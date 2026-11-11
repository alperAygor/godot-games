#!/usr/bin/env python3
"""MikroKurye — V1 model önizlemeleri + kontak sayfası.

Kullanım (Blender içinde çalışır):

    /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/preview.py

Yaptığı iş:
  * assets/models altındaki her GLB'yi temiz bir sahneye alır
  * 3/4 açıdan, #FFE8C7 arka planda, EEVEE ile 512x512 PNG render eder
  * build/previews/<model>.png dosyalarını yazar
  * Pillow (sistem python3) ile build/previews/sheet.png kontak sayfasını üretir

Kontak sayfasında her hücrede model adı, üçgen sayısı ve W x L x H (m) ölçüsü
vardır; son hücre palet lejandıdır. Render kamerasi her modeli kendi ölçeğine
göre çerçeveler, etiketler gerçek ölçüyü verir.
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
MODELS_DIR = PROJECT_ROOT / "assets" / "models"
PREVIEW_DIR = PROJECT_ROOT / "build" / "previews"

BG_WARM = "#FFE8C7"
VIEW_DIRECTION = (1.0, 1.0, 0.62)
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

CELL = 512
LABEL_H = 58
GAP = 18
MARGIN = 20
HEADER = 86
FOOTER = 26
COLUMNS = 4

# kontak sayfası sırası: robot -> kargo -> masa eşyaları
SHEET_ORDER = [
    "robot_body",
    "robot_wheel",
    "cargo_basket",
    "cargo_pencil_battery",
    "cargo_sd_card",
    "cargo_espresso_capsule",
    "prop_keyboard_row",
    "prop_mug",
    "prop_pencil",
    "prop_ruler",
    "prop_book",
]

PALETTE_ROLES = [
    ("Robot ana", "#2EE6C5"),
    ("Robot vurgu", "#FFC83D"),
    ("Lastik", "#2B2F3A"),
    ("Jant", "#B8C0CC"),
    ("Masa eşyası kırmızı", "#F25F5C"),
    ("Masa eşyası mavi", "#4D9DE0"),
    ("Masa eşyası sarı", "#F7B801"),
    ("Masa eşyası yeşil", "#7BC86C"),
    ("Arka plan", "#FFE8C7"),
    ("Tehlike", "#FF4D4D"),
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
    """Viewport yedek renkleri: Principled Base Color ile eşitle."""
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
    """Kamera arkasına emisyon düzlemi: arka plan tam #FFE8C7 kalır."""
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
    bpy.ops.mesh.primitive_plane_add(
        size=max_dim * 40.0 + 20.0,
        location=center - direction * distance,
    )
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


def render_model(path: Path, out_png: Path) -> dict:
    clear_scene()
    meshes = import_glb(path)
    if not meshes:
        raise RuntimeError("%s içinde mesh yok" % path)

    sync_viewport_colors()
    low, high = world_bounds(meshes)
    size = high - low
    max_dim = max(size.x, size.y, size.z, 0.01)

    configure_render()
    direction = Vector(VIEW_DIRECTION).normalized()
    center = (low + high) / 2.0
    add_backdrop(center, direction, max_dim)
    add_lights(center)
    place_camera(center, max_dim, direction)

    out_png.parent.mkdir(parents=True, exist_ok=True)
    bpy.context.scene.render.filepath = str(out_png)
    bpy.ops.render.render(write_still=True)

    return {
        "file": path.relative_to(MODELS_DIR).as_posix(),
        "name": path.stem,
        "tris": tri_count(meshes),
        # Blender X = genişlik, Y = uzunluk, Z = yükseklik
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

CELL = data["cell"]
LABEL_H = data["label_h"]
GAP = data["gap"]
MARGIN = data["margin"]
HEADER = data["header"]
FOOTER = data["footer"]
COLUMNS = data["columns"]
BG = data["bg"]
INK = data["ink"]
PANEL = data["panel"]
BORDER = data["border"]
PREVIEW_DIR = Path(data["preview_dir"])

FONT_CANDIDATES = [
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    "/System/Library/Fonts/Helvetica.ttc",
]
FONT_REGULAR = [
    "/System/Library/Fonts/Supplemental/Arial.ttf",
    "/System/Library/Fonts/Helvetica.ttc",
]


def load_font(candidates, size):
    for candidate in candidates:
        if Path(candidate).is_file():
            try:
                return ImageFont.truetype(candidate, size)
            except OSError:
                continue
    return ImageFont.load_default()


font_title = load_font(FONT_CANDIDATES, 34)
font_sub = load_font(FONT_REGULAR, 19)
font_name = load_font(FONT_CANDIDATES, 22)
font_dims = load_font(FONT_REGULAR, 17)
font_pal = load_font(FONT_CANDIDATES, 20)
font_pal_name = load_font(FONT_REGULAR, 15)
font_pal_hex = load_font(FONT_REGULAR, 14)
font_footer = load_font(FONT_REGULAR, 15)

cells = list(entries) + [{"palette": True}]
rows = (len(cells) + COLUMNS - 1) // COLUMNS
sheet_w = MARGIN * 2 + COLUMNS * CELL + (COLUMNS - 1) * GAP
sheet_h = MARGIN * 2 + HEADER + rows * (CELL + LABEL_H) + (rows - 1) * GAP + FOOTER

sheet = Image.new("RGB", (sheet_w, sheet_h), BG)
draw = ImageDraw.Draw(sheet)

# başlık
draw.text((MARGIN, MARGIN + 6), "Micro Courier — V1 model seti",
          font=font_title, fill=INK)
draw.text((MARGIN, MARGIN + 50),
          "Blender 5.2 · EEVEE · 512×512 · ölçüler metre (W×L×H)",
          font=font_sub, fill="#6B5B49")
subtitle = "%d model · her biri ≤3000 üçgen" % len(entries)
draw.text((sheet_w - MARGIN, MARGIN + 22), subtitle, font=font_sub,
          fill="#6B5B49", anchor="ra")

for index, entry in enumerate(cells):
    col = index % COLUMNS
    row = index // COLUMNS
    x = MARGIN + col * (CELL + GAP)
    y = MARGIN + HEADER + row * (CELL + LABEL_H + GAP)
    draw.rounded_rectangle((x - 6, y - 6, x + CELL + 6, y + CELL + LABEL_H + 6),
                           radius=18, fill=PANEL, outline=BORDER, width=2)
    if entry.get("palette"):
        draw.text((x + 18, y + 14), "PALET · PROJECT_SPEC §13",
                  font=font_pal, fill=INK)
        sw = 38
        col_w = (CELL - 36) // 2
        for i, (role, hex_color) in enumerate(palette):
            px = x + 18 + (i % 2) * col_w
            py = y + 54 + (i // 2) * 46
            draw.rounded_rectangle((px, py, px + sw, py + sw), radius=8,
                                   fill=hex_color, outline=BORDER, width=1)
            draw.text((px + sw + 10, py + 1), role, font=font_pal_name, fill=INK)
            draw.text((px + sw + 10, py + 20), hex_color, font=font_pal_hex,
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
          "MikroKurye · V1 görsel aşama · robot ~0.8 m, masa eşyaları dev ölçek · "
          "her hücre kendi boyutuna göre çerçeveli · kaynak: tools/blender/make_models.py",
          font=font_footer, fill="#6B5B49")

out_path.parent.mkdir(parents=True, exist_ok=True)
sheet.save(out_path, "PNG", optimize=True)
print("SHEET %s %dx%d" % (out_path, sheet_w, sheet_h))
'''


def compose_sheet(entries, out_png: Path) -> None:
    python = shutil.which("python3") or "/usr/bin/python3"
    manifest = {
        "cell": CELL,
        "label_h": LABEL_H,
        "gap": GAP,
        "margin": MARGIN,
        "header": HEADER,
        "footer": FOOTER,
        "columns": COLUMNS,
        "bg": BG_WARM,
        "ink": INK,
        "panel": PANEL,
        "border": PANEL_BORDER,
        "preview_dir": str(PREVIEW_DIR),
        "palette": PALETTE_ROLES,
        "images": entries,
    }
    with tempfile.TemporaryDirectory(prefix="mk_preview_") as tmp:
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
        raise RuntimeError("assets/models altında .glb yok")

    order = {name: index for index, name in enumerate(SHEET_ORDER)}
    paths.sort(key=lambda path: (order.get(path.stem, len(order)), path.as_posix()))

    entries = []
    for path in paths:
        out_png = PREVIEW_DIR / (path.stem + ".png")
        entry = render_model(path, out_png)
        entries.append(entry)
        print("PREVIEW %-28s %5d tris  %.2f/%.2f/%.2f m -> %s"
              % (entry["name"], entry["tris"], *entry["dims"], out_png.name))

    compose_sheet(entries, PREVIEW_DIR / "sheet.png")
    print("PREVIEW_DIR %s" % PREVIEW_DIR)
    return 0


if __name__ == "__main__":
    sys.exit(main())
