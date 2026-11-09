; editor.asm - Planning screen and command-list editing.

ui_index = $29
ui_row   = $2A
ui_save  = $2B
ui_count = $2C
ui_col   = $2D
; $2E is mouse_raw_x in zp.inc; keep this state in an unused zero-page slot.
exit_confirm = $43
arrow_rep = $61              ; auto-repeat counter for scrollbar arrow clicks
AVAILABLE_COMMANDS = 9

!zone game_main
game_main
        jsr input_init
        jsr editor_init
        jsr world_init
        jmp title_mode          ; title screen; "Start New Game" opens the world map

; Planning screen for level_no (called from the world map). Returns when the
; player goes back to the map: F7 here, or Space after a won level.
!zone plan_mode
plan_mode
        lda #0
        sta run_snap_ok         ; a new visit: no old run to look at
        sta plan_exit
        sta run_to_map
        sta selection_active
        sta delete_pending
        sta exit_confirm
        lda #$FF
        sta hover_command
        lda level_no
        jsr load_plan_level
        jsr editor_calc_scroll  ; keep the insertion marker in view
        sta scroll_offset
        jsr draw_planning_screen
        jsr draw_program_list
        jsr draw_program_counts
        jsr spr_init
.loop   jsr wait_frame
        jsr input_update
        jsr editor_update_hover
        jsr editor_handle_input
        lda plan_exit
        bne .leave
        jsr spr_update
        jmp .loop
.leave  jsr gfx_sprites_off
        rts

; F7: back to the world map (not while a list move/delete is pending).
!zone editor_to_map
editor_to_map
        lda selection_active
        bne .done
        lda key_repeat
        bne .done
        lda #1
        sta plan_exit
.done   rts

!zone editor_init
editor_init
        lda #0
        sta run_snap_ok
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
; Return selects the command directly above the insertion marker (the first
; command if the marker is above it); letters are case-insensitive.
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
        jsr plan_hit_footer     ; view: bottom line "F1:Run F7:Map F8:Title"
        bcc .palette_click
        cmp #1
        bcc .run_click
        beq .map_click
        jmp editor_request_exit
.map_click
        jmp editor_to_map
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
        cmp #KEY_F7             ; F7: world map, F8 (= Shift+F7): back to title (X is Turn 180)
        bne .not_exit_key
        ldx key_shift
        bne .exit_key
        jmp editor_to_map
.exit_key
        jmp editor_request_exit
.not_exit_key
        cmp #KEY_F1             ; F1 (unshifted): switch to the run screen
        bne .not_f1
        ldx key_repeat
        bne .not_f1
        ldx key_shift
        bne .not_f1
        jmp editor_run_plan
.not_f1
!if VIEW_UNIFIED {
        cmp #KEY_SPACE          ; shared plan/run screen: Space runs the plan right away
        bne +
        ldx key_repeat
        bne +
        jmp editor_run_plan
+
}
        cmp #17                 ; R key (with or without Shift): run plan
        bne .not_run_key
        ldx key_repeat
        bne .not_run_key
        jmp editor_run_plan
.not_run_key
        ldx #8                  ; digit keys 1..9 switch the level inside the world
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
        lda key_new             ; while a row is grabbed Del does nothing
        cmp #1                  ; Return
        bne .not_return
        jmp .confirm
.not_return
        rts
.not_selected
        lda key_new
        cmp #1                  ; Return: grab the command above the marker
        beq .pick_row
        cmp #0                  ; Del: delete it (asks first)
        bne .palette_key
.pick_row
        lda key_repeat
        bne .no_select
        lda editor_count
        beq .no_select
        lda insert_pos
        beq .select_row         ; marker above the first command: take it
        sec
        sbc #1
.select_row
        jsr editor_select_item
        lda key_new
        bne .no_select          ; Return: just grabbed
        lda #1                  ; Del: ask "Return:delete / <-:keep"
        sta delete_pending
        jsr editor_show_selection_help
.no_select
        rts
.palette_key
        lda key_repeat
        beq .first_palette_press
        rts
.first_palette_press
        lda key_new
        jsr key_to_command
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
!if VIEW_UNIFIED {
        lda #1                  ; same screen: no "ready" stop, start at once
        sta run_autostart
}
        jsr run_mode
        lda run_to_map          ; won level left with Space: back to the world map
        beq .stay
        lda #1
        sta plan_exit
        rts
.stay   lda #$FF
        sta hover_command
        jsr editor_calc_scroll  ; keep the insertion marker in view
        sta scroll_offset
        jsr draw_planning_screen
        jsr draw_program_list
        jsr draw_program_counts
        jsr spr_init            ; clear_screen wiped the sprite pointers
!if VIEW_UNIFIED {
        lda run_redo            ; the run ended because of an edit: do that edit now
        beq .done
        lda #0
        sta run_redo
        jmp editor_handle_input
}
.done   rts

; Keyboard matrix codes of the digit keys 1..9 = levels 1..9 of the current world.
level_key_codes
        !byte 56, 59, 8, 11, 16, 19, 24, 27, 32

; X = level index inside the world (0..8). Not while a list entry is being
; moved or deleted. The command list is kept.
!zone editor_level_key
editor_level_key
        lda selection_active
        bne .done
        lda key_repeat
        bne .done
        cpx world_nlev
        bcs .done
        txa
        clc
        adc world_first
        cmp level_no
        beq .done
        sta last_level
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
        jsr plan_draw_quit_confirm  ; view: question in the palette window
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
        jsr plan_draw_clear_confirm ; view: question in the palette window
.finish rts

!zone editor_handle_exit_confirm
editor_handle_exit_confirm
        lda mouse_click
        beq .keyboard
        jsr plan_hit_confirm    ; view: carry set, A = 0 yes / 1 no
        bcc .keyboard
        cmp #1
        bcc .yes
        jmp .no
.keyboard
        lda key_new
        cmp #$FF
        beq .finish
        cmp #1                  ; Return or Y selects Yes
        beq .yes
        cmp #KEY_Y
        beq .yes
        cmp #KEY_N              ; N or Left-arrow cancels
        beq .no
        cmp #57
        beq .no
.finish rts
.yes
        lda exit_confirm
        cmp #2
        bne .exit_yes
        jmp editor_clear_program
.exit_yes
        jmp title_return
.no
        lda #0
        sta exit_confirm
        jsr editor_clear_palette_interior
        jsr draw_palette_panel
        lda #$FF
        jsr editor_draw_info
        rts

!zone editor_insert
editor_insert                  ; A = command index (0..AVAILABLE_COMMANDS-1)
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
        jmp editor_draw_message2
.move_help
        lda #<str_select_help
        ldx #>str_select_help
        jmp editor_draw_message2

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

cmd_key_codes !byte 9, 13, 18, 10, 62, 14, 23, 12, 20 ; keyboard matrix codes of those keys
; A = matrix code -> command index (carry set) for the palette keys Q W E A S D X.
!zone key_to_command
key_to_command
        sta tmp0
        ldx #0
.scan   lda cmd_key_codes,x
        cmp tmp0
        beq .found
        inx
        cpx #AVAILABLE_COMMANDS
        bne .scan
        clc
        rts
.found  txa
        sec
        rts
