#!/usr/bin/env python3
"""Renk desen glifleri atlası: assets/sprites/patterns/glyphs.png

Neden ayrı atlas: kuyruk/HUD noktaları 20-28 px; shader deseni orada çözünmez. Glifler 4x
süperörnekleme ile çizilir (kenarlar pürüzsüz), tek dokuda 7 hücre durur -> tek çizim grubu.
Hücre sırası = ColorPatterns.PATTERN_BY_COLOR sırası (0 düz/boş, 1 dikey çizgi, 2 puan, 3 kare,
4 çapraz çizgi, 5 zikzak, 6 artı). Beyaz + alfa: oyun koda göre koyu/açık boyar.
Çalıştır: python3 tools/make_patterns.py
"""
import math
from pathlib import Path

from PIL import Image, ImageDraw

CELL = 64          # px / hücre
SS = 4             # süperörnekleme
COUNT = 7
OUT = Path(__file__).resolve().parent.parent / "assets/sprites/patterns/glyphs.png"
R = 0.40           # glifin hücre içindeki yarıçapı (nokta içine sığsın)


def canvas():
    size = CELL * SS
    img = Image.new("L", (size, size), 0)
    return img, ImageDraw.Draw(img), size


def circle_mask(size):
    m = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(m)
    c = size / 2
    r = size * R
    d.ellipse([c - r, c - r, c + r, c + r], fill=255)
    return m


def g_stripes(d, s):
    # üç kalın dikey çubuk
    c = s / 2
    w = s * 0.062
    for k in (-1, 0, 1):
        x = c + k * s * 0.205
        d.rounded_rectangle([x - w, c - s * R, x + w, c + s * R], radius=w, fill=255)


def g_dots(d, s):
    c = s / 2
    r = s * 0.095
    for dx, dy in ((-0.17, -0.12), (0.17, -0.12), (0.0, 0.17)):
        d.ellipse([c + dx * s - r, c + dy * s - r, c + dx * s + r, c + dy * s + r], fill=255)


def g_checks(d, s):
    c = s / 2
    q = s * 0.2
    # 2x2 satranç: sol-üst ve sağ-alt dolu
    d.rectangle([c - q * 1.0, c - q * 1.0, c, c], fill=255)
    d.rectangle([c, c, c + q * 1.0, c + q * 1.0], fill=255)


def g_diag(d, s):
    c = s / 2
    w = s * 0.045
    for k in (-1, 0, 1):
        off = k * s * 0.27
        # 45° çubuklar (sağ üste doğru)
        a = (c - s * 0.5 + off, c + s * 0.5)
        b = (c + s * 0.5 + off, c - s * 0.5)
        d.line([a, b], fill=255, width=int(w * 2))


def g_zigzag(d, s):
    c = s / 2
    w = int(s * 0.085)
    for k in (-1, 1):
        y = c + k * s * 0.17
        pts = [(c - s * 0.36, y + s * 0.07), (c - s * 0.12, y - s * 0.09),
               (c + s * 0.12, y + s * 0.07), (c + s * 0.36, y - s * 0.09)]
        d.line(pts, fill=255, width=w, joint="curve")


def g_plus(d, s):
    c = s / 2
    a = s * 0.075
    L = s * 0.3
    d.rounded_rectangle([c - a, c - L, c + a, c + L], radius=a, fill=255)
    d.rounded_rectangle([c - L, c - a, c + L, c + a], radius=a, fill=255)


GLYPHS = [None, g_stripes, g_dots, g_checks, g_diag, g_zigzag, g_plus]


def main():
    atlas = Image.new("RGBA", (CELL * COUNT, CELL), (255, 255, 255, 0))
    for i, fn in enumerate(GLYPHS):
        if fn is None:
            continue
        img, d, s = canvas()
        fn(d, s)
        # daire dışına taşan uçlar kırpılır
        from PIL import ImageChops
        img = ImageChops.multiply(img, circle_mask(s))
        img = img.resize((CELL, CELL), Image.LANCZOS)
        cell = Image.new("RGBA", (CELL, CELL), (255, 255, 255, 0))
        cell.putalpha(img)
        atlas.alpha_composite(cell, (i * CELL, 0))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(OUT)
    print("yazildi", OUT)


if __name__ == "__main__":
    main()
