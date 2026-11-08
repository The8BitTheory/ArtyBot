; vdc.asm (C128) - Treiber fuer den VDC (8563/8568) im Bitmap-Modus 640x200 mit Farbattributen
; pro 8x2 Pixel (Zeichenhoehe 2 Zeilen). Braucht 64 KB VDC-RAM.
; Zugriffsroutinen und Verfahren nach VDC-BASIC (github.com/the8bittheory/vdc-basic, Branch v2g,
; src/vdclib.a / vdcbasic.asm): Register schreiben/lesen mit Warten auf das Ready-Bit,
; 64-KB-Test ueber $3FFF/$BFFF, Block-Write/-Copy in Seiten ueber R30, VRAM->VRAM-Kopien mit
; Wiederholung und Ziel-Abstand (VMC), RAM->VRAM mit selbstmodifizierendem Lesezeiger.
;
; VDC-Speicher:  $0000-$3E7F Bitmap (80 Byte x 200 Zeilen)
;                $4000-$5F3F Attribute (80 x 100 Bloecke 8x2, hohes Nibble Hintergrund, niedriges Vordergrund)
;                $6000-$FFFF Grafikablage (Kacheln, Icons, Figuren) fuer Blitter-Kopien
; Zeropage: vdc_src/vdc_dst/vdc_cnt (inc/zp.inc, Block VDC).

VDC_REG     = $D600             ; schreiben: Registernummer, lesen: Status (Bit 7 ready, Bit 5 Austastung)
VDC_DATA    = $D601
VDC_BITMAP  = $0000
VDC_ATTR    = $4000
VDC_STORE   = $6000
VDC_COLS    = 80                ; Bytes pro Bitmapzeile = Attribute pro Blockzeile
VDC_LINES   = 200
VDC_AROWS   = 100               ; Attribut-Blockzeilen (je 2 Pixelzeilen)

!macro vdc_wait {
-       bit VDC_REG
        bpl -
}

; ---- Register ------------------------------------------------------------------
; X = Register, A = Wert
!zone vdc_wr
vdc_wr  stx VDC_REG
vdc_wr_data
        +vdc_wait
        sta VDC_DATA
        rts

; X = Register -> A
!zone vdc_rd
vdc_rd  stx VDC_REG
        +vdc_wait
        lda VDC_DATA
        rts

; Schreibadresse (R18/R19) = A (hi) / Y (lo); danach ist R31 (Daten) gewaehlt.
!zone vdc_addr
vdc_addr
        ldx #18
        jsr vdc_wr
        tya
        inx
        jsr vdc_wr
        ldx #31
        stx VDC_REG
        rts

; A = Byte an die aktuelle Adresse (Adresse zaehlt weiter)
!zone vdc_put
vdc_put +vdc_wait
        sta VDC_DATA
        rts

; ---- Block-Operationen ------------------------------------------------------------
; Zaehler vdc_cnt (16 Bit) als Folge von R30-Zyklen; R24 Bit 7 waehlt Write/Copy.
!zone vdc_cycles
vdc_cycles
        ldx #30
        stx VDC_REG
        lda vdc_cnt
        beq .pages
        +vdc_wait
        sta VDC_DATA            ; Teilseite
.pages  ldy vdc_cnt+1
        beq .done
.p      +vdc_wait
        lda #0                  ; 0 = 256 Zyklen
        sta VDC_DATA
        dey
        bne .p
.done   rts

; Fuellen: vdc_dst = Ziel, A = Wert, vdc_cnt = Anzahl (>= 1)
!zone vdc_fill
vdc_fill
        pha
        ldx #24                 ; Block-Write
        jsr vdc_rd
        and #$7F
        jsr vdc_wr_data
        lda vdc_dst+1
        ldy vdc_dst
        jsr vdc_addr
        pla
        jsr vdc_put             ; erstes Byte von Hand ...
        lda vdc_cnt             ; ... Rest per Block-Write (Zaehler - 1)
        bne +
        dec vdc_cnt+1
+       dec vdc_cnt
        lda vdc_cnt
        ora vdc_cnt+1
        beq .done
        jmp vdc_cycles
.done   rts

; Kopieren im VRAM: vdc_src -> vdc_dst, vdc_cnt Bytes
!zone vdc_copy
vdc_copy
        jsr vdc_copy_mode
        jsr vdc_set_src
        lda vdc_dst+1
        ldy vdc_dst
        jsr vdc_addr
        jmp vdc_cycles

vdc_copy_mode
        ldx #24                 ; Block-Copy
        jsr vdc_rd
        ora #$80
        jmp vdc_wr_data

vdc_set_src
        ldx #32
        lda vdc_src+1
        jsr vdc_wr
        inx
        lda vdc_src
        jmp vdc_wr

; Rechteck aus der Ablage kopieren (wie VMC mit Wiederholung): Quelle vdc_src linear,
; Ziel vdc_dst, Breite vdc_w Bytes, Hoehe vdc_h Zeilen, Ziel-Abstand VDC_COLS.
; Die Quelladresse zaehlt der VDC selbst weiter (R32/R33).
!zone vdc_rect
vdc_rect
        jsr vdc_copy_mode
        jsr vdc_set_src
        lda vdc_h
        sta vdc_n
.row    lda vdc_dst+1
        ldy vdc_dst
        jsr vdc_addr
        ldx #30
        lda vdc_w
        jsr vdc_wr
        lda vdc_dst
        clc
        adc #VDC_COLS
        sta vdc_dst
        bcc +
        inc vdc_dst+1
+       dec vdc_n
        bne .row
        rts

; Rechteck fuellen: vdc_dst, Breite vdc_w, Hoehe vdc_h, Abstand VDC_COLS, A = Wert
!zone vdc_rect_fill
vdc_rect_fill
        sta vdc_v
        lda vdc_h
        sta vdc_n
.row    lda vdc_w
        sta vdc_cnt
        lda #0
        sta vdc_cnt+1
        lda vdc_v
        jsr vdc_fill
        lda vdc_dst
        clc
        adc #VDC_COLS
        sta vdc_dst
        bcc +
        inc vdc_dst+1
+       dec vdc_n
        bne .row
        rts

; RAM -> VRAM: vdc_src (CPU-RAM, Bank 0) -> vdc_dst, vdc_cnt Bytes (>= 1)
!zone vdc_upload
vdc_upload
        lda vdc_dst+1
        ldy vdc_dst
        jsr vdc_addr
        lda vdc_src+1
        sta .hi
        ldy vdc_src
        lda #0
        sta .lo
        lda vdc_cnt             ; Zaehler negativ (wie vdclib ram_to_vram)
        eor #$FF
        clc
        adc #1
        sta vdc_cnt
        lda vdc_cnt+1
        eor #$FF
        adc #0
        sta vdc_cnt+1
.l
.lo = * + 1
.hi = * + 2
        lda $FF00,y             ; Adresse wird angepasst
        +vdc_wait
        sta VDC_DATA
        iny
        bne +
        inc .hi
+       inc vdc_cnt
        bne .l
        inc vdc_cnt+1
        bne .l
        rts

; ---- 64 KB? ----------------------------------------------------------------------
; Carry gesetzt = 64 KB. Bei 16 KB spiegelt $BFFF auf $3FFF (Verfahren aus vdclib.a).
!zone vdc_has_64k
vdc_has_64k
        lda #$3F
        ldy #$FF
        jsr .read
        sta vdc_v               ; alter Wert unten
        lda #$BF
        ldy #$FF
        jsr .read
        pha                     ; alter Wert oben
        lda #$BF
        ldy #$FF
        jsr vdc_addr
        lda vdc_v
        eor #$FF
        jsr vdc_put             ; oben = invertierter unterer Wert
        lda #$3F
        ldy #$FF
        jsr .read
        eor vdc_v               ; unten veraendert? -> 16 KB
        sta vdc_n
        lda #$BF
        ldy #$FF
        jsr vdc_addr
        pla
        jsr vdc_put             ; oben wiederherstellen
        lda vdc_n
        beq .yes
        clc
        rts
.yes    sec
        rts
.read   jsr vdc_addr            ; A/Y = Adresse, Ergebnis in A
        +vdc_wait
        lda VDC_DATA
        rts

; ---- Bitmap-Modus 640x200, Attribute 8x2 -----------------------------------------
; Liest die vom KERNAL gesetzten Zeitregister (PAL/NTSC) und rechnet sie von 8 auf 2
; Zeilen pro Zeichenzeile um; die Gesamtzeilenzahl und die Lage des VSync bleiben gleich.
!zone vdc_init_bitmap
vdc_init_bitmap
        ldx #28                 ; 64-KB-RAM-Typ
        jsr vdc_rd
        ora #$10
        jsr vdc_wr_data
        ; Gesamtzeilen = (R4+1) * (R9+1) + R5
        ldx #9
        jsr vdc_rd
        and #$1F
        sta vdc_v               ; R9 (Zeilen pro Zeichen - 1)
        ldx #4
        jsr vdc_rd
        sta vdc_n               ; R4
        ldx #7
        jsr vdc_rd
        sta vdc_w               ; R7
        ldx #5
        jsr vdc_rd
        and #$1F
        sta vdc_h               ; R5
        lda #0
        sta vdc_cnt
        sta vdc_cnt+1
        ldy vdc_n
        iny                     ; R4+1 Zeichenzeilen
.mul    lda vdc_cnt
        sec                     ; + (R9+1)
        adc vdc_v
        sta vdc_cnt
        bcc +
        inc vdc_cnt+1
+       dey
        bne .mul
        lda vdc_cnt
        clc
        adc vdc_h
        sta vdc_cnt
        bcc +
        inc vdc_cnt+1
+       lsr vdc_cnt+1           ; / 2 Zeilen pro Zeichenzeile
        ror vdc_cnt
        lda #0
        rol                     ; Rest -> R5
        sta vdc_h
        ; VSync-Zeichenzeile: R7 * (R9+1) / 2
        lda #0
        sta vdc_src
        sta vdc_src+1
        ldy vdc_v
        iny
.m2     lda vdc_src
        clc
        adc vdc_w
        sta vdc_src
        bcc +
        inc vdc_src+1
+       dey
        bne .m2
        lsr vdc_src+1
        ror vdc_src
        ; Bild aus, Speicher loeschen, dann umschalten
        jsr vdc_vblank
        ldx #25
        jsr vdc_rd
        ora #$C0                ; Bitmap + Attribute
        sta vdc_v
        jsr .save_cnt           ; Zeilenzahl merken, vdc_cnt = 16000
        lda #<VDC_BITMAP
        sta vdc_dst
        lda #>VDC_BITMAP
        sta vdc_dst+1
        lda #0
        jsr vdc_fill
        lda #<VDC_ATTR
        sta vdc_dst
        lda #>VDC_ATTR
        sta vdc_dst+1
        lda #<8000
        sta vdc_cnt
        lda #>8000
        sta vdc_cnt+1
        lda #$00                ; schwarz auf schwarz
        jsr vdc_fill
        jsr .restore_cnt
        jsr vdc_vblank
        ldx #4
        lda vdc_cnt
        sec
        sbc #1
        jsr vdc_wr              ; R4 = Zeilen - 1
        ldx #5
        lda vdc_h
        jsr vdc_wr
        ldx #6
        lda #VDC_AROWS
        jsr vdc_wr
        ldx #7
        lda vdc_src
        jsr vdc_wr
        ldx #9
        lda #1
        jsr vdc_wr              ; 2 Zeilen pro Zeichenzeile
        ldx #23
        lda #2
        jsr vdc_wr
        ldx #27
        lda #0
        jsr vdc_wr              ; kein Zeilenversatz
        ldx #12
        lda #>VDC_BITMAP
        jsr vdc_wr
        inx
        lda #<VDC_BITMAP
        jsr vdc_wr
        ldx #20
        lda #>VDC_ATTR
        jsr vdc_wr
        inx
        lda #<VDC_ATTR
        jsr vdc_wr
        ldx #26
        lda #$00                ; Rahmen/Hintergrund schwarz
        jsr vdc_wr
        ldx #25
        lda vdc_v
        jmp vdc_wr
.save_cnt
        lda vdc_cnt             ; Zeilenzahl merken (vdc_cnt wird zum Loeschen gebraucht)
        sta vdc_sv
        lda vdc_cnt+1
        sta vdc_sv+1
        lda #<16000
        sta vdc_cnt
        lda #>16000
        sta vdc_cnt+1
        rts
.restore_cnt
        lda vdc_sv
        sta vdc_cnt
        lda vdc_sv+1
        sta vdc_cnt+1
        rts

; Warten auf das Ende des Anzeigefensters (wie SYN in VDC-BASIC)
!zone vdc_vblank
vdc_vblank
-       lda VDC_REG
        and #$20
        bne -
-       lda VDC_REG
        and #$20
        beq -
        rts

; ---- Text ------------------------------------------------------------------------
; Zeichenkette (A/X, 0-terminiert, Bildschirmcodes) an Zelle vdc_tx (0..79) / vdc_ty
; (0..24, je 8 Pixelzeilen) mit Attribut vdc_tc (hohes Nibble Hintergrund, niedriges
; Vordergrund). Zeichen aus vdc_font (2 KB im CPU-RAM, 8 Byte je Zeichen).
!zone vdc_text
vdc_text
        sta .str
        stx .str+1
        ldy #0                  ; Laenge
.len
.str = * + 1
        lda $FFFF,y
        beq +
        iny
        bne .len
+       sty vdc_w
        tya
        bne .go
        rts
.go
        ; Bitmapadresse = ty*640 + tx
        lda vdc_ty
        sta vdc_dst
        lda #0
        sta vdc_dst+1
        ldx #3                  ; *8 Zeilen
-       asl vdc_dst
        rol vdc_dst+1
        dex
        bne -
        jsr .mul80              ; *80
        lda vdc_dst
        clc
        adc vdc_tx
        sta vdc_dst
        bcc +
        inc vdc_dst+1
+       lda #0
        sta vdc_n               ; Pixelzeile 0..7
.line   lda vdc_dst+1
        ldy vdc_dst
        jsr vdc_addr
        ldy #0
.ch     lda .str
        sta .s2
        lda .str+1
        sta .s2+1
.s2 = * + 1
        lda $FFFF,y             ; Zeichen
        sta vdc_src
        lda #0
        sta vdc_src+1
        ldx #3
-       asl vdc_src
        rol vdc_src+1
        dex
        bne -
        lda vdc_src
        ora vdc_n               ; Zeichen*8 + Zeile (die unteren 3 Bits sind frei)
        clc
        adc #<vdc_font
        sta .g
        lda vdc_src+1
        adc #>vdc_font
        sta .g+1
.g = * + 1
        lda $FFFF
        +vdc_wait
        sta VDC_DATA
        iny
        cpy vdc_w
        bne .ch
        lda vdc_dst
        clc
        adc #VDC_COLS
        sta vdc_dst
        bcc +
        inc vdc_dst+1
+       inc vdc_n
        lda vdc_n
        cmp #8
        bne .line
        ; Attribute: 4 Blockzeilen ab ty*4, Spalte tx
        lda vdc_ty
        asl
        asl
        sta vdc_dst
        lda #0
        sta vdc_dst+1
        jsr .mul80
        lda vdc_dst
        clc
        adc vdc_tx
        sta vdc_dst
        lda vdc_dst+1
        adc #>VDC_ATTR
        sta vdc_dst+1
        lda #4
        sta vdc_h
        lda vdc_tc
        jmp vdc_rect_fill
.mul80  lda vdc_dst             ; vdc_dst *= 80 (= *64 + *16)
        sta vdc_v
        lda vdc_dst+1
        sta vdc_sv
        ldx #4
-       asl vdc_dst
        rol vdc_dst+1
        dex
        bne -                   ; *16
        lda vdc_dst
        sta vdc_sv+1
        lda vdc_dst+1
        pha
        ldx #2
-       asl vdc_dst
        rol vdc_dst+1
        dex
        bne -                   ; *64
        lda vdc_dst
        clc
        adc vdc_sv+1
        sta vdc_dst
        pla
        adc vdc_dst+1
        sta vdc_dst+1
        rts
