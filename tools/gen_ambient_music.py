#!/usr/bin/env python3
"""Generate assets/music/komorebi_ambient.ogg — a seamless, calm pentatonic loop.

Pure numpy synthesis (no samples, no licensing questions): a slow pad that moves
through four chords at roughly breath tempo, soft bell plucks on a pentatonic
scale, and a little filtered noise "wind". Re-run to regenerate:

    python3 tools/gen_ambient_music.py && ffmpeg -y -i /tmp/komorebi_ambient.wav \
        -c:a libvorbis -q:a 3 assets/music/komorebi_ambient.ogg
"""
import wave
import numpy as np

SR = 32000
BAR = 9.5            # seconds per chord — half a 19 s 4-7-8 breath
CHORDS = [           # D major pentatonic-ish colours (Hz roots of stacked notes)
    [146.83, 220.00, 293.66, 369.99],   # D  A  D  F#
    [123.47, 185.00, 246.94, 329.63],   # B  F# B  E
    [110.00, 164.81, 220.00, 277.18],   # A  E  A  C#
    [130.81, 196.00, 261.63, 329.63],   # C  G  C  E  (borrowed, wistful)
]
LENGTH = BAR * len(CHORDS)
N = int(SR * LENGTH)
t = np.arange(N) / SR
rng = np.random.default_rng(413)

out = np.zeros((N, 2))

# --- pad: detuned sines with slow swell, crossfaded so the loop is seamless
for i, chord in enumerate(CHORDS):
    centre = (i + 0.5) * BAR
    # raised-cosine window 2 bars wide, wrapping around the loop end
    d = (t - centre + LENGTH / 2) % LENGTH - LENGTH / 2
    win = np.where(np.abs(d) < BAR, 0.5 * (1 + np.cos(np.pi * d / BAR)), 0.0)
    for j, f in enumerate(chord):
        for det, pan in ((-0.6, 0.25), (0.6, 0.75)):
            ph = rng.uniform(0, 2 * np.pi)
            # integer cycles per loop keeps it click-free at the seam
            ff = round((f + det) * LENGTH) / LENGTH
            s = np.sin(2 * np.pi * ff * t + ph) * win * (0.05 / (1 + j * 0.35))
            out[:, 0] += s * (1 - pan)
            out[:, 1] += s * pan

# --- bell plucks on a pentatonic scale
scale = [293.66, 329.63, 369.99, 440.00, 493.88, 587.33, 659.25, 739.99]
step = BAR / 6
for k in range(int(LENGTH / step)):
    if rng.random() < 0.35:
        continue
    start = k * step + rng.uniform(0, 0.25)
    f = scale[rng.integers(len(scale))]
    dur = 3.5
    n0 = int(start * SR); n = int(dur * SR)
    tt = np.arange(n) / SR
    env = np.exp(-tt * 1.6) * np.minimum(1, tt * 200)
    tone = (np.sin(2 * np.pi * f * tt) + 0.3 * np.sin(2 * np.pi * f * 2.01 * tt) * np.exp(-tt * 3)) * env * 0.06
    pan = rng.uniform(0.2, 0.8)
    idx = (n0 + np.arange(n)) % N          # wrap into the loop start
    out[idx, 0] += tone * (1 - pan)
    out[idx, 1] += tone * pan

# --- soft wind: low-passed noise with a slow breathing swell
noise = rng.standard_normal(N)
k = int(SR * 0.004)
noise = np.convolve(noise, np.ones(k) / k, mode="same")
swell = 0.5 + 0.5 * np.sin(2 * np.pi * t / (LENGTH / 4))
out[:, 0] += noise * swell * 0.02
out[:, 1] += np.roll(noise, 1500) * swell * 0.02

# --- simple feedback delay "space"
for delay, gain in ((0.31, 0.35), (0.47, 0.25)):
    dn = int(delay * SR)
    out[:, 0] += np.roll(out[:, 1], dn) * gain
    out[:, 1] += np.roll(out[:, 0], dn) * gain

out /= np.max(np.abs(out)) * 1.15
pcm = (out * 32767).astype(np.int16)
with wave.open("/tmp/komorebi_ambient.wav", "wb") as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes(pcm.tobytes())
print(f"wrote /tmp/komorebi_ambient.wav ({LENGTH:.1f}s)")
