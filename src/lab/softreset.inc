; Instant restart - bank 0 stub.
;
; Reached by a `jp`, replacing the original's `jp z, Reset` inside
; InGameCheckResetAndPause. The handler in bank 2 ends with `ret`, which
; unwinds through FarCall to whoever called `.start`. That deliberately skips
; the pause check that follows: Start is part of the combination, so returning
; normally would immediately pause the game we just restarted.

LabResetStub::
	ld   b, BANK(LabInGameReset)
	ld   hl, LabInGameReset
	jp   FarCall
