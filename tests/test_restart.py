#!/usr/bin/env python3
"""Instant restart: A+B+Select+Start restarts the drill instead of rebooting.

    .venv/bin/python tests/test_restart.py
"""

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from tools.emu import (Tetris, hATypeLevel, hIsHardMode,  # noqa: E402
                       GS_IN_GAME_MAIN, GS_TITLE_SCREEN_MAIN)

ROM = "build/tetrisgym.gb"
COMBO = ("a", "b", "select", "start")
hNumLinesCompletedBCD = 0xFF9E
hGamePaused = 0xFFAB

# A reboot runs the Nintendo logo and two copyright screens before the title.
REBOOT_FRAMES = 500


def combo(t, frames=4):
    for b in COMBO:
        t.pb.button_press(b)
    t.tick(frames)
    for b in COMBO:
        t.pb.button_release(b)


def wait_playing(t, limit=300):
    for f in range(limit):
        t.tick(1)
        if t.state == GS_IN_GAME_MAIN and f > 8:
            t.tick(20)
            return f
    raise AssertionError(f"never got back into play (state ${t.state:02X})")


def test_restart_is_fast():
    """The point of the feature: a drill you can repeat, not a reboot."""
    with Tetris(ROM) as t:
        t.start_game_at(18)
        t.tick(180)
        combo(t)
        frames = wait_playing(t)
        assert frames < REBOOT_FRAMES / 4, (
            f"took {frames} frames; a reboot alone is ~{REBOOT_FRAMES}"
        )


def test_restart_keeps_the_level():
    # M tops out on its own within ~96 frames, so warm up briefly there
    for level, warmup in ((5, 120), (18, 120), (22, 40)):
        with Tetris(ROM) as t:
            t.start_game_at(level)
            t.tick(warmup)
            assert t.state == GS_IN_GAME_MAIN, "test warm-up outlasted the game"
            before = t.gravity()
            combo(t)
            wait_playing(t)
            assert t[hATypeLevel] == level, (
                f"level {level} became {t[hATypeLevel]}"
            )
            assert t.gravity() == before, "gravity changed across a restart"


def test_restart_keeps_hearts():
    with Tetris(ROM) as t:
        t.start_game_at(5, hearts=True)
        t.tick(120)
        before = t.gravity()
        combo(t)
        wait_playing(t)
        assert t[hIsHardMode] != 0, "hearts lost across a restart"
        assert t.gravity() == before


def test_restart_clears_the_game():
    with Tetris(ROM) as t:
        t.start_game_at(9)
        t.tick(600)
        combo(t)
        wait_playing(t)
        assert t[hNumLinesCompletedBCD] == 0, "line count not reset"
        assert t[0xC0A0] == t[0xC0A1] == t[0xC0A2] == 0, "score not reset"


def test_restart_does_not_leave_the_game_paused():
    """Start is part of the combination, and the original's pause check sits
    directly after the reset check it replaces."""
    with Tetris(ROM) as t:
        t.start_game_at(9)
        t.tick(120)
        combo(t)
        wait_playing(t)
        assert t[hGamePaused] == 0, "restarted into a paused game"


def test_menus_still_reboot():
    """Only gameplay restarts. Everywhere else the combination must do what
    players expect, including on the level select - where Start is part of the
    combination, so the menu starts a game on the way past."""
    with Tetris(ROM) as t:
        t.to_level_select()
        t.tick(10)
        combo(t, 6)
        for _ in range(1200):
            t.tick(1)
            if t.state == GS_TITLE_SCREEN_MAIN:
                return
        raise AssertionError(f"never rebooted (state ${t.state:02X})")


def test_original_build_still_reboots_from_gameplay():
    """The GYM=0 build must keep the stock behaviour."""
    with Tetris("build/tetris.gb") as t:
        t.start_game_at(9)
        t.tick(120)
        combo(t, 6)
        for _ in range(1200):
            t.tick(1)
            if t.state == GS_TITLE_SCREEN_MAIN:
                return
        raise AssertionError(f"stock ROM did not reboot (state ${t.state:02X})")


def test_restart_works_after_topping_out():
    """The case a trainer needs most: die, go again. Game over runs
    $00 -> $01 -> $0D -> $04 before it settles, and all of those restart."""
    with Tetris(ROM) as t:
        t.start_game_at(22)                   # M tops out unaided
        for _ in range(900):
            t.tick(1)
            if t.state == 0x04:               # GS_LEVEL_ENDED_MAIN
                break
        assert t.state == 0x04, f"never reached game over (state ${t.state:02X})"
        combo(t)
        frames = wait_playing(t)
        assert frames < REBOOT_FRAMES / 4, f"took {frames} frames"
        assert t[hATypeLevel] == 22, "level lost restarting from game over"


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
