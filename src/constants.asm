/* constants.asm - memory map, Next registers, game constants */

; ---- memory ----
CODE_START			equ $8000
stack_top			equ $C000
STACK_SIZE			equ 256
TILEMAP_BASE		equ $6000			; must be in bank 5
TILEDEF_BASE		equ $7400
MAP_BASE			equ $C000
MAP_PAGE			equ 32				; 8K pages 32/33 (16K bank 16)
OVERLAY_WINDOW		equ $4000			; MMU slot 2
PAGE_LEVEL			equ 40				; overlay: level generation, monster placement
PAGE_MISC			equ 41				; overlay: start-up, death screen
PAGE_ITEMS			equ 42				; overlay: inventory and item commands
PAGE_CREATE			equ 43				; overlay: character creation, sheet, death
PAGE_STORE			equ 51				; overlay: the town's stores
PAGE_MAGIC			equ 52				; overlay: potions, timed effects, stats
PAGE_SCROLL			equ 53				; overlay: reading scrolls
PAGE_DEVICE			equ 54				; overlay: wands, staffs, rods
PAGE_SPELL			equ 55				; overlay: spells, mana, learning
PAGE_MCAST			equ 56				; overlay: monsters casting spells
PAGE_SAVE			equ 57				; overlay: saving and restoring the game
PAGE_TRAP			equ 58				; overlay: traps, rubble, disarming, tunnelling
PAGE_SCREEN_HI		equ 11				; bank 5's upper half, normally in slot 3
DATA_WINDOW			equ $2000			; MMU slot 1: race and kind data pages
EGO_PAGE			equ 63				; ego names and flags (data/egos.asm)
ACT_PAGE			equ 65				; what activating does (data/activate.asm)
SPELL_PAGE			equ 66				; each class's spells, their names
MSPELL_PAGE			equ 67				; each monster race's spells (data/mspells.asm)
MTEXT_PAGE			equ 68				; what monster spells and blows say (src/mcast_text.asm)
RACE_PAGE			equ 44				; 5 pages of races (data/races.asm)
KIND_PAGE			equ 60				; item kinds, 128 per page (data/kinds.asm)
FLAVOUR_PAGE		equ 64				; flavour names and colours, titles, normal_table
IM2_TABLE			equ $BC00			; 257 bytes of $BD
KNOWLEDGE			equ $7C00			; bank 5's spare 1K, after the tile definitions:
object_ident		equ KNOWLEDGE		;  what the player knows, 64 per object_offset
flavour_map			equ object_ident+8*64	;  colour shown for each potion
wood_map			equ flavour_map+57	;  wood for each staff
metal_map			equ wood_map+32		;  metal for each wand and rod
rock_map			equ metal_map+32	;  stone for each ring
amulet_map			equ rock_map+39		;  material for each amulet
KNOWLEDGE_END		equ amulet_map+16
	ASSERT KNOWLEDGE_END <= $8000
IM2_JUMP			equ $BDBD			; jp im2_handler

; ---- banking ----
; FARCALL page, routine - page an overlay into the window and call it
	MACRO FARCALL ov_page, ov_routine
		nextreg NR_MMU2, ov_page
		call ov_routine
	ENDM
; OVCALL page, routine, back - call a routine in another overlay from an
; overlay (page back), through overlay_call. Clobbers BC; A, HL, DE, IX, IY
; and flags pass through
	MACRO OVCALL ov_page, ov_routine, ov_back
		push hl
		ld hl,ov_routine
		ld (xc_target),hl
		pop hl
		ld bc,ov_page*256+ov_back
		call overlay_call
	ENDM

; ---- Next registers ----
NR_CPU_SPEED		equ $07
NR_TILEMAP_XOFF_MSB	equ $2F
NR_TILEMAP_XOFF_LSB	equ $30
NR_TILEMAP_YOFF		equ $31
NR_PAL_INDEX		equ $40
NR_PAL_VALUE8		equ $41
NR_PAL_CONTROL		equ $43
NR_MMU0				equ $50
NR_MMU1				equ $51
NR_MMU2				equ $52
NR_MMU3				equ $53
NR_MMU6				equ $56
NR_MMU7				equ $57
NR_ULA_CONTROL		equ $68
NR_TILEMAP_CONTROL	equ $6B
NR_TILEMAP_ATTR		equ $6C
NR_TILEMAP_BASE		equ $6E
NR_TILEDEF_BASE		equ $6F

; ---- screen layout (80x32 text) ----
SCREEN_W			equ 80
SCREEN_H			equ 32
MSG_ROW				equ 0
MSG_WIDTH			equ 72				; leave room for -more-
VIEW_TOP			equ 1
VIEW_W				equ 80
VIEW_H				equ 30
STATUS_ROW			equ 31
SCROLL_MARGIN_X		equ 10				; recentre when this close to an edge
SCROLL_MARGIN_Y		equ 5

; ---- colours: attribute = colour * 2 (text mode palette offset) ----
COL_WHITE			equ 0
COL_GREY			equ 1
COL_DARK			equ 2
COL_YELLOW			equ 3
COL_RED				equ 4
COL_GREEN			equ 5
COL_BLUE			equ 6
COL_UMBER			equ 7
COL_MAGENTA			equ 8
NUM_COLOURS			equ 32

ATTR_WHITE			equ COL_WHITE*2
ATTR_GREY			equ COL_GREY*2
ATTR_DARK			equ COL_DARK*2
ATTR_YELLOW			equ COL_YELLOW*2
ATTR_RED			equ COL_RED*2
ATTR_GREEN			equ COL_GREEN*2
ATTR_BLUE			equ COL_BLUE*2
ATTR_UMBER			equ COL_UMBER*2
ATTR_MAGENTA		equ COL_MAGENTA*2
; colours 16-31 are the 16 PC (Turbo C) colours the data uses
COL_TC				equ 16

; ---- dungeon (same size as Angband: CONSTANT.H MAX_HEIGHT/MAX_WIDTH) ----
MAP_W				equ 198
MAP_H				equ 66

; terrain ids - index into terrain_table (map.asm)
T_NULL				equ 0				; untouched rock (generation only)
T_FLOOR				equ 1				; room floor
T_CORRIDOR			equ 2
T_GRANITE			equ 3
T_PERMWALL			equ 4
T_DOOR_CLOSED		equ 5
T_DOOR_OPEN			equ 6
T_DOOR_SECRET		equ 7				; looks like granite
T_STAIR_DOWN		equ 8
T_STAIR_UP			equ 9
T_TMP1				equ 10				; pillar (generation only)
T_RUBBLE			equ T_TMP1			; ... after it: rubble, dug out with T
T_TMP2				equ 11				; wall a tunnel pierced (generation only)
T_MAGMA				equ 12
T_QUARTZ			equ 13
T_FLOOR_LIT			equ 14				; room floor that lights up on entry
T_STORE				equ 15				; a store entrance (town only)
TERRAIN_MASK		equ $0F				; terrain id is the low 4 bits

; per-square flags in the top 4 bits of each map byte (like cave_type's
; MSDOS bitfields: lr, pl, tl, fm)
F_ROOM_BIT			equ 4				; part of a room (lr)
F_PERM_BIT			equ 5				; lit for good / remembered (pl)
F_LAMP_BIT			equ 6				; lit by the player's light (tl)
F_ROOM				equ 1<<F_ROOM_BIT
F_PERM				equ 1<<F_PERM_BIT
F_LAMP				equ 1<<F_LAMP_BIT
F_SEEN				equ F_PERM|F_LAMP	; drawn if either is set
F_MON_BIT			equ 7				; a monster stands here (like cptr != 0)
F_MON				equ 1<<F_MON_BIT
LIGHT_QUEUE			equ TUN_STACK		; room flood fill queue, reuses
LIGHT_QUEUE_MAX		equ TUN_MAX*2		; tunnel+wall stacks (addresses)

; terrain flags (bit numbers)
TF_PASSABLE			equ 0
TF_WALL				equ 1				; counts as wall for door/stair placement
TF_REMEMBER			equ 2				; stays on the map once your light touches it

; ---- level generation (GENERATE.C / CONSTANT.H DUN_*) ----
ROOM_ROWS			equ 6				; room grid: 2*(MAP_H/22) x 2*(MAP_W/66)
ROOM_COLS			equ 6
DUN_ROOMS_MIN		equ 42				; rooms picked = 42+1d6 (randnor(45,2))
DUN_UNUSUAL			equ 200				; level/x chance of an unusual room
DUN_TUN_RND			equ 9				; 1/x chance of a random direction
DUN_TUN_CHG			equ 70				; % chance of changing direction
DUN_TUN_CON			equ 15				; % chance of extra tunnelling
DUN_TUN_PEN			equ 25				; % chance of a door where a tunnel enters a room
DUN_TUN_JCT			equ 8				; % chance of doors at tunnel junctions
DUN_STR_DEN			equ 5				; streamer density
DUN_STR_MAG			equ 3				; number of magma streamers
DUN_STR_QUA			equ 2				; number of quartz streamers
TUN_STEPS_MAX		equ 2000

; scratch buffers used while generating, in the map pages after the map
TUN_MAX				equ 600
DOOR_MAX			equ 100
TUN_STACK			equ $F400			; TUN_MAX x (y, x)
WALL_STACK			equ TUN_STACK+TUN_MAX*2
DOOR_STACK			equ WALL_STACK+TUN_MAX*2
ROOM_LIST			equ DOOR_STACK+DOOR_MAX*2	; up to 37 x (y, x)
ROOM_MAP			equ ROOM_LIST+80			; ROOM_ROWS x ROOM_COLS
	ASSERT MAP_BASE+MAP_W*MAP_H <= TUN_STACK
	ASSERT ROOM_MAP+ROOM_ROWS*ROOM_COLS <= $10000

; ---- monsters (MONSTERS.C, MISC1.C place_monster, CREATURE.C) ----
MON_LIST			equ $B000			; MON_MAX records of MON_SIZE bytes
MON_MAX				equ 64
MON_SIZE			equ 16
MON_EMPTY			equ $FF				; M_RACE_HI of a free slot
; monster record
M_RACE				equ 0				; race number, low byte
M_Y					equ 1
M_X					equ 2
M_HP				equ 3				; word
M_MAXHP				equ 5				; word
M_SLEEP				equ 7				; word (csleep)
M_SPEED				equ 9				; signed (cspeed = speed - 10)
M_CDIS				equ 10				; distance from player
M_ML				equ 11				; 1 if the player can see it
M_RACE_HI			equ 12				; race number, high byte ($FF = free slot)
M_CONFUSED			equ 13				; 1 while confused
; race record (data/races.asm, made by tools/convert.py from MONSTERS.C)
RACE_SIZE			equ 64				; 128 per 8K page
R_CHAR				equ 0
R_ATTR				equ 1
R_MOVE				equ 2				; RM_ flags
R_EXP				equ 3				; word
R_SLEEP				equ 5
R_AAF				equ 6				; how far away it notices you
R_AC				equ 7
R_SPEED				equ 8				; 11 = normal
R_HD_DICE			equ 9
R_HD_SIDES			equ 10
R_LEVEL				equ 11
R_RARITY			equ 12
R_FLAGS				equ 13				; RF_ bits
R_ATTACKS			equ 16				; 4 x (type, description, dice, sides)
R_NAME				equ 32				; the name itself, zero-terminated
; R_FLAGS bits (MONSTER.H cdefense / cmove)
RF_UNIQUE			equ 0
RF_MAX_HP			equ 1
RF_INVISIBLE		equ 2
RF_EVIL				equ 3
RF_UNDEAD			equ 4
RF_DEMON			equ 5
RF_NO_INFRA			equ 6
RF_CHARM_SLEEP		equ 7				; can't be confused or slept
R_FLAGS2			equ 14				; RF2_ bits
RF2_WIN				equ 0				; CM_WIN: Sauron, Morgoth
RF2_PHASE			equ 1				; CM_PHASE: passes through walls
RF2_BREAK_WALL		equ 2				; BREAK_WALL: digs through them
RF2_ANIMAL			equ 3				; what slays and brands look for
RF2_ORC				equ 4
RF2_DRAGON			equ 5
RF2_TROLL			equ 6
RF2_GIANT			equ 7
R_RESIST			equ 15				; RR_ bits
RR_FROST			equ 0				; IM_FROST
RR_FIRE				equ 1
RR_LIGHTNING		equ 2
RR_POISON			equ 3
RR_ACID				equ 4
RR_HURT_LIGHT		equ 5
RR_HURT_ROCK		equ 6
RR_SPELLS			equ 7				; it has spells (mon_cast_spell is tried)
; monster spells (data/mspells.asm): CS_ bits of spells, spells2, then
; spells3's low word (cast n is bit n-1), then RS_ flags
MS_SIZE				equ 12
MS_BITS				equ 80
MS_FLAGS			equ 10
RS_SMART			equ 0				; INTELLIGENT: casts to escape when hurt
RS_DESTRUCT			equ 1				; DESTRUCT: its heavy blows shake the cave
CS_FREQ				equ $0F				; 1 in this many turns it casts
MAX_SPELL_DIS		equ 18				; the furthest a spell is cast from
; what summon_by (level overlay) brings
SUM_MONSTER			equ 0
SUM_UNDEAD			equ 1
SUM_DEMON			equ 2				; up to the summoner's level
SUM_DRAGON			equ 3
SUM_ANGEL			equ 4
SUM_SPIDER			equ 5
SUM_HOUND			equ 6
SUM_GUNDEAD			equ 7
SUM_ANCIENTD		equ 8
SUM_WRAITH			equ 9				; uniques only
SUM_REPTILE			equ 10
SUM_ANT				equ 11
SUM_UNIQUE			equ 12				; uniques only, but not 'P'
SUM_JABBERWOCK		equ 13
; bolt and ball elements (the C's GF_ types)
GF_MAGIC_MISSILE	equ 0
GF_LIGHTNING		equ 1
GF_POISON_GAS		equ 2
GF_ACID				equ 3
GF_FROST			equ 4
GF_FIRE				equ 5
; R_MOVE bits (MONSTER.H cmove flags)
RM_ONLY_ATT			equ 0				; MV_ONLY_ATT: never moves
RM_NORMAL			equ 1				; MV_ATT_NORM: chases
RM_20				equ 2				; MV_20: 20% random moves
RM_40				equ 3
RM_75				equ 4
RM_GROUP			equ 5				; GROUP: appears in packs
RM_OPEN_DOOR		equ 6				; THRO_DR: opens doors
MAX_SIGHT			equ 20
MIN_MALLOC_LEVEL	equ 14				; minimum monsters per level

; ---- items (TREASURE.C, MORIA2.C carry, MISC2.C alloc_object) ----
ITEM_LIST			equ $B400			; floor items, ITEM_MAX x ITEM_SIZE
ITEM_MAX			equ 64
PACK				equ ITEM_LIST+ITEM_MAX*ITEM_SIZE	; PACK_MAX carried items
PACK_MAX			equ 12				; slots a-l
EQUIP				equ PACK+PACK_MAX*ITEM_SIZE	; EQ_SLOTS worn/wielded items
EQ_SLOTS			equ 11				; slots in use (shown by 'e')
EQ_MAX				equ 12				; room kept for a light and a spare
EQ_WEAPON			equ 0
EQ_BODY				equ 1
EQ_SHIELD			equ 2
EQ_HELM				equ 3
EQ_CLOAK			equ 4
EQ_GLOVES			equ 5
EQ_BOOTS			equ 6
EQ_NECK				equ 7
EQ_RIGHT			equ 8				; rings: right hand first
EQ_LEFT				equ 9
EQ_LIGHT			equ 10				; the light source
ITEM_SIZE			equ 14
ITEM_EMPTY			equ $FF				; I_KIND_HI of a free slot
KIND_GOLD			equ $FE				; I_KIND_HI of a pile of treasure
; item record
I_KIND				equ 0				; word: kinds are 9 bits
I_KIND_HI			equ 1				; (also holds ITEM_EMPTY / KIND_GOLD)
I_NUMBER			equ 2
I_Y					equ 3
I_X					equ 4
I_ATIME				equ 3				; word: worn artifacts, turns until it
										; can be activated again (y, x unused)
I_MARKED			equ 5				; seen on the floor (the C's fm)
I_VALUE				equ 6				; word, gold only
I_PVAL				equ 6				; wands and staffs: charges
I_TIMEOUT			equ 6				; rods: word, turns until it's ready
I_SUB				equ 8				; gold type
I_IDENT				equ 8				; everything else: ID_ flags
I_TOHIT				equ 9				; signed: magical pluses (magic_treasure)
I_TODAM				equ 10
I_TOAC				equ 11
I_NAME2				equ 12				; ego or artifact (9c-3), 0 = none
I_FEEL				equ 13				; FEEL_: how it felt (pseudo-identify)
ID_STORE_BIT		equ 0				; store bought (the C's ID_STOREBOUGHT)
ID_EMPTY_BIT		equ 1				; found to be empty (ID_EMPTY)
ID_KNOWN2_BIT		equ 2				; pluses or charges known (known2)
ID_CURSED_BIT		equ 3				; it is cursed (TR_CURSED)
ID_DAMD_BIT			equ 4				; and the player knows it (ID_DAMD)
ID_MAGIK_BIT		equ 5				; felt to be good (ID_MAGIK)
ID_SHOWHD_BIT		equ 6				; always show (+h,+d) (ID_SHOW_HITDAM)
FEEL_NONE			equ 0				; inscriptions value_check gives
FEEL_AVERAGE		equ 1
FEEL_GOOD			equ 2
FEEL_EXCELLENT		equ 3
FEEL_SPECIAL		equ 4
; kind record (data/kinds.asm, made by tools/convert.py from TREASURE.C)
KIND_SIZE			equ 64				; 128 per 8K page
K_CHAR				equ 0
K_ATTR				equ 1
K_CLASS				equ 2
K_EGO				equ 3				; KE_: equipment magic_treasure treats specially
KE_WHIP				equ 0				; (whips of fire)
KE_ROBE				equ 1				; (robes of the Magi)
KE_NO_RA			equ 2				; mithril and adamantite: never resist acid
KE_SHOD				equ 3				; metal shod boots: never stealth
KE_GAUNTLETS		equ 4				; (the artifact gauntlets)
KE_CLOAK			equ 5				; (the artifact cloaks)
KE_SHADOW			equ 6
K_LEVEL				equ 4
K_WEIGHT			equ 5				; word, tenths of a pound
K_DICE				equ 7
K_SIDES				equ 8
K_AC				equ 9
K_TOHIT				equ 10				; signed
K_TODAM				equ 11				; signed
K_P1				equ 12				; word: food value
K_ARTICLE			equ 14				; 1 if the name takes "a"/"an"
K_TVAL				equ 15				; the C's tval (which stores deal in it)
K_COST				equ 16				; word, base value in gold
K_FLAGS				equ 18				; dword: the C's flags (potion effects)
K_FLAVOUR			equ 22				; subval & 63: index into the flavour tables
K_GROUP2			equ 23				; 1 for TV_POTION2 (effects 33-64)
K_TOAC				equ 24				; signed: base magical AC
K_MAGIC				equ 25				; MC_: how magic_treasure treats it
K_FLAGS2			equ 26				; dword: the C's flags2
K_NAME				equ 30				; the name itself, '~' where plurals add 's'
; magic_treasure classes (K_MAGIC)
MC_NONE				equ 0
MC_ARMOUR			equ 1				; body armour, shields
MC_DRAGON			equ 2				; dragon scale mail: always enchanted
MC_WEAPON			equ 3
MC_GLOVES			equ 4
MC_BOOTS			equ 5
MC_HELM				equ 6
MC_CLOAK			equ 7
MC_CROWN			equ 8
MC_RING				equ 9
MC_AMULET			equ 10
OBJ_TOWN_LEVEL		equ 5				; what level store goods are made at
; ego items: SN_ numbers come with data/egos.asm, 16 bytes each in EGO_PAGE
EGO_SIZE			equ 24
E_FLAGS				equ 0				; dword: flags it adds
E_FLAGS2			equ 4				; dword: flags2 it adds
E_COST				equ 8				; word: gold it adds to the value
E_P1COST			equ 10				; word: gold per point of p1
E_OPTS				equ 12				; EO_ bits
EO_SHOW_P1			equ 0				; show its number: " (+2)"
EO_SHOW_HD			equ 1
EO_DOUBLE			equ 2				; value doubled
EO_ARTIFACT			equ 3				; an artifact: its value is E_COST
EO_OWN_FLAGS		equ 4				; its flags replace the kind's
E_DICE				equ 13				; dice instead of the kind's (0: the kind's)
E_NAME				equ 14				; word: its name, "of Resistance"
E_SIDES				equ 16				; artifacts: sides of its dice (0: the kind's)
E_WEIGHT			equ 17				; word: its weight (0: the kind's)
E_HIT				equ 19				; its to-hit, to-dam, AC, number, as
E_DAM				equ 20				; E_ART says
E_AC				equ 21
E_P1				equ 22
E_ART				equ 23				; EA_ bits
EA_HIT				equ 0				; sets to-hit
EA_DAM				equ 1				; sets to-dam
EA_AC				equ 2				; adds to AC
EA_AC_SET			equ 3				; (sets it)
EA_P1				equ 4				; sets its number
; item classes; wearable ones map to equipment slot class - IC_WEAPON
IC_FOOD				equ 1
IC_POTION			equ 2
IC_SCROLL			equ 3
IC_WAND				equ 4
IC_STAFF			equ 5
IC_ROD				equ 6
IC_WEAPON			equ 7
IC_BODY				equ 8
IC_SHIELD			equ 9
IC_HELM				equ 10
IC_CLOAK			equ 11
IC_GLOVES			equ 12
IC_BOOTS			equ 13
IC_AMULET			equ 14				; (slot 7, the neck)
IC_RING				equ 15				; (slots 8 and 9)
IC_MAGIC_BOOK		equ 16				; (carried, not worn)
IC_PRAYER_BOOK		equ 17
IC_LIGHT			equ 18				; Wooden Torches (they stack, by fuel)
IC_FLASK			equ 19				; Flasks of oil
IC_LANTERN			equ 20				; lanterns and the light artifacts
OBJ_LAMP_MAX		equ 15000			; the most a lamp holds
FILTER_CHARGED		equ $FE				; choose_pack filter: wand or staff
TREAS_ROOM_ALLOC	equ 9				; mean objects in rooms
TREAS_ANY_ALLOC		equ 3				; mean objects anywhere
TREAS_GOLD_ALLOC	equ 3				; mean piles of treasure
OBJ_GREAT			equ 11
MAX_GOLD			equ 18

; the character's tables, after the pack (create.asm fills them)
P_HP_TABLE			equ EQUIP+EQ_MAX*ITEM_SIZE	; player_hp[50], words
P_EXP_TABLE			equ P_HP_TABLE+100	; experience needed, 50 dwords

; ---- the town (GENERATE.C town_gen, STORE1.C, STORE2.C) ----
TOWN_H				equ 22				; SCREEN_HEIGHT
TOWN_W				equ 66				; SCREEN_WIDTH
NUM_STORES			equ 8				; 6 shops, the black market, home
STORE_BLACK			equ 6
STORE_HOME			equ 7
STORE_INVEN_MAX		equ 24
STORE_ITEM			equ 11				; stock entry (store_inv, in the store overlay):
SE_KIND				equ 0				;  word
SE_NUMBER			equ 2
SE_DISC				equ 3				;  special offer
SE_PVAL				equ 4				;  charges
SE_TOHIT			equ 5				;  pluses...
SE_TODAM			equ 6
SE_TOAC				equ 7
SE_NAME2			equ 8
SE_IDENT			equ 9				;  ID_CURSED (home items keep theirs)
SE_PVAL_HI			equ 10				;  (a light's fuel is a word)
STORE_OWNER			equ P_EXP_TABLE+200
STORE_COUNT			equ STORE_OWNER+NUM_STORES
STORE_DOOR			equ STORE_COUNT+NUM_STORES	; (y, x) for each store
; then: data moved out of the resident bank
uniques_dead		equ STORE_DOOR+NUM_STORES*2	; one bit per race (dead uniques)
msg_buf				equ uniques_dead+(NUM_RACES+7)/8	; 81: the message being built
; what the player knows of spells (MISC2.C calc_spells/gain_spells), and mana
SPELL_STATE			equ msg_buf+81
s_learned			equ SPELL_STATE		; dword: spells 0-30 learnt
s_learned2			equ s_learned+4		; dword: spells 32-62
s_worked			equ s_learned2+4	; cast at least once (experience)
s_worked2			equ s_worked+4
s_forgotten			equ s_worked2+4		; forgotten (level or stat too low)
s_forgotten2		equ s_forgotten+4
s_order				equ s_forgotten2+4	; 64: spells in the order learnt, 99 = none
s_new				equ s_order+64		; how many more may be learnt now
p_mana				equ s_new+1			; word: maximum mana
p_cmana				equ p_mana+2		; word: current mana
p_cmana_frac		equ p_cmana+2		; word: x 2^-16
SPELL_STATE_SIZE	equ p_cmana_frac+2-SPELL_STATE
sp_entry			equ p_cmana_frac+2	; 16: an effect for the device overlay
sp_name				equ sp_entry+16		; 32: its name
p_spell				equ sp_name+32		; the class's spells: 0, 1 mage, 2 priest
p_first_spell		equ p_spell+1		; the level it may first learn them
; the level's traps (MISC2.C place_trap): y, x, type 1-18 (0: none), TRF_ bits
TRAP_LIST			equ p_first_spell+1
TRAP_MAX			equ 32
TRAP_SIZE			equ 4
TR_Y				equ 0
TR_X				equ 1
TR_TYPE				equ 2
TR_FLAGS			equ 3
TRF_SEEN			equ 0				; found (the C's TV_VIS_TRAP)
TRF_MADE			equ 1				; made by magic: no experience for disarming
HIGH_RAM_END		equ TRAP_LIST+TRAP_MAX*TRAP_SIZE
	ASSERT HIGH_RAM_END <= IM2_TABLE
MIN_MALLOC_TD		equ 4				; townsfolk by day
MIN_MALLOC_TN		equ 8				; and by night

; ---- food (CONSTANT.H, MAIN.C) ----
FOOD_START			equ 7500
FOOD_DIGESTED		equ 2
FOOD_MAX			equ 15000
FOOD_FULL			equ 10000
FOOD_ALERT			equ 2000
FOOD_WEAK			equ 1000
FOOD_FAINT			equ 300
HUNGER_FED			equ 0
HUNGER_HUNGRY		equ 1
HUNGER_WEAK			equ 2
REGEN_NORMAL		equ 197				; PLAYER_REGEN_NORMAL (x 2^-16)
REGEN_WEAK			equ 98
REGEN_FAINT			equ 33
KILLER_STARVATION	equ $FE00			; killer_race (a word) for starving

; ---- the player (CREATE.C, PLAYER.C) ----
A_STR				equ 0				; stats, in p_stat order
A_INT				equ 1
A_WIS				equ 2
A_DEX				equ 3
A_CON				equ 4
A_CHR				equ 5
; player race record (data/player.asm prace_table)
PR_NAME				equ 0				; word
PR_ADJ				equ 2				; 6 stat adjustments
PR_AGE				equ 8
PR_AGE_MOD			equ 9
PR_M_HT				equ 10				; male height base, spread, weight base, spread
PR_F_HT				equ 14				; female the same
PR_DIS				equ 18
PR_SRH				equ 19
PR_STL				equ 20
PR_FOS				equ 21
PR_BTH				equ 22
PR_BTHB				equ 23
PR_BSAV				equ 24
PR_HITDIE			equ 25
PR_INFRA			equ 26
PR_EXP				equ 27
PR_CLASSES			equ 28				; bit per class allowed
; class record (class_table)
PC_NAME				equ 0
PC_HD				equ 2
PC_DIS				equ 3
PC_SRH				equ 4
PC_STL				equ 5
PC_FOS				equ 6
PC_BTH				equ 7
PC_BTHB				equ 8
PC_SAV				equ 9
PC_ADJ				equ 10				; 6 stat adjustments
PC_SPELL			equ 16
PC_EXP				equ 17
PC_FIRST_SPELL		equ 18
PC_LADJ				equ 19				; class_level_adj: bth, bthb, device, disarm, save

; ---- status (DUNGEON.C timed effects, MORIA1.C calc_bonuses) ----
; p_status bits (the C's PY_ flags), low byte
PY_BLIND			equ 0
PY_CONFUSED			equ 1
PY_FEAR				equ 2
PY_POISONED			equ 3
PY_FAST				equ 4
PY_SLOW				equ 5
PY_HERO				equ 6
PY_SHERO			equ 7
; p_status+1 bits
PY2_BLESSED			equ 0
PY2_DET_INV			equ 1
PY2_TIM_INFRA		equ 2
PY2_SHIELD			equ 3
PY2_INVULN			equ 4
; p_update bits: recalculations overlays leave to the main loop
PU_BONUS			equ 0				; stat bonuses, calc_bonuses
PU_HP				equ 1				; calc_hitpoints
PU_SPELLS			equ 2				; calc_spells, calc_mana (after the bonuses)
; the C's item flags (TREASURE.C), as bits of each byte of p_eflags
EF0_SEARCH			equ 6				; byte 0 (bits 0-5: the stats)
EF0_SLOW_DIGEST		equ 7
EF1_STEALTH			equ 0				; byte 1
EF1_AGGRAVATE		equ 1
EF1_TELEPORT		equ 2
EF1_REGEN			equ 3
EF1_SPEED			equ 4
EF1_SLAY_DRAGON		equ 5
EF1_SLAY_ANIMAL		equ 6
EF1_SLAY_EVIL		equ 7
EF2_SLAY_UNDEAD		equ 0				; byte 2
EF2_FROST_BRAND		equ 1
EF2_FLAME_TONGUE	equ 2
EF2_RES_FIRE		equ 3
EF2_RES_ACID		equ 4
EF2_RES_COLD		equ 5
EF2_SUST_STAT		equ 6
EF2_FREE_ACT		equ 7
EF3_SEE_INVIS		equ 0				; byte 3
EF3_RES_LIGHT		equ 1				; (lightning)
EF3_FFALL			equ 2
EF3_SLAY_X_DRAGON	equ 3
EF3_POISON			equ 4
EF3_INFRA			equ 6
EF3_CURSED			equ 7
; flags2, as bits of each byte of p_eflags2
F2_SLAY_DEMON		equ 0				; byte 0
F2_SLAY_TROLL		equ 1
F2_SLAY_GIANT		equ 2
F2_HOLD_LIFE		equ 3
F2_SLAY_ORC			equ 4
F2_TELEPATHY		equ 5
F2_LIGHT			equ 2				; byte 1
F2_ACTIVATE			equ 3
F2_LIGHTNING		equ 4				; (a lightning brand)
; races with intrinsics (calc_bonuses)
RACE_HOBBIT			equ 3				; sustain DEX
RACE_GNOME			equ 4				; free action
RACE_DWARF			equ 5				; resist blindness
RACE_HALF_TROLL		equ 7				; sustain STR
RACE_DUNADAN		equ 8				; sustain CON
RACE_HIGH_ELF		equ 9				; see invisible
; killer_race values for things that aren't monsters (high byte $FE)
KILLER_DETONATION	equ $FE01
KILLER_DEATH		equ $FE02
KILLER_RUINATION	equ $FE03
KILLER_POISON		equ $FE04
KILLER_WOUND		equ $FE05
KILLER_STRAIN		equ $FE06			; casting (mass) genocide
KILLER_AURA			equ $FE07			; the One Ring
KILLER_EARTHQUAKE	equ $FE08			; elemental force bringing the cave down
KILLER_TRAPS		equ $FE09			; and on: what each trap kills with (traps.asm)
; object_ident flags (DESC.C) and the kinds that have flavours
OD_TRIED_BIT		equ 0
OD_KNOWN_BIT		equ 1
TV_SCROLL1			equ 70
TV_SCROLL2			equ 71
TV_POTION1			equ 75
TV_POTION2			equ 76
TV_STAFF			equ 55
TV_WAND				equ 65
TV_ROD				equ 66
TV_AMULET			equ 40
TV_RING				equ 45
TV_MISC				equ 1				; (what the destroy sets name)
TV_CHEST			equ 2
TV_BOLT				equ 11
TV_ARROW			equ 12
TV_BOW				equ 20
TV_HAFTED			equ 21
TV_POLEARM			equ 22
TV_SWORD			equ 23
TV_BOOTS			equ 30
TV_GLOVES			equ 31
TV_CLOAK			equ 32
TV_HELM				equ 33
TV_SHIELD			equ 34
TV_HARD_ARMOR		equ 35
TV_SOFT_ARMOR		equ 36
TV_FLASK			equ 77
TV_FOOD				equ 80
; flag masks within it_flags / p_eflags (TR1_, byte 2 or 3) and
; it_flags+4 / p_eflags2 (TR2_, the byte noted)
TR1_RES_FIRE		equ $08				; byte 2
TR1_RES_ACID		equ $10				; byte 2
TR1_RES_COLD		equ $20				; byte 2
TR1_RES_LIGHT		equ $02				; byte 3
TR2_IM_FIRE			equ $40				; byte 0
TR2_IM_COLD			equ $80				; byte 0
TR2_IM_ACID			equ $01				; byte 1
TR2_IM_LIGHT		equ $02				; byte 1
TR2_IM_POISON		equ $40				; byte 1
TR2_RES_CONF		equ $80				; byte 1
TR2_RES_SOUND		equ $01				; byte 2
TR2_RES_CHAOS		equ $08				; byte 2
TR2_RES_BLIND		equ $80				; byte 2
TR2_HOLD_LIFE		equ $08				; byte 0
TR2_RES_LT			equ $02				; byte 2 (light, not lightning)
TR2_RES_DARK		equ $04				; byte 2
TR2_RES_DISENCHANT	equ $10				; byte 2
TR2_RES_SHARDS		equ $20				; byte 2
TR2_RES_NEXUS		equ $40				; byte 2
TR2_RES_NETHER		equ $01				; byte 3
OFS_AMULET			equ 0
OFS_RING			equ 1
OFS_STAFF			equ 2				; object_offset() for staffs
OFS_WAND			equ 3
OFS_SCROLL			equ 4
OFS_POTION			equ 5
OFS_ROD				equ 7
MAX_FLAVOURS		equ 57				; MAX_COLORS
; pending actions for the magic overlay (pending_magic)
PM_QUAFF			equ 1
PM_READ				equ 2
PM_AIM				equ 3
PM_USE				equ 4
PM_ZAP				equ 5
PM_ACTIVATE			equ 6

; ---- commands ----
CMD_MOVE			equ 0
CMD_DOWN			equ 1
CMD_UP				equ 2
CMD_STAY			equ 3
CMD_INVEN			equ 4
CMD_EQUIP			equ 5
CMD_WIELD			equ 6
CMD_TAKEOFF			equ 7
CMD_QUAFF			equ 8
CMD_EAT				equ 9
CMD_DROP			equ 10
CMD_PICKUP			equ 11
CMD_CHARACTER		equ 12
CMD_READ			equ 13
CMD_AIM				equ 14				; z: aim a wand
CMD_USE				equ 15				; Z: use a staff
CMD_ZAP				equ 16				; a: activate a rod
CMD_ACTIVATE		equ 17				; A: activate an artifact
CMD_CAST			equ 18				; m: cast a spell
CMD_BROWSE			equ 19				; P: browse a book
CMD_STUDY			equ 20				; G: learn new spells
CMD_PRAY			equ 21				; p: recite a prayer
CMD_SAVE			equ 22				; Symbol Shift + X: save and quit (^X)
CMD_FUEL			equ 23				; F: refill a lamp
CMD_DISARM			equ 24				; D: disarm a trap
CMD_TUNNEL			equ 25				; T: tunnel (rubble, rock)
CMD_THROW			equ 26				; v: throw
; key modifiers in key_table
KM_ANY				equ 0
KM_SYMBOL			equ 1
KM_CAPS				equ 2
KM_NONE				equ 3

; ---- input ----
KEY_NONE			equ $FF
REPEAT_FIRST		equ 12				; frames before a held key repeats
REPEAT_NEXT			equ 4				; frames between repeats
