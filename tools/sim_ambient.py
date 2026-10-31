#!/usr/bin/env python3
"""sim_ambient.py - checks the world map ambience in tools/c64sim.py and renders a preview WAV.

  python -B tools/sim_ambient.py build/roboter.prg build/labels.txt [out.wav] [seconds]

(labels with: acme -l build/labels.txt ...). Start New Game -> world map: the
ambience must run (wind swells on voice 3, pulse on voice 2, sci-fi sounds on
voice 1), never write SID voice 1 while a sound effect owns it (robot walks on
the map), keep running in the statistics overlay, stop in plan mode (voices
2/3 off, filter off, volume register back to $0F) and start again on F7.
Then Winter (world 2) for the second parameter set via the test key F2.
The WAV (default 60 s Meadow + 30 s Winter) is a rough SID approximation with
a simple band-pass for the filtered wind and ring modulation - fine for
judging density, rhythm and mood, not exact timbre."""
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
SECS = int(sys.argv[4]) if len(sys.argv) > 4 else 60
AMB_LO, AMB_HI = L['ambient_start'], L['amb_sfx_lo']
K = dict(W=9, A=10, S=13, D=18, SPACE=60, RETURN=1, F1=4, F7=3, SHIFT=15)

m = C64(prg)
log = []                                    # (frame, reg, value, from_ambient, sfx_active)
orig = m.wr_io
def wr_io(addr, val):
    if 0xD400 <= addr <= 0xD418:
        sfx = m.ram[0xF8] | m.ram[0xFB]
        log.append((m.frames, addr - 0xD400, val, AMB_LO <= m.pc < AMB_HI, sfx))
    orig(addr, val)
m.wr_io = wr_io

def press(*ks, hold=3, after=8):
    for k in ks: m.keys.add(K[k])
    m.run_frames(hold)
    for k in ks: m.keys.discard(K[k])
    m.run_frames(after)

errors = []
def check(cond, ok, bad):
    if cond: print(ok + ': ok')
    else: errors.append(bad)

m.start_game()
m.run_frames(20)
check(m.ram[L['amb_on']] == 1, 'ambience runs on the world map', 'ambience not running on the map')
# plan mode for node 1 (as after a mouse click on it: wm_node = 0, then Space)
m.ram[0x79] = 0
press('SPACE'); m.run_frames(30)
io = m.io
quiet = (m.ram[L['amb_on']] == 0 and io[0x40B] & 1 == 0 and io[0x412] & 1 == 0
         and io[0x417] == 0 and io[0x418] == 0x0F)
check(quiet, 'plan mode: ambience off, filter off, volume $0F',
      'ambience not cleanly stopped in plan mode (on=%d v2=%02X v3=%02X filt=%02X vol=%02X)' % (
          m.ram[L['amb_on']], io[0x40B], io[0x412], io[0x417], io[0x418]))
press('F7'); m.run_frames(30)
check(m.ram[L['amb_on']] == 1, 'F7: ambience back on the map', 'ambience not restarted after F7')

m.run_frames(20)
t0 = m.frames
m.run_frames(SECS * 50)
seg1 = [e for e in log if e[0] >= t0]

def gate_ons(entries, reg, only_amb=True):
    st = 0; n = 0
    for f, r, v, a, s in entries:
        if r == reg and (a or not only_amb):
            if v & 1 and not st & 1: n += 1
            st = v
    return n
w3, p2, s1 = gate_ons(seg1, 18), gate_ons(seg1, 11), gate_ons(seg1, 4)
print('in %d s: %d wind swells, %d pulse hits, %d sci-fi notes' % (SECS, w3, p2, s1))
check(w3 >= SECS // 8, 'wind swells', 'too few wind swells (%d)' % w3)
check(p2 > 0, 'pulse plays', 'pulse silent')
check(s1 > 0, 'sci-fi sounds play', 'no sci-fi sounds')

# walk on the map (step sounds on voice 1) - ambience must keep off voice 1
n0 = len(log)
for k in 'DDAADDAA':
    press(k, hold=2, after=12)
m.run_frames(100)
bad = [e for e in log[n0:] if e[3] and e[1] <= 6 and e[4]]
check(not bad, 'step sounds keep voice 1', 'ambience wrote voice 1 during an effect (%d writes)' % len(bad))

press('F1'); m.run_frames(30)
check(m.ram[L['amb_on']] == 1, 'still running in the statistics', 'ambience stopped in the statistics')
press('SPACE'); m.run_frames(30)
check(m.ram[L['amb_on']] == 1, 'still running back on the map', 'ambience off after the statistics')

# Winter: F2 (Shift+F1) solves Meadow, walk through the gate is long - instead
# switch the parameter set directly by world number for the preview
m.ram[L['world_cur'] if 'world_cur' in L else 0x7A] = 1
t1 = m.frames
m.run_frames((SECS // 2) * 50)
seg2 = [e for e in log if e[0] >= t1]
print('winter set, %d s: %d swells, %d pulse hits, %d sci-fi notes' % (
    SECS // 2, gate_ons(seg2, 18), gate_ons(seg2, 11), gate_ons(seg2, 4)))

# ---- rough WAV preview -------------------------------------------------------
def render(entries, path):
    import numpy as np
    SR, CLK = 22050, 985248
    A_MS = [2, 8, 16, 24, 38, 56, 68, 80, 100, 250, 500, 800, 1000, 3000, 5000, 8000]
    D_MS = [x * 3 for x in A_MS]
    first = entries[0][0]; nfr = entries[-1][0] - first + 100
    by_frame = {}
    for e in entries: by_frame.setdefault(e[0] - first, []).append(e)
    regs = [0] * 25
    for f, r, v, a, s in log:               # register state before the segment
        if f >= first: break
        regs[r] = v
    spf = SR // 50
    dry = np.zeros(nfr * spf); wet = np.zeros(nfr * spf)
    cutoff = np.zeros(nfr * spf); res = np.zeros(nfr * spf)
    phase = [0.0] * 3; env = [0.0] * 3
    state = ['r'] * 3
    for vo in range(3):
        if regs[vo * 7 + 4] & 1: state[vo] = 'd'
    rnd = np.random.default_rng(1).uniform(-1, 1, 1 << 16)
    for fr in range(nfr):
        for f, r, v, a, s in by_frame.get(fr, []):
            if r in (4, 11, 18):
                vo = r // 7
                if v & 1 and not regs[r] & 1: state[vo] = 'a'
                if not v & 1: state[vo] = 'r'
            regs[r] = v
        sl = slice(fr * spf, (fr + 1) * spf)
        fc = (regs[0x16] << 3 | regs[0x15] & 7)
        cutoff[sl] = 30 + fc * 5.8
        res[sl] = regs[0x17] >> 4
        osc3 = None
        for vo in (2, 1, 0):
            b = vo * 7
            freq = (regs[b] | regs[b + 1] << 8) * CLK / 16777216
            ctrl = regs[b + 4]; pw = ((regs[b + 2] | regs[b + 3] << 8) & 0xFFF) / 4096
            ad, sr_ = regs[b + 5], regs[b + 6]
            sus = (sr_ >> 4) / 15
            ev_ = np.empty(spf); sub = spf // 21
            for k in range(21):
                if state[vo] == 'a':
                    env[vo] += 1 / max(1, A_MS[ad >> 4])
                    if env[vo] >= 1: env[vo] = 1; state[vo] = 'd'
                elif state[vo] == 'd':
                    env[vo] = max(sus, env[vo] - (1 - sus) / max(1, D_MS[ad & 15]) * 3 * env[vo])
                else:
                    env[vo] = max(0.0, env[vo] - 1 / max(1, D_MS[sr_ & 15]) * 3 * max(env[vo], 0.05))
                ev_[k * sub:(k + 1) * sub] = env[vo]
            ev_[21 * sub:] = env[vo]
            ph = phase[vo] + freq / SR * np.arange(1, spf + 1)
            phase[vo] = ph[-1] % 1.0
            fpart = ph % 1.0
            if vo == 2: osc3 = fpart
            w = np.zeros(spf)
            if ctrl & 0x80: w = rnd[(ph * 16).astype(np.int64) & 0xFFFF]
            elif ctrl & 0x40: w = np.where(fpart < pw, 1.0, -1.0)
            elif ctrl & 0x20: w = fpart * 2 - 1
            elif ctrl & 0x10:
                w = 1 - 4 * np.abs(fpart - 0.5)
                if ctrl & 0x04: w = w * np.where(osc3 < 0.5, 1.0, -1.0)
            if not ctrl & 0xF0: w = np.zeros(spf)
            sig = w * ev_ * 0.3
            if regs[0x17] & (1 << vo): wet[sl] += sig
            else: dry[sl] += sig
    # state-variable band-pass for the filtered voice
    import math
    bp = np.zeros_like(wet); low = band = 0.0
    mode = regs[0x18]
    f_arr = 2 * np.sin(np.pi * np.minimum(cutoff, SR / 6) / SR)
    q_arr = 1 / (0.707 + res / 15 * 1.8)
    for i in range(len(wet)):
        f = f_arr[i]; q = q_arr[i]
        high = wet[i] - low - q * band
        band += f * high
        low += f * band
        bp[i] = band
    out = dry + bp * 1.2
    k = 3; out = np.convolve(out, np.ones(k) / k, mode='same')
    pcm = (np.clip(out, -1, 1) * 30000).astype('<i2')
    with wave.open(path, 'wb') as wf:
        wf.setnchannels(1); wf.setsampwidth(2); wf.setframerate(SR); wf.writeframes(pcm.tobytes())
    print('preview written:', path, '%.1f s' % (len(pcm) / SR))

if wav_out:
    base, ext = os.path.splitext(wav_out)
    render(seg1[:], base + '_meadow' + ext)
    render(seg2[:], base + '_winter' + ext)

if errors:
    print('ERRORS:'); [print('  ' + e) for e in errors]; sys.exit(1)
print('all ambience checks passed')
