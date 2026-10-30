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
SPRITE_BLOCK2 = SPRITE_BLOCK + 2   ; black outline of the mouse pointer (sprite 2 in plan mode / world map)
CODE_LIMIT  = $C000
ICON_CHAR_BASE  = $E0
ICON_CHAR_COUNT = 30            ; 24 command glyphs, Turn 180, and scrollbar arrows
ICON_CHAR_BYTES = ICON_CHAR_COUNT * 8
ROBOT_CHAR_BASE  = $80
ROBOT_CHAR_COUNT = 13           ; 4 robot dirs + floor, goal, package, blocker, water, ice, key, lock, door (all multicolour)
FLOOR_CHAR       = ROBOT_CHAR_BASE + 4
GOAL_CHAR        = ROBOT_CHAR_BASE + 5
PKG_CHAR         = ROBOT_CHAR_BASE + 6
BLOCK_CHAR       = ROBOT_CHAR_BASE + 7
WATER_CHAR       = ROBOT_CHAR_BASE + 8
ICE_CHAR         = ROBOT_CHAR_BASE + 9
KEY_CHAR         = ROBOT_CHAR_BASE + 10
LOCK_CHAR        = ROBOT_CHAR_BASE + 11
DOOR_CHAR        = ROBOT_CHAR_BASE + 12
PLAN_TILE_COUNT  = 9            ; per theme: floor, goal, package, blocker, water, ice, key, lock, door (from FLOOR_CHAR)
ROBOT_CHAR_BYTES = ROBOT_CHAR_COUNT * 8
; Second command-icon block (the $E0 block is full): Jump $90-$93, Throw $94-$97.
ICON2_CHAR_BASE  = $90
ICON2_CHAR_COUNT = 8
ICON2_CHAR_BYTES = ICON2_CHAR_COUNT * 8
!if ROBOT_CHAR_BASE + ROBOT_CHAR_COUNT > ICON2_CHAR_BASE {
    !error "Planungs-Kacheln ueberlappen die Icon2-Zeichen"
}

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
T_WATER     = 5             ; water: blocks walking/dropping, can be jumped over/thrown across
T_ICE       = 6             ; frozen water: the robot skates over it; jumping off it, landing
                            ; or throwing a package on it breaks it (run fails)
T_BROKEN    = 7             ; broken ice (map_work only, shown after such a failure)
T_KEY       = 8             ; key: picked up / dropped / thrown like a package, not a delivery
T_LOCK      = 9             ; lock: drop (or throw) the key onto it -> T_LOCKED, its door opens
T_LOCKED    = 10            ; lock holding its key (map_work only)
T_DOOR      = 11            ; closed door: blocks like a tree; opened it becomes T_FLOOR
MAX_LOCKS   = 4             ; lock/door pairs per level
SPRITE_BYTES= 192           ; mouse pointer (fill), insertion marker, mouse pointer outline
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

; --- Run screen (RPG look): multicolour 2x2-character field cells $A0-$DF (16 cell
; types, the theme's tileset), NES-style window frame $98-$9F, pointing hand $8D,
; solid block $8E (scrollbar thumb); sprites.
; Cell order (= display tile): grass, tree, chest, goal, flowers, water, path, gate l/r,
; arch (world map), ice, broken ice, key, lock, full lock, door. Every theme draws its own
; key / lock / door in the same positions (e.g. keycard, card reader, sliding door).
RUN_CHAR_BASE  = $A0
RUN_CELL_TYPES = 16
RUN_CELL_ICE   = 10             ; display cell of T_ICE; T_ICE..T_DOOR map to RUN_CELL_ICE.. in order
RUN_CHAR_COUNT = RUN_CELL_TYPES*4
RUN_CHAR_BYTES = RUN_CHAR_COUNT * 8
UI_FRAME_BASE  = $98
UI_TL          = UI_FRAME_BASE+0 ; window frame: rounded corners and edges
UI_TOP         = UI_FRAME_BASE+1
UI_TR          = UI_FRAME_BASE+2
UI_LEFT        = UI_FRAME_BASE+3
UI_RIGHT       = UI_FRAME_BASE+4
UI_BL          = UI_FRAME_BASE+5
UI_BOTTOM      = UI_FRAME_BASE+6
UI_BR          = UI_FRAME_BASE+7
UI_HAND        = ROBOT_CHAR_BASE + ROBOT_CHAR_COUNT ; $8D: Final-Fantasy style pointing hand
SOLID_CHAR     = UI_HAND + 1    ; $8E: solid block (scrollbar thumb)
!if T_DOOR - T_ICE + RUN_CELL_ICE != RUN_CELL_TYPES - 1 {
    !error "Tile-IDs T_ICE..T_DOOR passen nicht zu den Run-Zellen"
}
!if SOLID_CHAR >= ICON2_CHAR_BASE {
    !error "Hand/Block-Zeichen ueberlappen die Icon2-Zeichen"
}
!if RUN_CHAR_BASE + RUN_CHAR_COUNT > ICON_CHAR_BASE {
    !error "Run-Zeichen ueberlappen die Icon-Zeichen"
}
!if ICON2_CHAR_BASE + ICON2_CHAR_COUNT > UI_FRAME_BASE {
    !error "Icon2-/Rahmen-Zeichen ueberlappen"
}
!if UI_FRAME_BASE + 8 > RUN_CHAR_BASE {
    !error "Rahmen-/Run-Zeichen ueberlappen"
}
RUN_SPR_COUNT  = 18             ; robot 4 dirs x (normal, carrying) x 2 walk frames, chest, key
RUN_SPR_BYTES  = RUN_SPR_COUNT * 64
RUN_SPR_BLOCK  = SPRITE_BLOCK + 3   ; stored behind the pointer/marker/outline sprites
RUN_SPR_CHEST  = RUN_SPR_BLOCK + 16
RUN_SPR_KEY    = RUN_SPR_BLOCK + 17

; Run screen colours. Multicolour: $D021 black, $D022/$D023 the two grass greens.
COL_LGREEN     = 13
COL_LBLUE      = 14
COL_LGREY      = 15
RUN_BG1        = COL_GREEN
RUN_BG2        = COL_LGREEN
ROBOT_COLOR    = COL_LGREY      ; sprite colour (%10), $D025 black, $D026 white
CHEST_COLOR    = COL_RED        ; brownish red, also the chest cell colour
KEY_COLOR      = COL_YELLOW     ; carried key sprite
