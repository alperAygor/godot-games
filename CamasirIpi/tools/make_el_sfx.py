#!/usr/bin/env python3
"""Ses seti — ElevenLabs Sound Effects (SFX v3) ile üretilir, kodla sentez YOK.

    python3 tools/make_el_sfx.py              # eksikleri üretir
    python3 tools/make_el_sfx.py --force      # hepsini yeniden üretir
    python3 tools/make_el_sfx.py cloth_1 note # yalnız bu adlar

Anahtar `.env.local` içindeki ELEVENLABS_API_KEY'dir; SDK ortamdan okur. Anahtar asla
yazdırılmaz ve koda girmez. Çıktı: assets/audio/sfx/<ad>.wav (44.1 kHz mono, baştaki/sondaki
sessizlik kırpılır, ses yüksekliği dengelenir) + data/sounds.json kaydı.
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile

import numpy as np

from dotenv import load_dotenv
from elevenlabs import ElevenLabs

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SFX_DIR = os.path.join(ROOT, "assets", "audio", "sfx")
SOUNDS_PATH = os.path.join(ROOT, "data", "sounds.json")
ENV_PATH = os.path.join(ROOT, ".env.local")
MODEL = "eleven_text_to_sound_v3"
STYLE = " Close-mic ASMR recording, soft, warm, clean, no music, no voice, no background noise."

# ad: (tarif, süre sn, tarife bağlılık, döngü mü, hedef tepe seviyesi dB)
RECIPES = {
    "pin_click_1": ("A single wooden clothespin being unclipped from a clothesline, tiny crisp wood and spring click.", 0.5, 0.7, False, -6),
    "pin_click_2": ("One small wooden clothespin snapping open, gentle woody tick with a faint metal spring.", 0.5, 0.7, False, -6),
    "pin_click_3": ("A wooden clothes peg released from a rope, soft dry wooden click.", 0.5, 0.7, False, -6),
    "cloth_1": ("A cotton shirt pulled off a clothesline with a soft fabric swish through the air.", 0.7, 0.6, False, -9),
    "cloth_2": ("Soft linen fabric whooshing gently through the air, short cloth rustle.", 0.7, 0.6, False, -9),
    "cloth_3": ("A light cotton towel flicked once, soft airy fabric flutter.", 0.7, 0.6, False, -9),
    "fold_puff": ("A freshly folded soft cotton towel dropped onto a pile of laundry, gentle airy fabric poof.", 0.9, 0.6, False, -7),
    "note": ("A single warm soft kalimba note, one pluck, C5, gentle natural decay, dry.", 1.2, 0.8, False, -8),
    "wring": ("Wringing out a wet cloth by hand, short squeeze with a few water drips falling.", 1.0, 0.6, False, -8),
    "unlock": ("A small wooden latch clicking open followed by two soft pleasant glass chime notes rising.", 1.2, 0.6, False, -8),
    "wind": ("A sudden strong gust of wind sweeping through a garden, leaves and laundry flapping, swelling then fading.", 3.0, 0.5, False, -6),
    "win": ("A short gentle success jingle on kalimba and soft glockenspiel, five rising notes with a soft shimmer, cozy and satisfying.", 2.5, 0.6, False, -6),
    "basket_slide": ("A wicker laundry basket sliding softly across grass, short gentle rustling drag.", 0.8, 0.6, False, -11),
    "sparkle": ("A very soft delicate magical sparkle, tiny high bells twinkling briefly, gentle.", 0.9, 0.6, False, -12),
    "blocked": ("A soft muffled tug on a piece of fabric that does not come loose, gentle dull cloth pull.", 0.5, 0.6, False, -10),
    "lock_rattle": ("A tiny wooden latch rattling briefly, locked, soft and small.", 0.5, 0.6, False, -10),
    "rack_hang": ("A wooden clothes hanger being hooked onto a wooden rail, soft woody clack with a little fabric rustle.", 0.6, 0.6, False, -9),
    "ui_soft": ("A very soft rounded wooden button tap for a cozy game interface, short and gentle.", 0.5, 0.7, False, -10),
    "level_start": ("A light fresh breeze whoosh followed by one gentle warm chime, calm and inviting.", 1.2, 0.6, False, -9),
    "coin": ("Three small coins dropping softly into a cloth pouch, gentle muted clinks.", 0.9, 0.6, False, -9),
    "lose": ("A soft sad descending three-note kalimba phrase fading into a gentle sigh of wind, tender not harsh.", 2.0, 0.6, False, -8),
    "garden_ambience": ("Calm sunny garden ambience, very gentle breeze in leaves, a few distant soft songbirds, peaceful and quiet, no people, no traffic.", 22.0, 0.5, True, -16),
}
# ad: (tarif, süre ms, hedef tepe dB, döngü geçiş süresi sn) — arka plan müziği (ElevenLabs Music).
MUSIC = {
    "music_garden": ("Calm cozy instrumental background music for a relaxing laundry puzzle game in a sunny "
                     "garden: soft fingerpicked acoustic guitar, warm kalimba and light marimba, gentle upright "
                     "bass, very light brushed percussion, slow tempo around 80 bpm, major key, peaceful, "
                     "ASMR-soft, no vocals, steady from start to end so it can loop seamlessly.", 60000, -9, 3.0),
}
MUSIC_DIR = os.path.join(ROOT, "assets", "audio", "music")
ALIASES = {"pin_click": "pin_click_1", "cloth": "cloth_1"}
MIN_WAV_BYTES = 4000
START_DB = -42
END_DB = -60
# Ham API çıktısı burada saklanır: yeniden işleme kredi harcamaz.
RAW_DIR = os.path.join(ROOT, "build", "sfx_raw")


def load_key():
    """Anahtarı `.env.local` dosyasından ortama alır (yazdırmadan); SDK ortamdan okur."""
    if not os.path.exists(ENV_PATH):
        sys.exit("hata: .env.local yok (npx -y @elevenlabs/cli@latest onboard init)")
    load_dotenv(ENV_PATH)


def measure_peak(path, filters):
    """Filtrelerden sonraki tepe seviyesi (dB); kazanç buna göre hesaplanır."""
    result = subprocess.run(["ffmpeg", "-i", path, "-af", ",".join(filters + ["volumedetect"]),
                             "-f", "null", "-"], capture_output=True, text=True)
    for line in result.stderr.splitlines():
        if "max_volume" in line:
            return float(line.split("max_volume:")[1].split("dB")[0])
    return 0.0


def to_wav(source, target, loop, peak_db):
    filters = ["highpass=f=60"]
    if not loop:
        # Yalnız baştaki sessizlik ve sondaki TAM sessizlik kırpılır; sesin doğal sönümü kalır.
        filters += [
            "silenceremove=start_periods=1:start_threshold=%ddB:start_silence=0.005" % START_DB,
            "areverse",
            "silenceremove=start_periods=1:start_threshold=%ddB:start_silence=0.02" % END_DB,
            "areverse",
            "afade=t=in:d=0.003",
        ]
    # Kısa seslerde loudnorm güvenilmez; tepe seviyesine göre sabit kazanç uygulanır.
    gain = peak_db - measure_peak(source, filters)
    filters.append("volume=%.2fdB" % gain)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", source, "-af", ",".join(filters),
                    "-ac", "1", "-ar", "44100", "-sample_fmt", "s16", target], check=True)
    if not loop and os.path.getsize(target) < MIN_WAV_BYTES:
        # Çok sessiz kayıtta kırpma her şeyi atabilir; o durumda kırpmadan yeniden yazılır.
        plain = ["highpass=f=60", "volume=%.2fdB" % (peak_db - measure_peak(source, ["highpass=f=60"]))]
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", source, "-af", ",".join(plain),
                        "-ac", "1", "-ar", "44100", "-sample_fmt", "s16", target], check=True)


def make_music(client, force, wanted, table):
    """Müzik üretir ve sonunu başına çapraz geçişle bağlar: döngü noktasında kesinti olmaz."""
    os.makedirs(MUSIC_DIR, exist_ok=True)
    for name, (prompt, length_ms, peak, cross) in MUSIC.items():
        if wanted and name not in wanted:
            continue
        raw = os.path.join(RAW_DIR, name + ".mp3")
        try:
            if force or not os.path.exists(raw):
                audio = client.music.compose(prompt=prompt, music_length_ms=length_ms, model_id="music_v2_5")
                with open(raw, "wb") as handle:
                    for chunk in audio:
                        handle.write(chunk)
                print("üretildi:", name)
            pcm = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", raw, "-f", "s16le", "-ac", "2",
                                  "-ar", "44100", "-"], capture_output=True, check=True).stdout
            samples = np.frombuffer(pcm, dtype="<i2").astype(np.float32).reshape(-1, 2) / 32768.0
            fade = int(44100 * cross)
            body = samples[fade:].copy()
            ramp = np.linspace(0.0, 1.0, fade, dtype=np.float32)[:, None]
            # Son `cross` saniye, baştaki `cross` saniyeyle karışır; döngü başa sardığında aynı yerden sürer.
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
    # SDK varsayılanı içe aktarma anında okur; dosyadan sonradan yüklenen anahtar açıkça verilir.
    client = ElevenLabs(api_key=os.environ.get("ELEVENLABS_API_KEY"))
    os.makedirs(SFX_DIR, exist_ok=True)
    table = json.load(open(SOUNDS_PATH, encoding="utf-8")) if os.path.exists(SOUNDS_PATH) else {}
    os.makedirs(RAW_DIR, exist_ok=True)
    for name, (text, seconds, influence, loop, peak) in RECIPES.items():
        if args and name not in args:
            continue
        target = os.path.join(SFX_DIR, name + ".wav")
        raw = os.path.join(RAW_DIR, name + ".mp3")
        try:
            if force or not os.path.exists(raw):
                audio = client.text_to_sound_effects.convert(
                    text=text + ("" if loop else STYLE), model_id=MODEL, duration_seconds=seconds,
                    prompt_influence=influence, loop=loop)
                with open(raw, "wb") as handle:
                    for chunk in audio:
                        handle.write(chunk)
                print("üretildi:", name)
            to_wav(raw, target, loop, peak)
            table[name] = "res://assets/audio/sfx/%s.wav" % name
        except Exception as error:  # noqa: BLE001 — hata adıyla raporlanır, diğer sesler sürer
            # Yalnız durum kodu ve gövde yazılır (başlıklar gürültü; anahtar hiç yazılmaz).
            detail = getattr(error, "body", None) or str(error)
            print("HATA %s: %s %s" % (name, getattr(error, "status_code", ""), str(detail)[:300]))
    make_music(client, force, args, table)
    for alias, original in ALIASES.items():
        source = os.path.join(SFX_DIR, original + ".wav")
        if os.path.exists(source):
            shutil.copyfile(source, os.path.join(SFX_DIR, alias + ".wav"))
            table[alias] = "res://assets/audio/sfx/%s.wav" % alias
    json.dump(dict(sorted(table.items())), open(SOUNDS_PATH, "w", encoding="utf-8"), indent=2)


main()
