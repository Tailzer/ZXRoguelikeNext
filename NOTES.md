# Roguelike (ZX Spectrum Next)

Angband-inspired dungeon crawler written from scratch in Z80N assembly.
Design reference: Angband PC 1.2 C source (`~/Downloads/angband-pc1.2/SRC`).

## Build / run

- `./build.sh` — assembles `roguelike.asm` to `build/roguelike.nex` (plus `.sld`, `.lst`, `.map`)
- `./run.sh` — builds and runs it in CSpect at 28MHz
- `tools/convert.py [path to Angband SRC]` — regenerates `data/*.asm` from `MONSTERS.C` and `TREASURE.C` (only needed when the converter changes; the generated files are committed, with the original copyright notice the licence asks for)
- In VS Code: the default build task builds; DeZog has a "CSpect" config (start CSpect with `-remote` first)

## Character

Created at the start of each game as in `CREATE.C`: choose a race (10), sex and class (6, as the race allows), roll stats (space rolls again, Enter accepts), then type a name (Caps Shift+0 deletes). Race and class set the hit die, base to-hit, stealth, infravision and experience factor; stats give to-hit, damage, armour class, hit points per level and blows. The class's starting kit comes from `player_init[]` (warriors carry a Potion of Berserk Strength, priests one of Healing), minus torches and books the game can't use yet. Background history isn't generated (social class is taken as 50 for starting gold).

## Controls

`h j k l y u b n` (Angband roguelike keys) or cursor keys `5 6 7 8`.
Walk into a closed door to open it, or into a monster to attack it; walking onto an item picks it up; walking onto a store's number goes in (`p` purchase, `s` sell, at home `g` get and `d` drop, space leaves). `s` stays still for a turn. `>` (Symbol Shift+T) / `<` (Symbol Shift+R) take stairs.

`C` (Caps Shift+C) shows the character sheet.

Items: `i` inventory, `e` equipment, `w` wear/wield, `t` take off, `q` quaff, `r` read, `z` aim a wand, `Z` (Caps Shift+Z) use a staff, `a` activate a rod, `A` (Caps Shift+A) activate an artifact, `m` cast a spell, `p` recite a prayer, `P` (Caps Shift+P) browse a book, `G` (Caps Shift+G) learn new spells, `E` (Caps Shift+E) eat, `d` drop, `g` pick up. Choose items by letter; space cancels. Directions: `1`-`9` or `hjklyubn`.

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
8. **The town** (`GENERATE.C` town_gen, `STORE1.C`, `STORE2.C`, `SETS.C`, `TABLES.C` owners) *(done)*
   - games start in town; `<` from 50 ft comes back; the town is rebuilt from the same seed each visit, lit by day, dark at night (every other 5000 turns), with 4 or 8 townsfolk
   - eight stores behind numbered doors: General Store, Armoury, Weaponsmith, Temple, Alchemist, Magic shop, Black market, Home; random owners from the 24 in the C, each with their own markups and purse
   - prices as the C's no-haggle option: item value x race adjustment x owner's final markup (x2 at the black market) x charisma; selling gets the owner's final offer, up to their purse; 25%/50%/75%/90% special offers
   - stores restock (`store_maint`) on each visit to town
   - not yet: haggling, store items with magical pluses, the Alchemist and Magic shop stock (scrolls, wands, rings...), restocking while you're in the dungeon
9. **Magic**, in parts:
   - 9a-1: potions *(done)* — `POTIONS.C`, `DESC.C` flavours, `MISC2.C` stats, `DUNGEON.C` timed effects
     - every potion in Angband 1.2 (52 kinds, effects 1-56); potion colours shuffled per game (all but slime mold juice, apple juice and water), drawn in their colour
     - unknown potions go by colour ("a Cloudy Potion"); drinking one that does something identifies it and gives (level + lev/2) / lev experience; one that does nothing is marked `{tried}`; store stock and the starting kit are always known; selling an unknown potion identifies it, at a value of 20
     - known and unknown stacks of the same kind only merge once known ("You combine similar objects from the shop and dungeon."); "You have no more ..." after drinking or eating
     - current and maximum stats: gain (`inc_stat`), loss (`dec_stat`, with racial sustains), restore, ruination; maximum experience, Lose Memories and Restore Life Levels
     - timed effects with the C's messages: blindness (only the `@` drawn, no monsters seen), confusion (3 in 4 moves random), fear (can't attack), poison, cuts, stuns, speed and slowness (`change_speed` shifts every monster's relative speed), heroism, berserk, blessing, protection from evil, resist heat/cold, detect invisible, infravision, word of recall; paralysis from sleep and salt water
     - shown on the status line: Blind, Confused, Afraid, Poisoned, cut and stun levels, Paralysed, Fast/Slow
     - Enlightenment maps the level; Self Knowledge lists your state; *Enlightenment* does both and identifies the pack
     - overeating now slows you, and being fast burns food faster, as in the C
     - not yet: mana (Restore Mana does nothing), hallucination, prices above 65535 (they show as 65535), haggling
   - 9a-2: scrolls and the `r` command *(done)* — `SCROLLS.C`, `SPELLS.C`, `MISC2.C` teleport, `MISC1.C` summon_monster/summon_undead
     - 30 scroll kinds: Identify, Light, Darkness, Phase Door, Teleport, Teleport Level, Word of Recall, Magic Mapping, Treasure/Object Detection, Door/Stair Location, Detect Invisible, Monster Confusion, Protection from Evil, Blessing/Holy Chant/Holy Prayer, Create Food, Summon Monster/Undead, Aggravate Monster, Genocide, Mass Genocide, Dispel Undead, Trap/Door Destruction, *Destruction*, Remove Curse and *Remove Curse* (nothing is cursed yet), Trap Detection (no traps yet)
     - unknown scrolls go by a title made up each game from `TABLES.C`'s syllables (`a Scroll titled "ha nagkli"`); identified like potions
     - can't read while blind or confused; Identify isn't used up if you choose nothing
     - monsters can be confused (Monster Confusion's glowing hands, on your next hit or theirs) and wander at random until it wears off (1 in 8 a turn); protection from evil repels evil monsters up to your level
     - item classes renumbered: food 1, potion 2, scroll 3, weapon 4 ... boots 10
     - not yet: enchant/curse scrolls, Rune of Protection, Trap Creation, Recharging, Acquirement (not generated until their milestones)
   - 9b: wands, staffs and rods *(done)* — `WANDS.C`, `STAFFS.C`, `RODS.C`, `SPELLS.C`
     - all 29 wands, 29 staffs and 26 rods; unknown ones go by metal (wands, rods) or wood (staffs), shuffled each game, drawn in that colour; identified by use like potions
     - charges (`magic_treasure`'s table per kind), shown once known: "a Wand of Magic Missile (7 charges)", "{empty}" when found dry; rods recharge over their C timeouts, a turn at a time while carried
     - using one can fail: saving throw + INT adjustment - level + class device skill x level / 3, as in the C (halved when confused)
     - bolts (magic missile, lightning, frost, fire, acid) hit the first monster in line, with the C's immunities (a ninth) and pain messages ("The Kobold squeals in pain."); balls burst over radius 2, damage falling with distance, burning or freezing items on the floor and burning doors; beams of light hurt light-haters
     - Stone to Mud, Polymorph, Clone, Teleport Away, Slow/Haste/Confuse/Sleep Monster, Drain Life, Disarming, Trap/Door Destruction, Wonder, the dragon wands; staffs of Earthquakes, Starlight, Holiness, Power, Probing, Detect Evil and the rest; rods of Healing, Restoration, Detection, Recall...
     - the Recharging scroll (may blow the wand up); the Magic shop stocks wands and staffs
     - item kinds are now 9 bits (270 kinds, room for 510): item records are 9 bytes with a word kind, store stock 5 bytes with charges
     - not yet: traps (Trap Location finds none), mana (the Magi restore INT only), monsters escaping walls an earthquake drops on them (survivors keep their floor)
   - 9c-1: magical pluses *(done)* — `MISC1.C` magic_treasure/m_bonus/randnor, `SCROLLS.C`, `SPELLS.C` enchant/remove_curse, `DUNGEON.C` pseudo-identify, `STORE1.C` item_value
     - weapons and armour come with pluses or curses as magic_treasure gives them (chance 15 + level, at most 70; cursed 10/13 of that again), `m_bonus` using the C's normal table; dragon scale mail always enchanted; crowns more often; the stores' goods are made at level 5 (black market 40) and nothing cursed is stocked
     - names show pluses once known: "a Dagger (1d4) (+3,+2)", "Chain Mail (-2,+0) [32,+4]"; {cursed}, {blessed}, and {average}/{good}/{excellent}/{special} feelings
     - cursed things won't come off ("Hmmm, it seems to be cursed.") or be replaced; putting one on: "Oops! It feels deathly cold!"; cursed armour gives no base AC
     - scrolls: Enchant Weapon To-Hit/To-Dam, Enchant Armour, *Enchant Weapon*, *Enchant Armour*, Curse Weapon, Curse Armour, Remove Curse, *Remove Curse*; Identify (and *Enlightenment*) reveal pluses and charges
     - feelings: now and then you sense "There's something good about what you are wielding..."; warriors, rogues and paladins learn more ("You feel the Dagger you are wielding is good...")
     - prices: known pluses add 100 each; a known curse, or any minus, makes it worthless
     - the home keeps what you knew about an item
     - item records are now 14 bytes (pluses, ego, feeling); the store stock (10-byte entries) lives in the store overlay's own page
     - not yet: ego items and artifacts (the C's special cases are plain pluses for now; cursed cloaks keep their ego number for 9c-3)
   - 9c-2: rings and amulets *(done)* — `MISC1.C` magic_treasure (rings, amulets), `MORIA1.C` py_bonuses/calc_bonuses/wear, `MISC2.C` modify_stat/set_use_stat, `DESC.C` objdes, `STORE1.C` item_value, `SPELLS.C` self_knowledge, `DUNGEON.C` random teleport
     - all 31 rings and 9 amulets of 1.2 (not the artifacts); unknown ones go by stone ("a Ruby Ring") or material ("a Coral Amulet"), shuffled each game, drawn in that colour; identified by Identify (wearing one doesn't tell you, as in the C)
     - magic_treasure's numbers: stat rings and amulets +m_bonus(1,10) or cursed -m_bonus(1,20); Speed +1 (+2 one time in 888) or -1d3 cursed; Searching 5 x m_bonus; Damage, Accuracy, Protection m_bonus + 3 + 1d10; Slaying both, shown "(+5,+6)"; the Magi never cursed; Teleportation, Weakness, Stupidity, Woe, Aggravate Monster and Doom always cursed
     - names: "a Ring of Strength (+3)", "a Ring of Protection [+12]", "a Ring of Sustain Strength" (sustains don't show their number)
     - an amulet goes round the neck; rings on the right hand, then the left, then "Put ring on which hand (l/r/L/R)?"; `e` lists all ten slots
     - what they do: stats as used (the C's use_stat: current stat modified by equipment, 18/xx steps of 10) feed every bonus and the character sheet, while potions change the current stat; speed (two +1 Rings of Speed count once, the C's quirk); to-hit, to-dam and armour class; sustains (with the races' own); see invisible, free action (sleep potions), resist poison (poison potions, and it cures poisoning), slow digestion (half the food), aggravation (sleeping monsters near you wake), teleportation (1 in 100 a turn, teleport(40))
     - resist fire, cold and acid, feather fall and searching are recorded and listed by Self Knowledge, which now lists what equipment does as the C does ("You resist fire exceptionally well.", "You have magical strength.", every sustain); nothing burns, freezes or melts you yet, there are no trap doors and no searching
     - prices: unknown 45; known type, unknown number: the base cost; known: the cost plus magic_treasure's additions (100 a point for stats and pluses, 30 or 20 for searching), nothing if cursed; the Magic shop stocks them (never cursed ones)
     - no item feelings for rings and amulets (the C's pseudo-ID skips them)
     - `magic_items.asm` moved out of resident memory into the misc overlay (with the flavour shuffle); other overlays reach it with `OVCALL`
     - not yet: the verify prompt for L/R (both cases just choose), ring artifacts (Power, Narya, Nenya, Vilya, Barahir, Tulkas) and amulets (Ingwe, Carlammas, the Dwarves)
   - 9c-3a: ego items *(done)* — `MISC1.C` magic_treasure (the ego cases), `MISC2.C` tot_dam, `TREASURE.C` special_names, `DESC.C` objdes, `STORE1.C` item_value, `DUNGEON.C` value_check, `CREATURE.C` update_mon (telepathy), `SPELLS.C` self_knowledge/remove_curse
     - every ego magic_treasure makes for the kinds the game has, at the C's odds (special = chance / 4, 3/2 of that for weapons, doubled for crowns):
       - weapons: Holy Avenger, Defender, of Westernesse, Flame, Frost, slay Animal/Dragon/Evil/Undead/Orc/Troll/Giant/Demon; whips of Fire (1 in 10 with 2 dice); cursed weapons of Morgul deep down (AC -10, 10 lb heavier, see invisible, aggravation)
       - body armour and shields: of Resistance, Elvenkind, Resist Acid (not mithril or adamantite)/Fire/Cold/Lightning; Robes of the Magi
       - gloves: Free Action, Slaying, Agility, Power; cursed Clumsiness, Weakness
       - boots: Slow Descent, Speed, Stealth (not metal shod); cursed Slowness, Noise, Great Mass
       - helms: Intelligence, Wisdom, Infra-Vision, Light, Telepathy; crowns of Might, Lordliness, the Magi, Beauty, Seeing, Regeneration; cursed Stupidity, Dullness, Weakness, Teleportation, Ugliness
       - cloaks: Protection, Stealth, of Aman; cursed Irritation, Vulnerability, Enveloping. As in the C, a magical cloak only gets an armour bonus when it's an ego
     - names once known: "a Dagger (Defender) (1d4) (+3,+3) [+7] (+2 to stealth)", "a Pair of Soft Leather Boots of Speed [2,+5] (+1)", "a Set of Gauntlets of Power (+3,+4) [2,+2] (+3)"
     - what they do: slays and brands in melee (x5 lightning and execute dragon, x3 slay dragon/undead/orc/troll/giant/demon and the brands unless immune, x2 evil and animal, the first that applies); stealth (monsters notice you less), infravision, regeneration (heal half as fast again, eat 3 more a turn), telepathy (every monster within 20 squares on screen is seen, through walls and blind), speed, stat bonuses, sustains (a Holy Avenger's number; the Robe of the Magi all six), free action, see invisible, resistances, feather fall
     - monster races now carry the C's ANIMAL, ORC, DRAGON, TROLL and GIANT flags
     - prices: an ego's cost (and so much per point of its number, doubled for Holy Avengers, Defenders and Westernesse) is added once it's known
     - item feelings: egos feel "excellent"; Remove Curse can't lift Morgul's curse (*Remove Curse* can)
     - Self Knowledge (moved to the items overlay) adds stealth, regeneration, ESP, hold life, permanent light, resist lightning, and the weapon: "Your weapon strikes at undead with holy wrath.", "Your weapon is truly foul."...
     - ego names and flags live in their own data page (`data/egos.asm`, 16 bytes per SN_ number); kinds carry the C's flags2 and which ego rules apply to them
     - not yet: artifacts (the C's chances of one are rolled, and nothing made), hold life and immunities do nothing yet (no experience drain or elemental attacks), permanent light doesn't light anything
   - 9c-3b: artifacts *(done)* — `MISC1.C` unique_weapon/unique_armour and the cloaks in magic_treasure, `MISC2.C` special_place_object/place_object, `SPELLS.C` remove_curse/remove_all_curse/self_knowledge, `DUNGEON.C` value_check
     - all 101 artifact weapons, armour, gloves, boots, helms, crowns and cloaks of 1.2, read from the C by the converter (`tools/convert.py` parses unique_weapon and unique_armour): which base kinds may be which artifact and how likely (Longswords: Ringil 1 in 15, Anduril 1 in 5...), with each one's pluses, dice, weight, number, flags, flags2 and value
     - made where magic_treasure tries unique_weapon/unique_armour (1 in 2 or 3 of the ego chances, gauntlets, 1 in 10 Cloaks and 1 in 20 Shadow Cloaks of the special ones); never in a shop; each only once a game (`art_made`, cleared for a new character)
     - the special objects: the Rings of Power (Narya, Nenya, Vilya, the One Ring), Tulkas and Barahir, and the Amulets of Ingwe, Carlammas and the Dwarves, placed now and then instead of an ordinary object with special_place_object's odds (not much shallower than their level, rarer if deeper)
     - names: "a Longsword named Ringil (4d5) (+22,+25)", "an Iron Helm of Dor-Lomin [5,+20]", "a Ring of Power named Narya"; an artifact's own dice show even before it's known, as in the C
     - they do what their flags say: everything the egos do, plus flags2's resistances (confusion, sound, light, dark, chaos, disenchantment, shards, nexus, nether, blindness) and immunities, listed by Self Knowledge ("You are completely immune to fire." in place of the resist lines)
     - Remove Curse can't lift the curses of Morgul, Calris and Mormegil; *Remove Curse* can, but "The One Ring resists all attempts to remove it!"
     - value: an artifact's own cost (at most 65535), plus its known pluses; warriors feel it's "special"
     - the flavour tables moved to their own page (64), so the kinds can fill three pages
     - not yet: activation (9c-3c), the lights (the Phial, the Star of Elendil, the Arkenstone: no light sources yet), the bows (Beleg Cuthalion, Bard, Cubragol: no missile weapons yet); Razorback and Bladeturner can't appear (dragon scale mail never reaches unique_armour in 1.2)
   - 9c-3c: activation *(done)* — `DUNGEON.C` activate() and its timeout loop
     - `A` lists what you wear that can be activated (and is known to be an artifact), then does it: "You activate it...", the artifact's own message and effect, and then it needs so many turns to recharge, counted down while it's worn ("It whines, glows and fades..." until then)
     - it can fail: INT below 1d18 and 1d(its kind's level) above your level ("You fail to activate it properly.")
     - every activation in 1.2 for the artifacts and special objects the game has: bolts (Narthanc, Nimthanc, Dethanc, the Paur- gauntlets, Arunruth, Cammithrim, Fingolfin's spikes), balls (Ringil, Anduril, Aeglos, Firestar, Rilia, Belangil, the Rings of Power), drain life (Theoden, Turmil), stone to mud (Orome), teleport other (Ulmo), confuse (Totila), speed (Feanor, Taratol, Tulkas), healing (Soulkeeper, Gondor, Lotharang), cures (Dal-i-thalion), recall (Avavir), identify (Eriril), probing (Olorin), mass genocide (Eonwe), genocide (Celeborn), trap and door destruction (Caspanion), teleport (Belegennon, Colannon), restore life levels (Luthien), resistance (Colluin), sleep (Holcolleth), recharging (Thingol), detection (Holhenneth), dispel evil (Ingwe), protection from evil (Carlammas), and dragon scale mail breath (Multi-Hued, Chaos, Law, Balance and Shining choose at random)
     - the One Ring: dispel everything, a bolt or ball of raw mana, or a malignant aura (a level lost, every stat ruined, half your hit points); and while worn it takes a point of experience 1 turn in 20
     - the converter writes the table from activate() (`data/activate.asm`, its own data page, 65); the effects borrow the wands', staffs' and scrolls' code in the device overlay
     - an activation's timeout is kept in the item's floor position bytes, unused while it's carried (cleared as it's picked up)
     - not yet: chaos, disenchantment, sound, shards, light, darkness, confusion and the elements' "raw mana" act as magic missiles (as in the C without colour), resist poison/acid/lightning timers (Colluin gives heat and cold only), the Phial, Star and Arkenstone (no lights), Cubragol (no bolts)
     - (fixed in passing: dying of genocide's strain had no name on the tombstone)
   - 9d-1: mage spells *(done)* — `MAGIC.C` cast, `MORIA2.C` cast_spell, `MISC2.C` calc_spells/gain_spells/calc_mana/spell_chance/print_spells/stat_adj, `DUNGEON.C` regenmana and the new timers, `SPELLS.C` door_creation/stair_creation/detect_enchantment, `PLAYER.C` magic_spell/spell_names
     - books are items now: the four Books of Magic Spells and five special ones, and the priests' books (inert until 9d-2); mages, rogues and rangers start with [Magic for Beginners]; the Magic shop and Temple stock them; they stack
     - learning: as calc_spells allows (level from the class's first spell level, and INT's stat_adj), "You can learn some new spells now."; `G` lists what the books carried teach and you pick; spells above your level, or beyond what INT allows, are forgotten and remembered again in the order learnt
     - mana: calc_mana's table by INT and level (+1, so 2 at first), less a quarter in gloves (mages, rogues, rangers), less 1 per point of armour class over 35; it comes back like hit points (and faster with regeneration); shown as "SP 5/7" on the status line
     - `P` lists a book's spells with level, mana and failure chance, "unknown", "forgotten" or "untried"; `m` casts one: spell_chance's failure (stunned: +15 or +25), "You failed to get the spell off!", first success gives 4 x its experience, and too little mana asks "You summon your limited strength..." then faints you (1d(5 x shortfall) turns, 1 in 3 a point of CON)
     - all 59 mage spells: bolts and balls that grow with level, detections, phase door and teleports, cures, confusion, sleep (one, adjacent, all in sight), slow, polymorph, stone to mud, spear of light, create food, recharging (5, 40, 100), identify, haste, destruction, genocide and mass genocide, door and stair creation, teleport level, earthquake, recall, detect evil and enchantment, the resistances, heroism, berserk, a mystic shield (+50 AC), essence of speed and a globe of invulnerability (+100 AC, no damage)
     - new timers: shield, invulnerability, resist acid, poison and lightning (with the C's messages, and in Self Knowledge)
     - the spells live in a data page (66) and their code in a new overlay (55); they borrow the device overlay's bolts and balls through `do_effect`, and scroll and potion effects through `OVCALL`
     - to make room: `player_init` moved to the misc overlay, the dead uniques and the message buffer to high RAM with the spell state
     - not yet: priests' prayers (9d-2), no light needed to read (there are no light sources), Hellfire and Meteor Swarm hit as magic missiles (as in the C without colour)
   - 9d-2: prayers *(done)* — `PRAYER.C` pray, `MISC2.C` gain_spells (prayers at random), `SPELLS.C` turn_undead/banish_creature/bless/detect_inv2
     - priests and paladins learn from the Holy Books they carry, with WIS's stat_adj in place of INT's; `G` gives them a prayer at random ("You have learned the prayer of Remove Fear."); `p` recites one, `P` browses
     - the C's words for them: "You can't see to read your prayer!", "Use which Holy Book?", "Recite which prayer?", "You lost your concentration!", "You faint from fatigue!", and "Pray hard enough and your prayers may be answered." for anyone else
     - all 58 prayers: detect evil, the cures (3d3 to 16d4, cuts as the C has them), bless, chant and prayer, remove fear, light, find doors, slow and neutralize poison, scare (confusion), portal, sanctuary, satisfy hunger, remove curse, resist heat and cold, orb of draining, sense invisible, protection from evil, earthquake, sense surroundings, turn undead ("runs frantically!"), dispel undead and evil (3 or 4 x level), heal and healing, holy word, detect monsters, detection, perception, probing, clairvoyance, restoration, remembrance, banishment, word of destruction, annihilation, unbarring ways, recharging, dispel curse, enchant weapon and armour, elemental brand, blink, teleport, teleport away, teleport level, word of recall, alter reality
     - not yet: glyph of warding (nothing can be placed on the floor yet), find traps (no traps)
   - 9d-3: monster spells and breath; 9d-4: monster melee side effects
10. Saving to SD card

## Memory map

| Address | Contents |
|---|---|
| `$0000-$1FFF` | ROM 3 |
| `$2000-$3FFF` | **data window** (MMU slot 1): a race or kind page, paged in by `race_addr` / `kind_addr` (ROM 3 until start-up has copied the font) |
| `$4000-$5FFF` | **overlay window** (MMU slot 2): an overlay page, paged in by `FARCALL` |
| `$6000-$73FF` | tilemap, 80x32 x (char, attr) |
| `$7400-$7BFF` | tile definitions (1-bit text mode) |
| `$7C00-$7EAF` | what the player knows (`object_ident`, 8 x 64) and this game's flavour orders (potions, woods, metals, stones, amulets) |
| `$8000-$AFFF` | resident code and data (bank 2) |
| `$B000-$B3FF` | monster list, 64 x 16 bytes |
| `$B400-$B77F` | floor items, 64 x 14 bytes (kind word, number, y, x, marked, value/charges/timeout, ident, to-hit, to-dam, to-ac, ego, feeling) |
| `$B780-$B8CF` | pack (12 x 14) then equipment (room for 12 x 14; 10 in use: weapon, body, shield, helm, cloak, gloves, boots, neck, right hand, left hand) |
| `$B8D0-$B9FB` | the character's hit points per level (50 words) and experience needed per level (50 dwords) |
| `$B9FC-$BA1B` | store owners, entry counts, door positions (the stock itself is in the store overlay) |
| `$BA1C-$BB42` | dead uniques, the message buffer, what the player knows of spells, mana, and the spell-to-device effect buffer |
| `$BC00-$BDBF` | IM2 vector table + jump |
| `$BEC0-$BFFF` | stack |
| `$C000-$F30B` | dungeon map, 198x66 bytes (pages 32/33): low 4 bits terrain, bit 4 room, bit 5 lit/remembered, bit 6 player light, bit 7 monster here |
| `$F400-$FEA3` | scratch: tunnel/wall/door stacks and room list while generating; room-lighting queue in play |

## Code banks

Code that runs every turn is **resident** in bank 2. Code that runs rarely lives in 8K **overlay** pages, assembled at `$4000` and paged into the overlay window by `FARCALL page, routine`. The ULA screen is switched off, so its page is free to be swapped out, and the tilemap in the next page keeps displaying whatever is in the window.

| Page | Contents | Used |
|---|---|---|
| 40 `PAGE_LEVEL` | `generate.asm`, `populate.asm` | building a new level |
| 41 `PAGE_MISC` | `startup.asm`, `magic_items.asm`, `data/artifacts.asm`, `magic_init.asm` | power-on; making items (`new_item`, `new_plain`, `magic_treasure`, artifacts, special objects); each game's flavour shuffle |
| 42 `PAGE_ITEMS` | `inventory.asm`, `knowledge.asm`, `data/blows.asm` | item commands, picking up, starting kit, bonuses, Self Knowledge |
| 43 `PAGE_CREATE` | `create.asm`, `death.asm`, `data/player.asm` | making a character, the `C` sheet, the tombstone |
| 51 `PAGE_STORE` | `store.asm`, `data/stores.asm` | the stores: stock, prices, buying and selling |
| 52 `PAGE_MAGIC` | `potions.asm`, `effects.asm` | quaffing, stat changes, timed effects (every turn), the colour and title shuffle |
| 53 `PAGE_SCROLL` | `scrolls.asm` | reading scrolls (summons go through `level_call` to the level overlay) |
| 55 `PAGE_SPELL` | `spells.asm` | spells and prayers: learning, mana, browsing, casting |
| 54 `PAGE_DEVICE` | `devices.asm` | wands, staffs, rods and artifact activation: bolts, balls, beams (borrows scroll and potion effects through `device_xcall`) |

Data pages (slot 1, `$2000`): 44-48 `RACE_PAGE` = `data/races.asm` (128 x 64-byte races per page, name inline); 60-62 `KIND_PAGE` = `data/kinds.asm` (128 kinds per page); the flavours (`data/flavours.asm`: potion colours, woods, metals, stones, amulets, the title syllables, the buffer this game's scroll titles are written into, normal_table) have their own page. 63 `EGO_PAGE` = `data/egos.asm` (ego and artifact names, flags and numbers, 24 bytes each); 64 `FLAVOUR_PAGE` = `data/flavours.asm`; 65 `ACT_PAGE` = `data/activate.asm`; 66 `SPELL_PAGE` = `data/spells.asm`. The level tables (`data/alloc.asm`) live in the level overlay and the treasures (`data/tables.asm`) are resident.

Resident code ends around `$AEA1` after milestone 9d-1 (about 350 bytes left; `player_init` moved to the misc overlay, `magic_items.asm` moved to the misc overlay, the knowledge tables to `$7C00` and the experience table into the creation overlay to make room) (`status.asm` holds the stat tables, timed-effect counters, what the player knows, the colour order and the after-use identify logic; `pack.asm` the item lists and chooser), the monster list starting at `$B000`. The creation overlay is at 7.7K of 8K, the magic overlay 6.7K, the items overlay 7.1K, the store overlay 7.1K, the scroll overlay 4.0K, the device overlay 8.0K (full), the spell overlay 5.6K, the misc overlay 3.4K.

Overlays that change stats or bonuses set `p_update`; `draw_view` (main loop only) runs `update_stuff`, which pages the items overlay to recalculate. Item commands that need the magic overlay leave `pending_magic` for `pending_actions` in the main loop.

Rules: only resident code uses `FARCALL` (exceptions: `level_call`, which the scroll overlay uses to reach the level overlay, and `device_xcall`, which the device overlay uses to borrow scroll, potion and level routines; both page the caller back in before returning; and `overlay_call`, through the `OVCALL page, routine, back` macro, which any overlay can use to borrow another's routine; anything it passes by address must be outside the overlay window, since the caller's page is out while it runs: the stores make new stock in the resident `new_rec`); overlay code may call resident code but otherwise never another overlay; data an overlay owns stays in that overlay. New overlays go in the next free pages (42, 43...) with an `MMU 2, page, $4000` block in `roguelike.asm`.
