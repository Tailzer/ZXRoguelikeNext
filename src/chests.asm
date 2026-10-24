/* chests.asm - what monsters drop, and chests (overlay page PAGE_CHEST)
	References: MORIA2.C monster_death/summon_object/chest_trap/
	openobject/disarm_trap/bash, MISC1.C magic_treasure (TV_CHEST),
	MORIA1.C search, SPELLS.C detect_trap/td_destroy/disarm_all/
	td_destroy2.
	A dying monster's race says what it carries (MS_TREASURE, and RS_GOOD
	or RS_GREAT); chest_call (items.asm) brings it here from wherever it
	died. A chest keeps the C's CH_ flags in I_PVAL (CHF_ bits) and what
	it's known to be in I_NAME2 ("(Locked)", shown once known2); what's in
	it is its kind's MT_ bits, while CHF_TREASURE says it still holds it.
 */

; ---------------------------------------------------------------- treasure

/* monster_death - IX = a monster dying, A = 1 if nothing of the player's
	killed it: what it carried falls around it, good things if its race's
	are (not when A = 1); Morgoth leaves his crown and Grond first
	(monster_death in MORIA2.C). Preserves IX */
monster_death:
	ld (md_plain),a
	ld a,(ix+M_Y)
	ld (md_y),a
	ld a,(ix+M_X)
	ld (md_x),a
	call mon_race
	bit RF2_WIN,(iy+R_FLAGS2)
	call nz,win_drop
	ld l,(ix+M_RACE)					; its MS_ record: mspell_table +
	ld h,(ix+M_RACE_HI)					; race * 12
	ld d,h
	ld e,l
	add hl,hl
	add hl,de
	add hl,hl
	add hl,hl
	ld de,mspell_table+MS_FLAGS
	add hl,de
	nextreg NR_MMU1,MSPELL_PAGE
	ld b,0								; good: 1 (GOOD), 2 (SPECIAL)
	ld a,(md_plain)
	or a
	jr nz,.plain
	bit RS_GOOD,(hl)
	jr z,$+4
	ld b,1
	bit RS_GREAT,(hl)
	jr z,.plain
	ld b,2
.plain:
	ld a,b
	ld (md_good),a
	inc hl
	ld a,(hl)							; MS_TREASURE
/* treasure_drop - A = MT_ bits, (md_y, md_x) where, (md_good): how many
	things it carries, then each falls somewhere near (monster_death's
	count, summon_object). Preserves IX */
treasure_drop:
	push ix
	ld (md_flags),a
	and 3								; 1 objects, 2 treasure, 3 either
	ld (md_typ),a
	xor a
	ld (md_num),a
	ld a,(md_flags)
	bit MT_60,a
	jr z,.n60
	ld a,100
	call randint
	cp 60
	call c,.one
.n60:
	ld a,(md_flags)
	bit MT_90,a
	jr z,.n90
	ld a,100
	call randint
	cp 90
	call c,.one
.n90:
	ld a,(md_flags)
	bit MT_1D2,a
	jr z,.n1d2
	ld a,2
	call randint
	call .add
.n1d2:
	ld a,(md_flags)
	bit MT_2D2,a
	ld bc,2*256+2
	call nz,.dice
	ld a,(md_flags)
	bit MT_4D2,a
	ld bc,4*256+2
	call nz,.dice
	ld a,(md_num)
	or a
	jr z,.done
.each:									; up to 21 tries at a spot for each
	ld b,21
.try:
	push bc
	call drop_spot
	jr nc,.again
	call .place
	pop bc
	jr .placed
.again:
	pop bc
	djnz .try
.placed:
	ld hl,md_num
	dec (hl)
	jr nz,.each
.done:
	pop ix
	ret
.one:
	ld a,1
	jr .add
.dice:
	call damroll
	ld a,l
.add:
	ld hl,md_num
	add a,(hl)
	ld (hl),a
	ret
.place:									; D, E: an object or treasure (half
	ld a,(md_typ)						; and half if it carries both), or
	cp 3								; something good
	jr nz,.typ
	push de
	ld a,100
	call randint
	pop de
	cp 50
	ld a,1
	jr c,.typ
	inc a
.typ:
	ld b,a
	ld a,(md_good)
	or a
	jr nz,.special
	dec b
	jr z,.object
	OVCALL PAGE_LEVEL, place_gold, PAGE_CHEST
	ret
.object:
	OVCALL PAGE_LEVEL, place_object, PAGE_CHEST
	ret
.special:
	push de
	OVCALL PAGE_LEVEL, place_special, PAGE_CHEST
	pop de
/* roll_beneath - D, E = where something good fell: if the player stands
	there, "You feel something roll beneath your feet." */
roll_beneath:
	ld a,(player_y)
	cp d
	ret nz
	ld a,(player_x)
	cp e
	ret nz
	ld hl,mk_roll
	jp msg_print

/* drop_spot - D, E = a random square within 2 of (md_y, md_x) -> carry if
	something can fall there: in bounds, in sight of there, open floor with
	nothing on it (summon_object). Preserves IX */
drop_spot:
	ld a,5
	call randint
	ld hl,md_y
	add a,(hl)
	sub 3
	ld (md_j),a
	ld a,5
	call randint
	ld hl,md_x
	add a,(hl)
	sub 3
	ld e,a
	ld a,(md_j)
	ld d,a
	call in_bounds
	ret nc
	push de
	call map_addr
	pop de
	ld a,(hl)
	and TERRAIN_MASK
	cp T_FLOOR
	jr z,.floor
	cp T_CORRIDOR
	jr z,.floor
	cp T_FLOOR_LIT
	jr z,.floor
	or a
	ret
.floor:
	push ix
	call item_at
	jr c,.taken
	call trap_at
	jr c,.taken
	ld hl,(player_x)					; in sight of there: the player
	push hl								; stands in for it a moment, as
	ld a,(md_y)							; los looks from them
	ld (player_y),a
	ld a,(md_x)
	ld (player_x),a
	push de
	call los
	pop de
	pop hl
	ld (player_x),hl
	pop ix
	ret
.taken:
	pop ix
	or a
	ret

/* win_drop - Morgoth has died at (md_y, md_x): his Massive Iron Crown,
	then Grond, fall near him, in up to 50 tries. Preserves IX */
win_drop:
	push ix
	xor a
	ld (md_crown),a
	ld b,50
.try:
	push bc
	call drop_spot
	jr nc,.next
	push de
	call item_free_slot
	pop de
	jr nc,.next
	ld (ix+I_Y),d
	ld (ix+I_X),e
	push de
	ld a,(md_crown)
	or a
	ld hl,KIND_IRON_CROWN
	ld a,SN_MORGOTH
	jr z,.make
	ld hl,KIND_LEAD_MACE
	ld a,SN_GROND
.make:
	OVCALL PAGE_MISC, win_item, PAGE_CHEST
	pop de
	call roll_beneath
	ld hl,md_crown
	inc (hl)
	ld a,(hl)
	cp 2
	jr nc,.done
.next:
	pop bc
	djnz .try
	pop ix
	ret
.done:
	pop bc
	pop ix
	ret

; ---------------------------------------------------------------- chests

/* chest_open - D, E = a chest the player opens, a turn taken
	(openobject): a lock must be picked first (the disarming skill with
	nothing off for the dark, less the chest's level, against 1d100); once
	open, a trap still on it goes off, and what's in it falls around it */
chest_open:
	ld (ch_sq),de
	call item_at
	bit CHF_LOCKED,(ix+I_PVAL)
	jr z,.open
	ld hl,(p_confused)
	ld a,h
	or l
	ld hl,mk_too_confused
	jp nz,msg_print
	call chest_level
	OVCALL PAGE_TRAP, lock_skill, PAGE_CHEST
	call .beats
	ld hl,mk_failed_pick
	jp nc,msg_print
	ld hl,mk_picked						; + its level in experience
	call msg_print
	call level_exp
	ld de,(ch_sq)
	call item_at
.open:
	res CHF_LOCKED,(ix+I_PVAL)
	ld (ix+I_NAME2),SN_EMPTY
	set ID_KNOWN2_BIT,(ix+I_IDENT)
	call chest_trap
	ret nc								; (blown up)
	bit CHF_TREASURE,(ix+I_PVAL)
	jr z,.empty
	call item_kind_addr					; what's in it: as if a monster
	ld a,(iy+K_FLAGS+3)					; had died there, nothing good
	and $7F								; (and no winning by it: the curse)
	push af
	ld de,(ch_sq)
	ld a,d
	ld (md_y),a
	ld a,e
	ld (md_x),a
	xor a
	ld (md_good),a
	pop af
	call treasure_drop
.empty:
	ld (ix+I_PVAL),0
	ret
/* .beats - HL = skill, (ch_level): carry if skill - level > 1d100 */
.beats:
	ld a,(ch_level)
	ld e,a
	ld d,0
	or a
	sbc hl,de
	bit 7,h
	ret nz								; (no carry)
	push hl
	ld a,100
	call randint
	pop hl
	ld e,a
	ld d,0
	or a
	sbc hl,de							; carry or zero: not beaten
	ccf
	ret nc
	ld a,h
	or l
	ret z								; (carry clear on a draw)
	scf
	ret

/* chest_level - IX = chest -> (ch_level) = its level (its kind's) */
chest_level:
	call item_kind_addr
	ld a,(iy+K_LEVEL)
	ld (ch_level),a
	ret

/* level_exp - the chest's level in experience */
level_exp:
	ld a,(ch_level)
	ld l,a
	ld h,0
	call add_exp
	jp check_level_up

/* chest_trap - IX = the chest at (ch_sq): its traps go off (chest_trap in
	MORIA2.C) -> IX = it again and carry, unless it blew up */
chest_trap:
	ld a,(ix+I_PVAL)
	ld (ch_flags),a
	bit CHF_LOSE_STR,a					; a needle: strength, unless
	jr z,.poison						; sustained
	call .needle
	ld a,(p_sustain)
	bit A_STR,a
	ld hl,mk_unaffected
	jr nz,.said
	ld a,A_STR
	OVCALL PAGE_MAGIC, dec_stat, PAGE_CHEST
	ld bc,1*256+4
	call .hurt
	ld hl,mk_weakened
.said:
	call msg_print
.poison:
	ld a,(ch_flags)						; a needle: poison, unless resisted
	bit CHF_POISON,a
	jr z,.gas
	call .needle
	ld bc,1*256+6
	call .hurt
	ld a,(p_eflags2+1)
	and TR2_IM_POISON
	jr nz,.gas
	ld a,(p_eflags+3)
	bit EF3_POISON,a
	jr nz,.gas
	ld hl,(p_resist_poison)
	ld a,h
	or l
	jr nz,.gas
	ld a,20
	call randint
	add a,10
	ld hl,(p_poisoned)
	add hl,a
	ld (p_poisoned),hl
.gas:
	ld a,(ch_flags)						; gas: paralysis, unless free action
	bit CHF_PARALYSED,a
	jr z,.summon
	ld hl,mk_yellow_gas
	call msg_print
	ld a,(p_eflags+2)
	and 1<<EF2_FREE_ACT
	ld hl,mk_unaffected
	jr nz,.gas_said
	ld a,20
	call randint
	add a,10
	ld (p_paralysed),a
	ld hl,mk_pass_out
.gas_said:
	call msg_print
.summon:
	ld a,(ch_flags)						; runes: three monsters
	bit CHF_SUMMON,a
	jr z,.explode
	ld b,3
.call:
	push bc
	ld de,(ch_sq)
	OVCALL PAGE_LEVEL, summon_monster, PAGE_CHEST
	pop bc
	djnz .call
	call monsters_see_all
.explode:
	ld de,(ch_sq)
	call item_at
	ld a,(ch_flags)						; and it may blow up
	bit CHF_EXPLODE,a
	scf
	ret z
	ld hl,mk_explosion
	call msg_print
	ld (ix+I_KIND_HI),ITEM_EMPTY
	ld bc,5*256+8
	ld hl,KILLER_CHEST
	call .hurt_by
	or a
	ret
.needle:
	ld hl,mk_needle
	jp msg_print
.hurt:									; BC = dice, from a needle
	ld hl,KILLER_NEEDLE
.hurt_by:
	ld (killer_race),hl
	call damroll
	jp take_hit

/* chest_disarm - D, E = a chest 'D' is aimed at (disarm_trap): a trap
	known to be on it may be disarmed (the disarming skill, less its level,
	against 1d100), failed at, or set off */
chest_disarm:
	ld (ch_sq),de
	call item_at
	bit ID_KNOWN2_BIT,(ix+I_IDENT)		; (no turn for these)
	ld hl,mk_no_trap_seen
	jp z,msg_print
	ld a,(ix+I_PVAL)
	and CH_TRAPPED
	ld hl,mk_not_trapped
	jp z,msg_print
	ld a,1
	ld (turn_taken),a
	call chest_level
	OVCALL PAGE_TRAP, disarm_skill, PAGE_CHEST
	ld (ch_tot),hl
	call chest_open.beats
	jr nc,.not_done
	ld de,(ch_sq)
	call item_at
	ld a,(ix+I_PVAL)
	and $FF-CH_TRAPPED
	ld (ix+I_PVAL),a
	rra									; (CHF_LOCKED)
	ld a,SN_LOCKED
	jr c,$+4
	ld a,SN_DISARMED
	ld (ix+I_NAME2),a
	set ID_KNOWN2_BIT,(ix+I_IDENT)
	ld hl,mk_disarmed
	call msg_print
	jp level_exp
.not_done:
	ld hl,(ch_tot)						; tot > 5 and 1d(tot) > 5: just failed
	bit 7,h
	jr nz,.set_off
	ld de,6
	or a
	sbc hl,de
	jr c,.set_off
	ld hl,(ch_tot)
	call randint16
	ld de,6
	or a
	sbc hl,de
	ld hl,mk_failed_disarm
	jp nc,msg_print
.set_off:
	ld hl,mk_set_off
	call msg_print
	ld de,(ch_sq)
	call item_at
	set ID_KNOWN2_BIT,(ix+I_IDENT)
	jp chest_trap

/* chest_bash - D, E = a chest 'f' shoulders (bash): 1 in 10 it's ruined
	with all in it; or 1 in 10 a lock breaks; or it holds */
chest_bash:
	call item_at
	ld a,10
	call randint
	dec a
	jr nz,.lock
	ld hl,mk_destroyed
	call msg_print
	ld hl,mk_contents
	call msg_print
	ld (ix+I_KIND),low KIND_RUINED_CHEST
	ld (ix+I_KIND_HI),high KIND_RUINED_CHEST
	ld (ix+I_PVAL),0
	ret
.lock:
	bit CHF_LOCKED,(ix+I_PVAL)
	jr z,.firm
	ld a,10
	call randint
	dec a
	jr nz,.firm
	res CHF_LOCKED,(ix+I_PVAL)
	ld hl,mk_lock_breaks
	jp msg_print
.firm:
	ld hl,mk_holds_firm
	jp msg_print

/* chest_search - IX = a chest searching has noticed: a trap on it is
	found, or said to be there again */
chest_search:
	ld a,(ix+I_PVAL)
	and CH_TRAPPED
	ret z
	bit ID_KNOWN2_BIT,(ix+I_IDENT)
	ld hl,mk_chest_trapped
	jp nz,msg_print
	set ID_KNOWN2_BIT,(ix+I_IDENT)
	ld hl,mk_discovered
	jp msg_print

/* chest_magic - D, E = a square, A = 0 traps destroyed round the player
	(td_destroy), 1 disarmed along a beam (disarm_all), 2 destroyed along
	one (td_destroy2): what that does to a chest there -> carry if it did */
chest_magic:
	ld (ch_mode),a
	call item_at
	ret nc
	push de
	call item_kind_addr
	pop de
	ld a,(iy+K_CLASS)
	cp IC_CHEST
	jr nz,.none
	ld a,(ch_mode)
	cp 2
	jr z,.gone
	dec a
	ld a,(ix+I_PVAL)
	ld b,SN_DISARMED
	ld hl,mk_disarmed
	jr nz,.open
	or a								; "Click!", if anything's left of it
	jr z,.none
	ld b,SN_UNLOCKED
	ld hl,mk_click
.open:
	and $FF-CH_TRAPPED-1				; (and CHF_LOCKED)
	ld (ix+I_PVAL),a
	ld (ix+I_NAME2),b
	set ID_KNOWN2_BIT,(ix+I_IDENT)
	call msg_print
	scf
	ret
.gone:									; ("There is a bright flash of light!")
	ld (ix+I_KIND_HI),ITEM_EMPTY
	scf
	ret
.none:
	or a
	ret

/* detect_chests - the chests in view: what traps they have is known
	(detect_trap) */
detect_chests:
	ld ix,ITEM_LIST
	ld b,ITEM_MAX
.each:
	push bc
	ld a,(ix+I_KIND_HI)
	cp KIND_GOLD
	jr nc,.next
	ld a,(view_y)
	ld c,a
	ld a,(ix+I_Y)
	sub c
	cp VIEW_H
	jr nc,.next
	ld a,(view_x)
	ld c,a
	ld a,(ix+I_X)
	sub c
	cp VIEW_W
	jr nc,.next
	call item_kind_addr
	ld a,(iy+K_CLASS)
	cp IC_CHEST
	jr nz,.next
	set ID_KNOWN2_BIT,(ix+I_IDENT)
.next:
	ld de,ITEM_SIZE
	add ix,de
	pop bc
	djnz .each
	ret

; ---------------------------------------------------------------- words

mk_roll:		db "You feel something roll beneath your feet.",0
mk_too_confused: db "You are too confused to pick the lock.",0
mk_picked:		db "You have picked the lock.",0
mk_failed_pick:	db "You failed to pick the lock.",0
mk_needle:		db "A small needle has pricked you!",0
mk_unaffected:	db "You are unaffected.",0
mk_weakened:	db "You feel weakened!",0
mk_yellow_gas:	db "A puff of yellow gas surrounds you!",0
mk_pass_out:	db "You choke and pass out.",0
mk_explosion:	db "There is a sudden explosion!",0
mk_no_trap_seen: db "I don't see a trap.",0
mk_not_trapped:	db "The chest was not trapped.",0
mk_disarmed:	db "You have disarmed the chest.",0
mk_failed_disarm: db "You failed to disarm the chest.",0
mk_set_off:		db "You set a trap off!",0
mk_destroyed:	db "You have destroyed the chest.",0
mk_contents:	db "and its contents!",0
mk_lock_breaks:	db "The lock breaks open!",0
mk_holds_firm:	db "The chest holds firm.",0
mk_discovered:	db "You have discovered a trap on the chest!",0
mk_chest_trapped: db "The chest is trapped!",0
mk_click:		db "Click!",0

; ---------------------------------------------------------------- workspace

md_plain:		db 0
md_y:			db 0
md_x:			db 0
md_j:			db 0
md_good:		db 0
md_flags:		db 0
md_typ:			db 0
md_num:			db 0
md_crown:		db 0
ch_sq:			dw 0
ch_level:		db 0
ch_flags:		db 0
ch_tot:			dw 0
ch_mode:		db 0
