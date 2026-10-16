/* map.asm - dungeon map storage and the milestone 1 test level
	The map is MAP_W x MAP_H bytes, one terrain id per square, at MAP_BASE.
	Reference: GENERATE.C (level generation), TYPES.H cave_type.
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

/* map_build_test - fixed layout until the generator is written */
map_build_test:
	ld hl,test_level
	jr carve_list

; char, attribute, flags, spare
terrain_table:
	db '#',ATTR_GREY,0,0								; T_GRANITE
	db '.',ATTR_WHITE,1<<TF_PASSABLE,0					; T_FLOOR
	db '#',ATTR_DARK,0,0								; T_PERMWALL
	db '+',ATTR_UMBER,0,0								; T_DOOR_CLOSED
	db "'",ATTR_UMBER,1<<TF_PASSABLE,0					; T_DOOR_OPEN
	db '>',ATTR_WHITE,1<<TF_PASSABLE,0					; T_STAIR_DOWN
	db '<',ATTR_WHITE,1<<TF_PASSABLE,0					; T_STAIR_UP

test_level:
	; solid rock with a permanent border
	db 0,0,MAP_W,MAP_H,T_GRANITE
	db 0,0,MAP_W,1,T_PERMWALL
	db 0,MAP_H-1,MAP_W,1,T_PERMWALL
	db 0,0,1,MAP_H,T_PERMWALL
	db MAP_W-1,0,1,MAP_H,T_PERMWALL
	; rooms
	db 30,20,15,8,T_FLOOR
	db 60,18,20,12,T_FLOOR
	db 100,25,25,10,T_FLOOR
	db 40,40,12,6,T_FLOOR
	db 150,10,30,15,T_FLOOR
	; corridors
	db 45,23,15,1,T_FLOOR
	db 80,28,20,1,T_FLOOR
	db 42,28,1,12,T_FLOOR
	db 125,30,36,1,T_FLOOR
	db 160,25,1,5,T_FLOOR
	; features
	db 45,23,1,1,T_DOOR_CLOSED
	db 99,28,1,1,T_DOOR_CLOSED
	db 170,15,1,1,T_STAIR_DOWN
	db 32,21,1,1,T_STAIR_UP
	db $FF
