/* effects.asm - timed effects wearing off, once a turn  [overlay: PAGE_MAGIC]
	Reference: DUNGEON.C dungeon() (the block after food and regeneration),
	MORIA1.C change_speed.
	Effects with a PY_ status bit announce themselves the turn they start;
	all of them count down and say so when they end.
 */

/* timed_tick - one turn of every timed effect, in the C's order */
timed_tick:
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
	jp recall_tick

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

/* change_speed - A = change: the player's speed, and with it every
	monster's speed relative to the player (MORIA1.C) */
change_speed:
	ld (cs_num),a
	ld hl,p_speed
	add a,(hl)
	ld (hl),a
	ld ix,MON_LIST
	ld b,MON_MAX
	ld de,MON_SIZE
.each:
	ld a,(ix+M_RACE_HI)
	cp MON_EMPTY
	jr z,.next
	ld a,(cs_num)
	add a,(ix+M_SPEED)
	ld (ix+M_SPEED),a
.next:
	add ix,de
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
	jr nz,.hurt
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

cs_num:			db 0
st_old:			dw 0
