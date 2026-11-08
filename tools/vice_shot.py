#!/usr/bin/env python3
"""vice_shot.py - startet ein PRG in VICE (headless), wartet und speichert ein Bild.

  python3 -B tools/vice_shot.py EMU PRG OUT.png [SEKUNDEN] [vdc|vic] [VICE-DATA-DIR]

vdc: Bild des VDC (x128, 80 Zeichen), im Seitenverhaeltnis 1:2 gestreckt; vic: VIC-II.
Laeuft mit -warp; SEKUNDEN = Echtzeit bis zum Bild (Standard 6)."""
import sys, os, subprocess, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from vice_bm import BM

emu, prg, out = sys.argv[1:4]
secs = float(sys.argv[4]) if len(sys.argv) > 4 else 6
which = sys.argv[5] if len(sys.argv) > 5 else 'vdc'
data = sys.argv[6] if len(sys.argv) > 6 else None
port = 6502 + (os.getpid() % 1000)
args = [emu, '-default', '-warp', '-sounddev', 'dummy', '-binarymonitor',
        '-binarymonitoraddress', 'ip4://127.0.0.1:%d' % port, '-autostart', prg]
if data: args[2:2] = ['-directory', data]
log = open(out + '.log', 'w')
vice = subprocess.Popen(args, stdout=log, stderr=subprocess.STDOUT)
try:
    bm = BM(port=port, timeout=30)
    bm.resume()
    time.sleep(secs)
    vdc = which == 'vdc'
    bm.save_png(out, vicii=not vdc, border=16, yscale=2 if vdc else 1)
    print('Bild:', out)
finally:
    try: bm.quit()
    except Exception: pass
    time.sleep(0.3)
    vice.kill()
