; view.asm (VIC-II) - Darstellung fuer C64 und C128 (40 Zeichen): Bildschirme, Spielfeld,
; Sprites, Treffertests der Maus. Die Logik in src/ ruft nur die hier definierten
; Einstiegspunkte (Liste: HANDOVER.md, Abschnitt "View-Schnittstelle").

!source "platform/cbm/view_vic2/text.asm"         ; Textausgabe (Zeichenraster 40x25)
!source "platform/cbm/view_vic2/title.asm"
!source "platform/cbm/view_vic2/world.asm"
!source "platform/cbm/view_vic2/pointer.asm"
!source "platform/cbm/view_vic2/plan.asm"
!source "platform/cbm/view_vic2/run.asm"

; Grafikdaten (Zeichen, Sprites) - gfx_run/gfx_winter/gfx_title sind generiert
!source "platform/cbm/view_vic2/gfx_data.asm"
!source "platform/cbm/view_vic2/gfx_run.asm"       ; tools/gen_gfx_run.py
!source "platform/cbm/view_vic2/gfx_winter.asm"    ; tools/gen_theme_winter.py
!source "platform/cbm/view_vic2/gfx_title.asm"     ; tools/gen_title.py
