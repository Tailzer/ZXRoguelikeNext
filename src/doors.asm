/* doors.asm - opening, closing, bashing and spiking doors (overlay page
	PAGE_TRAP, after rest_run.asm)
	References: MORIA2.C openobject/closeobject/bash/py_bash, DUNGEON.C
	jamdoor, GENERATE.C place_door, CREATURE.C make_move (monsters and
	doors) and the stun in mon_move.
	A door's number (the C's p1) is kept in DOOR_LIST by its square's
	address: a closed door's above 0 is locked, below 0 stuck (spikes make
	it more so); an open door's not 0 is broken. A door not in the list is
	0. The list holds DOORS_KEPT; a door that doesn't fit is a plain one.
 */

; ---------------------------------------------------------------- the list

/* door_get - HL = a door's square -> A = its number (0 if none), DE = its
	entry if it has one (carry). Preserves HL */
door_get:
	ld de,DOOR_LIST
	ld b,DOORS_KEPT
.each:
	ld a,(de)
	cp l
	jr nz,.next
	inc de
	ld a,(de)
	dec de
	cp h
	jr nz,.next
	inc de
	inc de
	ld a,(de)
	dec de
	dec de
	scf
	ret
.next:
	inc de
	inc de
	inc de
	djnz .each
	xor a
	ret

/* door_set - HL = a door's square, A = its number: kept (0: forgotten).
	Preserves HL */
door_set:
	push bc
	push de
	ld c,a
	call door_get						; DE = its entry
	jr c,.found
	ld a,c
	or a
	jr z,.done
	push hl								; a free entry (address 0)
	ld hl,0
	call door_get
	pop hl
	jr nc,.done							; (full: a plain door)
	ex de,hl
	ld (hl),e
	inc hl
	ld (hl),d
	inc hl
	ld (hl),c
	ex de,hl
	jr .done
.found:
	ld a,c
	or a
	jr nz,.number
	ex de,hl							; forgotten: the entry's free
	ld (hl),a
	inc hl
	ld (hl),a
	ex de,hl
	jr .done
.number:
	inc de
	inc de
	ld (de),a
.done:
	pop de
	pop bc
	ret

/* doors_clear - a new level: no doors yet */
doors_clear:
	ld hl,DOOR_LIST
	ld b,DOORS_KEPT*DOOR_SIZE
.zero:
	ld (hl),0
	inc hl
	djnz .zero
	ret

; ---------------------------------------------------------------- commands

/* door_command - A = 0 open, 1 close, 2 bash, 3 spike: which way, then
	the command (the item overlay's cmd_open... come here) */
door_command:
	ld (dc_which),a
	OVCALL PAGE_DEVICE, get_dir, PAGE_TRAP	; (confused: astray)
	ret nc
	call dir_square						; D, E (traps.asm)
	ld (dc_sq),de
	ld a,(dc_which)
	or a
	jr z,door_open
	dec a
	jp z,door_close
	dec a
	jp z,door_bash
	jp door_spike

/* bump_door - D, E = a closed door the player walked into: as 'o', and
	"You open the door." if it opens */
bump_door:
	ld (dc_sq),de
	call door_open
	ld de,(dc_sq)
	call map_addr
	ld a,(hl)
	and TERRAIN_MASK
	cp T_DOOR_OPEN
	ret nz
	ld hl,msg_door_open
	jp msg_print

/* door_open - 'o' at (dc_sq): pick a lock (disarming skill against its
	number), find it stuck, or open it; or open a chest (chests.asm) */
door_open:
	ld de,(dc_sq)
	call map_addr
	ld a,(hl)
	and TERRAIN_MASK
	cp T_DOOR_CLOSED
	jr nz,.nothing
	call in_the_way						; a monster on it
	ret c
	ld a,1
	ld (turn_taken),a
	ld de,(dc_sq)
	call map_addr
	call door_get
	or a
	jr z,.open
	jp m,.stuck
	ld (dc_num),a
	ld hl,(p_confused)
	ld a,h
	or l
	ld hl,md_too_confused
	jp nz,msg_print
	call lock_skill						; skill - number > 1d100
	ld a,(dc_num)
	ld e,a
	ld d,0
	or a
	sbc hl,de
	bit 7,h
	jr nz,.failed
	push hl
	ld a,100
	call randint
	pop hl
	ld e,a
	ld d,0
	or a
	sbc hl,de
	jr z,.failed
	jr c,.failed
	ld hl,md_picked						; + 1 experience
	call msg_print
	ld hl,1
	call add_exp
	call check_level_up
	ld de,(dc_sq)
	call map_addr
	xor a
	call door_set
	jr .open
.failed:
	ld hl,md_failed_pick
	jp msg_print
.stuck:
	ld hl,md_stuck
	jp msg_print
.open:
	ld de,(dc_sq)
	call map_addr
	ld a,(hl)
	and ~TERRAIN_MASK
	or T_DOOR_OPEN
	ld (hl),a
	ret
.nothing:								; a chest?
	ld de,(dc_sq)
	call chest_at
	ld hl,md_nothing_open
	jp nc,msg_print
	ld a,1
	ld (turn_taken),a
	call in_the_way
	ret c
	ld de,(dc_sq)
	OVCALL PAGE_CHEST, chest_open, PAGE_TRAP
	ret

/* door_close - 'c': an open door closes, unless it's broken */
door_close:
	ld de,(dc_sq)
	call map_addr
	ld a,(hl)
	and TERRAIN_MASK
	cp T_DOOR_OPEN
	ld hl,md_nothing_close
	jp nz,msg_print
	ld a,1
	ld (turn_taken),a
	call in_the_way
	ret c
	ld de,(dc_sq)
	call map_addr
	call door_get
	or a
	ld hl,md_broken
	jp nz,msg_print
	ld de,(dc_sq)
	call map_addr
	ld a,(hl)
	and ~TERRAIN_MASK
	or T_DOOR_CLOSED
	ld (hl),a
	ret

/* in_the_way - (dc_sq): carry and "The Orc is in your way!" if a monster
	stands there ("Something", unseen) */
in_the_way:
	ld de,(dc_sq)
	call map_addr
	bit F_MON_BIT,(hl)
	ret z
	ld de,(dc_sq)
	call mon_at
	ret nc
	call msg_begin
	ld a,(ix+M_ML)
	or a
	ld hl,md_something
	jr z,.said
	ld a,1
	ld (name_cap),a
	call mon_race
	call mon_name_to_msg
	ld hl,md_in_your_way
.said:
	call msg_add
	call msg_end
	scf
	ret

/* door_bash - 'f' (force): a monster there gets a shield bash; a closed
	door is shouldered, STR and weight against its number; a chest is
	bashed (chests.asm) */
door_bash:
	ld a,1
	ld (turn_taken),a
	ld de,(dc_sq)
	call map_addr
	bit F_MON_BIT,(hl)
	jr z,.door
	ld de,(dc_sq)
	call mon_at
	jr nc,.door
	ld hl,(p_afraid)
	ld a,h
	or l
	ld hl,md_afraid
	jp nz,msg_print
	jp py_bash
.door:
	ld de,(dc_sq)
	call map_addr
	ld a,(hl)
	and TERRAIN_MASK
	cp T_DOOR_CLOSED
	jr z,.smash
	ld de,(dc_sq)						; a chest?
	call chest_at
	jr nc,.nothing
	OVCALL PAGE_CHEST, chest_bash, PAGE_TRAP
	ret
.nothing:
	xor a
	ld (turn_taken),a
	ld hl,md_nothing_bash
	jp msg_print
.smash:
	call door_get						; |number|
	bit 7,a
	jr z,$+4
	neg
	ld (dc_num),a
	ld hl,md_smash
	call msg_print
	ld a,(p_stat_use+A_STR)				; tmp = STR + weight / 2
	ld l,a
	ld h,0
	ld de,(p_wt)
	srl d
	rr e
	add hl,de
	ld (dc_tmp),hl
	ld a,(dc_num)						; 1d(tmp * (20 + n)) <
	add a,20							; 10 * (tmp - n)
	ld e,a
	ld d,0
	call mul16							; HL = tmp * (20 + n)
	call randint16
	push hl
	ld hl,(dc_tmp)
	ld a,(dc_num)
	ld e,a
	ld d,0
	or a
	sbc hl,de
	ld de,10
	call mul16_signed					; HL = 10 * (tmp - n)
	pop de
	ex de,hl							; roll - limit
	or a
	sbc hl,de
	jp m,.crash
	ld a,150							; off balance: 1d150 > DEX
	call randint
	ld hl,p_stat_use+A_DEX
	cp (hl)
	jr z,.firm
	jr c,.firm
	ld hl,md_off_balance
	jp off_balance
.firm:
	ld hl,md_holds_firm
	jp msg_print
.crash:									; open, half the time broken, and
	ld hl,md_crashes_open				; you go through
	call msg_print
	ld de,(dc_sq)
	call map_addr
	ld a,(hl)
	and ~TERRAIN_MASK
	or T_DOOR_OPEN
	ld (hl),a
	push hl
	ld a,2
	call randint
	pop hl
	dec a
	call door_set
	ld hl,(p_confused)
	ld a,h
	or l
	ret nz
	ld a,(tr_dx)
	ld b,a
	ld a,(tr_dy)
	ld c,a
	jp try_move

/* off_balance - HL = what's said: paralysed 1 + 1d2 */
off_balance:
	call msg_print
	ld a,2
	call randint
	inc a
	ld (p_paralysed),a
	ret

/* py_bash - IX = the monster: a shield bash (py_bash in MORIA2.C): to-hit
	STR + shield weight / 2 + your weight / 10 (much less unseen) with DEX
	as the pluses; the shield's dice, maybe a critical, + weight / 60 + 3;
	if it lives, maybe stunned; and 1d150 > DEX: off balance */
py_bash:
	ld (ix+M_SLEEP),0
	ld (ix+M_SLEEP+1),0
	ld (dc_mon),ix
	ld a,(EQUIP+EQ_SHIELD*ITEM_SIZE+I_KIND_HI)	; the shield, or nothing
	ld hl,0
	ld b,0
	ld c,0
	cp ITEM_EMPTY
	jr z,.no_shield
	ld ix,EQUIP+EQ_SHIELD*ITEM_SIZE
	call item_dice
	ld c,b
	ld b,a
	ld l,(iy+K_WEIGHT)
	ld h,(iy+K_WEIGHT+1)
.no_shield:
	ld (dc_sweight),hl
	ld (dc_dice),bc
	ld ix,(dc_mon)
	call mon_race
	ld hl,(dc_sweight)
	srl h								; base = STR + shield / 2 + wt / 10
	rr l
	ld a,(p_stat_use+A_STR)
	add hl,a
	push hl
	ld hl,(p_wt)
	ld c,10
	call div16_8
	pop de
	add hl,de
	ld a,(ix+M_ML)
	or a
	jr nz,.seen
	srl h								; unseen: base / 2 - DEX x 2 - lev x
	rr l								; adj / 2
	ld a,(p_stat_use+A_DEX)
	ld e,a
	ld d,0
	or a
	sbc hl,de
	sbc hl,de
	ld a,(p_cla_bth)
	srl a
	ld e,a
	ld a,(p_lev)
	ld d,a
	mul d,e
	or a
	sbc hl,de
.seen:
	ld a,(p_stat_use+A_DEX)				; + DEX x 3 + lev x adj
	ld e,a
	ld d,0
	add hl,de
	add hl,de
	add hl,de
	ld a,(p_cla_bth)
	ld e,a
	ld a,(p_lev)
	ld d,a
	mul d,e
	add hl,de
	ld a,(iy+R_AC)
	call test_hit
	jr c,.hit
	ld hl,txt_you_miss					; "You miss the Orc."
	call .say
	jp .balance
.hit:
	ld hl,txt_you_hit
	call .say
	ld bc,(dc_dice)
	call damroll
	ld (dc_tmp),hl
	ld hl,(w_weight)					; critical_blow(shield / 4 + STR, 0)
	push hl
	ld a,(p_tohit)
	push af
	ld hl,(dc_sweight)
	srl h
	rr l
	srl h
	rr l
	ld a,(p_stat_use+A_STR)
	add hl,a
	ld (w_weight),hl
	xor a
	ld (p_tohit),a
	ld hl,(dc_tmp)
	call critical_blow
	ld (dc_tmp),hl
	pop af
	ld (p_tohit),a
	pop hl
	ld (w_weight),hl
	ld hl,(dc_tmp)
	push hl								; + weight / 60 + 3
	ld hl,(p_wt)
	ld c,60
	call div16_8
	pop de
	add hl,de
	inc hl
	inc hl
	inc hl
	ld ix,(dc_mon)
	call mon_take_hit
	jr c,.balance						; dead ("You have slain...")
	call mon_race						; stunned? 100 + 1d400 + 1d400 >
	ld b,(iy+R_HD_DICE)					; hp + the average maximum
	ld c,(iy+R_HD_SIDES)
	ld e,b
	ld d,c
	mul d,e
	bit RF_MAX_HP,(iy+R_FLAGS)
	jr nz,.avg
	ld a,c								; (dice x (sides + 1)) / 2
	inc a
	ld d,a
	ld e,b
	mul d,e
	srl d
	rr e
.avg:
	ld l,(ix+M_HP)
	ld h,(ix+M_HP+1)
	add hl,de
	ld (dc_tmp),hl
	ld hl,400
	call randint16
	push hl
	ld hl,400
	call randint16
	pop de
	add hl,de
	ld de,100
	add hl,de
	ld de,(dc_tmp)
	or a
	sbc hl,de
	jr z,.ignores
	jr c,.ignores
	ld a,3
	call randint
	inc a
	add a,(ix+M_STUN)
	cp 25
	jr c,$+4
	ld a,24
	ld (ix+M_STUN),a
	ld hl,md_stunned
	jr .react
.ignores:
	ld hl,md_ignores_bash
.react:
	push hl
	call msg_begin						; "The Orc appears stunned!"
	ld a,1
	ld (name_cap),a
	call mon_race
	call mon_name_to_msg
	pop hl
	call msg_add
	call msg_end
.balance:
	ld a,150
	call randint
	ld hl,p_stat_use+A_DEX
	cp (hl)
	ret z
	ret c
	ld hl,md_off_balance2
	jp off_balance
.say:									; HL = "You hit " / "You miss "
	push hl
	call msg_begin
	pop hl
	call msg_add
	xor a
	ld (name_cap),a
	ld ix,(dc_mon)
	call mon_race
	call mon_name_to_msg
	ld hl,txt_full_stop
	call msg_add
	jp msg_end

/* door_spike - 'S': a spike from the pack jams a closed door (jamdoor in
	DUNGEON.C): locked becomes stuck, and each spike sticks it more */
door_spike:
	ld de,(dc_sq)
	call map_addr
	ld a,(hl)
	and TERRAIN_MASK
	cp T_DOOR_OPEN
	ld hl,md_close_first
	jp z,msg_print
	cp T_DOOR_CLOSED
	ld hl,md_not_door
	jp nz,msg_print
	call in_the_way
	jr nc,.free
	ld a,1
	ld (turn_taken),a
	ret
.free:
	ld ix,PACK							; a spike?
	ld b,PACK_MAX
	ld c,0
.find:
	ld a,(ix+I_KIND_HI)
	cp ITEM_EMPTY
	jr z,.none
	push bc
	call item_kind_addr
	pop bc
	ld a,(iy+K_CLASS)
	cp IC_SPIKE
	jr z,.spike
	ld de,ITEM_SIZE
	add ix,de
	inc c
	djnz .find
.none:
	ld hl,md_no_spikes
	jp msg_print
.spike:
	ld a,c
	call use_one
	ld a,1
	ld (turn_taken),a
	ld hl,md_jam
	call msg_print
	ld de,(dc_sq)
	call map_addr
	call door_get						; locked becomes stuck
	bit 7,a
	jr nz,$+4
	neg
	ld (dc_num),a						; n -= 1 + 190 / (10 - n)
	ld b,a
	ld a,10
	sub b
	ld c,a
	ld a,190
	call div8
	inc a
	ld c,a
	ld a,(dc_num)
	sub c
	jp pe,.most							; (overflowed: as stuck as can be)
	cp -127
	jr nc,.set
.most:
	ld a,-127
.set:
	jp door_set

; ---------------------------------------------------------------- monsters

/* mon_door - IX = monster, IY = race, D, E = a closed or secret door, HL
	= its square (make_move): one that opens doors picks a lock or bursts
	a stuck door, others bash at closed ones. -> carry if it isn't for this
	monster (try another way), else the turn's used */
mon_door:
	ld (dc_sq),de
	ld a,(hl)
	and TERRAIN_MASK
	ld (dc_terrain),a
	ld l,(ix+M_HP)						; (hp, at most 300 for the sums:
	ld h,(ix+M_HP+1)					; it hardly changes the odds)
	ld de,300
	push hl
	or a
	sbc hl,de
	pop hl
	jr c,$+3
	ex de,hl
	ld (dc_hp),hl
	bit RM_OPEN_DOOR,(iy+R_MOVE)
	jr z,.basher
	ld a,(dc_terrain)					; a secret door just opens
	cp T_DOOR_SECRET
	jr z,.open
	call .number
	or a
	jr z,.open							; plain: opens (the turn)
	jp m,.stuck
	ld b,50								; locked: 1d((hp+1)(50+n)) <
	call .chance						; 40(hp-10-n): unlocked
	ret nc
	xor a
	call .set
	or a
	ret
.stuck:									; 1d((hp+1)(50-n)) < 40(hp-10+n):
	neg									; it bursts open
	ld b,50
	call .chance
	ret nc
	call .burst
	ld a,2
	call randint
	dec a
	call .set
	jr .opened
.basher:
	ld a,(dc_terrain)
	cp T_DOOR_SECRET
	scf
	ret z								; (it doesn't know it's there)
	call .number						; 1d((hp+1)(80+|n|)) < 40(hp-20-|n|)
	bit 7,a								; (as .chance with 70 and |n| + 10)
	jr z,$+4
	neg
	add a,10
	ld b,70
	call .chance
	ret nc
	call .burst
	ld a,2
	call randint
	dec a
	call .set
	jr .opened
.open:
	xor a
	call .set
.opened:
	ld de,(dc_sq)
	call map_addr
	ld a,(hl)
	and ~TERRAIN_MASK
	or T_DOOR_OPEN
	ld (hl),a
	or a
	ret
.number:								; A = the door's number
	ld de,(dc_sq)
	call map_addr
	jp door_get
.set:
	push af
	ld de,(dc_sq)
	call map_addr
	pop af
	jp door_set
.burst:
	ld hl,md_burst
	jp msg_print
/* .chance - A = n (0-137), B = 50 or 70: 1d((hp+1)(B+n)) < 40(hp-10-n)
	-> carry */
.chance:
	ld (dc_num),a
	add a,b
	ld e,a
	ld d,0
	ld hl,(dc_hp)
	inc hl
	call mul16
	call randint16
	ld (dc_tmp),hl						; the roll
	ld a,(dc_num)
	add a,10
	ld e,a
	ld d,0
	ld hl,(dc_hp)
	or a
	sbc hl,de
	jr c,.never
	jr z,.never
	ld de,40
	call mul16							; the limit
	ex de,hl
	ld hl,(dc_tmp)						; roll < limit
	or a
	sbc hl,de
	ret
.never:
	or a
	ret

/* mon_stun - IX = a stunned monster, IY its race: level^2 > 1d5000 and
	it shakes it off, else one less; at 0 "The Orc recovers and glares at
	you." -> Z if it can act */
mon_stun:
	ld e,(iy+R_LEVEL)
	ld d,e
	mul d,e
	push de
	ld hl,5000
	call randint16
	pop de
	or a
	sbc hl,de
	jr c,.over
	dec (ix+M_STUN)
	ret nz
	jr .recovers
.over:
	ld (ix+M_STUN),0
.recovers:
	call msg_begin
	ld a,1
	ld (name_cap),a
	call mon_name_to_msg
	ld hl,md_recovers
	call msg_add
	call msg_end
	xor a
	ret

/* mul16 - HL x DE -> HL (low 16 bits). mul16_signed: the same, HL signed */
mul16_signed:
mul16:
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

md_too_confused: db "You are too confused to pick the lock.",0
md_picked:		db "You have picked the lock.",0
md_failed_pick:	db "You failed to pick the lock.",0
md_stuck:		db "It appears to be stuck.",0
md_nothing_open: db "I do not see anything you can open there.",0
md_nothing_close: db "I do not see anything you can close there.",0
md_broken:		db "The door appears to be broken.",0
md_something:	db "Something is in your way!",0
md_in_your_way:	db " is in your way!",0
md_afraid:		db "You are afraid!",0
md_nothing_bash: db "I do not see anything you can bash there.",0
md_smash:		db "You smash into the door!",0
md_crashes_open: db "The door crashes open!",0
md_off_balance:	db "You are off-balance.",0
md_off_balance2: db "You are off balance.",0
md_holds_firm:	db "The door holds firm.",0
md_stunned:		db " appears stunned!",0
md_ignores_bash: db " ignores your bash!",0
md_close_first:	db "The door must be closed first.",0
md_not_door:	db "That isn't a door!",0
md_no_spikes:	db "But you have no spikes.",0
md_jam:			db "You jam the door with a spike.",0
md_burst:		db "You hear a door burst open!",0
md_recovers:	db " recovers and glares at you.",0

dc_which:		db 0
dc_sq:			dw 0
dc_num:			db 0
dc_tmp:			dw 0
dc_mon:			dw 0
dc_sweight:		dw 0
dc_dice:		dw 0
dc_terrain:		db 0
dc_hp:			dw 0
