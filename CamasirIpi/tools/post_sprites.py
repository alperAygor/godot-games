#!/usr/bin/env python3
"""Nötr (renk çarpımıyla boyanan) sprite'ların tonunu dengeler: en açık bölgeler beyaza
yakın olur, gölgeler korunur. Böylece oyun rengi çamurlaşmadan doygun görünür.

    python3 tools/post_sprites.py        (make_sprites.py'den sonra)

İdempotent: işlenen PNG'ye bir metin işareti yazılır; ikinci çalıştırmada atlanır
(Blender yeniden render edince işaret kalkar ve dosya yeniden dengelenir).
"""
import glob
import os

import numpy as np
from PIL import Image, PngImagePlugin

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NEUTRAL = sorted(glob.glob(os.path.join(ROOT, "assets", "sprites", "garment_*.png"))) + [
    os.path.join(ROOT, "assets", "sprites", name) for name in ("folded.png", "basket_band.png")]
MARK = "camasir_post"
VERSION = "2"
# Beyaz nokta: görünen piksellerin %97'si -> yalnız en parlak sheen/rim tepeleri kırpılır.
WHITE_POINT_PERCENTILE = 97.0
# Orta tonlar biraz koyulaşır (hacim okunur), gölgeler tabandan kaldırılır (renk çamurlaşmaz).
GAMMA = 1.25
SHADOW_LIFT = 0.15

for path in NEUTRAL:
    if not os.path.exists(path):
        continue
    source = Image.open(path)
    if source.info.get(MARK) == VERSION:
        print("zaten dengeli:", os.path.relpath(path, ROOT))
        continue
    image = np.asarray(source.convert("RGBA")).astype(np.float32) / 255.0
    alpha = image[..., 3]
    luminance = image[..., :3].mean(axis=2)
    visible = luminance[alpha > 0.5]
    if visible.size == 0:
        continue
    white = max(float(np.percentile(visible, WHITE_POINT_PERCENTILE)), 1e-3)
    level = np.clip(luminance / white, 0.0, 1.0) ** GAMMA
    level = SHADOW_LIFT + (1.0 - SHADOW_LIFT) * level
    # Tamamen saydam piksellerde renk beyaz tutulur: filtrelemede kenarda koyu hale oluşmaz.
    level = np.where(alpha > 0.0, level, 1.0)
    out = np.dstack([level, level, level, alpha])
    info = PngImagePlugin.PngInfo()
    info.add_text(MARK, VERSION)
    Image.fromarray((np.clip(out, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8)).save(path, pnginfo=info)
    print("dengelendi:", os.path.relpath(path, ROOT))
