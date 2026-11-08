; keyboard.asm (C64) - Plattform-Tasten ausserhalb der 8x8-Matrix: keine.

; Aufruf am Ende von key_scan, wenn in der Matrix keine Taste gefunden wurde.
; Ausgang: A = Matrixcode oder $FF, ggf. key_shift gesetzt.
!zone key_scan_extra
key_scan_extra
        lda #$FF
        rts
