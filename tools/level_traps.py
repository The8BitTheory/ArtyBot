#!/usr/bin/env python3
"""level_traps.py - how forgiving is a level? Explores every state the robot can
reach (rules from solve_levels.py) and counts the dead ends: states from which the
level can no longer be won (the player has blocked himself and must press R).

  python -B tools/level_traps.py LEVEL.txt [--set x,y,c ...] [--show N] [--trace]
  python -B tools/level_traps.py 15            (a level already in src/mapdata.asm)

LEVEL.txt in the format of ascii_level.py. Prints:
  states      reachable states (position, direction, carried item, package layout)
  dead        of these, how many can no longer be won
  layouts     package layouts (where the packages stand) that are reachable,
              and how many of them are dead
  shortest    the shortest program (breadth-first, all commands cost 1)
  traps       the moves (Pick Up / Drop Off / Throw / Jump / ...) that lead from a
              winnable state into a dead one, grouped by the package layout they
              produce; --show N prints the first N of these layouts as a map.
--trace     prints the field after every Pick Up / Drop Off / Throw of the shortest
            program (to see what the solution does).
A good "order" puzzle has a short solution but many trap layouts.
"""
import os, sys
from collections import deque, defaultdict
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import solve_levels as sl
import ascii_level as al

LIMIT = 2_000_000


def load(args):
    sets = [args[i + 1] for i, a in enumerate(args) if a == '--set']
    pos = [a for i, a in enumerate(args)
           if not a.startswith('--') and (i == 0 or args[i - 1] not in ('--set', '--show'))]
    src = pos[0]
    if src.isdigit():
        return sl.parse_levels()[int(src)], None
    label, title, desc, art = al.load(src)
    art = [list(r) for r in art]
    for s in sets:
        x, y, c = s.split(',', 2)
        art[int(y)][int(x)] = c
    art = [''.join(r) for r in art]
    robot, L = al.parse(art)
    lv = dict(robot=(robot[0], robot[1], al.DIRN[robot[2]]), goals=L['goals'], boxes=L['boxes'],
              trees=set(L['trees']), water=set(L['water']), ice=set(L['ice']),
              keys=L['keys'], locks=L['locks'])
    return lv, art


def draw(art, lv, boxes, keys):
    rows = []
    for y in range(10):
        r = ''
        for x in range(10):
            p = (x, y)
            c = art[y][x] if art else '.'
            if c in 'PK<>^v':
                c = '.'
            if p in lv['goals']:
                c = 'G'
            if p in boxes:
                c = '@' if p in lv['goals'] else 'P'
            if p in keys:
                c = 'K'
            r += c
        rows.append(r)
    return rows


def analyse(lv, limit=LIMIT):
    """Returns dict: prog (shortest, list of commands or None), states, dead,
    layouts, dead_layouts, traps {layout: commands}. None if over limit."""
    start, moves = sl.rules(lv)
    goals = set(lv['goals'])
    won = lambda st: goals <= st[4]
    succ, pred = {}, defaultdict(list)
    seen = {start}
    parent = {start: None}
    q = deque([start])
    first = None
    while q:
        st = q.popleft()
        out = []
        if won(st):
            if first is None:
                first = st
        else:
            for name, nst, _ in moves(st):
                out.append((name, nst))
                pred[nst].append(st)
                if nst not in seen:
                    if len(seen) >= limit:
                        return None
                    seen.add(nst)
                    parent[nst] = (st, name)
                    q.append(nst)
        succ[st] = out
    prog = None
    if first is not None:
        prog, st = [], first
        while parent[st]:
            st, name = parent[st]
            prog.append(name)
        prog.reverse()
    alive = {st for st in seen if won(st)}
    q = deque(alive)
    while q:
        st = q.popleft()
        for p in pred[st]:
            if p not in alive:
                alive.add(p)
                q.append(p)
    lay = defaultdict(bool)
    for st in seen:
        lay[(st[3] != 0, st[4], st[5], st[6])] |= st in alive
    traps = defaultdict(set)
    for st in alive:
        for name, nst in succ[st]:
            if nst not in alive:
                traps[(nst[3], nst[4], nst[5], nst[6])].add(name)
    return dict(prog=prog, states=len(seen), dead=len(seen) - len(alive),
                layouts=len(lay), dead_layouts=sum(1 for v in lay.values() if not v),
                traps=traps)


def trace(lv, art, prog):
    """Prints the field after every Pick Up / Drop Off / Throw of the program."""
    start, moves = sl.rules(lv)
    st, done = start, ''
    arrow = '><^v'
    for c in prog:
        st = next(n for name, n, _ in moves(st) if name == c)
        done += sl.KEYS[c]
        if c in ('pick', 'drop', 'throw'):
            rows = [list(r) for r in draw(art, lv, st[4], st[5])]
            rows[st[1]][st[0]] = arrow[st[2]]
            print('-- %s  (%s%s)' % (done, c, ', carrying' if st[3] else ''))
            for row in rows:
                if set(row) != {'T'}:
                    print('   ' + ''.join(row))


def main():
    args = sys.argv[1:]
    show = int(args[args.index('--show') + 1]) if '--show' in args else 0
    lv, art = load(args)
    r = analyse(lv)
    if r is None:
        sys.exit('more than %d states - level too big for this tool' % LIMIT)
    if r['prog'] is None:
        print('NOT SOLVABLE')
    else:
        print('shortest %d commands  %s' % (len(r['prog']), ''.join(sl.KEYS[c] for c in r['prog'])))
    n = r['states']
    print('states  %7d   dead %7d  (%.0f%%)' % (n, r['dead'], 100.0 * r['dead'] / n))
    print('layouts %7d   dead %7d' % (r['layouts'], r['dead_layouts']))
    traps = r['traps']
    print('trap layouts (winnable -> lost in one move): %d' % len(traps))
    byname = defaultdict(int)
    for v in traps.values():
        for c in v:
            byname[c] += 1
    print('trap moves by command:', dict(byname))
    if '--trace' in args and r['prog']:
        trace(lv, art, r['prog'])
    for i, ((carry, boxes, keys, filled), names) in enumerate(sorted(traps.items(), key=lambda t: sorted(t[0][1]))):
        if i >= show:
            break
        print('-- after %s%s' % ('/'.join(sorted(names)), ' (carrying)' if carry else ''))
        for row in draw(art, lv, boxes, keys):
            print('   ' + row)


if __name__ == '__main__':
    main()
