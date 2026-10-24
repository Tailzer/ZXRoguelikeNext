/* killers.asm - what the tombstone says killed you, when it wasn't a
	monster: killer_race $FExx (data page ACT_PAGE, after data/activate.asm;
	death.asm pages it in) */

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
