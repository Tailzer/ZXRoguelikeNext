# Roguelike (ZX Spectrum Next)

Angband-inspired dungeon crawler written from scratch in Z80N assembly.
Design reference: Angband PC 1.2 C source (`~/Downloads/angband-pc1.2/SRC`).

## Build / run

- `./build.sh` — assembles `roguelike.asm` to `build/roguelike.nex` (plus `.sld`, `.lst`, `.map`)
- `./run.sh` — builds and runs it in CSpect at 28MHz
- `tools/convert.py [path to Angband SRC]` — regenerates `data/*.asm` from `MONSTERS.C` and `TREASURE.C` (only needed when the converter changes; the generated files are committed, with the original copyright notice the licence asks for)
- In VS Code: the default build task builds; DeZog has a "CSpect" config (start CSpect with `-remote` first)

## Character

Created at the start of each game as in `CREATE.C`: choose a race (10), sex and class (6, as the race allows), roll stats (space rolls again, Enter accepts), then type a name (Caps Shift+0 deletes). Race and class set the hit die, base to-hit, stealth, infravision and experience factor; stats give to-hit, damage, armour class, hit points per level and blows. The class's starting kit comes from `player_init[]`, minus torches, books and potions the game can't use yet. Background history isn't generated (social class is taken as 50 for starting gold).

## Controls

`h j k l y u b n` (Angband roguelike keys) or cursor keys `5 6 7 8`.
Walk into a closed door to open it, or into a monster to attack it; walking onto an item picks it up. `s` stays still for a turn. `>` (Symbol Shift+T) / `<` (Symbol Shift+R) take stairs.

`C` (Caps Shift+C) shows the character sheet.

Items: `i` inventory, `e` equipment, `w` wear/wield, `t` take off, `q` quaff, `E` (Caps Shift+E) eat, `d` drop, `g` pick up. Choose items by letter; space cancels.

## Milestones

1. **Walkabout** — tilemap text, test level, movement, scrolling view *(done)*
2. **Dungeon generator** — rooms and corridors (`GENERATE.C`), stairs, new levels *(done; vaults, pits and room types 2/3 still to come)*
3. **Lighting** — lit rooms light up on entry, 3x3 player light, remembered walls/doors/stairs (`MORIA1.C` light_room, move_light) *(done)*
4. **Monsters** (`CREATURE.C`, `MONSTERS.C`, `MISC1.C`)
   - 4a: 10 races, placement and packs, `los()`, sleep/wake, speed, chasing and erratic movement *(done)*
   - 4b: melee both ways (make_attack, py_attack, criticals), experience and levels, hit point regeneration, death and restart *(done)*
   - not yet: monster attack side effects (confusion, cuts, stuns), real stats/equipment
5. **Items** (`TREASURE.C`, `MORIA2.C` carry, `POTIONS.C`, `EAT.C`, `DUNGEON.C` hunger) *(done)*
   - 13 kinds (food, Cure Light/Serious Wounds, 5 weapons, 5 armours) and the 18 treasures, placed per level like `cave_gen()`
   - pack (a-l, stacking), equipment slots (weapon, body, arm, head), auto pick-up, hunger and starvation
   - not yet: magical pluses, unknown potion flavours, light sources, weight limits, overeating slowness
6. **Data converter** (`tools/convert.py`) *(done)*
   - all 549 monster races and 102 usable item kinds, in data pages; `get_mons_num` / `get_obj_num` level tables
   - uniques once only, max-hp monsters, invisible monsters unseen; cloak, gloves and boots slots
   - not yet: monster spells and breath, breeding, wall-passing, attack side effects (poison, stealing...), item types other than food, healing potions, weapons and armour
7. **Character creation** (`CREATE.C`, `PLAYER.C`, `MISC2.C` stat tables) *(done)*
8. Magic, stores, the town, saving to SD card

## Memory map

| Address | Contents |
|---|---|
| `$0000-$1FFF` | ROM 3 |
| `$2000-$3FFF` | **data window** (MMU slot 1): a race or kind page, paged in by `race_addr` / `kind_addr` (ROM 3 until start-up has copied the font) |
| `$4000-$5FFF` | **overlay window** (MMU slot 2): an overlay page, paged in by `FARCALL` |
| `$6000-$73FF` | tilemap, 80x32 x (char, attr) |
| `$7400-$7BFF` | tile definitions (1-bit text mode) |
| `$8000-$AFFF` | resident code and data (bank 2) |
| `$B000-$B3FF` | monster list, 64 x 16 bytes |
| `$B400-$B5FF` | floor items, 64 x 8 bytes |
| `$B600-$B697` | pack (12 x 8) then equipment (7 x 8) |
| `$B6A0-$B7CF` | the character's hit points per level (50 words) and experience needed per level (50 dwords) |
| `$BC00-$BDBF` | IM2 vector table + jump |
| `$BEC0-$BFFF` | stack |
| `$C000-$F30B` | dungeon map, 198x66 bytes (pages 32/33): low 4 bits terrain, bit 4 room, bit 5 lit/remembered, bit 6 player light, bit 7 monster here |
| `$F400-$FEA3` | scratch: tunnel/wall/door stacks and room list while generating; room-lighting queue in play |

## Code banks

Code that runs every turn is **resident** in bank 2. Code that runs rarely lives in 8K **overlay** pages, assembled at `$4000` and paged into the overlay window by `FARCALL page, routine`. The ULA screen is switched off, so its page is free to be swapped out, and the tilemap in the next page keeps displaying whatever is in the window.

| Page | Contents | Used |
|---|---|---|
| 40 `PAGE_LEVEL` | `generate.asm`, `populate.asm` | building a new level |
| 41 `PAGE_MISC` | `startup.asm` | power-on |
| 42 `PAGE_ITEMS` | `inventory.asm`, `data/blows.asm` | item commands, picking up, starting kit |
| 43 `PAGE_CREATE` | `create.asm`, `death.asm`, `data/player.asm` | making a character, the `C` sheet, the tombstone |

Data pages (slot 1, `$2000`): 44-48 `RACE_PAGE` = `data/races.asm` (128 x 64-byte races per page, name inline); 49 `KIND_PAGE` = `data/kinds.asm`. The level tables (`data/alloc.asm`) live in the level overlay and the treasures (`data/tables.asm`) are resident.

Resident code ends around `$9CA0` after milestone 7, about 5K below the monster list. The creation overlay (page 43) is nearly full (7.8K of 8K); the others have plenty of room.

Rules: only resident code uses `FARCALL`; overlay code may call resident code but never another overlay; data an overlay owns stays in that overlay. New overlays go in the next free pages (42, 43...) with an `MMU 2, page, $4000` block in `roguelike.asm`.
