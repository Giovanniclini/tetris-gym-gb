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

; ---------------------------------------------------------------------------
; WRAM
;
; Claimed from the one large gap the original leaves: $D762-$DF6F, 2062 bytes
; between the high score tables and the audio variables. Verified unused - no
; code in the disassembly references an address in that range.
;
; NOTE: $C400 is NOT free in v1.1 (wDarkSolidBlocksUnderRandomBlocks lives
; there). An earlier draft of docs/architecture.md said otherwise, based on a
; less complete disassembly's memory map.
;
; Gym code must never write outside this range.
; ---------------------------------------------------------------------------

SECTION "Gym State", WRAM0[$D800]
wGymState::

; Level picker, shown in a single cell to the right of the original 0-9 grid.
wGymPickerActive:: db        ; non-zero while the picker has focus
wGymPickerLevel::  db        ; 0-22, shown as 0-9 then A-M
wGymPickerBlink::  db        ; frame counter for the focus blink
wGymPickerDrawn::  db        ; what we last wrote, to avoid needless VRAM writes

; The original's init copies the whole layout back over the screen after our
; init runs, so anything we draw during init is erased. Repaint a frame later.
wGymRedrawPending:: db

	ds 1019
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




; ---------------------------------------------------------------------------
; Level picker
;
; The original 0-9 grid is left completely alone - same tiles, same cursor,
; same movement. All the Gym adds is one cell to the right of it showing a
; level, changed with Left and Right.
;
; Pressing Right on cell 9 gives the picker focus; the original ignores that
; press (`cp $09 / jr z`), so nothing needs suppressing to reach it. Pressing
; Left at level 0 hands focus back to cell 9.
;
; The picker cell's tile is simply the level number: the font puts 0-9 at
; $00-$09 and A-M at $0A-$16, so tile == level for every level we support.
; ---------------------------------------------------------------------------

DEF PICKER_CELL   EQU _SCRN0 + 6 * 32 + 16
DEF HEART_CELL    EQU _SCRN0 + 4 * 32 + 14
DEF TILE_HEART    EQU $27
DEF TILE_FRAME    EQU $2c       ; what the original draws in the heart cell
DEF GRID_LAST     EQU 9       ; bottom-right cell of the original grid
DEF PICKER_BLANK  EQU $2f


GymLevelSelectInit::
; hATypeLevel may hold a level above the grid, set last time a game started.
; Give the picker focus in that case, otherwise leave the grid in charge.
	ldh  a, [hATypeLevel]
	cp   GRID_LAST + 1
	jr   nc, .abovegrid

	xor  a
	ld   [wGymPickerActive], a
	ld   a, GRID_LAST + 1           ; a sensible first value to offer
	jr   .storePicker

.abovegrid:
	ld   b, a
	ld   a, 1
	ld   [wGymPickerActive], a
	ld   a, GRID_LAST
	ldh  [hATypeLevel], a           ; keep the grid cursor somewhere valid
	ld   a, b

.storePicker:
	ld   [wGymPickerLevel], a

	ld   a, $ff
	ld   [wGymPickerDrawn], a       ; force the first paint
	ld   a, 1
	ld   [wGymRedrawPending], a
	ret


GymLevelSelectMain::
	ld   a, [wGymRedrawPending]
	and  a
	jr   z, .readInput
	xor  a
	ld   [wGymRedrawPending], a
	call GymDrawHearts
	call GymDrawPicker

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
	ld   a, [wGymPickerActive]
	and  a
	jr   nz, .picker

; --- grid has focus: the only thing we add is Right on the last cell ---
	bit  PADB_RIGHT, c
	ret  z
	ldh  a, [hATypeLevel]
	cp   GRID_LAST
	ret  nz

	ld   a, 1
	ld   [wGymPickerActive], a
	jr   .consume

; --- picker has focus ---
.picker:
	bit  PADB_RIGHT, c
	jr   z, .checkLeft

	ld   a, [wGymPickerLevel]
	cp   MAX_LEVEL
	jr   nc, .consume               ; already at M
	inc  a
	ld   [wGymPickerLevel], a
	jr   .consume

.checkLeft:
	bit  PADB_LEFT, c
	jr   z, .swallowVertical

	ld   a, [wGymPickerLevel]
	and  a
	jr   nz, .decLevel

; at level 0: hand focus back to the grid
	ld   [wGymPickerActive], a      ; a is already 0
	call GymShowGridCursor
	jr   .consume

.decLevel:
	dec  a
	ld   [wGymPickerLevel], a
	jr   .consume

; Up and Down would move the grid cursor underneath the picker, so ignore them
; while the picker has focus.
.swallowVertical:
	bit  PADB_UP, c
	jr   nz, .consumeQuietly
	bit  PADB_DOWN, c
	ret  z

.consumeQuietly:
	ldh  a, [hButtonsPressed]
	res  PADB_UP, a
	res  PADB_DOWN, a
	ldh  [hButtonsPressed], a
	ret

.consume:
	ldh  a, [hButtonsPressed]
	res  PADB_LEFT, a
	res  PADB_RIGHT, a
	ldh  [hButtonsPressed], a
	ld   a, SND_MOVING_SELECTION
	ld   [wSquareSoundToPlay], a
	jp   GymDrawPicker


; Runs after the original handler.
GymLevelSelectPost::
	ldh  a, [hGameState]
	cp   GS_A_TYPE_SELECTION_MAIN
	jr   nz, .leavingScreen

	ld   a, [wGymPickerActive]
	and  a
	ret  z                          ; grid has focus: nothing to correct

; Hide the grid cursor - it draws the character for hATypeLevel, which is not
; what the picker is showing - and blink the picker cell instead, at the
; original's own 16-frame cadence.
; The original flashes this sprite by XOR-ing its hidden bit and then copying
; the specs into OAM. Setting the bit here is not enough on its own - the copy
; has already happened - so push the hidden state through as well, or the grid
; cursor blinks on screen next to the picker.
	ld   a, SPRITE_SPEC_HIDDEN
	ld   [wSpriteSpecs + SPR_SPEC_Hidden], a
	call Copy2SpriteSpecsToShadowOam

; Hearts are min(level + 10, 20). Above level 20 that ceiling clamps *downward*
; and makes the game slower, so hearts are simply turned off up there rather
; than changing the original formula, which normal heart games rely on.
; See docs/existing-hacks.md 3.2b.
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
	ld   hl, wGymPickerBlink
	inc  [hl]
	ld   a, [hl]
	and  $10
	jr   z, GymDrawPickerBlank
	jr   GymDrawPicker

; The original has handed over, so hATypeLevel stops being a grid index and
; becomes the level the game will start on.
.leavingScreen:
	ld   a, [wGymPickerActive]
	and  a
	ret  z
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


GymDrawPickerBlank::
	ld   a, PICKER_BLANK
	jr   GymDrawPickerTile

GymDrawPicker::
	ld   a, [wGymPickerLevel]

; Paint one tile into the picker cell, skipping the write when it is already
; there. Waits for VBlank rather than queueing - it is a single byte.
GymDrawPickerTile::
	ld   b, a
	ld   a, [wGymPickerDrawn]
	cp   b
	ret  z
	ld   a, b
	ld   [wGymPickerDrawn], a

.waitVBlank:
	ldh  a, [rLY]
	cp   SCRN_Y
	jr   c, .waitVBlank

	ld   a, [wGymPickerDrawn]
	ld   [PICKER_CELL], a
	ret


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
