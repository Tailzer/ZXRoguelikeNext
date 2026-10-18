/* pack.asm - item descriptions and the pack  [resident]
	Shared by the item commands (inventory.asm) and the stores (store.asm).
	References: MISC2.C objdes/inven_carry
 */

/* objdes_msg - add the description of item IX to the message being built:
	"a Dagger (1d4)", "2 Rations of Food", "Chain Mail [14]", and for
	flavours not yet known "a Cloudy Potion {tried}" (objdes in DESC.C) */
objdes_msg:
	call item_kind_addr
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
	ld a,(od_bare)						; ("The Dagger you are wielding...")
	or a
	jr nz,.no_article
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
	call flavour_class
	cp OFS_SCROLL
	ld a,'S'							; ("& Scroll~ titled ...")
	jr z,.unknown_art
	call flavour_name
	ld a,(hl)
.unknown_art:
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
	call item_kind_addr					; (the colours may be paged in)
	call flavour_class
	cp OFS_SCROLL
	jr z,.titled
	ld (od_class),a
	push bc
	call flavour_name
	call msg_add
	call item_kind_addr
	pop bc
	ld a,(od_class)						; "& %s Potion~", "& %s Staff"...
	ld hl,txt_potion_tilde
	cp OFS_POTION
	jr z,.noun
	ld hl,txt_staff_
	cp OFS_STAFF
	jr z,.noun
	ld hl,txt_wand_
	cp OFS_WAND
	jr z,.noun
	ld hl,txt_rod_
.noun:
	call .copy_hl
	jr .suffix
.titled:								; Scroll~ titled "abra kadab"
	ld hl,txt_scroll_tilde
	call .copy_hl
	call flavour_name
	call msg_add
	call item_kind_addr
	ld hl,txt_quote
	call msg_add
.suffix:
	ld a,(od_bare)						; just the name (objdes, pref FALSE)
	or a
	ret nz
	ld a,(iy+K_CLASS)
	cp IC_WEAPON
	jr z,.weapon
	jr nc,.armour
	cp IC_WAND							; " (5 charges)" once they're known
	jr z,.charges
	cp IC_STAFF
	jp nz,.notes
.charges:
	bit ID_KNOWN2_BIT,(ix+I_IDENT)
	jp z,.notes
	ld hl,txt_open_br
	call msg_add
	ld a,(ix+I_PVAL)
	call msg_add_u8
	ld hl,txt_charges_
	call msg_add
	jp .notes
.weapon:								; " (2d5)"
	ld hl,txt_open_br
	call msg_add
	ld a,(iy+K_DICE)
	call msg_add_u8
	ld hl,txt_d
	call msg_add
	ld a,(iy+K_SIDES)
	call msg_add_u8
	ld hl,txt_close_br
	call msg_add
.armour:								; once known: " (+3,+2)" (or just
	bit ID_KNOWN2_BIT,(ix+I_IDENT)		; the one that isn't 0), then
	jr z,.ac							; " [14,+3]" (" [14]" unknown)
	bit ID_SHOWHD_BIT,(ix+I_IDENT)
	jr z,.one
	call .hit_dam
	jr .ac
.one:
	ld a,(ix+I_TOHIT)
	or a
	jr nz,.one_plus
	ld a,(ix+I_TODAM)
	or a
	jr z,.ac
.one_plus:
	push af
	ld hl,txt_open_br
	call msg_add
	pop af
	call .signed
	ld hl,txt_close_br
	call msg_add
.ac:
	ld a,(iy+K_AC)						; (helms always: crowns have none)
	or a
	jr nz,.ac_base
	ld a,(iy+K_CLASS)
	cp IC_HELM
	jr z,.ac_base
	bit ID_KNOWN2_BIT,(ix+I_IDENT)		; " [+3]" if only magical
	jr z,.notes
	ld a,(ix+I_TOAC)
	or a
	jr z,.notes
	ld hl,txt_open_sq
	call msg_add
	ld a,(ix+I_TOAC)
	call .signed
	jr .ac_done
.ac_base:
	ld hl,txt_open_sq
	call msg_add
	ld a,(iy+K_AC)
	call msg_add_u8
	bit ID_KNOWN2_BIT,(ix+I_IDENT)
	jr z,.ac_done
	ld a,','
	call .put_char
	ld a,(ix+I_TOAC)
	call .signed
.ac_done:
	ld hl,txt_close_sq
	call msg_add
.notes:									; {tried blessed empty cursed good}
	xor a
	ld (od_note),a
	ld a,(od_unknown)
	or a
	jr z,.blessed
	call ident_addr
	bit OD_TRIED_BIT,(hl)
	ld hl,txt_tried
	call nz,.note
.blessed:
	bit ID_MAGIK_BIT,(ix+I_IDENT)
	ld hl,txt_blessed
	call nz,.note
	bit ID_KNOWN2_BIT,(ix+I_IDENT)
	jr nz,.cursed
	bit ID_EMPTY_BIT,(ix+I_IDENT)
	ld hl,txt_empty
	call nz,.note
.cursed:
	bit ID_DAMD_BIT,(ix+I_IDENT)
	ld hl,txt_cursed
	call nz,.note
	ld a,(ix+I_FEEL)					; how it felt, until it's known
	or a
	jr z,.close
	bit ID_KNOWN2_BIT,(ix+I_IDENT)
	jr nz,.close
	dec a
	add a,a
	ld hl,feel_words
	add hl,a
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	call .note
.close:
	ld a,(od_note)
	or a
	ret z
	ld hl,txt_brace
	jp msg_add
.note:									; " {" first, " " after
	push hl
	ld a,(od_note)
	or a
	ld hl,txt_open_brace
	jr z,$+5
	ld hl,txt_space_
	call msg_add
	pop hl
	ld a,1
	ld (od_note),a
	jp msg_add
.hit_dam:								; " (+3,+2)"
	ld hl,txt_open_br
	call msg_add
	ld a,(ix+I_TOHIT)
	call .signed
	ld a,','
	call .put_char
	ld a,(ix+I_TODAM)
	call .signed
	ld hl,txt_close_br
	jp msg_add
.signed:								; A = signed: "+3", "-2"
	bit 7,a
	push af
	ld a,'+'
	jr z,$+4
	ld a,'-'
	call .put_char
	pop af
	jp p,msg_add_u8
	neg
	jp msg_add_u8
.put_char:									; A = one character
	ld hl,(msg_ptr)
	ld (hl),a
	inc hl
	ld (msg_ptr),hl
	ret
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
	ld hl,PACK+I_KIND_HI
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

/* item_is_kind - IX = item, HL = kind -> Z if it is one */
item_is_kind:
	ld a,(ix+I_KIND)
	cp l
	ret nz
	ld a,(ix+I_KIND_HI)
	cp h
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
	call item_kind_addr
	ld (carry_kind),hl
	ld a,(iy+K_CLASS)
	cp IC_WAND
	jr nc,.new_slot						; only food, potions and scrolls stack
	call item_known
	sbc a,a
	ld (carry_known),a
	xor a
.stack:
	ld (carry_try),a
	call pack_slot
	ld hl,(carry_kind)
	call item_is_kind
	jr nz,.not_same
	call kind_addr
	call item_known
	sbc a,a
	ld hl,carry_known
	cp (hl)
	jr nz,.not_same
	ld hl,(carry_src)
	ld de,I_NUMBER
	add hl,de
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

/* pack_combine - HL = a kind just identified: its stacks in the pack join
	the first one (identify in DESC.C) */
pack_combine:
	ld (comb_kind),hl
	call kind_addr						; (wands and the like never merge)
	ld a,(iy+K_CLASS)
	cp IC_WAND
	ret nc
	xor a
	ld (comb_first),a
.find:
	call pack_slot
	ld hl,(comb_kind)
	call item_is_kind
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
	ld hl,(comb_kind)
	call item_is_kind
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

/* find_pack_kind - HL = kind -> A = the first pack slot holding it.
	Preserves HL */
find_pack_kind:
	xor a
.loop:
	ld (fk_slot),a
	call pack_slot
	call item_is_kind
	ld a,(fk_slot)
	ret z
	inc a
	cp PACK_MAX
	jr c,.loop
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
	ld hl,PACK+(PACK_MAX-1)*ITEM_SIZE+I_KIND_HI
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

; ---------------------------------------------------------------- lists

/* show_pack - list the pack on the screen, A = class filter (0 = all,
	IC_WEAPON = anything wearable). -> A = items listed */
show_pack:
	ld (list_filter),a
	xor a
	ld (list_shown),a
	ld (list_slot),a
.each:
	ld a,(list_slot)
	call pack_slot
	ld a,(ix+I_KIND_HI)
	cp ITEM_EMPTY
	jr z,.done
	call filter_ok
	jr nc,.next
	call msg_begin						; "a) a Ration of Food"
	ld a,(list_slot)
	add a,'a'
	call list_label
	call objdes_msg
	ld a,(list_shown)
	call list_line
	ld hl,list_shown
	inc (hl)
.next:
	ld hl,list_slot
	inc (hl)
	ld a,(hl)
	cp PACK_MAX
	jr c,.each
.done:
	ld a,(list_shown)
	ret

/* filter_ok - IX = item -> carry if it passes list_filter */
filter_ok:
	ld a,(list_filter)
	or a
	scf
	ret z
	ld b,a
	call item_kind_addr
	ld a,(iy+K_CLASS)
	ld c,a
	ld a,b
	cp IC_WEAPON
	jr z,.wearable
	cp FILTER_CHARGED
	jr z,.charged
	cp c
	scf
	ret z
	or a
	ret
.charged:								; wands and staffs (recharging)
	ld a,c
	cp IC_WAND
	scf
	ret z
	cp IC_STAFF
	scf
	ret z
	or a
	ret
.wearable:
	ld a,c
	cp IC_WEAPON
	ccf
	ret

/* list_label - A = letter: start a list line with "a) " */
list_label:
	ld (txt_label),a
	ld hl,txt_label
	jp msg_add

/* list_line - A = line number: print the built line in the list window */
list_line:
	ld hl,(msg_ptr)
	ld (hl),0
	add a,LIST_TOP
	ld d,a
	push de
	call clear_row
	pop de
	ld e,LIST_LEFT
	ld hl,msg_buf
	ld c,ATTR_WHITE
	jp print_at

/* prompt - HL = question for the message line */
prompt:
	push hl
	call msg_clear
	pop hl
	ld d,MSG_ROW
	ld e,0
	ld c,ATTR_YELLOW
	jp print_at

/* choose_pack - HL = question, A = class filter -> carry and A = slot,
	IX = item if a listed item was picked */
choose_pack:
	push hl
	call show_pack
	pop hl
	or a
	jr z,.none
	call prompt
	call read_ascii
	push af
	call msg_clear
	pop af
	sub 'a'
	cp PACK_MAX
	ret nc								; not a letter in range: cancel
	ld (list_slot),a
	call pack_slot
	ld a,(ix+I_KIND_HI)
	cp ITEM_EMPTY
	jr z,.cancel
	call filter_ok
	ret nc
	ld a,(list_slot)
	scf
	ret
.none:
	or a
	ret
.cancel:
	or a
	ret

/* pack_has_class - A = class -> carry if the pack has one
	(so an empty choice can be told apart from "you have none") */
pack_has_class:
	ld (list_filter),a
	ld ix,PACK
	ld b,PACK_MAX
.loop:
	ld a,(ix+I_KIND_HI)
	cp ITEM_EMPTY
	jr z,.next
	push bc
	call filter_ok
	pop bc
	ret c
.next:
	ld de,ITEM_SIZE
	add ix,de
	djnz .loop
	or a
	ret

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
txt_scroll_tilde: db "Scroll~ titled \"",0
txt_quote:		db "\"",0
txt_tried:		db "tried",0
txt_empty:		db "empty",0
txt_blessed:	db "blessed",0
txt_cursed:		db "cursed",0
txt_open_brace:	db " {",0
feel_words:		dw txt_average, txt_good, txt_excellent, txt_special
txt_average:	db "average",0
txt_good:		db "good",0
txt_excellent:	db "excellent",0
txt_special:	db "special",0
txt_brace:		db "}",0
txt_staff_:		db " Staff",0
txt_wand_:		db " Wand",0
txt_rod_:		db " Rod",0
txt_charges_:	db " charges)",0
txt_you_have_r:	db "You have ",0
txt_slot_r:		db " (a).",0
msg_combine:	db "You combine similar objects from the shop and dungeon.",0
carry_src:		dw 0
carry_known:	db 0
carry_kind:		dw 0
fk_slot:		db 0
carry_try:		db 0
od_unknown:		db 0
od_class:		db 0
od_bare:		db 0				; 1: no article ("The Dagger you are...")
od_note:		db 0
comb_kind:		dw 0
comb_first:		db 0
comb_try:		db 0
comb_dst:		dw 0
LIST_TOP			equ 1
LIST_LEFT			equ 2
txt_label:		db "a) ",0
list_filter:	db 0
list_shown:		db 0
list_slot:		db 0
