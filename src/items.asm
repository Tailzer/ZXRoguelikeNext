/* items.asm - item kinds, the floor item list, hunger  [resident]
	Kinds and treasures come from TREASURE.C via tools/convert.py
	(data/kinds.asm in KIND_PAGE, data/tables.asm here). Names use the C's
	conventions: '~' marks where a plural 's' goes.
	Not yet: magical pluses (magic_treasure), unknown potion flavours.
 */

P_STR				equ 17				; fixed stats until character creation

/* kind_addr - A = kind -> IY = kind record, paged into DATA_WINDOW.
	Clobbers DE */
kind_addr:
	nextreg NR_MMU1,KIND_PAGE
	ld e,a
	ld d,KIND_SIZE
	mul d,e
	ld iy,DATA_WINDOW
	add iy,de
	ret

/* kind_name - IY = kind record -> HL = its name. Clobbers DE */
kind_name:
	push iy
	pop hl
	ld de,K_NAME
	add hl,de
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
	ld hl,ITEM_LIST
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
	ld a,(ix+I_KIND)
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
	ld a,(ix+I_KIND)
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
	ld a,(ix+I_KIND)
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
	ld a,(ix+I_KIND)
	cp KIND_GOLD
	jr z,.gold
	call kind_addr
	ld b,(iy+K_CHAR)
	ld c,(iy+K_ATTR)
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

/* hunger_tick - one turn of digestion (DUNGEON.C). Returns A = regen
	amount for regenhp: less when weak or fainting, none when starving */
hunger_tick:
	ld hl,(p_food)
	ld de,-FOOD_DIGESTED
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
