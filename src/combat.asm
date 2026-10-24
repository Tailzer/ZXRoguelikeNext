/* combat.asm - the player, fighting, experience and death
	References: MORIA1.C test_hit/take_hit, MORIA2.C py_attack/
	mon_take_hit, CREATURE.C make_attack, MISC2.C critical_blow/
	prt_experience/gain_level, DUNGEON.C regenhp, PLAYER.C tables.

	The character comes from create.asm: race and class give the base
	to-hit, hit die and so on; stats give bonuses; armour class, to-hit,
	weapon dice and blows then come from what is worn and wielded
	(calc_bonuses in inventory.asm).
 */

BTH_PLUS_ADJ		equ 3
MAX_PLAYER_LEVEL	equ 50
REGEN_HPBASE		equ 1442			; PLAYER_REGEN_HPBASE

/* test_hit - HL = bth + pth*3 + level*adj (signed), A = target AC.
	-> carry if it hits. 1 in 20 always misses, 1 in 20 always hits */
test_hit:
	ld (th_ac),a
	push hl
	ld a,20
	call randint
	pop hl
	cp 1
	jr z,.miss
	cp 20
	jr z,.hit
	bit 7,h
	jr nz,.miss
	ld a,h
	or l
	jr z,.miss
	call randint16
	ld a,(th_ac)						; hit if 1d(i) > 3*ac/4
	ld e,a
	ld d,3
	mul d,e
	srl d
	rr e
	srl d
	rr e
	or a
	sbc hl,de
	jr z,.miss
	jr c,.miss
.hit:
	scf
	ret
.miss:
	or a
	ret

/* randint16 - HL = n (1-65535) -> HL = random 1..n. Clobbers A, DE */
randint16:
	ld (ri_n),hl
	dec hl
	ex de,hl
	ld hl,0								; mask covering n-1
.mask:
	ld a,d
	or e
	jr z,.try
	srl d
	rr e
	add hl,hl
	inc hl
	jr .mask
.try:
	ld (ri_mask),hl
.again:
	call rand16
	ld a,(ri_mask)
	and l
	ld l,a
	ld a,(ri_mask+1)
	and h
	ld h,a
	ld de,(ri_n)
	or a
	sbc hl,de
	jr nc,.again						; reject values >= n
	add hl,de
	inc hl
	ret

/* take_hit - HL = damage, killer_race = what did it. Sets p_dead when
	hit points drop below zero (0 hp is still alive, as in the C) */
take_hit:
	ex de,hl
	ld hl,(p_invuln)					; invulnerable: nothing hurts
	ld a,h
	or l
	jr z,$+5
	ld de,0
	ld hl,(p_chp)
	or a
	sbc hl,de
	ld (p_chp),hl
	bit 7,h
	ret z
	ld a,1
	ld (p_dead),a
	ret

/* regenhp - A = regen amount (197 normally, less when hungry). Heals
	(mhp * amount + 1442) / 65536 hit points */
regenhp:
	or a
	ret z								; starving: no healing
	ld (regen_amount),a
	ld hl,(p_chp)
	ld de,(p_mhp)
	or a
	sbc hl,de
	ret nc								; already full
	ld a,(regen_amount)					; A:HL = mhp * amount + 1442
	call .times_mhp
	ld b,a
	ld a,(p_eflags+1)					; regeneration: amount * 3 / 2
	bit EF1_REGEN,a
	ld a,b
	jr z,.base
	push hl
	push af
	ld a,(regen_amount)
	srl a
	call .times_mhp
	pop bc
	pop de
	add hl,de
	adc a,b
.base:
	ld de,REGEN_HPBASE
	add hl,de
	adc a,0
	ld de,(p_chp_frac)
	add hl,de
	adc a,0
	ld (p_chp_frac),hl
	ld hl,(p_chp)
	add hl,a
	ld (p_chp),hl
	ld de,(p_mhp)						; cap at max
	or a
	sbc hl,de
	ret c
	ld (p_chp),de
	ld hl,0
	ld (p_chp_frac),hl
	ret
.times_mhp:								; A = amount -> A:HL = mhp * amount
	ld (regen_amount+1),a
	ld e,a
	ld a,(p_mhp)
	ld d,a
	mul d,e
	push de
	ld a,(regen_amount+1)
	ld e,a
	ld a,(p_mhp+1)
	ld d,a
	mul d,e								; high byte product, shifted 8
	pop hl
	ld a,h
	add a,e
	ld h,a
	ld a,0
	adc a,d
	ret

/* mon_name_to_msg - add "The <name>" / "It" (cap=1) or "the <name>" /
	"it" (cap=0) for monster IX to the message being built. IY = race */
mon_name_to_msg:
	ld a,(ix+M_ML)
	or a
	jr z,.unseen
	bit RF_UNIQUE,(iy+R_FLAGS)			; uniques go by name alone
	jr nz,.name
	ld a,(name_cap)
	or a
	ld hl,txt_the
	jr nz,$+5
	ld hl,txt_the_lc
	call msg_add
.name:
	call race_name
	jp msg_add
.unseen:
	ld a,(name_cap)
	or a
	ld hl,txt_it
	jr nz,$+5
	ld hl,txt_it_lc
	jp msg_add

/* py_attack - the player attacks monster IX (py_attack in MORIA2.C) */
py_attack:
	ld a,1
	ld (turn_taken),a
	ld (ix+M_SLEEP),0					; it wakes up
	ld (ix+M_SLEEP+1),0
	call mon_race
	; base to-hit: bth if we can see it, otherwise
	; bth/2 - tohit*(BTH_PLUS_ADJ-1) - lev*adj/2
	ld a,(p_bth)
	ld l,a
	ld h,0
	ld a,(ix+M_ML)
	or a
	jr nz,.seen
	srl l								; bth/2
	call tohit_word
	ex de,hl
	add hl,hl							; *2
	ex de,hl
	or a
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
	call tohit_word						; i = base + tohit*3 + lev*4
	add hl,de
	add hl,de
	add hl,de
	ld a,(p_cla_bth)
	ld e,a
	ld a,(p_lev)
	ld d,a
	mul d,e
	add hl,de
	ld (attack_skill),hl
	ld a,(p_blows)
	ld (blows_left),a
.blow:
	ld hl,(attack_skill)
	ld a,(iy+R_AC)
	call test_hit
	jr nc,.miss
	ld a,(w_dice)						; damage: weapon dice, maybe a critical
	ld b,a
	ld a,(w_sides)
	ld c,a
	call damroll
	call tot_dam
	call critical_blow
	ld a,(p_todam)
	ld e,a
	rla
	sbc a,a
	ld d,a
	add hl,de
	bit 7,h
	jr z,$+5
	ld hl,0
	ld (hit_damage),hl
	call msg_begin
	ld hl,txt_you_hit
	call msg_add
	xor a
	ld (name_cap),a
	call mon_name_to_msg
	ld hl,txt_full_stop
	call msg_add
	call msg_end
	call confuse_touch					; Monster Confusion's glowing hands
	ld hl,(hit_damage)
	call mon_take_hit
	ret c								; it died: no more blows
	jr .next_blow
.miss:
	call msg_begin
	ld hl,txt_you_miss
	call msg_add
	xor a
	ld (name_cap),a
	call mon_name_to_msg
	ld hl,txt_full_stop
	call msg_add
	call msg_end
.next_blow:
	ld hl,blows_left
	dec (hl)
	jr nz,.blow
	ret

/* tot_dam - HL = damage, IY = the monster's race -> HL = damage after the
	weapon's slays and brands, the first that applies (tot_dam in MISC2.C).
	Preserves IX, IY */
tot_dam:
	ld de,(w_slays)
	ld a,d
	or e
	ret z
	ld a,(iy+R_FLAGS)					; what the race is, and isn't
	ld (td_race),a						; immune to
	ld a,(iy+R_FLAGS2)
	ld (td_race+1),a
	ld a,(iy+R_RESIST)
	cpl
	ld (td_race+2),a
	ld (td_dam),hl
	ld hl,slay_table
	ld b,NUM_SLAYS
.each:
	srl d
	rr e
	jr nc,.next
	push de
	ld a,(hl)
	ld de,td_race
	add de,a
	ld a,(de)
	inc hl
	and (hl)
	dec hl
	pop de
	jr z,.next
	inc hl								; it applies: times the multiplier
	inc hl
	ld b,(hl)
	ld hl,0
	ld de,(td_dam)
.times:
	add hl,de
	djnz .times
	ret
.next:
	inc hl
	inc hl
	inc hl
	djnz .each
	ld hl,(td_dam)
	ret

; in w_slays bit order: which td_race byte (0 flags, 1 flags2, 2 not
; immune), the bit, how many times the damage
slay_table:
	db 2,1<<RR_LIGHTNING,5				; lightning brand
	db 1,1<<RF2_DRAGON,5				; execute dragon
	db 1,1<<RF2_DRAGON,3				; slay dragon
	db 0,1<<RF_UNDEAD,3
	db 1,1<<RF2_ORC,3
	db 1,1<<RF2_TROLL,3
	db 1,1<<RF2_GIANT,3
	db 0,1<<RF_DEMON,3
	db 2,1<<RR_FROST,3					; frost brand
	db 2,1<<RR_FIRE,3					; flame tongue
	db 0,1<<RF_EVIL,2
	db 1,1<<RF2_ANIMAL,2
NUM_SLAYS		equ ($-slay_table)/3

/* tohit_word - DE = p_tohit sign-extended. Preserves HL */
tohit_word:
	ld a,(p_tohit)
	ld e,a
	rla
	sbc a,a
	ld d,a
	ret

/* critical_blow - HL = damage -> HL = damage after a possible critical.
	Chance: 1d5000 <= weight + 5*tohit + lev*4 */
critical_blow:
	ld (crit_dam),hl
	ld hl,5000
	call randint16
	ex de,hl
	push de								; chance = weight + 5*tohit + lev*adj
	ld a,(p_cla_bth)
	ld e,a
	ld a,(p_lev)
	ld d,a
	mul d,e
	ld hl,(w_weight)
	add hl,de
	call tohit_word
	ld b,5
.plus:
	add hl,de
	djnz .plus
	bit 7,h								; (a chance below 0: never, as the
	jr z,$+5							; C's signed compare)
	ld hl,0
	pop de
	or a
	sbc hl,de							; chance - roll
	ld hl,(crit_dam)
	ret c
	ld hl,650							; how good: weight + 1d650
	call randint16
	ld de,(w_weight)
	add hl,de
	ld de,400
	or a
	sbc hl,de							; HL = weight - 400
	ld de,txt_good_hit
	ld bc,5*256+2						; < 400: 2*dam + 5
	jr c,.apply
	ld de,300
	sbc hl,de							; carry is clear here
	ld de,txt_excellent_hit
	ld bc,10*256+2						; < 700: 2*dam + 10
	jr c,.apply
	ld de,200
	sbc hl,de
	ld de,txt_superb_hit
	ld bc,15*256+3						; < 900: 3*dam + 15
	jr c,.apply
	ld de,txt_great_hit
	ld bc,20*256+3						; else 3*dam + 20
.apply:
	push bc
	ex de,hl
	call msg_print
	pop bc
	ld hl,0								; HL = dam * C + B
	ld de,(crit_dam)
.times:
	add hl,de
	dec c
	jr nz,.times
	ld a,b
	add hl,a
	ret

/* mon_take_hit - IX = monster, HL = damage. Kills it if hp drops below 0,
	awarding experience (mon_take_hit in MORIA2.C) */
mon_take_hit:
	ex de,hl
	ld l,(ix+M_HP)
	ld h,(ix+M_HP+1)
	or a
	sbc hl,de
	ld (ix+M_HP),l
	ld (ix+M_HP+1),h
	bit 7,h
	jr nz,.dead
	or a								; still alive: carry clear
	ret
.dead:									; experience: mexp * level / plev,
	call mon_race						; the remainder kept as a fraction
	ld e,(iy+R_LEVEL)
	ld d,(iy+R_EXP)
	mul d,e
	push de
	ld e,(iy+R_LEVEL)
	ld d,(iy+R_EXP+1)
	mul d,e								; high byte's product, shifted 8
	pop hl
	ld a,h
	add a,e
	ld h,a
	ld a,d
	adc a,0
	ld e,a								; E:HL = mexp * level
	ld a,(p_lev)
	ld c,a
	call div24_8						; E:HL = whole exp, A = remainder
	push hl
	push de
	ld e,a								; frac += remainder * 65536 / plev
	ld hl,0
	call div24_8
	ld de,(p_exp_frac)
	add hl,de
	ld (p_exp_frac),hl
	pop de
	pop hl
	ld bc,0								; + 1 if the fraction overflowed
	adc hl,bc
	ld a,e
	adc a,0
	ld e,a
	ld bc,(p_exp)						; p_exp += E:HL
	add hl,bc
	ld (p_exp),hl
	ld hl,(p_exp+2)
	ld d,0
	adc hl,de
	ld (p_exp+2),hl
	bit RF_UNIQUE,(iy+R_FLAGS)			; a unique stays dead
	call nz,unique_killed
	; message, then remove it
	ld a,(mth_quiet)					; (dispel undead says its own)
	or a
	jr nz,.quiet
	call msg_begin
	ld hl,txt_you_slain					; undead and demons are destroyed
	ld a,(iy+R_FLAGS)
	and 1<<RF_UNDEAD|1<<RF_DEMON
	jr z,$+5
	ld hl,txt_you_destroyed
	call msg_add
	xor a
	ld (name_cap),a
	call mon_name_to_msg
	ld hl,txt_full_stop
	call msg_add
	call msg_end
.quiet:
	call mon_remove
	call check_level_up
	scf									; it died
	ret

/* mon_remove - IX = monster to take off the map and out of the list */
mon_remove:
	ld d,(ix+M_Y)
	ld e,(ix+M_X)
	call map_addr
	res F_MON_BIT,(hl)
	ld (ix+M_RACE_HI),MON_EMPTY
	ret

/* unique_killed - IX = a unique monster that died: mark its race dead */
unique_killed:
	call unique_bit
	or (hl)
	ld (hl),a
	ret

/* unique_bit - IX = monster -> HL = byte in uniques_dead, A = its bit */
unique_bit:
	ld l,(ix+M_RACE)
	ld h,(ix+M_RACE_HI)
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
	ld a,1
	inc b
.shift:
	dec b
	ret z
	add a,a
	jr .shift

/* check_level_up - gain levels while exp >= player_exp[lev-1] scaled by
	the race and class experience factor, and keep max_exp up to date
	(prt_experience in MISC2.C) */
check_level_up:
	call .levels
	jp update_max_exp
.levels:
	ld a,(p_lev)
	cp MAX_PLAYER_LEVEL
	ret nc
	dec a
	add a,a
	add a,a
	ld hl,P_EXP_TABLE+3					; compare high bytes first
	add hl,a
	ld de,p_exp+3
	ld b,4
.cmp:
	ld a,(de)
	cp (hl)
	ret c								; exp < needed
	jr nz,.gain							; exp > needed
	dec hl
	dec de
	djnz .cmp
.gain:
	ld hl,p_lev
	inc (hl)
	ld hl,p_update						; (spells and mana: update_stuff)
	set PU_BONUS,(hl)
	call calc_hitpoints					; current hp rise in proportion
	call msg_begin
	ld hl,txt_welcome_level
	call msg_add
	ld a,(p_lev)
	call msg_add_u8
	ld hl,txt_full_stop
	call msg_add
	call msg_end
	jr .levels

/* mon_attack - monster IX (race IY) attacks the player with each of its
	blows (make_attack in CREATURE.C; what each blow does is in the monster
	spell overlay, mmelee.asm) */
mon_attack:
	xor a
	ld (attack_num),a
.blow:
	ld a,(ix+M_RACE)					; (an earthquake may have changed it)
	ld (killer_race),a
	ld a,(ix+M_RACE_HI)
	ld (killer_race+1),a
	ld a,(p_dead)
	or a
	ret nz
	ld a,(attack_num)
	cp 4
	ret nc
	add a,a
	add a,a
	add a,R_ATTACKS
	ld e,a
	ld d,0
	push iy
	pop hl
	add hl,de
	ld a,(hl)							; type, 0 = no more blows
	or a
	ret z
	cp 26
	ret nc								; (no blow types above 25 in the data)
	ld (atk_type),a
	inc hl
	ld a,(hl)
	ld (atk_desc),a
	inc hl
	ld a,(hl)
	ld (atk_dice),a
	inc hl
	ld a,(hl)
	ld (atk_sides),a
	ld hl,attack_num
	inc (hl)
	ld hl,(p_protevil)					; protection from evil may repel it
	ld a,h
	or l
	jr z,.unprotected
	bit RF_EVIL,(iy+R_FLAGS)
	jr z,.unprotected
	ld a,(p_lev)
	cp (iy+R_LEVEL)						; lev + 1 > level
	jr c,.unprotected
	ld a,100
	call randint
	ld hl,p_lev
	add a,(hl)
	jr c,.repelled
	cp 51
	jr c,.unprotected
.repelled:
	call msg_begin						; "The Orc is repelled."
	ld a,1
	ld (name_cap),a
	call mon_name_to_msg
	ld hl,txt_repelled
	call msg_add
	call msg_end
	jr .blow
.unprotected:
	FARCALL PAGE_MCAST, melee_hits
	jr nc,.missed
	FARCALL PAGE_MCAST, melee_blow		; said and done -> carry if it left
	push af
	call mon_race
	ld hl,(p_protevil)					; touching glowing hands confuses
	ld a,h								; it too (unless repelling evil)
	or l
	call z,confuse_touch
	pop af
	ret c
	jp .blow
.missed:
	ld a,(atk_desc)						; only hits/bites/claws/kicks say so
	cp 4
	jr c,.say_miss
	cp 6
	jp nz,.blow
.say_miss:
	call msg_begin
	ld a,1
	ld (name_cap),a
	call mon_name_to_msg
	ld hl,txt_misses_you
	call msg_add
	call msg_end
	jp .blow

/* confuse_touch - IX = monster the player hit, or that hit the player:
	if their hands glow (Monster Confusion), it may become confused */
confuse_touch:
	ld a,(p_confuse_mon)
	or a
	ret z
	xor a
	ld (p_confuse_mon),a
	ld hl,msg_hands_stop
	call msg_print
	call msg_begin
	ld a,1
	ld (name_cap),a
	call mon_race
	call mon_name_to_msg
	bit RF_CHARM_SLEEP,(iy+R_FLAGS)
	jr nz,.unaffected
	ld a,MAX_MONS_LEVEL
	call randint
	cp (iy+R_LEVEL)
	jr c,.unaffected
	ld (ix+M_CONFUSED),1
	ld hl,txt_appears_confused
	jr .say
.unaffected:
	ld hl,txt_is_unaffected
.say:
	call msg_add
	jp msg_end

/* div16_8 - HL / C -> HL = quotient, A = remainder. Clobbers B */
div16_8:
	xor a
	ld b,16
.loop:
	add hl,hl
	rla
	jr c,.sub
	cp c
	jr c,.next
.sub:
	sub c
	inc l
.next:
	djnz .loop
	ret

/* div24_8 - E:HL / C -> E:HL = quotient, A = remainder. Clobbers B */
div24_8:
	xor a
	ld b,24
.loop:
	add hl,hl
	rl e
	rla
	jr c,.sub
	cp c
	jr c,.next
.sub:
	sub c
	inc l
.next:
	djnz .loop
	ret


; player
p_lev:			db 1
p_exp:			dd 0
p_exp_frac:		dw 0
p_mhp:			dw 0
p_chp:			dw 0				; signed: below 0 is dead
p_chp_frac:		dw 0
p_dead:			db 0
killer_race:	dw 0				; race, or KILLER_STARVATION
p_food:			dw 0				; signed
p_hunger:		db 0				; HUNGER_ state
p_paralysed:	db 0				; turns left fainted
p_gold:			dd 0
; who the character is (create.asm)
p_name:			ds 24
p_race:			db 0
p_class:		db 0
p_male:			db 1
p_stat:			ds 6				; STR INT WIS DEX CON CHR, 18/xx as 18+xx
p_age:			db 0
p_ht:			db 0
p_wt:			dw 0
p_hitdie:		db 0
p_bth:			db 0				; base to-hit, race + class
p_cla_bth:		db 0				; class_level_adj[class][CLA_BTH]
p_cla_dev:		db 0				; class_level_adj[class][CLA_DEVICE]
p_cla_save:		db 0				; class_level_adj[class][CLA_SAVE]
p_save:			db 0				; saving throw, race + class (signed)
p_int_adj:		db 0				; stat_adj(A_INT)
p_stl:			db 0				; stealth (signed), with equipment's
p_stl_race:		db 0				; the race's and class's
p_srh:			db 0				; searching skill (srh), with equipment's
p_srh_race:		db 0				; the race's and class's
p_fos:			db 0				; searching frequency (signed: lower, more)
p_fos_race:		db 0				; the race's and class's
p_dis:			db 0				; disarming skill, race + class
p_cla_dis:		db 0				; class_level_adj[class][CLA_DISARM]
p_bthb:			db 0				; missile skill, race + class
p_cla_bthb:		db 0				; class_level_adj[class][CLA_BTHB]
step_from:		dw 0				; where the last step came from (x, y)
p_infra:		db 0				; infravision, in 10 ft, with equipment's
p_infra_race:	db 0				; the race's
p_expfact:		db 100
p_notice:		dw 0				; highest 1d1024 roll monsters notice
p_stat_tohit:	db 0				; from DEX and STR (signed)
p_stat_todam:	db 0				; from STR
p_stat_toac:	db 0				; from DEX
p_con_adj:		db 0				; hit points per level from CON
p_dex_index:	db 0				; DEX column of blows_table
p_kit:			ds 10				; starting kinds, words ($FFFF = none)
; from equipment (calc_bonuses)
p_ac:			db 0
p_tohit:		db 0				; signed
p_todam:		db 0				; signed
p_blows:		db 1
w_dice:			db 1
w_sides:		db 1
w_weight:		dw 0
w_slays:		dw 0				; the weapon's slays and brands (slay_table)
td_race:		ds 3
td_dam:			dw 0
; scratch
th_ac:			db 0
ri_n:			dw 0
ri_mask:		dw 0
name_cap:		db 0
hit_damage:		dw 0
crit_dam:		dw 0
regen_amount:	db 0,0
attack_skill:	dw 0
blows_left:		db 0
attack_num:		db 0
atk_type:		db 0
atk_desc:		db 0
atk_dice:		db 0
atk_sides:		db 0
atk_damage:		dw 0
mth_quiet:		db 0				; mon_take_hit: no "You have slain"
msg_hands_stop:	db "Your hands stop glowing.",0
txt_appears_confused: db " appears confused.",0
txt_is_unaffected: db " is unaffected.",0
txt_repelled:	db " is repelled.",0
