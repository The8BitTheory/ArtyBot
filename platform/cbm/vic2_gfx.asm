; vic2_gfx.asm - VIC-II-Grafiktreiber (C64, C128 40 Zeichen): Init, Bildschirm loeschen,
; Zeichensatz- und Farbumschaltung, Sprites aus. Spiel-Code ruft nur diese Routinen auf,
; Sprite-Positionen/-Farben schreiben run.asm, world.asm, sprites.asm noch direkt (Schritt 3).

!zone video_init
video_init
        lda CIA2_DDRA
        ora #$03
        sta CIA2_DDRA
        lda CIA2_PRA
        and #$FC                ; %00 = VIC-Bank 3 ($C000-$FFFF)
        sta CIA2_PRA
        lda #GAME_MEMPTR        ; Screen = Bank+$0000, Charset = Bank+$0800
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
        lda theme_bg1           ; multicolour colours of the loaded theme
        sta VIC_BG1
        lda theme_bg2
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

; Multicolour-Hintergrundfarben des geladenen Themes (theme_bg1/2) setzen.
!zone gfx_theme_colors
gfx_theme_colors
        lda theme_bg1
        sta VIC_BG1
        lda theme_bg2
        sta VIC_BG2
        rts

; Zeichensatz umschalten: Spiel ($C800), Titel ($D000), Ende ($D800).
!zone gfx_charset
gfx_charset_game
        lda #GAME_MEMPTR
        sta VIC_MEMPTR
        rts
gfx_charset_title
        lda #TITLE_MEMPTR
        sta VIC_MEMPTR
        rts
gfx_charset_end
        lda #END_MEMPTR
        sta VIC_MEMPTR
        rts

; Alle Sprites aus. A = 0 danach.
!zone gfx_sprites_off
gfx_sprites_off
        lda #0
        sta VIC_SPR_EN
        rts
