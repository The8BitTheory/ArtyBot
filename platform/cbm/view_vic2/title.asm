; title.asm (VIC-II-View) - Titel, Menue, Instructions, Credits, Endbildschirm zeichnen.
; Logik (Menueablauf, Tasten, Auswahl title_sel): src/title.asm.

TITLE_WIN_X   = 18              ; menu window (outer frame)
TITLE_WIN_Y   = 10
TITLE_WIN_W   = 21
TITLE_WIN_H   = 11
TITLE_ITEM_X  = 22              ; first text column of the items
TITLE_HAND_X  = 20
TITLE_ITEM_Y  = 12              ; row of item 0, items 2 rows apart
TITLE_HINT_Y  = TITLE_WIN_Y+TITLE_WIN_H-1  ; hint in the bottom edge of the window
TITLE_COL_FRAME = COL_CYAN
TITLE_COL_ITEM  = COL_WHITE
TITLE_COL_SEL   = COL_YELLOW

; X = old item, title_sel = new item: both are redrawn by title_refresh in the next
; vertical blank (drawing while the beam passes the menu made the screen flicker).
!zone title_mark
title_mark
        lda title_bits,x
        ora title_dirty
        sta title_dirty
        ldx title_sel
        lda title_bits,x
        ora title_dirty
        sta title_dirty
        rts

; Item under the mouse pointer: A = 0..TITLE_ITEMS-1, $FF = none.
!zone title_hit
title_hit
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
        rts
.none   lda #$FF
        rts

; Back to the game screen setup: game charset, theme colours, no sprites.
!zone title_leave
title_leave
        jsr music_stop
        jsr gfx_sprites_off
        jsr gfx_charset_game
        jsr gfx_theme_colors
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
        jsr gfx_sprites_off
        jsr gfx_charset_title
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

; A/X = page: header, footer, lines ("#" first = yellow), $FF. Waits for a key.
!zone title_page
title_page
        sta ptr1
        stx ptr1+1
        jsr gfx_sprites_off
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
        jsr gfx_sprites_off
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
; At most END_ROWS (14) levels fit; more levels are an assembly error below.
END_WIN_X     = 18
END_WIN_Y     = 9
END_WIN_W     = 21
END_WIN_H     = 16              ; rows 9-24: top edge with the column heads, 14 levels,
                                ; bottom edge with the total
END_ROWS      = END_WIN_H - 2   ; level rows that fit
END_NAME_X    = 20
END_RUNS_X    = 29
END_CMDS_X    = 34
END_KEYS_X    = 2

!if plan_level_count > END_ROWS {
    !error "Abspann: zu viele Levels fuer das Rekord-Fenster (END_ROWS)"
}

!zone end_draw
end_draw
        jsr gfx_sprites_off
        jsr gfx_charset_end
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
        lda #COL_CYAN           ; column heads in the top edge (one more level row)
        sta cur_col
        ldx #END_NAME_X-1
        ldy #END_WIN_Y
        jsr set_cursor
        lda #<str_end_hlevel
        ldx #>str_end_hlevel
        jsr put_str
        ldx #END_RUNS_X-1
        ldy #END_WIN_Y
        jsr set_cursor
        lda #<str_end_hpar
        ldx #>str_end_hpar
        jsr put_str
        ldx #END_CMDS_X-2
        ldy #END_WIN_Y
        jsr set_cursor
        lda #<str_end_hcmds
        ldx #>str_end_hcmds
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
        adc #END_WIN_Y+1
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

title_msg     !byte 0           ; frames until the hint returns (0 = none)
