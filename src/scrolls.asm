/* scrolls.asm - reading scrolls  [overlay: PAGE_SCROLL]
	References: SCROLLS.C read_scroll, SPELLS.C (light_area, unlight_area,
	map_area, the detections, ident_spell, (mass_)genocide, aggravate_monster,
	td_destroy, protect_evil, create_food, dispel_creature, destroy_area),
	MISC2.C teleport, MORIA1.C darken_room, MISC1.C summon_* (level overlay).
	As with potions, each flag bit is an effect, from 1 (33 for TV_SCROLL2).
	Not yet: enchanting and cursing (9c), runes, traps, recharging and
	acquirement - those scrolls aren't generated.
 */

/* read_scroll - A = pack slot of the scroll to read */
read_scroll:
	ld (u_slot),a
	call pack_slot
	call item_kind_addr
	ld (u_kind),hl
	ld a,(iy+K_LEVEL)
	ld (u_level),a
	ld a,(iy+K_GROUP2)
	or a
	jr z,$+4
	ld a,32
	ld (r_base),a
	push iy
	pop hl
	ld de,K_FLAGS
	add hl,de
	ld de,r_flags
	ld bc,4
	ldir
	xor a
	ld (u_ident),a
	ld (r_bit),a
	inc a
	ld (r_used),a
.bit:
	ld hl,r_flags+3
	srl (hl)
	dec hl
	rr (hl)
	dec hl
	rr (hl)
	dec hl
	rr (hl)
	jr nc,.next
	ld a,(r_bit)
	ld hl,r_base
	add a,(hl)
	call scroll_effect
.next:
	ld hl,r_bit
	inc (hl)
	ld a,(hl)
	cp 32
	jr c,.bit
	call monsters_see_all				; (things may have moved or gone)
	call item_used
	ld a,(r_used)						; identify can be put back unused
	or a
	ret z
	ld a,(u_slot)
	call desc_remain
	ld a,(u_slot)
	jp use_one

/* scroll_effect - A = effect number - 1 */
scroll_effect:
	cp NUM_SCROLL_EFFECTS
	ret nc
	add a,a
	ld hl,scroll_effects
	add hl,a
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	jp (hl)

scroll_effects:
	dw sc_none, sc_none, sc_none, sc_identify, sc_none, sc_light	; 1-6
	dw sc_summon, sc_phase, sc_teleport, sc_tele_level, sc_confuse	; 7-11
	dw sc_map, sc_none, sc_none, sc_treasure, sc_objects, sc_none	; 12-17
	dw sc_doors, sc_mass_genocide, sc_det_inv, sc_aggravate, sc_none	; 18-22
	dw sc_td_destroy, sc_none, sc_recharge, sc_genocide, sc_darkness	; 23-27
	dw sc_protevil, sc_food, sc_dispel_undead, ident, sc_none		; 28-32
	dw sc_none, sc_none, sc_none, sc_none, sc_summon_undead			; 33-37
	dw sc_bless, sc_chant, sc_prayer, sc_recall, sc_destruction		; 38-42
NUM_SCROLL_EFFECTS	equ ($-scroll_effects)/2
; 5: remove curse and 17: trap detection find nothing yet (no curses or
; traps); 31: *remove curse* identifies itself regardless

sc_none:
	ret

; ---------------------------------------------------------------- 4

/* sc_identify - choose a pack item and learn what it is (ident_spell) */
sc_identify:
	ld hl,msg_identify_scroll
	call msg_print
/* sc_identify_item - ident_spell (staffs and rods use it too) */
sc_identify_item:
	call ident
	ld hl,txt_ident_which
	xor a
	call choose_pack
	jr c,.chosen
	xor a								; put back, unread
	ld (r_used),a
	ret
.chosen:
	ld (r_slot),a
	call item_kind_addr
	ld (r_kind),hl
	call learn_kind
	ld hl,(r_kind)						; flavoured: stacks may have joined
	call kind_addr
	call flavour_class
	jr nc,.say
	ld hl,(r_kind)
	call find_pack_kind
	ld (r_slot),a
.say:
	call msg_begin						; "b) a Potion of Healing."
	ld a,(r_slot)
	add a,'a'
	call list_label
	ld a,(r_slot)
	call pack_slot
	call objdes_msg
	ld hl,txt_full_stop
	call msg_add
	jp msg_end

; ---------------------------------------------------------------- 6, 27

/* sc_light - light_area: the room, or the squares around you */
sc_light:
	call ident
	ld a,(p_status)
	bit PY_BLIND,a
	ld hl,msg_white_light
	call z,msg_print
	ld a,(dun_level)
	or a
	jr z,.around
	call player_square
	call light_room						; (does nothing outside a room)
.around:
	call player_square
	ld de,-MAP_W-1
	add hl,de
	ld de,MAP_W-2
	ld b,3
.row:
	set F_PERM_BIT,(hl)
	inc hl
	set F_PERM_BIT,(hl)
	inc hl
	set F_PERM_BIT,(hl)
	add hl,de
	djnz .row
	ret

/* sc_darkness - unlight_area: darken the room, or a lit corridor */
sc_darkness:
	xor a
	ld (r_any),a
	ld a,(dun_level)
	or a
	jr z,.corridor
	call player_square
	bit F_ROOM_BIT,(hl)
	jr z,.corridor
	call darken_room
	ld a,1								; (true even if it was dark already)
	ld (r_any),a
	jr .said
.corridor:
	call player_square
	ld de,-MAP_W-1
	add hl,de
	ld c,3
.row:
	ld b,3
.col:
	ld a,(hl)
	and TERRAIN_MASK|F_PERM
	cp T_CORRIDOR|F_PERM
	jr nz,.next
	res F_PERM_BIT,(hl)
	ld a,1
	ld (r_any),a
.next:
	inc hl
	djnz .col
	ld de,MAP_W-3
	add hl,de
	dec c
	jr nz,.row
.said:
	ld a,(r_any)
	or a
	ret z
	call ident
	ld a,(p_status)
	bit PY_BLIND,a
	ret nz
	ld hl,msg_darkness
	jp msg_print

/* darken_room - flood out from the player through the room's lit floor,
	forgetting it (walls and doors stay remembered) */
darken_room:
	call player_square
	call lit_room_floor
	ret nz
	res F_PERM_BIT,(hl)
	ex de,hl
	ld hl,LIGHT_QUEUE
	ld (hl),e
	inc hl
	ld (hl),d
	inc hl
	ld (dk_tail),hl
	ld hl,LIGHT_QUEUE
	ld (dk_head),hl
.loop:
	ld hl,(dk_head)
	ld de,(dk_tail)
	or a
	sbc hl,de
	ret z
	ld hl,(dk_head)
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld (dk_head),hl
	ex de,hl							; HL = square
	ld ix,neighbour_offsets
	ld b,8
.neighbour:
	push bc
	push hl
	ld e,(ix+0)
	ld d,(ix+1)
	add hl,de
	call lit_room_floor
	jr nz,.skip
	res F_PERM_BIT,(hl)
	ex de,hl
	ld hl,(dk_tail)
	ld (hl),e
	inc hl
	ld (hl),d
	inc hl
	ld (dk_tail),hl
.skip:
	pop hl
	pop bc
	inc ix
	inc ix
	djnz .neighbour
	jr .loop

/* lit_room_floor - HL = square -> Z if it's lit floor in a room */
lit_room_floor:
	ld a,(hl)
	and F_ROOM|F_PERM|TERRAIN_MASK
	cp F_ROOM|F_PERM|T_FLOOR
	ret z
	cp F_ROOM|F_PERM|T_FLOOR_LIT
	ret

; ---------------------------------------------------------------- 7, 37

sc_summon:
	ld hl,summon_monster
	jr summon_some
sc_summon_undead:
	ld hl,summon_undead
/* summon_some - HL = summoner in the level overlay: while k < 1d3 (rolled
	afresh each time, as the C's for loop does) */
summon_some:
	ld (r_summoner),hl
	xor a
	ld (r_k),a
.loop:
	ld a,(summon_max)
	call randint
	ld b,a
	ld a,(r_k)
	cp b
	ret nc
	ld a,(player_y)
	ld d,a
	ld a,(player_x)
	ld e,a
	ld hl,(r_summoner)
	call level_call
	call c,ident
	ld hl,r_k
	inc (hl)
	jr .loop

; ---------------------------------------------------------------- 8-10

sc_phase:
	call ident
	ld hl,10
	jr teleport
sc_teleport:
	call ident
	ld hl,100
/* teleport - HL = how far: a random open square within that distance,
	doubling it after 1000 failures (teleport in MISC2.C) */
teleport:
	ld (tp_dis),hl
.round:
	ld hl,1000
	ld (tp_count),hl
.try:
	ld a,(dun_level)					; somewhere on the level
	or a
	ld a,MAP_H
	jr nz,$+4
	ld a,TOWN_H
	call randint
	dec a
	ld (tp_y),a
	ld a,(dun_level)
	or a
	ld a,MAP_W
	jr nz,$+4
	ld a,TOWN_W
	call randint
	dec a
	ld (tp_x),a
.closer:								; halve the way to the player
	ld a,(tp_y)							; while too far
	ld d,a
	ld a,(tp_x)
	ld e,a
	call mon_distance
	ld l,a
	ld h,0
	ld de,(tp_dis)
	or a
	sbc hl,de
	jr z,.near
	jr c,.near
	ld a,(player_y)
	ld hl,tp_y
	call halve_toward
	ld a,(player_x)
	ld hl,tp_x
	call halve_toward
	jr .closer
.near:
	ld a,(tp_y)
	ld d,a
	ld a,(tp_x)
	ld e,a
	push de
	call map_addr
	pop de
	ld a,(hl)
	bit F_MON_BIT,a
	jr nz,.fail
	and TERRAIN_MASK
	ld hl,landing
	add hl,a
	ld a,(hl)
	or a
	jr nz,.land
.fail:
	ld hl,(tp_count)
	dec hl
	ld (tp_count),hl
	ld a,h
	or l
	jr nz,.try
	ld hl,(tp_dis)
	add hl,hl
	ld (tp_dis),hl
	jp .round
.land:
	push de
	call lamp_off
	pop de
	ld a,d
	ld (player_y),a
	ld a,e
	ld (player_x),a
	call light_arrive
	call update_view
	jp monsters_see_all

; squares you can land on: floors, corridor, stairs (not doors)
landing:		db 0,1,1,0,0,0,0,0,1,1,0,0,0,0,1,0

/* halve_toward - A = the player's coordinate, HL -> ours: move half the
	way (the C's integer division, rounding toward zero) */
halve_toward:
	sub (hl)
	jr c,.minus
	srl a
	add a,(hl)
	ld (hl),a
	ret
.minus:
	neg
	srl a
	ld b,a
	ld a,(hl)
	sub b
	ld (hl),a
	ret

sc_tele_level:
	call ident
	ld a,2								; up or down a level
	call randint
	add a,a
	sub 3
	ld hl,dun_level
	add a,(hl)
	bit 7,a
	jr z,$+3
	xor a
	ld (hl),a
	ld a,3								; (nothing said)
	ld (p_new_level),a
	ret

; ---------------------------------------------------------------- 11, 28

sc_confuse:
	ld a,(p_confuse_mon)
	or a
	ret nz
	ld a,1
	ld (p_confuse_mon),a
	call ident
	ld hl,msg_hands_glow
	jp msg_print

sc_protevil:
	ld hl,p_protevil					; identifies if it wasn't running
	call get_w
	call z,ident
	ld a,(p_lev)						; += 1d25 + 3 * lev
	ld e,a
	ld d,3
	mul d,e
	push de
	ld a,25
	call randint
	pop de
	add de,a
	ld hl,(p_protevil)
	add hl,de
	ld (p_protevil),hl
	ret

; ---------------------------------------------------------------- 12

/* sc_map - map_area: walls, doors and stairs beside open squares in and
	around the view are mapped */
sc_map:
	call ident
	ld a,10
	call randint
	ld b,a
	ld a,(view_y)
	sub b
	jr nc,$+3
	xor a
	ld (mp_y0),a
	ld a,10
	call randint
	add a,VIEW_H-1
	ld hl,view_y
	add a,(hl)
	cp MAP_H
	jr c,$+4
	ld a,MAP_H-1
	ld (mp_y1),a
	ld a,20
	call randint
	ld b,a
	ld a,(view_x)
	sub b
	jr nc,$+3
	xor a
	ld (mp_x0),a
	ld a,20
	call randint
	add a,VIEW_W-1
	ld hl,view_x
	add a,(hl)
	jr c,.wide
	cp MAP_W
	jr c,$+4
.wide:
	ld a,MAP_W-1
	ld (mp_x1),a
	ld a,(mp_y0)
	ld d,a
.row:
	ld a,(mp_x0)
	ld e,a
.col:
	push de
	call in_bounds
	jr nc,.next
	call map_addr
	ld a,(hl)
	and TERRAIN_MASK
	ld de,open_squares
	add de,a
	ld a,(de)
	or a
	jr z,.next
	ld de,-MAP_W-1
	add hl,de
	ld c,3
.nrow:
	ld b,3
.ncol:
	ld a,(hl)
	and TERRAIN_MASK
	cp T_FLOOR
	jr z,.floor
	cp T_CORRIDOR
	jr z,.floor
	cp T_FLOOR_LIT
	jr z,.floor
	set F_PERM_BIT,(hl)
.floor:
	inc hl
	djnz .ncol
	ld de,MAP_W-3
	add hl,de
	dec c
	jr nz,.nrow
.next:
	pop de
	ld a,(mp_x1)
	cp e
	jr z,.row_done
	inc e
	jr .col
.row_done:
	ld a,(mp_y1)
	cp d
	ret z
	inc d
	jr .row

; open squares (fval <= MAX_CAVE_FLOOR; doors and stairs stand on floor)
open_squares:	db 0,1,1,0,0,1,1,1,1,1,0,0,0,0,1,1

; ---------------------------------------------------------------- 15, 16, 18

sc_treasure:
	ld a,1
	jr detect_items
sc_objects:
	xor a
/* detect_items - A = 1 for gold, 0 for objects: those in the view that
	can't be seen are marked so they're drawn */
detect_items:
	ld (r_gold),a
	xor a
	ld (r_any),a
	ld ix,ITEM_LIST
	ld b,ITEM_MAX
.each:
	push bc
	ld a,(ix+I_KIND_HI)
	cp ITEM_EMPTY
	jr z,.next
	cp KIND_GOLD
	ld a,0
	jr nz,$+3
	inc a
	ld hl,r_gold
	cp (hl)
	jr nz,.next
	ld d,(ix+I_Y)
	ld e,(ix+I_X)
	call in_view
	jr nc,.next
	ld a,(ix+I_MARKED)
	or a
	jr nz,.next
	call map_addr
	ld a,(hl)
	and F_SEEN
	jr nz,.next
	ld (ix+I_MARKED),1
	ld a,1
	ld (r_any),a
.next:
	ld de,ITEM_SIZE
	add ix,de
	pop bc
	djnz .each
	ld a,(r_any)
	or a
	ret z
	jp ident

/* in_view - D = y, E = x -> carry if it's within the view (panel) */
in_view:
	ld a,(view_y)
	ld b,a
	ld a,d
	sub b
	jr c,.no
	cp VIEW_H
	ret nc
	ld a,(view_x)
	ld b,a
	ld a,e
	sub b
	jr c,.no
	cp VIEW_W
	ret
.no:
	or a
	ret

/* sc_doors - detect_sdoor: secret doors in view become plain doors, and
	stairs are remembered */
sc_doors:
	xor a
	ld (r_any),a
	ld a,(view_y)
	ld d,a
	ld c,VIEW_H
.row:
	ld a,(view_x)
	ld e,a
	push de
	call map_addr
	pop de
	ld b,VIEW_W
.col:
	ld a,(hl)
	and TERRAIN_MASK
	cp T_DOOR_SECRET
	jr nz,.stairs
	ld a,(hl)
	and ~TERRAIN_MASK
	or T_DOOR_CLOSED|F_PERM
	ld (hl),a
	jr .found
.stairs:
	cp T_STAIR_DOWN
	jr z,.stair
	cp T_STAIR_UP
	jr nz,.next
.stair:
	bit F_PERM_BIT,(hl)
	jr nz,.next
	set F_PERM_BIT,(hl)
.found:
	ld a,1
	ld (r_any),a
.next:
	inc hl
	djnz .col
	inc d
	dec c
	jr nz,.row
	ld a,(r_any)
	or a
	ret z
	jp ident

; ---------------------------------------------------------------- monsters

/* sc_mass_genocide - every non-unique within sight dies; 1d3 damage each */
sc_mass_genocide:
	ld hl,msg_mass_genocide
	call msg_print
	ld ix,MON_LIST
	ld b,MON_MAX
.each:
	push bc
	ld a,(ix+M_RACE_HI)
	cp MON_EMPTY
	jr z,.next
	ld a,(ix+M_CDIS)
	cp MAX_SIGHT+1
	jr nc,.next
	call mon_race
	bit RF_UNIQUE,(iy+R_FLAGS)
	jr nz,.next
	bit RF2_WIN,(iy+R_FLAGS2)
	jr nz,.next
	call mon_remove
	call ident
	ld a,3
	call randint
	call strain
.next:
	ld de,MON_SIZE
	add ix,de
	pop bc
	djnz .each
	ret

/* strain - A = damage from casting genocide */
strain:
	ld l,a
	ld h,0
	ld de,KILLER_STRAIN
	jp hurt

/* sc_genocide - every monster of the letter you choose dies; 1d4 each */
sc_genocide:
	ld hl,msg_genocide
	call msg_print
	call msg_flush
	ld hl,txt_genocide_which
	call prompt
	call read_ascii
	ld (r_char),a
	call msg_clear
	ld ix,MON_LIST
	ld b,MON_MAX
.each:
	push bc
	ld a,(ix+M_RACE_HI)
	cp MON_EMPTY
	jr z,.next
	call mon_race
	ld a,(r_char)
	cp (iy+R_CHAR)
	jr nz,.next
	bit RF2_WIN,(iy+R_FLAGS2)
	jr nz,.spared
	call mon_remove
	call ident
	ld a,(gen_strain)					; (staffs don't hurt)
	or a
	jr z,.next
	ld a,4
	call randint
	call strain
	jr .next
.spared:								; "The X is unaffected."
	call msg_begin
	ld a,1
	ld (name_cap),a
	ld a,(ix+M_ML)						; (named even if unseen)
	push af
	ld (ix+M_ML),1
	call mon_name_to_msg
	pop af
	ld (ix+M_ML),a
	ld hl,txt_unaffected
	call msg_add
	call msg_end
.next:
	ld de,MON_SIZE
	add ix,de
	pop bc
	djnz .each
	ret

/* sc_det_inv - invisible monsters in view are shown until a key */
sc_det_inv:
	xor a
	ld (r_any),a
	ld ix,MON_LIST
	ld b,MON_MAX
.each:
	push bc
	ld a,(ix+M_RACE_HI)
	cp MON_EMPTY
	jr z,.next
	call mon_race
	bit RF_INVISIBLE,(iy+R_FLAGS)
	jr z,.next
	ld d,(ix+M_Y)
	ld e,(ix+M_X)
	call in_view
	jr nc,.next
	ld (ix+M_ML),1
	ld a,(view_y)						; draw it
	ld b,a
	ld a,d
	sub b
	add a,VIEW_TOP
	ld d,a
	ld a,(view_x)
	ld b,a
	ld a,e
	sub b
	ld e,a
	call screen_addr
	push hl
	call mon_race
	pop hl
	ld a,(iy+R_CHAR)
	ld (hl),a
	inc hl
	ld a,(iy+R_ATTR)
	ld (hl),a
	ld a,1
	ld (r_any),a
.next:
	ld de,MON_SIZE
	add ix,de
	pop bc
	djnz .each
	ld a,(r_any)
	or a
	ret z
	call ident
	ld hl,msg_sense_invisible
	call msg_print
	call msg_flush
	jp monsters_see_all

/* sc_aggravate - everything wakes; those within 20 speed up a step */
sc_aggravate:
	xor a
	ld (r_any),a
	ld ix,MON_LIST
	ld b,MON_MAX
.each:
	ld a,(ix+M_RACE_HI)
	cp MON_EMPTY
	jr z,.next
	ld (ix+M_SLEEP),0
	ld (ix+M_SLEEP+1),0
	ld a,(ix+M_CDIS)
	cp 21
	jr nc,.next
	ld a,(ix+M_SPEED)
	cp 2
	jp p,.next							; (signed: already 2 or more)
	inc (ix+M_SPEED)
	ld a,1
	ld (r_any),a
.next:
	ld de,MON_SIZE
	add ix,de
	djnz .each
	ld a,(r_any)
	or a
	ret z
	ld hl,msg_stirring
	call msg_print
	call ident
	ld hl,msg_humming
	jp msg_print

/* sc_dispel_undead - undead in sight take 1d60: "dissolves!"/"shudders." */
sc_dispel_undead:
	ld ix,MON_LIST
	ld b,MON_MAX
.each:
	push bc
	ld a,(ix+M_RACE_HI)
	cp MON_EMPTY
	jr z,.next
	ld a,(ix+M_CDIS)
	cp 100
	jr nc,.next
	call mon_race
	ld a,(dispel_mask)					; (0: anything)
	or a
	jr z,.kind
	and (iy+R_FLAGS)
	jr z,.next
.kind:
	ld d,(ix+M_Y)
	ld e,(ix+M_X)
	call los
	jr nc,.next
	ld a,(ix+M_ML)
	ld (r_seen),a
	call msg_begin						; name it before it might die
	ld a,1
	ld (name_cap),a
	call mon_race
	call mon_name_to_msg
	ld a,(dispel_dam)
	call randint
	ld l,a
	ld h,0
	ld a,1
	ld (mth_quiet),a
	call mon_take_hit
	ld a,0
	ld (mth_quiet),a
	ld hl,txt_dissolves
	jr c,$+5
	ld hl,txt_shudders
	ld a,(r_seen)
	or a
	jr z,.next
	call msg_add
	call msg_end
	call ident
.next:
	ld de,MON_SIZE
	add ix,de
	pop bc
	djnz .each
	ret

; ---------------------------------------------------------------- 23, 29

/* sc_td_destroy - doors around you are destroyed */
sc_td_destroy:
	call player_square
	ld de,-MAP_W-1
	add hl,de
	ld c,3
.row:
	ld b,3
.col:
	ld a,(hl)
	and TERRAIN_MASK
	cp T_DOOR_CLOSED
	jr c,.next
	cp T_DOOR_SECRET+1
	jr nc,.next
	ld a,(hl)
	and ~TERRAIN_MASK
	or T_CORRIDOR
	ld (hl),a
	push bc
	push hl
	call ident
	pop hl
	pop bc
.next:
	inc hl
	djnz .col
	ld de,MAP_W-3
	add hl,de
	dec c
	jr nz,.row
	ret

/* sc_food - create_food: a slime mold under you, if there's room */
sc_food:
	call ident
	ld a,(player_y)
	ld d,a
	ld a,(player_x)
	ld e,a
	call item_at
	ld hl,msg_object_under
	jp c,msg_print
	call item_free_slot
	ret nc
	ld (ix+I_KIND),low KIND_SLIME_MOLD
	ld (ix+I_KIND_HI),high KIND_SLIME_MOLD
	ld (ix+I_NUMBER),1
	ld a,(player_y)
	ld (ix+I_Y),a
	ld a,(player_x)
	ld (ix+I_X),a
	ld (ix+I_MARKED),1
	ld (ix+I_IDENT),0
	ld hl,msg_roll_beneath
	jp msg_print

; ---------------------------------------------------------------- 25

/* sc_recharge - recharge(60): more charges for a wand or staff, but it
	may explode (recharge in SPELLS.C) */
sc_recharge:
	ld hl,msg_recharge_scroll
	call msg_print
	call ident
	ld a,FILTER_CHARGED
	call pack_has_class
	ld hl,msg_nothing_to_charge
	jp nc,msg_print
	ld hl,txt_recharge_which
	ld a,FILTER_CHARGED
	call choose_pack
	jr c,.chosen
	xor a								; (not used up)
	ld (r_used),a
	ret
.chosen:
	ld (r_slot),a
	call item_kind_addr
	ld a,(ix+I_PVAL)					; fails 1 in (160 - level - 10*charges)/15
	ld e,a
	ld d,10
	mul d,e
	ld hl,60+100
	or a
	sbc hl,de
	ld e,(iy+K_LEVEL)
	ld d,0
	or a
	sbc hl,de
	bit 7,h
	jr nz,.boom
	ld c,15
	call div16_8
	ld a,h
	or a
	jr nz,.roll
	ld a,l
	cp 2
	jr c,.boom							; (1 in 1)
.roll:
	call randint16
	dec hl
	ld a,h
	or l
	jr nz,.charge
.boom:
	ld hl,msg_bright_flash
	call msg_print
	ld a,(r_slot)						; the wand is gone; the scroll's slot
	call pack_remove					; may move up
	ld a,(r_slot)
	ld hl,u_slot
	cp (hl)
	ret nc
	dec (hl)
	ret
.charge:								; p1 += 2 + 1d(60/(level+2) + 1)
	ld a,(iy+K_LEVEL)
	add a,2
	ld c,a
	ld a,60
	call div8
	inc a
	call randint
	add a,2
	add a,(ix+I_PVAL)
	ld (ix+I_PVAL),a
	res ID_KNOWN2_BIT,(ix+I_IDENT)		; how many is no longer known
	res ID_EMPTY_BIT,(ix+I_IDENT)
	ret

; ---------------------------------------------------------------- 38-42

sc_bless:
	ld bc,6*256+12
	jr blessing
sc_chant:
	ld bc,12*256+24
	jr blessing
sc_prayer:
	ld bc,24*256+48
blessing:
	call ident
	ld hl,p_blessed
	jp add_rand

sc_recall:
	call ident
	ld hl,p_word_recall
	call get_w
	jr nz,.charged
	ld bc,25*256+30
	call add_rand
.charged:
	ld hl,msg_air_charged
	jp msg_print

/* sc_destruction - destroy_area: within 15 squares the dungeon is torn
	up; then a blinding flash */
sc_destruction:
	call ident
	ld a,(dun_level)
	or a
	jr z,.flash
	ld a,-15
	ld (ds_dy),a
.row:
	ld a,-15
	ld (ds_dx),a
.col:
	ld a,(ds_dy)
	or a
	jr nz,.not_here
	ld a,(ds_dx)
	or a
	jr z,.next							; (not the player's square)
.not_here:
	ld a,(player_y)
	ld hl,ds_dy
	add a,(hl)
	ld d,a
	ld a,(player_x)
	ld hl,ds_dx
	add a,(hl)
	ld e,a
	call in_bounds
	jr nc,.next
	push de
	call map_addr
	pop de
	ld a,(hl)
	and TERRAIN_MASK
	cp T_PERMWALL
	jr z,.next
	push de
	call mon_distance
	pop de
	ld c,6
	cp 13
	jr c,.replace
	ld c,9
	cp 16
	jr nc,.next
.replace:
	ld a,c
	call randint
	call replace_spot
.next:
	ld hl,ds_dx
	inc (hl)
	ld a,(hl)
	cp 16
	jr nz,.col
	ld hl,ds_dy
	inc (hl)
	ld a,(hl)
	cp 16
	jr nz,.row
.flash:
	ld hl,msg_searing
	call msg_print
	ld a,(p_race)
	cp RACE_DWARF
	ret z
	ld hl,p_blind
	ld bc,10*256+10
	jp add_rand

/* replace_spot - D = y, E = x, A = 1-9: floor (1-3) or granite, magma,
	quartz; forgotten, no longer a room, and emptied */
replace_spot:
	ld b,T_CORRIDOR
	cp 4
	jr c,.set
.mod:
	sub 3
	cp 4
	jr nc,.mod
	ld hl,replace_walls-1
	add hl,a
	ld b,(hl)
.set:
	push de
	call map_addr
	pop de
	ld a,(hl)
	and F_LAMP|F_MON
	or b
	ld (hl),a
	push hl
	push de
	call item_at
	jr nc,.no_item
	ld (ix+I_KIND_HI),ITEM_EMPTY
.no_item:
	pop de
	pop hl
	bit F_MON_BIT,(hl)
	ret z
	call mon_at
	ret nc
	jp mon_remove
replace_walls:	db T_GRANITE,T_MAGMA,T_QUARTZ

; ---------------------------------------------------------------- text

msg_identify_scroll: db "This is an identify scroll.",0
msg_recharge_scroll: db "This is a Recharge-Item scroll.",0
msg_nothing_to_charge: db "You have nothing to recharge.",0
txt_recharge_which:	db "Recharge which item? (letter, or space)",0
msg_bright_flash:	db "There is a bright flash of light.",0
txt_ident_which:	db "Item you wish identified? (letter, or space)",0
msg_white_light:	db "You are surrounded by a white light.",0
msg_darkness:		db "Darkness surrounds you.",0
msg_hands_glow:		db "Your hands begin to glow.",0
msg_mass_genocide:	db "This is a mass genocide scroll.",0
msg_genocide:		db "This is a genocide scroll.",0
txt_genocide_which:	db "Which type of creature do you wish exterminated?",0
txt_unaffected:		db " is unaffected.",0
msg_sense_invisible: db "You sense the presence of invisible creatures!",0
msg_stirring:		db "You hear a sudden stirring in the distance!",0
msg_humming:		db "There is a high pitched humming noise.",0
txt_dissolves:		db " dissolves!",0
txt_shudders:		db " shudders.",0
msg_object_under:	db "There is already an object under you.",0
msg_roll_beneath:	db "You feel something roll beneath your feet.",0
msg_air_charged:	db "The air about you becomes charged.",0
msg_searing:		db "There is a searing blast of light!",0

; ---------------------------------------------------------------- variables

r_base:			db 0
r_flags:		dd 0
r_bit:			db 0
r_used:			db 0
r_slot:			db 0
r_kind:			dw 0
r_any:			db 0
r_k:			db 0
r_gold:			db 0
r_char:			db 0
r_seen:			db 0
r_summoner:		dw 0
tp_dis:			dw 0
tp_count:		dw 0
tp_y:			db 0
tp_x:			db 0
mp_y0:			db 0
mp_y1:			db 0
mp_x0:			db 0
mp_x1:			db 0
dk_head:		dw 0
dk_tail:		dw 0
ds_dy:			db 0
ds_dx:			db 0
