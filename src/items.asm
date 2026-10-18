/* items.asm - item kinds, the floor item list, hunger  [resident]
	Kinds and treasures come from TREASURE.C via tools/convert.py
	(data/kinds.asm in KIND_PAGE, data/tables.asm here). Names use the C's
	conventions: '~' marks where a plural 's' goes.
	Potions show their flavour's colour (TC_COLOR's tccolors).
 */

/* kind_addr - HL = kind -> IY = kind record, paged into DATA_WINDOW
	(128 kinds per page). Preserves HL. Clobbers A, DE */
kind_addr:
	ld a,l								; page = KIND_PAGE + kind / 128
	rla
	ld a,h
	rla
	add a,KIND_PAGE
	nextreg NR_MMU1,a
	ld a,l
	and $7F
	ld e,a
	ld d,KIND_SIZE
	mul d,e
	ld iy,DATA_WINDOW
	add iy,de
	ret

/* item_kind_addr - IX = item -> HL = its kind, IY = the kind's record.
	Clobbers A, DE */
item_kind_addr:
	ld l,(ix+I_KIND)
	ld h,(ix+I_KIND_HI)
	jr kind_addr

/* ego_addr - A = ego (SN_) -> IY = its record, EGO_PAGE paged into the
	data window. Clobbers DE */
ego_addr:
	nextreg NR_MMU1,EGO_PAGE
	ld e,a
	ld d,EGO_SIZE
	mul d,e
	ld iy,DATA_WINDOW
	add iy,de
	ret

/* item_flags - IX = item -> it_flags: the C's flags then flags2, the
	kind's with its ego's added. Leaves IY on the kind. Clobbers A, BC, DE,
	HL */
item_flags:
	call item_kind_addr
	push iy
	pop hl
	ld de,K_FLAGS
	add hl,de
	ld de,it_flags
	ld bc,4
	ldir
	ld c,K_FLAGS2-K_FLAGS-4
	add hl,bc
	ld c,4
	ldir
	ld a,(ix+I_NAME2)
	or a
	ret z
	call ego_addr						; (E_FLAGS, E_FLAGS2 come first)
	bit EO_OWN_FLAGS,(iy+E_OPTS)		; (an artifact may replace the kind's)
	jr z,.add
	ld hl,0
	ld (it_flags),hl
	ld (it_flags+2),hl
.add:
	push iy
	pop hl
	ld de,it_flags
	ld b,8
.or:
	ld a,(de)
	or (hl)
	ld (de),a
	inc hl
	inc de
	djnz .or
	jp item_kind_addr

/* item_dice - IX = item -> A = its number of damage dice, B = their sides:
	the kind's, or its ego's or artifact's (a whip of fire may have 2).
	Leaves IY on the kind. Clobbers C, DE, HL */
item_dice:
	ld bc,0
	ld a,(ix+I_NAME2)
	or a
	jr z,.kind
	call ego_addr
	ld b,(iy+E_DICE)
	ld c,(iy+E_SIDES)
.kind:
	call item_kind_addr
	ld a,c
	or a
	jr nz,$+5
	ld c,(iy+K_SIDES)
	ld a,b
	or a
	jr nz,$+5
	ld a,(iy+K_DICE)
	ld b,c
	ret

it_flags:		ds 8

/* kind_name - IY = kind record -> HL = its name. Clobbers DE */
kind_name:
	push iy
	pop hl
	ld de,K_NAME
	add hl,de
	ret

/* kind_charges - IY = kind -> A = charges for a new one: 1d(range) + base
	for wands and staffs (magic_treasure), the kind's number for rings and
	amulets (a stat to sustain, or -5), 0 for anything else.
	Clobbers DE, HL */
kind_charges:
	ld a,(iy+K_CLASS)
	cp IC_AMULET
	jr nc,.p1
	cp IC_WAND
	jr z,.charged
	cp IC_STAFF
	jr z,.charged
	xor a
	ret
.charged:
	ld a,(iy+K_P1)
	call randint
	add a,(iy+K_P1+1)
	ret
.p1:
	ld a,(iy+K_P1)
	ret

/* init_charges - IX = a new item, IY = its kind: its charges, or a rod
	that's ready. Clobbers A, DE, HL */
init_charges:
	call kind_charges
	ld (ix+I_PVAL),a
	ld (ix+I_PVAL+1),0
	ret

/* item_pval_known - IX = item, IY = its kind -> A = its charges if the
	player knows them (known2), else 0 */
item_pval_known:
	ld a,(iy+K_CLASS)
	cp IC_WAND
	jr z,.device
	cp IC_STAFF
	jr nz,.none
.device:
	bit ID_KNOWN2_BIT,(ix+I_IDENT)
	jr z,.none
	ld a,(ix+I_PVAL)
	ret
.none:
	xor a
	ret

/* gold_addr - A = gold type -> HL = gold_table entry. Clobbers DE */
gold_addr:
	ld e,a
	ld d,5
	mul d,e
	ld hl,gold_table
	add hl,de
	ret

/* items_clear - empty the floor list */
items_clear:
	ld hl,ITEM_LIST+I_KIND_HI
	ld de,ITEM_SIZE
	ld b,ITEM_MAX
.loop:
	ld (hl),ITEM_EMPTY
	add hl,de
	djnz .loop
	ret

/* item_at - D = y, E = x -> IX = floor item there, carry set if found.
	Preserves DE */
item_at:
	ld ix,ITEM_LIST
	ld b,ITEM_MAX
.loop:
	ld a,(ix+I_KIND_HI)
	cp ITEM_EMPTY
	jr z,.next
	ld a,(ix+I_Y)
	cp d
	jr nz,.next
	ld a,(ix+I_X)
	cp e
	jr nz,.next
	scf
	ret
.next:
	push de
	ld de,ITEM_SIZE
	add ix,de
	pop de
	djnz .loop
	or a
	ret

/* item_free_slot - IX = an empty floor slot, carry set if there is one */
item_free_slot:
	ld ix,ITEM_LIST
	ld b,ITEM_MAX
	ld de,ITEM_SIZE
.loop:
	ld a,(ix+I_KIND_HI)
	cp ITEM_EMPTY
	scf
	ret z
	add ix,de
	djnz .loop
	or a
	ret

/* draw_items - IX walks the floor list; items on lit or remembered
	squares are drawn and become remembered themselves (the C's fm flag) */
draw_items:
	ld ix,ITEM_LIST
	ld b,ITEM_MAX
.loop:
	push bc
	ld a,(ix+I_KIND_HI)
	cp ITEM_EMPTY
	jr z,.next
	ld a,(view_y)
	ld b,a
	ld a,(ix+I_Y)
	sub b
	cp VIEW_H
	jr nc,.next
	add a,VIEW_TOP
	ld d,a
	ld a,(view_x)
	ld b,a
	ld a,(ix+I_X)
	sub b
	cp VIEW_W
	jr nc,.next
	ld e,a
	push de
	ld d,(ix+I_Y)
	ld e,(ix+I_X)
	call map_addr
	pop de
	ld a,(hl)
	and F_SEEN
	jr z,.unseen
	ld (ix+I_MARKED),1
	jr .draw
.unseen:
	ld a,(ix+I_MARKED)
	or a
	jr z,.next
.draw:
	call screen_addr
	call item_glyph
	ld (hl),b
	inc hl
	ld (hl),c
.next:
	ld de,ITEM_SIZE
	add ix,de
	pop bc
	djnz .loop
	ret

/* item_glyph - IX = item -> B = character, C = attribute. Preserves HL */
item_glyph:
	push hl
	ld a,(ix+I_KIND_HI)
	cp KIND_GOLD
	jr z,.gold
	call item_kind_addr
	ld b,(iy+K_CHAR)
	ld c,(iy+K_ATTR)
	call flavour_class
	jr nc,.plain
	cp OFS_SCROLL						; (scrolls have no colours)
	jr z,.plain
	push bc
	call flavour_attr
	pop bc
	ld c,a
.plain:
	pop hl
	ret
.gold:
	ld a,(ix+I_SUB)
	call gold_addr
	inc hl
	inc hl
	ld b,(hl)
	inc hl
	ld c,(hl)
	pop hl
	ret

/* add_food - HL = nourishment (add_food in MISC1.C): overeating slows */
add_food:
	ex de,hl
	ld hl,(p_food)
	bit 7,h
	jr z,$+5
	ld hl,0
	add hl,de
	ld (p_food),hl
	ld de,FOOD_MAX+1
	or a
	sbc hl,de
	jr c,.not_bloated
	ld hl,msg_bloated					; slow += (food - max) / 50,
	call msg_print						; food = max + slow
	ld hl,(p_food)
	ld de,FOOD_MAX
	or a
	sbc hl,de
	ld c,50
	call div16_8
	ld de,(p_slow)
	add hl,de
	ld (p_slow),hl
	ld de,FOOD_MAX
	add hl,de
	ld (p_food),hl
	jr .hunger
.not_bloated:
	ld hl,(p_food)
	ld de,FOOD_FULL+1
	or a
	sbc hl,de
	jr c,.hunger
	ld hl,msg_full
	call msg_print
.hunger:
	ld hl,(p_food)						; hunger state from the new total
	ld a,HUNGER_FED
	ld de,FOOD_ALERT
	or a
	sbc hl,de
	jr nc,.set
	add hl,de
	ld a,HUNGER_HUNGRY
	ld de,FOOD_WEAK
	sbc hl,de
	jr nc,.set
	ld a,HUNGER_WEAK
.set:
	ld (p_hunger),a
	ret

/* hunger_tick - one turn of digestion (DUNGEON.C): fast characters burn
	speed^2 more. Returns A = regen amount for regenhp: less when weak or
	fainting, none when starving */
hunger_tick:
	ld a,(p_speed)
	bit 7,a
	jr z,.digest
	neg
	ld e,a
	ld d,a
	mul d,e
	ld hl,(p_food)
	or a
	sbc hl,de
	ld (p_food),hl
.digest:
	ld hl,(p_food)
	ld de,-FOOD_DIGESTED
	ld a,(p_eflags)						; slow digestion: one less
	bit EF0_SLOW_DIGEST,a
	jr z,$+3
	inc de
	ld a,(p_eflags+1)					; regeneration: three more
	bit EF1_REGEN,a
	jr z,.digested
	dec de
	dec de
	dec de
.digested:
	add hl,de
	ld (p_food),hl
	bit 7,h
	jr z,.fed
	ld a,h								; starving: lose -food/16 hp
	cpl
	ld h,a
	ld a,l
	cpl
	ld l,a
	inc hl
	srl h
	rr l
	srl h
	rr l
	srl h
	rr l
	srl h
	rr l
	ld de,KILLER_STARVATION
	ld (killer_race),de
	call take_hit
	xor a
	ret
.fed:
	ld de,FOOD_ALERT
	or a
	sbc hl,de
	ld a,REGEN_NORMAL
	ret nc								; not hungry
	add hl,de
	ld de,FOOD_WEAK
	or a
	sbc hl,de
	jr c,.weak
	ld a,(p_hunger)
	or a
	ld a,REGEN_NORMAL
	ret nz
	ld a,HUNGER_HUNGRY
	ld (p_hunger),a
	ld hl,msg_hungry
	call msg_print
	ld a,REGEN_NORMAL
	ret
.weak:
	add hl,de
	ld a,(p_hunger)
	cp HUNGER_WEAK
	jr z,.faint_check
	ld a,HUNGER_WEAK
	ld (p_hunger),a
	push hl
	ld hl,msg_weak
	call msg_print
	pop hl
.faint_check:
	ld de,FOOD_FAINT
	or a
	sbc hl,de
	ld a,REGEN_WEAK
	ret nc
	ld a,8								; 1 in 8: faint for 1d5 turns
	call randint
	dec a
	jr nz,.no_faint
	ld a,5
	call randint
	ld hl,p_paralysed
	add a,(hl)
	ld (hl),a
	ld hl,msg_faint
	call msg_print
.no_faint:
	ld a,REGEN_FAINT
	ret

msg_full:		db "You are full.",0
msg_bloated:	db "You are bloated from overeating.",0
