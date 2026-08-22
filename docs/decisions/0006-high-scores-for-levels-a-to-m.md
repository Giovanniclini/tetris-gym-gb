# 6. High scores for A–M continue the original's table

**Status:** accepted, 2026-08-21 (Milestone 2)

## Context

`DisplayATypeHighScoresForLevel` (`$1795`) finds a level's slot with
`wATypeHighScores + level * HISCORE_SIZEOF` and no bound check. The table has
ten slots — one per grid level. A game played at A–M therefore indexed past its
end, into the free region at `$D762`, and both read and wrote there.

The Lab had been hiding half of this. It clamps `hATypeLevel` back into the grid
on arrival at the level select, because the cursor sprite draws the character
for that value and `ATypeLevelsCoords` has ten entries. The clamp ran *before*
the original's init, so the score of a game played at M was filed under 9 — and
showed up there.

## Decision

Put the missing slots exactly where that arithmetic already points:
`$D762–$D8C0`, thirteen slots continuing `wATypeHighScores`. The original
routine is then correct for levels 0–22 with no change to it at all. Lab state
moves up to `$D8C1`.

The clamp stays, but the score is filed before it: `LabLevelSelectInit` calls
`DisplayATypeHighScoresForLevel` while `hATypeLevel` still holds the level that
was played. That routine clears `wScoreBCD` on its way out, so the original's
own call a moment later finds a zero score and cannot file it twice.

## Consequences

* **A–M keep their own scores and names**, and an unplayed level shows the
  original's dotted placeholder because a zeroed slot already renders that way.
* **`$D762–$D8C0` was never really free.** It was reachable from unmodified
  original code the moment a level above the grid existed. Levels 15 and 16
  landed on `$D800`, which is where Lab state used to start.
* **The panel routine no longer borrows `hATypeLevel`.** `LabUpdateHighScores`
  now computes the slot itself — twenty bytes of bank 2 to avoid a trap: the
  original's display path busy-waits on the LCD and can outlast a frame, so a
  borrowed value was visible to everything that ran in between. That is what
  broke heart speeds twice; both times it looked like a gravity bug.
* **Tests read Lab addresses from the `.sym` file** (`tools.emu.sym`) rather
  than hardcoding them, so moving a section cannot silently point a test at the
  wrong byte.
* **Scores filed under the wrong level before this change stay there** until the
  next cold boot. `Begin2` clears `$D000–$DFFF`; the soft reset does not.
