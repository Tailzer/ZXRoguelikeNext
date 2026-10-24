/* combine.asm - joining stacks (overlay page PAGE_RECALL, after recall.asm;
	moved out of pack.asm for resident room: learn_kind reaches it through
	recall_call). References: DESC.C identify */

/* pack_combine - DE = a kind just identified: its stacks in the pack join
	the first one (identify in DESC.C) */
pack_combine:
	ex de,hl							; (recall_call takes HL)
	ld (comb_kind),hl
	call kind_addr						; (wands and the like never merge)
	ld a,(iy+K_CLASS)
	call stackable
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

msg_combine:	db "You combine similar objects from the shop and dungeon.",0
comb_kind:		dw 0
comb_first:		db 0
comb_try:		db 0
comb_dst:		dw 0
