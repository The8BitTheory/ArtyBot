; main.asm - Einstieg: bindet alle Module in fester Reihenfolge ein
!sal	; Causes the label saving routines to also dump out local labels
!sl "Test.map"	; Save all labels
!svl "Test.lbl"	; Save referenced labels in VICE format
!pdb "Test.pdb"	; Save PDB format data

!cpu 6510


!source "inc/defs.inc"
!source "inc/zp.inc"
!source "inc/macros.inc"

; startup.asm setzt "* = $0801" und enthaelt den BASIC-Stub, danach Code ab $080D
!source "src/startup.asm"
!source "src/irq.asm"
!source "src/util.asm"
!source "src/video.asm"
!source "src/sound.asm"
!source "src/input.asm"
!source "src/sprites.asm"
!source "src/editor.asm"
!source "src/gfx_data.asm"

; --- Daten
!source "src/text.asm"

prg_end
!if prg_end > CODE_LIMIT {
    !error "Programm ragt in die VIC-Bank 3 ($C000) - zu gross"
}
