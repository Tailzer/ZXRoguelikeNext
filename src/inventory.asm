/* inventory.asm - the pack, equipment and item commands  [overlay: PAGE_ITEMS]
	References: MORIA2.C carry, MISC2.C inven_carry/objdes/calc_bonuses/
	attack_blows, EAT.C. Quaffing is chosen here and carried out by the
	magic overlay (potions.asm).
	The pack holds PACK_MAX records (a-l), kept packed together; food and
	potions of the same kind stack. Equipment has one slot per class:
	weapon, body armour, shield, helm, cloak, gloves, boots.
 */

/* starting_kit - empty pack and equipment, then the class's kit from
	player_init[] in PLAYER.C (p_kit; torches, books and potions the game
	can't use yet are left out) */
starting_kit:
	ld hl,PACK
	ld b,PACK_MAX+EQ_SLOTS
	ld de,ITEM_SIZE
.clear:
	ld (hl),ITEM_EMPTY
	add hl,de
	djnz .clear
	ld hl,p_kit							; wear what can be worn, carry the rest
	ld b,5
.kit:
	push bc
	push hl
	ld a,(hl)
	cp ITEM_EMPTY
	jr z,.next
	ld (kit_kind),a
	call kind_addr
	ld a,(iy+K_CLASS)
	sub IC_WEAPON
	jr c,.carry
	ld e,a								; equipment slot = class - IC_WEAPON
	ld d,ITEM_SIZE
	mul d,e
	ld ix,EQUIP
	add ix,de
	jr .put
.carry:
	call pack_count
	call pack_slot
.put:
	ld a,(kit_kind)
	call .make
.next:
	pop hl
	pop bc
	inc hl
	djnz .kit
	jp calc_bonuses
.make:
	ld (ix+I_KIND),a
	ld (ix+I_NUMBER),1
	ld (ix+I_MARKED),1
	ld (ix+I_IDENT),1<<ID_STORE_BIT		; (player_outfit: store_bought)
	ret

/* calc_bonuses - armour class, to-hit/dam and the weapon's numbers from
	what is worn and wielded, and blows from attack_blows() */
calc_bonuses:
	call stat_bonuses
	xor a
	ld (p_ac),a
	ld (p_tohit),a
	ld (p_todam),a
	ld ix,EQUIP
	ld b,EQ_SLOTS
.slot:
	push bc
	ld a,(ix+I_KIND)
	cp ITEM_EMPTY
	jr z,.next
	call kind_addr
	ld a,(p_ac)
	add a,(iy+K_AC)
	ld (p_ac),a
	ld a,(p_tohit)
	add a,(iy+K_TOHIT)
	ld (p_tohit),a
	ld a,(p_todam)
	add a,(iy+K_TODAM)
	ld (p_todam),a
.next:
	ld de,ITEM_SIZE
	add ix,de
	pop bc
	djnz .slot
	ld hl,p_stat_tohit					; plus what the stats give
	ld a,(p_tohit)
	add a,(hl)
	ld (p_tohit),a
	ld a,(p_stat_todam)
	ld hl,p_todam
	add a,(hl)
	ld (hl),a
	; temporary effects (MORIA1.C: stun, then the spell increases)
	ld b,0								; B = to-hit, C = to-ac changes
	ld c,b
	ld hl,(p_stun)
	bit 7,h
	jr nz,.unstunned
	ld a,h
	or l
	jr z,.unstunned
	ld de,51
	sbc hl,de							; (carry clear from the or)
	ld a,-5
	jr c,$+4
	ld a,-20
	ld b,a
	ld hl,p_todam
	add a,(hl)
	ld (hl),a
.unstunned:
	ld a,(p_status+1)
	bit PY2_BLESSED,a
	jr z,.unblessed
	ld a,b
	add a,10
	ld b,a
	ld a,c
	add a,5
	ld c,a
.unblessed:
	ld a,(p_status)
	bit PY_HERO,a
	jr z,.unheroic
	ld a,b
	add a,12
	ld b,a
.unheroic:
	ld a,(p_status)
	bit PY_SHERO,a
	jr z,.calm
	ld a,b
	add a,24
	ld b,a
	ld a,c
	sub 10
	ld c,a
.calm:
	ld hl,p_tohit
	ld a,(hl)
	add a,b
	ld (hl),a
	ld a,(p_stat_toac)
	add a,c
	ld hl,p_ac
	add a,(hl)
	jp p,$+4
	xor a								; (armour class can't go below 0)
	ld (hl),a
	ld a,(EQUIP+EQ_WEAPON*ITEM_SIZE+I_KIND)
	cp ITEM_EMPTY
	jr nz,.armed
	ld a,1								; bare hands: 2 blows of 1d1 at -3
	ld (w_dice),a
	ld (w_sides),a
	ld a,2
	ld (p_blows),a
	ld hl,0
	ld (w_weight),hl
	ld a,(p_tohit)
	sub 3
	ld (p_tohit),a
	ret
.armed:
	call kind_addr
	ld a,(iy+K_DICE)
	ld (w_dice),a
	ld a,(iy+K_SIDES)
	ld (w_sides),a
	ld l,(iy+K_WEIGHT)
	ld h,(iy+K_WEIGHT+1)
	ld (w_weight),hl
	; attack_blows: too heavy if weight > STR*15 (to-hit drops by the excess)
	ld a,(p_stat+A_STR)
	ld e,a
	ld d,15
	mul d,e
	ex de,hl							; HL = STR*15, DE = weight
	or a
	sbc hl,de
	jr nc,.can_lift
	ld a,(p_tohit)
	add a,l
	ld (p_tohit),a
	ld a,1
	ld (p_blows),a
	ret
.can_lift:
	ld de,(w_weight)					; adj_weight = STR*10 / max(weight,50)
	ld hl,49
	or a
	sbc hl,de
	jr c,$+5							; 50 or more: the weight itself
	ld de,50							; DE = divisor
	ld a,(p_stat+A_STR)
	ld l,a
	ld h,0
	ld b,h
	ld c,l
	add hl,hl
	add hl,hl
	add hl,bc
	add hl,hl							; HL = STR*10
	ld b,0
.divide:
	or a
	sbc hl,de
	jr c,.quotient
	inc b
	jr .divide
.quotient:
	ld a,b
	ld hl,str_index_limits
	ld b,0
.find:									; str_index: first limit above it
	cp (hl)
	jr c,.found
	inc hl
	inc b
	ld c,a
	ld a,b
	cp 10
	ld a,c
	jr nz,.find
.found:
	ld e,b								; blows_table[str_index][dex_index]
	ld d,12
	mul d,e
	ld a,(p_dex_index)
	add de,a
	ld hl,blows_table
	add hl,de
	ld a,(hl)
	ld (p_blows),a
	ret

/* the adj_weight thresholds for str_index 0-9 (anything more is 10) */
str_index_limits:	db 2,3,4,6,8,10,13,15,18,20
kit_kind:			db 0

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
	ld a,(ix+I_KIND)
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
	ld a,(ix+I_KIND)
	call kind_addr
	ld a,(iy+K_CLASS)
	ld c,a
	ld a,b
	cp IC_WEAPON
	jr z,.wearable
	cp c
	scf
	ret z
	or a
	ret
.wearable:
	ld a,c
	cp IC_WEAPON
	ccf
	ret

/* show_equip - list the four equipment slots */
show_equip:
	xor a
	ld (list_slot),a
.each:
	call msg_begin						; "a) Wielding : a Broadsword (2d5)"
	ld a,(list_slot)
	add a,'a'
	call list_label
	ld a,(list_slot)
	add a,a
	ld hl,equip_names
	add hl,a
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	call msg_add
	ld a,(list_slot)
	ld e,a
	ld d,ITEM_SIZE
	mul d,e
	ld ix,EQUIP
	add ix,de
	ld a,(ix+I_KIND)
	cp ITEM_EMPTY
	ld hl,txt_nothing
	jr z,.empty
	call objdes_msg
	jr .shown
.empty:
	call msg_add
.shown:
	ld a,(list_slot)
	call list_line
	ld hl,list_slot
	inc (hl)
	ld a,(hl)
	cp EQ_SLOTS
	jr c,.each
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
	ld a,(ix+I_KIND)
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

; ---------------------------------------------------------------- commands

/* cmd_inventory - 'i' */
cmd_inventory:
	xor a
	call show_pack
	or a
	ld hl,msg_pack_empty
	jp z,msg_print
	ld hl,txt_any_key
	call prompt
	call read_ascii
	jp msg_clear

/* cmd_equipment - 'e' */
cmd_equipment:
	call show_equip
	ld hl,txt_any_key
	call prompt
	call read_ascii
	jp msg_clear

/* cmd_wield - 'w': wear or wield from the pack, swapping out what was
	there before (it goes back into the same pack slot) */
cmd_wield:
	ld hl,txt_wear_which
	ld a,IC_WEAPON
	call choose_pack
	ret nc
	ld (cmd_slot),a
	ld a,(ix+I_KIND)
	call kind_addr
	ld a,(iy+K_CLASS)
	sub IC_WEAPON
	ld (cmd_equip),a
	ld e,a
	ld d,ITEM_SIZE
	mul d,e
	ld hl,EQUIP
	add hl,de							; HL = equipment slot
	push ix
	pop de								; DE = pack slot
	ld b,ITEM_SIZE
.swap:
	ld a,(de)
	ld c,(hl)
	ld (hl),a
	ld a,c
	ld (de),a
	inc hl
	inc de
	djnz .swap
	ld a,(ix+I_KIND)					; nothing was worn: close the gap
	cp ITEM_EMPTY
	ld a,(cmd_slot)
	call z,pack_remove
	call calc_bonuses
	ld a,1
	ld (turn_taken),a
	call msg_begin						; "You are wielding a Dagger (1d4)."
	ld a,(cmd_equip)
	or a
	ld hl,txt_you_wield
	jr z,$+5
	ld hl,txt_you_wear
	call msg_add
	ld a,(cmd_equip)
	ld e,a
	ld d,ITEM_SIZE
	mul d,e
	ld ix,EQUIP
	add ix,de
	call objdes_msg
	ld hl,txt_full_stop
	call msg_add
	jp msg_end

/* cmd_takeoff - 't': take something off and put it in the pack */
cmd_takeoff:
	call show_equip
	ld hl,txt_takeoff_which
	call prompt
	call read_ascii
	push af
	call msg_clear
	pop af
	sub 'a'
	cp EQ_SLOTS
	ret nc
	ld (cmd_equip),a
	ld e,a
	ld d,ITEM_SIZE
	mul d,e
	ld ix,EQUIP
	add ix,de
	ld a,(ix+I_KIND)
	cp ITEM_EMPTY
	ret z
	call pack_carry
	jr c,.carried
	ld hl,msg_no_room
	jp msg_print
.carried:
	ld (cmd_slot),a
	call msg_begin						; "You were wearing Chain Mail [14]."
	ld a,(cmd_equip)
	or a
	ld hl,txt_were_wielding
	jr z,$+5
	ld hl,txt_were_wearing
	call msg_add
	call objdes_msg
	ld hl,txt_full_stop
	call msg_add
	call msg_end
	ld (ix+I_KIND),ITEM_EMPTY
	call calc_bonuses
	ld a,1
	ld (turn_taken),a
	ret

/* cmd_quaff - 'q': drink a potion (POTIONS.C cases 13 and 14) */
cmd_quaff:
	ld hl,txt_quaff_which
	ld a,IC_POTION
	call choose_pack
	jr c,.drink
	ld a,IC_POTION
	call pack_has_class
	ret c								; had some, but chose none
	ld hl,msg_no_potions
	jp msg_print
.drink:
	ld (pending_arg),a					; POTIONS.C's effects are in the
	ld a,PM_QUAFF						; magic overlay
	ld (pending_magic),a
	ld a,1
	ld (turn_taken),a
	ret

/* cmd_eat - 'E': eat some food (EAT.C, add_food in MISC1.C) */
cmd_eat:
	ld hl,txt_eat_which
	ld a,IC_FOOD
	call choose_pack
	jr c,.eat
	ld a,IC_FOOD
	call pack_has_class
	ret c
	ld hl,msg_no_food
	jp msg_print
.eat:
	ld (cmd_slot),a
	ld a,(ix+I_KIND)
	call kind_addr
	ld l,(iy+K_P1)
	ld h,(iy+K_P1+1)
	call add_food
	ld a,(cmd_slot)
	call desc_remain
	ld a,(cmd_slot)
	call use_one
	ld a,1
	ld (turn_taken),a
	ret

/* pack_has_class - A = class -> carry if the pack has one
	(so an empty choice can be told apart from "you have none") */
pack_has_class:
	ld (list_filter),a
	ld ix,PACK
	ld b,PACK_MAX
.loop:
	ld a,(ix+I_KIND)
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

/* cmd_drop - 'd': put one of something on the floor (one item per square) */
cmd_drop:
	ld hl,txt_drop_which
	xor a
	call choose_pack
	ret nc
	ld (cmd_slot),a
	ld (drop_src),ix
	ld a,(player_y)
	ld d,a
	ld a,(player_x)
	ld e,a
	call item_at
	ld hl,msg_already_item
	jp c,msg_print
	call item_free_slot
	ld hl,msg_floor_full
	jp nc,msg_print
	ld (drop_dst),ix
	push ix
	pop de
	ld hl,(drop_src)
	ld bc,ITEM_SIZE
	ldir								; copy the record to the floor
	ld ix,(drop_dst)
	ld (ix+I_NUMBER),1
	ld (ix+I_MARKED),1
	ld a,(player_y)
	ld (ix+I_Y),a
	ld a,(player_x)
	ld (ix+I_X),a
	call msg_begin						; "You drop a Dagger (1d4)."
	ld hl,txt_you_drop
	call msg_add
	call objdes_msg
	ld hl,txt_full_stop
	call msg_add
	call msg_end
	ld a,(cmd_slot)
	call use_one
	ld a,1
	ld (turn_taken),a
	ret

/* cmd_pickup - 'g' */
cmd_pickup:
	ld a,(player_y)
	ld d,a
	ld a,(player_x)
	ld e,a
	call item_at
	jr c,carry_here
	ld hl,msg_nothing_here
	jp msg_print

/* carry_here - pick up whatever the player is standing on (carry in
	MORIA2.C): treasure goes in the purse, anything else into the pack */
carry_here:
	ld a,(player_y)
	ld d,a
	ld a,(player_x)
	ld e,a
	call item_at
	ret nc
	ld a,(ix+I_KIND)
	cp KIND_GOLD
	jr nz,.object
	ld l,(ix+I_VALUE)					; "You have found 31 gold pieces
	ld h,(ix+I_VALUE+1)					;  worth of copper."
	ld de,(p_gold)
	add hl,de
	ld (p_gold),hl
	ld hl,(p_gold+2)
	ld de,0
	adc hl,de
	ld (p_gold+2),hl
	call msg_begin
	ld hl,txt_found
	call msg_add
	ld e,(ix+I_VALUE)
	ld d,(ix+I_VALUE+1)
	ld (num_tmp),de
	ld hl,num_tmp
	call msg_add_u16
	ld hl,txt_gold_worth
	call msg_add
	ld a,(ix+I_SUB)
	call gold_addr
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	call msg_add
	ld hl,txt_full_stop
	call msg_add
	call msg_end
	ld (ix+I_KIND),ITEM_EMPTY
	ret
.object:
	call pack_carry
	jr c,.carried
	call msg_begin						; "You have no room for a Mace (2d4)."
	ld hl,txt_no_room_for
	call msg_add
	call objdes_msg
	ld hl,txt_full_stop
	call msg_add
	jp msg_end
.carried:
	ld (cmd_slot),a
	ld (ix+I_KIND),ITEM_EMPTY			; off the floor
	call pack_slot						; "You have a Dagger (1d4) (c)."
	call msg_begin
	ld hl,txt_you_have
	call msg_add
	call objdes_msg
	ld a,(cmd_slot)
	add a,'a'
	ld (txt_slot_letter+2),a
	ld hl,txt_slot_letter
	call msg_add
	jp msg_end

/* msg_add_u16 - HL -> 16-bit value: add it as a decimal number */
msg_add_u16:
	push ix
	call .add
	pop ix
	ret
.add:
	ld e,(hl)
	inc hl
	ld d,(hl)
	ex de,hl
	ld de,(msg_ptr)
	ld ix,pow10_table
	ld b,0								; set once a digit is written
.digit:
	ld c,(ix+0)
	ld a,c
	or (ix+1)
	jr z,.last
	push bc
	ld b,(ix+1)
	ld a,'0'
.sub:
	or a
	sbc hl,bc
	jr c,.got
	inc a
	jr .sub
.got:
	add hl,bc
	pop bc
	cp '0'
	jr nz,.write
	bit 0,b
	jr z,.skip
.write:
	ld (de),a
	inc de
	ld b,1
.skip:
	inc ix
	inc ix
	jr .digit
.last:
	ld a,l
	add a,'0'
	ld (de),a
	inc de
	ld (msg_ptr),de
	ret

LIST_TOP			equ 1
LIST_LEFT			equ 2

equip_names:	dw txt_eq_weapon, txt_eq_body, txt_eq_shield, txt_eq_helm
				dw txt_eq_cloak, txt_eq_gloves, txt_eq_boots
txt_eq_weapon:	db "Wielding    : ",0
txt_eq_body:	db "On body     : ",0
txt_eq_shield:	db "On arm      : ",0
txt_eq_helm:	db "On head     : ",0
txt_eq_cloak:	db "About body  : ",0
txt_eq_gloves:	db "On hands    : ",0
txt_eq_boots:	db "On feet     : ",0
txt_nothing:	db "(nothing)",0
txt_label:		db "a) ",0
txt_any_key:	db "-- press a key --",0
txt_wear_which:	db "Wear or wield which item? (letter, or space)",0
txt_takeoff_which: db "Take off which item? (letter, or space)",0
txt_quaff_which: db "Quaff which potion? (letter, or space)",0
txt_eat_which:	db "Eat what? (letter, or space)",0
txt_drop_which:	db "Drop which item? (letter, or space)",0
txt_you_wield:	db "You are wielding ",0
txt_you_wear:	db "You are wearing ",0
txt_were_wielding: db "You were wielding ",0
txt_were_wearing: db "You were wearing ",0
txt_you_drop:	db "You drop ",0
txt_you_have:	db "You have ",0
txt_slot_letter: db " (a).",0
txt_no_room_for: db "You have no room for ",0
txt_found:		db "You have found ",0
txt_gold_worth:	db " gold pieces worth of ",0
msg_pack_empty:	db "You are not carrying anything.",0
msg_no_potions:	db "You are not carrying any potions.",0
msg_no_food:	db "You are not carrying any food.",0
msg_no_room:	db "You have no room in your pack.",0
msg_already_item: db "There is already something here.",0
msg_nothing_here: db "There is nothing here to pick up.",0
msg_floor_full:	db "There is no room on the floor.",0

list_filter:	db 0
list_shown:		db 0
list_slot:		db 0
cmd_slot:		db 0
cmd_equip:		db 0
drop_src:		dw 0
drop_dst:		dw 0
num_tmp:		dw 0
