#!/usr/bin/env python3
"""Level select: banks 0-9 / A-J / K-M, and the hearts toggle.

    .venv/bin/python tests/test_menu.py
"""

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from tools.emu import Tetris, hATypeLevel, hIsHardMode, GS_IN_GAME_MAIN  # noqa: E402

ROM = "build/tetrisgym.gb"
wGymLevelBank = 0xD800

# The ten level cells: rows 6 and 8 of the tilemap, every second column from 5.
CELLS = ([0x9800 + 6 * 32 + 5 + 2 * i for i in range(5)]
         + [0x9800 + 8 * 32 + 5 + 2 * i for i in range(5)])
HEART_CELL = 0x9800 + 4 * 32 + 14

TILE_HEART = 0x27
TILE_FRAME = 0x2C          # what the original draws in that spot
TILE_BLANK = 0x2F

BANK_TILES = [
    [0x90 + i for i in range(10)],                       # original digit art
    [0x0A + i for i in range(10)],                       # A-J
    [0x14, 0x15, 0x16] + [TILE_BLANK] * 7,               # K, L, M
]

GRAVITY_L, GRAVITY_M = 2, 1


def to_bank(t, bank):
    """Cycle to a bank. Down on the bottom row advances; the first Down from
    level 0 just moves the cursor there."""
    t.to_level_select()
    t.press("down")                       # cursor 0 -> 5, still bank 0
    while t[wGymLevelBank] != bank:
        t.press("down")
    return t


def test_each_bank_draws_the_right_tiles():
    # a fresh boot per bank: to_bank() starts from the title screen
    for bank in range(3):
        with Tetris(ROM) as t:
            to_bank(t, bank)
            got = [t[a] for a in CELLS]
            assert got == BANK_TILES[bank], (
                f"bank {bank}: expected {[hex(x) for x in BANK_TILES[bank]]}, "
                f"got {[hex(x) for x in got]}"
            )


def test_banks_wrap_around():
    with Tetris(ROM) as t:
        to_bank(t, 2)
        t.press("down")
        assert t[wGymLevelBank] == 0, "bank should wrap 2 -> 0"


def test_cursor_cannot_leave_the_k_to_m_cells():
    """K, L and M occupy three cells; the original would happily walk right
    into the empty ones."""
    with Tetris(ROM) as t:
        to_bank(t, 2)
        for _ in range(6):
            t.press("right")
        assert t[hATypeLevel] == 2, f"cursor should stop at M, got {t[hATypeLevel]}"


def test_cursor_is_pulled_back_when_entering_the_k_to_m_bank():
    with Tetris(ROM) as t:
        to_bank(t, 1)
        for _ in range(4):
            t.press("right")              # park the cursor beyond M's column
        assert t[hATypeLevel] > 2
        t.press("down")                   # into bank 2
        assert t[wGymLevelBank] == 2
        assert t[hATypeLevel] <= 2, f"cursor not clamped, got {t[hATypeLevel]}"


def test_select_toggles_hearts_and_shows_an_indicator():
    with Tetris(ROM) as t:
        t.to_level_select()
        assert t[hIsHardMode] == 0
        assert t[HEART_CELL] == TILE_FRAME

        t.press("select")
        assert t[hIsHardMode] != 0, "hearts should be on"
        assert t[HEART_CELL] == TILE_HEART, "heart indicator not drawn"

        t.press("select")
        assert t[hIsHardMode] == 0, "hearts should be off"
        assert t[HEART_CELL] == TILE_FRAME, "heart indicator not cleared"


def test_starting_from_each_bank_gives_the_right_level():
    """The cursor holds 0-9 on this screen; the bank is folded back in only
    when the game starts."""
    for bank, cursor, expected in ((0, 3, 3), (1, 3, 13), (2, 1, 21), (2, 2, 22)):
        with Tetris(ROM) as t:
            to_bank(t, bank)
            # walk the cursor to the wanted column on the top row
            while t[hATypeLevel] >= 5:
                t.press("up")
            while t[hATypeLevel] > cursor:
                t.press("left")
            while t[hATypeLevel] < cursor:
                t.press("right")
            t.press("start")
            t.run_until_state(GS_IN_GAME_MAIN)
            assert t[hATypeLevel] == expected, (
                f"bank {bank} cursor {cursor}: expected level {expected}, "
                f"got {t[hATypeLevel]}"
            )


def test_l_and_m_are_reachable_through_the_menu_alone():
    """The whole point: no poking memory, just button presses."""
    for cursor, level, gravity in ((1, 21, GRAVITY_L), (2, 22, GRAVITY_M)):
        with Tetris(ROM) as t:
            to_bank(t, 2)
            while t[hATypeLevel] > cursor:
                t.press("left")
            while t[hATypeLevel] < cursor:
                t.press("right")
            t.press("start")
            t.run_until_state(GS_IN_GAME_MAIN)
            assert t[hATypeLevel] == level
            assert t.gravity() == gravity, (
                f"level {level}: expected {gravity} frames/row, got {t.gravity()}"
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
