#!/usr/bin/env python3
"""Ses seti — ElevenLabs ile üretilir (SFX + müzik). Anahtar `.env.local` içindeki ELEVENLABS_API_KEY'dir.

    python3 tools/make_sfx.py              # eksikleri üretir
    python3 tools/make_sfx.py --force      # hepsini yeniden üretir
    python3 tools/make_sfx.py ui_soft coin # yalnız bu adlar

Anahtar asla yazdırılmaz ve koda girmez; `.env.local` hiçbir zaman commit edilmez ve okunup basılmaz.
Gereksinim: pip install -r requirements.txt ve ffmpeg. Çıktı: assets/audio/sfx/<ad>.wav (44.1 kHz mono,
baştaki/sondaki sessizlik kırpılır, tepe seviyesi dengelenir) + data/sounds.json kaydı.
Müzik: assets/audio/music/<ad>.ogg (döngü noktası çapraz geçişle bağlanır). `music_main` adı
AudioService'te kendiliğinden çalar; ortam sesi için `ambience_main`.
Ham API çıktısı build/sfx_raw altında saklanır: yeniden işleme kredi harcamaz.
Yeni oyunun ses tarifleri RECIPES / MUSIC sözlüklerine eklenir (oyunun diline uygun).
"""
import json
import os
import subprocess
import sys

import numpy as np
from dotenv import load_dotenv
from elevenlabs import ElevenLabs

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SFX_DIR = os.path.join(ROOT, "assets", "audio", "sfx")
MUSIC_DIR = os.path.join(ROOT, "assets", "audio", "music")
SOUNDS_PATH = os.path.join(ROOT, "data", "sounds.json")
ENV_PATH = os.path.join(ROOT, ".env.local")
RAW_DIR = os.path.join(ROOT, "build", "sfx_raw")
MODEL = "eleven_text_to_sound_v3"
STYLE = " Close-mic recording, soft, warm, clean, no music, no voice, no background noise."
MIN_WAV_BYTES = 4000

# ad: (tarif, süre sn, tarife bağlılık, döngü mü, hedef tepe seviyesi dB)
RECIPES = {
    "ui_soft": ("A very soft rounded button tap for a calm mobile game interface, short and gentle.", 0.5, 0.7, False, -10),
    "coin": ("Three small coins dropping softly, gentle muted clinks.", 0.9, 0.6, False, -9),
    "win": ("A short gentle success jingle on kalimba and soft glockenspiel, five rising notes with a soft shimmer.", 2.5, 0.6, False, -6),
    "lose": ("A soft sad descending three-note phrase fading out, tender not harsh.", 2.0, 0.6, False, -8),
}
# ad: (tarif, süre ms, hedef tepe dB, döngü geçiş süresi sn)
MUSIC = {}


def load_key():
    if not os.path.exists(ENV_PATH):
        sys.exit("hata: .env.local yok (ELEVENLABS_API_KEY orada olmalı)")
    load_dotenv(ENV_PATH)


def measure_peak(path, filters):
    result = subprocess.run(["ffmpeg", "-i", path, "-af", ",".join(filters + ["volumedetect"]),
                             "-f", "null", "-"], capture_output=True, text=True)
    for line in result.stderr.splitlines():
        if "max_volume" in line:
            return float(line.split("max_volume:")[1].split("dB")[0])
    return 0.0


def to_wav(source, target, loop, peak_db):
    filters = ["highpass=f=60"]
    if not loop:
        filters += ["silenceremove=start_periods=1:start_threshold=-42dB:start_silence=0.005",
                    "areverse",
                    "silenceremove=start_periods=1:start_threshold=-60dB:start_silence=0.02",
                    "areverse", "afade=t=in:d=0.003"]
    gain = peak_db - measure_peak(source, filters)
    filters.append("volume=%.2fdB" % gain)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", source, "-af", ",".join(filters),
                    "-ac", "1", "-ar", "44100", "-sample_fmt", "s16", target], check=True)
    if not loop and os.path.getsize(target) < MIN_WAV_BYTES:
        plain = ["highpass=f=60", "volume=%.2fdB" % (peak_db - measure_peak(source, ["highpass=f=60"]))]
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", source, "-af", ",".join(plain),
                        "-ac", "1", "-ar", "44100", "-sample_fmt", "s16", target], check=True)


def write_stream(audio, path):
    with open(path, "wb") as handle:
        for chunk in audio:
            handle.write(chunk)


def make_music(client, force, wanted, table):
    os.makedirs(MUSIC_DIR, exist_ok=True)
    for name, (prompt, length_ms, peak, cross) in MUSIC.items():
        if wanted and name not in wanted:
            continue
        raw = os.path.join(RAW_DIR, name + ".mp3")
        try:
            if force or not os.path.exists(raw):
                write_stream(client.music.compose(prompt=prompt, music_length_ms=length_ms, model_id="music_v2_5"), raw)
                print("üretildi:", name)
            pcm = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", raw, "-f", "s16le", "-ac", "2",
                                  "-ar", "44100", "-"], capture_output=True, check=True).stdout
            samples = np.frombuffer(pcm, dtype="<i2").astype(np.float32).reshape(-1, 2) / 32768.0
            fade = int(44100 * cross)
            body = samples[fade:].copy()
            ramp = np.linspace(0.0, 1.0, fade, dtype=np.float32)[:, None]
            body[-fade:] = body[-fade:] * (1.0 - ramp) + samples[:fade] * ramp
            body *= (10.0 ** (peak / 20.0)) / max(float(np.max(np.abs(body))), 1e-6)
            target = os.path.join(MUSIC_DIR, name + ".ogg")
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "s16le", "-ac", "2", "-ar", "44100",
                            "-i", "-", "-c:a", "vorbis", "-strict", "experimental", "-b:a", "128k", target],
                           input=(body * 32767.0).astype("<i2").tobytes(), check=True)
            table[name] = "res://assets/audio/music/%s.ogg" % name
        except Exception as error:  # noqa: BLE001
            detail = getattr(error, "body", None) or str(error)
            print("HATA %s: %s %s" % (name, getattr(error, "status_code", ""), str(detail)[:300]))


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    force = "--force" in sys.argv
    load_key()
    client = ElevenLabs(api_key=os.environ.get("ELEVENLABS_API_KEY"))
    os.makedirs(SFX_DIR, exist_ok=True)
    os.makedirs(RAW_DIR, exist_ok=True)
    table = json.load(open(SOUNDS_PATH, encoding="utf-8")) if os.path.exists(SOUNDS_PATH) else {}
    for name, (text, seconds, influence, loop, peak) in RECIPES.items():
        if args and name not in args:
            continue
        raw = os.path.join(RAW_DIR, name + ".mp3")
        try:
            if force or not os.path.exists(raw):
                write_stream(client.text_to_sound_effects.convert(
                    text=text + ("" if loop else STYLE), model_id=MODEL, duration_seconds=seconds,
                    prompt_influence=influence, loop=loop), raw)
                print("üretildi:", name)
            to_wav(raw, os.path.join(SFX_DIR, name + ".wav"), loop, peak)
            table[name] = "res://assets/audio/sfx/%s.wav" % name
        except Exception as error:  # noqa: BLE001 — hata adıyla raporlanır, diğer sesler sürer
            detail = getattr(error, "body", None) or str(error)
            print("HATA %s: %s %s" % (name, getattr(error, "status_code", ""), str(detail)[:300]))
    make_music(client, force, args, table)
    json.dump(dict(sorted(table.items())), open(SOUNDS_PATH, "w", encoding="utf-8"), indent=2)


main()
