#!/usr/bin/env python3
"""Paket boyutu raporu (saf Python; PIL varsa doku boyutlari icin kullanilir).

Kullanim:
  python3 tools/size_report.py                      # kaynak + ice aktarilan + tahmin
  python3 tools/size_report.py --pck build/size/game.pck   # gercek PCK dokumu
  python3 tools/size_report.py --preset "Android (release)" # tahmin icin preset filtreleri
  python3 tools/size_report.py --markdown out.md    # ayni raporu .md olarak yaz

Bolumler:
  1. Klasor basina kaynak boyutu (docs/ ve .godot ayri; asla gemiyorlar)
  2. Dosya basina ice aktarilan boyut (.import -> dest_files), bicim basina
  3. Ses sureleri / bit hizi
  4. En buyuk 40 gonderilen dosya
  5. Tahmini paket boyutu (veya --pck ile gercek, DEFLATE ile sikistirilmis tahmini indirme)
"""
from __future__ import annotations

import argparse
import fnmatch
import os
import re
import struct
import subprocess
import sys
import wave
import zlib
from collections import Counter, defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NEVER_SCAN = {".git", ".godot", "build"}
# Android'de GPU bicimi: yalniz ASTC gonderilir (gozlem: gercek export-pack). BPTC/S3TC masaustu icindir.
DESKTOP_ONLY = (".bptc.", ".s3tc.")


def human(n: float) -> str:
    for unit in ("B", "KB", "MB", "GB"):
        if abs(n) < 1024 or unit == "GB":
            return f"{n:.0f} {unit}" if unit == "B" else f"{n:.2f} {unit}"
        n /= 1024
    return str(n)


# ---------------------------------------------------------------- PCK ayristirici
def read_pck(path: str) -> list[tuple[str, int, int]]:
    """GDPC v2-v4 dizinini oku: [(yol, ofset, boyut)]."""
    with open(path, "rb") as f:
        if f.read(4) != b"GDPC":
            raise SystemExit(f"{path}: GDPC degil")
        ver = struct.unpack("<I", f.read(4))[0]
        f.read(12)  # major, minor, patch
        flags = 0
        if ver >= 2:
            flags = struct.unpack("<I", f.read(4))[0]
            base, diroff = struct.unpack("<QQ", f.read(16))
        else:
            raise SystemExit("PCK v1 desteklenmiyor")
        f.seek(diroff)
        n = struct.unpack("<I", f.read(4))[0]
        out = []
        for _ in range(n):
            ln = struct.unpack("<I", f.read(4))[0]
            p = f.read(ln).rstrip(b"\0").decode("utf-8")
            off, size = struct.unpack("<QQ", f.read(16))
            f.read(16)  # md5
            f.read(4)  # flags
            out.append((p, off + (base if flags & 2 else 0), size))
        return out


def pck_read_file(path: str, off: int, size: int) -> bytes:
    with open(path, "rb") as f:
        f.seek(off)
        return f.read(size)


# ---------------------------------------------------------------- yardimcilar
def walk_files(root: str):
    for dp, dns, fns in os.walk(root):
        rel = os.path.relpath(dp, root)
        dns[:] = [d for d in dns if not (rel == "." and d in NEVER_SCAN)]
        for fn in fns:
            full = os.path.join(dp, fn)
            if os.path.islink(full):
                continue
            yield os.path.relpath(full, root), full


def parse_import(path: str) -> dict:
    info: dict = {"dest": [], "importer": "", "params": {}}
    section = ""
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.strip()
            if line.startswith("["):
                section = line.strip("[]")
            elif "=" in line:
                k, v = line.split("=", 1)
                if section == "remap" and k == "importer":
                    info["importer"] = v.strip('"')
                elif section == "deps" and k == "dest_files":
                    info["dest"] = re.findall(r'res://([^"]+)', v)
                elif section == "params":
                    info["params"][k] = v
    return info


def preset_filters(name: str | None) -> tuple[list[str], list[str], str]:
    path = os.path.join(ROOT, "export_presets.cfg")
    if not name or not os.path.exists(path):
        return [], [], "all_resources"
    txt = open(path, encoding="utf-8").read()
    for m in re.finditer(r"\[preset\.(\d+)\]\n(.*?)(?=\n\[preset\.\d+\]|\n\[preset\.\d+\.options\]|\Z)", txt, re.S):
        body = m.group(2)
        if f'name="{name}"' in body:
            def g(key):
                mm = re.search(rf'^{key}="(.*)"$', body, re.M)
                return [p.strip() for p in mm.group(1).split(",") if p.strip()] if mm else []
            mode = re.search(r'^export_filter="(.*)"$', body, re.M)
            return g("include_filter"), g("exclude_filter"), mode.group(1) if mode else "all_resources"
    raise SystemExit(f"preset yok: {name}")


def excluded(rel: str, patterns: list[str]) -> bool:
    return any(fnmatch.fnmatch(rel, p) for p in patterns)


def audio_info(full: str) -> tuple[float, int, str]:
    """(sure sn, bit hizi bps, aciklama)."""
    if full.endswith(".wav"):
        try:
            with wave.open(full) as w:
                dur = w.getnframes() / w.getframerate()
                br = w.getframerate() * w.getsampwidth() * 8 * w.getnchannels()
                return dur, br, f"{w.getframerate()}Hz {w.getnchannels()}ch {w.getsampwidth()*8}bit"
        except Exception:
            return 0.0, 0, "?"
    try:
        out = subprocess.run(
            ["ffprobe", "-v", "error", "-show_entries", "format=duration,bit_rate:stream=codec_name,sample_rate,channels",
             "-of", "default=nw=1", full], capture_output=True, text=True, timeout=30).stdout
        kv = dict(l.split("=", 1) for l in out.splitlines() if "=" in l)
        return float(kv.get("duration", 0)), int(kv.get("bit_rate", 0) or 0), \
            f"{kv.get('codec_name','?')} {kv.get('sample_rate','?')}Hz {kv.get('channels','?')}ch"
    except Exception:
        return 0.0, 0, "ffprobe yok"


def category(rel: str) -> str:
    if rel.startswith(".godot/imported/"):
        b = rel
        if ".astc.ctex" in b: return "doku ASTC"
        if ".etc2.ctex" in b: return "doku ETC2"
        if ".bptc.ctex" in b: return "doku BPTC (masaustu)"
        if ".s3tc.ctex" in b: return "doku S3TC (masaustu)"
        if b.endswith(".ctex"): return "doku (kayipsiz/yan bicim)"
        if b.endswith(".sample"): return "ses WAV/QOA (.sample)"
        if b.endswith(".oggvorbisstr"): return "ses OGG"
        if b.endswith(".mp3str"): return "ses MP3"
        if b.endswith(".fontdata"): return "font"
        if b.endswith((".scn", ".res")): return "sahne/kaynak (ikili)"
        return "ice aktarilan diger"
    if rel.startswith(".godot/exported/"): return "betik/sahne (ikili belirteclenmis)"
    top = rel.split("/")[0]
    if top in ("scripts", "data", "scenes", "addons", "tests", "tools", "docs", "assets"):
        return top + "/ (ham)"
    return "diger"


# ---------------------------------------------------------------- ana
def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--pck")
    ap.add_argument("--preset")
    ap.add_argument("--markdown")
    ap.add_argument("--top", type=int, default=40)
    args = ap.parse_args()

    out: list[str] = []
    P = out.append

    # 1. kaynak boyutlari
    P("## 1. Kaynak boyutu (calisma agaci, klasor basina)\n")
    P("| klasor | boyut | dosya |\n|---|---:|---:|")
    folders: dict[str, list[int]] = defaultdict(lambda: [0, 0])
    for rel, full in walk_files(ROOT):
        parts = rel.split(os.sep)
        key = parts[0] if len(parts) == 1 else "/".join(parts[:2]) if parts[0] in ("assets", "addons") else parts[0]
        if len(parts) == 1:
            key = "(kok dosyalar)"
        folders[key][0] += os.path.getsize(full)
        folders[key][1] += 1
    for k, (s, n) in sorted(folders.items(), key=lambda kv: -kv[1][0]):
        P(f"| {k} | {human(s)} | {n} |")
    for hidden in (".godot", "build"):
        hp = os.path.join(ROOT, hidden)
        if os.path.isdir(hp):
            tot = sum(os.path.getsize(f) for _, f in walk_files_all(hp))
            P(f"| {hidden} (yerel onbellek) | {human(tot)} | - |")

    # 2. ice aktarilan boyut, bicim basina
    P("\n## 2. Ice aktarilan boyut (.godot/imported, bicim basina)\n")
    imp_dir = os.path.join(ROOT, ".godot", "imported")
    variants: Counter = Counter()
    ship_variants: Counter = Counter()
    shipped_import: dict[str, int] = {}
    src_png_total = 0
    inc0, exc0, _ = preset_filters(args.preset)
    docs_import = 0
    for rel, full in walk_files(ROOT):
        if not rel.endswith(".import"):
            continue
        info = parse_import(full)
        src = rel[:-7]
        if src.startswith(("docs/", "tests/", "tools/", "build/")) or excluded(src, exc0):
            # docs/ gdignore'lu ama eski .import'lar .godot'ta durabilir: paketlenmez, rapora girmez.
            docs_import += sum(os.path.getsize(os.path.join(ROOT, d)) for d in info["dest"] if os.path.exists(os.path.join(ROOT, d)))
            continue
        dests = [d for d in info["dest"] if os.path.exists(os.path.join(ROOT, d))]
        has_astc = any(".astc." in d for d in dests)
        for d in dests:
            sz = os.path.getsize(os.path.join(ROOT, d))
            cat = category(d)
            variants[cat] += sz
            # Android: ASTC varsa yalniz o gider (gercek export-pack gozlemi); BPTC/S3TC/ETC2/duz .ctex gitmez.
            if any(t in d for t in DESKTOP_ONLY) or (has_astc and ".astc." not in d):
                continue
            shipped_import[d] = sz
            ship_variants[cat] += sz
        if src.endswith(".png"):
            src_png_total += os.path.getsize(os.path.join(ROOT, src)) if os.path.exists(os.path.join(ROOT, src)) else 0
    P("| bicim | .godot/imported toplami | Android paketine giren |\n|---|---:|---:|")
    for k, v in variants.most_common():
        P(f"| {k} | {human(v)} | {human(ship_variants.get(k, 0))} |")
    P(f"\n(docs/tests/tools/dislanan kaynaklarin .godot onbellegi, rapora girmez: {human(docs_import)})")
    P(f"\nKaynak PNG toplami (gonderilmez, yalniz .ctex gider): {human(src_png_total)}")

    # 3. ses
    P("\n## 3. Ses (kaynak dosya, sure, bit hizi, ice aktarilan boyut)\n")
    P("| dosya | sure | kaynak | bit hizi | ice aktarilan | bicim |\n|---|---:|---:|---:|---:|---|")
    audio_total_src = audio_total_imp = 0
    for rel, full in sorted(walk_files(os.path.join(ROOT, "assets", "audio")), key=lambda x: x[0]):
        if rel.endswith(".import"):
            continue
        full_rel = os.path.join("assets", "audio", rel)
        dur, br, desc = audio_info(full)
        imp = 0
        ip = full + ".import"
        if os.path.exists(ip):
            for d in parse_import(ip)["dest"]:
                dp = os.path.join(ROOT, d)
                if os.path.exists(dp):
                    imp += os.path.getsize(dp)
        sz = os.path.getsize(full)
        audio_total_src += sz
        audio_total_imp += imp
        P(f"| {full_rel} | {dur:.2f}s | {human(sz)} | {br/1000:.0f} kbps | {human(imp)} | {desc} |")
    P(f"\nSes toplami: kaynak {human(audio_total_src)}, ice aktarilan {human(audio_total_imp)}")

    # 4/5. gonderilen dosyalar
    inc, exc, mode = preset_filters(args.preset)
    shipped: list[tuple[str, int, int]] = []  # yol, boyut, sikistirilmis
    if args.pck:
        ents = read_pck(os.path.join(ROOT, args.pck) if not os.path.isabs(args.pck) else args.pck)
        for p, off, size in ents:
            raw = pck_read_file(args.pck, off, size)
            shipped.append((p, size, len(zlib.compress(raw, 6))))
        src_label = f"GERCEK PCK: {args.pck}"
    else:
        for d, sz in shipped_import.items():
            shipped.append((d, sz, 0))
        for rel, full in walk_files(ROOT):
            if rel.endswith(".import") or excluded(rel, exc) or rel.startswith(("docs/", "build/")):
                continue
            # kaynagi ice aktarilan dosya (png/wav/ttf...) gonderilmez
            if os.path.exists(full + ".import"):
                continue
            if rel.endswith((".gd.uid", ".gdignore")):
                continue
            shipped.append((rel, os.path.getsize(full), 0))
        # exclude filtresi ice aktarilan dosyalarin kaynak yoluna uygulanir
        keep = []
        for p, s, z in shipped:
            keep.append((p, s, z))
        shipped = keep
        src_label = "TAHMIN (kaynak + .import hedefleri; preset: %s)" % (args.preset or "yok")

    P(f"\n## 4. En buyuk {args.top} gonderilen dosya ({src_label})\n")
    P("| boyut | dosya |\n|---:|---|")
    for p, s, z in sorted(shipped, key=lambda x: -x[1])[: args.top]:
        P(f"| {human(s)} | {p} |")

    P(f"\n## 5. Paket boyutu ({src_label})\n")
    cats: Counter = Counter()
    zc: Counter = Counter()
    for p, s, z in shipped:
        cats[category(p)] += s
        zc[category(p)] += z
    total = sum(cats.values())
    P("| kategori | boyut | % |" + (" deflate |" if args.pck else "") + "\n|---|---:|---:|" + ("---:|" if args.pck else ""))
    for k, v in cats.most_common():
        P(f"| {k} | {human(v)} | {100*v/total:.1f}% |" + (f" {human(zc[k])} |" if args.pck else ""))
    P(f"| **TOPLAM** | **{human(total)}** | 100% |" + (f" **{human(sum(zc.values()))}** |" if args.pck else ""))
    P(f"\nDosya sayisi: {len(shipped)}")
    if args.pck:
        P(f"PCK dosya boyutu (dizin dahil): {human(os.path.getsize(args.pck))}")
    P("\nNot: APK/AAB = PCK (Android'de 'assets/' altinda) + libgodot_android.so (arm64 icin yaklasik bkz. templates) + dex/kaynaklar;"
      " motor kismi sablon APK'sindan olculur (bkz. docs/size/baseline.md).")

    text = "\n".join(out)
    print(text)
    if args.markdown:
        with open(args.markdown, "w", encoding="utf-8") as f:
            f.write(text + "\n")
    return 0


def walk_files_all(root: str):
    for dp, _, fns in os.walk(root):
        for fn in fns:
            full = os.path.join(dp, fn)
            if not os.path.islink(full):
                yield fn, full


if __name__ == "__main__":
    sys.exit(main())
