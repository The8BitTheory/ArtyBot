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
hook = lab['input_update'] + 6           # sicherer Punkt (kein IRQ): sta key_now
while m.pc != hook: m.step()
m.pc = lab['end_mode']; m.run_frames(40); shot("s05_end")
RETURN, KEY_D, KEY_S, F1 = 1, 18, 13, 4
press(RETURN); m.run_frames(30)               # Ende -> Titel
press(RETURN); m.run_frames(60); mouse(300, 61); m.run_frames(3); shot('s06_map')
m.keys.add(KEY_D); m.run_frames(4); shot('s07_walk'); m.keys.discard(KEY_D); m.run_frames(30)
press(KEY_S); m.run_frames(30); shot('s08_map2')
press(F1); m.run_frames(40); shot('s09_stats')
press(KEY_S); m.run_frames(60); shot('s10_map_back')
F5, LSHIFT = 5, 15
m.keys.update({LSHIFT, F1}); m.run_frames(3); m.keys.difference_update({LSHIFT, F1}); m.run_frames(150)
shot('s11_cheat')
press(9); m.run_frames(120); shot('s12_winter')
