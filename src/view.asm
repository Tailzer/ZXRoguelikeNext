/* view.asm - draws the visible part of the map and the status line
	Reference: MORIA1.C/IO.C (panels, prt_map), MISC1.C (prt_stat etc.)
 */

/* update_view - recentre the view on an axis when the player gets within
	the scroll margin of its edge (like Angband's panel shifting) */
update_view:
	ld a,(view_x)
	ld b,a
	ld a,(player_x)
	sub b
	jr c,.centre_x
	cp SCROLL_MARGIN_X
	jr c,.centre_x
	cp VIEW_W-SCROLL_MARGIN_X
	jr c,.check_y
.centre_x:
	ld a,(player_x)
	sub VIEW_W/2
	jr nc,.x_low_ok
	xor a
.x_low_ok:
	cp MAP_W-VIEW_W+1
	jr c,.x_high_ok
	ld a,MAP_W-VIEW_W
.x_high_ok:
	ld (view_x),a
.check_y:
	ld a,(view_y)
	ld b,a
	ld a,(player_y)
	sub b
	jr c,.centre_y
	cp SCROLL_MARGIN_Y
	jr c,.centre_y
	cp VIEW_H-SCROLL_MARGIN_Y
	ret c
.centre_y:
	ld a,(player_y)
	sub VIEW_H/2
	jr nc,.y_low_ok
	xor a
.y_low_ok:
	cp MAP_H-VIEW_H+1
	jr c,.y_high_ok
	ld a,MAP_H-VIEW_H
.y_high_ok:
	ld (view_y),a
	ret

/* draw_view - redraw every map cell in the view, then the player */
draw_view:
	call update_view
	ld de,TILEMAP_BASE+VIEW_TOP*SCREEN_W*2
	ld a,(view_y)
	ld c,a								; C = map y
	ld a,VIEW_H
.row:
	push af
	push de
	ld d,c
	ld a,(view_x)
	ld e,a
	call map_addr
	pop de
	push hl
	pop ix								; IX = map square
	ld b,VIEW_W
.col:
	ld a,(ix+0)
	inc ix
	ld l,a
	and F_SEEN
	jr z,.unknown
	ld a,l
	and TERRAIN_MASK
	add a,a
	add a,a
	ld hl,terrain_table
	add hl,a
	ld a,(hl)							; character
	ld (de),a
	inc de
	inc hl
	ld a,(hl)							; attribute
	ld (de),a
	inc de
	djnz .col
	jr .row_done
.unknown:
	ld a,' '
	ld (de),a
	inc de
	xor a
	ld (de),a
	inc de
	djnz .col
.row_done:
	inc c
	pop af
	dec a
	jr nz,.row

	call draw_items						; items, under any monsters
	ld a,(dun_level)
	or a
	call z,draw_store_doors

	; visible monsters
	ld ix,MON_LIST
	ld b,MON_MAX
.monster:
	push bc
	ld a,(ix+M_RACE_HI)
	cp MON_EMPTY
	jr z,.next_monster
	ld a,(ix+M_ML)
	or a
	jr z,.next_monster
	ld a,(view_y)
	ld b,a
	ld a,(ix+M_Y)
	sub b
	cp VIEW_H
	jr nc,.next_monster
	add a,VIEW_TOP
	ld d,a
	ld a,(view_x)
	ld b,a
	ld a,(ix+M_X)
	sub b
	cp VIEW_W
	jr nc,.next_monster
	ld e,a
	call screen_addr
	push hl
	call mon_race						; (uses HL)
	pop hl
	ld a,(iy+R_CHAR)
	ld (hl),a
	inc hl
	ld a,(iy+R_ATTR)
	ld (hl),a
.next_monster:
	ld de,MON_SIZE
	add ix,de
	pop bc
	djnz .monster

	; player
	ld a,(view_y)
	ld b,a
	ld a,(player_y)
	sub b
	add a,VIEW_TOP
	ld d,a
	ld a,(view_x)
	ld b,a
	ld a,(player_x)
	sub b
	ld e,a
	call screen_addr
	ld (hl),'@'
	inc hl
	ld (hl),ATTR_YELLOW
	ret

/* draw_store_doors - the town's doors show their store numbers 1-8 */
draw_store_doors:
	ld hl,STORE_DOOR
	ld b,0
.each:
	push bc
	push hl
	ld d,(hl)
	inc hl
	ld e,(hl)
	push de
	call map_addr
	pop de
	ld a,(hl)
	and F_SEEN
	jr z,.next
	ld a,(view_y)
	ld c,a
	ld a,d
	sub c
	cp VIEW_H
	jr nc,.next
	add a,VIEW_TOP
	ld d,a
	ld a,(view_x)
	ld c,a
	ld a,e
	sub c
	cp VIEW_W
	jr nc,.next
	ld e,a
	call screen_addr
	pop de
	pop bc
	push bc
	push de
	ld a,b
	add a,'1'
	ld (hl),a
	inc hl
	ld (hl),ATTR_WHITE
.next:
	pop hl
	pop bc
	inc hl
	inc hl
	inc b
	ld a,b
	cp NUM_STORES
	jr c,.each
	ret

/* draw_status - bottom line: level, experience, hit points, depth */
draw_status:
	ld d,STATUS_ROW
	call clear_row
	ld hl,txt_lev
	ld d,STATUS_ROW
	ld e,0
	ld c,ATTR_GREY
	call print_at
	ld a,(p_lev)
	call print_u8
	ld hl,txt_exp
	call print_str
	ld hl,p_exp
	call print_u32
	ld hl,txt_hp
	call print_str
	ld c,ATTR_WHITE						; hit points in yellow when low
	ld hl,(p_chp)
	add hl,hl
	add hl,hl
	ld a,(p_mhp)
	push de
	ld e,a
	ld a,(p_mhp+1)
	ld d,a
	or a
	sbc hl,de							; 4*chp < mhp?
	pop de
	jr nc,$+4
	ld c,ATTR_YELLOW
	ld hl,(p_chp)
	bit 7,h
	jr z,$+5
	ld hl,0
	call print_u16
	ld c,ATTR_GREY
	ld hl,txt_slash
	call print_str
	ld hl,(p_mhp)
	call print_u16
	ld hl,txt_gold
	call print_str
	ld hl,p_gold
	call print_u32
	ld a,(dun_level)
	or a
	ld hl,txt_town
	jr z,.depth_done
	ld hl,txt_depth
	call print_str
	push de
	ld a,(dun_level)					; 50 feet per level
	ld d,a
	ld e,50
	mul d,e
	ex de,hl
	pop de
	call print_u16
	ld hl,txt_feet
.depth_done:
	call print_str
	ld a,(p_hunger)						; Hungry / Weak
	or a
	jr z,.fed
	ld hl,txt_hungry
	ld c,ATTR_YELLOW
	cp HUNGER_HUNGRY
	jr z,.hunger
	ld hl,txt_weak
	ld c,ATTR_RED
.hunger:
	call print_str
.fed:
	ld hl,txt_keys
	ld d,STATUS_ROW
	ld e,SCREEN_W-txt_keys_len
	ld c,ATTR_DARK
	jp print_at
