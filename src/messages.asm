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

txt_depth:		db "Depth ",0
txt_feet:		db " ft",0
txt_pos_x:		db "   X:",0
txt_pos_y:		db "  Y:",0
txt_keys:		db "Move: hjkl yubn / cursors   Stairs: < >"
txt_keys_len	equ $-txt_keys
				db 0
