/* magic_init.asm - a new character's start  [overlay: PAGE_MISC]
	Reference: DESC.C magic_init. Run once for each new character.
 */

/* player_init - start the character create_character made: level 1,
	full hit points, fed, carrying the class's kit */
player_init:
	xor a
	ld (p_speed),a
	ld (p_eq_speed),a					; nothing worn yet
	ld hl,p_stat_mod
	ld b,6
	call .zero
	ld (p_status),a						; (before calc_hitpoints looks)
	ld (p_status+1),a
	ld (p_update),a
	ld (p_new_level),a
	ld (pending_magic),a
	ld (p_max_dlv),a
	ld (p_dead),a
	ld (p_hunger),a
	ld (p_paralysed),a
	inc a
	ld (p_lev),a
	ld hl,0
	ld (p_exp),hl
	ld (p_exp+2),hl
	ld (p_exp_frac),hl
	ld (p_chp_frac),hl
	ld (p_max_exp),hl
	ld (p_max_exp+2),hl
	call stat_bonuses
	call calc_hitpoints
	ld hl,(p_mhp)
	ld (p_chp),hl
	ld hl,FOOD_START
	ld (p_food),hl
	ld hl,uniques_dead					; a new world: every unique alive
	ld b,(NUM_RACES+7)/8
	call .zero
	ld hl,p_timed						; no effects running
	ld b,P_TIMED_SIZE
	call .zero
	ld hl,object_ident					; nothing learnt yet
	ld b,0
	call .zero
	call .zero
	ld hl,p_stat						; stats start at their maximum
	ld de,p_stat_max
	ld bc,6
	ldir
	ld hl,SPELL_STATE					; no spells learnt, no mana
	ld b,SPELL_STATE_SIZE
	call .zero
	ld hl,s_order						; (99: no spell)
	ld b,64
.none:
	ld (hl),99
	inc hl
	djnz .none
	call magic_init						; this game's flavours
	OVCALL PAGE_ITEMS, starting_kit, PAGE_MISC	; (works out the bonuses)
	ld hl,p_update						; (and spells: update_stuff)
	set PU_BONUS,(hl)
	ret
.zero:
	ld (hl),0
	inc hl
	djnz .zero
	ret


/* magic_init - this game's flavours: potion colours (all but the first
	three: slime mold, apple juice, water), staff woods, wand and rod
	metals, ring stones and amulet materials shuffled, and the scroll
	titles made up (magic_init in DESC.C) */
magic_init:
	ld hl,art_made						; no artifacts made yet
	ld b,(NUM_ART_BITS+7)/8
.unmade:
	ld (hl),0
	inc hl
	djnz .unmade
	ld hl,flavour_map
	xor a
.ident:
	ld (hl),a
	inc hl
	inc a
	cp MAX_FLAVOURS
	jr c,.ident
	ld a,3
.colours:
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
	jr c,.colours
	ld hl,wood_map						; woods, metals, stones and
	ld a,NUM_WOODS						; amulets: all shuffled
	call .shuffle
	ld hl,metal_map
	ld a,NUM_METALS
	call .shuffle
	ld hl,rock_map
	ld a,NUM_ROCKS
	call .shuffle
	ld hl,amulet_map
	ld a,NUM_AMULETS
	call .shuffle
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
.shuffle:								; HL = A entries: in order, then
	ld (mi_dst),hl						; each swapped with a random one
	ld (mi_n),a
	ld b,a
	xor a
.order:
	ld (hl),a
	inc hl
	inc a
	djnz .order
	xor a
.swap:
	ld (mi_i),a
	ld a,(mi_n)
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
	ld hl,mi_n
	cp (hl)
	jr c,.swap
	ret

mi_i:			db 0
mi_n:			db 0
mi_dst:			dw 0
mi_ptr:			dw 0
mi_words:		db 0
MI_BUF_SIZE		equ 32
mi_buf:			ds MI_BUF_SIZE
