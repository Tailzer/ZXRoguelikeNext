/* rest_run.asm - resting and running (overlay page PAGE_RUN)
	References: MORIA1.C rest/rest_off/disturb, find_init/find_run/end_find/
	area_affect/see_wall/see_nothing (-CJS-), DUNGEON.C (resting until the
	count runs out or hit points and mana are full; any key stops either).
	The main loop asks next_command for each command: while resting or
	running it makes one up, otherwise it reads the keys.
	Disturbances: the C calls disturb() from all over; here anything that
	gets said, a hurt, or a monster coming into view stops you.
 */

RR_NONE		equ 0
RR_REST		equ 1
RR_RUN		equ 2
RUN_MAX		equ 100				; then "You stop running to catch your breath."

/* next_command - as get_command (D = command, B = dx, C = dy), but
	resting or running carries on by itself; 'R' starts resting and Shift
	with a movement letter starts running */
next_command:
	ld a,(rr_mode)
	or a
	jr z,.ask
	call disturbed
	jr c,.stop
	ld a,(rr_mode)
	cp RR_REST
	jp z,rest_turn
	jp run_step
.stop:
	call rr_off
.ask:
	call get_command
	ld a,d
	cp CMD_REST
	jp z,start_rest
	cp CMD_MOVE
	ret nz
	ld a,(held_key)						; h j k l y u b n (not the cursor
	cp 8								; keys, which are Caps Shift + 5-8
	ret nc								; on a Spectrum) with Caps Shift
	ld a,$FE
	in a,($FE)
	rra
	ret c
	jp start_run

/* rr_off - resting or running stops */
rr_off:
	xor a
	ld (rr_mode),a
	ret

/* rr_begin - A = RR_REST / RR_RUN: from now on, what would disturb it */
rr_begin:
	ld (rr_mode),a
	ld a,1								; (the key that started it is
	ld (rr_held),a						;  still down)
	ld hl,(p_chp)
	ld (rr_hp),hl
	call seen_count
	ld (rr_seen),a
	ld a,(dun_level)
	ld (rr_level),a
	ret

/* disturbed -> carry if resting or running should stop: a key pressed
	(and let go: it isn't taken as a command), something said, hit points
	lost, another monster in view, a new level */
disturbed:
	xor a
	in a,($FE)
	cpl
	and %00011111
	jr z,.no_key
	ld a,(rr_held)
	or a
	jr nz,.keys_ok
.release:
	call wait_frame
	xor a
	in a,($FE)
	cpl
	and %00011111
	jr nz,.release
	scf
	ret
.no_key:
	ld (rr_held),a
.keys_ok:
	ld a,(msg_col)						; something was said
	or a
	scf
	ret nz
	ld hl,(p_chp)						; hurt
	ld de,(rr_hp)
	ld (rr_hp),hl
	or a
	sbc hl,de
	ret c
	call seen_count						; something came into view
	ld hl,rr_seen
	cp (hl)
	ld (hl),a
	jr z,.level
	ccf									; (carry if more than before)
	ret c
.level:
	ld a,(rr_level)
	ld hl,dun_level
	cp (hl)
	scf
	ret nz
	or a
	ret

/* seen_count -> A = monsters the player can see */
seen_count:
	ld ix,MON_LIST
	ld de,MON_SIZE
	ld bc,MON_MAX*256
.each:
	ld a,(ix+M_RACE_HI)
	cp MON_EMPTY
	jr z,.next
	ld a,(ix+M_ML)
	or a
	jr z,.next
	inc c
.next:
	add ix,de
	djnz .each
	ld a,c
	ret

; ---------------------------------------------------------------- resting

/* start_rest - 'R': "Rest for how long?" - a number of turns, or Enter
	alone for as long as needed (the C's '*'); space gives up */
start_rest:
	ld hl,mr_how_long
	call prompt
	xor a
	ld (rs_len),a
.key:
	ld hl,rs_buf						; show what's typed
	ld a,(rs_len)
	add hl,a
	ld (hl),'_'
	inc hl
	ld (hl),' '
	inc hl
	ld (hl),0
	ld hl,rs_buf
	ld d,MSG_ROW
	ld e,MR_HOW_LONG_LEN
	ld c,ATTR_WHITE
	call print_at
	call read_ascii
	cp 13
	jr z,.enter
	cp 8
	jr z,.delete
	cp '0'
	jr c,.cancel
	cp '9'+1
	jr nc,.cancel
	ld e,a
	ld a,(rs_len)
	cp 5
	jr nc,.key
	ld hl,rs_buf
	add hl,a
	ld (hl),e
	inc a
	ld (rs_len),a
	jr .key
.delete:
	ld a,(rs_len)
	or a
	jr z,.key
	dec a
	ld (rs_len),a
	jr .key
.cancel:
	call msg_clear
	jp next_command.ask
.enter:
	ld hl,$FFFF							; nothing typed: as long as needed
	ld a,(rs_len)
	or a
	jr z,.count
	ld b,a								; the number (at most 30000)
	ld de,rs_buf
	ld hl,0
.digit:
	push de
	ld d,h
	ld e,l
	add hl,hl
	add hl,hl
	add hl,de
	add hl,hl
	pop de
	ld a,(de)
	inc de
	sub '0'
	add hl,a
	djnz .digit
	ld a,h
	or l
	jr z,.cancel						; 0: no rest at all
	ld de,30000
	push hl
	or a
	sbc hl,de
	pop hl
	jr c,.count
	ex de,hl
.count:
	ld (rr_count),hl
	call msg_clear
	ld a,RR_REST
	call rr_begin
	; fall through: its first turn now

/* rest_turn - one turn's rest: twice the healing (DUNGEON.C), a little
	less hunger (food_digested--), then nothing happens (CMD_REST_TURN);
	over when the count runs out, or (as long as needed) once hit points
	and mana are both full */
rest_turn:
	ld hl,(rr_count)
	ld a,h
	and l
	inc a
	jr z,.needed
	ld a,h
	or l
	jr z,.over
	dec hl
	ld (rr_count),hl
	jr .rest
.needed:
	ld hl,(p_chp)
	ld de,(p_mhp)
	or a
	sbc hl,de
	jr c,.rest
	ld hl,(p_cmana)
	ld de,(p_mana)
	or a
	sbc hl,de
	jr c,.rest
.over:
	call rr_off
	jp next_command.ask
.rest:
	ld hl,(p_poisoned)					; (not while poisoned or bleeding)
	ld de,(p_cut)
	ld a,h
	or l
	or d
	or e
	ld a,(mana_regen)
	call z,regenhp
	ld a,(mana_regen)
	OVCALL PAGE_SPELL, regenmana, PAGE_RUN
	ld hl,(p_food)
	inc hl
	ld (p_food),hl
	ld d,CMD_REST_TURN
	ld bc,0
	ret

; ---------------------------------------------------------------- running

/* start_run - B = dx, C = dy: run that way (find_init); confused, just a
	step */
start_run:
	ld hl,(p_confused)
	ld a,h
	or l
	ret nz
	push bc
	call delta_dir						; A = 1-9
	pop bc
	ld (find_direction),a
	ld (find_prevdir),a
	xor a
	ld (find_breakleft),a
	ld (find_breakright),a
	ld a,1
	ld (find_count),a
	ld hl,(player_x)
	ld (rr_lastx),hl
	ld hl,(p_blind)
	ld a,h
	or l
	jp nz,.go
	ld a,(find_direction)				; i = chome[dir]
	call chome_of
	ld (fi_i),a
	xor a
	ld (fi_deepleft),a
	ld (fi_deepright),a
	ld (fi_shortleft),a
	ld (fi_shortright),a
	ld a,(fi_i)							; the left: next to you, or a step on
	inc a
	call cycle_dir
	call see_wall_here
	jr nc,.not_short_left
	ld a,1
	ld (find_breakleft),a
	ld (fi_shortleft),a
	jr .right
.not_short_left:
	call see_wall_ahead
	jr nc,.right
	ld a,1
	ld (find_breakleft),a
	ld (fi_deepleft),a
.right:
	ld a,(fi_i)
	dec a
	call cycle_dir
	call see_wall_here
	jr nc,.not_short_right
	ld a,1
	ld (find_breakright),a
	ld (fi_shortright),a
	jr .sides
.not_short_right:
	call see_wall_ahead
	jr nc,.sides
	ld a,1
	ld (find_breakright),a
	ld (fi_deepright),a
.sides:
	ld a,(find_breakleft)
	ld hl,find_breakright
	and (hl)
	ld (find_openarea),a				; (1 means both: not open)
	xor 1
	ld (find_openarea),a
	jr nz,.go							; open on a side: an open area
	ld a,(find_direction)				; a corridor
	rra
	jr nc,.straight
	ld a,(fi_deepleft)					; diagonally into it: turn with it
	ld hl,fi_deepright
	cp (hl)
	jr z,.go
	ld a,(fi_i)
	ld b,-1
	ld hl,fi_deepleft
	jr .turn_if
.straight:								; a wall two ahead: into the side
	ld a,(fi_i)							; corridor
	call cycle_dir
	call see_wall_ahead
	jr nc,.go
	ld a,(fi_shortleft)
	ld hl,fi_shortright
	cp (hl)
	jr z,.go
	ld a,(fi_i)
	ld b,-2
	ld hl,fi_shortleft
.turn_if:								; HL = the left flag: set, prevdir is
	bit 0,(hl)							; cycle[i + B], else cycle[i - B]
	jr nz,.turn
	ld c,a
	ld a,b
	neg
	ld b,a
	ld a,c
.turn:
	add a,b
	call cycle_dir
	ld (find_prevdir),a
.go:
	ld a,RR_RUN
	call rr_begin
	ld a,(find_direction)
	jr run_move

/* run_step - the next step of a run (find_run, then area_affect's
	choice), or the end of it */
run_step:
	ld hl,(player_x)					; didn't move: it's over
	ld de,(rr_lastx)
	ld (rr_lastx),hl
	or a
	sbc hl,de
	jr z,end_find
	ld hl,find_count					; at most 100 steps
	inc (hl)
	ld a,(hl)
	cp RUN_MAX+1
	jr c,.on
	ld hl,mr_breath
	call msg_print
	jr end_find
.on:
	call area_affect
	jr c,end_find
	ld a,(find_direction)
/* run_move - A = direction: that step as a command */
run_move:
	call dir_delta
	ld d,CMD_MOVE
	ret

/* end_find - the run is over: back to the keys */
end_find:
	call rr_off
	jp next_command.ask

/* area_affect - after a step: anything new in view next to you stops the
	run; in a corridor follow it round, stopping where it branches or opens
	out (area_affect, with find_examine and find_cut on as the C's
	defaults) */
area_affect:
	ld hl,(p_blind)
	ld a,h
	or l
	ret nz
	xor a
	ld (aa_option),a
	ld (aa_option2),a
	ld a,(find_prevdir)
	call chome_of
	ld (aa_home),a
	ld a,(find_prevdir)					; max = (dir & 1) + 1
	and 1
	inc a
	ld (aa_max),a
	neg
	ld (aa_i),a
.each:
	ld a,(aa_home)						; newdir = cycle[chome[dir] + i]
	ld hl,aa_i
	add a,(hl)
	call cycle_dir
	ld (aa_newdir),a
	call square_that_way				; HL = square, D, E
	ld a,(p_light)						; seen (or within your light)?
	or a
	jr nz,.seen
	ld a,(hl)
	and F_SEEN
	jr z,.unseen
.seen:
	call stopper						; something there stops you
	jp c,.end
	xor a
	jr .inv
.unseen:
	ld a,1
.inv:
	ld (aa_inv),a
	or a
	jr nz,.open
	ld a,(hl)
	and TERRAIN_MASK
	call open_space
	jp nc,.closed
.open:
	ld a,(find_openarea)
	or a
	jr z,.choose
	ld a,(aa_i)							; open area: a break on a side
	or a								; that was walled stops you
	jp z,.next
	jp p,.open_left
	ld a,(find_breakright)
	or a
	jp nz,.end
	jp .next
.open_left:
	ld a,(find_breakleft)
	or a
	jp nz,.end
	jp .next
.choose:
	ld a,(aa_option)					; the first new direction
	or a
	jr nz,.second
	ld a,(aa_newdir)
	ld (aa_option),a
	jr .next
.second:
	ld a,(aa_option2)					; three: stop
	or a
	jp nz,.end
	ld a,(aa_home)						; not next to the first: stop
	ld hl,aa_i
	add a,(hl)
	dec a
	call cycle_dir
	ld hl,aa_option
	cp (hl)
	jp nz,.end
	ld a,(aa_newdir)					; two side by side: option2 the
	rra									; diagonal, check_dir the other
	jr nc,.even							; diagonal by the first
	ld a,(aa_home)
	ld hl,aa_i
	add a,(hl)
	sub 2
	call cycle_dir
	ld (aa_check),a
	ld a,(aa_newdir)
	ld (aa_option2),a
	jr .next
.even:
	ld a,(aa_home)
	ld hl,aa_i
	add a,(hl)
	inc a
	call cycle_dir
	ld (aa_check),a
	ld a,(aa_option)
	ld (aa_option2),a
	ld a,(aa_newdir)
	ld (aa_option),a
	jr .next
.closed:								; an obstacle: in the open, it stops
	ld a,(find_openarea)				; you if that side was open before
	or a
	jr z,.next
	ld a,(aa_i)
	or a
	jr z,.next
	jp p,.wall_left
	ld a,(find_breakleft)
	or a
	jr nz,.end
	ld a,1
	ld (find_breakright),a
	jr .next
.wall_left:
	ld a,(find_breakright)
	or a
	jr nz,.end
	ld a,1
	ld (find_breakleft),a
.next:
	ld a,(aa_max)
	ld hl,aa_i
	cp (hl)
	jr z,.looked
	inc (hl)
	jp .each
.looked:
	ld a,(find_openarea)
	or a
	ret nz								; (no carry: carry on)
	ld a,(aa_option2)					; one way on
	or a
	jr nz,.two
	ld a,(aa_option)
	or a
	ret z								; (none: on into the wall)
	ld (find_direction),a
	ld (find_prevdir),a
	or a
	ret
.two:									; two ways: a corner, or a branch
	ld a,(aa_option)
	call square_that_way				; (row, col) one step that way
	ld (aa_y),de
	ld a,(aa_option)
	call see_wall_from
	jr nc,.unclosed
	ld a,(aa_check)
	call see_wall_from
	jr nc,.unclosed
	ld a,(aa_option2)					; closed off: cut the corner
	ld (find_direction),a
	ld (find_prevdir),a
	or a
	ret
.unclosed:
	ld a,(aa_option)					; can't see beyond: a corner, take
	call see_nothing_from				; it the long way
	jr nc,.end
	ld a,(aa_option2)
	call see_nothing_from
	jr nc,.end
	ld a,(aa_option)
	ld (find_direction),a
	ld a,(aa_option2)
	ld (find_prevdir),a
	or a
	ret
.end:
	scf
	ret

/* stopper - HL = a square you can see, D, E -> carry if what's there
	stops a run: a monster in view, an item, a door (open or closed),
	stairs, rubble, a store, a trap you know of */
stopper:
	bit F_MON_BIT,(hl)
	jr z,.no_mon
	push hl
	push de
	call mon_at
	pop de
	pop hl
	jr nc,.no_mon
	ld a,(ix+M_ML)
	or a
	scf
	ret nz
.no_mon:
	ld a,(hl)
	and TERRAIN_MASK
	cp T_DOOR_CLOSED
	jr z,.yes
	cp T_DOOR_OPEN
	jr z,.yes
	cp T_STAIR_DOWN
	jr z,.yes
	cp T_STAIR_UP
	jr z,.yes
	cp T_RUBBLE
	jr z,.yes
	cp T_STORE
	jr z,.yes
	push hl
	call item_at
	pop hl
	ret c
	push hl
	call trap_at
	pop hl
	ret nc
	bit TRF_SEEN,(ix+TR_FLAGS)
	ret z
.yes:
	scf
	ret

/* open_space - A = terrain -> carry if it's open floor (the C's fval <=
	MAX_OPEN_SPACE: floors, corridors, and what stands on them) */
open_space:
	cp T_FLOOR
	jr z,.yes
	cp T_CORRIDOR
	jr z,.yes
	cp T_FLOOR_LIT
	jr z,.yes
	cp T_DOOR_OPEN
	jr z,.yes
	cp T_STAIR_DOWN
	jr z,.yes
	cp T_STAIR_UP
	jr z,.yes
	cp T_STORE
	jr z,.yes
	or a
	ret
.yes:
	scf
	ret

/* see_wall_here - A = direction: carry if, from where you stand, you know
	there's a wall that way. see_wall_ahead: from one step on in
	find_direction. see_wall_from: from (aa_y) (see_wall) */
see_wall_here:
	ld hl,(player_x)					; (x, y)
	ld d,h
	ld e,l
	jr see_wall
see_wall_ahead:
	push af
	ld a,(find_direction)
	call square_that_way
	pop af
	jr see_wall
see_wall_from:
	ld de,(aa_y)
/* see_wall - A = direction, D = y, E = x -> carry if that way is a wall
	the player knows of (drawn '#' or '%') */
see_wall:
	call step_dir						; HL = the square
	ld a,(hl)
	and F_SEEN
	ret z								; (unknown: no carry)
	ld a,(hl)
	and TERRAIN_MASK
	cp T_GRANITE
	jr z,.wall
	cp T_PERMWALL
	jr z,.wall
	cp T_MAGMA
	jr z,.wall
	cp T_QUARTZ
	jr z,.wall
	cp T_DOOR_SECRET
	jr z,.wall
	or a
	ret
.wall:
	scf
	ret
/* see_nothing_from - A = direction -> carry if that way from (aa_y) is a
	square the player knows nothing of (drawn ' ') */
see_nothing_from:
	ld de,(aa_y)
	call step_dir
	ld a,(hl)
	and F_SEEN
	ret nz								; (no carry)
	scf
	ret

/* square_that_way - A = direction -> D, E = the square next to the player
	that way, HL = it */
square_that_way:
	ld hl,(player_x)
	ld d,h
	ld e,l
/* step_dir - A = direction, D = y, E = x -> D, E one step that way, HL =
	the square */
step_dir:
	push de
	call dir_delta						; B = dx, C = dy
	pop de
	ld a,d
	add a,c
	ld d,a
	ld a,e
	add a,b
	ld e,a
	push de
	call map_addr
	pop de
	ret

/* dir_delta - A = direction 1-9 -> B = dx, C = dy (keypad_deltas) */
dir_delta:
	dec a
	add a,a
	ld hl,keypad_deltas
	add hl,a
	ld c,(hl)
	inc hl
	ld b,(hl)
	ret
/* delta_dir - B = dx, C = dy -> A = direction 1-9 */
delta_dir:
	ld hl,keypad_deltas
	ld a,1
.find:
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	push af
	ld a,e
	cp c
	jr nz,.no
	ld a,d
	cp b
	jr z,.found
.no:
	pop af
	inc a
	cp 10
	jr c,.find
	ld a,5
	ret
.found:
	pop af
	ret

/* chome_of - A = direction -> A = chome[dir]. cycle_dir - A = index ->
	A = cycle[A] */
chome_of:
	ld hl,chome
	add hl,a
	ld a,(hl)
	ret
cycle_dir:
	ld hl,cycle
	add hl,a
	ld a,(hl)
	ret
cycle:	db 1, 2, 3, 6, 9, 8, 7, 4, 1, 2, 3, 6, 9, 8, 7, 4, 1
chome:	db -1, 8, 9, 10, 7, -1, 11, 6, 5, 4

mr_how_long:	db "Rest for how long? (Enter: as long as needed) : ",0
MR_HOW_LONG_LEN	equ 48
mr_breath:		db "You stop running to catch your breath.",0

rr_mode:		db RR_NONE
rr_held:		db 0
rr_hp:			dw 0
rr_seen:		db 0
rr_level:		db 0
rr_count:		dw 0
rr_lastx:		dw 0				; x, y
rs_len:			db 0
rs_buf:			ds 8
find_direction:	db 0
find_prevdir:	db 0
find_openarea:	db 0
find_breakleft:	db 0
find_breakright: db 0
find_count:		db 0
fi_i:			db 0
fi_deepleft:	db 0
fi_deepright:	db 0
fi_shortleft:	db 0
fi_shortright:	db 0
aa_home:		db 0
aa_i:			db 0
aa_max:			db 0
aa_newdir:		db 0
aa_inv:			db 0
aa_option:		db 0
aa_option2:		db 0
aa_check:		db 0
aa_y:			dw 0				; (DE: x, then y)
