/* death.asm - the end of a character  [overlay: PAGE_MISC] */

/* player_died_screen - "You die.", then a simple tombstone */
player_died_screen:
	ld hl,txt_you_die
	call msg_print
	call wait_fresh_key
	call clear_screen
	ld hl,txt_rip
	ld d,10
	ld e,37
	ld c,ATTR_WHITE
	call print_at
	call msg_begin						; "Killed by a Jackal"
	ld hl,txt_killed_by
	call msg_add
	ld a,(killer_race)
	cp KILLER_STARVATION
	jr nz,.monster
	ld hl,txt_starvation
	call msg_add
	jr .killer_done
.monster:
	call race_addr
	ld l,(iy+R_NAME)
	ld h,(iy+R_NAME+1)
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
	ld l,(iy+R_NAME)
	ld h,(iy+R_NAME+1)
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
