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

/* draw_status - bottom line: depth, position, key help */
draw_status:
	ld d,STATUS_ROW
	call clear_row
	ld hl,txt_depth
	ld d,STATUS_ROW
	ld e,0
	ld c,ATTR_GREY
	call print_at
	push de
	ld a,(dun_level)					; 50 feet per level
	ld d,a
	ld e,50
	mul d,e
	ex de,hl
	pop de
	call print_u16
	ld hl,txt_feet
	call print_str
	ld hl,txt_pos_x
	call print_str
	ld a,(player_x)
	call print_u8
	ld hl,txt_pos_y
	call print_str
	ld a,(player_y)
	call print_u8
	ld hl,txt_keys
	ld d,STATUS_ROW
	ld e,SCREEN_W-txt_keys_len
	ld c,ATTR_DARK
	jp print_at
