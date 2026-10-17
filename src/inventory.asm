/* inventory.asm - the pack, equipment and item commands  [overlay: PAGE_ITEMS]
	References: MORIA2.C carry, MISC2.C inven_carry/objdes/calc_bonuses/
	attack_blows, POTIONS.C, EAT.C, MISC1.C add_food, SPELLS.C hp_player.
	The pack holds PACK_MAX records (a-l), kept packed together; food and
	potions of the same kind stack. Equipment has one slot per class:
	weapon, body armour, shield, helm, cloak, gloves, boots.
 */

/* starting_kit - empty pack and equipment, then a warrior's kit
	(player_init[] in PLAYER.C: ration, torch, Broadsword, Chain Mail and
	a Potion of Berserk Strength; there's no light or berserk potion yet,
	so the potion is Cure Light Wounds) */
starting_kit:
	ld hl,PACK
	ld b,PACK_MAX+EQ_SLOTS
	ld de,ITEM_SIZE
.clear:
	ld (hl),ITEM_EMPTY
	add hl,de
	djnz .clear
	ld ix,EQUIP+EQ_WEAPON*ITEM_SIZE
	ld a,KIND_BROADSWORD
	call .make
	ld ix,EQUIP+EQ_BODY*ITEM_SIZE
	ld a,KIND_CHAIN_MAIL
	call .make
	ld ix,PACK
	ld a,KIND_RATION
	call .make
	ld ix,PACK+ITEM_SIZE
	ld a,KIND_CLW
	call .make
	jp calc_bonuses
.make:
	ld (ix+I_KIND),a
	ld (ix+I_NUMBER),1
	ld (ix+I_MARKED),1
	ret

/* calc_bonuses - armour class, to-hit/dam and the weapon's numbers from
	what is worn and wielded, and blows from attack_blows() */
calc_bonuses:
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
	; attack_blows with STR 17, DEX 14: too heavy if weight > 17*15
	ld de,P_STR*15
	ex de,hl
	or a
	sbc hl,de							; 255 - weight
	jr nc,.can_lift
	ld a,(p_tohit)						; to-hit drops by the excess
	add a,l
	ld (p_tohit),a
	ld a,1
	ld (p_blows),a
	ret
.can_lift:
	ld a,(iy+K_WEIGHT)					; adj_weight = STR*10 / max(weight,50)
										; (weight < 256 here)
	cp 50
	jr nc,$+4
	ld a,50
	ld c,a
	ld hl,P_STR*10
	call div16_8
	ld a,l
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
	ld a,b
	ld hl,blows_by_str
	add hl,a
	ld a,(hl)
	ld (p_blows),a
	ret

/* the adj_weight thresholds for str_index 0-9 (anything more is 10), and
	blows_table[str_index][dex_index] for DEX 14 (dex_index 1) */
str_index_limits:	db 2,3,4,6,8,10,13,15,18,20
blows_by_str:		db 1,1,1,1,2,2,2,3,3,3,3

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
	ld (cmd_slot),a
	ld a,(ix+I_KIND)
	call kind_addr
	ld b,(iy+K_EFFECT)					; heal (effect)d7
	ld c,7
	call damroll
	call hp_player
	ld a,(cmd_slot)
	call use_one
	ld a,1
	ld (turn_taken),a
	ret

/* hp_player - HL = hit points healed, with the C's messages by amount */
hp_player:
	ld a,l
	ld (heal_amount),a
	push hl
	ld hl,(p_chp)
	ld de,(p_mhp)
	or a
	sbc hl,de
	pop hl
	ret nc								; already at full health
	ld de,(p_chp)
	add hl,de
	ld (p_chp),hl
	push hl
	ld de,(p_mhp)
	or a
	sbc hl,de
	pop hl
	jr c,.msg
	ld (p_chp),de
	ld hl,0
	ld (p_chp_frac),hl
.msg:
	ld a,(heal_amount)
	ld c,5
	call div8							; num / 5
	ld hl,msg_little_better
	or a
	jr z,.say
	ld hl,msg_better
	cp 3
	jr c,.say
	ld hl,msg_much_better
	cp 7
	jr c,.say
	ld hl,msg_very_good
.say:
	jp msg_print

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
	ld hl,(p_food)
	bit 7,h
	jr z,$+5
	ld hl,0
	ld e,(iy+K_P1)
	ld d,(iy+K_P1+1)
	add hl,de
	ld (p_food),hl
	ld de,FOOD_MAX+1
	or a
	sbc hl,de
	jr c,.not_bloated
	ld hl,FOOD_MAX						; (no slowness from overeating yet)
	ld (p_food),hl
	ld hl,msg_bloated
	call msg_print
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
txt_a_:			db "a ",0
txt_an_:		db "an ",0
txt_space_:		db " ",0
txt_open_sq:	db " [",0
txt_close_sq:	db "]",0
txt_open_br:	db " (",0
txt_d:			db "d",0
txt_close_br:	db ")",0
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
msg_little_better: db "You feel a little better.",0
msg_better:		db "You feel better.",0
msg_much_better: db "You feel much better.",0
msg_very_good:	db "You feel very good.",0
msg_full:		db "You are full.",0
msg_bloated:	db "You are bloated from overeating.",0

list_filter:	db 0
list_shown:		db 0
list_slot:		db 0
cmd_slot:		db 0
cmd_equip:		db 0
carry_src:		dw 0
drop_src:		dw 0
drop_dst:		dw 0
heal_amount:	db 0
num_tmp:		dw 0
