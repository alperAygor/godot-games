#!/usr/bin/env python3
"""ElevenLabs Music ile oyunun müziğini üretir (assets/audio/music/*.mp3).

Kullanım: python3 tools/make_music.py [ad ...]     (ad verilmezse hepsi; var olanlar atlanır, --force ile yeniden)
Anahtar make_sfx.py ile aynı yerden okunur (ELEVENLABS_ENV ya da proje kökündeki .env); asla yazdırılmaz.
Müzik koşusuz (enstrümantal) ve bir sanatçı/oyun adı anılmadan, yalnızca tarz tarif edilerek istenir.
"""
import json
import os
import sys
import time
import urllib.error
import urllib.request

sys.path.insert(0, os.path.dirname(__file__))
import make_sfx  # noqa: E402  (api_key)

ROOT = make_sfx.ROOT
OUT = os.path.join(ROOT, "assets", "audio", "music")
# ad: (istem, süre sn). Hepsi kesintisiz döngüye uygun, sakin başlayıp sakin biten parçalar.
TRACKS = {
    "theme_main": ("Main theme of a melancholic bureaucratic drama game: a slow, wistful waltz in a minor key played by a solo accordion and a muted upright piano, "
                   "a soft typewriter-like rhythmic ticking, a lonely clarinet answering the melody, restrained and dignified, a little hopeful at the end of each phrase, "
                   "grey office nostalgia, lo-fi vintage recording, instrumental, memorable simple main melody", 75),
    "morning": ("A short gentle morning piece for an old city newspaper: pizzicato strings and a soft clarinet playing a light, slightly sleepy tune, "
                "a faint typewriter rhythm, tired but warm, minor to major, instrumental, loopable", 45),
    "desk_calm": ("Tense but steady background music for working at a counter all day: a minimal repeating pattern of muted piano and plucked double bass, "
                  "a soft wood-block clock-like pulse, a low string drone, understated bureaucratic suspense, no melody climax, instrumental, seamless loop", 75),
    "desk_tense": ("Rising pressure for the last hour of a work shift: the same minimal muted piano and plucked bass pattern but faster, a ticking clock pulse, "
                   "swelling low strings, an occasional dissonant violin note, anxious but controlled, instrumental, seamless loop", 75),
    "evening": ("Quiet evening at a small apartment after a hard day: a tender solo piano with a warm cello, slow and intimate, a little sad, a little grateful, "
                "far-off radio static at the edges, instrumental, loopable", 60),
    "ending_warm": ("A gentle hopeful ending theme: the main waltz melody played softly by piano and accordion, resolving into a major key, "
                    "warm strings, tearful and kind, instrumental, ends with a calm held chord", 40),
    "ending_dark": ("A grey somber ending theme: the main waltz melody in a slow minor key on a lonely accordion with a distant clock ticking, "
                    "cold strings, resigned and quiet, instrumental, ends with a fading note", 40),
    "ending_escape": ("A bittersweet travelling ending theme: a light train-like rhythm with clarinet and accordion playing a hopeful version of the main waltz melody, "
                      "freedom mixed with guilt, instrumental, ends open", 40),
    "stinger_win": ("A very short warm victory sting for finishing a work day: three soft piano notes rising and a gentle chord, instrumental", 6),
    "stinger_fail": ("A very short sad sting for a failure: two low piano notes and a muted brass sigh, instrumental", 6),
}


def generate(name, prompt, seconds, key):
    body = json.dumps({"prompt": prompt, "music_length_ms": int(seconds * 1000), "force_instrumental": True}).encode()
    req = urllib.request.Request("https://api.elevenlabs.io/v1/music", data=body, method="POST",
                                 headers={"xi-api-key": key, "Content-Type": "application/json", "Accept": "audio/mpeg"})
    with urllib.request.urlopen(req, timeout=600) as resp:
        data = resp.read()
    with open(os.path.join(OUT, name + ".mp3"), "wb") as f:
        f.write(data)
    print("%-14s %8d bayt -> assets/audio/music/%s.mp3" % (name, len(data), name), flush=True)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    force = "--force" in sys.argv
    os.makedirs(OUT, exist_ok=True)
    key = make_sfx.api_key()
    for name in args or TRACKS:
        if not force and os.path.exists(os.path.join(OUT, name + ".mp3")):
            print("%-14s var, atlandı" % name, flush=True)
            continue
        prompt, seconds = TRACKS[name]
        for attempt in range(6):  # "system_busy" (429) geçicidir: bekleyip yeniden dene
            try:
                generate(name, prompt, seconds, key)
                break
            except urllib.error.HTTPError as e:
                detail = e.read()[:300].decode(errors="replace")
                print("%-14s HATA %d (deneme %d): %s" % (name, e.code, attempt + 1, detail), flush=True)
                if e.code != 429:
                    break
                time.sleep(20 * (attempt + 1))


if __name__ == "__main__":
    main()
