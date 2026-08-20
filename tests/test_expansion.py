#!/usr/bin/env python3
"""Milestone 0.5: the cartridge is expanded, the original game is not touched.

    python3 tests/test_expansion.py        (also collectable by pytest)

The load-bearing test here is `test_original_banks_only_change_where_declared`.
It is what lets us restructure freely: if a refactor ever alters a byte of
original game code, this fails immediately and names the address.
"""

import hashlib
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Every permitted difference in banks 0-1, from src/hooks/hooks.inc plus the
# header fields the MBC1 conversion necessarily rewrites.
ALLOWED_RANGES = [
    (0x000B, 0x0027, "GYM_GRAVITY_TABLE - 23-entry gravity table in RST $08 padding"),
    (0x00DA, 0x00FF, "HOOK_TRAMPOLINE - Gym far-call trampoline in entry-point padding"),
    (0x1AFB, 0x1AFC, "HOOK_GRAVITY_PTR - table pointer redirected to GymFramesData"),
    (0x2459, 0x2459, "HOOK_LEVEL_CAP - level-up cap raised from $14 to $16"),
    (0x0147, 0x0147, "cartridge type -> MBC1+RAM+BATTERY"),
    (0x0148, 0x0148, "ROM size -> 64KB"),
    (0x0149, 0x0149, "RAM size -> 8KB"),
    (0x014D, 0x014D, "header checksum (recomputed by rgbfix)"),
    (0x014E, 0x014F, "global checksum (recomputed by rgbfix)"),
]

CART_MBC1_RAM_BATTERY = 0x03
ROM_SIZE_64KB = 0x01
RAM_SIZE_8KB = 0x02


def _build(*args) -> bytes:
    proc = subprocess.run(
        [sys.executable, "build.py", *args], cwd=ROOT, capture_output=True, text=True
    )
    assert proc.returncode == 0, f"build failed:\n{proc.stdout}\n{proc.stderr}"
    name = "tetris.gb" if "--original" in args else "tetrisgym.gb"
    return (ROOT / "build" / name).read_bytes()


def test_original_banks_only_change_where_declared():
    """The whole architecture in one assertion.

    Banks 0 and 1 are the original game. Any byte that differs between the
    stock build and the Gym build must be covered by an entry in
    src/hooks/hooks.inc. An undeclared difference means we changed original
    gameplay code, which is the one thing this project must never do silently.
    """
    ref, gym = _build("--original"), _build()

    def allowed(addr):
        return any(lo <= addr <= hi for lo, hi, _ in ALLOWED_RANGES)

    undeclared = [i for i in range(0x8000) if ref[i] != gym[i] and not allowed(i)]
    assert not undeclared, (
        f"{len(undeclared)} undeclared byte(s) changed in the original banks, "
        f"first at ${undeclared[0]:04X}. Either revert the change, or declare "
        f"it in src/hooks/hooks.inc and justify it in the commit."
    )


def test_trampoline_fits_its_declared_padding():
    """The trampoline must not overflow into the $0100 entry point."""
    ref, gym = _build("--original"), _build()
    changed = [i for i in range(0x00DA, 0x0100) if ref[i] != gym[i]]
    assert changed, "trampoline is missing - nothing changed in the padding"
    assert max(changed) <= 0x00FF, "trampoline overflowed past $00FF"
    used = max(changed) - 0x00DA + 1
    assert used <= 38, f"trampoline uses {used} of 38 available bytes"


def test_level_cap_raised_for_l_and_m():
    """docs/existing-hacks.md 3.2: with L and M selectable the level-up cap
    must rise, or levelling up runs past the gravity table into code. KLM has
    this bug; measured, its level 23 loads 202 frames/row."""
    ref, gym = _build("--original"), _build()
    assert ref[0x2459] == 0x14, "stock cap should be $14 (level 20)"
    assert gym[0x2459] == 0x16, f"Gym cap should be $16 (level 22), got ${gym[0x2459]:02X}"
    assert gym[0x2458] == 0xFE, "expected `cp n8` opcode at $2458"


def test_extended_gravity_table_contents():
    """The 23-entry table must match stock for 0-20 and KLM for L and M."""
    ref, gym = _build("--original"), _build()
    table = gym[0x000B:0x000B + 23]
    assert list(table[:21]) == list(ref[0x1B06:0x1B06 + 21]), "levels 0-20 changed"
    assert table[21] == 0x01, "L should be 2 frames/row"
    assert table[22] == 0x00, "M should be 1 frame/row (the engine ceiling)"


def test_gym_cartridge_header():
    d = _build()
    assert d[0x147] == CART_MBC1_RAM_BATTERY, f"cart type ${d[0x147]:02X}"
    assert d[0x148] == ROM_SIZE_64KB, f"ROM size ${d[0x148]:02X}"
    assert d[0x149] == RAM_SIZE_8KB, f"RAM size ${d[0x149]:02X}"
    assert len(d) == 64 * 1024, f"{len(d)} bytes"


def test_no_sram_variant_builds():
    """D9: SRAM must be optional - a battery adds cost and eventually dies."""
    d = _build("--no-sram")
    assert d[0x147] == 0x01, "cart type should be MBC1 without RAM"
    assert d[0x149] == 0x00, "RAM size should be none"


def test_original_build_still_byte_exact():
    """Milestone 0's guarantee must survive Milestone 0.5."""
    d = _build("--original")
    assert hashlib.sha1(d).hexdigest() == "74591cc9501af93873f9a5d3eb12da12c0723bbc"


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
