#!/usr/bin/env python3
"""gen_vdc_title.py - Bilder fuer Titel und Ende auf dem VDC (Bitmap 640x200, Attribut pro 8x2).
Quelle: tools/art/c64_title.png / c64_end.png (C64-Bildschirm 320x200 ohne Rand, aus c64sim).
Jedes C64-Pixel wird doppelt so breit (gleiche Proportionen auf 640x200); pro 8x2-Block die zwei
haeufigsten Farben (Hintergrund = haeufigste), andere Farben auf die naehere der beiden.

Ausgabe platform/c128/view_vdc/gfx_vdc_title.asm, je Bild:
  <name>        !byte breite_bytes, hoehe_zeilen ; dann gepackt (rle): breite*hoehe Bitmap-Bytes
                zeilenweise, danach breite*hoehe/2 Attribut-Bytes (hohes Nibble Hintergrund).
  Packen: Steuerbyte c < $80: c+1 Bytes folgen unveraendert; c >= $80: naechstes Byte (c-$7D)-mal
  (3..130). Entpacker: vt_image in platform/c128/view_vdc/text.asm.
python3 tools/gen_vdc_title.py [--preview out.png]"""
import os, sys
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_vdc_gfx import C64_TO_VDC, RGB as VDC_RGB

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(ROOT, 'tools', 'art')
OUT = os.path.join(ROOT, 'platform', 'c128', 'view_vdc', 'gfx_vdc_title.asm')

C64_RGB = [(0, 0, 0), (255, 255, 255), (104, 55, 43), (112, 164, 178), (111, 61, 134), (88, 141, 67),
           (53, 40, 121), (184, 199, 111), (111, 79, 37), (67, 57, 0), (154, 103, 89), (68, 68, 68),
           (108, 108, 108), (154, 210, 132), (108, 94, 181), (149, 149, 149)]

# name, Quelle, C64-Ausschnitt (x0, y0, x1, y1): x in 4er-Schritten (8 VDC-Pixel), y gerade
IMAGES = [
    ('vti_logo', 'c64_title.png', (24, 8, 304, 58)),
    ('vti_robot', 'c64_title.png', (16, 72, 104, 176)),
    ('vti_chest', 'c64_title.png', (104, 148, 140, 176)),
    ('vti_trophy', 'c64_end.png', (8, 72, 136, 176)),
]


def nearest(rgb, pal):
    return min(range(len(pal)), key=lambda i: sum((a - b) ** 2 for a, b in zip(rgb, pal[i])))


def load(src, box):
    im = Image.open(os.path.join(ART, src)).convert('RGB')
    x0, y0, x1, y1 = box
    cache = {}
    px = []
    for y in range(y0, y1):
        row = []
        for x in range(x0, x1):
            c = im.getpixel((x, y))
            if c not in cache:
                cache[c] = C64_TO_VDC[nearest(c, C64_RGB)]
            row += [cache[c]] * 2
        px.append(row)
    return px


def quantize(px):
    h, w = len(px), len(px[0])
    assert w % 8 == 0 and h % 2 == 0
    bm = [[0] * (w // 8) for _ in range(h)]
    at = [[0] * (w // 8) for _ in range(h // 2)]
    out = [[0] * w for _ in range(h)]
    bad = 0
    for by in range(0, h, 2):
        for bx in range(0, w, 8):
            cnt = {}
            for y in (by, by + 1):
                for x in range(bx, bx + 8):
                    cnt[px[y][x]] = cnt.get(px[y][x], 0) + 1
            order = sorted(cnt, key=lambda c: (-cnt[c], c))
            bg = order[0]
            fg = order[1] if len(order) > 1 else bg
            if len(order) > 2:
                bad += 1
            at[by // 2][bx // 8] = (bg << 4) | fg
            for y in (by, by + 1):
                v = 0
                for x in range(bx, bx + 8):
                    c = px[y][x]
                    if c != bg and c != fg:
                        c = fg if nearest(VDC_RGB[c], [VDC_RGB[bg], VDC_RGB[fg]]) else bg
                    v = (v << 1) | (1 if (c == fg and fg != bg) else 0)
                    out[y][x] = c
                bm[y][bx // 8] = v
    return bm, at, out, bad


def rle(data):
    out, i, lit = [], 0, []
    def flush():
        while lit:
            n = min(128, len(lit)); out.append(n - 1); out.extend(lit[:n]); del lit[:n]
    while i < len(data):
        j = i
        while j < len(data) and data[j] == data[i] and j - i < 130: j += 1
        if j - i >= 3:
            flush(); out += [0x7D + (j - i), data[i]]; i = j
        else:
            lit.append(data[i]); i += 1
    flush()
    return out


def unrle(p):
    out, i = [], 0
    while i < len(p):
        c = p[i]
        if c < 0x80: out += p[i + 1:i + 2 + c]; i += 2 + c
        else: out += [p[i + 1]] * (c - 0x7D); i += 2
    return out


def main():
    lines = ['; gfx_vdc_title.asm - generiert von tools/gen_vdc_title.py, nicht von Hand aendern',
             '; Je Bild: Breite (Bytes), Hoehe (Zeilen), Bitmap zeilenweise, Attribute je 2 Zeilen', '']
    previews = []
    for name, src, box in IMAGES:
        px = load(src, box)
        bm, at, out, bad = quantize(px)
        w, h = len(bm[0]), len(bm)
        print('%-11s %2d x %3d  %5d Byte  %d Bloecke mit >2 Farben' % (name, w, h, 2 + w * h + w * h // 2, bad))
        lines.append('%s\n        !byte %d, %d' % (name, w, h))
        flat = [b for r in bm for b in r] + [a for r in at for a in r]
        packed = rle(flat)
        assert unrle(packed) == flat
        print('            gepackt %5d Byte' % len(packed))
        flat = packed
        for i in range(0, len(flat), 16):
            lines.append('        !byte ' + ','.join('$%02X' % b for b in flat[i:i + 16]))
        lines.append('')
        previews.append((name, out))
        if name == 'vti_robot':               # Antennenlicht: gelbe Bloecke oben, blinkt rot
            bl = [(x, y, a) for y, r in enumerate(at[:8]) for x, a in enumerate(r) if 13 in (a >> 4, a & 15)]
            sw = lambda a: ((9 if a >> 4 == 13 else a >> 4) << 4) | (9 if a & 15 == 13 else a & 15)
            lines.append('vti_blink_n = %d' % len(bl))
            lines.append('vti_blink_dx  !byte ' + ','.join(str(x) for x, _, _ in bl))
            lines.append('vti_blink_dy  !byte ' + ','.join(str(y) for _, y, _ in bl))
            lines.append('vti_blink_on  !byte ' + ','.join('$%02X' % sw(a) for _, _, a in bl))
            lines.append('vti_blink_off !byte ' + ','.join('$%02X' % a for _, _, a in bl))
            lines.append('')
            print('  Antenne: %d Bloecke' % len(bl))
    open(OUT, 'w', newline='\n').write('\n'.join(lines))
    if '--preview' in sys.argv:
        p = sys.argv[sys.argv.index('--preview') + 1]
        W = sum(len(o[0]) for _, o in previews) + 8 * len(previews)
        H = max(len(o) for _, o in previews)
        im = Image.new('RGB', (W, H))
        x = 0
        for _, o in previews:
            for y, r in enumerate(o):
                for i, c in enumerate(r):
                    im.putpixel((x + i, y), VDC_RGB[c])
            x += len(o[0]) + 8
        im.resize((W, H * 2), Image.NEAREST).save(p)


if __name__ == '__main__':
    main()
