/* death.asm - the end of a character  [overlay: PAGE_CREATE] */

/* player_died_screen - "You die.", then a simple tombstone */
player_died_screen:
	ld hl,txt_you_die
	call msg_print
	call wait_fresh_key
	call clear_screen
	ld hl,txt_rip
	ld d,8
	ld e,37
	ld c,ATTR_WHITE
	call print_at
	ld hl,p_name						; the name, then "the Rookie"
	call strlen
	srl a
	ld b,a
	ld a,40
	sub b
	ld e,a
	ld d,10
	ld hl,p_name
	ld c,ATTR_YELLOW
	call print_at
	call msg_begin						; "Level 3 Human Warrior"
	ld hl,txt_level_
	call msg_add
	ld a,(p_lev)
	call msg_add_u8
	ld hl,txt_space_d
	call msg_add
	call race_rec
	ld l,(ix+PR_NAME)
	ld h,(ix+PR_NAME+1)
	call msg_add
	ld hl,txt_space_d
	call msg_add
	call class_rec
	ld l,(ix+PC_NAME)
	ld h,(ix+PC_NAME+1)
	call msg_add
	ld hl,(msg_ptr)
	ld (hl),0
	ld hl,msg_buf
	ld d,11
	ld e,30
	ld c,ATTR_GREY
	call print_at
	call msg_begin						; "Killed by a Jackal"
	ld hl,txt_killed_by
	call msg_add
	ld hl,(killer_race)
	ld a,h
	cp high KILLER_STARVATION
	jr nz,.monster
	ld hl,txt_starvation
	call msg_add
	jr .killer_done
.monster:
	call race_addr
	bit RF_UNIQUE,(iy+R_FLAGS)			; "Killed by Grip, Farmer Maggot's dog"
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
	ld hl,(msg_ptr)
	ld (hl),0
	ld hl,msg_buf
	ld d,12
	ld e,30
	ld c,ATTR_GREY
	call print_at
	call msg_begin						; "on level 3"
	ld hl,txt_on_level
	call msg_add
	ld a,(dun_level)
	call msg_add_u8
	ld hl,(msg_ptr)
	ld (hl),0
	ld hl,msg_buf
	ld d,13
	ld e,30
	ld c,ATTR_GREY
	call print_at
	ld hl,txt_try_again
	ld d,16
	ld e,25
	ld c,ATTR_DARK
	call print_at
	call wait_fresh_key
	jp clear_screen

; death
txt_you_die:	db "You die.",0
txt_rip:		db "R I P",0
txt_killed_by:	db "Killed by ",0
txt_a:			db "a ",0
txt_an:			db "an ",0
txt_on_level:	db "on level ",0
txt_try_again:	db "Press any key to start again.",0
txt_starvation:	db "starvation",0
txt_level_:		db "Level ",0
txt_space_d:	db " ",0
