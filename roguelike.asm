/* Roguelike - an Angband-inspired dungeon crawler for the ZX Spectrum Next
	Written from scratch in Z80N assembly, using Angband PC 1.2 (C source)
	as the design reference.

	Milestone 1: Walkabout
		80x32 tilemap text display
		Hand-built test level (rooms, corridors, doors)
		Player '@' moves in 8 directions, walls block, doors open on bump
		View scrolls when the player nears the edge

	Memory map (16K view):
		$0000-$3FFF  ROM (font copied from ROM 3 at start-up)
		$4000-$5FFF  bank 5 - ULA screen (unused, ULA is switched off)
		$6000-$73FF  tilemap, 80x32 cells x 2 bytes (char, attribute)
		$7400-$7BFF  tile definitions, 256 x 8 bytes (1-bit text mode)
		$8000-$BBFF  bank 2 - code, data
		$BC00-$BDBF  IM2 vector table and jump
		$BEC0-$BFFF  stack
		$C000-$FFFF  MMU6/7 = pages MAP_PAGE, MAP_PAGE+1 - dungeon map
 */

	DEVICE ZXSPECTRUMNEXT
	OPT --zxnext
	CSPECTMAP "build/roguelike.map"

	include "src/constants.asm"

	org CODE_START
start:
	di
	ld sp,stack_top
	nextreg NR_CPU_SPEED,3				; 28MHz

	call memory_init
	call video_init
	call map_build_test
	call interrupt_init

	ld a,PLAYER_START_X
	ld (player_x),a
	ld a,PLAYER_START_Y
	ld (player_y),a

	ld hl,msg_welcome
	call show_message

main_loop:
	call draw_view
	call draw_status
	call get_move_key					; B = dx, C = dy
	push bc
	ld d,MSG_ROW
	call clear_row						; old message goes once you act
	pop bc
	call try_move
	jr main_loop

/* memory_init - select ROM 3 (48K BASIC, has the font) and page in the map */
memory_init:
	ld bc,$7FFD
	ld a,%00010000						; ROM bit 0 = 1
	out (c),a
	ld bc,$1FFD
	ld a,%00000100						; ROM bit 1 = 1 -> ROM 3
	out (c),a
	nextreg NR_MMU0,$FF					; ROM in slots 0/1
	nextreg NR_MMU1,$FF
	nextreg NR_MMU2,10					; bank 5 at $4000
	nextreg NR_MMU3,11
	nextreg NR_MMU6,MAP_PAGE			; map at $C000 (after $7FFD write,
	nextreg NR_MMU7,MAP_PAGE+1			; which also touches MMU6/7)
	ret

	include "src/video.asm"
	include "src/input.asm"
	include "src/map.asm"
	include "src/view.asm"
	include "src/player.asm"
	include "src/messages.asm"
	include "src/variables.asm"

code_end:
	ASSERT code_end <= IM2_TABLE, "Code has run into the IM2 table"

	SAVENEX OPEN "build/roguelike.nex", start, stack_top
	SAVENEX CORE 3,0,0
	SAVENEX CFG 0,0,0,0
	SAVENEX AUTO
	SAVENEX CLOSE
