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

/* scan_keys - out: carry set if a key is down, A = key index,
	D = command, B = dx, C = dy. Clobbers E, HL */
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
	jr nz,.skip							; bits are active low
	ld a,(hl)							; modifier rule
	or a
	jr z,.found							; KM_ANY
	cp KM_SYMBOL
	jr z,.need_symbol
	cp KM_CAPS
	jr z,.need_caps
	call .symbol_down					; KM_NONE: neither shift held
	jr z,.skip
	call .caps_down
	jr z,.skip
	jr .found
.need_symbol:
	call .symbol_down
	jr z,.found
	jr .skip
.need_caps:
	call .caps_down
	jr z,.found
.skip:
	ld a,4
	add hl,a
	inc e
	jr .next
.found:
	inc hl
	ld d,(hl)
	inc hl
	ld b,(hl)
	inc hl
	ld c,(hl)
	ld a,e
	scf
	ret
.symbol_down:							; Z if Symbol Shift is held
	ld a,$7F
	in a,($FE)
	and %00000010
	ret
.caps_down:								; Z if Caps Shift is held
	ld a,$FE
	in a,($FE)
	and %00000001
	ret

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

/* get_command - waits for a command key, with repeat while held.
	out: D = command, B = dx, C = dy */
get_command:
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
	jr nz,get_command
	ld (hl),REPEAT_NEXT
	ret
.released:
	ld a,KEY_NONE
	ld (held_key),a
	jr get_command

; half-row port, bit mask, shift rule (KM_), command, dx, dy
key_table:
	db $BF,%00010000,0,CMD_MOVE,-1, 0	; h
	db $BF,%00001000,0,CMD_MOVE, 0, 1	; j
	db $BF,%00000100,0,CMD_MOVE, 0,-1	; k
	db $BF,%00000010,0,CMD_MOVE, 1, 0	; l
	db $DF,%00010000,0,CMD_MOVE,-1,-1	; y
	db $DF,%00001000,0,CMD_MOVE, 1,-1	; u
	db $7F,%00010000,0,CMD_MOVE,-1, 1	; b
	db $7F,%00001000,0,CMD_MOVE, 1, 1	; n
	db $F7,%00010000,0,CMD_MOVE,-1, 0	; 5 cursor left
	db $EF,%00010000,0,CMD_MOVE, 0, 1	; 6 cursor down
	db $EF,%00001000,0,CMD_MOVE, 0,-1	; 7 cursor up
	db $EF,%00000100,0,CMD_MOVE, 1, 0	; 8 cursor right
	db $FB,%00010000,1,CMD_DOWN, 0, 0	; > (Symbol Shift + T)
	db $FB,%00001000,1,CMD_UP,   0, 0	; < (Symbol Shift + R)
	db $FD,%00000010,0,CMD_STAY, 0, 0	; s: search (and stay) for a turn
	db $DF,%00000100,KM_NONE,CMD_INVEN,0,0	; i: inventory
	db $FB,%00000100,KM_CAPS,CMD_EAT,0,0	; E: eat
	db $FB,%00000100,KM_NONE,CMD_EQUIP,0,0	; e: equipment
	db $FB,%00000010,KM_NONE,CMD_WIELD,0,0	; w: wear/wield
	db $FB,%00010000,KM_NONE,CMD_TAKEOFF,0,0	; t: take off
	db $FB,%00000001,KM_NONE,CMD_QUAFF,0,0	; q: quaff
	db $FB,%00001000,KM_NONE,CMD_READ,0,0	; r: read
	db $FE,%00000010,KM_NONE,CMD_AIM,0,0	; z: aim a wand
	db $FE,%00000010,KM_CAPS,CMD_USE,0,0	; Z: use a staff
	db $FD,%00000001,KM_CAPS,CMD_ACTIVATE,0,0	; A: activate an artifact
	db $7F,%00000100,KM_NONE,CMD_CAST,0,0	; m: cast a spell
	db $DF,%00000001,KM_CAPS,CMD_BROWSE,0,0	; P: browse a book
	db $DF,%00000001,KM_NONE,CMD_PRAY,0,0	; p: recite a prayer
	db $FD,%00010000,KM_CAPS,CMD_STUDY,0,0	; G: learn spells
	db $FD,%00000001,KM_NONE,CMD_ZAP,0,0	; a: activate a rod
	db $FD,%00000100,KM_NONE,CMD_DROP,0,0	; d: drop
	db $FD,%00010000,KM_NONE,CMD_PICKUP,0,0	; g: pick up
	db $FE,%00001000,KM_CAPS,CMD_CHARACTER,0,0	; C: character sheet
	db $FE,%00000100,KM_SYMBOL,CMD_SAVE,0,0	; Symbol Shift + X: save (^X)
	db $FD,%00001000,KM_CAPS,CMD_FUEL,0,0	; F: refill a lamp
	db 0
