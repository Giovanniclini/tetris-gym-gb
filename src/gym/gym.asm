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

; Gym menu. wGymMode is the row the cursor sits on, and survives into the game
; so trainers can ask which drill is running.
wGymMode::        db        ; MODE_TETRIS / MODE_BTYPE / MODE_TRANSITION
wGymDrillPending:: db       ; set at game init, consumed on the first game frame
wGymDrillLevel::  db        ; the level the TRANSITION row is set to
wGymSeedDigit::   db        ; 0-3 while editing the seed row, else SEED_IDLE

	ds 1009
wGymStateEnd::

; ---------------------------------------------------------------------------
; Bank 2 - Gym core
; ---------------------------------------------------------------------------

SECTION "Gym Core", ROMX[$4000], BANK[2]

GymVersion::
	db "TETRISGYMGB 0.2", 0

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
	cp   GS_TITLE_SCREEN_MAIN
	jp   z, .menu
	cp   GS_TITLE_SCREEN_INIT
	jp   z, .menuInit
	cp   GS_GAME_MUSIC_TYPE_INIT
	jp   z, .backToMenu
	cp   GS_IN_GAME_MAIN
	jp   z, .inGameMain
	cp   GS_COPYRIGHT_DISPLAY
	jr   z, .skipCopyright

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
	call GymArmDrill
	ld   hl, GameState0a_InGameInit
	ret

; The copyright screen: 8.5 seconds before the title, every boot. Its only
; lasting effect is copying DemoPieces into wDemoOrMultiplayerPieces, and the
; only thing that reads that is the attract demo - 2-player shuffles its own
; table into it at $068C. The Gym menu never runs a demo, so none of it is
; needed. The tile data comes from $06 either way.
.skipCopyright:
	ld   a, GS_TITLE_SCREEN_INIT
	ldh  [hGameState], a
	ld   hl, Stub_148c
	ret

; The title screen's init, replaced so the original title is never drawn. The
; clears are the original's ($03AE), transcribed; only the screen is ours.
;
; The screen buffer clear is not cosmetic. InGameCheckIfAnyTetrisRowsComplete
; ($213E) scans wGameScreenBuffer for TILE_EMPTY to decide which rows are full -
; leave it holding anything else and every row reads as complete the moment the
; first piece lands, which overruns a four-entry list and hangs the game.
.menuInit:
	xor  a
	ldh  [hIsRecordingDemo], a
	ldh  [hPieceFallingState], a
	ldh  [hTetrisFlashCount], a
	ldh  [hPieceCollisionDetected], a
	ldh  [h1stHighScoreHighestByteForLevel], a
	ldh  [hNumLinesCompletedBCD + 1], a
	ldh  [hRowsShiftingDownState], a
	ldh  [hMustEnterHighScore], a
	call ClearPointersToCompletedTetrisRows
	call ClearScoreCategoryVarsAndTotalScore

	ld   hl, wGameScreenBuffer
.clearScreenBuffer:
	ld   a, TILE_EMPTY
	ld   [hl+], a
	ld   a, h
	cp   HIGH(wGameScreenBuffer.end)
	jr   nz, .clearScreenBuffer

; The walls and the floor. Not decoration: the falling piece collides against
; what is in this buffer, so without them a piece falls past the bottom for
; ever and no game ever ends.
	ld   hl, wGameScreenBuffer + 1
	call DisplayBlackColumnFromHLdown
	ld   hl, wGameScreenBuffer + $c
	call DisplayBlackColumnFromHLdown

	ld   hl, wGameScreenBuffer + $241
	ld   b, $0c
	ld   a, TILE_BLACK
.displayBlackRow:
	ld   [hl+], a
	dec  b
	jr   nz, .displayBlackRow

; serial back on: the menu is where a link partner finds us
	ld   a, IEF_VBLANK | IEF_SERIAL
	ldh  [rIE], a

	ld   a, SEED_IDLE
	ld   [wGymSeedDigit], a
	call GymMenuDraw

; Start the music the MUSIC row is set to. The screens this menu replaced each
; did their own: the title screen played MUS_TITLE_SCREEN, the A/B screen played
; the chosen type ($1481). The chosen type is right here - you audition it on
; the row - so that is the one to play. Without this the menu is silent until
; you nudge the row, which is what gave it away.
	call PlaySongBasedOnMusicTypeChosen
	ld   a, GS_TITLE_SCREEN_MAIN
	ldh  [hGameState], a
	ld   hl, Stub_148c
	ret

; B on a level select goes to $08, which would load the A-TYPE/B-TYPE screen.
; Send it back to the Gym menu instead - that is where it came from.
.backToMenu:
	ld   a, GS_TITLE_SCREEN_INIT
	ldh  [hGameState], a
	ld   hl, Stub_148c
	ret

; The Gym menu, on the title screen. The original handler never runs - this is a
; replacement, not an extension - so the Gym has to keep pinging for a link
; partner in its place.
.menu:
	call GymMenu
	ld   hl, Stub_148c
	ret

; Every gameplay frame. Anything a trainer must do after the original's in-game
; init has run belongs here: that init clears the line count and the score, so
; setting them beforehand achieves nothing.
.inGameMain:
	call GymDrillApply
	ld   hl, GameState00_InGameMain
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
DEF HEART_CELL    EQU _SCRN0 + 4 * 32 + 14
DEF TILE_HEART    EQU $27
DEF TILE_FRAME    EQU $2c       ; what the original draws in the heart cell
DEF TILE_BLANK    EQU $2f
DEF GRID_LAST     EQU 9

DEF FOCUS_GRID    EQU 0
DEF FOCUS_LEVEL   EQU 1



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
	jr   nz, .levelFocus

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
	jr   nz, .consume               ; nothing to the right of the level now

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
; C = digit index 0-3, leftmost first.
GymAdjustSeedNibble::
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



; ---------------------------------------------------------------------------
; The Gym menu
;
; TetrisGYM's game type menu is one scrolling list where the playable modes come
; first and the settings follow, each row carrying its own value edited in place
; (src/gamemode/gametypemenu/menu.asm). This is that list, on the screen the
; original used to offer A-TYPE and B-TYPE - which was already "what do you want
; to play", and is the only menu screen the game has. See docs/decisions/0007.
;
; Up/Down move, Left/Right change the value on the row, Start or A launches.
; MUSIC is a setting, not a mode, so Start does nothing on it - the same split
; TetrisGYM draws at MODE_GAME_QUANTITY.
; ---------------------------------------------------------------------------

DEF MODE_TETRIS     EQU 0
DEF MODE_BTYPE      EQU 1
DEF MODE_2PLAYER    EQU 2
DEF MODE_TRANSITION EQU 3
DEF MODE_LAUNCHABLE EQU 4           ; rows below this start a game
DEF MODE_SEED       EQU 4
DEF MODE_MUSIC      EQU 5
DEF MODE_COUNT      EQU 6

DEF MENU_ROW0       EQU _SCRN0 + 6 * 32 + 3   ; first entry
DEF MENU_STRIDE     EQU 2 * 32                ; a blank line between entries
DEF MENU_TEXT_COL   EQU 2                     ; label starts 2 cells in
DEF MENU_VALUE_COL  EQU 13                    ; the row's value, right of it
DEF MENU_CURSOR     EQU $26                   ; the font's "*"
DEF SEED_IDLE       EQU $ff                   ; wGymSeedDigit when not editing

NEWCHARMAP gymfont
	CHARMAP "0", $00
	CHARMAP "1", $01
	CHARMAP "2", $02
	CHARMAP "3", $03
	CHARMAP "4", $04
	CHARMAP "5", $05
	CHARMAP "6", $06
	CHARMAP "7", $07
	CHARMAP "8", $08
	CHARMAP "9", $09
	CHARMAP "A", $0a
	CHARMAP "B", $0b
	CHARMAP "C", $0c
	CHARMAP "D", $0d
	CHARMAP "E", $0e
	CHARMAP "F", $0f
	CHARMAP "G", $10
	CHARMAP "H", $11
	CHARMAP "I", $12
	CHARMAP "J", $13
	CHARMAP "K", $14
	CHARMAP "L", $15
	CHARMAP "M", $16
	CHARMAP "N", $17
	CHARMAP "O", $18
	CHARMAP "P", $19
	CHARMAP "Q", $1a
	CHARMAP "R", $1b
	CHARMAP "S", $1c
	CHARMAP "T", $1d
	CHARMAP "U", $1e
	CHARMAP "V", $1f
	CHARMAP "W", $20
	CHARMAP "X", $21
	CHARMAP "Y", $22
	CHARMAP "Z", $23
	CHARMAP "-", $25
	CHARMAP " ", TILE_BLANK
SETCHARMAP main


; The menu screen is painted by the init state and nowhere else, the way every
; original screen works. $07 is only ever reached through $06 - including when
; SerialFunc0_titleScreen bounces a stray serial byte back there - so there is
; no first-entry case to handle.
GymMenu::
	call GymLinkPing
	ldh  a, [hGameState]
	cp   GS_TITLE_SCREEN_MAIN
	ret  nz                         ; a partner took over; stop touching the menu

	call GymMenuInput
	jp   GymMenuRepaint


; The title screen's own rendezvous, transcribed from GameState07_TitleScreenMain
; ($0488). A second Game Boy finds us by seeing this ping, so the menu has to
; keep sending it - and it has to do so from state $07, because
; SerialFunc0_titleScreen only assigns roles while hGameState says $07.
GymLinkPing::
	call SerialTransferWaitFunc
	ld   a, SB_PASSIVES_PING_IN_TITLE_SCREEN
	ldh  [rSB], a
	ld   a, SC_REQUEST_TRANSFER|SC_PASSIVE
	ldh  [rSC], a

	ldh  a, [hSerialInterruptHandled]
	and  a
	ret  z                          ; nothing arrived

	ldh  a, [hMultiplayerPlayerRole]
	and  a
	jp   nz, GymStart2Player        ; assigned a role: the master is waiting

	xor  a                          ; a byte, but no role - not a partner
	ldh  [hSerialInterruptHandled], a
	ret


GymStart2Player::
	xor  a
	ldh  [hTimer1], a
	ld   a, GS_2PLAYER_GAME_MUSIC_TYPE_INIT
	ldh  [hGameState], a
	ret


GymMenuInput::
	ldh  a, [hButtonsPressed]
	ld   c, a

; The seed needs a cursor of its own, so the row borrows the D-pad while it is
; being edited. A gets in and out. TetrisGYM gives the seed row the same
; treatment (seedControls in gametypemenu/menu.asm); it can leave Up and Down
; free for the list because its list scrolls under a throttle and ours does not.
	ld   a, [wGymSeedDigit]
	cp   SEED_IDLE
	jr   nz, .editingSeed

	bit  PADB_START, c
	jr   nz, .confirm
	bit  PADB_A, c
	jr   nz, .confirm

	bit  PADB_DOWN, c
	jr   z, .notDown
	ld   a, [wGymMode]
	inc  a
	cp   MODE_COUNT
	jr   c, .setRow
	xor  a
	jr   .setRow

.notDown:
	bit  PADB_UP, c
	jr   z, .notUp
	ld   a, [wGymMode]
	and  a
	jr   nz, .decRow
	ld   a, MODE_COUNT
.decRow:
	dec  a
	jr   .setRow

.notUp:
	ld   a, c
	and  PADF_LEFT | PADF_RIGHT
	ret  z
	ld   b, 1
	bit  PADB_RIGHT, c
	jr   nz, .haveDelta
	ld   b, -1
.haveDelta:
	ld   a, [wGymMode]
	cp   MODE_MUSIC
	jr   z, .adjustMusic
	cp   MODE_TRANSITION
	ret  nz

; the level the drill starts on, 0-22, shown as 0-9 then A-M
	ld   a, [wGymDrillLevel]
	add  b
	cp   MAX_LEVEL + 1
	jr   c, .storeLevel
	and  a                          ; wrapped past 0 or past M
	ld   a, MAX_LEVEL
	jr   nz, .storeLevel
	xor  a
.storeLevel:
	ld   [wGymDrillLevel], a
	jp   GymMenuSound

.adjustMusic:
	ldh  a, [hMusicType]
	sub  MUSIC_TYPES_START
	add  b
	and  $03                        ; four options, wrapping
	add  MUSIC_TYPES_START
	ldh  [hMusicType], a
	call PlaySongBasedOnMusicTypeChosen
	jp   GymMenuSound

.setRow:
	ld   [wGymMode], a
	jp   GymMenuSound

; Start or A. On a mode it launches; on the seed it opens the digits; on any
; other setting it does nothing, the split TetrisGYM draws at MODE_GAME_QUANTITY.
.confirm:
	ld   a, [wGymMode]
	cp   MODE_SEED
	jr   z, .editSeed
	cp   MODE_LAUNCHABLE
	ret  nc
	jp   GymMenuLaunch

.editSeed:
	xor  a
	ld   [wGymSeedDigit], a
	jp   GymMenuSound

; --- the seed row has the D-pad ---
.editingSeed:
	ld   d, a                       ; d = digit index

	bit  PADB_START, c
	jr   nz, .leaveSeed
	bit  PADB_A, c
	jr   nz, .leaveSeed

	bit  PADB_UP, c
	jr   z, .seedNotUp
	ld   b, 1
	jr   .seedAdjust
.seedNotUp:
	bit  PADB_DOWN, c
	jr   z, .seedNotDown
	ld   b, -1
.seedAdjust:
	ld   a, d
	ld   c, a
	call GymAdjustSeedNibble
	jp   GymMenuSound

.seedNotDown:
	bit  PADB_RIGHT, c
	jr   z, .seedNotRight
	ld   a, d
	cp   3
	ret  nc
	inc  a
	ld   [wGymSeedDigit], a
	jp   GymMenuSound

.seedNotRight:
	bit  PADB_LEFT, c
	ret  z
	ld   a, d
	and  a
	jr   z, .leaveSeed              ; Left off the first digit leaves the row
	dec  a
	ld   [wGymSeedDigit], a
	jp   GymMenuSound

.leaveSeed:
	ld   a, SEED_IDLE
	ld   [wGymSeedDigit], a
	jp   GymMenuSound


; Start on a mode. TETRIS and B-TYPE hand over to that type's level select, the
; way the original screen did. TRANSITION carries its own level, so it goes
; straight into the game - a drill you set up once and repeat.
GymMenuLaunch::
	ld   a, [wGymMode]
	cp   MODE_2PLAYER
	jr   z, .keepSerial
; What $08 did on the way into a one-player game ($1444): serial off, and the
; serial registers and any pending interrupt cleared. Leaving rIF holding a
; stale serial flag is what froze the first piece.
	ld   a, IEF_VBLANK
	ldh  [rIE], a
	xor  a
	ldh  [rSB], a
	ldh  [rSC], a
	ldh  [rIF], a
.keepSerial:
	ld   a, SND_CONFIRM_OR_LETTER_TYPED
	ld   [wSquareSoundToPlay], a

	ld   a, [wGymMode]
	cp   MODE_BTYPE
	jr   z, .bType
	cp   MODE_2PLAYER
	jr   z, .twoPlayer
	cp   MODE_TRANSITION
	jr   z, .transition

	ld   a, GAME_TYPE_A_TYPE
	ldh  [hGameType], a
	ld   a, GS_A_TYPE_SELECTION_INIT
	ldh  [hGameState], a
	ret

.bType:
	ld   a, GAME_TYPE_B_TYPE
	ldh  [hGameType], a
	ld   a, GS_B_TYPE_SELECTION_INIT
	ldh  [hGameState], a
	ret

.transition:
	ld   a, GAME_TYPE_A_TYPE
	ldh  [hGameType], a
	ld   a, [wGymDrillLevel]
	ldh  [hATypeLevel], a
	ld   a, GS_IN_GAME_INIT
	ldh  [hGameState], a
	ret

; The master half of the handshake, transcribed from $04BF. If a role is already
; assigned we are the master and the passive is waiting; otherwise announce
; ourselves and wait one transfer for an answer. With no cable the transfer
; still completes - the byte just comes back as $FF - so this cannot hang, and
; no role is assigned, and we stay on the menu.
.twoPlayer:
	ldh  a, [hMultiplayerPlayerRole]
	cp   MP_ROLE_MASTER
	jp   z, GymStart2Player

	ld   a, SB_MASTER_PRESSING_START
	ldh  [rSB], a
	ld   a, SC_REQUEST_TRANSFER|SC_MASTER
	ldh  [rSC], a

.waitForAnswer:
	ldh  a, [hSerialInterruptHandled]
	and  a
	jr   z, .waitForAnswer

	ldh  a, [hMultiplayerPlayerRole]
	and  a
	ret  z                          ; nobody answered: stay where we are
	jp   GymStart2Player


; A = tile, HL = destination. The hardware drops tilemap writes made while a
; line is being drawn, so every cell the menu paints goes through here.
; Preserves BC and DE, which StoreAinHLwhenLCDFree does not.
GymPutTile::
	push bc
	call StoreAinHLwhenLCDFree
	pop  bc
	ret


GymMenuSound::
	ld   a, SND_MOVING_SELECTION
	ld   [wSquareSoundToPlay], a
	ret


; The one-off paint, with the LCD off - the labels never change afterwards.
GymMenuDraw::
	ld   b, BANK(GymLoadMenuGfx)
	ld   hl, GymLoadMenuGfx
	call FarCall                    ; LCD off, then the menu tileset
	call Clear_wOam

	ld   hl, _SCRN0
	ld   bc, 32 * 18
.blank:
	ld   a, TILE_BLANK
	ld   [hl+], a
	dec  bc
	ld   a, b
	or   c
	jr   nz, .blank

	ld   hl, GymMenuTitle
	ld   de, _SCRN0 + 2 * 32 + 3
	call GymMenuPutString

	ld   hl, GymMenuLabels
	ld   de, MENU_ROW0 + MENU_TEXT_COL
	ld   b, MODE_COUNT
.nextLabel:
	push bc
	push de
	call GymMenuPutString
	pop  de
	ld   a, e
	add  LOW(MENU_STRIDE)
	ld   e, a
	jr   nc, .noCarry
	inc  d
.noCarry:
	pop  bc
	dec  b
	jr   nz, .nextLabel

	call GymMenuPaint

	ld   a, LCDCF_ON|LCDCF_WIN9C00|LCDCF_BG8000|LCDCF_OBJON|LCDCF_BGON
	ldh  [rLCDC], a
	ret


; Everything that changes: the cursor cells and the row values. Every write goes
; through GymPutTile, which waits for the LCD - dropped writes are what made the
; cursor vanish at random and left the music letter stale.
GymMenuRepaint::
	ld   hl, wGymBlinkTimer
	inc  [hl]

GymMenuPaint::
	ld   de, MENU_ROW0
	ld   b, 0

.nextRow:
	ld   a, [wGymMode]
	cp   b
	ld   a, MENU_CURSOR
	jr   z, .putCursor
	ld   a, TILE_BLANK
.putCursor:
	ld   h, d
	ld   l, e
	call GymPutTile

; the value, if the row has one
	ld   a, b
	cp   MODE_TRANSITION
	call z, GymMenuPaintLevel
	ld   a, b
	cp   MODE_SEED
	call z, GymMenuPaintSeed
	ld   a, b
	cp   MODE_MUSIC
	call z, GymMenuPaintMusic

	ld   hl, MENU_STRIDE
	add  hl, de
	ld   d, h
	ld   e, l
	inc  b
	ld   a, b
	cp   MODE_COUNT
	jr   c, .nextRow
	ret


; DE = row base. Returns HL at the row's value column.
GymMenuValueCell::
	ld   hl, MENU_VALUE_COL
	add  hl, de
	ret


; 0-9 then A-M: the font puts those tiles at $00-$16, so the tile is the level.
GymMenuPaintLevel::
	call GymMenuValueCell
	ld   a, [wGymDrillLevel]
	jp   GymPutTile


; Four hex digits; the tile is the nibble. The digit being edited blinks.
GymMenuPaintSeed::
	call GymMenuValueCell
	push de
	ld   d, h
	ld   e, l
	ld   c, 0
.digit:
	push de
	call GymReadSeedNibble
	push af
	ld   a, [wGymSeedDigit]
	cp   c
	jr   nz, .draw
	ld   a, [wGymBlinkTimer]
	and  $10
	jr   nz, .draw
	pop  af
	ld   a, TILE_BLANK
	jr   .store
.draw:
	pop  af
.store:
	pop  de
	ld   h, d
	ld   l, e
	call GymPutTile
	inc  de
	inc  c
	ld   a, c
	cp   4
	jr   c, .digit
	pop  de
	ret


; The music letter. OFF is drawn as a dash.
GymMenuPaintMusic::
	call GymMenuValueCell
	ldh  a, [hMusicType]
	cp   MUSIC_TYPE_OFF
	ld   a, $25                     ; "-"
	jr   z, .put
	ldh  a, [hMusicType]
	sub  MUSIC_TYPES_START
	add  $0a                        ; "A"
.put:
	jp   GymPutTile


; hl = zero-terminated string, de = tilemap destination.
GymMenuPutString::
	ld   a, [hl+]
	and  a
	ret  z
	ld   [de], a
	inc  de
	jr   GymMenuPutString


PUSHC
SETCHARMAP gymfont
GymMenuTitle::
	db "TETRIS GYM GB", 0

; One zero-terminated label per row, in wGymMode order.
GymMenuLabels::
	db "TETRIS", 0
	db "B-TYPE", 0
	db "2 PLAYER", 0
	db "TRANSITION", 0
	db "SEED", 0
	db "MUSIC", 0
POPC


; ---------------------------------------------------------------------------
; Transition trainer
;
; TetrisGYM's TRANSITION (src/gamemodestate/initstate.asm, transitionModeSetup)
; fills the line counter up to the last ten-line boundary before the level
; advances, so you start one clear away from the speed change.
;
; The Game Boy's transition is that boundary: the original treats your starting
; level as the number of tens you must clear, so a level 9 start transitions at
; 100 lines. Ten short of it is 90.
;
; The one thing not carried over is TetrisGYM's score preset. Its modifier
; exists so the score and pace readouts look like a real run at that point;
; the Game Boy has no pace display and its transition point moves with the
; start level, so there is nothing for the number to mean here.
; ---------------------------------------------------------------------------

GymArmDrill::
	ld   a, [wGymMode]
	cp   MODE_TRANSITION
	ret  nz
	ld   a, 1
	ld   [wGymDrillPending], a
	ret


; The original's in-game init clears the line counter, so this runs on the first
; gameplay frame instead - after it, not before.
GymDrillApply::
	ld   a, [wGymDrillPending]
	and  a
	ret  z
	xor  a
	ld   [wGymDrillPending], a

; hATypeLinesThresholdToPassForNextLevel holds the start level, which is also
; the number of tens that must be cleared to transition. One ten short of it is
; where the drill begins.
; The game levels up when lines/10 exceeds the level, so a level 9 start
; transitions at 100 lines. Ten short of that is 90 - the level's own count of
; tens. Level 0 transitions at 10, so its drill preloads nothing.
	ldh  a, [hATypeLinesThresholdToPassForNextLevel]
	and  a
	ret  z
	ld   b, a                       ; tens to preload, 1-22

	xor  a
	ld   c, a                       ; hundreds, BCD
	ld   d, a                       ; tens and units, BCD

.addTen:
	ld   a, b
	and  a
	jr   z, .store
	dec  b
	ld   a, d
	add  $10
	daa
	ld   d, a
	jr   nc, .addTen
	ld   a, c
	add  1
	daa
	ld   c, a
	jr   .addTen

.store:
	ld   a, d
	ldh  [hNumLinesCompletedBCD], a
	ld   a, c
	ldh  [hNumLinesCompletedBCD+1], a

; Repaint the readout: the original only redraws it on a line clear, so without
; this the game shows 000 until the first one.
	jp   GymDrillPaintLines


; The four LINES digits, leading zeros blanked, exactly as the original renders
; them. Not DisplayBCDNum2CDigits: that writes the tilemap with a bare
; `ld [hl+], a`, which is correct for the original - it only ever calls it with
; the LCD idle - and drops writes anywhere else.
GymDrillPaintLines::
	ldh  a, [hNumLinesCompletedBCD + 1]
	ld   d, a
	ldh  a, [hNumLinesCompletedBCD]
	ld   e, a
	ld   hl, _SCRN0 + $14e
	ld   c, 0                       ; set once a digit has been drawn

	ld   a, d
	swap a
	call GymDrillDigit
	ld   a, d
	call GymDrillDigit
	ld   a, e
	swap a
	call GymDrillDigit
	ld   c, 1                       ; the units digit always shows
	ld   a, e
	; falls through

GymDrillDigit:
	and  $0f
	jr   nz, .visible

	ld   a, c
	and  a
	ld   a, TILE_EMPTY              ; nothing drawn yet: a leading zero
	jr   z, .put
	ld   a, TILE_0                  ; inside the number: a real zero
	jr   .put

.visible:
	ld   c, 1

.put:
	call GymPutTile
	inc  hl
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
