#!/usr/bin/env python3
# Static preview of the run screen art (field + sprites), C64 Pepto palette.
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_gfx_run as G
from PIL import Image

PAL = [0x000000,0xFFFFFF,0x68372B,0x70A4B2,0x6F3D86,0x588D43,0x352879,0xB8C76F,
       0x6F4F25,0x433900,0x9A6759,0x444444,0x6C6C6C,0x9AD284,0x6C5EB5,0x959595]
def rgb(i): v = PAL[i]; return ((v>>16)&255,(v>>8)&255,v&255)

BG = {'.':0,'g':5,'l':13}
CELLCOL = {'grass':5,'tree':2,'chest':2,'goal':3,'flowers':7,'water':6,'path':7,'gate_l':2,'gate_r':2}
ROBOT_COL = int(sys.argv[1]) if len(sys.argv) > 1 else 15
CHEST_COL = 2

def draw_cell(img, name, cx, cy):
    art = [x for x in G.CELLS[name].strip('\n').split('\n')]
    for y,row in enumerate(art):
        for x,p in enumerate(row):
            col = CELLCOL[name] if p=='c' else BG[p]
            for k in range(2): img.putpixel((cx+x*2+k, cy+y), rgb(col))

def draw_spr(img, art, sx, sy, col):
    m = {'B':0,'W':1,'c':col}
    for y,row in enumerate(art):
        for x,p in enumerate(row):
            if p=='.': continue
            for k in range(2):
                X,Y = sx+x*2+k, sy+y
                if 0<=X<img.width and 0<=Y<img.height: img.putpixel((X,Y), rgb(m[p]))

W,H = 16*10, 16*6
img = Image.new('RGB',(W,H))
layout = ["gfgggwgtlr",
          "gtgcgwgfgg",
          "gpppowggtg",
          "gfgggggggg",
          "ggtggfgtgg",
          "gggggggggg"]
names = {'g':'grass','t':'tree','c':'chest','o':'goal','f':'flowers','w':'water','p':'path','l':'gate_l','r':'gate_r'}
for y,row in enumerate(layout):
    for x,ch in enumerate(row):
        draw_cell(img, names[ch], x*16, y*16)
_, imgs = G.sprite_images()
# robots: row 3 standing (r,l,u,d), row 4 step frames, row 5 carrying
for i in range(4):
    draw_spr(img, imgs[i], (i*2)*16, 3*16-2, ROBOT_COL)
    draw_spr(img, imgs[8+i], (i*2+1)*16, 3*16-2, ROBOT_COL)
    draw_spr(img, imgs[4+i], (i*2)*16, 5*16-2, ROBOT_COL)
    draw_spr(img, imgs[16], (i*2)*16, 5*16-2-8, CHEST_COL)
    draw_spr(img, imgs[12+i], (i*2+1)*16, 5*16-2, ROBOT_COL)
    draw_spr(img, imgs[16], (i*2+1)*16, 5*16-2-8, CHEST_COL)
img = img.resize((W*4,H*4), Image.NEAREST)
out = sys.argv[2] if len(sys.argv) > 2 else 'preview.png'
img.save(out); print(out)

def robots_sheet(path, col):
    W,H = 16*8, 16*3
    im = Image.new('RGB',(W,H))
    for y in range(3):
        for x in range(8):
            draw_cell(im, 'grass', x*16, y*16)
    for i in range(4):
        draw_spr(im, imgs[i], (i*2)*16, 0*16+0, col)
        draw_spr(im, imgs[8+i], (i*2+1)*16, 0, col)
        draw_spr(im, imgs[4+i], (i*2)*16, 28, col)
        draw_spr(im, imgs[16], (i*2)*16, 28-3, CHEST_COL)
        draw_spr(im, imgs[12+i], (i*2+1)*16, 28, col)
        draw_spr(im, imgs[16], (i*2+1)*16, 28-4, CHEST_COL)
    im.resize((W*7,H*7), Image.NEAREST).save(path)
if len(sys.argv) > 3:
    robots_sheet(sys.argv[3], ROBOT_COL)
