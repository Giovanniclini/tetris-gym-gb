; Gym core - everything this project adds lives in ROM banks 2 and up.
;
; Bank 0 and bank 1 remain the original game, byte for byte, except for the
; single declared hook in src/hooks/hooks.inc.

INCLUDE "include/hardware.inc"
INCLUDE "include/constants.s"   ; pure EQUs, safe in multiple translation units
INCLUDE "include/structs.s"     ; rb offsets, likewise

INCLUDE "gym/levels.inc"


; hram.s declares a real SECTION, so it cannot be included twice. Its labels
; are exported and resolve at link time; these are the ones we use.
; Keep in sync with src/original/include/hram.s.

; ---------------------------------------------------------------------------
; HRAM
;
; The original leaves exactly two bytes of HRAM free ($FFFD-$FFFE); everything
; below $FFFD is in use. hGymBank must be in HRAM because the trampoline uses
; `ldh`, and because it is touched on every bank switch.
; ---------------------------------------------------------------------------

SECTION "Gym HRAM", HRAM[$FFFD]
hGymBank:: db            ; ROM bank currently selected by FarCall

; Read once per piece draw, so it earns one of the two free HRAM bytes.
hGymSpsEnabled:: db

; ---------------------------------------------------------------------------
; WRAM
;
; Claimed from the one large gap the original leaves: $D762-$DF6F, 2062 bytes
; between the high score tables and the audio variables. Verified unused - no
; code in the disassembly references an address in that range.
;
; The first 351 bytes are not free after all: the original's own high score
; indexing runs into them for levels above the grid. They are claimed below as
; the continuation of that table, which is what they should always have been.
;
; NOTE: $C400 is NOT free in v1.1 (wDarkSolidBlocksUnderRandomBlocks lives
; there). An earlier draft of docs/architecture.md said otherwise, based on a
; less complete disassembly's memory map.
;
; Gym code must never write outside this range.
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; A-type high scores for levels A-M
;
; The original's table is ten slots - one per grid level - and its index
; arithmetic (wATypeHighScores + level * HISCORE_SIZEOF, at $179A) has no bound
; check. A game played at A-M therefore filed its score off the end of the
; table, into whatever happened to be there.
;
; So put the missing slots there. This section continues the original table
; exactly, which makes the original routine correct for levels 0-22 without
; changing a byte of it. tests/test_menu.py asserts the two are contiguous.
;
; $D762 = wATypeHighScores + HISCORE_SIZEOF * 10. Written as a literal because
; a SECTION address must be known at assembly time, not link time.
; ---------------------------------------------------------------------------

SECTION "Gym High Scores", WRAM0[$D762]
wGymATypeHighScoresExt::
	ds HISCORE_SIZEOF * (MAX_LEVEL + 1 - 10)


SECTION "Gym State", WRAM0[$D8C1]
wGymState::

; Level picker, shown in a single cell to the right of the original 0-9 grid.
wGymFocus::        db        ; 0 grid, 1 level, 2-5 the four seed digits
wGymPickerLevel::  db        ; 0-22, shown as 0-9 then A-M
wGymBlinkTimer::   db        ; frame counter for the focus blink
wGymBlinkPhase::   db        ; current blink phase

; The original's init copies the whole layout back over the screen after our
; init runs, so anything we draw during init is erased. Repaint a frame later.
wGymRedrawPending:: db

; Set while an instant restart is in flight, so MainLoop's reset check knows to
; leave it alone. Without it there is no way to tell our restart apart from the
; level select starting a game, which reaches the same state.
wGymRestarting:: db

; SPS state. Sixteen bits, low byte first, matching the community's seeded ROM.
; $0000 is degenerate - period 1, always returns zero - so seeds are forced
; non-zero when set. See docs/existing-hacks.md section 4.2.
wGymRngLo:: db
wGymRngHi:: db

; The seed as configured on the menu, copied into the LFSR at the start of every
; game. Kept separate because the LFSR state advances during play, and a restart
; must repeat the sequence rather than continue it.
wGymSeedLo:: db
wGymSeedHi:: db

	ds 1013
wGymStateEnd::

; ---------------------------------------------------------------------------
; Bank 2 - Gym core
; ---------------------------------------------------------------------------

SECTION "Gym Core", ROMX[$4000], BANK[2]

GymVersion::
	db "TETRISGYMGB 0.1", 0

; Entry point for the Gym, reached via FarCall with b = BANK(GymInit).
; Does nothing yet: Milestone 0.5 expands the cartridge, it does not add
; behaviour. The trampoline and this stub exist so that Milestone 1 has
; somewhere to land.
GymInit::
	ret

; ---------------------------------------------------------------------------
; State dispatch
;
; Reached from GymStateHook in bank 0, with bank 2 mapped. Does the Gym's own
; work, then returns in HL the address of the original handler for the caller
; to chain to.
;
; This code must not call anything in $4000-$7FFF: while bank 2 is mapped that
; range is Gym code, not the original bank 1. Calls into bank 0 are fine, but
; only if the target does not itself reach into bank 1 - the original A-type
; init calls the sound engine, which does. So we touch RAM only, and let the
; original handler run afterwards with bank 1 restored.
; ---------------------------------------------------------------------------

GymDispatch::
	ldh  a, [hGameState]
	cp   GS_LEVEL_ENDED_MAIN
	jr   z, .levelEnded
	cp   GS_ENTERING_HIGH_SCORE
	jr   z, .nameEntry
	cp   GS_IN_GAME_INIT
	jr   z, .gameInit
	cp   GS_A_TYPE_SELECTION_INIT
	jr   z, .init

; The original main handler only calls bank-0 routines, so we can run it
; ourselves and then correct what it did. Fixing up afterwards is the only way
; to move the cursor sprite, which the original repositions on its own terms.
	call GymLevelSelectMain
	call GameState11_ATypeSelectionMain
	call GymLevelSelectPost
	ld   hl, Stub_148c              ; the stub's `jp hl` must land somewhere
	ret

.init:
	call GymLevelSelectInit
	ld   hl, GameState10_ATypeSelectionInit
	ret

; The end-of-game screen. Its handler treats Start as "back to the level
; select", and Start is part of the reset combination - so by the time either
; soft-reset check runs, the state has already moved on and we would reboot.
; Catch the combination here instead, which is what makes "top out, go again"
; work.
.levelEnded:
	call GymResetComboHeld
	jr   nz, .runLevelEnded

	call GymInGameReset             ; state is GS_LEVEL_ENDED_MAIN: restarts
	ld   hl, Stub_148c
	ret

.runLevelEnded:
	ld   hl, GameState04_LevelEndedMain
	ret

; Typing a high score name. Restarting here abandons the score, which is the
; point: when you are drilling you want another go, not a leaderboard entry.
.nameEntry:
	call GymResetComboHeld
	jr   nz, .runNameEntry

	call GymInGameReset
	ld   hl, Stub_148c
	ret

.runNameEntry:
	ld   hl, GameState15_EnteringHighScore
	ret

; Every game begins here, whether from the menu or an instant restart, so this
; is the one place to load the configured seed into the LFSR. A restart must
; repeat the sequence, not continue it.
.gameInit:
	call GymArmSeed
	ld   hl, GameState0a_InGameInit
	ret




; ---------------------------------------------------------------------------
; Level picker and seed entry
;
; The original 0-9 grid is left completely alone - same tiles, same cursor, same
; movement. The Gym adds two fields in the blank strip to its right:
;
;        cols 15-18
;   row  6      .  L  .  .      level, 0-9 then A-M
;   row  9      S  E  E  D
;   row 10      A  C  E  1      seed, four hex digits
;
; Focus moves in a chain: grid -> level -> the four seed digits. Left and Right
; walk the chain, Up and Down change the value under the cursor. Right on grid
; cell 9 enters the level field - a press the original ignores, which is what
; makes the grid's own movement survive untouched. The focused field blinks.
;
; A seed of $0000 means "no seed", so SPS is off and pieces come from rDIV as
; they always did - which is genuinely random, so there is nothing to randomise.
; ---------------------------------------------------------------------------

DEF PICKER_CELL   EQU _SCRN0 + 6 * 32 + 16
DEF SEED_LABEL    EQU _SCRN0 + 9 * 32 + 15
DEF SEED_CELL     EQU _SCRN0 + 10 * 32 + 15
DEF HEART_CELL    EQU _SCRN0 + 4 * 32 + 14
DEF TILE_HEART    EQU $27
DEF TILE_FRAME    EQU $2c       ; what the original draws in the heart cell
DEF TILE_BLANK    EQU $2f
DEF GRID_LAST     EQU 9

DEF FOCUS_GRID    EQU 0
DEF FOCUS_LEVEL   EQU 1
DEF FOCUS_SEED    EQU 2         ; .. FOCUS_SEED+3, leftmost digit first

; Font tiles. The game's charmap puts A-Z at $0A-$23; it lives in includes.s,
; which this file does not include, so the letters we need are spelled out.
DEF TILE_D        EQU $0d
DEF TILE_E        EQU $0e
DEF TILE_S        EQU $1c


GymLevelSelectInit::
; hATypeLevel may hold a level above the grid, set last time a game started.
	ldh  a, [hATypeLevel]
	cp   GRID_LAST + 1
	jr   nc, .aboveGrid

	ld   a, FOCUS_GRID
	ld   [wGymFocus], a
	ld   a, GRID_LAST + 1           ; a sensible first value to offer
	ld   [wGymPickerLevel], a
	jr   .pending

.aboveGrid:
	ld   [wGymPickerLevel], a
	ld   a, FOCUS_LEVEL
	ld   [wGymFocus], a

; A game just ended above the grid, and the original's init - which runs next -
; files the score under whatever hATypeLevel says at that moment. It is about to
; say GRID_LAST, so file the score here instead, while it still says the level
; that was played. The routine clears wScoreBCD on its way out, so the
; original's own call finds a zero score and cannot file it a second time.
	call DisplayATypeHighScoresForLevel

	ld   a, GRID_LAST
	ldh  [hATypeLevel], a           ; keep the grid cursor somewhere valid

.pending:
	ld   a, 1
	ld   [wGymRedrawPending], a
	ret


GymLevelSelectMain::
; While the reset combination is held, do not let the menu act on Start. It is
; part of the combination, so the menu would start a game that is then rebooted
; a frame later - you see it flash up on screen before the logo returns.
	call GymResetComboHeld
	jr   nz, .notResetting

	ldh  a, [hButtonsPressed]
	res  PADB_START, a
	res  PADB_A, a
	ldh  [hButtonsPressed], a
	ret

.notResetting:
	ld   a, [wGymRedrawPending]
	and  a
	jr   z, .readInput
	xor  a
	ld   [wGymRedrawPending], a
	call GymDrawHearts
	call GymUpdateHighScores        ; the original's init painted the grid level
	call GymPaintFields

.readInput:
	ldh  a, [hButtonsPressed]
	ld   c, a

; Select toggles hard mode ("hearts"). The original arms it with an
; undocumented Down+Start on the title screen, two screens earlier, with no
; feedback until a heart appears here; it never tests Select on this screen.
	bit  PADB_SELECT, c
	jr   z, .afterSelect

	ldh  a, [hIsHardMode]
	and  a
	ld   a, 0
	jr   nz, .storeHearts
	ld   a, 1

.storeHearts:
	ldh  [hIsHardMode], a
	call GymDrawHearts

.afterSelect:
	ld   a, [wGymFocus]
	and  a
	jr   z, .gridFocus
	cp   FOCUS_LEVEL
	jr   z, .levelFocus
	jr   .seedFocus

; --- the grid has focus: the only thing we add is Right on the last cell ---
.gridFocus:
	bit  PADB_RIGHT, c
	ret  z
	ldh  a, [hATypeLevel]
	cp   GRID_LAST
	ret  nz
	ld   a, FOCUS_LEVEL
	ld   [wGymFocus], a
	jr   .consume

; --- the level field has focus ---
; Every direction that lands here is swallowed, whether or not it changed
; anything: the original would otherwise move the grid cursor underneath us.
.levelFocus:
	bit  PADB_LEFT, c
	jr   z, .levelNotLeft
	xor  a                          ; FOCUS_GRID
	ld   [wGymFocus], a
	call GymShowGridCursor
	jr   .consume

.levelNotLeft:
	bit  PADB_RIGHT, c
	jr   z, .levelNotRight
	ld   a, FOCUS_SEED              ; on into the seed, leftmost digit
	ld   [wGymFocus], a
	jr   .consume

.levelNotRight:
	bit  PADB_UP, c
	jr   z, .levelNotUp
	ld   a, [wGymPickerLevel]
	cp   MAX_LEVEL
	jr   nc, .consume               ; already at M
	inc  a
	ld   [wGymPickerLevel], a
	jr   .consume

.levelNotUp:
	bit  PADB_DOWN, c
	ret  z
	ld   a, [wGymPickerLevel]
	and  a
	jr   z, .consume                ; already at 0
	dec  a
	ld   [wGymPickerLevel], a
	jr   .consume

; --- a seed digit has focus ---
.seedFocus:
	bit  PADB_UP, c
	jr   z, .seedNotUp
	ld   b, 1
	call GymAdjustSeedNibble
	jr   .consume

.seedNotUp:
	bit  PADB_DOWN, c
	jr   z, .seedNotDown
	ld   b, -1
	call GymAdjustSeedNibble
	jr   .consume

.seedNotDown:
	bit  PADB_RIGHT, c
	jr   z, .seedNotRight
	ld   a, [wGymFocus]
	cp   FOCUS_SEED + 3
	jr   nc, .consume               ; already on the last digit
	inc  a
	ld   [wGymFocus], a
	jr   .consume

.seedNotRight:
	bit  PADB_LEFT, c
	ret  z
	ld   a, [wGymFocus]
	cp   FOCUS_SEED + 1
	jr   nc, .seedLeftWithin

	ld   a, FOCUS_LEVEL             ; back up to the level field
	ld   [wGymFocus], a
	jr   .consume

.seedLeftWithin:
	dec  a
	ld   [wGymFocus], a

.consume:
	ldh  a, [hButtonsPressed]
	res  PADB_LEFT, a
	res  PADB_RIGHT, a
	res  PADB_UP, a
	res  PADB_DOWN, a
	ldh  [hButtonsPressed], a
	ld   a, SND_MOVING_SELECTION
	ld   [wSquareSoundToPlay], a
	call GymUpdateHighScores
	jp   GymPaintFields


; Runs after the original handler.
GymLevelSelectPost::
	ldh  a, [hGameState]
	cp   GS_A_TYPE_SELECTION_MAIN
	jr   nz, .leavingScreen

	ld   a, [wGymFocus]
	and  a
	ret  z                          ; grid has focus: nothing to correct

; Hide the grid cursor - it draws the character for hATypeLevel, which is not
; what these fields show - and push that through to OAM, because the original
; has already copied the specs by the time we run.
	ld   a, SPRITE_SPEC_HIDDEN
	ld   [wSpriteSpecs + SPR_SPEC_Hidden], a
	call Copy2SpriteSpecsToShadowOam

; Hearts are min(level + 10, 20). Above level 20 that ceiling clamps downward
; and makes the game slower, so hearts are turned off up there rather than
; changing the original formula. See docs/existing-hacks.md 3.2b.
	ld   a, [wGymPickerLevel]
	cp   21
	jr   c, .blink
	ldh  a, [hIsHardMode]
	and  a
	jr   z, .blink
	xor  a
	ldh  [hIsHardMode], a
	call GymDrawHearts

.blink:
	ld   hl, wGymBlinkTimer
	inc  [hl]
	ld   a, [hl]
	and  $10
	ld   b, a
	ld   a, [wGymBlinkPhase]
	cp   b
	ret  z
	ld   a, b
	ld   [wGymBlinkPhase], a
	jp   GymPaintFields

; The original has handed over - to the game, or back a screen. hATypeLevel has
; been holding a grid index so the original cursor code kept working; now that
; nothing else reads it as an index, fold in the level field.
.leavingScreen:
	ld   a, [wGymFocus]
	and  a
	ret  z                          ; grid has focus: the cursor is the level
	ld   a, [wGymPickerLevel]
	ldh  [hATypeLevel], a
	ret


GymShowGridCursor::
	xor  a
	ld   [wSpriteSpecs + SPR_SPEC_Hidden], a
	ld   de, wSpriteSpecs + SPR_SPEC_BaseYOffset
	ld   hl, ATypeLevelsCoords
	ldh  a, [hATypeLevel]
	call SetNumberSpecStructsCoordsAndSpecIdxFromHLtable
	jp   Copy2SpriteSpecsToShadowOam


; Add B (1 or -1) to the nibble the focus is on, wrapping 0-F.
GymAdjustSeedNibble::
	ld   a, [wGymFocus]
	sub  FOCUS_SEED
	ld   c, a                       ; c = digit index 0-3

	call GymReadSeedNibble
	add  b
	and  $0f
	ld   d, a                       ; d = new nibble

; rebuild the byte the digit lives in
	ld   a, c
	cp   2
	jr   c, .highByte

	ld   hl, wGymSeedLo
	jr   .haveByte

.highByte:
	ld   hl, wGymSeedHi

.haveByte:
	ld   a, c
	and  1                          ; 0 = upper nibble, 1 = lower
	jr   nz, .lowerNibble

	ld   a, [hl]
	and  $0f
	swap d
	or   d
	ld   [hl], a
	ret

.lowerNibble:
	ld   a, [hl]
	and  $f0
	or   d
	ld   [hl], a
	ret


; Nibble C (0-3, leftmost first) of the seed, returned in A.
GymReadSeedNibble::
	ld   a, c
	cp   2
	jr   c, .fromHigh
	ld   a, [wGymSeedLo]
	jr   .haveByte

.fromHigh:
	ld   a, [wGymSeedHi]

.haveByte:
	bit  0, c
	jr   nz, .lower
	swap a

.lower:
	and  $0f
	ret


; Paint the level field, the SEED label and the four seed digits, blanking
; whichever field has focus while the blink phase is off. Ten tilemap writes at
; most, so it simply waits for VBlank - the original does the same in
; HandleLockdownTransferToTilemap.
GymPaintFields::
.waitVBlank:
	ldh  a, [rLY]
	cp   SCRN_Y
	jr   c, .waitVBlank

; level field
	ld   a, [wGymPickerLevel]
	ld   b, FOCUS_LEVEL
	call GymBlankIfFocused
	ld   [PICKER_CELL], a

; label - explicit tile indices, because no charmap is active in this file and
; a string literal would assemble as ASCII
	ld   hl, SEED_LABEL
	ld   a, TILE_S
	ld   [hl+], a
	ld   a, TILE_E
	ld   [hl+], a
	ld   [hl+], a
	ld   a, TILE_D
	ld   [hl], a

; four digits - the font puts 0-9 at $00-$09 and A-F at $0A-$0F, so the tile is
; the nibble
	ld   hl, SEED_CELL
	ld   c, 0

.digitLoop:
	push hl
	call GymReadSeedNibble
	ld   b, a
	ld   a, c
	add  FOCUS_SEED
	ld   d, a                       ; d = the focus value for this digit
	ld   a, b
	ld   b, d
	call GymBlankIfFocused
	pop  hl
	ld   [hl+], a
	inc  c
	ld   a, c
	cp   4
	jr   c, .digitLoop
	ret


; A = TILE_BLANK when field B has focus and the blink is off, else A unchanged.
GymBlankIfFocused::
	push af
	ld   a, [wGymBlinkPhase]
	and  a
	jr   nz, .keep                  ; blink on: draw normally
	ld   a, [wGymFocus]
	cp   b
	jr   nz, .keep
	pop  af
	ld   a, TILE_BLANK
	ret

.keep:
	pop  af
	ret


; Keep the TOP SCORE panel showing the level you are actually about to play.
;
; The original drives it from hATypeLevel, which the Gym keeps as the grid index
; while the level field or the seed has focus - so it kept showing the grid
; cursor's scores while you had M selected. A-M have their own slots (see "Gym
; High Scores" above), so every level shows real scores.
;
; This is DisplayATypeHighScoresForLevel ($1795) with one substitution: the
; level comes from the picker instead of hATypeLevel. Borrowing hATypeLevel
; instead would be shorter, but the routine below busy-waits on the LCD and so
; can outlast a frame - leaving the borrowed value visible to everything else
; that runs in between.
GymUpdateHighScores::
	call DisplayDottedLinesForHighScore

	ld   a, [wGymFocus]
	and  a
	jr   nz, .fromPicker
	ldh  a, [hATypeLevel]           ; grid focus: the cursor is the level
	jr   .haveLevel

.fromPicker:
	ld   a, [wGymPickerLevel]

.haveLevel:
	ld   hl, wATypeHighScores
	ld   de, HISCORE_SIZEOF

.nextSlot:
	and  a
	jr   z, .foundSlot
	dec  a
	add  hl, de
	jr   .nextSlot

.foundSlot:
	inc  hl                         ; highest byte of score 1
	inc  hl
	ld   d, h
	ld   e, l
	jp   SetNewHighScoreIfAchieved_SendNameAndScoreToRamBuffer


; Show whether hearts are armed, in the blank strip beside "LEVEL".
GymDrawHearts::
	ldh  a, [hIsHardMode]
	and  a
	ld   a, TILE_HEART
	jr   nz, .paint
	ld   a, TILE_FRAME

.paint:
	ld   b, a

.waitVBlank:
	ldh  a, [rLY]
	cp   SCRN_Y
	jr   c, .waitVBlank

	ld   a, b
	ld   [HEART_CELL], a
	ret


; Z is set when the soft-reset combination is held.
GymResetComboHeld::
	ldh  a, [hButtonsHeld]
	and  PADF_START|PADF_SELECT|PADF_B|PADF_A
	cp   PADF_START|PADF_SELECT|PADF_B|PADF_A
	ret


GymInGameReset::
; Link play still reboots: restarting one side of a two-player game would
; desync the cable, and the original behaviour is the safe one there.
	ldh  a, [hIs2Player]
	and  a
	jp   nz, Reset

; A restart we started is still initialising: decline, and let it finish.
	ld   a, [wGymRestarting]
	and  a
	jr   z, .notRestarting

	ldh  a, [hGameState]
	cp   GS_IN_GAME_INIT
	jr   z, .consume

	xor  a                          ; init finished
	ld   [wGymRestarting], a

.notRestarting:
; Restart from anywhere inside a game or its aftermath. Topping out and going
; straight again is the case a trainer needs most, and the game-over sequence
; runs $00 -> $01 -> $0D -> $04 before it settles.
	ldh  a, [hGameState]
	and  a
	jr   z, .restart                ; GS_IN_GAME_MAIN
	cp   GS_GAME_OVER_INIT
	jr   z, .restart
	cp   GS_LEVEL_ENDED_MAIN
	jr   z, .restart
	cp   GS_GAME_OVER_SCREEN_CLEARING
	jr   z, .restart
	cp   GS_ENTERING_HIGH_SCORE
	jr   z, .restart

; Anywhere else, reboot exactly as the original does. Note this includes
; GS_IN_GAME_INIT reached from the level select, which is what happens when the
; combination is pressed on a menu - Start is part of it, so the menu starts a
; game on the way past. Only a restart we began is exempt, hence the flag.
	jp   Reset

.restart:
	ld   a, GS_IN_GAME_INIT
	ldh  [hGameState], a
	ld   a, 1
	ld   [wGymRestarting], a

; Consume the combination. MainLoop's check runs later in this same frame, and
; during the restart's init frames it is the only one that runs at all.
; PollInput refills hButtonsHeld next frame.
.consume:
	xor  a
	ldh  [hButtonsHeld], a
	ret


; ---------------------------------------------------------------------------
; SPS seed
; ---------------------------------------------------------------------------

; Copy the configured seed into the LFSR and arm SPS, or disarm it.
;
; A seed of $0000 means "off": pieces come from rDIV, exactly as the original
; does, which is genuinely random. That also means the degenerate all-zero LFSR
; state can never be reached - it is spent as the "no seed" value instead of
; being a trap the way it is in the community's ROM (docs/existing-hacks.md 4.2).
GymArmSeed::
	ld   a, [wGymSeedLo]
	ld   [wGymRngLo], a
	ld   b, a
	ld   a, [wGymSeedHi]
	ld   [wGymRngHi], a
	or   b                          ; seed zero?
	ldh  [hGymSpsEnabled], a        ; non-zero arms it, zero disarms it
	ret
