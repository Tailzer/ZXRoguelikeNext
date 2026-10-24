/* generate.asm - dungeon level generator
	A close port of cave_gen() from GENERATE.C:
		random rooms on a 6x6 grid, shuffled and joined by wandering tunnels,
		doors where tunnels pierce room walls and at junctions,
		magma/quartz streamers, permanent outer wall, then stairs.
	The unusual rooms (types 2, 3, 5 and pits) are rooms.asm's.
	[overlay: PAGE_LEVEL]
 */

/* is_wall - A = terrain -> NZ if it counts as wall. Preserves HL */
is_wall:
	push hl
	add a,a
	add a,a
	ld hl,terrain_table+2
	add hl,a
	ld a,(hl)
	pop hl
	and 1<<TF_WALL
	ret

/* carve_rect - E = x, D = y, B = width, C = height, A = terrain */
carve_rect:
	ld (carve_terrain),a
.row:
	push bc
	push de
	call map_addr
	ld a,(carve_terrain)
.col:
	ld (hl),a
	inc hl
	djnz .col
	pop de
	pop bc
	inc d
	dec c
	jr nz,.row
	ret

/* carve_list - HL = list of x, y, w, h, terrain; ends with $FF */
carve_list:
	ld a,(hl)
	cp $FF
	ret z
	ld e,a
	inc hl
	ld d,(hl)
	inc hl
	ld b,(hl)
	inc hl
	ld c,(hl)
	inc hl
	ld a,(hl)
	inc hl
	push hl
	call carve_rect
	pop hl
	jr carve_list

/* next_to_walls - HL = square -> A = walls in the 4 orthogonal squares.
	Preserves DE, HL. Clobbers C */
next_to_walls:
	push de
	push hl
	ld c,0
	ld de,-MAP_W
	add hl,de							; north
	ld a,(hl)
	call is_wall
	jr z,$+3
	inc c
	ld de,MAP_W*2
	add hl,de							; south
	ld a,(hl)
	call is_wall
	jr z,$+3
	inc c
	ld de,-MAP_W-1
	add hl,de							; west
	ld a,(hl)
	call is_wall
	jr z,$+3
	inc c
	inc hl
	inc hl								; east
	ld a,(hl)
	call is_wall
	jr z,$+3
	inc c
	pop hl
	pop de
	ld a,c
	ret


/* generate_level - build a new level for dun_level */
generate_level:
	OVCALL PAGE_TRAP, doors_clear, PAGE_LEVEL
	call mon_clear_all					; (rooms may put monsters, objects
	call items_clear					;  and traps in as they're built)
	ld hl,TRAP_LIST
	ld b,TRAP_MAX*TRAP_SIZE
.no_traps:
	ld (hl),0
	inc hl
	djnz .no_traps
	ld a,1
	ld (pit_ok),a
	ld a,3								; stairs like corridor ends
	ld (stair_wall_start),a
	; blank cave
	ld hl,MAP_BASE
	ld de,MAP_BASE+1
	ld bc,MAP_W*MAP_H-1
	ld (hl),T_NULL
	ldir

	; choose which room slots get a room
	ld hl,ROOM_MAP
	ld b,ROOM_ROWS*ROOM_COLS
.clear_slots:
	ld (hl),0
	inc hl
	djnz .clear_slots
	ld a,6
	call randint
	add a,DUN_ROOMS_MIN
	ld b,a
.pick_slot:
	push bc
	ld a,ROOM_ROWS*ROOM_COLS
	call randint
	dec a
	ld hl,ROOM_MAP
	add hl,a
	ld (hl),1
	pop bc
	djnz .pick_slot

	; build a room in each chosen slot, remembering its centre
	xor a
	ld (room_count),a
	ld (gen_row),a
.slot_row:
	xor a
	ld (gen_col),a
.slot_col:
	ld a,(gen_row)
	ld d,a
	ld e,ROOM_COLS
	mul d,e
	ld a,(gen_col)
	add a,e
	ld hl,ROOM_MAP
	add hl,a
	ld a,(hl)
	or a
	jr z,.no_room
	ld a,(gen_row)						; yval = row * 11 + 5
	ld d,a
	ld e,11
	mul d,e
	ld a,e
	add a,5
	ld (room_yval),a
	ld a,(gen_col)						; xval = col * 33 + 16
	ld d,a
	ld e,33
	mul d,e
	ld a,e
	add a,16
	ld (room_xval),a
	ld a,(room_count)
	add a,a
	ld hl,ROOM_LIST
	add hl,a
	ld a,(room_yval)
	ld (hl),a
	inc hl
	ld a,(room_xval)
	ld (hl),a
	ld hl,room_count
	inc (hl)
	call build_room
.no_room:
	ld hl,gen_col
	inc (hl)
	ld a,(hl)
	cp ROOM_COLS
	jr c,.slot_col
	ld hl,gen_row
	inc (hl)
	ld a,(hl)
	cp ROOM_ROWS
	jr c,.slot_row

	; shuffle the room order
	ld a,(room_count)
	ld b,a
.shuffle:
	push bc
	ld a,(room_count)
	call randint
	dec a
	add a,a
	ld hl,ROOM_LIST
	add hl,a
	push hl
	ld a,(room_count)
	call randint
	dec a
	add a,a
	ld hl,ROOM_LIST
	add hl,a
	pop de
	ld a,(de)
	ld c,(hl)
	ld (hl),a
	ld a,c
	ld (de),a
	inc hl
	inc de
	ld a,(de)
	ld c,(hl)
	ld (hl),a
	ld a,c
	ld (de),a
	pop bc
	djnz .shuffle

	; copy the first room to the end, so every room gets a tunnel
	ld a,(room_count)
	add a,a
	ld hl,ROOM_LIST
	add hl,a
	ex de,hl
	ld hl,ROOM_LIST
	ldi
	ldi

	; tunnel from each room to the previous one
	ld hl,0
	ld (door_list),hl
	xor a
	ld (gen_row),a
.tunnels:
	ld a,(gen_row)
	add a,a
	ld hl,ROOM_LIST
	add hl,a
	ld a,(hl)
	ld (tun_ty),a
	inc hl
	ld a,(hl)
	ld (tun_tx),a
	inc hl
	ld a,(hl)
	ld (tun_y),a
	inc hl
	ld a,(hl)
	ld (tun_x),a
	call build_tunnel
	ld hl,gen_row
	inc (hl)
	ld a,(room_count)
	cp (hl)
	jr nz,.tunnels

	call fill_cave
	ld b,DUN_STR_MAG
.magma:
	push bc
	ld a,T_MAGMA
	call place_streamer
	pop bc
	djnz .magma
	ld b,DUN_STR_QUA
.quartz:
	push bc
	ld a,T_QUARTZ
	call place_streamer
	pop bc
	djnz .quartz
	ld hl,boundary_rects
	call carve_list
	call junction_doors

	; 3-4 down staircases, 1-2 up
	ld a,2
	call randint
	add a,2
	ld b,a
	ld a,T_STAIR_DOWN
	call place_stairs
	ld a,2
	call randint
	ld b,a
	ld a,T_STAIR_UP
	call place_stairs
	; fall through
/* mark_rooms - every room floor square and its 8 neighbours (walls,
	doors, doorways) get F_ROOM, as build_room sets lr in the C */
mark_rooms:
	ld hl,MAP_BASE+MAP_W
	ld bc,MAP_W*(MAP_H-2)
.loop:
	ld a,(hl)
	and TERRAIN_MASK
	cp T_FLOOR
	jr z,.room
	cp T_FLOOR_LIT
	jr nz,.next
.room:
	push hl
	ld de,-MAP_W-1
	add hl,de
	call .mark3
	ld de,MAP_W-3
	add hl,de
	call .mark3
	add hl,de
	call .mark3
	pop hl
.next:
	inc hl
	dec bc
	ld a,b
	or c
	jr nz,.loop
	ret
.mark3:
	set F_ROOM_BIT,(hl)
	inc hl
	set F_ROOM_BIT,(hl)
	inc hl
	set F_ROOM_BIT,(hl)
	inc hl
	ret

/* build_room - room centred on room_yval, room_xval, in slot (gen_row,
	gen_col). Deeper levels (level > 1d200) sometimes get an unusual one:
	1d5 picks overlapping rectangles (type 1, here), an inner room (2), a
	cross (3) or, deeper again, a vault (5, which takes the slots beside and
	below it); else, deeper again, the level's one monster pit (rooms.asm) */
build_room:
	ld a,25								; lit if dun_level <= 1d25
	call randint
	ld b,a
	ld a,(dun_level)
	cp b
	ld a,T_FLOOR_LIT
	jr z,.lit
	jr c,.lit
	ld a,T_FLOOR
.lit:
	ld (room_floor),a
	call .deeper						; unusual if dun_level > 1d200
	jp nc,.normal
	ld a,5
	call randint
	cp 2
	jp c,.type1
	cp 4
	jr c,.unusual						; 2, 3
	jr nz,.pit_or_not					; 5
	call .deeper						; 4: a vault, deeper again
	jr nc,.pit_or_not
	call .take_slots
	ld a,5
	jr .unusual
.pit_or_not:
	call .deeper
	jr nc,.normal
	ld a,(pit_ok)
	or a
	jr z,.normal
	xor a
	ld (pit_ok),a
	ld a,6
.unusual:
	ld hl,(room_yval)					; (room_yval, room_xval)
	ld d,l
	ld e,h
	ld hl,room_floor
	ld l,(hl)
	OVCALL PAGE_ROOMS, build_unusual, PAGE_LEVEL
	ret
.deeper:								; carry if dun_level > 1d200
	ld a,DUN_UNUSUAL
	call randint
	ld b,a
	ld a,(dun_level)
	cp b
	ccf
	ret nc
	ret nz
	or a
	ret
.take_slots:							; a vault takes the slots to the
	ld a,(gen_row)						; right and below
	ld d,a
	ld e,ROOM_COLS
	mul d,e
	ld a,(gen_col)
	add a,e
	ld hl,ROOM_MAP
	add hl,a							; HL = this slot
	ld a,(gen_col)
	cp ROOM_COLS-1
	jr nc,.below
	inc hl
	ld (hl),0							; right
	dec hl
.below:
	ld a,(gen_row)
	cp ROOM_ROWS-1
	ret nc
	ld de,ROOM_COLS
	add hl,de
	ld (hl),0							; below
	ld a,(gen_col)
	cp ROOM_COLS-1
	jr nc,$+5
	inc hl
	ld (hl),0							; below right
	dec hl
	ld a,(gen_col)
	or a
	ret z
	dec hl
	ld (hl),0							; below left
	ret
.type1:
	ld a,2
	call randint
	inc a
	ld b,a
.overlap:
	push bc
	call room_rect
	pop bc
	djnz .overlap
	ret
.normal:
	call room_rect
	ld a,20
	call randint
	cp 2
	ret nz								; 1 in 20 rooms get pillars
	ld a,(r_top)
	ld (pillar_y),a
.pillar_row:
	ld a,(r_left)
	ld (pillar_x),a
.pillar_col:
	ld a,(pillar_y)
	ld d,a
	ld a,(pillar_x)
	ld e,a
	call map_addr
	ld (hl),T_TMP1
	ld a,(pillar_x)
	add a,2
	ld (pillar_x),a
	ld b,a
	ld a,(r_right)
	cp b
	jr nc,.pillar_col
	ld a,(pillar_y)
	add a,2
	ld (pillar_y),a
	ld b,a
	ld a,(r_bottom)
	cp b
	jr nc,.pillar_row
	ret

/* room_rect - one random rectangle of floor around room_yval/xval,
	with a granite ring wherever there is not already floor */
room_rect:
	ld a,4
	call randint
	ld b,a
	ld a,(room_yval)
	sub b
	ld (r_top),a
	ld a,3
	call randint
	ld b,a
	ld a,(room_yval)
	add a,b
	ld (r_bottom),a
	ld a,11
	call randint
	ld b,a
	ld a,(room_xval)
	sub b
	ld (r_left),a
	ld a,11
	call randint
	ld b,a
	ld a,(room_xval)
	add a,b
	ld (r_right),a

	ld a,(r_top)
	ld d,a
	ld a,(r_left)
	ld e,a
	ld a,(r_right)
	sub e
	inc a
	ld b,a
	ld a,(r_bottom)
	sub d
	inc a
	ld c,a
	ld a,(room_floor)
	call carve_rect

	ld a,(r_top)
	dec a
	ld d,a
	ld a,(r_left)
	dec a
	ld e,a
	ld a,(r_right)
	sub e
	add a,2
	ld b,a
	ld a,(r_bottom)
	sub d
	add a,2
	ld c,a
	; fall through
/* wall_rect - E = x, D = y, B = width, C = height: granite on non-floor */
wall_rect:
.row:
	push bc
	push de
	call map_addr
.col:
	ld a,(hl)
	cp T_FLOOR
	jr z,.keep
	cp T_FLOOR_LIT
	jr z,.keep
	ld (hl),T_GRANITE
.keep:
	inc hl
	djnz .col
	pop de
	pop bc
	inc d
	dec c
	jr nz,.row
	ret

/* build_tunnel - dig from tun_y,tun_x towards tun_ty,tun_tx.
	Walks through rock and rooms; where it breaks through a room wall the
	wall square is remembered and later becomes a doorway or door. */
build_tunnel:
	xor a
	ld (stop_flag),a
	ld (door_flag),a
	ld hl,0
	ld (tun_steps),hl
	ld (tun_list),hl
	ld (wall_list),hl
	ld a,(tun_y)
	ld (tun_sy),a
	ld a,(tun_x)
	ld (tun_sx),a
	call correct_dir
.loop:
	ld hl,(tun_steps)
	inc hl
	ld (tun_steps),hl
	ld de,TUN_STEPS_MAX
	or a
	sbc hl,de
	jr c,.steps_ok
	ld a,1
	ld (stop_flag),a
.steps_ok:
	ld a,100
	call randint
	cp DUN_TUN_CHG+1
	jr c,.step
	call change_dir
.step:
	ld a,(row_dir)
	ld hl,tun_y
	add a,(hl)
	ld d,a
	ld a,(col_dir)
	ld hl,tun_x
	add a,(hl)
	ld e,a
	call in_bounds
	jr c,.inside
	call change_dir
	jr .step
.inside:
	push de
	call map_addr
	pop de
	ld a,(hl)
	cp T_NULL
	jr z,.rock
	cp T_TMP2
	jp z,.next							; never dig next to a pierced wall
	cp T_GRANITE
	jr z,.room_wall
	cp T_CORRIDOR
	jr z,.corridor
	cp T_DOOR_CLOSED
	jr z,.corridor
	cp T_DOOR_OPEN
	jr z,.corridor
	cp T_DOOR_SECRET
	jr z,.corridor
	call .move							; floor, pillar: walk through
	jp .next

.rock:
	call .move
	ld ix,tun_list
	call list_push
	xor a
	ld (door_flag),a
	jp .next

.room_wall:
	call .move
	ld ix,wall_list
	call list_push
	call mark_pierced
	jp .next

.corridor:
	call .move
	ld a,(door_flag)
	or a
	jr nz,.joined
	ld ix,door_list
	call list_push
	ld a,1
	ld (door_flag),a
.joined:
	ld a,100
	call randint
	cp DUN_TUN_CON+1
	jr c,.next
	ld a,(tun_sy)						; stop if we've come far enough
	ld b,a
	ld a,(tun_y)
	sub b
	jr nc,$+4
	neg
	cp 11
	jr nc,.stop
	ld a,(tun_sx)
	ld b,a
	ld a,(tun_x)
	sub b
	jr nc,$+4
	neg
	cp 11
	jr c,.next
.stop:
	ld a,1
	ld (stop_flag),a

.next:
	ld a,(stop_flag)
	or a
	jr nz,.dig
	ld a,(tun_ty)
	ld b,a
	ld a,(tun_y)
	cp b
	jp nz,.loop
	ld a,(tun_tx)
	ld b,a
	ld a,(tun_x)
	cp b
	jp nz,.loop

.dig:
	ld hl,TUN_STACK
	ld bc,(tun_list)
.dig_loop:
	ld a,b
	or c
	jr z,.doorways
	ld d,(hl)
	inc hl
	ld e,(hl)
	inc hl
	push hl
	push bc
	call map_addr
	ld (hl),T_CORRIDOR
	pop bc
	pop hl
	dec bc
	jr .dig_loop

.doorways:
	ld hl,WALL_STACK
	ld bc,(wall_list)
.door_loop:
	ld a,b
	or c
	ret z
	ld d,(hl)
	inc hl
	ld e,(hl)
	inc hl
	push hl
	push bc
	call map_addr
	ld a,(hl)
	cp T_TMP2
	jr nz,.door_next
	push hl
	ld a,100
	call randint
	pop hl
	cp DUN_TUN_PEN
	jr nc,.doorway
	call place_door
	jr .door_next
.doorway:
	ld (hl),T_CORRIDOR
.door_next:
	pop bc
	pop hl
	dec bc
	jr .door_loop

.move:									; D, E -> current position
	ld a,d
	ld (tun_y),a
	ld a,e
	ld (tun_x),a
	ret

/* mark_pierced - granite in the 3x3 around tun_y,tun_x becomes T_TMP2 */
mark_pierced:
	ld a,(tun_y)
	dec a
	ld (mark_y),a
	ld b,3
.row:
	ld a,(tun_x)
	dec a
	ld (mark_x),a
	ld c,3
.col:
	push bc
	ld a,(mark_y)
	ld d,a
	ld a,(mark_x)
	ld e,a
	call in_bounds
	jr nc,.skip
	call map_addr
	ld a,(hl)
	cp T_GRANITE
	jr nz,.skip
	ld (hl),T_TMP2
.skip:
	ld hl,mark_x
	inc (hl)
	pop bc
	dec c
	jr nz,.col
	ld hl,mark_y
	inc (hl)
	djnz .row
	ret

/* change_dir - 1 in DUN_TUN_RND random, otherwise head for the target */
change_dir:
	ld a,DUN_TUN_RND
	call randint
	dec a
	jr nz,correct_dir
/* rand_dir - one of the four orthogonal directions */
rand_dir:
	ld a,4
	call randint
	add a,a
	ld hl,rand_dir_table-2
	add hl,a
	ld a,(hl)
	ld (row_dir),a
	inc hl
	ld a,(hl)
	ld (col_dir),a
	ret

/* correct_dir - point at the target; if diagonal, drop one axis at random */
correct_dir:
	ld a,(tun_ty)
	ld b,a
	ld a,(tun_y)
	call sign_to
	ld (row_dir),a
	ld a,(tun_tx)
	ld b,a
	ld a,(tun_x)
	call sign_to
	ld (col_dir),a
	or a
	ret z
	ld a,(row_dir)
	or a
	ret z
	ld a,2
	call randint
	dec a
	jr nz,.zero_col
	ld (row_dir),a
	ret
.zero_col:
	xor a
	ld (col_dir),a
	ret

/* sign_to - A = from, B = to -> A = 1, 0 or -1 */
sign_to:
	cp b
	jr z,.same
	ld a,1
	ret c
	ld a,-1
	ret
.same:
	xor a
	ret

rand_dir_table:
	db -1,0, 1,0, 0,-1, 0,1

/* place_door - HL = square. 3/8 open (1 in 4 of them broken), 3/8 closed
	(of those, 1 in 100 stuck, 24 in 100 locked, by 11-20), 2/8 secret.
	Clobbers A, DE */
place_door:
	push hl
	ld a,8
	call randint
	pop hl
	cp 4
	jr nc,.not_open
	ld (hl),T_DOOR_OPEN
	push hl
	ld a,4
	call randint
	pop hl
	dec a
	ret nz
	ld a,1								; broken
	jr .number
.not_open:
	cp 7
	jr nc,.secret
	ld (hl),T_DOOR_CLOSED
	push hl
	ld a,100
	call randint
	pop hl
	cp 26
	ret nc								; plain
	ld e,a
	push hl
	ld a,10
	call randint
	pop hl
	add a,10
	ld d,a
	ld a,e
	cp 3								; 1 in 100 stuck, else locked
	ld a,d
	jr nz,.number
	neg
.number:
	push bc
	OVCALL PAGE_TRAP, door_set, PAGE_LEVEL
	pop bc
	ret
.secret:
	ld (hl),T_DOOR_SECRET
	ret

/* fill_cave - leftover rock, pillars and pierced walls become granite */
fill_cave:
	ld hl,MAP_BASE
	ld bc,MAP_W*MAP_H
.loop:
	ld a,(hl)
	cp T_NULL
	jr z,.granite
	cp T_TMP1
	jr z,.granite
	cp T_TMP2
	jr nz,.next
.granite:
	ld (hl),T_GRANITE
.next:
	inc hl
	dec bc
	ld a,b
	or c
	jr nz,.loop
	ret

/* place_streamer - A = T_MAGMA or T_QUARTZ. A band of mineral vein
	through the granite, in one of the 8 directions from near the centre */
place_streamer:
	ld (streamer_type),a
	ld a,23
	call randint
	ld b,a
	ld a,MAP_H/2+11
	sub b
	ld (streamer_y),a
	ld a,33
	call randint
	ld b,a
	ld a,MAP_W/2+16
	sub b
	ld (streamer_x),a
	ld a,8
	call randint
	add a,a
	ld hl,streamer_dirs-2
	add hl,a
	ld a,(hl)
	ld (streamer_dy),a
	inc hl
	ld a,(hl)
	ld (streamer_dx),a
.step:
	ld b,DUN_STR_DEN
.dot:
	push bc
	ld a,5
	call randint
	sub 3
	ld hl,streamer_y
	add a,(hl)
	ld (streamer_ty),a
	ld a,5
	call randint
	sub 3
	ld hl,streamer_x
	add a,(hl)
	ld e,a
	ld a,(streamer_ty)
	ld d,a
	call in_bounds
	jr nc,.no_dot
	call map_addr
	ld a,(hl)
	cp T_GRANITE
	jr nz,.no_dot
	ld a,(streamer_type)
	ld (hl),a
.no_dot:
	pop bc
	djnz .dot
	ld a,(streamer_dy)					; move on; stop at the map edge
	ld hl,streamer_y
	add a,(hl)
	cp MAP_H
	ret nc
	ld (hl),a
	ld a,(streamer_dx)
	ld hl,streamer_x
	add a,(hl)
	cp MAP_W
	ret nc
	ld (hl),a
	jr .step

streamer_dirs:							; keypad 1-4, 6-9 as dy, dx
	db 1,-1, 1,0, 1,1, 0,-1, 0,1, -1,-1, -1,0, -1,1

/* junction_doors - try a door beside each place tunnels met */
junction_doors:
	ld hl,DOOR_STACK
	ld bc,(door_list)
.loop:
	ld a,b
	or c
	ret z
	ld d,(hl)
	inc hl
	ld e,(hl)
	inc hl
	push hl
	push bc
	dec e
	call try_door
	inc e
	inc e
	call try_door
	dec e
	dec d
	call try_door
	inc d
	inc d
	call try_door
	pop bc
	pop hl
	dec bc
	jr .loop

/* try_door - D = y, E = x. Door if it's a corridor squeezed between walls
	with corridor around it. Preserves DE */
try_door:
	push de
	call map_addr
	pop de
	ld a,(hl)
	cp T_CORRIDOR
	ret nz
	push de
	push hl
	ld a,100
	call randint
	pop hl
	pop de
	cp DUN_TUN_JCT+1
	ret c
	call next_to
	ret nc
	push de
	call place_door
	pop de
	ret

/* next_to - HL = square -> carry if 3+ corridor squares in the 3x3 and
	walls on both sides (north/south or west/east). Preserves DE, HL */
next_to:
	push de
	push hl
	ld de,-MAP_W-1
	add hl,de
	ld c,0
	call .count3
	ld de,MAP_W-3
	add hl,de
	call .count3
	add hl,de
	call .count3
	pop hl
	push hl
	ld a,c
	cp 3
	jr c,.no
	ld de,-MAP_W
	add hl,de							; north
	ld a,(hl)
	call is_wall
	jr z,.west_east
	ld de,MAP_W*2
	add hl,de							; south
	ld a,(hl)
	call is_wall
	jr nz,.yes
.west_east:
	pop hl
	push hl
	dec hl
	ld a,(hl)
	call is_wall
	jr z,.no
	inc hl
	inc hl
	ld a,(hl)
	call is_wall
	jr z,.no
.yes:
	pop hl
	pop de
	scf
	ret
.no:
	pop hl
	pop de
	or a
	ret
.count3:
	ld b,3
.c3:
	ld a,(hl)
	inc hl
	cp T_CORRIDOR
	jr nz,.c3_next
	inc c
.c3_next:
	djnz .c3
	ret

/* place_stairs - A = T_STAIR_DOWN / T_STAIR_UP, B = how many (on
	Sauron's level while he lives, down is up: place_down_stairs).
	Prefers spots with 3 walls round them (corridor ends), accepting fewer
	walls if none can be found */
place_stairs:
	cp T_STAIR_DOWN
	jr nz,.type
	push bc
	ld a,(dun_level)
	call is_quest
	pop bc
	ld a,T_STAIR_DOWN
	jr nz,.type
	ld a,T_STAIR_UP
.type:
	ld (stair_type),a
.each:
	push bc
	ld a,(stair_wall_start)
	ld (stair_walls),a
.retry:
	ld b,0								; 256 tries per wall count
.try:
	push bc
	call random_open_spot
	call next_to_walls
	ld b,a
	ld a,(stair_walls)
	cp b
	jr z,.found
	jr c,.found
	pop bc
	djnz .try
	ld hl,stair_walls
	dec (hl)
	jr .retry
.found:
	pop bc
	ld a,(stair_type)
	ld (hl),a
	pop bc
	djnz .each
	ret

/* list_push - IX = list (count, max, base), D = y, E = x. Full lists
	silently drop entries, like the C version */
list_push:
	ld l,(ix+0)
	ld h,(ix+1)
	ld a,l
	sub (ix+2)
	ld a,h
	sbc a,(ix+3)
	ret nc
	push hl
	inc hl
	ld (ix+0),l
	ld (ix+1),h
	pop hl
	add hl,hl
	ld a,(ix+4)
	add a,l
	ld l,a
	ld a,(ix+5)
	adc a,h
	ld h,a
	ld (hl),d
	inc hl
	ld (hl),e
	ret

; list descriptors: count, max, base
tun_list:		dw 0,TUN_MAX,TUN_STACK
wall_list:		dw 0,TUN_MAX,WALL_STACK
door_list:		dw 0,DOOR_MAX,DOOR_STACK

; generator state
room_count:		db 0
room_floor:		db 0
pit_ok:			db 0				; one pit a level
gen_row:		db 0
gen_col:		db 0
room_yval:		db 0
room_xval:		db 0
r_top:			db 0
r_bottom:		db 0
r_left:			db 0
r_right:		db 0
pillar_y:		db 0
pillar_x:		db 0
tun_y:			db 0
tun_x:			db 0
tun_ty:			db 0
tun_tx:			db 0
tun_sy:			db 0
tun_sx:			db 0
row_dir:		db 0
col_dir:		db 0
door_flag:		db 0
stop_flag:		db 0
tun_steps:		dw 0
mark_y:			db 0
mark_x:			db 0
streamer_type:	db 0
streamer_y:		db 0
streamer_x:		db 0
streamer_ty:	db 0
streamer_dy:	db 0
streamer_dx:	db 0
stair_type:		db 0
stair_walls:	db 0
stair_wall_start: db 3

boundary_rects:
	db 0,0,MAP_W,1,T_PERMWALL
	db 0,MAP_H-1,MAP_W,1,T_PERMWALL
	db 0,0,1,MAP_H,T_PERMWALL
	db MAP_W-1,0,1,MAP_H,T_PERMWALL
	db $FF

/* town_gen - the town (town_gen in GENERATE.C): one screen of open
	ground with eight walled stores in a 2x4 grid, each with a numbered
	door, and a down staircase. It's built from town_seed, so it looks the
	same on every visit. By day everything is lit; by night only the
	buildings */
town_gen:
	OVCALL PAGE_TRAP, doors_clear, PAGE_LEVEL
	ld hl,(rng_state)
	ld (saved_rng),hl
	ld hl,(town_seed)
	ld (rng_state),hl
	ld hl,MAP_BASE						; solid permanent rock everywhere
	ld de,MAP_BASE+1
	ld bc,MAP_W*MAP_H-1
	ld (hl),T_PERMWALL
	ldir
	ld e,1								; open ground inside the town wall
	ld d,1
	ld b,TOWN_W-2
	ld c,TOWN_H-2
	ld a,T_FLOOR
	call carve_rect
	ld hl,town_rooms					; stores 0-7 in a random order
	ld b,NUM_STORES
	xor a
.rooms:
	ld (hl),a
	inc hl
	inc a
	djnz .rooms
	ld a,NUM_STORES
	ld (rooms_left),a
	xor a
	ld (slot_y),a
.slot_row:
	xor a
	ld (slot_x),a
.slot_col:
	ld a,(rooms_left)					; take a random one off the list
	call randint
	dec a
	ld (room_pick),a
	ld hl,town_rooms
	add hl,a
	ld c,(hl)
	push bc
	ld a,(rooms_left)					; close the gap behind it
	dec a
	ld hl,room_pick
	sub (hl)
	jr z,.no_shift
	ld c,a
	ld b,0
	ld a,(room_pick)
	ld hl,town_rooms
	add hl,a
	ld d,h
	ld e,l
	inc hl
	ldir
.no_shift:
	ld hl,rooms_left
	dec (hl)
	pop bc
	ld a,c
	call build_store
	ld hl,slot_x
	inc (hl)
	ld a,(hl)
	cp 4
	jr c,.slot_col
	ld hl,slot_y
	inc (hl)
	ld a,(hl)
	cp 2
	jr c,.slot_row
	xor a								; stairs anywhere open
	ld (stair_wall_start),a
	ld b,1
	ld a,T_STAIR_DOWN
	call place_stairs
	ld hl,(saved_rng)
	ld (rng_state),hl
	; day or night: night is every other 5000 turns
	ld hl,(game_turn)
	ld de,5000
	ld b,0
.days:
	or a
	sbc hl,de
	jr c,.counted
	inc b
	jr .days
.counted:
	ld a,b
	and 1
	ld (town_night),a
	ld hl,MAP_BASE						; light it
	ld c,TOWN_H
.light_row:
	push hl
	ld b,TOWN_W
.light_col:
	ld a,(town_night)
	or a
	jr z,.lit
	ld a,(hl)
	and TERRAIN_MASK
	cp T_FLOOR
	jr z,.dark
.lit:
	set F_PERM_BIT,(hl)
.dark:
	inc hl
	djnz .light_col
	pop hl
	ld de,MAP_W
	add hl,de
	dec c
	jr nz,.light_row
	ret

/* build_store - A = store, slot_y/slot_x = its place in the grid: a
	block of permanent wall with the door on a random side (build_store) */
build_store:
	ld (bs_store),a
	ld a,(slot_y)						; yval = y*10 + 5, xval = x*14 + 12
	ld e,a
	ld d,10
	mul d,e
	ld a,e
	add a,5
	ld (bs_yval),a
	ld a,(slot_x)
	ld e,a
	ld d,14
	mul d,e
	ld a,e
	add a,12
	ld (bs_xval),a
	ld a,3
	call randint
	ld b,a
	ld a,(bs_yval)
	sub b
	ld (bs_top),a
	ld a,4
	call randint
	ld b,a
	ld a,(bs_yval)
	add a,b
	ld (bs_bottom),a
	ld a,4
	call randint
	ld b,a
	ld a,(bs_xval)
	sub b
	ld (bs_left),a
	ld a,4
	call randint
	ld b,a
	ld a,(bs_xval)
	add a,b
	ld (bs_right),a
	ld a,(bs_top)
	ld d,a
	ld a,(bs_left)
	ld e,a
	ld a,(bs_right)
	sub e
	inc a
	ld b,a
	ld a,(bs_bottom)
	sub d
	inc a
	ld c,a
	ld a,T_PERMWALL
	call carve_rect
	ld a,4								; the door
	call randint
	cp 3
	jr nc,.top_bottom
	push af								; 1, 2: left or right wall
	ld a,(bs_top)
	ld b,a
	ld a,(bs_bottom)
	sub b
	call randint
	ld b,a
	ld a,(bs_top)
	add a,b
	dec a
	ld d,a
	pop af
	ld e,a
	ld a,(bs_left)
	dec e
	jr z,.door
	ld a,(bs_right)
	jr .door
.top_bottom:							; 3, 4: bottom or top wall
	push af
	ld a,(bs_left)
	ld b,a
	ld a,(bs_right)
	sub b
	call randint
	ld b,a
	ld a,(bs_left)
	add a,b
	dec a
	ld e,a
	pop af
	cp 3
	ld a,(bs_bottom)
	jr z,.got_row
	ld a,(bs_top)
.got_row:
	ld d,a
	ld a,e
.door:
	ld e,a								; D = y, E = x
	push de
	call map_addr
	ld (hl),T_STORE
	pop de
	ld a,(bs_store)						; remember where it is
	add a,a
	ld hl,STORE_DOOR
	add hl,a
	ld (hl),d
	inc hl
	ld (hl),e
	ret

saved_rng:		dw 0
town_rooms:		ds NUM_STORES
rooms_left:		db 0
room_pick:		db 0
slot_y:			db 0
slot_x:			db 0
bs_store:		db 0
bs_yval:		db 0
bs_xval:		db 0
bs_top:			db 0
bs_bottom:		db 0
bs_left:		db 0
bs_right:		db 0

