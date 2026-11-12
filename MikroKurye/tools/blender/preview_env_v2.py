#!/usr/bin/env python3
"""MikroKurye — F7.10b: MODEL v2 önizlemeleri + kontak sayfası + masa dioraması.

Kullanım (Blender içinde çalışır):

    /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/preview_env_v2.py

Yaptığı iş:
  * assets/models/v2/env altındaki her GLB'yi temiz sahneye alır
  * 3/4 açıdan, #FFE8C7 arka planda, EEVEE ile 768x768 PNG render eder
    -> docs/art/models_v2/env/<model>.png
  * vertex-renk AO'sunu (COLOR_0) malzemeye bağlayarak derinlik gösterir
  * Pillow ile docs/art/models_v2/env/sheet.png kontak sayfası üretir
  * TOPLU KOMPOZİSYON: robot V1 + tüm masa eşyaları + pencere/raf/perde
    "masa dioraması" -> docs/art/models_v2/env/diorama.png
  * docs/art/models_v2/env/manifest.json (üçgen sayısı, ölçü, kapsama) yazar
"""

import json
import math
import shutil
import struct
import subprocess
import sys
import tempfile
from pathlib import Path

import bpy
from mathutils import Vector

PROJECT_ROOT = Path(__file__).resolve().parents[2]
MODELS_DIR = PROJECT_ROOT / "assets" / "models"
V2_DIR = MODELS_DIR / "v2" / "env"
PREVIEW_DIR = PROJECT_ROOT / "docs" / "art" / "models_v2" / "env"
ROBOT_GLB = MODELS_DIR / "robot_body.glb"

BG_WARM = "#FFE8C7"
VIEW_DIRECTION = (1.0, 1.0, 0.62)
RENDER_SAMPLES = 64
WORLD_STRENGTH = 0.30
KEY_COLOR = "#FFF1D6"
KEY_ENERGY = 2.4
KEY_ANGLE = 25.0
FILL_COLOR = "#DCEFFF"
FILL_ENERGY = 0.45
FILL_ANGLE = 50.0
RIM_COLOR = "#FFE2B8"
RIM_ENERGY = 0.80
RIM_ANGLE = 35.0
INK = "#2B2F3A"
PANEL = "#FFF6EA"
PANEL_BORDER = "#E4C199"

CELL = 768
LABEL_H = 62
GAP = 20
MARGIN = 24
HEADER = 92
FOOTER = 30
COLUMNS = 4

SHEET_ORDER = [
    "prop_keyboard_row_v2", "prop_mug_v2", "prop_pencil_v2", "prop_ruler_v2",
    "prop_book_v2", "prop_monitor_v2", "prop_lamp_v2", "prop_plant_v2",
    "prop_book_stack_v2", "prop_headphones_v2", "prop_notebook_v2", "prop_pen_cup_v2",
    "prop_sticky_notes_v2", "prop_coin_v2", "env_window_v2", "env_curtain_v2",
    "env_shelf_v2", "env_picture_frame_v2", "env_desk_edge_v2", "env_wall_panel_v2",
]

PALETTE_ROLES = [
    ("Ahşap", "#D9A066"), ("Ahşap koyu", "#B07A45"), ("Kırmızı", "#F25F5C"),
    ("Mavi", "#4D9DE0"), ("Sarı", "#F7B801"), ("Yeşil", "#7BC86C"),
    ("Krem", "#FFE8C7"), ("Lacivert", "#20263A"), ("Altın", "#E3B64B"),
    ("Turkuaz (robot)", "#2EE6C5"),
]


def srgb_to_linear(channel: float) -> float:
    return channel / 12.92 if channel <= 0.04045 else ((channel + 0.055) / 1.055) ** 2.4


def hex_to_linear(hex_color: str):
    value = hex_color.lstrip("#")
    return tuple(srgb_to_linear(int(value[i:i + 2], 16) / 255.0) for i in (0, 2, 4))


def clear_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def import_glb(path: Path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    bpy.context.view_layer.update()
    return [obj for obj in bpy.data.objects if obj not in before and obj.type == "MESH"]


def sync_viewport_colors() -> None:
    for material in bpy.data.materials:
        if material.node_tree is None:
            continue
        node = material.node_tree.nodes.get("Principled BSDF")
        if node is None:
            continue
        color = node.inputs["Base Color"].default_value
        material.diffuse_color = (color[0], color[1], color[2], 1.0)
        material.roughness = float(node.inputs["Roughness"].default_value)


def _read_glb_materials(path: Path) -> dict:
    """GLB JSON chunk'ından malzeme bilgilerini (isim -> özellik) çıkarır.

    glTF importer'ın node yeniden kurması emisyonlu malzemelerde base color'ı
    koparabildiği için, renkleri doğrudan dosyadan okuyup temiz malzeme kuruyoruz.
    """
    data = path.read_bytes()
    _magic, _version, length = struct.unpack("<III", data[:12])
    offset = 12
    doc = None
    while offset < length:
        chunk_len, chunk_type = struct.unpack("<II", data[offset:offset + 8])
        chunk = data[offset + 8:offset + 8 + chunk_len]
        if chunk_type == 0x4E4F534A:  # JSON
            doc = json.loads(chunk.decode("utf-8"))
        offset += 8 + chunk_len + ((4 - chunk_len % 4) % 4 if chunk_len % 4 else 0)
    if doc is None:
        return {}
    result = {}
    for material in doc.get("materials", []):
        pbr = material.get("pbrMetallicRoughness", {})
        base = pbr.get("baseColorFactor", [1.0, 1.0, 1.0, 1.0])
        emissive = material.get("emissiveFactor", [0.0, 0.0, 0.0])
        ext = (material.get("extensions") or {}).get("KHR_materials_emissive_strength", {})
        result[material.get("name")] = {
            "base": [float(base[i]) if i < len(base) else 1.0 for i in range(4)],
            "emissive": [float(emissive[i]) if i < len(emissive) else 0.0 for i in range(3)],
            "emissive_strength": float(ext.get("emissiveStrength", 1.0)),
            "metallic": float(pbr.get("metallicFactor", 0.0)),
            "roughness": float(pbr.get("roughnessFactor", 1.0)),
            "alpha": float(base[3]) if len(base) > 3 else 1.0,
            "alpha_mode": material.get("alphaMode", "OPAQUE"),
        }
    return result


def rebuild_materials(path: Path) -> None:
    """İçe aktarılan malzemeleri GLB JSON'daki doğru değerlerle temizden kurar.

    Her malzemenin node ağacını sıfırlayıp tek bir Principled BSDF + (istenirse)
    COLOR_0 AO çarpımı kurar; emisyon/yarı saydamlık/metallic doğru taşınır.
    """
    info = _read_glb_materials(path)
    has_color = any("Color" in getattr(obj.data, "color_attributes", ())
                    for obj in bpy.data.objects if obj.type == "MESH")
    for material in bpy.data.materials:
        entry = info.get(material.name)
        if entry is None:
            continue
        nt = material.node_tree
        if nt is None:
            continue
        nt.nodes.clear()
        bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
        bsdf.location = (0.0, 0.0)
        output = nt.nodes.new("ShaderNodeOutputMaterial")
        output.location = (240.0, 0.0)
        nt.links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])

        base = entry["base"]
        bsdf.inputs["Base Color"].default_value = (base[0], base[1], base[2], 1.0)
        emissive = entry["emissive"]
        bsdf.inputs["Emission Color"].default_value = (emissive[0], emissive[1], emissive[2], 1.0)
        bsdf.inputs["Emission Strength"].default_value = entry["emissive_strength"]
        bsdf.inputs["Metallic"].default_value = entry["metallic"]
        bsdf.inputs["Roughness"].default_value = entry["roughness"]

        if entry["alpha"] < 0.99:
            bsdf.inputs["Alpha"].default_value = entry["alpha"]
            for attr, value in (("blend_method", "BLEND"),
                                ("surface_render_method", "BLENDED"),
                                ("shadow_method", "NONE")):
                try:
                    setattr(material, attr, value)
                except (AttributeError, TypeError):
                    pass
            material.use_backface_culling = False
            material.diffuse_color = (base[0], base[1], base[2], entry["alpha"])
        else:
            material.diffuse_color = (base[0], base[1], base[2], 1.0)
        material.roughness = entry["roughness"]

        # COLOR_0 taban AO'sunu (varsa) base color ile çarp — emisyonsuz/opak yüzeylerde.
        if (has_color and entry["emissive_strength"] <= 0.5 and entry["alpha"] >= 0.99):
            vc = nt.nodes.new("ShaderNodeVertexColor")
            vc.layer_name = "Color"
            vc.location = (-240.0, 0.0)
            mix = nt.nodes.new("ShaderNodeMixRGB")
            mix.blend_type = "MULTIPLY"
            mix.location = (-120.0, 0.0)
            mix.inputs["Fac"].default_value = 1.0
            mix.inputs["Color1"].default_value = (base[0], base[1], base[2], 1.0)
            nt.links.new(vc.outputs["Color"], mix.inputs["Color2"])
            nt.links.new(mix.outputs["Color"], bsdf.inputs["Base Color"])


def world_bounds(objects):
    low = Vector((float("inf"),) * 3)
    high = Vector((float("-inf"),) * 3)
    for obj in objects:
        for corner in obj.bound_box:
            point = obj.matrix_world @ Vector(corner)
            low.x = min(low.x, point.x)
            low.y = min(low.y, point.y)
            low.z = min(low.z, point.z)
            high.x = max(high.x, point.x)
            high.y = max(high.y, point.y)
            high.z = max(high.z, point.z)
    return low, high


def tri_count(objects) -> int:
    return sum(len(poly.vertices) - 2 for obj in objects for poly in obj.data.polygons)


def add_backdrop(center: Vector, direction: Vector, max_dim: float) -> None:
    material = bpy.data.materials.new("Preview_Backdrop")
    material.use_nodes = True
    nodes = material.node_tree.nodes
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    emission = nodes.new("ShaderNodeEmission")
    emission.inputs["Color"].default_value = (*hex_to_linear(BG_WARM), 1.0)
    emission.inputs["Strength"].default_value = 1.0
    material.node_tree.links.new(emission.outputs["Emission"], output.inputs["Surface"])

    distance = max_dim * 2.0 + 2.0
    bpy.ops.mesh.primitive_plane_add(size=max_dim * 40.0 + 20.0,
                                     location=center - direction * distance)
    plane = bpy.context.active_object
    plane.name = "PreviewBackdrop"
    plane.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    plane.data.materials.append(material)


def add_sun(name, center, offset, energy, color, angle):
    data = bpy.data.lights.new(name, "SUN")
    data.energy = energy
    data.color = hex_to_linear(color)
    data.angle = math.radians(angle)
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.location = center + Vector(offset).normalized() * 10.0
    obj.rotation_euler = (center - obj.location).to_track_quat("-Z", "Y").to_euler()


def add_lights(center: Vector) -> None:
    add_sun("KeySun", center, (-1.4, 1.8, 2.4), KEY_ENERGY, KEY_COLOR, KEY_ANGLE)
    add_sun("FillSun", center, (2.4, 1.0, 0.9), FILL_ENERGY, FILL_COLOR, FILL_ANGLE)
    add_sun("RimSun", center, (1.2, -2.2, 1.8), RIM_ENERGY, RIM_COLOR, RIM_ANGLE)


def configure_render() -> None:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.eevee.taa_render_samples = RENDER_SAMPLES
    scene.eevee.use_shadows = True
    scene.render.resolution_x = CELL
    scene.render.resolution_y = CELL
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = False
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
    scene.render.image_settings.color_depth = "8"
    scene.render.image_settings.compression = 15
    scene.view_settings.view_transform = "Standard"
    try:
        scene.view_settings.look = "None"
    except TypeError:
        pass
    scene.view_settings.exposure = 0.0
    scene.view_settings.gamma = 1.0

    world = bpy.data.worlds.new("PreviewWorld")
    scene.world = world
    world.use_nodes = True
    background = world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = (*hex_to_linear(BG_WARM), 1.0)
    background.inputs["Strength"].default_value = WORLD_STRENGTH


def place_camera(center: Vector, max_dim: float, direction: Vector) -> None:
    distance = max_dim * 3.2 + 0.8
    camera_data = bpy.data.cameras.new("PreviewCamera")
    camera = bpy.data.objects.new("PreviewCamera", camera_data)
    bpy.context.collection.objects.link(camera)
    camera.location = center + direction * distance
    camera.rotation_euler = (center - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = max_dim * 1.32
    camera_data.clip_start = max(0.001, max_dim * 0.001)
    camera_data.clip_end = (distance + max_dim * 2.0 + 2.0) * 2.0
    bpy.context.scene.camera = camera


def render_to(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.context.scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def render_model(path: Path, out_png: Path) -> dict:
    clear_scene()
    meshes = import_glb(path)
    if not meshes:
        raise RuntimeError("%s içinde mesh yok" % path)
    sync_viewport_colors()
    rebuild_materials(path)
    low, high = world_bounds(meshes)
    size = high - low
    max_dim = max(size.x, size.y, size.z, 0.01)

    configure_render()
    direction = Vector(VIEW_DIRECTION).normalized()
    center = (low + high) / 2.0
    add_backdrop(center, direction, max_dim)
    add_lights(center)
    place_camera(center, max_dim, direction)
    render_to(out_png)

    return {
        "name": path.stem,
        "tris": tri_count(meshes),
        "dims": [round(size.x, 3), round(size.y, 3), round(size.z, 3)],
        "preview": out_png.name,
    }


# ---------------------------------------------------------------------------
# masa dioraması
# ---------------------------------------------------------------------------
def make_desk() -> None:
    mat = bpy.data.materials.new("Desk_Wood")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*hex_to_linear("#D9A066"), 1.0)
    bsdf.inputs["Roughness"].default_value = 0.5
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 0.0, -0.1))
    desk = bpy.context.active_object
    desk.name = "Desk"
    desk.scale = (16.0, 10.0, 0.2)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    desk.data.materials.append(mat)


def place(name_prefix, x, y, z=0.0, rz=0.0):
    obj = next((o for o in bpy.data.objects
                if o.type == "MESH" and o.name.startswith(name_prefix)), None)
    if obj is None:
        raise RuntimeError("diorama: %s bulunamadı" % name_prefix)
    obj.location = (x, y, z)
    obj.rotation_euler = (0.0, 0.0, math.radians(rz))
    return obj


def build_diorama(out_png: Path) -> None:
    clear_scene()
    configure_render()
    scene = bpy.context.scene
    scene.render.resolution_x = 1600
    scene.render.resolution_y = 1200

    make_desk()

    # robot (referans ölçek) + masa eşyaları + çevre
    place_robot = None
    imported = {}
    import_glb(ROBOT_GLB)
    for o in bpy.data.objects:
        if o.type == "MESH" and "Robot" in o.name:
            imported["robot"] = o
    for glb in sorted(V2_DIR.glob("*.glb")):
        import_glb(glb)
    # isim eşlemesi
    for o in bpy.data.objects:
        if o.type == "MESH" and o.name not in imported:
            imported[o.name] = o

    def put(name_prefix, x, y, z=0.0, rz=0.0):
        obj = next((o for n, o in imported.items() if n.startswith(name_prefix)), None)
        if obj is None:
            raise RuntimeError("diorama: %s bulunamadı" % name_prefix)
        obj.location = (x, y, z)
        obj.rotation_euler = (0.0, 0.0, math.radians(rz))

    # arka duvar + dekor (y negatif = arka; masa 16×10, kenarlar x=±8 / y=±5)
    put("WallPanel", 0.0, -5.2, 0.0)
    put("Window", -6.0, -5.2, 0.0)
    put("Curtain", 3.0, -5.2, 0.0)
    put("PictureFrame", 6.8, -5.2, 1.6)
    put("Shelf", -2.2, -5.2, 2.6)

    # masa eşyaları (y pozitif = ön, kameraya doğru)
    put("RobotBody", 0.0, 3.4, 0.0)
    put("KeyboardRow", -4.0, 0.0, 0.0)
    put("Mug", -5.6, 1.2, 0.0)
    put("Pencil", 0.0, -2.0, 0.0, 90.0)
    put("Ruler", 0.0, 4.0, 0.0, 90.0)
    put("Book", 3.6, 0.2, 0.0)
    put("Monitor", 5.6, -1.0, 0.0)
    put("Lamp", 2.0, -3.2, 0.0)
    put("Plant", -6.2, -2.0, 0.0)
    put("BookStack", -2.6, -1.2, 0.0)
    put("Headphones", -5.0, 3.0, 0.0)
    put("Notebook", 1.6, 1.2, 0.0)
    put("PenCup", -6.2, 2.6, 0.0)
    put("StickyNotes", 4.0, 3.2, 0.0)
    put("Coin", 6.2, 3.0, 0.0)

    sync_viewport_colors()
    rebuild_materials(ROBOT_GLB)
    for glb in sorted(V2_DIR.glob("*.glb")):
        rebuild_materials(glb)

    # kamera: 3/4 perspektif
    camera_data = bpy.data.cameras.new("DioCamera")
    camera = bpy.data.objects.new("DioCamera", camera_data)
    bpy.context.collection.objects.link(camera)
    camera.location = (14.0, 18.0, 13.0)
    camera.rotation_euler = (Vector((0.0, 0.0, 1.5)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera_data.type = "PERSP"
    camera_data.lens = 35.0
    camera_data.clip_end = 200.0
    scene.camera = camera

    # diorama ışıkları
    add_lights(Vector((0.0, 0.0, 1.0)))

    render_to(out_png)


# ---------------------------------------------------------------------------
# kontak sayfası — sistem python3 + Pillow
# ---------------------------------------------------------------------------
COMPOSE_SOURCE = r'''
import json
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

manifest_path = Path(sys.argv[1]); out_path = Path(sys.argv[2])
data = json.loads(manifest_path.read_text(encoding="utf-8"))
entries = data["images"]; palette = data["palette"]
CELL = data["cell"]; LABEL_H = data["label_h"]; GAP = data["gap"]
MARGIN = data["margin"]; HEADER = data["header"]; FOOTER = data["footer"]
COLUMNS = data["columns"]; BG = data["bg"]; INK = data["ink"]
PANEL = data["panel"]; BORDER = data["border"]; PREVIEW_DIR = Path(data["preview_dir"])

FONT_B = ["/System/Library/Fonts/Supplemental/Arial Bold.ttf",
          "/System/Library/Fonts/Helvetica.ttc"]
FONT_R = ["/System/Library/Fonts/Supplemental/Arial.ttf",
          "/System/Library/Fonts/Helvetica.ttc"]

def load(cands, size):
    for c in cands:
        if Path(c).is_file():
            try: return ImageFont.truetype(c, size)
            except OSError: continue
    return ImageFont.load_default()

font_title = load(FONT_B, 34); font_sub = load(FONT_R, 19)
font_name = load(FONT_B, 20); font_dims = load(FONT_R, 16)
font_pal = load(FONT_B, 20); font_pal_name = load(FONT_R, 14)
font_pal_hex = load(FONT_R, 13); font_footer = load(FONT_R, 15)

cells = list(entries) + [{"palette": True}]
rows = (len(cells) + COLUMNS - 1) // COLUMNS
sheet_w = MARGIN * 2 + COLUMNS * CELL + (COLUMNS - 1) * GAP
sheet_h = MARGIN * 2 + HEADER + rows * (CELL + LABEL_H) + (rows - 1) * GAP + FOOTER
sheet = Image.new("RGB", (sheet_w, sheet_h), BG)
draw = ImageDraw.Draw(sheet)
draw.text((MARGIN, MARGIN + 6), "Micro Courier — MODEL v2 · masa eşyaları + oda/çevre kiti",
          font=font_title, fill=INK)
draw.text((MARGIN, MARGIN + 50), "Blender 5.2 · EEVEE · 768×768 · ölçüler metre (W×L×H)",
          font=font_sub, fill="#6B5B49")
subtitle = "%d model · masa eşyası ≤6000 tris · çevre ≤4000 tris" % len(entries)
draw.text((sheet_w - MARGIN, MARGIN + 22), subtitle, font=font_sub, fill="#6B5B49", anchor="ra")

for index, entry in enumerate(cells):
    col = index % COLUMNS; row = index // COLUMNS
    x = MARGIN + col * (CELL + GAP); y = MARGIN + HEADER + row * (CELL + LABEL_H + GAP)
    draw.rounded_rectangle((x - 6, y - 6, x + CELL + 6, y + CELL + LABEL_H + 6),
                           radius=18, fill=PANEL, outline=BORDER, width=2)
    if entry.get("palette"):
        draw.text((x + 18, y + 14), "PALET · PROJECT_SPEC §13", font=font_pal, fill=INK)
        sw = 34; col_w = (CELL - 36) // 2
        for i, (role, hc) in enumerate(palette):
            px = x + 18 + (i % 2) * col_w; py = y + 52 + (i // 2) * 42
            draw.rounded_rectangle((px, py, px + sw, py + sw), radius=8, fill=hc,
                                   outline=BORDER, width=1)
            draw.text((px + sw + 9, py), role, font=font_pal_name, fill=INK)
            draw.text((px + sw + 9, py + 18), hc, font=font_pal_hex, fill="#6B5B49")
    else:
        img = Image.open(PREVIEW_DIR / entry["preview"]).convert("RGB")
        img = img.resize((CELL, CELL), Image.Resampling.LANCZOS)
        sheet.paste(img, (x, y))
        draw.text((x + CELL // 2, y + CELL + 8), entry["name"], font=font_name,
                  fill=INK, anchor="ma")
        dims = " × ".join("%.2f" % v for v in entry["dims"])
        draw.text((x + CELL // 2, y + CELL + 34), "%d tris · %s m" % (entry["tris"], dims),
                  font=font_dims, fill="#6B5B49", anchor="ma")

draw.text((MARGIN, sheet_h - MARGIN - FOOTER + 4),
          "MikroKurye · F7.10b · robot ~0.8 m, masa eşyaları dev ölçek · her hücre kendi boyutuna göre çerçeveli · "
          "kaynak: tools/blender/make_env_v2.py", font=font_footer, fill="#6B5B49")
out_path.parent.mkdir(parents=True, exist_ok=True)
sheet.save(out_path, "PNG", optimize=True)
print("SHEET %s %dx%d" % (out_path, sheet_w, sheet_h))
'''


def compose_sheet(entries, out_png: Path) -> None:
    python = shutil.which("python3") or "/usr/bin/python3"
    manifest = {
        "cell": CELL, "label_h": LABEL_H, "gap": GAP, "margin": MARGIN,
        "header": HEADER, "footer": FOOTER, "columns": COLUMNS,
        "bg": BG_WARM, "ink": INK, "panel": PANEL, "border": PANEL_BORDER,
        "preview_dir": str(PREVIEW_DIR), "palette": PALETTE_ROLES, "images": entries,
    }
    with tempfile.TemporaryDirectory(prefix="mk_v2_") as tmp:
        manifest_path = Path(tmp) / "manifest.json"
        manifest_path.write_text(json.dumps(manifest, ensure_ascii=False), encoding="utf-8")
        source_path = Path(tmp) / "compose.py"
        source_path.write_text(COMPOSE_SOURCE, encoding="utf-8")
        result = subprocess.run([python, str(source_path), str(manifest_path), str(out_png)],
                                capture_output=True, text=True)
        if result.returncode != 0:
            raise RuntimeError("kontak sayfası üretilemedi:\n%s\n%s"
                               % (result.stdout, result.stderr))
        print(result.stdout.strip())


def main() -> int:
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    paths = sorted(V2_DIR.glob("*.glb"))
    if not paths:
        raise RuntimeError("assets/models/v2/env altında .glb yok")
    order = {name: index for index, name in enumerate(SHEET_ORDER)}
    paths.sort(key=lambda path: (order.get(path.stem, len(order)), path.as_posix()))

    entries = []
    for path in paths:
        out_png = PREVIEW_DIR / (path.stem + ".png")
        entry = render_model(path, out_png)
        entries.append(entry)
        print("PREVIEW %-22s %5d tris  %.2f/%.2f/%.2f m -> %s"
              % (entry["name"], entry["tris"], *entry["dims"], out_png.name))

    compose_sheet(entries, PREVIEW_DIR / "sheet.png")

    diorama = PREVIEW_DIR / "diorama.png"
    build_diorama(diorama)
    print("DIORAMA -> %s" % diorama)

    manifest = PREVIEW_DIR / "manifest.json"
    manifest.write_text(json.dumps({"images": entries, "diorama": diorama.name},
                                   ensure_ascii=False, indent=2), encoding="utf-8")
    print("PREVIEW_DIR %s" % PREVIEW_DIR)
    return 0


if __name__ == "__main__":
    sys.exit(main())
