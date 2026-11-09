; title.asm (VDC-View) - Titel, Menue, Anleitung, Credits, Endbildschirm in 640x200.
; Logik (Menueablauf, Tasten, title_sel): src/title.asm. Bilder: gfx_vdc_title.asm
; (tools/gen_vdc_title.py, aus dem C64-Titelbild mit doppelter Pixelbreite).
;
; Aufbau Titel: Logo oben, Untertitel doppelt breit, links Roboter + Kiste, rechts das Menue
; (doppelt breite Schrift wie auf dem C64), unten Autor und Wettbewerb in einer Zeile.

TV_LOGO_X   = 5                 ; Logo 70 Bytes breit, Zeilen 4..53
TV_LOGO_Y   = 4
TV_TAG_ROW  = 7
TV_ROBOT_X  = 4                 ; Roboter 22 Bytes, 104 Zeilen ab Zeile 72
TV_ROBOT_Y  = 72
TV_CHEST_X  = 27
TV_CHEST_Y  = 148
TV_WIN_X    = 40                ; Menuefenster (Spalten, Textzeilen)
TV_WIN_Y    = 9
TV_WIN_W    = 36
TV_WIN_H    = 11
TV_HAND_X   = 43
TV_ITEM_X   = 46
TV_ITEM_ROW = 11                ; Punkt 0, Punkte 2 Zeilen auseinander
TV_BY_ROW   = 22
TV_COMP_ROW = 24

TC_FRAME    = $07               ; hellcyan auf schwarz
TC_ITEM     = $0F
TC_SEL      = $0D
TC_TAG      = $07
TC_BY       = $0E
TC_COMP     = $06
TC_HEAD     = $0D               ; Ueberschriften der Anleitung

; X = alter Punkt, title_sel = neuer: beide in title_refresh neu zeichnen.
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

; Punkt unter dem Mauszeiger: A = 0..TITLE_ITEMS-1, $FF = keiner.
!zone title_hit
title_hit
        jsr mouse_col
        cmp #TV_WIN_X+1
        bcc .none
        cmp #TV_WIN_X+TV_WIN_W-1
        bcs .none
        lda mouse_y
        lsr
        lsr
        lsr
        sec
        sbc #TV_ITEM_ROW
        bcc .none
        lsr
        bcs .none
        cmp #TITLE_ITEMS
        bcs .none
        rts
.none   lda #$FF
        rts

!zone title_leave
title_leave
        jsr music_stop
        jsr view_sprites_off
        jmp clear_screen

title_split                     ; kein Raster-Split auf dem VDC
        rts

title_pointer
        jmp vp_show

!zone title_refresh
title_refresh
        lda title_dirty
        beq .done
        lda #0
        sta tmp0
.l      lsr title_dirty
        bcc .next
        jsr title_draw_item
.next   inc tmp0
        lda tmp0
        cmp #TITLE_ITEMS
        bne .l
        lda #0
        sta title_dirty
.done   rts

; Pro Frame: Antennenlicht blinkt (Attribute der Antennen-Bloecke).
!zone title_anim
title_anim
        lda frame
        and #$1F
        bne .done
        lda #0
        sta tmp1
.l      ldx tmp1
        cpx #vti_blink_n
        beq .done
        lda vti_blink_dy,x      ; Blockzeile im Bild
        clc
        adc #TV_ROBOT_Y/2
        tay
        lda al_lo,y
        clc
        adc #TV_ROBOT_X
        sta vdc_dst
        lda al_hi,y
        adc #0
        sta vdc_dst+1
        lda vdc_dst
        clc
        adc vti_blink_dx,x
        tay
        lda vdc_dst+1
        adc #0
        jsr vdc_addr
        ldx tmp1
        lda frame
        and #$20
        beq .on
        lda vti_blink_off,x
        jmp .put
.on     lda vti_blink_on,x
.put    jsr vdc_put
        inc tmp1
        bne .l
.done   rts

; Ganzer Titelbildschirm.
!zone title_draw
title_draw
        jsr view_sprites_off
        jsr clear_screen
        jsr title_logo
        lda #TC_TAG
        sta vt_col
        lda #<str_title_tag
        ldx #>str_title_tag
        ldy #TV_TAG_ROW
        jsr vt_center_wide
        lda #TV_ROBOT_X
        sta vt_x
        lda #TV_ROBOT_Y
        sta vt_y
        lda #<vti_robot
        ldx #>vti_robot
        jsr vt_image
        lda #TV_CHEST_X
        sta vt_x
        lda #TV_CHEST_Y
        sta vt_y
        lda #<vti_chest
        ldx #>vti_chest
        jsr vt_image
        jsr title_draw_menu
        lda #TC_BY
        sta vt_col
        lda #<str_title_by
        ldx #>str_title_by
        ldy #TV_BY_ROW
        jsr vt_center_wide
        ; "Created for ... Competition in October 2026" in einer Zeile
        jsr vb_reset
        lda #<str_title_comp1
        ldx #>str_title_comp1
        jsr vb_str
        lda #' '
        jsr vb_char
        lda #<str_title_comp2
        ldx #>str_title_comp2
        jsr vb_str
        lda #TC_COMP
        sta vt_col
        lda #TV_COMP_ROW*8
        sta vt_y
        lda vt_len
        lsr
        eor #$FF
        sec
        adc #40
        sta vt_x
        jmp vt_print_buf

title_logo
        lda #TV_LOGO_X
        sta vt_x
        lda #TV_LOGO_Y
        sta vt_y
        lda #<vti_logo
        ldx #>vti_logo
        jmp vt_image

; Menuefenster mit Titel und allen Punkten
!zone title_draw_menu
title_draw_menu
        lda #TC_FRAME
        sta vt_col
        lda #$00
        sta vt_fill
        lda #TV_WIN_W
        sta vt_fw
        lda #TV_WIN_H
        sta vt_fh
        lda #TV_WIN_X
        sta vt_x
        ldy #TV_WIN_Y
        jsr vt_frame
        lda #TV_WIN_X+3
        sta vt_x
        lda #TV_WIN_Y*8
        sta vt_y
        lda #1
        sta vt_wide
        lda #<str_title_menu
        ldx #>str_title_menu
        jsr vt_print
        lda #0
        sta vt_wide
        sta tmp0
-       jsr title_draw_item
        inc tmp0
        lda tmp0
        cmp #TITLE_ITEMS
        bne -
        rts

; Punkt tmp0: Hand (ausgewaehlt) + Text, doppelt breit
!zone title_draw_item
title_draw_item
        lda tmp0
        asl
        clc
        adc #TV_ITEM_ROW
        asl
        asl
        asl
        sta vt_y
        lda #TV_HAND_X
        sta vt_x
        lda #2
        sta vt_len
        ldx #TC_ITEM
        lda tmp0
        cmp title_sel
        bne .nohand
        ldx #TC_SEL
        lda #GL_HAND
        sta vt_buf
        lda #GL_HAND+1
        bne .hand
.nohand lda #' '
        sta vt_buf
.hand   sta vt_buf+1
        stx vt_col
        lda #0
        sta vt_wide
        jsr vt_print_buf
        lda #TV_ITEM_X
        sta vt_x
        lda #1
        sta vt_wide
        ldx tmp0
        lda title_item_lo,x
        pha
        lda title_item_hi,x
        tax
        pla
        jsr vt_print
        lda #0
        sta vt_wide
        rts

; A/X = Text, Y = Textzeile: doppelt breit zentriert in vt_col.
!zone vt_center_wide
vt_center_wide
        sta vt_ptr
        stx vt_ptr+1
        tya
        asl
        asl
        asl
        sta vt_y
        ldy #0
-       lda (vt_ptr),y
        beq +
        iny
        bne -
+       sty vt_tmp
        lda #40
        sec
        sbc vt_tmp
        sta vt_x
        lda #1
        sta vt_wide
        lda vt_ptr
        ldx vt_ptr+1
        jsr vt_print
        lda #0
        sta vt_wide
        rts

; ---- Anleitung: beide Seiten nebeneinander auf einem Bildschirm --------------------
; A/X = Seite (str_instr1 / str_instr2). Die erste zeigt beide und wartet; die zweite kehrt
; sofort zurueck (die Logik ruft beide nacheinander).
!zone title_page
title_page
        cmp #<str_instr2
        bne .draw
        cpx #>str_instr2
        bne .draw
        rts
.draw   jsr view_sprites_off
        jsr clear_screen
        lda #TC_FRAME
        sta vt_col
        lda #0
        sta vt_fill
        lda #80
        sta vt_fw
        lda #25
        sta vt_fh
        lda #0
        sta vt_x
        tay
        jsr vt_frame
        lda #39                 ; Trennlinie in der Mitte
        sta tp_col
        jsr tp_divider
        lda #<str_instr1
        sta ptr1
        lda #>str_instr1
        sta ptr1+1
        lda #3
        jsr tp_column
        lda #<str_instr2
        sta ptr1
        lda #>str_instr2
        sta ptr1+1
        lda #42
        jsr tp_column
        lda #TC_FRAME           ; Kopf und Fuss
        sta vt_col
        lda #3
        sta vt_x
        lda #0
        sta vt_y
        lda #<str_instr_head
        ldx #>str_instr_head
        jsr vt_print
        lda #3
        sta vt_x
        lda #24*8
        sta vt_y
        lda #<str_instr_foot
        ldx #>str_instr_foot
        jsr vt_print
        jmp title_wait_any

; Spalte A: Kopf und Fuss der Seite ueberspringen, Zeilen ab Textzeile 2.
tp_column
        sta tp_col
        jsr tp_skip
        jsr tp_skip
        lda #2
        sta tp_row
.line   ldy #0
        lda (ptr1),y
        cmp #$FF
        beq .end
        ldx #TC_ITEM
        cmp #'#'
        bne .plain
        inc ptr1
        bne +
        inc ptr1+1
+       ldx #TC_HEAD
.plain  stx vt_col
        lda tp_col
        sta vt_x
        lda tp_row
        asl
        asl
        asl
        sta vt_y
        lda ptr1
        ldx ptr1+1
        jsr vt_print
        jsr tp_skip
        inc tp_row
        jmp .line
.end    rts

; ptr1 hinter den naechsten 0-terminierten Text
tp_skip ldy #0
-       lda (ptr1),y
        beq +
        iny
        bne -
+       iny
        tya
        clc
        adc ptr1
        sta ptr1
        bcc +
        inc ptr1+1
+       rts

; senkrechte Linie in Spalte tp_col, Textzeilen 1..23
tp_divider
        lda #1
        sta tp_row
-       lda tp_col
        sta vt_x
        lda tp_row
        asl
        asl
        asl
        sta vt_y
        lda #GL_L
        sta vt_buf
        lda #1
        sta vt_len
        jsr vt_print_buf
        inc tp_row
        lda tp_row
        cmp #24
        bne -
        rts

; Warten auf Taste oder Klick (Zeiger sichtbar)
!zone title_wait_any
title_wait_any
.wait   jsr wait_frame
        jsr input_update
        jsr vp_show
        lda mouse_click
        bne .done
        lda key_new
        cmp #$FF
        beq .wait
        lda key_repeat
        bne .wait
.done   rts

; ---- Credits: Fenster rechts ueber dem Menue ---------------------------------------
!zone title_credits
title_credits
        lda #TC_FRAME
        sta vt_col
        lda #0
        sta vt_fill
        lda #TV_WIN_W+2
        sta vt_fw
        lda #13
        sta vt_fh
        lda #TV_WIN_X-1
        sta vt_x
        ldy #TV_WIN_Y
        jsr vt_frame
        lda #TV_WIN_X+3
        sta vt_x
        lda #TV_WIN_Y*8
        sta vt_y
        lda #1
        sta vt_wide
        lda #<str_title_credits
        ldx #>str_title_credits
        jsr vt_print
        lda #0
        sta vt_wide
        lda #<str_credits
        sta ptr1
        lda #>str_credits
        sta ptr1+1
        lda #TV_WIN_Y+2
        sta tp_row
.line   ldy #0
        lda (ptr1),y
        cmp #$FF
        beq .wait
        lda #TC_ITEM
        ldx tp_row
        cpx #TV_WIN_Y+2
        bne +
        lda #TC_SEL             ; erste Zeile (Titel) gelb
+       sta vt_col
        lda #TV_WIN_X+1
        sta vt_x
        lda tp_row
        asl
        asl
        asl
        sta vt_y
        lda ptr1
        ldx ptr1+1
        jsr vt_print
        jsr tp_skip
        inc tp_row
        jmp .line
.wait   jmp title_wait_any

; ---- Endbildschirm -------------------------------------------------------------------
EV_WIN_X    = 40
EV_WIN_Y    = 8
EV_WIN_W    = 38
EV_WIN_H    = 17
EV_ROWS     = EV_WIN_H - 2
EV_NAME_X   = 43
EV_PAR_X    = 61
EV_CMDS_X   = 69
EV_TROPHY_X = 4
EV_TROPHY_Y = 68
EV_KEYS_X   = 6

!if plan_level_count > EV_ROWS {
    !error "Endbildschirm: zu viele Levels fuer das Fenster (EV_ROWS)"
}

!zone end_draw
end_draw
        jsr view_sprites_off
        jsr clear_screen
        jsr title_logo
        lda #TC_TAG
        sta vt_col
        lda #<str_end_tag
        ldx #>str_end_tag
        ldy #TV_TAG_ROW
        jsr vt_center_wide
        lda #EV_TROPHY_X
        sta vt_x
        lda #EV_TROPHY_Y
        sta vt_y
        lda #<vti_trophy
        ldx #>vti_trophy
        jsr vt_image
        lda #TC_ITEM
        sta vt_col
        lda #EV_KEYS_X
        sta vt_x
        lda #22*8
        sta vt_y
        lda #<str_end_key1
        ldx #>str_end_key1
        jsr vt_print
        lda #EV_KEYS_X
        sta vt_x
        lda #23*8
        sta vt_y
        lda #<str_end_key2
        ldx #>str_end_key2
        jsr vt_print
        lda #TC_FRAME
        sta vt_col
        lda #0
        sta vt_fill
        lda #EV_WIN_W
        sta vt_fw
        lda #EV_WIN_H
        sta vt_fh
        lda #EV_WIN_X
        sta vt_x
        ldy #EV_WIN_Y
        jsr vt_frame
        lda #EV_WIN_Y*8         ; Spaltenkoepfe im oberen Rand
        sta vt_y
        lda #EV_NAME_X-1
        sta vt_x
        lda #<str_end_hlevel
        ldx #>str_end_hlevel
        jsr vt_print
        lda #EV_PAR_X-2
        sta vt_x
        lda #<str_end_hpar
        ldx #>str_end_hpar
        jsr vt_print
        lda #EV_CMDS_X-2
        sta vt_x
        lda #<str_end_hcmds
        ldx #>str_end_hcmds
        jsr vt_print
        lda #0
        sta end_lvl
        sta end_sum
        sta end_sum+1
.row    lda end_lvl
        cmp #plan_level_count
        beq .total
        clc
        adc #EV_WIN_Y+1
        asl
        asl
        asl
        sta vt_y
        lda #TC_ITEM
        sta vt_col
        lda #EV_NAME_X
        sta vt_x
        jsr vb_reset
        lda end_lvl
        jsr vb_level_name
        jsr vt_print_buf
        lda #EV_PAR_X
        sta vt_x
        jsr vb_reset
        ldx end_lvl
        lda level_cmds,x        ; Par erst nach einer echten Loesung
        bne .par
        jsr vb_dash3
        jmp .p2
.par    lda level_par,x
        jsr vb_num3
.p2     jsr vt_print_buf
        lda #EV_CMDS_X
        sta vt_x
        jsr vb_reset
        ldx end_lvl
        lda level_cmds,x
        bne .cn
        jsr vb_dash3
        lda #TC_ITEM
        bne .c2
.cn     pha
        clc
        adc end_sum
        sta end_sum
        bcc +
        inc end_sum+1
+       pla
        jsr vb_num3
        lda #TC_SEL
.c2     sta vt_col
        jsr vt_print_buf
        inc end_lvl
        jmp .row
.total  lda #(EV_WIN_Y+EV_WIN_H-1)*8
        sta vt_y
        lda #EV_WIN_X+3
        sta vt_x
        lda #TC_FRAME
        sta vt_col
        lda #<str_end_total
        ldx #>str_end_total
        jsr vt_print
        jsr vb_reset
        jsr end_sum_digits
        lda #' '
        jsr vb_char
        lda #TC_SEL
        sta vt_col
        jmp vt_print_buf

; end_sum (< 10000) ohne fuehrende Nullen an vt_buf anhaengen
!zone end_sum_digits
end_sum_digits
        lda #0
        sta vt_nz
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
        lda vt_nz
        beq .skip
.show   lda #1
        sta vt_nz
        tya
        ora #'0'
        jsr vb_char
.skip   inc end_i
        lda end_i
        cmp #3
        bne .p
        lda end_sum
        ora #'0'
        jmp vb_char

end_pow_lo !byte <1000, <100, 10
end_pow_hi !byte >1000, >100, 0
end_lvl    !byte 0
end_i      !byte 0
end_sum    !word 0
tp_col     !byte 0
tp_row     !byte 0

title_item_lo !byte <str_title_new, <str_title_instr, <str_title_cred, <str_title_quit
title_item_hi !byte >str_title_new, >str_title_instr, >str_title_cred, >str_title_quit
title_bits    !byte 1, 2, 4, 8
title_dirty   !byte 0

str_instr_head !text " How to play ",0
str_instr_foot !text " Any key: let's go ",0
