#!/usr/bin/env python3
"""MikroKurye — V2 model önizlemeleri + kontak sayfası.

Kullanım (Blender içinde çalışır):

    /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/preview_v2.py

Yaptığı iş:
  * assets/models/v2 altındaki her GLB'yi temiz bir sahneye alır
  * 3/4 açıdan, #FFE8C7 arka planda, EEVEE ile 768x768 PNG render eder
  * robot için ek olarak ön ve yan açılar da render edilir
  * docs/art/models_v2/<model>.png dosyalarını yazar
  * Pillow (sistem python3) ile docs/art/models_v2/sheet.png kontak sayfasını üretir
"""

import json
import math
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import bpy
from mathutils import Vector

# ---------------------------------------------------------------------------
# yol + sabitler
# ---------------------------------------------------------------------------
PROJECT_ROOT = Path(__file__).resolve().parents[2]
MODELS_DIR = PROJECT_ROOT / "assets" / "models" / "v2"
PREVIEW_DIR = PROJECT_ROOT / "docs" / "art" / "models_v2"

BG_WARM = "#FFE8C7"
VIEW_3Q = (1.0, 1.0, 0.62)
VIEW_FRONT = (0.0, 1.0, 0.14)
VIEW_SIDE = (1.0, 0.0, 0.14)
RENDER_SIZE = 768
RENDER_SAMPLES = 32
WORLD_STRENGTH = 0.28
KEY_COLOR = "#FFF1D6"
KEY_ENERGY = 2.6
KEY_ANGLE = 25.0
FILL_COLOR = "#DCEFFF"
FILL_ENERGY = 0.50
FILL_ANGLE = 50.0
RIM_COLOR = "#FFE2B8"
RIM_ENERGY = 0.90
RIM_ANGLE = 35.0
INK = "#2B2F3A"
PANEL = "#FFF6EA"
PANEL_BORDER = "#E4C199"

# kontak sayfası düzeni (hücre 512'ye küçültülür)
CELL = 512
LABEL_H = 58
GAP = 18
MARGIN = 20
HEADER = 86
FOOTER = 26
COLUMNS = 3

SHEET_ORDER = [
    "robot_body_v2",
    "robot_wheel_v2",
    "cargo_basket_v2",
    "cargo_pencil_battery_v2",
    "cargo_sd_card_v2",
    "cargo_espresso_capsule_v2",
]

# ek açılar: yalnız robot için (ön + yan); 3/4 her modelde var
EXTRA_VIEWS = {
    "robot_body_v2": [
        ("front", VIEW_FRONT),
        ("side", VIEW_SIDE),
    ],
}

PALETTE_ROLES = [
    ("Robot ana", "#2EE6C5"),
    ("Robot vurgu", "#FFC83D"),
    ("Lastik", "#2B2F3A"),
    ("Jant", "#B8C0CC"),
    ("Visor", "#20283A"),
    ("Göz emisyon", "#B7F3FF"),
    ("Sepet", "#EF8B2C"),
    ("Pil yeşili", "#7BC86C"),
    ("SD mavi", "#4D9DE0"),
    ("Kapsül kırmızı", "#F25F5C"),
]


# ---------------------------------------------------------------------------
# yardımcılar
# ---------------------------------------------------------------------------
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
        material.metallic = float(node.inputs["Metallic"].default_value)


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


def add_sun(name: str, center: Vector, offset, energy: float, color: str,
            angle: float) -> None:
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
    scene.render.resolution_x = RENDER_SIZE
    scene.render.resolution_y = RENDER_SIZE
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


def render_view(path: Path, out_png: Path, direction_tuple) -> dict:
    clear_scene()
    meshes = import_glb(path)
    if not meshes:
        raise RuntimeError("%s içinde mesh yok" % path)

    sync_viewport_colors()
    low, high = world_bounds(meshes)
    size = high - low
    max_dim = max(size.x, size.y, size.z, 0.01)

    configure_render()
    direction = Vector(direction_tuple).normalized()
    center = (low + high) / 2.0
    add_backdrop(center, direction, max_dim)
    add_lights(center)
    place_camera(center, max_dim, direction)

    out_png.parent.mkdir(parents=True, exist_ok=True)
    bpy.context.scene.render.filepath = str(out_png)
    bpy.ops.render.render(write_still=True)

    return {
        "name": path.stem,
        "tris": tri_count(meshes),
        "dims": [round(size.x, 3), round(size.y, 3), round(size.z, 3)],
        "preview": out_png.name,
    }


# ---------------------------------------------------------------------------
# kontak sayfası — sistem python3 + Pillow
# ---------------------------------------------------------------------------
COMPOSE_SOURCE = r'''
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

manifest_path = Path(sys.argv[1])
out_path = Path(sys.argv[2])
data = json.loads(manifest_path.read_text(encoding="utf-8"))
entries = data["images"]
palette = data["palette"]

CELL = data["cell"]; LABEL_H = data["label_h"]; GAP = data["gap"]
MARGIN = data["margin"]; HEADER = data["header"]; FOOTER = data["footer"]
COLUMNS = data["columns"]; BG = data["bg"]; INK = data["ink"]
PANEL = data["panel"]; BORDER = data["border"]
PREVIEW_DIR = Path(data["preview_dir"])

FONT_BOLD = ["/System/Library/Fonts/Supplemental/Arial Bold.ttf",
             "/System/Library/Fonts/Helvetica.ttc"]
FONT_REG = ["/System/Library/Fonts/Supplemental/Arial.ttf",
            "/System/Library/Fonts/Helvetica.ttc"]

def load_font(candidates, size):
    for candidate in candidates:
        if Path(candidate).is_file():
            try:
                return ImageFont.truetype(candidate, size)
            except OSError:
                continue
    return ImageFont.load_default()

font_title = load_font(FONT_BOLD, 32)
font_sub = load_font(FONT_REG, 18)
font_name = load_font(FONT_BOLD, 21)
font_dims = load_font(FONT_REG, 16)
font_pal = load_font(FONT_BOLD, 20)
font_pal_name = load_font(FONT_REG, 14)
font_pal_hex = load_font(FONT_REG, 13)
font_footer = load_font(FONT_REG, 14)

cells = list(entries) + [{"palette": True}]
rows = (len(cells) + COLUMNS - 1) // COLUMNS
sheet_w = MARGIN * 2 + COLUMNS * CELL + (COLUMNS - 1) * GAP
sheet_h = MARGIN * 2 + HEADER + rows * (CELL + LABEL_H) + (rows - 1) * GAP + FOOTER

sheet = Image.new("RGB", (sheet_w, sheet_h), BG)
draw = ImageDraw.Draw(sheet)

draw.text((MARGIN, MARGIN + 4), "Micro Courier — V2 model seti",
          font=font_title, fill=INK)
draw.text((MARGIN, MARGIN + 46),
          "Blender 5.2 · EEVEE · 768×768 · ölçüler metre (W×L×H)",
          font=font_sub, fill="#6B5B49")
subtitle = "%d model · hero robot ≤12000 · pürüzsüz gölgeleme" % len(entries)
draw.text((sheet_w - MARGIN, MARGIN + 20), subtitle, font=font_sub,
          fill="#6B5B49", anchor="ra")

for index, entry in enumerate(cells):
    col = index % COLUMNS
    row = index // COLUMNS
    x = MARGIN + col * (CELL + GAP)
    y = MARGIN + HEADER + row * (CELL + LABEL_H + GAP)
    draw.rounded_rectangle((x - 6, y - 6, x + CELL + 6, y + CELL + LABEL_H + 6),
                           radius=18, fill=PANEL, outline=BORDER, width=2)
    if entry.get("palette"):
        draw.text((x + 16, y + 12), "PALET · PROJECT_SPEC §13",
                  font=font_pal, fill=INK)
        sw = 34
        col_w = (CELL - 32) // 2
        for i, (role, hex_color) in enumerate(palette):
            px = x + 16 + (i % 2) * col_w
            py = y + 48 + (i // 2) * 40
            draw.rounded_rectangle((px, py, px + sw, py + sw), radius=7,
                                   fill=hex_color, outline=BORDER, width=1)
            draw.text((px + sw + 9, py + 1), role, font=font_pal_name, fill=INK)
            draw.text((px + sw + 9, py + 18), hex_color, font=font_pal_hex,
                      fill="#6B5B49")
    else:
        preview = Image.open(PREVIEW_DIR / entry["preview"]).convert("RGB")
        preview = preview.resize((CELL, CELL), Image.Resampling.LANCZOS)
        sheet.paste(preview, (x, y))
        draw.text((x + CELL // 2, y + CELL + 8), entry["name"],
                  font=font_name, fill=INK, anchor="ma")
        dims = " × ".join("%.2f" % value for value in entry["dims"])
        draw.text((x + CELL // 2, y + CELL + 34),
                  "%d tris · %s m" % (entry["tris"], dims),
                  font=font_dims, fill="#6B5B49", anchor="ma")

draw.text((MARGIN, sheet_h - MARGIN - FOOTER + 4),
          "MikroKurye · V2 görsel aşama · kaynak: tools/blender/make_models_v2.py · "
          "vertex-renk gradyanı + isimli malzeme slotları",
          font=font_footer, fill="#6B5B49")

out_path.parent.mkdir(parents=True, exist_ok=True)
sheet.save(out_path, "PNG", optimize=True)
print("SHEET %s %dx%d" % (out_path, sheet_w, sheet_h))
'''


def compose_sheet(entries, out_png: Path) -> None:
    python = shutil.which("python3") or "/usr/bin/python3"
    manifest = {
        "cell": CELL, "label_h": LABEL_H, "gap": GAP, "margin": MARGIN,
        "header": HEADER, "footer": FOOTER, "columns": COLUMNS, "bg": BG_WARM,
        "ink": INK, "panel": PANEL, "border": PANEL_BORDER,
        "preview_dir": str(PREVIEW_DIR), "palette": PALETTE_ROLES,
        "images": entries,
    }
    with tempfile.TemporaryDirectory(prefix="mk_preview_v2_") as tmp:
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


# ---------------------------------------------------------------------------
# ana akış
# ---------------------------------------------------------------------------
def main() -> int:
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    paths = sorted(MODELS_DIR.rglob("*.glb"))
    if not paths:
        raise RuntimeError("assets/models/v2 altında .glb yok")

    order = {name: index for index, name in enumerate(SHEET_ORDER)}
    paths.sort(key=lambda path: (order.get(path.stem, len(order)), path.as_posix()))

    entries = []
    for path in paths:
        # ana 3/4 görüntü
        main_png = PREVIEW_DIR / (path.stem + ".png")
        entry = render_view(path, main_png, VIEW_3Q)
        entries.append(entry)
        print("PREVIEW %-28s %5d tris  %.2f/%.2f/%.2f m -> %s"
              % (entry["name"], entry["tris"], *entry["dims"], main_png.name))
        # ek açılar (robot: ön + yan)
        for view_name, direction in EXTRA_VIEWS.get(path.stem, []):
            extra_png = PREVIEW_DIR / ("%s_%s.png" % (path.stem, view_name))
            render_view(path, extra_png, direction)
            print("  +%-6s -> %s" % (view_name, extra_png.name))

    compose_sheet(entries, PREVIEW_DIR / "sheet.png")
    print("PREVIEW_DIR %s" % PREVIEW_DIR)
    return 0


if __name__ == "__main__":
    sys.exit(main())
