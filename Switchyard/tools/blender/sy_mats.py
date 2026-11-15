"""Switchyard — malzeme kütüphanesi (tek kaynak).

1. Blender betikleri yüzeylere bu ADLARLA malzeme atar (önizleme rengiyle).
2. `python3 tools/blender/sy_mats.py` tabloyu `assets/materials/<ad>.tres` olarak yazar.
3. `assets/models/sy_post_import.gd` GLB yüzeylerini adla bu .tres dosyalarına bağlar.

Çizim çağrısı için: yalnız rengi farklı parçalar ortak "vc_*" malzemesine toplanır (renk x pişmiş AO köşe
renginde; `sy_bl.collapse_materials`). Boyanabilir gövde yüzeyi `paint` adını taşır: ArtKit çalışma anında
onu `paint_<renk>.tres` ile değiştirir (köşe rengi = AO, albedo = vagon rengi).

Alanlar: albedo, tex/albedo_tex/normal_tex/orm_tex, tile, rough, metal, normal, alpha, cull, rim, rim_tint,
emission (hex, enerji), vcol (varsayılan True), specular, unshaded, shader (+params; assets/materials/shaders/).
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import sy_spec  # noqa: E402

ROOT = sy_spec.ROOT

MATERIALS = {
    # --- araç yüzeyleri (çoğu vc_* gruplarına toplanır)
    "paint": dict(albedo="#e9e4d8", rough=0.42, specular=0.45),
    "loco_body": dict(albedo=sy_spec.LOCO_COLORS["body"], rough=0.38),
    "loco_cab": dict(albedo=sy_spec.LOCO_COLORS["cab"], rough=0.42),
    "stripe_yellow": dict(albedo=sy_spec.LOCO_COLORS["stripe"], rough=0.45),
    "stripe_dark": dict(albedo=sy_spec.LOCO_COLORS["stripe_dark"], rough=0.5),
    "frame_dark": dict(albedo="#2c3034", rough=0.62),
    "frame_grey": dict(albedo="#5d646b", rough=0.6),
    "roof_grey": dict(albedo="#b9bcbc", rough=0.55),
    "deck_wood": dict(albedo="#8a6a4c", rough=0.8),
    "rubber": dict(albedo="#1e1f21", rough=0.85),
    "buffer_red": dict(albedo="#b8473c", rough=0.5),
    "cream": dict(albedo="#efe7d6", rough=0.5),
    "symbol_white": dict(albedo=sy_spec.SYMBOL_COLOR, rough=0.45),
    "steel": dict(albedo="#9aa1a6", rough=0.32, metal=0.85),
    "steel_dark": dict(albedo="#4b5157", rough=0.4, metal=0.7),
    "brass": dict(albedo="#caa55c", rough=0.3, metal=1.0),
    "coil_steel": dict(albedo="#a8adb0", rough=0.28, metal=0.9),
    # --- tek başına malzemeler
    "glass": dict(albedo="#1b2630", rough=0.08, specular=0.8, vcol=False),
    "glass_load": dict(albedo="#bfe3e6", alpha=0.42, rough=0.05, specular=0.9, vcol=False, cull="disabled"),
    "lamp_front": dict(albedo="#fff6df", rough=0.2, emission=("#ffe7b0", 1.6), vcol=False),
    "lamp_rear": dict(albedo="#7a1e18", rough=0.25, emission=("#ff3a28", 0.6), vcol=False),
    "symbol": dict(albedo=sy_spec.SYMBOL_COLOR, rough=0.5, emission=(sy_spec.SYMBOL_COLOR, 0.12)),
    # --- hat
    "sleeper_wood": dict(albedo="#ffffff", tex="sleeper", tile=0.0, rough=0.85, normal=0.6),
    "sleeper_concrete": dict(albedo="#c9c6bf", rough=0.85),
    "rail": dict(albedo="#ffffff", rough=0.38, metal=0.65),
    "track_prop": dict(albedo="#ffffff", rough=0.55),
    # --- çevre (köşe renkli gruplara toplanır)
    "brick": dict(albedo="#b45f45", rough=0.85),
    "plaster_cream": dict(albedo="#eadfc8", rough=0.85),
    "wood_board": dict(albedo="#9c7651", rough=0.8),
    "wood_dark": dict(albedo="#5e4633", rough=0.8),
    "wood_paint_green": dict(albedo="#4f7a5c", rough=0.6),
    "wood_paint_white": dict(albedo="#f0ebe0", rough=0.6),
    "roof_slate": dict(albedo="#57606a", rough=0.7),
    "roof_red": dict(albedo="#b2523e", rough=0.65),
    "metal_paint_grey": dict(albedo="#8e969c", rough=0.5),
    "metal_paint_yellow": dict(albedo="#e9b22f", rough=0.45),
    "metal_paint_blue": dict(albedo="#456f93", rough=0.45),
    "metal_paint_red": dict(albedo="#b84a3d", rough=0.45),
    "metal_paint_white": dict(albedo="#e9e6df", rough=0.45),
    "concrete": dict(albedo="#bdb8ae", rough=0.9),
    "concrete_dark": dict(albedo="#8f8b84", rough=0.9),
    "stone": dict(albedo="#a59d90", rough=0.9),
    "tyre": dict(albedo="#25272a", rough=0.85),
    "rope": dict(albedo="#c9b48a", rough=0.9),
    "leaf_light": dict(albedo="#8fbf5a", rough=0.8),
    "leaf_mid": dict(albedo="#6ea64a", rough=0.8),
    "leaf_dark": dict(albedo="#4d8a43", rough=0.8),
    "leaf_conifer": dict(albedo="#3f7650", rough=0.8),
    "leaf_autumn": dict(albedo="#d99a3a", rough=0.8),
    "bark": dict(albedo="#6b5340", rough=0.9),
    "flower_white": dict(albedo="#f6f1e6", rough=0.7),
    "flower_pink": dict(albedo="#e88aa0", rough=0.7),
    "flower_yellow": dict(albedo="#f2cc4a", rough=0.7),
    "container_red": dict(albedo="#a9473d", rough=0.55),
    "container_blue": dict(albedo="#3e6585", rough=0.55),
    "container_teal": dict(albedo="#3f8582", rough=0.55),
    "container_sand": dict(albedo="#cdb58a", rough=0.55),
    "container_grey": dict(albedo="#8c9296", rough=0.55),
    "water_tank": dict(albedo="#4f6c7a", rough=0.45),
    "sign_red": dict(albedo="#d23c32", rough=0.45),
    "sign_white": dict(albedo="#f4f1ea", rough=0.45),
    "asphalt_paint": dict(albedo="#f1ede3", rough=0.7),
    "snow": dict(albedo="#f3f6f8", rough=0.6),
    "rock": dict(albedo="#8a8781", rough=0.9),
    # --- yer işaretleri, vurgu (çalışma anında)
    "marker_ring": dict(albedo="#ffffff", rough=0.6, vcol=True),
    "ghost": dict(shader="ghost", params=dict(tint="#9fe3ff")),
    "highlight": dict(shader="highlight", params=dict(tint="#fff3c4")),
    "lamp_green": dict(albedo="#1f5c35", rough=0.2, emission=("#5dff8a", 1.2), vcol=False),
    "lamp_red": dict(albedo="#5c1f1f", rough=0.2, emission=("#ff5a4a", 1.2), vcol=False),
    "lamp_warm": dict(albedo="#fff1d0", rough=0.2, emission=("#ffd48a", 0.9), vcol=False),
    "window_warm": dict(albedo="#2c3640", rough=0.1, specular=0.7, emission=("#ffcf8a", 0.0), vcol=False),
}

# Paint varyantları (çalışma anında ArtKit.apply_color): albedo = vagon rengi, köşe rengi = AO.
for _c, _h in sy_spec.COLORS.items():
    MATERIALS[f"paint_{_c}"] = dict(albedo=_h, rough=0.42, specular=0.45)
# Yer hedefi renkleri (çakılda boyalı işaret; hafif ışıma ile gölgede de okunur)
for _c, _h in sy_spec.COLORS.items():
    MATERIALS[f"marker_{_c}"] = dict(albedo=_h, rough=0.7, emission=(_h, 0.18), vcol=False)
MATERIALS["marker_loco"] = dict(albedo=sy_spec.LOCO_TARGET_COLOR, rough=0.7, emission=("#ffffff", 0.12), vcol=False)

VC_GROUPS = {
    "vc_satin": dict(albedo="#ffffff", rough=0.42, specular=0.45),
    "vc_matte": dict(albedo="#ffffff", rough=0.82),
    "vc_metal": dict(albedo="#ffffff", rough=0.34, metal=0.8),
    "vc_leaf": dict(albedo="#ffffff", rough=0.78, rim=0.25, rim_tint=0.7),
}
VC_MEMBERS = {
    "vc_satin": ["loco_body", "loco_cab", "stripe_yellow", "stripe_dark", "buffer_red", "cream", "symbol_white",
                 "wood_paint_green", "wood_paint_white", "metal_paint_grey", "metal_paint_yellow",
                 "metal_paint_blue", "metal_paint_red", "metal_paint_white", "container_red", "container_blue",
                 "container_teal", "container_sand", "container_grey", "water_tank", "sign_red", "sign_white",
                 "roof_red", "roof_grey"],
    "vc_matte": ["frame_dark", "frame_grey", "deck_wood", "rubber", "brick", "plaster_cream", "wood_board",
                 "wood_dark", "roof_slate", "concrete", "concrete_dark", "stone", "tyre", "rope", "bark",
                 "asphalt_paint", "snow", "rock"],
    "vc_metal": ["steel", "steel_dark", "brass", "coil_steel"],
    "vc_leaf": ["leaf_light", "leaf_mid", "leaf_dark", "leaf_conifer", "leaf_autumn", "flower_white",
                "flower_pink", "flower_yellow"],
}
GROUP_OF = {m: g for g, ms in VC_MEMBERS.items() for m in ms}


def _hex(c):
    c = c.lstrip("#")
    return tuple(int(c[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def _lin(c):
    return tuple((x / 12.92) if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def preview_color(spec):
    if "albedo" in spec:
        return _lin(_hex(spec["albedo"]))
    return (0.6, 0.6, 0.6)


def _color(c, a=1.0):
    r, g, b = _hex(c)
    return f"Color({r:.4f}, {g:.4f}, {b:.4f}, {a:.4f})"


def _tex_path(name):
    return f"res://assets/textures/{name}.png"


def write_tres(name, spec, out_dir):
    path = os.path.join(out_dir, f"{name}.tres")
    if "shader" in spec:
        ext = [f'[ext_resource type="Shader" path="res://assets/materials/shaders/{spec["shader"]}.gdshader" id="1"]']
        body = ["[resource]", f'resource_name = "{name}"', 'shader = ExtResource("1")']
        for k, v in spec.get("params", {}).items():
            if isinstance(v, str) and v.startswith("tex:"):
                tid = str(len(ext) + 1)
                ext.append(f'[ext_resource type="Texture2D" path="{_tex_path(v[4:])}" id="{tid}"]')
                body.append(f'shader_parameter/{k} = ExtResource("{tid}")')
            elif isinstance(v, str) and v.startswith("#"):
                body.append(f"shader_parameter/{k} = {_color(v)}")
            else:
                body.append(f"shader_parameter/{k} = {v}")
        lines = [f'[gd_resource type="ShaderMaterial" load_steps={len(ext) + 1} format=3]', ""] + ext + [""] + body
        with open(path, "w") as f:
            f.write("\n".join(lines) + "\n")
        return path

    albedo_tex = spec.get("albedo_tex") or (f"{spec['tex']}_albedo" if "tex" in spec else None)
    normal_tex = spec.get("normal_tex") or (f"{spec['tex']}_normal" if "tex" in spec else None)
    orm_tex = spec.get("orm_tex")
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
    lines = [f'[gd_resource type="{rtype}" load_steps={len(ext) + 1} format=3]', ""]
    if ext:
        lines += ext + [""]
    lines += ["[resource]", f'resource_name = "{name}"']
    alpha = spec.get("alpha")
    if alpha is not None:
        lines.append("transparency = 1")
    if spec.get("cull") == "disabled":
        lines.append("cull_mode = 2")
    if spec.get("unshaded"):
        lines.append("shading_mode = 0")
    if spec.get("vcol", True):
        lines.append("vertex_color_use_as_albedo = true")
    lines.append(f"albedo_color = {_color(spec.get('albedo', '#ffffff'), alpha if alpha is not None else 1.0)}")
    if "albedo" in ids:
        lines.append(f'albedo_texture = ExtResource("{ids["albedo"]}")')
    if "specular" in spec:
        lines.append(f"metallic_specular = {spec['specular']}")
    if "orm" in ids:
        lines.append(f'orm_texture = ExtResource("{ids["orm"]}")')
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
    if "emission" in spec:
        col, energy = spec["emission"]
        lines.append("emission_enabled = true")
        lines.append(f"emission = {_color(col)}")
        lines.append(f"emission_energy_multiplier = {energy}")
    tile = spec.get("tile", 1.0)
    if tile and tile > 0 and ext:
        s = 1.0 / tile
        lines.append(f"uv1_scale = Vector3({s:.4f}, {s:.4f}, {s:.4f})")
    if ext:
        lines.append("texture_filter = 5")
    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")
    return path


def main():
    out = os.path.join(ROOT, "assets", "materials")
    os.makedirs(out, exist_ok=True)
    written = 0
    for name, spec in MATERIALS.items():
        if name in GROUP_OF:
            stale = os.path.join(out, f"{name}.tres")
            if os.path.exists(stale):
                os.remove(stale)
            continue
        write_tres(name, spec, out)
        written += 1
    for name, spec in VC_GROUPS.items():
        write_tres(name, spec, out)
        written += 1
    print(f"sy_mats: {written} malzeme -> assets/materials/")


if __name__ == "__main__":
    main()
