/* player.asm - player actions
	Reference: MORIA2.C move_char(), MORIA1.C
 */

/* try_move - B = dx, C = dy. Moves if the square is passable; bumping a
	closed door opens it (Angband's easy_open behaviour) */
try_move:
	ld a,(player_x)
	add a,b
	ld e,a
	ld a,(player_y)
	add a,c
	ld d,a
	push de
	call map_addr						; HL = target square
	pop de
	ld a,(hl)
	and TERRAIN_MASK
	ld b,a								; B = terrain id
	call terrain_flags
	bit TF_PASSABLE,a
	jr z,.blocked
	bit F_MON_BIT,(hl)
	jr nz,.monster
	ld a,1
	ld (turn_taken),a
	push de
	call lamp_off
	pop de
	ld a,e
	ld (player_x),a
	ld a,d
	ld (player_y),a
	call light_arrive
	call player_square					; a store's door: go in
	ld a,(hl)
	and TERRAIN_MASK
	cp T_STORE
	jr nz,.items
	call store_here
	FARCALL PAGE_STORE, enter_store
	ret
.items:
	ld a,(player_y)						; walked onto something: pick it up
	ld d,a
	ld a,(player_x)
	ld e,a
	call item_at
	ret nc
	FARCALL PAGE_ITEMS, carry_here
	ret
.blocked:
	ld a,b
	cp T_DOOR_CLOSED
	jr nz,.wall
	ld a,(hl)							; keep the square's flags
	and ~TERRAIN_MASK
	or T_DOOR_OPEN
	ld (hl),a
	ld a,1
	ld (turn_taken),a
	ld hl,msg_door_open
	jp show_message
.wall:
	ld hl,msg_wall
	jp show_message
.monster:
	call mon_at
	jp py_attack

/* store_here - A = the store whose door the player is on */
store_here:
	ld hl,STORE_DOOR
	ld a,(player_y)
	ld d,a
	ld a,(player_x)
	ld e,a
	ld b,0
.each:
	ld a,(hl)
	inc hl
	cp d
	jr nz,.next
	ld a,(hl)
	cp e
	jr z,.found
.next:
	inc hl
	inc b
	ld a,b
	cp NUM_STORES
	jr c,.each
.found:
	ld a,b
	ret

/* player_square - HL = map square under the player. Clobbers A, DE */
player_square:
	ld a,(player_y)
	ld d,a
	ld a,(player_x)
	ld e,a
	jp map_addr

/* go_down - '>' command */
go_down:
	call player_square
	ld a,(hl)
	and TERRAIN_MASK
	cp T_STAIR_DOWN
	jr nz,.none
	ld hl,dun_level
	inc (hl)
	call new_level
	ld hl,msg_down
	jp show_message
.none:
	ld hl,msg_no_down
	jp show_message

/* go_up - '<' command */
go_up:
	call player_square
	ld a,(hl)
	and TERRAIN_MASK
	cp T_STAIR_UP
	jr nz,.none
	ld hl,dun_level
	dec (hl)
	call new_level
	ld hl,msg_up
	jp show_message
.none:
	ld hl,msg_no_up
	jp show_message

/* new_level - generate a level for dun_level (0 = the town) and drop the
	player in it */
new_level:
	ld hl,msg_generating
	call show_message
	call rng_mix
	ld a,(dun_level)
	or a
	jr z,.town
	FARCALL PAGE_LEVEL, generate_level
	call msg_clear
	call random_open_spot
	ld a,d
	ld (player_y),a
	ld a,e
	ld (player_x),a
	call light_arrive
	FARCALL PAGE_LEVEL, alloc_monsters
	FARCALL PAGE_LEVEL, alloc_items
	call update_view
	jp monsters_see_all
.town:
	FARCALL PAGE_LEVEL, town_gen
	call msg_clear
	FARCALL PAGE_STORE, store_maint		; the stores restock
	call items_clear					; nothing lying about in town
	call random_open_spot
	ld a,d
	ld (player_y),a
	ld a,e
	ld (player_x),a
	call light_arrive
	FARCALL PAGE_LEVEL, alloc_town_monsters
	call update_view
	jp monsters_see_all
