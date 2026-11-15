#!/usr/bin/env python3
"""Android başlatıcı simgeleri (T-R1 ara çözümü; T-R2 marka sanatı gelince yolları değiştirir).

Çıktı (assets/launcher_icons/):
  icon.png            192x192  eski/yedek ana simge   -> launcher_icons/main_192x192
  adaptive_fg.png     432x432  ön plan, güvenli bölge: ortadaki 264 px daire (432 px = 108 dp, güvenli = 66 dp)
  adaptive_bg.png     432x432  arka plan (düz renk geçişi)
  adaptive_mono.png   432x432  tek renk katmanı (yalnız alfa kullanılır; Android 13+ temalı simge)
Kaynak: yalnız bu betik çizer (banknot + damga); dış varlık/indirme yok, gerçek ülke/banknot imgesi yok.
Çalıştırma: python3 tools/make_launcher_icons.py   (Pillow gerekir)
"""
import os
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "launcher_icons")
SS = 4  # süper örnekleme (pürüzsüz kenar)
NAVY_TOP, NAVY_BOT = (34, 44, 70), (18, 24, 40)
PAPER, PAPER_EDGE, INK = (238, 228, 196), (196, 176, 128), (54, 74, 96)
STAMP = (196, 52, 52)


def _gradient(size: int) -> Image.Image:
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        t = y / (size - 1)
        c = tuple(int(NAVY_TOP[i] + (NAVY_BOT[i] - NAVY_TOP[i]) * t) for i in range(3))
        for x in range(size):
            px[x, y] = c
    return img


def _banknote(size: int, mono: bool) -> Image.Image:
    """Güvenli bölgeye (merkez 61%) sığan, hafif eğik banknot + damga. RGBA, saydam zemin."""
    big = size * SS
    layer = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    w, h = int(big * 0.50), int(big * 0.29)
    x0, y0 = (big - w) // 2, (big - h) // 2 + int(big * 0.02)
    r = int(h * 0.12)
    if mono:
        d.rounded_rectangle([x0, y0, x0 + w, y0 + h], r, fill=(255, 255, 255, 255))
        # iç çerçeve ve daire oyuk (alfa 0): okunur siluet
        m = int(h * 0.10)
        d.rounded_rectangle([x0 + m, y0 + m, x0 + w - m, y0 + h - m], r, outline=(0, 0, 0, 0), width=int(h * 0.05))
        cx, cy, cr = x0 + w // 2, y0 + h // 2, int(h * 0.26)
        d.ellipse([cx - cr, cy - cr, cx + cr, cy + cr], fill=(0, 0, 0, 0))
    else:
        d.rounded_rectangle([x0, y0, x0 + w, y0 + h], r, fill=PAPER, outline=PAPER_EDGE, width=int(h * 0.04))
        m = int(h * 0.11)
        d.rounded_rectangle([x0 + m, y0 + m, x0 + w - m, y0 + h - m], r, outline=INK, width=int(h * 0.025))
        cx, cy, cr = x0 + w // 2, y0 + h // 2, int(h * 0.26)
        d.ellipse([cx - cr, cy - cr, cx + cr, cy + cr], outline=INK, width=int(h * 0.04))
        d.ellipse([cx - cr // 2, cy - cr // 2, cx + cr // 2, cy + cr // 2], fill=INK)
        for sx in (x0 + m * 2, x0 + w - m * 2):
            d.ellipse([sx - h * 0.07, cy - h * 0.07, sx + h * 0.07, cy + h * 0.07], fill=INK)
    layer = layer.rotate(8, resample=Image.BICUBIC, center=(big // 2, big // 2))
    # damga: sağ altta dairesel, hafif yarı saydam halka + onay işareti
    stamp = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    sd = ImageDraw.Draw(stamp)
    sx, sy, sr = int(big * 0.60), int(big * 0.62), int(big * 0.115)
    col = (255, 255, 255, 255) if mono else STAMP + (235,)
    sd.ellipse([sx - sr, sy - sr, sx + sr, sy + sr], outline=col, width=int(sr * 0.22))
    sd.line([(sx - sr * 0.45, sy), (sx - sr * 0.1, sy + sr * 0.4), (sx + sr * 0.5, sy - sr * 0.4)],
            fill=col, width=int(sr * 0.24), joint="curve")
    if mono:
        # damganın etrafını banknottan ayır
        halo = Image.new("L", (big, big), 0)
        ImageDraw.Draw(halo).ellipse([sx - sr * 1.25, sy - sr * 1.25, sx + sr * 1.25, sy + sr * 1.25], fill=255)
        clear = Image.new("RGBA", (big, big), (0, 0, 0, 0))
        layer = Image.composite(clear, layer, halo)
    layer.alpha_composite(stamp)
    if not mono:  # yumuşak gölge
        shadow = Image.new("RGBA", (big, big), (0, 0, 0, 0))
        shadow.putalpha(layer.getchannel("A").filter(ImageFilter.GaussianBlur(big * 0.012)).point(lambda v: int(v * 0.45)))
        shadow = shadow.transform(shadow.size, Image.AFFINE, (1, 0, 0, 0, 1, -big * 0.012))
        shadow.alpha_composite(layer)
        layer = shadow
    return layer.resize((size, size), Image.LANCZOS)


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    bg = _gradient(432)
    bg.save(os.path.join(OUT, "adaptive_bg.png"))
    _banknote(432, mono=False).save(os.path.join(OUT, "adaptive_fg.png"))
    mono = _banknote(432, mono=True)
    mono.save(os.path.join(OUT, "adaptive_mono.png"))
    # eski simge: bg + fg, yuvarlatılmış köşe
    flat = _gradient(192).convert("RGBA")
    flat.alpha_composite(_banknote(192, mono=False).resize((192, 192), Image.LANCZOS))
    mask = Image.new("L", (192 * SS, 192 * SS), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, 192 * SS - 1, 192 * SS - 1], 40 * SS, fill=255)
    flat.putalpha(mask.resize((192, 192), Image.LANCZOS))
    flat.save(os.path.join(OUT, "icon.png"))
    for name in sorted(os.listdir(OUT)):
        if name.endswith(".png"):
            print("yazıldı: assets/launcher_icons/" + name)


if __name__ == "__main__":
    main()
