# Vendored disassembly — provenance

This directory is a **verbatim copy** of the `disasm/` subtree of an upstream
Game Boy Tetris disassembly. It is vendored, **not forked**.

| | |
| --- | --- |
| Upstream | <https://github.com/vinheim3/tetris-gb-disasm> |
| Pinned commit | `af54544fe292464055dc1d32490e48c4f998c9d9` (2023-01-19) |
| Licence | MIT — Copyright © 2023 Daniel Jianoran (see `LICENSE`) |
| Target ROM | Tetris (World) (Rev A), "v1.1" |
| SHA-1 | `74591cc9501af93873f9a5d3eb12da12c0723bbc` |
| MD5 | `982ed5d2b12a0377eb14bcdc4123744e` |
| Coverage | 100 % — upstream `coverage.txt` reports 0 bytes remaining |

Note that the upstream MIT licence covers the author's annotation and
organisation work. It cannot grant rights over the underlying game content,
which remains copyrighted. See `docs/research.md` §7.

## Local deviations from upstream

Eleven, all minimal. `build.py --original` still reproduces the stock ROM byte-exactly.

Only three categories of deviation are ever permitted, and every one must be
listed in the table below with a justification (see `docs/architecture.md` §3.1):

1. **Toolchain migration** — syntax required by the pinned RGBDS version.
   Must not change a single output byte.
2. **Section splitting** — e.g. splitting the monolithic `include/wram.s` into
   named per-purpose sections so the linker reports real free space.
   Must not change a single output byte.
3. **Hook insertion points** — declared in `src/hooks/hooks.inc`. These *do*
   change bytes, and each is enumerated and counted by `tests/`.

| # | File | Change | Category | Why | Bytes changed |
| --- | --- | --- | --- | --- | --- |
| 1 | `code/bank_000.s` | `IF GYM` include of `hooks/trampoline.inc` immediately before `ds $100-@, $ff` | 3 (hook) | The entry-point padding at `$00DA-$00FF` is the only free space in bank 0. The far-call trampoline must live in bank 0 because the caller may execute from any bank. | 22 of 38 available, `$00DA-$00EF`. Zero when `GYM=0`. |
| 2 | `include/wram.s` | Split the monolithic `$C000-$DFFC` section, starting a new `"WRAM Audio"` section at `$DF70` | 2 (section split) | Upstream declares all of WRAM as one section, so the linker cannot see the 2062-byte gap at `$D762-$DF6F`. No label moves. (The game does reach the first 351 bytes of that gap - its high score indexing runs off the end of the table for levels above the grid - which is why the Gym continues the table there rather than treating the space as free. See `docs/decisions/0006`.) | **0** — WRAM is not in the ROM image |
| 3 | `code/bank_000.s` | `IF GYM` include of `gym/gravity.inc` into the `ds $28-@, $ff` padding, and the `ld hl, .framesData` operand redirected to it | 3 (hook) | Levels L (21) and M (22) need a 23-entry gravity table. Placing it in reclaimed padding and redirecting the pointer avoids shifting bank 0. KLM achieves the same feature by relocating the table, which moves every byte after it — 20 870 bytes changed versus our 25. | 23 (table) + 2 (pointer operand). Zero when `GYM=0`. |
| 4 | `code/inGameFlow.s` | `IF GYM` raises the level-up cap from `$14` to `MAX_LEVEL` (`$16`) | 3 (hook) | With L and M selectable, a level-up from an L start would otherwise run past the end of the gravity table and read code as gravity values. **KLM has this bug** — it adds L and M but leaves the cap at `$14`. Latent (an L start needs ~220 lines to level up) but wrong. | 1. Zero when `GYM=0`. |
| 5 | `code/bank_000.s` | `IF GYM` swaps two entries of `ProcessGameState`'s jump table (`$10` A-type select init, `$11` main) for `GymStateHook` | 3 (hook) | Routes the level-select screen through Gym code, which runs its own logic and then chains to the original handler. The handlers themselves are unmodified. | 4 (two `dw` entries). Zero when `GYM=0`. |

| 6 | `code/bank_000.s` | `IF GYM` redirects the `jp z, Reset` inside `InGameCheckResetAndPause` to `GymResetStub`, and adds the stub to the `ds $40-@, $ff` padding | 3 (hook) | Instant restart. This is the reset check that fires while gameplay is ticking. | 2 (operand) + 8 (stub). Zero when `GYM=0`. |
| 7 | `code/bank_000.s` | `IF GYM` turns MainLoop's `jp z, Reset` into `call z, GymResetStub` | 3 (hook) | The ROM has **two** soft-reset checks. The in-game one goes quiet during the restart's own init frames, and this one would reboot us a moment later. `call` so the Gym can decline. | 3. Zero when `GYM=0`. |
| 8 | `code/bank_000.s` | `IF GYM` routes the `$04` jump-table entry (end-of-game screen) through `GymStateHook` | 3 (hook) | That handler treats Start as "back to the level select", and Start is part of the reset combination - so by the time either soft-reset check runs the state has moved on and we would reboot. Catching it here is what makes "top out, go again" work. | 2. Zero when `GYM=0`. |
| 9 | `code/inGameFlow.s`, `code/bank_000.s` | `IF GYM` replaces `ldh a, [rDIV] / ld b, a` with `call GymRandom` at the piece generator and at B-type's garbage draw | 3 (hook) | SPS. Three bytes for three, so nothing shifts. `GymRandom` returns the value in B exactly as those instructions did, and returns `rDIV` unchanged when SPS is off, so everything downstream — the counting loop, the OR-rejection retry and its bias — is untouched. | 3 + 3. Zero when `GYM=0`. |
| 10 | `code/bank_000.s` | `IF GYM` routes the `$15` jump-table entry (high score name entry) through `GymStateHook` | 3 (hook) | So the reset combination restarts the drill from the name entry screen instead of rebooting. Abandoning the score is the point — when you are drilling you want another go, not a leaderboard entry. | 2. Zero when `GYM=0`. |
| 11 | `code/bank_000.s` | `IF GYM` routes the `$0A` jump-table entry (in-game init) through `GymStateHook` | 3 (hook) | Loads the configured seed into the LFSR at the start of every game. Without it an instant restart would continue the sequence rather than repeat it, which defeats the point of a seed. | 2. Zero when `GYM=0`. |

## What was not vendored

Upstream's `web/` visualiser, `tools/`, `coverage.txt` and `README.md` are not
needed to build and were left out. Fetch them from upstream if useful — the
visualiser in particular is a handy reference for screen layouts and sprites.
| 13 | `code/bank_000.s` | `IF GYM` routes the `$00` jump-table entry (in-game main) through `GymStateHook` | 3 (hook) | The one per-frame gameplay hook. Trainers that must act while a game runs all land here rather than adding a hook each; the transition trainer needs it because the original's in-game init clears the line count after any earlier hook could set it. | 2. Zero when `GYM=0`. |
| 15 | `code/bank_000.s` | `IF GYM` routes the `$24` jump-table entry (copyright screen) through `GymStateHook`, which goes straight to the title init | 3 (hook) | 8.5 s before the menu on every boot of a ROM whose point is that you restart it constantly. Its only lasting effect is copying `DemoPieces` into `wDemoOrMultiplayerPieces`, which only the attract demo reads — 2-player shuffles its own table into it at `$068C`, and the tile data comes from `$06` either way. Boot to the menu: 9.8 s → 1.3 s. | 2. Zero when `GYM=0`. |
| 16 | `code/bank_000.s` | `IF GYM` routes the `$07` jump-table entry (title screen) through `GymStateHook` | 3 (hook) | The title screen becomes the Gym menu. It has to be **this** state: `SerialFunc0_titleScreen` (`$0078`) only assigns a multiplayer role while `hGameState` is `$07`, and bounces the game back to the title from anywhere else — so the menu must also keep sending the passive ping the screen it replaced was sending. See `docs/decisions/0007`. | 2. Zero when `GYM=0`. |
