; bank1.asm (C128, TARGET_C128VDC) - Ressource-Datei nach RAM-Bank 1 laden und von dort in den
; VDC kopieren. Liegt am Anfang des Programms (unter $4000): mit 16 KB gemeinsamem RAM unten
; ($D506 Bit 0-2 = %111) sieht die CPU $0000-$3FFF immer aus Bank 0 - auch wenn $FF00 auf
; Bank 1 steht. Darum muessen diese Routinen, die VDC-Routinen, die sie aufrufen, und ihre
; Variablen unter $4000 liegen; die Ressource liegt in Bank 1 ab $4000.
; Nur beim Start (vor dem eigenen IRQ, Interrupts aus): kein IRQ laeuft je mit Bank 1.

RES_BASE    = $4000             ; wie src/res128vdc.asm
RES_MAGIC   = $A7
RES_LOGO    = 0                 ; Teile der Ressource (Reihenfolge der Tabelle)
RES_ROBOT   = 1
RES_CHEST   = 2
RES_TROPHY  = 3
RES_ICONS   = 4
RES_MINI    = 5
RES_CELLS_M = 6
RES_CELLS_W = 7
RES_INK     = 8
MMU_CFG_BANK1 = $7E             ; wie MMU_CFG_RAM_IO, aber RAM-Bank 1

KERNAL_SETBNK = $FF68
KERNAL_SETLFS = $FFBA
KERNAL_SETNAM = $FFBD
KERNAL_LOAD   = $FFD5
KERNAL_DEVNUM = $BA             ; zuletzt benutztes Geraet

; Noch mit KERNAL (direkt nach dem Start): Hinweis im VDC-Textmodus, "artybot.gfx" nach Bank 1
; laden. Fehler: Meldung, auf Taste warten, Neustart.
!zone res_load
res_load
        lda #<str_res_loading
        ldx #>str_res_loading
        jsr res_text
        lda #1                  ; Daten nach Bank 1, Dateiname in Bank 0
        ldx #0
        jsr KERNAL_SETBNK
        lda #str_res_name_end - str_res_name
        ldx #<str_res_name
        ldy #>str_res_name
        jsr KERNAL_SETNAM
        lda #1
        ldx KERNAL_DEVNUM
        cpx #8
        bcs +
        ldx #8
+       ldy #1                  ; Ladeadresse aus der Datei
        jsr KERNAL_SETLFS
        lda #0
        jsr KERNAL_LOAD
        bcs res_fail
        rts

; Nach dem Umschalten auf die eigene Konfiguration (Interrupts aus): gemeinsames RAM an,
; Kennung der Ressource in Bank 1 pruefen.
res_ready
        jsr res_common_on
        jsr res_check
        bcc res_fail
        rts

res_fail
        lda #<str_res_missing
        ldx #>str_res_missing
        jsr res_text
        jmp res_wait_reset

; A/X = Text: in Zeile 0 des VDC-Textbildschirms (KERNAL: Bildschirm $0000, Attribute $0800)
!zone res_text
res_text
        sta vt_ptr
        stx vt_ptr+1
        lda #$00
        ldy #$00
        jsr vdc_addr
        ldy #0
.l      lda (vt_ptr),y
        beq .fill
        jsr res_scr
        jsr vdc_put
        iny
        bne .l
.fill   lda #' '                ; Rest der Zeile leeren
        jsr vdc_put
        iny
        cpy #80
        bcc .fill
        lda #$08
        ldy #$00
        jsr vdc_addr
        ldy #80
        lda #$8F                ; weiss, Gross-/Kleinbuchstaben
-       jsr vdc_put
        dey
        bne -
        rts

; ASCII -> Screencode (wie ascii2scr; der KERNAL-Zeichensatz 2 im VDC)
res_scr cmp #$61
        bcc +
        cmp #$7B
        bcs +
        sbc #$5F
+       rts

; Taste abwarten, dann Neustart
res_wait_reset
        sei
        lda #0
        sta CIA1_PRA
-       lda CIA1_PRB
        cmp #$FF
        bne -
-       lda CIA1_PRB
        cmp #$FF
        beq -
        jmp system_reset

; Carry gesetzt, wenn die Ressource in Bank 1 steht (erstes Byte = Kennung)
!zone res_check
res_check
        lda #<RES_BASE
        sta vt_ptr
        lda #>RES_BASE
        sta vt_ptr+1
        jsr res_peek
        cmp #RES_MAGIC
        beq +
        clc
        rts
+       sec
        rts

; Ab hier: eigene Speicherkonfiguration (MMU_CFG_RAM_IO). Gemeinsames RAM unten 16 KB.
res_common_on
        lda MMU_RCR
        and #$F0
        ora #%0111
        sta MMU_RCR
        rts

; Y = 0: Byte (vt_ptr),Y aus Bank 1 -> A
res_peek
        ldy #0
        php
        sei
        ldx MMU_CR
        lda #MMU_CFG_BANK1
        sta MMU_CR
        lda (vt_ptr),y
        stx MMU_CR
        plp
        rts

; A = Teil (RES_*): Adresse aus der Tabelle in Bank 1 -> vt_ptr
!zone res_item
res_item
        asl
        clc
        adc #2                  ; hinter Kennung und Anzahl
        sta vt_tmp
        lda #<RES_BASE
        clc
        adc vt_tmp
        sta vt_ptr
        lda #>RES_BASE
        adc #0
        sta vt_ptr+1
        jsr res_peek
        pha
        inc vt_ptr
        bne +
        inc vt_ptr+1
+       jsr res_peek
        sta vt_ptr+1
        pla
        sta vt_ptr
        rts

; A = Teil: vdc_cnt Bytes ungepackt aus Bank 1 nach VRAM vdc_dst
res_upload
        jsr res_item
        lda vt_ptr
        sta vdc_src
        lda vt_ptr+1
        sta vdc_src+1
        lda #MMU_CFG_BANK1
        sta MMU_CR
        jsr vdc_upload
        lda #MMU_CFG_RAM_IO
        sta MMU_CR
        rts

; A = Teil: gepacktes Bild aus Bank 1 entpacken, vu_cnt Bytes ab VRAM-Adresse vdc_dst
res_unpack
        jsr res_item
        lda #0
        sta vt_run
        sta vt_lit
        lda vdc_dst+1
        ldy vdc_dst
        jsr vdc_addr
        lda #MMU_CFG_BANK1
        sta MMU_CR
        jsr vu_unpack
        lda #MMU_CFG_RAM_IO
        sta MMU_CR
        rts

; ---- Entpacken ins VRAM ----------------------------------------------------------
; Format (tools/gen_vdc_title.py): c < $80: c+1 Bytes folgen; c >= $80: naechstes Byte (c-$7D)-mal.
; Laeufe ab VU_FILL Bytes per Block-Fill: erstes Byte ueber R31, Rest mit R30 = n-1.
;
; Rechnung (Zyklen bei 2 MHz, VDC bereit): ein Byte ueber R31 in der Schleife kostet etwa
; 15 Zyklen (warten 6, sta 4, Zaehler/Sprung 5). Block-Fill: erstes Byte 15, R30 waehlen +
; Zaehler schreiben + R31 wieder waehlen etwa 20, dazu ca. 2 Zyklen je weiteres Byte, die der
; VDC selbst schreibt (die CPU wartet beim naechsten Zugriff). Byteweise: 15*n, Fill: 35+2*(n-1).
; Gleichstand bei n = 2,5 -> ab 3 gleichen Bytes lohnt sich der Fill (= kuerzester Lauf im Format).
VU_FILL = 3

; A/X = gepackte Daten: Zustand zuruecksetzen
vu_start
        sta vt_ptr
        stx vt_ptr+1
        lda #0
        sta vt_run
        sta vt_lit
        rts

; vu_cnt (16 Bit) Bytes an die aktuelle Schreibadresse (R31 gewaehlt) entpacken. Ein Lauf darf
; ueber das Ende hinausgehen (Rest bleibt fuer den naechsten Aufruf in vt_run).
!zone vu_unpack
vu_unpack
        jsr vdc_mode_fill
        ldx #31
        stx VDC_REG
.loop   lda vu_cnt
        ora vu_cnt+1
        bne .more
        rts
.more   lda vt_run
        beq .nr
        ; Lauf: k = min(vt_run, vu_cnt)
        ldx vu_cnt+1
        bne .krun
        cmp vu_cnt
        bcc .krun
        lda vu_cnt
.krun   sta vu_k
        lda vt_run
        sec
        sbc vu_k
        sta vt_run
        lda vu_cnt
        sec
        sbc vu_k
        sta vu_cnt
        bcs +
        dec vu_cnt+1
+       lda vt_val
        ldx vu_k
        cpx #VU_FILL
        bcc .bytes
        +vdc_wait               ; erstes Byte, dann R30 = k-1 mal wiederholen
        sta VDC_DATA
        dex
        txa
        ldx #30
        stx VDC_REG
        +vdc_wait
        sta VDC_DATA
        ldx #31
        stx VDC_REG
        jmp .loop
.bytes  +vdc_wait
        sta VDC_DATA
        dex
        bne .bytes
        jmp .loop
.nr     lda vt_lit
        beq .ctl
        ; Literale: so viele wie da sind und gebraucht werden
.lit    ldy #0
        lda (vt_ptr),y
        +vdc_wait
        sta VDC_DATA
        inc vt_ptr
        bne +
        inc vt_ptr+1
+       lda vu_cnt
        bne +
        dec vu_cnt+1
+       dec vu_cnt
        dec vt_lit
        bne +
        jmp .loop
+       lda vu_cnt
        ora vu_cnt+1
        bne .lit
        rts
.ctl    ldy #0
        lda (vt_ptr),y
        bmi .rep
        clc
        adc #1
        sta vt_lit
        jsr .inc
        jmp .loop
.rep    sec
        sbc #$7D
        sta vt_run
        iny
        lda (vt_ptr),y
        sta vt_val
        jsr .inc
        jsr .inc
        jmp .loop
.inc    inc vt_ptr
        bne +
        inc vt_ptr+1
+       rts

vu_cnt   !word 0
vu_k     !byte 0
vt_run   !byte 0                ; Zustand des Entpackers (hier unten: auch mit Bank 1 sichtbar)
vt_lit   !byte 0
vt_val   !byte 0

str_res_name    !pet "artybot.gfx"          ; PETSCII wie im Verzeichnis
str_res_name_end
str_res_loading !text "ArtyBot: loading graphics (artybot.gfx) ...", 0
str_res_missing !text "ArtyBot: artybot.gfx not found on this disk. Any key: reset.", 0

!if * > RES_BASE {
    !error "bank1.asm/vdc.asm muessen unter RES_BASE liegen (gemeinsames RAM)"
}
