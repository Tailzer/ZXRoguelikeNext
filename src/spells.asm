/* spells.asm - magic: learning, mana and casting  [overlay: PAGE_SPELL]
	References: MAGIC.C cast, MISC2.C calc_spells/gain_spells/calc_mana/
	spell_chance/print_spells/stat_adj, DUNGEON.C regenmana, SPELLS.C
	door_creation/stair_creation/detect_enchantment.
	The spells (data/spells.asm) are on SPELL_PAGE: each class's level,
	mana, failure and experience for its 63, and the names. What the player
	knows (s_learned and the rest) and the mana are in high RAM.
	Bolts, balls and the like are done by the device overlay (do_effect);
	scroll and potion effects are borrowed from their overlays.
	Mages, rogues and rangers cast from magic books here; priests and
	paladins' prayers come in 9d-2.
 */

SP_MAGE				equ 1				; p_spell: the class's spell type
SP_PRIEST			equ 2
SPELL_REC			equ 5				; level, mana, fail, exp (word)
SPELLS_PER_CLASS	equ 63

; ---------------------------------------------------------------- upkeep

/* update_spells - after the bonuses change (update_stuff): what may be
	learnt now, and the mana (calc_spells, calc_mana) */
update_spells:
	ld a,(p_spell)
	or a
	ret z
	call calc_spells
	jp calc_mana

/* sp_stat_adj - -> A = stat_adj() of the class's spell stat (INT, WIS) */
sp_stat_adj:
	ld a,(p_spell)
	cp SP_MAGE
	ld a,(p_stat_use+A_INT)
	jr z,stat_adj
	ld a,(p_stat_use+A_WIS)
/* stat_adj - A = a stat as used -> A = 0-20 (MISC2.C) */
stat_adj:
	ld hl,stat_adj_table
	jp threshold
; (limit, result): the result for a stat below the limit
stat_adj_table:
	db 8,0, 15,1, 18,2, 68,3, 88,4, 108,5, 118,6, 119,7, 129,8, 139,9
	db 149,10, 159,11, 169,12, 179,13, 189,14, 199,15, 219,16, 229,18, 255,20

/* spell_rec - A = spell -> HL = the class's record for it, SPELL_PAGE
	paged in. Clobbers DE */
spell_rec:
	push af
	nextreg NR_MMU1,SPELL_PAGE
	ld a,(p_class)
	dec a
	ld e,a
	ld d,SPELLS_PER_CLASS
	mul d,e
	pop af
	add de,a
	ld h,d								; x 5
	ld l,e
	add hl,hl
	add hl,hl
	add hl,de
	ld de,magic_spell
	add hl,de
	ret

/* spell_bit - A = spell, HL = a set (s_learned, s_worked, s_forgotten:
	64 bits, spells 32-62 in the second dword) -> HL = its byte, A = its
	bit, C = the same. Clobbers B */
spell_bit:
	ld b,a
	srl a
	srl a
	srl a
	add hl,a
	ld a,b
	and 7
	ld b,a
	ld a,1
	jr z,.got
.shift:
	add a,a
	djnz .shift
.got:
	ld c,a
	ret

/* is_set - A = spell, HL = set -> NZ if it's in it. Preserves A */
is_set:
	push af
	push bc
	call spell_bit
	and (hl)
	pop bc
	pop hl								; (the spell)
	ld a,h
	ret

sp_set:									; A = spell, HL = set: add it
	push bc
	call spell_bit
	or (hl)
	ld (hl),a
	pop bc
	ret
sp_clear:								; ...take it away
	push bc
	call spell_bit
	cpl
	and (hl)
	ld (hl),a
	pop bc
	ret

/* sp_levels - -> A = level - first spell level + 1 (0 if below) */
sp_levels:
	ld a,(p_first_spell)
	ld b,a
	ld a,(p_lev)
	sub b
	jr c,.none
	inc a
	ret
.none:
	xor a
	ret

/* calc_spells - forget spells now above the level (or beyond what the
	stat allows), remember forgotten ones, and work out how many more may
	be learnt (s_new): "You can learn some new spells now." */
calc_spells:
	xor a								; forget those above the level
.over:
	ld (cs_i),a
	ld hl,s_learned
	call is_set
	jr z,.next_over
	call spell_rec
	ld a,(p_lev)
	cp (hl)
	jr nc,.next_over
	ld a,(cs_i)
	call forget
.next_over:
	ld a,(cs_i)
	inc a
	cp SPELLS_PER_CLASS
	jr c,.over
	call sp_levels						; spells allowed for the stat:
	ld (cs_levels),a					; 0, levels, 3/2, 2x or 5/2 of them
	call sp_stat_adj
	ld b,a
	ld a,(cs_levels)
	ld l,a
	ld h,0
	ld d,h
	ld e,l
	ld a,b
	or a
	jr nz,$+5
	ld hl,0
	cp 4
	jr c,.count							; 0: none, 1-3: levels
	add hl,hl							; 2x
	cp 6
	jr z,.count
	jr c,.half							; 4-5: (2x + 1x) / 2
	add hl,hl							; else (4x + 1x) / 2
.half:
	add hl,de
	srl h
	rr l
.count:
	ld (cs_allowed),hl
	ld hl,s_learned						; how many are known
	ld bc,8*256
.byte:
	ld a,(hl)
.bits:
	or a
	jr z,.next_byte
	ld d,a
	dec a
	and d								; (the lowest set bit off)
	inc c
	jr .bits
.next_byte:
	inc hl
	djnz .byte
	ld b,0								; new = allowed - known
	ld hl,(cs_allowed)
	or a
	sbc hl,bc
	ld (cs_new),hl
	bit 7,h
	jp nz,.too_many
	ld a,h
	or l
	jp z,.done
	xor a								; remember forgotten ones, in the
.remember:								; order they were learnt
	ld (cs_i),a
	ld hl,s_order
	add hl,a
	ld a,(hl)
	cp 99
	jr z,.next_remember
	ld (cs_j),a
	ld hl,s_forgotten
	call is_set
	jr z,.next_remember
	call spell_rec
	ld a,(p_lev)
	cp (hl)
	jr c,.too_high
	ld a,(cs_j)
	ld hl,s_forgotten
	call sp_clear
	ld a,(cs_j)
	ld hl,s_learned
	call sp_set
	ld hl,(cs_new)
	dec hl
	ld (cs_new),hl
	ld hl,txt_remembered
	ld a,(cs_j)
	call spell_msg
	jr .next_remember
.too_high:
	ld hl,(cs_allowed)
	inc hl
	ld (cs_allowed),hl
.next_remember:
	ld hl,(cs_new)
	ld a,h
	or l
	jp z,.done
	ld a,(cs_i)
	inc a
	cp 64
	jr nc,.learnable
	ld hl,(cs_allowed)
	ld d,0
	ld e,a
	or a
	sbc hl,de
	ld a,e
	jr z,.learnable
	jr nc,.remember
.learnable:								; no more than could be learnt
	ld bc,0
	xor a
.can:
	ld (cs_i),a
	and 31
	cp 31
	jr z,.next_can						; (31 and 63: no spell)
	ld a,(cs_i)
	ld hl,s_learned
	call is_set
	jr nz,.next_can
	push bc
	call spell_rec
	pop bc
	ld a,(p_lev)
	cp (hl)
	jr c,.next_can
	inc c
.next_can:
	ld a,(cs_i)
	inc a
	cp SPELLS_PER_CLASS
	jr c,.can
	ld hl,(cs_new)
	or a
	sbc hl,bc
	jr c,.done
	ld (cs_new),bc
	jr .done
.too_many:								; forget, latest learnt first
	ld a,63
.unlearn:
	ld (cs_i),a
	ld hl,s_order
	add hl,a
	ld a,(hl)
	cp 99
	jr z,.next_unlearn
	ld hl,s_learned
	call is_set
	jr z,.next_unlearn
	call forget
	ld hl,(cs_new)
	inc hl
	ld (cs_new),hl
	ld a,h
	or l
	jr z,.forgot
.next_unlearn:
	ld a,(cs_i)
	sub 1
	jr nc,.unlearn
.forgot:
	ld hl,0
	ld (cs_new),hl
.done:
	ld a,(cs_new)
	ld hl,s_new
	cp (hl)
	ret z
	ld b,(hl)
	ld (hl),a
	or a
	ret z
	ld a,b
	or a
	ret nz
	ld hl,msg_can_learn
	ld a,(p_spell)
	cp SP_MAGE
	jp z,msg_print
	ld hl,msg_can_learn_p
	jp msg_print

/* forget - A = spell: no longer known, but forgotten */
forget:
	push af
	ld hl,s_learned
	call sp_clear
	pop af
	push af
	ld hl,s_forgotten
	call sp_set
	pop af
	ld hl,txt_forgotten
/* spell_msg - HL = "You have forgotten the ", A = spell: + "spell of X." */
spell_msg:
	push af
	push hl
	call msg_begin
	pop hl
	call msg_add
	ld a,(p_spell)
	cp SP_MAGE
	ld hl,txt_spell_of
	jr z,$+5
	ld hl,txt_prayer_of
	call msg_add
	pop af
	call spell_name
	call msg_add
	ld hl,txt_full_stop
	call msg_add
	jp msg_end

/* spell_name - A = spell -> HL = its name, SPELL_PAGE paged in */
spell_name:
	ld b,a
	ld a,(p_spell)
	cp SP_MAGE
	ld a,b
	jr z,$+4
	add a,SPELLS_PER_CLASS
	nextreg NR_MMU1,SPELL_PAGE
	add a,a
	ld hl,spell_names
	jr nc,$+3
	inc h
	add hl,a
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	ret

/* calc_mana - maximum mana from the level and the spell stat, once any
	spell is known; gloves cost mages, rogues and rangers a quarter, and
	armour over 35 a point each. Current mana keeps its proportion */
calc_mana:
	ld hl,(s_learned)
	ld de,(s_learned+2)
	ld a,h
	or l
	or d
	or e
	ld hl,(s_learned2)
	or h
	or l
	ld hl,(s_learned2+2)
	or h
	or l
	jr nz,.knows
	ld hl,0								; no spells: no mana
	ld (p_mana),hl
	ld (p_cmana),hl
	ret
.knows:
	call sp_stat_adj					; half-levels per level by stat_adj
	cp 15
	jr c,$+4
	ld a,15
	ld hl,mana_halves
	add hl,a
	ld e,(hl)
	call sp_levels
	ld d,a
	mul d,e
	srl d
	rr e								; DE = new mana
	ld a,d
	or e
	jr z,.gloves
	inc de								; (first level casters have 2)
.gloves:
	ld a,(EQUIP+EQ_GLOVES*ITEM_SIZE+I_KIND_HI)
	cp ITEM_EMPTY
	jr z,.armour
	ld a,(p_class)						; mages, rogues, rangers: 3/4
	cp 2
	jr z,.armour
	cp 5
	jr z,.armour
	ld h,d
	ld l,e
	add hl,hl
	add hl,de
	srl h
	rr l
	srl h
	rr l
	ex de,hl
.armour:
	ld a,(p_ac)							; heavy armour: - (ac - 35)
	sub 36
	jr c,.set
	inc a
	ex de,hl
	ld e,a
	ld d,0
	or a
	sbc hl,de
	jr nc,$+5
	ld hl,0
	ex de,hl
.set:
	ld hl,(p_mana)
	or a
	sbc hl,de
	ret z								; (no change)
	ld hl,(p_mana)
	ld a,h
	or l
	jr nz,.scale
	ld (p_mana),de						; first mana: all of it
	ld (p_cmana),de
	ld hl,0
	ld (p_cmana_frac),hl
	ret
.scale:									; cmana = cmana * new / old
	push de
	ld hl,(p_cmana)
	ld (ch_val),hl
	ld hl,0
	ld (ch_val+2),hl
	ld b,d
	ld c,e
	call mul32_16
	ld de,(p_mana)
	call div32_16
	ld hl,(ch_val)
	ld (p_cmana),hl
	pop de
	ld (p_mana),de
	ld hl,0
	ld (p_cmana_frac),hl
	ret

; mana per level x 2, by stat_adj 0-15 (calc_mana)
mana_halves:	db 0,2,2,3,4,5,6,8,9,10,11,12,13,14,15,16

/* regenmana - A = this turn's regeneration (hunger_tick): mana comes back
	as hit points do (DUNGEON.C regenmana) */
regenmana:
	ld hl,(p_cmana)
	ld de,(p_mana)
	or a
	sbc hl,de
	ret nc
	ld l,a								; HL = amount, half again with
	ld h,0								; regeneration
	ld a,(p_eflags+1)
	bit EF1_REGEN,a
	jr z,.amount
	ld d,h
	ld e,l
	srl d
	rr e
	add hl,de
.amount:
	ld b,h								; ch_val = mana * amount + 524
	ld c,l
	ld hl,(p_mana)
	ld (ch_val),hl
	ld hl,0
	ld (ch_val+2),hl
	call mul32_16
	ld hl,(ch_val)
	ld de,524							; PLAYER_REGEN_MNBASE
	add hl,de
	ld de,(ch_val+2)
	jr nc,$+3
	inc de
	ld bc,(p_cmana_frac)				; the fraction, then the whole
	add hl,bc
	ld (p_cmana_frac),hl
	jr nc,$+3
	inc de
	ld hl,(p_cmana)
	add hl,de
	ld de,(p_mana)
	push hl
	or a
	sbc hl,de
	pop hl
	jr c,.store
	ex de,hl							; full
	ld bc,0
	ld (p_cmana_frac),bc
.store:
	ld (p_cmana),hl
	ret

/* spell_chance - A = spell -> A = its failure chance in % (spell_chance
	in MISC2.C) */
spell_chance:
	call spell_rec
	ld a,(hl)							; level
	ld b,a
	inc hl
	ld a,(hl)							; mana
	ld (sc_mana),a
	inc hl
	ld e,(hl)							; fail
	ld d,0
	ld a,(p_lev)						; fail - 3 * (lev - level)
	sub b
	ld l,a
	ld h,0
	jr nc,$+3
	dec h
	ld b,h
	ld c,l
	add hl,hl
	add hl,bc
	ex de,hl
	or a
	sbc hl,de
	push hl
	call sp_stat_adj					; - 3 * (stat_adj - 1)
	ld (sc_adj),a
	ld e,a
	ld d,0
	dec de
	ld h,d
	ld l,e
	add hl,hl
	add hl,de
	ex de,hl
	pop hl
	or a
	sbc hl,de
	push hl
	ld a,(sc_mana)						; short of mana: + 5 per point
	ld l,a
	ld h,0
	ld de,(p_cmana)
	or a
	sbc hl,de
	pop de
	jr c,.clamp
	jr z,.clamp
	ld b,h
	ld c,l
	add hl,hl
	add hl,hl
	add hl,bc
	add hl,de
	ex de,hl
.clamp:									; DE = chance
	ld a,(sc_adj)						; the least it can be
	cp 17
	jr c,$+4
	ld a,17
	ld hl,min_fail
	add hl,a
	ld b,(hl)
	ld a,(p_class)						; (only mages and priests below 5)
	cp 3
	jr c,.min
	ld a,b
	cp 5
	jr nc,.min
	ld b,5
.min:
	bit 7,d
	jr nz,.lowest
	ld a,d
	or a
	jr nz,.highest
	ld a,e
	cp 96
	jr nc,.highest
	cp b
	ret nc
.lowest:
	ld a,b
	ret
.highest:
	ld a,95
	ret

; the lowest failure chance by stat_adj 0-17
min_fail:	db 50,12,8,5,4,4,3,3,2,2,2,2,2,1,1,1,1,0

; ---------------------------------------------------------------- lists

/* book_spells - IX = a book -> sp_list (and sp_count) of the class's
	spells in it (level below 99), lowest first; sp_first = the lowest.
	With sp_known set, only those known and not above the level */
book_spells:
	call item_kind_addr
	ld l,(iy+K_FLAGS)					; its spells: flags 0-30,
	ld h,(iy+K_FLAGS+1)					; flags2 32-62
	ld (sp_bits),hl
	ld l,(iy+K_FLAGS+2)
	ld h,(iy+K_FLAGS+3)
	ld (sp_bits+2),hl
	ld l,(iy+K_FLAGS2)
	ld h,(iy+K_FLAGS2+1)
	ld (sp_bits+4),hl
	ld l,(iy+K_FLAGS2+2)
	ld h,(iy+K_FLAGS2+3)
	ld (sp_bits+6),hl
	xor a								; the first spell in the book (the
.first:									; letters count from it)
	ld (sp_first),a
	ld hl,sp_bits
	call is_set
	jr nz,.listing
	inc a
	cp 64
	jr c,.first
.listing:
	xor a
	ld (sp_count),a
.each:
	ld (cs_i),a
	ld hl,sp_bits
	call is_set
	jr z,.next
	call spell_rec
	ld a,(hl)
	cp 99
	jr z,.next
	ld a,(sp_known)
	or a
	jr z,.add
	ld a,(p_lev)
	cp (hl)
	jr c,.next
	ld a,(cs_i)
	ld hl,s_learned
	call is_set
	jr z,.next
.add:
	ld hl,sp_count
	ld a,(hl)
	inc (hl)
	ld hl,sp_list
	add hl,a
	ld a,(cs_i)
	ld (hl),a
.next:
	ld a,(cs_i)
	inc a
	cp SPELLS_PER_CLASS
	jr c,.each
	ld a,(sp_count)
	or a
	ret

/* print_spells - the sp_count spells of sp_list: "a) Magic Missile ... 1
	1 22%", lettered from sp_first (or from a with sp_letters 0), with
	" unknown", " forgotten", " untried" if sp_notes is set */
print_spells:
	call msg_begin
	ld hl,txt_spells_head
	call msg_add
	ld a,0
	call list_line
	xor a
.each:
	ld (ps_i),a
	ld hl,sp_count
	cp (hl)
	ret nc
	cp LIST_ROWS-1
	ret nc
	ld hl,sp_list
	add hl,a
	ld a,(hl)
	ld (ps_spell),a
	call msg_begin
	ld a,(sp_letters)
	or a
	ld a,(ps_i)
	jr z,.letter
	ld a,(sp_first)
	ld b,a
	ld a,(ps_spell)
	sub b
.letter:
	add a,'a'
	call list_label
	ld a,(ps_spell)
	call spell_name
	call msg_add
	ld a,33
	call pad_to
	ld a,(ps_spell)
	call spell_rec
	ld a,(hl)							; level, mana, fail% (%2d %4d %3d%%)
	push hl
	ld b,2
	call add_padded
	pop hl
	inc hl
	ld a,(hl)
	ld b,5
	call add_padded
	ld a,(ps_spell)
	call spell_chance
	ld b,4
	call add_padded
	ld a,'%'
	call put_char
	ld a,(sp_notes)
	or a
	jr z,.show
	ld a,(ps_spell)
	ld hl,s_forgotten
	call is_set
	ld hl,txt_forgotten_n
	jr nz,.note
	ld hl,s_learned
	call is_set
	ld hl,txt_unknown_n
	jr z,.note
	ld hl,s_worked
	call is_set
	ld hl,txt_untried_n
	jr z,.note
	jr .show
.note:
	call msg_add
.show:
	ld a,(ps_i)
	inc a
	call list_line
	ld a,(ps_i)
	inc a
	jp .each

/* pad_to - A = column: spaces to it */
pad_to:
	ld b,a
.space:
	ld hl,(msg_ptr)
	ld de,msg_buf
	or a
	sbc hl,de
	ld a,l
	cp b
	ret nc
	ld a,' '
	call put_char
	jr .space
put_char:
	ld hl,(msg_ptr)
	ld (hl),a
	inc hl
	ld (msg_ptr),hl
	ret
add_padded:								; A, right-aligned in B columns
	ld c,1
	cp 10
	jr c,.digits
	inc c
	cp 100
	jr c,.digits
	inc c
.digits:
	push af
	ld a,b
	sub c
	jr z,.number
	jr c,.number
	ld b,a
.space:
	ld a,' '
	push bc
	call put_char
	pop bc
	djnz .space
.number:
	pop af
	jp msg_add_u8

LIST_ROWS			equ 22

; ---------------------------------------------------------------- commands

/* sp_ready - can the player read a book now? -> carry if so (blind and
	confused can't) */
sp_ready:
	ld hl,(p_blind)
	ld a,h
	or l
	ld hl,t_cant_see
	jr nz,.say
	call no_light
	ld hl,msg_no_light
	jr z,.no
	ld hl,(p_confused)
	ld a,h
	or l
	ld hl,msg_too_confused_sp
	jr nz,.no
	scf
	ret
.say:
	call sp_text
.no:
	call msg_print
	or a
	ret

/* sp_text - HL = (mage text, priest text) -> HL = the class's */
sp_text:
	ld a,(p_spell)
	cp SP_MAGE
	jr z,$+4
	inc hl
	inc hl
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	ret
sp_say:									; ...and print it
	call sp_text
	jp msg_print

/* sp_book_class - -> A = IC_MAGIC_BOOK or IC_PRAYER_BOOK */
sp_book_class:
	ld a,(p_spell)
	cp SP_MAGE
	ld a,IC_MAGIC_BOOK
	ret z
	ld a,IC_PRAYER_BOOK
	ret

/* sp_book - "Use which spell-book?" -> carry, IX = the book; or a message */
sp_book:
	call sp_book_class
	call pack_has_class
	ld hl,t_no_books
	jr nc,.none
	ld hl,t_which_book
	call sp_text
	push hl
	call sp_book_class
	pop hl
	jp choose_pack
.none:
	call sp_say
	or a
	ret

/* sp_pray - 'p': recite a prayer (pray in PRAYER.C) */
sp_pray:
	call sp_ready
	ret nc
	ld a,(p_spell)
	cp SP_PRIEST
	ld hl,msg_pray_hard
	jp nz,msg_print
	jr sp_use

/* sp_cast - 'm': cast a spell (cast in MAGIC.C) */
sp_cast:
	call sp_ready
	ret nc
	ld a,(p_spell)
	cp SP_MAGE
	ld hl,msg_cant_cast
	jp nz,msg_print
sp_use:
	call sp_book
	ret nc
	ld a,1
	ld (sp_known),a
	ld (sp_letters),a
	call book_spells
	ld hl,t_dont_know
	jp z,sp_say
	call print_spells
	ld hl,t_cast_which
	call sp_text
	call prompt
	call read_ascii
	push af
	call msg_clear
	pop af
	sub 'a'
	ret c
	ld hl,sp_first
	add a,(hl)
	ld (sp_spell),a
	ld hl,sp_list						; one of those listed?
	ld a,(sp_count)
	ld b,a
	ld a,(sp_spell)
.known:
	cp (hl)
	jr z,.cast
	inc hl
	djnz .known
	ld hl,t_dont_know_that
	jp sp_say
.cast:
	ld a,(sp_spell)						; short of mana: are you sure?
	call spell_rec
	inc hl
	ld e,(hl)
	ld d,0
	ld hl,(p_cmana)
	or a
	sbc hl,de
	jr nc,.sure
	ld hl,txt_limited
	call prompt
	call read_ascii
	push af
	call msg_clear
	pop af
	cp 'y'
	ret nz
.sure:
	ld a,1
	ld (turn_taken),a
	ld a,(sp_spell)
	call spell_chance
	ld b,a
	ld hl,(p_stun)						; stunned: harder
	bit 7,h
	jr nz,.roll
	ld a,h
	or l
	jr z,.roll
	ld de,51
	or a
	sbc hl,de
	ld a,15
	jr c,$+4
	ld a,25
	add a,b
	ld b,a
.roll:
	push bc
	ld a,100
	call randint
	pop bc
	cp b
	jr z,.failed
	jr c,.failed
	ld a,(p_spell)						; the spell itself
	cp SP_MAGE
	ld hl,mage_spells-2
	jr z,$+5
	ld hl,prayers-2
	ld a,(sp_spell)
	inc a
	call sp_jump
	ld a,(sp_spell)						; first time: experience
	ld hl,s_worked
	call is_set
	jr nz,.mana
	ld hl,s_worked
	call sp_set
	ld a,(sp_spell)
	call spell_rec
	inc hl
	inc hl
	inc hl
	ld e,(hl)							; + exp x 4
	inc hl
	ld d,(hl)
	ex de,hl
	add hl,hl
	add hl,hl
	call add_exp
	call check_level_up
	jr .mana
.failed:
	ld hl,t_failed
	call sp_say
.mana:									; pay for it, or faint
	ld a,(sp_spell)
	call spell_rec
	inc hl
	ld e,(hl)
	ld d,0
	ld hl,(p_cmana)
	or a
	sbc hl,de
	jr c,.faint
	ld (p_cmana),hl
	ret
.faint:
	ld a,(p_cmana)
	ld b,a
	ld a,e
	sub b
	push af
	ld hl,t_faint
	call sp_say
	pop af
	ld e,a								; paralysed 1d(5 x shortfall)
	ld d,5
	mul d,e
	ld a,d
	or a
	ld a,e
	jr z,$+4
	ld a,255
	call randint
	ld hl,p_paralysed
	add a,(hl)
	jr nc,$+4
	ld a,255
	ld (hl),a
	ld hl,0
	ld (p_cmana),hl
	ld (p_cmana_frac),hl
	ld a,3								; 1 in 3: CON down
	call randint
	dec a
	ret nz
	ld hl,msg_damaged_health
	call msg_print
	ld a,A_CON
	OVCALL PAGE_MAGIC, dec_stat, PAGE_SPELL
	ret

sp_jump:								; A = 1-based, HL = table - 2
	add a,a
	add hl,a
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	jp (hl)

/* sp_browse - 'P': read a book's spells (any class that casts from it) */
sp_browse:
	call sp_ready
	ret nc
	ld a,(p_spell)
	or a
	ld hl,msg_cant_read
	jp z,msg_print
	call sp_book
	ret nc
	xor a
	ld (sp_known),a
	ld a,1
	ld (sp_letters),a
	ld (sp_notes),a
	call book_spells
	ld hl,msg_nothing_in_book
	jp z,msg_print
	call print_spells
	xor a
	ld (sp_notes),a
	ld hl,txt_any_key_sp
	call prompt
	call read_ascii
	jp msg_clear

/* sp_study - 'G': learn new spells from the books carried (gain_spells) */
sp_study:
	call sp_ready
	ret nc
	ld a,(p_spell)
	or a
	ld hl,msg_cant_cast
	jp z,msg_print
	ld a,(s_new)
	or a
	ld hl,t_cant_learn
	jp z,sp_say
	ld hl,sp_bits						; every spell in the books carried
	ld b,8
.clear:
	ld (hl),0
	inc hl
	djnz .clear
	ld ix,PACK
	ld b,PACK_MAX
.book:
	push bc
	ld a,(ix+I_KIND_HI)
	cp ITEM_EMPTY
	jr z,.next_book
	call item_kind_addr
	call sp_book_class
	cp (iy+K_CLASS)
	jr nz,.next_book
	ld hl,sp_bits
	ld de,K_FLAGS
	call .or4
	ld de,K_FLAGS2
	call .or4
.next_book:
	ld de,ITEM_SIZE
	add ix,de
	pop bc
	djnz .book
	xor a								; those not known, not above level
	ld (sp_count),a
.each:
	ld (cs_i),a
	ld hl,sp_bits
	call is_set
	jr z,.next
	ld hl,s_learned
	call is_set
	jr nz,.next
	call spell_rec
	ld a,(p_lev)
	cp (hl)
	jr c,.next
	ld hl,sp_count
	ld a,(hl)
	inc (hl)
	ld hl,sp_list
	add hl,a
	ld a,(cs_i)
	ld (hl),a
.next:
	ld a,(cs_i)
	inc a
	cp SPELLS_PER_CLASS
	jr c,.each
	xor a
	ld (sp_short),a
	ld a,(sp_count)
	ld b,a
	ld a,(s_new)
	sub b
	jr c,.choose
	jr z,.choose
	ld (sp_short),a						; more allowed than the books have
	ld hl,msg_missing_book
	call msg_print
	ld a,b
	ld (s_new),a
.choose:
	ld a,(s_new)
	or a
	jp z,.finish
	ld a,(p_spell)						; priests: one at random
	cp SP_MAGE
	jr z,.pick
	ld a,(sp_count)
	call randint
	dec a
	push af
	ld hl,sp_list
	add hl,a
	ld a,(hl)
	ld hl,txt_learned_prayer
	call spell_msg
	pop af
	jr .learn
.pick:
	xor a
	ld (sp_letters),a
	ld (sp_notes),a
	call print_spells
	ld hl,txt_learn_which
	call prompt
	call read_ascii
	push af
	call msg_clear
	pop af
	sub 'a'
	jr c,.finish
	ld hl,sp_count
	cp (hl)
	jr nc,.finish
.learn:
	ld hl,sp_list						; learn it
	add hl,a
	ld (sp_at),hl
	ld a,(hl)
	ld hl,s_learned
	call sp_set
	ld hl,s_order						; in learning order
	ld b,64
.slot:
	ld a,(hl)
	cp 99
	jr z,.order
	inc hl
	djnz .slot
	jr .learnt
.order:
	ld de,(sp_at)
	ld a,(de)
	ld (hl),a
.learnt:
	ld hl,(sp_at)						; out of the list
	ld de,sp_list+SPELLS_PER_CLASS
.shift:
	inc hl
	ld a,(hl)
	dec hl
	ld (hl),a
	inc hl
	push hl
	or a
	sbc hl,de
	pop hl
	jr c,.shift
	ld hl,sp_count
	dec (hl)
	ld hl,s_new
	dec (hl)
	ld a,1
	ld (turn_taken),a
	jp .choose
.finish:
	ld a,(sp_short)
	ld hl,s_new
	add a,(hl)
	ld (hl),a
	ld hl,(p_mana)						; the first spell: mana at last
	ld a,h
	or l
	ret nz
	jp calc_mana
.or4:									; 4 bytes of the kind at DE into HL
	push iy
	pop bc
	ex de,hl
	add hl,bc
	ex de,hl
	ld b,4
.or:
	ld a,(de)
	or (hl)
	ld (hl),a
	inc de
	inc hl
	djnz .or
	ret

; ---------------------------------------------------------------- spells

/* the spells: MAGE spells 1-59 (MAGIC.C) */
mage_spells:
	dw ms_missile, ms_det_mons, ms_phase, ms_light, ms_treasure			; 1-5
	dw ms_clw, ms_objects, ms_doors, ms_stinking, ms_confuse			; 6-10
	dw ms_lightning, ms_td, ms_sleep1, ms_cure_poison, ms_teleport		; 11-15
	dw ms_spear, ms_frost_bolt, ms_mud, ms_food, ms_recharge1			; 16-20
	dw ms_sleep2, ms_poly, ms_identify, ms_sleep3, ms_fire_bolt			; 21-25
	dw ms_slow, ms_frost_ball, ms_recharge2, ms_tele_other, ms_haste		; 26-30
	dw ms_fire_ball, ms_destruction, ms_genocide, ms_doors_make, ms_stairs	; 31-35
	dw ms_tele_level, ms_quake, ms_recall, ms_acid_bolt, ms_cloud_kill		; 36-40
	dw ms_acid_ball, ms_ice_storm, ms_meteor, ms_hellfire, ms_det_evil		; 41-45
	dw ms_det_ench, ms_recharge3, ms_genocide, ms_mass_gen, ms_res_fire		; 46-50
	dw ms_res_cold, ms_res_acid, ms_res_poison, ms_resistance, ms_hero		; 51-55
	dw ms_shield, ms_shero, ms_speed, ms_invuln, no_spell				; 56-60
	dw no_spell, no_spell, no_spell
no_spell:
	ret

; bolts: element, dice (base + (lev - 5) / 4 for some), 8 sides
ms_missile:
	ld bc,2*256+6
	xor a
	jr sp_bolt
ms_lightning:
	ld b,3
	ld a,GF_LIGHTNING
	jr bolt_lev
ms_frost_bolt:
	ld b,5
	ld a,GF_FROST
	jr bolt_lev
ms_fire_bolt:
	ld b,8
	ld a,GF_FIRE
	jr bolt_lev
ms_acid_bolt:
	ld b,6
	ld a,GF_ACID
	ld hl,txt_acid_bolt_s
	call own_name
bolt_lev:								; B + (lev - 5) / 4 dice of 8
	push af
	ld a,(p_lev)
	sub 5
	jr nc,$+3
	xor a
	srl a
	srl a
	add a,b
	ld b,a
	ld c,8
	pop af
sp_bolt:								; A = element, B dice of C sides
	ld (sp_entry+3),a
	ld (sp_entry+4),bc
	ld a,AE_BOLT
	jp sp_effect

; balls: element, damage (base + lev or lev / 2)
ms_stinking:
	ld a,GF_POISON_GAS
	ld b,10
	jr ball_half
ms_cloud_kill:
	ld hl,txt_deadly_cloud
	call own_name
	ld a,GF_POISON_GAS
	ld b,40
ball_half:								; B + lev / 2
	push af
	ld a,(p_lev)
	srl a
	jr ball_add
ms_frost_ball:
	ld a,GF_FROST
	ld b,30
	jr ball_lev
ms_fire_ball:
	ld a,GF_FIRE
	ld b,55
	jr ball_lev
ms_acid_ball:
	ld hl,txt_acid_ball_s
	call own_name
	ld a,GF_ACID
	ld b,40
	jr ball_lev
ms_ice_storm:
	ld hl,txt_ice_storm
	call own_name
	ld a,GF_FROST
	ld b,70
	jr ball_lev
ms_meteor:
	ld hl,txt_meteor
	call own_name
	xor a
	ld b,65
ball_lev:								; B + lev
	push af
	ld a,(p_lev)
ball_add:
	add a,b
	ld l,a
	ld h,0
	jr nc,$+3
	inc h
	pop af
sp_ball:								; A = element, HL = damage
	ld (sp_entry+3),a
	ld (sp_entry+4),hl
	ld a,AE_BALL
	jr sp_effect
ms_hellfire:
	ld hl,txt_hellfire
	call own_name
	xor a
	ld hl,300
	jr sp_ball

; the device overlay's effects
ms_det_mons:
	ld a,AE_DETECT_MON
	jr sp_effect
ms_confuse:
	ld a,AE_CONF_MON
	jr sp_effect
ms_sleep1:
	ld a,AE_SLEEP_ONE
	jr sp_effect
ms_spear:
	ld a,AE_LIGHT_LINE
	jr sp_effect
ms_mud:
	ld a,AE_MUD
	jr sp_effect
ms_sleep2:
	ld a,AE_SLEEP_ADJ
	jr sp_effect
ms_poly:
	ld a,AE_POLY
	jr sp_effect
ms_sleep3:
	ld a,AE_SLEEP
	jr sp_effect
ms_slow:
	ld a,AE_SLOW_ONE
	jr sp_effect
ms_tele_other:
	ld a,AE_TELE_MON
	jr sp_effect
ms_quake:
	ld a,AE_EARTHQUAKE
	jr sp_effect
ms_det_evil:
	ld a,AE_DETECT_EVIL
/* sp_effect - A = AE_ effect (sp_entry's element and number set): the
	device overlay does it, named for the spell unless own_name named it */
sp_effect:
	ld (sp_entry+2),a
	ld a,(sp_named)
	or a
	jr nz,.named
	ld a,(sp_spell)
	call spell_name
	ld de,sp_name
	call copy_str
.named:
	xor a
	ld (sp_named),a
	OVCALL PAGE_DEVICE, do_effect, PAGE_SPELL
	ret
own_name:								; HL = the name the C gives it
	push af
	push bc
	ld de,sp_name
	call copy_str
	ld a,1
	ld (sp_named),a
	pop bc
	pop af
	ret
copy_str:
	ld a,(hl)
	ld (de),a
	inc hl
	inc de
	or a
	jr nz,copy_str
	ret

; the scrolls' effects
ms_phase:
	ld hl,10
	jr sp_teleport
ms_teleport:							; teleport(lev * 5)
	ld a,(p_lev)
	ld e,a
	ld d,5
	mul d,e
	ex de,hl
sp_teleport:
	OVCALL PAGE_SCROLL, teleport, PAGE_SPELL
	ret
ms_light:
	OVCALL PAGE_SCROLL, sc_light, PAGE_SPELL
	ret
ms_treasure:
	OVCALL PAGE_SCROLL, sc_treasure, PAGE_SPELL
	ret
ms_objects:
	OVCALL PAGE_SCROLL, sc_objects, PAGE_SPELL
	ret
ms_doors:								; (and traps)
	call pr_doors
pr_traps:
	OVCALL PAGE_TRAP, detect_traps, PAGE_SPELL
	ret
pr_doors:
	OVCALL PAGE_SCROLL, sc_doors, PAGE_SPELL
	ret
ms_td:
	OVCALL PAGE_SCROLL, sc_td_destroy, PAGE_SPELL
	ret
ms_food:
	OVCALL PAGE_SCROLL, sc_food, PAGE_SPELL
	ret
ms_identify:
	OVCALL PAGE_SCROLL, sc_identify_item, PAGE_SPELL
	ret
ms_destruction:
	OVCALL PAGE_SCROLL, sc_destruction, PAGE_SPELL
	ret
ms_genocide:
	OVCALL PAGE_SCROLL, sc_genocide, PAGE_SPELL
	ret
ms_mass_gen:
	OVCALL PAGE_SCROLL, sc_mass_genocide, PAGE_SPELL
	ret
ms_tele_level:
	OVCALL PAGE_SCROLL, sc_tele_level, PAGE_SPELL
	ret
ms_recharge1:
	ld a,5
	jr sp_recharge
ms_recharge2:
	ld a,40
	jr sp_recharge
ms_recharge3:
	ld a,100
sp_recharge:
	OVCALL PAGE_SCROLL, recharge_n, PAGE_SPELL
	ret

; the potions' effects, and timers
ms_clw:									; 4d4, and cuts 15 better
	ld bc,4*256+4
	call damroll
	OVCALL PAGE_MAGIC, hp_player, PAGE_SPELL
	ld hl,(p_cut)
	bit 7,h
	ret nz
	ld a,h
	or l
	ret z
	ld de,-15
	add hl,de
	jr c,$+5
	ld hl,0
	ld (p_cut),hl
	ld hl,msg_wounds_heal_s
	jp msg_print
ms_cure_poison:
	OVCALL PAGE_MAGIC, cure_poison, PAGE_SPELL
	ret
ms_haste:								; not fast: 1d20 + lev; else 1d5
	ld a,(p_lev)
	ld b,a
	ld c,20
	jr haste
ms_speed:								; 1d30 + 30 + lev; else 1d5
	ld a,(p_lev)
	add a,30
	ld b,a
	ld c,30
haste:
	ld hl,p_fast
	call get_w
	bit 7,d
	jr nz,.slow
	ld a,d
	or e
	jr z,.slow
	ld bc,5								; fast already
.slow:
	jp add_rand
ms_recall:
	ld hl,p_word_recall
	call get_w
	jr nz,.charged
	ld a,30
	call randint
	add a,25
	ld l,a
	ld h,0
	ld (p_word_recall),hl
.charged:
	ld hl,msg_air_charged_s
	jp msg_print
ms_res_fire:
	ld hl,p_resist_heat
	jr resist
ms_res_cold:
	ld hl,p_resist_cold
	jr resist
ms_res_acid:
	ld hl,p_resist_acid
	jr resist
ms_res_poison:
	ld hl,p_resist_poison
resist:									; 20 + 1d20
	ld bc,20*256+20
	jp add_rand
ms_resistance:
	ld hl,p_resist_heat
	call resist
	ld hl,p_resist_cold
	call resist
	ld hl,p_resist_light
	call resist
	ld hl,p_resist_poison
	call resist
	ld hl,p_resist_acid
	jr resist
ms_hero:
	ld hl,p_hero
	ld bc,25*256+25
	jp add_rand
ms_shero:
	ld hl,p_shero
	ld bc,25*256+25
	jp add_rand
ms_shield:
	ld hl,p_shield
	ld bc,30*256+20
	call add_rand
	ld hl,msg_mystic_shield
	jp msg_print
ms_invuln:
	ld hl,p_invuln
	ld bc,8*256+8
	jp add_rand

; new ones
ms_doors_make:							; door_creation: closed doors on the
	ld hl,around						; floor all round (not on artifacts,
	ld b,8								; nor monsters)
.each:
	push bc
	push hl
	ld a,(player_y)
	add a,(hl)
	ld d,a
	inc hl
	ld a,(player_x)
	add a,(hl)
	ld e,a
	call make_door
	pop hl
	inc hl
	inc hl
	pop bc
	djnz .each
	ret
around:		db -1,-1, -1,0, -1,1, 0,-1, 0,1, 1,-1, 1,0, 1,1
make_door:								; D = y, E = x
	push de
	call map_addr
	pop de
	ld a,(hl)
	bit 7,a
	ret nz								; (a monster)
	and 15
	cp T_FLOOR
	jr z,.floor
	cp T_CORRIDOR
	jr z,.floor
	cp T_FLOOR_LIT
	ret nz
.floor:
	push hl
	call item_at
	pop hl
	jr nc,.door
	ld a,(ix+I_NAME2)					; an artifact resists
	or a
	jr z,.gone
	push hl
	call ego_addr
	pop hl
	bit EO_ARTIFACT,(iy+E_OPTS)
	jr z,.gone
	ld hl,msg_resists_spell
	jp msg_print
.gone:
	ld (ix+I_KIND_HI),ITEM_EMPTY
.door:
	ld a,(hl)
	and $F0
	or T_DOOR_CLOSED
	ld (hl),a
	ret
ms_stairs:								; stair_creation: up or down here
	ld a,(player_y)
	ld d,a
	ld a,(player_x)
	ld e,a
	call item_at
	jr nc,.stair
	ld a,(ix+I_NAME2)
	or a
	jr z,.gone
	call ego_addr
	bit EO_ARTIFACT,(iy+E_OPTS)
	jr z,.gone
	ld hl,msg_resists_spell
	jp msg_print
.gone:
	ld (ix+I_KIND_HI),ITEM_EMPTY
.stair:
	ld a,(player_y)
	ld d,a
	ld a,(player_x)
	ld e,a
	call map_addr
	ld b,T_STAIR_DOWN					; up 1 in 2, below the town (and
	ld a,(dun_level)					; always on Sauron's level)
	or a
	jr z,.set
	push bc
	call is_quest
	pop bc
	jr z,.up
	push hl
	ld a,2
	call randint
	pop hl
	dec a
	jr nz,.set
.up:
	ld b,T_STAIR_UP
.set:
	ld a,(hl)
	and $F0
	or b
	ld (hl),a
	ret
ms_det_ench:							; detect_enchantment: magical
	ld ix,ITEM_LIST						; things on screen are shown
	ld b,ITEM_MAX
.each:
	push bc
	ld a,(ix+I_KIND_HI)
	cp KIND_GOLD
	jr nc,.next
	call on_screen
	jr nc,.next
	call item_kind_addr
	ld a,(iy+K_CLASS)					; weapons and armour with pluses, an
	cp IC_WEAPON						; ego, and not cursed (bows and
	jr c,.next							; arrows too)
	cp IC_CHEST
	jr z,.next
	cp IC_BOW
	jr nc,.arms
	cp IC_AMULET
	jr nc,.next
.arms:
	bit ID_CURSED_BIT,(ix+I_IDENT)
	jr nz,.next
	ld a,(ix+I_NAME2)
	or a
	jr nz,.magic
	ld a,(ix+I_TOHIT)
	call sp_positive
	jr c,.magic
	ld a,(ix+I_TODAM)
	call sp_positive
	jr c,.magic
	ld a,(ix+I_TOAC)
	call sp_positive
	jr nc,.next
.magic:
	ld (ix+I_MARKED),1
.next:
	ld de,ITEM_SIZE
	add ix,de
	pop bc
	djnz .each
	ret
sp_positive:							; A signed -> carry if above 0
	bit 7,a
	ret nz
	or a
	ret z
	scf
	ret
on_screen:								; IX = floor item -> carry if in view
	ld a,(view_y)
	ld b,a
	ld a,(ix+I_Y)
	sub b
	ret c
	cp VIEW_H
	ret nc
	ld a,(view_x)
	ld b,a
	ld a,(ix+I_X)
	sub b
	ret c
	cp VIEW_W
	ret

; ---------------------------------------------------------------- prayers

/* the prayers: PRIEST prayers 1-58 (PRAYER.C) */
prayers:
	dw ms_det_evil, pr_cure_light, pr_bless, pr_fear, ms_light			; 1-5
	dw pr_traps, pr_doors, pr_slow_poison, ms_confuse, pr_portal		; 6-10
	dw pr_cure_serious, pr_chant, ms_sleep2, ms_food, pr_uncurse		; 11-15
	dw pr_res_heat_cold, ms_cure_poison, pr_orb, pr_cure_critical, pr_sense_inv	; 16-20
	dw pr_prot_evil, ms_quake, pr_map, pr_cure_mortal, pr_turn_undead	; 21-25
	dw pr_prayer, pr_dispel_undead3, pr_heal, pr_dispel_evil3, pr_glyph	; 26-30
	dw pr_holy_word, ms_det_mons, pr_detection, ms_identify, pr_probing	; 31-35
	dw pr_clairvoyance, pr_cure_critical, pr_cure_mortal, pr_healing, pr_restoration	; 36-40
	dw pr_remembrance, pr_dispel_undead4, pr_dispel_evil4, pr_banish, ms_destruction	; 41-45
	dw pr_annihilate, ms_td, pr_recharge, pr_dispel_curse, pr_enchant_weapon	; 46-50
	dw pr_enchant_armour, pr_brand, ms_phase, pr_teleport, ms_tele_other	; 51-55
	dw ms_tele_level, ms_recall, pr_alter, no_spell, no_spell			; 56-60
	dw no_spell, no_spell, no_spell

pr_cure_light:							; 3d3, cuts 10 better
	ld bc,3*256+3
	call heal_dice
	ld hl,(p_cut)
	call cut_positive
	ret z
	ld de,-10
	jr cut_less
pr_cure_serious:						; 4d4, cuts halved less 20
	ld bc,4*256+4
	call heal_dice
	ld hl,(p_cut)
	call cut_positive
	ret z
	sra h
	rr l
	ld de,-20
cut_less:
	add hl,de
	jr c,$+5
	ld hl,0
	ld (p_cut),hl
	jp pr_wounds_heal
pr_cure_critical:						; 8d4, no more cuts
	ld bc,8*256+4
	jr cure_cuts
pr_cure_mortal:							; 16d4
	ld bc,16*256+4
cure_cuts:
	call heal_dice
	ld hl,(p_cut)
	call cut_positive
	ret z
	ld hl,0
	ld (p_cut),hl
pr_wounds_heal:							; (the C's own words)
	ld hl,msg_you_wounds_heal
	jp msg_print
heal_dice:								; heal B dice of C
	call damroll
heal_hl:
	OVCALL PAGE_MAGIC, hp_player, PAGE_SPELL
	ret
cut_positive:							; HL = cut -> NZ if above 0
	bit 7,h
	jr nz,.no
	ld a,h
	or l
	ret
.no:
	xor a
	ret
pr_heal:								; 200, and stun and cuts gone
	ld hl,200
	jr heal_all
pr_healing:
	ld hl,2000
heal_all:
	call heal_hl
cure_stun_cut:
	OVCALL PAGE_MAGIC, cure_stun, PAGE_SPELL
	ld hl,(p_cut)
	call cut_positive
	ret z
	ld hl,0
	ld (p_cut),hl
	ld hl,msg_feel_better_s
	jp msg_print
pr_holy_word:							; dispel evil 4 x lev, fear and
	call pr_dispel_evil4				; poison gone, 1000, stun and cuts
	call pr_fear
	OVCALL PAGE_MAGIC, cure_poison, PAGE_SPELL
	ld hl,1000
	jr heal_all
pr_fear:
	OVCALL PAGE_MAGIC, remove_fear, PAGE_SPELL
	ret
pr_slow_poison:
	OVCALL PAGE_MAGIC, slow_poison, PAGE_SPELL
	ret
pr_bless:								; blessed 12 + 1d12
	ld bc,12*256+12
	jr blessed
pr_chant:
	ld bc,24*256+24
	jr blessed
pr_prayer:
	ld bc,48*256+48
blessed:
	ld hl,p_blessed
	jp add_rand
pr_sense_inv:							; detect invisible 24 + 1d24
	ld hl,p_detect_inv
	ld bc,24*256+24
	jp add_rand
pr_res_heat_cold:						; 10 + 1d10 each
	ld hl,p_resist_heat
	ld bc,10*256+10
	call add_rand
	ld hl,p_resist_cold
	ld bc,10*256+10
	jp add_rand
pr_portal:								; teleport(lev * 3)
	ld a,(p_lev)
	ld e,a
	ld d,3
	jr pr_tele
pr_teleport:							; teleport(lev * 8)
	ld a,(p_lev)
	ld e,a
	ld d,8
pr_tele:
	mul d,e
	ex de,hl
	jp sp_teleport
pr_uncurse:
	OVCALL PAGE_SCROLL, sc_remove_curse, PAGE_SPELL
	ret
pr_dispel_curse:
	OVCALL PAGE_SCROLL, sc_star_remove, PAGE_SPELL
	ret
pr_prot_evil:
	OVCALL PAGE_SCROLL, sc_protevil, PAGE_SPELL
	ret
pr_map:
	OVCALL PAGE_SCROLL, sc_map, PAGE_SPELL
	ret
pr_recharge:
	ld a,15
	jp sp_recharge
pr_enchant_weapon:
	OVCALL PAGE_SCROLL, pr_enchant_weapon_s, PAGE_SPELL
	ret
pr_enchant_armour:
	OVCALL PAGE_SCROLL, sc_enchant_ac, PAGE_SPELL
	ret
pr_brand:
	OVCALL PAGE_SCROLL, pr_brand_s, PAGE_SPELL
	ret
pr_clairvoyance:
	OVCALL PAGE_MAGIC, wizard_light, PAGE_SPELL
	ret
pr_remembrance:
	OVCALL PAGE_MAGIC, restore_level, PAGE_SPELL
	ret
pr_restoration:							; each stat, with its message
	OVCALL PAGE_MAGIC, pe_res_str, PAGE_SPELL
	OVCALL PAGE_MAGIC, pe_res_int, PAGE_SPELL
	OVCALL PAGE_MAGIC, pe_res_wis, PAGE_SPELL
	OVCALL PAGE_MAGIC, pe_res_dex, PAGE_SPELL
	OVCALL PAGE_MAGIC, pe_res_con, PAGE_SPELL
	OVCALL PAGE_MAGIC, pe_res_chr, PAGE_SPELL
	ret
pr_alter:								; alter reality: a new level here
	ld a,3
	ld (p_new_level),a
	ret
pr_orb:									; orb of draining: 3d6 + lev
	ld hl,txt_black_sphere
	call own_name
	ld bc,3*256+6
	call damroll
	ld a,(p_lev)
	add hl,a
	xor a
	jp sp_ball
pr_annihilate:							; drain life 200
	ld hl,200
	ld (sp_entry+4),hl
	ld a,AE_DRAIN
	jp sp_effect
pr_turn_undead:
	ld a,AE_TURN_UNDEAD
	jp sp_effect
pr_banish:
	ld a,AE_BANISH
	jp sp_effect
pr_detection:
	ld a,AE_DETECT_ALL
	jp sp_effect
pr_probing:
	ld a,AE_PROBE_ALL
	jp sp_effect
pr_glyph:								; Glyph of Warding
	OVCALL PAGE_TRAP, warding_glyph, PAGE_SPELL
	ret
pr_dispel_undead3:						; dispel undead 3 x lev
	ld b,1<<RF_UNDEAD
	ld c,3
	jr pr_dispel
pr_dispel_undead4:
	ld b,1<<RF_UNDEAD
	ld c,4
	jr pr_dispel
pr_dispel_evil3:
	ld b,1<<RF_EVIL
	ld c,3
	jr pr_dispel
pr_dispel_evil4:
	ld b,1<<RF_EVIL
	ld c,4
pr_dispel:								; B = the monsters, C x lev damage
	ld a,b
	ld (sp_entry+3),a
	ld a,(p_lev)
	ld e,a
	ld d,c
	mul d,e
	ld a,d								; (at most 255)
	or a
	ld a,e
	jr z,$+4
	ld a,255
	ld (sp_entry+4),a
	ld a,AE_DISPEL
	jp sp_effect

; ---------------------------------------------------------------- text

txt_forgotten:		db "You have forgotten the ",0
txt_remembered:		db "You have remembered the ",0
txt_spell_of:		db "spell of ",0
txt_prayer_of:		db "prayer of ",0
msg_can_learn:		db "You can learn some new spells now.",0
msg_can_learn_p:	db "You can learn some new prayers now.",0
t_cant_see:			dw msg_cant_see_book, msg_cant_see_prayer
t_no_books:			dw msg_no_books, msg_no_holy_books
t_which_book:		dw txt_which_book, txt_which_holy
t_dont_know:		dw msg_dont_know, msg_dont_know_p
t_cast_which:		dw txt_cast_which, txt_recite_which
t_dont_know_that:	dw msg_dont_know_that, msg_dont_know_that_p
t_failed:			dw msg_spell_failed, msg_lost_concentration
t_faint:			dw msg_faint_effort, msg_faint_fatigue
t_cant_learn:		dw msg_cant_learn, msg_cant_learn_p
msg_cant_see_book:	db "You can't see to read your spell book!",0
msg_cant_see_prayer: db "You can't see to read your prayer!",0
msg_no_holy_books:	db "You are not carrying any Holy Books!",0
txt_which_holy:		db "Use which Holy Book? (letter, or space)",0
msg_dont_know_p:	db "You don't know any prayers in that book.",0
txt_recite_which:	db "Recite which prayer? (letter, or space)",0
msg_dont_know_that_p: db "You don't know that prayer.",0
msg_lost_concentration: db "You lost your concentration!",0
msg_faint_fatigue:	db "You faint from fatigue!",0
msg_cant_learn_p:	db "You can't learn any new prayers!",0
msg_pray_hard:		db "Pray hard enough and your prayers may be answered.",0
txt_learned_prayer:	db "You have learned the ",0
msg_too_confused_sp: db "You are too confused.",0
msg_no_books:		db "But you are not carrying any spell-books!",0
txt_which_book:		db "Use which spell-book? (letter, or space)",0
msg_cant_cast:		db "You can't cast spells!",0
msg_cant_read:		db "You cannot read books!",0
msg_dont_know:		db "You don't know any spells in that book.",0
msg_dont_know_that:	db "You don't know that spell.",0
txt_cast_which:		db "Cast which spell? (letter, or space)",0
msg_spell_failed:	db "You failed to get the spell off!",0
txt_limited:		db "You summon your limited strength to cast this one! Confirm? (y/n)",0
msg_faint_effort:	db "You faint from the effort!",0
msg_damaged_health:	db "You have damaged your health!",0
msg_nothing_in_book: db "There is nothing in that book you can use.",0
txt_any_key_sp:		db "-- press a key --",0
msg_cant_learn:		db "You can't learn any new spells!",0
msg_missing_book:	db "You seem to be missing a book.",0
txt_learn_which:	db "Learn which spell? (letter, or space)",0
txt_spells_head:	db "   Name                          Lv Mana Fail",0
txt_forgotten_n:	db " forgotten",0
txt_unknown_n:		db " unknown",0
txt_untried_n:		db " untried",0
msg_wounds_heal_s:	db "Your wounds heal.",0
msg_you_wounds_heal: db "You wounds heal.",0
msg_feel_better_s:	db "You feel better.",0
txt_black_sphere:	db "Black Sphere",0
msg_air_charged_s:	db "The air about you becomes charged.",0
msg_mystic_shield:	db "A mystic shield forms around your body!",0
msg_resists_spell:	db "The object resists the spell.",0
txt_acid_bolt_s:	db "Acid Bolt",0
txt_deadly_cloud:	db "Deadly Cloud",0
txt_acid_ball_s:	db "Acid Ball",0
txt_ice_storm:		db "Ice Storm",0
txt_meteor:			db "Meteor Swarm",0
txt_hellfire:		db "Hellfire",0

; ---------------------------------------------------------------- variables

cs_i:			db 0
cs_j:			db 0
cs_levels:		dw 0
cs_allowed:		dw 0
cs_new:			dw 0
sc_mana:		db 0
sc_adj:			db 0
sp_spell:		db 0
sp_first:		db 0
sp_count:		db 0
sp_known:		db 0
sp_letters:		db 0
sp_notes:		db 0
sp_named:		db 0
sp_short:		db 0
sp_at:			dw 0
ps_i:			db 0
ps_spell:		db 0
sp_bits:		ds 8
sp_list:		ds SPELLS_PER_CLASS+1
