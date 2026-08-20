# 5. Instant restart hooks three places, not one

**Status:** accepted, 2026-08-20 (Milestone 1)

## Context

`A+B+Select+Start` is the original's soft reset: back through the Nintendo logo,
two copyright screens, the title, the game type menu and the level select.
Around fifteen seconds to resume the drill you were on. A training ROM needs
that to be a restart.

## Decision

During a game or its aftermath, restart at the same level and hearts by setting
`hGameState` to `GS_IN_GAME_INIT` - exactly what the level select does when you
press Start. Everywhere else, reboot as the original does. Link play always
reboots: restarting one side would desync the cable.

## Why three hooks

This looked like a one-byte change and was not. Each hook exists because a
different piece of the original gets to the buttons first.

1. **`InGameCheckResetAndPause` (`$1C14`)** - gameplay has its *own* reset
   check, separate from MainLoop's, and it is the one that fires while playing.
   Hooking MainLoop alone does nothing: this one reaches `Reset` first.
2. **`MainLoop` (`$02D3`)** - runs every frame regardless of state. The in-game
   check goes quiet during the restart's own init frames, so this one would
   reboot us a moment later. Hooked with `call` rather than `jp` so the Gym can
   decline and let the loop carry on.
3. **The `$04` jump-table entry** - the end-of-game screen treats Start as "back
   to the level select", and Start is part of the combination. By the time
   either reset check runs, the state has already moved to `$10` and we would
   reboot. Catching it in the state dispatch is what makes "top out, go again"
   work - the case a trainer needs most.

## Consequences

* **A flag, not a state test, marks our restart.** `wGymRestarting` distinguishes
  "the Gym restarted the game" from "the level select started a game", which
  reach the same `GS_IN_GAME_INIT`. Pressing the combination on a menu presses
  Start too, so the menu starts a game on the way past; without the flag that
  would be mistaken for a restart and the menu would stop rebooting.
* **The buttons are consumed** (`hButtonsHeld` cleared) so the second check does
  not undo the first. `PollInput` refills it next frame.
* **The in-game hook stays a `jp`.** Its `ret` unwinds to whoever called
  `.start`, which skips the pause check sitting directly after the reset check -
  Start is part of the combination, so returning normally would pause the game
  we just restarted.
* Restart covers `$00` playing, `$01` game-over init, `$0D` screen clearing and
  `$04` end-of-game. High-score entry is deliberately left alone so scores can
  still be entered.
* **You get the level you chose, not the level you reached.** `hATypeLevel`
  (`$FFC2`) holds the menu choice and is never written during play;
  `hATypeLinesThresholdToPassForNextLevel` (`$FFA9`) is the live level and
  climbs with the line count. Re-running the init copies the former into the
  latter, so starting on 8 and levelling to 9 restarts on 8. That is the right
  default for a trainer - "again" means the drill you set up. Restarting at the
  level reached would be a separate option, not this one.

## What this cost to find

Four wrong diagnoses, in order: the hook had not been applied (it had); the
handler was broken (it was not); re-entering `GS_IN_GAME_INIT` from gameplay was
unsafe (it is fine - proved by poking the state into the *stock* ROM); and the
emulator had input latency (it does, but that was not it). The actual answer
each time was another piece of the original reaching the buttons first.

**The lesson: when a hook appears not to fire, find every place the original
handles that input before assuming the hook is wrong.** A marker byte in WRAM is
the cheap way to tell - though note `Reset` clears WRAM, so a marker that a
reboot has already wiped reads as "never ran".
