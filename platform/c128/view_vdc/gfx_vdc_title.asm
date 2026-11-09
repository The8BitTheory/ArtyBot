; gfx_vdc_title.asm - generiert von tools/gen_vdc_title.py, nicht von Hand aendern
; Je Bild: Kopf (Breite in Bytes, Hoehe in Zeilen) und entpackte Groesse. Die gepackten Daten
; liegen in der Ressource-Datei (res_vdc_title.asm, Bank 1) und kommen beim Start in den VRAM.

vti_logo_n = 5250                 ; entpackte Groesse (Bitmap + Attribute)
vti_logo
        !byte 70, 50

vti_robot_n = 3432                 ; entpackte Groesse (Bitmap + Attribute)
vti_robot
        !byte 22, 104

vti_blink_n = 19
vti_blink_dx  !byte 10,11,9,11,12,9,10,11,12,9,10,11,12,9,10,11,12,10,11
vti_blink_dy  !byte 0,0,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5
vti_blink_on  !byte $99,$99,$09,$99,$09,$99,$99,$99,$99,$99,$99,$99,$99,$09,$99,$99,$09,$99,$99
vti_blink_off !byte $DD,$DD,$0D,$DD,$0D,$DD,$DD,$DD,$DD,$DD,$DD,$DD,$DD,$0D,$DD,$DD,$0D,$DD,$DD

vti_chest_n = 378                 ; entpackte Groesse (Bitmap + Attribute)
vti_chest
        !byte 9, 28

vti_trophy_n = 4992                 ; entpackte Groesse (Bitmap + Attribute)
vti_trophy
        !byte 32, 104
