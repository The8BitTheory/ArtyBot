#!/usr/bin/env python3
"""c128sim.py - vereinfachter C128 (C128-Modus, 8502 + VIC-II) auf Basis von c64sim.C64.

Bildet nur ab, was ArtyBot braucht: MMU-Konfigurationsregister ($FF00, bei I/O auch $D500)
fuer RAM-Bank 0, System-ROM / Zeichensatz-ROM / I/O. ROM-Bereiche liefern beim Lesen
$60 (keine ROM-Abbilder, wie in c64sim), Schreibzugriffe gehen immer ins RAM darunter.
$FF00-$FF04 sind immer MMU-Register. Nicht nachgebildet: RAM-Bank 1, Common RAM,
Farb-RAM-Baenke und Zeichensatz-ROM-Schatten des VIC ($01 Bit 0-2), 2 MHz.
VDC ($D600/$D601): 64 KB RAM, Register, Lesen/Schreiben ueber R31 mit Adresszaehler R18/R19,
Block-Write/-Copy (R24 Bit 7, R30, Quelle R32/R33), Status immer bereit; render_vdc() zeigt
den Bitmap-Modus mit Attributen (R25 Bit 7/6, R12/R13 Bitmap, R20/R21 Attribute, R9 Zeilen).
Tastatur: zusaetzlich die Zeilen K0-K2 ($D02F), Codes 64..87 (KEY_UP usw.).
Start bei $1C0D (BASIC-7-Stub "SYS 7181")."""
from c64sim import C64


class C128(C64):
    def __init__(self, prg):
        super().__init__(prg)
        self.mmu = [0x00, 0, 0, 0, 0]       # CR = $00 nach dem Reset: System-ROMs + I/O
        self.pc = 0x1C0D
        self.vdc = bytearray(65536)
        self.vreg = bytearray(64)
        self.vsel = 0
        self.vdc_writes = 0

    def area(self, addr):
        cr = self.mmu[0]
        if 0xFF00 <= addr <= 0xFF04: return 'mmu'
        if addr < 0x4000: return 'ram'
        if addr < 0x8000: return 'ram' if cr & 0x02 else 'rom'
        if addr < 0xC000: return 'ram' if cr & 0x0C == 0x0C else 'rom'
        if 0xD000 <= addr < 0xE000:
            if not cr & 1: return 'io'
            hi = (cr >> 4) & 3
            return 'char' if hi == 0 else ('ram' if hi == 3 else 'rom')
        return 'ram' if cr & 0x30 == 0x30 else 'rom'

    def visible(self, addr):                # fuer Aufrufer aus c64sim
        a = self.area(addr)
        return {'rom': 'kernal'}.get(a, a)

    def rd(self, addr):
        addr &= 0xFFFF
        a = self.area(addr)
        if a == 'ram': return self.ram[addr]
        if a == 'mmu': return self.mmu[addr - 0xFF00]
        if a == 'char': return self.chargen[addr - 0xD000]
        if a == 'io':
            if 0xD500 <= addr <= 0xD504: return self.mmu[addr - 0xD500]
            return self.rd_io(addr)
        return 0x60

    def wr(self, addr, val):
        addr &= 0xFFFF; val &= 0xFF
        a = self.area(addr)
        if a == 'mmu': self.mmu[addr - 0xFF00] = val; return
        if a == 'io':
            if 0xD500 <= addr <= 0xD504: self.mmu[addr - 0xD500] = val; return
            if addr in (0xD600, 0xD601): return self.vdc_wr(addr, val)
            if addr == 0xD030: self.frame_cycles = 39312 if val & 1 else 19656   # 2 MHz
            return self.wr_io(addr, val)
        self.ram[addr] = val


    # Zusatztasten: Code 64 + Zeile*8 + Bit (Zeile K0-K2 ueber $D02F), z. B. 64+16+3 = hoch
    KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT = 83, 84, 85, 86

    # ---- VDC
    def _vaddr(self): return self.vreg[18] << 8 | self.vreg[19]
    def _vset(self, a): a &= 0xFFFF; self.vreg[18] = a >> 8; self.vreg[19] = a & 255

    def vdc_rd(self, addr):
        if addr == 0xD600:
            return 0x80 | (0x20 if (self.cycles // 63) % 312 > 250 else 0)
        r = self.vsel
        if r == 31:
            a = self._vaddr(); v = self.vdc[a]; self._vset(a + 1); return v
        return self.vreg[r]

    def vdc_wr(self, addr, val):
        if addr == 0xD600: self.vsel = val & 63; return
        r = self.vsel
        if r == 31:
            a = self._vaddr(); self.vdc[a] = val; self.vreg[31] = val; self._vset(a + 1)
            self.vdc_writes += 1; return
        self.vreg[r] = val
        if r == 30:
            n = val or 256
            a = self._vaddr()
            if self.vreg[24] & 0x80:
                src = self.vreg[32] << 8 | self.vreg[33]
                for i in range(n):
                    self.vdc[(a + i) & 0xFFFF] = self.vdc[(src + i) & 0xFFFF]
                src += n; self.vreg[32] = (src >> 8) & 255; self.vreg[33] = src & 255
            else:
                for i in range(n): self.vdc[(a + i) & 0xFFFF] = self.vreg[31]
            self._vset(a + n)

    def render_vdc(self, yscale=2):
        from PIL import Image
        RGBI = [0x000000, 0x555555, 0x0000AA, 0x5555FF, 0x00AA00, 0x55FF55, 0x00AAAA, 0x55FFFF,
                0xAA0000, 0xFF5555, 0xAA00AA, 0xFF55FF, 0xAA5500, 0xFFFF55, 0xAAAAAA, 0xFFFFFF]
        P = [((v >> 16) & 255, (v >> 8) & 255, v & 255) for v in RGBI]
        bm = self.vreg[12] << 8 | self.vreg[13]
        at = self.vreg[20] << 8 | self.vreg[21]
        lines = (self.vreg[9] & 31) + 1
        rows = self.vreg[6] or 100
        cols = self.vreg[1] or 80
        im = Image.new('RGB', (cols * 8, rows * lines)); px = im.load()
        for y in range(rows * lines):
            for c in range(cols):
                b = self.vdc[(bm + y * cols + c) & 0xFFFF]
                a = self.vdc[(at + (y // lines) * cols + c) & 0xFFFF]
                fg, bg = P[a & 15], P[a >> 4]
                for k in range(8):
                    px[c * 8 + k, y] = fg if b & (0x80 >> k) else bg
        return im.resize((im.width, im.height * yscale), Image.NEAREST)

    def rd_io(self, addr):
        if addr in (0xD600, 0xD601): return self.vdc_rd(addr)
        if (addr & 0xFF0F) == 0xDC01:
            v = 0xFF
            for k in self.keys:
                if k < 64:
                    if not (self.pra >> (k >> 3)) & 1: v &= ~(1 << (k & 7))
                elif not (self.io[0x2F] >> ((k - 64) >> 3)) & 1:
                    v &= ~(1 << (k & 7))
            return v & 0xFF
        return super().rd_io(addr)


def machine(prg):
    """C64 oder C128 je nach Ladeadresse des PRG ($1C01 = C128-Modus)."""
    load = prg[0] | prg[1] << 8
    return C128(prg) if load == 0x1C01 else C64(prg)
