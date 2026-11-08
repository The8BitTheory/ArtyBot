; startup.asm (C128) - BASIC-7-Stub, MMU-Konfiguration, Vektoren, Hardware-Init
; Laeuft im C128-Modus mit dem VIC-II (40 Zeichen) bei 1 MHz; der VDC bleibt unbenutzt.

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
        sei
        cld
        ldx #$FF
        txs

        ; Zeichensaetze aufbauen: Zeichensatz-ROM bei $D000 lesbar, RAM-Bank 0 sonst,
        ; Schreibzugriffe landen im RAM (auch unter $C000-$FFFF).
        lda #MMU_CFG_CHARROM
        sta MMU_CR
        jsr vic2_upload_charsets

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
        lda #0                  ; 1 MHz (VIC-II braucht alle Buszyklen)
        sta VIC_CLOCK
        lda #$FF                ; Zusatz-Tastaturzeilen abwaehlen
        sta VIC_KBD

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
