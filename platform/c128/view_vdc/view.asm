; view.asm (VDC) - Darstellung fuer den C128 mit VDC: Bitmap 640x200, Attribute je 8x2 Pixel.
; Einstiegspunkte wie die VIC-II-View (HANDOVER.md, Abschnitt "View-Schnittstelle").

PROGRAM_ROWS = 20               ; sichtbare Programmzeilen (gemeinsamer Plan/Run-Bildschirm)
INFO_W       = 16

; Grafikdaten zuerst (store.asm verteilt die Ablage nach ihren Groessen)
!source "platform/c128/view_vdc/gfx_vdc_title.asm"    ; tools/gen_vdc_title.py
!source "platform/c128/view_vdc/gfx_vdc.asm"          ; tools/gen_vdc_gfx.py
!source "platform/c128/view_vdc/store.asm"            ; VRAM-Ablage, Hochladen, Entpacken
!source "platform/c128/view_vdc/text.asm"
!source "platform/c128/view_vdc/pointer.asm"
!source "platform/c128/view_vdc/title.asm"
!source "platform/c128/view_vdc/sprite.asm"
!source "platform/c128/view_vdc/world.asm"
!source "platform/c128/view_vdc/planrun.asm"      ; gemeinsamer Plan-/Run-Bildschirm

; Welcher Bildschirm steht (clear_screen setzt 0): Plan/Run baut nur bei Bedarf neu auf.
VW_NONE     = 0
VW_WORLD    = 1
VW_PLANRUN  = 2
vw_screen   !byte 0
vw_mode     !byte 0             ; Plan/Run-Bildschirm: 0 Planen, 1 Lauf
vw_msg_row  !byte 23            ; Meldungszeile (run_draw_message) und Zahl der Zeilen
vw_msg_rows !byte 1

; Alle Software-Figuren und den Zeiger vom Bild nehmen.
view_sprites_off
        jsr vp_hide
        jmp ss_hide_all


