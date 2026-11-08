; platform.inc (C128, C128-Modus: VIC-II 40 Zeichen oder VDC 80 Zeichen) - Register und Speicherlayout
; Eingebunden von main.asm vor inc/defs.inc. Gegenstueck: platform/c128/platform.asm (Code).

; --- CPU (8502-Prozessorport, im C128-Modus andere Bedeutung als beim 6510)
CPU_DDR     = $00
CPU_PORT    = $01           ; Bit 0: Farb-RAM-Bank der CPU, Bit 1: der des VIC,
                            ; Bit 2: 1 = VIC sieht kein Zeichensatz-ROM (sonst in allen Baenken)
CPU_PORT_VIDEO = $07        ; Bits 0-2 setzen: Farb-RAM-Bank 1 fuer beide, kein ROM-Schatten

; --- MMU 8722
MMU_CR      = $FF00         ; Konfigurationsregister (immer sichtbar, auch $D500)
MMU_RCR     = $D506         ; RAM-Konfiguration: Bits 6-7 = RAM-Bank des VIC
MMU_CFG_RAM_IO   = $3E      ; RAM-Bank 0 ueberall, I/O bei $D000 (Spielbetrieb)
MMU_CFG_CHARROM  = $0F      ; RAM-Bank 0 bis $BFFF, Zeichensatz-ROM bei $D000, System-ROM
                            ; bei $C000/$E000 (Lesen); Schreiben geht immer ins RAM darunter
MMU_CFG_SYSTEM   = $00      ; System-ROMs + I/O (BASIC-Bank 15), fuer den Reset

; --- VIC-IIe-Zusatzregister
VIC_KBD     = $D02F         ; Zusatz-Tastaturzeilen K0-K2 (Bit = 0 waehlt die Zeile)
VIC_CLOCK   = $D030         ; Bit 0: 0 = 1 MHz, 1 = 2 MHz

!source "platform/cbm/vic2.inc"
!source "platform/cbm/sidcia.inc"

; --- Speicherlayout: PRG ab $1C01 (BASIC-7-Stub), VIC-Bank 3 = $C000-$FFFF in RAM-Bank 0.
; $FF00-$FF04 sind MMU-Register (dort nichts ablegen). $0400-$1BFF ist ungenutzt.
LOAD_ADDR   = $1C01
BANK_BASE   = $C000
SCREEN      = $C000
CHARSET     = $C800
TITLE_CHARSET = $D000         ; title screen charset (RAM under I/O)
END_CHARSET   = $D800         ; end screen charset (RAM under I/O)
SPRITES     = $E000
SPR_PTR0    = SCREEN + $3F8
SPRITE_BLOCK= (SPRITES - BANK_BASE) >> 6
SPRITE_BLOCK1 = SPRITE_BLOCK + 1
SPRITE_BLOCK2 = SPRITE_BLOCK + 2
!if TARGET = TARGET_C128VDC {
; VDC-Ziel: der VIC zeigt nichts (Bild aus, 2 MHz), sein Speicher ist frei. Programm bis $CFFF,
; $D000-$DFFF ist I/O; $E000-$FEFF RAM fuer Daten (Zeichensatz-Kopie, Puffer).
CODE_LIMIT  = $D000
VDC_FONT    = $E000             ; 2 KB: Zeichensatz-ROM $D800 (Gross-/Kleinbuchstaben), Index = Screencode
VDC_SAVE    = $E800             ; Puffer der View (Zeiger-Hintergrund u. a.), bis $FEFF
MOUSE_X_MAX = 639               ; Mauszeiger ueber die volle VDC-Breite
MOUSE_X_FAST = 1                ; x-Bewegung doppelt (Pixel sind halb so breit)
} else {
CODE_LIMIT  = $C000
}

GAME_MEMPTR   = $02             ; screen $C000, charset $C800
TITLE_MEMPTR  = $04             ; screen $C000, charset $D000
END_MEMPTR    = $06             ; screen $C000, charset $D800
