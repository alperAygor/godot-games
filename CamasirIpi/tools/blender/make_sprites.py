#!/usr/bin/env python3
"""Çamaşır İpi — sprite üretici (Blender, headless). Kaynak = bu betik; PNG'ler çıktıdır.

    /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/make_sprites.py
    ... -- garment_tshirt pin        # yalnız adı verilenler

Kural 1 (kullanıcı): low-poly yok. Her şekil 2B dış hattan doldurulur, kalınlık verilir,
voxel remesh + yumuşatma ile pürüzsüzleşir, sonra asılı kumaş kıvrımları eklenir.
Çamaşırlar NÖTR BEYAZ render edilir; oyun rengi çarpımla verir.
"""

import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_DIR = os.path.join(ROOT, "assets", "sprites")
VOXEL = 0.011
THICKNESS = 0.05


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    for engine in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
        try:
            scene.render.engine = engine
            break
        except TypeError:
            continue
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    world = bpy.data.worlds.new("World")
    scene.world = world
    world.use_nodes = True
    background = world.node_tree.nodes["Background"]
    background.inputs[0].default_value = (1.0, 1.0, 1.0, 1.0)
    background.inputs[1].default_value = 0.36
    return scene


def add_lights():
    def light(name, kind, energy, location, rotation, size=None):
        data = bpy.data.lights.new(name, kind)
        data.energy = energy
        if size is not None and kind == "AREA":
            data.size = size
        if kind == "SUN":
            data.angle = math.radians(25.0)
        obj = bpy.data.objects.new(name, data)
        obj.location = location
        obj.rotation_euler = rotation
        bpy.context.scene.collection.objects.link(obj)
        return obj
    # Anahtar ışık sol-üst-önden: kıvrımların bir yanı aydınlık, diğer yanı yumuşak gölge.
    light("Key", "SUN", 1.9, (0, 0, 0), (math.radians(68), 0, math.radians(-62)))
    light("Fill", "AREA", 16.0, (1.6, -2.5, -0.2), (math.radians(80), 0, math.radians(30)), 4.0)


def add_camera(center_z, ortho_scale, res_x, res_y, tilt_deg=0.0):
    data = bpy.data.cameras.new("Cam")
    data.type = "ORTHO"
    data.ortho_scale = ortho_scale
    obj = bpy.data.objects.new("Cam", data)
    tilt = math.radians(tilt_deg)
    obj.location = (0.0, -6.0 * math.cos(tilt), center_z + 6.0 * math.sin(tilt))
    obj.rotation_euler = (math.radians(90.0) - tilt, 0.0, 0.0)
    scene = bpy.context.scene
    scene.collection.objects.link(obj)
    scene.camera = obj
    scene.render.resolution_x = res_x
    scene.render.resolution_y = res_y
    scene.render.resolution_percentage = 100


def material(name, color, roughness=0.85, weave=0.0, metallic=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if weave > 0.0:
        # İnce dokuma hissi: çok küçük ölçekli gürültüyle kabartma.
        nodes, links = mat.node_tree.nodes, mat.node_tree.links
        noise = nodes.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = 260.0
        noise.inputs["Detail"].default_value = 2.0
        bump = nodes.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = weave
        bump.inputs["Distance"].default_value = 0.01
        links.new(noise.outputs["Fac"], bump.inputs["Height"])
        links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


def mirror(points):
    """Sağ yarı (x>=0, saat yönünde yukarıdan aşağı) -> tam kapalı dış hat."""
    left = [(-x, z) for x, z in reversed(points) if x > 1e-6]
    return points + left


def flat_shape(name, outline, thickness, y_offset=0.0):
    """XZ düzleminde dış hattı doldurur, Y yönünde kalınlık verir."""
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "2D"
    curve.fill_mode = "BOTH"
    spline = curve.splines.new("POLY")
    spline.points.add(len(outline) - 1)
    for point, (x, z) in zip(spline.points, outline):
        point.co = (x, z, 0.0, 1.0)
    spline.use_cyclic_u = True
    obj = bpy.data.objects.new(name, curve)
    bpy.context.scene.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    obj = bpy.context.view_layer.objects.active
    # Eğri XY'de doldurulur; dik durması için X ekseninde 90° döndürülür (Y -> Z).
    obj.rotation_euler = (math.radians(90.0), 0.0, 0.0)
    bpy.ops.object.transform_apply(rotation=True)
    solid = obj.modifiers.new("Solid", "SOLIDIFY")
    solid.thickness = thickness
    solid.offset = 0.0
    bpy.ops.object.modifier_apply(modifier="Solid")
    obj.location.y = y_offset
    bpy.ops.object.transform_apply(location=True)
    obj.select_set(False)
    return obj


def join(objects, name):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    if len(objects) > 1:
        bpy.ops.object.join()
    result = bpy.context.view_layer.objects.active
    result.name = name
    return result


def soften(obj, voxel=VOXEL, smooth_repeat=10):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    remesh = obj.modifiers.new("Remesh", "REMESH")
    remesh.mode = "VOXEL"
    remesh.voxel_size = voxel
    bpy.ops.object.modifier_apply(modifier="Remesh")
    smooth = obj.modifiers.new("Smooth", "SMOOTH")
    smooth.factor = 0.7
    smooth.iterations = smooth_repeat
    bpy.ops.object.modifier_apply(modifier="Smooth")
    bpy.ops.object.shade_smooth()
    return obj


def drape(obj, folds=3.2, amplitude=0.035, seed=0.0):
    """Asılı kumaş: üstte (ip) düz, aşağı indikçe derinleşen dikey kıvrımlar + hafif eğim."""
    mesh = obj.data
    bm = bmesh.new()
    bm.from_mesh(mesh)
    top = max(v.co.z for v in bm.verts)
    bottom = min(v.co.z for v in bm.verts)
    height = max(top - bottom, 1e-6)
    for v in bm.verts:
        t = (top - v.co.z) / height
        ease = t * t * (3.0 - 2.0 * t)
        wave = math.sin(v.co.x * folds * math.tau + seed + t * 1.3)
        wave += 0.45 * math.sin(v.co.x * folds * 2.3 * math.tau + seed * 1.7 + t * 2.1)
        v.co.y += amplitude * ease * wave
        # Alt kenar hafif dalgalı: kumaş ağırlığı hissi.
        v.co.z += 0.012 * ease * math.sin(v.co.x * folds * math.tau * 1.4 + seed)
        v.co.x *= 1.0 - 0.035 * ease * (0.5 + 0.5 * math.sin(seed + v.co.z * 4.0))
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()


def render(name, res_x, res_y):
    path = os.path.join(OUT_DIR, name + ".png")
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("yazıldı:", os.path.relpath(path, ROOT))


def rect(x0, x1, z0, z1):
    return [(x0, z1), (x1, z1), (x1, z0), (x0, z0)]


def arc_band(radius_x, radius_z, width, center_z, start_deg, end_deg, steps=14):
    """Yaka gibi yay şerit: dış yay + iç yay."""
    outer, inner = [], []
    for step in range(steps + 1):
        angle = math.radians(start_deg + (end_deg - start_deg) * step / steps)
        outer.append((radius_x * math.cos(angle), center_z + radius_z * math.sin(angle)))
        inner.append(((radius_x - width) * math.cos(angle),
                      center_z + (radius_z - width) * math.sin(angle)))
    return outer + list(reversed(inner))


# Dış hatlar: x sağa, z yukarı; ipe tutunan üst kenar z = 0; genişlik ~1 birim.
GARMENTS = {
    "garment_tshirt": {
        "outline": mirror([(0.0, -0.09), (0.09, -0.05), (0.15, 0.0), (0.33, -0.02), (0.55, -0.2),
                           (0.47, -0.37), (0.33, -0.28), (0.345, -0.94), (0.0, -0.96)]),
        "extras": [arc_band(0.17, 0.12, 0.035, 0.015, 198, 342)],
        "folds": 2.6,
    },
    "garment_pants": {
        "outline": [(-0.31, 0.0), (0.31, 0.0), (0.345, -0.98), (0.07, -0.98), (0.0, -0.36),
                    (-0.07, -0.98), (-0.345, -0.98)],
        "extras": [rect(-0.315, 0.315, -0.075, 0.0), rect(0.12, 0.26, -0.3, -0.16)],
        "folds": 3.4,
    },
    "garment_dress": {
        "outline": mirror([(0.0, -0.1), (0.1, -0.03), (0.13, 0.0), (0.22, 0.0), (0.27, -0.24),
                           (0.22, -0.42), (0.47, -0.97), (0.0, -1.0)]),
        "extras": [rect(-0.225, 0.225, -0.45, -0.39)],
        "folds": 3.8,
    },
    "garment_towel": {
        "outline": rect(-0.39, 0.39, -0.95, 0.0),
        "extras": [rect(-0.39, 0.39, -0.8, -0.74), rect(-0.39, 0.39, -0.7, -0.67)],
        "folds": 2.2,
    },
    "garment_shorts": {
        "outline": [(-0.33, 0.0), (0.33, 0.0), (0.4, -0.58), (0.06, -0.58), (0.0, -0.3),
                    (-0.06, -0.58), (-0.4, -0.58)],
        "extras": [rect(-0.335, 0.335, -0.08, 0.0)],
        "folds": 3.0,
    },
    "garment_sweater": {
        "outline": mirror([(0.0, -0.08), (0.09, -0.04), (0.14, 0.0), (0.32, -0.02), (0.6, -0.7),
                           (0.47, -0.77), (0.33, -0.32), (0.335, -0.9), (0.0, -0.92)]),
        "extras": [arc_band(0.16, 0.11, 0.045, 0.015, 198, 342), rect(-0.335, 0.335, -0.92, -0.84)],
        "folds": 2.4,
    },
    "garment_sock": {
        "outline": [(-0.14, 0.0), (0.14, 0.0), (0.15, -0.5), (0.36, -0.68), (0.42, -0.82),
                    (0.36, -0.94), (0.2, -0.97), (-0.02, -0.93), (-0.13, -0.78)],
        "extras": [rect(-0.145, 0.145, -0.12, 0.0)],
        "folds": 1.2,
    },
}


def make_garment(name, spec, index):
    reset()
    add_lights()
    cloth = material("Cloth", (0.93, 0.93, 0.93), 0.9, weave=0.06)
    parts = [flat_shape(name, spec["outline"], THICKNESS)]
    for extra_index, extra in enumerate(spec.get("extras", [])):
        parts.append(flat_shape("%s_x%d" % (name, extra_index), extra, THICKNESS + 0.07))
    obj = join(parts, name)
    soften(obj)
    drape(obj, spec.get("folds", 3.0), 0.072, seed=index * 1.9)
    obj.data.materials.clear()
    obj.data.materials.append(cloth)
    # Kadraj: üst kenar tuvalin üstüne yakın; nesne tuvale sığacak ölçek.
    add_camera(center_z=-0.5, ortho_scale=1.26, res_x=768, res_y=768)
    render(name, 768, 768)


def make_folded():
    reset()
    add_lights()
    cloth = material("Cloth", (0.93, 0.93, 0.93), 0.9, weave=0.06)
    layers = []
    for layer in range(3):
        z = -0.09 * layer
        half = 0.36 - 0.012 * layer
        piece = flat_shape("fold%d" % layer, rect(-half, half, z - 0.07, z), 0.5, y_offset=0.0)
        # Katlar ayrı yumuşatılır: aralarındaki çizgi (kat izi) görünür kalır.
        layers.append(soften(piece, voxel=0.012, smooth_repeat=14))
    obj = join(layers, "folded")
    obj.data.materials.append(cloth)
    add_camera(center_z=-0.12, ortho_scale=0.95, res_x=256, res_y=256, tilt_deg=38.0)
    render("folded", 256, 256)


def make_pin():
    reset()
    add_lights()
    wood = material("Wood", (0.82, 0.62, 0.38), 0.6)
    metal = material("Metal", (0.75, 0.77, 0.8), 0.3, metallic=0.9)
    prongs = []
    for side in (-1.0, 1.0):
        outline = [(side * 0.02, 0.0), (side * 0.11, 0.0), (side * 0.12, -0.55), (side * 0.07, -0.86),
                   (side * 0.02, -0.9), (side * 0.035, -0.5)]
        if side < 0:
            outline = list(reversed(outline))
        prongs.append(flat_shape("prong", outline, 0.16))
    body = join(prongs, "pin")
    soften(body, voxel=0.009, smooth_repeat=8)
    body.data.materials.append(wood)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.105, minor_radius=0.022, location=(0, 0, -0.34),
                                     rotation=(math.radians(90), 0, 0), major_segments=64,
                                     minor_segments=24)
    ring = bpy.context.view_layer.objects.active
    ring.scale = (1.0, 1.0, 0.8)
    bpy.ops.object.shade_smooth()
    ring.data.materials.append(metal)
    add_camera(center_z=-0.45, ortho_scale=1.0, res_x=128, res_y=256)
    bpy.context.scene.camera.data.ortho_scale = 1.0
    render("pin", 128, 256)


def basket_parts():
    """Sepet gövdesi: yukarı doğru genişleyen yuvarlak gövde + örgü halkaları + ağız bandı."""
    wicker = material("Wicker", (0.9, 0.78, 0.58), 0.75, weave=0.12)
    bpy.ops.mesh.primitive_cylinder_add(vertices=96, radius=0.42, depth=0.6, location=(0, 0, 0))
    body = bpy.context.view_layer.objects.active
    for v in body.data.vertices:
        t = (v.co.z + 0.3) / 0.6
        scale = 0.78 + 0.22 * t
        v.co.x *= scale
        v.co.y *= scale
    bevel = body.modifiers.new("Bevel", "BEVEL")
    bevel.width = 0.07
    bevel.segments = 8
    bpy.ops.object.modifier_apply(modifier="Bevel")
    bpy.ops.object.shade_smooth()
    body.data.materials.append(wicker)
    rings = [body]
    for row in range(10):
        z = -0.25 + 0.05 * row
        radius = 0.42 * (0.78 + 0.22 * ((z + 0.3) / 0.6)) + 0.004
        bpy.ops.mesh.primitive_torus_add(major_radius=radius, minor_radius=0.021, location=(0, 0, z),
                                         major_segments=96, minor_segments=20)
        ring = bpy.context.view_layer.objects.active
        bpy.ops.object.shade_smooth()
        ring.data.materials.append(wicker)
        rings.append(ring)
    band_mat = material("Band", (0.93, 0.93, 0.93), 0.85, weave=0.05)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.435, minor_radius=0.06, location=(0, 0, 0.3),
                                     major_segments=96, minor_segments=32)
    band = bpy.context.view_layer.objects.active
    band.scale = (1.0, 1.0, 1.25)
    bpy.ops.object.shade_smooth()
    band.data.materials.append(band_mat)
    # İç boşluk: koyu disk, sepetin içi dolu görünmesin.
    inner_mat = material("Inner", (0.55, 0.45, 0.32), 0.9)
    bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=0.4, depth=0.02, location=(0, 0, 0.27))
    inner = bpy.context.view_layer.objects.active
    inner.data.materials.append(inner_mat)
    return rings + [inner], band


def make_basket():
    for target in ("basket_body", "basket_band"):
        reset()
        add_lights()
        body_parts, band = basket_parts()
        if target == "basket_body":
            band.hide_render = True
        else:
            for part in body_parts:
                # Bant, gövdenin kapattığı yerlerde de doğru kesilsin: gövde "holdout" olur.
                part.is_holdout = True
        add_camera(center_z=0.03, ortho_scale=1.12, res_x=512, res_y=512, tilt_deg=24.0)
        render(target, 512, 512)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    wanted = set(argv)
    for index, (name, spec) in enumerate(GARMENTS.items()):
        if not wanted or name in wanted:
            make_garment(name, spec, index)
    if not wanted or "folded" in wanted:
        make_folded()
    if not wanted or "pin" in wanted:
        make_pin()
    if not wanted or wanted & {"basket_body", "basket_band"}:
        make_basket()


main()
