#!/usr/bin/env python3
"""Çamaşır İpi — makine ve misafir sprite'ları (Blender, headless, Cycles). Kaynak = bu betik.

    /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/make_machines.py
    ... -- washer dryer glass        # yalnız adı verilenler
    ... -- icons                      # yalnız siluetler (render yok; mevcut PNG'lerden)

Çıktılar (assets/sprites/machines, assets/sprites/critters):
  machine_washer.png / machine_dryer.png  gövde + kapak yuvası + koyu tambur (cam YOK)
  machine_glass.png                        kapak halkası + cam (gövdeyle aynı kadraj; üstte çizilir)
  overlay_mud.png / overlay_birdmess.png  çamaşırın üstüne konan alfa lekeler
  bird_idle.png / bird_flap.png            tombul kuş, iki kanat pozu
  cloud.png / drop.png                     yağmur bulutu + damla
  cat_sleep.png / cat_awake.png            sepete sığan kıvrılmış kedi + uyanık poz
  icon_*.png, kind_*.png                   beyaz siluetler (HUD hapı, türlü sepet rozeti)

Kural (kullanıcı): low-poly yok; pürüzsüz, dolgun, pastel; mevcut sprite'larla aynı ışık dili.
Oyundaki yerleşim sabitleri (kapak merkezi/yarıçapı) MACHINE_* sabitlerinden hesaplanır ve
scripts/game/machines/machine_view.gd içinde oran olarak durur: kadraj değişirse ikisi birlikte.
"""

import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MACHINE_DIR = os.path.join(ROOT, "assets", "sprites", "machines")
CRITTER_DIR = os.path.join(ROOT, "assets", "sprites", "critters")
GARMENT_DIR = os.path.join(ROOT, "assets", "sprites")
SAMPLES = 160

# Makine kadrajı: 448x512, dikey açıklık MACHINE_ORTHO. Gövde tabanı z=0.
MACHINE_W, MACHINE_H = 448, 512
MACHINE_ORTHO = 1.36
MACHINE_CENTER_Z = 0.6
BODY_W, BODY_D, BODY_H = 1.0, 0.78, 1.08
BODY_Z0 = 0.06
DOOR_Z = 0.5
DOOR_R = 0.3
FRONT_Y = -BODY_D * 0.5

# Siluet boyutları (piksel, kare tuval).
ICON_SIZE = 96
KIND_SIZE = 128
# Leke kadrajı: leke tuvali doldursun (oyunda çamaşır boyuna göre ölçeklenir).
OVERLAY_ORTHO = 0.82
KINDS = ["tshirt", "pants", "dress", "towel", "shorts", "sweater", "sock"]


def lin(hex_color):
    h = hex_color.lstrip("#")
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return tuple(out)


# ----------------------------------------------------------------------------- sahne

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
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
    scene.cycles.max_bounces = 8
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    world = bpy.data.worlds.new("World")
    scene.world = world
    world.use_nodes = True
    background = world.node_tree.nodes["Background"]
    background.inputs[0].default_value = (1.0, 1.0, 1.0, 1.0)
    background.inputs[1].default_value = 0.42
    add_lights()
    return scene


def add_lights(key=2.2, fill=0.4, rim=1.4):
    """Çamaşır sprite'larıyla aynı ışık dili: sol-üst anahtar, sağ dolgu, arka-üst rim."""
    def sun(name, energy, toward_light, angle):
        data = bpy.data.lights.new(name, "SUN")
        data.energy = energy
        data.angle = math.radians(angle)
        obj = bpy.data.objects.new(name, data)
        obj.rotation_euler = Vector(toward_light).normalized().to_track_quat("Z", "Y").to_euler()
        bpy.context.scene.collection.objects.link(obj)
    sun("Key", key, (-0.62, -0.62, 0.62), 32.0)
    sun("Fill", fill, (0.75, -0.6, -0.15), 60.0)
    sun("Rim", rim, (0.3, 0.75, 0.6), 18.0)


def camera(center_z, ortho, res_x, res_y, tilt_deg=0.0, center_x=0.0):
    data = bpy.data.cameras.new("Cam")
    data.type = "ORTHO"
    data.ortho_scale = ortho
    obj = bpy.data.objects.new("Cam", data)
    tilt = math.radians(tilt_deg)
    dist = 8.0
    obj.location = (center_x, -dist * math.cos(tilt), center_z + dist * math.sin(tilt))
    obj.rotation_euler = (math.radians(90.0) - tilt, 0.0, 0.0)
    scene = bpy.context.scene
    scene.collection.objects.link(obj)
    scene.camera = obj
    scene.render.resolution_x = res_x
    scene.render.resolution_y = res_y
    scene.render.resolution_percentage = 100


def render(directory, name):
    os.makedirs(directory, exist_ok=True)
    path = os.path.join(directory, name + ".png")
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("yazıldı:", os.path.relpath(path, ROOT))
    return path


# ----------------------------------------------------------------------------- malzeme / geometri

def mat(name, color, rough=0.45, coat=0.0, metallic=0.0, sheen=0.0, transmission=0.0, spec=0.4,
        emission=None, emission_strength=0.0, subsurface=0.0, alpha=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*lin(color), 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metallic
    for sock_name, value in (("Coat Weight", coat), ("Sheen Weight", sheen), ("Transmission Weight", transmission),
                             ("Specular IOR Level", spec), ("Subsurface Weight", subsurface), ("Alpha", alpha)):
        if sock_name in bsdf.inputs:
            bsdf.inputs[sock_name].default_value = value
    if subsurface > 0.0 and "Subsurface Radius" in bsdf.inputs:
        bsdf.inputs["Subsurface Radius"].default_value = (1.0, 0.6, 0.45)
        bsdf.inputs["Subsurface Scale"].default_value = 0.05
    if emission is not None:
        bsdf.inputs["Emission Color"].default_value = (*lin(emission), 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission_strength
    return m


def gradient_mat(name, bottom, top, rough=0.7, sheen=0.4, z0=-0.5, z1=0.5, subsurface=0.0):
    """Nesne Z'sine göre iki renkli yumuşak geçiş (bulut: açık üst, gri alt)."""
    m = mat(name, bottom, rough=rough, sheen=sheen, subsurface=subsurface)
    nodes, links = m.node_tree.nodes, m.node_tree.links
    texco = nodes.new("ShaderNodeTexCoord")
    sep = nodes.new("ShaderNodeSeparateXYZ")
    links.new(texco.outputs["Object"], sep.inputs[0])
    remap = nodes.new("ShaderNodeMapRange")
    remap.inputs["From Min"].default_value = z0
    remap.inputs["From Max"].default_value = z1
    links.new(sep.outputs["Z"], remap.inputs["Value"])
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = "EASE"
    ramp.color_ramp.elements[0].color = (*lin(bottom), 1.0)
    ramp.color_ramp.elements[1].color = (*lin(top), 1.0)
    links.new(remap.outputs["Result"], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], m.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
    return m


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


def smooth(obj, levels=2):
    activate(obj)
    if levels > 0:
        sub = obj.modifiers.new("Sub", "SUBSURF")
        sub.levels = levels
        sub.render_levels = levels
        bpy.ops.object.modifier_apply(modifier=sub.name)
    bpy.ops.object.shade_smooth()
    return obj


def rbox(center, size, bevel, material, segments=10, name="Box"):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=center)
    obj = bpy.context.view_layer.objects.active
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(scale=True)
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = min(bevel, min(size) * 0.49)
    mod.segments = segments
    mod.limit_method = "NONE"
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.ops.object.shade_smooth()
    return assign(obj, material)


def rcyl(center, radius, depth, bevel, material, axis="Y", verts=96, name="Cyl"):
    rot = {"Z": (0.0, 0.0, 0.0), "Y": (math.radians(90.0), 0.0, 0.0), "X": (0.0, math.radians(90.0), 0.0)}[axis]
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=center, rotation=rot)
    obj = bpy.context.view_layer.objects.active
    obj.name = name
    if bevel > 0.0:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = min(bevel, radius * 0.49, depth * 0.49)
        mod.segments = 6
        mod.limit_method = "NONE"
        bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.ops.object.shade_smooth()
    return assign(obj, material)


def sphere(center, scale, material, rot=(0.0, 0.0, 0.0), name="Sphere"):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=96, ring_count=48, radius=1.0, location=center,
                                         rotation=[math.radians(r) for r in rot])
    obj = bpy.context.view_layer.objects.active
    obj.name = name
    obj.scale = scale
    bpy.ops.object.shade_smooth()
    return assign(obj, material)


def torus(center, major, minor, material, axis="Y", name="Torus"):
    rot = {"Z": (0.0, 0.0, 0.0), "Y": (math.radians(90.0), 0.0, 0.0), "X": (0.0, math.radians(90.0), 0.0)}[axis]
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=128,
                                     minor_segments=40, location=center, rotation=rot)
    obj = bpy.context.view_layer.objects.active
    obj.name = name
    bpy.ops.object.shade_smooth()
    return assign(obj, material)


def tube(points, material, name="Tube", res=10):
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
    spline.resolution_u = 24
    obj = link(bpy.data.objects.new(name, curve))
    activate(obj)
    bpy.ops.object.convert(target="MESH")
    obj = bpy.context.view_layer.objects.active
    bpy.ops.object.shade_smooth()
    return assign(obj, material)


def blobs(elements, material, resolution=0.012, threshold=0.6, name="Blob"):
    """Metatop birleşimi -> pürüzsüz tek gövde (çamur, leke, bulut). elements: (x,y,z,r,(sx,sy,sz))."""
    data = bpy.data.metaballs.new(name)
    data.resolution = resolution
    data.render_resolution = resolution
    data.threshold = threshold
    for x, y, z, radius, stretch in elements:
        element = data.elements.new()
        element.type = "ELLIPSOID"
        element.co = (x, y, z)
        element.radius = radius
        element.size_x, element.size_y, element.size_z = stretch
    obj = link(bpy.data.objects.new(name, data))
    activate(obj)
    bpy.ops.object.convert(target="MESH")
    obj = bpy.context.view_layer.objects.active
    bpy.ops.object.shade_smooth()
    return assign(obj, material)


def cone(center, radius, depth, material, rot=(0.0, 0.0, 0.0), name="Cone"):
    bpy.ops.mesh.primitive_cone_add(vertices=64, radius1=radius, radius2=radius * 0.18, depth=depth,
                                    location=center, rotation=[math.radians(r) for r in rot])
    obj = bpy.context.view_layer.objects.active
    obj.name = name
    smooth(obj, 2)
    return assign(obj, material)


# ----------------------------------------------------------------------------- makineler

def _machine_frame():
    camera(MACHINE_CENTER_Z, MACHINE_ORTHO, MACHINE_W, MACHINE_H)


def _machine_body(body_hex, accent_hex, name, dryer):
    body = mat(name + "_body", body_hex, rough=0.3, coat=0.75, spec=0.45)
    accent = mat(name + "_panel", "#FFFFFF", rough=0.28, coat=0.6)
    soft = mat(name + "_soft", accent_hex, rough=0.35, coat=0.5)
    cy = 0.0
    rbox((0.0, cy, BODY_Z0 + BODY_H * 0.5), (BODY_W, BODY_D, BODY_H), 0.16, body, name=name + "Body")
    # Ayaklar: kısa, tombul.
    foot = mat(name + "_foot", "#E9E3D8", rough=0.4)
    for fx in (-BODY_W * 0.33, BODY_W * 0.33):
        rcyl((fx, cy - BODY_D * 0.2, BODY_Z0 * 0.5), 0.07, BODY_Z0 + 0.02, 0.025, foot, axis="Z")
    # Üst panel: beyaz şerit (oyunda sayaç ışıkları bunun üstüne çizilir).
    panel_z = BODY_Z0 + BODY_H - 0.15
    rbox((0.0, FRONT_Y + 0.01, panel_z), (BODY_W * 0.84, 0.07, 0.17), 0.06, accent, name=name + "Panel")
    knob = mat(name + "_knob", "#FFFFFF", rough=0.25, coat=0.6)
    rcyl((BODY_W * 0.3, FRONT_Y - 0.04, panel_z), 0.062, 0.06, 0.022, knob)
    rcyl((BODY_W * 0.3, FRONT_Y - 0.075, panel_z), 0.03, 0.02, 0.008, soft)
    if dryer:
        # Kurutucu: üstte havalandırma yarıkları + sol tarafta küçük filtre kapağı.
        vent = mat(name + "_vent", accent_hex, rough=0.45)
        for i in range(4):
            rbox((-BODY_W * 0.28 + i * 0.075, FRONT_Y - 0.03, panel_z), (0.035, 0.03, 0.09), 0.015, vent,
                 segments=4, name="Vent")
        rbox((0.0, FRONT_Y - 0.005, BODY_Z0 + 0.1), (BODY_W * 0.5, 0.03, 0.06), 0.025, soft, segments=4, name="Lint")
    else:
        rbox((-BODY_W * 0.25, FRONT_Y - 0.02, panel_z), (0.24, 0.04, 0.09), 0.03, soft, segments=4, name="Drawer")
    # Kapak yuvası: halkanın oturduğu açık renk çanak + koyu tambur (camdan görünecek iç).
    lip = mat(name + "_lip", "#F3F1EC", rough=0.35, coat=0.4)
    rcyl((0.0, FRONT_Y - 0.01, DOOR_Z), DOOR_R + 0.07, 0.05, 0.02, lip, name=name + "Lip")
    drum = mat(name + "_drum", "#4E6670" if not dryer else "#6A5A66", rough=0.5, metallic=0.35)
    drum_obj = rcyl((0.0, FRONT_Y - 0.03, DOOR_Z), DOOR_R + 0.005, 0.03, 0.0, drum, name=name + "Drum")
    # Düz gölgeleme: yumuşatılmış kapak kubbe gibi parlıyordu; iç düz ve derin okunmalı.
    activate(drum_obj)
    bpy.ops.object.shade_flat()
    shade = mat(name + "_shade", "#2F3F46" if not dryer else "#45394A", rough=0.6)
    torus((0.0, FRONT_Y - 0.04, DOOR_Z), DOOR_R - 0.005, 0.02, shade)
    # Tamburun deliklerini ima eden çok hafif iç halka (cam altında derinlik).
    inner = mat(name + "_inner", "#7F959E" if not dryer else "#8E7F8A", rough=0.45, metallic=0.4)
    torus((0.0, FRONT_Y - 0.045, DOOR_Z), DOOR_R - 0.03, 0.012, inner)


def build_washer():
    reset()
    _machine_frame()
    _machine_body("#A7DCC9", "#7FC4A4", "washer", False)
    render(MACHINE_DIR, "machine_washer")


def build_dryer():
    reset()
    _machine_frame()
    _machine_body("#F6C9B4", "#E99A7B", "dryer", True)
    render(MACHINE_DIR, "machine_dryer")


def build_glass():
    """Halka + cam: gövdeyle aynı kadraj. Cam saydamlığı alfaya yazılır (film_transparent_glass)."""
    reset()
    scene = bpy.context.scene
    scene.cycles.film_transparent_glass = True
    _machine_frame()
    ring = mat("ring", "#EEF2F4", rough=0.16, metallic=0.85, coat=0.5)
    torus((0.0, FRONT_Y - 0.07, DOOR_Z), DOOR_R + 0.03, 0.055, ring, name="Ring")
    glass = bpy.data.materials.new("glass")
    glass.use_nodes = True
    nodes, links = glass.node_tree.nodes, glass.node_tree.links
    for node in list(nodes):
        if node.type != "OUTPUT_MATERIAL":
            nodes.remove(node)
    out = [n for n in nodes if n.type == "OUTPUT_MATERIAL"][0]
    # Cam: hafif mavi saydamlık + parlak yansıma; alttaki çamaşırlar okunur kalsın.
    transparent = nodes.new("ShaderNodeBsdfTransparent")
    transparent.inputs["Color"].default_value = (*lin("#E6F4FA"), 1.0)
    glossy = nodes.new("ShaderNodeBsdfGlossy")
    glossy.inputs["Roughness"].default_value = 0.05
    fresnel = nodes.new("ShaderNodeLayerWeight")
    fresnel.inputs["Blend"].default_value = 0.35
    mix = nodes.new("ShaderNodeMixShader")
    links.new(fresnel.outputs["Fresnel"], mix.inputs["Fac"])
    links.new(transparent.outputs[0], mix.inputs[1])
    links.new(glossy.outputs[0], mix.inputs[2])
    links.new(mix.outputs[0], out.inputs["Surface"])
    sphere((0.0, FRONT_Y - 0.06, DOOR_Z), (DOOR_R, 0.07, DOOR_R), glass, name="Glass")
    # Yansıma kaynağı: kadraj dışında, camda yumuşak parlak şerit bırakan geniş beyaz düzlem.
    bpy.ops.mesh.primitive_plane_add(size=1.0, location=(-1.2, -2.0, 1.6), rotation=(math.radians(70), 0.0, math.radians(-30)))
    panel = bpy.context.view_layer.objects.active
    panel.scale = (1.6, 0.6, 1.0)
    panel.visible_camera = False
    assign(panel, mat("softbox", "#FFFFFF", emission="#FFFFFF", emission_strength=4.0))
    render(MACHINE_DIR, "machine_glass")


# ----------------------------------------------------------------------------- lekeler

def _overlay_frame():
    camera(0.0, OVERLAY_ORTHO, 256, 256)


def build_mud():
    reset()
    _overlay_frame()
    mud = mat("mud", "#7B5435", rough=0.32, coat=0.55, spec=0.5)
    elements = [
        (0.0, 0.0, 0.03, 0.2, (1.25, 0.25, 1.0)),
        (0.16, 0.0, 0.12, 0.13, (1.0, 0.25, 0.9)),
        (-0.18, 0.0, -0.02, 0.12, (1.1, 0.25, 1.0)),
        (0.07, 0.0, -0.15, 0.13, (1.2, 0.25, 0.8)),
        (-0.06, 0.0, 0.17, 0.1, (1.0, 0.25, 1.0)),
        (0.3, 0.0, -0.08, 0.06, (1.0, 0.25, 1.0)),
        (-0.31, 0.0, 0.14, 0.05, (1.0, 0.25, 1.0)),
        (0.24, 0.0, 0.27, 0.045, (1.0, 0.25, 1.0)),
        # Damlalar: aşağı sarkan uzun küçük toplar.
        (-0.12, 0.0, -0.27, 0.055, (0.8, 0.25, 1.9)),
        (0.12, 0.0, -0.31, 0.045, (0.8, 0.25, 2.0)),
    ]
    blobs(elements, mud, threshold=0.55)
    # Leke içinde açık ton kabarcıklar: düz kahverengi değil, ıslak toprak.
    light = mat("mud_light", "#9C7250", rough=0.3, coat=0.6)
    for x, z, r in ((-0.05, 0.05, 0.05), (0.13, -0.08, 0.035), (-0.17, 0.07, 0.03)):
        sphere((x, -0.06, z), (r, r * 0.4, r), light)
    render(MACHINE_DIR, "overlay_mud")


def build_birdmess():
    reset()
    _overlay_frame()
    white = mat("mess", "#FBFAF5", rough=0.28, coat=0.7, subsurface=0.1)
    elements = [
        (0.0, 0.0, 0.05, 0.17, (1.2, 0.3, 1.0)),
        (0.13, 0.0, 0.14, 0.1, (1.0, 0.3, 1.0)),
        (-0.14, 0.0, 0.0, 0.1, (1.0, 0.3, 1.0)),
        (-0.04, 0.0, -0.12, 0.09, (0.8, 0.3, 1.6)),
        (0.12, 0.0, -0.1, 0.05, (0.8, 0.3, 2.2)),
        (0.27, 0.0, 0.0, 0.04, (1.0, 0.3, 1.0)),
        (-0.26, 0.0, 0.18, 0.035, (1.0, 0.3, 1.0)),
    ]
    blobs(elements, white, threshold=0.55)
    render(MACHINE_DIR, "overlay_birdmess")


# ----------------------------------------------------------------------------- kuş

def _bird(flap):
    camera(0.05, 1.25, 256, 256)
    body = mat("bird_body", "#9CC3E6", rough=0.55, sheen=0.5, subsurface=0.05)
    belly = mat("bird_belly", "#FCE3CF", rough=0.6, sheen=0.5)
    wing = mat("bird_wing", "#7FAAD6", rough=0.5, sheen=0.4)
    beak = mat("bird_beak", "#F4A259", rough=0.35, coat=0.4)
    eye = mat("bird_eye", "#1F2430", rough=0.08, coat=1.0)
    cheek = mat("bird_cheek", "#F7A8B8", rough=0.6)
    sphere((0.0, 0.0, 0.0), (0.36, 0.32, 0.33), body, name="Body")
    sphere((-0.04, -0.13, -0.06), (0.27, 0.2, 0.24), belly, name="Belly")
    # Kafa gövdeye kaynaşık (tombul serçe): sol-öne dönük.
    sphere((-0.17, -0.05, 0.2), (0.21, 0.2, 0.2), body, name="Head")
    sphere((-0.21, -0.17, 0.14), (0.12, 0.08, 0.09), belly, name="Throat")
    cone((-0.39, -0.08, 0.19), 0.05, 0.12, beak, rot=(0.0, -90.0, 0.0))
    for ex, ey in ((-0.25, -0.2), (-0.11, -0.21)):
        sphere((ex, ey, 0.25), (0.028, 0.02, 0.032), eye)
    sphere((-0.27, -0.2, 0.16), (0.03, 0.01, 0.022), cheek)
    sphere((-0.06, -0.21, 0.17), (0.03, 0.01, 0.022), cheek)
    # Kuyruk: arkada yukarı kalkık yassı elips.
    sphere((0.38, 0.03, 0.12), (0.16, 0.06, 0.07), wing, rot=(0.0, -30.0, 0.0), name="Tail")
    if flap:
        for side, y in ((-1.0, -0.2), (1.0, 0.2)):
            sphere((0.12, y, 0.28), (0.24, 0.05, 0.13), wing, rot=(side * 25.0, -40.0, 0.0), name="WingUp")
    else:
        sphere((0.12, -0.2, 0.0), (0.22, 0.07, 0.15), wing, rot=(0.0, 18.0, 0.0), name="Wing")
    leg = mat("bird_leg", "#E8935A", rough=0.4)
    for lx in (-0.08, 0.06):
        tube([(lx, -0.05, -0.27, 0.018), (lx, -0.05, -0.34, 0.016), (lx - 0.04, -0.07, -0.36, 0.014)], leg)


def build_bird():
    reset()
    _bird(False)
    render(CRITTER_DIR, "bird_idle")
    reset()
    _bird(True)
    render(CRITTER_DIR, "bird_flap")


# ----------------------------------------------------------------------------- bulut + damla

def build_cloud():
    reset()
    camera(0.0, 1.6, 512, 320)
    cloud = gradient_mat("cloud", "#AFC0D4", "#F4F7FB", rough=0.85, sheen=0.6, z0=-0.22, z1=0.3, subsurface=0.08)
    elements = [
        (0.0, 0.0, 0.0, 0.3, (1.6, 1.0, 0.9)),
        (-0.32, 0.0, -0.04, 0.24, (1.2, 1.0, 0.85)),
        (0.34, 0.0, -0.05, 0.22, (1.2, 1.0, 0.8)),
        (-0.1, 0.0, 0.15, 0.25, (1.0, 1.0, 1.0)),
        (0.17, 0.0, 0.12, 0.21, (1.0, 1.0, 1.0)),
        (-0.52, 0.0, -0.1, 0.13, (1.0, 1.0, 0.8)),
        (0.54, 0.0, -0.11, 0.12, (1.0, 1.0, 0.8)),
    ]
    obj = blobs(elements, cloud, resolution=0.015, threshold=0.6)
    # Alt kenar düzleşsin: bulut "oturan" bir yastık gibi okunur.
    obj.scale = (1.0, 0.7, 1.0)
    render(CRITTER_DIR, "cloud")


def build_drop():
    reset()
    camera(0.0, 0.3, 64, 96)
    water = mat("drop", "#8CC8EE", rough=0.08, coat=1.0, transmission=0.3, spec=0.6)
    sphere((0.0, 0.0, -0.03), (0.07, 0.07, 0.075), water)
    cone((0.0, 0.0, 0.05), 0.058, 0.12, water)
    render(CRITTER_DIR, "drop")


# ----------------------------------------------------------------------------- kedi

def _cat_materials():
    return {
        "fur": mat("cat_fur", "#F2BE8A", rough=0.62, sheen=0.7, subsurface=0.05),
        "cream": mat("cat_cream", "#FCEBD7", rough=0.65, sheen=0.6),
        "stripe": mat("cat_stripe", "#E59E64", rough=0.6, sheen=0.6),
        "ear": mat("cat_ear", "#F7B7B9", rough=0.6),
        "nose": mat("cat_nose", "#EE8E9C", rough=0.4, coat=0.4),
        "ink": mat("cat_ink", "#5B4436", rough=0.35),
        "eye": mat("cat_eye", "#2A2E36", rough=0.06, coat=1.0),
    }


def _ear(x, z, side, materials, tilt=0.0):
    cone((x, 0.0, z), 0.085, 0.15, materials["fur"], rot=(tilt, side * 18.0, 0.0))
    cone((x, -0.03, z - 0.01), 0.05, 0.1, materials["ear"], rot=(tilt, side * 18.0, 0.0))


def build_cat_sleep():
    reset()
    # Sepet ağzından görünür: hafif yukarıdan.
    camera(0.08, 1.2, 384, 256, tilt_deg=28.0)
    m = _cat_materials()
    sphere((0.05, 0.02, 0.0), (0.42, 0.3, 0.2), m["fur"], name="Body")
    for i, x in enumerate((-0.05, 0.1, 0.25)):
        sphere((x, 0.04, 0.1), (0.04, 0.2, 0.06), m["stripe"], rot=(0.0, 0.0, 8.0 * i), name="Stripe")
    # Kafa solda, kuyruğa yaslanmış.
    sphere((-0.3, -0.1, 0.07), (0.19, 0.17, 0.15), m["fur"], name="Head")
    sphere((-0.34, -0.22, 0.03), (0.1, 0.06, 0.07), m["cream"], name="Muzzle")
    _ear(-0.4, 0.2, -1.0, m, tilt=-10.0)
    _ear(-0.2, 0.2, 1.0, m, tilt=-10.0)
    sphere((-0.34, -0.27, 0.06), (0.022, 0.014, 0.016), m["nose"])
    # Kapalı gözler: ince yay (mutlu uyku).
    for ex in (-0.41, -0.27):
        tube([(ex - 0.035, -0.25, 0.1, 0.009), (ex, -0.265, 0.086, 0.009), (ex + 0.035, -0.25, 0.1, 0.009)], m["ink"])
    # Kuyruk önden dolanır, ucu kafaya değer.
    tube([(0.42, -0.05, -0.02, 0.06), (0.36, -0.28, -0.04, 0.06), (0.05, -0.34, -0.05, 0.058),
          (-0.2, -0.27, -0.06, 0.05)], m["fur"], name="Tail")
    sphere((-0.2, -0.27, -0.06), (0.06, 0.06, 0.055), m["cream"], name="TailTip")
    # Ön pati kuyruğun üstünde.
    sphere((-0.1, -0.3, -0.02), (0.08, 0.06, 0.045), m["cream"], name="Paw")
    render(CRITTER_DIR, "cat_sleep")


def build_cat_awake():
    reset()
    camera(0.1, 1.15, 320, 320, tilt_deg=12.0)
    m = _cat_materials()
    sphere((0.05, 0.05, -0.12), (0.3, 0.26, 0.28), m["fur"], name="Body")
    sphere((-0.02, -0.14, -0.1), (0.16, 0.12, 0.2), m["cream"], name="Chest")
    sphere((0.0, -0.02, 0.22), (0.22, 0.19, 0.18), m["fur"], name="Head")
    for i, x in enumerate((-0.06, 0.0, 0.06)):
        sphere((x, -0.06, 0.37), (0.018, 0.08, 0.045), m["stripe"], name="Stripe")
    sphere((0.0, -0.17, 0.16), (0.11, 0.06, 0.075), m["cream"], name="Muzzle")
    _ear(-0.13, 0.37, -1.0, m)
    _ear(0.13, 0.37, 1.0, m)
    sphere((0.0, -0.225, 0.19), (0.024, 0.015, 0.018), m["nose"])
    for ex in (-0.08, 0.08):
        sphere((ex, -0.18, 0.25), (0.035, 0.02, 0.045), m["eye"])
        sphere((ex - 0.012, -0.2, 0.265), (0.01, 0.005, 0.012), mat("cat_glint", "#FFFFFF", emission="#FFFFFF",
                                                                       emission_strength=2.0))
    for px in (-0.1, 0.1):
        sphere((px, -0.2, -0.36), (0.07, 0.07, 0.045), m["cream"], name="Paw")
    tube([(0.25, 0.1, -0.3, 0.05), (0.38, -0.05, -0.32, 0.05), (0.33, -0.22, -0.34, 0.045),
          (0.18, -0.27, -0.36, 0.04)], m["fur"], name="Tail")
    render(CRITTER_DIR, "cat_awake")


# ----------------------------------------------------------------------------- siluetler

def _load_rgba(path):
    img = bpy.data.images.load(path)
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    bpy.data.images.remove(img)
    return px.reshape(h, w, 4)


def _save_rgba(px, path):
    h, w = px.shape[:2]
    out = bpy.data.images.new("sil", w, h, alpha=True)
    out.pixels.foreach_set(np.ascontiguousarray(px).ravel())
    out.filepath_raw = path
    out.file_format = "PNG"
    out.save()
    bpy.data.images.remove(out)
    print("yazıldı:", os.path.relpath(path, ROOT))


def silhouette(source, target, size, pad=0.08):
    """Kaynak PNG'nin alfasından kare, ortalanmış BEYAZ siluet (oyunda renkle çarpılır)."""
    px = _load_rgba(source)
    alpha = px[:, :, 3]
    rows = np.where(alpha.max(axis=1) > 0.05)[0]
    cols = np.where(alpha.max(axis=0) > 0.05)[0]
    crop = alpha[rows[0]:rows[-1] + 1, cols[0]:cols[-1] + 1]
    ch, cw = crop.shape
    inner = int(size * (1.0 - 2.0 * pad))
    scale = inner / max(ch, cw)
    nh, nw = max(int(ch * scale), 1), max(int(cw * scale), 1)
    # Alan ortalamalı küçültme (yumuşak kenar): her hedef piksel kaynak bloğunun ortalaması.
    ys = (np.arange(nh + 1) * ch / nh).astype(int)
    xs = (np.arange(nw + 1) * cw / nw).astype(int)
    small = np.zeros((nh, nw), dtype=np.float32)
    for j in range(nh):
        band = crop[ys[j]:max(ys[j + 1], ys[j] + 1)]
        sums = np.add.reduceat(band.sum(axis=0), xs[:-1])
        widths = np.diff(np.append(xs[:-1], cw)).clip(min=1)
        small[j] = sums / (widths * band.shape[0])
    canvas = np.zeros((size, size, 4), dtype=np.float32)
    y0 = (size - nh) // 2
    x0 = (size - nw) // 2
    canvas[y0:y0 + nh, x0:x0 + nw, 0:3] = 1.0
    canvas[y0:y0 + nh, x0:x0 + nw, 3] = small
    _save_rgba(canvas, target)


def build_icons():
    for name in KINDS:
        source = os.path.join(GARMENT_DIR, "garment_%s.png" % name)
        if os.path.exists(source):
            silhouette(source, os.path.join(MACHINE_DIR, "kind_%s.png" % name), KIND_SIZE)
    for source, target in (("bird_idle", "icon_bird"), ("cloud", "icon_cloud"), ("cat_awake", "icon_cat")):
        path = os.path.join(CRITTER_DIR, source + ".png")
        if os.path.exists(path):
            silhouette(path, os.path.join(CRITTER_DIR, target + ".png"), ICON_SIZE)
    for source in ("machine_washer", "machine_dryer"):
        path = os.path.join(MACHINE_DIR, source + ".png")
        if os.path.exists(path):
            silhouette(path, os.path.join(MACHINE_DIR, "icon_" + source.split("_")[1] + ".png"), ICON_SIZE)


BUILDERS = {
    "washer": build_washer, "dryer": build_dryer, "glass": build_glass, "mud": build_mud,
    "birdmess": build_birdmess, "bird": build_bird, "cloud": build_cloud, "drop": build_drop,
    "cat_sleep": build_cat_sleep, "cat_awake": build_cat_awake, "icons": build_icons,
}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    names = argv if argv else list(BUILDERS.keys())
    for name in names:
        BUILDERS[name]()


main()
