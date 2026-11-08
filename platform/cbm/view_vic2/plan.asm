; plan.asm (VIC-II-View) - Planungsbildschirm: Karte, Legende, Befehlspalette, Programmliste,
; Scrollbalken, Hilfe- und Infotexte, Rueckfragen, Treffertests der Maus.
; Logik (Befehlsliste bearbeiten, Tasten, Ablauf): src/editor.asm.

PROGRAM_ROWS = 17               ; visible program rows (the logic scrolls by this)
MAP_SCR_X   = 1             ; screen column of field tile (0,0)
MAP_SCR_Y   = 2             ; screen row of field tile (0,0)
; --- Info window (right half, under the command list): two text rows
INFO_X      = 23            ; first text column
INFO_Y      = 21            ; first text row (second row = INFO_Y+1)
INFO_W      = 16            ; characters per row

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
        cmp #23
        bne .clear_rows
        rts

; Pointer over a palette icon (or its key label)? Carry set and A = command
; index if so. The icons form a 3x3 grid (see pal_grid_cmd): 16 px wide, pitch
; 40 px from x = 32; three character rows (24 px) per grid row from y = 112.
!zone palette_hit_test
palette_hit_test
        lda mouse_x_hi
        bne .miss
        lda mouse_x_lo
        sec
        sbc #32                 ; first icon starts in column 4
        bcc .miss
        ldx #0
.col    cmp #16                 ; inside a 2-character icon?
        bcc .col_ok
        cmp #40                 ; icon pitch is 5 characters
        bcc .miss
        sbc #40
        inx
        cpx #3
        bcc .col
        bcs .miss
.col_ok stx tmp0                ; grid column
        lda mouse_y
        sec
        sbc #112                ; first palette row = screen row 14
        bcc .miss
        ldx #0
.row    cmp #24
        bcc .row_ok
        sbc #24
        inx
        cpx #3
        bcc .row
        bcs .miss
.row_ok stx tmp1                ; grid row
        txa
        asl
        clc
        adc tmp1                ; row * 3
        clc
        adc tmp0
        tax
        lda pal_grid_cmd,x
        cmp #$FF
        beq .miss
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
        lda #$FF
        jmp editor_draw_info    ; idle help text in the info window

!zone draw_title_and_counters
draw_title_and_counters
        lda #COL_WHITE
        sta cur_col
        ldx #0
        ldy #0
        jsr set_cursor
        lda #<str_title         ; "ArtyBot - Plan - <world> <n>"
        ldx #>str_title
        jsr put_str
        jsr put_level_name
        lda #<str_title_pad
        ldx #>str_title_pad
        jsr put_str
        lda #COL_CYAN           ; colour the title parts
        sta cur_col
        ldx #0
        ldy #0
        jsr set_cursor
        lda #7
        jsr paint
        lda #COL_YELLOW
        sta cur_col
        ldx #10
        ldy #0
        jsr set_cursor
        lda #4
        jsr paint
        lda #COL_GREEN
        sta cur_col
        ldx #17
        ldy #0
        jsr set_cursor
        lda #16
        jsr paint
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
        jsr draw_map_objects
        jmp draw_legend

; Legend right of the field (columns LEG_X.., rows of the field): ArtyBot with its
; facing direction, then only the tile types that occur in the loaded level
; (grass is left out). Icon in column LEG_X, text from LEG_X+2 (8 characters).
LEG_X     = MAP_SCR_X + MAP_COLS + 1
LEG_COUNT = 8

!zone draw_legend
draw_legend
        lda #MAP_SCR_Y
        sta ui_row
        lda theme_plan_robot    ; ArtyBot, then "looking" / direction indented below
        sta cur_col
        ldx #LEG_X
        ldy ui_row
        jsr set_cursor
        lda robot_dir
        clc
        adc #ROBOT_CHAR_BASE
        jsr put_char
        lda #COL_WHITE
        sta cur_col
        ldx #LEG_X+2
        ldy ui_row
        jsr set_cursor
        lda #<str_leg_robot
        ldx #>str_leg_robot
        jsr put_str
        inc ui_row
        ldx #LEG_X+2
        ldy ui_row
        jsr set_cursor
        lda #<str_leg_looking
        ldx #>str_leg_looking
        jsr put_str
        inc ui_row
        ldx #LEG_X+3
        ldy ui_row
        jsr set_cursor
        lda robot_dir
        asl
        tax
        lda leg_dir_ptrs,x
        pha
        lda leg_dir_ptrs+1,x
        tax
        pla
        jsr put_str
        inc ui_row
        lda #0
        sta ui_index
.next   ldx ui_index
        cpx #LEG_COUNT
        beq .done
        lda leg_ids,x
        sta tmp0
        ldx #MAP_COLS*MAP_ROWS-1
.scan   lda map_work,x
        cmp tmp0
        beq .found
        dex
        bpl .scan
        inc ui_index            ; tile type not in this level
        jmp .next
.found  lda ui_row
        cmp #MAP_SCR_Y+MAP_ROWS
        bcs .done               ; out of room
        ldx tmp0
        lda map_tile_colors,x
        sta cur_col
        lda map_tile_chars,x
        pha
        ldx #LEG_X
        ldy ui_row
        jsr set_cursor
        pla
        jsr put_char
        lda #COL_WHITE
        sta cur_col
        ldx #LEG_X+2
        ldy ui_row
        jsr set_cursor
        lda ui_index
        asl
        tax
        lda leg_text,x
        pha
        lda leg_text+1,x
        tax
        pla
        jsr put_str
        inc ui_row
        inc ui_index
        jmp .next
.done   rts

leg_ids   !byte T_GOAL, T_BOX, T_WALL, T_WATER, T_ICE, T_KEY, T_LOCK, T_DOOR

leg_text  !word str_leg_goal, str_leg_box, str_leg_tree, str_leg_water
          !word str_leg_ice, str_leg_key, str_leg_lock, str_leg_door

leg_dir_ptrs !word str_leg_right, str_leg_left, str_leg_up, str_leg_down

!zone draw_palette_panel
draw_palette_panel
        ; Window: columns 0..20, rows 13..23 (3x3 grid of 2x2 icons, WASD layout).
        lda #COL_WHITE
        sta cur_col
        lda #21
        sta win_w
        ldx #0
        ldy #13
        lda #11
        jsr draw_window
        ldx #0
        stx ui_index
.icons jsr draw_palette_icon
        inc ui_index
        lda ui_index
        cmp #AVAILABLE_COMMANDS
        bne .icons
        rts

!zone draw_palette_icon
draw_palette_icon
        ; ui_index = command; pal_col/pal_row give the 2x2 tile position, the
        ; key label sits in the row below it.
        ldx ui_index
        cpx #AVAILABLE_COMMANDS
        bcc .active
        rts
.active lda pal_col,x
        sta tmp0                 ; tile start column
        lda pal_row,x
        sta ui_row               ; tile top row
        lda cmd_colors,x         ; icon colour by command type
        sta cur_col
        lda palette_icon_chars,x
        cmp #$FF
        beq .key_label
        sta tmp1                 ; first of the four icon glyphs
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
.key_label
        lda #COL_WHITE
        sta cur_col
        ldx tmp0
        lda ui_row
        clc
        adc #2
        tay
        jsr set_cursor
        ldx ui_index
        lda pal_label,x          ; lowercase key letter
        jmp put_char

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
        lda #COL_CYAN
        sta cur_col
        ldx #24
        ldy #1
        jsr set_cursor
        lda #8
        jsr paint
        lda #COL_WHITE
        sta cur_col

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

; Redraw 17 visible rows as "01 Text" (same columns as the run list). Numbers
; are absolute command positions (01-99); column 23 holds the insertion marker.
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
.number ldx #24
        ldy ui_row
        jsr set_cursor
        lda tmp0
        clc
        adc #1                  ; display one-based running number
        jsr draw_decimal2
        ldx #27
        ldy ui_row
        jsr set_cursor
        ldx tmp0
        lda program,x
        sta tmp1
        lda cur_col
        cmp #COL_YELLOW         ; selected row stays yellow
        beq .name
        ldx tmp1
        lda cmd_colors,x        ; otherwise colour by command type
        sta cur_col
.name   lda tmp1
        jsr draw_short_name
.next   rts

!zone draw_program_counts
draw_program_counts
        lda #COL_YELLOW
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
        lda #SOLID_CHAR         ; solid block
        jsr put_char
        rts

!zone draw_help_areas
draw_help_areas
        lda #<str_bottom_commands
        ldx #>str_bottom_commands

draw_help_areas_str             ; A/X = text for the bottom line (row 24)
        sta ptr1
        stx ptr1+1
        ; Info window: right half under the command list, columns 22..39, rows
        ; 20..23, two text rows (INFO_X / INFO_Y).
        lda #COL_WHITE
        sta cur_col
        lda #18
        sta win_w
        ldx #22
        ldy #20
        lda #4
        jsr draw_window
        lda #COL_WHITE
        sta cur_col
        ldx #0
        ldy #24
        jsr set_cursor
        lda ptr1
        ldx ptr1+1
        jsr put_str
        lda #COL_YELLOW         ; key names stand out
        sta cur_col
        ldx #0
        ldy #24
        jsr set_cursor
        lda #3
        jsr paint
        ldx #7
        ldy #24
        jsr set_cursor
        lda #3
        jsr paint
        ldx #14
        ldy #24
        jsr set_cursor
        lda #3
        jsr paint
        lda #$FF
        jsr editor_draw_info
        rts

!zone editor_draw_info
editor_draw_info                ; A = command index, or $FF to clear
        sta selected_command
        jsr editor_clear_info
        lda selected_command
        cmp #$50
        bcc .palette_text
        cmp #$FF
        beq .idle_help
        jmp draw_map_info
.idle_help                      ; nothing hovered: explain cursor keys and Return
        lda #COL_WHITE
        sta cur_col
        lda #<str_idle_help
        ldx #>str_idle_help
        jmp editor_draw_message2
.palette_text
        cmp #AVAILABLE_COMMANDS
        bcs .done
        ldx selected_command
        lda cmd_colors,x
        sta cur_col
        ldx #INFO_X
        ldy #INFO_Y
        jsr set_cursor
        lda selected_command
        jsr draw_short_name
.done   rts

!zone editor_draw_message
editor_draw_message             ; A/X = 0-terminated one-row message address
        sta ptr2
        stx ptr2+1
        jsr editor_clear_info
        ldx #INFO_X
        ldy #INFO_Y
        jsr set_cursor
        lda ptr2
        ldx ptr2+1
        jmp put_str

!zone editor_draw_message2
editor_draw_message2            ; A/X = two consecutive 0-terminated strings (two rows)
        sta ptr2
        stx ptr2+1
        jsr editor_clear_info
        ldx #INFO_X
        ldy #INFO_Y
        jsr set_cursor
        lda ptr2
        ldx ptr2+1
        jsr put_str             ; tmp3 = index of the terminator
        lda ptr2
        sec
        adc tmp3                ; + index + 1 = start of the second string
        sta ptr2
        bcc .second
        inc ptr2+1
.second ldx #INFO_X
        ldy #INFO_Y+1
        jsr set_cursor
        lda ptr2
        ldx ptr2+1
        jmp put_str

!zone editor_clear_info
editor_clear_info
        lda #COL_WHITE
        sta cur_col
        ldx #INFO_X
        ldy #INFO_Y
        jsr set_cursor
        lda #INFO_W
        sta ui_count
.clear  lda #$20
        jsr put_char
        dec ui_count
        bne .clear
        ldx #INFO_X
        ldy #INFO_Y+1
        jsr set_cursor
        lda #INFO_W
        sta ui_count
.clear2 lda #$20
        jsr put_char
        dec ui_count
        bne .clear2
        rts

; Palette layout, indexed by command (0 Fwd, 1 Back, 2 Right, 3 Left, 4 Pick, 5 Drop,
; 6 Turn180, 7 Jump, 8 Throw); WASD arrangement:
;                                   Q(pick)  W(fwd)   E(drop)
;                                   A(left)  S(back)  D(right)
;                                   Z(jump)  X(180)   C(throw)
pal_col  !byte 9, 9, 14, 4, 4, 14, 9, 4, 14

pal_row  !byte 14, 17, 17, 17, 14, 14, 20, 20, 20

pal_label !byte 23, 19, 4, 1, 17, 5, 24, 26, 3      ; screen codes: w s d a q e x z c

pal_grid_cmd                                  ; 3x3 grid, row-major, $FF = empty cell
        !byte 4, 0, 5
        !byte 3, 1, 2
        !byte 7, 6, 8

; Colour per command type: moves (incl. jump) white, turns cyan, pick up green,
; drop off and throw purple.
cmd_colors
        !byte COL_WHITE, COL_WHITE, COL_CYAN, COL_CYAN, COL_GREEN, COL_PURPLE, COL_CYAN
        !byte COL_WHITE, COL_PURPLE

; First of the four icon glyphs per command; $FF = no icon.
palette_icon_chars
        !byte ICON_CHAR_BASE+0, ICON_CHAR_BASE+4, ICON_CHAR_BASE+8, ICON_CHAR_BASE+12
        !byte ICON_CHAR_BASE+16, ICON_CHAR_BASE+20, ICON_CHAR_BASE+24
        !byte ICON2_CHAR_BASE+0, ICON2_CHAR_BASE+4

short_name_ptrs
        !word short_forward,short_backward,short_turn_right,short_turn_left
        !word short_pick_up,short_drop_off,short_turn_180
        !word short_jump,short_throw

short_pick_up !text "Pick Up",0

short_drop_off !text "Drop Off",0

short_forward !text "Move Fwd",0

short_backward !text "Move Back",0

short_turn_right !text "Turn Right",0

short_turn_left !text "Turn Left",0

short_turn_180 !text "Turn 180",0

short_jump !text "Jump",0

short_throw !text "Throw",0

; Draw the field layer and the robot from the loaded level. All field characters are
; multicolour (colour RAM +8) on the shared greens $D022/$D023 of the run screen.
!zone draw_map_objects
draw_map_objects
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
        lda map_tile_colors,x
        sta cur_col
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
        lda theme_plan_robot
        sta cur_col
        lda robot_dir
        clc
        adc #ROBOT_CHAR_BASE
        jmp put_char

map_tile_chars                  ; indexed by tile id
        !byte FLOOR_CHAR, BLOCK_CHAR, PKG_CHAR, GOAL_CHAR, PKG_CHAR, WATER_CHAR, ICE_CHAR, WATER_CHAR
        !byte KEY_CHAR, LOCK_CHAR, LOCK_CHAR, DOOR_CHAR

; map_tile_colors (colour RAM per tile id) comes from the theme, see world.asm.
map_info_colors                 ; help-text colour per tile id
        !byte COL_WHITE, COL_GREEN, COL_YELLOW, COL_CYAN, COL_YELLOW, COL_CYAN, COL_CYAN, COL_CYAN
        !byte COL_YELLOW, COL_YELLOW, COL_YELLOW, COL_YELLOW

; Hover code in A ($50..$63) -> help text in the info row.
!zone draw_map_info
draw_map_info
        cmp #$60
        bcs .object
        sec
        sbc #$50                ; robot direction
        pha
        ldx #INFO_X
        ldy #INFO_Y
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
        tay
        lda map_info_colors,y
        sta cur_col
        tya
        asl
        tax
        lda map_text_ptrs,x
        pha
        lda map_text_ptrs+1,x
        tax
        ldy #INFO_Y
        stx tmp0
        ldx #INFO_X
        jsr set_cursor
        pla
        ldx tmp0
        jmp put_str

dir_name_ptrs
        !word str_dir_right, str_dir_left, str_dir_up, str_dir_down

map_text_ptrs                   ; indexed by tile id (floor unused)
        !word 0, str_blocker, str_package, str_target, str_package_done, str_water, str_ice, str_water
        !word str_key, str_lock, str_lock, str_door

; Mouse on the bottom line (row 24)? Carry set, A = 0 "F1:Run" (columns 0..6),
; 1 "F7:Map" (7..13), 2 "F8:Title" (14..21).
!zone plan_hit_footer
plan_hit_footer
        lda mouse_y
        cmp #192
        bcc .none
        cmp #200
        bcs .none
        lda mouse_x_hi
        bne .none
        lda mouse_x_lo
        cmp #56
        bcc .run
        cmp #112
        bcc .map
        cmp #176
        bcs .none
        lda #2
        sec
        rts
.map    lda #1
        sec
        rts
.run    lda #0
        sec
        rts
.none   clc
        rts

; Questions in the palette window (exit_confirm 1 = back to title, 2 = clear list).
!zone plan_draw_quit_confirm
plan_draw_quit_confirm
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
        rts

!zone plan_draw_clear_confirm
plan_draw_clear_confirm
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
        rts

; Mouse click during a question: carry set, A = 0 "Yes" / 1 "No".
!zone plan_hit_confirm
plan_hit_confirm
        jsr palette_hit_test
        bcc .check_buttons
        cmp #9
        bcc .check_buttons
        cmp #18
        bcs .check_buttons
        cmp #13
        bcc .yes
        bcs .no
.check_buttons
        lda mouse_y
        cmp #144
        bcc .none
        cmp #160
        bcs .none
        lda mouse_x_hi
        bne .none
        lda mouse_x_lo
        cmp #48
        bcc .none
        cmp #104
        bcc .yes
        cmp #160
        bcc .no
.none   clc
        rts
.yes    lda #0
        sec
        rts
.no     lda #1
        sec
        rts

; Field cell under the mouse pointer: carry set, tmp0/tmp1 = cell (0..MAP_COLS-1, 0..MAP_ROWS-1).
!zone plan_hit_field
plan_hit_field
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
        sec
        rts
.none   clc
        rts
