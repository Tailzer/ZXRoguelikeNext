/* startup.asm - one-off hardware set-up  [overlay: PAGE_MISC]
	80x32 tilemap text mode. Text mode tiles are 1 bit per pixel (8 bytes,
	same as the ROM font). Each cell is 2 bytes: character, attribute; the
	attribute is a palette offset, so colour c uses palette entries 2c
	(paper) and 2c+1 (ink).
 */

/* hold_loading - the loading screen (still on Layer 2 from the NEX
	loader) stays up for 5 seconds, or until a key is pressed */
hold_loading:
	ld b,250
.frame:
	halt
	xor a
	in a,($FE)
	cpl
	and %00011111
	ret nz
	djnz .frame
	ret

video_init:
	ld bc,$123B							; Layer 2 off (the loading screen
	xor a								; was showing on it)
	out (c),a
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
	db %11000011						; magenta ($E3 is the transparent colour)
	ds 7, 0								; (unused)
	; the 16 PC colours (Turbo C order) the converted data uses: COL_TC + n
	db %00000000, %00000010, %00010100, %00010110	; black, blue, green, cyan
	db %10100000, %10100010, %10101000, %10110110	; red, magenta, brown, light grey
	db %01001001, %01001011, %01011101, %01011111	; dark grey, light blue/green/cyan
	db %11101001, %11101011, %11111101, %11111111	; light red, light magenta, yellow, white
