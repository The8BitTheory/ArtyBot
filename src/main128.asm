; main128.asm - Einstieg fuer das C128-Ziel (C128-Modus). Setzt TARGET und bindet
; main.asm ein. Bauen: acme -f cbm --cpu 6510 -o build/artybot128.prg src/main128.asm
TARGET = 2
!source "src/main.asm"
