#!/usr/bin/env python3
"""mock_vdc.py - Layout-Mocks fuer den C128-VDC (80x25 Zeichen, 8x8 Pixel, 640x200).

Baut Bildschirme aus Zeichen + Attribut nach den VDC-Regeln: pro Zeichen EINE
Vordergrundfarbe (RGBI, 16 Farben), Hintergrund global (hier schwarz), Attribut-Bit
"reverse" fuer Hervorhebungen. Ausgabe als PNG mit VDC-Pixelseitenverhaeltnis (1:2):
  python -B tools/mock_vdc.py out/dir
Nur fuer die Layout-Diskussion (Schritt 4); Text-Glyphen sind synthetisch (kein ROM)."""
import sys, os
from PIL import Image, ImageDraw, ImageFont

RGBI = [0x000000, 0x555555, 0x0000AA, 0x5555FF, 0x00AA00, 0x55FF55, 0x00AAAA, 0x55FFFF,
        0xAA0000, 0xFF5555, 0xAA00AA, 0xFF55FF, 0xAA5500, 0xFFFF55, 0xAAAAAA, 0xFFFFFF]
BLK, DGRY, DBLU, LBLU, DGRN, LGRN, DCYN, LCYN, DRED, LRED, DPUR, LPUR, BRN, YEL, LGRY, WHT = range(16)
COLS, ROWS = 80, 25

FONT = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf', 9)
_gcache = {}


def glyph(ch):
    if ch not in _gcache:
        im = Image.new('1', (8, 8), 0)
        ImageDraw.Draw(im).text((1, -2), ch, font=FONT, fill=1)
        _gcache[ch] = [[im.getpixel((x, y)) for x in range(8)] for y in range(8)]
    return _gcache[ch]


def frame_glyph(kind):
    g = [[0] * 8 for _ in range(8)]
    h = kind in ('tl', 'tr', 'bl', 'br', 'h')
    v = kind in ('tl', 'tr', 'bl', 'br', 'v')
    if kind == 'h':
        for x in range(8): g[3][x] = g[4][x] = 1
    elif kind == 'v':
        for y in range(8): g[y][3] = g[y][4] = 1
    else:
        for x in range(8):
            if (kind in ('tl', 'bl') and x >= 3) or (kind in ('tr', 'br') and x <= 4):
                g[3][x] = g[4][x] = 1
        for y in range(8):
            if (kind in ('tl', 'tr') and y >= 3) or (kind in ('bl', 'br') and y <= 4):
                g[y][3] = g[y][4] = 1
    return g


def solid():
    return [[1] * 8 for _ in range(8)]


class Screen:
    def __init__(self):
        self.g = [[None] * COLS for _ in range(ROWS)]   # glyph bitmap
        self.c = [[WHT] * COLS for _ in range(ROWS)]
        self.r = [[False] * COLS for _ in range(ROWS)]

    def put(self, x, y, g, col, rev=False):
        if 0 <= x < COLS and 0 <= y < ROWS:
            self.g[y][x] = g; self.c[y][x] = col; self.r[y][x] = rev

    def text(self, x, y, s, col=WHT, rev=False):
        for i, ch in enumerate(s):
            self.put(x + i, y, glyph(ch) if ch != ' ' else None, col, rev)

    def fill_rev(self, x, y, w, col):
        for i in range(w):
            if self.g[y][x + i] is None: self.put(x + i, y, None, col, True)
            else: self.r[y][x + i] = True; self.c[y][x + i] = col

    def window(self, x, y, w, h, col=LCYN, title=None, tcol=WHT):
        self.put(x, y, frame_glyph('tl'), col); self.put(x + w - 1, y, frame_glyph('tr'), col)
        self.put(x, y + h - 1, frame_glyph('bl'), col); self.put(x + w - 1, y + h - 1, frame_glyph('br'), col)
        for i in range(1, w - 1):
            self.put(x + i, y, frame_glyph('h'), col); self.put(x + i, y + h - 1, frame_glyph('h'), col)
        for j in range(1, h - 1):
            self.put(x, y + j, frame_glyph('v'), col); self.put(x + w - 1, y + j, frame_glyph('v'), col)
        if title: self.text(x + 2, y, ' %s ' % title, tcol)

    def tile(self, x, y, t):
        """t: list of 16 strings x 32 px ('#' set, else clear) + list of 8 colours (row-major 4x2)."""
        art, cols = t
        for cy in range(2):
            for cx in range(4):
                g = [[1 if art[cy * 8 + yy][cx * 8 + xx] == '#' else 0 for xx in range(8)] for yy in range(8)]
                self.put(x + cx, y + cy, g, cols[cy * 4 + cx])

    def render(self, path):
        im = Image.new('RGB', (COLS * 8, ROWS * 8), RGBI[BLK])
        px = im.load()
        for y in range(ROWS):
            for x in range(COLS):
                g = self.g[y][x]; c = RGBI[self.c[y][x]]; rev = self.r[y][x]
                fg = ((c >> 16) & 255, (c >> 8) & 255, c & 255)
                for yy in range(8):
                    for xx in range(8):
                        on = bool(g and g[yy][xx]) != rev
                        if on: px[x * 8 + xx, y * 8 + yy] = fg
        # VDC-Pixel: doppelt so hoch wie breit -> 2x horizontal, 4x vertikal (1280x800)
        im = im.resize((COLS * 16, ROWS * 32), Image.NEAREST)
        b = 24
        out = Image.new('RGB', (im.width + 2 * b, im.height + 2 * b), (20, 20, 20))
        out.paste(im, (b, b))
        out.save(path)


# ---- Kacheln: 4x2 Zeichen = 32x16 VDC-Pixel (wirkt wie 16x16 VIC-Pixel) -------------
def art(s):
    lines = [l for l in s.strip('\n').split('\n')]
    assert len(lines) == 16 and all(len(l) == 32 for l in lines), [len(l) for l in lines]
    return lines

GRASS = (art("""
################################
#####.##########.###############
################################
##########.###########.#########
###.############################
################.###############
#########.#####################.
################################
################################
####.##########.################
################################
#########.############.#########
################################
##.#########.###################
#####################.##########
################################
"""), [DGRN] * 8)

TREE = (art("""
.........##########.............
......################..........
....######.###########.##.......
...##############.#######.......
..#####.##################......
..########################......
...######.###############.......
....####################........
......##################........
........###############.........
...........###....##............
.............######.............
.............######.............
............########............
...........##########...........
................................
"""), [LGRN, LGRN, LGRN, LGRN, LGRN, BRN, BRN, LGRN])

WATER = (art("""
################################
################################
###....######....######....#####
#######......####......####.####
################################
################################
################################
#####....######....######....###
#########......####......#######
################################
################################
################################
##....######....######....######
######......####......####...###
################################
################################
"""), [DBLU] * 8)

GOAL = (art("""
................................
..........############..........
.......####..........####.......
.....###....########....###.....
....##....###......###....##....
....##...##..........##...##....
....##...##..........##...##....
....##....###......###....##....
.....###....########....###.....
.......####..........####.......
..........############..........
................................
................................
................................
................................
................................
"""), [LCYN, LCYN, LCYN, LCYN, LCYN, LCYN, LCYN, LCYN])

CHEST = (art("""
................................
.....######################.....
....##....................##....
....#.######################....
....#.######################....
....#.######################....
....########################....
....########################....
....#######..........#######....
....########################....
....########################....
....#.######################....
....#.######################....
....##....................##....
.....######################.....
................................
"""), [BRN, BRN, BRN, BRN, BRN, YEL, YEL, BRN])

ROBOT = (art("""
..........############..........
.........##############.........
.........###..####..###.........
.........###..####..###.........
.........##############.........
..........###......###..........
...........##########...........
.......##################.......
......####################......
......###.####....####.###......
......###.############.###......
......###.############.###......
.........##############.........
.........####......####.........
........#####......#####........
................................
"""), [WHT, LGRY, LGRY, WHT, WHT, LGRY, LGRY, WHT])

PATH = (art("""
################################
################################
#######.########################
######################.#########
################################
###.############################
################################
#############.##########.#######
################################
################################
#######################.########
####.###########################
################################
#############.##################
################################
################################
"""), [BRN] * 8)

FLOWERS = (art("""
################################
###.#.##########################
####.###################.#.#####
###.#.###################.######
########################.#.#####
################################
##########.#.###################
###########.####################
##########.#.###################
######################.#.#######
#######################.########
##.#.#################.#.#######
###.############################
##.#.#############.#.###########
###################.############
##################.#.###########
"""), [DGRN] * 8)   # VDC: eine Farbe pro Zeichen - Blumen als Aussparungen im Gras

NODE = (art("""
################################
###########..........###########
#########..##########..#########
########.##############.########
########.##############.########
#########..##########..#########
###########..........###########
################################
################################
################################
################################
################################
################################
################################
################################
################################
"""), [BRN, YEL, YEL, BRN, BRN, BRN, BRN, BRN])

ICONS = {}


def icon(name, lines, col):
    ICONS[name] = (art(lines), [col] * 8)

icon('fwd', """
................................
...............##...............
..............####..............
.............######.............
............########............
...........##########...........
..............####..............
..............####..............
..............####..............
..............####..............
..............####..............
..............####..............
..............####..............
................................
................................
................................
""", WHT)
ICONS['back'] = ([l for l in ICONS['fwd'][0][12::-1]] + ICONS['fwd'][0][13:], [WHT] * 8)
icon('left', """
................................
................................
..........##....................
.........###....................
........##############..........
.......###############..........
........##############..........
.........###.........###........
..........##.........###........
.....................###........
.....................###........
.....................###........
.....................###........
................................
................................
................................
""", LCYN)
ICONS['right'] = ([l[::-1] for l in ICONS['left'][0]], [LCYN] * 8)
icon('turn', """
................................
...........##########...........
.........###........###.........
........###..........###........
........###..........###........
........###..........###........
........###.......########......
........###........######.......
........###.........####........
........###..........##.........
........###.....................
........###.....................
........###.....................
................................
................................
................................
""", LCYN)
icon('pick', """
................................
...............##...............
.............######.............
...............##...............
...............##...............
..........############..........
.........##..........##.........
.........##############.........
.........##############.........
.........##############.........
..........############..........
................................
................................
................................
................................
................................
""", LGRN)
ICONS['drop'] = (ICONS['pick'][0][:], [LPUR] * 8)
ICONS['drop'] = ([ICONS['pick'][0][0]] + [ICONS['pick'][0][3], ICONS['pick'][0][2].replace('######', '..##..'),
                 '.............######.............'] + ICONS['pick'][0][4:], [LPUR] * 8)
icon('jump', """
................................
...........#########............
.........###.......###..........
........##...........##.........
.......##.............##........
......##...............##.......
.....##.................##......
....######.............###......
.....####..............###......
......##........................
................................
.....##################.........
................................
................................
................................
................................
""", WHT)
icon('throw', """
................................
.............########...........
...........##........##.........
.........##............##.......
........##..............##......
.......##...........#######.....
......##............##...##.....
.....#####..........#######.....
......###.......................
.......#........................
.....####.......................
.....####.......................
.....####.......................
................................
................................
................................
""", LPUR)

LEVEL = """
TTTTTTTTTT
TTTTTTTTTT
TTTTTTTTTT
T>.PP~...T
TTTTTTTT.T
TTTTTTTT.T
TGGG.~P.PT
TTTTTTTTTT
TTTTTTTTTT
TTTTTTTTTT
""".split()

PROGRAM = ['Move Fwd', 'Pick Up', 'Move Back', 'Drop Off', 'Jump', 'Pick Up', 'Move Fwd',
           'Jump', 'Jump', 'Turn Right', 'Drop Off', 'Jump', 'Pick Up', 'Move Fwd', 'Turn Left',
           'Move Back', 'Drop Off', 'Turn 180', 'Pick Up', 'Move Fwd', 'Jump', 'Throw',
           'Turn 180', 'Jump', 'Move Fwd']
CMD_COL = {'Move': WHT, 'Turn': LCYN, 'Pick': LGRN, 'Drop': LPUR, 'Jump': WHT, 'Thro': LPUR}


def draw_field(s, x0, y0, robot=(1, 3), boxes_override=None):
    for r, line in enumerate(LEVEL):
        for c, ch in enumerate(line):
            t = {'T': TREE, '~': WATER, 'G': GOAL, 'P': CHEST}.get(ch, GRASS)
            if boxes_override is not None and ch in 'PG':
                t = GOAL if ch == 'G' else GRASS
            s.tile(x0 + c * 4, y0 + r * 2, t)
    if boxes_override:
        for (c, r), t in boxes_override.items():
            s.tile(x0 + c * 4, y0 + r * 2, t)
    s.tile(x0 + robot[0] * 4, y0 + robot[1] * 2, ROBOT)


def palette(s, x, y, keyrow=True):
    grid = [('q', 'pick', 'Pick Up'), ('w', 'fwd', 'Fwd'), ('e', 'drop', 'Drop Off'),
            ('a', 'left', 'Left'), ('s', 'back', 'Back'), ('d', 'right', 'Right'),
            ('z', 'jump', 'Jump'), ('x', 'turn', 'U-Turn'), ('c', 'throw', 'Throw')]
    return grid


# ---- Variante A: Spielfeld links, Palette oben rechts, Programm zweispaltig -------
def variant_a(run=False):
    s = Screen()
    s.text(0, 0, ' ArtyBot ', YEL, rev=True)
    s.text(10, 0, 'World 1: Meadow   Level 5 "Bottleneck"', WHT)
    s.text(66, 0, ' RUN  ' if run else ' PLAN ', YEL if run else LGRN, rev=True)
    s.text(73, 0, 'Par --', LGRY)
    s.window(0, 1, 42, 22, LCYN, 'Meadow 5')
    if run:
        draw_field(s, 1, 2, robot=(4, 3), boxes_override={(3, 3): CHEST, (6, 3): CHEST, (6, 6): CHEST, (8, 6): CHEST})
        s.text(2, 22, ' Delivered: 0/3 ', WHT)
    else:
        draw_field(s, 1, 2)
    # Palette
    s.window(42, 1, 38, 8, LCYN, 'Commands')
    for i, (k, ic, name) in enumerate(palette(s, 0, 0)):
        cx, cy = 44 + (i % 3) * 11, 2 + (i // 3) * 2
        s.tile(cx, cy, ICONS[ic] if not run else (ICONS[ic][0], [DGRY] * 8))
        s.text(cx + 4, cy, k.upper(), YEL if not run else DGRY)
        s.text(cx + 4, cy + 1, name[:8], (ICONS[ic][1][0]) if not run else DGRY)
    # Programm
    s.window(42, 9, 38, 14, LCYN, 'Program 25/99')
    for i, cmd in enumerate(PROGRAM[:24]):
        cx, cy = 44 + (i // 12) * 17, 10 + i % 12
        s.text(cx, cy, '%02d' % (i + 1), LGRY)
        s.text(cx + 3, cy, cmd, CMD_COL[cmd[:4]])
    if run:
        s.fill_rev(43, 14, 17, YEL)           # laufender Befehl (Attribut reverse)
        s.text(43, 14, '>', YEL, rev=True)
    else:
        s.text(43, 17, '>', YEL)               # Einfuegemarke
    s.put(78, 10, glyph('^'), WHT); s.put(78, 21, glyph('v'), WHT)
    for j in range(11, 21): s.put(78, j, solid() if j < 15 else None, DGRY)
    # Info / Nachricht
    if run:
        s.text(1, 23, 'Running...  Space: pause   R: restart', WHT)
        s.text(0, 24, 'Space:Go R:Redo F1:Edit F7:Map F8:Title', LGRY)
    else:
        s.text(1, 23, 'Hover: "Package - pick it up with Q, drop it on a target with E"', LGRY)
        s.text(0, 24, 'QWEASDZXC:add  Cursor:marker  Ret:edit  Del:delete  F1:Run  F7:Map  F8:Title', LGRY)
    return s


# ---- Variante B: drei Spalten - Feld | Palette + Legende | Programm hoch -------------
def variant_b(run=False):
    s = Screen()
    s.window(0, 0, 42, 23, LCYN, 'Meadow 5 - Bottleneck')
    draw_field(s, 1, 1, robot=(4, 3) if run else (1, 3),
               boxes_override={(3, 3): CHEST, (6, 3): CHEST, (6, 6): CHEST, (8, 6): CHEST} if run else None)
    s.text(2, 22, ' Delivered: 0/3 ', WHT)
    s.window(42, 0, 20, 11, LCYN, 'Commands')
    for i, (k, ic, name) in enumerate(palette(s, 0, 0)):
        cx, cy = 43 + (i % 3) * 6, 1 + (i // 3) * 3
        s.tile(cx + 1, cy, ICONS[ic] if not run else (ICONS[ic][0], [DGRY] * 8))
        s.text(cx + 2, cy + 2, k.upper(), YEL if not run else DGRY)
    s.window(42, 11, 20, 12, LCYN, 'Legend')
    leg = [('ArtyBot', ROBOT, 'looking right'), ('Target', GOAL, None), ('Package', CHEST, None),
           ('Tree', TREE, None), ('Water', WATER, None)]
    for i, (n, t, sub) in enumerate(leg):
        y = 12 + i * 2
        s.tile(43, y, t)
        s.text(48, y, n, WHT)
        if sub: s.text(48, y + 1, sub, LGRY)
    s.window(62, 0, 18, 23, LCYN, 'Program 25')
    for i, cmd in enumerate(PROGRAM[:21]):
        s.text(64, 1 + i, '%02d' % (i + 1), LGRY)
        s.text(67, 1 + i, cmd, CMD_COL[cmd[:4]])
    if run:
        s.fill_rev(63, 5, 15, YEL)
        s.text(63, 5, '>', YEL, rev=True)
    else:
        s.text(63, 8, '>', YEL)
    s.text(0, 23, (' RUN ' if run else ' PLAN '), YEL if run else LGRN, rev=True)
    s.text(7, 23, 'Running... Space: pause  R: restart' if run else 'Package: pick it up with Q, drop it on a target with E', WHT if run else LGRY)
    s.text(0, 24, 'Space:Go  R:Redo  F1:Edit  F7:Map  F8:Title' if run else
           'QWEASDZXC:add Cursor:marker Ret:edit Del:delete  F1:Run  F7:Map  F8:Title', LGRY)
    return s


# ---- Weltkarte: 19x10 Zellen a 4x2 Zeichen = 76x20 -----------------------------------
WORLD = """
TTTT[]TTTTT~~TTTTTT
T,1.S..*T,,~~*T,4.T
T,*T,,.,TT,~~,,T*.T
T,TT*,.,,T*~~,TT,.T
TT,....T,*~~,,T,..T
T*,.TTT,,~~,*T,..,T
T,..,T*,~~,T,3..T,T
T,.2*T,,,~*,TT,..5T
T,..............TTT
TTTTTTTTTTTTTTTTTTT
""".split()


def world_map():
    s = Screen()
    s.window(1, 0, 78, 22, LCYN, 'World 1: Meadow')
    for r, line in enumerate(WORLD):
        for c, ch in enumerate(line):
            t = {'T': TREE, '~': WATER, ',': GRASS, '*': FLOWERS, '[': TREE, ']': TREE}.get(ch, PATH)
            if ch in '12345':
                t = NODE if ch in '12' else (GOAL[0], [LCYN] * 8)
                t = NODE
            s.tile(2 + c * 4, 1 + r * 2, t)
            if ch in '12345':
                s.text(2 + c * 4 + 3, 1 + r * 2 + 1, ch, WHT)
    s.tile(2 + 4 * 4, 1 + 1 * 2, ROBOT)
    s.text(2, 22, 'Meadow 1 - solved   Space: play', WHT)
    s.text(1, 23, 'WASD/Cursor: walk to a level', LGRY)
    s.text(1, 24, 'Space:Play  F1:Stats  F3/F5:World  F8:Title', LGRY)
    return s


if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 else 'out/mock_vdc'
    os.makedirs(out, exist_ok=True)
    variant_a().render(os.path.join(out, 'A_plan.png'))
    variant_a(run=True).render(os.path.join(out, 'A_run.png'))
    variant_b().render(os.path.join(out, 'B_plan.png'))
    variant_b(run=True).render(os.path.join(out, 'B_run.png'))
    world_map().render(os.path.join(out, 'world_map.png'))
    print('ok', out)
