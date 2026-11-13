#!/usr/bin/env python3
"""ASMR ses seti (yerel sentez, API yok): yumuşak, kısa, tok sesler.

    python3 tools/make_asmr_sfx.py

Üretir: assets/audio/sfx/{pin_click,cloth,fold_puff,note,wring,unlock,wind,win}.wav ve
data/sounds.json kayıtları. Gürültü tabanlı sesler FFT ile bant sınırlanır (tiz cızırtı yok).
"""
import json
import os
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SFX_DIR = os.path.join(ROOT, "assets", "audio", "sfx")
SOUNDS_PATH = os.path.join(ROOT, "data", "sounds.json")
RATE = 44100
PEAK = 0.8
rng = np.random.default_rng(7)


def t(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def band(noise, low, high):
    spectrum = np.fft.rfft(noise)
    freqs = np.fft.rfftfreq(noise.size, 1.0 / RATE)
    # Yumuşak kenarlı bant: keskin kesim "çınlama" yapar.
    gain = 1.0 / (1.0 + (low / np.maximum(freqs, 1.0)) ** 4) / (1.0 + (freqs / high) ** 4)
    return np.fft.irfft(spectrum * gain, noise.size)


def noise(seconds, low, high):
    return band(rng.standard_normal(int(RATE * seconds)), low, high)


def env(seconds, attack, decay_rate):
    x = t(seconds)
    return np.minimum(x / max(attack, 1e-4), 1.0) * np.exp(-decay_rate * x)


def marimba(freq, seconds, decay=9.0):
    x = t(seconds)
    tone = np.sin(2 * np.pi * freq * x) + 0.28 * np.sin(2 * np.pi * freq * 4.0 * x) * np.exp(-18 * x)
    return tone * env(seconds, 0.004, decay)


def pad(signal, seconds):
    out = np.zeros(int(RATE * seconds))
    out[:min(signal.size, out.size)] = signal[:out.size]
    return out


def mix_at(base, signal, start):
    index = int(RATE * start)
    end = min(base.size, index + signal.size)
    base[index:end] += signal[:end - index]
    return base


SOUNDS = {}
# Mandal "tık": tahta rezonansı + çok kısa gürültü.
click = noise(0.09, 900, 5000) * env(0.09, 0.0008, 90)
click += 0.6 * np.sin(2 * np.pi * 1450 * t(0.09)) * env(0.09, 0.0008, 70)
SOUNDS["pin_click"] = click
# Kumaş hışırtısı: yumuşak bant gürültüsü, çan eğrisi zarf.
x = t(0.28)
SOUNDS["cloth"] = noise(0.28, 700, 4200) * np.exp(-((x - 0.1) / 0.07) ** 2) * 0.8
# Katlama "puf": alçak gürültü + tok vuruş.
puff = noise(0.4, 120, 1500) * env(0.4, 0.012, 11)
puff += 0.7 * np.sin(2 * np.pi * 150 * t(0.4)) * env(0.4, 0.005, 16)
SOUNDS["fold_puff"] = puff
# Tek nota: art arda sepetlerde perdesi oyunda yükseltilir.
SOUNDS["note"] = marimba(523.25, 0.7)
# Islak sıkma: ıslak, titreşen gürültü.
x = t(0.34)
SOUNDS["wring"] = noise(0.34, 300, 2600) * (0.55 + 0.45 * np.sin(2 * np.pi * 34 * x)) \
    * np.exp(-((x - 0.14) / 0.1) ** 2)
# Kilit açılma: iki küçük nota.
SOUNDS["unlock"] = mix_at(pad(marimba(784, 0.3, 14), 0.5), marimba(1046.5, 0.38, 12), 0.09)
# Fırtına rüzgârı: yavaş kabaran alçak gürültü.
x = t(2.4)
SOUNDS["wind"] = noise(2.4, 150, 1100) * np.sin(np.pi * x / 2.4) ** 1.5 \
    * (0.75 + 0.25 * np.sin(2 * np.pi * 0.9 * x))
# Kazanma: yumuşak üç notalı arpej.
win = np.zeros(int(RATE * 1.5))
for index, freq in enumerate((523.25, 659.25, 783.99, 1046.5)):
    mix_at(win, marimba(freq, 0.9, 6.0), 0.11 * index)
SOUNDS["win"] = win

os.makedirs(SFX_DIR, exist_ok=True)
table = json.load(open(SOUNDS_PATH, encoding="utf-8")) if os.path.exists(SOUNDS_PATH) else {}
for name, signal in SOUNDS.items():
    signal = signal / max(float(np.max(np.abs(signal))), 1e-9) * PEAK
    fade = min(256, signal.size // 4)
    signal[-fade:] *= np.linspace(1.0, 0.0, fade)
    path = os.path.join(SFX_DIR, name + ".wav")
    with wave.open(path, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes((signal * 32767).astype("<i2").tobytes())
    table[name] = "res://assets/audio/sfx/%s.wav" % name
    print("yazıldı:", name)
json.dump(dict(sorted(table.items())), open(SOUNDS_PATH, "w", encoding="utf-8"), indent=2)
