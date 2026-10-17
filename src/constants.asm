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
PAGE_STORE			equ 50				; overlay: the town's stores
DATA_WINDOW			equ $2000			; MMU slot 1: race and kind data pages
RACE_PAGE			equ 44				; 5 pages of races (data/races.asm)
KIND_PAGE			equ 49				; 1 page of item kinds (data/kinds.asm)
IM2_TABLE			equ $BC00			; 257 bytes of $BD
IM2_JUMP			equ $BDBD			; jp im2_handler

; ---- banking ----
; FARCALL page, routine - page an overlay into the window and call it
	MACRO FARCALL ov_page, ov_routine
		nextreg NR_MMU2, ov_page
		call ov_routine
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
PACK				equ $B600			; PACK_MAX carried items
PACK_MAX			equ 12				; slots a-l
EQUIP				equ PACK+PACK_MAX*ITEM_SIZE	; EQ_SLOTS worn/wielded items
EQ_SLOTS			equ 7
EQ_WEAPON			equ 0
EQ_BODY				equ 1
EQ_SHIELD			equ 2
EQ_HELM				equ 3
EQ_CLOAK			equ 4
EQ_GLOVES			equ 5
EQ_BOOTS			equ 6
ITEM_SIZE			equ 8
ITEM_EMPTY			equ $FF				; I_KIND of a free slot
KIND_GOLD			equ $FE				; I_KIND of a pile of treasure
; item record
I_KIND				equ 0
I_NUMBER			equ 1
I_Y					equ 2
I_X					equ 3
I_MARKED			equ 4				; seen on the floor (the C's fm)
I_VALUE				equ 5				; word, gold only
I_SUB				equ 7				; gold type
; kind record (data/kinds.asm, made by tools/convert.py from TREASURE.C)
KIND_SIZE			equ 64				; 128 per 8K page
K_CHAR				equ 0
K_ATTR				equ 1
K_CLASS				equ 2
K_EFFECT			equ 3				; potions: dice of 7 healed
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
K_NAME				equ 20				; the name itself, '~' where plurals add 's'
; item classes; wearable ones map to equipment slot class - IC_WEAPON
IC_FOOD				equ 1
IC_POTION			equ 2
IC_WEAPON			equ 3
IC_BODY				equ 4
IC_SHIELD			equ 5
IC_HELM				equ 6
IC_CLOAK			equ 7
IC_GLOVES			equ 8
IC_BOOTS			equ 9
TREAS_ROOM_ALLOC	equ 9				; mean objects in rooms
TREAS_ANY_ALLOC		equ 3				; mean objects anywhere
TREAS_GOLD_ALLOC	equ 3				; mean piles of treasure
OBJ_GREAT			equ 11
MAX_GOLD			equ 18

; ---- the town (GENERATE.C town_gen, STORE1.C, STORE2.C) ----
TOWN_H				equ 22				; SCREEN_HEIGHT
TOWN_W				equ 66				; SCREEN_WIDTH
NUM_STORES			equ 8				; 6 shops, the black market, home
STORE_BLACK			equ 6
STORE_HOME			equ 7
STORE_INVEN_MAX		equ 24
STORE_ITEM			equ 4				; stock entry: kind, number, discount, spare
STORE_INV			equ $B7E0			; NUM_STORES x STORE_INVEN_MAX entries
STORE_OWNER			equ STORE_INV+NUM_STORES*STORE_INVEN_MAX*STORE_ITEM
STORE_COUNT			equ STORE_OWNER+NUM_STORES
STORE_DOOR			equ STORE_COUNT+NUM_STORES	; (y, x) for each store
	ASSERT STORE_DOOR+NUM_STORES*2 <= $BB00
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
P_HP_TABLE			equ $B6A0			; player_hp[50], words
P_EXP_TABLE			equ P_HP_TABLE+100	; experience needed, 50 dwords
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
; key modifiers in key_table
KM_ANY				equ 0
KM_SYMBOL			equ 1
KM_CAPS				equ 2
KM_NONE				equ 3

; ---- input ----
KEY_NONE			equ $FF
REPEAT_FIRST		equ 12				; frames before a held key repeats
REPEAT_NEXT			equ 4				; frames between repeats
