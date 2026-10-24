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
	xor a								; (none bred yet)
	ld (MON_MULT),a
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
	ld a,(iy+R_LEVEL)					; out of its depth: the level's
	push hl								; rating, c > 30 ? 15 : c/2, and
	call .rate							; c/2 more for a unique
	pop hl
	ld (ix+M_ML),0
	ld (ix+M_CONFUSED),0
	ld (ix+M_STUN),0
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

.rate:									; A = its level, IY its race
	ld hl,dun_level
	sub (hl)
	ret c
	ret z
	ld c,a								; c
	cp 31
	ld a,15
	jr nc,$+5
	ld a,c
	srl a
	call rate_add
	bit RF_UNIQUE,(iy+R_FLAGS)
	ret z
	ld a,c
	srl a
	jp rate_add

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
	call place_win_monster				; (first: rooms may have filled
										;  much of the list)
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

/* place_win_monster - from level 100 down, 3 times in 5, Morgoth is
	there, awake, out of sight of the player (place_win_monster in MISC1.C;
	a winner has already met him) */
place_win_monster:
	ld a,(dun_level)
	cp WIN_MON_APPEAR
	ret c
	ld a,(p_winner)
	or a
	ret nz
	ld a,5
	call randint
	cp 4
	ret nc
.spot:
	call random_open_spot
	bit F_MON_BIT,(hl)
	jr nz,.spot
	push de
	call item_at
	pop de
	jr c,.spot
	push de
	call mon_distance
	pop de
	cp MAX_SIGHT+1
	jr c,.spot
	ld hl,RACE_MORGOTH
	ld (place_race),hl
	xor a
	ld (place_sleep),a
	jp place_monster

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

/* get_nmons_num_a - A = level -> HL = a race (get_nmons_num in MISC1.C:
	the vaults' meaner monsters): the best of three picks, the first 15
	further on, then any race of that one's level; uniques from deeper, or
	Sauron before his level, are picked again */
get_nmons_num_a:
	cp MAX_MONS_LEVEL+1
	jr c,$+4
	ld a,MAX_MONS_LEVEL
	ld (gm_base),a
.again:
	ld a,(gm_base)						; num = m_level[level] - m_level[0]
	call m_level
	ld de,(mon_level_table)
	or a
	sbc hl,de
	ld (gm_num),hl
	call randint16						; i = 1d(num) - 1 + 15, at most
	dec hl								; num - 1
	ld de,15
	add hl,de
	ld de,(gm_num)
	push hl
	or a
	sbc hl,de
	pop hl
	jr c,$+4
	ex de,hl
	dec hl
	ld (gm_pick),hl
	ld b,2								; then the higher of two more
.best:
	push bc
	ld hl,(gm_num)
	call randint16
	dec hl
	ld de,(gm_pick)
	push hl
	or a
	sbc hl,de
	pop hl
	jr c,$+5
	ld (gm_pick),hl
	pop bc
	djnz .best
	ld hl,(gm_pick)						; its level -> any of that level
	ld de,(mon_level_table)
	add hl,de
	call race_addr
	ld a,(iy+R_LEVEL)
	ld (gm_target),a
	dec a
	call m_level
	ld (gm_pick),hl
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
	call race_addr
	pop hl
	ld a,(gm_base)
	cp (iy+R_LEVEL)
	jr nc,.not_deep
	bit RF_UNIQUE,(iy+R_FLAGS)
	jp nz,.again
.not_deep:
	ld de,RACE_SAURON					; (Sauron, deeper than you are)
	push hl
	or a
	sbc hl,de
	pop hl
	ret nz
	ld a,(dun_level)
	cp (iy+R_LEVEL)
	ret nc
	jp .again

/* vault_place - D = y, E = x, HL = race, A = 1 asleep: that monster there
	(unless rooms have already put ROOM_MON_MAX on the level, leaving the
	rest of the list for its monsters, and Morgoth) */
vault_place:
	ld (place_race),hl
	ld (place_sleep),a
	call room_mon_full
	ret nc
	jp place_monster
/* room_mon_full -> no carry if the list has ROOM_MON_MAX already.
	Preserves DE */
room_mon_full:
	push de
	ld ix,MON_LIST
	ld de,MON_SIZE
	ld bc,MON_MAX*256
.each:
	ld a,(ix+M_RACE_HI)
	cp MON_EMPTY
	jr z,$+3
	inc c
	add ix,de
	djnz .each
	pop de
	ld a,c
	cp ROOM_MON_MAX
	ret

/* vault_mon - D = y, E = x, A = level, H = 1 for a meaner one
	(get_nmons_num): one asleep there, from that level */
vault_mon:
	push de
	dec h
	jr z,.nasty
	call get_mons_num_a
	jr .got
.nasty:
	call get_nmons_num_a
.got:
	pop de
	ld a,1
	jr vault_place

/* place_special - D = y, E = x, A = 1 good, 2 great: a good weapon or
	armour from 10 levels deeper (place_special in MISC2.C) */
place_special:
	ld (ps_good),a
	push de
	call item_free_slot
	pop de
	ret nc
	ld (ix+I_Y),d
	ld (ix+I_X),e
	OVCALL PAGE_MISC, try_special, PAGE_LEVEL	; a Ring of Power?
	ret c
.pick:
	ld a,(dun_level)
	add a,10
	call get_obj_num_a
	push hl
	call kind_addr
	pop hl
	ld a,(iy+K_CLASS)					; weapons, armour, bows and their
	cp IC_WEAPON						; arrows and bolts
	jr c,.pick
	cp IC_AMULET
	jr c,.good
	cp IC_BOW
	jr z,.good
	cp IC_AMMO
	jr nz,.pick
	ld a,(iy+K_TVAL)
	cp 10								; (not sling shot)
	jr z,.pick
.good:
	ld a,(ps_good)
	ld b,a
	ld a,(dun_level)
	OVCALL PAGE_MISC, new_good_item, PAGE_LEVEL
	ret

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
	xor a								; (awake)
	jr summon_slp
/* summon_asleep - the same, asleep (vault_monster's summon_monster(.., TRUE)) */
summon_asleep:
	call room_mon_full
	ret nc
	ld a,1
summon_slp:
	ld (sm_sleep),a
	push de
	ld a,(dun_level)
	add a,MON_SUMMON_ADJ
	call get_mons_num_a
	ld (place_race),hl
	pop de
	call summon_spot
	ret nc
	ld a,(sm_sleep)
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

/* summon_by - A = SUM_ kind, D = y, E = x, L = the summoner's level: one
	of that kind appears next to there, awake (the summon_ functions of
	MISC1.C) -> carry and D, E = where, if one did */
summon_by:
	ld (sb_kind),a
	ld a,l
	ld (sb_level),a
	ld a,(sb_kind)
	or a
	jr nz,summon_match
	call summon_monster
	ret nc
	ld de,(ss_found)
	ret

/* summon_undead - D = y, E = x: an undead (not unique, below level + 5)
	appears next to there, awake (summon_undead in MISC1.C) -> carry */
summon_undead:
	ld a,SUM_UNDEAD
	ld (sb_kind),a
/* summon_match - sb_kind: a race of that kind, found as the C does (m =
	randint(l) - 1, then up to 20 on from there), next to D, E (a unique
	already here or dead doesn't come: place_monster) -> carry, D, E */
summon_match:
	push de
	xor a
	ld (sb_picks),a
.pick:
	ld hl,sb_picks						; (none of that kind at all: give up)
	dec (hl)
	jr z,.none
	ld hl,NUM_RACES
	call randint16
	dec hl
	ld b,21
.look:
	push bc
	push hl
	call race_addr
	call sb_test
	pop hl
	pop bc
	jr c,.found
	inc hl
	push hl
	ld de,NUM_RACES
	or a
	sbc hl,de
	pop hl
	jr nc,.pick
	djnz .look
	jr .pick
.none:
	pop de
	or a
	ret
.found:
	ld (place_race),hl
	pop de
	call summon_spot
	ret nc
	xor a
	ld (place_sleep),a
	call place_monster
	ld de,(ss_found)
	scf
	ret

/* sb_test - IY = race -> carry if it's of kind sb_kind */
sb_test:
	ld a,(sb_kind)
	cp SUM_ANGEL
	jr nc,.lettered
	or a								; undead, demons, dragons: no uniques
	bit RF_UNIQUE,(iy+R_FLAGS)
	ret nz
	cp SUM_UNDEAD
	jr z,.undead
	cp SUM_DEMON
	jr z,.demon
	bit RF2_DRAGON,(iy+R_FLAGS2)
	ret z
	scf
	ret
.undead:								; below dun_level + 5
	bit RF_UNDEAD,(iy+R_FLAGS)
	ret z
	ld a,(dun_level)
	add a,4
	cp (iy+R_LEVEL)
	ccf
	ret
.demon:									; up to the summoner's level
	bit RF_DEMON,(iy+R_FLAGS)
	ret z
	ld a,(sb_level)
	cp (iy+R_LEVEL)
	ccf
	ret
.lettered:								; the rest go by their letter
	sub SUM_ANGEL
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	ld de,sb_kinds
	add hl,de
	ld e,(hl)							; DE = the letters
	inc hl
	ld d,(hl)
	inc hl
	ld a,(hl)							; SB_ rule about uniques
	or a
	jr z,.letters
	ld b,a
	ld a,(iy+R_FLAGS)
	and 1<<RF_UNIQUE
	jr z,.common
	ld a,b
	cp SB_UNIQUE
	jr z,.letters
	or a
	ret
.common:
	ld a,b
	cp SB_COMMON
	jr z,.letters
	or a
	ret
.letters:
	ex de,hl
	ld b,(iy+R_CHAR)
	ld a,(hl)
	cp "!"
	jr z,.not_in
.in:
	ld a,(hl)
	inc hl
	or a
	ret z
	cp b
	jr nz,.in
	scf
	ret
.not_in:								; any letter but these
	inc hl
	ld a,(hl)
	or a
	scf
	ret z
	cp b
	jr nz,.not_in
	or a
	ret
SB_ANY		equ 0
SB_COMMON	equ 1
SB_UNIQUE	equ 2
; from SUM_ANGEL on: the letters, the rule about uniques (MISC1.C summon_*)
sb_kinds:	dw sb_angel
			db SB_COMMON,0
			dw sb_spider
			db SB_COMMON,0
			dw sb_hound
			db SB_COMMON,0
			dw sb_gundead
			db SB_ANY,0
			dw sb_ancientd
			db SB_ANY,0
			dw sb_wraith
			db SB_UNIQUE,0
			dw sb_reptile
			db SB_COMMON,0
			dw sb_ant
			db SB_COMMON,0
			dw sb_not_p
			db SB_UNIQUE,0
			dw sb_jabberwock
			db SB_COMMON,0
sb_angel:	db "A",0
sb_spider:	db "S",0
sb_hound:	db "CZ",0
sb_gundead:	db "LVW",0
sb_ancientd: db "D",0
sb_wraith:	db "W",0
sb_reptile:	db "R",0
sb_ant:		db "a",0
sb_not_p:	db "!P",0
sb_jabberwock: db "J",0

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

/* mon_breed - IX = a monster that breeds (MULTIPLY), IY its race, at the
	start of its move (mon_move in CREATURE.C): while fewer than
	MAX_MON_MULT have bred on the level, and you aren't resting (but every
	8th turn of a count, or 1 in 8 resting till you're better), with fewer
	than 4 monsters in the 9 squares round it (itself too, k), 1 in 8k
	another appears beside it, awake */
mon_breed:
	ld a,(MON_MULT)
	cp MAX_MON_MULT+1
	ret nc
	OVCALL PAGE_RUN, rest_state, PAGE_LEVEL	; A = 0 not resting, else HL
	or a								; the count ($FFFF: till better)
	jr z,.count
	ld a,h
	and l
	inc a
	jr z,.needed
	ld a,l
	and MON_MULT_ADJ-1
	ret nz
	jr .count
.needed:
	ld a,MON_MULT_ADJ
	call randint
	dec a
	ret nz
.count:
	ld a,(ix+M_Y)						; k: monsters in the 3 x 3 round it
	dec a
	ld d,a
	ld a,(ix+M_X)
	dec a
	ld e,a
	call map_addr
	ld c,0
	ld b,3
.row:
	push bc
	ld b,3
.col:
	bit F_MON_BIT,(hl)
	jr z,$+3
	inc c
	inc hl
	djnz .col
	ld de,MAP_W-3
	add hl,de
	ld a,c
	pop bc
	ld c,a
	djnz .row
	ld a,c
	cp 4
	ret nc
	add a,a								; 1 in 8k
	add a,a
	add a,a
	call randint
	dec a
	ret nz
	ld d,(ix+M_Y)
	ld e,(ix+M_X)
	push ix
	call clone_spot
	pop ix
	ret nc
	ld hl,MON_MULT
	inc (hl)
	ld hl,rc_wake						; (seen, it's known to breed)
	set RC_BRED,(hl)
	ret

/* clone_at - D = y, E = x: another of the monster there appears beside it
	(multiply_monster in CREATURE.C) -> carry if one did */
clone_at:
	push de
	call mon_at
	pop de
	ret nc
	ld (ix+M_SLEEP),0
	ld (ix+M_SLEEP+1),0
/* clone_spot - IX = a monster at D, E: another of it appears beside it,
	awake -> carry if one did */
clone_spot:
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
	ld (ss_found),de
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
	ld hl,(lv_rating)					; (only the first counts)
	ld (pg_rating),hl
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
	ld hl,(pg_rating)
	ld (lv_rating),hl
	ld hl,(place_race)
	call race_addr
	ld a,(iy+R_LEVEL)
	jp place_monster.rate

group_offsets:							; dy, dx for cases 13 down to 1
	db 0,-2, 0,2, 2,0, -2,0, 1,1, 1,-1, -1,-1, -1,1, 0,1, 0,-1, 1,0, -1,0, 0,0

place_race:		dw 0
pg_rating:		dw 0
ss_centre:		dw 0
ss_found:		dw 0				; where summon_spot found room
sb_kind:		db 0
sb_level:		db 0
sb_picks:		db 0
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
	OVCALL PAGE_MISC, try_special, PAGE_LEVEL	; a Ring of Power?
	ret c
	call get_obj_num
	push hl								; out of its depth: the level's
	call kind_addr						; rating
	ld a,(iy+K_LEVEL)
	call rate_deeper
	pop hl
	ld a,(dun_level)					; magic_treasure at this depth
	OVCALL PAGE_MISC, new_item, PAGE_LEVEL
	ret

/* get_obj_num - HL = a kind for this depth (get_obj_num in MISC2.C):
	1 in OBJ_GREAT looks much deeper; half the time it picks one dungeon
	object up to the level, otherwise the best of three; then any object of
	that object's exact level; rarer objects are often picked again */
get_obj_num:
	ld a,(dun_level)
/* get_obj_num_a - the same for level A (place_special: deeper) */
get_obj_num_a:
	ld (go_base),a
.again:
	ld a,(go_base)
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
	jp nz,get_obj_num_a.again
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

/* rate_deeper - A = a level: as far as it's below this one, the level's
	rating rises (place_object). -> A = how far (0 if not) */
rate_deeper:
	ld hl,dun_level
	sub (hl)
	jr nc,.deeper
	xor a
	ret
.deeper:
	ret z
/* rate_add - A: added to the level's rating. Preserves A */
rate_add:
	ld hl,(lv_rating)
	add hl,a
	ld (lv_rating),hl
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
go_base:		db 0
sm_sleep:		db 0
ps_good:		db 0
go_count:		dw 0
go_pick:		dw 0
gold_type:		db 0
gold_cost:		db 0
