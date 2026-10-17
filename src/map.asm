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
	and TERRAIN_MASK
	cp T_FLOOR
	ret z
	cp T_FLOOR_LIT
	ret z
	cp T_CORRIDOR
	ret z
	jr random_open_spot

; char, attribute, flags, spare
REM		equ 1<<TF_REMEMBER
terrain_table:
	db '#',ATTR_GREY,0,0								; T_NULL
	db '.',ATTR_WHITE,1<<TF_PASSABLE,0					; T_FLOOR
	db '.',ATTR_WHITE,1<<TF_PASSABLE,0					; T_CORRIDOR
	db '#',ATTR_GREY,1<<TF_WALL|REM,0					; T_GRANITE
	db '#',ATTR_DARK,1<<TF_WALL|REM,0					; T_PERMWALL
	db '+',ATTR_UMBER,REM,0								; T_DOOR_CLOSED
	db "'",ATTR_UMBER,1<<TF_PASSABLE|REM,0				; T_DOOR_OPEN
	db '#',ATTR_GREY,REM,0								; T_DOOR_SECRET
	db '>',ATTR_WHITE,1<<TF_PASSABLE|REM,0				; T_STAIR_DOWN
	db '<',ATTR_WHITE,1<<TF_PASSABLE|REM,0				; T_STAIR_UP
	db '#',ATTR_GREY,0,0								; T_TMP1
	db '#',ATTR_GREY,0,0								; T_TMP2
	db '%',ATTR_DARK,1<<TF_WALL|REM,0					; T_MAGMA
	db '%',ATTR_WHITE,1<<TF_WALL|REM,0					; T_QUARTZ
	db '.',ATTR_WHITE,1<<TF_PASSABLE,0					; T_FLOOR_LIT
	db '+',ATTR_WHITE,1<<TF_PASSABLE|REM,0				; T_STORE (drawn as its number)

