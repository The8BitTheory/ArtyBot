; sprite.asm (VDC-View) - Software-Sprites (Roboter, Kiste, Schluessel) im Bitmap.
; Bilder: Tinte (H Zeilen x 5 Byte, Verschiebung 0/4 Pixel) liegt in der Ablage (store.asm);
; die Block-Codes (H/2 x 5) liest die CPU aus dem RAM-Bild (gfx_vdc.asm):
;   $FF leer (Kachel bleibt), 0 Figurfarbe auf der Grundfarbe des Blocks, $80 schwarz auf der
;   Grundfarbe, sonst fertiges Attribut. Grundfarbe = Hintergrund (hohes Nibble) des Blocks
;   darunter; andere Farben der Kachel in Randbloecken fallen weg (z. B. Gruen auf braunem Weg).
; Warum nicht je Grundfarbe vorberechnet: das Ergebnis haengt nur am Attribut-Byte (Grundfarbe
; OR Figurfarbe), die Tinte ist fuer jede Grundfarbe gleich. 45 Attribute rechnen kostet weniger
; als 16 Farbvarianten zu je 4,9 KB in der Ablage.
;
; Zeichnen: Hintergrund per Block-Copy VRAM -> VRAM sichern (ST_SAVE), Attribute der Sicherung
; lesen, neue Attribute schreiben, Tinte je Zeile in Laeufen nicht-leerer Bloecke per Block-Copy.
; Wegnehmen: Sicherung per Block-Copy zurueck.

SS_MAX   = 2
SS_W     = 5

ss_p     = $90                  ; RAM-Bild (Codes ab H*5)
ss_ra    = $92                  ; laufende Zeilenadresse im VRAM
ss_q     = $94                  ; Laeufe der Blockzeilen
ss_c     = $9C                  ; Codes im RAM-Bild ($9C/$9D)

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

; X = Sprite: Quelle/Ziel der Sicherung -> ss_sv
ss_save_addr
        ldx ss_cur
        lda ss_sv_lo,x
        sta ss_sv
        lda ss_sv_hi,x
        sta ss_sv+1
        rts

; Zeile weiter: ss_ra += 80
!macro ss_next {
        lda ss_ra
        clc
        adc #80
        sta ss_ra
        bcc +
        inc ss_ra+1
+
}
; ss_ra = Bitmapzeile ss_yy (bzw. Attributzeile ss_yy/2) + Spalte ss_cc
!macro ss_row_bm {
        ldx ss_yy
        lda vl_lo,x
        clc
        adc ss_cc
        sta ss_ra
        lda vl_hi,x
        adc #0
        sta ss_ra+1
}
!macro ss_row_at {
        lda ss_yy
        lsr
        tax
        lda al_lo,x
        clc
        adc ss_cc
        sta ss_ra
        lda al_hi,x
        adc #0
        sta ss_ra+1
}

; X = Sprite: vom Bild nehmen (falls gezeichnet). Quelle = Sicherung (zaehlt weiter),
; je Zeile nur Ziel und R30.
!zone ss_hide
ss_hide stx ss_cur
        lda ss_drawn,x
        bne +
        rts
+       lda #0
        sta ss_drawn,x
        lda ss_dh,x
        sta ss_h
        lda ss_dy,x
        sta ss_yy
        lda ss_dc,x
        sta ss_cc
        jsr ss_ptr_check
        jsr ss_save_addr
        jsr vdc_mode_copy
        lda ss_sv+1
        +vwr 32
        lda ss_sv
        +vwr 33
        +ss_row_bm
        lda ss_h
        sta ss_n
.bl     lda ss_ra+1
        +vwr 18
        lda ss_ra
        +vwr 19
        lda #SS_W
        +vwr 30
        +ss_next
        dec ss_n
        bne .bl
        +ss_row_at
        lda ss_h
        lsr
        sta ss_n
.al     lda ss_ra+1
        +vwr 18
        lda ss_ra
        +vwr 19
        lda #SS_W
        +vwr 30
        +ss_next
        dec ss_n
        bne .al
        ldx ss_cur
        rts

; X = Sprite: an ss_col/ss_sh/ss_y,x mit Bild ss_img,x zeichnen (vorher ss_hide!)
!zone ss_draw
ss_draw stx ss_cur
        lda ss_img,x            ; Bild*2 + Verschiebung
        asl
        ora ss_sh,x
        sta ss_ix
        tay
        lda vdc_spr_lo,y
        sta ss_p
        lda vdc_spr_hi,y
        sta ss_p+1
        lda ss_st_lo,y
        sta ss_ink
        lda ss_st_hi,y
        sta ss_ink+1
        lda ss_span_lo,y        ; Laeufe der Blockzeilen (vs_init)
        sta ss_q
        lda ss_span_hi,y
        sta ss_q+1
        ldy ss_img,x
        lda vdc_spr_h,y
        sta ss_h
        sta ss_dh,x
        asl
        asl
        adc ss_h
        sta ss_h5               ; Codes ab H*5
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
        jsr ss_save_addr
        ; 1. Hintergrund sichern: Ziel = Sicherung (zaehlt weiter), je Zeile Quelle + R30
        jsr vdc_mode_copy
        lda ss_sv+1
        +vwr 18
        lda ss_sv
        +vwr 19
        +ss_row_bm
        lda ss_h
        sta ss_n
.sb     lda ss_ra+1
        +vwr 32
        lda ss_ra
        +vwr 33
        lda #SS_W
        +vwr 30
        +ss_next
        dec ss_n
        bne .sb
        +ss_row_at
        lda ss_h
        lsr
        sta ss_n
.sa     lda ss_ra+1
        +vwr 32
        lda ss_ra
        +vwr 33
        lda #SS_W
        +vwr 30
        +ss_next
        dec ss_n
        bne .sa
        ; 2. gesicherte Attribute lesen (hinter der Bitmap-Sicherung)
        lda ss_sv
        clc
        adc ss_h5
        tay
        lda ss_sv+1
        adc #0
        +vwr 18
        tya
        +vwr 19
        ldx #31
        stx VDC_REG
        lda ss_h5
        lsr
        sta ss_n                ; H/2*5
        ldx #0
-       +vdc_wait
        lda VDC_DATA
        sta ss_sat,x
        inx
        cpx ss_n
        bne -
        ; 3. neue Attribute: Grundfarbe (hohes Nibble darunter) + Code
        lda ss_p                ; ss_c = Codes im RAM-Bild
        clc
        adc ss_h5
        sta ss_c
        lda ss_p+1
        adc #0
        sta ss_c+1
        +ss_row_at
        lda ss_h
        lsr
        sta ss_n
        ldy #0                  ; Blockindex 0..H/2*5-1
.wa     lda ss_ra+1
        +vwr 18
        lda ss_ra
        +vwr 19
        ldx #31
        stx VDC_REG
        lda #SS_W
        sta ss_k
.wak    lda (ss_c),y
        cmp #$FF
        beq .keep
        cmp #$80
        beq .black
        cmp #0
        bne .put                ; fertiges Attribut
        lda ss_sat,y            ; Figurfarbe auf der Grundfarbe
        and #$F0
        ora ss_fc
        jmp .put
.black  lda ss_sat,y
        and #$F0
        jmp .put
.keep   lda ss_sat,y
.put    +vdc_wait
        sta VDC_DATA
        iny
        dec ss_k
        bne .wak
        +ss_next
        dec ss_n
        bne .wa
        ; 4. Tinte: je Zeile ein Lauf (k0, Laenge) aus der Ablage
        +ss_row_bm
        lda #0
        sta ss_i
.wb     lda ss_i
        lsr
        tay
        lda (ss_q),y            ; Lauf der Blockzeile: k0 | Laenge << 4
        beq .nl
        pha
        and #$0F
        sta ss_k0
        pla
        lsr
        lsr
        lsr
        lsr
        sta ss_k
        lda ss_ra               ; Ziel = Zeile + k0
        clc
        adc ss_k0
        tay
        lda ss_ra+1
        adc #0
        +vwr 18
        tya
        +vwr 19
        lda ss_i                ; Quelle = Tinte + Zeile*5 + k0
        asl
        asl
        adc ss_i
        adc ss_k0
        clc
        adc ss_ink
        tay
        lda ss_ink+1
        adc #0
        +vwr 32
        tya
        +vwr 33
        lda ss_k
        +vwr 30
.nl     +ss_next
        inc ss_i
        lda ss_i
        cmp ss_h
        beq +
        jmp .wb
+       ldx ss_cur
        rts

; Zeiger nur wegnehmen, wenn er das Rechteck (ss_cc, ss_yy, 5 Spalten, ss_h Zeilen) beruehrt
; (sonst flackert er bei jeder Bewegung der Figur).
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
        jsr vp_hide
.no     rts

; Ziel (vdc_addr) bzw. Quelle (R32/R33) der Bitmap-Zeile ss_i / Attribut-Blockzeile ss_i
ss_bm_addr
        jsr ss_bm_ay
        jmp vdc_addr
ss_at_addr
        jsr ss_at_ay
        jmp vdc_addr
ss_bm_src
        jsr ss_bm_ay
        jmp ss_src_ay
ss_at_src
        jsr ss_at_ay
ss_src_ay                       ; A = hi, Y = lo -> R32/R33
        ldx #32
        jsr vdc_wr
        tya
        ldx #33
        jmp vdc_wr
ss_bm_ay
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
        rts
ss_at_ay
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
        rts

ss_sv_lo !byte <ST_SAVE, <(ST_SAVE+ST_SAVE_B)
ss_sv_hi !byte >ST_SAVE, >(ST_SAVE+ST_SAVE_B)

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
ss_h5    !byte 0
ss_yy    !byte 0
ss_cc    !byte 0
ss_i     !byte 0
ss_o     !byte 0
ss_t     !byte 0
ss_k     !byte 0
ss_k0    !byte 0
ss_n     !byte 0
ss_s     !byte 0
ss_fc    !byte 0
ss_sv    !word 0
ss_ink   !word 0
ss_sat   !fill 5*9, 0
ss_ix    !byte 0
ss_span_lo !fill 2*18, 0      ; je Bild*2+Verschiebung: Zeiger auf 9 Lauf-Bytes (vs_init)
ss_span_hi !fill 2*18, 0
ss_spans !fill 2*18*9, 0
