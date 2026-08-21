; Declared edits to the original ROM banks 0 and 1.
;
; These are the ONLY places tetris-gym-gb is permitted to change original code.
; Every entry here is asserted by tests/test_expansion.py, which diffs banks 0-1
; against the reference build and fails if a single byte outside this table
; differs. Adding an entry is a significant change - see CLAUDE.md principle 3.
;
;   name              range           bytes  purpose
;   ----------------- --------------- -----  --------------------------------
;   HOOK_TRAMPOLINE   $00DA-$00FF        38  Gym far-call trampoline, placed in
;                                            the `ds $100-@, $ff` padding that
;                                            sits between the serial interrupt
;                                            code and the $0100 entry point.
;   GYM_GRAVITY_TABLE $000B-$0027        29  Extended 23-entry gravity table
;                                            (levels 0-22), in the padding that
;                                            follows the RST $08 vector.
;   HOOK_GRAVITY_PTR  $1AFB-$1AFC         2  Operand of `ld hl, .framesData`,
;                                            redirected to GymFramesData.
;   HOOK_STATE_TABLE  $031B-$031E         4  Two entries of ProcessGameState's
;                                            jump table ($10 A-type select
;                                            init, $11 main), routed through
;                                            GymStateHook. The handlers
;                                            themselves are untouched.
;   GYM_RESET_STUB    $0034-$003F        12  Far-call stub for instant restart,
;                                            in the padding between the RST $28
;                                            handler and the VBlank vector.
;   HOOK_MAINLOOP_RST $02D3-$02D5         3  MainLoop's soft-reset `jp z, Reset`
;                                            becomes `call z, GymResetStub`, so
;                                            the Gym can decline and carry on.
;   HOOK_INGAME_RST   $1C14-$1C15         2  Operand of the *other* soft-reset
;                                            check, inside
;                                            InGameCheckResetAndPause. This is
;                                            the one that fires while playing.
;   HOOK_STATE_TABLE4 $0303-$0304         2  Jump-table entry for $04, the
;                                            end-of-game screen, so the reset
;                                            combination is seen before that
;                                            handler acts on Start.
;   HOOK_RNG_PIECE    $2043-$2045         3  `ldh a,[rDIV] / ld b,a` in the
;                                            piece generator becomes
;                                            `call GymRandom` - three bytes for
;                                            three, so nothing shifts.
;   HOOK_RNG_BTYPE    $1B6F-$1B71         3  The same substitution for B-type's
;                                            starting garbage.
;   GYM_RANDOM        $7FC6-$7FEF        42  The LFSR itself, in the empty space
;                                            between the sound engine and the
;                                            sound thunks in bank 1. A new
;                                            section in a gap, not an insertion.
;   HOOK_STATE_TABLE15 $0325-$0326        2  Jump-table entry for $15, high
;                                            score name entry, so the reset
;                                            combination restarts the drill
;                                            rather than rebooting.
;   HOOK_STATE_TABLE0A $030F-$0310        2  Jump-table entry for $0A, in-game
;                                            init, so the configured seed is
;                                            loaded into the LFSR at the start
;                                            of every game - including an
;                                            instant restart, which must repeat
;                                            the sequence rather than continue.
;   HOOK_LEVEL_CAP    $2459               1  Operand of `cp $14`, raised to $16
;                                            so levelling up from an L or M
;                                            start cannot run past the table.
;   HOOK_STATE_TABLE00 $02FB-$02FC       2  Jump-table entry for $00, the
;                                            per-frame gameplay state. The one
;                                            hook trainers act from while a game
;                                            is running - the transition trainer
;                                            needs it because the original's
;                                            in-game init clears the line count
;                                            after any earlier hook could set it.
;   HOOK_STATE_TABLE0E $0317-$0318       2  Jump-table entry for $0E, the
;                                            A-TYPE/B-TYPE screen, which becomes
;                                            the Gym menu. The only hook that
;                                            replaces an original handler rather
;                                            than chaining to it.
;
; Nothing else in banks 0-1 may change.
;
; Note the shape of these: we redirect pointers and constants into space we
; reclaimed, we never *insert* into the original banks. Inserting shifts every
; byte after the insertion point - which is exactly why KLM is a 20KB binary
; diff for a feature we express in 54 bytes.

DEF HOOK_TRAMPOLINE_START EQU $00DA
DEF HOOK_TRAMPOLINE_END   EQU $00FF
DEF GYM_GRAVITY_START     EQU $000B
DEF GYM_GRAVITY_END       EQU $0027
