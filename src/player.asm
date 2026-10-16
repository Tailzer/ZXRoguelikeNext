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
	ld b,a								; B = terrain id
	push hl
	add a,a
	add a,a
	ld hl,terrain_table+2				; flags byte
	add hl,a
	ld a,(hl)
	pop hl
	bit TF_PASSABLE,a
	jr z,.blocked
	ld a,e
	ld (player_x),a
	ld a,d
	ld (player_y),a
	ret
.blocked:
	ld a,b
	cp T_DOOR_CLOSED
	jr nz,.wall
	ld (hl),T_DOOR_OPEN
	ld hl,msg_door_open
	jp show_message
.wall:
	ld hl,msg_wall
	jp show_message
