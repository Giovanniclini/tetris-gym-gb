# 2. Hook by redirecting pointers, never by inserting bytes

**Status:** accepted, 2026-08-20

## Context

Adding anything to the original banks shifts every byte after the insertion
point. That is what makes the community's existing hacks unmaintainable: KLM
adds two entries to the gravity table by relocating it, and the result differs
from stock in **20 870 bytes across 80 regions**, two thirds of the ROM
(`docs/existing-hacks.md` §3.3).

## Decision

Never insert into banks 0 or 1. Instead:

1. Put new code and data in **reclaimed padding** (bank 0) or **bank 2+**.
2. Change only **pointer operands, constants and jump-table entries** in place,
   so nothing moves.

## Why

It keeps the byte-level diff small enough to enumerate, which in turn keeps
`tests/test_expansion.py` meaningful: it asserts that the set of differing
bytes in banks 0-1 is *exactly* the declared hook table. That test is what makes
future restructuring safe — the failure mode that broke KLM's own author.

## Consequences

* The same feature costs 54 bytes instead of 20 870 (**386× smaller**).
* Every hook must be declared in `src/hooks/hooks.inc` and mirrored in
  `tests/test_expansion.py`. An undeclared byte fails the build.
* Bank-0 padding is a scarce, shared resource. Known regions:
  `$000B-$0027` (29 B, holds the gravity table), `$0034-$003F` (12 B, free),
  `$00DA-$00FF` (38 B, holds `FarCall` + `GymStateHook`).
* When new data is too large for padding it goes in bank 2, reached through
  `FarCall` — which means it cannot be read by original code still running in
  bank 1. Plan for that before choosing a location.
