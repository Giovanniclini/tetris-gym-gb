; SPS - same piece sequence.
;
; The original draws pieces from the hardware divider register: `ldh a, [rDIV]`
; inside a retry loop, once per attempt. Everything downstream - the x4 counting
; loop, the bitwise-OR rejection test, the resulting 10.7/13.7/16.1% bias - is
; left exactly as it was. Only the entropy source changes.
;
; The LFSR below is transcribed byte for byte from the community's unfinished
; seeded ROM (docs/existing-hacks.md section 4). That is deliberate: for a
; fairness mechanism, interoperability *is* the feature. A given seed must
; produce the same pieces on our ROM as on theirs, so an objectively better
; generator producing different sequences would be worse.
;
; Lives in the 42 bytes of empty space between the sound engine and the sound
; thunks in bank 1, so it needs no room in bank 0 and shifts nothing. Bank 1 is
; mapped throughout gameplay, which is the only time this is called.

INCLUDE "include/hardware.inc"

SECTION "Gym Random", ROMX[$7FC6], BANK[1]

; Replaces `ldh a, [rDIV] / ld b, a` at each call site - three bytes for three,
; so nothing moves. Returns the value in B, as those two instructions did.
; Preserves HL, which the piece generator uses as its retry counter.
GymRandom::
	ldh  a, [hGymSpsEnabled]
	and  a
	jr   nz, .seeded

; SPS off: behave exactly like the original.
	ldh  a, [rDIV]
	ld   b, a
	ret

.seeded:
	push hl

	ld   hl, wGymRngLo
	ld   a, [hl+]
	ld   h, [hl]                    ; h = high byte
	ld   l, a                       ; l = low byte

; 16-bit LFSR, maximal length: period 65535 for any non-zero seed.
	ld   a, h
	rra
	ld   a, l
	rra
	xor  h
	ld   h, a

	ld   a, l
	rra
	ld   a, h
	rra
	xor  l
	ld   l, a
	xor  h
	ld   h, a

	ld   a, h
	ld   [wGymRngHi], a
	ld   a, l
	ld   [wGymRngLo], a

	ld   b, a
	pop  hl
	ret
