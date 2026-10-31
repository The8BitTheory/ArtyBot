#!/usr/bin/env python3
"""gen_music.py - Title music for ArtyBot: song in readable notation -> src/music_data.asm

Player: src/music.asm (3 voices, raster IRQ, one tick = MUS_SPEED frames = a 16th note).
  Voice 1 (SID 1): highlights - sparse, sound effects take this voice over when they play
  Voice 2 (SID 2): lead melody (pulse with PWM)
  Voice 3 (SID 3): bass + snare (the rhythm)

Notation of a pattern: tokens separated by blanks
  C4:2   note + duration in ticks (16ths), '#' for sharps (F#4)
  r:4    rest
  @lead  switch instrument
Pattern byte format: 0 = rest, 1..95 = note (C0 = 1), $80+d = duration d,
$A0+i = instrument i, $FF = end of pattern. Order list per voice: pattern
numbers, $FE + position = loop.

Call: python -B tools/gen_music.py
"""
import os, re

SPEED = 6          # frames per tick -> 125 BPM
PAL_CLOCK = 985248

# name: (AD, SR, wave first frame, wave afterwards, pulse width hi, pwm, arp)
# arp: 0 none, 1 major (0 4 7), 2 minor (0 3 7)
INSTRUMENTS = [
    ("bass",  0x08, 0x60, 0x80, 0x40, 0x08, 0, 0),   # noise click (kick) then pulse
    ("snare", 0x06, 0x00, 0x80, 0x80, 0x08, 0, 0),
    ("lead",  0x08, 0x95, 0x40, 0x40, 0x04, 1, 0),
    ("bell",  0x09, 0x00, 0x10, 0x10, 0x08, 0, 0),
    ("maj",   0x05, 0x00, 0x40, 0x40, 0x03, 0, 1),
    ("min",   0x05, 0x00, 0x40, 0x40, 0x03, 0, 2),
]
ARPS = [[0, 4, 7], [0, 3, 7]]
INS = {n[0]: i for i, n in enumerate(INSTRUMENTS)}

SEMI = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}
def midi(name):
    m = re.fullmatch(r'([A-G])(#?)(\d)', name)
    return 12 * (int(m.group(3)) + 1) + SEMI[m.group(1)] + (1 if m.group(2) else 0)

SN = "A6"          # snare "pitch" (noise frequency)

def bass_bar(root, fill=False):
    r = midi(root)
    n = lambda v: "%s" % v
    def nm(v):
        names = ['C','C#','D','D#','E','F','F#','G','G#','A','A#','B']
        return names[v % 12] + str(v // 12 - 1)
    o, f = nm(r + 12), nm(r + 7)
    rt = nm(r)
    if fill:
        return (f"@bass {rt}:2 {o}:2 @snare {SN}:2 @bass {rt}:2 "
                f"@snare {SN}:1 {SN}:1 {SN}:2 {SN}:2 @bass {f}:2")
    return (f"@bass {rt}:2 {o}:2 @snare {SN}:2 @bass {rt}:2 "
            f"{rt}:2 {o}:2 @snare {SN}:2 @bass {f}:2")

def stab(ins, root, last=False):
    return f"@{ins} {root}:3 r:3 {root}:3 r:7"

# --- the song ---------------------------------------------------------------
# Intro 2 bars (C G), then loop: A (C Am F G C Am F G), B (F G Em Am F G C G)
CH_A = [("C2", "maj"), ("A1", "min"), ("F1", "maj"), ("G1", "maj")] * 2
CH_B = [("F1", "maj"), ("G1", "maj"), ("E1", "min"), ("A1", "min"),
        ("F1", "maj"), ("G1", "maj"), ("C2", "maj"), ("G1", "maj")]

LA1 = "E4:2 G4:2 C5:2 r:2 B4:2 C5:2 G4:4"
LA2 = "A4:2 G4:2 E4:2 r:2 D4:2 E4:6"
LA3 = "F4:2 A4:2 C5:2 r:2 A4:2 C5:2 D5:4"
LA4 = "D5:2 C5:2 B4:2 G4:2 r:4 G4:2 B4:2"
LA8 = "D5:2 B4:2 G4:4 r:8"
LB = ["A4:4 C5:2 A4:2 G4:4 F4:4",
      "G4:2 A4:2 B4:2 D5:2 B4:4 G4:4",
      "E4:4 G4:2 B4:2 E5:4 D5:4",
      "C5:6 B4:2 A4:4 E4:4",
      "F4:2 A4:2 C5:2 F5:2 E5:4 C5:4",
      "D5:2 r:2 D5:2 E5:2 D5:4 B4:4",
      "C5:4 E5:2 G5:2 r:2 G5:2 E5:4",
      "D5:4 B4:2 G4:2 r:8"]

REST_BAR = "r:16"
PATTERNS = {
    "lead_intro": REST_BAR + " " + REST_BAR,
    "lead_a": "@lead " + " ".join([LA1, LA2, LA3, LA4, LA1, LA2, LA3, LA8]),
    "lead_b": "@lead " + " ".join(LB),
    "bass_intro": bass_bar("C2") + " " + bass_bar("G1", fill=True),
    "bass_a": " ".join(bass_bar(r) for r, _ in CH_A),
    "bass_b": " ".join(bass_bar(r, fill=(i == 7)) for i, (r, _) in enumerate(CH_B)),
    "hl_intro": stab("maj", "C5") + " " + stab("maj", "G4"),
    "hl_a": ("@bell " + " ".join([REST_BAR] * 3) + " r:8 G5:2 B5:2 D6:2 G6:2 "
             + " ".join([REST_BAR] * 3) + " r:6 G5:2 A5:2 B5:2 D6:2 G6:2"),
    "hl_b": " ".join(stab(c, n) for c, n in
                     [("maj", "F5"), ("maj", "G5"), ("min", "E5"), ("min", "A4"),
                      ("maj", "F5"), ("maj", "G5"), ("maj", "C5"), ("maj", "G4")]),
}
# order per voice: intro, then loop from position 1
ORDERS = [["hl_intro", "hl_a", "hl_b"],
          ["lead_intro", "lead_a", "lead_b"],
          ["bass_intro", "bass_a", "bass_b"]]
LOOP_POS = 1

# --- encoder ----------------------------------------------------------------
def encode(text):
    out, ticks, dur = [], 0, None
    for tok in text.split():
        if tok.startswith('@'):
            out.append(0xA0 + INS[tok[1:]]); continue
        name, d = tok.split(':'); d = int(d)
        assert 1 <= d <= 31, tok
        if d != dur:
            out.append(0x80 + d); dur = d
        if name == 'r':
            out.append(0)
        else:
            v = midi(name) - 11
            assert 1 <= v <= 95, tok
            out.append(v)
        ticks += d
    out.append(0xFF)
    assert len(out) <= 256, "pattern too long"
    return out, ticks

def main():
    names = list(PATTERNS)
    enc = {n: encode(PATTERNS[n]) for n in names}
    # all voices must have the same length per order slot
    for slot in range(len(ORDERS[0])):
        lens = {enc[o[slot]][1] for o in ORDERS}
        assert len(lens) == 1, ("voices out of step in slot", slot, [enc[o[slot]][1] for o in ORDERS])
    L = []
    L.append("; music_data.asm - GENERATED by tools/gen_music.py, do not edit by hand")
    L.append(f"MUS_SPEED = {SPEED}")
    L.append(f"MUS_INS = {len(INSTRUMENTS)}")
    order, starts = [], []
    for o in ORDERS:
        s = len(order); starts.append(s)
        order += [names.index(p) for p in o] + [0xFE, s + LOOP_POS]
    L.append("mus_ord_start !byte " + ", ".join(map(str, starts)))
    L.append("mus_order     !byte " + ", ".join("$%02X" % b for b in order))
    L.append("mus_pat_lo    !byte " + ", ".join("<mus_p_" + n for n in names))
    L.append("mus_pat_hi    !byte " + ", ".join(">mus_p_" + n for n in names))
    for col, lab in enumerate(["ins_ad", "ins_sr", "ins_wave1", "ins_wave2", "ins_pw", "ins_pwm", "ins_arp"]):
        L.append(f"{lab:13} !byte " + ", ".join("$%02X" % i[col + 1] for i in INSTRUMENTS)
                 + ("   ; " + " ".join(i[0] for i in INSTRUMENTS) if col == 0 else ""))
    L.append("mus_arp_base  !byte 0, " + ", ".join(str(3 * i) for i in range(len(ARPS))))
    L.append("mus_arp_tab   !byte " + ", ".join(str(v) for a in ARPS for v in a))
    fr = [0]
    for v in range(1, 96 + 12):
        f = 440.0 * 2 ** ((v + 11 - 69) / 12)
        fr.append(min(0xFFFF, round(f * 16777216 / PAL_CLOCK)))
    L.append("mus_flo       !byte " + ", ".join("$%02X" % (x & 255) for x in fr))
    L.append("mus_fhi       !byte " + ", ".join("$%02X" % (x >> 8) for x in fr))
    total = 0
    for n in names:
        b, t = enc[n]
        L.append(f"mus_p_{n:12} ; {t} ticks, {len(b)} bytes")
        for i in range(0, len(b), 16):
            L.append("        !byte " + ", ".join("$%02X" % x for x in b[i:i + 16]))
        total += len(b)
    loop_ticks = sum(enc[o][1] for o in ORDERS[0][LOOP_POS:])
    print(f"patterns {total} bytes, loop {loop_ticks} ticks = {loop_ticks*SPEED/50:.1f} s")
    path = os.path.join(os.path.dirname(__file__), "..", "src", "music_data.asm")
    with open(path, "w", newline="\r\n") as f:
        f.write("\n".join(L) + "\n")
    print("written", os.path.normpath(path))

if __name__ == "__main__":
    main()
