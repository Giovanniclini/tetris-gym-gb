#!/usr/bin/env python3
"""Diff a community ROM hack against our byte-exact reference build.

    python3 tools/analyze_hack.py <patch-or-rom> [...]

Every Game Boy Tetris hack in circulation is a UPS/BPS patch against
Tetris (World) (Rev A), which is exactly what `build.py --original` produces.
So we can apply any of them to our own build, diff, and map each changed run
back to the routine it lives in using the linker's symbol file.

That turns an opaque binary into a reviewable list of edits - which is how we
match what the community already uses instead of reinventing it.
"""

import binascii
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from tools import patch as P  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
REFERENCE = ROOT / "build" / "tetris.gb"
SYMFILE = ROOT / "build" / "tetris.sym"


def load_symbols():
    """bank:addr -> name, from rgblink's .sym output. Only ROM banks 0 and 1."""
    syms = []
    if not SYMFILE.exists():
        return syms
    for line in SYMFILE.read_text(errors="replace").splitlines():
        line = line.split(";")[0].strip()
        if not line or ":" not in line:
            continue
        try:
            loc, name = line.split(None, 1)
            bank, addr = loc.split(":")
            bank, addr = int(bank, 16), int(addr, 16)
        except ValueError:
            continue
        flat = addr if bank == 0 else (bank - 1) * 0x4000 + addr
        if flat < 0x8000:
            syms.append((flat, name.strip()))
    syms.sort()
    return syms


def symbol_for(syms, addr):
    """Nearest symbol at or before addr."""
    lo, hi, best = 0, len(syms) - 1, None
    while lo <= hi:
        mid = (lo + hi) // 2
        if syms[mid][0] <= addr:
            best = syms[mid]
            lo = mid + 1
        else:
            hi = mid - 1
    if not best:
        return "?", 0
    return best[1], addr - best[0]


def runs(ref, mod, gap=8):
    """Contiguous changed regions, merging runs separated by < `gap` equal bytes."""
    diff = [i for i in range(min(len(ref), len(mod))) if ref[i] != mod[i]]
    if not diff:
        return []
    out, start, prev = [], diff[0], diff[0]
    for i in diff[1:]:
        if i - prev <= gap:
            prev = i
        else:
            out.append((start, prev))
            start = prev = i
    out.append((start, prev))
    return out


def analyze(path: Path, ref: bytes, syms):
    blob = path.read_bytes()
    if blob[:4] in (b"UPS1", b"BPS1"):
        mod = P.apply(ref, blob)
        kind = blob[:4].decode()
    else:
        mod, kind = blob, "ROM"

    print(f"\n{'=' * 78}\n{path.name}   [{kind}]")
    print(f"  size {len(mod)} bytes   crc {binascii.crc32(mod) & 0xFFFFFFFF:08X}")
    hdr = {
        0x147: "cart type", 0x148: "rom size", 0x149: "ram size",
    }
    changed_hdr = [f"{n} ${ref[a]:02X}->${mod[a]:02X}"
                   for a, n in hdr.items() if ref[a] != mod[a]]
    print(f"  header: {', '.join(changed_hdr) if changed_hdr else 'unchanged (still 32KB ROM-ONLY)'}")

    rs = runs(ref, mod)
    total = sum(e - s + 1 for s, e in rs)
    print(f"  {len(rs)} changed regions, {total} bytes\n")
    for s, e in rs:
        name, off = symbol_for(syms, s)
        n = e - s + 1
        loc = f"{name}+{off}" if off else name
        print(f"    ${s:04X}-${e:04X}  {n:4d}B  {loc}")
    return mod


def main():
    if not REFERENCE.exists():
        raise SystemExit("run `python3 build.py --original` first")
    ref = REFERENCE.read_bytes()
    syms = load_symbols()
    if not syms:
        print("warning: no symbols loaded; regions will be unlabelled\n")
    for arg in sys.argv[1:]:
        analyze(Path(arg), ref, syms)


if __name__ == "__main__":
    main()
