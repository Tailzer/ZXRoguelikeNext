/* keys.asm - reading commands from the keyboard (overlay page PAGE_RUN,
	with next_command, which is the only caller): the key table, scan_keys
	and get_command, moved out of input.asm to make resident room
 */

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
	db $F7,%00010000,KM_SYMBOL,CMD_KNOWLEDGE,0,0	; % (Symbol Shift + 5): self knowledge
	db $F7,%00010000,0,CMD_MOVE,-1, 0	; 5 cursor left
	db $EF,%00010000,0,CMD_MOVE, 0, 1	; 6 cursor down
	db $EF,%00001000,0,CMD_MOVE, 0,-1	; 7 cursor up
	db $EF,%00000100,0,CMD_MOVE, 1, 0	; 8 cursor right
	db $FB,%00010000,1,CMD_DOWN, 0, 0	; > (Symbol Shift + T)
	db $FB,%00001000,1,CMD_UP,   0, 0	; < (Symbol Shift + R)
	db $FD,%00000010,KM_NONE,CMD_STAY, 0, 0	; s: search (and stay) for a turn
	db $FD,%00000010,KM_CAPS,CMD_SPIKE,0,0	; S: spike a door
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
	db $FD,%00000100,KM_CAPS,CMD_DISARM,0,0	; D: disarm a trap
	db $FB,%00010000,KM_CAPS,CMD_TUNNEL,0,0	; T: tunnel
	db $FE,%00010000,KM_NONE,CMD_THROW,0,0	; v: throw
	db $FD,%00001000,KM_NONE,CMD_BASH,0,0	; f: force (bash) a door or monster
	db $DF,%00000010,KM_NONE,CMD_OPEN,0,0	; o: open (pick a lock)
	db $FE,%00001000,KM_NONE,CMD_CLOSE,0,0	; c: close a door
	db $FB,%00001000,KM_CAPS,CMD_REST,0,0	; R: rest
	db $FE,%00000100,KM_NONE,CMD_LOOK,0,0	; x: look
	db $7F,%00000100,KM_CAPS,CMD_MAP,0,0	; M: the map
	db $FB,%00000010,KM_CAPS,CMD_LOCATE,0,0	; W: where (locate)
	db $DF,%00000001,KM_SYMBOL,CMD_MESSAGES,0,0	; Symbol Shift + P: old messages (^P)
	db $FE,%00010000,KM_SYMBOL,CMD_SYMBOL,0,0	; / (Symbol Shift + V): identify a symbol
	db 0
