; platform.inc (C64) - Hardware-Register und Speicherlayout
; Eingebunden von main.asm vor inc/defs.inc. Gegenstueck: platform/c64/platform.asm (Code).

; --- CPU (6510-Prozessorport)
CPU_DDR     = $00
CPU_PORT    = $01

!source "platform/cbm/vic2.inc"
!source "platform/cbm/sidcia.inc"

; --- Speicherlayout: PRG ab $0801 (BASIC-Stub), VIC-Bank 3 = $C000-$FFFF
LOAD_ADDR   = $0801
BANK_BASE   = $C000
SCREEN      = $C000
CHARSET     = $C800
TITLE_CHARSET = $D000         ; title screen charset (RAM under I/O, see title.asm)
END_CHARSET   = $D800         ; end screen charset (RAM under the colour RAM, see title.asm)
SPRITES     = $E000
SPR_PTR0    = SCREEN + $3F8
SPRITE_BLOCK= (SPRITES - BANK_BASE) >> 6
SPRITE_BLOCK1 = SPRITE_BLOCK + 1
SPRITE_BLOCK2 = SPRITE_BLOCK + 2   ; black outline of the mouse pointer (sprite 2 in plan mode / world map)
CODE_LIMIT  = $C000           ; program must end below the VIC bank

; $D018-Werte (Bildschirm $C000 + Zeichensatz) fuer die drei Zeichensaetze
GAME_MEMPTR   = $02             ; screen $C000, charset $C800
TITLE_MEMPTR  = $04             ; screen $C000, charset $D000
END_MEMPTR    = $06             ; screen $C000, charset $D800
