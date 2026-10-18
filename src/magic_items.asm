/* magic_items.asm - new items and their magical pluses  [resident]
	References: MISC1.C magic_treasure/m_bonus/randnor/magik, MISC2.C
	place_object. Used by level generation and the stores alike.
	Not yet: ego items and artifacts (the C's special cases are made plain
	pluses for now), rings and amulets.
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
	call new_plain
	ld a,(mt_level)
	jr magic_treasure

/* new_plain - IX = record, HL = kind: one of it, just as it comes (base
	pluses and charges, no magic). Leaves IY on the kind */
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
	jp init_charges

/* magic_treasure - IX = item, IY = its kind, A = level: magical pluses,
	or curses (magic_treasure in MISC1.C, without the egos) */
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
	ld e,a								; cursed = 10 * chance / 13
	ld d,10
	mul d,e
	ex de,hl
	ld c,OBJ_DIV_CURSED
	call div16_8
	ld a,l
	ld (mt_cursed),a
	ld a,(iy+K_MAGIC)
	or a
	ret z
	cp MC_CROWN							; crowns: chance += cost / 100
	jr nz,.class
	ld l,(iy+K_COST)
	ld h,(iy+K_COST+1)
	ld c,100
	call div16_8
	ld a,(mt_chance)
	add a,l
	jr nc,$+4
	ld a,255
	ld (mt_chance),a
	ld a,MC_HELM
.class:
	cp MC_DRAGON
	jr z,.dragon
	cp MC_WEAPON
	jr z,.weapon
	ld hl,armour_magic-4				; (bonus base, sd, curse base, sd)
	add a,a
	add a,a
	add hl,a
	ld (mt_table),hl
	cp MC_CLOAK*4
	jr z,.cloak
	call .magical
	jr nc,.cursed_armour
	ld hl,(mt_table)
	call .ac_bonus
	jr .add_ac
.cursed_armour:
	call .is_cursed
	ret nc
	ld hl,(mt_table)
	inc hl
	inc hl
	call .ac_bonus
	neg
.add_ac:
	add a,(ix+I_TOAC)
	ld (ix+I_TOAC),a
	ret
.dragon:								; always: + m_bonus(1, 30)
	ld bc,1*256+30
	call m_bonus
	jr .add_ac
.weapon:
	set ID_SHOWHD_BIT,(ix+I_IDENT)		; (weapons always show both)
	call .magical
	jr nc,.cursed_weapon
	ld bc,0*256+40						; + m_bonus(0, 40) each
	call m_bonus
	add a,(ix+I_TOHIT)
	ld (ix+I_TOHIT),a
	ld bc,0*256+40
	call m_bonus
	add a,(ix+I_TODAM)
	ld (ix+I_TODAM),a
	ret
.cursed_weapon:
	call .is_cursed
	ret nc
	ld bc,1*256+55						; - m_bonus(1, 55) each
	call m_bonus
	neg
	add a,(ix+I_TOHIT)
	ld (ix+I_TOHIT),a
	ld bc,1*256+55
	call m_bonus
	neg
	add a,(ix+I_TODAM)
	ld (ix+I_TODAM),a
	ret
.cloak:
	call .magical
	jr nc,.cursed_cloak
	ld bc,1*256+20
	call m_bonus
	jr .add_ac
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
	call m_bonus
	neg
	add a,(ix+I_TOAC)
	ld (ix+I_TOAC),a
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
	call m_bonus
	neg
	add a,(ix+I_TOAC)
	ld (ix+I_TOAC),a
	ld bc,1*256+10
.hit_dam_minus:
	push bc
	call m_bonus
	neg
	add a,(ix+I_TOHIT)
	ld (ix+I_TOHIT),a
	pop bc
	call m_bonus
	neg
	add a,(ix+I_TODAM)
	ld (ix+I_TODAM),a
	ret
.vulnerability:							; -m_bonus(10,100,level+50) AC
	ld (ix+I_NAME2),SN_VULNERABILITY
	ld hl,mt_level
	ld a,(hl)
	add a,50
	jr nc,$+4
	ld a,255
	ld (hl),a
	ld bc,10*256+100
	call m_bonus
	neg
	add a,(ix+I_TOAC)
	ld (ix+I_TOAC),a
	ret
.magical:								; magik(chance) -> carry
	ld a,(mt_chance)
	jr magik
.is_cursed:								; magik(cursed) -> carry, and it is
	ld a,(mt_cursed)
	call magik
	ret nc
	set ID_CURSED_BIT,(ix+I_IDENT)
	scf
	ret
.ac_bonus:								; HL -> (base, sd): A = m_bonus
	ld b,(hl)
	inc hl
	ld c,(hl)
	jp m_bonus

; (bonus base, sd, curse base, sd) for armour, -, gloves, boots, helm, cloak
armour_magic:	db 1,30, 1,40,  0,0,0,0,  0,0,0,0
				db 1,20, 1,40,  1,20, 2,45,  1,20, 1,45,  1,20, 0,0

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
mt_table:		dw 0
