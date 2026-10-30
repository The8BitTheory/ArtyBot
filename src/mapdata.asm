; mapdata.asm - Planning-field level data (part of the single PRG) and loader.
; One variable-length record per level, coordinates are field tiles
; (0..MAP_COLS-1 / 0..MAP_ROWS-1, origin top-left):
;   +0 robot x, +1 robot y, +2 robot direction (ROBOT_DIR_*),
;   +3 number of goal fields G (1..MAX_GOALS), followed by G pairs (x, y),
;   then the number of packages P, followed by P pairs (x, y),
;   then the number of blockers N, followed by N pairs (x, y).
; A level is won when every goal field holds a package, so give it at least as
; many packages as goal fields. More levels: add a record below and an entry in
; plan_level_table.
;
; load_plan_level builds the static field layer in map_work (MAP_COLS*MAP_ROWS
; bytes, row-major, tile ids T_FLOOR/T_WALL(blocker)/T_BOX(package)/T_GOAL
; (free goal field)/T_BOXG(package standing on a goal field)) and the goal list
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
        beq .done
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
.done   rts

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

; Draw the field layer and the robot from the loaded level.
!zone draw_map_objects
draw_map_objects
        lda #COL_WHITE
        sta cur_col
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
        lda robot_dir
        clc
        adc #ROBOT_CHAR_BASE
        jmp put_char

map_tile_chars                  ; indexed by tile id
        !byte FLOOR_CHAR, BLOCK_CHAR, PKG_CHAR, GOAL_CHAR, PKG_CHAR

; Hover code for the field tile under the mouse, or $FF.
;   $50+dir robot, $61 blocker, $62 package, $63 goal
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
        ldx #1
        ldy #22
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
        asl
        tax
        lda map_text_ptrs,x
        pha
        lda map_text_ptrs+1,x
        tax
        ldy #22
        stx tmp0
        ldx #1
        jsr set_cursor
        pla
        ldx tmp0
        jmp put_str

dir_name_ptrs
        !word str_dir_right, str_dir_left, str_dir_up, str_dir_down
map_text_ptrs                   ; indexed by tile id (floor unused)
        !word 0, str_blocker, str_package, str_target, str_package_done
