/* mcast.asm - monsters casting spells (overlay page PAGE_MCAST)
	References: CREATURE.C mon_cast_spell, SPELLS.C bolt/breath/
	teleport_away/teleport_to, MORIA1.C fire_dam/cold_dam/light_dam/
	acid_dam/poison_gas/minus_ac, MISC2.C inven_damage/player_saves,
	SETS.C (what each element destroys).
	9d-3a: the classic spells (casts 5-32), the bolts, balls, mind blasts,
	healing, hasting and summoning; the exotic breaths and the rest (33-38,
	42, 51, 53, 54, 57, 59, 60, 64-78) are 9d-3b's, and until then a
	monster that picks one moves instead.
	Convention: IX = the caster throughout; anything that needs IX for
	something else saves it.
 */

/* mon_cast_spell - IX = monster, IY = its race (paged): 1 in freq it
	casts one of its spells at the player, if within MAX_SPELL_DIS and in
	line of sight (mon_cast_spell in CREATURE.C) -> carry if it took its
	turn */
mon_cast_spell:
	ld a,(iy+R_LEVEL)					; what the casting needs of the race
	ld (mc_level),a
	ld a,(iy+R_SPEED)
	ld (mc_rspeed),a
	ld d,(iy+R_HD_DICE)
	ld e,(iy+R_HD_SIDES)
	mul d,e
	ld (mc_hd),de
	ld l,(ix+M_RACE)					; its spells: mspell_table + race * 12
	ld h,(ix+M_RACE_HI)
	ld d,h
	ld e,l
	add hl,hl
	add hl,de
	add hl,hl
	add hl,hl
	ld de,mspell_table
	add hl,de
	nextreg NR_MMU1,MSPELL_PAGE
	ld de,mc_rec
	ld bc,MS_SIZE
	ldir
	call mon_race
	ld a,(mc_rec)						; 1 in freq
	and CS_FREQ
	jp z,.no
	call randint
	cp 1
	jp nz,.no
	ld a,(ix+M_CDIS)
	cp MAX_SPELL_DIS+1
	jp nc,.no
	ld d,(ix+M_Y)
	ld e,(ix+M_X)
	call los
	jp nc,.no
	call update_mon						; it's casting: is it seen?
	ld a,(ix+M_RACE)
	ld (killer_race),a
	ld a,(ix+M_RACE_HI)
	ld (killer_race+1),a
	call desperate
	ld a,(mc_rec)						; the frequency isn't a spell
	and $F0
	ld (mc_rec),a
	xor a								; every spell it has, as a list
	ld (mc_k),a
	ld c,a								; C = the bit: cast C+1
	ld hl,mc_rec
.byte:
	ld a,(mc_desp)						; desperate: only the escapes
	or a
	ld a,(hl)
	jr z,.unmasked
	push hl
	ld de,mc_rec
	or a
	sbc hl,de
	ld de,int_masks
	add hl,de
	and (hl)
	pop hl
.unmasked:
	ld b,8
.bit:
	rra
	jr nc,.skip
	push af
	push hl
	ld a,(mc_k)
	ld hl,mc_choice
	add hl,a
	ld (hl),c
	inc a
	ld (mc_k),a
	pop hl
	pop af
.skip:
	inc c
	djnz .bit
	inc hl
	ld a,c
	cp MS_BITS
	jr c,.byte
	ld a,(mc_k)
	or a
	jr z,.no
	call randint
	ld hl,mc_choice-1
	add hl,a
	ld a,(hl)							; cast (A+1): its handler, 0 if none yet
	sub 4
	add a,a
	ld hl,mc_handlers
	add hl,a
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	or h
	jr z,.no
	call jp_hl_mc
	scf
	ret
.no:
	or a
	ret
jp_hl_mc:
	jp (hl)

/* desperate - an intelligent monster below a tenth of its hit dice, with
	an escape among its spells: half the time, mc_desp = 1 */
desperate:
	xor a
	ld (mc_desp),a
	ld a,(mc_rec+MS_FLAGS)
	bit RS_SMART,a
	ret z
	ld hl,(mc_hd)						; hp < hd[0] * hd[1] / 10
	ld c,10
	call div16_8
	ex de,hl
	ld l,(ix+M_HP)
	ld h,(ix+M_HP+1)
	bit 7,h
	jr nz,.low
	or a
	sbc hl,de
	ret nc
.low:
	ld hl,mc_rec						; CS_INT1 or CS_INT2 among its spells
	ld de,int_masks
	ld b,8
.any:
	ld a,(de)
	and (hl)
	jr nz,.has
	inc hl
	inc de
	djnz .any
	ret
.has:
	ld a,2
	call randint
	cp 1
	ret nz
	ld (mc_desp),a
	ret
; CS_INT1, CS_INT2 and CS_INT3's low word, as bytes
int_masks:		db $20,$00,$06,$80, $00,$34,$02,$51, $00,$00

; casts 5-80 (bit 4 up): the handlers, 0 for those still to come (9d-3b)
mc_handlers:
	dw mc_blink, mc_teleport, mc_tele_to, mc_light_wound			; 5-8
	dw mc_serious_wound, mc_hold, mc_blind, mc_confuse				; 9-12
	dw mc_fear, mc_summon_mon, mc_summon_undead, mc_slow			; 13-16
	dw mc_drain_mana, mc_summon_demon, mc_summon_dragon, mc_br_light ; 17-20
	dw mc_br_gas, mc_br_acid, mc_br_frost, mc_br_fire				; 21-24
	dw mc_fire_bolt, mc_frost_bolt, mc_acid_bolt, mc_mmissile		; 25-28
	dw mc_critical, mc_fire_ball, mc_frost_ball, mc_mana_bolt		; 29-32
	dw 0, 0, 0, 0, 0, 0												; 33-38
	dw mc_light_bolt, mc_light_ball, mc_acid_ball, 0				; 39-42
	dw mc_die, mc_stare, mc_tele_away, mc_heal						; 43-46
	dw mc_haste, mc_missiles, mc_plasma, mc_summon_mons				; 47-50
	dw 0, mc_ice_bolt, 0, 0, mc_glow_red, mc_stink, 0, mc_water_bolt ; 51-58
	dw 0, 0, mc_summon_angel, mc_summon_spiders, mc_summon_hounds	; 59-63
	dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0					; 64-78
	dw mc_summon_gundead, mc_summon_ancientd						; 79-80

; ---------------------------------------------------------------- 5-7

mc_blink:
	ld hl,mz_blinks
	call mc_say
	ld a,5
	jp mc_tport
mc_teleport:
	ld hl,mz_teleports
	call mc_say
	ld a,MAX_SIGHT
	jp mc_tport
mc_tele_to:
	ld hl,mz_commands
	call mc_say
	jp tele_to
mc_tele_away:							; 45
	ld hl,mz_teleports_you
	call mc_say
	push ix
	ld hl,100
	OVCALL PAGE_SCROLL, teleport, PAGE_MCAST
	pop ix
	ret

; ---------------------------------------------------------------- curses

mc_light_wound:
	ld hl,mz_curses
	ld bc,3*256+8
	jr wound
mc_serious_wound:
	ld hl,mz_curses_horribly
	ld bc,8*256+8
	jr wound
mc_critical:							; 29
	ld hl,mz_incanting
	ld bc,10*256+15
/* wound - HL = what it does, B/C = damage dice, unless the player saves */
wound:
	push bc
	call mc_say
	call player_saves
	pop bc
	ld hl,mcm_resist_spell
	jp c,msg_print
	call damroll
	jp take_hit

mc_die:									; 43
	ld hl,mz_scream_die
	call mc_say
	call player_saves
	ld hl,mcm_laugh
	jp c,msg_print
	ld hl,mcm_bleed
	call msg_print
	ld bc,15*256+15
	call damroll
	call take_hit
	ld l,(ix+M_HP)						; cut_player(m_ptr->hp)
	ld h,(ix+M_HP+1)
	push ix
	OVCALL PAGE_MAGIC, cut_player, PAGE_MCAST
	pop ix
	ret

mc_stare:								; 44
	ld hl,mz_stares
	call mc_say
	call player_saves
	ld hl,mcm_resist_effects
	jp c,msg_print
	ld hl,mcm_mind_blasted
	call msg_print
	call confuse_unless
	ld bc,8*256+8
	call damroll
	jp take_hit

mc_glow_red:							; 55
	ld hl,mz_glow_red
	call mc_say
	call player_saves
	ld hl,mcm_avert
	jp c,msg_print
	ld hl,mcm_mind_blasted
	call msg_print
	ld bc,12*256+15
	call damroll
	call take_hit
	call confuse_unless
	ld a,(p_eflags+2)
	bit EF2_FREE_ACT,a
	jr nz,.blind
	call paralyse
	call slow_more
.blind:
	call blind_resist
	ret nz
	jp blind_more

; ---------------------------------------------------------------- hold, blind, confuse, fear, slow

mc_hold:
	ld hl,mz_gazes
	call mc_say
	ld a,(p_eflags+2)
	bit EF2_FREE_ACT,a
	ld hl,mcm_unaffected
	jp nz,msg_print
	call player_saves
	ld hl,mcm_stare_back
	jp c,msg_print
/* paralyse - paralysed 2 more turns, or 1d5 + 4 */
paralyse:
	ld hl,p_paralysed
	ld a,(hl)
	or a
	jr z,.fresh
	add a,2
	jr nc,$+4
	ld a,255
	ld (hl),a
	ret
.fresh:
	ld a,5
	call randint
	add a,4
	ld (p_paralysed),a
	ret

mc_blind:
	ld hl,mz_burning
	call mc_say
	call player_saves
	jr c,.clears
	call blind_resist
	jr z,blind_more
.clears:
	ld hl,mcm_vision_clears
	jp msg_print
/* blind_more - blind 6 more turns, or 12 + 1d3 */
blind_more:
	ld hl,(p_blind)
	ld a,h
	or l
	ld a,6
	jr nz,.add
	ld a,3
	call randint
	add a,12
	ld hl,(p_blind)
.add:
	add hl,a
	ld (p_blind),hl
	ret
/* blind_resist - NZ if the player can't be blinded: a dwarf, or
	TR_RES_BLIND */
blind_resist:
	ld a,(p_race)
	cp RACE_DWARF
	jr nz,.worn
	or a								; (NZ: dwarves are never 0)
	ret
.worn:
	ld a,(p_eflags2+2)
	and TR2_RES_BLIND
	ret

mc_confuse:
	ld hl,mz_mesmerising
	call mc_say
	call player_saves
	jr c,.disbelieve
	call confuse_resist
	jr z,confuse_more
.disbelieve:
	ld hl,mcm_disbelieve
	jp msg_print
/* confuse_unless - confused, unless the player resists confusion or chaos */
confuse_unless:
	call confuse_resist
	ret nz
/* confuse_more - confused 2 more turns, or 1d5 + 3 */
confuse_more:
	ld hl,p_confused
	jr more_or_new
/* confuse_resist - NZ if TR_RES_CONF or TR_RES_CHAOS */
confuse_resist:
	ld a,(p_eflags2+1)
	and TR2_RES_CONF
	ret nz
	ld a,(p_eflags2+2)
	and TR2_RES_CHAOS
	ret

mc_fear:
	ld hl,mz_fearful
	call mc_say
	call player_saves
	ld hl,mcm_not_frightened
	jp c,msg_print
	ld hl,p_afraid
	jr more_or_new

mc_slow:
	ld hl,mz_drains_power
	call mc_say
	ld a,(p_eflags+2)
	bit EF2_FREE_ACT,a
	ld hl,mcm_unaffected
	jp nz,msg_print
	call player_saves
	ld hl,mcm_body_resists
	jp c,msg_print
/* slow_more - slowed 2 more turns, or 1d5 + 3 */
slow_more:
	ld hl,p_slow
/* more_or_new - HL = a timer: 2 more turns if it's running, else 1d5 + 3 */
more_or_new:
	ld e,(hl)
	inc hl
	ld d,(hl)
	ld a,d
	or e
	ld a,2
	jr nz,.add
	push hl
	ld a,5
	call randint
	add a,3
	pop hl
	ld de,0
.add:
	add de,a
	ld (hl),d
	dec hl
	ld (hl),e
	ret

; ---------------------------------------------------------------- 17, 46, 47

mc_drain_mana:
	ld hl,(p_cmana)						; nothing to draw on: nothing said
	ld a,h
	or l
	ret z
	ld hl,mz_psychic
	call mc_say
	ld a,(ix+M_ML)
	or a
	ld hl,mz_appears_healthier
	call nz,mc_say
	ld a,(mc_level)						; r1 = 1d(level) / 2 + 1
	or a
	jr z,.one
	call randint
	srl a
.one:
	inc a
	ld e,a
	ld d,0
	ld hl,(p_cmana)
	or a
	sbc hl,de
	jr nc,.enough
	ld de,(p_cmana)						; all of it
	ld hl,0
	ld (p_cmana_frac),hl
.enough:
	ld (p_cmana),hl
	ld d,6								; hp += 6 * r1 (no limit)
	mul d,e
	ld l,(ix+M_HP)
	ld h,(ix+M_HP+1)
	add hl,de
	ld (ix+M_HP),l
	ld (ix+M_HP+1),h
	ret

mc_heal:								; 46
	ld hl,mz_concentrates
	call mc_say
	ld l,(ix+M_HP)
	ld h,(ix+M_HP+1)
	ld e,(ix+M_MAXHP)
	ld d,(ix+M_MAXHP+1)
	push hl
	or a
	sbc hl,de
	pop hl
	jr c,.heal
	ld hl,mz_as_healthy
	jp mc_say
.heal:
	push de
	ld a,(mc_level)						; hp += level * 6, up to maxhp
	ld e,a
	ld d,6
	mul d,e
	add hl,de
	pop de
	push hl
	or a
	sbc hl,de
	pop hl
	jr c,.below
	ex de,hl
.below:
	ld (ix+M_HP),l						; (carry: still below maxhp)
	ld (ix+M_HP+1),h
	ld hl,mz_looks_healthier
	jr c,$+5
	ld hl,mz_really_healthy
	jp mc_say

mc_haste:								; 47
	ld hl,mz_casts_spell
	call mc_say
	ld a,(mc_rspeed)					; cspeed <= speed - 10 + py speed
	sub 10
	ld hl,p_speed
	add a,(hl)
	ld b,a
	ld a,(ix+M_SPEED)
	sub b
	jr z,.ok
	ret p
.ok:
	ld a,(mc_rspeed)					; and speed <= 15
	cp 16
	ret nc
	inc (ix+M_SPEED)
	ld hl,mz_faster
	jp mc_say

; ---------------------------------------------------------------- breaths

mc_br_light:
	ld hl,mz_br_lightning
	ld a,GF_LIGHTNING
	jr breathe
mc_br_gas:
	ld hl,mz_br_gas
	call mc_say
	ld de,800
	ld a,GF_POISON_GAS
	jr breathe_capped
mc_br_acid:
	ld hl,mz_br_acid
	ld a,GF_ACID
	jr breathe
mc_br_frost:
	ld hl,mz_br_frost
	ld a,GF_FROST
	jr breathe
mc_br_fire:
	ld hl,mz_br_fire
	ld a,GF_FIRE
/* breathe - HL = what it does, A = element: hp / 3 of it, up to 1600 */
breathe:
	push af
	call mc_say
	pop af
	ld de,1600
breathe_capped:
	push af
	push de
	ld l,(ix+M_HP)
	ld h,(ix+M_HP+1)
	ld c,3
	call div16_8
	pop de
	push hl
	or a
	sbc hl,de
	pop hl
	jr c,$+3
	ex de,hl
	pop af
	jp mon_ball

; ---------------------------------------------------------------- balls

mc_fire_ball:
	ld hl,mz_fire_ball
	ld de,7*256+10						; 1d(level * 7 / 2) + 10
	ld a,GF_FIRE
	jr ball_spell
mc_frost_ball:
	ld hl,mz_frost_ball
	ld de,3*256+10						; 1d(level * 3 / 2) + 10
	ld a,GF_FROST
	jr ball_spell
mc_light_ball:
	ld hl,mz_light_ball
	ld de,3*256+8
	ld a,GF_LIGHTNING
	jr ball_spell
mc_acid_ball:
	ld hl,mz_acid_ball
	ld de,6*256+15						; 1d(level * 3) + 15
	ld a,GF_ACID
/* ball_spell - HL = what it does, A = element, D = level multiplier (in
	halves), E = added: a ball of 1d(level * D / 2) + E */
ball_spell:
	push af
	push de
	call mc_say
	pop de
	push de
	ld a,(mc_level)
	ld e,a
	mul d,e
	srl d
	rr e
	ex de,hl
	call rand_or_0
	pop de
	ld a,e
	add hl,a
	pop af
	jp mon_ball
mc_stink:								; 56
	ld hl,mz_stinking
	call mc_say
	ld bc,12*256+2
	call damroll
	ld a,GF_POISON_GAS
	jp mon_ball

/* rand_or_0 - HL = n -> HL = 1dn (0 when n is 0) */
rand_or_0:
	ld a,h
	or l
	ret z
	jp randint16

; ---------------------------------------------------------------- bolts

mc_fire_bolt:
	ld hl,mz_fire_bolt
	ld bc,9*256+8
	ld a,GF_FIRE
	jr bolt_third
mc_frost_bolt:
	ld hl,mz_frost_bolt
	ld bc,6*256+8
	ld a,GF_FROST
	jr bolt_third
mc_acid_bolt:
	ld hl,mz_acid_bolt
	ld bc,7*256+8
	ld a,GF_ACID
	jr bolt_third
mc_mmissile:
	ld hl,mz_mmissile
	ld bc,2*256+6
	ld a,GF_MAGIC_MISSILE
	jr bolt_third
mc_light_bolt:							; 39
	ld hl,mz_light_bolt
	ld bc,4*256+8
	ld a,GF_LIGHTNING
/* bolt_third - HL = what it does, A = element, B/C = dice: a bolt of
	the dice + level / 3 */
bolt_third:
	push af
	push bc
	call mc_say
	pop bc
	call damroll
	ld a,(mc_level)
	ld c,3
	call div8
	add hl,a
	pop af
	jp mon_bolt
mc_mana_bolt:							; 32: 1d(level * 7 / 2) + 50
	ld hl,mz_mana_bolt
	call mc_say
	ld a,(mc_level)
	ld e,a
	ld d,7
	mul d,e
	srl d
	rr e
	ex de,hl
	call rand_or_0
	ld a,50
	add hl,a
	ld a,GF_MAGIC_MISSILE
	jp mon_bolt
mc_missiles:							; 48: 6d7
	ld hl,mz_missiles
	call mc_say
	ld bc,6*256+7
	call damroll
	ld a,GF_MAGIC_MISSILE
	jp mon_bolt
mc_plasma:								; 49: 10 + 8d7 + level
	ld hl,mz_plasma
	call mc_say
	ld bc,8*256+7
	call damroll
	ld a,(mc_level)
	add a,10
	add hl,a
	ld a,GF_MAGIC_MISSILE
	jp mon_bolt
mc_ice_bolt:							; 52: 6d6 + level of frost; then
	ld hl,mz_ice_bolt					; 8d10, stunned and cut
	call mc_say
	ld bc,6*256+6
	call damroll
	ld a,(mc_level)
	add hl,a
	ld a,GF_FROST
	call mon_bolt
	ret nc
	ld bc,8*256+10
	call damroll
	call take_hit
	ld a,25
	call stun_unless
	ld a,10
	call randint
	ld l,a
	ld h,0
	push ix
	OVCALL PAGE_MAGIC, cut_player, PAGE_MCAST
	pop ix
	ret
mc_water_bolt:							; 58: 10d10 + level; stunned
	ld hl,mz_water_bolt
	call mc_say
	ld bc,10*256+10
	call damroll
	ld a,(mc_level)
	add hl,a
	ld a,GF_MAGIC_MISSILE
	call mon_bolt
	ret nc
	ld a,15
/* stun_unless - A = n: stunned 1dn more, unless the player resists sound */
stun_unless:
	ld b,a
	ld a,(p_eflags2+2)
	and TR2_RES_SOUND
	ret nz
	ld a,b
	call randint
	push ix
	OVCALL PAGE_MAGIC, stun_player, PAGE_MCAST
	pop ix
	ret

; ---------------------------------------------------------------- summons

mc_summon_mon:
	ld hl,mz_summons_help
	ld bc,1*256+SUM_MONSTER
	jr summon
mc_summon_undead:
	ld hl,mz_beyond_grave
	ld bc,1*256+SUM_UNDEAD
	jr summon
mc_summon_demon:
	ld hl,mz_hellish
	ld bc,1*256+SUM_DEMON
	jr summon
mc_summon_dragon:
	ld hl,mz_a_dragon
	ld bc,1*256+SUM_DRAGON
	jr summon
mc_summon_mons:							; 50
	ld hl,mz_summons_monsters
	ld bc,8*256+SUM_MONSTER
	jr summon
mc_summon_angel:
	ld hl,mz_an_angel
	ld bc,1*256+SUM_ANGEL
	jr summon
mc_summon_spiders:
	ld hl,mz_spiders
	ld bc,6*256+SUM_SPIDER
	jr summon
mc_summon_hounds:
	ld hl,mz_hounds
	ld bc,8*256+SUM_HOUND
	jr summon
mc_summon_gundead:						; 79
	ld hl,mz_the_dead
	ld bc,8*256+SUM_GUNDEAD
	jr summon
mc_summon_ancientd:						; 80
	ld hl,mz_ancient_dragons
	ld bc,5*256+SUM_ANCIENTD
/* summon - HL = what it does, B = how many, C = SUM_ kind: each one
	appears next to the last one that did, starting at the player (the C's
	y and x, which the summon_ functions move) */
summon:
	push bc
	call mc_say
	pop bc
	ld a,c
	ld (mc_sum_kind),a
	ld a,(player_y)
	ld (mc_sy),a
	ld a,(player_x)
	ld (mc_sx),a
	push ix
.each:
	push bc
	ld a,(mc_sy)
	ld d,a
	ld a,(mc_sx)
	ld e,a
	ld a,(mc_level)						; (demons: up to the caster's level)
	ld l,a
	ld a,(mc_sum_kind)
	OVCALL PAGE_LEVEL, summon_by, PAGE_MCAST
	jr nc,.next
	ld a,d
	ld (mc_sy),a
	ld a,e
	ld (mc_sx),a
.next:
	pop bc
	djnz .each
	call monsters_see_all				; (update_mon for the new ones)
	pop ix
	jp mon_race

; ---------------------------------------------------------------- the player's saving throw

/* player_saves - carry if the player saves: 1d100 <= save + stat_adj(WIS)
	+ class_level_adj[CLA_SAVE] * lev / 3 (MISC2.C). Clobbers all but IX */
player_saves:
	ld a,(p_cla_save)
	ld e,a
	ld a,(p_lev)
	ld d,a
	mul d,e
	ex de,hl
	ld c,3
	call div16_8
	push hl
	ld a,(p_stat_use+A_WIS)
	ld hl,wis_adj
	call threshold
	pop hl
	add hl,a
	ld a,(p_save)						; (signed)
	ld e,a
	rla
	sbc a,a
	ld d,a
	add hl,de
	bit 7,h
	jr z,.roll
	or a
	ret
.roll:
	push hl
	ld a,100
	call randint
	pop hl
	ld e,a
	ld d,0
	or a
	sbc hl,de
	ccf
	ret
; stat_adj (MISC2.C): (limit, result) - the result for a stat below the limit
wis_adj:	db 8,0, 15,1, 18,2, 68,3, 88,4, 108,5, 118,6, 119,7, 129,8, 139,9
			db 149,10, 159,11, 169,12, 179,13, 189,14, 199,15, 219,16, 229,18, 255,20

; ---------------------------------------------------------------- saying it

/* mc_say - HL = text: "The Orc <text>", "Grip, Farmer Maggot's Dog
	<text>" or "It <text>" when the player can't see it */
mc_say:
	push hl
	call mon_race
	call msg_begin
	ld a,1
	ld (name_cap),a
	call mon_name_to_msg
	ld hl,txt_space
	call msg_add
	pop hl
	call msg_add
	jp msg_end

; ---------------------------------------------------------------- teleporting

/* mc_tport - IX = monster, A = distance: somewhere open that far off, 5
	more every 10 tries (teleport_away in SPELLS.C) */
mc_tport:
	ld (mc_tdis),a
	xor a
	ld (mc_tries),a
.try:
	ld a,(mc_tdis)						; yn = fy + 1d(2*dis+1) - (dis+1)
	call mc_offset
	add a,(ix+M_Y)
	ld d,a
	push de
	ld a,(mc_tdis)
	call mc_offset
	pop de
	add a,(ix+M_X)
	ld e,a
	call in_bounds
	jr nc,.try
	ld hl,mc_tries
	inc (hl)
	ld a,(hl)
	cp 10
	jr c,.check
	ld (hl),0
	ld a,(mc_tdis)
	add a,5
	cp 128
	jr nc,.check
	ld (mc_tdis),a
.check:
	push de
	call map_addr
	pop de
	ld a,(hl)
	bit F_MON_BIT,a
	jr nz,.try
	and TERRAIN_MASK
	call terrain_flags
	bit TF_PASSABLE,a
	jr z,.try
	ld a,(player_y)
	cp d
	jr nz,.go
	ld a,(player_x)
	cp e
	jr z,.try
.go:
	set F_MON_BIT,(hl)
	push de
	ld d,(ix+M_Y)
	ld e,(ix+M_X)
	call map_addr
	res F_MON_BIT,(hl)
	pop de
	ld (ix+M_Y),d
	ld (ix+M_X),e
	ld (ix+M_ML),0
	call mon_distance
	ld (ix+M_CDIS),a
	jp update_mon

/* mc_offset - A = dis (up to 127) -> A = 1d(2*dis+1) - (dis+1), signed */
mc_offset:
	ld c,a
	add a,a
	inc a
	push bc
	call randint
	pop bc
	sub c
	dec a
	ret

/* tele_to - the player lands next to monster IX, further off every 10
	tries (teleport_to in SPELLS.C; the C checks the wrong square for the
	edge of the map, this checks the right one) */
tele_to:
	ld a,1
	ld (mc_tdis),a
	xor a
	ld (mc_tries),a
.try:
	ld a,(mc_tdis)
	call mc_offset
	add a,(ix+M_Y)
	ld d,a
	push de
	ld a,(mc_tdis)
	call mc_offset
	pop de
	add a,(ix+M_X)
	ld e,a
	call in_bounds
	jr nc,.try
	ld hl,mc_tries
	inc (hl)
	ld a,(hl)
	cp 10
	jr c,.check
	ld (hl),0
	ld hl,mc_tdis
	inc (hl)
.check:
	push de
	call map_addr
	pop de
	ld a,(hl)
	bit F_MON_BIT,a						; (the player's own square will do)
	jr nz,.try
	and TERRAIN_MASK
	call terrain_flags
	bit TF_PASSABLE,a
	jr z,.try
	push ix
	push de
	call lamp_off
	pop de
	ld a,d
	ld (player_y),a
	ld a,e
	ld (player_x),a
	call light_arrive
	call update_view
	call monsters_see_all
	pop ix
	jp mon_race

; ---------------------------------------------------------------- bolts and balls

/* mon_bolt - IX = caster, A = GF_ element, HL = damage: a bolt along the
	line to the player, stopping at the first monster on the way, which
	takes it instead (bolt in SPELLS.C) -> carry if it hit the player */
mon_bolt:
	ld (mc_gf),a
	ld (mc_dam),hl
	xor a
	ld (mc_ball),a
	ld a,(player_y)
	sub (ix+M_Y)
	ld (mc_dy),a
	call abs_a
	ld b,a
	ld a,(player_x)
	sub (ix+M_X)
	ld (mc_dx),a
	call abs_a
	cp b
	jr nc,$+3
	ld a,b
	ld (mc_step),a						; the longer of the two
	ld a,1
	ld (mc_n),a
.step:									; square n: fy + n * dy / step (floored)
	ld a,(mc_dy)
	call mc_frac
	add a,(ix+M_Y)
	ld (mc_sq+1),a
	ld a,(mc_dx)
	call mc_frac
	add a,(ix+M_X)
	ld (mc_sq),a
	ld de,(mc_sq)
	call in_bounds
	jr nc,.next
	call los
	jr nc,.next
	ld de,(mc_sq)
	ld a,(player_y)
	cp d
	jr nz,.not_player
	ld a,(player_x)
	cp e
	jr z,.player
.not_player:
	call map_addr
	ld a,(hl)
	and TERRAIN_MASK
	call terrain_flags
	bit TF_PASSABLE,a
	jr z,.next
	bit F_MON_BIT,(hl)
	jr z,.next
	ld de,(mc_sq)						; something in the way
	push ix
	call mon_at
	jr nc,.gone
	ld hl,(mc_dam)
	call mc_harm
	call mc_hurt_mon
.gone:
	pop ix
	or a
	ret
.next:
	ld hl,mc_n
	ld a,(hl)
	inc (hl)
	ld hl,mc_step
	cp (hl)
	jr c,.step
	or a
	ret
.player:
	ld hl,(mc_dam)
	ld a,h
	or l
	jr nz,$+3
	inc hl
	ld a,(mc_gf)
	call el_damage
	scf
	ret

/* abs_a - A = |A| */
abs_a:
	or a
	ret p
	neg
	ret

/* mc_frac - A = delta (signed) -> A = n * delta / step, rounded down */
mc_frac:
	bit 7,a
	jr z,.plus
	neg
	call .times
	ld a,(mc_step)
	dec a
	add hl,a							; (rounding away from zero)
	call .divide
	neg
	ret
.plus:
	call .times
.divide:
	ld a,(mc_step)
	ld c,a
	call div16_8
	ld a,l
	ret
.times:
	ld e,a
	ld a,(mc_n)
	ld d,a
	mul d,e
	ex de,hl
	ret

/* mon_ball - IX = caster, A = GF_ element, HL = damage: a ball of radius
	2 centred on the player, damage / (distance + 1) to each monster in it
	(but the caster) and everything burnable on the floor destroyed
	(breath in SPELLS.C) */
mon_ball:
	ld (mc_gf),a
	ld (mc_dam),hl
	ld (mc_caster),ix
	ld a,1
	ld (mc_ball),a
	ld a,-2
	ld (mc_by),a
.row:
	ld a,-2
	ld (mc_bx),a
.col:
	call ball_square
	ld hl,mc_bx
	inc (hl)
	ld a,(hl)
	cp 3
	jr nz,.col
	ld hl,mc_by
	inc (hl)
	ld a,(hl)
	cp 3
	jr nz,.row
	ld ix,(mc_caster)
	jp mon_race
ball_square:
	ld a,(player_y)
	ld hl,mc_by
	add a,(hl)
	ld d,a
	ld a,(player_x)
	ld hl,mc_bx
	add a,(hl)
	ld e,a
	ld (mc_sq),de
	call in_bounds
	ret nc
	call mon_distance
	cp 3
	ret nc
	ld (mc_bdist),a
	ld de,(mc_sq)
	call los
	ret nc
	call floor_destroy
	ld de,(mc_sq)
	call map_addr
	ld a,(hl)
	and TERRAIN_MASK
	call terrain_flags
	bit TF_PASSABLE,a
	ret z
	ld a,(mc_bdist)
	or a
	jr z,.player
	bit F_MON_BIT,(hl)
	ret z
	ld de,(mc_sq)
	call mon_at
	ret nc
	push ix								; (not the caster)
	pop hl
	ld de,(mc_caster)
	or a
	sbc hl,de
	ret z
	ld hl,(mc_dam)
	call mc_harm
	ld a,(mc_bdist)
	inc a
	ld c,a
	call div16_8
	jp mc_hurt_mon
.player:
	ld ix,(mc_caster)
	ld hl,(mc_dam)						; at least 1, at most 1600
	ld a,h
	or l
	jr nz,$+3
	inc hl
	ld de,1601
	or a
	sbc hl,de
	add hl,de
	jr c,$+5
	ld hl,1600
	ld a,(mc_gf)
	jp el_damage

/* mc_harm - IX = a monster, HL = damage -> HL = a ninth of it if it
	shrugs off the element. Leaves IY on its race */
mc_harm:
	push hl
	call mon_race
	ld a,(mc_gf)
	ld hl,gf_resist
	add hl,a
	ld a,(hl)
	pop hl
	and (iy+R_RESIST)
	ret z
	ld c,9
	jp div16_8
gf_resist:	db 0, 1<<RR_LIGHTNING, 1<<RR_POISON, 1<<RR_ACID, 1<<RR_FROST, 1<<RR_FIRE

/* mc_hurt_mon - IX = a monster (IY its race), HL = damage: it wakes; if
	it dies it's gone, no experience (a unique caught in a ball is left
	at 0 hit points instead) */
mc_hurt_mon:
	ex de,hl
	ld l,(ix+M_HP)
	ld h,(ix+M_HP+1)
	or a
	sbc hl,de
	ld (ix+M_SLEEP),0
	ld (ix+M_SLEEP+1),0
	bit 7,h
	jr z,.alive
	ld a,(mc_ball)
	or a
	jp z,mon_remove
	bit RF_UNIQUE,(iy+R_FLAGS)
	jp z,mon_remove
	ld hl,0
.alive:
	ld (ix+M_HP),l
	ld (ix+M_HP+1),h
	ret

/* floor_destroy - mc_sq: what the element destroys there goes (the
	destroy sets of get_flags in SPELLS.C): a floor item, or a door */
floor_destroy:
	ld a,(mc_gf)
	add a,a
	ld hl,gf_floor_set
	add hl,a
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	or h
	ret z
	ld (mc_set),hl
	ld de,4								; does it burn doors?
	add hl,de
	ld a,(hl)
	or a
	jr z,.item
	ld de,(mc_sq)
	call map_addr
	ld a,(hl)
	and TERRAIN_MASK
	cp T_DOOR_CLOSED
	jr z,.door
	cp T_DOOR_OPEN
	jr nz,.item
.door:
	ld a,(hl)
	and $FF-TERRAIN_MASK
	or T_CORRIDOR
	ld (hl),a
.item:
	push ix
	ld de,(mc_sq)
	call item_at
	jr nc,.done
	ld a,(ix+I_KIND_HI)
	cp KIND_GOLD
	jr z,.done
	ld hl,(mc_set)
	call set_test
	jr nc,.done
	ld (ix+I_KIND_HI),ITEM_EMPTY
.done:
	pop ix
	ret
gf_floor_set:	dw 0, set_lightning, 0, set_acid_destroy, set_frost, set_fire_destroy

; ---------------------------------------------------------------- elements and the player

/* el_damage - A = GF_ element, HL = damage: the player takes it */
el_damage:
	add a,a
	ld de,el_table
	add de,a
	ex de,hl
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	ex de,hl
	push de
	ret
el_table:	dw take_hit, el_light, el_poison, el_acid, el_cold, el_fire

/* div3 - HL = HL / 3. Clobbers A, BC */
div3:
	ld c,3
	jp div16_8

/* el_fire - HL = damage of fire (fire_dam in MORIA1.C) */
el_fire:
	ld a,(p_eflags+2)
	bit EF2_RES_FIRE,a
	call nz,div3
	ld de,(p_resist_heat)
	ld a,d
	or e
	call nz,div3
	ld a,(p_eflags2)
	and TR2_IM_FIRE
	jr z,$+5
	ld hl,1
	call take_hit
	ld hl,set_flammable
	ld a,3
	call inven_damage
	ret z
	ld hl,mcm_smoke
	jp msg_print

/* el_cold - HL = damage of cold (cold_dam) */
el_cold:
	ld a,(p_eflags+2)
	bit EF2_RES_COLD,a
	call nz,div3
	ld de,(p_resist_cold)
	ld a,d
	or e
	call nz,div3
	ld a,(p_eflags2)
	and TR2_IM_COLD
	jr z,$+5
	ld hl,1
	call take_hit
	ld hl,set_frost
	ld a,5
	call inven_damage
	ret z
	ld hl,mcm_shatters
	jp msg_print

/* el_light - HL = damage of lightning (light_dam) */
el_light:
	ld de,(p_resist_light)
	ld a,d
	or e
	call nz,div3
	ld a,(p_eflags+3)
	bit EF3_RES_LIGHT,a
	call nz,div3
	ld a,(p_eflags2+1)
	and TR2_IM_LIGHT
	jr z,$+5
	ld hl,1
	jp take_hit

/* el_acid - HL = damage of acid: armour may take it instead (acid_dam) */
el_acid:
	ld a,(p_eflags+2)
	bit EF2_RES_ACID,a
	call nz,div3
	ld de,(p_resist_acid)
	ld a,d
	or e
	call nz,div3
	ld a,(p_eflags2+1)
	and TR2_IM_ACID
	jr z,$+5
	ld hl,1
	ld (mc_edam),hl
	call minus_ac						; flag = 1 if the armour took it,
	ld a,0								; + 2 if resisting: dam / (flag + 1)
	adc a,a
	ld b,a
	ld a,(p_eflags+2)
	bit EF2_RES_ACID,a
	jr z,$+4
	inc b
	inc b
	inc b
	ld c,b
	ld hl,(mc_edam)
	call div16_8
	call take_hit
	ld hl,set_acid_affect
	ld a,3
	call inven_damage
	ret z
	ld hl,mcm_acrid
	jp msg_print

/* el_poison - HL = damage of poison gas: poisoned too, unless resisting
	(poison_gas) */
el_poison:
	ld de,(p_resist_poison)				; resisting for now: 2/3
	ld a,d
	or e
	jr z,.worn
	add hl,hl
	call div3
.worn:
	ld a,(p_eflags+3)					; resisting poison: 3/5
	bit EF3_POISON,a
	jr z,.immune
	ld d,h
	ld e,l
	add hl,hl
	add hl,de
	ld c,5
	call div16_8
.immune:
	ld a,(p_eflags2+1)
	and TR2_IM_POISON
	jr z,$+5
	ld hl,1
	push hl
	call take_hit
	pop hl
	ld a,(p_eflags2+1)
	and TR2_IM_POISON
	ret nz
	ld a,(p_eflags+3)
	bit EF3_POISON,a
	ret nz
	ld de,(p_resist_poison)
	ld a,d
	or e
	ret nz
	call rand_or_0						; poisoned += 12 + 1d(dam)
	ld a,12
	add hl,a
	ld de,(p_poisoned)
	add hl,de
	ld (p_poisoned),hl
	ret

/* minus_ac - acid on a random piece of armour: it resists, or loses a
	point of AC (minus_ac in MORIA1.C) -> carry if it took the damage */
minus_ac:
	push ix
	ld hl,ac_slots
	ld de,mc_choice
	ld c,0
	ld b,6
.collect:
	push bc
	ld a,(hl)
	inc hl
	push hl
	push de
	ld e,a
	ld d,ITEM_SIZE
	mul d,e
	ld ix,EQUIP
	add ix,de
	pop de
	pop hl
	pop bc
	ld a,(ix+I_KIND_HI)
	cp ITEM_EMPTY
	jr z,.none
	dec hl
	ld a,(hl)
	inc hl
	ld (de),a
	inc de
	inc c
.none:
	djnz .collect
	ld a,c
	or a
	jr z,.no
	call randint
	ld hl,mc_choice-1
	add hl,a
	ld e,(hl)
	ld d,ITEM_SIZE
	mul d,e
	ld ix,EQUIP
	add ix,de
	call item_flags
	ld a,(it_flags+2)
	and TR1_RES_ACID
	ld hl,mz_resists_damage
	jr nz,.say
	call item_kind_addr					; ac + toac > 0
	ld a,(iy+K_AC)
	add a,(ix+I_TOAC)
	jr z,.no
	jp m,.no
	dec (ix+I_TOAC)
	ld hl,p_update
	set PU_BONUS,(hl)
	ld hl,mz_is_damaged
.say:
	push hl
	call msg_begin
	ld hl,mz_your
	call msg_add
	ld a,1
	ld (od_bare),a
	call objdes_msg
	xor a
	ld (od_bare),a
	pop hl
	call msg_add
	call msg_end
	pop ix
	scf
	ret
.no:
	pop ix
	or a
	ret
; the C's INVEN_BODY, ARM, OUTER, HANDS, HEAD, FEET
ac_slots:	db EQ_BODY, EQ_SHIELD, EQ_CLOAK, EQ_GLOVES, EQ_HELM, EQ_BOOTS

/* inven_damage - HL = a destroy set, A = percent: each pack item in the
	set may be destroyed, one of a stack (inven_damage in MISC2.C; like
	the C, the item that moves into a destroyed one's slot is passed over)
	-> A = how many, Z if none */
inven_damage:
	ld (mc_set),hl
	ld (mc_perc),a
	push ix
	xor a
	ld (mc_count),a
	ld (mc_slot),a
.loop:
	ld a,(mc_slot)
	cp PACK_MAX
	jr nc,.done
	call pack_slot
	ld a,(ix+I_KIND_HI)
	cp ITEM_EMPTY
	jr z,.done
	ld hl,(mc_set)
	call set_test
	jr nc,.next
	ld a,100							; 1d100 < percent
	call randint
	ld hl,mc_perc
	cp (hl)
	jr nc,.next
	ld a,(mc_slot)
	call use_one
	ld hl,mc_count
	inc (hl)
.next:
	ld hl,mc_slot
	inc (hl)
	jr .loop
.done:
	pop ix
	ld a,(mc_count)
	or a
	ret

/* set_test - IX = an item, HL = a destroy set -> carry if it's in it.
	A set: what guards an item (the byte and bit of the flags, then of
	flags2), whether it burns doors, then the tvals that are safe if
	guarded or an artifact, 0, then those that never are, 0 (SETS.C) */
set_test:
	push hl
	call item_kind_addr
	ld a,(iy+K_TVAL)
	ld (mc_tval),a
	pop hl
	push hl
	ld de,5
	add hl,de
	call in_list
	jr c,.guarded
	ld a,(mc_tval)
	call in_list
	pop hl
	ret
.guarded:
	call item_flags
	pop hl
	ld a,(hl)							; flags guard
	inc hl
	ld de,it_flags
	add de,a
	ld a,(de)
	and (hl)
	inc hl
	jr nz,.safe
	ld a,(hl)							; flags2 guard
	inc hl
	ld de,it_flags+4
	add de,a
	ld a,(de)
	and (hl)
	jr nz,.safe
	ld a,(ix+I_NAME2)					; artifacts are spared
	or a
	jr z,.burns
	call ego_addr
	bit EO_ARTIFACT,(iy+E_OPTS)
	jr nz,.safe
.burns:
	scf
	ret
.safe:
	or a
	ret
/* in_list - A = tval, HL = a 0-terminated list -> carry if it's there.
	HL ends past the 0 */
in_list:
	ld b,a
.look:
	ld a,(hl)
	inc hl
	or a
	ret z
	cp b
	jr nz,.look
.skip:
	ld a,(hl)
	inc hl
	or a
	jr nz,.skip
	scf
	ret

; the sets: guard (flags byte, mask, flags2 byte, mask), doors, guarded
; tvals, 0, unguarded tvals, 0
set_flammable:
	db 2,TR1_RES_FIRE, 0,TR2_IM_FIRE, 0
	db TV_ARROW,TV_BOW,TV_HAFTED,TV_POLEARM,TV_BOOTS,TV_GLOVES,TV_CLOAK,TV_SOFT_ARMOR,0
	db TV_STAFF,TV_SCROLL1,TV_SCROLL2,0
set_fire_destroy:
	db 2,TR1_RES_FIRE, 0,TR2_IM_FIRE, 1
	db TV_ARROW,TV_BOW,TV_HAFTED,TV_POLEARM,TV_BOOTS,TV_GLOVES,TV_CLOAK,TV_SOFT_ARMOR,0
	db TV_STAFF,TV_SCROLL1,TV_SCROLL2,TV_POTION1,TV_POTION2,TV_FLASK,TV_FOOD,0
set_frost:
	db 0,0, 0,0, 0
	db 0
	db TV_POTION1,TV_POTION2,TV_FLASK,0
set_acid_affect:
	db 2,TR1_RES_ACID, 1,TR2_IM_ACID, 0
	db TV_BOLT,TV_ARROW,TV_BOW,TV_HAFTED,TV_POLEARM,TV_BOOTS,TV_GLOVES,TV_CLOAK,TV_SOFT_ARMOR,0
	db TV_MISC,TV_CHEST,0
set_acid_destroy:
	db 2,TR1_RES_ACID, 1,TR2_IM_ACID, 1
	db TV_ARROW,TV_BOW,TV_HAFTED,TV_POLEARM,TV_BOOTS,TV_GLOVES,TV_CLOAK,TV_HELM
	db TV_SHIELD,TV_HARD_ARMOR,TV_SOFT_ARMOR,0
	db TV_SCROLL1,TV_SCROLL2,TV_FOOD,TV_STAFF,0
set_lightning:
	db 3,TR1_RES_LIGHT, 1,TR2_IM_LIGHT, 0
	db TV_RING,0
	db TV_WAND,TV_ROD,0

; ---------------------------------------------------------------- what they say

mz_blinks:			db "blinks away.",0
mz_teleports:		db "teleports away.",0
mz_commands:		db "commands you to return!",0
mz_teleports_you:	db "teleports you away.",0
mz_curses:			db "points at you and curses.",0
mz_curses_horribly: db "points at you and curses horribly.",0
mz_incanting:		db "points at you, incanting terribly!",0
mz_scream_die:		db "points at you, screaming the word DIE!",0
mz_stares:			db "stares at you.",0
mz_glow_red:		db "concentrates and its eyes glow red.",0
mz_gazes:			db "gazes deep into your eyes!",0
mz_burning:		db "casts a spell, burning your eyes!",0
mz_mesmerising:	db "creates a mesmerising illusion.",0
mz_fearful:		db "casts a fearful illusion.",0
mz_drains_power:	db "drains power from your muscles!",0
mz_psychic:		db "draws psychic energy from you!",0
mz_appears_healthier: db "appears healthier.",0
mz_concentrates:	db "concentrates on its wounds.",0
mz_as_healthy:		db "looks as healthy as can be.",0
mz_really_healthy:	db "looks REALLY healthy!",0
mz_looks_healthier: db "looks healthier.",0
mz_casts_spell:	db "casts a spell.",0
mz_faster:			db "starts moving faster.",0
mz_br_lightning:	db "breathes lightning.",0
mz_br_gas:			db "breathes gas.",0
mz_br_acid:		db "breathes acid.",0
mz_br_frost:		db "breathes frost.",0
mz_br_fire:		db "breathes fire.",0
mz_fire_bolt:		db "casts a Fire bolt.",0
mz_frost_bolt:		db "casts a Frost bolt.",0
mz_acid_bolt:		db "casts a Acid bolt.",0
mz_mmissile:		db "casts a Magic missile.",0
mz_mana_bolt:		db "casts a Mana bolt.",0
mz_light_bolt:		db "casts a Lightning bolt.",0
mz_missiles:		db "fires missiles at you.",0
mz_plasma:			db "casts a Plasma bolt.",0
mz_ice_bolt:		db "casts an Ice bolt.",0
mz_water_bolt:		db "casts a Water bolt.",0
mz_fire_ball:		db "casts a Fire ball.",0
mz_frost_ball:		db "casts a Frost ball.",0
mz_light_ball:		db "casts a Lightning ball.",0
mz_acid_ball:		db "casts an Acid ball.",0
mz_stinking:		db "casts a Stinking cloud.",0
mz_summons_help:	db "magically summons help!",0
mz_beyond_grave:	db "magically summons help from beyond the grave!",0
mz_hellish:		db "summons a hellish adversary!",0
mz_a_dragon:		db "magically summons a Dragon!",0
mz_summons_monsters: db "magically summons monsters!",0
mz_an_angel:		db "summons an Angel.",0
mz_spiders:		db "magically summons Spiders.",0
mz_hounds:			db "magically summons Hounds.",0
mz_the_dead:		db "summons the DEAD!",0
mz_ancient_dragons: db "summons Ancient Dragons.",0
mz_your:			db "Your ",0
mz_resists_damage:	db " resists damage!",0
mz_is_damaged:		db " is damaged!",0
mcm_resist_spell:	db "You resist the effects of the spell.",0
mcm_resist_effects:	db "You resist the effects.",0
mcm_laugh:			db "You laugh at the feeble spell.",0
mcm_bleed:			db "You start to bleed!",0
mcm_mind_blasted:	db "Your mind is blasted by psionic energy.",0
mcm_avert:			db "You avert your gaze!",0
mcm_unaffected:		db "You are unaffected.",0
mcm_stare_back:		db "You stare back unafraid!",0
mcm_vision_clears:	db "You blink and your vision clears.",0
mcm_disbelieve:		db "You disbelieve the feeble spell.",0
mcm_not_frightened:	db "You refuse to be frightened.",0
mcm_body_resists:	db "Your body resists the spell.",0
mcm_smoke:			db "There is smoke coming from your pack!",0
mcm_shatters:		db "Something shatters inside your pack!",0
mcm_acrid:			db "There is an acrid smell coming from your pack!",0

; ---------------------------------------------------------------- workspace

mc_rec:			ds MS_SIZE			; the caster's spells (data/mspells.asm)
mc_choice:		ds MS_BITS			; the bits of the ones it may cast
mc_k:			db 0
mc_desp:		db 0
mc_level:		db 0
mc_rspeed:		db 0
mc_hd:			dw 0
mc_gf:			db 0
mc_dam:			dw 0
mc_edam:		dw 0
mc_ball:		db 0
mc_caster:		dw 0
mc_dy:			db 0
mc_dx:			db 0
mc_step:		db 0
mc_n:			db 0
mc_sq:			dw 0				; x, y (so DE = y, x)
mc_by:			db 0
mc_bx:			db 0
mc_bdist:		db 0
mc_set:			dw 0
mc_perc:		db 0
mc_count:		db 0
mc_slot:		db 0
mc_tval:		db 0
mc_tdis:		db 0
mc_tries:		db 0
mc_sum_kind:	db 0
mc_sy:			db 0
mc_sx:			db 0
