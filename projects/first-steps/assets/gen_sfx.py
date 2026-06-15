#!/usr/bin/env python3
"""Deterministic retro SFX generator for First Steps (top-down pixel action RPG).

Synthesizes the full SFX set with numpy + stdlib wave:
16-bit PCM mono 44100 Hz, loudness-matched (combat > UI >> ambience).
Loops (forest_ambience, campfire_crackle) are built with wrap-around
continuity: noise beds are shaped in the FFT domain (circular, so
sample N-1 -> sample 0 is a natural neighbor), amplitude undulation uses
whole-cycle LFOs, transients (chirps/pops) are kept away from the seam,
and the seam is then rotated onto the smallest circular sample step.

Run:  python3 gen_sfx.py
Writes WAVs to ./sounds/ and a waveform contour sheet to /tmp/sfx_waveforms.png
"""

import os
import wave

import numpy as np
from PIL import Image, ImageDraw

SR = 44100
OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sounds")
SHEET_PATH = "/tmp/sfx_waveforms.png"

np.random.seed(20260611)  # fixed: output is byte-deterministic


# ---------------------------------------------------------------- helpers

def t_axis(n):
    return np.arange(n) / SR


def sine(freq, n=None, phase0=0.0):
    """Sine from scalar or per-sample frequency array."""
    f = np.asarray(freq, dtype=np.float64)
    if f.ndim == 0:
        f = np.full(n, float(f))
    phase = phase0 + 2.0 * np.pi * np.cumsum(f) / SR
    return np.sin(phase)


def lowpass(x, cutoff):
    """One-pole lowpass; cutoff may be scalar or per-sample array (sweep)."""
    c = np.broadcast_to(np.asarray(cutoff, dtype=np.float64), x.shape)
    a = 1.0 - np.exp(-2.0 * np.pi * c / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += a[i] * (x[i] - acc)
        y[i] = acc
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def env_ad(n, attack_s, tau_s):
    """Linear attack then exponential decay."""
    t = t_axis(n)
    a = np.minimum(t / max(attack_s, 1e-6), 1.0)
    return a * np.exp(-t / tau_s)


def end_fade(x, fade_s=0.005):
    """Short fade to zero at the tail so one-shots never click."""
    m = min(int(fade_s * SR), len(x))
    x[-m:] *= np.linspace(1.0, 0.0, m)
    return x


def normalize(x, peak):
    return x * (peak / np.max(np.abs(x)))


def circular_noise(n, pink=1.0, lp_fc=600.0, lp_order=2, hp_fc=25.0):
    """Spectrally shaped noise built in the FFT domain.

    Because shaping is circular, x[n-1] -> x[0] is statistically just
    another adjacent sample pair: the bed loops seamlessly by construction.
    """
    white = np.random.standard_normal(n)
    X = np.fft.rfft(white)
    f = np.maximum(np.fft.rfftfreq(n, 1.0 / SR), 1.0)
    shape = f ** (-pink / 2.0)                                  # pink-ish tilt
    shape *= 1.0 / np.sqrt(1.0 + (f / lp_fc) ** (2 * lp_order))  # lowpass
    shape *= (f ** 2) / (f ** 2 + hp_fc ** 2)                    # kill DC/rumble
    shape[0] = 0.0
    y = np.fft.irfft(X * shape, n)
    return y / np.max(np.abs(y))


def seam_rotate(x, max_shift_s=0.15):
    """Rotate a circular loop so the file boundary lands on the smallest
    sample-to-sample step near the original seam. Transient placement
    windows account for this shift."""
    n = len(x)
    m = int(max_shift_s * SR)
    cand = np.concatenate([np.arange(0, m), np.arange(n - m, n)])
    j = cand[np.argmin(np.abs(x[cand] - x[(cand + 1) % n]))]
    return np.roll(x, -(int(j) + 1))


# ---------------------------------------------------------------- one-shots

def gen_swing_whoosh():
    """Sword cut: noise through a sweeping lowpass, sharp attack, fast decay."""
    n = int(0.22 * SR)
    t = t_axis(n)
    noise = np.random.standard_normal(n)
    sweep = 2500.0 * (600.0 / 2500.0) ** (t / t[-1])
    x = lowpass(lowpass(noise, sweep), sweep)   # 12 dB/oct: airy, not static-y
    x = highpass(x, 350.0)                       # no rumble under the cut
    env = (1.0 - np.exp(-t / 0.005)) * np.exp(-t / 0.06)
    return end_fade(normalize(x * env, 0.60))


def gen_swing_miss():
    """Softer, higher, breathier whoosh."""
    n = int(0.25 * SR)
    t = t_axis(n)
    noise = np.random.standard_normal(n)
    sweep = 3400.0 * (900.0 / 3400.0) ** (t / t[-1])
    x = lowpass(noise, sweep)                    # only 6 dB/oct: breathier
    x = highpass(x, 600.0)
    env = (1.0 - np.exp(-t / 0.014)) * np.exp(-t / 0.075)
    return end_fade(normalize(x * env, 0.46))


def gen_hit_flesh():
    """Impact: 85 Hz decaying sine thump + 25 ms noise transient, tight."""
    n = int(0.18 * SR)
    t = t_axis(n)
    thump = sine(85.0 + 70.0 * np.exp(-t / 0.012)) * np.exp(-t / 0.045)
    trans = lowpass(np.random.standard_normal(n), 4000.0)
    trans *= np.exp(-t / 0.008) * (t < 0.025)
    return end_fade(normalize(thump + 0.55 * trans, 0.68))


def gen_hit_crit():
    """Bigger impact: thump + 500->180 Hz drop + bright transient + tail."""
    n = int(0.32 * SR)
    t = t_axis(n)
    thump = sine(70.0 + 95.0 * np.exp(-t / 0.02)) * np.exp(-t / 0.07)
    drop_f = 500.0 * (180.0 / 500.0) ** np.minimum(t / 0.16, 1.0)
    drop = sine(drop_f) * env_ad(n, 0.003, 0.06)
    trans = lowpass(np.random.standard_normal(n), 7000.0)
    trans *= np.exp(-t / 0.010) * (t < 0.035)
    tail = lowpass(np.random.standard_normal(n), 1100.0)
    tail *= np.exp(-np.maximum(t - 0.03, 0.0) / 0.10) * (t > 0.03)
    x = thump + 0.50 * drop + 0.70 * trans + 0.14 * tail
    return end_fade(normalize(x, 0.70))


def gen_hurt_player():
    """Dull mid thud + short low square-ish grunt at 160 Hz."""
    n = int(0.20 * SR)
    t = t_axis(n)
    thud = sine(140.0 + 70.0 * np.exp(-t / 0.015)) * np.exp(-t / 0.05)
    smack = lowpass(np.random.standard_normal(n), 900.0) * np.exp(-t / 0.03)
    grunt = np.zeros(n)
    for k in (1, 3, 5, 7, 9):                    # band-limited square
        grunt += np.sin(2.0 * np.pi * 160.0 * k * t) / k
    g_env = env_ad(n, 0.012, 0.05) * (t < 0.16)
    grunt = lowpass(grunt, 1100.0) * np.roll(g_env, int(0.02 * SR))
    return end_fade(normalize(thud + 0.5 * smack + 0.55 * grunt, 0.64))


def gen_wolf_growl():
    """75-115 Hz sawtooth, 6 Hz pitch wobble, breath noise; in-out fade."""
    n = int(0.60 * SR)
    t = t_axis(n)
    f = 92.0 + 13.0 * np.sin(2.0 * np.pi * 1.1 * t + 1.0) \
        + 8.0 * np.sin(2.0 * np.pi * 6.0 * t)
    phase = 2.0 * np.pi * np.cumsum(f) / SR
    saw = np.zeros(n)
    for k in range(1, 29):                       # band-limited sawtooth
        saw += np.sin(k * phase) / k
    saw = lowpass(saw, 1700.0)
    breath = highpass(lowpass(np.random.standard_normal(n), 1500.0), 300.0)
    env_in = np.minimum(t / 0.18, 1.0) ** 2
    env_out = np.minimum((t[-1] - t) / 0.22, 1.0) ** 2
    trem = 1.0 + 0.15 * np.sin(2.0 * np.pi * 6.0 * t + 0.7)
    env = env_in * env_out * trem
    return end_fade(normalize((saw + 0.30 * breath) * env, 0.55))


def gen_wolf_bite():
    """Snappy noise click + 220 Hz thump."""
    n = int(0.15 * SR)
    t = t_axis(n)
    click = highpass(np.random.standard_normal(n), 1500.0) * np.exp(-t / 0.0015)
    snap = lowpass(np.random.standard_normal(n), 3000.0) * np.exp(-t / 0.012)
    thump = sine(220.0 + 80.0 * np.exp(-t / 0.008)) * np.exp(-t / 0.035)
    return end_fade(normalize(0.9 * click + 0.6 * snap + 1.0 * thump, 0.66))


def gen_wolf_yelp():
    """Sine pitch arc 500->1100->350 Hz, light vibrato; cartoonish-sad."""
    n = int(0.28 * SR)
    t = t_axis(n)
    u = t / t[-1]
    p = 0.32                                      # peak of the arc
    f = np.where(u < p,
                 500.0 * (1100.0 / 500.0) ** (u / p),
                 1100.0 * (350.0 / 1100.0) ** ((u - p) / (1.0 - p)))
    f = f * (1.0 + 0.022 * np.sin(2.0 * np.pi * 9.0 * t))
    phase = 2.0 * np.pi * np.cumsum(f) / SR
    x = np.sin(phase) + 0.22 * np.sin(2.0 * phase)
    env = np.minimum(t / 0.010, 1.0) * np.exp(-t / 0.13)   # rise-fall arc
    env *= np.minimum((t[-1] - t) / 0.06, 1.0)
    return end_fade(normalize(x * env, 0.58))


def gen_pickup_chime():
    """The sword moment: E5 G5 B5 detuned-sine arpeggio with sparkle."""
    n = int(0.90 * SR)
    t = t_axis(n)
    x = np.zeros(n)
    notes = [(659.2551, 0.00, 0.30, 0.90),
             (783.9909, 0.12, 0.30, 0.95),
             (987.7666, 0.24, 0.40, 1.05)]       # arrival note rings longest
    for f0, t0, tau, amp in notes:
        i0 = int(t0 * SR)
        m = n - i0
        tn = t_axis(m)
        env = np.minimum(tn / 0.004, 1.0) * np.exp(-tn / tau)
        sparkle = 1.0 + 0.5 * np.sin(2.0 * np.pi * 6.0 * tn)
        tone = np.zeros(m)
        # Detuned pair: phase-staggered onset, unequal amps so the ~2 Hz
        # beat shimmers instead of nulling to silence.
        for det, ph, pa in ((0.9985, 0.0, 1.0), (1.0015, 1.1, 0.72)):
            tone += pa * np.sin(2.0 * np.pi * f0 * det * tn + ph)
            tone += pa * 0.16 * np.sin(2.0 * np.pi * 2.0 * f0 * det * tn + ph)
        tone += 0.06 * np.sin(2.0 * np.pi * 3.0 * f0 * tn)
        tone += 0.045 * np.sin(2.0 * np.pi * 4.0 * f0 * tn) * sparkle
        x[i0:] += amp * tone * env
    x *= np.minimum((t[-1] - t) / 0.08, 1.0)     # soft landing, no cliff
    return end_fade(normalize(x, 0.62))


def gen_target_ping():
    """1150 Hz sine blip + faint octave-up; subtle UI tick."""
    n = int(0.12 * SR)
    t = t_axis(n)
    x = sine(1150.0, n) * env_ad(n, 0.0015, 0.022)
    x += 0.28 * sine(2300.0, n) * env_ad(n, 0.0015, 0.014)
    return end_fade(normalize(x, 0.45))


def gen_death_sting():
    """Solemn descending A3 F3 D3, soft sine, slow vibrato, long release."""
    n = int(1.60 * SR)
    t = t_axis(n)
    x = np.zeros(n)
    notes = [(220.0000, 0.00, 0.32, 0.85),
             (174.6141, 0.50, 0.32, 0.90),
             (146.8324, 1.00, 0.60, 1.00)]       # final note rings out
    for f0, t0, tau, amp in notes:
        i0 = int(t0 * SR)
        m = n - i0
        tn = t_axis(m)
        vib_in = np.minimum(np.maximum(tn - 0.12, 0.0) / 0.25, 1.0)
        f = f0 * (1.0 + 0.008 * vib_in * np.sin(2.0 * np.pi * 4.5 * tn))
        phase = 2.0 * np.pi * np.cumsum(f) / SR
        tone = np.sin(phase) + 0.20 * np.sin(2.0 * phase) \
            + 0.07 * np.sin(3.0 * phase)
        env = np.minimum(tn / 0.045, 1.0) * np.exp(-tn / tau)
        x[i0:] += amp * tone * env
    x *= np.minimum((t[-1] - t) / 0.20, 1.0) ** 2  # gentle final release
    return end_fade(normalize(x, 0.55), 0.01)


# ------------------------------------------------------------------- loops

def gen_forest_ambience():
    """8 s seamless bed: lowpassed pink wind, slow undulation, sparse birds."""
    n = 8 * SR
    t = t_axis(n)
    wind = circular_noise(n, pink=1.0, lp_fc=550.0, lp_order=2, hp_fc=40.0)
    undulate = 1.0 + 0.30 * np.sin(2.0 * np.pi * 3.0 * t / 8.0 + 0.8) \
        + 0.16 * np.sin(2.0 * np.pi * 5.0 * t / 8.0 + 2.1)  # whole cycles
    wind = normalize(wind * undulate, 0.155)

    birds = np.zeros(n)
    starts, last = [], -10.0
    while len(starts) < 7:                        # sparse, varied intervals
        s = np.random.uniform(0.55, 7.15)
        if all(abs(s - p) > 0.55 for p in starts):
            starts.append(s)
    for idx, s in enumerate(sorted(starts)):
        reps = 2 if idx in (1, 4) else 1          # two doublet chirps -> 9 total
        for r in range(reps):
            dur = np.random.uniform(0.045, 0.085)
            m = int(dur * SR)
            tn = t_axis(m)
            f0 = np.random.uniform(2000.0, 2900.0)
            f1 = f0 * np.random.uniform(1.25, 1.55)  # rising sweep, 2-4 kHz
            f = f0 * (f1 / f0) ** (tn / tn[-1])
            chirp = sine(f) * np.sin(np.pi * tn / tn[-1]) ** 2
            i0 = int((s + r * 0.085) * SR)
            birds[i0:i0 + m] += np.random.uniform(0.06, 0.095) * chirp
    x = wind + birds                              # chirps live in [0.55, 7.25] s
    x = seam_rotate(x, max_shift_s=0.15)          # seam stays >0.4 s from birds
    if np.max(np.abs(x)) > 0.18:
        x = normalize(x, 0.18)
    return x


def gen_campfire_crackle():
    """4 s seamless: sparse lowpassed pops over a faint low rumble."""
    n = 4 * SR
    t = t_axis(n)
    rumble = circular_noise(n, pink=1.5, lp_fc=130.0, lp_order=2, hp_fc=30.0)
    undulate = 1.0 + 0.25 * np.sin(2.0 * np.pi * 2.0 * t / 4.0 + 1.3) \
        + 0.15 * np.sin(2.0 * np.pi * 5.0 * t / 4.0 + 0.4)
    rumble = normalize(rumble * undulate, 0.085)

    pops = np.zeros(n)
    for _ in range(30):                           # crackles, away from seam
        s = np.random.uniform(0.30, 3.66)
        dur = np.random.uniform(0.008, 0.030)
        m = int(dur * SR)
        tn = t_axis(m)
        fc = np.random.uniform(1500.0, 4200.0)
        burst = lowpass(np.random.standard_normal(m), fc)
        burst *= np.exp(-tn / np.random.uniform(0.002, 0.007))
        burst[-max(int(0.001 * SR), 2):] *= 0.0   # hard-zero pop tail
        pops[int(s * SR):int(s * SR) + m] += np.random.uniform(0.3, 1.0) * burst
    pops = normalize(pops, 0.22)
    x = rumble + pops
    x = seam_rotate(x, max_shift_s=0.12)          # pops stay >0.18 s from seam
    if np.max(np.abs(x)) > 0.25:
        x = normalize(x, 0.25)
    return x


# ---------------------------------------------------------- write/validate

SOUNDS = [
    ("swing_whoosh.wav", gen_swing_whoosh, False),
    ("swing_miss.wav", gen_swing_miss, False),
    ("hit_flesh.wav", gen_hit_flesh, False),
    ("hit_crit.wav", gen_hit_crit, False),
    ("hurt_player.wav", gen_hurt_player, False),
    ("wolf_growl.wav", gen_wolf_growl, False),
    ("wolf_bite.wav", gen_wolf_bite, False),
    ("wolf_yelp.wav", gen_wolf_yelp, False),
    ("pickup_chime.wav", gen_pickup_chime, False),
    ("target_ping.wav", gen_target_ping, False),
    ("death_sting.wav", gen_death_sting, False),
    ("forest_ambience.wav", gen_forest_ambience, True),
    ("campfire_crackle.wav", gen_campfire_crackle, True),
]


def write_wav(path, x):
    q = np.clip(np.round(x * 32767.0), -32767, 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(q.tobytes())
    return q.astype(np.float64) / 32767.0         # validate what's on disk


def validate(name, x, is_loop):
    dur = len(x) / SR
    peak = float(np.max(np.abs(x)))
    rms = float(np.sqrt(np.mean(x ** 2)))
    assert peak < 0.95, f"{name}: peak {peak:.3f} exceeds 0.95"
    seam = ""
    if is_loop:
        wrap = abs(float(x[-1] - x[0]))
        assert wrap < 0.01, f"{name}: loop wrap step {wrap:.4f} >= 0.01"
        w = int(0.010 * SR)
        splice = np.concatenate([x[-w:], x[:w]])
        step = float(np.max(np.abs(np.diff(splice))))
        assert step < 0.05, f"{name}: splice step {step:.4f} >= 0.05"
        seam = f"  wrap={wrap:.5f} splice_max_step={step:.4f}"
    print(f"{name:24s} dur={dur:6.3f}s  peak={peak:.3f}  rms={rms:.4f}{seam}")


def waveform_sheet(rendered, path):
    strip_h, gap, width = 92, 8, 1100
    img = Image.new("RGB", (width, gap + len(rendered) * (strip_h + gap)),
                    (16, 18, 24))
    d = ImageDraw.Draw(img)
    full_scale = 0.75                              # shared scale: shows loudness
    for r, (name, x) in enumerate(rendered):
        y0 = gap + r * (strip_h + gap)
        d.rectangle([0, y0, width - 1, y0 + strip_h - 1], fill=(26, 29, 38))
        mid = y0 + strip_h // 2
        d.line([(0, mid), (width - 1, mid)], fill=(50, 54, 66))
        cols = width
        idx = np.linspace(0, len(x), cols + 1).astype(int)
        sc = (strip_h / 2 - 3) / full_scale
        for c in range(cols):
            seg = x[idx[c]:max(idx[c + 1], idx[c] + 1)]
            d.line([(c, mid - seg.max() * sc), (c, mid - seg.min() * sc)],
                   fill=(232, 178, 90))
        peak = np.max(np.abs(x))
        d.text((6, y0 + 3), f"{name}  ({len(x)/SR:.2f}s, peak {peak:.2f})",
               fill=(225, 228, 235))
    img.save(path)
    print(f"waveform sheet -> {path}")


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    rendered = []
    for name, gen, is_loop in SOUNDS:
        x = gen()
        on_disk = write_wav(os.path.join(OUT_DIR, name), x)
        validate(name, on_disk, is_loop)
        rendered.append((name, on_disk))
    waveform_sheet(rendered, SHEET_PATH)
    print("OK: all files written and validated.")


if __name__ == "__main__":
    main()
