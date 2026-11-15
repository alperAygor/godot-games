#!/usr/bin/env python3
"""PCK denetimi (şablondaki tools/pck_check.py'den uyarlandı, tools/size_report.py bağımlılığı kaldırıldı).

  godot --headless --path . --export-pack "Android" build/verify/na.pck
  python3 tools/pck_check.py build/verify/na.pck [--max-mb 10]

Üç şey denetler (biri bozuksa çıkış kodu 1):
  1. EKSİK: oyun kodundan/verisinden anılan `res://` yolları diskte var ama PCK'da yok (çalışma zamanında yüklenemez).
  2. SIZINTI: PCK'ya girmemesi gereken dosyalar var (tests/, tools/, docs/, *.md, .env, anahtar deposu, .blend, ham kayıt/çıktı).
  3. BOYUT: PCK boyutu --max-mb (varsayılan PCK_MAX_MB ya da 10) sınırını aşıyor. %75'i aşınca uyarı basar.
Ayrıca PCK'da olup hiçbir yerden anılmayan varlıkları bilgi olarak listeler (çıkış kodunu etkilemez).
"""
from __future__ import annotations

import fnmatch
import os
import re
import struct
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CORPUS_DIRS = ["scripts", "scenes", "data", "assets"]
CORPUS_EXT = (".gd", ".tscn", ".tres", ".json", ".gdshader", ".gdshaderinc", ".cfg", ".csv")
ASSET_EXT = (".png", ".svg", ".wav", ".ogg", ".mp3", ".ttf", ".otf", ".glb", ".tres", ".tscn", ".gdshader",
             ".gdshaderinc", ".json", ".translation", ".csv", ".webp", ".jpg")
REF_RE = re.compile(r'res://[^"\'\s\)\],;]+')
# Pakete bilerek girmeyen yollar (export_presets.cfg exclude_filter ile uyumlu); kodda anılmaları sorun değil.
EXCLUDED_REFS = ("tests/*", "tools/*", "docs/*", "*.md", "build/*")
# PCK içinde ASLA bulunmaması gerekenler.
FORBIDDEN = ("tests/*", "tools/*", "docs/*", "*.md", "*.keystore", "*.jks", ".env*", "*.blend", "*.blend1", "*.apk", "*.aab",
             "google-services.json", "service-account.json", "export_credentials.cfg", "build/*", ".git/*", "*.cfg.bak", "*.tmp")


def read_pck(path: str) -> list[tuple[str, int, int]]:
    """GDPC v2+ dizinini oku: [(yol, ofset, boyut)]."""
    with open(path, "rb") as f:
        if f.read(4) != b"GDPC":
            raise SystemExit(f"{path}: GDPC değil")
        ver = struct.unpack("<I", f.read(4))[0]
        f.read(12)
        if ver < 2:
            raise SystemExit("PCK v1 desteklenmiyor")
        flags = struct.unpack("<I", f.read(4))[0]
        base, diroff = struct.unpack("<QQ", f.read(16))
        f.seek(diroff)
        n = struct.unpack("<I", f.read(4))[0]
        out = []
        for _ in range(n):
            ln = struct.unpack("<I", f.read(4))[0]
            p = f.read(ln).rstrip(b"\0").decode("utf-8")
            off, size = struct.unpack("<QQ", f.read(16))
            f.read(16)  # md5
            f.read(4)  # dosya bayrakları
            out.append((p[len("res://"):] if p.startswith("res://") else p, off + (base if flags & 2 else 0), size))
        return out


def import_dests(rel: str) -> list[str]:
    path = os.path.join(ROOT, rel + ".import")
    if not os.path.exists(path):
        return []
    txt = open(path, encoding="utf-8", errors="replace").read()
    m = re.search(r"^dest_files=\[(.*?)\]", txt, re.M | re.S)
    return re.findall(r'res://([^"]+)', m.group(1)) if m else []


def shipped_logical(entries) -> set[str]:
    names = {p for p, _, _ in entries}
    out = set()
    for n in names:
        if n.endswith(".remap"):
            out.add(n[:-6])
        elif n.endswith(".import") or n.startswith(".godot/"):
            continue
        else:
            out.add(n)
    # İçe aktarılmış varlıklar: kaynak yol yerine .godot/imported/* hedefi paketlenir.
    for n in list(os.walk(os.path.join(ROOT, "assets"))):
        pass
    for dp, _, fns in os.walk(ROOT):
        rel_dir = os.path.relpath(dp, ROOT)
        if rel_dir.startswith((".git", ".godot", "build")):
            continue
        for fn in fns:
            if fn.endswith(".import"):
                src = os.path.normpath(os.path.join(rel_dir, fn[:-7]))
                dests = import_dests(src)
                if dests and any(d in names for d in dests):
                    out.add(src)
    return out


def corpus_refs() -> tuple[set[str], list[str], str]:
    literal: set[str] = set()
    templates: list[str] = []
    texts = []
    files = [os.path.join(ROOT, "project.godot")]
    for d in CORPUS_DIRS:
        for dp, _, fns in os.walk(os.path.join(ROOT, d)):
            files += [os.path.join(dp, fn) for fn in fns if fn.endswith(CORPUS_EXT)]
    for fp in files:
        try:
            t = open(fp, encoding="utf-8", errors="replace").read()
        except OSError:
            continue
        texts.append(t)
        for m in REF_RE.findall(t):
            p = m[len("res://"):]
            if "%" in p or "{" in p:
                templates.append(re.sub(r"%[-+0-9.]*[sdfx]|\{[^}]*\}", "*", p))
            elif not p.endswith("/"):
                literal.add(p)
    return literal, templates, "\n".join(texts)


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    max_mb = float(os.environ.get("PCK_MAX_MB", "10"))
    if "--max-mb" in sys.argv:
        max_mb = float(sys.argv[sys.argv.index("--max-mb") + 1])
        args = [a for a in args if a != str(sys.argv[sys.argv.index("--max-mb") + 1])]
    if not args:
        print("kullanım: pck_check.py <paket.pck> [--max-mb N]")
        return 2
    pck = args[0]
    entries = read_pck(pck)
    names = {p for p, _, _ in entries}
    shipped = shipped_logical(entries)
    size = os.path.getsize(pck)
    rc = 0
    print(f"pck: {size / 1048576:.2f} MB (sınır {max_mb:.1f} MB) · girdi {len(entries)} · mantıksal dosya {len(shipped)}")

    # 3. boyut
    if size > max_mb * 1048576:
        print(f"  ✗ BOYUT: {size / 1048576:.2f} MB > {max_mb:.1f} MB")
        rc = 1
    elif size > 0.75 * max_mb * 1048576:
        print(f"  ! uyarı: sınırın %75'i aşıldı ({size / 1048576:.2f} / {max_mb:.1f} MB)")

    # 2. sızıntı
    leaks = sorted(n for n in names if any(fnmatch.fnmatch(n, pat) or fnmatch.fnmatch(os.path.basename(n), pat) for pat in FORBIDDEN))
    if leaks:
        print(f"  ✗ SIZINTI: pakette olmaması gereken {len(leaks)} dosya")
        for n in leaks[:15]:
            print("      ", n)
        rc = 1

    # 1. eksik
    literal, templates, _ = corpus_refs()
    on_disk = set()
    for top in ("assets", "data", "scenes", "scripts"):
        for dp, _, fns in os.walk(os.path.join(ROOT, top)):
            for fn in fns:
                if not fn.endswith((".import", ".uid")):
                    on_disk.add(os.path.relpath(os.path.join(dp, fn), ROOT))
    required = {p for p in literal if p in on_disk and not any(fnmatch.fnmatch(p, e) for e in EXCLUDED_REFS)}
    for t in templates:
        required |= {p for p in on_disk if fnmatch.fnmatch(p, t)}
    missing = sorted(p for p in required if p not in shipped)
    if missing:
        print(f"  ✗ EKSİK: çalışma zamanında gerekli ama pakette olmayan {len(missing)} dosya")
        for p in missing[:20]:
            print("      ", p)
        rc = 1
    dangling = sorted(p for p in literal if p not in on_disk and not p.startswith(("user://", ".godot/")) and "*" not in p
                      and not any(fnmatch.fnmatch(p, e) for e in EXCLUDED_REFS))
    if dangling:
        print(f"  ! bilgi: kodda anılan ama diskte olmayan {len(dangling)} yol (üretilen dosya ya da ölü referans): " + ", ".join(dangling[:6]))
    unref = sorted(p for p in shipped if p.startswith("assets/") and p.endswith(ASSET_EXT) and p not in required)
    if unref:
        print(f"  ! bilgi: pakette olup hiçbir yerden anılmayan {len(unref)} varlık (dışlama adayı)")
    print("  ✓ paket denetimi geçti" if rc == 0 else "  ✗ paket denetimi BAŞARISIZ")
    return rc


if __name__ == "__main__":
    sys.exit(main())
