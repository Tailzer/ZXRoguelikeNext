/* input.asm - keyboard reading with key repeat
	Movement keys follow Angband's roguelike keyset (ROGLCMDS.HLP):
		y k u
		h   l
		b j n
	plus the Spectrum cursor keys 5/6/7/8 (with or without Caps Shift).
 */

/* interrupt_init - IM2 with a 257-byte vector table, so whatever byte is on
	the data bus the CPU jumps to IM2_JUMP, which jumps to the real handler */
interrupt_init:
	ld hl,IM2_TABLE
	ld de,IM2_TABLE+1
	ld bc,256
	ld (hl),high IM2_JUMP
	ldir
	ld a,$C3							; jp im2_handler
	ld (IM2_JUMP),a
	ld hl,im2_handler
	ld (IM2_JUMP+1),hl
	ld a,high IM2_TABLE
	ld i,a
	im 2
	ei
	ret

/* im2_handler - runs once per frame (50Hz) */
im2_handler:
	push af
	ld a,(frame_counter)
	inc a
	ld (frame_counter),a
	pop af
	ei
	reti

/* wait_frame - sleep until the next frame interrupt */
wait_frame:
	halt
	ret

/* scan_keys - out: carry set if a key is down, A = key index,
	B = dx, C = dy. Clobbers E, HL */
scan_keys:
	ld hl,key_table
	ld e,0
.next:
	ld a,(hl)							; keyboard half-row, 0 = end
	or a
	ret z								; carry clear
	inc hl
	in a,($FE)
	and (hl)
	inc hl
	jr z,.found							; bits are active low
	inc hl
	inc hl
	inc e
	jr .next
.found:
	ld b,(hl)
	inc hl
	ld c,(hl)
	ld a,e
	scf
	ret

/* get_move_key - waits for a movement key, with repeat while held.
	out: B = dx, C = dy */
get_move_key:
	call wait_frame
	call scan_keys
	jr nc,.released
	ld e,a
	ld a,(held_key)
	cp e
	jr z,.held
	ld a,e								; new key: act straight away
	ld (held_key),a
	ld a,REPEAT_FIRST
	ld (repeat_timer),a
	ret
.held:
	ld hl,repeat_timer
	dec (hl)
	jr nz,get_move_key
	ld (hl),REPEAT_NEXT
	ret
.released:
	ld a,KEY_NONE
	ld (held_key),a
	jr get_move_key

; half-row port, bit mask, dx, dy
key_table:
	db $BF,%00010000,-1, 0				; h
	db $BF,%00001000, 0, 1				; j
	db $BF,%00000100, 0,-1				; k
	db $BF,%00000010, 1, 0				; l
	db $DF,%00010000,-1,-1				; y
	db $DF,%00001000, 1,-1				; u
	db $7F,%00010000,-1, 1				; b
	db $7F,%00001000, 1, 1				; n
	db $F7,%00010000,-1, 0				; 5 cursor left
	db $EF,%00010000, 0, 1				; 6 cursor down
	db $EF,%00001000, 0,-1				; 7 cursor up
	db $EF,%00000100, 1, 0				; 8 cursor right
	db 0
