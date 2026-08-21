; SPS - same piece sequence.
;
; The original draws pieces from the hardware divider register: `ldh a, [rDIV]`
; inside a retry loop, once per attempt. Everything downstream - the x4 counting
; loop, the bitwise-OR rejection test, the resulting 10.7/13.7/16.1% bias - is
; left exactly as it was. Only the entropy source changes.
;
; The LFSR below is NOT ours. It is transcribed byte for byte from the seeded
; ROM already circulating in the GBTetris community (docs/existing-hacks.md
; section 4). Ospin found it - it comes from the public literature rather than
; being anyone's invention - and Tolstoj confirmed its provenance.
;
; It is 16-bit, and the community is moving to 24 bits: Toni is building that,
; and Tolstoj's guidance is to adopt it rather than keep this. Nobody uses the
; four-digit seeds, so there is no compatibility to preserve.
;
; That it is theirs is the point: for a fairness mechanism, interoperability
; *is* the feature. A given seed must produce the same pieces on our ROM as on
; theirs, so an objectively better generator producing different sequences would
; be worse.
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


; ---------------------------------------------------------------------------
; Bank 1 thunk
;
; LoadAsciiAndMenuScreenGfx lives in bank 0 but reads Gfx_Ascii from bank 1
; ($415F), so it cannot be called while bank 2 is mapped - that address holds
; Gym code. Bank-2 code must not switch banks itself (ADR 0001), so the call
; happens from here, reached through FarCall with bank 1 selected.
;
; In the empty gap the linker reports between the demo steps and the demo piece
; table. A new section in a hole, not an insertion.
; ---------------------------------------------------------------------------

SECTION "Gym Bank 1 Thunk", ROMX[$6430], BANK[1]

GymLoadMenuGfx::
	call TurnOffLCD
	call LoadAsciiAndMenuScreenGfx
	ret
