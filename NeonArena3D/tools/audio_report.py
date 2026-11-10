#!/usr/bin/env python3
"""Ses denetimi: algılanan yükseklik (K-ağırlıklı, 400 ms en yüksek pencere), tepe, DC,
müzik döngü dikişi. Sound.SFX içindeki dB kazançlarıyla oyun içi etkin seviyeyi hesaplar.

    python3 tools/audio_report.py            # tablo
    python3 tools/audio_report.py --json     # makine okunur
"""
import json
import os
import re
import sys
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AUDIO = os.path.join(ROOT, "assets", "audio")
SOUND_GD = os.path.join(ROOT, "scripts", "autoload", "sound.gd")


def load(path):
    with wave.open(path, "rb") as w:
        sr = w.getframerate()
        ch = w.getnchannels()
        data = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(float) / 32768.0
    return data.reshape(-1, ch), sr


def k_weight(x, sr):
    """ITU-R BS.1770 K-ağırlığına yakın: 60 Hz yüksek geçiren + 1.5 kHz üstü +4 dB raf."""
    spec = np.fft.rfft(x, axis=0)
    f = np.fft.rfftfreq(len(x), 1.0 / sr)
    hp = 1.0 / np.sqrt(1.0 + (60.0 / np.maximum(f, 1e-3)) ** 4)
    shelf = 1.0 + (10 ** (4.0 / 20.0) - 1.0) / (1.0 + (1500.0 / np.maximum(f, 1e-3)) ** 2)
    return np.fft.irfft(spec * (hp * shelf)[:, None], len(x), axis=0)


def loudness(x, sr, window=0.4):
    y = k_weight(x, sr)
    power = np.sum(y ** 2, axis=1)
    n = max(1, int(sr * window))
    if len(power) <= n:
        return 10 * np.log10(np.mean(power) + 1e-12) - 0.691
    c = np.cumsum(np.concatenate([[0.0], power]))
    win = (c[n:] - c[:-n]) / n
    return 10 * np.log10(np.max(win) + 1e-12) - 0.691


def integrated(x, sr):
    y = k_weight(x, sr)
    return 10 * np.log10(np.mean(np.sum(y ** 2, axis=1)) + 1e-12) - 0.691


def gains():
    src = open(SOUND_GD, encoding="utf-8").read()
    out = {}
    for m in re.finditer(r'"(\w+)": \["(\w+)", (-?[\d.]+)', src):
        out[m.group(2)] = (m.group(1), float(m.group(3)))
    return out


def main():
    g = gains()
    rows = []
    for name in sorted(os.listdir(AUDIO)):
        if not name.endswith(".wav"):
            continue
        x, sr = load(os.path.join(AUDIO, name))
        stem = name[:-4]
        peak = 20 * np.log10(np.max(np.abs(x)) + 1e-12)
        dc = float(np.max(np.abs(np.mean(x, axis=0))))
        is_music = stem.startswith("music_")
        lu = integrated(x, sr) if is_music else loudness(x, sr)
        gain = g.get(stem, (stem, None))[1]
        row = {"name": stem, "len": len(x) / sr, "peak": peak, "dc": dc, "lufs": lu, "gain": gain,
               "effective": None if gain is None else lu + gain}
        if is_music:
            # Dikiş sıçramasını tipik örnek adımına göre ölç: >1 ise döngü noktası olağan dışı.
            steps = np.max(np.abs(np.diff(x, axis=0)), axis=1)
            seam = float(np.max(np.abs(x[0] - x[-1])) / (np.percentile(steps, 99) + 1e-9))
            head = integrated(x[: sr * 2], sr)
            tail = integrated(x[-sr * 2:], sr)
            row.update({"seam": seam, "head": head, "tail": tail})
        rows.append(row)
    if "--json" in sys.argv:
        print(json.dumps(rows, indent=1))
        return
    print("%-15s %6s %7s %7s %7s %7s %7s" % ("ses", "süre", "tepe", "LUFS", "kazanç", "etkin", "DC"))
    for r in rows:
        print("%-15s %5.2fs %6.1f %7.1f %7s %7s %7.4f%s" % (
            r["name"], r["len"], r["peak"], r["lufs"],
            "-" if r["gain"] is None else "%.1f" % r["gain"],
            "-" if r["effective"] is None else "%.1f" % r["effective"], r["dc"],
            ("   dikiş/p99=%.2f baş=%.1f son=%.1f" % (r["seam"], r["head"], r["tail"])) if "seam" in r else ""))


if __name__ == "__main__":
    main()
