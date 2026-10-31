#!/usr/bin/env python3
"""gen_title.py - generates src/gfx_title.asm (title screen art).

Text mode with its own character set (TITLE_CHARSET, $D000 in VIC bank 3): the
lower/uppercase ROM set plus redefined characters for the big "ARTYBOT" logo
and the robot picture. Both are multicolour characters:
  %00 = $D021 black   %01 = $D022 dark grey   %10 = $D023 light grey
  %11 = colour RAM (0-7, one accent colour per character cell)
Style after the title of "Attack of the PETSCII Robots": big logo on top,
robot on the left, menu window on the right, black background.

Usage:  python -B tools/gen_title.py [--preview out.png]
Output: src/gfx_title.asm with
  title_screen / title_colors   1000 + 1000 bytes (screen codes, colour RAM)
  title_charset_init            routine: copies the redefined characters
  title_blink                   colour RAM offsets of the antenna light
Text (menu, footer) is drawn by src/title.asm on top of this picture.
End screen (shown when the road past the last world is taken): same logo, a
trophy instead of the robot, own charset END_CHARSET ($D800, RAM under the colour
RAM I/O) with the logo characters at the title's codes plus the trophy:
  end_screen / end_colors / end_charset_init   (--preview-end out.png)
"""
import os, sys
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', 'src', 'gfx_title.asm')

BG1, BG2 = 11, 15                 # $D022 dark grey, $D023 light grey (robot, rows 8-24)
LOGO_BG1, LOGO_BG2 = 3, 1         # logo rows 0-7 (raster split): $D022 cyan, $D023 white
LOGO_SHADOW = 6                   # colour RAM of the logo cells: blue extrusion
TITLE_SPLIT_ROW = 8               # first character row with the robot colours
BLACK, DG, LG = 0, 1, 2           # pixel values %00 %01 %10
def ACC(c): return 16 + c         # %11 with colour RAM c

# Free character codes of the lower/uppercase set for the title. Keep:
# $00-$3F letters/digits/punctuation, $41-$5A capitals, $8D hand, $8E block,
# $98-$9F window frame (copied from the game charset).
FREE = [0x40] + list(range(0x5B, 0x80)) + [c for c in range(0x80, 0x100)
        if c not in (0x8D, 0x8E) and not 0x98 <= c <= 0x9F]

screen = [0x20] * 1000
colors = [1] * 1000

# --------------------------------------------------------------- the logo
LETTERS = {
'A': """
.######.
########
##....##
##....##
##....##
########
########
##....##
##....##
##....##
##....##
##....##""",
'R': """
#######.
########
##....##
##....##
##....##
#######.
#######.
##..###.
##...###
##....##
##....##
##....##""",
'T': """
########
########
...##...
...##...
...##...
...##...
...##...
...##...
...##...
...##...
...##...
...##...""",
'Y': """
##....##
##....##
##....##
##....##
###..###
.######.
..####..
...##...
...##...
...##...
...##...
...##...""",
'B': """
#######.
########
##....##
##....##
##...##.
######..
#######.
##....##
##....##
##....##
########
#######.""",
'O': """
.######.
########
##....##
##....##
##....##
##....##
##....##
##....##
##....##
##....##
########
.######.""",
}
LOGO = 'ARTYBOT'
LOGO_COL, LOGO_ROW = 3, 1          # first character cell of the logo
LOGO_ROWS = 7                      # 6 letter rows + 1 row for the shadow

def letter_pixels(ch):
    """Block letter (8x12 blocks of 2 MC pixels x 4 lines) -> set of (x, y)."""
    rows = LETTERS[ch].strip('\n').split('\n')
    B = lambda bx, by: 0 <= by < 12 and 0 <= bx < 8 and rows[by][bx] == '#'
    px = set()
    cut = [2, 1, 1, 0]              # rounded outer corners (per line of a block)
    for by in range(12):
        for bx in range(8):
            if not B(bx, by):
                continue
            for ly in range(4):
                for lx in range(2):
                    x, y = bx*2 + lx, by*4 + ly
                    # outer corners: cut a small diagonal
                    tl = not B(bx-1, by) and not B(bx, by-1)
                    tr = not B(bx+1, by) and not B(bx, by-1)
                    bl = not B(bx-1, by) and not B(bx, by+1)
                    br = not B(bx+1, by) and not B(bx, by+1)
                    if tl and lx < cut[ly]: continue
                    if tr and (1-lx) < cut[ly]: continue
                    if bl and lx < cut[3-ly]: continue
                    if br and (1-lx) < cut[3-ly]: continue
                    px.add((x, y))
    return px

def build_logo():
    W, H = (len(LOGO)*5) * 4, LOGO_ROWS * 8
    face = set()
    for i, ch in enumerate(LOGO):
        for (x, y) in letter_pixels(ch):
            face.add((x + i*5*4, y))
    img = [[BLACK]*W for _ in range(H)]
    # face: yellow ($D023) on top, orange ($D022) below, dithered in between;
    # inner top edges get a yellow bevel line. Shadow: colour RAM.
    def face_col(x, y):
        if y < 14: return LG
        if y < 22: return LG if (x + y) % 2 == 0 and y < 18 or (x + y) % 4 == 0 else DG
        if (x, y-1) not in face: return LG
        return DG
    for y in range(H):
        for x in range(W):
            if (x, y) in face:
                img[y][x] = face_col(x, y)
            elif any((x-dx, y-dy) in face for dx, dy in ((1, 1), (1, 2), (1, 3), (2, 3), (2, 4), (1, 4))):
                img[y][x] = ACC(LOGO_SHADOW)  # extruded shadow down/right
    return img

# --------------------------------------------------------------- the robot
ROBOT_COL, ROBOT_ROW = 1, 9
RW, RH = 64, 52                    # 16 x 13 character cells; 1 px = 1 MC pixel x 2 lines

def build_robot():
    im = Image.new('P', (RW, RH), BLACK)
    d = ImageDraw.Draw(im)
    R = lambda box, f, o=None: d.rectangle(box, fill=f, outline=o)
    RR = lambda box, f, o=None, r=3: d.rounded_rectangle(box, r, fill=f, outline=o)
    # antenna
    R((25, 4, 26, 8), DG)
    d.ellipse((22, 0, 29, 5), fill=ACC(2))
    R((24, 1, 25, 1), LG)
    # ears / bolts
    RR((6, 13, 10, 22), DG, r=1)
    RR((41, 13, 45, 22), DG, r=1)
    # head
    RR((10, 8, 41, 27), LG, BLACK, r=5)
    R((12, 25, 39, 26), DG)                     # lower shade
    R((39, 11, 40, 26), DG)                     # right shade
    # visor with two eyes
    RR((14, 12, 37, 20), BLACK, r=3)
    d.ellipse((16, 13, 22, 19), fill=ACC(3))
    d.ellipse((29, 13, 35, 19), fill=ACC(3))
    R((17, 14, 18, 15), LG); R((30, 14, 31, 15), LG)
    # mouth grill
    for x in range(19, 33, 3):
        R((x, 22, x+1, 23), DG)
    # neck
    R((21, 28, 30, 29), DG)
    # body
    RR((12, 30, 39, 45), LG, BLACK, r=4)
    R((37, 32, 38, 44), DG)
    R((14, 43, 37, 44), DG)
    RR((16, 33, 35, 40), BLACK, r=1)            # control panel
    for i, c in enumerate((2, 7, 5, 3)):        # four lights, one per cell
        x = 17 + i*4
        R((x+1, 35, x+2, 37), ACC(c))
    # arms with claws
    RR((5, 31, 10, 41), LG, BLACK, r=2)
    R((9, 32, 9, 40), DG)
    R((5, 42, 6, 44), DG); R((9, 42, 10, 44), DG)
    RR((41, 31, 46, 41), LG, BLACK, r=2)
    R((45, 32, 45, 40), DG)
    R((41, 42, 42, 44), DG); R((45, 42, 46, 44), DG)
    # legs and feet
    R((17, 46, 22, 48), DG)
    R((29, 46, 34, 48), DG)
    RR((13, 48, 23, 51), LG, BLACK, r=1)
    RR((28, 48, 38, 51), LG, BLACK, r=1)
    R((14, 51, 22, 51), DG); R((29, 51, 37, 51), DG)
    # treasure chest beside the robot (cells 12-15)
    RR((49, 38, 63, 51), ACC(2), BLACK, r=2)    # red-brown chest
    R((49, 43, 63, 44), DG)                     # lid edge / iron band
    R((54, 41, 58, 47), LG)                     # lock plate
    R((56, 44, 56, 45), BLACK)
    R((50, 39, 62, 39), LG)                     # lid highlight
    return [[im.getpixel((x, y)) for x in range(RW)] for y in range(RH)]

# ------------------------------------------------------------ cell packing
chars = {}            # bitmap tuple -> code
char_list = []
blink = []

def add_cells(img, col0, row0, lines_per_px):
    h = len(img) * lines_per_px
    w = len(img[0])
    assert w % 4 == 0 and h % 8 == 0
    for cy in range(h // 8):
        for cx in range(w // 4):
            acc = set()
            bm = []
            for line in range(8):
                y = (cy*8 + line) // lines_per_px
                b = 0
                for k in range(4):
                    v = img[y][cx*4 + k]
                    if v >= 16:
                        acc.add(v - 16); v = 3
                    b = (b << 2) | v
                bm.append(b)
            assert len(acc) <= 1, 'cell %d,%d has accents %s' % (col0+cx, row0+cy, acc)
            pos = (row0 + cy) * 40 + col0 + cx
            if not any(bm):
                continue                 # stays a space
            key = tuple(bm)
            if key not in chars:
                assert len(char_list) < len(FREE), 'too many title characters'
                chars[key] = FREE[len(char_list)]
                char_list.append(key)
            screen[pos] = chars[key]
            colors[pos] = 8 + (acc.pop() if acc else 1)
            yield pos, acc

def place(img, col0, row0, lpp):
    for _ in add_cells(img, col0, row0, lpp):
        pass

logo = build_logo()
place(logo, LOGO_COL, LOGO_ROW, 1)
robot = build_robot()
place(robot, ROBOT_COL, ROBOT_ROW, 2)
for row in range(ROBOT_ROW, ROBOT_ROW + 2):     # antenna ball cells blink
    for col in range(ROBOT_COL, ROBOT_COL + RW // 4):
        p = row*40 + col
        if colors[p] == 8 + 2 and screen[p] != 0x20:
            blink.append(p)

# ------------------------------------------------------------- the trophy
TROPHY_COL, TROPHY_ROW = 1, 9      # same place as the robot on the title
TW, TH = 64, 52                    # 16 x 13 cells; 1 px = 1 MC pixel x 2 lines
GOLD = ACC(7)                      # yellow colour RAM

def build_trophy():
    im = Image.new('P', (TW, TH), BLACK)
    d = ImageDraw.Draw(im)
    # handles
    d.ellipse((5, 7, 23, 27), outline=GOLD, width=3)
    d.ellipse((40, 7, 58, 27), outline=GOLD, width=3)
    # bowl (mask, then shaded)
    mask = Image.new('1', (TW, TH), 0)
    m = ImageDraw.Draw(mask)
    m.rectangle((16, 5, 47, 18), fill=1)
    m.ellipse((16, 4, 47, 33), fill=1)
    for y in range(TH):
        for x in range(TW):
            if mask.getpixel((x, y)):
                c = GOLD
                if x >= 43 and y <= 24: c = DG
                elif 20 <= x <= 22 and 7 <= y <= 24: c = LG
                im.putpixel((x, y), c)
    # rim
    d.rectangle((14, 2, 49, 5), fill=GOLD)
    d.rectangle((15, 2, 48, 2), fill=LG)
    d.rectangle((45, 3, 49, 5), fill=DG)
    # star on the bowl
    d.polygon([(31, 9), (33, 14), (38, 14), (34, 17), (36, 22), (31, 19), (26, 22),
               (28, 17), (24, 14), (29, 14)], fill=DG)
    # stem and knot
    d.rectangle((29, 31, 34, 38), fill=GOLD)
    d.ellipse((25, 34, 38, 39), fill=GOLD)
    # plinth
    d.rectangle((20, 40, 43, 44), fill=LG)
    d.rectangle((40, 40, 43, 44), fill=DG)
    d.rectangle((13, 45, 50, 51), fill=DG)
    d.rectangle((13, 45, 50, 45), fill=LG)
    d.rectangle((23, 47, 40, 49), fill=LG)     # name plate
    # sparkles
    for (x, y) in ((7, 1), (56, 33), (3, 38), (59, 3), (55, 46)):
        d.rectangle((x - 2, y, x + 2, y), fill=LG)
        d.rectangle((x, y - 2, x, y + 2), fill=LG)
    return [[im.getpixel((x, y)) for x in range(TW)] for y in range(TH)]

# End screen: logo rows copied from the title, trophy with its own codes.
end_screen = [0x20] * 1000
end_colors = [1] * 1000
logo_rows = range(0, TITLE_SPLIT_ROW * 40)
for p in logo_rows:
    end_screen[p], end_colors[p] = screen[p], colors[p]
logo_codes = sorted({end_screen[p] for p in logo_rows if end_screen[p] != 0x20})
code_bitmap = {code: key for key, code in chars.items()}
end_free = [c for c in FREE if c not in logo_codes]
end_chars = {}                     # bitmap -> code (trophy)

def place_end(img, col0, row0, lpp):
    w, h = len(img[0]), len(img) * lpp
    for cy in range(h // 8):
        for cx in range(w // 4):
            acc, bm = set(), []
            for line in range(8):
                y = (cy * 8 + line) // lpp
                b = 0
                for k in range(4):
                    v = img[y][cx * 4 + k]
                    if v >= 16:
                        acc.add(v - 16); v = 3
                    b = (b << 2) | v
                bm.append(b)
            assert len(acc) <= 1, 'trophy cell %d,%d has accents %s' % (cx, cy, acc)
            if not any(bm):
                continue
            key = tuple(bm)
            if key not in end_chars:
                assert len(end_chars) < len(end_free), 'too many end screen characters'
                end_chars[key] = end_free[len(end_chars)]
            pos = (row0 + cy) * 40 + col0 + cx
            end_screen[pos] = end_chars[key]
            end_colors[pos] = 8 + (acc.pop() if acc else 1)

place_end(build_trophy(), TROPHY_COL, TROPHY_ROW, 2)

# ------------------------------------------------------------- output
def write_asm():
    o = ['; gfx_title.asm - GENERATED by tools/gen_title.py - do not edit by hand',
         '; Title screen: logo + robot as multicolour characters of TITLE_CHARSET.',
         '; %d redefined characters.' % len(char_list), '',
         'TITLE_BG1 = %d' % BG1, 'TITLE_BG2 = %d' % BG2,
         'TITLE_LOGO_BG1 = %d' % LOGO_BG1, 'TITLE_LOGO_BG2 = %d' % LOGO_BG2,
         'TITLE_SPLIT_LINE = %d   ; raster line of character row %d' % (51 + TITLE_SPLIT_ROW*8 - 1, TITLE_SPLIT_ROW), '']
    # contiguous runs of codes -> one copy each
    runs = []
    for i, code in enumerate(FREE[:len(char_list)]):
        if runs and runs[-1][0] + runs[-1][1] == code:
            runs[-1][1] += 1
        else:
            runs.append([code, 1, i])
    o.append('; Copies the redefined characters into TITLE_CHARSET (startup, $01 = $32:')
    o.append('; writes to $D000-$D7FF go to the RAM below the character ROM).')
    o.append('title_charset_init')
    for code, n, i in runs:
        o.append('        +copy title_chars+%d, TITLE_CHARSET+$%03X, %d' % (i*8, code*8, n*8))
    o.append('        rts')
    o.append('')
    o.append('title_chars')
    for key, code in zip(char_list, FREE):
        o.append('        !byte ' + ','.join('$%02X' % b for b in key) + '   ; $%02X' % code)
    o.append('')
    for name, data in (('title_screen', screen), ('title_colors', colors)):
        o.append(name)
        for r in range(25):
            o.append('        !byte ' + ','.join('$%02X' % b for b in data[r*40:r*40+40]))
    o.append('')
    # end screen charset: logo characters (title codes) + trophy
    end_list = sorted([(c, code_bitmap[c]) for c in logo_codes] +
                      [(c, k) for k, c in end_chars.items()])
    runs = []
    for i, (code, _) in enumerate(end_list):
        if runs and runs[-1][0] + runs[-1][1] == code:
            runs[-1][1] += 1
        else:
            runs.append([code, 1, i])
    o.append('; End screen: copies logo + trophy characters into END_CHARSET (startup).')
    o.append('end_charset_init')
    for code, n, i in runs:
        o.append('        +copy end_chars+%d, END_CHARSET+$%03X, %d' % (i*8, code*8, n*8))
    o.append('        rts')
    o.append('')
    o.append('end_chars')
    for code, key in end_list:
        o.append('        !byte ' + ','.join('$%02X' % b for b in key) + '   ; $%02X' % code)
    o.append('')
    for name, data in (('end_screen', end_screen), ('end_colors', end_colors)):
        o.append(name)
        for r in range(25):
            o.append('        !byte ' + ','.join('$%02X' % b for b in data[r*40:r*40+40]))
    o.append('')
    o.append('TITLE_BLINK_COUNT = %d' % len(blink))
    o.append('title_blink_lo !byte ' + ','.join('<($D800+%d)' % p for p in blink))
    o.append('title_blink_hi !byte ' + ','.join('>($D800+%d)' % p for p in blink))
    open(OUT, 'w', newline='\n').write('\n'.join(o) + '\n')
    print('gfx_title.asm: %d characters, %d blink cells; end screen: %d logo + %d trophy characters'
          % (len(char_list), len(blink), len(logo_codes), len(end_chars)))

PAL = [0x000000,0xFFFFFF,0x68372B,0x70A4B2,0x6F3D86,0x588D43,0x352879,0xB8C76F,
       0x6F4F25,0x433900,0x9A6759,0x444444,0x6C6C6C,0x9AD284,0x6C5EB5,0x959595]

def preview(path, screen=screen, colors=colors, bm=None):
    rgb = [((v >> 16) & 255, (v >> 8) & 255, v & 255) for v in PAL]
    im = Image.new('RGB', (320, 200)); px = im.load()
    if bm is None:
        bm = {code: key for key, code in chars.items()}
    for p in range(1000):
        code = screen[p]
        if code not in bm: continue
        cx, cy = (p % 40)*8, (p // 40)*8
        for line in range(8):
            b = bm[code][line]
            for k in range(4):
                v = (b >> (6 - 2*k)) & 3
                b1, b2 = (LOGO_BG1, LOGO_BG2) if p < TITLE_SPLIT_ROW*40 else (BG1, BG2)
                c = [rgb[0], rgb[b1], rgb[b2], rgb[colors[p] & 7]][v]
                px[cx+2*k, cy+line] = c; px[cx+2*k+1, cy+line] = c
    im.resize((960, 600), Image.NEAREST).save(path)

write_asm()
if '--preview' in sys.argv:
    preview(sys.argv[sys.argv.index('--preview') + 1])
if '--preview-end' in sys.argv:
    ebm = {c: code_bitmap[c] for c in logo_codes}
    ebm.update({c: k for k, c in end_chars.items()})
    preview(sys.argv[sys.argv.index('--preview-end') + 1], end_screen, end_colors, ebm)
