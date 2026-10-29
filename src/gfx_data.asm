; gfx_data.asm - Pointer and insertion-marker sprites for planning prototype.
; Sprite 0 is the mouse pointer; sprite 1 marks the insertion position.

gfx_sprites
; White arrow pointer: hotspot is pixel (0,0), body extends right and down.
        !byte $80,$00,$00
        !byte $C0,$00,$00
        !byte $A0,$00,$00
        !byte $90,$00,$00
        !byte $88,$00,$00
        !byte $84,$00,$00
        !byte $82,$00,$00
        !byte $81,$00,$00
        !byte $FF,$80,$00
        !byte $FF,$C0,$00
        !byte $FF,$E0,$00
        !byte $FF,$F0,$00
        !byte $FF,$F8,$00
        !byte $FF,$FC,$00
        !byte $FF,$FE,$00
        !byte $FF,$FF,$00
        !byte $FF,$0F,$00
        !byte $FE,$07,$00
        !byte $FC,$03,$00
        !byte $F8,$01,$00
        !byte $F0,$00,$00
        !byte $00

; Insert marker: small right-pointing triangle plus line extending right.
        !byte $00,$00,$00
        !byte $00,$00,$00
        !byte $00,$00,$00
        !byte $00,$00,$00
        !byte $00,$00,$00
        !byte $00,$00,$00
        !byte $00,$00,$00
        !byte $00,$00,$00
        !byte $80,$00,$00
        !byte $F0,$00,$00
        !byte $FF,$FF,$FF
        !byte $F0,$00,$00
        !byte $80,$00,$00
        !byte $00,$00,$00
        !byte $00,$00,$00
        !byte $00,$00,$00
        !byte $00,$00,$00
        !byte $00,$00,$00
        !byte $00,$00,$00
        !byte $00,$00,$00
        !byte $00,$00,$00
        !byte $00
gfx_sprites_end
!if gfx_sprites_end - gfx_sprites != SPRITE_BYTES {
    !error "SPRITE_BYTES passt nicht zu Pointer-Sprites"
}


; Seven monochrome 12x12 command icons centered inside 16x16 character cells,
; followed by 8x8 up/down scrollbar arrows in inverse characters $FC-$FD.
gfx_icons
; $E0-$E3 - FORWARD
        !byte $00,$00,$08,$14,$22,$08,$08,$08
; $E1
        !byte $00,$00,$10,$28,$44,$10,$10,$10
; $E2
        !byte $08,$08,$08,$08,$08,$08,$00,$00
; $E3
        !byte $10,$10,$10,$10,$10,$10,$00,$00
; $E4-$E7 - BACKWARD
        !byte $00,$00,$08,$08,$08,$08,$08,$08
; $E5
        !byte $00,$00,$10,$10,$10,$10,$10,$10
; $E6
        !byte $08,$08,$08,$22,$14,$08,$00,$00
; $E7
        !byte $10,$10,$10,$44,$28,$10,$00,$00
; $E8-$EB - TURN RIGHT
        !byte $00,$00,$00,$00,$00,$00,$00,$0F
; $E9
        !byte $00,$00,$00,$00,$00,$10,$08,$FC
; $EA
        !byte $08,$08,$08,$08,$08,$08,$00,$00
; $EB
        !byte $08,$10,$00,$00,$00,$00,$00,$00
; $EC-$EF - TURN LEFT
        !byte $00,$00,$00,$00,$00,$08,$10,$3F
; $ED
        !byte $00,$00,$00,$00,$00,$00,$00,$F0
; $EE
        !byte $10,$08,$00,$00,$00,$00,$00,$00
; $EF
        !byte $10,$10,$10,$10,$10,$10,$00,$00
; $F0-$F3 - PICK UP
        !byte $00,$00,$00,$01,$02,$04,$01,$01
; $F1
        !byte $00,$00,$00,$80,$40,$20,$80,$80
; $F2
        !byte $01,$0F,$10,$10,$10,$0F,$00,$00
; $F3
        !byte $80,$F0,$88,$88,$88,$F0,$00,$00
; $F4-$F7 - DROP OFF
        !byte $00,$00,$00,$01,$01,$01,$02,$04
; $F5
        !byte $00,$00,$00,$80,$80,$80,$40,$20
; $F6
        !byte $01,$0F,$10,$10,$10,$0F,$00,$00
; $F7
        !byte $80,$F0,$88,$88,$88,$F0,$00,$00
; $F8-$FB - TURN 180 (a U-turn path ending in a downward arrow)
        !byte $00,$00,$0F,$1F,$20,$20,$20,$20
; $F9
        !byte $00,$00,$F0,$F8,$04,$04,$04,$04
; $FA
        !byte $20,$20,$20,$20,$20,$00,$00,$00
; $FB
        !byte $04,$04,$04,$04,$1F,$0E,$04,$00
; $FC - scrollbar up arrow
        !byte $18,$3C,$7E,$18,$18,$18,$18,$18
; $FD - scrollbar down arrow
        !byte $18,$18,$18,$18,$18,$7E,$3C,$18
gfx_icons_end
!if gfx_icons_end - gfx_icons != ICON_CHAR_BYTES {
    !error "ICON_CHAR_BYTES does not match icon charset data"
}
