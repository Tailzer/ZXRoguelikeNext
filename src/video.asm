/* video.asm - 80x32 tilemap text mode and text printing
	Text mode tiles are 1 bit per pixel (8 bytes, same as the ROM font).
	Each cell is 2 bytes: character, attribute. The attribute is a palette
	offset, so colour c uses palette entries 2c (paper) and 2c+1 (ink).
 */

video_init:
	xor a
	out ($FE),a							; black border
	nextreg NR_ULA_CONTROL,%10000000	; ULA off, tilemap only

	; tilemap palette: paper black, ink from palette_inks
	nextreg NR_PAL_CONTROL,%00110000	; edit first tilemap palette
	nextreg NR_PAL_INDEX,0
	ld hl,palette_inks
	ld b,NUM_COLOURS
.pal:
	xor a
	nextreg NR_PAL_VALUE8,a
	ld a,(hl)
	inc hl
	nextreg NR_PAL_VALUE8,a
	djnz .pal

	; tile definitions: clear, then copy ROM font so tile number = ASCII
	ld hl,TILEDEF_BASE
	ld de,TILEDEF_BASE+1
	ld bc,256*8-1
	ld (hl),0
	ldir
	ld hl,$3D00							; ROM 3 font, chars 32-127
	ld de,TILEDEF_BASE+32*8
	ld bc,96*8
	ldir

	call clear_screen

	nextreg NR_TILEMAP_BASE,high (TILEMAP_BASE-$4000)
	nextreg NR_TILEDEF_BASE,high (TILEDEF_BASE-$4000)
	nextreg NR_TILEMAP_ATTR,0
	nextreg NR_TILEMAP_XOFF_MSB,0
	nextreg NR_TILEMAP_XOFF_LSB,0
	nextreg NR_TILEMAP_YOFF,0
	nextreg NR_TILEMAP_CONTROL,%11001000	; on, 80 col, attrs, text mode
	ret

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

/* print_u8 - A = value, DE = cell, C = attribute. No leading zeros.
	Clobbers A, B, HL */
print_u8:
	ld h,0								; set once a digit is printed
	ld b,100
	call .digit
	ld b,10
	call .digit
	add a,'0'
	ld (de),a
	inc de
	ld a,c
	ld (de),a
	inc de
	ret
.digit:									; A = value, B = divisor -> A = remainder
	ld l,'0'
.sub:
	cp b
	jr c,.got
	sub b
	inc l
	jr .sub
.got:
	push af
	ld a,l
	cp '0'
	jr nz,.print
	bit 0,h
	jr z,.skip
.print:
	ld h,1
	ld (de),a
	inc de
	ld a,c
	ld (de),a
	inc de
.skip:
	pop af
	ret

/* show_message - HL = string, printed on the message row */
show_message:
	push hl
	ld d,MSG_ROW
	call clear_row
	pop hl
	ld d,MSG_ROW
	ld e,0
	ld c,ATTR_WHITE
	jp print_at

; ink colours, RRRGGGBB, in COL_ order
palette_inks:
	db %11111111						; white
	db %10010010						; grey
	db %01001001						; dark grey
	db %11111100						; yellow
	db %11100000						; red
	db %00011100						; green
	db %01001111						; blue
	db %10101100						; umber
