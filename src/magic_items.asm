/* magic_items.asm - new items and their magical pluses  [overlay: PAGE_MISC]
	References: MISC1.C magic_treasure/m_bonus/randnor/magik, MISC2.C
	place_object. Used by level generation, the stores, the starting kit
	and Create Food alike: other overlays reach it with OVCALL.
	Not yet: ego items and artifacts (the C's special cases are made plain
	pluses for now).
 */

OBJ_BASE_MAGIC		equ 15
OBJ_BASE_MAX		equ 70
OBJ_DIV_SPECIAL		equ 4
OBJ_DIV_CURSED		equ 13
OBJ_STD_ADJ			equ 125
OBJ_STD_MIN			equ 7

/* new_item - IX = record, HL = kind, A = level: one of it, with its base
	pluses, charges, and whatever magic_treasure gives at that level */
new_item:
	ld (mt_level),a
	xor a
	ld (mt_good),a
.unique:
	ld (mt_nounique),a
	call new_plain
	ld a,(mt_level)
	jr magic_treasure

/* new_good_item - as new_item, B = 1 good (always magic), 2 great (an ego
	too, as magic_treasure's good == 666): place_special */
new_good_item:
	ld (mt_level),a
	ld a,b
	ld (mt_good),a
	xor a
	jr new_item.unique

/* new_store_item - as new_item, but never an artifact (store_create's
	not_unique) */
new_store_item:
	ld (mt_level),a
	xor a
	ld (mt_good),a
	ld a,1
	jr new_item.unique

/* new_plain - IX = record, HL = kind: one of it, just as it comes (base
	pluses, charges or a ring's number, cursed if the kind always is, no
	magic). Leaves IY on the kind */
new_plain:
	ld (ix+I_KIND),l
	ld (ix+I_KIND_HI),h
	ld (ix+I_NUMBER),1
	xor a
	ld (ix+I_MARKED),a
	ld (ix+I_IDENT),a
	ld (ix+I_NAME2),a
	ld (ix+I_FEEL),a
	call kind_addr
	ld a,(iy+K_TOHIT)
	ld (ix+I_TOHIT),a
	ld a,(iy+K_TODAM)
	ld (ix+I_TODAM),a
	ld a,(iy+K_TOAC)
	ld (ix+I_TOAC),a
	call init_charges
	ld a,(iy+K_CLASS)					; Teleportation, Weakness, Woe, Doom...
	cp IC_AMULET
	ret c
	bit EF3_CURSED,(iy+K_FLAGS+3)
	ret z
	set ID_CURSED_BIT,(ix+I_IDENT)
	ret

/* magic_treasure - IX = item, IY = its kind, A = level: magical pluses,
	ego items, or curses (magic_treasure in MISC1.C; the artifacts it may
	make instead come in 9c-3b: their dice are rolled, but nothing made) */
magic_treasure:
	ld (mt_level),a
	add a,OBJ_BASE_MAGIC				; chance = 15 + level, at most 70
	jr c,.max
	cp OBJ_BASE_MAX+1
	jr c,.chance
.max:
	ld a,OBJ_BASE_MAX
.chance:
	ld (mt_chance),a
	srl a								; special = chance / 4
	srl a
	ld (mt_special),a
	ld a,(mt_chance)
	ld e,a								; cursed = 10 * chance / 13
	ld d,10
	mul d,e
	ex de,hl
	ld c,OBJ_DIV_CURSED
	call div16_8
	ld a,l
	ld (mt_cursed),a
	ld a,(mt_good)						; good: always magic (great: an ego
	or a								; too)
	jr z,.ordinary
	ld a,100
	ld (mt_chance),a
	ld a,(mt_good)
	cp 2
	jr nz,.ordinary
	ld a,100
	ld (mt_special),a
.ordinary:
	xor a
	ld (mt_crown),a
	ld a,(iy+K_EGO)						; (m_bonus pages the kinds out)
	ld (mt_kego),a
	ld a,(iy+K_CLASS)					; a torch or lantern found in the
	cp IC_LIGHT							; dungeon: 1d its fuel (the C's odd
	jr z,.fuel							; subvals)
	cp IC_LANTERN
	jr nz,.not_light
.fuel:
	ld a,(mt_nounique)					; (not the stores')
	or a
	ret nz
	ld l,(ix+I_PVAL)
	ld h,(ix+I_PVAL+1)
	ld a,h
	or l
	ret z								; (the Phial and its like)
	call randint16
	ld (ix+I_PVAL),l
	ld (ix+I_PVAL+1),h
	ret
.not_light:
	ld a,(iy+K_MAGIC)
	or a
	ret z
	cp MC_CROWN							; crowns: chance += cost / 100,
	jr nz,.class						; special doubled
	ld l,(iy+K_COST)
	ld h,(iy+K_COST+1)
	ld c,100
	call div16_8
	ld a,(mt_chance)
	add a,l
	jr nc,$+4
	ld a,255
	ld (mt_chance),a
	ld hl,mt_special
	sla (hl)
	ld a,1
	ld (mt_crown),a
	ld a,MC_HELM
.class:
	cp MC_RING
	jp z,.ring
	cp MC_AMULET
	jp z,.amulet
	cp MC_DRAGON
	jp z,.dragon
	cp MC_WEAPON
	jp z,.weapon
	cp MC_GLOVES
	jp z,.gloves
	cp MC_BOOTS
	jp z,.boots
	cp MC_HELM
	jp z,.helm
	cp MC_CLOAK
	jp z,.cloak
	cp MC_BOW
	jp z,.bow
	cp MC_AMMO
	jp z,.ammo
	cp MC_CHEST
	jp z,.chest
	; body armour and shields
	call .magical
	jp nc,.armour_cursed
	ld bc,1*256+30						; + m_bonus(1, 30)
	call .ac_plus
	ld a,(mt_kego)
	bit KE_ROBE,a				; a robe: 1 in 30 of the special
	jr z,.armour_ego					; ones are of the Magi
	call .special
	jr nc,.armour_ego
	ld a,30
	call randint
	dec a
	jr nz,.armour_ego
	ld a,SN_MAGI_ROBE
	call .ego
	ld a,5
	call randint
	add a,10
	call .add_ac
	ld a,10								; (sustains every stat)
	jp .set_p1
.armour_ego:
	call .special
	ret nc
	ld a,9
	call randint
	dec a
	jr z,.resistance
	dec a
	jr z,.resist_acid
	ld b,SN_RF
	cp 3
	jr c,.resist
	ld b,SN_RC
	cp 5
	jr c,.resist
	ld b,SN_RL
.resist:
	ld a,3
	call .art
	ret c
	ld a,b
	jp .ego
.resist_acid:							; (not mithril or adamantite)
	ld a,3
	call .art
	ret c
	ld a,(mt_kego)
	bit KE_NO_RA,a
	ret nz
	ld a,SN_RA
	jp .ego
.resistance:							; 1 in 3 of Elvenkind, with
	ld a,3								; 1d3 stealth
	call .art
	ret c
	ld a,3
	call randint
	dec a
	jr nz,.plain_resist
	ld a,SN_ELVENKIND
	call .ego
	ld a,15
	call .add_ac
	ld a,3
	call randint
	jp .set_p1
.plain_resist:
	ld a,SN_R
	call .ego
	ld a,8
	jp .add_ac
.armour_cursed:
	call .is_cursed
	ret nc
	ld bc,1*256+40
	jp .ac_minus
.dragon:								; always: + m_bonus(1, 30)
	ld bc,1*256+30
	jp .ac_plus

.weapon:
	set ID_SHOWHD_BIT,(ix+I_IDENT)		; (weapons always show both)
	call .magical
	jp nc,.weapon_cursed
	ld bc,0*256+40						; + m_bonus(0, 40) each
	call m_bonus
	call .add_hit
	ld bc,0*256+40
	call m_bonus
	call .add_dam
	ld a,(mt_special)					; an ego: magik(3 * special / 2)
	ld b,a
	srl a
	add a,b
	call magik
	ret nc
	ld a,(mt_kego)
	bit KE_WHIP,a
	jr z,.weapon_ego
	ld a,10								; a whip of fire, 1 in 10 with 2d3
	call randint
	dec a
	ld a,SN_FIRE
	jr nz,$+4
	ld a,SN_FIRE2
	call .ego
	ld bc,5*256+5
	jp .hit_dam
.weapon_ego:
	ld a,27
	call randint
	dec a
	ld e,a
	ld d,4
	mul d,e
	ld hl,weapon_egos
	add hl,de
	ld a,(hl)							; the ego
	ld (mt_ego),a
	inc hl
	ld b,(hl)							; to-hit and to-dam
	inc hl
	ld c,(hl)
	inc hl
	ld a,(hl)							; 1: it may be an artifact instead
	or a
	jr z,.weapon_named
	ld a,2
	call .art
	ret c
.weapon_named:
	ld a,(mt_ego)
	call .ego
	call .hit_dam
	ld a,(mt_ego)
	cp SN_WEST
	jr z,.westernesse
	cp SN_HA
	jr z,.holy_avenger
	cp SN_DF
	ret nz
	ld a,5								; Defender: AC + 5 + 1d5, 1d3 stealth
	call randint
	add a,5
	call .add_ac
	ld a,3
	call randint
	jp .set_p1
.holy_avenger:							; AC + 1d4, 1d4 strength
	ld a,4
	call randint
	call .add_ac
	ld a,4
	call randint
	jp .set_p1
.westernesse:							; + 1d5 more each, +1 STR DEX CON
	ld a,5
	call randint
	call .add_hit
	ld a,5
	call randint
	call .add_dam
	ld a,1
	jp .set_p1
.weapon_cursed:
	call .is_cursed
	ret nc
	ld bc,1*256+55						; - m_bonus(1, 55) each
	call m_bonus
	neg
	call .add_hit
	ld bc,1*256+55
	call m_bonus
	neg
	call .add_dam
	ld a,15								; deep down, 1 in 10 of Morgul
	call randint
	add a,20
	ld b,a
	ld a,(mt_level)
	cp b
	ret c
	ret z
	ld a,10
	call randint
	dec a
	ret nz
	ld a,SN_MORGUL
	call .ego
	ld bc,$F1F1							; (-15, -15)
	call .hit_dam
	ld (ix+I_TOAC),-10
	ret

.gloves:
	call .magical
	jp nc,.gloves_cursed
	ld bc,1*256+20
	call .ac_plus
	ld a,(mt_kego)						; gauntlets: 1 in 4 of the special
	bit KE_GAUNTLETS,a					; ones may be an artifact
	jr z,.gloves_ego
	ld a,4
	call randint
	cp 1
	jr nz,.gloves_ego
	call .special
	jr nc,.gloves_ego
	ld hl,art_table
	call .unique_art
	ret c
.gloves_ego:
	call .special
	ret nc
	ld a,10
	call randint
	cp 4
	ld b,SN_FREE_ACTION
	jr c,.ego_b							; 1-3 free action
	cp 7
	jr c,.slaying						; 4-6 slaying
	cp 10
	jr c,.agility						; 7-9 agility
	ld a,3								; 10 power
	call .art
	ret c
	ld a,SN_POWER
	call .ego
	set ID_SHOWHD_BIT,(ix+I_IDENT)
	ld a,4
	call randint
	inc a
	call .set_p1
	jr .hit_dam_1d4
.slaying:
	ld a,SN_SLAYING
	call .ego
	set ID_SHOWHD_BIT,(ix+I_IDENT)
.hit_dam_1d4:							; + 1 + 1d4 each
	ld a,4
	call randint
	inc a
	call .add_hit
	ld a,4
	call randint
	inc a
	jp .add_dam
.agility:
	ld a,SN_AGILITY
	call .ego
	ld a,2
	call randint
	add a,2
	jp .set_p1
.ego_b:
	ld a,b
	jp .ego
.gloves_cursed:
	call .is_cursed
	ret nc
	call .special
	jr nc,.gloves_minus
	ld a,2								; clumsiness or weakness:
	call randint						; -m_bonus(1,10) DEX or STR
	dec a
	ld a,SN_CLUMSINESS
	jr z,$+4
	ld a,SN_WEAKNESS
	call .ego
	ld bc,1*256+10
	call m_bonus
	neg
	call .set_p1
.gloves_minus:
	ld bc,1*256+40
	jp .ac_minus

.boots:
	call .magical
	jr nc,.boots_cursed
	ld bc,1*256+20
	call .ac_plus
	call .special
	ret nc
	ld a,12
	call randint
	cp 6
	ld b,SN_SLOW_DESCENT
	jr nc,.ego_b						; 6-12 slow descent
	dec a
	jr z,.speed_boots					; 1 speed
	ld a,(mt_kego)
	bit KE_SHOD,a				; 2-5 stealth, but not metal
	ret nz								; shod boots
	ld a,SN_STEALTH
	call .ego
	ld a,3
	call randint
	jp .set_p1
.speed_boots:
	ld a,2
	call .art
	ret c
	ld a,SN_SPEED
	call .ego
	ld a,1
	jp .set_p1
.boots_cursed:
	call .is_cursed
	ret nc
	ld a,3								; slowness, noise or great mass
	call randint
	dec a
	jr nz,.not_slow
	ld a,-1
	call .set_p1
	ld a,SN_SLOWNESS
	jr .boots_minus
.not_slow:
	dec a
	ld a,SN_NOISE
	jr z,.boots_minus
	ld a,SN_GREAT_MASS
.boots_minus:
	call .ego
	ld bc,2*256+45
	jp .ac_minus

.helm:
	call .magical
	jp nc,.helm_cursed
	ld bc,1*256+20
	call .ac_plus
	call .special
	ret nc
	ld a,(mt_crown)
	or a
	jr nz,.crown
	ld a,12
	call randint
	ld (mt_ego),a
	ld a,2
	call .art
	ret c
	ld a,(mt_ego)
	cp 3
	jr c,.intelligence					; 1-2
	cp 6
	jr c,.wisdom						; 3-5
	cp 10
	jr c,.infravision					; 6-9
	cp 12
	ld a,SN_LIGHT						; 10-11
	jp c,.ego
	ld a,SN_TELEPATHY					; 12
	jp .ego
.intelligence:
	ld a,SN_INTELLIGENCE
	jr .one_or_two
.wisdom:
	ld a,SN_WISDOM
.one_or_two:
	call .ego
	ld a,2
	call randint
	jp .set_p1
.infravision:
	ld a,SN_INFRAVISION
	call .ego
	ld a,4
	call randint
	inc a
	jp .set_p1
.crown:
	ld a,6
	call randint
	dec a
	jr nz,.not_might
	ld a,2
	call .art
	ret c
	ld a,SN_MIGHT
	jr .crown_1d3
.not_might:
	dec a
	ld b,SN_LORDLINESS
	jr z,.crown_b
	dec a
	ld b,SN_MAGI
	jr z,.crown_b
	dec a
	ld b,SN_BEAUTY
	jr z,.crown_b
	dec a
	ld a,SN_REGENERATION
	jp nz,.ego
	ld a,SN_SEEING						; seeing: 5 * (1 + 1d4) searching
	call .ego
	ld a,4
	call randint
	inc a
	ld e,a
	ld d,5
	mul d,e
	ld a,e
	jp .set_p1
.crown_b:
	ld a,b
.crown_1d3:
	call .ego
	ld a,3
	call randint
	jp .set_p1
.helm_cursed:
	call .is_cursed
	ret nc
	ld bc,1*256+45
	call .ac_minus
	call .special
	ret nc
	ld a,7
	call randint
	dec a
	ld b,SN_STUPIDITY
	jr z,.dull
	cp 3
	ld b,SN_DULLNESS
	jr c,.dull
	cp 5
	ld b,SN_WEAKNESS
	jr c,.dull
	cp 5
	ld a,SN_TELEPORTATION
	jp z,.ego
	ld b,SN_UGLINESS
.dull:									; -1d5 to the stat
	ld a,b
	call .ego
	ld a,5
	call randint
	neg
	jp .set_p1

.cloak:									; only special ones get pluses
	call .magical
	jp nc,.cursed_cloak
	call .special
	ret nc
	ld a,(mt_kego)						; 1 in 10 Cloaks, 1 in 20 Shadow
	ld b,10								; Cloaks may be an artifact
	bit KE_CLOAK,a
	jr nz,.art_cloak
	ld b,20
	bit KE_SHADOW,a
	jr z,.cloak_ego
.art_cloak:
	ld a,b
	call randint
	cp 1
	jr nz,.cloak_ego
	ld hl,art_cloak_table
	call .unique_art
	jr nc,.cloak_ego
	ld bc,1*256+20						; and + m_bonus(1, 20)
	jp .ac_plus
.cloak_ego:
	ld a,2
	call randint
	dec a
	jr nz,.not_protection
	ld a,SN_PROTECTION					; + m_bonus(2,40) + 5 + 1d3
	call .ego
	ld bc,2*256+40
	call .ac_plus
	ld a,3
	call randint
	add a,5
	jp .add_ac
.not_protection:
	ld a,10
	call randint
	cp 10
	jr z,.aman
	ld a,SN_STEALTH						; + m_bonus(1,20), 1d3 stealth
	call .ego
	ld bc,1*256+20
	call .ac_plus
	ld a,3
	call randint
	jp .set_p1
.aman:									; + 20, 1d3 stealth
	ld a,SN_AMAN
	call .ego
	ld a,20
	call .add_ac
	ld a,3
	call randint
	jp .set_p1
.cursed_cloak:							; always one of three egos
	call .is_cursed
	ret nc
	ld a,3
	call randint
	dec a
	jr z,.irritation
	dec a
	jr z,.vulnerability
	ld (ix+I_NAME2),SN_ENVELOPING		; -m_bonus(1,10) AC,
	set ID_SHOWHD_BIT,(ix+I_IDENT)
	ld bc,1*256+10						; -m_bonus(2,40,level+10) hit, dam
	call .ac_minus
	ld hl,mt_level
	ld a,(hl)
	add a,10
	jr nc,$+4
	ld a,255
	ld (hl),a
	ld bc,2*256+40
	jr .hit_dam_minus
.irritation:							; -m_bonus(1,10) AC, hit and dam
	ld (ix+I_NAME2),SN_IRRITATION
	set ID_SHOWHD_BIT,(ix+I_IDENT)
	ld bc,1*256+10
	call .ac_minus
	ld bc,1*256+10
.hit_dam_minus:
	push bc
	call m_bonus
	neg
	call .add_hit
	pop bc
	call m_bonus
	neg
	jp .add_dam
.vulnerability:							; -m_bonus(10,100,level+50) AC
	ld (ix+I_NAME2),SN_VULNERABILITY
	ld hl,mt_level
	ld a,(hl)
	add a,50
	jr nc,$+4
	ld a,255
	ld (hl),a
	ld bc,10*256+100
	jp .ac_minus

.bow:									; which bow it is, while the kind's
	ld b,0								; in: 1 a long bow, 2 a light crossbow
	ld a,(iy+K_P1+1)					; (by range: 30, or 25 for bolts)
	cp 30
	jr nz,$+4
	ld b,1
	cp 25
	jr nz,.which
	ld a,(iy+K_FLAVOUR)					; (the ammunition's tval)
	cp 11
	jr nz,.which
	ld b,2
.which:
	ld a,b
	ld (mt_bow),a
	set ID_SHOWHD_BIT,(ix+I_IDENT)		; (always shows both)
	call .magical
	jp nc,.bow_cursed
	ld bc,1*256+30						; + m_bonus(1, 30), m_bonus(1, 20)
	call m_bonus
	call .add_hit
	ld bc,1*256+20
	call m_bonus
	call .add_dam
	ld a,(mt_special)					; special: magik(3 * special / 2)
	ld b,a
	srl a
	add a,b
	call magik
	ret nc
	ld a,15
	call randint
	cp 9
	jr nc,.accuracy						; 9-15
	cp 1
	jr nz,.might						; 2-8
	ld a,(mt_nounique)					; 1: maybe an artifact
	or a
	jr nz,.might
	ld a,(mt_bow)
	cp 1
	jr nz,.crossbow
	ld a,3								; a long bow, 1 in 3: Beleg
	call randint						; Cuthalion or Bard (if made
	dec a								; already, nothing)
	jr nz,.might
	ld a,2
	call randint
	dec a
	ld a,SN_BELEG
	jr z,.bow_art
	ld a,SN_BARD
	jr .bow_art
.crossbow:								; a light crossbow, 1 in 5: Cubragol
	cp 2
	jr nz,.might
	ld a,5
	call randint
	dec a
	jr nz,.might
	ld a,SN_CUBRAGOL
.bow_art:								; A = which: made, with its number,
	ld b,a								; and its pluses added
	call art_bit
	and (hl)
	ret nz
	ld a,c
	or (hl)
	ld (hl),a
	ld (ix+I_NAME2),b
	ld a,b
	call ego_addr
	ld a,(iy+E_P1)
	ld (ix+I_PVAL),a
	ld hl,bow_arts
.find_bow:
	ld a,(hl)
	inc hl
	cp b
	jr z,.bow_pluses
	inc hl
	inc hl
	jr .find_bow
.bow_pluses:
	ld b,(hl)
	inc hl
	ld c,(hl)
	jp .hit_dam
.might:
	ld a,SN_MIGHT_BOW
	call .ego
	ld bc,7*256+13
	jp .hit_dam
.accuracy:
	ld a,SN_ACCURACY
	call .ego
	ld bc,15*256+5
	jp .hit_dam
.bow_cursed:							; - m_bonus(1, 50), m_bonus(1, 30)
	call .is_cursed
	ret nc
	ld bc,1*256+50
	call m_bonus
	neg
	call .add_hit
	ld bc,1*256+30
	call m_bonus
	neg
	jp .add_dam

.chest:									; 1d(level + 4): empty, locked, or
	ld a,(mt_level)						; locked with a trap, worse deeper
	add a,4
	jr nc,$+4
	ld a,255
	call randint
	ld hl,.chest_traps
.trap:
	cp (hl)
	jr c,.this
	jr z,.this
	inc hl
	inc hl
	inc hl
	jr .trap
.this:
	inc hl
	ld a,(hl)
	ld (ix+I_PVAL),a
	inc hl
	ld a,(hl)
	ld (ix+I_NAME2),a
	ret
.chest_traps:							; up to 1d.., CHF_ bits, what it is
	db 1, 0, SN_EMPTY					; (nothing in it, either)
	db 2, $81, SN_LOCKED
	db 4, $83, SN_POISON_NEEDLE			; (lose strength)
	db 6, $85, SN_POISON_NEEDLE
	db 9, $89, SN_GAS_TRAP
	db 11, $91, SN_EXPLOSION_DEVICE
	db 14, $A1, SN_SUMMONING_RUNES
	db 17, $8F, SN_MULTIPLE_TRAPS		; (paralysis, poison, strength)
	db 255, $B1, SN_MULTIPLE_TRAPS		; (summoning, explosion)

.ammo:									; shots, arrows and bolts: pluses,
	set ID_SHOWHD_BIT,(ix+I_IDENT)		; then 7d6 of them, a new pile
	call .ammo_magic
	ld b,7
	xor a
.seven:
	push af
	push bc
	ld a,6
	call randint
	pop bc
	pop de
	add a,d
	djnz .seven
	ld (ix+I_NUMBER),a
	ld hl,(MISSILE_CTR)
	inc hl
	ld (MISSILE_CTR),hl
	ld (ix+I_PVAL),l
	ld (ix+I_PVAL+1),h
	ret
.ammo_magic:
	ld a,(iy+K_TVAL)					; (spikes: never magic)
	cp 13
	ret z
	call .magical
	jr nc,.ammo_cursed
	ld bc,1*256+35						; + m_bonus(1, 35) each
	call m_bonus
	call .add_hit
	ld bc,1*256+35
	call m_bonus
	call .add_dam
	ld a,(mt_special)					; an ego: magik(5 * special / 2)
	ld b,a
	srl a
	add a,b
	add a,b
	call magik
	ret nc
	ld a,11
	call randint
	ld hl,ammo_egos
.ammo_ego:
	cp (hl)								; (1d11 against each limit)
	jr z,.this_ego
	jr c,.this_ego
	inc hl
	inc hl
	inc hl
	inc hl
	jr .ammo_ego
.this_ego:
	inc hl
	ld a,(hl)
	call .ego
	inc hl
	ld b,(hl)
	inc hl
	ld c,(hl)
	jp .hit_dam
.ammo_cursed:							; - m_bonus(5, 55) each, 1 in 5 of
	call .is_cursed						; Backbiting (-20 more)
	ret nc
	ld bc,5*256+55
	call m_bonus
	neg
	call .add_hit
	ld bc,5*256+55
	call m_bonus
	neg
	call .add_dam
	ld a,5
	call randint
	dec a
	ret nz
	ld a,SN_BACKBITING
	call .ego
	ld bc,$ECEC							; (-20, -20)
	jp .hit_dam

; small helpers (A = amount unless said)
.ac_plus:								; AC + m_bonus(B, C)
	call m_bonus
	jr .add_ac
.ac_minus:								; AC - m_bonus(B, C)
	call m_bonus
	neg
.add_ac:
	add a,(ix+I_TOAC)
	ld (ix+I_TOAC),a
	ret
.add_hit:
	add a,(ix+I_TOHIT)
	ld (ix+I_TOHIT),a
	ret
.add_dam:
	add a,(ix+I_TODAM)
	ld (ix+I_TODAM),a
	ret
.hit_dam:								; to-hit + B, to-dam + C
	ld a,b
	call .add_hit
	ld a,c
	jr .add_dam
.ego:									; its ego is A
	ld (ix+I_NAME2),a
	ret
.special:								; magik(special) -> carry
	ld a,(mt_special)
	jp magik
.art:									; 1 in A (unique_weapon, unique_armour)
	push bc								; it's an artifact instead: carry.
	call randint						; Keeps BC
	pop bc
	cp 1
	jr nz,.no_art
	push bc
	ld hl,art_table
	call .unique_art
	pop bc
	ret
.no_art:
	or a
	ret
.unique_art:							; HL = table: not in a shop
	ld a,(mt_nounique)
	or a
	jp z,make_artifact
	xor a
	ret
.ring:									; by subval (K_FLAVOUR)
	ld a,(iy+K_FLAVOUR)
	cp 4
	jr c,.stat							; strength, dexterity...
	jr z,.speed
	cp 5
	jp z,.searching
	ld e,I_TODAM
	cp 19
	jp z,.field							; damage
	ld e,I_TOHIT
	cp 20
	jp z,.field							; accuracy
	ld e,I_TOAC
	cp 21
	jp z,.field							; protection
	cp 30
	ret nz
	set ID_SHOWHD_BIT,(ix+I_IDENT)		; slaying: m_bonus(1,25)*2 + 1d3
	ld hl,I_TODAM						; each
	call .slay
	ld hl,I_TOHIT
	call .slay
	call .is_cursed
	ret nc
	ld a,(ix+I_TODAM)
	neg
	ld (ix+I_TODAM),a
	ld a,(ix+I_TOHIT)
	neg
	ld (ix+I_TOHIT),a
	ret
.slay:
	push ix
	pop de
	add hl,de
	push hl
	ld bc,1*256+25
	call m_bonus
	add a,a
	pop hl
	add a,(hl)
	ld (hl),a
	push hl
	ld a,3
	call randint
	pop hl
	add a,(hl)
	ld (hl),a
	ret
.stat:									; cursed: -m_bonus(1,20),
	call .is_cursed						; else m_bonus(1,10)
	ld bc,1*256+10
	jr nc,.plus_p1
	ld bc,1*256+20
	call m_bonus
	neg
	jr .set_p1
.plus_p1:
	call m_bonus
.set_p1:
	ld (ix+I_PVAL),a
	ret
.speed:									; cursed: -1d3, else +1 (+2 one
	call .is_cursed						; time in 888)
	jr nc,.fast
	ld a,3
	call randint
	neg
	jr .set_p1
.fast:
	ld hl,888
	call randint16
	dec hl
	ld a,h
	or l
	ld a,1
	jr nz,.set_p1
	inc a
	jr .set_p1
.searching:								; 5 * m_bonus(1,20), maybe cursed
	ld bc,1*256+20
.five_times:
	call m_bonus
	ld e,a
	ld d,5
	mul d,e
	ld (ix+I_PVAL),e
	call .is_cursed
	ret nc
	ld a,(ix+I_PVAL)
	neg
	jr .set_p1
.field:									; E = the plus: m_bonus(1,20) +
	push ix								; 3 + 1d10, all negated if cursed
	pop hl
	ld d,0
	add hl,de
	push hl
	ld bc,1*256+20
	call m_bonus
	pop hl
	add a,(hl)
	ld (hl),a
	push hl
	ld a,10
	call randint
	add a,3
	pop hl
	add a,(hl)
	ld (hl),a
	push hl
	call .is_cursed
	pop hl
	ret nc
	ld a,(hl)
	neg
	ld (hl),a
	ret
.amulet:
	ld a,(iy+K_FLAVOUR)
	cp 2
	jr c,.stat							; wisdom, charisma
	ld bc,1*256+25
	jr z,.five_times					; searching: 5 * m_bonus(1,25)
	cp 8
	ret nz
	call m_bonus						; the Magi: the same, never cursed
	ld e,a
	ld d,5
	mul d,e
	ld (ix+I_PVAL),e
	ret
.magical:								; magik(chance) -> carry
	ld a,(mt_chance)
	jp magik
.is_cursed:								; magik(cursed) -> carry, and it is
	ld a,(mt_cursed)
	call magik
	ret nc
	set ID_CURSED_BIT,(ix+I_IDENT)
	scf
	ret

; ammunition egos by 1d11: up to, ego, to-hit, to-dam
ammo_egos:
	db 3,SN_SLAYING,5,5, 5,SN_FIRE,2,4, 7,SN_SLAY_EVIL,3,3
	db 9,SN_SLAY_ANIMAL,2,2, 10,SN_DRAGON_SLAYING,3,3, 11,SN_WOUNDING,15,15

; weapon egos by 1d27: ego, to-hit, to-dam, 1 if it may be an artifact
weapon_egos:
	db SN_HA,5,5,1, SN_DF,3,3,1, SN_FT,2,3,1, SN_FT,2,3,1	; 1-4
	db SN_FB,2,2,1, SN_FB,2,2,1, SN_SA,3,3,0, SN_SA,3,3,0	; 5-8
	db SN_SD,3,3,0, SN_SD,3,3,0, SN_SE,3,3,0, SN_SE,3,3,0	; 9-12
	db SN_SU,2,2,0, SN_SU,2,2,0, SN_SO,2,2,0, SN_SO,2,2,0	; 13-16
	db SN_SO,2,2,0, SN_ST,2,2,0, SN_ST,2,2,0, SN_ST,2,2,0	; 17-20
	db SN_SG,2,2,0, SN_SG,2,2,0, SN_SG,2,2,0, SN_SDEM,2,2,0	; 21-24
	db SN_SDEM,2,2,0, SN_SDEM,2,2,0, SN_WEST,3,3,1			; 25-27

/* make_artifact - IX = item, HL = art_table or art_cloak_table: if its
	kind may be an artifact, 1d(total) picks which by weight, it must then
	pass its 1 in keep, and not have been made already this game; then it
	is that artifact: carry (unique_weapon/unique_armour in MISC1.C) */
make_artifact:
	ld e,(ix+I_KIND)
	ld d,(ix+I_KIND_HI)
.find:
	ld c,(hl)
	inc hl
	ld b,(hl)
	inc hl
	ld a,b
	and c
	inc a
	jp z,.none							; ($FFFF: the end)
	ld a,c
	cp e
	jr nz,.next
	ld a,b
	cp d
	jr z,.found
.next:
	inc hl								; (the total)
	ld a,(hl)							; 3 bytes each
	inc hl
	ld c,a
	add a,a
	add a,c
	add hl,a
	jr .find
.found:
	ld a,(hl)							; 1d(total)
	inc hl
	inc hl
	push hl
	call randint
	pop hl
.pick:
	sub (hl)
	jr c,.got
	jr z,.got
	inc hl
	inc hl
	inc hl
	jr .pick
.got:
	inc hl
	ld a,(hl)							; 1 in keep
	inc hl
	ld b,(hl)							; B = the artifact
	cp 2
	jr c,.kept
	push bc
	call randint
	pop bc
	cp 1
	jr nz,.none
.kept:
	ld a,b
	call art_bit
	and (hl)
	jr nz,.none							; made already
	ld a,c
	or (hl)
	ld (hl),a
	ld (ix+I_NAME2),b					; it's this one: its numbers
	ld a,b
	call ego_addr
	ld a,(iy+E_HIT)
	bit EA_HIT,(iy+E_ART)
	jr z,$+5
	ld (ix+I_TOHIT),a
	ld a,(iy+E_DAM)
	bit EA_DAM,(iy+E_ART)
	jr z,$+5
	ld (ix+I_TODAM),a
	ld a,(iy+E_P1)
	bit EA_P1,(iy+E_ART)
	jr z,$+5
	ld (ix+I_PVAL),a
	bit EA_AC,(iy+E_ART)
	jr z,.curse
	ld a,(iy+E_AC)
	bit EA_AC_SET,(iy+E_ART)
	jr nz,$+5
	add a,(ix+I_TOAC)
	ld (ix+I_TOAC),a
.curse:
	bit EO_SHOW_HD,(iy+E_OPTS)
	jr z,$+6
	set ID_SHOWHD_BIT,(ix+I_IDENT)
	bit EF3_CURSED,(iy+E_FLAGS+3)
	jr z,$+6
	set ID_CURSED_BIT,(ix+I_IDENT)
	scf
	ret
.none:
	or a
	ret

/* win_item - IX = a floor record (y, x set), HL = kind, A = artifact:
	one of it, made that artifact (what Morgoth leaves, monster_death) */
win_item:
	push af
	call new_plain
	pop bc
	jp make_artifact.kept

/* art_bit - A = artifact (or special object) -> HL = its art_made byte,
	A = its bit there, C = the same. Clobbers DE */
art_bit:
	ld e,a
	srl a
	srl a
	srl a
	ld hl,art_made
	add hl,a
	ld a,e
	and 7
	ld de,bit_masks
	add de,a
	ld a,(de)
	ld c,a
	ret

/* try_special - IX = a floor record (y, x set): 1 time in 10 of those
	where 1d513 > 502, special_place_object (MISC2.C): up to 20 tries at
	one of its 12 cases, each 1 in r, not made already, not 40 levels
	too deep, and 1 in m if at all deeper; then it's here: carry */
try_special:
	ld hl,MAX_OBJECTS
	call randint16
	ld de,SPECIAL_OBJ+1
	or a
	sbc hl,de
	jr c,.none
	ld a,10
	call randint
	cp 1
	jr nz,.none
	xor a
	ld (sp_done),a
.again:
	ld a,(sp_done)
	cp 21
	jr nc,.none
	inc a
	ld (sp_done),a
	ld a,12
	call randint
	dec a
	ld e,a
	ld d,5
	mul d,e
	ld hl,special_cases
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld a,d
	and e
	inc a
	jr z,.again							; (a light: not yet)
	ld (sp_kind),de
	ld a,(hl)							; 1 in r
	inc hl
	ld b,(hl)							; (1 in m if it's deeper)
	inc hl
	ld c,(hl)							; its bit
	push bc
	call randint
	pop bc
	cp 1
	jr nz,.again
	ld a,c
	push bc
	call art_bit
	pop bc
	and (hl)
	jr nz,.again
	push bc
	ld hl,(sp_kind)
	call kind_addr
	pop bc
	ld a,(dun_level)					; level - 40 > dun_level: no
	add a,40
	jr c,.near
	cp (iy+K_LEVEL)
	jr c,.again
.near:
	ld a,(dun_level)					; deeper: 1 in m
	cp (iy+K_LEVEL)
	jr nc,.place
	ld a,b
	push bc
	call randint
	pop bc
	cp 1
	jr nz,.again
.place:
	ld a,c
	call art_bit
	or (hl)
	ld (hl),a
	ld hl,(sp_kind)
	call new_plain
	scf
	ret
.none:
	or a
	ret

bit_masks:		db 1,2,4,8,16,32,64,128
art_made:		ds (NUM_ART_BITS+7)/8	; artifacts made this game
sp_done:		db 0
sp_kind:		dw 0

	include "data/artifacts.asm"		; generated: which kinds are which

/* magik - A = chance in 100 -> carry if 1d100 <= it */
magik:
	ld b,a
	ld a,100
	call randint
	dec a
	cp b
	ret

/* m_bonus - B = base, C = max_std (mt_level = level) -> A = base +
	|randnor(0, std)| / 10, std = level * 1.25 + 7 at most max_std */
m_bonus:
	push bc
	ld a,(mt_level)						; std = 125 * level / 100 + 7
	ld e,a
	ld d,125
	mul d,e
	ex de,hl
	ld c,100
	call div16_8
	ld a,l
	add a,OBJ_STD_MIN
	pop bc
	push bc
	cp c
	jr c,$+3
	ld a,c
	call randnor_abs
	ld c,10
	call div16_8
	pop bc
	ld a,l
	add a,b
	ret

/* randnor_abs - A = standard deviation -> HL = |randnor(0, it)|, from the
	C's normal_table (on FLAVOUR_PAGE) */
randnor_abs:
	ld (mt_std),a
	ld hl,32767
	call randint16
	ld de,32767
	or a
	sbc hl,de
	jr nz,.table
	ld a,(mt_std)						; off the scale: 4 to 5 deviations
	ld e,a
	ld d,4
	mul d,e
	push de
	ld a,(mt_std)
	call randint
	pop hl
	add hl,a
	ret
.table:
	add hl,de							; the first entry at or above it
	ex de,hl
	nextreg NR_MMU1,FLAVOUR_PAGE
	ld hl,normal_table
	ld b,0
.find:
	ld a,(hl)
	inc hl
	push hl
	ld h,(hl)
	ld l,a
	or a
	sbc hl,de
	pop hl
	jr nc,.found
	inc hl
	inc b
	jr nz,.find
	dec b
.found:									; (std * index + 32) / 64
	ld a,(mt_std)
	ld e,a
	ld d,b
	mul d,e
	ex de,hl
	ld de,32
	add hl,de
	ld b,6
.shift:
	srl h
	rr l
	djnz .shift
	ret

mt_level:		db 0
mt_chance:		db 0
mt_cursed:		db 0
mt_std:			db 0
mt_special:		db 0
mt_crown:		db 0
mt_ego:			db 0
mt_kego:		db 0
mt_bow:			db 0				; 1 a long bow, 2 a light crossbow
mt_good:		db 0				; 1 good, 2 great (place_special)
mt_nounique:	db 0				; 1: in a shop (no artifacts)
