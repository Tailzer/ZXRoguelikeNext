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
