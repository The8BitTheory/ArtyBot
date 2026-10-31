#!/usr/bin/env python3
"""sim_music.py - checks the title music in tools/c64sim.py and renders a preview WAV.

  python -B tools/sim_music.py build/roboter.prg build/labels.txt [out.wav]

(labels with: acme -l build/labels.txt ...). Logs every SID write on the title
screen for two loops of the song, checks that the loop repeats exactly, that
the music never touches SID voice 1 while a sound effect owns it (menu key S),
and that "Start New Game" silences it. The WAV is a rough SID approximation
(no filter, simple envelopes) - good for judging melody and rhythm, not timbre."""
import sys, os, wave
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from c64sim import C64

prg = open(sys.argv[1], 'rb').read()
L = {}
for line in open(sys.argv[2]):
    p = line.split('=')
    if len(p) == 2 and '$' in p[1]:
        L[p[0].strip()] = int(p[1].split('$')[1].split()[0].rstrip(';?'), 16)
wav_out = sys.argv[3] if len(sys.argv) > 3 else None
MUS_LO, MUS_HI = L['music_start'], L['mus_sid']
LOOP = 256 * 6                                   # loop length in frames
INTRO = 32 * 6

m = C64(prg)
log = []                                         # (frame, reg, value, from_music, sfx_active)
orig = m.wr_io
def wr_io(addr, val):
    if 0xD400 <= addr <= 0xD418:
        sfx = m.ram[0xF8] | m.ram[0xFB]
        log.append((m.frames, addr - 0xD400, val, MUS_LO <= m.pc < MUS_HI, sfx))
    orig(addr, val)
m.wr_io = wr_io

errors = []
m.run_frames(30)
if not m.ram[L['mus_on']]:
    errors.append('music not running on the title screen')
start = log[0][0] if log else 0
m.run_frames(INTRO + 2 * LOOP + 20)

# gate-on events per voice: (frame, voice, freq)
def gates(entries):
    """gate-on events, frequency as it stands at the end of that frame"""
    st = [0] * 25; ev = []; end = {}
    for f, r, v, mu, sfx in entries:
        if r in (4, 11, 18) and v & 1 and not st[r] & 1:
            ev.append((f, r // 7))
        st[r] = v
        end[f] = list(st)
    return [(f, vo, end[f][vo * 7] | end[f][vo * 7 + 1] << 8) for f, vo in ev]
ev = gates(log)
t0 = min(f for f, _, _ in ev)
l1 = [(f - t0 - INTRO, v, fr) for f, v, fr in ev if INTRO <= f - t0 < INTRO + LOOP]
l2 = [(f - t0 - INTRO - LOOP, v, fr) for f, v, fr in ev if INTRO + LOOP <= f - t0 < INTRO + 2 * LOOP]
for v in range(3):
    n = sum(1 for e in l1 if e[1] == v)
    print('voice %d: %3d notes per loop' % (v + 1, n))
    if n == 0: errors.append('voice %d silent' % (v + 1))
if l1 != l2:
    errors.append('second loop differs from the first (%d vs %d notes)' % (len(l1), len(l2)))
else:
    print('loop of %d frames (%.1f s) repeats exactly' % (LOOP, LOOP / 50))

# sound effect on voice 1: menu cursor down (S) a few times
n0 = len(log)
for _ in range(4):
    m.keys.add(13); m.run_frames(3); m.keys.discard(13); m.run_frames(9)
m.run_frames(40)
bad = [e for e in log[n0:] if e[3] and e[1] <= 6 and e[4]]
if bad:
    errors.append('music wrote voice 1 while an effect played (%d writes)' % len(bad))
else:
    print('sound effects keep voice 1: ok')
music_log = log[:n0]

# start new game -> music off
m.keys.add(56); m.run_frames(3); m.keys.discard(56); m.run_frames(30)  # key 1 = Start New Game
if m.ram[L['mus_on']] or m.io[0x400 + 11] & 0xF1 or m.io[0x400 + 18] & 0xF1:
    errors.append('music still on after Start New Game')
else:
    print('Start New Game stops the music: ok')

# ---- rough WAV preview -------------------------------------------------------
if wav_out:
    import numpy as np
    SR, CLK = 44100, 985248
    A_MS = [2, 8, 16, 24, 38, 56, 68, 80, 100, 250, 500, 800, 1000, 3000, 5000, 8000]
    D_MS = [x * 3 for x in A_MS]
    first = music_log[0][0]; last = music_log[-1][0]
    nfr = last - first + 50
    by_frame = {}
    for e in music_log: by_frame.setdefault(e[0] - first, []).append(e)
    regs = [0] * 25
    spf = SR // 50
    out = np.zeros(nfr * spf)
    phase = [0.0] * 3; env = [0.0] * 3; state = ['r'] * 3
    rnd = np.random.default_rng(1).uniform(-1, 1, 65536)
    for fr in range(nfr):
        for f, r, v, mu, sfx in by_frame.get(fr, []):
            if r in (4, 11, 18):
                vo = r // 7
                if v & 1 and not regs[r] & 1: state[vo] = 'a'
                if not v & 1: state[vo] = 'r'
            regs[r] = v
        for vo in range(3):
            b = vo * 7
            freq = (regs[b] | regs[b + 1] << 8) * CLK / 16777216
            ctrl = regs[b + 4]; pw = ((regs[b + 2] | regs[b + 3] << 8) & 0xFFF) / 4096
            ad, sr_ = regs[b + 5], regs[b + 6]
            sus = (sr_ >> 4) / 15
            # envelope in 20 sub-steps per frame
            ev_ = np.empty(spf)
            sub = spf // 20
            for k in range(20):
                if state[vo] == 'a':
                    env[vo] += 1 / max(1, A_MS[ad >> 4]); 
                    if env[vo] >= 1: env[vo] = 1; state[vo] = 'd'
                elif state[vo] == 'd':
                    env[vo] = max(sus, env[vo] - (1 - sus) / max(1, D_MS[ad & 15]) * 3 * env[vo])
                else:
                    env[vo] = max(0.0, env[vo] - 1 / max(1, D_MS[sr_ & 15]) * 3 * max(env[vo], 0.05))
                ev_[k * sub:(k + 1) * sub] = env[vo]
            ev_[20 * sub:] = env[vo]
            ph = phase[vo] + freq / SR * np.arange(1, spf + 1)
            phase[vo] = ph[-1] % 1.0
            fpart = ph % 1.0
            w = np.zeros(spf)
            if ctrl & 0x80: w = rnd[(ph * 16).astype(np.int64) & 65535]
            elif ctrl & 0x40: w = np.where(fpart < pw, 1.0, -1.0)
            elif ctrl & 0x20: w = fpart * 2 - 1
            elif ctrl & 0x10: w = 1 - 4 * np.abs(fpart - 0.5)
            if not ctrl & 0xF0: w = np.zeros(spf)
            out[fr * spf:(fr + 1) * spf] += w * ev_ * 0.3
    # gentle low pass (SID output is not that harsh)
    k = 6; out = np.convolve(out, np.ones(k) / k, mode='same')
    pcm = (np.clip(out, -1, 1) * 30000).astype('<i2')
    with wave.open(wav_out, 'wb') as wf:
        wf.setnchannels(1); wf.setsampwidth(2); wf.setframerate(SR); wf.writeframes(pcm.tobytes())
    print('preview written:', wav_out, '%.1f s' % (len(pcm) / SR))

if errors:
    print('ERRORS:'); [print('  ' + e) for e in errors]; sys.exit(1)
print('all music checks passed')
