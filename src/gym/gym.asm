; Gym core - everything this project adds lives in ROM banks 2 and up.
;
; Bank 0 and bank 1 remain the original game, byte for byte, except for the
; single declared hook in src/hooks/hooks.inc.

INCLUDE "include/hardware.inc"
INCLUDE "include/constants.s"   ; pure EQUs, safe in multiple translation units
INCLUDE "include/structs.s"     ; rb offsets, likewise

INCLUDE "gym/levels.inc"

DEF TILE_HEART          EQU $27
DEF TILE_BLANK_CELL     EQU $2f
DEF TILE_LEVEL_ROW_BLANK EQU $2c ; what the original draws there

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

; Which block of ten levels the cursor is showing: 0 = 0-9, 1 = A-J, 2 = K-M.
wGymLevelBank:: db

; Set on entering the level select screen. The original's init copies the whole
; layout back over the screen after we run, so the Gym's cells and hearts
; indicator have to be painted on the frame after, not during init.
wGymRedrawPending:: db

; Blink state for the selected cell on letter banks.
wGymBlinkTimer:: db
wGymBlinkPhase:: db
wGymBlinkCell::  db          ; $ff = no cell currently blanked

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


; Entering the level select screen.
;
; hATypeLevel may hold a real level 0-22 (set when a game was last started).
; The original cursor code only understands 0-9, so split it into a bank and a
; cursor index, and hand the original the index it expects.
GymLevelSelectInit::
	ldh  a, [hATypeLevel]
	ld   b, 0

.splitLoop:
	cp   10
	jr   c, .splitDone
	sub  10
	inc  b
	jr   .splitLoop

.splitDone:
	ldh  [hATypeLevel], a
	ld   a, b
	ld   [wGymLevelBank], a

	ld   a, 1
	ld   [wGymRedrawPending], a
	; fall through

; Clear the blink so a stale blanked cell cannot survive into a repaint.
GymResetBlink::
	ld   a, $10                     ; phase on
	ld   [wGymBlinkPhase], a
	ld   a, $ff                     ; no cell blanked
	ld   [wGymBlinkCell], a
	ret


; One frame of the level select screen. Runs before the original handler.
;
; Acts only on inputs the original ignores here, so nothing needs suppressing:
;   - Down on the bottom row / Up on the top row: the original explicitly
;     ignores these (`cp $05 / jr nc`), we use them to cycle the level bank
;   - Select: the original never tests it on this screen
GymLevelSelectMain::
; Repaint once, on the frame after the original init has drawn the layout.
	ld   a, [wGymRedrawPending]
	and  a
	jr   z, .readInput
	xor  a
	ld   [wGymRedrawPending], a
	call GymRedrawLevelScreen

.readInput:
	ldh  a, [hButtonsPressed]
	ld   c, a

; Select toggles hard mode ("hearts"). The original arms it with an
; undocumented Down+Start on the title screen, two screens earlier, with no
; feedback until a heart appears here. It never tests Select on this screen.
; Hearts are min(level + 10, 20). That ceiling was written when 20 was the
; highest level, so at K, L or M it clamps *downward* - M with hearts drops
; from 1 frame per row to 3, making hearts three times slower. Rather than
; touch the original formula, which normal heart games rely on, we simply do
; not offer hearts where they cannot help: at K, L and M the speed already
; meets or exceeds anything hearts could add.
	ld   a, [wGymLevelBank]
	cp   GYM_LEVEL_BANKS - 1
	jr   z, .skipHearts

	bit  PADB_SELECT, c
	jr   nz, .toggleHearts

.skipHearts:

	ld   a, [wGymLevelBank]
	cp   GYM_LEVEL_BANKS - 1
	jr   z, .topBankKeys

; Banks 0 and 1 fill all ten cells. Down on the bottom row and Up on the top
; row are both explicitly ignored by the original (`cp $05 / jr nc`), so we can
; use them to cycle banks. Every other movement is left to the original.
	ldh  a, [hATypeLevel]
	ld   e, a

	bit  PADB_DOWN, c
	jr   z, .checkUp
	ld   a, e
	cp   5
	ret  c                          ; not on the bottom row

; Falling off the bottom of one bank lands on the *top* row of the next, so
; Down keeps reading as "keep going down" rather than dumping you back on the
; bottom row you just left.
	sub  5
	ldh  [hATypeLevel], a
	jr   .bankNext

.checkUp:
	bit  PADB_UP, c
	ret  z
	ld   a, e
	cp   5
	ret  nc                         ; not on the top row

	add  5                          ; and Up lands on the bottom row above
	ldh  [hATypeLevel], a
	jr   .bankPrev

; The K-M bank has only three cells, all on the top row, so vertical movement
; has nothing to move to and always cycles. Right must stop at M, which the
; original would otherwise walk past into empty cells.
.topBankKeys:
	bit  PADB_DOWN, c
	jr   nz, .bankNext
	bit  PADB_UP, c
	jr   nz, .bankPrev

	ret                             ; Left/Right are clamped by the post-pass

.toggleHearts:
	ldh  a, [hIsHardMode]
	and  a
	ld   a, 0
	jr   nz, .storeHardMode
	ld   a, 1

.storeHardMode:
	ldh  [hIsHardMode], a
	jp   GymRedrawLevelScreen

.bankNext:
	ld   a, [wGymLevelBank]
	inc  a
	cp   GYM_LEVEL_BANKS
	jr   c, .setBank
	xor  a
	jr   .setBank

.bankPrev:
	ld   a, [wGymLevelBank]
	and  a
	jr   nz, .decBank
	ld   a, GYM_LEVEL_BANKS

.decBank:
	dec  a

.setBank:
	ld   [wGymLevelBank], a

	cp   GYM_LEVEL_BANKS - 1
	jr   nz, .afterClamp

; Hearts cannot help at K-M, so clear them on arrival - unconditionally, not
; only when the cursor also needs clamping. Landing on cell 0 needs no clamp,
; which is how hearts survived into K-M before.
	xor  a
	ldh  [hIsHardMode], a

; Pull the cursor back if it is parked beyond M.
	ldh  a, [hATypeLevel]
	cp   GYM_TOP_BANK_COUNT
	jr   c, .afterClamp
	ld   a, GYM_TOP_BANK_COUNT - 1
	ldh  [hATypeLevel], a

.afterClamp:
	call GymResetBlink
	call .consumeMovement
	ld   a, SND_MOVING_SELECTION
	ld   [wSquareSoundToPlay], a
	jp   GymRedrawLevelScreen

; We have consumed this press. Without clearing it the original handler would
; act on it too - after clamping the cursor to K it would see a top-row cursor
; and move it straight down a row, into an empty cell.
.consumeMovement:
	ldh  a, [hButtonsPressed]
	res  PADB_UP, a
	res  PADB_DOWN, a
	ldh  [hButtonsPressed], a
	ret


; Runs after the original handler, which is the only point at which the cursor
; sprite can be corrected - the original positions it on its own terms.
;
; Two jobs:
;   1. Keep the cursor inside K, L and M, and move the sprite to match.
;   2. On letter banks, hide the sprite and blink the letter instead. The
;      cursor sprite draws the *character* for the level ($20 + level selects a
;      one-tile sprite spec), and the ROM only has those specs for digits 0-9 -
;      so on a letter bank it draws a digit over the letter. Adding letter
;      sprites would mean extending SpriteData, which shifts bank 0, so we
;      blink the background cell instead.
GymLevelSelectPost::
	ldh  a, [hGameState]
	cp   GS_A_TYPE_SELECTION_MAIN
	jr   nz, .leavingScreen

	ld   a, [wGymLevelBank]
	and  a
	jr   nz, .letterBank

; digit bank: the original behaviour is already right, just undo any blink
	ld   a, [wGymBlinkCell]
	inc  a
	ret  z                          ; $ff = nothing blanked
	xor  a
	dec  a
	ld   [wGymBlinkCell], a
	ret

; The original has handed over - to the game, or back a screen. hATypeLevel has
; been holding a cursor index so the original cursor code kept working; now
; that nothing else will read it as an index, fold the bank in.
;
; This has to happen *after* the original handler, not before it. Doing it
; first meant the clamp below saw a real level rather than a cursor index and
; pulled level 21 back to 2.
.leavingScreen:
	ld   a, [wGymLevelBank]
	and  a
	ret  z                          ; bank 0: the cursor already is the level

	ld   b, a
	ldh  a, [hATypeLevel]

.addTens:
	add  10
	dec  b
	jr   nz, .addTens

	cp   MAX_LEVEL + 1              ; belt and braces
	jr   c, .storeLevel
	ld   a, MAX_LEVEL

.storeLevel:
	ldh  [hATypeLevel], a
	ret

.letterBank:
	cp   GYM_LEVEL_BANKS - 1
	jr   nz, .afterClampCursor

	ldh  a, [hATypeLevel]
	cp   GYM_TOP_BANK_COUNT
	jr   c, .afterClampCursor

	ld   a, GYM_TOP_BANK_COUNT - 1  ; walked past M: pull back and move the
	ldh  [hATypeLevel], a           ; sprite, which the original will not do
	ld   de, wSpriteSpecs + SPR_SPEC_BaseYOffset
	ld   hl, ATypeLevelsCoords
	call SetNumberSpecStructsCoordsAndSpecIdxFromHLtable
	call Copy2SpriteSpecsToShadowOam

.afterClampCursor:
; the digit sprite would sit on top of a letter, so keep it hidden
	ld   a, SPRITE_SPEC_HIDDEN
	ld   [wSpriteSpecs + SPR_SPEC_Hidden], a

; blink the selected letter at the original cadence: 16 frames on, 16 off
	ld   hl, wGymBlinkTimer
	inc  [hl]
	ld   a, [hl]
	and  $10
	ld   b, a                       ; b = phase

	ldh  a, [hATypeLevel]
	ld   c, a                       ; c = selected cell
	ld   a, [wGymBlinkCell]
	cp   c
	jr   nz, .repaint               ; cursor moved: repaint both cells
	ld   a, [wGymBlinkPhase]
	cp   b
	ret  z                          ; nothing changed

.repaint:
	ld   a, b
	ld   [wGymBlinkPhase], a
	ld   a, c
	ld   [wGymBlinkCell], a
	jp   GymRedrawLevelScreen


; Repaint the ten level cells, and the hearts indicator, to match the current
; bank. Ten tilemap writes, so we simply wait for VBlank rather than building a
; queue - the original does the same thing in HandleLockdownTransferToTilemap.
GymRedrawLevelScreen::
.waitVBlank:
	ldh  a, [rLY]
	cp   SCRN_Y
	jr   c, .waitVBlank

	ld   a, [wGymLevelBank]
	ld   hl, GymBankTiles
	and  a
	jr   z, .haveTiles
	ld   b, a
	ld   de, 10

.offsetLoop:
	add  hl, de
	dec  b
	jr   nz, .offsetLoop

.haveTiles:
	ld   de, _SCRN0 + 6 * 32 + 5    ; top row of level cells
	ld   b, 0
	call .writeRow
	ld   de, _SCRN0 + 8 * 32 + 5    ; bottom row
	ld   b, 5
	call .writeRow

; hearts indicator, in the blank strip to the right of "LEVEL"
	ldh  a, [hIsHardMode]
	and  a
	ld   a, TILE_HEART
	jr   nz, .storeHeart
	ld   a, TILE_LEVEL_ROW_BLANK

.storeHeart:
	ld   [_SCRN0 + 4 * 32 + 14], a
	ret

; Blank the selected cell while the blink phase is off, so the letter flashes
; in place of the digit sprite we had to hide.
.maybeBlank:
	push af
	ld   a, [wGymBlinkPhase]
	and  a
	jr   nz, .keepTile              ; phase on: draw normally
	ld   a, [wGymBlinkCell]
	cp   b
	jr   nz, .keepTile
	pop  af
	ld   a, TILE_BLANK_CELL
	ret

.keepTile:
	pop  af
	ret

.writeRow:
	ld   c, 5

.cellLoop:
	ld   a, [hl+]
	call .maybeBlank
	ld   [de], a
	inc  de
	inc  de                         ; cells are two tiles apart
	inc  b                          ; b tracks which cell we are on
	dec  c
	jr   nz, .cellLoop
	ret


; Tiles drawn in the ten level cells, one row of ten per bank.
GymBankTiles::
	;   0    1    2    3    4    5    6    7    8    9   - original digit art
	db $90, $91, $92, $93, $94, $95, $96, $97, $98, $99
	;   A    B    C    D    E    F    G    H    I    J   - font letters
	db $0a, $0b, $0c, $0d, $0e, $0f, $10, $11, $12, $13
	;   K    L    M   then blanks - only three valid entries
	db $14, $15, $16, $2f, $2f, $2f, $2f, $2f, $2f, $2f

; ---------------------------------------------------------------------------
; Bank 3 - reserved. Declared so the linker reports it and the ROM sizes to
; 64KB. Grow to more banks when we actually need them: a smaller ROM is a
; cheaper cartridge, and the community intends to have carts produced.
; ---------------------------------------------------------------------------

SECTION "Gym Reserved", ROMX[$4000], BANK[3]
	db "RESERVED", 0
