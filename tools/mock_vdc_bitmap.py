#!/usr/bin/env python3
"""mock_vdc_bitmap.py - Mocks fuer den C128-VDC im Bitmap-Modus (640x200, 1 Bit/Pixel)
mit Farbattributen pro 8x2-Pixel-Block (Zeichenhoehe 2 Zeilen): je Block eine Vorder- und
eine Hintergrundfarbe aus den 16 RGBI-Farben. Text wird als Bitmap gezeichnet.

  python -B tools/mock_vdc_bitmap.py out/dir

Gezeichnet wird frei in Farbe (640x200, Palettenindizes); vdc_quantize() erzwingt danach
die VDC-Regel (pro 8x2-Block die zwei haeufigsten Farben, Rest auf die naehere der beiden)
und meldet, wie viele Bloecke mehr als zwei Farben hatten. Speicherbedarf: Bitmap 16000 +
Attribute 8000 Byte = 24000 Byte -> braucht 64 KB VDC-RAM (C128D / aufgeruestet, x128 -VDC64KB).
Ausgabe mit VDC-Pixelseitenverhaeltnis (1 breit : 2 hoch), 1280x800."""
import sys, os
import numpy as np
from PIL import Image, ImageDraw, ImageFont

RGBI = [0x000000, 0x555555, 0x0000AA, 0x5555FF, 0x00AA00, 0x55FF55, 0x00AAAA, 0x55FFFF,
        0xAA0000, 0xFF5555, 0xAA00AA, 0xFF55FF, 0xAA5500, 0xFFFF55, 0xAAAAAA, 0xFFFFFF]
BLK, DGRY, DBLU, LBLU, DGRN, LGRN, DCYN, LCYN, DRED, LRED, DPUR, LPUR, BRN, YEL, LGRY, WHT = range(16)
RGB = np.array([[(v >> 16) & 255, (v >> 8) & 255, v & 255] for v in RGBI])
W, H = 640, 200
BW, BH = 8, 2                     # Farbblock

# ---- Schrift: DejaVu Mono Bold in 8x16 gerendert, vertikal 2:1 zusammengefasst -> 8x8
_FONT = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf', 13)
_gl = {}


def glyph(ch):
    if ch not in _gl:
        im = Image.new('L', (8, 16), 0)
        ImageDraw.Draw(im).text((0, 0), ch, font=_FONT, fill=255)
        a = np.array(im, dtype=np.int32)
        _gl[ch] = ((a[0::2] + a[1::2]) >= 200)     # 8 Zeilen x 8 Spalten
    return _gl[ch]


class Canvas:
    def __init__(self, bg=BLK):
        self.p = np.full((H, W), bg, dtype=np.uint8)

    def rect(self, x, y, w, h, c):
        self.p[max(0, y):y + h, max(0, x):x + w] = c

    def box(self, x, y, w, h, c, t=(2, 1)):
        """Rahmen: t = (Breite links/rechts in Pixeln, Hoehe oben/unten in Zeilen)."""
        self.rect(x, y, w, t[1], c); self.rect(x, y + h - t[1], w, t[1], c)
        self.rect(x, y, t[0], h, c); self.rect(x + w - t[0], y, t[0], h, c)

    def text(self, x, y, s, c, shadow=None):
        for i, ch in enumerate(s):
            g = glyph(ch)
            if shadow is not None:
                sub = self.p[y + 1:y + 9, x + i * 8 + 1:x + i * 8 + 9]
                sub[g[:sub.shape[0], :sub.shape[1]]] = shadow
            sub = self.p[y:y + 8, x + i * 8:x + i * 8 + 8]
            sub[g[:sub.shape[0], :sub.shape[1]]] = c

    def blit(self, x, y, tile):
        t = tile
        m = t != 255
        self.p[y:y + t.shape[0], x:x + t.shape[1]][m] = t[m]

    def panel(self, x, y, w, h, title, bg=DBLU, frame=LCYN, tbg=LCYN, tfg=BLK):
        self.rect(x, y, w, h, bg)
        self.rect(x, y, w, 10, tbg)
        self.text(x + 6, y + 1, title, tfg)
        self.box(x, y, w, h, frame)


def vdc_quantize(p):
    """Pro 8x2-Block hoechstens 2 Farben (VDC-Attribut: Vorder-/Hintergrund)."""
    out = p.copy(); bad = 0
    for by in range(0, H, BH):
        for bx in range(0, W, BW):
            blk = out[by:by + BH, bx:bx + BW]
            vals, cnt = np.unique(blk, return_counts=True)
            if len(vals) <= 2: continue
            bad += 1
            keep = vals[np.argsort(-cnt)[:2]]
            for v in vals:
                if v in keep: continue
                d = [np.sum((RGB[v] - RGB[k]) ** 2) for k in keep]
                blk[blk == v] = keep[int(np.argmin(d))]
    return out, bad


def save(p, path):
    q, bad = vdc_quantize(p)
    img = Image.fromarray(RGB[q].astype(np.uint8), 'RGB').resize((W * 2, H * 4), Image.NEAREST)
    out = Image.new('RGB', (img.width + 48, img.height + 48), (20, 20, 20))
    out.paste(img, (24, 24)); out.save(path)
    return bad


# ---- Kacheln 32x16 (Feldzelle; wirkt quadratisch) --------------------------------------
T = 255   # transparent


def tile():
    return np.full((16, 32), T, dtype=np.uint8)


def bare(seed=0):
    return tile()


def ellipse(t, cx, cy, rx, ry, c):
    yy, xx = np.mgrid[0:t.shape[0], 0:t.shape[1]]
    m = ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2 <= 1
    t[m] = c
    return m


# ---- Kacheln aus der C64-Grafik (tools/gen_gfx_run.py) ------------------------------
# C64-Zelle: 8 Multicolour-Pixel x 16 Zeilen (16x16 VIC-Pixel). VDC-Zelle: 32x16 Pixel,
# ein MC-Pixel = 4 VDC-Pixel breit, 1 Zeile hoch -> gleiche Groesse auf dem Bildschirm.
# Farben: '.' $D021 schwarz, 'g'/'l' die beiden Gruentoene, 'c' Farb-RAM der Zelle.
import gen_gfx_run as G

C64_BG = {'.': BLK, 'g': DGRN, 'l': LGRN}
CELL_C = {'grass': DGRN, 'tree': BRN, 'chest': BRN, 'goal': LCYN, 'flowers': YEL,
          'water': DBLU, 'path': BRN, 'ice': LCYN, 'broken': DBLU, 'key': YEL, 'lock': YEL,
          'lock_full': YEL, 'door': BRN, 'gate_l': BRN, 'gate_r': BRN, 'arch': WHT}
CELL_OVR = {'chest': {'l': YEL}, 'flowers': {}}


def c64cell(name):
    rows = [r for r in G.CELLS[name].strip('\n').split('\n')]
    cmap = dict(C64_BG); cmap['c'] = CELL_C[name]; cmap.update(CELL_OVR.get(name, {}))
    t = np.zeros((16, 32), dtype=np.uint8)
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            t[y, x * 4:x * 4 + 4] = cmap[ch]
    return t


SPR = {'.': T, 'B': BLK, 'c': LGRY, 'W': WHT}


def c64sprite(img, col=LGRY):
    m = dict(SPR); m['c'] = col
    t = np.full((len(img), 32), T, dtype=np.uint8)
    for y, r in enumerate(img):
        for x, ch in enumerate(r):
            t[y, x * 4:x * 4 + 4] = m[ch]
    return t


ROBOT_SPR = {d: c64sprite(G.robot(d, 0, 0) if d != 'left' else G.mirror(G.robot('right', 0, 0)))
             for d in ('right', 'left', 'up', 'down')}


def grass(seed=1): return c64cell('grass')
def tree(base=None): return c64cell('tree')
def goal(base=None): return c64cell('goal')
def water(seed=7): return c64cell('water')
def flowers(seed=3): return c64cell('flowers')
def path_tile(seed=15): return c64cell('path')
def node(n): return c64cell('goal')


def chest(on_goal=False, base=None):
    return c64cell('chest')


def blit_robot(cv, x, y, d='right'):
    """Roboter wie beim C64: Sprite 18 Zeilen, 2 Zeilen ueber seiner Zelle."""
    cv.blit(x, y - 2, ROBOT_SPR[d])


def robot(base=None):
    t = grass() if base is None else base.copy()
    spr = ROBOT_SPR['right'][2:18]
    m = spr != T
    t[m] = spr[m]
    return t


# ---- Icons der Befehle (32x16 auf Panel-Hintergrund) ---------------------------------
def icon(kind, c):
    t = tile()
    if kind == 'fwd':
        t[6:14, 14:18] = c
        for i in range(6): t[1 + i, 15 - i * 1:17 + i * 1] = c
    elif kind == 'back':
        t[2:10, 14:18] = c
        for i in range(6): t[14 - i, 15 - i:17 + i] = c
    elif kind in ('left', 'right'):
        t[3:5, 10:22] = c; t[3:13, 20:22] = c
        for i in range(4): t[4 - i:4 + i + 1, 10 - i * 2:12 - i * 2] = c
        if kind == 'right': t = t[:, ::-1].copy()
    elif kind == 'turn':
        t[2:4, 10:22] = c; t[2:13, 10:12] = c; t[2:9, 20:22] = c
        for i in range(4): t[9 + i, 17 + i:25 - i] = c
    elif kind in ('pick', 'drop'):
        t[8:15, 9:23] = BRN; t[8:10, 9:23] = YEL; t[11:13, 15:17] = YEL
        if kind == 'pick':
            t[2:7, 15:17] = c
            for i in range(3): t[1 + i, 15 - i:17 + i] = c
        else:
            t[0:5, 15:17] = c
            for i in range(3): t[6 - i, 15 - i:17 + i] = c
    elif kind == 'jump':
        for x in range(4, 28):
            y = int(12 - 10 * (1 - ((x - 16) / 12) ** 2))
            t[y:y + 2, x] = c
        t[14:16, 2:30] = DGRN
    elif kind == 'throw':
        for x in range(4, 24):
            y = int(13 - 10 * (1 - ((x - 14) / 10) ** 2))
            t[y:y + 1, x] = c
        t[9:15, 22:30] = BRN; t[9:11, 22:30] = YEL
    return t


# ---- Bildschirm: drei Spalten ----------------------------------------------------------
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
PAL = [('Q', 'pick', LGRN), ('W', 'fwd', WHT), ('E', 'drop', LPUR),
       ('A', 'left', LCYN), ('S', 'back', WHT), ('D', 'right', LCYN),
       ('Z', 'jump', WHT), ('X', 'turn', LCYN), ('C', 'throw', LPUR)]


def field(cv, x0, y0, run):
    boxes = {(3, 3), (4, 3), (6, 6), (8, 6)}
    rob = (1, 3)
    if run:
        boxes = {(3, 3), (6, 3), (6, 6), (8, 6)}; rob = (4, 3)
    for r, line in enumerate(LEVEL):
        for c, ch in enumerate(line):
            if ch == 'T': t = tree()
            elif ch == '~': t = water(c + r)
            elif ch == 'G': t = goal()
            else: t = grass(c * 7 + r)
            if (c, r) in boxes: t = chest(ch == 'G')
            if (c, r) == rob and ch == 'P': t = grass()
            cv.blit(x0 + c * 32, y0 + r * 16, t)
    blit_robot(cv, x0 + rob[0] * 32, y0 + rob[1] * 16)


def screen(run=False):
    cv = Canvas(BLK)
    # Spielfeld (links)
    cv.panel(0, 0, 336, 180, 'Meadow 5 - Bottleneck')
    field(cv, 8, 12, run)
    cv.rect(8, 172, 320, 6, DBLU)
    cv.text(8, 172 - 0, '', WHT)
    # Legende (Mitte oben)
    cv.panel(340, 0, 152, 96, 'Legend')
    leg = [('ArtyBot', robot(tile()) , 'looking right'), ('Target', goal(tile()), None),
           ('Package', chest(base=tile()), None), ('Tree', tree(tile()), None), ('Water', water(), None)]
    for i, (n, t, sub) in enumerate(leg):
        y = 12 + i * 16
        cv.blit(346, y, t)
        cv.text(384, y + (0 if sub else 4), n, WHT)
        if sub: cv.text(384, y + 8, sub, LGRY)
    # Befehle (Mitte unten)
    cv.panel(340, 100, 152, 80, 'Commands')
    for i, (k, kind, c) in enumerate(PAL):
        x, y = 346 + (i % 3) * 48, 112 + (i // 3) * 22
        cv.blit(x, y, icon(kind, DGRY if run else c))
        cv.text(x + 34, y + 4, k, DGRY if run else YEL)
    # Programm (rechts)
    cv.panel(496, 0, 144, 180, 'Program 25/99')
    cur = 4 if run else None
    for i, cmd in enumerate(PROGRAM[:20]):
        y = 12 + i * 8
        if i == cur:
            cv.rect(498, y, 132, 8, YEL)
            cv.text(506, y, '%02d %s' % (i + 1, cmd), BLK)
        else:
            cv.text(506, y, '%02d' % (i + 1), LGRY)
            cv.text(530, y, cmd, CMD_COL[cmd[:4]])
    if not run:
        cv.text(498, 12 + 7 * 8 + 4, '>', YEL)             # Einfuegemarke zwischen 08 und 09
    cv.rect(632, 12, 6, 166, DGRY); cv.rect(632, 14, 6, 90, LGRY)   # Scrollbalken
    # Status
    cv.rect(0, 184, 640, 16, BLK)
    if run:
        cv.text(4, 184, 'Running...   Delivered 0/3   Space: pause   R: restart', WHT)
        cv.text(4, 192, 'Space:Go/Pause  R:Redo  Q..C/Del: edit stops the run  F7:Map  F8:Title', LGRY)
    else:
        cv.text(4, 184, 'Package: pick it up with Q, drop it on a target with E.   Delivered 0/3', WHT)
        cv.text(4, 192, 'Q..C:add  Cursor:marker  Ret:edit  Del:delete  Space:Run  F7:Map  F8:Title', LGRY)
    return cv


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
    cv = Canvas(BLK)
    cv.panel(8, 0, 624, 176, 'World 1: Meadow')
    for r, line in enumerate(WORLD):
        for c, ch in enumerate(line):
            if ch in 'T[]': t = tree()
            elif ch == '~': t = water(c + r)
            elif ch == ',': t = grass(c * 5 + r)
            elif ch == '*': t = flowers(c + r * 3)
            elif ch in '12345': t = node(ch)
            else: t = path_tile(c + r)
            cv.blit(16 + c * 32, 12 + r * 16, t)
            if ch in '12345':
                cv.rect(16 + c * 32 + 24, 12 + r * 16 + 8, 8, 8, BLK)
                cv.text(16 + c * 32 + 24, 12 + r * 16 + 8, ch, WHT)
    blit_robot(cv, 16 + 4 * 32, 12 + 1 * 16)
    cv.text(12, 180, 'Meadow 1 - solved   Space: play', WHT)
    cv.text(12, 190, 'WASD/Cursor: walk   Space:Play  F1:Stats  F3/F5:World  F8:Title', LGRY)
    return cv


def compare(c64_png, vdc_canvas, path):
    """C64-Spielfeld (aus sim_regress-Screenshot) neben dem VDC-Spielfeld, gleiche Groesse."""
    c64 = Image.open(c64_png).convert('RGB').crop((32 + 8, 32 + 8, 32 + 8 + 160, 32 + 8 + 160))
    c64 = c64.resize((640, 640), Image.NEAREST)
    q, _ = vdc_quantize(vdc_canvas.p)
    v = Image.fromarray(RGB[q[12:172, 8:328]].astype(np.uint8), 'RGB').resize((640, 640), Image.NEAREST)
    out = Image.new('RGB', (1328, 700), (20, 20, 20))
    out.paste(c64, (16, 44)); out.paste(v, (672, 44))
    d = ImageDraw.Draw(out)
    f = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 22)
    d.text((16, 10), 'C64 (VIC-II, Multicolour)', fill=(230, 230, 230), font=f)
    d.text((672, 10), 'C128 VDC (Bitmap, Farbe pro 8x2 Pixel)', fill=(230, 230, 230), font=f)
    out.save(path)


if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 else 'out/mock_vdc_bitmap'
    os.makedirs(out, exist_ok=True)
    for name, cv in [('plan', screen(False)), ('run', screen(True)), ('world_map', world_map())]:
        bad = save(cv.p, os.path.join(out, name + '.png'))
        print('%-10s %4d von %d Farbbloecken hatten >2 Farben (angepasst)' % (name, bad, (W // BW) * (H // BH)))
    if len(sys.argv) > 2:       # Vergleich mit einem C64-Screenshot von Level 15 (sim_regress: L15_run.png)
        compare(sys.argv[2], screen(False), os.path.join(out, 'compare.png'))

