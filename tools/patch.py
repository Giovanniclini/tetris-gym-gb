"""Apply and analyse UPS and BPS patches.

The Game Boy Tetris community distributes its ROM hacks as UPS/BPS patches
against Tetris (World) (Rev A). Since `build.py --original` reproduces that ROM
byte-exactly, we can apply any community patch to our own build and diff the
result - which turns an opaque binary into a precise list of what it changed.

We also emit BPS patches for our own releases: patches, never ROM data.
See docs/research.md section 7.
"""

import binascii
import struct


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
