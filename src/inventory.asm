/* inventory.asm - the pack, equipment and item commands  [overlay: PAGE_ITEMS]
	References: MORIA2.C carry, MISC2.C inven_carry/objdes/calc_bonuses/
	attack_blows, EAT.C. Quaffing is chosen here and carried out by the
	magic overlay (potions.asm).
	The pack holds PACK_MAX records (a-l), kept packed together; food and
	potions of the same kind stack. Equipment has one slot per class:
	weapon, body armour, shield, helm, cloak, gloves, boots, amulet; and
	two for rings, right hand first.
 */

/* starting_kit - empty pack and equipment, then the class's kit from
	player_init[] in PLAYER.C (p_kit; torches, books and potions the game
	can't use yet are left out) */
starting_kit:
	ld hl,PACK+I_KIND_HI
	ld b,PACK_MAX+EQ_MAX
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
	ld e,(hl)
	inc hl
	ld d,(hl)
	ld a,d
	cp ITEM_EMPTY
	jr z,.next
	ex de,hl
	ld (kit_kind),hl
	call kind_addr
	ld a,(iy+K_CLASS)
	cp IC_MAGIC_BOOK					; (books are carried)
	jr nc,.carry
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
	call .make
.next:
	pop hl
	pop bc
	inc hl
	inc hl
	djnz .kit
	jp calc_bonuses
.make:
	ld hl,(kit_kind)
	OVCALL PAGE_MISC, new_plain, PAGE_ITEMS
	ld (ix+I_ATIME),0
	ld (ix+I_ATIME+1),0
	ld (ix+I_MARKED),1
	ld (ix+I_IDENT),1<<ID_STORE_BIT|1<<ID_KNOWN2_BIT	; (store_bought)
	ld a,(iy+K_CLASS)					; torches come five to a bundle
	cp IC_LIGHT
	ret nz
	ld (ix+I_NUMBER),5
	ret

/* calc_bonuses - what everything worn does (py_bonuses and calc_bonuses
	in MORIA1.C): its flags, stat and speed bonuses and sustains, then
	armour class, to-hit/dam and the weapon's numbers, and blows from
	attack_blows() */
calc_bonuses:
	ld hl,p_update						; (spells and mana follow: gloves,
	set PU_SPELLS,(hl)					;  armour, the spell stat)
	call equip_flags
	call stat_bonuses
	xor a
	ld (p_ac),a
	ld (p_tohit),a
	ld (p_todam),a
	ld ix,EQUIP
	ld b,EQ_SLOTS
.slot:
	push bc
	ld a,(ix+I_KIND_HI)
	cp ITEM_EMPTY
	jr z,.next
	call item_kind_addr
	bit ID_CURSED_BIT,(ix+I_IDENT)		; cursed: no base armour class
	jr nz,.pluses
	ld a,(p_ac)
	add a,(iy+K_AC)
	ld (p_ac),a
.pluses:								; and its own pluses
	ld a,(p_ac)
	add a,(ix+I_TOAC)
	ld (p_ac),a
	ld a,(p_tohit)
	add a,(ix+I_TOHIT)
	ld (p_tohit),a
	ld a,(iy+K_CLASS)					; bows can't damage
	cp IC_BOW
	jr z,.next
	ld a,(p_todam)
	add a,(ix+I_TODAM)
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
	ld a,(p_status+1)					; a mystic shield: +50; invulnerable:
	ld b,50								; +100 (at most 255)
	bit PY2_SHIELD,a
	call nz,.more_ac
	ld a,(p_status+1)
	ld b,100
	bit PY2_INVULN,a
	call nz,.more_ac
	ld a,(EQUIP+EQ_WEAPON*ITEM_SIZE+I_KIND_HI)
	cp ITEM_EMPTY
	jr nz,.armed
	ld a,1								; bare hands: 2 blows of 1d1 at -3
	ld (w_dice),a
	ld (w_sides),a
	ld a,2
	ld (p_blows),a
	ld hl,0
	ld (w_weight),hl
	ld (w_slays),hl
	ld a,(p_tohit)
	sub 3
	ld (p_tohit),a
	ret
.armed:
	ld ix,EQUIP+EQ_WEAPON*ITEM_SIZE
	call item_flags						; its slays and brands
	ld hl,slay_flags
	ld de,0
	ld b,NUM_SLAYS
.slays:
	ld a,(hl)							; (byte of it_flags, bit)
	push hl
	ld hl,it_flags
	add hl,a
	ld c,(hl)
	pop hl
	inc hl
	ld a,(hl)
	inc hl
	and c
	scf
	jr nz,$+3
	or a
	rr d
	rr e
	djnz .slays
	ld b,16-NUM_SLAYS
.align:
	srl d
	rr e
	djnz .align
	ld (w_slays),de
	call item_dice
	ld (w_dice),a
	ld a,b
	ld (w_sides),a
	ld l,(iy+K_WEIGHT)
	ld h,(iy+K_WEIGHT+1)
	ld a,(ix+I_NAME2)					; a weapon of Morgul weighs 10 lb
	cp SN_MORGUL						; more; an artifact may weigh what
	jr nz,.artifact						; it likes
	ld de,100
	add hl,de
	jr .weight
.artifact:
	or a
	jr z,.weight
	push hl
	call ego_addr
	ld e,(iy+E_WEIGHT)
	ld d,(iy+E_WEIGHT+1)
	pop hl
	ld a,d
	or e
	jr z,.weight
	ex de,hl
.weight:
	ld (w_weight),hl
	; attack_blows: too heavy if weight > STR*15 (to-hit drops by the excess)
	ld a,(p_stat_use+A_STR)
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
	ld a,(p_stat_use+A_STR)
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
	ld ix,EQUIP+EQ_WEAPON*ITEM_SIZE		; arrows in hand: one blow
	call item_kind_addr
	ld a,(iy+K_CLASS)
	cp IC_AMMO
	ret nz
	ld a,1
	ld (p_blows),a
	ret

.more_ac:
	ld a,(p_ac)
	add a,b
	jr nc,$+4
	ld a,255
	ld (p_ac),a
	ret

/* equip_flags - p_eflags (the race's gifts and the flags of everything
	worn), p_sustain, the stat bonuses (p_stat_mod) and speed (p_eq_speed,
	with every monster's speed changed to match) */
equip_flags:
	ld hl,p_eflags						; (p_eflags, p_sustain, p_stat_mod,
	ld b,4+1+6+4						;  p_eflags2)
	xor a
.clear:
	ld (hl),a
	inc hl
	djnz .clear
	ld (ef_speed),a
	ld (ef_stealth),a
	ld (ef_infra),a
	ld (ef_search),a
	ld a,(p_race)						; race intrinsics
	ld hl,race_gifts
.race:
	cp (hl)
	inc hl
	jr z,.gift
	inc hl
	inc hl
	inc hl
	inc hl
	inc hl
	bit 7,(hl)
	jr z,.race
	jr .worn
.gift:
	ld de,p_eflags
	ld b,5
.or:
	ld a,(de)
	or (hl)
	ld (de),a
	inc hl
	inc de
	djnz .or
.worn:
	ld ix,EQUIP
	ld b,EQ_SLOTS
.slot:
	push bc
	ld a,(ix+I_KIND_HI)
	cp ITEM_EMPTY
	jr z,.next
	call item_flags						; its flags, and its ego's (cursed
	ld hl,it_flags						; or not)
	ld de,p_eflags
	ld b,4
	call .or_flags
	ld de,p_eflags2
	ld b,4
	call .or_flags
	ld a,(it_flags)						; its number to each stat it names
	and $3F
	ld c,a
	ld hl,p_stat_mod
	ld b,6
.stat:
	rr c
	jr nc,.stat_next
	ld a,(ix+I_PVAL)
	add a,(hl)
	ld (hl),a
.stat_next:
	inc hl
	djnz .stat
	ld a,(it_flags+1)					; and to speed and stealth
	ld hl,ef_speed
	bit EF1_SPEED,a
	call nz,.add_p1
	ld hl,ef_stealth
	bit EF1_STEALTH,a
	call nz,.add_p1
	ld a,(it_flags)						; and searching
	ld hl,ef_search
	bit EF0_SEARCH,a
	call nz,.add_p1
	ld a,(it_flags+3)					; and infravision
	ld hl,ef_infra
	bit EF3_INFRA,a
	call nz,.add_p1
	ld a,(it_flags+2)					; a sustain: its number is the stat
	bit EF2_SUST_STAT,a					; (1 STR, 2 INT, 3 WIS, 4 CON, 5 DEX,
	jr z,.next							;  6 CHR, 10 all)
	ld a,(ix+I_PVAL)
	cp 10
	jr nz,.one
	ld a,$3F
	jr .sustained
.one:
	dec a
	cp 6
	jr nc,.next
	ld hl,sustain_bits
	add hl,a
	ld a,(hl)
.sustained:
	ld hl,p_sustain
	or (hl)
	ld (hl),a
.next:
	ld de,ITEM_SIZE
	add ix,de
	pop bc
	dec b
	jp nz,.slot
	ld de,KIND_RING_SPEED				; two Rings of Speed (+1 on the right)
	ld hl,(EQUIP+EQ_RIGHT*ITEM_SIZE+I_KIND)	; only count once (py_bonuses)
	or a
	sbc hl,de
	jr nz,.speed
	ld hl,(EQUIP+EQ_LEFT*ITEM_SIZE+I_KIND)
	or a
	sbc hl,de
	jr nz,.speed
	ld a,(EQUIP+EQ_RIGHT*ITEM_SIZE+I_PVAL)
	dec a
	jr nz,.speed
	ld hl,ef_speed
	dec (hl)
.speed:
	ld a,(ef_search)					; searching: skill up, and more often
	ld b,a
	ld a,(p_srh_race)
	add a,b
	ld (p_srh),a
	ld a,(p_fos_race)
	sub b
	ld (p_fos),a
	ld a,(ef_stealth)					; stealth and infravision: the
	ld hl,p_stl_race					; race's and class's, plus
	add a,(hl)
	ld (p_stl),a
	add a,4								; monsters' noticing roll
	bit 7,a
	jr z,$+3
	xor a
	cp 25
	jr c,$+4
	ld a,24
	add a,a
	ld hl,notice_table
	add hl,a
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	ld (p_notice),hl
	ld a,(ef_infra)
	ld hl,p_infra_race
	add a,(hl)
	ld (p_infra),a
	ld a,(p_eq_speed)					; speed changes by the difference
	ld b,a
	ld a,(ef_speed)
	ld (p_eq_speed),a
	sub b
	ret z
	neg									; (faster is lower)
	jp change_speed
.or_flags:								; B bytes from HL ORed into DE
	ld a,(de)
	or (hl)
	ld (de),a
	inc hl
	inc de
	djnz .or_flags
	ret
.add_p1:								; (HL) += its number. Keeps A
	push af
	ld a,(ix+I_PVAL)
	add a,(hl)
	ld (hl),a
	pop af
	ret

; the weapon's flags in slay_table order: (byte of it_flags, bit)
slay_flags:
	db 5,1<<F2_LIGHTNING, 3,1<<EF3_SLAY_X_DRAGON, 1,1<<EF1_SLAY_DRAGON
	db 2,1<<EF2_SLAY_UNDEAD, 4,1<<F2_SLAY_ORC, 4,1<<F2_SLAY_TROLL
	db 4,1<<F2_SLAY_GIANT, 4,1<<F2_SLAY_DEMON, 2,1<<EF2_FROST_BRAND
	db 2,1<<EF2_FLAME_TONGUE, 1,1<<EF1_SLAY_EVIL, 1,1<<EF1_SLAY_ANIMAL

; race, then its gifts as p_eflags (4 bytes) and p_sustain
race_gifts:
	db RACE_HIGH_ELF, 0,0,0,1<<EF3_SEE_INVIS|1<<EF3_FFALL, 0
	db RACE_GNOME, 0,0,1<<EF2_FREE_ACT,0, 0
	db RACE_HOBBIT, 0,0,0,0, 1<<A_DEX
	db RACE_HALF_TROLL, 0,0,0,0, 1<<A_STR
	db RACE_DUNADAN, 0,0,0,0, 1<<A_CON
	db $FF
; the C's sustain numbers 1-6 as p_sustain bits
sustain_bits:	db 1<<A_STR, 1<<A_INT, 1<<A_WIS, 1<<A_CON, 1<<A_DEX, 1<<A_CHR
ef_speed:		db 0
ef_stealth:		db 0
ef_infra:		db 0
ef_search:		db 0

/* the adj_weight thresholds for str_index 0-9 (anything more is 10) */
str_index_limits:	db 2,3,4,6,8,10,13,15,18,20
kit_kind:			dw 0

; ---------------------------------------------------------------- lists

/* show_equip - list the equipment slots */
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
	ld a,(ix+I_KIND_HI)
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
	call item_kind_addr
	ld a,(iy+K_CLASS)
	cp IC_BOW							; bows and arrows are wielded
	jr nc,.wielded
	cp IC_LIGHT							; lights go in the light slot
	jr z,.light
	cp IC_LANTERN
	jr z,.light
	cp IC_RING
	call z,ring_hand					; (A = the slot)
	ret nc
	jr .slot
.wielded:
	ld a,IC_WEAPON
	jr .slot
.light:
	ld a,IC_WEAPON+EQ_LIGHT
.slot:
	sub IC_WEAPON
	ld (cmd_equip),a
	ld e,a
	ld d,ITEM_SIZE
	mul d,e
	ld hl,EQUIP
	add hl,de							; HL = equipment slot
	push hl								; what's there now can't come off
	inc hl								; if it's cursed
	ld a,(hl)							; (I_KIND_HI)
	ld de,I_IDENT-I_KIND_HI
	add hl,de
	cp ITEM_EMPTY
	jr z,.free
	bit ID_CURSED_BIT,(hl)
.free:
	pop hl
	jp nz,stuck_on
	ld a,(iy+K_CLASS)					; (arrows: the whole stack)
	cp IC_AMMO
	jr z,.whole
	ld a,(ix+I_NUMBER)					; one from a stack (torches)
	cp 2
	jr nc,.one_of
.whole:
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
	ld a,(ix+I_KIND_HI)					; nothing was worn: close the gap
	cp ITEM_EMPTY
	ld a,(cmd_slot)
	call z,pack_remove
.worn:
	call calc_bonuses
	ld a,1
	ld (turn_taken),a
	call msg_begin						; "You are wielding a Dagger (1d4)."
	ld a,(cmd_equip)
	or a
	ld hl,txt_you_wield
	jr z,.said
	cp EQ_LIGHT
	ld hl,txt_light_is
	jr z,.said
	ld hl,txt_you_wear
.said:
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
	call msg_end
	bit ID_CURSED_BIT,(ix+I_IDENT)		; a curse makes itself known
	ret z
	set ID_DAMD_BIT,(ix+I_IDENT)
	ld hl,msg_deathly_cold
	jp msg_print
.one_of:								; HL = the slot, IX = the stack: one
	ld (wd_slot),hl						; of it goes on, what was there into
	inc hl								; the pack (which needs room)
	ld a,(hl)
	cp ITEM_EMPTY
	jr z,.room
	call pack_count
	cp PACK_MAX
	ld hl,msg_drop_first
	jp nc,msg_print
.room:
	push ix
	pop hl
	ld de,new_rec
	ld bc,ITEM_SIZE
	ldir
	ld a,1
	ld (new_rec+I_NUMBER),a
	dec (ix+I_NUMBER)
	ld ix,(wd_slot)
	ld a,(ix+I_KIND_HI)
	cp ITEM_EMPTY
	call nz,pack_carry
	ld hl,new_rec
	ld de,(wd_slot)
	ld bc,ITEM_SIZE
	ldir
	jp .worn

/* ring_hand - a ring goes on the right hand if it's free, else the left;
	with both full, ask which (MORIA1.C). -> A = IC_WEAPON + the slot, carry;
	no carry if no hand was chosen. Keeps IX */
ring_hand:
	ld a,(EQUIP+EQ_RIGHT*ITEM_SIZE+I_KIND_HI)
	cp ITEM_EMPTY
	ld a,IC_WEAPON+EQ_RIGHT
	scf
	ret z
	ld a,(EQUIP+EQ_LEFT*ITEM_SIZE+I_KIND_HI)
	cp ITEM_EMPTY
	ld a,IC_WEAPON+EQ_LEFT
	scf
	ret z
	push ix
	ld hl,txt_which_hand
	call prompt
	call read_ascii
	push af
	call msg_clear
	pop af
	pop ix
	or $20								; (L and R as l and r)
	ld b,a
	cp 'l'
	ld a,IC_WEAPON+EQ_LEFT
	scf
	ret z
	ld a,b
	cp 'r'
	ld a,IC_WEAPON+EQ_RIGHT
	scf
	ret z
	or a								; anything else: never mind
	ret

/* stuck_on - HL = a cursed piece of equipment in the way: "The Dagger
	(1d4) you are wielding appears to be cursed." and nothing happens */
stuck_on:
	push hl
	pop ix
	call msg_begin
	ld hl,txt_the
	call msg_add
	ld a,1
	ld (od_bare),a
	call objdes_msg
	xor a
	ld (od_bare),a
	ld a,(cmd_equip)
	or a
	ld hl,txt_wielding_cursed
	jr z,$+5
	ld hl,txt_wearing_cursed
	call msg_add
	jp msg_end

/* cmd_fuel - 'F': fill the lamp from a flask of oil (refill_lamp in
	DUNGEON.C) */
cmd_fuel:
	ld ix,EQUIP+EQ_LIGHT*ITEM_SIZE
	ld a,(ix+I_KIND_HI)
	cp ITEM_EMPTY
	jr z,.no_lamp
	call item_kind_addr
	ld a,(iy+K_CLASS)
	cp IC_LANTERN
	jr nz,.no_lamp
	bit 1,(iy+K_FLAGS2+3)				; (artifacts aren't lamps)
	jr z,.lamp
.no_lamp:
	ld hl,msg_not_lamp
	jp msg_print
.lamp:
	xor a
.find:
	ld (cmd_slot),a
	cp PACK_MAX
	jr nc,.no_oil
	call pack_slot
	ld a,(ix+I_KIND_HI)
	cp ITEM_EMPTY
	jr z,.no_oil
	call item_kind_addr
	ld a,(iy+K_CLASS)
	cp IC_FLASK
	jr z,.oil
	ld a,(cmd_slot)
	inc a
	jr .find
.no_oil:
	ld hl,msg_no_oil
	jp msg_print
.oil:
	ld a,1
	ld (turn_taken),a
	ld e,(ix+I_PVAL)
	ld d,(ix+I_PVAL+1)
	ld hl,(EQUIP+EQ_LIGHT*ITEM_SIZE+I_PVAL)
	add hl,de
	ld de,OBJ_LAMP_MAX+1
	or a
	sbc hl,de
	add hl,de
	jr c,.fits
	ld hl,OBJ_LAMP_MAX
	ld (EQUIP+EQ_LIGHT*ITEM_SIZE+I_PVAL),hl
	ld hl,msg_overflows
	call msg_print
	ld hl,msg_lamp_full
	jr .said
.fits:
	ld (EQUIP+EQ_LIGHT*ITEM_SIZE+I_PVAL),hl
	ld de,OBJ_LAMP_MAX/2
	or a
	sbc hl,de
	ld hl,msg_lamp_half
	jr z,.said
	ld hl,msg_lamp_more
	jr nc,.said
	ld hl,msg_lamp_less
.said:
	call msg_print
	ld a,(cmd_slot)						; "You have 4 Flasks of oil (b)."
	call desc_remain
	ld a,(cmd_slot)
	jp use_one

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
	ld a,(ix+I_KIND_HI)
	cp ITEM_EMPTY
	ret z
	bit ID_CURSED_BIT,(ix+I_IDENT)
	ld hl,msg_seems_cursed
	jp nz,msg_print
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
	jr z,.said
	cp EQ_LIGHT
	ld hl,txt_light_was
	jr z,.said
	ld hl,txt_were_wearing
.said:
	call msg_add
	call objdes_msg
	ld hl,txt_full_stop
	call msg_add
	call msg_end
	ld (ix+I_KIND_HI),ITEM_EMPTY
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

/* cmd_read - 'r': read a scroll (SCROLLS.C; the effects are in the magic
	overlay). You need to see and to think straight */
cmd_read:
	ld hl,(p_blind)
	ld a,h
	or l
	ld hl,msg_cant_see
	jp nz,msg_print
	call no_light
	ld hl,msg_no_light
	jp z,msg_print
	ld hl,(p_confused)
	ld a,h
	or l
	ld hl,msg_too_confused
	jp nz,msg_print
	call pack_count
	or a
	ld hl,msg_pack_empty
	jp z,msg_print
	ld hl,txt_read_which
	ld a,IC_SCROLL
	call choose_pack
	jr c,.read
	ld a,IC_SCROLL
	call pack_has_class
	ret c
	ld hl,msg_no_scrolls
	jp msg_print
.read:
	ld (pending_arg),a
	ld a,PM_READ
	ld (pending_magic),a
	ld a,1
	ld (turn_taken),a
	ret

/* cmd_aim, cmd_use, cmd_zap - 'z' wand, 'Z' staff, 'a' rod: choose one,
	and the device overlay does the rest (WANDS.C, STAFFS.C, RODS.C) */
cmd_aim:
	ld hl,txt_aim_which
	ld de,msg_no_wands
	ld bc,IC_WAND*256+PM_AIM
	jr use_device
cmd_use:
	ld hl,txt_use_which
	ld de,msg_no_staffs
	ld bc,IC_STAFF*256+PM_USE
	jr use_device
cmd_zap:
	ld hl,txt_zap_which
	ld de,msg_no_rods
	ld bc,IC_ROD*256+PM_ZAP
use_device:
	ld (ud_prompt),hl
	ld (ud_none),de
	ld (ud_class),bc
	call pack_count
	or a
	ld hl,msg_pack_empty
	jp z,msg_print
	ld hl,(ud_prompt)					; "Aim which wand?"
	ld a,(ud_class+1)					; (the class)
	call choose_pack
	jr c,.chosen
	ld a,(ud_class+1)
	call pack_has_class
	ret c
	ld hl,(ud_none)
	jp msg_print
.chosen:
	ld (pending_arg),a
	ld a,(ud_class)
	ld (pending_magic),a
	ld a,1
	ld (turn_taken),a
	ret

/* cmd_activate - 'A': activate a worn artifact, known to be one (activate
	in DUNGEON.C); the device overlay does it */
cmd_activate:
	xor a
	ld (act_n),a
	ld (act_eq),a
.each:
	ld a,(act_eq)
	ld e,a
	ld d,ITEM_SIZE
	mul d,e
	ld ix,EQUIP
	add ix,de
	ld a,(ix+I_KIND_HI)
	cp ITEM_EMPTY
	jr z,.next
	bit ID_KNOWN2_BIT,(ix+I_IDENT)
	jr z,.next
	call item_flags
	ld a,(it_flags+5)
	bit F2_ACTIVATE,a
	jr z,.next
	ld hl,act_n							; one more: listed as a, b...
	ld e,(hl)
	inc (hl)
	ld d,0
	ld hl,act_slots
	add hl,de
	ld a,(act_eq)
	ld (hl),a
	push de
	call msg_begin
	pop de
	ld a,e
	add a,'a'
	call list_label
	call objdes_msg
	ld a,(act_n)
	dec a
	call list_line
.next:
	ld hl,act_eq
	inc (hl)
	ld a,(hl)
	cp EQ_SLOTS
	jr c,.each
	ld a,(act_n)
	or a
	ld hl,msg_nothing_activates
	jp z,msg_print
	ld hl,txt_activate_which
	call prompt
	call read_ascii
	push af
	call msg_clear
	pop af
	sub 'a'
	ld hl,act_n
	cp (hl)
	ret nc
	ld hl,act_slots
	add hl,a
	ld a,(hl)
	ld (pending_arg),a
	ld a,PM_ACTIVATE
	ld (pending_magic),a
	ld a,1
	ld (turn_taken),a
	ret

/* cmd_cast, cmd_browse, cmd_study - 'm', 'P', 'G': the spell overlay */
cmd_cast:
	OVCALL PAGE_SPELL, sp_cast, PAGE_ITEMS
	ret
cmd_browse:
	OVCALL PAGE_SPELL, sp_browse, PAGE_ITEMS
	ret
cmd_study:
	OVCALL PAGE_SPELL, sp_study, PAGE_ITEMS
	ret
cmd_pray:
	OVCALL PAGE_SPELL, sp_pray, PAGE_ITEMS
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
	call item_kind_addr
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
	ld a,(ix+I_KIND_HI)
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
	ld (ix+I_KIND_HI),ITEM_EMPTY
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
	ld (ix+I_KIND_HI),ITEM_EMPTY			; off the floor
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



equip_names:	dw txt_eq_weapon, txt_eq_body, txt_eq_shield, txt_eq_helm
				dw txt_eq_cloak, txt_eq_gloves, txt_eq_boots, txt_eq_neck
				dw txt_eq_right, txt_eq_left, txt_eq_light
txt_eq_weapon:	db "Wielding     : ",0
txt_eq_body:	db "On body      : ",0
txt_eq_shield:	db "On arm       : ",0
txt_eq_helm:	db "On head      : ",0
txt_eq_cloak:	db "About body   : ",0
txt_eq_gloves:	db "On hands     : ",0
txt_eq_boots:	db "On feet      : ",0
txt_eq_neck:	db "Around neck  : ",0
txt_eq_right:	db "On right hand: ",0
txt_eq_left:	db "On left hand : ",0
txt_eq_light:	db "Light source : ",0
txt_which_hand:	db "Put ring on which hand (l/r/L/R)?",0
txt_nothing:	db "(nothing)",0
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
txt_light_is:	db "Your light source is ",0
txt_light_was:	db "Your light source was ",0
msg_drop_first:	db "You will have to drop something first.",0
msg_not_lamp:	db "But you are not using a lamp.",0
msg_no_oil:		db "You have no oil.",0
msg_overflows:	db "Your lamp overflows, spilling oil on the ground.",0
msg_lamp_full:	db "Your lamp is full.",0
msg_lamp_more:	db "Your lamp is more than half full.",0
msg_lamp_half:	db "Your lamp is half full.",0
msg_lamp_less:	db "Your lamp is less than half full.",0
wd_slot:		dw 0
txt_you_drop:	db "You drop ",0
txt_you_have:	db "You have ",0
txt_slot_letter: db " (a).",0
txt_no_room_for: db "You have no room for ",0
txt_found:		db "You have found ",0
txt_gold_worth:	db " gold pieces worth of ",0
msg_pack_empty:	db "You are not carrying anything.",0
msg_no_potions:	db "You are not carrying any potions.",0
msg_no_scrolls:	db "You are not carrying any scrolls!",0
msg_cant_see:	db "You can't see to read the scroll.",0
msg_too_confused: db "You are too confused to read a scroll.",0
txt_read_which:	db "Read which scroll? (letter, or space)",0
msg_deathly_cold: db "Oops! It feels deathly cold!",0
msg_seems_cursed: db "Hmmm, it seems to be cursed.",0
txt_wielding_cursed: db " you are wielding appears to be cursed.",0
txt_wearing_cursed: db " you are wearing appears to be cursed.",0
txt_aim_which:	db "Aim which wand? (letter, or space)",0
txt_use_which:	db "Use which staff? (letter, or space)",0
txt_zap_which:	db "Activate which rod? (letter, or space)",0
msg_no_wands:	db "You are not carrying any wands.",0
msg_no_staffs:	db "You are not carrying any staffs.",0
msg_no_rods:	db "You are not carrying any rods.",0
msg_nothing_activates: db "You are not wearing/wielding anything that can be activated.",0
txt_activate_which: db "Activate which item? (letter, or space)",0
act_n:			db 0
act_eq:			db 0
act_slots:		ds EQ_SLOTS
ud_none:		dw 0
ud_prompt:		dw 0
ud_class:		dw 0				; action, class
msg_no_food:	db "You are not carrying any food.",0
msg_no_room:	db "You have no room in your pack.",0
msg_already_item: db "There is already something here.",0
msg_nothing_here: db "There is nothing here to pick up.",0
msg_floor_full:	db "There is no room on the floor.",0

cmd_slot:		db 0
cmd_equip:		db 0
drop_src:		dw 0
drop_dst:		dw 0
num_tmp:		dw 0
