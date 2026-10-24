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
Walk into a closed door to open it (picking its lock if it has one), or into a monster to attack it; walking onto an item picks it up; walking onto a store's number goes in (`p` purchase, `s` sell, at home `g` get and `d` drop, space leaves). `s` searches for a turn (staying still). `R` (Caps Shift+R) rests: a number of turns, or Enter for as long as needed. Caps Shift with a movement letter (`HJKLYUBN`) runs that way. `>` (Symbol Shift+T) / `<` (Symbol Shift+R) take stairs.

`C` (Caps Shift+C) shows the character sheet. Symbol Shift+X (the C's `^X`) saves the game and goes back to the title; pressing a key there carries on from the save. `F` (Caps Shift+F) fills a lantern from a flask of oil. `D` (Caps Shift+D) disarms a trap you've found, `T` (Caps Shift+T) tunnels through rubble or rock; both ask for a direction. `v` throws or fires something from the pack in a direction. Doors: `o` opens (picks a lock), `c` closes, `f` forces (bashes) a door or a monster with your shield, `S` (Caps Shift+S) jams a closed door with an iron spike; each asks for a direction. `x` looks around (a direction, or 5 all round), `M` (Caps Shift+M) shows the whole map, `W` (Caps Shift+W) moves the view about (locate), Symbol Shift+P shows the last messages (^P), `/` (Symbol Shift+V) identifies a symbol, `%` (Symbol Shift+5) is Self Knowledge. `Q` (Caps Shift+Q) quits, or retires once you've won.

Items: `i` inventory, `e` equipment, `w` wear/wield, `t` take off, `q` quaff, `r` read, `z` aim a wand, `Z` (Caps Shift+Z) use a staff, `a` activate a rod, `A` (Caps Shift+A) activate an artifact, `m` cast a spell, `p` recite a prayer, `P` (Caps Shift+P) browse a book, `G` (Caps Shift+G) learn new spells, `E` (Caps Shift+E) eat, `d` drop, `g` pick up. Choose items by letter; space cancels. Directions: `1`-`9` or `hjklyubn`.

## Milestones

1. **Walkabout** — tilemap text, test level, movement, scrolling view *(done)*
2. **Dungeon generator** — rooms and corridors (`GENERATE.C`), stairs, new levels *(done; the unusual rooms came in 16)*
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
     - 30 scroll kinds: Identify, Light, Darkness, Phase Door, Teleport, Teleport Level, Word of Recall, Magic Mapping, Treasure/Object Detection, Door/Stair Location, Detect Invisible, Monster Confusion, Protection from Evil, Blessing/Holy Chant/Holy Prayer, Create Food, Summon Monster/Undead, Aggravate Monster, Genocide, Mass Genocide, Dispel Undead, Trap/Door Destruction, *Destruction*, Remove Curse and *Remove Curse* (nothing is cursed yet), Trap Detection, Trap Creation
     - unknown scrolls go by a title made up each game from `TABLES.C`'s syllables (`a Scroll titled "ha nagkli"`); identified like potions
     - can't read while blind or confused; Identify isn't used up if you choose nothing
     - monsters can be confused (Monster Confusion's glowing hands, on your next hit or theirs) and wander at random until it wears off (1 in 8 a turn); protection from evil repels evil monsters up to your level
     - item classes renumbered: food 1, potion 2, scroll 3, weapon 4 ... boots 10
     - not yet: enchant/curse scrolls, Rune of Protection, Recharging, Acquirement (not generated until their milestones)
   - 9b: wands, staffs and rods *(done)* — `WANDS.C`, `STAFFS.C`, `RODS.C`, `SPELLS.C`
     - all 29 wands, 29 staffs and 26 rods; unknown ones go by metal (wands, rods) or wood (staffs), shuffled each game, drawn in that colour; identified by use like potions
     - charges (`magic_treasure`'s table per kind), shown once known: "a Wand of Magic Missile (7 charges)", "{empty}" when found dry; rods recharge over their C timeouts, a turn at a time while carried
     - using one can fail: saving throw + INT adjustment - level + class device skill x level / 3, as in the C (halved when confused)
     - bolts (magic missile, lightning, frost, fire, acid) hit the first monster in line, with the C's immunities (a ninth) and pain messages ("The Kobold squeals in pain."); balls burst over radius 2, damage falling with distance, burning or freezing items on the floor and burning doors; beams of light hurt light-haters
     - Stone to Mud, Polymorph, Clone, Teleport Away, Slow/Haste/Confuse/Sleep Monster, Drain Life, Disarming, Trap/Door Destruction, Wonder, the dragon wands; staffs of Earthquakes, Starlight, Holiness, Power, Probing, Detect Evil and the rest; rods of Healing, Restoration, Detection, Recall...
     - the Recharging scroll (may blow the wand up); the Magic shop stocks wands and staffs
     - item kinds are now 9 bits (270 kinds, room for 510): item records are 9 bytes with a word kind, store stock 5 bytes with charges
     - not yet: mana (the Magi restore INT only), monsters escaping walls an earthquake drops on them (survivors keep their floor)
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
     - resist fire, cold and acid, feather fall and searching are recorded and listed by Self Knowledge, which now lists what equipment does as the C does ("You resist fire exceptionally well.", "You have magical strength.", every sustain); nothing burns, freezes or melts you yet
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
     - not yet: activation (9c-3c), the lights (the Phial, the Star of Elendil, the Arkenstone: no light sources yet), the bows (Beleg Cuthalion, Bard, Cubragol: no missile weapons yet) (all since done); Razorback and Bladeturner can't appear (dragon scale mail never reaches unique_armour in 1.2)
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
     - not yet: glyph of warding (nothing can be placed on the floor yet)
   - 9d-3a: monster spells *(done)* — `CREATURE.C` mon_cast_spell, `SPELLS.C` bolt/breath/teleport_away/teleport_to, `MORIA1.C` fire_dam/cold_dam/light_dam/acid_dam/poison_gas/minus_ac, `MISC2.C` inven_damage/player_saves, `MISC1.C` the summon_ functions, `SETS.C`
     - each race's spells (spells, spells2, spells3 and INTELLIGENT) are in a new data page (67, `data/mspells.asm`, 12 bytes a race); a bit in the race record says it has any, and only those monsters page in the new overlay (56, `src/mcast.asm`)
     - 1 in freq turns, within 18 squares and in line of sight, it casts one of its spells at random; an intelligent one below a tenth of its hit dice picks only its escapes half the time; unseen casters are "It"
     - blink, teleport, teleport-to, teleport the player away; light, serious, critical and mortal ("DIE!") wounds, the mind blasts (stare, eyes glow red), hold, blindness, confusion, fear, slowness, all with the player's saving throw (save + WIS's stat_adj + class_level_adj * level / 3) and free action, TR_RES_BLIND (and dwarves), TR_RES_CONF/CHAOS where the C has them; drain mana, heal self, haste self
     - the five classic breaths (hp / 3, up to 1600, gas 800), fire/frost/acid/lightning/mana/plasma/ice/water bolts and magic missiles, fire/frost/lightning/acid balls and the stinking cloud: bolts stop at the first monster in the way; balls (radius 2 on the player) hit monsters for damage / (distance + 1), a ninth if they resist, burn the floor's scrolls and doors (the C's destroy sets)
     - the player's elements as the C has them: resisting (worn or timed) takes a third each, immunity leaves 1; acid may eat a point of armour instead ("Your Robe is damaged!") or be resisted by it, and halves the hit if so; poison gas poisons for 12 + 1d(damage); the pack loses scrolls and staffs to fire, potions to frost, armour and weapons to acid ("There is smoke coming from your pack!")
     - summon monster (and monsters, 8), undead, a demon (up to its level), a dragon, angels, spiders (6), hounds (8), greater undead (8), ancient dragons (5), each beside the last one summoned
     - not like the C: a ball doesn't hurt its own caster; monsters killed by other monsters' spells leave nothing (no drops yet)
   - 9d-3b: the rest of the monster spells *(done)* — `CREATURE.C` mon_cast_spell 33-78 and br_wall, `SPELLS.C` chaos/lose_all_info/unlight_area/light_area, `MISC1.C` summon_wraith/reptile/ant/unique/jabberwock (code in `src/mexotic.asm`, same overlay; their words in the monster spell page, `src/mexotic_text.asm`)
     - every exotic breath hits as a magic missile (the C without colour), for hp / 6 or hp / 3 up to its cap, less if the player resists it (TR_RES_ flags2: chaos, shards, sound, confusion, disenchantment, nether, nexus, light, darkness)
     - and then: chaos drains experience, confuses and turns every monster in sight but uniques into something else; shards cut (hp / 3); sound, plasma and gravity stun; confusion confuses; disenchantment takes 1d2 off each plus of one piece of armour ("There is a static feeling in the air."); nether drains experience unless hold life keeps it; nexus teleports the player far, to the monster, a level up or down, or swaps two stats ("Your body starts to scramble..."); elemental force 1 in 10 brings the cave down ("The cave ceiling collapses!": pushed aside, the square turns to rock, or 250 if there's nowhere to go, "Killed by an Earthquake"); inertia slows; light lights the room and blinds; time drains experience or takes a quarter off one stat or all six; gravity stuns, slows and teleports 5; darkness and the darkness storm darken the room
     - nether bolt and ball (experience, hold life), the whirlpool, arrows, the mana storm, gestures in shadow (darkness), blanking the mind (pluses unknown again, the map forgotten), teleport level ("You sink through the floor.")
     - summons: ringwraiths (uniques) then greater undead, reptiles, ants, uniques (not 'P') and jabberwocks; uniques come where the C lets them, if not dead or already on the level
     - not yet: chaos's hallucination (none in the game)
   - 9d-4: monster melee side effects *(done)* — `CREATURE.C` make_attack, monster_critical, shatter_quake; `MORIA1.C` corrode_gas; `SPELLS.C` aggravate_monster (code in `src/mmelee.asm`, in the monster spell overlay, sharing its element, stat and teleport routines)
     - the to-hit (power + level x 3 against AC, or against the player's level for stealing; nothing to steal or drain is a miss), what each blow says (the C's nine insults, Farmer Maggot's five lines, "You've been slimed!") and what it does, all moved out of resident code into the overlay
     - all 25 blow types: armour absorbs normal blows; strength, dexterity, constitution, intelligence and wisdom drained unless sustained (strength half the time), or all six; confusion, fear (saving throw; mages shrug it off 1 in 3), blindness (dwarves and TR_RES_BLIND), paralysis (saving throw, free action), poison; fire, acid, cold, lightning as the spells' elements; corrosion eats armour or does 1d8, and the pack; experience drained unless hold life holds it; aggravation; disenchantment of one piece of equipment
     - thieves: 1d168 under your DEX keeps your purse or pack ("You quickly protect your money pouch!"); gold goes by a tenth plus 1d25, an item one at a time (never an artifact); then 1 in 2 (gold) or 1 in 3 (items) "There is a puff of smoke!" and it's gone, with no more blows; eating food, draining a wand's or staff's charges into its hit points (and marking it empty)
     - critical blows: hits, bites and claws may cut, hits, tramples, butts and charges may stun, worse the nearer the damage is to the dice's maximum (a mortal wound, or knocked out, at the top)
     - Quaker and Morgoth (DESTRUCT): a blow over 23 shakes everything within 8 squares, 1 in 8: monsters hurt or embedded in the rock ("wails out in pain!"), the player thrown aside (320 if trapped), floors turned to rock and rock opened
     - not like the C: kicks and embraces say so (the C is silent); a square something still stands on isn't turned to rock (nothing may stand in rock here)
     - the monster spells' and blows' messages moved to a page of their own (68, `src/mcast_text.asm`); `data/mspells.asm` gained the DESTRUCT bit
10. **Saving** (`DUNGEON.C` ^X, `SAVE.C`, `DEATH.C`) *(done)*
   - Symbol Shift+X: "Saving game...", then back to the title screen; "Save failed..." if it can't (and play goes on, as in the C)
   - `roguelike.sav` in the folder the game was started from, through the esxDOS calls NextZXOS provides (`RST $08` F_OPEN/F_READ/F_WRITE/F_CLOSE/F_UNLINK; addresses in IX and HL)
   - what's saved (19K): the character, stats and timed effects, the level, place and turn, the town seed, what's known of objects and flavours, every monster and floor item, the pack and equipment, spells and mana, dead uniques, the level map, the stores' stock, the artifacts made, and this game's scroll titles
   - the file holds each block's length: a later build reads it as long as none of the blocks changed size ("Your saved game is from another version."); a short file isn't used ("Your saved game is damaged.")
   - pressing a key at the title restores it and play carries on exactly where it was; with no save, a new character is made
   - dying deletes the save (where the file can't be deleted it's marked dead, which counts as none); the C keeps a dead character's file and starts a new one from it
   - in an emulator the SD card must be emulated: CSpect `-mmc=<folder>/`, ZEsarUX's esxdos handler (Settings > Storage > esxdos handler, with a root folder)
   - the save code is its own overlay (57, `src/save.asm`)
11. **Light sources** (`DUNGEON.C` the light check and refill_lamp, `TREASURE.C`, `MISC1.C` magic_treasure, `DESC.C`) *(done)*
   - Wooden Torches (4000 turns of fuel), Brass Lanterns (7500) and Flasks of oil (7500) are items now, in the dungeon and the General Store; every class starts with 5 torches in the pack, unlit, as in the C
   - a light slot ("Light source :"); `w` puts a light there, one from a bundle of torches ("Your light source is a Wooden Torch with 4000 turns of light."); `t` takes it off ("Your light source was ...")
   - the player's light (the 3x3 around them) only shines while the light source has fuel, or while something worn gives light (the Phial): no light, and dark rooms and corridors stay dark; lit rooms still light up as you enter
   - a turn of fuel each turn; under 40, now and then "Your light is growing faint."; at 0, "Your light has gone out!"
   - `F` fills a lantern from a flask, up to 15000 ("Your lamp is more than half full.", "Your lamp overflows, spilling oil on the ground.", "You have no oil.", "But you are not using a lamp.")
   - reading a scroll or a book needs light where you stand: "You have no light to read by."
   - torches found in the dungeon have 1d4000 turns left, lanterns 1d7500; torches stack only with the same fuel, lanterns never; plurals as the C ("Torches")
   - the Phial of Galadriel, the Star of Elendil and the Arkenstone of Thrain: lights that never burn down; activated, the Phial lights the room, the Star maps the area, the Arkenstone lights the whole level
   - monsters that eat light now do: 250 + 1d250 turns of fuel ("Your light dims.")
   - store entries grew a byte for the fuel, so saves from before this don't load
   - searching (`MORIA1.C` search, `MORIA2.C` move_char, `CREATE.C` srh/fos), so secret doors can be found without magic: `s` searches the 8 squares round you; walking, you search every step if your searching frequency is 1 or less, else 1 in that many
     - each square: 1d100 under the searching skill (race + class, plus Searching rings) finds a secret door ("You have found a secret door."), which becomes a closed door; a tenth of the chance when confused, blind or in the dark
     - not yet: the character sheet doesn't show searching (chests' traps are found too since 17)
12. **Traps** (`TREASURE.C` the 18 traps, `MISC2.C` place_trap/place_rubble, `MORIA2.C` hit_trap/disarm_trap/tunnel, `MORIA1.C` twall, `SPELLS.C` detect_trap/trap_creation/td_destroy) *(done)*
   - each level (not the town) gets 1d(level / 3, 2 to 10) traps anywhere on the floor and as much rubble in the corridors; traps are hidden (all but open pits) until found by searching (as you walk, or `s`), by magic, or by stepping on one; found traps show as a red `^` (`;` for a loose rock), rubble as `:`
   - stepping on one sets it off, as `hit_trap`: pits (feather fall floats you down) and covered pits (an open pit after), trap doors (down a level), arrows and darts against your AC (STR and CON drains unless sustained, slowing unless free action), gases (sleep unless free action, corrosion, poison, blindness unless resisted, confusion), the teleport rune, the summoning rune (2 + 1d3 monsters, then it's gone), fire and acid, a loose rock (something under it) and a rockfall (rubble where it was, and you're back where you stepped from); the death screen names the trap
   - `D` disarms a trap you've found next to you: disarming skill (race + class), 2 x the DEX adjustment, the INT adjustment and class adjustment x level / 3, a tenth of it blind, in the dark or confused; skill + 100 - the trap's level over 1d100 removes it with its experience ("You have disarmed the trap.") and you step on; else "You failed to disarm the trap.", or with no skill "You set the trap off!"
   - `T` tunnels: rubble against 1d180, magma 1d600+10, quartz 1d400+10, granite 1d1200+80, with a digging power of (STR + the weapon's dice x sides + its pluses) / 2 (STR + 25 + 50 per point of a TUNNEL weapon); rubble sometimes hides an object; permanent rock never; no weapon, "You dig with your hands, making no progress."
   - magic: Trap Detection/Location (scroll, staff, rod, Detection), Find Traps/Doors (mage), Find Traps (priest) find the traps in view; Trap Creation (scroll, monster spell) puts traps on every floor square round you, no experience for disarming those; Trap/Door Destruction (scroll, wand, spell, Caspanion) and Disarming destroy them
   - the trap list is 32 x 4 bytes of high RAM (saved with it), so saves from before this don't load; the trap code is its own overlay (58, `src/traps.asm`)
   - not yet: shovels and picks (TV_DIGGING isn't converted yet, so `T` digs with your weapon; the TUNNEL bonus is ready for them)
13a. **Throwing** (`MORIA2.C` throw_object/inven_throw/facts/drop_throw, `MISC2.C` tot_dam) *(done)*
   - `v` throws one of anything in the pack ("Fire/Throw which one?") in a direction ("You have 4 Flasks of oil (c)."); confused, it goes astray
   - it flies up to (STR + 20) x 10 / its weight squares (at most 10), stopping at a wall or the first monster in its way
   - to hit: 3/4 of the missile skill (race + class) less the distance, with the player's to-hit less the wielded weapon's plus its own, and the missile adjustment per level; an unseen monster is much harder to hit ("The Dagger finds a mark.")
   - damage: its dice + to-dam, through its slays and brands, maybe a critical ("The Flask of oil hits the Orc.", "The Orc grunts with pain.", "You have killed the Orc."); flasks of oil burn: 2d6 x 3 against anything not immune to fire
   - what hits is used up; what misses or falls short lands on the floor where it stopped or next to it, or 1 in 10 "The Flask of oil disappears."
   - the missile skill is new character data, so saves from before this don't load
   - throwing lives in the trap overlay (58, `src/throw.asm`); the pain words are the device overlay's (`pain_add`)
13b. **Bows** (`MORIA2.C` facts, `MISC1.C` magic_treasure's TV_BOW and missiles, `DESC.C`, `STORE1.C`, `DUNGEON.C` Cubragol's activation) *(done)*
   - Slings, Short and Long Bows, Light and Heavy Crossbows, and Rounded Pebbles, Iron Shots, Arrows, Seeker Arrows, Bolts and Seeker Bolts are items now: in the dungeon, the Weaponsmith, and the Ranger's kit (a Long Bow)
   - a launcher is wielded in the weapon's hand, as in 1.2 (there is no separate bow slot): "a Long Bow (x3) (+5,+6)"; its to-hit counts, its to-dam doesn't ("Bows can't damage."); hitting things with it does its dice (none, or 1d1)
   - `v`/`f` with the ammunition the wielded launcher takes (shots for slings, arrows for bows, bolts for crossbows): the full missile skill, the launcher's to-hit twice, its to-dam added, all of it times its multiplier (x2 sling and short bow, x3 long bow and light crossbow, x4 heavy crossbow), and a range of 20 to 35; other things thrown as before
   - ammunition: "23 Arrows (1d4) (+2,+3)"; magic_treasure gives it m_bonus(1,35) pluses and 1 in 11 egos (Slaying, Fire, Slay Evil, Slay Animal, Dragon Slaying, Wounding), or cursed ones (Backbiting); 7d6 to a pile; each pile has its own number (the C's missile_ctr, saved), and arrows only stack with the pile they came from; wielded, arrows give one blow
   - bows: m_bonus(1,30) and m_bonus(1,20), or cursed; of Might (+7,+13) and Accuracy (+15,+5); Beleg Cuthalion and Bard (long bows) and Cubragol (light crossbows), which activates: "Your bolts are covered in a fiery shield!" (the first bolts in the pack become bolts of Fire, +3+1d3 each) or "The fiery enchantment fails."
   - prices: launchers as weapons (100 a plus), ammunition 5 a plus (it comes 20 at a time); they're felt by pseudo-ID and found by Detect Enchantment; fire and acid burn them as in the C
   - a fix on the way: a critical hit's chance below zero (light things with poor to-hit, bare hands at low level) always made a critical; now never, as the C's signed compare
   - new kinds and the pile counter: saves from before this don't load
   - not yet: wielded ammunition used up in melee (the C uses one per hit)
14a. **Resting and running** (`MORIA1.C` rest/rest_off/disturb, find_init/find_run/area_affect/see_wall/see_nothing, `DUNGEON.C`) *(done)*
   - `R` asks "Rest for how long?": a number (up to 30000) rests that many turns, Enter alone rests until hit points and mana are full (the C's `*`, which a Spectrum can't type without Symbol Shift), space gives up; resting heals twice as fast and digests a little less, as in the C
   - Caps Shift + h j k l y u b n runs (the cursor keys are Caps Shift + 5-8 already, so they still walk): along corridors round their bends, through open rooms until a side opens or closes, stopping beside anything new in view (a monster, an item, a door, stairs, rubble, a trap you know of) and where a corridor branches (the C's find_examine and find_cut, both on); at most 100 steps ("You stop running to catch your breath."); confused, just a step
   - either stops for a key (which isn't taken as a command), anything said, any hurt, a monster coming into view, or a new level (the C calls disturb() from everywhere; here those cover it)
   - the main loop asks `next_command` (trap overlay, `src/rest_run.asm`) instead of `get_command`
   - not yet: the status line doesn't show "Rest", and there's no repeat count (the C's `0` prefix)
14b. **Doors** (`MORIA2.C` openobject/closeobject/bash/py_bash, `DUNGEON.C` jamdoor, `GENERATE.C` place_door, `CREATURE.C` make_move and mon_move's stun) *(done)*
   - doors are made as the C's place_door: of 8, 3 open (1 in 4 of them broken), 3 closed (24% locked by 11-20, 1% stuck by 11-20) and 2 secret
   - `o` opens a closed door; a locked one is picked with the disarming skill (skill - lock > 1d100: "You have picked the lock.", 1 experience; else "You failed to pick the lock."; confused: "You are too confused to pick the lock."); a stuck one: "It appears to be stuck."; walking into a closed door does the same, and "You open the door."
   - `c` closes an open door ("The door appears to be broken." if it is; "I do not see anything you can close there.")
   - `f` shoulders a closed door: 1d((STR + weight/2) x (20 + |lock|)) < 10 x (STR + weight/2 - |lock|): "The door crashes open!" (broken half the time) and you go through; else maybe "You are off-balance." (1 + 1d2 turns), or "The door holds firm."; at a monster, a shield bash (py_bash: STR, shield and body weight, DEX for the pluses; "You hit the Orc.", "The Orc appears stunned!" / "ignores your bash!", and maybe "You are off balance.")
   - `S` jams a closed door with an Iron Spike (a new item, sold in the General Store, 7d6 to a pile): locked becomes stuck, each spike sticking it more (0, 20, 30, 37...); "The door must be closed first.", "That isn't a door!", "But you have no spikes."
   - monsters: those that open doors pick locks and burst stuck doors (1d((hp+1)(50+n)) < 40(hp-10-n)); the rest bash closed doors (1d((hp+1)(80+n)) < 40(hp-20-n)): "You hear a door burst open!"; a stunned monster recovers (level^2 > 1d5000) or waits: "The Orc recovers and glares at you."
   - doors with a number (locked, stuck, broken) are kept in high RAM, 16 a level (any more are plain); the door code is in the trap overlay (`src/doors.asm`), and resting and running moved to their own overlay (59, `src/rest_run.asm`) to make room
   - `f` was a second fire key (13b); it's force now, as the roguelike keyset has it
   - (chests came in 17, monsters that pass or dig through walls in 19)
14c. **Looking around** (`MORIA2.C` look/look_see/look_mon_desc, `IO.C` screen_map, `DUNGEON.C` locate and ^P, `HELP.C` ident_char) *(done)*
   - `x` (the roguelike keys' look): "Look which direction?", then every monster you can see and every object on a lit or remembered square in sight, in that 45-degree cone (5: all round), nearest first, each until a key, space stopping it ("--Aborting look--"): "You see a Kobold (unhurt).", "You see a Dagger (1d4) ---pause---", "It is on a down staircase ---pause---"; then "That's all you see in that direction." or "You see nothing of interest."; the C's ray scan is done with the game's line of sight; no monster recall (there's no monster memory)
   - `M`: the level a third the size in a border, each 3 x 3 showing its most important thing (you, stairs, items and monsters, doors, walls, floor), until a key
   - `W`: "Map sector [y,x], which is north-east of your sector. Look which direction?" - the view moves half a screen each way, until another key, then comes back
   - Symbol Shift+P (^P): the last 30 messages, oldest at the top; every message is kept as it's printed, the last 32 of them, in a RAM page of their own
   - `/`: "Enter character to be identified :" and the C's list ("k - Kobold.", "# - A stone wall.", '@' your name); Symbol Shift gives the Spectrum's symbols, but [ ] { } | ~ \ need extended mode and can't be asked about
   - `%`: Self Knowledge, as the potion
   - none of them takes a turn
   - the key table, scan_keys and get_command moved into the run overlay (only next_command reads commands) to make resident room; the look code is its own overlay (69, `src/look.asm`)
   - not yet: inscriptions (`{`): an item's record has no room left for one, nor the save for a list of them
15. **The endgame** (`MORIA2.C` mon_take_hit's quest and win, `DUNGEON.C` is_quest and `Q`, `DEATH.C` kingly and the tombstone) *(done)*
   - Sauron (the QUESTOR, level 99) guards his level: while he lives it has no way down (its down stairs are made up stairs), a trap door there is a spiked pit ("You fall into a spiked pit!", half as much again, 1 in 3 "The spikes are poisoned!" for double unless resisted), teleport level only rises, and stair creation makes only up stairs
   - killing him on his level: "Well done!! Go for it!", "A magical stairway appears..." and a stairway down where he fell (or beside it, if something lies there); anywhere else: "Well done!!  Now continue onward towards Morgoth."
   - killing Morgoth wins: "*** CONGRATULATIONS *** You have won the game.", "You cannot save this game, but you may retire when ready."; the status line says Winner, and ^X won't save ("You are a Total Winner,  your character must be retired.")
   - `Q`: "Do you really want to quit? [y/n]" (the character is done: "Killed by Quitting"), or for a winner "Do you want to retire? [y/n]": back to the town with 50 more levels, 250000 gold and 5000000 experience, the crown ("Veni, Vidi, Vici! I came, I saw, I conquered! All Hail the Mighty King!"), then the tombstone, "Killed by Ripe Old Age", "the Magnificent *King*"
   - the quest and the win are character data (saves from before this don't load); unique_killed notes the deaths and the main loop handles them at the end of the turn (`src/endgame.asm`, in the look overlay)
   - not yet: the high score list
16. **Dungeon variety** (`GENERATE.C` build_type1/2/3/5, build_pit/special_pit, vault_monster/vault_trap, `MISC2.C` random_object/place_special, `MISC1.C` get_nmons_num/place_win_monster) *(done)*
   - deeper than 1d200, a room is unusual: 1d5 picks overlapping rectangles (type 1), an inner room (2), a cross (3), or (deeper than 1d200 again) a vault (5); otherwise (deeper again) the level's one monster pit
   - inner rooms (23 x 9, the inner one behind a secret door): just a guardian; a locked treasure vault inside (an object or stairs, 2 + 1d3 guards, 2 + 1d3 traps); pillars, maybe with two little rooms of their own; a maze with monsters, traps and treasure; four small rooms
   - crosses: a big middle pillar, a treasure vault behind a secret door with guards and traps, a little pattern of pillars (perhaps with secret doors), or nothing
   - vaults: the C's eleven templates (seven lesser, four greater behind permanent walls, placed 4 further down and right), with their monsters (from deeper, '@' meaner ones from get_nmons_num), treasure, traps and stairs; 8 and O are guarded "good" and "great" objects (place_special: weapons and armour from 10 levels deeper, always magic, the great ones with an ego chance); a vault takes the room slots beside and below it, and one that won't fit is an inner room
   - pits: by depth a jelly pit, orc pit, troll pit, graveyard, dragon pit (one colour) or demon pit, the inner room packed in ranks, the strongest in the middle; jellies and undead asleep, the rest awake
   - Morgoth: from level 100, 3 times in 5, awake and out of sight (place_win_monster), placed first
   - the monster list holds 64: vaults and pits stop at 56, and a pit is filled from the middle out (the C fills a 95-monster pit from the outside in), so some of the outer, weakest ranks may be missing
   - as in the C, tunnels pass through the inner and permanent walls without digging them, so parts of a level with vaults can be cut off (dig, or use magic)
   - the room code is its own overlay (71, `src/rooms.asm`), the templates and the pits' races made by the converter (`data/vaults.asm`); a level's monsters, objects and traps are now cleared before its rooms are built, and the player starts on a free square
   - not yet: the level feeling (the C's rating)
17. **Chests and what monsters drop** (`MORIA2.C` monster_death/summon_object/chest_trap/openobject/disarm_trap/bash, `MISC1.C` magic_treasure's TV_CHEST, `MORIA1.C` search, `SPELLS.C` detect_trap/td_destroy/disarm_all/td_destroy2) *(done)*
   - monsters drop what they carry now: each race's CM_ treasure bits (objects, gold or both; 60%, 90%, 1d2, 2d2, 4d2) are in its spell record, and what it carries falls within 2 squares of where it died, on open floor in sight of there; GOOD and SPECIAL races drop good and great things (place_special: "You feel something roll beneath your feet." if it's under you); a monster killed by another's breath or ball drops plainly, as the C
   - Morgoth leaves the Massive Iron Crown of Morgoth (+125 to every stat, telepathy, light, see invisible, cursed) and Grond (10d8, +5,+25, [+10], slays and resistances, aggravation), made by the converter from monster_death's own statements
   - the six chests (Small/Large wooden, iron and steel, levels 7 to 50) are items, found anywhere objects are (`~`, too heavy to carry far); magic_treasure makes each 1d(level + 4): empty, locked, a poison needle (strength or poison), a gas trap, an explosion device, summoning runes, or multiple traps, and its name says which once it's known: "a Small wooden chest (Locked)"
   - `o` opens one next to you: a lock is picked with the disarming skill less the chest's level ("You have picked the lock.", its level in experience; "You failed to pick the lock."; "You are too confused to pick the lock."); open, it's "(Empty)", any trap still on it goes off, and what was in it falls round it as if a monster had died there (never good, and no winning by it)
   - the traps: "A small needle has pricked you!" (strength down and 1d4 unless sustained: "You feel weakened!"; or 1d6 and poison 10 + 1d20 unless resisted), "A puff of yellow gas surrounds you!" ("You choke and pass out." for 10 + 1d20, or free action), summoning runes (three monsters, or their groups), "There is a sudden explosion!" (5d8, the chest and all in it gone); the tombstone says "a poison needle" or "an exploding chest"
   - `D` at a chest: "I don't see a trap." until it's known, "The chest was not trapped.", or the disarming skill less its level: "You have disarmed the chest." (its level in experience; "(Locked)" if it still is, else "(Disarmed)"), "You failed to disarm the chest.", or "You set a trap off!"
   - `f` at a chest: 1 in 10 "You have destroyed the chest." "and its contents!" (a ruined chest), else 1 in 10 "The lock breaks open!", else "The chest holds firm."
   - searching finds a chest's trap ("You have discovered a trap on the chest!", then "The chest is trapped!"); trap detection shows what traps the chests in view have; Trap/Door Destruction round you disarms and unlocks them ("You have disarmed the chest."), a wand of Disarming "Click!"s them open ("(Unlocked)"), and Trap/Door Destruction's beam destroys them
   - Sauron's stairway takes the square he fell on even if what he dropped is there (the C deletes anything but an artifact for it), moving aside only for an artifact or a trap
   - chests are kept out of the class checks that take everything from bows on as arms (Detect Enchantment, enchanting, pseudo-ID) or as wearable
   - the drop and chest code is its own overlay (72, `src/chests.asm`), reached from anywhere through the resident `chest_call`, which reads back which pages were in slots 1 and 2 and puts them back; the tombstone's words moved to the activation data page (`src/killers.asm`) to make room in the creation overlay
   - the kinds are renumbered (chests, the ruined chest), so the save version is 2 and older saves don't load
   - not yet: an opened chest keeps its price (what a race drops is remembered since 18)
18. **Monster memory** (`RECALL.C` roff_recall, `TYPES.H` recall_type, the `c_recall` updates in `CREATURE.C`, `MORIA2.C`, `MISC2.C` tot_dam and `SPELLS.C`, `HELP.C` ident_char, `MORIA2.C` look_see) *(done)*
   - every race has the C's memory: how it has been seen to move (normally, erratically, attacking only, opening doors, invisibly), its spells and breaths and how often it casts, kills and the characters it has killed, what it is (evil, undead, demon, the immunities, light and rock remover, cold-blooded, can't be charmed, casts intelligently), how alert it is (seen to wake, or sleep on), what it was seen to drop, and each blow it has landed
   - it's learnt as the C learns it: watching it move and wake, its blows and spells, killing it (seen), slays and brands striking it, wands, staffs, spells and scrolls it resists or that hurt it (bolts and balls, light, stone to mud, sleep, drain life, turn undead, banishment, dispel), protection from evil repelling it, confusing hands; each kept in the C's own bits against the race's real flags (the converter puts the C's cmove and cdefense of each race in a page of their own)
   - `x` (look): "You see a Jackal (unhurt). [(r)ecall]"; `r` shows it, as the C words it: "The Jackal:", the history ("No battles to the death are recalled.", "At least 3 of these creatures have been killed by your ancestors.", for uniques "It has slain 1 of your ancestors, who remains unavenged." / "You have slain this foe."), the description (MON_DESC.DAT's, all 549 in six pages), depth and movement, "A kill of this evil orc is worth 30.00 points for a 3rd level character.", breaths and spells, armour and life rating after enough kills, abilities, weaknesses and resistances, alertness, what it may carry, its blows (the damage once seen enough), "Killing one of these wins the game!", then "--pause--"
   - `/`: after what the symbol is, "You recall those details? [y/n]" and each race of that symbol you know something of, the deepest first (space stops)
   - the memory outlives the character, as the C's: it's kept as roguelike.mem on the SD card, written when you save and when a character dies (the race that killed you remembered for it), and read at start-up
   - the memory is three RAM pages (74-76, 32 bytes a race); the code is its own overlay (73, `src/recall.asm`), reached through the resident `learn` (and `recall_call`, as `chest_call`); `pack_combine` moved there too, and the device overlay's copy of `msg_add_u16` went, to make room
   - not yet: a few of the C's learning points with no port counterpart yet (breeding, eating others, picking up objects); cold blood and invisibility are learnt while it's in view rather than exactly where `update_mon` finds them
19. **Monsters in the walls** (`CREATURE.C` make_move's CM_PHASE and BREAK_WALL, `MORIA2.C` twall and move_char) *(done)*
   - those that pass through walls (CM_PHASE: ghosts, elementals, xorns...) step into granite, magma, quartz, rubble and closed doors as if they were floor, and leave them as they were; permanent rock (the outer wall, the greater vaults) stops them
   - those that bore (BREAK_WALL: umber hulks, Morgoth...) dig through rock and rubble as they come, the square becoming floor (in a room, like the room floor beside it, lit or not; else a corridor), and burst closed and secret doors open, broken ("You hear a door burst open!"); permanent rock stops them too
   - walking into a monster you can see in the rock attacks it; one you can't is just "There is a wall in the way." (find it by tunnelling, which fights whatever's there), as the C's move_char
   - monster memory learns both: "It can pass through walls" when one's seen doing it, "It can bore through rock" whenever one digs, seen or not
   - the digging is the trap overlay's (`mon_dig`, `src/doors.asm`); make_move tries them before doors, as the C
   - not yet: monsters that eat others or pick things up; bolts still stop at the rock a monster stands in (as the C's)

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
| `$BB43-$BBC2` | traps, 32 x 4 bytes (y, x, type, found/made) |
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
| 58 `PAGE_TRAP` | `traps.asm`, `throw.asm` | placing traps and rubble, setting them off, `D`, `T`, trap magic; `v` throwing |
| 54 `PAGE_DEVICE` | `devices.asm` | wands, staffs, rods and artifact activation: bolts, balls, beams (borrows scroll and potion effects through `device_xcall`) |
| 73 `PAGE_RECALL` | `recall.asm`, `combine.asm` | monster memory: learning it, `r` and `/` showing it; joining stacks (`pack_combine`) |
| 72 `PAGE_CHEST` | `chests.asm` | what monsters drop (`monster_death`), Morgoth's crown and Grond, chests: opening, their traps, `D`, `f`, searching and magic (reached through the resident `chest_call`) |

Data pages (slot 1, `$2000`): 44-48 `RACE_PAGE` = `data/races.asm` (128 x 64-byte races per page, name inline); 60-62 `KIND_PAGE` = `data/kinds.asm` (128 kinds per page); the flavours (`data/flavours.asm`: potion colours, woods, metals, stones, amulets, the title syllables, the buffer this game's scroll titles are written into, normal_table) have their own page. 63 `EGO_PAGE` = `data/egos.asm` (ego and artifact names, flags and numbers, 24 bytes each); 64 `FLAVOUR_PAGE` = `data/flavours.asm`; 65 `ACT_PAGE` = `data/activate.asm`; 66 `SPELL_PAGE` = `data/spells.asm`. The level tables (`data/alloc.asm`) live in the level overlay and the treasures (`data/tables.asm`) are resident.

Resident code ends around `$AEA1` after milestone 9d-1 (about 350 bytes left; `player_init` moved to the misc overlay, `magic_items.asm` moved to the misc overlay, the knowledge tables to `$7C00` and the experience table into the creation overlay to make room) (`status.asm` holds the stat tables, timed-effect counters, what the player knows, the colour order and the after-use identify logic; `pack.asm` the item lists and chooser), the monster list starting at `$B000`. The creation overlay is at 7.7K of 8K, the magic overlay 6.7K, the items overlay 7.1K, the store overlay 7.1K, the scroll overlay 4.0K, the device overlay 8.0K (full), the spell overlay 5.6K, the misc overlay 3.4K, the monster spell overlay 7.8K (9d-4, with the melee effects; its words in page 68), the level overlay 5.9K. Resident code ends at `$AC83` after 9d-4 (the blow messages and to-hit table moved out).

Overlays that change stats or bonuses set `p_update`; `draw_view` (main loop only) runs `update_stuff`, which pages the items overlay to recalculate. Item commands that need the magic overlay leave `pending_magic` for `pending_actions` in the main loop.

Rules: only resident code uses `FARCALL` (exceptions: `level_call`, which the scroll overlay uses to reach the level overlay, and `device_xcall`, which the device overlay uses to borrow scroll, potion and level routines; both page the caller back in before returning; and `overlay_call`, through the `OVCALL page, routine, back` macro, which any overlay can use to borrow another's routine; anything it passes by address must be outside the overlay window, since the caller's page is out while it runs: the stores make new stock in the resident `new_rec`); overlay code may call resident code but otherwise never another overlay; data an overlay owns stays in that overlay. New overlays go in the next free pages (42, 43...) with an `MMU 2, page, $4000` block in `roguelike.asm`.
