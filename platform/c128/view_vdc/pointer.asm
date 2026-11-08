; pointer.asm (VDC-View) - Mauszeiger als Software-Sprite: Pfeil 12x8 Pixel mit 1 Pixel Rand.
; Zeichnen: Hintergrund (3 Bytes x 8 Zeilen) sichern, dann (alt AND NOT Maske) OR Form;
; Wegnehmen: gesicherte Bytes zurueck. Farbe = Vordergrund der Bloecke darunter, der Rand ist
; deren Hintergrund.
; vp_show zeichnet an (mouse_x, mouse_y), vp_hide nimmt ihn weg (vor jedem Zeichnen),
; vp_forget nach einem Loeschen des Bildschirms (Zeiger ist schon weg).

VP_LINES = 8

!zone vp_forget
vp_forget
        lda #$FF
        sta vp_x
        rts

; Zeiger an der Mausposition (vorher wegnehmen, falls woanders)
!zone vp_show
vp_show
        jsr mouse_col
        cmp #78                 ; 3 Bytes breit: ganz rechts nur 2 Spalten
        bcc +
        lda #77
+       sta vp_nx
        lda mouse_x_lo
        and #7
        sta vp_nb
        lda mouse_y
        cmp #200-VP_LINES
        bcc +
        lda #200-VP_LINES
+       sta vp_ny
        lda vp_x
        cmp #$FF
        beq .draw
        cmp vp_nx
        bne .move
        lda vp_b
        cmp vp_nb
        bne .move
        lda vp_y
        cmp vp_ny
        beq .done               ; unveraendert
.move   jsr vp_hide
.draw   lda vp_nx
        sta vp_x
        lda vp_nb
        sta vp_b
        lda vp_ny
        sta vp_y
        lda #0
        sta vp_on
        jmp vp_xor
.done   rts

; A = Spalte unter dem Zeiger (x / 8, 0..79)
!zone mouse_col
mouse_col
        lda mouse_x_lo
        lsr
        lsr
        lsr
        sta vp_t
        lda mouse_x_hi
        asl
        asl
        asl
        asl
        asl
        ora vp_t
        rts

!zone vp_hide
vp_hide
        lda vp_x
        cmp #$FF
        beq .done
        lda #1
        sta vp_on
        jsr vp_xor
        lda #$FF
        sta vp_x
.done   rts

; vp_xor: zeichnen (vp_on = 0) bzw. wegnehmen (vp_on = 1) an (vp_x, vp_b, vp_y)
!zone vp_xor
vp_xor
        lda vp_b                ; Tabellenindex: vp_b * 24
        asl
        asl
        asl
        sta vp_t
        asl
        adc vp_t
        sta vp_t
        lda #0
        sta vp_i
        sta vp_s
.line   lda vp_y
        clc
        adc vp_i
        tax
        lda vl_lo,x
        clc
        adc vp_x
        sta vp_a
        lda vl_hi,x
        adc #0
        sta vp_a+1
        lda vp_on
        bne .restore
        lda vp_a+1
        ldy vp_a
        jsr vdc_addr            ; Hintergrund lesen und sichern
        ldx vp_s
        ldy #3
-       +vdc_wait
        lda VDC_DATA
        sta vp_save,x
        inx
        dey
        bne -
        lda vp_a+1
        ldy vp_a
        jsr vdc_addr
        ldx vp_s
        ldy vp_t
        lda #3
        sta vp_c
-       lda vp_mask,y
        eor #$FF
        and vp_save,x
        ora vp_shapes,y
        +vdc_wait
        sta VDC_DATA
        iny
        inx
        dec vp_c
        bne -
        jmp .next
.restore
        lda vp_a+1
        ldy vp_a
        jsr vdc_addr
        ldx vp_s
        ldy #3
-       lda vp_save,x
        +vdc_wait
        sta VDC_DATA
        inx
        dey
        bne -
.next   lda vp_s
        clc
        adc #3
        sta vp_s
        lda vp_t
        clc
        adc #3
        sta vp_t
        inc vp_i
        lda vp_i
        cmp #VP_LINES
        beq +
        jmp .line
+       rts

; Form (12 Pixel, Spitze oben links; 1 Pixel Rand links frei) und Maske (Form + 1 Pixel ringsum),
; je 8 Verschiebungen x 8 Zeilen x 3 Bytes (erzeugt). Der Hotspot liegt 1 Pixel rechts der Spalte.
vp_shapes
        !byte $60,$00,$00,$78,$00,$00,$7E,$00,$00,$7F,$80,$00,$7F,$E0,$00,$7E,$00,$00,$67,$00,$00,$03,$80,$00
        !byte $30,$00,$00,$3C,$00,$00,$3F,$00,$00,$3F,$C0,$00,$3F,$F0,$00,$3F,$00,$00,$33,$80,$00,$01,$C0,$00
        !byte $18,$00,$00,$1E,$00,$00,$1F,$80,$00,$1F,$E0,$00,$1F,$F8,$00,$1F,$80,$00,$19,$C0,$00,$00,$E0,$00
        !byte $0C,$00,$00,$0F,$00,$00,$0F,$C0,$00,$0F,$F0,$00,$0F,$FC,$00,$0F,$C0,$00,$0C,$E0,$00,$00,$70,$00
        !byte $06,$00,$00,$07,$80,$00,$07,$E0,$00,$07,$F8,$00,$07,$FE,$00,$07,$E0,$00,$06,$70,$00,$00,$38,$00
        !byte $03,$00,$00,$03,$C0,$00,$03,$F0,$00,$03,$FC,$00,$03,$FF,$00,$03,$F0,$00,$03,$38,$00,$00,$1C,$00
        !byte $01,$80,$00,$01,$E0,$00,$01,$F8,$00,$01,$FE,$00,$01,$FF,$80,$01,$F8,$00,$01,$9C,$00,$00,$0E,$00
        !byte $00,$C0,$00,$00,$F0,$00,$00,$FC,$00,$00,$FF,$00,$00,$FF,$C0,$00,$FC,$00,$00,$CE,$00,$00,$07,$00
vp_mask
        !byte $FC,$00,$00,$FF,$00,$00,$FF,$C0,$00,$FF,$F0,$00,$FF,$F0,$00,$FF,$F0,$00,$FF,$C0,$00,$FF,$C0,$00
        !byte $7E,$00,$00,$7F,$80,$00,$7F,$E0,$00,$7F,$F8,$00,$7F,$F8,$00,$7F,$F8,$00,$7F,$E0,$00,$7F,$E0,$00
        !byte $3F,$00,$00,$3F,$C0,$00,$3F,$F0,$00,$3F,$FC,$00,$3F,$FC,$00,$3F,$FC,$00,$3F,$F0,$00,$3F,$F0,$00
        !byte $1F,$80,$00,$1F,$E0,$00,$1F,$F8,$00,$1F,$FE,$00,$1F,$FE,$00,$1F,$FE,$00,$1F,$F8,$00,$1F,$F8,$00
        !byte $0F,$C0,$00,$0F,$F0,$00,$0F,$FC,$00,$0F,$FF,$00,$0F,$FF,$00,$0F,$FF,$00,$0F,$FC,$00,$0F,$FC,$00
        !byte $07,$E0,$00,$07,$F8,$00,$07,$FE,$00,$07,$FF,$80,$07,$FF,$80,$07,$FF,$80,$07,$FE,$00,$07,$FE,$00
        !byte $03,$F0,$00,$03,$FC,$00,$03,$FF,$00,$03,$FF,$C0,$03,$FF,$C0,$03,$FF,$C0,$03,$FF,$00,$03,$FF,$00
        !byte $01,$F8,$00,$01,$FE,$00,$01,$FF,$80,$01,$FF,$E0,$01,$FF,$E0,$01,$FF,$E0,$01,$FF,$80,$01,$FF,$80

vp_nx   !byte 0
vp_nb   !byte 0
vp_ny   !byte 0
vp_t    !byte 0
vp_i    !byte 0
vp_a    !word 0
vp_save !fill 3*VP_LINES, 0
vp_s    !byte 0
vp_c    !byte 0
vp_on   !byte 0
