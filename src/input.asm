; input.asm - Keyboard matrix plus proportional Commodore 1351 mouse (port 1)
; key_new is one debounced matrix code; key_shift reports either Shift key.
; The mouse pointer uses the 1351's 6-bit wrapping SID POT counters.

!zone input_init
input_init
        lda #$FF
        sta CIA1_DDRA
        lda #$00
        sta CIA1_DDRB
        lda #$40
        sta CIA1_PRA            ; select paddle pair 1 / port 1 mouse
        lda SID_POTX
        sta mouse_raw_x
        lda SID_POTY
        sta mouse_raw_y
        lda #160
        sta mouse_x_lo
        lda #0
        sta mouse_x_hi
        lda #100
        sta mouse_y
        sta mouse_btn
        sta mouse_current
        sta mouse_click
        sta key_repeat
        lda #$FF
        sta key_new
        sta key_prev
        lda #REPEAT_DELAY
        sta key_rep
        lda #0
        sta key_shift
        lda #$40
        sta CIA1_PRA
        rts

!zone input_update
input_update
        jsr mouse_update
        jsr key_scan
        sta key_now
        cmp key_prev
        beq .same
        sta key_prev
        sta key_new
        lda #0
        sta key_repeat
        lda #REPEAT_DELAY
        sta key_rep
        jmp .mouse
.same   lda #$FF
        sta key_new
        lda #0
        sta key_repeat
        lda key_now
        cmp #$FF
        beq .mouse
        dec key_rep
        bne .mouse
        lda key_now
        sta key_new
        lda #1
        sta key_repeat
        lda #REPEAT_RATE
        sta key_rep
.mouse  rts

; Scan for the first non-Shift key. Shift state is sampled separately so a
; Shift+letter chord is reported as the letter plus key_shift=1.
!zone key_scan
key_scan
        lda #$FF
        sta CIA1_PRA
        lda CIA1_PRB
        and #$10
        beq .button_down
        lda #0
        sta mouse_current
        jmp .scan_start
.button_down
        lda #1
        sta mouse_current
.scan_start
        lda #0
        sta key_shift
        ldx #0
        lda #%11111110
        sta tmp0
.col    lda tmp0
        sta CIA1_PRA
        lda CIA1_PRB
        ldy mouse_current
        beq .read_rows
        ora #$10                ; suppress port 1 fire while mouse is clicked
.read_rows
        cmp #$FF
        bne .rows
        sec
        rol tmp0
        inx
        cpx #8
        beq .scan_end
        jmp .col
.scan_end
        lda #$40
        sta CIA1_PRA
        lda #$FF
        rts
.rows   sta tmp2
        ldy #0
.row    lda tmp2
        lsr
        sta tmp2
        bcc .candidate
        iny
        cpy #8
        bne .row
        sec
        rol tmp0
        inx
        cpx #8
        bne .col
        lda #$40
        sta CIA1_PRA
        lda #$FF
        rts
.candidate
        ; Ignore left/right Shift as the primary key.
        ; Keep the scanner's established column * 8 + row code layout.
        ; Shift keys and palette_key_codes use this same coordinate order.
        tya
        sta tmp1
        txa
        asl
        asl
        asl
        clc
        adc tmp1
        cmp #15
        beq .next_row
        cmp #52
        beq .next_row
        sta tmp1
        ; Scan both physical Shift keys, independently of the key result.
        lda #$FD
        sta CIA1_PRA
        lda CIA1_PRB
        and #$80
        beq .shift_yes
        lda #$BF
        sta CIA1_PRA
        lda CIA1_PRB
        and #$10
        bne .key_found
.shift_yes
        lda #1
        sta key_shift
.key_found
        lda #$40
        sta CIA1_PRA
        lda tmp1
        rts
.next_row
        iny
        cpy #8
        bne .row
        sec
        rol tmp0
        inx
        cpx #8
        beq .no_key
        jmp .col
.no_key
        lda #$40
        sta CIA1_PRA
        lda #$FF
        rts

; Update click edge and pointer coordinates from the 1351's signed POT deltas.
!zone mouse_update
mouse_update
        lda #0
        sta mouse_click
        ; input_init / key_scan leave port 1 connected ($40). Sample the POTs
        ; before the button scan briefly changes the CIA matrix selection.
        lda SID_POTX
        sta tmp0
        lda SID_POTY
        sta tmp1

        ; Read fire with all matrix columns high, then reconnect port 1.
        ; This disconnect must happen after the POT sample, never before it.
        lda #$FF
        sta CIA1_PRA
        lda CIA1_PRB
        and #$10
        beq .button_down
        lda #0
        sta mouse_current
        jmp .button_read
.button_down
        lda #1
        sta mouse_current
.button_read
        lda mouse_current
        beq .button_released
        lda mouse_btn
        bne .button_done
        lda #1
        sta mouse_click
        bne .button_set
.button_released
        lda #0
.button_set
        sta mouse_btn
.button_done
        lda #$40
        sta CIA1_PRA

        ; POT's bit 0 is clock noise. The 1351 encodes signed movement in
        ; the remaining seven bits; decode before updating the screen position.
        lda tmp0
        sec
        sbc mouse_raw_x
        and #$7F
        sta tmp2
        lda tmp0
        sta mouse_raw_x
        lda tmp2
        beq .y_axis
        cmp #64
        bcs .x_negative
        lsr
        beq .y_axis
        clc
        adc mouse_x_lo
        sta mouse_x_lo
        lda mouse_x_hi
        adc #0
        sta mouse_x_hi
        jmp .clamp_x
.x_negative
        cmp #$7F
        beq .y_axis            ; only the noise bit changed
        lda tmp2
        ora #$80
        sec
        ror                     ; signed delta / 2, dropping noise bit
        eor #$FF
        clc
        adc #1                  ; absolute pixel delta
        sta tmp3
        lda mouse_x_lo
        sec
        sbc tmp3
        sta mouse_x_lo
        lda mouse_x_hi
        sbc #0
        sta mouse_x_hi
        bcs .clamp_x
        lda #0
        sta mouse_x_hi
        sta mouse_x_lo
.clamp_x
        lda mouse_x_hi
        beq .y_axis
        cmp #1
        bcc .y_axis
        bne .x_max
        lda mouse_x_lo
        cmp #64
        bcc .y_axis
.x_max  lda #1
        sta mouse_x_hi
        lda #63
        sta mouse_x_lo

.y_axis
        ; Y uses the same signed delta, with screen-down opposite to mouse-up.
        lda tmp1
        sec
        sbc mouse_raw_y
        and #$7F
        sta tmp2
        lda tmp1
        sta mouse_raw_y
        lda tmp2
        beq .finish
        cmp #64
        bcs .y_counter_negative
        ; Positive mouse delta moves the pointer up.
        lda tmp2
        lsr
        beq .finish
        sta tmp3
        lda mouse_y
        sec
        sbc tmp3
        bcs .store_y_up
        lda #0
.store_y_up
        sta mouse_y
        jmp .clamp_y
.y_counter_negative
        cmp #$7F
        beq .finish            ; only the noise bit changed
        ; Negative mouse delta moves the pointer down.
        lda tmp2
        ora #$80
        sec
        ror
        eor #$FF
        clc
        adc #1
        clc
        adc mouse_y
        bcc .store_y_down
        lda #199
        bne .store_y_down
.store_y_down
        cmp #200
        bcc .save_y
        lda #199
.save_y sta mouse_y
.clamp_y
        lda mouse_y
        cmp #200
        bcc .finish
        lda #199
        sta mouse_y
.finish rts

