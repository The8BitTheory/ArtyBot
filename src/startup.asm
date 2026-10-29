; startup.asm - BASIC-Stub, Hardware-Init, Datenkopie

* = $0801
        !word .next             ; 10 SYS 2061
        !word 10
        !byte $9E
        !text "2061"
        !byte 0
.next   !word 0

start
        !if start != 2061 {
            !error "start muss bei $080D (SYS 2061) liegen"
        }
        sei
        cld
        ldx #$FF
        txs
        lda #$2F
        sta CPU_DDR

        ; Lower/uppercase-Zeichensatz-ROM nach $C800 kopieren.
        ; $32 = BASIC aus, KERNAL an, Char-ROM sichtbar (Code kann ueber $A000 liegen!)
        lda #$32
        sta CPU_PORT
        +copy $D800, CHARSET, $0800
        ; Custom icons stay in inverse character codes $E0-$F7.
        +copy gfx_icons, CHARSET + ICON_CHAR_BASE*8, ICON_CHAR_BYTES
        ; Robot directions occupy inverse charset characters $80-$83.
        +copy gfx_robot, CHARSET + ROBOT_CHAR_BASE*8, ROBOT_CHAR_BYTES
        +copy gfx_run, CHARSET + RUN_CHAR_BASE*8, RUN_CHAR_BYTES
        +copy gfx_sprites, SPRITES, SPRITE_BYTES
        +copy gfx_run_sprites, SPRITES + SPRITE_BYTES, RUN_SPR_BYTES

        ; Ab jetzt: alle ROMs aus, nur I/O (eigene Vektoren in $FFFA-$FFFF)
        lda #$35
        sta CPU_PORT

        lda #<nmi_handler
        sta $FFFA
        lda #>nmi_handler
        sta $FFFB
        lda #<start
        sta $FFFC
        lda #>start
        sta $FFFD
        lda #<irq_handler
        sta $FFFE
        lda #>irq_handler
        sta $FFFF

        ; CIA-Interrupts aus, VIC-IRQs aus und quittieren
        lda #$7F
        sta CIA1_ICR
        sta CIA2_ICR
        lda CIA1_ICR
        lda CIA2_ICR
        lda #0
        sta VIC_IMR
        lda #$FF
        sta VIC_IRR

        jsr video_init
        jsr sound_init
        jsr irq_init
        cli
        jmp game_main
