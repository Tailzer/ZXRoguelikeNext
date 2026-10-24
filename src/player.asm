/* player.asm - player actions
	Reference: MORIA2.C move_char(), MORIA1.C
 */

/* try_move - B = dx, C = dy. Moves if the square is passable; bumping a
	closed door opens it (Angband's easy_open behaviour) */
try_move:
	ld a,(p_confused)					; confused or stunned: 3 in 4 moves
	ld hl,p_confused+1					; go a random way (move_char)
	or (hl)
	ld hl,(p_stun)
	or h
	or l
	jr z,.steady
	push bc
	ld a,4
	call randint
	pop bc
	cp 2
	jr c,.steady
	ld a,9
	call randint
	cp 5
	jp z,.stay
	dec a
	add a,a
	ld hl,keypad_deltas
	add hl,a
	ld c,(hl)							; dy
	inc hl
	ld b,(hl)							; dx
.steady:
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
	jp nz,.monster
	ld a,1
	ld (turn_taken),a
	ld hl,(player_x)					; (x, y: a rockfall sends you back)
	ld (step_from),hl
	push de
	call lamp_off
	pop de
	ld a,e
	ld (player_x),a
	ld a,d
	ld (player_y),a
	call light_arrive
	ld a,(p_fos)						; noticing things as you go: every
	bit 7,a								; step if the frequency is 1 or less,
	jr nz,.search						; else 1 in that many
	cp 2
	jr c,.search
	call randint
	dec a
	call z,search
	jr .searched
.search:
	FARCALL PAGE_TRAP, search			; (traps.asm)
.searched:
	ld a,(player_y)						; a trap here goes off
	ld d,a
	ld a,(player_x)
	ld e,a
	call trap_at
	jr nc,.no_trap
	FARCALL PAGE_TRAP, hit_trap
	ret									; (a trap's square has no item yet)
.no_trap:
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
	bit F_MON_BIT,(hl)					; a monster you can see in the rock
	jr z,.solid							; (one you can't: just the wall)
	push bc
	push de
	call mon_at
	pop de
	pop bc
	jr nc,.solid
	ld a,(ix+M_ML)
	or a
	jr nz,.monster
.solid:
	ld a,b
	cp T_DOOR_CLOSED
	jr nz,.wall
	FARCALL PAGE_TRAP, bump_door		; open it (or pick its lock)
	ret
.wall:
	ld hl,msg_wall
	jp show_message
.monster:
	call mon_at
	ld hl,(p_afraid)
	ld a,h
	or l
	jp z,py_attack
	ld a,1
	ld (turn_taken),a
	ld hl,msg_too_afraid
	jp show_message
.stay:									; stumbled on the spot
	ld a,1
	ld (turn_taken),a
	ret

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
	ld a,(dun_level)					; the deepest so far, for recall
	ld hl,p_max_dlv
	cp (hl)
	jr c,$+3
	ld (hl),a
	ld hl,msg_generating
	call show_message
	call rng_mix
	ld a,(dun_level)
	or a
	jr z,.town
	FARCALL PAGE_LEVEL, generate_level
	call msg_clear
.spot:									; (somewhere free: rooms may have
	call random_open_spot				;  monsters, objects and traps)
	bit F_MON_BIT,(hl)
	jr nz,.spot
	push de
	call item_at
	pop de
	jr c,.spot
	call trap_at
	jr c,.spot
	ld a,d
	ld (player_y),a
	ld a,e
	ld (player_x),a
	call light_arrive
	FARCALL PAGE_LEVEL, alloc_monsters
	FARCALL PAGE_LEVEL, alloc_items
	FARCALL PAGE_TRAP, alloc_traps
	call update_view
	call monsters_see_all
	FARCALL PAGE_LEVEL, level_feeling	; (generate.asm)
	ret
.town:
	FARCALL PAGE_LEVEL, town_gen
	call msg_clear
	FARCALL PAGE_STORE, store_maint		; the stores restock
	call items_clear					; nothing lying about in town
	FARCALL PAGE_TRAP, alloc_traps		; (no traps either)
	call random_open_spot
	ld a,d
	ld (player_y),a
	ld a,e
	ld (player_x),a
	call light_arrive
	FARCALL PAGE_LEVEL, alloc_town_monsters
	call update_view
	call monsters_see_all
	FARCALL PAGE_LEVEL, level_feeling	; (the turn it began, all the same)
	ret
