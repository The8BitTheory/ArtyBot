; keyboard.asm (C128) - Zusatztasten der C128-Tastatur ueber die VIC-IIe-Zeilen K0-K2.
; Die vier Pfeiltasten oben (Zeile K2, $D02F Bit 2 = 0) werden auf die Cursortasten der
; C64-Matrix abgebildet: hoch = Shift+CRSR U/D, runter = CRSR U/D, links = Shift+CRSR L/R,
; rechts = CRSR L/R. x128 legt die Pfeiltasten des PCs auf diese vier Tasten.
;   Zeile K2 ($DC01): Bit 0 ALT, 1 Ziffernblock 0, 2 Ziffernblock ., 3 hoch, 4 runter,
;   5 links, 6 rechts, 7 NO SCROLL (0 = gedrueckt)

KEYX_CRSR_UD = 7                ; Matrixcodes der C64-Cursortasten (wie KEY_CRSR_UD/LR)
KEYX_CRSR_LR = 2

; Aufruf am Ende von key_scan, wenn in der Matrix keine Taste gefunden wurde
; (CIA1_PRA = $40, Port 1 verbunden). Ausgang: A = Matrixcode oder $FF, key_shift.
!zone key_scan_extra
key_scan_extra
        lda #$FF                ; keine Hauptzeile: $DC01 zeigt nur Joystick-Port 1
        sta CIA1_PRA
        lda CIA1_PRB            ; Grundwert (1351-Maustasten, Joystick) zum Ausblenden
        eor #$FF
        sta tmp2
        lda #$FB                ; Zeile K2 waehlen
        sta VIC_KBD
        lda CIA1_PRB
        ora tmp2                ; Bits, die schon ohne K2 auf 0 waren, ignorieren
        sta tmp2
        lda #$FF
        sta VIC_KBD
        lda #$40
        sta CIA1_PRA
        lda tmp2
        and #$08
        beq .up
        lda tmp2
        and #$10
        beq .down
        lda tmp2
        and #$20
        beq .left
        lda tmp2
        and #$40
        beq .right
        lda #$FF
        rts
.up     lda #1
        sta key_shift
.down   lda #KEYX_CRSR_UD
        rts
.left   lda #1
        sta key_shift
.right  lda #KEYX_CRSR_LR
        rts
