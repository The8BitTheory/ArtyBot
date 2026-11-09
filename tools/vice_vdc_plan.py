#!/usr/bin/env python3
"""vice_vdc_plan.py - gemeinsamer Plan-/Run-Bildschirm in echtem x128 (headless, Binary Monitor).

  python3 -B tools/vice_vdc_plan.py X128 PRG LABELS OUTDIR [VICE-DATA-DIR]

Weltkarte -> Level 1, Befehle tippen, Lauf (Space), waehrend des Laufs editieren, Level loesen.
Bilder in 4:3 (640x480): w01_plan, w02_typed, w03_running, w04_edit, w05_won."""
import sys, os, subprocess
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from vice_bm import BM
from PIL import Image

emu, prg, labf, out = sys.argv[1:5]
data = sys.argv[5] if len(sys.argv) > 5 else None
os.makedirs(out, exist_ok=True)
lab = {}
for l in open(labf):
    p = l.split('=')
    if len(p) == 2 and p[1].strip().startswith('$'):
        lab[p[0].strip()] = int(p[1].split(';')[0].strip().lstrip('$'), 16)
KEY_HOOK = lab['input_update'] + 6
K = dict(w=9, s=13, d=18, a=10, q=62, e=14, x=23, z=12, c=20)
SPACE, RETURN, F1 = 60, 1, 4
SOL11 = 'wwdwqsswdwwqsswwdwwq'   # Platzhalter, wird unten aus solutions.txt ersetzt
port = 6502 + (os.getpid() % 1000)
args = [emu, '-default', '-warp', '-sounddev', 'dummy', '-binarymonitor',
        '-binarymonitoraddress', 'ip4://127.0.0.1:%d' % port, '-autostart', prg]
if data: args[2:2] = ['-directory', data]
vice = subprocess.Popen(args, stdout=open(os.path.join(out, 'plan.log'), 'w'), stderr=subprocess.STDOUT)
bm = BM(port=port, timeout=30)
bm.checkpoint(KEY_HOOK)
bm.resume()


def tick(key=0xFF, action=None):
    bm.wait_checkpoint()
    r = action() if action else None
    if key != 0xFF:
        bm.set_regs(A=key)
        bm.mem_set(lab['key_shift'], [0])
    bm.resume()
    return r


def wait(n):
    for _ in range(n): tick()


def press(k, hold=2, after=6):
    for _ in range(hold): tick(k)
    wait(after)


def shot(name):
    p = os.path.join(out, name + '.png')
    tick(action=lambda: bm.save_png(p, vicii=False, border=0, yscale=1))
    Image.open(p).resize((640, 480), Image.NEAREST).save(p)
    print('Bild', name, flush=True)


def ram(a):
    return tick(action=lambda: bm.mem_get(a, a)[0])


try:
    wait(60); press(RETURN, after=40)
    for _ in range(3): press(K['a'], after=12)
    press(SPACE, after=40); shot('w01_plan')
    for ch in 'wwdw': press(K[ch], after=4)
    shot('w02_typed')
    press(SPACE, after=30); shot('w03_running')
    press(K['q'], after=30); shot('w04_edit')
    sol = sys.argv[6] if len(sys.argv) > 6 else None
    if sol:
        for _ in range(6): press(0, after=4)            # Del: Rueckfrage, Return
        press(RETURN, after=4)
    print('editor_count', ram(lab['editor_count']), 'state', ram(0x47))
finally:
    try: bm.quit()
    except Exception: pass
    vice.kill()
