# tetris-gym-gb

**A TetrisGYM-style training and practice ROM for the original Nintendo Game Boy Tetris (1989).**

> **Status:** see [`docs/roadmap.md`](docs/roadmap.md).
> Working today: level select up to M, hearts, instant restart and SPS.

---

## What this is

[TetrisGYM](https://github.com/kirjavascript/TetrisGYM) gave the NES Tetris community a practice ROM
built on top of a disassembly of the original game: same gameplay, same timings, same feel, plus the
training tools competitive players actually need.

**Nothing equivalent exists for Game Boy Tetris.** This project builds it.

There *is* a real audience. The [Classic Tetris World Championship — Game
Boy](https://liquipedia.net/tetris/CTWCGB/2025) has run annually since 2023, organised by the
GBTetris Discord, with international qualifiers. Physical CTWC regionals run Game Boy side events —
[CTWC France 2026](https://liquipedia.net/tetris/CTWC_France/2026/Game_Boy) had 24 players and a
prize pool. [speedrun.com](https://www.speedrun.com/tetrisgb) tracks three active categories.

And their competitive formats are **not** the NES formats:

| | NES Tetris | **Game Boy Tetris** |
| --- | --- | --- |
| Tournament qualifier | A-Type score from level 18 | **40-line sprint, best time** |
| Bracket format | Score duel | **Link-cable head-to-head VS** |
| Speed ceiling | Level 29 killscreen | **Level 20 + "heart" levels (+10 speed)** |
| DAS | 16 frames + 6 | **23 frames + 9** |

So this is not a port of TetrisGYM's feature list. It is a training tool designed from what Game Boy
players actually compete at — starting with the thing the original game conspicuously lacks:
**a timer**.

## Design principle

**Preserve the original game exactly. Add training tools around it.**

The gameplay stays the original machine code — bit for bit. Gravity, DAS, ARE, the biased
randomizer, the left-handed rotation system, the 10×18 playfield, the quirks. All of it, unchanged
and *provably* unchanged: the build reproduces the original ROM byte-exactly, and that check runs on
every commit.

This is deliberately **not** a modernisation. No hold, no hard drop, no ghost piece, no SRS.
[Tetris — Rosy Retrospection](https://www.romhacking.net/hacks/5813/) already does that well, and
does not need competition.

## What it does

**Working today**

| | |
| --- | --- |
| **Level select to M** | Levels `0-9` and `A-M` from a picker beside the original grid — `M` is one row per frame, the engine's ceiling |
| **Hearts on Select** | The hidden `Down`+`Start` combination, made visible, with an indicator |
| **Instant restart** | `A+B+Select+Start` restarts the drill in ~0.15 s instead of rebooting through 15 s of logos and menus |
| **SPS** | A seed beside the level picker. Same seed, same pieces — and the same pieces as the community's own seeded ROM, so seeds are shareable |

**Next**

Transition trainer, Hz counter, floor and preset boards, low stack,
VS garbage. Ranked from community evidence in
[`docs/community-research.md`](docs/community-research.md) §6.2.

## Technical approach

| | |
| --- | --- |
| **Target ROM** | `Tetris (World) (Rev A)` — "v1.1" · MD5 `982ed5d2b12a0377eb14bcdc4123744e` · SHA-1 `74591cc9501af93873f9a5d3eb12da12c0723bbc` |
| **Foundation** | [`vinheim3/tetris-gb-disasm`](https://github.com/vinheim3/tetris-gb-disasm) (MIT, 100 % coverage) — verified to build byte-exactly |
| **Toolchain** | RGBDS v0.6.1, downloaded and SHA-256-verified into `build/`. No system-wide installs. |
| **Build** | `python3 build.py` — Python 3 stdlib only. No `make`, no `gcc`. |
| **Cartridge** | MBC1, 128 KB ROM, 8 KB battery SRAM. The original 32 KB ROM has only ~400 free bytes. |
| **Distribution** | **BPS patch only.** You supply your own ROM. |

Full reasoning in [`docs/architecture.md`](docs/architecture.md) and
[`docs/research.md`](docs/research.md).

## Requirements

**You must supply your own Game Boy Tetris ROM.** This repository does not, and will not, distribute
ROM data. Releases contain a BPS patch you apply to your own legally obtained copy of
`Tetris (World) (Rev A)`.

**On real hardware you need a flash cart** — an [EverDrive
GB](https://krikzz.com/our-products/cartridges/edgbx7.html) or an EZ-Flash Junior, which load `.gb`
files from an SD card. In emulation, [SameBoy](https://sameboy.github.io/), BGB, Emulicious and
mGBA all work with no extra hardware.

*This is not a restriction this project introduces.* A retail Game Boy Tetris cartridge contains
**mask ROM** — etched during chip fabrication and physically unwritable. A Game Genie can patch
cartridge reads at runtime on a genuine cart, but only three codes at a time, which is enough for a
level-start tweak and nowhere near enough for a Gym. Anything larger needs a flash cart.

Our expansion to an MBC1 cartridge (needed because the original 32 KB ROM has only ~400 free bytes)
therefore costs nothing to emulator, flash-cart, Analogue Pocket or MiSTer users. The only people it
affects are those building their own repro cartridges, who now need a board with an MBC1 and battery
SRAM rather than a bare 32 KB flash chip.

## Known quirk: greyscale in some emulators

Game Boy Tetris is a DMG game — it has no colour of its own. The familiar palette comes from the
Game Boy Color boot ROM, which colourises Nintendo-published games automatically.

The patched ROM keeps every input to that lookup byte-identical, so **on real Game Boy Color
hardware it colourises exactly like the original**. But some emulators — mGBA among them —
identify games by CRC32 against a database instead, and a patched ROM naturally isn't in it, so
they fall back to greyscale.

In mGBA: *Settings → Game Boy → Game Boy model → **Game Boy Color***.

## Documentation

| | |
| --- | --- |
| [`CLAUDE.md`](CLAUDE.md) | Project principles — **read first**, human or AI |
| [`docs/research.md`](docs/research.md) | TetrisGYM analysis, Game Boy Tetris internals, disassembly evaluation, hardware constraints, legal notes |
| [`docs/community-research.md`](docs/community-research.md) | Community evidence, feature matrix, top 10 |
| [`docs/architecture.md`](docs/architecture.md) | Architecture decisions, layout, memory, build, testing |
| [`docs/roadmap.md`](docs/roadmap.md) | Milestones and acceptance criteria |

## Contributing

The project is at Milestone 0. The most valuable contributions right now are **not** code:

* **Talk to the GBTetris Discord.** First contact already corrected two ranking errors and surfaced
  the community's actual blocker (SPS). The open questions are listed in
  [`docs/community-research.md`](docs/community-research.md) §7 — several are one-line answers from
  anyone who plays.
* **Catalogue the existing GB Tetris hacks**, especially the "more level starts + score digit +
  rocket skip" ROM already in general use. This project should be a clean superset of what people
  already have, not a competitor to it.
* **Search r/Tetris and r/classictetris** for Game Boy practice discussion — a known blind spot in
  the research.
* **Confirm the canonical ROM version** used by CTWC-GB and speedrun.com rules.

For code: read `CLAUDE.md`, then `docs/architecture.md` §8 (adding a trainer). The rule that matters
most is that `python3 build.py --original` must keep reproducing the original ROM byte-exactly.

## Licence and legal

Project code: MIT (planned). The vendored disassembly is MIT-licensed by its author.

**Note that an author's licence over a disassembly covers their annotation and organisation work; it
cannot grant rights over Nintendo's, TTC's or Elorg's underlying content.** Game Boy Tetris is
copyrighted. This project distributes source and patches, never ROM data, and is unaffiliated with
Nintendo, The Tetris Company or any rights holder.

## Credits

* [kirjavascript/TetrisGYM](https://github.com/kirjavascript/TetrisGYM) — the model for this project,
  and the proof the approach works
* [vinheim3/tetris-gb-disasm](https://github.com/vinheim3/tetris-gb-disasm) — the disassembly this is built on
* [kaspermeerts/tetris](https://github.com/kaspermeerts/tetris) and
  [meithecatte/gbtetris](https://github.com/meithecatte/gbtetris) — reference disassemblies whose
  documentation and memory maps informed the research
* [RGBDS](https://rgbds.gbdev.io/) and [gbdev](https://gbdev.io/) — the toolchain and the community
  that maintains it
