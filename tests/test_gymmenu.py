#!/usr/bin/env python3
"""The Gym menu, and the transition trainer it launches.

    .venv/bin/python tests/test_gymmenu.py

The menu replaces the original A-TYPE/B-TYPE screen. See docs/decisions/0007.
"""

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from tools.emu import (Tetris, sym, hATypeLevel,  # noqa: E402
                       hNumLinesCompletedBCD, GS_IN_GAME_MAIN)

ROM = "build/tetrisgym.gb"

GS_GAME_TYPE_MAIN = 0x0E
GS_A_TYPE_SELECTION_MAIN = 0x11
GS_B_TYPE_SELECTION_MAIN = 0x13

hGameType = 0xFFC0
hMusicType = 0xFFC1
hATypeLinesThreshold = 0xFFA9              # the live level
LINES_LO, LINES_HI = hNumLinesCompletedBCD, hNumLinesCompletedBCD + 1

GAME_TYPE_A, GAME_TYPE_B = 0x37, 0x77
MUSIC_A, MUSIC_OFF = 0x1C, 0x1F

MODE_TETRIS, MODE_BTYPE, MODE_TRANSITION, MODE_SEED, MODE_MUSIC = 0, 1, 2, 3, 4

wGymMode = sym("wGymMode")

TILE_BLANK = 0x2F


def text(t, row, cols=range(20)):
    """Read a tilemap row back as text. The font puts 0-9 at $00 and A-Z at $0A."""
    out = ""
    for c in cols:
        v = t[0x9800 + row * 32 + c]
        if v == TILE_BLANK:
            out += " "
        elif v <= 0x09:
            out += chr(ord("0") + v)
        elif 0x0A <= v <= 0x23:
            out += chr(ord("A") + v - 0x0A)
        elif v == 0x25:
            out += "-"
        elif v == 0x26:
            out += "*"
        else:
            out += "?"
    return out.rstrip()


def to_menu(t):
    t.to_title()
    t.press("start")
    t.run_until_state(GS_GAME_TYPE_MAIN)
    t.tick(20)
    return t


def to_menu_row(t, row):
    to_menu(t)
    for _ in range(row):
        t.press("down")
    assert t[wGymMode] == row, f"wanted row {row}, cursor is on {t[wGymMode]}"
    return t


def test_the_menu_replaces_the_game_type_screen():
    with Tetris(ROM) as t:
        to_menu(t)
        rows = [text(t, r) for r in range(18)]
        joined = "\n".join(rows)
        for want in ("TETRIS GYM", "TETRIS", "B-TYPE", "TRANSITION", "SEED", "MUSIC"):
            assert want in joined, f"{want!r} missing from the menu:\n{joined}"
        assert "A-TYPE" not in joined, "the original screen is still showing"


def test_the_cursor_moves_and_wraps():
    with Tetris(ROM) as t:
        to_menu(t)
        assert t[wGymMode] == MODE_TETRIS, "should open on the first row"
        t.press("up")
        assert t[wGymMode] == MODE_MUSIC, "Up from the first row should wrap"
        t.press("down")
        assert t[wGymMode] == MODE_TETRIS, "Down from the last row should wrap"


def test_tetris_launches_the_a_type_level_select():
    with Tetris(ROM) as t:
        to_menu_row(t, MODE_TETRIS)
        t.press("start")
        t.run_until_state(GS_A_TYPE_SELECTION_MAIN)
        assert t[hGameType] == GAME_TYPE_A, f"game type is ${t[hGameType]:02X}"


def test_b_type_launches_the_b_type_level_select():
    with Tetris(ROM) as t:
        to_menu_row(t, MODE_BTYPE)
        t.press("start")
        t.run_until_state(GS_B_TYPE_SELECTION_MAIN)
        assert t[hGameType] == GAME_TYPE_B, f"game type is ${t[hGameType]:02X}"


def test_the_seed_row_opens_its_digits_with_a():
    with Tetris(ROM) as t:
        to_menu_row(t, MODE_SEED)
        idle = t[sym("wGymSeedDigit")]
        assert idle == 0xFF, f"should start closed, got {idle}"
        t.press("a")
        assert t[sym("wGymSeedDigit")] == 0, "A should open the first digit"
        t.press("right")
        assert t[sym("wGymSeedDigit")] == 1, "Right should step to the next digit"
        t.press("a")
        assert t[sym("wGymSeedDigit")] == 0xFF, "A should close the digits"
        assert t.state == GS_GAME_TYPE_MAIN, "A on a setting started something"


def test_music_is_a_setting_not_a_mode():
    """TetrisGYM splits its list at MODE_GAME_QUANTITY: rows past it configure
    the game rather than starting one. Start must do nothing here."""
    with Tetris(ROM) as t:
        to_menu_row(t, MODE_MUSIC)
        seen = []
        for _ in range(5):
            seen.append(t[hMusicType])
            t.press("right")
        assert seen == [MUSIC_A, MUSIC_A + 1, MUSIC_A + 2, MUSIC_OFF, MUSIC_A], (
            f"music should cycle A/B/C/OFF and wrap, saw {[hex(x) for x in seen]}"
        )
        t.press("start")
        t.tick(10)
        assert t.state == GS_GAME_TYPE_MAIN, (
            f"Start on a setting started something (state ${t.state:02X})"
        )


def _run_drill(t, level):
    """The row carries its own level and starts the game directly - a drill you
    set up once and repeat, with no level select in between."""
    to_menu_row(t, MODE_TRANSITION)
    for _ in range(level):
        t.press("right")
    assert t[sym("wGymDrillLevel")] == level, "the row did not take the level"
    t.press("start")
    t.run_until_state(GS_IN_GAME_MAIN)
    t.tick(25)
    assert t[hATypeLevel] == level, f"started on level {t[hATypeLevel]}"
    return int(f"{t[LINES_HI]:02X}{t[LINES_LO]:02X}")   # BCD -> decimal


def test_transition_starts_ten_lines_short_of_the_level_up():
    """The game levels up when lines/10 exceeds the level, so a level 9 start
    transitions at 100. TetrisGYM lands you on the last ten-line boundary
    before that; here that is 90."""
    for level in (5, 9, 12, 18, 22):
        with Tetris(ROM) as t:
            got, want = _run_drill(t, level), level * 10
            assert got == want, (
                f"level {level}: transitions at {(level + 1) * 10} lines, "
                f"drill should start at {want}, got {got}"
            )
            assert t[hATypeLinesThreshold] == level, "the drill changed the level"


def test_transition_at_level_zero_preloads_nothing():
    with Tetris(ROM) as t:
        assert _run_drill(t, 0) == 0, "level 0 transitions at 10; nothing to skip"


def test_the_lines_readout_is_repainted():
    """The original only redraws the line count on a clear, so the drill has to
    paint it itself or the game shows 000 until the first one."""
    with Tetris(ROM) as t:
        _run_drill(t, 9)
        assert text(t, 10, range(14, 18)).strip() == "90", (
            f"LINES reads {text(t, 10, range(14, 18))!r}, expected 90"
        )


def test_a_plain_tetris_game_is_not_a_drill():
    with Tetris(ROM) as t:
        to_menu_row(t, MODE_TETRIS)
        t.press("start")
        t.run_until_state(GS_A_TYPE_SELECTION_MAIN)
        t.tick(6)
        t.pb.memory[hATypeLevel] = 9
        t.press("start")
        t.run_until_state(GS_IN_GAME_MAIN)
        t.tick(20)
        assert t[LINES_HI] == 0 and t[LINES_LO] == 0, "TETRIS preloaded lines"


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
