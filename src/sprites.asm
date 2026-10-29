; sprites.asm - Mouse pointer (sprite 0) and program insertion marker (sprite 1)

!zone spr_init
spr_init
        lda #SPRITE_BLOCK
        sta SPR_PTR0
        lda #SPRITE_BLOCK1
        sta SPR_PTR0+1
        lda #COL_WHITE
        sta VIC_SPR0COL
        lda #COL_YELLOW
        sta VIC_SPR0COL+1
        lda #0
        sta VIC_SPRXMSB
        sta VIC_SPR_MC
        sta VIC_SPR_EXPX
        sta VIC_SPR_EXPY
        sta VIC_SPR_PRI
        lda #$03
        sta VIC_SPR_EN
        jsr spr_update
        rts

!zone spr_update
spr_update
        ; Convert screen-relative X (0..319) to VIC coordinates.
        lda mouse_x_lo
        clc
        adc #24
        sta VIC_SPR0X
        lda mouse_x_hi
        adc #0
        and #1
        sta VIC_SPRXMSB
        lda mouse_y
        clc
        adc #50
        sta VIC_SPR0Y

        ; Fixed insertion point before the first program row. Sprite 1's
        ; arrow tip lands on the row boundary; its line reaches toward text.
        lda #208
        sta VIC_SPR1X
        lda insert_pos
        sec
        sbc scroll_offset
        asl
        asl
        asl
        clc
        adc #56
        sta VIC_SPR1Y

        lda #$03
        ldx selection_active
        beq .sprite_enable
        lda #$01                ; hide insertion marker while editing a row
.sprite_enable
        sta VIC_SPR_EN

        rts
