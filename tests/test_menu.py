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
GRAVITY_TABLE = [53, 49, 45, 41, 37, 33, 28, 22, 17, 11,
                 10, 9, 8, 7, 6, 6, 5, 5, 4, 4, 3, 2, 1]


def to_bank_from_here(t, bank):
    """Cycle to a bank from an open level select screen.

    Navigation model: Down on the bottom row moves to the *top* row of the next
    bank; Up on the top row moves to the bottom row of the previous one. So
    each bank change costs two Downs from a top-row start.
    """
    for _ in range(24):
        if t[wGymLevelBank] == bank:
            return t
        t.press("down")
    raise AssertionError(f"could not reach bank {bank}")


def to_bank(t, bank):
    t.to_level_select()
    return to_bank_from_here(t, bank)


def goto(t, bank, cursor):
    """Put the cursor on a specific cell of a specific bank, using only button
    presses - no memory pokes."""
    to_bank(t, bank)
    if cursor >= 5:
        if t[hATypeLevel] < 5:
            t.press("down")             # top row -> bottom row, same bank
    else:
        if t[hATypeLevel] >= 5:
            t.press("up")               # bottom row -> top row, same bank
    while t[hATypeLevel] > cursor:
        t.press("left")
    while t[hATypeLevel] < cursor:
        t.press("right")
    assert t[hATypeLevel] == cursor, f"could not reach cell {cursor}"
    assert t[wGymLevelBank] == bank, "navigation changed bank"
    return t


def settled_cells(t):
    """Read the ten cells with the blink resolved.

    On letter banks the selected cell blinks between its letter and blank, so a
    single sample can catch either. Take the non-blank value seen over a full
    blink period.
    """
    seen = [set() for _ in range(10)]
    for _ in range(40):
        t.tick(1)
        for i, addr in enumerate(CELLS):
            seen[i].add(t[addr])
    out = []
    for s in seen:
        non_blank = [v for v in s if v != TILE_BLANK]
        out.append(non_blank[0] if non_blank else TILE_BLANK)
    return out


def test_each_bank_draws_the_right_tiles():
    # a fresh boot per bank: to_bank() starts from the title screen
    for bank in range(3):
        with Tetris(ROM) as t:
            to_bank(t, bank)
            got = settled_cells(t)
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
        goto(t, 1, 9)                     # bottom row, beyond M's column
        assert t[hATypeLevel] > 2
        t.press("down")                   # falls into bank 2
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
    for bank, cursor, expected in ((0, 3, 3), (0, 7, 7), (1, 3, 13), (2, 1, 21), (2, 2, 22)):
        with Tetris(ROM) as t:
            goto(t, bank, cursor)
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
            goto(t, 2, cursor)
            t.press("start")
            t.run_until_state(GS_IN_GAME_MAIN)
            assert t[hATypeLevel] == level
            assert t.gravity() == gravity, (
                f"level {level}: expected {gravity} frames/row, got {t.gravity()}"
            )


def test_hearts_are_not_offered_where_they_would_slow_the_game():
    """Hard mode is min(level + 10, 20). That ceiling predates L and M, so at
    K, L or M it clamps downward - M with hearts runs at 3 frames per row
    instead of 1, three times slower. KLM has the same behaviour.

    Rather than change the original formula, which normal heart games depend
    on, hearts are simply not offered in the K-M bank, where they can never
    help.
    """
    with Tetris(ROM) as t:
        t.to_level_select(hearts=True)          # armed the original way
        assert t[hIsHardMode] != 0
        to_bank_from_here(t, 2)
        assert t[hIsHardMode] == 0, "hearts should be cleared on entering K-M"
        t.press("select")
        assert t[hIsHardMode] == 0, "Select must not arm hearts in K-M"


def test_heart_speeds_are_unchanged_for_the_original_levels():
    """The original formula must be untouched for levels 0-20: a normal heart
    game saturates at level-20 speed from in-game level 10 onward."""
    for level, expected in ((0, 10), (5, 15), (9, 19), (12, 20), (19, 20)):
        with Tetris(ROM) as t:
            t.start_game_at(level, hearts=True)
            assert t.gravity() == GRAVITY_TABLE[expected], (
                f"heart level {level}: expected level {expected} speed"
            )


def test_hearts_indicator_shows_when_armed_at_the_title_screen():
    """The layout is copied over the screen after our init runs, so the
    indicator is painted a frame later."""
    with Tetris(ROM) as t:
        t.to_level_select(hearts=True)
        assert t[HEART_CELL] == TILE_HEART, "indicator missing for title-armed hearts"


def test_selected_letter_blinks_at_the_original_cadence():
    """The cursor sprite draws the character for the level, and the ROM only has
    those sprite specs for digits 0-9 - on a letter bank it drew a digit over a
    letter. The sprite is hidden and the letter blinks instead, at the
    original's own 16-frame cadence. See docs/decisions/0003.
    """
    with Tetris(ROM) as t:
        goto(t, 1, 0)
        assert t[0xC200] == 0x80, "cursor sprite should be hidden on a letter bank"

        seen = []
        for _ in range(70):
            t.tick(1)
            seen.append(t[CELLS[0]])
        assert 0x0A in seen, "letter never drawn"
        assert TILE_BLANK in seen, "letter never blanked - no blink"

        runs = []
        for v in seen:
            if not runs or runs[-1][0] != v:
                runs.append([v, 1])
            else:
                runs[-1][1] += 1
        full = [n for _, n in runs[1:-1]]        # ignore partial runs at the ends
        assert full and all(n == 16 for n in full), (
            f"expected 16-frame phases, got {full}"
        )


def test_bank_change_lands_on_the_top_row():
    """Falling off the bottom of a bank should land on the top row of the next,
    not on the bottom row you just left."""
    with Tetris(ROM) as t:
        goto(t, 0, 7)
        t.press("down")
        assert t[wGymLevelBank] == 1
        assert t[hATypeLevel] < 5, (
            f"expected the top row after a bank change, got cell {t[hATypeLevel]}"
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
