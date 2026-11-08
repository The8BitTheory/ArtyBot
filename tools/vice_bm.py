#!/usr/bin/env python3
"""vice_bm.py - kleiner Client fuer den Binary Monitor von VICE (ab 3.5), fuer Tests mit
echtem Emulator (auch headless gebaut: configure --enable-headlessui).

VICE starten mit:  x64sc -binarymonitor -binarymonitoraddress ip4://127.0.0.1:6502 ...
Benutzt nur die Standardbibliothek (Bilder: Pillow, wenn vorhanden).

  bm = BM(); bm.wait_stopped() ...
"""
import socket, struct, time

CMD_MEM_GET, CMD_MEM_SET = 0x01, 0x02
CMD_CP_SET, CMD_CP_DEL = 0x12, 0x13
CMD_REG_GET, CMD_REG_SET, CMD_REG_AVAIL = 0x31, 0x32, 0x83
CMD_DISPLAY, CMD_PALETTE = 0x84, 0x91
CMD_EXIT, CMD_QUIT, CMD_RESET, CMD_AUTOSTART = 0xAA, 0xBB, 0xCC, 0xDD
EV_CHECKPOINT, EV_STOPPED, EV_RESUMED, EV_JAM = 0x11, 0x62, 0x63, 0x61
EVENT_ID = 0xFFFFFFFF


class BM:
    def __init__(self, host='127.0.0.1', port=6502, timeout=30):
        t0 = time.time()
        while True:
            try:
                self.s = socket.create_connection((host, port), timeout=timeout)
                break
            except OSError:
                if time.time() - t0 > timeout: raise
                time.sleep(0.2)
        self.rid = 1
        self.events = []
        self.buf = b''
        self.stopped = False
        self.regs = {}

    # ---- transport
    def _recv(self, n):
        while len(self.buf) < n:
            d = self.s.recv(65536)
            if not d: raise EOFError('VICE hat die Verbindung geschlossen')
            self.buf += d
        r, self.buf = self.buf[:n], self.buf[n:]
        return r

    def _read_msg(self):
        h = self._recv(12)
        stx, api, ln, rtype, err, rid = struct.unpack('<BBIBBI', h)
        body = self._recv(ln)
        if rtype == EV_STOPPED: self.stopped = True
        if rtype == EV_RESUMED: self.stopped = False
        return rtype, err, rid, body

    def cmd(self, ctype, body=b''):
        rid = self.rid; self.rid += 1
        self.s.sendall(struct.pack('<BBIIB', 2, 2, len(body), rid, ctype) + body)
        while True:
            rtype, err, r, b = self._read_msg()
            if r == rid:
                if err: raise RuntimeError('VICE-Fehler %02X bei Befehl %02X' % (err, ctype))
                return rtype, b
            self.events.append((rtype, b))

    def wait_checkpoint(self, timeout=60):
        """Wartet auf einen Checkpoint-Treffer (Ereignis 0x11) und das folgende Stopped.
        Liefert die Checkpoint-Nummer; der Emulator steht danach."""
        self.events = [e for e in self.events if e[0] not in (EV_STOPPED, EV_RESUMED)]
        t, b = self.wait_event((EV_CHECKPOINT, EV_JAM), timeout)
        if t == EV_JAM:
            raise RuntimeError('CPU JAM bei $%04X' % struct.unpack('<H', b[:2])[0])
        self.wait_event((EV_STOPPED,), timeout)
        return struct.unpack('<I', b[:4])[0]

    def wait_event(self, types, timeout=60):
        """Wartet auf ein Ereignis (z. B. EV_STOPPED) und liefert (typ, body)."""
        for i, (t, b) in enumerate(self.events):
            if t in types:
                del self.events[i]; return t, b
        self.s.settimeout(timeout)
        while True:
            t, err, r, b = self._read_msg()
            if t in types: return t, b
            self.events.append((t, b))

    # ---- commands
    def mem_get(self, start, end, side_effects=0):
        _, b = self.cmd(CMD_MEM_GET, struct.pack('<BHHBH', side_effects, start, end, 0, 0))
        n = struct.unpack('<H', b[:2])[0]
        return b[2:2 + n]

    def mem_set(self, start, data, side_effects=0):
        data = bytes(data)
        self.cmd(CMD_MEM_SET, struct.pack('<BHHBH', side_effects, start, start + len(data) - 1, 0, 0) + data)

    def checkpoint(self, start, end=None, stop=True, op=4, temporary=False):
        _, b = self.cmd(CMD_CP_SET, struct.pack('<HHBBBB', start, end if end is not None else start,
                                                1 if stop else 0, 1, op, 1 if temporary else 0))
        return struct.unpack('<I', b[:4])[0]

    def delete_checkpoint(self, cid):
        self.cmd(CMD_CP_DEL, struct.pack('<I', cid))

    def reg_ids(self):
        if not self.regs:
            _, b = self.cmd(CMD_REG_AVAIL, b'\x00')
            n = struct.unpack('<H', b[:2])[0]; p = 2
            for _ in range(n):
                size = b[p]; rid, bits, nl = b[p + 1], b[p + 2], b[p + 3]
                name = b[p + 4:p + 4 + nl].decode()
                self.regs[name.upper()] = rid
                p += size + 1
        return self.regs

    def get_regs(self):
        ids = {v: k for k, v in self.reg_ids().items()}
        _, b = self.cmd(CMD_REG_GET, b'\x00')
        n = struct.unpack('<H', b[:2])[0]; p = 2; out = {}
        for _ in range(n):
            size, rid, val = b[p], b[p + 1], struct.unpack('<H', b[p + 2:p + 4])[0]
            out[ids.get(rid, rid)] = val; p += size + 1
        return out

    def set_regs(self, **vals):
        ids = self.reg_ids()
        items = b''.join(struct.pack('<BBH', 3, ids[k.upper()], v) for k, v in vals.items())
        self.cmd(CMD_REG_SET, struct.pack('<BH', 0, len(vals)) + items)

    def resume(self):
        self.cmd(CMD_EXIT)

    def quit(self):
        try: self.cmd(CMD_QUIT)
        except Exception: pass

    def display(self, vicii=True):
        """Bild als (breite, hoehe, bytes 8 bpp Palettenindex, palette) - nur der innere Teil
        plus Rand wie im Emulatorfenster (Debug-Ausschnitt XO/YO)."""
        _, b = self.cmd(CMD_DISPLAY, bytes([1 if vicii else 0, 0]))
        fl = struct.unpack('<I', b[:4])[0]
        dw, dh, xo, yo, iw, ih, bpp = struct.unpack('<HHHHHHB', b[4:17])
        bl = struct.unpack('<I', b[17:21])[0]
        data = b[4 + fl:4 + fl + bl]
        _, pb = self.cmd(CMD_PALETTE, bytes([1 if vicii else 0]))
        n = struct.unpack('<H', pb[:2])[0]; pal = []; p = 2
        for _ in range(n):
            size = pb[p]; pal.append(tuple(pb[p + 1:p + 4])); p += size + 1
        return dict(dw=dw, dh=dh, xo=xo, yo=yo, iw=iw, ih=ih, data=data, pal=pal)

    def save_png(self, path, vicii=True, border=32, xscale=1, yscale=1):
        from PIL import Image
        d = self.display(vicii)
        im = Image.frombytes('P', (d['dw'], d['dh']), d['data'])
        flat = []
        for c in d['pal']: flat += list(c)
        im.putpalette(flat + [0] * (768 - len(flat)))
        x0, y0 = max(0, d['xo'] - border), max(0, d['yo'] - border)
        im = im.crop((x0, y0, min(d['dw'], d['xo'] + d['iw'] + border), min(d['dh'], d['yo'] + d['ih'] + border)))
        im = im.convert('RGB')
        if xscale != 1 or yscale != 1:
            im = im.resize((im.width * xscale, im.height * yscale), Image.NEAREST)
        im.save(path)
        return im
