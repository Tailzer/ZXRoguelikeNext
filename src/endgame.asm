/* endgame.asm - Sauron, Morgoth, winning and retiring (overlay page
	PAGE_LOOK, after look.asm)
	References: MORIA2.C mon_take_hit (the quest, the win), DUNGEON.C
	is_quest and 'Q', DEATH.C kingly.
	While Sauron lives, his level (QUEST_LEVEL) has no way further down:
	its stairs all go up, a trap door is a spiked pit and teleport level
	only rises (see is_quest). Killing him there makes a stairway down;
	killing Morgoth wins the game. A winner can't save, only retire ('Q'),
	which crowns them before the tombstone.
 */

/* end_event_now - the main loop, after a turn in which unique_killed
	noted Sauron's or Morgoth's death (end_event 1 or 2) */
end_event_now:
	ld a,(end_event)
	push af
	xor a
	ld (end_event),a
	pop af
	cp 2
	jr z,.morgoth
	xor a								; the quest is done
	ld (p_quest),a
	ld a,(dun_level)
	cp QUEST_LEVEL
	ld hl,me_onward
	jp nz,msg_print						; (killed elsewhere: just words)
	ld a,(end_y)						; a stairway where he fell, or near
	ld d,a								; it if something lies there
	ld a,(end_x)
	ld e,a
	ld b,20
.spot:
	push bc
	push de
	call item_at
	pop de
	jr c,.taken
	push de
	call trap_at
	pop de
	jr nc,.here
.taken:
	pop bc
	push bc
	call .nearby
	pop bc
	djnz .spot
	push bc
.here:
	pop bc
	push de
	call map_addr
	ld a,(hl)
	and $FF-TERRAIN_MASK
	or T_STAIR_DOWN
	ld (hl),a
	pop de
	ld hl,me_go_for_it
	call msg_print
	ld hl,me_stairway
	jp msg_print
.nearby:								; D, E -> a random open square next
	ld a,3								; to (end_y, end_x)
	call randint
	ld hl,end_y
	add a,(hl)
	sub 2
	ld d,a
	ld a,3
	call randint
	ld hl,end_x
	add a,(hl)
	sub 2
	ld e,a
	push de
	call map_addr
	pop de
	ld a,(hl)
	and TERRAIN_MASK
	cp T_FLOOR
	ret z
	cp T_CORRIDOR
	ret z
	cp T_FLOOR_LIT
	ret z
	jr .nearby
.morgoth:
	ld a,1
	ld (p_winner),a
	ld hl,me_congratulations
	call msg_print
	ld hl,me_retire_when_ready
	jp msg_print

/* quit_command - 'Q' (Caps Shift + Q): "Do you really want to quit?",
	or a winner's "Do you want to retire?"; yes, and the character is done */
quit_command:
	ld a,(p_winner)
	or a
	ld hl,me_really_quit
	jr z,$+5
	ld hl,me_retire
	call prompt
	call read_ascii
	push af
	call msg_clear
	pop af
	cp 'y'
	jr z,.yes
	cp 'Y'
	ret nz
.yes:
	ld hl,KILLER_QUIT
	ld a,(p_winner)
	or a
	jr z,$+3
	inc hl								; (KILLER_OLD_AGE)
	ld (killer_race),hl
	ld a,1
	ld (p_dead),a
	ret

/* end_screens - before the tombstone: a winner who retires is crowned
	(kingly in DEATH.C): back to the town, the levels and experience of a
	lifetime, a fortune, and "Veni, Vidi, Vici!" */
end_screens:
	ld hl,(killer_race)
	ld de,KILLER_OLD_AGE
	or a
	sbc hl,de
	ret nz
	xor a
	ld (dun_level),a
	ld hl,(p_max_exp)					; restore_level: experience back
	ld (p_exp),hl						; to its most, the level with it
	ld hl,(p_max_exp+2)
	ld (p_exp+2),hl
	call check_level_up
	ld a,(p_lev)						; + 50 levels
	add a,MAX_PLAYER_LEVEL
	ld (p_lev),a
	ld hl,(p_gold)						; + 250000 gold
	ld de,250000 & $FFFF
	add hl,de
	ld (p_gold),hl
	ld hl,(p_gold+2)
	ld de,250000 >> 16
	adc hl,de
	ld (p_gold+2),hl
	ld hl,(p_max_exp)					; + 5000000 experience, all of it
	ld de,5000000 & $FFFF
	add hl,de
	ld (p_max_exp),hl
	ld (p_exp),hl
	ld hl,(p_max_exp+2)
	ld de,5000000 >> 16
	adc hl,de
	ld (p_max_exp+2),hl
	ld (p_exp+2),hl
	call clear_screen					; the crown
	ld hl,crown
.line:
	ld d,(hl)							; row, column, text (row $FF ends)
	inc hl
	ld a,d
	inc a
	jr z,.hail
	ld e,(hl)
	inc hl
	ld c,ATTR_YELLOW
	push hl
	call print_at
	pop hl
.skip:
	ld a,(hl)
	inc hl
	or a
	jr nz,.skip
	jr .line
.hail:
	ld a,(p_male)
	or a
	ld hl,me_king
	jr nz,$+5
	ld hl,me_queen
	ld d,17+KR
	ld e,22+KC
	ld c,ATTR_WHITE
	call print_at
	ld hl,me_any_key
	ld d,23+KR
	ld e,27+KC
	ld c,ATTR_GREY
	call print_at
	call wait_fresh_key
	jp clear_screen

KR		equ 3							; (the C's 24 x 80 screen, a little
KC		equ 0							;  lower on the Next's 32 rows)
crown:
	db 1+KR,34+KC,"#",0
	db 2+KR,32+KC,"#####",0
	db 3+KR,34+KC,"#",0
	db 4+KR,28+KC,",,,  $$$  ,,,",0
	db 5+KR,24+KC,",,=$   ",34,"$$$$$",34,"   $=,,",0
	db 6+KR,22+KC,",$$        $$$        $$,",0
	db 7+KR,22+KC,"*>         <*>         <*",0
	db 8+KR,22+KC,"$$         $$$         $$",0
	db 9+KR,22+KC,34,"$$        $$$        $$",34,0
	db 10+KR,23+KC,34,"$$       $$$       $$",34,0
	db 11+KR,24+KC,"*#########*#########*",0
	db 12+KR,24+KC,"*#########*#########*",0
	db 15+KR,26+KC,"Veni, Vidi, Vici!",0
	db 16+KR,21+KC,"I came, I saw, I conquered!",0
	db $FF

me_onward:		db "Well done!!  Now continue onward towards Morgoth.",0
me_go_for_it:	db "Well done!! Go for it!",0
me_stairway:	db "A magical stairway appears...",0
me_congratulations: db "*** CONGRATULATIONS *** You have won the game.",0
me_retire_when_ready: db "You cannot save this game, but you may retire when ready.",0
me_really_quit:	db "Do you really want to quit? [y/n]",0
me_retire:		db "Do you want to retire? [y/n]",0
me_king:		db "All Hail the Mighty King!",0
me_queen:		db "All Hail the Mighty Queen!",0
me_any_key:		db "[Press any key]",0
