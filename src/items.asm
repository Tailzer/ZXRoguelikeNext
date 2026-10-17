/* items.asm - item kinds, the floor item list, hunger  [resident]
	Kinds are hand-copied from TREASURE.C object_list[] (Angband PC 1.2):
	name, symbol, level, weight, damage dice, AC and to-hit. alloc is how
	many copies of the kind the C table has, which sets how common it is.
	Names use the C's conventions: '~' marks where a plural 's' goes.
	Not yet: magical pluses (magic_treasure), unknown potion flavours.
 */

NUM_KINDS			equ 13
KIND_RATION			equ 0
KIND_CLW			equ 1
KIND_BROADSWORD		equ 6
KIND_CHAIN_MAIL		equ 10
P_STR				equ 17				; fixed stats until character creation

	MACRO KIND p_nm, p_ch, p_at, p_cl, p_ef, p_lv, p_wt, p_dd, p_ds, p_ac, p_th, p_td, p_p1, p_al
		dw p_nm
		db p_ch, p_at, p_cl, p_ef, p_lv, p_wt, p_dd, p_ds, p_ac, p_th, p_td
		dw p_p1
		db p_al
	ENDM

; name, char, colour, class, effect, level, weight, dice, ac, to-hit,
; to-dam, p1, alloc
kind_table:
	KIND kn_ration,   ',', ATTR_UMBER,  IC_FOOD,   0, 0,  10, 0,0,  0,  0, 0, 5000, 3
	KIND kn_clw,      '!', ATTR_BLUE,   IC_POTION, 2, 0,   4, 0,0,  0,  0, 0,    0, 3
	KIND kn_csw,      '!', ATTR_RED,    IC_POTION, 4, 3,   4, 0,0,  0,  0, 0,    0, 1
	KIND kn_dagger,   '|', ATTR_WHITE,  IC_WEAPON, 0, 0,  12, 1,4,  0,  0, 0,    0, 4
	KIND kn_gauche,   '|', ATTR_WHITE,  IC_WEAPON, 0, 2,  30, 1,5,  0,  0, 0,    0, 1
	KIND kn_shortsw,  '|', ATTR_WHITE,  IC_WEAPON, 0, 6,  80, 1,7,  0,  0, 0,    0, 1
	KIND kn_broadsw,  '|', ATTR_WHITE,  IC_WEAPON, 0, 9, 150, 2,5,  0,  0, 0,    0, 2
	KIND kn_mace,     $5C, ATTR_GREY,   IC_WEAPON, 0, 6, 120, 2,4,  0,  0, 0,    0, 1
	KIND kn_softarm,  '(', ATTR_UMBER,  IC_BODY,   0, 2,  80, 0,0,  4,  0, 0,    0, 1
	KIND kn_hardarm,  '(', ATTR_UMBER,  IC_BODY,   0, 5, 100, 1,1,  6, -1, 0,    0, 1
	KIND kn_chain,    '[', ATTR_GREY,   IC_BODY,   0,26, 220, 1,4, 14, -2, 0,    0, 1
	KIND kn_shield,   ')', ATTR_UMBER,  IC_SHIELD, 0, 3,  50, 1,1,  2,  0, 0,    0, 1
	KIND kn_cap,      ']', ATTR_UMBER,  IC_HELM,   0, 4,  15, 0,0,  2,  0, 0,    0, 1
kind_table_end:
	ASSERT kind_table_end - kind_table == NUM_KINDS * KIND_SIZE

kn_ration:		db "Ration~ of Food",0
kn_clw:			db "Potion~ of Cure Light Wounds",0
kn_csw:			db "Potion~ of Cure Serious Wounds",0
kn_dagger:		db "Dagger~",0
kn_gauche:		db "Main Gauche~",0
kn_shortsw:		db "Short Sword~",0
kn_broadsw:		db "Broadsword~",0
kn_mace:		db "Mace~",0
kn_softarm:		db "Soft Leather Armour",0
kn_hardarm:		db "Hard Leather Armour",0
kn_chain:		db "Chain Mail",0
kn_shield:		db "Small Leather Shield~",0
kn_cap:			db "Hard Leather Cap~",0

; the 18 kinds of treasure (TREASURE.C, after OBJ_GOLD_LIST): name, symbol,
; colour, base value
gold_table:
	dw gn_copper
	db '$', ATTR_UMBER, 3
	dw gn_copper
	db '$', ATTR_UMBER, 4
	dw gn_copper
	db '$', ATTR_UMBER, 5
	dw gn_silver
	db '$', ATTR_GREY, 6
	dw gn_silver
	db '$', ATTR_GREY, 7
	dw gn_silver
	db '$', ATTR_GREY, 8
	dw gn_garnets
	db '*', ATTR_RED, 9
	dw gn_garnets
	db '*', ATTR_RED, 10
	dw gn_gold
	db '$', ATTR_YELLOW, 12
	dw gn_gold
	db '$', ATTR_YELLOW, 14
	dw gn_gold
	db '$', ATTR_YELLOW, 16
	dw gn_opals
	db '*', ATTR_WHITE, 18
	dw gn_sapphires
	db '*', ATTR_BLUE, 20
	dw gn_gold
	db '$', ATTR_YELLOW, 24
	dw gn_rubies
	db '*', ATTR_RED, 28
	dw gn_diamonds
	db '*', ATTR_WHITE, 32
	dw gn_emeralds
	db '*', ATTR_GREEN, 40
	dw gn_mithril
	db '$', ATTR_WHITE, 80
gn_copper:		db "copper",0
gn_silver:		db "silver",0
gn_garnets:		db "garnets",0
gn_gold:		db "gold",0
gn_opals:		db "opals",0
gn_sapphires:	db "sapphires",0
gn_rubies:		db "rubies",0
gn_diamonds:	db "diamonds",0
gn_emeralds:	db "emeralds",0
gn_mithril:		db "mithril",0

/* kind_addr - A = kind -> IY = kind record. Clobbers DE */
kind_addr:
	ld e,a
	ld d,KIND_SIZE
	mul d,e
	ld iy,kind_table
	add iy,de
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
	ld a,KILLER_STARVATION
	ld (killer_race),a
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
