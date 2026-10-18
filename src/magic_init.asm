/* magic_init.asm - this game's flavours  [overlay: PAGE_MISC]
	Reference: DESC.C magic_init. Run once for each new character.
 */

/* magic_init - this game's flavours: potion colours (all but the first
	three: slime mold, apple juice, water), staff woods, wand and rod
	metals, ring stones and amulet materials shuffled, and the scroll
	titles made up (magic_init in DESC.C) */
magic_init:
	ld hl,flavour_map
	xor a
.ident:
	ld (hl),a
	inc hl
	inc a
	cp MAX_FLAVOURS
	jr c,.ident
	ld a,3
.colours:
	ld (mi_i),a
	ld a,MAX_FLAVOURS-3					; j = randint(MAX_COLORS - 3) + 2
	call randint
	add a,2
	ld hl,flavour_map
	add hl,a
	ex de,hl							; DE = &map[j]
	ld a,(mi_i)
	ld hl,flavour_map
	add hl,a							; HL = &map[i]
	ld a,(de)
	ld c,(hl)
	ld (hl),a
	ld a,c
	ld (de),a
	ld a,(mi_i)
	inc a
	cp MAX_FLAVOURS
	jr c,.colours
	ld hl,wood_map						; woods, metals, stones and
	ld a,NUM_WOODS						; amulets: all shuffled
	call .shuffle
	ld hl,metal_map
	ld a,NUM_METALS
	call .shuffle
	ld hl,rock_map
	ld a,NUM_ROCKS
	call .shuffle
	ld hl,amulet_map
	ld a,NUM_AMULETS
	call .shuffle
	; scroll titles: 2 or 3 words of 1 or 2 syllables each, cut at 9
	nextreg NR_MMU1,FLAVOUR_PAGE
	ld hl,scroll_titles
	ld (mi_dst),hl
	ld a,MAX_TITLES
.title:
	ld (mi_i),a
	ld hl,mi_buf						; a fresh buffer
	ld b,MI_BUF_SIZE
.wipe:
	ld (hl),0
	inc hl
	djnz .wipe
	ld hl,mi_buf
	ld (mi_ptr),hl
	ld a,2
	call randint
	inc a
	ld (mi_words),a
.word:
	ld a,2
	call randint
.syllable:
	push af
	ld a,NUM_SYLLABLES
	call randint
	dec a
	add a,a
	ld hl,syllables
	add hl,a
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	ld de,(mi_ptr)
.copy:
	ld a,(hl)
	or a
	jr z,.copied
	ld (de),a
	inc hl
	inc de
	jr .copy
.copied:
	ld (mi_ptr),de
	pop af
	dec a
	jr nz,.syllable
	ld hl,mi_words
	dec (hl)
	jr z,.cut
	ld hl,(mi_ptr)						; a space between words
	ld (hl),' '
	inc hl
	ld (mi_ptr),hl
	jr .word
.cut:
	ld a,(mi_buf+8)						; end at 8 if that's a space, else 9
	cp ' '
	ld hl,mi_buf+8
	jr z,$+3
	inc hl
	ld (hl),0
	ld hl,mi_buf
	ld de,(mi_dst)
	ld bc,10
	ldir
	ld (mi_dst),de
	ld a,(mi_i)
	dec a
	jr nz,.title
	ret
.shuffle:								; HL = A entries: in order, then
	ld (mi_dst),hl						; each swapped with a random one
	ld (mi_n),a
	ld b,a
	xor a
.order:
	ld (hl),a
	inc hl
	inc a
	djnz .order
	xor a
.swap:
	ld (mi_i),a
	ld a,(mi_n)
	call randint
	dec a
	ld hl,(mi_dst)
	add hl,a
	ex de,hl							; DE = &map[j]
	ld a,(mi_i)
	ld hl,(mi_dst)
	add hl,a							; HL = &map[i]
	ld a,(de)
	ld c,(hl)
	ld (hl),a
	ld a,c
	ld (de),a
	ld a,(mi_i)
	inc a
	ld hl,mi_n
	cp (hl)
	jr c,.swap
	ret

mi_i:			db 0
mi_n:			db 0
mi_dst:			dw 0
mi_ptr:			dw 0
mi_words:		db 0
MI_BUF_SIZE		equ 32
mi_buf:			ds MI_BUF_SIZE
