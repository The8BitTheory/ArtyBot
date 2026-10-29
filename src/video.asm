; video.asm - VIC-Init (Bank 3, lower/uppercase charset), Text, Tiles
; put_str maps ASCII upper/lowercase to screen codes for the lower/uppercase set.

!zone video_init
video_init
        lda CIA2_DDRA
        ora #$03
        sta CIA2_DDRA
        lda CIA2_PRA
        and #$FC                ; %00 = VIC-Bank 3 ($C000-$FFFF)
        sta CIA2_PRA
        lda #$02                ; Screen = Bank+$0000, Charset = Bank+$0800
        sta VIC_MEMPTR
        lda #$1B
        sta VIC_CTRL1
        lda #$18                ; 40 Spalten, Multicolor an
        sta VIC_CTRL2
        lda #0
        sta VIC_SPR_EN          ; static screen prototype has no sprites
        sta VIC_SPRXMSB
        lda #COL_BLACK
        sta VIC_BORDER
        sta VIC_BG0
        lda #COL_DGREY
        sta VIC_BG1
        lda #COL_ORANGE
        sta VIC_BG2
        ; weiter mit clear_screen

!zone clear_screen
clear_screen
        ldx #0
.l      lda #$20
        sta SCREEN,x
        sta SCREEN+$100,x
        sta SCREEN+$200,x
        sta SCREEN+$300,x
        lda #COL_WHITE          ; Farbe < 8 = Hires-Zeichen (Text)
        sta COLORRAM,x
        sta COLORRAM+$100,x
        sta COLORRAM+$200,x
        sta COLORRAM+$300,x
        inx
        bne .l
        rts

; ---- Text -------------------------------------------------------------
set_cursor                      ; X = Spalte, Y = Zeile
        stx cur_x
        sty cur_y
        rts

!zone put_char
put_char                        ; A = Screencode an (cur_x,cur_y) in Farbe cur_col
        sta tmp2
        ldx cur_y
        lda row_lo,x
        clc
        adc cur_x
        sta ptr0
        lda row_hi,x
        adc #0
        sta ptr0+1
        ldy #0
        lda tmp2
        sta (ptr0),y
        lda ptr0+1
        clc
        adc #>(COLORRAM - SCREEN)
        sta ptr0+1
        lda cur_col
        sta (ptr0),y
        inc cur_x
        rts

!zone put_str
put_str                         ; A/X = Adresse (lo/hi) eines 0-terminierten ASCII-Strings
        sta ptr2
        stx ptr2+1
        ldy #0
.l      sty tmp3
        lda (ptr2),y
        beq .d
        jsr ascii2scr
        jsr put_char
        ldy tmp3
        iny
        bne .l
.d      rts

!zone ascii2scr
ascii2scr                       ; ASCII lowercase -> 1..26; uppercase keeps $41..$5A.
        cmp #$41
        bcc .done
        cmp #$5B
        bcc .done
        cmp #$61
        bcc .done
        cmp #$7B
        bcs .done
        sec
        sbc #$60
.done   rts

!zone print_hex8
print_hex8                      ; A = Wert
        pha
        lsr
        lsr
        lsr
        lsr
        jsr print_nibble
        pla
        and #$0F
print_nibble
        tax
        lda hexdigits,x
        jmp put_char

; ---- Tiles ------------------------------------------------------------
; draw_tile: A = Tile-ID, tile_x/tile_y = Feldkoordinate
!zone draw_tile
draw_tile
        sta tmp2
        lda tile_y
        asl
        clc
        adc #FIELD_ROW
        tax
        lda tile_x
        asl
        clc
        adc #FIELD_COL
        clc
        adc row_lo,x
        sta ptr0
        lda row_hi,x
        adc #0
        sta ptr0+1
        lda ptr0                ; ptr1 = Farb-RAM-Adresse
        sta ptr1
        lda ptr0+1
        clc
        adc #>(COLORRAM - SCREEN)
        sta ptr1+1

        lda tmp2                ; Zeichencode = $80 + id*4
        asl
        asl
        clc
        adc #CHAR_TILE_BASE
        sta tmp3
        ldy #0
        sta (ptr0),y
        inc tmp3
        iny
        lda tmp3
        sta (ptr0),y
        inc tmp3
        ldy #40
        lda tmp3
        sta (ptr0),y
        inc tmp3
        iny
        lda tmp3
        sta (ptr0),y

        ldx tmp2                ; Farbe (Bit 3 = Multicolor)
        lda tile_color,x
        ora #$08
        sta (ptr1),y            ; Y = 41
        ldy #40
        sta (ptr1),y
        ldy #1
        sta (ptr1),y
        ldy #0
        sta (ptr1),y
        rts

!zone draw_map
draw_map
        lda #0
        sta tile_y
.row    lda #0
        sta tile_x
.col    lda tile_y
        asl
        asl
        asl
        asl
        ora tile_x
        tax
        lda map_work,x
        jsr draw_tile
        inc tile_x
        lda tile_x
        cmp #MAP_W
        bne .col
        inc tile_y
        lda tile_y
        cmp #MAP_H
        bne .row
        rts

; ---- Tabellen -----------------------------------------------------------
row_lo
        !for i, 26 {
            !byte <(SCREEN + (i-1)*40)
        }
row_hi
        !for i, 26 {
            !byte >(SCREEN + (i-1)*40)
        }
hexdigits
        !byte $30,$31,$32,$33,$34,$35,$36,$37,$38,$39,$41,$42,$43,$44,$45,$46
tile_color                      ; Farbe "11" je Tile: Boden, Wand, Kiste, Ziel
        !byte COL_WHITE, COL_RED, COL_YELLOW, COL_GREEN
