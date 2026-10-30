#!/usr/bin/env python3
"""Runs build/roboter.prg in tools/c64sim.py, enters a 14-command test plan,
starts it (R, Space) and saves screenshots: python tools/sim_screenshots.py build/roboter.prg out"""
import sys
sys.path.insert(0,'tools')
from c64sim import C64
prg = open(sys.argv[1],'rb').read(); out = sys.argv[2]
m = C64(prg)
m.start_game()                # title screen -> Start New Game
def press(k, frames=3):
    m.keys.add(k); m.run_frames(frames); m.keys.discard(k); m.run_frames(5)
m.run_frames(30)
KEYS = {'A':10,'B':28,'C':20,'D':18,'E':14,'F':21,'G':26}
for ch in "AAACAAAAEDAACF":
    press(KEYS[ch])
m.render(2).save(out+'_editor2.png')
press(17); m.run_frames(10)
press(60)
shots = [3, 3, 40, 60, 80, 100, 100, 90, 60]
for i,f in enumerate(shots):
    m.run_frames(f); m.render(3).save(out+'_r%d.png'%i)
    print(i, m.frames, 'robot', m.ram[0x1C], m.ram[0x1D], 'dir', m.ram[0x44], 'carry', m.ram[0x4C], 'walk', m.ram[0x5A], 'pc', m.ram[0x48], 'state', m.ram[0x47])
