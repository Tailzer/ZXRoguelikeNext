/* constants.asm - memory map, Next registers, game constants */

; ---- memory ----
CODE_START			equ $8000
stack_top			equ $C000
STACK_SIZE			equ 256
TILEMAP_BASE		equ $6000			; must be in bank 5
TILEDEF_BASE		equ $7400
MAP_BASE			equ $C000
MAP_PAGE			equ 32				; 8K pages 32/33 (16K bank 16)
IM2_TABLE			equ $BC00			; 257 bytes of $BD
IM2_JUMP			equ $BDBD			; jp im2_handler

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
NUM_COLOURS			equ 9

ATTR_WHITE			equ COL_WHITE*2
ATTR_GREY			equ COL_GREY*2
ATTR_DARK			equ COL_DARK*2
ATTR_YELLOW			equ COL_YELLOW*2
ATTR_RED			equ COL_RED*2
ATTR_GREEN			equ COL_GREEN*2
ATTR_BLUE			equ COL_BLUE*2
ATTR_UMBER			equ COL_UMBER*2
ATTR_MAGENTA		equ COL_MAGENTA*2

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
MON_EMPTY			equ $FF				; M_RACE of a free slot
; monster record
M_RACE				equ 0
M_Y					equ 1
M_X					equ 2
M_HP				equ 3				; word
M_MAXHP				equ 5				; word
M_SLEEP				equ 7				; word (csleep)
M_SPEED				equ 9				; signed (cspeed = speed - 10)
M_CDIS				equ 10				; distance from player
M_ML				equ 11				; 1 if the player can see it
; race record (race_table in races.asm)
RACE_SIZE			equ 32
R_NAME				equ 0				; word, pointer to name
R_CHAR				equ 2
R_ATTR				equ 3
R_MOVE				equ 4				; RM_ flags
R_EXP				equ 5
R_SLEEP				equ 6
R_AAF				equ 7				; how far away it notices you
R_AC				equ 8
R_SPEED				equ 9				; 11 = normal
R_HD_DICE			equ 10
R_HD_SIDES			equ 11
R_LEVEL				equ 12
R_RARITY			equ 13
R_ATTACKS			equ 16				; 4 x (type, description, dice, sides)
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
NOTICE_LIMIT		equ 645				; noticed if 1d1024^3 <= 2^(29-stealth 1)

; ---- commands ----
CMD_MOVE			equ 0
CMD_DOWN			equ 1
CMD_UP				equ 2
CMD_STAY			equ 3

; ---- input ----
KEY_NONE			equ $FF
REPEAT_FIRST		equ 12				; frames before a held key repeats
REPEAT_NEXT			equ 4				; frames between repeats
