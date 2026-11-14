#!/usr/bin/env python3
"""ElevenLabs ile oyunun ses efektlerini üretir (assets/audio/sfx/*.mp3).

Kullanım: python3 tools/make_sfx.py [ad ...]     (ad verilmezse hepsi; var olanlar atlanır, --force ile yeniden)
Anahtar proje kökündeki .env'den okunur: ELEVENLABS_API_KEY=..., elevenlabs_api_key:... ya da tek satır ham anahtar.
Anahtar asla yazdırılmaz.
"""
import json
import os
import sys
import urllib.request

ROOT = os.path.join(os.path.dirname(__file__), "..")
OUT = os.path.join(ROOT, "assets", "audio", "sfx")
SOUNDS = {
    "bell": ("small brass service desk bell, single bright ding, short, dry", 0.8),
    "note_drop": ("a paper banknote slapped onto a wooden counter, short soft thud with a paper rustle, dry", 0.6),
    "stamp": ("heavy rubber office stamp pressed onto paper, a solid dry thunk, very short, no reverb", 0.6),
    "coin": ("a few coins dropped into a metal tray, short bright clink", 0.8),
    "error": ("short low buzzer for a wrong answer in a casual game, soft and not harsh", 0.6),
    "page": ("a newspaper page turning, short paper rustle", 0.8),
    "footsteps": ("a person walking up to a counter on a tiled floor indoors, four slow footsteps, dry, no music", 2.0),
    "paper_slide": ("paper sheets sliding across a wooden desk, short soft slide", 0.8),
    "cash_slide": ("banknotes and a few coins sliding through a metal tray slot, short", 0.9),
    "tube": ("a pneumatic tube capsule whooshing down a pipe and landing with a soft metallic thunk in a wooden tray, short, dry", 1.6),
    "typewriter": ("an old mechanical typewriter typing a short burst of keys and a carriage return bell, dry, no music", 2.0),
    "phone": ("an old rotary telephone ringing twice in a quiet office, dry", 2.0),
    "buzzer": ("a short harsh office buzzer for denied entry, one buzz, dry", 0.7),
    "siren": ("a short police siren whoop heard through a window, two rising tones, muffled", 1.5),
    "drawer": ("a metal cash drawer sliding open with a light bell ding, short", 1.0),
    "calc_key": ("a single mechanical calculator key press, tiny dry click", 0.5),
    "uv_on": ("a ultraviolet lamp switching on: soft click then a short electric hum rising, short", 1.2),
    "lens": ("a magnifying glass sliding on a wooden desk, short glassy scrape", 0.8),
    "flicker": ("a fluorescent tube flickering and buzzing for a moment then steadying, short", 1.4),
    "chime_win": ("a gentle warm bell chime of three rising notes for a finished work day, short", 1.6),
    "chime_fail": ("a low dull bell strike with a slow fade, sad and short", 1.6),
    "coins_pile": ("a handful of coins poured into a tin cup, bright jingle, short", 1.2),
    "crumple": ("a sheet of paper being crumpled in a fist, short", 0.8),
    "door_buzz": ("an old office door buzzer and a heavy door opening, short", 1.3),
    "clock_tick": ("a large wall clock ticking steadily, four ticks, dry room", 2.0),
    "pen_scratch": ("a fountain pen scratching a signature on paper, short", 1.0),
    "ink_press": ("a rubber stamp pressed hard on an ink pad, wet dull thump, short", 0.6),
    "ambient": ("quiet empty government office room tone, faint fluorescent light hum, distant muffled city noise, steady and seamless, no music", 12.0),
}


def api_key():
    """`ELEVENLABS_API_KEY=...`, `elevenlabs_api_key:...` ya da tek başına anahtar satırını kabul eder."""
    # ELEVENLABS_ENV: anahtar dosyası başka bir klasördeyse yolu (içeriği değil).
    with open(os.environ.get("ELEVENLABS_ENV") or os.path.join(ROOT, ".env")) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            for sep in ("=", ":"):
                name, found, value = line.partition(sep)
                if found and "eleven" in name.lower():
                    return value.strip().strip('"').strip("'")
            return line
    raise SystemExit(".env içinde anahtar yok")


def generate(name, prompt, seconds, key):
    body = json.dumps({"text": prompt, "duration_seconds": seconds, "prompt_influence": 0.6}).encode()
    req = urllib.request.Request("https://api.elevenlabs.io/v1/sound-generation", data=body, method="POST",
                                 headers={"xi-api-key": key, "Content-Type": "application/json", "Accept": "audio/mpeg"})
    with urllib.request.urlopen(req, timeout=60) as resp:
        data = resp.read()
    path = os.path.join(OUT, name + ".mp3")
    with open(path, "wb") as f:
        f.write(data)
    print("%-8s %6d bayt -> assets/audio/sfx/%s.mp3" % (name, len(data), name))


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    force = "--force" in sys.argv
    os.makedirs(OUT, exist_ok=True)
    key = api_key()
    for name in args or SOUNDS:
        if not force and os.path.exists(os.path.join(OUT, name + ".mp3")):
            print("%-8s var, atlandı" % name)
            continue
        prompt, seconds = SOUNDS[name]
        try:
            generate(name, prompt, seconds, key)
        except urllib.error.HTTPError as e:
            print("%-8s HATA %d: %s" % (name, e.code, e.read()[:200].decode(errors="replace")))


if __name__ == "__main__":
    main()
