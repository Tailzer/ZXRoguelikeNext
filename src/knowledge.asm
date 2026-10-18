/* knowledge.asm - Self Knowledge  [overlay: PAGE_ITEMS]
	Reference: SPELLS.C self_knowledge. The potions of Self Knowledge and
	*Enlightenment* reach it with OVCALL; it's here, beside calc_bonuses,
	because what it lists is mostly what equipment gives.
 */

/* self_knowledge - list what the player knows of their own state over
	the map (SPELLS.C) */
self_knowledge:
	ld d,VIEW_TOP
.clear:
	push de
	call clear_row
	pop de
	inc d
	ld a,d
	cp VIEW_TOP+VIEW_H
	jr c,.clear
	ld hl,txt_attributes
	ld d,VIEW_TOP
	ld e,20
	ld c,ATTR_YELLOW
	call print_at
	ld a,VIEW_TOP+1
	ld (sk_row),a
	ld ix,knowledge
.each:
	ld a,(ix+2)
	cp $FF
	jp z,.done
	ld c,0								; C = 1 if its counter is running
	ld l,(ix+0)
	ld h,(ix+1)
	ld a,h
	or l
	jr z,.flag
	call get_w
	jr z,.flag
	inc c
.flag:
	call sk_flag						; carry if its flag is set
	bit 6,(ix+3)
	jr z,.either
	jp nc,.next							; both: counter and flag, and then
	ld a,c								; not the next line
	or a
	jp z,.next
	call .show
	ld de,SK_SIZE
	add ix,de
	jp .next
.either:
	push af
	ld a,(ix+2)							; an immunity: then not the
	cp $F9								; resistances after it
	jr c,.not_immune
	cp $FB
	jr nc,.not_immune
	pop af
	jp nc,.next
	call .show
	ld a,(ix+2)
	sub $F8								; ($FA skip 2, $F9 skip 1)
	ld b,a
.skip:
	ld de,SK_SIZE
	add ix,de
	djnz .skip
	jp .next
.not_immune:
	pop af
	jr c,.shown
	ld a,c
	or a
	jr nz,.shown
	ld a,(ix+2)							; or a race's gift
	cp $FE
	jr z,.infra
	cp $FC
	jr z,.slay
	cp $FB
	jr z,.foul
	ld b,a
	ld a,(p_race)
	cp b
	jr z,.shown
	jr .next
.infra:
	ld a,(p_infra)
	or a
	jr z,.next
	jr .shown
.slay:									; the weapon's slays (w_slays bit)
	ld a,(ix+3)
	and $3F
	inc a
	ld b,a
	ld hl,(w_slays)
.slay_bit:
	srl h
	rr l
	djnz .slay_bit
	jr nc,.next
	jr .shown
.foul:									; a cursed weapon
	ld a,(EQUIP+EQ_WEAPON*ITEM_SIZE+I_KIND_HI)
	cp ITEM_EMPTY
	jr z,.next
	ld a,(EQUIP+EQ_WEAPON*ITEM_SIZE+I_IDENT)
	bit ID_CURSED_BIT,a
	jr z,.next
	ld hl,txt_sk_foul
	ld a,(EQUIP+EQ_WEAPON*ITEM_SIZE+I_NAME2)
	cp SN_MORGUL
	jr z,.say
	ld hl,txt_sk_calris
	cp SN_CALRIS
	jr z,.say
	ld hl,txt_sk_mormegil
	cp SN_MORMEGIL
	jr z,.say
	ld hl,txt_sk_accursed
.say:
	ld (ix+4),l							; (the table is in RAM)
	ld (ix+5),h
.shown:
	call .show
.next:
	ld de,SK_SIZE
	add ix,de
	jp .each
.done:
	ld a,(sk_row)
	inc a
	ld d,a
	ld e,15
	ld hl,txt_press_key
	ld c,ATTR_GREY
	call print_at
	jp wait_fresh_key
.show:
	ld a,(sk_row)
	cp VIEW_TOP+VIEW_H-2				; (no more than fits)
	ret nc
	ld l,(ix+4)
	ld h,(ix+5)
	ld d,a
	inc a
	ld (sk_row),a
	ld e,15
	ld c,ATTR_WHITE
	jp print_at

/* sk_flag - IX = knowledge entry -> carry if its flag is set: 0-31 a bit
	of p_eflags, 32-56 a bit of p_eflags2, 57-62 a sustained stat, bit 7
	none */
sk_flag:
	ld a,(ix+3)
	bit 7,a
	jr nz,.no
	and $3F
	ld hl,p_eflags
	cp 32
	jr c,.bits
	cp SK_SUST
	jr nc,.sustain
	sub 32								; 32-56: flags2
	ld hl,p_eflags2
.bits:
	ld b,a
	srl a
	srl a
	srl a
	add hl,a
	ld a,b
	and 7
	ld b,a
	ld a,(hl)
.rot:
	inc b
.bit:
	rrca
	djnz .bit
	ret
.sustain:
	sub SK_SUST
	ld b,a
	ld a,(p_sustain)
	jr .rot
.no:
	or a
	ret

; counter (0 = none), race ($FD = none, $FE = has infravision, $FC the
; weapon's slay in flag's low bits, $FB a cursed weapon, $FA/$F9 an
; immunity: shown if its flag is, and then not the 2/1 lines after), flag (SK_),
; text: shown if the counter is running, the race has it or the flag is set;
; SK_BOTH: only if counter and flag both are, and then not the next line
SK_SIZE			equ 6
SK_NONE			equ $80
SK_BOTH			equ $40
SK_F2			equ 32
SK_SUST			equ 57
	MACRO SK counter, race, flag, text
		dw counter
		db race, flag
		dw text
	ENDM
knowledge:
	SK p_blind, $FD, SK_NONE, txt_sk_blind
	SK p_confused, $FD, SK_NONE, txt_sk_confused
	SK p_afraid, $FD, SK_NONE, txt_sk_afraid
	SK p_cut, $FD, SK_NONE, txt_sk_cut
	SK p_stun, $FD, SK_NONE, txt_sk_stun
	SK p_poisoned, $FD, SK_NONE, txt_sk_poisoned
	SK 0, $FD, 9, txt_sk_aggravate
	SK 0, $FD, 10, txt_sk_teleport
	SK p_blessed, $FD, SK_NONE, txt_sk_blessed
	SK p_hero, $FD, SK_NONE, txt_sk_hero
	SK p_shero, $FD, SK_NONE, txt_sk_shero
	SK p_protevil, $FD, SK_NONE, txt_sk_protevil
	SK p_shield, $FD, SK_NONE, txt_sk_shield
	SK p_invuln, $FD, SK_NONE, txt_sk_invuln
	SK p_confuse_mon, $FD, SK_NONE, txt_sk_glowing
	SK p_word_recall, $FD, SK_NONE, txt_sk_recall
	SK 0, $FD, 8, txt_sk_stealth
	SK 0, $FD, 6, txt_sk_search
	SK p_tim_infra, $FE, SK_NONE, txt_sk_infra
	SK p_detect_inv, $FD, 24, txt_sk_see_inv
	SK 0, $FD, 26, txt_sk_ffall
	SK 0, $FD, 23, txt_sk_free_act
	SK 0, $FD, 11, txt_sk_regen
	SK 0, $FD, 7, txt_sk_digest
	SK 0, $FD, SK_F2+5, txt_sk_esp
	SK 0, $FD, SK_F2+3, txt_sk_hold_life
	SK 0, $FD, SK_F2+10, txt_sk_light
	SK 0, RACE_DWARF, SK_F2+23, txt_sk_res_blind
	SK 0, $FA, SK_F2+6, txt_sk_im_fire
	SK p_resist_heat, $FD, SK_BOTH|19, txt_sk_fire2
	SK p_resist_heat, $FD, 19, txt_sk_res_fire
	SK 0, $FA, SK_F2+7, txt_sk_im_cold
	SK p_resist_cold, $FD, SK_BOTH|21, txt_sk_cold2
	SK p_resist_cold, $FD, 21, txt_sk_res_cold
	SK 0, $FA, SK_F2+8, txt_sk_im_acid
	SK p_resist_acid, $FD, SK_BOTH|20, txt_sk_acid2
	SK p_resist_acid, $FD, 20, txt_sk_res_acid
	SK 0, $FA, SK_F2+14, txt_sk_im_poison
	SK p_resist_poison, $FD, SK_BOTH|28, txt_sk_poison2
	SK p_resist_poison, $FD, 28, txt_sk_res_poison
	SK 0, $FA, SK_F2+9, txt_sk_im_lightning
	SK p_resist_light, $FD, SK_BOTH|25, txt_sk_lightning2
	SK p_resist_light, $FD, 25, txt_sk_res_lightning
	SK 0, 2, SK_F2+17, txt_sk_res_light		; (elves)
	SK 0, 6, SK_F2+18, txt_sk_res_dark		; (half-orcs)
	SK 0, $FD, SK_F2+15, txt_sk_res_conf
	SK 0, $FD, SK_F2+16, txt_sk_res_sound
	SK 0, $FD, SK_F2+20, txt_sk_res_disen
	SK 0, $FD, SK_F2+19, txt_sk_res_chaos
	SK 0, $FD, SK_F2+21, txt_sk_res_shards
	SK 0, $FD, SK_F2+22, txt_sk_res_nexus
	SK 0, $FD, SK_F2+24, txt_sk_res_nether
	SK 0, $FD, 0, txt_sk_str
	SK 0, $FD, 1, txt_sk_int
	SK 0, $FD, 2, txt_sk_wis
	SK 0, $FD, 3, txt_sk_dex
	SK 0, $FD, 4, txt_sk_con
	SK 0, $FD, 5, txt_sk_chr
	SK 0, $FD, SK_SUST+A_STR, txt_sk_sus_str
	SK 0, $FD, SK_SUST+A_INT, txt_sk_sus_int
	SK 0, $FD, SK_SUST+A_WIS, txt_sk_sus_wis
	SK 0, $FD, SK_SUST+A_CON, txt_sk_sus_con
	SK 0, $FD, SK_SUST+A_DEX, txt_sk_sus_dex
	SK 0, $FD, SK_SUST+A_CHR, txt_sk_sus_chr
	SK 0, $FB, SK_NONE, txt_sk_accursed
	SK 0, $FC, SK_NONE|4, txt_sk_orcs
	SK 0, $FC, SK_NONE|5, txt_sk_trolls
	SK 0, $FC, SK_NONE|6, txt_sk_giants
	SK 0, $FC, SK_NONE|11, txt_sk_animals
	SK 0, $FC, SK_NONE|1, txt_sk_bane
	SK 0, $FC, SK_NONE|2, txt_sk_dragons
	SK 0, $FC, SK_NONE|7, txt_sk_demons
	SK 0, $FC, SK_NONE|3, txt_sk_undead
	SK 0, $FC, SK_NONE|10, txt_sk_evil
	SK 0, $FC, SK_NONE|8, txt_sk_frigid
	SK 0, $FC, SK_NONE|9, txt_sk_flaming
	SK 0, $FC, SK_NONE|0, txt_sk_electric
	db 0,0,$FF

txt_attributes:		db "Your Attributes:",0
txt_press_key:		db "[Press any key to continue]",0
txt_sk_blind:		db "You cannot see.",0
txt_sk_confused:	db "You are confused.",0
txt_sk_afraid:		db "You are scared.",0
txt_sk_cut:			db "You are bleeding.",0
txt_sk_stun:		db "You are reeling.",0
txt_sk_poisoned:	db "You are poisoned.",0
txt_sk_blessed:		db "You feel rightous.",0
txt_sk_hero:		db "You feel heroic.",0
txt_sk_shero:		db "You are in a battle rage.",0
txt_sk_protevil:	db "You are protected from evil.",0
txt_sk_recall:		db "You will soon be recalled.",0
txt_sk_glowing:		db "Your hands are glowing dull red.",0
txt_sk_infra:		db "Your eyes are sensitive to infrared.",0
txt_sk_see_inv:		db "You can see invisible creatures.",0
txt_sk_ffall:		db "You land gently.",0
txt_sk_free_act:	db "You have free action.",0
txt_sk_res_blind:	db "Your eyes are resistant to blindness.",0
txt_sk_res_fire:	db "You are resistant to fire.",0
txt_sk_res_cold:	db "You are resistant to cold.",0
txt_sk_res_light:	db "You are resistant to bright light.",0
txt_sk_res_dark:	db "You are resistant to darkness.",0
txt_sk_sus_str:		db "You will not become weaker.",0
txt_sk_sus_con:		db "You will not become out of shape.",0
txt_sk_sus_dex:		db "You will not become clumsy.",0
txt_sk_sus_int:		db "You will not become dumber.",0
txt_sk_sus_wis:		db "You will not become less wise.",0
txt_sk_sus_chr:		db "You will not become less popular.",0
txt_sk_aggravate:	db "You aggravate monsters.",0
txt_sk_teleport:	db "Your position is very uncertain.",0
txt_sk_search:		db "You are perceptive.",0
txt_sk_digest:		db "Your appetite is small.",0
txt_sk_fire2:		db "You resist fire exceptionally well.",0
txt_sk_cold2:		db "You resist cold exceptionally well.",0
txt_sk_res_acid:	db "You are resistant to acid.",0
txt_sk_res_poison:	db "You are resistant to poison.",0
txt_sk_str:			db "You have magical strength.",0
txt_sk_int:			db "You have magically enhanced intelligence.",0
txt_sk_wis:			db "You are magically wise.",0
txt_sk_dex:			db "You are magically agile.",0
txt_sk_con:			db "You are magically tough.",0
txt_sk_chr:			db "You are magically popular.",0
txt_sk_stealth:		db "You are hard to find.",0
txt_sk_regen:		db "You regenerate quickly.",0
txt_sk_esp:			db "You have ESP.",0
txt_sk_hold_life:	db "You have a firm hold on your life force.",0
txt_sk_light:		db "You are carrying a permanent light.",0
txt_sk_res_lightning: db "You are resistant to lightning.",0

sk_row:			db 0
txt_sk_foul:		db "Your weapon is truly foul.",0
txt_sk_accursed:	db "Your weapon is accursed.",0
txt_sk_orcs:		db "Your weapon is especially deadly against orcs.",0
txt_sk_trolls:		db "Your weapon is especially deadly against trolls.",0
txt_sk_giants:		db "Your weapon is especially deadly against giants.",0
txt_sk_animals:		db "Your weapon is especially deadly against Nature's creatures.",0
txt_sk_bane:		db "Your weapon is a great bane of dragons.",0
txt_sk_dragons:		db "Your weapon is especially deadly against dragons.",0
txt_sk_demons:		db "Your weapon strikes at demons with holy wrath.",0
txt_sk_undead:		db "Your weapon strikes at undead with holy wrath.",0
txt_sk_evil:		db "Your weapon fights against evil with holy fury.",0
txt_sk_frigid:		db "Your frigid weapon freezes your foes.",0
txt_sk_flaming:		db "Your flaming weapon burns your foes.",0
txt_sk_electric:	db "Your weapon electrocutes your foes.",0
txt_sk_calris:		db "Your bastard sword is wickedly accursed.",0
txt_sk_mormegil:	db "Your two-handed sword radiates an aura of unspeakable evil.",0
txt_sk_im_fire:		db "You are completely immune to fire.",0
txt_sk_im_cold:		db "You are completely immune to cold.",0
txt_sk_im_acid:		db "You are completely immune to acid.",0
txt_sk_im_poison:	db "You are completely immune to poison.",0
txt_sk_im_lightning: db "You are completely immune to lightning.",0
txt_sk_res_conf:	db "You are resistant to confusion.",0
txt_sk_res_sound:	db "You are resistant to sonic attacks.",0
txt_sk_res_disen:	db "You are resistant to disenchantment.",0
txt_sk_res_chaos:	db "You are resistant to blasts of chaos.",0
txt_sk_res_shards:	db "You are resistant to blasts of shards.",0
txt_sk_res_nexus:	db "You are resistant to nexus attacks.",0
txt_sk_res_nether:	db "You are resistant to nether forces.",0
txt_sk_shield:		db "You are protected by a mystic shield.",0
txt_sk_invuln:		db "You are temporarily invulnerable.",0
txt_sk_acid2:		db "You resist acid exceptionally well.",0
txt_sk_poison2:		db "You resist poison exceptionally well.",0
txt_sk_lightning2:	db "You resist lightning exceptionally well.",0
