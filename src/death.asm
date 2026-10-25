/* death.asm - the end of a character  [overlay: PAGE_CREATE]
	References: DEATH.C print_tomb, center_string, date; MISC2.C
	title_string. The tombstone's picture and the words for what killed you
	are in the activation data page (src/killers.asm). */

TOMB_ROW		equ 3					; (the C's 24 rows, lower on 32)
TOMB_MID		equ 26					; the middle of center_string's 31 columns

/* player_died_screen - "You die.", then the tombstone: name, title, class,
	level, experience, gold, the depth, what killed you and the date */
player_died_screen:
	ld hl,(killer_race)					; (not quitting or retiring)
	ld de,KILLER_QUIT
	or a
	sbc hl,de
	jr nc,.no_die
	ld hl,txt_you_die
	call msg_print
	call wait_fresh_key
.no_die:
	call clear_screen
	nextreg NR_MMU1,ACT_PAGE			; the picture
	ld hl,tomb_art
.art:
	ld a,(hl)
	inc hl
	cp $FF
	jr z,.words
	add a,TOMB_ROW
	ld d,a
	ld e,(hl)
	inc hl
	ld c,ATTR_GREY
	push hl
	call print_at
	pop hl
.skip:
	ld a,(hl)
	inc hl
	or a
	jr nz,.skip
	jr .art
.words:
	ld hl,p_name						; the name
	ld a,6
	call tomb_field
	ld a,(p_winner)						; the title (a winner: Magnificent)
	or a
	ld hl,txt_magnificent
	call z,title_string
	ld a,8
	call tomb_field
	ld a,(p_winner)						; the class (a winner: *King*)
	or a
	jr z,.class
	ld a,(p_male)
	or a
	ld hl,txt_king
	jr nz,.said_class
	ld hl,txt_queen
	jr .said_class
.class:
	call class_rec
	ld l,(ix+PC_NAME)
	ld h,(ix+PC_NAME+1)
.said_class:
	ld a,10
	call tomb_field
	call msg_begin						; "Level : 3"
	ld hl,txt_level_
	call msg_add
	ld a,(p_lev)
	call msg_add_u8
	ld a,11
	call tomb_msg
	call msg_begin						; "123 Exp"
	ld hl,p_exp
	call msg_add_u24
	ld hl,txt_exp_
	call msg_add
	ld a,12
	call tomb_msg
	call msg_begin						; "555 Au"
	ld hl,p_gold
	call msg_add_u24
	ld hl,txt_au
	call msg_add
	ld a,13
	call tomb_msg
	call msg_begin						; "Died on Level : 3"
	ld hl,txt_died_on
	call msg_add
	ld a,(dun_level)
	call msg_add_u8
	ld a,14
	call tomb_msg
	call msg_begin						; "a Jackal."
	ld hl,(killer_race)
	ld a,h
	cp high KILLER_STARVATION
	jr nz,.monster
	nextreg NR_MMU1,ACT_PAGE			; starvation, poison, potions...
	ld a,l								; (src/killers.asm)
	add a,a
	ld hl,killer_texts
	add hl,a
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	call msg_add
	jr .killer_done
.monster:
	call race_addr
	bit RF_UNIQUE,(iy+R_FLAGS)			; "Grip, Farmer Maggot's dog"
	jr nz,.unique
	call race_name
	ld a,(hl)
	ld hl,txt_a
	cp 'A'
	jr z,.an
	cp 'E'
	jr z,.an
	cp 'I'
	jr z,.an
	cp 'O'
	jr z,.an
	cp 'U'
	jr nz,.article
.an:
	ld hl,txt_an
.article:
	call msg_add
.unique:
	call race_name
	call msg_add
.killer_done:
	ld hl,txt_stop
	call msg_add
	ld a,16
	call tomb_msg
	call tomb_date						; the date, if there's a clock
	jr nc,.undated
	ld a,17
	call tomb_field
.undated:
	ld hl,txt_try_again
	ld d,TOMB_ROW+21
	ld e,25
	ld c,ATTR_DARK
	call print_at
.not_king:
	call wait_fresh_key
	jp clear_screen

/* tomb_msg - A = the C's row: the message built, centred there */
tomb_msg:
	ld hl,(msg_ptr)
	ld (hl),0
	ld hl,msg_buf
/* tomb_field - HL = text, A = the C's row: centred in the stone, as
	center_string (15 - length / 2 spaces into 31) */
tomb_field:
	add a,TOMB_ROW
	ld d,a
	push hl
	call strlen
	pop hl
	srl a
	ld e,a
	ld a,TOMB_MID
	sub e
	ld e,a
	ld c,ATTR_WHITE
	jp print_at

/* msg_add_u24 - HL -> a number (its low 3 bytes): added in decimal */
msg_add_u24:
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld a,(hl)
	ex de,hl
	ld e,a
	ld bc,tomb_digits+8
	xor a
	ld (bc),a
.digit:
	push bc
	ld c,10
	call div24_8
	pop bc
	add a,'0'
	dec bc
	ld (bc),a
	ld a,h
	or l
	or e
	jr nz,.digit
	ld h,b
	ld l,c
	jp msg_add

/* tomb_date - the date from the Next's clock, as ctime has it ("Sun Feb
	08") -> HL = it, carry; no carry if there's no clock (esxDOS
	M_GETDATE: BC = the day, as MS-DOS keeps it) */
tomb_date:
	di
	nextreg NR_MMU1,$FF					; (esxDOS wants the ROM there)
	rst $08
	db $8E
	ei
	ret c
	nextreg NR_MMU1,ACT_PAGE
	ld a,c								; day (bits 0-4), month (5-8), year
	and $1F								; from 1980 (9-15)
	ld (td_day),a
	ld a,b
	srl a
	ld (td_year),a
	ld a,c
	rlca
	rlca
	rlca
	and 7
	ld e,a
	ld a,b
	and 1
	add a,a
	add a,a
	add a,a
	or e
	ld (td_month),a
	or a								; (nothing sensible: no clock)
	ret z
	cp 13
	ccf
	ret nc
	ld a,(td_day)
	or a
	ret z
	ld a,(td_year)						; y = 1980 + .., less 1 before March
	ld l,a
	ld h,0
	ld de,1980
	add hl,de
	ld a,(td_month)
	cp 3
	jr nc,$+3
	dec hl
	push hl								; dow = (y + y/4 - y/100 + y/400 +
	srl h								;  t[m-1] + d) mod 7 (Sakamoto)
	rr l
	srl h
	rr l
	push hl
	ld c,100
	call div16_8						; (y/4)/100 = y/400
	ex de,hl
	pop hl
	add hl,de
	ex de,hl							; DE = y/4 + y/400
	pop hl
	push hl
	add hl,de
	ex de,hl							; DE = y + y/4 + y/400
	pop hl
	push de
	ld c,100
	call div16_8						; y/100
	ex de,hl
	pop hl
	or a
	sbc hl,de
	ld a,(td_month)
	dec a
	ld de,tomb_sakamoto
	add de,a
	ld a,(de)
	add hl,a
	ld a,(td_day)
	add hl,a
	ld c,7
	call div16_8						; A = the day of the week
	ld hl,tomb_days
	ld e,a
	add a,a
	add a,e
	add hl,a
	ld de,td_text
	ld bc,3
	ldir
	ld a,' '
	ld (de),a
	inc de
	ld a,(td_month)
	dec a
	ld hl,tomb_months
	ld c,a
	add a,a
	add a,c
	add hl,a
	ld bc,3
	ldir
	ld a,' '
	ld (de),a
	inc de
	ld a,(td_day)						; "08"
	ld c,10
	ld l,a
	ld h,0
	push de
	call div16_8
	pop de
	push af
	ld a,l
	add a,'0'
	ld (de),a
	inc de
	pop af
	add a,'0'
	ld (de),a
	inc de
	xor a
	ld (de),a
	ld hl,td_text
	scf
	ret

; death
txt_you_die:	db "You die.",0
txt_a:			db "a ",0
txt_an:			db "an ",0
txt_stop:		db ".",0
txt_try_again:	db "Press any key to start again.",0
txt_level_:		db "Level : ",0
txt_exp_:		db " Exp",0
txt_au:			db " Au",0
txt_died_on:	db "Died on Level : ",0
txt_magnificent: db "Magnificent",0
txt_king:		db "*King*",0
txt_queen:		db "*Queen*",0
tomb_digits:	ds 9
td_day:			db 0
td_month:		db 0
td_year:		db 0
td_text:		ds 12
