/* map.asm - dungeon map storage and helpers
	The map is MAP_W x MAP_H bytes, one terrain id per square, at MAP_BASE.
	Reference: TYPES.H cave_type, MISC1.C in_bounds/next_to_walls
 */

/* map_addr - D = y, E = x -> HL = map square. Clobbers A, DE */
map_addr:
	ld a,e
	ld e,MAP_W
	mul d,e
	add de,a
	ld hl,MAP_BASE
	add hl,de
	ret

/* in_bounds - D = y, E = x -> carry set if inside the outer wall.
	Clobbers A only */
in_bounds:
	ld a,d
	dec a
	cp MAP_H-2
	ret nc
	ld a,e
	dec a
	cp MAP_W-2
	ret

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

/* terrain_flags - A = terrain -> A = flags. Preserves HL */
terrain_flags:
	push hl
	add a,a
	add a,a
	ld hl,terrain_table+2
	add hl,a
	ld a,(hl)
	pop hl
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

/* random_open_spot - pick a random room or corridor floor square.
	out: D = y, E = x, HL = square */
random_open_spot:
	ld a,MAP_H-2
	call randint
	push af
	ld a,MAP_W-2
	call randint
	ld e,a
	pop af
	ld d,a
	push de
	call map_addr
	pop de
	ld a,(hl)
	cp T_FLOOR
	ret z
	cp T_CORRIDOR
	ret z
	jr random_open_spot

; char, attribute, flags, spare
terrain_table:
	db '#',ATTR_GREY,0,0								; T_NULL
	db '.',ATTR_WHITE,1<<TF_PASSABLE,0					; T_FLOOR
	db '.',ATTR_WHITE,1<<TF_PASSABLE,0					; T_CORRIDOR
	db '#',ATTR_GREY,1<<TF_WALL,0						; T_GRANITE
	db '#',ATTR_DARK,1<<TF_WALL,0						; T_PERMWALL
	db '+',ATTR_UMBER,0,0								; T_DOOR_CLOSED
	db "'",ATTR_UMBER,1<<TF_PASSABLE,0					; T_DOOR_OPEN
	db '#',ATTR_GREY,0,0								; T_DOOR_SECRET
	db '>',ATTR_WHITE,1<<TF_PASSABLE,0					; T_STAIR_DOWN
	db '<',ATTR_WHITE,1<<TF_PASSABLE,0					; T_STAIR_UP
	db '#',ATTR_GREY,0,0								; T_TMP1
	db '#',ATTR_GREY,0,0								; T_TMP2
	db '%',ATTR_DARK,1<<TF_WALL,0						; T_MAGMA
	db '%',ATTR_WHITE,1<<TF_WALL,0						; T_QUARTZ

boundary_rects:
	db 0,0,MAP_W,1,T_PERMWALL
	db 0,MAP_H-1,MAP_W,1,T_PERMWALL
	db 0,0,1,MAP_H,T_PERMWALL
	db MAP_W-1,0,1,MAP_H,T_PERMWALL
	db $FF
