/* throw.asm - throwing things (overlay page PAGE_TRAP, after traps.asm)
	References: MORIA2.C throw_object/inven_throw/facts/drop_throw,
	MISC2.C tot_dam, MORIA1.C test_hit/critical_blow.
	Whatever is thrown flies up to (STR + 20) x 10 / its weight squares
	(at most 10) and hits the first monster in its way, with the missile
	skill; flasks of oil burn (their fire brand). It's gone if it hits,
	and lands near where it stopped if it misses. (Bows: milestone 13b.)
 */

/* cmd_throw - 'v': throw an item from the pack (throw_object) */
cmd_throw:
	ld a,(PACK+I_KIND_HI)
	cp ITEM_EMPTY
	ld hl,mt_carrying_nothing
	jp z,msg_print
	ld hl,mt_throw_which
	xor a
	call choose_pack
	ret nc
	ld (th_slot),a
	OVCALL PAGE_DEVICE, get_dir, PAGE_TRAP	; (confused, it goes astray)
	ret nc
	ld (th_dir),a
	ld a,1
	ld (turn_taken),a
	ld a,(th_slot)						; "You have 4 Flasks of oil (c)."
	call desc_remain
	ld a,(th_slot)						; one of them leaves the pack
	call pack_slot
	push ix
	pop hl
	ld de,th_obj
	ld bc,ITEM_SIZE
	ldir
	ld a,1
	ld (th_obj+I_NUMBER),a
	ld a,(th_slot)
	call use_one
	ld hl,p_update						; (lighter)
	set PU_BONUS,(hl)
	call facts
	ld a,(player_y)						; the flight
	ld (th_y),a
	ld (th_oldy),a
	ld a,(player_x)
	ld (th_x),a
	ld (th_oldx),a
	xor a
	ld (th_dist),a
.fly:
	ld a,(th_dir)						; one square on
	dec a
	add a,a
	ld hl,keypad_deltas
	add hl,a
	ld a,(th_y)
	add a,(hl)
	ld (th_y),a
	ld d,a
	inc hl
	ld a,(th_x)
	add a,(hl)
	ld (th_x),a
	ld e,a
	ld hl,th_dist
	inc (hl)
	ld a,(th_range)						; as far as it goes
	cp (hl)
	jp c,drop_throw
	push de
	call map_addr
	pop de
	ld a,(hl)
	push af
	and TERRAIN_MASK
	call terrain_flags
	ld b,a
	pop af
	bit TF_PASSABLE,b					; a wall stops it
	jp z,drop_throw
	bit F_MON_BIT,a
	jr nz,.monster
	ld a,(th_y)
	ld (th_oldy),a
	ld a,(th_x)
	ld (th_oldx),a
	jr .fly
.monster:
	call mon_at
	jr nc,.fly							; (shouldn't happen)
	jp hit_monster

/* facts - th_obj -> th_dam, th_bth, th_pth, th_range, th_weight, and the
	slays it brings (facts): damage its dice + to-dam; skill 3/4 of the
	missile skill; to-hit the player's, less the wielded weapon's, plus
	its own; range (STR + 20) x 10 / weight, at most 10 */
facts:
	ld ix,th_obj
	call item_dice						; (IY = its kind)
	ld c,b
	ld b,a
	call damroll
	ld a,(th_obj+I_TODAM)
	call add_signed
	ld (th_dam),hl
	ld ix,th_obj
	call item_kind_addr
	ld l,(iy+K_WEIGHT)
	ld h,(iy+K_WEIGHT+1)
	ld a,h
	or l
	jr nz,$+3
	inc l
	ld (th_weight),hl
	ex de,hl							; range
	ld a,(p_stat_use+A_STR)
	ld l,a
	ld h,0
	ld bc,20
	add hl,bc
	ld b,h
	ld c,l
	add hl,hl							; x 10
	add hl,hl
	add hl,bc
	add hl,hl
	xor a								; / weight, counting to 10
.count:
	or a
	sbc hl,de
	jr c,.range
	inc a
	cp 10
	jr c,.count
.range:
	ld (th_range),a
	ld a,(p_bthb)						; bthb x 75 / 100
	ld e,a
	ld d,75
	mul d,e
	ex de,hl
	ld c,100
	call div16_8
	ld (th_bth),hl
	ld a,(p_tohit)						; to-hit
	ld l,a
	rla
	sbc a,a
	ld h,a
	ld a,(EQUIP+EQ_WEAPON*ITEM_SIZE+I_KIND_HI)
	cp ITEM_EMPTY
	jr z,.own
	ld a,(EQUIP+EQ_WEAPON*ITEM_SIZE+I_TOHIT)
	neg
	call add_signed
.own:
	ld a,(th_obj+I_TOHIT)
	call add_signed
	ld (th_pth),hl
	ld ix,th_obj						; slays and brands, as calc_bonuses
	call item_flags						; works them out for the weapon
	ld hl,th_slay_flags
	ld de,0
	ld b,NUM_SLAYS
.slays:
	ld a,(hl)
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
	ld (th_slays),de
	ret
; (inventory.asm's slay_flags: which byte of it_flags, which bit)
th_slay_flags:
	db 5,1<<F2_LIGHTNING, 3,1<<EF3_SLAY_X_DRAGON, 1,1<<EF1_SLAY_DRAGON
	db 2,1<<EF2_SLAY_UNDEAD, 4,1<<F2_SLAY_ORC, 4,1<<F2_SLAY_TROLL
	db 4,1<<F2_SLAY_GIANT, 4,1<<F2_SLAY_DEMON, 2,1<<EF2_FROST_BRAND
	db 2,1<<EF2_FLAME_TONGUE, 1,1<<EF1_SLAY_EVIL, 1,1<<EF1_SLAY_ANIMAL

/* add_signed - HL += A (signed). Clobbers DE */
add_signed:
	ld e,a
	rla
	sbc a,a
	ld d,a
	add hl,de
	ret

/* hit_monster - IX = the monster in the way: the missile skill less the
	distance (much less if it can't be seen), against its AC */
hit_monster:
	ld (ix+M_SLEEP),0					; (it wakes up, hit or not)
	ld (ix+M_SLEEP+1),0
	call mon_race
	ld hl,(th_bth)						; bth - distance
	ld a,(th_dist)
	ld e,a
	ld d,0
	or a
	sbc hl,de
	ld a,(ix+M_ML)
	or a
	jr nz,.seen
	ld a,(th_dist)						; unseen: / (distance + 2), less
	add a,2								; lev x adj / 2 and pth x 2
	ld c,a
	bit 7,h
	jr nz,.neg
	call div16_8
	jr .less
.neg:
	ld hl,0
.less:
	ld a,(p_cla_bthb)
	srl a
	ld e,a
	ld a,(p_lev)
	ld d,a
	mul d,e
	or a
	sbc hl,de
	ld de,(th_pth)
	or a
	sbc hl,de
	sbc hl,de
.seen:
	ld de,(th_pth)						; test_hit: + pth x 3 + lev x adj
	add hl,de
	add hl,de
	add hl,de
	ld a,(p_cla_bthb)
	ld e,a
	ld a,(p_lev)
	ld d,a
	mul d,e
	add hl,de
	ld a,(iy+R_AC)
	call test_hit
	jp nc,drop_throw					; (where it was before the monster)
	ld a,(ix+M_ML)						; "The Flask of oil hits the Orc."
	ld (th_seen),a
	call msg_begin
	ld hl,txt_the_t
	call msg_add
	push ix
	ld ix,th_obj
	ld a,1
	ld (od_bare),a
	call objdes_msg
	xor a
	ld (od_bare),a
	pop ix
	ld hl,mt_finds_mark
	ld a,(th_seen)
	or a
	jr z,.said
	ld hl,mt_hits
	call msg_add
	xor a
	ld (name_cap),a
	call mon_race
	call mon_name_to_msg
	ld hl,txt_full_stop
.said:
	call msg_add
	call msg_end
	ld hl,(w_slays)						; the slays, the weight and the
	push hl								; to-hit are the missile's for
	ld hl,(w_weight)					; tot_dam and critical_blow
	push hl
	ld a,(p_tohit)
	push af
	ld hl,(th_slays)
	ld (w_slays),hl
	ld hl,(th_weight)
	ld (w_weight),hl
	ld a,(th_pth)
	ld (p_tohit),a
	call mon_race
	ld hl,(th_dam)
	call tot_dam
	call critical_blow
	bit 7,h
	jr z,$+5
	ld hl,0
	ld (th_dam),hl
	pop af
	ld (p_tohit),a
	pop hl
	ld (w_weight),hl
	pop hl
	ld (w_slays),hl
	ld e,(ix+M_HP)						; (its hit points, for the pain)
	ld d,(ix+M_HP+1)
	ld (th_oldhp),de
	ld a,1
	ld (mth_quiet),a
	ld hl,(th_dam)
	call mon_take_hit
	ld a,0
	ld (mth_quiet),a
	jr c,.killed
	call msg_begin						; "The Orc grunts with pain."
	ld a,1
	ld (name_cap),a
	call mon_race
	call mon_name_to_msg
	ld de,(th_oldhp)
	OVCALL PAGE_DEVICE, pain_add, PAGE_TRAP
	jp msg_end
.killed:
	ld hl,mt_killed_something
	ld a,(th_seen)
	or a
	jp z,msg_print
	call msg_begin						; "You have killed the Orc."
	ld hl,mt_you_killed
	call msg_add
	xor a
	ld (name_cap),a
	call mon_name_to_msg
	ld hl,txt_full_stop
	call msg_add
	jp msg_end

/* drop_throw - th_obj comes down at (th_oldy, th_oldx), or one of the
	squares round it, on bare floor; 1 in 10 (or nowhere to fall) "The
	Flask of oil disappears." (drop_throw) */
drop_throw:
	ld a,10
	call randint
	cp 1
	jr z,.gone
	ld a,(th_oldy)
	ld (th_try_y),a
	ld d,a
	ld a,(th_oldx)
	ld (th_try_x),a
	ld e,a
	ld b,11								; there, then up to 10 tries
.try:
	push bc
	push de
	call map_addr
	pop de
	ld a,(hl)
	and TERRAIN_MASK
	cp T_FLOOR
	jr z,.floor
	cp T_CORRIDOR
	jr z,.floor
	cp T_FLOOR_LIT
	jr nz,.next
.floor:
	push de								; nothing there already
	call item_at
	pop de
	jr c,.next
	call trap_at
	jr c,.next
	call item_free_slot
	jr nc,.next
	pop bc
	push ix								; it lands
	pop de
	push de
	ld hl,th_obj
	ld bc,ITEM_SIZE
	ldir
	pop ix
	ld a,(th_try_y)
	ld (ix+I_Y),a
	ld a,(th_try_x)
	ld (ix+I_X),a
	ret
.next:
	ld a,(th_oldy)						; y + 1d3 - 2, x + 1d3 - 2
	ld (th_try_y),a
	ld a,3
	call randint
	ld hl,th_try_y
	add a,(hl)
	sub 2
	ld (hl),a
	ld a,(th_oldx)
	ld (th_try_x),a
	ld a,3
	call randint
	ld hl,th_try_x
	add a,(hl)
	sub 2
	ld (hl),a
	ld e,a
	ld a,(th_try_y)
	ld d,a
	pop bc
	djnz .try
.gone:
	call msg_begin
	ld hl,txt_the_t
	call msg_add
	ld ix,th_obj
	ld a,1
	ld (od_bare),a
	call objdes_msg
	xor a
	ld (od_bare),a
	ld hl,mt_disappears
	call msg_add
	jp msg_end

mt_carrying_nothing: db "But you are not carrying anything.",0
mt_throw_which:	db "Fire/Throw which one?",0
txt_the_t:		db "The ",0
mt_hits:		db " hits ",0
mt_finds_mark:	db " finds a mark.",0
mt_killed_something: db "You have killed something!",0
mt_you_killed:	db "You have killed ",0
mt_disappears:	db " disappears.",0

th_slot:		db 0
th_dir:			db 0
th_obj:			ds ITEM_SIZE
th_dam:			dw 0
th_bth:			dw 0
th_pth:			dw 0
th_range:		db 0
th_weight:		dw 0
th_slays:		dw 0
th_y:			db 0
th_x:			db 0
th_oldy:		db 0
th_oldx:		db 0
th_try_y:		db 0
th_try_x:		db 0
th_dist:		db 0
th_seen:		db 0
th_oldhp:		dw 0
