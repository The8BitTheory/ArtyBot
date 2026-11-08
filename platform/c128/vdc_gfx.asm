; vdc_gfx.asm (C128, TARGET_C128VDC) - Grundlage der Darstellung auf dem VDC: Init (64-KB-Test,
; Bitmap 640x200 mit Attributen), Bildschirm loeschen, Zeichensatz-Kopie. Gegenstueck zu
; platform/cbm/vic2_gfx.asm; Zeichensatz-/Theme-Umschaltung gibt es hier nicht (Text als Bitmap,
; Kachelfarben stecken in den Attributen der Kacheln).

vdc_font = VDC_FONT             ; fuer vdc_text (Treiber)

; Beim Start (MMU_CFG_CHARROM): Zeichensatz-ROM $D800 (Gross-/Kleinbuchstaben) -> VDC_FONT.
!zone vdc_copy_font
vdc_copy_font
        ldx #0
-       !for p, 8 {
        lda $D800+(p-1)*256,x
        sta VDC_FONT+(p-1)*256,x
        }
        inx
        bne -
        rts

!zone video_init
video_init
        ldx #28                 ; 64-KB-Adressierung vor dem Test
        jsr vdc_rd
        ora #$10
        jsr vdc_wr_data
        jsr vdc_has_64k
        bcs .ok
        jmp vdc_no_64k
.ok     jsr vdc_init_bitmap
        jsr vt_init             ; Rahmen-/Handglyphen in die Zeichensatz-Kopie
        ; weiter mit clear_screen

; Ganzer Bildschirm: Bitmap leer, Attribute weiss auf schwarz.
!zone clear_screen
clear_screen
        jsr vp_forget           ; Zeiger ist mit geloescht
        lda #<VDC_BITMAP
        sta vdc_dst
        lda #>VDC_BITMAP
        sta vdc_dst+1
        lda #<16000
        sta vdc_cnt
        lda #>16000
        sta vdc_cnt+1
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
        lda #$0F
        jmp vdc_fill

; Keine Zeichensaetze/Multicolour-Register auf dem VDC.
gfx_theme_colors
gfx_charset_game
gfx_charset_title
gfx_charset_end
        rts

; Figuren aus: Zeiger und Software-Sprites der View verschwinden.
gfx_sprites_off
        jmp view_sprites_off

; Nur 16 KB VDC-RAM: Hinweis im Textmodus (Bildschirm $0000, Attribute $0800 wie vom KERNAL
; eingerichtet), auf eine Taste warten, C128 neu starten.
!zone vdc_no_64k
vdc_no_64k
        lda #$00
        ldy #$00
        jsr vdc_addr
        ldy #0
.l      lda str_vdc_16k,y
        beq .attr
        jsr ascii2scr
        jsr vdc_put
        iny
        bne .l
.attr   lda #$08
        ldy #$00
        jsr vdc_addr
        ldy #80
        lda #$89                ; hellrot, zweiter Zeichensatz (Gross/Klein, Bit 7)
-       jsr vdc_put
        dey
        bne -
        lda #0                  ; alle Tastaturzeilen
        sta CIA1_PRA
-       lda CIA1_PRB            ; Taste loslassen ...
        cmp #$FF
        bne -
-       lda CIA1_PRB            ; ... und neu druecken
        cmp #$FF
        beq -
        jmp system_reset

str_vdc_16k !text "ArtyBot needs 64 KB of VDC RAM (C128 DCR or upgraded C128). Any key: reset.", 0
