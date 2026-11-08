#!/usr/bin/env python3
"""sim_c128keys.py - prueft die C128-Pfeiltasten (Zeile K2 ueber $D02F) im Simulator:
Titelmenue (runter/hoch), Weltkarte (Figur laeuft rechts/links/runter/hoch).
  python -B tools/sim_c128keys.py build/artybot128.prg build/artybot128.labels"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from c128sim import C128

prg = open(sys.argv[1], 'rb').read()
lab = {}
for l in open(sys.argv[2]):
    p = l.split('=')
    if len(p) == 2 and p[1].strip().startswith('$'):
        lab[p[0].strip()] = int(p[1].split(';')[0].strip().lstrip('$'), 16)
m = C128(prg)
m.run_frames(60)
SEL = lab['title_sel']


def press(k, hold=3, after=10):
    m.keys.add(k); m.run_frames(hold); m.keys.discard(k); m.run_frames(after)


ok = True
s0 = m.ram[SEL]; press(C128.KEY_DOWN); s1 = m.ram[SEL]; press(C128.KEY_UP); s2 = m.ram[SEL]
print('Titel: Auswahl %d -> runter %d -> hoch %d' % (s0, s1, s2))
ok &= s1 == s0 + 1 and s2 == s0
press(56); m.run_frames(40)                       # Taste 1: neues Spiel -> Weltkarte
X, Y = 0x70, 0x71
for k, name in ((C128.KEY_RIGHT, 'rechts'), (C128.KEY_LEFT, 'links'), (C128.KEY_DOWN, 'runter'), (C128.KEY_UP, 'hoch')):
    a = (m.ram[X], m.ram[Y]); press(k, 2, 20); b = (m.ram[X], m.ram[Y])
    print('Karte: %-6s %s -> %s' % (name, a, b))
    if name in ('rechts', 'links'): ok &= a != b       # ab S: rechts und zurueck ist Weg
print('OK' if ok else 'FEHLER')
sys.exit(0 if ok else 1)
