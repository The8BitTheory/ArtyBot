; macros.inc

!macro set16 .addr, .val {
    lda #<(.val)
    sta .addr
    lda #>(.val)
    sta .addr+1
}

; Kopiert .len Bytes von .src nach .dst (nutzt ptr0, ptr1, cnt, A, Y)
!macro copy .src, .dst, .len {
    +set16 ptr0, .src
    +set16 ptr1, .dst
    +set16 cnt,  .len
    jsr memcpy
}
