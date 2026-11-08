#!/usr/bin/env python3
"""sim_level.py - plays one level in tools/c64sim.py and checks that it is won.

  python -B tools/sim_level.py build/roboter.prg LABEL [PROGRAM] [out/prefix]

LABEL is the level label without "map", e.g. 15 (world 1, level 5). PROGRAM is the
command list as planning keys (w s d a q e x z c); without it the shortest program
of tools/solve_levels.py is used. The script starts a new game, unlocks the
worlds up to the level's world (F2 cheat + walking through the gates), walks to the
level's node on the world map, types the program, runs it and checks run_state
(4 = won). With out/prefix it saves screenshots of the world map, the plan and the won run.
Exit code 0 = won."""
import sys, os
from collections import deque
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from c64sim import C64
import gen_world_maps as W
import solve_levels as sl

K = dict(w=9, s=13, d=18, a=10, q=62, e=14, x=23, z=12, c=20)
SPACE, F1, LSHIFT = 60, 4, 15
RUN_STATE, WORLD, POS_X, POS_Y = 0x47, 0x7A, 0x70, 0x71

prg = open(sys.argv[1], 'rb').read()
label = int(sys.argv[2])
prog = sys.argv[3] if len(sys.argv) > 3 and not sys.argv[3].startswith(('out', '/', '.')) else None
out = sys.argv[-1] if len(sys.argv) > 3 and sys.argv[-1] != prog else None
if prog is None:
    p, _ = sl.solve(sl.parse_levels()[label])
    prog = ''.join(sl.KEYS[c] for c in p)
want_world, local = label // 10 - 1, label % 10 - 1
MAPS = [W.parse(n, a, i) for i, (n, a) in enumerate(W.WORLDS)]

m = C64(prg)
m.start_game()
m.run_frames(40)


def press(k, hold=3, after=6, shift=False):
    if shift: m.keys.add(LSHIFT)
    m.keys.add(k); m.run_frames(hold); m.keys.discard(k)
    if shift: m.keys.discard(LSHIFT)
    m.run_frames(after)


def shot(n):
    if out: m.render(2).save('%s_%s.png' % (out, n))


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
    assert goal is not None, 'no way from %s to %s' % (start, targets)
    keys = []
    while prev[goal]:
        goal, k = prev[goal]; keys.append(k)
    w0 = m.ram[WORLD]
    for k in keys[::-1]:
        press(K[k], 2, 10)
        if m.ram[WORLD] != w0: break
    m.run_frames(15)


while m.ram[WORLD] < want_world:         # F2 (cheat) solves the world, gate blinks, walk through
    press(F1, shift=True); m.run_frames(200)
    cells = MAPS[m.ram[WORLD]][0]
    gate = {(i % W.COLS, i // W.COLS) for i, c in enumerate(cells) if c in (7, 8)}
    walk_to(gate, (6, 7, 8))
walk_to({MAPS[m.ram[WORLD]][1][local]}, (6,))
shot('map')
press(SPACE); m.run_frames(20)
for ch in prog:
    press(K[ch], 2, 4)
shot('plan')
press(F1); m.run_frames(20)
press(SPACE)
for _ in range(200):
    m.run_frames(20)
    if m.ram[RUN_STATE] in (2, 4): break
won = m.ram[RUN_STATE] == 4
shot('run')
print('map%d %s: %s (%d commands)' % (label, 'WON' if won else 'NOT won, run_state %d' % m.ram[RUN_STATE], prog, len(prog)))
sys.exit(0 if won else 1)
