#!/usr/bin/env python3
"""Pick Up / Drop Off command icons (2x2 hires characters = 16x16 pixels, X = pixel set):
a package with an arrow next to it (up = pick up, down = drop off).
Prints the !byte blocks for $F0-$F7 in src/gfx_data.asm (order TL, TR, BL, BR per icon).
Usage: python -B tools/gen_cmd_icons.py"""

BOX = [
    "XXXXXXXXX",
    "X...X...X",
    "X...X...X",
    "X...X...X",
    "XXXXXXXXX",
    "X...X...X",
    "X...X...X",
    "X...X...X",
    "XXXXXXXXX",
]

def canvas():
    return [[0] * 16 for _ in range(16)]

def put_box(c, top=4, left=1):
    for y, row in enumerate(BOX):
        for x, ch in enumerate(row):
            if ch == 'X':
                c[top + y][left + x] = 1

def arrow(c, up):
    # thin chevron head with shaft on column 13, rows 3..12
    pts = []
    if up:
        pts += [(3, 13), (4, 12), (4, 14), (5, 11), (5, 15)]
        pts += [(y, 13) for y in range(4, 13)]
    else:
        pts += [(12, 13), (11, 12), (11, 14), (10, 11), (10, 15)]
        pts += [(y, 13) for y in range(3, 12)]
    for y, x in pts:
        c[y][x] = 1

def encode(c):
    out = []
    for (y0, x0) in ((0, 0), (0, 8), (8, 0), (8, 8)):      # TL, TR, BL, BR
        out.append([sum(c[y0 + y][x0 + x] << (7 - x) for x in range(8)) for y in range(8)])
    return out

def show(c):
    return '\n'.join('; ' + ''.join('x' if v else '.' for v in r) for r in c)

if __name__ == '__main__':
    for title, up, base in (('PICK UP (package, arrow up)', True, 0xF0),
                            ('DROP OFF (package, arrow down)', False, 0xF4)):
        c = canvas(); put_box(c); arrow(c, up)
        print('; $%02X-$%02X - %s' % (base, base + 3, title))
        for i, ch in enumerate(encode(c)):
            print('; $%02X' % (base + i))
            print('        !byte ' + ','.join('$%02X' % b for b in ch))
