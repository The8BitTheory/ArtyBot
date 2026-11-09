; text.asm (VDC-View) - Text und Flaechen im Bitmap 640x200: Glyphen aus VDC_FONT (Index =
; Screencode), Farbe ueber die Attribute (8x2-Bloecke). Koordinaten: Spalte 0..79 (8 Pixel),
; Pixelzeile 0..199 (gerade, damit die Attribute passen). Alle Zeichenroutinen nehmen vorher
; den Software-Zeiger vom Bild (vp_hide), title_pointer & Co. setzen ihn wieder.

GL_TL = $70                     ; Rahmenglyphen in VDC_FONT (Screencodes $70-$77, aus ASCII nie erzeugt)
GL_T  = $71
GL_TR = $72
GL_L  = $73
GL_R  = $74
GL_BL = $75
GL_B  = $76
GL_BR = $77
GL_HAND = $78                   ; Zeigehand (2 Glyphen breit: $78, $79)
GL_FULL = $7A                   ; volles Feld

; ASCII -> Screencode (Gross-/Kleinbuchstaben-Satz): a-z -> 1..26, A-Z bleibt $41-$5A.
!zone ascii2scr
ascii2scr
        cmp #$61
        bcc .done
        cmp #$7B
        bcs .done
        sbc #$5F                ; Carry ist 0: -$60
.done   rts

; Beim Start: eigene Glyphen in die Zeichensatz-Kopie.
!zone vt_init
vt_init
        ldx #vt_glyphs_end - vt_glyphs - 1
-       lda vt_glyphs,x
        sta VDC_FONT + GL_TL*8,x
        dex
        bpl -
        rts

; A/X = 0-terminierter ASCII-Text an (vt_x, vt_y) in vt_col; vt_wide = 1: doppelt breit.
; Danach vt_x hinter dem Text.
!zone vt_print
vt_print
        sta vt_ptr
        stx vt_ptr+1
        ldy #0
-       lda (vt_ptr),y
        beq +
        jsr ascii2scr
        sta vt_buf,y
        iny
        cpy #80
        bne -
+       sty vt_len
; vt_buf[0..vt_len-1] = Screencodes
vt_print_buf
        lda vt_len
        bne +
        rts
+       jsr vp_hide
        ldx #0                  ; Glyphadressen
-       lda vt_buf,x
        sta vt_tmp
        lda #0
        asl vt_tmp
        rol
        asl vt_tmp
        rol
        asl vt_tmp
        rol
        adc #>VDC_FONT
        sta vt_ghi,x
        lda vt_tmp
        sta vt_glo,x
        inx
        cpx vt_len
        bne -
        lda #0
        sta vdc_n               ; Glyphzeile
.line   lda vt_y
        clc
        adc vdc_n
        tax
        lda vl_lo,x
        clc
        adc vt_x
        tay
        lda vl_hi,x
        adc #0
        jsr vdc_addr
        ldx #0
.ch     lda vt_glo,x
        sta vt_ptr2
        lda vt_ghi,x
        sta vt_ptr2+1
        ldy vdc_n
        lda (vt_ptr2),y
        ldy vt_wide
        bne .wide
        +vdc_wait
        sta VDC_DATA
        inx
        cpx vt_len
        bne .ch
        beq .next
.wide   tay
        lsr
        lsr
        lsr
        lsr
        sta vt_tmp
        tya
        and #$0F
        tay
        lda vt_dbl,y
        pha
        ldy vt_tmp
        lda vt_dbl,y
        +vdc_wait
        sta VDC_DATA
        pla
        +vdc_wait
        sta VDC_DATA
        inx
        cpx vt_len
        bne .ch
.next   inc vdc_n
        lda vdc_n
        cmp #8
        bne .line
        lda vt_len              ; Attribute: 4 Blockzeilen, Breite = Zeichen (x2 breit)
        ldx vt_wide
        beq +
        asl
+       sta vdc_w
        pha
        lda #4
        sta vdc_h
        lda vt_col
        jsr vt_attr_rect
        pla
        clc
        adc vt_x
        sta vt_x
        rts

; Attribut-Rechteck: ab Spalte vt_x, Pixelzeile vt_y (gerade), vdc_w Spalten, vdc_h Blockzeilen,
; A = Attribut.
!zone vt_attr_rect
vt_attr_rect
        pha
        lda vt_y
        lsr
        tax
        lda al_lo,x
        clc
        adc vt_x
        sta vdc_dst
        lda al_hi,x
        adc #0
        sta vdc_dst+1
        pla
        jmp vdc_rect_fill

; Bitmap-Rechteck mit A fuellen: ab vt_x, vt_y, vdc_w Spalten, vdc_h Pixelzeilen.
!zone vt_bits_rect
vt_bits_rect
        pha
        jsr vp_hide
        ldx vt_y
        lda vl_lo,x
        clc
        adc vt_x
        sta vdc_dst
        lda vl_hi,x
        adc #0
        sta vdc_dst+1
        pla
        jmp vdc_rect_fill

; Flaeche leeren: vt_x, vt_y, vdc_w Spalten, vdc_h Pixelzeilen (gerade); Attribut A.
!zone vt_clear
vt_clear
        pha
        lda vdc_h
        pha
        lda #0
        jsr vt_bits_rect
        pla
        lsr
        sta vdc_h
        pla
        jmp vt_attr_rect

; Rahmen (Fenster): Spalte vt_x, Textzeile Y (8 Pixel), Breite vt_fw, Hoehe vt_fh Textzeilen,
; Attribut vt_col. Das Innere wird geleert (Attribut vt_fill).
!zone vt_frame
vt_frame
        sty vt_fy
        lda vt_x
        sta vt_fx
        tya
        asl
        asl
        asl
        sta vt_y
        lda #GL_TL
        ldx #GL_T
        ldy #GL_TR
        jsr .row
        lda vt_fh
        sec
        sbc #2
        sta vt_fn
        beq .bottom
.mid    lda vt_y
        clc
        adc #8
        sta vt_y
        lda vt_fx
        sta vt_x
        lda #GL_L               ; Rand links
        sta vt_buf
        lda #1
        sta vt_len
        jsr vt_print_buf
        lda vt_fx               ; Rand rechts
        clc
        adc vt_fw
        sec
        sbc #1
        sta vt_x
        lda #GL_R
        sta vt_buf
        lda #1
        sta vt_len
        jsr vt_print_buf
        dec vt_fn
        bne .mid
        lda vt_fy               ; Inneres leeren
        asl
        asl
        asl
        clc
        adc #8
        sta vt_y
        ldx vt_fx
        inx
        stx vt_x
        lda vt_fw
        sec
        sbc #2
        sta vdc_w
        lda vt_fh
        sec
        sbc #2
        asl
        asl
        asl
        sta vdc_h
        lda vt_fill
        jsr vt_clear
        lda vt_fy
        clc
        adc vt_fh
        sec
        sbc #1
        asl
        asl
        asl
        sta vt_y
.bottom lda vt_fy
        clc
        adc vt_fh
        sec
        sbc #1
        asl
        asl
        asl
        sta vt_y
        lda #GL_BL
        ldx #GL_B
        ldy #GL_BR
.row    sta vt_buf              ; A links, X Mitte, Y rechts
        txa
        ldx vt_fw
        dex
-       sta vt_buf,x
        dex
        bne -
        ldx vt_fw
        dex
        tya
        sta vt_buf,x
        lda vt_fw
        sta vt_len
        lda vt_fx
        sta vt_x
        jmp vt_print_buf

; Bild aus RAM: A/X = Bild (Breite in Bytes, Hoehe, dann gepackt: Bitmap, Attribute; Format
; siehe tools/gen_vdc_title.py), Ziel vt_x, vt_y (gerade).
!zone vt_image
vt_image
        sta vt_ptr
        stx vt_ptr+1
        jsr vp_hide
        ldy #0
        lda (vt_ptr),y
        sta vdc_w
        iny
        lda (vt_ptr),y
        sta vdc_h
        lda vt_ptr              ; gepackte Daten hinter dem Kopf
        clc
        adc #2
        sta vt_ptr
        bcc +
        inc vt_ptr+1
+       lda #0
        sta vt_run
        sta vt_lit
        lda vt_y                ; Bitmap: vdc_h Zeilen
        sta vt_tmp
        lda vdc_h
        sta vt_fn
.br     ldx vt_tmp
        lda vl_lo,x
        clc
        adc vt_x
        tay
        lda vl_hi,x
        adc #0
        jsr .row
        inc vt_tmp
        dec vt_fn
        bne .br
        lda vt_y                ; Attribute: vdc_h/2 Blockzeilen
        lsr
        sta vt_tmp
        lda vdc_h
        lsr
        sta vt_fn
.ar     ldx vt_tmp
        lda al_lo,x
        clc
        adc vt_x
        tay
        lda al_hi,x
        adc #0
        jsr .row
        inc vt_tmp
        dec vt_fn
        bne .ar
        rts
.row    jsr vdc_addr            ; A/Y = Adresse, dann vdc_w Bytes entpacken
        ldx vdc_w
-       jsr vt_unpack
        +vdc_wait
        sta VDC_DATA
        dex
        bne -
        rts

; naechstes entpacktes Byte -> A (X, Y bleiben)
vt_unpack
        lda vt_run              ; laufende Wiederholung?
        beq .nr
        dec vt_run
        lda vt_val
        rts
.nr     lda vt_lit              ; laufende Literale?
        beq .ctl
        dec vt_lit
        sty vt_sy
        ldy #0
        lda (vt_ptr),y
        ldy vt_sy
        jmp .adv
.ctl    sty vt_sy
        ldy #0
        lda (vt_ptr),y
        bmi .rep
        sta vt_lit              ; c+1 Literale: eines sofort, c weitere
        jsr .inc
        lda (vt_ptr),y
        ldy vt_sy
        jmp .adv
.rep    sec
        sbc #$7E                ; (c-$7D)-mal: eines sofort, Rest in vt_run
        sta vt_run
        jsr .inc
        lda (vt_ptr),y
        sta vt_val
        ldy vt_sy
.adv    inc vt_ptr
        bne +
        inc vt_ptr+1
+       rts
.inc    inc vt_ptr
        bne +
        inc vt_ptr+1
+       rts

; A/X = Text, Y = Textzeile: zentriert in vt_col (normal breit).
!zone vt_center
vt_center
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
+       tya
        lsr
        sta vt_tmp
        lda #40
        sec
        sbc vt_tmp
        sta vt_x
        lda vt_ptr
        ldx vt_ptr+1
        jmp vt_print

; ---- Tabellen --------------------------------------------------------------------
vl_lo   !for i, 200 { !byte <(VDC_BITMAP + (i-1)*80) }
vl_hi   !for i, 200 { !byte >(VDC_BITMAP + (i-1)*80) }
al_lo   !for i, 100 { !byte <(VDC_ATTR + (i-1)*80) }
al_hi   !for i, 100 { !byte >(VDC_ATTR + (i-1)*80) }
vt_dbl  !for i, 16 {            ; 4 Bit -> 8 Bit, jedes Bit doppelt
            !byte (((i-1)&8)*24) | (((i-1)&4)*12) | (((i-1)&2)*6) | (((i-1)&1)*3)
        }

; Rahmen: 4 Pixel breite senkrechte, 2 Zeilen hohe waagrechte Linien (gleich dick auf dem
; Bildschirm), abgerundete Ecken.
vt_glyphs
        !byte %00000000,%00000000,%00000000,%00001111,%00111111,%00111100,%00111100,%00111100 ; TL
        !byte %00000000,%00000000,%00000000,%11111111,%11111111,%00000000,%00000000,%00000000 ; T
        !byte %00000000,%00000000,%00000000,%11110000,%11111100,%00111100,%00111100,%00111100 ; TR
        !byte %00111100,%00111100,%00111100,%00111100,%00111100,%00111100,%00111100,%00111100 ; L
        !byte %00111100,%00111100,%00111100,%00111100,%00111100,%00111100,%00111100,%00111100 ; R
        !byte %00111100,%00111100,%00111100,%00111111,%00001111,%00000000,%00000000,%00000000 ; BL
        !byte %00000000,%00000000,%00000000,%11111111,%11111111,%00000000,%00000000,%00000000 ; B
        !byte %00111100,%00111100,%00111100,%11111100,%11110000,%00000000,%00000000,%00000000 ; BR
        !byte %00000011,%00000111,%00000111,%11111111,%11111111,%11111111,%01111111,%00111111 ; Hand links
        !byte %00000000,%11111000,%00000000,%11111110,%00000000,%11100000,%11000000,%10000000 ; Hand rechts
        !byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF                                                ; voll
vt_glyphs_end

vt_buf  !fill 80, 0
vt_glo  !fill 80, 0
vt_ghi  !fill 80, 0
vt_fx   !byte 0
vt_fy   !byte 0
vt_fw   !byte 0
vt_fh   !byte 0
vt_fn   !byte 0
vt_fill !byte $00
vt_run  !byte 0
vt_lit  !byte 0
vt_val  !byte 0
vt_sy   !byte 0

; ---- Zeilenpuffer: Text in vt_buf zusammensetzen, dann vt_print_buf ------------------
vb_reset
        lda #0
        sta vt_len
        rts

; A/X = ASCII-Text anhaengen
!zone vb_str
vb_str  sta vt_ptr
        stx vt_ptr+1
        ldy #0
-       lda (vt_ptr),y
        beq +
        jsr vb_char
        iny
        bne -
+       rts

; A = ASCII-Zeichen anhaengen (Y bleibt)
vb_char jsr ascii2scr
        ldx vt_len
        sta vt_buf,x
        inc vt_len
        rts

; A = Zahl 0..255 rechtsbuendig in 3 Zeichen
!zone vb_num3
vb_num3 ldy #0
        sty vt_nz
        ldy #100
        jsr .dig
        ldy #10
        jsr .dig
        ora #'0'
        jmp vb_char
.dig    sty vt_tmp
        ldy #0
-       cmp vt_tmp
        bcc +
        sbc vt_tmp
        iny
        bne -
+       pha
        tya
        bne .show
        ldx vt_nz
        bne .show
        lda #' '
        bne .out
.show   inc vt_nz
        ora #'0'
.out    jsr vb_char
        pla
        rts

vb_dash3
        lda #' '
        jsr vb_char
        lda #' '
        jsr vb_char
        lda #'-'
        jmp vb_char

; A = Level (Index in plan_level_table): "Name n" anhaengen
!zone vb_level_name
vb_level_name
        sta vt_lvl
        ldx #0
.w      stx vt_wi
        txa
        asl
        tax
        lda world_table,x
        sta vt_ptr2
        lda world_table+1,x
        sta vt_ptr2+1
        ldy #WREC_FIRST
        lda vt_lvl
        sec
        sbc (vt_ptr2),y
        bcc .next
        iny
        cmp (vt_ptr2),y
        bcs .next
        clc
        adc #'1'
        pha
        ldy #WREC_NAME
        lda (vt_ptr2),y
        pha
        iny
        lda (vt_ptr2),y
        tax
        pla
        jsr vb_str
        lda #' '
        jsr vb_char
        pla
        jmp vb_char
.next   ldx vt_wi
        inx
        cpx #world_count
        bcc .w
        rts

vt_nz   !byte 0
vt_lvl  !byte 0
vt_wi   !byte 0
