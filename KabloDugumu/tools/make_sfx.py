#!/usr/bin/env python3
"""Ses efektlerini üretir: ElevenLabs API -> WAV, anahtar yoksa yedek sentez.

Kullanım:
    python3 tools/make_sfx.py                 # eksik olanları üretir
    python3 tools/make_sfx.py --force         # hepsini yeniden üretir
    python3 tools/make_sfx.py --offline       # API'yi atlar, yedeği üretir
    python3 tools/make_sfx.py ui_tap success  # yalnızca bu adlar
    python3 tools/make_sfx.py --normalize     # var olanları tepe-normalize eder

Tarifler \`data/sfx_recipes.json\`:
    {
      "ui_tap": {"prompt": "...", "seconds": 0.4, "synth": "blip", "freq": 880}
    }

Yedek sentez tipleri (anahtar yoksa deterministik üretim):
    blip, thud, crackle, chime, whoosh, clack, pop, buzz, hum

Üretilen dosya \`assets/audio/sfx/<ad>.wav\` (44.1 kHz mono 16-bit, tepe 0.89) ve
\`data/sounds.json\` tablosuna \`"<ad>": "res://assets/audio/sfx/<ad>.wav"\` kaydı eklenir.

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
# yedek sentez (anahtar yoksa) — tipler tarifte seçilir
# --------------------------------------------------------------------------
def envelope(t, attack, decay):
    return np.clip(t / max(attack, 1e-6), 0.0, 1.0) * np.exp(-t / max(decay, 1e-6))


def normalize(samples, peak=TARGET_PEAK):
    top = float(np.max(np.abs(samples))) or 1.0
    return samples / top * peak


def synth_blip(seconds, freq):
    t = np.arange(int(RATE * seconds)) / RATE
    tone = np.sin(2 * math.pi * freq * t) + 0.3 * np.sin(2 * math.pi * freq * 2 * t)
    return normalize(tone * envelope(t, 0.002, seconds * 0.22))


def synth_thud(seconds, freq):
    t = np.arange(int(RATE * seconds)) / RATE
    sweep = np.sin(2 * math.pi * (freq * (1.0 - 0.45 * t / seconds)) * t)
    noise = np.random.default_rng(7).normal(0, 1, t.size)
    return normalize(sweep * envelope(t, 0.004, seconds * 0.3) + noise * envelope(t, 0.001, 0.02) * 0.3)


def synth_crackle(seconds, freq):
    rng = np.random.default_rng(11)
    t = np.arange(int(RATE * seconds)) / RATE
    out = rng.normal(0, 1, t.size) * envelope(t, 0.0006, seconds * 0.12)
    for partial, delay in ((1.0, 0.0), (1.37, 0.04), (2.1, 0.09)):
        shifted = np.clip(t - delay, 0, None)
        out += np.sin(2 * math.pi * freq * partial * shifted) * envelope(shifted, 0.001, seconds * 0.18) * 0.25
    return normalize(out)


def synth_chime(seconds, freq):
    t = np.arange(int(RATE * seconds)) / RATE
    out = np.zeros(t.size)
    for partial, weight in ((1.0, 1.0), (1.5, 0.4), (2.0, 0.25), (2.98, 0.12)):
        out += weight * np.sin(2 * math.pi * freq * partial * t)
    return normalize(out * envelope(t, 0.004, seconds * 0.35))


def synth_whoosh(seconds, freq):
    rng = np.random.default_rng(23)
    t = np.arange(int(RATE * seconds)) / RATE
    noise = rng.normal(0, 1, t.size)
    shape = np.sin(np.pi * np.clip(t / seconds, 0, 1)) ** 2
    tone = np.sin(2 * math.pi * freq * t) * 0.2
    return normalize((noise * 0.7 + tone) * shape)


def synth_clack(seconds, freq):
    """Keskin metal-tokmak: kısa gürültü atağı + inharmonik metal kısmi tonları."""
    rng = np.random.default_rng(31)
    t = np.arange(int(RATE * seconds)) / RATE
    click = rng.normal(0, 1, t.size) * envelope(t, 0.0004, 0.006)
    out = click * 0.45
    for partial, weight in ((1.0, 0.8), (2.37, 0.5), (3.71, 0.3), (5.43, 0.16)):
        out += weight * np.sin(2 * math.pi * freq * partial * t) * envelope(t, 0.0008, 0.035)
    return normalize(out)


def synth_pop(seconds, freq):
    """Kısa bas pop: hızlı düşen sinüs + tok bir gövde; sigorta patlaması."""
    t = np.arange(int(RATE * seconds)) / RATE
    fall = np.exp(-t / max(seconds * 0.18, 1e-6))
    sweep = np.sin(2 * math.pi * freq * np.exp(-t / max(seconds * 0.5, 1e-6)) * t)
    click = np.sin(2 * math.pi * freq * 6.0 * t) * envelope(t, 0.0005, 0.012) * 0.35
    return normalize((sweep * fall) + click)


def synth_buzz(seconds, freq):
    """Alçak testere (saw) vurgusu: yanlış priz / sigorta hatası hissi."""
    t = np.arange(int(RATE * seconds)) / RATE
    cycle = (freq * t) % 1.0
    saw = 2.0 * cycle - 1.0
    out = saw.copy()
    for harmonic in (2, 3, 4):
        out += saw_harmonic(cycle, harmonic) / harmonic
    # Yavaş tremolo "vızıltı" ve sondaki sönüm; başta 8 ms fade ile tık önlenir.
    tremolo = 1.0 + 0.18 * np.sin(2 * math.pi * 7.0 * t)
    body = envelope(t, 0.008, seconds * 0.55)
    # Son 40 ms'i sıfıra indir: kesik kuyruk duyulmasın (tık).
    body *= np.clip((seconds - t) / 0.04, 0.0, 1.0)
    return normalize(out * tremolo * body)


def saw_harmonic(cycle, harmonic):
    """Testere dalgasının n. harmoniği (faz kaymasız toplam için)."""
    return 2.0 * ((cycle * harmonic) % 1.0) - 1.0


def synth_hum(seconds, freq):
    """Dikişsiz elektrik hum'u: 50 Hz + 100 Hz. Süre * frekans tam sayı olduğundan
    döngüde baş/son örnekleri uyumludur; fade eklenmez (döngüyü bozar)."""
    t = np.arange(int(RATE * seconds)) / RATE
    tone = np.sin(2 * math.pi * freq * t) + 0.5 * np.sin(2 * math.pi * 2.0 * freq * t)
    tone += 0.18 * np.sin(2 * math.pi * 3.0 * freq * t)
    return normalize(tone)


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
