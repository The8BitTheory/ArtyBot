; store.asm (VDC-View) - Grafikablage im VRAM ($6000-$FFFF) und Hochladen beim Start.
; Gezeichnet wird von dort per Block-Copy des VDC (R24 Bit 7, Quelle R32/R33, Ziel R18/R19,
; Anzahl R30): die CPU setzt nur Adressen und Zaehler.
;
; Belegung in fester Rangfolge (zur Assemblierzeit verteilt):
;   1. Zeichensatz normal: 8 Glyphzeilen x 128 Zeichen (Zeile n ab ST_FONT + n*128)
;      Zeichensatz doppelt breit: 8 x 128 x 2 Byte (Zeile n ab ST_FONTW + n*256)
;      Zeilenweise abgelegt, damit das hohe Quellbyte innerhalb einer Textzeile gleich bleibt.
;   2. Kacheln: je Theme 17 Zellen zu 96 Byte (16 Zeilen x 4 Bitmap, 8 x 4 Attribute);
;      Zelle 16 = Kiste in Gold (geloester Level auf der Karte)
;   3. Figuren: Tinte je Bild und Verschiebung lueckenlos (nur belegte Bytes jeder Zeile);
;      Sicherung des Hintergrunds je Sprite und unter dem Mauszeiger
;   4. Befehls-Icons (9 x 64)
;   5. Titelbilder entpackt, nur solange Platz ist; sonst beim Anzeigen direkt aus dem
;      gepackten RAM-Bild auf den Bildschirm entpackt (vt_image).

vs_p        = $9A               ; Zeropage $9A/$9B
vs_q        = $9E               ; Zeropage $9E/$9F
ST_FONT     = VDC_STORE                         ; $6000, 1 KB
ST_FONTW    = ST_FONT + 8*128                   ; 2 KB, Seitengrenze
ST_CELLS    = ST_FONTW + 8*256
ST_CELL_B   = 96
ST_THEME_B  = 17*ST_CELL_B
ST_CELL_GOLD = 16
ST_SPR      = ST_CELLS + 2*ST_THEME_B
ST_SPR_N    = VDC_INK_N                         ; Tinte lueckenlos (gfx_vdc.asm)
ST_SAVE     = ST_SPR + ST_SPR_N
ST_SAVE_B   = 5*26 + 5*13                       ; Bitmap + Attribute unter einem Sprite (Roboter+Kiste: 26 Zeilen)
ST_PSAVE    = ST_SAVE + 3*ST_SAVE_B             ; unter dem Mauszeiger: 3 x 8 Bitmap + 3 x 4 Attribute
ST_ICONS    = ST_PSAVE + 3*8 + 3*4
ST_MINI     = ST_ICONS + 9*64                   ; Legende: 2 x 16 Mini-Zellen + 4 Mini-Roboter, je 24 Byte
ST_MINI_B   = 24
ST_FREE     = ST_MINI + (2*16+4)*ST_MINI_B

; Titelbilder: alle in der Ablage (sie liegen nur noch in der Ressource, nicht im Programm)
vti_logo_st   = ST_FREE
vti_robot_st  = vti_logo_st + vti_logo_n
vti_chest_st  = vti_robot_st + vti_robot_n
vti_trophy_st = vti_chest_st + vti_chest_n
ST_END        = vti_trophy_st + vti_trophy_n
!if ST_END > $10000 {
    !error "VRAM-Ablage voll"
}

; Teil .item der Ressource (Bank 1): .n Bytes ungepackt bzw. gepackt nach VRAM .dst
!macro vs_res .item, .dst, .n {
        lda #<.dst
        sta vdc_dst
        lda #>.dst
        sta vdc_dst+1
        lda #<.n
        sta vdc_cnt
        lda #>.n
        sta vdc_cnt+1
        lda #.item
        jsr res_upload
}
!macro vs_unres .item, .dst, .n {
        lda #<.dst
        sta vdc_dst
        lda #>.dst
        sta vdc_dst+1
        lda #<.n
        sta vu_cnt
        lda #>.n
        sta vu_cnt+1
        lda #.item
        jsr res_unpack
}

; ---- Hochladen beim Start (nach vt_init: Zeichensatz-Kopie in VDC_FONT) ------------
!zone vs_init
vs_init
        ; Zeichensatz normal: Zeile n aller 128 Zeichen hintereinander
        lda #0
        sta vs_n
.fn     lda vs_n                ; Ziel ST_FONT + n*128: lo = (n&1)*128, hi = >ST_FONT + n/2
        lsr
        lda #0
        ror
        tay
        lda vs_n
        lsr
        clc
        adc #>ST_FONT
        jsr vdc_addr
        jsr .glyphs             ; X = 0..127, A = Byte
-       +vdc_wait
        sta VDC_DATA
        jsr .next
        bne -
        inc vs_n
        lda vs_n
        cmp #8
        bne .fn
        ; doppelt breit: Zeile n ab ST_FONTW + n*256, je Zeichen 2 Byte
        lda #0
        sta vs_n
.fw     lda vs_n
        clc
        adc #>ST_FONTW
        ldy #0
        jsr vdc_addr
        jsr .glyphs
-       pha
        lsr
        lsr
        lsr
        lsr
        tay
        lda vt_dbl,y
        +vdc_wait
        sta VDC_DATA
        pla
        and #$0F
        tay
        lda vt_dbl,y
        +vdc_wait
        sta VDC_DATA
        jsr .next
        bne -
        inc vs_n
        lda vs_n
        cmp #8
        bne .fw
        ; aus der Ressource (Bank 1): Kacheln beider Themes (mit Kiste in Gold), Figurentinte
        +vs_res RES_CELLS_M, ST_CELLS, ST_THEME_B
        +vs_res RES_CELLS_W, ST_CELLS+ST_THEME_B, ST_THEME_B
        +vs_res RES_INK, ST_SPR, VDC_INK_N
        ; Icons
        +vs_res RES_ICONS, ST_ICONS, 9*64                       ; aus der Ressource (Bank 1)
        +vs_res RES_MINI, ST_MINI, (2*16+4)*ST_MINI_B           ; meadow, winter, robot hintereinander
        ; Titelbilder, soweit abgelegt
        +vs_unres RES_LOGO, vti_logo_st, vti_logo_n
        +vs_unres RES_ROBOT, vti_robot_st, vti_robot_n
        +vs_unres RES_CHEST, vti_chest_st, vti_chest_n
        +vs_unres RES_TROPHY, vti_trophy_st, vti_trophy_n
        rts

; Zeichen 0..127 von Zeile vs_n: X = Zeichen, A = Glyphbyte; .next: X+1, Z = 1 nach 128
.glyphs ldx #0
        lda #<VDC_FONT
        sta vt_ptr2
        lda #>VDC_FONT
        sta vt_ptr2+1
.g      ldy vs_n
        lda (vt_ptr2),y
        rts
.next   lda vt_ptr2
        clc
        adc #8
        sta vt_ptr2
        bcc +
        inc vt_ptr2+1
+       inx
        cpx #128
        beq +
        ldy vs_n
        lda (vt_ptr2),y
        ldy #1                  ; Z = 0: weiter
+       rts

; A/X = Zellen eines Themes im RAM, Y = Theme: 16 Zellen + goldene Kiste ablegen

vs_n     !byte 0
vs_a     !word 0
vs_h     !byte 0
vs_r     !byte 0
vs_len   !byte 0
vs_k0    !byte 0
vs_t     !byte 0
