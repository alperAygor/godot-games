#!/usr/bin/env python3
"""Gönderilen tüm sesleri ölçer ve tablo basar (ağ yok, kredi harcamaz).

    python3 tools/audio_check.py                  # tablo (ad, yeniden üretildi mi, süre, LUFS-I, tepe...)
    python3 tools/audio_check.py --json out.json  # ölçümleri dosyaya da yaz
    python3 tools/audio_check.py --stack          # en kötü durum yığın testi (ffmpeg ile)

"Yeniden üretildi" bilgisi `data/sounds.json` içindeki `regenerated` alanından gelir.
"""
import glob
import json
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audio_lib  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOUNDS_PATH = os.path.join(ROOT, "data", "sounds.json")
LOOPS = {"ambient", "theme_main", "morning", "desk_calm", "desk_tense", "evening"}


def collect():
    return sorted(glob.glob(os.path.join(ROOT, "assets", "audio", "**", "*.mp3"), recursive=True))


def stack_test():
    """En kötü durum: müzik + ambient + 6 efekt AYNI ANDA (oyun yolundaki bus kazançlarıyla: müzik -5 dB, ambient -13 dB)."""
    sfx = os.path.join(ROOT, "assets", "audio", "sfx")
    music = os.path.join(ROOT, "assets", "audio", "music", "desk_calm.mp3")
    amb = os.path.join(sfx, "ambient.mp3")
    one_shots = ["stamp", "ink_press", "coin", "note_drop", "bell", "paper_slide"]
    cmd = ["ffmpeg", "-y", "-loglevel", "error", "-i", music, "-i", amb]
    for name in one_shots:
        cmd += ["-i", os.path.join(sfx, name + ".mp3")]
    parts = ["[0:a]volume=-5dB,aformat=channel_layouts=stereo[m]", "[1:a]volume=-13dB,aformat=channel_layouts=stereo[a]"]
    labels = ["[m]", "[a]"]
    for index, _name in enumerate(one_shots):
        parts.append("[%d:a]aformat=channel_layouts=stereo[s%d]" % (index + 2, index))
        labels.append("[s%d]" % index)
    graph = ";".join(parts) + ";" + "".join(labels) + "amix=inputs=%d:normalize=0:duration=longest[mix]" % len(labels)
    out = os.path.join(ROOT, "build", "_stack.wav")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    subprocess.run(cmd + ["-filter_complex", graph, "-map", "[mix]", "-t", "8", "-c:a", "pcm_f32le", out], check=True)
    integrated, peak = audio_lib.lufs(out, 0.0)
    print("yigin (limitersiz): LUFS-I %.1f  gercek tepe %.1f dBTP" % (integrated, peak))


def main():
    if "--stack" in sys.argv:
        stack_test()
        return
    table = json.load(open(SOUNDS_PATH, encoding="utf-8")) if os.path.exists(SOUNDS_PATH) else {}
    rows = {}
    print("%-14s %-5s %-5s %6s %7s %7s %7s %7s %6s %6s %5s" % ("ad", "yeni", "tur", "sure", "LUFS-I", "ev100", "TP", "pik", "bas ms", "son ms", "KB"))
    for path in collect():
        name = os.path.splitext(os.path.basename(path))[0]
        row = audio_lib.stats(path)
        row["size_kb"] = round(os.path.getsize(path) / 1024)
        row["event_db"] = round(audio_lib.event_level_of(path), 1)  # en yüksek 100 ms RMS (150 Hz üstü), kısa olaylar için asıl ölçü
        row["regenerated"] = bool(table.get(name, {}).get("regenerated", False))
        row["kind"] = "music" if "/music/" in path else "sfx"
        if name in LOOPS:
            data = audio_lib.decode(path)
            row["seam"] = audio_lib.seam(data)
        rows[name] = row
        print("%-14s %-5s %-5s %6.2f %7.1f %7.1f %7.1f %7.1f %6d %6d %5d" % (
            name, "evet" if row["regenerated"] else "hayir", row["kind"], row["duration_s"], row["lufs_i"], row["event_db"], row["true_peak_db"],
            row["peak_db"], row["head_silence_ms"], row["tail_silence_ms"], row["size_kb"]))
        if "seam" in row:
            print("     dongu dikisi:", row["seam"])
    print("toplam dosya:", len(rows), " toplam KB:", sum(r["size_kb"] for r in rows.values()))
    if "--json" in sys.argv:
        json.dump(rows, open(sys.argv[sys.argv.index("--json") + 1], "w", encoding="utf-8"), indent=1)


if __name__ == "__main__":
    main()
