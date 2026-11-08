; system.asm (C128) - Systemfunktionen: Rueckkehr ins BASIC

!zone system_reset
system_reset
        sei
        lda #0
        sta SID_VOL             ; no music or effect left ringing
        lda #MMU_CFG_SYSTEM     ; System-ROMs + I/O sichtbar
        sta MMU_CR
        jmp ($FFFC)             ; Reset-Vektor im KERNAL-ROM (Neustart des C128)
