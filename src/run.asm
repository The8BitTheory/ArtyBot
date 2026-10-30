; run.asm - Run screen (own game mode) in an RPG look (Lykia / NES & SNES
; Final Fantasy): multicolour 10x10 field of 2x2-character cells on the left,
; read-only command list on the right with a pointing-hand cursor, message box
; at the bottom, all in rounded NES-style window frames. Space plays the plan:
; the robot is a multicolour sprite (sprite 3) with a two-frame walk cycle; a
; carried package (chest) is sprite 2, held above the robot's head.
; Keys: Space = run / pause / continue, R = restart the run, P = back to
; planning mode, X = quit (confirmed).
; The mouse is ignored (pointer and insertion marker sprites are off).

run_confirm   = $46             ; 1 while "Really quit?" is shown
run_state     = $47             ; 0 ready, 1 running, 2 stopped (finished/failed), 3 paused,
                                ; 4 level won (Space = next level)
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
run_gold      = $5D             ; 1: draw the chest cell gold (chest on a goal field)
run_gcol      = $5E             ; goal shimmer colour of this step
run_gi        = $5F             ; goal_list offset while shimmering
run_won_wait  = $60             ; frames of fanfare before a key leaves the won level
run_jump      = $62             ; 1 while the robot is in the air (Jump)
run_fly       = $63             ; 1 while a thrown package is in the air (Throw)
run_fx        = $64             ; thrown package: pixel position inside the field area
run_fy        = $65
run_fvx       = $66             ; thrown package: movement per frame (signed pixels)
run_fvy       = $67
run_fsteps    = $68             ; thrown package: flight frames left
run_mid       = $69             ; tile id of the field jumped over / thrown across
run_ftile     = $6A             ; tile the thrown package becomes when it lands
run_fidx      = $6B             ; map index of that landing field

RUN_FIELD_X = 1                 ; screen column of the first cell
RUN_FIELD_Y = 1                 ; screen row of the first cell
RUN_MSG_ROW = 23                ; text row inside the message box
RUN_ROBOT_DY = 2                ; robot art starts 2 lines above its cell
RUN_CHEST_DY = 3                ; chest sprite sits this far above the robot
RUN_MOVE_FRAMES = 8             ; 2 pixels per frame = one 16 pixel cell
RUN_JUMP_FRAMES = 16            ; 2 pixels per frame = two cells (jump and throw)
KEY_P       = 41                ; C64 keyboard matrix codes
KEY_X       = 23
KEY_SPACE   = 60
KEY_R       = 17
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
        jsr run_won_tick
        lda key_new
        cmp #$FF
        beq .loop
        ldx key_repeat          ; auto-repeat is ignored
        bne .loop
        ldx run_confirm
        bne .confirm
        ldx run_state
        cpx #4
        bne .normal
        cmp #KEY_SPACE          ; level won: Space (after the fanfare) goes to the
        bne .normal             ; next level; P, R and X work as usual
        ldx run_won_wait
        bne .loop
        beq .next
.normal cmp #KEY_P
        beq .leave
        cmp #KEY_F1             ; F1 (like P): back to the plan
        beq .f1
        cmp #KEY_SPACE
        beq .space
        cmp #KEY_R
        beq .restart
        cmp #KEY_F7             ; F8 (= Shift+F7) exits
        bne .loop
        ldx key_shift
        beq .loop
.askquit
        lda #1
        sta run_confirm
        lda #<str_run_quit
        ldx #>str_run_quit
        jsr run_draw_message
        jmp .loop
.f1     ldx key_shift           ; Shift+F1 = F2: ignored
        bne .loop
        beq .leave
.space  jsr run_space
        jmp .loop
.restart
        jsr run_restart
        jsr run_go
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
.next   lda level_no            ; next level, back to the first one after the last
        clc
        adc #1
        cmp #plan_level_count
        bcc .set_level
        lda #0
.set_level
        sta level_no
        jsr editor_init         ; fresh level: empty command list
.leave  jsr sound_stop
        lda #RUN_BG1            ; planning screen shares the run colours (see video_init)
        sta VIC_BG1
        lda #RUN_BG2
        sta VIC_BG2
        lda level_no            ; plan view shows the untouched level again
        jsr load_plan_level
        rts

; While the level-won fanfare plays Space is ignored; afterwards the message
; points to Space (next level), R (replay) and P (plan).
!zone run_won_tick
run_won_tick
        lda run_state
        cmp #4
        bne .done
        lda run_confirm
        bne .done
        lda run_won_wait
        beq .done
        dec run_won_wait
        bne .done
        lda #<str_run_next
        ldx #>str_run_next
        jmp run_say
.done   rts

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
        jsr sound_stop
        lda level_no
        jsr load_plan_level
        lda #0
        sta run_state
        sta run_pc
        sta run_phase
        sta run_timer
        sta run_carry
        sta run_walk
        sta run_jump
        sta run_fly
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

; Space: start when ready, pause while running, continue when paused,
; restart after the run has stopped.
!zone run_space
run_space
        lda run_state
        beq run_go
        cmp #1
        beq .pause
        cmp #3
        beq run_go
        jsr run_restart         ; stopped: play again from the start
        jmp run_go
.pause  lda #3
        sta run_state
        lda #<str_run_paused
        ldx #>str_run_paused
        jmp run_say

; Reload the level and redraw field and list (state = ready).
!zone run_restart
run_restart
        jsr run_reset
        jsr draw_run_field
        jsr draw_run_list
        jsr draw_scrollbar
        jmp run_set_robot_image

; Start or continue running.
!zone run_go
run_go  lda #1
        sta run_state
        lda #<str_run_going
        ldx #>str_run_going
        jmp run_say

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
        lda level_no            ; patch the level digit into the label
        clc
        adc #$31
        sta str_run_field_lvl
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
        lda run_spx
        clc
        adc #24
        sta VIC_SPR0X+6
        sta VIC_SPR0X+4         ; the chest is held right above the head
        lda run_spy
        clc
        adc #50-RUN_ROBOT_DY
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
        adc #24
        sta VIC_SPR0X+4
        lda run_fy
        clc
        adc #50-RUN_ROBOT_DY-RUN_CHEST_DY
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
        cmp #3
        beq .flying
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
        lda run_jump            ; in the air: legs stay apart (step frame)
        bne .air
        lda run_steps           ; walk cycle: step frame for 4 of 8 frames
        and #4
        asl                     ; 0 or 8
        sta run_walk
        jmp run_set_robot_image
.air    rts
.arrived
        lda #0
        sta run_phase
        sta run_walk
        sta run_jump
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
.flying                         ; thrown package in the air
        lda run_fx
        clc
        adc run_fvx
        sta run_fx
        lda run_fy
        clc
        adc run_fvy
        sta run_fy
        dec run_fsteps
        bne .air
        lda #0                  ; landed: the field shows the package again
        sta run_fly
        sta run_phase
        lda run_ftile
        ldx run_fidx
        jmp run_land

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
        cmp #7
        beq .jump
        cmp #8
        beq .throw
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
.jump   jmp run_do_jump
.throw  jmp run_do_throw

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
        cmp #T_BOXG
        beq .blocked
        cmp #T_WATER
        beq .water
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
.water  +run_fail str_run_water

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
        beq .take_floor
        cmp #T_BOXG
        bne .nothing
        lda #T_GOAL             ; delivered chest taken back: goal field is free again
        bne .take
.take_floor
        lda #T_FLOOR
.take   sta map_work,x
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
        beq .floor              ; free floor
        cmp #T_GOAL
        bne .cant
        lda #T_BOXG             ; chest on a goal field
        bne .store
.floor  lda #T_BOX
.store  jmp run_land
.cant   +run_fail str_run_cantdrop

; A = new tile (T_BOX / T_BOXG), X = map index of the field run_tx/run_ty: the
; package is put down there (Drop Off, or the end of a Throw).
!zone run_land
run_land
        sta map_work,x
        pha
        jsr run_redraw_front
        lda #0
        sta run_carry
        jsr run_set_robot_image
        lda #16
        sta run_timer
        pla
        cmp #T_BOXG
        bne .more
        jsr run_all_delivered   ; carry set: no free goal field left
        bcc .placed
        jsr sound_celebrate     ; everything delivered: 2 second fanfare
        lda #$FF
        sta run_cur
        jsr draw_run_list
        lda #<str_run_done
        ldx #>str_run_done
        jsr run_stop
        lda #4                  ; level won
        sta run_state
        lda #100                ; the fanfare takes 2 seconds
        sta run_won_wait
        rts
.placed jmp sound_place         ; bright two-part sound for one delivery
.more   lda #3
        sta tmp3
        jmp sound_move

; Field two steps ahead (Jump / Throw). Carry set when it is inside the field;
; then run_tx/run_ty = that field, X = its map index, and run_mid = tile id of
; the field in between (always inside the field then).
!zone run_far_cell
run_far_cell
        ldx robot_dir
        lda run_dx_tab,x
        asl                     ; two steps: +2 / -2 ($FE)
        clc
        adc robot_tx
        cmp #MAP_COLS           ; also catches negative results
        bcs .out
        sta run_tx
        lda run_dy_tab,x
        asl
        clc
        adc robot_ty
        cmp #MAP_ROWS
        bcs .out
        sta run_ty
        lda robot_tx            ; the field in between
        clc
        adc run_dx_tab,x
        sta tmp0
        lda robot_ty
        clc
        adc run_dy_tab,x
        sta tmp1
        jsr map_index
        lda map_work,x
        sta run_mid
        lda run_tx
        sta tmp0
        lda run_ty
        sta tmp1
        jsr map_index
        sec
        rts
.out    clc
        rts

; Jump: over the next field onto the one behind it. Trees block the jump, water
; and packages can be jumped over; the landing field must be free floor or a
; free goal field. The robot may carry a package while jumping.
!zone run_do_jump
run_do_jump
        jsr run_far_cell
        bcc .noland
        lda run_mid
        cmp #T_WALL
        beq .tree
        lda map_work,x
        beq .go                 ; free floor
        cmp #T_GOAL
        bne .noland
.go     lda run_tx
        sta robot_tx
        lda run_ty
        sta robot_ty
        ldx robot_dir
        lda run_dx_tab,x
        asl                     ; 2 pixels per frame
        sta run_vx
        lda run_dy_tab,x
        asl
        sta run_vy
        lda #RUN_JUMP_FRAMES
        sta run_steps
        lda #1
        sta run_phase
        sta run_jump
        lda #8                  ; legs apart in the air
        sta run_walk
        jsr run_set_robot_image
        jmp sound_jump
.tree   +run_fail str_run_tree
.noland +run_fail str_run_noland

; Throw: the carried package flies over the next field and lands on the one
; behind it (one field further than Drop Off). Trees block the throw, water
; and packages can be thrown across; it lands on free floor or a free goal field.
!zone run_do_throw
run_do_throw
        lda run_carry
        bne .carrying
        +run_fail str_run_nothrow
.carrying
        jsr run_far_cell
        bcc .cant
        lda run_mid
        cmp #T_WALL
        beq .tree
        lda map_work,x
        beq .floor              ; free floor
        cmp #T_GOAL
        bne .cant
        lda #T_BOXG
        bne .fly
.floor  lda #T_BOX
.fly    sta run_ftile
        stx run_fidx
        lda #0                  ; the robot lets go, the chest sprite flies on
        sta run_carry
        jsr run_set_robot_image
        lda run_spx
        sta run_fx
        lda run_spy
        sta run_fy
        ldx robot_dir
        lda run_dx_tab,x
        asl
        sta run_fvx
        lda run_dy_tab,x
        asl
        sta run_fvy
        lda #RUN_JUMP_FRAMES
        sta run_fsteps
        lda #1
        sta run_fly
        lda #3                  ; phase 3: package in the air
        sta run_phase
        jmp sound_throw
.tree   +run_fail str_run_tree
.cant   +run_fail str_run_cantthrow

; Carry set when no goal field without a chest is left on the field.
!zone run_all_delivered
run_all_delivered
        ldx #MAP_CELLS-1
.l      lda map_work,x
        cmp #T_GOAL
        beq .no
        dex
        bpl .l
        sec
        rts
.no     clc
        rts

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
        lda #0
        sta run_gold
        lda map_work,x
        sta ui_save             ; cell type 0..3 = display tile
        beq .floor
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
run_bit_tab
        !byte $01, $02, $04, $08, $10, $20, $40, $80

run_cell_colors                 ; grass, tree trunk, chest, goal, flowers, water
        !byte COL_GREEN+8, COL_RED+8, CHEST_COLOR+8, COL_CYAN+8, COL_YELLOW+8, COL_BLUE+8

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
