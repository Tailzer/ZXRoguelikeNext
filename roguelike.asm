/* Roguelike - an Angband-inspired dungeon crawler for the ZX Spectrum Next
	Written from scratch in Z80N assembly, using Angband PC 1.2 (C source)
	as the design reference.

	Milestone 1: Walkabout - 80x32 tilemap text, movement, doors, scrolling
	Milestone 2: Dungeon generator - GENERATE.C rooms, tunnels, doors,
		streamers and stairs; > and < change level
	Milestone 3: Lighting - Moria-style lit rooms, 3x3 player light,
		remembered walls/doors/stairs
	Milestone 4a: Monsters - 10 races from MONSTERS.C, placement and packs,
		los(), sleep/wake, speed, chasing and erratic movement
	Milestone 4b: Combat - make_attack, py_attack, criticals, experience
		and levels, hit point regeneration, death and restart

	Memory map (16K view):
		$0000-$3FFF  ROM (font copied from ROM 3 at start-up)
		$4000-$5FFF  bank 5 - ULA screen (unused, ULA is switched off)
		$6000-$73FF  tilemap, 80x32 cells x 2 bytes (char, attribute)
		$7400-$7BFF  tile definitions, 256 x 8 bytes (1-bit text mode)
		$8000-$AFFF  bank 2 - code, data
		$B000-$B3FF  monster list
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
	call interrupt_init

	ld hl,msg_press_key
	call show_message
	call wait_any_key					; timing of the key press seeds the RNG
enter_dungeon:
	call player_init
	ld a,1
	ld (dun_level),a
	call msg_clear
	call new_level
	call msg_clear
	ld hl,msg_welcome
	call show_message

main_loop:
	call draw_view
	call draw_status
	ld a,(p_dead)
	or a
	jr nz,player_died
	call get_command					; D = command, B = dx, C = dy
	push bc
	push de
	call msg_clear						; old messages go once you act
	pop de
	pop bc
	xor a
	ld (turn_taken),a
dispatch:
	ld a,d
	cp CMD_DOWN
	jr z,.down
	cp CMD_UP
	jr z,.up
	cp CMD_STAY
	jr z,.stay
	call try_move
.after:
	ld a,(turn_taken)					; the world moves on after any
	or a								; action that took a turn
	jr z,main_loop
	ld hl,(game_turn)
	inc hl
	ld (game_turn),hl
	call update_view
	call monsters_act
	call regenhp
	jr main_loop
.stay:
	ld a,1
	ld (turn_taken),a
	jr .after
.down:
	call go_down
	jr main_loop
.up:
	call go_up
	jr main_loop

/* player_died - message, a simple tombstone, then a fresh start */
player_died:
	ld hl,txt_you_die
	call msg_print
	call wait_fresh_key
	call clear_screen
	ld hl,txt_rip
	ld d,10
	ld e,37
	ld c,ATTR_WHITE
	call print_at
	call msg_begin						; "Killed by a Jackal"
	ld hl,txt_killed_by
	call msg_add
	ld a,(killer_race)
	call race_addr
	ld l,(iy+R_NAME)
	ld h,(iy+R_NAME+1)
	ld a,(hl)
	ld hl,txt_a
	cp 'A'
	jr z,.an
	cp 'E'
	jr z,.an
	cp 'I'
	jr z,.an
	cp 'O'
	jr z,.an
	cp 'U'
	jr nz,.article
.an:
	ld hl,txt_an
.article:
	call msg_add
	ld l,(iy+R_NAME)
	ld h,(iy+R_NAME+1)
	call msg_add
	ld hl,(msg_ptr)
	ld (hl),0
	ld hl,msg_buf
	ld d,12
	ld e,30
	ld c,ATTR_GREY
	call print_at
	call msg_begin						; "on level 3"
	ld hl,txt_on_level
	call msg_add
	ld a,(dun_level)
	call msg_add_u8
	ld hl,(msg_ptr)
	ld (hl),0
	ld hl,msg_buf
	ld d,13
	ld e,30
	ld c,ATTR_GREY
	call print_at
	ld hl,txt_try_again
	ld d,16
	ld e,25
	ld c,ATTR_DARK
	call print_at
	call wait_fresh_key
	call clear_screen
	jp enter_dungeon

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
	include "src/random.asm"
	include "src/map.asm"
	include "src/generate.asm"
	include "src/light.asm"
	include "src/los.asm"
	include "src/monsters.asm"
	include "src/races.asm"
	include "src/combat.asm"
	include "src/view.asm"
	include "src/player.asm"
	include "src/messages.asm"
	include "src/variables.asm"

code_end:
	ASSERT code_end <= MON_LIST, "Code has run into the monster list"

	SAVENEX OPEN "build/roguelike.nex", start, stack_top
	SAVENEX CORE 3,0,0
	SAVENEX CFG 0,0,0,0
	SAVENEX AUTO
	SAVENEX CLOSE
