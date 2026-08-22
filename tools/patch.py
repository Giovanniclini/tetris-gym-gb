"""Apply, create and analyse UPS and BPS patches.

    python3 tools/patch.py tetrislab.bps "Tetris (World) (Rev A).gb"

Applies a patch to a ROM you supply and writes the result beside it. This
exists so that using a release needs nothing but Python 3 - the same promise
the build makes.

The Game Boy Tetris community distributes its ROM hacks as UPS/BPS patches
against Tetris (World) (Rev A). Since `build.py --original` reproduces that ROM
byte-exactly, we can apply any community patch to our own build and diff the
result - which turns an opaque binary into a precise list of what it changed.

We also emit BPS patches for our own releases: patches, never ROM data.
See docs/research.md section 7.
"""

import binascii
import struct
import sys
from pathlib import Path


class PatchError(Exception):
    pass


def _read_vuint(buf, pos):
    """The variable-width integer used by both UPS and BPS."""
    value, shift = 0, 1
    while True:
        x = buf[pos]
        pos += 1
        value += (x & 0x7F) * shift
        if x & 0x80:
            return value, pos
        shift <<= 7
        value += shift


def apply_ups(source: bytes, patch: bytes) -> bytes:
    if patch[:4] != b"UPS1":
        raise PatchError("not a UPS patch")
    src_crc, tgt_crc, _ = struct.unpack("<III", patch[-12:])
    if binascii.crc32(source) & 0xFFFFFFFF != src_crc:
        raise PatchError(
            f"source mismatch: patch wants {src_crc:08X}, "
            f"got {binascii.crc32(source) & 0xFFFFFFFF:08X}"
        )

    pos = 4
    src_size, pos = _read_vuint(patch, pos)
    tgt_size, pos = _read_vuint(patch, pos)
    if src_size != len(source):
        raise PatchError(f"source size {len(source)}, patch expects {src_size}")

    target = bytearray(tgt_size)
    target[: min(src_size, tgt_size)] = source[: min(src_size, tgt_size)]

    end = len(patch) - 12
    offset = 0
    while pos < end:
        rel, pos = _read_vuint(patch, pos)
        offset += rel
        while True:
            b = patch[pos]
            pos += 1
            if b == 0:
                break
            target[offset] ^= b
            offset += 1
        offset += 1

    out = bytes(target)
    if binascii.crc32(out) & 0xFFFFFFFF != tgt_crc:
        raise PatchError("target checksum mismatch after applying")
    return out


def apply_bps(source: bytes, patch: bytes) -> bytes:
    if patch[:4] != b"BPS1":
        raise PatchError("not a BPS patch")
    src_crc, tgt_crc, _ = struct.unpack("<III", patch[-12:])
    if binascii.crc32(source) & 0xFFFFFFFF != src_crc:
        raise PatchError(
            f"source mismatch: patch wants {src_crc:08X}, "
            f"got {binascii.crc32(source) & 0xFFFFFFFF:08X}"
        )

    pos = 4
    src_size, pos = _read_vuint(patch, pos)
    tgt_size, pos = _read_vuint(patch, pos)
    meta_size, pos = _read_vuint(patch, pos)
    metadata = patch[pos:pos + meta_size]
    pos += meta_size

    target = bytearray(tgt_size)
    out_off = src_rel = tgt_rel = 0
    end = len(patch) - 12

    while pos < end:
        data, pos = _read_vuint(patch, pos)
        action, length = data & 3, (data >> 2) + 1
        if action == 0:                                   # SourceRead
            target[out_off:out_off + length] = source[out_off:out_off + length]
            out_off += length
        elif action == 1:                                 # TargetRead
            target[out_off:out_off + length] = patch[pos:pos + length]
            pos += length
            out_off += length
        elif action == 2:                                 # SourceCopy
            data, pos = _read_vuint(patch, pos)
            src_rel += (-1 if data & 1 else 1) * (data >> 1)
            for _ in range(length):
                target[out_off] = source[src_rel]
                src_rel += 1
                out_off += 1
        else:                                             # TargetCopy
            data, pos = _read_vuint(patch, pos)
            tgt_rel += (-1 if data & 1 else 1) * (data >> 1)
            for _ in range(length):
                target[out_off] = target[tgt_rel]
                tgt_rel += 1
                out_off += 1

    out = bytes(target)
    if binascii.crc32(out) & 0xFFFFFFFF != tgt_crc:
        raise PatchError("target checksum mismatch after applying")
    return out, metadata


def apply(source: bytes, patch: bytes):
    """Apply a UPS or BPS patch, dispatching on its magic."""
    if patch[:4] == b"UPS1":
        return apply_ups(source, patch)
    if patch[:4] == b"BPS1":
        return apply_bps(source, patch)[0]
    raise PatchError(f"unknown patch format {patch[:4]!r}")


# --- creating BPS patches --------------------------------------------------
#
# Releases are a patch and nothing else: the user brings their own ROM. See
# CLAUDE.md principle 10.

def _write_vuint(out: bytearray, value: int):
    while True:
        x = value & 0x7F
        value >>= 7
        if value == 0:
            out.append(0x80 | x)
            return
        out.append(x)
        value -= 1


def _write_svuint(out: bytearray, value: int):
    _write_vuint(out, (abs(value) << 1) | (1 if value < 0 else 0))


def create_bps(source: bytes, target: bytes, metadata: bytes = b"") -> bytes:
    """Encode a BPS patch turning `source` into `target`.

    Deliberately simple: runs that already match the source cost nothing, runs
    of a repeated byte become a self-referencing copy (which is how the 32 KB of
    $FF padding in the new banks all but disappears), everything else is a
    literal. A real delta compressor would do better; the output of this one is
    small enough that the difference does not matter.
    """
    MIN_RUN = 4
    out = bytearray(b"BPS1")
    _write_vuint(out, len(source))
    _write_vuint(out, len(target))
    _write_vuint(out, len(metadata))
    out += metadata

    def emit(action, length, literal=b""):
        _write_vuint(out, ((length - 1) << 2) | action)
        out.extend(literal)

    i, n, tgt_rel, pending = 0, len(target), 0, bytearray()

    def flush_literal():
        if pending:
            emit(1, len(pending), bytes(pending))
            pending.clear()

    while i < n:
        # 1. Identical to the source at the same offset: free.
        run = 0
        while (i + run < n and i + run < len(source)
               and target[i + run] == source[i + run]):
            run += 1
        if run >= MIN_RUN:
            flush_literal()
            emit(0, run)
            i += run
            continue

        # 2. A repeated byte: point one byte back into the output and let the
        #    copy read what it is writing.
        run = 1
        while i + run < n and target[i + run] == target[i]:
            run += 1
        if i > 0 and target[i] == target[i - 1] and run >= MIN_RUN:
            flush_literal()
            _write_vuint(out, ((run - 1) << 2) | 3)
            _write_svuint(out, (i - 1) - tgt_rel)
            tgt_rel = (i - 1) + run
            i += run
            continue

        pending.append(target[i])
        i += 1

    flush_literal()
    out += struct.pack("<II", binascii.crc32(source) & 0xFFFFFFFF,
                       binascii.crc32(target) & 0xFFFFFFFF)
    out += struct.pack("<I", binascii.crc32(bytes(out)) & 0xFFFFFFFF)
    return bytes(out)


def _main(argv):
    import argparse

    ap = argparse.ArgumentParser(description="Apply a UPS or BPS patch to a ROM.")
    ap.add_argument("patch", help="the .bps or .ups file")
    ap.add_argument("rom", help="your own copy of Tetris (World) (Rev A)")
    ap.add_argument("-o", "--out", help="output file (default: alongside the patch)")
    args = ap.parse_args(argv)

    patch_path, rom_path = Path(args.patch), Path(args.rom)
    out = Path(args.out) if args.out else patch_path.with_suffix(".gb")

    try:
        result = apply(rom_path.read_bytes(), patch_path.read_bytes())
    except PatchError as exc:
        print(f"error: {exc}", file=sys.stderr)
        if "source mismatch" in str(exc):
            print("This patch is for Tetris (World) (Rev A), md5 "
                  "982ed5d2b12a0377eb14bcdc4123744e.", file=sys.stderr)
        return 1

    out.write_bytes(result)
    print(f"wrote {out}  ({len(result)} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(_main(sys.argv[1:]))
