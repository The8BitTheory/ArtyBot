; sprite.asm (VDC-View) - Software-Sprites (Roboter, Kiste, Schluessel) im Bitmap.
; Bilder aus gfx_vdc.asm (tools/gen_vdc_gfx.py): H Zeilen x 5 Bytes Tinte, danach H/2 x 5
; Attribute je 8x2-Block: $FF leer (Kachel bleibt), 0 Randblock Figurfarbe auf der Grundfarbe
; der Kachel, $80 Randblock schwarz auf der Grundfarbe, sonst fertiges Attribut.
; Position: Spalte (Byte) + Verschiebung 0/4 Pixel, Zeile gerade. Vor dem Zeichnen wird der
; Hintergrund (Bitmap + Attribute) gesichert, ss_hide schreibt ihn zurueck.
; Reihenfolge pro Frame: Zeiger weg, Sprites rueckwaerts weg, neu zeichnen, Zeiger an.

SS_MAX   = 2
SS_W     = 5
SS_HMAX  = 18
SS_BM    = SS_W*SS_HMAX         ; gesicherte Bitmap-Bytes je Sprite
SS_AT    = SS_W*SS_HMAX/2

ss_p     = $90                  ; Bilddaten
ss_b     = $92                  ; Sicherung Bitmap
ss_a     = $94                  ; Sicherung Attribute

; X = Sprite: Zeiger auf seine Sicherungen
!zone ss_bufs
ss_bufs lda ss_buf_lo,x
        sta ss_b
        lda ss_buf_hi,x
        sta ss_b+1
        lda ss_buf_lo,x
        clc
        adc #SS_BM
        sta ss_a
        lda ss_buf_hi,x
        adc #0
        sta ss_a+1
        rts

; Bildschirm wurde geloescht: kein Sprite steht mehr im Bild
ss_forget
        lda #0
        ldx #SS_MAX-1
-       sta ss_drawn,x
        dex
        bpl -
        rts

; alle Sprites vom Bild (in umgekehrter Reihenfolge)
ss_hide_all
        ldx #SS_MAX-1
-       stx ss_cur
        jsr ss_hide
        ldx ss_cur
        dex
        bpl -
        rts

; X = Sprite: vom Bild nehmen (falls gezeichnet)
!zone ss_hide
ss_hide lda ss_drawn,x
        bne +
        rts
+       lda #0
        sta ss_drawn,x
        jsr ss_bufs
        lda ss_dh,x
        sta ss_h
        lda ss_dy,x
        sta ss_yy
        lda ss_dc,x
        sta ss_cc
        jsr ss_ptr_check
        lda #0
        sta ss_i
        sta ss_o
.bl     jsr ss_bm_addr
        ldy ss_o
        ldx #SS_W
-       lda (ss_b),y
        +vdc_wait
        sta VDC_DATA
        iny
        dex
        bne -
        sty ss_o
        inc ss_i
        lda ss_i
        cmp ss_h
        bne .bl
        lda #0
        sta ss_i
        sta ss_o
.al     jsr ss_at_addr
        ldy ss_o
        ldx #SS_W
-       lda (ss_a),y
        +vdc_wait
        sta VDC_DATA
        iny
        dex
        bne -
        sty ss_o
        inc ss_i
        lda ss_i
        asl
        cmp ss_h
        bne .al
        rts

; X = Sprite: an ss_col/ss_sh/ss_y,x mit Bild ss_img,x zeichnen (vorher ss_hide!)
!zone ss_draw
ss_draw stx ss_cur
        jsr ss_bufs
        lda ss_img,x            ; Bilddaten: Bild*2 + Verschiebung
        asl
        ora ss_sh,x
        tay
        lda vdc_spr_lo,y
        sta ss_p
        lda vdc_spr_hi,y
        sta ss_p+1
        ldy ss_img,x
        lda vdc_spr_h,y
        sta ss_h
        sta ss_dh,x
        lda vdc_spr_col,y
        sta ss_fc
        lda ss_y,x
        sta ss_yy
        sta ss_dy,x
        lda ss_col,x
        sta ss_cc
        sta ss_dc,x
        lda #1
        sta ss_drawn,x
        jsr ss_ptr_check
        ; Hintergrund sichern: Bitmap-Zeilen
        lda #0
        sta ss_i
        sta ss_o
.rb     jsr ss_bm_addr
        ldy ss_o
        ldx #SS_W
-       +vdc_wait
        lda VDC_DATA
        sta (ss_b),y
        iny
        dex
        bne -
        sty ss_o
        inc ss_i
        lda ss_i
        cmp ss_h
        bne .rb
        ; Attribut-Zeilen
        lda #0
        sta ss_i
        sta ss_o
.ra     jsr ss_at_addr
        ldy ss_o
        ldx #SS_W
-       +vdc_wait
        lda VDC_DATA
        sta (ss_a),y
        iny
        dex
        bne -
        sty ss_o
        inc ss_i
        lda ss_i
        asl
        cmp ss_h
        bne .ra
        ; Attribute zusammensetzen (ss_na) und schreiben. Bilddaten: Tinte ab 0, Attribute ab H*5
        lda ss_h
        asl
        asl
        adc ss_h                ; H*5 (H <= 18, kein Uebertrag)
        sta ss_ao
        sta ss_h5
        lda #0
        sta ss_i
        sta ss_o
.wa     jsr ss_at_addr
        ldx #0
.wak    ldy ss_ao
        lda (ss_p),y            ; Code des Blocks
        ldy ss_o
        cmp #$FF
        beq .keep
        cmp #0
        beq .edge
        cmp #$80
        beq .edge0
        bne .put                ; fertiges Attribut
.edge   lda (ss_a),y            ; Grundfarbe der Kachel + Figurfarbe
        and #$F0
        ora ss_fc
        jmp .put
.edge0  lda (ss_a),y            ; Grundfarbe + schwarz
        and #$F0
        jmp .put
.keep   lda (ss_a),y
.put    +vdc_wait
        sta VDC_DATA
        inc ss_ao
        inc ss_o
        inx
        cpx #SS_W
        bne .wak
        inc ss_i
        lda ss_i
        asl
        cmp ss_h
        bne .wa
        ; Bitmap: Tinte, in leeren Bloecken ($FF) die gesicherten Bytes
        lda #0
        sta ss_i
        sta ss_o
        sta ss_ao               ; Index der Tinte
.wb     jsr ss_bm_addr
        lda ss_i                ; Code-Index = H*5 + (Zeile/2)*5
        lsr
        sta ss_t
        asl
        asl
        adc ss_t
        clc
        adc ss_h5
        sta ss_t
        ldx #0
.wbk    ldy ss_t
        lda (ss_p),y
        cmp #$FF
        bne .ink
        ldy ss_o
        lda (ss_b),y            ; leer: Kachel unveraendert
        jmp .wr
.ink    ldy ss_ao
        lda (ss_p),y
.wr     +vdc_wait
        sta VDC_DATA
        inc ss_ao
        inc ss_o
        inc ss_t
        inx
        cpx #SS_W
        bne .wbk
        inc ss_i
        lda ss_i
        cmp ss_h
        bne .wb
        ldx ss_cur
        rts

; Zeiger nur wegnehmen, wenn er das Rechteck (ss_cc, ss_yy, 5 Spalten, ss_h Zeilen) beruehrt
; (sonst flackert er bei jeder Bewegung der Figur). X bleibt.
!zone ss_ptr_check
ss_ptr_check
        lda vp_x
        cmp #$FF
        beq .no
        clc                     ; vp_x+3 > cc  und  vp_x < cc+5
        adc #3
        cmp ss_cc
        bcc .no
        beq .no
        lda ss_cc
        clc
        adc #SS_W
        cmp vp_x
        bcc .no
        beq .no
        lda vp_y                ; vp_y+8 > yy  und  vp_y < yy+h
        clc
        adc #VP_LINES
        cmp ss_yy
        bcc .no
        beq .no
        lda ss_yy
        clc
        adc ss_h
        cmp vp_y
        bcc .no
        beq .no
        stx ss_t
        jsr vp_hide
        ldx ss_t
.no     rts

; Adressen der Zeile ss_i (Bitmap) bzw. Blockzeile ss_i (Attribute) an Spalte ss_cc
ss_bm_addr
        lda ss_yy
        clc
        adc ss_i
        tax
        lda vl_lo,x
        clc
        adc ss_cc
        tay
        lda vl_hi,x
        adc #0
        jmp vdc_addr
ss_at_addr
        lda ss_yy
        lsr
        clc
        adc ss_i
        tax
        lda al_lo,x
        clc
        adc ss_cc
        tay
        lda al_hi,x
        adc #0
        jmp vdc_addr

ss_buf_lo !byte <(VDC_SAVE+$100), <(VDC_SAVE+$200)
ss_buf_hi !byte >(VDC_SAVE+$100), >(VDC_SAVE+$200)

ss_drawn !fill SS_MAX, 0        ; 1 = steht im Bild (Hintergrund gesichert)
ss_dc    !fill SS_MAX, 0        ; gezeichnet an: Spalte, Zeile, Hoehe
ss_dy    !fill SS_MAX, 0
ss_dh    !fill SS_MAX, 0
ss_img   !fill SS_MAX, 0        ; gewuenscht: Bild, Spalte, Verschiebung (0/1), Zeile
ss_col   !fill SS_MAX, 0
ss_sh    !fill SS_MAX, 0
ss_y     !fill SS_MAX, 0
ss_cur   !byte 0
ss_h     !byte 0
ss_yy    !byte 0
ss_cc    !byte 0
ss_i     !byte 0
ss_o     !byte 0
ss_ao    !byte 0
ss_t     !byte 0
ss_v     !byte 0
ss_fc    !byte 0
ss_h5    !byte 0
