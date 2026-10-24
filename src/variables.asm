/* variables.asm - game state */

dun_level:		db 1				; depth, 50ft per level (0 = town, later)
player_x:		db 0
player_y:		db 0
view_x:			db 0				; map square shown at the view's top-left
view_y:			db 0

held_key:		db KEY_NONE
repeat_timer:	db 0

carve_terrain:	db 0
frame_counter:	dw 0
rng_state:		dw $ACE1

print_attr:		db 0
print_started:	db 0

game_turn:		dw 0
turn_taken:		db 0				; set when the player's action used a turn
msg_ptr:		dw 0
msg_col:		db 0				; where the next message goes
log_next:		db 0				; the message history's next line
end_event:		db 0				; 1 Sauron, 2 Morgoth died (endgame.asm)
end_y:			db 0
end_x:			db 0
town_seed:		dw 0				; the town is built from this each visit
town_night:		db 0
