#!/usr/bin/env python3
"""Ses seti — ElevenLabs (SFX v3 + Music v2.5) ile üretilir, kodla sentez YOK.

    python3 tools/make_el_sfx.py --account        # yalnız abonelik/kredi sayılarını yazar
    python3 tools/make_el_sfx.py --estimate       # plan süresi ve tahmini kredi (ağ yok)
    python3 tools/make_el_sfx.py                  # EKSİK ham dosyaları üretir + hepsini işler
    python3 tools/make_el_sfx.py --process        # üretmez; ham önbellekten yeniden işler (kredi harcamaz)
    python3 tools/make_el_sfx.py --retry cloth_2  # tek varlığı BİR kez yeniden üretir (eskisi .try1 olur)
    python3 tools/make_el_sfx.py cloth_1 note     # yalnız bu adlar

Anahtar `.env.local` içindeki ELEVENLABS_API_KEY'dir; yalnız python-dotenv + SDK okur, hiçbir yerde
yazdırılmaz. Ham API çıktısı `build/sfx_raw_v2/` altında saklanır (git dışı) ve her istek
`build/sfx_raw_v2/ledger.json` dosyasına yazılır: işleme (kırpma, seviye, döngü) kredi harcamaz.

Seviye kuralları `LEVELS` tablosundadır (kategori başına hedef LUFS-I ve gerçek tepe tavanı);
ayrıntı `docs/AUDIO.md`.
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audio_lib  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SFX_DIR = os.path.join(ROOT, "assets", "audio", "sfx")
MUSIC_DIR = os.path.join(ROOT, "assets", "audio", "music")
SOUNDS_PATH = os.path.join(ROOT, "data", "sounds.json")
ENV_PATH = os.path.join(ROOT, ".env.local")
RAW_DIR = os.path.join(ROOT, "build", "sfx_raw_v2")
LEDGER_PATH = os.path.join(RAW_DIR, "ledger.json")
REPORT_PATH = os.path.join(RAW_DIR, "processed.json")

SFX_MODEL = "eleven_text_to_sound_v3"
MUSIC_MODEL = "music_v2_5"
SFX_FORMAT = "mp3_44100_128"
STYLE = " Close-mic ASMR recording, soft, warm, clean, dry, no music, no voice, no background noise."
RATE = 44100

# Tahmini kredi birimleri (belgelenmiş fiyat: SFX sabit süreli üretimde ~40 kredi/sn; müzik ~1000 kredi/dk).
# Gerçek tüketim `--account` ile kontrol edilir; tahmin yalnız bütçe ön denetimi içindir.
SFX_CREDITS_PER_SECOND = 40
MUSIC_CREDITS_PER_MINUTE = 1000

# kategori: (hedef LUFS-I, gerçek tepe tavanı dBTP). Kazanç = min(hedef - ölçülen, tavan - tepe).
LEVELS = {
    "ui": (-17.0, -3.0),       # menü dokunuşları: net ama yumuşak
    "basket": (-13.0, -1.5),   # çamaşır sepete girer: oyunun en net sesi
    "core": (-16.0, -2.0),     # mandal, kumaş, askı, engeller
    "reward": (-15.0, -1.5),   # kazanma, para, sandık, açılış
    "spot": (-21.0, -3.0),     # kuş/kedi/yağmur/makine: atmosfer olayları
    "amb": (-25.0, -3.0),      # döngülü ortam yatağı
    "music": (-17.0, -1.5),    # arka plan müziği
}
MAX_GAIN_DB = 24.0

# ad: (tarif, süre sn, tarife bağlılık, kategori)
SFX = {
    "pin_click_1": ("A single wooden clothespin being unclipped from a clothesline, tiny crisp wood and spring click.", 0.5, 0.7, "core"),
    "pin_click_2": ("One small wooden clothespin snapping open, gentle woody tick with a faint metal spring.", 0.5, 0.7, "core"),
    "pin_click_3": ("A wooden clothes peg released from a rope, soft dry wooden click.", 0.5, 0.7, "core"),
    "cloth_1": ("A cotton shirt pulled off a clothesline with a soft fabric swish through the air.", 0.8, 0.6, "core"),
    "cloth_2": ("Soft linen fabric whooshing gently through the air, short cloth rustle.", 0.8, 0.6, "core"),
    "cloth_3": ("A light cotton towel flicked once, soft airy fabric flutter.", 0.8, 0.6, "core"),
    "fold_puff": ("A freshly folded soft cotton towel dropped into a wicker basket, a gentle soft thump with an airy fabric poof, warm and satisfying.", 0.9, 0.6, "basket"),
    "note": ("A single warm soft kalimba note, one pluck, C5, gentle natural decay, dry, no reverb.", 1.2, 0.8, "basket"),
    "wring": ("Wringing out a wet cloth by hand, short squeeze with a few water drips falling.", 1.0, 0.6, "core"),
    "unlock": ("A small wooden latch clicking open followed by two soft pleasant glass chime notes rising.", 1.4, 0.6, "reward"),
    "wind": ("A sudden strong gust of wind sweeping through a garden, leaves and laundry flapping, swelling then fading.", 3.0, 0.5, "spot"),
    "win": ("A short gentle success jingle on kalimba and soft glockenspiel, five rising notes with a soft shimmer, cozy and satisfying, ends on a warm resolved chord.", 3.0, 0.6, "reward"),
    "success": ("A short cheerful success jingle, bright soft marimba arpeggio with a gentle glockenspiel shimmer, uplifting, warm, resolves cleanly.", 2.0, 0.6, "reward"),
    "basket_slide": ("A wicker laundry basket sliding softly across grass, short gentle rustling drag.", 0.8, 0.6, "core"),
    "sparkle": ("A very soft delicate magical sparkle, tiny high bells twinkling briefly, gentle.", 0.9, 0.6, "reward"),
    "blocked": ("A soft muffled tug on a piece of fabric that does not come loose, gentle dull cloth pull.", 0.5, 0.6, "core"),
    "lock_rattle": ("A tiny wooden latch rattling briefly, locked, soft and small.", 0.5, 0.6, "core"),
    "rack_hang": ("A wooden clothes hanger being hooked onto a wooden rail, soft woody clack with a little fabric rustle.", 0.6, 0.6, "core"),
    "ui_soft": ("A very soft rounded wooden button tap for a cozy game interface, short and gentle.", 0.5, 0.7, "ui"),
    "ui_tap": ("A soft clean wooden tap on a small wooden block, pleasant mid pitch, short, for a cozy mobile game button.", 0.5, 0.7, "ui"),
    "level_start": ("A light fresh breeze whoosh followed by one gentle warm chime, calm and inviting.", 1.3, 0.6, "reward"),
    "coin": ("Three small coins dropping softly into a cloth pouch, gentle muted clinks.", 0.9, 0.6, "reward"),
    "lose": ("A soft sad descending three-note kalimba phrase fading into a gentle sigh of wind, tender not harsh.", 2.2, 0.6, "reward"),
    "machine_door": ("A washing machine door closing with a soft rubbery clunk and a small click, close and gentle.", 0.7, 0.6, "core"),
    "machine_tumble": ("A washing machine drum turning slowly with soft sloshing water and fabric tumbling, gentle, short.", 2.0, 0.5, "spot"),
    "machine_done": ("A clear friendly chime from a washing machine finishing its cycle: two warm rounded bell-like notes, medium loud, clean, cozy.", 1.0, 0.7, "reward"),
    "dryer_tumble": ("A tumble dryer drum turning with soft dry fabric tumbling and a low warm hum, gentle, short.", 2.0, 0.5, "spot"),
    "bird_chirp": ("A small songbird chirping twice, cute, close, clear, gentle.", 0.8, 0.6, "spot"),
    "bird_flutter": ("A small bird taking off with quick soft wing flutters, light and airy.", 0.7, 0.6, "spot"),
    "bird_splat": ("A tiny soft wet plop, cartoonish but subtle, a small drop landing on fabric.", 0.5, 0.6, "spot"),
    "rain_patter": ("A gentle rain shower pattering clearly on fabric and grass, close microphone, steady soft drops at medium volume, cozy, fading out at the end.", 2.5, 0.5, "spot"),
    "cat_meow": ("A small cute cat meowing once, soft and sleepy.", 0.9, 0.6, "spot"),
    "cat_purr": ("A cat purring contentedly, close and soft, short.", 1.5, 0.6, "spot"),
    "mud_squish": ("A soft muddy squish, small and gentle, wet cloth.", 0.5, 0.6, "core"),
    "chest_open": ("A small wooden treasure chest lid slowly creaking open with a soft wooden creak, then a gentle magical shimmer of tiny bells ringing out and fading, about one second long.", 1.4, 0.6, "reward"),
    "purchase": ("A soft satisfying cash register style ding with a gentle coin sparkle, cozy game shop purchase.", 1.0, 0.6, "reward"),
}
# Döngülü ortam yatakları: loop=True ile üretilir, ayrıca kuyruk başa çapraz geçişle bağlanır.
AMBIENCE = {
    "garden_ambience": ("Calm sunny garden ambience, very gentle breeze in leaves, a few distant soft songbirds, peaceful and quiet, no people, no traffic.", 22.0, 0.5),
    "beach_ambience": ("Calm beach ambience, gentle small waves lapping on sand, soft sea breeze, a few distant seagulls, peaceful and quiet, no people.", 22.0, 0.5),
    "rooftop_ambience": ("Quiet city rooftop ambience, soft distant city hum, light breeze, occasional far away pigeons, peaceful, no traffic horns, no voices.", 22.0, 0.5),
    "night_ambience": ("Calm summer night garden ambience, soft crickets, gentle breeze, very peaceful and quiet.", 22.0, 0.5),
}
AMBIENCE_CROSS_S = 1.5
ALIGN = 2048

COMMON_MUSIC = (" Instrumental only, no vocals. Constant gentle dynamics from the first second to the last: no intro, "
                "no build-up, no drop, no ending, no fade, so the track loops seamlessly. Smooth warm mix with soft "
                "highs, nothing sharp or harsh.")
# ad: (tarif, üretilen süre ms, çapraz geçiş sn). Çıktı süresi = üretilen - çapraz geçiş.
MUSIC = {
    "music_menu": ("Warm, inviting main-menu theme for a cozy laundry puzzle game. A gentle memorable melodic hook "
                   "of four bars played on warm kalimba and felt piano, answered by soft nylon-string guitar, "
                   "airy sustained pad underneath, very light shaker only. 88 bpm, C major, calm and hopeful, "
                   "a little more melodic and present than the in-game music." + COMMON_MUSIC, 79000, 4.0),
    "music_garden": ("Sparse soft ambient in-game music for a relaxing puzzle in a sunny garden. Slow fingerpicked "
                     "nylon guitar and a few spaced kalimba notes, airy warm pad, lots of space between notes. "
                     "72 bpm, C major, ASMR-soft, very low dynamics, no drums, no percussion, no bass drum, "
                     "nothing rhythmic that competes with sound effects." + COMMON_MUSIC, 99000, 4.0),
    "music_beach": ("Sparse soft ambient in-game music for a relaxing puzzle on a calm beach. Gentle plucked ukulele "
                    "and a few spaced kalimba notes, soft marimba, airy shimmering pad like distant sea haze. "
                    "76 bpm, G major, ASMR-soft, very low dynamics, no drums, no percussion, nothing rhythmic "
                    "that competes with sound effects." + COMMON_MUSIC, 99000, 4.0),
    "music_rooftop": ("Sparse soft ambient in-game music for a relaxing puzzle on a quiet city rooftop at golden hour. "
                      "Mellow electric piano and a few spaced kalimba notes, soft vibraphone, warm low pad, "
                      "dreamy and a little urban. 70 bpm, F major, ASMR-soft, very low dynamics, no drums, "
                      "no percussion, nothing rhythmic that competes with sound effects." + COMMON_MUSIC, 99000, 4.0),
    "music_night": ("Very quiet sparse night-time ambient in-game music for a relaxing puzzle under the stars. "
                    "Celesta, music-box and kalimba with a few slow spaced notes, deep soft warm pad, dreamy. "
                    "60 bpm, C major, lullaby-like, extremely low dynamics, no drums, no percussion, "
                    "nothing rhythmic." + COMMON_MUSIC, 89000, 4.0),
}
ALIASES = {"pin_click": "pin_click_1", "cloth": "cloth_1"}
# Müzik: hedef çıkış süresi sn (doğrulama için), OGG kalite (ffmpeg yerleşik vorbis; libvorbis yok).
OGG_QUALITY = 4

START_REL_DB = -42.0   # tepeye göre baştaki sessizlik eşiği
END_REL_DB = -50.0     # tepeye göre sondaki sessizlik eşiği
PRE_ROLL_S = 0.004
TAIL_KEEP_S = 0.12
FADE_OUT_S = 0.05
FADE_IN_S = 0.004


def load_client():
    """Anahtarı `.env.local` dosyasından ortama alır (yazdırmadan) ve SDK'ya açıkça verir."""
    if not os.path.exists(ENV_PATH):
        sys.exit("hata: .env.local yok")
    from dotenv import load_dotenv
    from elevenlabs import ElevenLabs
    load_dotenv(ENV_PATH)
    return ElevenLabs(api_key=os.environ.get("ELEVENLABS_API_KEY"))


def account(client):
    """Yalnız sayılar: katman, durum, sınır, kullanılan, kalan, sıfırlanma."""
    sub = client.user.subscription.get()
    used, limit = int(sub.character_count), int(sub.character_limit)
    print("tier=%s status=%s credit_limit=%d used=%d remaining=%d reset_unix=%s" % (
        sub.tier, sub.status, limit, used, limit - used, sub.next_character_count_reset_unix))
    return sub.tier, limit, used


def ledger_read():
    return json.load(open(LEDGER_PATH, encoding="utf-8")) if os.path.exists(LEDGER_PATH) else []


def ledger_add(entry):
    os.makedirs(RAW_DIR, exist_ok=True)
    rows = ledger_read()
    entry["time"] = time.strftime("%Y-%m-%dT%H:%M:%S")
    rows.append(entry)
    json.dump(rows, open(LEDGER_PATH, "w", encoding="utf-8"), indent=1)


def plan_rows():
    """(ad, tür, saniye, tarif, model) — üretilecek her varlık."""
    rows = []
    for name, (text, seconds, _influence, _cat) in SFX.items():
        rows.append((name, "sfx", seconds, text + STYLE, SFX_MODEL))
    for name, (text, seconds, _influence) in AMBIENCE.items():
        rows.append((name, "ambience", seconds, text, SFX_MODEL))
    for name, (text, length_ms, _cross) in MUSIC.items():
        rows.append((name, "music", length_ms / 1000.0, text, MUSIC_MODEL))
    return rows


def estimate():
    total = 0
    for name, kind, seconds, _text, _model in plan_rows():
        credits = seconds / 60.0 * MUSIC_CREDITS_PER_MINUTE if kind == "music" else seconds * SFX_CREDITS_PER_SECOND
        total += credits
    sfx = sum(r[2] for r in plan_rows() if r[1] != "music")
    music = sum(r[2] for r in plan_rows() if r[1] == "music")
    print("istek=%d sfx+ortam=%.1f sn  muzik=%.0f sn  tahmini kredi=%d" % (len(plan_rows()), sfx, music, total))
    return total


def save_stream(audio, path):
    with open(path, "wb") as handle:
        for chunk in audio:
            handle.write(chunk)


def generate(client, name, kind, retry):
    """Tek varlığı üretir ve ham dosyayı kaydeder. Ham dosya varsa dokunmaz (kredi korunur)."""
    raw = os.path.join(RAW_DIR, name + ".mp3")
    if os.path.exists(raw) and not retry:
        return False
    if os.path.exists(raw) and retry:
        shutil.move(raw, raw + ".try1")
    os.makedirs(RAW_DIR, exist_ok=True)
    if kind == "music":
        text, length_ms, _cross = MUSIC[name]
        audio = client.music.compose(prompt=text, music_length_ms=length_ms, model_id=MUSIC_MODEL,
                                     force_instrumental=True)
        seconds, model = length_ms / 1000.0, MUSIC_MODEL
    else:
        if kind == "ambience":
            text, seconds, influence = AMBIENCE[name]
            loop, prompt = True, text
        else:
            text, seconds, influence, _cat = SFX[name]
            loop, prompt = False, text + STYLE
        audio = client.text_to_sound_effects.convert(text=prompt, model_id=SFX_MODEL, duration_seconds=seconds,
                                                     prompt_influence=influence, loop=loop,
                                                     output_format=SFX_FORMAT)
        model = SFX_MODEL
    save_stream(audio, raw)
    ledger_add({"name": name, "kind": kind, "model": model, "seconds": seconds, "retry": bool(retry),
                "prompt": prompt if kind != "music" else text})
    print("uretildi:", name)
    return True


# --- işleme -----------------------------------------------------------------------------------

def write_wav(path, data):
    """float [-1,1] mono/stereo -> 16 bit WAV."""
    pcm = np.clip(data, -1.0, 1.0)
    pcm = (pcm * 32767.0).round().astype("<i2")
    with wave.open(path, "wb") as handle:
        handle.setnchannels(1 if pcm.ndim == 1 else pcm.shape[1])
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(pcm.tobytes())


def write_float_wav(path, data):
    raw = np.asarray(data, dtype="<f4")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "f32le", "-ac", str(1 if raw.ndim == 1 else raw.shape[1]),
                    "-ar", str(RATE), "-i", "-", "-c:a", "pcm_f32le", path], input=raw.tobytes(), check=True)


def trim_and_fade(mono):
    """Baştaki ve sondaki sessizliği tepeye göre kırpar; doğal sönümün `TAIL_KEEP_S` kadarı kalır."""
    peak = float(np.max(np.abs(mono))) + 1e-9
    start_thr = peak * 10 ** (START_REL_DB / 20.0)
    end_thr = peak * 10 ** (END_REL_DB / 20.0)
    above_start = np.where(np.abs(mono) > start_thr)[0]
    above_end = np.where(np.abs(mono) > end_thr)[0]
    first = max(int(above_start[0]) - int(PRE_ROLL_S * RATE), 0) if len(above_start) else 0
    last = min(int(above_end[-1]) + int(TAIL_KEEP_S * RATE), len(mono)) if len(above_end) else len(mono)
    out = mono[first:last].copy()
    fade_in = min(int(FADE_IN_S * RATE), len(out) // 4)
    fade_out = min(int(FADE_OUT_S * RATE), len(out) // 2)
    if fade_in:
        out[:fade_in] *= np.linspace(0.0, 1.0, fade_in, dtype=np.float32)
    if fade_out:
        out[-fade_out:] *= np.linspace(1.0, 0.0, fade_out, dtype=np.float32)
    return out


def level_gain(path_wav, category):
    """Kategori hedefine göre kazanç (dB) ve ölçümler."""
    target, ceiling = LEVELS[category]
    integrated, true_peak = audio_lib.lufs(path_wav, pad_s=1.0)
    gain = min(target - integrated, ceiling - true_peak, MAX_GAIN_DB)
    return gain, integrated, true_peak


def process_sfx(name, category, report):
    raw = os.path.join(RAW_DIR, name + ".mp3")
    # 70 Hz altı hışırtı atılır (telefon hoparlörü zaten çalmaz; limitörün boşuna çalışmasını önler).
    mono = audio_lib.decode_filtered(raw, "highpass=f=70", channels=1)[:, 0]
    trimmed = trim_and_fade(mono)
    with tempfile.TemporaryDirectory() as tmp:
        probe = os.path.join(tmp, "p.wav")
        write_float_wav(probe, trimmed)
        gain, integrated, true_peak = level_gain(probe, category)
    final = trimmed * (10 ** (gain / 20.0))
    target = os.path.join(SFX_DIR, name + ".wav")
    write_wav(target, final)
    report[name] = {"kind": "sfx", "category": category, "raw_s": round(len(mono) / RATE, 2),
                    "gain_db": round(gain, 1)}


def crossfade_loop(data, cross_s):
    """Kuyruğu başa eşit güçlü çapraz geçişle bağlar: döngü başa sardığında aynı yerden sürer."""
    fade = int(RATE * cross_s)
    # Çıkış uzunluğu 2048'in katı olsun: yerleşik vorbis kodlayıcı sonu sıfırla doldurup 64'e yuvarlıyordu
    # (döngü sonunda ~12 örneklik sessizlik = tık). Çapraz geçiş en çok 2047 örnek uzar.
    fade = len(data) - ((len(data) - fade) // ALIGN) * ALIGN
    body = data[fade:].copy()
    phase = np.linspace(0.0, np.pi / 2, fade, dtype=np.float32)[:, None]
    tail_gain, head_gain = np.cos(phase), np.sin(phase)
    body[-fade:] = body[-fade:] * tail_gain + data[:fade] * head_gain
    return body


def loudnorm_two_pass(src, dst, target_i, target_tp, channels):
    """ffmpeg loudnorm iki geçiş (doğrusal mod): ölçüm sonrası sabit kazançla hedefe oturtur."""
    first = subprocess.run(
        ["ffmpeg", "-nostats", "-i", src, "-af", "loudnorm=I=%.1f:TP=%.1f:LRA=11:print_format=json" % (target_i, target_tp),
         "-f", "null", "-"], capture_output=True, text=True).stderr
    block = json.loads(first[first.rindex("{"):first.rindex("}") + 1])
    flt = ("loudnorm=I=%.1f:TP=%.1f:LRA=11:measured_I=%s:measured_TP=%s:measured_LRA=%s:measured_thresh=%s:"
           "offset=%s:linear=true" % (target_i, target_tp, block["input_i"], block["input_tp"], block["input_lra"],
                                      block["input_thresh"], block["target_offset"]))
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", src, "-af", flt, "-ar", str(RATE), "-ac", str(channels),
                    "-c:a", "pcm_f32le", dst], check=True)
    return block


def process_loop(name, kind, report):
    """Müzik ve ortam: çapraz geçiş -> loudnorm 2 geçiş -> (müzik) OGG, (ortam) 16 bit mono WAV."""
    raw = os.path.join(RAW_DIR, name + ".mp3")
    if kind == "music":
        cross = MUSIC[name][2]
        channels, category = 2, "music"
    else:
        cross, channels, category = AMBIENCE_CROSS_S, 1, "amb"
    target_i, ceiling = LEVELS[category]
    # Ortamda 40 Hz altı gürültü, müzikte 30 Hz altı atılır; tepe payı için loudnorm TP biraz düşük verilir.
    data = audio_lib.decode_filtered(raw, "highpass=f=%d" % (40 if kind == "ambience" else 30), channels=channels)
    looped = crossfade_loop(data, cross)
    with tempfile.TemporaryDirectory() as tmp:
        pre = os.path.join(tmp, "pre.wav")
        post = os.path.join(tmp, "post.wav")
        write_float_wav(pre, looped)
        block = loudnorm_two_pass(pre, post, target_i, ceiling - 0.5, channels)
        normalised = audio_lib.decode(post, channels=channels)
        if kind == "music":
            target = os.path.join(MUSIC_DIR, name + ".ogg")
            os.makedirs(MUSIC_DIR, exist_ok=True)
            encode_ogg(post, target, ceiling)
        else:
            target = os.path.join(SFX_DIR, name + ".wav")
            write_wav(target, normalised)
    report[name] = {"kind": kind, "category": category, "raw_s": round(len(data) / RATE + cross, 2),
                    "loudnorm_input_i": block["input_i"], "loudnorm_input_tp": block["input_tp"]}


def encode_ogg(src_wav, target, ceiling):
    """ffmpeg yerleşik vorbis (libvorbis yok; kalite modu). Kayıplı kodlama tepeyi kaydırabilir: ölçüp düzeltir."""
    gain_db = 0.0
    for _attempt in range(3):
        flt = "volume=%.2fdB" % gain_db
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", src_wav, "-af", flt, "-c:a", "vorbis", "-strict",
                        "experimental", "-q:a", str(OGG_QUALITY), target], check=True)
        _i, true_peak = audio_lib.lufs(target, 0.0)
        if true_peak <= ceiling + 0.05:
            return
        gain_db -= (true_peak - ceiling) + 0.1


# --- ana akış ---------------------------------------------------------------------------------

def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    flags = [a for a in sys.argv[1:] if a.startswith("--")]
    if "--estimate" in flags:
        estimate()
        return
    client = None
    if "--process" not in flags:
        client = load_client()
    if "--account" in flags:
        account(client)
        return
    retry = "--retry" in flags
    os.makedirs(SFX_DIR, exist_ok=True)
    table = json.load(open(SOUNDS_PATH, encoding="utf-8")) if os.path.exists(SOUNDS_PATH) else {}
    report = json.load(open(REPORT_PATH, encoding="utf-8")) if os.path.exists(REPORT_PATH) else {}
    for name, kind, _seconds, _text, _model in plan_rows():
        if args and name not in args:
            continue
        try:
            if client is not None:
                generate(client, name, kind, retry)
            if not os.path.exists(os.path.join(RAW_DIR, name + ".mp3")):
                continue
            if kind == "sfx":
                process_sfx(name, SFX[name][3], report)
                table[name] = "res://assets/audio/sfx/%s.wav" % name
            elif kind == "ambience":
                process_loop(name, kind, report)
                table[name] = "res://assets/audio/sfx/%s.wav" % name
            else:
                process_loop(name, kind, report)
                table[name] = "res://assets/audio/music/%s.ogg" % name
        except Exception as error:  # noqa: BLE001 — hata adıyla raporlanır, diğer sesler sürer
            # Yalnız durum kodu ve gövde yazılır (başlıklar gürültü; anahtar hiç yazılmaz).
            detail = getattr(error, "body", None) or str(error)
            print("HATA %s: %s %s" % (name, getattr(error, "status_code", ""), str(detail)[:300]))
    for alias, original in ALIASES.items():
        source = os.path.join(SFX_DIR, original + ".wav")
        if os.path.exists(source):
            shutil.copyfile(source, os.path.join(SFX_DIR, alias + ".wav"))
            table[alias] = "res://assets/audio/sfx/%s.wav" % alias
    json.dump(dict(sorted(table.items())), open(SOUNDS_PATH, "w", encoding="utf-8"), indent=2)
    json.dump(report, open(REPORT_PATH, "w", encoding="utf-8"), indent=1)


if __name__ == "__main__":
    main()
