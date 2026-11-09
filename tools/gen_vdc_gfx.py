#!/usr/bin/env python3
"""gen_vdc_gfx.py - rechnet die C64-Grafik auf den VDC um (640x200, 2 Farben je 8x2 Pixel).

  python -B tools/gen_vdc_gfx.py [--preview out.png]
  -> platform/c128/view_vdc/gfx_vdc.asm (generiert, nicht von Hand aendern)

Quellen (dieselben wie fuer den VIC-II): Feldzellen tools/gen_gfx_run.py (Meadow) und
tools/gen_theme_winter.py (Winter) mit den Theme-Farben aus platform/cbm/view_vic2/world.asm,
Roboter/Kiste/Schluessel aus gen_gfx_run (Sprites), Befehls-Icons aus
platform/cbm/view_vic2/gfx_data.asm (gfx_icons, gfx_icons2).

Umrechnung: ein C64-Multicolour-Pixel = 4 VDC-Pixel breit, 1 Zeile hoch (Zelle 16x16 VIC-Pixel
-> 32x16 VDC-Pixel, gleich gross am Bildschirm); ein Hires-Pixel der Icons = 2 VDC-Pixel.
C64-Farben -> RGBI ueber C64_TO_VDC. Je 8x2-Block bleiben die zwei haeufigsten Farben (die
haeufigere ist der Hintergrund = Grundfarbe), andere Farben werden auf die naehere abgebildet;
die Zahl solcher Bloecke wird gemeldet.

Ausgabe:
  vdc_cells_meadow / vdc_cells_winter: RUN_CELL_TYPES Zellen in CELL_ORDER, je 64 Byte Bitmap
      (16 Zeilen x 4 Byte) + 32 Byte Attribute (8 Blockzeilen x 4; hohes Nibble Hintergrund).
  vdc_spr_<n>_s0 / _s4: Roboter-/Kistenmasken (gefuellt = Koerperpixel c/W, die schwarze
      Kontur faellt weg), 5 Byte breit, um 0 bzw. 4 Pixel verschoben; Tabellen vdc_spr_lo/hi,
      Hoehe vdc_spr_h, Farbe vdc_spr_col.  Reihenfolge wie gen_gfx_run.sprite_images().
  vdc_icons: 9 Befehls-Icons (Befehlsnummer 0..8), je 64 Byte Bitmap 32x16; Farbe = cmd_colors.
"""
import os, sys, re
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gen_gfx_run as G
import gen_theme_winter as GW
import vdc_robot_art as RA

ROOT = os.path.join(HERE, '..')
OUT = os.path.join(ROOT, 'platform', 'c128', 'view_vdc', 'gfx_vdc.asm')
OUT_RES = os.path.join(ROOT, 'platform', 'c128', 'view_vdc', 'res_vdc_gfx.asm')  # nur VRAM: Ressource (Bank 1)
VIEW = os.path.join(ROOT, 'platform', 'cbm', 'view_vic2')

RGBI = [0x000000, 0x555555, 0x0000AA, 0x5555FF, 0x00AA00, 0x55FF55, 0x00AAAA, 0x55FFFF,
        0xAA0000, 0xFF5555, 0xAA00AA, 0xFF55FF, 0xAA5500, 0xFFFF55, 0xAAAAAA, 0xFFFFFF]
RGB = [((v >> 16) & 255, (v >> 8) & 255, v & 255) for v in RGBI]
# C64-Farbe -> VDC (RGBI). Rot ist beim C64 braeunlich (Staemme, Truhen, Tueren) -> Braun.
C64_TO_VDC = {0: 0, 1: 15, 2: 12, 3: 7, 4: 10, 5: 4, 6: 2, 7: 13, 8: 12, 9: 12, 10: 9,
              11: 1, 12: 1, 13: 5, 14: 3, 15: 14}
COLNAMES = {'COL_BLACK': 0, 'COL_WHITE': 1, 'COL_RED': 2, 'COL_CYAN': 3, 'COL_PURPLE': 4,
            'COL_GREEN': 5, 'COL_BLUE': 6, 'COL_YELLOW': 7, 'COL_ORANGE': 8, 'COL_DGREY': 11,
            'COL_LGREEN': 13, 'COL_LBLUE': 14, 'COL_LGREY': 15, 'CHEST_COLOR': 2}


def theme_colors(label):
    """bg1, bg2 und die 16 Zellfarben (Farb-RAM & 7) eines Themes aus world.asm."""
    txt = open(os.path.join(VIEW, 'world.asm')).read()
    blk = txt[txt.index('\n' + label + '\n'):]
    vals = []
    for line in blk.split('\n')[2:12]:
        line = line.split(';')[0]
        if '!byte' not in line: continue
        for t in line.split('!byte')[1].split(','):
            t = t.strip()
            v = 0
            for part in t.split('+'):
                part = part.strip()
                v += COLNAMES[part] if part in COLNAMES else int(part)
            vals.append(v)
    return vals[0], vals[1], [c & 7 for c in vals[2:18]]


def quantize(px):
    """px[y][x] Farbindizes (RGBI) -> (bitmap rows, attr rows, Zahl angepasster Bloecke)."""
    h, w = len(px), len(px[0])
    bm = [[0] * (w // 8) for _ in range(h)]
    at = [[0] * (w // 8) for _ in range((h + 1) // 2)]
    bad = 0
    for by in range(0, h, 2):
        for bx in range(0, w, 8):
            cnt = {}
            for y in range(by, min(by + 2, h)):
                for x in range(bx, bx + 8):
                    cnt[px[y][x]] = cnt.get(px[y][x], 0) + 1
            order = sorted(cnt, key=lambda c: -cnt[c])
            bg = order[0]; fg = order[1] if len(order) > 1 else order[0]
            if len(order) > 2: bad += 1
            for y in range(by, min(by + 2, h)):
                b = 0
                for x in range(bx, bx + 8):
                    c = px[y][x]
                    if c != bg and c != fg:
                        d = lambda k: sum((RGB[c][i] - RGB[k][i]) ** 2 for i in range(3))
                        c = fg if d(fg) < d(bg) else bg
                    b = b << 1 | (1 if c == fg else 0)
                bm[y][bx // 8] = b
            at[by // 2][bx // 8] = bg << 4 | fg
    return bm, at, bad


def cell_pixels(art, bg1, bg2, cc):
    rows = [r for r in art.strip('\n').split('\n')]
    m = {'.': 0, 'g': C64_TO_VDC[bg1], 'l': C64_TO_VDC[bg2], 'c': C64_TO_VDC[cc]}
    return [[m[ch] for ch in r for _ in range(4)] for r in rows]


CELL_VDC = {'path': 12}     # Meadow-Weg: Braun statt grellem Gelb (Entscheidung 08.11.)


def cells(source, label):
    bg1, bg2, cols = theme_colors(label)
    out, bad = [], 0
    for i, name in enumerate(G.CELL_ORDER):
        px = cell_pixels(source[name], bg1, bg2, cols[i])
        if name in CELL_VDC:
            px = [[CELL_VDC[name] if c == C64_TO_VDC[cols[i]] else c for c in r] for r in px]
        bm, at, b = quantize(px)
        bad += b
        out.append((name, bm, at, px))
    return out, bad


def mini(px):
    """32x16 -> 16x8 (Mehrheit je 2x2), dann je 8x2-Block zwei Farben."""
    m = []
    for y in range(0, len(px) - 1, 2):
        r = []
        for x in range(0, len(px[0]), 2):
            c = [px[y][x], px[y][x + 1], px[y + 1][x], px[y + 1][x + 1]]
            r.append(max(set(c), key=lambda k: (c.count(k), -k)))
        m.append(r)
    return m


def minis(cs):
    return [quantize(mini(px))[:2] for _, _, _, px in cs]


def mini_robots():
    out = []
    for view in ('right', 'left', 'up', 'down'):     # Reihenfolge wie robot_dir
        img = RA.robot('right' if view == 'left' else view, 0, 0)
        if view == 'left': img = RA.mirror(img)
        px = [[{'.': 0, 'B': 0, 'c': 14}[ch] for ch in r] for r in img[:16]]
        out.append(quantize(mini(px))[:2])
    return out


def sprites():
    """Figuren aus tools/vdc_robot_art.py (in VDC-Pixeln gezeichnet)."""
    out = []
    for n, img, col in RA.images():
        if len(img) % 2: img = img + ['.' * 32]
        h = len(img)
        shifts = []
        for s in (0, 4):
            pad = lambda r: '.' * s + r + '.' * (8 - s)
            im = [pad(r) for r in img]                      # 40 breit
            rows, att = [[0] * 5 for _ in range(h)], []
            for by in range(0, h, 2):
                ar = []
                for k in range(5):
                    blk = [im[y][k * 8 + x] for y in (by, by + 1) for x in range(8)]
                    nB, nc, nT = blk.count('B'), blk.count('c'), blk.count('.')
                    if nT == 16:
                        ar.append(0xFF); ink = ''
                    elif nc and (nB or nT == 0):             # Koerper + Kontur: schwarz hinterlegt
                        ar.append(col); ink = 'c'            # (durchsichtige Pixel werden Kontur)
                    elif nB:                                 # nur Kontur: schwarz auf der Kachel
                        ar.append(0x80); ink = 'B'
                    else:                                    # nur Koerper: Figurfarbe auf der Kachel
                        ar.append(0); ink = 'c'
                    for y in (by, by + 1):
                        seg = im[y][k * 8:k * 8 + 8]
                        rows[y][k] = int(''.join('1' if ch == ink else '0' for ch in seg), 2) if ink else 0
                att.append(ar)
            for ar in att:                      # Laeufe ohne Luecke (sprite.asm kopiert je Zeile einen Lauf)
                used = [k for k in range(5) if ar[k] != 0xFF]
                assert not used or used == list(range(used[0], used[-1] + 1)), (n, s, ar)
            shifts.append((rows, att))
        out.append((n, h, col, shifts))
    return out


def asm_bytes(label_start, label_end):
    txt = open(os.path.join(VIEW, 'gfx_data.asm')).read()
    blk = txt[txt.index('\n' + label_start):txt.index('\n' + label_end)]
    vals = []
    for line in blk.split('\n'):
        line = line.split(';')[0]
        if '!byte' in line:
            vals += [int(t.strip().replace('$', '0x'), 16) if t.strip().startswith('$') else int(t.strip(), 0)
                     for t in line.split('!byte')[1].split(',') if t.strip()]
    return vals


def icons():
    a = asm_bytes('gfx_icons', 'gfx_icons_end')
    b = asm_bytes('gfx_icons2', 'gfx_icons2_end')
    chars = [a[i * 8:i * 8 + 8] for i in range(len(a) // 8)] + [b[i * 8:i * 8 + 8] for i in range(len(b) // 8)]
    first = [0, 4, 8, 12, 16, 20, 24, len(a) // 8, len(a) // 8 + 4]       # wie palette_icon_chars
    out = []
    for f in first:
        tl, tr, bl, br = chars[f:f + 4]
        rows = []
        for half in ((tl, tr), (bl, br)):
            for y in range(8):
                bits = ''
                for ch in half:
                    bits += ''.join(b * 2 for b in format(ch[y], '08b'))
                rows.append([int(bits[k * 8:k * 8 + 8], 2) for k in range(4)])
        out.append(rows)
    return out


def hx(row):
    return ','.join('$%02X' % v for v in row)


def main():
    cm, bad_m = cells(G.CELLS, 'theme_meadow')
    cw, bad_w = cells(GW.C, 'theme_winter')
    sp = sprites()
    ic = icons()
    o = ['; gfx_vdc.asm - VDC-Grafik. GENERIERT von tools/gen_vdc_gfx.py - nicht von Hand aendern.',
         '; Zellen: je 64 Byte Bitmap (16 Zeilen x 4) + 32 Byte Attribute (8 x 4, hi = Hintergrund).',
         '; Reihenfolge gen_gfx_run.CELL_ORDER: ' + ', '.join(G.CELL_ORDER) + '.',
         'VDC_CELL_BYTES = 96', 'VDC_SPR_W = 5', 'VDC_SPR_COUNT = %d' % len(sp), '']
    for label, cs in (('vdc_cells_meadow', cm), ('vdc_cells_winter', cw)):
        o.append(label)
        for name, bm, at, _ in cs:
            o.append('; ' + name)
            for r in bm: o.append('        !byte ' + hx(r))
            for r in at: o.append('        !byte ' + hx(r))
        o.append('')
    o.append('; Sprites: Masken (1 = Koerperpixel), 5 Byte breit, Verschiebung 0 und 4 Pixel')
    o.append('; danach je Blockzeile 5 Attribute: $FF leer; 0 Randblock: Figurfarbe auf der Grundfarbe der Kachel;')
    o.append('; $80 Randblock: schwarz (Kontur) auf der Grundfarbe; sonst fertiges Attribut (schwarz hinterlegt)')
    for i, (n, h, col, shifts) in enumerate(sp):
        for s, (rows, att) in zip((0, 4), shifts):
            o.append('vdc_spr_%d_s%d    ; %s' % (i, s, n))
            for r in rows: o.append('        !byte ' + hx(r))
            for r in att: o.append('        !byte ' + hx(r))
    o.append('vdc_spr_lo')
    o.append('        !byte ' + ', '.join('<vdc_spr_%d_s0, <vdc_spr_%d_s4' % (i, i) for i in range(len(sp))))
    o.append('vdc_spr_hi')
    o.append('        !byte ' + ', '.join('>vdc_spr_%d_s0, >vdc_spr_%d_s4' % (i, i) for i in range(len(sp))))
    o.append('vdc_spr_h')
    o.append('        !byte ' + ', '.join(str(h) for _, h, _, _ in sp))
    o.append('vdc_spr_col')
    o.append('        !byte ' + ', '.join(str(c) for _, _, c, _ in sp))
    o.append('')
    o.append('; Icons und Mini-Zellen: res_vdc_gfx.asm (Ressource-Datei, nur im VRAM)')
    r = ['; res_vdc_gfx.asm - GENERIERT von tools/gen_vdc_gfx.py - nicht von Hand aendern.', '']
    r.append('; Mini-Zellen fuer die Legende: 16x8 (8 Zeilen x 2 Bytes, dann 4 x 2 Attribute), je 24 Byte')
    for label, ms in (('vdc_mini_meadow', minis(cm)), ('vdc_mini_winter', minis(cw)), ('vdc_mini_robot', mini_robots())):
        r.append(label)
        for bm, at in ms:
            r.append('        !byte ' + ', '.join(hx(r) for r in bm) + ', ' + ', '.join(hx(r) for r in at))
    r.append('')
    r.append('; Befehls-Icons 0..8 (Fwd, Back, Right, Left, Pick, Drop, Turn 180, Jump, Throw), je 32x16')
    r.append('vdc_icons')
    for k, rows in enumerate(ic):
        r.append('; Befehl %d' % k)
        for row in rows: r.append('        !byte ' + hx(row))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    open(OUT, 'w').write('\n'.join(o) + '\n')
    open(OUT_RES, 'w').write('\n'.join(r) + '\n')
    print('gfx_vdc.asm: %d+%d Zellen (%d/%d Bloecke angepasst), %d Sprites, %d Icons' %
          (len(cm), len(cw), bad_m, bad_w, len(sp), len(ic)))
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1], cm, cw, sp, ic)


def preview(path, cm, cw, sp, ic):
    """Alle Zellen beider Themes, Roboter auf Gras (beide Verschiebungen), Icons; 2x/4x."""
    from PIL import Image
    W, H = 640, 150
    img = Image.new('RGB', (W, H), (0, 0, 0)); p = img.load()

    def put(x0, y0, bm, at):
        for y, r in enumerate(bm):
            for bx, b in enumerate(r):
                a = at[y // 2][bx]; bg, fg = a >> 4, a & 15
                for k in range(8):
                    p[x0 + bx * 8 + k, y0 + y] = RGB[fg if b & (0x80 >> k) else bg]
    for row, cs in enumerate((cm, cw)):
        for i, (_, bm, at, _) in enumerate(cs):
            put(8 + i * 38, 8 + row * 24, bm, at)
    grass = cm[0]
    def put_sprite(x0, y0, spr, s, variant):
        rows, att = spr[3][s]
        put(x0, y0, grass[1], grass[2])
        for y in range(min(16, len(rows))):
            for bx in range(5):
                a = att[y // 2][bx]
                if a == 0xFF: continue
                tbg = grass[2][min(7, y // 2)][min(3, bx)] >> 4
                if a == 0: bg, fg = tbg, spr[2]
                elif a == 0x80: bg, fg = tbg, 0
                else: bg, fg = a >> 4, a & 15
                for k in range(8):
                    x = x0 + bx * 8 + k
                    if x < W: p[x, y0 + y] = RGB[fg if rows[y][bx] & (0x80 >> k) else bg]
    for i in range(16):
        put_sprite(8 + i * 38, 60, sp[i if i < 16 else 0], i % 2, 'C')
    for i in (16, 17):
        put_sprite(8 + (i - 16) * 38, 92, sp[i], 0, 'C')
    for i, rows in enumerate(ic):
        put(8 + i * 38, 124, rows, [[0x0F] * 4 for _ in range(8)])
    img.resize((W * 2, H * 4), Image.NEAREST).save(path)
    print('Vorschau:', path)


if __name__ == '__main__':
    main()
