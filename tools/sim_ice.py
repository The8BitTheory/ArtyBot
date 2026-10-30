#!/usr/bin/env python3
"""sim_ice.py - tests the ice rules (winter levels 8 and 9) in tools/c64sim.py.

  python -B tools/sim_ice.py build/roboter.prg out/prefix

Gets to the winter world with the F2 test key, then plays programs on levels
8 and 9: the solutions from tools/solve_levels.py must win; skating must stop
at a pine; jumping onto / off the ice and throwing a package on it must break
the ice (broken-ice tile, run stopped); dropping on ice is refused.
Needs Test.map (labels) next to build/."""
import sys, os
from collections import deque
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from c64sim import C64
import gen_world_maps as W

K = dict(w=9, s=13, d=18, a=10, q=62, e=14, x=23, z=12, c=20)
SPACE, F1, F7, LSHIFT = 60, 4, 3, 15
DIGITS = [56, 59, 8, 11, 16, 19, 24, 27, 32]
T_ICE, T_BROKEN = 6, 7
prg = open(sys.argv[1], 'rb').read(); out = sys.argv[2]
lbl = {}
for line in open(os.path.join(os.path.dirname(os.path.abspath(sys.argv[1])), '..', 'Test.map')):
    if '=$' in line:
        n, v = line.split('=$'); lbl[n.strip()] = int(v.split(';')[0].strip(), 16)
m = C64(prg)
MAPS = [W.parse(n, a, i) for i, (n, a) in enumerate(W.WORLDS)]
ok = True

def press(keys, hold=3, after=6):
    for k in keys: m.keys.add(k)
    m.run_frames(hold)
    for k in keys: m.keys.discard(k)
    m.run_frames(after)
def check(cond, what):
    global ok
    print(('ok   ' if cond else 'FAIL ') + what); ok = ok and bool(cond)
def tile(x, y): return m.ram[0x0200 + y * 10 + x]
def robot(): return (m.ram[0x1C], m.ram[0x1D])

def walk_to(targets, passable):
    cells = MAPS[m.ram[0x7A]][0]
    start = (m.ram[0x70], m.ram[0x71])
    prev = {start: None}; q = deque([start]); goal = None
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
        press([K[k]], 2, 10)
        if m.ram[0x7A] != w0: break
    m.run_frames(15)

def run_program(local, prog):
    """Plan screen of winter level `local` (0-based), fresh list, run until it stops."""
    press([DIGITS[local]]); m.run_frames(5)
    press([LSHIFT, 51]); m.run_frames(5); press([1]); m.run_frames(5)   # Shift+CLR: clear list, Return
    for ch in prog: press([K[ch]], 2, 4)
    press([F1]); m.run_frames(20); press([SPACE])
    for _ in range(80):
        m.run_frames(20)
        if m.ram[0x47] in (2, 4): break
    return m.ram[0x47]

def back_to_plan():
    if m.ram[0x47] == 4:
        m.run_frames(110)
    press([F1]); m.run_frames(20)

m.run_frames(40)
press([LSHIFT, F1]); m.run_frames(130)          # F2: meadow solved, gate opens
walk_to({(15, 0), (16, 0), (4, 0), (5, 0)}, (6, 7, 8))
check(m.ram[0x7A] == 1, 'in the winter world')
press([SPACE]); m.run_frames(20)                 # node 1 -> plan of level 5

st = run_program(3, 'w')
check(st == 0 or st == 2 or st == 4, 'L8: skate run finished (state %d)' % st)
check(robot() == (4, 4), 'L8: skating stops in front of the pine on the ice %s' % (robot(),))
check(tile(4, 4) == T_ICE, 'L8: the robot stands on intact ice')
m.render(2).save(out + '_1_skate_stop.png'); back_to_plan()

st = run_program(3, 'z')
check(st == 2 and tile(3, 4) == T_BROKEN and m.ram[lbl['run_sunk']] == 1,
      'L8: jump onto the ice breaks it (state %d, tile %d)' % (st, tile(3, 4)))
m.render(2).save(out + '_2_jump_on_ice.png'); back_to_plan()

st = run_program(3, 'wz')
check(st == 2 and tile(4, 4) == T_BROKEN, 'L8: jump off the ice breaks it (state %d, tile %d)' % (st, tile(4, 4)))
back_to_plan()

st = run_program(3, 'awwaqxc')
check(st == 2 and tile(3, 2) == T_BROKEN and m.ram[lbl['run_sunk']] == 0 and m.ram[0x4C] == 0,
      'L8: package thrown onto the ice breaks it, package gone (tile %d)' % tile(3, 2))
m.render(2).save(out + '_3_throw_on_ice.png'); back_to_plan()

st = run_program(3, 'awwaqxe')
check(st == 2 and tile(2, 2) == T_ICE and m.ram[0x4C] == 1, 'L8: drop on the ice is refused (state %d)' % st)
back_to_plan()

st = run_program(3, 'azaqsxessdzzqssdssae')
check(st == 4, 'L8: solution wins (state %d)' % st)
m.render(2).save(out + '_4_L8_won.png'); back_to_plan()

st = run_program(4, 'awwwwwwdw')
check(st == 2 and m.ram[lbl['run_sunk']] == 1 and robot() == (6, 3),
      'L9: skating into open water drowns the robot (state %d, robot %s)' % (st, robot()))
m.render(2).save(out + '_5_drown.png'); back_to_plan()

st = run_program(4, 'wdsdqsdssedwdwwazqsdsde')
check(st == 4, 'L9: solution wins (state %d)' % st)
m.render(2).save(out + '_6_L9_won.png')
print('RESULT', 'ALL OK' if ok else 'FAILED')
sys.exit(0 if ok else 1)
