/* devices.asm - wands, staffs and rods  [overlay: PAGE_DEVICE]
	References: WANDS.C aim, STAFFS.C use, RODS.C activate_rod, DUNGEON.C
	activate (artifacts), and from
	SPELLS.C fire_bolt/fire_ball/light_line/starlite/disarm_all/hp_monster/
	drain_life/speed_monster/confuse_monster/sleep_monster/wall_to_mud/
	td_destroy2/poly_monster/clone_monster/teleport_monster/speed_monsters/
	sleep_monsters2/detect_evil/detection/probing/earthquake/pain_message,
	SETS.C (what fire, frost, acid and lightning destroy), MORIA1.C get_dir.
	A device's K_FLAGS is its effect number (WD_, ST_, RD_ in CONSTANT.H).
	Effects shared with scrolls and potions are borrowed from those
	overlays through device_xcall.
 */

OBJ_BOLT_RANGE		equ 18
USE_DEVICE			equ 3
; (GF_ types, the bolt and ball elements, are in constants.asm)

; borrow a routine from another overlay
	MACRO XCALL ov_page, ov_routine
		push hl
		ld hl,ov_routine
		ld (xc_target),hl
		pop hl
		ld b,ov_page
		call device_xcall
	ENDM

/* device_action - B = PM_AIM/PM_USE/PM_ZAP, A = pack slot; or
	PM_ACTIVATE, A = equipment slot */
device_action:
	ld (u_slot),a
	ld a,b
	ld (d_action),a
	cp PM_ACTIVATE						; an artifact worn: A = its slot
	ld a,(u_slot)
	jp z,activate
	call pack_slot
	call item_kind_addr
	ld (u_kind),hl
	ld a,(iy+K_LEVEL)
	ld (u_level),a
	ld a,(iy+K_FLAGS)
	ld (d_effect),a
	xor a
	ld (u_ident),a
	ld (d_used),a
	ld a,(d_action)
	cp PM_AIM
	jp z,aim_wand
	cp PM_USE
	jp z,use_staff
	jp zap_rod

/* the_device - IX = the device being used */
the_device:
	ld a,(u_slot)
	jp pack_slot

; ---------------------------------------------------------------- wands

aim_wand:
	call get_dir
	jp nc,free_turn
	call device_skill
	ld hl,msg_wand_failed
	jp nc,msg_print
	call the_device
	ld a,(ix+I_PVAL)
	or a
	jr z,.empty
	dec (ix+I_PVAL)
.effect:
	ld a,(d_effect)
	cp NUM_WAND_EFFECTS+1
	jr nc,.done
	ld hl,wand_effects-2
	call jump_table
	ld a,(d_wonder)						; wonder: pick another and go again
	or a
	jr z,.done
	xor a
	ld (d_wonder),a
	jr .effect
.done:
	call item_used
	jp desc_charges
.empty:
	ld hl,msg_wand_empty
	call msg_print
	bit ID_KNOWN2_BIT,(ix+I_IDENT)
	ret nz
	set ID_EMPTY_BIT,(ix+I_IDENT)
	ret

wand_effects:
	dw wd_light, wd_lt_bolt, wd_ft_bolt, wd_fr_bolt, wd_stone_mud		; 1-5
	dw wd_poly, wd_heal_mon, wd_haste_mon, wd_slow_mon, wd_conf_mon	; 6-10
	dw wd_sleep_mon, wd_drain, wd_td_destroy, wd_magic_missile		; 11-14
	dw no_effect, wd_clone, wd_teleport, wd_disarm, wd_lt_ball		; 15-19
	dw wd_cd_ball, wd_fr_ball, wd_st_cloud, wd_ac_ball, wd_wonder		; 20-24
	dw wd_drg_fire, wd_drg_frost, wd_drg_breath, wd_ac_bolt, wd_annihil	; 25-29
NUM_WAND_EFFECTS	equ ($-wand_effects)/2

/* jump_table - A = 1-based index, HL = table - 2 */
jump_table:
	add a,a
	add hl,a
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	jp (hl)

no_effect:
	ret

wd_light:
	ld hl,msg_blue_line
	call msg_print
	call ident
	ld a,(d_dir)
	jp light_line
wd_lt_bolt:
	ld bc,3*256+8
	ld hl,txt_lightning_bolt
	ld a,GF_LIGHTNING
	jr bolt_dice
wd_ft_bolt:
	ld bc,4*256+8
	ld hl,txt_frost_bolt
	ld a,GF_FROST
	jr bolt_dice
wd_fr_bolt:
	ld bc,6*256+8
	ld hl,txt_fire_bolt
	ld a,GF_FIRE
	jr bolt_dice
wd_ac_bolt:
	ld bc,5*256+8
	ld hl,txt_acid_bolt
	ld a,GF_ACID
	jr bolt_dice
wd_magic_missile:
	ld bc,2*256+6
	ld hl,txt_magic_missile
	ld a,GF_MAGIC_MISSILE
/* bolt_dice - A = type, HL = name, B/C = damage dice: fire a bolt */
bolt_dice:
	ld (d_type),a
	ld (d_name),hl
	call damroll
	ld (d_dam),hl
	call ident
	jp fire_bolt
wd_stone_mud:
	call wall_to_mud
	ret nc
	jp ident
wd_poly:
	call target_monster
	ret nc
	jp poly_monster
wd_heal_mon:
	call target_monster
	ret nc
	call ident
	ld bc,4*256+6						; hp_monster(-4d6): no message
	call damroll
	ld e,(ix+M_HP)
	ld d,(ix+M_HP+1)
	add hl,de
	ld (ix+M_HP),l
	ld (ix+M_HP+1),h
	ret
wd_haste_mon:
	call target_monster
	ret nc
	jp haste_one
wd_slow_mon:
	call target_monster
	ret nc
	jp slow_one
wd_conf_mon:
	call target_monster
	ret nc
	jp confuse_one
wd_sleep_mon:
	call target_monster
	ret nc
	jp sleep_one
wd_drain:
	ld hl,75
	jr drain
wd_annihil:
	ld hl,125
drain:
	ld (d_dam),hl
	call target_monster
	ret nc
	jp drain_one
wd_td_destroy:
	call td_destroy2
	ret nc
	jp ident
wd_clone:
	call target_monster
	ret nc
	ld d,(ix+M_Y)
	ld e,(ix+M_X)
	XCALL PAGE_LEVEL, clone_at
	ret nc
	jp ident
wd_teleport:
	call target_monster
	ret nc
	call ident
	ld (ix+M_SLEEP),0
	ld (ix+M_SLEEP+1),0
	jp teleport_away
wd_disarm:
	call disarm_all
	ret nc
	jp ident
wd_lt_ball:
	ld a,GF_LIGHTNING
	ld hl,txt_lightning_ball
	ld de,32
	jr ball
wd_cd_ball:
	ld a,GF_FROST
	ld hl,txt_cold_ball
	ld de,48
	jr ball
wd_fr_ball:
	ld a,GF_FIRE
	ld hl,txt_fire_ball
	ld de,72
	jr ball
wd_st_cloud:
	ld a,GF_POISON_GAS
	ld hl,txt_stinking_cloud
	ld de,12
	jr ball
wd_ac_ball:
	ld a,GF_ACID
	ld hl,txt_acid_ball
	ld de,60
	jr ball
wd_drg_fire:
	ld a,GF_FIRE
	ld hl,txt_huge_fire
	ld de,100
	jr ball
wd_drg_frost:
	ld a,GF_FROST
	ld hl,txt_huge_frost
	ld de,80
/* ball - A = type, HL = name, DE = damage: fire a ball */
ball:
	ld (d_type),a
	ld (d_name),hl
	ld (d_dam),de
	call ident
	jp fire_ball
wd_drg_breath:							; one of five, at random
	ld a,5
	call randint
	dec a
	jr z,wd_drg_fire
	dec a
	jr z,wd_drg_frost
	dec a
	ld hl,txt_huge_acid
	ld de,90
	ld b,GF_ACID
	jr z,.breathe
	dec a
	ld hl,txt_huge_lightning
	ld de,70
	ld b,GF_LIGHTNING
	jr z,.breathe
	ld hl,txt_huge_gas
	ld b,GF_POISON_GAS
.breathe:
	ld a,b
	jr ball
wd_wonder:								; a random wand effect, 1-23
	ld a,23
	call randint
	ld (d_effect),a
	ld a,1
	ld (d_wonder),a
	ret

/* desc_charges - "You have 5 charges remaining." (if they're known) */
desc_charges:
	call the_device
	bit ID_KNOWN2_BIT,(ix+I_IDENT)
	ret z
	call msg_begin
	ld hl,txt_you_have_
	call msg_add
	ld a,(ix+I_PVAL)
	call msg_add_u8
	ld hl,txt_charges_remaining
	call msg_add
	jp msg_end

; ---------------------------------------------------------------- artifacts

/* activate - A = the equipment slot of an artifact to activate (activate
	in DUNGEON.C): not while it's recharging; it may fail; else its
	messages and effect (data/activate.asm), and its recharge time */
activate:
	ld (a_slot),a
	call a_item
	ld a,(ix+I_ATIME)
	or (ix+I_ATIME+1)
	ld hl,msg_whines
	jp nz,msg_print
	ld a,18								; INT < 1d18 and 1d(level) > lev:
	call randint						; it fails
	ld b,a
	ld a,(p_stat_use+A_INT)
	cp b
	jr nc,.works
	call item_kind_addr
	ld a,(iy+K_LEVEL)
	call randint
	ld b,a
	ld a,(p_lev)
	cp b
	jr nc,.works
	ld hl,msg_fail_activate
	jp msg_print
.works:
	ld hl,msg_activate_it
	call msg_print
	call a_item							; which: its ego, or $8000 + kind
	ld e,(ix+I_NAME2)
	ld d,0
	ld a,e
	or a
	jr nz,.key
	ld e,(ix+I_KIND)
	ld a,(ix+I_KIND_HI)
	or $80
	ld d,a
.key:
	nextreg NR_MMU1,ACT_PAGE
	ld hl,act_table
	ld b,NUM_ACTS
.find:
	ld a,(hl)
	cp e
	jr nz,.not_it
	inc hl
	ld a,(hl)
	dec hl
	cp d
	jr z,.found
.not_it:
	ld a,16
	add hl,a
	djnz .find
	ret
.found:
	ld de,a_entry
	ld bc,16
	ldir
	ld a,(a_effect)						; a breath: one of its choices
	cp AE_BREATH
	jr nz,.strings
	ld a,(a_gf)
	call randint
	dec a
	ld e,a
	ld d,5
	mul d,e
	ld hl,(a_name_p)
	add hl,de
	ld a,(hl)
	ld (a_gf),a
	inc hl
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld (a_msg_p),de
	ld e,(hl)
	inc hl
	ld d,(hl)
	ld (a_name_p),de
	ld a,AE_BALL
	ld (a_effect),a
.strings:								; (copied out of the page)
	ld hl,(a_msg_p)
	ld de,a_msg
	call .copy
	ld hl,(a_msg2_p)
	ld de,a_msg2
	call .copy
	ld hl,(a_name_p)
	ld de,a_name
	call .copy
	ld hl,a_msg
	ld a,(hl)
	or a
	call nz,msg_print
	ld hl,a_msg2
	ld a,(hl)
	or a
	call nz,msg_print
	xor a
	ld (a_cancel),a
	ld a,(a_effect)
	ld hl,act_effects-2
	call jump_table
	ld a,(a_cancel)						; no direction: nothing happened
	or a
	ret nz
	ld hl,(a_trand)						; recharge: base + 1d(rand)
	ld a,h
	or l
	jr z,$+5
	call randint16
	ld de,(a_tbase)
	add hl,de
	push hl
	call a_item
	pop hl
	ld (ix+I_ATIME),l
	ld (ix+I_ATIME+1),h
	ret
.copy:									; HL = string or 0 -> DE
	ld a,h
	or l
	jr z,.empty
.char:
	ld a,(hl)
	ld (de),a
	inc hl
	inc de
	or a
	jr nz,.char
	ret
.empty:
	ld (de),a
	ret

/* a_item - IX = the artifact being activated */
a_item:
	ld a,(a_slot)
	ld e,a
	ld d,ITEM_SIZE
	mul d,e
	ld ix,EQUIP
	add ix,de
	ret

act_effects:
	dw ae_bolt, ae_ball, ae_drain, ae_mud, ae_tele_mon, ae_conf_mon		; 1-6
	dw ae_fast, ae_fast0, ae_heal, ae_heal_cut, ae_fear_poison			; 7-11
	dw ae_recall, ae_identify, probing, ae_mass_gen, ae_genocide		; 12-16
	dw ae_td, ae_teleport, ae_restore, ae_resist, sleep_monsters		; 17-21
	dw ae_recharge, rd_detect, ae_dispel_evil, ae_protevil, ae_one_ring	; 22-26
	dw ae_ball														; 27 (a breath)
	dw ae_sleep_one, ae_poly, ae_slow_one, ae_light_line, ae_sleep_adj	; 28-32
	dw earthquake, detect_evil, ae_detect_mon						; 33-35
	dw ae_turn_undead, ae_banish, ae_dispel, rd_detect, probing		; 36-40
	dw ae_light_area, ae_map_area, ae_wiz_light, ae_fire_bolts		; 41-44

/* do_effect - one of activate's effects for a spell: sp_entry (16 bytes,
	as act_table's) and sp_name, in high RAM. -> A = 1 if it was called off
	(no direction) */
do_effect:
	ld hl,sp_entry
	ld de,a_entry
	ld bc,16
	ldir
	ld hl,sp_name
	ld de,a_name
	ld bc,32
	ldir
	xor a
	ld (a_msg),a
	ld (a_msg2),a
	ld (a_cancel),a
	ld a,(a_effect)
	ld hl,act_effects-2
	call jump_table
	ld a,(a_cancel)
	ret

ae_sleep_one:
	call ae_dir
	ret nc
	jp wd_sleep_mon
ae_poly:
	call ae_dir
	ret nc
	jp wd_poly
ae_slow_one:
	call ae_dir
	ret nc
	jp wd_slow_mon
ae_light_line:
	call ae_dir
	ret nc
	ld hl,msg_blue_line
	call msg_print
	ld a,(d_dir)
	jp light_line
ae_sleep_adj:							; sleep_monsters1: those next to you
	ld hl,.adjacent
	jp in_sight_each
.adjacent:
	ld a,(ix+M_CDIS)
	cp 2
	ret nc
	jp sleep_monsters.one
ae_light_area:							; the Phial: light_area
	XCALL PAGE_SCROLL, sc_light
	ret
ae_map_area:							; the Star: map_area
	XCALL PAGE_SCROLL, sc_map
	ret
ae_fire_bolts:							; Cubragol (throw.asm)
	XCALL PAGE_TRAP, fire_bolts
	ret
ae_wiz_light:							; the Arkenstone: wizard_light(TRUE)
	XCALL PAGE_MAGIC, wizard_light
	ret
ae_detect_mon:
	xor a
	ld hl,msg_sense_monsters
	jp show_monsters
ae_turn_undead:							; turn_undead: undead in sight that
	ld hl,.one							; fail to stand (level + 1 above
	jp in_sight_each					; theirs, or 1 in 5) are confused
.one:
	call mon_race
	bit RF_UNDEAD,(iy+R_FLAGS)
	ret z
	ld a,(p_lev)
	cp (iy+R_LEVEL)
	jr nc,.turned
	ld a,5
	call randint
	dec a
	ld hl,txt_unaffected_d
	jr nz,.say
.turned:
	ld (ix+M_CONFUSED),1
	ld hl,txt_runs_frantically
.say:
	ld a,(ix+M_ML)
	or a
	ret z
	jp say_name
ae_banish:								; banish_creature(EVIL, 100): the
	ld hl,.one							; evil in sight sent far away
	call in_sight_each
	ld a,(d_any)
	or a
	ret z
	ld hl,msg_banished
	jp msg_print
.one:
	call mon_race
	bit RF_EVIL,(iy+R_FLAGS)
	ret z
	ld a,1
	ld (d_any),a
	jp teleport_away
ae_dispel:								; dispel_creature: element = the
	ld a,(a_num)						; R_FLAGS mask, number = damage
	ld b,a
	ld a,(a_gf)
	jp dispel

/* ae_dir - a direction -> carry; none: a_cancel set */
ae_dir:
	call get_dir
	ret c
	ld a,1
	ld (a_cancel),a
	or a
	ret

ae_bolt:
	call ae_dir
	ret nc
	call ae_named
	ld bc,(a_num)						; (B = dice, C = sides)
	call damroll
	ld (d_dam),hl
	jp fire_bolt
ae_ball:
	call ae_dir
	ret nc
	call ae_named
	ld hl,(a_num)
	ld (d_dam),hl
	jp fire_ball
ae_named:								; its element and name
	ld a,(a_gf)
	ld (d_type),a
	ld hl,a_name
	ld (d_name),hl
	ret
ae_drain:
	call ae_dir
	ret nc
	ld hl,(a_num)
	jp drain
ae_mud:
	call ae_dir
	ret nc
	jp wall_to_mud
ae_tele_mon:
	call ae_dir
	ret nc
	jp wd_teleport
ae_conf_mon:
	call ae_dir
	ret nc
	jp wd_conf_mon
ae_fast0:								; only if not fast already
	ld hl,p_fast
	call get_w
	ret nz
ae_fast:								; fast += 1d(low) + high
	ld hl,p_fast
	ld bc,(a_num)
	jp add_rand
ae_heal:
	ld hl,(a_num)
	XCALL PAGE_MAGIC, hp_player
	ret
ae_heal_cut:							; heal the dice, and halve cuts - 50
	ld bc,(a_num)
	call damroll
	XCALL PAGE_MAGIC, hp_player
	ld hl,(p_cut)
	call positive_w
	ret z
	sra h
	rr l
	ld de,-50
	add hl,de
	bit 7,h
	jr z,$+5
	ld hl,0
	ld (p_cut),hl
	ld hl,msg_you_wounds
	jp msg_print
ae_fear_poison:
	XCALL PAGE_MAGIC, remove_fear
	XCALL PAGE_MAGIC, cure_poison
	ret
ae_recall:								; recall in 15 + 1d20, if not already
	ld hl,p_word_recall
	call get_w
	ret nz
	ld a,20
	call randint
	add a,15
	ld l,a
	ld h,0
	ld (p_word_recall),hl
	ret
ae_identify:
	XCALL PAGE_SCROLL, sc_identify_item
	ret
ae_mass_gen:
	XCALL PAGE_SCROLL, sc_mass_genocide
	ret
ae_genocide:
	XCALL PAGE_SCROLL, sc_genocide
	ret
ae_td:
	XCALL PAGE_SCROLL, sc_td_destroy
	ret
ae_teleport:
	ld hl,(a_num)
	XCALL PAGE_SCROLL, teleport
	ret
ae_restore:
	XCALL PAGE_MAGIC, restore_level
	ret
ae_resist:								; 20 + 1d20 more of each
	ld hl,p_resist_heat
	ld bc,20*256+20
	call add_rand
	ld hl,p_resist_cold
	ld bc,20*256+20
	jp add_rand
ae_recharge:							; (Thingol: recharge(60))
	ld a,60
	XCALL PAGE_SCROLL, recharge_n
	ret
ae_dispel_evil:							; dispel evil for 5 x level
	ld a,(p_lev)
	ld e,a
	ld d,5
	mul d,e
	ld b,e
	ld a,1<<RF_EVIL
	jp dispel
ae_protevil:
	XCALL PAGE_SCROLL, sc_protevil
	ret
ae_one_ring:							; 1d17 + 8 - lev/10:
	ld a,(p_lev)
	ld c,0
.tens:
	cp 10
	jr c,.roll
	sub 10
	inc c
	jr .tens
.roll:
	push bc
	ld a,17
	call randint
	pop bc
	add a,8
	sub c
	cp 5
	jr z,.dispel						; 5: dispel everything
	cp 6
	jr z,.aura							; 6, 7: a malignant aura
	cp 7
	jr z,.aura
	cp 8
	jr c,.bolt
	cp 11
	jr nc,.bolt
	call ae_dir							; 8-10: a ball of raw mana
	ret nc
	ld hl,txt_raw_mana_ball
	ld de,300
	call .mana
	jp fire_ball
.bolt:									; else a bolt of it
	call ae_dir
	ret nc
	ld hl,txt_raw_mana_bolt
	ld de,250
	call .mana
	jp fire_bolt
.mana:
	ld (d_name),hl
	ld (d_dam),de
	xor a								; (GF_MAGIC_MISSILE)
	ld (d_type),a
	ret
.dispel:
	xor a								; (the C's 1000: as hard as it can)
	ld b,255
	jp dispel
.aura:
	ld hl,msg_malignant
	call msg_print
	ld a,(p_lev)						; down a level: somewhere in the one
	cp 2								; below
	jr c,.ruin
	call lose_a_level
.ruin:
	xor a
.stat:
	ld (d_star),a
	XCALL PAGE_MAGIC, ruin_stat
	ld a,(d_star)
	inc a
	cp 6
	jr c,.stat
	ld hl,(p_chp)						; and half the hit points
	ld de,3
	or a
	sbc hl,de
	ld hl,0
	jr c,.hurt
	ld hl,(p_chp)
	srl h
	rr l
.hurt:
	ld de,KILLER_AURA
	ld (killer_race),de
	jp take_hit

/* lose_a_level - exp falls to somewhere in the level below (the One
	Ring's aura): low = needed for level-1 (0 at 2), high = needed for this
	level, exp = low + 1d(high - low) */
lose_a_level:
	ld a,(p_lev)
	sub 3								; (entry k: needed for level k + 2)
	ld hl,0
	ld e,l
	jr c,.low
	add a,a
	add a,a
	ld hl,P_EXP_TABLE
	add hl,a
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld a,(hl)
	ex de,hl
	ld e,a
.low:									; E:HL = low
	ld (a_low),hl
	ld a,e
	ld (a_low+2),a
	ld a,(p_lev)
	sub 2
	add a,a
	add a,a
	ld hl,P_EXP_TABLE
	add hl,a
	ld e,(hl)
	inc hl
	ld d,(hl)
	ex de,hl							; HL = high (low 16 bits)
	ld de,(a_low)
	or a
	sbc hl,de							; the difference (at most 65535)
	ld a,h
	or l
	jr z,.new
	call randint16
.new:									; new = low + 1d(diff)
	ld de,(a_low)
	add hl,de
	ld a,(a_low+2)
	adc a,0
	ld e,a								; E:HL = new; lose exp - new
	ld bc,(p_exp)
	ld a,(p_exp+2)
	push hl
	ld h,b
	ld l,c
	pop bc
	or a
	sbc hl,bc
	sbc a,e
	ld e,a
	XCALL PAGE_MAGIC, lose_exp
	ld hl,(p_exp)						; max_exp = exp
	ld (p_max_exp),hl
	ld hl,(p_exp+2)
	ld (p_max_exp+2),hl
	ret

msg_whines:		db "It whines, glows and fades...",0
msg_fail_activate: db "You fail to activate it properly.",0
msg_activate_it: db "You activate it...",0
msg_you_wounds:	db "You wounds heal.",0
msg_malignant:	db "You are surrounded by a malignant aura",0
txt_raw_mana_ball: db "huge ball of Raw Mana",0
txt_raw_mana_bolt: db "bolt of Raw Mana",0
a_slot:			db 0
a_cancel:		db 0
a_low:			ds 3
a_entry:							; (act_table's 16 bytes)
a_key:			dw 0
a_effect:		db 0
a_gf:			db 0
a_num:			dw 0
a_msg_p:		dw 0
a_msg2_p:		dw 0
a_name_p:		dw 0
a_tbase:		dw 0
a_trand:		dw 0
a_msg:			ds 64
a_msg2:			ds 40
a_name:			ds 32

; ---------------------------------------------------------------- staffs

use_staff:
	call device_skill
	ld hl,msg_staff_failed
	jp nc,msg_print
	call the_device
	ld a,(ix+I_PVAL)
	or a
	jr z,.empty
	dec (ix+I_PVAL)
	ld a,(d_effect)
	cp NUM_STAFF_EFFECTS+1
	jr nc,.done
	ld hl,staff_effects-2
	call jump_table
.done:
	call item_used
	jp desc_charges
.empty:
	ld hl,msg_staff_empty
	call msg_print
	bit ID_KNOWN2_BIT,(ix+I_IDENT)
	ret nz
	set ID_EMPTY_BIT,(ix+I_IDENT)
	ret

staff_effects:
	dw st_light, st_doors, st_traps, st_treasure, st_objects		; 1-5
	dw st_teleport, st_earthquake, st_summon, st_destruction, st_starlite	; 6-10
	dw st_haste_mons, st_slow_mons, st_sleep_mons, st_cure_light		; 11-14
	dw st_det_inv, st_haste_self, st_slow, no_effect, st_det_evil			; 15-19
	dw st_curing, st_dispel_evil, st_darkness, st_genocide, st_power	; 20-24
	dw st_magi, st_holiness, st_identify, st_mapping, st_healing		; 25-29
	dw st_probe														; 30
NUM_STAFF_EFFECTS	equ ($-staff_effects)/2

st_light:
	XCALL PAGE_SCROLL, sc_light
	ret
st_doors:
	XCALL PAGE_SCROLL, sc_doors
	ret
st_traps:
	XCALL PAGE_SCROLL, sc_traps
	ret
st_treasure:
	XCALL PAGE_SCROLL, sc_treasure
	ret
st_objects:
	XCALL PAGE_SCROLL, sc_objects
	ret
st_teleport:
	XCALL PAGE_SCROLL, sc_teleport
	ret
st_destruction:
	XCALL PAGE_SCROLL, sc_destruction
	ret
st_darkness:
	XCALL PAGE_SCROLL, sc_darkness
	ret
st_mapping:
	XCALL PAGE_SCROLL, sc_map
	ret
st_det_inv:
	XCALL PAGE_SCROLL, sc_det_inv
	ret
st_identify:
	XCALL PAGE_SCROLL, sc_identify_item
	ret
st_summon:								; summon_monster, 1d4 times
	ld a,4
	ld (summon_max),a
	XCALL PAGE_SCROLL, sc_summon
	ld a,3
	ld (summon_max),a
	ret
st_genocide:							; genocide(FALSE): no strain
	xor a
	ld (gen_strain),a
	XCALL PAGE_SCROLL, sc_genocide
	ld a,1
	ld (gen_strain),a
	jp ident
st_dispel_evil:
	ld a,1<<RF_EVIL
	ld b,60
	jr dispel
st_power:								; (the C doesn't identify it, but
	xor a								;  any visible hit does here)
	ld b,120
/* dispel - A = R_FLAGS mask (0: everything), B = damage */
dispel:
	ld (dispel_mask),a
	ld a,b
	ld (dispel_dam),a
	XCALL PAGE_SCROLL, sc_dispel_undead
	ld a,1<<RF_UNDEAD					; (the scroll's own settings)
	ld (dispel_mask),a
	ld a,60
	ld (dispel_dam),a
	ret
st_starlite:
	call ident
	ld a,(p_status)
	bit PY_BLIND,a
	ld hl,msg_staff_bursts
	call z,msg_print
	ld a,1
.dir:
	ld (d_star),a
	cp 5
	call nz,light_line
	ld a,(d_star)
	inc a
	cp 10
	jr c,.dir
	ret
st_cure_light:
	ld a,8
	call randint
	ld l,a
	ld h,0
	XCALL PAGE_MAGIC, hp_player
	ret nc
	jp ident
st_haste_self:
	ld hl,p_fast
	call get_w
	call z,ident
	ld bc,15*256+30
	jp z,add_rand
	ld bc,0*256+5
	jp add_rand
st_slow:
	ld hl,p_slow
	call get_w
	call z,ident
	ld bc,15*256+30
	jp add_rand
st_curing:								; the C's || stops at the first
	call cure_first
	call c,ident
	ld hl,(p_stun)
	call positive_w
	jr z,.cut
	call clear_stun
	jp ident
.cut:
	ld hl,(p_cut)
	call positive_w
	ret z
	call clear_cut
	jp ident
st_healing:
	ld hl,300
	XCALL PAGE_MAGIC, hp_player
	call c,ident
stun_and_cut:							; both cleared, if any
	ld hl,(p_stun)
	call positive_w
	jr z,.cut
	call clear_stun
	call ident
.cut:
	ld hl,(p_cut)
	call positive_w
	ret z
	call clear_cut
	jp ident
st_holiness:
	call ident
	ld a,1<<RF_EVIL
	ld b,120
	call dispel
	XCALL PAGE_SCROLL, sc_protevil
	XCALL PAGE_MAGIC, cure_poison
	XCALL PAGE_MAGIC, remove_fear
	ld hl,50
	XCALL PAGE_MAGIC, hp_player
	jr stun_and_cut
st_magi:
	ld a,A_INT
	XCALL PAGE_MAGIC, res_stat
	ret nc
	ld hl,msg_warm_feeling_d
	call msg_print
	jp ident
st_probe:
	call ident
	jp probing
st_det_evil:
	call detect_evil
	ret nc
	jp ident
st_haste_mons:
	ld a,1
	jr st_speed_mons
st_slow_mons:
	ld a,-1
st_speed_mons:
	call speed_monsters
	ret nc
	jp ident
st_sleep_mons:
	call sleep_monsters
	ret nc
	jp ident
st_earthquake:
	call ident
	jp earthquake

/* cure_first - blindness, else poison, else confusion -> carry if one */
cure_first:
	XCALL PAGE_MAGIC, cure_blindness
	ret c
	XCALL PAGE_MAGIC, cure_poison
	ret c
	XCALL PAGE_MAGIC, cure_confusion
	ret

clear_stun:
	ld hl,0
	ld (p_stun),hl
	ld hl,p_update
	set PU_BONUS,(hl)
	ld hl,msg_head_stops_d
	jp msg_print
clear_cut:
	ld hl,0
	ld (p_cut),hl
	ld hl,msg_feel_better_d
	jp msg_print

/* positive_w - HL = signed word -> Z if not above 0 */
positive_w:
	bit 7,h
	jr nz,.no
	ld a,h
	or l
	ret
.no:
	xor a
	ret

; ---------------------------------------------------------------- rods

zap_rod:
	call device_skill
	ld hl,msg_rod_failed
	jp nc,msg_print
	call the_device
	ld a,(ix+I_TIMEOUT)
	or (ix+I_TIMEOUT+1)
	ld hl,msg_rod_exhausted
	jp nz,msg_print
	ld a,(d_effect)						; aimed rods ask for a direction
	cp NUM_ROD_EFFECTS+1
	ret nc
	dec a
	ld hl,rod_aimed
	add hl,a
	ld a,(hl)
	or a
	jr z,.go
	call get_dir
	jp nc,free_turn
.go:
	call the_device						; the effect and its timeout
	ld a,(d_effect)
	dec a
	add a,a
	ld hl,rod_timeouts
	add hl,a
	ld a,(hl)
	ld (ix+I_TIMEOUT),a
	inc hl
	ld a,(hl)
	ld (ix+I_TIMEOUT+1),a
	ld a,(d_effect)
	ld hl,rod_effects-2
	call jump_table
	jp item_used

rod_effects:
	dw rd_light, wd_lt_bolt, rd_ft_bolt, rd_fr_bolt, no_effect		; 1-5
	dw wd_poly, wd_slow_mon, no_effect, wd_sleep_mon, wd_drain		; 6-10
	dw no_effect, no_effect, wd_teleport, wd_disarm, wd_lt_ball		; 11-15
	dw wd_cd_ball, wd_fr_ball, no_effect, wd_ac_ball, rd_ac_bolt		; 16-20
	dw no_effect, st_mapping, st_identify, rd_cure, rd_heal			; 21-25
	dw rd_detect, rd_restore, rd_speed, rd_illume, st_probe			; 26-30
	dw rd_recall, st_traps											; 31-32
NUM_ROD_EFFECTS		equ ($-rod_effects)/2
; which rods need a direction, and how long each takes to recharge
rod_aimed:		db 1,1,1,1,1, 1,1,1,1,1, 1,1,1,1,1, 1,1,1,1,1, 1,0,0,0,0, 0,0,0,0,0, 0,0
rod_timeouts:	dw 9,11,13,15,0, 25,20,0,18,23, 0,0,25,30,23, 25,30,0,27,12
				dw 0,99,10,888,888, 99,999,99,30,50, 60,99

rd_light:
	ld hl,msg_blue_line
	call msg_print
	call ident
	ld a,(d_dir)
	jp light_line
rd_ft_bolt:
	ld bc,5*256+8
	ld hl,txt_frost_bolt
	ld a,GF_FROST
	jp bolt_dice
rd_fr_bolt:
	ld bc,8*256+8
	ld hl,txt_fire_bolt
	ld a,GF_FIRE
	jp bolt_dice
rd_ac_bolt:
	ld bc,6*256+8
	ld hl,txt_acid_bolt
	ld a,GF_ACID
	jp bolt_dice
rd_illume:
	XCALL PAGE_SCROLL, sc_light
	ret
rd_recall:
	XCALL PAGE_SCROLL, sc_recall
	ret
rd_cure:
	call cure_first
	call c,ident
	ld hl,(p_stun)
	call positive_w
	jr z,.cut
	call clear_stun
	jp ident
.cut:
	ld hl,(p_cut)
	call positive_w
	ret z
	call clear_cut
	jp ident
rd_heal:
	ld hl,500
	XCALL PAGE_MAGIC, hp_player
	call c,ident
	jp stun_and_cut
rd_restore:								; the C's || stops at the first
	XCALL PAGE_MAGIC, restore_level
	jr c,.yes
	ld a,A_STR
.stat:
	ld (d_star),a
	XCALL PAGE_MAGIC, res_stat
	jr c,.yes
	ld a,(d_star)
	inc a
	cp 6
	jr c,.stat
	ret
.yes:
	jp ident
rd_speed:
	ld hl,p_fast
	call get_w
	call z,ident
	ld bc,15*256+30
	jp add_rand
rd_detect:								; detection(): everything in view
	call ident
	XCALL PAGE_SCROLL, sc_treasure
	XCALL PAGE_SCROLL, sc_objects
	XCALL PAGE_SCROLL, sc_doors
	call st_traps
	xor a
	ld hl,msg_sense_monsters
	jp show_monsters

; ---------------------------------------------------------------- using

/* device_skill - can the player work this device? (chance from WANDS.C,
	STAFFS.C, RODS.C) -> carry if so */
device_skill:
	ld a,(p_save)						; save + INT (x2 rods) - level (-5
	ld l,a								; staffs; rods at most 50)
	rla
	sbc a,a
	ld h,a
	ld a,(p_int_adj)
	ld e,a
	ld d,0
	add hl,de
	ld a,(d_action)
	cp PM_ZAP
	jr nz,.level
	add hl,de
.level:
	ld a,(d_action)
	cp PM_ZAP
	ld a,(u_level)
	jr nz,.no_cap
	cp 51
	jr c,.no_cap
	ld a,50
.no_cap:
	ld e,a
	ld d,0
	or a
	sbc hl,de
	ld a,(d_action)
	cp PM_USE
	jr nz,.class
	ld de,5
	or a
	sbc hl,de
.class:
	push hl								; + device skill * lev / 3
	ld a,(p_cla_dev)
	ld e,a
	ld a,(p_lev)
	ld d,a
	mul d,e
	ex de,hl
	ld c,3
	call div16_8
	pop de
	add hl,de
	ld de,(p_confused)					; halved when confused
	ld a,d
	or e
	jr z,.clear
	sra h
	rr l
.clear:
	bit 7,h								; at least 1
	jr nz,.one
	ld a,h
	or l
	jr nz,.roll
.one:
	ld hl,1
.roll:
	call randint16						; 1d(chance) must reach USE_DEVICE
	ld de,USE_DEVICE
	or a
	sbc hl,de
	ccf
	ret

/* free_turn - the player changed their mind: no turn passes */
free_turn:
	xor a
	ld (turn_taken),a
	ret

/* get_dir - "Which direction?" -> carry and A = 1-9 (not 5), d_dir set;
	no carry if cancelled. Confused, it goes a random way */
get_dir:
	ld hl,txt_which_dir
	call prompt
.key:
	call read_ascii
	cp '1'
	jr c,.letter
	cp '9'+1
	jr nc,.letter
	sub '0'
	cp 5
	jr z,.key
	jr .got
.letter:
	ld hl,dir_keys						; hjklyubn
	ld b,8
.find:
	cp (hl)
	jr z,.found
	inc hl
	inc hl
	djnz .find
	cp ' '								; space, Enter or Escape: never mind
	jr z,.cancel
	cp 13
	jr z,.cancel
	cp 27
	jr z,.cancel
	jr .key
.found:
	inc hl
	ld a,(hl)
.got:
	ld (d_dir),a
	call msg_clear
	ld hl,(p_confused)
	ld a,h
	or l
	jr z,.ok
	ld hl,msg_you_confused
	call msg_print
.random:
	ld a,9
	call randint
	cp 5
	jr z,.random
	ld (d_dir),a
.ok:
	ld a,(d_dir)
	scf
	ret
.cancel:
	call msg_clear
	or a
	ret
dir_keys:	db 'b',1, 'j',2, 'n',3, 'h',4, 'l',6, 'y',7, 'k',8, 'u',9

; ---------------------------------------------------------------- beams

/* beam_start - the beam starts on the player's square */
beam_start:
	ld a,(player_y)
	ld (d_y),a
	ld a,(player_x)
	ld (d_x),a
	xor a
	ld (d_dist),a
	ret

/* beam_square - HL = the map square at (d_y, d_x), D = y, E = x,
	A = its terrain flags (TF_). Clobbers BC */
beam_square:
	ld a,(d_y)
	ld d,a
	ld a,(d_x)
	ld e,a
	push de
	call map_addr
	pop de
	ld a,(hl)
	and TERRAIN_MASK
	jp terrain_flags

/* beam_step - one square on in d_dir, counting the distance */
beam_step:
	ld a,(d_dir)
	dec a
	add a,a
	ld hl,keypad_deltas
	add hl,a
	ld a,(d_y)
	add a,(hl)
	ld (d_y),a
	inc hl
	ld a,(d_x)
	add a,(hl)
	ld (d_x),a
	ld hl,d_dist
	inc (hl)
	ret

/* target_monster - along d_dir up to the bolt range until something
	closed: -> carry and IX = the first monster met */
target_monster:
	call beam_start
.step:
	call beam_step
	ld a,(d_dist)
	cp OBJ_BOLT_RANGE+1
	ret nc
	call beam_square
	bit TF_PASSABLE,a
	ret z
	bit F_MON_BIT,(hl)
	jr z,.step
	call mon_at
	ret

/* name_caps / name_lower - IX = monster: "The Kobold" / "the kobold"
	into the message being built */
name_caps:
	ld a,1
	jr name_it
name_lower:
	xor a
name_it:
	ld (name_cap),a
	call mon_race
	jp mon_name_to_msg

/* say_name - IX = monster, HL = the rest: "The Kobold" + text */
say_name:
	push hl
	call msg_begin
	call name_caps
	pop hl
	call msg_add
	jp msg_end

/* pain_add - IX = monster, DE = its hit points before: " grunts with
	pain." and so on added to the message (for throwing) */
pain_add:
	ld (d_oldhp),de
	call pain_message
	jp msg_add

/* say_victim - HL = text: "The Kobold" (remembered) + text. Names are
	taken before a monster is hurt: its death may say something first */
say_victim:
	push hl
	call msg_begin
	ld hl,d_victim_caps
	call msg_add
	pop hl
	call msg_add
	jp msg_end

/* fire_bolt - d_type, d_dam, d_name: the first monster in d_dir is hit
	(fire_bolt in SPELLS.C) */
fire_bolt:
	call target_monster
	ret nc
	call light_up						; you see what it hits
	call msg_begin						; "The Fire Bolt strikes the orc."
	ld hl,txt_the
	call msg_add
	ld hl,(d_name)
	call msg_add
	ld hl,txt_strikes
	call msg_add
	call name_lower
	ld hl,txt_full_stop
	call msg_add
	call msg_end
	call resisted						; immune: a ninth
	jr nc,.full
	ld hl,(d_dam)
	ld c,9
	call div16_8
	ld (d_dam),hl
.full:
	call remember_victim				; name it before it might die
	call mon_race
	ld a,(iy+R_FLAGS)
	ld (d_tmp),a
	ld hl,(d_dam)
	call hurt_monster
	jr nc,.alive
	ld hl,txt_dies_agony				; undead and demons are destroyed
	ld a,(d_tmp)
	and 1<<RF_UNDEAD|1<<RF_DEMON
	jr z,$+5
	ld hl,txt_is_destroyed
	jp say_victim
.alive:
	ld hl,(d_dam)
	ld a,h
	or l
	ret z
	call resisted
	ld hl,txt_looks_unharmed
	jp c,say_victim
	call pain_message
	jp say_victim

/* light_up - IX = monster: lit for a moment, so update_mon sees it */
light_up:
	ld d,(ix+M_Y)
	ld e,(ix+M_X)
	call map_addr
	ld a,(hl)
	push af
	push hl
	set F_LAMP_BIT,(hl)
	call update_mon
	pop hl
	pop af
	ld (hl),a
	ret

/* resisted - IX = monster, d_type -> carry if immune to it */
resisted:
	call mon_race
	ld a,(d_type)
	ld hl,gf_immunity
	add hl,a
	ld a,(hl)
	and (iy+R_RESIST)
	ret z								; (carry clear)
	scf
	ret
; the R_RESIST bit each GF_ type is stopped by
gf_immunity:	db 0, 1<<RR_LIGHTNING, 1<<RR_POISON, 1<<RR_ACID, 1<<RR_FROST, 1<<RR_FIRE

/* hurt_monster - IX = monster, HL = damage -> carry if it died. Remembers
	its hit points before, for pain_message. Quiet (callers speak) */
hurt_monster:
	ld e,(ix+M_HP)
	ld d,(ix+M_HP+1)
	ld (d_oldhp),de
	ld a,1
	ld (mth_quiet),a
	call mon_take_hit
	ld a,0
	ld (mth_quiet),a
	ret

/* pain_message - IX = monster just hurt (d_oldhp before) -> HL = " barely
	notices." and so on, by how much it has left and what it is */
pain_message:
	ld e,(ix+M_HP)						; percentage = hp * 100 / old hp
	ld d,(ix+M_HP+1)
	ld hl,(d_oldhp)
	ld a,h
	or l
	jr z,.unharmed
	push ix
	ld (ch_val),de
	ld hl,0
	ld (ch_val+2),hl
	ld bc,100
	call mul32_16
	ld de,(d_oldhp)
	call div32_16
	pop ix
	ld a,(ch_val)						; (at most 100)
	ld (d_pct),a
	call mon_race						; which set of sounds
	ld a,(iy+R_CHAR)
	ld hl,pain_quiet
	ld bc,5
	cpir
	ld hl,pains_quiet
	jr z,.level
	ld hl,pain_dogs
	ld bc,2
	cpir
	ld hl,pains_dogs
	jr z,.level
	ld hl,pain_beasts
	ld bc,15
	cpir
	ld hl,pains_beasts
	jr z,.level
	ld hl,pains_people
.level:									; >95, >75, >50, >35, >20, >10, else
	ld de,pain_levels
	ld a,(d_pct)
	ld b,a
.find:
	ld a,(de)
	cp $FF
	jr z,.got
	cp b
	jr c,.got
	inc de
	inc hl
	inc hl
	jr .find
.got:
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	ret
.unharmed:
	ld hl,txt_unharmed
	ret
pain_levels:	db 95,75,50,35,20,10,$FF
pain_quiet:		db "jQvme"			; molds and the like (not counting the
pain_dogs:		db "CZ"				; Beholder's name check)
pain_beasts:	db "KcaUqRXbFJlrsSt"
pains_quiet:	dw txt_p_barely, txt_p_flinches, txt_p_squelches, txt_p_draws_back
				dw txt_p_writhes, txt_p_writhes_agony, txt_p_jerks
pains_dogs:		dw txt_p_shrugs, txt_p_snarls, txt_p_yelps, txt_p_howls
				dw txt_p_howls_agony, txt_p_writhes_agony, txt_p_yelps_feebly
pains_beasts:	dw txt_p_ignores, txt_p_grunts, txt_p_squeals, txt_p_shrieks
				dw txt_p_shrieks_agony, txt_p_writhes_agony, txt_p_cries_feebly
pains_people:	dw txt_p_shrugs, txt_p_grunts, txt_p_cries_out, txt_p_screams
				dw txt_p_screams_agony, txt_p_writhes_agony, txt_p_cries_feebly

/* fire_ball - d_type, d_dam, d_name: flies in d_dir until it meets a
	monster or a wall, then bursts over radius 2 (fire_ball in SPELLS.C) */
fire_ball:
	call beam_start
.fly:
	ld a,(d_y)							; the square before
	ld (d_cy),a
	ld a,(d_x)
	ld (d_cx),a
	call beam_step
	ld a,(d_dist)
	cp OBJ_BOLT_RANGE+1
	ret nc								; off into the distance
	call beam_square
	bit TF_PASSABLE,a
	jr z,.burst							; a wall: bursts in front of it
	bit F_MON_BIT,(hl)
	jr z,.fly
	ld a,(d_y)
	ld (d_cy),a
	ld a,(d_x)
	ld (d_cx),a
.burst:
	xor a
	ld (d_hits),a
	ld (d_kills),a
	ld a,-2
	ld (d_by),a
.row:
	ld a,-2
	ld (d_bx),a
.col:
	call burst_square
	ld hl,d_bx
	inc (hl)
	ld a,(hl)
	cp 3
	jr nz,.col
	ld hl,d_by
	inc (hl)
	ld a,(hl)
	cp 3
	jr nz,.row
	ld a,(d_hits)						; what was hit
	or a
	jr z,.screams
	dec a
	jr nz,.several
	call msg_begin						; "The Fire Ball envelopes the orc!"
	ld hl,txt_the
	call msg_add
	ld hl,(d_name)
	call msg_add
	ld hl,txt_envelopes
	call msg_add
	ld hl,d_victim
	call msg_add
	ld hl,txt_bang
	call msg_add
	call msg_end
	ld a,(d_kills)
	or a
	jr nz,.screams
	call msg_begin						; and how it took it
	ld hl,d_victim_caps
	call msg_add
	ld hl,(d_victim_says)
	call msg_add
	call msg_end
	jr .screams
.several:
	call msg_begin
	ld hl,txt_the
	call msg_add
	ld hl,(d_name)
	call msg_add
	ld hl,txt_envelopes_several
	call msg_add
	call msg_end
.screams:
	ld a,(d_kills)
	or a
	ret z
	dec a
	ld hl,msg_scream
	jp z,msg_print
	ld hl,msg_screams
	jp msg_print

/* burst_square - (d_cy + d_by, d_cx + d_bx), if within 2 of the centre
	and in its line of sight: items burn, monsters are hurt */
burst_square:
	ld a,(d_cy)
	ld hl,d_by
	add a,(hl)
	ld d,a
	ld a,(d_cx)
	ld hl,d_bx
	add a,(hl)
	ld e,a
	call in_bounds
	ret nc
	ld (d_sq),de
	call from_centre					; distance and sight from the centre
	ld (d_sqdist),a
	cp 3
	ret nc
	ld de,(d_sq)
	call item_at						; things that burn, freeze...
	call c,destroy_item
	ld de,(d_sq)
	call map_addr
	ld a,(hl)
	and TERRAIN_MASK
	push hl
	call terrain_flags
	pop hl
	bit TF_PASSABLE,a
	jr z,.doors
	ld a,(hl)
	and TERRAIN_MASK
	cp T_DOOR_OPEN
	call z,.burn_door
	bit F_MON_BIT,(hl)
	ret z
	ld de,(d_sq)
	call mon_at
	ret nc
	call light_up
	ld hl,d_hits
	inc (hl)
	ld a,(hl)
	dec a
	call z,remember_victim
	call resisted						; immune: a ninth
	ld hl,(d_dam)
	jr nc,.full
	ld c,9
	call div16_8
.full:
	ld a,(d_sqdist)						; / (distance + 1)
	inc a
	ld c,a
	call div16_8
	ld (d_hit),hl
	call hurt_monster
	jr nc,.alive
	ld hl,d_kills
	inc (hl)
	ret
.alive:
	ld a,(d_hits)						; the first one's reaction
	dec a
	ret nz
	call resisted
	ld hl,txt_looks_unharmed
	jr c,.said
	ld hl,(d_hit)
	ld a,h
	or l
	ld hl,txt_unharmed
	jr z,.said
	call pain_message
.said:
	ld (d_victim_says),hl
	ret
.doors:
	ld a,(hl)
	and TERRAIN_MASK
	cp T_DOOR_CLOSED
	ret nz
.burn_door:								; fire and acid burn doors away
	ld a,(d_type)
	cp GF_FIRE
	jr z,.burn
	cp GF_ACID
	ret nz
.burn:
	ld a,(hl)
	and ~TERRAIN_MASK
	or T_CORRIDOR
	ld (hl),a
	ret

/* remember_victim - IX = the first monster a ball hits: its names */
remember_victim:
	call msg_begin
	call name_lower
	ld hl,(msg_ptr)
	ld (hl),0
	ld hl,msg_buf
	ld de,d_victim
	ld bc,32
	ldir
	call msg_begin
	call name_caps
	ld hl,(msg_ptr)
	ld (hl),0
	ld hl,msg_buf
	ld de,d_victim_caps
	ld bc,32
	ldir
	ld hl,txt_looks_unharmed
	ld (d_victim_says),hl
	ret

/* from_centre - (d_sq) -> A = its distance from the burst's centre, 255
	if the centre can't see it (the player stands in for the centre) */
from_centre:
	ld hl,(player_x)					; (player_x, player_y)
	push hl
	ld a,(d_cy)
	ld (player_y),a
	ld a,(d_cx)
	ld (player_x),a
	ld de,(d_sq)
	call mon_distance
	ld (d_tmp),a
	ld de,(d_sq)
	call los
	pop hl
	ld (player_x),hl
	ld a,(d_tmp)
	ret c
	ld a,255
	ret

/* destroy_item - IX = an item in the burst: gone if the element destroys
	its kind (SETS.C set_*_destroy) */
destroy_item:
	ld a,(ix+I_KIND_HI)
	cp KIND_GOLD
	ret z
	call item_kind_addr
	ld a,(d_type)
	add a,a
	ld hl,destroy_lists
	add hl,a
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	ld a,(iy+K_TVAL)
.scan:
	cp (hl)
	jr z,.gone
	inc (hl)
	dec (hl)
	ret z
	inc hl
	jr .scan
.gone:
	ld (ix+I_KIND_HI),ITEM_EMPTY
	ret
destroy_lists:	dw destroys_none, destroys_lightning, destroys_none, destroys_acid
				dw destroys_frost, destroys_fire
destroys_none:	db 0
destroys_lightning: db 65,66,45,0			; wands, rods, rings
destroys_acid:	db 12,20,21,22,30,31,32,33,34,35,36,70,71,80,55,0
destroys_frost:	db 75,76,77,0				; potions, flasks
destroys_fire:	db 12,20,21,22,30,31,32,36,55,70,71,75,76,77,80,0

/* light_line - A = direction: lights squares from the player until a
	wall; light-hating monsters suffer (light_line in SPELLS.C) */
light_line:
	ld (d_dir),a
	call beam_start
.square:
	ld a,(d_dist)
	cp OBJ_BOLT_RANGE+1
	ret nc
	call beam_square
	bit TF_PASSABLE,a
	ret z
	ld a,(hl)
	and F_SEEN
	jr nz,.lit
	ld a,(hl)
	and TERRAIN_MASK
	cp T_FLOOR_LIT
	jr nz,.lit
	push hl
	call dv_in_view
	pop hl
	jr nc,.lit
	push hl
	call light_room
	pop hl
.lit:
	set F_PERM_BIT,(hl)
	bit F_MON_BIT,(hl)
	jr z,.next
	ld a,(d_y)
	ld d,a
	ld a,(d_x)
	ld e,a
	call mon_at
	jr nc,.next
	call update_mon
	ld (ix+M_SLEEP),0
	ld (ix+M_SLEEP+1),0
	call mon_race
	bit RR_HURT_LIGHT,(iy+R_RESIST)
	jr z,.next
	call remember_victim
	ld bc,6*256+8
	call damroll
	call hurt_monster
	ld hl,txt_shrivels
	jr c,$+5
	ld hl,txt_cringes
	call say_victim
.next:
	call beam_step
	jr .square

/* dv_in_view - D = y, E = x -> carry if it's within the view */
dv_in_view:
	ld a,(view_y)
	ld b,a
	ld a,d
	sub b
	jr c,.no
	cp VIEW_H
	ret nc
	ld a,(view_x)
	ld b,a
	ld a,e
	sub b
	jr c,.no
	cp VIEW_W
	ret
.no:
	or a
	ret

/* wall_to_mud - walls in d_dir melt (and rock-eaters suffer) -> carry if
	the player saw a wall go */
wall_to_mud:
	xor a
	ld (d_any),a
	call beam_start
.step:
	call beam_step
	call beam_square
	ld a,(hl)
	and TERRAIN_MASK
	cp T_PERMWALL
	jr nz,.not_perm
	ld a,(hl)
	and F_SEEN
	ld hl,msg_wall_resists
	call nz,msg_print
	jp .done
.not_perm:
	cp T_GRANITE
	jr z,.wall
	cp T_MAGMA
	jr z,.wall
	cp T_QUARTZ
	jr z,.wall
	cp T_DOOR_CLOSED
	jr z,.door
	cp T_DOOR_SECRET
	jr z,.door
	call .rock_eater
	ld a,(d_dist)
	cp OBJ_BOLT_RANGE
	jr c,.step
	jp .done
.wall:
	call .melt
	ld a,(hl)
	and F_SEEN
	jr z,.walled
	push hl
	ld hl,msg_wall_mud
	call msg_print
	pop hl
	ld a,1
	ld (d_any),a
.walled:
	call .rock_eater
	jp .done
.door:
	call .melt
	ld a,(hl)
	and F_SEEN
	jr z,.walled
	ld a,1
	ld (d_any),a
	ld hl,msg_door_mud
	call msg_print
	jr .walled
.melt:									; floor, or room floor in a room
	ld a,(hl)
	and ~TERRAIN_MASK
	bit F_ROOM_BIT,a
	ld b,T_CORRIDOR
	jr z,$+4
	ld b,T_FLOOR
	or b
	ld (hl),a
	ret
.rock_eater:							; HURT_ROCK: 20 + 1d30
	call beam_square
	bit F_MON_BIT,(hl)
	ret z
	call mon_at
	ret nc
	call mon_race
	bit RR_HURT_ROCK,(iy+R_RESIST)
	ret z
	ld a,(ix+M_ML)
	ld (d_seen),a
	call remember_victim
	ld a,30
	call randint
	add a,20
	ld l,a
	ld h,0
	call hurt_monster
	ld hl,txt_dissolves_d
	jr c,$+5
	ld hl,txt_grunts
	ld a,(d_seen)
	or a
	call nz,say_victim
	pop hl								; (a rock-eater stops the ray)
	jp .done
.done:
	ld a,(d_any)
	or a
	ret z
	scf
	ret

/* td_destroy2 - doors in d_dir are destroyed -> carry if any */
td_destroy2:
	xor a
	ld (d_any),a
	call beam_start
.step:
	call beam_step
	call beam_square
	ld b,a								; (terrain flags)
	call trap_flash						; traps go too (and chests)
	jr c,.flash
	ld a,(hl)
	and TERRAIN_MASK
	cp T_DOOR_CLOSED
	jr c,.on
	cp T_DOOR_SECRET+1
	jr nc,.on
	ld a,(hl)
	and ~TERRAIN_MASK
	or T_CORRIDOR
	ld (hl),a
.flash:
	ld hl,msg_bright_flash_d
	call msg_print
	ld a,1
	ld (d_any),a
	ld b,1<<TF_PASSABLE
.on:									; on while in range or still open
	ld a,(d_dist)
	cp OBJ_BOLT_RANGE+1
	jr c,.step
	bit TF_PASSABLE,b
	jr nz,.step
	ld a,(d_any)
	or a
	ret z
	scf
	ret

/* disarm_all - from your square along d_dir: secret doors are found
	-> carry if any */
disarm_all:
	xor a
	ld (d_any),a
	call beam_start
.square:
	call beam_square
	ld b,a
	call trap_click						; traps are disarmed (chests too)
	jr c,.any
	ld a,(hl)
	and TERRAIN_MASK
	cp T_DOOR_SECRET
	jr nz,.next
	ld a,(hl)
	and ~TERRAIN_MASK
	or T_DOOR_CLOSED|F_PERM
	ld (hl),a
.any:
	ld a,1
	ld (d_any),a
.next:
	ld a,(d_dist)
	cp OBJ_BOLT_RANGE+1
	jr nc,.done
	bit TF_PASSABLE,b
	jr z,.done
	call beam_step
	jr .square
.done:
	ld a,(d_any)
	or a
	ret z
	scf
	ret

; ---------------------------------------------------------------- monsters

/* saves - IX = monster -> carry if it resists: level > 1d(max(lev-10,1))
	+ 10, or a unique */
saves:
	call mon_race
	bit RF_UNIQUE,(iy+R_FLAGS)
	scf
	ret nz
	ld a,(p_lev)
	sub 10
	jr c,.one
	jr nz,.roll
.one:
	ld a,1
.roll:
	call randint
	add a,10
	cp (iy+R_LEVEL)						; carry if 1d(..)+10 < level
	ret

haste_one:
	call ident
	inc (ix+M_SPEED)
	call wake
	ld hl,txt_faster
	jp say_name
slow_one:
	call saves
	jr c,unaffected
	call ident
	dec (ix+M_SPEED)
	call wake
	ld hl,txt_slower
	jp say_name
confuse_one:
	call saves
	jr c,unaffected
	call ident
	ld (ix+M_CONFUSED),1
	call wake
	ld hl,txt_confused_d
	jp say_name
sleep_one:
	call saves
	jr c,unaffected
	bit RF_CHARM_SLEEP,(iy+R_FLAGS)
	jr nz,unaffected
	call ident
	ld (ix+M_SLEEP),low 500
	ld (ix+M_SLEEP+1),high 500
	ld hl,txt_falls_asleep
	jp say_name
unaffected:
	ld hl,txt_unaffected_d
	jp say_name
wake:
	ld (ix+M_SLEEP),0
	ld (ix+M_SLEEP+1),0
	ret

/* drain_one - IX = monster, d_dam: the living lose hit points */
drain_one:
	call mon_race
	ld a,(iy+R_FLAGS)
	and 1<<RF_UNDEAD|1<<RF_DEMON
	ret nz
	call ident
	call remember_victim
	ld hl,(d_dam)
	call hurt_monster
	ld hl,txt_dies_agony
	jp c,say_victim
	call pain_message
	jp say_victim

/* poly_monster - IX = monster: unless it saves, a random other one */
poly_monster:
	call mon_race
	bit RF_UNIQUE,(iy+R_FLAGS)
	jr nz,unaffected
	ld a,(p_lev)						; level < 1d(max(lev-10,1)) + 10
	sub 10
	jr c,.one
	jr nz,.roll
.one:
	ld a,1
.roll:
	call randint
	add a,10
	cp (iy+R_LEVEL)
	jr c,unaffected
	jr z,unaffected
	ld d,(ix+M_Y)
	ld e,(ix+M_X)
	push de
	XCALL PAGE_LEVEL, poly_at
	pop de
	call map_addr						; seen happening?
	ld a,(hl)
	and F_SEEN
	ret z
	jp ident

/* teleport_away - IX = monster: somewhere up to 100 squares off
	(teleport_away in SPELLS.C) */
teleport_away:
	ld a,MAX_SIGHT*5
	ld (d_tdis),a
	xor a
	ld (d_tries),a
.try:
	ld a,(d_tdis)						; yn = fy + 1d(2*dis+1) - (dis+1)
	call offset_by
	add a,(ix+M_Y)
	ld d,a
	push de
	ld a,(d_tdis)
	call offset_by
	pop de
	add a,(ix+M_X)
	ld e,a
	call in_bounds
	jr nc,.try
	ld hl,d_tries						; every 10 tries, further
	inc (hl)
	ld a,(hl)
	cp 10
	jr c,.check
	ld (hl),0
	ld a,(d_tdis)
	add a,5
	jr c,.check
	ld (d_tdis),a
.check:
	push de
	call map_addr
	pop de
	ld a,(hl)
	bit F_MON_BIT,a
	jr nz,.try
	and TERRAIN_MASK
	push hl
	call terrain_flags
	pop hl
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

/* offset_by - A = dis (up to 127) -> A = 1d(2*dis+1) - (dis+1), signed */
offset_by:
	ld c,a
	add a,a
	inc a
	jr nc,$+4
	ld a,255
	push bc
	call randint
	pop bc
	sub c
	dec a
	ret

/* for_each_monster - HL = routine called with IX for every monster in
	sight of the player (los; within 100) -> d_any set by the routine */
in_sight_each:
	ld (d_each),hl
	xor a
	ld (d_any),a
	ld ix,MON_LIST
	ld b,MON_MAX
.each:
	push bc
	ld a,(ix+M_RACE_HI)
	cp MON_EMPTY
	jr z,.next
	ld a,(ix+M_CDIS)
	cp 100
	jr nc,.next
	ld d,(ix+M_Y)
	ld e,(ix+M_X)
	call los
	jr nc,.next
	ld hl,(d_each)
	call .go
.next:
	ld de,MON_SIZE
	add ix,de
	pop bc
	djnz .each
	ld a,(d_any)
	or a
	ret z
	scf
	ret
.go:
	jp (hl)

/* speed_monsters - A = +1 or -1: everything in sight (speed_monsters) */
speed_monsters:
	ld (d_spd),a
	ld hl,.one
	jp in_sight_each
.one:
	ld a,(d_spd)
	cp 1
	jr nz,.slower
	inc (ix+M_SPEED)
	call wake
	ld a,(ix+M_ML)
	or a
	ret z
	ld (d_any),a
	ld hl,txt_faster
	jp say_name
.slower:
	call saves
	jr c,.resists
	dec (ix+M_SPEED)
	call wake
	ld a,(ix+M_ML)
	or a
	ret z
	ld (d_any),a
	ld hl,txt_slower
	jp say_name
.resists:
	ld a,(ix+M_ML)
	or a
	ret z
	jp unaffected

/* sleep_monsters - everything in sight may fall asleep (sleep_monsters2) */
sleep_monsters:
	ld hl,.one
	jp in_sight_each
.one:
	call saves
	jr c,.resists
	bit RF_CHARM_SLEEP,(iy+R_FLAGS)
	jr nz,.resists
	ld (ix+M_SLEEP),low 500
	ld (ix+M_SLEEP+1),high 500
	ld a,(ix+M_ML)
	or a
	ret z
	ld (d_any),a
	ld hl,txt_falls_asleep
	jp say_name
.resists:
	ld a,(ix+M_ML)
	or a
	ret z
	jp unaffected

/* probing - "The orc has 12 hit points." for each visible one in sight */
probing:
	ld hl,msg_probing
	call msg_print
	ld hl,.one
	call in_sight_each
	ld hl,msg_thats_all
	jp c,msg_print
	ld hl,msg_nothing_probe
	jp msg_print
.one:
	ld a,(ix+M_ML)
	or a
	ret z
	ld (d_any),a
	call msg_begin
	call name_caps
	ld hl,txt_has_
	call msg_add
	ld l,(ix+M_HP)
	ld h,(ix+M_HP+1)
	call msg_add_u16_d
	ld hl,txt_hit_points
	call msg_add
	jp msg_end

/* msg_add_u16_d - HL = number into the message being built */
msg_add_u16_d:
	ld de,(msg_ptr)
	ld bc,10000
	call .digit
	ld bc,1000
	call .digit
	ld bc,100
	call .digit
	ld bc,10
	call .digit
	ld a,l
	add a,'0'
	ld (de),a
	inc de
	ld (msg_ptr),de
	xor a
	ld (d_digits),a
	ret
.digit:
	ld a,'0'-1
.sub:
	inc a
	or a
	sbc hl,bc
	jr nc,.sub
	add hl,bc
	cp '0'
	jr nz,.put
	ld a,(d_digits)
	or a
	ret z
	ld a,'0'
.put:
	ld (de),a
	inc de
	ld a,1
	ld (d_digits),a
	ret

/* detect_evil - evil monsters in view are shown until a key */
detect_evil:
	ld a,1<<RF_EVIL
	ld hl,msg_sense_evil
/* show_monsters - A = R_FLAGS mask (0: all), HL = message: those in view
	are drawn, then forgotten after a key -> carry if any */
show_monsters:
	ld (d_mask),a
	ld (d_name),hl
	xor a
	ld (d_any),a
	ld ix,MON_LIST
	ld b,MON_MAX
.each:
	push bc
	ld a,(ix+M_RACE_HI)
	cp MON_EMPTY
	jr z,.next
	call mon_race
	ld a,(d_mask)
	or a
	jr z,.this
	and (iy+R_FLAGS)
	jr z,.next
.this:
	ld d,(ix+M_Y)
	ld e,(ix+M_X)
	call dv_in_view
	jr nc,.next
	ld (ix+M_ML),1
	ld a,(view_y)
	ld b,a
	ld a,d
	sub b
	add a,VIEW_TOP
	ld d,a
	ld a,(view_x)
	ld b,a
	ld a,e
	sub b
	ld e,a
	call screen_addr
	push hl
	call mon_race
	pop hl
	ld a,(iy+R_CHAR)
	ld (hl),a
	inc hl
	ld a,(iy+R_ATTR)
	ld (hl),a
	ld a,1
	ld (d_any),a
.next:
	ld de,MON_SIZE
	add ix,de
	pop bc
	djnz .each
	ld a,(d_any)
	or a
	ret z
	ld hl,(d_name)
	call msg_print
	call msg_flush
	call monsters_see_all
	scf
	ret

/* earthquake - the ground within 8 heaves: walls fall, floors rise
	(earthquake in SPELLS.C; a monster that survives keeps its floor) */
earthquake:
	ld a,-8
	ld (d_by),a
.row:
	ld a,-8
	ld (d_bx),a
.col:
	ld a,(d_by)
	or a
	jr nz,.not_you
	ld a,(d_bx)
	or a
	jr z,.next
.not_you:
	ld a,8
	call randint
	dec a
	jr nz,.next
	ld a,(player_y)
	ld hl,d_by
	add a,(hl)
	ld d,a
	ld a,(player_x)
	ld hl,d_bx
	add a,(hl)
	ld e,a
	call in_bounds
	jr nc,.next
	ld (d_sq),de
	call quake_square
.next:
	ld hl,d_bx
	inc (hl)
	ld a,(hl)
	cp 9
	jr nz,.col
	ld hl,d_by
	inc (hl)
	ld a,(hl)
	cp 9
	jr nz,.row
	jp monsters_see_all

quake_square:
	ld de,(d_sq)
	call item_at
	jr nc,.no_item
	ld (ix+I_KIND_HI),ITEM_EMPTY
.no_item:
	ld de,(d_sq)
	call map_addr
	bit F_MON_BIT,(hl)
	jr z,.ground
	ld de,(d_sq)
	call mon_at
	jr nc,.ground
	call mon_race
	ld a,(iy+R_FLAGS2)
	and 1<<RF2_PHASE|1<<RF2_BREAK_WALL
	jr nz,.ground
	call msg_begin						; "The orc wails out in pain!"
	call name_caps
	ld hl,txt_wails_pain
	call msg_add
	call msg_end
	ld bc,4*256+8						; 320 if it can't get away
	call damroll
	bit RM_ONLY_ATT,(iy+R_MOVE)
	jr z,$+5
	ld hl,320
	push hl
	call remember_victim				; (name for the epitaph)
	pop hl
	call hurt_monster
	ret nc								; alive: its square stays open
	ld hl,txt_embedded
	call say_victim
.ground:
	ld de,(d_sq)
	call map_addr
	ld a,(hl)
	and TERRAIN_MASK
	cp T_PERMWALL
	ret z
	cp T_GRANITE
	jr z,.fall
	cp T_MAGMA
	jr z,.fall
	cp T_QUARTZ
	jr z,.fall
	push hl
	ld hl,quake_open
	add hl,a
	ld a,(hl)
	pop hl
	or a
	ret z
	push hl								; floor becomes rock
	ld a,10
	call randint
	pop hl
	ld b,T_QUARTZ
	cp 6
	jr c,.rock
	ld b,T_MAGMA
	cp 9
	jr c,.rock
	ld b,T_GRANITE
.rock:
	ld a,(hl)
	and $FF & ~(TERRAIN_MASK|F_PERM)
	or b
	ld (hl),a
	ret
.fall:									; rock becomes floor
	ld a,(hl)
	and $FF & ~(TERRAIN_MASK|F_PERM)
	or T_CORRIDOR
	ld (hl),a
	ret
; floor that heaves up (fval <= MAX_CAVE_FLOOR): floors and corridor, and
; what stands on them in the C (doors, stairs)
quake_open:		db 0,1,1,0,0,1,1,1,1,1,0,0,0,0,1,0

; ---------------------------------------------------------------- text

msg_wand_failed:	db "You failed to use the wand properly.",0
msg_wand_empty:		db "The wand has no charges left.",0
msg_staff_failed:	db "You failed to use the staff properly.",0
msg_staff_empty:	db "The staff has no charges left.",0
msg_rod_failed:		db "You failed to use the rod properly.",0
msg_rod_exhausted:	db "The rod is currently exhausted.",0
msg_you_confused:	db "You are confused.",0
txt_which_dir:		db "Which direction? (1-9 or hjklyubn, space cancels)",0
msg_blue_line:		db "A line of blue shimmering light appears.",0
msg_staff_bursts:	db "The end of the staff bursts into a blue shimmering light.",0
msg_head_stops_d:	db "You're head stops stinging.",0
msg_feel_better_d:	db "You feel better.",0
msg_warm_feeling_d:	db "You have a warm feeling.",0
msg_sense_evil:		db "You sense the presence of evil!",0
msg_sense_monsters:	db "You sense the presence of monsters!",0
msg_probing:		db "Probing...",0
msg_thats_all:		db "That's all.",0
msg_nothing_probe:	db "You find nothing to probe.",0
msg_scream:			db "There is a scream of agony!",0
msg_screams:		db "There are several screams of agony!",0
msg_wall_resists:	db "The wall resists your spell.",0
msg_wall_mud:		db "The wall turns into mud.",0
msg_door_mud:		db "The door turns into mud.",0
msg_bright_flash_d:	db "There is a bright flash of light!",0
txt_you_have_:		db "You have ",0
txt_charges_remaining: db " charges remaining.",0
txt_strikes:		db " strikes ",0
txt_envelopes:		db " envelopes ",0
txt_envelopes_several: db " envelopes several creatures!",0
txt_bang:			db "!",0
txt_dies_agony:		db " dies in a fit of agony.",0
txt_is_destroyed:	db " is destroyed.",0
txt_looks_unharmed:	db " looks unharmed.",0
txt_unharmed:		db " is unharmed.",0
txt_shrivels:		db " shrivels away in the light!",0
txt_cringes:		db " cringes from the light!",0
txt_dissolves_d:	db " dissolves!",0
txt_grunts:			db " grunts in pain!",0
txt_faster:			db " starts moving faster.",0
txt_slower:			db " starts moving slower.",0
txt_confused_d:		db " appears confused.",0
txt_falls_asleep:	db " falls asleep.",0
txt_unaffected_d:	db " is unaffected.",0
txt_runs_frantically: db " runs frantically!",0
msg_banished:	db "The Power of your god banishes the creatures!",0
txt_has_:			db " has ",0
txt_hit_points:		db " hit points.",0
txt_wails_pain:		db " wails out in pain!",0
txt_embedded:		db " is embedded in the rock.",0
txt_magic_missile:	db "Magic Missile",0
txt_lightning_bolt:	db "Lightning Bolt",0
txt_frost_bolt:		db "Frost Bolt",0
txt_fire_bolt:		db "Fire Bolt",0
txt_acid_bolt:		db "Acid Bolt",0
txt_lightning_ball:	db "Lightning Ball",0
txt_cold_ball:		db "Cold Ball",0
txt_fire_ball:		db "Fire Ball",0
txt_acid_ball:		db "Acid Ball",0
txt_stinking_cloud:	db "Stinking Cloud",0
txt_huge_fire:		db "huge ball of Fire",0
txt_huge_frost:		db "huge ball of Frost",0
txt_huge_acid:		db "huge ball of Acid",0
txt_huge_lightning:	db "huge ball of Lightning",0
txt_huge_gas:		db "huge ball of Gas",0
txt_p_barely:		db " barely notices.",0
txt_p_flinches:		db " flinches.",0
txt_p_squelches:	db " squelches.",0
txt_p_draws_back:	db " draws back in pain.",0
txt_p_writhes:		db " writhes about.",0
txt_p_writhes_agony: db " writhes in agony.",0
txt_p_jerks:		db " jerks limply.",0
txt_p_shrugs:		db " shrugs off the attack.",0
txt_p_snarls:		db " snarls with pain.",0
txt_p_yelps:		db " yelps in pain.",0
txt_p_howls:		db " howls in pain.",0
txt_p_howls_agony:	db " howls in agony.",0
txt_p_yelps_feebly:	db " yelps feebly.",0
txt_p_ignores:		db " ignores the attack.",0
txt_p_grunts:		db " grunts with pain.",0
txt_p_squeals:		db " squeals in pain.",0
txt_p_shrieks:		db " shrieks in pain.",0
txt_p_shrieks_agony: db " shrieks in agony.",0
txt_p_cries_feebly:	db " cries out feebly.",0
txt_p_cries_out:	db " cries out in pain.",0
txt_p_screams:		db " screams in pain.",0
txt_p_screams_agony: db " screams in agony.",0

; ---------------------------------------------------------------- variables

d_action:		db 0
d_effect:		db 0
d_wonder:		db 0
d_used:			db 0
d_dir:			db 0
d_y:			db 0
d_x:			db 0
d_dist:			db 0
d_type:			db 0
d_dam:			dw 0
d_hit:			dw 0
d_name:			dw 0
d_oldhp:		dw 0
d_pct:			db 0
d_cy:			db 0
d_cx:			db 0
d_by:			db 0
d_bx:			db 0
d_sq:			dw 0				; (x, y) of a square in the burst
d_sqdist:		db 0
d_hits:			db 0
d_kills:		db 0
d_tmp:			db 0
d_star:			db 0
d_any:			db 0
d_seen:			db 0
d_spd:			db 0
d_mask:			db 0
d_each:			dw 0
d_tdis:			db 0
d_tries:		db 0
d_digits:		db 0
d_victim_says:	dw 0
d_victim:		ds 32
d_victim_caps:	ds 32
