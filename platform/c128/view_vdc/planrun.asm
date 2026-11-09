; planrun.asm (VDC-View) - gemeinsamer Plan-/Run-Bildschirm (VIEW_UNIFIED), 640x200:
;   links  Feld 10x10 Zellen zu 32x16 (Spalten 0..41, Zeilen 0..21 mit Rahmen)
;   Mitte  Legende (Zeilen 0..10) und Befehle 3x3 (Zeilen 11..21), Spalten 42..61
;   rechts Programm, 20 Zeilen, Einfuegemarke Spalte 63, Scrollbalken Spalte 78 (62..79)
;   unten  Info/Meldung Zeilen 22-23, Tastenzeile 24
; Ein Wechsel Plan <-> Run baut den Bildschirm nicht neu auf (nur Feld, Liste, Modus).
; Logik: src/editor.asm (Planen), src/run.asm (Lauf). Roboter und Kiste: sprite.asm.

PR_FIELD_COL = 1                ; Spalte der Zelle (0,0)
PR_FIELD_Y   = 8                ; Pixelzeile der Zelle (0,0)
PR_ROBOT_DY  = 2
PR_CHEST_DY  = 6                ; Kiste ueber dem Kopf (Hoehe des Kistenbilds)
PR_LEG_ROW   = 1
PR_LEG_ROWS  = 9
PR_PAL_COL   = 44               ; erste Icon-Spalte, Abstand 6
PR_PAL_ROW   = 12               ; erste Icon-Zeile, Abstand 3
PR_LIST_ROW  = 1
PR_MARK_COL  = 63
PR_NUM_COL   = 64
PR_NAME_COL  = 67
PR_BAR_COL   = 78
PR_INFO_ROW  = 22
PR_FOOT_ROW  = 24
PR_FRAME     = $0F
pr_a         = $9C              ; Zeropage $9C/$9D (wie ss_c, nie gleichzeitig)

!macro pr_text .col, .row, .attr, .str {
        lda #.col
        sta vt_x
        lda #.row*8
        sta vt_y
        lda #.attr
        sta vt_col
        lda #<.str
        ldx #>.str
        jsr vt_print
}

; ---- Bildschirm ---------------------------------------------------------------------
; Rahmen, Titel und Tastenzeile (nur wenn der Bildschirm noch nicht steht)
!zone pr_frame
pr_frame
        lda vw_screen
        cmp #VW_PLANRUN
        bne +
        rts
+       jsr view_sprites_off
        jsr clear_screen
        jsr ss_forget
        lda #VW_PLANRUN
        sta vw_screen
        lda #$FE                ; Schatten der Liste ungueltig
        ldx #PROGRAM_ROWS-1
-       sta pr_sh_idx,x
        dex
        bpl -
        lda #PR_INFO_ROW
        sta vw_msg_row
        lda #2
        sta vw_msg_rows
        lda #PR_FRAME
        sta vt_col
        lda #0
        sta vt_fill
        lda #42                 ; Feld
        sta vt_fw
        lda #22
        sta vt_fh
        lda #0
        sta vt_x
        ldy #0
        jsr vt_frame
        lda #20                 ; Legende
        sta vt_fw
        lda #11
        sta vt_fh
        lda #42
        sta vt_x
        ldy #0
        jsr vt_frame
        lda #11                 ; Befehle
        sta vt_fh
        lda #42
        sta vt_x
        ldy #11
        jsr vt_frame
        lda #18                 ; Programm
        sta vt_fw
        lda #22
        sta vt_fh
        lda #62
        sta vt_x
        ldy #0
        jsr vt_frame
        +pr_text 44, 0, PR_FRAME, str_pr_legend
        +pr_text 44, 11, PR_FRAME, str_pr_commands
        +pr_text 64, 0, PR_FRAME, str_pr_program
        lda #PR_BAR_COL         ; Pfeile des Scrollbalkens
        sta vt_x
        lda #PR_LIST_ROW*8
        sta vt_y
        lda #GL_UP
        jsr pr_glyph
        lda #(PR_LIST_ROW+PROGRAM_ROWS-1)*8
        sta vt_y
        lda #PR_BAR_COL
        sta vt_x
        lda #GL_DOWN
        jsr pr_glyph
        +pr_text 1, PR_FOOT_ROW, $0D, str_pr_footer
        jsr draw_program_counts
        jmp draw_palette_panel

; A = Glyph an (vt_x, vt_y) in vt_col
pr_glyph
        sta vt_buf
        lda #1
        sta vt_len
        lda #0
        sta vt_wide
        jmp vt_print_buf

; Titel im oberen Feldrand: " <Welt> <n> - Plan " / " - Run "
!zone draw_title_and_counters
draw_title_and_counters
        lda #2
        sta vt_x
        lda #0
        sta vt_y
        lda #$0D
        sta vt_col
        jsr vb_reset
        lda #' '
        jsr vb_char
        lda level_no
        jsr vb_level_name
        jsr vt_print_buf
        jsr vb_reset
        lda #<str_pr_plan
        ldx #>str_pr_plan
        ldy vw_mode
        beq +
        lda #<str_pr_run
        ldx #>str_pr_run
+       jsr vb_str
        lda #$07
        sta vt_col
        jmp vt_print_buf

; ---- Planen ----------------------------------------------------------------------
draw_planning_screen
        jsr pr_frame
        lda #0
        sta vw_mode
        jsr draw_title_and_counters
        jsr draw_map_objects
        jsr pr_clear_bottom_edge
        jsr draw_scrollbar
        lda #$FF
        jmp editor_draw_info

; Feld aus map_work, der Roboter am Start (Bild = Blickrichtung) und die Legende
; (auch beim Levelwechsel mit den Zifferntasten)
draw_map_objects
        jsr draw_legend
        jsr draw_run_field
        lda #0
        sta pr_vis+1            ; keine Kiste
        lda robot_tx
        asl
        asl
        clc
        adc #PR_FIELD_COL
        sta ss_col
        lda #0
        sta ss_sh
        lda robot_ty
        asl
        asl
        asl
        asl
        clc
        adc #PR_FIELD_Y-PR_ROBOT_DY
        sta ss_y
        lda robot_dir
        sta ss_img
        lda #1
        sta pr_vis
        jmp pr_sprites_draw

; unterer Feldrand ohne "Delivered" (im Plan)
pr_clear_bottom_edge
        lda #1
        sta vt_x
        lda #21*8
        sta vt_y
        lda #PR_FRAME
        sta vt_col
        lda #20
        sta vt_len
        tax
        lda #GL_B
-       sta vt_buf-1,x
        dex
        bne -
        jmp vt_print_buf

; Legende: ArtyBot mit Blickrichtung, dann die Feldarten des Levels (Mini-Zellen)
!zone draw_legend
draw_legend
        lda #43                 ; Inneres leeren
        sta vt_x
        lda #PR_LEG_ROW*8
        sta vt_y
        lda #18
        sta vdc_w
        lda #PR_LEG_ROWS*8
        sta vdc_h
        lda #$00
        jsr vt_clear
        lda robot_dir           ; Mini-Roboter
        clc
        adc #32
        ldy #PR_LEG_ROW
        jsr pr_mini
        +pr_text 47, PR_LEG_ROW, $0D, str_leg_robot
        lda #48
        sta vt_x
        lda #(PR_LEG_ROW+1)*8
        sta vt_y
        lda #$0F
        sta vt_col
        jsr vb_reset
        lda #<str_leg_looking
        ldx #>str_leg_looking
        jsr vb_str
        lda #' '
        jsr vb_char
        lda robot_dir
        asl
        tax
        lda pr_dir_ptrs,x
        pha
        lda pr_dir_ptrs+1,x
        tax
        pla
        jsr vb_str
        jsr vt_print_buf
        lda #PR_LEG_ROW+2
        sta pr_row
        lda #0
        sta pr_i
.next   ldx pr_i
        cpx #8
        beq .done
        lda pr_leg_ids,x
        sta tmp0
        ldx #MAP_COLS*MAP_ROWS-1
.scan   lda map_work,x
        cmp tmp0
        beq .found
        cmp #T_BOXG             ; Kiste auf dem Ziel zaehlt fuer Ziel und Kiste
        bne +
        lda tmp0
        cmp #T_GOAL
        beq .found
        cmp #T_BOX
        beq .found
+       dex
        bpl .scan
        inc pr_i
        jmp .next
.found  lda pr_row
        cmp #PR_LEG_ROW+PR_LEG_ROWS
        bcs .done
        ldx pr_i
        lda pr_leg_cell,x
        ldx wv_theme
        beq +
        clc
        adc #16
+       ldy pr_row
        jsr pr_mini
        lda #47
        sta vt_x
        lda pr_row
        asl
        asl
        asl
        sta vt_y
        lda #$0F
        sta vt_col
        lda pr_i
        asl
        tax
        lda pr_leg_text,x
        pha
        lda pr_leg_text+1,x
        tax
        pla
        jsr vt_print
        inc pr_row
        inc pr_i
        jmp .next
.done   rts

; A = Mini-Bild (0..31 Zellen, 32..35 Roboter), Y = Textzeile: Spalten 44-45 per Block-Copy
!zone pr_mini
pr_mini
        sta pr_t
        sty pr_t2
        jsr vp_hide
        jsr vdc_mode_copy
        lda pr_t                ; Quelle = ST_MINI + Bild*24 (Bild*3, dann *8)
        asl
        adc pr_t
        sta pr_a
        lda #0
        sta pr_a+1
        ldx #3
-       asl pr_a
        rol pr_a+1
        dex
        bne -
        lda pr_a
        clc
        adc #<ST_MINI
        tay
        lda pr_a+1
        adc #>ST_MINI
        +vwr 32
        tya
        +vwr 33
        lda pr_t2               ; 8 Bitmap-Zeilen
        asl
        asl
        asl
        sta pr_t
        lda #8
        sta pr_n
-       ldx pr_t
        lda vl_lo,x
        clc
        adc #44
        tay
        lda vl_hi,x
        adc #0
        +vwr 18
        tya
        +vwr 19
        lda #2
        +vwr 30
        inc pr_t
        dec pr_n
        bne -
        lda pr_t2               ; 4 Attributzeilen
        asl
        asl
        sta pr_t
        lda #4
        sta pr_n
-       ldx pr_t
        lda al_lo,x
        clc
        adc #44
        tay
        lda al_hi,x
        adc #0
        +vwr 18
        tya
        +vwr 19
        lda #2
        +vwr 30
        inc pr_t
        dec pr_n
        bne -
        rts

; Befehle: 9 Icons (32x16 aus der Ablage) im 3x3-Raster mit Tastenbuchstaben
!zone draw_palette_panel
draw_palette_panel
        lda #0
        sta pr_i
.l      jsr pr_icon
        inc pr_i
        lda pr_i
        cmp #9
        bne .l
        rts

; Rasterplatz pr_i (0..8, zeilenweise): Icon + Buchstabe
pr_icon
        ldx pr_i
        lda pr_grid_cmd,x
        sta pr_cmd
        jsr pr_cell_pos         ; vt_x, vt_y = Icon oben links
        jsr vp_hide
        jsr vdc_mode_copy
        lda pr_cmd              ; Quelle = ST_ICONS + Befehl*64
        lsr
        lsr
        clc
        adc #>ST_ICONS
        sta pr_a+1
        lda pr_cmd
        asl
        asl
        asl
        asl
        asl
        asl
        clc
        adc #<ST_ICONS
        tay
        lda pr_a+1
        adc #0
        +vwr 32
        tya
        +vwr 33
        lda vt_y
        sta pr_t
        lda #16
        sta pr_n
-       ldx pr_t
        lda vl_lo,x
        clc
        adc vt_x
        tay
        lda vl_hi,x
        adc #0
        +vwr 18
        tya
        +vwr 19
        lda #4
        +vwr 30
        inc pr_t
        dec pr_n
        bne -
        lda #4                  ; Farbe nach Befehlsart
        sta vdc_w
        lda #8
        sta vdc_h
        ldx pr_cmd
        lda pr_cmd_col,x
        jsr vt_attr_rect
        lda vt_x                ; Tastenbuchstabe rechts daneben
        clc
        adc #4
        sta vt_x
        lda #$0D
        sta vt_col
        ldx pr_cmd
        lda pr_key_char,x
        jsr ascii2scr
        jmp pr_glyph

; pr_i (Rasterplatz) -> vt_x / vt_y
pr_cell_pos
        lda pr_i
        ldx #0
-       cmp #3
        bcc +
        sbc #3
        inx
        bne -
+       sta pr_t                ; Spalte im Raster
        asl
        adc pr_t
        asl                     ; *6
        adc #PR_PAL_COL
        sta vt_x
        txa                     ; Zeile *3
        sta pr_t
        asl
        adc pr_t
        adc #PR_PAL_ROW
        asl
        asl
        asl
        sta vt_y
        rts

; Befehle-Inneres leeren (fuer Rueckfragen)
editor_clear_palette_interior
        lda #43
        sta vt_x
        lda #12*8
        sta vt_y
        lda #18
        sta vdc_w
        lda #9*8
        sta vdc_h
        lda #$00
        jmp vt_clear

plan_draw_quit_confirm
        jsr editor_clear_palette_interior
        +pr_text 45, 14, $0F, str_quit_confirm
        jmp pr_yes_no
plan_draw_clear_confirm
        jsr editor_clear_palette_interior
        +pr_text 45, 13, $0F, str_clear_confirm
        +pr_text 45, 14, $0F, str_clear_confirm2
pr_yes_no
        +pr_text 45, 17, $0D, str_quit_yes
        +pr_text 54, 17, $0D, str_quit_no
        rts

; ---- Programmliste -----------------------------------------------------------------
draw_program_list
        lda #$FF                ; Lauf-Liste beim naechsten Mal ganz
        sta pr_lscr
        lda #0
        sta pr_row
-       jsr pr_list_row
        inc pr_row
        lda pr_row
        cmp #PROGRAM_ROWS
        bne -
        rts

; A = absolute Befehlsnummer: nur diese Zeile, wenn sichtbar
draw_program_row
        sec
        sbc scroll_offset
        bcc +
        cmp #PROGRAM_ROWS
        bcs +
        sta pr_row
        jmp pr_list_row
+       rts

; sichtbare Zeile pr_row: Spalten 63..77; Plan: ausgewaehlt gelb, Run: laufender Befehl mit Hand
!zone pr_list_row
; Nur zeichnen, wenn sich die Zeile geaendert hat: Schatten je Zeile = Nummer ($FF leer)
; und Zustand (Befehl | $10 Hand | $20 ausgewaehlt). Beim Tippen am Ende aendert sich so nur
; eine Zeile (sonst kostet die ganze Liste mehrere Frames und Tasten gehen verloren).
pr_list_row
        lda scroll_offset
        clc
        adc pr_row
        sta pr_t
        ldy #0                  ; Zustand
        cmp editor_count
        bcc +
        lda #$FF                ; leer
        bne .cmp
+       tax
        lda program,x
        sta pr_t2
        lda vw_mode
        beq .pl
        cpx run_cur
        bne .st
        lda #$10
        bne .or
.pl     lda selection_active
        beq .st
        cpx selected_index
        bne .st
        lda #$20
.or     ora pr_t2
        sta pr_t2
.st     ldy pr_t2
        lda pr_t
.cmp    ldx pr_row
        cmp pr_sh_idx,x
        bne .draw
        tya
        cmp pr_sh_st,x
        bne .draw
        rts
.draw   sta pr_sh_idx,x         ; (A = Nummer bzw. Zustand, siehe unten)
        lda pr_t
        cmp editor_count
        bcc +
        lda #$FF
+       sta pr_sh_idx,x
        tya
        sta pr_sh_st,x
        lda pr_mark             ; Marke ragt in diese Zeile (Marke = Zeile oder Zeile+1):
        sec                     ; vorher loeschen, spr_update zeichnet sie neu
        sbc pr_row
        cmp #2
        bcs +
        jsr pr_mark_erase
        lda #$FF
        sta pr_mark
+       lda pr_row
        clc
        adc #PR_LIST_ROW
        asl
        asl
        asl
        sta vt_y
        jsr vb_reset            ; 15 Zeichen: Marke/Hand, Nummer, Name
        lda pr_t
        cmp editor_count
        bcc .cmd
-       lda #' '            ; leere Zeile
        jsr vb_char
        lda vt_len
        cmp #15
        bcc -
        lda #$0F
        bne .out
.cmd    lda #' '                ; Spalte 63: Hand beim laufenden Befehl
        ldx vw_mode
        beq +
        ldx pr_t
        cpx run_cur
        bne +
        lda #GL_HAND
+       ldx vt_len
        sta vt_buf,x
        inc vt_len
        ldx pr_t                ; zweistellige Nummer (ab 1)
        inx
        txa
        jsr pr_num2
        lda #' '
        jsr vb_char
        lda #' '
        jsr vb_char
        ldx pr_t
        lda program,x
        sta pr_cmd
        asl
        tax
        lda pr_names+1,x
        pha
        lda pr_names,x
        tay
        pla
        tax
        tya
        jsr vb_str
-       lda vt_len              ; auf 15 auffuellen
        cmp #15
        bcs +
        lda #' '
        jsr vb_char
        jmp -
+       ldx pr_cmd              ; Farbe: Befehlsart; ausgewaehlt / laufend gelb
        lda pr_cmd_col,x
        ldx vw_mode
        bne .run
        ldx selection_active
        beq .out
        ldx pr_t
        cpx selected_index
        bne .out
        lda #$0D
        bne .out
.run    ldx pr_t
        cpx run_cur
        bne .out
        lda #$0D
.out    sta vt_col
        lda #PR_MARK_COL
        sta vt_x
        jmp vt_print_buf

; A = 0..99 zweistellig an vt_buf
pr_num2 ldx #'0'
-       cmp #10
        bcc +
        sbc #10
        inx
        bne -
+       pha
        txa
        jsr vb_char
        pla
        ora #'0'
        jmp vb_char

draw_program_counts
        lda #73
        sta vt_x
        lda #0
        sta vt_y
        lda #$0D
        sta vt_col
        jsr vb_reset
        lda editor_count
        jsr pr_num2
        jmp vt_print_buf

; Scrollbalken: Spur Zeilen 2..19, Daumen = scroll_offset * 17 / (editor_count - 20)
!zone draw_scrollbar
draw_scrollbar
        lda #$07
        sta vt_col
        lda #PR_LIST_ROW+1
        sta pr_row
-       lda #PR_BAR_COL
        sta vt_x
        lda pr_row
        asl
        asl
        asl
        sta vt_y
        lda #GL_TRACK
        jsr pr_glyph
        inc pr_row
        lda pr_row
        cmp #PR_LIST_ROW+PROGRAM_ROWS-1
        bne -
        ldx #0
        lda editor_count
        sec
        sbc #PROGRAM_ROWS
        bcc .place
        beq .place
        sta tmp3                ; groesster Versatz
        lda scroll_offset       ; * 17 (Spur hat 18 Zeilen: 0..17)
        sta tmp1
        lda #0
        sta tmp2
        ldy #4
-       asl tmp1
        rol tmp2
        dey
        bne -
        lda tmp1
        clc
        adc scroll_offset
        sta tmp1
        bcc .div
        inc tmp2
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
        cmp #PROGRAM_ROWS-3
        bcc +
        lda #PROGRAM_ROWS-3
+       clc
        adc #PR_LIST_ROW+1
        asl
        asl
        asl
        sta vt_y
        lda #$0F
        sta vt_col
        lda #PR_BAR_COL
        sta vt_x
        lda #GL_FULL
        jmp pr_glyph

; ---- Info (Zeilen 22-23) -------------------------------------------------------
pr_info_clear
        lda #0
        sta vt_x
        lda #PR_INFO_ROW*8
        sta vt_y
        lda #80
        sta vdc_w
        lda #16
        sta vdc_h
        lda #$00
        jmp vt_clear

; A = Befehl (0..8), $FF = Hilfe, $50+Richtung = Roboter, $60+Feldart
!zone editor_draw_info
editor_draw_info
        sta selected_command
        jsr pr_info_clear
        lda selected_command
        cmp #$FF
        beq .idle
        cmp #$50
        bcs .map
        cmp #9
        bcs .done
        tax
        lda pr_cmd_col,x
        sta vt_col
        lda #1
        sta vt_x
        lda #PR_INFO_ROW*8
        sta vt_y
        txa
        asl
        tax
        lda pr_names,x
        pha
        lda pr_names+1,x
        tax
        pla
        jmp vt_print
.idle   lda #<str_idle_help
        ldx #>str_idle_help
        jmp editor_draw_message2
.map    lda #1
        sta vt_x
        lda #PR_INFO_ROW*8
        sta vt_y
        lda selected_command
        cmp #$60
        bcs .obj
        and #3                  ; Roboter: "Facing <Richtung>"
        sta pr_t
        lda #$0F
        sta vt_col
        jsr vb_reset
        lda #<str_facing
        ldx #>str_facing
        jsr vb_str
        lda pr_t
        asl
        tax
        lda pr_dirname+1,x
        pha
        lda pr_dirname,x
        tay
        pla
        tax
        tya
        jsr vb_str
        jmp vt_print_buf
.obj    sec
        sbc #$60
        tax
        lda pr_info_col,x
        sta vt_col
        txa
        asl
        tax
        lda pr_map_text+1,x
        beq .done
        pha
        lda pr_map_text,x
        tay
        pla
        tax
        tya
        jmp vt_print
.done   rts

; A/X = zwei Texte hintereinander: Zeilen 22 und 23
editor_draw_message2
        sta vt_ptr2
        stx vt_ptr2+1
        jsr pr_info_clear
        lda #1
        sta vt_x
        lda #PR_INFO_ROW*8
        sta vt_y
        lda #$0F
        sta vt_col
        lda vt_ptr2
        ldx vt_ptr2+1
        jsr vt_print
        ldy #0                  ; hinter das erste Ende
-       lda (vt_ptr),y
        beq +
        iny
        bne -
+       iny
        tya
        clc
        adc vt_ptr
        pha
        lda vt_ptr+1
        adc #0
        tax
        lda #1
        sta vt_x
        lda #(PR_INFO_ROW+1)*8
        sta vt_y
        pla
        jmp vt_print

; ---- Treffertests -----------------------------------------------------------------
; mouse_col -> A, Textzeile -> pr_t
pr_mouse
        lda mouse_y
        lsr
        lsr
        lsr
        sta pr_t
        jmp mouse_col

; Scrollpfeile: Carry, A = 0 hoch / 1 runter
arrow_hit_test
        jsr pr_mouse
        cmp #PR_BAR_COL
        bne .no
        lda pr_t
        cmp #PR_LIST_ROW
        beq .up
        cmp #PR_LIST_ROW+PROGRAM_ROWS-1
        bne .no
        lda #1
        sec
        rts
.up     lda #0
        sec
        rts
.no     clc
        rts

; Befehls-Icon (mit Buchstabe): Carry, A = Befehl
!zone palette_hit_test
palette_hit_test
        jsr pr_mouse
        sec
        sbc #PR_PAL_COL
        bcc .no
        ldx #0
-       cmp #5                  ; 4 Spalten Icon + Buchstabe
        bcc .col
        cmp #6
        bcc .no
        sbc #6
        inx
        cpx #3
        bne -
        beq .no
.col    stx pr_t2               ; Rasterspalte
        lda pr_t
        sec
        sbc #PR_PAL_ROW
        bcc .no
        ldx #0
-       cmp #2
        bcc .row
        cmp #3
        bcc .no
        sbc #3
        inx
        cpx #3
        bne -
        beq .no
.row    txa                     ; Zeile*3 + Spalte
        sta pr_t
        asl
        adc pr_t
        adc pr_t2
        tax
        lda pr_grid_cmd,x
        sec
        rts
.no     clc
        rts

; belegte Programmzeile: Carry, A = absolute Nummer
!zone list_hit_test
list_hit_test
        jsr pr_mouse
        cmp #PR_MARK_COL
        bcc .no
        cmp #PR_BAR_COL
        bcs .no
        lda pr_t
        sec
        sbc #PR_LIST_ROW
        bcc .no
        cmp #PROGRAM_ROWS
        bcs .no
        clc
        adc scroll_offset
        cmp editor_count
        bcs .no
        sec
        rts
.no     clc
        rts

; Feldzelle: Carry, tmp0/tmp1
!zone plan_hit_field
plan_hit_field
        jsr mouse_col
        sec
        sbc #PR_FIELD_COL
        bcc .no
        lsr
        lsr
        cmp #MAP_COLS
        bcs .no
        sta tmp0
        lda mouse_y
        sec
        sbc #PR_FIELD_Y
        bcc .no
        lsr
        lsr
        lsr
        lsr
        cmp #MAP_ROWS
        bcs .no
        sta tmp1
        sec
        rts
.no     clc
        rts

; Tastenzeile: Carry, A = 0 Run / 1 Karte / 2 Titel
!zone plan_hit_footer
plan_hit_footer
        jsr pr_mouse
        ldx pr_t
        cpx #PR_FOOT_ROW
        bne .no
        cmp #1                  ; "Space:Go/Pause" 1..14, "F7:Map" 17..22, "F8:Title" 25..32
        bcc .no
        cmp #15
        bcc .run
        cmp #17
        bcc .no
        cmp #23
        bcc .map
        cmp #25
        bcc .no
        cmp #33
        bcs .no
        lda #2
        sec
        rts
.map    lda #1
        sec
        rts
.run    lda #0
        sec
        rts
.no     clc
        rts

; Rueckfrage: Carry, A = 0 Ja / 1 Nein
!zone plan_hit_confirm
plan_hit_confirm
        jsr pr_mouse
        ldx pr_t
        cpx #17
        bne .no
        cmp #45
        bcc .no
        cmp #52
        bcc .yes
        cmp #54
        bcc .no
        cmp #60
        bcs .no
        lda #1
        sec
        rts
.yes    lda #0
        sec
        rts
.no     clc
        rts

; ---- Zeiger und Einfuegemarke (Planen, pro Frame) ----------------------------------
!zone spr_update
spr_init
        lda #$FF
        sta pr_mark
spr_update
        lda #$FF                ; Marke: Luecke insert_pos - scroll_offset, beim Verschieben aus
        ldx selection_active
        bne +
        lda insert_pos
        sec
        sbc scroll_offset
+       cmp pr_mark
        beq .ptr
        pha
        jsr pr_mark_erase       ; alte Marke weg
        pla
        sta pr_mark
        cmp #PROGRAM_ROWS
        bcs .ptr
        jsr pr_mark_y
        lda #<pr_mark_bits
        jsr pr_mark_put
        lda #1                  ; Farbe: 3 Attributbloecke (6 Pixelzeilen) ab der ersten Markenzeile
        sta vdc_w
        lda #3
        sta vdc_h
        lda #$0D
        jsr vt_attr_rect
.ptr    jmp vp_show

; Die Marke steht zwischen zwei Listenzeilen wie auf dem C64: Pfeil (5 Pixelzeilen) mit der
; Spitze auf der Oberkante der Zeile pr_mark, also vor dem Befehl, vor dem eingefuegt wird.
; Geschrieben werden nur diese 5 Bytes der Spalte PR_MARK_COL (Rahmenlinie darueber bleibt).
pr_mark_erase                   ; Marke pr_mark (falls sichtbar) loeschen
        lda pr_mark
        cmp #PROGRAM_ROWS
        bcs .r
        jsr pr_mark_y
        lda #<pr_mark_zero
pr_mark_put                     ; A = Low-Byte der 5 Musterbytes (pr_mark_bits/pr_mark_zero)
        sta .src+1
        jsr vp_hide
        ldy #0
-       sty pr_mk_i
        tya
        clc
        adc vt_y
        tax
        lda vl_lo,x
        clc
        adc #PR_MARK_COL
        tay
        lda vl_hi,x
        adc #0
        jsr vdc_addr
        ldy pr_mk_i
.src    lda pr_mark_bits,y
        jsr vdc_wr_data
        ldy pr_mk_i
        iny
        cpy #5
        bne -
.r      rts
pr_mark_y                       ; A = Zeile -> vt_y = erste Pixelzeile der Marke, vt_x
        clc
        adc #PR_LIST_ROW
        asl
        asl
        asl
        sec
        sbc #2
        sta vt_y
        lda #PR_MARK_COL
        sta vt_x
        rts

; ---- Run ---------------------------------------------------------------------------
draw_run_screen
        jsr pr_frame
        lda #1
        sta vw_mode
        jsr draw_title_and_counters
        jsr draw_run_field
        jsr draw_run_delivered
        lda #$FF
        sta pr_lscr
        jsr draw_run_list
        jsr draw_scrollbar
        jsr pr_info_clear
        jsr pr_mark_erase       ; Marke ist im Run aus
        lda #$FF
        sta pr_mark
        rts

; Liste im Lauf: bei gleichem Scrollstand nur die alte und die neue Zeile des laufenden
; Befehls neu (sonst die ganze Liste) - der Lauf ruft das bei jedem Befehl auf.
!zone draw_run_list
draw_run_list
        lda scroll_offset
        cmp pr_lscr
        bne .full
        lda run_cur
        cmp pr_lcur
        beq .done
        lda pr_lcur
        jsr .row
        lda run_cur
        sta pr_lcur
        jsr .row
.done   rts
.full   jsr draw_program_list
        lda scroll_offset
        sta pr_lscr
        lda run_cur
        sta pr_lcur
        rts
.row    sec                     ; A = absolute Nummer: Zeile neu, wenn sichtbar
        sbc scroll_offset
        bcc .done
        cmp #PROGRAM_ROWS
        bcs .done
        sta pr_row
        jmp pr_list_row

; Feld: alle Zellen aus map_work
!zone draw_run_field
draw_run_field
        jsr pr_sprites_hide
        lda #0
        sta ui_row
.r      lda #0
        sta ui_col
.c      jsr pr_cell
        inc ui_col
        lda ui_col
        cmp #MAP_COLS
        bne .c
        inc ui_row
        lda ui_row
        cmp #MAP_ROWS
        bne .r
        rts

; eine Zelle (ui_col, ui_row) neu
draw_run_cell
        jsr pr_sprites_hide
pr_cell
        lda ui_col
        sta tmp0
        lda ui_row
        sta tmp1
        jsr map_index
        lda #0
        sta wv_gold
        lda map_work,x
        beq .floor
        cmp #T_ICE
        bcc +
        adc #RUN_CELL_ICE-T_ICE-1   ; Carry ist 1
        bne .typed
+       cmp #T_BOXG
        bne .typed
        lda #$80                ; Kiste auf dem Ziel: goldene Kiste
        sta wv_gold
        lda #T_BOX
        bne .typed
.floor  ldx ui_row              ; Blumen: festes Muster
        lda ui_col
        and #7
        tay
        lda pr_flower_rows,x
        and run_bit_tab,y
        beq .typed
        lda #4
.typed  sta tmp3
        lda ui_col
        asl
        asl
        clc
        adc #PR_FIELD_COL
        sta wv_cc
        lda ui_row
        asl
        asl
        asl
        asl
        clc
        adc #PR_FIELD_Y
        sta wv_yy
        jsr wv_put_cell_at
        lda #0
        sta wv_gold
        rts

; unterer Feldrand: " Delivered: n/m "
!zone draw_run_delivered
draw_run_delivered
        ldx #MAP_CELLS-1
        lda #0
        sta pr_t
-       lda map_work,x
        cmp #T_BOXG
        bne +
        inc pr_t
+       dex
        bpl -
        jsr pr_clear_bottom_edge
        lda #3
        sta vt_x
        lda #21*8
        sta vt_y
        lda #$0F
        sta vt_col
        jsr vb_reset
        lda #' '
        jsr vb_char
        lda #<str_run_delivered
        ldx #>str_run_delivered
        jsr vb_str
        lda pr_t
        jsr pr_num1
        lda #'/'
        jsr vb_char
        lda goal_count
        jsr pr_num1
        lda #' '
        jsr vb_char
        jmp vt_print_buf
pr_num1 cmp #10
        bcs +
        ora #'0'
        jmp vb_char
+       jmp pr_num2

run_init_sprites
        jsr run_set_robot_image
        ; weiter

; Pro Frame im Run: Roboter (Slot 0) und Kiste/Schluessel (Slot 1, getragen oder im Flug)
!zone run_update_sprites
run_update_sprites
        lda #0                  ; Slot 0: Roboter allein (gemeinsames Sprite s. u.)
        sta ss_top
        lda run_sunk            ; eingebrochen: beide weg
        beq +
        lda #0
        sta pr_vis
        sta pr_vis+1
        jmp pr_sprites_draw
+       lda #1
        sta pr_vis
        lda vr_img
        sta ss_img
        lda run_spx             ; x = 8 + spx*2 Pixel
        jsr pr_xpos
        sta ss_col
        stx ss_sh
        lda run_spy             ; y = 8 + spy - 2 - Sprungbogen (>= 0, gerade)
        clc
        adc #PR_FIELD_Y-PR_ROBOT_DY
        ldx run_jump
        beq .ry
        ldx run_steps
        sec
        sbc run_arc,x
        bcs .ry
        lda #0
.ry     and #$FE
        sta ss_y
        lda #16                 ; Kiste oder Schluessel
        ldx run_item
        beq +
        lda #17
+       sta ss_img+1
        lda #0
        sta pr_vis+1
        lda run_carry
        beq .fly
        ldx #0                  ; getragen: Roboter und Kiste als ein Sprite (kein Flackern),
        lda run_walk            ; beim Schritt 2 Zeilen Abstand; passt es oben nicht, zwei Sprites
        beq +
        ldx #$40
+       stx pr_t
        lda ss_y
        sec
        sbc #PR_CHEST_DY
        bcc .two
        cpx #0
        beq +
        sbc #2
        bcc .two
+       sta ss_y
        lda ss_img+1
        ora pr_t
        sta ss_top
        jmp pr_sprites_draw
.two    lda ss_col
        sta ss_col+1
        lda ss_sh
        sta ss_sh+1
        lda ss_y                ; ueber dem Kopf, beim Schritt 2 Zeilen hoeher
        sec
        sbc #PR_CHEST_DY
        bcc .c0
        ldx run_walk
        beq .cy
        sbc #2
        bcs .cy
.c0     lda #0
.cy     and #$FE
        sta ss_y+1
        inc pr_vis+1
        bne pr_sprites_draw
.fly    lda run_fly
        beq pr_sprites_draw
        lda run_fx
        jsr pr_xpos
        sta ss_col+1
        stx ss_sh+1
        ldx run_fsteps          ; y = fy + 8 - 2 - 6 - Wurfbogen (Bogen darf negativ sein)
        lda run_throw_arc,x
        bmi .neg
        sta pr_t
        lda run_fy
        sec
        sbc pr_t
        bcs .fy
        lda #0
        beq .fy
.neg    eor #$FF
        sec
        adc run_fy
.fy     and #$FE
        sta ss_y+1
        inc pr_vis+1
        ; weiter

; Sprites zeichnen, wenn sich etwas geaendert hat (beide neu: sie koennen sich ueberlappen)
!zone pr_sprites_draw
pr_sprites_draw
        lda pr_force
        bne .redo
        ldx #1
-       lda pr_vis,x
        cmp ss_drawn,x
        bne .redo
        lda pr_vis,x
        beq +
        lda ss_img,x            ; sichtbar und gezeichnet: gleich?
        cmp pr_dimg,x
        bne .redo
        lda ss_col,x
        cmp ss_dc,x
        bne .redo
        lda ss_y,x
        cmp ss_dy,x
        bne .redo
        lda ss_sh,x
        cmp pr_dsh,x
        bne .redo
        lda ss_top,x
        cmp pr_dtop,x
        bne .redo
+       dex
        bpl -
        jmp vp_show
.redo   lda #0
        sta pr_force
        ldx #0                  ; gemeinsames Sprite vorher zusammensetzen
        jsr ss_prebuild
        lda pr_vis+1            ; nur der Roboter (ggf. mit Kiste) und schon im Bild:
        ora ss_drawn+1          ; flackerfrei verschieben
        bne .old
        lda pr_vis
        beq .old
        lda ss_drawn
        beq .old
        lda ss_top              ; nur mit Kiste/Schluessel (Roboter allein: altes Verfahren)
        ora pr_dtop             ; (auch beim Ablegen: altes Bild hatte noch die Kiste)
        beq .old
        lda ss_img
        sta pr_dimg
        lda ss_sh
        sta pr_dsh
        lda ss_top
        sta pr_dtop
        jsr ss_move
        jmp vp_show
.old    jsr ss_hide_all
        ldx #0
-       stx pr_t
        lda pr_vis,x
        beq +
        lda ss_img,x
        sta pr_dimg,x
        lda ss_sh,x
        sta pr_dsh,x
        lda ss_top,x
        sta pr_dtop,x
        jsr ss_draw
+       ldx pr_t
        inx
        cpx #2
        bne -
        jmp vp_show

; vor dem Zeichnen von Zellen: Figuren weg, beim naechsten Frame neu
pr_sprites_hide
        jsr ss_hide_all
        lda #1
        sta pr_force
        rts

; A = Feld-Einheiten x -> A = Spalte, X = Verschiebung (0/1)
pr_xpos pha                     ; Pixel = 8 + x*2: Spalte = x/4 + 1, Verschiebung = Bit 1
        lsr
        and #1
        tax
        pla
        lsr
        lsr
        clc
        adc #PR_FIELD_COL
        rts

; Schimmernde Ziele: alle 8 Frames Vordergrund Hellcyan der freien Zielzellen durch die
; naechste Farbe ersetzen (Attribute aus den Zelldaten im RAM). Zellen unter einer Figur
; bleiben aus (sonst stimmte deren Sicherung nicht mehr).
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
        lda pr_goal_cols,x
        sta run_gcol
        lda #0
        sta run_gi
.next   lda run_gi
        lsr
        cmp goal_count
        bcs .done
        ldx run_gi
        lda goal_list,x
        sta tmp0
        lda goal_list+1,x
        sta tmp1
        jsr map_index
        lda map_work,x
        cmp #T_GOAL
        bne .skip
        jsr pr_paint_goal
.skip   inc run_gi
        inc run_gi
        jmp .next
.done   rts

; tmp0/tmp1 = Zielzelle
!zone pr_paint_goal
pr_paint_goal
        lda tmp0
        asl
        asl
        clc
        adc #PR_FIELD_COL
        sta pr_gc
        lda tmp1
        asl
        asl
        asl
        asl
        clc
        adc #PR_FIELD_Y
        sta pr_gy
        ldx #1                  ; unter einer Figur? (Rechtecke ueberlappen)
-       lda ss_drawn,x
        beq .free
        lda ss_dc,x             ; dc < gc+4 und gc < dc+5
        sec
        sbc pr_gc
        bcs +
        eor #$FF                ; gc - dc
        adc #1
        cmp #5
        bcs .free
        bcc .y
+       cmp #4
        bcs .free
.y      lda ss_dy,x             ; dy < gy+16 und gy < dy+h
        clc
        adc ss_dh,x
        cmp pr_gy
        bcc .free
        beq .free
        lda pr_gy
        clc
        adc #16
        cmp ss_dy,x
        bcc .free
        beq .free
        rts                     ; verdeckt: diesmal nicht
.free   dex
        bpl -
        jsr vp_hide
        lda wv_cells            ; Attribute der Zielzelle des Themes (gfx_vdc.asm)
        sta pr_a
        lda wv_cells+1
        sta pr_a+1
        lda pr_gy
        lsr
        sta pr_t
        ldy #0
.row    ldx pr_t
        lda al_lo,x
        clc
        adc pr_gc
        sta pr_t2
        lda al_hi,x
        adc #0
        +vwr 18
        lda pr_t2
        +vwr 19
        ldx #31
        stx VDC_REG
        lda #4
        sta pr_n
-       lda (pr_a),y
        pha                     ; Nibble 7 (Hellcyan) -> run_gcol
        and #$0F
        cmp #7
        bne +
        lda run_gcol
+       sta pr_t2
        pla
        and #$F0
        cmp #$70
        bne +
        lda run_gcol
        asl
        asl
        asl
        asl
+       ora pr_t2
        +vdc_wait
        sta VDC_DATA
        iny
        dec pr_n
        bne -
        inc pr_t
        cpy #32
        bne .row
        rts

pr_goal_cols !byte 7, 15, 7, 11

; Hoehe ueber dem Boden je Restframe (wie VIC-View): Sprung, Wurf (Wurf sinkt 5 Pixel)
run_arc       !byte 0, 2, 4, 6, 8, 9, 10, 10, 10, 10, 10, 9, 8, 6, 4, 2, 0
run_throw_arc !byte 256-5, 256-2, 1, 3, 5, 7, 8, 8, 9, 9, 9, 9, 8, 6, 4, 2, 0

; ---- Daten -----------------------------------------------------------------------
pr_grid_cmd     !byte 4, 0, 5,  3, 1, 2,  7, 6, 8       ; Q W E / A S D / Z X C
pr_key_char     !text "wsdaqexzc"                        ; je Befehl 0..8
pr_cmd_col      !byte $0F, $0F, $07, $07, $05, $0B, $07, $0F, $0B
pr_names        !word pr_n_fwd, pr_n_back, pr_n_right, pr_n_left, pr_n_pick, pr_n_drop
                !word pr_n_180, pr_n_jump, pr_n_throw
pr_n_fwd        !text "Move Fwd",0
pr_n_back       !text "Move Back",0
pr_n_right      !text "Turn Right",0
pr_n_left       !text "Turn Left",0
pr_n_pick       !text "Pick Up",0
pr_n_drop       !text "Drop Off",0
pr_n_180        !text "Turn 180",0
pr_n_jump       !text "Jump",0
pr_n_throw      !text "Throw",0
pr_leg_ids      !byte T_GOAL, T_BOX, T_WALL, T_WATER, T_ICE, T_KEY, T_LOCK, T_DOOR
pr_leg_cell     !byte 3, 2, 1, 5, 10, 12, 13, 15            ; Mini-Zelle je Eintrag
pr_leg_text     !word str_leg_goal, str_leg_box, str_leg_tree, str_leg_water
                !word str_leg_ice, str_leg_key, str_leg_lock, str_leg_door
pr_dir_ptrs     !word str_leg_right, str_leg_left, str_leg_up, str_leg_down
pr_dirname      !word str_dir_right, str_dir_left, str_dir_up, str_dir_down
pr_map_text     !word 0, str_blocker, str_package, str_target, str_package_done, str_water
                !word str_ice, str_water, str_key, str_lock, str_lock, str_door
pr_info_col     !byte $0F, $05, $0D, $07, $0D, $07, $07, $07, $0D, $0D, $0D, $0D
pr_flower_rows  !byte %00100001, %00000100, %01000000, %00010010, %00000000
                !byte %10000100, %00000001, %00101000, %00000000, %01000010
str_pr_legend   !text " Legend ",0
str_pr_commands !text " Commands ",0
str_pr_program  !text " Program   /99 ",0
str_pr_plan     !text " - Plan ",0
str_pr_run      !text " - Run  ",0
str_pr_footer   !text "Space:Go/Pause  F7:Map  F8:Title   R:Restart  Ret:Grab  Del:Delete",0

pr_vis   !byte 0, 0             ; gewuenscht sichtbar: Roboter, Kiste
pr_dimg  !byte 0, 0             ; gezeichnet mit Bild / Verschiebung
pr_dsh   !byte 0, 0
pr_dtop  !byte 0, 0
pr_force !byte 0
pr_mark  !byte $FF              ; Luecke der Einfuegemarke ($FF = keine)
pr_mk_i  !byte 0
pr_mark_bits !byte %11110000,%11111100,%11111111,%11111100,%11110000
pr_mark_zero !byte 0,0,0,0,0
!if >pr_mark_bits != >pr_mark_zero { !error "pr_mark_bits/zero: gleiche Seite noetig" }
pr_lscr  !byte $FF              ; Lauf-Liste: gezeichnet mit Scrollstand / laufendem Befehl
pr_lcur  !byte $FF
pr_sh_idx !fill PROGRAM_ROWS, $FE
pr_sh_st  !fill PROGRAM_ROWS, 0
pr_row   !byte 0
pr_i     !byte 0
pr_t     !byte 0
pr_t2    !byte 0
pr_n     !byte 0
pr_cmd   !byte 0
pr_gc    !byte 0
pr_gy    !byte 0
