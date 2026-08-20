#!/usr/bin/env python3
"""Build the TetrisGYM-GB ROM.

    python3 build.py               build the Gym ROM       (GYM=1)
    python3 build.py --original    rebuild the stock ROM   (GYM=0)  <- the regression test
    python3 build.py --freespace   also print per-bank free space

Requires only Python 3 and network access on first run; the pinned RGBDS
toolchain is fetched into build/toolchain/. Nothing is installed system-wide.
"""

import argparse
import hashlib
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from tools import gfx, rgbds  # noqa: E402

ROOT = Path(__file__).parent.resolve()
SRC = ROOT / "src" / "original"
BUILD = ROOT / "build"
OBJ = BUILD / "obj"

# Tetris (World) (Rev A), a.k.a. v1.1 - the community standard.
# See docs/architecture.md D2 and docs/community-research.md section 3.5.6.
REFERENCE_SHA1 = "74591cc9501af93873f9a5d3eb12da12c0723bbc"
REFERENCE_MD5 = "982ed5d2b12a0377eb14bcdc4123744e"

# Translation units, in link order. The original disassembly is one big
# address-fixed ROM0 section plus the sound engine in bank 1.
UNITS = [
    ("bank_000", SRC / "code" / "bank_000.s"),
    ("soundEngine", SRC / "code" / "soundEngine.s"),
    ("wram", SRC / "include" / "wram.s"),
    ("hram", SRC / "include" / "hram.s"),
]


def run(cmd):
    proc = subprocess.run([str(c) for c in cmd], capture_output=True, text=True)
    if proc.stdout.strip():
        print(proc.stdout.rstrip())
    if proc.returncode != 0:
        print(proc.stderr.rstrip(), file=sys.stderr)
        raise SystemExit(f"command failed: {' '.join(str(c) for c in cmd)}")
    # rgbasm warnings are worth seeing even on success
    if proc.stderr.strip():
        print(proc.stderr.rstrip(), file=sys.stderr)


def freespace(map_path: Path) -> None:
    print("\nfree space:")
    bank = None
    for line in map_path.read_text().splitlines():
        stripped = line.strip()
        if stripped.endswith("bank #0:") or "bank #" in stripped and ":" in stripped:
            if not stripped.startswith(("SECTION", "EMPTY", "TOTAL")):
                bank = stripped.rstrip(":")
        elif stripped.startswith("TOTAL EMPTY:") and bank:
            print(f"  {bank:<16} {stripped.split(':', 1)[1].strip()}")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--original", action="store_true",
                    help="build with GYM=0: must reproduce the stock ROM byte-exactly")
    ap.add_argument("--freespace", action="store_true", help="print per-bank free space")
    args = ap.parse_args()

    gym = 0 if args.original else 1
    name = "tetris" if args.original else "tetrisgym"

    print(f"TetrisGYM-GB build  (GYM={gym})")

    print("toolchain:")
    tc = rgbds.ensure(BUILD)

    print("graphics:")
    gfx.build(tc / "rgbgfx", SRC, OBJ / "build")

    print("assemble:")
    OBJ.mkdir(parents=True, exist_ok=True)
    objs = []
    for unit, path in UNITS:
        obj = OBJ / f"{unit}.o"
        run([tc / "rgbasm", "-h", "-L",
             "-D", f"GYM={gym}",
             "-I", str(SRC) + "/", "-I", str(OBJ) + "/",
             "-o", obj, path])
        objs.append(obj)

    rom = BUILD / f"{name}.gb"
    sym = BUILD / f"{name}.sym"
    mapf = BUILD / f"{name}.map"

    print("link:")
    run([tc / "rgblink", "-n", sym, "-m", mapf, "-w", "-o", rom, *objs])
    run([tc / "rgbfix", "-v", "-p", "255", rom])

    data = rom.read_bytes()
    sha1 = hashlib.sha1(data).hexdigest()
    md5 = hashlib.md5(data).hexdigest()
    print(f"\n{rom.relative_to(ROOT)}  {len(data)} bytes")
    print(f"  sha1 {sha1}")
    print(f"  md5  {md5}")

    if args.freespace:
        freespace(mapf)

    if args.original:
        if sha1 != REFERENCE_SHA1:
            print(f"\nFAIL: expected sha1 {REFERENCE_SHA1}", file=sys.stderr)
            return 1
        print("\nOK: byte-exact match for Tetris (World) (Rev A)")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
