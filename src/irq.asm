; irq.asm - Raster-IRQ (50 Hz), Frame-Sync, NMI-Stub

!zone irq_init
irq_init
        lda #RASTER_LINE
        sta VIC_RASTER
        lda VIC_CTRL1
        and #$7F                ; Rasterzeile Bit 8 = 0
        sta VIC_CTRL1
        lda #$01                ; Raster-IRQ an
        sta VIC_IMR
        rts

!zone irq_handler
irq_handler
        pha
        txa
        pha
        tya
        pha
        lda #$FF
        sta VIC_IRR             ; alle VIC-IRQs quittieren
        inc frame
        jsr sound_tick
        pla
        tay
        pla
        tax
        pla
        rti

nmi_handler                     ; RESTORE-Taste ignorieren
        rti

!zone wait_frame
wait_frame                      ; wartet auf den naechsten Frame
        lda frame
.w      cmp frame
        beq .w
        rts
