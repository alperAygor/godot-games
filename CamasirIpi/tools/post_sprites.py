#!/usr/bin/env python3
"""Nötr (renk çarpımıyla boyanan) sprite'ların tonunu dengeler: en açık bölgeler beyaza
yakın olur, gölgeler korunur. Böylece oyun rengi çamurlaşmadan doygun görünür.
Ayrıca sepetin çimdeki yumuşak temas gölgesini (basket_shadow.png) üretir.

    python3 tools/post_sprites.py        (make_sprites.py'den sonra)

İdempotent: işlenen PNG'ye bir metin işareti yazılır; ikinci çalıştırmada atlanır
(Blender yeniden render edince işaret kalkar ve dosya yeniden dengelenir).
"""
import glob
import os

import numpy as np
from PIL import Image, ImageFilter, PngImagePlugin

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPRITES = os.path.join(ROOT, "assets", "sprites")
BASKET = os.path.join(SPRITES, "basket")
# Her grup TEK beyaz noktayla dengelenir. Sepet astarının arka/ön yarısı oyunda yan yana durur:
# ayrı ayrı dengelenseler yan kenardaki birleşme yerinde ton sıçraması görünürdü.
GROUPS = [[path] for path in sorted(glob.glob(os.path.join(SPRITES, "garment_*.png")))] + [
    [os.path.join(SPRITES, "folded.png")],
    [os.path.join(BASKET, "band_back.png"), os.path.join(BASKET, "band_front.png")]]
MARK = "camasir_post"
VERSION = "2"
# Beyaz nokta: görünen piksellerin %97'si -> yalnız en parlak sheen/rim tepeleri kırpılır.
WHITE_POINT_PERCENTILE = 97.0
# Orta tonlar biraz koyulaşır (hacim okunur), gölgeler tabandan kaldırılır (renk çamurlaşmaz).
GAMMA = 1.25
SHADOW_LIFT = 0.15


def balance_group(paths):
    paths = [path for path in paths if os.path.exists(path)]
    if not paths:
        return
    sources = [Image.open(path) for path in paths]
    if all(source.info.get(MARK) == VERSION for source in sources):
        for path in paths:
            print("zaten dengeli:", os.path.relpath(path, ROOT))
        return
    images = [np.asarray(source.convert("RGBA")).astype(np.float32) / 255.0 for source in sources]
    visible = np.concatenate([image[..., :3].mean(axis=2)[image[..., 3] > 0.5] for image in images])
    if visible.size == 0:
        return
    white = max(float(np.percentile(visible, WHITE_POINT_PERCENTILE)), 1e-3)
    for path, image in zip(paths, images):
        alpha = image[..., 3]
        level = np.clip(image[..., :3].mean(axis=2) / white, 0.0, 1.0) ** GAMMA
        level = SHADOW_LIFT + (1.0 - SHADOW_LIFT) * level
        # Tamamen saydam piksellerde renk beyaz tutulur: filtrelemede kenarda koyu hale oluşmaz.
        level = np.where(alpha > 0.0, level, 1.0)
        out = np.dstack([level, level, level, alpha])
        info = PngImagePlugin.PngInfo()
        info.add_text(MARK, VERSION)
        Image.fromarray((np.clip(out, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8)).save(path, pnginfo=info)
        print("dengelendi:", os.path.relpath(path, ROOT))


# --- Sepet temas gölgesi -----------------------------------------------------------------------
# Neden Blender'da değil: gölge yakalayıcı tüm zemine hafif gri bir örtü bırakıyordu (çim kirlenir).
# Ayak izi iki sepet katmanının birleşik alfasından çıkarılır -> kamera/biçim değişse de oturur.
SHADOW_OUT = os.path.join(BASKET, "basket_shadow.png")
SHADOW_SCALE = 2          # 512'lik sepet karesi -> 256'lık gölge (yumuşak olduğu için yeter)
SHADOW_RGB = (24, 38, 30)  # serin, hafif yeşil koyu: çimde gri leke değil gölge gibi okunur
CORE_ALPHA = 0.5
CORE_BLUR = 3.5
HALO_ALPHA = 0.26
HALO_BLUR = 16.0
HALO_GROW = 1.12
# Anahtar ışık soldan gelir: geniş yarı gölge hafif sağa kayar (temas çekirdeği tam altta kalır).
HALO_SHIFT = (9, 4)


def make_basket_shadow():
    layers = [os.path.join(BASKET, name) for name in ("basket_back.png", "basket_front.png")]
    if not all(os.path.exists(path) for path in layers):
        return
    alpha = np.zeros((512, 512), dtype=np.float32)
    for path in layers:
        alpha = np.maximum(alpha, np.asarray(Image.open(path).convert("RGBA"))[..., 3].astype(np.float32) / 255.0)
    rows = np.where(alpha.max(axis=1) > 0.5)[0]
    if rows.size == 0:
        return
    bottom = rows.max()
    # Ayak elipsi: genişlik = en alt satırın üstündeki dolu genişlik (kulplar hariç alt bölge).
    lower = alpha[bottom - 40:bottom - 30] > 0.5
    span = np.where(lower.any(axis=0))[0]
    half_w = 0.5 * (span.max() - span.min()) * 1.04
    center_x = 0.5 * (span.max() + span.min())
    half_h = half_w * 0.5
    center_y = bottom - half_h * 0.92
    size = 512 // SHADOW_SCALE
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32) * SHADOW_SCALE

    def ellipse(grow, shift):
        dx = (xx - center_x - shift[0]) / (half_w * grow)
        dy = (yy - center_y - shift[1]) / (half_h * grow)
        return Image.fromarray(((dx * dx + dy * dy) <= 1.0).astype(np.uint8) * 255)

    core = np.asarray(ellipse(1.0, (0, 0)).filter(ImageFilter.GaussianBlur(CORE_BLUR))).astype(np.float32) / 255.0
    halo = np.asarray(ellipse(HALO_GROW, HALO_SHIFT).filter(ImageFilter.GaussianBlur(HALO_BLUR))).astype(np.float32) / 255.0
    shadow = np.clip(1.0 - (1.0 - CORE_ALPHA * core) * (1.0 - HALO_ALPHA * halo), 0.0, 1.0)
    out = np.zeros((size, size, 4), dtype=np.uint8)
    out[..., 0], out[..., 1], out[..., 2] = SHADOW_RGB
    out[..., 3] = (shadow * 255.0 + 0.5).astype(np.uint8)
    Image.fromarray(out).save(SHADOW_OUT)
    print("gölge:", os.path.relpath(SHADOW_OUT, ROOT), "merkez=(%.0f,%.0f) yarıçap=(%.0f,%.0f)"
          % (center_x, center_y, half_w, half_h))


for group in GROUPS:
    balance_group(group)
make_basket_shadow()
