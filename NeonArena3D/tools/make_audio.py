#!/usr/bin/env python3
"""NEON ARENA 3D — tüm ses efektlerini ve müzikleri sentezler (harici örnek yok).

Kullanım:  python3 tools/make_audio.py            # hepsi
           python3 tools/make_audio.py sfx        # yalnız efektler
           python3 tools/make_audio.py music      # yalnız müzik
Çıktı:    assets/audio/*.wav  (44.1 kHz, 16 bit, stereo)
Gereken:  numpy
"""
import os
import sys
import wave

import numpy as np

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio")
rng = np.random.default_rng(20261109)


# --------------------------------------------------------------------------- temel
def n_of(dur):
    return int(round(SR * dur))


def tt(dur):
    return np.arange(n_of(dur)) / SR


def glide(f0, f1, dur, curve=1.0):
    """f0 → f1 üstel kayma; curve>1 daha hızlı düşer."""
    x = np.linspace(0.0, 1.0, n_of(dur)) ** (1.0 / curve)
    return f0 * (f1 / f0) ** x


def phase(freq, dur=None):
    if np.isscalar(freq):
        return 2 * np.pi * freq * tt(dur)
    return 2 * np.pi * np.cumsum(freq) / SR


def sine(freq, dur=None):
    return np.sin(phase(freq, dur))


def saw(freq, dur=None):
    p = phase(freq, dur) / (2 * np.pi)
    return 2.0 * (p % 1.0) - 1.0


def square(freq, dur=None, duty=0.5):
    p = phase(freq, dur) / (2 * np.pi)
    return np.where((p % 1.0) < duty, 1.0, -1.0)


def tri(freq, dur=None):
    return 2.0 * np.abs(saw(freq, dur)) - 1.0


def noise(dur):
    return rng.uniform(-1.0, 1.0, n_of(dur))


def decay(dur, rate, attack=0.002):
    """Üstel sönüm zarfı; rate büyüdükçe hızlı söner."""
    t = tt(dur)
    e = np.exp(-t * rate)
    a = np.clip(t / max(attack, 1e-5), 0.0, 1.0)
    return e * a


def adsr(dur, a=0.01, d=0.1, s=0.6, r=0.1):
    n = n_of(dur)
    t = np.arange(n) / SR
    out = np.full(n, s)
    out = np.where(t < a, t / max(a, 1e-5), out)
    dm = (t >= a) & (t < a + d)
    out = np.where(dm, 1.0 - (1.0 - s) * (t - a) / max(d, 1e-5), out)
    rel = dur - r
    out = np.where(t > rel, s * np.clip(1.0 - (t - rel) / max(r, 1e-5), 0.0, 1.0), out)
    return out


def fade(x, fin=0.002, fout=0.006):
    x = x.copy()
    a = min(len(x) // 2, n_of(fin))
    b = min(len(x) // 2, n_of(fout))
    if a > 0:
        x[:a] *= np.linspace(0.0, 1.0, a)[(...,) + (None,) * (x.ndim - 1)]
    if b > 0:
        x[-b:] *= np.linspace(1.0, 0.0, b)[(...,) + (None,) * (x.ndim - 1)]
    return x


def _filt(x, cutoff, order, high):
    n = len(x)
    spec = np.fft.rfft(x, axis=0)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    ratio = (f / max(cutoff, 1.0)) ** (2 * order)
    h = 1.0 / np.sqrt(1.0 + ratio)
    if high:
        h = np.sqrt(1.0 - h * h)
    if x.ndim == 2:
        h = h[:, None]
    return np.fft.irfft(spec * h, n, axis=0)


def lp(x, cutoff, order=2):
    return _filt(x, cutoff, order, False)


def hp(x, cutoff, order=2):
    return _filt(x, cutoff, order, True)


def bp(x, lo, hi, order=2):
    return hp(lp(x, hi, order), lo, order)


def sweep_lp(x, f0, f1, steps=10, order=2, curve=1.0):
    """Zamanla değişen alçak geçiren: log aralıklı filtreli kopyalar arasında geçiş."""
    n = len(x)
    cut = np.geomspace(f0, f1, steps)
    layers = [lp(x, c, order) for c in cut]
    pos = (np.linspace(0.0, 1.0, n) ** curve) * (steps - 1)
    idx = np.clip(pos.astype(int), 0, steps - 2)
    frac = pos - idx
    out = np.zeros(n)
    for i in range(steps - 1):
        m = idx == i
        out[m] = layers[i][m] * (1.0 - frac[m]) + layers[i + 1][m] * frac[m]
    return out


def drive(x, amount=2.0):
    return np.tanh(x * amount) / np.tanh(amount)


def stereo(x, pan=0.0):
    if x.ndim == 2:
        return x
    l = np.cos((pan + 1.0) * np.pi / 4.0)
    r = np.sin((pan + 1.0) * np.pi / 4.0)
    return np.stack([x * l, x * r], axis=1) * np.sqrt(2.0) * 0.5 * 1.4142


def widen(x, ms=9.0, amount=0.5):
    """Haas benzeri genişlik: sağ kanala küçük gecikme karışımı."""
    d = n_of(ms / 1000.0)
    delayed = np.concatenate([np.zeros(d), x])[: len(x)]
    left = x + delayed * amount * 0.4
    right = x * (1.0 - amount * 0.25) + delayed * amount
    return np.stack([left, right], axis=1)


def pad_to(x, n):
    if len(x) >= n:
        return x
    shape = (n - len(x),) + x.shape[1:]
    return np.concatenate([x, np.zeros(shape)])


def mix(*layers):
    n = max(len(l) for l in layers)
    out = np.zeros((n, 2))
    for l in layers:
        s = stereo(l)
        out[: len(s)] += s
    return out


def at(layer, offset):
    s = stereo(layer)
    return np.concatenate([np.zeros((n_of(offset), 2)), s])


_IR_CACHE = {}


def _ir(time, bright):
    key = (round(time, 3), round(bright))
    if key not in _IR_CACHE:
        n = n_of(time)
        r = np.random.default_rng(int(time * 1000) + int(bright))
        ir = r.normal(0.0, 1.0, (n, 2)) * np.exp(-np.arange(n) / SR * (6.9 / time))[:, None]
        ir = lp(ir, bright, 1)
        ir[: n_of(0.004)] *= 0.0
        ir /= np.sqrt(np.sum(ir ** 2) / 2.0) + 1e-9
        _IR_CACHE[key] = ir
    return _IR_CACHE[key]


def reverb(x, time=0.9, wet=0.25, bright=5000.0):
    x = stereo(x)
    ir = _ir(time, bright)
    n = len(x) + len(ir) - 1
    size = 1 << (n - 1).bit_length()
    out = np.zeros((n, 2))
    for ch in range(2):
        out[:, ch] = np.fft.irfft(np.fft.rfft(x[:, ch], size) * np.fft.rfft(ir[:, ch], size), size)[:n]
    dry = pad_to(x, n)
    return dry + out * wet


def echo(x, delay, feedback=0.4, wet=0.35, taps=5, ping=True, damp=3500.0):
    x = stereo(x)
    d = n_of(delay)
    out = pad_to(x, len(x) + d * taps)
    cur = x
    gain = wet
    for k in range(1, taps + 1):
        cur = lp(cur, damp, 1)
        tap = cur[:, ::-1] if (ping and k % 2 == 1) else cur
        out[d * k: d * k + len(tap)] += tap * gain
        gain *= feedback
    return out


def save(name, x, peak=0.89, tail=0.008):
    os.makedirs(OUT, exist_ok=True)
    x = stereo(np.asarray(x, dtype=float))
    # DC kaymasını sil: asimetrik dalgalar (kare/testere) ortalamayı sıfırdan kaydırır, tık ve boşa headroom yapar.
    x = x - np.mean(x, axis=0)
    top = np.max(np.abs(x)) + 1e-9
    # Duyulmayan yankı kuyruğunu kırp (-54 dB altı).
    loud = np.nonzero(np.max(np.abs(x), axis=1) > top * 0.002)[0]
    if len(loud) > 0:
        x = x[: min(len(x), loud[-1] + n_of(0.02))]
    x = fade(x, 0.0008, max(tail, min(0.06, len(x) / SR * 0.15)))
    x = x * (peak / top)
    data = (np.clip(x, -1.0, 1.0) * 32767.0).astype("<i2")
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    rms = np.sqrt(np.mean(x ** 2))
    print("%-16s %6.2fs  rms %.3f  %7.1f KB" % (name, len(x) / SR, rms, data.nbytes / 1024))


# --------------------------------------------------------------------------- efektler
def sfx_shoot():
    d = 0.15
    f = glide(2100, 380, d, 2.2)
    body = saw(f) * 0.55 + square(f * 0.5) * 0.35
    body = sweep_lp(body, 9000, 1400, 8) * decay(d, 26, 0.001)
    click = hp(noise(0.012), 3500) * decay(0.012, 320, 0.0003) * 0.7
    thump = sine(glide(210, 70, 0.07)) * decay(0.07, 38) * 0.6
    save("shoot", mix(widen(body, 5, 0.35), click, thump), 0.86)


def sfx_shoot_enemy():
    d = 0.2
    f = glide(820, 190, d, 1.6)
    body = square(f, duty=0.32) * 0.5 + sine(f * 2.01) * 0.25
    body = lp(body, 2600) * decay(d, 17, 0.003)
    grit = bp(noise(d), 500, 1800) * decay(d, 30) * 0.25
    save("shoot_enemy", mix(widen(body, 7, 0.3), grit), 0.8)


def sfx_shoot_sniper():
    d = 0.42
    crack = hp(noise(0.05), 1800) * decay(0.05, 90, 0.0004)
    beam = sine(glide(3200, 240, d, 3.0)) * decay(d, 13, 0.001) * 0.7
    low = sine(glide(160, 48, 0.2)) * decay(0.2, 18) * 0.8
    save("shoot_sniper", reverb(mix(crack, widen(beam, 6, 0.4), low), 0.55, 0.22), 0.86)


def sfx_hit():
    d = 0.07
    tick = sine(glide(1500, 700, d)) * decay(d, 70, 0.0005) * 0.7
    nz = hp(noise(d), 2400) * decay(d, 95, 0.0004) * 0.8
    save("hit", mix(tick, nz), 0.82, 0.004)


def sfx_crit():
    d = 0.24
    nz = hp(noise(0.06), 2000) * decay(0.06, 80, 0.0004)
    ring = (sine(2093, d) + 0.6 * sine(3136, d) + 0.35 * sine(4699, d)) * decay(d, 16, 0.001) * 0.45
    thud = sine(glide(260, 90, 0.09)) * decay(0.09, 34) * 0.7
    save("crit", reverb(mix(nz, widen(ring, 4, 0.5), thud), 0.35, 0.18), 0.86)


def _boom(d, f0, f1, bright, rate):
    nz = sweep_lp(noise(d), bright, 180, 10, 2, 0.55) * decay(d, rate, 0.002)
    sub = sine(glide(f0, f1, d, 1.8)) * decay(d, rate * 0.8, 0.003)
    crack = hp(noise(0.03), 3000) * decay(0.03, 150, 0.0003) * 0.6
    return drive(nz * 0.9 + sub * 1.0, 1.6), crack


def sfx_explode():
    body, crack = _boom(0.5, 150, 42, 6500, 9.5)
    save("explode", reverb(mix(widen(body, 8, 0.4), crack), 0.4, 0.14), 0.88)


def sfx_explode_big():
    body, crack = _boom(1.15, 120, 30, 7500, 4.6)
    debris = bp(noise(0.9), 900, 5000) * decay(0.9, 5.0, 0.05) * (0.5 + 0.5 * square(23, 0.9)) * 0.28
    second = at(_boom(0.6, 95, 34, 3800, 8.0)[0] * 0.55, 0.13)
    save("explode_big", reverb(mix(widen(body, 11, 0.5), crack, debris, second), 0.9, 0.24, 3800), 0.9)


def sfx_hurt():
    d = 0.36
    f = glide(330, 105, d, 1.5)
    body = drive(square(f, duty=0.4) * 0.6 + saw(f * 1.5) * 0.3, 3.0)
    body = lp(body, 3200) * decay(d, 9.5, 0.002)
    nz = bp(noise(0.12), 700, 4000) * decay(0.12, 30, 0.001) * 0.7
    thud = sine(glide(140, 50, 0.16)) * decay(0.16, 20) * 0.9
    save("hurt", mix(widen(body, 9, 0.45), nz, thud), 0.9)


def sfx_dash():
    d = 0.3
    n = n_of(d)
    nz = noise(d)
    sw = sweep_lp(nz, 500, 7000, 10, 2, 0.6)
    sw = hp(sw, 350)
    shape = np.sin(np.linspace(0.0, np.pi, n)) ** 1.4
    tone = sine(glide(260, 1250, d, 0.7)) * shape * 0.22
    x = sw * shape * 0.9 + tone
    left = x * np.linspace(1.0, 0.45, n)
    right = x * np.linspace(0.45, 1.0, n)
    save("dash", np.stack([left, right], axis=1), 0.8)


def _pluck(freq, d, bright=4200.0, rate=9.0):
    x = saw(freq, d) * 0.5 + tri(freq, d) * 0.5 + sine(freq * 2, d) * 0.2
    return sweep_lp(x, bright, 900, 6) * decay(d, rate, 0.002)


def _bell(freq, d, rate=7.0):
    x = sine(freq, d) + 0.42 * sine(freq * 2.0, d) + 0.22 * sine(freq * 3.01, d) + 0.12 * sine(freq * 4.2, d)
    return x * decay(d, rate, 0.002)


def sfx_pickup_heal():
    a = _bell(659.3, 0.3, 11)
    b = at(_bell(987.8, 0.42, 9), 0.085)
    save("pickup_heal", reverb(mix(a, b), 0.6, 0.25), 0.82)


def sfx_pickup_power():
    notes = [523.3, 659.3, 784.0, 1046.5, 1318.5]
    layers = [at(stereo(_pluck(f, 0.2, 6500, 16), (i - 2) * 0.25), i * 0.045) for i, f in enumerate(notes)]
    save("pickup_power", reverb(mix(*layers), 0.5, 0.22), 0.84)


def sfx_shield_up():
    d = 0.5
    f = glide(330, 990, d, 0.8)
    x = (sine(f) + 0.5 * sine(f * 1.5) + 0.3 * sine(f * 2.01)) * (0.75 + 0.25 * sine(26, d))
    x *= np.sin(np.linspace(0.0, np.pi, n_of(d))) ** 0.8
    air = hp(noise(d), 5000) * np.linspace(0.0, 1.0, n_of(d)) * decay(d, 3.0) * 0.18
    save("shield_up", reverb(mix(widen(x, 10, 0.6), air), 0.7, 0.3), 0.8)


def sfx_shield_break():
    d = 0.4
    glass = hp(noise(0.14), 3200) * decay(0.14, 34, 0.0004)
    tones = sum(sine(glide(f, f * 0.55, d)) * decay(d, 9 + i * 2, 0.001) for i, f in enumerate([1760, 2349, 3136, 4186])) * 0.22
    thud = sine(glide(190, 60, 0.15)) * decay(0.15, 20) * 0.7
    save("shield_break", reverb(mix(glass, widen(tones, 7, 0.6), thud), 0.5, 0.22), 0.86)


def sfx_nova():
    rise_d = 0.16
    rise = sweep_lp(noise(rise_d), 600, 9000, 8) * np.linspace(0.0, 1.0, n_of(rise_d)) ** 2 * 0.6
    rise += sine(glide(200, 1600, rise_d, 0.6)) * np.linspace(0.0, 1.0, n_of(rise_d)) ** 2 * 0.3
    d = 1.3
    body, crack = _boom(d, 170, 28, 9000, 3.6)
    zap = sweep_lp(saw(glide(2600, 70, d, 2.4)), 8000, 300, 8) * decay(d, 4.2, 0.002) * 0.4
    shimmer = hp(noise(d), 6000) * decay(d, 3.0, 0.01) * 0.2
    boom = mix(widen(body, 13, 0.6), crack, widen(zap, 6, 0.6), shimmer)
    save("nova", reverb(mix(rise, at(boom, rise_d - 0.01)), 1.2, 0.3, 4200), 0.92)


def sfx_nova_ready():
    a = _bell(784.0, 0.5, 6)
    b = at(_bell(1174.7, 0.5, 6), 0.07)
    c = at(_bell(1568.0, 0.6, 5), 0.14)
    save("nova_ready", reverb(mix(stereo(a, -0.4), stereo(b, 0.4), c), 0.8, 0.3), 0.78)


def sfx_level_up():
    notes = [523.3, 659.3, 784.0, 1046.5, 1318.5, 1568.0]
    layers = []
    for i, f in enumerate(notes):
        layers.append(at(stereo(_pluck(f, 0.32, 7000, 10) + 0.5 * _bell(f * 2, 0.32, 12), (i % 2) * 0.6 - 0.3), i * 0.058))
    chord = sum(_bell(f, 0.9, 3.5) for f in [1046.5, 1318.5, 1568.0]) * 0.3
    layers.append(at(widen(chord, 12, 0.7), 0.36))
    sub = sine(glide(90, 180, 0.4, 0.8)) * decay(0.4, 5, 0.03) * 0.5
    layers.append(sub)
    save("level_up", reverb(mix(*layers), 1.0, 0.3), 0.86)


def sfx_card_pick():
    a = _pluck(784.0, 0.16, 6500, 16)
    b = at(_pluck(1174.7, 0.3, 7000, 10) + 0.4 * _bell(2349.3, 0.3, 10), 0.07)
    click = hp(noise(0.01), 3000) * decay(0.01, 300, 0.0003) * 0.5
    thump = sine(glide(170, 70, 0.1)) * decay(0.1, 28) * 0.6
    save("card_pick", reverb(mix(a, b, click, thump), 0.5, 0.2), 0.84)


def sfx_ui_click():
    d = 0.08
    x = sine(glide(1500, 950, d)) * decay(d, 55, 0.0005)
    click = hp(noise(0.008), 3500) * decay(0.008, 380, 0.0002) * 0.5
    low = sine(240, 0.05) * decay(0.05, 50) * 0.5
    save("ui_click", mix(x, click, low), 0.72, 0.004)


def sfx_ui_hover():
    d = 0.045
    x = sine(2100, d) * decay(d, 85, 0.0008)
    save("ui_hover", x, 0.5, 0.004)


def sfx_ui_back():
    d = 0.12
    x = sine(glide(1000, 520, d)) * decay(d, 32, 0.0008) + tri(glide(500, 260, d)) * decay(d, 32) * 0.4
    save("ui_back", x, 0.68, 0.005)


def sfx_ui_toggle():
    a = sine(1320, 0.05) * decay(0.05, 60, 0.0006)
    b = at(sine(1760, 0.07) * decay(0.07, 45, 0.0006), 0.045)
    save("ui_toggle", mix(a, b), 0.62, 0.004)


def sfx_wave_start():
    rise_d = 0.42
    ramp = np.linspace(0.0, 1.0, n_of(rise_d)) ** 2.2
    rise = hp(sweep_lp(noise(rise_d), 800, 10000, 8), 500) * ramp * 0.5 + saw(glide(110, 440, rise_d, 0.7)) * ramp * 0.22
    d = 0.8
    chord = sum(saw(f, d) for f in [146.8, 220.0, 293.7, 440.0]) * 0.22
    chord = sweep_lp(chord, 5200, 500, 8) * decay(d, 4.5, 0.002)
    hit = sine(glide(150, 46, 0.3)) * decay(0.3, 12) * 0.9
    crack = hp(noise(0.03), 2500) * decay(0.03, 120, 0.0004) * 0.5
    impact = mix(widen(chord, 12, 0.7), hit, crack)
    save("wave_start", reverb(mix(widen(rise, 8, 0.5), at(impact, rise_d - 0.005)), 0.9, 0.26), 0.86)


def sfx_wave_clear():
    notes = [523.3, 659.3, 784.0, 987.8, 1174.7]
    layers = [at(stereo(_pluck(f, 0.5, 6000, 6.5) + 0.35 * _bell(f * 2, 0.5, 8), (i - 2) * 0.3), i * 0.05) for i, f in enumerate(notes)]
    bass = sine(130.8, 0.6) * decay(0.6, 5, 0.01) * 0.5
    layers.append(bass)
    save("wave_clear", reverb(mix(*layers), 1.1, 0.32), 0.84)


def sfx_boss_warn():
    d = 1.7
    n = n_of(d)
    t = tt(d)
    gate = (np.sin(2 * np.pi * 1.95 * t - 0.3) > -0.25).astype(float)
    gate = lp(gate, 60, 1)
    f = np.where(np.sin(2 * np.pi * 1.95 * t - 0.3) > 0.45, 466.2, 349.2)
    f = lp(f, 40, 1)
    siren = drive(square(f, duty=0.45) * 0.6 + saw(f * 0.5) * 0.4, 2.2)
    siren = lp(siren, 2400) * gate * np.clip(1.0 - t / d * 0.25, 0, 1)
    rumble = lp(noise(d), 110, 2) * 3.0 * np.sin(np.linspace(0.0, np.pi, n)) ** 0.6
    sub = sine(glide(48, 36, d)) * 0.7 * np.sin(np.linspace(0.0, np.pi, n)) ** 0.5
    save("boss_warn", reverb(mix(widen(siren, 14, 0.6), rumble, sub), 1.2, 0.26, 3000), 0.86, 0.05)


def sfx_boss_phase():
    d = 1.2
    f = glide(52, 82, d, 0.8)
    growl = drive(saw(f) + saw(f * 1.012) + saw(f * 0.5) * 0.7 + square(f * 2.0) * 0.3, 2.5)
    growl = sweep_lp(growl, 300, 4200, 10) * np.sin(np.linspace(0.0, np.pi, n_of(d))) ** 0.7
    growl *= 0.7 + 0.3 * sine(31, d)
    nz = bp(noise(d), 1200, 7000) * np.linspace(0.0, 1.0, n_of(d)) ** 2 * 0.3
    body, crack = _boom(0.7, 130, 36, 6000, 7.0)
    save("boss_phase", reverb(mix(widen(growl, 12, 0.6), nz, at(mix(body, crack) * 0.8, d - 0.25)), 1.0, 0.25, 3600), 0.9)


def sfx_boss_die():
    layers = []
    for i, (off, sc) in enumerate([(0.0, 0.7), (0.22, 0.6), (0.4, 0.75), (0.62, 0.65), (0.85, 1.0)]):
        body, crack = _boom(0.5 + 0.9 * (i == 4), 160 - i * 12, 34, 6000 + 800 * i, 9.0 - 5.0 * (i == 4))
        layers.append(at(stereo(body * sc, (i % 2) * 1.0 - 0.5 if i < 4 else 0.0), off))
        layers.append(at(crack * sc, off))
    d = 2.4
    sub = sine(glide(90, 24, d, 1.4)) * decay(d, 1.8, 0.02) * 0.8
    shimmer = hp(noise(d), 5000) * decay(d, 2.2, 0.85) * 0.2
    whine = sine(glide(1800, 120, 1.0, 1.5)) * decay(1.0, 3.0, 0.01) * 0.25
    layers += [sub, at(shimmer, 0.85), widen(whine, 10, 0.6)]
    save("boss_die", reverb(mix(*layers), 1.8, 0.32, 3600), 0.92, 0.1)


def sfx_game_over():
    notes = [440.0, 349.2, 293.7, 220.0]
    layers = []
    for i, f in enumerate(notes):
        x = saw(f, 0.7) * 0.5 + saw(f * 1.007, 0.7) * 0.5 + square(f * 0.5, 0.7) * 0.3
        x = sweep_lp(x, 3800, 420, 8) * decay(0.7, 4.2, 0.004)
        layers.append(at(widen(x, 11, 0.6), i * 0.24))
    drone = lp(saw(55, 2.0) + saw(55.4, 2.0), 300) * decay(2.0, 1.4, 0.3) * 0.7
    layers.append(at(drone, 0.5))
    hit = sine(glide(120, 34, 0.5)) * decay(0.5, 7) * 0.9
    layers.append(hit)
    save("game_over", reverb(mix(*layers), 1.7, 0.36, 3200), 0.86, 0.15)


def sfx_combo():
    d = 0.14
    x = (tri(880, d) * 0.6 + sine(1760, d) * 0.4) * decay(d, 26, 0.001)
    save("combo", reverb(x, 0.3, 0.2), 0.7)


def sfx_low_hp():
    def thump(f):
        return sine(glide(f, f * 0.5, 0.14)) * decay(0.14, 24, 0.004)
    x = mix(thump(92), at(thump(76) * 0.8, 0.2))
    save("low_hp", lp(pad_to(x, n_of(0.55)), 400), 0.8, 0.02)


def sfx_elite():
    d = 0.75
    x = sum(saw(f, d) + saw(f * 1.008, d) for f in [82.4, 123.5, 164.8]) * 0.2
    x = drive(sweep_lp(x, 400, 3200, 8, 2, 0.5), 1.8) * adsr(d, 0.03, 0.2, 0.6, 0.35)
    ping = _bell(1318.5, 0.5, 8) * 0.3
    save("elite", reverb(mix(widen(x, 12, 0.6), ping), 0.9, 0.28, 3000), 0.84)


def sfx_revive():
    rise_d = 0.5
    ramp = np.linspace(0.0, 1.0, n_of(rise_d)) ** 1.6
    rise = hp(sweep_lp(noise(rise_d), 500, 11000, 8), 400) * ramp * 0.45 + sine(glide(180, 1400, rise_d, 0.6)) * ramp * 0.3
    chord = sum(_bell(f, 1.0, 3.2) for f in [523.3, 784.0, 1046.5, 1318.5, 1568.0]) * 0.25
    hit = sine(glide(140, 50, 0.3)) * decay(0.3, 12) * 0.7
    save("revive", reverb(mix(widen(rise, 9, 0.5), at(mix(widen(chord, 12, 0.7), hit), rise_d)), 1.3, 0.34), 0.86, 0.1)


def sfx_spawn():
    d = 0.16
    x = sine(glide(720, 300, d)) * decay(d, 22, 0.004) * 0.8 + bp(noise(d), 1500, 5000) * decay(d, 30, 0.01) * 0.2
    save("spawn", x, 0.55)


def sfx_chain():
    d = 0.17
    nz = hp(noise(d), 1800) * (0.5 + 0.5 * square(96, d)) * decay(d, 20, 0.0006)
    buzz = square(glide(1900, 700, d), duty=0.2) * decay(d, 24, 0.0006) * 0.3
    save("chain", widen(nz + buzz, 6, 0.6), 0.74)


def sfx_bomb_beep():
    d = 0.09
    x = square(1480, d, 0.5) * 0.5 + sine(2960, d) * 0.3
    save("bomb_beep", lp(x, 5000) * decay(d, 30, 0.001), 0.6, 0.004)


def sfx_deny():
    d = 0.16
    x = square(glide(240, 150, d), duty=0.4) * decay(d, 14, 0.002)
    save("deny", lp(x, 1800), 0.6)


# --- v1.2 efektleri ------------------------------------------------------------
def sfx_purchase():
    a = _bell(1046.5, 0.35, 9)
    b = at(_bell(1568.0, 0.5, 7), 0.07)
    c = at(_bell(2093.0, 0.6, 6) * 0.6, 0.14)
    clink = hp(noise(0.02), 4000) * decay(0.02, 200, 0.0003) * 0.5
    sparkle = at(hp(noise(0.4), 7000) * decay(0.4, 9, 0.02) * 0.25, 0.1)
    save("purchase", reverb(mix(stereo(a, -0.3), stereo(b, 0.3), c, clink, sparkle), 0.7, 0.28), 0.84)


def sfx_shoot_scatter():
    d = 0.32
    blast = sweep_lp(noise(d), 7000, 600, 8, 2, 0.6) * decay(d, 16, 0.001)
    thump = sine(glide(140, 48, 0.16, 1.6)) * decay(0.16, 18, 0.001)
    click = hp(noise(0.01), 3000) * decay(0.01, 300, 0.0002) * 0.6
    crack = bp(noise(0.06), 1500, 6000) * decay(0.06, 60, 0.0005) * 0.5
    save("shoot_scatter", mix(widen(blast * 0.9, 6, 0.5), thump, click, crack), 0.88)


def sfx_shoot_rail():
    pre_d = 0.07
    pre = sine(glide(600, 2400, pre_d, 0.6)) * np.linspace(0.2, 1.0, n_of(pre_d)) * 0.35
    d = 0.5
    crack = hp(noise(0.04), 2500) * decay(0.04, 110, 0.0003)
    beam = (saw(glide(3600, 180, d, 2.2)) * 0.5 + sine(glide(1800, 90, d, 2.0)) * 0.5) * decay(d, 8.5, 0.001)
    beam = sweep_lp(beam, 9000, 900, 8)
    sub = sine(glide(120, 40, 0.25)) * decay(0.25, 12, 0.002) * 0.9
    body = mix(crack, widen(beam, 7, 0.6), sub)
    save("shoot_rail", reverb(mix(pre, at(body, pre_d)), 0.6, 0.2), 0.88)


def sfx_shoot_rocket():
    d = 0.45
    n = n_of(d)
    whoosh = hp(sweep_lp(noise(d), 600, 6000, 8, 2, 0.5), 300) * np.sin(np.linspace(0.0, np.pi, n)) ** 0.8
    ignite = bp(noise(0.08), 300, 2500) * decay(0.08, 30, 0.001) * 0.8
    tone = saw(glide(180, 420, d, 0.8)) * decay(d, 4.0, 0.01) * 0.12
    left = whoosh * np.linspace(1.0, 0.5, n)
    right = whoosh * np.linspace(0.5, 1.0, n)
    save("shoot_rocket", mix(np.stack([left, right], axis=1) * 0.8, ignite, lp(tone, 2000)), 0.8)


def sfx_slam():
    body, crack = _boom(0.7, 110, 30, 4500, 7.5)
    crunch = bp(noise(0.25), 200, 2400) * decay(0.25, 14, 0.001) * (0.6 + 0.4 * square(37, 0.25))
    debris = at(hp(noise(0.4), 2500) * decay(0.4, 7, 0.03) * 0.2, 0.05)
    save("slam", reverb(mix(widen(body, 9, 0.5), crack, crunch * 0.6, debris), 0.7, 0.2, 3500), 0.9)


def sfx_leap():
    d = 0.9
    ramp = np.linspace(0.0, 1.0, n_of(d)) ** 1.5
    roar = drive(saw(glide(70, 140, d, 0.8)) + saw(glide(71, 142, d, 0.8)), 2.0) * ramp * 0.35
    roar = sweep_lp(roar, 300, 2800, 8)
    wind = hp(sweep_lp(noise(d), 500, 9000, 8, 2, 0.7), 400) * ramp * 0.5
    save("leap", reverb(mix(widen(roar, 10, 0.5), widen(wind, 8, 0.6)), 0.8, 0.22), 0.84, 0.08)


def sfx_teleport():
    d = 0.6
    t = tt(d)
    f = glide(300, 2400, d, 0.7) * (1.0 + 0.3 * np.sin(2 * np.pi * 34 * t))
    x = sine(f) * np.sin(np.linspace(0.0, np.pi, n_of(d))) ** 0.6 * 0.6
    sh = hp(noise(d), 6000) * decay(d, 5.0, 0.05) * 0.25
    pop = at(sine(glide(900, 200, 0.12)) * decay(0.12, 25) * 0.6, d * 0.7)
    save("teleport", reverb(mix(widen(x, 9, 0.7), sh, pop), 0.9, 0.3), 0.8)


def sfx_laser_charge():
    d = 1.0
    t = tt(d)
    ramp = np.linspace(0.0, 1.0, n_of(d)) ** 1.4
    f = glide(220, 1300, d, 0.8)
    x = (saw(f) * 0.4 + sine(f * 2) * 0.3) * (0.6 + 0.4 * np.sin(2 * np.pi * (6 + 24 * ramp) * t)) * ramp
    x = lp(x, 4500)
    save("laser_charge", reverb(widen(x, 8, 0.6), 0.5, 0.2), 0.78, 0.05)


def sfx_laser():
    d = 0.32
    t = tt(d)
    buzz = saw(110, d) * 0.5 + saw(110.7, d) * 0.5 + square(220, d, 0.3) * 0.25
    buzz *= 0.75 + 0.25 * np.sin(2 * np.pi * 31 * t)
    hiss = hp(noise(d), 4500) * 0.15
    env = np.sin(np.linspace(0.0, np.pi, n_of(d))) ** 0.5
    x = drive(lp(buzz, 2600) + hiss, 1.6) * env
    save("laser", widen(x, 9, 0.6), 0.7, 0.04)


def sfx_synergy():
    notes = [392.0, 523.3, 659.3, 784.0, 1046.5, 1318.5, 1568.0, 2093.0]
    layers = [at(stereo(_pluck(f, 0.4, 8000, 8) + 0.6 * _bell(f * 2, 0.4, 10), (i % 2) * 0.8 - 0.4), i * 0.045) for i, f in enumerate(notes)]
    chord = sum(_bell(f, 1.4, 2.6) for f in [523.3, 659.3, 784.0, 1046.5]) * 0.3
    swell = sweep_lp(sum(saw(f, 1.2) + saw(f * 1.006, 1.2) for f in [261.6, 392.0]) * 0.18, 400, 5000, 8) * adsr(1.2, 0.3, 0.3, 0.7, 0.5)
    sub = sine(glide(80, 160, 0.5, 0.7)) * decay(0.5, 5, 0.03) * 0.5
    save("synergy", reverb(mix(*layers, at(widen(chord, 12, 0.7), 0.3), widen(swell, 14, 0.7), sub), 1.4, 0.32), 0.88, 0.1)


SFX = [
    sfx_shoot, sfx_shoot_enemy, sfx_shoot_sniper, sfx_hit, sfx_crit, sfx_explode, sfx_explode_big,
    sfx_hurt, sfx_dash, sfx_pickup_heal, sfx_pickup_power, sfx_shield_up, sfx_shield_break,
    sfx_nova, sfx_nova_ready, sfx_level_up, sfx_card_pick, sfx_ui_click, sfx_ui_hover, sfx_ui_back,
    sfx_ui_toggle, sfx_wave_start, sfx_wave_clear, sfx_boss_warn, sfx_boss_phase, sfx_boss_die,
    sfx_game_over, sfx_combo, sfx_low_hp, sfx_elite, sfx_revive, sfx_spawn, sfx_chain,
    sfx_bomb_beep, sfx_deny,
    sfx_purchase, sfx_shoot_scatter, sfx_shoot_rail, sfx_shoot_rocket, sfx_slam, sfx_leap, sfx_teleport,
    sfx_laser_charge, sfx_laser, sfx_synergy,
]


# --------------------------------------------------------------------------- müzik
NOTE = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}


def hz(name):
    """'A2', 'C#4' → frekans."""
    pitch, octave = name[:-1], int(name[-1])
    return 440.0 * 2 ** ((NOTE[pitch] - 9) / 12.0 + (octave - 4))


class Track:
    """Döngüsel parça: taşan kuyruklar başa sarılır, böylece döngü dikişsiz olur."""

    def __init__(self, bpm, bars):
        self.bpm = bpm
        self.beat = 60.0 / bpm
        self.bar = self.beat * 4.0
        self.length = n_of(self.bar * bars)
        self.bars = bars
        self.layers = {}

    def layer(self, name):
        if name not in self.layers:
            self.layers[name] = np.zeros((self.length * 2, 2))
        return self.layers[name]

    def add(self, name, time, sound, gain=1.0, pan=0.0):
        buf = self.layer(name)
        s = stereo(sound, pan) * gain
        start = int(round(time * SR)) % self.length
        end = min(len(buf), start + len(s))
        buf[start:end] += s[: end - start]

    def fold(self, x):
        x = pad_to(x, self.length)
        out = x[: self.length].copy()
        rest = x[self.length:]
        while len(rest) > 0:
            part = rest[: self.length]
            out[: len(part)] += part
            rest = rest[self.length:]
        return out

    def get(self, name):
        return self.fold(self.layers[name])


def kick(punch=1.0):
    d = 0.32
    body = sine(glide(165, 44, d, 2.6)) * decay(d, 13, 0.001)
    click = hp(noise(0.006), 2000) * decay(0.006, 500, 0.0002) * 0.35
    return drive(pad_to(body, n_of(d)) * punch + pad_to(click, n_of(d)), 1.5)


def snare():
    d = 0.24
    nz = bp(noise(d), 900, 7500) * decay(d, 21, 0.0006)
    tone = sine(glide(240, 170, d)) * decay(d, 30, 0.0006) * 0.6
    return nz * 0.9 + tone


def clap():
    d = 0.22
    x = np.zeros(n_of(d))
    for off in [0.0, 0.011, 0.023]:
        b = bp(noise(0.05), 1100, 6000) * decay(0.05, 70, 0.0004)
        s = n_of(off)
        x[s: s + len(b)] += b
    tail = bp(noise(d), 1200, 5000) * decay(d, 22, 0.02) * 0.5
    return x + tail


def hat(open_=False):
    d = 0.22 if open_ else 0.045
    return hp(noise(d), 7500, 3) * decay(d, 16 if open_ else 95, 0.0004)


def tom(f):
    d = 0.3
    return sine(glide(f * 1.6, f, d, 2.0)) * decay(d, 11, 0.001)


def bass_note(freq, d, bright=900.0, drive_amt=1.6):
    x = saw(freq, d) * 0.6 + square(freq, d, 0.5) * 0.3 + sine(freq * 0.5, d) * 0.5
    x = sweep_lp(x, bright * 2.4, bright * 0.5, 6) * adsr(d, 0.004, d * 0.5, 0.55, min(0.03, d * 0.2))
    return drive(x, drive_amt)


def pluck_note(freq, d, bright=5000.0):
    x = saw(freq, d) * 0.5 + saw(freq * 1.006, d) * 0.4 + square(freq * 2.0, d, 0.3) * 0.12
    return sweep_lp(x, bright, 700, 6) * decay(d, 8.5, 0.002)


def pad_chord(freqs, d, bright=1500.0):
    x = np.zeros(n_of(d))
    for f in freqs:
        for det in (0.994, 1.0, 1.007):
            x += saw(f * det, d)
    x = lp(x, bright, 2) * adsr(d, d * 0.22, d * 0.2, 0.8, d * 0.3) / (len(freqs) * 2.0)
    lfo = 0.85 + 0.15 * np.sin(2 * np.pi * 0.31 * tt(d))
    return widen(x * lfo, 14, 0.7)


def lead_note(freq, d, bright=4200.0):
    t = tt(d)
    vib = 1.0 + 0.006 * np.sin(2 * np.pi * 5.4 * t) * np.clip(t / 0.18, 0.0, 1.0)
    f = freq * vib
    x = saw(f) * 0.5 + square(f, duty=0.38) * 0.35 + sine(f * 2.0) * 0.15
    return lp(x, bright, 2) * adsr(d, 0.012, 0.09, 0.72, min(0.08, d * 0.3))


def sidechain(track, amount=0.6, rate=9.0, every=1.0):
    t = np.arange(track.length) / SR
    since = t % (track.beat * every)
    return 1.0 - amount * np.exp(-since * rate)


def finish(name, track, parts, peak=0.84):
    total = np.zeros((track.length, 2))
    for p in parts:
        total += p
    total = hp(total, 28, 2)
    total = np.tanh(total * 1.15) / np.tanh(1.15)
    top = np.max(np.abs(total)) + 1e-9
    total *= peak / top
    data = (np.clip(total, -1.0, 1.0) * 32767.0).astype("<i2")
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print("%-16s %6.2fs  rms %.3f  %7.1f KB  (döngü)" % (name, track.length / SR, np.sqrt(np.mean(total ** 2)), data.nbytes / 1024))


def music_battle():
    """128 BPM synthwave: Am – F – C – G, 32 bar (60 sn)."""
    tr = Track(128, 32)
    beat, bar = tr.beat, tr.bar
    s16 = beat / 4.0
    prog = [
        ("A1", ["A3", "C4", "E4"], ["A4", "C5", "E5", "A5"]),
        ("F1", ["F3", "A3", "C4"], ["F4", "A4", "C5", "F5"]),
        ("C2", ["G3", "C4", "E4"], ["G4", "C5", "E5", "G5"]),
        ("G1", ["G3", "B3", "D4"], ["G4", "B4", "D5", "G5"]),
    ]
    k, sn, cl, hc, ho = kick(), snare(), clap(), hat(), hat(True)
    for b in range(32):
        t0 = b * bar
        root, chord, arp = prog[(b // 2) % 4]
        intro = b < 4
        breakdown = 16 <= b < 20
        full = not intro and not breakdown
        # Davul
        for q in range(4):
            if not breakdown:
                tr.add("kick", t0 + q * beat, k, 1.0)
            if q in (1, 3) and not intro:
                tr.add("drums", t0 + q * beat, sn, 0.5 if not breakdown else 0.0)
                tr.add("drums", t0 + q * beat, cl, 0.42)
        for s in range(16):
            if intro and s % 2 == 1:
                continue
            vel = 0.2 if s % 4 == 2 else (0.11 if s % 2 == 0 else 0.07)
            if s % 4 == 2 and full:
                tr.add("hats", t0 + s * s16, ho, 0.12, 0.3)
            else:
                tr.add("hats", t0 + s * s16, hc, vel, -0.25 if s % 2 else 0.25)
        if b % 8 == 7:
            for i, f in enumerate([180, 150, 120, 95]):
                tr.add("drums", t0 + bar - (4 - i) * beat * 0.25, tom(f), 0.5, (i - 1.5) * 0.4)
        # Bas: 16'lık oktav sekmeli
        f_root = hz(root)
        for s in range(16):
            if breakdown and s % 4 != 0:
                continue
            octave = 2.0 if s % 4 == 2 or (s % 8 == 7) else 1.0
            if b % 2 == 1 and s >= 14:
                octave = 1.5
            tr.add("bass", t0 + s * s16, bass_note(f_root * octave, s16 * (0.9 if not breakdown else 3.6), 700 if not breakdown else 420), 0.5)
        # Arpej
        order = [0, 1, 2, 3, 2, 1, 2, 3, 0, 2, 1, 3, 2, 1, 3, 2] if (b // 4) % 2 == 0 else [0, 2, 1, 3, 0, 2, 3, 1, 0, 2, 1, 3, 3, 2, 1, 0]
        if not intro or b >= 2:
            for s in range(16):
                f = hz(arp[order[s]])
                bright = 2600 + 2400 * np.sin(np.pi * (b % 8 + s / 16.0) / 8.0) ** 2
                tr.add("arp", t0 + s * s16, pluck_note(f, s16 * 1.8, bright), 0.19 if full else 0.13, 0.45 if s % 2 else -0.45)
        # Pad
        if b % 2 == 0:
            tr.add("pad", t0, pad_chord([hz(n) for n in chord], bar * 2.0, 1300 if full else 900), 0.34)
    # Lead (ikinci yarı)
    melody = [
        (20, 0.0, "E5", 1.5), (20, 1.5, "D5", 0.5), (20, 2.0, "C5", 1.0), (20, 3.0, "E5", 1.0),
        (21, 0.0, "A5", 2.0), (21, 2.5, "G5", 0.5), (21, 3.0, "E5", 1.0),
        (22, 0.0, "F5", 1.5), (22, 1.5, "E5", 0.5), (22, 2.0, "C5", 1.0), (22, 3.0, "A4", 1.0),
        (23, 0.0, "C5", 3.0), (23, 3.0, "D5", 1.0),
        (24, 0.0, "E5", 1.5), (24, 1.5, "G5", 0.5), (24, 2.0, "E5", 1.0), (24, 3.0, "C5", 1.0),
        (25, 0.0, "G5", 2.0), (25, 2.0, "E5", 1.0), (25, 3.0, "G5", 1.0),
        (26, 0.0, "B5", 1.5), (26, 1.5, "A5", 0.5), (26, 2.0, "G5", 1.0), (26, 3.0, "D5", 1.0),
        (27, 0.0, "G5", 2.5), (27, 3.0, "B5", 1.0),
        (28, 0.0, "C6", 1.5), (28, 1.5, "B5", 0.5), (28, 2.0, "A5", 1.0), (28, 3.0, "E5", 1.0),
        (29, 0.0, "A5", 3.0), (29, 3.0, "G5", 1.0),
        (30, 0.0, "F5", 1.0), (30, 1.0, "A5", 1.0), (30, 2.0, "C6", 1.0), (30, 3.0, "A5", 1.0),
        (31, 0.0, "E5", 3.5),
        (8, 0.0, "A4", 1.0), (8, 1.5, "C5", 0.5), (8, 2.0, "E5", 2.0),
        (10, 0.0, "A4", 1.0), (10, 1.5, "C5", 0.5), (10, 2.0, "F5", 2.0),
        (12, 0.0, "G4", 1.0), (12, 1.5, "C5", 0.5), (12, 2.0, "E5", 2.0),
        (14, 0.0, "G4", 1.0), (14, 1.5, "B4", 0.5), (14, 2.0, "D5", 1.5), (14, 3.5, "E5", 0.5),
    ]
    for b, q, name, length in melody:
        tr.add("lead", b * bar + q * beat, lead_note(hz(name), length * beat * 0.96), 0.21 if b >= 20 else 0.13)
    # Geçiş süpürmeleri
    for b in (3, 15, 19, 31):
        d = bar
        ramp = np.linspace(0.0, 1.0, n_of(d)) ** 2.4
        tr.add("fx", b * bar, widen(hp(sweep_lp(noise(d), 700, 11000, 8), 500) * ramp, 9, 0.6), 0.2)
    for b in (4, 20):
        body, crack = _boom(1.2, 110, 34, 5000, 3.5)
        tr.add("fx", b * bar, mix(widen(body, 12, 0.6), crack), 0.4)
    sc = sidechain(tr, 0.55, 8.5)[:, None]
    sc_soft = sidechain(tr, 0.3, 8.5)[:, None]
    parts = [
        tr.get("kick") * 0.78,
        tr.fold(reverb(tr.layers["drums"], 0.5, 0.16, 4500)) * 0.8,
        tr.get("hats") * 0.85,
        lp(tr.get("bass"), 3200, 2) * sc * 0.95,
        tr.fold(echo(tr.layers["arp"], beat * 0.75, 0.42, 0.3, 4)) * sc_soft,
        tr.fold(reverb(tr.layers["pad"], 1.6, 0.3, 3800)) * sc * 0.9,
        tr.fold(reverb(echo(tr.layers["lead"], beat * 0.75, 0.38, 0.28, 4), 1.2, 0.22, 4500)) * sc_soft,
        tr.fold(reverb(tr.layers["fx"], 1.0, 0.25, 4000)),
    ]
    finish("music_battle", tr, parts)


def music_boss():
    """140 BPM, karanlık: E frigyen (E – F – G – F), 16 bar (27 sn)."""
    tr = Track(140, 16)
    beat, bar = tr.beat, tr.bar
    s16 = beat / 4.0
    roots = ["E1", "E1", "F1", "E1", "E1", "E1", "G1", "F1"]
    k, sn, cl, hc, ho = kick(1.15), snare(), clap(), hat(), hat(True)
    riff = [0, 0, 12, 0, 0, 13, 0, 12, 0, 0, 15, 0, 13, 12, 0, 10]
    for b in range(16):
        t0 = b * bar
        root = hz(roots[b % 8])
        for q in range(4):
            tr.add("kick", t0 + q * beat, k, 1.0)
            if q in (1, 3):
                tr.add("drums", t0 + q * beat, sn, 0.62)
                tr.add("drums", t0 + q * beat, cl, 0.36)
        if b % 2 == 1:
            tr.add("kick", t0 + 3.5 * beat, k, 0.8)
            tr.add("kick", t0 + 3.75 * beat, k, 0.7)
        for s in range(16):
            tr.add("hats", t0 + s * s16, ho if s % 4 == 2 else hc, 0.13 if s % 4 == 2 else (0.13 if s % 2 == 0 else 0.08), 0.3 if s % 2 else -0.3)
        if b % 4 == 3:
            for i, f in enumerate([200, 170, 140, 110, 90, 75]):
                tr.add("drums", t0 + bar - (6 - i) * s16, tom(f), 0.55, (i - 2.5) * 0.3)
        for s in range(16):
            semis = riff[s]
            f = root * 2 ** (semis / 12.0)
            tr.add("bass", t0 + s * s16, bass_note(f, s16 * 0.92, 1000, 2.6), 0.5)
        # Sert vuruşlu akor bıçakları
        if b % 2 == 0:
            stab_f = [root * 4, root * 4 * 2 ** (7 / 12.0), root * 8]
            for q in (0.0, 1.5, 3.0):
                d = beat * 0.45
                x = sum(saw(f, d) + saw(f * 1.01, d) for f in stab_f) * 0.2
                x = sweep_lp(x, 5200, 900, 6) * decay(d, 9, 0.002)
                tr.add("stab", t0 + q * beat, widen(drive(x, 2.0), 10, 0.6), 0.34)
        # Hızlı arpej (üst katman)
        scale = [0, 1, 3, 5, 7, 8, 10, 12]
        if b >= 4:
            for s in range(16):
                step = scale[(s * 3 + b) % 8]
                f = hz("E4") * 2 ** (step / 12.0) * (2.0 if (s % 8) >= 6 else 1.0)
                tr.add("arp", t0 + s * s16, pluck_note(f, s16 * 1.5, 4200), 0.15, 0.5 if s % 2 else -0.5)
        # Alarm benzeri lead
        if b >= 8 and b % 2 == 0:
            for q, name, ln in [(0.0, "E5", 1.0), (1.0, "F5", 1.0), (2.0, "E5", 0.5), (2.5, "D5", 0.5), (3.0, "B4", 1.0)]:
                tr.add("lead", t0 + q * beat, lead_note(hz(name), ln * beat * 0.95, 3600), 0.2)
        if b >= 8 and b % 2 == 1:
            for q, name, ln in [(0.0, "G5", 1.5), (1.5, "F5", 0.5), (2.0, "E5", 2.0)]:
                tr.add("lead", t0 + q * beat, lead_note(hz(name), ln * beat * 0.95, 3600), 0.2)
        if b % 4 == 0:
            d = bar * 4.0
            x = lp(saw(root, d) + saw(root * 1.005, d) + saw(root * 2.0 * 1.003, d), 260, 2) * adsr(d, 0.4, 0.5, 0.8, 0.6)
            tr.add("drone", t0, widen(x, 15, 0.6), 0.3)
    for b in (7, 15):
        d = bar
        ramp = np.linspace(0.0, 1.0, n_of(d)) ** 2.2
        tr.add("fx", b * bar, widen(hp(sweep_lp(noise(d), 600, 11000, 8), 500) * ramp, 9, 0.6), 0.22)
    sc = sidechain(tr, 0.55, 9.5)[:, None]
    sc_soft = sidechain(tr, 0.3, 9.5)[:, None]
    parts = [
        tr.get("kick") * 0.8,
        tr.fold(reverb(tr.layers["drums"], 0.45, 0.16, 4500)) * 0.85,
        tr.get("hats") * 0.85,
        lp(tr.get("bass"), 3800, 2) * sc,
        tr.fold(reverb(tr.layers["stab"], 0.7, 0.22, 4200)) * sc_soft,
        tr.fold(echo(tr.layers["arp"], beat * 0.75, 0.4, 0.3, 4)) * sc_soft,
        tr.fold(reverb(echo(tr.layers["lead"], beat * 0.5, 0.35, 0.25, 3), 1.0, 0.2, 4200)) * sc_soft,
        tr.get("drone") * sc,
        tr.fold(reverb(tr.layers["fx"], 1.0, 0.25, 4000)),
    ]
    finish("music_boss", tr, parts)


def music_menu():
    """84 BPM, sakin: Am9 – Fmaj7 – Cmaj7 – Em7, 12 bar (34 sn)."""
    tr = Track(84, 12)
    beat, bar = tr.beat, tr.bar
    s8 = beat / 2.0
    prog = [
        ("A1", ["A3", "C4", "E4", "B4"], ["A4", "B4", "C5", "E5", "G5"]),
        ("F1", ["F3", "A3", "C4", "E4"], ["F4", "A4", "C5", "E5", "A5"]),
        ("C2", ["E3", "G3", "B3", "C4"], ["G4", "B4", "C5", "E5", "G5"]),
        ("E1", ["E3", "G3", "B3", "D4"], ["E4", "G4", "B4", "D5", "E5"]),
    ]
    hc = hat()
    k = kick(0.8)
    for b in range(12):
        t0 = b * bar
        root, chord, arp = prog[b % 4]
        tr.add("pad", t0, pad_chord([hz(n) for n in chord], bar * 1.15, 1500), 0.5)
        d = bar * 0.98
        sub = (sine(hz(root) * 2, d) * 0.7 + sine(hz(root), d) * 0.5 + tri(hz(root) * 2, d) * 0.15) * adsr(d, 0.05, 0.4, 0.7, 0.4)
        tr.add("bass", t0, sub, 0.42)
        pattern = [0, 2, 4, 3, 1, 3, 2, 4] if b % 2 == 0 else [0, 3, 2, 4, 1, 2, 3, 1]
        for s in range(8):
            if b < 1 and s < 4:
                continue
            f = hz(arp[pattern[s]]) * (2.0 if (b >= 4 and s in (3, 7)) else 1.0)
            tr.add("arp", t0 + s * s8, _bell(f, s8 * 3.0, 5.5) * 0.6 + pad_to(pluck_note(f, s8 * 2.0, 3200), n_of(s8 * 3.0)) * 0.5, 0.2, 0.5 if s % 2 else -0.5)
        if b >= 4:
            tr.add("kick", t0, k, 0.6)
            tr.add("kick", t0 + 2.5 * beat, k, 0.42)
            for s in range(8):
                tr.add("hats", t0 + s * s8 + (s8 * 0.5 if s % 2 else 0.0) * 0.0, hc, 0.07 if s % 2 else 0.04, 0.4 if s % 2 else -0.4)
    melody = [(4, 0.0, "E5", 3.0), (5, 0.0, "C5", 2.0), (5, 2.0, "A4", 2.0), (6, 0.0, "B4", 3.0), (6, 3.0, "G4", 1.0), (7, 0.0, "B4", 4.0),
              (8, 0.0, "A5", 3.0), (8, 3.0, "G5", 1.0), (9, 0.0, "E5", 4.0), (10, 0.0, "G5", 2.0), (10, 2.0, "E5", 2.0), (11, 0.0, "D5", 3.5)]
    for b, q, name, length in melody:
        d = length * beat
        x = (sine(hz(name), d) + 0.3 * sine(hz(name) * 2, d) + 0.25 * tri(hz(name), d)) * adsr(d, 0.08, 0.3, 0.7, min(0.5, d * 0.4))
        x *= 1.0 + 0.06 * np.sin(2 * np.pi * 4.6 * tt(d))
        tr.add("lead", b * bar + q * beat, x, 0.16)
    sc = sidechain(tr, 0.18, 6.0, 4.0)[:, None]
    parts = [
        tr.get("kick") * 0.6,
        tr.get("hats") * 0.8,
        lp(tr.get("bass"), 900, 2) * 0.9,
        tr.fold(reverb(tr.layers["pad"], 2.4, 0.4, 3600)) * sc,
        tr.fold(reverb(echo(tr.layers["arp"], beat * 0.75, 0.5, 0.42, 5), 2.0, 0.35, 5000)),
        tr.fold(reverb(echo(tr.layers["lead"], beat * 1.5, 0.4, 0.3, 3), 2.4, 0.4, 4200)),
    ]
    finish("music_menu", tr, parts, 0.8)


MUSIC = [music_menu, music_battle, music_boss]


def main():
    what = sys.argv[1] if len(sys.argv) > 1 else "all"
    only = set(sys.argv[2].split(",")) if len(sys.argv) > 2 else None
    if what in ("all", "sfx"):
        for fn in SFX:
            if only is None or fn.__name__.replace("sfx_", "") in only:
                fn()
    if what in ("all", "music"):
        for fn in MUSIC:
            fn()


if __name__ == "__main__":
    main()
