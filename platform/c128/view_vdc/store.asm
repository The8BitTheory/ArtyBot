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
ST_SPR_N    = 16*2*18*5 + 2*2*6*5               ; obere Grenze (lueckenlos abgelegt ist es weniger)
ST_SAVE     = ST_SPR + ST_SPR_N
ST_SAVE_B   = 5*18 + 5*9                        ; Bitmap + Attribute unter einem Sprite
ST_PSAVE    = ST_SAVE + 2*ST_SAVE_B             ; unter dem Mauszeiger: 3 x 8 Bitmap + 3 x 4 Attribute
ST_ICONS    = ST_PSAVE + 3*8 + 3*4
ST_FREE     = ST_ICONS + 9*64

; Titelbilder: in dieser Reihenfolge, solange sie ganz hineinpassen (Adresse 0 = nicht abgelegt)
!if ST_FREE + vti_logo_n <= $10000 {
    vti_logo_st = ST_FREE
    ST_T1 = ST_FREE + vti_logo_n
} else {
    vti_logo_st = 0
    ST_T1 = ST_FREE
}
!if ST_T1 + vti_robot_n <= $10000 {
    vti_robot_st = ST_T1
    ST_T2 = ST_T1 + vti_robot_n
} else {
    vti_robot_st = 0
    ST_T2 = ST_T1
}
!if ST_T2 + vti_chest_n <= $10000 {
    vti_chest_st = ST_T2
    ST_T3 = ST_T2 + vti_chest_n
} else {
    vti_chest_st = 0
    ST_T3 = ST_T2
}
!if ST_T3 + vti_trophy_n <= $10000 {
    vti_trophy_st = ST_T3
    ST_END = ST_T3 + vti_trophy_n
} else {
    vti_trophy_st = 0
    ST_END = ST_T3
}

!macro vs_up .src, .dst, .n {
        lda #<.src
        sta vdc_src
        lda #>.src
        sta vdc_src+1
        lda #<.dst
        sta vdc_dst
        lda #>.dst
        sta vdc_dst+1
        lda #<.n
        sta vdc_cnt
        lda #>.n
        sta vdc_cnt+1
        jsr vdc_upload
}

!macro vs_unpack .img, .dst, .n {
        lda #<(.img+2)
        ldx #>(.img+2)
        jsr vu_start
        lda #>.dst
        ldy #<.dst
        jsr vdc_addr
        lda #<.n
        sta vu_cnt
        lda #>.n
        sta vu_cnt+1
        jsr vu_unpack
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
        ; Kacheln beider Themes, danach je die goldene Kiste
        lda #<vdc_cells_meadow
        ldx #>vdc_cells_meadow
        ldy #0
        jsr .theme
        lda #<vdc_cells_winter
        ldx #>vdc_cells_winter
        ldy #1
        jsr .theme
        ; Laeufe der Blockzeilen je Bild: k0 | Laenge << 4 (0 = leer); der Generator stellt
        ; sicher, dass die belegten Bloecke einer Blockzeile zusammenhaengen.
        lda #<ss_spans
        sta vs_q
        lda #>ss_spans
        sta vs_q+1
        ldx #0
.spn    stx vs_n
        lda vs_q
        sta ss_span_lo,x
        lda vs_q+1
        sta ss_span_hi,x
        txa
        lsr
        tay
        lda vdc_spr_h,y         ; Codes ab H*5
        sta vs_h
        asl
        asl
        adc vs_h
        clc
        adc vdc_spr_lo,x
        sta vs_p
        lda vdc_spr_hi,x
        adc #0
        sta vs_p+1
        lsr vs_h                ; Blockzeilen
        lda #0
        sta vs_r
.br     lda #0
        sta vs_len
        lda #$FF
        sta vs_k0
        ldy #0
.bk     lda (vs_p),y
        cmp #$FF
        beq +
        inc vs_len
        lda vs_k0
        bpl +
        sty vs_k0
+       iny
        cpy #5
        bne .bk
        lda vs_len
        beq +
        asl
        asl
        asl
        asl
        ora vs_k0
+       ldy vs_r
        sta (vs_q),y
        lda vs_p
        clc
        adc #5
        sta vs_p
        bcc +
        inc vs_p+1
+       inc vs_r
        lda vs_r
        cmp vs_h
        bne .br
        lda vs_q                ; naechstes Bild: 9 Bytes weiter
        clc
        adc #9
        sta vs_q
        bcc +
        inc vs_q+1
+       ldx vs_n
        inx
        cpx #2*18
        beq +
        jmp .spn
+
        ; Figuren: Tinte lueckenlos, nur die belegten Bytes jeder Zeile hintereinander. Beim
        ; Zeichnen laeuft die Quelle damit ueber alle Zeilen von selbst weiter (sprite.asm).
        lda #>ST_SPR
        ldy #<ST_SPR
        sta vs_a+1
        sty vs_a
        jsr vdc_addr
        ldx #0
.ink    stx vs_n
        lda vs_a                ; Anfang der Tinte dieses Bildes
        sta ss_st_lo,x
        lda vs_a+1
        sta ss_st_hi,x
        lda vdc_spr_lo,x        ; RAM-Bild
        sta vs_p
        lda vdc_spr_hi,x
        sta vs_p+1
        lda ss_span_lo,x        ; Laeufe
        sta vs_q
        lda ss_span_hi,x
        sta vs_q+1
        txa
        lsr
        tay
        lda vdc_spr_h,y
        sta vs_h
        lda #0
        sta vs_r                ; Zeile
.ir     lda vs_r
        lsr
        tay
        lda (vs_q),y
        beq .inext
        pha
        and #$0F
        sta vs_k0
        pla
        lsr
        lsr
        lsr
        lsr
        sta vs_len
        lda vs_r                ; Quelle: Zeile*5 + k0
        asl
        asl
        adc vs_r
        adc vs_k0
        tay
-       lda (vs_p),y
        +vdc_wait
        sta VDC_DATA
        inc vs_a
        bne +
        inc vs_a+1
+       iny
        dec vs_len
        bne -
.inext  inc vs_r
        lda vs_r
        cmp vs_h
        bne .ir
        ldx vs_n
        inx
        cpx #2*18
        bne .ink
        ; Icons
        +vs_up vdc_icons, ST_ICONS, 9*64
        ; Titelbilder, soweit abgelegt
!if vti_logo_st {
        +vs_unpack vti_logo, vti_logo_st, vti_logo_n
}
!if vti_robot_st {
        +vs_unpack vti_robot, vti_robot_st, vti_robot_n
}
!if vti_chest_st {
        +vs_unpack vti_chest, vti_chest_st, vti_chest_n
}
!if vti_trophy_st {
        +vs_unpack vti_trophy, vti_trophy_st, vti_trophy_n
}
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
.theme  sta vdc_src
        stx vdc_src+1
        lda vs_theme_lo,y
        sta vdc_dst
        lda vs_theme_hi,y
        sta vdc_dst+1
        lda #<(16*ST_CELL_B)
        sta vdc_cnt
        lda #>(16*ST_CELL_B)
        sta vdc_cnt+1
        lda vdc_src             ; Kiste = Zelle 2, Quelle merken
        clc
        adc #<(2*ST_CELL_B)
        sta vs_p
        lda vdc_src+1
        adc #>(2*ST_CELL_B)
        sta vs_p+1
        jsr vdc_upload
        ; goldene Kiste: Bitmap unveraendert, Attribute Braun -> Gelb
        lda vdc_dst
        clc
        adc #<(16*ST_CELL_B)
        tay
        lda vdc_dst+1
        adc #>(16*ST_CELL_B)
        jsr vdc_addr
        ldy #0
-       lda (vs_p),y
        cpy #64
        bcc +
        jsr wv_goldify
+       +vdc_wait
        sta VDC_DATA
        iny
        cpy #ST_CELL_B
        bne -
        rts

vs_theme_lo !byte <ST_CELLS, <(ST_CELLS+ST_THEME_B)
vs_theme_hi !byte >ST_CELLS, >(ST_CELLS+ST_THEME_B)

; ---- Entpacken ins VRAM ----------------------------------------------------------
; Format (tools/gen_vdc_title.py): c < $80: c+1 Bytes folgen; c >= $80: naechstes Byte (c-$7D)-mal.
; Laeufe ab VU_FILL Bytes per Block-Fill: erstes Byte ueber R31, Rest mit R30 = n-1.
;
; Rechnung (Zyklen bei 2 MHz, VDC bereit): ein Byte ueber R31 in der Schleife kostet etwa
; 15 Zyklen (warten 6, sta 4, Zaehler/Sprung 5). Block-Fill: erstes Byte 15, R30 waehlen +
; Zaehler schreiben + R31 wieder waehlen etwa 20, dazu ca. 2 Zyklen je weiteres Byte, die der
; VDC selbst schreibt (die CPU wartet beim naechsten Zugriff). Byteweise: 15*n, Fill: 35+2*(n-1).
; Gleichstand bei n = 2,5 -> ab 3 gleichen Bytes lohnt sich der Fill (= kuerzester Lauf im Format).
VU_FILL = 3

; A/X = gepackte Daten: Zustand zuruecksetzen
vu_start
        sta vt_ptr
        stx vt_ptr+1
        lda #0
        sta vt_run
        sta vt_lit
        rts

; vu_cnt (16 Bit) Bytes an die aktuelle Schreibadresse (R31 gewaehlt) entpacken. Ein Lauf darf
; ueber das Ende hinausgehen (Rest bleibt fuer den naechsten Aufruf in vt_run).
!zone vu_unpack
vu_unpack
        jsr vdc_mode_fill
        ldx #31
        stx VDC_REG
.loop   lda vu_cnt
        ora vu_cnt+1
        bne .more
        rts
.more   lda vt_run
        beq .nr
        ; Lauf: k = min(vt_run, vu_cnt)
        ldx vu_cnt+1
        bne .krun
        cmp vu_cnt
        bcc .krun
        lda vu_cnt
.krun   sta vu_k
        lda vt_run
        sec
        sbc vu_k
        sta vt_run
        lda vu_cnt
        sec
        sbc vu_k
        sta vu_cnt
        bcs +
        dec vu_cnt+1
+       lda vt_val
        ldx vu_k
        cpx #VU_FILL
        bcc .bytes
        +vdc_wait               ; erstes Byte, dann R30 = k-1 mal wiederholen
        sta VDC_DATA
        dex
        txa
        ldx #30
        stx VDC_REG
        +vdc_wait
        sta VDC_DATA
        ldx #31
        stx VDC_REG
        jmp .loop
.bytes  +vdc_wait
        sta VDC_DATA
        dex
        bne .bytes
        jmp .loop
.nr     lda vt_lit
        beq .ctl
        ; Literale: so viele wie da sind und gebraucht werden
.lit    ldy #0
        lda (vt_ptr),y
        +vdc_wait
        sta VDC_DATA
        inc vt_ptr
        bne +
        inc vt_ptr+1
+       lda vu_cnt
        bne +
        dec vu_cnt+1
+       dec vu_cnt
        dec vt_lit
        bne +
        jmp .loop
+       lda vu_cnt
        ora vu_cnt+1
        bne .lit
        rts
.ctl    ldy #0
        lda (vt_ptr),y
        bmi .rep
        clc
        adc #1
        sta vt_lit
        jsr .inc
        jmp .loop
.rep    sec
        sbc #$7D
        sta vt_run
        iny
        lda (vt_ptr),y
        sta vt_val
        jsr .inc
        jsr .inc
        jmp .loop
.inc    inc vt_ptr
        bne +
        inc vt_ptr+1
+       rts

vs_n     !byte 0
vs_a     !word 0
vs_h     !byte 0
vs_r     !byte 0
vs_len   !byte 0
vs_k0    !byte 0
vs_t     !byte 0
vu_cnt   !word 0
vu_k     !byte 0
ss_st_lo !fill 2*18, 0          ; VRAM-Adresse der Tinte je Bild*2 + Verschiebung
ss_st_hi !fill 2*18, 0
