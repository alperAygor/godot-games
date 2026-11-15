#!/usr/bin/env python3
"""Calisma zamani baslik tarayicisi + PCK carpraz denetimi.

Kullanim:
  python3 tools/pck_check.py build/size/game.pck         # eksik varsa cikis 1 (yuksek sesle)
  python3 tools/pck_check.py --unreferenced              # PCK'siz: hicbir yerden anilmayan varliklar

Mantik:
  1. Oyun kodundan (scripts/, scenes/, data/, assets/ icindeki .tres/.gdshader/.json, project.godot,
     addons/admob/gdscript) `res://` dizgilerini topla. `%s`/`%d` iceren sablonlar glob'a cevrilir.
  2. `res://dizin/` ile biten sabitler (LAYER_DIR + ad gibi birlestirmeler) icin: o dizindeki dosyalardan
     govdesi (uzantisiz adi) kod/veri metninde bir yerde gecenler "gerekli" sayilir.
  3. Gerekli her dosya PCK'da olmali: ya kendisi, ya `<dosya>.import` + ice aktarilan hedefi, ya `.remap`.
     Eksik varsa listelenir ve cikis kodu 1 olur.
  4. PCK'da olup hicbir seyden anilmayan varliklar `UNREFERENCED` olarak listelenir (dislama adayi).
"""
from __future__ import annotations

import fnmatch
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from size_report import read_pck, parse_import  # noqa: E402

CORPUS_DIRS = ["scripts", "scenes", "data", "assets", "addons/admob/gdscript", "addons/admob/internal/version"]
CORPUS_EXT = (".gd", ".tscn", ".tres", ".json", ".gdshader", ".gdshaderinc", ".cfg", ".csv", ".godot")
ASSET_EXT = (".png", ".svg", ".wav", ".ogg", ".mp3", ".ttf", ".otf", ".glb", ".tres", ".tscn", ".gdshader",
             ".gdshaderinc", ".json", ".translation", ".csv", ".webp", ".jpg")
# Bilerek paketlenmeyen, yalniz editorde/AdMob export eklentisinde kullanilan yollar (docs/MONETIZATION.md):
# plugin_version.gd FileAccess.file_exists ile yoklar; mock yalniz OS.has_feature("editor") iken yuklenir.
KNOWN_EDITOR_ONLY = ("addons/admob/android/*", "addons/admob/ios/*", "addons/admob/internal/mock/*",
                     "addons/admob/internal/editor/*", "addons/admob/internal/exporters/*",
                     "addons/admob/internal/services/*", "addons/admob/internal/handlers/*", "addons/admob/assets/*")
REF_RE = re.compile(r'res://[^"\'\s\)\],;]+')


def corpus_files():
    yield os.path.join(ROOT, "project.godot")
    for d in CORPUS_DIRS:
        for dp, dns, fns in os.walk(os.path.join(ROOT, d)):
            for fn in fns:
                if fn.endswith(CORPUS_EXT):
                    yield os.path.join(dp, fn)


def collect():
    literal: set[str] = set()
    templates: list[str] = []
    dirs: set[str] = set()
    text_all = []
    for f in corpus_files():
        try:
            t = open(f, encoding="utf-8", errors="replace").read()
        except OSError:
            continue
        text_all.append(t)
        for m in REF_RE.findall(t):
            p = m[len("res://"):]
            if "%" in p or "{" in p:
                templates.append(re.sub(r"%[-+0-9.]*[sdfx]|\{[^}]*\}", "*", p))
            elif p.endswith("/"):
                dirs.add(p)
            else:
                literal.add(p)
    return literal, templates, dirs, "\n".join(text_all)


def pck_logical(pck_entries):
    names = {p for p, _, _ in pck_entries}
    shipped = set()
    for n in names:
        if n.startswith(".godot/"):
            continue
        if n.endswith(".import"):
            src = n[:-7]
            dests = parse_import(os.path.join(ROOT, n))["dest"] if os.path.exists(os.path.join(ROOT, n)) else []
            # Godot pakette '.import' kopyasini tutmaz; hedef dosyalardan biri varsa kaynak "gonderildi" sayilir.
            if not dests or any(d in names for d in dests):
                shipped.add(src)
        elif n.endswith(".remap"):
            shipped.add(n[:-6])
        else:
            shipped.add(n)
    return shipped


def project_assets():
    out = []
    for top in ("assets", "data", "scenes", "scripts", "addons"):
        for dp, dns, fns in os.walk(os.path.join(ROOT, top)):
            for fn in fns:
                if fn.endswith((".import", ".uid")):
                    continue
                out.append(os.path.relpath(os.path.join(dp, fn), ROOT))
    return out


def required_set(literal, templates, dirs, text, everything):
    req = set()
    for p in literal:
        req.add(p)
    for t in templates:
        for p in everything:
            if fnmatch.fnmatch(p, t):
                req.add(p)
    for d in dirs:
        stem_hits = 0
        for p in everything:
            if os.path.dirname(p) + "/" == d and p.endswith(ASSET_EXT):
                stem = os.path.splitext(os.path.basename(p))[0]
                if re.search(r'(?<![A-Za-z0-9_])' + re.escape(stem) + r'(?![A-Za-z0-9_])', text):
                    req.add(p)
                    stem_hits += 1
    return req


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    only_unref = "--unreferenced" in sys.argv
    literal, templates, dirs, text = collect()
    everything = project_assets()
    req = required_set(literal, templates, dirs, text, everything)
    exists_on_disk = {p for p in everything}
    rc = 0

    # varsayilan olarak kod+veri icinden hic anilmayan varliklar
    asset_like = [p for p in everything if p.startswith("assets/") and p.endswith(ASSET_EXT)]
    # sahne/betik/uid ile dolayli referanslar: .tres/.tscn icindeki ext_resource path'leri zaten REF_RE'ye girer
    unref = sorted(p for p in asset_like if p not in req and not p.endswith(".json") or
                   (p.endswith(".json") and p not in req and "laundromat_layers" not in p and "MANIFEST" not in p))
    if only_unref or not args:
        print(f"UNREFERENCED ({len(unref)}):")
        for p in unref:
            print("  ", p, os.path.getsize(os.path.join(ROOT, p)))
        if only_unref:
            return 0

    if args:
        entries = read_pck(args[0])
        shipped = pck_logical(entries)
        missing = sorted(p for p in req if p in exists_on_disk and p not in shipped
                         and not any(fnmatch.fnmatch(p, k) for k in KNOWN_EDITOR_ONLY))
        dangling = sorted(p for p in req if p not in exists_on_disk and p not in shipped
                          and not p.startswith(("user://", ".godot/")) and "*" not in p)
        print(f"pck girdisi: {len(entries)}  mantiksal dosya: {len(shipped)}  gerekli: {len(req)}")
        if missing:
            print(f"\n!!! EKSIK ({len(missing)}): calisma zamaninda gerekli ama PCK'da YOK")
            for p in missing:
                print("   MISSING", p)
            rc = 1
        stale = sorted(p for p in dangling if not os.path.exists(os.path.join(ROOT, p)))
        if stale:
            print(f"\nUYARI: kodda anilan ama diskte olmayan {len(stale)} yol (olu referans veya olusturulan dosya):")
            for p in stale[:40]:
                print("   ", p)
        extra_unref = sorted(p for p in shipped if p in set(unref))
        print(f"\nPCK'da olup hicbir yerden anilmayan varlik: {len(extra_unref)}")
        for p in extra_unref:
            print("   UNREF-SHIPPED", p)
        print("\nSONUC:", "BASARISIZ (eksik dosya)" if rc else "gecti (gerekli tum dosyalar pakette)")
    return rc


if __name__ == "__main__":
    sys.exit(main())
