"""Headless emulator harness for behavioural tests.

Byte-level tests prove the ROM *contains* the right values. They cannot prove
the game *uses* them - a broken hook can leave every byte correct. This drives
the ROM in an emulator so tests can press buttons, run frames and read memory.

Requires PyBoy, a test-only dependency:

    python3 -m venv .venv && .venv/bin/python -m pip install pyboy
    .venv/bin/python tests/test_behaviour.py

`build.py` deliberately keeps no dependencies at all, so a bare machine can
still build the ROM.
"""

import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Silence PyBoy's optional-dependency chatter before importing it.
os.environ.setdefault("PYBOY_DISABLE_SDL2_WARNING", "1")

try:
    from pyboy import PyBoy
except ImportError:  # pragma: no cover
    raise SystemExit(
        "PyBoy not installed. See the module docstring:\n"
        "  python3 -m venv .venv && .venv/bin/python -m pip install pyboy"
    )

# --- game state machine (src/original/include/constants.s) -----------------
GS_IN_GAME_MAIN = 0x00
GS_TITLE_SCREEN_MAIN = 0x07
GS_GAME_TYPE_MAIN = 0x0E
GS_MUSIC_TYPE_MAIN = 0x0F
GS_A_TYPE_SELECTION_INIT = 0x10
GS_A_TYPE_SELECTION_MAIN = 0x11
GS_IN_GAME_INIT = 0x0A

# --- addresses we assert on (src/original/include/hram.s) ------------------
hButtonsPressed = 0xFF81
hPieceFallingState = 0xFF98
hNumFramesUntilCurrPieceMovesDown = 0xFF99   # counts down
hNumFramesUntilPiecesMoveDown = 0xFF9A       # reload value == gravity
hNumLinesCompletedBCD = 0xFF9E
hStickyButtonCounter = 0xFFAA                # DAS counter
hGameType = 0xFFC0
hATypeLevel = 0xFFC2
hGameState = 0xFFE1
hIsHardMode = 0xFFF4

BOOT_TIMEOUT = 2000     # frames; the copyright screens alone are ~500


def sym(name, rom="build/tetrisgym.sym"):
    """Address of a label, read from the linker's symbol file.

    Gym RAM moves as the layout changes; a test that hardcodes an address
    silently asserts on the wrong byte when it does.
    """
    path = ROOT / rom
    for line in path.read_text().splitlines():
        parts = line.split()
        if len(parts) == 2 and parts[1] == name:
            return int(parts[0].split(":")[1], 16)
    raise KeyError(f"{name} not in {path}")


class Tetris:
    """A running Game Boy Tetris, driven a frame at a time."""

    def __init__(self, rom="build/tetris.gb"):
        path = ROOT / rom if not os.path.isabs(rom) else Path(rom)
        if not path.exists():
            raise SystemExit(f"{path} not found - run `python3 build.py` first")
        self.pb = PyBoy(str(path), window="null", sound_emulated=False, log_level="ERROR")
        # The Gym replaces the title screen, so hearts move from the original's
        # hidden Down+Start there to Select on the level select.
        self.is_gym = "tetrisgym" in path.name

    # -- primitives ---------------------------------------------------------

    def tick(self, frames=1):
        for _ in range(frames):
            self.pb.tick()

    def __getitem__(self, addr):
        return self.pb.memory[addr]

    @property
    def state(self):
        return self.pb.memory[hGameState]

    def press(self, *buttons, hold=2, release=2):
        """Tap buttons. The menus read hButtonsPressed (edge-triggered), so a
        button must be seen down for a frame and then released."""
        for b in buttons:
            self.pb.button_press(b)
        self.tick(hold)
        for b in buttons:
            self.pb.button_release(b)
        self.tick(release)

    def hold(self, *buttons):
        for b in buttons:
            self.pb.button_press(b)

    def release(self, *buttons):
        for b in buttons:
            self.pb.button_release(b)

    def run_until(self, predicate, limit=BOOT_TIMEOUT, what="condition"):
        for _ in range(limit):
            self.pb.tick()
            if predicate():
                return
        raise AssertionError(f"timed out after {limit} frames waiting for {what}")

    def run_until_state(self, target, limit=BOOT_TIMEOUT):
        self.run_until(lambda: self.state == target, limit,
                       f"hGameState == ${target:02X} (currently ${self.state:02X})")

    # -- navigation ---------------------------------------------------------

    def to_title(self):
        """Boot to the Gym menu, which lives on the title screen's state.

        The copyright screen is skipped and the 1P/2P screen is the menu now;
        see docs/decisions/0007. On the stock ROM this still reaches the real
        title screen, which is what the comparison tests want.
        """
        self.run_until_state(GS_TITLE_SCREEN_MAIN)

    def to_menu(self):
        self.to_title()
        self.tick(20)
        return self

    def to_level_select(self, hearts=False):
        """Gym menu -> TETRIS -> the A-TYPE level select.

        `hearts` presses Select once there, which is how the Gym arms hard mode
        (the original's hidden Down+Start lived on the screen the menu replaced).
        """
        self.to_menu()
        if hearts and not self.is_gym:
            self.hold("down")                     # the original's hidden combo
            self.press("start")
            self.release("down")
        else:
            self.press("start")                   # TETRIS is the first row
        # The stock ROM still has the A-TYPE/B-TYPE screen in between.
        self.run_until(lambda: self.state in (GS_A_TYPE_SELECTION_MAIN,
                                              GS_GAME_TYPE_MAIN),
                       what="a level select or the game type screen")
        if self.state == GS_GAME_TYPE_MAIN:
            self.press("start")
            self.run_until_state(GS_A_TYPE_SELECTION_MAIN)
        self.tick(20)             # the picker defers its first paint a frame
        if hearts and self.is_gym:
            self.press("select")

    def start_game_at(self, level, hearts=False):
        """Reach gameplay at a chosen level. Writes hATypeLevel directly rather
        than driving the cursor, so this works for levels the menu cannot yet
        reach."""
        self.to_level_select(hearts=hearts)
        self.pb.memory[hATypeLevel] = level
        self.press("start")
        self.run_until_state(GS_IN_GAME_MAIN)

    # -- measurements -------------------------------------------------------

    def gravity(self):
        """Frames per row, read from the reload value the game computed."""
        return self[hNumFramesUntilPiecesMoveDown] + 1

    def measure_gravity(self, max_frames=400):
        """Observed frames between two gravity steps - the behavioural check,
        independent of what any table says."""
        prev = self[hNumFramesUntilCurrPieceMovesDown]
        gaps, last_reload = [], None
        for f in range(max_frames):
            self.pb.tick()
            cur = self[hNumFramesUntilCurrPieceMovesDown]
            if cur > prev:                        # counter reloaded == a row fell
                if last_reload is not None:
                    gaps.append(f - last_reload)
                last_reload = f
                if len(gaps) >= 2:
                    break
            prev = cur
        return gaps

    def close(self):
        self.pb.stop(save=False)

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        self.close()
