; title.asm - Title screen logic: menu (title_sel), keys, mouse, end screen flow.
; Keys: W/S or cursor up/down, Return or Space selects, 1-4 direct; mouse: point
; and click. Drawing: view (platform/*/view_*/title.asm): title_draw, title_refresh,
; title_split, title_pointer, title_anim, title_hit, title_mark, title_page,
; title_credits, title_leave, end_draw.

TITLE_ITEMS   = 4
KEY_1         = 56              ; keyboard matrix codes of 1..4
KEY_2         = 59
KEY_3         = 8
KEY_4         = 11

!zone title_mode
title_mode
        jsr music_start
        lda #0
        sta title_sel
        jsr title_draw
.loop   jsr wait_frame
        jsr title_refresh       ; menu redraw in the vertical blank (no flicker)
        jsr title_split
        jsr input_update
        jsr title_pointer
        jsr title_anim
        jsr title_mouse         ; carry set: click on an item
        bcs .go
        lda key_new
        cmp #$FF
        beq .loop
        cmp #KEY_W
        beq .up
        cmp #KEY_S
        beq .down
        cmp #KEY_CRSR_UD
        bne .not_crsr
        ldx key_shift
        bne .up
        beq .down
.not_crsr
        cmp #KEY_RETURN
        beq .go
        cmp #KEY_SPACE
        beq .go
        ldx key_repeat          ; number keys: no auto repeat
        bne .loop
        ldx #0
        cmp #KEY_1
        beq .num
        inx
        cmp #KEY_2
        beq .num
        inx
        cmp #KEY_3
        beq .num
        inx
        cmp #KEY_4
        bne .loop
.num    txa
        jsr title_select
        jmp .go
.up     lda title_sel
        sec
        sbc #1
        bcs .set
        lda #TITLE_ITEMS-1
        bne .set
.down   lda title_sel
        clc
        adc #1
        cmp #TITLE_ITEMS
        bcc .set
        lda #0
.set    jsr title_select
        lda #0
        sta tmp3
        jsr sound_move
        jmp .loop
.go     lda title_sel
        beq .new_game
        cmp #1
        beq .instructions
        cmp #2
        beq .credits
        jmp system_reset        ; item 4: quit (soft reset)
.instructions
        jsr title_instructions
        jsr title_draw
        jmp .loop
.credits
        jsr title_credits
        jsr title_draw
        jmp .loop
.new_game
        jsr sound_place
        jsr title_leave
        jsr editor_init
        jsr world_init
        jmp world_mode          ; world 1 (world_init selects world 0)

; F8 in the game screens: back to the title screen from anywhere. The caller
; may sit deep inside a mode, so the stack starts over.
!zone title_return
title_return
        jsr sound_stop
        ldx #$FF
        txs
        jmp title_mode

; A = item: select it. The view redraws the old and the new item (title_mark).
!zone title_select
title_select
        cmp title_sel
        beq .same
        ldx title_sel           ; old item loses hand and highlight
        sta title_sel
        jsr title_mark          ; X = old item
.same   rts

; Mouse: moving the pointer over an item selects it; a click on an item
; returns carry set (title_sel = that item). title_hit (view) finds the item.
!zone title_mouse
title_mouse
        jsr title_hit           ; A = item under the pointer, $FF = none
        cmp #$FF
        beq .none
        sta tmp0
        lda mouse_click
        bne .click
        lda mouse_x_lo          ; hover: only when the pointer moved
        cmp title_mx
        bne .moved
        lda mouse_y
        cmp title_my
        beq .none
.moved  lda tmp0
        jsr title_select
.none   lda mouse_x_lo
        sta title_mx
        lda mouse_y
        sta title_my
        clc
        rts
.click  lda tmp0
        jsr title_select
        sec
        rts

; Instructions: two full-screen pages (str_instr1, str_instr2), any key or
; click turns the page; the caller redraws the title afterwards.
!zone title_instructions
title_instructions
        lda #<str_instr1
        ldx #>str_instr1
        jsr title_page
        lda #<str_instr2
        ldx #>str_instr2
        jmp title_page

!zone end_mode
end_mode
        jsr ambient_stop
        lda wm_prevx            ; the robot waits in front of the gate
        sta wm_cx
        lda wm_prevy
        sta wm_cy
        jsr world_save_pos
        jsr end_draw
        jsr sound_celebrate
.wait   jsr wait_frame
        jsr title_split
        jsr input_update
        lda key_new
        cmp #$FF
        beq .wait
        ldx key_repeat
        bne .wait
        cmp #KEY_RETURN
        beq .title
        cmp #KEY_F7
        bne .wait
        lda key_shift           ; F8 (Shift+F7) does nothing here
        bne .wait
        jsr title_leave
        ldx #$FF                ; top level again (we came from inside world_mode)
        txs
        jmp world_mode
.title  ldx #$FF
        txs
        jmp title_mode

title_sel     !byte 0           ; selected menu item
title_mx      !byte 0           ; last mouse position (hover detection)
title_my      !byte 0
