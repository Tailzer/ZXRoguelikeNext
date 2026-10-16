/* monsters.asm - live monsters: placement, visibility and turns
	References: MISC1.C alloc_monster/place_monster/place_group/distance,
	CREATURE.C creatures/update_mon/movement_rate/mon_move/get_moves/
	make_move. Monsters live in MON_LIST; the square they stand on has
	F_MON set so occupancy checks don't need to search the list.
	Convention: IX = monster record, IY = its race record.
 */

/* race_addr - A = race -> IY = race record. Clobbers DE */
race_addr:
	ld e,a
	ld d,RACE_SIZE
	mul d,e
	ld iy,race_table
	add iy,de
	ret

/* mon_clear_all - empty the monster list */
mon_clear_all:
	ld hl,MON_LIST
	ld de,MON_SIZE
	ld b,MON_MAX
.loop:
	ld (hl),MON_EMPTY
	add hl,de
	djnz .loop
	ret

/* mon_at - D = y, E = x -> IX = monster there, carry set if found */
mon_at:
	ld ix,MON_LIST
	ld b,MON_MAX
.loop:
	ld a,(ix+M_RACE)
	cp MON_EMPTY
	jr z,.next
	ld a,(ix+M_Y)
	cp d
	jr nz,.next
	ld a,(ix+M_X)
	cp e
	jr nz,.next
	scf
	ret
.next:
	push de
	ld de,MON_SIZE
	add ix,de
	pop de
	djnz .loop
	or a
	ret

/* mon_distance - D = y, E = x -> A = distance() to the player, max 255.
	Clobbers BC, DE, HL */
mon_distance:
	ld a,(player_y)
	sub d
	jr nc,$+4
	neg
	ld b,a								; dy
	ld a,(player_x)
	sub e
	jr nc,$+4
	neg
	ld c,a								; dx
	ld h,0
	ld l,b
	add hl,a							; dy + dx
	add hl,hl
	ld a,b								; - min(dy, dx)
	cp c
	jr c,$+3
	ld a,c
	ld e,a
	ld d,0
	or a
	sbc hl,de
	srl h
	rr l								; ((dy+dx)*2 - min) / 2
	ld a,h
	or a
	ld a,l
	ret z
	ld a,255
	ret

/* damroll - B = dice, C = sides -> HL = total. Clobbers A, DE */
damroll:
	ld hl,0
	ld a,b
	or a
	ret z
.loop:
	push hl
	push bc
	ld a,c
	call randint
	pop bc
	pop hl
	add hl,a
	djnz .loop
	ret

/* div8 - A / C -> A = quotient. Clobbers B */
div8:
	ld b,0
.loop:
	sub c
	jr c,.done
	inc b
	jr .loop
.done:
	ld a,b
	ret

/* place_monster - D = y, E = x, A = race, place_sleep = asleep or not */
place_monster:
	ld (place_race),a
	push de
	ld ix,MON_LIST						; find a free slot
	ld b,MON_MAX
	ld de,MON_SIZE
.find:
	ld a,(ix+M_RACE)
	cp MON_EMPTY
	jr z,.found
	add ix,de
	djnz .find
	pop de
	ret									; list full
.found:
	pop de
	ld a,(place_race)
	ld (ix+M_RACE),a
	ld (ix+M_Y),d
	ld (ix+M_X),e
	push de
	call map_addr
	set F_MON_BIT,(hl)
	ld a,(place_race)
	call race_addr
	ld b,(iy+R_HD_DICE)					; hp = hit dice roll
	ld c,(iy+R_HD_SIDES)
	call damroll
	ld (ix+M_HP),l
	ld (ix+M_HP+1),h
	ld (ix+M_MAXHP),l
	ld (ix+M_MAXHP+1),h
	ld a,(iy+R_SPEED)
	sub 10
	ld (ix+M_SPEED),a
	ld (ix+M_ML),0
	ld hl,0
	ld a,(place_sleep)
	or a
	jr z,.set_sleep
	ld a,(iy+R_SLEEP)
	or a
	jr z,.set_sleep
	; csleep = sleep*2 + 1d(sleep*10), the 1d(sleep*10) built as
	; (1d(sleep) - 1) * 10 + 1d10, which has the same spread
	call randint
	dec a
	ld d,a
	ld e,10
	mul d,e
	push de
	ld a,10
	call randint
	pop hl
	add hl,a
	ld a,(iy+R_SLEEP)
	add hl,a
	add hl,a
.set_sleep:
	ld (ix+M_SLEEP),l
	ld (ix+M_SLEEP+1),h
	pop de
	call mon_distance
	ld (ix+M_CDIS),a
	ret

/* test_place - D = y, E = x -> carry if a monster could stand there.
	Preserves DE */
test_place:
	call in_bounds
	ret nc
	ld a,(player_y)
	cp d
	jr nz,.not_player
	ld a,(player_x)
	cp e
	jr z,.no
.not_player:
	push de
	call map_addr
	pop de
	bit F_MON_BIT,(hl)
	jr nz,.no
	ld a,(hl)
	and TERRAIN_MASK
	call terrain_flags
	bit TF_PASSABLE,a
	jr z,.no
	scf
	ret
.no:
	or a
	ret

/* alloc_monsters - populate a new level: 1d8 + 14 + clamp(level/3, 2, 10)
	monsters, asleep, anywhere but on the player. Packs come in groups */
alloc_monsters:
	call mon_clear_all
	ld a,(dun_level)
	ld c,3
	call div8
	cp 2
	jr nc,$+4
	ld a,2
	cp 11
	jr c,$+4
	ld a,10
	ld (alloc_left),a
	ld a,8
	call randint
	add a,MIN_MALLOC_LEVEL
	ld hl,alloc_left
	add a,(hl)
	ld (hl),a
.each:
	call random_open_spot				; D, E, HL
	bit F_MON_BIT,(hl)
	jr nz,.each
	ld a,(player_y)
	cp d
	jr nz,.spot_ok
	ld a,(player_x)
	cp e
	jr z,.each
.spot_ok:
	push de
.pick:									; get_mons_num + rarity check
	ld a,NUM_RACES						; all races are level 1 for now
	call randint
	dec a
	ld (place_race),a
	call race_addr
	ld a,(iy+R_RARITY)
	call randint
	cp 2
	jr nc,.pick
	pop de
	bit RM_GROUP,(iy+R_MOVE)
	jr nz,.group
	ld a,1
	ld (place_sleep),a
	ld a,(place_race)
	call place_monster
	jr .next
.group:
	call place_group
.next:
	ld hl,alloc_left
	dec (hl)
	jr nz,.each
	ret

/* place_group - D = y, E = x, place_race. 1d13 awake members spread
	round the spot, as place_group()'s fall-through switch does */
place_group:
	xor a
	ld (place_sleep),a
	ld a,(place_race)
	ld (group_race),a
	ld a,13
	push de
	call randint
	pop de
	ld b,a								; members
	ld a,13
	sub b
	add a,a
	ld hl,group_offsets
	add hl,a
.member:
	push bc
	push hl
	push de
	ld a,(hl)							; dy
	add a,d
	ld d,a
	inc hl
	ld a,(hl)							; dx
	add a,e
	ld e,a
	call test_place
	jr nc,.skip
	ld a,(group_race)
	call place_monster
.skip:
	pop de
	pop hl
	pop bc
	inc hl
	inc hl
	djnz .member
	ret

group_offsets:							; dy, dx for cases 13 down to 1
	db 0,-2, 0,2, 2,0, -2,0, 1,1, 1,-1, -1,-1, -1,1, 0,1, 0,-1, 1,0, -1,0, 0,0

/* monsters_see_all - refresh distance and visibility of every monster */
monsters_see_all:
	ld ix,MON_LIST
	ld b,MON_MAX
.loop:
	push bc
	ld a,(ix+M_RACE)
	cp MON_EMPTY
	jr z,.next
	ld d,(ix+M_Y)
	ld e,(ix+M_X)
	call mon_distance
	ld (ix+M_CDIS),a
	call update_mon
.next:
	ld de,MON_SIZE
	add ix,de
	pop bc
	djnz .loop
	ret

/* update_mon - IX = monster. Visible if within MAX_SIGHT, on screen, on a
	lit or remembered-lit square, and in line of sight */
update_mon:
	ld a,(ix+M_CDIS)
	cp MAX_SIGHT+1
	jr nc,.hidden
	ld a,(view_y)
	ld b,a
	ld a,(ix+M_Y)
	sub b
	jr c,.hidden
	cp VIEW_H
	jr nc,.hidden
	ld a,(view_x)
	ld b,a
	ld a,(ix+M_X)
	sub b
	jr c,.hidden
	cp VIEW_W
	jr nc,.hidden
	ld d,(ix+M_Y)
	ld e,(ix+M_X)
	push de
	call map_addr
	pop de
	ld a,(hl)
	and F_SEEN
	jr z,.hidden
	call los
	jr nc,.hidden
	ld (ix+M_ML),1
	ret
.hidden:
	ld (ix+M_ML),0
	ret

/* monsters_act - every monster takes its turn (creatures(TRUE)) */
monsters_act:
	ld ix,MON_LIST
	ld b,MON_MAX
.loop:
	push bc
	ld a,(ix+M_RACE)
	cp MON_EMPTY
	call nz,mon_turn
	ld de,MON_SIZE
	add ix,de
	pop bc
	djnz .loop
	ret

/* mon_turn - IX = monster. Speed gives moves per player turn; sleeping
	monsters may notice the player when close (or visible) */
mon_turn:
	ld d,(ix+M_Y)
	ld e,(ix+M_X)
	call mon_distance
	ld (ix+M_CDIS),a
	ld a,(ix+M_RACE)
	call race_addr
	ld a,(ix+M_SPEED)					; movement_rate()
	or a
	jr z,.slow
	jp p,.have_moves
.slow:									; speed <= 0: move when turn % (2-speed) = 0
	neg
	add a,2
	ld c,a
	ld hl,(game_turn)
	call mod16_8
	or a
	ld a,1
	jr z,.have_moves
	jp update_mon
.have_moves:
	ld (mon_moves),a
.move:
	ld a,(ix+M_ML)
	or a
	jr nz,.awake_check
	ld a,(ix+M_CDIS)
	cp (iy+R_AAF)
	jr z,.awake_check
	jr nc,.done_move					; too far away to care
.awake_check:
	ld a,(ix+M_SLEEP)
	or (ix+M_SLEEP+1)
	jr z,.act
	call rand16							; does it notice the player?
	ld a,h
	and 3
	ld h,a								; 0..1023
	ld de,NOTICE_LIMIT
	or a
	sbc hl,de
	jr nc,.done_move
	ld a,(ix+M_CDIS)					; csleep -= 100 / cdis
	or a
	jr nz,$+3
	inc a
	ld c,a
	ld a,100
	call div8
	ld e,a
	ld d,0
	ld l,(ix+M_SLEEP)
	ld h,(ix+M_SLEEP+1)
	or a
	sbc hl,de
	jr c,.wake
	jr z,.wake
	ld (ix+M_SLEEP),l
	ld (ix+M_SLEEP+1),h
	jr .done_move
.wake:
	ld (ix+M_SLEEP),0
	ld (ix+M_SLEEP+1),0
.act:
	call mon_move
.done_move:
	call update_mon
	ld hl,mon_moves
	dec (hl)
	jr nz,.move
	ret

/* mod16_8 - HL mod C -> A. Clobbers B, HL */
mod16_8:
	xor a
	ld b,16
.loop:
	add hl,hl
	rla
	jr c,.sub
	cp c
	jr c,.next
.sub:
	sub c
.next:
	djnz .loop
	ret

/* mon_move - IX = monster, IY = race. Random wandering for erratic
	movers, otherwise head for the player; stationary ones only attack */
mon_move:
	bit RM_75,(iy+R_MOVE)
	jr z,.not75
	ld a,100
	call randint
	cp 75
	jr c,.random
.not75:
	bit RM_40,(iy+R_MOVE)
	jr z,.not40
	ld a,100
	call randint
	cp 40
	jr c,.random
.not40:
	bit RM_20,(iy+R_MOVE)
	jr z,.not20
	ld a,100
	call randint
	cp 20
	jr c,.random
.not20:
	bit RM_NORMAL,(iy+R_MOVE)
	jr z,.only_attack
	ld a,200
	call randint
	dec a
	jr z,.random
	call get_moves
	jp make_move
.only_attack:
	bit RM_ONLY_ATT,(iy+R_MOVE)
	ret z
	ld a,(ix+M_CDIS)
	cp 2
	ret nc
	call get_moves
	jp make_move
.random:
	ld hl,move_dirs
	ld b,5
.rnd:
	push bc
	push hl
	ld a,9
	call randint
	pop hl
	pop bc
	ld (hl),a
	inc hl
	djnz .rnd
	jp make_move

/* get_moves - IX = monster -> move_dirs = 5 keypad directions towards
	the player, best first (the get_moves() switch, as a table) */
get_moves:
	xor a
	ld (gm_val),a
	ld (gm_yneg),a
	ld (gm_xneg),a
	ld a,(player_y)						; y = monster - player
	ld b,a
	ld a,(ix+M_Y)
	sub b
	jr nc,.y_pos
	neg
	ld b,a
	ld a,8
	ld (gm_val),a
	ld (gm_yneg),a
	ld a,b
.y_pos:
	ld (gm_ay),a
	ld a,(player_x)
	ld b,a
	ld a,(ix+M_X)
	sub b
	jr c,.x_neg
	jr z,.x_zero
	ld b,a								; x > 0
	ld a,(gm_val)
	add a,4
	ld (gm_val),a
	ld a,b
	jr .x_zero
.x_neg:
	neg
	ld b,a
	ld a,1
	ld (gm_xneg),a
	ld a,b
.x_zero:
	ld (gm_ax),a
	add a,a								; ay > 2*ax -> +2
	jr c,.not_steep
	ld b,a
	ld a,(gm_ay)
	cp b
	jr z,.not_steep
	jr c,.not_steep
	ld hl,gm_val
	inc (hl)
	inc (hl)
	jr .pick
.not_steep:
	ld a,(gm_ay)						; ax > 2*ay -> +1
	add a,a
	jr c,.pick
	ld b,a
	ld a,(gm_ax)
	cp b
	jr z,.pick
	jr c,.pick
	ld hl,gm_val
	inc (hl)
.pick:
	ld a,(gm_val)
	ld d,a
	ld e,11
	mul d,e
	ld hl,get_moves_table
	add hl,de
	ld a,(hl)							; which test picks the order
	inc hl
	or a
	jr nz,.test_y
	ld a,(gm_ax)						; 0: ay > ax
	ld b,a
	ld a,(gm_ay)
	cp b
	jr z,.second
	jr c,.second
	jr .first
.test_y:
	cp 1
	jr nz,.test_x
	ld a,(gm_yneg)						; 1: y < 0
	or a
	jr z,.second
	jr .first
.test_x:
	ld a,(gm_xneg)						; 2: x < 0
	or a
	jr z,.second
.first:
	ld de,move_dirs
	ld bc,5
	ldir
	ret
.second:
	ld de,5
	add hl,de
	jr .first

; for each move_val 0-15: test (0 ay>ax, 1 y<0, 2 x<0), order if true,
; order if false. 3, 7, 11 and 15 can't happen.
get_moves_table:
	db 0, 9,8,6,7,3, 9,6,8,3,7			; 0
	db 1, 6,3,9,2,8, 6,9,3,8,2			; 1
	db 2, 8,9,7,6,4, 8,7,9,4,6			; 2
	db 0, 5,5,5,5,5, 5,5,5,5,5			; 3
	db 0, 7,8,4,9,1, 7,4,8,1,9			; 4
	db 1, 4,1,7,2,8, 4,7,1,8,2			; 5
	db 2, 8,9,7,6,4, 8,7,9,4,6			; 6
	db 0, 5,5,5,5,5, 5,5,5,5,5			; 7
	db 0, 3,2,6,1,9, 3,6,2,9,1			; 8
	db 1, 6,3,9,2,8, 6,9,3,8,2			; 9
	db 2, 2,3,1,6,4, 2,1,3,4,6			; 10
	db 0, 5,5,5,5,5, 5,5,5,5,5			; 11
	db 0, 1,2,4,3,7, 1,4,2,7,3			; 12
	db 1, 4,1,7,2,8, 4,7,1,8,2			; 13
	db 2, 2,3,1,6,4, 2,1,3,4,6			; 14
	db 0, 5,5,5,5,5, 5,5,5,5,5			; 15

/* make_move - IX = monster, IY = race. Try move_dirs in order until one
	uses the turn: moving, opening a door, attacking, or staying put */
make_move:
	xor a
	ld (mm_try),a
.try:
	ld a,(mm_try)
	ld hl,move_dirs
	add hl,a
	ld a,(hl)
	dec a
	add a,a
	ld hl,keypad_deltas
	add hl,a
	ld a,(ix+M_Y)
	add a,(hl)
	ld d,a
	inc hl
	ld a,(ix+M_X)
	add a,(hl)
	ld e,a
	push de
	call map_addr
	pop de
	ld a,(hl)
	and TERRAIN_MASK
	ld (mm_terrain),a
	cp T_PERMWALL
	jr z,.fail
	call terrain_flags
	bit TF_PASSABLE,a
	jr nz,.open
	ld a,(mm_terrain)
	cp T_DOOR_CLOSED
	jr z,.door
	cp T_DOOR_SECRET
	jr nz,.fail							; wall: try the next direction
.door:
	bit RM_OPEN_DOOR,(iy+R_MOVE)
	jr nz,.open_door
	ld a,(mm_terrain)					; can't open: a closed door gets
	cp T_DOOR_CLOSED					; bashed (needs 20+ hp, so never yet),
	ret z								; a secret one isn't noticed
	jr .fail
.open_door:
	ld a,(hl)
	and ~TERRAIN_MASK
	or T_DOOR_OPEN
	ld (hl),a
	ret
.open:
	ld a,(player_y)
	cp d
	jr nz,.not_player
	ld a,(player_x)
	cp e
	jp z,mon_attack
.not_player:
	bit F_MON_BIT,(hl)
	jr z,.move
	ld a,(ix+M_Y)						; occupied: fine only if it's us
	cp d
	jr nz,.fail
	ld a,(ix+M_X)
	cp e
	jr nz,.fail
	ret
.move:
	set F_MON_BIT,(hl)
	push de
	ld d,(ix+M_Y)
	ld e,(ix+M_X)
	call map_addr
	res F_MON_BIT,(hl)
	pop de
	ld (ix+M_Y),d
	ld (ix+M_X),e
	call mon_distance
	ld (ix+M_CDIS),a
	ret
.fail:
	ld hl,mm_try
	inc (hl)
	ld a,(hl)
	cp 5
	jp c,.try
	ret

/* mon_attack - IX = monster next to the player. Combat is milestone 4b;
	for now it just announces itself */
mon_attack:
	ld a,(ix+M_ML)
	or a
	ret z
	call msg_begin
	ld hl,txt_the
	call msg_add
	ld a,(ix+M_RACE)
	call race_addr
	ld l,(iy+R_NAME)
	ld h,(iy+R_NAME+1)
	call msg_add
	ld hl,txt_threatens
	call msg_add
	jp msg_end

keypad_deltas:							; dy, dx for directions 1-9
	db 1,-1, 1,0, 1,1, 0,-1, 0,0, 0,1, -1,-1, -1,0, -1,1

place_race:		db 0
place_sleep:	db 0
group_race:		db 0
alloc_left:		db 0
mon_moves:		db 0
move_dirs:		ds 5
mm_try:			db 0
mm_terrain:		db 0
gm_val:			db 0
gm_ay:			db 0
gm_ax:			db 0
gm_yneg:		db 0
gm_xneg:		db 0
