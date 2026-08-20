#!/usr/bin/env python3
"""Behavioural tests: drive the ROM in an emulator and check what it does.

    .venv/bin/python tests/test_behaviour.py

These complement the byte-level tests. A byte test proves the ROM contains the
right value; these prove the game acts on it. A broken hook can leave every
byte correct.
"""

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from tools.emu import Tetris, hIsHardMode, hNumFramesUntilPiecesMoveDown  # noqa: E402

# docs/research.md 2.1 - frames per row for levels 0..20
GRAVITY = [53, 49, 45, 41, 37, 33, 28, 22, 17, 11,
           10, 9, 8, 7, 6, 6, 5, 5, 4, 4, 3]


def test_gravity_matches_table_for_every_level():
    """The game must actually load the documented gravity for each level.

    Reads the reload value the game computed at gameplay start, for all 21
    levels, by driving the real menus and starting a real game each time.
    """
    with Tetris() as t:
        for level in range(21):
            t.start_game_at(level)
            got = t.gravity()
            assert got == GRAVITY[level], (
                f"level {level}: expected {GRAVITY[level]} frames/row, got {got}"
            )
            t.__init__()  # fresh boot for the next level


def test_hearts_add_ten_levels_and_clamp_at_twenty():
    """docs/research.md 3.7: hard mode is min(level + 10, 20)."""
    with Tetris() as t:
        for level, expected_level in ((0, 10), (5, 15), (9, 19)):
            t.start_game_at(level, hearts=True)
            assert t[hIsHardMode] != 0, f"hard mode not armed for level {level}"
            got = t.gravity()
            assert got == GRAVITY[expected_level], (
                f"heart level {level}: expected level {expected_level} speed "
                f"({GRAVITY[expected_level]} frames/row), got {got}"
            )
            t.__init__()


def test_observed_fall_rate_matches_the_reload_value():
    """Independent check: count actual frames between gravity steps, rather
    than trusting the reload value the game stored."""
    with Tetris() as t:
        t.start_game_at(0)
        expected = t.gravity()
        gaps = t.measure_gravity()
        assert gaps, "no gravity steps observed"
        assert all(g == expected for g in gaps), (
            f"level 0: reload says {expected} frames/row, observed {gaps}"
        )


def test_gym_build_adds_levels_l_and_m():
    """L (21) and M (22) must match KLM exactly: 2 and 1 frames per row.

    M is the engine's ceiling - the gravity counter cannot reload with less
    than one frame - which is why KLM stops there and so do we.
    See docs/existing-hacks.md section 3.
    """
    for level, expected in ((21, 2), (22, 1)):
        with Tetris("build/tetrisgym.gb") as t:
            t.start_game_at(level)
            got = t.gravity()
            name = "L" if level == 21 else "M"
            assert got == expected, (
                f"level {name} ({level}): expected {expected} frames/row, got {got}"
            )


def test_gym_build_preserves_every_original_level():
    """Adding L and M must not disturb levels 0-20."""
    with Tetris("build/tetrisgym.gb") as t:
        for level in range(21):
            t.start_game_at(level)
            got = t.gravity()
            assert got == GRAVITY[level], (
                f"level {level}: expected {GRAVITY[level]} frames/row, got {got}"
            )
            t.__init__("build/tetrisgym.gb")


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
