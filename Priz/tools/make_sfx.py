#!/usr/bin/env python3
"""Priz ses seti — ElevenLabs ile üretilir (SFX + müzik), kodla sentez YOK.

    python3 tools/make_sfx.py                 # eksik olanları üretir (önbellekte olan API'ye gitmez)
    python3 tools/make_sfx.py plug_seat_1     # yalnız bu adlar
    python3 tools/make_sfx.py --force NAME    # adı verilen sesi YENİDEN üretir (kredi harcar; ad şart)
    python3 tools/make_sfx.py --dry           # ne üretilecek, kaç istek gider: API çağrısı yok
    python3 tools/make_sfx.py --report        # yalnız ölçüm tablosu (süre, tepe, RMS, sessizlik, döngü dikişi)

Anahtar `.env.local` içindeki ELEVENLABS_API_KEY'dir; python-dotenv ile yüklenir, SDK'ya açıkça verilir,
asla yazdırılmaz ve koda girmez. Dosya hiçbir zaman okunup basılmaz, commit edilmez.
Ham API çıktısı build/sfx_raw altında saklanır (git dışı): yeniden işleme kredi harcamaz.
Toplam istek sayısı build/sfx_raw/requests.json'da tutulur ve MAX_REQUESTS'i aşamaz.

Çıktılar (44.1 kHz mono 16-bit WAV; müzik OGG):
  assets/audio/sfx/<ad>.wav       tek atımlık sesler (baş/son sessizlik kırpılır, tepe dengelenir)
  assets/audio/loops/<ad>.wav     cihaz ve elektrik döngüleri (kuyruk başa çapraz geçişle bağlanır)
  assets/audio/ambience/<ad>.wav  ortam döngüleri (aynı yöntem, daha uzun geçiş)
  assets/audio/music/<ad>.ogg     müzik (döngü olanın sonu başa bağlanır)
Hepsi data/sounds.json'a ada göre kaydedilir. coin / ui_soft / win kabuk şablonundan gelir: dokunulmaz.
"""
import json
import os
import subprocess
import sys
import wave

import numpy as np
from dotenv import load_dotenv
from elevenlabs import ElevenLabs

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AUDIO_DIR = os.path.join(ROOT, "assets", "audio")
DIRS = {"oneshot": "sfx", "loop": "loops", "ambience": "ambience", "music": "music", "jingle": "music"}
SOUNDS_PATH = os.path.join(ROOT, "data", "sounds.json")
ENV_PATH = os.path.join(ROOT, ".env.local")
RAW_DIR = os.path.join(ROOT, "build", "sfx_raw")
COUNT_PATH = os.path.join(RAW_DIR, "requests.json")
MODEL = "eleven_text_to_sound_v3"
MUSIC_MODEL = "music_v2_5"
MAX_REQUESTS = 45
RATE = 44100
# Döngüler daha düşük örnekleme hızında saklanır (depo küçük kalsın); tek atımlıklar ve müzik 44.1 kHz.
RATES = {"oneshot": 44100, "loop": 32000, "ambience": 22050}
STYLE = " Close-mic recording, soft, warm, clean, no music, no voice, no background noise."
LOOP_STYLE = " Seamless steady loop, no music, no voice, no sudden events, quiet and even."
MIN_WAV_BYTES = 3000

# kind: oneshot | loop | ambience | music (döngülü) | jingle (döngüsüz müzik)
# peak: hedef tepe dB. Tek atımlıklar döngülerden yüksek; fiş "tık"ı oyunun en net sesi.
# fade: döngü çapraz geçiş süresi (sn). hp: yüksek geçiren kesim Hz (şebeke uğultusu için düşük).
RECIPES = {
    # --- Fiş ---
    "plug_pickup": dict(kind="oneshot", secs=0.6, infl=0.7, peak=-8, text=
        "A soft rubber and plastic power plug being lifted off a wooden table, gentle tactile lift, tiny cable rustle."),
    "plug_magnet": dict(kind="oneshot", secs=0.5, infl=0.6, peak=-12, text=
        "A very subtle short airy whoosh, something small gliding quickly through the air with a faint magnetic pull."),
    "plug_seat_1": dict(kind="oneshot", secs=0.5, infl=0.8, peak=-1.5, style=
        " Close-mic ASMR recording, clean, no music, no voice, no background noise.", text=
        "A power plug pushed firmly into a wall socket with one crisp satisfying tactile click-thunk, tight and solid, "
        "quick snap of plastic and metal contacts, dry, no echo."),
    "plug_seat_2": dict(kind="oneshot", secs=0.5, infl=0.8, peak=-1.5, style=
        " Close-mic ASMR recording, clean, no music, no voice, no background noise.", text=
        "An electrical plug seating into a socket, a single crisp click with a short solid thunk underneath, "
        "satisfying and precise, dry, no echo."),
    "plug_seat_3": dict(kind="oneshot", secs=0.5, infl=0.8, peak=-1.5, style=
        " Close-mic ASMR recording, clean, no music, no voice, no background noise.", text=
        "A plug clicking home into a socket, bright crisp click followed by a muffled firm thunk, "
        "premium tactile feel, one single hit, dry."),
    "plug_unplug": dict(kind="oneshot", secs=0.5, infl=0.7, peak=-6, text=
        "A plug pulled out of a wall socket with a soft pop, short rubbery release."),
    "plug_reject": dict(kind="oneshot", secs=0.5, infl=0.7, peak=-9, text=
        "A soft dull plastic bounce, a small rubbery thud as something does not fit, gentle, no buzzer, no beep."),
    "socket_tick": dict(kind="oneshot", secs=0.5, infl=0.7, peak=-12, text=
        "A tiny soft light tick, a delicate quiet plastic tap, very short."),
    # --- Sigorta kutusu ve gün ---
    "breaker_flip": dict(kind="oneshot", secs=0.7, infl=0.7, peak=-4, text=
        "A chunky heavy breaker lever flipping with a solid mechanical clack, thick and tactile."),
    "start_day": dict(kind="oneshot", secs=2.2, infl=0.6, peak=-5, text=
        "A big heavy electrical switch thrown with a deep clack, then a warm electrical hum swelling and rising in pitch "
        "as a house powers up."),
    "fuse_blow": dict(kind="oneshot", secs=0.8, infl=0.7, peak=-3, text=
        "A sharp electrical snap, a fuse blowing with a crisp crack and a brief spark fizz, dramatic but not painful, "
        "then sudden silence."),
    "power_down": dict(kind="oneshot", secs=1.8, infl=0.6, peak=-10, text=
        "Household appliances winding down into silence, motors slowing and humming fading away, power cutting out, "
        "ending in total quiet."),
    "lamp_flicker": dict(kind="oneshot", secs=0.6, infl=0.6, peak=-12, text=
        "A short soft electrical buzz of a lamp bulb flickering, brief faint filament stutter."),
    # --- Akış / ödül ---
    "slice_transition": dict(kind="oneshot", secs=1.0, infl=0.6, peak=-9, text=
        "A soft gentle chime with a light airy whoosh, calm transition, warm and clean."),
    "window_light": dict(kind="oneshot", secs=0.7, infl=0.7, peak=-9, text=
        "A single clear soft glass tink, one small bright warm bell note with a short decay, like a light switching on."),
    "lose": dict(kind="oneshot", secs=1.8, infl=0.6, peak=-10, text=
        "A soft gentle descending two-note sting on a warm rounded instrument, tender not harsh, fading out."),
    # --- Cihaz döngüleri ---
    "loop_fridge": dict(kind="loop", secs=6.0, infl=0.5, peak=-18, fade=0.6, hp=40, text=
        "A refrigerator running, steady low warm compressor hum with a faint motor vibration, constant and even."),
    "loop_oven": dict(kind="loop", secs=6.0, infl=0.5, peak=-18, fade=0.6, hp=60, text=
        "An electric oven with a convection fan, soft steady airy fan whoosh over a faint low warm hum, constant."),
    "loop_kettle": dict(kind="loop", secs=6.0, infl=0.5, peak=-18, fade=0.6, hp=80, text=
        "An electric kettle boiling water, gentle steady rolling bubbling and simmer, soft and constant."),
    "loop_washer": dict(kind="loop", secs=6.0, infl=0.5, peak=-18, fade=0.6, hp=60, text=
        "A washing machine drum slowly tumbling, soft rhythmic water sloshing and clothes turning, low gentle motor hum."),
    "loop_tv": dict(kind="loop", secs=6.0, infl=0.5, peak=-20, fade=0.6, hp=100, text=
        "A television playing in another room, very low muffled unintelligible murmur and faint electronic hiss, quiet."),
    "loop_fan": dict(kind="loop", secs=6.0, infl=0.5, peak=-18, fade=0.6, hp=80, text=
        "A small electric desk fan, steady soft whirring airflow, gentle constant blades, no rattle."),
    "loop_toaster": dict(kind="loop", secs=6.0, infl=0.5, peak=-20, fade=0.6, hp=100, text=
        "A toaster glowing, soft sparse electrical ticking and faint warm crackle of heating filaments, quiet, steady."),
    "loop_lamp": dict(kind="loop", secs=5.0, infl=0.5, peak=-28, fade=0.6, hp=100, text=
        "A lamp bulb filament, near silent, an extremely faint soft electrical buzz, constant."),
    # --- Elektrik ---
    "hum_mains": dict(kind="loop", secs=5.0, infl=0.6, peak=-20, fade=0.4, hp=30, text=
        "A clean steady mains electrical transformer hum at 50 Hz with soft gentle harmonics, smooth drone, "
        "no crackle, no noise, no pulsing."),
    # --- Ortamlar ---
    "ambience_morning": dict(kind="ambience", secs=16.0, infl=0.5, peak=-22, fade=1.5, hp=60, text=
        "Quiet early morning ambience, a few soft distant birds singing, faint distant street, calm, no voices, no horns."),
    "ambience_noon": dict(kind="ambience", secs=16.0, infl=0.5, peak=-22, fade=1.5, hp=60, text=
        "Bright daytime city murmur from an open window, soft distant traffic hum and faint far away life, calm, no voices, no horns."),
    "ambience_evening": dict(kind="ambience", secs=16.0, infl=0.5, peak=-22, fade=1.5, hp=60, text=
        "Calm evening ambience, very distant soft city life, gentle breeze, a faint far away bird, peaceful, no voices, no horns."),
    "ambience_night": dict(kind="ambience", secs=16.0, infl=0.5, peak=-22, fade=1.5, hp=60, text=
        "Quiet night ambience, soft crickets, a very gentle breeze, peaceful and still, no voices."),
}
# Müzik (ElevenLabs Music): ad -> dict(kind, ms, peak, fade, text)
MUSIC = {
    "music_win": dict(kind="jingle", ms=5000, peak=-4, text=
        "A short warm uplifting win piece, soft kalimba, felt piano and gentle strings, rising phrase that ends on a "
        "resolved warm major chord, cozy and rewarding, no vocals."),
    "music_plan": dict(kind="music", ms=32000, peak=-10, fade=2.0, text=
        "Cozy sparse instrumental background loop for a calm planning puzzle game: slow soft felt piano, warm "
        "fingerpicked guitar, very light pads, around 70 bpm, major key, quiet and spacious, lots of room, steady "
        "energy from start to end, no vocals."),
}


def out_path(name, kind):
    ext = "ogg" if kind in ("music", "jingle") else "wav"
    return os.path.join(AUDIO_DIR, DIRS[kind], "%s.%s" % (name, ext))


def res_path(name, kind):
    ext = "ogg" if kind in ("music", "jingle") else "wav"
    return "res://assets/audio/%s/%s.%s" % (DIRS[kind], name, ext)


def load_key():
    """Anahtarı ortama alır; dosya okunup basılmaz (python-dotenv yükler)."""
    if not os.path.exists(ENV_PATH):
        sys.exit("hata: .env.local yok")
    load_dotenv(ENV_PATH)


def request_count():
    if os.path.exists(COUNT_PATH):
        return int(json.load(open(COUNT_PATH))["requests"])
    return 0


def bump_request():
    """Her API çağrısından ÖNCE sayaç artırılır; üst sınır aşılırsa çağrı yapılmaz."""
    count = request_count()
    if count >= MAX_REQUESTS:
        sys.exit("hata: istek üst sınırına (%d) ulaşıldı" % MAX_REQUESTS)
    json.dump({"requests": count + 1}, open(COUNT_PATH, "w"))


def write_stream(audio, path):
    with open(path, "wb") as handle:
        for chunk in audio:
            handle.write(chunk)


def decode(path, filters, rate=RATE):
    """Ham dosyayı mono float32 44.1 kHz diziye çevirir."""
    args = ["ffmpeg", "-loglevel", "error", "-i", path]
    if filters:
        args += ["-af", ",".join(filters)]
    pcm = subprocess.run(args + ["-f", "f32le", "-ac", "1", "-ar", str(rate), "-"], capture_output=True, check=True).stdout
    return np.frombuffer(pcm, dtype="<f4").copy()


def write_wav(samples, path, rate=RATE):
    data = np.clip(samples, -1.0, 1.0)
    pcm = (data * 32767.0).astype("<i2")
    with wave.open(path, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(rate)
        handle.writeframes(pcm.tobytes())


def normalise(samples, peak_db):
    top = float(np.max(np.abs(samples)))
    return samples * ((10.0 ** (peak_db / 20.0)) / max(top, 1e-6))


def trim_silence(samples, start_db=-42.0, end_db=-60.0, pad=0.004):
    """Baştaki sessizliği ve sondaki TAM sessizliği kırpar; doğal sönüm kalır."""
    top = float(np.max(np.abs(samples)))
    if top <= 0:
        return samples
    start_thr = top * 10.0 ** (start_db / 20.0)
    end_thr = top * 10.0 ** (end_db / 20.0)
    loud = np.nonzero(np.abs(samples) > start_thr)[0]
    tail = np.nonzero(np.abs(samples) > end_thr)[0]
    if len(loud) == 0:
        return samples
    first = max(int(loud[0]) - int(pad * RATE), 0)
    last = min(int(tail[-1]) + int(0.02 * RATE), len(samples))
    return samples[first:last]


def make_seamless(samples, fade_s, rate=RATE):
    """Kuyruğu başa eşit-güçlü çapraz geçişle bağlar: sarma noktasında süreksizlik olmaz."""
    fade = int(rate * fade_s)
    if len(samples) < fade * 3:
        fade = len(samples) // 4
    body = samples[fade:].copy()
    ramp = np.linspace(0.0, 1.0, fade, dtype=np.float32)
    fade_in = np.sin(ramp * np.pi / 2.0)
    fade_out = np.cos(ramp * np.pi / 2.0)
    body[-fade:] = body[-fade:] * fade_out + samples[:fade] * fade_in
    return body


def process_wav(raw, target, spec):
    hp = spec.get("hp", 60)
    rate = RATES[spec["kind"]]
    samples = decode(raw, ["highpass=f=%d" % hp], rate)
    if spec["kind"] == "oneshot":
        samples = trim_silence(samples)
        if len(samples) * 2 < MIN_WAV_BYTES:
            samples = decode(raw, ["highpass=f=%d" % hp], rate)
        fade_in = int(0.004 * RATE)
        samples[:fade_in] *= np.linspace(0.0, 1.0, fade_in, dtype=np.float32)
        tail = int(0.01 * RATE)
        samples[-tail:] *= np.linspace(1.0, 0.0, tail, dtype=np.float32)
    else:
        samples = make_seamless(samples, spec["fade"], rate)
    write_wav(normalise(samples, spec["peak"]), target, rate)


def process_music(raw, target, spec):
    pcm = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", raw, "-f", "s16le", "-ac", "2", "-ar", str(RATE), "-"],
                         capture_output=True, check=True).stdout
    samples = np.frombuffer(pcm, dtype="<i2").astype(np.float32).reshape(-1, 2) / 32768.0
    if spec["kind"] == "music":
        fade = int(RATE * spec["fade"])
        body = samples[fade:].copy()
        ramp = np.linspace(0.0, 1.0, fade, dtype=np.float32)[:, None]
        body[-fade:] = body[-fade:] * np.cos(ramp * np.pi / 2.0) + samples[:fade] * np.sin(ramp * np.pi / 2.0)
    else:
        body = samples.copy()
        tail = int(0.25 * RATE)
        body[-tail:] *= np.linspace(1.0, 0.0, tail, dtype=np.float32)[:, None]
    body *= (10.0 ** (spec["peak"] / 20.0)) / max(float(np.max(np.abs(body))), 1e-6)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "s16le", "-ac", "2", "-ar", str(RATE), "-i", "-",
                    "-c:a", "vorbis", "-strict", "experimental", "-b:a", "112k", target],
                   input=(body * 32767.0).astype("<i2").tobytes(), check=True)


def read_wav(path):
    with wave.open(path, "rb") as handle:
        rate = handle.getframerate()
        data = np.frombuffer(handle.readframes(handle.getnframes()), dtype="<i2").astype(np.float32) / 32768.0
    return data, rate


def db(value):
    return 20.0 * np.log10(max(float(value), 1e-9))


def report_row(name, kind):
    path = out_path(name, kind)
    if not os.path.exists(path):
        return None
    size = os.path.getsize(path)
    rate = RATE
    if path.endswith(".ogg"):
        samples = decode(path, [])
        seam = "-"
    else:
        samples, rate = read_wav(path)
        seam = "-"
        if kind in ("loop", "ambience"):
            # Sarma noktası: son örnekten ilk örneğe sıçrama, ortalama örnekler arası farka oranla.
            jump = abs(float(samples[0]) - float(samples[-1]))
            typical = float(np.sqrt(np.mean(np.diff(samples) ** 2))) + 1e-9
            seam = "%.1fx" % (jump / typical)
    rms = float(np.sqrt(np.mean(samples ** 2)))
    loud = np.nonzero(np.abs(samples) > 10 ** (-50 / 20))[0]
    head = loud[0] / rate * 1000 if len(loud) else -1
    tail = (len(samples) - 1 - loud[-1]) / rate * 1000 if len(loud) else -1
    return "%-18s %-8s %6.2fs peak %6.1f dB rms %6.1f dB head %5.0fms tail %5.0fms seam %-6s %6.1f KB" % (
        name, kind, len(samples) / rate, db(np.max(np.abs(samples))), db(rms), head, tail, seam, size / 1024.0)


def print_report():
    for name, spec in list(RECIPES.items()) + list(MUSIC.items()):
        row = report_row(name, spec["kind"])
        if row:
            print(row)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    force = "--force" in sys.argv
    if "--report" in sys.argv:
        print_report()
        return
    if force and not args:
        sys.exit("hata: --force için ad ver (toplu yeniden üretim kredi yakar)")
    os.makedirs(RAW_DIR, exist_ok=True)
    for sub in set(DIRS.values()):
        os.makedirs(os.path.join(AUDIO_DIR, sub), exist_ok=True)
    table = json.load(open(SOUNDS_PATH, encoding="utf-8")) if os.path.exists(SOUNDS_PATH) else {}
    jobs = [(n, s) for n, s in list(RECIPES.items()) + list(MUSIC.items()) if not args or n in args]
    pending = [n for n, _ in jobs if force or not os.path.exists(os.path.join(RAW_DIR, n + ".mp3"))]
    if "--dry" in sys.argv:
        print("üretilecek istek: %d (şimdiye dek %d / %d): %s" % (len(pending), request_count(), MAX_REQUESTS, ", ".join(pending)))
        return
    client = None
    if pending:
        load_key()
        # SDK ortamı içe aktarma anında okur; sonradan yüklenen anahtar açıkça verilir.
        client = ElevenLabs(api_key=os.environ.get("ELEVENLABS_API_KEY"))
    for name, spec in jobs:
        raw = os.path.join(RAW_DIR, name + ".mp3")
        kind = spec["kind"]
        try:
            if name in pending:
                bump_request()
                if kind in ("music", "jingle"):
                    audio = client.music.compose(prompt=spec["text"], music_length_ms=spec["ms"], model_id=MUSIC_MODEL)
                else:
                    looped = kind in ("loop", "ambience")
                    style = LOOP_STYLE if looped else spec.get("style", STYLE)
                    audio = client.text_to_sound_effects.convert(
                        text=spec["text"] + style, model_id=MODEL, duration_seconds=spec["secs"],
                        prompt_influence=spec["infl"], loop=looped)
                write_stream(audio, raw)
                print("üretildi:", name)
            if kind in ("music", "jingle"):
                process_music(raw, out_path(name, kind), spec)
            else:
                process_wav(raw, out_path(name, kind), spec)
            table[name] = res_path(name, kind)
        except Exception as error:  # noqa: BLE001 — hata adıyla raporlanır, diğer sesler sürer
            detail = getattr(error, "body", None) or str(error)
            print("HATA %s: %s %s" % (name, getattr(error, "status_code", ""), str(detail)[:300]))
    json.dump(dict(sorted(table.items())), open(SOUNDS_PATH, "w", encoding="utf-8"), indent=2)
    print("toplam istek: %d / %d" % (request_count(), MAX_REQUESTS))


main()
