#!/usr/bin/env python3
"""check_layers.py - prueft die Trennung Logik / View / Plattform.

  python -B tools/check_layers.py        (Exit-Code 1 bei Verstoessen)

Logik-Dateien (src/*.asm ausser den unten genannten Treibern) duerfen keine Grafik-
hardware, kein Bildschirm-/Farb-RAM, keine Textausgabe und keine Speicherkonfiguration
benutzen: Zeichnen nur ueber die View-Einstiegspunkte (HANDOVER.md, View-Schnittstelle).
sound/music/ambient (SID) und input (CIA, 1351) sind noch Plattformtreiber in src/
(gleich auf C64, C128, MEGA65; fuer den X16 auszulagern)."""
import re, glob, os, sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
DRIVERS = {'sound.asm', 'music.asm', 'ambient.asm', 'input.asm', 'music_data.asm'}
FORBIDDEN = re.compile(r'\b(VIC_\w+|SCREEN|COLORRAM|CHARSET|TITLE_CHARSET|END_CHARSET|SPR_PTR0|'
                       r'SPRITE_BLOCK\d?|SPRITES|row_lo|row_hi|set_cursor|put_char|put_str|paint|'
                       r'cur_col|cur_x|cur_y|win_w|draw_window|clear_screen|CPU_PORT|CPU_DDR|MMU_\w+|'
                       r'SID_\w+|CIA\w+|\$D[0-9A-F]{3})\b')
bad = 0
for path in sorted(glob.glob(os.path.join(ROOT, 'src', '*.asm'))):
    name = os.path.basename(path)
    if name in DRIVERS:
        continue
    for n, line in enumerate(open(path, encoding='utf-8', errors='replace'), 1):
        code = line.split(';')[0]
        m = FORBIDDEN.search(code)
        if m:
            bad += 1
            print('%s:%d: %s   <- %s' % (name, n, line.rstrip(), m.group(1)))
print('Schichten: %s' % ('OK' if not bad else '%d Verstoesse' % bad))
sys.exit(1 if bad else 0)
