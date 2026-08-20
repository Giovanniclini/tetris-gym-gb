# Reverse engineering the community's ROM hacks

**Status:** 2026-08-20. Derived by applying the patches pinned in the GBTetris Discord's
`#romhacks-modify` channel to our own byte-exact reference build and diffing the result.

**No ROM or patch data is stored in this repository.** The patches were analysed locally; only
findings are recorded here.

---

## 1. Method

Every community hack is a UPS or BPS patch against **Tetris (World) (Rev A)**, and
`build.py --original` reproduces that ROM byte-exactly. So:

```
build.py --original  →  reference ROM  →  apply community patch  →  diff  →  map to symbols
```

`tools/patch.py` implements both patch formats; `tools/analyze_hack.py` does the diff and maps each
changed run to the nearest preceding symbol from `rgblink`'s `.sym` output.

```
python3 build.py --original
python3 tools/analyze_hack.py /path/to/patch.ups
```

**Every one of the seven patches declares source CRC `46DF91AD`** — byte-for-byte our reference
build. That is independent confirmation of two things: v1.1 is definitively the community's base
(closing §7 A3 for good), and our build is exactly the ROM every community hack is built on.

## 2. Inventory

| Patch | Format | Target CRC | Changed | What it is |
| --- | --- | --- | --- | --- |
| `L-and-pushdown-fixed-2.ups` | UPS | `11261002` | 20 870 B / 80 regions | **The KLM ROM** — level K/L/M starts, score uncap, pushdown fix |
| `seeded.ups` | UPS | `6895B5AE` | 16 127 B / 14 regions | **The SPS ROM** — deterministic piece sequences |
| `sprint-mode-40-lines.bps` | BPS | `C452417C` | 12 562 B / 6 regions | 40-line sprint with built-in timer |
| `sprint-mode-30-lines.bps` | BPS | `EEFF38DD` | 12 562 B / 6 regions | 30-line variant (superseded) |
| `tetris_ctec_gb_qual_2024.bps` | BPS | `D568AE87` | 12 545 B / 9 regions | CTEC 2024 qualification ROM |
| `Tetris_ctec-2025-qual-v3.bps` | BPS | `F32864D1` | 29 533 B / 21 regions | CTEC 2025 qualification ROM |
| `tetris-patch-tp-v2.ups` | UPS | `6C0D0D44` | 1 182 B / 61 regions | Small surgical patch (score/pushdown related) |

**All seven are 32 768 bytes with an unchanged ROM-ONLY header.** Every hack in circulation is
squeezed into the stock cartridge with no mapper — which is precisely why none of them can be a
full Gym, and why our Milestone 0.5 expansion matters.

## 3. KLM — level K/L/M

### 3.1 The gravity table is relocated and extended

Stock has 21 entries (levels 0–20) at `$1B06`, immediately followed by code. KLM needed two more, so
it **moved the table back 21 bytes to `$1AF1`** and extended it to 23 entries.

| Level | Display | Stored | Frames/row | Rows/sec |
| --- | --- | --- | --- | --- |
| 0–20 | `0`–`K` | *identical to stock* | 53 … 3 | 1.13 … 19.91 |
| **21** | **`L`** | `$01` | **2** | 29.86 |
| **22** | **`M`** | `$00` | **1** | 59.73 |

**M is the hard ceiling of the gravity mechanism, not an arbitrary choice.** The counter reloads
with `stored + 1` frames; `$00` means one row per frame, which is the fastest the engine can express.
There is no N.

This confirms the community's own figures exactly: M-J's *"L is 2 frames/row compared to level 20's
3"*, and *"26400 for tetris"* on L, which is `(21 + 1) × 1200` — the score multiplier extends
naturally with no table change.

### 3.2 Structure

Relocating the table shifted everything after it, so KLM differs from stock in **20 870 bytes across
80 regions — 64 % of the ROM** — despite being, conceptually, a handful of edits. It is a whole-binary
rewrite with no source.

**This is the concrete form of the problem this project solves.** Tolstoj's *"I tried restructuring
the code and ended up breaking the whole project"* (§3.5.8) is the inevitable outcome of maintaining
a 20 KB binary diff by hand. In a disassembly, "extend the gravity table by two entries" is two
lines, and the linker relocates everything.

## 4. SPS — the seeded ROM

### 4.1 The mechanism

The stock piece randomiser reads the hardware divider register:

```asm
$2042  F0 04        ldh  a, [rDIV]
$2044  47           ld   b, a
```

The seeded ROM replaces those two bytes with five:

```asm
$202B  CD 32 05     call $0532          ; step the PRNG
$202E  F0 A3        ldh  a, [$FFA3]     ; read the result
$2030  47           ld   b, a
```

The `+3` bytes account exactly for the code shift measured either side of the patch site.
Everything downstream — the `×4` counting loop, the OR-rejection retry, the biased distribution — is
**untouched**. Only the entropy source changed.

The same substitution is applied to `PopulateGameScreenWithRandomBlocks` (the two `rDIV` reads at
`$1B6F`/`$1B83` that generate B-type starting garbage), so **B-type garbage is seeded too**.
`ShuffleHiddenPieces2Player` keeps its `rDIV` read.

### 4.2 The PRNG

A **16-bit LFSR**, state held in otherwise-unused HRAM at `$FFA2` (high) / `$FFA3` (low):

```asm
$0532  push af / push hl
       ld   a, [$FFA2] / ld h, a        ; hl = state
       ld   a, [$FFA3] / ld l, a
       ld a,h / rra / ld a,l / rra / xor h / ld h,a
       ld a,l / rra / ld a,h / rra / xor l / ld l,a / xor h / ld h,a
       ld   a, h / ld [$FFA2], a        ; store back
       ld   a, l / ld [$FFA3], a
       pop hl / pop af / ret
```

Transcribed and simulated: **maximal-length, period 65535** for any non-zero seed.

> **`$0000` is a degenerate seed — period 1, always returns `0`.** The title screen displays
> `SEED 0000` as its default. This may be part of what nells meant by *"it's also not perfect SPS
> iirc"*. Worth raising with the community, and worth guarding against in our own implementation.

### 4.3 Seed entry and link sync

The title screen gains a **`SEED 0000`** field — a 16-bit seed as four hex digits, matching the LFSR
state width. The routine at `$0555` drives `rSB`/`rSC`, so the ROM **exchanges seeds over the link
cable**, which is what Muf meant by *"automatically synchronise SPS seeds"* (§3.5.3).

### 4.4 Recommendation: adopt this LFSR exactly

**Implement the identical LFSR with identical state semantics.** If we do, a given seed produces the
*same piece sequence* on our ROM as on theirs — so a player on the seeded ROM and a player on
TetrisGYM-GB can play the same seed against each other. For a feature whose entire purpose is
fairness between two players, **interoperability is the feature**. An objectively better PRNG that
produced different sequences would be worse.

This also supersedes the plan in `docs/architecture.md` §4.2 to seed by filling the existing
256-byte `wRandomness` table and forcing the `.predefined` branch. That approach was sound and
cheap, but it would produce **different sequences** from the ROM the community already uses, and it
inherits the 256-piece wrap problem. Hooking the entropy source is both simpler and compatible.
`docs/research.md` §8 #3 (the wrap question) is moot under this design.

## 5. The sprint / qualification ROMs

All four modify **`VBlankInterrupt` at `$0041`** — that is where the frame timer increments — and
`RST_00` at `$0001`. The 2025 CTEC ROM is much larger (29 533 B changed), consistent with Pascal's
description of a purpose-built, zero-configuration qualification ROM (§3.5.4).

Not yet decoded in detail. Before implementing our own timer we still need the exact start/stop
semantics (§7 A15) — Tolstoj's *"stops the timer one frame after the piece locks"* — because a timer
that disagrees by a frame makes results incomparable.

## 6. Cross-cutting observations

* **A shared base.** KLM and the seeded ROM contain several identical small edits — `$0049`
  (`LCDCInterrupt`), `$0076`, `$00C9`, `$019A-$01D9` (64 B in `VBlankInterruptHandler`), `$0298`,
  `$02A1`. They descend from a common ancestor hack. Notably `$0049` replaces the stubbed LCD STAT
  interrupt vector with a real handler.
* **No hack combines features.** KLM has levels but no SPS; the seeded ROM has SPS but *"only basic
  level starts"* (nells). They cannot be merged because each is a whole-binary rewrite against the
  same stock ROM. **In a disassembly they are simply two source files.** This is the single clearest
  argument for the project.
* **Everything is cramped into 32 KB.** No hack uses a mapper, which caps how far any of them can go.

## 7. What this changes

| Was | Now |
| --- | --- |
| M1 scoped to levels 0–20 (A–K) because L/M were unknown | **A–M is fully specified.** Extend the table to 23 entries; L=`$01`, M=`$00` |
| SPS design: fill `wRandomness`, force `.predefined` | **Replace the `rDIV` read with the community's exact LFSR**, for seed compatibility |
| 256-piece wrap an open question | Moot — we no longer use the table |
| v1.1 the community standard "on technical grounds" | Proven: all seven patches target CRC `46DF91AD` |
