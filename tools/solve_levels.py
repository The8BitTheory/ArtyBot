#!/usr/bin/env python3
"""solve_levels.py - checks that the levels in src/mapdata.asm are solvable.

  python -B tools/solve_levels.py [--greedy] [levels, e.g. 11 25]      (default: all)

--greedy: one goal at a time, fast also for levels with many packages; the
program found is valid but not the shortest.

Parses the level records (map<world><level>, e.g. map11) and searches the shortest program with
A* over the game rules of run.asm (Move Fwd/Back, Turn, Pick Up, Drop Off,
Jump, Throw; ice: skating, breaking when jumped off / landed on / thrown on).
Prints the program as keys of the planning screen
(w s d a q e x z c) so it can be typed in.

--par: also prints the PAR value of each level (shown in the game once the
level is solved). Par counts commands like the game, except that a Jump over a
field the robot could simply walk across (free floor or goal field, no ice)
costs 2, like the two Move Fwd it replaces. So a solution that only saves
steps by hopping over plain ground does not lower the par.
--write-par: computes the par of all levels and writes src/level_par.asm (table
level_par in the order of plan_level_table). Levels where the exact search
gives up fall back to the greedy search (marked in the file).

  python -B tools/solve_levels.py --write-par
"""
import os, re, sys, heapq, time

HERE = os.path.dirname(os.path.abspath(__file__))
MAPDATA = os.path.join(HERE, '..', 'src', 'mapdata.asm')
PAR_ASM = os.path.join(HERE, '..', 'src', 'level_par.asm')
COLS = ROWS = 10
W = float(os.environ.get('SOLVE_W', '1'))   # >1: weighted A* (faster, not the shortest program)
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
        m = re.match(r'map(\d\d)\s*$', line)
        if m:
            cur = int(m.group(1)); levels[cur] = []; continue
        if cur is None:
            continue
        if re.match(r'[A-Za-z_]', line) and not re.match(r'map\d\d\s*$', line):
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
        for _ in range(6):                 # goals, packages, trees, water, ice, keys
            c = b[i]; i += 1
            lists.append([(b[i + 2 * k], b[i + 2 * k + 1]) for k in range(c)])
            i += 2 * c
        c = b[i]; i += 1                   # lock/door records: lock x, y, door x, y
        locks = [((b[i + 4 * k], b[i + 4 * k + 1]), (b[i + 4 * k + 2], b[i + 4 * k + 3])) for k in range(c)]
        i += 4 * c
        assert i == len(b), 'level %d: %d bytes, parsed %d' % (n, len(b), i)
        out[n] = dict(robot=(rx, ry, rd), goals=lists[0], boxes=lists[1], trees=set(lists[2]),
                      water=set(lists[3]), ice=set(lists[4]), keys=lists[5], locks=locks)
    return out


def solve(lv, limit=3_000_000, start_state=None, more=False, par=False):
    """par=True: a jump over walkable ground costs 2; returns (prog, n, cost)."""
    goals = tuple(lv['goals']); gset = set(goals)
    trees, water, ice = lv['trees'], lv['water'], lv['ice']
    inside = lambda x, y: 0 <= x < COLS and 0 <= y < ROWS
    rx, ry, rd = lv['robot']
    # state: x, y, dir, carry (0 nothing, 1 package, 2 key), packages, loose keys, filled locks
    locks = dict(lv['locks'])                      # lock position -> door position
    lockpos = set(locks)
    start = start_state or (rx, ry, rd, 0, frozenset(lv['boxes']), frozenset(lv['keys']), frozenset())
    covered0 = sum(1 for g in goals if g in start[4])

    def h(st):
        x, y, d, carry, boxes = st[:5]
        free = [b for b in boxes if b not in gset]
        if carry == 1:
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

    def free(p, boxes, keys=frozenset(), filled=frozenset()):   # walked on / skated over (floor, goal, ice)
        if not inside(*p) or p in trees or p in water or p in boxes or p in keys or p in lockpos:
            return False
        return not any(door == p and lk not in filled for lk, door in locks.items())

    def door_closed(p, filled):
        return any(door == p and lk not in filled for lk, door in locks.items())

    def moves(st):
        x, y, d, carry, boxes, keys, filled = st
        fr = lambda p, bx: free(p, bx, keys, filled)
        for name, dd in (('fwd', d), ('back', d ^ 1)):
            nx, ny = x + DX[dd], y + DY[dd]
            if fr((nx, ny), boxes):
                # Ice: keep skating in the moving direction until land is reached
                # (stop there) or the next field is blocked (stop on the ice).
                dead = False
                while (nx, ny) in ice:
                    sx, sy = nx + DX[dd], ny + DY[dd]
                    if (sx, sy) in water:           # skating into open water: drowns
                        dead = True
                        break
                    if not fr((sx, sy), boxes):
                        break
                    nx, ny = sx, sy
                if not dead:
                    yield name, (nx, ny, d, carry, boxes, keys, filled), 1
        yield 'right', (x, y, TURN_R[d], carry, boxes, keys, filled), 1
        yield 'left', (x, y, TURN_L[d], carry, boxes, keys, filled), 1
        yield 'turn180', (x, y, TURN_R[TURN_R[d]], carry, boxes, keys, filled), 1
        fx, fy = x + DX[d], y + DY[d]
        if not carry and inside(fx, fy):
            if (fx, fy) in boxes:
                yield 'pick', (x, y, d, 1, boxes - {(fx, fy)}, keys, filled), 1
            elif (fx, fy) in keys:
                yield 'pick', (x, y, d, 2, boxes, keys - {(fx, fy)}, filled), 1
        if carry and inside(fx, fy):
            if fr((fx, fy), boxes) and (fx, fy) not in ice:
                if carry == 1:
                    yield 'drop', (x, y, d, 0, boxes | {(fx, fy)}, keys, filled), 1
                else:
                    yield 'drop', (x, y, d, 0, boxes, keys | {(fx, fy)}, filled), 1
            elif carry == 2 and (fx, fy) in lockpos and (fx, fy) not in filled:
                yield 'drop', (x, y, d, 0, boxes, keys, filled | {(fx, fy)}), 1
        ax, ay = x + 2 * DX[d], y + 2 * DY[d]
        if inside(ax, ay) and (fx, fy) not in trees and not door_closed((fx, fy), filled):
            # landing on ice (robot or package) breaks it: fail; jumping off ice too
            land_ok = fr((ax, ay), boxes) and (ax, ay) not in ice
            if land_ok and (x, y) not in ice:
                # par: a jump over plain walkable ground is just two Move Fwd
                cheap = par and fr((fx, fy), boxes) and (fx, fy) not in ice
                yield 'jump', (ax, ay, d, carry, boxes, keys, filled), 2 if cheap else 1
            if land_ok and carry == 1:
                yield 'throw', (x, y, d, 0, boxes | {(ax, ay)}, keys, filled), 1
            elif land_ok and carry == 2:
                yield 'throw', (x, y, d, 0, boxes, keys | {(ax, ay)}, filled), 1
            elif carry == 2 and (ax, ay) in lockpos and (ax, ay) not in filled:
                yield 'throw', (x, y, d, 0, boxes, keys, filled | {(ax, ay)}), 1

    openq = [(W * h(start), 0, 0, start)]
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
            if more:
                return (prog[::-1], n, end) + ((g,) if par else ())
            return (prog[::-1], n, g) if par else (prog[::-1], n)
        n += 1
        if n > limit:
            return (None, n, None) if par else (None, n)
        for name, nst, cost in moves(st):
            ng = g + cost
            if ng < best.get(nst, 1 << 30):
                best[nst] = ng
                parent[nst] = (st, name)
                tie += 1
                heapq.heappush(openq, (ng + W * h(nst), ng, tie, nst))
    return (None, n, None) if par else (None, n)


def solve_greedy(lv, par=False):
    """Not the shortest program: cover one more goal per search (for big levels)."""
    rx, ry, rd = lv['robot']
    st = (rx, ry, rd, 0, frozenset(lv['boxes']), frozenset(lv['keys']), frozenset())
    prog, total, cost = [], 0, 0
    while not all(g in st[4] for g in lv['goals']):
        r = solve(lv, 400_000, st, True, par)
        if r[0] is None:
            return (None, total, None) if par else (None, total)
        p, n, st = r[:3]
        prog += p; total += n
        cost += r[3] if par else len(p)
    return (prog, total, cost) if par else (prog, total)


def level_order():
    """Level labels (e.g. 11) in the order of plan_level_table."""
    order, inside = [], False
    for line in open(MAPDATA, encoding='utf-8'):
        if line.startswith('plan_level_table'):
            inside = True; continue
        if inside:
            if line.startswith('plan_level_count'):
                break
            m = re.match(r'\s*!word\s+([^;]*)', line)
            if m:
                order += [int(t.strip()[3:]) for t in m.group(1).split(',') if t.strip()]
    return order


def write_par(levels):
    rows = []
    for n in level_order():
        t = time.time()
        prog, nodes, cost = solve(levels[n], par=True)
        how = 'exact'
        if prog is None:
            prog, nodes, cost = solve_greedy(levels[n], par=True)
            how = 'greedy'
        if prog is None:
            sys.exit('map%d: no solution - par not written' % n)
        keys = ''.join(KEYS[p] for p in prog)
        print('map%d: par %2d (%d commands, %s)  %s   (%.1fs)' % (
            n, cost, len(prog), how, keys, time.time() - t))
        rows.append((n, cost, how, keys))
    with open(PAR_ASM, 'w', newline='\r\n') as f:
        f.write('; level_par.asm - GENERATED by tools/solve_levels.py --write-par, do not edit.\n')
        f.write('; Par = shortest program found by the solver; a Jump over walkable ground\n')
        f.write('; counts 2 (two Move Fwd). One byte per level, order of plan_level_table.\n')
        f.write('level_par\n')
        for n, cost, how, keys in rows:
            f.write('        !byte %3d             ; map%d %s %s\n' % (cost, n, how, keys))
        f.write('level_par_count = * - level_par\n')
        f.write('!if level_par_count != plan_level_count {\n')
        f.write('    !error "level_par.asm passt nicht zu plan_level_table: solve_levels.py --write-par"\n')
        f.write('}\n')
    print('written', os.path.normpath(PAR_ASM))


def main():
    levels = parse_levels()
    greedy = '--greedy' in sys.argv
    par = '--par' in sys.argv
    if '--write-par' in sys.argv:
        write_par(levels)
        return
    sys.argv = [a for a in sys.argv if a not in ('--greedy', '--par')]
    which = [int(a) for a in sys.argv[1:]] or sorted(levels)
    bad = 0
    for n in which:
        t = time.time()
        r = (solve_greedy if greedy else solve)(levels[n], par=par)
        prog, nodes = r[:2]
        if prog is None:
            print('map%d: NO SOLUTION found (%d states)' % (n, nodes)); bad += 1
        else:
            print('map%d: %2d commands%s  %s   (%d states, %.1fs)' % (
                n, len(prog), ('  par %2d' % r[2]) if par else '',
                ''.join(KEYS[p] for p in prog), nodes, time.time() - t))
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
