; editor.asm - Planning screen and command-list editing.

ui_index = $29
ui_row   = $2A
ui_save  = $2B
ui_count = $2C
ui_col   = $2D
; $2E is mouse_raw_x in zp.inc; keep this state in an unused zero-page slot.
exit_confirm = $43
arrow_rep = $61              ; auto-repeat counter for scrollbar arrow clicks
PALETTE_NUM = 18
AVAILABLE_COMMANDS = 7
PROGRAM_ROWS = 17

!zone game_main
game_main
        jsr input_init
        jsr editor_init
        lda #0                  ; default level; others are loaded the same way
        jsr load_plan_level
        jsr draw_planning_screen
        jsr draw_program_list
        jsr spr_init
.loop   jsr wait_frame
        jsr input_update
        jsr editor_update_hover
        jsr editor_handle_input
        jsr spr_update
        jmp .loop

!zone editor_init
editor_init
        lda #0
        sta editor_count
        sta insert_pos
        sta scroll_offset
        sta selection_active
        sta delete_pending
        sta exit_confirm
        lda #$FF
        sta hover_command
        lda #0
        tax
.clear_program
        sta program,x
        inx
        cpx #PROGRAM_MAX
        bne .clear_program
        rts

!zone editor_clear_program
editor_clear_program
        lda #0
        sta exit_confirm
        jsr editor_clear_palette_interior
        jsr draw_palette_panel
        lda #0
        ldx #0
.clear  sta program,x
        inx
        cpx #PROGRAM_MAX
        bne .clear
        lda #0
        sta editor_count
        sta insert_pos
        sta scroll_offset
        sta selection_active
        sta delete_pending
        lda #$FF
        sta hover_command
        jsr editor_update_view
        lda #$FF
        jsr editor_draw_info
        rts
; Mouse clicks and palette letters share the same insert path. Up/down move
; the insertion point; letter auto-repeat is ignored so one press inserts once.
!zone editor_handle_input
editor_handle_input
        lda exit_confirm
        beq .normal_input
        jmp editor_handle_exit_confirm
.normal_input
        lda mouse_click
        bne .click
        lda mouse_btn           ; button held on a scrollbar arrow: auto-repeat
        beq .no_repeat
        jsr arrow_hit_test
        bcc .no_repeat
        dec arrow_rep
        bne .no_repeat
        ldx #REPEAT_RATE
        stx arrow_rep
        jmp .arrow_action
.no_repeat
        jmp .keyboard
.click
        ; Bottom line (screen row 24): Run at columns 0..11, X: Exit at columns 12..18.
        lda mouse_y
        cmp #192
        bcc .palette_click
        cmp #200
        bcs .palette_click
        lda mouse_x_hi
        bne .palette_click
        lda mouse_x_lo
        cmp #96
        bcc .run_click          ; columns 0..11: "R: Run plan"
        cmp #152
        bcs .palette_click
        jmp editor_request_exit
.run_click
        jmp editor_run_plan
.palette_click
        ; Scrollbar arrows act like cursor up/down (move marker / scroll).
        jsr arrow_hit_test
        bcc .not_arrow
        ldx #REPEAT_DELAY
        stx arrow_rep
.arrow_action
        cmp #0
        bne .arrow_down
        jmp .cursor_up
.arrow_down
        jmp .cursor_down
.not_arrow
        jsr palette_hit_test
        bcc .list_click
        cmp #AVAILABLE_COMMANDS
        bcc .palette_valid
        rts
.palette_valid
        sta selected_command
        lda selection_active
        beq .insert_mouse
        lda selected_command
        sta selection_target
        jsr editor_cancel_selection
        lda selection_target
        jsr editor_insert
        rts
.insert_mouse
        lda selected_command
        jsr editor_insert
        rts
.list_click
        jsr list_hit_test
        bcs .list_hit_valid
        rts
.list_hit_valid
        sta selection_target
        lda selection_active
        beq .select_saved
        jsr editor_cancel_selection
        jsr list_hit_test
        bcs .list_hit_after_cancel
        rts
.list_hit_after_cancel
.select_mouse
        jsr editor_select_item
        rts
.select_saved
        lda selection_target
        jsr editor_select_item
        rts
.keyboard
        lda key_new
        cmp #$FF
        bne .has_key
        rts
.has_key
        cmp #23                 ; X key
        bne .not_exit_key
        jmp editor_request_exit
.not_exit_key
        cmp #17                 ; R key (with or without Shift): run plan
        bne .not_run_key
        ldx key_repeat
        bne .not_run_key
        jmp editor_run_plan
.not_run_key
        ldx #8                  ; digit keys 1..9 switch the level
.digit  cmp level_key_codes,x
        bne .next_digit
        jmp editor_level_key    ; X = level index
.next_digit
        dex
        bpl .digit
        cmp #KEY_CLR_HOME
        bne .not_clear_program
        lda key_shift
        beq .not_clear_program
        lda key_repeat
        bne .not_clear_program
        jmp editor_request_clear
.not_clear_program
        cmp #57                 ; physical left-arrow key, immediately left of 1
        bne .not_left_cancel
        jmp .cancel             ; cancel is handled before any cursor movement
.not_left_cancel
        cmp #7                  ; C64 cursor up/down key
        bne .other_key
        lda key_shift           ; Shift selects cursor up; unshifted selects down
        bne .shifted_cursor_up
        jmp .cursor_down
.shifted_cursor_up
        jmp .cursor_up
.other_key
        lda selection_active
        beq .not_selected
        lda key_new
        bne .not_delete
        jmp .delete
.not_delete
        cmp #1                  ; Return
        bne .not_return
        jmp .confirm
.not_return
        lda key_shift
        bne .upper_select
        rts                     ; only uppercase letters select list rows
.upper_select
        lda key_repeat
        beq .not_repeat_select
        rts
.not_repeat_select
        lda key_new
        jsr key_to_palette
        bcs .active_key_valid
        rts
.active_key_valid
        sta selection_target
        jsr editor_cancel_selection
        lda selection_target
        clc
        adc scroll_offset
        cmp editor_count
        bcc .active_row_valid
        rts
.active_row_valid
        jsr editor_select_item
        rts
.not_selected
        lda key_shift
        beq .palette_key
        lda key_repeat
        beq .first_upper_press
        rts
.first_upper_press
        lda key_new
        jsr key_to_palette
        bcs .upper_key_valid
        rts
.upper_key_valid
        clc
        adc scroll_offset
        cmp editor_count
        bcc .row_valid
        rts
.row_valid
        jsr editor_select_item
        rts
.palette_key
        lda key_repeat
        beq .first_palette_press
        rts
.first_palette_press
        lda key_new
        jsr key_to_palette
        bcs .palette_key_valid
        rts
.palette_key_valid
        jsr editor_insert
        rts
.cursor_up
        lda selection_active
        beq .insert_up
        lda delete_pending
        bne .done
        jmp .selected_up
.insert_up
        lda insert_pos
        beq .done
        dec insert_pos
        jsr editor_move_insert_marker
        rts
.selected_up
        jsr editor_move_selected_up
        rts
.cursor_down
        lda selection_active
        beq .insert_down
        lda delete_pending
        bne .done
        jmp .selected_down
.insert_down
        lda insert_pos
        cmp editor_count
        bcs .done
        inc insert_pos
        jsr editor_move_insert_marker
        rts
.selected_down
        jsr editor_move_selected_down
        rts
.delete
        lda key_repeat
        bne .done
        lda #1
        sta delete_pending
        jsr editor_show_selection_help
        rts
.confirm
        lda key_repeat
        bne .done
        lda delete_pending
        beq .confirm_move
        jsr editor_delete_selected
        rts
.confirm_move
        lda #0
        sta selection_active
        sta delete_pending
        jsr editor_refresh_after_leave
        lda #$FF
        jsr editor_draw_info
        rts
.cancel
        lda key_repeat
        bne .done
        jsr editor_cancel_selection
.done   rts

; R: switch to the run screen. Ignored while a list move/delete is pending
; (Return confirms, left arrow cancels). Comes back here after P.
!zone editor_run_plan
editor_run_plan
        lda selection_active
        bne .done
        jsr run_mode
        lda #$FF
        sta hover_command
        jsr editor_calc_scroll  ; keep the insertion marker in view
        sta scroll_offset
        jsr draw_planning_screen
        jsr draw_program_list
        jsr draw_program_counts
        jsr spr_init            ; clear_screen wiped the sprite pointers
.done   rts

; Pointer over a scrollbar arrow? Carry set and A = 0 (up) / 1 (down) if so.
; Up arrow: column 38, row 1 (y 8..15); down arrow: column 38, row 19 (y 152..159).
!zone arrow_hit_test
arrow_hit_test
        lda mouse_x_hi
        cmp #1
        bne .miss
        lda mouse_x_lo
        cmp #48
        bcc .miss
        cmp #56
        bcs .miss
        lda mouse_y
        cmp #8
        bcc .miss
        cmp #16
        bcc .up
        cmp #152
        bcc .miss
        cmp #160
        bcs .miss
        lda #1
        sec
        rts
.up     lda #0
        sec
        rts
.miss   clc
        rts

; Keyboard matrix codes of the digit keys 1..9 = levels 1..9.
level_key_codes
        !byte 56, 59, 8, 11, 16, 19, 24, 27, 32

; X = level index (0..8). Not while a list entry is being moved or deleted.
!zone editor_level_key
editor_level_key
        lda selection_active
        bne .done
        lda key_repeat
        bne .done
        txa
        cmp #plan_level_count
        bcs .done
        cmp level_no
        beq .done
        jsr load_plan_level
        lda #$FF
        sta hover_command
        jsr draw_title_and_counters
        jsr draw_map_objects
        lda #$FF
        jsr editor_draw_info
.done   rts

!zone editor_request_exit
editor_request_exit
        lda key_repeat
        bne .finish
        lda #1
        sta exit_confirm
        lda #$FF                ; drop any palette hover help
        sta hover_command
        jsr editor_draw_info
        jsr editor_clear_palette_interior
        ldx #4
        ldy #16
        jsr set_cursor
        lda #<str_quit_confirm
        ldx #>str_quit_confirm
        jsr put_str
        lda #COL_YELLOW
        sta cur_col
        ldx #3
        ldy #18
        jsr set_cursor
        lda #<str_quit_yes
        ldx #>str_quit_yes
        jsr put_str
        ldx #12
        ldy #18
        jsr set_cursor
        lda #<str_quit_no
        ldx #>str_quit_no
        jsr put_str
.finish rts

!zone editor_request_clear
editor_request_clear
        lda key_repeat
        bne .finish
        lda #2
        sta exit_confirm
        lda #$FF                ; drop any palette hover help
        sta hover_command
        jsr editor_draw_info
        jsr editor_clear_palette_interior
        ldx #4
        ldy #16
        jsr set_cursor
        lda #<str_clear_confirm
        ldx #>str_clear_confirm
        jsr put_str
        ldx #4
        ldy #17
        jsr set_cursor
        lda #<str_clear_confirm2
        ldx #>str_clear_confirm2
        jsr put_str
        lda #COL_YELLOW
        sta cur_col
        ldx #3
        ldy #18
        jsr set_cursor
        lda #<str_quit_yes
        ldx #>str_quit_yes
        jsr put_str
        ldx #12
        ldy #18
        jsr set_cursor
        lda #<str_quit_no
        ldx #>str_quit_no
        jsr put_str
.finish rts

!zone editor_handle_exit_confirm
editor_handle_exit_confirm
        lda mouse_click
        beq .keyboard
        jsr palette_hit_test
        bcc .check_buttons
        cmp #9
        bcc .check_buttons
        cmp #18
        bcs .check_buttons
        cmp #13
        bcc .yes
        jmp .no
.check_buttons
        lda mouse_y
        cmp #144
        bcc .keyboard
        cmp #160
        bcs .keyboard
        lda mouse_x_hi
        bne .keyboard
        lda mouse_x_lo
        cmp #48
        bcc .keyboard
        cmp #104
        bcc .yes
        cmp #160
        bcc .no
.keyboard
        lda key_new
        cmp #$FF
        beq .finish
        cmp #1                  ; Return selects Yes
        beq .yes
        cmp #57                 ; Left-arrow cancels
        beq .no
.finish rts
.yes
        lda exit_confirm
        cmp #2
        bne .exit_yes
        jmp editor_clear_program
.exit_yes
        jmp system_reset
.no
        lda #0
        sta exit_confirm
        jsr editor_clear_palette_interior
        jsr draw_palette_panel
        lda #$FF
        jsr editor_draw_info
        rts

!zone editor_clear_palette_interior
editor_clear_palette_interior
        lda #COL_WHITE
        sta cur_col
        lda #14
        sta ui_row
.clear_rows
        ldx #1
        ldy ui_row
        jsr set_cursor
        lda #19
        sta ui_count
.clear_row
        lda #$20
        jsr put_char
        dec ui_count
        bne .clear_row
        inc ui_row
        lda ui_row
        cmp #20
        bne .clear_rows
        rts

; Return palette index in A and carry set when the pointer is over an entry.
!zone palette_hit_test
palette_hit_test
        lda mouse_y
        cmp #112                ; first palette row starts at screen row 14
        bcc .miss
        cmp #160                ; include the label row under both icon rows
        bcs .miss
        cmp #136
        bcc .top_row
        lda #9
        bne .row_ready
.top_row
        lda #0
.row_ready
        sta selected_command
        lda mouse_x_hi
        bne .miss
        lda mouse_x_lo
        cmp #8                  ; first tile starts in column 1
        bcc .miss
        cmp #152                ; nine 16-pixel palette slots
        bcs .miss
        sec
        sbc #8
        lsr
        lsr
        lsr
        lsr                     ; (x - 8) / 16
        clc
        adc selected_command
        sec
        rts
.miss   clc
        rts

; Return the absolute command index under the pointer, if an occupied list row
; is clicked. The row label, command text, and empty interior all select it.
!zone list_hit_test
list_hit_test
        lda mouse_x_hi
        beq .x_low
        cmp #1
        bne .miss
        lda mouse_x_lo
        cmp #48                 ; 256..303, stop before column 38
        bcs .miss
        jmp .y_test
.x_low  lda mouse_x_lo
        cmp #184                ; left edge of program panel, column 23
        bcc .miss
.y_test
        lda mouse_y
        cmp #16                 ; first program row, screen row 2
        bcc .miss
        cmp #152                ; last program row ends at screen row 18
        bcs .miss
        sec
        sbc #16
        lsr
        lsr
        lsr                     ; (y - 16) / 8 -> visible row
        clc
        adc scroll_offset
        cmp editor_count
        bcs .miss
        sec
        rts
.miss   clc
        rts

; Translate C64 keyboard-matrix codes for A through R to palette indexes.
!zone key_to_palette
key_to_palette
        sta selected_command
        ldx #0
.scan   lda palette_key_codes,x
        cmp selected_command
        beq .found
        inx
        cpx #PALETTE_NUM
        bne .scan
        clc
        rts
.found  txa
        sec
        rts

!zone editor_insert
editor_insert                  ; A = command index (0..6)
        cmp #AVAILABLE_COMMANDS
        bcs .done
        sta selected_command
        lda editor_count
        cmp #PROGRAM_MAX
        bcs .done
        tax                      ; shift existing entries right from the end
.shift  cpx insert_pos
        beq .store
        dex
        lda program,x
        sta program+1,x
        jmp .shift
.store  ldx insert_pos
        lda selected_command
        sta program,x
        inc editor_count
        inc insert_pos
        jsr editor_update_view
        lda #$FF
        sta hover_command
        lda selected_command
        jsr editor_draw_info
.done   rts

!zone editor_move_insert_marker
editor_move_insert_marker
        ; The VIC sprite follows insert_pos each frame. Redraw the list only
        ; when the marker leaves the visible window and the list must scroll.
        jsr editor_calc_scroll
        cmp scroll_offset
        beq .done
        sta scroll_offset
        jsr draw_program_list
        jsr draw_scrollbar
.done   rts

!zone editor_update_view
editor_update_view
        ; Keep the insertion marker in the visible list rows (2..19).
        jsr editor_calc_scroll
        sta scroll_offset
        jsr draw_program_list
        jsr draw_program_counts
        jsr draw_scrollbar
        rts

; Return in A the scroll offset that keeps the insertion marker visible
; (marker row = insert_pos - scroll_offset, valid 0..PROGRAM_ROWS-1) while
; moving the window as little as possible. Clamped so the window does not
; scroll past the end of the list after deletions.
!zone editor_calc_scroll
editor_calc_scroll
        lda insert_pos
        cmp scroll_offset
        bcc .clamp              ; marker above window: scroll up to it
        sec
        sbc scroll_offset
        cmp #PROGRAM_ROWS
        bcc .keep               ; marker inside window: no scrolling
        lda insert_pos
        sec
        sbc #PROGRAM_ROWS-1     ; marker below window: put it on last row
        jmp .clamp
.keep   lda scroll_offset
.clamp  sta tmp2
        lda editor_count
        sec
        sbc #PROGRAM_ROWS-1     ; max offset = editor_count - 17, at least 0
        bcs .max_ok
        lda #0
.max_ok cmp tmp2
        bcs .use_wanted
        rts                     ; wanted offset too large: use maximum
.use_wanted
        lda tmp2
        rts

!zone editor_select_item
editor_select_item              ; A = absolute program index
        cmp editor_count
        bcs .done
        sta selected_index
        sta selection_origin
        lda #1
        sta selection_active
        lda #0
        sta delete_pending
        ldx #$FF
        jsr editor_update_selection_view
        jsr editor_show_selection_help
.done   rts

; X = second absolute row that changed (swap partner), or $FF. Redraws the
; whole list only when the window has to scroll; otherwise just those rows.
!zone editor_update_selection_view
editor_update_selection_view
        stx refresh_other
        lda selected_index
        cmp scroll_offset
        bcs .check_bottom
        sta scroll_offset
        jmp .redraw
.check_bottom
        sec
        sbc scroll_offset
        cmp #PROGRAM_ROWS
        bcc .rows_only
        lda selected_index
        sec
        sbc #PROGRAM_ROWS-1     ; keep selected row at bottom of viewport
        sta scroll_offset
.redraw jsr draw_program_list
        jsr draw_program_counts
        jsr draw_scrollbar
        rts
.rows_only
        lda selected_index
        jsr draw_program_row
        lda refresh_other
        cmp #$FF
        beq .done
        jsr draw_program_row
.done   rts

; After leaving selection mode (selection_active already 0): redraw only the
; formerly selected row, unless the insertion marker forces a scroll.
!zone editor_refresh_after_leave
editor_refresh_after_leave
        jsr editor_calc_scroll
        cmp scroll_offset
        bne .full
        lda selected_index
        jmp draw_program_row
.full   jmp editor_update_view

!zone editor_show_selection_help
editor_show_selection_help
        lda delete_pending
        beq .move_help
        lda #<str_delete_help
        ldx #>str_delete_help
        jmp editor_draw_message
.move_help
        lda #<str_select_help
        ldx #>str_select_help
        jmp editor_draw_message

!zone editor_move_selected_up
editor_move_selected_up
        lda selected_index
        beq .done
        jsr editor_swap_selected_up
        ldx selected_index
        inx                     ; swap partner is the row below
        jsr editor_update_selection_view
        jsr editor_show_selection_help
.done   rts

!zone editor_move_selected_down
editor_move_selected_down
        ldx selected_index
        inx
        cpx editor_count
        bcs .done
        jsr editor_swap_selected_down
        ldx selected_index
        dex                     ; swap partner is the row above
        jsr editor_update_selection_view
        jsr editor_show_selection_help
.done   rts

!zone editor_swap_selected_up
editor_swap_selected_up
        ldx selected_index
        lda program,x
        sta move_temp
        dex
        lda program,x
        inx
        sta program,x
        dex
        lda move_temp
        sta program,x
        dec selected_index
        rts

!zone editor_swap_selected_down
editor_swap_selected_down
        ldx selected_index
        lda program,x
        sta move_temp
        inx
        lda program,x
        sta tmp0
        dex
        lda tmp0
        sta program,x
        inx
        lda move_temp
        sta program,x
        inc selected_index
        rts

!zone editor_cancel_selection
editor_cancel_selection
        lda selection_active
        beq .done
        lda selected_index
        sta refresh_other       ; position before rolling back
.rollback
        lda selected_index
        cmp selection_origin
        beq .restored
        bcc .move_down
        jsr editor_swap_selected_up
        jmp .rollback
.move_down
        jsr editor_swap_selected_down
        jmp .rollback
.restored
        lda #0
        sta selection_active
        sta delete_pending
        lda selected_index
        cmp refresh_other
        beq .single
        jsr editor_update_view  ; rows between were reordered
        jmp .info
.single jsr editor_refresh_after_leave
.info   lda #$FF
        jsr editor_draw_info
.done   rts

!zone editor_delete_selected
editor_delete_selected
        ldx selected_index
.shift  inx
        cpx editor_count
        bcs .deleted
        lda program,x
        dex
        sta program,x
        inx
        jmp .shift
.deleted
        dec editor_count
        lda selected_index
        cmp insert_pos
        bcs .marker_ok
        dec insert_pos
.marker_ok
        lda insert_pos
        cmp editor_count
        bcc .clear_state
        sta insert_pos
        lda editor_count
        sta insert_pos
.clear_state
        lda #0
        sta selection_active
        sta delete_pending
        jsr editor_update_view
        lda #$FF
        jsr editor_draw_info
        rts

!zone draw_planning_screen
draw_planning_screen
        jsr clear_screen
        lda #COL_WHITE
        sta cur_col
        jsr draw_title_and_counters
        jsr draw_map_panel
        jsr draw_palette_panel
        jsr draw_program_panel
        jsr draw_help_areas
        rts

!zone draw_title_and_counters
draw_title_and_counters
        lda #COL_WHITE
        sta cur_col
        ldx #0
        ldy #0
        jsr set_cursor
        lda level_no            ; patch the level digit into the title
        clc
        adc #$31
        sta str_title_lvl
        lda #<str_title
        ldx #>str_title
        jsr put_str

        rts

!zone draw_map_panel
draw_map_panel
        ; Window: columns 0..MAP_COLS+1, rows 1..MAP_ROWS+2 around the field
        ; (same rounded frame as the run screen, see draw_window in run.asm).
        lda #COL_WHITE
        sta cur_col
        lda #MAP_COLS+2
        sta win_w
        ldx #0
        ldy #MAP_SCR_Y-1
        lda #MAP_ROWS+2
        jsr draw_window
        ; Level layer, goal, package, blockers and robot.
        jmp draw_map_objects

!zone draw_palette_panel
draw_palette_panel
        ; Window: columns 0..20, rows 13..20.
        lda #COL_WHITE
        sta cur_col
        lda #21
        sta win_w
        ldx #0
        ldy #13
        lda #8
        jsr draw_window
        ldx #0
        stx ui_index
.icons jsr draw_palette_icon
        inc ui_index
        lda ui_index
        cmp #PALETTE_NUM
        bne .icons
        rts

!zone draw_palette_icon
draw_palette_icon
        ; 18 two-by-two command tiles, nine per row.
        lda ui_index
        cmp #AVAILABLE_COMMANDS
        bcc .active
        rts
.active
        lda ui_index
        cmp #9
        bcc .first
        sec
        sbc #9
        sta ui_col
        lda #17
        sta ui_row
        jmp .position
.first sta ui_col
        lda #14
        sta ui_row
.position
        lda ui_col
        asl
        clc
        adc #1
        sta tmp0                 ; tile start column
        lda #COL_WHITE
        sta cur_col
        ; Each palette tile uses four glyphs from the inverse charset range.
        ldx ui_index
        lda palette_icon_ids,x
        cmp #$FF
        beq .key_label
        asl
        asl
        clc
        adc #ICON_CHAR_BASE
        tax
        stx tmp1                 ; icon table offset
        ldx tmp0
        ldy ui_row
        jsr set_cursor
        lda tmp1
        jsr put_char
        ldx tmp0
        inx
        ldy ui_row
        jsr set_cursor
        lda tmp1
        clc
        adc #1
        jsr put_char
        ldx tmp0
        ldy ui_row
        iny
        jsr set_cursor
        lda tmp1
        clc
        adc #2
        jsr put_char
        ldx tmp0
        inx
        ldy ui_row
        iny
        jsr set_cursor
        lda tmp1
        clc
        adc #3
        jsr put_char
        ; A-R key labels below the 2x2 icon.
.key_label
        ldx tmp0
        lda ui_row
        clc
        adc #2
        tay
        jsr set_cursor
        lda ui_index
        clc
        adc #1
        jsr put_char
        rts

!zone draw_program_panel
draw_program_panel
        ; Window: columns 22..39, rows 1..19 (header and arrows sit in its edges).
        lda #COL_WHITE
        sta cur_col
        lda #18
        sta win_w
        ldx #22
        ldy #1
        lda #19
        jsr draw_window
        ; Keep the scrollbar arrows in the list header.
        lda #COL_WHITE
        sta cur_col
        ldx #23
        ldy #1
        jsr set_cursor
        lda #<str_program_count
        ldx #>str_program_count
        jsr put_str

        ldx #38
        ldy #1
        jsr set_cursor
        lda #ICON_CHAR_BASE+28   ; custom scrollbar up arrow ($FC)
        jsr put_char
        ldx #38
        ldy #19
        jsr set_cursor
        lda #ICON_CHAR_BASE+29   ; custom scrollbar down arrow ($FD)
        jsr put_char
        jsr draw_scrollbar
        rts

!zone draw_short_name
draw_short_name
        asl
        tax
        lda short_name_ptrs,x
        sta tmp0
        lda short_name_ptrs+1,x
        tax
        lda tmp0
        jmp put_str

; Redraw 17 visible rows as "A 01 Text". Letters select visible rows; numbers
; are absolute command positions (01-99).
!zone draw_program_list
draw_program_list
        lda #0
        sta ui_index
.all    jsr draw_list_row
        inc ui_index
        lda ui_index
        cmp #PROGRAM_ROWS
        bne .all
        rts

; A = absolute command index: redraw just that row if it is visible.
!zone draw_program_row
draw_program_row
        sec
        sbc scroll_offset
        bcc .hidden
        cmp #PROGRAM_ROWS
        bcs .hidden
        sta ui_index
        jmp draw_list_row
.hidden rts

; Draw visible list row ui_index (0..PROGRAM_ROWS-1).
!zone draw_list_row
draw_list_row
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
        bcs .next
        lda #COL_WHITE
        sta cur_col
        lda selection_active
        beq .number
        lda tmp0
        cmp selected_index
        bne .number
        lda #COL_YELLOW
        sta cur_col
.number ldx #23
        ldy ui_row
        jsr set_cursor
        lda ui_index
        clc
        adc #$41                ; A-R selects the corresponding visible row
        jsr put_char
        ldx #25
        ldy ui_row
        jsr set_cursor
        lda tmp0
        clc
        adc #1                  ; display one-based running number
        jsr draw_decimal2
        ldx #28
        ldy ui_row
        jsr set_cursor
        ldx tmp0
        lda program,x
        jsr draw_short_name
.next   rts


!zone draw_program_counts
draw_program_counts
        lda #COL_WHITE
        sta cur_col
        ldx #33
        ldy #1
        jsr set_cursor
        lda editor_count
        jsr draw_decimal2
        rts
!zone draw_decimal2
draw_decimal2                   ; A = 0..99, writes two decimal digits
        sta tmp1
        ldx #0
.tens   lda tmp1
        cmp #10
        bcc .digits
        sec
        sbc #10
        sta tmp1
        inx
        jmp .tens
.digits txa
        clc
        adc #$30
        jsr put_char
        lda tmp1
        clc
        adc #$30
        jmp put_char
!zone draw_scrollbar
draw_scrollbar
        lda #COL_CYAN
        sta cur_col
        lda #2
        sta ui_row
.track ldx #38
        ldy ui_row
        jsr set_cursor
        lda #$7C
        jsr put_char
        inc ui_row
        lda ui_row
        cmp #19
        bne .track

        ; Thumb: row = scroll_offset * 16 / (editor_count - 17), 0..16.
        ; With nothing to scroll the thumb rests on the top row.
        ldx #0
        lda editor_count
        sec
        sbc #PROGRAM_ROWS
        bcc .place
        beq .place
        sta tmp3                ; divisor = maximum scroll offset
        lda scroll_offset
        sta tmp1
        lda #0
        sta tmp2
        asl tmp1                ; * 16
        rol tmp2
        asl tmp1
        rol tmp2
        asl tmp1
        rol tmp2
        asl tmp1
        rol tmp2
.div    lda tmp2
        bne .sub
        lda tmp1
        cmp tmp3
        bcc .place
.sub    lda tmp1
        sec
        sbc tmp3
        sta tmp1
        lda tmp2
        sbc #0
        sta tmp2
        inx
        jmp .div
.place  txa
        cmp #PROGRAM_ROWS-1
        bcc .row_ok
        lda #PROGRAM_ROWS-1
.row_ok clc
        adc #2
        tay
        lda #COL_WHITE
        sta cur_col
        ldx #38
        jsr set_cursor
        lda #$A0                ; solid block
        jsr put_char
        rts

!zone draw_help_areas
draw_help_areas
        lda #<str_bottom_commands
        ldx #>str_bottom_commands
draw_help_areas_str             ; A/X = text for the bottom line (row 24)
        sta ptr1
        stx ptr1+1
        ; Info window: rows 21..23, text in row 22 (editor_draw_message).
        lda #COL_WHITE
        sta cur_col
        lda #40
        sta win_w
        ldx #0
        ldy #21
        lda #3
        jsr draw_window
        lda #COL_WHITE
        sta cur_col
        ldx #0
        ldy #24
        jsr set_cursor
        lda ptr1
        ldx ptr1+1
        jsr put_str
        lda #$FF
        jsr editor_draw_info
        rts

!zone editor_update_hover
editor_update_hover
        lda selection_active
        bne .done
        lda exit_confirm        ; palette hidden by quit/clear confirmation
        bne .done
        jsr palette_hit_test
        bcc .map
        cmp #AVAILABLE_COMMANDS
        bcc .changed
        lda #$FF
        bne .changed
.map    jsr map_hover_code      ; $FF or field object code
.changed
        cmp hover_command
        beq .done
        sta hover_command
        jsr editor_draw_info
.done   rts

!zone editor_draw_info
editor_draw_info                ; A = command index, or $FF to clear
        sta selected_command
        jsr editor_clear_info
        lda selected_command
        cmp #$50
        bcc .palette_text
        cmp #$FF
        beq .done
        jmp draw_map_info
.palette_text
        cmp #AVAILABLE_COMMANDS
        bcs .done
        ldx #1
        ldy #22
        jsr set_cursor
        lda selected_command
        jsr draw_short_name
.done   rts

!zone editor_draw_message
editor_draw_message             ; A/X = 0-terminated message address
        sta ptr2
        stx ptr2+1
        jsr editor_clear_info
        ldx #1
        ldy #22
        jsr set_cursor
        lda ptr2
        ldx ptr2+1
        jmp put_str

!zone editor_clear_info
editor_clear_info
        lda #COL_WHITE
        sta cur_col
        ldx #1
        ldy #22
        jsr set_cursor
        lda #38
        sta ui_count
.clear  lda #$20
        jsr put_char
        dec ui_count
        bne .clear
        rts

; Seven implemented commands; later palette positions remain empty.
palette_icon_ids
        !byte 0,1,2,3,4,5,6,$FF,$FF,$FF,$FF,$FF
        !byte $FF,$FF,$FF,$FF,$FF,$FF

palette_key_codes            ; C64 keyboard matrix positions for A-R
        !byte 10,28,20,18,14,21,26,29,33,34,37,42,36,39,38,41,62,17

short_name_ptrs
        !word short_forward,short_backward,short_turn_right,short_turn_left
        !word short_pick_up,short_drop_off,short_turn_180
short_pick_up !text "Pick Up",0
short_drop_off !text "Drop Off",0
short_forward !text "Move Fwd",0
short_backward !text "Move Back",0
short_turn_right !text "Turn Right",0
short_turn_left !text "Turn Left",0
short_turn_180 !text "Turn 180",0
