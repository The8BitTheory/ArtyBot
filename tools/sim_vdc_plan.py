#!/usr/bin/env python3
"""sim_vdc_plan.py - gemeinsamer Plan-/Run-Bildschirm im Simulator (c128sim mit VDC-Modell).

  python3 -B tools/sim_vdc_plan.py PRG LABELS OUTDIR

Weltkarte -> Level 1, Befehle eingeben, laufen lassen, waehrend des Laufs editieren.
Bilder in 4:3 (640x480, Zeilen gestreckt wie auf dem Monitor): p01.. ."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from c128sim import C128
from PIL import Image

prg, labf, out = sys.argv[1:4]
os.makedirs(out, exist_ok=True)
lab = {}
for l in open(labf):
    p = l.split('=')
    if len(p) == 2 and p[1].strip().startswith('$'):
        lab[p[0].strip()] = int(p[1].split(';')[0].strip().lstrip('$'), 16)
m = C128(open(prg, 'rb').read())
K = dict(w=9, s=13, d=18, a=10, q=62, e=14, x=23, z=12, c=20, r=17, p=41)
SPACE, RETURN, F1, DEL = 60, 1, 4, 0


def press(k, frames=3, after=8):
    m.keys.add(k); m.run_frames(frames); m.keys.discard(k); m.run_frames(after)


def shot(name):
    m.render_vdc(yscale=1).resize((640, 480), Image.NEAREST).save(os.path.join(out, name + '.png'))
    print('Bild', name)


def mouse(x, y):
    m.ram[lab['mouse_x_lo']] = x & 255; m.ram[lab['mouse_x_hi']] = x >> 8; m.ram[lab['mouse_y']] = y


m.run_frames(60); press(RETURN, after=60)              # Titel -> Weltkarte
mouse(600, 190)
for _ in range(3): press(K['a'], after=12)              # nach links zu Level 1
press(SPACE, after=60); shot('p01_plan')
for ch in 'wwdw': press(K[ch], after=6)
mouse(400, 120); m.run_frames(5); shot('p02_typed')
press(SPACE, after=50); shot('p03_running')
press(K['q'], after=40); shot('p04_edit_stops_run')
press(SPACE, after=400); shot('p05_run_end')
print('editor_count', m.ram[lab['editor_count']], 'run_state', m.ram[0x47])
