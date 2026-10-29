#!/usr/bin/env python3
"""Minimal C64 test harness: 6502 CPU, RAM/ROM banking, raster IRQ, CIA1
keyboard matrix, and a VIC-II renderer (text/multicolour chars + sprites).
Character ROM is replaced by a synthetic font (only for readable previews)."""
import sys
from PIL import Image, ImageDraw, ImageFont

PAL = [0x000000,0xFFFFFF,0x68372B,0x70A4B2,0x6F3D86,0x588D43,0x352879,0xB8C76F,
       0x6F4F25,0x433900,0x9A6759,0x444444,0x6C6C6C,0x9AD284,0x6C5EB5,0x959595]
RGB = [((v>>16)&255,(v>>8)&255,v&255) for v in PAL]

def make_chargen():
    """4 KB: upper/graphics set (unused) + lower/upper set at +$800."""
    font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf', 9)
    rom = bytearray(4096)
    def glyph(ch):
        im = Image.new('1', (8, 8), 0)
        d = ImageDraw.Draw(im)
        d.text((1, -2), ch, font=font, fill=1)
        return [sum((im.getpixel((x, y)) and 1) << (7-x) for x in range(8)) for y in range(8)]
    table = {}
    table[0] = '@'
    for i in range(26):
        table[1+i] = chr(ord('a')+i)
        table[0x41+i] = chr(ord('A')+i)
    table[0x1B] = '['; table[0x1D] = ']'; table[0x1E] = '^'; table[0x1F] = '<'
    for c in range(0x20, 0x40):
        table[c] = chr(c)
    table[0x40] = '-'
    for code, ch in table.items():
        g = glyph(ch) if ch != ' ' else [0]*8
        for half in (0, 0x800):
            rom[half + code*8: half + code*8+8] = bytes(g)
            rom[half + (code|0x80)*8: half + (code|0x80)*8+8] = bytes(255-b for b in g)
    for half in (0, 0x800):
        rom[half+0xA0*8:half+0xA0*8+8] = b'\xff'*8
    return rom

class C64:
    def __init__(self, prg):
        self.ram = bytearray(65536)
        self.io = bytearray(4096)
        self.colram = bytearray(1024)
        self.chargen = make_chargen()
        self.ram[0] = 0x2F; self.ram[1] = 0x37
        load = prg[0] | prg[1] << 8
        self.ram[load:load+len(prg)-2] = prg[2:]
        self.a = self.x = self.y = 0
        self.sp = 0xFF; self.p = 0x24; self.pc = 0x080D
        self.cycles = 0; self.next_irq = 19656
        self.keys = set()           # pressed key codes (8*PA bit + PB bit)
        self.pra = 0xFF
        self.io[0xD00] = 0x03
        self.frames = 0
    # ---- memory
    def visible(self, addr):
        b = self.ram[1] & 7
        if 0xD000 <= addr < 0xE000:
            if b & 3 == 0: return 'ram'
            return 'io' if b & 4 else 'char'
        if addr >= 0xE000 and (b & 2): return 'kernal'
        if 0xA000 <= addr < 0xC000 and (b & 3) == 3: return 'basic'
        return 'ram'
    def rd(self, addr):
        addr &= 0xFFFF
        if addr < 0xA000 or 0xC000 <= addr < 0xD000:
            return self.ram[addr]
        v = self.visible(addr)
        if v == 'ram': return self.ram[addr]
        if v == 'char': return self.chargen[addr - 0xD000]
        if v in ('kernal', 'basic'):
            if addr >= 0xFFFA: return self.ram[addr]  # harness: no ROM images
            return 0x60
        return self.rd_io(addr)
    def wr(self, addr, val):
        addr &= 0xFFFF; val &= 0xFF
        if 0xD000 <= addr < 0xE000 and self.visible(addr) == 'io':
            return self.wr_io(addr, val)
        self.ram[addr] = val
    def rd_io(self, addr):
        o = addr - 0xD000
        if 0xD800 <= addr < 0xDC00: return self.colram[addr-0xD800] | 0xF0
        if addr == 0xD012:
            return (self.cycles // 63) % 312 & 0xFF
        if addr == 0xD011:
            return (self.io[0x11] & 0x7F) | (0x80 if (self.cycles//63) % 312 > 255 else 0)
        if addr == 0xD019: return self.io[0x19] | 0x70
        if addr in (0xD419, 0xD41A): return 0
        if (addr & 0xFF0F) == 0xDC01:
            v = 0xFF
            for k in self.keys:
                pa, pb = k >> 3, k & 7
                if not (self.pra >> pa) & 1:
                    v &= ~(1 << pb)
            return v & 0xFF
        if (addr & 0xFF0F) == 0xDC00: return self.pra
        if (addr & 0xFF0F) == 0xDC0D: return 0
        if (addr & 0xFF0F) == 0xDD0D: return 0
        return self.io[o]
    def wr_io(self, addr, val):
        o = addr - 0xD000
        if 0xD800 <= addr < 0xDC00: self.colram[addr-0xD800] = val & 15; return
        if addr == 0xD019: self.io[0x19] &= ~val & 0xFF; return
        if (addr & 0xFF0F) == 0xDC00: self.pra = val
        self.io[o if addr < 0xDC00 else (o & 0xF0F)] = val
        if addr >= 0xDC00: self.io[o] = val
    # ---- CPU
    def push(self, v): self.ram[0x100+self.sp] = v & 0xFF; self.sp = (self.sp-1) & 0xFF
    def pull(self): self.sp = (self.sp+1) & 0xFF; return self.ram[0x100+self.sp]
    def nz(self, v):
        v &= 0xFF
        self.p = (self.p & 0x7D) | (v & 0x80) | (0 if v else 2)
        return v
    def irq(self):
        self.push(self.pc >> 8); self.push(self.pc & 0xFF)
        self.push((self.p | 0x20) & ~0x10)
        self.p |= 4
        self.pc = self.rd(0xFFFE) | self.rd(0xFFFF) << 8
    def adc(self, v):
        c = self.p & 1
        r = self.a + v + c
        self.p &= ~0x41 & 0xFF
        if r > 0xFF: self.p |= 1
        if (~(self.a ^ v) & (self.a ^ r)) & 0x80: self.p |= 0x40
        self.a = self.nz(r)
    def sbc(self, v): self.adc(v ^ 0xFF)
    def cmp(self, r, v):
        t = r - v
        self.p = (self.p & ~1) | (1 if t >= 0 else 0)
        self.nz(t)
    def step(self):
        if self.cycles >= self.next_irq:
            self.next_irq += 19656
            self.frames += 1
            if self.io[0x1A] & 1:
                self.io[0x19] |= 0x81
            if self.io[0x19] & 0x80 and not (self.p & 4):
                self.irq()
        elif self.io[0x19] & 0x80 and not (self.p & 4) and self.io[0x1A] & 1:
            self.irq()
        pc = self.pc
        op = self.rd(pc)
        self.pc = (pc + 1) & 0xFFFF
        self.cycles += 3
        R = self.rd
        def imm(): v = R(self.pc); self.pc = (self.pc+1) & 0xFFFF; return v
        def zp(): return imm()
        def zpx(): return (imm() + self.x) & 0xFF
        def zpy(): return (imm() + self.y) & 0xFF
        def ab(): lo = imm(); hi = imm(); return lo | hi << 8
        def abx(): return (ab() + self.x) & 0xFFFF
        def aby(): return (ab() + self.y) & 0xFFFF
        def izx(): z = (imm() + self.x) & 0xFF; return R(z) | R((z+1) & 0xFF) << 8
        def izy(): z = imm(); return ((R(z) | R((z+1) & 0xFF) << 8) + self.y) & 0xFFFF
        modes = {0:izx,1:zp,2:None,3:ab,4:izy,5:zpx,6:aby,7:abx}
        aaa, bbb, cc = op >> 5, (op >> 2) & 7, op & 3
        def br(cond):
            off = imm()
            if cond:
                self.pc = (self.pc + (off - 256 if off & 0x80 else off)) & 0xFFFF
        # specials first
        if op == 0x00: raise RuntimeError('BRK at %04X' % pc)
        if op == 0x20:
            t = ab(); r = (self.pc - 1) & 0xFFFF
            self.push(r >> 8); self.push(r & 0xFF); self.pc = t; return
        if op == 0x60: lo = self.pull(); hi = self.pull(); self.pc = ((lo | hi << 8) + 1) & 0xFFFF; return
        if op == 0x40:
            self.p = self.pull() | 0x20; lo = self.pull(); hi = self.pull(); self.pc = lo | hi << 8; return
        if op == 0x4C: self.pc = ab(); return
        if op == 0x6C:
            a = ab(); self.pc = R(a) | R((a & 0xFF00) | ((a+1) & 0xFF)) << 8; return
        if op & 0x1F == 0x10:
            flag = [0x80, 0x40, 0x01, 0x02][op >> 6]
            want = (op >> 5) & 1
            br(bool(self.p & flag) == bool(want)); return
        simple = {
            0x08: lambda: self.push(self.p | 0x30), 0x28: lambda: setattr(self, 'p', self.pull() | 0x20),
            0x48: lambda: self.push(self.a), 0x68: lambda: setattr(self, 'a', self.nz(self.pull())),
            0x18: lambda: setattr(self, 'p', self.p & ~1), 0x38: lambda: setattr(self, 'p', self.p | 1),
            0x58: lambda: setattr(self, 'p', self.p & ~4), 0x78: lambda: setattr(self, 'p', self.p | 4),
            0xB8: lambda: setattr(self, 'p', self.p & ~0x40), 0xD8: lambda: setattr(self, 'p', self.p & ~8),
            0xF8: lambda: setattr(self, 'p', self.p | 8),
            0x88: lambda: setattr(self, 'y', self.nz(self.y-1)), 0xC8: lambda: setattr(self, 'y', self.nz(self.y+1)),
            0xCA: lambda: setattr(self, 'x', self.nz(self.x-1)), 0xE8: lambda: setattr(self, 'x', self.nz(self.x+1)),
            0x8A: lambda: setattr(self, 'a', self.nz(self.x)), 0x98: lambda: setattr(self, 'a', self.nz(self.y)),
            0xAA: lambda: setattr(self, 'x', self.nz(self.a)), 0xA8: lambda: setattr(self, 'y', self.nz(self.a)),
            0x9A: lambda: setattr(self, 'sp', self.x), 0xBA: lambda: setattr(self, 'x', self.nz(self.sp)),
            0xEA: lambda: None,
        }
        if op in simple: simple[op](); return
        if cc == 1:
            if op == 0x89: raise RuntimeError('bad op %02X at %04X' % (op, pc))
            if bbb == 2: v = imm(); addr = None
            else: addr = modes[bbb](); v = None
            if aaa == 4: self.wr(addr, self.a); return
            if v is None: v = R(addr)
            if aaa == 0: self.a = self.nz(self.a | v)
            elif aaa == 1: self.a = self.nz(self.a & v)
            elif aaa == 2: self.a = self.nz(self.a ^ v)
            elif aaa == 3: self.adc(v)
            elif aaa == 5: self.a = self.nz(v)
            elif aaa == 6: self.cmp(self.a, v)
            elif aaa == 7: self.sbc(v)
            return
        if cc == 2:
            if op == 0xA2: self.x = self.nz(imm()); return
            if bbb == 2:   # accumulator
                addr = None; v = self.a
            else:
                if bbb == 0: raise RuntimeError('bad op %02X at %04X' % (op, pc))
                if aaa in (4, 5) and bbb == 5: addr = zpy()
                elif aaa == 5 and bbb == 7: addr = aby()
                else: addr = {1: zp, 3: ab, 5: zpx, 7: abx}[bbb]()
                v = None
            if aaa == 4: self.wr(addr, self.x); return
            if aaa == 5: self.x = self.nz(R(addr)); return
            if v is None: v = R(addr)
            c = self.p & 1
            if aaa == 0: c2 = v >> 7; r = (v << 1) & 0xFF
            elif aaa == 1: c2 = v >> 7; r = ((v << 1) | c) & 0xFF
            elif aaa == 2: c2 = v & 1; r = v >> 1
            elif aaa == 3: c2 = v & 1; r = (v >> 1) | (c << 7)
            elif aaa == 6: c2 = c; r = (v - 1) & 0xFF
            elif aaa == 7: c2 = c; r = (v + 1) & 0xFF
            self.p = (self.p & ~1) | c2
            self.nz(r)
            if addr is None: self.a = r
            else: self.wr(addr, r)
            return
        if cc == 0:
            if op == 0xA0: self.y = self.nz(imm()); return
            if op == 0xC0: self.cmp(self.y, imm()); return
            if op == 0xE0: self.cmp(self.x, imm()); return
            addr = {1: zp, 3: ab, 5: zpx, 7: abx}[bbb]()
            if aaa == 1:   # BIT
                v = R(addr)
                self.p = (self.p & 0x3D) | (v & 0xC0) | (0 if self.a & v else 2); return
            if aaa == 4: self.wr(addr, self.y); return
            if aaa == 5: self.y = self.nz(R(addr)); return
            if aaa == 6: self.cmp(self.y, R(addr)); return
            if aaa == 7: self.cmp(self.x, R(addr)); return
        raise RuntimeError('unhandled op %02X at %04X' % (op, pc))
    def run_frames(self, n):
        target = self.frames + n
        while self.frames < target:
            self.step()
    # ---- VIC render
    def render(self, scale=3):
        bank = (3 - (self.io[0xD00] & 3)) * 0x4000
        d018 = self.io[0x18]
        scr = bank + (d018 >> 4) * 0x400
        chs = bank + ((d018 >> 1) & 7) * 0x800
        mc = self.io[0x16] & 0x10
        bgc = [self.io[0x21] & 15, self.io[0x22] & 15, self.io[0x23] & 15]
        B = 32
        im = Image.new('RGB', (320 + 2*B, 200 + 2*B), RGB[self.io[0x20] & 15])
        px = im.load()
        for row in range(25):
            for col in range(40):
                code = self.ram[scr + row*40 + col]
                cr = self.colram[row*40 + col]
                for line in range(8):
                    bits = self.ram[chs + code*8 + line]
                    y = B + row*8 + line
                    if mc and cr & 8:
                        for k in range(4):
                            v = (bits >> (6 - 2*k)) & 3
                            c = RGB[cr & 7] if v == 3 else RGB[bgc[v]]
                            px[B+col*8+2*k, y] = c; px[B+col*8+2*k+1, y] = c
                    else:
                        for k in range(8):
                            px[B+col*8+k, y] = RGB[cr] if bits & (0x80 >> k) else RGB[bgc[0]]
        en = self.io[0x15]
        for s in range(7, -1, -1):
            if not en & (1 << s): continue
            ptr = self.ram[scr + 0x3F8 + s]
            data = bank + ptr*64
            sx = self.io[2*s] | ((self.io[0x10] >> s) & 1) << 8
            sy = self.io[2*s+1]
            smc = self.io[0x1C] & (1 << s)
            cols = [None, RGB[self.io[0x25] & 15], RGB[self.io[0x27+s] & 15], RGB[self.io[0x26] & 15]]
            for line in range(21):
                for byte in range(3):
                    bits = self.ram[data + line*3 + byte]
                    for k in range(8):
                        X = sx - 24 + byte*8 + k + B
                        Y = sy - 50 + line + B
                        if smc:
                            v = (bits >> (6 - (k & 6))) & 3
                            c = cols[v]
                        else:
                            c = RGB[self.io[0x27+s] & 15] if bits & (0x80 >> k) else None
                        if c and 0 <= X < im.width and 0 <= Y < im.height:
                            px[X, Y] = c
        return im.resize((im.width*scale, im.height*scale), Image.NEAREST)
