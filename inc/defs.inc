; defs.inc - Hardware-Register und Konstanten

; --- CPU
CPU_DDR     = $00
CPU_PORT    = $01

; --- VIC-II
VIC_SPR0X   = $D000
VIC_SPR0Y   = $D001
VIC_SPR1X   = $D002
VIC_SPR1Y   = $D003
VIC_SPRXMSB = $D010
VIC_CTRL1   = $D011
VIC_RASTER  = $D012
VIC_SPR_EN  = $D015
VIC_CTRL2   = $D016
VIC_SPR_EXPY= $D017
VIC_MEMPTR  = $D018
VIC_IRR     = $D019
VIC_IMR     = $D01A
VIC_SPR_PRI = $D01B
VIC_SPR_MC  = $D01C
VIC_SPR_EXPX= $D01D
VIC_BORDER  = $D020
VIC_BG0     = $D021
VIC_BG1     = $D022
VIC_BG2     = $D023
VIC_SPR_MC0 = $D025         ; shared sprite multicolour 1 (%01)
VIC_SPR_MC1 = $D026         ; shared sprite multicolour 2 (%11)
VIC_SPR0COL = $D027

; --- SID / CIA
SID_BASE    = $D400
SID_POTX    = $D419
SID_POTY    = $D41A
SID_VOL     = $D418
CIA1_PRA    = $DC00
CIA1_PRB    = $DC01
CIA1_DDRA   = $DC02
CIA1_DDRB   = $DC03
CIA1_ICR    = $DC0D
CIA2_PRA    = $DD00
CIA2_DDRA   = $DD02
CIA2_ICR    = $DD0D

COLORRAM    = $D800

; --- Speicherlayout (VIC-Bank 3 = $C000-$FFFF)
BANK_BASE   = $C000
SCREEN      = $C000
CHARSET     = $C800
SPRITES     = $E000
SPR_PTR0    = SCREEN + $3F8
SPRITE_BLOCK= (SPRITES - BANK_BASE) >> 6
SPRITE_BLOCK1 = SPRITE_BLOCK + 1
CODE_LIMIT  = $C000
ICON_CHAR_BASE  = $E0
ICON_CHAR_COUNT = 30            ; 24 command glyphs, Turn 180, and scrollbar arrows
ICON_CHAR_BYTES = ICON_CHAR_COUNT * 8
ROBOT_CHAR_BASE  = $80
ROBOT_CHAR_COUNT = 8            ; 4 robot dirs + floor, goal, package, blocker (all multicolour)
FLOOR_CHAR       = ROBOT_CHAR_BASE + 4
GOAL_CHAR        = ROBOT_CHAR_BASE + 5
PKG_CHAR         = ROBOT_CHAR_BASE + 6
BLOCK_CHAR       = ROBOT_CHAR_BASE + 7
ROBOT_CHAR_BYTES = ROBOT_CHAR_COUNT * 8

; --- Farben
COL_BLACK   = 0
COL_WHITE   = 1
COL_RED     = 2
COL_PURPLE  = 4
COL_CYAN    = 3
COL_GREEN   = 5
COL_YELLOW  = 7
COL_ORANGE  = 8
COL_DGREY   = 11

; --- Spielfeld
MAP_COLS    = 10            ; planning field interior (tiles)
MAP_ROWS    = 10
MAP_SCR_X   = 1             ; screen column of field tile (0,0)
MAP_SCR_Y   = 2             ; screen row of field tile (0,0)

; --- Info window (right half, under the command list): two text rows
INFO_X      = 23            ; first text column
INFO_Y      = 21            ; first text row (second row = INFO_Y+1)
INFO_W      = 16            ; characters per row
KEY_F1      = 4             ; F1 matrix code: switch between plan and run mode
KEY_F7      = 3             ; F7 matrix code; Shift+F7 = F8: exit (both modes)

; --- Tile-IDs
T_FLOOR     = 0
T_WALL      = 1
T_BOX       = 2
T_GOAL      = 3             ; goal field without a package
T_BOXG      = 4             ; package standing on a goal field (map_work only)
SPRITE_BYTES= 128           ; mouse pointer plus insertion marker
PROGRAM_MAX = 99

; --- Eingabe
KEY_CLR_HOME = 51          ; CLR/HOME matrix position; Shift clears the list
JOY_UP      = $01
JOY_DOWN    = $02
JOY_LEFT    = $04
JOY_RIGHT   = $08
JOY_FIRE    = $10
REPEAT_DELAY= 15
REPEAT_RATE = 4

; --- Timing
RASTER_LINE = 250
COL_BLUE    = 6

; --- Run screen (RPG look): multicolour 2x2-character field cells, NES-style
; window frame characters and the pointing hand, all from $C0 on; sprites.
RUN_CHAR_BASE  = $C0
RUN_CELL_TYPES = 5              ; grass, tree, chest, goal, grass with flowers
RUN_UI_BASE    = RUN_CHAR_BASE + RUN_CELL_TYPES*4
UI_TL          = RUN_UI_BASE+0  ; window frame: rounded corners and edges
UI_TOP         = RUN_UI_BASE+1
UI_TR          = RUN_UI_BASE+2
UI_LEFT        = RUN_UI_BASE+3
UI_RIGHT       = RUN_UI_BASE+4
UI_BL          = RUN_UI_BASE+5
UI_BOTTOM      = RUN_UI_BASE+6
UI_BR          = RUN_UI_BASE+7
UI_HAND        = RUN_UI_BASE+8  ; Final-Fantasy style pointing hand
RUN_CHAR_COUNT = RUN_CELL_TYPES*4 + 9
RUN_CHAR_BYTES = RUN_CHAR_COUNT * 8
!if RUN_CHAR_BASE + RUN_CHAR_COUNT > ICON_CHAR_BASE {
    !error "Run-Zeichen ueberlappen die Icon-Zeichen"
}
RUN_SPR_COUNT  = 17             ; robot 4 dirs x (normal, carrying) x 2 walk frames, chest
RUN_SPR_BYTES  = RUN_SPR_COUNT * 64
RUN_SPR_BLOCK  = SPRITE_BLOCK + 2   ; stored behind the pointer/marker sprites
RUN_SPR_CHEST  = RUN_SPR_BLOCK + 16

; Run screen colours. Multicolour: $D021 black, $D022/$D023 the two grass greens.
COL_LGREEN     = 13
COL_LGREY      = 15
RUN_BG1        = COL_GREEN
RUN_BG2        = COL_LGREEN
ROBOT_COLOR    = COL_LGREY      ; sprite colour (%10), $D025 black, $D026 white
CHEST_COLOR    = COL_RED        ; brownish red, also the chest cell colour
