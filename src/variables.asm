/* variables.asm - game state */

player_x:		db 0
player_y:		db 0
view_x:			db 0				; map square shown at the view's top-left
view_y:			db 0

held_key:		db KEY_NONE
repeat_timer:	db 0

carve_terrain:	db 0
frame_counter:	db 0
