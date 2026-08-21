# 7. The Gym menu is TetrisGYM's list, on the screen the game already had

**Status:** accepted, 2026-08-21 (Milestone 2)

## Context

Trainers need somewhere to be chosen from. Until now there were two features and
both fitted beside the level grid (ADR 0003); a list of trainers does not.

TetrisGYM solves this with **one scrolling list**
(`src/gamemode/gametypemenu/menu.asm`): playable modes first, settings after,
each row carrying its own value edited in place. `TETRIS` is row 0 and `B-TYPE`
is row 6 of the same list — there is no A/B branch. Start is ignored on rows
past `MODE_GAME_QUANTITY`, which is how modes and settings are separated.

## Decision

**Mirror that list, on the original's A-TYPE/B-TYPE screen.** That screen is
already "what do you want to play", and it is the only menu the game has. The
Gym redraws its tilemap and handles its own input; the original handler never
runs. One two-byte jump-table redirect, nothing shifts.

Rows: `TETRIS`, `B-TYPE`, `TRANSITION`, `SEED`, `MUSIC`. Up/Down move,
Left/Right edit the row's value, Start or A launches. `SEED` and `MUSIC` are
settings, so Start does nothing on them — the same split TetrisGYM draws.

**The seed lives here, not on the level select.** It is configuration, not part
of choosing a level, and TetrisGYM keeps it on the menu row too. The level
select is back to a level picker and nothing else.

**`SEED` borrows the D-pad.** Four digits need a cursor, so A opens the row and
A or Start closes it; while open, Left/Right pick a digit and Up/Down change it,
with the active one blinking. TetrisGYM leaves Up and Down free for its list
because it scrolls under a throttle; ours does not, so the row has to be
explicitly entered.

**ADR 0003 still stands.** It rejected a menu *for the level picker*, which
belongs on the level select. This is a different screen and a different job:
choosing the drill, not configuring it.

## Where the source of truth is

**NES TetrisGYM specifies how a trainer behaves. Game Boy evidence decides which
trainers exist.** Both halves matter, and `docs/community-research.md` has an
example of getting it wrong in each direction: the transition trainer was first
marked DROP because *"GB has no level-19/29 transition wall"* — NES-shaped
reasoning that binned the highest-value feature in the matrix — while a faithful
port would ship a killscreen trainer for a game whose speed caps at level 20.

About a third of TetrisGYM's list does not survive the crossing: no T-spin
scoring, no killscreen, one timing domain, no NES crash bug. Hard drop is out of
scope by decision (CLAUDE.md §12).

## The first trainer: TRANSITION

Chosen by community evidence — §6.2 ranks it third behind SPS and the level
select, both already done, and it is the one thing a practitioner named
unprompted as *"the most annoying thing"* in their routine.

**`TRANSITION` carries its own level and starts the game directly**, with no
level select in between — a drill you set up once and repeat, which is the whole
point of it. Instant restart then re-runs the same drill for free, because the
mode is still selected.

`transitionModeSetup` (`src/gamemodestate/initstate.asm`) fills the line counter
up to the last ten-line boundary before the level advances. The Game Boy's
transition is that boundary: the original treats the start level as the number
of tens to clear, so a level 9 start transitions at 100 lines and the drill
begins at 90.

**One deliberate divergence: no score preset.** TetrisGYM's modifier sets a
starting score so the score and pace readouts look like a real run at that
point. The Game Boy has no pace display, and its transition point moves with the
start level rather than being fixed at 19 — so the number has nothing to mean
here. The level comes from the level picker instead, where the Game Boy already
puts it.

## Consequences

* **A per-frame gameplay hook now exists** (`$00`, `HOOK_STATE_TABLE00`). The
  transition trainer needs it because the original's in-game init clears the
  line counter *after* any earlier hook could set it — verified in an emulator,
  not assumed. Trainers that act during play all land here rather than adding a
  hook each, which is what keeps the count from growing per feature.
* **The original A-TYPE/B-TYPE screen is gone**, and with it the combined music
  selector it shared. `MUSIC` is a menu row instead. The artwork stays in the
  ROM, unreferenced.
* **The menu repaints on entry, not per frame**, with the LCD off, as the
  original does for every screen change. No VBlank cost.
* **The line readout must be repainted by hand.** The original only redraws it
  on a line clear, so a drill would otherwise show `000` until the first one.
* **Every tilemap cell the Gym paints with the LCD on goes through
  `StoreAinHLwhenLCDFree`.** The hardware drops writes made while a line is being
  drawn, and the original's helpers do not guard against it —
  `DisplayBCDNum2CDigits` writes with a bare `ld [hl+], a` because it is only
  ever called with the LCD idle, so the Gym renders the line count itself rather
  than calling it.

  This cost three bugs that looked unrelated: a menu cursor that vanished at
  random, a line count that read `0`, `10` or `20` instead of `90`, and a music
  letter that never changed. Waiting for VBlank once and then painting is *not*
  enough — the window is ten lines and the last cells painted fall outside it,
  which is why the music letter, painted last, was the one that stayed stale.

  **PyBoy does not enforce VRAM blocking, so none of them failed a test.** Only
  hardware-accurate timing shows them. Treat any "it works in the tests but not
  on screen" report as this until proven otherwise.
