/* video.asm - 80x32 tilemap text mode and text printing
	Text mode tiles are 1 bit per pixel (8 bytes, same as the ROM font).
	Each cell is 2 bytes: character, attribute. The attribute is a palette
	offset, so colour c uses palette entries 2c (paper) and 2c+1 (ink).
 */

/* clear_screen - fill every cell with space / attribute 0 */
clear_screen:
	ld hl,TILEMAP_BASE
	ld (hl),' '
	inc hl
	ld (hl),0
	ld hl,TILEMAP_BASE
	ld de,TILEMAP_BASE+2
	ld bc,SCREEN_W*SCREEN_H*2-2
	ldir								; copies the 2-byte pattern along
	ret

/* clear_row - D = row */
clear_row:
	ld e,0
	call screen_addr
	ld b,SCREEN_W
.loop:
	ld (hl),' '
	inc hl
	ld (hl),0
	inc hl
	djnz .loop
	ret

/* screen_addr - D = row, E = column -> HL = tilemap cell. Clobbers A, DE */
screen_addr:
	ld a,e
	ld e,SCREEN_W
	mul d,e
	add de,a
	ex de,hl
	add hl,hl
	add hl,TILEMAP_BASE
	ret

/* print_at - HL = zero-terminated string, D = row, E = col, C = attribute
	Returns DE = next cell */
print_at:
	push hl
	call screen_addr
	ex de,hl
	pop hl
/* print_str - HL = string, DE = cell, C = attribute */
print_str:
	ld a,(hl)
	or a
	ret z
	ld (de),a
	inc de
	ld a,c
	ld (de),a
	inc de
	inc hl
	jr print_str

/* print_u8 - A = value, DE = cell, C = attribute. No leading zeros */
print_u8:
	ld l,a
	ld h,0
/* print_u16 - HL = value, DE = cell, C = attribute. No leading zeros.
	Returns DE = next cell. Clobbers A, B, HL, IX */
print_u16:
	ld a,c
	ld (print_attr),a
	xor a
	ld (print_started),a
	ld ix,pow10_table
.digit:
	ld c,(ix+0)
	ld b,(ix+1)
	ld a,b
	or c
	jr z,.last
	ld a,'0'
.sub:
	or a
	sbc hl,bc
	jr c,.got
	inc a
	jr .sub
.got:
	add hl,bc
	cp '0'
	jr nz,.emit
	ld b,a
	ld a,(print_started)
	or a
	ld a,b
	jr z,.skip
.emit:
	call .put
	ld a,1
	ld (print_started),a
.skip:
	inc ix
	inc ix
	jr .digit
.last:
	ld a,l
	add a,'0'
	call .put
	ld a,(print_attr)
	ld c,a
	ret
.put:
	ld (de),a
	inc de
	ld a,(print_attr)
	ld (de),a
	inc de
	ret

pow10_table:
	dw 10000,1000,100,10,0

/* msg_begin / msg_add / msg_end - build a message from pieces.
	msg_add: HL = zero-terminated string. msg_end shows it */
msg_begin:
	ld hl,msg_buf
	ld (msg_ptr),hl
	ret
msg_add:
	ld de,(msg_ptr)
.copy:
	ld a,(hl)
	or a
	jr z,.done
	ld (de),a
	inc hl
	inc de
	jr .copy
.done:
	ld (msg_ptr),de
	ret
msg_end:
	ld hl,(msg_ptr)
	ld (hl),0
	ld hl,msg_buf
	; fall through
/* msg_print - HL = string. Messages share the top line, as in Moria;
	when the next one won't fit, -more- waits for a key first */
msg_print:
show_message:
	push hl
	call strlen
	ld b,a
	ld a,(msg_col)
	or a
	jr z,.place
	add a,b
	inc a
	jr c,.more
	cp MSG_WIDTH+1
	jr c,.space
.more:
	ld a,(msg_col)
	ld e,a
	ld d,MSG_ROW
	ld hl,txt_more
	ld c,ATTR_GREY
	call print_at
	call wait_fresh_key
	call msg_clear
	jr .place
.space:
	ld hl,msg_col
	inc (hl)
.place:
	pop hl
	call strlen
	ld b,a
	ld a,(msg_col)
	ld e,a
	ld d,MSG_ROW
	ld c,ATTR_WHITE
	push bc
	call print_at
	pop bc
	ld a,(msg_col)
	add a,b
	ld (msg_col),a
	ret

/* msg_clear - empty the message line */
msg_clear:
	ld d,MSG_ROW
	call clear_row
	xor a
	ld (msg_col),a
	ret

/* strlen - HL = string -> A = length. Preserves HL, clobbers B */
strlen:
	push hl
	ld b,0
.loop:
	ld a,(hl)
	or a
	jr z,.done
	inc hl
	inc b
	jr .loop
.done:
	ld a,b
	pop hl
	ret

/* msg_add_u8 - add A as a decimal number to the message being built */
msg_add_u8:
	ld de,(msg_ptr)
	ld b,0								; set once a digit is written
	ld c,100
	call .digit
	ld c,10
	call .digit
	add a,'0'
	ld (de),a
	inc de
	ld (msg_ptr),de
	ret
.digit:
	ld h,'0'
.sub:
	cp c
	jr c,.got
	sub c
	inc h
	jr .sub
.got:
	ld l,a
	ld a,h
	cp '0'
	jr nz,.write
	bit 0,b
	jr z,.skip
.write:
	ld (de),a
	inc de
	ld b,1
.skip:
	ld a,l
	ret

/* print_u32 - HL -> 32-bit value, DE = cell, C = attribute. No leading
	zeros, up to 8 digits. Returns DE = next cell. Clobbers IX */
print_u32:
	ld a,c
	ld (print_attr),a
	push de
	ld de,p32_work
	ld bc,4
	ldir
	pop de
	xor a
	ld (print_started),a
	ld ix,pow10_32
.digit:
	ld a,(ix+0)
	or (ix+1)
	or (ix+2)
	or (ix+3)
	jr z,.last
	ld b,'0'
.sub:									; try work -= power
	ld hl,p32_work
	ld a,(hl)
	sub (ix+0)
	ld (p32_try),a
	inc hl
	ld a,(hl)
	sbc a,(ix+1)
	ld (p32_try+1),a
	inc hl
	ld a,(hl)
	sbc a,(ix+2)
	ld (p32_try+2),a
	inc hl
	ld a,(hl)
	sbc a,(ix+3)
	ld (p32_try+3),a
	jr c,.got
	ld hl,(p32_try)
	ld (p32_work),hl
	ld hl,(p32_try+2)
	ld (p32_work+2),hl
	inc b
	jr .sub
.got:
	ld a,b
	cp '0'
	jr nz,.emit
	ld a,(print_started)
	or a
	jr z,.skip
	ld a,b
.emit:
	call .put
	ld a,1
	ld (print_started),a
.skip:
	ld bc,4
	add ix,bc
	jr .digit
.last:
	ld a,(p32_work)
	add a,'0'
	call .put
	ld a,(print_attr)
	ld c,a
	ret
.put:
	ld (de),a
	inc de
	ld a,(print_attr)
	ld (de),a
	inc de
	ret

pow10_32:
	dd 10000000,1000000,100000,10000,1000,100,10,0
p32_work:		dd 0
p32_try:		dd 0

