#!/usr/bin/env python3
"""Mandal kaplamalarını üretir: assets/sprites/pin.png'yi yeniden renklendirir.

Neden yeniden boyama: orijinal sprite'ın gölge/ışık dağılımı korunur, böylece her kaplama
aynı boyutta, aynı çapada ve aynı "yumuşak 3B" görünümde kalır. Ahşabın damarı plastik
kaplamalarda bulanıklaştırılarak pürüzsüz bir malzeme hissi verilir. Çıktı: assets/sprites/skins/pin_<id>.png
Kullanım: python3 tools/make_pin_skins.py   (Blender gerekmez)
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SRC = "assets/sprites/pin.png"
OUT = "assets/sprites/skins"
SS = 4  # süper örnekleme: süs çizimleri pürüzsüz kenarlı olsun
WOOD_MEDIAN = 0.83  # orijinal ahşabın ortanca parlaklığı (gölge hesabı bunun etrafında)
SPRING_SAT = 0.15  # bunun altı yay/metal kabul edilir ve renklendirilmez

# id: (taban renk, damar bulanıklığı 0..1, yay rengi ya da None, süs)
SKINS = {
    "mint": ((143, 214, 184), 0.85, None, None),
    "sky": ((148, 198, 240), 0.85, None, None),
    "butter": ((246, 215, 122), 0.85, None, None),
    "bamboo": ((176, 190, 98), 0.35, None, "bamboo"),
    "metal": ((170, 182, 196), 0.9, (226, 190, 110), "metal"),
    "star": ((242, 120, 112), 0.85, None, "star"),
    "tulip": ((226, 72, 84), 0.85, None, "tulip"),
    "cactus": ((84, 170, 112), 0.8, None, "cactus"),
    "lotus": ((236, 130, 178), 0.85, None, "lotus"),
}


def blur(arr, radius):
    img = Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8))
    return np.asarray(img.filter(ImageFilter.GaussianBlur(radius))).astype(float) / 255


def recolor(src, base, smooth, spring, kind):
    a = np.asarray(src).astype(float) / 255
    rgb, alpha = a[..., :3], a[..., 3]
    mx, mn = rgb.max(-1), rgb.min(-1)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    lum = 0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]
    shade_src = (1 - smooth) * lum + smooth * blur(lum, 2.2)
    shade = np.clip((shade_src - WOOD_MEDIAN) / 0.22, -1, 1)
    b = np.array(base) / 255.0
    dark = b * 0.68
    light = b + (1 - b) * 0.42
    shade3 = shade[..., None]
    body = np.where(shade3 < 0, b + (dark - b) * (-shade3), b + (light - b) * shade3)
    wood_mask = (sat > SPRING_SAT)[..., None]
    out = np.where(wood_mask, body, rgb)
    if kind == "metal":
        # Metal: doymamış, yüksek kontrastlı çelik; yay altın.
        steel = np.clip(0.80 + shade * 0.42, 0, 1)[..., None] * np.array([0.86, 0.91, 0.97])
        out = np.where(wood_mask, steel, out)
    if spring is not None:
        spring_col = np.array(spring) / 255.0
        spring_shade = np.clip(lum / 0.9, 0.35, 1.15)[..., None]
        out = np.where(wood_mask, out, np.clip(spring_col * spring_shade, 0, 1))
    res = np.dstack([np.clip(out, 0, 1), alpha])
    return Image.fromarray((res * 255).astype(np.uint8), "RGBA")


def star_points(cx, cy, r, inner=0.5):
    pts = []
    for i in range(10):
        radius = r if i % 2 == 0 else r * inner
        ang = -math.pi / 2 + math.pi / 5 * i
        pts.append((cx + math.cos(ang) * radius, cy + math.sin(ang) * radius))
    return pts


def decal(size, kind, base):
    """Mandalın üst gövdesine konan küçük, düz süs. Sonra mandal alfasıyla kırpılır."""
    w, h = size
    layer = Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cx, cy = 64 * SS, 54 * SS
    if kind == "star":
        d.polygon(star_points(cx, cy, 17 * SS), fill=(255, 226, 120, 255))
        d.polygon(star_points(cx, cy + SS, 8 * SS), fill=(255, 244, 196, 255))
    elif kind == "tulip":
        col = (255, 236, 220, 255)
        # Lale tomurcuğu: yuvarlak gövde + üç kısa, yumuşak uç (ortadaki biraz yüksek).
        d.ellipse((cx - 10 * SS, cy - 4 * SS, cx + 10 * SS, cy + 18 * SS), fill=col)
        d.polygon([(cx - 10 * SS, cy + 4 * SS), (cx - 10 * SS, cy - 6 * SS), (cx - 5 * SS, cy - 1 * SS),
                   (cx, cy - 10 * SS), (cx + 5 * SS, cy - 1 * SS), (cx + 10 * SS, cy - 6 * SS),
                   (cx + 10 * SS, cy + 4 * SS)], fill=col)
    elif kind == "cactus":
        col = (244, 250, 236, 255)
        for dy in (-18, -6, 6, 18, 30):
            for dx in (-9, 9):
                off = 0 if (dy // 12) % 2 == 0 else 5
                x, y = cx + (dx + off) * SS, cy + dy * SS
                d.ellipse((x - 2 * SS, y - 2 * SS, x + 2 * SS, y + 2 * SS), fill=col)
    elif kind == "lotus":
        col = (255, 240, 246, 255)
        # Beş yuvarlak taç yaprak: merkezden dışa doğru yayılan elipsler.
        for ang in (-72, -36, 0, 36, 72):
            rad = math.radians(ang - 90)
            px, py = cx + math.cos(rad) * 11 * SS, cy + 6 * SS + math.sin(rad) * 11 * SS
            d.ellipse((px - 6 * SS, py - 6 * SS, px + 6 * SS, py + 6 * SS), fill=col)
        d.ellipse((cx - 6 * SS, cy, cx + 6 * SS, cy + 12 * SS), fill=(250, 200, 120, 255))
    elif kind == "bamboo":
        # Bambu boğumları: ince koyu bantlar.
        for y in (30, 78, 176, 214):
            d.rectangle((30 * SS, y * SS, 98 * SS, (y + 3) * SS), fill=(110, 124, 56, 150))
    return layer.resize((w, h), Image.LANCZOS)


def main():
    os.makedirs(OUT, exist_ok=True)
    src = Image.open(SRC).convert("RGBA")
    for skin_id, (base, smooth, spring, kind) in SKINS.items():
        image = recolor(src, base, smooth, spring, kind)
        if kind in ("star", "tulip", "cactus", "lotus", "bamboo"):
            layer = decal(src.size, kind, base)
            # Süs yalnız mandalın içinde kalsın (alfa ile kırp).
            la = np.asarray(layer).astype(float)
            sa = np.asarray(src.split()[3]).astype(float) / 255
            la[..., 3] *= sa
            layer = Image.fromarray(la.astype(np.uint8), "RGBA")
            image = Image.alpha_composite(image, layer)
        path = os.path.join(OUT, "pin_%s.png" % skin_id)
        image.save(path)
        print("yazildi", path)


if __name__ == "__main__":
    main()
