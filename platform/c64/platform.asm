; platform.asm (C64) - plattformabhaengiger Code. main.asm bindet diese Datei als
; ersten Code ein: startup.asm setzt "* = $0801" (BASIC-Stub, Einstieg bei $080D).

!source "platform/c64/startup.asm"
!source "platform/c64/system.asm"
!source "platform/c64/keyboard.asm"
!source "platform/cbm/irq.asm"
!source "platform/cbm/vic2_gfx.asm"
