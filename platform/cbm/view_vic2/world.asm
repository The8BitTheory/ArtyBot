; world.asm (VIC-II-View) - Themes (Zeichensatz-Kacheln, Farben), Weltkarte, Kartenfigur,
; Statuszeile, Level-Statistik zeichnen. Logik (Welten, Fortschritt, Laufen): src/world.asm.

WM_X          = 1               ; screen column of map cell (0,0)
WM_Y          = 1               ; screen row of map cell (0,0)
WM_MSG_ROW    = 23

; ---- Themes --------------------------------------------------------------
; Record: +0 run cells (RUN_CELL_TYPES*32 bytes), +2 planning tiles (PLAN_TILE_COUNT*8
; bytes: floor/goal/package/blocker/water/ice/key/lock/door), +4 $D022, +5 $D023, +6 colour
; RAM of the RUN_CELL_TYPES run cells, then colour RAM per tile id (T_FLOOR..T_DOOR),
; then the colour of the robot arrows in the planning map.
; Colour RAM values +8 = multicolour.
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
        !byte COL_YELLOW+8, COL_YELLOW+8, COL_YELLOW+8, COL_RED+8     ; key, lock, full lock, door
        !byte COL_GREEN+8, COL_RED+8, CHEST_COLOR+8, COL_CYAN+8, COL_YELLOW+8, COL_BLUE+8
        !byte COL_CYAN+8, COL_BLUE+8
        !byte COL_YELLOW+8, COL_YELLOW+8, COL_YELLOW+8, COL_RED+8     ; T_KEY, T_LOCK, T_LOCKED, T_DOOR
        !byte COL_WHITE+8

; Winter: white snow with light-blue shadows, pines, ice-cold water, brown path.
; Keep the colour RAM values in sync with preview() in tools/gen_theme_winter.py.
theme_winter
        !word winter_cells, winter_plan
        !byte COL_WHITE, COL_LBLUE
        !byte COL_BLUE+8, COL_GREEN+8, CHEST_COLOR+8, COL_CYAN+8, COL_CYAN+8, COL_BLUE+8, COL_RED+8
        !byte COL_RED+8, COL_RED+8, COL_CYAN+8, COL_CYAN+8, COL_BLUE+8
        !byte COL_YELLOW+8, COL_YELLOW+8, COL_YELLOW+8, COL_RED+8     ; key, lock, full lock, door
        !byte COL_BLUE+8, COL_GREEN+8, CHEST_COLOR+8, COL_CYAN+8, COL_YELLOW+8, COL_BLUE+8
        !byte COL_CYAN+8, COL_BLUE+8
        !byte COL_YELLOW+8, COL_YELLOW+8, COL_YELLOW+8, COL_RED+8     ; T_KEY, T_LOCK, T_LOCKED, T_DOOR
        !byte COL_PURPLE+8              ; robot arrows: white would vanish in the snow

; Colours of the loaded theme (theme_load copies them here; preset = meadow).
theme_colors

theme_bg1       !byte COL_GREEN         ; $D022

theme_bg2       !byte COL_LGREEN        ; $D023

run_cell_colors                         ; grass, tree trunk, chest, goal, flowers, water, path, gate l/r, arch,
        !byte COL_GREEN+8, COL_RED+8, CHEST_COLOR+8, COL_CYAN+8, COL_YELLOW+8, COL_BLUE+8, COL_YELLOW+8
        !byte COL_RED+8, COL_RED+8, COL_WHITE+8, COL_CYAN+8, COL_BLUE+8   ; ice, broken ice
        !byte COL_YELLOW+8, COL_YELLOW+8, COL_YELLOW+8, COL_RED+8     ; key, lock, full lock, door
!if * - run_cell_colors != RUN_CELL_TYPES {
    !error "run_cell_colors: ein Eintrag pro Zelltyp"
}

map_tile_colors                         ; planning tiles by tile id (T_FLOOR..T_DOOR)
        !byte COL_GREEN+8, COL_RED+8, CHEST_COLOR+8, COL_CYAN+8, COL_YELLOW+8, COL_BLUE+8
        !byte COL_CYAN+8, COL_BLUE+8
        !byte COL_YELLOW+8, COL_YELLOW+8, COL_YELLOW+8, COL_RED+8
!if * - map_tile_colors != T_DOOR + 1 {
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
        jsr gfx_theme_colors
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

STATS_X       = 3               ; overlay window position and width
STATS_Y       = 2
STATS_W       = 34

; Three characters "  -" (no value).
!zone stats_put_dash
stats_put_dash
        lda #' '
        jsr put_char
        lda #' '
        jsr put_char
        lda #'-'
        jmp put_char

; Draws the overlay for world_cur.
!zone stats_draw
stats_draw
        lda #COL_WHITE
        sta cur_col
        lda #STATS_Y+1          ; blank interior
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
        cmp stat_bot
        bne .fill
        lda #COL_WHITE
        sta cur_col
        lda #STATS_W
        sta win_w
        ldx #STATS_X
        ldy #STATS_Y
        lda stat_h
        jsr draw_window
        ldx #STATS_X+1          ; rule under the header
        ldy #STATS_Y+2
        jsr set_cursor
        lda #STATS_W-2
        sta stat_w
.rule   lda #UI_TOP
        jsr put_char
        dec stat_w
        bne .rule
        lda #<str_stats_title   ; " Level statistics: <world> "
        sta ptr1
        lda #>str_stats_title
        sta ptr1+1
        ldx #STATS_X+2
        ldy #STATS_Y
        jsr run_label
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
        lda #<str_stats_close
        sta ptr1
        lda #>str_stats_close
        sta ptr1+1
        ldx #STATS_X+2
        ldy stat_bot
        jsr run_label
        lda #COL_CYAN           ; hint in the blank row above the bottom edge
        sta cur_col
        ldx #5
        ldy stat_bot
        dey
        jsr set_cursor
        lda #<str_stats_worlds
        ldx #>str_stats_worlds
        jsr put_str
        lda #COL_YELLOW         ; header
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
        ldx #25
        ldy #STATS_Y+1
        jsr set_cursor
        lda #<str_stats_par
        ldx #>str_stats_par
        jsr put_str
        ldx #30
        ldy #STATS_Y+1
        jsr set_cursor
        lda #<str_stats_cmds
        ldx #>str_stats_cmds
        jsr put_str
        lda #0                  ; one row per level of this world
        sta wm_tmp
.row    lda wm_tmp
        cmp world_nlev
        bne .more
        rts
.more   clc
        adc world_first
        sta stat_lvl            ; global level number
        lda #COL_WHITE
        sta cur_col
        ldx #5
        lda wm_tmp
        clc
        adc #STATS_Y+3
        tay
        jsr set_cursor
        lda stat_lvl
        jsr stats_put_level_name
        ldx #16                 ; solved?
        lda wm_tmp
        clc
        adc #STATS_Y+3
        tay
        jsr set_cursor
        lda stat_lvl
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
        ldx #25                 ; par: only after a real solution (no spoiler)
        lda wm_tmp
        clc
        adc #STATS_Y+3
        tay
        jsr set_cursor
        ldx stat_lvl
        lda level_cmds,x
        beq .nodash             ; not solved yet (or only with F2)
        lda level_par,x
        jsr stats_put_num
        jmp .cmds
.nodash jsr stats_put_dash
.cmds
        ldx #31                 ; commands (only for solved levels)
        lda wm_tmp
        clc
        adc #STATS_Y+3
        tay
        jsr set_cursor
        ldx stat_lvl
        lda level_cmds,x
        beq .dash
        cmp level_par,x         ; par reached or beaten: green
        beq .good
        bcs .put
.good   ldy #COL_GREEN
        sty cur_col
.put    jsr stats_put_num
        jmp .next
.dash   jsr stats_put_dash
.next   inc wm_tmp
        jmp .row

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

; Robot pixel position from its cell; while walking (wm_steps frames left) it sits
; 2 pixels per frame left back towards the cell it came from (direction robot_dir).
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
        lda wm_steps
        beq .done
        asl                     ; offset = 2 * frames left
        sta tmp3
        ldx robot_dir
        lda run_dx_tab,x
        beq .vert
        bmi .left
        lda wm_px               ; moving right: still left of the target
        sec
        sbc tmp3
        sta wm_px
        bcs .done
        dec wm_px+1
        rts
.left   lda wm_px
        clc
        adc tmp3
        sta wm_px
        bcc .done
        inc wm_px+1
        rts
.vert   lda run_dy_tab,x
        bmi .up
        lda wm_py
        sec
        sbc tmp3
        sta wm_py
        rts
.up     lda wm_py
        clc
        adc tmp3
        sta wm_py
.done   rts

!zone world_draw
world_draw
        jsr gfx_sprites_off
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

; Sprite 0 = mouse pointer (white filling), sprite 2 = its black outline, sprite 3 = robot
; (multicolour, as on the run screen).
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
        lda #SPRITE_BLOCK2
        sta SPR_PTR0+2
        lda #COL_WHITE
        sta VIC_SPR0COL
        lda #COL_BLACK
        sta VIC_SPR0COL+2
        lda #ROBOT_COLOR
        sta VIC_SPR0COL+3
        jsr run_set_robot_image
        ; fall through

!zone world_sprites
world_sprites
        jsr wm_set_pixels
        lda #0
        sta wm_ix               ; X MSB bits
        lda mouse_x_lo
        clc
        adc #24
        sta VIC_SPR0X
        sta VIC_SPR0X+4         ; outline sprite right under the filling
        lda mouse_x_hi
        adc #0
        and #1
        beq .msb
        lda #$05                ; X MSB of sprites 0 and 2
.msb    sta wm_ix
        lda mouse_y
        clc
        adc #50
        sta VIC_SPR0Y
        sta VIC_SPR0Y+4
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
        lda #$0D                ; pointer filling, outline and robot
        sta VIC_SPR_EN
        rts

; Map cell under the mouse pointer: carry set, tmp0/tmp1 = cell (may lie outside
; the map: callers compare with the node list); carry clear above/left of the map.
!zone wm_hit_cell
wm_hit_cell
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
        sec
        rts
.miss   clc
        rts

; Status row for wm_node ($FF = no node: hint, or the open gate).
!zone wm_draw_status
wm_draw_status
        lda wm_node
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


; Statistics window height: most levels of any world + 6 (stat_h, stat_bot).
!zone stats_layout
stats_layout
        lda #0                  ; window height: most levels of any world + 6
        sta stat_h
        sta stat_w
.mx     lda stat_w
        asl
        tax
        lda world_table,x
        sta ptr1
        lda world_table+1,x
        sta ptr1+1
        ldy #WREC_FIRST+1
        lda (ptr1),y
        cmp stat_h
        bcc .small
        sta stat_h
.small  inc stat_w
        lda stat_w
        cmp #world_count
        bcc .mx
        lda stat_h
        clc
        adc #6
        sta stat_h
        clc
        adc #STATS_Y-1
        sta stat_bot            ; screen row of the bottom edge
        rts

; View state of the statistics overlay
stat_lvl        !byte 0                 ; stats_put_level_name / stats rows
stat_w          !byte 0
stat_h          !byte 0                 ; statistics window height
stat_bot        !byte 0                 ; its bottom edge row
