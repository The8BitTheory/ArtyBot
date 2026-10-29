; run.asm - Run screen (own game mode): 20x20 field with 2x2-tile cells on the
; left, read-only command list on the right. Space plays the plan: the robot is
; a hardware sprite (sprite 3) that walks/turns; a carried package is sprite 2.
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

RUN_FIELD_X = 1                 ; screen column of the first cell
RUN_FIELD_Y = 1                 ; screen row of the first cell
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
        jsr editor_draw_message
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
        jsr editor_draw_message
        jmp .loop
.quit   jmp system_reset
.leave  lda level_no            ; plan view shows the untouched level again
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
        jmp editor_draw_message

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
        ldx #0
        ldy #0
        jsr set_cursor
        lda #<str_title_run
        ldx #>str_title_run
        jsr put_str
        jsr draw_run_field
        jsr draw_program_panel
        jsr draw_program_counts
        jsr draw_run_list
        lda #<str_bottom_run
        ldx #>str_bottom_run
        jmp draw_help_areas_str

; ---- Sprites -----------------------------------------------------------
; Sprite 2 = carried package, sprite 3 = robot (sprite 2 is drawn in front).
!zone run_init_sprites
run_init_sprites
        lda #0
        sta VIC_SPRXMSB
        sta VIC_SPR_MC
        sta VIC_SPR_EXPX
        sta VIC_SPR_EXPY
        sta VIC_SPR_PRI
        lda #RUN_SPR_BLOCK+8
        sta SPR_PTR0+2          ; clear_screen wiped the pointers
        lda #COL_YELLOW
        sta VIC_SPR0COL+2
        lda #COL_WHITE
        sta VIC_SPR0COL+3
        jsr run_set_robot_image
        jmp run_update_sprites

; Robot image = direction, +4 while the package is carried.
!zone run_set_robot_image
run_set_robot_image
        lda robot_dir
        ldx run_carry
        beq .set
        clc
        adc #4
.set    clc
        adc #RUN_SPR_BLOCK
        sta SPR_PTR0+3
        rts

!zone run_update_sprites
run_update_sprites
        lda run_spx
        clc
        adc #24
        sta VIC_SPR0X+6
        lda run_spy
        clc
        adc #50
        sta VIC_SPR0X+7
        lda run_carry
        beq .robot_only
        ldx robot_dir           ; the package sits in the gripper
        lda run_spx
        clc
        adc run_pk_x,x
        sta VIC_SPR0X+4
        lda run_spy
        clc
        adc run_pk_y,x
        sta VIC_SPR0X+5
        lda #$0C
        bne .enable
.robot_only
        lda #$08
.enable sta VIC_SPR_EN
        rts

run_pk_x !byte 34,20,27,27      ; per direction: right, left, up, down
run_pk_y !byte 53,53,46,60

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
        bne .done
        lda #0
        sta run_phase
        lda #3
        sta run_timer
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

; Draw the cell (ui_col, ui_row). Floor on the target position shows the goal.
!zone draw_run_cell
draw_run_cell
        lda ui_col
        sta tmp0
        lda ui_row
        sta tmp1
        jsr map_index
        lda map_work,x
        sta ui_save             ; cell type 0..3
        bne .typed
        lda ui_col
        cmp goal_tx
        bne .typed
        lda ui_row
        cmp goal_ty
        bne .typed
        lda #T_GOAL
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

; Colours stay below 8 so the cells remain hires characters.
run_cell_colors                 ; floor, blocker, package, goal
        !byte COL_BLUE, COL_RED, COL_YELLOW, COL_GREEN

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
