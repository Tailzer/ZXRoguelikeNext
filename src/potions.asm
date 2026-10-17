/* potions.asm - quaffing, stat changes and their helpers  [overlay: PAGE_MAGIC]
	References: POTIONS.C quaff, MISC2.C inc_stat/dec_stat/res_stat,
	DUNGEON.C ruin_stat, SPELLS.C hp_player, the cures, lose_str etc, lose_exp,
	restore_level/self_knowledge/identify_pack, WIZARD.C wizard_light,
	MISC2.C cut_player/stun_player, DESC.C magic_init.
	A potion's flags say what it does: each set bit is one effect, numbered
	from 1 (33 for TV_POTION2), run lowest bit first as the C's bit_pos does.
 */

/* magic_action - B = PM_ action, A = its argument (pending_actions) */
magic_action:
	dec b
	jp z,quaff_potion
	ret

/* magic_init - this game's potion colours: all but the first three
	(slime mold, apple juice, water) are shuffled (magic_init in DESC.C) */
magic_init:
	ld hl,flavour_map
	xor a
.ident:
	ld (hl),a
	inc hl
	inc a
	cp MAX_FLAVOURS
	jr c,.ident
	ld a,3
.shuffle:
	ld (mi_i),a
	ld a,MAX_FLAVOURS-3					; j = randint(MAX_COLORS - 3) + 2
	call randint
	add a,2
	ld hl,flavour_map
	add hl,a
	ex de,hl							; DE = &map[j]
	ld a,(mi_i)
	ld hl,flavour_map
	add hl,a							; HL = &map[i]
	ld a,(de)
	ld c,(hl)
	ld (hl),a
	ld a,c
	ld (de),a
	ld a,(mi_i)
	inc a
	cp MAX_FLAVOURS
	jr c,.shuffle
	ld hl,wood_map						; woods and metals: all shuffled
	call .shuffle32
	ld hl,metal_map
	call .shuffle32
	; scroll titles: 2 or 3 words of 1 or 2 syllables each, cut at 9
	nextreg NR_MMU1,FLAVOUR_PAGE
	ld hl,scroll_titles
	ld (mi_dst),hl
	ld a,MAX_TITLES
.title:
	ld (mi_i),a
	ld hl,mi_buf						; a fresh buffer
	ld b,MI_BUF_SIZE
.wipe:
	ld (hl),0
	inc hl
	djnz .wipe
	ld hl,mi_buf
	ld (mi_ptr),hl
	ld a,2
	call randint
	inc a
	ld (mi_words),a
.word:
	ld a,2
	call randint
.syllable:
	push af
	ld a,NUM_SYLLABLES
	call randint
	dec a
	add a,a
	ld hl,syllables
	add hl,a
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	ld de,(mi_ptr)
.copy:
	ld a,(hl)
	or a
	jr z,.copied
	ld (de),a
	inc hl
	inc de
	jr .copy
.copied:
	ld (mi_ptr),de
	pop af
	dec a
	jr nz,.syllable
	ld hl,mi_words
	dec (hl)
	jr z,.cut
	ld hl,(mi_ptr)						; a space between words
	ld (hl),' '
	inc hl
	ld (mi_ptr),hl
	jr .word
.cut:
	ld a,(mi_buf+8)						; end at 8 if that's a space, else 9
	cp ' '
	ld hl,mi_buf+8
	jr z,$+3
	inc hl
	ld (hl),0
	ld hl,mi_buf
	ld de,(mi_dst)
	ld bc,10
	ldir
	ld (mi_dst),de
	ld a,(mi_i)
	dec a
	jr nz,.title
	ret
.shuffle32:								; HL = 32 entries: in order, then
	ld (mi_dst),hl						; each swapped with a random one
	xor a
.order:
	ld (hl),a
	inc hl
	inc a
	cp 32
	jr c,.order
	xor a
.swap:
	ld (mi_i),a
	ld a,32
	call randint
	dec a
	ld hl,(mi_dst)
	add hl,a
	ex de,hl							; DE = &map[j]
	ld a,(mi_i)
	ld hl,(mi_dst)
	add hl,a							; HL = &map[i]
	ld a,(de)
	ld c,(hl)
	ld (hl),a
	ld a,c
	ld (de),a
	ld a,(mi_i)
	inc a
	cp 32
	jr c,.swap
	ret

; ---------------------------------------------------------------- quaff

/* quaff_potion - A = pack slot of the potion to drink */
quaff_potion:
	ld (u_slot),a
	call pack_slot
	call item_kind_addr
	ld (u_kind),hl
	ld a,(iy+K_LEVEL)
	ld (u_level),a
	ld l,(iy+K_P1)
	ld h,(iy+K_P1+1)
	ld (q_food),hl
	ld a,(iy+K_GROUP2)
	or a
	jr z,$+4
	ld a,32
	ld (q_base),a
	ld b,4
	push iy
	pop hl
	ld de,K_FLAGS
	add hl,de
	ld de,q_flags
	ld bc,4
	ldir
	xor a
	ld (u_ident),a
	ld hl,(q_flags)						; no flags: just a drink
	ld de,(q_flags+2)
	ld a,h
	or l
	or d
	or e
	jr nz,.effects
	ld hl,msg_less_thirsty
	call msg_print
	call ident
	jr .done
.effects:
	xor a
	ld (q_bit),a
.bit:
	ld hl,q_flags+3
	srl (hl)
	dec hl
	rr (hl)
	dec hl
	rr (hl)
	dec hl
	rr (hl)
	jr nc,.next
	ld a,(q_bit)						; j = bit + 1 (+ 32)
	ld hl,q_base
	add a,(hl)
	call potion_effect
.next:
	ld hl,q_bit
	inc (hl)
	ld a,(hl)
	cp 32
	jr c,.bit
.done:
	call item_used
	ld hl,(q_food)
	call add_food
	ld a,(u_slot)
	call desc_remain
	ld a,(u_slot)
	jp use_one

/* potion_effect - A = effect number - 1 (0-63) */
potion_effect:
	cp NUM_POTION_EFFECTS
	ret nc
	add a,a
	ld hl,potion_effects
	add hl,a
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	jp (hl)

potion_effects:
	dw pe_str, pe_lose_str, pe_res_str, pe_int, pe_lose_int, pe_res_int	; 1-6
	dw pe_wis, pe_lose_wis, pe_res_wis, pe_chr, pe_lose_chr, pe_res_chr	; 7-12
	dw pe_clw, pe_csw, pe_ccw, pe_healing, pe_con, pe_experience			; 13-18
	dw pe_sleep, pe_blind, pe_confuse, pe_poison, pe_speed, pe_slow		; 19-24
	dw pe_none, pe_dex, pe_res_dex, pe_res_con, cure_blindness_i		; 25-29
	dw cure_confusion_i, cure_poison_i, pe_none, pe_none, pe_lose_mem	; 30-34
	dw pe_salt, pe_none, pe_hero, pe_shero, remove_fear_i, restore_level_i	; 35-40
	dw pe_res_heat, pe_res_cold, pe_det_inv, slow_poison_i, cure_poison_i	; 41-45
	dw pe_none, pe_infra, pe_star_enlight, pe_detonate, pe_death			; 46-50
	dw pe_life, pe_augment, pe_ruin, pe_enlight, pe_self, pe_star_heal	; 51-56
NUM_POTION_EFFECTS	equ ($-potion_effects)/2

pe_none:								; 46: restore mana (no mana yet)
	ret

; gain a stat: message if it went up
pe_str:
	ld hl,msg_muscles
	ld a,A_STR
	jr gain_msg
pe_int:
	ld hl,msg_brilliant
	ld a,A_INT
	jr gain_msg
pe_wis:
	ld hl,msg_profound
	ld a,A_WIS
	jr gain_msg
pe_chr:
	ld hl,msg_cute
	ld a,A_CHR
	jr gain_msg
pe_con:
	ld hl,msg_tingly
	ld a,A_CON
	jr gain_msg
pe_dex:
	ld hl,msg_limber
	ld a,A_DEX
gain_msg:
	push hl
	call inc_stat
	pop hl
	ret nc
	call msg_print
	jp ident

; restore a stat
pe_res_str:
	ld hl,msg_warm_all
	ld a,A_STR
	jr res_msg
pe_res_int:
	ld hl,msg_warm_feeling
	ld a,A_INT
	jr res_msg
pe_res_wis:
	ld hl,msg_wisdom_back
	ld a,A_WIS
	jr res_msg
pe_res_chr:
	ld hl,msg_looks_back
	ld a,A_CHR
	jr res_msg
pe_res_dex:
	ld hl,msg_less_clumsy
	ld a,A_DEX
	jr res_msg
pe_res_con:
	ld hl,msg_health_back
	ld a,A_CON
res_msg:
	push hl
	call res_stat
	pop hl
	ret nc
	call msg_print
	jp ident

; lose a stat (always identifies)
pe_lose_str:
	ld a,A_STR
	jr lose_stat
pe_lose_int:
	ld a,A_INT
	jr lose_stat
pe_lose_wis:
	ld a,A_WIS
	jr lose_stat
pe_lose_chr:
	ld a,A_CHR
lose_stat:
	push af
	call ident
	pop af
/* lose_stat_msg - A = stat: lose_str() and friends: a sustained stat
	resists, with a message either way */
lose_stat_msg:
	ld (ls_stat),a
	ld b,RACE_HALF_TROLL				; which race sustains it, if any
	cp A_STR
	jr z,.sustain
	ld b,RACE_HOBBIT
	cp A_DEX
	jr z,.sustain
	ld b,RACE_DUNADAN
	cp A_CON
	jr z,.sustain
	ld b,$FF
.sustain:
	ld a,(ls_stat)
	add a,a
	add a,a
	ld hl,lose_msgs
	add hl,a							; HL -> (lost, sustained) messages
	ld a,(p_race)
	cp b
	jr z,.sustained
	push hl
	ld a,(ls_stat)
	call dec_stat
	pop hl
	jr .say
.sustained:
	inc hl
	inc hl
.say:
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	jp msg_print

lose_msgs:
	dw msg_very_sick, msg_sick_passes		; STR
	dw msg_dizzy, msg_dizzy_passes			; INT
	dw msg_naive, msg_naive_passes			; WIS
	dw msg_sore, msg_sore_passes			; DEX
	dw msg_very_sick, msg_sick_passes		; CON
	dw msg_itch, msg_itch_passes			; CHR

; healing
pe_clw:
	ld bc,2*256+7
	call damroll
	call hp_player_i
	ld hl,(p_cut)						; cut -= 10
	call positive
	ret z
	ld de,-10
	add hl,de
	jr cut_healed
pe_csw:
	ld bc,4*256+7
	call damroll
	call hp_player_i
	ld hl,(p_cut)						; cut = cut/2 - 50
	call positive
	ret z
	sra h
	rr l
	ld de,-50
	add hl,de
	jr cut_healed
pe_ccw:
	ld bc,6*256+7
	call damroll
	call hp_player_i
	call cure_cut
	jp cure_stun
pe_healing:
	ld hl,400
	call hp_player_i
	call cure_stun
	jp cure_cut
pe_star_heal:
	ld hl,1200
	call hp_player_i
	call cure_stun
	call cure_cut
	call cure_blindness_i
	call cure_confusion_i
	jp cure_poison_i

/* positive - HL = signed value -> Z if it isn't above 0 */
positive:
	bit 7,h
	jr nz,.no
	ld a,h
	or l
	ret
.no:
	xor a
	ret

/* cut_healed - HL = what's left of the cut (0 if below) */
cut_healed:
	bit 7,h
	jr z,$+5
	ld hl,0
	ld (p_cut),hl
	jr wounds_heal
cure_cut:
	ld hl,(p_cut)
	call positive
	ret z
	ld hl,0
	ld (p_cut),hl
wounds_heal:
	call ident
	ld hl,msg_wounds_heal
	jp msg_print
cure_stun:
	ld hl,(p_stun)
	call positive
	ret z
	ld hl,0
	ld (p_stun),hl
	call bonus_update
	call ident
	ld hl,msg_head_stops
	jp msg_print

hp_player_i:
	call hp_player
	ret nc
	jp ident

/* hp_player - HL = hit points to heal -> carry if any were (SPELLS.C) */
hp_player:
	ld (hp_num),hl
	ld hl,(p_chp)
	ld de,(p_mhp)
	or a
	sbc hl,de
	ret nc								; already at full health
	ld hl,(p_chp)
	ld de,(hp_num)
	add hl,de
	ld (p_chp),hl
	ld de,(p_mhp)
	or a
	sbc hl,de
	jr c,.msg
	ld (p_chp),de
	ld hl,0
	ld (p_chp_frac),hl
.msg:
	ld hl,(hp_num)						; by num / 5
	ld c,5
	call div16_8
	ld a,h
	or a
	ld a,l
	ld hl,msg_very_good
	jr nz,.say
	or a
	ld hl,msg_little_better
	jr z,.say
	cp 3
	ld hl,msg_better
	jr c,.say
	cp 7
	ld hl,msg_much_better
	jr c,.say
	ld hl,msg_very_good
.say:
	call msg_print
	scf
	ret

pe_experience:
	ld hl,p_exp							; l = exp/2 + 10, at most 100000
	ld de,ex_val
	ld bc,4
	ldir
	ld hl,ex_val+3
	srl (hl)
	dec hl
	rr (hl)
	dec hl
	rr (hl)
	dec hl
	rr (hl)
	ld hl,(ex_val)
	ld de,10
	add hl,de
	ld (ex_val),hl
	ld hl,(ex_val+2)
	ld de,0
	adc hl,de
	ld (ex_val+2),hl
	ld de,1								; above 100000 ($186A0)?
	or a
	sbc hl,de
	jr c,.add
	jr nz,.cap
	ld hl,(ex_val)
	ld de,$86A0+1
	sbc hl,de							; (carry clear)
	jr c,.add
.cap:
	ld hl,$86A0
	ld (ex_val),hl
	ld hl,1
	ld (ex_val+2),hl
.add:
	ld hl,(ex_val)
	ld de,(ex_val+2)
	call add_exp32
	ld hl,msg_more_exp
	call msg_print
	call check_level_up
	jp ident

; bad things
pe_sleep:
	ld a,(p_race)
	cp RACE_GNOME						; free action
	ret z
	ld hl,msg_fall_asleep
	call msg_print
	ld a,4
	call randint
	add a,4
	ld hl,p_paralysed
	add a,(hl)
	ld (hl),a
	jp ident
pe_blind:
	ld a,(p_race)
	cp RACE_DWARF						; resists blindness
	ret z
	ld hl,p_blind
	ld de,msg_veil
	call say_if_zero
	ld hl,p_blind
	ld bc,100*256+100
	jp add_rand
pe_confuse:
	ld hl,p_confused
	ld de,msg_good_stuff
	call say_if_zero
	ld hl,p_confused
	ld bc,12*256+20
	jp add_rand
pe_poison:
	ld hl,p_poisoned
	ld de,msg_very_sick
	call say_if_zero
	ld hl,p_poisoned
	ld bc,10*256+15
	jp add_rand
pe_speed:
	ld hl,p_fast
	call get_w
	call z,ident
	ld bc,15*256+25
	jp z,add_rand
	ld bc,0*256+5
	jp add_rand
pe_slow:
	ld hl,p_slow
	ld bc,15*256+25
	jr if_zero_ident
pe_hero:
	ld hl,p_hero
	ld bc,25*256+25
	jr if_zero_ident
pe_shero:
	ld hl,p_shero
	ld bc,25*256+25
	jr if_zero_ident
pe_res_heat:
	ld hl,p_resist_heat
	ld bc,10*256+10
	jr if_zero_ident
pe_res_cold:
	ld hl,p_resist_cold
	ld bc,10*256+10
	jr if_zero_ident
pe_det_inv:
	ld hl,p_detect_inv
	ld bc,12*256+12
if_zero_ident:							; identifies if it wasn't running
	call get_w
	push bc
	call z,ident
	pop bc
	jp add_rand
pe_infra:
	ld hl,p_tim_infra
	ld de,msg_tingle
	call say_if_zero
	ld hl,p_tim_infra
	ld bc,100*256+100
	jp add_rand

/* say_if_zero - HL = counter, DE = message: say it and identify if the
	counter is 0 */
say_if_zero:
	call get_w
	ret nz
	ex de,hl
	call msg_print
	jp ident

pe_lose_mem:
	call ident
	ld hl,(p_exp)
	ld de,(p_exp+2)
	ld a,h
	or l
	or d
	or e
	ld hl,msg_memories_return
	jp z,msg_print
	ld hl,msg_memories_fade
	call msg_print
	ld hl,(p_exp)						; m = exp / 5
	ld a,(p_exp+2)
	ld e,a
	ld c,5
	call div24_8
	ld (lm_m),hl
	ld a,e
	ld (lm_m+2),a
	ld hl,(p_exp+2)						; exp > 32767?
	ld a,h
	or l
	jr nz,.big
	ld hl,(p_exp)
	bit 7,h
	jr nz,.big
	call randint16						; m += randint(exp) / 5
	ld c,5
	call div16_8
	xor a
	jr .add
.big:									; m += about randint(exp)/5, as
	call rand16							; m * (0-255) / 256
	ld c,h
	ld a,(lm_m+1)
	ld d,a
	ld e,c
	mul d,e
	push de								; mid * r
	ld a,(lm_m+2)
	ld d,a
	ld e,c
	mul d,e								; high * r, shifted 8
	pop hl
	ld a,h
	add a,e
	ld h,a
	ld a,d
	adc a,0								; A:HL = the extra
.add:
	ld de,(lm_m)
	add hl,de
	ld e,a
	ld a,(lm_m+2)
	adc a,e
	ld e,a
	jp lose_exp

pe_salt:
	call cure_poison
	ld hl,(p_food)						; food at most 150
	ld de,151
	bit 7,h
	jr nz,.ok
	or a
	sbc hl,de
	jr c,.ok
	ld hl,150
	ld (p_food),hl
.ok:
	ld a,4
	ld (p_paralysed),a
	ld hl,msg_vomit
	call msg_print
	jp ident

pe_star_enlight:
	call wizard_light
	ld a,A_WIS
	call res_stat
	ld a,A_WIS
	call nc,inc_stat
	ld a,A_INT
	call res_stat
	ld a,A_INT
	call nc,inc_stat
	ld hl,msg_enlightened
	call msg_print
	call msg_flush
	call self_knowledge
	call identify_pack
	jp ident

pe_detonate:
	ld hl,msg_explosions
	call msg_print
	ld bc,50*256+20
	call damroll
	ld de,KILLER_DETONATION
	call hurt
	ld hl,5000
	call cut_player
	ld a,75
	call stun_player
	jp ident

pe_death:
	ld hl,msg_death_flows
	call msg_print
	ld hl,5000
	ld de,KILLER_DEATH
	call hurt
	jp ident

pe_ruin:
	ld bc,10*256+10
	call damroll
	ld de,KILLER_RUINATION
	call hurt
	ld hl,ruin_order
	ld b,6
.each:
	push bc
	push hl
	ld a,(hl)
	call ruin_stat
	pop hl
	pop bc
	inc hl
	djnz .each
	call ident
	ld hl,msg_lifeless
	jp msg_print
ruin_order:		db A_DEX,A_WIS,A_CON,A_STR,A_CHR,A_INT

pe_augment:
	xor a
	ld (q_any),a
	ld hl,augment_order
	ld b,6
.each:
	push bc
	push hl
	ld a,(hl)
	call inc_stat
	call any
	pop hl
	pop bc
	inc hl
	djnz .each
	ld a,(q_any)
	or a
	ret z
	call ident
	ld hl,msg_power_flows
	jp msg_print
augment_order:	db A_DEX,A_WIS,A_INT,A_STR,A_CHR,A_CON

/* any - carry -> remember it in q_any */
any:
	ret nc
	ld a,1
	ld (q_any),a
	ret

pe_life:
	xor a
	ld (q_any),a
	call restore_level
	call any
	ld hl,life_order
	ld b,6
.each:
	push bc
	push hl
	ld a,(hl)
	call res_stat
	call any
	pop hl
	pop bc
	inc hl
	djnz .each
	ld hl,5000
	call hp_player
	call any
	call cure_poison
	call any
	call cure_blindness
	call any
	call cure_confusion
	call any
	call remove_fear
	call any
	ld hl,(p_stun)
	call positive
	jr z,$+5
	ld (q_any),a
	ld hl,(p_cut)
	call positive
	jr z,$+5
	ld (q_any),a
	ld a,(q_any)
	or a
	ret z
	call ident
	ld hl,0
	ld (p_cut),hl
	ld (p_stun),hl
	jp bonus_update
life_order:		db A_STR,A_CON,A_DEX,A_WIS,A_INT,A_CHR

pe_enlight:
	call wizard_light
	ld hl,msg_image_forms
	call msg_print
	jp ident

pe_self:
	ld hl,msg_know_better
	call msg_print
	call msg_flush
	call self_knowledge
	jp ident

; ---------------------------------------------------------------- cures

cure_blindness_i:
	call cure_blindness
	ret nc
	jp ident
cure_confusion_i:
	call cure_confusion
	ret nc
	jp ident
cure_poison_i:
	call cure_poison
	ret nc
	jp ident
remove_fear_i:
	call remove_fear
	ret nc
	jp ident
restore_level_i:
	call restore_level
	ret nc
	jp ident
slow_poison_i:
	call slow_poison
	ret nc
	jp ident

/* cure_* - a counter above 1 drops to 1 (it ends next turn) -> carry */
cure_blindness:
	ld hl,p_blind
	jr cure_counter
cure_confusion:
	ld hl,p_confused
	jr cure_counter
cure_poison:
	ld hl,p_poisoned
	jr cure_counter
remove_fear:
	ld hl,p_afraid
cure_counter:
	call get_w
	ld a,d
	or a
	jr nz,.cure
	ld a,e
	cp 2
	jr nc,.cure
	or a
	ret
.cure:
	ld de,1
	call set_w
	scf
	ret

/* slow_poison - poison halves (at least 1) -> carry if poisoned */
slow_poison:
	ld hl,p_poisoned
	call get_w
	ret z								; (carry clear)
	srl d
	rr e
	ld a,d
	or e
	jr nz,$+3
	inc e
	call set_w
	ld hl,msg_poison_reduced
	call msg_print
	scf
	ret

/* restore_level - back to max_exp -> carry if it was below */
restore_level:
	ld hl,(p_max_exp+2)
	ld de,(p_exp+2)
	or a
	sbc hl,de
	ret c
	jr nz,.restore
	ld hl,(p_max_exp)
	ld de,(p_exp)
	sbc hl,de
	ret c
	ret z
.restore:
	ld hl,msg_life_returns
	call msg_print
	ld hl,(p_max_exp)
	ld (p_exp),hl
	ld hl,(p_max_exp+2)
	ld (p_exp+2),hl
	call check_level_up
	scf
	ret

/* lose_exp - E:HL = experience lost: levels drop to match (SPELLS.C) */
lose_exp:
	ld bc,(p_exp)
	ld a,(p_exp+2)
	ld d,a								; D:BC = exp (exp is under 2^24)
	push hl
	ld h,b
	ld l,c
	pop bc								; HL = exp low, BC = amount low
	or a
	sbc hl,bc
	ld a,d
	sbc a,e
	jr nc,.set
	xor a								; more than we have: 0
	ld h,a
	ld l,a
.set:
	ld (p_exp),hl
	ld (p_exp+2),a
	xor a
	ld (p_exp+3),a
	ld b,0								; level = 1 + entries <= exp
	ld hl,P_EXP_TABLE
.count:
	push hl
	push bc
	ld de,p_exp
	call cmp32							; carry if table < exp?
	pop bc
	pop hl
	jr z,.below
	jr nc,.found
.below:
	inc b
	ld a,b
	cp MAX_PLAYER_LEVEL
	jr nc,.found
	inc hl
	inc hl
	inc hl
	inc hl
	jr .count
.found:
	inc b
	ld a,b
	cp MAX_PLAYER_LEVEL+1
	jr c,$+4
	ld a,MAX_PLAYER_LEVEL
	ld hl,p_lev
	cp (hl)
	ret z
	ld (hl),a
	jp calc_hitpoints

/* cmp32 - HL, DE -> 32-bit values: carry if (HL) < (DE), Z if equal */
cmp32:
	inc hl
	inc hl
	inc hl
	inc de
	inc de
	inc de
	ld b,4
.loop:
	ld a,(de)
	ld c,a
	ld a,(hl)
	cp c
	ret nz
	dec hl
	dec de
	djnz .loop
	ret

; ---------------------------------------------------------------- stats

/* inc_stat - A = stat: up one randomised step -> carry if it rose */
inc_stat:
	ld (st_idx),a
	call stat_addr
	ld a,(hl)
	cp 118
	ret nc
	cp 18
	jr nc,.high
	push hl
	ld a,2
	call randint
	pop hl
	add a,(hl)
	jr .set
.high:
	cp 116
	jr nc,.one
	ld b,a								; gain = ((118 - tmp)/2 + 3) >> 1
	ld a,118
	sub b
	srl a
	add a,3
	srl a
	ld c,a
	push hl
	push bc
	call randint
	pop bc
	pop hl
	ld b,a								; tmp += randint(gain) + gain/2
	ld a,c
	srl a
	add a,b
	add a,(hl)
	cp 118
	jr c,.set
	ld a,117
	jr .set
.one:
	inc a
.set:
	ld (hl),a
	ld b,a
	ld de,p_stat_max-p_stat				; raise the maximum with it
	add hl,de
	ld a,b
	cp (hl)
	jr c,set_use_stat
	ld (hl),a
	jr set_use_stat

/* dec_stat - A = stat: down one randomised step -> carry if it fell */
dec_stat:
	ld (st_idx),a
	call stat_addr
	ld a,(hl)
	cp 4
	ccf
	ret nc								; 3 already
	cp 19
	jr c,.one
	cp 117
	jr nc,.one
	ld b,a								; loss = (((118 - tmp) >> 1) + 1) >> 1
	ld a,118
	sub b
	srl a
	inc a
	srl a
	ld c,a
	push hl
	push bc
	call randint
	pop bc
	pop hl
	add a,c								; tmp -= randint(loss) + loss
	ld b,a
	ld a,(hl)
	sub b
	jr c,.floor
	cp 18
	jr nc,.set
.floor:
	ld a,18
	jr .set
.one:
	dec a
.set:
	ld (hl),a
	jr set_use_stat

/* res_stat - A = stat: back to its maximum -> carry if it was below */
res_stat:
	ld (st_idx),a
	call stat_addr
	ld de,p_stat_max-p_stat
	ex de,hl
	add hl,de							; HL = max, DE = current
	ld a,(de)
	cp (hl)
	ret nc								; (equal: carry clear)
	ld a,(hl)
	ld (de),a
	jr set_use_stat

/* ruin_stat - A = stat: a big permanent loss -> carry if it fell */
ruin_stat:
	ld (st_idx),a
	call stat_addr
	ld a,(hl)
	cp 4
	ccf
	ret nc
	cp 7
	jr c,.one
	cp 19
	jr nc,.half
	sub 3
	jr .set
.half:
	srl a
	cp 18
	jr nc,.set
	ld a,18
	jr .set
.one:
	dec a
.set:
	ld (hl),a
	ld de,p_stat_max-p_stat
	add hl,de
	ld (hl),a
/* set_use_stat - (st_idx) changed: bonuses (and hit points for CON) are
	recalculated by the main loop. Returns carry */
set_use_stat:
	ld hl,p_update
	set PU_BONUS,(hl)
	ld a,(st_idx)
	cp A_CON
	jr nz,.done
	set PU_HP,(hl)
.done:
	scf
	ret

/* stat_addr - (st_idx) -> HL = its current value */
stat_addr:
	ld a,(st_idx)
	ld hl,p_stat
	add hl,a
	ret

bonus_update:
	ld hl,p_update
	set PU_BONUS,(hl)
	ret

; ---------------------------------------------------------------- wounds

/* cut_player - HL = how much worse the cut gets */
cut_player:
	ld de,(p_cut)
	add hl,de
	ld (p_cut),hl
	ld ix,cut_levels
	jr level_msg

/* stun_player - A = how much more stunned */
stun_player:
	ld hl,(p_stun)
	add hl,a
	ld (p_stun),hl
	call bonus_update
	ld hl,(p_stun)
	ld ix,stun_levels
/* level_msg - HL = value, IX = (threshold, message) list ending $FFFF:
	say the first message whose threshold the value is above */
level_msg:
	bit 7,h
	ret nz
.next:
	ld e,(ix+0)
	ld d,(ix+1)
	ld a,d
	and e
	inc a
	ret z								; ($FFFF ends the list)
	push hl
	or a
	sbc hl,de
	pop hl
	jr z,.skip
	jr nc,.say
.skip:
	ld de,4
	add ix,de
	jr .next
.say:
	ld l,(ix+2)
	ld h,(ix+3)
	jp msg_print

cut_levels:
	dw 5000,msg_mortal, 900,msg_gash, 200,msg_severe, 100,msg_nasty
	dw 50,msg_bad_cut, 10,msg_light_cut, 0,msg_graze_l, $FFFF
stun_levels:
	dw 100,msg_knocked_out, 50,msg_heavy_stun, 0,msg_stunned, $FFFF

; ---------------------------------------------------------------- knowledge

/* wizard_light - every open square and the squares around it are lit for
	good (wizard_light(TRUE) in WIZARD.C) */
wizard_light:
	ld de,MAP_BASE+MAP_W+1				; skip the border
	ld b,MAP_H-2
.row:
	push bc
	ld b,MAP_W-2
.col:
	ld a,(de)
	and TERRAIN_MASK
	ld hl,open_terrain
	add hl,a
	ld a,(hl)
	or a
	jr z,.next
	push bc
	ld hl,-MAP_W-1
	add hl,de
	ld bc,MAP_W-2
	ld a,3
.light:
	set F_PERM_BIT,(hl)
	inc hl
	set F_PERM_BIT,(hl)
	inc hl
	set F_PERM_BIT,(hl)
	add hl,bc
	dec a
	jr nz,.light
	pop bc
.next:
	inc de
	djnz .col
	inc de
	inc de
	pop bc
	djnz .row
	ret

; terrain that counts as floor (fval <= MAX_CAVE_FLOOR, doors and stairs
; being objects on floor in the C)
open_terrain:	db 0,1,1,0,0,1,1,1,1,1,0,0,0,0,1,1

/* identify_pack - learn every flavour carried */
identify_pack:
	xor a
.each:
	ld (ip_slot),a
	call pack_slot
	ld a,(ix+I_KIND_HI)
	cp ITEM_EMPTY
	ret z
	ld l,(ix+I_KIND)
	ld h,a
	call learn_kind
	ld a,(ip_slot)
	inc a
	cp PACK_MAX
	jr c,.each
	ret

/* self_knowledge - list what the player knows of their own state over
	the map (SPELLS.C) */
self_knowledge:
	ld d,VIEW_TOP
.clear:
	push de
	call clear_row
	pop de
	inc d
	ld a,d
	cp VIEW_TOP+VIEW_H
	jr c,.clear
	ld hl,txt_attributes
	ld d,VIEW_TOP
	ld e,20
	ld c,ATTR_YELLOW
	call print_at
	ld a,VIEW_TOP+1
	ld (sk_row),a
	ld ix,knowledge
.each:
	ld a,(ix+2)
	cp $FF
	jr z,.done
	ld l,(ix+0)							; a counter running?
	ld h,(ix+1)
	ld a,h
	or l
	jr z,.race
	call get_w
	jr nz,.show
.race:
	ld a,(ix+2)							; or a race's gift
	cp $FE
	jr z,.infra
	ld b,a
	ld a,(p_race)
	cp b
	jr z,.show
	jr .next
.infra:
	ld a,(p_infra)
	or a
	jr z,.next
.show:
	ld l,(ix+3)
	ld h,(ix+4)
	ld a,(sk_row)
	ld d,a
	inc a
	ld (sk_row),a
	ld e,15
	ld c,ATTR_WHITE
	call print_at
.next:
	ld de,5
	add ix,de
	jr .each
.done:
	ld a,(sk_row)
	inc a
	ld d,a
	ld e,15
	ld hl,txt_press_key
	ld c,ATTR_GREY
	call print_at
	jp wait_fresh_key

; counter (0 = none), race ($FD = none, $FE = has infravision), text
knowledge:
	dw p_blind
	db $FD
	dw txt_sk_blind
	dw p_confused
	db $FD
	dw txt_sk_confused
	dw p_afraid
	db $FD
	dw txt_sk_afraid
	dw p_cut
	db $FD
	dw txt_sk_cut
	dw p_stun
	db $FD
	dw txt_sk_stun
	dw p_poisoned
	db $FD
	dw txt_sk_poisoned
	dw p_blessed
	db $FD
	dw txt_sk_blessed
	dw p_hero
	db $FD
	dw txt_sk_hero
	dw p_shero
	db $FD
	dw txt_sk_shero
	dw p_protevil
	db $FD
	dw txt_sk_protevil
	dw p_confuse_mon
	db $FD
	dw txt_sk_glowing
	dw p_word_recall
	db $FD
	dw txt_sk_recall
	dw p_tim_infra
	db $FE
	dw txt_sk_infra
	dw p_detect_inv
	db RACE_HIGH_ELF
	dw txt_sk_see_inv
	dw 0
	db RACE_HIGH_ELF
	dw txt_sk_ffall
	dw 0
	db RACE_GNOME
	dw txt_sk_free_act
	dw 0
	db RACE_DWARF
	dw txt_sk_res_blind
	dw p_resist_heat
	db $FD
	dw txt_sk_res_fire
	dw p_resist_cold
	db $FD
	dw txt_sk_res_cold
	dw 0
	db 2								; elves
	dw txt_sk_res_light
	dw 0
	db 6								; half-orcs
	dw txt_sk_res_dark
	dw 0
	db RACE_HALF_TROLL
	dw txt_sk_sus_str
	dw 0
	db RACE_DUNADAN
	dw txt_sk_sus_con
	dw 0
	db RACE_HOBBIT
	dw txt_sk_sus_dex
	dw 0
	db $FF

; ---------------------------------------------------------------- words

; ---------------------------------------------------------------- text

msg_less_thirsty:	db "You feel less thirsty.",0
msg_muscles:		db "Wow!  What bulging muscles!",0
msg_warm_all:		db "You feel warm all over.",0
msg_brilliant:		db "Aren't you brilliant!",0
msg_warm_feeling:	db "You have a warm feeling.",0
msg_profound:		db "You suddenly have a profound thought!",0
msg_wisdom_back:	db "You feel your wisdom returning.",0
msg_cute:			db "Gee, ain't you cute!",0
msg_looks_back:		db "You feel your looks returning.",0
msg_tingly:			db "You feel tingly for a moment.",0
msg_limber:			db "You feel more limber!",0
msg_less_clumsy:	db "You feel less clumsy.",0
msg_health_back:	db "You feel your health returning!",0
msg_very_sick:		db "You feel very sick.",0
msg_sick_passes:	db "You feel sick for a moment,  it passes.",0
msg_dizzy:			db "You become very dizzy.",0
msg_dizzy_passes:	db "You become dizzy for a moment,  it passes.",0
msg_naive:			db "You feel very naive.",0
msg_naive_passes:	db "You feel naive for a moment,  it passes.",0
msg_sore:			db "You feel very sore.",0
msg_sore_passes:	db "You feel sore for a moment,  it passes.",0
msg_itch:			db "Your skin starts to itch.",0
msg_itch_passes:	db "Your skin starts to itch, but feels better now.",0
msg_wounds_heal:	db "Your wounds heal.",0
msg_head_stops:		db "Your head stops stinging.",0
msg_little_better:	db "You feel a little better.",0
msg_better:			db "You feel better.",0
msg_much_better:	db "You feel much better.",0
msg_very_good:		db "You feel very good.",0
msg_more_exp:		db "You feel more experienced.",0
msg_fall_asleep:	db "You fall asleep.",0
msg_veil:			db "You are covered by a veil of darkness.",0
msg_good_stuff:		db "Hey!  This is good stuff!  * Hick! *",0
msg_tingle:			db "Your eyes begin to tingle.",0
msg_memories_fade:	db "You feel your memories fade.",0
msg_memories_return: db "You feel you memories fade for a moment, but quickly return.",0
msg_vomit:			db "The potion makes you vomit!",0
msg_enlightened:	db "You feel more enlightened!",0
msg_explosions:		db "Massive explosions rupture your body!",0
msg_death_flows:	db "A feeling of Death flows through your body.",0
msg_lifeless:		db "Your nerves and muscles feel weak and lifeless",0
msg_power_flows:	db "You feel power flow through your body!",0
msg_image_forms:	db "An image of your surroundings forms in your mind",0
msg_know_better:	db "You feel you know yourself a little better...",0
msg_poison_reduced:	db "The effect of the poison has been reduced.",0
msg_life_returns:	db "You feel your life energies returning.",0
msg_mortal:			db "You have been given a mortal wound.",0
msg_gash:			db "You have been given a deep gash.",0
msg_severe:			db "You have been given a severe cut.",0
msg_nasty:			db "You have been given a nasty cut.",0
msg_bad_cut:		db "You have been given a bad cut.",0
msg_light_cut:		db "You have been given a light cut.",0
msg_graze_l:		db "You have been given a graze.",0
msg_knocked_out:	db "You have been knocked out.",0
msg_heavy_stun:		db "You've been heavily stunned.",0
msg_stunned:		db "You've been stunned.",0
txt_attributes:		db "Your Attributes:",0
txt_press_key:		db "[Press any key to continue]",0
txt_sk_blind:		db "You cannot see.",0
txt_sk_confused:	db "You are confused.",0
txt_sk_afraid:		db "You are scared.",0
txt_sk_cut:			db "You are bleeding.",0
txt_sk_stun:		db "You are reeling.",0
txt_sk_poisoned:	db "You are poisoned.",0
txt_sk_blessed:		db "You feel rightous.",0
txt_sk_hero:		db "You feel heroic.",0
txt_sk_shero:		db "You are in a battle rage.",0
txt_sk_protevil:	db "You are protected from evil.",0
txt_sk_recall:		db "You will soon be recalled.",0
txt_sk_glowing:		db "Your hands are glowing dull red.",0
txt_sk_infra:		db "Your eyes are sensitive to infrared.",0
txt_sk_see_inv:		db "You can see invisible creatures.",0
txt_sk_ffall:		db "You land gently.",0
txt_sk_free_act:	db "You have free action.",0
txt_sk_res_blind:	db "Your eyes are resistant to blindness.",0
txt_sk_res_fire:	db "You are resistant to fire.",0
txt_sk_res_cold:	db "You are resistant to cold.",0
txt_sk_res_light:	db "You are resistant to bright light.",0
txt_sk_res_dark:	db "You are resistant to darkness.",0
txt_sk_sus_str:		db "You will not become weaker.",0
txt_sk_sus_con:		db "You will not become out of shape.",0
txt_sk_sus_dex:		db "You will not become clumsy.",0

; ---------------------------------------------------------------- variables

mi_i:			db 0
mi_dst:			dw 0
mi_ptr:			dw 0
mi_words:		db 0
MI_BUF_SIZE		equ 32
mi_buf:			ds MI_BUF_SIZE
q_food:			dw 0
q_base:			db 0
q_flags:		dd 0
q_bit:			db 0
q_any:			db 0
hp_num:			dw 0
ex_val:			dd 0
lm_m:			ds 3
ls_stat:		db 0
st_idx:			db 0
ip_slot:		db 0
sk_row:			db 0
