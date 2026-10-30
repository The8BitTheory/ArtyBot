#!/usr/bin/env python3
"""sim_stats.py - tests the level statistics (runs / commands) and the F1 overlay on the world map.

  python -B tools/sim_stats.py build/roboter.prg build/labels.txt out/prefix
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from c64sim import C64
K = dict(W=9, A=10, S=13, D=18, Q=62, E=14, X=23, Z=12, SPACE=60, RETURN=1, F1=4, F7=3, R=17)
prg = open(sys.argv[1], 'rb').read(); out = sys.argv[3]
lab = {}
for line in open(sys.argv[2]):
    p = line.replace('=', ' ').replace('$', ' ').split()
    if len(p) >= 2 and p[0] in ('level_runs', 'level_cmds', 'level_done'):
        lab[p[0]] = int(p[1], 16)
m = C64(prg)
def press(k, hold=3, after=6):
    m.keys.add(K[k]); m.run_frames(hold); m.keys.discard(K[k]); m.run_frames(after)
def shot(n): m.render(2).save('%s_%s.png' % (out, n))
def st(tag):
    print('%-14s runs[0..3]=%s cmds[0..3]=%s state=%d' % (tag, list(m.ram[lab['level_runs']:lab['level_runs']+4]),
          list(m.ram[lab['level_cmds']:lab['level_cmds']+4]), m.ram[0x47]))
def wait_stop():
    for _ in range(80):
        m.run_frames(20)
        if m.ram[0x47] in (2, 4): break
m.run_frames(40)
press('F1'); m.run_frames(10); shot('1_stats_empty'); st('empty')
press('F1'); m.run_frames(20); shot('2_back')
press('SPACE'); m.run_frames(20)
for ch in 'WZ': press(ch)
press('F1'); m.run_frames(20); press('SPACE'); wait_stop(); st('run1 (WZ)')
press('SPACE'); wait_stop(); st('retry')            # same plan: no count
press('R'); wait_stop(); st('R restart')            # no count
press('F1'); m.run_frames(10); press('F1'); m.run_frames(20); press('SPACE'); wait_stop(); st('F1 F1 same')
press('F1'); m.run_frames(10)
for ch in 'DQXEDZAQXEAZDQXE': press(ch)
press('F1'); m.run_frames(20); press('SPACE'); wait_stop(); st('run2 full')
m.run_frames(110)
press('SPACE'); m.run_frames(30)
press('F1'); m.run_frames(10); shot('3_stats'); st('stats')
press('F1'); m.run_frames(20); shot('4_back')
