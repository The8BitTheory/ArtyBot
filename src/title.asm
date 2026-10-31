; title.asm - Title screen (text mode with its own character set TITLE_CHARSET)
; Picture (logo + robot) from gfx_title.asm (tools/gen_title.py), menu and
; footer drawn on top. Raster split at TITLE_SPLIT_LINE: logo colours above,
; robot colours below ($D022/$D023). Keys: W/S or cursor up/down, Return or
; Space selects, 1-4 direct; mouse: point and click.

TITLE_ITEMS   = 4
TITLE_WIN_X   = 18              ; menu window (outer frame)
TITLE_WIN_Y   = 10
TITLE_WIN_W   = 21
TITLE_WIN_H   = 11
TITLE_ITEM_X  = 22              ; first text column of the items
TITLE_HAND_X  = 20
TITLE_ITEM_Y  = 12              ; row of item 0, items 2 rows apart
TITLE_HINT_Y  = TITLE_WIN_Y+TITLE_WIN_H-1  ; hint in the bottom edge of the window
TITLE_MEMPTR  = $04             ; screen $C000, charset $D000 (bank 3)
GAME_MEMPTR   = $02             ; screen $C000, charset $C800
KEY_1         = 56              ; keyboard matrix codes of 1..4
KEY_2         = 59
KEY_3         = 8
KEY_4         = 11
TITLE_COL_FRAME = COL_CYAN
TITLE_COL_ITEM  = COL_WHITE
TITLE_COL_SEL   = COL_YELLOW

!zone title_mode
title_mode
        jsr music_start
        lda #0
        sta title_sel
        jsr title_draw
.loop   jsr wait_frame
        jsr title_refresh       ; menu redraw in the vertical blank (no flicker)
        jsr title_split
        jsr input_update
        jsr title_pointer
        jsr title_anim
        jsr title_mouse         ; carry set: click on an item
        bcs .go
        lda key_new
        cmp #$FF
        beq .loop
        cmp #KEY_W
        beq .up
        cmp #KEY_S
        beq .down
        cmp #KEY_CRSR_UD
        bne .not_crsr
        ldx key_shift
        bne .up
        beq .down
.not_crsr
        cmp #KEY_RETURN
        beq .go
        cmp #KEY_SPACE
        beq .go
        ldx key_repeat          ; number keys: no auto repeat
        bne .loop
        ldx #0
        cmp #KEY_1
        beq .num
        inx
        cmp #KEY_2
        beq .num
        inx
        cmp #KEY_3
        beq .num
        inx
        cmp #KEY_4
        bne .loop
.num    txa
        jsr title_select
        jmp .go
.up     lda title_sel
        sec
        sbc #1
        bcs .set
        lda #TITLE_ITEMS-1
        bne .set
.down   lda title_sel
        clc
        adc #1
        cmp #TITLE_ITEMS
        bcc .set
        lda #0
.set    jsr title_select
        lda #0
        sta tmp3
        jsr sound_move
        jmp .loop
.go     lda title_sel
        beq .new_game
        cmp #1
        beq .instructions
        cmp #2
        beq .credits
        jmp system_reset        ; item 4: quit (soft reset)
.instructions
        jsr title_instructions
        jsr title_draw
        jmp .loop
.credits
        jsr title_credits
        jsr title_draw
        jmp .loop
.new_game
        jsr sound_place
        jsr title_leave
        jsr editor_init
        jsr world_init
        jmp world_mode          ; world 1 (world_init selects world 0)

; F8 in the game screens: back to the title screen from anywhere. The caller
; may sit deep inside a mode, so the stack starts over.
!zone title_return
title_return
        jsr sound_stop
        ldx #$FF
        txs
        jmp title_mode

; Back to the game screen setup: game charset, theme colours, no sprites.
!zone title_leave
title_leave
        jsr music_stop
        lda #0
        sta VIC_SPR_EN
        lda #GAME_MEMPTR
        sta VIC_MEMPTR
        lda theme_bg1
        sta VIC_BG1
        lda theme_bg2
        sta VIC_BG2
        jmp clear_screen

; Raster split, called right after wait_frame (line RASTER_LINE, below the
; screen): logo colours for the top, robot colours from TITLE_SPLIT_LINE on.
!zone title_split
title_split
        lda #TITLE_LOGO_BG1
        sta VIC_BG1
        lda #TITLE_LOGO_BG2
        sta VIC_BG2
        lda #TITLE_SPLIT_LINE
.w      cmp VIC_RASTER
        bne .w
        ldx #TITLE_BG1
        ldy #TITLE_BG2
        stx VIC_BG1
        sty VIC_BG2
        rts

; Whole title screen: picture, menu window, items, hint, footer; pointer on.
!zone title_draw
title_draw
        lda #0
        sta VIC_SPR_EN
        lda #TITLE_MEMPTR
        sta VIC_MEMPTR
        +copy title_screen, SCREEN, 1000
        +copy title_colors, COLORRAM, 1000
        jsr title_draw_menu
        lda #COL_CYAN           ; tagline under the logo
        sta cur_col
        lda #<str_title_tag
        ldx #>str_title_tag
        ldy #8
        jsr title_center
        lda #COL_WHITE          ; footer
        sta cur_col
        lda #<str_title_by
        ldx #>str_title_by
        ldy #22
        jsr title_center
        lda #COL_CYAN           ; (hires text: colours 0-7 only)
        sta cur_col
        lda #<str_title_comp1
        ldx #>str_title_comp1
        ldy #23
        jsr title_center
        lda #<str_title_comp2
        ldx #>str_title_comp2
        ldy #24
        jsr title_center
        jsr spr_init            ; mouse pointer (sprites 0 + 2 outline)
        jsr title_pointer
        lda mouse_x_lo
        sta title_mx
        lda mouse_y
        sta title_my
        lda #0
        sta title_msg
        rts

; Menu window frame with " Menu " and the items (also restores the bottom
; edge after a hint message).
!zone title_draw_menu
title_draw_menu
        lda #TITLE_COL_FRAME
        sta cur_col
        lda #TITLE_WIN_W
        sta win_w
        ldx #TITLE_WIN_X
        ldy #TITLE_WIN_Y
        lda #TITLE_WIN_H
        jsr draw_window
        ldx #TITLE_WIN_X+2      ; " Menu " in the top edge
        ldy #TITLE_WIN_Y
        jsr set_cursor
        lda #<str_title_menu
        ldx #>str_title_menu
        jsr put_str
        jmp title_draw_items

; A/X = string, Y = row: prints it centred in cur_col.
!zone title_center
title_center
        sta ptr2
        stx ptr2+1
        sty tmp1
        ldy #0
.len    lda (ptr2),y
        beq .got
        iny
        bne .len
.got    tya
        eor #$FF
        sec
        adc #40                 ; 40 - length
        lsr
        tax
        ldy tmp1
        jsr set_cursor
        lda ptr2
        ldx ptr2+1
        jmp put_str

; Draws all items; the selected one in yellow with the pointing hand.
!zone title_draw_items
title_draw_items
        lda #0
        sta title_dirty
        sta tmp0
.l      jsr title_draw_item
        inc tmp0
        lda tmp0
        cmp #TITLE_ITEMS
        bne .l
        rts

; Draws item tmp0 (hand + text). Called per changed item only: redrawing the
; whole menu after a key press takes longer than the frame has left after the
; raster split, which made the title screen flicker.
!zone title_draw_item
title_draw_item
        lda tmp0
        asl
        clc
        adc #TITLE_ITEM_Y
        tay
        ldx #TITLE_HAND_X
        jsr set_cursor
        lda #TITLE_COL_SEL
        sta cur_col
        lda tmp0
        cmp title_sel
        beq .sel
        lda #TITLE_COL_ITEM
        sta cur_col
        lda #' '
        bne .hand
.sel    lda #UI_HAND
.hand   jsr put_char
        lda #' '
        jsr put_char
        ldx tmp0
        lda title_item_lo,x
        pha
        lda title_item_hi,x
        tax
        pla
        jmp put_str

; Mouse pointer only (sprite 1, the plan's insertion marker, stays off).
!zone title_pointer
title_pointer
        jsr spr_update
        lda #$05
        sta VIC_SPR_EN
        rts

; A = item: select it. Only the two changed items are marked in title_dirty
; (bit mask); title_refresh redraws them in the next vertical blank, because
; drawing while the beam passes the menu made the screen flicker.
!zone title_select
title_select
        cmp title_sel
        beq .same
        ldx title_sel           ; old item loses hand and highlight
        sta title_sel
        lda title_bits,x
        ora title_dirty
        sta title_dirty
        ldx title_sel
        lda title_bits,x
        ora title_dirty
        sta title_dirty
.same   rts

; Called right after wait_frame (raster line 250): redraw the marked items.
!zone title_refresh
title_refresh
        lda title_dirty
        beq .done
        ldx #0
        stx tmp0
.l      lsr title_dirty
        bcc .next
        jsr title_draw_item     ; tmp0 = item
.next   inc tmp0
        lda tmp0
        cmp #TITLE_ITEMS
        bne .l
        lda #0
        sta title_dirty
.done   rts

; A/X = message for the hint row, shown for about 2 seconds.
!zone title_message
title_message
        pha
        txa
        pha
        ldx #TITLE_WIN_X+1
        ldy #TITLE_HINT_Y
        jsr set_cursor
        lda #COL_WHITE
        sta cur_col
        pla
        tax
        pla
        jsr put_str
        lda #100
        sta title_msg
        rts

; Per frame: antenna light blinks; message timer.
!zone title_anim
title_anim
        lda title_msg
        beq .blink
        dec title_msg
        bne .blink
        jsr title_draw_menu     ; hint over: restore the window edge
.blink  lda frame
        and #$1F
        bne .done
        lda frame
        and #$20
        beq .on
        lda #8+COL_YELLOW
        !byte $2C               ; bit abs: skip the next lda
.on     lda #8+COL_RED
        ldx #TITLE_BLINK_COUNT-1
.l      ldy title_blink_lo,x
        sty ptr0
        ldy title_blink_hi,x
        sty ptr0+1
        ldy #0
        sta (ptr0),y
        dex
        bpl .l
.done   rts

; Mouse: moving the pointer over an item selects it; a click on an item
; returns carry set (title_sel = that item).
!zone title_mouse
title_mouse
        lda mouse_x_hi          ; character column = x / 8
        lsr
        lda mouse_x_lo
        ror
        lsr
        lsr
        cmp #TITLE_WIN_X+1
        bcc .none
        cmp #TITLE_WIN_X+TITLE_WIN_W-1
        bcs .none
        lda mouse_y             ; row 12, 14 or 16
        lsr
        lsr
        lsr
        sec
        sbc #TITLE_ITEM_Y
        bcc .none
        lsr
        bcs .none               ; odd row: between items
        cmp #TITLE_ITEMS
        bcs .none
        sta tmp0
        lda mouse_click
        bne .click
        lda mouse_x_lo          ; hover: only when the pointer moved
        cmp title_mx
        bne .moved
        lda mouse_y
        cmp title_my
        beq .none
.moved  lda tmp0
        jsr title_select
.none   lda mouse_x_lo
        sta title_mx
        lda mouse_y
        sta title_my
        clc
        rts
.click  lda tmp0
        jsr title_select
        sec
        rts

; Instructions: two full-screen pages (str_instr1, str_instr2), any key or
; click turns the page; the caller redraws the title afterwards.
!zone title_instructions
title_instructions
        lda #<str_instr1
        ldx #>str_instr1
        jsr title_page
        lda #<str_instr2
        ldx #>str_instr2
        ; fall through

; A/X = page: header, footer, lines ("#" first = yellow), $FF. Waits for a key.
!zone title_page
title_page
        sta ptr1
        stx ptr1+1
        lda #0
        sta VIC_SPR_EN
        ldx #0                  ; blank screen, white text colour
.clr    lda #' '
        sta SCREEN,x
        sta SCREEN+250,x
        sta SCREEN+500,x
        sta SCREEN+750,x
        lda #COL_WHITE
        sta COLORRAM,x
        sta COLORRAM+250,x
        sta COLORRAM+500,x
        sta COLORRAM+750,x
        inx
        cpx #250
        bne .clr
        lda #COL_CYAN
        sta cur_col
        lda #40
        sta win_w
        ldx #0
        ldy #0
        lda #25
        jsr draw_window
        ldx #2                  ; header in the top edge
        ldy #0
        jsr set_cursor
        jsr .string
        ldx #2                  ; footer in the bottom edge
        ldy #24
        jsr set_cursor
        jsr .string
        lda #2
        sta tmp0                ; text row
.line   ldy #0
        lda (ptr1),y
        cmp #$FF
        beq .wait
        ldx #COL_WHITE
        cmp #'#'
        bne .plain
        inc ptr1                ; skip the marker, heading in yellow
        bne +
        inc ptr1+1
+       ldx #COL_YELLOW
.plain  stx cur_col
        ldx #2
        ldy tmp0
        jsr set_cursor
        jsr .string
        inc tmp0
        jmp .line
.wait   jsr wait_frame
        jsr title_split
        jsr input_update
        lda mouse_click
        bne .done
        lda key_new
        cmp #$FF
        beq .wait
        lda key_repeat
        bne .wait
.done   rts
; prints the string at ptr1 and moves ptr1 behind its terminator
.string lda ptr1
        ldx ptr1+1
        jsr put_str
        ldy #0
.skip   lda (ptr1),y
        beq .end
        iny
        bne .skip
.end    iny
        tya
        clc
        adc ptr1
        sta ptr1
        bcc +
        inc ptr1+1
+       rts

; Credits: window over the picture, any key or click returns.
!zone title_credits
title_credits
        lda #0
        sta VIC_SPR_EN
        lda #COL_CYAN
        sta cur_col
        lda #38
        sta win_w
        ldx #1
        ldy #9
        lda #13
        jsr draw_window
        ldy #10                 ; clear the inside
.clr    ldx #2
        jsr set_cursor
        lda #COL_WHITE
        sta cur_col
        ldx #36
.sp     lda #' '
        stx tmp1
        jsr put_char
        ldx tmp1
        dex
        bne .sp
        ldy cur_y
        iny
        cpy #21
        bne .clr
        ldx #3
        ldy #9
        jsr set_cursor
        lda #COL_CYAN
        sta cur_col
        lda #<str_title_credits
        ldx #>str_title_credits
        jsr put_str
        lda #COL_WHITE
        sta cur_col
        lda #<str_credits       ; lines: 0-terminated strings, $FF ends
        sta ptr1
        lda #>str_credits
        sta ptr1+1
        lda #11
        sta tmp0
.line   ldy #0
        lda (ptr1),y
        cmp #$FF
        beq .wait
        ldx #3
        ldy tmp0
        jsr set_cursor
        lda ptr1
        ldx ptr1+1
        jsr put_str
        ldy #0                  ; skip to the next string
.skip   lda (ptr1),y
        beq .next
        iny
        bne .skip
.next   iny
        tya
        clc
        adc ptr1
        sta ptr1
        bcc .nc
        inc ptr1+1
.nc     inc tmp0
        jmp .line
.wait   jsr wait_frame
        jsr title_split
        jsr input_update
        lda mouse_click
        bne .done
        lda key_new
        cmp #$FF
        beq .wait
        lda key_repeat
        bne .wait
.done   rts

; ---- End screen ---------------------------------------------------------------
; Shown when the robot steps through the open gate of the last world. Style of
; the title (logo, END_CHARSET with a trophy instead of the robot), on the right
; the record of every level (runs, fewest commands) as a certificate.
; Return: title screen, F7: back onto the map (in front of the gate).
END_WIN_X     = 18
END_WIN_Y     = 9
END_WIN_W     = 21
END_WIN_H     = 16              ; rows 9-24: header + 13 levels
END_ROWS      = END_WIN_H - 3   ; level rows that fit
END_NAME_X    = 20
END_RUNS_X    = 29
END_CMDS_X    = 34
END_KEYS_X    = 2
END_MEMPTR    = $06             ; screen $C000, charset $D800 (bank 3)

!zone end_mode
end_mode
        lda wm_prevx            ; the robot waits in front of the gate
        sta wm_cx
        lda wm_prevy
        sta wm_cy
        jsr world_save_pos
        jsr end_draw
        jsr sound_celebrate
.wait   jsr wait_frame
        jsr title_split
        jsr input_update
        lda key_new
        cmp #$FF
        beq .wait
        ldx key_repeat
        bne .wait
        cmp #KEY_RETURN
        beq .title
        cmp #KEY_F7
        bne .wait
        lda key_shift           ; F8 (Shift+F7) does nothing here
        bne .wait
        jsr title_leave
        ldx #$FF                ; top level again (we came from inside world_mode)
        txs
        jmp world_mode
.title  ldx #$FF
        txs
        jmp title_mode

!zone end_draw
end_draw
        lda #0
        sta VIC_SPR_EN
        lda #END_MEMPTR
        sta VIC_MEMPTR
        +copy end_screen, SCREEN, 1000
        +copy end_colors, COLORRAM, 1000
        lda #COL_CYAN           ; line under the logo
        sta cur_col
        lda #<str_end_tag
        ldx #>str_end_tag
        ldy #8
        jsr title_center
        lda #COL_WHITE          ; keys under the trophy
        sta cur_col
        ldx #END_KEYS_X
        ldy #22
        jsr set_cursor
        lda #<str_end_key1
        ldx #>str_end_key1
        jsr put_str
        ldx #END_KEYS_X
        ldy #23
        jsr set_cursor
        lda #<str_end_key2
        ldx #>str_end_key2
        jsr put_str
        lda #TITLE_COL_FRAME    ; the record window
        sta cur_col
        lda #END_WIN_W
        sta win_w
        ldx #END_WIN_X
        ldy #END_WIN_Y
        lda #END_WIN_H
        jsr draw_window
        ldx #END_WIN_X+2
        ldy #END_WIN_Y
        jsr set_cursor
        lda #<str_end_record
        ldx #>str_end_record
        jsr put_str
        lda #COL_CYAN           ; column heads
        sta cur_col
        ldx #END_NAME_X
        ldy #END_WIN_Y+1
        jsr set_cursor
        lda #<str_stats_level
        ldx #>str_stats_level
        jsr put_str
        ldx #END_RUNS_X
        ldy #END_WIN_Y+1
        jsr set_cursor
        lda #<str_stats_par
        ldx #>str_stats_par
        jsr put_str
        ldx #END_CMDS_X-1
        ldy #END_WIN_Y+1
        jsr set_cursor
        lda #<str_stats_cmds
        ldx #>str_stats_cmds
        jsr put_str
        lda #0
        sta end_lvl
        sta end_sum
        sta end_sum+1
.row    lda end_lvl
        cmp #plan_level_count
        beq .total
        cmp #END_ROWS
        beq .total
        clc
        adc #END_WIN_Y+2
        sta end_y
        tay
        ldx #END_NAME_X
        jsr set_cursor
        lda #COL_WHITE
        sta cur_col
        lda end_lvl
        jsr stats_put_level_name
        ldx #END_RUNS_X
        ldy end_y
        jsr set_cursor
        ldx end_lvl             ; par: only after a real solution
        lda level_cmds,x
        bne .runs
        jsr stats_put_dash
        jmp .cmds
.runs   lda level_par,x
        jsr stats_put_num
.cmds   ldx #END_CMDS_X
        ldy end_y
        jsr set_cursor
        ldx end_lvl
        lda level_cmds,x
        bne .cn
        jsr stats_put_dash
        jmp .next
.cn     pha
        clc
        adc end_sum
        sta end_sum
        bcc .nc
        inc end_sum+1
.nc     lda #COL_YELLOW
        sta cur_col
        pla
        jsr stats_put_num
.next   inc end_lvl
        jmp .row
.total  lda #TITLE_COL_FRAME    ; " Total cmds: n " in the bottom edge
        sta cur_col
        ldx #END_WIN_X+2
        ldy #END_WIN_Y+END_WIN_H-1
        jsr set_cursor
        lda #<str_end_total
        ldx #>str_end_total
        jsr put_str
        lda #COL_YELLOW
        sta cur_col
        jsr end_put_sum
        lda #' '
        jmp put_char

; end_sum (16 bit, < 10000) as decimal without leading zeros.
!zone end_put_sum
end_put_sum
        lda #0
        sta stat_nz
        sta end_i
.p      ldx end_i
        ldy #0
.s      lda end_sum
        sec
        sbc end_pow_lo,x
        sta tmp3
        lda end_sum+1
        sbc end_pow_hi,x
        bcc .d
        sta end_sum+1
        lda tmp3
        sta end_sum
        iny
        bne .s
.d      tya
        bne .show
        lda stat_nz
        beq .skip
.show   lda #1
        sta stat_nz
        tya
        clc
        adc #'0'
        jsr put_char
.skip   inc end_i
        lda end_i
        cmp #3
        bne .p
        lda end_sum
        clc
        adc #'0'
        jmp put_char

end_pow_lo !byte <1000, <100, 10
end_pow_hi !byte >1000, >100, 0
end_lvl    !byte 0
end_y      !byte 0
end_i      !byte 0
end_sum    !word 0

title_item_lo !byte <str_title_new, <str_title_instr, <str_title_cred, <str_title_quit
title_item_hi !byte >str_title_new, >str_title_instr, >str_title_cred, >str_title_quit
title_bits    !byte 1, 2, 4, 8
title_dirty   !byte 0           ; bit mask of items to redraw (title_refresh)
title_sel     !byte 0           ; selected menu item
title_msg     !byte 0           ; frames until the hint returns (0 = none)
title_mx      !byte 0           ; last mouse position (hover detection)
title_my      !byte 0
