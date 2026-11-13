#!/usr/bin/env python3
"""ASMR ses seti (yerel sentez, ağ/API yok; yalnızca numpy).

    python3 tools/make_asmr_sfx.py            # sesleri üretir + data/sounds.json'u günceller
    python3 tools/make_asmr_sfx.py --report   # ayrıca ölçüm tablosu + docs/art/sfx_spectrograms.png

Üretilen sesler (assets/audio/sfx/*.wav, 44.1 kHz mono 16-bit):
  pin_click_1..3 (+ pin_click = 1. varyant), cloth_1..3 (+ cloth), fold_puff, note, wring,
  unlock, wind, win, basket_slide, sparkle ve döngülü garden_ambience.

Teknik (neden): tek bir gürültü patlaması "ucuz" duyulur. Burada
  - ahşap/zil gibi cisimler sönümlü modal kısmi tonlarla (eş harmonik olmayan oranlar),
  - kumaş/rüzgâr bantlı gürültü taneciklerinin (granular) hareketli süzgeciyle,
  - hepsi çok hafif bir oda yankısıyla (erken yansımalar + küçük comb/allpass ağı) üretilir.
Mastering: 60 Hz alçak kesim, ~7 kHz üstü yumuşak düşüş, kısa fade, etkin-RMS eşitleme, tepe sınırı.
success.wav ve ui_tap.wav bu betiğin dışındadır; sounds.json'daki kayıtları korunur.
"""
import json
import os
import sys
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SFX_DIR = os.path.join(ROOT, "assets", "audio", "sfx")
SOUNDS_PATH = os.path.join(ROOT, "data", "sounds.json")
SPECTROGRAM_PATH = os.path.join(ROOT, "docs", "art", "sfx_spectrograms.png")
RATE = 44100
PEAK_CEILING = 0.85          # Tepe tavanı (~ -1.4 dBFS): kırpılma yok.
TARGET_RMS_DB = -23.0        # Etkin-RMS hedefi; efektler arası algısal denge.
LOW_CUT_HZ = 60.0
HIGH_ROLLOFF_HZ = 7000.0     # 8 kHz üstü sert olmasın.
FADE_IN_S = 0.002
FADE_OUT_S = 0.03
SILENCE_DB = -48.0           # Kuyruk kırpma eşiği.
AMBIENCE_SECONDS = 24.0      # Tam sayı: tüm LFO'lar periyotta tam tur atar -> dikişsiz döngü.
AMBIENCE_RMS_DB = -36.0      # Ambiyans "çok sessiz" tasarlandı.


def hash_text(text):
    # Python hash() süreçler arası rastgeledir; tekrarlanabilirlik için kararlı FNV özeti.
    value = 2166136261
    for char in text.encode("utf-8"):
        value = ((value ^ char) * 16777619) & 0xFFFFFFFF
    return value


def seeded(name):
    """Her ses kendi tohumundan üretilir; biri değişince diğerleri kaymaz."""
    return np.random.default_rng(hash_text(name))


def t(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def spectrum_filter(signal, gain_fn):
    spectrum = np.fft.rfft(signal)
    freqs = np.fft.rfftfreq(signal.size, 1.0 / RATE)
    return np.fft.irfft(spectrum * gain_fn(np.maximum(freqs, 1.0)), signal.size)


def band(signal, low, high):
    """Yumuşak kenarlı bant geçiren (keskin kesim 'çınlama' yapar)."""
    return spectrum_filter(signal, lambda f: 1.0 / (1.0 + (low / f) ** 4) / (1.0 + (f / high) ** 4))


def lowpass(signal, high):
    return spectrum_filter(signal, lambda f: 1.0 / (1.0 + (f / high) ** 4))


def log_band(signal, centre, octaves):
    """Log-frekans Gauss bandı: tanecik süzgeci; merkez frekans taneciğe göre değişir."""
    return spectrum_filter(signal, lambda f: np.exp(-0.5 * (np.log2(f / centre) / octaves) ** 2))


def noise(rng, seconds, low, high):
    return band(rng.standard_normal(int(RATE * seconds)), low, high)


def adsr(seconds, attack, decay_rate):
    x = t(seconds)
    return np.minimum(x / max(attack, 1e-4), 1.0) * np.exp(-decay_rate * x)


def place(base, signal, start):
    index = int(RATE * start)
    if index >= base.size:
        return base
    end = min(base.size, index + signal.size)
    base[index:end] += signal[:end - index]
    return base


def modes(freqs, amps, decays, seconds, attack=0.0008, drift=0.0):
    """Sönümlü sinüs toplamı (modal sentez). drift: başta hafif perde kayması (doğal his)."""
    x = t(seconds)
    out = np.zeros(x.size)
    for freq, amp, decay in zip(freqs, amps, decays):
        inst = freq * (1.0 + drift * np.exp(-x * 25.0))
        phase = 2 * np.pi * np.cumsum(inst) / RATE
        out += amp * np.sin(phase) * np.exp(-decay * x)
    return out * np.minimum(x / max(attack, 1e-5), 1.0)


def burst(rng, seconds, low, high, decay_rate, attack=0.0003):
    return noise(rng, seconds, low, high) * adsr(seconds, attack, decay_rate)


def hann(n):
    return 0.5 - 0.5 * np.cos(2 * np.pi * np.arange(n) / max(n - 1, 1))


def grains(rng, seconds, count, centres, octaves, length_range, amp_env):
    """Tanecikli gürültü: her tanecik Hann pencereli, kendi merkezinde bant süzgeçli.

    centres(u): 0..1 zaman oranından merkez frekans; amp_env(u): genel şiddet eğrisi.
    """
    out = np.zeros(int(RATE * seconds))
    for _ in range(count):
        u = rng.uniform(0.0, 1.0)
        n = int(RATE * rng.uniform(*length_range))
        grain = log_band(rng.standard_normal(n), centres(u) * rng.uniform(0.85, 1.18), octaves)
        grain *= hann(n) * amp_env(u) * rng.uniform(0.5, 1.0)
        start = int(u * max(out.size - n, 1))
        out[start:start + n] += grain
    return out


# --- Oda yankısı --------------------------------------------------------------------------

EARLY_TAPS = ((0.011, 0.30), (0.017, -0.22), (0.023, 0.17), (0.031, -0.12), (0.043, 0.08))
COMB_DELAYS = (1051, 1327, 1613, 1867)
COMB_FEEDBACK = 0.5
ALLPASS_DELAYS = (225, 556)
ALLPASS_GAIN = 0.5
REVERB_TAIL_S = 0.3
REVERB_WET = 0.4
WET_LOWPASS_HZ = 4500.0


def comb(x, delay, feedback):
    y = x.copy()
    for i in range(delay, y.size, delay):
        j = min(i + delay, y.size)
        y[i:j] += feedback * y[i - delay:j - delay]
    return y


def allpass(x, delay, gain):
    y = np.zeros_like(x)
    for i in range(0, x.size, delay):
        j = min(i + delay, x.size)
        prev_x = x[i - delay:j - delay] if i >= delay else np.zeros(j - i)
        prev_y = y[i - delay:j - delay] if i >= delay else np.zeros(j - i)
        y[i:j] = -gain * x[i:j] + prev_x + gain * prev_y
    return y


def room(signal, wet=REVERB_WET, tail=REVERB_TAIL_S):
    """Çok hafif küçük oda: erken yansımalar + paralel comb + seri allpass; ıslak kol yumuşatılır."""
    x = np.concatenate([signal, np.zeros(int(RATE * tail))])
    early = np.zeros_like(x)
    for delay_s, gain in EARLY_TAPS:
        place(early, x * gain, delay_s)
    late = sum(comb(x, d, COMB_FEEDBACK) for d in COMB_DELAYS) / len(COMB_DELAYS)
    for d in ALLPASS_DELAYS:
        late = allpass(late, d, ALLPASS_GAIN)
    return x + wet * lowpass(early + late * 0.5, WET_LOWPASS_HZ)


# --- Mastering ----------------------------------------------------------------------------

def active_rms(signal):
    peak = float(np.max(np.abs(signal)))
    active = signal[np.abs(signal) > 0.1 * peak]
    return float(np.sqrt(np.mean(active ** 2))) if active.size else 0.0


def finish(signal, gain_db=0.0, reverb=True):
    """Tek ses için tüm mastering zinciri; 'gain_db' sese özel algısal ayar."""
    x = np.concatenate([signal, np.zeros(int(RATE * 0.05))])
    if reverb:
        x = room(x)
    x = band(x, LOW_CUT_HZ, HIGH_ROLLOFF_HZ)
    floor = 10 ** (SILENCE_DB / 20) * float(np.max(np.abs(x)))
    loud = np.nonzero(np.abs(x) > floor)[0]
    if loud.size:
        x = x[:loud[-1] + 1]
    fade_in = int(RATE * FADE_IN_S)
    fade_out = min(int(RATE * FADE_OUT_S), x.size // 3)
    x[:fade_in] *= np.linspace(0.0, 1.0, fade_in)
    x[-fade_out:] *= np.linspace(1.0, 0.0, fade_out) ** 2
    gain = 10 ** ((TARGET_RMS_DB + gain_db) / 20) / max(active_rms(x), 1e-9)
    gain = min(gain, PEAK_CEILING / max(float(np.max(np.abs(x))), 1e-9))
    return x * gain


# --- Sesler -------------------------------------------------------------------------------

def pin_click(variant):
    """Ahşap mandal: yay vuruşu + ahşap vuruşu + çene kapanma 'tik'i; küçük ahşap parçanın modları."""
    rng = seeded("pin_click_%d" % variant)
    out = np.zeros(int(RATE * 0.22))
    base = rng.uniform(1050, 1450)
    place(out, burst(rng, 0.006, 2200, 6500, 700) * 0.5, 0.0)            # 1) yay
    ratios = (1.0, 2.57, 4.63, 6.9)                                      # 2) ahşap modları
    amps = (1.0, 0.55, 0.28, 0.12)
    decays = (rng.uniform(55, 80), rng.uniform(90, 130), rng.uniform(140, 200), 260.0)
    wood = modes([base * r * rng.uniform(0.99, 1.01) for r in ratios], amps, decays, 0.2, drift=0.01)
    place(wood, burst(rng, 0.004, 700, 4000, 900) * 0.6, 0.0)
    place(out, wood * 0.9, rng.uniform(0.005, 0.009))
    tick = modes([base * 0.78, base * 0.78 * 2.57], (0.6, 0.3), (110, 190), 0.1)  # 3) çene kapanışı
    place(tick, burst(rng, 0.003, 600, 3500, 1000) * 0.4, 0.0)
    place(out, tick * 0.45, rng.uniform(0.024, 0.034))
    return finish(out, gain_db=2.0)


def cloth(variant):
    """Kumaş sürtünmesi: onlarca kısa süzülmüş gürültü tanesi, merkez frekans hareket eder."""
    rng = seeded("cloth_%d" % variant)
    seconds = 0.38 + 0.04 * variant
    start_f, end_f = (900.0, 2600.0) if variant % 2 == 1 else (2400.0, 900.0)
    sig = grains(rng, seconds, 70, lambda u: start_f * (end_f / start_f) ** u, 0.55,
                 (0.012, 0.045), lambda u: np.sin(np.pi * min(max(u, 0.0), 1.0)) ** 1.6)
    sig *= np.minimum(t(seconds) / 0.06, 1.0)  # Yumuşak atak.
    return finish(sig, gain_db=-1.0)


def fold_puff():
    """Kumaşın konması: alçak-orta gövde + hava + çok yumuşak transient."""
    rng = seeded("fold_puff")
    seconds = 0.6
    body = noise(rng, seconds, 90, 900) * adsr(seconds, 0.018, 9.0)
    thump = modes([95.0, 150.0], (1.0, 0.4), (14.0, 22.0), seconds, attack=0.006, drift=-0.25)
    air = noise(rng, seconds, 1800, 6000) * adsr(seconds, 0.03, 12.0)
    return finish(body * 0.9 + thump * 0.8 + air * 0.35, gain_db=1.0)


def note():
    """Sıcak kalimba/mallet: eş harmonik olmayan kısmi tonlar. En tiz kısmi ~2.8 kHz (2x perdede
    ~5.6 kHz) ile sınırlı; böylece 1.0x-2.0x aralığında tizleşip sertleşmez."""
    rng = seeded("note")
    f0 = 523.25
    ratios = (1.0, 2.0, 2.76, 5.4)
    tone = modes([f0 * r for r in ratios], (1.0, 0.32, 0.22, 0.06), (4.2, 7.5, 11.0, 24.0),
                 1.3, attack=0.003, drift=0.006)
    thud = burst(rng, 0.03, 200, 1600, 140, attack=0.002) * 0.25  # Mallet gövde vuruşu.
    tone[:thud.size] += thud
    return finish(tone)


def wring():
    """Islak sıkma: sürtünme tanecikleri + küçük su damlası 'plip'leri (aşağı glissando)."""
    rng = seeded("wring")
    squeeze = grains(rng, 0.55, 90, lambda u: 500.0 + 700.0 * u, 0.7, (0.008, 0.03),
                     lambda u: np.sin(np.pi * u) ** 1.2)
    squeeze *= 0.55 + 0.45 * np.sin(2 * np.pi * 14 * t(0.55) + 0.8)  # Sıkma titreşimi.
    out = np.zeros(int(RATE * 0.9))
    place(out, squeeze * 0.8, 0.0)
    for start in (0.30, 0.47, 0.60, 0.74):
        start += rng.uniform(-0.02, 0.03)
        x = t(0.09)
        freq = rng.uniform(1500, 2400) * (1.0 - 0.28 * (1 - np.exp(-x * 45)))  # Aşağı chirp.
        plip = np.sin(2 * np.pi * np.cumsum(freq) / RATE) * np.exp(-55 * x) * np.minimum(x / 0.002, 1.0)
        place(out, plip * rng.uniform(0.3, 0.55), start)
    return finish(out, gain_db=-1.0)


def bell(freq, seconds, gain=1.0, decay=7.0):
    """Yumuşak çan/çınlama tonu."""
    ratios = (1.0, 2.0, 3.01, 4.2)
    return gain * modes([freq * r for r in ratios], (1.0, 0.25, 0.1, 0.04),
                        (decay, decay * 1.7, decay * 2.6, decay * 4.0), seconds, attack=0.004)


def unlock():
    """Küçük ahşap mandal 'tık' + iki notalı çınlama."""
    rng = seeded("unlock")
    out = np.zeros(int(RATE * 1.3))
    latch = modes([760, 760 * 2.57, 760 * 4.63], (1.0, 0.5, 0.2), (70, 120, 190), 0.15)
    place(latch, burst(rng, 0.004, 700, 4000, 800) * 0.6, 0.0)
    place(out, latch * 0.8, 0.0)
    place(out, burst(rng, 0.03, 1500, 5000, 150, attack=0.004) * 0.2, 0.045)  # Kayma sürtünmesi.
    place(out, bell(784.0, 1.0, 0.55), 0.12)
    place(out, bell(1174.7, 1.1, 0.5), 0.25)
    return finish(out, gain_db=-1.0)


def wind():
    """Fırtına esintisi (kaybetme): 3 bantlı rastgele hamleler, yavaş kabarma ve ince ıslık."""
    rng = seeded("wind")
    seconds = 2.8
    x = t(seconds)
    swell = np.sin(np.pi * np.clip(x / seconds, 0, 1)) ** 2.0
    out = np.zeros(x.size)
    for low, high, amp in ((100, 450, 1.0), (350, 1400, 0.8), (1200, 3600, 0.35)):
        gust = np.abs(lowpass(rng.standard_normal(x.size), 1.8))
        out += noise(rng, seconds, low, high) * (0.35 + 0.65 * gust / gust.max()) * amp
    wander = lowpass(rng.standard_normal(x.size), 1.2)
    whistle_f = 620 + 140 * wander / np.max(np.abs(wander))
    whistle = np.sin(2 * np.pi * np.cumsum(whistle_f) / RATE) * np.abs(lowpass(rng.standard_normal(x.size), 1.0))
    out = out / np.max(np.abs(out)) + 0.12 * whistle / max(np.max(np.abs(whistle)), 1e-9)
    return finish(out * swell)


def win():
    """Yumuşak 5 notalı arpej + parlayan 'shimmer' kuyruğu."""
    rng = seeded("win")
    out = np.zeros(int(RATE * 3.2))
    freqs = (523.25, 659.25, 783.99, 1046.5, 1318.5)
    for index, freq in enumerate(freqs):
        last = index == len(freqs) - 1
        tone = modes([freq, freq * 2.0, freq * 2.76], (1.0, 0.3, 0.15), (3.0, 6.0, 10.0),
                     1.8 if last else 1.0, attack=0.004, drift=0.004)
        place(out, tone * (0.9 if last else 0.7), 0.14 * index)
    x = t(2.4)
    shimmer = np.zeros(x.size)
    for freq in (2093.0, 2637.0, 3136.0, 3951.0):
        det = freq * (1.0 + rng.uniform(-0.003, 0.003))
        trem = 0.6 + 0.4 * np.sin(2 * np.pi * rng.uniform(3, 6) * x + rng.uniform(0, 6))
        shimmer += np.sin(2 * np.pi * det * x) * trem
    shimmer *= np.minimum(x / 0.25, 1.0) * np.exp(-1.7 * x) * 0.05
    place(out, shimmer, 0.45)
    return finish(out)


def basket_slide():
    """Sepet kenarında sürtünme: kaba tanecik dokusu + hareketli yumuşak vızıltı (hasır his)."""
    rng = seeded("basket_slide")
    seconds = 0.55
    swish = grains(rng, seconds, 60, lambda u: 650.0 + 1300.0 * u, 0.6, (0.02, 0.06),
                   lambda u: np.sin(np.pi * u) ** 1.3)
    crackle = grains(rng, seconds, 160, lambda u: 1800.0, 0.8, (0.002, 0.006),
                     lambda u: np.sin(np.pi * u) ** 2.0) * 0.5
    return finish((swish + crackle) * np.minimum(t(seconds) / 0.05, 1.0), gain_db=-2.0)


def sparkle():
    """Çok yumuşak çan tozu: pentatonik tiz 'ping'ler, hızla azalan."""
    rng = seeded("sparkle")
    out = np.zeros(int(RATE * 1.0))
    scale = (2093.0, 2349.0, 2637.0, 3136.0, 3520.0, 4186.0)
    for _ in range(8):
        freq = scale[rng.integers(len(scale))]
        ping = modes([freq, freq * 2.76], (1.0, 0.2), (rng.uniform(14, 24), 40.0), 0.7, attack=0.002)
        place(out, ping * rng.uniform(0.2, 0.5), rng.uniform(0.0, 0.45))
    return finish(out, gain_db=-4.0)


# --- Ambiyans -----------------------------------------------------------------------------

def fold_tail(buffer, length):
    """Sondan taşan kuyruğu başa ekler -> olaylar döngü sınırında dikişsiz sürer."""
    out = buffer[:length].copy()
    over = buffer[length:]
    out[:over.size] += over
    return out


def chirp(rng, kind):
    """Basit FM kuş cıvıltısı. Üç tür: yükselen ıslık, tril, alçalan titreşimli."""
    if kind == 1:  # Tril: birkaç kısa, hafif eğimli vuruş.
        pulse = 0.05
        out = np.zeros(int(RATE * 0.42))
        base = rng.uniform(3300, 4200)
        for k in range(int(rng.integers(3, 6))):
            x = t(pulse)
            freq = base * (1.0 + 0.12 * k) * (1.0 + 0.1 * np.sin(np.pi * x / pulse))
            place(out, np.sin(2 * np.pi * np.cumsum(freq) / RATE) * np.sin(np.pi * x / pulse) ** 2, 0.075 * k)
        return out * 0.7
    if kind == 0:
        dur = rng.uniform(0.11, 0.17)
        x = t(dur)
        freq = np.linspace(rng.uniform(2600, 3100), rng.uniform(3700, 4300), x.size)
        mod_ratio, index = 1.0, 0.8
    else:
        dur = rng.uniform(0.2, 0.3)
        x = t(dur)
        freq = np.linspace(rng.uniform(4000, 4600), rng.uniform(2700, 3200), x.size)
        freq = freq * (1.0 + 0.04 * np.sin(2 * np.pi * 28 * x))
        mod_ratio, index = 2.0, 1.2
    carrier = 2 * np.pi * np.cumsum(freq) / RATE
    tone = np.sin(carrier + index * np.sin(mod_ratio * carrier)) + 0.25 * np.sin(2 * carrier)
    return tone * np.sin(np.pi * x / dur) ** 1.5


def garden_ambience():
    """Dikişsiz döngü: hafif esinti yatağı + seyrek, uzak kuş sesleri + ara sıra yaprak hışırtısı.

    Dikişsizlik yapıyla sağlanır: yatak dairesel FFT süzgeciyle, LFO'lar periyotta tam tur atarak,
    kuş/yaprak kuyrukları başa katlanarak üretilir. Bu yüzden sonu başına çapraz geçişsiz de tıksız bağlanır."""
    rng = seeded("garden_ambience")
    length = int(RATE * AMBIENCE_SECONDS)
    x = np.arange(length) / RATE
    low = band(rng.standard_normal(length), 110, 1100)
    high = band(rng.standard_normal(length), 1200, 3800)
    cycles = AMBIENCE_SECONDS
    mod_low = 0.65 + 0.2 * np.sin(2 * np.pi * 3 / cycles * x + 1.0) + 0.15 * np.sin(2 * np.pi * 7 / cycles * x + 2.3)
    mod_high = 0.5 + 0.35 * np.sin(2 * np.pi * 5 / cycles * x + 0.4) + 0.15 * np.sin(2 * np.pi * 11 / cycles * x)
    breeze = low / low.std() * mod_low + 0.18 * high / high.std() * np.maximum(mod_high, 0.0) ** 2

    pad = int(RATE * 2.5)
    birds = np.zeros(length + pad)
    for slot in range(9):  # Seyrek: ~2.7 sn'de bir, aralıklı rastgele yerleşim.
        start = (slot + rng.uniform(0.1, 0.9)) * AMBIENCE_SECONDS / 9
        kind = int(rng.integers(3))
        call = chirp(rng, kind) * rng.uniform(0.5, 1.0)
        if kind != 1 and rng.random() < 0.6:  # Bazen kısa bir cevap.
            call = np.concatenate([call, np.zeros(int(RATE * 0.12)), call * 0.7])
        place(birds, call, start)
    birds = lowpass(birds, 4800.0)                                    # Uzak: tizler yutulur.
    birds = room(birds, wet=0.9, tail=0.6)[:length + pad]
    leaves = np.zeros(length + pad)
    for _ in range(5):
        dur = rng.uniform(0.25, 0.5)
        rustle = grains(rng, dur, 40, lambda u: 3200.0, 0.7, (0.004, 0.015),
                        lambda u: np.sin(np.pi * u) ** 2) * rng.uniform(0.5, 1.0)
        place(leaves, rustle, rng.uniform(0, AMBIENCE_SECONDS))
    bird_layer = fold_tail(birds, length)
    leaf_layer = fold_tail(leaves, length)
    mix = breeze / np.max(np.abs(breeze)) \
        + bird_layer / max(np.max(np.abs(bird_layer)), 1e-9) * 0.30 \
        + leaf_layer / max(np.max(np.abs(leaf_layer)), 1e-9) * 0.12
    mix = band(mix, LOW_CUT_HZ, HIGH_ROLLOFF_HZ)  # Dairesel FFT: dikişi bozmaz.
    gain = 10 ** (AMBIENCE_RMS_DB / 20) / float(np.sqrt(np.mean(mix ** 2)))
    return mix * min(gain, PEAK_CEILING / float(np.max(np.abs(mix))))


# --- Yazma / ölçüm ------------------------------------------------------------------------

def write_wav(name, signal):
    path = os.path.join(SFX_DIR, name + ".wav")
    # TPDF dither: 16-bit niceleme gürültüsünü düzleştirir (sessiz kuyruklarda tıkırtı olmaz).
    dither_rng = np.random.default_rng(1)
    dither = (dither_rng.random(signal.size) - dither_rng.random(signal.size)) / 32768.0
    data = np.clip(signal + dither, -1.0, 1.0)
    with wave.open(path, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes((data * 32767).astype("<i2").tobytes())


def measure(signal):
    spectrum = np.abs(np.fft.rfft(signal))
    freqs = np.fft.rfftfreq(signal.size, 1.0 / RATE)
    return {
        "duration": signal.size / RATE,
        "peak": 20 * np.log10(max(float(np.max(np.abs(signal))), 1e-9)),
        "rms": 20 * np.log10(max(float(np.sqrt(np.mean(signal ** 2))), 1e-9)),
        "active": 20 * np.log10(max(active_rms(signal), 1e-9)),
        "centroid": float(np.sum(freqs * spectrum) / max(np.sum(spectrum), 1e-12)),
        "hi": 100.0 * float(np.sum(spectrum[freqs > 8000] ** 2) / max(np.sum(spectrum ** 2), 1e-12)),
    }


def build():
    sounds = {}
    for variant in (1, 2, 3):
        sounds["pin_click_%d" % variant] = pin_click(variant)
        sounds["cloth_%d" % variant] = cloth(variant)
    sounds["pin_click"] = sounds["pin_click_1"]
    sounds["cloth"] = sounds["cloth_1"]
    sounds["fold_puff"] = fold_puff()
    sounds["note"] = note()
    sounds["wring"] = wring()
    sounds["unlock"] = unlock()
    sounds["wind"] = wind()
    sounds["win"] = win()
    sounds["basket_slide"] = basket_slide()
    sounds["sparkle"] = sparkle()
    sounds["garden_ambience"] = garden_ambience()
    return sounds


def report(sounds):
    print("%-16s %6s %7s %7s %8s %9s %6s" % ("ses", "sn", "tepe", "RMS", "etkinRMS", "centroid", ">8k%"))
    for name, signal in sounds.items():
        m = measure(signal)
        print("%-16s %6.2f %7.1f %7.1f %8.1f %9.0f %6.2f" % (
            name, m["duration"], m["peak"], m["rms"], m["active"], m["centroid"], m["hi"]))
    amb = sounds["garden_ambience"]
    step = np.abs(np.diff(amb))
    print("ambiyans: |x[0]-x[-1]| = %.6f ; tipik adım (RMS) = %.6f ; en büyük adım = %.6f" % (
        abs(amb[0] - amb[-1]), float(np.sqrt(np.mean(step ** 2))), float(step.max())))
    seam = np.abs(np.diff(np.concatenate([amb[-4:], amb[:4]])))
    print("ambiyans dikiş adımı (son->ilk örnek) = %.6f" % float(seam.max()))


def plot(sounds):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    names = list(sounds)
    cols = 4
    rows = (len(names) + cols - 1) // cols
    fig, axes = plt.subplots(rows, cols, figsize=(16, 2.6 * rows))
    for ax, name in zip(axes.flat, names):
        ax.specgram(sounds[name], NFFT=1024, Fs=RATE, noverlap=768, cmap="magma", vmin=-130, vmax=-30)
        ax.set_ylim(0, 10000)
        ax.set_title(name, fontsize=9)
    for ax in list(axes.flat)[len(names):]:
        ax.axis("off")
    fig.tight_layout()
    os.makedirs(os.path.dirname(SPECTROGRAM_PATH), exist_ok=True)
    fig.savefig(SPECTROGRAM_PATH, dpi=70)


def main():
    os.makedirs(SFX_DIR, exist_ok=True)
    table = json.load(open(SOUNDS_PATH, encoding="utf-8")) if os.path.exists(SOUNDS_PATH) else {}
    sounds = build()
    for name, signal in sounds.items():
        write_wav(name, signal)
        table[name] = "res://assets/audio/sfx/%s.wav" % name
        print("yazıldı:", name)
    with open(SOUNDS_PATH, "w", encoding="utf-8") as handle:
        json.dump(dict(sorted(table.items())), handle, indent=2)
    if "--report" in sys.argv:
        report(sounds)
        plot(sounds)


if __name__ == "__main__":
    main()
