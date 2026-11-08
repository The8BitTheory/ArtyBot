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

; Zeichensaetze und Sprites in die VIC-Bank kopieren: Spiel ($C800), Titel ($D000, RAM unter
; dem I/O-Bereich), Ende ($D800), jeweils ROM-Satz (Gross/Klein) + eigene Zeichen.
; Aufruf beim Start, solange das Zeichensatz-ROM bei $D000 sichtbar ist (Lesen = ROM,
; Schreiben = RAM darunter); die Speicherkonfiguration setzt der Startup der Plattform.
!zone vic2_upload_charsets
vic2_upload_charsets
        +copy $D800, CHARSET, $0800
        ; Custom icons stay in inverse character codes $E0-$F7.
        +copy gfx_icons, CHARSET + ICON_CHAR_BASE*8, ICON_CHAR_BYTES
        ; Robot directions occupy inverse charset characters $80-$83.
        +copy gfx_robot, CHARSET + ROBOT_CHAR_BASE*8, ROBOT_CHAR_BYTES
        +copy gfx_icons2, CHARSET + ICON2_CHAR_BASE*8, ICON2_CHAR_BYTES
        +copy gfx_run, CHARSET + RUN_CHAR_BASE*8, RUN_CHAR_BYTES
        +copy gfx_ui_frame, CHARSET + UI_FRAME_BASE*8, 8*8
        +copy gfx_ui_extra, CHARSET + UI_HAND*8, 2*8
        +copy gfx_sprites, SPRITES, SPRITE_BYTES
        +copy gfx_run_sprites, SPRITES + SPRITE_BYTES, RUN_SPR_BYTES
        ; Title charset in the RAM below the char ROM ($D000): writes there go
        ; to RAM while the ROM is visible. Lower/uppercase set + title graphics,
        ; plus window frame and hand from the game charset (same codes).
        +copy $D800, TITLE_CHARSET, $0800
        jsr title_charset_init
        +copy gfx_ui_frame, TITLE_CHARSET + UI_FRAME_BASE*8, 8*8
        +copy gfx_ui_extra, TITLE_CHARSET + UI_HAND*8, 2*8
        ; End screen charset in the RAM below $D800 (same way): ROM set, logo +
        ; trophy, window frame and hand.
        +copy $D800, END_CHARSET, $0800
        jsr end_charset_init
        +copy gfx_ui_frame, END_CHARSET + UI_FRAME_BASE*8, 8*8
        +copy gfx_ui_extra, END_CHARSET + UI_HAND*8, 2*8
        rts
