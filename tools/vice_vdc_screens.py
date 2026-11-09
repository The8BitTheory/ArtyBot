#!/usr/bin/env python3
"""vice_vdc_screens.py - Bilder der VDC-Bildschirme (Titel, Anleitung, Credits, Ende) aus echtem
x128 (headless, Binary Monitor), Tasten wie in vice_smoke.py ueber den Checkpoint in input_update.

  python3 -B tools/vice_vdc_screens.py X128 PRG LABELS OUTDIR [VICE-DATA-DIR]

Bilder: OUTDIR/v01_title.png, v02_hover.png, v03_instr.png, v04_credits.png, v05_end.png,
v06_map.png, v07_walk.png, v08_stats.png, v09_map_back.png
(VDC-Bild, Zeilen verdoppelt)."""
import sys, os, subprocess
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from vice_bm import BM

emu, prg, labf, out = sys.argv[1:5]
data = sys.argv[5] if len(sys.argv) > 5 else None
os.makedirs(out, exist_ok=True)
lab = {}
for l in open(labf):
    p = l.split('=')
    if len(p) == 2 and p[1].strip().startswith('$'):
        lab[p[0].strip()] = int(p[1].split(';')[0].strip().lstrip('$'), 16)
KEY_HOOK = lab['input_update'] + 6
KEY_SHIFT = lab['key_shift']
KEY_2, KEY_3, SPACE = 59, 8, 60
MX_LO, MX_HI, MY = lab['mouse_x_lo'], lab['mouse_x_hi'], lab['mouse_y']

port = 6502 + (os.getpid() % 1000)
args = [emu, '-default', '-warp', '-sounddev', 'dummy', '-binarymonitor',
        '-binarymonitoraddress', 'ip4://127.0.0.1:%d' % port, '-autostart', prg]
if data: args[2:2] = ['-directory', data]
log = open(os.path.join(out, 'vdc.log'), 'w')
vice = subprocess.Popen(args, stdout=log, stderr=subprocess.STDOUT)
bm = BM(port=port, timeout=30)
bm.checkpoint(KEY_HOOK)
bm.resume()


def tick(key=0xFF, action=None):
    bm.wait_checkpoint()
    r = action() if action else None
    if key != 0xFF:
        bm.set_regs(A=key)
        bm.mem_set(KEY_SHIFT, [0])
    bm.resume()
    return r


def wait(n):
    for _ in range(n): tick()


def press(k, hold=3, after=8):
    for _ in range(hold): tick(k)
    wait(after)


def shot(name):
    tick(action=lambda: bm.save_png(os.path.join(out, name + '.png'), vicii=False, border=16, yscale=2))
    print('Bild', name)


def mouse(x, y):
    tick(action=lambda: bm.mem_set(MX_LO, [x & 255, x >> 8]) or bm.mem_set(MY, [y]))


try:
    wait(60)
    shot('v01_title')
    mouse(420, 106)              # ueber "Instructions"
    wait(4)
    shot('v02_hover')
    press(KEY_2)
    wait(10)
    shot('v03_instr')
    press(SPACE)
    wait(10)
    press(KEY_3)
    wait(10)
    shot('v04_credits')
    press(SPACE)
    wait(10)
    # Endbildschirm direkt: einige Rekorde setzen, PC auf end_mode
    def to_end():
        bm.mem_set(lab['level_cmds'], [18, 0, 0, 0, 0, 18, 0, 0, 0])
        bm.set_regs(PC=lab['end_mode'])
    tick(action=to_end)
    wait(20)
    shot('v05_end')
    RETURN, KEY_D, KEY_S, F1 = 1, 18, 13, 4
    press(RETURN); wait(20)                  # Ende -> Titel
    press(RETURN); wait(40)                  # neues Spiel -> Weltkarte
    mouse(300, 61); wait(3)
    shot('v06_map')
    for _ in range(4): tick(KEY_D)
    shot('v07_walk')
    wait(30)
    press(KEY_S); wait(20)
    press(F1); wait(20)
    shot('v08_stats')
    press(KEY_S); wait(40)
    shot('v09_map_back')
finally:
    try: bm.quit()
    except Exception: pass
    vice.kill()
