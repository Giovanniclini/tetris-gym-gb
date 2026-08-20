; Gym far-call trampoline.
;
; Lives in the original ROM's entry-point padding ($00DA-$00FF, 38 bytes of
; $FF). Must stay in bank 0, because the caller may be executing from any bank.
;
; Calling convention:
;     b  = target bank
;     hl = target address
;   FarCall preserves A (so a far routine can return a value in it) and
;   clobbers B and the flags. Nesting depth 1 only - hGymBank holds the bank to
;   restore, and a nested FarCall would overwrite it.
;
; The original game already writes 1 to $2000 during init (verified at $0252),
; which on MBC1 selects bank 1 - the correct default. See docs/research.md 3.6.

FarCall::
	ldh  a, [hGymBank]
	push af                 ; stash the bank we came from
	ld   a, b
	ldh  [hGymBank], a
	ld   [$2000], a         ; MBC1 ROM bank select
	call .jumpHL
	ld   b, a               ; preserve the far routine's return value
	pop  af                 ; a = previous bank (flags clobbered)
	ldh  [hGymBank], a
	ld   [$2000], a
	ld   a, b
	ret

.jumpHL:
	jp   hl
