/* races.asm - monster races
	Hand-copied from MONSTERS.C (Angband PC 1.2) until the data converter
	(milestone 6) generates this from the C tables. Attacks are expanded
	from the monster_attacks[] indices: type, description, dice, sides.
	Attack types: 1 normal, 3 confusion.  Descriptions: 1 hits, 2 bites,
	4 stings, 5 touches, 13 releases spores.
 */

NUM_RACES			equ 10

	MACRO RACE p_nm, p_ch, p_at, p_mv, p_xp, p_sl, p_aa, p_ac, p_sp, p_hd, p_hs, p_lv, p_ra
		dw p_nm
		db p_ch, p_at, p_mv, p_xp, p_sl, p_aa, p_ac, p_sp, p_hd, p_hs, p_lv, p_ra
		db 0, 0
	ENDM

; name, char, colour, moves, exp, sleep, aaf, ac, speed, hit dice, level, rarity
race_table:
	RACE name_grey_mold,      'm', ATTR_GREY,   1<<RM_ONLY_ATT,            3,  0,  2,  1, 11, 1, 2, 1, 1
	db 1,1,1,4,  1,1,1,4,  0,0,0,0,  0,0,0,0	; attacks
	RACE name_grey_mushroom,  ',', ATTR_GREY,   1<<RM_ONLY_ATT,            1,  0,  2,  1, 11, 1, 2, 1, 1
	db 3,13,1,4,  0,0,0,0,  0,0,0,0,  0,0,0,0	; attacks
	RACE name_yellow_centipede,'c',ATTR_YELLOW, 1<<RM_NORMAL,              2, 30,  8, 12, 11, 2, 6, 1, 1
	db 1,2,1,3,  1,4,1,3,  0,0,0,0,  0,0,0,0	; attacks
	RACE name_white_centipede,'c', ATTR_WHITE,  1<<RM_NORMAL|1<<RM_40,     2, 40,  7, 10, 11, 3, 5, 1, 1
	db 1,2,1,2,  1,4,1,2,  0,0,0,0,  0,0,0,0	; attacks
	RACE name_white_icky,     'i', ATTR_WHITE,  1<<RM_NORMAL|1<<RM_75,     2, 10, 12,  7, 11, 3, 5, 1, 1
	db 1,5,1,2,  0,0,0,0,  0,0,0,0,  0,0,0,0	; attacks
	RACE name_white_snake,    'R', ATTR_WHITE,  1<<RM_NORMAL|1<<RM_40,     2, 99,  4, 30, 11, 3, 6, 1, 1
	db 1,2,1,1,  0,0,0,0,  0,0,0,0,  0,0,0,0	; attacks
	RACE name_rock_lizard,    'R', ATTR_DARK,   1<<RM_NORMAL,              2, 15, 20,  4, 11, 3, 4, 1, 1
	db 1,2,1,1,  0,0,0,0,  0,0,0,0,  0,0,0,0	; attacks
	RACE name_small_kobold,   'k', ATTR_GREEN,  1<<RM_NORMAL|1<<RM_OPEN_DOOR, 5, 10, 20, 16, 11, 2, 7, 1, 1
	db 1,1,1,5,  0,0,0,0,  0,0,0,0,  0,0,0,0	; attacks
	RACE name_jackal,         'C', ATTR_UMBER,  1<<RM_NORMAL|1<<RM_GROUP,  1, 10, 10,  3, 11, 1, 4, 1, 1
	db 1,2,1,1,  0,0,0,0,  0,0,0,0,  0,0,0,0	; attacks
	RACE name_fruit_bat,      'b', ATTR_MAGENTA,1<<RM_NORMAL,              1, 10, 20,  3, 12, 1, 6, 1, 1
	db 1,2,1,1,  0,0,0,0,  0,0,0,0,  0,0,0,0	; attacks
race_table_end:
	ASSERT race_table_end - race_table == NUM_RACES * RACE_SIZE

name_grey_mold:			db "Grey mold",0
name_grey_mushroom:		db "Grey mushroom patch",0
name_yellow_centipede:	db "Giant yellow centipede",0
name_white_centipede:	db "Giant white centipede",0
name_white_icky:		db "White icky thing",0
name_white_snake:		db "Large white snake",0
name_rock_lizard:		db "Rock lizard",0
name_small_kobold:		db "Small kobold",0
name_jackal:			db "Jackal",0
name_fruit_bat:			db "Fruit bat",0
