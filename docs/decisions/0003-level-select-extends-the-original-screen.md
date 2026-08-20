# 3. Level select extends the original screen rather than adding a menu

**Status:** accepted, 2026-08-20 (Milestone 1)

## Context

Levels 0-22 must be selectable. The original A-type screen offers 0-9 as a
5×2 grid of custom digit tiles (`$90-$99`) with a sprite cursor positioned from
`ATypeLevelsCoords`. KLM extends the same screen, changing only nine tiles.

## Decision

Extend the existing screen with a **bank** concept — `0-9`, `A-J`, `K-M` — and
repaint the ten cells. No new screen. A separate Gym menu waits until there is
something to configure that does not belong on an existing screen (Milestone 2).

## The input choices, and why they are free

* **Down on the bottom row / Up on the top row** cycle the bank. The original
  *explicitly ignores* both (`cp $05 / jr nc, .sendSpritesToOam`), so normal
  cursor movement needed no changes.
* **Select** toggles hearts. The original never tests it on this screen.

Falling off the bottom of a bank lands on the **top row of the next**, so Down
keeps reading as "keep going down" instead of dumping you back on the row you
just left.

## Consequences and gotchas found the hard way

* **We run before *and* after the original handler.** The pre-pass consumes
  input and changes bank; the post-pass fixes up what the original did. A
  post-pass is unavoidable because the cursor *sprite* is positioned by the
  original on its own terms, and clamping `hATypeLevel` alone leaves the sprite
  stale — the cursor visibly sits on an empty cell.
* **Consume the inputs you act on.** The original runs after us and sees the
  same `hButtonsPressed`. Clamping the cursor to K left it on the top row, so
  the original then moved it *down* into an empty cell. Bits we act on are
  cleared with `res`.
* **The bank must be folded into `hATypeLevel` only when leaving the screen.**
  While the screen is up, `hATypeLevel` holds the cursor index 0-9 so the
  original's cursor and coordinate-table code works untouched. Doing the fold
  in the pre-pass instead meant the post-pass clamp saw a real level rather than
  an index and pulled level 21 back to 2.
* **Repaint one frame late.** The original's init copies the whole layout over
  the screen *after* our init runs, so anything we draw during init is erased.
  A pending flag defers the repaint to the next frame.
* **Letters blink; digits do not.** The cursor sprite draws the *character* for
  the level — spec index `$20 + level` selects a one-tile sprite — and the ROM
  contains those specs only for digits `0-9`. On a letter bank it therefore drew
  a digit on top of a letter. Adding letter sprites would mean extending
  `SpriteData`, which shifts bank 0 (ADR 2), so instead the sprite is hidden and
  the selected letter blinks in place, at the original's own 16-frame cadence
  (`hTimer1`). Digits keep their original grey/black flash.
* **Hearts are not offered on K-M.** Hard mode is `min(level + 10, 20)`, a
  ceiling written when 20 was the highest level; at L and M it clamps *downward*
  and makes the game slower. Raising the ceiling would change normal heart games,
  which players rely on, so the option is simply withheld where it cannot help.
  See `docs/existing-hacks.md` §3.2b.
