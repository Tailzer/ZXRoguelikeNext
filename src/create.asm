/* create.asm - making a character, and the character sheet
	[overlay: PAGE_CREATE]
	References: CREATE.C (choose_race, get_sex, get_class_choice,
	get_stats, change_stat, get_all_stats, get_class, get_ahw, get_money,
	create_character), MISC2.C (tohit_adj, todam_adj, toac_adj, con_adj,
	attack_blows, title_string, get_name), PLAYER.C tables via
	tools/convert.py (data/player.asm).
	Not yet: the background history (social class is taken as 50).
 */

SOCIAL_CLASS		equ 50

/* create_character - the whole sequence; leaves everything player_init
	needs: stats, race/class numbers, hp and exp tables, kit, gold */
create_character:
	call clear_screen
	ld hl,txt_create
	ld d,0
	ld e,2
	ld c,ATTR_YELLOW
	call print_at
	call choose_race
	call choose_sex
	call choose_class
.roll:
	call roll_character
	xor a
	ld (sheet_full),a
	call draw_sheet
	ld hl,txt_reroll
	call bottom_prompt
.key:
	call read_ascii
	cp ' '
	jr z,.roll
	cp 13
	jr nz,.key
	call get_money
	call get_name
	call finish_character
	ret

; ------------------------------------------------------------- choosing

/* choose_race - "a) Human  b) Half-Elf ..." then a letter */
choose_race:
	ld hl,prace_table
	ld b,NUM_P_RACES
	ld de,P_RACE_SIZE
	call show_choices
	ld hl,txt_choose_race
	call bottom_prompt
.key:
	call read_ascii
	sub 'a'
	cp NUM_P_RACES
	jr nc,.key
	ld (p_race),a
	jp clear_choices

/* choose_sex - m or f */
choose_sex:
	ld hl,txt_sexes
	ld d,CHOICE_ROW
	ld e,2
	ld c,ATTR_WHITE
	call print_at
	ld hl,txt_choose_sex
	call bottom_prompt
.key:
	call read_ascii
	or $20								; either case
	cp 'm'
	ld b,1
	jr z,.got
	cp 'f'
	ld b,0
	jr nz,.key
.got:
	ld a,b
	ld (p_male),a
	jp clear_choices

/* choose_class - only the classes this race may be (rtclass bits) */
choose_class:
	call race_rec
	ld a,(ix+PR_CLASSES)
	ld (class_mask),a
	xor a								; list them, letters in order
	ld (choice_count),a
	ld (choice_index),a
.list:
	ld a,(choice_index)
	ld b,a
	ld a,(class_mask)
	inc b
.bit:
	dec b
	jr z,.test
	rrca
	jr .bit
.test:
	rrca
	jr nc,.next
	ld a,(choice_count)					; this class gets the next letter
	ld hl,class_letters
	add hl,a
	ld a,(choice_index)
	ld (hl),a
	call class_rec_a
	ld a,(choice_count)
	call show_choice
	ld hl,choice_count
	inc (hl)
.next:
	ld hl,choice_index
	inc (hl)
	ld a,(hl)
	cp NUM_CLASSES
	jr c,.list
	ld hl,txt_choose_class
	call bottom_prompt
.key:
	call read_ascii
	sub 'a'
	ld hl,choice_count
	cp (hl)
	jr nc,.key
	ld hl,class_letters
	add hl,a
	ld a,(hl)
	ld (p_class),a
	jp clear_choices

/* show_choices - HL = table of records starting with a name pointer,
	DE = record size, B = how many: "a) Name" in rows of five */
show_choices:
	xor a
.each:
	push af
	push bc
	push de
	push hl
	push hl
	pop ix
	call show_choice
	pop hl
	pop de
	add hl,de
	pop bc
	pop af
	inc a
	djnz .each
	ret

/* show_choice - A = number, IX = record with a name pointer first:
	"a) Human" at row CHOICE_ROW + n/5, column 2 + 15*(n%5) */
show_choice:
	ld (choice_n),a
	call msg_begin
	ld a,(choice_n)
	add a,'a'
	ld (txt_choice_label),a
	ld hl,txt_choice_label
	call msg_add
	ld l,(ix+0)
	ld h,(ix+1)
	call msg_add
	ld hl,(msg_ptr)
	ld (hl),0
	ld a,(choice_n)
	ld b,CHOICE_ROW
.row:
	cp 5
	jr c,.col
	sub 5
	inc b
	jr .row
.col:
	ld e,a
	ld d,15
	mul d,e
	ld a,e
	add a,2
	ld e,a
	ld d,b
	ld hl,msg_buf
	ld c,ATTR_WHITE
	jp print_at

/* clear_choices - wipe the choice rows and the prompt */
clear_choices:
	ld d,CHOICE_ROW
	call clear_row
	ld d,CHOICE_ROW+1
	call clear_row
	ld d,CHOICE_ROW+2
	call clear_row
	ld d,PROMPT_ROW
	jp clear_row

/* bottom_prompt - HL = text for the prompt row */
bottom_prompt:
	push hl
	ld d,PROMPT_ROW
	call clear_row
	pop hl
	ld d,PROMPT_ROW
	ld e,2
	ld c,ATTR_YELLOW
	jp print_at

/* race_rec - IX = this player's race record. Clobbers DE */
race_rec:
	ld a,(p_race)
	ld e,a
	ld d,P_RACE_SIZE
	mul d,e
	ld ix,prace_table
	add ix,de
	ret

/* class_rec - IX = this player's class record; class_rec_a: class A */
class_rec:
	ld a,(p_class)
class_rec_a:
	ld e,a
	ld d,CLASS_SIZE
	mul d,e
	ld ix,class_table
	add ix,de
	ret

; ---------------------------------------------------------------- rolling

/* roll_character - roll stats (get_stats), add race and class
	adjustments (change_stat), and work out everything that follows */
roll_character:
.again:
	ld hl,stat_dice
	ld b,0								; die number 0-17
	ld c,0								; total
.die:
	ld a,b								; 1d(3 + n % 3): 3, 4 and 5-sided
.mod3:
	cp 3
	jr c,.sides
	sub 3
	jr .mod3
.sides:
	add a,3
	push bc
	push hl
	call randint
	pop hl
	pop bc
	ld (hl),a
	inc hl
	add a,c
	ld c,a
	inc b
	ld a,b
	cp 18
	jr c,.die
	ld a,c								; total must be 43-53
	cp 43
	jr c,.again
	cp 54
	jr nc,.again
	ld hl,stat_dice						; stat = 5 + three dice
	ld de,p_stat
	ld b,6
.stat:
	ld a,5
	add a,(hl)
	inc hl
	add a,(hl)
	inc hl
	add a,(hl)
	inc hl
	ld (de),a
	inc de
	djnz .stat
	call race_rec						; race, then class, adjustments
	ld de,PR_ADJ
	call .adjust
	call class_rec
	ld de,PC_ADJ
	call .adjust
	jp derive
.adjust:								; IX+DE = 6 signed adjustments
	add ix,de
	ld hl,p_stat
	ld b,6
.each:
	push bc
	ld b,(ix+0)
	call change_stat
	inc ix
	inc hl
	pop bc
	djnz .each
	ret

/* change_stat - HL -> stat, B = signed amount (change_stat in CREATE.C:
	above 18 the steps are 18/05-18/20 at a time, then smaller) */
change_stat:
	ld a,b
	or a
	ret z
	bit 7,b
	jr nz,.down
.up:
	push bc
	ld a,(hl)
	cp 18
	jr c,.plus1
	cp 88
	jr c,.plus15
	cp 108
	jr c,.plus6
	cp 118
	jr c,.plus1
	jr .up_next
.plus1:
	inc (hl)
	jr .up_next
.plus15:
	ld a,15
	ld c,5
	jr .plus
.plus6:
	ld a,6
	ld c,2
.plus:
	push hl
	push bc
	call randint
	pop bc
	pop hl
	add a,c
	add a,(hl)
	ld (hl),a
.up_next:
	pop bc
	djnz .up
	ret
.down:
	ld a,b
	neg
	ld b,a
.down_loop:
	push bc
	ld a,(hl)
	cp 109
	jr nc,.minus1						; above 18/90: one point
	cp 89
	jr nc,.minus6						; above 18/70: 1d6+2
	cp 19
	jr nc,.minus15						; above 18: 1d15+5, not below 18
	cp 4
	jr nc,.minus1
	jr .down_next
.minus1:
	dec (hl)
	jr .down_next
.minus6:
	ld a,6
	ld c,2
	jr .minus
.minus15:
	ld a,15
	ld c,5
.minus:
	push hl
	push bc
	call randint
	pop bc
	pop hl
	add a,c
	ld c,a
	ld a,(hl)
	sub c
	jr c,.to18
	cp 18
	jr nc,.store
.to18:
	ld a,18
.store:
	ld (hl),a
.down_next:
	pop bc
	djnz .down_loop
	ret

/* derive - everything that follows from race, class and stats */
derive:
	call race_rec
	push ix
	call class_rec
	pop iy								; IY = race, IX = class
	ld a,(iy+PR_HITDIE)
	add a,(ix+PC_HD)
	ld (p_hitdie),a
	ld a,(iy+PR_BTH)
	add a,(ix+PC_BTH)
	ld (p_bth),a
	ld a,(iy+PR_STL)
	add a,(ix+PC_STL)
	ld (p_stl),a
	ld a,(iy+PR_EXP)
	add a,(ix+PC_EXP)
	ld (p_expfact),a
	ld a,(iy+PR_INFRA)
	ld (p_infra),a
	ld a,(ix+PC_LADJ)
	ld (p_cla_bth),a
	ld a,(ix+PC_LADJ+2)					; device skill per level
	ld (p_cla_dev),a
	ld a,(iy+PR_BSAV)					; saving throw
	add a,(ix+PC_SAV)
	ld (p_save),a
	ld a,(p_stl)						; monsters' noticing roll
	add a,4
	bit 7,a
	jr z,$+3
	xor a
	cp 25
	jr c,$+4
	ld a,24
	add a,a
	ld hl,notice_table
	add hl,a
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	ld (p_notice),hl
	call stat_bonuses
	; age, height, weight (get_ahw; randnor taken as base +- mod)
	ld a,(iy+PR_AGE_MOD)
	call randint
	add a,(iy+PR_AGE)
	ld (p_age),a
	ld a,(p_male)
	or a
	ld de,PR_M_HT
	jr nz,$+5
	ld de,PR_F_HT
	push iy
	pop hl
	add hl,de
	push hl
	ld b,(hl)
	inc hl
	ld c,(hl)
	call about_base
	ld a,l
	ld (p_ht),a
	pop hl
	inc hl
	inc hl
	ld b,(hl)
	inc hl
	ld c,(hl)
	call about_base
	ld (p_wt),hl
	; level 1 hit points for the sheet: hit die + con adjustment
	ld a,(p_hitdie)
	ld b,a
	ld a,(p_con_adj)
	add a,b
	cp 2
	jr nc,$+4
	ld a,2
	ld l,a
	ld h,0
	ld (p_mhp),hl
	ld (p_chp),hl
	ld a,1
	ld (p_lev),a
	ld hl,0
	ld (p_exp),hl
	ld (p_exp+2),hl
	ld (p_gold),hl
	ld (p_gold+2),hl
	ret

/* about_base - B = base, C = spread -> HL = base - spread + 1d(2*spread+1) - 1
	(an even stand-in for randnor) */
about_base:
	ld a,c
	add a,a
	inc a
	push bc
	call randint
	pop bc
	dec a
	ld l,b
	ld h,0
	add hl,a
	ld e,c
	ld d,0
	or a
	sbc hl,de
	ret

/* get_money - starting gold (get_money in CREATE.C): 325 + 1d25 + social
	class * 6, less 5 per stat point over 10, plus charisma's, +50 if female */
get_money:
	ld hl,SOCIAL_CLASS*6+325
	ld a,25
	push hl
	call randint
	pop hl
	add hl,a
	ld ix,p_stat
	ld b,5								; STR INT WIS DEX CON
.stat:
	ld a,(ix+0)
	call monval
	or a
	sbc hl,de
	inc ix
	djnz .stat
	ld a,(p_stat+A_CHR)
	call monval
	add hl,de
	ld a,(p_male)
	or a
	jr nz,.min
	ld de,50
	add hl,de
.min:
	bit 7,h
	jr nz,.eighty
	ld de,80
	or a
	sbc hl,de
	add hl,de
	jr nc,.set
.eighty:
	ld hl,80
.set:
	ld (p_gold),hl
	ld hl,0
	ld (p_gold+2),hl
	ret

/* monval - A = stat -> DE = 5 * (stat - 10), signed. Preserves HL */
monval:
	sub 10
	ld e,a
	rla
	sbc a,a
	ld d,a
	push hl
	ld h,d
	ld l,e
	add hl,hl
	add hl,hl
	add hl,de
	ex de,hl
	pop hl
	ret

/* get_name - type a name: letters, digits, space; Caps Shift + 0
	deletes; Enter finishes */
get_name:
	ld hl,txt_enter_name
	call bottom_prompt
	ld hl,p_name
	ld (hl),0
	ld b,0								; length
.show:
	push bc
	ld d,SHEET_ROW
	ld e,SHEET_LEFT+9
	ld hl,txt_blank_name
	ld c,ATTR_WHITE
	call print_at
	ld d,SHEET_ROW
	ld e,SHEET_LEFT+9
	ld hl,p_name
	ld c,ATTR_YELLOW
	call print_at
	ld a,'_'
	ld (de),a
	inc de
	ld a,ATTR_YELLOW
	ld (de),a
	pop bc
.key:
	push bc
	call read_ascii
	pop bc
	cp 13
	jr z,.done
	cp 8
	jr z,.delete
	cp ' '
	jr c,.key
	ld c,a
	ld a,b
	cp NAME_MAX
	jr nc,.key
	ld hl,p_name
	ld a,b
	add hl,a
	ld (hl),c
	inc hl
	ld (hl),0
	inc b
	jr .show
.delete:
	ld a,b
	or a
	jr z,.key
	dec b
	ld hl,p_name
	ld a,b
	add hl,a
	ld (hl),0
	jr .show
.done:
	ld a,b
	or a
	jr nz,.named
	ld hl,txt_default_name
	ld de,p_name
	ld bc,txt_default_name_end-txt_default_name
	ldir
.named:
	ld d,PROMPT_ROW
	jp clear_row

/* finish_character - roll hit points for every level, scale the
	experience table, and note the class's kit */
finish_character:
	; player_hp[]: hit die at level 1, then 1d(hit die) a level, rolled
	; again until the total at level 50 is within 1/8 of average
	ld a,(p_hitdie)
	dec a
	ld e,a
	ld d,150							; min = 150*(hd-1)/8 + 50
	mul d,e
	ex de,hl
	srl h
	rr l
	srl h
	rr l
	srl h
	rr l
	ld de,MAX_PLAYER_LEVEL
	add hl,de
	ld (hp_min),hl
	ld a,(p_hitdie)
	dec a
	ld e,a
	ld d,250							; max = 250*(hd-1)/8 + 50
	mul d,e
	ex de,hl
	srl h
	rr l
	srl h
	rr l
	srl h
	rr l
	ld de,MAX_PLAYER_LEVEL
	add hl,de
	ld (hp_max),hl
.reroll:
	ld a,(p_hitdie)
	ld l,a
	ld h,0
	ld ix,P_HP_TABLE
	ld (ix+0),l
	ld (ix+1),h
	ld b,MAX_PLAYER_LEVEL-1
.level:
	push bc
	push hl
	ld a,(p_hitdie)
	call randint
	pop hl
	add hl,a
	inc ix
	inc ix
	ld (ix+0),l
	ld (ix+1),h
	pop bc
	djnz .level
	ld de,(hp_min)						; HL = total at level 50
	or a
	sbc hl,de
	jr c,.reroll
	add hl,de
	ld de,(hp_max)
	ex de,hl
	or a
	sbc hl,de
	jr c,.reroll
	; experience needed: player_exp[] * expfact / 100
	ld hl,player_exp
	ld ix,P_EXP_TABLE
	ld b,MAX_PLAYER_LEVEL
.exp:
	push bc
	push hl
	call scale_exp
	pop hl
	ld de,4
	add hl,de
	add ix,de
	pop bc
	djnz .exp
	; kit
	ld a,(p_class)
	ld e,a
	ld d,10
	mul d,e
	ld hl,kit_table
	add hl,de
	ld de,p_kit
	ld bc,10
	ldir
	ret

/* scale_exp - (HL) 32-bit level threshold -> (IX) = it * expfact / 100 */
scale_exp:
	ld a,(p_expfact)
	ld c,a
	ld b,4
	push ix
	pop de
	xor a								; carry byte
	ld (scale_carry),a
.byte:									; multiply byte by byte
	push bc
	ld a,(hl)
	inc hl
	push de
	ld d,a
	ld e,c
	mul d,e
	ld a,(scale_carry)
	add a,e
	ld e,a
	ld a,d
	adc a,0
	ld (scale_carry),a
	ld a,e
	pop de
	ld (de),a
	inc de
	pop bc
	djnz .byte
	; divide the 32-bit product at IX by 100
	ld b,32
	xor a
	ld (scale_carry),a
	ld l,(ix+0)
	ld h,(ix+1)
	ld e,(ix+2)
	ld d,(ix+3)
	ld c,0								; remainder
.div:
	add hl,hl
	rl e
	rl d
	rl c
	ld a,c
	sub 100
	jr c,.next
	ld c,a
	inc l
.next:
	djnz .div
	ld (ix+0),l
	ld (ix+1),h
	ld (ix+2),e
	ld (ix+3),d
	ret

; ------------------------------------------------------------- the sheet

/* show_character - 'C': the character sheet until a key is pressed */
show_character:
	call clear_screen
	ld a,1
	ld (sheet_full),a
	call draw_sheet
	ld hl,txt_any_key_c
	call bottom_prompt
	call read_ascii
	jp clear_screen

/* draw_sheet - name, race, sex, class, age/height/weight, title, stats;
	with sheet_full also level, experience, hit points and combat numbers */
draw_sheet:
	ld hl,sheet_labels
	call print_labels
	ld hl,p_name
	ld de,SHEET_ROW*256+COL1
	call print_text
	call race_rec
	ld l,(ix+0)
	ld h,(ix+1)
	ld de,(SHEET_ROW+1)*256+COL1
	call print_text
	ld hl,txt_female
	ld a,(p_male)
	or a
	jr z,$+5
	ld hl,txt_male
	ld de,(SHEET_ROW+2)*256+COL1
	call print_text
	call class_rec
	ld l,(ix+0)
	ld h,(ix+1)
	ld de,(SHEET_ROW+3)*256+COL1
	call print_text
	ld a,(p_age)
	ld de,SHEET_ROW*256+COL2
	call print_number
	ld a,(p_ht)
	ld de,(SHEET_ROW+1)*256+COL2
	call print_number
	ld hl,(p_wt)
	ld de,(SHEET_ROW+2)*256+COL2
	call print_word
	call title_string
	ld de,(SHEET_ROW+3)*256+COL2
	call print_text
	ld hl,p_stat_use					; STR..CHR as used (use_stat), or
	ld a,(sheet_full)					; as rolled
	or a
	jr nz,$+5
	ld hl,p_stat
	ld de,SHEET_ROW*256+COL3
	ld b,6
.stat:
	push bc
	push de
	push hl
	ld a,(hl)
	call screen_at
	call print_stat
	pop hl
	pop de
	pop bc
	inc hl
	inc d
	djnz .stat
	ld hl,(p_gold)						; gold, once rolled
	ld (num32),hl
	ld hl,(p_gold+2)
	ld (num32+2),hl
	ld de,(SHEET_ROW+10)*256+COL1
	call screen_at
	ld hl,num32
	ld c,ATTR_WHITE
	call print_u32
	ld a,(sheet_full)
	or a
	ret z
	ld hl,full_labels
	call print_labels
	ld a,(p_lev)
	ld de,(SHEET_ROW+8)*256+COL1
	call print_number
	ld de,(SHEET_ROW+9)*256+COL1
	call screen_at
	ld hl,p_exp
	ld c,ATTR_WHITE
	call print_u32
	ld hl,(p_mhp)
	ld de,(SHEET_ROW+8)*256+COL2
	call print_word
	ld hl,(p_chp)
	ld de,(SHEET_ROW+9)*256+COL2
	call print_word
	ld a,(p_ac)
	ld de,(SHEET_ROW+10)*256+COL2
	call print_number
	ld a,(p_tohit)
	ld de,(SHEET_ROW+8)*256+COL3
	call print_signed
	ld a,(p_todam)
	ld de,(SHEET_ROW+9)*256+COL3
	call print_signed
	ld a,(p_blows)
	ld de,(SHEET_ROW+10)*256+COL3
	call print_number
	ld a,(p_stl)
	ld de,(SHEET_ROW+11)*256+COL1
	call print_signed
	ld a,(p_infra)						; infravision in tens of feet
	ld e,a
	ld d,10
	mul d,e
	ex de,hl
	ld de,(SHEET_ROW+11)*256+COL2
	call print_word
	ld hl,txt_feet_c
	ld c,ATTR_WHITE
	jp print_str

/* print_labels - HL = list of row, column, text pointer; 0 ends it */
print_labels:
	ld a,(hl)
	or a
	ret z
	ld d,a
	inc hl
	ld e,(hl)
	inc hl
	ld a,(hl)
	inc hl
	push hl
	ld h,(hl)
	ld l,a
	ld c,ATTR_GREY
	call print_at
	pop hl
	inc hl
	jr print_labels

/* screen_at - D = row, E = column -> DE = that cell. Preserves AF, BC, HL */
screen_at:
	push af
	push hl
	push bc
	call screen_addr
	ex de,hl
	pop bc
	pop hl
	pop af
	ret

/* print_text - HL = text at row D, column E */
print_text:
	ld c,ATTR_WHITE
	jp print_at

/* print_number - A at row D, column E */
print_number:
	call screen_at
	ld c,ATTR_WHITE
	jp print_u8

/* print_word - HL at row D, column E */
print_word:
	call screen_at
	ld c,ATTR_WHITE
	jp print_u16

/* print_signed - A (signed) as "+3" / "-1" at row D, column E */
print_signed:
	call screen_at
	ld c,ATTR_WHITE
	ld b,'+'
	bit 7,a
	jr z,.sign
	neg
	ld b,'-'
.sign:
	push af
	ld a,b
	ld (de),a
	inc de
	ld a,c
	ld (de),a
	inc de
	pop af
	jp print_u8

/* print_stat - A = stat at cell DE: " 9", "18", "18/05", "18/100" */
print_stat:
	ld c,ATTR_WHITE
	cp 19
	jr nc,.percent
	cp 10
	jr nc,.plain
	push af
	ld a,' '
	ld (de),a
	inc de
	ld a,c
	ld (de),a
	inc de
	pop af
.plain:
	jp print_u8
.percent:
	sub 18
	push af
	ld hl,txt_18
	call print_str
	pop af
	cp 10
	jr nc,.plain
	push af
	ld a,'0'
	ld (de),a
	inc de
	ld a,c
	ld (de),a
	inc de
	pop af
	jp print_u8

/* title_string - HL = the title for this class and level */
title_string:
	ld a,(p_class)
	ld e,a
	ld d,MAX_PLAYER_LEVEL
	mul d,e
	ld a,(p_lev)
	dec a
	add de,a
	ex de,hl
	add hl,hl
	ld de,title_table
	add hl,de
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	ret

SHEET_ROW			equ 3
SHEET_LEFT			equ 2
COL1				equ 11				; value columns
COL2				equ 38
COL3				equ 63
CHOICE_ROW			equ 20
PROMPT_ROW			equ 26
NAME_MAX			equ 15

sheet_labels:
	db SHEET_ROW, SHEET_LEFT
	dw txt_l_name
	db SHEET_ROW+1, SHEET_LEFT
	dw txt_l_race
	db SHEET_ROW+2, SHEET_LEFT
	dw txt_l_sex
	db SHEET_ROW+3, SHEET_LEFT
	dw txt_l_class
	db SHEET_ROW, 29
	dw txt_l_age
	db SHEET_ROW+1, 29
	dw txt_l_height
	db SHEET_ROW+2, 29
	dw txt_l_weight
	db SHEET_ROW+3, 29
	dw txt_l_title
	db SHEET_ROW, 57
	dw txt_l_str
	db SHEET_ROW+1, 57
	dw txt_l_int
	db SHEET_ROW+2, 57
	dw txt_l_wis
	db SHEET_ROW+3, 57
	dw txt_l_dex
	db SHEET_ROW+4, 57
	dw txt_l_con
	db SHEET_ROW+5, 57
	dw txt_l_chr
	db SHEET_ROW+10, SHEET_LEFT
	dw txt_l_gold
	db 0
full_labels:
	db SHEET_ROW+8, SHEET_LEFT
	dw txt_l_level
	db SHEET_ROW+9, SHEET_LEFT
	dw txt_l_exp
	db SHEET_ROW+8, 29
	dw txt_l_maxhp
	db SHEET_ROW+9, 29
	dw txt_l_curhp
	db SHEET_ROW+10, 29
	dw txt_l_ac
	db SHEET_ROW+8, 54
	dw txt_l_tohit
	db SHEET_ROW+9, 54
	dw txt_l_todam
	db SHEET_ROW+10, 54
	dw txt_l_blows
	db SHEET_ROW+11, SHEET_LEFT
	dw txt_l_stealth
	db SHEET_ROW+11, 29
	dw txt_l_infra
	db 0

txt_l_name:		db "Name   :",0
txt_l_race:		db "Race   :",0
txt_l_sex:		db "Sex    :",0
txt_l_class:	db "Class  :",0
txt_l_age:		db "Age    :",0
txt_l_height:	db "Height :",0
txt_l_weight:	db "Weight :",0
txt_l_title:	db "Title  :",0
txt_l_str:		db "STR :",0
txt_l_int:		db "INT :",0
txt_l_wis:		db "WIS :",0
txt_l_dex:		db "DEX :",0
txt_l_con:		db "CON :",0
txt_l_chr:		db "CHR :",0
txt_l_gold:		db "Gold   :",0
txt_l_level:	db "Level  :",0
txt_l_exp:		db "Exp    :",0
txt_l_maxhp:	db "Max HP :",0
txt_l_curhp:	db "Cur HP :",0
txt_l_ac:		db "AC     :",0
txt_l_tohit:	db "To-hit :",0
txt_l_todam:	db "To-dam :",0
txt_l_blows:	db "Blows  :",0
txt_l_stealth:	db "Stealth:",0
txt_l_infra:	db "Infra  :",0
txt_feet_c:		db " ft",0
txt_18:			db "18/",0
txt_male:		db "Male",0
txt_female:		db "Female",0
txt_create:		db "Create a character",0
txt_choose_race: db "Choose a race (a-j)",0
txt_sexes:		db "m) Male         f) Female",0
txt_choose_sex:	db "Choose a sex (m or f)",0
txt_choose_class: db "Choose a class",0
txt_reroll:		db "Space: roll again    Enter: accept",0
txt_enter_name:	db "Enter a name, then Enter (Caps Shift+0 deletes)",0
txt_blank_name:	db "                ",0
txt_default_name: db "Adventurer",0
txt_default_name_end:
txt_any_key_c:	db "-- press a key --",0
txt_choice_label: db "a) ",0

sheet_full:		db 0
choice_n:		db 0
choice_count:	db 0
choice_index:	db 0
class_mask:		db 0
class_letters:	ds NUM_CLASSES
stat_dice:		ds 18
hp_min:			dw 0
hp_max:			dw 0
scale_carry:	db 0
num32:			dd 0

player_exp:								; PLAYER.C player_exp[]
	dd 10, 25, 45, 70, 100, 140, 200, 280
	dd 380, 500, 650, 850, 1100, 1400, 1800, 2300
	dd 2900, 3600, 4400, 5400, 6800, 8400, 10200, 12500
	dd 17500, 25000, 35000, 50000, 75000, 100000, 150000, 200000
	dd 275000, 350000, 450000, 550000, 700000, 850000, 1000000, 1250000
	dd 1500000, 1800000, 2100000, 2400000, 2700000, 3000000, 3500000, 4000000
	dd 4500000, 5000000

