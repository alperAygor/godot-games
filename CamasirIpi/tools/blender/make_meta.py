#!/usr/bin/env python3
"""Çamaşır İpi — meta katmanı: çamaşırhane tadilat katmanları (Blender, headless, Cycles).

    /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/make_meta.py
    ... -- machine1 lamp            # yalnız adı verilen yuvalar (tüm durumları)
    ... -- machine1_old floor_2     # yalnız adı verilen katmanlar
    ... -- --preview                # çeyrek çözünürlük, az örnek (hızlı deneme)
    ... -- --compose=old|0|1|2|half # tüm odayı tek karede render et (yerleşim kontrolü)

Çıktılar: assets/sprites/meta/room_<yuva>_<durum>.png (RGBA, şeffaf, KIRPILMIŞ) +
assets/sprites/meta/laundromat_layers.json (her katmanın 1080x1920 tuvaldeki dikdörtgeni).

NEDEN katman katman render: oyunda her tadilat görevi tek bir katmanı "eski"den "yeni N"e
çevirir; tüm katmanlar AYNI kamera ve ışıkla render edildiği için üst üste konunca kusursuz
hizalanır. NEDEN kırpma: 1080x1920 tam kare ~8 MB doku demek; kırpılmış katman çok küçüktür.
NEDEN Cycles + gölge yakalayıcı: duvar ve zemin her eşya render'ında görünmez "gölge
yakalayıcı" olarak durur; eşyanın duvara/zemine düşen yumuşak gölgesi kendi katmanına
yarı saydam siyah olarak yazılır — oyunda eşya yerine konunca gölgesiyle birlikte oturur.

Kural 1 (kullanıcı): low-poly YOK. Her şey yuvarlatılmış (bevel), pürüzsüz gölgeli,
tombul oyuncak-diorama dili; bahçe katmanlarıyla aynı pastel palet.
Kamera: yatay bakan perspektif + dikey kaydırma (shift) -> dikeyler dik kalır (mimari,
"vitrin dioraması" hissi), zemin yine görünür.
"""

import json
import math
import os
import random
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_DIR = os.path.join(ROOT, "assets", "sprites", "meta")
MANIFEST = os.path.join(OUT_DIR, "laundromat_layers.json")
PREVIEW_DIR = os.path.join(ROOT, "build", "meta_preview")

ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
PREVIEW = "--preview" in ARGV
COMPOSE = next((a.split("=", 1)[1] for a in ARGV if a.startswith("--compose=")), "")
WANTED = {a for a in ARGV if not a.startswith("--")}
_OUT = next((a.split("=", 1)[1] for a in ARGV if a.startswith("--out=")), "")
if _OUT:  # deneme çıktısı: gerçek varlıklara dokunmadan başka klasöre yaz
    OUT_DIR = os.path.abspath(_OUT)
    MANIFEST = os.path.join(OUT_DIR, "laundromat_layers.json")
_RES = next((a.split("=", 1)[1] for a in ARGV if a.startswith("--res=")), "")

CANVAS_W = 1080
CANVAS_H = 1920
SAMPLES = 48 if (PREVIEW and _RES) else (24 if PREVIEW else 128)
# Kamera: duvardan D uzakta, h yükseklikte, yatay bakış; kadraj üstü duvarda z=TOP_Z.
CAM_D = 14.0
CAM_H = 4.0
TOP_Z = 4.4
FLOOR_LINE = 0.56  # duvar dibi (z=0, y=0) tuvalin bu oranında
CROP_ALPHA = 3     # bu alfadan (0..255) küçük pikseller kırpmada boş sayılır
CROP_PAD = 2
# Gölge yakalayıcı, eşyanın ortam ışığını kesmesiyle TÜM kareye çok hafif (%1-5) bir karartma
# yazar; bu "peçe" katmanı tam kare yapar (kırpma işe yaramaz) ve üst üste binince odayı
# kirletir. Siyah (yakalayıcı) piksellerde alfa bu eşik kadar düşürülüp yeniden ölçeklenir.
VEIL_ALPHA = 14 / 255.0
CATCHER_RGB = 0.06
# Gürültü: bir satır/sütun en az bu kadar dolu piksel içermiyorsa kırpma sınırına sayılmaz.
CROP_MIN_PIXELS = 3
BLOCK = 4          # VRAM sıkıştırma blok boyu: katman boyutları bunun katı olur

# Sahne sırası = oyundaki çizim sırası (arkadan öne). Her yuva: eski durum + 3 varyant.
SLOTS = ["floor", "wall", "window", "door", "sign", "shelf", "lamp",
         "machine1", "machine2", "plant", "rug", "counter"]
# Eski hâli olmayan yuvalar (başlangıçta boş).
NO_OLD = {"sign"}
# Gölge düşürmeyen yuvalar (bkz. render_layer).
NO_SHADOW = {"lamp"}


# ---------------------------------------------------------------------------- renk / sahne

def lin(hex_color):
    """'#RRGGBB' (sRGB) -> lineer RGB demeti."""
    h = hex_color.lstrip("#")
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return tuple(out)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _MATS.clear()
    _MESHES.clear()
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    try:
        prefs = bpy.context.preferences.addons["cycles"].preferences
        prefs.compute_device_type = "METAL"
        prefs.get_devices()
        for device in prefs.devices:
            device.use = True
        scene.cycles.device = "GPU"
    except Exception:  # GPU yoksa CPU ile de çalışır (yalnız yavaş).
        scene.cycles.device = "CPU"
    scene.cycles.samples = SAMPLES
    scene.cycles.use_denoising = True
    scene.cycles.max_bounces = 6
    scene.render.film_transparent = True
    scene.render.filter_size = 1.2
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.render.resolution_x = CANVAS_W
    scene.render.resolution_y = CANVAS_H
    scene.render.resolution_percentage = int(_RES) if _RES else (25 if PREVIEW else 100)
    lights()
    camera()
    return scene


def lights():
    """Sıcak, yumuşak iç mekân ışığı: sol-üst-önden geniş güneş + krem ortam dolgusu.
    Gölgeler sağ-arkaya, duvara düşer -> eşyalar duvardan ayrışır (derinlik)."""
    scene = bpy.context.scene
    world = bpy.data.worlds.new("World")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (*lin("#FFF1E0"), 1.0)
    bg.inputs[1].default_value = 0.62
    data = bpy.data.lights.new("Key", "SUN")
    data.energy = 2.3
    data.color = lin("#FFF4E4")
    data.angle = math.radians(26.0)
    obj = bpy.data.objects.new("Key", data)
    toward_light = Vector((-0.55, -0.75, 0.62)).normalized()
    obj.rotation_euler = toward_light.to_track_quat("Z", "Y").to_euler()
    scene.collection.objects.link(obj)


def camera():
    scene = bpy.context.scene
    top = (TOP_Z - CAM_H) / CAM_D
    floor = -CAM_H / CAM_D
    span = (top - floor) / FLOOR_LINE
    bottom = top - span
    data = bpy.data.cameras.new("Cam")
    data.type = "PERSP"
    data.sensor_fit = "VERTICAL"
    data.sensor_height = 36.0
    data.lens = 36.0 / span
    data.shift_y = (top + bottom) * 0.5 / span
    data.clip_start = 0.5
    data.clip_end = 100.0
    obj = bpy.data.objects.new("Cam", data)
    obj.location = (0.0, -CAM_D, CAM_H)
    obj.rotation_euler = (math.radians(90.0), 0.0, 0.0)
    scene.collection.objects.link(obj)
    scene.camera = obj


# ---------------------------------------------------------------------------- malzeme

_MATS = {}


def mat(name, color, rough=0.6, noise=0.0, noise_color=None, noise_scale=3.0, coat=0.0,
        emission=None, emission_strength=1.0, metallic=0.0, sheen=0.0, transmission=0.0,
        tone_jitter=0.0, bands=None, band_scale=1.0, spec=0.4):
    """Principled tabanlı yumuşak malzeme.

    noise: düşük frekanslı leke (eski/yıpranmış yüzeyler); noise_color lekenin rengi.
    tone_jitter: nesne başına rastgele ton (döşeme/tahta tek tip görünmesin).
    bands: [(konum, '#renk'), ...] — nesne merkezinden eşmerkezli renk halkaları (kilim).
    """
    if name in _MATS:
        return _MATS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nodes, links = m.node_tree.nodes, m.node_tree.links
    bsdf = nodes["Principled BSDF"]
    base = nodes.new("ShaderNodeRGB")
    base.outputs[0].default_value = (*lin(color), 1.0)
    col = base.outputs[0]
    if bands:
        texco = nodes.new("ShaderNodeTexCoord")
        mapping = nodes.new("ShaderNodeMapping")
        mapping.inputs["Scale"].default_value = (band_scale, band_scale * 1.6, band_scale)
        links.new(texco.outputs["Object"], mapping.inputs["Vector"])
        grad = nodes.new("ShaderNodeTexGradient")
        grad.gradient_type = "SPHERICAL"
        links.new(mapping.outputs["Vector"], grad.inputs["Vector"])
        ramp = nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.interpolation = "EASE"
        elems = ramp.color_ramp.elements
        for i, (pos, hexc) in enumerate(bands):
            el = elems[i] if i < len(elems) else elems.new(pos)
            el.position = pos
            el.color = (*lin(hexc), 1.0)
        links.new(grad.outputs["Fac"], ramp.inputs["Fac"])
        col = ramp.outputs["Color"]
    if tone_jitter > 0.0:
        info = nodes.new("ShaderNodeObjectInfo")
        rr = nodes.new("ShaderNodeMapRange")
        rr.inputs["To Min"].default_value = 1.0 - tone_jitter
        rr.inputs["To Max"].default_value = 1.0 + tone_jitter * 0.6
        links.new(info.outputs["Random"], rr.inputs["Value"])
        mul = nodes.new("ShaderNodeMix")
        mul.data_type = "RGBA"
        mul.blend_type = "MULTIPLY"
        mul.inputs["Factor"].default_value = 1.0
        comb = nodes.new("ShaderNodeCombineXYZ")
        for i in range(3):
            links.new(rr.outputs["Result"], comb.inputs[i])
        links.new(col, mul.inputs[6])
        links.new(comb.outputs[0], mul.inputs[7])
        col = mul.outputs[2]
    if noise > 0.0:
        texco = nodes.new("ShaderNodeTexCoord")
        tex = nodes.new("ShaderNodeTexNoise")
        tex.inputs["Scale"].default_value = noise_scale
        tex.inputs["Detail"].default_value = 4.0
        links.new(texco.outputs["Object"], tex.inputs["Vector"])
        rr = nodes.new("ShaderNodeMapRange")
        rr.inputs["From Min"].default_value = 0.5
        rr.inputs["From Max"].default_value = 0.68
        rr.inputs["To Max"].default_value = noise
        links.new(tex.outputs["Fac"], rr.inputs["Value"])
        mix = nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        links.new(rr.outputs["Result"], mix.inputs["Factor"])
        links.new(col, mix.inputs[6])
        mix.inputs[7].default_value = (*lin(noise_color or "#7A6E5E"), 1.0)
        col = mix.outputs[2]
    links.new(col, bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metallic
    for sock_name, value in (("Coat Weight", coat), ("Sheen Weight", sheen),
                             ("Transmission Weight", transmission), ("Specular IOR Level", spec)):
        if sock_name in bsdf.inputs:
            bsdf.inputs[sock_name].default_value = value
    if emission is not None:
        bsdf.inputs["Emission Color"].default_value = (*lin(emission), 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission_strength
    _MATS[name] = m
    return m


def sky_mat(name, top, bottom, strength=1.0):
    """Pencere/kapı camının arkasındaki gökyüzü: dikey gradyan, ışıktan etkilenmeyen yayım."""
    if name in _MATS:
        return _MATS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nodes, links = m.node_tree.nodes, m.node_tree.links
    for node in list(nodes):
        if node.type != "OUTPUT_MATERIAL":
            nodes.remove(node)
    out = [n for n in nodes if n.type == "OUTPUT_MATERIAL"][0]
    texco = nodes.new("ShaderNodeTexCoord")
    sep = nodes.new("ShaderNodeSeparateXYZ")
    links.new(texco.outputs["Generated"], sep.inputs[0])
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = "EASE"
    ramp.color_ramp.elements[0].color = (*lin(bottom), 1.0)
    ramp.color_ramp.elements[1].color = (*lin(top), 1.0)
    links.new(sep.outputs["Z"], ramp.inputs["Fac"])
    emis = nodes.new("ShaderNodeEmission")
    emis.inputs["Strength"].default_value = strength
    links.new(ramp.outputs["Color"], emis.inputs["Color"])
    links.new(emis.outputs[0], out.inputs["Surface"])
    _MATS[name] = m
    return m


# ---------------------------------------------------------------------------- geometri

_MESHES = {}


def link(obj):
    bpy.context.scene.collection.objects.link(obj)
    return obj


def activate(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def assign(obj, material):
    obj.data.materials.clear()
    obj.data.materials.append(material)
    return obj


def _bevel_apply(obj, width, segments):
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "NONE"
    mod.harden_normals = False
    activate(obj)
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.ops.object.shade_smooth()


def rbox(center, size, bevel, material, segments=8, rot=(0.0, 0.0, 0.0), name="Box"):
    """Yuvarlatılmış kutu (tombul kenar). Aynı boyutlu kutular tek mesh'i paylaşır (hız)."""
    key = ("box", round(size[0], 4), round(size[1], 4), round(size[2], 4), round(bevel, 4), segments)
    mesh = _MESHES.get(key)
    if mesh is None:
        bpy.ops.mesh.primitive_cube_add(size=1.0)
        tmp = bpy.context.view_layer.objects.active
        tmp.scale = size
        bpy.ops.object.transform_apply(scale=True)
        if bevel > 0.0:
            _bevel_apply(tmp, min(bevel, min(size) * 0.499), segments)
        mesh = tmp.data
        mesh.name = "M_%s" % name
        bpy.data.objects.remove(tmp)
        _MESHES[key] = mesh
    obj = link(bpy.data.objects.new(name, mesh))
    obj.location = center
    obj.rotation_euler = [math.radians(r) for r in rot]
    _object_material(obj, material)
    return obj


def _object_material(obj, material):
    """Paylaşılan mesh'te malzemeyi NESNE yuvasına bağla (her kopya farklı renkte olabilsin)."""
    if len(obj.data.materials) == 0:
        obj.data.materials.append(material)
    obj.material_slots[0].link = "OBJECT"
    obj.material_slots[0].material = material


def rcyl(center, radius, depth, bevel, material, axis="Z", segments=6, verts=72, name="Cyl"):
    """Kenarları yuvarlatılmış silindir; axis: silindirin ekseni (X/Y/Z)."""
    rot = {"Z": (0.0, 0.0, 0.0), "Y": (math.radians(90.0), 0.0, 0.0), "X": (0.0, math.radians(90.0), 0.0)}[axis]
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=center, rotation=rot)
    obj = bpy.context.view_layer.objects.active
    obj.name = name
    if bevel > 0.0:
        _bevel_apply(obj, min(bevel, radius * 0.49, depth * 0.49), segments)
    else:
        bpy.ops.object.shade_smooth()
    return assign(obj, material)


def sphere(center, scale, material, rot=(0.0, 0.0, 0.0), name="Sphere"):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=64, ring_count=32, radius=1.0, location=center,
                                         rotation=[math.radians(r) for r in rot])
    obj = bpy.context.view_layer.objects.active
    obj.name = name
    obj.scale = scale
    bpy.ops.object.shade_smooth()
    return assign(obj, material)


def torus(center, major, minor, material, axis="Y", name="Torus"):
    rot = {"Z": (0.0, 0.0, 0.0), "Y": (math.radians(90.0), 0.0, 0.0), "X": (0.0, math.radians(90.0), 0.0)}[axis]
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=96,
                                     minor_segments=32, location=center, rotation=rot)
    obj = bpy.context.view_layer.objects.active
    obj.name = name
    bpy.ops.object.shade_smooth()
    return assign(obj, material)


def slab(outlines, depth, bevel, material, y=0.0, name="Slab", loc=(0.0, 0.0)):
    """XZ düzleminde 2B dış hat(lar) -> Y yönünde kalınlık, yuvarlak bevel.
    İç içe dış hatlar delik açar (pencere çerçevesi gibi)."""
    if outlines and isinstance(outlines[0][0], (int, float)):
        outlines = [outlines]
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "2D"
    curve.fill_mode = "BOTH"
    curve.extrude = max(depth * 0.5 - bevel, 0.0)
    curve.bevel_depth = bevel
    curve.bevel_resolution = 6
    for outline in outlines:
        spline = curve.splines.new("POLY")
        spline.points.add(len(outline) - 1)
        for point, (px, pz) in zip(spline.points, outline):
            point.co = (px, pz, 0.0, 1.0)
        spline.use_cyclic_u = True
    obj = link(bpy.data.objects.new(name, curve))
    obj.rotation_euler = (math.radians(90.0), 0.0, 0.0)
    obj.location = (loc[0], y, loc[1])
    activate(obj)
    bpy.ops.object.convert(target="MESH")
    obj = bpy.context.view_layer.objects.active
    bpy.ops.object.shade_smooth()
    return assign(obj, material)


def tube(points, material, name="Tube", res=8):
    """Yarıçaplı yumuşak boru: points = [(x, y, z, r), ...]."""
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = 1.0
    curve.bevel_resolution = res
    curve.use_fill_caps = True
    spline = curve.splines.new("NURBS")
    spline.points.add(len(points) - 1)
    for point, (x, y, z, r) in zip(spline.points, points):
        point.co = (x, y, z, 1.0)
        point.radius = r
    spline.use_endpoint_u = True
    spline.order_u = min(4, len(points))
    spline.resolution_u = 16
    obj = link(bpy.data.objects.new(name, curve))
    activate(obj)
    bpy.ops.object.convert(target="MESH")
    obj = bpy.context.view_layer.objects.active
    bpy.ops.object.shade_smooth()
    return assign(obj, material)


def rounded_rect(x0, z0, x1, z1, r, steps=10):
    pts = []
    for cx, cz, a0 in ((x1 - r, z1 - r, 0), (x0 + r, z1 - r, 90), (x0 + r, z0 + r, 180), (x1 - r, z0 + r, 270)):
        for i in range(steps + 1):
            a = math.radians(a0 + 90.0 * i / steps)
            pts.append((cx + r * math.cos(a), cz + r * math.sin(a)))
    return pts


def arch_rect(x0, z0, x1, z1, r_bottom=0.06, steps=32):
    """Üstü yarım daire kemerli dikdörtgen (pencere/kapı)."""
    w = (x1 - x0) * 0.5
    cx = (x0 + x1) * 0.5
    top_c = z1 - w
    pts = []
    for i in range(steps + 1):
        a = math.radians(180.0 * i / steps)
        pts.append((cx + w * math.cos(a), top_c + w * math.sin(a)))
    for cx2, cz2, a0 in ((x0 + r_bottom, z0 + r_bottom, 180), (x1 - r_bottom, z0 + r_bottom, 270)):
        for i in range(9):
            a = math.radians(a0 + 90.0 * i / 8)
            pts.append((cx2 + r_bottom * math.cos(a), cz2 + r_bottom * math.sin(a)))
    return pts


def ellipse(cx, cz, rx, rz, steps=64):
    return [(cx + rx * math.cos(2 * math.pi * i / steps), cz + rz * math.sin(2 * math.pi * i / steps))
            for i in range(steps)]


def dome(center, radius, height, material, thickness=0.02, name="Dome"):
    """Lamba abajuru: yarım küre kabuk (içi boş), ağzı aşağı."""
    bpy.ops.mesh.primitive_uv_sphere_add(segments=96, ring_count=48, radius=1.0)
    obj = bpy.context.view_layer.objects.active
    obj.name = name
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    gone = [v for v in bm.verts if v.co.z < -0.02]
    bmesh.ops.delete(bm, geom=gone, context="VERTS")
    bm.to_mesh(obj.data)
    bm.free()
    obj.scale = (radius, radius, height)
    bpy.ops.object.transform_apply(scale=True)
    mod = obj.modifiers.new("Solid", "SOLIDIFY")
    mod.thickness = thickness
    mod.offset = -1.0
    bpy.ops.object.modifier_apply(modifier=mod.name)
    sub = obj.modifiers.new("Sub", "SUBSURF")
    sub.levels = 1
    sub.render_levels = 1
    bpy.ops.object.modifier_apply(modifier=sub.name)
    bpy.ops.object.shade_smooth()
    obj.location = center
    return assign(obj, material)


def lathe(profile, material, center, segments=96, name="Lathe"):
    """Profil (r, z) noktalarını Z ekseni etrafında döndürür (saksı, şişe)."""
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    rings = []
    for r, z in profile:
        ring = []
        for i in range(segments):
            a = 2 * math.pi * i / segments
            ring.append(bm.verts.new((r * math.cos(a), r * math.sin(a), z)))
        rings.append(ring)
    for a_ring, b_ring in zip(rings, rings[1:]):
        for i in range(segments):
            j = (i + 1) % segments
            bm.faces.new((a_ring[i], a_ring[j], b_ring[j], b_ring[i]))
    bm.to_mesh(mesh)
    bm.free()
    obj = link(bpy.data.objects.new(name, mesh))
    obj.location = center
    activate(obj)
    sub = obj.modifiers.new("Sub", "SUBSURF")
    sub.levels = 2
    sub.render_levels = 2
    bpy.ops.object.modifier_apply(modifier=sub.name)
    bpy.ops.object.shade_smooth()
    return assign(obj, material)


# ---------------------------------------------------------------------------- palet

WOOD_OAK = "#D8A878"
WOOD_HONEY = "#E2B27C"
WOOD_WALNUT = "#9A6B4A"
CREAM = "#FBF3E4"
CHROME = "#E8ECEF"
OLD_GRAY = "#A39C90"
CARDBOARD = "#C9A27A"
LEAF = "#7DBE7A"

WALL_COLORS = [("#BFE3D2", "#DFF1E8"), ("#F6CDB8", "#FBE6DA"), ("#BCD6EE", "#E0ECF7")]
FLOOR_VARIANTS = ["planks", "checker", "terracotta"]
WINDOW_FRAMES = ["#FFFFFF", "#A9C9B0", WOOD_HONEY]
WINDOW_FLOWERS = [("#F49AB0", "#FFFFFF"), ("#FFD36B", "#F7A8C0"), ("#B9A4F0", "#FFFFFF")]
DOOR_COLORS = ["#8FBF9F", "#8DB3D9", "#F2C36B"]
SIGN_COLORS = [("#FFFFFF", "#56B08A"), ("#FFD9E0", "#E27D93"), ("#DCEBFA", "#5A8FD0")]
SHELF_WOODS = [WOOD_OAK, "#F4EEE6", WOOD_WALNUT]
TOWEL_SETS = [["#F7B8B0", "#FFFFFF", "#A9D8C4"], ["#B9D4F2", "#FFF3C9", "#FFFFFF"],
              ["#F4D7A6", "#E9C0D9", "#FFFFFF"]]
LAMP_COLORS = ["#7FC4A4", "#F6E7CF", "#E99A7B"]
MACHINE1_COLORS = ["#9ED8C3", "#FFE08A", "#F7B6C2"]
MACHINE2_COLORS = ["#A9CDF0", "#CDB8F0", "#FFF6E8"]
POT_COLORS = ["#D9825B", "#F5F0E6", "#8FB3C9"]
RUG_BANDS = [
    [(0.0, "#F6E3C5"), (0.35, "#F6E3C5"), (0.4, "#E99A7B"), (0.62, "#E99A7B"), (0.66, "#FBF3E4")],
    [(0.0, "#CFE8DB"), (0.35, "#CFE8DB"), (0.4, "#5FAE8C"), (0.62, "#5FAE8C"), (0.66, "#F5F0E6")],
    [(0.0, "#E2D7F5"), (0.35, "#E2D7F5"), (0.4, "#8E7CC9"), (0.62, "#8E7CC9"), (0.66, "#FBF3E4")],
]
COUNTER_COLORS = ["#A8CDB4", "#FBEAD6", "#9DBAD9"]


# ---------------------------------------------------------------------------- yerleşim (dünya)
# Duvar yüzü y=0, zemin z=0, kamera -y'den bakar. Ekran izdüşümü için `screen()`.

M1_X = -0.72
M2_X = 0.36
M_W, M_D, M_H = 0.95, 0.8, 1.15
DOOR_X0, DOOR_X1, DOOR_Z1 = 1.22, 2.08, 2.2
WIN_X0, WIN_X1, WIN_Z0, WIN_Z1 = -2.0, -0.62, 2.05, 3.62
SHELF_Z = 1.52
PLANT_POS = (1.12, -0.5)
# Tezgâh dar bir yan dolap: tamamen kadraj içinde (sol kenardan ~15 px pay), makineyi örtmez.
COUNTER_C = (-1.46, -2.1)
RUG_C = (0.35, -2.75)
LAMP_POS = (-0.05, -1.6, 2.95)
SIGN_C = (1.15, 3.12)


def screen(x, y, z):
    top = (TOP_Z - CAM_H) / CAM_D
    span = (top + CAM_H / CAM_D) / FLOOR_LINE
    dist = y + CAM_D
    px = CANVAS_W * 0.5 + (x / dist) / (span * CANVAS_W / CANVAS_H) * CANVAS_W
    py = (top - (z - CAM_H) / dist) / span * CANVAS_H
    return round(px), round(py)


# ---------------------------------------------------------------------------- yuvalar

def build_floor(state):
    rng = random.Random(11)
    x0, x1, y0, y1 = -3.4, 3.4, -8.5, 0.6
    if state == "old":
        bed = mat("bed_old", "#6E665C", rough=0.9)
        rbox((0.0, (y0 + y1) * 0.5, -0.06), (x1 - x0 + 0.4, y1 - y0, 0.1), 0.01, bed, segments=1)
        tile = mat("tile_old", "#C9C2B4", rough=0.8, noise=0.55, noise_color="#8F8676", noise_scale=1.4,
                   tone_jitter=0.16)
        step = 0.5
        for ix in range(int((x1 - x0) / step) + 1):
            for iy in range(int((y1 - y0) / step) + 1):
                cx = x0 + ix * step
                cy = y0 + iy * step
                roll = rng.random()
                if roll < 0.05:
                    continue  # kırık/eksik karo: altındaki koyu harç görünür
                tilt = (rng.uniform(-4, 4), rng.uniform(-4, 4), rng.uniform(-3, 3)) if roll < 0.14 else (0, 0, 0)
                lift = rng.uniform(0.0, 0.025) if roll < 0.14 else 0.0
                rbox((cx, cy, -0.035 + lift), (step - 0.035, step - 0.035, 0.07), 0.025, tile, segments=4,
                     rot=tilt, name="Tile")
        return
    variant = FLOOR_VARIANTS[state]
    if variant == "planks":
        grout = mat("grout_wood", "#9C7552", rough=0.9)
        rbox((0.0, (y0 + y1) * 0.5, -0.07), (x1 - x0 + 0.4, y1 - y0, 0.1), 0.01, grout, segments=1)
        plank = mat("plank", WOOD_HONEY, rough=0.45, tone_jitter=0.14, coat=0.25)
        width = 0.34
        lengths = [1.6, 2.2, 2.8]
        for ix in range(int((x1 - x0) / width) + 2):
            cx = x0 + ix * width
            cy = y0 - rng.uniform(0.0, 2.0)
            while cy < y1:
                length = rng.choice(lengths)
                rbox((cx, cy + length * 0.5, -0.04), (width - 0.025, length - 0.025, 0.08), 0.022, plank,
                     segments=4, name="Plank")
                cy += length
        return
    grout = mat("grout_%s" % variant, "#E9E1D2" if variant == "checker" else "#C9B39A", rough=0.9)
    rbox((0.0, (y0 + y1) * 0.5, -0.07), (x1 - x0 + 0.4, y1 - y0, 0.1), 0.01, grout, segments=1)
    if variant == "checker":
        a = mat("tile_cream", "#FBF6EC", rough=0.35, coat=0.3, tone_jitter=0.03)
        b = mat("tile_mint", "#9FD3BD", rough=0.35, coat=0.3, tone_jitter=0.04)
        step = 0.52
    else:
        a = mat("tile_terra", "#E6A07E", rough=0.5, coat=0.15, tone_jitter=0.12)
        b = mat("tile_terra2", "#F0BE9C", rough=0.5, coat=0.15, tone_jitter=0.1)
        step = 0.42
    for ix in range(int((x1 - x0) / step) + 2):
        for iy in range(int((y1 - y0) / step) + 2):
            cx = x0 + ix * step
            cy = y0 + iy * step
            m = a if (ix + iy) % 2 == 0 or variant != "checker" and rng.random() < 0.7 else b
            rbox((cx, cy, -0.035), (step - 0.03, step - 0.03, 0.07), 0.03, m, segments=4, name="Tile")


def build_wall(state):
    x0, x1 = -3.0, 3.0
    if state == "old":
        plaster = mat("plaster_old", "#D3C7AE", rough=0.9, noise=0.75, noise_color="#A8987A", noise_scale=1.1)
        rbox((0.0, 0.15, 3.0), (x1 - x0, 0.3, 6.0), 0.01, plaster, segments=1, name="Wall")
        # Dökülmüş sıva altından tuğla öbekleri (yuvarlak, tombul tuğlalar).
        brick = mat("brick_old", "#C98E72", rough=0.85, tone_jitter=0.18)
        rng = random.Random(4)
        for (bx, bz, cols, rows) in ((-2.35, 1.05, 3, 4), (0.55, 3.75, 4, 3), (1.95, 2.75, 2, 3)):
            for r in range(rows):
                for c in range(cols - (r % 2)):
                    if rng.random() < 0.22:
                        continue
                    x = bx + c * 0.3 + (0.15 if r % 2 else 0.0)
                    rbox((x, -0.02, bz + r * 0.15), (0.27, 0.06, 0.12), 0.03, brick, segments=4, name="Brick")
        # Eski süpürgelik: soluk, bir yerinden kopuk.
        base = mat("base_old", "#B9AE98", rough=0.8, noise=0.4)
        rbox((-1.6, -0.03, 0.08), (2.8, 0.06, 0.16), 0.025, base, segments=4)
        rbox((1.75, -0.03, 0.08), (2.4, 0.06, 0.16), 0.025, base, segments=4, rot=(0, -2.0, 0))
        # Çatlak: ince koyu, kıvrık boru.
        return
    upper, lower = WALL_COLORS[state]
    paint = mat("paint_%d" % state, upper, rough=0.85)
    rbox((0.0, 0.15, 3.0), (x1 - x0, 0.3, 6.0), 0.01, paint, segments=1, name="Wall")
    # Alt lambiri: dikey, yuvarlak çıtalar (beadboard) — sıcak, el yapımı his.
    board = mat("board_%d" % state, lower, rough=0.6, tone_jitter=0.02)
    step = 0.16
    count = int((x1 - x0) / step)
    for i in range(count + 1):
        rbox((x0 + i * step, -0.02, 0.5), (step - 0.012, 0.05, 0.92), 0.02, board, segments=4, name="Bead")
    trim = mat("trim_%d" % state, "#FFFFFF", rough=0.45)
    rcyl((0.0, -0.05, 0.98), 0.04, x1 - x0, 0.0, trim, axis="X", name="Rail")
    rbox((0.0, -0.05, 0.09), (x1 - x0, 0.08, 0.18), 0.03, trim, segments=5, name="Baseboard")
    # Üst korniş (kadrajın tepesinde ince bir bant, odayı "kapatır").
    rbox((0.0, -0.04, 4.55), (x1 - x0, 0.1, 0.16), 0.04, trim, segments=5, name="Cornice")


def _window_sky(z0, z1, x0, x1, dirty):
    sky = sky_mat("sky_dirty" if dirty else "sky", "#8FA4AE" if dirty else "#9ED6F5",
                  "#B5B4A4" if dirty else "#EAF6E9", 0.85 if dirty else 1.0)
    pane = rbox(((x0 + x1) * 0.5, 0.06, (z0 + z1) * 0.5), (x1 - x0 + 0.1, 0.02, z1 - z0 + 0.1), 0.0, sky,
                segments=1, name="Sky")
    if not dirty:
        # Uzak tepeler ve bulut: pencereden bahçeye bakış (oyunun bahçesiyle aynı dil).
        hill = sky_mat("hill", "#B6DDAA", "#9FCF94", 1.0)
        sphere(((x0 + x1) * 0.5 - 0.2, 0.05, z0 - 0.05), (0.8, 0.01, 0.35), hill)
        cloud = sky_mat("cloud", "#FFFFFF", "#F4F1F8", 1.0)
        for dx, dz, r in ((-0.15, 0.55, 0.16), (0.05, 0.6, 0.2), (0.25, 0.54, 0.14)):
            sphere(((x0 + x1) * 0.5 + dx, 0.04, (z0 + z1) * 0.5 + dz), (r * 1.3, 0.01, r), cloud)
    return pane


def build_window(state):
    x0, x1, z0, z1 = WIN_X0, WIN_X1, WIN_Z0, WIN_Z1
    old = state == "old"
    frame_m = mat("wframe_old", "#B8AC96", rough=0.85, noise=0.5) if old else \
        mat("wframe_%d" % state, WINDOW_FRAMES[state], rough=0.45, coat=0.2)
    t = 0.11
    outer = arch_rect(x0 - t, z0 - t, x1 + t, z1 + t)
    inner = arch_rect(x0, z0, x1, z1)
    slab([outer, inner], 0.14, 0.04, frame_m, y=-0.05, name="Frame")
    _window_sky(z0, z1, x0, x1, old)
    cx = (x0 + x1) * 0.5
    mull = frame_m
    rbox((cx, -0.02, (z0 + z1) * 0.5 - 0.05), (0.05, 0.05, z1 - z0 - 0.05), 0.02, mull, segments=4)
    rbox((cx, -0.02, z0 + (z1 - z0) * 0.42), (x1 - x0, 0.05, 0.05), 0.02, mull, segments=4)
    sill_m = mat("sill_old", "#B0A48D", rough=0.85, noise=0.5) if old else mat("sill", "#FFFFFF", rough=0.4)
    rbox((cx, -0.12, z0 - t - 0.04), (x1 - x0 + 0.42, 0.28, 0.08), 0.035, sill_m, segments=5, name="Sill")
    if old:
        # Çapraz çakılmış tahtalar + çivi başları.
        plank = mat("board_old", "#B98F64", rough=0.8, noise=0.45, noise_color="#8A6A4A")
        nail = mat("nail", "#8C8C8C", rough=0.4, metallic=0.6)
        for ang, dz, by in ((24.0, 0.0, -0.12), (-20.0, 0.25, -0.17)):
            rbox((cx, by, (z0 + z1) * 0.5 + dz - 0.2), (x1 - x0 + 0.35, 0.05, 0.18), 0.03, plank,
                 segments=4, rot=(0.0, ang, 0.0), name="Board")
        for sx, sz in ((x0 - 0.02, z0 + 0.32), (x1 + 0.02, z0 + 0.95), (x0 + 0.05, z0 + 1.0), (x1 - 0.02, z0 + 0.42)):
            sphere((sx, -0.155, sz), (0.025, 0.012, 0.025), nail)
        return
    # Saksılı çiçek kutusu (pencere altında): yeni pencerenin sevimli imzası.
    box_m = mat("wbox_%d" % state, WINDOW_FRAMES[state] if state != 0 else "#F3D7C3", rough=0.55)
    rbox((cx, -0.28, z0 - t - 0.2), (x1 - x0 + 0.1, 0.26, 0.22), 0.07, box_m, segments=6, name="FlowerBox")
    leaf = mat("wleaf", LEAF, rough=0.6, tone_jitter=0.15)
    petal_a = mat("wpetal_a_%d" % state, WINDOW_FLOWERS[state][0], rough=0.5, sheen=0.4)
    petal_b = mat("wpetal_b_%d" % state, WINDOW_FLOWERS[state][1], rough=0.5, sheen=0.4)
    heart = mat("wheart", "#FFC94D", rough=0.5)
    rng = random.Random(7 + state)
    span = x1 - x0
    for i in range(9):
        lx = x0 + 0.06 + span * (i + 0.5) / 9.0
        sphere((lx, -0.3 + rng.uniform(-0.05, 0.05), z0 - t - 0.06 + rng.uniform(0.0, 0.05)),
               (0.1, 0.07, 0.07), leaf, rot=(0, rng.uniform(-30, 30), 0))
    for i in range(5):
        fx = x0 + 0.12 + span * (i + 0.5) / 5.0 - 0.06
        fz = z0 - t + 0.05 + rng.uniform(0.0, 0.06)
        pm = petal_a if i % 2 == 0 else petal_b
        for k in range(5):
            a = 2 * math.pi * k / 5
            sphere((fx + 0.055 * math.cos(a), -0.36, fz + 0.055 * math.sin(a)), (0.045, 0.02, 0.045), pm)
        sphere((fx, -0.38, fz), (0.03, 0.02, 0.03), heart)


def build_door(state):
    x0, x1, z1 = DOOR_X0, DOOR_X1, DOOR_Z1
    old = state == "old"
    frame_m = mat("dframe_old", "#B4A891", rough=0.85, noise=0.5) if old else mat("dframe", "#FFFFFF", rough=0.45)
    t = 0.09
    outer = arch_rect(x0 - t, 0.0, x1 + t, z1 + t, r_bottom=0.01)
    inner = arch_rect(x0, 0.0, x1, z1, r_bottom=0.01)
    slab([outer, inner], 0.12, 0.035, frame_m, y=-0.05, name="DoorFrame")
    if old:
        body = mat("door_old", "#9C7A5C", rough=0.85, noise=0.6, noise_color="#76593F", noise_scale=2.4)
    else:
        body = mat("door_%d" % state, DOOR_COLORS[state], rough=0.5, coat=0.25)
    slab(arch_rect(x0 + 0.01, 0.0, x1 - 0.01, z1 - 0.01, r_bottom=0.01), 0.09, 0.03, body, y=-0.01, name="Door")
    cx = (x0 + x1) * 0.5
    # Kabartma paneller.
    panel = body
    for (pz0, pz1) in ((0.18, 0.95),):
        slab(rounded_rect(x0 + 0.12, pz0, x1 - 0.12, pz1, 0.06), 0.03, 0.012, panel, y=-0.06, name="Panel")
    # Yuvarlak cam (kapıda lomboz) — gökyüzü görünür.
    wz = 1.62
    ring_m = mat("dring_old", "#B5A98F", rough=0.7) if old else mat("dring", "#FFFFFF", rough=0.35, coat=0.4)
    torus((cx, -0.07, wz), 0.22, 0.035, ring_m, axis="Y", name="Porthole")
    glass = sky_mat("dsky_old" if old else "dsky", "#A5B3B5" if old else "#A9DCF5",
                    "#C2BDAA" if old else "#EEF8EE", 0.9)
    rcyl((cx, -0.04, wz), 0.205, 0.02, 0.0, glass, axis="Y", name="DoorGlass")
    knob_m = mat("knob_old", "#9E9483", rough=0.5, metallic=0.4) if old else \
        mat("knob", "#F0C66B", rough=0.25, metallic=0.8, coat=0.5)
    sphere((x1 - 0.13, -0.12, 1.02), (0.05, 0.05, 0.05), knob_m)
    rcyl((x1 - 0.13, -0.08, 1.02), 0.03, 0.06, 0.008, knob_m, axis="Y")
    if old:
        # Yamuk bant + çizik: eski kapının "unutulmuş" hâli.
        tape = mat("tape", "#E8D7A8", rough=0.8)
        rbox((cx - 0.05, -0.075, 1.3), (0.5, 0.012, 0.08), 0.005, tape, segments=2, rot=(0, 12, 0))
    else:
        # Paspas: kapı önünde yumuşak hap.
        mat_m = mat("doormat_%d" % state, "#E8D2B0", rough=0.95, sheen=0.6)
        rbox((cx, -0.42, 0.02), (0.82, 0.42, 0.04), 0.02, mat_m, segments=4, name="Doormat")


def build_sign(state):
    board_c, icon_c = SIGN_COLORS[state]
    board = mat("sign_%d" % state, board_c, rough=0.4, coat=0.5)
    icon = mat("signicon_%d" % state, icon_c, rough=0.35, coat=0.6)
    cx, cz = SIGN_C
    w, h = 1.25, 0.56
    slab(rounded_rect(cx - w / 2, cz - h / 2, cx + w / 2, cz + h / 2, h / 2), 0.1, 0.045, board, y=-0.1, name="Sign")
    # Kabartma tişört simgesi + köpükler.
    sx, sz, s = cx - 0.22, cz, 0.36
    shirt = [(-0.5, 0.42), (-0.18, 0.5), (-0.1, 0.42), (0.1, 0.42), (0.18, 0.5), (0.5, 0.42), (0.62, 0.12),
             (0.36, 0.04), (0.34, -0.5), (-0.34, -0.5), (-0.36, 0.04), (-0.62, 0.12)]
    slab([(sx + px * s, sz + pz * s) for px, pz in shirt], 0.05, 0.02, icon, y=-0.17, name="Shirt")
    bubble = mat("bubble", "#FFFFFF", rough=0.08, coat=1.0)
    for bx, bz, r in ((0.2, 0.08, 0.07), (0.36, -0.06, 0.05), (0.33, 0.14, 0.035), (0.46, 0.06, 0.03)):
        sphere((cx + bx, -0.19, cz + bz), (r, r * 0.7, r), icon if r > 0.06 else bubble)
    # Asma kancaları (yuvarlak düğmeler).
    hook = mat("signhook", "#E9E3D8", rough=0.4, metallic=0.3)
    for dx in (-w * 0.32, w * 0.32):
        tube([(cx + dx, -0.12, cz + h / 2 - 0.02, 0.012), (cx + dx * 0.6, -0.06, cz + h / 2 + 0.22, 0.012),
              (cx, -0.02, cz + h / 2 + 0.34, 0.012)], hook)
    sphere((cx, -0.03, cz + h / 2 + 0.34), (0.04, 0.03, 0.04), hook)


def build_shelf(state):
    cx = -0.15
    if state == "old":
        wood = mat("shelfwood_old", "#A88B6C", rough=0.85, noise=0.5)
        rbox((cx, -0.15, SHELF_Z - 0.05), (1.6, 0.28, 0.05), 0.02, wood, segments=4, rot=(0.0, 4.5, 0.0))
        metal = mat("bracket_old", "#8E8778", rough=0.5, metallic=0.5)
        rbox((cx - 0.6, -0.12, SHELF_Z - 0.16), (0.04, 0.22, 0.2), 0.015, metal, segments=3)
        can = mat("can_old", "#B7B1A3", rough=0.5, metallic=0.4, noise=0.5, noise_color="#8C7C66")
        rcyl((cx - 0.35, -0.15, SHELF_Z + 0.07), 0.07, 0.17, 0.02, can, name="Can")
        cloth = mat("cloth_old", "#CFC7B6", rough=0.95, sheen=0.4)
        sphere((cx + 0.3, -0.16, SHELF_Z + 0.0), (0.16, 0.1, 0.06), cloth, rot=(0, -6, 0))
        return
    wood = mat("shelfwood_%d" % state, SHELF_WOODS[state], rough=0.5, coat=0.2)
    rbox((cx, -0.17, SHELF_Z), (2.0, 0.34, 0.07), 0.03, wood, segments=5, name="Board")
    for dx in (-0.75, 0.75):
        slab([(0.0, 0.0), (0.0, -0.26), (0.03, -0.26)] + [(0.03 + 0.25 * (1 - math.cos(math.radians(a))),
                                                          -0.26 + 0.25 * math.sin(math.radians(a)))
                                                         for a in range(0, 91, 10)] + [(0.28, 0.0)],
             0.05, 0.015, wood, y=-0.15, loc=(cx + dx - 0.02, SHELF_Z - 0.035), name="Bracket")
    towels = TOWEL_SETS[state]
    for i, base_x in enumerate((cx - 0.7, cx - 0.35)):
        for k in range(3):
            tm = mat("towel_%d_%d" % (state, (i + k) % 3), towels[(i + k) % 3], rough=0.9, sheen=0.8)
            rbox((base_x + (k % 2) * 0.015, -0.18, SHELF_Z + 0.07 + k * 0.075), (0.3, 0.26, 0.075), 0.034, tm,
                 segments=6, name="Towel")
    bottle_m = mat("bottle_%d" % state, towels[0], rough=0.25, coat=0.6)
    cap_m = mat("cap", "#FFFFFF", rough=0.3)
    for k, bx in enumerate((cx + 0.15, cx + 0.38)):
        hgt = 0.34 - k * 0.07
        lathe([(0.0, 0.0), (0.085, 0.0), (0.1, 0.03), (0.1, hgt * 0.7), (0.07, hgt * 0.9), (0.045, hgt),
               (0.0, hgt)], bottle_m if k == 0 else mat("bottle2_%d" % state, towels[2], rough=0.25, coat=0.6),
              (bx, -0.18, SHELF_Z + 0.035), name="Bottle")
        rcyl((bx, -0.18, SHELF_Z + 0.035 + hgt + 0.02), 0.05, 0.05, 0.015, cap_m)
    # Mandal kavanozu: cam yerine yumuşak krem çömlek + üstte renkli mandallar.
    jar = mat("jar", "#F5EBDD", rough=0.4, coat=0.3)
    lathe([(0.0, 0.0), (0.09, 0.0), (0.11, 0.05), (0.11, 0.16), (0.09, 0.2), (0.0, 0.2)], jar,
          (cx + 0.68, -0.18, SHELF_Z + 0.035), name="Jar")
    for k, hexc in enumerate(("#F7B8B0", "#9ED8C3", "#FFE08A")):
        pin = mat("pinc_%d" % k, hexc, rough=0.4)
        rbox((cx + 0.64 + k * 0.04, -0.18, SHELF_Z + 0.28), (0.025, 0.04, 0.14), 0.012, pin, segments=3,
             rot=(0, -12 + k * 12, 0))


def build_lamp(state):
    x, y, z = LAMP_POS
    cord = mat("cord", "#5E5850", rough=0.6)
    tube([(x, y, 6.0, 0.012), (x, y, z + 0.4, 0.012), (x, y, z + 0.2, 0.012)], cord, name="Cord")
    if state == "old":
        sock = mat("socket_old", "#6B655C", rough=0.5)
        rcyl((x, y, z + 0.12), 0.04, 0.12, 0.012, sock)
        bulb = mat("bulb_old", "#E8E0C8", rough=0.2, emission="#FFE7B0", emission_strength=0.6)
        sphere((x, y, z - 0.02), (0.08, 0.08, 0.1), bulb)
        return
    shade_m = mat("shade_%d" % state, LAMP_COLORS[state], rough=0.35, coat=0.6)
    dome((x, y, z - 0.08), 0.42, 0.3, shade_m, thickness=0.025, name="Shade")
    cap = mat("lampcap", "#FFFFFF", rough=0.3)
    rcyl((x, y, z + 0.24), 0.07, 0.08, 0.02, cap)
    bulb = mat("bulb", "#FFF6DD", rough=0.2, emission="#FFE6A8", emission_strength=6.0)
    sphere((x, y, z - 0.08), (0.11, 0.11, 0.11), bulb)


def _washer(x, body_hex, old, name):
    d, w, h = M_D, M_W, M_H
    cy = -d * 0.5 - 0.03
    if old:
        body = mat(name + "_body", body_hex, rough=0.6, noise=0.5, noise_color="#8E8370", noise_scale=2.2)
        accent = mat(name + "_panel", "#C8C2B4", rough=0.7, noise=0.3)
        ring = mat(name + "_ring", "#A8A497", rough=0.5, metallic=0.4)
        glass = mat(name + "_glass", "#8E9A98", rough=0.35, coat=0.3)
    else:
        body = mat(name + "_body", body_hex, rough=0.32, coat=0.7)
        accent = mat(name + "_panel", "#FFFFFF", rough=0.3, coat=0.5)
        ring = mat(name + "_ring", CHROME, rough=0.18, metallic=0.85, coat=0.4)
        glass = mat(name + "_glass", "#CFE8F2", rough=0.04, transmission=0.82, coat=1.0)
    rbox((x, cy, h * 0.5 + 0.04), (w, d, h), 0.12, body, segments=10, name=name + "Body")
    for fx in (-w * 0.36, w * 0.36):
        rcyl((x + fx, cy - d * 0.32, 0.03), 0.045, 0.06, 0.012, accent)
    panel_z = h - 0.1
    rbox((x, cy - d * 0.5 + 0.01, panel_z), (w * 0.84, 0.06, 0.16), 0.05, accent, segments=6, name=name + "Panel")
    knob = mat(name + "_knob", "#FFFFFF" if not old else "#B3AD9F", rough=0.3, coat=0.5)
    rcyl((x + w * 0.24, cy - d * 0.5 - 0.04, panel_z), 0.06, 0.06, 0.02, knob, axis="Y")
    dots = [mat(name + "_dot%d" % i, c, rough=0.3) for i, c in
            enumerate(("#F49AB0", "#7FC4A4") if not old else ("#9C978B", "#9C978B"))]
    for i, dx in enumerate((-0.04, 0.06)):
        sphere((x + dx, cy - d * 0.5 - 0.025, panel_z), (0.026, 0.02, 0.026), dots[i])
    rbox((x - w * 0.27, cy - d * 0.5 - 0.02, panel_z), (0.22, 0.04, 0.09), 0.03, accent, segments=4,
         name=name + "Drawer")
    door_z = 0.5
    door_dx = 0.0
    door_y = cy - d * 0.5 - 0.035
    if old:
        door_dx = -0.05  # menteşeden sarkmış kapak
    drum = mat(name + "_drum", "#4F5A63" if not old else "#5A5852", rough=0.4, metallic=0.5)
    rcyl((x, cy - d * 0.5 + 0.02, door_z), 0.26, 0.04, 0.0, drum, axis="Y", name=name + "Drum")
    if not old:
        # Tamburun içinde renkli çamaşır yumağı: camdan görünür, sıcaklık katar.
        socks = mat(name + "_laundry", "#F7B8B0", rough=0.8, sheen=0.6)
        sphere((x + 0.05, cy - d * 0.5 + 0.0, door_z - 0.12), (0.17, 0.05, 0.1), socks)
        sphere((x - 0.1, cy - d * 0.5 + 0.0, door_z - 0.14), (0.12, 0.05, 0.08),
               mat(name + "_laundry2", "#A9CDF0", rough=0.8, sheen=0.6))
    torus((x + door_dx, door_y, door_z), 0.29, 0.055, ring, axis="Y", name=name + "Ring")
    sphere((x + door_dx, door_y + 0.01, door_z), (0.26, 0.05, 0.26), glass, name=name + "Glass")
    if old:
        tape = mat("tape_x", "#E9CF7A", rough=0.75)
        for ang in (35.0, -35.0):
            rbox((x + door_dx, door_y - 0.08, door_z), (0.78, 0.015, 0.075), 0.006, tape, segments=2,
                 rot=(0.0, ang, 0.0), name="Tape")


def build_machine1(state):
    if state == "old":
        _washer(M1_X, "#BDB6A6", True, "m1old")
    else:
        _washer(M1_X, MACHINE1_COLORS[state], False, "m1_%d" % state)


def build_machine2(state):
    if state == "old":
        # Boş köşede üst üste koliler: "henüz ikinci makine yok".
        card = mat("card", CARDBOARD, rough=0.85, tone_jitter=0.12, noise=0.25, noise_color="#A88560")
        tape = mat("cardtape", "#E2CDA3", rough=0.6)
        for (dx, dz, sx, sy, sz, rz) in ((0.0, 0.0, 0.8, 0.62, 0.5, 2.0), (-0.06, 0.5, 0.62, 0.5, 0.38, -6.0),
                                         (0.2, 0.88, 0.36, 0.32, 0.26, 10.0)):
            rbox((M2_X + dx, -0.42, dz + sz * 0.5), (sx, sy, sz), 0.04, card, segments=4, rot=(0, 0, rz))
            rbox((M2_X + dx, -0.42, dz + sz), (0.1, sy + 0.005, 0.012), 0.004, tape, segments=2, rot=(0, 0, rz))
        return
    _washer(M2_X, MACHINE2_COLORS[state], False, "m2_%d" % state)


def build_plant(state):
    px, py = PLANT_POS
    old = state == "old"
    pot_m = mat("pot_old", "#A5998A", rough=0.8, noise=0.5) if old else \
        mat("pot_%d" % state, POT_COLORS[state], rough=0.45, coat=0.3)
    lathe([(0.0, 0.0), (0.17, 0.0), (0.2, 0.04), (0.23, 0.36), (0.26, 0.38), (0.26, 0.44), (0.22, 0.44),
           (0.0, 0.43)], pot_m, (px, py, 0.0), name="Pot")
    soil = mat("soil", "#7A5A42", rough=0.95)
    rcyl((px, py, 0.425), 0.215, 0.02, 0.0, soil)
    rng = random.Random(21)
    if old:
        dry = mat("dry", "#B39A6E", rough=0.9, tone_jitter=0.2)
        stem = mat("drystem", "#8C7552", rough=0.9)
        tube([(px, py, 0.42, 0.018), (px + 0.02, py, 0.75, 0.015), (px + 0.12, py, 0.95, 0.012),
              (px + 0.3, py - 0.05, 0.85, 0.01)], stem)
        for k, (lx, lz, rot) in enumerate(((0.32, 0.78, 70), (0.12, 0.62, -60), (-0.1, 0.55, 40),
                                           (0.2, 0.92, 110))):
            sphere((px + lx, py - 0.08, lz), (0.05, 0.02, 0.13), dry, rot=(10, rot, 0))
        return
    leaf = mat("leaf_%d" % state, ["#6FB677", "#86C27A", "#5FA98A"][state], rough=0.45, coat=0.4,
               tone_jitter=0.16)
    stem = mat("stem", "#6E9B5A", rough=0.7)
    count = 15
    for k in range(count):
        a = 2 * math.pi * (k / count) + rng.uniform(-0.2, 0.2)
        tilt = rng.uniform(15, 55) if k % 3 else rng.uniform(0, 12)
        length = rng.uniform(0.55, 0.95)
        ex = math.sin(math.radians(tilt)) * length
        tip = (px + ex * math.cos(a) * 0.9, py + ex * math.sin(a) * 0.6, 0.43 + math.cos(math.radians(tilt)) * length)
        tube([(px, py, 0.42, 0.016), ((px + tip[0]) * 0.5, (py + tip[1]) * 0.5, (0.42 + tip[2]) * 0.5 + 0.04, 0.013),
              (tip[0], tip[1], tip[2] - 0.12, 0.01)], stem)
        rot_y = math.degrees(math.atan2(tip[0] - px, tip[2] - 0.43))
        sphere(tip, (0.13, 0.045, 0.21), leaf, rot=(rng.uniform(-15, 15), rot_y, 0))


def _organic(cx, cy, rx, ry, seed, n=120, tongue=0.0):
    """Düzensiz, organik su lekesi dış hattı (yerde düz; tongue: makineye doğru dil)."""
    rng = random.Random(seed)
    ph = [rng.uniform(0, math.tau) for _ in range(4)]
    pts = []
    for i in range(n):
        t = math.tau * i / n
        r = (1.0 + 0.11 * math.sin(2 * t + ph[0]) + 0.09 * math.sin(3 * t + ph[1])
             + 0.05 * math.sin(5 * t + ph[2]) + 0.025 * math.sin(7 * t + ph[3]))
        if tongue:
            d = math.atan2(math.sin(t - math.pi * 0.55), math.cos(t - math.pi * 0.55))
            r += tongue * math.exp(-(d / 0.16) ** 2)
        pts.append((cx + rx * r * math.cos(t), cy + ry * r * math.sin(t)))
    return pts


def _no_cast(obj):
    obj.visible_shadow = False
    return obj


def _glossy_only(obj):
    """Yalnız yansıma ışınlarına görünür: kamerada, gölgede ve dolaylı ışıkta YOK (katmana sızmaz)."""
    for attr in ("visible_camera", "visible_shadow", "visible_diffuse", "visible_transmission",
                 "visible_volume_scatter"):
        setattr(obj, attr, False)
    obj.visible_glossy = True
    return obj


def _soft_glow(name, color, strength):
    """Merkezi parlak, kenarı sıfıra sönen emisyon malzemesi (Y'ye bakan düzlem)."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs[0].default_value = (*lin(color), 1.0)
    coord = nt.nodes.new("ShaderNodeTexCoord")
    grad = nt.nodes.new("ShaderNodeTexGradient")
    grad.gradient_type = "SPHERICAL"
    sub = nt.nodes.new("ShaderNodeVectorMath")
    sub.operation = "SUBTRACT"
    sub.inputs[1].default_value = (0.5, 0.5, 0.5)
    flat = nt.nodes.new("ShaderNodeVectorMath")
    flat.operation = "MULTIPLY"
    flat.inputs[1].default_value = (1.0, 0.0, 1.0)
    nt.links.new(coord.outputs["Generated"], sub.inputs[0])
    nt.links.new(sub.outputs[0], flat.inputs[0])
    nt.links.new(flat.outputs[0], grad.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.5
    ramp.color_ramp.elements[0].color = (0, 0, 0, 1)
    ramp.color_ramp.elements[1].position = 1.0
    ramp.color_ramp.elements[1].color = (1, 1, 1, 1)
    ramp.color_ramp.interpolation = "EASE"
    mul = nt.nodes.new("ShaderNodeMath")
    mul.operation = "MULTIPLY"
    mul.inputs[1].default_value = strength
    nt.links.new(grad.outputs["Fac"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], mul.inputs[0])
    nt.links.new(mul.outputs[0], em.inputs["Strength"])
    nt.links.new(em.outputs[0], out.inputs["Surface"])
    return m


def _puddle_world():
    """Cam ışınları aynen kalır; yalnız yansıma (glossy) ışınları odanın sıcak-duvar rengini görür:
    su, gökyüzü-krem 'beyaz disk' yerine odayı yansıtır."""
    world = bpy.context.scene.world
    nt = world.node_tree
    bg = nt.nodes["Background"]
    lp = nt.nodes.new("ShaderNodeLightPath")
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.inputs[6].default_value = bg.inputs[0].default_value
    mix.inputs[7].default_value = (*lin("#9C8672"), 1.0)
    nt.links.new(lp.outputs["Is Glossy Ray"], mix.inputs["Factor"])
    nt.links.new(mix.outputs[2], bg.inputs[0])


def _water_mat(name, color, alpha, rough=0.05):
    m = mat(name, color, rough=rough, spec=1.0)
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Alpha"].default_value = alpha
    bsdf.inputs["IOR"].default_value = 1.33
    tex = nt.nodes.new("ShaderNodeTexNoise")
    tex.inputs["Scale"].default_value = 9.0
    tex.inputs["Detail"].default_value = 3.0
    coord = nt.nodes.new("ShaderNodeTexCoord")
    nt.links.new(coord.outputs["Object"], tex.inputs["Vector"])
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.035
    bump.inputs["Distance"].default_value = 0.02
    nt.links.new(tex.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    return m


def build_puddle():
    """Eski makineden sızan SIĞ su birikintisi: düzensiz hat, parlak yansıtıcı yüzey, ıslak koyu
    kenar halkası, makineye uzanan dil, ikincil küçük birikintiler ve damlalar."""
    _puddle_world()
    # Yansıma sahnesi (kameraya görünmez, gölge düşürmez): makinenin ön yüzü + sıcak ışık paneli.
    stand = mat("refl_machine", "#B3A292", rough=0.7)
    obj = rbox((M1_X, -0.43, 0.6), (M_W, M_D, 1.15), 0.1, stand, segments=4, name="ReflMachine")
    _glossy_only(obj)
    # Yumuşak kenarlı ışık lekeleri (pencere ışığı): sert dikdörtgen yerine eriyen parlama.
    for gx, gz, gw, gh, strength, tint in ((0.12, 0.22, 0.9, 0.34, 3.4, "#EAF5FF"),
                                           (0.72, 0.2, 0.5, 0.28, 2.4, "#FFEBD2")):
        glow = _soft_glow("refl_glow_%d" % int(gx * 10), tint, strength)
        card = rbox((M1_X + gx, -0.95, gz), (gw, 0.02, gh), 0.0, glow, segments=1, name="ReflGlow")
        _glossy_only(card)

    cx, cy = M1_X + 0.02, -1.22
    wet = mat("wet_rim", "#3A2C22", rough=0.45)
    wet.node_tree.nodes["Principled BSDF"].inputs["Alpha"].default_value = 0.11
    shapes = []
    # Islak koyu halka: büyükten küçüğe 4 katman -> kenara doğru yumuşak koyuluk.
    for k, grow in enumerate((1.26, 1.17, 1.09, 1.03)):
        pts = _organic(cx, cy, 0.52 * grow, 0.255 * grow, 7, tongue=0.35)
        slab(pts, 0.004, 0.0015, wet, y=0.0, name="Wet%d" % k)
        o = bpy.context.view_layer.objects.active
        o.rotation_euler = (0.0, 0.0, 0.0)
        o.location = (0.0, 0.0, 0.0015 + k * 0.0004)
        _no_cast(o)
    water = _water_mat("puddle", "#7FB2C4", 0.55)
    slab(_organic(cx, cy, 0.52, 0.255, 7, tongue=0.35), 0.018, 0.007, water, y=0.0, name="Puddle")
    o = bpy.context.view_layer.objects.active
    o.rotation_euler = (0.0, 0.0, 0.0)
    o.location = (0.0, 0.0, 0.004)
    _no_cast(o)
    # İkincil küçük birikintiler + damlalar.
    for i, (dx, dy, rx, ry) in enumerate(((0.74, -0.08, 0.10, 0.05), (-0.64, 0.1, 0.07, 0.038),
                                         (0.5, -0.4, 0.05, 0.03))):
        for grow, mm, al in ((1.25, wet, None), (1.0, water, None)):
            pts = _organic(cx + dx, cy + dy, rx * grow, ry * grow, 20 + i)
            slab(pts, 0.014 if mm is water else 0.004, 0.005 if mm is water else 0.0015, mm, y=0.0,
                 name="Small%d" % i)
            o = bpy.context.view_layer.objects.active
            o.rotation_euler = (0.0, 0.0, 0.0)
            o.location = (0.0, 0.0, 0.004 if mm is water else 0.0015)
            _no_cast(o)
    for dx, dy, r in ((0.30, -0.42, 0.022), (-0.18, -0.46, 0.017), (1.03, 0.0, 0.014),
                      (-0.95, 0.2, 0.013), (0.12, 0.55, 0.012)):
        o = sphere((cx + dx, cy + dy, 0.0), (r, r * 0.9, r * 0.55), water, name="Drop")
        _no_cast(o)
    # Damla izi: makine ayağından birikintiye doğru küçülen damlalar (sızıntı kaynağı).
    for k in range(4):
        o = sphere((M1_X + 0.12 - k * 0.012, -0.9 - k * 0.07, 0.0), (0.02 - k * 0.003, 0.026 - k * 0.003, 0.011),
                   water, name="Trail")
        _no_cast(o)


def build_rug(state):
    if state == "old":
        build_puddle()
        return
    cx, cy = RUG_C
    rug_m = mat("rug_%d" % state, "#FFFFFF", rough=0.95, sheen=0.9, bands=RUG_BANDS[state], band_scale=0.55)
    slab([(x, z) for x, z in ellipse(0.0, 0.0, 1.45, 0.9)], 0.035, 0.015, rug_m, y=0.0, name="Rug")
    obj = bpy.context.view_layer.objects.active
    obj.rotation_euler = (0.0, 0.0, 0.0)
    obj.location = (cx, cy, 0.017)


def build_counter(state):
    cx, cy = COUNTER_C
    if state == "old":
        # Eski tahta kasa (dört yüzü de tahtalı) + üstünde koli: geçici "tezgâh". Dar ayak izi.
        slat = mat("slat", "#C4A27C", rough=0.85, tone_jitter=0.18, noise=0.3)
        w, d, h = 0.58, 0.5, 0.56
        for k in range(4):
            z = 0.08 + k * 0.14
            rbox((cx, cy - d * 0.5, z), (w, 0.04, 0.115), 0.02, slat, segments=3, name="Slat")
            rbox((cx, cy + d * 0.5, z), (w, 0.04, 0.115), 0.02, slat, segments=3, name="Slat")
            rbox((cx - w * 0.5, cy, z), (0.04, d, 0.115), 0.02, slat, segments=3, name="Slat")
            rbox((cx + w * 0.5, cy, z), (0.04, d, 0.115), 0.02, slat, segments=3, name="Slat")
        for sx in (-w * 0.5, w * 0.5):
            for sy in (-d * 0.5, d * 0.5):
                rbox((cx + sx, cy + sy, h * 0.5), (0.065, 0.065, h), 0.02, slat, segments=3, name="Post")
        rbox((cx, cy, h + 0.02), (w + 0.05, d + 0.04, 0.04), 0.015, slat, segments=3, name="Lid")
        card = mat("card", CARDBOARD, rough=0.85, tone_jitter=0.12)
        rbox((cx + 0.02, cy, h + 0.22), (0.4, 0.32, 0.36), 0.04, card, segments=4, rot=(0, 0, -8))
        return
    w, d, h = 0.56, 0.55, 0.9
    body = mat("counter_%d" % state, COUNTER_COLORS[state], rough=0.45, coat=0.4)
    rbox((cx, cy, h * 0.5), (w, d, h - 0.06), 0.06, body, segments=6, name="Cabinet")
    knob = mat("knob", "#F0C66B", rough=0.25, metallic=0.8, coat=0.5)
    slab(rounded_rect(cx - w * 0.38, 0.12, cx + w * 0.38, h - 0.3, 0.06), 0.03, 0.012, body,
         y=cy - d * 0.5 - 0.01, name="CPanel")
    sphere((cx + w * 0.26, cy - d * 0.5 - 0.05, h - 0.4), (0.03, 0.03, 0.03), knob)
    slab(rounded_rect(cx - w * 0.38, h - 0.25, cx + w * 0.38, h - 0.1, 0.05), 0.03, 0.012, body,
         y=cy - d * 0.5 - 0.01, name="CDrawer")
    sphere((cx, cy - d * 0.5 - 0.05, h - 0.175), (0.035, 0.03, 0.03), knob)
    top = mat("countertop", WOOD_OAK, rough=0.4, coat=0.4)
    rbox((cx, cy - 0.02, h), (w + 0.06, d + 0.08, 0.08), 0.035, top, segments=5, name="Top")
    # Üstte katlanmış çamaşır yığını + küçük zil.
    for k, hexc in enumerate(TOWEL_SETS[state][:3]):
        tm = mat("ctowel_%d_%d" % (state, k), hexc, rough=0.9, sheen=0.8)
        rbox((cx - 0.07 + (k % 2) * 0.02, cy - 0.04, h + 0.075 + k * 0.07), (0.3, 0.26, 0.07), 0.032, tm,
             segments=6, name="CTowel")
    bell = mat("bell", "#F0C66B", rough=0.2, metallic=0.85, coat=0.5)
    dome((cx + 0.17, cy - 0.14, h + 0.05), 0.075, 0.07, bell, thickness=0.01, name="Bell")
    sphere((cx + 0.17, cy - 0.14, h + 0.14), (0.02, 0.02, 0.02), bell)
    rcyl((cx + 0.17, cy - 0.14, h + 0.05), 0.09, 0.02, 0.008, mat("bellbase", "#FFFFFF", rough=0.3))


BUILDERS = {
    "floor": build_floor, "wall": build_wall, "window": build_window, "door": build_door,
    "sign": build_sign, "shelf": build_shelf, "lamp": build_lamp, "machine1": build_machine1,
    "machine2": build_machine2, "plant": build_plant, "rug": build_rug, "counter": build_counter,
}


def shadow_catchers():
    """Görünmez duvar + zemin: eşyanın gölgesini yakalar (katmana yarı saydam siyah yazılır)."""
    catcher = mat("catcher", "#FFFFFF", rough=0.9)
    floor = rbox((0.0, -4.0, -0.05), (12.0, 9.0, 0.1), 0.0, catcher, segments=1, name="FloorCatcher")
    wall = rbox((0.0, 0.15, 3.0), (12.0, 0.3, 6.0), 0.0, catcher, segments=1, name="WallCatcher")
    for obj in (floor, wall):
        obj.is_shadow_catcher = True


# ---------------------------------------------------------------------------- render + kırpma

def layer_states(slot):
    states = [] if slot in NO_OLD else ["old"]
    return states + [0, 1, 2]


def layer_name(slot, state):
    return "room_%s_%s" % (slot, state)


def crop_and_save(raw_path, out_path):
    """Render'ı okuyup saydam kenarları kırpar; tuvaldeki [x, y, w, h] döner (tam çözünürlükte)."""
    img = bpy.data.images.load(raw_path)
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(h, w, 4)[::-1].copy()  # Blender alttan başlar; tuval üstten
    alpha = px[:, :, 3]
    catcher = px[:, :, :3].max(axis=2) < CATCHER_RGB
    lifted = np.clip((alpha - VEIL_ALPHA) / (1.0 - VEIL_ALPHA), 0.0, 1.0)
    alpha[catcher] = lifted[catcher]
    px[:, :, 3] = alpha
    mask = alpha > (CROP_ALPHA / 255.0)
    if not mask.any():
        bpy.data.images.remove(img)
        return None
    rows = np.where(mask.sum(axis=1) >= CROP_MIN_PIXELS)[0]
    cols = np.where(mask.sum(axis=0) >= CROP_MIN_PIXELS)[0]
    if rows.size == 0 or cols.size == 0:
        bpy.data.images.remove(img)
        return None
    y0 = max(int(rows[0]) - CROP_PAD, 0)
    y1 = min(int(rows[-1]) + CROP_PAD + 1, h)
    x0 = max(int(cols[0]) - CROP_PAD, 0)
    x1 = min(int(cols[-1]) + CROP_PAD + 1, w)
    # Boyutlar 4'ün katına büyütülür: VRAM sıkıştırma (ASTC/BPTC 4x4 blok) 4'ün katı olmayan
    # dokuyu YENİDEN ÖLÇEKLER (bulanıklaşır). Dikey pay üstten (zemin alt şeridi ve alt pivot
    # korunur), yatay pay sağdan (tuval kenarındaysa soldan) eklenir.
    grow_y = (-(y1 - y0)) % BLOCK
    if y0 - grow_y >= 0:
        y0 -= grow_y
    else:
        y1 = min(y1 + grow_y, h)
    grow_x = (-(x1 - x0)) % BLOCK
    if x1 + grow_x <= w:
        x1 += grow_x
    else:
        x0 = max(x0 - grow_x, 0)
    crop =np.ascontiguousarray(px[y0:y1, x0:x1][::-1])
    out = bpy.data.images.new("crop", x1 - x0, y1 - y0, alpha=True)
    out.pixels.foreach_set(crop.ravel())
    out.filepath_raw = out_path
    out.file_format = "PNG"
    out.save()
    bpy.data.images.remove(out)
    bpy.data.images.remove(img)
    scale = CANVAS_W / w
    return [round(x0 * scale), round(y0 * scale), round((x1 - x0) * scale), round((y1 - y0) * scale)]


def render_layer(slot, state, manifest):
    reset()
    if slot not in ("floor", "wall"):
        shadow_catchers()
    BUILDERS[slot](state)
    if slot in NO_SHADOW:
        # Tavandan sarkan lamba duvardan uzakta: güneş gölgesi duvarda "kir lekesi" gibi
        # kopuk bir bulanıklık bırakıyordu; lambanın katmanı yalnız kendisini taşır.
        for obj in bpy.context.scene.objects:
            if obj.type == "MESH" and not obj.is_shadow_catcher:
                obj.visible_shadow = False
    name = layer_name(slot, state)
    raw_dir = os.path.join(ROOT, "build", "meta_raw")
    os.makedirs(raw_dir, exist_ok=True)
    os.makedirs(OUT_DIR, exist_ok=True)
    raw = os.path.join(raw_dir, name + ".png")
    bpy.context.scene.render.filepath = raw
    bpy.ops.render.render(write_still=True)
    rect = crop_and_save(raw, os.path.join(OUT_DIR, name + ".png"))
    if rect is None:
        manifest["layers"].pop(name, None)
    else:
        manifest["layers"][name] = rect
    print("katman:", name, rect)


def compose(mode):
    """Tüm odayı tek karede kur (yerleşim/uyum kontrolü; çıktı build/meta_preview)."""
    reset()
    for index, slot in enumerate(SLOTS):
        if mode == "half":
            state = 0 if index % 2 == 0 else "old"
        elif mode == "old":
            state = "old"
        else:
            state = int(mode)
        if state == "old" and slot in NO_OLD:
            continue
        BUILDERS[slot](state)
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    path = os.path.join(PREVIEW_DIR, "compose_%s.png" % mode)
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("yazıldı:", os.path.relpath(path, ROOT))


def anchors():
    """Oyunun efektleri için tuval noktaları: ampul (ışık halesi), pencere (toz zerreleri)."""
    x, y, z = LAMP_POS
    wx0, wy0 = screen(WIN_X0, 0.0, WIN_Z1)
    wx1, wy1 = screen(WIN_X1, 0.0, WIN_Z0)
    return {"lamp_bulb": list(screen(x, y, z - 0.08)), "window": [wx0, wy0, wx1 - wx0, wy1 - wy0]}


def main():
    if COMPOSE:
        compose(COMPOSE)
        return
    manifest = {"canvas": [CANVAS_W, CANVAS_H], "layers": {}}
    if os.path.exists(MANIFEST):
        with open(MANIFEST) as handle:
            try:
                manifest = json.load(handle)
            except ValueError:
                pass
    manifest.setdefault("layers", {})
    manifest["anchors"] = anchors()
    if "--recrop" in ARGV:
        # Yeniden render etmeden kırpma/peçe ayarını uygula (build/meta_raw'daki ham karelerden).
        raw_dir = os.path.join(ROOT, "build", "meta_raw")
        for slot in SLOTS:
            for state in layer_states(slot):
                name = layer_name(slot, state)
                raw = os.path.join(raw_dir, name + ".png")
                if os.path.exists(raw):
                    manifest["layers"][name] = crop_and_save(raw, os.path.join(OUT_DIR, name + ".png"))
                    print("kırpıldı:", name, manifest["layers"][name])
        with open(MANIFEST, "w") as handle:
            json.dump(manifest, handle, indent=1, sort_keys=True)
        return
    if "--anchors" in ARGV:
        with open(MANIFEST, "w") as handle:
            json.dump(manifest, handle, indent=1, sort_keys=True)
        return
    for slot in SLOTS:
        for state in layer_states(slot):
            name = layer_name(slot, state)
            if WANTED and slot not in WANTED and name.replace("room_", "") not in WANTED:
                continue
            render_layer(slot, state, manifest)
            with open(MANIFEST, "w") as handle:
                json.dump(manifest, handle, indent=1, sort_keys=True)


main()
