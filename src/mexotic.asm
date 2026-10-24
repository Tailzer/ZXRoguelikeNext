/* mexotic.asm - the rest of the monsters' spells (overlay page PAGE_MCAST,
	after mcast.asm): the exotic breaths, nether, the whirlpool, darkness,
	forgetting, teleport level, nexus, elemental force, time, gravity and
	the bigger summons (CREATURE.C mon_cast_spell, 33-78; br_wall; SPELLS.C
	chaos/lose_all_info). As in the C without colour, every exotic breath
	hits as a magic missile; what it does besides is below.
 */

; ---------------------------------------------------------------- the breaths

mc_br_chaos:							; 33
	ld hl,mz_br_chaos
	call mx_say
	ld b,6
	ld de,400
	call resists_chaos
	jp nz,hp_ball
	ld de,450							; (the C: nether resistance does too)
	ld a,(p_eflags2+3)
	and TR2_RES_NETHER
	jp nz,hp_ball
	ld de,600
	call hp_ball
	ld a,3
	call keep_life
	jr c,.mind
	ld hl,mcm_draining
	call mx_print
	ld hl,5000
	ld b,1
	call drain_exp
.mind:
	call confuse_resist
	call z,confuse_big
	jp chaos_all
mc_br_shards:							; 34
	ld hl,mz_br_shards
	call mx_say
	ld b,6
	ld de,267
	ld a,(p_eflags2+2)
	and TR2_RES_SHARDS
	jp nz,hp_ball
	ld de,400
	call hp_ball
	ld l,(ix+M_HP)						; cut_player(hp / 3)
	ld h,(ix+M_HP+1)
	call div3
	jp mc_cut
mc_br_sound:							; 35
	ld hl,mz_br_sound
	call mx_say
	ld b,6
	ld de,200
	ld a,(p_eflags2+2)
	and TR2_RES_SOUND
	jp nz,hp_ball
	ld de,400
	call hp_ball
	ld l,(ix+M_HP)						; stunned 1d(min(hp / 20, 35) + 5)
	ld h,(ix+M_HP+1)
	ld c,20
	call div16_8
	ld de,31
	or a
	sbc hl,de
	add hl,de
	ld a,l
	jr c,$+4
	ld a,35
	add a,5
	call randint
	jp mc_stun
mc_br_confusion:						; 36
	ld hl,mz_br_confusion
	call mx_say
	ld b,6
	ld de,200
	call confuse_resist
	jp nz,hp_ball
	ld de,400
	call hp_ball
/* confuse_big - confused 12 more turns, or 1d20 + 10 */
confuse_big:
	ld hl,(p_confused)
	ld a,h
	or l
	ld a,12
	jr nz,.add
	ld a,20
	call randint
	add a,10
	ld hl,0
.add:
	add hl,a
	ld (p_confused),hl
	ret
mc_br_disenchant:						; 37
	ld hl,mz_br_disenchant
	call mx_say
	ld b,6
	ld de,334
	ld a,(p_eflags2+2)
	and TR2_RES_DISENCHANT
	jp nz,hp_ball
	ld hl,dis_slots
	call disenchant
	ld b,6
	ld de,500
	call hp_ball
	ld a,(mc_count)
	or a
	ret z
	ld hl,p_update
	set PU_BONUS,(hl)
	ld hl,mcm_static
	jp mx_print
/* disenchant - HL = 7 equipment slots: one of them, at random, loses
	1d2 of each of its pluses (none below 0) -> mc_count = 1 if any did */
disenchant:
	xor a
	ld (mc_count),a
	push hl
	ld a,7
	call randint
	pop hl
	dec hl
	add hl,a
	ld e,(hl)
	ld d,ITEM_SIZE
	mul d,e
	push ix
	ld ix,EQUIP
	add ix,de
	ld a,(ix+I_KIND_HI)
	cp ITEM_EMPTY
	jr z,.done
	ld hl,I_TOHIT
	call .plus
	ld hl,I_TODAM
	call .plus
	ld hl,I_TOAC
	call .plus
.done:
	pop ix
	ret
.plus:									; HL = the field's offset
	push ix
	pop de
	add hl,de
	ld a,(hl)
	dec a
	cp 127
	ret nc								; 0 or below: left alone
	push hl
	ld a,2
	call randint
	pop hl
	ld b,a
	ld a,(hl)
	sub b
	jr nc,$+3
	xor a
	ld (hl),a
	ld a,1
	ld (mc_count),a
	ret
; the C's 1d7: INVEN_BODY twice, then ARM, OUTER, HANDS, HEAD, FEET
dis_slots:	db EQ_BODY, EQ_BODY, EQ_SHIELD, EQ_CLOAK, EQ_GLOVES, EQ_HELM, EQ_BOOTS
mc_br_nether:							; 38
	ld hl,mz_br_nether
	call mx_say
	ld b,6
	ld de,300
	ld a,(p_eflags2+3)
	and TR2_RES_NETHER
	jp nz,hp_ball
	ld de,400
	call hp_ball
	ld a,4
	call keep_life
	ret c
	ld hl,mcm_draining
	call mx_print
	ld l,(ix+M_HP)						; lose hp / 3 + exp / 100 * 2
	ld h,(ix+M_HP+1)
	call div3
	ld b,1
	jp drain_exp
mc_br_force:							; 65
	ld hl,mz_br_force
	call mx_say
	ld a,10
	call randint
	cp 1
	jp z,br_wall
	ld b,6
	ld de,200
	call hp_ball
	ld a,20
	jp stun_unless
mc_br_inertia:							; 66
	ld hl,mz_br_inertia
	call mx_say
	ld b,6
	ld de,200
	call hp_ball
	ld hl,mcm_less_able
	call mx_print
/* slow_new - slowed for 1d5 + 3 (set, not added to) */
slow_new:
	ld a,5
	call randint
	add a,3
	ld l,a
	ld h,0
	ld (p_slow),hl
	ret
mc_br_bright:							; 67
	ld hl,mz_br_light
	call mx_say
	ld b,6
	ld de,200
	ld a,(p_eflags2+2)
	and TR2_RES_LT
	jr nz,.resisted
	ld de,400
	call hp_ball
	call light_area
	call blind_resist
	ret nz
	ld hl,(p_blind)
	ld a,h
	or l
	ret nz
	ld hl,mcm_flash
	call mx_print
	ld a,6
	call randint
	add a,3
	ld l,a
	ld h,0
	ld (p_blind),hl
	ret
.resisted:
	call hp_ball
/* light_area - the room or the squares around lit (light_area) */
light_area:
	push ix
	OVCALL PAGE_SCROLL, sc_light, PAGE_MCAST
	pop ix
	ret
mc_br_time:								; 68
	ld hl,mz_br_time
	call mx_say
	ld b,3
	ld de,150
	call hp_ball
	ld a,10
	call randint
	cp 6
	jr nc,.stats
	ld hl,mcm_clocked
	call mx_print
	ld l,(ix+M_HP)						; lose hp + exp / 300 * 2
	ld h,(ix+M_HP+1)
	ld b,3
	jp drain_exp
.stats:
	cp 10
	jr z,.all
	ld a,6
	call randint
	dec a
	jr shrink_stat
.all:
	xor a
.each:
	push af
	call shrink_stat
	pop af
	inc a
	cp 6
	jr c,.each
	ret
/* shrink_stat - A = stat: three quarters of what it was, at least 3,
	"You're not as strong as you used to be..." */
shrink_stat:
	push af
	add a,a
	ld hl,time_msgs
	add hl,a
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	call mx_print
	pop af
	ld hl,p_stat
	add hl,a
	ld e,(hl)
	ld d,3
	mul d,e
	srl d
	rr e
	srl d
	rr e
	ld a,e
	cp 3
	jr nc,$+4
	ld a,3
	ld (hl),a
	ld hl,p_update						; (the stat in use follows)
	ld a,(hl)
	or 1<<PU_BONUS|1<<PU_HP
	ld (hl),a
	ret
time_msgs:	dw mcm_strong, mcm_bright, mcm_wise, mcm_agile, mcm_hale, mcm_beautiful
mc_br_gravity:							; 69
	ld hl,mz_br_gravity
	call mx_say
	call hp_stun
	ld b,3
	ld de,200
	call hp_ball
	call slow_new
	ld hl,mcm_gravity
	call mx_print
	ld hl,5
	jp tport_player
mc_br_dark:								; 70
	ld hl,mz_br_dark
	ld bc,200
	ld de,400
	jr dark_ball
mc_dark_storm:							; 74
	ld hl,mz_dark_storm
	ld bc,250
	ld de,500
/* dark_ball - HL = what it does, BC = cap if resisting darkness, DE = cap
	if not: hp / 6 of it, then the room goes dark (unlight_area) */
dark_ball:
	push bc
	push de
	call mx_say
	pop de
	pop hl
	ld a,(p_eflags2+2)
	and TR2_RES_DARK
	jr z,$+3
	ex de,hl
	ld b,6
	call hp_ball
	push ix
	OVCALL PAGE_SCROLL, sc_darkness, PAGE_MCAST
	pop ix
	ret
mc_br_plasma:							; 71
	ld hl,mz_br_plasma
	call mx_say
	ld b,6
	ld de,150
	call hp_ball
/* hp_stun - unless resisting sound: stunned 1d(hp / 8, 1 to 35) */
hp_stun:
	ld a,(p_eflags2+2)
	and TR2_RES_SOUND
	ret nz
	ld l,(ix+M_HP)
	ld h,(ix+M_HP+1)
	ld c,8
	call div16_8
	ld de,36
	or a
	sbc hl,de
	add hl,de
	ld a,l
	jr c,$+4
	ld a,35
	or a
	jr nz,$+3
	inc a
	call randint
	jp mc_stun
mc_br_nexus:							; 64
	ld hl,mz_br_nexus
	call mx_say
	ld b,3
	ld de,167
	ld a,(p_eflags2+2)
	and TR2_RES_NEXUS
	jp nz,hp_ball
	ld de,250
	call hp_ball
	ld a,7
	call randint
	cp 4
	jr nc,.not_far
	ld hl,200
	jp tport_player
.not_far:
	cp 6
	jp c,tele_to
	jr nz,.scramble
	call player_saves
	jp nc,tele_level
	ld hl,mcm_resist_effects
	jp mx_print
.scramble:
	call player_saves
	jr nc,.go
	ld a,2
	call randint
	cp 1
	ld hl,mcm_resist_effects
	jp z,mx_print
.go:
	ld hl,mcm_scramble
	call mx_print
	ld a,6								; two different stats swap, current
	call randint						; and maximum
	dec a
	ld c,a
.other:
	push bc
	ld a,6
	call randint
	pop bc
	dec a
	cp c
	jr z,.other
	ld b,a
	ld hl,p_stat
	call .swap
	ld hl,p_stat_max
	call .swap
	ld hl,p_update
	ld a,(hl)
	or 1<<PU_BONUS|1<<PU_HP
	ld (hl),a
	ret
.swap:									; HL = the stats, B and C the two
	push bc
	push hl
	ld a,b
	add hl,a
	ex de,hl
	pop hl
	ld a,c
	add hl,a
	ld a,(de)
	ld b,(hl)
	ld (hl),a
	ld a,b
	ld (de),a
	pop bc
	ret

/* hp_ball - B = 3 or 6, DE = cap: a ball (as a magic missile) of the
	caster's hp / B, up to the cap */
hp_ball:
	push de
	ld l,(ix+M_HP)
	ld h,(ix+M_HP+1)
	ld c,b
	call div16_8
	pop de
	push hl
	or a
	sbc hl,de
	pop hl
	jr c,$+3
	ex de,hl
	ld a,GF_MAGIC_MISSILE
	jp mon_ball

; ---------------------------------------------------------------- nether

mc_nether_bolt:							; 51
	ld hl,mz_nether_bolt
	call mx_say
	ld a,(p_eflags2+3)
	and TR2_RES_NETHER
	jr z,.full
	ld a,(mc_level)						; 20 + 5d3 + level * 8 / 3
	ld e,a
	ld d,8
	mul d,e
	ex de,hl
	call div3
	ld a,20
	add hl,a
	push hl
	ld bc,5*256+3
	call damroll
	pop de
	add hl,de
	ld a,GF_MAGIC_MISSILE
	jp mon_bolt
.full:
	ld bc,5*256+5						; 30 + 5d5 + level / 4
	call damroll
	ld a,(mc_level)
	srl a
	srl a
	add a,30
	add hl,a
	ld a,GF_MAGIC_MISSILE
	call mon_bolt
	ret nc								; (only if it hit the player)
	ld a,(p_eflags2)
	and TR2_HOLD_LIFE
	jr z,.drain
	ld a,5
	call randint
	cp 1
	ld hl,mcm_keep_life
	jp nz,mx_print
	ld hl,mcm_slipping
	call mx_print
	ld hl,200
	ld b,10
	jp drain_exp
.drain:
	ld hl,mcm_draining
	call mx_print
	ld hl,200
	ld b,1
	jp drain_exp
mc_nether_ball:							; 60
	ld hl,mz_nether_ball
	call mx_say
	ld a,(p_eflags2+3)
	and TR2_RES_NETHER
	jr z,.full
	ld bc,10*256+7						; 34 + 10d7 + level * 2 / 3
	call damroll
	push hl
	ld a,(mc_level)
	ld l,a
	ld h,0
	add hl,hl
	call div3
	pop de
	add hl,de
	ld a,34
	add hl,a
	ld a,GF_MAGIC_MISSILE
	jp mon_ball
.full:
	ld bc,10*256+10						; 50 + 10d10 + level
	call damroll
	ld a,(mc_level)
	add hl,a
	ld a,50
	add hl,a
	ld a,GF_MAGIC_MISSILE
	call mon_ball
	ld a,2
	call keep_life
	ret c
	ld hl,mcm_draining
	call mx_print
	ld hl,5000
	ld b,1
	jp drain_exp

/* keep_life - A = n: with hold life, 1dn above 1 keeps it ("You keep
	hold of your life force!") -> carry if kept */
keep_life:
	ld b,a
	ld a,(p_eflags2)
	and TR2_HOLD_LIFE
	ret z								; (carry is clear)
	ld a,b
	call randint
	cp 2
	ccf
	ret nc
	ld hl,mcm_keep_life
	call mx_print
	scf
	ret

/* drain_exp - HL = base, B = 1, 3 or 10: lose base + exp / (B * 100) * 2
	experience (lose_exp) */
drain_exp:
	ld (mc_base),hl
	ld hl,(p_exp)
	ld a,(p_exp+2)
	ld e,a
	ld a,b
	cp 1
	jr z,.hundred
	ld c,a
	call div24_8
.hundred:
	ld c,100
	call div24_8
	add hl,hl
	rl e
	ld bc,(mc_base)
	add hl,bc
	ld a,e
	adc a,0
	ld e,a
	push ix
	OVCALL PAGE_MAGIC, lose_exp, PAGE_MCAST
	pop ix
	ret

; ---------------------------------------------------------------- the rest

mc_traps:								; 42: trap creation
	ld hl,mz_casts_spell
	call mx_say
	push ix
	OVCALL PAGE_TRAP, trap_creation, PAGE_MCAST
	pop ix
	ret
mc_shadow:								; 53
	ld hl,mz_shadow
	call mx_say
	push ix
	OVCALL PAGE_SCROLL, sc_darkness, PAGE_MCAST
	pop ix
	ret
mc_forget:								; 54
	ld hl,mz_blank_mind
	call mx_say
	call player_saves
	jr c,.resist
	ld a,2
	call randint
	cp 1
	jr nz,.forget
.resist:
	ld hl,mcm_resist_spell2
	jp mx_print
.forget:								; lose_all_info: what's known of the
	push ix								; pack's and equipment's pluses, and
	ld ix,PACK							; the map
	ld b,PACK_MAX+EQ_SLOTS
	ld de,ITEM_SIZE
.item:
	ld a,(ix+I_KIND_HI)
	cp ITEM_EMPTY
	jr z,.next
	res ID_KNOWN2_BIT,(ix+I_IDENT)
.next:
	add ix,de
	djnz .item
	pop ix
	ld hl,MAP_BASE
	ld bc,MAP_W*MAP_H
.square:
	res F_PERM_BIT,(hl)
	cpi
	jp pe,.square
	call update_view
	ld hl,mcm_memories
	jp mx_print
mc_tele_level:							; 57
	ld hl,mz_gestures
	call mx_say
	call player_saves
	jr c,.firm
	ld a,3
	call randint
	cp 1
	jr nz,.firm
	ld a,(p_eflags2+2)
	and TR2_RES_NEXUS
	jr z,tele_level
.firm:
	ld hl,mcm_firm
	jp mx_print
/* tele_level - up or down a level: "You sink through the floor." */
tele_level:
	ld a,(dun_level)					; (Sauron's level: only up)
	call is_quest
	ld a,-1
	jr z,.change
	ld a,2
	call randint
	add a,a
	sub 3
.change:
	ld hl,dun_level
	add a,(hl)
	bit 7,a
	jr z,$+3
	xor a
	ld b,(hl)
	ld (hl),a
	cp b
	ld hl,mcm_sink
	jr z,.rise
	jr nc,.said
.rise:
	ld hl,mcm_rise
.said:
	call mx_print
	ld a,3
	ld (p_new_level),a
	ret
mc_whirlpool:							; 59
	ld hl,mz_fluidly
	call mx_say
	ld hl,mcm_whirlpool
	call mx_print
	ld a,(mc_level)						; 1d(level * 5 / 2) + 50
	ld e,a
	ld d,5
	mul d,e
	srl d
	rr e
	ex de,hl
	call rand_or_0
	ld a,50
	add hl,a
	ld a,GF_MAGIC_MISSILE
	call mon_ball
	ld a,55
	call stun_unless
	call player_saves
	ret c
	call confuse_resist
	ret nz
	ld hl,(p_confused)					; 6 more, or 1d8 + 6
	ld a,h
	or l
	ld a,6
	jr nz,.add
	ld a,8
	call randint
	add a,6
	ld hl,0
.add:
	add hl,a
	ld (p_confused),hl
	ret
mc_arrow:								; 72
	ld hl,mz_arrow
	call mx_say
	ld a,6
	call randint
	ld l,a
	ld h,0
	ld a,GF_MAGIC_MISSILE
	jp mon_bolt
mc_mana_storm:							; 75: level * 5 + 10d10
	ld hl,mz_mana_storm
	call mx_say
	ld bc,10*256+10
	call damroll
	ld a,(mc_level)
	ld e,a
	ld d,5
	mul d,e
	add hl,de
	ld a,GF_MAGIC_MISSILE
	jp mon_ball

/* tport_player - HL = distance: teleport() (the scroll overlay's) */
tport_player:
	push ix
	OVCALL PAGE_SCROLL, teleport, PAGE_MCAST
	pop ix
	jp mon_race

/* chaos_all - every monster but uniques and the caster within MAX_SIGHT
	becomes something else (chaos in SPELLS.C) */
chaos_all:
	ld (mc_caster),ix
	ld ix,MON_LIST
	ld b,MON_MAX
.each:
	push bc
	ld a,(ix+M_RACE_HI)
	cp MON_EMPTY
	jr z,.next
	ld a,(ix+M_CDIS)
	cp MAX_SIGHT
	jr nc,.next
	push ix
	pop hl
	ld de,(mc_caster)
	or a
	sbc hl,de
	jr z,.next
	call mon_race
	bit RF_UNIQUE,(iy+R_FLAGS)
	jr nz,.next
	ld d,(ix+M_Y)
	ld e,(ix+M_X)
	push ix
	OVCALL PAGE_LEVEL, poly_at, PAGE_MCAST
	pop ix
.next:
	ld de,MON_SIZE
	add ix,de
	pop bc
	djnz .each
	call monsters_see_all
	ld ix,(mc_caster)
	jp mon_race

/* br_wall - elemental force brings the cave down: the player is pushed to
	an open square beside them and theirs fills with rock, or, with nowhere
	to go, crushed for 250 (br_wall in CREATURE.C) */
br_wall:
	ld hl,250
/* br_wall_n - the same, HL = the damage if there's nowhere to go */
br_wall_n:
	ld (mc_trapdam),hl
	ld a,(player_y)						; the first free square round about
	dec a
	ld d,a
	ld b,3
.row:
	ld a,(player_x)
	dec a
	ld e,a
	ld c,3
.col:
	push bc
	push de
	call free_square
	pop de
	pop bc
	jr c,.found
	inc e
	dec c
	jr nz,.col
	inc d
	djnz .row
	ld de,0								; none: crushed
.found:
	ld (mc_sq),de
	ld a,3
	call randint
	dec a
	add a,a
	ld hl,wall_msgs
	add hl,a
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	call mx_print
	ld hl,KILLER_EARTHQUAKE
	ld (killer_race),hl
	ld hl,(mc_sq)
	ld a,h
	or l
	jr nz,.escape
	ld hl,mcm_trapped
	call mx_print
	ld hl,(mc_trapdam)
	jp take_hit
.escape:
	ld a,3
	call randint
	ld hl,0
	cp 2
	jr nz,.hurt
	ld hl,mcm_dodge
	call mx_print
	ld hl,0
	jr .move
.hurt:
	ld hl,mcm_rubble
	cp 1
	jr z,$+5
	ld hl,mcm_crushes
	call mx_print
	ld a,50
	call randint
	call mc_stun
	ld bc,10*256+4
	call damroll
.move:
	push hl
	call player_square					; a floor becomes rock
	ld a,(hl)
	and TERRAIN_MASK
	cp T_FLOOR
	jr z,.rock
	cp T_CORRIDOR
	jr z,.rock
	cp T_FLOOR_LIT
	jr nz,.moved
.rock:
	push hl
	ld a,10
	call randint
	pop hl
	ld b,T_QUARTZ
	cp 6
	jr c,.wall
	ld b,T_MAGMA
	cp 9
	jr c,.wall
	ld b,T_GRANITE
.wall:
	ld a,(hl)
	and $FF-TERRAIN_MASK-F_PERM
	or b
	ld (hl),a
.moved:
	push ix
	call lamp_off
	ld de,(mc_sq)
	ld a,d
	ld (player_y),a
	ld a,e
	ld (player_x),a
	call light_arrive
	call update_view
	call monsters_see_all
	pop ix
	call mon_race
	pop hl
	jp take_hit
/* free_square - D = y, E = x -> carry if it's open, empty and not the
	player's */
free_square:
	call in_bounds
	ret nc
	ld a,(player_y)
	cp d
	jr nz,.not_player
	ld a,(player_x)
	cp e
	jr nz,.not_player
	or a
	ret
.not_player:
	call map_addr
	ld a,(hl)
	bit F_MON_BIT,a
	jr nz,.no
	and TERRAIN_MASK
	call terrain_flags
	bit TF_PASSABLE,a
	jr z,.no
	scf
	ret
.no:
	or a
	ret
wall_msgs:	dw mcm_collapses, mcm_floor_turns, mcm_pummeled

/* mc_cut - HL = how much worse the cut gets (cut_player) */
mc_cut:
	push ix
	OVCALL PAGE_MAGIC, cut_player, PAGE_MCAST
	pop ix
	ret
/* mc_stun - A = how much more stunned (stun_player) */
mc_stun:
	push ix
	OVCALL PAGE_MAGIC, stun_player, PAGE_MCAST
	pop ix
	ret
/* resists_chaos - NZ if TR_RES_CHAOS */
resists_chaos:
	ld a,(p_eflags2+2)
	and TR2_RES_CHAOS
	ret

; ---------------------------------------------------------------- the bigger summons

mc_summon_mighty:						; 73: 10 ringwraiths, then 7 greater
	ld hl,mz_mighty_undead				; undead, carrying on from them
	ld bc,10*256+SUM_WRAITH
	call summon
	ld b,7
	ld c,SUM_GUNDEAD
	jp summon_more
mc_summon_reptiles:						; 76
	ld hl,mz_reptiles
	ld bc,8*256+SUM_REPTILE
	jp summon
mc_summon_ants:							; 77
	ld hl,mz_ants
	ld bc,7*256+SUM_ANT
	jp summon
mc_summon_uniques:						; 78: 5 uniques, 4 jabberwocks
	ld hl,mz_special
	ld bc,5*256+SUM_UNIQUE
	call summon
	ld b,4
	ld c,SUM_JABBERWOCK
	jp summon_more

/* mx_say, mx_print - mc_say and msg_print for HL = a message kept in the
	monster text page (src/mcast_text.asm), copied out first */
mx_say:
	call mx_text
	jp mc_say
mx_print:
	call mx_text
	jp msg_print
mx_text:
	nextreg NR_MMU1,MTEXT_PAGE
	ld de,mx_buf
.copy:
	ld a,(hl)
	ld (de),a
	inc hl
	inc de
	or a
	jr nz,.copy
	ld hl,mx_buf
	ret

mx_buf:				ds 48
mc_base:			dw 0
mc_trapdam:			dw 0
