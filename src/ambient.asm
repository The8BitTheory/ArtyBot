; ambient.asm - background ambience for the world maps. No melody: a soft
; wind/noise swell (voice 3 through the band-pass filter) that comes and goes,
; a slow, sparse pulse (voice 2) that fades in for a while and pauses again,
; and now and then a small sci-fi sound on voice 1 (sonar ping, computer
; chatter, rising/falling sweep, ring-modulated bell, distant beacon).
; Everything is generated at run time from a few tables and a small random
; generator, so it never repeats exactly. Runs in the raster IRQ after
; music_tick. Voice 1 belongs to the sound effects: while snd_dur/snd_off
; <> 0 the ambience leaves it alone and drops its own sound in progress.
; ambient_start: world map (may be called again while running, then nothing
; happens); ambient_stop: leaving the map (plan mode, title, end screen).
; Per world a parameter set (noise colour, filter, pulse notes, sound mix);
; worlds beyond AMB_WORLDS use the last set.

AMB_STEP    = 15                ; frames per pulse step (an 8th at 100 BPM)
AMB_STEPS   = 16                ; steps per pattern (4.8 s)
AMB_WORLDS  = 2                 ; parameter sets below
AMB_CUT_MAX = $50               ; highest filter cutoff of a wind swell

SID_FC_LO   = $D415
SID_FC_HI   = $D416
SID_RESFILT = $D417
AMB_V2      = SID_BASE+7
AMB_V3      = SID_BASE+14

!zone ambient_start
ambient_start
        lda amb_on
        beq .start
        rts
.start  php
        sei
        lda frame               ; seed the random generator (never 0)
        eor amb_seed
        bne .seed
        lda #$5A
.seed   sta amb_seed
        lda #0
        sta AMB_V3+4            ; wind: noise, silent until the first swell
        sta AMB_V3
        sta AMB_V2+4
        lda #$E0                ; attack 5 s: the gate is let go long before
        sta AMB_V3+5            ; the top, so the hold time sets the volume
        lda #$FB                ; release 2.4 s
        sta AMB_V3+6
        lda #0
        sta SID_FC_LO
        lda #$10
        sta SID_FC_HI
        lda #$74                ; resonance 7, filter voice 3 only
        sta SID_RESFILT
        lda #$2F                ; band pass, volume 15
        sta SID_VOL
        lda #0
        sta amb_wstate
        sta amb_skind
        sta amb_rgate
        sta amb_rstep
        sta amb_rplay           ; the pulse starts with one silent pattern
        sta amb_rbar
        lda #1
        sta amb_rleft
        sta amb_rframe
        lda #$70
        sta amb_ratt
        lda #40                 ; first swell after 0.8 s
        sta amb_wtime
        lda #150                ; first sound after 3 s
        sta amb_stime
        lda #1
        sta amb_on
        plp
        rts

!zone ambient_stop
ambient_stop
        lda amb_on
        beq .rts
        php
        sei
        lda #0
        sta amb_on
        sta amb_skind
        sta AMB_V2+4
        sta AMB_V3+4
        sta SID_RESFILT
        lda #$0F                ; no filter mode, volume 15
        sta SID_VOL
        lda snd_dur
        ora snd_off
        bne .sfx                ; voice 1 belongs to a running effect
        lda #0
        sta SID_BASE+4
        jsr snd_voice1_setup
.sfx    plp
.rts    rts

!zone ambient_tick              ; 50 times per second from the IRQ
ambient_tick
        lda amb_on
        bne .on
        rts
.on     ldx world_cur
        cpx #AMB_WORLDS
        bcc .w
        ldx #AMB_WORLDS-1
.w      stx amb_w
        jsr amb_rand            ; keeps the generator moving every frame
        jsr amb_wind
        jsr amb_pulse
        jmp amb_sfx

; 8-bit Galois LFSR (x^8+x^4+x^3+x^2+1), A = next value, never 0.
amb_rand
        lda amb_seed
        asl
        bcc .n
        eor #$1D
.n      sta amb_seed
        rts

; ---- wind: voice 3 noise, band-pass filter opens during a swell ---------------
; state 0 = quiet, 1 = swelling (gate on), 2 = dying away (release)
!zone amb_wind
amb_wind
        dec amb_wtime
        bne .run
        ldx amb_wstate          ; time is up: next state
        beq .swell
        dex
        beq .release
        lda #0                  ; release over: quiet for 1.2 .. 3.7 s
        sta amb_wstate
        jsr amb_rand
        and #$7F
        clc
        adc #60
        sta amb_wtime
        rts
.swell  jsr amb_rand
        and #7
        ldx amb_w
        clc
        adc amb_noise,x
        sta AMB_V3+1            ; noise colour varies a little per swell
        lda amb_cutbase,x
        sta amb_cut
        sta SID_FC_HI
        lda #$81
        sta AMB_V3+4
        jsr amb_rand
        and #$3F
        clc
        adc #60                 ; held 1.2 .. 2.5 s: peak 24 .. 49 percent
        sta amb_wtime
        lda #1
        sta amb_wstate
        rts
.release
        lda #$80
        sta AMB_V3+4
        lda #150
        sta amb_wtime
        lda #2
        sta amb_wstate
        rts
.run    lda amb_wstate
        beq .rts
        cmp #1
        bne .fall
        lda frame               ; swelling: the filter opens slowly
        and #1
        bne .rts
        lda amb_cut
        cmp #AMB_CUT_MAX
        bcs .rts
        inc amb_cut
        bne .wr
.fall   lda frame               ; dying away: it closes again, slower
        and #3
        bne .rts
        ldx amb_w
        lda amb_cut
        cmp amb_cutbase,x
        beq .rts
        bcc .rts
        dec amb_cut
.wr     lda amb_cut
        sta SID_FC_HI
.rts    rts

; ---- pulse: voice 2, soft low thumps and quiet noise ticks ------------------
; Plays 3-4 patterns (fading in and out), then pauses for 2-3 patterns.
!zone amb_pulse
amb_pulse
        lda amb_rgate           ; a hit keeps its gate for one frame only
        beq .t
        lda #0
        sta amb_rgate
        lda amb_rwave
        sta AMB_V2+4
.t      dec amb_rframe
        beq .step
        rts
.step
        lda #AMB_STEP
        sta amb_rframe
        ldy amb_rstep
        iny
        cpy #AMB_STEPS
        bcc .s
        jsr amb_bar
        ldy #0
.s      sty amb_rstep
        lda amb_rplay
        beq .rts
        lda amb_pat,y
        beq .rts
        cmp #3
        beq .tick
        sta amb_tmp             ; 1 = accent, 2 = soft thump
        lda amb_w               ; note: world set, changes every 2 patterns
        asl
        sta amb_tmp2
        lda amb_rcount
        lsr
        and #1
        ora amb_tmp2
        tax
        lda amb_root_lo,x
        sta AMB_V2
        lda amb_root_hi,x
        sta AMB_V2+1
        lda amb_ratt            ; slower attack = quieter (gate is 1 frame)
        ldx amb_tmp
        cpx #2
        bne .acc
        clc
        adc #$10
.acc    sta AMB_V2+5
        lda #$09                ; sustain 0, release 750 ms
        sta AMB_V2+6
        lda #$10                ; triangle
        bne .hit
.tick   jsr amb_rand            ; every 4th tick is left out
        and #3
        bne .tk
        rts
.tk     lda #0
        sta AMB_V2
        lda #$C0
        sta AMB_V2+1
        lda #$50                ; ~35 percent
        sta AMB_V2+5
        lda #$02                ; release 48 ms
        sta AMB_V2+6
        lda #$80                ; noise
.hit    sta amb_rwave
        ora #1
        sta AMB_V2+4
        lda #1
        sta amb_rgate
.rts    rts

; End of a pattern: count it, switch between playing and pausing, and pick
; the loudness of the next one (first pattern of a phase soft, last a bit).
!zone amb_bar
amb_bar
        inc amb_rcount
        dec amb_rleft
        bne .same
        lda amb_rplay
        eor #1
        sta amb_rplay
        jsr amb_rand
        and #1
        clc
        adc #2                  ; pause 2-3 patterns
        ldx amb_rplay
        beq .p
        adc #1                  ; play 3-4 patterns
.p      sta amb_rleft
        lda #0
        sta amb_rbar
        beq .att
.same   inc amb_rbar
.att    lda #$50                ; attack 56 ms: peak ~35 percent
        ldx amb_rbar
        bne .nf
        lda #$70                ; first pattern: 80 ms, ~25 percent
.nf     ldx amb_rleft
        cpx #1
        bne .set
        lda #$60                ; last pattern: 68 ms, ~30 percent
.set    sta amb_ratt
        rts

; ---- sci-fi sounds on voice 1 ------------------------------------------------
!zone amb_sfx
amb_sfx
        lda snd_dur
        ora snd_off
        beq .free
        lda amb_skind           ; an effect owns voice 1: drop our sound
        beq .rts
        lda #0
        sta amb_skind
        lda #100
        sta amb_stime
.rts    rts
.free   lda amb_skind
        bne .run
        dec amb_stime
        bne .rts
        jsr amb_rand            ; next one in 2.6 .. 5.1 s after this one
        ora #$80
        sta amb_stime
        jsr amb_rand
        and #7
        sta amb_tmp
        lda amb_w
        asl
        asl
        asl
        ora amb_tmp
        tax
        lda amb_sfx_tab,x
        beq .rts                ; 0 = stay quiet this time
        sta amb_skind
        lda #0
        sta amb_st
        sta SID_BASE+4
.run    ldx amb_skind
        lda amb_sfx_lo-1,x
        sta amb_vec
        lda amb_sfx_hi-1,x
        sta amb_vec+1
        jmp (amb_vec)

; A = attack/decay, X = sustain/release: gate on with waveform amb_swave.
amb_hit
        sta SID_BASE+5
        stx SID_BASE+6
        lda amb_swave
        sta SID_BASE+4
        ora #1
        sta SID_BASE+4
        rts

amb_gate_off
        lda amb_swave
        sta SID_BASE+4
        rts

amb_end
        lda #0
        sta amb_skind
        sta SID_BASE+4
        rts

; amb_sf (16 bit) to the voice 1 frequency
amb_wr_freq
        lda amb_sfl
        sta SID_BASE
        lda amb_sfh
        sta SID_BASE+1
        rts

; 1: sonar ping with two fading echoes
!zone amb_ping
amb_ping
        ldx amb_st
        inc amb_st
        txa
        bne .t
        jsr amb_rand
        and #3
        tay
        lda #0
        sta SID_BASE
        lda amb_ping_hi,y
        sta SID_BASE+1
        lda #$10
        sta amb_swave
        lda #$40                ; ~50 percent
        ldx #$0A                ; release 1.5 s
        jmp amb_hit
.t      cpx #24
        bne .t2
        lda #$70                ; echo, ~25 percent
        ldx #$0A
        jmp amb_hit
.t2     cpx #48
        bne .t3
        lda #$90                ; second echo, ~8 percent
        ldx #$0A
        jmp amb_hit
.t3     cpx #130
        beq .end
        cpx #1
        beq .off
        cpx #25
        beq .off
        cpx #49
        beq .off
        rts
.off    jmp amb_gate_off
.end    jmp amb_end

; 2: computer chatter, 4-11 short random blips of a pentatonic scale
!zone amb_chatter
amb_chatter
        lda amb_st
        bne .go
        jsr amb_rand
        and #7
        clc
        adc #4
        sta amb_scnt
        lda #0
        sta SID_BASE+2
        lda #$03                ; narrow pulse
        sta SID_BASE+3
        lda #$40
        sta amb_swave
.go     inc amb_st
        lda amb_st
        and #3
        cmp #1
        beq .note
        cmp #2
        beq .off
        rts
.note   lda amb_scnt
        beq .end
        dec amb_scnt
        jsr amb_rand
        and #7
        tay
        lda amb_chat_lo,y
        sta SID_BASE
        lda amb_chat_hi,y
        sta SID_BASE+1
        lda #$50                ; ~35 percent
        ldx #$03
        jmp amb_hit
.off    jmp amb_gate_off
.end    jmp amb_end

; 3: rising sweep ("vwoop"), 4: falling sweep (power down)
!zone amb_sweep
amb_sweep
        lda amb_st
        bne .go
        lda #0
        sta amb_sfl
        lda #$0A
        ldx amb_skind
        cpx #3
        beq .f
        lda #$40
.f      sta amb_sfh
        jsr amb_wr_freq
        lda #$10
        sta amb_swave
        lda #$B0                ; attack 800 ms, let go after 360 ms
        ldx #$09                ; release 750 ms
        jsr amb_hit
.go     inc amb_st
        lda amb_sfh             ; amb_t = f / 16
        sta amb_t1
        lda amb_sfl
        ldx #4
.sh     lsr amb_t1
        ror
        dex
        bne .sh
        sta amb_t2
        lda amb_skind
        cmp #3
        bne .down
        lda amb_sfh
        cmp #$C0
        bcs .chk                ; high enough
        clc
        lda amb_sfl
        adc amb_t2
        sta amb_sfl
        lda amb_sfh
        adc amb_t1
        sta amb_sfh
        jmp .wr
.down   sec
        lda amb_sfl
        sbc amb_t2
        sta amb_sfl
        lda amb_sfh
        sbc amb_t1
        sta amb_sfh
.wr     jsr amb_wr_freq
.chk    lda amb_st
        cmp #18
        beq .off
        cmp #60
        beq .end
        rts
.off    jmp amb_gate_off
.end    jmp amb_end

; 5: metallic bell (triangle ring-modulated by the wind oscillator)
!zone amb_bell
amb_bell
        ldx amb_st
        inc amb_st
        txa
        bne .t
        jsr amb_rand
        and #3
        tay
        lda #0
        sta SID_BASE
        lda amb_bell_hi,y
        sta SID_BASE+1
        lda #$14                ; triangle + ring modulation
        sta amb_swave
        lda #$50                ; ~35 percent
        ldx #$0B                ; release 2.4 s
        jmp amb_hit
.t      cpx #1
        bne .t2
        jmp amb_gate_off
.t2     cpx #140
        bne .rts
        jmp amb_end
.rts    rts

; 6: distant beacon, two soft pulse tones high-low
!zone amb_beacon
amb_beacon
        ldx amb_st
        inc amb_st
        txa
        bne .t
        lda #0
        sta SID_BASE+2
        lda #$08                ; pulse 50 percent
        sta SID_BASE+3
        lda #$40
        sta amb_swave
        jsr amb_rand
        and #1
        sta amb_scnt            ; pair 0 or 1
        asl
        tay
        lda amb_beac_lo,y
        sta SID_BASE
        lda amb_beac_hi,y
        sta SID_BASE+1
.hit    lda #$A0                ; attack 500 ms, gate 160 ms: ~30 percent
        ldx #$07                ; release 240 ms
        jmp amb_hit
.t      cpx #12
        bne .t2
        lda amb_scnt
        asl
        tay
        lda amb_beac_lo+1,y
        sta SID_BASE
        lda amb_beac_hi+1,y
        sta SID_BASE+1
        jmp .hit
.t2     cpx #8
        beq .off
        cpx #20
        beq .off
        cpx #60
        beq .end
        rts
.off    jmp amb_gate_off
.end    jmp amb_end

; ---- data -------------------------------------------------------------------
amb_sfx_lo  !byte <amb_ping, <amb_chatter, <amb_sweep, <amb_sweep, <amb_bell, <amb_beacon
amb_sfx_hi  !byte >amb_ping, >amb_chatter, >amb_sweep, >amb_sweep, >amb_bell, >amb_beacon

; per world: 8 choices (1 ping, 2 chatter, 3 rise, 4 fall, 5 bell, 6 beacon, 0 none)
amb_sfx_tab !byte 2, 6, 3, 1, 2, 6, 4, 0        ; Meadow: chatter and beacons
            !byte 1, 5, 4, 1, 5, 2, 3, 0        ; Winter: pings and bells
amb_noise   !byte $10, $28                      ; noise pitch (hi byte) per world
amb_cutbase !byte $0C, $18                      ; filter cutoff at rest per world
; pulse notes per world, two each (PAL): Meadow A2/F2, Winter E2/C2
amb_root_lo !byte <1873, <1487, <1403, <1114
amb_root_hi !byte >1873, >1487, >1403, >1114
; pulse pattern: 1 thump, 2 soft thump, 3 tick
amb_pat     !byte 1, 0, 0, 3,  0, 0, 2, 0,  0, 0, 0, 3,  0, 0, 0, 0
amb_ping_hi !byte $60, $70, $50, $68
amb_bell_hi !byte $24, $2E, $36, $1C
; C6 D6 E6 G6 A6 C7 D7 E7
amb_chat_lo !byte <17820, <20003, <22452, <26700, <29970, <35641, <40005, <44904
amb_chat_hi !byte >17820, >20003, >22452, >26700, >29970, >35641, >40005, >44904
; beacon pairs high-low: A5-D5, E5-A4
amb_beac_lo !byte <14985, <10001, <11226, <7493
amb_beac_hi !byte >14985, >10001, >11226, >7493

amb_on      !byte 0
amb_seed    !byte $A7
amb_w       !byte 0             ; parameter set of the current world
amb_tmp     !byte 0
amb_tmp2    !byte 0
amb_wstate  !byte 0
amb_wtime   !byte 0
amb_cut     !byte 0
amb_rframe  !byte 0
amb_rstep   !byte 0
amb_rplay   !byte 0
amb_rleft   !byte 0
amb_rbar    !byte 0
amb_rcount  !byte 0
amb_ratt    !byte 0
amb_rgate   !byte 0
amb_rwave   !byte 0
amb_skind   !byte 0
amb_stime   !byte 0
amb_st      !byte 0
amb_scnt    !byte 0
amb_swave   !byte 0
amb_sfl     !byte 0
amb_sfh     !byte 0
amb_t1      !byte 0
amb_t2      !byte 0
amb_vec     !word 0
!if (amb_vec & $FF) = $FF { !error "amb_vec crosses a page (JMP indirect bug)" }
