/* look.asm - looking around (overlay page PAGE_LOOK)
	References: MORIA2.C look/look_ray/look_see/look_mon_desc, IO.C
	screen_map, DUNGEON.C the locate command and ^P, HELP.C ident_char.
	The message history: msg_print (video.asm) copies every message into
	LOG_PAGE, LOG_LINES of them round and round.
 */

/* look_command - A = 0 look, 1 map, 2 locate, 3 messages, 4 identify a
	symbol (the item overlay's do_look... come here) */
look_command:
	or a
	jp z,do_look
	dec a
	jp z,screen_map
	dec a
	jp z,locate
	dec a
	jp z,show_messages
	dec a
	jp z,ident_char
	jp quit_command

; ---------------------------------------------------------------- look

/* do_look - 'x' (the roguelike keys' look): every monster and object
	you can see in a direction, nearest first, each until a key (space
	stops); 5 looks all round. Takes no turn */
do_look:
	ld hl,(p_blind)
	ld a,h
	or l
	ld hl,ml_damn_thing
	jp nz,msg_print
	ld hl,ml_which_way
	call get_alldir
	ret nc
	ld (lk_dir),a
	dec a
	add a,a
	ld hl,keypad_deltas
	add hl,a
	ld a,(hl)
	ld (lk_dy),a
	inc hl
	ld a,(hl)
	ld (lk_dx),a
	xor a
	ld (lk_seen),a
	ld (lk_ry),a						; where you stand first
	ld (lk_rx),a
	ld hl,ml_you_are_on
	ld (lk_dstring),hl
	call look_see
	jp c,.abort
	ld a,1								; then outwards, a ring at a time
	ld (lk_d),a
.ring:
	ld a,(lk_d)
	neg
	ld (lk_ry),a
.row:
	ld a,(lk_d)							; the ring's top and bottom rows:
	neg									; every square; between, its ends
	ld (lk_rx),a
	ld a,(lk_d)
	ld b,a
	ld a,(lk_ry)
	call lk_abs
	cp b
	jr z,.full
.ends:
	call look_at
	jr c,.abort
	ld a,(lk_d)
	ld (lk_rx),a
	call look_at
	jr c,.abort
	jr .next_row
.full:
	call look_at
	jr c,.abort
	ld a,(lk_d)
	ld hl,lk_rx
	cp (hl)
	jr z,.next_row
	inc (hl)
	jr .full
.next_row:
	ld a,(lk_d)
	ld hl,lk_ry
	cp (hl)
	jr z,.next_ring
	inc (hl)
	jr .row
.next_ring:
	ld hl,lk_d
	inc (hl)
	ld a,(hl)
	cp MAX_SIGHT+1
	jr c,.ring
	ld a,(lk_dir)						; "That's all you see." and so on
	cp 5
	ld a,(lk_seen)
	jr z,.all_round
	or a
	ld hl,ml_all_that_way
	jr nz,.said
	ld hl,ml_nothing_that_way
	jr .said
.all_round:
	or a
	ld hl,ml_all
	jr nz,.said
	ld hl,ml_nothing
.said:
	push hl
	call msg_clear
	pop hl
	jp msg_print
.abort:
	call msg_clear
	ld hl,ml_aborting
	jp msg_print

/* look_at - (lk_ry, lk_rx): looked at if it's in the cone -> carry if the
	look was stopped */
look_at:
	ld a,(lk_dir)
	cp 5
	jr z,.in
	ld a,(lk_dy)						; straight or diagonal?
	or a
	jr z,.straight
	ld a,(lk_dx)
	or a
	jr z,.straight
	ld a,(lk_ry)						; diagonal: a = ry.dy, b = rx.dx both
	ld hl,lk_dy							; > 0, and each at least half the
	call smul							; other (between 26.5 and 63.5 degrees)
	ld c,a
	ld a,(lk_rx)
	ld hl,lk_dx
	call smul
	ld b,a
	ld a,c
	dec a
	jp m,.out
	ld a,b
	dec a
	jp m,.out
	ld a,c								; 2a >= b
	add a,a
	cp b
	jr c,.out
	ld a,b								; 2b >= a
	add a,a
	cp c
	jr c,.out
	jr .in
.straight:								; along > 0, 2|across| <= along
	ld a,(lk_ry)
	ld hl,lk_dy
	call smul
	ld c,a
	ld a,(lk_rx)
	ld hl,lk_dx
	call smul
	add a,c
	ld c,a								; C = along
	dec a
	jp m,.out
	ld a,(lk_dy)						; across: the other one
	or a
	ld a,(lk_ry)
	jr z,$+5
	ld a,(lk_rx)
	call lk_abs
	add a,a
	dec a
	cp c
	jr nc,.out
.in:
	ld hl,ml_you_see
	ld (lk_dstring),hl
	jp look_see
.out:
	or a
	ret

/* look_see - the square at (lk_ry, lk_rx) from you: a monster you can
	see there ("You see a Kobold (unhurt)."), then what lies there, if the
	square is lit or remembered and in sight ("You see a Dagger (1d4)
	---pause---"). Each waits for a key -> carry if it was space */
look_see:
	ld a,(player_y)
	ld hl,lk_ry
	add a,(hl)
	cp MAP_H
	jr nc,.none
	ld d,a
	ld a,(player_x)
	ld hl,lk_rx
	add a,(hl)
	cp MAP_W
	jr nc,.none
	ld e,a
	ld (lk_sq),de
	ld a,(view_y)						; (only what's on the screen)
	ld b,a
	ld a,d
	sub b
	cp VIEW_H
	jr nc,.none
	ld a,(view_x)
	ld b,a
	ld a,e
	sub b
	cp VIEW_W
	jr nc,.none
	call map_addr
	ld a,(hl)
	ld (lk_byte),a
	bit F_MON_BIT,a
	jr z,.objects
	ld de,(lk_sq)
	call mon_at
	jr nc,.objects
	ld a,(ix+M_ML)
	or a
	jr z,.objects
	call describe_monster
	call lk_wait
	ret c
	ld hl,ml_it_is_on
	ld (lk_dstring),hl
.objects:
	ld a,(lk_byte)						; lit or remembered, and in sight
	and F_SEEN
	jr z,.none
	ld a,(lk_ry)
	ld hl,lk_rx
	or (hl)
	jr z,.near							; (your own square)
	ld de,(lk_sq)
	push ix
	call los
	pop ix
	jr nc,.none
.near:
	call describe_object
	jr nc,.none
	call lk_wait
	ret c
.none:
	or a
	ret

/* describe_monster - IX = monster: "You see a Kobold (unhurt)." */
describe_monster:
	call msg_begin
	ld hl,(lk_dstring)
	call msg_add
	call mon_race
	call race_name
	bit RF_UNIQUE,(iy+R_FLAGS)			; (uniques by name)
	jr nz,.name
	push hl
	ld a,(hl)
	call is_vowel
	ld hl,ml_a
	jr nz,$+5
	ld hl,ml_an
	call msg_add
	pop hl
.name:
	call msg_add
	ld hl,ml_open_br
	call msg_add
	call health_word
	call msg_add
	ld hl,ml_close
	call msg_add
	ld hl,lk_seen
	inc (hl)
	ret

/* health_word - IX = monster, IY = race -> HL = "unhurt", "wounded"...
	(look_mon_desc): over 60% somewhat, over 25%, over 10% badly, else
	almost dead; undead and demons are damaged, not wounded */
health_word:
	ld a,(iy+R_FLAGS)
	and 1<<RF_UNDEAD|1<<RF_DEMON
	ld hl,ml_health_living
	jr z,$+5
	ld hl,ml_health_unliving
	ld (lk_words),hl
	ld l,(ix+M_HP)
	ld h,(ix+M_HP+1)
	ld e,(ix+M_MAXHP)
	ld d,(ix+M_MAXHP+1)
	push hl
	or a
	sbc hl,de
	pop hl
	ld b,0
	jr nc,.word							; full: unhurt
	ld (lk_hp),hl
	ld (lk_max),de
	inc b								; 5 hp > 3 max: somewhat
	ld de,5
	call .times_hp
	ld de,3
	call .vs_max
	jr c,.word
	inc b								; 4 hp > max: wounded
	ld de,4
	call .times_hp
	ld de,1
	call .vs_max
	jr c,.word
	inc b								; 10 hp > max: badly
	ld de,10
	call .times_hp
	ld de,1
	call .vs_max
	jr c,.word
	inc b								; almost dead
.word:
	ld a,b
	add a,a
	ld hl,(lk_words)
	add hl,a
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	ret
.times_hp:								; lk_t = hp x DE
	ld hl,(lk_hp)
	call lk_mul
	ld (lk_t),hl
	ret
.vs_max:								; carry if lk_t > max x DE
	push bc
	ld hl,(lk_max)
	call lk_mul
	ex de,hl
	ld hl,(lk_t)
	or a
	sbc hl,de
	pop bc
	jr z,.not
	ccf
	ret
.not:
	or a
	ret

/* describe_object - (lk_sq): what lies there -> carry, and the message
	built ("You see a Dagger (1d4) ---pause---"), if anything does */
describe_object:
	ld de,(lk_sq)
	call item_at
	jr nc,.trap
	ld a,(ix+I_MARKED)					; (one you've seen)
	or a
	jr z,.trap
	call .start
	call objdes_msg
	jp .pause
.trap:
	ld de,(lk_sq)
	call trap_at
	jr nc,.feature
	bit TRF_SEEN,(ix+TR_FLAGS)
	jr z,.feature
	call .start
	OVCALL PAGE_TRAP, trap_name_add, PAGE_LOOK
	jr .pause
.feature:
	ld a,(lk_byte)
	and TERRAIN_MASK
	ld hl,ml_closed_door
	cp T_DOOR_CLOSED
	jr z,.named
	ld hl,ml_open_door
	cp T_DOOR_OPEN
	jr z,.named
	ld hl,ml_up_stairs
	cp T_STAIR_UP
	jr z,.named
	ld hl,ml_down_stairs
	cp T_STAIR_DOWN
	jr z,.named
	ld hl,ml_rubble
	cp T_RUBBLE
	jr z,.named
	cp T_STORE
	jr z,.store
	or a
	ret
.store:									; "the entrance to the General Store"
	call .start
	ld hl,ml_entrance
	call msg_add
	ld de,(lk_sq)
	ld hl,STORE_DOOR
	ld b,0
.which:
	ld a,(hl)
	inc hl
	cp d
	ld a,(hl)
	inc hl
	jr nz,.next_store
	cp e
	jr z,.store_name
.next_store:
	inc b
	ld a,b
	cp NUM_STORES
	jr c,.which
.store_name:
	ld a,b
	add a,a
	ld hl,ml_stores
	add hl,a
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	jr .add
.named:
	push hl
	call .start
	pop hl
.add:
	call msg_add
.pause:
	ld hl,ml_pause
	call msg_add
	ld hl,lk_seen
	inc (hl)
	scf
	ret
.start:
	call msg_begin
	ld hl,(lk_dstring)
	call msg_add
	ld hl,ml_space
	jp msg_add

/* lk_wait - show the message built, wait for a key -> carry if space */
lk_wait:
	call msg_clear
	ld hl,(msg_ptr)
	ld (hl),0
	ld hl,msg_buf
	ld d,MSG_ROW
	ld e,0
	ld c,ATTR_WHITE
	call print_at
	call read_ascii
	push af
	call msg_clear
	pop af
	cp ' '
	scf
	ret z
	or a
	ret

/* get_alldir - HL = question -> carry and A = 1-9 (5: all round), or no
	carry (space). The movement letters or 1-9 */
get_alldir:
	call prompt
.key:
	call read_ascii
	cp ' '
	jr z,.cancel
	cp '1'
	jr c,.letter
	cp '9'+1
	jr nc,.letter
	sub '0'
	jr .got
.letter:
	ld hl,dir_letters
	ld bc,9
	cpir
	jr nz,.key
	ld a,9
	sub c
.got:
	push af
	call msg_clear
	pop af
	scf
	ret
.cancel:
	call msg_clear
	or a
	ret
dir_letters:	db "bjnh.lyku"			; directions 1-9 ('.' can't be typed)

/* lk_mul - HL x DE -> HL (16 bits). Preserves BC */
lk_mul:
	push bc
	ld b,h
	ld c,l
	ld hl,0
	ld a,16
.bit:
	add hl,hl
	ex de,hl
	add hl,hl
	ex de,hl
	jr nc,.skip
	add hl,bc
.skip:
	dec a
	jr nz,.bit
	pop bc
	ret

/* smul - A = value, (HL) = -1, 0 or 1 -> A = value x it */
smul:
	ld b,a
	ld a,(hl)
	or a
	ret z
	ld a,b
	bit 7,(hl)
	ret z
	neg
	ret
/* lk_abs - A = |A| */
lk_abs:
	bit 7,a
	ret z
	neg
	ret

; ---------------------------------------------------------------- the map

/* screen_map - 'M': the whole level, a third the size: each 3 x 3 shows
	the most important thing in it ('@' over stairs over anything else
	over doors over walls over floors over nothing), in a border, until a
	key (screen_map in IO.C) */
screen_map:
	call clear_screen
	ld d,SM_TOP							; the border
	call sm_edge
	ld d,SM_TOP+MAP_H/3+1
	call sm_edge
	ld d,SM_TOP+1
.side:
	push de
	ld e,SM_LEFT
	call screen_addr
	ld (hl),'|'
	pop de
	push de
	ld e,SM_LEFT+MAP_W/3+1
	call screen_addr
	ld (hl),'|'
	pop de
	inc d
	ld a,d
	cp SM_TOP+MAP_H/3+1
	jr c,.side
	ld d,0								; the terrain you know of
.map_row:
	ld e,0
	push de
	call map_addr
	pop de
.map_col:
	ld a,(hl)
	inc hl
	ld c,a
	and F_SEEN
	ld a,' '
	jr z,.blank
	ld a,c
	and TERRAIN_MASK
	push hl
	add a,a
	add a,a
	ld hl,terrain_table
	add hl,a
	ld a,(hl)
	inc hl
	ld c,(hl)
	pop hl
	ld b,a
	call sm_plot
.blank:
	inc e
	ld a,e
	cp MAP_W
	jr c,.map_col
	inc d
	ld a,d
	cp MAP_H
	jr c,.map_row
	ld ix,ITEM_LIST						; items you've seen
	ld b,ITEM_MAX
.item:
	push bc
	ld a,(ix+I_KIND_HI)
	cp ITEM_EMPTY
	jr z,.next_item
	ld a,(ix+I_MARKED)
	or a
	jr z,.next_item
	call item_glyph
	ld d,(ix+I_Y)
	ld e,(ix+I_X)
	call sm_plot
.next_item:
	ld de,ITEM_SIZE
	add ix,de
	pop bc
	djnz .item
	ld ix,TRAP_LIST						; traps you've found
	ld b,TRAP_MAX
.trap:
	push bc
	ld a,(ix+TR_TYPE)
	or a
	jr z,.next_trap
	bit TRF_SEEN,(ix+TR_FLAGS)
	jr z,.next_trap
	ld d,(ix+TR_Y)
	ld e,(ix+TR_X)
	ld bc,'^'*256+ATTR_RED
	call sm_plot
.next_trap:
	ld de,TRAP_SIZE
	add ix,de
	pop bc
	djnz .trap
	ld ix,MON_LIST						; monsters in view
	ld b,MON_MAX
.mon:
	push bc
	ld a,(ix+M_RACE_HI)
	cp MON_EMPTY
	jr z,.next_mon
	ld a,(ix+M_ML)
	or a
	jr z,.next_mon
	call mon_race
	ld b,(iy+R_CHAR)
	ld c,(iy+R_ATTR)
	ld d,(ix+M_Y)
	ld e,(ix+M_X)
	call sm_plot
.next_mon:
	ld de,MON_SIZE
	add ix,de
	pop bc
	djnz .mon
	ld a,(player_y)						; and you
	ld d,a
	ld a,(player_x)
	ld e,a
	ld bc,'@'*256+ATTR_YELLOW
	call sm_plot
	ld hl,ml_any_key
	ld d,SCREEN_H-1
	ld e,0
	ld c,ATTR_GREY
	call print_at
	call read_ascii
	jp clear_screen

/* sm_plot - D = y, E = x, B = character, C = attribute: shown in the
	reduced map's cell for that square if it matters more than what's
	there. Preserves DE, HL, IX */
sm_plot:
	push de
	push hl
	ld a,d								; the cell: (y/3, x/3)
	push bc
	ld c,3
	call div8
	add a,SM_TOP+1
	ld d,a
	ld a,e
	call div8
	pop bc
	add a,SM_LEFT+1
	ld e,a
	call screen_addr
	ld a,(hl)							; what's there now
	push hl
	call sm_priority
	ld e,a
	ld a,b
	call sm_priority
	pop hl
	cp e								; more important (signed)
	jp m,.keep
	jr z,.keep
	ld (hl),b
	inc hl
	ld (hl),c
.keep:
	pop hl
	pop de
	ret
/* sm_priority - A = character -> A = how much it matters (+ 128, so it
	compares unsigned... kept signed here: '@' 10, stairs 5, doors' -3,
	walls -5, floor -10, nothing -15, anything else 0) */
sm_priority:
	push hl
	push bc
	ld hl,sm_priorities
	ld b,a
.find:
	ld a,(hl)
	or a
	jr z,.other
	cp b
	inc hl
	ld a,(hl)
	inc hl
	jr nz,.find
	pop bc
	pop hl
	ret
.other:
	xor a
	pop bc
	pop hl
	ret
sm_priorities:	db '@',10, '<',5, '>',5, "'",-3, '#',-5, '%',-5, '.',-10, ' ',-15, 0
/* sm_edge - D = row: +---...---+ */
sm_edge:
	ld e,SM_LEFT
	call screen_addr
	ld (hl),'+'
	inc hl
	inc hl
	ld b,MAP_W/3
.dash:
	ld (hl),'-'
	inc hl
	inc hl
	djnz .dash
	ld (hl),'+'
	ret
SM_TOP		equ 2
SM_LEFT		equ (SCREEN_W-MAP_W/3-2)/2

; ---------------------------------------------------------------- locate

/* locate - 'W' (where): the view moves round the level half a screen at a
	time, "Map sector [y,x], which is north of your sector. Look which
	direction?", until a key that isn't a direction */
locate:
	ld a,(view_y)
	ld (lc_home_y),a
	ld (lc_y),a
	ld a,(view_x)
	ld (lc_home_x),a
	ld (lc_x),a
.show:
	ld a,(lc_y)
	ld (view_y),a
	ld a,(lc_x)
	ld (view_x),a
	call draw_map						; (draw_view, without recentring)
	call msg_begin						; "Map sector [2,1], which is
	ld hl,ml_sector						; north-east of your sector."
	call msg_add
	ld a,(lc_y)
	call sector_y
	ld (lc_sy),a
	call msg_add_u8
	ld hl,ml_comma
	call msg_add
	ld a,(lc_x)
	call sector_x
	ld (lc_sx),a
	call msg_add_u8
	ld hl,ml_which_is
	call msg_add
	ld a,(lc_home_y)
	call sector_y
	ld b,a
	ld a,(lc_sy)
	ld hl,ml_north
	cp b
	jr c,.ns
	ld hl,ml_south
	jr nz,.ns
	ld hl,0
.ns:
	ld (lc_ns),hl
	ld a,(lc_home_x)
	call sector_x
	ld b,a
	ld a,(lc_sx)
	ld hl,ml_west
	cp b
	jr c,.we
	ld hl,ml_east
	jr nz,.we
	ld hl,0
.we:
	ld de,(lc_ns)						; nothing either way: "is your
	ld a,h								; sector"
	or l
	or d
	or e
	jr nz,.away
	jr .tail
.away:									; " north-east of", " east of"...
	ld a,d
	or e
	jr z,.no_ns
	push hl
	ex de,hl
	call msg_add
	pop hl
	ld a,h
	or l
	jr z,.of
	push hl
	ld hl,ml_dash
	call msg_add
	pop hl
	call msg_add
	jr .of
.no_ns:
	push hl
	ld hl,ml_is
	call msg_add
	pop hl
	call msg_add
.of:
	ld hl,ml_of
	call msg_add
.tail:
	ld hl,ml_your_sector
	call msg_add
	ld hl,(msg_ptr)
	ld (hl),0
	call msg_clear
	ld hl,msg_buf
	ld d,MSG_ROW
	ld e,0
	ld c,ATTR_YELLOW
	call print_at
	call read_ascii						; a direction moves the view
	ld hl,dir_letters
	ld bc,9
	cpir
	jr z,.letter
	sub '1'
	cp 9
	jr nc,.done
	jr .step
.letter:
	ld a,8
	sub c
.step:
	add a,a
	ld hl,keypad_deltas
	add hl,a
	ld a,(hl)							; dy x half a view
	push hl
	ld e,VIEW_H/2
	call lc_move
	ld hl,lc_y
	ld b,MAP_H-VIEW_H
	call lc_add
	pop hl
	inc hl
	ld a,(hl)							; dx x half a view
	ld e,VIEW_W/2
	call lc_move
	ld hl,lc_x
	ld b,MAP_W-VIEW_W
	call lc_add
	jp .show
.done:
	ld a,(lc_home_y)					; back where it was
	ld (view_y),a
	ld a,(lc_home_x)
	ld (view_x),a
	jp msg_clear
/* lc_move - A = -1, 0 or 1, E = step -> A = the change */
lc_move:
	or a
	ret z
	bit 7,a
	ld a,e
	ret z
	neg
	ret
/* lc_add - A = change (signed), HL = position, B = its most: added,
	kept 0..B */
lc_add:
	ld c,a
	ld a,(hl)
	add a,c
	bit 7,c
	jr z,.most
	jr c,.most							; (a fall below 0 has no carry)
	xor a
	jr .set
.most:
	cp b
	jr c,.set
	ld a,b
.set:
	ld (hl),a
	ret
/* sector_y, sector_x - A = view y or x -> A = its sector (half views) */
sector_y:
	ld c,VIEW_H/2
	jp div8
sector_x:
	ld c,VIEW_W/2
	jp div8

; ---------------------------------------------------------------- messages

/* log_clear - an empty history (at start-up) */
log_clear:
	nextreg NR_MMU7,PAGE_LOG
	ld hl,LOG_BASE
	ld de,LOG_BASE+1
	ld bc,LOG_LINES*LOG_LEN-1
	ld (hl),0
	ldir
	nextreg NR_MMU7,MAP_PAGE+1
	xor a
	ld (log_next),a
	ret

/* show_messages - ^P (Symbol Shift + P): the last messages, oldest at the
	top, until a key */
show_messages:
	call clear_screen
	ld a,(log_next)						; the oldest of the last SCREEN_H-2
	sub SCREEN_H-2
	and LOG_LINES-1
	ld (lk_d),a
	ld d,0
.line:
	push de
	nextreg NR_MMU7,PAGE_LOG			; the line, copied out (the map's
	ld a,(lk_d)							; page is back before printing)
	ld e,a
	ld d,LOG_LEN
	mul d,e
	ld hl,LOG_BASE
	add hl,de
	ld de,lk_line
	ld bc,LOG_LEN
	ldir
	nextreg NR_MMU7,MAP_PAGE+1
	pop de
	push de
	ld hl,lk_line
	ld e,0
	ld c,ATTR_WHITE
	call print_at
	pop de
	inc d
	ld a,(lk_d)
	inc a
	and LOG_LINES-1
	ld (lk_d),a
	ld a,d
	cp SCREEN_H-2
	jr c,.line
	ld hl,ml_any_key
	ld d,SCREEN_H-1
	ld e,0
	ld c,ATTR_GREY
	call print_at
	call read_ascii
	jp clear_screen

; ---------------------------------------------------------------- symbols

/* ident_char - '/' (Symbol Shift + V): "Enter character to be identified
	:", then what it stands for (HELP.C). Symbol Shift gives the Spectrum's
	symbols; [ ] { } | ~ \ need extended mode, so can't be asked about */
ident_char:
	ld hl,ml_enter_char
	call prompt
	call read_key_sym
	ld (lk_char),a
	call msg_clear
	ld a,(lk_char)
	cp '@'								; '@': you
	jr nz,.table
	ld hl,p_name
	jp msg_print
.table:
	ld hl,symbol_table
	ld b,a
.find:
	ld a,(hl)
	or a
	jr z,.unused
	cp b
	inc hl
	jr z,.found
.skip:
	ld a,(hl)
	inc hl
	or a
	jr nz,.skip
	jr .find
.found:
	jp msg_print
.unused:
	ld hl,ml_not_used
	jp msg_print

/* read_key_sym - wait for a key -> A = its character, with Caps Shift
	(capitals) or Symbol Shift (the symbol printed in red on its key:
	read_ascii notes whether it was held) */
read_key_sym:
	call read_ascii
	ld b,a
	ld a,(ascii_sym)
	and %00000010
	ld a,b
	ret z								; (not held: as typed)
	ld hl,sym_keys
.find:
	ld a,(hl)
	or a
	jr z,.plain
	inc hl
	cp b
	ld a,(hl)
	inc hl
	ret z
	jr .find
.plain:
	ld a,b
	ret
; key, then what Symbol Shift makes it
sym_keys:	db "1!2@3#4$5%6&7'8(9)0_r<t>o;p",'"',"h^j-k+l=z:c?v/b*n,m."
			db 0

; ---------------------------------------------------------------- words

ml_damn_thing:	db "You can't see a damn thing!",0
ml_which_way:	db "Look which direction?",0
ml_you_are_on:	db "You are on",0
ml_you_see:		db "You see",0
ml_it_is_on:	db "It is on",0
ml_space:		db " ",0
ml_a:			db " a ",0
ml_an:			db " an ",0
ml_open_br:		db " (",0
ml_close:		db ").",0
ml_pause:		db " ---pause---",0
ml_all:			db "That's all you see.",0
ml_all_that_way: db "That's all you see in that direction.",0
ml_nothing:		db "You see nothing of interest.",0
ml_nothing_that_way: db "You see nothing of interest in that direction.",0
ml_aborting:	db "--Aborting look--",0
ml_closed_door:	db "a closed door",0
ml_open_door:	db "an open door",0
ml_up_stairs:	db "an up staircase",0
ml_down_stairs:	db "a down staircase",0
ml_rubble:		db "some rubble",0
ml_entrance:	db "the entrance to the ",0
ml_stores:		dw mls_1, mls_2, mls_3, mls_4, mls_5, mls_6, mls_7, mls_8
mls_1:			db "General Store",0
mls_2:			db "Armoury",0
mls_3:			db "Weapon Smiths",0
mls_4:			db "Temple",0
mls_5:			db "Alchemy Shop",0
mls_6:			db "Magic Shop",0
mls_7:			db "Black Market",0
mls_8:			db "Home",0
ml_health_living:	dw mlh_0, mlh_1, mlh_2, mlh_3, mlh_4
ml_health_unliving:	dw mlh_0u, mlh_1u, mlh_2u, mlh_3u, mlh_4u
mlh_0:			db "unhurt",0
mlh_1:			db "somewhat wounded",0
mlh_2:			db "wounded",0
mlh_3:			db "badly wounded",0
mlh_4:			db "almost dead",0
mlh_0u:			db "undamaged",0
mlh_1u:			db "somewhat damaged",0
mlh_2u:			db "damaged",0
mlh_3u:			db "badly damaged",0
mlh_4u:			db "almost destroyed",0
ml_any_key:		db "Press any key.",0
ml_sector:		db "Map sector [",0
ml_comma:		db ",",0
ml_which_is:	db "], which is",0
ml_is:			db " ",0
ml_north:		db " north",0
ml_south:		db " south",0
ml_east:		db "east",0
ml_west:		db "west",0
ml_dash:		db "-",0
ml_of:			db " of",0
ml_your_sector:	db " your sector. Look which direction?",0
ml_enter_char:	db "Enter character to be identified :",0
ml_not_used:	db "Not Used.",0

; character, then what it is (ident_char in HELP.C)
symbol_table:
	db ' ',"  - An open pit.",0
	db '!',"! - A potion.",0
	db '"',34," - An amulet, periapt, or necklace.",0
	db '#',"# - A stone wall.",0
	db '$',"$ - Treasure.",0
	db '%',"% - A magma or quartz vein.",0
	db '&',"& - Demon (Oh dear!).",0
	db "'","' - An open door.",0
	db '(',"( - Soft armor.",0
	db ')',") - A shield.",0
	db '*',"* - Gems.",0
	db '+',"+ - A closed door.",0
	db ',',", - Food or mushroom patch.",0
	db '-',"- - A wand",0
	db '.',". - Floor.",0
	db '/',"/ - A pole weapon.",0
	db '1',"1 - Entrance to General Store.",0
	db '2',"2 - Entrance to Armory.",0
	db '3',"3 - Entrance to Weaponsmith.",0
	db '4',"4 - Entrance to Temple.",0
	db '5',"5 - Entrance to Alchemy shop.",0
	db '6',"6 - Entrance to Magic-Users store.",0
	db '7',"7 - Entrance to the Healers.",0
	db '8',"8 - Entrance to your home.",0
	db ':',": - Rubble.",0
	db ';',"; - A loose rock.",0
	db '<',"< - An up staircase.",0
	db '=',"= - A ring.",0
	db '>',"> - A down staircase.",0
	db '?',"? - A scroll.",0
	db 'A',"A - Angel.",0
	db 'B',"B - Birds",0
	db 'C',"C - Canine.",0
	db 'D',"D - An Ancient Dragon (Beware).",0
	db 'E',"E - Elemental.",0
	db 'F',"F - Giant Fly.",0
	db 'G',"G - Ghost.",0
	db 'H',"H - Hybrid.",0
	db 'I',"I - Minor Demon.",0
	db 'J',"J - Jabberwock.",0
	db 'K',"K - Killer Beetle.",0
	db 'L',"L - Lich.",0
	db 'M',"M - Mummy.",0
	db 'O',"O - Ogre.",0
	db 'P',"P - Giant humanoid.",0
	db 'Q',"Q - Quylthulg (Pulsing Flesh Mound).",0
	db 'R',"R - Reptiles and Amphibians.",0
	db 'S',"S - Giant Scorpion/Spider.",0
	db 'T',"T - Troll.",0
	db 'U',"U - Umber Hulk.",0
	db 'V',"V - Vampire.",0
	db 'W',"W - Wight or Wraith.",0
	db 'X',"X - Xorn/Xaren.",0
	db 'Y',"Y - Yeti.",0
	db 'Z',"Z - Zepher hound (Elemental hound).",0
	db '^',"^ - A trap.",0
	db '_',"_ - A staff.",0
	db 'a',"a - Giant Ant/Ant Lion.",0
	db 'b',"b - Giant Bat.",0
	db 'c',"c - Giant Centipede.",0
	db 'd',"d - a Dragon.",0
	db 'e',"e - Floating Eye.",0
	db 'f',"f - Felines",0
	db 'g',"g - Golem.",0
	db 'h',"h - Humanoid (Dwarf, Elf, Halfling)",0
	db 'i',"i - Icky Thing.",0
	db 'j',"j - Jelly.",0
	db 'k',"k - Kobold.",0
	db 'l',"l - Giant Louse.",0
	db 'm',"m - Mold.",0
	db 'n',"n - Naga.",0
	db 'o',"o - Orc.",0
	db 'p',"p - Person (Humanoid).",0
	db 'q',"q - Quadroped.",0
	db 'r',"r - Rodent.",0
	db 's',"s - Skeleton.",0
	db 't',"t - Giant Tick.",0
	db 'v',"v - Vortex.",0
	db 'w',"w - Worm or Worm Mass.",0
	db 'y',"y - Yeek.",0
	db 'z',"z - Zombie.",0
	db '{',"{ - Arrow, bolt, or bullet.",0
	db '|',"| - A sword or dagger.",0
	db '}',"} - Bow, crossbow, or sling.",0
	db '~',"~ - Tool or miscellaneous item.",0
	db 0

; ---------------------------------------------------------------- workspace

lk_dir:			db 0
lk_dy:			db 0
lk_dx:			db 0
lk_d:			db 0
lk_ry:			db 0
lk_rx:			db 0
lk_seen:		db 0
lk_sq:			dw 0
lk_byte:		db 0
lk_dstring:		dw 0
lk_words:		dw 0
lk_hp:			dw 0
lk_max:			dw 0
lk_t:			dw 0
lk_char:		db 0
lc_home_y:		db 0
lc_home_x:		db 0
lc_y:			db 0
lc_x:			db 0
lc_sy:			db 0
lc_sx:			db 0
lc_ns:			dw 0
lk_line:		ds LOG_LEN
