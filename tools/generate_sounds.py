#!/usr/bin/env python3
"""يولّد أصوات التطبيق (نغمات لطيفة قصيرة) داخل assets/audio.

الأصوات أصلية ومولَّدة برمجيًا (لا حقوق نشر). للتعديل: غيّر النغمات ثم شغّل
    python3 tools/generate_sounds.py
"""
import math
import struct
import wave
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parent.parent / "assets" / "audio"

NOTE = {
    "G4": 392.00, "C5": 523.25, "D5": 587.33, "E5": 659.25,
    "G5": 783.99, "A5": 880.00, "C6": 1046.50, "E6": 1318.51,
}


def tone(freq, dur, volume=0.45):
    """نغمة ناعمة: جيب + توافق ثانٍ خفيف + بداية ونهاية هادئتان."""
    n = int(RATE * dur)
    out = []
    for i in range(n):
        t = i / RATE
        attack = min(1.0, t / 0.008)
        release = math.exp(-5.0 * t / dur)
        s = math.sin(2 * math.pi * freq * t) + 0.25 * math.sin(4 * math.pi * freq * t)
        out.append(volume * attack * release * s / 1.25)
    return out


def sequence(notes, step, note_dur):
    total = int(RATE * (step * (len(notes) - 1) + note_dur)) + 1
    mix = [0.0] * total
    for idx, name in enumerate(notes):
        start = int(RATE * step * idx)
        for j, v in enumerate(tone(NOTE[name], note_dur)):
            if start + j < total:
                mix[start + j] += v
    return mix


def claps(count, start, gap, volume=0.12):
    """تصفيق خفيف جدًا: دفعات ضوضاء قصيرة متتالية."""
    import random

    rnd = random.Random(7)
    total = int(RATE * (start + gap * count + 0.1))
    out = [0.0] * total
    for k in range(count):
        s0 = int(RATE * (start + gap * k))
        for i in range(int(RATE * 0.05)):
            env = math.exp(-i / (RATE * 0.012))
            if s0 + i < total:
                out[s0 + i] += volume * env * (rnd.random() * 2 - 1)
    return out


def mix_into(a, b):
    n = max(len(a), len(b))
    return [(a[i] if i < len(a) else 0.0) + (b[i] if i < len(b) else 0.0) for i in range(n)]


def write(name, samples):
    OUT.mkdir(parents=True, exist_ok=True)
    peak = max(1e-9, max(abs(x) for x in samples))
    scale = min(1.0, 0.8 / peak)
    with wave.open(str(OUT / name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, x * scale)) * 32767))
            for x in samples
        ))


if __name__ == "__main__":
    write("tap.wav", tone(880.0, 0.06, 0.35))
    write("correct.wav", sequence(["C5", "E5"], 0.10, 0.28))
    write("success.wav", sequence(["C5", "E5", "G5", "C6"], 0.11, 0.40))
    write("levelup.wav", sequence(["G4", "C5", "E5", "G5", "C6"], 0.12, 0.45))
    write("joy.wav", mix_into(sequence(["C5", "E5", "G5", "C6", "E6"], 0.09, 0.5), claps(7, 0.25, 0.07)))
    print("done:", sorted(p.name for p in OUT.glob("*.wav")))
