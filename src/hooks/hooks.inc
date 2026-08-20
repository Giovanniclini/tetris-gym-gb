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
;
; Nothing else in banks 0-1 may change.

DEF HOOK_TRAMPOLINE_START EQU $00DA
DEF HOOK_TRAMPOLINE_END   EQU $00FF
