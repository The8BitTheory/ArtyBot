#!/usr/bin/env python3
"""sim_vdc_levels.py - alle Levels im VDC-Ziel (c128sim mit VDC-Modell) mit der Solver-Loesung.

  python3 -B tools/sim_vdc_levels.py PRG OUTDIR [SOLUTIONS.txt]

Wie Ablauf 2 von sim_regress.py, aber fuer den gemeinsamen Plan-/Run-Bildschirm: Space startet
den Lauf sofort. Je Level ein Bild in 4:3 (OUTDIR/V<n>.png); Ausgabe WON / NOT won."""
import sys, os
from collections import deque
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from c128sim import C128
from PIL import Image
import gen_world_maps as W
import solve_levels as sl

K = dict(w=9, s=13, d=18, a=10, q=62, e=14, x=23, z=12, c=20)
SPACE, RETURN, F1, LSHIFT = 60, 1, 4, 15
RUN_STATE, WORLD, POS_X, POS_Y = 0x47, 0x7A, 0x70, 0x71
prg = open(sys.argv[1], 'rb').read()
out = sys.argv[2]
os.makedirs(out, exist_ok=True)
solf = sys.argv[3] if len(sys.argv) > 3 else None
SOL = dict(l.split() for l in open(solf)) if solf and os.path.exists(solf) else {}
MAPS = [W.parse(n, a, i) for i, (n, a) in enumerate(W.WORLDS)]
LEVELS = sl.parse_levels()
_resf = os.path.join(os.path.dirname(os.path.abspath(sys.argv[1])), 'artybot.gfx')
RES = open(_resf, 'rb').read() if os.path.exists(_resf) else None   # Ressource neben dem PRG
m = None


def press(k, hold=3, after=6, shift=False):
    if shift: m.keys.add(LSHIFT)
    m.keys.add(k); m.run_frames(hold); m.keys.discard(k); m.keys.discard(LSHIFT); m.run_frames(after)


def walk_to(targets, passable):
    cells = MAPS[m.ram[WORLD]][0]
    start = (m.ram[POS_X], m.ram[POS_Y])
    prev = {start: None}; q = deque([start]); goal = None
    while q:
        c = q.popleft()
        if c in targets: goal = c; break
        for k, (dx, dy) in dict(d=(1, 0), a=(-1, 0), w=(0, -1), s=(0, 1)).items():
            n = (c[0] + dx, c[1] + dy)
            if n not in prev and 0 <= n[0] < W.COLS and 0 <= n[1] < W.ROWS and cells[n[1] * W.COLS + n[0]] in passable:
                prev[n] = (c, k); q.append(n)
    assert goal is not None
    keys = []
    while prev[goal]:
        goal, k = prev[goal]; keys.append(k)
    w0 = m.ram[WORLD]
    for k in keys[::-1]:
        press(K[k], 2, 12)
        if m.ram[WORLD] != w0: break
    m.run_frames(20)


def solution(label):
    key = 'map%d' % label
    if key not in SOL:
        r = sl.solve(LEVELS[label])
        if r[0] is None: r = sl.solve_greedy(LEVELS[label])
        SOL[key] = ''.join(sl.KEYS[c] for c in r[0])
    return SOL[key]


won = 0
for label in sorted(LEVELS):
    world, local = label // 10 - 1, label % 10 - 1
    m = C128(prg, RES)
    m.run_frames(60); press(RETURN, after=60)
    while m.ram[WORLD] < world:
        press(F1, shift=True); m.run_frames(200)
        cells = MAPS[m.ram[WORLD]][0]
        walk_to({(i % W.COLS, i // W.COLS) for i, c in enumerate(cells) if c in (7, 8)}, (6, 7, 8))
        m.run_frames(60)
    walk_to({MAPS[m.ram[WORLD]][1][local]}, (6,))
    press(SPACE, after=60)
    for ch in solution(label):
        press(K[ch], 2, 6)
    press(SPACE, after=20)
    for _ in range(400):
        m.run_frames(10)
        if m.ram[RUN_STATE] in (2, 4): break
    st = m.ram[RUN_STATE]
    m.render_vdc(yscale=1).resize((640, 480), Image.NEAREST).save(os.path.join(out, 'V%d.png' % label))
    won += st == 4
    print('map%d %s' % (label, 'WON' if st == 4 else 'NOT won (%d)' % st), flush=True)
print('%d/%d gewonnen' % (won, len(LEVELS)))
