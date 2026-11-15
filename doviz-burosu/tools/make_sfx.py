#!/usr/bin/env python3
"""ElevenLabs ile oyunun KRİTİK seslerini (ücretli plan) üretir ve bütün sesleri ölçülü seviyeye oturtur.

    python3 tools/make_sfx.py --account             # yalnız abonelik/kredi sayıları (katman, sınır, kullanılan, kalan, sıfırlanma)
    python3 tools/make_sfx.py --estimate            # sıra, tahmini kredi (ağ yok)
    python3 tools/make_sfx.py                       # sıralı: EKSİK ham dosyaları üretir (bütçe tavanına kadar) + işler
    python3 tools/make_sfx.py stamp bell            # yalnız bu adlar
    python3 tools/make_sfx.py --retry error         # tek varlığı BİR kez yeniden üretir (eski ham dosya .try1 olur)
    python3 tools/make_sfx.py --process             # üretmez; ham önbellekten yeniden işler + kayıtları yazar (kredi harcamaz)

Anahtar `.env.local` içindeki ELEVENLABS_API_KEY'dir; yalnız python-dotenv + SDK okur, hiçbir yerde yazdırılmaz.
Ham API çıktısı `build/sfx_raw_v2/` altında saklanır (git dışı, eski ücretsiz plan dosyaları ASLA yeniden kullanılmaz);
her istek `build/sfx_raw_v2/ledger.json` dosyasına yazılır. Bütçe tavanı `CREDIT_BUDGET` kredi.
Çıktı: assets/audio/{sfx,music}/<ad>.mp3 (adlar ve çağrı yerleri değişmez), data/sounds.json (kayıt defteri),
assets/audio/PROVENANCE.md (üretim kaydı, SHA-256). Seviye kuralları `LEVELS`; ayrıntı docs/AUDIO.md.
"""
import hashlib
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
PROVENANCE_PATH = os.path.join(ROOT, "assets", "audio", "PROVENANCE.md")
ENV_PATH = os.path.join(ROOT, ".env.local")
RAW_DIR = os.path.join(ROOT, "build", "sfx_raw_v2")
LEDGER_PATH = os.path.join(RAW_DIR, "ledger.json")
REPORT_PATH = os.path.join(RAW_DIR, "processed.json")
BASELINE_PATH = os.path.join(ROOT, "build", "baseline_free_plan.json")

SFX_MODEL = "eleven_text_to_sound_v3"
MUSIC_MODEL = "music_v2_5"
SFX_FORMAT = "mp3_44100_128"
RATE = 44100
CREDIT_BUDGET = 4000          # bu iş için sert tavan (sahip onayı)
RESERVE = 150                 # tavanın altında bırakılan pay (tek yeniden deneme + ölçü sapması)
# Tahmin (yalnız ön denetim; gerçek tüketim abonelik farkından ölçülüp deftere yazılır).
SFX_CREDITS_PER_SECOND = 10  # ölçüldü: 0,6 sn efekt = 6 kredi (3 istek, sayaç farkı)
MUSIC_CREDITS_PER_MINUTE = 750  # ölçüldü: 75 sn müzik = 938 kredi; 6 sn vuruş ≈ 95

STYLE = (" Dry close recording in a quiet small 1980s government office, realistic and tactile, "
         "no music, no voice, no reverb, no background noise, not cartoonish, nothing harsh.")
AMBIENT_STYLE = " Seamless steady room tone, no music, no voice, no sudden events, nothing sharp."

# kategori: (hedef LUFS-I, gerçek tepe tavanı dBTP). Kazanç = min(hedef - ölçülen, tavan - tepe).
# Ses yöneticisi bus kazançları sabittir: SFX 0 dB, müzik parçası -5 dB, ambient -13 dB (Music bus). Hedefler buna göre:
# damga en net ses; arayüz/küçük geri bildirim daha kısık; müzik ve ambient çok altta.
LEVELS = {
    "hero": (-15.5, -1.5),     # damga (imza ses), mürekkep: en net/yüksek olay
    "core": (-19.5, -2.5),     # para/kâğıt/zil/doğru-yanlış: sürekli duyulan oyun sesleri
    "ui": (-23.5, -4.0),       # hesap makinesi tuşu, kalem, mercek: çok sık, kısık
    "stinger": (-19.0, -2.0),  # gün sonu vurgusu: chime_* olay yüksekliği (dBFS), stinger_* (6 sn müzik vuruşu) LUFS-I
    "spot": (-22.5, -3.0),     # telefon, tüp, siren, saat, floresan: arada bir
    "amb": (-24.0, -3.0),      # döngülü oda uğultusu, LUFS-I (oyunda ayrıca -13 dB)
    "music": (-18.0, -1.5),    # müzik, LUFS-I (oyunda ayrıca -5 dB)
}
# Ölçü: kısa olaylar (sfx) için "olay yüksekliği" = 150 Hz üstü en yüksek 100 ms RMS (dBFS); ambient, müzik ve stinger_* için LUFS-I.
# Darbeli seslerde (damga gibi, tepe/ortalama farkı ~25 dB) tepe tavanı LUFS hedefine ulaşmayı engeller. Hedefe varmak için sınırlayıcı
# (alimiter) ile en çok bu kadar dB EK kazanç verilir; fazlası denenmez (pompalama/bozulma olmasın).
MAX_BOOST_DB = {"hero": 9.0, "core": 6.0, "ui": 4.0, "stinger": 4.0, "spot": 4.0, "amb": 0.0, "music": 0.0}
MAX_GAIN_DB = 30.0
MIN_GAIN_DB = -30.0

# Kritiklik sırası = üretim sırası. (ad, tür, tarif, süre sn, tarife bağlılık, kategori, sıklık notu)
# tür: sfx | loop (ambient: loop=True + çapraz geçiş) | music (müzik, ms olarak süre, çapraz geçişli döngü) | sting (kısa müzik vuruşu, ms, döngüsüz)
ASSETS = [
    ("stamp", "sfx", "A heavy rubber office stamp with a wooden handle pressed firmly onto a stack of paper on a wooden counter, one solid dry thunk with a short paper slap, very short.", 0.6, 0.7, "hero", "her karar (müşteri başına 1) + not onayı; imza ses"),
    ("ink_press", "sfx", "A rubber stamp pressed down on an ink pad, a soft wet dull press, one quick press, no rattle.", 0.6, 0.7, "hero", "her kararda damganın 50 ms altında katman"),
    ("note_drop", "sfx", "A single paper banknote laid down on a wooden counter, soft paper rustle and a very light thud.", 0.6, 0.7, "core", "müşteri başına 2-4 (para/belge bırakma)"),
    ("paper_slide", "sfx", "A few sheets of paper sliding across a wooden desk, a short soft slide.", 0.8, 0.7, "core", "her sürükle-bırak + belge kayması"),
    ("bell", "sfx", "A small brass service desk bell, a single bright ding with a short natural ring, dry.", 1.0, 0.7, "core", "müşteri gelişi (4'ün 3'ü)"),
    ("coin", "sfx", "Three coins dropped into a metal cash tray, a short bright metallic clink, dry.", 0.8, 0.7, "core", "her doğru kararda"),
    ("error", "sfx", "A short low electric buzzer tone for a wrong answer on an old office device, dull and muted, a single soft buzz, not harsh.", 0.6, 0.7, "core", "her hatada"),
    ("calc_key", "sfx", "A single mechanical calculator key press, a tiny dry plastic click.", 0.5, 0.8, "ui", "hesap makinesi tuşu: oyundaki en sık ses"),
    ("footsteps", "sfx", "Three slow footsteps of a person in leather shoes walking up to a counter on a hard tiled floor indoors, dry.", 1.8, 0.7, "core", "her müşteri gelişi"),
    ("page", "sfx", "A page of a printed rulebook turning, a short dry paper rustle.", 0.8, 0.7, "core", "kural kitabı sayfası, öğretici"),
    ("drawer", "sfx", "A metal cash register drawer sliding open with a light bell ding, a short mechanical till sound.", 1.0, 0.7, "core", "doğru 'tamamla' kararı"),
    ("chime_win", "sfx", "A gentle warm bell chime of three rising notes for a finished work day, short, dry office.", 1.6, 0.7, "stinger", "gün sonu (iyi), her gün"),
    ("chime_fail", "sfx", "A low dull bell strike with a slow fade, sad and short, dry office.", 1.6, 0.7, "stinger", "gün sonu (kötü) / oyun kaybı"),
    ("door_buzz", "sfx", "An old office door entry buzzer, one short electric buzz, then a heavy door clicking open.", 1.3, 0.7, "core", "her 4. müşteri gelişi"),
    ("crumple", "sfx", "A sheet of paper being crumpled in a fist, short.", 0.8, 0.7, "core", "el koyma kararı"),
    ("siren", "sfx", "A short police siren whoop heard through a window, two rising tones, muffled and distant.", 1.5, 0.7, "spot", "polis kararı"),
    ("pen_scratch", "sfx", "A fountain pen scratching a signature on paper, short.", 1.0, 0.7, "ui", "not sayfası imzası"),
    ("lens", "sfx", "A magnifying glass sliding on a wooden desk, a short glassy scrape.", 0.8, 0.7, "ui", "mercek aracı"),
    ("uv_on", "sfx", "An ultraviolet lamp switching on: a soft click then a short electric hum rising, short.", 1.2, 0.7, "ui", "UV lambası aracı"),
    ("clock_tick", "sfx", "A large wall clock ticking steadily, four ticks, dry quiet room.", 2.0, 0.7, "spot", "günün son dakikalarında her 2 sn"),
    ("flicker", "sfx", "A fluorescent tube flickering and buzzing for a moment then steadying, short.", 1.4, 0.7, "spot", "rastgele (~20-35 sn'de bir)"),
    ("phone", "sfx", "An old rotary telephone ringing twice in a quiet office, dry.", 2.0, 0.7, "spot", "ofis aramaları, gün başına birkaç"),
    ("tube", "sfx", "A pneumatic tube capsule whooshing down a pipe and landing with a soft metallic thunk in a wooden tray, short, dry.", 1.6, 0.7, "spot", "ofis notları, gün başına birkaç"),
    ("stinger_win", "sting", "A very short warm victory sting for finishing the story: three soft piano notes rising and a gentle chord, instrumental.", 6000, 0.7, "stinger", "oyun sonu (iyi), oyunda bir kez"),
    ("ambient", "loop", "Quiet empty government office room tone, faint fluorescent light hum, distant muffled city noise outside, steady and seamless.", 12.0, 0.5, "amb", "her ekranda sürekli (kısık)"),
    ("desk_calm", "music", "Tense but steady background music for working at a counter all day: a minimal repeating pattern of muted piano and plucked double bass, a soft wood-block clock-like pulse, a low string drone, understated bureaucratic suspense, no melody climax, instrumental.", 75000, 0.0, "music", "gişe müziği: oyun süresinin çoğu"),
    ("theme_main", "music", "Main theme of a melancholic bureaucratic drama game: a slow, wistful waltz in a minor key played by a solo accordion and a muted upright piano, a soft typewriter-like rhythmic ticking, a lonely clarinet answering the melody, restrained and dignified, grey office nostalgia, lo-fi vintage recording, instrumental, memorable simple main melody.", 75000, 0.0, "music", "ana menü, her açılış"),
    ("morning", "music", "A short gentle morning piece for an old city newspaper: pizzicato strings and a soft clarinet playing a light, slightly sleepy tune, a faint typewriter rhythm, tired but warm, instrumental.", 45000, 0.0, "music", "her gün başı"),
    ("evening", "music", "Quiet evening at a small apartment after a hard day: a tender solo piano with a warm cello, slow and intimate, a little sad, a little grateful, instrumental.", 60000, 0.0, "music", "her gün sonu"),
    ("desk_tense", "music", "Rising pressure for the last hour of a work shift: a minimal muted piano and plucked bass pattern, faster, a ticking clock pulse, swelling low strings, anxious but controlled, instrumental.", 75000, 0.0, "music", "günün son bölümü"),
    ("stinger_fail", "sting", "A very short sad sting for a failure: two low piano notes and a muted brass sigh, instrumental.", 6000, 0.7, "stinger", "çağrılmıyor (kodda kullanılmıyor)"),
    ("buzzer", "sfx", "A short office buzzer for denied entry, one dull buzz, dry, not harsh.", 0.7, 0.7, "core", "çağrılmıyor"),
    ("typewriter", "sfx", "An old mechanical typewriter typing a short burst of keys and a carriage return bell, dry.", 2.0, 0.7, "ui", "çağrılmıyor (daktilo etkisi kodla bip)"),
    ("cash_slide", "sfx", "Banknotes and a few coins sliding through a metal tray slot, short.", 0.9, 0.7, "core", "çağrılmıyor"),
    ("coins_pile", "sfx", "A handful of coins poured into a tin cup, a short dry jingle.", 1.2, 0.7, "core", "çağrılmıyor"),
    ("ending_warm", "music", "A gentle hopeful ending theme: a soft waltz melody on piano and accordion resolving into a major key, warm strings, tearful and kind, instrumental.", 40000, 0.0, "music", "oyun sonu, oyunda bir kez"),
    ("ending_dark", "music", "A grey somber ending theme: a slow minor-key waltz melody on a lonely accordion with a distant clock ticking, cold strings, resigned and quiet, instrumental.", 40000, 0.0, "music", "oyun sonu, oyunda bir kez"),
    ("ending_escape", "music", "A bittersweet travelling ending theme: a light train-like rhythm with clarinet and accordion playing a hopeful waltz melody, freedom mixed with guilt, instrumental.", 40000, 0.0, "music", "oyun sonu, oyunda bir kez"),
]
ORDER = [a[0] for a in ASSETS]
INFO = {a[0]: a for a in ASSETS}
LOOP_NAMES = {"ambient", "desk_calm", "desk_tense", "theme_main", "morning", "evening"}
MUSIC_COMMON = (" Constant gentle dynamics from the first second to the last: no intro, no build-up, no drop, no ending, "
                "no fade, so the track loops seamlessly. Smooth warm mix, nothing sharp or harsh.")
MUSIC_CROSS_S = 3.0
AMBIENT_CROSS_S = 1.5
START_REL_DB = -42.0
END_REL_DB = -50.0
PRE_ROLL_S = 0.003
TAIL_KEEP_S = 0.12
FADE_OUT_S = 0.05
FADE_IN_S = 0.003
MP3_BITRATE = {"sfx": "96k", "loop": "96k", "music": "128k", "sting": "128k"}
MUSIC_API = ("music", "sting")


def directory_of(name):
    return MUSIC_DIR if INFO[name][2] and name in ("desk_calm", "desk_tense", "theme_main", "morning", "evening", "ending_warm", "ending_dark",
                                                  "ending_escape", "stinger_win", "stinger_fail") else SFX_DIR


def out_path(name):
    return os.path.join(directory_of(name), name + ".mp3")


def kind_of(name):
    return INFO[name][1]


def prompt_of(name):
    info = INFO[name]
    if info[1] == "music":
        return info[2] + MUSIC_COMMON
    if info[1] == "loop":
        return info[2] + AMBIENT_STYLE
    if info[1] == "sting":
        return info[2]
    return info[2] + STYLE


def seconds_of(name):
    info = INFO[name]
    return info[3] / 1000.0 if info[1] in MUSIC_API else float(info[3])


def estimate_credits(name):
    secs = seconds_of(name)
    return secs / 60.0 * MUSIC_CREDITS_PER_MINUTE if kind_of(name) in MUSIC_API else secs * SFX_CREDITS_PER_SECOND


# --- hesap, defter ----------------------------------------------------------------------------

def load_client():
    """Anahtarı `.env.local` dosyasından ortama alır (yazdırmadan) ve SDK'ya açıkça verir."""
    if not os.path.exists(ENV_PATH):
        sys.exit("hata: .env.local yok")
    from dotenv import load_dotenv
    from elevenlabs import ElevenLabs
    load_dotenv(ENV_PATH)
    return ElevenLabs(api_key=os.environ.get("ELEVENLABS_API_KEY"))


def account(client, quiet=False):
    """Yalnız sayılar: katman, durum, sınır, kullanılan, kalan, sıfırlanma."""
    sub = client.user.subscription.get()
    used, limit = int(sub.character_count), int(sub.character_limit)
    if not quiet:
        print("tier=%s status=%s credit_limit=%d used=%d remaining=%d reset_unix=%s" % (
            sub.tier, sub.status, limit, used, limit - used, sub.next_character_count_reset_unix))
    return str(sub.tier), used, limit


def ledger_read():
    return json.load(open(LEDGER_PATH, encoding="utf-8")) if os.path.exists(LEDGER_PATH) else []


def ledger_add(entry):
    os.makedirs(RAW_DIR, exist_ok=True)
    rows = ledger_read()
    entry["time"] = time.strftime("%Y-%m-%dT%H:%M:%S")
    rows.append(entry)
    json.dump(rows, open(LEDGER_PATH, "w", encoding="utf-8"), indent=1)


def spent_credits():
    return sum(float(r.get("credits_measured", 0)) for r in ledger_read())


def estimate():
    total = 0.0
    print("%-3s %-14s %-6s %7s %9s" % ("sıra", "ad", "tür", "süre", "tah.kredi"))
    for index, name in enumerate(ORDER, 1):
        credits = estimate_credits(name)
        total += credits
        print("%-3d %-14s %-6s %7.1f %9.0f   toplam %6.0f" % (index, name, kind_of(name), seconds_of(name), credits, total))


def save_stream(audio, path):
    with open(path, "wb") as handle:
        for chunk in audio:
            handle.write(chunk)


def generate(client, name, retry):
    """Tek varlığı üretir; ham dosyayı kaydeder; gerçek krediyi abonelik farkından ölçüp deftere yazar. Ham dosya varsa dokunmaz."""
    raw = os.path.join(RAW_DIR, name + ".mp3")
    if os.path.exists(raw) and not retry:
        return False
    if os.path.exists(raw) and retry:
        shutil.move(raw, raw + ".try1")
    os.makedirs(RAW_DIR, exist_ok=True)
    tier, before, _limit = account(client, quiet=True)
    if tier == "free":
        sys.exit("DURDU: plan 'free'")
    kind, prompt, secs = kind_of(name), prompt_of(name), seconds_of(name)
    if kind in MUSIC_API:
        audio = client.music.compose(prompt=prompt, music_length_ms=int(secs * 1000), model_id=MUSIC_MODEL, force_instrumental=True)
        model = MUSIC_MODEL
    else:
        audio = client.text_to_sound_effects.convert(text=prompt, model_id=SFX_MODEL, duration_seconds=secs,
                                                     prompt_influence=INFO[name][4], loop=(kind == "loop"),
                                                     output_format=SFX_FORMAT)
        model = SFX_MODEL
    save_stream(audio, raw)
    # Abonelik sayacı gecikmeli güncellenir: değişene dek (en çok ~32 sn) beklenir; değişmezse 0 yazılır ve sonda toplam farkla uzlaştırılır.
    after = before
    for _wait in range(8):
        time.sleep(4)
        _tier, after, _limit = account(client, quiet=True)
        if after != before:
            break
    ledger_add({"name": name, "kind": kind, "model": model, "seconds": secs, "retry": bool(retry), "prompt": prompt,
                "credits_measured": after - before, "credits_used_after": after})
    print("uretildi: %-13s %5.1f sn  kredi=%d  (toplam bu iş %d)" % (name, secs, after - before, spent_credits()))
    return True


# --- işleme -----------------------------------------------------------------------------------

def write_float_wav(path, data, channels):
    raw = np.asarray(data, dtype="<f4")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "f32le", "-ac", str(channels), "-ar", str(RATE), "-i", "-",
                    "-c:a", "pcm_f32le", path], input=raw.tobytes(), check=True)


def trim_and_fade(data):
    """Baştaki/sondaki sessizliği tepeye göre kırpar; doğal sönümün `TAIL_KEEP_S` kadarı kalır. data: [örnek, kanal]."""
    mono_abs = np.abs(data).max(axis=1)
    peak = float(mono_abs.max()) + 1e-9
    above_start = np.where(mono_abs > peak * 10 ** (START_REL_DB / 20.0))[0]
    above_end = np.where(mono_abs > peak * 10 ** (END_REL_DB / 20.0))[0]
    first = max(int(above_start[0]) - int(PRE_ROLL_S * RATE), 0) if len(above_start) else 0
    last = min(int(above_end[-1]) + int(TAIL_KEEP_S * RATE), len(data)) if len(above_end) else len(data)
    out = data[first:last].copy()
    fade_in = min(int(FADE_IN_S * RATE), len(out) // 4)
    fade_out = min(int(FADE_OUT_S * RATE), len(out) // 2)
    if fade_in:
        out[:fade_in] *= np.linspace(0.0, 1.0, fade_in, dtype=np.float32)[:, None]
    if fade_out:
        out[-fade_out:] *= np.linspace(1.0, 0.0, fade_out, dtype=np.float32)[:, None]
    return out


def crossfade_loop(data, cross_s):
    """Kuyruğu başa eşit güçlü çapraz geçişle bağlar: döngü başa sardığında aynı yerden sürer."""
    fade = int(RATE * cross_s)
    body = data[fade:].copy()
    phase = np.linspace(0.0, np.pi / 2, fade, dtype=np.float32)[:, None]
    body[-fade:] = body[-fade:] * np.cos(phase) + data[:fade] * np.sin(phase)
    return body


def encode_mp3(src_wav, target, bitrate, ceiling, gain_db=0.0, channels=None, limit_db=None):
    """libmp3lame; kayıplı kodlama tepeyi kaydırabilir: ölçüp tavanın altına çeker. limit_db verilirse kazançtan sonra sınırlayıcı çalışır."""
    for _attempt in range(5):
        flt = "volume=%.2fdB" % gain_db
        if limit_db is not None:
            flt += ",alimiter=limit=%.4f:attack=0.5:release=8:level=disabled" % (10 ** (limit_db / 20.0))
        cmd = ["ffmpeg", "-y", "-loglevel", "error", "-i", src_wav, "-af", flt]
        if channels:
            cmd += ["-ac", str(channels)]
        cmd += ["-c:a", "libmp3lame", "-b:a", bitrate, "-ar", str(RATE), target]
        subprocess.run(cmd, check=True)
        _i, true_peak = audio_lib.lufs(target, 0.0)
        if true_peak <= ceiling + 0.05:
            return
        if limit_db is not None:
            limit_db -= (true_peak - ceiling) + 0.1
        else:
            gain_db -= (true_peak - ceiling) + 0.1


def render_chain(src, gain_db, limit_db, dst):
    flt = "volume=%.2fdB" % gain_db
    if limit_db is not None:
        flt += ",alimiter=limit=%.4f:attack=0.5:release=8:level=disabled" % (10 ** (limit_db / 20.0))
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", src, "-af", flt, "-c:a", "pcm_f32le", dst], check=True)


def level_gain(path_wav, category, kind):
    """Dönüş: (kazanç dB, ölçü, ölçülen gerçek tepe, sınırlayıcı tavanı dB ya da None).
    Kısa olaylarda (sfx) ölçü "olay yüksekliği"dir ve sınırlayıcı etkisi dahil yinelemeli aranır: önce tepe tavanına göre doğal kazanç,
    hedef tutmuyorsa sınırlayıcıyla kategori için izinli EK kazanç (MAX_BOOST_DB) kadar yukarı. Döngülerde ve müzik vuruşlarında (ambient, müzik, stinger_*) LUFS-I, sınırlayıcısız."""
    target, ceiling = LEVELS[category]
    if kind != "sfx":
        level, true_peak = audio_lib.lufs(path_wav, pad_s=0.0)
        return max(MIN_GAIN_DB, min(target - level, ceiling - true_peak, MAX_GAIN_DB)), level, true_peak, None
    _lufs, true_peak = audio_lib.lufs(path_wav, pad_s=0.5)
    level = audio_lib.event_level_of(path_wav)
    natural = ceiling - true_peak
    high = natural + MAX_BOOST_DB[category]
    gain = min(target - level, natural)
    if target - level <= natural or MAX_BOOST_DB[category] <= 0:
        return max(MIN_GAIN_DB, gain), level, true_peak, None
    limit = ceiling - 0.7
    gain = natural
    with tempfile.TemporaryDirectory() as tmp:
        out = os.path.join(tmp, "o.wav")
        for _step in range(5):
            render_chain(path_wav, gain, limit, out)
            reached = audio_lib.event_level_of(out)
            if abs(target - reached) < 0.25 or (reached < target and gain >= high - 0.01):
                break
            gain = min(high, gain + (target - reached))
    return gain, level, true_peak, limit


def process_new(name, report):
    """Yeni ham dosya: kırp -> (döngüyse çapraz geçiş) -> seviye -> mp3."""
    kind, category = kind_of(name), INFO[name][5]
    raw = os.path.join(RAW_DIR, name + ".mp3")
    channels = 2 if kind in MUSIC_API else 1
    # Telefon hoparlörü için: sfx'te 70 Hz altı ve 9,5 kHz üstü (tiz hışırtı) yumuşatılır, ambient'te 8 kHz üstü; müzik yalnız 35 Hz altı.
    chain = {"sfx": "highpass=f=70,lowpass=f=9500", "loop": "highpass=f=35,lowpass=f=8000"}.get(kind, "highpass=f=35")
    data = audio_lib.decode_filtered(raw, chain, channels=channels)
    if kind in ("sfx", "sting"):
        data = trim_and_fade(data)
    elif kind == "loop":
        data = crossfade_loop(data, AMBIENT_CROSS_S)
    else:
        data = crossfade_loop(data, MUSIC_CROSS_S)
    with tempfile.TemporaryDirectory() as tmp:
        probe = os.path.join(tmp, "p.wav")
        write_float_wav(probe, data, channels)
        gain, integrated, true_peak, limit = level_gain(probe, category, kind)
        encode_mp3(probe, out_path(name), MP3_BITRATE[kind], LEVELS[category][1], gain, channels, limit)
    report[name] = {"regenerated": True, "raw_s": round(len(audio_lib.decode(raw)) / RATE, 2), "gain_db": round(gain, 1),
                    "measured_lufs": round(integrated, 1), "measured_tp": round(true_peak, 1)}


def process_old(name, report):
    """Henüz yeniden üretilmemiş (ücretsiz plan) ses: yalnız seviye eşitleme (kazanç); içerik değişmez. Özgün git geçmişinde."""
    category = INFO[name][5]
    original = out_path(name)
    baseline = json.load(open(BASELINE_PATH, encoding="utf-8")).get(name) if os.path.exists(BASELINE_PATH) else None
    backup = os.path.join(RAW_DIR, "freeplan_" + name + ".mp3")
    if not os.path.exists(backup):  # özgün bir kez saklanır; tekrar işlemede nesil kaybı olmasın
        os.makedirs(RAW_DIR, exist_ok=True)
        shutil.copyfile(original, backup)
    channels = int(subprocess.run(["ffprobe", "-v", "error", "-select_streams", "a:0", "-show_entries", "stream=channels",
                                   "-of", "csv=p=0", backup], capture_output=True, text=True).stdout.strip() or 1)
    data = audio_lib.decode(backup, channels=channels)
    kind = kind_of(name)
    with tempfile.TemporaryDirectory() as tmp:
        probe = os.path.join(tmp, "p.wav")
        write_float_wav(probe, data, channels)
        gain, integrated, true_peak, _limit = level_gain(probe, category, kind)
        if abs(gain) >= 1.0:
            encode_mp3(probe, original, MP3_BITRATE[kind], LEVELS[category][1], gain, channels)
        else:
            gain = 0.0
    report[name] = {"regenerated": False, "gain_db": round(gain, 1), "measured_lufs": round(integrated, 1),
                    "measured_tp": round(true_peak, 1), "baseline": baseline and {"lufs_i": baseline["lufs_i"], "tp": baseline["true_peak_db"]}}


# --- kayıtlar ---------------------------------------------------------------------------------

def sha256(path):
    return hashlib.sha256(open(path, "rb").read()).hexdigest()


def regenerated_names():
    """Ledger'da ham dosyası + kaydı olan adlar (son kayıt geçerli)."""
    done = {}
    for row in ledger_read():
        done[row["name"]] = row
    return {n: r for n, r in done.items() if os.path.exists(os.path.join(RAW_DIR, n + ".mp3"))}


def write_registry(report):
    done = regenerated_names()
    table = {}
    for rank, name in enumerate(ORDER, 1):
        info = INFO[name]
        folder = "music" if directory_of(name) == MUSIC_DIR else "sfx"
        entry = {"path": "res://assets/audio/%s/%s.mp3" % (folder, name), "kind": "music" if info[1] in MUSIC_API else "sfx",
                 "category": info[5], "rank": rank, "loop": name in LOOP_NAMES, "usage": info[6],
                 "regenerated": name in done, "source": "elevenlabs-paid-plan" if name in done else "elevenlabs-free-plan",
                 "sha256": sha256(out_path(name))}
        if name in done:
            entry.update({"model": done[name]["model"], "date": done[name]["time"][:10]})
        table[name] = entry
    json.dump(table, open(SOUNDS_PATH, "w", encoding="utf-8"), indent=2, ensure_ascii=False)
    json.dump(report, open(REPORT_PATH, "w", encoding="utf-8"), indent=1)
    write_provenance(done, table)


def write_provenance(done, table):
    tier, used_after = "", 0
    lines = ["# Ses üretim kaydı (PROVENANCE)", "",
             "Otomatik üretilir: `python3 tools/make_sfx.py --process`. Ayrıntı ve lisans notu: `docs/AUDIO_LICENSE.md`, `docs/AUDIO.md`.", "",
             "## Ücretli plan altında yeniden üretilenler", "",
             "| dosya | tarih | model | süre sn | kredi | SHA-256 (gönderilen mp3) | tarif |", "|---|---|---|---:|---:|---|---|"]
    for name in ORDER:
        if name in done:
            row = done[name]
            lines.append("| `%s` | %s | %s | %.1f | %d | `%s` | %s |" % (
                name, row["time"][:10], row["model"], row["seconds"], row.get("credits_reconciled", row["credits_measured"]), table[name]["sha256"], row["prompt"].replace("|", "/")))
    lines += ["", "## Hâlâ ücretsiz plan (2026-10-26/27) sesleri — ticari yayın için lisans sorusu", "",
              "| dosya | SHA-256 (seviye eşitlenmiş) | tahmini yeniden üretim kredisi |", "|---|---|---:|"]
    for name in ORDER:
        if name not in done:
            lines.append("| `%s` | `%s` | %d |" % (name, table[name]["sha256"], round(estimate_credits(name))))
    open(PROVENANCE_PATH, "w", encoding="utf-8").write("\n".join(lines) + "\n")


# --- ana akış ---------------------------------------------------------------------------------

def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    flags = [a for a in sys.argv[1:] if a.startswith("--")]
    if "--estimate" in flags:
        estimate()
        return
    client = None if "--process" in flags else load_client()
    if "--account" in flags:
        account(client)
        return
    retry = "--retry" in flags
    names = args or ORDER
    for name in names:
        if name not in INFO:
            sys.exit("bilinmeyen ad: " + name)
    if client is not None:
        tier, used, limit = account(client)
        if tier == "free":
            sys.exit("DURDU: plan 'free'")
        for name in names:
            if os.path.exists(os.path.join(RAW_DIR, name + ".mp3")) and not retry:
                continue
            projected = spent_credits() + estimate_credits(name)
            if projected > CREDIT_BUDGET - RESERVE:
                print("BÜTÇE: %s için tahmini toplam %d > %d (tavan %d - pay %d); atlandı" % (name, projected, CREDIT_BUDGET - RESERVE, CREDIT_BUDGET, RESERVE))
                continue
            try:
                generate(client, name, retry)
            except Exception as error:  # noqa: BLE001 — hata adıyla raporlanır, diğer sesler sürer
                detail = getattr(error, "body", None) or str(error)
                print("HATA %s: %s %s" % (name, getattr(error, "status_code", ""), str(detail)[:300]))
    report = json.load(open(REPORT_PATH, encoding="utf-8")) if os.path.exists(REPORT_PATH) else {}
    done = regenerated_names()
    for name in ORDER:
        if args and name not in args and "--process" not in flags:
            continue
        try:
            if name in done:
                process_new(name, report)
            else:
                process_old(name, report)
        except Exception as error:  # noqa: BLE001
            print("ISLEME HATASI %s: %s" % (name, str(error)[:300]))
    write_registry(report)
    print("bu iş toplam ölçülen kredi:", int(spent_credits()))


if __name__ == "__main__":
    main()
