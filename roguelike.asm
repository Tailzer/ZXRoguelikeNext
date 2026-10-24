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
	Milestone 8: The town - town_gen with day and night, townsfolk, and the
		eight stores: stock, owners and prices from STORE1.C/STORE2.C
	Milestone 9a-1: Potions - flavours and identification, every potion in
		POTIONS.C, current/max stats, and DUNGEON.C's timed effects
	Milestone 9a-2: Scrolls - the r command and 30 scrolls from SCROLLS.C,
		titled per game; monster confusion, protection from evil
	Milestone 9b: Devices - wands, staffs and rods (WANDS.C, STAFFS.C,
		RODS.C): charges, bolts, balls and beams; 9-bit item kinds
	Milestone 9c-1: Pluses - magic_treasure's to-hit, to-dam and AC, curses,
		enchant and curse scrolls, item feelings
	Milestone 9c-2: Rings and amulets - flavours, neck and ring slots,
		stat, speed and other bonuses, sustains, resistances
	Milestone 9c-3a: Ego items - magic_treasure's egos, slays and brands,
		stealth, infravision, regeneration, telepathy
	Milestone 9c-3b: Artifacts - unique_weapon, unique_armour, the cloaks
		and the special objects, each once a game
	Milestone 9c-3c: Activation - the A command, activate()'s effects and
		recharging
	Milestone 9d-1: Mage spells - books, learning, mana, browsing and
		casting, all 59 mage spells
	Milestone 9d-2: Prayers - priests and paladins learn and recite the
		58 prayers
	Milestone 9d-3a: Monster spells - curses, mind blasts, the classic
		breaths, bolts and balls, teleports and summons
	Milestone 9d-3b: The rest of the monster spells - the exotic breaths,
		nether, nexus, time, gravity, forgetting and the bigger summons
	Milestone 9d-4: Monster blows - stat drains, poison, paralysis,
		theft, elements, criticals and the cave-shaking blows
	Milestone 10: Saving - Symbol Shift + X saves to roguelike.sav on the
		SD card (esxDOS); a key at the title carries on from it
	Milestone 11: Light sources - torches, lanterns and oil, a light slot,
		fuel burning down, and the dark without them; searching for
		secret doors ('s', and as you walk)
	Milestone 12: Traps - the 18 traps and rubble, found by searching
		or magic, 'D' to disarm and 'T' to tunnel
	Milestone 13a: Throwing - 'v' throws anything, flasks of oil burn
	Milestone 13b: Bows - slings, bows and crossbows, their ammunition,
		Beleg Cuthalion, Bard and Cubragol
	Milestone 14a: Resting and running - 'R', and Caps Shift + a direction
	Milestone 14b: Doors - locked, stuck and broken; o, c, f and S
	Milestone 14c: Looking around - look, the map, locate, ^P, symbols
	Milestone 15: The endgame - Sauron's quest, Morgoth, winning, retiring
	Milestone 16: Dungeon variety - inner rooms, crosses, vaults, pits
	Milestone 17: Chests and what monsters drop - monster_death, the six
		chests and their traps; o, D, f, searching and magic on them
	Milestone 18: Monster memory - what each race has been seen to do and
		be, learnt as the C learns it; r in look, / and roguelike.mem
	Milestone 19: Monsters in the walls - passing through rock, and boring
		through it and through doors

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
	call interrupt_init
	FARCALL PAGE_MISC, hold_loading		; the loading screen stays a while
	FARCALL PAGE_MISC, video_init
	FARCALL PAGE_LOOK, log_clear		; (no messages yet)

	ld hl,msg_press_key
	call show_message
	call wait_any_key					; timing of the key press seeds the RNG
	call rng_mix
	FARCALL PAGE_SAVE, load_game		; a saved game carries on
	jr nc,enter_dungeon
	call clear_screen
	call msg_clear
	call update_view
	jp main_loop
enter_dungeon:
	FARCALL PAGE_CREATE, create_character
	call clear_screen
	FARCALL PAGE_MISC, player_init
	call rand16							; a new town for a new character
	ld (town_seed),hl
	FARCALL PAGE_STORE, store_init		; and new shopkeepers
	xor a								; start in town, as the C does
	ld (dun_level),a
	call msg_clear
	call new_level
	call msg_clear
	ld hl,msg_welcome
	call show_message

main_loop:
	call draw_view						; (first redoes bonuses: update_stuff)
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
	FARCALL PAGE_RUN, next_command		; D = command, B = dx, C = dy (or
										; resting, or running)
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
	jp z,.down
	cp CMD_UP
	jp z,.up
	cp CMD_STAY
	jp z,.stay
	cp CMD_CHARACTER
	jp z,.character
	cp CMD_SAVE
	jp z,.save
	cp CMD_DISARM
	jp z,.disarm
	cp CMD_TUNNEL
	jp z,.tunnel
	cp CMD_THROW
	jp z,.throw
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
	ld (mana_regen),a
	ld b,a
	ld hl,(p_poisoned)					; not while poisoned or bleeding
	ld de,(p_cut)
	ld a,h
	or l
	or d
	or e
	ld a,b
	call z,regenhp
	ld a,(mana_regen)					; mana comes back too
	FARCALL PAGE_SPELL, regenmana
	FARCALL PAGE_MAGIC, timed_tick
	ld a,(p_eflags+1)					; a ring of teleportation
	bit EF1_TELEPORT,a
	call nz,random_teleport
	ld a,(end_event)					; Sauron or Morgoth fell
	or a
	jr z,.no_end
	FARCALL PAGE_LOOK, end_event_now
.no_end:
	ld a,(p_new_level)					; word of recall
	or a
	jp z,main_loop
	push af
	xor a
	ld (p_new_level),a
	call new_level
	pop af
	ld hl,msg_yanked_up
	cp 1
	jr z,.yanked
	ld hl,msg_yanked_down
	cp 2
	jr z,.yanked
	ld hl,msg_trap_door					; (said once the new level is up)
	cp 4
	jp nz,main_loop
.yanked:
	call show_message
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
	call pending_actions				; e.g. the potion chosen to quaff
	jp .after
.stay:									; 's': search for a turn
	ld a,1
	ld (turn_taken),a
	call search
	jp .after
.disarm:								; D, T: traps and digging
	FARCALL PAGE_TRAP, cmd_disarm
	jp .after
.tunnel:
	FARCALL PAGE_TRAP, cmd_tunnel
	jp .after
.throw:
	FARCALL PAGE_TRAP, cmd_throw
	jp .after
.character:
	FARCALL PAGE_CREATE, show_character
	jp main_loop
.save:									; ^X: save, then back to the title
	FARCALL PAGE_SAVE, save_game
	jp nc,main_loop
	jp start
.down:
	call go_down
	jp main_loop
.up:
	call go_up
	jp main_loop

item_commands:							; in CMD_INVEN order
	dw cmd_inventory, cmd_equipment, cmd_wield, cmd_takeoff
	dw cmd_quaff, cmd_eat, cmd_drop, cmd_pickup
	dw 0, cmd_read						; (CMD_CHARACTER is handled above)
	dw cmd_aim, cmd_use, cmd_zap, cmd_activate
	dw cmd_cast, cmd_browse, cmd_study, cmd_pray
	dw 0, cmd_fuel						; (CMD_SAVE is handled above)
	dw 0, 0, 0, 0, cmd_rest_turn		; (disarm, tunnel, throw, rest: above)
	dw cmd_open, cmd_close, cmd_bash, cmd_spike
	dw cmd_look, cmd_map, cmd_locate, cmd_messages, cmd_symbol, cmd_knowledge
	dw cmd_quit
player_died:
	FARCALL PAGE_SAVE, delete_save		; (a dead character's save goes)
	FARCALL PAGE_LOOK, end_screens		; (a winner retiring: the crown)
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
	include "src/pack.asm"
	include "src/status.asm"
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
	include "src/magic_items.asm"
	include "src/magic_init.asm"
misc_end:
	ASSERT misc_end <= $6000, "Misc overlay is over 8K"

	MMU 2, PAGE_ITEMS, $4000
	include "src/inventory.asm"
	include "src/knowledge.asm"
	include "data/blows.asm"			; generated: blows_table
items_end:
	ASSERT items_end <= $6000, "Items overlay is over 8K"

	MMU 2, PAGE_CREATE, $4000
	include "src/create.asm"
	include "src/death.asm"
	include "data/player.asm"			; generated: races, classes, kits, titles
create_end:
	ASSERT create_end <= $6000, "Creation overlay is over 8K"

	MMU 2, PAGE_STORE, $4000
	include "src/store.asm"
	include "data/stores.asm"			; generated: owners, prices, stock lists
store_end:
	ASSERT store_end <= $6000, "Store overlay is over 8K"

	MMU 2, PAGE_MAGIC, $4000
	include "src/potions.asm"
	include "src/effects.asm"
magic_end:
	ASSERT magic_end <= $6000, "Magic overlay is over 8K"

	MMU 2, PAGE_SCROLL, $4000
	include "src/scrolls.asm"
scroll_end:
	ASSERT scroll_end <= $6000, "Scroll overlay is over 8K"

	MMU 2, PAGE_SPELL, $4000
	include "src/spells.asm"
spell_end:
	ASSERT spell_end <= $6000, "Spell overlay is over 8K"

	MMU 2, PAGE_MCAST, $4000
	include "src/mcast.asm"
	include "src/mexotic.asm"
	include "src/mmelee.asm"
mcast_end:
	ASSERT mcast_end <= $6000, "Monster spell overlay is over 8K"

	MMU 2, PAGE_TRAP, $4000
	include "src/traps.asm"
	include "src/throw.asm"
	include "src/doors.asm"
trap_end:
	ASSERT trap_end <= $6000, "Trap overlay is over 8K"

	MMU 2, PAGE_LOOK, $4000
	include "src/look.asm"
	include "src/endgame.asm"
look_end:
	ASSERT look_end <= $6000, "Look overlay is over 8K"

	MMU 2, PAGE_ROOMS, $4000
	include "src/rooms.asm"
rooms_end:
	ASSERT rooms_end <= $6000, "Rooms overlay is over 8K"

	MMU 2, PAGE_CHEST, $4000
	include "src/chests.asm"
chest_end:
	ASSERT chest_end <= $6000, "Chest overlay is over 8K"

	MMU 2, PAGE_RECALL, $4000
	include "src/recall.asm"
	include "src/combine.asm"
recall_end:
	ASSERT recall_end <= $6000, "Recall overlay is over 8K"

	MMU 2, PAGE_RUN, $4000
	include "src/rest_run.asm"
	include "src/keys.asm"
run_end:
	ASSERT run_end <= $6000, "Run overlay is over 8K"

	MMU 2, PAGE_SAVE, $4000
	include "src/save.asm"
save_end:
	ASSERT save_end <= $6000, "Save overlay is over 8K"

	MMU 2, PAGE_DEVICE, $4000
	include "src/devices.asm"
device_end:
	ASSERT device_end <= $6000, "Device overlay is over 8K"

; ---- data pages: paged into slot 1 ($2000-$3FFF) by race_addr / kind_addr ----
; (the ROM there is only needed at start-up, to copy the font)

	MMU 1 n, RACE_PAGE, DATA_WINDOW		; 128 races per page, onto the next page
	include "data/races.asm"
races_end:
	ASSERT $$races_end < RACE_PAGE+5 || (races_end == DATA_WINDOW && $$races_end == RACE_PAGE+5), "Races run past their pages"

	MMU 1 n, KIND_PAGE, DATA_WINDOW		; 128 kinds per page, then the flavours
	include "data/kinds.asm"
kinds_end:
	ASSERT $$kinds_end < KIND_PAGE+3 || ($$kinds_end == KIND_PAGE+3 && kinds_end == DATA_WINDOW), "Kinds run past their pages"

	MMU 1 n, FLAVOUR_PAGE, DATA_WINDOW	; flavours, titles, normal_table
	include "data/flavours.asm"			; generated: potion colours
flavours_end:
	ASSERT $$flavours_end == FLAVOUR_PAGE, "Flavours run past their page"

	MMU 1 n, EGO_PAGE, DATA_WINDOW		; ego items: names, flags, values
	include "data/egos.asm"
egos_end:
	ASSERT $$egos_end == EGO_PAGE, "Egos run past their page"

	MMU 1 n, ACT_PAGE, DATA_WINDOW		; activation: effects and messages
	include "data/activate.asm"
	include "src/killers.asm"			; what kills you, when not a monster
acts_end:
	ASSERT $$acts_end == ACT_PAGE, "Activations run past their page"

	MMU 1 n, SPELL_PAGE, DATA_WINDOW	; spells: each class's, their names
	include "data/spells.asm"
spells_end:
	ASSERT $$spells_end == SPELL_PAGE, "Spells run past their page"

	MMU 1 n, MSPELL_PAGE, DATA_WINDOW	; monster spells, 12 bytes a race
	include "data/mspells.asm"
mspells_end:
	ASSERT $$mspells_end == MSPELL_PAGE, "Monster spells run past their page"

	MMU 1 n, RINFO_PAGE, DATA_WINDOW	; each race's C flags, its description
	include "data/recall.asm"
rinfo_end:
	ASSERT $$rinfo_end == RINFO_PAGE, "Race flags run past their page"

	include "data/descs.asm"			; the descriptions, from DESC_PAGE
	ASSERT NUM_DESC_PAGES <= 6, "Descriptions need more pages"

	MMU 1 n, MTEXT_PAGE, DATA_WINDOW	; what monster spells and blows say
	include "src/mcast_text.asm"
mtext_end:
	ASSERT $$mtext_end == MTEXT_PAGE, "Monster texts run past their page"

; ---- the loading screen: assets/loading.sl2, a 256 x 192 Layer 2 screen
; in the Next's default palette (so the NEX carries no palette for it), in
; pages 18-23 just long enough for SAVENEX SCREEN to take it into the header
LOAD_SCREEN_PAGE	equ 18					; 6 pages of picture
	MMU 0 5, LOAD_SCREEN_PAGE, $0000
	INCBIN "assets/loading.sl2"

	SAVENEX OPEN "build/roguelike.nex", start, stack_top
	SAVENEX CORE 3,0,0
	SAVENEX CFG 0,0,0,0
	SAVENEX SCREEN L2 LOAD_SCREEN_PAGE, 0

lsp = LOAD_SCREEN_PAGE						; (then gone again, so AUTO doesn't
	DUP 6									;  save it as the game's memory too)
	MMU 0, lsp, $0000
	DS 8192, 0
lsp = lsp + 1
	EDUP
	SAVENEX AUTO
	SAVENEX CLOSE
