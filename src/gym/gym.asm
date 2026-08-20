; Gym core - everything this project adds lives in ROM banks 2 and up.
;
; Bank 0 and bank 1 remain the original game, byte for byte, except for the
; single declared hook in src/hooks/hooks.inc.

INCLUDE "include/hardware.inc"
INCLUDE "include/constants.s"   ; pure EQUs, safe in multiple translation units

INCLUDE "gym/levels.inc"

DEF TILE_HEART          EQU $27
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

	ds 1023
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

	call GymLevelSelectMain
	ld   hl, GameState11_ATypeSelectionMain
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
	ret


; One frame of the level select screen. Runs before the original handler.
;
; Acts only on inputs the original ignores here, so nothing needs suppressing:
;   - Down on the bottom row / Up on the top row: the original explicitly
;     ignores these (`cp $05 / jr nc`), we use them to cycle the level bank
;   - Select: the original never tests it on this screen
GymLevelSelectMain::
	ldh  a, [hButtonsPressed]
	ld   c, a

; Start or A begins the game. hATypeLevel has been holding the cursor index so
; that the original cursor code keeps working unchanged, so fold the bank back
; in before the original handler hands over to the game.
	bit  PADB_START, c
	jr   nz, .combineLevel
	bit  PADB_A, c
	jr   nz, .combineLevel

; Select toggles hard mode ("hearts"). The original arms it with an
; undocumented Down+Start on the title screen, two screens earlier, with no
; feedback until a heart appears here. It never tests Select on this screen.
	bit  PADB_SELECT, c
	jr   nz, .toggleHearts

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
	jr   .bankNext

.checkUp:
	bit  PADB_UP, c
	ret  z
	ld   a, e
	cp   5
	ret  nc                         ; not on the top row
	jr   .bankPrev

; The K-M bank has only three cells, all on the top row, so vertical movement
; has nothing to move to and always cycles. Right must stop at M, which the
; original would otherwise walk past into empty cells.
.topBankKeys:
	bit  PADB_DOWN, c
	jr   nz, .bankNext
	bit  PADB_UP, c
	jr   nz, .bankPrev

	bit  PADB_RIGHT, c
	ret  z
	ldh  a, [hATypeLevel]
	cp   GYM_TOP_BANK_COUNT - 1
	ret  c                          ; room left, let the original move
	jr   .consumeMovement           ; at M already

.combineLevel:
	ld   a, [wGymLevelBank]
	and  a
	ret  z                          ; bank 0: the cursor already is the level

	ld   b, a
	ldh  a, [hATypeLevel]

.addTens:
	add  10
	dec  b
	jr   nz, .addTens

	cp   MAX_LEVEL + 1              ; belt and braces; the cursor clamp should
	jr   c, .storeLevel             ; already make this unreachable
	ld   a, MAX_LEVEL

.storeLevel:
	ldh  [hATypeLevel], a
	ret

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

; Pull the cursor back if it is parked beyond M in the top bank.
	cp   GYM_LEVEL_BANKS - 1
	jr   nz, .afterClamp
	ldh  a, [hATypeLevel]
	cp   GYM_TOP_BANK_COUNT
	jr   c, .afterClamp
	ld   a, GYM_TOP_BANK_COUNT - 1
	ldh  [hATypeLevel], a

.afterClamp:
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
	res  PADB_RIGHT, a
	ldh  [hButtonsPressed], a
	ret


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
	call .writeRow
	ld   de, _SCRN0 + 8 * 32 + 5    ; bottom row
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

.writeRow:
	ld   c, 5

.cellLoop:
	ld   a, [hl+]
	ld   [de], a
	inc  de
	inc  de                         ; cells are two tiles apart
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
