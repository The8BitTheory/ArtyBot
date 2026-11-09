; gfx_vdc.asm - VDC-Grafik (Programmteil). GENERIERT von tools/gen_vdc_gfx.py - nicht von Hand aendern.
; Was nur im VRAM gebraucht wird (Zellen, Figurentinte, Icons, Mini-Zellen), steht in
; res_vdc_gfx.asm (Ressource-Datei artybot.gfx, RAM-Bank 1). Hier bleibt, was die CPU liest.
; Zellen-Reihenfolge gen_gfx_run.CELL_ORDER: grass, tree, chest, goal, flowers, water, path, gate_l, gate_r, arch, ice, broken, key, lock, lock_full, door, dann Kiste in Gold.
VDC_CELL_BYTES = 96
VDC_SPR_W = 5
VDC_SPR_COUNT = 18

vdc_goal_attr_meadow    ; Attribute der Zielzelle (run_goal_anim)
        !byte $44,$40,$40,$44
        !byte $40,$07,$70,$40
        !byte $07,$07,$70,$70
        !byte $70,$70,$07,$07
        !byte $70,$70,$07,$07
        !byte $07,$07,$70,$70
        !byte $40,$70,$07,$40
        !byte $44,$40,$40,$44
vdc_goal_attr_winter    ; Attribute der Zielzelle (run_goal_anim)
        !byte $FF,$F0,$F0,$FF
        !byte $F0,$07,$70,$F0
        !byte $07,$07,$70,$70
        !byte $70,$70,$07,$07
        !byte $70,$70,$07,$07
        !byte $07,$07,$70,$70
        !byte $F0,$70,$07,$F0
        !byte $FF,$F0,$F0,$FF
vdc_grass_attr !byte $44,$FF   ; erstes Attribut der Wiese je Theme (Grundfarbe)
; Figuren: je Bild und Verschiebung Block-Codes (H/2 Zeilen x 5): $FF leer; 0 Figurfarbe auf der
; Grundfarbe; $80 schwarz auf der Grundfarbe; sonst fertiges Attribut. Laeufe: 9 Bytes k0 | Laenge<<4.
; Tinte: Ressource (vdc_ink), Adresse in der VRAM-Ablage = ST_SPR + Versatz (vdc_ink_lo/hi).
vdc_spr_0_s0    ; robot right
        !byte $FF,$80,$80,$FF,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$80,$80,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$0E,$80,$80,$FF
        !byte $FF,$80,$80,$FF,$FF
vdc_spr_0_s0_span !byte $21,$40,$40,$40,$40,$40,$40,$40,$21
vdc_spr_0_s4    ; robot right
        !byte $FF,$FF,$80,$FF,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$80,$80,$80,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$80,$0E,$80,$FF
        !byte $FF,$80,$80,$FF,$FF
vdc_spr_0_s4_span !byte $12,$31,$31,$31,$31,$31,$31,$31,$21
vdc_spr_1_s0    ; robot left
        !byte $FF,$80,$80,$FF,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$80,$80,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$80,$0E,$80,$FF
        !byte $FF,$80,$80,$FF,$FF
vdc_spr_1_s0_span !byte $21,$40,$40,$40,$40,$40,$40,$40,$21
vdc_spr_1_s4    ; robot left
        !byte $FF,$FF,$80,$FF,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$80,$80,$80,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$80,$0E,$80,$FF
        !byte $FF,$FF,$80,$80,$FF
vdc_spr_1_s4_span !byte $12,$31,$31,$31,$31,$31,$31,$31,$22
vdc_spr_2_s0    ; robot up
        !byte $FF,$80,$80,$FF,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$80,$80,$80,$FF
        !byte $0E,$0E,$0E,$0E,$FF
        !byte $0E,$0E,$0E,$0E,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $FF,$80,$80,$FF,$FF
vdc_spr_2_s0_span !byte $21,$40,$40,$40,$40,$40,$40,$40,$21
vdc_spr_2_s4    ; robot up
        !byte $FF,$FF,$80,$FF,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$80,$80,$80,$FF
        !byte $0E,$0E,$0E,$0E,$0E
        !byte $0E,$0E,$0E,$0E,$0E
        !byte $FF,$0E,$80,$0E,$FF
        !byte $FF,$80,$80,$80,$FF
vdc_spr_2_s4_span !byte $12,$31,$31,$31,$31,$50,$50,$31,$31
vdc_spr_3_s0    ; robot down
        !byte $FF,$80,$80,$FF,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$80,$80,$80,$FF
        !byte $0E,$0E,$0E,$0E,$FF
        !byte $0E,$0E,$0E,$0E,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $FF,$80,$80,$FF,$FF
vdc_spr_3_s0_span !byte $21,$40,$40,$40,$40,$40,$40,$40,$21
vdc_spr_3_s4    ; robot down
        !byte $FF,$FF,$80,$FF,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$80,$80,$80,$FF
        !byte $0E,$0E,$0E,$0E,$0E
        !byte $0E,$0E,$0E,$0E,$0E
        !byte $FF,$0E,$80,$0E,$FF
        !byte $FF,$80,$80,$80,$FF
vdc_spr_3_s4_span !byte $12,$31,$31,$31,$31,$50,$50,$31,$31
vdc_spr_4_s0    ; robot right, carrying
        !byte $FF,$80,$80,$FF,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$80,$80,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$0E,$80,$80,$FF
        !byte $FF,$80,$80,$FF,$FF
vdc_spr_4_s0_span !byte $21,$40,$40,$40,$40,$40,$40,$40,$21
vdc_spr_4_s4    ; robot right, carrying
        !byte $FF,$FF,$80,$FF,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$80,$80,$80,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$80,$0E,$80,$FF
        !byte $FF,$80,$80,$FF,$FF
vdc_spr_4_s4_span !byte $12,$31,$31,$31,$31,$31,$31,$31,$21
vdc_spr_5_s0    ; robot left, carrying
        !byte $FF,$80,$80,$FF,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$80,$80,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$80,$0E,$80,$FF
        !byte $FF,$80,$80,$FF,$FF
vdc_spr_5_s0_span !byte $21,$40,$40,$40,$40,$40,$40,$40,$21
vdc_spr_5_s4    ; robot left, carrying
        !byte $FF,$FF,$80,$FF,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$80,$80,$80,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$80,$0E,$80,$FF
        !byte $FF,$FF,$80,$80,$FF
vdc_spr_5_s4_span !byte $12,$31,$31,$31,$31,$31,$31,$31,$22
vdc_spr_6_s0    ; robot up, carrying
        !byte $FF,$80,$80,$FF,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$80,$80,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $FF,$80,$80,$FF,$FF
vdc_spr_6_s0_span !byte $21,$40,$40,$40,$40,$40,$40,$40,$21
vdc_spr_6_s4    ; robot up, carrying
        !byte $FF,$FF,$80,$FF,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$80,$80,$80,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$0E,$80,$0E,$FF
        !byte $FF,$80,$80,$80,$FF
vdc_spr_6_s4_span !byte $12,$31,$31,$31,$31,$31,$31,$31,$31
vdc_spr_7_s0    ; robot down, carrying
        !byte $FF,$80,$80,$FF,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$80,$80,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $FF,$80,$80,$FF,$FF
vdc_spr_7_s0_span !byte $21,$40,$40,$40,$40,$40,$40,$40,$21
vdc_spr_7_s4    ; robot down, carrying
        !byte $FF,$FF,$80,$FF,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$80,$80,$80,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$0E,$80,$0E,$FF
        !byte $FF,$80,$80,$80,$FF
vdc_spr_7_s4_span !byte $12,$31,$31,$31,$31,$31,$31,$31,$31
vdc_spr_8_s0    ; robot right, step
        !byte $FF,$80,$80,$FF,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$80,$80,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$80,$80,$FF,$FF
vdc_spr_8_s0_span !byte $21,$40,$40,$40,$40,$40,$40,$40,$30
vdc_spr_8_s4    ; robot right, step
        !byte $FF,$FF,$80,$FF,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$80,$80,$80,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$80,$80,$80,$FF
vdc_spr_8_s4_span !byte $12,$31,$31,$31,$31,$31,$31,$31,$31
vdc_spr_9_s0    ; robot left, step
        !byte $FF,$80,$80,$FF,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$80,$80,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $FF,$80,$80,$80,$FF
vdc_spr_9_s0_span !byte $21,$40,$40,$40,$40,$40,$40,$40,$31
vdc_spr_9_s4    ; robot left, step
        !byte $FF,$FF,$80,$FF,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$80,$80,$80,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$80,$80,$80,$FF
vdc_spr_9_s4_span !byte $12,$31,$31,$31,$31,$31,$31,$31,$31
vdc_spr_10_s0    ; robot up, step
        !byte $FF,$80,$80,$FF,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$80,$80,$80,$FF
        !byte $0E,$0E,$0E,$0E,$FF
        !byte $0E,$0E,$0E,$0E,$FF
        !byte $80,$0E,$80,$80,$FF
        !byte $FF,$80,$0E,$FF,$FF
vdc_spr_10_s0_span !byte $21,$40,$40,$40,$40,$40,$40,$40,$21
vdc_spr_10_s4    ; robot up, step
        !byte $FF,$FF,$80,$FF,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$80,$80,$80,$FF
        !byte $0E,$0E,$0E,$0E,$0E
        !byte $0E,$0E,$0E,$0E,$0E
        !byte $FF,$0E,$80,$80,$FF
        !byte $FF,$80,$80,$0E,$FF
vdc_spr_10_s4_span !byte $12,$31,$31,$31,$31,$50,$50,$31,$31
vdc_spr_11_s0    ; robot down, step
        !byte $FF,$80,$80,$FF,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$80,$80,$80,$FF
        !byte $0E,$0E,$0E,$0E,$FF
        !byte $0E,$0E,$0E,$0E,$FF
        !byte $80,$0E,$80,$80,$FF
        !byte $FF,$80,$0E,$FF,$FF
vdc_spr_11_s0_span !byte $21,$40,$40,$40,$40,$40,$40,$40,$21
vdc_spr_11_s4    ; robot down, step
        !byte $FF,$FF,$80,$FF,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$80,$80,$80,$FF
        !byte $0E,$0E,$0E,$0E,$0E
        !byte $0E,$0E,$0E,$0E,$0E
        !byte $FF,$0E,$80,$80,$FF
        !byte $FF,$80,$80,$0E,$FF
vdc_spr_11_s4_span !byte $12,$31,$31,$31,$31,$50,$50,$31,$31
vdc_spr_12_s0    ; robot right, carrying, step
        !byte $FF,$80,$80,$FF,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$80,$80,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$80,$80,$FF,$FF
vdc_spr_12_s0_span !byte $21,$40,$40,$40,$40,$40,$40,$40,$30
vdc_spr_12_s4    ; robot right, carrying, step
        !byte $FF,$FF,$80,$FF,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$80,$80,$80,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$80,$80,$80,$FF
vdc_spr_12_s4_span !byte $12,$31,$31,$31,$31,$31,$31,$31,$31
vdc_spr_13_s0    ; robot left, carrying, step
        !byte $FF,$80,$80,$FF,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$80,$80,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $FF,$80,$80,$80,$FF
vdc_spr_13_s0_span !byte $21,$40,$40,$40,$40,$40,$40,$40,$31
vdc_spr_13_s4    ; robot left, carrying, step
        !byte $FF,$FF,$80,$FF,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$80,$80,$80,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$80,$80,$80,$FF
vdc_spr_13_s4_span !byte $12,$31,$31,$31,$31,$31,$31,$31,$31
vdc_spr_14_s0    ; robot up, carrying, step
        !byte $FF,$80,$80,$FF,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$80,$80,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$0E,$80,$80,$FF
        !byte $FF,$80,$0E,$FF,$FF
vdc_spr_14_s0_span !byte $21,$40,$40,$40,$40,$40,$40,$40,$21
vdc_spr_14_s4    ; robot up, carrying, step
        !byte $FF,$FF,$80,$FF,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$80,$80,$80,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$0E,$80,$80,$FF
        !byte $FF,$80,$80,$0E,$FF
vdc_spr_14_s4_span !byte $12,$31,$31,$31,$31,$31,$31,$31,$31
vdc_spr_15_s0    ; robot down, carrying, step
        !byte $FF,$80,$80,$FF,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$80,$80,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$0E,$0E,$80,$FF
        !byte $80,$0E,$80,$80,$FF
        !byte $FF,$80,$0E,$FF,$FF
vdc_spr_15_s0_span !byte $21,$40,$40,$40,$40,$40,$40,$40,$21
vdc_spr_15_s4    ; robot down, carrying, step
        !byte $FF,$FF,$80,$FF,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$80,$80,$80,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$0E,$0E,$0E,$FF
        !byte $FF,$0E,$80,$80,$FF
        !byte $FF,$80,$80,$0E,$FF
vdc_spr_15_s4_span !byte $12,$31,$31,$31,$31,$31,$31,$31,$31
vdc_spr_16_s0    ; package (chest) carried above the head
        !byte $80,$0C,$0C,$80,$FF
        !byte $80,$0C,$0C,$80,$FF
        !byte $80,$0C,$0C,$80,$FF
vdc_spr_16_s0_span !byte $40,$40,$40,$00,$00,$00,$00,$00,$00
vdc_spr_16_s4    ; package (chest) carried above the head
        !byte $FF,$0C,$0C,$0C,$FF
        !byte $FF,$0C,$0C,$0C,$FF
        !byte $FF,$0C,$0C,$0C,$FF
vdc_spr_16_s4_span !byte $31,$31,$31,$00,$00,$00,$00,$00,$00
vdc_spr_17_s0    ; key carried above the head
        !byte $0D,$0D,$FF,$FF,$FF
        !byte $0D,$0D,$0D,$0D,$FF
        !byte $0D,$0D,$0D,$0D,$FF
vdc_spr_17_s0_span !byte $20,$40,$40,$00,$00,$00,$00,$00,$00
vdc_spr_17_s4    ; key carried above the head
        !byte $80,$0D,$80,$FF,$FF
        !byte $80,$0D,$0D,$0D,$FF
        !byte $80,$0D,$0D,$0D,$FF
vdc_spr_17_s4_span !byte $30,$40,$40,$00,$00,$00,$00,$00,$00
VDC_INK_N = 1940          ; Bytes Tinte in der Ressource
vdc_spr_lo
        !byte <vdc_spr_0_s0, <vdc_spr_0_s4, <vdc_spr_1_s0, <vdc_spr_1_s4, <vdc_spr_2_s0, <vdc_spr_2_s4, <vdc_spr_3_s0, <vdc_spr_3_s4, <vdc_spr_4_s0, <vdc_spr_4_s4, <vdc_spr_5_s0, <vdc_spr_5_s4, <vdc_spr_6_s0, <vdc_spr_6_s4, <vdc_spr_7_s0, <vdc_spr_7_s4, <vdc_spr_8_s0, <vdc_spr_8_s4, <vdc_spr_9_s0, <vdc_spr_9_s4, <vdc_spr_10_s0, <vdc_spr_10_s4, <vdc_spr_11_s0, <vdc_spr_11_s4, <vdc_spr_12_s0, <vdc_spr_12_s4, <vdc_spr_13_s0, <vdc_spr_13_s4, <vdc_spr_14_s0, <vdc_spr_14_s4, <vdc_spr_15_s0, <vdc_spr_15_s4, <vdc_spr_16_s0, <vdc_spr_16_s4, <vdc_spr_17_s0, <vdc_spr_17_s4
vdc_spr_hi
        !byte >vdc_spr_0_s0, >vdc_spr_0_s4, >vdc_spr_1_s0, >vdc_spr_1_s4, >vdc_spr_2_s0, >vdc_spr_2_s4, >vdc_spr_3_s0, >vdc_spr_3_s4, >vdc_spr_4_s0, >vdc_spr_4_s4, >vdc_spr_5_s0, >vdc_spr_5_s4, >vdc_spr_6_s0, >vdc_spr_6_s4, >vdc_spr_7_s0, >vdc_spr_7_s4, >vdc_spr_8_s0, >vdc_spr_8_s4, >vdc_spr_9_s0, >vdc_spr_9_s4, >vdc_spr_10_s0, >vdc_spr_10_s4, >vdc_spr_11_s0, >vdc_spr_11_s4, >vdc_spr_12_s0, >vdc_spr_12_s4, >vdc_spr_13_s0, >vdc_spr_13_s4, >vdc_spr_14_s0, >vdc_spr_14_s4, >vdc_spr_15_s0, >vdc_spr_15_s4, >vdc_spr_16_s0, >vdc_spr_16_s4, >vdc_spr_17_s0, >vdc_spr_17_s4
vdc_span_lo
        !byte <vdc_spr_0_s0_span, <vdc_spr_0_s4_span, <vdc_spr_1_s0_span, <vdc_spr_1_s4_span, <vdc_spr_2_s0_span, <vdc_spr_2_s4_span, <vdc_spr_3_s0_span, <vdc_spr_3_s4_span, <vdc_spr_4_s0_span, <vdc_spr_4_s4_span, <vdc_spr_5_s0_span, <vdc_spr_5_s4_span, <vdc_spr_6_s0_span, <vdc_spr_6_s4_span, <vdc_spr_7_s0_span, <vdc_spr_7_s4_span, <vdc_spr_8_s0_span, <vdc_spr_8_s4_span, <vdc_spr_9_s0_span, <vdc_spr_9_s4_span, <vdc_spr_10_s0_span, <vdc_spr_10_s4_span, <vdc_spr_11_s0_span, <vdc_spr_11_s4_span, <vdc_spr_12_s0_span, <vdc_spr_12_s4_span, <vdc_spr_13_s0_span, <vdc_spr_13_s4_span, <vdc_spr_14_s0_span, <vdc_spr_14_s4_span, <vdc_spr_15_s0_span, <vdc_spr_15_s4_span, <vdc_spr_16_s0_span, <vdc_spr_16_s4_span, <vdc_spr_17_s0_span, <vdc_spr_17_s4_span
vdc_span_hi
        !byte >vdc_spr_0_s0_span, >vdc_spr_0_s4_span, >vdc_spr_1_s0_span, >vdc_spr_1_s4_span, >vdc_spr_2_s0_span, >vdc_spr_2_s4_span, >vdc_spr_3_s0_span, >vdc_spr_3_s4_span, >vdc_spr_4_s0_span, >vdc_spr_4_s4_span, >vdc_spr_5_s0_span, >vdc_spr_5_s4_span, >vdc_spr_6_s0_span, >vdc_spr_6_s4_span, >vdc_spr_7_s0_span, >vdc_spr_7_s4_span, >vdc_spr_8_s0_span, >vdc_spr_8_s4_span, >vdc_spr_9_s0_span, >vdc_spr_9_s4_span, >vdc_spr_10_s0_span, >vdc_spr_10_s4_span, >vdc_spr_11_s0_span, >vdc_spr_11_s4_span, >vdc_spr_12_s0_span, >vdc_spr_12_s4_span, >vdc_spr_13_s0_span, >vdc_spr_13_s4_span, >vdc_spr_14_s0_span, >vdc_spr_14_s4_span, >vdc_spr_15_s0_span, >vdc_spr_15_s4_span, >vdc_spr_16_s0_span, >vdc_spr_16_s4_span, >vdc_spr_17_s0_span, >vdc_spr_17_s4_span
vdc_ink_lo
        !byte <(ST_SPR+0), <(ST_SPR+64), <(ST_SPR+112), <(ST_SPR+176), <(ST_SPR+224), <(ST_SPR+288), <(ST_SPR+346), <(ST_SPR+410), <(ST_SPR+468), <(ST_SPR+532), <(ST_SPR+580), <(ST_SPR+644), <(ST_SPR+692), <(ST_SPR+756), <(ST_SPR+806), <(ST_SPR+870), <(ST_SPR+920), <(ST_SPR+986), <(ST_SPR+1036), <(ST_SPR+1102), <(ST_SPR+1152), <(ST_SPR+1216), <(ST_SPR+1274), <(ST_SPR+1338), <(ST_SPR+1396), <(ST_SPR+1462), <(ST_SPR+1512), <(ST_SPR+1578), <(ST_SPR+1628), <(ST_SPR+1692), <(ST_SPR+1742), <(ST_SPR+1806), <(ST_SPR+1856), <(ST_SPR+1880), <(ST_SPR+1898), <(ST_SPR+1918)
vdc_ink_hi
        !byte >(ST_SPR+0), >(ST_SPR+64), >(ST_SPR+112), >(ST_SPR+176), >(ST_SPR+224), >(ST_SPR+288), >(ST_SPR+346), >(ST_SPR+410), >(ST_SPR+468), >(ST_SPR+532), >(ST_SPR+580), >(ST_SPR+644), >(ST_SPR+692), >(ST_SPR+756), >(ST_SPR+806), >(ST_SPR+870), >(ST_SPR+920), >(ST_SPR+986), >(ST_SPR+1036), >(ST_SPR+1102), >(ST_SPR+1152), >(ST_SPR+1216), >(ST_SPR+1274), >(ST_SPR+1338), >(ST_SPR+1396), >(ST_SPR+1462), >(ST_SPR+1512), >(ST_SPR+1578), >(ST_SPR+1628), >(ST_SPR+1692), >(ST_SPR+1742), >(ST_SPR+1806), >(ST_SPR+1856), >(ST_SPR+1880), >(ST_SPR+1898), >(ST_SPR+1918)
vdc_spr_h
        !byte 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 6, 6
vdc_spr_col
        !byte 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 12, 13

; Icons und Mini-Zellen: res_vdc_gfx.asm (Ressource-Datei, nur im VRAM)
