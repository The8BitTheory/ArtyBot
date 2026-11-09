; res128vdc.asm - Ressource-Datei "artybot.gfx" fuer das VDC-Ziel: Grafik, die nur im VRAM
; gebraucht wird. Wird beim Start nach Bank 1 geladen (platform/c128/bank1.asm) und von dort
; in die VRAM-Ablage gebracht; belegt keinen Programmspeicher.
; Bauen: acme -f cbm -o build/artybot.gfx src/res128vdc.asm
; Aufbau: Tabelle (Adressen der Teile, Reihenfolge = RES_* in platform/c128/bank1.asm),
; dann die Daten.

!cpu 6510
RES_BASE = $4000                ; muss zu platform/c128/bank1.asm passen
RES_MAGIC = $A7                 ; erstes Byte: Kennung (falscher/alter Stand erkennbar)

* = RES_BASE
        !byte RES_MAGIC, RES_COUNT
res_table
        !word vti_logo_d, vti_robot_d, vti_chest_d, vti_trophy_d
        !word vdc_icons, vdc_mini_meadow
RES_COUNT = (* - res_table) / 2

!source "platform/c128/view_vdc/res_vdc_title.asm"   ; tools/gen_vdc_title.py
!source "platform/c128/view_vdc/res_vdc_gfx.asm"     ; tools/gen_vdc_gfx.py
res_end
