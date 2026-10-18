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
	call new_plain
	ld a,(mt_level)
	jr magic_treasure

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
	or curses (magic_treasure in MISC1.C, without the egos and artifacts) */
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
	cp MC_RING
	jp z,.ring
	cp MC_AMULET
	jp z,.amulet
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
