/* random.asm - random numbers
	xorshift16 generator, plus Angband-style randint().
	Reference: RND.C, MISC1.C randint()
 */

/* rand16 - next random number in HL. Clobbers A */
rand16:
	ld hl,(rng_state)
	ld a,h
	rra
	ld a,l
	rra
	xor h
	ld h,a
	ld a,l
	rra
	ld a,h
	rra
	xor l
	ld l,a
	xor h
	ld h,a
	ld (rng_state),hl
	ret

/* randint - A = n (1-255) -> A = random number 1..n. Clobbers DE, HL */
randint:
	ld e,a
	call rand16
	ld d,h
	mul d,e								; D = H * n / 256 = 0..n-1
	ld a,d
	inc a
	ret

/* rng_mix - stir the frame counter and R register into the state */
rng_mix:
	ld hl,(frame_counter)
	ld a,r
	xor l
	ld l,a
	ld de,(rng_state)
	ld a,l
	xor e
	ld l,a
	ld a,h
	xor d
	ld h,a
	or l
	jr nz,.ok
	inc l								; state must never be zero
.ok:
	ld (rng_state),hl
	ret
