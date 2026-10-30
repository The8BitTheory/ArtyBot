#!/usr/bin/env python3
"""sim_world.py - plays the world-map flow in tools/c64sim.py and saves screenshots.

  python -B tools/sim_world.py build/roboter.prg out/prefix

Start (world map) -> Space on node 1 -> plan: enters the 18-command solution of
level 1 -> F1 run -> Space -> waits for the fanfare -> Space (world map, node 1
is a gold chest) -> walks to node 2 -> Space (plan of level 2) -> F7 (map)."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from c64sim import C64

K = dict(W=9, A=10, S=13, D=18, Q=62, E=14, X=23, Z=12, SPACE=60, RETURN=1, F1=4, F7=3)
prg = open(sys.argv[1], 'rb').read()
out = sys.argv[2]
m = C64(prg)


def press(k, hold=3, after=6):
    m.keys.add(K[k]); m.run_frames(hold); m.keys.discard(K[k]); m.run_frames(after)


def shot(name):
    m.render(2).save('%s_%s.png' % (out, name))


def state(tag):
    r = m.ram
    print('%-10s frame %5d  level %d  world %d  map cell %d,%d  node %d  run_state %d  done %02X' % (
        tag, m.frames, r[0x22], r[0x7A], r[0x70], r[0x71], r[0x79], r[0x47], r[0x0000 + LEVEL_DONE]))


# address of level_done from the label file of the build (Test.map)
LEVEL_DONE = 0
lbl = os.path.join(os.path.dirname(os.path.abspath(sys.argv[1])), '..', 'Test.map')
for line in open(lbl):
    if line.startswith('level_done'):
        LEVEL_DONE = int(line.split('$')[1][:4], 16)

m.run_frames(40)
shot('1_world'); state('start')
press('SPACE'); m.run_frames(20)
shot('2_plan'); state('plan')
for ch in 'WZDQXEDZAQXEAZDQXE':
    press(ch)
shot('3_plan_prog')
press('F1'); m.run_frames(20)
press('SPACE')
for _ in range(60):
    m.run_frames(20)
    if m.ram[0x47] == 4:
        break
state('won')
m.run_frames(110)
shot('4_won')
press('SPACE'); m.run_frames(30)
shot('5_world_after'); state('map')
for ch in 'DDDDSSSAAASSASSD':
    press(ch, hold=2, after=10)
m.run_frames(10)
shot('6_world_node2'); state('node2')
press('SPACE'); m.run_frames(20)
shot('7_plan2'); state('plan2')
press('F7'); m.run_frames(20)
shot('8_back'); state('back')
