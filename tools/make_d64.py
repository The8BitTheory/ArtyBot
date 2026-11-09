#!/usr/bin/env python3
"""make_d64.py - schreibt ein D64-Diskettenimage (1541, 35 Spuren) mit PRG-Dateien.

  python3 -B tools/make_d64.py OUT.d64 "DISKNAME" DATEI[=NAME] ...

NAME ist der Name auf der Diskette (sonst der Dateiname ohne Endung, klein). Dateien werden
als PRG ab Spur 17 abwaerts und ab 19 aufwaerts abgelegt (Spur 18 = Verzeichnis)."""
import sys, os

SPT = [21] * 17 + [19] * 7 + [18] * 6 + [17] * 5          # Sektoren je Spur 1..35


def offset(t, s):
    return (sum(SPT[:t - 1]) + s) * 256


def petscii(name):
    out = bytearray()
    for ch in name:
        c = ord(ch)
        if 0x61 <= c <= 0x7A: c -= 0x20          # klein -> PETSCII-Grossbuchstaben (Zeichensatz 2: klein)
        elif 0x41 <= c <= 0x5A: c += 0x80
        out.append(c)
    return bytes(out)


def main():
    out, diskname = sys.argv[1], sys.argv[2]
    files = []
    for a in sys.argv[3:]:
        path, _, name = a.partition('=')
        files.append((name or os.path.splitext(os.path.basename(path))[0].lower(), open(path, 'rb').read()))
    img = bytearray(683 * 256)
    free = {t: set(range(SPT[t - 1])) for t in range(1, 36)}
    free[18] -= {0, 1}
    order = [t for t in range(17, 0, -1)] + [t for t in range(19, 36)]
    dirents = []
    for name, data in files:
        chunks = [data[i:i + 254] for i in range(0, len(data), 254)] or [b'']
        secs = []
        for _ in chunks:
            t = next(t for t in order if free[t])
            s = min(free[t]); free[t].discard(s); secs.append((t, s))
        for i, (t, s) in enumerate(secs):
            o = offset(t, s); c = chunks[i]
            if i + 1 < len(secs):
                img[o], img[o + 1] = secs[i + 1]
            else:
                img[o], img[o + 1] = 0, len(c) + 1
            img[o + 2:o + 2 + len(c)] = c
        dirents.append((name, secs[0], len(secs)))
    # Verzeichnis 18/1 (bis 8 Eintraege)
    assert len(dirents) <= 8
    d = offset(18, 1)
    img[d], img[d + 1] = 0, 0xFF
    for i, (name, (t, s), n) in enumerate(dirents):
        e = d + i * 32
        img[e + 2] = 0x82                         # PRG, geschlossen
        img[e + 3], img[e + 4] = t, s
        nm = petscii(name)[:16]
        img[e + 5:e + 21] = nm + b'\xA0' * (16 - len(nm))
        img[e + 30], img[e + 31] = n & 255, n >> 8
    # BAM 18/0
    b = offset(18, 0)
    img[b:b + 4] = bytes([18, 1, 0x41, 0])
    for t in range(1, 36):
        fr = free[t]
        bits = sum(1 << s for s in fr)
        e = b + 4 * t
        img[e] = len(fr)
        img[e + 1:e + 4] = bytes([bits & 255, (bits >> 8) & 255, (bits >> 16) & 255])
    dn = petscii(diskname)[:16]
    img[b + 0x90:b + 0xA0] = dn + b'\xA0' * (16 - len(dn))
    img[b + 0xA0:b + 0xAB] = b'\xA0\xA0AB\xA02A\xA0\xA0\xA0\xA0'
    open(out, 'wb').write(img)
    print('%s: %s' % (out, ', '.join('%s (%d Bl.)' % (n, c) for n, _, c in dirents)))


if __name__ == '__main__':
    main()
