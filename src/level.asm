; level.asm - Level (ASCII-Art) in die Arbeitskarte map_work (Zeilenabstand 16) entpacken

!zone level_load
level_load
        lda #<level_1
        sta ptr0
        lda #>level_1
        sta ptr0+1
        ldx #0                  ; gesamte Karte mit Wand fuellen (Rand/Reste)
        lda #T_WALL
.fill   sta map_work,x
        inx
        bne .fill
        ldy #0                  ; Quellindex
        sty tmp2                ; Zielindex
        sty tmp0                ; Zeile
.row    lda #0
        sta tmp1                ; Spalte
.col    lda (ptr0),y
        jsr tile_from_char
        cmp #T_ROBOT
        bne .store
        lda tmp1
        sta robot_tx
        lda tmp0
        sta robot_ty
        lda #T_FLOOR
.store  ldx tmp2
        sta map_work,x
        inc tmp2
        iny
        inc tmp1
        lda tmp1
        cmp #MAP_W
        bne .col
        lda tmp2                ; Zielindex auf naechste 16er-Zeile
        clc
        adc #16 - MAP_W
        sta tmp2
        inc tmp0
        lda tmp0
        cmp #MAP_H
        bne .row
        rts

; ASCII-Zeichen (A) -> Tile-ID (A); unbekannt = Boden. Erhaelt Y.
!zone tile_from_char
tile_from_char
        ldx #4
.f      cmp lvl_chars,x
        beq .hit
        dex
        bpl .f
        lda #T_FLOOR
        rts
.hit    txa
        rts
