#!/usr/bin/env python3
"""ascii_level.py - builds a level record from ASCII art, solves it and can write it
into src/mapdata.asm.

  python -B tools/ascii_level.py LEVEL.txt [--write] [--set x,y,c ...] [--greedy]

LEVEL.txt:
  line 1   label and title, e.g.   map23 Steering
  then     description lines (become the comment above the record) up to an
           empty line, then 10 rows of 10 characters:
    .  snow / grass (floor)   #  ice        ~  water      T  tree / pine
    P  package (on floor)     G  goal       K  key
    L / M  lock 1 / 2         D / E  door of lock 1 / 2
    > < ^ v  robot (on floor) and its direction
--set x,y,c   test a variant: cell (x, y) becomes character c (several allowed),
              e.g. --set 6,4,#  "what if this pine were ice?"
--write       replace the record of that label in src/mapdata.asm (only without --set)
Prints the shortest program (keys w s d a q e x z c) from solve_levels.py.
"""
import os, sys, time
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import solve_levels as sl

MAPDATA = os.path.join(HERE, '..', 'src', 'mapdata.asm')
DIRS = {'>': 'ROBOT_DIR_RIGHT', '<': 'ROBOT_DIR_LEFT', '^': 'ROBOT_DIR_UP', 'v': 'ROBOT_DIR_DOWN'}
DIRN = {'>': 0, '<': 1, '^': 2, 'v': 3}


def load(path):
    lines = open(path, encoding='utf-8').read().split('\n')
    label, title = lines[0].split(None, 1)
    i, desc = 1, []
    while lines[i].strip():
        desc.append(lines[i].rstrip()); i += 1
    art = [l.rstrip('\r') for l in lines[i + 1:i + 11]]
    return label, title.strip(), desc, art


def parse(art):
    assert len(art) == 10 and all(len(r) == 10 for r in art), 'need 10 rows of 10 characters'
    L = dict(goals=[], boxes=[], trees=[], water=[], ice=[], keys=[])
    locks, doors, robot = {}, {}, None
    for y, r in enumerate(art):
        for x, c in enumerate(r):
            p = (x, y)
            if c in DIRS: robot = (x, y, c)
            elif c == 'G': L['goals'].append(p)
            elif c == 'P': L['boxes'].append(p)
            elif c == 'T': L['trees'].append(p)
            elif c == '~': L['water'].append(p)
            elif c == '#': L['ice'].append(p)
            elif c == 'K': L['keys'].append(p)
            elif c in 'LM': locks[c] = p
            elif c in 'DE': doors['L' if c == 'D' else 'M'] = p
            elif c != '.': sys.exit('unknown character %r at %d,%d' % (c, x, y))
    assert robot, 'no robot'
    assert sorted(locks) == sorted(doors), 'every lock needs its door'
    L['locks'] = [(locks[k], doors[k]) for k in sorted(locks)]
    return robot, L


def record(label, title, desc, art, robot, L):
    def pairs(lst, per=8):
        return ['        !byte ' + ', '.join('%d, %d' % p for p in lst[i:i + per])
                for i in range(0, len(lst), per)]
    out = ['; %s (%s)%s' % (label, title, ':' if desc else '')]
    out += ['; ' + d for d in desc]
    out += [';'] + [';    ' + r for r in art]
    out += [';    (. snow  # ice  ~ water  T pine  P package  G goal  K key  L/M lock  D/E door)']
    out += [label, '        !byte %d, %d, %s' % (robot[0], robot[1], DIRS[robot[2]])]
    for key, name in (('goals', 'goal fields'), ('boxes', 'packages'), ('trees', 'blockers'),
                      ('water', 'water fields'), ('ice', 'ice fields (frozen water)'),
                      ('keys', 'keys')):
        out.append('        !byte %-22d; %s (x, y)' % (len(L[key]), name))
        out += pairs(L[key])
    out.append('        !byte %-22d; lock/door pairs: lock x, y, door x, y' % len(L['locks']))
    for (lx, ly), (dx, dy) in L['locks']:
        out.append('        !byte %d, %d, %d, %d' % (lx, ly, dx, dy))
    return '\n'.join(out) + '\n'


def write(label, text):
    s = open(MAPDATA, newline='').read()
    nl = '\r\n' if '\r\n' in s else '\n'
    s = s.replace('\r\n', '\n')
    lines = s.split('\n')
    start = lines.index(label)
    while start > 0 and lines[start - 1].startswith(';') and not lines[start - 1].startswith('; ' + label + '..'):
        start -= 1
    end = lines.index(label) + 1
    while end < len(lines) and lines[end].startswith('        '):
        end += 1
    lines[start:end] = text.rstrip('\n').split('\n')
    open(MAPDATA, 'w', newline='').write('\n'.join(lines).replace('\n', nl))
    print('written', label, 'into', os.path.normpath(MAPDATA))


def main():
    args = sys.argv[1:]
    sets = [args[i + 1] for i, a in enumerate(args) if a == '--set']
    path = [a for i, a in enumerate(args) if not a.startswith('--') and (i == 0 or args[i - 1] != '--set')][0]
    label, title, desc, art = load(path)
    art = [list(r) for r in art]
    for s in sets:
        x, y, c = s.split(',', 2)
        art[int(y)][int(x)] = c
    art = [''.join(r) for r in art]
    robot, L = parse(art)
    lvl = dict(robot=(robot[0], robot[1], DIRN[robot[2]]), goals=L['goals'], boxes=L['boxes'],
               trees=set(L['trees']), water=set(L['water']), ice=set(L['ice']),
               keys=L['keys'], locks=L['locks'])
    t = time.time()
    prog, nodes = (sl.solve_greedy if '--greedy' in args else sl.solve)(lvl)
    tag = label + (' ' + ' '.join(sets) if sets else '')
    if prog is None:
        print('%s: NO SOLUTION (%d states)' % (tag, nodes))
    else:
        print('%s: %2d commands  %s   (%d states, %.1fs)' % (
            tag, len(prog), ''.join(sl.KEYS[p] for p in prog), nodes, time.time() - t))
    if '--write' in args and not sets:
        write(label, record(label, title, desc, art, robot, L))


if __name__ == '__main__':
    main()
