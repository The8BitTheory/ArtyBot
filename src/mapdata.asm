; mapdata.asm - Planning-field level data (part of the single PRG) and loader.
; One variable-length record per level, coordinates are field tiles
; (0..MAP_COLS-1 / 0..MAP_ROWS-1, origin top-left):
;   +0 robot x, +1 robot y, +2 robot direction (ROBOT_DIR_*),
;   +3 number of goal fields G (1..MAX_GOALS), followed by G pairs (x, y),
;   then the number of packages P, followed by P pairs (x, y),
;   then the number of blockers N (trees: block the space, cannot be jumped
;   over or thrown across), followed by N pairs (x, y),
;   then the number of water fields W (block the ground: cannot be walked on
;   or dropped onto, but can be jumped over and thrown across), followed by
;   W pairs (x, y),
;   then the number of ice fields I (frozen water: the robot skates over it until
;   land is reached or the next field is blocked; jumping off it, landing on it or
;   throwing a package on it breaks it and the run fails), followed by I pairs.
; A level is won when every goal field holds a package, so give it at least as
; many packages as goal fields. More levels: add a record below and an entry in
; plan_level_table.
;
; load_plan_level builds the static field layer in map_work (MAP_COLS*MAP_ROWS
; bytes, row-major, tile ids T_FLOOR/T_WALL(blocker)/T_BOX(package)/T_GOAL
; (free goal field)/T_BOXG(package standing on a goal field)/T_WATER) and the goal list
; goal_list (goal_count pairs x, y).
; The robot is not stored in that layer; it lives in robot_tx/robot_ty/robot_dir.

goal_list       = $0280         ; goal_count pairs (x, y) behind map_work
MAX_GOALS       = 16

ROBOT_DIR_RIGHT = 0             ; matches gfx_robot order ($80..$83)
ROBOT_DIR_LEFT  = 1
ROBOT_DIR_UP    = 2
ROBOT_DIR_DOWN  = 3

MAPREC_ROBOT_X   = 0
MAPREC_ROBOT_Y   = 1
MAPREC_ROBOT_DIR = 2
MAPREC_GOALS     = 3            ; count byte; goals, packages, blockers follow

MAP_CELLS       = MAP_COLS * MAP_ROWS

plan_level_table
        !word plan_level_1
        !word plan_level_2
        !word plan_level_3
        !word plan_level_4
        !word plan_level_5
        !word plan_level_6
        !word plan_level_7
        !word plan_level_8
        !word plan_level_9
plan_level_count = (* - plan_level_table) / 2

plan_level_1
        !byte 0, 0, ROBOT_DIR_RIGHT     ; robot: top-left, facing right
        !byte 1                         ; goal fields (x, y)
        !byte 5, 5                      ; centre of the 10x10 field
        !byte 1                         ; packages (x, y)
        !byte 3, 5                      ; two tiles left of the goal
        !byte 6                         ; blockers (x, y), fixed part of the level
        !byte 2, 2
        !byte 7, 2
        !byte 8, 5
        !byte 2, 7
        !byte 6, 7
        !byte 9, 9
        !byte 0                         ; water fields
        !byte 0                         ; ice fields (frozen water)

plan_level_2
        !byte 0, 5, ROBOT_DIR_RIGHT     ; robot: left edge, facing right
        !byte 3                         ; goal fields (x, y): right column
        !byte 6, 3
        !byte 6, 5
        !byte 6, 7
        !byte 3                         ; packages (x, y): left column
        !byte 3, 3
        !byte 3, 5
        !byte 3, 7
        !byte 6                         ; blockers (x, y)
        !byte 1, 1
        !byte 8, 1
        !byte 4, 4
        !byte 4, 6
        !byte 1, 9
        !byte 8, 9
        !byte 0                         ; water fields
        !byte 0                         ; ice fields (frozen water)

; Level 3: a river (column 5) splits the field. Robot and packages start on the
; left bank, both goals are on the right bank. The upper goal (6,2) is fenced in
; by trees and only open towards the river: its package has to be thrown across.
;   .....~....
;   .R.T.~T...
;   .....~GT..
;   ..P..~T...
;   .....~..T.
;   T....~....
;   .....~....
;   ...P.~..G.
;   .T...~....
;   .....~...T
plan_level_3
        !byte 1, 1, ROBOT_DIR_DOWN      ; robot: left bank, facing down
        !byte 2                         ; goal fields (x, y): right bank
        !byte 6, 2                      ; only reachable from the water side
        !byte 8, 7
        !byte 2                         ; packages (x, y): left bank
        !byte 2, 3
        !byte 3, 7
        !byte 8                         ; blockers (x, y)
        !byte 6, 1                      ; trees fencing in the upper goal
        !byte 7, 2
        !byte 6, 3
        !byte 3, 1
        !byte 0, 5
        !byte 1, 8
        !byte 8, 4
        !byte 9, 9
        !byte 10                        ; water fields (x, y): the river
        !byte 5, 0
        !byte 5, 1
        !byte 5, 2
        !byte 5, 3
        !byte 5, 4
        !byte 5, 5
        !byte 5, 6
        !byte 5, 7
        !byte 5, 8
        !byte 5, 9
        !byte 0                         ; ice fields (frozen water)

; Level 4 (Sokoban-style warehouse): walls of the classic puzzle are trees, 7 goals,
; 7 packages (one already stands on its goal). Robot starts in the upper-left
; nook facing down. Redrawn from the original 8x9 map, shifted by (1,0).
; Map (T tree, p package, G goal, P package on a goal, R robot):
;      TTTTT  
;    TTT...T  
;    TGRp..T  
;    TTT.pGT  
;    TGTTp.T  
;    T.T.G.TT 
;    Tp.PppGT 
;    T...G..T 
;    TTTTTTTT 
;             
plan_level_4
        !byte 3, 2, ROBOT_DIR_DOWN      ; robot
        !byte 7                         ; goal fields (x, y)
        !byte 2, 2
        !byte 6, 3
        !byte 2, 4
        !byte 5, 5
        !byte 7, 6
        !byte 5, 7
        !byte 4, 6
        !byte 7                         ; packages (x, y)
        !byte 4, 2
        !byte 5, 3
        !byte 5, 4
        !byte 2, 6
        !byte 4, 6
        !byte 5, 6
        !byte 6, 6
        !byte 35                        ; blockers (x, y)
        !byte 1, 1
        !byte 1, 2
        !byte 1, 3
        !byte 1, 4
        !byte 1, 5
        !byte 1, 6
        !byte 1, 7
        !byte 1, 8
        !byte 2, 1
        !byte 2, 3
        !byte 2, 8
        !byte 3, 0
        !byte 3, 1
        !byte 3, 3
        !byte 3, 4
        !byte 3, 5
        !byte 3, 8
        !byte 4, 0
        !byte 4, 4
        !byte 4, 8
        !byte 5, 0
        !byte 5, 8
        !byte 6, 0
        !byte 6, 8
        !byte 7, 0
        !byte 7, 1
        !byte 7, 2
        !byte 7, 3
        !byte 7, 4
        !byte 7, 5
        !byte 7, 8
        !byte 8, 5
        !byte 8, 6
        !byte 8, 7
        !byte 8, 8
        !byte 0                         ; water fields
        !byte 0                         ; ice fields (frozen water)

; Level 5 (Winter 1, "Ice bridge"): a frozen lake (rows 4-5) cuts the field in two,
; only the ice bridge at x = 4, 5 leads across. Three packages down south, three
; goals up north: carry them over the bridge or throw them across the bridge ends.
plan_level_5
        !byte 4, 8, ROBOT_DIR_UP
        !byte 3                         ; goal fields (x, y)
        !byte 3, 1
        !byte 4, 1
        !byte 5, 1
        !byte 3                         ; packages (x, y)
        !byte 3, 7
        !byte 4, 6
        !byte 5, 7
        !byte 6                         ; blockers (x, y)
        !byte 1, 1
        !byte 8, 1
        !byte 2, 7
        !byte 7, 7
        !byte 0, 3
        !byte 9, 3
        !byte 16                         ; water fields
        !byte 0, 4
        !byte 1, 4
        !byte 2, 4
        !byte 3, 4
        !byte 6, 4
        !byte 7, 4
        !byte 8, 4
        !byte 9, 4
        !byte 0, 5
        !byte 1, 5
        !byte 2, 5
        !byte 3, 5
        !byte 6, 5
        !byte 7, 5
        !byte 8, 5
        !byte 9, 5
        !byte 0                         ; ice fields (frozen water)


; Level 6 (Winter 2, "Pine forest"): two walls of pines (x = 4 and x = 6), each with a
; single gap, form a zigzag corridor. Trees block jumping and throwing, so both
; packages have to be carried through both gaps.
plan_level_6
        !byte 2, 4, ROBOT_DIR_RIGHT
        !byte 2                         ; goal fields (x, y)
        !byte 8, 5
        !byte 7, 8
        !byte 2                         ; packages (x, y)
        !byte 2, 2
        !byte 1, 7
        !byte 21                        ; blockers (x, y)
        !byte 4, 0
        !byte 4, 1
        !byte 4, 2
        !byte 4, 3
        !byte 4, 5
        !byte 4, 6
        !byte 4, 7
        !byte 4, 8
        !byte 4, 9
        !byte 6, 0
        !byte 6, 1
        !byte 6, 2
        !byte 6, 3
        !byte 6, 4
        !byte 6, 5
        !byte 6, 7
        !byte 6, 8
        !byte 6, 9
        !byte 9, 0
        !byte 0, 0
        !byte 8, 9
        !byte 0                         ; water fields
        !byte 0                         ; ice fields (frozen water)

; Level 7 (Winter 3, "Frozen lake"): three ice floes with a goal each lie in a lake.
; Nothing can walk or drop there, the packages have to be thrown across the water.
plan_level_7
        !byte 0, 4, ROBOT_DIR_RIGHT
        !byte 3                         ; goal fields (x, y)
        !byte 4, 4
        !byte 5, 5
        !byte 4, 5
        !byte 3                         ; packages (x, y)
        !byte 1, 2
        !byte 1, 6
        !byte 8, 3
        !byte 5                         ; blockers (x, y)
        !byte 2, 0
        !byte 7, 0
        !byte 8, 8
        !byte 0, 8
        !byte 9, 6
        !byte 13                         ; water fields
        !byte 3, 3
        !byte 4, 3
        !byte 5, 3
        !byte 6, 3
        !byte 3, 4
        !byte 5, 4
        !byte 6, 4
        !byte 3, 5
        !byte 6, 5
        !byte 3, 6
        !byte 4, 6
        !byte 5, 6
        !byte 6, 6
        !byte 0                         ; ice fields (frozen water)

; Level 8 (Winter 4, "Skating rink"): a big ice rink between two snow banks. On ice
; the robot skates on until it reaches land or the next field is blocked. The goal
; in the middle of the rink can only be served from the ice: the pine at (5,4) stops
; the robot right above it. Jumping or throwing onto the ice breaks it.
;
;    ..........
;    ..######..
;    P.######.G
;    ..######..
;    .>###T##..
;    ..##G###..
;    ..######..
;    P.######..
;    ..######..
;    ..........
;    (. snow  # ice  ~ water  T pine  P package  G goal  > robot)
plan_level_8
        !byte 1, 4, ROBOT_DIR_RIGHT
        !byte 2                       ; goal fields (x, y)
        !byte 9, 2, 4, 5
        !byte 2                       ; packages (x, y)
        !byte 0, 2, 0, 7
        !byte 1                       ; blockers (x, y)
        !byte 5, 4
        !byte 0                       ; water fields
        !byte 46                      ; ice fields (frozen water)
        !byte 2, 1, 3, 1, 4, 1, 5, 1, 6, 1, 7, 1, 2, 2, 3, 2
        !byte 4, 2, 5, 2, 6, 2, 7, 2, 2, 3, 3, 3, 4, 3, 5, 3
        !byte 6, 3, 7, 3, 2, 4, 3, 4, 4, 4, 6, 4, 7, 4, 2, 5
        !byte 3, 5, 5, 5, 6, 5, 7, 5, 2, 6, 3, 6, 4, 6, 5, 6
        !byte 6, 6, 7, 6, 2, 7, 3, 7, 4, 7, 5, 7, 6, 7, 7, 7
        !byte 2, 8, 3, 8, 4, 8, 5, 8, 6, 8, 7, 8

; Level 9 (Winter 5, "Ice maze"): an ice field with pines and a hole of open water
; as stoppers. Both goals are small snow islands in the ice: skate so that the
; robot stops next to them (or throw from the ice, two fields ahead).
;
;    P.........
;    .#####T##.
;    .##T#####.
;    .#####~##.
;    .#G######.
;    .######T#.
;    .#T###G##.
;    .########.
;    .####T###.
;    >........P
;    (. snow  # ice  ~ water  T pine  P package  G goal  > robot)
plan_level_9
        !byte 0, 9, ROBOT_DIR_RIGHT
        !byte 2                       ; goal fields (x, y)
        !byte 2, 4, 6, 6
        !byte 2                       ; packages (x, y)
        !byte 0, 0, 9, 9
        !byte 5                       ; blockers (x, y)
        !byte 2, 6, 3, 2, 5, 8, 6, 1, 7, 5
        !byte 1                       ; water fields
        !byte 6, 3
        !byte 56                      ; ice fields (frozen water)
        !byte 1, 1, 2, 1, 3, 1, 4, 1, 5, 1, 7, 1, 8, 1, 1, 2
        !byte 2, 2, 4, 2, 5, 2, 6, 2, 7, 2, 8, 2, 1, 3, 2, 3
        !byte 3, 3, 4, 3, 5, 3, 7, 3, 8, 3, 1, 4, 3, 4, 4, 4
        !byte 5, 4, 6, 4, 7, 4, 8, 4, 1, 5, 2, 5, 3, 5, 4, 5
        !byte 5, 5, 6, 5, 8, 5, 1, 6, 3, 6, 4, 6, 5, 6, 7, 6
        !byte 8, 6, 1, 7, 2, 7, 3, 7, 4, 7, 5, 7, 6, 7, 7, 7
        !byte 8, 7, 1, 8, 2, 8, 3, 8, 4, 8, 6, 8, 7, 8, 8, 8

; A = level number. Copies its record into the game variables and builds the
; field layer including the blockers. Invalid numbers fall back to level 0.
!zone load_plan_level
load_plan_level
        cmp #plan_level_count
        bcc .valid
        lda #0
.valid  sta level_no
        asl
        tax
        lda plan_level_table,x
        sta ptr0
        lda plan_level_table+1,x
        sta ptr0+1
        ldy #MAPREC_ROBOT_X
        lda (ptr0),y
        sta robot_tx
        ldy #MAPREC_ROBOT_Y
        lda (ptr0),y
        sta robot_ty
        ldy #MAPREC_ROBOT_DIR
        lda (ptr0),y
        sta robot_dir

        ; Empty field.
        ldx #0
        lda #T_FLOOR
.clear  sta map_work,x
        inx
        cpx #MAP_CELLS
        bne .clear

        ; Goal fields: remember them in goal_list and mark the field layer.
        ldy #MAPREC_GOALS
        lda (ptr0),y
        sta goal_count
        sta cnt
        iny
        lda #0
        sta tmp3                ; offset into goal_list
.goal   lda cnt
        beq .goals_done
        lda (ptr0),y
        sta tmp0
        iny
        lda (ptr0),y
        sta tmp1
        iny
        ldx tmp3
        lda tmp0
        sta goal_list,x
        lda tmp1
        sta goal_list+1,x
        inx
        inx
        stx tmp3
        jsr map_index           ; keeps Y
        lda #T_GOAL
        sta map_work,x
        dec cnt
        jmp .goal
.goals_done

        ; Packages (a package that starts on a goal field counts as delivered).
        lda (ptr0),y
        iny
        sta cnt
.pkg    lda cnt
        beq .pkgs_done
        lda (ptr0),y
        sta tmp0
        iny
        lda (ptr0),y
        sta tmp1
        iny
        jsr map_index
        lda map_work,x
        cmp #T_GOAL
        beq .on_goal
        lda #T_BOX
        bne .put
.on_goal
        lda #T_BOXG
.put    sta map_work,x
        dec cnt
        jmp .pkg
.pkgs_done

        ; Blockers from the level record.
        lda (ptr0),y
        iny
        sta cnt
.blk    lda cnt
        beq .water
        lda (ptr0),y
        sta tmp0
        iny
        lda (ptr0),y
        sta tmp1
        iny
        jsr map_index           ; keeps Y
        lda #T_WALL
        sta map_work,x
        dec cnt
        jmp .blk

        ; Water fields from the level record.
.water  lda (ptr0),y
        iny
        sta cnt
.wat    lda cnt
        beq .done
        lda (ptr0),y
        sta tmp0
        iny
        lda (ptr0),y
        sta tmp1
        iny
        jsr map_index           ; keeps Y
        lda #T_WATER
        sta map_work,x
        dec cnt
        jmp .wat

        ; Ice fields (frozen water) from the level record.
.done   lda (ptr0),y
        iny
        sta cnt
.ice    lda cnt
        beq .end
        lda (ptr0),y
        sta tmp0
        iny
        lda (ptr0),y
        sta tmp1
        iny
        jsr map_index           ; keeps Y
        lda #T_ICE
        sta map_work,x
        dec cnt
        jmp .ice
.end    rts

; tmp0 = x, tmp1 = y -> X = row-major index into map_work.
!zone map_index
map_index
        lda tmp1
        asl
        asl
        asl
        clc
        adc tmp1
        adc tmp1                ; y * 10
        clc
        adc tmp0
        tax
        rts

; Draw the field layer and the robot from the loaded level. All field characters are
; multicolour (colour RAM +8) on the shared greens $D022/$D023 of the run screen.
!zone draw_map_objects
draw_map_objects
        lda #0
        sta ui_row
.row    lda #0
        sta ui_col
.col    lda ui_row
        sta tmp0
        asl
        asl
        asl
        clc
        adc tmp0
        adc tmp0                ; row * 10
        clc
        adc ui_col
        tax
        lda map_work,x
        tax
        lda map_tile_colors,x
        sta cur_col
        lda map_tile_chars,x
        pha
        lda ui_col
        clc
        adc #MAP_SCR_X
        tax
        lda ui_row
        clc
        adc #MAP_SCR_Y
        tay
        jsr set_cursor
        pla
        jsr put_char
        inc ui_col
        lda ui_col
        cmp #MAP_COLS
        bne .col
        inc ui_row
        lda ui_row
        cmp #MAP_ROWS
        bne .row
        lda robot_tx
        clc
        adc #MAP_SCR_X
        tax
        lda robot_ty
        clc
        adc #MAP_SCR_Y
        tay
        jsr set_cursor
        lda theme_plan_robot
        sta cur_col
        lda robot_dir
        clc
        adc #ROBOT_CHAR_BASE
        jmp put_char

map_tile_chars                  ; indexed by tile id
        !byte FLOOR_CHAR, BLOCK_CHAR, PKG_CHAR, GOAL_CHAR, PKG_CHAR, WATER_CHAR, ICE_CHAR, WATER_CHAR
; map_tile_colors (colour RAM per tile id) comes from the theme, see world.asm.
map_info_colors                 ; help-text colour per tile id
        !byte COL_WHITE, COL_GREEN, COL_YELLOW, COL_CYAN, COL_YELLOW, COL_CYAN, COL_CYAN, COL_CYAN

; Hover code for the field tile under the mouse, or $FF.
;   $50+dir robot, $61 blocker, $62 package, $63 goal, $64 delivered, $65 water
!zone map_hover_code
map_hover_code
        lda mouse_x_hi
        bne .none
        lda mouse_x_lo
        lsr
        lsr
        lsr
        sec
        sbc #MAP_SCR_X
        bcc .none
        cmp #MAP_COLS
        bcs .none
        sta tmp0
        lda mouse_y
        lsr
        lsr
        lsr
        sec
        sbc #MAP_SCR_Y
        bcc .none
        cmp #MAP_ROWS
        bcs .none
        sta tmp1
        lda tmp0
        cmp robot_tx
        bne .tile
        lda tmp1
        cmp robot_ty
        bne .tile
        lda robot_dir
        clc
        adc #$50
        rts
.tile   jsr map_index
        lda map_work,x
        beq .none               ; plain floor: no help text
        clc
        adc #$60
        rts
.none   lda #$FF
        rts

; Hover code in A ($50..$63) -> help text in the info row.
!zone draw_map_info
draw_map_info
        cmp #$60
        bcs .object
        sec
        sbc #$50                ; robot direction
        pha
        ldx #INFO_X
        ldy #INFO_Y
        jsr set_cursor
        lda #<str_facing
        ldx #>str_facing
        jsr put_str
        pla
        asl
        tax
        lda dir_name_ptrs,x
        pha
        lda dir_name_ptrs+1,x
        tax
        pla
        jmp put_str
.object sec
        sbc #$60
        tay
        lda map_info_colors,y
        sta cur_col
        tya
        asl
        tax
        lda map_text_ptrs,x
        pha
        lda map_text_ptrs+1,x
        tax
        ldy #INFO_Y
        stx tmp0
        ldx #INFO_X
        jsr set_cursor
        pla
        ldx tmp0
        jmp put_str

dir_name_ptrs
        !word str_dir_right, str_dir_left, str_dir_up, str_dir_down
map_text_ptrs                   ; indexed by tile id (floor unused)
        !word 0, str_blocker, str_package, str_target, str_package_done, str_water, str_ice, str_water
