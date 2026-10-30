#!/usr/bin/env python3
"""gen_gfx_run.py - generates src/gfx_run.asm (run screen graphics).

RPG look (Lykia / NES & SNES Final Fantasy): multicolour 16x16 field cells,
NES-style window frame, pointing-hand cursor and a multicolour robot sprite
with a two-frame walk cycle.

Usage:  python tools/gen_gfx_run.py          (writes src/gfx_run.asm)

Multicolour character pixels (each is 2 hires pixels wide):
  .  = %00  $D021  background (black, outlines and shadows)
  g  = %01  $D022  grass green          (RUN_BG1)
  l  = %10  $D023  light green          (RUN_BG2)
  c  = %11  colour RAM (0-7, +8 = multicolour flag), per cell type
Hires characters (UI): X = pixel set.
Multicolour sprite pixels:
  .  = transparent   B = $D025 (black)   c = sprite colour   W = $D026 (white)
"""
import os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', 'src', 'gfx_run.asm')

# ---------------------------------------------------------------- field cells
# 8 multicolour pixels x 16 rows per cell, split into 4 characters
# (TL, TR, BL, BR). Order = display tile index (see run.asm run_disp_*).
CELLS = {}

CELLS['grass'] = """
gggggggg
gggggglg
ggggglgl
ggggg.g.
glgggggg
l.lggggg
.g.ggggg
gggggggg
gggggggg
ggggggg.
gggglggg
ggglglgg
ggg.g.gg
gggggggg
gglggggg
g.g.gggg
"""

CELLS['tree'] = """
gg....gg
g.llgg.g
.llgggg.
.lgglgg.
.lglggg.
.ggggg..
.gggg.g.
.ggg.gg.
g.gggg.g
g..gg..g
gg....gg
ggg.c.gg
ggg.c.gg
gg..cc.g
gg.....g
ggg...gg
"""

CELLS['chest'] = """
gggggggg
gggggggg
gg....gg
g.cccc.g
.cccccc.
.c....c.
.cccccc.
........
.cc..cc.
.cc.l.c.
.cc..cc.
.cccccc.
.c....c.
.cccccc.
g......g
gg....gg
"""

CELLS['goal'] = """
gggggggg
ggg..ggg
gg.cc.gg
g.c..c.g
.c.cc.c.
.c.cc.c.
c.c..c.c
c.c..c.c
c.c..c.c
c.c..c.c
.c.cc.c.
.c.cc.c.
g.c..c.g
gg.cc.gg
ggg..ggg
gggggggg
"""

CELLS['flowers'] = """
gggggggg
ggcggggg
gc.cgggg
ggcggggg
gggggglg
ggggglgl
ggggg.g.
gggggggg
gggggggg
gglggggg
glglggcg
g.g.gc.c
ggggggcg
gggggggg
gggggggg
gggggggg
"""

# Water (river): blue body (colour RAM) with dark ripples. Blocks walking and
# dropping, but can be jumped over and thrown across.
CELLS['water'] = """
cccccccc
cccccccc
cc..cccc
c.cc.ccc
cccccccc
cccccccc
ccccc..c
cccc.cc.
cccccccc
cccccccc
c..ccccc
.cc.cccc
cccccccc
cccccccc
cccc..cc
ccc.cc.c
"""

# Path (world map only): sandy dirt road in colour RAM (yellow) with pebbles.
# The only walkable cell of the world maps besides the level nodes.
CELLS['path'] = """
cccccccc
ccccc.cc
cccccccc
c.cccccc
cccccccc
cccccccc
cccc.ccc
cccccccc
cccccccc
cc.ccccc
cccccccc
cccccc.c
cccccccc
c.cccccc
cccccccc
cccccccc
"""

# Wooden double gate (world map): closes the exit of a world until all its
# levels are solved. Left and right half, wood in colour RAM.
CELLS['gate_l'] = """
........
.cccccc.
.cccccc.
........
.ccc.cc.
.ccc.cc.
.ccc.cc.
.cccccc.
.cccccc.
.ccc.cc.
.ccc.cc.
.ccc.cc.
.ccc.cc.
........
.cccccc.
........
"""

CELLS['gate_r'] = """
........
.cccccc.
.cccccc.
........
.cc.ccc.
.cc.ccc.
.cc.ccc.
.cccccc.
.cccccc.
.cc.ccc.
.cc.ccc.
.cc.ccc.
.cc.ccc.
........
.cccccc.
........
"""

# Archway (world map): the way back to the previous world. Dark passage in a
# frame (colour RAM), the ground shows through at the bottom.
CELLS['arch'] = """
..cccc..
.cccccc.
cc....cc
c......c
c......c
c......c
c......c
c......c
c......c
c......c
c......c
c......c
c......c
c.gggg.c
cggggggc
cccccccc
"""

# Ice (frozen water, T_ICE): smooth ice in colour RAM with white glints and
# light shadow streaks. The robot skates over it.
CELLS['ice'] = """
cccccccc
ccgccccc
cgcclccc
cccccccc
ccccccgc
cccclgcc
cccccccc
cclccccc
cccccccc
cgcccccc
gcccclcc
cccccccc
ccccgccc
cccgcccc
cclccccc
cccccccc
"""

# Broken ice (T_BROKEN, after a failed run): dark water in colour RAM, white
# floes with black cracks.
CELLS['broken'] = """
gg.cccc.
g.cc.gg.
.ccc.gl.
cc.gg.c.
c.gllg.c
cc.gg.cc
.ccccccc
gg.cc.gg
gl.cc.gl
.gg.cc..
c..ccccc
ccc.gg.c
cc.glgg.
.c.gg.cc
gg.cc.cg
gl.c.ggc
"""

CELL_ORDER = ['grass', 'tree', 'chest', 'goal', 'flowers', 'water', 'path', 'gate_l', 'gate_r', 'arch',
              'ice', 'broken']

# ---------------------------------------------------------------- UI chars
# NES Final Fantasy window frame (rounded corners) and the pointing hand.
UI = {}
UI['tl'] = """
........
........
........
....XXXX
...XXXXX
...XX...
...XX...
...XX...
"""
UI['top'] = """
........
........
........
XXXXXXXX
XXXXXXXX
........
........
........
"""
UI['tr'] = """
........
........
........
XXXX....
XXXXX...
...XX...
...XX...
...XX...
"""
UI['left'] = """
...XX...
...XX...
...XX...
...XX...
...XX...
...XX...
...XX...
...XX...
"""
UI['right'] = UI['left']
UI['bl'] = """
...XX...
...XX...
...XX...
...XXXXX
....XXXX
........
........
........
"""
UI['bottom'] = UI['top']
UI['br'] = """
...XX...
...XX...
...XX...
XXXXX...
XXXX....
........
........
........
"""
UI['hand'] = """
........
.XXXX...
X....XXX
X..XXXX.
X...XX..
X..XXX..
.XXXX...
........
"""
UI_ORDER = ['tl', 'top', 'tr', 'left', 'right', 'bl', 'bottom', 'br', 'hand']

# ---------------------------------------------------------------- sprites
# Robot: 8 multicolour pixels wide, 18 rows. The sprite is placed 2 lines
# above its 16x16 cell (antenna pokes into the cell above, RPG style).
HEAD_DOWN = """
...BB...
..BWWB..
...BB...
..BBBB..
.BcWWcB.
.BWcccB.
.BBBBBB.
.BWBBWB.
.BBBBBB.
..BccB..
"""
HEAD_UP = """
...BB...
..BWWB..
...BB...
..BBBB..
.BcWWcB.
.BWcccB.
.BccccB.
.BccccB.
.BBccBB.
..BccB..
"""
HEAD_RIGHT = """
...BB...
..BWWB..
...BB...
..BBBB..
.BcWWcB.
.BWcccB.
.BccBBB.
.BccBWB.
.BccBBB.
..BccB..
"""
BODY_FRONT = """
.BBBBBB.
BcBccBcB
BcBWcBcB
BBBccBBB
.BBBBBB.
"""
BODY_FRONT_CARRY = """
.BBBBBB.
.BccccB.
.BcWccB.
.BccccB.
.BBBBBB.
"""
BODY_SIDE = """
..BBBB..
.BccBcB.
.BccBcB.
.BccBBB.
..BBBB..
"""
BODY_SIDE_CARRY = """
..BBBB..
.BcccWB.
.BccccB.
.BccccB.
..BBBB..
"""
# Two walk frames: feet apart / one foot lifted (plus a one-line bob).
LEGS_FRONT = ["""
.BcBBcB.
.BB..BB.
........
""", """
.BcBBB..
.BB.....
........
"""]
LEGS_SIDE = ["""
..BcBB..
..BBBB..
........
""", """
.BcB.BcB
.BB...BB
........
"""]

def rows(s):
    r = [x for x in s.strip('\n').split('\n')]
    for x in r:
        assert len(x) == 8, (x, len(x))
    return r

def robot(view, carry, step):
    if view == 'down':
        head, body = rows(HEAD_DOWN), rows(BODY_FRONT_CARRY if carry else BODY_FRONT)
        legs = rows(LEGS_FRONT[step])
    elif view == 'up':
        head, body = rows(HEAD_UP), rows(BODY_FRONT_CARRY if carry else BODY_FRONT)
        body = [r.replace('W', 'c') for r in body]
        legs = rows(LEGS_FRONT[step])
    else:
        head, body = rows(HEAD_RIGHT), rows(BODY_SIDE_CARRY if carry else BODY_SIDE)
        legs = rows(LEGS_SIDE[step])
    img = head + body + legs
    if step:                    # walk bob: one line up on the step frame
        img = img[1:] + ['........']
    return img

def mirror(img):
    return [r[::-1] for r in img]

# Chest held above the head; the white gloves are part of this sprite.
CHEST_SPRITE = """
.BBBBBB.
.BcWccB.
.BBBBBB.
.BcBBcB.
WBccccBW
WBccccBW
.BBBBBB.
"""

def sprite_images():
    imgs = []
    names = []
    for step in (0, 1):
        for carry in (0, 1):
            r = robot('right', carry, step)
            for d, img in (('right', r), ('left', mirror(r)),
                           ('up', robot('up', carry, step)),
                           ('down', robot('down', carry, step))):
                imgs.append(img)
                names.append('robot %s%s%s' % (d, ', carrying' if carry else '',
                                               ', step' if step else ''))
    imgs.append(rows(CHEST_SPRITE))
    names.append('package (chest) carried above the head')
    return names, imgs

# ---------------------------------------------------------------- encoders
MC_CHAR = {'.': 0, 'g': 1, 'l': 2, 'c': 3}
MC_SPR = {'.': 0, 'B': 1, 'c': 2, 'W': 3}

def mc_byte(px, table):
    v = 0
    for p in px:
        v = (v << 2) | table[p]
    return v

def cell_chars(art):
    r = [x for x in art.strip('\n').split('\n')]
    assert len(r) == 16 and all(len(x) == 8 for x in r), art
    chars = []
    for (y0, x0) in ((0, 0), (0, 4), (8, 0), (8, 4)):
        chars.append([mc_byte(r[y][x0:x0 + 4], MC_CHAR) for y in range(y0, y0 + 8)])
    return r, chars

def hires_char(art):
    r = [x for x in art.strip('\n').split('\n')]
    assert len(r) == 8 and all(len(x) == 8 for x in r), art
    return r, [int(x.replace('.', '0').replace('X', '1'), 2) for x in r]

def sprite_bytes(img):
    data = []
    for y in range(21):
        line = img[y] if y < len(img) else '........'
        line = line + '.' * (12 - len(line))
        data += [mc_byte(line[0:4], MC_SPR), mc_byte(line[4:8], MC_SPR),
                 mc_byte(line[8:12], MC_SPR)]
    return data + [0]

def hexrow(b):
    return '        !byte ' + ','.join('$%02X' % x for x in b)

def main():
    o = []
    o.append('; gfx_run.asm - run screen graphics. GENERATED by tools/gen_gfx_run.py,')
    o.append('; edit the ASCII art there and re-run the script instead of editing this file.')
    o.append(';')
    o.append('; Multicolour field cells (16x16 px = 2x2 characters TL,TR,BL,BR) from')
    o.append('; RUN_CHAR_BASE: ' + ', '.join(CELL_ORDER) + '.')
    o.append(';   . = $D021 black   g = $D022 green   l = $D023 light green   c = colour RAM')
    o.append('; Then hires UI characters: ' + ', '.join(UI_ORDER) + '.')
    o.append('gfx_run')
    for name in CELL_ORDER:
        art, chars = cell_chars(CELLS[name])
        o.append('; --- ' + name)
        for a in art:
            o.append(';   ' + a)
        for ch in chars:
            o.append(hexrow(ch))
    for name in UI_ORDER:
        art, b = hires_char(UI[name])
        o.append('; --- ' + name)
        for a in art:
            o.append(';   ' + a)
        o.append(hexrow(b))
    o.append('gfx_run_end')
    o.append('!if gfx_run_end - gfx_run != RUN_CHAR_BYTES {')
    o.append('    !error "RUN_CHAR_BYTES passt nicht zu den Run-Zeichendaten"')
    o.append('}')
    o.append('')
    o.append('; Multicolour sprites (12x21, art in the left 8 columns):')
    o.append(';   . = transparent   B = $D025 black   c = sprite colour   W = $D026 white')
    o.append('; Robot images: index = direction (right, left, up, down) + 4 carrying')
    o.append('; + 8 walk step. Image 16 = the carried package.')
    o.append('gfx_run_sprites')
    names, imgs = sprite_images()
    for n, img in zip(names, imgs):
        o.append('; --- ' + n)
        for a in img:
            o.append(';   ' + a)
        b = sprite_bytes(img)
        for i in range(0, 63, 3):
            o.append(hexrow(b[i:i + 3]))
        o.append(hexrow([b[63]]))
    o.append('gfx_run_sprites_end')
    o.append('!if gfx_run_sprites_end - gfx_run_sprites != RUN_SPR_BYTES {')
    o.append('    !error "RUN_SPR_BYTES passt nicht zu den Run-Spritedaten"')
    o.append('}')
    o.append('')
    with open(OUT, 'w', newline='\n') as f:
        f.write('\n'.join(o))
    print('wrote', os.path.normpath(OUT), '-', len(CELL_ORDER) * 4 + len(UI_ORDER),
          'chars,', len(imgs), 'sprites')

if __name__ == '__main__':
    main()
