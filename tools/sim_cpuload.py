#!/usr/bin/env python3
"""sim_cpuload.py - misst im Simulator die CPU-Last pro Frame waehrend eines Levellaufs:
Anteil der Zeit ausserhalb der Warteschleife von wait_frame (Mittel und Maximum).
  python -B tools/sim_cpuload.py build/roboter.prg labels.txt [LEVEL]
Taktzahlen sind die Naeherung von c64sim (3 Takte pro Befehl) - fuer Vergleiche vorher/nachher."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from c128sim import machine
import solve_levels as sl
import gen_world_maps as W

prg = open(sys.argv[1], 'rb').read()
lab = {}
for l in open(sys.argv[2]):
    p = l.split('=')
    if len(p) == 2 and p[1].strip().startswith('$'):
        lab[p[0].strip()] = int(p[1].split(';')[0].strip().lstrip('$'), 16)
label = int(sys.argv[3]) if len(sys.argv) > 3 else 22
wf = lab['wait_frame']
WAIT = range(wf + 2, wf + 6)          # .w: cmp frame / beq .w
K = dict(w=9, s=13, d=18, a=10, q=62, e=14, x=23, z=12, c=20)

m = machine(prg)
m.start_game(); m.run_frames(40)
MAPS = [W.parse(n, a, i) for i, (n, a) in enumerate(W.WORLDS)]


def press(k, hold=3, after=6, shift=False):
    if shift: m.keys.add(15)
    m.keys.add(k); m.run_frames(hold); m.keys.discard(k)
    if shift: m.keys.discard(15)
    m.run_frames(after)


from collections import deque


def walk_to(targets, passable):
    cells = MAPS[m.ram[0x7A]][0]
    start = (m.ram[0x70], m.ram[0x71]); prev = {start: None}; q = deque([start]); goal = None
    while q:
        c = q.popleft()
        if c in targets: goal = c; break
        for k, (dx, dy) in dict(d=(1, 0), a=(-1, 0), w=(0, -1), s=(0, 1)).items():
            n = (c[0] + dx, c[1] + dy)
            if n not in prev and 0 <= n[0] < W.COLS and 0 <= n[1] < W.ROWS and cells[n[1] * W.COLS + n[0]] in passable:
                prev[n] = (c, k); q.append(n)
    keys = []
    while prev[goal]:
        goal, k = prev[goal]; keys.append(k)
    w0 = m.ram[0x7A]
    for k in keys[::-1]:
        press(K[k], 2, 10)
        if m.ram[0x7A] != w0: break
    m.run_frames(15)


while m.ram[0x7A] < label // 10 - 1:
    press(4, shift=True); m.run_frames(200)
    cells = MAPS[m.ram[0x7A]][0]
    walk_to({(i % W.COLS, i // W.COLS) for i, c in enumerate(cells) if c in (7, 8)}, (6, 7, 8))
walk_to({MAPS[m.ram[0x7A]][1][label % 10 - 1]}, (6,))
press(60); m.run_frames(20)
p, _ = sl.solve(sl.parse_levels()[label])
for ch in ''.join(sl.KEYS[c] for c in p): press(K[ch], 2, 4)
press(4); m.run_frames(20)
press(60)

# Messung: pro Frame Takte ausserhalb der Warteschleife
step0 = m.step
busy = [0]; waiting = [0]
def step():
    c0 = m.cycles; pc = m.pc
    step0()
    (waiting if pc in WAIT else busy)[0] += m.cycles - c0
m.step = step
loads = []
for _ in range(400):
    busy[0] = waiting[0] = 0
    m.run_frames(1)
    tot = busy[0] + waiting[0]
    if tot: loads.append(100.0 * busy[0] / tot)
    if m.ram[0x47] in (2, 4): break
print('map%d: %d Frames, Last Mittel %.1f %%, Maximum %.1f %%' % (label, len(loads), sum(loads) / len(loads), max(loads)))
