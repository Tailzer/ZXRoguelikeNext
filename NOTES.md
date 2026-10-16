# Roguelike (ZX Spectrum Next)

Angband-inspired dungeon crawler written from scratch in Z80N assembly.
Design reference: Angband PC 1.2 C source (`~/Downloads/angband-pc1.2/SRC`).

## Build / run

- `./build.sh` — assembles `roguelike.asm` to `build/roguelike.nex` (plus `.sld`, `.lst`, `.map`)
- `./run.sh` — builds and runs it in CSpect at 28MHz
- In VS Code: the default build task builds; DeZog has a "CSpect" config (start CSpect with `-remote` first)

## Controls

`h j k l y u b n` (Angband roguelike keys) or cursor keys `5 6 7 8`.
Walk into a closed door to open it.

## Milestones

1. **Walkabout** — tilemap text, test level, movement, scrolling view *(done)*
2. **Dungeon generator** — rooms and corridors (`GENERATE.C`), stairs, new levels
3. **Line of sight / lighting** — remembered squares, lit rooms (`MORIA1.C` los, `MISC1.C`)
4. **Monsters** — ~10 hand-picked races, chase AI, melee (`CREATURE.C`, `MONSTERS.C`)
5. **Items** — pick up, inventory, wield, potions (`TREASURE.C`, `POTIONS.C`)
6. **Data converter** — Mac-side script turning the C tables into `.bin` files
7. Magic, stores, the town, saving to SD card

## Memory map

| Address | Contents |
|---|---|
| `$0000-$3FFF` | ROM 3 (font copied at start-up) |
| `$6000-$73FF` | tilemap, 80x32 x (char, attr) |
| `$7400-$7BFF` | tile definitions (1-bit text mode) |
| `$8000-$BFFF` | code, data, stack at top |
| `$C000-$FFFF` | dungeon map, 198x66 bytes (pages 32/33) |
