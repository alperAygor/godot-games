#!/usr/bin/env python3
"""Tüm gönderilen sesleri ölçer ve tablo basar (ağ yok).

    python3 tools/audio_report.py                 # tablo
    python3 tools/audio_report.py --json out.json # ölçümleri dosyaya da yaz
    python3 tools/audio_report.py --stack         # en kötü durum yığın testi (ffmpeg ile)
"""
import json
import os
import subprocess
import sys
import glob

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audio_lib  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def collect():
    files = sorted(glob.glob(os.path.join(ROOT, "assets", "audio", "**", "*.wav"), recursive=True)
                   + glob.glob(os.path.join(ROOT, "assets", "audio", "**", "*.ogg"), recursive=True))
    return files


def stack_test():
    """En kötü durum: müzik + ortam + 6 efekt AYNI ANDA, hepsi tam düzeyde (oyun yolundaki bus ayarları ile).

    Bus kazançları AudioService sabitleriyle aynı olmalı: GAME_MUSIC_DB, AMBIENCE_DB. Master'da sert sınırlayıcı
    (tavan -1 dB) çalar; burada alimiter ile benzetilir. Karıştırma öncesi (limitersiz) ve sonrası tepe basılır.
    """
    sfx = os.path.join(ROOT, "assets", "audio", "sfx")
    music = os.path.join(ROOT, "assets", "audio", "music", "music_garden.ogg")
    amb = os.path.join(sfx, "garden_ambience.wav")
    one_shots = ["fold_puff", "note", "win", "pin_click_1", "cloth_1", "coin"]
    cmd = ["ffmpeg", "-y", "-loglevel", "error", "-i", music, "-i", amb]
    for name in one_shots:
        cmd += ["-i", os.path.join(sfx, name + ".wav")]
    parts = ["[0:a]volume=-4dB,aformat=channel_layouts=stereo[m]", "[1:a]volume=-2dB,aformat=channel_layouts=stereo[a]"]
    labels = ["[m]", "[a]"]
    for index, name in enumerate(one_shots):
        parts.append("[%d:a]aformat=channel_layouts=stereo[s%d]" % (index + 2, index))
        labels.append("[s%d]" % index)
    graph = ";".join(parts) + ";" + "".join(labels) + "amix=inputs=%d:normalize=0:duration=longest[mix]" % len(labels)
    raw_path = "/tmp/_stack_raw.wav"
    subprocess.run(cmd + ["-filter_complex", graph, "-map", "[mix]", "-t", "8", "-c:a", "pcm_f32le", raw_path], check=True)
    limited = "/tmp/_stack_lim.wav"
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", raw_path, "-af", "volume=2dB,alimiter=limit=0.891:attack=5:release=100:level=disabled",
                    "-c:a", "pcm_f32le", limited], check=True)
    for label, path in (("limitersiz", raw_path), ("sinirlayici sonrasi", limited)):
        integrated, peak = audio_lib.lufs(path, 0.0)
        print("yigin %-20s LUFS-I %6.1f  gercek tepe %6.1f dBTP" % (label, integrated, peak))


def main():
    if "--stack" in sys.argv:
        stack_test()
        return
    rows = {}
    for path in collect():
        name = os.path.relpath(path, os.path.join(ROOT, "assets", "audio"))
        row = audio_lib.stats(path)
        row["size_kb"] = round(os.path.getsize(path) / 1024)
        if name.startswith("music/") or "ambience" in name:
            data = audio_lib.decode(path)
            row["seam"] = audio_lib.seam(data)
            row["spectrum"] = audio_lib.spectrum_sanity(data)
        rows[name] = row
        print("%-26s %6.2fs  LUFS %6.1f  TP %6.1f  peak %6.1f  rms %6.1f  head %4dms tail %4dms  %5d KB" % (
            name, row["duration_s"], row["lufs_i"], row["true_peak_db"], row["peak_db"], row["rms_db"],
            row["head_silence_ms"], row["tail_silence_ms"], row["size_kb"]))
        if "seam" in row:
            print("     dikis:", row["seam"], " tayf:", row["spectrum"])
    if "--json" in sys.argv:
        json.dump(rows, open(sys.argv[sys.argv.index("--json") + 1], "w", encoding="utf-8"), indent=1)


if __name__ == "__main__":
    main()
