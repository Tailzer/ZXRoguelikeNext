/* rooms.asm - the unusual rooms (overlay page PAGE_ROOMS)
	References: GENERATE.C build_type2 (inner rooms), build_type3 (cross
	shaped), build_type5 (the vaults: templates), build_pit/special_pit and
	vault_nasty (monster pits), vault_monster, vault_trap; MISC2.C
	random_object, place_special.
	The level overlay's build_room asks for one with build_unusual; these
	reach back into it (and the trap overlay) for monsters, objects, traps.
	Map squares are written bare (just terrain) as all of generation does;
	T_TMP1 is an inner wall, granite after fill_cave.
 */

/* build_unusual - A = 2, 3 (inner room, cross), 5 (a vault) or 6 (a
	pit), D = yval, E = xval, L = the floor (lit or not) */
build_unusual:
	ld c,a
	ld a,l
	ld (ru_floor),a
	ld a,d
	ld (ru_y),a
	ld a,e
	ld (ru_x),a
	ld a,c
	ld b,a
	xor a
	ld (ru_wide),a
	ld a,b
	cp 2
	jp z,build_type2
	cp 3
	jp z,build_type3
	cp 5
	jp z,build_type5
	jp build_pit

; ---------------------------------------------------------------- helpers

/* ru_at - B = dy, C = dx from (ru_y, ru_x) -> D, E the square, HL its
	address. Preserves BC */
ru_at:
	ld a,(ru_y)
	add a,b
	ld d,a
	ld a,(ru_x)
	add a,c
	ld e,a
/* ru_addr - D, E -> HL. Preserves BC, DE */
ru_addr:
	push de
	call map_addr
	pop de
	ret

/* ru_set - B = dy, C = dx from the centre, A = terrain. Preserves BC */
ru_set:
	push af
	call ru_at
	pop af
	ld (hl),a
	ret

/* ru_fill - A = terrain, B = dy top, C = dx left, D = height, E = width:
	a rectangle relative to the centre */
ru_fill:
	ld (ru_t),a
.row:
	push bc
	push de
.col:
	push de
	ld a,(ru_t)
	call ru_set
	pop de
	inc c
	dec e
	jr nz,.col
	pop de
	pop bc
	inc b
	dec d
	jr nz,.row
	ret

/* ru_ring - A = terrain, B = dy top, C = dx left, D = height, E = width:
	the edge of that rectangle */
ru_ring:
	ld (ru_t),a
	push bc
	push de
.top:
	push de
	ld a,(ru_t)
	call ru_set
	pop de
	inc c
	dec e
	jr nz,.top
	pop de
	pop bc
	push bc
	push de
	ld a,b
	add a,d
	dec a
	ld b,a
.bottom:
	push de
	ld a,(ru_t)
	call ru_set
	pop de
	inc c
	dec e
	jr nz,.bottom
	pop de
	pop bc
	push bc
	push de
.left:
	push de
	ld a,(ru_t)
	call ru_set
	pop de
	inc b
	dec d
	jr nz,.left
	pop de
	pop bc
	ld a,c
	add a,e
	dec a
	ld c,a
.right:
	push de
	ld a,(ru_t)
	call ru_set
	pop de
	inc b
	dec d
	jr nz,.right
	ret

/* ru_room - B = dy top, C = dx left, D = height, E = width: floor, with
	a granite ring round it (as build_room) */
ru_room:
	push bc
	push de
	ld a,(ru_floor)
	call ru_fill
	pop de
	pop bc
	dec b
	dec c
	inc d
	inc d
	inc e
	inc e
	ld a,T_GRANITE
	jp ru_ring

/* ru_secret - B, C: a secret door. ru_locked: a locked one (11-20) */
ru_secret:
	ld a,T_DOOR_SECRET
	jp ru_set
ru_locked:
	ld a,T_DOOR_CLOSED
	call ru_set
	push hl
	ld a,10
	call randint
	add a,10
	pop hl
	OVCALL PAGE_TRAP, door_set, PAGE_ROOMS
	ret

/* ru_door4 - one secret door in the middle of a side of the inner room
	(B = its top - 1 .. its bottom + 1, as tmp = 1d4 in the C): top,
	bottom, left, right. B = top dy, D = bottom dy, C = left dx, E = right
	dx (of the wall) */
ru_door4:
	push bc
	push de
	ld a,4
	call randint
	pop de
	pop hl								; H = top, L = left
	dec a
	jr nz,.not_top
	ld b,h
	ld c,0
	jr ru_secret
.not_top:
	dec a
	jr nz,.not_bottom
	ld b,d
	ld c,0
	jr ru_secret
.not_bottom:
	dec a
	ld b,0
	ld c,l
	jr z,ru_secret
	ld c,e
	jr ru_secret

/* ru_object - B, C: an object there. ru_monster - B, C, A = how many:
	vault_monster (asleep, a little deeper, next to there) */
ru_object:
	call ru_at
	OVCALL PAGE_LEVEL, place_object, PAGE_ROOMS
	ret
ru_monster:
	or a
	ret z
.each:
	push af
	push bc
	call ru_at
	OVCALL PAGE_LEVEL, summon_asleep, PAGE_ROOMS
	pop bc
	pop af
	dec a
	jr nz,.each
	ret

/* ru_trap - B, C = the middle, D = yd, E = xd, A = how many: vault_trap,
	each on a floor square within +-yd, +-xd (5 tries) */
ru_trap:
	or a
	ret z
	ld (ru_n),a
	ld (ru_yd),de
.each:
	ld a,6
	ld (ru_try),a
.try:
	push bc
	ld a,(ru_yd)						; (E: xd, D: yd)
	ld e,a
	add a,a
	inc a
	call randint
	sub e
	dec a
	ld h,a								; dx
	ld a,(ru_yd+1)
	ld e,a
	add a,a
	inc a
	call randint
	sub e
	dec a
	add a,b								; dy
	ld b,a
	ld a,h
	add a,c
	ld c,a
	call ru_at
	ld a,(hl)
	call ru_is_floor
	jr nz,.next
	push de
	call item_at
	pop de
	jr c,.next
	call trap_at
	jr c,.next
	ld a,NUM_TRAPS
	call randint
	OVCALL PAGE_TRAP, place_trap, PAGE_ROOMS
	pop bc
	jr .placed
.next:
	pop bc
	ld hl,ru_try
	dec (hl)
	jr nz,.try
.placed:
	ld hl,ru_n
	dec (hl)
	jr nz,.each
	ret

/* ru_is_floor - A = a square's byte -> Z if it's floor */
ru_is_floor:
	and TERRAIN_MASK
	cp T_FLOOR
	ret z
	cp T_FLOOR_LIT
	ret z
	cp T_CORRIDOR
	ret

/* ru_random_object - A = how many: random_object near the centre, each
	on a floor square without one (10 tries): 3 in 4 an object, else gold */
ru_random_object:
	ld (ru_n),a
.each:
	ld a,11
	ld (ru_try),a
.try:
	ld a,5								; y - 3 + 1d5, x - 4 + 1d7
	call randint
	sub 3
	ld b,a
	ld a,7
	call randint
	sub 4
	ld c,a
	call ru_at
	ld a,(hl)
	call ru_is_floor
	jr nz,.next
	push de
	call item_at
	pop de
	jr c,.next
	ld a,100
	push de
	call randint
	pop de
	cp 75
	jr nc,.gold
	OVCALL PAGE_LEVEL, place_object, PAGE_ROOMS
	jr .done
.gold:
	OVCALL PAGE_LEVEL, place_gold, PAGE_ROOMS
	jr .done
.next:
	ld hl,ru_try
	dec (hl)
	jr nz,.try
.done:
	ld hl,ru_n
	dec (hl)
	jr nz,.each
	ret

/* ru_stairs - B, C, A = T_STAIR_DOWN or UP (down is up on Sauron's
	level, as place_down_stairs) */
ru_stairs:
	cp T_STAIR_DOWN
	jr nz,.set
	push bc
	ld a,(dun_level)
	call is_quest
	pop bc
	ld a,T_STAIR_DOWN
	jr nz,.set
	ld a,T_STAIR_UP
.set:
	jp ru_set

; ---------------------------------------------------------------- type 2

/* build_type2 - an outer room (23 x 9) with an inner one (19 x 5, walls
	of T_TMP1) holding one of five things (build_type2) */
build_type2:
	ld bc,-4*256+(-11 & 255)			; the outer room
	ld de,9*256+23
	call ru_room
	ld bc,-3*256+(-10 & 255)			; the inner room's walls
	ld de,7*256+21
	ld a,T_TMP1
	call ru_ring
	ld a,5
	call randint
	dec a
	jp z,.just
	dec a
	jr z,.treasure
	dec a
	jp z,.pillars
	dec a
	jp z,.maze
	jp .four
.door:									; a secret door in the inner wall
	ld b,-3
	ld d,3
	ld c,-10
	ld e,10
	jp ru_door4
.just:									; 1: just an inner room
	call .door
	ld bc,0
	ld a,1
	jp ru_monster
.treasure:								; 2: a vault inside the inner room
	call .door
	ld bc,-1*256+(-1 & 255)
	ld de,3*256+3
	ld a,T_TMP1
	call ru_ring
	ld a,4								; its locked door
	call randint
	cp 3
	jr nc,.side
	add a,a								; 1 -> -1, 2 -> +1
	sub 3
	ld b,a
	ld c,0
	jr .lock
.side:
	add a,a								; 3 -> -1, 4 -> +1
	sub 7
	ld c,a
	ld b,0
.lock:
	call ru_locked
	ld a,10								; an object, or stairs
	call randint
	ld bc,0
	cp 3
	jr nc,.thing
	cp 2
	ld a,T_STAIR_DOWN
	jr z,$+4
	ld a,T_STAIR_UP
	call ru_stairs
	jr .guard
.thing:
	call ru_object
.guard:
	ld a,3								; 2 + 1d3 guards, 2 + 1d3 traps
	call randint
	add a,2
	ld bc,0
	call ru_monster
	ld a,3
	call randint
	add a,2
	ld bc,0
	ld de,4*256+10
	jp ru_trap
.pillars:								; 3: a pillar (or three), maybe
	call .door							; two inner rooms of their own
	ld bc,-1*256+(-1 & 255)
	ld de,3*256+3
	ld a,T_TMP1
	call ru_fill
	ld a,2
	call randint
	dec a
	jr nz,.rooms
	ld a,2
	call randint
	ld (ru_n),a
	neg
	sub 5
	ld c,a								; -5 - tmp
	ld b,-1
	ld de,3*256+3
	ld a,T_TMP1
	call ru_fill
	ld a,(ru_n)
	add a,3
	ld c,a								; 3 + tmp
	ld b,-1
	ld de,3*256+3
	ld a,T_TMP1
	call ru_fill
.rooms:
	ld a,3
	call randint
	dec a
	ret nz
	ld bc,-1*256+(-5 & 255)				; walls above and below, the ends
	ld de,1*256+11
	ld a,T_TMP1
	call ru_fill
	ld bc,1*256+(-5 & 255)
	ld de,1*256+11
	ld a,T_TMP1
	call ru_fill
	ld bc,0*256+(-5 & 255)
	ld a,T_TMP1
	call ru_set
	ld bc,0*256+5
	ld a,T_TMP1
	call ru_set
	ld a,2								; their secret doors
	call randint
	add a,a
	sub 3
	ld b,a
	ld c,-3
	call ru_secret
	ld a,2
	call randint
	add a,a
	sub 3
	ld b,a
	ld c,3
	call ru_secret
	ld a,3
	call randint
	dec a
	ld bc,0*256+(-2 & 255)
	call z,ru_object
	ld a,3
	call randint
	dec a
	ld bc,0*256+2
	call z,ru_object
	ld a,2
	call randint
	ld bc,0*256+(-2 & 255)
	call ru_monster
	ld a,2
	call randint
	ld bc,0*256+2
	jp ru_monster
.maze:									; 4: a maze
	call .door
	ld b,-2
.maze_row:
	ld c,-9
.maze_col:
	ld a,(ru_y)							; walls where x + y is odd
	add a,b
	ld e,a
	ld a,(ru_x)
	add a,c
	add a,e
	and 1
	jr z,.maze_next
	ld a,T_TMP1
	call ru_set
.maze_next:
	inc c
	ld a,c
	cp 10
	jr nz,.maze_col
	inc b
	ld a,b
	cp 3
	jr nz,.maze_row
	ld a,3
	call randint
	ld bc,0*256+(-5 & 255)
	call ru_monster
	ld a,3
	call randint
	ld bc,0*256+5
	call ru_monster
	ld a,3
	call randint
	ld bc,0*256+(-3 & 255)
	ld de,2*256+8
	call ru_trap
	ld a,3
	call randint
	ld bc,0*256+3
	ld de,2*256+8
	call ru_trap
	ld a,3
	jp ru_random_object
.four:									; 5: four small rooms
	ld bc,-2*256+0
	ld de,5*256+1
	ld a,T_TMP1
	call ru_fill
	ld bc,0*256+(-9 & 255)
	ld de,1*256+19
	ld a,T_TMP1
	call ru_fill
	ld a,2
	call randint
	dec a
	jr nz,.sides
	ld a,10								; doors top and bottom, 1d10 out
	call randint
	ld (ru_n),a
	ld c,a
	ld b,-3
	call ru_secret
	ld a,(ru_n)
	neg
	ld c,a
	ld b,-3
	call ru_secret
	ld a,(ru_n)
	ld c,a
	ld b,3
	call ru_secret
	ld a,(ru_n)
	neg
	ld c,a
	ld b,3
	call ru_secret
	jr .stock
.sides:
	ld a,3								; doors at the sides, 1d3 out
	call randint
	ld (ru_n),a
	ld b,a
	ld c,-10
	call ru_secret
	ld a,(ru_n)
	ld b,a
	ld c,10
	call ru_secret
	ld a,(ru_n)
	neg
	ld b,a
	ld c,-10
	call ru_secret
	ld a,(ru_n)
	neg
	ld b,a
	ld c,10
	call ru_secret
.stock:
	ld a,2
	call randint
	add a,2
	call ru_random_object
	ld a,2
	call randint
	ld bc,2*256+(-4 & 255)
	call ru_monster
	ld a,2
	call randint
	ld bc,2*256+4
	call ru_monster
	ld a,2
	call randint
	ld bc,-2*256+(-4 & 255)
	call ru_monster
	ld a,2
	call randint
	ld bc,-2*256+4
	jp ru_monster

; ---------------------------------------------------------------- type 3

/* build_type3 - a cross: a tall narrow room and a wide flat one, with
	one of four things in the middle (build_type3) */
build_type3:
	ld a,2								; the tall arm: 3 wide, 2 + 1d2 up
	call randint						; and down
	add a,2
	ld (ru_n),a
	neg
	ld b,a
	ld c,-1
	ld a,(ru_n)
	add a,a
	inc a
	ld d,a
	ld e,3
	call ru_room
	ld a,9								; the wide arm: 3 high, 2 + 1d9 out
	call randint
	add a,2
	ld (ru_n),a
	neg
	ld c,a
	ld b,-1
	ld a,(ru_n)
	add a,a
	inc a
	ld e,a
	ld d,3
	call ru_arm
	ld a,4
	call randint
	dec a
	jr z,.pillar
	dec a
	jr z,.vault
	dec a
	ret nz
	ld a,3								; 3: a little pattern of pillars
	call randint
	dec a
	jr nz,.plus
	ld hl,cross_pillars
	call ru_list
	ld a,3
	call randint
	dec a
	ret nz
	ld hl,cross_doors
	jp ru_list_doors
.plus:
	ld a,3
	call randint
	dec a
	jr nz,.dot
	ld hl,plus_pillars
	jp ru_list
.dot:
	ld a,3
	call randint
	dec a
	ret nz
	ld bc,0
	ld a,T_TMP1
	jp ru_set
.pillar:								; 1: a big middle pillar
	ld bc,-1*256+(-1 & 255)
	ld de,3*256+3
	ld a,T_TMP1
	jp ru_fill
.vault:									; 2: a treasure vault in the middle
	ld bc,-1*256+(-1 & 255)
	ld de,3*256+3
	ld a,T_TMP1
	call ru_ring
	ld a,4
	call randint
	cp 3
	jr nc,.vside
	add a,a
	sub 3
	ld b,a
	ld c,0
	jr .vdoor
.vside:
	add a,a
	sub 7
	ld c,a
	ld b,0
.vdoor:
	call ru_secret
	ld bc,0
	call ru_object
	ld a,2
	call randint
	add a,2
	ld bc,0
	call ru_monster
	ld a,3
	call randint
	inc a
	ld bc,0
	ld de,4*256+4
	jp ru_trap

/* ru_arm - as ru_room, but its ring doesn't cover floor already there */
ru_arm:
	push bc
	push de
	ld a,(ru_floor)
	call ru_fill
	pop de
	pop bc
	dec b
	dec c
	inc d
	inc d
	inc e
	inc e
.row:
	push bc
	push de
.col:
	push de
	call ru_at
	ld a,(hl)
	call ru_is_floor
	jr z,.keep
	ld (hl),T_GRANITE
.keep:
	pop de
	inc c
	dec e
	jr nz,.col
	pop de
	pop bc
	ld a,b								; (only the ring: top and bottom
	inc a								; rows whole, the sides between)
	ld b,a
	dec d
	jr nz,.row
	ret

/* ru_list - HL = (dy, dx) pairs ending $80: T_TMP1 on each.
	ru_list_doors: secret doors */
ru_list:
	ld a,T_TMP1
	jr ru_list_a
ru_list_doors:
	ld a,T_DOOR_SECRET
ru_list_a:
	ld (ru_t),a
.each:
	ld a,(hl)
	cp $80
	ret z
	ld b,a
	inc hl
	ld c,(hl)
	inc hl
	push hl
	ld a,(ru_t)
	call ru_set
	pop hl
	jr .each
cross_pillars:	db -1,-2, 1,-2, -1,2, 1,2, -2,-1, -2,1, 2,-1, 2,1, $80
cross_doors:	db 0,-2, 0,2, -2,0, 2,0, $80
plus_pillars:	db 0,0, -1,0, 1,0, 0,-1, 0,1, $80

; ---------------------------------------------------------------- type 5

/* build_type5 - a vault from a template (build_type5): seven lesser ones
	(1 in 8 each), else one of four greater ones, which sit 4 further down
	and right, behind permanent walls. One that won't fit is an inner room
	(type 2) instead */
build_type5:
	ld a,8
	call randint
	cp 8
	jr nz,.lesser
	ld a,4
	call randint
	add a,7
.lesser:
	dec a
	add a,a
	ld hl,vault_table
	add hl,a
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	ld a,(hl)							; width, height, greater
	ld (rv_w),a
	inc hl
	ld a,(hl)
	ld (rv_h),a
	inc hl
	ld a,(hl)
	ld (rv_greater),a
	inc hl
	ld (rv_ptr),hl
	ld a,T_TMP1
	ld (rv_wall),a
	ld a,(rv_greater)
	or a
	jr z,.fits
	ld a,(ru_y)
	add a,4
	ld (ru_y),a
	ld a,(ru_x)
	add a,4
	ld (ru_x),a
	ld a,T_PERMWALL
	ld (rv_wall),a
.fits:									; in bounds, corner to corner?
	ld a,(rv_h)
	srl a
	ld b,a
	ld a,(ru_y)
	sub b
	jr c,.no
	jr z,.no
	ld a,(ru_y)
	add a,b
	cp MAP_H-1
	jr nc,.no
	ld a,(rv_w)
	srl a
	ld b,a
	ld a,(ru_x)
	sub b
	jr c,.no
	jr z,.no
	ld a,(ru_x)
	add a,b
	cp MAP_W-1
	jr c,.build
.no:
	call build_type2
	ld a,1
	ret
.build:
	ld a,(rv_h)							; B, C = the top left, from the
	srl a								; centre
	neg
	ld (rv_top),a
	ld a,(rv_w)
	srl a
	neg
	ld (rv_left),a
	ld a,(rv_h)
	ld (rv_rows),a
	ld a,(rv_top)
	ld b,a
.row:
	ld a,(rv_w)
	ld (rv_cols),a
	ld a,(rv_left)
	ld c,a
.col:
	ld hl,(rv_ptr)
	ld a,(hl)
	inc hl
	ld (rv_ptr),hl
	push bc
	call vault_cell
	pop bc
	inc c
	ld hl,rv_cols
	dec (hl)
	jr nz,.col
	inc b
	ld hl,rv_rows
	dec (hl)
	jr nz,.row
	ld a,1
	ret

/* vault_cell - A = a template character, B, C = where (from the centre) */
vault_cell:
	ld (rv_ch),a
	cp '#'
	jr nz,.not_wall
	ld a,(rv_wall)
	jp ru_set
.not_wall:
	cp 'X'
	jr nz,.not_x
	ld a,T_TMP1
	jp ru_set
.not_x:
	cp '%'
	jr nz,.not_granite
	ld a,T_GRANITE
	jp ru_set
.not_granite:
	cp '+'
	jp z,ru_secret
	cp ' '
	ret z
	ld a,(ru_floor)						; everything else is floor first
	call ru_set
	ld a,(rv_ch)
	cp '.'
	ret z
	cp '^'
	jr z,.trap
	cp '*'
	jr z,.treasure
	cp '&'
	jr z,.monster
	cp '@'
	jr z,.meaner
	cp '8'
	jr z,.good
	cp 'O'
	jp z,.great
	cp ','
	ret nz
	ld a,2								; ',': maybe a monster, maybe an
	call randint						; object
	dec a
	jr nz,.no_mon
	xor a
	ld (rv_mean),a
	ld a,(rv_greater)
	add a,MON_SUMMON_ADJ
	call .mon
.no_mon:
	ld a,2
	call randint
	dec a
	ret nz
	jp ru_object
.trap:
	call ru_at
	ld a,NUM_TRAPS
	call randint
	OVCALL PAGE_TRAP, place_trap, PAGE_ROOMS
	ret
.treasure:								; '*': an object, a trap, or (in a
	ld a,20								; lesser vault) stairs
	call randint
	cp 8
	jp nc,ru_object
	ld a,10
	call randint
	cp 3
	jr nc,.trap
	ld a,(rv_greater)
	or a
	ret nz
	ld a,2
	call randint
	dec a
	ld a,T_STAIR_DOWN
	jr z,$+4
	ld a,T_STAIR_UP
	jp ru_stairs
.monster:								; '&': level + 2 + 2 (+1 greater)
	xor a
	ld (rv_mean),a
	ld a,(rv_greater)
	add a,MON_SUMMON_ADJ+2
	jr .mon
.meaner:								; '@': a meaner one, level + 2 + 7
	ld a,1
	ld (rv_mean),a
	ld a,MON_SUMMON_ADJ+7
	jr .mon
.good:									; '8': that, and a good object
	call .meaner
	call ru_at
	ld a,1
	OVCALL PAGE_LEVEL, place_special, PAGE_ROOMS
	ret
.great:									; 'O': a nasty one, level + 2 + 40,
	ld a,1								; and a great object
	ld (rv_mean),a
	ld a,MON_SUMMON_ADJ+40
	call .mon
	call ru_at
	ld a,2
	OVCALL PAGE_LEVEL, place_special, PAGE_ROOMS
	ret
.mon:									; A = levels deeper, rv_mean = 1:
	ld hl,dun_level						; a meaner one. Preserves BC
	add a,(hl)
	jr nc,$+4
	ld a,255
	ld (rv_lvl),a
	push bc
	call ru_at
	ld a,(rv_mean)
	ld h,a
	ld a,(rv_lvl)
	OVCALL PAGE_LEVEL, vault_mon, PAGE_ROOMS
	pop bc
	ret

; ---------------------------------------------------------------- pits

/* build_pit - a monster pit (build_pit, special_pit): by depth a jelly
	pit, an orc pit, a troll pit, a graveyard, a dragon pit or a demon pit,
	an inner room packed with them, the strongest in the middle. Placed
	from the middle out (the C fills from the outside in, but here only
	64 monsters fit a level) */
build_pit:
	ld a,(dun_level)
	cp 81
	jr c,$+4
	ld a,80
	or a
	jr nz,$+3
	inc a
	call randint
	ld b,1
	cp 10
	jr c,.type
	inc b
	cp 20
	jr c,.type
	inc b
	cp 40
	jr c,.type
	inc b
	cp 55
	jr c,.type
	inc b
	cp 72
	jr c,.type
	inc b
.type:
	ld a,b
	ld (rp_type),a
	ld a,T_FLOOR						; (always dark)
	ld (ru_floor),a
	ld bc,-4*256+(-11 & 255)
	ld de,9*256+23
	call ru_room
	ld bc,-3*256+(-10 & 255)
	ld de,7*256+21
	ld a,T_TMP1
	call ru_ring
	ld b,-3
	ld d,3
	ld c,-10
	ld e,10
	call ru_door4
	ld a,6
	call randint
	ld (rp_colour),a
	ld hl,pit_ranks						; column by column, by rank
.each:
	ld a,(hl)
	or a
	ret z
	ld (rp_rank),a
	inc hl
	ld a,(hl)							; the column (dx), all its rows
	inc hl
	ld c,a
	ld a,(hl)							; first row, how many
	inc hl
	ld b,a
	ld a,(hl)
	inc hl
	ld (rp_n),a
	push hl
.cell:
	push bc
	call pit_monster
	pop bc
	inc b
	ld hl,rp_n
	dec (hl)
	jr nz,.cell
	pop hl
	jr .each
; rank, dx, first dy, rows: from the middle (rank 6) out to the edge
pit_ranks:
	db 6,0,-1,3
	db 5,-1,-1,3, 5,1,-1,3, 5,-2,-1,3, 5,2,-1,3
	db 4,-3,-1,3, 4,3,-1,3, 4,-4,-1,3, 4,4,-1,3
	db 3,-5,-1,3, 3,5,-1,3, 3,-6,-1,3, 3,6,-1,3
	db 2,-7,-1,3, 2,7,-1,3, 2,-8,-1,3, 2,8,-1,3
	db 1,-9,-1,3, 1,9,-1,3
	db 1,-9,-2,1, 1,-8,-2,1, 1,-7,-2,1, 1,-6,-2,1, 1,-5,-2,1, 1,-4,-2,1
	db 1,-3,-2,1, 1,-2,-2,1, 1,-1,-2,1, 1,0,-2,1, 1,1,-2,1, 1,2,-2,1
	db 1,3,-2,1, 1,4,-2,1, 1,5,-2,1, 1,6,-2,1, 1,7,-2,1, 1,8,-2,1, 1,9,-2,1
	db 1,-9,2,1, 1,-8,2,1, 1,-7,2,1, 1,-6,2,1, 1,-5,2,1, 1,-4,2,1
	db 1,-3,2,1, 1,-2,2,1, 1,-1,2,1, 1,0,2,1, 1,1,2,1, 1,2,2,1
	db 1,3,2,1, 1,4,2,1, 1,5,2,1, 1,6,2,1, 1,7,2,1, 1,8,2,1, 1,9,2,1
	db 0

/* pit_monster - B, C: one of the pit's (vault_nasty): jellies and
	undead asleep, the rest awake */
pit_monster:
	call ru_at
	ld (rp_at),de
	ld a,(rp_type)
	cp 1
	jr z,.jelly
	cp 4
	jr z,.undead
	ld hl,pit_orc-2						; ranks 1-6 in a table
	cp 2
	jr z,.ranked
	ld hl,pit_troll-2
	cp 3
	jr z,.ranked
	ld hl,pit_demon-2
	cp 6
	jr z,.ranked
	ld a,(rp_colour)					; dragons: by colour
	dec a
	ld e,a
	ld d,12
	mul d,e
	ld hl,pit_dragon-2
	add hl,de
.ranked:
	ld a,(rp_rank)
	add a,a
	add hl,a
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	xor a								; (awake)
	jr .place
.jelly:									; j , i or m, not evil
	call .any
	ld a,(iy+R_CHAR)
	cp 'j'
	jr z,.not_evil
	cp ','
	jr z,.not_evil
	cp 'i'
	jr z,.not_evil
	cp 'm'
	jr nz,.jelly
.not_evil:
	bit RF_EVIL,(iy+R_FLAGS)
	jr nz,.jelly
	jr .asleep
.undead:								; undead, not unique
	call .any
	bit RF_UNDEAD,(iy+R_FLAGS)
	jr z,.undead
	bit RF_UNIQUE,(iy+R_FLAGS)
	jr nz,.undead
.asleep:
	ld hl,(rp_race)
	ld a,1
.place:
	ld de,(rp_at)
	OVCALL PAGE_LEVEL, vault_place, PAGE_ROOMS
	ret
.any:									; a race at random (IY its record)
	ld hl,NUM_RACES
	call randint16
	dec hl
	ld (rp_race),hl
	jp race_addr

; ---------------------------------------------------------------- workspace

ru_y:			db 0				; (ru_y, ru_x as a word: x low)
ru_x:			db 0
ru_floor:		db 0
ru_t:			db 0
ru_n:			db 0
ru_try:			db 0
ru_yd:			dw 0
ru_wide:		db 0
rv_w:			db 0
rv_h:			db 0
rv_greater:		db 0
rv_ptr:			dw 0
rv_wall:		db 0
rv_top:			db 0
rv_left:		db 0
rv_rows:		db 0
rv_cols:		db 0
rv_ch:			db 0
rv_mean:		db 0
rv_lvl:			db 0
rp_type:		db 0
rp_colour:		db 0
rp_rank:		db 0
rp_n:			db 0
rp_at:			dw 0
rp_race:		dw 0

	include "data/vaults.asm"
