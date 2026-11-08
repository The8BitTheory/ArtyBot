; video.asm - Textausgabe in Bildschirm- und Farb-RAM (Zeichenraster 40x25)
; Initialisierung und Zeichensatz-/Farbumschaltung: platform/cbm/vic2_gfx.asm
; put_str maps ASCII upper/lowercase to screen codes for the lower/uppercase set.

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

!zone paint
paint                           ; A = count: colour RAM from (cur_x,cur_y) set to cur_col (text stays)
        sta tmp3
        ldx cur_y
        lda row_lo,x
        clc
        adc cur_x
        sta ptr0
        lda row_hi,x
        adc #>(COLORRAM - SCREEN)
        sta ptr0+1
        ldy #0
        lda cur_col
.l      sta (ptr0),y
        iny
        cpy tmp3
        bne .l
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
