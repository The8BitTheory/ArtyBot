; world.asm - Themes (tilesets), worlds, progress and the world map screen.
;
; Flow: game start -> world map -> (Space on a level node) plan -> run.
; Plan F7 or Space after a won level -> back to the world map.
;
; A THEME is one tileset: the run-screen cells (grass, tree, chest, goal,
; flowers, water, path; 4 characters each), the five planning tiles (floor, goal,
; package, blocker, water) and the colours. theme_load copies it over the
; same character codes, so only one theme lives in the charset at a time.
;
; A WORLD has one theme, a range of levels in plan_level_table (all levels of
; a world are open once the world is), an overview map (tools/gen_world_maps.py
; -> world_maps.asm) and one map node per level. World n+1 opens when every
; level of world n is solved: the gate at the exit of the world map (cells '['
; and ']' in the map) opens with a blinking effect when the player comes back
; to the map after the last level, and stepping through it opens the next
; world (F3/F5 switch between the opened worlds). Every world after the first has
; an archway (map cell '<') that is always open and leads back to the previous
; world. Progress is kept in RAM only.

; Zero-page variables: see zp.inc (world map block).

WM_X          = 1               ; screen column of map cell (0,0)
WM_Y          = 1               ; screen row of map cell (0,0)
WM_MSG_ROW    = 23
WM_PATH       = 6               ; map cell type of the path (walkable)
WM_GATE_L     = 7               ; gate halves: blocked while closed, walkable when open
WM_GATE_R     = 8
WM_BACK       = 9               ; archway back to the previous world (always walkable)              ; status text row (message box as on the run screen)
MAX_WORLDS    = 8
MAX_LEVELS    = 64              ; size of the level_done bit mask
KEY_W         = 9               ; keyboard matrix codes
KEY_A         = 10
KEY_S         = 13
KEY_D         = 18
KEY_CRSR_UD   = 7
KEY_CRSR_LR   = 2
KEY_F3        = 5
KEY_F5        = 6

; ---- Themes --------------------------------------------------------------
; Record: +0 run cells (RUN_CELL_TYPES*32 bytes), +2 planning tiles (PLAN_TILE_COUNT*8
; bytes: floor/goal/package/blocker/water/ice), +4 $D022, +5 $D023, +6 colour RAM of the
; RUN_CELL_TYPES run cells, then colour RAM per tile id (T_FLOOR..T_BROKEN),
; then the colour of the robot arrows in the planning map.
; Colour RAM values +8 = multicolour.
THEME_MEADOW  = 0
THEME_WINTER  = 1
TREC_CELLS    = 0
TREC_PLAN     = 2
TREC_COLORS   = 4

theme_table
        !word theme_meadow
        !word theme_winter
theme_count = (* - theme_table) / 2

theme_meadow
        !word gfx_run, gfx_robot + 4*8
        !byte COL_GREEN, COL_LGREEN
        !byte COL_GREEN+8, COL_RED+8, CHEST_COLOR+8, COL_CYAN+8, COL_YELLOW+8, COL_BLUE+8, COL_YELLOW+8
        !byte COL_RED+8, COL_RED+8, COL_WHITE+8, COL_CYAN+8, COL_BLUE+8
        !byte COL_GREEN+8, COL_RED+8, CHEST_COLOR+8, COL_CYAN+8, COL_YELLOW+8, COL_BLUE+8
        !byte COL_CYAN+8, COL_BLUE+8
        !byte COL_WHITE+8

; Winter: white snow with light-blue shadows, pines, ice-cold water, brown path.
; Keep the colour RAM values in sync with preview() in tools/gen_theme_winter.py.
theme_winter
        !word winter_cells, winter_plan
        !byte COL_WHITE, COL_LBLUE
        !byte COL_BLUE+8, COL_GREEN+8, CHEST_COLOR+8, COL_CYAN+8, COL_CYAN+8, COL_BLUE+8, COL_RED+8
        !byte COL_RED+8, COL_RED+8, COL_CYAN+8, COL_CYAN+8, COL_BLUE+8
        !byte COL_BLUE+8, COL_GREEN+8, CHEST_COLOR+8, COL_CYAN+8, COL_YELLOW+8, COL_BLUE+8
        !byte COL_CYAN+8, COL_BLUE+8
        !byte COL_PURPLE+8              ; robot arrows: white would vanish in the snow

; Colours of the loaded theme (theme_load copies them here; preset = meadow).
theme_colors
theme_bg1       !byte COL_GREEN         ; $D022
theme_bg2       !byte COL_LGREEN        ; $D023
run_cell_colors                         ; grass, tree trunk, chest, goal, flowers, water, path, gate l/r, arch,
        !byte COL_GREEN+8, COL_RED+8, CHEST_COLOR+8, COL_CYAN+8, COL_YELLOW+8, COL_BLUE+8, COL_YELLOW+8
        !byte COL_RED+8, COL_RED+8, COL_WHITE+8, COL_CYAN+8, COL_BLUE+8   ; ice, broken ice
!if * - run_cell_colors != RUN_CELL_TYPES {
    !error "run_cell_colors: ein Eintrag pro Zelltyp"
}
map_tile_colors                         ; planning tiles by tile id (T_FLOOR..T_BROKEN)
        !byte COL_GREEN+8, COL_RED+8, CHEST_COLOR+8, COL_CYAN+8, COL_YELLOW+8, COL_BLUE+8
        !byte COL_CYAN+8, COL_BLUE+8
!if * - map_tile_colors != T_BROKEN + 1 {
    !error "map_tile_colors: ein Eintrag pro Tile-ID"
}
theme_plan_robot !byte COL_WHITE+8      ; colour of the robot arrows in the planning map
THEME_COLOR_BYTES = * - theme_colors

; A = theme. Copies cells, planning tiles and colours; sets $D022/$D023.
!zone theme_load
theme_load
        asl
        tax
        lda theme_table,x
        sta ptr2
        lda theme_table+1,x
        sta ptr2+1
        ldy #TREC_CELLS
        lda (ptr2),y
        sta ptr0
        iny
        lda (ptr2),y
        sta ptr0+1
        +set16 ptr1, CHARSET + RUN_CHAR_BASE*8
        +set16 cnt, RUN_CELL_TYPES*32
        jsr memcpy
        ldy #TREC_PLAN
        lda (ptr2),y
        sta ptr0
        iny
        lda (ptr2),y
        sta ptr0+1
        +set16 ptr1, CHARSET + FLOOR_CHAR*8
        +set16 cnt, PLAN_TILE_COUNT*8
        jsr memcpy
        ldx #0
        ldy #TREC_COLORS
.col    lda (ptr2),y
        sta theme_colors,x
        iny
        inx
        cpx #THEME_COLOR_BYTES
        bne .col
        lda theme_bg1
        sta VIC_BG1
        lda theme_bg2
        sta VIC_BG2
        rts

; ---- Worlds --------------------------------------------------------------
; Record: +0 theme, +1 first level, +2 number of levels (1..9), +3 map,
; +5 name (0-terminated), +7 node list (x, y per level).
WREC_THEME    = 0
WREC_FIRST    = 1
WREC_COUNT    = 2
WREC_MAP      = 3
WREC_NAME     = 5
WREC_NODES    = 7

world_table
        !word world_meadow
        !word world_winter
world_count = (* - world_table) / 2
!if world_count > MAX_WORLDS {
    !error "Zu viele Welten (MAX_WORLDS)"
}

world_meadow
        !byte THEME_MEADOW, 0, 4
        !word wmap_meadow, str_world_meadow, wnodes_meadow
!if WNODES_MEADOW != 4 {
    !error "Weltkarte meadow: Anzahl Knoten passt nicht zur Anzahl Levels"
}
!if plan_level_count > MAX_LEVELS {
    !error "Zu viele Levels fuer level_done"
}

str_world_meadow !text "Meadow",0

world_winter
        !byte THEME_WINTER, 4, 5        ; levels 5-9 (8 and 9: ice)
        !word wmap_winter, str_world_winter, wnodes_winter
!if WNODES_WINTER != 5 {
    !error "Weltkarte winter: Anzahl Knoten passt nicht zur Anzahl Levels"
}
str_world_winter !text "Winter",0

; ---- Progress (RAM) ---------------------------------------------------------
level_done      !fill MAX_LEVELS/8, 0   ; one bit per level of plan_level_table
level_runs      !fill MAX_LEVELS, 0     ; runs per level (counted until it is solved, max 255)
level_cmds      !fill MAX_LEVELS, 0     ; fewest commands of a solution (0 = not solved)
stat_s1         !byte 0                 ; checksum of the plan of the last run
stat_s2         !byte 0
stat_nz         !byte 0                 ; stats_put_num: leading digit seen
stat_lvl        !byte 0                 ; stats_put_level_name / stats rows
stat_w          !byte 0
world_pos_x     !fill MAX_WORLDS, 0     ; last robot cell per world
world_pos_y     !fill MAX_WORLDS, 0
last_level      !byte $FF               ; level whose plan is in the command list
worlds_open     !byte 1                 ; worlds 0..worlds_open-1 can be visited (F3/F5)
gate_done       !byte 0                 ; bit per world: its gate has opened (blink played)
wm_gate_open    !byte 0                 ; 1: gate of the current world is open (cells walkable)

; Game start: robot on node 1 of every world, nothing solved, world 1.
!zone world_init
world_init
        lda #$FF
        sta last_level
        lda #1
        sta worlds_open
        lda #0
        sta gate_done
        ldx #MAX_LEVELS/8-1
        lda #0
.clr    sta level_done,x
        dex
        bpl .clr
        ldx #MAX_LEVELS-1
        lda #0
.clr2   sta level_runs,x
        sta level_cmds,x
        dex
        bpl .clr2
        sta stat_s1
        sta stat_s2
        lda #0
        sta wm_tmp
.w      lda wm_tmp
        cmp #world_count
        beq .done
        jsr world_select
        ldy #0
        lda (wm_nodes),y
        ldx wm_tmp
        sta world_pos_x,x
        iny
        lda (wm_nodes),y
        sta world_pos_y,x
        inc wm_tmp
        jmp .w
.done   lda #0
        sta world_cur
        lda #ROBOT_DIR_DOWN
        sta robot_dir
        rts

; A = world: world_cur, world_rec, world_first, world_nlev, wm_map, wm_nodes.
!zone world_select
world_select
        sta world_cur
        asl
        tax
        lda world_table,x
        sta world_rec
        lda world_table+1,x
        sta world_rec+1
        ldy #WREC_FIRST
        lda (world_rec),y
        sta world_first
        iny
        lda (world_rec),y
        sta world_nlev
        iny
        lda (world_rec),y
        sta wm_map
        iny
        lda (world_rec),y
        sta wm_map+1
        ldy #WREC_NODES
        lda (world_rec),y
        sta wm_nodes
        iny
        lda (world_rec),y
        sta wm_nodes+1
        rts

; A = level -> A = 0 when not solved (Z flag set accordingly).
!zone level_is_done
level_is_done
        pha
        lsr
        lsr
        lsr
        tax
        pla
        and #7
        tay
        lda level_done,x
        and run_bit_tab,y
        rts

; Mark level_no as solved.
!zone progress_mark
progress_mark
        lda level_no
        lsr
        lsr
        lsr
        tax
        lda level_no
        and #7
        tay
        lda level_done,x
        ora run_bit_tab,y
        sta level_done,x
        rts

; A = world -> carry set when every level of it is solved.
!zone world_complete
world_complete
        asl
        tax
        lda world_table,x
        sta ptr2
        lda world_table+1,x
        sta ptr2+1
        ldy #WREC_FIRST
        lda (ptr2),y
        sta wm_tmp
        iny
        lda (ptr2),y
        sta wm_tmp2
.l      lda wm_tmp
        jsr level_is_done
        beq .no
        inc wm_tmp
        dec wm_tmp2
        bne .l
        sec
        rts
.no     clc
        rts

; Prints "<world name> <n>" for level A (level_no for put_level_name) at the
; cursor. The level must belong to the current world.
!zone put_level_name
put_level_name
        lda level_no
put_level_name_a
        sec
        sbc world_first
        clc
        adc #'1'
        pha
        ldy #WREC_NAME
        lda (world_rec),y
        pha
        iny
        lda (world_rec),y
        tax
        pla
        jsr put_str
        lda #' '
        jsr put_char
        pla
        jmp put_char

; ---- World map screen -----------------------------------------------------
; Never returns: plan mode is called from here and comes back here.
!zone world_mode
world_mode
        lda world_cur
        jsr world_enter
.loop   jsr wait_frame
        jsr input_update
        jsr world_tick
        jsr world_sprites
        lda mouse_click
        beq .keys
        lda wm_confirm
        ora wm_steps
        bne .keys
        jsr world_mouse_node    ; carry set: A = node under the pointer
        bcc .keys
        jmp .play
.keys   lda key_new
        cmp #$FF
        beq .loop
        ldx key_repeat
        bne .loop
        ldx wm_confirm
        bne .confirm
        cmp #KEY_F7             ; F8 (= Shift+F7): quit
        bne .not_quit
        ldx key_shift
        beq .loop
        lda #1
        sta wm_confirm
        lda #<str_run_quit
        ldx #>str_run_quit
        jsr run_draw_message
        jmp .loop
.not_quit
        ldx wm_steps            ; the rest only while the robot stands still
        bne .loop
        cmp #KEY_F1             ; F1: level statistics, F2 (= Shift+F1): test key, solves the world
        bne .not_f2
        ldx key_shift
        beq .stats
        jmp world_cheat
.stats  jmp world_stats
.not_f2
        cmp #KEY_SPACE
        beq .enter
        cmp #KEY_RETURN
        beq .enter
        cmp #KEY_F5
        beq .next_world
        cmp #KEY_F3
        beq .prev_world
        jmp .loop
.enter  lda wm_node
        bmi .loop               ; not on a node
.play   jsr world_play          ; A = node; returns after plan/run
        jmp world_mode
.stay   jmp .loop
.next_world
        lda world_cur           ; only worlds opened through a gate
        clc
        adc #1
        cmp #world_count
        bcs .stay
        cmp worlds_open
        bcs .stay
        jmp .switch
.prev_world
        lda world_cur
        beq .stay
        sec
        sbc #1
.switch pha
        jsr world_save_pos
        pla
        jsr world_enter
        jmp .loop
.confirm
        cmp #KEY_RETURN
        bne .no
        jmp system_reset
.no     cmp #KEY_LEFTARROW
        bne .back
        lda #0
        sta wm_confirm
        jsr world_status
.back   jmp .loop

; Test key F2: marks every level of the current world as solved. The map is
; entered again, so the gate blinks open as after a really solved last level.
!zone world_cheat
world_cheat
        jsr world_save_pos
        lda #0
        sta wm_tmp
.l      lda wm_tmp
        cmp world_nlev
        beq .done
        clc
        adc world_first         ; level number
        pha
        lsr
        lsr
        lsr
        tax
        pla
        and #7
        tay
        lda level_done,x
        ora run_bit_tab,y
        sta level_done,x
        inc wm_tmp
        jmp .l
.done   jmp world_mode

; ---- Statistics: runs and commands per level --------------------------------
; A run is counted when the program is started and the plan (level + command
; list) differs from the plan of the previous run; restarting, retrying after
; an error, pausing and continuing do not count. Counting stops once the level
; is solved. level_cmds keeps the shortest solution (commands executed until
; the last package was delivered).

; Called whenever playback starts or continues (run_go).
!zone stats_run_start
stats_run_start
        lda level_no            ; Fletcher-like checksum over the list
        sta stat_nz
        lda editor_count
        clc
        adc #1
        sta tmp1
        ldx #0
.l      cpx editor_count
        beq .done
        lda stat_nz
        clc
        adc program,x
        adc #1
        sta stat_nz
        clc
        adc tmp1
        sta tmp1
        inx
        bne .l
.done   lda stat_nz
        cmp stat_s1
        bne .new
        lda tmp1
        cmp stat_s2
        beq .same
.new    lda stat_nz
        sta stat_s1
        lda tmp1
        sta stat_s2
        lda level_no
        jsr level_is_done
        bne .same               ; solved already: runs are frozen
        ldx level_no
        inc level_runs,x
        bne .same
        dec level_runs,x        ; saturate at 255
.same   rts

; The level was just solved: run_pc = number of commands executed.
!zone stats_level_won
stats_level_won
        ldx level_no
        lda level_cmds,x
        beq .store              ; first solution
        cmp run_pc
        bcc .done               ; the stored one is shorter
        beq .done
.store  lda run_pc
        sta level_cmds,x
.done   rts

; A = number 0..255: three characters, right aligned.
!zone stats_put_num
stats_put_num
        sta tmp1
        lda #0
        sta stat_nz
        ldx #0
.h      lda tmp1
        cmp #100
        bcc .hd
        sbc #100
        sta tmp1
        inx
        bne .h
.hd     jsr .digit
        ldx #0
.t      lda tmp1
        cmp #10
        bcc .td
        sbc #10
        sta tmp1
        inx
        bne .t
.td     jsr .digit
        lda tmp1
        clc
        adc #'0'
        jmp put_char
.digit  txa                     ; X = digit value; blank while it is a leading zero
        ora stat_nz
        bne .show
        lda #' '
        jmp put_char
.show   lda #1
        sta stat_nz
        txa
        clc
        adc #'0'
        jmp put_char

; A = level (global index): prints "<world name> <n>" at the cursor.
!zone stats_put_level_name
stats_put_level_name
        sta stat_lvl
        lda #0
        sta stat_w
.w      lda stat_w
        asl
        tax
        lda world_table,x
        sta ptr1
        lda world_table+1,x
        sta ptr1+1
        ldy #WREC_FIRST
        lda stat_lvl
        sec
        sbc (ptr1),y
        bcc .next               ; level is before this world
        iny
        cmp (ptr1),y
        bcs .next               ; level is after this world
        clc
        adc #'1'
        pha
        ldy #WREC_NAME
        lda (ptr1),y
        pha
        iny
        lda (ptr1),y
        tax
        pla
        jsr put_str
        lda #' '
        jsr put_char
        pla
        jmp put_char
.next   inc stat_w
        lda stat_w
        cmp #world_count
        bcc .w
        rts

STATS_X       = 3               ; overlay window position and size
STATS_Y       = 2
STATS_W       = 34
STATS_H       = plan_level_count + 5
!if STATS_H > 22 {
    !error "Level-Statistik: zu viele Levels fuer eine Seite"
}

; F1 on the world map: table with the bookkeeping of every level over the map.
; Any of F1 / Space / Return / left arrow closes it; the map is entered again.
!zone world_stats
world_stats
        jsr world_save_pos
        lda #0
        sta VIC_SPR_EN
        jsr sound_stop
        ; blank interior
        lda #COL_WHITE
        sta cur_col
        lda #STATS_Y+1
        sta stat_lvl
.fill   ldx #STATS_X+1
        ldy stat_lvl
        jsr set_cursor
        lda #STATS_W-2
        sta stat_w
.fc     lda #' '
        jsr put_char
        dec stat_w
        bne .fc
        inc stat_lvl
        lda stat_lvl
        cmp #STATS_Y+STATS_H-1
        bne .fill
        lda #COL_WHITE
        sta cur_col
        lda #STATS_W
        sta win_w
        ldx #STATS_X
        ldy #STATS_Y
        lda #STATS_H
        jsr draw_window
        ; rule under the header
        ldx #STATS_X+1
        ldy #STATS_Y+2
        jsr set_cursor
        lda #STATS_W-2
        sta stat_w
.rule   lda #UI_TOP
        jsr put_char
        dec stat_w
        bne .rule
        ; labels
        lda #<str_stats_title
        sta ptr1
        lda #>str_stats_title
        sta ptr1+1
        ldx #STATS_X+2
        ldy #STATS_Y
        jsr run_label
        lda #<str_stats_close
        sta ptr1
        lda #>str_stats_close
        sta ptr1+1
        ldx #STATS_X+2
        ldy #STATS_Y+STATS_H-1
        jsr run_label
        ; header
        lda #COL_YELLOW
        sta cur_col
        ldx #5
        ldy #STATS_Y+1
        jsr set_cursor
        lda #<str_stats_level
        ldx #>str_stats_level
        jsr put_str
        ldx #16
        ldy #STATS_Y+1
        jsr set_cursor
        lda #<str_stats_solved
        ldx #>str_stats_solved
        jsr put_str
        ldx #24
        ldy #STATS_Y+1
        jsr set_cursor
        lda #<str_stats_runs
        ldx #>str_stats_runs
        jsr put_str
        ldx #30
        ldy #STATS_Y+1
        jsr set_cursor
        lda #<str_stats_cmds
        ldx #>str_stats_cmds
        jsr put_str
        ; one row per level
        lda #0
        sta wm_tmp
.row    lda #COL_WHITE
        sta cur_col
        ldx #5
        lda wm_tmp
        clc
        adc #STATS_Y+3
        tay
        jsr set_cursor
        lda wm_tmp
        jsr stats_put_level_name
        ldx #16                 ; solved?
        lda wm_tmp
        clc
        adc #STATS_Y+3
        tay
        jsr set_cursor
        lda wm_tmp
        jsr level_is_done
        beq .no
        lda #COL_GREEN
        sta cur_col
        lda #<str_stats_yes
        ldx #>str_stats_yes
        bne .say
.no     lda #COL_RED
        sta cur_col
        lda #<str_stats_no
        ldx #>str_stats_no
.say    jsr put_str
        lda #COL_WHITE
        sta cur_col
        ldx #25                 ; runs
        lda wm_tmp
        clc
        adc #STATS_Y+3
        tay
        jsr set_cursor
        ldx wm_tmp
        lda level_runs,x
        jsr stats_put_num
        ldx #31                 ; commands (only for solved levels)
        lda wm_tmp
        clc
        adc #STATS_Y+3
        tay
        jsr set_cursor
        ldx wm_tmp
        lda level_cmds,x
        beq .dash
        jsr stats_put_num
        jmp .next
.dash   lda #' '
        jsr put_char
        lda #' '
        jsr put_char
        lda #'-'
        jsr put_char
.next   inc wm_tmp
        lda wm_tmp
        cmp #plan_level_count
        beq .rows_done
        jmp .row
.rows_done
        ; wait for the closing key
.wait   jsr wait_frame
        jsr input_update
        lda key_new
        cmp #$FF
        beq .wait
        ldx key_repeat
        bne .wait
        cmp #KEY_F1
        beq .close
        cmp #KEY_SPACE
        beq .close
        cmp #KEY_RETURN
        beq .close
        cmp #KEY_LEFTARROW
        bne .wait
.close  jmp world_mode          ; redraws the whole map (position was saved)

; A = node index: start that level in plan mode, back when the player leaves.
!zone world_play
world_play
        sta wm_tmp              ; robot onto the node (mouse click from afar)
        asl
        tay
        lda (wm_nodes),y
        sta wm_cx
        iny
        lda (wm_nodes),y
        sta wm_cy
        jsr world_save_pos
        lda #0
        sta VIC_SPR_EN
        jsr sound_stop
        lda wm_tmp
        clc
        adc world_first
        sta level_no
        cmp last_level
        beq .same               ; same level again: keep its plan
        sta last_level
        jsr editor_init
.same   jmp plan_mode

!zone world_save_pos
world_save_pos
        ldx world_cur
        lda wm_cx
        sta world_pos_x,x
        lda wm_cy
        sta world_pos_y,x
        rts

; A = world: load it, its theme and draw the map screen.
!zone world_enter
world_enter
        jsr world_select
        ldy #WREC_THEME
        lda (world_rec),y
        jsr theme_load
        ldx world_cur
        lda world_pos_x,x
        sta wm_cx
        lda world_pos_y,x
        sta wm_cy
        lda #0
        sta wm_steps
        sta wm_confirm
        sta run_walk
        sta run_carry
        ldy world_cur           ; gate already open? (exactly 0 or 1)
        lda gate_done
        and run_bit_tab,y
        beq .shut
        lda #1
.shut   sta wm_gate_open
        jsr wm_set_pixels
        jsr world_draw
        jsr world_init_sprites
        jsr world_status
        lda wm_gate_open
        bne .done
        lda world_cur           ; all levels solved but the gate not yet opened:
        jsr world_complete      ; we just came back from the last level
        bcc .done
        jsr world_gate_blink
        jmp world_status
.done   rts

; The gate opens: the closed gate stays visible for a moment, then flashes
; between gate and path and stays open. The robot can keep being drawn.
!zone world_gate_blink
world_gate_blink
        lda #30
        jsr .wait
        lda #7                  ; 7 changes: closed, open, closed ... open
        sta wm_tmp
.t      lda wm_gate_open
        eor #1
        sta wm_gate_open
        beq .closed
        jsr sound_place
.closed jsr world_redraw_gates
        lda #5
        jsr .wait
        dec wm_tmp
        bne .t
        ldy world_cur           ; remember: opened for good
        lda gate_done
        ora run_bit_tab,y
        sta gate_done
        rts
.wait   sta wm_tmp2
.w      jsr wait_frame
        jsr input_update
        jsr world_sprites
        dec wm_tmp2
        bne .w
        rts

; Draw the gate cells of the map again (gate or path, see wm_gate_open).
!zone world_redraw_gates
world_redraw_gates
        lda #0
        sta wm_dy
.row    lda #0
        sta wm_dx
.col    ldx wm_dx
        ldy wm_dy
        jsr wm_cell
        cmp #WM_GATE_L
        bcc .skip
        jsr wm_draw_type
.skip   inc wm_dx
        lda wm_dx
        cmp #WMAP_COLS
        bne .col
        inc wm_dy
        lda wm_dy
        cmp #WMAP_ROWS
        bne .row
        rts

; A = map cell type: draw it at map cell (wm_dx, wm_dy); an open gate shows the path.
!zone wm_draw_type
wm_draw_type
        cmp #WM_BACK            ; the archway is always shown
        bcs .draw
        cmp #WM_GATE_L
        bcc .draw
        ldx wm_gate_open
        beq .draw
        lda #WM_PATH
.draw   tax
        lda run_cell_colors,x
        sta cur_col
        txa
        jmp wm_put_map_cell

; The robot arrived on an exit cell: the open gate leads into the next world, the
; archway back to the previous one. The robot is left in front of the exit.
!zone world_check_gate
world_check_gate
        ldx wm_cx
        ldy wm_cy
        jsr wm_cell
        cmp #WM_BACK
        beq .back
        cmp #WM_GATE_L
        bcc .no
        lda world_cur
        clc
        adc #1                  ; the next world
        cmp #world_count
        bcs .end
        pha
        clc
        adc #1
        cmp worlds_open         ; worlds_open = max(worlds_open, next + 1)
        bcc .go
        sta worlds_open
        bcs .go
.back   lda world_cur
        beq .no                 ; (the generator forbids an archway in world 1)
        sec
        sbc #1                  ; the previous world
        pha
.go     lda wm_prevx            ; leave the robot in front of the exit
        sta wm_cx
        lda wm_prevy
        sta wm_cy
        jsr world_save_pos
        pla
        jmp world_enter
.end    lda #<str_world_end
        ldx #>str_world_end
        jmp run_draw_message
.no     rts

; Robot pixel position from its cell.
!zone wm_set_pixels
wm_set_pixels
        lda wm_cx
        sta wm_px
        lda #0
        sta wm_px+1
        ldx #4
.x16    asl wm_px
        rol wm_px+1
        dex
        bne .x16
        lda wm_px
        clc
        adc #WM_X*8
        sta wm_px
        bcc .y
        inc wm_px+1
.y      lda wm_cy
        asl
        asl
        asl
        asl
        clc
        adc #WM_Y*8
        sta wm_py
        rts

!zone world_draw
world_draw
        lda #0
        sta VIC_SPR_EN
        jsr clear_screen
        lda #COL_WHITE
        sta cur_col
        lda #40                 ; map window: rows 0-21 around 19x10 cells
        sta win_w
        ldx #0
        ldy #0
        lda #22
        jsr draw_window
        lda #COL_WHITE          ; title in the top edge: " World n: Name "
        sta cur_col
        ldx #2
        ldy #0
        jsr set_cursor
        lda #<str_world_title
        ldx #>str_world_title
        jsr put_str
        lda world_cur
        clc
        adc #'1'
        jsr put_char
        lda #':'
        jsr put_char
        lda #' '
        jsr put_char
        ldy #WREC_NAME
        lda (world_rec),y
        pha
        iny
        lda (world_rec),y
        tax
        pla
        jsr put_str
        lda #' '
        jsr put_char
        lda #COL_WHITE          ; message box with the key help in its bottom edge
        sta cur_col
        lda #40
        sta win_w
        ldx #0
        ldy #22
        lda #3
        jsr draw_window
        lda #COL_WHITE
        sta cur_col
        ldx #1
        ldy #24
        jsr set_cursor
        lda #<str_bottom_world
        ldx #>str_bottom_world
        jsr put_str
        ; Map cells.
        lda #0
        sta wm_dy
.row    lda #0
        sta wm_dx
.col    ldx wm_dx
        ldy wm_dy
        jsr wm_cell
        jsr wm_draw_type
        inc wm_dx
        lda wm_dx
        cmp #WMAP_COLS
        bne .col
        inc wm_dy
        lda wm_dy
        cmp #WMAP_ROWS
        bne .row
        ; Level nodes: goal field = open, gold chest = solved.
        lda #0
        sta wm_tmp
.node   lda wm_tmp
        cmp world_nlev
        beq .done
        asl
        tay
        lda (wm_nodes),y
        sta wm_dx
        iny
        lda (wm_nodes),y
        sta wm_dy
        lda wm_tmp
        clc
        adc world_first
        jsr level_is_done
        beq .open
        lda #COL_YELLOW+8
        sta cur_col
        lda #2                  ; chest cell
        bne .put
.open   lda run_cell_colors+3
        sta cur_col
        lda #3                  ; goal cell
.put    jsr wm_put_map_cell
        jsr wm_node_digit
        inc wm_tmp
        jmp .node
.done   rts

; Level number of node wm_tmp: hires digit in the bottom-right character of
; its cell (wm_dx, wm_dy).
!zone wm_node_digit
wm_node_digit
        lda wm_dx
        asl
        clc
        adc #WM_X+1
        tax
        lda wm_dy
        asl
        clc
        adc #WM_Y+1
        tay
        jsr set_cursor
        lda #COL_WHITE
        sta cur_col
        lda wm_tmp
        clc
        adc #'1'
        jmp put_char

; A = cell type, cur_col = colour: draw it at map cell (wm_dx, wm_dy).
!zone wm_put_map_cell
wm_put_map_cell
        pha
        lda wm_dx
        asl
        clc
        adc #WM_X
        tax
        lda wm_dy
        asl
        clc
        adc #WM_Y
        tay
        pla
        ; fall through

; A = cell type (0..RUN_CELL_TYPES-1), X/Y = screen column/row of its top-left
; character, cur_col = colour RAM value: the four characters of the cell.
!zone put_cell
put_cell
        stx wm_sx
        sty wm_sy
        asl
        asl
        clc
        adc #RUN_CHAR_BASE
        sta wm_ch
        jsr set_cursor
        lda wm_ch
        jsr put_char
        inc wm_ch
        lda wm_ch
        jsr put_char
        inc wm_ch
        ldx wm_sx
        ldy wm_sy
        iny
        jsr set_cursor
        lda wm_ch
        jsr put_char
        inc wm_ch
        lda wm_ch
        jmp put_char

; X = cell x, Y = cell y -> A = map cell type of the current world.
!zone wm_cell
wm_cell
        stx wm_ix
        tya
        asl
        sta wm_iy               ; 2y
        asl
        asl
        asl                     ; 16y
        clc
        adc wm_iy               ; 18y
        sty wm_iy
        adc wm_iy               ; 19y (always < 256)
        adc wm_ix
        lsr                     ; two cells per byte, carry = odd cell
        tay
        lda (wm_map),y
        bcs .low
        lsr
        lsr
        lsr
        lsr
        rts
.low    and #$0F
        rts

; Node at cell (tmp0, tmp1) -> A = node index, or $FF (N flag set).
!zone wm_find_node
wm_find_node
        ldx #0
        ldy #0
.l      cpx world_nlev
        beq .none
        lda (wm_nodes),y
        cmp tmp0
        bne .next
        iny
        lda (wm_nodes),y
        dey
        cmp tmp1
        bne .next
        txa
        rts
.next   iny
        iny
        inx
        bne .l
.none   lda #$FF
        rts

; Mouse pointer over a level node? Carry set and A = node if so.
!zone world_mouse_node
world_mouse_node
        lda mouse_x_lo          ; cell x = (x - WM_X*8) / 16
        sec
        sbc #WM_X*8
        sta tmp0
        lda mouse_x_hi
        sbc #0
        bcc .miss
        lsr
        ror tmp0
        lsr tmp0
        lsr tmp0
        lsr tmp0
        lda mouse_y
        sec
        sbc #WM_Y*8
        bcc .miss
        lsr
        lsr
        lsr
        lsr
        sta tmp1
        jsr wm_find_node
        bmi .miss
        sec
        rts
.miss   clc
        rts

; Status row: level under the robot, otherwise a hint.
!zone world_status
world_status
        lda wm_cx
        sta tmp0
        lda wm_cy
        sta tmp1
        jsr wm_find_node
        sta wm_node
        bmi .free
        lda #<str_empty
        ldx #>str_empty
        jsr run_draw_message    ; clears the row, cursor at column 2
        lda #COL_YELLOW
        sta cur_col
        lda wm_node
        clc
        adc world_first
        sta wm_tmp
        jsr put_level_name_a
        lda #COL_WHITE
        sta cur_col
        lda wm_tmp
        jsr level_is_done
        beq .open
        lda #<str_world_solved
        ldx #>str_world_solved
        jsr put_str
.open   lda #<str_world_play
        ldx #>str_world_play
        jmp put_str
.free   lda wm_gate_open         ; open gate and a world behind it?
        beq .hint
        lda world_cur
        clc
        adc #1
        cmp #world_count
        bcs .hint
        lda #<str_world_gate
        ldx #>str_world_gate
        jmp run_draw_message
.hint   lda #<str_world_walk
        ldx #>str_world_walk
        jmp run_draw_message

; Walking: one cell per press (held keys keep walking), 2 pixels per frame.
!zone world_tick
world_tick
        lda wm_steps
        beq .idle
        lda wm_vx               ; 16 bit x += signed vx
        beq .y
        clc
        adc wm_px
        sta wm_px
        lda wm_vx
        bmi .neg
        lda wm_px+1
        adc #0
        sta wm_px+1
        jmp .y
.neg    lda wm_px+1
        adc #$FF
        sta wm_px+1
.y      lda wm_py
        clc
        adc wm_vy
        sta wm_py
        dec wm_steps
        beq .arrived
        lda wm_steps            ; walk cycle as on the run screen
        and #4
        asl
        sta run_walk
        jmp run_set_robot_image
.arrived
        lda #0
        sta run_walk
        jsr run_set_robot_image
        jsr world_status
        jmp world_check_gate
.idle   lda wm_confirm
        beq .poll
        rts
.poll   lda key_now
        ldx #3
.find   cmp wm_dir_keys,x
        beq .dir
        dex
        bpl .find
        cmp #KEY_CRSR_UD
        bne .lr
        ldx #3                  ; down, Shift = up
        lda key_shift
        beq .dir
        ldx #2
        bne .dir
.lr     cmp #KEY_CRSR_LR
        bne .done
        ldx #0                  ; right, Shift = left
        lda key_shift
        beq .dir
        ldx #1
.dir    stx robot_dir
        jsr run_set_robot_image
        ldx robot_dir
        lda wm_cx
        clc
        adc run_dx_tab,x
        sta tmp0
        cmp #WMAP_COLS          ; also catches $FF
        bcs .done
        lda wm_cy
        clc
        adc run_dy_tab,x
        sta tmp1
        cmp #WMAP_ROWS
        bcs .done
        ldx tmp0
        ldy tmp1
        jsr wm_cell
        cmp #WM_PATH
        beq .walk
        cmp #WM_BACK
        beq .walk
        cmp #WM_GATE_L          ; gate halves: only when open
        bcc .done
        lda wm_gate_open
        beq .done
.walk   lda wm_cx
        sta wm_prevx
        lda wm_cy
        sta wm_prevy
        lda tmp0
        sta wm_cx
        lda tmp1
        sta wm_cy
        ldx robot_dir
        lda run_dx_tab,x
        asl
        sta wm_vx
        lda run_dy_tab,x
        asl
        sta wm_vy
        lda #RUN_MOVE_FRAMES
        sta wm_steps
        lda #$FF                ; no node while walking
        sta wm_node
        lda robot_dir
        sta tmp3
        jmp sound_move
.done   rts

wm_dir_keys                     ; by direction: right, left, up, down = D A W S
        !byte KEY_D, KEY_A, KEY_W, KEY_S

; Sprite 0 = mouse pointer, sprite 3 = robot (multicolour, as on the run screen).
!zone world_init_sprites
world_init_sprites
        lda #0
        sta VIC_SPR_EXPX
        sta VIC_SPR_EXPY
        sta VIC_SPR_PRI
        lda #$08
        sta VIC_SPR_MC
        lda #COL_BLACK
        sta VIC_SPR_MC0
        lda #COL_WHITE
        sta VIC_SPR_MC1
        lda #SPRITE_BLOCK
        sta SPR_PTR0
        lda #COL_WHITE
        sta VIC_SPR0COL
        lda #ROBOT_COLOR
        sta VIC_SPR0COL+3
        jsr run_set_robot_image
        ; fall through

!zone world_sprites
world_sprites
        lda #0
        sta wm_ix               ; X MSB bits
        lda mouse_x_lo
        clc
        adc #24
        sta VIC_SPR0X
        lda mouse_x_hi
        adc #0
        and #1
        sta wm_ix
        lda mouse_y
        clc
        adc #50
        sta VIC_SPR0Y
        lda wm_px
        clc
        adc #24
        sta VIC_SPR0X+6
        lda wm_px+1
        adc #0
        beq .lo
        lda wm_ix
        ora #$08
        sta wm_ix
.lo     lda wm_ix
        sta VIC_SPRXMSB
        lda wm_py
        clc
        adc #50-RUN_ROBOT_DY
        sta VIC_SPR0X+7
        lda #$09
        sta VIC_SPR_EN
        rts
