#!/usr/bin/env python3
"""Baloo2'yi oyunda kullanilan karakterlere indirger (fontTools; pyftsubset gerekmez).

Kaynak: tools/fontsrc/Baloo2-full.ttf  ->  cikti: assets/fonts/Baloo2.ttf
Karakter kumesi: ASCII + Latin-1 + Latin Ek-A (tr/es/en/pt/de ve yakin diller) + noktalama/para birimi/oklar
                 + data/i18n/strings.csv'nin TUM dil sutunlarinda gecen her karakter (sutunlar basliktan okunur;
                   yeni dil eklenince betik degismez)
                 + depodaki tum .gd/.csv/.json/.tscn/.tres metinlerinde gecen her karakter.
Baloo 2 CJK (ja/ko) ve Kiril icermez: o karakterler alt kumeye girmez, oyunda sistem yazi tipine (SystemFont) duser
(bkz. scripts/core/loc_fonts.gd). Latin kullanan bir dilde (tr/en/es/pt/de) eksik karakter varsa betik HATA verir.
Kontrol: `python3 tools/subset_font.py --check` (yazmaz; eksik varsa cikis 1).
Yeni dil eklenirse bu betigi yeniden calistirin; tam font tools/fontsrc'de durur.
Yerlesim ozellikleri (GPOS/GSUB: kern, birlesik harf), degisken eksen (wght) ve hinting korunur.
"""
import csv, os, sys
from fontTools import subset
from fontTools.ttLib import TTFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "tools", "fontsrc", "Baloo2-full.ttf")
DST = os.path.join(ROOT, "assets", "fonts", "Baloo2.ttf")

keep = set(range(0x20, 0x7F)) | set(range(0xA0, 0x180)) | set(range(0x2010, 0x203B)) | {0x20AC, 0x20BA, 0x2022}
keep |= set(range(0x2190, 0x2194)) | {0x2264, 0x2265, 0x2260, 0x00D7, 0x2212}
for dp, dns, fns in os.walk(ROOT):
    dns[:] = [d for d in dns if d not in (".git", ".godot", "build", "docs", "fontsrc")]
    for fn in fns:
        if fn.endswith((".gd", ".csv", ".json", ".tscn", ".tres", ".gdshader")):
            with open(os.path.join(dp, fn), encoding="utf-8", errors="ignore") as f:
                keep |= {ord(c) for c in f.read() if ord(c) > 0x7E}

CSV_PATH = os.path.join(ROOT, "data", "i18n", "strings.csv")
# CJK dilleri Baloo ile karsilanamaz; sistem yazi tipine dusmeleri beklenir.
FALLBACK_LANGS = {"ja", "ko"}
lang_chars = {}
with open(CSV_PATH, encoding="utf-8", newline="") as f:
    for row in csv.DictReader(f):
        for lang, text in row.items():
            if lang != "keys" and text:
                lang_chars.setdefault(lang, set()).update(ord(c) for c in text if ord(c) > 0x20)
for chars in lang_chars.values():
    keep |= chars

opts = subset.Options()
opts.layout_features = ["*"]
opts.notdef_outline = True
opts.name_IDs = ["*"]
opts.hinting = True
opts.glyph_names = False
opts.legacy_kern = True
opts.drop_tables += ["DSIG"]
font = TTFont(SRC)
cmap = font.getBestCmap()
present = sorted(c for c in keep if c in cmap)
bad = False
for lang, chars in sorted(lang_chars.items()):
    missing = sorted(c for c in chars if c not in cmap)
    if missing and lang not in FALLBACK_LANGS:
        bad = True
        print(f"HATA: {lang} sutununda Baloo2'de olmayan karakterler: {''.join(chr(c) for c in missing)}")
    elif missing:
        print(f"bilgi: {lang}: {len(missing)} karakter sistem yazi tipine duser (beklenen)")
if bad:
    sys.exit(1)
if "--check" in sys.argv:
    print("kontrol tamam: Latin dillerinde eksik karakter yok")
    sys.exit(0)
sub = subset.Subsetter(opts)
sub.populate(unicodes=present)
sub.subset(font)
font.save(DST)
print(f"{len(present)} karakter, {len(font.getGlyphOrder())} glif, {os.path.getsize(SRC)} -> {os.path.getsize(DST)} bayt")
