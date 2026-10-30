#!/usr/bin/env python3
"""Preview: planning-map tiles (8x8 multicolour chars, 4x8 mc pixels), derived
from the run cells (gen_gfx_run.py) plus hand-drawn robot. Prints ACME !byte lines."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_gfx_run as g

VAL = {'.':0, 'g':1, 'l':2, 'c':3}

def down(cell):
    rows = cell.strip('\n').split('\n')
    out = []
    for y in range(0, 16, 2):
        line = ''
        for x in range(0, 8, 2):
            blk = [rows[y][x], rows[y][x+1], rows[y+1][x], rows[y+1][x+1]]
            if 'c' in blk: line += 'c'
            elif blk.count('.') >= 2: line += '.'
            elif blk.count('l') >= 2: line += 'l'
            else: line += 'g'
        out.append(line)
    return out

def enc(rows):
    assert len(rows) == 8 and all(len(r) == 4 for r in rows), rows
    bs = []
    for r in rows:
        v = 0
        for ch in r: v = (v << 2) | VAL[ch]
        bs.append(v)
    return bs

ROBOT = {   # white robot (c) on grass; the black visor shows where it looks
 'right': ["gccg","cc..","cc..","cccc","cccc",".cc.","c..c","c..c"],
 'left':  ["gccg","..cc","..cc","cccc","cccc",".cc.","c..c","c..c"],
 'up':    ["gccg","cccc","cccc","cccc","cccc",".cc.","c..c","c..c"],
 'down':  ["gccg","cccc","c..c","cccc","cccc",".cc.","c..c","c..c"],
}
# One grass tile with a single dot near the centre of the cell: easy to count rows/columns.
GRASS = ["gggg","gggg","gggg","gg.g","gggg","gggg","gggg","gggg"]
GOAL  = ["gggg","g..g",".cc.","c..c","c..c",".cc.","g..g","gggg"]
CHEST = ["gggg","....",".cc.",".cc.",".ll.",".cc.","....","gggg"]
TREE  = ["g..g",".ll.",".lg.",".gg.",".cc.",".cc.","g..g","gggg"]
WATER = ["cccc","c.cc",".c.c","cccc","cccc","cc.c","c.c.","cccc"]
# Winter theme (snow, pines, ice lake): same tile order as above, see
# gen_theme_winter.py. The robot arrows are shared by all themes.
W_FLOOR = ["gggg","gggg","gggg","gglg","gggg","gggg","gggg","gggg"]
W_TREE  = ["g..g",".gg.",".cc.",".cc.","cccc","g..g","g..g","gggg"]
W_WATER = ["cccc","cgcc","ccgc","cccc","cccc","cc.c","cgcc","cccc"]
# Ice (frozen water, both themes): light ice with white glints.
ICE     = ["cccc","cgcc","gccc","cccc","ccgc","cgcc","cccc","cccc"]
WINTER_TILES = [('snow (floor)', W_FLOOR), ('goal', GOAL), ('package (chest)', CHEST),
                ('blocker (pine)', W_TREE), ('water (ice lake)', W_WATER), ('ice', ICE)]

tiles = []   # (comment, rows)
for d in ('right','left','up','down'):
    tiles.append(('robot '+d, ROBOT[d]))
tiles.append(('grass (floor)', GRASS))
tiles.append(('goal', GOAL))
tiles.append(('package (chest)', CHEST))
tiles.append(('blocker (tree)', TREE))
tiles.append(('water', WATER))
tiles.append(('ice (frozen water)', ICE))

if __name__ == '__main__':
    for name, rows in tiles:
        print('; ' + name)
        for r in rows: print(';   ' + r)
        print('        !byte ' + ','.join('$%02X' % b for b in enc(rows)))
