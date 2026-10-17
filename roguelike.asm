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
	Milestone 5: Items - 13 kinds and 18 treasures from TREASURE.C on the
		floor, pack and equipment, wield/wear, quaff, eat, hunger
	Milestone 6: Data - tools/convert.py turns MONSTERS.C and TREASURE.C into
		data pages: all 549 races, every usable item kind, level tables
	Milestone 7: Characters - CREATE.C's race, sex, class, stat rolling and
		name; stats feed combat, hit points, stealth and infravision

	Memory map (16K view):
		$0000-$3FFF  ROM (font copied from ROM 3 at start-up)
		$2000-$3FFF  data window: race/kind pages, paged in by race_addr and
		             kind_addr (ROM until start-up has copied the font)
		$4000-$5FFF  overlay window: PAGE_LEVEL / PAGE_MISC paged in by
		             FARCALL (normally the unused ULA screen)
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
	FARCALL PAGE_MISC, video_init
	call interrupt_init

	ld hl,msg_press_key
	call show_message
	call wait_any_key					; timing of the key press seeds the RNG
	call rng_mix
enter_dungeon:
	FARCALL PAGE_CREATE, create_character
	call clear_screen
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
	jp nz,player_died
	ld a,(p_paralysed)					; fainted: the turn passes anyway
	or a
	jr z,.awake
	dec a
	ld (p_paralysed),a
	ld a,1
	ld (turn_taken),a
	jr dispatch.after
.awake:
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
	cp CMD_CHARACTER
	jr z,.character
	cp CMD_INVEN
	jr nc,.item_command
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
	call hunger_tick					; A = how fast we heal
	call regenhp
	jp main_loop
.item_command:							; i e w t q E d g, in the items overlay
	sub CMD_INVEN
	add a,a
	ld hl,item_commands
	add hl,a
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	ld (.target+1),hl
	nextreg NR_MMU2,PAGE_ITEMS
.target:
	call 0
	jr .after
.stay:
	ld a,1
	ld (turn_taken),a
	jr .after
.character:
	FARCALL PAGE_CREATE, show_character
	jp main_loop
.down:
	call go_down
	jp main_loop
.up:
	call go_up
	jp main_loop

item_commands:							; in CMD_INVEN order
	dw cmd_inventory, cmd_equipment, cmd_wield, cmd_takeoff
	dw cmd_quaff, cmd_eat, cmd_drop, cmd_pickup
player_died:
	FARCALL PAGE_CREATE, player_died_screen
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
	include "src/light.asm"
	include "src/los.asm"
	include "src/monsters.asm"
	include "data/tables.asm"			; generated: constants, treasures
	include "src/combat.asm"
	include "src/items.asm"
	include "src/view.asm"
	include "src/player.asm"
	include "src/messages.asm"
	include "src/variables.asm"

code_end:
	ASSERT code_end <= MON_LIST, "Code has run into the monster list"

; ---- overlays: 8K pages paged into slot 2 ($4000-$5FFF) by FARCALL ----
; Overlay code may call resident code, but never another overlay.

	MMU 2, PAGE_LEVEL, $4000
	include "src/generate.asm"
	include "src/populate.asm"
	include "data/alloc.asm"			; generated: level tables
level_end:
	ASSERT level_end <= $6000, "Level overlay is over 8K"

	MMU 2, PAGE_MISC, $4000
	include "src/startup.asm"
misc_end:
	ASSERT misc_end <= $6000, "Misc overlay is over 8K"

	MMU 2, PAGE_ITEMS, $4000
	include "src/inventory.asm"
	include "data/blows.asm"			; generated: blows_table
items_end:
	ASSERT items_end <= $6000, "Items overlay is over 8K"

	MMU 2, PAGE_CREATE, $4000
	include "src/create.asm"
	include "src/death.asm"
	include "data/player.asm"			; generated: races, classes, kits, titles
create_end:
	ASSERT create_end <= $6000, "Creation overlay is over 8K"

; ---- data pages: paged into slot 1 ($2000-$3FFF) by race_addr / kind_addr ----
; (the ROM there is only needed at start-up, to copy the font)

	MMU 1 n, RACE_PAGE, DATA_WINDOW		; 128 races per page, onto the next page
	include "data/races.asm"
races_end:
	ASSERT $$races_end < RACE_PAGE+5 || (races_end == DATA_WINDOW && $$races_end == RACE_PAGE+5), "Races run past their pages"

	MMU 1, KIND_PAGE, DATA_WINDOW
	include "data/kinds.asm"
kinds_end:
	ASSERT kinds_end <= DATA_WINDOW+$2000, "Kinds are over one page"

	SAVENEX OPEN "build/roguelike.nex", start, stack_top
	SAVENEX CORE 3,0,0
	SAVENEX CFG 0,0,0,0
	SAVENEX AUTO
	SAVENEX CLOSE
