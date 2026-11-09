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
        jsr music_tick
        jsr ambient_tick
        pla
        tay
        pla
        tax
        pla
        rti

nmi_handler                     ; RESTORE-Taste ignorieren
        rti

!zone wait_frame
!if TARGET = TARGET_C128VDC {
; VDC: Takt des Spiels = Bildwechsel des VDC (nicht synchron zum VIC-Raster-IRQ, der weiter
; Sound/Musik treibt). Rueckkehr am Beginn des unteren Rands (Status-Bit 5: 0 -> 1): danach
; ist der VDC rund 112 Zeilen lang nicht im sichtbaren Bild, Zeiger und Figuren werden dann
; ohne Flackern gezeichnet und der VDC ist nach jedem Zugriff schnell wieder bereit.
wait_frame
-       lda VDC_STATUS          ; noch im Rand: erst das sichtbare Bild abwarten
        and #$20
        bne -
-       lda VDC_STATUS
        and #$20
        beq -
        rts
} else {
wait_frame                      ; wartet auf den naechsten Frame
        lda frame
.w      cmp frame
        beq .w
        rts
}

; Gemeinsamer Abschluss des Startups (C64, C128): Speicherkonfiguration und Vektoren
; sind gesetzt. CIA- und VIC-Interrupts aus, Grafik, Sound, Raster-IRQ an, Spiel starten.
!zone cbm_start
cbm_start
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
