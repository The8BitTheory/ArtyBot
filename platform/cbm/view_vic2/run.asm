; run.asm (VIC-II-View) - Run-Bildschirm: Spielfeld aus 2x2-Zeichen-Zellen, Roboter und
; Kiste als Sprites, schimmernde Ziele, Befehlsliste, Meldungszeile, Fensterrahmen.
; Logik (Ausfuehrung, Regeln, Animationstakt): src/run.asm. Positionen run_spx/run_spy und
; run_fx/run_fy sind Feld-Einheiten (16 pro Zelle), hier 1:1 Pixel.

RUN_FIELD_X = 1                 ; screen column of the first cell
RUN_FIELD_Y = 1                 ; screen row of the first cell
RUN_MSG_ROW = 23                ; text row inside the message box
RUN_ROBOT_DY = 2                ; robot art starts 2 lines above its cell
RUN_CHEST_DY = 3                ; chest sprite sits this far above the robot

; A/X = 0-terminated text, shown in the message box (row RUN_MSG_ROW).
!zone run_draw_message
run_draw_message
        sta ptr2
        stx ptr2+1
        lda #COL_WHITE
        sta cur_col
        ldx #1
        ldy #RUN_MSG_ROW
        jsr set_cursor
        lda #38
        sta ui_count
.clear  lda #$20
        jsr put_char
        dec ui_count
        bne .clear
        ldx #2
        ldy #RUN_MSG_ROW
        jsr set_cursor
        lda ptr2
        ldx ptr2+1
        jmp put_str

!zone draw_run_screen
draw_run_screen
        jsr clear_screen
        lda #COL_WHITE
        sta cur_col
        ; Field window (cols 0-21, rows 0-21) around the 20x20 character field.
        ldx #0
        ldy #0
        lda #22
        sta win_w
        lda #22
        jsr draw_window
        lda #COL_WHITE          ; label " <world> <n> " in the top edge
        sta cur_col
        ldx #2
        ldy #0
        jsr set_cursor
        lda #' '
        jsr put_char
        jsr put_level_name
        lda #' '
        jsr put_char
        jsr draw_run_delivered
        ; Command window (cols 22-39, rows 0-21).
        ldx #22
        ldy #0
        lda #18
        sta win_w
        lda #22
        jsr draw_window
        ldx #24
        ldy #0
        lda #<str_run_list
        sta ptr1
        lda #>str_run_list
        sta ptr1+1
        jsr run_label
        ldx #23
        ldy #1
        jsr set_cursor
        lda #<str_program_count
        ldx #>str_program_count
        jsr put_str
        jsr draw_program_counts
        lda #COL_WHITE
        sta cur_col
        ldx #38
        ldy #1
        jsr set_cursor
        lda #ICON_CHAR_BASE+28   ; scrollbar up arrow
        jsr put_char
        ldx #38
        ldy #19
        jsr set_cursor
        lda #ICON_CHAR_BASE+29   ; scrollbar down arrow
        jsr put_char
        jsr draw_scrollbar
        ; Message box (rows 22-24) with the key help in its bottom edge.
        lda #COL_WHITE
        sta cur_col
        ldx #0
        ldy #22
        lda #40
        sta win_w
        lda #3
        jsr draw_window
        ldx #1
        ldy #24
        lda #<str_bottom_run
        sta ptr1
        lda #>str_bottom_run
        sta ptr1+1
        jsr run_label
        jsr draw_run_field
        jmp draw_run_list

; X/Y = position, ptr1 = text: white label in a window edge.
!zone run_label
run_label
        lda #COL_WHITE
        sta cur_col
        jsr set_cursor
        lda ptr1
        ldx ptr1+1
        jmp put_str

; X/Y = top-left corner, win_w = outer width, A = outer height (>= 3).
; Rounded NES-style frame in cur_col; the inside is left untouched.
!zone draw_window
draw_window
        stx win_x
        sty win_y
        sta win_h
        jsr set_cursor
        lda #UI_TL
        jsr put_char
        jsr .hline_top
        lda #UI_TR
        jsr put_char
        lda win_y
        sta ui_row
.side   inc ui_row
        lda win_y
        clc
        adc win_h
        sec
        sbc #1                  ; last row of the frame
        cmp ui_row
        beq .bottom
        ldx win_x
        ldy ui_row
        jsr set_cursor
        lda #UI_LEFT
        jsr put_char
        lda win_x
        clc
        adc win_w
        sec
        sbc #1
        tax
        ldy ui_row
        jsr set_cursor
        lda #UI_RIGHT
        jsr put_char
        jmp .side
.bottom ldx win_x
        ldy ui_row
        jsr set_cursor
        lda #UI_BL
        jsr put_char
        lda #UI_BOTTOM
        jsr .hline
        lda #UI_BR
        jmp put_char
.hline_top
        lda #UI_TOP
.hline  sta ui_save
        lda win_w
        sec
        sbc #2
        sta ui_count
.h      lda ui_save
        jsr put_char
        dec ui_count
        bne .h
        rts

; ---- Sprites -----------------------------------------------------------
; Sprite 2 = carried chest, sprite 3 = robot (sprite 2 is drawn in front).
; Both are multicolour: $D025 black outline, $D026 white highlights.
!zone run_init_sprites
run_init_sprites
        lda #0
        sta VIC_SPRXMSB
        sta VIC_SPR_EXPX
        sta VIC_SPR_EXPY
        sta VIC_SPR_PRI
        lda #$0C                ; sprites 2 and 3 multicolour
        sta VIC_SPR_MC
        lda #COL_BLACK
        sta VIC_SPR_MC0
        lda #COL_WHITE
        sta VIC_SPR_MC1
        lda #RUN_SPR_CHEST
        sta SPR_PTR0+2          ; clear_screen wiped the pointers
        lda #CHEST_COLOR
        sta VIC_SPR0COL+2
        lda #ROBOT_COLOR
        sta VIC_SPR0COL+3
        jsr run_set_robot_image
        jmp run_update_sprites

; Robot image = direction, +4 while the chest is carried, +8 on a walk step.
!zone run_set_robot_image
run_set_robot_image
        lda robot_dir
        ldx run_carry
        beq .set
        clc
        adc #4
.set    clc
        adc run_walk
        adc #RUN_SPR_BLOCK
        sta SPR_PTR0+3
        rts

!zone run_update_sprites
run_update_sprites
        lda run_sunk            ; broke through the ice: robot (and chest) gone
        beq .visible
        jsr gfx_sprites_off
        rts
.visible
        lda #RUN_SPR_CHEST      ; sprite 2: the package or the key
        ldx #CHEST_COLOR
        ldy run_item
        beq .item
        lda #RUN_SPR_KEY
        ldx #KEY_COLOR
.item   sta SPR_PTR0+2
        stx VIC_SPR0COL+2
        lda run_spx
        clc
        adc #24+RUN_FIELD_X*8
        sta VIC_SPR0X+6
        sta VIC_SPR0X+4         ; the chest is held right above the head
        lda run_spy
        clc
        adc #50+RUN_FIELD_Y*8-RUN_ROBOT_DY
        ldx run_jump            ; in the air: lift by the jump arc
        beq .ground
        ldx run_steps
        sec
        sbc run_arc,x
.ground sta VIC_SPR0X+7
        ldx run_carry
        beq .robot_only
        sec
        sbc #RUN_CHEST_DY
        ldx run_walk            ; the chest bobs with the walk step
        beq .chest_y
        sec
        sbc #1
.chest_y
        sta VIC_SPR0X+5
        lda #$0C
        bne .enable
.robot_only
        lda run_fly             ; a thrown package flies on its own
        beq .alone
        lda run_fx
        clc
        adc #24+RUN_FIELD_X*8
        sta VIC_SPR0X+4
        lda run_fy
        clc
        adc #50+RUN_FIELD_Y*8-RUN_ROBOT_DY-RUN_CHEST_DY
        ldx run_fsteps
        sec
        sbc run_throw_arc,x
        sta VIC_SPR0X+5
        lda #$0C
        bne .enable
.alone  lda #$08
.enable sta VIC_SPR_EN
        rts

; Height above the ground (pixels) by frames left, RUN_JUMP_FRAMES..0:
; s*(16-s)/6, peak 10 pixels in the middle of the jump.
run_arc
        !byte 0, 2, 4, 6, 8, 9, 10, 10, 10, 10, 10, 9, 8, 6, 4, 2, 0

; Thrown package: the same arc, sinking 5 pixels over the flight from the
; carrying height down to the ground (signed).
run_throw_arc
        !byte 256-5, 256-2, 1, 3, 5, 7, 8, 8, 9, 9, 9, 9, 8, 6, 4, 2, 0

; The goal circles shimmer: every 8 frames the colour RAM of every free goal
; field cycles (fields that hold a chest keep the chest colour).
!zone run_goal_anim
run_goal_anim
        inc run_gtimer
        lda run_gtimer
        and #7
        bne .done
        inc run_gphase
        lda run_gphase
        and #3
        tax
        lda run_goal_colors,x
        sta run_gcol
        lda #0
        sta run_gi
.next   lda run_gi
        lsr
        cmp goal_count
        bcs .done
        lda run_gi
        tax
        lda goal_list,x
        sta tmp0
        lda goal_list+1,x
        sta tmp1
        jsr map_index
        lda map_work,x
        cmp #T_GOAL
        bne .skip
        jsr run_paint_goal
.skip   inc run_gi
        inc run_gi
        jmp .next
.done   rts

; tmp0/tmp1 = goal field, run_gcol = colour: recolour its four characters.
!zone run_paint_goal
run_paint_goal
        lda tmp1
        asl
        clc
        adc #RUN_FIELD_Y
        tax
        lda tmp0
        asl
        clc
        adc #RUN_FIELD_X
        clc
        adc row_lo,x
        sta ptr0
        lda row_hi,x
        adc #>(COLORRAM - SCREEN)
        sta ptr0+1
        lda run_gcol
        ldy #0
        sta (ptr0),y
        iny
        sta (ptr0),y
        ldy #40
        sta (ptr0),y
        iny
        sta (ptr0),y
        rts

run_goal_colors                 ; multicolour flag + cyan, white, cyan, purple
        !byte COL_CYAN+8, COL_WHITE+8, COL_CYAN+8, 4+8

; Bottom edge of the field window (row 21): " Delivered: n/m " = goal fields that
; hold a chest / all goal fields. Clobbers A, X, Y, tmp0-tmp3, ptr0, ptr2.
!zone draw_run_delivered
draw_run_delivered
        ldx #MAP_CELLS-1
        lda #0
        sta tmp0
.cnt    lda map_work,x
        cmp #T_BOXG
        bne .nx
        inc tmp0
.nx     dex
        bpl .cnt
        lda #COL_WHITE
        sta cur_col
        ldx #2
        ldy #21
        jsr set_cursor
        lda #<str_run_delivered
        ldx #>str_run_delivered
        jsr put_str
        lda tmp0
        jsr .num
        lda #'/'
        jsr put_char
        lda goal_count
        jsr .num
        lda #' '
        jmp put_char
.num    cmp #10                 ; one or two digits
        bcs .two
        clc
        adc #$30
        jmp put_char
.two    jmp draw_decimal2

; ---- Field -------------------------------------------------------------
; 10x10 cells, each 2x2 characters, from the level layer in map_work.
!zone draw_run_field
draw_run_field
        lda #0
        sta ui_row
.row    lda #0
        sta ui_col
.col    jsr draw_run_cell
        inc ui_col
        lda ui_col
        cmp #MAP_COLS
        bne .col
        inc ui_row
        lda ui_row
        cmp #MAP_ROWS
        bne .row
        rts

; Draw the cell (ui_col, ui_row). Floor on the target position shows the
; goal circle; some floor cells get flowers (fixed pattern, purely decorative).
!zone draw_run_cell
draw_run_cell
        lda ui_col
        sta tmp0
        lda ui_row
        sta tmp1
        jsr map_index
        lda #0
        sta run_gold
        lda map_work,x
        sta ui_save             ; cell type 0..3 = display tile
        beq .floor
        cmp #T_ICE              ; ice / broken ice: own display cells
        bcc .not_ice
        clc
        adc #RUN_CELL_ICE-T_ICE
        sta ui_save
        bne .typed
.not_ice
        cmp #T_BOXG
        bne .typed
        lda #T_BOX              ; chest on a goal field: shown as a gold chest
        sta ui_save
        lda #1
        sta run_gold
        bne .typed
.floor  ldx ui_row              ; flowers: bit (col & 7) of the row mask
        lda ui_col
        and #7
        tay
        lda run_flower_rows,x
        and run_bit_tab,y
        beq .typed
        lda #4                  ; grass with flowers
        sta ui_save
.typed  ldx ui_save
        lda run_cell_colors,x
        ldy run_gold
        beq .colour
        lda #COL_YELLOW+8
.colour sta cur_col
        txa
        asl
        asl
        clc
        adc #RUN_CHAR_BASE
        sta ui_index            ; first of the four characters
        lda ui_col
        asl
        clc
        adc #RUN_FIELD_X
        sta ui_count            ; screen column
        lda ui_row
        asl
        clc
        adc #RUN_FIELD_Y
        sta tmp1                ; screen row
        ldx ui_count
        ldy tmp1
        jsr set_cursor
        lda ui_index
        jsr put_char
        lda ui_index
        clc
        adc #1
        jsr put_char
        ldx ui_count
        ldy tmp1
        iny
        jsr set_cursor
        lda ui_index
        clc
        adc #2
        jsr put_char
        lda ui_index
        clc
        adc #3
        jmp put_char

; Colour RAM per display tile; +8 = multicolour character. Shared colours:
; $D021 black, $D022 green, $D023 light green (see run_mode).
run_flower_rows                 ; decorative flower cells, one mask per row
        !byte %00100001, %00000100, %01000000, %00010010, %00000000
        !byte %10000100, %00000001, %00101000, %00000000, %01000010

; ---- Command list ------------------------------------------------------
; Without selection letters: "nn Text"; the running command is yellow.
!zone draw_run_list
draw_run_list
        lda #0
        sta ui_index
.all    jsr draw_run_list_row
        inc ui_index
        lda ui_index
        cmp #PROGRAM_ROWS
        bne .all
        rts

!zone draw_run_list_row
draw_run_list_row
        lda ui_index
        clc
        adc #2
        sta ui_row
        lda #COL_WHITE
        sta cur_col
        ldx #23
        ldy ui_row
        jsr set_cursor
        lda #15
        sta ui_count
.clear  lda #$20
        jsr put_char
        dec ui_count
        bne .clear
        lda scroll_offset
        clc
        adc ui_index
        sta tmp0
        cmp editor_count
        bcs .done
        cmp run_cur
        bne .draw
        ldx #23                 ; pointing hand at the running command
        ldy ui_row
        jsr set_cursor
        lda #UI_HAND
        jsr put_char
        lda #COL_YELLOW
        sta cur_col
.draw   ldx #24
        ldy ui_row
        jsr set_cursor
        lda tmp0
        clc
        adc #1                  ; one-based command number
        jsr draw_decimal2
        ldx #27
        ldy ui_row
        jsr set_cursor
        ldx tmp0
        lda program,x
        jsr draw_short_name
.done   rts
