#!/usr/bin/env python3
"""make_d81.py - schreibt ein D81-Diskettenimage (1581, 80 Spuren x 40 Sektoren) mit PRG-Dateien.

  python3 -B tools/make_d81.py OUT.d81 "DISKNAME" DATEI[=NAME] ...

NAME ist der Name auf der Diskette (sonst der Dateiname ohne Endung, klein). Spur 40 haelt
Kopf (40/0), BAM (40/1, 40/2) und Verzeichnis (ab 40/3); Dateien liegen ab Spur 39 abwaerts,
dann ab 41 aufwaerts (kurze Wege zum Verzeichnis)."""
import sys, os

TRACKS, SPT = 80, 40
DIR_T = 40
DISK_ID = b'AB'


def offset(t, s):
    return ((t - 1) * SPT + s) * 256


def petscii(name):
    out = bytearray()
    for ch in name:
        c = ord(ch)
        if 0x61 <= c <= 0x7A: c -= 0x20          # klein -> PETSCII-Grossbuchstaben (Zeichensatz 2: klein)
        elif 0x41 <= c <= 0x5A: c += 0x80
        out.append(c)
    return bytes(out)


def pad16(b):
    return (b[:16] + b'\xA0' * 16)[:16]


def main():
    out, diskname = sys.argv[1], sys.argv[2]
    files = []
    for a in sys.argv[3:]:
        path, _, name = a.partition('=')
        files.append((name or os.path.splitext(os.path.basename(path))[0].lower(), open(path, 'rb').read()))
    img = bytearray(TRACKS * SPT * 256)
    free = {t: set(range(SPT)) for t in range(1, TRACKS + 1)}
    dir_secs = 1 + (len(files) - 1) // 8 if files else 1
    free[DIR_T] -= set(range(3 + dir_secs))
    order = list(range(DIR_T - 1, 0, -1)) + list(range(DIR_T + 1, TRACKS + 1))
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
    # Kopf 40/0
    h = offset(DIR_T, 0)
    img[h], img[h + 1], img[h + 2] = DIR_T, 3, 0x44
    img[h + 4:h + 20] = pad16(petscii(diskname))
    img[h + 20:h + 22] = b'\xA0\xA0'
    img[h + 22:h + 24] = DISK_ID
    img[h + 24] = 0xA0
    img[h + 25:h + 27] = b'3D'
    img[h + 27:h + 29] = b'\xA0\xA0'
    # Verzeichnis ab 40/3, 8 Eintraege je Sektor
    for k in range(dir_secs):
        d = offset(DIR_T, 3 + k)
        if k + 1 < dir_secs:
            img[d], img[d + 1] = DIR_T, 4 + k
        else:
            img[d], img[d + 1] = 0, 0xFF
    for i, (name, (t, s), n) in enumerate(dirents):
        e = offset(DIR_T, 3 + i // 8) + (i % 8) * 32
        img[e + 2] = 0x82                         # PRG, geschlossen
        img[e + 3], img[e + 4] = t, s
        img[e + 5:e + 21] = pad16(petscii(name))
        img[e + 30], img[e + 31] = n & 255, n >> 8
    # BAM 40/1 (Spuren 1-40), 40/2 (41-80): je Spur Anzahl frei + 5 Byte Bitmap (1 = frei)
    for k in range(2):
        b = offset(DIR_T, 1 + k)
        img[b], img[b + 1] = (DIR_T, 2) if k == 0 else (0, 0xFF)
        img[b + 2], img[b + 3] = 0x44, 0xBB
        img[b + 4:b + 6] = DISK_ID
        img[b + 6], img[b + 7] = 0xC0, 0
        for j in range(40):
            t = k * 40 + j + 1
            e = b + 16 + j * 6
            img[e] = len(free[t])
            bits = sum(1 << s for s in free[t])
            for q in range(5):
                img[e + 1 + q] = (bits >> (8 * q)) & 255
    open(out, 'wb').write(img)
    used = sum(n for _, _, n in dirents)
    print('%s: %s, %d Blocks frei' % (out, ', '.join('%s (%d Bl.)' % (nm, n) for nm, _, n in dirents),
                                       sum(len(free[t]) for t in free if t != DIR_T)))


if __name__ == '__main__':
    main()
