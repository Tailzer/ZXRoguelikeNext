/* traps.asm - traps and rubble (overlay page PAGE_TRAP)
	References: TREASURE.C (the 18 traps: what they're called, their
	damage, how hard to disarm, the experience for it), MISC2.C place_trap/
	place_rubble/alloc_object, MORIA2.C hit_trap/disarm_trap/tunnel,
	MORIA1.C twall, SPELLS.C detect_trap/trap_creation.
	The level's traps are kept in TRAP_LIST (high RAM); rubble is a terrain
	(T_RUBBLE). Stepping on a trap, found or not, sets it off.
 */

; per trap type 1-18: name, then dice, sides, how hard to disarm (level),
; the experience for disarming it, and what it kills with (KILLER_TRAPS+n,
; or $FF if it can't)
	MACRO TRAP name, dice, sides, level, exp, killer
		dw name
		db dice, sides, level, exp, killer
	ENDM
TRAP_REC	equ 7
trap_table:
	TRAP tn_open_pit, 2,6, 50, 1, 0				; 1: open pit
	TRAP tn_arrow, 1,8, 90, 3, 1				; 2: arrow trap
	TRAP tn_covered_pit, 2,6, 60, 2, 2			; 3: covered pit
	TRAP tn_trap_door, 2,8, 75, 5, 3			; 4: trap door
	TRAP tn_gas, 1,4, 95, 3, $FF				; 5: sleep gas
	TRAP tn_loose_rock, 0,0, 10, 0, $FF			; 6: loose rock
	TRAP tn_dart, 1,4, 110, 5, 4				; 7: strength dart
	TRAP tn_rune, 0,0, 90, 5, $FF				; 8: teleport rune
	TRAP tn_some_rock, 2,6, 90, 5, 5			; 9: rockfall
	TRAP tn_gas, 1,4, 105, 10, 6				; 10: corrosive gas
	TRAP tn_rune, 0,0, 90, 5, $FF				; 11: summoning rune
	TRAP tn_blackened, 4,6, 110, 10, 7			; 12: fire
	TRAP tn_corroded, 4,6, 110, 10, 8			; 13: acid
	TRAP tn_gas, 2,6, 105, 5, 9					; 14: poison gas
	TRAP tn_gas, 1,4, 110, 5, $FF				; 15: blinding gas
	TRAP tn_gas, 1,8, 105, 5, $FF				; 16: confusing gas
	TRAP tn_dart, 1,8, 110, 5, 4				; 17: slowing dart
	TRAP tn_dart, 1,8, 110, 5, 4				; 18: constitution dart
NUM_TRAPS	equ 18

; ---------------------------------------------------------------- a new level

/* alloc_traps - the new level's rubble (in corridors) and traps (on any
	floor), 1d(alloc_level) of each, alloc_level being dun_level / 3 from 2
	to 10; none in town (cave_gen's alloc_object calls) */
alloc_traps:
	ld a,(dun_level)					; (the town: none; a dungeon level
	or a								; was cleared before its rooms were
	jr nz,.dungeon						; built: they may have traps)
	ld hl,TRAP_LIST
	ld b,TRAP_MAX*TRAP_SIZE
.clear:
	ld (hl),0
	inc hl
	djnz .clear
	ret
.dungeon:
	ld c,3
	call div8
	cp 2
	jr nc,$+4
	ld a,2
	cp 11
	jr c,$+4
	ld a,10
	ld (tr_alloc),a
	call randint						; rubble
	ld b,a
.rubble:
	push bc
.rspot:
	call random_open_spot				; (D, E, HL)
	ld a,(hl)
	and TERRAIN_MASK
	cp T_CORRIDOR
	jr nz,.rspot
	call tr_free
	jr nc,.rspot
	ld a,(hl)
	and $FF-TERRAIN_MASK
	or T_RUBBLE
	ld (hl),a
	pop bc
	djnz .rubble
	ld a,(tr_alloc)						; traps
	call randint
	ld b,a
.trap:
	push bc
.tspot:
	call random_open_spot
	call tr_free
	jr nc,.tspot
	push de
	ld a,NUM_TRAPS
	call randint
	pop de
	call place_trap
	pop bc
	djnz .trap
	ret
/* tr_free - D, E -> carry if nothing's there: not the player, an item or
	a trap. Preserves DE, HL */
tr_free:
	ld a,(player_y)
	cp d
	jr nz,.not_player
	ld a,(player_x)
	cp e
	ret z								; (carry clear)
.not_player:
	push hl
	push ix
	call item_at
	jr c,.taken
	call trap_at
.taken:
	pop ix
	pop hl
	ccf
	ret

/* place_trap - A = type, D = y, E = x: a trap there (one already there is
	replaced); an open pit is plain to see. -> IX = it, carry if there was
	room in the list. Preserves DE */
place_trap:
	ld c,a
	call trap_at						; (its own slot, if there is one)
	jr c,.slot
	ld ix,TRAP_LIST
	ld b,TRAP_MAX
.free:
	ld a,(ix+TR_TYPE)
	or a
	jr z,.slot
	inc ix
	inc ix
	inc ix
	inc ix
	djnz .free
	or a
	ret
.slot:
	ld (ix+TR_Y),d
	ld (ix+TR_X),e
	ld (ix+TR_TYPE),c
	xor a
	ld (ix+TR_FLAGS),a
	ld a,c
	cp 1
	jr nz,$+6
	set TRF_SEEN,(ix+TR_FLAGS)
	scf
	ret

/* tr_rec - IX = trap -> IY = its trap_table entry. Clobbers A, DE */
tr_rec:
	ld a,(ix+TR_TYPE)
	dec a
	ld e,a
	ld d,TRAP_REC
	mul d,e
	ld iy,trap_table
	add iy,de
	ret

/* trap_name_add - IX = trap: its name added to the message (look) */
trap_name_add:
	call tr_rec
	ld l,(iy+0)
	ld h,(iy+1)
	jp msg_add

/* search_square - D, E = a square searching has noticed: a hidden trap
	there is found, or the trap on a chest (search in MORIA1.C) */
search_square:
	call trap_at
	jr nc,.chest
	bit TRF_SEEN,(ix+TR_FLAGS)
	jr nz,.chest
	set TRF_SEEN,(ix+TR_FLAGS)
	push de
	call say_found_trap
	pop de
.chest:
	call chest_at
	ret nc
	OVCALL PAGE_CHEST, chest_search, PAGE_TRAP
	ret

/* chest_at - D, E -> IX = a chest lying there, carry if there is one.
	Preserves DE */
chest_at:
	call item_at
	ret nc
	push de
	call item_kind_addr
	pop de
	ld a,(iy+K_CLASS)
	cp IC_CHEST
	scf
	ret z
	or a
	ret

/* say_found_trap - IX = trap: "You have found an arrow trap." */
say_found_trap:
	call msg_begin
	ld hl,mt_found
	call msg_add
	call tr_rec
	ld l,(iy+0)
	ld h,(iy+1)
	call msg_add
	ld hl,txt_full_stop
	call msg_add
	jp msg_end

; ---------------------------------------------------------------- springing one

/* hit_trap - IX = the trap the player has stepped onto: it's found, and it
	does what it does (hit_trap in MORIA2.C) */
hit_trap:
	set TRF_SEEN,(ix+TR_FLAGS)
	ld (tr_trap),ix
	call tr_rec
	ld a,(iy+6)							; who the death screen blames
	cp $FF
	jr z,.no_killer
	ld hl,KILLER_TRAPS
	add hl,a
	ld (killer_race),hl
.no_killer:
	ld b,(iy+2)							; the damage
	ld c,(iy+3)
	call damroll
	ld (tr_dam),hl
	ld a,(ix+TR_TYPE)
	dec a
	add a,a
	ld hl,trap_effects
	add hl,a
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	jp (hl)
trap_effects:
	dw tp_open_pit, tp_arrow, tp_covered_pit, tp_trap_door, tp_sleep
	dw tp_loose_rock, tp_str_dart, tp_teleport, tp_rockfall, tp_corrode
	dw tp_summon, tp_fire, tp_acid, tp_poison, tp_blind, tp_confuse
	dw tp_slow_dart, tp_con_dart

tp_open_pit:
	ld hl,mt_pit
	jr pit
tp_covered_pit:							; ... and then it's an open pit
	ld hl,mt_covered_pit
	call pit
	ld ix,(tr_trap)
	ld (ix+TR_TYPE),1
	ret
/* pit - HL = what happened: the fall hurts, unless feather fall */
pit:
	call msg_print
fall:
	ld a,(p_eflags+3)
	bit EF3_FFALL,a
	ld hl,mt_float
	jp nz,msg_print
	ld hl,(tr_dam)
	jp take_hit
tp_trap_door:							; down a level ("You fell through a
	ld a,(dun_level)					; trap door!" comes after it), but on
	call is_quest						; Sauron's level it's a spiked pit
	jr z,.spiked
	ld hl,dun_level
	inc (hl)
	ld a,4								; (4: "You fell through a trap door!")
	ld (p_new_level),a
	jr fall
.spiked:								; "You fall into a spiked pit!":
	ld hl,mt_spiked_pit					; half as much again, and 1 in 3
	call msg_print						; poisoned (twice, if not resisted)
	ld a,(p_eflags+3)
	bit EF3_FFALL,a
	ld hl,mt_float
	jp nz,msg_print
	ld hl,(tr_dam)
	ld d,h
	ld e,l
	srl d
	rr e
	add hl,de
	ld (tr_dam),hl
	ld a,3
	call randint
	dec a
	jr nz,.hurt
	ld hl,mt_spikes_poisoned
	call msg_print
	ld a,(p_eflags2+1)
	and TR2_IM_POISON
	jr nz,.resisted
	ld a,(p_eflags+3)
	bit EF3_POISON,a
	jr nz,.resisted
	ld hl,(p_resist_poison)
	ld a,h
	or l
	jr nz,.resisted
	ld hl,(tr_dam)
	add hl,hl
	ld (tr_dam),hl
	jr .hurt
.resisted:
	ld hl,mt_unaffected_poison
	call msg_print
.hurt:
	ld hl,(tr_dam)
	jp take_hit
tp_arrow:
	call dart_hits
	ld hl,mt_arrow_misses
	jp nc,msg_print
	ld hl,(tr_dam)
	call take_hit
	ld hl,mt_arrow_hits
	jp msg_print
tp_sleep:								; a strange white mist
	ld a,(p_paralysed)
	or a
	ret nz
	ld hl,mt_white_mist
	call msg_print
	call free_action
	ret nz
	ld hl,mt_fall_asleep
	call msg_print
	ld a,10
	call randint
	add a,4
	ld hl,p_paralysed
	add a,(hl)
	jr nc,$+4
	ld a,255
	ld (hl),a
	ret
tp_loose_rock:							; something was under it
	ld ix,(tr_trap)
	ld (ix+TR_TYPE),0
	ld d,(ix+TR_Y)
	ld e,(ix+TR_X)
	OVCALL PAGE_LEVEL, place_object, PAGE_TRAP
	ld hl,mt_under_rock
	jp msg_print
tp_str_dart:
	ld a,A_STR
	ld hl,mt_dart_weakens
	jr stat_dart
tp_con_dart:
	ld a,A_CON
	ld hl,mt_dart_saps
/* stat_dart - A = stat, HL = what it says if it takes: unless sustained,
	the stat goes down a step and the dart hurts */
stat_dart:
	ld (tr_stat),a
	ld (tr_text),hl
	call dart_hits
	ld hl,mt_dart_misses
	jp nc,msg_print
	ld a,(tr_stat)						; sustained: only "hits you"
	inc a
	ld b,a
	ld a,(p_sustain)
.bit:
	rrca
	djnz .bit
	ld hl,mt_dart_hits_
	jp c,msg_print
	ld a,(tr_stat)
	OVCALL PAGE_MAGIC, dec_stat, PAGE_TRAP
	ld hl,(tr_dam)
	call take_hit
	ld hl,(tr_text)
	jp msg_print
tp_slow_dart:
	call dart_hits
	ld hl,mt_dart_misses
	jp nc,msg_print
	ld hl,(tr_dam)
	call take_hit
	ld hl,mt_dart_hits
	call msg_print
	call free_action
	ret nz
	ld a,20
	call randint
	add a,10
	ld hl,(p_slow)
	add hl,a
	ld (p_slow),hl
	ret
tp_teleport:
	ld hl,mt_teleport_trap
	call msg_print
	ld hl,100
	OVCALL PAGE_SCROLL, teleport, PAGE_TRAP
	ret
tp_rockfall:							; rubble where it was, and the
	ld hl,(tr_dam)						; player back where they came from
	call take_hit
	ld ix,(tr_trap)
	ld (ix+TR_TYPE),0
	ld d,(ix+TR_Y)
	ld e,(ix+TR_X)
	push de
	call lamp_off
	pop de
	call map_addr
	ld a,(hl)
	and $FF-TERRAIN_MASK
	or T_RUBBLE
	ld (hl),a
	ld hl,(step_from)
	ld a,l
	ld (player_x),a
	ld a,h
	ld (player_y),a
	call light_arrive
	call update_view
	call monsters_see_all
	ld hl,mt_falling_rock
	jp msg_print
tp_corrode:
	OVCALL PAGE_MCAST, corrode_gas, PAGE_TRAP
	ld hl,mt_red_gas
	jp msg_print
tp_summon:								; the rune goes, 2 + 1d3 monsters come
	ld ix,(tr_trap)
	ld (ix+TR_TYPE),0
	ld a,3
	call randint
	add a,2
	ld b,a
.each:
	push bc
	ld ix,(tr_trap)
	ld d,(ix+TR_Y)
	ld e,(ix+TR_X)
	ld a,(dun_level)
	ld l,a
	ld a,SUM_MONSTER
	OVCALL PAGE_LEVEL, summon_by, PAGE_TRAP
	pop bc
	djnz .each
	jp monsters_see_all
tp_fire:
	ld hl,(tr_dam)
	OVCALL PAGE_MCAST, el_fire, PAGE_TRAP
	ld hl,mt_flames
	jp msg_print
tp_acid:
	ld hl,(tr_dam)
	OVCALL PAGE_MCAST, el_acid, PAGE_TRAP
	ld hl,mt_splashed
	jp msg_print
tp_poison:								; (no damage if resisting at all)
	ld a,(p_eflags2+1)
	and TR2_IM_POISON
	jr nz,.green
	ld a,(p_eflags+3)
	bit EF3_POISON,a
	jr nz,.green
	ld hl,(p_resist_poison)
	ld a,h
	or l
	jr nz,.green
	ld hl,(tr_dam)
	OVCALL PAGE_MCAST, el_poison, PAGE_TRAP
.green:
	ld hl,mt_green_gas
	jp msg_print
tp_blind:
	ld hl,mt_black_gas
	call msg_print
	ld a,(p_race)						; (dwarves, and TR_RES_BLIND)
	cp RACE_DWARF
	ret z
	ld a,(p_eflags2+2)
	and TR2_RES_BLIND
	ret nz
	ld a,50
	call randint
	add a,50
	ld hl,(p_blind)
	add hl,a
	ld (p_blind),hl
	ret
tp_confuse:
	ld hl,mt_colour_gas
	call msg_print
	ld a,(p_eflags2+1)
	and TR2_RES_CONF
	ret nz
	ld a,(p_eflags2+2)
	and TR2_RES_CHAOS
	ret nz
	ld a,15
	call randint
	add a,15
	ld hl,(p_confused)
	add hl,a
	ld (p_confused),hl
	ret

/* dart_hits - test_hit(125, ..., AC): carry if the dart or arrow hits */
dart_hits:
	ld hl,125
	ld a,(p_ac)
	jp test_hit
/* free_action - "You are unaffected." and NZ if the player has it */
free_action:
	ld a,(p_eflags+2)
	and 1<<EF2_FREE_ACT
	ret z
	ld hl,mcm_unaffected_t
	call msg_print
	or 1
	ret

; ---------------------------------------------------------------- D: disarming

/* cmd_disarm - 'D': disarm a trap that's been found next to you (disarm_trap
	in MORIA2.C): skill (race + class), 2 x DEX's todis_adj, INT's stat_adj
	and class_level_adj[DISARM] x level / 3; a tenth of it blind, in the
	dark or confused. Well done, it's gone, with its experience, and you step
	onto it; badly done, you set it off */
cmd_disarm:
	OVCALL PAGE_DEVICE, get_dir, PAGE_TRAP
	ret nc
	call dir_square						; D, E, (tr_dx, tr_dy)
	xor a
	ld (tr_chest),a
	call trap_at
	jr nc,.chest
	bit TRF_SEEN,(ix+TR_FLAGS)
	jr z,.chest
	ld (tr_trap),ix
.way:
	push de
	call map_addr
	pop de
	bit F_MON_BIT,(hl)
	jr z,.clear
	push de								; "The Orc is in your way!"
	call mon_at
	pop de
	jr nc,.clear
	ld a,1
	ld (turn_taken),a
	call msg_begin
	ld a,1
	ld (name_cap),a
	call mon_race
	call mon_name_to_msg
	ld hl,mt_in_your_way
	call msg_add
	jp msg_end
.chest:									; or a chest's trap
	call chest_at
	jr nc,.nothing
	ld a,1
	ld (tr_chest),a
	jr .way
.nothing:
	ld hl,mt_nothing_to_disarm
	jp msg_print
.clear:
	ld a,(tr_chest)
	or a
	jr z,.trap
	OVCALL PAGE_CHEST, chest_disarm, PAGE_TRAP
	ret
.trap:
	ld a,1
	ld (turn_taken),a
	call disarm_skill					; HL = tot
	ld (tr_tot),hl
	ld ix,(tr_trap)
	call tr_rec
	ld l,(iy+4)							; tot + 100 - level > 1d100
	ld h,0
	ld de,(tr_tot)
	ex de,hl
	or a
	sbc hl,de
	ld de,100
	add hl,de
	bit 7,h
	jr nz,.not_done
	push hl
	ld a,100
	call randint
	pop hl
	ld e,a
	ld d,0
	or a
	sbc hl,de
	jr z,.not_done
	jr c,.not_done
	ld hl,mt_disarmed					; done: its experience, and step on
	call msg_print
	ld ix,(tr_trap)
	bit TRF_MADE,(ix+TR_FLAGS)
	jr nz,.no_exp
	call tr_rec
	ld l,(iy+5)
	ld h,0
	call add_exp
	call check_level_up
.no_exp:
	ld ix,(tr_trap)
	ld (ix+TR_TYPE),0
	jr step_on
.not_done:
	ld hl,(tr_tot)						; tot > 5 and 1d(tot) > 5: just failed
	bit 7,h
	jr nz,.set_off
	ld de,6
	or a
	sbc hl,de
	jr c,.set_off
	ld hl,(tr_tot)
	call randint16
	ld de,6
	or a
	sbc hl,de
	ld hl,mt_failed
	jp nc,msg_print
.set_off:
	ld hl,mt_set_off
	call msg_print
/* step_on - onto the square in (tr_dy, tr_dx), never stumbling (move_char
	with the confusion put aside) */
step_on:
	ld hl,(p_confused)
	push hl
	ld hl,0
	ld (p_confused),hl
	ld a,(tr_dx)
	ld b,a
	ld a,(tr_dy)
	ld c,a
	call try_move
	pop hl
	ld (p_confused),hl
	ret

/* disarm_skill -> HL = tot (signed) */
disarm_skill:
	ld a,(p_cla_dis)					; class_level_adj x level / 3
	ld e,a
	ld a,(p_lev)
	ld d,a
	mul d,e
	ex de,hl
	ld c,3
	call div16_8
	ld a,(p_dis)						; + skill
	call .signed
	ld a,(p_stat_use+A_DEX)				; + 2 x todis_adj
	push hl
	ld hl,todis_adj
	call threshold
	pop hl
	call .signed
	call .signed
	ld a,(p_stat_use+A_INT)				; + stat_adj(INT)
	push hl
	ld hl,int_adj
	call threshold
	pop hl
	call .signed
	ld a,(ds_lock)						; (picking a lock: no less for the
	or a								; dark, as openobject)
	ret nz
	ld de,(p_blind)						; a tenth blind or in the dark
	ld a,d
	or e
	jr nz,.tenth
	push hl
	call no_light
	pop hl
	jr nz,.lit
.tenth:
	call .div10
.lit:
	ld de,(p_confused)					; and confused
	ld a,d
	or e
	ret z
.div10:
	bit 7,h
	ret nz
	ld c,10
	jp div16_8
.signed:								; HL += A (signed)
	ld e,a
	rla
	sbc a,a
	ld d,a
	add hl,de
	ret
; todis_adj (MISC2.C), as (stat below this, value) pairs - the C's 3 is 0
todis_adj:	db 3,-8, 4,0, 5,-6, 6,-4, 7,-2, 8,-1, 13,0, 16,1, 18,2
			db 59,4, 94,5, 117,6, 255,8

/* lock_skill -> HL = the disarming skill as openobject has it */
lock_skill:
	ld a,1
	ld (ds_lock),a
	call disarm_skill
	xor a
	ld (ds_lock),a
	ret
ds_lock:		db 0

/* dir_square - A = direction 1-9 -> D, E = the square that way, and
	(tr_dy), (tr_dx) */
dir_square:
	dec a
	add a,a
	ld hl,keypad_deltas
	add hl,a
	ld a,(hl)
	ld (tr_dy),a
	ld b,a
	inc hl
	ld a,(hl)
	ld (tr_dx),a
	ld c,a
	ld a,(player_y)
	add a,b
	ld d,a
	ld a,(player_x)
	add a,c
	ld e,a
	ret

; ---------------------------------------------------------------- T: tunnelling

/* cmd_tunnel - 'T': dig at the square next to you (tunnel and twall in
	MORIA2.C and MORIA1.C): rubble, or rock as hard as it is, against STR
	and what you're wielding */
cmd_tunnel:
	OVCALL PAGE_DEVICE, get_dir, PAGE_TRAP
	ret nc								; (confused, get_dir goes astray)
	call dir_square
	ld (tr_sq),de
	ld a,1
	ld (turn_taken),a
	push de
	call map_addr
	pop de
	bit F_MON_BIT,(hl)
	jr z,.dig
	call mon_at							; something's in the way: fight it
	ret nc
	call msg_begin
	ld a,1
	ld (name_cap),a
	call mon_race
	call mon_name_to_msg
	ld hl,mt_in_your_way
	call msg_add
	push ix
	call msg_end
	pop ix
	ld hl,(p_afraid)
	ld a,h
	or l
	jp z,py_attack
	ld hl,msg_too_afraid
	jp msg_print
.dig:
	ld a,(EQUIP+EQ_WEAPON*ITEM_SIZE+I_KIND_HI)
	cp ITEM_EMPTY
	ld hl,mt_hands
	jp z,msg_print
	call dig_power
	ld (tr_tot),hl
	ld de,(tr_sq)
	call map_addr
	ld a,(hl)
	and TERRAIN_MASK
	cp T_GRANITE
	ld hl,mt_tunnel_granite
	jr z,.rock
	cp T_MAGMA
	ld hl,mt_tunnel_magma
	jr z,.soft
	cp T_QUARTZ
	ld hl,mt_tunnel_quartz
	jr z,.softer
	cp T_PERMWALL
	ld hl,mt_permanent
	jp z,msg_print
	cp T_RUBBLE
	jp z,.rubble
	cp T_DOOR_SECRET					; (it's a door: digging finds it)
	jp z,.secret
	push af
	call free_turn_t
	pop af
	ld hl,mt_empty_air
	cp T_FLOOR
	jp z,msg_print
	cp T_CORRIDOR
	jp z,msg_print
	cp T_FLOOR_LIT
	jp z,msg_print
	ld hl,mt_cant_tunnel
	jp msg_print
.rock:									; granite: 1d1200 + 80
	ld (tr_text),hl
	ld hl,1200
	ld b,80
	jr .twall
.soft:									; magma: 1d600 + 10
	ld (tr_text),hl
	ld hl,600
	ld b,10
	jr .twall
.softer:								; quartz: 1d400 + 10
	ld (tr_text),hl
	ld hl,400
	ld b,10
.twall:									; dug through if power > it
	push bc
	call randint16
	pop bc
	ld a,b
	add hl,a
	ex de,hl
	ld hl,(tr_tot)
	or a
	sbc hl,de
	jr z,.not_yet
	jr c,.not_yet
	call open_square
	ld hl,mt_finished
	jp msg_print
.not_yet:
	ld hl,(tr_text)
	jp msg_print
.rubble:								; power > 1d180: cleared, and 1 in
	ld a,180							; 10 something was in it
	call randint
	ld e,a
	ld d,0
	ld hl,(tr_tot)
	or a
	sbc hl,de
	ld hl,mt_dig_rubble
	jp z,msg_print
	jp c,msg_print
	call open_square
	ld hl,mt_rubble_gone
	call msg_print
	ld a,10
	call randint
	cp 1
	ret nz
	ld de,(tr_sq)
	OVCALL PAGE_LEVEL, place_object, PAGE_TRAP
	ld de,(tr_sq)						; (if you can see it)
	call map_addr
	ld a,(hl)
	and F_SEEN
	ret z
	ld hl,mt_found_something
	jp msg_print
.secret:
	ld hl,mt_tunnel_granite
	call msg_print
	jp search
free_turn_t:
	xor a
	ld (turn_taken),a
	ret
/* open_square - (tr_sq) becomes floor: a room's, or corridor */
open_square:
	ld de,(tr_sq)
	call map_addr
	ld a,(hl)
	and $FF-TERRAIN_MASK
	ld b,T_CORRIDOR
	bit F_ROOM_BIT,a
	jr z,$+4
	ld b,T_FLOOR
	or b
	ld (hl),a
	jp light_refresh

/* dig_power -> HL = STR (as used) + the weapon's dice x sides + its
	pluses, halved; or STR + 25 + its number x 50 for a digger (TR_TUNNEL) */
dig_power:
	ld ix,EQUIP+EQ_WEAPON*ITEM_SIZE
	call item_flags
	ld a,(p_stat_use+A_STR)
	ld l,a
	ld h,0
	ld a,(it_flags+3)
	bit 5,a								; TR_TUNNEL
	jr z,.weapon
	ld de,25
	add hl,de
	ld a,(ix+I_PVAL)					; (signed: a cursed one digs worse,
	bit 7,a								;  at worst not at all)
	jr nz,.worse
	ld e,a
	ld d,50
	mul d,e
	add hl,de
	ret
.worse:
	neg
	ld e,a
	ld d,50
	mul d,e
	or a
	sbc hl,de
	ret nc
	ld hl,0
	ret
.weapon:
	push hl
	call item_dice						; A = dice, B = sides
	ld e,a
	ld d,b
	mul d,e
	pop hl
	add hl,de
	ld a,(ix+I_TOHIT)
	call disarm_skill.signed
	ld a,(ix+I_TODAM)
	call disarm_skill.signed
	bit 7,h
	jr z,$+5
	ld hl,0
	srl h
	rr l
	ret

; ---------------------------------------------------------------- magic

/* detect_traps - every trap in view is found, and what chests in view are
	(detect_trap) -> carry if any trap. Preserves IX */
detect_traps:
	push ix
	xor a
	ld (tr_any),a
	ld ix,TRAP_LIST
	ld b,TRAP_MAX
.each:
	ld a,(ix+TR_TYPE)
	or a
	jr z,.next
	ld a,(view_y)
	ld c,a
	ld a,(ix+TR_Y)
	sub c
	cp VIEW_H
	jr nc,.next
	ld a,(view_x)
	ld c,a
	ld a,(ix+TR_X)
	sub c
	cp VIEW_W
	jr nc,.next
	bit TRF_SEEN,(ix+TR_FLAGS)
	jr nz,.next
	set TRF_SEEN,(ix+TR_FLAGS)
	ld a,1
	ld (tr_any),a
.next:
	inc ix
	inc ix
	inc ix
	inc ix
	djnz .each
	OVCALL PAGE_CHEST, detect_chests, PAGE_TRAP	; (chests: what traps)
	pop ix
	ld a,(tr_any)
	rra
	ret

/* trap_creation - a trap on every floor square round the player, theirs
	too, in place of what was there (not an artifact: "The object resists
	the spell."); no experience for disarming these (trap_creation) ->
	carry if any */
trap_creation:
	push ix
	xor a
	ld (tr_any),a
	ld a,(player_y)
	dec a
	ld d,a
	ld b,3
.row:
	push bc
	ld a,(player_x)
	dec a
	ld e,a
	ld b,3
.col:
	push bc
	push de
	call map_addr
	ld a,(hl)
	and TERRAIN_MASK
	cp T_FLOOR
	jr z,.floor
	cp T_CORRIDOR
	jr z,.floor
	cp T_FLOOR_LIT
	jr nz,.next
.floor:
	pop de
	push de
	call item_at						; whatever lies there goes
	jr nc,.make
	ld a,(ix+I_KIND_HI)
	cp KIND_GOLD
	jr z,.gone
	ld a,(ix+I_NAME2)
	or a
	jr z,.gone
	push de
	call ego_addr
	pop de
	bit EO_ARTIFACT,(iy+E_OPTS)
	jr z,.gone
	ld hl,mt_resists
	call msg_print
	jr .next
.gone:
	ld (ix+I_KIND_HI),ITEM_EMPTY
.make:
	ld a,NUM_TRAPS
	call randint
	pop de
	push de
	call place_trap
	jr nc,.next
	set TRF_MADE,(ix+TR_FLAGS)
	ld a,1
	ld (tr_any),a
.next:
	pop de
	pop bc
	inc e
	djnz .col
	pop bc
	inc d
	djnz .row
	pop ix
	ld a,(tr_any)
	rra
	ret

/* traps_around_gone - the traps round the player (theirs too) are
	destroyed, chests disarmed (td_destroy) -> carry if any */
traps_around_gone:
	xor a
	ld (tr_any),a
	ld a,(player_y)
	dec a
	ld d,a
	ld b,3
.row:
	ld a,(player_x)
	dec a
	ld e,a
	ld c,3
.col:
	call trap_gone
	jr nc,$+7
	ld a,1
	ld (tr_any),a
	inc e
	dec c
	jr nz,.col
	inc d
	djnz .row
	ld a,(tr_any)
	rra
	ret

; ---------------------------------------------------------------- words

tn_open_pit:	db "an open pit",0
tn_arrow:		db "an arrow trap",0
tn_covered_pit:	db "a covered pit",0
tn_trap_door:	db "a trap door",0
tn_gas:			db "a gas trap",0
tn_loose_rock:	db "a loose rock",0
tn_dart:		db "a dart trap",0
tn_rune:		db "a strange rune",0
tn_some_rock:	db "some loose rock",0
tn_blackened:	db "a blackened spot",0
tn_corroded:	db "some corroded rock",0
mt_found:		db "You have found ",0
mt_pit:			db "You fell into a pit!",0
mt_covered_pit:	db "You fell into a covered pit.",0
mt_float:		db "You gently float down.",0
mt_spiked_pit:	db "You fall into a spiked pit!",0
mt_spikes_poisoned: db "The spikes are poisoned!",0
mt_unaffected_poison: db "You are unaffected by the poison.",0
mt_arrow_hits:	db "An arrow hits you.",0
mt_arrow_misses: db "An arrow barely misses you.",0
mt_white_mist:	db "A strange white mist surrounds you!",0
mt_fall_asleep:	db "You fall asleep.",0
mt_under_rock:	db "Hmmm, there was something under this rock.",0
mt_dart_weakens: db "A small dart weakens you!",0
mt_dart_saps:	db "A small dart saps your health!",0
mt_dart_hits_:	db "A small dart hits you.",0
mt_dart_hits:	db "A small dart hits you!",0
mt_dart_misses:	db "A small dart barely misses you.",0
mt_teleport_trap: db "You hit a teleport trap!",0
mt_falling_rock: db "You are hit by falling rock.",0
mt_red_gas:		db "A strange red gas surrounds you.",0
mt_flames:		db "You are enveloped in flames!",0
mt_splashed:	db "You are splashed with acid!",0
mt_green_gas:	db "A pungent green gas surrounds you!",0
mt_black_gas:	db "A black gas surrounds you!",0
mt_colour_gas:	db "A gas of scintillating colors surrounds you!",0
mcm_unaffected_t: db "You are unaffected.",0
mt_in_your_way:	db " is in your way!",0
mt_nothing_to_disarm: db "I do not see anything to disarm there.",0
mt_disarmed:	db "You have disarmed the trap.",0
mt_failed:		db "You failed to disarm the trap.",0
mt_set_off:		db "You set the trap off!",0
mt_hands:		db "You dig with your hands, making no progress.",0
mt_tunnel_granite: db "You tunnel into the granite wall.",0
mt_tunnel_magma: db "You tunnel into the magma intrusion.",0
mt_tunnel_quartz: db "You tunnel into the quartz vein.",0
mt_permanent:	db "This seems to be permanent rock.",0
mt_finished:	db "You have finished the tunnel.",0
mt_dig_rubble:	db "You dig in the rubble.",0
mt_rubble_gone:	db "You have removed the rubble.",0
mt_found_something: db "You have found something!",0
mt_cant_tunnel:	db "You can't tunnel through that.",0
mt_empty_air:	db "Tunnel through what?  Empty air?!?",0
mt_resists:		db "The object resists the spell.",0

; ---------------------------------------------------------------- workspace

tr_alloc:		db 0
tr_trap:		dw 0
tr_dam:			dw 0
tr_stat:		db 0
tr_text:		dw 0
tr_tot:			dw 0
tr_dy:			db 0
tr_dx:			db 0
tr_sq:			dw 0
tr_any:			db 0
tr_chest:		db 0				; D at a chest (chests.asm does it)
