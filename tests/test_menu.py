#!/usr/bin/env python3
"""Level picker on the A-TYPE selection screen.

    .venv/bin/python tests/test_menu.py

The original 0-9 grid is left completely alone. The Gym adds one cell to its
right, reached by pressing Right on cell 9 - a press the original ignores.
See docs/decisions/0003.
"""

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from tools.emu import Tetris, hATypeLevel, hIsHardMode, GS_IN_GAME_MAIN  # noqa: E402

ROM = "build/tetrisgym.gb"

wGymPickerActive = 0xD800
wGymPickerLevel = 0xD801

GRID_CELLS = ([0x9800 + 6 * 32 + 5 + 2 * i for i in range(5)]
              + [0x9800 + 8 * 32 + 5 + 2 * i for i in range(5)])
GRID_TILES = [0x90 + i for i in range(10)]      # the original's digit art
PICKER_CELL = 0x9800 + 6 * 32 + 16
HEART_CELL = 0x9800 + 4 * 32 + 14
SPRITE_HIDDEN_BYTE = 0xC200

TILE_HEART, TILE_FRAME, TILE_BLANK = 0x27, 0x2C, 0x2F
MAX_LEVEL = 22

GRAVITY = [53, 49, 45, 41, 37, 33, 28, 22, 17, 11,
           10, 9, 8, 7, 6, 6, 5, 5, 4, 4, 3, 2, 1]


def open_picker(t):
    """Walk the grid to cell 9 and press Right once more."""
    t.to_level_select()
    t.tick(4)
    while t[hATypeLevel] < 9:
        t.press("right")
    t.press("right")
    assert t[wGymPickerActive], "Right on cell 9 should open the picker"
    return t


def picker_to(t, level):
    while t[wGymPickerLevel] < level:
        t.press("right")
    while t[wGymPickerLevel] > level:
        t.press("left")
    assert t[wGymPickerLevel] == level
    return t


def test_the_original_grid_is_never_modified():
    """The whole point of this design: the 0-9 grid keeps its own tiles,
    cursor and movement."""
    with Tetris(ROM) as t:
        open_picker(t)
        picker_to(t, MAX_LEVEL)
        t.tick(40)
        got = [t[a] for a in GRID_CELLS]
        assert got == GRID_TILES, f"grid tiles changed: {[hex(x) for x in got]}"


def test_grid_movement_is_unchanged():
    with Tetris(ROM) as t:
        t.to_level_select()
        t.tick(4)
        for expected in (1, 2, 3, 4, 5):
            t.press("right")
            assert t[hATypeLevel] == expected
        t.press("down")
        assert t[hATypeLevel] == 5, "Down on the bottom row should do nothing"
        t.press("up")
        assert t[hATypeLevel] == 0, "Up from cell 5 should reach cell 0"


def test_picker_opens_and_closes_from_the_grid():
    with Tetris(ROM) as t:
        open_picker(t)
        picker_to(t, 0)
        t.press("left")                       # left at 0 hands focus back
        assert not t[wGymPickerActive], "picker should have closed"
        assert t[hATypeLevel] == 9, "focus should return to grid cell 9"


def test_picker_clamps_at_both_ends():
    with Tetris(ROM) as t:
        open_picker(t)
        for _ in range(30):
            t.press("right")
        assert t[wGymPickerLevel] == MAX_LEVEL, "should stop at M"


def test_picker_cell_shows_the_level_character():
    """The font puts 0-9 at $00-$09 and A-M at $0A-$16, so the tile is simply
    the level number."""
    with Tetris(ROM) as t:
        open_picker(t)
        for level in (10, 15, 20, 21, 22):
            picker_to(t, level)
            seen = set()
            for _ in range(40):
                t.tick(1)
                seen.add(t[PICKER_CELL])
            assert level in seen, (
                f"level {level}: expected tile ${level:02X}, saw "
                f"{[hex(x) for x in seen]}"
            )


def test_picker_blinks_only_while_it_has_focus():
    with Tetris(ROM) as t:
        open_picker(t)
        picker_to(t, 12)
        seen = set()
        for _ in range(40):
            t.tick(1)
            seen.add(t[PICKER_CELL])
        assert seen == {12, TILE_BLANK}, f"expected a blink, saw {seen}"

        picker_to(t, 0)
        t.press("left")                       # back to the grid
        seen = set()
        for _ in range(40):
            t.tick(1)
            seen.add(t[PICKER_CELL])
        assert seen == {0}, f"should be steady once unfocused, saw {seen}"


def test_grid_cursor_is_hidden_while_the_picker_has_focus():
    """The cursor sprite draws the character for hATypeLevel, not what the
    picker shows, so it must not appear on screen.

    Asserted against OAM rather than the spec byte: the original copies the
    specs into OAM itself, so setting the hidden bit after that copy is not
    enough on its own.
    """
    with Tetris(ROM) as t:
        open_picker(t)
        picker_to(t, 15)
        for _ in range(40):
            t.tick(1)
            y = t[0xFE00]
            assert y == 0 or y >= 160, f"grid cursor visible on screen at Y={y}"


def test_vertical_input_is_ignored_while_the_picker_has_focus():
    with Tetris(ROM) as t:
        open_picker(t)
        before = t[hATypeLevel]
        t.press("up")
        t.press("down")
        assert t[hATypeLevel] == before, "grid cursor moved under the picker"
        assert t[wGymPickerActive], "picker lost focus"


def test_starting_from_the_picker_uses_its_level():
    for level in (10, 15, 20, 21, 22):
        with Tetris(ROM) as t:
            open_picker(t)
            picker_to(t, level)
            t.press("start")
            t.run_until_state(GS_IN_GAME_MAIN)
            assert t[hATypeLevel] == level, (
                f"expected level {level}, got {t[hATypeLevel]}"
            )
            assert t.gravity() == GRAVITY[level], (
                f"level {level}: expected {GRAVITY[level]} frames/row, "
                f"got {t.gravity()}"
            )


def test_starting_from_the_grid_still_works():
    for level in (0, 5, 9):
        with Tetris(ROM) as t:
            t.to_level_select()
            t.tick(4)
            while t[hATypeLevel] < level:
                t.press("right")
            t.press("start")
            t.run_until_state(GS_IN_GAME_MAIN)
            assert t[hATypeLevel] == level
            assert t.gravity() == GRAVITY[level]


def test_select_toggles_hearts_and_shows_an_indicator():
    with Tetris(ROM) as t:
        t.to_level_select()
        t.tick(4)
        assert t[hIsHardMode] == 0
        assert t[HEART_CELL] == TILE_FRAME

        t.press("select")
        t.tick(2)
        assert t[hIsHardMode] != 0
        assert t[HEART_CELL] == TILE_HEART

        t.press("select")
        t.tick(2)
        assert t[hIsHardMode] == 0
        assert t[HEART_CELL] == TILE_FRAME


def test_hearts_are_cleared_above_level_20():
    """min(level + 10, 20) clamps downward past level 20, which would make the
    game slower. See docs/existing-hacks.md 3.2b."""
    with Tetris(ROM) as t:
        t.to_level_select()
        t.tick(4)
        t.press("select")
        assert t[hIsHardMode] != 0
        while t[hATypeLevel] < 9:            # already on the screen; do not renavigate
            t.press("right")
        t.press("right")
        assert t[wGymPickerActive]
        picker_to(t, 21)
        t.tick(4)
        assert t[hIsHardMode] == 0, "hearts should be cleared above level 20"
        assert t[HEART_CELL] == TILE_FRAME


def test_heart_speeds_are_unchanged_for_the_original_levels():
    for level, effective in ((0, 10), (5, 15), (9, 19)):
        with Tetris(ROM) as t:
            t.start_game_at(level, hearts=True)
            assert t.gravity() == GRAVITY[effective]


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
