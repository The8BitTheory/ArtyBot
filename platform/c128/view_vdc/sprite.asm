; sprite.asm (VDC-View) - Software-Sprites (Roboter, Kiste, Schluessel) im Bitmap.
; Bilder: Tinte (H Zeilen x 5 Byte, Verschiebung 0/4 Pixel) liegt in der Ablage (store.asm);
; die Block-Codes (H/2 x 5) liest die CPU aus dem RAM-Bild (gfx_vdc.asm):
;   $FF leer (Kachel bleibt), 0 Figurfarbe auf der Grundfarbe des Blocks, $80 schwarz auf der
;   Grundfarbe, sonst fertiges Attribut. Grundfarbe = Hintergrund (hohes Nibble) des Blocks
;   darunter; andere Farben der Kachel in Randbloecken fallen weg (z. B. Gruen auf braunem Weg).
; Warum nicht je Grundfarbe vorberechnet: das Ergebnis haengt nur am Attribut-Byte (Grundfarbe
; OR Figurfarbe), die Tinte ist fuer jede Grundfarbe gleich. 45 Attribute rechnen kostet weniger
; als 16 Farbvarianten zu je 4,9 KB in der Ablage.
;
; Zeichnen: Hintergrund per Block-Copy VRAM -> VRAM sichern (ST_SAVE), Attribute der Sicherung
; lesen, neue Attribute schreiben, Tinte je Zeile in Laeufen nicht-leerer Bloecke per Block-Copy.
; Wegnehmen: Sicherung per Block-Copy zurueck.

SS_MAX   = 2
SS_W     = 5

ss_p     = $90                  ; Block-Codes im RAM (gfx_vdc.asm)
ss_ra    = $92                  ; laufende Zeilenadresse im VRAM
ss_q     = $94                  ; Laeufe der Blockzeilen
ss_c     = $9C                  ; Codes im RAM-Bild ($9C/$9D)

; Bildschirm wurde geloescht: kein Sprite steht mehr im Bild
ss_forget
        lda #0
        ldx #SS_MAX-1
-       sta ss_drawn,x
        sta ss_top,x
        dex
        bpl -
        rts

; alle Sprites vom Bild (in umgekehrter Reihenfolge)
ss_hide_all
        ldx #SS_MAX-1
-       stx ss_cur
        jsr ss_hide
        ldx ss_cur
        dex
        bpl -
        rts

; X = Sprite: Quelle/Ziel der Sicherung -> ss_sv
ss_save_addr
        ldx ss_cur
        ldy ss_buf,x
        lda ss_sv_lo,y
        sta ss_sv
        lda ss_sv_hi,y
        sta ss_sv+1
        rts

; Zeile weiter: ss_ra += 80
!macro ss_next {
        lda ss_ra
        clc
        adc #80
        sta ss_ra
        bcc +
        inc ss_ra+1
+
}
; ss_ra = Bitmapzeile ss_yy (bzw. Attributzeile ss_yy/2) + Spalte ss_cc
!macro ss_row_bm {
        ldx ss_yy
        lda vl_lo,x
        clc
        adc ss_cc
        sta ss_ra
        lda vl_hi,x
        adc #0
        sta ss_ra+1
}
!macro ss_row_at {
        lda ss_yy
        lsr
        tax
        lda al_lo,x
        clc
        adc ss_cc
        sta ss_ra
        lda al_hi,x
        adc #0
        sta ss_ra+1
}

; Zeilenschleife: ss_n Zeilen ab ss_ra, je Zeile Adresse .hi/.lo (R18/R19 = Ziel oder R32/R33 =
; Quelle) und R30 = 5. Das hohe Byte nur, wenn es sich aendert: ss_ra steigt um 80; ohne
; Uebertrag bleibt das hohe Byte gleich - auch das vom VDC weitergezaehlte (ein Lauf von 5 Byte,
; der die Seite ueberquert, erzwingt beim naechsten +80 ebenfalls einen Uebertrag).
!macro ss_rows .hi, .lo {
        lda ss_ra+1
.full   +vwr .hi
        lda ss_ra
.low    +vwr .lo
        lda #SS_W
        +vwr 30
        dec ss_n
        beq .end
        lda ss_ra
        clc
        adc #80
        sta ss_ra
        bcc .low
        inc ss_ra+1
        lda ss_ra+1
        jmp .full
.end
}

; X = Sprite: vom Bild nehmen (falls gezeichnet). Quelle = Sicherung (zaehlt weiter),
; je Zeile nur Ziel und R30.
!zone ss_hide
ss_hide stx ss_cur
        lda ss_drawn,x
        bne +
        rts
+       lda #0
        sta ss_drawn,x
        lda ss_dh,x
        sta ss_h
        lda ss_dy,x
        sta ss_yy
        lda ss_dc,x
        sta ss_cc
        jsr ss_ptr_check
        jsr ss_save_addr
        jsr vdc_mode_copy
        lda ss_sv+1
        +vwr 32
        lda ss_sv
        +vwr 33
        +ss_row_bm
        lda ss_h
        sta ss_n
        +ss_rows 18, 19
        +ss_row_at
        lda ss_h
        lsr
        sta ss_n
        +ss_rows 18, 19
        ldx ss_cur
        rts

; X = Sprite: an ss_col/ss_sh/ss_y,x mit Bild ss_img,x zeichnen (vorher ss_hide!)
!zone ss_draw
ss_draw stx ss_cur
        jsr ss_setup
        lda #1
        sta ss_drawn,x
        jsr ss_ptr_check
        jsr ss_save_addr
        jmp ss_draw_body

; X = Slot (= ss_cur): Bild laden (Codes, Laeufe, Tinte, Hoehe, Farbe; gemeinsames Sprite),
; neues Rechteck nach ss_yy/ss_cc und ss_dy/ss_dc/ss_dh,x.
ss_setup
        lda ss_img,x            ; Bild*2 + Verschiebung
        asl
        ora ss_sh,x
        sta ss_ix
        tay
        lda vdc_spr_lo,y
        sta ss_p
        lda vdc_spr_hi,y
        sta ss_p+1
        lda vdc_ink_lo,y        ; Tinte in der VRAM-Ablage
        sta ss_ink
        lda vdc_ink_hi,y
        sta ss_ink+1
        lda vdc_span_lo,y       ; Laeufe der Blockzeilen (generiert)
        sta ss_q
        lda vdc_span_hi,y
        sta ss_q+1
        ldy ss_img,x
        lda vdc_spr_h,y
        sta ss_h
        sta ss_dh,x
        asl
        asl
        adc ss_h
        sta ss_h5               ; Codes ab H*5
        lda vdc_spr_col,y
        sta ss_fc
        lda #$FF                ; kein Wechsel von Tinte/Figurfarbe
        sta ss_isw
        sta ss_fsw5
        lda ss_top,x            ; Roboter mit Kiste/Schluessel: ein gemeinsames Sprite
        beq +
        jsr ss_compose
        ldx ss_cur
+       lda ss_y,x
        sta ss_yy
        sta ss_dy,x
        lda ss_col,x
        sta ss_cc
        sta ss_dc,x
        rts

ss_draw_body
        ; 1. Hintergrund sichern: Ziel = Sicherung (zaehlt weiter), je Zeile Quelle + R30
        jsr vdc_mode_copy
        lda ss_sv+1
        +vwr 18
        lda ss_sv
        +vwr 19
        +ss_row_bm
        lda ss_h
        sta ss_n
        +ss_rows 32, 33
        +ss_row_at
        lda ss_h
        lsr
        sta ss_n
        +ss_rows 32, 33
        jsr ss_attrs
        ; 4. Tinte: lueckenlos in der Ablage, Quelle einmal setzen; je Zeile Ziel + Laenge
        lda ss_ink+1
        +vwr 32
        lda ss_ink
        +vwr 33
        +ss_row_bm
        lda #0
        sta ss_i
.wb     lda ss_i
        cmp ss_isw              ; gemeinsames Sprite: ab hier Tinte des Roboters
        bne +
        lda ss_ink2+1
        +vwr 32
        lda ss_ink2
        +vwr 33
        lda ss_i
+       lsr
        tay
        lda (ss_q),y            ; Lauf der Blockzeile: k0 | Laenge << 4
        beq .nl
        pha
        and #$0F
        clc
        adc ss_ra               ; Ziel = Zeile + k0
        tay
        lda ss_ra+1
        adc #0
        +vwr 18
        tya
        +vwr 19
        pla
        lsr
        lsr
        lsr
        lsr
        +vwr 30
.nl     +ss_next
        inc ss_i
        lda ss_i
        cmp ss_h
        bne .wb
        ldx ss_cur
        rts

; Attribute: gesicherte (ss_sv + H*5) lesen, neue schreiben
ss_attrs
        ; 2. gesicherte Attribute lesen (hinter der Bitmap-Sicherung)
        lda ss_sv
        clc
        adc ss_h5
        tay
        lda ss_sv+1
        adc #0
        +vwr 18
        tya
        +vwr 19
        ldx #31
        stx VDC_REG
        lda ss_h5
        lsr
        sta ss_n                ; H/2*5
        ldx #0
-       +vdc_wait
        lda VDC_DATA
        sta ss_sat,x
        inx
        cpx ss_n
        bne -
        ; 3. neue Attribute: Grundfarbe (hohes Nibble darunter) + Code
        lda ss_p                ; ss_c = Codes im RAM-Bild
        sta ss_c
        lda ss_p+1
        sta ss_c+1
        +ss_row_at
        lda ss_h
        lsr
        sta ss_n
        ldy #0                  ; Blockindex 0..H/2*5-1
.wa     cpy ss_fsw5             ; gemeinsames Sprite: ab hier Figurfarbe des Roboters
        bne +
        lda ss_fc2
        sta ss_fc
+       lda ss_ra+1
        +vwr 18
        lda ss_ra
        +vwr 19
        ldx #31
        stx VDC_REG
        lda #SS_W
        sta ss_k
.wak    lda (ss_c),y
        cmp #$FF
        beq .keep
        cmp #$80
        beq .black
        cmp #0
        bne .put                ; fertiges Attribut
        lda ss_sat,y            ; Figurfarbe auf der Grundfarbe
        and #$F0
        ora ss_fc
        jmp .put
.black  lda ss_sat,y
        and #$F0
        jmp .put
.keep   lda ss_sat,y
.put    +vdc_wait
        sta VDC_DATA
        iny
        dec ss_k
        bne .wak
        +ss_next
        dec ss_n
        bne .wa
        rts

; ---- Flackerfrei verschieben (Slot 0, kein anderes Sprite im Bild) -----------------------
; Die Figur verschwindet nie: 1. neue Sicherung aus alter Sicherung (Ueberlappung) und Bild
; (Rest), 2./3. Attribute, 4. Tinte samt Hintergrund der leeren Bytes aus der neuen Sicherung,
; 5. nur die nicht mehr bedeckten Teile des alten Rechtecks aus der alten Sicherung zurueck.
; Sicherungen von Slot 0 wechseln zwischen Puffer 0 und 1.
!zone ss_move
ss_move ldx #0
        stx ss_cur
        lda ss_dy               ; altes Rechteck
        sta ss_oy
        sta ss_yy
        lda ss_dc
        sta ss_oc
        sta ss_cc
        lda ss_dh
        sta ss_oh
        sta ss_h
        jsr ss_ptr_check
        jsr ss_save_addr
        lda ss_sv
        sta ss_so
        lda ss_sv+1
        sta ss_so+1
        ldx #0
        jsr ss_setup
        jsr ss_ptr_check
        jsr vdc_mode_copy
        lda ss_cc
        sec
        sbc ss_oc
        sta ss_dcol
        bne .moved              ; gleiches Rechteck: Sicherung bleibt, nichts zurueck
        lda ss_yy
        cmp ss_oy
        bne .moved
        lda ss_h
        cmp ss_oh
        bne .moved
        jsr ss_save_addr
        jsr ss_attrs
        jsr ss_inkfill
        jmp .done
.moved  lda ss_buf
        eor #1
        sta ss_buf
        jsr ss_save_addr
        ; 1. neue Sicherung (Ziel fortlaufend)
        lda ss_sv+1
        +vwr 18
        lda ss_sv
        +vwr 19
        lda #0
        sta ss_md
        lda ss_yy
        sta ss_ry
        lda ss_h
        sta ss_rn
        lda ss_oy
        sta ss_roy
        lda ss_oh
        sta ss_ron
        lda ss_so
        sta ss_rob
        lda ss_so+1
        sta ss_rob+1
        jsr ss_bseg
        jsr ss_half
        jsr ss_bseg
        ; 2./3.
        jsr ss_attrs
        ; 4.
        jsr ss_inkfill
        ; 5. Reste des alten Bilds
        lda #0
        sta ss_md
        lda ss_oy
        sta ss_ry
        lda ss_oh
        sta ss_rn
        lda ss_yy
        sta ss_roy
        lda ss_h
        sta ss_ron
        lda ss_so
        sta ss_rob
        lda ss_so+1
        sta ss_rob+1
        jsr ss_rseg
        jsr ss_half
        jsr ss_rseg
.done   ldx #0
        lda #1
        sta ss_drawn
        rts

; von Bitmapzeilen auf Attributzeilen: md = 1, Zeilen/2, rob += Hoehe(ss_ron bzw. ss_rn alt)*5
ss_half inc ss_md
        lsr ss_ry
        lsr ss_rn
        lsr ss_roy
        lsr ss_ron
        lda ss_oh               ; alte Sicherung: Attribute hinter oh*5 Bitmapbytes
        asl
        asl
        clc
        adc ss_oh
        clc
        adc ss_so
        sta ss_rob
        lda ss_so+1
        adc #0
        sta ss_rob+1
        rts

; A = Zeile (md 0: Bitmap, 1: Attribute) -> ss_ra = Adresse + ss_xc
ss_scr  tax
        lda ss_md
        bne +
        lda vl_lo,x
        clc
        adc ss_xc
        sta ss_ra
        lda vl_hi,x
        adc #0
        sta ss_ra+1
        rts
+       lda al_lo,x
        clc
        adc ss_xc
        sta ss_ra
        lda al_hi,x
        adc #0
        sta ss_ra+1
        rts

; Block-Copy: Quelle ss_src, A Bytes an das laufende Ziel
ss_cpy  sta ss_ln
        lda ss_src+1
        +vwr 32
        lda ss_src
        +vwr 33
        lda ss_ln
        +vwr 30
        rts
ss_s_ra lda ss_ra
        sta ss_src
        lda ss_ra+1
        sta ss_src+1
        rts
ss_s_o  lda ss_o16
        sta ss_src
        lda ss_o16+1
        sta ss_src+1
        rts
; ss_o16 = ss_rob + A*5
ss_o5   sta ss_t
        asl
        asl
        clc
        adc ss_t
        clc
        adc ss_rob
        sta ss_o16
        lda ss_rob+1
        adc #0
        sta ss_o16+1
        rts

; 1. Zeilen ss_ry.. (ss_rn) des neuen Rechtecks sichern; Zeilen im alten Rechteck (ss_roy,
; ss_ron, Sicherung ss_rob) nehmen die ueberlappenden Spalten aus der alten Sicherung.
!zone ss_bseg
ss_bseg lda #0
        sta ss_ri
        lda ss_cc
        sta ss_xc
.row    lda ss_ry
        clc
        adc ss_ri
        sta ss_rl
        jsr ss_scr
        lda ss_rl
        sec
        sbc ss_roy
        bcc .fullj
        cmp ss_ron
        bcc +
.fullj  jmp .full
+       sta ss_t2               ; o = Zeile im alten Rechteck
        jsr ss_o5
        lda ss_dcol
        bne +
        lda ss_ron              ; gleiche Spalte: alle restlichen ueberlappenden Zeilen am Stueck
        sec
        sbc ss_t2
        sta ss_t
        lda ss_rn
        sec
        sbc ss_ri
        cmp ss_t
        bcc ++
        lda ss_t
++      sta ss_t                ; k Zeilen
        clc
        adc ss_ri
        sta ss_ri
        dec ss_ri
        jsr ss_s_o
        lda ss_t
        asl
        asl
        clc
        adc ss_t
        jsr ss_cpy
        jmp .next
+       lda ss_dcol
        bmi .neg
        cmp #5
        bcs .full
        clc                     ; rechts verschoben: alte Spalten d..4, dann Bild
        adc ss_o16
        sta ss_src
        lda ss_o16+1
        adc #0
        sta ss_src+1
        lda #5
        sec
        sbc ss_dcol
        sta ss_t2
        jsr ss_cpy
        lda ss_dcol
        beq .next
        lda ss_t2
        clc
        adc ss_ra
        sta ss_src
        lda ss_ra+1
        adc #0
        sta ss_src+1
        lda ss_dcol
        jsr ss_cpy
        jmp .next
.neg    eor #$FF                ; links verschoben: Bild n Spalten, dann alte Spalten 0..4-n
        clc
        adc #1
        cmp #5
        bcs .full
        sta ss_t2
        jsr ss_s_ra
        lda ss_t2
        jsr ss_cpy
        jsr ss_s_o
        lda #5
        sec
        sbc ss_t2
        jsr ss_cpy
        jmp .next
.full   jsr ss_s_ra
        lda #5
        jsr ss_cpy
.next   inc ss_ri
        lda ss_ri
        cmp ss_rn
        beq +
        jmp .row
+       rts

; 5. Zeilen ss_ry.. (ss_rn) des alten Rechtecks (Sicherung ss_rob): was das neue Rechteck
; (Zeilen ss_roy, ss_ron) nicht bedeckt, zurueck ins Bild.
!zone ss_rseg
ss_rseg lda #0
        sta ss_ri
        lda ss_oc
        sta ss_xc
.row    lda ss_ry
        clc
        adc ss_ri
        sta ss_rl
        sec
        sbc ss_roy
        bcc .out
        cmp ss_ron
        bcs .out
        lda ss_dcol             ; Zeile auch im neuen Rechteck: bei gleicher Spalte nichts
        bne +
        jmp .next
+       jsr .adr
        lda ss_dcol
        bmi .neg
        cmp #5
        bcs .full
        sta ss_t2               ; neues Rechteck rechts: alte Spalten 0..d-1
        jsr .dst
        jsr ss_s_o
        lda ss_t2
        jsr ss_cpy
        jmp .next
.neg    eor #$FF                ; neues Rechteck links: alte Spalten 5-n..4
        clc
        adc #1
        cmp #5
        bcs .full
        sta ss_t2
        lda #5
        sec
        sbc ss_t2
        sta ss_t
        clc
        adc ss_ra
        sta ss_ra
        bcc +
        inc ss_ra+1
+       lda ss_t
        clc
        adc ss_o16
        sta ss_o16
        bcc +
        inc ss_o16+1
+       jsr .dst
        jsr ss_s_o
        lda ss_t2
        jsr ss_cpy
        jmp .next
.out    jsr .adr
.full   jsr .dst
        jsr ss_s_o
        lda #5
        jsr ss_cpy
.next   inc ss_ri
        lda ss_ri
        cmp ss_rn
        beq +
        jmp .row
+       rts
.adr    lda ss_ri
        jsr ss_o5
        lda ss_rl
        jmp ss_scr
.dst    lda ss_ra+1
        +vwr 18
        lda ss_ra
        +vwr 19
        rts

; 4. Tinte je Bitmapzeile, leere Bytes der Zeile aus der neuen Sicherung (alte Figur weg)
!zone ss_inkfill
ss_inkfill
        lda ss_ink
        sta ss_ip
        lda ss_ink+1
        sta ss_ip+1
        lda ss_sv
        sta ss_o16
        lda ss_sv+1
        sta ss_o16+1
        lda #0
        sta ss_md
        sta ss_i
        lda ss_cc
        sta ss_xc
.ln     lda ss_i
        cmp ss_isw              ; gemeinsames Sprite: ab hier Tinte des Roboters
        bne +
        lda ss_ink2
        sta ss_ip
        lda ss_ink2+1
        sta ss_ip+1
+       lda ss_yy
        clc
        adc ss_i
        jsr ss_scr
        lda ss_ra+1
        +vwr 18
        lda ss_ra
        +vwr 19
        lda ss_i
        lsr
        tay
        lda (ss_q),y
        bne .sp
        jsr ss_s_o              ; leere Zeile: Hintergrund
        lda #5
        jsr ss_cpy
        jmp .nx
.sp     tax
        and #$0F
        sta ss_k0
        txa
        lsr
        lsr
        lsr
        lsr
        sta ss_ln2
        lda ss_k0
        beq +
        jsr ss_s_o
        lda ss_k0
        jsr ss_cpy
+       lda ss_ip
        sta ss_src
        lda ss_ip+1
        sta ss_src+1
        lda ss_ln2
        jsr ss_cpy
        lda ss_ip
        clc
        adc ss_ln2
        sta ss_ip
        bcc +
        inc ss_ip+1
+       lda ss_k0
        clc
        adc ss_ln2
        sta ss_t
        lda #5
        sec
        sbc ss_t
        beq .nx
        sta ss_t2
        lda ss_o16
        clc
        adc ss_t
        sta ss_src
        lda ss_o16+1
        adc #0
        sta ss_src+1
        lda ss_t2
        jsr ss_cpy
.nx     lda ss_o16
        clc
        adc #5
        sta ss_o16
        bcc +
        inc ss_o16+1
+       inc ss_i
        lda ss_i
        cmp ss_h
        beq +
        jmp .ln
+       rts

; Gemeinsames Sprite (Slot X = ss_cur): oben Bild ss_top & $1F (Kiste/Schluessel), bei Bit 6
; zwei leere Zeilen Abstand (Wippen beim Gehen), darunter der Roboter (schon geladen: ss_p,
; ss_q, ss_ink, ss_h, ss_fc). Codes und Laeufe werden in ss_cbuf/ss_sbuf zusammengesetzt
; (nur wenn sich Bild, Verschiebung oder Oberteil geaendert haben); Tinte und Figurfarbe
; wechseln beim Zeichnen an der Grenze (ss_isw, ss_fsw5). ss_y ist die Oberkante.
!zone ss_compose
ss_compose
        jsr ss_compose_calc
        lda ss_ink              ; Tinte: erst Oberteil, dann Roboter
        sta ss_ink2
        lda ss_ink+1
        sta ss_ink2+1
        ldy ss_ti
        lda vdc_ink_lo,y
        sta ss_ink
        lda vdc_ink_hi,y
        sta ss_ink+1
        lda ss_fc
        sta ss_fc2
        lda ss_tfc
        sta ss_fc
        ldx ss_cur
        ldy ss_sh,x
        lda ss_cb_lo,y
        sta ss_p
        lda ss_cb_hi,y
        sta ss_p+1
        lda ss_sb_lo,y
        sta ss_q
        lda ss_sb_hi,y
        sta ss_q+1
        lda ss_isw              ; Hoehe = Oberteil + Abstand + Roboter
        clc
        adc ss_h
        sta ss_h
        sta ss_dh,x
        asl
        asl
        adc ss_h
        sta ss_h5
        rts

; Vor dem Wegnehmen (ausserhalb des Zeitfensters): Puffer fuer Slot X vorbereiten.
ss_prebuild
        lda ss_top,x
        bne +
        rts
+       stx ss_cur
        lda ss_img,x
        asl
        ora ss_sh,x
        sta ss_ix
        tay
        lda vdc_spr_lo,y
        sta ss_p
        lda vdc_spr_hi,y
        sta ss_p+1
        lda vdc_span_lo,y
        sta ss_q
        lda vdc_span_hi,y
        sta ss_q+1
        lda ss_top,x
        ; weiter
; A = ss_top, X = Slot, ss_ix/ss_p/ss_q = Roboter: Werte des Oberteils, Puffer je Verschiebung
; (2 Eintraege) bei Bedarf neu.
ss_compose_calc
        sta ss_tp
        and #$40
        beq +
        lda #2
+       sta ss_gap
        lda ss_tp               ; Index Oberteil = Bild*2 + Verschiebung
        and #$1F
        sta ss_ti
        tay
        lda vdc_spr_h,y
        sta ss_ht
        lda vdc_spr_col,y
        sta ss_tfc
        lda ss_ti
        asl
        ora ss_sh,x
        sta ss_ti
        lda ss_ht               ; Grenze: Zeile ht+gap, Blockzeile (ht+gap)/2 -> Codeindex *5
        clc
        adc ss_gap
        sta ss_isw
        lsr
        sta ss_t
        asl
        asl
        adc ss_t
        sta ss_fsw5
        ldy ss_sh,x
        lda ss_ix
        cmp ss_ck1,y
        bne .build
        lda ss_tp
        cmp ss_ck2,y
        bne .build
        rts
.build  lda ss_ix
        sta ss_ck1,y
        lda ss_tp
        sta ss_ck2,y
        lda ss_cb_lo,y          ; Ziel: Puffer dieser Verschiebung (ss_ra = Codes, vs_q = Laeufe)
        sta ss_ra
        lda ss_cb_hi,y
        sta ss_ra+1
        lda ss_sb_lo,y
        sta ss_c
        lda ss_sb_hi,y
        sta ss_c+1
        ; Laeufe: Oberteil ht/2, Abstand (0), Roboter 9
        ldy ss_ti
        lda vdc_span_lo,y
        sta vs_q
        lda vdc_span_hi,y
        sta vs_q+1
        lda ss_ht
        lsr
        sta ss_k
        ldy #0
-       lda (vs_q),y
        sta (ss_c),y
        iny
        cpy ss_k
        bne -
        lda #0
-       cpy ss_t
        beq +
        sta (ss_c),y
        iny
        bne -
+       tya
        clc
        adc ss_c
        sta ss_c
        bcc +
        inc ss_c+1
+       ldy #0
-       lda (ss_q),y
        sta (ss_c),y
        iny
        cpy #9
        bne -
        ; Codes: Oberteil ht/2*5, Abstand $FF, Roboter 45
        ldy ss_ti
        lda vdc_spr_lo,y
        sta vs_q
        lda vdc_spr_hi,y
        sta vs_q+1
        lda ss_k
        asl
        asl
        adc ss_k
        sta ss_k
        ldy #0
-       lda (vs_q),y
        sta (ss_ra),y
        iny
        cpy ss_k
        bne -
        lda #$FF
-       cpy ss_fsw5
        beq +
        sta (ss_ra),y
        iny
        bne -
+       tya
        clc
        adc ss_ra
        sta ss_ra
        bcc +
        inc ss_ra+1
+       ldy #0
-       lda (ss_p),y
        sta (ss_ra),y
        iny
        cpy #45
        bne -
        rts

ss_cb_lo !byte <ss_cbuf, <(ss_cbuf+65)
ss_cb_hi !byte >ss_cbuf, >(ss_cbuf+65)
ss_sb_lo !byte <ss_sbuf, <(ss_sbuf+13)
ss_sb_hi !byte >ss_sbuf, >(ss_sbuf+13)

; Zeiger nur wegnehmen, wenn er das Rechteck (ss_cc, ss_yy, 5 Spalten, ss_h Zeilen) beruehrt
; (sonst flackert er bei jeder Bewegung der Figur).
!zone ss_ptr_check
ss_ptr_check
        lda vp_x
        cmp #$FF
        beq .no
        clc                     ; vp_x+3 > cc  und  vp_x < cc+5
        adc #3
        cmp ss_cc
        bcc .no
        beq .no
        lda ss_cc
        clc
        adc #SS_W
        cmp vp_x
        bcc .no
        beq .no
        lda vp_y                ; vp_y+8 > yy  und  vp_y < yy+h
        clc
        adc #VP_LINES
        cmp ss_yy
        bcc .no
        beq .no
        lda ss_yy
        clc
        adc ss_h
        cmp vp_y
        bcc .no
        beq .no
        jsr vp_hide
.no     rts

; Ziel (vdc_addr) bzw. Quelle (R32/R33) der Bitmap-Zeile ss_i / Attribut-Blockzeile ss_i
ss_bm_addr
        jsr ss_bm_ay
        jmp vdc_addr
ss_at_addr
        jsr ss_at_ay
        jmp vdc_addr
ss_bm_src
        jsr ss_bm_ay
        jmp ss_src_ay
ss_at_src
        jsr ss_at_ay
ss_src_ay                       ; A = hi, Y = lo -> R32/R33
        ldx #32
        jsr vdc_wr
        tya
        ldx #33
        jmp vdc_wr
ss_bm_ay
        lda ss_yy
        clc
        adc ss_i
        tax
        lda vl_lo,x
        clc
        adc ss_cc
        tay
        lda vl_hi,x
        adc #0
        rts
ss_at_ay
        lda ss_yy
        lsr
        clc
        adc ss_i
        tax
        lda al_lo,x
        clc
        adc ss_cc
        tay
        lda al_hi,x
        adc #0
        rts

ss_sv_lo !byte <ST_SAVE, <(ST_SAVE+ST_SAVE_B), <(ST_SAVE+2*ST_SAVE_B)
ss_sv_hi !byte >ST_SAVE, >(ST_SAVE+ST_SAVE_B), >(ST_SAVE+2*ST_SAVE_B)
ss_buf   !byte 0, 2             ; Sicherung des gezeichneten Bilds (Slot 0: 0/1 im Wechsel)

ss_drawn !fill SS_MAX, 0        ; 1 = steht im Bild (Hintergrund gesichert)
ss_dc    !fill SS_MAX, 0        ; gezeichnet an: Spalte, Zeile, Hoehe
ss_dy    !fill SS_MAX, 0
ss_dh    !fill SS_MAX, 0
ss_img   !fill SS_MAX, 0        ; gewuenscht: Bild, Spalte, Verschiebung (0/1), Zeile
ss_col   !fill SS_MAX, 0
ss_sh    !fill SS_MAX, 0
ss_y     !fill SS_MAX, 0
ss_cur   !byte 0
ss_h     !byte 0
ss_h5    !byte 0
ss_yy    !byte 0
ss_cc    !byte 0
ss_i     !byte 0
ss_o     !byte 0
ss_t     !byte 0
ss_k     !byte 0
ss_k0    !byte 0
ss_n     !byte 0
ss_s     !byte 0
ss_fc    !byte 0
ss_sv    !word 0
ss_ink   !word 0
ss_sat   !fill 5*13, 0
ss_top   !fill SS_MAX, 0        ; 0 oder Oberteil (Bild | $40 = 2 Zeilen Abstand), nur Slot 0
ss_cbuf  !fill 2*65, 0          ; gemeinsames Sprite: Codes je Verschiebung
ss_sbuf  !fill 2*13, 0          ; gemeinsames Sprite: Laeufe je Verschiebung
ss_ck1   !byte $FF, $FF         ; zusammengesetzt fuer Bild*2+Versch. / Oberteil (je Versch.)
ss_ck2   !byte $FF, $FF
ss_tp    !byte 0
ss_ti    !byte 0
ss_ht    !byte 0
ss_gap   !byte 0
ss_tfc   !byte 0
ss_fc2   !byte 0
ss_isw   !byte $FF
ss_fsw5  !byte $FF
ss_ink2  !word 0
ss_oy    !byte 0                ; ss_move: altes Rechteck, Sicherung, Arbeitswerte
ss_oc    !byte 0
ss_oh    !byte 0
ss_so    !word 0
ss_md    !byte 0
ss_ry    !byte 0
ss_rn    !byte 0
ss_roy   !byte 0
ss_ron   !byte 0
ss_rob   !word 0
ss_ri    !byte 0
ss_rl    !byte 0
ss_o16   !word 0
ss_src   !word 0
ss_ln    !byte 0
ss_ln2   !byte 0
ss_dcol  !byte 0
ss_t2    !byte 0
ss_xc    !byte 0
ss_ip    !word 0
ss_ix    !byte 0
