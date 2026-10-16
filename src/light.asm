/* light.asm - what the player can see
	Angband 1.2 uses Moria's model (MORIA1.C, MORIA2.C move_char):
		- the player's light covers the 3x3 squares around them (F_LAMP);
		  walls, doors and stairs it touches are remembered (F_PERM)
		- stepping into a lit room lights the whole room for good (F_PERM)
		- dark floor is only seen while your light is on it
	A square is drawn if F_PERM or F_LAMP is set.
 */

/* lamp_origin - HL = square up-left of the player. Clobbers A, DE */
lamp_origin:
	ld a,(player_y)
	dec a
	ld d,a
	ld a,(player_x)
	dec a
	ld e,a
	jp map_addr

/* lamp_off - take the player's light off the 3x3 around them */
lamp_off:
	call lamp_origin
	ld de,MAP_W-3
	ld c,3
.row:
	ld b,3
.col:
	res F_LAMP_BIT,(hl)
	inc hl
	djnz .col
	add hl,de
	dec c
	jr nz,.row
	ret

/* lamp_on - light the 3x3 around the player, remembering walls/doors/stairs */
lamp_on:
	call lamp_origin
	ld de,MAP_W-3
	ld c,3
.row:
	ld b,3
.col:
	set F_LAMP_BIT,(hl)
	ld a,(hl)
	and TERRAIN_MASK
	call terrain_flags
	bit TF_REMEMBER,a
	jr z,.next
	set F_PERM_BIT,(hl)
.next:
	inc hl
	djnz .col
	add hl,de
	dec c
	jr nz,.row
	ret

/* light_arrive - the player has just arrived on their square:
	light the room if it's a lit room (or a doorway into one), then the lamp */
light_arrive:
	call player_square
	ld a,(hl)
	and TERRAIN_MASK
	cp T_FLOOR_LIT
	jr nz,.doorway
	bit F_PERM_BIT,(hl)
	call z,light_room
	jr .lamp
.doorway:
	bit F_ROOM_BIT,(hl)
	jr z,.lamp
	ld de,-MAP_W-1						; any unlit lit-room floor next to us?
	add hl,de
	ld c,3
.row:
	ld b,3
.col:
	ld a,(hl)
	and TERRAIN_MASK|F_PERM
	cp T_FLOOR_LIT
	jr nz,.next
	push bc
	push hl
	call light_room
	pop hl
	pop bc
.next:
	inc hl
	djnz .col
	ld de,MAP_W-3
	add hl,de
	dec c
	jr nz,.row
.lamp:
	jp lamp_on

/* light_room - HL = a square in a room. Flood fill through the room's open
	squares, marking every room square reached (floor, walls, doors) F_PERM.
	F_PERM doubles as the 'visited' mark, so each square is queued once.
	Reference: MORIA1.C light_room / flood_light / flood_permanent */
light_room:
	bit F_ROOM_BIT,(hl)
	ret z
	set F_PERM_BIT,(hl)
	ld de,LIGHT_QUEUE
	ex de,hl
	ld (hl),e
	inc hl
	ld (hl),d
	inc hl
	ld (queue_tail),hl
	ld hl,LIGHT_QUEUE
	ld (queue_head),hl
.loop:
	ld hl,(queue_head)
	ld de,(queue_tail)
	or a
	sbc hl,de
	ret z								; queue empty
	ld hl,(queue_head)
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld (queue_head),hl
	ex de,hl							; HL = square
	ld a,(hl)
	and TERRAIN_MASK
	call terrain_flags
	bit TF_PASSABLE,a
	jr z,.loop							; walls and closed doors stop the light
	ld ix,neighbour_offsets
	ld b,8
.neighbour:
	push bc
	push hl
	ld e,(ix+0)
	ld d,(ix+1)
	add hl,de
	ld a,(hl)
	and F_ROOM|F_PERM
	cp F_ROOM
	jr nz,.skip							; not room, or already lit
	set F_PERM_BIT,(hl)
	ex de,hl							; DE = neighbour
	ld hl,(queue_tail)
	ld bc,LIGHT_QUEUE+LIGHT_QUEUE_MAX*2
	or a
	sbc hl,bc
	jr nc,.skip							; queue full (never for real rooms)
	add hl,bc
	ld (hl),e
	inc hl
	ld (hl),d
	inc hl
	ld (queue_tail),hl
.skip:
	pop hl
	pop bc
	inc ix
	inc ix
	djnz .neighbour
	jp .loop

neighbour_offsets:
	dw -MAP_W-1,-MAP_W,-MAP_W+1,-1,1,MAP_W-1,MAP_W,MAP_W+1

queue_head:		dw 0
queue_tail:		dw 0
