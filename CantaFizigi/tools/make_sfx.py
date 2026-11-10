#!/usr/bin/env python3
"""CantaFizigi — ses efektlerini üretir (assets/audio/sfx/*.wav).

Öncelik ElevenLabs API'sidir. Anahtar yoksa ya da API hata verirse aynı isimlerle
deterministik bir yedek sentez üretilir; oyun her durumda sesli çalışır.

Anahtar kaynağı (sırayla):
  1) ELEVENLABS_API_KEY ortam değişkeni
  2) proje kökündeki .env  (ELEVENLABS_API_KEY=... / elevenlabs_api_key:...)
Anahtar hiçbir zaman ekrana basılmaz ve repoya yazılmaz (.gitignore'da .env var).

Kullanım:
  python3 tools/make_sfx.py            # eksik olanları üretir
  python3 tools/make_sfx.py --force    # hepsini yeniden üretir
  python3 tools/make_sfx.py --offline  # API'yi atla, yedeği üret
"""

import json
import math
import os
import random
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio", "sfx")
RATE = 44100

# isim: (ElevenLabs prompt'u, süre sn)
SOUNDS = {
    "package_drop": (
        "single heavy cardboard parcel dropping onto a wooden table, dull low thud with a soft "
        "paper rustle, short, no music, close miced", 0.6),
    "glass_break": (
        "glass cargo box shattering, sharp high crack then tinkling shards falling, short, "
        "crisp, no music", 1.4),
    "ice_clink": (
        "ice cubes clinking inside a glass, light crystalline tinkle, small bits, short, no music",
        0.8),
    "success": (
        "short cheerful success jingle for a mobile game, bright marimba arpeggio with a soft "
        "glockenspiel shimmer, uplifting, 2 seconds", 2.0),
}


def api_key():
    key = os.environ.get("ELEVENLABS_API_KEY", "").strip()
    if key:
        return key
    env_path = os.path.join(ROOT, ".env")
    if not os.path.exists(env_path):
        return ""
    with open(env_path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            for sep in ("=", ":"):
                name, found, value = line.partition(sep)
                if found and "eleven" in name.lower():
                    return value.strip().strip('"').strip("'")
    return ""


# --------------------------------------------------------------------------
# ElevenLabs
# --------------------------------------------------------------------------
def elevenlabs(name: str, prompt: str, seconds: float, key: str) -> bytes:
    body = json.dumps({
        "text": prompt,
        "duration_seconds": seconds,
        "prompt_influence": 0.6,
    }).encode("utf-8")
    req = urllib.request.Request(
        "https://api.elevenlabs.io/v1/sound-generation",
        data=body,
        method="POST",
        headers={
            "xi-api-key": key,
            "Content-Type": "application/json",
            "Accept": "audio/mpeg",
        },
    )
    with urllib.request.urlopen(req, timeout=90) as resp:
        return resp.read()


def mp3_to_wav(data: bytes, out_path: str) -> bool:
    with tempfile.NamedTemporaryFile(suffix=".mp3", delete=False) as tmp:
        tmp.write(data)
        tmp_path = tmp.name
    try:
        result = subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error", "-i", tmp_path,
             "-ac", "1", "-ar", str(RATE), "-acodec", "pcm_s16le", out_path],
            capture_output=True)
        return result.returncode == 0 and os.path.getsize(out_path) > 512
    finally:
        os.unlink(tmp_path)


# --------------------------------------------------------------------------
# yedek sentez (anahtar yoksa) — aynı dosya adları, deterministik
# --------------------------------------------------------------------------
def env_ad(t: np.ndarray, attack: float, decay: float) -> np.ndarray:
    a = np.clip(t / max(attack, 1e-6), 0.0, 1.0)
    d = np.exp(-t / max(decay, 1e-6))
    return a * d


def norm(x: np.ndarray, peak: float = 0.86) -> np.ndarray:
    m = float(np.max(np.abs(x))) or 1.0
    return (x / m) * peak


def synth_drop() -> np.ndarray:
    t = np.arange(int(RATE * 0.45)) / RATE
    low = np.sin(2 * math.pi * (86 - 26 * t / 0.45) * t) * env_ad(t, 0.004, 0.09)
    body = np.sin(2 * math.pi * 172 * t) * env_ad(t, 0.002, 0.05) * 0.5
    noise = np.random.default_rng(7).normal(0, 1, t.size) * env_ad(t, 0.001, 0.02) * 0.35
    return norm(low + body + noise, 0.8)


def synth_glass() -> np.ndarray:
    rng = np.random.default_rng(11)
    n = int(RATE * 1.0)
    t = np.arange(n) / RATE
    crack = rng.normal(0, 1, n) * env_ad(t, 0.0005, 0.012)
    out = crack * 0.9
    for freq, delay, dec in ((2400, 0.00, 0.10), (3300, 0.03, 0.13), (1750, 0.07, 0.18),
                             (4200, 0.12, 0.09), (2900, 0.19, 0.14), (5100, 0.26, 0.08)):
        tt = np.clip(t - delay, 0, None)
        out += np.sin(2 * math.pi * freq * tt) * env_ad(tt, 0.001, dec) * 0.28
    return norm(out, 0.82)


def synth_ice() -> np.ndarray:
    rng = np.random.default_rng(23)
    n = int(RATE * 0.7)
    t = np.arange(n) / RATE
    out = np.zeros(n)
    for _ in range(6):
        delay = float(rng.uniform(0.0, 0.5))
        freq = float(rng.uniform(1800, 3600))
        tt = np.clip(t - delay, 0, None)
        out += np.sin(2 * math.pi * freq * tt) * env_ad(tt, 0.001, 0.045) * 0.3
    out += rng.normal(0, 1, n) * env_ad(t, 0.001, 0.03) * 0.05
    return norm(out, 0.7)


def synth_success() -> np.ndarray:
    notes = (523.25, 659.25, 783.99, 1046.50)  # C5 E5 G5 C6
    n = int(RATE * 1.6)
    t = np.arange(n) / RATE
    out = np.zeros(n)
    for i, freq in enumerate(notes):
        start = i * 0.13
        tt = np.clip(t - start, 0, None)
        bell = (np.sin(2 * math.pi * freq * tt) + 0.35 * np.sin(2 * math.pi * freq * 2.01 * tt)
                + 0.15 * np.sin(2 * math.pi * freq * 3.02 * tt))
        out += bell * env_ad(tt, 0.004, 0.38) * 0.4
    return norm(out, 0.75)


FALLBACK = {
    "package_drop": synth_drop,
    "glass_break": synth_glass,
    "ice_clink": synth_ice,
    "success": synth_success,
}


def write_wav(path: str, samples: np.ndarray) -> None:
    import wave
    pcm = np.clip(samples, -1.0, 1.0)
    pcm = (pcm * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())


def normalize_wav(path: str, target_peak: float = 0.89) -> float:
    """Tepe seviyeyi hedefe çeker: telefon hoparlöründe kırpılma (clipping) olmasın."""
    import wave
    with wave.open(path, "rb") as w:
        params = w.getparams()
        frames = w.readframes(w.getnframes())
    data = np.frombuffer(frames, dtype="<i2").astype(np.float32) / 32768.0
    peak = float(np.max(np.abs(data))) if data.size else 0.0
    if peak <= 1e-6:
        return 1.0
    scale = target_peak / peak
    if scale >= 1.0:
        return 1.0
    out = np.clip(data * scale, -1.0, 1.0)
    pcm = (out * 32767).astype("<i2").tobytes()
    with wave.open(path, "wb") as w:
        w.setparams(params)
        w.writeframes(pcm)
    return scale


def main() -> None:
    args = sys.argv[1:]
    force = "--force" in args
    offline = "--offline" in args
    normalize_only = "--normalize" in args
    os.makedirs(OUT, exist_ok=True)

    if normalize_only:
        for name in SOUNDS:
            path = os.path.join(OUT, name + ".wav")
            if os.path.exists(path):
                gain = normalize_wav(path)
                print("%-13s normalize (x%.2f)" % (name, gain))
        return

    key = "" if offline else api_key()
    if key:
        print("ElevenLabs anahtarı bulundu (değer yazdırılmıyor).")
    else:
        print("Anahtar yok ya da --offline: yedek sentez kullanılacak.")

    for name, (prompt, seconds) in SOUNDS.items():
        path = os.path.join(OUT, name + ".wav")
        if not force and os.path.exists(path) and os.path.getsize(path) > 512:
            print("%-13s var, atlandı" % name)
            continue
        produced = False
        if key:
            try:
                data = elevenlabs(name, prompt, seconds, key)
                produced = mp3_to_wav(data, path)
                if produced:
                    print("%-13s ElevenLabs -> %6.1f KB" % (name, os.path.getsize(path) / 1024))
                else:
                    print("%-13s ElevenLabs dönüştürülemedi, yedeğe geçiliyor" % name)
            except urllib.error.HTTPError as exc:
                detail = exc.read()[:160].decode("utf-8", "replace")
                print("%-13s ElevenLabs HATA %d: %s" % (name, exc.code, detail))
            except (urllib.error.URLError, TimeoutError, OSError) as exc:
                print("%-13s ElevenLabs bağlantı hatası: %s" % (name, exc))
        if not produced:
            samples = FALLBACK[name]()
            write_wav(path, samples)
            print("%-13s yedek sentez -> %6.1f KB" % (name, os.path.getsize(path) / 1024))


if __name__ == "__main__":
    main()
