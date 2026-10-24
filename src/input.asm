/* input.asm - keyboard reading with key repeat
	Movement keys follow Angband's roguelike keyset (ROGLCMDS.HLP):
		y k u
		h   l
		b j n
	plus the Spectrum cursor keys 5/6/7/8 (with or without Caps Shift).
	> (Symbol Shift + T) goes down stairs, < (Symbol Shift + R) goes up.
	s stays in place for a turn. Items: i inventory, e equipment, w wear/wield,
	t take off, q quaff, E (Caps Shift + E) eat, d drop, g pick up.
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
	push hl
	ld hl,(frame_counter)
	inc hl
	ld (frame_counter),hl
	pop hl
	ei
	reti

/* wait_frame - sleep until the next frame interrupt */
wait_frame:
	halt
	ret

/* wait_any_key - wait for a key press, then for it to be released */
wait_any_key:
	call wait_frame
	xor a
	in a,($FE)							; all half-rows at once
	cpl
	and %00011111
	jr z,wait_any_key
.release:
	call wait_frame
	xor a
	in a,($FE)
	cpl
	and %00011111
	jr nz,.release
	ret

/* wait_fresh_key - wait for every key to be let go, then a new press
	(so a held movement key can't skip a -more-) */
wait_fresh_key:
	call wait_frame
	xor a
	in a,($FE)
	cpl
	and %00011111
	jr nz,wait_fresh_key
	jp wait_any_key

/* read_ascii - wait for a fresh key press and its release -> A = its
	character: a-z (A-Z with Caps Shift), 0-9, space, 13 for Enter.
	Symbol Shift and Caps Shift alone don't count */
read_ascii:
	call wait_frame						; everything released first
	xor a
	in a,($FE)
	cpl
	and %00011111
	jr nz,read_ascii
.wait:
	call wait_frame
	ld hl,ascii_keys
	ld bc,$FEFE							; B = half-row port, rotating
.row:
	in a,(c)
	cpl
	and %00011111
	ld d,5
.bit:
	srl a
	jr nc,.next_bit
	ld e,a
	ld a,(hl)
	or a
	jr nz,.key							; (a shift key alone is 0: skip it)
	ld a,e
.next_bit:
	inc hl
	dec d
	jr nz,.bit
	rlc b
	jr c,.row
	jr .wait
.key:
	ld e,a
	ld a,$7F							; (Symbol Shift: for ident_char)
	in a,($FE)
	cpl
	ld (ascii_sym),a
	ld a,$FE							; Caps Shift held: upper case
	in a,($FE)
	and %00000001
	ld a,e
	jr nz,.got
	cp '0'								; Caps Shift + 0 is delete
	jr nz,.upper
	ld a,8
	jr .got
.upper:
	cp 'a'
	jr c,.got
	sub 'a'-'A'
.got:
	ld (ascii_key),a
.release:
	call wait_frame
	xor a
	in a,($FE)
	cpl
	and %00011111
	jr nz,.release
	ld a,(ascii_key)
	ret

; characters by half-row ($FE, $FD ... $7F), bit 0 first; 0 = shift key
ascii_keys:
	db 0,'z','x','c','v'
	db 'a','s','d','f','g'
	db 'q','w','e','r','t'
	db '1','2','3','4','5'
	db '0','9','8','7','6'
	db 'p','o','i','u','y'
	db 13,'l','k','j','h'
	db ' ',0,'m','n','b'
ascii_key:		db 0
ascii_sym:		db 0				; bit 1: Symbol Shift was held

