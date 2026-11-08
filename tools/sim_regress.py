#!/usr/bin/env python3
"""sim_regress.py - Regressionstest fuer Umbauten ohne Verhaltensaenderung.

  python -B tools/sim_regress.py build/roboter.prg out/dir            # Signaturen schreiben
  python -B tools/sim_regress.py build/roboter.prg out/dir REF/dir    # zusaetzlich mit REF vergleichen

Laeuft auch mit dem C128-PRG (build/artybot128.prg, tools/c128sim.py); als REF dient dann
die C64-Referenz - die Bilder muessen gleich sein.

Spielt einen festen Ablauf im Simulator (tools/c64sim.py) durch: Titel, Instructions,
Credits, Weltkarte, Statistik, Plan, Lauf mit Fehler, Lauf mit Sieg, Tor, Winter,
Eis-Level, Endbildschirm, F8 zurueck zum Titel, alle Levels mit der Solver-Loesung.
An jedem Haltepunkt wird das gerenderte Bild (inkl. Sprites) als PNG gespeichert und
eine Signatur aus Bild + VIC-Registern + Spielzustand in out/dir/signatures.txt
geschrieben. Mit REF werden die Signaturen verglichen; Abweichungen werden gemeldet
(Exit-Code 1). Zeropage-Adressen wie in sim_level.py (zp.inc)."""
import sys, os, hashlib
from collections import deque
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from c128sim import machine     # C64 oder C128 je nach Ladeadresse
import gen_world_maps as W
import solve_levels as sl

K = dict(w=9, s=13, d=18, a=10, q=62, e=14, x=23, z=12, c=20)
SPACE, RETURN, F1, F7, LSHIFT, Y = 60, 1, 4, 3, 15, 25
KEY_2, KEY_3 = 59, 8
RUN_STATE, WORLD, POS_X, POS_Y = 0x47, 0x7A, 0x70, 0x71

prg = open(sys.argv[1], 'rb').read()
out = sys.argv[2]
ref = sys.argv[3] if len(sys.argv) > 3 else None
os.makedirs(out, exist_ok=True)
MAPS = [W.parse(n, a, i) for i, (n, a) in enumerate(W.WORLDS)]
LEVELS = sl.parse_levels()
sigs = []
m = None


def press(k, hold=3, after=6, shift=False):
    if shift: m.keys.add(LSHIFT)
    m.keys.add(k); m.run_frames(hold); m.keys.discard(k)
    if shift: m.keys.discard(LSHIFT)
    m.run_frames(after)


def shot(name):
    im = m.render(1)
    im.save(os.path.join(out, name + '.png'))
    h = hashlib.sha1(im.tobytes())
    h.update(bytes(m.io[0:0x2F]))           # VIC registers
    h.update(bytes([m.ram[RUN_STATE], m.ram[WORLD], m.ram[POS_X], m.ram[POS_Y]]))
    sigs.append('%s %s' % (name, h.hexdigest()))


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


def open_next_world():
    press(F1, shift=True); m.run_frames(200)          # F2 cheat, gate blinks
    cells = MAPS[m.ram[WORLD]][0]
    gate = {(i % W.COLS, i // W.COLS) for i, c in enumerate(cells) if c in (7, 8)}
    walk_to(gate, (6, 7, 8))


def go_level(local):
    walk_to({MAPS[m.ram[WORLD]][1][local]}, (6,))
    press(SPACE); m.run_frames(20)


def type_prog(prog):
    for ch in prog:
        press(K[ch], 2, 4)


def run_until_end(mid=None):
    press(F1); m.run_frames(20)
    press(SPACE)
    n = 0
    for _ in range(300):
        m.run_frames(10); n += 1
        if mid and n == 3: shot(mid)
        if m.ram[RUN_STATE] in (2, 4): break
    return m.ram[RUN_STATE]


SOLFILE = os.path.join(ref or out, 'solutions.txt')
SOL = dict(l.split() for l in open(SOLFILE)) if os.path.exists(SOLFILE) else {}


def solution(label):
    """Solver solution (A*, fallback greedy), cached in solutions.txt of REF/out."""
    key = 'map%d' % label
    if key not in SOL:
        r = sl.solve(LEVELS[label])
        if r[0] is None:
            r = sl.solve_greedy(LEVELS[label])
        SOL[key] = ''.join(sl.KEYS[c] for c in r[0])
        open(os.path.join(out, 'solutions.txt'), 'w').write(''.join('%s %s\n' % kv for kv in sorted(SOL.items())))
    return SOL[key]


# ---- Ablauf 1: Bildschirme --------------------------------------------
m = machine(prg)
m.run_frames(60); shot('01_title')
press(KEY_2); m.run_frames(20); shot('02_instr1')
press(SPACE); m.run_frames(20); shot('03_instr2')
press(SPACE); m.run_frames(20)
press(KEY_3); m.run_frames(20); shot('04_credits')
press(SPACE); m.run_frames(30)
press(56); m.run_frames(30); shot('05_map_meadow')
press(F1); m.run_frames(20); shot('06_stats')
press(SPACE); m.run_frames(20)
go_level(0); shot('07_plan_empty')
type_prog('ww'); shot('08_plan_typed')
st = run_until_end(); shot('09_run_fail'); assert st == 2, st
press(F1); m.run_frames(20); shot('10_plan_after_fail')
press(51, shift=True); m.run_frames(10); press(RETURN); m.run_frames(10)   # clear list
type_prog(solution(11))
st = run_until_end('11_run_mid'); assert st == 4, st
m.run_frames(150); shot('12_run_won')
press(SPACE); m.run_frames(60); shot('13_map_after_win')
open_next_world(); shot('14_map_winter')
go_level(0); type_prog(solution(21))
st = run_until_end('15_run_ice_mid'); assert st == 4, st
m.run_frames(150); shot('16_run_ice_won')
press(F7); m.run_frames(40)
open_next_world(); m.run_frames(60); shot('17_end')
press(RETURN); m.run_frames(60); shot('18_title_again')
print('Ablauf 1 ok')

# ---- Ablauf 2: alle Levels -----------------------------------------------
for label in sorted(LEVELS):
    world, local = label // 10 - 1, label % 10 - 1
    m = machine(prg)
    m.start_game(); m.run_frames(40)
    while m.ram[WORLD] < world:
        open_next_world()
    go_level(local)
    type_prog(solution(label))
    st = run_until_end()
    shot('L%d_run' % label)
    print('map%d %s' % (label, 'WON' if st == 4 else 'NOT won (%d)' % st))
    sigs.append('map%d_won %d' % (label, st == 4))

open(os.path.join(out, 'signatures.txt'), 'w').write('\n'.join(sigs) + '\n')
if ref:
    a = dict(l.split(' ', 1) for l in open(os.path.join(ref, 'signatures.txt')).read().split('\n') if l)
    b = dict(l.split(' ', 1) for l in sigs)
    bad = [k for k in sorted(set(a) | set(b)) if a.get(k) != b.get(k)]
    for k in bad: print('ABWEICHUNG', k)
    print('Vergleich: %d Haltepunkte, %d Abweichungen' % (len(a), len(bad)))
    sys.exit(1 if bad else 0)
