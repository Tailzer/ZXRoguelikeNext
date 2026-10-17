# Roguelike (ZX Spectrum Next)

Angband-inspired dungeon crawler written from scratch in Z80N assembly.
Design reference: Angband PC 1.2 C source (`~/Downloads/angband-pc1.2/SRC`).

## Build / run

- `./build.sh` — assembles `roguelike.asm` to `build/roguelike.nex` (plus `.sld`, `.lst`, `.map`)
- `./run.sh` — builds and runs it in CSpect at 28MHz
- In VS Code: the default build task builds; DeZog has a "CSpect" config (start CSpect with `-remote` first)

## Character (until character creation exists)

Fixed level 1 human warrior (STR 17, DEX 14) with the class's starting kit from `PLAYER.C`: Broadsword (2d5), Chain Mail (AC 14, -2 to hit), a Ration of Food and a Potion of Cure Light Wounds (standing in for Berserk Strength). 19 hp. AC, to-hit, weapon dice and blows come from what is worn and wielded.

## Controls

`h j k l y u b n` (Angband roguelike keys) or cursor keys `5 6 7 8`.
Walk into a closed door to open it, or into a monster to attack it; walking onto an item picks it up. `s` stays still for a turn. `>` (Symbol Shift+T) / `<` (Symbol Shift+R) take stairs.

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
6. **Data converter** — Mac-side script turning the C tables into `.bin` files
7. Magic, stores, the town, saving to SD card

## Memory map

| Address | Contents |
|---|---|
| `$0000-$3FFF` | ROM 3 (font copied at start-up) |
| `$4000-$5FFF` | **overlay window** (MMU slot 2): an overlay page, paged in by `FARCALL` |
| `$6000-$73FF` | tilemap, 80x32 x (char, attr) |
| `$7400-$7BFF` | tile definitions (1-bit text mode) |
| `$8000-$AFFF` | resident code and data (bank 2) |
| `$B000-$B3FF` | monster list, 64 x 16 bytes |
| `$B400-$B5FF` | floor items, 64 x 8 bytes |
| `$B600-$B67F` | pack (12 x 8) then equipment (4 x 8) |
| `$BC00-$BDBF` | IM2 vector table + jump |
| `$BEC0-$BFFF` | stack |
| `$C000-$F30B` | dungeon map, 198x66 bytes (pages 32/33): low 4 bits terrain, bit 4 room, bit 5 lit/remembered, bit 6 player light, bit 7 monster here |
| `$F400-$FEA3` | scratch: tunnel/wall/door stacks and room list while generating; room-lighting queue in play |

## Code banks

Code that runs every turn is **resident** in bank 2. Code that runs rarely lives in 8K **overlay** pages, assembled at `$4000` and paged into the overlay window by `FARCALL page, routine`. The ULA screen is switched off, so its page is free to be swapped out, and the tilemap in the next page keeps displaying whatever is in the window.

| Page | Contents | Used |
|---|---|---|
| 40 `PAGE_LEVEL` | `generate.asm`, `populate.asm` | building a new level |
| 41 `PAGE_MISC` | `startup.asm`, `death.asm` | power-on, death screen |
| 42 `PAGE_ITEMS` | `inventory.asm` | item commands, picking up, starting kit |

Resident code ends around `$9E30` after milestone 5, about 4.5K below the monster list; the overlay pages have plenty of room.

Rules: only resident code uses `FARCALL`; overlay code may call resident code but never another overlay; data an overlay owns stays in that overlay. New overlays go in the next free pages (42, 43...) with an `MMU 2, page, $4000` block in `roguelike.asm`.
