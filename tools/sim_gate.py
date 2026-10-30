#!/usr/bin/env python3
"""sim_gate.py - tests the world gate in tools/c64sim.py (screenshots in out/).

  python -B tools/sim_gate.py build/roboter.prg out/prefix

1. The closed gate blocks the robot. 2. Levels 2-4 are marked as solved by
poking level_done, level 1 is played with its solution: after the win the
gate blinks open on the map. 3. The robot walks through the opened gate."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from c64sim import C64

K = dict(W=9, A=10, S=13, D=18, Q=62, E=14, SPACE=60, F1=4, F3=5, F5=6)
prg = open(sys.argv[1], 'rb').read(); out = sys.argv[2]
lbl = {}
for line in open(os.path.join(os.path.dirname(os.path.abspath(sys.argv[1])), '..', 'Test.map')):
    if '=$' in line:
        n, v = line.split('=$')
        lbl[n.strip()] = int(v.split(';')[0].strip(), 16)
m = C64(prg)

def press(k, hold=3, after=6):
    m.keys.add(K[k]); m.run_frames(hold); m.keys.discard(K[k]); m.run_frames(after)
def shot(n): m.render(2).save('%s_%s.png' % (out, n))
def info(tag):
    r = m.ram
    print('%-14s frame %5d world %d cell %d,%d gate_open %d gate_done %d worlds_open %d level_done %02X' % (
        tag, m.frames, r[0x7A], r[0x70], r[0x71], r[lbl['wm_gate_open']], r[lbl['gate_done']], r[lbl['worlds_open']], r[lbl['level_done']]))

m.run_frames(40); shot('g1_closed'); info('start')
for ch in 'DDW':            # up to the gate: blocked
    press(ch, 2, 14)
info('at gate')
m.ram[lbl['level_done']] = 0x0E           # levels 2-4 solved
press('A', 2, 14); press('A', 2, 14)       # back to node 1 (2,1)
info('at node 1')
press('SPACE'); m.run_frames(20)
for ch in 'WWWDWWWWQAWWDE': press(ch)
press('F1'); m.run_frames(20); press('SPACE')
for _ in range(60):
    m.run_frames(20)
    if m.ram[0x47] == 4: break
m.run_frames(110)
m.keys.add(K['SPACE']); m.run_frames(3); m.keys.discard(K['SPACE'])
seq = []
for i in range(120):                       # gate_open every frame: closed wait, then 7 changes
    m.run_frames(1)
    seq.append(m.ram[lbl['wm_gate_open']])
    if i in (5, 36, 38, 42, 47, 52, 57):
        shot('g3_f%03d' % i)
print('gate_open per frame:', ''.join(map(str, seq)))
info('back on map')
m.run_frames(30); info('opened'); shot('g4_open')
for ch in 'DDW':
    press(ch, 2, 14)
info('through gate'); shot('g5_end')
