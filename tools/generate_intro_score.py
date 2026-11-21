#!/usr/bin/env python3
"""يولّد موسيقى المقدمة السينمائية (45 ثانية) بالكود: بساط أوتار هادئ + أجراس صغيرة
على لحظات المقدمة (kCinemaCues). أصلية بالكامل (لا مقطوعات منسوخة)، هادئة ومناسبة للصغار.
الناتج: assets/audio/intro_score.wav  —  تشغيل: python3 tools/generate_intro_score.py
"""
import math
import wave
import numpy as np

SR = 22050
T = 45.0
N = int(SR * T)
t = np.arange(N) / SR
rng = np.random.default_rng(3)


def env(x, a, d, r_start, r):
    """ظرف: صعود a ثانية، ثم ثبات، ثم هبوط من r_start لمدة r."""
    e = np.clip(x / a, 0, 1)
    e = e * np.clip((r_start + r - x) / r, 0, 1)
    return e


def pad_note(freq, start, dur, amp):
    x = t - start
    m = (x >= 0) & (x <= dur)
    out = np.zeros(N)
    xs = x[m]
    e = env(xs, 1.6, 0, dur - 2.2, 2.2)
    wave_ = np.sin(2 * np.pi * freq * xs) + 0.35 * np.sin(2 * np.pi * freq * 2 * xs + 0.5) + 0.12 * np.sin(2 * np.pi * freq * 3 * xs)
    wave_ += 0.25 * np.sin(2 * np.pi * (freq * 1.003) * xs)  # تفتّح خفيف (كورَس)
    out[m] = amp * e * wave_
    return out


def bell(freq, start, amp=0.25, decay=1.6):
    x = t - start
    m = x >= 0
    out = np.zeros(N)
    xs = x[m]
    tone = (np.sin(2 * np.pi * freq * xs) + 0.4 * np.sin(2 * np.pi * freq * 2.76 * xs) + 0.18 * np.sin(2 * np.pi * freq * 5.4 * xs))
    out[m] = amp * np.exp(-xs / decay) * np.minimum(xs / 0.005, 1) * tone
    return out


# مقام هادئ (ري الكبير الخماسي): D E F# A B
D3, A3, D4, E4, Fs4, A4, B4 = 146.83, 220.0, 293.66, 329.63, 369.99, 440.0, 493.88
D5, E5, Fs5, A5, B5, D6 = 587.33, 659.25, 739.99, 880.0, 987.77, 1174.66
G3, B3, G4 = 196.0, 246.94, 392.0

# بساط الأوتار: كل وتر ~5.6 ث وتتداخل الأوتار بنعومة.
chords = [
    [D3, A3, D4, E4],
    [G3, D4, B4 / 2 * 2, G4],
    [D3, A3, Fs4, B4],
    [G3, B3, D4, A4],
    [D3, A3, D4, Fs4],
    [G3, D4, G4, B4],
    [D3, A3, E4, A4],
    [D3, A3, D4, Fs4, A4],
]
pad = np.zeros(N)
for i, ch in enumerate(chords):
    start = i * 5.4
    for f in ch:
        pad += pad_note(f, start, 7.2, 0.07)

# شدّة عامة: هادئ جدًا في البداية، ينتفخ مع ظهور العالم، يرتفع برفق عند الخريطة.
level = np.interp(t, [0, 3, 5, 11, 22, 31, 37, 42, 45], [0.25, 0.35, 0.45, 0.8, 0.85, 0.85, 0.95, 1.0, 0.9])
pad *= level

# أجراس لحظات المقدمة.
mel = np.zeros(N)
def arp(notes, start, gap, amp=0.22):
    global mel
    for k, f in enumerate(notes):
        mel += bell(f, start + k * gap, amp)

arp([D5, Fs5, A5, D6], 0.9, 0.55, 0.12)                 # ضوء أول + نجوم
arp([A5, B5, D6, B5, A5], 10.0, 0.22, 0.2)               # لمعة: تلألؤ سريع لطيف
arp([D5, Fs5, A5, B5, A5, Fs5, D5], 15.6, 0.5, 0.2)      # فداء ونور: لحن دافئ
arp([Fs5, A5, D6], 23.0, 0.35, 0.2)                      # ظهور الخريطة
arp([D5, A5, D6], 31.0, 0.3, 0.24)                       # نجمة فداء إلى نور
arp([A5, D6, Fs5 * 2], 35.0, 0.26, 0.18)                 # نجمة نور إلى فداء (أخف وأعلى)
arp([D5, Fs5, A5, D6, Fs5 * 2], 39.0, 0.4, 0.2)         # البوابات والنهاية المتفائلة
mel += bell(D6, 42.0, 0.2, 2.5) + bell(A5, 42.0, 0.14, 2.5)

mix = pad + mel
# صدى ناعم (بلا مكتبات خارجية).
wet = np.zeros(N)
for delay, g in [(0.23, 0.32), (0.41, 0.22), (0.67, 0.14)]:
    d = int(delay * SR)
    wet[d:] += mix[:-d] * g
mix = mix + wet

# بداية من الصمت ونهاية هادئة.
mix *= np.clip(t / 0.8, 0, 1) * np.clip((T - t) / 1.6, 0, 1)
mix = mix / np.max(np.abs(mix)) * 0.7
pcm = (mix * 32767).astype('<i2')

with wave.open('assets/audio/intro_score.wav', 'wb') as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(pcm.tobytes())
print('ok', len(pcm) / SR, 'seconds')
