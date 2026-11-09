; world.asm (VDC-View) - Themes, Weltkarte (19x10 Zellen zu 32x16 Pixel), Kartenfigur als
; Software-Sprite, Statuszeile, Level-Statistik. Logik: src/world.asm.
;
; Bildschirm: Rahmen Textzeilen 0..21 um die Karte (Spalten 2..77, Pixelzeilen 8..167),
; Meldungskasten Zeilen 22..24 (Meldung Zeile 23, Tastenhilfe im unteren Rand).

WV_COL      = 2                 ; Spalte der Zelle (0,0)
WV_Y        = 8                 ; Pixelzeile der Zelle (0,0)
WV_MSG_ROW  = 23
WV_CELL_B   = 96                ; Bytes je Zelle (64 Bitmap + 32 Attribute)
WV_ROBOT_DY = 2                 ; Roboter 18 Zeilen hoch: 2 Zeilen ueber der Zelle
WV_FRAME    = $0F               ; Rahmenfarbe Weltkarte (weiss)
wv_cells    = $96               ; Zeropage: Zellen des Themes ($96/$97)
wv_p        = $98               ; Zellendaten ($98/$99)

; ---- Themes ------------------------------------------------------------------
theme_table                     ; nur fuer die Anzahl (Logik); Daten in wv_theme_*
        !word vdc_cells_meadow
        !word vdc_cells_winter
theme_count = (* - theme_table) / 2

; A = Theme
!zone theme_load
theme_load
        sta wv_theme
        asl
        tax
        lda theme_table,x
        sta wv_cells
        lda theme_table+1,x
        sta wv_cells+1
        ldx wv_theme
        lda wv_digit_fg,x       ; Ziffern der Level: Grundfarbe der Wiese + Kontrastfarbe
        sta tmp3
        ldy #64
        lda (wv_cells),y
        and #$F0
        ora tmp3
        sta wv_digit_attr
        rts

wv_digit_fg !byte $0F, $00      ; Meadow: weiss, Winter: schwarz

; ---- Zellen ------------------------------------------------------------------
; A = Zelltyp, X/Y = Kartenzelle: zeichnen. wv_gold = 1: Braun -> Gelb (geloester Level).
!zone wv_put_cell
wv_put_cell
        sta tmp3
        txa                     ; Spalte = WV_COL + x*4
        asl
        asl
        clc
        adc #WV_COL
        sta wv_cc
        tya                     ; Zeile = WV_Y + y*16
        asl
        asl
        asl
        asl
        clc
        adc #WV_Y
        sta wv_yy
; A ist frei; tmp3 = Typ, wv_cc/wv_yy = Ziel (Spalte, Pixelzeile)
wv_put_cell_at
        jsr vp_hide
        lda tmp3                ; Daten = wv_cells + Typ*96 (Typ*64 + Typ*32)
        sta wv_p
        lda #0
        sta wv_p+1
        ldx #5
-       asl wv_p
        rol wv_p+1
        dex
        bne -                   ; *32
        lda wv_p
        sta wv_t
        lda wv_p+1
        sta wv_t+1
        asl wv_p
        rol wv_p+1              ; *64
        lda wv_p
        clc
        adc wv_t
        sta wv_p
        lda wv_p+1
        adc wv_t+1
        sta wv_p+1
        lda wv_p
        clc
        adc wv_cells
        sta wv_p
        lda wv_p+1
        adc wv_cells+1
        sta wv_p+1
        lda #0
        sta wv_i
        tay                     ; Y = Datenindex
.bl     lda wv_yy
        clc
        adc wv_i
        tax
        lda vl_lo,x
        clc
        adc wv_cc
        sta wv_t
        lda vl_hi,x
        adc #0
        sty wv_t+1
        ldy wv_t
        jsr vdc_addr
        ldy wv_t+1
        ldx #4
-       lda (wv_p),y
        +vdc_wait
        sta VDC_DATA
        iny
        dex
        bne -
        inc wv_i
        lda wv_i
        cmp #16
        bne .bl
        lda #0
        sta wv_i
.al     lda wv_yy
        lsr
        clc
        adc wv_i
        tax
        lda al_lo,x
        clc
        adc wv_cc
        sta wv_t
        lda al_hi,x
        adc #0
        sty wv_t+1
        ldy wv_t
        jsr vdc_addr
        ldy wv_t+1
        ldx #4
-       lda (wv_p),y
        bit wv_gold
        bpl +
        jsr wv_goldify
+       +vdc_wait
        sta VDC_DATA
        iny
        dex
        bne -
        inc wv_i
        lda wv_i
        cmp #8
        bne .al
        rts

; A = Attribut: Braun (12) -> Gelb (13) in beiden Haelften
wv_goldify
        pha
        and #$0F
        cmp #12
        bne +
        lda #13
+       sta wv_t
        pla
        and #$F0
        cmp #$C0
        bne +
        lda #$D0
+       ora wv_t
        rts

; A = Zelltyp der Karte an (wm_dx, wm_dy); ein offenes Tor zeigt den Weg.
!zone wm_draw_type
wm_draw_type
        cmp #WM_BACK
        bcs .draw
        cmp #WM_GATE_L
        bcc .draw
        ldx wm_gate_open
        beq .draw
        lda #WM_PATH
.draw   ldx wm_dx
        ldy wm_dy
        jmp wv_put_cell

; ---- Weltkarte ---------------------------------------------------------------
!zone world_draw
world_draw
        jsr view_sprites_off
        jsr clear_screen
        jsr ss_forget
        lda #0
        sta wv_gold
        lda #WV_FRAME
        sta vt_col
        lda #0
        sta vt_fill
        lda #78
        sta vt_fw
        lda #22
        sta vt_fh
        lda #1
        sta vt_x
        ldy #0
        jsr vt_frame
        lda #3
        sta vt_fh
        lda #1
        sta vt_x
        ldy #22
        jsr vt_frame
        jsr vb_reset            ; " World n: Name " im oberen Rand
        lda #<str_world_title
        ldx #>str_world_title
        jsr vb_str
        lda world_cur
        clc
        adc #'1'
        jsr vb_char
        lda #':'
        jsr vb_char
        lda #' '
        jsr vb_char
        ldy #WREC_NAME
        lda (world_rec),y
        pha
        iny
        lda (world_rec),y
        tax
        pla
        jsr vb_str
        lda #' '
        jsr vb_char
        lda #4
        sta vt_x
        lda #0
        sta vt_y
        lda #WV_FRAME
        sta vt_col
        jsr vt_print_buf
        lda #4                  ; Tastenhilfe im unteren Rand
        sta vt_x
        lda #24*8
        sta vt_y
        lda #<str_bottom_world_vdc
        ldx #>str_bottom_world_vdc
        jsr vt_print
        lda #0                  ; Zellen
        sta wm_dy
.row    lda #0
        sta wm_dx
.col    ldx wm_dx
        ldy wm_dy
        jsr wm_cell
        jsr wm_draw_type
        inc wm_dx
        lda wm_dx
        cmp #WMAP_COLS
        bne .col
        inc wm_dy
        lda wm_dy
        cmp #WMAP_ROWS
        bne .row
        lda #0                  ; Levelpunkte: Ziel = offen, goldene Kiste = geloest
        sta wm_tmp
.node   lda wm_tmp
        cmp world_nlev
        beq .done
        asl
        tay
        lda (wm_nodes),y
        sta wm_dx
        iny
        lda (wm_nodes),y
        sta wm_dy
        lda wm_tmp
        clc
        adc world_first
        jsr level_is_done
        beq .open
        lda #$80
        sta wv_gold
        lda #2                  ; Kiste
        bne .put
.open   lda #3                  ; Ziel
.put    ldx wm_dx
        ldy wm_dy
        jsr wv_put_cell
        lda #0
        sta wv_gold
        jsr wv_node_digit
        inc wm_tmp
        jmp .node
.done   rts

; Levelnummer des Punkts wm_tmp unten rechts in seiner Zelle
!zone wv_node_digit
wv_node_digit
        lda wm_dx
        asl
        asl
        clc
        adc #WV_COL+3
        sta vt_x
        lda wm_dy
        asl
        asl
        asl
        asl
        clc
        adc #WV_Y+8
        sta vt_y
        lda wv_digit_attr
        sta vt_col
        lda wm_tmp
        clc
        adc #'1'
        sta vt_buf
        lda #1
        sta vt_len
        jmp vt_print_buf

; Torzellen neu (Tor oder Weg, siehe wm_gate_open)
!zone world_redraw_gates
world_redraw_gates
        ldx #0
        jsr ss_hide
        lda #0
        sta wm_dy
.row    lda #0
        sta wm_dx
.col    ldx wm_dx
        ldy wm_dy
        jsr wm_cell
        cmp #WM_GATE_L
        bcc .skip
        jsr wm_draw_type
.skip   inc wm_dx
        lda wm_dx
        cmp #WMAP_COLS
        bne .col
        inc wm_dy
        lda wm_dy
        cmp #WMAP_ROWS
        bne .row
        rts

; ---- Kartenfigur -------------------------------------------------------------
world_init_sprites
        jsr ss_forget
        jsr run_set_robot_image
        ; weiter mit world_sprites

; Pro Frame: Roboter an seine Position (Zelle + Restschritte), Zeiger.
!zone world_sprites
world_sprites
        lda wm_cx               ; Spalte = WV_COL + cx*4, beim Laufen 4 Pixel je Restframe zurueck
        asl
        asl
        clc
        adc #WV_COL
        sta wv_t                ; Spalte
        lda #0
        sta wv_t+1              ; Verschiebung (0/1 = 4 Pixel)
        lda wm_cy
        asl
        asl
        asl
        asl
        clc
        adc #WV_Y-WV_ROBOT_DY
        sta wv_i                ; Zeile
        lda wm_steps
        beq .set
        ldx robot_dir
        lda run_dx_tab,x
        beq .vert
        bmi .left
        lda wm_steps            ; nach rechts: steps*4 Pixel links vom Ziel
        lsr                     ; = steps/2 Bytes, ungerade: halbes Byte
        sta tmp3
        bcc +
        inc tmp3                ; ein Byte weiter links, dann 4 Pixel nach rechts
        inc wv_t+1
+       lda wv_t
        sec
        sbc tmp3
        sta wv_t
        jmp .set
.left   lda wm_steps            ; nach links: steps*4 Pixel rechts vom Ziel
        lsr
        bcc +
        inc wv_t+1
+       clc
        adc wv_t
        sta wv_t
        jmp .set
.vert   lda wm_steps            ; 2 Zeilen je Restframe
        asl
        sta tmp3
        lda run_dy_tab,x
        bmi .up
        lda wv_i
        sec
        sbc tmp3
        sta wv_i
        jmp .set
.up     lda wv_i
        clc
        adc tmp3
        sta wv_i
.set    ldx #0
        lda vr_img
        cmp ss_img
        bne .move
        lda wv_t
        cmp ss_col
        bne .move
        lda wv_t+1
        cmp ss_sh
        bne .move
        lda wv_i
        cmp ss_y
        bne .move
        lda ss_drawn
        bne .ptr                ; unveraendert
.move   ldx #0
        jsr ss_hide
        lda vr_img
        sta ss_img
        lda wv_t
        sta ss_col
        lda wv_t+1
        sta ss_sh
        lda wv_i
        sta ss_y
        ldx #0
        jsr ss_draw
.ptr    jmp vp_show

; Bild des Roboters aus Richtung, Tragen und Laufschritt (Reihenfolge wie gen_gfx_run)
!zone run_set_robot_image
run_set_robot_image
        lda robot_dir
        ldx run_carry
        beq +
        clc
        adc #4
+       clc
        adc run_walk
        sta vr_img
        rts

; Kartenzelle unter dem Zeiger: Carry 1, tmp0/tmp1 (kann ausserhalb liegen); Carry 0 links/oben.
!zone wm_hit_cell
wm_hit_cell
        lda mouse_x_lo          ; x - WV_COL*8, dann /32
        sec
        sbc #WV_COL*8
        sta tmp0
        lda mouse_x_hi
        sbc #0
        bcc .miss
        ldx #5
-       lsr
        ror tmp0
        dex
        bne -
        lda mouse_y
        sec
        sbc #WV_Y
        bcc .miss
        lsr
        lsr
        lsr
        lsr
        sta tmp1
        sec
        rts
.miss   clc
        rts

; ---- Meldungen ---------------------------------------------------------------
; A/X = Text in der Meldungszeile (Zeile leeren, ab Spalte 3). Auch fuer den Run-Bildschirm.
!zone run_draw_message
run_draw_message
        pha
        txa
        pha
        jsr wv_msg_clear
        pla
        tax
        pla
        jmp vt_print

wv_msg_clear
        lda #WV_MSG_ROW*8
        sta vt_y
        lda #2
        sta vt_x
        lda #76
        sta vdc_w
        lda #8
        sta vdc_h
        lda #$00
        jsr vt_clear
        lda #3
        sta vt_x
        lda #$0F
        sta vt_col
        rts

; Statuszeile fuer wm_node ($FF = kein Level: Hinweis oder offenes Tor)
!zone wm_draw_status
wm_draw_status
        lda wm_node
        bmi .free
        jsr wv_msg_clear
        jsr vb_reset
        lda wm_node
        clc
        adc world_first
        sta wm_tmp
        jsr vb_level_name
        lda #$0D
        sta vt_col
        jsr vt_print_buf
        jsr vb_reset
        lda wm_tmp
        jsr level_is_done
        beq .open
        lda #<str_world_solved
        ldx #>str_world_solved
        jsr vb_str
.open   lda #<str_world_play
        ldx #>str_world_play
        jsr vb_str
        lda #$0F
        sta vt_col
        jmp vt_print_buf
.free   lda wm_gate_open
        beq .hint
        lda world_cur
        clc
        adc #1
        cmp #world_count
        bcs .hint
        lda #<str_world_gate
        ldx #>str_world_gate
        jmp run_draw_message
.hint   lda #<str_world_walk
        ldx #>str_world_walk
        jmp run_draw_message

; ---- Statistik (Fenster ueber der Karte) ----------------------------------------
SV_X    = 14
SV_Y    = 2
SV_W    = 52
SV_NAME = SV_X+3
SV_SOLV = SV_X+19
SV_PAR  = SV_X+30
SV_CMDS = SV_X+40

; Fensterhoehe: groesste Welt + 6 Zeilen
!zone stats_layout
stats_layout
        lda #0
        sta stat_h
        sta stat_w
.mx     lda stat_w
        asl
        tax
        lda world_table,x
        sta ptr1
        lda world_table+1,x
        sta ptr1+1
        ldy #WREC_FIRST+1
        lda (ptr1),y
        cmp stat_h
        bcc +
        sta stat_h
+       inc stat_w
        lda stat_w
        cmp #world_count
        bcc .mx
        lda stat_h
        clc
        adc #6
        sta stat_h
        clc
        adc #SV_Y-1
        sta stat_bot
        rts

!zone stats_draw
stats_draw
        jsr view_sprites_off
        lda #$0F
        sta vt_col
        lda #0
        sta vt_fill
        lda #SV_W
        sta vt_fw
        lda stat_h
        sta vt_fh
        lda #SV_X
        sta vt_x
        ldy #SV_Y
        jsr vt_frame
        lda #SV_X+1             ; Linie unter dem Kopf
        sta vt_x
        lda #(SV_Y+2)*8
        sta vt_y
        lda #SV_W-2
        sta vt_len
        tax
        lda #GL_T
-       sta vt_buf-1,x
        dex
        bne -
        jsr vt_print_buf
        jsr vb_reset            ; " Level statistics: <Welt> "
        lda #<str_stats_title
        ldx #>str_stats_title
        jsr vb_str
        ldy #WREC_NAME
        lda (world_rec),y
        pha
        iny
        lda (world_rec),y
        tax
        pla
        jsr vb_str
        lda #' '
        jsr vb_char
        lda #SV_X+2
        sta vt_x
        lda #SV_Y*8
        sta vt_y
        lda #$0F
        sta vt_col
        jsr vt_print_buf
        lda #SV_X+2             ; unterer Rand
        sta vt_x
        lda stat_bot
        asl
        asl
        asl
        sta vt_y
        lda #<str_stats_close
        ldx #>str_stats_close
        jsr vt_print
        lda #SV_NAME            ; Hinweis ueber dem unteren Rand
        sta vt_x
        lda stat_bot
        sec
        sbc #1
        asl
        asl
        asl
        sta vt_y
        lda #$07
        sta vt_col
        lda #<str_stats_worlds
        ldx #>str_stats_worlds
        jsr vt_print
        lda #(SV_Y+1)*8         ; Kopfzeile
        sta vt_y
        lda #$0D
        sta vt_col
        lda #SV_NAME
        sta vt_x
        lda #<str_stats_level
        ldx #>str_stats_level
        jsr vt_print
        lda #SV_SOLV
        sta vt_x
        lda #<str_stats_solved
        ldx #>str_stats_solved
        jsr vt_print
        lda #SV_PAR
        sta vt_x
        lda #<str_stats_par
        ldx #>str_stats_par
        jsr vt_print
        lda #SV_CMDS
        sta vt_x
        lda #<str_stats_cmds
        ldx #>str_stats_cmds
        jsr vt_print
        lda #0
        sta wm_tmp
.row    lda wm_tmp
        cmp world_nlev
        bne .more
        rts
.more   clc
        adc world_first
        sta stat_lvl
        lda wm_tmp
        clc
        adc #SV_Y+3
        asl
        asl
        asl
        sta vt_y
        lda #SV_NAME
        sta vt_x
        lda #$0F
        sta vt_col
        jsr vb_reset
        lda stat_lvl
        jsr vb_level_name
        jsr vt_print_buf
        lda #SV_SOLV
        sta vt_x
        lda stat_lvl
        jsr level_is_done
        beq .no
        lda #$05
        sta vt_col
        lda #<str_stats_yes
        ldx #>str_stats_yes
        bne .say
.no     lda #$09
        sta vt_col
        lda #<str_stats_no
        ldx #>str_stats_no
.say    jsr vt_print
        lda #SV_PAR
        sta vt_x
        lda #$0F
        sta vt_col
        jsr vb_reset
        ldx stat_lvl
        lda level_cmds,x
        beq .nopar
        lda level_par,x
        jsr vb_num3
        jmp .p
.nopar  jsr vb_dash3
.p      jsr vt_print_buf
        lda #SV_CMDS+1
        sta vt_x
        jsr vb_reset
        ldx stat_lvl
        lda level_cmds,x
        beq .dash
        cmp level_par,x
        beq .good
        bcs .put
.good   ldy #$05
        sty vt_col
.put    jsr vb_num3
        jmp .n
.dash   jsr vb_dash3
.n      jsr vt_print_buf
        inc wm_tmp
        jmp .row

str_bottom_world_vdc !text " Space/Click: play   F1: stats   F3/F5: world   F8: title ",0

; View-Zustand
wv_theme        !byte 0
wv_digit_attr   !byte $4F
wv_gold         !byte 0         ; $80: Braun -> Gelb
wv_cc           !byte 0
wv_yy           !byte 0
wv_i            !byte 0
wv_t            !word 0
vr_img          !byte 0         ; Bild des Roboters (run_set_robot_image)
stat_lvl        !byte 0
stat_w          !byte 0
stat_h          !byte 0
stat_bot        !byte 0
