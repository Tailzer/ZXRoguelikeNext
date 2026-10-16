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
NR_LINE_LSB			equ $1F

; ---- screen layout (80x32 text) ----
SCREEN_W			equ 80
SCREEN_H			equ 32
MSG_ROW				equ 0
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
NUM_COLOURS			equ 8

ATTR_WHITE			equ COL_WHITE*2
ATTR_GREY			equ COL_GREY*2
ATTR_DARK			equ COL_DARK*2
ATTR_YELLOW			equ COL_YELLOW*2
ATTR_RED			equ COL_RED*2
ATTR_GREEN			equ COL_GREEN*2
ATTR_BLUE			equ COL_BLUE*2
ATTR_UMBER			equ COL_UMBER*2

; ---- dungeon (same size as Angband: CONSTANT.H MAX_HEIGHT/MAX_WIDTH) ----
MAP_W				equ 198
MAP_H				equ 66

; terrain ids - index into terrain_table (map.asm)
T_GRANITE			equ 0
T_FLOOR				equ 1
T_PERMWALL			equ 2
T_DOOR_CLOSED		equ 3
T_DOOR_OPEN			equ 4
T_STAIR_DOWN		equ 5
T_STAIR_UP			equ 6

; terrain flags
TF_PASSABLE			equ 0				; bit number

PLAYER_START_X		equ 35
PLAYER_START_Y		equ 23

; ---- input ----
KEY_NONE			equ $FF
REPEAT_FIRST		equ 12				; frames before a held key repeats
REPEAT_NEXT			equ 4				; frames between repeats
