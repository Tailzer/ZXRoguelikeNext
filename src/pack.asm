/* pack.asm - item descriptions and the pack  [resident]
	Shared by the item commands (inventory.asm) and the stores (store.asm).
	References: MISC2.C objdes/inven_carry
 */

/* objdes_msg - add the description of item IX to the message being built:
	"a Dagger (1d4)", "2 Rations of Food", "Chain Mail [14]" */
objdes_msg:
	ld a,(ix+I_KIND)
	call kind_addr
	ld a,(ix+I_NUMBER)
	cp 1
	jr nz,.several
	call kind_name
	ld a,(iy+K_ARTICLE)					; "Chain Mail" has no article
	or a
	jr z,.no_article
	ld a,(hl)
	call is_vowel
	ld hl,txt_a_
	jr nz,$+5
	ld hl,txt_an_
	call msg_add
.no_article:
	ld b,0
	call .name
	jr .suffix
.several:
	call msg_add_u8
	ld hl,txt_space_
	call msg_add
	ld b,1
	call .name
.suffix:
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
.name:									; copy the name, '~' -> 's' if B=1
	push bc
	call kind_name
	pop bc
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
	ld iy,PACK
	ld b,PACK_MAX
	ld c,0
.stack:
	ld a,(iy+I_KIND)
	cp (ix+I_KIND)
	jr nz,.not_same
	ld a,(iy+I_NUMBER)
	add a,(ix+I_NUMBER)
	ld (iy+I_NUMBER),a
	ld a,c
	scf
	ret
.not_same:
	ld de,ITEM_SIZE
	add iy,de
	inc c
	djnz .stack
.new_slot:
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
carry_src:		dw 0
