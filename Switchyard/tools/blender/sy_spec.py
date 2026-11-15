"""Switchyard — sanat kitinin TEK ölçü/renk kaynağı.

Blender betikleri bu modülü içe aktarır; `python3 sy_spec.py` (ya da build_all.sh) aynı değerleri
`scripts/game/art/art_dims.gd` olarak yazar ki Godot tarafı (TrackBuilder, ArtKit) aynı sayıları kullansın.

Eksen sözleşmesi (Godot): 1 ızgara birimi = 1 m. Hücre (x, y) -> Godot (x, 0, y). Y yukarı.
Ray üstü Godot y = 0'dadır; araçlar orijinleri ray üstünde (tekerlek altı) ve +Z'ye bakar.
Zemin (çim/apron) GROUND_Y'dedir; çevre modellerinin orijini kendi tabanlarıdır ve GROUND_Y'ye konur.
Blender'da Z yukarıdır ve glTF ihracı Godot (x, y, z) = Blender (x, z, -y) yapar; yani Blender -Y = Godot +Z.
"""

import os

# ---------------------------------------------------------------- hat
GAUGE = 0.26              # ray merkezleri arası
RAIL_H = 0.040            # ray yüksekliği (taban -> mantar üstü)
RAIL_HEAD_W = 0.026
RAIL_FOOT_W = 0.050
SLEEPER_L = 0.46
SLEEPER_W = 0.066
SLEEPER_H = 0.024
SLEEPER_STEP = 0.165      # hedef aralık (kenar uzunluğuna tam bölünecek şekilde yuvarlanır)
SLEEPER_TOP = -RAIL_H
BALLAST_TOP = SLEEPER_TOP - SLEEPER_H * 0.55   # traversler balasta biraz gömülü
BALLAST_TOP_W = 0.56
BALLAST_BOTTOM_W = 0.76
GROUND_Y = BALLAST_TOP - 0.032
APRON_Y = GROUND_Y + 0.004   # apron (çakıl saha) çimden biraz yüksek: kenar okunur

# ---------------------------------------------------------------- araç
VEHICLE_W = 0.48          # gövde genişliği (paralel hatlar 1.0 aralıklı -> 0.52 boşluk)
HEADSTOCK_LEN = 0.74      # tampon kirişleri arası
OVER_BUFFERS = 0.86       # tampon başları arası; düz hatta araçlar arası boşluk 0.14
BUFFER_Y = 0.125          # tampon/kanca merkez yüksekliği (ray üstünden)
BUFFER_SPACING = 0.30     # iki tampon arası (merkez)
WHEEL_R = 0.068
FRAME_Y = 0.105           # şasi alt yüzü
COUPLER_Z = OVER_BUFFERS / 2.0   # kanca noktası (yerel +Z/-Z)

# ---------------------------------------------------------------- renk + simge (renk asla tek ipucu değil)
# sRGB onaltılık. Sırası CORE_API'deki renk adlarıyla aynı.
COLORS = {
    "red": "#D9453B",
    "blue": "#3A78D0",
    "yellow": "#F0B42A",
    "green": "#3E9E58",
    "purple": "#8A58C4",
    "orange": "#EE7F2C",
}
SYMBOLS = {
    "red": "circle",
    "blue": "triangle",
    "yellow": "star",
    "green": "cross",
    "purple": "diamond",
    "orange": "square",
    "loco": "loco",
}
SYMBOL_COLOR = "#FFFBF2"       # simge beyazı (sıcak)
LOCO_COLORS = {"body": "#34495A", "cab": "#EFE6D2", "stripe": "#F2C230", "stripe_dark": "#2A2E33"}
LOCO_TARGET_COLOR = "#F4F0E4"  # lokomotif hedefi: krem halka + lokomotif simgesi

# ---------------------------------------------------------------- dünya
WORLDS = {1: "depot", 2: "harbour", 3: "mountain", 4: "factory"}

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def _gd_color(h):
    h = h.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    return f"Color({r:.4f}, {g:.4f}, {b:.4f})"


def write_gd():
    """scripts/game/art/art_dims.gd — ÜRETİLİR, elle düzenlenmez."""
    names = ["GAUGE", "RAIL_H", "RAIL_HEAD_W", "RAIL_FOOT_W", "SLEEPER_L", "SLEEPER_W", "SLEEPER_H",
             "SLEEPER_STEP", "SLEEPER_TOP", "BALLAST_TOP", "BALLAST_TOP_W", "BALLAST_BOTTOM_W", "GROUND_Y",
             "APRON_Y", "VEHICLE_W", "HEADSTOCK_LEN", "OVER_BUFFERS", "BUFFER_Y", "BUFFER_SPACING", "WHEEL_R",
             "FRAME_Y", "COUPLER_Z"]
    g = globals()
    lines = ["# ÜRETİLİR: tools/blender/sy_spec.py -> elle düzenleme (build_all.sh yeniden yazar).",
             "class_name ArtDims", "extends RefCounted", "",
             "## Sanat kitinin ölçüleri (1 birim = 1 hücre = 1 m). Ray üstü y = 0.", ""]
    for n in names:
        lines.append(f"const {n}: float = {g[n]:.5f}")
    lines.append("")
    lines.append("const COLOR_NAMES: PackedStringArray = [%s]" % ", ".join(f'"{c}"' for c in COLORS))
    lines.append("const COLORS: Dictionary[String, Color] = {")
    for c, h in COLORS.items():
        lines.append(f'\t"{c}": {_gd_color(h)},')
    lines.append("}")
    lines.append("const SYMBOLS: Dictionary[String, String] = {")
    for c, s in SYMBOLS.items():
        lines.append(f'\t"{c}": "{s}",')
    lines.append("}")
    lines.append(f"const SYMBOL_COLOR: Color = {_gd_color(SYMBOL_COLOR)}")
    lines.append(f"const LOCO_TARGET_COLOR: Color = {_gd_color(LOCO_TARGET_COLOR)}")
    path = os.path.join(ROOT, "scripts", "game", "art", "art_dims.gd")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")
    print("sy_spec: yazıldı scripts/game/art/art_dims.gd")


if __name__ == "__main__":
    write_gd()
