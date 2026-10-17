/* populate.asm - putting monsters on a new level  [overlay: PAGE_LEVEL]
	References: MISC1.C alloc_monster/place_monster/place_group/test_place
 */

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


place_race:		db 0
place_sleep:	db 0
group_race:		db 0
alloc_left:		db 0
