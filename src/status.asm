/* status.asm - stats, timed effects and what follows from them  [resident]
	References: MISC2.C tohit_adj/todam_adj/toac_adj/con_adj/calc_hitpoints/
	prt_experience, DESC.C known1/known1_p/sample/identify.
	The timed effects themselves tick in effects.asm (PAGE_MAGIC); code in an
	overlay that changes stats or bonuses sets p_update, and the main loop
	does the recalculating here, where it can reach every overlay.
 */

/* update_stuff - redo whatever p_update asks for */
update_stuff:
	ld a,(p_update)
	or a
	ret z
	ld b,a
	xor a
	ld (p_update),a
	bit PU_BONUS,b
	jr z,.hp
	push bc
	FARCALL PAGE_ITEMS, calc_bonuses	; (works out the stat bonuses first)
	pop bc
.hp:
	bit PU_HP,b
	push bc
	call nz,calc_hitpoints
	pop bc
	ld hl,p_update						; spells and mana, after the bonuses
	ld a,(hl)
	or b
	bit PU_SPELLS,a
	ret z
	res PU_SPELLS,(hl)
	FARCALL PAGE_SPELL, update_spells
	ret

/* pending_actions - an item command chose something the magic overlay
	carries out (the C does both in one function) */
pending_actions:
	ld a,(pending_magic)
	or a
	ret z
	ld b,a
	xor a
	ld (pending_magic),a
	ld a,b
	cp PM_READ
	ld a,(pending_arg)
	jr z,.read
	jr nc,.device
	FARCALL PAGE_MAGIC, magic_action	; B = action, A = argument
	ret
.read:
	FARCALL PAGE_SCROLL, read_scroll
	ret
.device:
	FARCALL PAGE_DEVICE, device_action	; B = action, A = slot
	ret

/* device_xcall - B = an overlay, xc_target = a routine in it: called from
	the device overlay, which is paged back in afterwards. A, HL, DE and
	flags pass through (staffs and rods share scroll and potion effects) */
device_xcall:
	push af
	ld a,b
	nextreg NR_MMU2,a
	pop af
	call .go
	nextreg NR_MMU2,PAGE_DEVICE
	ret
.go:
	push hl
	ld hl,(xc_target)
	ex (sp),hl
	ret

/* overlay_call - B = an overlay, xc_target = a routine in it, C = the
	overlay to page back afterwards (OVCALL): one overlay borrowing another's
	routine. A, HL, DE, IX, IY and flags pass through */
overlay_call:
	push af
	ld a,b
	nextreg NR_MMU2,a
	pop af
	push bc
	call device_xcall.go
	pop bc
	push af
	ld a,c
	nextreg NR_MMU2,a
	pop af
	ret

/* random_teleport - a ring or amulet of teleportation: 1 in 100 each turn,
	teleport(40) (DUNGEON.C) */
random_teleport:
	ld a,100
	call randint
	dec a
	ret nz
	ld hl,40
	FARCALL PAGE_SCROLL, teleport
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

/* level_call - HL = a routine in the level overlay, called from the scroll
	overlay, which is paged back in afterwards (flags come back) */
level_call:
	nextreg NR_MMU2,PAGE_LEVEL
	call .go
	nextreg NR_MMU2,PAGE_SCROLL
	ret
.go:
	jp (hl)

/* stat_bonuses - the stats in use (the current ones as equipment
	modifies them: set_use_stat), then to-hit, to-dam, to-ac, hit points
	per level and the blows column from them (MISC2.C's *_adj functions) */
stat_bonuses:
	ld b,0
.use:
	ld hl,p_stat_mod					; modify_stat(cur, mod)
	ld a,b
	add hl,a
	ld a,(hl)
	ld hl,p_stat
	push af
	ld a,b
	add hl,a
	pop af
	ld c,(hl)
	push bc
	or a
	jr z,.store
	ld b,a
	bit 7,a
	jr nz,.down
.up:									; up: one point to 18, then 10
	ld a,c
	cp 18
	jr nc,.up10
	inc c
	jr .up_next
.up10:
	add a,10
	jr nc,$+4
	ld a,255
	ld c,a
.up_next:
	djnz .up
	jr .store
.down:									; down: 10 at a time to 18/10,
	ld a,b								; then 18, then one point to 3
	neg
	ld b,a
.down_one:
	ld a,c
	cp 28
	jr c,.to18
	sub 10
	ld c,a
	jr .down_next
.to18:
	cp 19
	jr c,.to3
	ld c,18
	jr .down_next
.to3:
	cp 4
	jr c,.down_next
	dec c
.down_next:
	djnz .down_one
.store:
	ld a,c
	pop bc
	ld hl,p_stat_use
	push af
	ld a,b
	add hl,a
	pop af
	ld (hl),a
	inc b
	ld a,b
	cp 6
	jr c,.use
	ld a,(p_stat_use+A_DEX)
	ld hl,dex_tohit
	call threshold
	ld b,a
	ld a,(p_stat_use+A_STR)
	ld hl,str_tohit
	push bc
	call threshold
	pop bc
	add a,b
	ld (p_stat_tohit),a
	ld a,(p_stat_use+A_STR)
	ld hl,str_todam
	call threshold
	ld (p_stat_todam),a
	ld a,(p_stat_use+A_DEX)
	ld hl,dex_toac
	call threshold
	ld (p_stat_toac),a
	ld a,(p_stat_use+A_CON)
	ld hl,con_hp
	call threshold
	ld (p_con_adj),a
	ld a,(p_stat_use+A_DEX)
	ld hl,dex_blows
	call threshold
	ld (p_dex_index),a
	ld a,(p_stat_use+A_INT)
	ld hl,int_adj
	call threshold
	ld (p_int_adj),a
	ret

/* threshold - A = stat, HL = table of (limit, value) pairs ending with
	limit 255 -> A = the value of the first pair whose limit is above it */
threshold:
	cp (hl)
	jr c,.found
	inc hl
	inc hl
	jr threshold
.found:
	inc hl
	ld a,(hl)
	ret

; MISC2.C's stat adjustments as (stat below this, value) pairs
; (18/xx is stored as 18 + xx, so 18/100 = 118)
dex_tohit:	db 4,-3, 6,-2, 8,-1, 16,0, 17,1, 18,2, 69,3, 118,4, 119,5, 128,6
			db 138,7, 148,8, 158,9, 168,10, 178,11, 188,12, 198,13, 218,14, 228,15, 255,17
str_tohit:	db 4,-3, 5,-2, 7,-1, 18,0, 94,1, 109,2, 117,3, 119,4, 128,5, 138,6
			db 148,7, 158,8, 168,9, 178,10, 188,11, 198,12, 218,13, 228,14, 255,16
str_todam:	db 4,-2, 5,-1, 16,0, 17,1, 18,2, 94,3, 109,4, 119,5, 128,6, 138,7
			db 148,8, 158,9, 168,10, 178,11, 188,12, 198,13, 218,14, 228,16, 255,20
dex_toac:	db 4,-4, 5,-3, 6,-2, 7,-1, 15,0, 18,1, 59,2, 94,3, 117,4, 119,5
			db 128,6, 138,7, 148,8, 158,9, 168,10, 178,11, 188,12, 198,13, 218,14, 228,15, 255,17
con_hp:		db 4,-4, 5,-3, 6,-2, 7,-1, 17,0, 18,1, 94,2, 117,3, 119,4, 128,5
			db 138,6, 158,7, 168,8, 178,9, 188,10, 198,11, 208,12, 228,13, 255,14
dex_blows:	db 10,0, 19,1, 68,2, 108,3, 118,4, 119,5, 128,6, 138,7, 148,8, 158,9
			db 168,10, 255,11
int_adj:	db 8,0, 15,1, 18,2, 68,3, 88,4, 108,5, 118,6, 119,7, 129,8, 139,9
			db 149,10, 159,11, 169,12, 179,13, 189,14, 199,15, 219,16, 229,18, 255,20

/* calc_hitpoints - p_mhp = player_hp[lev-1] + con_adj * lev, at least
	lev + 1, +10 heroic, +20 berserk. When it changes, current hit points
	change in proportion (calc_hitpoints in MISC2.C) */
calc_hitpoints:
	ld a,(p_lev)
	dec a
	add a,a
	ld hl,P_HP_TABLE
	add hl,a
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	ld a,(p_con_adj)
	ld e,a
	rla
	sbc a,a
	ld d,a								; DE = con_adj
	ld a,(p_lev)
	ld b,a
.times:
	add hl,de
	djnz .times
	ld a,(p_lev)
	inc a
	ld e,a
	ld d,0
	bit 7,h
	jr nz,.least
	push hl
	or a
	sbc hl,de
	pop hl
	jr nc,.enough
.least:
	ex de,hl
.enough:
	ld a,(p_status)
	bit PY_HERO,a
	jr z,.no_hero
	ld de,10
	add hl,de
.no_hero:
	bit PY_SHERO,a
	jr z,.no_shero
	ld de,20
	add hl,de
.no_shero:
	ld de,(p_mhp)
	ld a,d
	or e
	jr z,.store							; still being created
	push hl
	or a
	sbc hl,de
	pop hl
	ret z								; no change
	ld (ch_new),hl
	ld hl,(p_chp)
	bit 7,h
	jr nz,.new							; dead anyway
	ld (ch_val+2),hl					; ((chp << 16) + frac) / mhp * new
	ld hl,(p_chp_frac)
	ld (ch_val),hl
	call div32_16
	ld bc,(ch_new)
	call mul32_16
	ld hl,(ch_val)
	ld (p_chp_frac),hl
	ld hl,(ch_val+2)
	ld (p_chp),hl
.new:
	ld hl,(ch_new)
.store:
	ld (p_mhp),hl
	ret

/* div32_16 - ch_val /= DE (DE > 0). Clobbers A, B, HL, IX */
div32_16:
	ld ix,ch_val
	ld hl,0								; remainder
	ld b,32
.loop:
	sla (ix+0)
	rl (ix+1)
	rl (ix+2)
	rl (ix+3)
	adc hl,hl
	jr c,.over							; past 16 bits: certainly >= DE
	or a
	sbc hl,de
	jr nc,.one
	add hl,de
	jr .next
.over:
	or a
	sbc hl,de
.one:
	inc (ix+0)
.next:
	djnz .loop
	ret

/* mul32_16 - ch_val = low 32 bits of ch_val * BC. Clobbers A, DE, HL */
mul32_16:
	ld hl,0
	ld de,0
	ld a,16
.loop:
	add hl,hl							; DE:HL <<= 1
	rl e
	rl d
	sla c
	rl b
	jr nc,.next
	push bc
	ld bc,(ch_val)
	add hl,bc
	ex de,hl
	ld bc,(ch_val+2)
	adc hl,bc
	ex de,hl
	pop bc
.next:
	dec a
	jr nz,.loop
	ld (ch_val),hl
	ld (ch_val+2),de
	ret

/* update_max_exp - max_exp follows exp up (prt_experience) */
update_max_exp:
	ld hl,(p_exp+2)
	ld de,(p_max_exp+2)
	or a
	sbc hl,de
	ret c
	jr nz,.raise
	ld hl,(p_exp)
	ld de,(p_max_exp)
	sbc hl,de							; (carry is clear)
	ret c
	ret z
.raise:
	ld hl,(p_exp)
	ld (p_max_exp),hl
	ld hl,(p_exp+2)
	ld (p_max_exp+2),hl
	ret

; ---------------------------------------------------------------- flavours

/* flavour_class - IY = kind -> carry and A = its object_offset() if the
	kind has a flavour (potions, scrolls, staffs, wands, rods, rings,
	amulets).
	Changes only A */
flavour_class:
	ld a,(iy+K_TVAL)
	cp TV_POTION1
	jr z,.potion
	cp TV_POTION2
	jr z,.potion
	cp TV_SCROLL1
	jr z,.scroll
	cp TV_SCROLL2
	jr z,.scroll
	cp TV_STAFF
	jr z,.staff
	cp TV_WAND
	jr z,.wand
	cp TV_ROD
	jr z,.rod
	cp TV_RING
	jr z,.ring
	cp TV_AMULET
	jr z,.amulet
	or a
	ret
.ring:
	ld a,OFS_RING
	scf
	ret
.amulet:
	ld a,OFS_AMULET
	scf
	ret
.staff:
	ld a,OFS_STAFF
	scf
	ret
.wand:
	ld a,OFS_WAND
	scf
	ret
.rod:
	ld a,OFS_ROD
	scf
	ret
.scroll:
	ld a,OFS_SCROLL
	scf
	ret
.potion:
	ld a,OFS_POTION
	scf
	ret

/* ident_addr - IY = kind -> carry and HL = its object_ident byte, if it
	has a flavour. Clobbers A, DE */
ident_addr:
	call flavour_class
	ret nc
	ld e,a
	ld d,64
	mul d,e
	ld a,(iy+K_FLAVOUR)
	add de,a
	ld hl,object_ident
	add hl,de
	scf
	ret

/* item_known - IX = item, IY = its kind -> carry if the player knows what
	it is: store bought, no flavour, or learnt (known1_p). Clobbers A, DE, HL */
item_known:
	bit ID_STORE_BIT,(ix+I_IDENT)
	scf
	ret nz
	call ident_addr
	ccf
	ret c								; nothing to learn
	bit OD_KNOWN_BIT,(hl)
	scf
	ret nz
	or a
	ret

/* flavour_index - IY = flavoured kind -> A = its colour (after this game's
	shuffle). Clobbers HL */
flavour_index:
	call flavour_tables
	ld a,(iy+K_FLAVOUR)
	add hl,a
	ld a,(hl)
	ret

/* flavour_tables - IY = flavoured kind (not a scroll) -> HL = this game's
	order for its class, DE = the names, BC = the colours (on FLAVOUR_PAGE).
	Clobbers A */
flavour_tables:
	call flavour_class
	ld hl,flavour_map
	ld de,colour_names
	ld bc,colour_attrs
	cp OFS_POTION
	ret z
	ld hl,wood_map
	ld de,wood_names
	ld bc,wood_attrs
	cp OFS_STAFF
	ret z
	ld hl,rock_map
	ld de,rock_names
	ld bc,rock_attrs
	cp OFS_RING
	ret z
	ld hl,amulet_map
	ld de,amulet_names
	ld bc,amulet_attrs
	cp OFS_AMULET
	ret z
	ld hl,metal_map						; wands and rods: metals
	ld de,metal_names
	ld bc,metal_attrs
	ret

/* flavour_attr - IY = flavoured kind (not a scroll) -> A = its colour.
	Leaves FLAVOUR_PAGE in the data window */
flavour_attr:
	call flavour_index
	push af
	call flavour_tables
	pop af
	nextreg NR_MMU1,FLAVOUR_PAGE
	ld h,b
	ld l,c
	add hl,a
	ld a,(hl)
	ret

/* flavour_name - IY = flavoured kind -> HL = its colour's name, or its
	title for a scroll. Leaves FLAVOUR_PAGE in the data window: page the
	kind back before using IY. Clobbers A, DE */
flavour_name:
	call flavour_class
	cp OFS_SCROLL
	jr nz,.colour
	ld e,(iy+K_FLAVOUR)					; scroll_titles + flavour * 10
	ld d,10
	mul d,e
	ld hl,scroll_titles
	add hl,de
	nextreg NR_MMU1,FLAVOUR_PAGE
	ret
.colour:
	call flavour_index
	push af
	call flavour_tables
	pop af
	nextreg NR_MMU1,FLAVOUR_PAGE
	add a,a
	ex de,hl
	add hl,a
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	ret

/* learn_kind - HL = kind: the player now knows what it is (identify):
	known, no longer just tried, and stacks of it in the pack combine */
learn_kind:
	push hl
	call kind_addr
	call ident_addr
	jr nc,.done
	set OD_KNOWN_BIT,(hl)
	res OD_TRIED_BIT,(hl)
	pop hl
	jp pack_combine
.done:
	pop hl
	ret

/* try_kind - HL = kind: the player tried it without learning what it is
	(sample). Clobbers DE, HL */
try_kind:
	call kind_addr
	call ident_addr
	ret nc
	set OD_TRIED_BIT,(hl)
	ret

; ---------------------------------------------------------------- using items

/* item_used - after quaffing or reading item u_slot (kind u_kind, level
	u_level): if it did something noticeable (u_ident) and wasn't known,
	learn it, with (level + lev/2) / lev experience; if not, it's tried.
	Leaves u_slot on the item, which identifying may have moved */
item_used:
	ld a,(u_slot)						; still where it was?
	call pack_slot
	ld hl,(u_kind)
	call item_is_kind
	call nz,.refind
	ld hl,(u_kind)
	call kind_addr
	call ident_addr
	bit OD_KNOWN_BIT,(hl)
	ret nz								; known already
	ld a,(u_slot)
	call pack_slot
	bit ID_STORE_BIT,(ix+I_IDENT)
	ret nz								; (the C's known1_p)
	ld a,(u_ident)
	or a
	jr z,.sample
	ld a,(p_lev)						; exp += (level + lev/2) / lev
	ld c,a
	srl a
	ld hl,u_level
	add a,(hl)
	ld l,a
	ld h,0
	call div16_8
	call add_exp
	call check_level_up
	ld hl,(u_kind)
	call learn_kind
.refind:								; learning combines stacks (of the
	ld hl,(u_kind)						; things that stack)
	call kind_addr
	ld a,(iy+K_CLASS)
	call stackable
	ret nc
	ld hl,(u_kind)
	call find_pack_kind
	ld (u_slot),a
	ret
.sample:
	ld hl,(u_kind)
	jp try_kind

/* ident - the item being used did something noticeable */
ident:
	ld a,1
	ld (u_ident),a
	ret

/* add_exp - HL = experience to add. add_exp32 - DE:HL */
add_exp:
	ld de,0
add_exp32:
	ld bc,(p_exp)
	add hl,bc
	ld (p_exp),hl
	ld hl,(p_exp+2)
	adc hl,de
	ld (p_exp+2),hl
	ret

/* hurt - HL = damage, DE = killer */
hurt:
	ld (killer_race),de
	jp take_hit

/* msg_flush - msg_print(NULL): let the player read what's on the line */
msg_flush:
	ld a,(msg_col)
	or a
	ret z
	ld e,a
	inc e
	ld d,MSG_ROW
	ld hl,txt_more
	ld c,ATTR_GREY
	call print_at
	call wait_fresh_key
	jp msg_clear

/* get_w - HL = word -> DE = its value, Z if zero. Preserves HL */
get_w:
	ld e,(hl)
	inc hl
	ld d,(hl)
	dec hl
	ld a,d
	or e
	ret

/* set_w - HL = word, DE = value */
set_w:
	ld (hl),e
	inc hl
	ld (hl),d
	dec hl
	ret

/* add_rand - HL = counter, B = base, C = range: counter += 1dC + B */
add_rand:
	push hl
	push bc
	ld a,c
	call randint
	pop bc
	pop hl
	add a,b
	ld e,(hl)
	inc hl
	ld d,(hl)
	add de,a
	ld (hl),d
	dec hl
	ld (hl),e
	ret

; ---------------------------------------------------------------- variables

p_stat_max:		ds 6				; what restoring brings stats back to
p_max_exp:		dd 0
p_max_dlv:		db 0				; deepest level, for word of recall
p_speed:		db 0				; signed: below 0 is fast (the C's speed)
p_eq_speed:		db 0				; signed: how much faster equipment makes you
p_eflags:		dd 0				; the C's flags of everything worn (EF_ bits),
									; with race gifts (see invisible, ffall, free action)
p_sustain:		db 0				; bit per A_ stat: sustained by race or ring
p_stat_mod:		ds 6				; signed: what equipment adds to each stat
p_eflags2:		dd 0				; the C's flags2 of everything worn (F2_ bits)
p_stat_use:		ds 6				; the stats in use (the C's use_stat)
cs_num:			db 0
mana_regen:		db 0				; this turn's regeneration (for mana)
new_rec:		ds ITEM_SIZE		; an item an overlay is having made in the misc
									; overlay (OVCALL new_item): outside the window
p_status:		dw 0				; PY_ and PY2_ bits
p_update:		db 0				; PU_ bits
p_new_level:	db 0				; set when word of recall fires
pending_magic:	db 0				; PM_ action for the magic overlay
pending_arg:	db 0
xc_target:		dw 0				; device_xcall's routine
summon_max:		db 3				; summon_some: up to 1d(this), 1d4 staffs
gen_strain:		db 1				; genocide hurts (scrolls), not staffs
dispel_mask:	db 1<<RF_UNDEAD		; dispel_creature: R_FLAGS bits, 0 = all
dispel_dam:		db 60
u_slot:			db 0				; the item being quaffed or read
u_kind:			dw 0
u_level:		db 0
u_ident:		db 0
; timed effects, words, cleared together by player_init
p_timed:
p_blind:		dw 0
p_confused:		dw 0
p_afraid:		dw 0
p_poisoned:		dw 0
p_fast:			dw 0
p_slow:			dw 0
p_cut:			dw 0				; signed
p_stun:			dw 0				; signed
p_hero:			dw 0
p_shero:		dw 0
p_blessed:		dw 0
p_protevil:		dw 0
p_resist_heat:	dw 0
p_resist_cold:	dw 0
p_detect_inv:	dw 0
p_tim_infra:	dw 0
p_word_recall:	dw 0
p_shield:		dw 0				; a mystic shield (+50 AC)
p_invuln:		dw 0				; invulnerable (+100 AC, no damage)
p_resist_acid:	dw 0
p_resist_light:	dw 0				; (lightning)
p_resist_poison: dw 0
p_confuse_mon:	dw 0				; hands glowing (not timed)
p_light:		db 0				; the player's light is on (player_light)
P_TIMED_SIZE	equ $-p_timed
; what the player knows and this game's flavours live in bank 5's spare
; 1K after the tile definitions (KNOWLEDGE in constants.asm)
; scratch
ch_new:			dw 0
ch_val:			dd 0
