# 1. Lab code lives in bank 2 and can never switch banks itself

**Status:** accepted, 2026-08-20 (Milestone 0.5 / 1)

## Context

The cartridge is MBC1 with banks 0-3. Bank 0 is always mapped at `$0000-$3FFF`;
`$4000-$7FFF` holds whichever bank is selected, normally bank 1 (the original's
sound engine and data). Lab code lives in bank 2.

## Decision

**Bank switching happens only in bank-0 code.** Lab code in bank 2 must never
write the MBC register.

## Why

Bank 2 code executes from `$4000-$7FFF`. The instruction *after* a bank switch
would be fetched from the newly selected bank — i.e. from whatever happens to
sit at that address in bank 1. It is an immediate, guaranteed crash.

## Consequences

* All hooks are bank-0 stubs: switch, call, switch back. `FarCall` in
  `src/hooks/trampoline.inc` is the only place that touches `$2000`.
* **Lab code must not call anything in `$4000-$7FFF`.** While bank 2 is mapped
  that range is Lab code, not the original bank 1. Calls *into bank 0* are fine,
  but only if the target does not itself reach into bank 1 — the original's
  A-type *init* calls the sound engine, which does, so we chain to it rather
  than calling it. Its *main* handler calls only bank-0 routines, so we call
  that one directly (see ADR 3).
* Check the address before calling any original routine from Lab code. Under
  `$4000` is safe; at or above it is not.
* `hLabBank` (the bank to restore) must live in HRAM, and the original leaves
  exactly two free bytes there. It sits at `$FFFD`.
