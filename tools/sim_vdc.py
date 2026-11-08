#!/usr/bin/env python3
"""sim_vdc.py - Bilder der VDC-Bildschirme im Simulator (tools/c128sim.py mit VDC-Modell).

  python3 -B tools/sim_vdc.py PRG LABELS OUTDIR

Bilder: s01_title, s02_hover, s03_instr, s04_credits, s05_end (.png, 640x400). Schneller als
VICE (tools/vice_vdc_screens.py), Zeichensatz aus c64sim (Ersatzschrift)."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from c128sim import C128

prg, labf, out = sys.argv[1:4]
os.makedirs(out, exist_ok=True)
lab = {}
for l in open(labf):
    p = l.split('=')
    if len(p) == 2 and p[1].strip().startswith('$'):
        lab[p[0].strip()] = int(p[1].split(';')[0].strip().lstrip('$'), 16)
m = C128(open(prg, 'rb').read())
KEY_2, KEY_3, SPACE = 59, 8, 60


def press(k, frames=3):
    m.keys.add(k); m.run_frames(frames); m.keys.discard(k); m.run_frames(8)


def shot(name):
    m.render_vdc().save(os.path.join(out, name + '.png')); print('Bild', name)


def mouse(x, y):
    m.ram[lab['mouse_x_lo']] = x & 255; m.ram[lab['mouse_x_hi']] = x >> 8; m.ram[lab['mouse_y']] = y


m.run_frames(60); shot('s01_title')
mouse(420, 106); m.run_frames(10); shot('s02_hover')
press(KEY_2); m.run_frames(40); shot('s03_instr')
press(SPACE); press(KEY_3); m.run_frames(40); shot('s04_credits')
press(SPACE)
for i, v in enumerate([18, 0, 0, 0, 0, 18]): m.ram[lab['level_cmds'] + i] = v
m.pc = lab['end_mode']; m.run_frames(40); shot("s05_end")
