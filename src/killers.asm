/* killers.asm - the tombstone: what it says killed you, when it wasn't a
	monster (killer_race $FExx), and its picture (data page ACT_PAGE, after
	data/activate.asm; death.asm pages it in) */

killer_texts:	dw txt_starvation, txt_k_detonation, txt_k_death, txt_k_ruination
				dw txt_k_poison, txt_k_wound, txt_k_strain, txt_k_aura
				dw txt_k_earthquake
				dw txt_k_pit, txt_k_arrow, txt_k_covered_pit, txt_k_trap_door
				dw txt_k_dart, txt_k_rock, txt_k_corrosion, txt_k_fire
				dw txt_k_acid, txt_k_poison_gas, txt_k_quitting, txt_k_old_age
				dw txt_k_needle, txt_k_chest
txt_k_quitting:	db "Quitting",0
txt_k_old_age:	db "Ripe Old Age",0
txt_k_pit:		db "an open pit",0
txt_k_arrow:	db "an arrow trap",0
txt_k_covered_pit: db "a covered pit",0
txt_k_trap_door: db "a trap door",0
txt_k_dart:		db "a dart trap",0
txt_k_rock:		db "a falling rock",0
txt_k_corrosion: db "corrosion gas",0
txt_k_fire:		db "a fire trap",0
txt_k_acid:		db "an acid trap",0
txt_k_poison_gas: db "a poison gas trap",0
txt_k_detonation: db "a potion of Detonation",0
txt_k_death:	db "a potion of Death",0
txt_k_ruination: db "a potion of Ruination",0
txt_k_poison:	db "poison",0
txt_k_wound:	db "a fatal wound",0
txt_k_strain:	db "the strain of casting Genocide",0
txt_k_aura:		db "a malignant aura",0
txt_k_earthquake: db "an Earthquake",0
txt_k_needle:	db "a poison needle",0
txt_k_chest:	db "an exploding chest",0
txt_starvation:	db "starvation",0

; the tombstone (print_tomb in DEATH.C): row (the C's, before TOMB_ROW is
; added), column, text; $FF ends
tomb_art:
	db 1,15,'_______________________',0
	db 2,14,'/',0
	db 2,38,'\         ___',0
	db 3,13,'/',0
	db 3,39,'\ ___   /   \      ___',0
	db 4,12,'/            RIP            \   \  :   :     /   \',0
	db 5,11,'/',0
	db 5,41,'\  : _;,,,;_    :   :',0
	db 6,10,'/',0
	db 6,42,'\,;_          _;,,,;_',0
	db 7,9,'|               the               |   ___',0
	db 8,9,'|',0
	db 8,43,'|  /   \',0
	db 9,9,'|',0
	db 9,43,'|  :   :',0
	db 10,9,'|',0
	db 10,43,'| _;,,,;_   ____',0
	db 11,9,'|',0
	db 11,43,'|          /    \',0
	db 12,9,'|',0
	db 12,43,'|          :    :',0
	db 13,9,'|',0
	db 13,43,'|          :    :',0
	db 14,9,'|',0
	db 14,43,'|         _;,,,,;_',0
	db 15,9,'|            killed by            |',0
	db 16,9,'|',0
	db 16,43,'|',0
	db 17,9,'|',0
	db 17,43,'|',0
	db 18,8,'*|   *     *     *    *   *     *  | *',0
	db 19,0,'________)/\\_)_/___(\/___(//_\)/_\//__\\(/_|_)_______',0
	db $FF

; ctime's names for the date
tomb_days:	db "SunMonTueWedThuFriSat"
tomb_months:	db "JanFebMarAprMayJunJulAugSepOctNovDec"
tomb_sakamoto:	db 0,3,2,5,0,3,5,1,4,6,2,4
