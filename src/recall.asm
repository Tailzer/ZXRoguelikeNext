/* recall.asm - monster memory (overlay page PAGE_RECALL)
	References: RECALL.C roff_recall/bool_roff_recall, TYPES.H recall_type,
	the c_recall updates in CREATURE.C, MORIA2.C, MISC2.C tot_dam and
	SPELLS.C; HELP.C ident_char; MORIA2.C look_see.
	Each race's memory is the C's recall_type (MR_ offsets), kept in the
	C's own bits in pages MEM_PAGE on: what it has been seen to do and to
	be, kills, deaths. rinfo_table (RINFO_PAGE) holds the C's cmove and
	cdefense of every race, so what is learnt can be what it really has.
	The memory outlives characters: it is saved as roguelike.mem with the
	game and when a character dies (save.asm).
 */

; ---------------------------------------------------------------- reaching it

/* rc_open - HL = race: (rc_race) = it, rc_info = its rinfo record; then
	its memory record is paged into the data window: HL = (rc_rec) = it.
	Preserves IX */
rc_open:
	ld (rc_race),hl
	nextreg NR_MMU1,RINFO_PAGE
	ld b,h								; race * RINFO_SIZE (11)
	ld c,l
	add hl,hl
	ld d,h
	ld e,l
	add hl,hl
	add hl,hl
	add hl,de
	add hl,bc
	ld de,rinfo_table
	add hl,de
	ld de,rc_info
	ld bc,RINFO_SIZE
	ldir
	ld hl,(rc_race)
	ld a,h
	add a,MEM_PAGE
	nextreg NR_MMU1,a
	ld e,l
	ld d,MR_SIZE
	mul d,e
	ld hl,DATA_WINDOW
	add hl,de
	ld (rc_rec),hl
	ret

/* rc_field - A = MR_ offset -> HL = that byte of the record */
rc_field:
	ld hl,(rc_rec)
	add hl,a
	ret

; ---------------------------------------------------------------- learning

/* learn_what - IX = a monster, E = LN_, A its detail (from learn, which
	is resident): what the player has just learnt of its race. Preserves
	IX */
learn_what:
	ld (ln_val),a
	ld a,e
	ld (ln_what),a
	ld l,(ix+M_RACE)
	ld h,(ix+M_RACE_HI)
	call rc_open
	xor a								; (rc_mask: cdefense bits)
	ld hl,rc_mask
	ld (hl),a
	inc hl
	ld (hl),a
	inc hl
	ld (hl),a
	inc hl
	ld (hl),a
	ld a,(ln_what)
	add a,a
	ld hl,ln_table
	add hl,a
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	jp (hl)
ln_table:	dw ln_flags, ln_resist, ln_turn, ln_spell, ln_blow, ln_slays
			dw ln_repelled, ln_smart, ln_bore

ln_flags:								; R_FLAGS bits -> cdefense
	ld a,(ln_val)
	ld hl,rc_mask
	bit RF_EVIL,a
	jr z,$+4
	set 1,(hl)							; EVIL
	bit RF_UNDEAD,a
	jr z,$+4
	set 3,(hl)							; UNDEAD
	bit RF_DEMON,a
	jr z,$+4
	set 5,(hl)							; DEMON
	inc hl
	bit RF_CHARM_SLEEP,a
	jr z,$+4
	set 0,(hl)							; CHARM_SLEEP
	bit RF_NO_INFRA,a
	jr z,cdef_learnt
	set 1,(hl)							; NO_INFRA
/* cdef_learnt - rc_mask: what of it the race has is now known */
cdef_learnt:
	ld a,MR_CDEF
	call rc_field
	ld de,rc_mask
	ld bc,rc_info+RI_CDEF
	ld a,4
.byte:
	push af
	ld a,(bc)
	ex de,hl
	and (hl)
	ex de,hl
	or (hl)
	ld (hl),a
	inc hl
	inc de
	inc bc
	pop af
	dec a
	jr nz,.byte
	ret

ln_resist:								; R_RESIST bits -> cdefense: the
	ld a,(ln_val)						; immunities (IM_FROST... IM_ACID
	and $1F								; are bits 11-15)
	add a,a
	add a,a
	add a,a
	ld (rc_mask+1),a
	ld a,(ln_val)						; HURT_LIGHT, HURT_ROCK (bits 6, 7)
	and $60
	add a,a
	ld (rc_mask),a
	jr cdef_learnt

ln_smart:								; INTELLIGENT
	ld a,1
	ld (rc_mask+3),a
	jr cdef_learnt

ln_bore:								; BREAK_WALL (seen or not, as the C)
	ld a,$20
	ld (rc_mask+2),a
	jr cdef_learnt

ln_repelled:							; seen repelled: EVIL
	ld a,(ix+M_ML)
	or a
	ret z
	ld a,2
	ld (rc_mask),a
	jr cdef_learnt

/* ln_turn - a move seen (mon_turn): how it moves, if it woke or slept on,
	that it's cold-blooded or invisible (the C learns those in update_mon,
	when they are what lets it be seen or not) */
ln_turn:
	ld a,(rc_move)
	ld c,a
	ld a,MR_CMOVE
	call rc_field
	ld a,c
	and $3B								; (CM_ATTACK_ONLY... CM_75_RANDOM)
	or (hl)
	ld (hl),a
	inc hl
	inc hl
	ld a,(rc_wake)
	bit RC_BRED,a
	jr z,$+4
	set 5,(hl)							; CM_MULTIPLY
	bit RC_ATE,a
	jr z,$+4
	set 3,(hl)							; CM_EATS_OTHER
	bit RC_OPEN_DOOR,c
	jr z,.door
	set 1,(hl)							; CM_OPEN_DOOR
.door:
	bit RC_PHASE,c
	jr z,.solid
	set 2,(hl)							; CM_PHASE
.solid:
	ld a,(rc_info+RI_CMOVE+2)			; invisible, seen without telepathy:
	rra									; seen invisible (MV_INVIS)
	jr nc,.visible
	ld a,(p_eflags2)
	bit F2_TELEPATHY,a
	jr nz,.visible
	set 0,(hl)							; CM_INVISIBLE
.visible:
	ld a,(rc_info+RI_CDEF+1)			; cold-blooded, within infravision
	bit 1,a								; (NO_INFRA)
	jr z,.warm
	ld a,(p_status+1)
	bit PY2_TIM_INFRA,a
	ld a,(p_infra)
	jr z,$+3
	inc a
	cp (ix+M_CDIS)
	jr c,.warm
	ld a,MR_CDEF+1
	call rc_field
	set 1,(hl)
.warm:
	ld a,(rc_wake)						; woke, or slept on
	and $3F
	ret z
	add a,MR_WAKE-1
	call rc_field
	inc (hl)
	ret nz
	dec (hl)							; (at most 255)
	ret

/* ln_spell - (ln_val) = the spell cast (1-80): it's known to cast it, and
	how often it has been seen to (the low 4 bits, up to 15) */
ln_spell:
	ld a,(ix+M_ML)						; seen, or teleporting you away or
	or a								; a level (45, 57)
	jr nz,.seen
	ld a,(ln_val)
	cp 45
	jr z,.seen
	cp 57
	ret nz
.seen:
	ld a,(ln_val)
	dec a
	ld c,a
	srl a
	srl a
	srl a
	add a,MR_SPELLS
	call rc_field
	ld a,c
	and 7
	ld b,a
	ld a,1
	jr z,.bit
.shift:
	add a,a
	djnz .shift
.bit:
	or (hl)
	ld (hl),a
	ld a,MR_SPELLS
	call rc_field
	ld a,(hl)
	and $0F
	cp $0F
	ret z
	inc (hl)
	ret

ln_blow:								; a blow noticed (seen)
	ld a,(ix+M_ML)
	or a
	ret z
	ld a,(ln_val)
	add a,MR_ATTACKS
	call rc_field
	inc (hl)
	ret nz
	dec (hl)
	ret

/* ln_slays - the weapon or missile (w_slays) has struck it: the first slay
	that applies says what it is, and a brand it's immune to says so
	(tot_dam in MISC2.C) */
ln_slays:
	ld hl,slay_learn
	ld de,(w_slays)
	ld b,12
.each:
	srl d
	rr e
	jr nc,.next
	bit 7,(hl)
	jr nz,.brand
	call .has							; Z if the race lacks it
	jr z,.next
	call .learn							; a slay: that, and no further
	jr .brands
.brand:
	call .has							; immune: it doesn't apply
	jr nz,.next
	jr .brands							; else it does: no further
.next:
	inc hl
	inc hl
	djnz .each
.brands:								; immune to a brand: that's known
	ld de,(w_slays)
	ld hl,slay_learn
	bit 0,e
	call nz,.immune
	ld hl,slay_learn+16
	bit 0,d
	call nz,.immune
	ld hl,slay_learn+18
	bit 1,d
	ret z
.immune:
	call .has
	ret z
.learn:									; HL = entry: rc_mask gets its bit
	push hl
	push de
	push bc
	ld a,(hl)
	and 3
	ld de,rc_mask
	add de,a
	inc hl
	ld a,(hl)
	ld (de),a
	call cdef_learnt
	xor a
	ld hl,rc_mask
	ld (hl),a
	inc hl
	ld (hl),a
	inc hl
	ld (hl),a
	inc hl
	ld (hl),a
	pop bc
	pop de
	pop hl
	ret
.has:									; HL = entry -> NZ if the race has
	push hl								; its bit (preserves HL)
	ld a,(hl)
	and 3
	push de
	ld de,rc_info+RI_CDEF
	add de,a
	inc hl
	ld a,(de)
	and (hl)
	pop de
	pop hl
	ret
; in slay_table's order (w_slays bits): cdefense byte (+$80: a brand,
; the bit its immunity), the bit
slay_learn:
	db $81,$20							; lightning brand (IM_LIGHTNING)
	db 0,$10, 0,$10						; execute dragon, slay dragon
	db 0,$08, 0,$04						; undead, orc
	db 2,$01, 2,$02						; troll, giant
	db 0,$20							; demon
	db $81,$08, $81,$10					; frost brand, flame tongue
	db 0,$02, 0,$01						; evil, animal

/* mon_eat - IX = a monster about to step onto D, E, where another stands
	(make_move in CREATURE.C): one that eats others (CM_EATS_OTHER) and is
	worth more experience eats it - it's simply gone - and moves in ->
	carry if so. Preserves IX, DE */
mon_eat:
	ld (me_sq),de
	ld l,(ix+M_RACE)
	ld h,(ix+M_RACE_HI)
	call rc_open
	ld de,(me_sq)
	ld a,(rc_info+RI_CMOVE+2)
	bit 3,a								; (CM_EATS_OTHER)
	ret z
	ld l,(ix+M_RACE)					; its experience
	ld h,(ix+M_RACE_HI)
	call race_addr
	ld l,(iy+R_EXP)
	ld h,(iy+R_EXP+1)
	ld (rf_t),hl
	ld de,(me_sq)
	push ix
	push de
	call mon_at							; the other, and its
	pop de
	jr nc,.not
	ld l,(ix+M_RACE)
	ld h,(ix+M_RACE_HI)
	push de
	call race_addr
	pop de
	ld l,(iy+R_EXP)
	ld h,(iy+R_EXP+1)
	ex de,hl
	push hl
	ld hl,(rf_t)						; more than it: eaten
	or a
	sbc hl,de
	pop de
	jr z,.not
	jr c,.not
	ld a,(ix+M_ML)						; (seen eaten: it's known to)
	push af
	push de
	call mon_remove
	pop de
	pop af
	pop ix
	or a
	jr z,.eaten
	ld hl,rc_wake
	set RC_ATE,(hl)
.eaten:
	scf
	ret
.not:
	pop ix
	or a
	ret
me_sq:			dw 0

/* learn_kill - IX = a monster that died, D = how many things it was seen
	to drop, A = bit 0 objects, 1 treasure among them, 7 the player killed
	it (monster_death, chests.asm): what it carries is known, and the
	player's kills of it counted, if it was seen (or is Morgoth) */
learn_kill:
	ld (ln_val),a
	ld a,d
	ld (ln_what),a
	ld l,(ix+M_RACE)
	ld h,(ix+M_RACE_HI)
	call rc_open
	ld a,(rc_info+RI_CMOVE+3)			; CM_WIN: always
	rla
	jr c,.seen
	ld a,(ix+M_ML)
	or a
	ret z
	ld a,(ln_val)						; (the player's kill: and not blind)
	rla
	jr nc,.seen
	ld a,(p_status)
	bit PY_BLIND,a
	ret nz
.seen:
	ld a,(ln_what)						; what it dropped: the most seen
	or a
	jr z,.kills
	cp 32
	jr c,$+4
	ld a,31
	ld c,a
	ld a,MR_CMOVE+3
	call rc_field
	ld a,(hl)
	rrca
	rrca
	and $1F
	cp c
	jr nc,$+3
	ld a,c
	add a,a
	add a,a
	ld c,a
	ld a,(ln_val)
	and 3
	or (hl)
	and 3
	or c
	ld (hl),a
.kills:
	ld a,(ln_val)
	rla
	ret nc
	ld a,MR_KILLS
	call rc_field
/* count_up - HL = a word to add one to, at most 65535 */
count_up:
	inc (hl)
	ret nz
	inc hl
	inc (hl)
	ret nz
	dec (hl)
	dec hl
	dec (hl)
	ret

/* note_death - the character has died: if a monster did it, its race has
	killed one more of your ancestors */
note_death:
	ld hl,(killer_race)
	ld a,h
	cp high KILLER_STARVATION
	ret nc
	call rc_open
	ld a,MR_DEATHS
	call rc_field
	jr count_up

/* recall_known - HL = race -> NZ if anything is known of it
	(bool_roff_recall) */
recall_known:
	call rc_open
	ld b,MR_ATTACKS+4
	xor a
.byte:
	or (hl)
	inc hl
	djnz .byte
	or a
	ret

; ---------------------------------------------------------------- telling it

/* roff_recall - HL = race: everything known of it, as the C words it,
	then "--pause--" -> A = the key pressed. The screen is cleared for it;
	the caller puts the view back (recall_done) */
roff_recall:
	ld (rf_race),hl
	call rc_open						; its memory, as it is now
	ld de,rc_mem
	ld bc,MR_SIZE
	ldir
	ld hl,(rf_race)						; its race record
	call race_addr
	push iy
	pop hl
	ld de,rc_racerec
	ld bc,RACE_SIZE
	ldir
	ld hl,(rf_race)						; its spells: race * 12
	ld d,h
	ld e,l
	add hl,hl
	add hl,de
	add hl,hl
	add hl,hl
	ld de,mspell_table
	add hl,de
	nextreg NR_MMU1,MSPELL_PAGE
	ld de,rc_spell
	ld bc,MS_SIZE
	ldir
	xor a								; (spells3's high word)
	ld (rc_spell+10),a
	ld (rc_spell+11),a
	ld hl,rc_spell						; rspells = known & has, not the
	ld de,rc_mem+MR_SPELLS				; frequency
	ld bc,rf_spells
	ld a,12
.spells:
	push af
	ld a,(de)
	and (hl)
	ld (bc),a
	inc hl
	inc de
	inc bc
	pop af
	dec a
	jr nz,.spells
	ld a,(rf_spells)
	and $F0
	ld (rf_spells),a
	ld hl,rc_mem+MR_CDEF				; rcdefense = known & has
	ld de,rc_info+RI_CDEF
	ld bc,rf_cdef
	ld a,4
.cdef:
	push af
	ld a,(de)
	and (hl)
	ld (bc),a
	inc hl
	inc de
	inc bc
	pop af
	dec a
	jr nz,.cdef
	ld hl,(rc_mem+MR_CMOVE)				; rcmove = known, and CM_WIN always
	ld (rf_cmove),hl
	ld a,(rc_info+RI_CMOVE+3)
	and $80
	ld hl,rc_mem+MR_CMOVE+3
	or (hl)
	ld (rf_cmove+3),a
	ld a,(rc_mem+MR_CMOVE+2)
	ld (rf_cmove+2),a
	call clear_screen
	xor a
	ld (rf_len),a
	ld (rf_row),a
	call rf_name						; "The Kobold:"
	call rf_history
	call rf_desc
	call rf_moves
	call rf_kill
	call rf_spells_said
	call rf_armour
	call rf_abilities
	call rf_defences
	call rf_awareness
	call rf_treasure
	call rf_attacks
	ld a,(rc_info+RI_CMOVE+3)			; Morgoth
	rla
	ld hl,rt_wins
	call c,roff
	ld hl,rt_nl
	call roff
	ld hl,rt_pause
	ld a,(rf_row)
	ld d,a
	ld e,0
	ld c,ATTR_WHITE
	call print_at
	jp read_ascii

/* recall_done - the view back after roff_recall */
recall_done:
	call clear_screen
	call draw_map
	jp draw_status

; the parts of roff_recall, in its order

rf_name:
	ld hl,rc_racerec+R_NAME
	ld a,(rc_racerec+R_FLAGS)
	bit RF_UNIQUE,a
	jr nz,.unique
	push hl
	ld hl,rt_the
	call roff
	pop hl
.unique:
	call roff
	ld hl,rt_colon_nl
	jp roff

rf_history:								; kills and deaths
	ld hl,(rc_mem+MR_DEATHS)
	ld a,(rc_racerec+R_FLAGS)
	bit RF_UNIQUE,a
	jr z,.common
	ld a,h								; a unique
	or l
	jr z,.no_deaths
	push hl
	ld hl,rt_slain_ancestors			; "It has slain 2 of your ancestors"
	call roff
	pop hl
	push hl
	call rf_num
	ld hl,rt_of_ancestors
	call roff
	call rf_dead
	pop de								; (deaths)
	jr z,.unavenged
	ld hl,rt_avenged					; ", but you have avenged him!" /
	call roff							; "them"
	ld hl,rt_him
	call rf_plural
	ld hl,rt_avenged_end
	jp roff
.unavenged:
	ld hl,rt_who							; ", who remains unavenged."
	call roff
	ld hl,rt_remains
	call rf_plural
	ld hl,rt_unavenged
	jp roff
.no_deaths:
	call rf_dead
	ret z
	ld hl,rt_slain_foe
	jp roff
.common:
	ld a,h
	or l
	jr z,.no_deaths_c
	push hl
	call rf_num							; "2 of your ancestors have been
	ld hl,rt_of_ancestors_c				; killed by this creature, and"
	call roff
	pop de
	push de
	ld hl,rt_has
	call rf_plural
	ld hl,rt_been_killed
	call roff
	pop de
	ld hl,(rc_mem+MR_KILLS)
	ld a,h
	or l
	ld hl,rt_never_defeated
	jp z,roff
	ld hl,rt_at_least
	call roff
	ld hl,(rc_mem+MR_KILLS)
	push hl
	call rf_num
	ld hl,rt_beasts
	call roff
	pop de
	ld hl,rt_has
	call rf_plural
	ld hl,rt_exterminated
	jp roff
.no_deaths_c:
	ld hl,(rc_mem+MR_KILLS)
	ld a,h
	or l
	ld hl,rt_no_battles
	jp z,roff
	ld hl,rt_at_least_these
	call roff
	ld hl,(rc_mem+MR_KILLS)
	push hl
	call rf_num
	ld hl,rt_these_creatures
	call roff
	pop de
	ld hl,rt_has
	call rf_plural
	ld hl,rt_by_ancestors
	jp roff
/* rf_dead - NZ if this unique is dead (this character killed it) */
rf_dead:
	ld hl,(rf_race)
	ld a,l
	and 7
	ld b,a
	srl h
	rr l
	srl h
	rr l
	srl h
	rr l
	ld de,uniques_dead
	add hl,de
	ld a,(hl)
	inc b
.bit:
	dec b
	jr z,.got
	rrca
	jr .bit
.got:
	and 1
	ret
/* rf_plural - DE = a number, HL = the singular, followed by the plural
	("him",0,"them"): the one that fits */
rf_plural:
	ld a,d
	or a
	jr nz,.plural
	ld a,e
	dec a
	jp z,roff
.plural:
	xor a								; (past the singular)
	ld bc,0
	cpir
	jp roff

rf_desc:								; the description (MON_DESC.DAT)
	ld a,(rc_info+RI_DPAGE)
	cp $FF
	ld hl,rt_trouble
	jp z,roff
	add a,DESC_PAGE
	nextreg NR_MMU1,a
	ld hl,(rc_info+RI_DADDR)
	call roff
	ld hl,rt_stop
	jp roff

rf_moves:								; where and how it moves
	xor a
	ld (rf_k),a
	ld a,(rc_racerec+R_LEVEL)
	or a
	jr nz,.deep
	ld hl,rt_town
	call roff
	jr .found
.deep:
	ld hl,(rc_mem+MR_KILLS)
	ld a,h
	or l
	jr z,.moving
	ld hl,rt_depths
	call roff
	ld a,(rc_racerec+R_LEVEL)
	ld e,a
	ld d,50
	mul d,e
	ex de,hl
	call rf_num
	ld hl,rt_feet
	call roff
.found:
	ld a,1
	ld (rf_k),a
.moving:
	ld a,(rf_cmove)
	and $3B|$38							; CM_ALL_MV_FLAGS, CM_RANDOM_MOVE
	jr z,.attack_only
	call .and_it
	ld hl,rt_moves
	call roff
	ld a,(rf_cmove)
	and $38
	jr z,.speed
	rrca
	rrca
	rrca
	ld hl,howmuch_words
	call rf_word_at
	ld hl,rt_erratically
	call roff
.speed:
	ld a,(rc_racerec+R_SPEED)
	sub 10								; mspeed
	cp 1
	ld hl,rt_normal_speed
	jp z,.said
	push af
	ld a,(rf_cmove)
	and $38
	ld hl,rt_and
	call nz,roff
	pop af
	bit 7,a
	jr nz,.slow
	or a
	jr z,.slow
	cp 3
	jr c,.quick
	ld hl,rt_very
	jr z,.q_said
	ld hl,rt_unbelievably
.q_said:
	call roff
.quick:
	ld hl,rt_quickly
	jr .said
.slow:
	cp -1
	ld hl,rt_very
	jr z,.s_said
	or a
	jr z,.slowly
	ld hl,rt_incredibly
.s_said:
	call roff
.slowly:
	ld hl,rt_slowly
.said:
	call roff
.attack_only:
	ld a,(rf_cmove)
	rra									; CM_ATTACK_ONLY
	jr nc,.stop
	ld a,(rf_k)
	or a
	ld hl,rt_but
	jr nz,.but
	ld hl,rt_it
	ld a,1
	ld (rf_k),a
.but:
	call roff
	ld hl,rt_deign
	call roff
.stop:
	ld a,(rf_k)
	or a
	ret z
	ld hl,rt_stop
	jp roff
.and_it:
	ld a,(rf_k)
	or a
	ld hl,rt_comma_and
	jp nz,roff
	ld a,1
	ld (rf_k),a
	ld hl,rt_it
	jp roff

rf_kill:								; its kind and its experience
	ld hl,(rc_mem+MR_KILLS)
	ld a,h
	or l
	ret z
	ld hl,rt_kill_of
	call roff
	ld a,(rc_info+RI_CDEF)				; ANIMAL, EVIL, UNDEAD
	rra
	ld hl,rt_natural
	call c,roff
	ld a,(rc_info+RI_CDEF)
	bit 1,a
	ld hl,rt_evil
	call nz,roff
	ld a,(rc_info+RI_CDEF)
	bit 3,a
	ld hl,rt_undead
	call nz,roff
	ld hl,rt_giant						; GIANT, ORC, DRAGON, DEMON, TROLL
	ld a,(rc_info+RI_CDEF+2)
	bit 1,a
	jr nz,.kind
	ld a,(rc_info+RI_CDEF)
	ld hl,rt_orc
	bit 2,a
	jr nz,.kind
	ld hl,rt_dragon
	bit 4,a
	jr nz,.kind
	ld hl,rt_demon
	bit 5,a
	jr nz,.kind
	ld hl,rt_troll
	ld a,(rc_info+RI_CDEF+2)
	bit 0,a
	jr nz,.kind
	ld hl,rt_creature
.kind:
	call roff
	ld a,(rc_racerec+R_LEVEL)			; mexp * level / plev
	ld e,a
	ld a,(rc_racerec+R_EXP)
	ld d,a
	mul d,e
	push de
	ld a,(rc_racerec+R_LEVEL)
	ld e,a
	ld a,(rc_racerec+R_EXP+1)
	ld d,a
	mul d,e
	pop hl
	ld a,h
	add a,e
	ld h,a
	ld a,d
	adc a,0
	ld e,a
	ld a,(p_lev)
	ld c,a
	call div24_8
	push af
	push hl
	push de
	ld hl,rt_worth
	call roff
	pop de
	pop hl
	ld (rf_t),hl						; (the whole part, to say "point")
	ld a,e
	ld (rf_t+2),a
	call rf_num24
	ld a,'.'
	call rf_char
	pop af								; (remainder * 1000 / plev + 5) / 10
	ld e,a
	ld d,250
	mul d,e
	ex de,hl
	add hl,hl
	add hl,hl
	ld a,(p_lev)
	ld c,a
	call div16_8
	ld de,5
	add hl,de
	ld c,10
	call div16_8
	ld (rf_t+3),hl						; (low byte: the hundredths)
	ld a,l
	cp 10
	jr nc,.two
	ld a,'0'
	call rf_char
	ld hl,(rf_t+3)
.two:
	call rf_num
	ld hl,rt_point
	call roff
	ld hl,(rf_t)						; "point" for exactly 1.00
	dec hl
	ld a,h
	or l
	ld hl,rf_t+2
	or (hl)
	ld hl,rf_t+3
	or (hl)
	ld a,'s'
	call nz,rf_char
	ld hl,rt_for_a						; " for a 3rd level character."
	call roff
	ld a,(p_lev)
	cp 8
	jr z,.an
	cp 11
	jr z,.an
	cp 18
	jr nz,.level
.an:
	ld a,'n'
	call rf_char
.level:
	ld a,' '
	call rf_char
	ld a,(p_lev)
	ld l,a
	ld h,0
	call rf_num
	ld a,(p_lev)						; th, st, nd, rd
	ld c,10
	ld l,a
	ld h,0
	call div16_8						; HL = tens, A = units
	ld b,a
	ld a,l
	dec a
	ld hl,rt_th
	jr z,.ord
	ld a,b
	ld hl,rt_st
	cp 1
	jr z,.ord
	ld hl,rt_nd
	cp 2
	jr z,.ord
	ld hl,rt_rd
	cp 3
	jr z,.ord
	ld hl,rt_th
.ord:
	call roff
	ld hl,rt_level_char
	call roff
	ld a,(rc_info+RI_CDEF+2)			; GROUP
	bit 3,a
	ret z
	ld hl,rt_groups
	jp roff

/* rf_spells_said - its breaths, then its spells, and how often */
rf_spells_said:
	ld hl,breath_mask					; breaths: rspells & CS_BREATHE..
	ld de,rf_breaths
	call .list
	ld hl,spell_mask					; the rest
	ld de,rf_magic
	call .list
	ld a,(rf_breaths)
	ld (rf_k),a
	or a
	jr z,.magic
	ld hl,rt_breathe
	call roff
	ld hl,rf_breaths
	ld de,rt_and_sep
	call rf_items
.magic:
	ld a,(rf_magic)
	or a
	jr z,.often
	ld a,(rf_k)
	or a
	ld hl,rt_also
	jr nz,$+5
	ld hl,rt_it_is
	call roff
	ld hl,rt_magical
	call roff
	ld a,(rf_magic+1)					; (the first from spells, and seen
	cp 32								;  casting to escape)
	jr nc,.plainly
	ld a,(rc_mem+MR_CDEF+3)
	rra
	ld hl,rt_intelligently
	call c,roff
.plainly:
	ld hl,rt_spells_which
	call roff
	ld hl,rf_magic
	ld de,rt_or_sep
	call rf_items
.often:
	ld a,(rf_breaths)
	ld hl,rf_magic
	or (hl)
	ret z
	ld a,(rc_mem+MR_SPELLS)				; seen more than 5 times
	and $0F
	cp 6
	jr c,.stop
	ld hl,rt_time_in
	call roff
	ld a,(rc_spell)
	and $0F
	ld l,a
	ld h,0
	call rf_num
.stop:
	ld hl,rt_stop
	jp roff
.list:									; HL = 10-byte mask, DE = list:
	ld (rf_lp),de						; the spell numbers (0-79) in both
	ld (rf_mp),hl						; rf_spells and the mask, count
	xor a								; first
	ld (de),a
	ld c,a
.bit:
	ld a,c
	srl a
	srl a
	srl a
	ld e,a
	ld d,0
	ld hl,rf_spells
	add hl,de
	ld b,(hl)
	ld hl,(rf_mp)
	add hl,de
	ld a,b
	and (hl)
	ld b,a
	ld a,c
	and 7
	jr z,.test
.shift:
	srl b
	dec a
	jr nz,.shift
.test:
	bit 0,b
	jr z,.skip
	ld hl,(rf_lp)
	inc (hl)
	ld a,(hl)
	add hl,a
	ld (hl),c
.skip:
	inc c
	ld a,c
	cp 80
	jr c,.bit
	ret

/* rf_items - HL = a list (count, spell numbers), DE = the last separator:
	"a, b and c" */
rf_items:
	ld (rf_sep),de
	ld b,(hl)
	inc hl
	ld c,0
.item:
	push bc
	push hl
	ld a,c
	or a
	jr nz,.sep
	ld a,(rf_pre)						; (something came before the first)
	or a
	jr z,.word
.sep:
	ld a,c
	inc a
	cp b
	ld hl,rt_comma_sep
	jr nz,.said
	ld hl,(rf_sep)
.said:
	call roff
.word:
	pop hl
	ld a,(hl)
	push hl
	ld hl,spell_words
	call rf_word
	pop hl
	inc hl
	pop bc
	inc c
	ld a,c
	cp b
	jr c,.item
	xor a
	ld (rf_pre),a
	ret

rf_armour:								; armour class and hit dice, after
	ld a,(rc_racerec+R_LEVEL)			; enough kills
	ld e,a
	ld a,(rc_racerec+R_FLAGS)
	bit RF_UNIQUE,a
	jr nz,.unique
	ld a,e								; kills > 304 / (4 + level)
	add a,4
	jr .test
.unique:								; kills > 304 / (38 + 5*level/4)
	ld d,5
	mul d,e
	ex de,hl
	srl h
	rr l
	srl h
	rr l
	ld de,38
	add hl,de
	ld a,h
	or a
	jr nz,.known						; (304 / more than 255: 1, beaten)
	ld a,l
.test:
	ld c,a
	ld hl,304
	call div16_8
	ld de,(rc_mem+MR_KILLS)
	or a
	sbc hl,de
	ret nc
.known:
	ld hl,(rc_mem+MR_KILLS)				; (a unique: needs a kill too)
	ld a,h
	or l
	ret z
	ld hl,rt_armour
	call roff
	ld a,(rc_racerec+R_AC)
	ld l,a
	ld h,0
	call rf_num
	ld hl,rt_life
	call roff
	ld a,(rc_racerec+R_FLAGS)
	bit RF_MAX_HP,a
	ld hl,rt_maximized
	call nz,roff
	ld hl,rt_life_rating
	call roff
	ld a,(rc_racerec+R_HD_DICE)
	ld l,a
	ld h,0
	call rf_num
	ld a,'d'
	call rf_char
	ld a,(rc_racerec+R_HD_SIDES)
	ld l,a
	ld h,0
	call rf_num
	ld hl,rt_stop
	jp roff

rf_abilities:							; boring, invisible, doors...
	xor a
	ld (rf_k),a
	ld a,(rf_cdef+2)					; BREAK_WALL
	bit 5,a
	jr z,.moves
	ld hl,rt_bore
	call roff
	ld a,1
	ld (rf_k),a
.moves:
	ld a,(rf_cmove+2)					; CM_SPECIAL: bits 16-21
	and $3F
	ld b,0
	ld de,rf_magic+1					; (a list, as the spells)
	ld c,0
.bit:
	rra
	jr nc,.next
	push af
	ld a,c
	add a,96							; (move_words follow spell_words)
	ld (de),a
	inc de
	inc b
	pop af
.next:
	inc c
	or a
	jr nz,.bit
	ld a,b
	ld (rf_magic),a
	or a
	jr z,.end
	ld a,(rf_k)							; (after boring: joined on)
	ld (rf_pre),a
	or a
	ld hl,rt_it_can
	call z,roff
	ld a,1
	ld (rf_k),a
	ld hl,rf_magic
	ld de,rt_and_sep
	call rf_items
.end:
	ld a,(rf_k)
	or a
	ret z
	ld hl,rt_stop
	jp roff

rf_defences:							; weaknesses, resistances, blood
	ld a,(rf_cdef)						; HURT_LIGHT, HURT_ROCK
	and $C0
	jr z,.immune
	ld hl,rt_susceptible
	call roff
	ld a,(rf_cdef)
	bit 6,a
	ld hl,rt_light
	call nz,roff
	ld a,(rf_cdef)
	cp $C0
	ld hl,rt_and_sep
	call nc,roff
	ld a,(rf_cdef)
	bit 7,a
	ld hl,rt_rock
	call nz,roff
	ld hl,rt_stop
	call roff
.immune:
	ld a,(rf_cdef+1)					; IM_FROST... IM_ACID: bits 11-15
	rrca
	rrca
	rrca
	and $1F
	jr z,.blood
	ld de,rf_magic+1
	ld b,0
	ld c,0
.bit:
	rra
	jr nc,.next
	push af
	ld a,c
	add a,102							; (immune_words)
	ld (de),a
	inc de
	inc b
	pop af
.next:
	inc c
	or a
	jr nz,.bit
	ld a,b
	ld (rf_magic),a
	ld hl,rt_resists
	call roff
	ld hl,rf_magic
	ld de,rt_and_sep
	call rf_items
	ld hl,rt_stop
	call roff
.blood:
	ld a,(rf_cdef+1)					; NO_INFRA (bit 9), CHARM_SLEEP (8)
	and 3
	ret z
	bit 1,a
	ld hl,rt_cold
	call nz,roff
	ld a,(rf_cdef+1)
	rra
	jr nc,.stop
	bit 0,a								; (NO_INFRA, shifted)
	ld hl,rt_and_charm
	jr nz,$+5
	ld hl,rt_it_charm
	call roff
	ld hl,rt_charm
	call roff
.stop:
	ld hl,rt_stop
	jp roff

rf_awareness:							; how alert it is
	ld a,(rc_mem+MR_WAKE)				; wake^2 > sleep, ignore 255, or
	ld e,a								; never asleep and 10 kills
	ld d,a
	mul d,e
	ld a,(rc_racerec+R_SLEEP)
	ld l,a
	ld h,0
	or a
	sbc hl,de
	jr c,.known
	ld a,(rc_mem+MR_IGNORE)
	inc a
	jr z,.known
	ld a,(rc_racerec+R_SLEEP)
	or a
	ret nz
	ld hl,(rc_mem+MR_KILLS)
	ld de,10
	or a
	sbc hl,de
	ret c
.known:
	ld hl,rt_it_
	call roff
	ld a,(rc_racerec+R_SLEEP)			; the first threshold it's above
	ld hl,sleep_thresholds
.find:
	ld c,(hl)
	inc hl
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	inc c
	jr z,.this							; ($FF: the last)
	cp c
	jr c,.find
.this:
	ex de,hl
.said:
	call roff
	ld hl,rt_intruders
	call roff
	ld a,(rc_racerec+R_AAF)
	ld e,a
	ld d,10
	mul d,e
	ex de,hl
	call rf_num
	ld hl,rt_feet_stop
	jp roff
; sleep above this (descending), what it does
sleep_thresholds:
	db 200
	dw rt_ignore
	db 95
	dw rt_very_little
	db 75
	dw rt_little
	db 45
	dw rt_overlook
	db 25
	dw rt_quite_while
	db 10
	dw rt_a_while
	db 5
	dw rt_fairly
	db 3
	dw rt_observant
	db 1
	dw rt_very_observant
	db 0
	dw rt_vigilant
	db $FF								; (0 itself)
	dw rt_ever_vigilant

rf_treasure:							; what it may carry
	ld a,(rf_cmove+3)
	and 3
	ret z
	ld hl,rt_may
	call roff
	ld a,(rf_cmove+3)					; j = how many seen
	rrca
	rrca
	and $1F
	ld (rf_k),a
	ld a,(rc_info+RI_CMOVE+3)			; its CM_ treasure bits: 60 4, 90 8
	and $7C
	ld c,a
	ld a,(rf_k)
	cp 1
	jr nz,.not1
	ld a,c
	cp 4
	ld hl,rt_sometimes
	jr z,.often
	ld hl,rt_often
	jr .often
.not1:
	cp 2
	jr nz,.carry
	ld a,c
	cp 4|8
	jr nz,.carry
	ld hl,rt_often
.often:
	call roff
.carry:
	ld hl,rt_carry
	call roff
	ld a,(rf_k)
	cp 1
	jr z,.one
	cp 2
	ld hl,rt_one_or_two
	jr z,.number_said
	ld hl,rt_up_to
	call roff
	ld a,(rf_k)
	ld l,a
	ld h,0
	call rf_num
	jr .objects
.number_said:
	call roff
.objects:
	ld a,(rf_cmove+3)
	rra
	jr nc,.treasures
	ld hl,rt_objects
	call roff
	ld a,(rf_cmove+3)
	bit 1,a
	jr z,.stop
	ld hl,rt_or_treasure
	call roff
	ld a,(rf_k)
	cp 2
	ld a,'s'
	call nc,rf_char
.stop:
	ld hl,rt_stop
	jp roff
.treasures:
	ld hl,rt_treasures
	jp roff
.one:
	ld a,(rf_cmove+3)
	rra
	ld hl,rt_an_object
	jr c,.object
	ld hl,rt_treasure
	jp roff
.object:
	call roff
	ld a,(rf_cmove+3)
	bit 1,a
	jr z,.stop
	ld hl,rt_or_treasure
	call roff
	jr .stop

rf_attacks:								; the blows it has been seen to use
	ld hl,rc_mem+MR_ATTACKS				; k = how many are known
	ld b,4
	ld c,0
.count:
	ld a,(hl)
	or a
	jr z,$+3
	inc c
	inc hl
	djnz .count
	ld a,c
	ld (rf_k),a
	xor a
	ld (rf_j),a
	ld (rf_i),a
.each:
	ld a,(rf_i)
	cp 4
	jp nc,.end
	add a,a
	add a,a
	ld hl,rc_racerec+R_ATTACKS
	add hl,a
	ld a,(hl)
	or a
	jp z,.end
	ld (rf_att),hl
	ld a,(rf_i)
	ld hl,rc_mem+MR_ATTACKS
	add hl,a
	ld a,(hl)
	or a
	jp z,.next
	ld (rf_seen),a
	ld hl,rf_j
	inc (hl)
	ld a,(hl)
	dec a
	ld hl,rt_it_can
	jr z,.sep
	inc a
	ld hl,rf_k
	cp (hl)
	ld hl,rt_comma_and_
	jr z,.sep
	ld hl,rt_comma_sep
.sep:
	call roff
	ld hl,(rf_att)
	inc hl
	ld a,(hl)							; how: hit, bite...
	cp 24
	jr c,$+3
	xor a
	ld hl,method_words
	call rf_word_at
	ld hl,(rf_att)
	ld a,(hl)
	cp 1								; type 1 with no damage: just "hit"
	jr nz,.to
	inc hl
	inc hl
	ld a,(hl)
	or a
	jp z,.next
	inc hl
	ld a,(hl)
	or a
	jp z,.next
.to:
	ld hl,rt_to
	call roff
	ld hl,(rf_att)
	ld a,(hl)
	cp 26
	jr c,$+3
	xor a
	ld hl,type_words
	call rf_word_at
	ld hl,(rf_att)						; the damage, once known
	inc hl
	inc hl
	ld a,(hl)
	or a
	jr z,.next
	ld d,a
	inc hl
	ld e,(hl)
	ld a,e
	or a
	jr z,.next
	mul d,e								; d1 * d2 * 80
	ld b,d
	ld c,e
	ld hl,0
	ld a,80
.x80:
	add hl,bc
	dec a
	jr nz,.x80
	ld (rf_t),hl
	ld a,(rc_racerec+R_LEVEL)			; (4 + level) * seen, twice for a
	add a,4								; unique
	ld e,a
	ld a,(rf_seen)
	ld d,a
	mul d,e
	ld a,(rc_racerec+R_FLAGS)
	bit RF_UNIQUE,a
	jr z,$+6
	ex de,hl
	add hl,hl
	ex de,hl
	ld hl,(rf_t)
	or a
	sbc hl,de
	jr nc,.next
	ld hl,(rf_att)
	ld a,(hl)
	cp 19								; (experience: "by")
	ld hl,rt_by
	jr z,$+5
	ld hl,rt_with_damage
	call roff
	ld hl,(rf_att)
	inc hl
	inc hl
	ld a,(hl)
	ld l,a
	ld h,0
	call rf_num
	ld a,'d'
	call rf_char
	ld hl,(rf_att)
	inc hl
	inc hl
	inc hl
	ld a,(hl)
	ld l,a
	ld h,0
	call rf_num
.next:
	ld hl,rf_i
	inc (hl)
	jp .each
.end:
	ld a,(rf_j)
	or a
	ld hl,rt_stop
	jp nz,roff
	ld a,(rf_k)
	or a
	jr z,.nothing
	ld a,(rc_mem+MR_ATTACKS)
	cp 10
	ld hl,rt_no_physical
	jp nc,roff
.nothing:
	ld hl,rt_nothing_known
	jp roff

; ---------------------------------------------------------------- the words

/* rf_word - A = an entry of spell_words (which go on into move_words and
	immune_words), HL ignored -> roff it */
rf_word:
	ld hl,spell_words
/* rf_word_at - HL = a list of words, A = which -> roff it */
rf_word_at:
	or a
	jp z,roff
	ld b,a
.skip:
	push bc
	xor a
	ld bc,0
	cpir
	pop bc
	djnz .skip
	jp roff

/* roff - HL = text: added to the screen a line at a time, words wrapped
	at 79 columns ('\n' ends a line), as the C's roff */
roff:
	ld a,(hl)
	or a
	ret z
	inc hl
	push hl
	call rf_char
	pop hl
	jr roff
/* rf_char - A = a character for roff */
rf_char:
	ld c,a
	ld a,(rf_len)
	ld hl,rf_buf
	add hl,a
	ld (hl),c
	ld a,c
	cp 10
	jr z,.line
	ld a,(rf_len)
	cp 79
	jr z,.wrap
	inc a
	ld (rf_len),a
	ret
.line:
	ld (hl),0
	xor a
	ld (rf_len),a
	jr rf_print
.wrap:									; back to a space: print to it, keep
	ld b,0								; the rest
.back:
	ld a,(hl)
	cp ' '
	jr z,.cut
	dec hl
	inc b
	jr .back
.cut:
	ld (hl),0
	inc hl
	push hl
	push bc
	call rf_print
	pop bc
	pop hl
	ld a,b
	ld (rf_len),a
	or a
	ret z
	ld c,b
	ld b,0
	ld de,rf_buf
	ldir
	ret
rf_print:								; rf_buf on row rf_row
	ld hl,rf_buf
	ld a,(rf_row)
	ld d,a
	inc a
	ld (rf_row),a
	ld e,0
	ld c,ATTR_WHITE
	jp print_at

/* rf_num - HL = a number for roff; rf_num24 - E:HL */
rf_num:
	ld e,0
rf_num24:
	push hl
	ld hl,rf_numbuf+9
	ld (hl),0
	ld (rf_np),hl
	pop hl
.digit:
	ld c,10
	call div24_8
	add a,'0'
	push hl
	ld hl,(rf_np)
	dec hl
	ld (hl),a
	ld (rf_np),hl
	pop hl
	ld a,h
	or l
	or e
	jr nz,.digit
	ld hl,(rf_np)
	jp roff

; masks over the 80 spell bits (spells, spells2, spells3's low word)
breath_mask:	db $00,$00,$F8,$00, $3F,$00,$00,$80, $7F,$00
spell_mask:		db $F0,$FF,$07,$FF, $C0,$FF,$FF,$7F, $80,$FF

; desc_spell (spell bits 0-95), then desc_move (96-101), desc_immune (102-)
spell_words:
	db "1",0,"2",0,"4",0,"8",0
	db "teleport short distances",0,"teleport long distances",0
	db "teleport to its prey",0,"cause light wounds",0
	db "cause serious wounds",0,"paralyse its prey",0,"induce blindness",0
	db "confuse",0,"terrify",0,"summon a monster",0,"summon the undead",0
	db "slow its prey",0,"drain mana",0,"summon demonkind",0
	db "summon dragonkind",0,"lightning",0,"poison gases",0,"acid",0
	db "frost",0,"fire",0,"cast fire bolts",0,"cast frost bolts",0
	db "cast acid bolts",0,"cast magic missiles",0,"cause critical wounds",0
	db "cast fire balls",0,"cast frost balls",0,"cast mana bolts",0
	db "chaos",0,"shards",0,"sound",0,"confusion",0,"disenchantment",0
	db "nether",0,"cast lightning bolts",0,"cast lightning balls",0
	db "cast acid balls",0,"create traps",0,"wound its prey",0
	db "cast mind blasting",0,"teleport away its prey",0,"heal itself",0
	db "haste itself",0,"fire missiles",0,"cast plasma bolts",0
	db "mass summoning",0,"cast nether bolts",0,"cast ice bolts",0
	db "cast darkness",0,"cause amnesia",0,"mind searing",0
	db "cast stinking clouds",0,"teleport its preys level",0
	db "cast water bolts",0,"cast whirlpools",0,"cast nether balls",0
	db "summon an angel",0,"summon spiders",0,"summon hounds",0,"nexus",0
	db "elemental force",0,"inertia",0,"light",0,"time",0,"gravity",0
	db "darkness",0,"plasma",0,"fires arrows",0,"summon Ringwraiths",0
	db "cast darkness storms",0,"cast mana storms",0,"summon reptiles",0
	db "summon ants",0,"summon unique creatures",0
	db "summon greater undead",0,"summon ancient dragons",0
	db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0	; (81-95: none)
	db "move invisibly",0,"open doors",0,"pass through walls",0
	db "kill weaker creatures",0,"pick up objects",0,"breed explosively",0
	db "frost",0,"fire",0,"lightning",0,"poison",0,"acid",0
howmuch_words:
	db " not at all",0," a bit",0,0," quite",0," very",0," most",0
	db " highly",0," extremely",0
method_words:
	db "make an undefined advance",0,"hit",0,"bite",0,"claw",0,"sting",0
	db "touch",0,"kick",0,"gaze",0,"breathe",0,"spit",0,"wail",0
	db "embrace",0,"crawl on you",0,"release spores",0,"beg",0,"slime you",0
	db "crush",0,"trample",0,"drool",0,"insult",0,"butt",0,"charge",0
	db "engulf",0,"moan",0
type_words:
	db "do something undefined",0,"attack",0,"weaken",0,"confuse",0
	db "terrify",0,"shoot flames",0,"shoot acid",0,"freeze",0
	db "shoot lightning",0,"corrode",0,"blind",0,"paralyse",0
	db "steal money",0,"steal things",0,"poison",0,"reduce dexterity",0
	db "reduce constitution",0,"drain intelligence",0,"drain wisdom",0
	db "lower experience",0,"call for help",0,"disenchant",0
	db "eat your food",0,"absorb light",0,"absorb charges",0
	db "reduce all stats",0

rt_the:				db "The ",0
rt_colon_nl:		db ":",10,0
rt_slain_ancestors:	db "It has slain ",0
rt_of_ancestors:	db " of your ancestors",0
rt_avenged:			db ", but you have avenged ",0
rt_him:				db "him",0,"them",0
rt_avenged_end:		db "! ",0
rt_who:				db ", who ",0
rt_remains:			db "remains",0,"remain",0
rt_unavenged:		db " unavenged. ",0
rt_slain_foe:		db "You have slain this foe. ",0
rt_of_ancestors_c:	db " of your ancestors ",0
rt_has:				db "has",0,"have",0
rt_been_killed:		db " been killed by this creature, and ",0
rt_never_defeated:	db "it is not ever known to have been defeated. ",0
rt_at_least:		db "at least ",0
rt_beasts:			db " of the beasts ",0
rt_exterminated:	db " been exterminated. ",0
rt_no_battles:		db "No battles to the death are recalled. ",0
rt_at_least_these:	db "At least ",0
rt_these_creatures:	db " of these creatures ",0
rt_by_ancestors:	db " been killed by your ancestors. ",0
rt_trouble:			db " You feel you know it, and it knows you. This can only mean trouble.",0
rt_town:			db " It lives in the town",0
rt_depths:			db " It is normally found at depths of ",0
rt_feet:			db " feet",0
rt_comma_and:		db ", and",0
rt_comma_and_:		db ", and ",0
rt_it:				db " It",0
rt_moves:			db " moves",0
rt_erratically:		db " erratically",0
rt_normal_speed:	db " at normal speed",0
rt_and:				db ", and",0
rt_very:			db " very",0
rt_unbelievably:	db " unbelievably",0
rt_quickly:			db " quickly",0
rt_incredibly:		db " incredibly",0
rt_slowly:			db " slowly",0
rt_but:				db ", but",0
rt_deign:			db " does not deign to chase intruders",0
rt_stop:			db ".",0
rt_kill_of:			db " A kill of this",0
rt_natural:			db " natural",0
rt_evil:			db " evil",0
rt_undead:			db " undead",0
rt_giant:			db " giant",0
rt_orc:				db " orc",0
rt_dragon:			db " dragon",0
rt_demon:			db " demon",0
rt_troll:			db " troll",0
rt_creature:		db " creature",0
rt_worth:			db " is worth ",0
rt_point:			db " point",0
rt_for_a:			db " for a",0
rt_th:				db "th",0
rt_st:				db "st",0
rt_nd:				db "nd",0
rt_rd:				db "rd",0
rt_level_char:		db " level character.",0
rt_groups:			db " It usually appears in groups.",0
rt_breathe:			db " It can breathe ",0
rt_also:			db ", and is also",0
rt_it_is:			db " It is",0
rt_magical:			db " magical, casting spells",0
rt_intelligently:	db " intelligently",0
rt_spells_which:	db " which ",0
rt_time_in:			db "; 1 time in ",0
rt_comma_sep:		db ", ",0
rt_and_sep:			db " and ",0
rt_or_sep:			db " or ",0
rt_armour:			db " It has an armor rating of ",0
rt_life:			db " and a",0
rt_maximized:		db " maximized",0
rt_life_rating:		db " life rating of ",0
rt_bore:			db " It can bore through rock",0
rt_it_can:			db " It can ",0
rt_susceptible:		db " It is susceptible to ",0
rt_light:			db "bright light",0
rt_rock:			db "rock remover",0
rt_resists:			db " It resists ",0
rt_cold:			db " It is cold blooded",0
rt_and_charm:		db ", and",0
rt_it_charm:		db " It",0
rt_charm:			db " cannot be charmed or slept",0
rt_it_:				db " It ",0
rt_ignore:			db "prefers to ignore",0
rt_very_little:		db "pays very little attention to",0
rt_little:			db "pays little attention to",0
rt_overlook:		db "tends to overlook",0
rt_quite_while:		db "takes quite a while to see",0
rt_a_while:			db "takes a while to see",0
rt_fairly:			db "is fairly observant of",0
rt_observant:		db "is observant of",0
rt_very_observant:	db "is very observant of",0
rt_vigilant:		db "is vigilant for",0
rt_ever_vigilant:	db "is ever vigilant for",0
rt_intruders:		db " intruders, which it may notice from ",0
rt_feet_stop:		db " feet.",0
rt_may:				db " It may",0
rt_sometimes:		db " sometimes",0
rt_often:			db " often",0
rt_carry:			db " carry",0
rt_one_or_two:		db " one or two",0
rt_up_to:			db " up to ",0
rt_an_object:		db " an object",0
rt_objects:			db " objects",0
rt_or_treasure:		db " or treasure",0
rt_treasure:		db " treasure.",0
rt_treasures:		db " treasures.",0
rt_to:				db " to ",0
rt_by:				db " by ",0
rt_with_damage:		db " with damage ",0
rt_no_physical:		db " It has no physical attacks.",0
rt_nothing_known:	db " Nothing is known about its attack.",0
rt_wins:			db " Killing one of these wins the game!",0
rt_nl:				db 10,0
rt_pause:			db "--pause--",0

; ---------------------------------------------------------------- workspace

rc_race:		dw 0
rc_rec:			dw 0
rc_info:		ds RINFO_SIZE
rc_mask:		ds 4
ln_val:			db 0
ln_what:		db 0
rc_mem:			ds MR_SIZE
rc_racerec:		ds RACE_SIZE
rc_spell:		ds 12
rf_race:		dw 0
rf_spells:		ds 12
rf_cdef:		ds 4
rf_cmove:		ds 4
rf_breaths:		ds 81
rf_magic:		ds 81
rf_sep:			dw 0
rf_pre:			db 0
rf_lp:			dw 0
rf_mp:			dw 0
rf_k:			db 0
rf_i:			db 0
rf_j:			db 0
rf_seen:		db 0
rf_att:			dw 0
rf_t:			ds 5
rf_len:			db 0
rf_row:			db 0
rf_buf:			ds 81
rf_np:			dw 0
rf_numbuf:		ds 10
