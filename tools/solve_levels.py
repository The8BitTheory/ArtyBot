#!/usr/bin/env python3
"""solve_levels.py - checks that the levels in src/mapdata.asm are solvable.

  python -B tools/solve_levels.py [--greedy] [level numbers 1..n]      (default: all)

--greedy: one goal at a time, fast also for levels with many packages; the
program found is valid but not the shortest.

Parses the level records (plan_level_N) and searches the shortest program with
A* over the game rules of run.asm (Move Fwd/Back, Turn, Pick Up, Drop Off,
Jump, Throw). Prints the program as keys of the planning screen
(w s d a q e x z c) so it can be typed in.
"""
import os, re, sys, heapq, time

HERE = os.path.dirname(os.path.abspath(__file__))
MAPDATA = os.path.join(HERE, '..', 'src', 'mapdata.asm')
COLS = ROWS = 10
DX = (1, -1, 0, 0)          # right, left, up, down (ROBOT_DIR_*)
DY = (0, 0, -1, 1)
TURN_R = (3, 2, 0, 1)
TURN_L = (2, 3, 1, 0)
SYMBOLS = {'ROBOT_DIR_RIGHT': 0, 'ROBOT_DIR_LEFT': 1, 'ROBOT_DIR_UP': 2, 'ROBOT_DIR_DOWN': 3}
KEYS = {'fwd': 'w', 'back': 's', 'right': 'd', 'left': 'a', 'pick': 'q', 'drop': 'e',
        'turn180': 'x', 'jump': 'z', 'throw': 'c'}


def parse_levels():
    levels, cur = {}, None
    for line in open(MAPDATA, encoding='utf-8'):
        m = re.match(r'plan_level_(\d+)\s*$', line)
        if m:
            cur = int(m.group(1)); levels[cur] = []; continue
        if cur is None:
            continue
        if re.match(r'[A-Za-z_]', line) and not line.startswith('plan_level'):
            cur = None; continue
        m = re.match(r'\s*!byte\s+([^;]*)', line)
        if m:
            for tok in m.group(1).split(','):
                tok = tok.strip()
                if tok:
                    levels[cur].append(SYMBOLS[tok] if tok in SYMBOLS else int(tok))
    out = {}
    for n, b in levels.items():
        rx, ry, rd = b[0], b[1], b[2]
        i = 3
        lists = []
        for _ in range(4):                 # goals, packages, trees, water
            c = b[i]; i += 1
            lists.append([(b[i + 2 * k], b[i + 2 * k + 1]) for k in range(c)])
            i += 2 * c
        assert i == len(b), 'level %d: %d bytes, parsed %d' % (n, len(b), i)
        out[n] = dict(robot=(rx, ry, rd), goals=lists[0], boxes=lists[1], trees=set(lists[2]),
                      water=set(lists[3]))
    return out


def solve(lv, limit=3_000_000, start_state=None, more=False):
    goals = tuple(lv['goals']); gset = set(goals)
    trees, water = lv['trees'], lv['water']
    inside = lambda x, y: 0 <= x < COLS and 0 <= y < ROWS
    rx, ry, rd = lv['robot']
    start = start_state or (rx, ry, rd, 0, frozenset(lv['boxes']))
    covered0 = sum(1 for g in goals if g in start[4])

    def h(st):
        x, y, d, carry, boxes = st
        free = [b for b in boxes if b not in gset]
        if carry:
            free = free + [(x, y)]
        t = 0
        for g in goals:
            if g not in boxes:
                t += min(abs(g[0] - b[0]) + abs(g[1] - b[1]) for b in free) if free else 99
        return (t + 1) // 2 + (1 if t else 0)

    def won(st):
        if more:                    # greedy step: one more goal covered
            return sum(1 for g in goals if g in st[4]) > covered0
        return all(g in st[4] for g in goals)

    def moves(st):
        x, y, d, carry, boxes = st
        for name, dd in (('fwd', d), ('back', d ^ 1)):
            nx, ny = x + DX[dd], y + DY[dd]
            if inside(nx, ny) and (nx, ny) not in trees and (nx, ny) not in water and (nx, ny) not in boxes:
                yield name, (nx, ny, d, carry, boxes)
        yield 'right', (x, y, TURN_R[d], carry, boxes)
        yield 'left', (x, y, TURN_L[d], carry, boxes)
        yield 'turn180', (x, y, TURN_R[TURN_R[d]], carry, boxes)
        fx, fy = x + DX[d], y + DY[d]
        if not carry and inside(fx, fy) and (fx, fy) in boxes:
            yield 'pick', (x, y, d, 1, boxes - {(fx, fy)})
        if carry and inside(fx, fy) and (fx, fy) not in trees and (fx, fy) not in water and (fx, fy) not in boxes:
            yield 'drop', (x, y, d, 0, boxes | {(fx, fy)})
        ax, ay = x + 2 * DX[d], y + 2 * DY[d]
        if inside(ax, ay) and (fx, fy) not in trees:
            land_ok = (ax, ay) not in trees and (ax, ay) not in water and (ax, ay) not in boxes
            if land_ok:
                yield 'jump', (ax, ay, d, carry, boxes)
                if carry:
                    yield 'throw', (x, y, d, 0, boxes | {(ax, ay)})

    openq = [(h(start), 0, 0, start)]
    best = {start: 0}
    parent = {start: None}
    tie = 0
    n = 0
    while openq:
        f, g, _, st = heapq.heappop(openq)
        if best.get(st, 1 << 30) < g:
            continue
        if won(st):
            end = st
            prog = []
            while parent[st]:
                st, name = parent[st]
                prog.append(name)
            return (prog[::-1], n, end) if more else (prog[::-1], n)
        n += 1
        if n > limit:
            return None, n
        for name, nst in moves(st):
            ng = g + 1
            if ng < best.get(nst, 1 << 30):
                best[nst] = ng
                parent[nst] = (st, name)
                tie += 1
                heapq.heappush(openq, (ng + h(nst), ng, tie, nst))
    return None, n


def solve_greedy(lv):
    """Not the shortest program: cover one more goal per search (for big levels)."""
    rx, ry, rd = lv['robot']
    st = (rx, ry, rd, 0, frozenset(lv['boxes']))
    prog, total = [], 0
    while not all(g in st[4] for g in lv['goals']):
        r = solve(lv, 400_000, st, True)
        if r[0] is None:
            return None, total
        p, n, st = r
        prog += p; total += n
    return prog, total


def main():
    levels = parse_levels()
    greedy = '--greedy' in sys.argv
    sys.argv = [a for a in sys.argv if a != '--greedy']
    which = [int(a) for a in sys.argv[1:]] or sorted(levels)
    bad = 0
    for n in which:
        t = time.time()
        prog, nodes = (solve_greedy if greedy else solve)(levels[n])
        if prog is None:
            print('level %d: NO SOLUTION found (%d states)' % (n, nodes)); bad += 1
        else:
            print('level %d: %2d commands  %s   (%d states, %.1fs)' % (
                n, len(prog), ''.join(KEYS[p] for p in prog), nodes, time.time() - t))
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
