#!/usr/bin/env python3
"""The project's ground truth.

    python3 tests/test_original.py        (also collectable by pytest)

`build.py --original` must reproduce Tetris (World) (Rev A) byte for byte.
This is the mechanical guarantee behind the promise in CLAUDE.md that the
gameplay is the original machine code. If it fails, the change is wrong -
regardless of how good the new feature looks. Never weaken or skip it.
"""

import hashlib
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REFERENCE_SHA1 = "74591cc9501af93873f9a5d3eb12da12c0723bbc"
REFERENCE_MD5 = "982ed5d2b12a0377eb14bcdc4123744e"
REFERENCE_SIZE = 32768


def build_original() -> bytes:
    proc = subprocess.run(
        [sys.executable, "build.py", "--original"],
        cwd=ROOT, capture_output=True, text=True,
    )
    assert proc.returncode == 0, f"build failed:\n{proc.stdout}\n{proc.stderr}"
    rom = ROOT / "build" / "tetris.gb"
    assert rom.exists(), "build reported success but produced no ROM"
    return rom.read_bytes()


def test_original_rom_is_byte_exact():
    data = build_original()
    assert len(data) == REFERENCE_SIZE, f"size {len(data)}, expected {REFERENCE_SIZE}"
    assert hashlib.md5(data).hexdigest() == REFERENCE_MD5
    assert hashlib.sha1(data).hexdigest() == REFERENCE_SHA1


def test_cartridge_header_is_stock():
    """Guards the header fields the Lab build will later change (see D5)."""
    d = build_original()
    assert d[0x134:0x13B] == b"TETRIS\x00", "title"
    assert d[0x147] == 0x00, "cartridge type must be ROM ONLY in the original build"
    assert d[0x148] == 0x00, "ROM size must be 32 KB in the original build"
    assert d[0x149] == 0x00, "RAM size must be none in the original build"
    assert d[0x14C] == 0x01, "mask ROM version must be 1 (Rev A / v1.1)"


def test_gravity_table_matches_documented_timings():
    """docs/research.md section 2.1: the table lives at $1B06 in v1.1 and stores
    frames-per-row minus one, for levels 0..20."""
    d = build_original()
    expected = [53, 49, 45, 41, 37, 33, 28, 22, 17, 11,
                10, 9, 8, 7, 6, 6, 5, 5, 4, 4, 3]
    actual = [d[0x1B06 + i] + 1 for i in range(21)]
    assert actual == expected, f"gravity table changed: {actual}"


def test_das_constants_unchanged():
    """docs/research.md section 8: DAS is 23 frames initial ($17), 9 autorepeat.

    9 frames at 59.727 Hz is 6.6363 Hz, which matches the auto-repeat rate the
    community independently measured as 6.636666667 Hz - see
    docs/community-research.md section 3.5.5.

    Each site is `ld a, n8` (opcode $3E), so the constant is the operand byte.
    Asserting the opcode too means a shifted address fails loudly instead of
    silently reading some unrelated byte that happens to match.
    """
    d = build_original()
    sites = [
        (0x2517, 0x17, "initial DAS delay (right)"),
        (0x254E, 0x17, "initial DAS delay (left)"),
        (0x2525, 0x09, "DAS autorepeat (right)"),
        (0x255C, 0x09, "DAS autorepeat (left)"),
    ]
    for addr, value, what in sites:
        assert d[addr] == 0x3E, f"{what}: expected `ld a, n8` at ${addr:04X}"
        assert d[addr + 1] == value, (
            f"{what}: expected ${value:02X} at ${addr + 1:04X}, "
            f"got ${d[addr + 1]:02X}"
        )


TESTS = [v for k, v in sorted(globals().items()) if k.startswith("test_")]

if __name__ == "__main__":
    failures = 0
    for fn in TESTS:
        try:
            fn()
            print(f"PASS  {fn.__name__}")
        except AssertionError as exc:
            failures += 1
            print(f"FAIL  {fn.__name__}: {exc}")
    print(f"\n{len(TESTS) - failures}/{len(TESTS)} passed")
    raise SystemExit(1 if failures else 0)
