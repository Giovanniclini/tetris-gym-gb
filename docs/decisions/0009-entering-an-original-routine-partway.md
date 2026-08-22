# 9. Entering an original routine partway

**Status:** accepted, 2026-08-22 (score uncap)

## Context

High score entries are three BCD bytes. An uncapped score cannot be ranked
against them: `1 000 050` stored as its low six digits loses to `999 999`, and
`999 999` wrongly beats a stored million. Only the *comparison* is wrong — the
shift, the dotted name, the song and the display buffer are all fine.

Bank 0 has no free bytes left, so there was no room for a hook that replaces the
comparison in place.

## Decision

Do the comparison in bank 2 and jump into the original's insert path at
`SetNewHighScoreIfAchieved_SendNameAndScoreToRamBuffer.currScoreHigherThanAHighScore`
(`$1822`) with `c` holding the rank.

This is legitimate here because of a specific property: that entry point's first
instruction is `pop de`, and its *next* two instructions overwrite `de` from
`h1stHighScoreHighestByteForLevel`. The popped value is discarded. So the
routine can be entered from outside with any word on the stack — it needs the
stack balanced, not a particular value on it.

**This is allowed only when the entry point's preconditions are provably a
register contract, not an accident of the caller.** Read the target and the
instructions after it before doing this. If the entry point consumes anything
the compare loop left behind, do not enter it; write the code out instead.

## Consequences

* **It costs nothing in bank 0.** No hook, no declared byte, nothing shifted.
  Compare with reimplementing the insert: roughly 150 bytes duplicating the
  name initialisation, `hTypedTextCharLoc`, the flash counters and the song —
  all of which would then have to be kept correct by hand.
* **The address is pinned by byte-exactness.** `$1822` cannot move while
  `build.py --original` passes, which is the project's ground truth. This
  technique is safe *because* of that test, and would be reckless without it.
* **The symbol resolves because `build.py` assembles with `-E`**, which exports
  local labels. `Parent.localLabel` is a real link-time symbol.
* **One instance so far.** Grep for it before adding another:
  `grep -nE "(call|jp)\s+[A-Za-z0-9_]+\.[a-z]" src/lab/*.asm`.

## What this cost to find

Nothing, in the end — but only because the alternative was costed first. The
reimplementation was drafted far enough to count what it would duplicate, which
is what made the mid-routine entry obviously the smaller risk rather than the
clever one.
