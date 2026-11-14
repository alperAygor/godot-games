#!/usr/bin/env python3
"""Baloo2'yi oyunda kullanilan karakterlere indirger (fontTools; pyftsubset gerekmez).

Kaynak: tools/fontsrc/Baloo2-full.ttf  ->  cikti: assets/fonts/Baloo2.ttf
Karakter kumesi: ASCII + Latin-1 + Latin Ek-A (tr/es/en ve yakin diller) + noktalama/para birimi/oklar
                 + depodaki tum .gd/.csv/.json/.tscn/.tres metinlerinde gecen her karakter.
Yeni dil eklenirse (ör. Kiril/Devanagari) bu betigi yeniden calistirin; tam font tools/fontsrc'de durur.
Yerlesim ozellikleri (GPOS/GSUB: kern, birlesik harf), degisken eksen (wght) ve hinting korunur.
"""
import os, sys
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
sub = subset.Subsetter(opts)
sub.populate(unicodes=present)
sub.subset(font)
font.save(DST)
print(f"{len(present)} karakter, {len(font.getGlyphOrder())} glif, {os.path.getsize(SRC)} -> {os.path.getsize(DST)} bayt")
