/* messages.asm - text */

msg_press_key:	db "Press any key to enter the dungeon.",0
msg_generating:	db "Generating level...",0
msg_welcome:	db "Welcome to the dungeon.",0
msg_wall:		db "There is a wall in the way.",0
msg_door_open:	db "You open the door.",0
msg_down:		db "You enter a maze of down staircases.",0
msg_up:			db "You enter a maze of up staircases.",0
msg_no_down:	db "I see no down staircase here.",0
msg_no_up:		db "I see no up staircase here.",0
msg_something:	db "Something is in the way.",0
txt_the:		db "The ",0
txt_in_way:		db " is in the way.",0
txt_threatens:	db " is next to you!",0

txt_the_lc:		db "the ",0
txt_it:			db "It",0
txt_it_lc:		db "it",0
txt_space:		db " ",0
txt_full_stop:	db ".",0
txt_more:		db "-more-",0
txt_you_hit:	db "You hit ",0
txt_you_miss:	db "You miss ",0
txt_you_slain:	db "You have slain ",0
txt_misses_you:	db " misses you.",0
txt_welcome_level: db "Welcome to level ",0
txt_good_hit:	db "It was a good hit!",0
txt_excellent_hit: db "It was an excellent hit!",0
txt_superb_hit:	db "It was a superb hit!",0
txt_great_hit:	db "It was a *GREAT* hit!",0
txt_you_destroyed: db "You have destroyed ",0
; status line
txt_lev:		db "Lv ",0
txt_exp:		db "  Exp ",0
txt_hp:			db "  HP ",0
txt_slash:		db "/",0
txt_sp:			db "  SP ",0
txt_gold:		db "  AU ",0
txt_depth:		db "  ",0
txt_hungry:		db "  Hungry",0
txt_weak:		db "  Weak",0
msg_hungry:		db "You are getting hungry.",0
msg_weak:		db "You are getting weak from hunger.",0
msg_faint:		db "You faint from the lack of food.",0
txt_feet:		db " ft",0
txt_town:		db "  Town",0
				db 0
msg_yanked_up:	db "You feel yourself yanked upwards!",0
msg_yanked_down: db "You feel yourself yanked downwards!",0
msg_trap_door:	db "You fell through a trap door!",0
msg_too_afraid:	db "You are too afraid!",0
msg_no_light:	db "You have no light to read by.",0
