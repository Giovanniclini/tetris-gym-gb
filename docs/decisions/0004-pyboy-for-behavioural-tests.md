# 4. PyBoy drives behavioural tests; the build stays dependency-free

**Status:** accepted, 2026-08-20 (Milestone 1)

## Context

Byte-level tests prove the ROM *contains* a value. They cannot prove the game
*uses* it — a broken hook leaves every byte correct. They are also brittle: an
early DAS test asserted on the instruction address rather than the operand and
passed for the wrong reason.

## Decision

`tools/emu.py` drives the ROM in **PyBoy**, installed into a local `.venv` as a
**test-only** dependency. `build.py` keeps no dependencies at all.

## Why PyBoy

SameBoy is the accuracy reference but ships no Linux binary. This machine has
neither `pip` nor a compiler, so anything needing a build was out; PyBoy ships
wheels, and `pip` bootstraps into a venv from `get-pip.py` without touching the
system. Our tests need CPU, timers, memory and input — not PPU accuracy.

## Consequences

* `python3 build.py` still works on a bare machine with only Python 3.
* Tests can drive the real menus, so they exercise the same path a player does.
  Several bugs in this milestone were only findable this way.
* PyBoy is not cycle-exact. It is adequate for frame-level assertions
  (gravity, DAS, ARE) but **not** authority for sub-frame timing. If we ever
  need that, revisit with SameBoy or Emulicious.
* Emulator-driven tests are slow — a fresh boot costs ~500 frames of copyright
  screens. Reuse an instance where the state machine allows, and start a new
  one where it does not.
