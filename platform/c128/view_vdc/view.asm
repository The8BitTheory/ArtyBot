; view.asm (VDC) - Darstellung fuer den C128 mit VDC: Bitmap 640x200, Attribute je 8x2 Pixel.
; Einstiegspunkte wie die VIC-II-View (HANDOVER.md, Abschnitt "View-Schnittstelle").

PROGRAM_ROWS = 20               ; sichtbare Programmzeilen (gemeinsamer Plan/Run-Bildschirm)
INFO_W       = 16

!source "platform/c128/view_vdc/text.asm"
!source "platform/c128/view_vdc/pointer.asm"
!source "platform/c128/view_vdc/title.asm"
!source "platform/c128/view_vdc/sprite.asm"
!source "platform/c128/view_vdc/world.asm"
!source "platform/c128/view_vdc/stubs.asm"        ; noch nicht umgesetzte Bildschirme

; Alle Software-Figuren und den Zeiger vom Bild nehmen.
view_sprites_off
        jsr vp_hide
        jmp ss_hide_all

; Grafikdaten
!source "platform/c128/view_vdc/gfx_vdc_title.asm"    ; tools/gen_vdc_title.py
!source "platform/c128/view_vdc/gfx_vdc.asm"          ; tools/gen_vdc_gfx.py
