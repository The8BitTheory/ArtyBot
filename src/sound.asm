; sound.asm - small SID note sequencer (voice 1) for steps, errors, placing a
; package on a goal field and the celebration fanfare.
; A sequence is a list of 4-byte notes: frequency (16 bit), duration in 50 Hz
; frames, waveform (0 = rest). A note with duration 0 ends the sequence.
; sound_tick runs in the raster IRQ; it only uses its own zero-page bytes.

snd_dur     = $F8               ; frames left of the current note (0 = silent)
snd_ptr     = $F9               ; next note of the running sequence ($F9/$FA)
snd_off     = $FB               ; frames until the voice is switched off completely

SND_TAIL    = 12                ; > release time (204 ms = 10.2 frames)

SND_TRI     = $10
SND_SAW     = $20
SND_PULSE   = $40

!macro snd_note .freq, .dur, .wave {
        !byte <(.freq), >(.freq), .dur, .wave
}
!macro snd_rest .dur {
        !byte 0, 0, .dur, 0
}
!macro snd_end {
        !byte 0, 0, 0, 0
}

!zone sound_init
sound_init
        lda #0
        ldx #$18
.l      sta SID_BASE,x
        dex
        bpl .l
        sta snd_dur
        sta snd_off
        lda #$0F
        sta SID_VOL
        ; fall through

; Voice 1 settings for the effects (the title music changes them).
snd_voice1_setup
        lda #$00                ; pulse width 50 percent
        sta SID_BASE+2
        lda #$08
        sta SID_BASE+3
        lda #$06                ; attack 0, decay 6
        sta SID_BASE+5
        lda #$A6                ; sustain 10, release 6
        sta SID_BASE+6
        rts

; A/X = sequence address (lo/hi). It starts with the next IRQ tick.
!zone snd_play
snd_play
        php
        sei                     ; the music player checks snd_dur/snd_off
        sta snd_ptr
        stx snd_ptr+1
        jsr snd_voice1_setup    ; voice 1 may still have music settings
        lda #0
        sta snd_off
        lda #1
        sta snd_dur
        plp
        rts

; Cut off whatever is playing: the voice is silent immediately (waveform off,
; gate off, frequency 0), nothing is left in the release phase.
!zone sound_stop
sound_stop
        lda #0
        sta snd_dur             ; first, so the IRQ cannot start another note
        sta snd_off
        sta SID_BASE+4
        sta SID_BASE
        sta SID_BASE+1
        rts

!zone sound_tick                ; 50 times per second from the IRQ
sound_tick
        lda snd_dur
        bne .playing
        lda snd_off             ; sequence over: wait for the release, then
        beq .done               ; switch the voice off completely
        dec snd_off
        bne .done
        lda #0
        sta SID_BASE+4
        sta SID_BASE
        sta SID_BASE+1
.done   rts
.playing
        dec snd_dur
        bne .done
        ldy #2                  ; the note is over: start the next one
        lda (snd_ptr),y
        beq .stop               ; duration 0 = end of sequence
        sta snd_dur
        ldy #3
        lda (snd_ptr),y
        tax                     ; waveform, 0 = rest
        ldy #0
        lda (snd_ptr),y
        sta SID_BASE
        iny
        lda (snd_ptr),y
        sta SID_BASE+1
        txa
        beq .rest
        sta SID_BASE+4          ; gate off first so every note retriggers
        ora #$01
        sta SID_BASE+4
        jmp .advance
.rest   lda #SND_PULSE          ; gate off, release phase
        sta SID_BASE+4
.advance
        clc
        lda snd_ptr
        adc #4
        sta snd_ptr
        bcc .done
        inc snd_ptr+1
        rts
.stop   lda #SND_PULSE          ; gate off, release phase ...
        sta SID_BASE+4
        lda #SND_TAIL           ; ... then silence the voice for good
        sta snd_off
        rts

; tmp3 = 0..3 selects the pitch of the short step blip.
!zone sound_move
sound_move
        ldy tmp3
        lda snd_move_hi,y
        tax
        lda snd_move_lo,y
        jmp snd_play

sound_error
        lda #<seq_error
        ldx #>seq_error
        jmp snd_play

; Package put on a goal field: bright two-part "ding-ding" (C7, then G7).
sound_place
        lda #<seq_place
        ldx #>seq_place
        jmp snd_play

; Jump: a rising "boing" over the 16 frames in the air, dropping at the landing.
sound_jump
        lda #<seq_jump
        ldx #>seq_jump
        jmp snd_play

; Throw: a falling "whoosh" while the package flies.
sound_throw
        lda #<seq_throw
        ldx #>seq_throw
        jmp snd_play

; All packages delivered: fanfare of exactly 100 frames (2 seconds).
sound_celebrate
        lda #<seq_celebrate
        ldx #>seq_celebrate
        jmp snd_play

snd_move_lo !byte <seq_move0, <seq_move1, <seq_move2, <seq_move3
snd_move_hi !byte >seq_move0, >seq_move1, >seq_move2, >seq_move3

seq_move0 +snd_note $0A00, 3, SND_SAW
          +snd_end
seq_move1 +snd_note $0C00, 3, SND_SAW
          +snd_end
seq_move2 +snd_note $0E00, 3, SND_SAW
          +snd_end
seq_move3 +snd_note $1000, 3, SND_SAW
          +snd_end

seq_jump  +snd_note $0C00, 2, SND_TRI
          +snd_note $1000, 2, SND_TRI
          +snd_note $1500, 2, SND_TRI
          +snd_note $1C00, 2, SND_TRI
          +snd_note $2400, 2, SND_TRI
          +snd_note $2E00, 2, SND_TRI
          +snd_note $2400, 2, SND_TRI
          +snd_note $1800, 2, SND_TRI
          +snd_end

seq_throw +snd_note $3800, 2, SND_SAW
          +snd_note $3000, 2, SND_SAW
          +snd_note $2800, 2, SND_SAW
          +snd_note $2000, 2, SND_SAW
          +snd_note $1800, 2, SND_SAW
          +snd_note $1200, 3, SND_SAW
          +snd_end

seq_error +snd_note $0340, 10, SND_TRI
          +snd_end

seq_place +snd_note 35640, 5, SND_PULSE
          +snd_note 53400, 11, SND_PULSE
          +snd_end

seq_celebrate
        +snd_note 17820, 5, SND_PULSE   ; C6
        +snd_note 22452, 5, SND_PULSE   ; E6
        +snd_note 26700, 5, SND_PULSE   ; G6
        +snd_note 35640, 12, SND_PULSE   ; C7
        +snd_rest 3
        +snd_note 26700, 5, SND_PULSE   ; G6
        +snd_note 35640, 5, SND_PULSE   ; C7
        +snd_note 44904, 5, SND_PULSE   ; E7
        +snd_note 53400, 14, SND_PULSE   ; G7
        +snd_rest 3
        +snd_note 44904, 4, SND_PULSE   ; E7
        +snd_note 53400, 4, SND_PULSE   ; G7
        +snd_note 44904, 4, SND_PULSE   ; E7
        +snd_note 53400, 4, SND_PULSE   ; G7
        +snd_note 35640, 5, SND_PULSE   ; C7
        +snd_note 44904, 5, SND_PULSE   ; E7
        +snd_note 53400, 5, SND_PULSE   ; G7
        +snd_note 53400, 7, SND_PULSE   ; G7
        +snd_end
