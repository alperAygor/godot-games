#!/usr/bin/env python3
"""Uygulama simgesi + mağaza simgesi + öne çıkan grafik üretici (yalnız proje sanatından).

Kaynak: assets/sprites/garment_*.png (beyaz, çarpımla renklenir) + pin.png.
Çıktı:
  assets/icons/app/icon.png            192x192  (eski/yedek ana simge, project.godot config/icon)
  assets/icons/app/adaptive_fg.png     432x432  (güvenli bölge: orta 264 px daire)
  assets/icons/app/adaptive_bg.png     432x432
  assets/icons/app/adaptive_mono.png   432x432  (tek renk, yalnız alfa kullanılır)
  docs/store/assets/icon_512.png       512x512  (Play mağaza simgesi, alfalı)
  docs/store/assets/feature_1024x500.png (alfasız)
Çalıştırma: python3 tools/make_app_icons.py   (Pillow gerekir; indirme yok)
"""
import math
import os
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageChops

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPR = os.path.join(ROOT, "assets", "sprites")
APP_OUT = os.path.join(ROOT, "assets", "icons", "app")
STORE_OUT = os.path.join(ROOT, "docs", "store", "assets")
SS = 4  # süper örnekleme


def tint(path: str, rgb: tuple) -> Image.Image:
    """Beyaz giysiyi çarpımla renklendirir; alfa korunur."""
    img = Image.open(os.path.join(SPR, path)).convert("RGBA")
    solid = Image.new("RGBA", img.size, rgb + (255,))
    out = ImageChops.multiply(img, solid)
    out.putalpha(img.getchannel("A"))
    return out


def crop_alpha(img: Image.Image) -> Image.Image:
    box = img.getchannel("A").getbbox()
    return img.crop(box) if box else img


def sky(size: tuple) -> Image.Image:
    w, h = size
    img = Image.new("RGB", size)
    px = img.load()
    top, bot = (120, 196, 238), (255, 240, 214)
    for y in range(h):
        t = y / max(h - 1, 1)
        t = t * t * (3 - 2 * t)
        c = tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3))
        for x in range(w):
            px[x, y] = c
    # yumuşak bulutlar
    cl = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(cl)
    for cx, cy, r in ((0.2, 0.22, 0.11), (0.3, 0.2, 0.09), (0.12, 0.26, 0.08),
                      (0.82, 0.72, 0.10), (0.9, 0.7, 0.07), (0.74, 0.75, 0.07)):
        d.ellipse([w * cx - w * r, h * cy - w * r * 0.6, w * cx + w * r, h * cy + w * r * 0.6],
                  fill=(255, 255, 255, 150))
    alpha = cl.getchannel("A").filter(ImageFilter.GaussianBlur(w * 0.02))
    cl = Image.new("RGBA", size, (255, 255, 255, 0))
    cl.putalpha(alpha)
    img = img.convert("RGBA")
    img.alpha_composite(cl)
    return img


def draw_line_scene(size: tuple, items: list, rope_y: float, sag: float, rope_w: float,
                    mono: bool = False) -> Image.Image:
    """Saydam zeminde ip + asılı giysiler + mandallar. items: (dosya, renk, merkez_x, genişlik, açı)."""
    w, h = size
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    pts = []
    for i in range(0, 101):
        t = i / 100
        x = w * (-0.05 + 1.1 * t)
        y = rope_y * h + sag * h * math.sin(math.pi * t)
        pts.append((x, y))
    rope_col = (255, 255, 255, 255) if mono else (96, 70, 52, 255)
    d.line(pts, fill=rope_col, width=int(rope_w), joint="curve")

    def rope_at(xf: float) -> float:
        t = (xf / w + 0.05) / 1.1
        return rope_y * h + sag * h * math.sin(math.pi * t)

    pin = Image.open(os.path.join(SPR, "pin.png")).convert("RGBA")
    for fname, rgb, cx, gw, angle in items:
        g = crop_alpha(tint(fname, rgb))
        scale = gw * w / g.width
        g = g.resize((int(g.width * scale), int(g.height * scale)), Image.LANCZOS)
        if mono:
            solid = Image.new("RGBA", g.size, (255, 255, 255, 255))
            solid.putalpha(g.getchannel("A"))
            g = solid
        g = g.rotate(angle, resample=Image.BICUBIC, expand=True)
        ry = rope_at(cx * w)
        x0 = int(cx * w - g.width / 2)
        y0 = int(ry - g.height * 0.06)
        layer.alpha_composite(g, (x0, y0))
        # iki mandal (omuz hizası)
        pw = int(gw * w * 0.09)
        p = pin.resize((pw, int(pw * 2)), Image.LANCZOS)
        if mono:
            sp = Image.new("RGBA", p.size, (255, 255, 255, 255))
            sp.putalpha(p.getchannel("A"))
            p = sp
        for off in (-0.26, 0.26):
            px_ = int(cx * w + off * gw * w - p.width / 2)
            layer.alpha_composite(p, (px_, int(ry - p.height * 0.62)))
    return layer


def shadowed(layer: Image.Image, blur: float, dy: int, alpha: int) -> Image.Image:
    sh = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    a = layer.getchannel("A").point(lambda v: int(v * alpha / 255))
    sh.putalpha(a)
    sh = sh.filter(ImageFilter.GaussianBlur(blur))
    out = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    out.alpha_composite(sh, (0, dy))
    out.alpha_composite(layer)
    return out


CORAL = (240, 96, 96)
TEAL = (70, 190, 190)
SUN = (250, 196, 64)


def icon_items() -> list:
    return [("garment_tshirt.png", CORAL, 0.29, 0.40, 6),
            ("garment_dress.png", TEAL, 0.71, 0.40, -5)]


def fg_layer(px: int, mono: bool = False) -> Image.Image:
    """Adaptif ön plan: tüm içerik orta ~61 % (66/108) güvenli dairede."""
    big = px * SS
    # içerik 264/432 oranında bir kareye sığdırılır, ortalanır
    inner_px = int(big * 264 / 432)
    inner = draw_line_scene((inner_px, inner_px), icon_items(), 0.22, 0.04, inner_px * 0.018, mono)
    if not mono:
        inner = shadowed(inner, inner_px * 0.012, int(inner_px * 0.012), 70)
    layer = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    layer.alpha_composite(inner, ((big - inner_px) // 2, int((big - inner_px) * 0.62)))
    return layer.resize((px, px), Image.LANCZOS)


def full_icon(px: int) -> Image.Image:
    """Düz (adaptif olmayan) simge: gökyüzü + ip + giysiler, köşeler yuvarlak değil (Play maskeler)."""
    big = px * SS
    bg = sky((big, big))
    scene = draw_line_scene((big, big), icon_items(), 0.34, 0.05, big * 0.014)
    scene = shadowed(scene, big * 0.008, int(big * 0.01), 70)
    bg.alpha_composite(scene)
    return bg.resize((px, px), Image.LANCZOS)


def feature_graphic() -> Image.Image:
    w, h = 1024 * SS, 500 * SS
    bg = sky((w, h))
    items = [("garment_tshirt.png", CORAL, 0.14, 0.17, 7), ("garment_sock.png", SUN, 0.31, 0.12, -6),
             ("garment_dress.png", TEAL, 0.50, 0.16, 4), ("garment_pants.png", (110, 130, 230), 0.70, 0.14, -4),
             ("garment_towel.png", (170, 110, 220), 0.87, 0.14, 5)]
    scene = draw_line_scene((w, h), items, 0.10, 0.05, h * 0.008)
    scene = shadowed(scene, h * 0.006, int(h * 0.008), 70)
    bg.alpha_composite(scene)
    # başlık: proje yazı tipi (Baloo2), koyu lacivert + hafif gölge
    from PIL import ImageFont
    font = ImageFont.truetype(os.path.join(ROOT, "assets", "fonts", "Baloo2.ttf"), int(h * 0.20))
    title = "Clothesline Sort"
    txt = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    td = ImageDraw.Draw(txt)
    box = td.textbbox((0, 0), title, font=font)
    tx, ty = (w - (box[2] - box[0])) // 2 - box[0], int(h * 0.70)
    td.text((tx, ty), title, font=font, fill=(38, 62, 110, 255))
    bg.alpha_composite(shadowed(txt, h * 0.004, int(h * 0.006), 60))
    return bg.resize((1024, 500), Image.LANCZOS).convert("RGB")


def main() -> int:
    os.makedirs(APP_OUT, exist_ok=True)
    os.makedirs(STORE_OUT, exist_ok=True)
    full_icon(192).convert("RGBA").save(os.path.join(APP_OUT, "icon.png"), optimize=True)
    fg_layer(432).save(os.path.join(APP_OUT, "adaptive_fg.png"), optimize=True)
    sky((432, 432)).convert("RGB").save(os.path.join(APP_OUT, "adaptive_bg.png"), optimize=True)
    fg_layer(432, mono=True).save(os.path.join(APP_OUT, "adaptive_mono.png"), optimize=True)
    full_icon(512).save(os.path.join(STORE_OUT, "icon_512.png"), optimize=True)
    feature_graphic().save(os.path.join(STORE_OUT, "feature_1024x500.png"), optimize=True)
    print("tamam:", APP_OUT, STORE_OUT)
    return 0


if __name__ == "__main__":
    sys.exit(main())
