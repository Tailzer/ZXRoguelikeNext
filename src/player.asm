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
	push de
	call lamp_off
	pop de
	ld a,e
	ld (player_x),a
	ld a,d
	ld (player_y),a
	jp light_arrive
.blocked:
	ld a,b
	cp T_DOOR_CLOSED
	jr nz,.wall
	ld a,(hl)							; keep the square's flags
	and ~TERRAIN_MASK
	or T_DOOR_OPEN
	ld (hl),a
	ld hl,msg_door_open
	jp show_message
.wall:
	ld hl,msg_wall
	jp show_message

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
	ld a,(dun_level)
	cp 1
	jr z,.no_town
	ld hl,dun_level
	dec (hl)
	call new_level
	ld hl,msg_up
	jp show_message
.no_town:
	ld hl,msg_no_town
	jp show_message
.none:
	ld hl,msg_no_up
	jp show_message

/* new_level - generate a level for dun_level and drop the player in it */
new_level:
	ld hl,msg_generating
	call show_message
	call rng_mix
	call generate_level
	call random_open_spot
	ld a,d
	ld (player_y),a
	ld a,e
	ld (player_x),a
	jp light_arrive
