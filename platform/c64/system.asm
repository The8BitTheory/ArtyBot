; system.asm (C64) - Systemfunktionen: Rueckkehr ins BASIC

!zone system_reset
system_reset
        sei
        lda #0
        sta SID_VOL             ; no music or effect left ringing
        lda #$37                ; BASIC + KERNAL + I/O visible again
        sta CPU_PORT
        jmp $FCE2               ; KERNAL reset entry (soft reset)
