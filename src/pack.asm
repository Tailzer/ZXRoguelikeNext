/* pack.asm - item descriptions and the pack  [resident]
	Shared by the item commands (inventory.asm) and the stores (store.asm).
	References: MISC2.C objdes/inven_carry
 */

/* objdes_msg - add the description of item IX to the message being built:
	"a Dagger (1d4)", "2 Rations of Food", "Chain Mail [14]", and for
	flavours not yet known "a Cloudy Potion {tried}" (objdes in DESC.C) */
objdes_msg:
	ld a,(ix+I_KIND)
	call kind_addr
	call item_known
	sbc a,a
	cpl
	ld (od_unknown),a					; $FF: show the flavour instead
	ld a,(ix+I_NUMBER)
	or a
	jr z,.no_more
	cp 1
	jr nz,.several
	ld a,(od_unknown)
	or a
	jr nz,.unknown_one
	call kind_name
	ld a,(iy+K_ARTICLE)					; "Chain Mail" has no article
	or a
	jr z,.no_article
	ld a,(hl)
	call .article
.no_article:
	ld b,0
	call .name
	jr .suffix
.unknown_one:							; "& %s Potion~" always has one
	call flavour_name
	ld a,(hl)
	call .article
	ld b,0
	jr .flavoured
.no_more:
	ld hl,txt_no_more_
	call msg_add
	jr .plural
.several:
	call msg_add_u8
	ld hl,txt_space_
	call msg_add
.plural:
	ld b,1
	ld a,(od_unknown)
	or a
	jr nz,.flavoured
	call .name
	jr .suffix
.flavoured:								; B = 1 for plural
	push bc
	ld a,(ix+I_KIND)					; (the colours may be paged in)
	call kind_addr
	call flavour_name
	call msg_add
	ld a,(ix+I_KIND)
	call kind_addr
	pop bc
	ld hl,txt_potion_tilde
	call .copy_hl
.suffix:
	ld a,(od_unknown)					; " {tried}"
	or a
	jr z,.class
	call ident_addr
	bit OD_TRIED_BIT,(hl)
	jr z,.class
	ld hl,txt_tried
	call msg_add
.class:
	ld a,(iy+K_CLASS)
	cp IC_WEAPON
	jr z,.dice
	cp IC_BODY
	ret c								; food, potions
	ld hl,txt_open_sq					; " [ac]"
	call msg_add
	ld a,(iy+K_AC)
	call msg_add_u8
	ld hl,txt_close_sq
	jp msg_add
.dice:
	ld hl,txt_open_br					; " (XdY)"
	call msg_add
	ld a,(iy+K_DICE)
	call msg_add_u8
	ld hl,txt_d
	call msg_add
	ld a,(iy+K_SIDES)
	call msg_add_u8
	ld hl,txt_close_br
	jp msg_add
.article:								; A = first letter: "a " or "an "
	call is_vowel
	ld hl,txt_a_
	jr nz,$+5
	ld hl,txt_an_
	jp msg_add
.name:									; copy the name, '~' -> 's' if B=1
	push bc
	call kind_name
	pop bc
.copy_hl:
	ld de,(msg_ptr)
.copy:
	ld a,(hl)
	inc hl
	or a
	jr z,.copied
	cp '~'
	jr nz,.char
	bit 0,b
	jr z,.copy
	ld a,'s'
.char:
	ld (de),a
	inc de
	jr .copy
.copied:
	ld (msg_ptr),de
	ret

/* desc_remain - A = pack slot just used from: "You have 2 Potions of
	Healing (a)." / "You have no more ..." (desc_remain in DESC.C) */
desc_remain:
	push af
	call pack_slot
	call msg_begin
	ld hl,txt_you_have_r
	call msg_add
	dec (ix+I_NUMBER)
	call objdes_msg
	inc (ix+I_NUMBER)
	pop af
	add a,'a'
	ld (txt_slot_r+2),a
	ld hl,txt_slot_r
	call msg_add
	jp msg_end

/* is_vowel - A = letter -> Z if it is a capital vowel */
is_vowel:
	cp 'A'
	ret z
	cp 'E'
	ret z
	cp 'I'
	ret z
	cp 'O'
	ret z
	cp 'U'
	ret

/* pack_count - A = how many pack slots are in use */
pack_count:
	ld hl,PACK+I_KIND
	ld de,ITEM_SIZE
	ld b,PACK_MAX
	ld c,0
.loop:
	ld a,(hl)
	cp ITEM_EMPTY
	jr z,.done
	inc c
	add hl,de
	djnz .loop
.done:
	ld a,c
	ret

/* pack_slot - A = slot -> IX = its record. Clobbers DE */
pack_slot:
	ld e,a
	ld d,ITEM_SIZE
	mul d,e
	ld ix,PACK
	add ix,de
	ret

/* pack_carry - IX = item (floor record) to add to the pack, one stack.
	Food and potions stack with the same kind when both or neither are
	known (inven_carry in MISC2.C).
	-> carry set and A = slot it went into, or carry clear if no room */
pack_carry:
	ld (carry_src),ix
	call .carry
	ld ix,(carry_src)
	ret
.carry:
	ld a,(ix+I_KIND)
	call kind_addr
	ld a,(iy+K_CLASS)
	cp IC_WEAPON
	jr nc,.new_slot						; only food and potions stack
	call item_known
	sbc a,a
	ld (carry_known),a
	xor a
.stack:
	ld (carry_try),a
	call pack_slot
	ld a,(ix+I_KIND)
	ld hl,(carry_src)
	cp (hl)								; (I_KIND is offset 0)
	jr nz,.not_same
	call kind_addr
	call item_known
	sbc a,a
	ld hl,carry_known
	cp (hl)
	jr nz,.not_same
	ld hl,(carry_src)
	inc hl								; I_NUMBER
	ld a,(ix+I_NUMBER)
	add a,(hl)
	ld (ix+I_NUMBER),a
	ld a,(carry_try)
	scf
	ret
.not_same:
	ld a,(carry_try)
	inc a
	cp PACK_MAX
	jr c,.stack
.new_slot:
	ld ix,(carry_src)
	call pack_count
	cp PACK_MAX
	ret nc								; carry clear: no room
	push af
	push ix
	pop hl
	call pack_slot
	push ix
	pop de
	ld bc,ITEM_SIZE
	ldir
	pop af
	scf
	ret

/* pack_combine - A = a kind just identified: its stacks in the pack join
	the first one (identify in DESC.C) */
pack_combine:
	ld (comb_kind),a
	xor a
	ld (comb_first),a
.find:
	call pack_slot
	ld a,(ix+I_KIND)
	ld hl,comb_kind
	cp (hl)
	jr z,.found
	ld a,(comb_first)
	inc a
	ld (comb_first),a
	cp PACK_MAX
	jr c,.find
	ret
.found:
	ld (comb_dst),ix
	ld a,(comb_first)
.next:
	inc a
	cp PACK_MAX
	ret nc
	ld (comb_try),a
	call pack_slot
	ld a,(ix+I_KIND)
	ld hl,comb_kind
	cp (hl)
	ld a,(comb_try)
	jr nz,.next
	ld a,(ix+I_NUMBER)
	ld ix,(comb_dst)
	add a,(ix+I_NUMBER)
	ld (ix+I_NUMBER),a
	ld a,(comb_try)
	call pack_remove
	ld hl,msg_combine
	call msg_print
	ld a,(comb_try)						; the next one has moved up
	dec a
	jr .next

/* find_pack_kind - A = kind -> A = the first pack slot holding it */
find_pack_kind:
	ld hl,PACK+I_KIND
	ld de,ITEM_SIZE
	ld c,0
.loop:
	cp (hl)
	jr z,.found
	add hl,de
	inc c
	ld b,a
	ld a,c
	cp PACK_MAX
	ld a,b
	jr c,.loop
.found:
	ld a,c
	ret

/* pack_remove - A = slot: close the gap so the pack stays packed */
pack_remove:
	ld c,a
	call pack_slot
	push ix
	pop de								; DE = this slot
	ld hl,ITEM_SIZE
	add hl,de							; HL = next slot
	ld a,PACK_MAX-1
	sub c
	jr z,.last
	ld b,a								; slots after this one
.shift:
	push bc
	ld bc,ITEM_SIZE
	ldir
	pop bc
	djnz .shift
.last:
	ld hl,PACK+(PACK_MAX-1)*ITEM_SIZE
	ld (hl),ITEM_EMPTY
	ret

/* use_one - A = slot: one of the stack is used up */
use_one:
	push af
	call pack_slot
	dec (ix+I_NUMBER)
	pop bc
	ret nz
	ld a,b
	jp pack_remove

txt_a_:			db "a ",0
txt_an_:		db "an ",0
txt_space_:		db " ",0
txt_open_sq:	db " [",0
txt_close_sq:	db "]",0
txt_open_br:	db " (",0
txt_d:			db "d",0
txt_close_br:	db ")",0
txt_no_more_:	db "no more ",0
txt_potion_tilde: db " Potion~",0
txt_tried:		db " {tried}",0
txt_you_have_r:	db "You have ",0
txt_slot_r:		db " (a).",0
msg_combine:	db "You combine similar objects from the shop and dungeon.",0
carry_src:		dw 0
carry_known:	db 0
carry_try:		db 0
od_unknown:		db 0
comb_kind:		db 0
comb_first:		db 0
comb_try:		db 0
comb_dst:		dw 0
