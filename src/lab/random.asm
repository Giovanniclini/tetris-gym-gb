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

SECTION "Lab Random", ROMX[$7FC6], BANK[1]

; Replaces `ldh a, [rDIV] / ld b, a` at each call site - three bytes for three,
; so nothing moves. Returns the value in B, as those two instructions did.
; Preserves HL, which the piece generator uses as its retry counter.
LabRandom::
	ldh  a, [hLabSpsEnabled]
	and  a
	jr   nz, .seeded

; SPS off: behave exactly like the original.
	ldh  a, [rDIV]
	ld   b, a
	ret

.seeded:
	push hl

	ld   hl, wLabRngLo
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
	ld   [wLabRngHi], a
	ld   a, l
	ld   [wLabRngLo], a

	ld   b, a
	pop  hl
	ret


; ---------------------------------------------------------------------------
; Bank 1 thunk
;
; LoadAsciiAndMenuScreenGfx lives in bank 0 but reads Gfx_Ascii from bank 1
; ($415F), so it cannot be called while bank 2 is mapped - that address holds
; Lab code. Bank-2 code must not switch banks itself (ADR 0001), so the call
; happens from here, reached through FarCall with bank 1 selected.
;
; In the empty gap the linker reports between the demo steps and the demo piece
; table. A new section in a hole, not an insertion.
; ---------------------------------------------------------------------------

; Two gaps, because neither is big enough alone: 32 bytes here and 10 at the
; very end of the bank, past the sound thunks.

SECTION "Lab Bank 1 Gfx Thunk", ROMX[$7FF6], BANK[1]

LabLoadMenuGfx::
	call TurnOffLCD
	call LoadAsciiAndMenuScreenGfx
	ret


SECTION "Lab Bank 1 Thunk", ROMX[$6430], BANK[1]


; ---------------------------------------------------------------------------
; Score uncap
;
; The original stops the score at 999 999 by pinning all three BCD bytes to $99
; when the add carries out of the top one ($0178). That is the ceiling of the
; storage, not a rule: three BCD bytes hold six digits and the clamp exists to
; stop them wrapping to zero.
;
; The clamp is replaced by a jump here. By this point the add has already
; wrapped the three bytes to the low six digits, so all that is missing is the
; carry - one more BCD byte, giving digits 7 and 8.
;
; AddScoreValueDEontoBaseScoreHL is generic: it adds into whatever HL points at,
; from five different call sites. Only the live score gets a carry digit, so the
; pointer is checked first.
;
; In bank 1 because the clamp is reached during gameplay, when bank 2 is not
; mapped.
; ---------------------------------------------------------------------------

; A and the flags are not preserved: the clamp this replaces ended with $99 in A,
; so no caller can have relied on either.
LabScoreCarry::
	ld   a, h
	cp   HIGH(wScoreBCD + 2)
	jr   nz, .notTheLiveScore
	ld   a, l
	cp   LOW(wScoreBCD + 2)
	jr   nz, .notTheLiveScore

; Stop at 9, so the ceiling is 9 999 999. There is no room on screen for an
; eighth digit - column 11 is inside the playfield - so counting past 9 would
; only make the display lie, which is worse than a ceiling ten times the
; original's. Toni's build adds digits 7 and 8; when we take his format this
; comes back.
	ld   a, [wLabScoreMillions]
	cp   $09
	jr   z, .ceiling
	add  $01
	daa
	ld   [wLabScoreMillions], a

.notTheLiveScore:
	ret

; At the ceiling, pin every digit the way the original pinned its six. Simply
; refusing the carry is not enough: the add has already wrapped the low six, so
; the score would fall from 9 999 950 to 9 000 350.
.ceiling:
	ld   a, $99
	ld   [hl-], a
	ld   [hl-], a
	ld   [hl], a
	ret
