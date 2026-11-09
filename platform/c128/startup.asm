; startup.asm (C128) - BASIC-7-Stub, MMU-Konfiguration, Vektoren, Hardware-Init
; C128-Modus. TARGET_C128: VIC-II (40 Zeichen) bei 1 MHz. TARGET_C128VDC: VDC-Bitmap bei 2 MHz,
; der VIC liefert nur noch den Raster-IRQ (50 Hz).

* = $1C01
        !word .next             ; 10 SYS 7181
        !word 10
        !byte $9E
        !text "7181"
        !byte 0
.next   !word 0

start
        !if start != 7181 {
            !error "start muss bei $1C0D (SYS 7181) liegen"
        }
!if TARGET = TARGET_C128VDC {
        jsr res_load            ; noch mit KERNAL: Ressource "artybot.gfx" nach Bank 1
}
        sei
        cld
        ldx #$FF
        txs

        ; Zeichensaetze aufbauen: Zeichensatz-ROM bei $D000 lesbar, RAM-Bank 0 sonst,
        ; Schreibzugriffe landen im RAM (auch unter $C000-$FFFF).
        lda #MMU_CFG_CHARROM
        sta MMU_CR
!if TARGET = TARGET_C128VDC {
        jsr vdc_copy_font       ; Zeichensatz-ROM -> VDC_FONT (Text als Bitmap)
} else {
        jsr vic2_upload_charsets
}

        ; Ab jetzt: nur RAM-Bank 0 und I/O (eigene Vektoren in $FFFA-$FFFF)
        lda #MMU_CFG_RAM_IO
        sta MMU_CR
        lda MMU_RCR             ; VIC liest RAM-Bank 0
        and #$3F
        sta MMU_RCR
        lda CPU_DDR             ; Prozessorport: Farb-RAM-Bank fuer CPU und VIC gleich,
        ora #CPU_PORT_VIDEO     ; kein Zeichensatz-ROM-Schatten im Bild des VIC
        sta CPU_DDR
        lda CPU_PORT
        ora #CPU_PORT_VIDEO
        sta CPU_PORT
!if TARGET = TARGET_C128VDC {
        lda #$0B                ; VIC-Bild aus (keine Badlines), dann 2 MHz
        sta VIC_CTRL1
        lda #1
} else {
        lda #0                  ; 1 MHz (VIC-II braucht alle Buszyklen)
}
        sta VIC_CLOCK
        lda #$FF                ; Zusatz-Tastaturzeilen abwaehlen
        sta VIC_KBD
!if TARGET = TARGET_C128VDC {
        jsr res_ready           ; gemeinsames RAM unten 16 KB, Ressource in Bank 1 da?
}

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
        jmp cbm_start
