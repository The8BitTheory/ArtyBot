; sound.asm - kleine SID-Signale fuer Schritte, Fehler und Lieferung

!zone sound_init
sound_init
        lda #0
        ldx #$18
.l      sta SID_BASE,x
        dex
        bpl .l
        sta sound_timer
        lda #$0F
        sta SID_VOL
        lda #$08
        sta SID_BASE+5
        lda #$A8
        sta SID_BASE+6
        rts

sound_tick                      ; wird 50x/s aus dem IRQ gerufen
        lda sound_timer
        beq .done
        dec sound_timer
        bne .done
        lda #$10
        sta SID_BASE+4
.done
        rts

sound_move
        ldx tmp3
        lda snd_freq_lo,x
        sta SID_BASE
        lda snd_freq_hi,x
        sta SID_BASE+1
        lda #$08
        sta SID_BASE+5
        lda #$A8
        sta SID_BASE+6
        lda #3
        sta sound_timer
        lda #$21
        sta SID_BASE+4
        rts

sound_error
        lda #$40
        sta SID_BASE
        lda #$03
        sta SID_BASE+1
        lda #$01
        sta SID_BASE+5
        lda #$42
        sta SID_BASE+6
        lda #10
        sta sound_timer
        lda #$11
        sta SID_BASE+4
        rts

sound_success
        lda #$80
        sta SID_BASE
        lda #$0B
        sta SID_BASE+1
        lda #$04
        sta SID_BASE+5
        lda #$C8
        sta SID_BASE+6
        lda #18
        sta sound_timer
        lda #$21
        sta SID_BASE+4
        rts

snd_freq_lo !byte $00,$00,$00,$00
snd_freq_hi !byte $0A,$0C,$0E,$10
