; platform.asm (C128) - plattformabhaengiger Code. main.asm bindet diese Datei als
; ersten Code ein: startup.asm setzt "* = $1C01" (BASIC-7-Stub, Einstieg bei $1C0D).

!source "platform/c128/startup.asm"
!source "platform/c128/system.asm"
!source "platform/c128/keyboard.asm"
!source "platform/cbm/irq.asm"
!source "platform/cbm/vic2_gfx.asm"
