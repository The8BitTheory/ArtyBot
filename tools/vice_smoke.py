#!/usr/bin/env python3
"""vice_smoke.py - Ablauf mit echtem VICE (headless) ueber den Binary Monitor.

  python3 -B tools/vice_smoke.py EMU PRG LABELS OUTDIR [VICE-DATA-DIR]
  EMU = Pfad zu x64sc oder x128, LABELS = acme -l Ausgabe des PRG

Tasten: VICE-headless hat keine Tastatur, und "keybuf" fuellt nur den KERNAL-Puffer. Der
Test setzt deshalb einen Checkpoint auf "sta key_now" in input_update (direkt nach
key_scan) und legt dort den gewuenschten Matrixcode in den Akku. Alles danach laeuft im
Emulator echt (VIC-II, MMU, Timing); nur das Abfragen der Matrix wird uebersprungen.
Ein Checkpoint-Treffer = ein Durchlauf einer Hauptschleife = ein Frame.
Ausgabe: OUTDIR/*.png (VIC-II-Bild mit Rand) und OUTDIR/run.log."""
import sys, os, subprocess, time
from collections import deque
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from vice_bm import BM, EV_STOPPED, EV_JAM
import gen_world_maps as W
import solve_levels as sl

emu, prg, labf, out = sys.argv[1:5]
data = sys.argv[5] if len(sys.argv) > 5 else None
os.makedirs(out, exist_ok=True)
lab = {}
for l in open(labf):
    p = l.split('=')
    if len(p) == 2 and p[1].strip().startswith('$'):
        lab[p[0].strip()] = int(p[1].split(';')[0].strip().lstrip('$'), 16)
KEY_HOOK = lab['input_update'] + 6        # jsr mouse_update / jsr key_scan / sta key_now
KEY_SHIFT = lab['key_shift']
K = dict(w=9, s=13, d=18, a=10, q=62, e=14, x=23, z=12, c=20)
SPACE, RETURN, F1, F7 = 60, 1, 4, 3
KEY_1, KEY_2, KEY_3 = 56, 59, 8
RUN_STATE, WORLD, POS_X, POS_Y = 0x47, 0x7A, 0x70, 0x71
log = open(os.path.join(out, 'run.log'), 'w')

port = 6502 + (os.getpid() % 1000)
args = [emu, '-default', '-warp', '-sounddev', 'dummy', '-binarymonitor',
        '-binarymonitoraddress', 'ip4://127.0.0.1:%d' % port, '-autostart', prg]
if data: args[2:2] = ['-directory', data]   # nach -default, sonst ueberschrieben
vice = subprocess.Popen(args, stdout=log, stderr=subprocess.STDOUT)
bm = BM(port=port, timeout=30)
bm.checkpoint(KEY_HOOK)
bm.resume()
ticks = 0


def tick(key=0xFF, shift=0, action=None):
    """Laeuft bis zum naechsten input_update (Checkpoint); dort optional action() ausfuehren
    (Speicher lesen, Bild holen), den Tastencode setzen und weiterlaufen lassen."""
    global ticks
    bm.wait_checkpoint()
    r = action() if action else None
    if key != 0xFF:
        bm.set_regs(A=key)
        bm.mem_set(KEY_SHIFT, [shift])
    ticks += 1
    bm.resume()
    return r


def wait(n):
    for _ in range(n): tick()


def press(k, hold=3, after=6, shift=0):
    for _ in range(hold): tick(k, shift)
    wait(after)


def ram(a, n=1):
    return tick(action=lambda: bm.mem_get(a, a + n - 1))


def shot(name):
    tick(action=lambda: bm.save_png(os.path.join(out, name + '.png')))
    print('  Bild', name, file=log); log.flush()


MAPS = [W.parse(n, a, i) for i, (n, a) in enumerate(W.WORLDS)]


def walk_to(targets, passable):
    st = ram(WORLD, 1)[0]; pos = ram(POS_X, 2)
    cells = MAPS[st][0]
    start = (pos[0], pos[1]); prev = {start: None}; q = deque([start]); goal = None
    while q:
        c = q.popleft()
        if c in targets: goal = c; break
        for k, (dx, dy) in dict(d=(1, 0), a=(-1, 0), w=(0, -1), s=(0, 1)).items():
            n = (c[0] + dx, c[1] + dy)
            if n not in prev and 0 <= n[0] < W.COLS and 0 <= n[1] < W.ROWS and cells[n[1] * W.COLS + n[0]] in passable:
                prev[n] = (c, k); q.append(n)
    assert goal is not None, 'kein Weg von %s nach %s' % (start, targets)
    keys = []
    while prev[goal]:
        goal, k = prev[goal]; keys.append(k)
    for k in keys[::-1]:
        press(K[k], 2, 10)
    wait(15)


def open_next_world():
    press(F1, shift=1); wait(200)          # F2: Welt geloest, Tor blinkt
    w = ram(WORLD, 1)[0]
    cells = MAPS[w][0]
    walk_to({(i % W.COLS, i // W.COLS) for i, c in enumerate(cells) if c in (7, 8)}, (6, 7, 8))


def solution(label):
    p, _ = sl.solve(sl.parse_levels()[label])
    return ''.join(sl.KEYS[c] for c in p)


def run_level(label, mid):
    w = ram(WORLD, 1)[0]
    walk_to({MAPS[w][1][label % 10 - 1]}, (6,))
    press(SPACE); wait(20)
    for ch in solution(label): press(K[ch], 2, 4)
    shot(mid + '_plan')
    press(F1); wait(20)
    press(SPACE); wait(30)
    shot(mid + '_run')
    for _ in range(200):
        if ram(RUN_STATE, 1)[0] in (2, 4): break
        wait(10)
    st = ram(RUN_STATE, 1)[0]
    wait(150)
    shot(mid + '_won')
    print('map%d: run_state %d (%s)' % (label, st, 'gewonnen' if st == 4 else 'NICHT gewonnen'), file=log)
    return st == 4


ok = True
try:
    wait(60); shot('01_title')
    press(KEY_2); wait(20); shot('02_instr1')
    press(SPACE); wait(20); shot('03_instr2')
    press(SPACE); wait(20)
    press(KEY_3); wait(20); shot('04_credits')
    press(SPACE); wait(30)
    press(KEY_1); wait(40); shot('05_map')
    press(F1); wait(20); shot('06_stats')
    press(SPACE); wait(20)
    ok &= run_level(11, '07_meadow1')
    press(SPACE); wait(60); shot('08_map_after')
    open_next_world(); wait(30); shot('09_winter')
    ok &= run_level(21, '10_winter1')
    press(F7); wait(40)
    open_next_world(); wait(80); shot('11_end')
    press(RETURN); wait(60); shot('12_title_again')
except Exception as e:
    ok = False
    print('FEHLER:', repr(e), file=log)
finally:
    print('%s nach %d Frames' % ('OK' if ok else 'FEHLER', ticks), file=log)
    log.close()
    try: bm.quit()
    except Exception: pass
    time.sleep(0.5)
    vice.kill()
print(open(os.path.join(out, 'run.log')).read().strip().split('\n')[-1])
sys.exit(0 if ok else 1)
