/* mcast_text.asm - what the monster spells (mcast.asm, mexotic.asm) and
	monster blows (mmelee.asm) say, kept in the monster text page and
	printed through mx_say / mx_print, to leave room in the overlay */

mz_blinks:			db "blinks away.",0
mz_teleports:		db "teleports away.",0
mz_commands:		db "commands you to return!",0
mz_teleports_you:	db "teleports you away.",0
mz_curses:			db "points at you and curses.",0
mz_curses_horribly: db "points at you and curses horribly.",0
mz_incanting:		db "points at you, incanting terribly!",0
mz_scream_die:		db "points at you, screaming the word DIE!",0
mz_stares:			db "stares at you.",0
mz_glow_red:		db "concentrates and its eyes glow red.",0
mz_gazes:			db "gazes deep into your eyes!",0
mz_burning:		db "casts a spell, burning your eyes!",0
mz_mesmerising:	db "creates a mesmerising illusion.",0
mz_fearful:		db "casts a fearful illusion.",0
mz_drains_power:	db "drains power from your muscles!",0
mz_psychic:		db "draws psychic energy from you!",0
mz_appears_healthier: db "appears healthier.",0
mz_concentrates:	db "concentrates on its wounds.",0
mz_as_healthy:		db "looks as healthy as can be.",0
mz_really_healthy:	db "looks REALLY healthy!",0
mz_looks_healthier: db "looks healthier.",0
mz_casts_spell:	db "casts a spell.",0
mz_faster:			db "starts moving faster.",0
mz_br_lightning:	db "breathes lightning.",0
mz_br_gas:			db "breathes gas.",0
mz_br_acid:		db "breathes acid.",0
mz_br_frost:		db "breathes frost.",0
mz_br_fire:		db "breathes fire.",0
mz_fire_bolt:		db "casts a Fire bolt.",0
mz_frost_bolt:		db "casts a Frost bolt.",0
mz_acid_bolt:		db "casts a Acid bolt.",0
mz_mmissile:		db "casts a Magic missile.",0
mz_mana_bolt:		db "casts a Mana bolt.",0
mz_light_bolt:		db "casts a Lightning bolt.",0
mz_missiles:		db "fires missiles at you.",0
mz_plasma:			db "casts a Plasma bolt.",0
mz_ice_bolt:		db "casts an Ice bolt.",0
mz_water_bolt:		db "casts a Water bolt.",0
mz_fire_ball:		db "casts a Fire ball.",0
mz_frost_ball:		db "casts a Frost ball.",0
mz_light_ball:		db "casts a Lightning ball.",0
mz_acid_ball:		db "casts an Acid ball.",0
mz_stinking:		db "casts a Stinking cloud.",0
mz_summons_help:	db "magically summons help!",0
mz_beyond_grave:	db "magically summons help from beyond the grave!",0
mz_hellish:		db "summons a hellish adversary!",0
mz_a_dragon:		db "magically summons a Dragon!",0
mz_summons_monsters: db "magically summons monsters!",0
mz_an_angel:		db "summons an Angel.",0
mz_spiders:		db "magically summons Spiders.",0
mz_hounds:			db "magically summons Hounds.",0
mz_the_dead:		db "summons the DEAD!",0
mz_ancient_dragons: db "summons Ancient Dragons.",0
mcm_resist_spell:	db "You resist the effects of the spell.",0
mcm_resist_effects:	db "You resist the effects.",0
mcm_laugh:			db "You laugh at the feeble spell.",0
mcm_bleed:			db "You start to bleed!",0
mcm_mind_blasted:	db "Your mind is blasted by psionic energy.",0
mcm_avert:			db "You avert your gaze!",0
mcm_unaffected:		db "You are unaffected.",0
mcm_stare_back:		db "You stare back unafraid!",0
mcm_vision_clears:	db "You blink and your vision clears.",0
mcm_disbelieve:		db "You disbelieve the feeble spell.",0
mcm_not_frightened:	db "You refuse to be frightened.",0
mcm_body_resists:	db "Your body resists the spell.",0
mcm_smoke:			db "There is smoke coming from your pack!",0
mcm_shatters:		db "Something shatters inside your pack!",0
mcm_acrid:			db "There is an acrid smell coming from your pack!",0
mz_br_chaos:		db "breathes Chaos.",0
mz_br_shards:		db "breathes shards.",0
mz_br_sound:		db "breathes sound.",0
mz_br_confusion:	db "breathes confusion.",0
mz_br_disenchant:	db "breathes disenchantment.",0
mz_br_nether:		db "breathes nether.",0
mz_br_nexus:		db "breathes Nexus.",0
mz_br_force:		db "breathes elemental force.",0
mz_br_inertia:		db "breathes inertia.",0
mz_br_light:		db "breathes light.",0
mz_br_time:			db "breathes time.",0
mz_br_gravity:		db "breathes gravity.",0
mz_br_dark:			db "breathes darkness.",0
mz_br_plasma:		db "breathes plasma.",0
mz_dark_storm:		db "casts a darkness storm.",0
mz_mana_storm:		db "invokes a Mana storm.",0
mz_nether_bolt:		db "casts a Nether bolt.",0
mz_nether_ball:		db "casts a Nether Ball.",0
mz_shadow:			db "gestures in shadow.",0
mz_blank_mind:		db "tries to blank your mind.",0
mz_gestures:		db "gestures at you.",0
mz_fluidly:			db "gestures fluidly.",0
mz_arrow:			db "fires an arrow at you.",0
mz_mighty_undead:	db "magically summons mighty undead opponents.",0
mz_reptiles:		db "magically summons reptiles.",0
mz_ants:			db "magically summons ants.",0
mz_special:			db "summons special opponents!",0
mcm_draining:		db "You feel your life draining away!",0
mcm_slipping:		db "You feel your life slipping away!",0
mcm_keep_life:		db "You keep hold of your life force!",0
mcm_static:			db "There is a static feeling in the air.",0
mcm_less_able:		db "You feel less able to move.",0
mcm_flash:			db "You are blinded by the flash!",0
mcm_clocked:		db "You feel life has clocked back.",0
mcm_strong:			db "You're not as strong as you used to be...",0
mcm_bright:			db "You're not as bright as you used to be...",0
mcm_wise:			db "You're not as wise as you used to be...",0
mcm_agile:			db "You're not as agile as you used to be...",0
mcm_hale:			db "You're not as hale as you used to be...",0
mcm_beautiful:		db "You're not as beautiful as you used to be...",0
mcm_gravity:		db "Gravity warps around you.",0
mcm_scramble:		db "Your body starts to scramble...",0
mcm_resist_spell2:	db "You resist the spell.",0
mcm_memories:		db "Your memories fade away.",0
mcm_firm:			db "You keep your feet firmly on the ground.",0
mcm_sink:			db "You sink through the floor.",0
mcm_rise:			db "You rise up through the ceiling.",0
mcm_whirlpool:		db "You are engulfed in a whirlpool.",0
mcm_collapses:		db "The cave ceiling collapses!",0
mcm_floor_turns:	db "The floor turns and crushes you!",0
mcm_pummeled:		db "You are pummeled with debris!",0
mcm_trapped:		db "You are trapped, crushed and cannot move!",0
mcm_rubble:			db "The rubble bashes you!",0
mcm_dodge:			db "But you nimbly dodge the blast!",0
mcm_crushes:		db "The floor crushes you against the ceiling!",0


; ---------------------------------------------------------------- monster blows (mmelee.asm)

mb_hits:			db "hits you.",0
mb_bites:			db "bites you.",0
mb_claws:			db "claws you.",0
mb_stings:			db "stings you.",0
mb_touches:			db "touches you.",0
mb_kicks:			db "kicks you.",0
mb_gazes:			db "gazes at you.",0
mb_breathes:		db "breathes on you.",0
mb_spits:			db "spits on you.",0
mb_wails:			db "makes a horrible wail.",0
mb_embraces:		db "embraces you.",0
mb_crawls:			db "crawls on you.",0
mb_spores:			db "releases a cloud of spores.",0
mb_begs:			db "begs you for money.",0
mb_slimed:			db "You've been slimed!",0
mb_crushes:			db "crushes you.",0
mb_tramples:		db "tramples you.",0
mb_drools:			db "drools on you.",0
mb_insults:			db "insults you!",0
mb_butts:			db "butts you.",0
mb_charges:			db "charges you.",0
mb_engulfs:			db "engulfs you.",0
mb_attacks:			db "attacks you.",0
mb_insult1:			db "insults you!",0
mb_insult2:			db "insults your mother!",0
mb_insult3:			db "gives you the finger!",0
mb_insult4:			db "humiliates you!",0
mb_insult5:			db "wets on your leg!",0
mb_insult6:			db "defiles you!",0
mb_insult7:			db "dances around you!",0
mb_insult8:			db "makes obscene gestures!",0
mb_insult9:			db "moons you!!!",0
mb_maggot1:			db "wants his mushrooms back",0
mb_maggot2:			db "tells you to get off his land",0
mb_maggot3:			db "looks for his dogs",0
mb_maggot4:			db "says 'Did you kill my Fang?'",0
mb_maggot5:			db "asks 'Do you want to buy any mushrooms?'",0
mb_weaker:			db "You feel weaker.",0
mb_weaker_moment:	db "You feel weaker for a moment, but it passes.",0
mb_confused:		db "You feel confused.",0
mb_stand:			db "You stand your ground!",0
mb_afraid:			db "You are suddenly afraid!",0
mb_flames:			db "You are enveloped in flames!",0
mb_acid:			db "You are covered in acid!",0
mb_frost:			db "You are covered with frost!",0
mb_lightning:		db "Lightning strikes you!",0
mb_red_gas:			db "A stinging red gas swirls about you.",0
mb_acrid:			db "There is an acrid smell coming from your pack.",0
mb_sting:			db "Your eyes begin to sting.",0
mb_resist:			db "You resist the effects!",0
mb_paralysed:		db "You are paralysed.",0
mb_pouch:			db "You quickly protect your money pouch!",0
mb_purse:			db "Your purse feels lighter.",0
mb_backpack:		db "You grab hold of your backpack!",0
mb_lighter:			db "Your backpack feels lighter.",0
mb_smoke:			db "There is a puff of smoke!",0
mb_sick:			db "You feel very sick.",0
mb_no_effect:		db "The poison has no effect.",0
mb_trouble:			db "You have trouble thinking clearly.",0
mb_mind_clears:		db "But your mind quickly clears.",0
mb_wis_drained:		db "Your wisdom is drained.",0
mb_wis_sustained:	db "Your wisdom is sustained.",0
mb_clumsy:			db "You feel more clumsy.",0
mb_clumsy_moment:	db "You feel clumsy for a moment, but it passes.",0
mb_health:			db "Your health is damaged!",0
mb_disease:			db "Your body resists the effects of the disease.",0
mb_twisted:			db "Your features are twisted.",0
mb_good_looks:		db "You keep your good looks.",0
mb_stirring:		db "You hear a sudden stirring in the distance!",0
mb_rations:			db "It got at your rations!",0
mb_energy:			db "Energy drains from your pack!",0
mb_wails_pain:		db " wails out in pain!",0
mb_embedded:		db " is embedded in the rock.",0
