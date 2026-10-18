/* effects.asm - timed effects wearing off, once a turn  [overlay: PAGE_MAGIC]
	Reference: DUNGEON.C dungeon() (the block after food and regeneration).
	(change_speed is resident, in status.asm.)
	Effects with a PY_ status bit announce themselves the turn they start;
	all of them count down and say so when they end.
 */

/* timed_tick - one turn of every timed effect, in the C's order */
timed_tick:
	call art_tick
	ld ix,te_blind
	call status_effect
	ld ix,te_confused
	call status_effect
	call afraid_tick
	call cut_tick
	call stun_tick
	call poison_tick
	ld ix,te_fast
	call status_effect
	ld ix,te_slow
	call status_effect
	ld hl,p_protevil
	ld de,msg_no_protevil
	call count_down
	ld ix,te_hero
	call status_effect
	ld ix,te_shero
	call status_effect
	ld ix,te_blessed
	call status_effect
	ld hl,p_resist_heat
	ld de,msg_no_res_heat
	call count_down
	ld hl,p_resist_cold
	ld de,msg_no_res_cold
	call count_down
	ld ix,te_det_inv
	call status_effect
	ld ix,te_tim_infra
	call status_effect
	call rod_tick
	call recall_tick
	jp feel_tick

/* feel_tick - now and then you sense whether things are magical (the two
	pseudo-identify blocks in DUNGEON.C): first anyone may feel something
	"good" or "bad"; then warriors, rogues and paladins learn more */
feel_tick:
	ld hl,(p_confused)					; (not while confused)
	ld a,h
	or l
	ret nz
	ld a,(p_class)
	cp 2
	jr nz,.often
	ld hl,10000							; priests: 1 in 10000/(lev*lev+40)+1
	call per_level
	jp nz,.second
	jr .sense
.often:
	ld a,(game_turn)					; others: every 16 turns, 1 in
	and 15								; 10 + 750/(5+lev)
	jp nz,.second
	ld a,(p_lev)
	add a,5
	ld c,a
	ld hl,750
	call div16_8
	ld de,10
	add hl,de
	call randint16
	dec hl
	ld a,h
	or l
	jp nz,.second
.sense:
	xor a
.each:
	ld (fl_i),a
	call feel_item
	jr z,.next
	call special_check
	jr z,.next
	ld (fl_good),a
	ld a,(p_class)						; priests and rogues sense more
	cp 2
	jr z,.keen
	cp 3
	jr z,.keen
	ld hl,50
	ld de,10
	jr .odds
.keen:
	ld hl,5
	ld de,1
.odds:
	ld a,(fl_i)
	cp PACK_MAX
	jr c,$+3
	ex de,hl
	call randint16
	dec hl
	ld a,h
	or l
	jr nz,.next
	ld a,(p_class)						; warriors, rogues and paladins
	or a								; don't feel weapons and armour this
	jr z,.next							; way (they do below)
	cp 3
	jr z,.next
	cp 5
	jr z,.next
	call msg_begin						; "There's something good about..."
	ld hl,txt_somethings
	call msg_add
	ld a,(fl_good)
	dec a
	ld hl,txt_feel_good
	jr z,$+5
	ld hl,txt_feel_bad
	call msg_add
	ld hl,txt_about_what
	call msg_add
	call add_use
	ld hl,txt_dots
	call msg_add
	call msg_end
	ld a,(fl_good)
	dec a
	jr z,.magik
	set ID_DAMD_BIT,(ix+I_IDENT)
	jr .next
.magik:
	set ID_MAGIK_BIT,(ix+I_IDENT)
.next:
	ld a,(fl_i)
	inc a
	cp PACK_MAX+EQ_MAX
	jp c,.each
.second:								; warriors 9000, rogues 20000,
	ld a,(p_class)						; paladins 80000 / (lev*lev+40)
	ld hl,9000
	or a
	jr z,.roll
	ld hl,20000
	cp 3
	jr z,.roll
	cp 5
	ret nz
	ld hl,80000/4						; (/4: kept to 16 bits)
	call per_level4
	ret nz
	jr .value
.roll:
	call per_level
	ret nz
.value:
	xor a
.item:
	ld (fl_i),a
	call feel_item
	jr z,.next2
	call value_check
	jr z,.next2
	ld (fl_good),a
	ld a,(fl_i)							; in the pack, 1 in 5
	cp PACK_MAX
	jr nc,.felt
	ld a,5
	call randint
	dec a
	jr nz,.next2
.felt:
	call msg_begin						; "You feel the Dagger you are
	ld hl,txt_you_feel_the				;  wielding is good..."
	call msg_add
	call item_kind_addr
	call kind_name
	call add_plural
	ld hl,txt_you_are_
	call msg_add
	call add_use
	call item_kind_addr
	ld a,(iy+K_CLASS)
	cp IC_GLOVES
	ld hl,txt_are_
	jr z,.verb
	cp IC_BOOTS
	jr z,.verb
	ld hl,txt_is_
.verb:
	call msg_add
	ld a,(fl_good)
	dec a
	add a,a
	ld hl,value_words
	add hl,a
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	call msg_add
	ld hl,txt_dots
	call msg_add
	call msg_end
	ld a,(fl_good)						; worthless, terrible: cursed
	cp 5
	jr nc,.damned
	ld (ix+I_FEEL),a
	jr .next2
.damned:
	set ID_DAMD_BIT,(ix+I_IDENT)
.next2:
	ld a,(fl_i)
	inc a
	cp PACK_MAX+EQ_MAX
	jp c,.item
	ret

/* per_level - HL = n: carry-free Z if 1d(n / (lev*lev + 40) + 1) is 1.
	per_level4 - the same for 4*HL */
per_level4:
	ld a,4
	jr per_level_n
per_level:
	ld a,1
per_level_n:
	ld (fl_mul),a
	push hl
	ld a,(p_lev)
	ld e,a
	ld d,a
	mul d,e
	ld hl,40
	add hl,de
	ex de,hl							; DE = lev*lev + 40
	pop hl
	ld (ch_val),hl
	ld hl,0
	ld (ch_val+2),hl
	ld a,(fl_mul)
	ld c,a
	ld b,0
	push de
	call mul32_16
	pop de
	call div32_16
	ld hl,(ch_val)
	inc hl
	call randint16
	dec hl
	ld a,h
	or l
	ret

/* feel_item - (fl_i) = 0-11 pack, 12+ equipment -> IX, NZ if something */
feel_item:
	ld a,(fl_i)
	ld e,a
	ld d,ITEM_SIZE
	mul d,e
	ld ix,PACK
	add ix,de
	ld a,(ix+I_KIND_HI)
	cp ITEM_EMPTY
	ret

/* special_check - IX = item -> A = 1 good, 2 bad, Z if neither (or known) */
special_check:
	call unfelt
	ret z
	bit ID_CURSED_BIT,(ix+I_IDENT)
	ld a,2
	jr nz,.yes
	call arms
	ret z
	ld a,(ix+I_TOHIT)					; any plus at all
	call .plus
	jr nz,.good
	ld a,(ix+I_TODAM)
	call .plus
	jr nz,.good
	ld a,(ix+I_TOAC)
	call .plus
	ret z
.good:
	ld a,1
.yes:
	or a
	ret
.plus:									; A > 0 -> NZ
	bit 7,a
	jr z,$+3
	xor a
	or a
	ret

/* value_check - IX = item (weapon or armour) -> A = 1 average, 2 good,
	3 excellent, 4 special, 5 worthless, 6 terrible; Z if nothing */
value_check:
	call unfelt
	ret z
	ld a,(ix+I_FEEL)					; (already inscribed)
	or a
	jr nz,.none
	call arms
	ret z
	bit ID_CURSED_BIT,(ix+I_IDENT)
	jr z,.blessed
	ld a,(ix+I_NAME2)
	or a
	ld a,5
	jr z,.yes
	inc a
	jr .yes
.blessed:
	ld a,(ix+I_NAME2)
	or a
	jr z,.plain
	call ego_addr						; an ego: excellent; an artifact:
	bit EO_ARTIFACT,(iy+E_OPTS)			; special
	ld a,3
	jr z,.yes
	inc a
	jr .yes
.plain:
	ld a,(ix+I_TOHIT)
	or (ix+I_TODAM)
	or (ix+I_TOAC)
	jr z,.average
	bit 7,(ix+I_TOHIT)					; any plus above 0: good
	jr z,.has_plus
	bit 7,(ix+I_TODAM)
	jr z,.has_plus
	bit 7,(ix+I_TOAC)
	jr z,.has_plus
.average:
	ld a,1
	jr .yes
.has_plus:
	ld a,(ix+I_TOHIT)
	call special_check.plus
	jr nz,.good
	ld a,(ix+I_TODAM)
	call special_check.plus
	jr nz,.good
	ld a,(ix+I_TOAC)
	call special_check.plus
	jr z,.average
.good:
	ld a,2
.yes:
	or a
	ret
.none:
	xor a
	ret

/* unfelt - IX = item -> Z if there's nothing left to sense: known2,
	store bought, or already felt blessed or cursed */
unfelt:
	ld a,(ix+I_IDENT)
	and 1<<ID_KNOWN2_BIT|1<<ID_STORE_BIT|1<<ID_MAGIK_BIT|1<<ID_DAMD_BIT
	jr nz,.nothing
	or 1
	ret
.nothing:
	xor a
	ret

/* arms - IX = item -> NZ if it's a weapon or armour */
arms:
	call item_kind_addr
	ld a,(iy+K_CLASS)
	cp IC_AMULET						; (not rings and amulets)
	jr nc,.no
	cp IC_WEAPON
	jr c,.no
	or 1
	ret
.no:
	xor a
	ret

/* add_use - (fl_i): "carrying in your pack", "wielding"... */
add_use:
	ld a,(fl_i)
	sub PACK_MAX
	jr nc,$+4
	ld a,EQ_MAX							; (the pack)
	add a,a
	ld hl,use_words
	add hl,a
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	jp msg_add

/* add_plural - HL = a kind's name: added with '~' as 's' */
add_plural:
	ld de,(msg_ptr)
.copy:
	ld a,(hl)
	inc hl
	or a
	jr z,.done
	cp '~'
	jr nz,$+4
	ld a,'s'
	ld (de),a
	inc de
	jr .copy
.done:
	ld (msg_ptr),de
	ret

use_words:		dw txt_u_wield, txt_u_body, txt_u_arm, txt_u_head, txt_u_about
				dw txt_u_hands, txt_u_feet, txt_u_pack, txt_u_pack, txt_u_pack
				dw txt_u_pack, txt_u_pack, txt_u_pack
value_words:	dw txt_average_f, txt_good_f, txt_excellent_f, txt_special_f
				dw txt_worthless, txt_terrible
txt_somethings:	db "There's something ",0
txt_feel_good:	db "good",0
txt_feel_bad:	db "bad",0
txt_about_what:	db " about what you are ",0
txt_dots:		db "...",0
txt_you_feel_the: db "You feel the ",0
txt_is_:		db " is ",0
txt_you_are_:	db " you are ",0
txt_are_:		db " are ",0
txt_u_wield:	db "wielding",0
txt_u_body:		db "wearing on your body",0
txt_u_arm:		db "wearing on your arm",0
txt_u_head:		db "wearing on your head",0
txt_u_about:	db "wearing about your body",0
txt_u_hands:	db "wearing on your hands",0
txt_u_feet:		db "wearing on your feet",0
txt_u_pack:		db "carrying in your pack",0
txt_average_f:	db "average",0
txt_good_f:		db "good",0
txt_excellent_f: db "excellent",0
txt_special_f:	db "special",0
txt_worthless:	db "worthless",0
txt_terrible:	db "terrible",0

/* rod_tick - rods in the pack recharge, a turn at a time */
rod_tick:
	xor a
.each:
	ld (rt_slot),a
	call pack_slot
	ld a,(ix+I_KIND_HI)
	cp ITEM_EMPTY
	ret z
	call item_kind_addr
	ld a,(iy+K_CLASS)
	cp IC_ROD
	jr nz,.next
	ld l,(ix+I_TIMEOUT)
	ld h,(ix+I_TIMEOUT+1)
	ld a,h
	or l
	jr z,.next
	dec hl
	ld (ix+I_TIMEOUT),l
	ld (ix+I_TIMEOUT+1),h
.next:
	ld a,(rt_slot)
	inc a
	cp PACK_MAX
	jr c,.each
	ret

/* status_effect - IX = (counter, status byte, bit mask, on, off): if it's
	running, set its status bit the first turn (calling on), count down, and
	at 0 clear it (calling off) */
status_effect:
	ld l,(ix+0)
	ld h,(ix+1)
	call get_w
	ret z
	ld l,(ix+2)
	ld h,(ix+3)
	ld a,(ix+4)
	and (hl)
	jr nz,.running
	ld a,(ix+4)
	or (hl)
	ld (hl),a
	ld l,(ix+5)
	ld h,(ix+6)
	push ix
	call jp_hl
	pop ix
.running:
	ld l,(ix+0)
	ld h,(ix+1)
	call dec_w
	ret nz
	ld l,(ix+2)
	ld h,(ix+3)
	ld a,(ix+4)
	cpl
	and (hl)
	ld (hl),a
	ld l,(ix+7)
	ld h,(ix+8)
jp_hl:
	jp (hl)

te_blind:		dw p_blind,p_status
				db 1<<PY_BLIND
				dw blind_on,blind_off
te_confused:	dw p_confused,p_status
				db 1<<PY_CONFUSED
				dw no_op,confused_off
te_fast:		dw p_fast,p_status
				db 1<<PY_FAST
				dw fast_on,fast_off
te_slow:		dw p_slow,p_status
				db 1<<PY_SLOW
				dw slow_on,slow_off
te_hero:		dw p_hero,p_status
				db 1<<PY_HERO
				dw hero_on,hero_off
te_shero:		dw p_shero,p_status
				db 1<<PY_SHERO
				dw shero_on,shero_off
te_blessed:		dw p_blessed,p_status+1
				db 1<<PY2_BLESSED
				dw blessed_on,blessed_off
te_det_inv:		dw p_detect_inv,p_status+1
				db 1<<PY2_DET_INV
				dw monsters_see_all,monsters_see_all
te_tim_infra:	dw p_tim_infra,p_status+1
				db 1<<PY2_TIM_INFRA
				dw monsters_see_all,monsters_see_all

blind_on:								; the map goes dark, monsters vanish
	call lamp_off
	jp monsters_see_all
blind_off:
	ld hl,msg_veil_lifts
	call msg_print
	call light_arrive
	jp monsters_see_all
confused_off:
	ld hl,msg_less_confused
	jp msg_print
fast_on:
	ld a,-1
	call change_speed
	ld hl,msg_faster
	jp msg_print
fast_off:
	ld a,1
	call change_speed
	ld hl,msg_slow_down
	jp msg_print
slow_on:
	ld a,1
	call change_speed
	ld hl,msg_slower
	jp msg_print
slow_off:
	ld a,-1
	call change_speed
	ld hl,msg_speed_up
	jp msg_print
hero_on:
	ld de,10
	ld hl,msg_hero
	jr heroic
shero_on:
	ld de,30
	ld hl,msg_killing
heroic:									; more hit points, now and at most
	push hl
	ld hl,(p_mhp)
	add hl,de
	ld (p_mhp),hl
	ld hl,(p_chp)
	add hl,de
	ld (p_chp),hl
	call bonus_update
	pop hl
	jp msg_print
hero_off:
	ld de,10
	ld hl,msg_heroism_off
	jr unheroic
shero_off:
	ld de,30
	ld hl,msg_less_berserk
unheroic:
	push hl
	ld hl,(p_mhp)
	or a
	sbc hl,de
	ld (p_mhp),hl
	ex de,hl							; DE = new maximum
	ld hl,(p_chp)
	or a
	sbc hl,de
	jr c,.fine
	jr z,.fine
	ld (p_chp),de
	ld hl,0
	ld (p_chp_frac),hl
.fine:
	call bonus_update
	pop hl
	jp msg_print
blessed_on:
	call bonus_update
	ld hl,msg_righteous
	jp msg_print
blessed_off:
	call bonus_update
	ld hl,msg_prayer_over
	jp msg_print
no_op:
	ret

/* count_down - HL = counter, DE = message when it runs out */
count_down:
	push de
	call get_w
	pop de
	ret z
	call dec_w
	ret nz
	ex de,hl
	jp msg_print

/* dec_w - HL = word: one less -> Z if now 0. Preserves HL */
dec_w:
	ld e,(hl)
	inc hl
	ld d,(hl)
	dec de
	ld (hl),d
	dec hl
	ld (hl),e
	ld a,d
	or e
	ret

/* art_tick - worn artifacts that activate recharge a turn; the One Ring
	takes a point of experience 1 turn in 20 ("Timeout Artifacts") */
art_tick:
	ld ix,EQUIP
	ld b,EQ_SLOTS
.each:
	push bc
	ld a,(ix+I_KIND_HI)
	cp ITEM_EMPTY
	jr z,.next
	call item_flags
	ld a,(it_flags+5)
	bit F2_ACTIVATE,a
	jr z,.next
	ld l,(ix+I_ATIME)
	ld h,(ix+I_ATIME+1)
	ld a,h
	or l
	jr z,.ring
	dec hl
	ld (ix+I_ATIME),l
	ld (ix+I_ATIME+1),h
.ring:
	ld hl,KIND_RING_POWER
	call item_is_kind
	jr nz,.next
	ld a,20
	call randint
	dec a
	jr nz,.next
	push ix
	ld hl,1
	ld e,h
	call lose_exp
	ld hl,p_max_exp						; (max too)
	ld a,(hl)
	sub 1
	ld (hl),a
	jr nc,.drained
	inc hl
	ld a,(hl)
	sub 1
	ld (hl),a
	jr nc,.drained
	inc hl
	dec (hl)
.drained:
	pop ix
.next:
	ld de,ITEM_SIZE
	add ix,de
	pop bc
	djnz .each
	ret

/* afraid_tick - heroes can't stay afraid */
afraid_tick:
	ld hl,p_afraid
	call get_w
	ret z
	ld hl,(p_hero)						; heroic?
	ld de,(p_shero)
	ld a,h
	or l
	or d
	or e
	ld b,a
	ld hl,p_status
	bit PY_FEAR,(hl)
	jr nz,.afraid
	ld a,b
	or a
	jr z,.scared
	ld hl,0								; (the C goes to -1: never afraid)
	ld (p_afraid),hl
	ret
.scared:
	set PY_FEAR,(hl)
	jr .count
.afraid:
	ld a,b
	or a
	jr z,.count
	ld hl,1
	ld (p_afraid),hl
.count:
	ld hl,p_afraid
	call dec_w
	ret nz
	ld hl,p_status
	res PY_FEAR,(hl)
	ld hl,msg_bolder
	jp msg_print

/* cut_tick - bleeding: hurts more the deeper the cut, heals by con */
cut_tick:
	ld hl,(p_cut)
	call positive
	ret z
	ld de,KILLER_WOUND
	ld (killer_race),de
	ld de,1001
	or a
	sbc hl,de
	jr c,.not_mortal
	ld hl,3								; a mortal wound doesn't close
	jp take_hit
.not_mortal:
	ld hl,(p_cut)
	ld de,201
	ld b,3
	or a
	sbc hl,de
	jr nc,.bleed
	ld hl,(p_cut)
	ld de,101
	dec b
	or a
	sbc hl,de
	jr nc,.bleed
	dec b
.bleed:
	ld l,b
	ld h,0
	call take_hit
	ld a,(p_con_adj)					; cut -= con_adj + 1
	inc a
	ld e,a
	rla
	sbc a,a
	ld d,a
	ld hl,(p_cut)
	or a
	sbc hl,de
	ld (p_cut),hl
	call positive
	ret nz
	ld hl,0
	ld (p_cut),hl
	ld hl,(p_chp)
	bit 7,h
	ret nz
	ld hl,msg_wound_heals
	jp msg_print

/* stun_tick - recovering: by con, at least 1 a turn */
stun_tick:
	ld hl,(p_stun)
	call positive
	ret z
	ld (st_old),hl
	ld a,(p_con_adj)					; con_adj <= 0: 1, else con_adj/2 + 1
	dec a
	bit 7,a
	ld a,1
	jr nz,.by
	ld a,(p_con_adj)
	srl a
	inc a
.by:
	ld e,a
	ld d,0
	ld hl,(p_stun)
	or a
	sbc hl,de
	ld (p_stun),hl
	ld de,51							; crossed below the heavy stun mark?
	ld hl,(st_old)
	or a
	sbc hl,de
	jr c,.light
	ld hl,(p_stun)
	bit 7,h
	jr nz,.crossed
	or a
	sbc hl,de
	jr nc,.light
.crossed:
	call bonus_update
.light:
	ld hl,(p_stun)
	call positive
	ret nz
	ld hl,0
	ld (p_stun),hl
	call bonus_update
	ld hl,msg_head_stops
	jp msg_print

/* poison_tick - poison hurts each turn, less for the hardy */
poison_tick:
	ld hl,p_poisoned
	call get_w
	ret z
	ld a,(p_status)
	set PY_POISONED,a
	ld (p_status),a
	call dec_w
	jr z,.cured
	ld a,(p_eflags+3)					; resisting it ends it
	bit EF3_POISON,a
	jr z,.hurt
	ld hl,0
	ld (p_poisoned),hl
.cured:
	ld hl,p_status
	res PY_POISONED,(hl)
	ld hl,msg_feel_better
	jp msg_print
.hurt:
	ld a,(p_con_adj)
	ld hl,poison_damage					; (con_adj, damage or turn modulus)
.find:
	cp (hl)
	jr z,.found
	bit 7,(hl)
	jr nz,.next							; negatives must match exactly
	jr c,.found							; first non-negative above it
.next:
	inc hl
	inc hl
	jr .find
.found:
	inc hl
	ld a,(hl)
	bit 7,a
	jr z,.damage
	and $7F								; 1 if turn % n == 0
	ld c,a
	ld hl,(game_turn)
	call mod16_8
	or a
	ld a,1
	jr z,.damage
	xor a
.damage:
	ld l,a
	ld h,0
	ld de,KILLER_POISON
	ld (killer_race),de
	jp take_hit

poison_damage:	db -4,4, -3,3, -2,3, -1,2, 0,1, 3,$82, 5,$83, 6,$84, 7,$85, 127,$86

/* recall_tick - word of recall fires when its counter reaches 1 */
recall_tick:
	ld hl,p_word_recall
	call get_w
	ret z
	ld a,d
	or a
	jr nz,.wait
	ld a,e
	cp 1
	jr nz,.wait
	ld de,0
	call set_w
	ld hl,p_paralysed
	inc (hl)
	ld a,1								; up to town
	ld (p_new_level),a
	ld a,(dun_level)
	or a
	jr z,.down
	xor a
	ld (dun_level),a
	ret
.down:
	ld a,3								; (a new town, nothing said)
	ld (p_new_level),a
	ld a,(p_max_dlv)
	or a
	ret z
	ld (dun_level),a
	ld a,2
	ld (p_new_level),a
	ret
.wait:
	jp dec_w

msg_veil_lifts:		db "The veil of darkness lifts.",0
msg_less_confused:	db "You feel less confused now.",0
msg_bolder:			db "You feel bolder now.",0
msg_wound_heals:	db "Your wound heals.",0
msg_feel_better:	db "You feel better.",0
msg_faster:			db "You feel yourself moving faster.",0
msg_slow_down:		db "You feel yourself slow down.",0
msg_slower:			db "You feel yourself moving slower.",0
msg_speed_up:		db "You feel yourself speed up.",0
msg_no_protevil:	db "You no longer feel safe from evil.",0
msg_hero:			db "You feel like a HERO!",0
msg_heroism_off:	db "The heroism wears off.",0
msg_killing:		db "You feel like a killing machine!",0
msg_less_berserk:	db "You feel less Berserk.",0
msg_righteous:		db "You feel righteous!",0
msg_prayer_over:	db "The prayer has expired.",0
msg_no_res_heat:	db "You no longer feel safe from flame.",0
msg_no_res_cold:	db "You no longer feel safe from cold.",0

rt_slot:		db 0
fl_i:			db 0
fl_good:		db 0
fl_mul:			db 0
st_old:			dw 0
