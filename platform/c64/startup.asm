; startup.asm (C64) - BASIC-Stub, Speicherkonfiguration, Vektoren, Hardware-Init

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

        ; Zeichensaetze aufbauen (ROM-Satz + eigene Zeichen, Sprites).
        ; $32 = BASIC aus, KERNAL an, Char-ROM sichtbar (Code kann ueber $A000 liegen!)
        lda #$32
        sta CPU_PORT
        jsr vic2_upload_charsets

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

        jmp cbm_start
