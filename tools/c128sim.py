#!/usr/bin/env python3
"""c128sim.py - vereinfachter C128 (C128-Modus, 8502 + VIC-II) auf Basis von c64sim.C64.

Bildet nur ab, was ArtyBot braucht: MMU-Konfigurationsregister ($FF00, bei I/O auch $D500)
fuer RAM-Bank 0, System-ROM / Zeichensatz-ROM / I/O. ROM-Bereiche liefern beim Lesen
$60 (keine ROM-Abbilder, wie in c64sim), Schreibzugriffe gehen immer ins RAM darunter.
$FF00-$FF04 sind immer MMU-Register. Nicht nachgebildet: RAM-Bank 1, Common RAM,
Farb-RAM-Baenke und Zeichensatz-ROM-Schatten des VIC ($01 Bit 0-2), 2 MHz, VDC.
Tastatur: zusaetzlich die Zeilen K0-K2 ($D02F), Codes 64..87 (KEY_UP usw.).
Start bei $1C0D (BASIC-7-Stub "SYS 7181")."""
from c64sim import C64


class C128(C64):
    def __init__(self, prg):
        super().__init__(prg)
        self.mmu = [0x00, 0, 0, 0, 0]       # CR = $00 nach dem Reset: System-ROMs + I/O
        self.pc = 0x1C0D

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
            return self.wr_io(addr, val)
        self.ram[addr] = val


    # Zusatztasten: Code 64 + Zeile*8 + Bit (Zeile K0-K2 ueber $D02F), z. B. 64+16+3 = hoch
    KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT = 83, 84, 85, 86

    def rd_io(self, addr):
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
