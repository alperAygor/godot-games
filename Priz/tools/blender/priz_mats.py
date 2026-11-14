"""Priz — malzeme kütüphanesi (tek kaynak).

Bu tablo iki yerde kullanılır:
1. Blender betikleri yüzeylere bu ADLARLA malzeme atar (önizleme rengiyle).
2. `python3 tools/blender/priz_mats.py` tabloyu `assets/materials/<ad>.tres` olarak yazar.
Godot içe aktarma betiği GLB yüzeylerini adla bu .tres dosyalarına bağlar.

Alanlar:
  albedo      : renk (hex) — doku varsa çarpan
  tex         : doku seti öneki (assets/textures/<tex>_albedo|_normal|_orm.png)
  albedo_tex / normal_tex / orm_tex : tek tek doku adı (tex'i ezer)
  tile        : dokunun kapladığı metre (uv1_scale = 1/tile); UV'ler metre cinsindendir
  rough, metal: doku yoksa değer; ORM varsa çarpan
  normal      : normal şiddeti
  alpha       : saydamlık (0..1) → alfa karışımı
  cull        : "back" | "disabled"
  rim, rim_tint : kumaş yumuşak parlaklığı
  backlight   : arkadan ışık geçirme rengi (perde, abajur)
  emission    : (hex, enerji)
  vcol        : köşe rengi (pişmiş AO) albedo çarpanı — varsayılan True
  shader      : özel gölgelendirici (assets/shaders/<ad>.gdshader) + params
"""

import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

# Hat renkleri (1..4): kırmızı/daire, mavi/üçgen, sarı/kare, mor/elmas
LINE_COLORS_PACKED = ("PackedColorArray(0.878, 0.341, 0.29, 1, 0.247, 0.561, 0.847, 1, 0.91, 0.698, 0.227, 1, "
                      "0.604, 0.416, 0.839, 1)")

MATERIALS = {
    # --- ahşap
    "wood_oak": dict(tex="wood_oak", tile=0.9, normal=0.6),
    "wood_walnut": dict(tex="wood_walnut", tile=0.9, normal=0.6),
    "floor_planks": dict(tex="floor_planks", tile=2.6, normal=0.45, aniso=True),
    # --- boya, sıva, duvar
    "wall_cream": dict(albedo="#eee3cf", albedo_tex="plaster_albedo", normal_tex="plaster_normal",
                       orm_tex="plaster_orm", tile=1.2, normal=0.5),
    "wall_sage": dict(albedo="#a7b39a", albedo_tex="plaster_albedo", normal_tex="plaster_normal",
                      orm_tex="plaster_orm", tile=1.2, normal=0.5),
    "wallpaper": dict(tex="wallpaper", tile=0.55, normal=0.3),
    "wall_cut": dict(albedo="#5a4d45", normal_tex="plaster_normal", orm_tex="plaster_orm", tile=0.6, normal=0.4),
    "wall_exterior": dict(albedo="#b9ad9e", normal_tex="plaster_normal", orm_tex="plaster_orm", tile=0.8),
    "paint_white": dict(albedo="#f1ece3", normal_tex="paintwood_normal", orm_tex="paintwood_orm", tile=0.8,
                        normal=0.4),
    "paint_sage": dict(albedo="#8ea08a", normal_tex="paintwood_normal", orm_tex="paintwood_orm", tile=0.8,
                       normal=0.4),
    "tiles_cream": dict(albedo="#f2ece0", tex="tiles", tile=0.6, normal=1.0),
    # --- kumaş
    "fabric_teal": dict(albedo="#3f6f73", tex="fabric", tile=0.18, normal=0.8, rim=0.35, rim_tint=0.6),
    "fabric_mustard": dict(albedo="#cf9a3c", tex="fabric", tile=0.18, normal=0.8, rim=0.35, rim_tint=0.6),
    "fabric_terracotta": dict(albedo="#c0674a", tex="fabric", tile=0.18, normal=0.8, rim=0.35, rim_tint=0.6),
    "fabric_oat": dict(albedo="#e2d5bd", tex="fabric", tile=0.18, normal=0.8, rim=0.3, rim_tint=0.5),
    "fabric_charcoal": dict(albedo="#5a5a5e", tex="fabric", tile=0.18, normal=0.8, rim=0.3, rim_tint=0.5),
    "linen_curtain": dict(albedo="#f1e7d6", tex="linen", tile=0.35, normal=0.6, cull="disabled",
                          backlight="#b89a70", rim=0.2, rim_tint=0.4),
    "rug_kilim": dict(tex="rug_kilim", tile=0.0, normal=0.6, rim=0.25, rim_tint=0.7),
    "leather_tan": dict(albedo="#9b6a43", tex="leather", tile=0.3, normal=0.6),
    # --- metal
    "steel_brushed": dict(tex="brushed", tile=0.4, metal=1.0, normal=0.25),
    "chrome": dict(albedo="#e0e0e0", rough=0.1, metal=1.0, vcol=False),
    "brass": dict(albedo="#c9a35b", normal_tex="brushed_normal", tile=0.3, rough=0.28, metal=1.0, normal=0.2),
    "black_metal": dict(albedo="#2a2b2e", normal_tex="peel_normal", orm_tex="peel_orm", tile=0.25, rough=1.2,
                        metal=0.0, normal=0.3),
    "enamel_white": dict(albedo="#f3f1ec", normal_tex="peel_normal", orm_tex="peel_orm", tile=0.25, normal=0.25),
    "enamel_cream": dict(albedo="#efe1c4", normal_tex="peel_normal", orm_tex="peel_orm", tile=0.25, normal=0.25),
    "enamel_mint": dict(albedo="#9ccabb", normal_tex="peel_normal", orm_tex="peel_orm", tile=0.25, normal=0.25),
    "enamel_red": dict(albedo="#c8473b", normal_tex="peel_normal", orm_tex="peel_orm", tile=0.25, normal=0.25),
    "enamel_graphite": dict(albedo="#3a3d42", normal_tex="peel_normal", orm_tex="peel_orm", tile=0.25,
                            normal=0.25),
    # --- plastik, kauçuk
    "plastic_white": dict(albedo="#f4f1ea", normal_tex="peel_normal", orm_tex="peel_orm", tile=0.15, rough=1.1,
                          normal=0.15),
    "plastic_black": dict(albedo="#1d1e20", normal_tex="peel_normal", orm_tex="peel_orm", tile=0.15, rough=1.1,
                          normal=0.15),
    "plastic_grey": dict(albedo="#8b8e92", normal_tex="peel_normal", orm_tex="peel_orm", tile=0.15, rough=1.2,
                         normal=0.15),
    "plastic_red": dict(albedo="#c23b2e", normal_tex="peel_normal", orm_tex="peel_orm", tile=0.15, rough=1.0,
                        normal=0.15),
    "rubber_black": dict(albedo="#1a1a1b", rough=0.75),
    # Hat renkli boya (sigorta kutusu levhaları/kolları; vc_peel'e toplanır)
    "paint_line1": dict(albedo="#e0574a", rough=0.4),
    "paint_line2": dict(albedo="#3f8fd8", rough=0.4),
    "paint_line3": dict(albedo="#e8b23a", rough=0.4),
    "paint_line4": dict(albedo="#9a6ad6", rough=0.4),
    # --- cam, seramik
    "glass_clear": dict(albedo="#dfeef0", alpha=0.18, rough=0.04, metal=0.0, vcol=False, specular=0.7),
    "glass_dark": dict(albedo="#0d0f12", alpha=0.82, rough=0.06, vcol=False, specular=0.7),
    "glass_amber": dict(albedo="#c98a3c", alpha=0.6, rough=0.06, vcol=False, specular=0.7),
    "ceramic_white": dict(albedo="#f2efe8", rough=0.16),
    "ceramic_blue": dict(albedo="#3d6787", rough=0.14),
    "ceramic_green": dict(albedo="#7d9c7a", rough=0.18),
    "ceramic_mustard": dict(albedo="#d4a443", rough=0.2),
    "terracotta": dict(albedo="#b9663f", normal_tex="plaster_normal", orm_tex="plaster_orm", tile=0.3,
                       normal=0.6),
    # --- bitki
    "leaf": dict(tex="leaf", tile=0.0, normal=0.5, cull="disabled", backlight="#4a6a2a"),
    "leaf_dark": dict(albedo="#7d9a78", tex="leaf", tile=0.0, normal=0.5, cull="disabled", backlight="#30451e"),
    "stem": dict(albedo="#58703c", rough=0.6),
    "soil": dict(tex="soil", tile=0.25, normal=0.8),
    "hob_glass": dict(albedo="#0c0c0d", rough=0.06, specular=0.7),
    "hob_mark": dict(albedo="#7a7a7a", rough=0.3),
    "wicker": dict(albedo="#c79a62", tex="fabric", tile=0.05, normal=1.2),
    "fruit_orange": dict(albedo="#e5862a", normal_tex="peel_normal", tile=0.04, rough=0.45, normal=0.8),
    "fruit_lemon": dict(albedo="#e9c84a", normal_tex="peel_normal", tile=0.04, rough=0.4, normal=0.8),
    "fruit_apple": dict(albedo="#b8352c", rough=0.3),
    "food_pasta": dict(albedo="#e7c27d", rough=0.7),
    "food_lentil": dict(albedo="#b4502c", rough=0.7),
    "food_rice": dict(albedo="#f1ecdf", rough=0.7),
    "food_bread": dict(albedo="#b9773a", normal_tex="leather_normal", tile=0.08, rough=0.75, normal=0.6),
    "food_toast": dict(albedo="#e3c28b", normal_tex="fabric_normal", tile=0.03, rough=0.85, normal=0.6),
    "fan_blade": dict(albedo="#a9cfc3", rough=0.32, cull="disabled", vcol=False),
    # --- atlas, kağıt
    "books": dict(albedo_tex="books_albedo", rough=0.7, tile=0.0),
    "art": dict(albedo_tex="art_albedo", rough=0.65, tile=0.0),
    "paper": dict(albedo="#efe6d3", rough=0.85),
    "candle": dict(albedo="#f1e6cf", rough=0.5, backlight="#e0a060"),
    # --- fiş kablosu (fiziksel kablo, plug_cable.gd)
    "cable_plug": dict(albedo="#ece8e0", rough=0.45, vcol=False),
    # --- efekt yüzeyleri (çalışma anında betikle sürülür)
    "fx_oven_glow": dict(shader="oven_glow", params=dict(noise_tex="tex:noise_rgba")),
    "fx_coil": dict(shader="heat_coil", params=dict(noise_tex="tex:noise_rgba")),
    "fx_tv_screen": dict(shader="tv_screen", params=dict(art_tex="tex:art_albedo")),
    "fx_lamp_shade": dict(albedo="#f3e2c0", tex="linen", tile=0.12, normal=0.4, cull="disabled",
                          backlight="#5a4028", emission=("#ffcf8a", 0.0), vcol=False),
    "fx_bulb": dict(albedo="#fff4dc", rough=0.2, emission=("#ffd59a", 0.0), vcol=False),
    "fx_indicator": dict(albedo="#2a2d2a", rough=0.2, emission=("#7dff9a", 0.0), vcol=False),
    "fx_window_sky": dict(shader="window_sky", params=dict(city_tex="tex:city_masks", noise_tex="tex:noise_rgba")),
    "fx_gauge": dict(shader="fuse_gauge"),
    "fx_cables": dict(shader="cable_lines", params=dict(line_colors=LINE_COLORS_PACKED)),
    "fx_socket_marker": dict(shader="socket_marker", params=dict(line_colors=LINE_COLORS_PACKED)),
    "fx_fan_blur": dict(shader="fan_blur", params=dict(blade_color="#a9cfc3")),
    "fx_dial": dict(albedo_tex="dial_albedo", rough=0.4, tile=0.0, vcol=False),
    "fx_glow_strip": dict(albedo="#fff1d6", rough=0.3, emission=("#ffd08a", 0.0), vcol=False),
    "fx_drum": dict(albedo="#c9ccd0", normal_tex="brushed_normal", tile=0.08, rough=0.25, metal=1.0, vcol=False),
}


# ---------------------------------------------------------------- birleşik (köşe rengiyle renklenen) malzemeler
# Çizim çağrısını azaltmak için: yalnız rengi farklı olan malzemeler tek bir ortak malzemeye toplanır,
# renk (doğrusal) × pişmiş AO köşe rengine (COLOR_0) yazılır. Blender'da priz_bl.collapse_materials().
VC_GROUPS = {
    "vc_plaster": dict(albedo="#ffffff", albedo_tex="plaster_albedo", normal_tex="plaster_normal",
                       orm_tex="plaster_orm", tile=1.0, normal=0.5),
    "vc_paint": dict(albedo="#ffffff", normal_tex="paintwood_normal", orm_tex="paintwood_orm", tile=0.8, normal=0.4),
    "vc_fabric": dict(albedo="#ffffff", tex="fabric", tile=0.18, normal=0.8, rim=0.35, rim_tint=0.6),
    "vc_peel": dict(albedo="#ffffff", normal_tex="peel_normal", orm_tex="peel_orm", tile=0.2, normal=0.25),
    "vc_gloss": dict(albedo="#ffffff", rough=0.18),
    "vc_matte": dict(albedo="#ffffff", rough=0.72),
    "vc_metal": dict(albedo="#ffffff", normal_tex="brushed_normal", tile=0.3, rough=0.2, metal=1.0, normal=0.15),
    "vc_leaf": dict(albedo="#ffffff", tex="leaf", tile=0.0, normal=0.5, cull="disabled", backlight="#3c5522"),
}
VC_MEMBERS = {
    "vc_plaster": ["wall_cream", "wall_sage", "wall_cut", "wall_exterior", "terracotta"],
    "vc_paint": ["paint_white", "paint_sage"],
    "vc_fabric": ["fabric_teal", "fabric_mustard", "fabric_terracotta", "fabric_oat", "fabric_charcoal"],
    "vc_peel": ["enamel_white", "enamel_cream", "enamel_mint", "enamel_red", "enamel_graphite", "plastic_white",
                "plastic_black", "plastic_grey", "plastic_red", "black_metal", "paint_line1", "paint_line2",
                "paint_line3", "paint_line4"],
    "vc_gloss": ["ceramic_white", "ceramic_blue", "ceramic_green", "ceramic_mustard", "fruit_orange", "fruit_lemon",
                 "fruit_apple", "hob_mark", "candle"],
    "vc_matte": ["paper", "stem", "food_pasta", "food_lentil", "food_rice", "food_bread", "food_toast", "rubber_black"],
    "vc_metal": ["chrome", "brass"],
    "vc_leaf": ["leaf", "leaf_dark"],
}
GROUP_OF = {m: g for g, ms in VC_MEMBERS.items() for m in ms}


def _hex(c):
    c = c.lstrip("#")
    return tuple(int(c[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def _lin(c):
    return tuple((x / 12.92) if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def preview_color(spec):
    """Blender önizlemesi için doğrusal renk."""
    if "albedo" in spec:
        return _lin(_hex(spec["albedo"]))
    return (0.6, 0.6, 0.6)


# ---------------------------------------------------------------- .tres yazımı

def _color(c, a=1.0):
    r, g, b = _hex(c)
    return f"Color({r:.4f}, {g:.4f}, {b:.4f}, {a:.4f})"


def _tex_path(name):
    return f"res://assets/textures/{name}.png"


def write_tres(name, spec, out_dir):
    path = os.path.join(out_dir, f"{name}.tres")
    if "shader" in spec:
        ext = [f'[ext_resource type="Shader" path="res://assets/shaders/{spec["shader"]}.gdshader" id="1"]']
        body = ["[resource]", f'resource_name = "{name}"', 'shader = ExtResource("1")']
        for k, v in spec.get("params", {}).items():
            if isinstance(v, str) and v.startswith("tex:"):
                tid = str(len(ext) + 1)
                ext.append(f'[ext_resource type="Texture2D" path="{_tex_path(v[4:])}" id="{tid}"]')
                body.append(f'shader_parameter/{k} = ExtResource("{tid}")')
            elif isinstance(v, str) and v.startswith("#"):
                body.append(f"shader_parameter/{k} = {_color(v)}")
            elif isinstance(v, str) and v.startswith("Packed"):
                body.append(f"shader_parameter/{k} = {v}")
            else:
                body.append(f"shader_parameter/{k} = {v}")
        lines = ['[gd_resource type="ShaderMaterial" format=3]', ""] + ext + [""] + body
        with open(path, "w") as f:
            f.write("\n".join(lines) + "\n")
        return path

    albedo_tex = spec.get("albedo_tex") or (f"{spec['tex']}_albedo" if "tex" in spec else None)
    normal_tex = spec.get("normal_tex") or (f"{spec['tex']}_normal" if "tex" in spec else None)
    orm_tex = spec.get("orm_tex") or (f"{spec['tex']}_orm" if "tex" in spec else None)
    for t in (albedo_tex, normal_tex, orm_tex):
        if t and not os.path.exists(os.path.join(ROOT, "assets", "textures", f"{t}.png")):
            raise FileNotFoundError(f"{name}: doku yok {t}")
    ext = []
    ids = {}
    for key, t in (("albedo", albedo_tex), ("normal", normal_tex), ("orm", orm_tex)):
        if t:
            ids[key] = str(len(ext) + 1)
            ext.append(f'[ext_resource type="Texture2D" path="{_tex_path(t)}" id="{ids[key]}"]')
    rtype = "ORMMaterial3D" if orm_tex else "StandardMaterial3D"
    lines = [f'[gd_resource type="{rtype}" format=3]', ""]
    if ext:
        lines += ext + [""]
    lines += ["[resource]", f'resource_name = "{name}"']
    alpha = spec.get("alpha")
    if alpha is not None:
        lines.append("transparency = 1")
        lines.append("depth_draw_mode = 1")
    if spec.get("cull") == "disabled":
        lines.append("cull_mode = 2")
    if spec.get("vcol", True):
        lines.append("vertex_color_use_as_albedo = true")
    lines.append(f"albedo_color = {_color(spec.get('albedo', '#ffffff'), alpha if alpha is not None else 1.0)}")
    if "albedo" in ids:
        lines.append(f'albedo_texture = ExtResource("{ids["albedo"]}")')
    if "specular" in spec:
        lines.append(f"metallic_specular = {spec['specular']}")
    if "orm" in ids:
        lines.append(f'orm_texture = ExtResource("{ids["orm"]}")')
        lines.append(f"roughness = {min(spec.get('rough', 1.0), 1.0)}")
        lines.append(f"metallic = {spec.get('metal', 0.0)}")
    else:
        lines.append(f"roughness = {spec.get('rough', 0.6)}")
        lines.append(f"metallic = {spec.get('metal', 0.0)}")
    if "normal" in ids:
        lines.append("normal_enabled = true")
        lines.append(f"normal_scale = {spec.get('normal', 1.0)}")
        lines.append(f'normal_texture = ExtResource("{ids["normal"]}")')
    if "rim" in spec:
        lines.append("rim_enabled = true")
        lines.append(f"rim = {spec['rim']}")
        lines.append(f"rim_tint = {spec.get('rim_tint', 0.5)}")
    if "backlight" in spec:
        lines.append("backlight_enabled = true")
        lines.append(f"backlight = {_color(spec['backlight'])}")
    if "emission" in spec:
        col, energy = spec["emission"]
        lines.append("emission_enabled = true")
        lines.append(f"emission = {_color(col)}")
        lines.append(f"emission_energy_multiplier = {energy}")
    tile = spec.get("tile", 1.0)
    if tile and tile > 0:
        s = 1.0 / tile
        lines.append(f"uv1_scale = Vector3({s:.4f}, {s:.4f}, {s:.4f})")
    if spec.get("aniso"):
        lines.append("texture_filter = 5")
    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")
    return path


def main():
    out = os.path.join(ROOT, "assets", "materials")
    os.makedirs(out, exist_ok=True)
    written = 0
    for name, spec in MATERIALS.items():
        stale = os.path.join(out, f"{name}.tres")
        if name in GROUP_OF:
            # Ortak "vc_*" malzemesine toplanan renk kaynağı: çalışma anında kullanılmaz, dosyası yazılmaz.
            if os.path.exists(stale):
                os.remove(stale)
            continue
        write_tres(name, spec, out)
        written += 1
    for name, spec in VC_GROUPS.items():
        write_tres(name, spec, out)
        written += 1
    print(f"priz_mats: {written} malzeme -> assets/materials/")


if __name__ == "__main__":
    main()
