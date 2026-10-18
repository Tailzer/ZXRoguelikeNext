/* populate.asm - putting monsters and items on a new level  [overlay: PAGE_LEVEL]
	References: MISC1.C alloc_monster/place_monster/place_group/test_place/
	get_mons_num, MISC2.C alloc_object/place_object/place_gold/get_obj_num.
	The level tables come from tools/convert.py (data/alloc.asm).
 */

MON_NASTY			equ 50				; 1/x chance of a deeper monster
MAX_MONS_LEVEL		equ 99
MAX_OBJ_LEVEL		equ 255

/* mon_clear_all - empty the monster list */
mon_clear_all:
	ld hl,MON_LIST+M_RACE_HI
	ld de,MON_SIZE
	ld b,MON_MAX
.loop:
	ld (hl),MON_EMPTY
	add hl,de
	djnz .loop
	ret

/* place_monster - D = y, E = x, place_race = race (word), place_sleep =
	asleep or not. A unique isn't placed if it's dead or already here */
place_monster:
	push de
	ld hl,(place_race)
	call race_addr
	bit RF_UNIQUE,(iy+R_FLAGS)
	jr z,.ok
	call unique_absent
	jr c,.ok
	pop de
	ret
.ok:
	ld ix,MON_LIST						; find a free slot
	ld b,MON_MAX
	ld de,MON_SIZE
.find:
	ld a,(ix+M_RACE_HI)
	cp MON_EMPTY
	jr z,.found
	add ix,de
	djnz .find
	pop de
	ret									; list full
.found:
	pop de
	ld hl,(place_race)
	ld (ix+M_RACE),l
	ld (ix+M_RACE_HI),h
	ld (ix+M_Y),d
	ld (ix+M_X),e
	push de
	call map_addr
	set F_MON_BIT,(hl)
	ld hl,(place_race)
	call race_addr
	ld b,(iy+R_HD_DICE)					; hp: hit dice roll, or the maximum
	ld c,(iy+R_HD_SIDES)
	bit RF_MAX_HP,(iy+R_FLAGS)
	jr z,.roll
	ld d,b
	ld e,c
	mul d,e
	ex de,hl
	jr .hp
.roll:
	call damroll
.hp:
	ld (ix+M_HP),l
	ld (ix+M_HP+1),h
	ld (ix+M_MAXHP),l
	ld (ix+M_MAXHP+1),h
	ld a,(p_speed)						; cspeed = speed - 10 + py speed
	add a,(iy+R_SPEED)
	sub 10
	ld (ix+M_SPEED),a
	ld (ix+M_ML),0
	ld (ix+M_CONFUSED),0
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

/* unique_absent - place_race is a unique: carry set if it may appear
	(not killed, not already on the level) */
unique_absent:
	ld hl,(place_race)					; dead? bit (race & 7) of byte race/8
	ld a,l
	and 7
	ld b,a
	srl h
	rr l
	srl h
	rr l
	srl h
	rr l
	ld de,uniques_dead
	add hl,de
	ld a,(hl)
	inc b
.shift:
	dec b
	jr z,.bit
	rrca
	jr .shift
.bit:
	rrca
	ccf
	ret nc								; dead
	ld ix,MON_LIST						; already here?
	ld b,MON_MAX
	ld de,(place_race)
.scan:
	ld a,(ix+M_RACE)
	cp e
	jr nz,.next
	ld a,(ix+M_RACE_HI)
	cp d
	jr nz,.next
	or a
	ret
.next:
	push de
	ld de,MON_SIZE
	add ix,de
	pop de
	djnz .scan
	scf
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
	call get_mons_num
	ld (place_race),hl
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
	call place_monster
	jr .next
.group:
	call place_group
.next:
	ld hl,alloc_left
	dec (hl)
	jr nz,.each
	ret

/* alloc_town_monsters - townsfolk (alloc_monster(MIN_MALLOC_TD/TN, 3,
	TRUE)): asleep, and not within 3 squares of the player */
alloc_town_monsters:
	call mon_clear_all
	ld a,MIN_MALLOC_TD
	ld hl,town_night
	bit 0,(hl)
	jr z,$+4
	ld a,MIN_MALLOC_TN
	ld (alloc_left),a
.each:
	call random_open_spot
	bit F_MON_BIT,(hl)
	jr nz,.each
	push de
	call mon_distance
	pop de
	cp 4
	jr c,.each
	push de
	call get_mons_num
	ld (place_race),hl
	pop de
	ld a,1
	ld (place_sleep),a
	call place_monster
	ld hl,alloc_left
	dec (hl)
	jr nz,.each
	ret

/* get_mons_num - HL = a race for this depth (get_mons_num in MISC1.C):
	usually the higher of two picks from everything up to the dungeon
	level, then any race of that exact level; 1 in MON_NASTY looks a few
	levels deeper. Out-of-depth uniques are picked again */
get_mons_num:
	ld a,(dun_level)
/* get_mons_num_a - the same for level A */
get_mons_num_a:
	or a
	jr nz,.dungeon
	ld hl,(mon_level_table)				; the town: any of its folk
	call randint16
	dec hl
	ret
.dungeon:
	cp MAX_MONS_LEVEL+1
	jr c,$+4
	ld a,MAX_MONS_LEVEL
	ld (gm_base),a
.again:
	ld a,(gm_base)
	ld (gm_target),a
	ld a,MON_NASTY
	call randint
	dec a
	jr nz,.usual
	ld a,4								; level + |randnor(0,4)| + 1, taken
	call randint						; as level + 1d4 + 1d4 - 1
	ld b,a
	push bc
	ld a,4
	call randint
	pop bc
	add a,b
	dec a
	ld hl,gm_target
	add a,(hl)
	cp MAX_MONS_LEVEL+1
	jr c,$+4
	ld a,MAX_MONS_LEVEL
	ld (hl),a
	jr .exact
.usual:
	ld a,(gm_target)					; num = m_level[level] - m_level[0]
	call m_level
	ld de,(mon_level_table)
	or a
	sbc hl,de
	ld (gm_num),hl
	call randint16						; the higher of two picks
	ld (gm_pick),hl
	ld hl,(gm_num)
	call randint16
	ld de,(gm_pick)
	or a
	sbc hl,de
	jr c,.keep
	add hl,de
	ld (gm_pick),hl
.keep:
	ld hl,(gm_pick)						; its level becomes the target
	dec hl
	ld de,(mon_level_table)
	add hl,de
	call race_addr
	ld a,(iy+R_LEVEL)
	ld (gm_target),a
.exact:									; any race of exactly that level
	ld a,(gm_target)
	dec a
	call m_level
	ld (gm_pick),hl						; m_level[level-1]
	ld a,(gm_target)
	call m_level
	ld de,(gm_pick)
	or a
	sbc hl,de
	ld a,h
	or l
	jr nz,$+3
	inc hl
	call randint16
	dec hl
	ld de,(gm_pick)
	add hl,de
	push hl
	call race_addr						; deeper than the level and unique?
	pop hl
	ld a,(dun_level)
	cp (iy+R_LEVEL)
	ret nc
	bit RF_UNIQUE,(iy+R_FLAGS)
	ret z
	jp .again

/* m_level - A = level -> HL = mon_level_table[level]. Clobbers A */
m_level:
	ld hl,mon_level_table
	add hl,a
	add hl,a
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	ret

/* summon_monster - D = y, E = x: a monster from a little deeper appears
	next to there, awake (summon_monster in MISC1.C) -> carry if one did */
summon_monster:
	push de
	ld a,(dun_level)
	add a,MON_SUMMON_ADJ
	call get_mons_num_a
	ld (place_race),hl
	pop de
	call summon_spot
	ret nc
	xor a
	ld (place_sleep),a
	push de
	ld hl,(place_race)
	call race_addr
	pop de
	bit RM_GROUP,(iy+R_MOVE)
	jr z,.single
	call place_group
	scf
	ret
.single:
	call place_monster
	scf
	ret

/* summon_undead - D = y, E = x: an undead (not unique, below level + 5)
	appears next to there, awake (summon_undead in MISC1.C) -> carry */
summon_undead:
	push de
.pick:
	ld hl,NUM_RACES						; m = randint(l) - 1, then look on
	call randint16						; up to 20 races for one that fits
	dec hl
	ld b,21
.look:
	push bc
	push hl
	call race_addr
	pop hl
	pop bc
	bit RF_UNDEAD,(iy+R_FLAGS)
	jr z,.next
	bit RF_UNIQUE,(iy+R_FLAGS)
	jr nz,.next
	ld a,(dun_level)
	add a,5
	cp (iy+R_LEVEL)
	jr z,.next
	jr c,.next
	ld (place_race),hl
	pop de
	call summon_spot
	ret nc
	xor a
	ld (place_sleep),a
	call place_monster
	scf
	ret
.next:
	inc hl
	push hl
	ld de,NUM_RACES
	or a
	sbc hl,de
	pop hl
	jr nc,.pick
	djnz .look
	jr .pick

/* poly_at - D = y, E = x: the monster there becomes a random non-unique
	dungeon race, awake (poly_monster in SPELLS.C) */
poly_at:
	push de
	call mon_at
	call c,mon_remove
.pick:
	ld hl,(mon_level_table+MAX_MONS_LEVEL*2)	; randint(m_level[MAX] - m_level[0])
	ld de,(mon_level_table)						; - 1 + m_level[0]
	or a
	sbc hl,de
	call randint16
	dec hl
	ld de,(mon_level_table)
	add hl,de
	push hl
	call race_addr
	pop hl
	bit RF_UNIQUE,(iy+R_FLAGS)
	jr nz,.pick
	ld (place_race),hl
	xor a
	ld (place_sleep),a
	pop de
	jp place_monster

/* clone_at - D = y, E = x: another of the monster there appears beside it
	(multiply_monster in CREATURE.C) -> carry if one did */
clone_at:
	push de
	call mon_at
	pop de
	ret nc
	ld (ix+M_SLEEP),0
	ld (ix+M_SLEEP+1),0
	ld l,(ix+M_RACE)
	ld h,(ix+M_RACE_HI)
	ld (place_race),hl
	ld b,19								; (multiply_monster's tries)
	call summon_spot_n
	ret nc
	xor a
	ld (place_sleep),a
	call place_monster
	scf
	ret

/* summon_spot - D = y, E = x -> D, E = a random empty open square next to
	it (10 tries), carry if found */
summon_spot:
	ld b,10
/* summon_spot_n - the same with B tries */
summon_spot_n:
	ld (ss_centre),de
.try:
	push bc
	ld a,3
	call randint
	ld hl,ss_centre+1
	add a,(hl)
	sub 2
	ld d,a
	push de
	ld a,3
	call randint
	pop de
	ld hl,ss_centre
	add a,(hl)
	sub 2
	ld e,a
	call in_bounds
	jr nc,.no
	push de
	call map_addr
	pop de
	ld a,(hl)
	bit F_MON_BIT,a
	jr nz,.no
	and TERRAIN_MASK
	cp T_FLOOR
	jr z,.player
	cp T_CORRIDOR
	jr z,.player
	cp T_FLOOR_LIT
	jr nz,.no
.player:
	ld a,(player_y)
	cp d
	jr nz,.yes
	ld a,(player_x)
	cp e
	jr z,.no
.yes:
	pop bc
	scf
	ret
.no:
	pop bc
	djnz .try
	or a
	ret

/* place_group - D = y, E = x, place_race. 1d13 awake members spread
	round the spot, as place_group()'s fall-through switch does */
place_group:
	xor a
	ld (place_sleep),a
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
	call c,place_monster
	pop de
	pop hl
	pop bc
	inc hl
	inc hl
	djnz .member
	ret

group_offsets:							; dy, dx for cases 13 down to 1
	db 0,-2, 0,2, 2,0, -2,0, 1,1, 1,-1, -1,-1, -1,1, 0,1, 0,-1, 1,0, -1,0, 0,0

place_race:		dw 0
ss_centre:		dw 0
MON_SUMMON_ADJ	equ 2
place_sleep:	db 0
alloc_left:		db 0
gm_base:		db 0
gm_target:		db 0
gm_num:			dw 0
gm_pick:		dw 0

/* alloc_items - objects and treasure for a new level (end of cave_gen):
	about 9 objects in rooms, about 3 anywhere, about 3 piles of treasure.
	randnor(mean, 3) is approximated as mean - 4 + 1d7 */
alloc_items:
	call items_clear
	ld a,TREAS_ROOM_ALLOC
	call about
	or a
	jr z,.anywhere
	ld b,a
.room:
	push bc
	call item_spot
	ld a,(hl)
	and TERRAIN_MASK
	cp T_CORRIDOR						; rooms only: try again in corridors
	pop bc
	jr z,.room
	push bc
	call place_object
	pop bc
	djnz .room
.anywhere:
	ld a,TREAS_ANY_ALLOC
	call about
	or a
	jr z,.gold
	ld b,a
.any:
	push bc
	call item_spot
	call place_object
	pop bc
	djnz .any
.gold:
	ld a,TREAS_GOLD_ALLOC
	call about
	or a
	ret z
	ld b,a
.treasure:
	push bc
	call item_spot
	call place_gold
	pop bc
	djnz .treasure
	ret

/* about - A = mean -> A = mean - 4 + 1d7, at least 0 */
about:
	add a,-4
	ld b,a
	ld a,7
	push bc
	call randint
	pop bc
	add a,b
	ret p
	xor a
	ret

/* item_spot - a random floor square with no item and no player.
	-> D = y, E = x, HL = square */
item_spot:
	call random_open_spot
	push hl
	call item_at
	pop hl
	jr c,item_spot
	ld a,(player_y)
	cp d
	ret nz
	ld a,(player_x)
	cp e
	ret nz
	jr item_spot

/* place_object - D = y, E = x: a random object for this depth */
place_object:
	push de
	call item_free_slot
	pop de
	ret nc
	ld (ix+I_Y),d
	ld (ix+I_X),e
	call get_obj_num
	ld a,(dun_level)					; magic_treasure at this depth
	OVCALL PAGE_MISC, new_item, PAGE_LEVEL
	ret

/* get_obj_num - HL = a kind for this depth (get_obj_num in MISC2.C):
	1 in OBJ_GREAT looks much deeper; half the time it picks one dungeon
	object up to the level, otherwise the best of three; then any object of
	that object's exact level; rarer objects are often picked again */
get_obj_num:
	ld a,(dun_level)
	ld (go_level),a
	ld a,OBJ_GREAT
	call randint
	dec a
	jr nz,.level_set
	ld a,255							; level = level * 255 / 1d255 + 1
	call randint
	ld c,a
	ld a,(dun_level)
	ld h,a
	ld l,0
	ld d,0
	ld e,a
	or a
	sbc hl,de							; level * 255
	call div16_8
	inc hl
	ld a,h
	or a
	ld a,l
	jr z,$+4
	ld a,MAX_OBJ_LEVEL
	ld (go_level),a
.level_set:
	ld a,(go_level)						; count = t_level[level]
	call t_level
	ld (go_count),hl
	call randint16
	ld (go_pick),hl
	ld a,2
	call randint
	dec a
	jr z,.picked						; half the time: just the one
	ld b,2								; otherwise the best of three
.best:
	push bc
	ld hl,(go_count)
	call randint16
	ld de,(go_pick)
	or a
	sbc hl,de
	jr c,.lower
	add hl,de
	ld (go_pick),hl
.lower:
	pop bc
	djnz .best
.picked:
	ld hl,(go_pick)						; its level -> any object of that level
	dec hl
	call alloc_entry
	inc hl
	inc hl
	inc hl
	ld a,(hl)							; that object's level
	or a
	jr nz,.levelled
	xor a
	call t_level
	call randint16
	dec hl
	jr .entry
.levelled:
	ld (go_level),a
	dec a
	call t_level
	ld (go_pick),hl						; t_level[j-1]
	ld a,(go_level)
	call t_level
	ld de,(go_pick)
	or a
	sbc hl,de
	call randint16
	dec hl
	ld de,(go_pick)
	add hl,de
.entry:
	call alloc_entry					; rare ones: 1d(rare) must come up 1
	inc hl
	inc hl
	ld a,(hl)
	dec hl
	dec hl
	or a
	jr z,.done
	push hl
	call randint
	pop hl
	dec a
	jp nz,get_obj_num
.done:
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	ret

/* t_level - A = level -> HL = obj_level_table[level]. Clobbers A */
t_level:
	ld hl,obj_level_table
	add hl,a
	add hl,a
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	ret

/* alloc_entry - HL = index -> HL = its obj_alloc_table entry (kind word,
	rare, level). Clobbers DE */
alloc_entry:
	add hl,hl
	add hl,hl
	ld de,obj_alloc_table
	add hl,de
	ret

/* place_gold - D = y, E = x: treasure worth more deeper down
	(place_gold in MISC2.C) */
place_gold:
	push de
	call item_free_slot
	pop de
	ret nc
	ld (ix+I_Y),d
	ld (ix+I_X),e
	ld (ix+I_KIND_HI),KIND_GOLD
	ld (ix+I_NUMBER),1
	ld (ix+I_MARKED),0
	ld a,(dun_level)					; i = (1d(level+2) + 2) / 2 - 1
	add a,2
	call randint
	add a,2
	srl a
	dec a
	ld (gold_type),a
	ld a,OBJ_GREAT						; 1 in 11: i += 1d(level+1)
	call randint
	dec a
	jr nz,.clamp
	ld a,(dun_level)
	inc a
	call randint
	ld hl,gold_type
	add a,(hl)
	ld (hl),a
.clamp:
	ld a,(gold_type)
	cp MAX_GOLD
	jr c,$+4
	ld a,MAX_GOLD-1
	ld (ix+I_SUB),a
	call gold_addr						; value = cost + 8*1d(cost) + 1d8
	inc hl
	inc hl
	inc hl
	inc hl
	ld a,(hl)
	ld (gold_cost),a
	call randint
	ld e,a
	ld d,8
	mul d,e
	ld a,(gold_cost)
	add de,a
	push de
	ld a,8
	call randint
	pop hl
	add hl,a
	ld (ix+I_VALUE),l
	ld (ix+I_VALUE+1),h
	ret

go_level:		db 0
go_count:		dw 0
go_pick:		dw 0
gold_type:		db 0
gold_cost:		db 0
