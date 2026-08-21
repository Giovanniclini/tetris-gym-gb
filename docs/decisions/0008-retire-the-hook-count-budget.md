# 8. The hook count is not the budget; the diff test is

**Status:** accepted, 2026-08-21 (Milestone 2). Supersedes the hook-count
criteria in Milestone 1 and Milestone 2.

## Context

Milestone 1's acceptance criteria included *"Hook count ≤ 4, all declared and
justified"* and Milestone 2's *"hook count ≤ 8"*. Both were written before we
knew what a hook costs. Instant restart needed four on its own, for reasons ADR
0005 records and that still look right.

Today, banks 0–1 differ from the original in **20 regions, 150 bytes**. That
number is alarming until it is broken down:

| | Regions | Bytes | |
| --- | --- | --- | --- |
| Cartridge header | 2 | 6 | Written by `rgbfix`, not by us |
| Code placed in reclaimed padding and linker gaps | 5 | 110 | Gravity table, reset stub, trampoline, LFSR, bank-1 thunk — **new sections in holes, nothing displaced** |
| Redirects into original instructions | **13** | **34** | Jump-table entries and operands |

**Thirteen redirects, thirty-four bytes** is the figure that describes the risk.
The other 116 bytes are code we added where nothing was.

## Decision

**Retire the count cap.** Judge a hook on three things instead:

1. **It is declared** in `src/hooks/hooks.inc`, and `tests/test_expansion.py`
   fails naming the address if any other byte in banks 0–1 moves.
2. **It redirects, never inserts** (ADR 0002), so nothing after it shifts.
3. **It is justified** — a reason recorded, not just a range.

The diff test is the real control, and it has earned that: it caught every
undeclared hook added in this milestone, before anyone noticed by playing.

## Why a cap is worse than no cap

A count cap prices hooks equally when they are not. A two-byte jump-table entry
that chains to an untouched handler is not the same risk as rewriting an
instruction mid-routine, and a cap says nothing about which you added.

Worse, it creates an incentive to stay under the number by **bundling unrelated
behaviour behind one hook** — which is harder to reason about, harder to remove,
and exactly the sort of thing this project exists to avoid.

## What actually keeps the number down

**Shared landing points.** The per-frame gameplay hook (`$00`,
`HOOK_STATE_TABLE00`) exists so that trainers which must act while a game is
running have somewhere to land *without adding a hook each*. The transition
trainer needed it; the ones after it will not need another. Designing for that
is the mechanism. A budget is only a number.

## Consequences

* The roadmap's hook-count criteria are struck. `--original` remaining
  byte-exact, and the declared-hook diff, stay exactly as they are.
* **Bank 0 is full** — its remaining 51 "free" bytes are the Nintendo logo and
  header checksums, which cannot be written. Any future hook needing code, not
  just a redirect, must go in a bank-1 gap or bank 2+. That is a real budget,
  and it is enforced by the linker rather than by a rule.
