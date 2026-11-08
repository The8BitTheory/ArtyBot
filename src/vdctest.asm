; vdctest.asm - Testbild fuer den VDC-Treiber (platform/c128/vdc.asm), eigenes PRG fuer x128.
; Bauen: acme -f cbm --cpu 6510 -o build/vdctest.prg src/vdctest.asm
; Zeigt: 16 Farbbalken, Attribut-Streifen (8x2), Schachbrett, Text aus dem Zeichensatz-ROM,
; eine Kachel 10x per Blitter (VRAM->VRAM) aus der Ablage kopiert.
; Ohne 64 KB VDC-RAM: roter Rahmen im Textmodus, Programm bleibt stehen.

!cpu 6510
TARGET_C64 = 1
TARGET_C128 = 2
TARGET_C128VDC = 3
TARGET = TARGET_C128VDC
!source "platform/c128/platform.inc"

vdc_src = $E0
vdc_dst = $E2
vdc_cnt = $E4
vdc_w   = $E6
vdc_h   = $E7
vdc_n   = $E8
vdc_v   = $E9
vdc_sv  = $EA                   ; 2 Byte
vdc_tx  = $EC
vdc_ty  = $ED
vdc_tc  = $EE
t_i     = $EF

* = $1C01
        !word .next
        !word 10
        !byte $9E
        !text "7181"
        !byte 0
.next   !word 0

start   sei
        cld
        ldx #$FF
        txs
        lda #MMU_CFG_CHARROM    ; Zeichensatz-ROM lesbar: Gross/Klein-Satz nach vdc_font
        sta MMU_CR
        ldx #0
-       !for p, 8 {
        lda $D800+(p-1)*256,x
        sta vdc_font+(p-1)*256,x
        }
        inx
        bne -
        lda #MMU_CFG_RAM_IO
        sta MMU_CR
        lda #1                  ; 2 MHz
        sta VIC_CLOCK
        jsr vdc_has_64k
        bcs .ok
        ldx #26                 ; 16 KB: roter Rahmen, Ende
        lda #$80
        jsr vdc_wr
        jmp *
.ok     jsr vdc_init_bitmap

        ; Titel weiss auf dunkelblau
        lda #0
        sta vdc_tx
        sta vdc_ty
        lda #$2F
        sta vdc_tc
        lda #<str_title
        ldx #>str_title
        jsr vdc_text

        ; 16 Farbbalken: Attributzeilen 8..27, je 5 Spalten
        lda #0
        sta t_i
.bar    lda t_i
        asl
        asl
        clc
        adc t_i                 ; *5
        clc
        adc #<(VDC_ATTR + 8*80)
        sta vdc_dst
        lda #>(VDC_ATTR + 8*80)
        adc #0
        sta vdc_dst+1
        lda #5
        sta vdc_w
        lda #20
        sta vdc_h
        lda t_i
        asl
        asl
        asl
        asl
        ora t_i
        jsr vdc_rect_fill
        inc t_i
        lda t_i
        cmp #16
        bne .bar

        ; Attribut-Streifen: Blockzeilen 30..45, Farbe = Zeile (zeigt das 2-Zeilen-Raster)
        lda #30
        sta t_i
.str    lda t_i
        sta vdc_dst
        lda #0
        sta vdc_dst+1
        jsr mul80
        lda vdc_dst
        clc
        adc #<VDC_ATTR
        sta vdc_dst
        lda vdc_dst+1
        adc #>VDC_ATTR
        sta vdc_dst+1
        lda #80
        sta vdc_cnt
        lda #0
        sta vdc_cnt+1
        lda t_i
        and #15
        asl
        asl
        asl
        asl
        jsr vdc_fill
        inc t_i
        lda t_i
        cmp #46
        bne .str

        ; Schachbrett: Bitmapzeilen 96..119, Spalten 0..39 ($AA/$55), weiss auf schwarz
        lda #<(96*80)
        sta vdc_dst
        lda #>(96*80)
        sta vdc_dst+1
        lda #24
        sta t_i
.chk    lda #40
        sta vdc_cnt
        lda #0
        sta vdc_cnt+1
        lda t_i
        and #1
        beq +
        lda #$AA
        !byte $2C
+       lda #$55
        jsr vdc_fill
        lda vdc_dst             ; vdc_fill laesst vdc_dst stehen
        clc
        adc #80
        sta vdc_dst
        bcc +
        inc vdc_dst+1
+       dec t_i
        bne .chk
        lda #<(VDC_ATTR + 48*80)
        sta vdc_dst
        lda #>(VDC_ATTR + 48*80)
        sta vdc_dst+1
        lda #40
        sta vdc_w
        lda #12
        sta vdc_h
        lda #$0F
        jsr vdc_rect_fill

        ; Text in verschiedenen Farben
        lda #42
        sta vdc_tx
        lda #12
        sta vdc_ty
        lda #$0D                ; gelb auf schwarz
        sta vdc_tc
        lda #<str_abc
        ldx #>str_abc
        jsr vdc_text
        lda #42
        sta vdc_tx
        lda #13
        sta vdc_ty
        lda #$57                ; hellcyan auf hellgruen
        sta vdc_tc
        lda #<str_num
        ldx #>str_num
        jsr vdc_text

        ; Kachel in die Ablage laden und 10x per Blitter kopieren (Zeilen 160..175)
        lda #<tile
        sta vdc_src
        lda #>tile
        sta vdc_src+1
        lda #<VDC_STORE
        sta vdc_dst
        lda #>VDC_STORE
        sta vdc_dst+1
        lda #64
        sta vdc_cnt
        lda #0
        sta vdc_cnt+1
        jsr vdc_upload
        lda #0
        sta t_i
.tl     lda #<VDC_STORE
        sta vdc_src
        lda #>VDC_STORE
        sta vdc_src+1
        lda t_i
        asl
        asl
        asl                     ; 8 Byte Abstand
        clc
        adc #<(160*80)
        sta vdc_dst
        lda #>(160*80)
        adc #0
        sta vdc_dst+1
        lda #4
        sta vdc_w
        lda #16
        sta vdc_h
        jsr vdc_rect
        lda t_i                 ; Attribute: 4 x 8 Bloecke, Farbe je Kachel
        asl
        asl
        asl
        clc
        adc #<(VDC_ATTR + 80*80)
        sta vdc_dst
        lda #>(VDC_ATTR + 80*80)
        adc #0
        sta vdc_dst+1
        lda #4
        sta vdc_w
        lda #8
        sta vdc_h
        ldx t_i
        lda tile_col,x
        jsr vdc_rect_fill
        inc t_i
        lda t_i
        cmp #10
        bne .tl
        jmp *

mul80   lda vdc_dst             ; vdc_dst *= 80
        sta vdc_sv
        lda vdc_dst+1
        sta vdc_sv+1
        ldx #2
-       asl vdc_dst
        rol vdc_dst+1
        dex
        bne -
        lda vdc_dst
        clc
        adc vdc_sv
        sta vdc_dst
        lda vdc_dst+1
        adc vdc_sv+1
        sta vdc_dst+1           ; *5
        ldx #4
-       asl vdc_dst
        rol vdc_dst+1
        dex
        bne -                   ; *16
        rts

str_title !scr "ArtyBot VDC-Test: 640x200 Bitmap, Farbe pro 8x2 Pixel (64 KB)",0
str_abc   !scr "abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLM",0
str_num   !scr "0123456789 !?.,:;()+-*/=<> NOPQRSTUVWXYZ",0
tile_col  !byte $45, $5D, $C9, $3F, $27, $8D, $E1, $6B, $1C, $A5
tile      ; 32x16 Rahmen mit Diagonale
        !byte $FF,$FF,$FF,$FF
        !for i, 14 {
        !byte $80 | ($80 >> ((i-1)&7)), 0, 0, $01 | (1 << ((i-1)&7))
        }
        !byte $FF,$FF,$FF,$FF

!source "platform/c128/vdc.asm"

vdc_font !fill 2048, 0
