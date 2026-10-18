/* store.asm - the town's stores  [overlay: PAGE_STORE]
	References: STORE1.C (store_init, store_maint, store_create,
	store_destroy, store_carry, special_offer, sell_price, item_value),
	STORE2.C (purchase/sell with the MSDOS no_haggle option: you pay the
	owner's final asking price and get their final offer), SETS.C (what
	each store buys), MISC2.C chr_adj. Owners and stock lists come from
	TABLES.C via tools/convert.py (data/stores.asm).
	Not yet: haggling, magical pluses on store items, the 1000-turn
	restock while you're in the dungeon (stores restock on each visit).
 */

OWN_NAME			equ 0
OWN_PURSE			equ 2				; word: the most they'll pay
OWN_MAX_INFLATE		equ 4
OWN_MIN_INFLATE		equ 5
OWN_RACE			equ 7
STORE_CHOICES		equ 30
STORE_MIN_INVEN		equ 10
STORE_MAX_INVEN		equ 18
STORE_TURN_AROUND	equ 9
LIST_ROW			equ 3
PRICE_COL			equ 68
STORE_MSG_ROW		equ 28
STORE_PROMPT_ROW	equ 29
STORE_CMD_ROW		equ 31

/* store_init - every store gets one of its three possible owners and
	nothing in stock (store_init in STORE1.C) */
store_init:
	ld b,0
.each:
	push bc
	ld a,3
	call randint
	dec a
	add a,a
	add a,a
	add a,a								; 8 * (1d3 - 1) + store
	pop bc
	push bc
	add a,b
	ld hl,STORE_OWNER
	ld e,b
	ld d,0
	add hl,de
	ld (hl),a
	ld hl,STORE_COUNT
	add hl,de
	ld (hl),0
	pop bc
	inc b
	ld a,b
	cp NUM_STORES
	jr c,.each
	ret

/* store_maint - sell off some stock and make some more, in every store
	but the home (store_maint in STORE1.C) */
store_maint:
	xor a
.each:
	ld (maint_store),a
	call store_count
	cp STORE_MIN_INVEN
	jr c,.make
	ld a,STORE_TURN_AROUND				; j = 1d9, more if overstocked
	call randint
	ld b,a
	call store_count
	cp STORE_MAX_INVEN
	jr c,.destroy
	sub STORE_MAX_INVEN-1
	add a,b
	ld b,a
.destroy:
	push bc
	call store_count
	or a
	jr z,.destroyed
	call randint
	dec a
	ld b,a
	ld a,(maint_store)
	call store_destroy
.destroyed:
	pop bc
	djnz .destroy
.make:
	call store_count
	cp STORE_MAX_INVEN+1
	jr nc,.next
	ld a,STORE_TURN_AROUND				; j = 1d9, more if understocked
	call randint
	ld b,a
	call store_count
	cp STORE_MIN_INVEN
	jr nc,.create
	neg
	add a,STORE_MIN_INVEN
	add a,b
	ld b,a
.create:
	push bc
	ld a,(maint_store)
	call store_create
	pop bc
	djnz .create
.next:
	ld a,(maint_store)
	inc a
	cp STORE_HOME
	jr c,.each
	ret

/* store_count - A = number of entries in maint_store's stock */
store_count:
	ld a,(maint_store)
store_count_a:
	ld hl,STORE_COUNT
	add hl,a
	ld a,(hl)
	ret

/* store_create - A = store: try a few times to stock one more item from
	its choice list (or anything up to level 40 for the black market),
	with magical pluses as magic_treasure gives them (store_create) */
store_create:
	ld (cs_store),a
	ld b,4								; tries
.try:
	push bc
	ld a,(cs_store)
	cp STORE_BLACK
	jr nz,.choice
.black:									; (stands in for get_obj_num(40))
	ld hl,NUM_KINDS
	call randint16
	dec hl
	call kind_addr
	ld a,(iy+K_LEVEL)
	cp 41
	jr nc,.black
	ld a,40
	jr .chosen
.choice:
	ld a,STORE_CHOICES
	call randint
	dec a
	ld c,a
	ld a,(cs_store)
	ld e,a
	ld d,STORE_CHOICES
	mul d,e
	ld a,c
	add de,a
	ex de,hl
	add hl,hl
	ld de,store_choice_table
	add hl,de
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	ld a,h
	cp $FF
	jr z,.failed						; nothing the game has yet
	ld a,OBJ_TOWN_LEVEL
.chosen:
	ld ix,new_rec						; make one: HL = kind, A = level
	OVCALL PAGE_MISC, new_store_item, PAGE_STORE
	bit ID_CURSED_BIT,(ix+I_IDENT)		; must be good (cursed: cost 0),
	jr nz,.failed						; worth something, and less than the
	call item_kind_addr					; owner can afford
	ld l,(iy+K_COST)
	ld h,(iy+K_COST+1)
	ld a,h
	or l
	jr z,.failed
	ld a,(cs_store)
	cp STORE_BLACK
	jr z,.affordable
	push hl
	call owner_rec
	pop hl
	ld e,(iy+OWN_PURSE)
	ld d,(iy+OWN_PURSE+1)
	or a
	sbc hl,de
	jr nc,.failed
.affordable:
	ld a,(cs_store)
	ld b,a
	call store_has_room
	jr nc,.failed
	call special_offer
	ld c,a
	ld a,(cs_store)
	ld b,a
	call store_carry
	pop bc
	ret
.failed:
	pop bc
	dec b
	jp nz,.try
	ret

/* special_offer - A = discount: 1 in 30 25% off, 1 in 150 50%, 1 in 300
	75%, 1 in 500 "to clear" (90%) */
special_offer:
	ld a,30
	call randint
	dec a
	ld a,1
	ret z
	ld a,150
	call randint
	dec a
	ld a,2
	ret z
	ld hl,300
	call randint16
	dec hl
	ld a,h
	or l
	ld a,3
	ret z
	ld hl,500
	call randint16
	dec hl
	ld a,h
	or l
	ld a,4
	ret z
	xor a
	ret

/* store_entry - A = store, B = position -> HL = stock entry. Clobbers DE */
store_entry:
	ld e,a
	ld d,STORE_INVEN_MAX
	mul d,e
	ld a,b
	add a,e								; (at most 191)
	ld e,a
	ld d,STORE_ITEM
	mul d,e
	ld hl,store_inv
	add hl,de
	ret

/* entry_is_kind - HL = stock entry, DE = kind -> Z if it's that kind.
	Preserves HL, DE */
entry_is_kind:
	ld a,(hl)
	cp e
	ret nz
	inc hl
	ld a,(hl)
	dec hl
	cp d
	ret

/* stacks - IX = item -> Z set if it stacks (food, potions, scrolls) */
stacks:
	call item_kind_addr
	ld a,(iy+K_CLASS)
	cp IC_WAND
	jr nc,.no
	xor a
	ret
.no:
	or 1
	ret

/* store_has_room - IX = item, B = store -> carry if it fits */
store_has_room:
	ld a,b
	ld (hr_store),a
	call store_count_a
	cp STORE_INVEN_MAX
	ret c								; a free entry
	call stacks							; or a stack to join
	ret nz
	ld a,(hr_store)
	call store_count_a
	ld c,a
	ld b,0
.scan:
	push bc
	ld a,(hr_store)
	call store_entry
	pop bc
	ld e,(ix+I_KIND)
	ld d,(ix+I_KIND_HI)
	call entry_is_kind
	scf
	ret z
	inc b
	ld a,b
	cp c
	jr c,.scan
	or a
	ret

/* store_carry - IX = item, B = store, C = discount: add one, joining a
	stack of the same kind and price, else in order of tval, highest first
	(store_carry in STORE1.C) */
store_carry:
	ld a,b
	ld (sc_store),a
	ld a,c
	ld (sc_discount),a
	call stacks
	jr nz,.insert
	ld a,(sc_store)
	call store_count_a
	ld c,a
	ld b,0
.stack:
	ld a,b
	cp c
	jr nc,.insert
	push bc
	ld a,(sc_store)
	call store_entry
	pop bc
	ld e,(ix+I_KIND)
	ld d,(ix+I_KIND_HI)
	call entry_is_kind
	jr nz,.next_stack
	push hl
	ld de,SE_DISC
	add hl,de
	ld a,(sc_discount)
	cp (hl)
	pop hl
	jr nz,.next_stack
	inc hl
	inc hl
	inc (hl)							; one more of these
	ret
.next_stack:
	inc b
	jr .stack
.insert:
	ld a,(sc_store)
	call store_count_a
	cp STORE_INVEN_MAX
	ret nc								; (full: callers check, but be safe)
	call item_kind_addr					; tval of the new item
	ld a,(iy+K_TVAL)
	ld (sc_tval),a
	ld a,(sc_store)
	call store_count_a
	ld c,a
	ld b,0
.find:									; first entry with a lower tval
	ld a,b
	cp c
	jr nc,.here
	push bc
	ld a,(sc_store)
	call store_entry
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	call kind_addr
	pop bc
	ld a,(sc_tval)
	cp (iy+K_TVAL)
	jr z,.later
	jr nc,.here
.later:
	inc b
	jr .find
.here:									; B = where it goes, C = entries
	ld a,c
	sub b
	jr z,.write							; at the end: nothing to move
	ld e,a
	ld d,STORE_ITEM
	mul d,e
	ld a,e
	ld (sc_bytes),a
	push bc
	ld a,(sc_store)
	ld b,c
	call store_entry					; HL = first free entry
	ld de,STORE_ITEM-1
	add hl,de							; its last byte
	ld d,h
	ld e,l
	ld bc,-STORE_ITEM
	add hl,bc							; the last byte in use
	ld a,(sc_bytes)
	ld c,a
	ld b,0
	lddr								; move the later entries up one
	pop bc
.write:
	ld a,(sc_store)
	call store_entry
	ld a,(ix+I_KIND)
	ld (hl),a
	inc hl
	ld a,(ix+I_KIND_HI)
	ld (hl),a
	inc hl
	ld (hl),1
	inc hl
	ld a,(sc_discount)
	ld (hl),a
	inc hl
	ld a,(ix+I_PVAL)
	ld (hl),a
	inc hl
	ld a,(ix+I_TOHIT)
	ld (hl),a
	inc hl
	ld a,(ix+I_TODAM)
	ld (hl),a
	inc hl
	ld a,(ix+I_TOAC)
	ld (hl),a
	inc hl
	ld a,(ix+I_NAME2)
	ld (hl),a
	inc hl
	ld a,(ix+I_IDENT)					; (the home keeps what you knew)
	ld (hl),a
	ld a,(sc_store)						; one more entry
	ld hl,STORE_COUNT
	add hl,a
	inc (hl)
	ret

/* entry_to_item - HL = stock entry, IX = item record: it, as a known,
	store bought item (number as in the store) */
entry_to_item:
	ld a,(hl)
	ld (ix+I_KIND),a
	inc hl
	ld a,(hl)
	ld (ix+I_KIND_HI),a
	inc hl
	ld a,(hl)
	ld (ix+I_NUMBER),a
	inc hl
	inc hl
	ld a,(hl)
	ld (ix+I_PVAL),a
	ld (ix+I_PVAL+1),0
	inc hl
	ld a,(hl)
	ld (ix+I_TOHIT),a
	inc hl
	ld a,(hl)
	ld (ix+I_TODAM),a
	inc hl
	ld a,(hl)
	ld (ix+I_TOAC),a
	inc hl
	ld a,(hl)
	ld (ix+I_NAME2),a
	inc hl
	ld a,(cur_store)					; a store's goods are known; the
	cp STORE_HOME						; home gives back what you left
	ld a,(hl)
	jr z,$+4
	or 1<<ID_STORE_BIT|1<<ID_KNOWN2_BIT
	ld (ix+I_IDENT),a
	ld (ix+I_MARKED),1
	ld (ix+I_FEEL),FEEL_NONE
	ret

/* store_destroy - A = store, B = position: 1d(number) of it go */
store_destroy:
	ld (sd_store),a
	ld a,b
	ld (sd_pos),a
	ld a,(sd_store)
	call store_entry
	inc hl
	inc hl
	push hl
	ld a,(hl)
	call randint
	pop hl
	ld c,a
	ld a,(hl)
	sub c
	ld (hl),a
	ret nz
	ld a,(sd_store)						; all gone: close the gap
	ld hl,sd_pos
	ld b,(hl)
	jr store_remove

/* store_remove - A = store, B = position: take the entry out */
store_remove:
	ld (sr_store),a
	push bc
	call store_entry					; DE <- next entries
	pop bc
	push hl
	ld a,(sr_store)
	call store_count_a
	dec a
	sub b								; entries after this one
	pop de
	jr z,.last
	push de
	ld e,a
	ld d,STORE_ITEM
	mul d,e
	ld a,e
	pop de
	ld c,a
	ld b,0
	ld hl,STORE_ITEM
	add hl,de
	ldir
.last:
	ld a,(sr_store)
	ld hl,STORE_COUNT
	add hl,a
	dec (hl)
	ret

/* owner_rec - A = store -> IY = its owner's record. Clobbers DE */
owner_rec:
	ld hl,STORE_OWNER
	add hl,a
	ld e,(hl)
	ld d,OWNER_SIZE
	mul d,e
	ld iy,owner_table
	add iy,de
	ret

; ---------------------------------------------------------------- prices

/* pct - HL * A / 100 -> HL, at most 65535. Clobbers BC, DE */
pct:
	ld c,a
	push hl
	ld d,l
	ld e,c
	mul d,e
	pop hl
	push de
	ld d,h
	ld e,c
	mul d,e								; high byte's product, shifted 8
	pop hl
	ld a,h
	add a,e
	ld h,a
	ld a,d
	adc a,0
	ld e,a
	ld c,100
	call div24_8
	ld a,e
	or a
	ret z
	ld hl,$FFFF
	ret

/* at_least_1 - HL = max(HL, 1) */
at_least_1:
	ld a,h
	or l
	ret nz
	inc hl
	ret

/* item_cost - IX = item, C = discount -> HL = its value: the cost, cut by
	any special offer; pluses and charges add to it once they're known;
	unknown flavours have flat values; known curses are worthless
	(special_offer, item_value in STORE1.C) */
item_cost:
	push bc
	call item_kind_addr
	pop bc
	ld hl,0
	bit ID_DAMD_BIT,(ix+I_IDENT)
	ret nz
	ld l,(iy+K_COST)
	ld h,(iy+K_COST+1)
	push hl
	push bc
	call item_known
	pop bc
	pop hl
	jr c,.known
	ld hl,20							; not known: a flat 20 for potions
	ld a,(iy+K_CLASS)					; and scrolls, 50 wands, 70 staffs,
	cp IC_AMULET						; 45 rings and amulets
	jr c,$+5
	ld hl,45
	cp IC_WAND
	jr nz,$+5
	ld hl,50
	cp IC_STAFF
	jp nz,.offer
	ld hl,70
	jp .offer
.known:
	ld a,(iy+K_CLASS)
	cp IC_AMULET
	jp nc,.jewel
	cp IC_WEAPON
	jr nc,.arms
	call .offer
	ld a,(iy+K_CLASS)					; charges add 1/20 of the cost each
	cp IC_WAND
	jr z,.charged
	cp IC_STAFF
	ret nz
.charged:
	push hl
	call item_pval_known
	ld (ic_pval),a
	pop hl
	push hl
	ld c,20
	call div16_8
	ld a,(ic_pval)
	ld e,a
	ld d,l
	mul d,e								; (cost/20 is under 256 for devices)
	pop hl
	add hl,de
	ret
.arms:									; weapons and armour
	bit ID_KNOWN2_BIT,(ix+I_IDENT)
	ret z								; (pluses unknown: the plain cost)
	call .offer
	ld a,(ix+I_NAME2)					; an ego: + its cost, + so much per
	or a								; point of its number, doubled for
	jr z,.pluses						; the best weapons
	push hl
	call ego_addr
	pop hl
	ld e,(iy+E_COST)
	ld d,(iy+E_COST+1)
	bit EO_ARTIFACT,(iy+E_OPTS)			; an artifact: its own cost
	jr z,.ego_cost
	ex de,hl
	jr .ego_done
.ego_cost:
	call .sat_add
	ld a,(ix+I_PVAL)
	or a
	jr z,.doubled
	bit 7,a
	jr nz,.doubled
	ld b,a
	ld e,(iy+E_P1COST)
	ld d,(iy+E_P1COST+1)
.per_point:
	call .sat_add
	djnz .per_point
.doubled:
	bit EO_DOUBLE,(iy+E_OPTS)
	jr z,.ego_done
	ld d,h
	ld e,l
	call .sat_add
.ego_done:
	push hl
	call item_kind_addr
	pop hl
.pluses:
	ld a,(ix+I_TOAC)					; any minus: worthless
	ld b,a
	or (ix+I_TOHIT)
	or (ix+I_TODAM)
	ld a,(iy+K_CLASS)
	cp IC_WEAPON
	jr z,.weapon
	bit 7,b
	jr nz,.worthless
	ld a,b
	jr .plus
.weapon:
	bit 7,(ix+I_TOHIT)
	jr nz,.worthless
	bit 7,(ix+I_TODAM)
	jr nz,.worthless
	bit 7,(ix+I_TOAC)
	jr nz,.worthless
	ld a,(ix+I_TOHIT)
	add a,(ix+I_TODAM)
	add a,(ix+I_TOAC)
.plus:									; + 100 per plus
	ld e,a
	ld d,100
	mul d,e
	add hl,de
	ret nc
	ld hl,$FFFF
	ret
.worthless:
	ld hl,0
	ret
.sat_add:								; HL += DE, at most 65535
	add hl,de
	ret nc
	ld hl,$FFFF
	ret
.jewel:									; rings and amulets: the cost
	bit ID_KNOWN2_BIT,(ix+I_IDENT)		; magic_treasure gave it: what
	ret z								; its number or pluses add, or
	call .offer							; nothing if cursed
	bit ID_CURSED_BIT,(ix+I_IDENT)
	jr nz,.worthless
	ld a,(iy+K_CLASS)
	ld b,a
	ld a,(iy+K_FLAVOUR)
	ld c,a
	ld de,jewel_values
.find:
	ld a,(de)
	cp $FF
	ret z
	cp b
	jr nz,.skip
	inc de
	ld a,(de)
	dec de
	cp c
	jr z,.found
.skip:
	inc de
	inc de
	inc de
	inc de
	jr .find
.found:
	inc de
	inc de
	ld a,(de)							; the field
	ld c,a
	inc de
	ld a,(de)							; and what each point adds
	ld b,a
	ld a,c
	cp $FF
	jr z,.slaying
	push hl
	push ix
	pop hl
	add hl,a
	ld a,(hl)
	pop hl
	jr .times
.slaying:
	ld a,(ix+I_TOHIT)
	add a,(ix+I_TODAM)
.times:
	bit 7,a
	jr nz,.worthless
	ld e,a
	ld d,b
	mul d,e
	add hl,de
	ret nc
	ld hl,$FFFF
	ret

.offer:
	ld a,c
	or a
	ret z
	ld a,h
	or l
	ret z
	ld a,c
	cp 1
	ld a,75
	jr z,.cut
	ld a,c
	cp 2
	ld a,50
	jr z,.cut
	ld a,c
	cp 3
	ld a,25
	jr z,.cut
	ld a,10
.cut:
	call pct
	jp at_least_1

; class, subval, field ($FF: to-hit + to-dam), gold per point
jewel_values:
	db IC_RING,0,I_PVAL,100, IC_RING,1,I_PVAL,100		; STR, DEX
	db IC_RING,2,I_PVAL,100, IC_RING,3,I_PVAL,100		; CON, INT
	db IC_RING,5,I_PVAL,30								; searching
	db IC_RING,19,I_TODAM,100, IC_RING,20,I_TOHIT,100	; damage, accuracy
	db IC_RING,21,I_TOAC,100, IC_RING,30,$FF,100		; protection, slaying
	db IC_AMULET,0,I_PVAL,100, IC_AMULET,1,I_PVAL,100	; WIS, CHR
	db IC_AMULET,2,I_PVAL,20, IC_AMULET,8,I_PVAL,20	; searching, the Magi
	db $FF

/* buy_price - (cur_store) IX = item, C = discount -> HL = what you pay:
	value * race adjustment * final markup (x2 black market) * charisma */
buy_price:
	call item_cost
	ld a,h
	or l
	ret z
	push hl
	ld a,(cur_store)
	call owner_rec
	call race_adjust
	pop hl
	call pct
	call at_least_1
	ld a,(iy+OWN_MIN_INFLATE)
	call pct
	ld a,(cur_store)
	cp STORE_BLACK
	jr nz,.charisma
	add hl,hl
	jr nc,.charisma
	ld hl,$FFFF
.charisma:
	ld a,(store_chr)
	call pct
	jp at_least_1

/* sell_offer - (cur_store) IX = item -> HL = what they'll pay for one:
	value less the charisma and race adjustments, at their final offer,
	never more than they can afford */
sell_offer:
	ld c,0
	call item_cost
	ld a,h
	or l
	ret z
	push hl
	ld a,(cur_store)
	call owner_rec
	pop hl
	ld a,(store_chr)
	neg
	add a,200
	call pct
	push hl
	call race_adjust
	pop hl
	neg
	add a,200
	call pct
	call at_least_1
	push hl
	ld a,(iy+OWN_MAX_INFLATE)			; max_buy
	neg
	add a,200
	call pct
	call at_least_1
	ld (max_buy),hl
	pop hl
	ld a,(iy+OWN_MIN_INFLATE)			; min_buy, but not below max_buy
	neg
	add a,200
	call pct
	call at_least_1
	ld de,(max_buy)
	push hl
	or a
	sbc hl,de
	pop hl
	jr nc,.capped
	ex de,hl
.capped:								; and no more than their purse
	ld e,(iy+OWN_PURSE)
	ld d,(iy+OWN_PURSE+1)
	push hl
	or a
	sbc hl,de
	pop hl
	ret c
	ex de,hl
	ret

/* race_adjust - IY = owner -> A = rgold_adj[owner race][your race] */
race_adjust:
	ld e,(iy+OWN_RACE)
	ld d,10
	mul d,e
	ld a,(p_race)
	add de,a
	ld hl,rgold_table
	add hl,de
	ld a,(hl)
	ret

/* store_buys - IY = kind -> carry if cur_store deals in its tval
	(general_store, armory... in SETS.C; black market and home take all) */
store_buys:
	ld a,(cur_store)
	cp STORE_BLACK						; the black market and home take
	jr c,.list							; anything
	scf
	ret
.list:
	add a,a
	ld hl,store_buy_lists
	add hl,a
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	ld a,(iy+K_TVAL)
	ld c,a
.scan:
	ld a,(hl)
	or a
	ret z								; (carry clear)
	cp c
	scf
	ret z
	inc hl
	jr .scan

store_buy_lists:
	dw buys_general, buys_armoury, buys_weapons, buys_temple, buys_alchemist, buys_magic
buys_general:	db 25,30,32,80,77,15,13,0	; digging, boots, cloaks, food, flasks, lights, spikes
buys_armoury:	db 30,31,33,34,35,36,0		; boots, gloves, helms, shields, armour
buys_weapons:	db 10,11,12,20,21,22,23,0	; shots, bolts, arrows, bows, hafted, polearms, swords
buys_temple:	db 21,70,71,75,76,91,0		; hafted, scrolls, potions, prayer books
buys_alchemist:	db 70,71,75,76,0			; scrolls, potions
buys_magic:		db 40,45,55,65,70,71,75,76,90,66,0

; ---------------------------------------------------------------- the screen

/* enter_store - A = store: browse, buy and sell until space or Enter */
enter_store:
	ld (cur_store),a
	ld a,(p_stat_use+A_CHR)				; chr_adj()
	ld hl,chr_table
.chr:
	cp (hl)
	jr c,.chr_found
	inc hl
	inc hl
	jr .chr
.chr_found:
	inc hl
	ld a,(hl)
	ld (store_chr),a
	xor a
	ld (store_said),a
.redraw:
	call draw_store
.key:
	call read_ascii
	cp ' '
	jr z,.leave
	cp 13
	jr z,.leave
	or $20
	cp 'p'
	jp z,store_purchase
	cp 'g'
	jp z,store_purchase
	cp 's'
	jp z,store_sell
	cp 'd'
	jp z,store_sell
	jr .key
.leave:
	jp clear_screen

/* say - finish the message being built and keep it for the next redraw */
say:
	ld hl,(msg_ptr)
	ld (hl),0
	ld hl,msg_buf
	ld de,store_text
	ld bc,80
	ldir
	ld a,1
	ld (store_said),a
	jp enter_store.redraw

/* say_text - HL = a fixed message */
say_text:
	push hl
	call msg_begin
	pop hl
	call msg_add
	jr say

/* draw_store - owner, stock with prices, your gold, the commands */
draw_store:
	call clear_screen
	ld a,(cur_store)
	call owner_rec
	ld l,(iy+OWN_NAME)
	ld h,(iy+OWN_NAME+1)
	ld d,1
	ld e,2
	ld c,ATTR_YELLOW
	call print_at
	ld a,(cur_store)
	cp STORE_HOME
	jr z,.no_heading
	ld hl,txt_price_heading
	ld d,LIST_ROW-1
	ld e,PRICE_COL-1
	ld c,ATTR_GREY
	call print_at
.no_heading:
	ld a,(cur_store)
	call store_count_a
	ld (list_count),a
	or a
	jr nz,.stock
	ld hl,txt_no_stock
	ld d,LIST_ROW
	ld e,4
	ld c,ATTR_GREY
	call print_at
	jp .gold
.stock:
	xor a
.line:
	ld (list_pos),a
	call msg_begin						; "a) 3 Rations of Food"
	ld a,(list_pos)
	add a,'a'
	ld (txt_store_label),a
	ld hl,txt_store_label
	call msg_add
	ld a,(cur_store)
	ld hl,list_pos
	ld b,(hl)
	call store_entry
	push hl
	pop ix
	push ix
	call store_objdes
	pop ix
	ld a,(ix+3)							; any discount?
	or a
	jr z,.no_offer
	dec a
	add a,a
	ld hl,offer_texts
	add hl,a
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	call msg_add
.no_offer:
	ld hl,(msg_ptr)
	ld (hl),0
	ld a,(list_pos)
	add a,LIST_ROW
	ld d,a
	ld e,2
	ld hl,msg_buf
	ld c,ATTR_WHITE
	call print_at
	ld a,(cur_store)					; price, but not at home
	cp STORE_HOME
	jr z,.next_line
	call entry_price
	ld a,(list_pos)
	add a,LIST_ROW
	ld d,a
	ld e,PRICE_COL
	push hl
	call screen_addr
	ex de,hl
	pop hl
	ld c,ATTR_WHITE
	call print_u16
.next_line:
	ld a,(list_pos)
	inc a
	ld hl,list_count
	cp (hl)
	jr c,.line
.gold:
	ld hl,txt_gold_left					; "Gold remaining: 312"
	ld d,STORE_PROMPT_ROW-2
	ld e,2
	ld c,ATTR_GREY
	call print_at
	ld hl,p_gold
	ld c,ATTR_WHITE
	call print_u32
	ld hl,txt_store_cmds
	ld a,(cur_store)
	cp STORE_HOME
	jr nz,$+5
	ld hl,txt_home_cmds
	ld d,STORE_CMD_ROW
	ld e,2
	ld c,ATTR_GREY
	call print_at
	ld a,(store_said)
	or a
	ret z
	xor a
	ld (store_said),a
	ld hl,store_text
	ld d,STORE_MSG_ROW
	ld e,2
	ld c,ATTR_YELLOW
	jp print_at

/* store_prompt - HL = question on the prompt row -> A = key */
store_prompt:
	push hl
	ld d,STORE_PROMPT_ROW
	call clear_row
	pop hl
	ld d,STORE_PROMPT_ROW
	ld e,2
	ld c,ATTR_YELLOW
	call print_at
	jp read_ascii

/* store_purchase - 'p' (or 'g' at home): one of an entry into the pack */
store_purchase:
	ld a,(cur_store)
	call store_count_a
	or a
	jr nz,.choose
	ld hl,txt_out_of_stock
	jp say_text
.choose:
	ld hl,txt_buy_which
	ld a,(cur_store)
	cp STORE_HOME
	jr nz,$+5
	ld hl,txt_get_which
	call store_prompt
	or $20
	sub 'a'
	ld (list_pos),a
	ld hl,list_count
	cp (hl)
	jp nc,enter_store.redraw
	ld a,(cur_store)
	ld hl,list_pos
	ld b,(hl)
	call store_entry
	push hl
	pop ix
	ld hl,0								; price (free at home)
	ld a,(cur_store)
	cp STORE_HOME
	jr z,.priced
	call entry_price
.priced:
	ld (deal_price),hl
	ld de,(p_gold+2)					; enough gold?
	ld a,d
	or e
	jr nz,.afford
	ld de,(p_gold)
	ex de,hl
	or a
	sbc hl,de
	jr nc,.afford
	ld hl,txt_no_gold
	jp say_text
.afford:
	push ix								; one of them, as a pack item
	pop hl
	push ix
	ld ix,deal_item
	call entry_to_item
	ld (ix+I_NUMBER),1
	pop ix
	push ix
	ld ix,deal_item
	call pack_carry
	pop ix
	jr c,.carried
	ld hl,txt_no_room
	jp say_text
.carried:
	ld (deal_slot),a
	ld hl,(p_gold)						; pay
	ld de,(deal_price)
	or a
	sbc hl,de
	ld (p_gold),hl
	ld hl,(p_gold+2)
	ld de,0
	sbc hl,de
	ld (p_gold+2),hl
	dec (ix+2)							; one fewer in the store
	jr nz,.described
	ld a,(cur_store)
	ld hl,list_pos
	ld b,(hl)
	call store_remove
.described:
	call msg_begin						; "You have a Dagger (1d4) (c)."
	ld hl,txt_you_have_s
	call msg_add
	ld a,(deal_slot)
	call pack_slot
	call objdes_msg
	ld a,(deal_slot)
	add a,'a'
	ld (txt_letter+2),a
	ld hl,txt_letter
	call msg_add
	jp say

/* store_sell - 's' (or 'd' at home): one of a pack item into the store */
store_sell:
	call draw_store						; list what they'll take
	ld d,LIST_ROW
	call clear_rows
	xor a
	ld (list_pos),a						; pack slot
	ld (list_count),a					; lines shown
.list:
	ld a,(list_pos)
	call pack_slot
	ld a,(ix+I_KIND_HI)
	cp ITEM_EMPTY
	jr z,.listed
	call item_kind_addr
	call store_buys
	jr nc,.skip
	call msg_begin
	ld a,(list_pos)
	add a,'a'
	ld (txt_store_label),a
	ld hl,txt_store_label
	call msg_add
	ld a,(list_pos)
	call pack_slot
	call objdes_msg
	ld hl,(msg_ptr)
	ld (hl),0
	ld a,(list_count)
	add a,LIST_ROW
	ld d,a
	ld e,2
	ld hl,msg_buf
	ld c,ATTR_WHITE
	call print_at
	ld hl,list_count
	inc (hl)
.skip:
	ld hl,list_pos
	inc (hl)
	ld a,(hl)
	cp PACK_MAX
	jr c,.list
.listed:
	ld a,(list_count)
	or a
	jr nz,.choose
	ld hl,txt_nothing_to_sell
	jp say_text
.choose:
	ld hl,txt_sell_which
	ld a,(cur_store)
	cp STORE_HOME
	jr nz,$+5
	ld hl,txt_drop_which_s
	call store_prompt
	or $20
	sub 'a'
	cp PACK_MAX
	jp nc,enter_store.redraw
	ld (deal_slot),a
	call pack_slot
	ld a,(ix+I_KIND_HI)
	cp ITEM_EMPTY
	jp z,enter_store.redraw
	call item_kind_addr
	call store_buys
	jp nc,enter_store.redraw
	ld a,(cur_store)					; room?
	ld b,a
	call store_has_room
	jr c,.room
	ld hl,txt_store_full
	jp say_text
.room:
	ld hl,0
	ld a,(cur_store)
	cp STORE_HOME
	jr z,.offered
	call sell_offer
	ld a,h
	or l
	jr nz,.offered
	ld hl,txt_not_interested
	jp say_text
.offered:
	ld (deal_price),hl
	ld de,(p_gold)						; paid
	add hl,de
	ld (p_gold),hl
	ld hl,(p_gold+2)
	ld de,0
	adc hl,de
	ld (p_gold+2),hl
	ld a,(deal_slot)
	call pack_slot
	push ix								; a copy of one of them
	pop hl
	ld de,deal_item
	ld bc,ITEM_SIZE
	ldir
	ld a,(cur_store)					; selling identifies it (STORE2.C),
	cp STORE_HOME						; which may combine stacks
	jr z,.known
	ld hl,(deal_item+I_KIND)
	call learn_kind
	ld hl,(deal_item+I_KIND)
	call kind_addr
	call ident_addr
	jr nc,.known						; (no flavour: nothing moved)
	ld hl,(deal_item+I_KIND)
	call find_pack_kind
	ld (deal_slot),a
.known:
	ld a,(deal_slot)
	call pack_slot
	ld a,1								; describe one of them: known now
	ld (deal_item+I_NUMBER),a
	ld a,(cur_store)
	cp STORE_HOME						; (the home learns nothing)
	jr z,.home_copy
	ld a,(deal_item+I_IDENT)
	or 1<<ID_STORE_BIT|1<<ID_KNOWN2_BIT
	ld (deal_item+I_IDENT),a
.home_copy:
	call msg_begin
	ld hl,txt_you_sold
	ld a,(cur_store)
	cp STORE_HOME
	jr nz,$+5
	ld hl,txt_you_drop_s
	call msg_add
	push ix
	ld ix,deal_item
	call objdes_msg
	pop ix
	ld a,(cur_store)
	cp STORE_HOME
	jr z,.dropped
	ld hl,txt_for
	call msg_add
	ld hl,deal_price
	call store_add_u16
	ld hl,txt_gold_pieces
	call msg_add
.dropped:
	ld hl,txt_full_stop
	call msg_add
	ld a,(cur_store)					; into the store, out of the pack
	ld b,a
	ld c,0
	push ix
	ld ix,deal_item
	call store_carry
	pop ix
	ld a,(deal_slot)
	call use_one
	jp say

/* store_objdes - IX = stock entry: describe it, as a known item */
store_objdes:
	push ix
	pop hl
	ld ix,show_item
	call entry_to_item
	jp objdes_msg

/* entry_price - IX = stock entry -> HL = its price */
entry_price:
	push ix
	ld c,(ix+SE_DISC)
	push bc
	push ix
	pop hl
	ld ix,show_item
	call entry_to_item
	pop bc
	call buy_price
	pop ix
	ret

/* clear_rows - D = first row: clear down to the prompt row */
clear_rows:
	push de
	call clear_row
	pop de
	inc d
	ld a,d
	cp STORE_PROMPT_ROW-2
	jr c,clear_rows
	ret

/* store_add_u16 - HL -> 16-bit value: add it as a decimal number */
store_add_u16:
	xor a
	ld (u16_started),a
	ld e,(hl)
	inc hl
	ld d,(hl)
	ex de,hl
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
	ret
.digit:
	ld a,'0'
.sub:
	or a
	sbc hl,bc
	jr c,.got
	inc a
	jr .sub
.got:
	add hl,bc
	cp '0'
	jr nz,.write
	push af
	ld a,(u16_started)
	or a
	jr z,.skip
	pop af
.write:
	ld (de),a
	inc de
	ld a,1
	ld (u16_started),a
	ret
.skip:
	pop af
	ret

; chr_adj() in MISC2.C as (charisma below this, percent) pairs
chr_table:
	db 4,130, 5,125, 6,122, 7,120, 8,118, 9,116, 10,114, 11,112, 12,110
	db 13,108, 14,106, 15,104, 16,103, 17,102, 18,101, 19,100, 68,98
	db 88,96, 108,94, 118,92, 148,90, 188,88, 218,86, 255,80

offer_texts:	dw txt_off25, txt_off50, txt_off75, txt_off90
txt_off25:		db " {25% discount}",0
txt_off50:		db " {50% discount}",0
txt_off75:		db " {75% discount}",0
txt_off90:		db " {to clear}",0
txt_price_heading: db "Price",0
txt_no_stock:	db "(nothing)",0
txt_gold_left:	db "Gold remaining: ",0
txt_store_cmds:	db "p) Purchase an item    s) Sell an item    Space) Leave",0
txt_home_cmds:	db "g) Get an item    d) Drop an item    Space) Leave",0
txt_buy_which:	db "Purchase which item? (letter, or space)",0
txt_get_which:	db "Get which item? (letter, or space)",0
txt_sell_which:	db "Sell which item? (letter, or space)",0
txt_drop_which_s: db "Drop which item? (letter, or space)",0
txt_out_of_stock: db "I am currently out of stock.",0
txt_no_gold:	db "You do not have enough gold for this item.",0
txt_no_room:	db "You cannot carry that many items.",0
txt_nothing_to_sell: db "You have nothing that I want.",0
txt_store_full:	db "I have not the room in my store to keep it.",0
txt_not_interested: db "I am not interested in that.",0
txt_you_have_s:	db "You have ",0
txt_you_sold:	db "You sold ",0
txt_you_drop_s:	db "You drop ",0
txt_for:		db " for ",0
txt_gold_pieces: db " gold",0
txt_letter:		db " (a).",0
txt_store_label: db "a) ",0

cur_store:		db 0
store_chr:		db 100
store_said:		db 0
store_text:		ds 80
list_pos:		db 0
list_count:		db 0
deal_price:		dw 0
deal_slot:		db 0
deal_item:		ds ITEM_SIZE
show_item:		ds ITEM_SIZE
ic_pval:		db 0
max_buy:		dw 0
maint_store:	db 0
cs_store:		db 0
cs_kind:		dw 0
cs_disc:		db 0
hr_kind:		dw 0
hr_store:		db 0
sc_kind:		dw 0
sc_pval:		db 0
sc_store:		db 0
sc_discount:	db 0
sc_tval:		db 0
sc_bytes:		db 0
sd_store:		db 0
sd_pos:			db 0
sr_store:		db 0
u16_started:	db 0

; the stock of every store (the home's too): only this overlay looks at it
store_inv:		ds NUM_STORES*STORE_INVEN_MAX*STORE_ITEM
