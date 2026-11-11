#!/usr/bin/env python3
"""Ses efektlerini üretir: ElevenLabs API -> WAV, anahtar yoksa yedek sentez.

Kullanım:
    python3 tools/make_sfx.py                 # eksik olanları üretir
    python3 tools/make_sfx.py --force         # hepsini yeniden üretir
    python3 tools/make_sfx.py --offline       # API'yi atlar, yedeği üretir
    python3 tools/make_sfx.py ui_tap success  # yalnızca bu adlar
    python3 tools/make_sfx.py --normalize     # var olanları tepe-normalize eder

Tarifler `data/sfx_recipes.json`:
    {
      "ui_tap": {"prompt": "...", "seconds": 0.4, "synth": "blip", "freq": 880}
    }

Yedek sentez tipleri (v0.2 ASMR — anahtar yoksa deterministik üretim):
    blip, thud, crackle, chime, whoosh, clack, pop, buzz, hum,
    friction (kumaş/ahşap sürtünme), hum_loop (dikişsiz uğultu),
    pad_loop (dikişsiz sıcak pad)

Loop'lar `crossfade_loop` ile dikişsiz kılınır: kuyruk, başa eşit güç eğrisiyle
karıştırılır; dosya başı/sonu arasında tık oluşmaz.

Üretilen dosya `assets/audio/sfx/<ad>.wav` (44.1 kHz mono 16-bit, tepe 0.89) ve
`data/sounds.json` tablosuna `"<ad>": "res://assets/audio/sfx/<ad>.wav"` kaydı eklenir.

Anahtar: ELEVENLABS_API_KEY ortam değişkeni ya da proje kökündeki .env.
Anahtar hiçbir zaman yazdırılmaz ve repoya girmez.
"""

import json
import math
import os
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SFX_DIR = os.path.join(ROOT, "assets", "audio", "sfx")
RECIPES_PATH = os.path.join(ROOT, "data", "sfx_recipes.json")
SOUNDS_PATH = os.path.join(ROOT, "data", "sounds.json")
RATE = 44100
TARGET_PEAK = 0.89
# ElevenLabs sound-generation 0.5 sn altını reddediyor (HTTP 400
# invalid_generation_settings). Kısa efektler için yine de 0.5 sn istenir,
# gerekirse sonra kırpılır.
MIN_API_SECONDS = 0.5
# Dikişsiz loop üretiminde kuyruk/baş karışım süresi (sn). ASMR: uzun, duyulmaz.
LOOP_FADE_SECONDS = 1.5


# --------------------------------------------------------------------------
# tarifler
# --------------------------------------------------------------------------
def load_recipes():
    if not os.path.exists(RECIPES_PATH):
        raise SystemExit("hata: tarif dosyasi yok: %s" % RECIPES_PATH)
    with open(RECIPES_PATH, encoding="utf-8") as handle:
        recipes = json.load(handle)
    if not isinstance(recipes, dict) or not recipes:
        raise SystemExit("hata: %s bos ya da nesne degil" % RECIPES_PATH)
    return recipes


def api_key():
    key = os.environ.get("ELEVENLABS_API_KEY", "").strip()
    if key:
        return key
    env_path = os.path.join(ROOT, ".env")
    if not os.path.exists(env_path):
        return ""
    with open(env_path, encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            for separator in ("=", ":"):
                name, found, value = line.partition(separator)
                if found and "eleven" in name.lower():
                    return value.strip().strip('"').strip("'")
    return ""


# --------------------------------------------------------------------------
# ElevenLabs
# --------------------------------------------------------------------------
def elevenlabs(prompt, seconds, key):
    body = json.dumps({
        "text": prompt,
        "duration_seconds": seconds,
        "prompt_influence": 0.6,
    }).encode("utf-8")
    request = urllib.request.Request(
        "https://api.elevenlabs.io/v1/sound-generation",
        data=body,
        method="POST",
        headers={"xi-api-key": key, "Content-Type": "application/json", "Accept": "audio/mpeg"},
    )
    with urllib.request.urlopen(request, timeout=90) as response:
        return response.read()


def mp3_to_wav(data, out_path):
    with tempfile.NamedTemporaryFile(suffix=".mp3", delete=False) as handle:
        handle.write(data)
        tmp_path = handle.name
    try:
        result = subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error", "-i", tmp_path,
             "-ac", "1", "-ar", str(RATE), "-acodec", "pcm_s16le", out_path],
            capture_output=True)
        return result.returncode == 0 and os.path.getsize(out_path) > 512
    finally:
        os.unlink(tmp_path)


# --------------------------------------------------------------------------
# ortak yardımcılar (ASMR: yumuşak atak, düşük frekans, yumuşak kırpma)
# --------------------------------------------------------------------------
def envelope(t, attack, decay):
    return np.clip(t / max(attack, 1e-6), 0.0, 1.0) * np.exp(-t / max(decay, 1e-6))


def soft_attack(t, attack):
    """Tık yapmayan yumuşak giriş: cos eğrisiyle 0 -> 1."""
    return np.clip(t / max(attack, 1e-6), 0.0, 1.0) ** 2 * (3.0 - 2.0 * np.clip(
        t / max(attack, 1e-6), 0.0, 1.0))


def normalize(samples, peak=TARGET_PEAK):
    top = float(np.max(np.abs(samples))) or 1.0
    return samples / top * peak


def soft_saturate(samples, drive=1.15):
    """Tepeye yakın harmonikleri yumuşatır; sert dijital kırpma yerine tanh."""
    return np.tanh(samples * drive) / math.tanh(drive)


def lowpassed(rng, size, kernel):
    """Basit hareketli ortalama alçak geçiren: pencere büyüdükçe daha koyu."""
    noise = rng.normal(0, 1, size)
    if kernel <= 1:
        return noise
    taps = np.ones(kernel, dtype=np.float64) / float(kernel)
    return np.convolve(noise, taps, mode="same")


def crossfade_loop(samples, loop_seconds, fade_seconds=LOOP_FADE_SECONDS):
    """Dikişsiz loop: son `fade` saniyelik kuyruk, eşit güç eğrisiyle başa karışır.

    y[i] = x[i]*(i/fade) + x[loop_len+i]*(1-i/fade)  (i < fade)
    Böylece y[-1] -> y[0] geçişi doğal örnek adımı kadar kalır; tık oluşmaz.
    """
    loop_len = int(round(RATE * loop_seconds))
    fade_len = int(round(RATE * min(fade_seconds, loop_seconds * 0.4)))
    if loop_len <= 0 or fade_len <= 0:
        return normalize(samples)
    needed = loop_len + fade_len
    if samples.size < needed:
        samples = np.resize(samples, needed)
    out = samples[:loop_len].copy()
    ramp = np.linspace(0.0, 1.0, fade_len, endpoint=False)
    head = samples[:fade_len]
    tail = samples[loop_len:loop_len + fade_len]
    out[:fade_len] = head * ramp + tail * (1.0 - ramp)
    return normalize(out)


# --------------------------------------------------------------------------
# yedek sentez tipleri
# --------------------------------------------------------------------------
def synth_blip(seconds, freq):
    """Yumuşak UI dokunuşu: sıcak sinüs, kısa ve nazik."""
    t = np.arange(int(RATE * seconds)) / RATE
    tone = np.sin(2 * math.pi * freq * t) + 0.16 * np.sin(2 * math.pi * freq * 2.0 * t)
    return normalize(soft_saturate(tone * envelope(t, 0.006, seconds * 0.30), 1.05))


def synth_thud(seconds, freq):
    t = np.arange(int(RATE * seconds)) / RATE
    sweep = np.sin(2 * math.pi * (freq * (1.0 - 0.35 * t / seconds)) * t)
    rng = np.random.default_rng(7)
    noise = lowpassed(rng, t.size, 24) * envelope(t, 0.002, 0.06) * 0.25
    return normalize(soft_saturate(sweep * envelope(t, 0.008, seconds * 0.35) + noise))


def synth_crackle(seconds, freq):
    """Yumuşak kıvılcım: alçak geçiren gürültü + kısık rezonanslar (keskin değil)."""
    rng = np.random.default_rng(11)
    t = np.arange(int(RATE * seconds)) / RATE
    body = lowpassed(rng, t.size, 10) * envelope(t, 0.004, seconds * 0.30)
    out = body * 0.8
    for partial, delay in ((1.0, 0.0), (1.37, 0.05), (2.1, 0.11)):
        shifted = np.clip(t - delay, 0, None)
        out += np.sin(2 * math.pi * freq * partial * shifted) * envelope(
            shifted, 0.003, seconds * 0.26) * 0.14
    return normalize(soft_saturate(out, 0.9))


def synth_chime(seconds, freq):
    """Sıcak chime: yumuşak atak, hafif detune, uzun sönüm (ASMR kutlama)."""
    t = np.arange(int(RATE * seconds)) / RATE
    out = np.zeros(t.size)
    for partial, weight in ((1.0, 1.0), (1.5, 0.32), (2.0, 0.18), (2.98, 0.08)):
        out += weight * np.sin(2 * math.pi * freq * partial * t)
    out += 0.22 * np.sin(2 * math.pi * (freq * 1.003) * t)
    return normalize(soft_saturate(out * envelope(t, 0.012, seconds * 0.42), 0.95))


def synth_whoosh(seconds, freq):
    """Yumuşak hava/whoosh: koyu gürültü, çan şeklinde zarf, düşük ton."""
    rng = np.random.default_rng(23)
    t = np.arange(int(RATE * seconds)) / RATE
    noise = lowpassed(rng, t.size, 28)
    shape = np.sin(np.pi * np.clip(t / seconds, 0, 1)) ** 2
    tone = np.sin(2 * math.pi * freq * t) * 0.12
    return normalize(soft_saturate((noise * 0.6 + tone) * shape, 0.9))


def synth_clack(seconds, freq):
    """Tok ahşap-metal oturma: gövde vuruşu + kısa yumuşak temas gürültüsü."""
    rng = np.random.default_rng(31)
    t = np.arange(int(RATE * seconds)) / RATE
    click = lowpassed(rng, t.size, 6) * envelope(t, 0.0008, 0.010) * 0.30
    out = click
    for partial, weight, decay in ((1.0, 0.9, 0.055), (1.58, 0.42, 0.040), (2.31, 0.20, 0.026)):
        out += weight * np.sin(2 * math.pi * freq * partial * t) * envelope(t, 0.0015, decay)
    # gövde: hafif aşağı kayan "tok" tonu
    out += np.sin(2 * math.pi * (freq * 0.5) * t) * envelope(t, 0.002, 0.09) * 0.45
    return normalize(soft_saturate(out, 1.0))


def synth_pop(seconds, freq):
    """Kısık sigorta pop'u: yumuşak bas vuruş, sert tık yok."""
    t = np.arange(int(RATE * seconds)) / RATE
    fall = np.exp(-t / max(seconds * 0.22, 1e-6))
    sweep = np.sin(2 * math.pi * freq * np.exp(-t / max(seconds * 0.6, 1e-6)) * t)
    body = np.sin(2 * math.pi * freq * 1.5 * t) * envelope(t, 0.004, 0.05) * 0.18
    return normalize(soft_saturate(sweep * fall + body, 0.95))


def synth_buzz(seconds, freq):
    """Alçak, yumuşak uğultu: testere yerine birkaç sıcak harmonik + tremolo."""
    t = np.arange(int(RATE * seconds)) / RATE
    out = np.sin(2 * math.pi * freq * t)
    for harmonic, weight in ((2.0, 0.32), (3.0, 0.14), (4.0, 0.06)):
        out += weight * np.sin(2 * math.pi * freq * harmonic * t)
    tremolo = 1.0 + 0.12 * np.sin(2 * math.pi * 5.0 * t)
    body = envelope(t, 0.030, seconds * 0.60)
    body *= np.clip((seconds - t) / 0.06, 0.0, 1.0)
    return normalize(soft_saturate(out * tremolo * body, 0.95))


def synth_hum(seconds, freq):
    """Kısa uğultu (eski 'hum' adı korunur): 50 Hz + harmonikleri."""
    t = np.arange(int(RATE * seconds)) / RATE
    tone = np.sin(2 * math.pi * freq * t) + 0.5 * np.sin(2 * math.pi * 2.0 * freq * t)
    tone += 0.18 * np.sin(2 * math.pi * 3.0 * freq * t)
    return normalize(tone, peak=0.55)


def synth_friction(seconds, freq):
    """Kumaş/ahşap sürtünmesi: koyu gürültü, yumuşak iki kabarma, kısık rezonans."""
    rng = np.random.default_rng(41)
    t = np.arange(int(RATE * seconds)) / RATE
    t01 = np.clip(t / max(seconds, 1e-6), 0.0, 1.0)
    swell = np.sin(np.pi * t01) ** 1.6
    texture = lowpassed(rng, t.size, 42) * 0.7 + lowpassed(rng, t.size, 9) * 0.3
    tone = np.sin(2 * math.pi * freq * t) * 0.10 * np.sin(np.pi * t01)
    out = (texture + tone) * swell
    return normalize(soft_saturate(out, 0.9))


def synth_hum_loop(seconds, freq):
    """Dikişsiz elektrik uğultusu: 50/100 Hz + hafif koyu gürültü yatağı."""
    loop_len = int(round(RATE * seconds))
    fade_len = int(round(RATE * min(LOOP_FADE_SECONDS, seconds * 0.4)))
    t = np.arange(loop_len + fade_len) / RATE
    rng = np.random.default_rng(53)
    air = lowpassed(rng, t.size, 64) * 0.16
    tone = np.sin(2 * math.pi * freq * t)
    tone += 0.55 * np.sin(2 * math.pi * 2.0 * freq * t)
    tone += 0.18 * np.sin(2 * math.pi * 3.0 * freq * t)
    # çok yavaş nefes: 8 sn'de ~1.2 kabarma (loop crossfade toplar)
    breath = 1.0 + 0.10 * np.sin(2 * math.pi * 0.15 * t)
    return crossfade_loop((tone * breath + air), seconds, fade_len / float(RATE))


def synth_pad_loop(seconds, freq):
    """Dikişsiz sıcak pad: A minör yaylı akor + yumuşak nefes LFO'ları."""
    loop_len = int(round(RATE * seconds))
    fade_len = int(round(RATE * min(LOOP_FADE_SECONDS * 1.4, seconds * 0.4)))
    t = np.arange(loop_len + fade_len) / RATE
    # A2 / E3 / A3 / C4 — sıcak, çözülmemiş akor; hafif detune ile canlılık.
    voices = (
        (freq, 0.50), (freq * 1.5, 0.34), (freq * 2.0, 0.26),
        (freq * 2.38, 0.16), (freq * 3.0, 0.10),
    )
    out = np.zeros(t.size)
    for index, (voice_freq, weight) in enumerate(voices):
        detune = 1.0 + 0.0012 * float(index % 2) - 0.0006 * float(index // 2)
        lfo = 1.0 + 0.16 * np.sin(2 * math.pi * (0.045 + 0.017 * index) * t + index)
        out += weight * np.sin(2 * math.pi * voice_freq * detune * t) * lfo
    rng = np.random.default_rng(67)
    air = lowpassed(rng, t.size, 90) * 0.10
    warm = out + air
    # Nazik saturasyon: pad'e analog sıcaklık, tepe kontrolü
    return crossfade_loop(soft_saturate(warm, 0.85), seconds, fade_len / float(RATE))


SYNTHS = {
    "blip": synth_blip,
    "thud": synth_thud,
    "crackle": synth_crackle,
    "chime": synth_chime,
    "whoosh": synth_whoosh,
    "clack": synth_clack,
    "pop": synth_pop,
    "buzz": synth_buzz,
    "hum": synth_hum,
    "friction": synth_friction,
    "hum_loop": synth_hum_loop,
    "pad_loop": synth_pad_loop,
}


# --------------------------------------------------------------------------
# dosya işlemleri
# --------------------------------------------------------------------------
def write_wav(path, samples):
    import wave
    pcm = (np.clip(samples, -1.0, 1.0) * 32767).astype("<i2")
    with wave.open(path, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(pcm.tobytes())


def normalize_wav(path):
    import wave
    with wave.open(path, "rb") as handle:
        params = handle.getparams()
        frames = handle.readframes(handle.getnframes())
    data = np.frombuffer(frames, dtype="<i2").astype(np.float32) / 32768.0
    peak = float(np.max(np.abs(data))) if data.size else 0.0
    if peak <= 1e-6 or peak <= TARGET_PEAK:
        return 1.0
    scale = TARGET_PEAK / peak
    pcm = (np.clip(data * scale, -1.0, 1.0) * 32767).astype("<i2").tobytes()
    with wave.open(path, "wb") as handle:
        handle.setparams(params)
        handle.writeframes(pcm)
    return scale


def register(name):
    """data/sounds.json'a kaydı ekler (varsa korur)."""
    table = {}
    if os.path.exists(SOUNDS_PATH):
        with open(SOUNDS_PATH, encoding="utf-8") as handle:
            try:
                table = json.load(handle)
            except json.JSONDecodeError:
                table = {}
        if not isinstance(table, dict):
            table = {}
    table[name] = "res://assets/audio/sfx/%s.wav" % name
    with open(SOUNDS_PATH, "w", encoding="utf-8") as handle:
        json.dump(dict(sorted(table.items())), handle, indent=2, ensure_ascii=False)
        handle.write("\n")


# --------------------------------------------------------------------------
# ana akış
# --------------------------------------------------------------------------
def main():
    args = sys.argv[1:]
    force = "--force" in args
    offline = "--offline" in args
    normalize_only = "--normalize" in args
    names = [a for a in args if not a.startswith("--")]

    os.makedirs(SFX_DIR, exist_ok=True)
    recipes = load_recipes()
    targets = names or list(recipes)
    unknown = [n for n in targets if n not in recipes]
    if unknown:
        print("hata: tarifte olmayan ad(lar): %s" % ", ".join(unknown), file=sys.stderr)
        return 2

    if normalize_only:
        for name in targets:
            path = os.path.join(SFX_DIR, name + ".wav")
            if os.path.exists(path):
                print("%-14s normalize (x%.2f)" % (name, normalize_wav(path)))
        return 0

    key = "" if offline else api_key()
    print("anahtar: %s" % ("bulundu (yazdırılmıyor)" if key else "yok — yedek sentez"))

    failures = 0
    for name in targets:
        path = os.path.join(SFX_DIR, name + ".wav")
        if not force and os.path.exists(path) and os.path.getsize(path) > 512:
            print("%-14s var, atlandı" % name)
            register(name)
            continue

        recipe = recipes[name]
        produced = False
        if key:
            try:
                api_seconds = max(MIN_API_SECONDS, float(recipe.get("seconds", 1.0)))
                data = elevenlabs(recipe.get("prompt", name), api_seconds, key)
                produced = mp3_to_wav(data, path)
                if produced:
                    normalize_wav(path)
                    print("%-14s ElevenLabs -> %6.1f KB" % (name, os.path.getsize(path) / 1024.0))
                else:
                    print("%-14s ElevenLabs dönüştürülemedi, yedeğe geçiliyor" % name)
            except urllib.error.HTTPError as exc:
                detail = exc.read()[:160].decode("utf-8", "replace")
                print("%-14s ElevenLabs HATA %d: %s" % (name, exc.code, detail))
            except (urllib.error.URLError, TimeoutError, OSError) as exc:
                print("%-14s ElevenLabs bağlantı hatası: %s" % (name, exc))

        if not produced:
            synth_name = recipe.get("synth", "blip")
            if synth_name not in SYNTHS:
                print("%-14s hata: bilinmeyen synth '%s'" % (name, synth_name), file=sys.stderr)
                failures += 1
                continue
            seconds = float(recipe.get("seconds", 0.5))
            freq = float(recipe.get("freq", 440.0))
            write_wav(path, SYNTHS[synth_name](seconds, freq))
            print("%-14s yedek sentez (%s) -> %6.1f KB"
                  % (name, synth_name, os.path.getsize(path) / 1024.0))

        register(name)

    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
