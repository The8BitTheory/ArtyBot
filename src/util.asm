; util.asm - Hilfsroutinen

; memcpy: ptr0 = Quelle, ptr1 = Ziel, cnt = Laenge (16 Bit). Aufsteigend.
!zone memcpy
memcpy
        ldy #0
        lda cnt+1
        beq .tail
.pg     lda (ptr0),y
        sta (ptr1),y
        iny
        bne .pg
        inc ptr0+1
        inc ptr1+1
        dec cnt+1
        bne .pg
.tail   lda cnt
        beq .done
.by     lda (ptr0),y
        sta (ptr1),y
        iny
        cpy cnt
        bne .by
.done   rts
