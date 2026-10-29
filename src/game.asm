; Robotron: programmiere zwanzig Schritte, dann beobachte den Lauf.
!zone game_main
game_main
        lda #$FF
        sta key_prev
        lda #0
        sta joy_prev
        sta joy_new
        sta level_no
        sta attempts
        sta prog_slot
        sta run_state
        lda #COL_WHITE
        sta cur_col
        ldx #0
        lda #4
.clear  sta program,x
        inx
        cpx #prog_len
        bne .clear
        jsr spr_init
        jsr load_level
        jsr draw_interface
        jsr draw_map
        jsr spr_update
        jsr draw_program

.loop   jsr wait_frame
        jsr input_update
        jsr keyboard_to_joy
        lda run_state
        cmp #1
        bne .not_running
        jmp .running
.not_running
        lda joy_new
        and #JOY_FIRE
        beq .edit
        lda run_state
        cmp #2
        beq .next_level
        cmp #3
        beq .restart
        jsr start_run
        jmp .loop
.next_level
        inc level_no
        lda level_no
        cmp #NUM_LEVELS
        bcc .keep_level
        lda #0
        sta level_no
.keep_level
        lda #0
        sta attempts
.restart
        jsr load_level
        jsr draw_map
        jsr spr_update
        lda #0
        sta run_state
        jsr draw_status
        jmp .loop
.edit   lda run_state
        bne .loop
        lda joy_new
        and #JOY_LEFT
        beq .right
        lda prog_slot
        beq .right
        dec prog_slot
        jsr draw_program
.right  lda joy_new
        and #JOY_RIGHT
        beq .up
        lda prog_slot
        cmp #prog_len-1
        bcs .up
        inc prog_slot
        jsr draw_program
.up     lda joy_new
        and #JOY_UP
        beq .down
        ldx prog_slot
        lda program,x
        beq .upwrap
        dec program,x
        jmp .changed
.upwrap lda #4
        sta program,x
        jmp .changed
.down   lda joy_new
        and #JOY_DOWN
        bne .have_down
        jmp .loop
.have_down
        ldx prog_slot
        inc program,x
        lda program,x
        cmp #5
        bcc .changed
        lda #0
        sta program,x
.changed jsr draw_program
        jmp .loop

.running
        dec run_delay
        beq .next_step
        jmp .loop
.next_step
        lda #5
        sta run_delay
        jsr execute_step
        jmp .loop

!zone keyboard_to_joy
keyboard_to_joy
        lda key_new
        cmp #9                  ; W
        beq .up
        cmp #13                 ; S
        beq .down
        cmp #10                 ; A
        beq .left
        cmp #18                 ; D
        beq .right
        cmp #1                  ; RETURN
        beq .fire
        cmp #$3C                ; SPACE
        bne .done
.fire   lda joy_new
        ora #JOY_FIRE
        sta joy_new
        rts
.up     lda joy_new
        ora #JOY_UP
        sta joy_new
        rts
.down   lda joy_new
        ora #JOY_DOWN
        sta joy_new
        rts
.left   lda joy_new
        ora #JOY_LEFT
        sta joy_new
        rts
.right  lda joy_new
        ora #JOY_RIGHT
        sta joy_new
.done   rts

!zone draw_interface
draw_interface
        ldx #0
        ldy #0
        jsr set_cursor
        lda #<str_title
        ldx #>str_title
        jsr put_str
        ldx #26
        ldy #2
        jsr set_cursor
        lda #<str_goal
        ldx #>str_goal
        jsr put_str
        lda level_no
        clc
        adc #1
        jsr print_hex8
        ldx #26
        ldy #5
        jsr set_cursor
        lda #<str_controls
        ldx #>str_controls
        jsr put_str
        ldx #26
        ldy #7
        jsr set_cursor
        lda #<str_controls2
        ldx #>str_controls2
        jsr put_str
        ldx #0
        ldy #22
        jsr set_cursor
        lda #<str_program
        ldx #>str_program
        jsr put_str
        ldx #0
        ldy #24
        jsr set_cursor
        lda #<str_help
        ldx #>str_help
        jsr put_str
        jsr draw_status
        rts

!zone draw_status
draw_status
        ldx #26
        ldy #2
        jsr set_cursor
        lda #<str_goal
        ldx #>str_goal
        jsr put_str
        lda level_no
        clc
        adc #1
        jsr print_hex8
        ldx #26
        ldy #11
        jsr set_cursor
        lda #<str_level
        ldx #>str_level
        jsr put_str
        lda level_no
        clc
        adc #1
        jsr print_hex8
        ldx #26
        ldy #13
        jsr set_cursor
        lda #<str_attempt
        ldx #>str_attempt
        jsr put_str
        lda attempts
        jsr print_hex8
        ldx #26
        ldy #16
        jsr set_cursor
        lda #<str_status
        ldx #>str_status
        jsr put_str
        ldx #26
        ldy #18
        jsr set_cursor
        lda run_state
        cmp #2
        beq .won
        cmp #3
        beq .lost
        lda #<str_ready
        ldx #>str_ready
        jsr put_str
        rts
.won    lda #<str_won
        ldx #>str_won
        jsr put_str
        rts
.lost   lda #<str_lost
        ldx #>str_lost
        jsr put_str
        rts

!zone draw_program
draw_program
        ldx #0
.slot   stx tmp0
        txa
        clc
        adc #9
        tax
        ldy #22
        jsr set_cursor
        ldx tmp0
        cpx prog_slot
        bne .normal
        lda #COL_YELLOW
        sta cur_col
        jmp .glyph
.normal lda #COL_WHITE
        sta cur_col
.glyph  ldx tmp0
        lda program,x
        tax
        lda cmd_chars,x
        jsr put_char
        ldx tmp0
        inx
        cpx #prog_len
        bne .slot
        lda #COL_WHITE
        sta cur_col
        rts

!zone start_run
start_run
        inc attempts
        jsr load_level
        jsr draw_map
        jsr spr_update
        lda #0
        sta prog_pos
        lda #1
        sta run_state
        lda #5
        sta run_delay
        jsr draw_status
        rts

!zone execute_step
execute_step
        ldx prog_pos
        lda program,x
        cmp #4
        bne .command
        jmp .advance
.command
        sta tmp3
        lda robot_tx
        sta tmp0
        lda robot_ty
        sta tmp1
        ldx tmp3
        lda cmd_dx,x
        clc
        adc tmp0
        sta tmp0
        lda cmd_dy,x
        clc
        adc tmp1
        sta tmp1
        lda tmp0
        cmp #MAP_W
        bcc .x_ok
        jmp .blocked
.x_ok
        lda tmp1
        cmp #MAP_H
        bcc .y_ok
        jmp .blocked
.y_ok
        lda tmp1
        asl
        asl
        asl
        asl
        ora tmp0
        tax
        lda map_work,x
        cmp #T_WALL
        bne .not_wall
        jmp .blocked
.not_wall
        cmp #T_BOX
        bne .move_robot
        ; compute the square beyond the box using the active command
        ldx tmp3
        lda box_tx
        clc
        adc cmd_dx,x
        sta tmp2
        lda box_ty
        clc
        adc cmd_dy,x
        cmp #MAP_H
        bcc .box_y_ok
        jmp .blocked
.box_y_ok
        sta tmp1
        lda tmp2
        cmp #MAP_W
        bcc .box_x_ok
        jmp .blocked
.box_x_ok
        lda tmp1
        asl
        asl
        asl
        asl
        ora tmp2
        tax
        lda map_work,x
        cmp #T_FLOOR
        bne .box_goal
        jmp .push_box
.box_goal
        cmp #T_GOAL
        beq .push_box_ok
        jmp .blocked
.push_box_ok
.push_box
        lda box_ty
        asl
        asl
        asl
        asl
        ora box_tx
        tax
        lda #T_FLOOR
        cpx goal_index
        bne .old_box
        lda #T_GOAL
.old_box
        sta map_work,x
        lda tmp2
        sta box_tx
        lda tmp1
        sta box_ty
        lda tmp1
        asl
        asl
        asl
        asl
        ora tmp2
        tax
        lda #T_BOX
        sta map_work,x
        lda box_tx
        sta robot_tx
        lda box_ty
        sta robot_ty
        jmp .redraw
.move_robot
        lda tmp0
        sta robot_tx
        lda tmp1
        sta robot_ty
.redraw
        jsr sound_move
        jsr draw_map
        jsr spr_update
        lda box_tx
        cmp goal_tx
        bne .advance
        lda box_ty
        cmp goal_ty
        beq .success
.advance
        inc prog_pos
        lda prog_pos
        cmp #prog_len
        bcc .done
        lda #3
        sta run_state
        jsr sound_error
        jsr draw_status
.done   rts
.blocked
        lda #3
        sta run_state
        jsr sound_error
        jsr draw_status
        rts
.success
        lda #2
        sta run_state
        jsr sound_success
        jsr draw_status
        rts

!zone load_level
load_level
        lda level_no
        asl
        tax
        lda level_ptrs,x
        sta ptr0
        lda level_ptrs+1,x
        sta ptr0+1
        ldx #0
        lda #T_WALL
.fill   sta map_work,x
        inx
        bne .fill
        ldy #0
        sty tmp2
        sty tmp0
.row    lda #0
        sta tmp1
.col    lda (ptr0),y
        jsr tile_from_char
        sta tmp3
        cmp #T_ROBOT
        bne .not_robot
        lda tmp1
        sta robot_tx
        lda tmp0
        sta robot_ty
        lda #T_FLOOR
        sta tmp3
.not_robot
        lda tmp3
        cmp #T_BOX
        bne .not_box
        lda tmp1
        sta box_tx
        lda tmp0
        sta box_ty
.not_box
        lda tmp3
        cmp #T_GOAL
        bne .store
        lda tmp1
        sta goal_tx
        lda tmp0
        sta goal_ty
.store  lda tmp3
        ldx tmp2
        sta map_work,x
        inc tmp2
        iny
        inc tmp1
        lda tmp1
        cmp #MAP_W
        bne .col
        lda tmp2
        clc
        adc #16-MAP_W
        sta tmp2
        inc tmp0
        lda tmp0
        cmp #MAP_H
        bne .row
        lda goal_ty
        asl
        asl
        asl
        asl
        ora goal_tx
        sta goal_index
        rts

; Coordinates: right, down, left, up
cmd_dx  !byte 1,0,$FF,0
cmd_dy  !byte 0,1,0,$FF
cmd_chars !byte $3E,$76,$3C,$5E,$2D
goal_index !byte 0
