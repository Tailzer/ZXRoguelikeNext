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
msg_no_town:	db "The town hasn't been built yet.",0
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
; monster attack descriptions 1-18 (make_attack)
txt_hits:		db "hits you.",0
txt_bites:		db "bites you.",0
txt_claws:		db "claws you.",0
txt_stings:		db "stings you.",0
txt_touches:	db "touches you.",0
txt_kicks:		db "kicks you.",0
txt_gazes:		db "gazes at you.",0
txt_breathes:	db "breathes on you.",0
txt_spits:		db "spits on you.",0
txt_wails:		db "makes a horrible wail.",0
txt_embraces:	db "embraces you.",0
txt_crawls:		db "crawls on you.",0
txt_spores:		db "releases a cloud of spores.",0
txt_begs:		db "begs you for money.",0
txt_slimed:		db "slimes you.",0
txt_crushes:	db "crushes you.",0
txt_tramples:	db "tramples you.",0
txt_drools:		db "drools on you.",0
; status line
txt_lev:		db "Lv ",0
txt_exp:		db "  Exp ",0
txt_hp:			db "  HP ",0
txt_slash:		db "/",0
txt_depth:		db "  ",0
txt_feet:		db " ft",0
txt_keys:		db "hjkl yubn  s stay  < >"
txt_keys_len	equ $-txt_keys
				db 0
