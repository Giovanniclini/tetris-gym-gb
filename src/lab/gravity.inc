; Extended gravity table: levels 0-22, i.e. 0-9 then A-M.
;
; Each entry is (frames per row - 1); the game reloads the gravity counter with
; the stored value and counts down. Levels 0-20 are byte-identical to the
; original. L and M are not our invention: they match the community's KLM
; romhack - Ospin, Tolstoj, Pascal and Hepps in lineage - exactly, verified by
; reverse engineering it (docs/existing-hacks.md section 3). A practice level
; has to mean the same thing on both ROMs or the numbers players quote each
; other stop being comparable.
;
; M ($00 = one row per frame) is the hard ceiling of the mechanism, not an
; arbitrary stop: the counter cannot reload with less than one frame.
;
; Lives in the 29 bytes of $ff padding at $000B-$0027 so bank 0 keeps its
; original layout. 23 bytes used, 6 spare.

INCLUDE "lab/levels.inc"

LabFramesData::
	;   0    1    2    3    4    5    6    7    8    9
	db $34, $30, $2c, $28, $24, $20, $1b, $15, $10, $0a
	;   A    B    C    D    E    F    G    H    I    J
	db $09, $08, $07, $06, $05, $05, $04, $04, $03, $03
	;   K    L    M
	db $02, $01, $00
