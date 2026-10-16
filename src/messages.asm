/* messages.asm - text */

msg_welcome:	db "Welcome to the dungeon.",0
msg_wall:		db "There is a wall in the way.",0
msg_door_open:	db "You open the door.",0

txt_pos_x:		db "X:",0
txt_pos_y:		db "  Y:",0
txt_keys:		db "Move: hjkl yubn / cursors"
txt_keys_len	equ $-txt_keys
				db 0
