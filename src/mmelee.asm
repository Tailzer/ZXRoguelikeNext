/* mmelee.asm - what a monster's blow does (overlay page PAGE_MCAST, with
	mcast.asm and mexotic.asm, whose element and stat routines it shares)
	References: CREATURE.C make_attack (the attack types and descriptions),
	monster_critical, shatter_quake; MORIA1.C corrode_gas; SPELLS.C
	aggravate_monster. mon_attack (resident) loads the blow into atk_type,
	atk_desc, atk_dice, atk_sides; IX = the monster, IY = its race.
 */

/* melee_hits - does the blow land? (make_attack's test_hit calls: power
	+ level * 3 against the AC, or against the level for stealing; nothing
	to steal or drain is a miss) -> carry if it does */
melee_hits:
	ld a,(atk_type)
	cp 20								; aggravation always happens
	scf
	ret z
	ld hl,attack_power-1
	add hl,a
	ld a,(hl)
	ld l,a
	rla
	sbc a,a
	ld h,a								; sign extended
	ld d,(iy+R_LEVEL)
	ld e,3								; (class_level_adj[CLA_MISC_HIT])
	mul d,e
	add hl,de
	ld a,(atk_type)
	cp 12
	jr z,.steal
	cp 13
	jr z,.steal
	ld a,(p_ac)
	jr .test
.steal:
	ld a,(p_lev)
.test:
	call test_hit
	ret nc
	ld a,(atk_type)
	cp 12								; no gold: nothing to take
	jr nz,.not_gold
	ld hl,(p_gold)
	ld a,h
	or l
	ld hl,(p_gold+2)
	or h
	or l
	scf
	ret nz
	or a
	ret
.not_gold:
	cp 13
	jr z,.pack
	cp 24
	scf
	ret nz
.pack:									; an empty pack: nothing to take
	call pack_count
	or a
	ret z
	scf
	ret
; to-hit power of each attack type 1-25 (make_attack's test_hit calls)
attack_power:
	db 60,-3,10,10,10,0,10,10,0,2,2,5,2,5,0,0,2,2,5,0,20,5,5,15,2

/* melee_blow - the blow has landed: say it, then do it, then perhaps a
	cut or a stun (make_attack) -> carry if the monster vanished with
	what it stole (no more blows) */
melee_blow:
	ld a,(iy+R_LEVEL)
	ld (mc_level),a
	xor a
	ld (mb_stop),a
	call blow_say
	ld a,(atk_dice)
	ld b,a
	ld a,(atk_sides)
	ld c,a
	call damroll
	ld (mb_dam),hl
	ld a,(atk_type)
	dec a
	cp 25
	jr nc,.done
	add a,a
	ld hl,blow_types
	add hl,a
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	or h
	jr z,.done
	push hl
	ld hl,(mb_dam)
	ret									; (jp to it, HL = damage)
.done:
	call mon_race
	call blow_critical
	ld a,(mb_stop)
	rra
	ret
blow_done:								; the types return through here
	jr melee_blow.done
blow_types:
	dw blow_normal, blow_str, blow_confuse, blow_fear, blow_fire		; 1-5
	dw blow_acid, blow_cold, blow_light, blow_corrode, blow_blind	; 6-10
	dw blow_paralyse, blow_gold, blow_object, blow_poison, blow_dex	; 11-15
	dw blow_con, blow_int, blow_wis, blow_exp, blow_aggravate		; 16-20
	dw blow_disenchant, blow_food, blow_eat_light, blow_charges, blow_all	; 21-25

/* blow_say - "The Jackal bites you." ("It" if unseen) */
blow_say:
	ld a,(atk_desc)
	cp 15
	jr nz,.not_slime
	ld hl,mb_slimed						; (no name)
	jp mx_print
.not_slime:
	cp 19
	jr nz,.not_insult
	ld a,9
	call randint
	ld hl,insults-2
	jr .pick
.not_insult:
	cp 23
	jr nz,.plain
	ld a,5
	call randint
	ld hl,maggot_words-2
.pick:
	add a,a
	add hl,a
	jr .say
.plain:
	ld hl,mb_attacks					; anything unknown "attacks you."
	cp NUM_BLOW_DESCS+1
	jr nc,.said
	add a,a
	ld hl,blow_descs-2
	add hl,a
.say:
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
.said:
	jp mx_say
NUM_BLOW_DESCS	equ 22
blow_descs:
	dw mb_hits, mb_bites, mb_claws, mb_stings, mb_touches, mb_kicks
	dw mb_gazes, mb_breathes, mb_spits, mb_wails, mb_embraces
	dw mb_crawls, mb_spores, mb_begs, mb_slimed, mb_crushes
	dw mb_tramples, mb_drools, mb_insults, mb_butts, mb_charges
	dw mb_engulfs
insults:	dw mb_insult1, mb_insult2, mb_insult3, mb_insult4, mb_insult5
			dw mb_insult6, mb_insult7, mb_insult8, mb_insult9
maggot_words: dw mb_maggot1, mb_maggot2, mb_maggot3, mb_maggot4, mb_maggot5

; ---------------------------------------------------------------- the types

blow_normal:							; 1: armour absorbs
	push hl								; (min(ac,150)*3/4 * dam) / 200
	ld a,(p_ac)
	cp 150
	jr c,$+4
	ld a,150
	ld e,a
	ld d,3
	mul d,e
	srl d
	rr e
	srl d
	rr e
	ld d,l
	mul d,e
	ex de,hl
	ld c,200
	call div16_8
	ex de,hl
	pop hl
	or a
	sbc hl,de
	ld (mb_dam),hl
	call take_hit
	ld hl,(mb_dam)						; a DESTRUCT monster's big blow
	ld de,24							; shakes the cave
	or a
	sbc hl,de
	jp c,blow_done
	call ms_flags
	bit RS_DESTRUCT,a
	call nz,shatter_quake
	jp blow_done
blow_str:								; 2
	call take_hit
	ld a,A_STR
	call sustained
	ld hl,mb_weaker_moment
	jr nz,.said
	ld a,2
	call randint
	cp 1
	jp nz,blow_done
	ld hl,mb_weaker
	call mx_print
	ld a,A_STR
	call lower_stat
	jp blow_done
.said:
	call mx_print
	jp blow_done
blow_confuse:							; 3
	call take_hit
	call confuse_resist
	jp nz,blow_done
	ld a,2
	call randint
	cp 1
	jp nz,blow_done
	ld hl,(p_confused)
	ld a,h
	or l
	jr nz,.more
	ld hl,mb_confused
	call mx_print
	ld a,(mc_level)
	call rand_lev
	ld hl,(p_confused)
	add hl,a
	jr .three
.more:
.three:
	ld a,3
	add hl,a
	ld (p_confused),hl
	jp blow_done
blow_fear:								; 4
	call take_hit
	call player_saves
	jr c,.stand
	ld a,(p_class)						; (the C's pclass 1, mages, 1 in 3)
	cp 1
	jr nz,.afraid
	ld a,3
	call randint
	cp 1
	jr z,.stand
.afraid:
	ld hl,(p_afraid)
	ld a,h
	or l
	ld a,3
	jr nz,.add
	ld hl,mb_afraid
	call mx_print
	ld a,(mc_level)
	call rand_lev
	add a,3
	ld hl,(p_afraid)
.add:
	add hl,a
	ld (p_afraid),hl
	jp blow_done
.stand:
	ld hl,mb_stand
	call mx_print
	jp blow_done
blow_fire:								; 5
	push hl
	ld hl,mb_flames
	call mx_print
	pop hl
	call el_fire
	jp blow_done
blow_acid:								; 6
	push hl
	ld hl,mb_acid
	call mx_print
	pop hl
	call el_acid
	jp blow_done
blow_cold:								; 7
	push hl
	ld hl,mb_frost
	call mx_print
	pop hl
	call el_cold
	jp blow_done
blow_light:								; 8
	push hl
	ld hl,mb_lightning
	call mx_print
	pop hl
	call el_light
	jp blow_done
blow_corrode:							; 9: corrode_gas, then the damage
	ld hl,mb_red_gas
	call mx_print
	ld a,(p_eflags2+1)
	and TR2_IM_ACID
	jr nz,.pack
	call minus_ac
	jr c,.pack
	ld a,8
	call randint
	ld l,a
	ld h,0
	call take_hit
.pack:
	ld hl,set_corrodes
	ld a,5
	call inven_damage
	ld hl,mb_acrid
	call nz,mx_print
	ld hl,(mb_dam)
	call take_hit
	jp blow_done
blow_blind:								; 10
	call take_hit
	call blind_resist
	jp nz,blow_done
	ld hl,(p_blind)
	ld a,h
	or l
	ld a,5
	jr nz,.add
	ld hl,mb_sting
	call mx_print
	ld a,(mc_level)
	call rand_lev
	add a,10
	ld hl,(p_blind)
.add:
	add hl,a
	ld (p_blind),hl
	jp blow_done
blow_paralyse:							; 11
	call take_hit
	call player_saves
	ld hl,mb_resist
	jr c,.said
	ld a,(p_paralysed)
	or a
	jp nz,blow_done
	ld a,(p_eflags+2)
	bit EF2_FREE_ACT,a
	ld hl,mcm_unaffected
	jr nz,.said
	ld a,(mc_level)
	call rand_lev
	add a,3
	jr nc,$+4
	ld a,255
	ld (p_paralysed),a
	ld hl,mb_paralysed
.said:
	call mx_print
	jp blow_done
blow_gold:								; 12
	call grabbed
	ld hl,mb_pouch
	jr c,.said
	ld hl,(p_gold)						; au / 10 + 1d25
	ld a,(p_gold+2)
	ld e,a
	ld c,10
	call div24_8
	push hl
	push de
	ld a,25
	call randint
	pop de
	pop hl
	ld c,a
	ld b,0
	add hl,bc
	ld a,e
	adc a,0
	ld e,a
	ld bc,(p_gold)						; au -= that, or to 0
	push hl
	ld h,b
	ld l,c
	pop bc
	or a
	sbc hl,bc
	ld a,(p_gold+2)
	sbc a,e
	ld c,a
	ld a,(p_gold+3)
	sbc a,0
	jr nc,.left
	xor a
	ld h,a
	ld l,a
	ld c,a
.left:
	ld (p_gold),hl
	ld l,c
	ld h,a
	ld (p_gold+2),hl
	ld hl,mb_purse
.said:
	call mx_print
	ld a,2
	jr smoke
blow_object:							; 13
	call grabbed
	ld hl,mb_backpack
	jr c,.said
	call pack_count
	call randint
	dec a
	ld (mb_slot),a
	push ix
	call pack_slot
	call item_kind_addr					; artifacts can't be taken (and
	ld a,(iy+K_TVAL)					; then no puff of smoke)
	cp 10
	jr c,.take
	cp 51
	jr nc,.take
	ld a,(ix+I_NAME2)
	or a
	jr z,.take
	call ego_addr
	bit EO_ARTIFACT,(iy+E_OPTS)
	jr z,.take
	pop ix
	jp blow_done
.take:
	pop ix
	push ix
	ld a,(mb_slot)
	call use_one						; (which leaves IX on the pack)
	pop ix
	ld hl,mb_lighter
.said:
	call mx_print
	ld a,3
/* smoke - A = n: 1 in n, "There is a puff of smoke!" and the thief
	teleports away, no more blows */
smoke:
	call randint
	cp 1
	jp nz,blow_done
	ld hl,mb_smoke
	call mx_print
	ld a,1
	ld (mb_stop),a
	ld a,MAX_SIGHT
	call mc_tport
	jp blow_done
/* grabbed - unless paralysed, 1d168 < DEX keeps it -> carry if kept */
grabbed:
	ld a,(p_paralysed)
	or a
	ret nz								; (carry is clear)
	ld a,168
	call randint
	ld hl,p_stat_use+A_DEX				; (carry: 1d168 < DEX)
	cp (hl)
	ret
blow_poison:							; 14
	call take_hit
	ld a,(p_eflags2+1)
	and TR2_IM_POISON
	jr nz,.no_effect
	ld a,(p_eflags+3)
	bit EF3_POISON,a
	jr nz,.no_effect
	ld hl,(p_resist_poison)
	ld a,h
	or l
	jr nz,.no_effect
	ld hl,mb_sick
	call mx_print
	ld a,(mc_level)
	call rand_lev
	add a,5
	ld hl,(p_poisoned)
	add hl,a
	ld (p_poisoned),hl
	jp blow_done
.no_effect:
	ld hl,mb_no_effect
	call mx_print
	jp blow_done
blow_dex:								; 15
	call take_hit
	ld a,A_DEX
	jr stat_blow
blow_con:								; 16
	call take_hit
	ld a,A_CON
	jr stat_blow
blow_int:								; 17
	call take_hit
	ld a,A_INT
	jr stat_blow
blow_wis:								; 18
	call take_hit
	ld a,A_WIS
/* stat_blow - A = stat: lowered unless sustained, said the C's way */
stat_blow:
	call stat_drain
	jp blow_done
blow_all:								; 25: all six
	call take_hit
	xor a
.each:
	push af
	call stat_drain
	pop af
	inc a
	cp 6
	jr c,.each
	jp blow_done
/* stat_drain - A = stat: its message, and down a step unless sustained */
stat_drain:
	ld (mb_stat),a
	add a,a
	add a,a
	ld hl,stat_words
	add hl,a							; (before, lowered, sustained)
	ld a,(mb_stat)
	cp A_INT							; "You have trouble thinking clearly."
	jr nz,.not_int						; comes first either way
	push hl
	ld hl,mb_trouble
	call mx_print
	pop hl
.not_int:
	push hl
	ld a,(mb_stat)
	call sustained
	pop hl
	jr z,.lower
	inc hl
	inc hl
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	jp mx_print
.lower:
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	ld a,h
	or l
	call nz,mx_print
	ld a,(mb_stat)
/* lower_stat - A = stat: dec_stat (the magic overlay's) */
lower_stat:
	push ix
	OVCALL PAGE_MAGIC, dec_stat, PAGE_MCAST
	pop ix
	ret
; per stat (A_ order): lowered, sustained
stat_words:	dw mb_weaker, mb_weaker_moment				; STR
			dw 0, mb_mind_clears					; INT
			dw mb_wis_drained, mb_wis_sustained		; WIS
			dw mb_clumsy, mb_clumsy_moment			; DEX
			dw mb_health, mb_disease				; CON
			dw mb_twisted, mb_good_looks			; CHR
/* sustained - A = stat -> NZ if it's sustained */
sustained:
	ld b,a
	inc b
	ld a,(p_sustain)
.bit:
	rrca
	djnz .bit
	sbc a,a
	ret
blow_exp:								; 19: no damage, but experience
	ld a,(p_eflags2)
	and TR2_HOLD_LIFE
	jr z,.drain
	ld a,5
	call randint
	cp 1
	ld hl,mcm_keep_life
	jr nz,.said
	ld hl,mcm_slipping
	call mx_print
	ld hl,(mb_dam)
	ld b,10
	jr .lose
.drain:
	ld hl,mcm_draining
	call mx_print
	ld hl,(mb_dam)
	ld b,1
.lose:
	call drain_exp
	jp blow_done
.said:
	call mx_print
	jp blow_done
blow_aggravate:							; 20: aggravate_monster(20)
	push ix
	xor a
	ld (mc_count),a
	ld ix,MON_LIST
	ld b,MON_MAX
.each:
	ld a,(ix+M_RACE_HI)
	cp MON_EMPTY
	jr z,.next
	ld (ix+M_SLEEP),0
	ld (ix+M_SLEEP+1),0
	ld a,(ix+M_CDIS)
	cp 21
	jr nc,.next
	ld a,(ix+M_SPEED)
	cp 2
	jp p,.next
	inc (ix+M_SPEED)
	ld a,1
	ld (mc_count),a
.next:
	ld de,MON_SIZE
	add ix,de
	djnz .each
	pop ix
	ld a,(mc_count)
	or a
	ld hl,mb_stirring
	call nz,mx_print
	jp blow_done
blow_disenchant:						; 21
	ld a,(p_eflags2+2)
	and TR2_RES_DISENCHANT
	jp nz,blow_done
	call take_hit
	ld hl,blow_dis_slots
	call disenchant
	ld a,(mc_count)
	or a
	jp z,blow_done
	ld hl,p_update
	set PU_BONUS,(hl)
	ld hl,mcm_static
	call mx_print
	jp blow_done
; INVEN_WIELD, BODY, ARM, OUTER, HANDS, HEAD, FEET
blow_dis_slots:	db EQ_WEAPON, EQ_BODY, EQ_SHIELD, EQ_CLOAK, EQ_GLOVES, EQ_HELM, EQ_BOOTS
blow_food:								; 22: the first food in the pack
	push ix
	xor a
.look:
	ld (mb_slot),a
	cp PACK_MAX
	jr nc,.none
	call pack_slot
	ld a,(ix+I_KIND_HI)
	cp ITEM_EMPTY
	jr z,.none
	call item_kind_addr
	ld a,(iy+K_CLASS)
	cp IC_FOOD
	jr z,.eat
	ld a,(mb_slot)
	inc a
	jr .look
.eat:
	ld a,(mb_slot)
	call use_one
	ld hl,mb_rations
	call mx_print
.none:
	pop ix
	jp blow_done
blow_eat_light:							; 23: the light source's fuel, 250 +
	ld a,(EQUIP+EQ_LIGHT*ITEM_SIZE+I_KIND_HI)	; 1d250 (to no less than 1)
	cp ITEM_EMPTY
	jp z,blow_done
	ld hl,(EQUIP+EQ_LIGHT*ITEM_SIZE+I_PVAL)
	ld a,h
	or l
	jp z,blow_done
	push ix
	ld ix,EQUIP+EQ_LIGHT*ITEM_SIZE
	call item_kind_addr
	pop ix
	bit 1,(iy+K_FLAGS2+3)				; (not artifacts)
	jp nz,blow_done
	ld a,250
	call randint
	ld e,a
	ld d,0
	ld hl,250
	add hl,de
	ex de,hl
	ld hl,(EQUIP+EQ_LIGHT*ITEM_SIZE+I_PVAL)
	or a
	sbc hl,de
	jr z,.one
	jr nc,.left
.one:
	ld hl,1
.left:
	ld (EQUIP+EQ_LIGHT*ITEM_SIZE+I_PVAL),hl
	ld hl,(p_blind)
	ld a,h
	or l
	ld hl,mb_dims
	call z,mx_print
	jp blow_done
blow_charges:							; 24: a wand's or staff's charges
	call pack_count						; feed the monster
	call randint
	dec a
	push ix
	call pack_slot
	call item_kind_addr
	ld a,(iy+K_CLASS)
	cp IC_WAND
	jr z,.device
	cp IC_STAFF
	jr nz,.none
.device:
	ld a,(ix+I_PVAL)
	or a
	jr z,.none
	ld e,a
	ld (ix+I_PVAL),0
	bit ID_KNOWN2_BIT,(ix+I_IDENT)
	jr nz,$+6
	set ID_EMPTY_BIT,(ix+I_IDENT)
	pop ix
	ld a,(mc_level)						; hp += level * charges
	ld d,a
	mul d,e
	ld l,(ix+M_HP)
	ld h,(ix+M_HP+1)
	add hl,de
	ld (ix+M_HP),l
	ld (ix+M_HP+1),h
	ld hl,mb_energy
	call mx_print
	jp blow_done
.none:
	pop ix
	jp blow_done

/* rand_lev - A = level -> A = 1d(level), 0 for level 0 */
rand_lev:
	or a
	ret z
	jp randint

/* ms_flags - IX = monster -> A = its RS_ flags (data/mspells.asm). Pages
	the race out: mon_race after */
ms_flags:
	ld l,(ix+M_RACE)
	ld h,(ix+M_RACE_HI)
	ld d,h
	ld e,l
	add hl,hl
	add hl,de
	add hl,hl
	add hl,hl
	ld de,mspell_table+MS_FLAGS
	add hl,de
	nextreg NR_MMU1,MSPELL_PAGE
	ld a,(hl)
	push af
	call mon_race
	pop af
	ret

; ---------------------------------------------------------------- criticals

/* blow_critical - a blow that hits, bites or claws may cut, one that
	hits, tramples, butts or charges may stun, worse the nearer the damage
	is to the most the dice can do (monster_critical) */
blow_critical:
	ld a,(atk_desc)
	ld c,0								; C bit 0: cut, bit 1: stun
	cp 1
	jr nz,.not_hit
	ld a,2								; both: one of them, at random
	call randint
	ld c,a
	jr .kind
.not_hit:
	cp 2
	jr z,.cut
	cp 3
	jr z,.cut
	cp 17
	jr z,.stun
	cp 20
	jr z,.stun
	cp 21
	ret nz
.stun:
	ld c,2
	jr .kind
.cut:
	ld c,1
.kind:
	ld a,c
	ld (mb_cs),a
	call critical_level					; A = 0 for none
	or a
	ret z
	cp 7
	jr c,$+4
	ld a,7
	dec a
	ld e,a
	ld d,8
	mul d,e
	ld hl,crit_table
	add hl,de
	ld a,(mb_cs)
	cp 1
	jr z,.cuts
	inc hl								; stun: (base, 1dn) after the cut's
	inc hl
	inc hl
	inc hl
	ld a,(hl)							; (stuns fit a byte)
	inc hl
	inc hl
	ld b,(hl)
	push af
	ld a,b
	call randint
	pop bc
	add a,b
	jp mc_stun
.cuts:
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld a,(hl)
	or a
	jr z,.fixed
	push de
	call randint
	pop de
	add de,a
.fixed:
	ex de,hl
	jp mc_cut
; per critical level 1-7: cut base (word), cut 1dn (0: none), 0, stun
; base (word), stun 1dn, 0
crit_table:	dw 0
			db 5,0
			dw 0
			db 5,0
			dw 5
			db 5,0
			dw 5
			db 5,0
			dw 20
			db 30,0
			dw 10
			db 20,0
			dw 30
			db 70,0
			dw 30
			db 40,0
			dw 50
			db 250,0
			dw 40
			db 50,0
			dw 300
			db 0,0
			dw 57
			db 60,0
			dw 5000
			db 0,0
			dw 100
			db 10,0

/* critical_level - mb_dam against the dice -> A = monster_critical() */
critical_level:
	ld a,(atk_dice)
	ld e,a
	ld a,(atk_sides)
	ld d,a
	mul d,e								; DE = total
	ld (mb_total),de
	xor a
	ld (mb_max),a
	ld hl,(mb_dam)
	bit 7,h
	ld a,0
	ret nz
	or a								; dam == total and dam > 20: max 1
	sbc hl,de
	jr nz,.not_max
	ld hl,(mb_dam)
	ld de,21
	or a
	sbc hl,de
	jr c,.not_max
	ld a,1
	ld (mb_max),a
.not_max:
	ld hl,(mb_total)					; dam > 19 * total / 20?
	ld d,h
	ld e,l
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl							; x 32
	sbc hl,de
	sbc hl,de
	sbc hl,de
	sbc hl,de
	sbc hl,de
	sbc hl,de
	sbc hl,de
	sbc hl,de
	sbc hl,de
	sbc hl,de
	sbc hl,de
	sbc hl,de
	sbc hl,de							; x 19
	ld c,20
	call div16_8
	ex de,hl
	ld hl,(mb_dam)
	or a
	sbc hl,de
	ld a,0
	ret z
	ret c
	ld hl,(mb_dam)						; under 20: only 1 in 20
	ld de,20
	or a
	sbc hl,de
	jr nc,.big
	ld a,20
	call randint
	cp 1
	ld a,0
	ret nz
	jr .levels
.big:
	ld hl,(mb_dam)						; over 20: 1 in 50 for each step more
	ld de,21
	or a
	sbc hl,de
	jr c,.levels
.more:
	ld a,50
	call randint
	cp 1
	jr nz,.levels
	ld hl,mb_max
	inc (hl)
	jr .more
.levels:
	ld hl,(mb_dam)
	ld a,h
	or a
	ld a,l
	jr z,$+4
	ld a,255
	ld hl,crit_steps
	ld b,6
.step:
	cp (hl)
	jr nc,.found
	inc hl
	djnz .step
.found:
	ld a,b
	ld hl,mb_max
	add a,(hl)
	ret
crit_steps:	db 46,34,26,19,12,0			; dam above 45 -> 6 ... else 1

; ---------------------------------------------------------------- shatter_quake

/* shatter_quake - a DESTRUCT monster's heavy blow: each square within 8 of
	it, 1 in 8, is shaken: a monster there is hurt (4d8, or killed if no
	rock is beside it), the player is thrown aside as by elemental force,
	what lies there is destroyed (not artifacts), rock opens and floor
	turns to rock (shatter_quake in CREATURE.C; a square still holding a
	monster or the player stays open, as nothing may stand in rock here) */
shatter_quake:
	ld (mc_caster),ix
	ld a,-8
	ld (mc_by),a
.row:
	ld a,-8
	ld (mc_bx),a
.col:
	call shake_square
	ld hl,mc_bx
	inc (hl)
	ld a,(hl)
	cp 9
	jr nz,.col
	ld hl,mc_by
	inc (hl)
	ld a,(hl)
	cp 9
	jr nz,.row
	ld ix,(mc_caster)
	call monsters_see_all
	ld ix,(mc_caster)
	jp mon_race
shake_square:
	ld ix,(mc_caster)
	ld a,(mc_by)
	add a,(ix+M_Y)
	ld d,a
	ld a,(mc_bx)
	add a,(ix+M_X)
	ld e,a
	ld (mc_sq),de
	call in_bounds
	ret nc
	ld a,8
	call randint
	cp 1
	ret nz
	ld a,(mc_by)						; (not the monster's own square)
	ld hl,mc_bx
	or (hl)
	ret z
	ld de,(mc_sq)
	ld a,(player_y)
	cp d
	jr nz,.not_player
	ld a,(player_x)
	cp e
	jr nz,.not_player
	ld hl,320							; (its old square is rock now)
	jp br_wall_n
.not_player:
	call map_addr
	bit F_MON_BIT,(hl)
	jr z,.ground
	ld de,(mc_sq)
	call mon_at
	jr nc,.ground
	call mon_race
	bit RF2_PHASE,(iy+R_FLAGS2)
	jr nz,.ground
	bit RF2_BREAK_WALL,(iy+R_FLAGS2)
	jr nz,.ground
	ld hl,$7FFF
	bit RM_ONLY_ATT,(iy+R_MOVE)			; it can't move: killed
	jr nz,.hurt
	push hl
	call rock_beside					; or unless rock is beside it
	pop hl								; (as the C has it)
	jr nc,.hurt
	ld bc,4*256+8
	call damroll
.hurt:
	push hl
	call msg_begin						; "The Orc wails out in pain!"
	ld a,1
	ld (name_cap),a
	call mon_name_to_msg
	ld hl,mb_wails_pain
	call mx_text
	call msg_add
	call msg_end
	call mon_race
	pop hl
	ld a,1								; (uniques left at 0)
	ld (mc_ball),a
	call mc_hurt_mon
	xor a
	ld (mc_ball),a
	ld a,(ix+M_RACE_HI)
	cp MON_EMPTY
	jr nz,.ground
	call msg_begin						; "The Orc is embedded in the rock."
	ld a,1
	ld (name_cap),a
	call mon_race
	call mon_name_to_msg
	ld hl,mb_embedded
	call mx_text
	call msg_add
	call msg_end
.ground:
	ld de,(mc_sq)						; the floor's things go
	call item_at
	jr nc,.terrain
	ld a,(ix+I_KIND_HI)
	cp KIND_GOLD
	jr z,.gone
	ld a,(ix+I_NAME2)
	or a
	jr z,.gone
	call ego_addr
	bit EO_ARTIFACT,(iy+E_OPTS)
	ret nz								; (an artifact: the square is left)
.gone:
	ld (ix+I_KIND_HI),ITEM_EMPTY
.terrain:
	ld de,(mc_sq)
	call map_addr
	bit F_MON_BIT,(hl)					; something still standing there
	ret nz
	ld de,(mc_sq)
	ld a,(player_y)
	cp d
	jr nz,.empty
	ld a,(player_x)
	cp e
	ret z
.empty:
	ld de,(mc_sq)
	call map_addr
	ld a,(hl)
	and TERRAIN_MASK
	cp T_PERMWALL
	ret z
	cp T_STORE
	ret z
	cp T_GRANITE
	jr z,.open
	cp T_MAGMA
	jr z,.open
	cp T_QUARTZ
	jr z,.open
	cp T_DOOR_SECRET
	jr z,.open
	push hl								; floor, doors, stairs: rock
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
	jr .wall
.open:
	ld b,T_CORRIDOR
.wall:
	ld a,(hl)
	and $FF-TERRAIN_MASK-F_PERM
	or b
	ld (hl),a
	ret
/* rock_beside - mc_sq -> carry if any square round it is rock */
rock_beside:
	ld de,(mc_sq)
	dec d
	dec e
	ld b,3
.row:
	ld c,3
	push de
.col:
	push bc
	push de
	call map_addr
	ld a,(hl)
	and TERRAIN_MASK
	call terrain_flags
	pop de
	pop bc
	bit TF_PASSABLE,a
	jr z,.rock
	inc e
	dec c
	jr nz,.col
	pop de
	inc d
	djnz .row
	or a
	ret
.rock:
	pop de
	scf
	ret

; ---------------------------------------------------------------- workspace

mb_dam:			dw 0
mb_total:		dw 0
mb_max:			db 0
mb_cs:			db 0
mb_stop:		db 0
mb_slot:		db 0
mb_stat:		db 0
