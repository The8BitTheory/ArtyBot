#!/usr/bin/env python3
"""Kachelvorschau: zeichnet die Planungs-Kacheln aus gen_plan_tiles.py vergroessert
mit den C64-Farben des Simulators.  Aufruf: python -B tools/sheet.py [ausgabe.png]
(Standard: build/sheet.png)"""
import sys, os
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from PIL import Image
from c64sim import RGB
import gen_plan_tiles as t
out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', 'build', 'sheet.png')
COL = {'.': RGB[0], 'g': RGB[5], 'l': RGB[13]}
CC = {'robot': RGB[1], 'goal': RGB[3], 'package': RGB[2], 'blocker': RGB[2], 'flowers': RGB[7], 'water': RGB[6]}
Z = 14
im = Image.new('RGB', (len(t.tiles) * (8 * Z + 10) + 10, 8 * Z + 20), (0, 0, 0))
for i, (name, rows) in enumerate(t.tiles):
    cc = RGB[1]
    for k, v in CC.items():
        if k in name: cc = v
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            col = cc if ch == 'c' else COL[ch]
            for dx in range(2 * Z):
                for dy in range(Z):
                    im.putpixel((10 + i * (8 * Z + 10) + x * 2 * Z + dx, 10 + y * Z + dy), col)
im.save(out)
print('geschrieben:', out)
