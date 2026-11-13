#!/usr/bin/env python3
"""Nötr (renk çarpımıyla boyanan) sprite'ların tonunu dengeler: en açık bölgeler beyaza
yakın olur, gölgeler korunur. Böylece oyun rengi çamurlaşmadan doygun görünür.

    python3 tools/post_sprites.py        (make_sprites.py'den sonra)
"""
import glob
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NEUTRAL = sorted(glob.glob(os.path.join(ROOT, "assets", "sprites", "garment_*.png"))) + [
    os.path.join(ROOT, "assets", "sprites", name) for name in ("folded.png", "basket_band.png")]
WHITE_POINT_PERCENTILE = 92.0
SHADOW_LIFT = 0.18

for path in NEUTRAL:
    image = np.asarray(Image.open(path).convert("RGBA")).astype(np.float32) / 255.0
    alpha = image[..., 3]
    luminance = image[..., :3].mean(axis=2)
    visible = luminance[alpha > 0.5]
    if visible.size == 0:
        continue
    white = max(float(np.percentile(visible, WHITE_POINT_PERCENTILE)), 1e-3)
    level = np.clip(luminance / white, 0.0, 1.0)
    # Gölgeler biraz açılır: çarpılan renk kararmasın, ama kıvrım okunur kalsın.
    level = SHADOW_LIFT + (1.0 - SHADOW_LIFT) * level
    out = np.dstack([level, level, level, alpha])
    Image.fromarray((np.clip(out, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8), "RGBA").save(path)
    print("dengelendi:", os.path.relpath(path, ROOT))
