; run.asm - Run screen (own game mode) in an RPG look (Lykia / NES & SNES
; Final Fantasy): multicolour 10x10 field of 2x2-character cells on the left,
; read-only command list on the right with a pointing-hand cursor, message box
; at the bottom, all in rounded NES-style window frames. Space plays the plan:
; the robot is a multicolour sprite (sprite 3) with a two-frame walk cycle; a
; carried package (chest) is sprite 2, held above the robot's head.
; Keys: Space = run, P = back to planning mode, X = quit (confirmed).
; The mouse is ignored (pointer and insertion marker sprites are off).

run_confirm   = $46             ; 1 while "Really quit?" is shown
run_state     = $47             ; 0 ready, 1 running, 2 stopped (finished/failed)
run_pc        = $48             ; next command to execute
run_cur       = $49             ; command shown highlighted ($FF = none)
run_phase     = $4A             ; 0 fetch next, 1 moving, 2 turning
run_timer     = $4B             ; frames to wait before the next step
run_carry     = $4C             ; 1 while the package is carried
run_spx       = $4D             ; robot pixel position inside the field area
run_spy       = $4E
run_vx        = $4F             ; movement per frame (signed pixels)
run_vy        = $50
run_steps     = $51             ; movement frames left
run_turn      = $52             ; quarter turns left
run_turn_dir  = $53             ; 0 right, 1 left
run_tx        = $54             ; scratch: target cell
run_ty        = $55
run_cmd       = $56
run_mdir      = $57
run_msg       = $58             ; address of the text shown in the info row
run_walk      = $5A             ; 0 or 8: walk-cycle frame added to the robot image
run_gtimer    = $5B             ; frame counter for the shimmering goal
run_gphase    = $5C             ; colour index of the goal shimmer

RUN_FIELD_X = 1                 ; screen column of the first cell
RUN_FIELD_Y = 1                 ; screen row of the first cell
RUN_MSG_ROW = 23                ; text row inside the message box
RUN_ROBOT_DY = 2                ; robot art starts 2 lines above its cell
RUN_CHEST_DY = 3                ; chest sprite sits this far above the robot
RUN_MOVE_FRAMES = 8             ; 2 pixels per frame = one 16 pixel cell
KEY_P       = 41                ; C64 keyboard matrix codes
KEY_X       = 23
KEY_SPACE   = 60
KEY_RETURN  = 1
KEY_LEFTARROW = 57

!macro run_fail .msg {
        lda #<.msg
        ldx #>.msg
        jmp run_fail
}

; Called from the planning mode. Returns when P is pressed; the caller
; redraws the planning screen.
!zone run_mode
run_mode
        lda #0
        sta run_confirm
        sta run_gtimer
        sta run_gphase
        lda #RUN_BG1            ; multicolour grass greens for the field cells
        sta VIC_BG1
        lda #RUN_BG2
        sta VIC_BG2
        jsr run_reset
        jsr draw_run_screen
        jsr run_init_sprites
        lda #<str_run_ready
        ldx #>str_run_ready
        jsr run_say
.loop   jsr wait_frame
        jsr input_update
        lda run_confirm
        bne .sprites
        lda run_state
        cmp #1
        bne .sprites
        jsr run_tick
.sprites
        jsr run_update_sprites
        jsr run_goal_anim
        lda key_new
        cmp #$FF
        beq .loop
        ldx key_repeat          ; auto-repeat is ignored
        bne .loop
        ldx run_confirm
        bne .confirm
        cmp #KEY_P
        beq .leave
        cmp #KEY_SPACE
        beq .space
        cmp #KEY_X
        bne .loop
        lda #1
        sta run_confirm
        lda #<str_run_quit
        ldx #>str_run_quit
        jsr run_draw_message
        jmp .loop
.space  jsr run_space
        jmp .loop
.confirm
        cmp #KEY_RETURN
        beq .quit
        cmp #KEY_LEFTARROW
        bne .loop
        lda #0
        sta run_confirm
        lda run_msg
        ldx run_msg+1
        jsr run_draw_message
        jmp .loop
.quit   jmp system_reset
.leave  lda #COL_DGREY           ; planning screen colours (see video_init)
        sta VIC_BG1
        lda #COL_ORANGE
        sta VIC_BG2
        lda level_no            ; plan view shows the untouched level again
        jsr load_plan_level
        rts

!zone system_reset
system_reset
        sei
        lda #$37                ; BASIC + KERNAL + I/O visible again
        sta CPU_PORT
        jmp $FCE2               ; KERNAL reset entry (soft reset)

; A/X = text for the info row; remembered so it can be restored.
!zone run_say
run_say
        sta run_msg
        stx run_msg+1
        ; fall through

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

; Reload the level and reset all playback state.
!zone run_reset
run_reset
        lda level_no
        jsr load_plan_level
        lda #0
        sta run_state
        sta run_pc
        sta run_phase
        sta run_timer
        sta run_carry
        sta run_walk
        sta scroll_offset
        lda #$FF
        sta run_cur
        lda robot_tx
        asl
        asl
        asl
        asl
        clc
        adc #RUN_FIELD_X*8
        sta run_spx
        lda robot_ty
        asl
        asl
        asl
        asl
        clc
        adc #RUN_FIELD_Y*8
        sta run_spy
        rts

; Space: start (or restart after a stop). Ignored while running.
!zone run_space
run_space
        lda run_state
        cmp #1
        beq .done
        cmp #2
        bne .go
        jsr run_reset
        jsr draw_run_field
        jsr draw_run_list
        jsr draw_scrollbar
        jsr run_set_robot_image
.go     lda #1
        sta run_state
        lda #<str_run_going
        ldx #>str_run_going
        jsr run_say
.done   rts

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
        ldx #2
        ldy #0
        lda #<str_run_field
        sta ptr1
        lda #>str_run_field
        sta ptr1+1
        jsr run_label
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
        ldx #7
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
        lda run_spx
        clc
        adc #24
        sta VIC_SPR0X+6
        sta VIC_SPR0X+4         ; the chest is held right above the head
        lda run_spy
        clc
        adc #50-RUN_ROBOT_DY
        sta VIC_SPR0X+7
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
        lda #$08
.enable sta VIC_SPR_EN
        rts

; The goal circle shimmers: every 8 frames its colour RAM cycles, unless the
; chest stands on it.
!zone run_goal_anim
run_goal_anim
        inc run_gtimer
        lda run_gtimer
        and #7
        bne .done
        lda goal_tx
        sta tmp0
        lda goal_ty
        sta tmp1
        jsr map_index
        lda map_work,x
        cmp #T_BOX
        beq .done
        inc run_gphase
        lda run_gphase
        and #3
        tax
        lda run_goal_colors,x
        sta cur_col
        lda goal_ty
        asl
        clc
        adc #RUN_FIELD_Y
        tax
        lda goal_tx
        asl
        clc
        adc #RUN_FIELD_X
        clc
        adc row_lo,x
        sta ptr0
        lda row_hi,x
        adc #>(COLORRAM - SCREEN)
        sta ptr0+1
        lda cur_col
        ldy #0
        sta (ptr0),y
        iny
        sta (ptr0),y
        ldy #40
        sta (ptr0),y
        iny
        sta (ptr0),y
.done   rts

run_goal_colors                 ; multicolour flag + cyan, white, cyan, purple
        !byte COL_CYAN+8, COL_WHITE+8, COL_CYAN+8, 4+8

; ---- Playback ----------------------------------------------------------
!zone run_tick
run_tick
        lda run_timer
        beq .act
        dec run_timer
        rts
.act    lda run_phase
        cmp #1
        beq .moving
        cmp #2
        beq .turning
        jmp run_fetch
.moving lda run_spx
        clc
        adc run_vx
        sta run_spx
        lda run_spy
        clc
        adc run_vy
        sta run_spy
        dec run_steps
        beq .arrived
        lda run_steps           ; walk cycle: step frame for 4 of 8 frames
        and #4
        asl                     ; 0 or 8
        sta run_walk
        jmp run_set_robot_image
.arrived
        lda #0
        sta run_phase
        sta run_walk
        lda #3
        sta run_timer
        jmp run_set_robot_image
.done   rts
.turning
        ldx robot_dir
        lda run_turn_dir
        bne .left
        lda run_tr_tab,x
        jmp .apply
.left   lda run_tl_tab,x
.apply  sta robot_dir
        jsr run_set_robot_image
        lda #1
        sta tmp3
        jsr sound_move
        lda #6
        sta run_timer
        dec run_turn
        bne .done
        lda #0
        sta run_phase
        rts

run_dx_tab !byte 1,$FF,0,0      ; right, left, up, down
run_dy_tab !byte 0,0,$FF,1
run_tr_tab !byte 3,2,0,1        ; direction after a right turn
run_tl_tab !byte 2,3,1,0        ; ... after a left turn

!zone run_fetch
run_fetch
        lda run_pc
        cmp editor_count
        bcc .have
        lda #$FF                ; program ended without delivering
        sta run_cur
        jsr draw_run_list
        lda #<str_run_end
        ldx #>str_run_end
        jmp run_stop
.have   sta run_cur
        tax
        inc run_pc
        lda program,x
        sta run_cmd
        jsr run_follow_cursor
        lda run_cmd
        beq .fwd
        cmp #1
        beq .back
        cmp #2
        beq .tright
        cmp #3
        beq .tleft
        cmp #4
        beq .pick
        cmp #5
        beq .drop
        lda #0                  ; 6: turn 180 = two right turns
        ldx #2
        jmp run_start_turn
.fwd    lda robot_dir
        jmp run_do_move
.back   lda robot_dir
        eor #1
        jmp run_do_move
.tright lda #0
        ldx #1
        jmp run_start_turn
.tleft  lda #1
        ldx #1
        jmp run_start_turn
.pick   jmp run_pickup
.drop   jmp run_drop

; Keep the running command visible in the list and highlighted.
!zone run_follow_cursor
run_follow_cursor
        lda run_cur
        sec
        sbc scroll_offset
        bcc .above
        cmp #PROGRAM_ROWS
        bcc .redraw
        lda run_cur
        sec
        sbc #PROGRAM_ROWS-1
        sta scroll_offset
        jmp .redraw
.above  lda run_cur
        sta scroll_offset
.redraw jsr draw_run_list
        jmp draw_scrollbar

; A = turn direction (0 right, 1 left), X = number of quarter turns
!zone run_start_turn
run_start_turn
        sta run_turn_dir
        stx run_turn
        lda #2
        sta run_phase
        lda #0
        sta run_timer
        rts

; A = direction to move in (0..3). Walls, the package and the field edge block.
!zone run_do_move
run_do_move
        sta run_mdir
        tax
        lda robot_tx
        clc
        adc run_dx_tab,x
        sta run_tx
        cmp #MAP_COLS           ; also catches $FF (left of the field)
        bcs .blocked
        lda robot_ty
        clc
        adc run_dy_tab,x
        sta run_ty
        cmp #MAP_ROWS
        bcs .blocked
        lda run_tx
        sta tmp0
        lda run_ty
        sta tmp1
        jsr map_index
        lda map_work,x
        cmp #T_WALL
        beq .blocked
        cmp #T_BOX
        beq .blocked
        lda run_tx
        sta robot_tx
        lda run_ty
        sta robot_ty
        ldx run_mdir
        lda run_dx_tab,x
        asl                     ; 2 pixels per frame
        sta run_vx
        lda run_dy_tab,x
        asl
        sta run_vy
        lda #RUN_MOVE_FRAMES
        sta run_steps
        lda #1
        sta run_phase
        lda run_mdir
        sta tmp3
        jmp sound_move
.blocked
        +run_fail str_run_blocked

; Cell in front of the robot: carry set and X = map index when inside the field.
; run_tx/run_ty hold the cell.
!zone run_front_cell
run_front_cell
        ldx robot_dir
        lda robot_tx
        clc
        adc run_dx_tab,x
        cmp #MAP_COLS
        bcs .out
        sta run_tx
        sta tmp0
        lda robot_ty
        clc
        adc run_dy_tab,x
        cmp #MAP_ROWS
        bcs .out
        sta run_ty
        sta tmp1
        jsr map_index
        sec
        rts
.out    clc
        rts

!zone run_redraw_front
run_redraw_front
        lda run_tx
        sta ui_col
        lda run_ty
        sta ui_row
        jmp draw_run_cell

!zone run_pickup
run_pickup
        lda run_carry
        beq .free
        +run_fail str_run_full
.free   jsr run_front_cell
        bcc .nothing
        lda map_work,x
        cmp #T_BOX
        bne .nothing
        lda #T_FLOOR
        sta map_work,x
        jsr run_redraw_front
        lda #1
        sta run_carry
        jsr run_set_robot_image
        lda #16
        sta run_timer
        lda #3
        sta tmp3
        jmp sound_move
.nothing
        +run_fail str_run_nopick

!zone run_drop
run_drop
        lda run_carry
        bne .carrying
        +run_fail str_run_nodrop
.carrying
        jsr run_front_cell
        bcc .cant
        lda map_work,x
        beq .ok                 ; free floor
        cmp #T_GOAL
        bne .cant
.ok     lda #T_BOX
        sta map_work,x
        jsr run_redraw_front
        lda #0
        sta run_carry
        jsr run_set_robot_image
        lda #16
        sta run_timer
        lda run_tx
        cmp goal_tx
        bne .more
        lda run_ty
        cmp goal_ty
        bne .more
        jsr sound_success       ; delivered to the target area
        lda #$FF
        sta run_cur
        jsr draw_run_list
        lda #<str_run_done
        ldx #>str_run_done
        jmp run_stop
.more   lda #3
        sta tmp3
        jmp sound_move
.cant   +run_fail str_run_cantdrop

; A/X = message. Stops playback and keeps the failing command highlighted.
!zone run_fail
run_fail
        pha
        txa
        pha
        jsr sound_error
        pla
        tax
        pla
        ; fall through

!zone run_stop
run_stop
        jsr run_say
        lda #2
        sta run_state
        lda #0
        sta run_phase
        sta run_timer
        rts

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
        lda map_work,x
        sta ui_save             ; cell type 0..3 = display tile
        bne .typed
        lda ui_col
        cmp goal_tx
        bne .floor
        lda ui_row
        cmp goal_ty
        bne .floor
        lda #T_GOAL
        sta ui_save
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
        sta cur_col
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
run_bit_tab
        !byte $01, $02, $04, $08, $10, $20, $40, $80

run_cell_colors                 ; grass, tree trunk, chest, goal, flowers
        !byte COL_GREEN+8, COL_RED+8, CHEST_COLOR+8, COL_CYAN+8, COL_YELLOW+8

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
