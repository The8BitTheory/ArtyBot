#!/usr/bin/env python3
"""sim_winter.py - plays the whole game flow in tools/c64sim.py, with screenshots.

  python -B tools/sim_winter.py build/roboter.prg out/prefix

Solves the 5 meadow levels (walking on the world map), the gate blinks open,
through the gate into winter, back through the archway, F5 forward again,
solves the 5 winter levels and walks to the winter gate (no world behind it).
The level programs come from tools/solve_levels.py. Needs Test.map (labels)."""
import sys, os
from collections import deque
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from c64sim import C64
import gen_world_maps as W

K = dict(w=9, s=13, d=18, a=10, q=62, e=14, x=23, z=12, c=20)
SPACE, F1, F5, F3 = 60, 4, 6, 5
PROGS = {
    0: 'wzdqxedzaqxeazdqxe',
    1: 'zqzcsdwqwazeazzawqxc',
    2: 'wdsaqazcdwzzdqxzc',
    3: 'aqxessaqwcqaedwqwcqsezaqcxzqwdc',
    4: 'wdsaqazzexqzazzdezwdqdwzzeaqazacdqawzdcdqwdzwde',   # key level (SOLVE_W=4, not the shortest)
    5: 'wdqazzcxzqxcssaqsdzzcaqzdc',
    6: 'awqsdcsdzqssazzdedqazazdcdzdqdzwae',
    7: 'wdwqawcawzaqssacazzdqzwdwc',
    8: 'azaqsxessdzzqssdssae',
    9: 'wdsdqsdssedwdwwazqsdsde',
}
prg = open(sys.argv[1], 'rb').read(); out = sys.argv[2]
lbl = {}
for line in open(os.path.join(os.path.dirname(os.path.abspath(sys.argv[1])), '..', 'Test.map')):
    if '=$' in line:
        n, v = line.split('=$'); lbl[n.strip()] = int(v.split(';')[0].strip(), 16)
m = C64(prg)
MAPS = [W.parse(n, a, i) for i, (n, a) in enumerate(W.WORLDS)]   # (cells, nodes)
ok = True

def press(k, hold=3, after=6):
    m.keys.add(k); m.run_frames(hold); m.keys.discard(k); m.run_frames(after)
def shot(n): m.render(2).save('%s_%s.png' % (out, n))
def world(): return m.ram[0x7A]
def pos(): return (m.ram[0x70], m.ram[0x71])
def check(cond, what):
    global ok
    print(('ok   ' if cond else 'FAIL ') + what)
    ok = ok and cond

def walk_to(targets, passable):
    """BFS over the map of the current world, then press WASD along the path."""
    cells = MAPS[world()][0]
    start = pos()
    prev = {start: None}; q = deque([start])
    goal = None
    while q:
        c = q.popleft()
        if c in targets: goal = c; break
        for k, (dx, dy) in dict(d=(1, 0), a=(-1, 0), w=(0, -1), s=(0, 1)).items():
            n = (c[0] + dx, c[1] + dy)
            if n not in prev and 0 <= n[0] < W.COLS and 0 <= n[1] < W.ROWS and cells[n[1] * W.COLS + n[0]] in passable:
                prev[n] = (c, k); q.append(n)
    assert goal is not None, 'no way from %s to %s' % (start, targets)
    keys = []
    while prev[goal]:
        goal, k = prev[goal][0], prev[goal][1]; keys.append(k)
    w0 = world()
    for k in keys[::-1]:
        press(K[k], 2, 10)
        if world() != w0: break
    m.run_frames(15)

def node_cell(i): return MAPS[world()][1][i]

def play(level, local):
    walk_to({node_cell(local)}, (6,))
    press(SPACE); m.run_frames(20)
    for ch in PROGS[level]: press(K[ch], 2, 4)
    if level in (0, 4, 5, 8): shot('plan_L%d' % (level + 1))
    press(F1); m.run_frames(20)
    press(SPACE)
    for _ in range(120):
        m.run_frames(20)
        if m.ram[0x47] in (2, 4): break
    check(m.ram[0x47] == 4, 'level %d solved (run_state %d)' % (level + 1, m.ram[0x47]))
    if level in (0, 4, 5, 8, 9): shot('run_L%d' % (level + 1))
    m.run_frames(110)
    press(SPACE, 3, 3); m.run_frames(30)

m.run_frames(40)
shot('01_start')
for i in range(5): play(i, i)
m.run_frames(150)          # gate blinks
check(m.ram[lbl['gate_done']] & 1, 'meadow gate opened')
shot('02_gate_open')
walk_to({(4, 0), (5, 0)}, (6, 7, 8))
check(world() == 1, 'through the gate into world 2')
check(m.ram[lbl['worlds_open']] == 2, 'worlds_open = 2')
m.run_frames(10); shot('03_winter')
walk_to({n for n in [(0, 8)]}, (6, 9))
check(world() == 0, 'back through the archway into world 1')
check(pos() in ((4, 1), (5, 1)), 'robot stands in front of the gate %s' % (pos(),))
m.run_frames(10); shot('04_back_in_meadow')
press(F5); m.run_frames(20)
check(world() == 1 and pos() == (1, 8), 'F5 -> winter, robot in front of the archway %s' % (pos(),))
press(F3); m.run_frames(20)
check(world() == 0, 'F3 -> meadow')
press(F5); m.run_frames(20)
for i in range(5): play(5 + i, i)
m.run_frames(150)
check(m.ram[lbl['gate_done']] & 2, 'winter gate opened')
shot('05_winter_gate_open')
walk_to({(15, 0), (16, 0)}, (6, 7, 8))
m.run_frames(10); shot('06_winter_end')
check(world() == 1, 'no world behind the winter gate: stays in winter')
print('RESULT', 'ALL OK' if ok else 'FAILED')
sys.exit(0 if ok else 1)
