#!/usr/bin/env python3
"""Çamaşır İpi — sprite üretici (Blender, headless, Cycles). Kaynak = bu betik; PNG'ler çıktıdır.

    /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/make_sprites.py
    ... -- garment_tshirt pin        # yalnız adı verilenler
    python3 tools/post_sprites.py     # ardından ton dengesi (nötr sprite'lar)

Kural 1 (kullanıcı): low-poly yok; her şey pürüzsüz, dolgun, "premium".

Çamaşır boru hattı (v2):
  1. 2B dış hat (köşeleri Chaikin ile yuvarlatılmış) -> ince levha -> ince voxel remesh.
  2. ŞİŞİRME: her köşenin dış hatta uzaklığına göre ön/arka yüz dışarı itilir
     (kenarda dairesel yuvarlak profil + ortada hafif kubbe) -> yastık gibi dolgun hacim.
  3. Yükseklik detayları (geometri): kalın kıvrık etek/kol/bel bantları, yaka şeridi, ribana.
  4. Asılı kumaş kıvrımları: mandal noktalarından yelpaze gibi açılan yumuşak kıvrımlar,
     mandallar arası sarkma kıvrımı, altta ağırlık dalgaları.
  5. İnce detaylar (doku/bump): dikiş hatları (kesik çizgi), dikiş oluğu, ince dokuma.
  6. Kumaş gölgelendirici: sheen (kadife parıltı) + hafif subsurface; arka/üst "rim" ışığı.
Çamaşırlar NÖTR BEYAZ render edilir; oyun rengi çarpımla verir.
"""

import math
import os
import random
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_DIR = os.path.join(ROOT, "assets", "sprites")
SAMPLES = 160

# Çamaşır kadrajı: 768x768, üst kenar (z=0) tuvalin ~%10 altında, ortalanmış.
G_CENTER_Z = -0.5
G_ORTHO = 1.26
G_LEFT = -G_ORTHO * 0.5
G_BOTTOM = G_CENTER_Z - G_ORTHO * 0.5
DETAIL_RES = 1024
# Oyun mandalları çamaşır boyunun ±%20'sine koyar; sprite 1.14 kat büyütülür -> ±0.221 birim.
PIN_X = 0.2 * G_ORTHO / 1.14
FOLD_GAIN = 1.6


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
    scene.cycles.max_bounces = 6
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
    background.inputs[1].default_value = 0.3
    return scene


def add_lights(key=2.1, fill=0.35, rim=1.6, ambient=None):
    def sun(name, energy, toward_light, angle):
        data = bpy.data.lights.new(name, "SUN")
        data.energy = energy
        data.angle = math.radians(angle)
        obj = bpy.data.objects.new(name, data)
        # Güneş yerel −Z yönünde ışır: +Z ışığın geldiği yöne bakmalı.
        obj.rotation_euler = Vector(toward_light).normalized().to_track_quat("Z", "Y").to_euler()
        bpy.context.scene.collection.objects.link(obj)
        return obj
    # Anahtar: sol-üst-önden, geniş açılı (yumuşak ama yönü belli gölge -> hacim okunur).
    sun("Key", key, (-0.62, -0.62, 0.62), 32.0)
    # Dolgu: sağ-önden, alçak ve zayıf (gölgeler çamurlaşmasın).
    sun("Fill", fill, (0.75, -0.6, -0.15), 60.0)
    # Arka/üst ışık: yukarı bakan kıvrım sırtlarında ve kenarlarda parlak "rim".
    sun("Rim", rim, (0.3, 0.75, 0.6), 18.0)
    if ambient is not None:
        bpy.context.scene.world.node_tree.nodes["Background"].inputs[1].default_value = ambient


def add_camera(center_z, ortho_scale, res_x, res_y, tilt_deg=0.0, yaw_deg=0.0, center_x=0.0):
    data = bpy.data.cameras.new("Cam")
    data.type = "ORTHO"
    data.ortho_scale = ortho_scale
    obj = bpy.data.objects.new("Cam", data)
    tilt = math.radians(tilt_deg)
    yaw = math.radians(yaw_deg)
    dist = 6.0
    obj.location = (center_x + dist * math.cos(tilt) * math.sin(yaw), -dist * math.cos(tilt) * math.cos(yaw),
                    center_z + dist * math.sin(tilt))
    obj.rotation_euler = (math.radians(90.0) - tilt, 0.0, yaw)
    scene = bpy.context.scene
    scene.collection.objects.link(obj)
    scene.camera = obj
    scene.render.resolution_x = res_x
    scene.render.resolution_y = res_y
    scene.render.resolution_percentage = 100


def render(name, res_x, res_y):
    path = os.path.join(OUT_DIR, name + ".png")
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("yazıldı:", os.path.relpath(path, ROOT))


# ----------------------------------------------------------------------------- malzemeler

def _set(node, name, value):
    if name in node.inputs:
        node.inputs[name].default_value = value


def principled(name, color, roughness=0.8):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    _set(bsdf, "Base Color", (*color, 1.0))
    _set(bsdf, "Roughness", roughness)
    return mat, bsdf


def fabric_material(name, detail=None, texture="cotton", uv_scale=1.0, base=0.93, cavity=False):
    """Yumuşak kumaş: sheen + hafif subsurface + ince dokuma bump + (varsa) dikiş haritası."""
    mat, bsdf = principled(name, (base, base, base), 0.82)
    _set(bsdf, "Sheen Weight", 0.55)
    _set(bsdf, "Sheen Roughness", 0.38)
    _set(bsdf, "Sheen Tint", (1.0, 1.0, 1.0, 1.0))
    _set(bsdf, "Subsurface Weight", 0.06)
    _set(bsdf, "Subsurface Radius", (1.0, 1.0, 1.0))
    _set(bsdf, "Subsurface Scale", 0.01)
    _set(bsdf, "Specular IOR Level", 0.25)
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    coords = nodes.new("ShaderNodeTexCoord")
    mapping = nodes.new("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = (uv_scale, uv_scale, uv_scale)
    links.new(coords.outputs["UV"], mapping.inputs["Vector"])

    # Dokuma yüksekliği (çok ince; 768 px'te sezilir, 200 px'te yalnız "kumaş" hissi verir).
    if texture == "terry":
        noise = nodes.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = 520.0
        noise.inputs["Detail"].default_value = 3.0
        links.new(mapping.outputs["Vector"], noise.inputs["Vector"])
        weave_out, weave_strength = noise.outputs["Fac"], 0.32
    elif texture == "knit":
        wave = nodes.new("ShaderNodeTexWave")
        wave.wave_type = "BANDS"
        wave.bands_direction = "X"
        wave.inputs["Scale"].default_value = 140.0
        wave.inputs["Distortion"].default_value = 1.5
        wave.inputs["Detail"].default_value = 1.0
        links.new(mapping.outputs["Vector"], wave.inputs["Vector"])
        weave_out, weave_strength = wave.outputs["Fac"], 0.12
    else:
        wave_a = nodes.new("ShaderNodeTexWave")
        wave_a.bands_direction = "X"
        wave_a.inputs["Scale"].default_value = 320.0
        wave_b = nodes.new("ShaderNodeTexWave")
        wave_b.bands_direction = "Y"
        wave_b.inputs["Scale"].default_value = 320.0
        for wave in (wave_a, wave_b):
            links.new(mapping.outputs["Vector"], wave.inputs["Vector"])
        mix = nodes.new("ShaderNodeMath")
        mix.operation = "MULTIPLY"
        links.new(wave_a.outputs["Fac"], mix.inputs[0])
        links.new(wave_b.outputs["Fac"], mix.inputs[1])
        weave_out, weave_strength = mix.outputs["Value"], 0.07

    weave_bump = nodes.new("ShaderNodeBump")
    weave_bump.inputs["Strength"].default_value = weave_strength
    weave_bump.inputs["Distance"].default_value = 0.002
    links.new(weave_out, weave_bump.inputs["Height"])
    normal_out = weave_bump.outputs["Normal"]

    if detail is not None:
        height_img, shade_img = detail
        height_tex = nodes.new("ShaderNodeTexImage")
        height_tex.image = height_img
        height_tex.interpolation = "Cubic"
        height_tex.extension = "EXTEND"
        links.new(coords.outputs["UV"], height_tex.inputs["Vector"])
        detail_bump = nodes.new("ShaderNodeBump")
        detail_bump.inputs["Strength"].default_value = 0.85
        detail_bump.inputs["Distance"].default_value = 0.006
        links.new(height_tex.outputs["Color"], detail_bump.inputs["Height"])
        links.new(weave_bump.outputs["Normal"], detail_bump.inputs["Normal"])
        normal_out = detail_bump.outputs["Normal"]
        shade_tex = nodes.new("ShaderNodeTexImage")
        shade_tex.image = shade_img
        shade_tex.interpolation = "Cubic"
        shade_tex.extension = "EXTEND"
        links.new(coords.outputs["UV"], shade_tex.inputs["Vector"])
        tint = nodes.new("ShaderNodeMath")
        tint.operation = "MULTIPLY"
        tint.inputs[1].default_value = base
        links.new(shade_tex.outputs["Color"], tint.inputs[0])
        links.new(tint.outputs["Value"], bsdf.inputs["Base Color"])
    links.new(normal_out, bsdf.inputs["Normal"])
    if cavity:
        # Köşe başına "cavity" özniteliği: kıvrım diplerinde yumuşak temas gölgesi (AO benzeri).
        attr = nodes.new("ShaderNodeAttribute")
        attr.attribute_name = "cavity"
        attr.attribute_type = "GEOMETRY"
        mul = nodes.new("ShaderNodeMath")
        mul.operation = "MULTIPLY"
        base_input = bsdf.inputs["Base Color"]
        if base_input.links:
            links.new(base_input.links[0].from_socket, mul.inputs[0])
        else:
            mul.inputs[0].default_value = base
        links.new(attr.outputs["Fac"], mul.inputs[1])
        links.new(mul.outputs["Value"], base_input)
    return mat


def set_cavity(obj, values):
    attr = obj.data.attributes.new("cavity", "FLOAT", "POINT")
    attr.data.foreach_set("value", np.asarray(values, dtype=np.float32))


def wood_material(name, light=(0.86, 0.64, 0.40), dark=(0.66, 0.44, 0.24)):
    mat, bsdf = principled(name, light, 0.45)
    _set(bsdf, "Coat Weight", 0.25)
    _set(bsdf, "Coat Roughness", 0.3)
    _set(bsdf, "Sheen Weight", 0.15)
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    coords = nodes.new("ShaderNodeTexCoord")
    mapping = nodes.new("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = (14.0, 14.0, 1.6)
    links.new(coords.outputs["Object"], mapping.inputs["Vector"])
    grain = nodes.new("ShaderNodeTexWave")
    grain.wave_type = "RINGS"
    grain.inputs["Scale"].default_value = 1.6
    grain.inputs["Distortion"].default_value = 6.0
    grain.inputs["Detail"].default_value = 3.0
    links.new(mapping.outputs["Vector"], grain.inputs["Vector"])
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (*dark, 1.0)
    ramp.color_ramp.elements[0].position = 0.15
    ramp.color_ramp.elements[1].color = (*light, 1.0)
    ramp.color_ramp.elements[1].position = 0.75
    links.new(grain.outputs["Fac"], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    bump = nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.08
    links.new(grain.outputs["Fac"], bump.inputs["Height"])
    links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


def metal_material(name):
    mat, bsdf = principled(name, (0.86, 0.88, 0.92), 0.22)
    _set(bsdf, "Metallic", 1.0)
    return mat


def wicker_material(name):
    """Hasır: sıcak bal rengi, lif yönünde ince çizgiler, satır satır hafif ton farkı."""
    mat, bsdf = principled(name, (0.88, 0.72, 0.48), 0.55)
    _set(bsdf, "Coat Weight", 0.2)
    _set(bsdf, "Coat Roughness", 0.35)
    _set(bsdf, "Sheen Weight", 0.2)
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    coords = nodes.new("ShaderNodeTexCoord")
    fibre = nodes.new("ShaderNodeTexNoise")
    fibre.inputs["Scale"].default_value = 9.0
    fibre.inputs["Detail"].default_value = 6.0
    mapping = nodes.new("ShaderNodeMapping")
    # Lifler yatay sıralar boyunca uzanır: z yönünde hızlı, çevrede yavaş değişen gürültü.
    mapping.inputs["Scale"].default_value = (1.6, 1.6, 40.0)
    links.new(coords.outputs["Object"], mapping.inputs["Vector"])
    links.new(mapping.outputs["Vector"], fibre.inputs["Vector"])
    attr = nodes.new("ShaderNodeAttribute")
    attr.attribute_name = "tone"
    attr.attribute_type = "OBJECT"
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (0.70, 0.52, 0.30, 1.0)
    ramp.color_ramp.elements[1].color = (0.95, 0.82, 0.60, 1.0)
    mix = nodes.new("ShaderNodeMath")
    mix.operation = "MULTIPLY_ADD"
    links.new(fibre.outputs["Fac"], mix.inputs[0])
    mix.inputs[1].default_value = 0.55
    links.new(attr.outputs["Fac"], mix.inputs[2])
    links.new(mix.outputs["Value"], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    bump = nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.25
    bump.inputs["Distance"].default_value = 0.004
    links.new(fibre.outputs["Fac"], bump.inputs["Height"])
    links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


# ----------------------------------------------------------------------------- 2B geometri

def mirror(points):
    """Sağ yarı (x>=0, saat yönünde yukarıdan aşağı) -> tam kapalı dış hat."""
    left = [(-x, z) for x, z in reversed(points) if x > 1e-6]
    return points + left


def mirrored(polyline):
    return [(-x, z) for x, z in polyline]


def densify(points, step=0.025, closed=True):
    """Uzun kenarları böler: Chaikin köşeleri sabit, küçük yarıçapla yuvarlasın."""
    out = []
    count = len(points) if closed else len(points) - 1
    for i in range(count):
        a, b = points[i], points[(i + 1) % len(points)]
        n = max(1, int(math.ceil(math.hypot(b[0] - a[0], b[1] - a[1]) / step)))
        out += [(a[0] + (b[0] - a[0]) * k / n, a[1] + (b[1] - a[1]) * k / n) for k in range(n)]
    if not closed:
        out.append(tuple(points[-1]))
    return out


def chaikin(points, iterations=3, closed=True):
    pts = [tuple(p) for p in points]
    for _ in range(iterations):
        out = []
        count = len(pts) if closed else len(pts) - 1
        for i in range(count):
            a, b = pts[i], pts[(i + 1) % len(pts)]
            out.append(tuple(0.75 * p + 0.25 * q for p, q in zip(a, b)))
            out.append(tuple(0.25 * p + 0.75 * q for p, q in zip(a, b)))
        if not closed:
            out = [pts[0]] + out + [pts[-1]]
        pts = out
    return pts


def rect(x0, x1, z0, z1):
    return [(x0, z1), (x1, z1), (x1, z0), (x0, z0)]


def arc(cx, cz, rx, rz, start_deg, end_deg, steps=24):
    return [(cx + rx * math.cos(math.radians(start_deg + (end_deg - start_deg) * i / steps)),
             cz + rz * math.sin(math.radians(start_deg + (end_deg - start_deg) * i / steps)))
            for i in range(steps + 1)]


def seg_distance(px, pz, polyline, closed=False):
    """Noktaların (numpy) çoklu çizgiye en kısa uzaklığı."""
    pts = np.asarray(polyline, dtype=np.float64)
    a = pts if closed else pts[:-1]
    b = np.roll(pts, -1, axis=0) if closed else pts[1:]
    best = np.full(px.shape, 1e9)
    for (ax, az), (bx, bz) in zip(a, b):
        dx, dz = bx - ax, bz - az
        length2 = max(dx * dx + dz * dz, 1e-12)
        t = np.clip(((px - ax) * dx + (pz - az) * dz) / length2, 0.0, 1.0)
        qx, qz = ax + t * dx - px, az + t * dz - pz
        best = np.minimum(best, np.sqrt(qx * qx + qz * qz))
    return best


def inside_polygon(px, pz, polygon):
    pts = np.asarray(polygon, dtype=np.float64)
    inside = np.zeros(px.shape, dtype=bool)
    for (ax, az), (bx, bz) in zip(pts, np.roll(pts, -1, axis=0)):
        cond = (az > pz) != (bz > pz)
        with np.errstate(divide="ignore", invalid="ignore"):
            cross = ax + (pz - az) * (bx - ax) / (bz - az)
        inside ^= cond & (px < cross)
    return inside


def flat_shape(name, outline, thickness):
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
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    obj = bpy.context.view_layer.objects.active
    obj.rotation_euler = (math.radians(90.0), 0.0, 0.0)
    bpy.ops.object.transform_apply(rotation=True)
    solid = obj.modifiers.new("Solid", "SOLIDIFY")
    solid.thickness = thickness
    solid.offset = 0.0
    bpy.ops.object.modifier_apply(modifier="Solid")
    obj.select_set(False)
    return obj


def remesh_smooth(obj, voxel, smooth_repeat, factor=0.6):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    remesh = obj.modifiers.new("Remesh", "REMESH")
    remesh.mode = "VOXEL"
    remesh.voxel_size = voxel
    bpy.ops.object.modifier_apply(modifier="Remesh")
    if smooth_repeat > 0:
        smooth = obj.modifiers.new("Smooth", "SMOOTH")
        smooth.factor = factor
        smooth.iterations = smooth_repeat
        bpy.ops.object.modifier_apply(modifier="Smooth")
    bpy.ops.object.shade_smooth()
    return obj


def get_co(obj):
    co = np.empty(len(obj.data.vertices) * 3)
    obj.data.vertices.foreach_get("co", co)
    return co.reshape(-1, 3)


def set_co(obj, co):
    obj.data.vertices.foreach_set("co", co.reshape(-1))
    obj.data.update()


def add_canvas_uv(obj, coords_xz, left, bottom, span):
    """UV = özgün (kıvrım öncesi) x,z'nin tuval içindeki yeri; detay haritaları buna oturur."""
    mesh = obj.data
    uv = mesh.uv_layers.new(name="UVMap")
    loop_vert = np.empty(len(mesh.loops), dtype=np.int64)
    mesh.loops.foreach_get("vertex_index", loop_vert)
    u = (coords_xz[loop_vert, 0] - left) / span
    v = (coords_xz[loop_vert, 1] - bottom) / span
    uv.data.foreach_set("uv", np.stack([u, v], axis=1).reshape(-1))


def add_subsurf(obj, levels=1):
    mod = obj.modifiers.new("Subsurf", "SUBSURF")
    mod.levels = levels
    mod.render_levels = levels


# ----------------------------------------------------------------------------- detay haritası

class DetailMap:
    """Tuvale oturan iki doku: yükseklik (bump) ve ton (oluk/dikiş gölgesi)."""

    def __init__(self, res=DETAIL_RES, left=G_LEFT, bottom=G_BOTTOM, span=G_ORTHO):
        self.res, self.left, self.bottom, self.span = res, left, bottom, span
        self.height = np.full((res, res), 0.5, dtype=np.float32)
        self.shade = np.ones((res, res), dtype=np.float32)

    def _px(self, x, z):
        return ((x - self.left) / self.span * self.res, (z - self.bottom) / self.span * self.res)

    def _stroke(self, a, b, radius_units, fn):
        ax, az = self._px(*a)
        bx, bz = self._px(*b)
        r = radius_units / self.span * self.res
        x0, x1 = int(max(min(ax, bx) - r * 3 - 2, 0)), int(min(max(ax, bx) + r * 3 + 3, self.res))
        z0, z1 = int(max(min(az, bz) - r * 3 - 2, 0)), int(min(max(az, bz) + r * 3 + 3, self.res))
        if x1 <= x0 or z1 <= z0:
            return
        gz, gx = np.mgrid[z0:z1, x0:x1].astype(np.float32) + 0.5
        dx, dz = bx - ax, bz - az
        length2 = max(dx * dx + dz * dz, 1e-9)
        t = np.clip(((gx - ax) * dx + (gz - az) * dz) / length2, 0.0, 1.0)
        dist = np.hypot(ax + t * dx - gx, az + t * dz - gz)
        fn(slice(z0, z1), slice(x0, x1), dist / max(r, 1e-6))

    def groove(self, polyline, width=0.006, depth=0.35, darken=0.22):
        def apply(rows, cols, d):
            g = np.exp(-d * d)
            self.height[rows, cols] = np.minimum(self.height[rows, cols], 0.5 - depth * g)
            self.shade[rows, cols] = np.minimum(self.shade[rows, cols], 1.0 - darken * g)
        for a, b in zip(polyline[:-1], polyline[1:]):
            self._stroke(a, b, width, apply)

    def stitches(self, polyline, dash=0.011, gap=0.007, width=0.0028, lift=0.3, darken=0.12):
        """Kesik çizgi dikiş: her dikiş hafif kabarık, iki yanında ince gölge."""
        pts = np.asarray(polyline, dtype=np.float64)
        seg = np.hypot(*(pts[1:] - pts[:-1]).T)
        cum = np.concatenate([[0.0], np.cumsum(seg)])
        total = cum[-1]

        def at(s):
            i = int(np.clip(np.searchsorted(cum, s) - 1, 0, len(seg) - 1))
            t = (s - cum[i]) / max(seg[i], 1e-9)
            return tuple(pts[i] + (pts[i + 1] - pts[i]) * t)

        def apply(rows, cols, d):
            bump = np.exp(-d * d * 1.6)
            halo = np.exp(-((d - 1.6) ** 2) * 1.5)
            self.height[rows, cols] = np.maximum(self.height[rows, cols], 0.5 + lift * bump)
            self.shade[rows, cols] = np.minimum(self.shade[rows, cols], 1.0 - darken * halo)
        s = gap * 0.5
        while s + dash <= total:
            self._stroke(at(s), at(s + dash), width, apply)
            s += dash + gap

    def images(self, name):
        out = []
        for suffix, data in (("h", self.height), ("s", self.shade)):
            img = bpy.data.images.new("%s_%s" % (name, suffix), self.res, self.res, alpha=False,
                                      float_buffer=True)
            img.colorspace_settings.name = "Non-Color"
            rgba = np.ones((self.res, self.res, 4), dtype=np.float32)
            rgba[..., 0] = rgba[..., 1] = rgba[..., 2] = data
            img.pixels.foreach_set(rgba.reshape(-1))
            out.append(img)
        return out


# ----------------------------------------------------------------------------- çamaşırlar

def offset_line(polyline, dx, dz):
    return [(x + dx, z + dz) for x, z in polyline]


def hline(x0, x1, z, steps=16):
    return [(x0 + (x1 - x0) * i / steps, z) for i in range(steps + 1)]


def line(a, b, steps=12):
    return [(a[0] + (b[0] - a[0]) * i / steps, a[1] + (b[1] - a[1]) * i / steps) for i in range(steps + 1)]


TSHIRT_R = [(0.0, -0.10), (0.08, -0.07), (0.145, 0.0), (0.33, -0.02), (0.56, -0.2),
            (0.47, -0.38), (0.335, -0.29), (0.35, -0.95), (0.0, -0.965)]
SWEATER_R = [(0.0, -0.09), (0.08, -0.06), (0.14, 0.0), (0.29, -0.012), (0.345, -0.05), (0.39, -0.13), (0.585, -0.72),
             (0.46, -0.79), (0.33, -0.33), (0.335, -0.93), (0.0, -0.94)]
DRESS_R = [(0.0, -0.13), (0.09, -0.05), (0.125, 0.0), (0.215, 0.0), (0.255, -0.2),
           (0.215, -0.42), (0.48, -0.96), (0.25, -0.995), (0.0, -1.005)]
TOWEL = rect(-0.39, 0.39, -0.96, 0.0)
PANTS = [(-0.31, 0.0), (0.31, 0.0), (0.35, -0.99), (0.07, -0.99), (0.0, -0.38),
         (-0.07, -0.99), (-0.35, -0.99)]
SHORTS = [(-0.33, 0.0), (0.33, 0.0), (0.405, -0.6), (0.065, -0.6), (0.0, -0.31),
          (-0.065, -0.6), (-0.405, -0.6)]
SOCK = [(-0.15, 0.0), (0.15, 0.0), (0.16, -0.5), (0.27, -0.6), (0.36, -0.67), (0.415, -0.74), (0.435, -0.82),
        (0.41, -0.9), (0.35, -0.95), (0.2, -0.975), (0.06, -0.965), (-0.06, -0.92), (-0.13, -0.85), (-0.145, -0.76)]


def sleeve_cuff(end_a, end_b, axis, inset):
    """Kol ucu kenarına paralel, kol ekseni boyunca içeri kaydırılmış çizgi."""
    ax, az = axis
    n = math.hypot(ax, az)
    ax, az = ax / n * inset, az / n * inset
    return line((end_a[0] - ax, end_a[1] - az), (end_b[0] - ax, end_b[1] - az))


def neck_curve(half_width, depth, z_top=0.0, steps=24):
    return [(half_width * math.sin(math.radians(-90 + 180 * i / steps)),
             z_top - depth * math.cos(math.radians(-90 + 180 * i / steps))) for i in range(steps + 1)]


def garment_specs():
    specs = {}

    # --- tişört
    cuff_r = sleeve_cuff((0.555, -0.2), (0.47, -0.375), (0.19, -0.13), 0.06)
    specs["garment_tshirt"] = dict(
        outline=mirror(TSHIRT_R), back=neck_curve(0.17, 0.035, 0.0) + list(reversed(neck_curve(0.17, 0.2, 0.0))),
        ridges=[(neck_curve(0.13, 0.085, -0.008), 0.016, 0.016),             # yaka biyesi
                (hline(-0.35, 0.35, -0.925), 0.012, 0.022),                   # kıvrık etek
                (cuff_r, 0.012, 0.02), (mirrored(cuff_r), 0.012, 0.02)],
        grooves=[hline(-0.35, 0.35, -0.895), cuff_r, mirrored(cuff_r),
                 line((0.315, -0.015), (0.335, -0.29)), mirrored(line((0.315, -0.015), (0.335, -0.29))),
                 neck_curve(0.115, 0.07, -0.01)],
        stitches=[hline(-0.35, 0.35, -0.91), hline(-0.35, 0.35, -0.94),
                  offset_line(cuff_r, 0.012, -0.008), mirrored(offset_line(cuff_r, 0.012, -0.008)),
                  neck_curve(0.13, 0.087, -0.006)],
        texture="cotton", folds=dict(fan=0.032, sag=0.022, wave=0.03, freq=2.4))

    # --- kazak (uzun kol, ribanalı)
    cuff_r = sleeve_cuff((0.585, -0.715), (0.465, -0.785), (0.27, -0.7), 0.075)
    specs["garment_sweater"] = dict(
        outline=mirror(SWEATER_R), back=neck_curve(0.16, 0.035, 0.0) + list(reversed(neck_curve(0.16, 0.2, 0.0))),
        ridges=[(neck_curve(0.12, 0.075, -0.012), 0.022, 0.022),
                (hline(-0.34, 0.34, -0.9), 0.014, 0.035),
                (cuff_r, 0.014, 0.02), (mirrored(cuff_r), 0.014, 0.02)],
        ribs=[(rect(-0.36, 0.36, -0.96, -0.865), (1.0, 0.0), 0.024, 0.006),
              ([(0.6, -0.7), (0.53, -0.62), (0.415, -0.69), (0.45, -0.8)], (0.89, 0.45), 0.024, 0.006),
              ([(-0.6, -0.7), (-0.53, -0.62), (-0.415, -0.69), (-0.45, -0.8)], (0.89, -0.45), 0.024, 0.006),
              (neck_curve(0.15, 0.1, 0.01) + list(reversed(neck_curve(0.095, 0.055, -0.005))),
               (1.0, 0.0), 0.02, 0.004)],
        grooves=[hline(-0.34, 0.34, -0.862), sleeve_cuff((0.585, -0.715), (0.465, -0.785), (0.27, -0.7), 0.08),
                 mirrored(sleeve_cuff((0.585, -0.715), (0.465, -0.785), (0.27, -0.7), 0.08)),
                 line((0.30, -0.02), (0.33, -0.33)), mirrored(line((0.30, -0.02), (0.33, -0.33))),
                 neck_curve(0.1, 0.06, -0.008)],
        stitches=[line((0.285, -0.03), (0.315, -0.33)), mirrored(line((0.285, -0.03), (0.315, -0.33)))],
        texture="knit", folds=dict(fan=0.03, sag=0.02, wave=0.026, freq=2.2))

    # --- elbise (askılı, büzgülü bel, kloş etek)
    hem = [(-0.48, -0.955), (-0.25, -0.99), (0.0, -1.0), (0.25, -0.99), (0.48, -0.955)]
    hem = chaikin(hem, 2, closed=False)
    specs["garment_dress"] = dict(
        outline=mirror(DRESS_R),
        back=[(-0.14, 0.0), (0.0, -0.045), (0.14, 0.0), (0.12, -0.2), (-0.12, -0.2)],
        ridges=[(hline(-0.24, 0.24, -0.425), 0.022, 0.024),                   # bel kemeri
                (offset_line(hem, 0.0, 0.035), 0.01, 0.02),
                (line((0.17, -0.005), (0.24, -0.19)), 0.01, 0.02),
                (mirrored(line((0.17, -0.005), (0.24, -0.19))), 0.01, 0.02)],
        grooves=[hline(-0.24, 0.24, -0.398), hline(-0.25, 0.25, -0.452), offset_line(hem, 0.0, 0.055),
                 [(0.0, -0.13), (0.09, -0.05), (0.125, 0.0)], mirrored([(0.0, -0.13), (0.09, -0.05), (0.125, 0.0)])],
        stitches=[hline(-0.235, 0.235, -0.41), hline(-0.235, 0.235, -0.44), offset_line(hem, 0.0, 0.045)],
        gathers=(-0.45, 0.24, 26.0, 0.009),
        texture="cotton", folds=dict(fan=0.028, sag=0.018, wave=0.05, freq=3.6, flare=-0.45))

    # --- havlu (dobi bordürlü, kenar biyeli)
    border = []
    for z in (-0.74,):
        border += [(hline(-0.39, 0.39, z), 0.018, 0.022), (hline(-0.39, 0.39, z - 0.05), 0.018, 0.022)]
    specs["garment_towel"] = dict(
        outline=TOWEL,
        ridges=border + [(hline(-0.39, 0.39, -0.93), 0.012, 0.02), (hline(-0.39, 0.39, -0.03), 0.01, 0.02)],
        ribs=[(rect(-0.4, 0.4, -0.79, -0.745), (1.0, 0.0), 0.022, 0.006)],
        grooves=[hline(-0.385, 0.385, -0.905), hline(-0.385, 0.385, -0.06)],
        stitches=[hline(-0.385, 0.385, -0.92), hline(-0.385, 0.385, -0.045),
                  line((-0.365, -0.06), (-0.365, -0.905), 40), line((0.365, -0.06), (0.365, -0.905), 40)],
        texture="terry", folds=dict(fan=0.03, sag=0.024, wave=0.026, freq=2.0))

    # --- pantolon
    pocket_r = chaikin([(0.17, -0.085), (0.21, -0.17), (0.31, -0.22)], 2, closed=False)
    fly = chaikin([(0.035, -0.09), (0.04, -0.27), (0.0, -0.33)], 2, closed=False)
    specs["garment_pants"] = dict(
        outline=PANTS,
        ridges=[(hline(-0.31, 0.31, -0.045), 0.02, 0.04),
                (line((0.07, -0.95), (0.35, -0.95)), 0.012, 0.02), (mirrored(line((0.07, -0.95), (0.35, -0.95))), 0.012, 0.02)],
        grooves=[hline(-0.31, 0.31, -0.088), pocket_r, mirrored(pocket_r), fly,
                 line((0.07, -0.92), (0.35, -0.92)), mirrored(line((0.07, -0.92), (0.35, -0.92)))],
        stitches=[hline(-0.305, 0.305, -0.015), hline(-0.305, 0.305, -0.075),
                  offset_line(pocket_r, 0.012, -0.012), mirrored(offset_line(pocket_r, 0.012, -0.012)),
                  offset_line(fly, -0.015, 0.0), line((0.075, -0.935), (0.345, -0.935)),
                  mirrored(line((0.075, -0.935), (0.345, -0.935)))],
        loops=[-0.2, 0.0, 0.2],
        texture="cotton", folds=dict(fan=0.03, sag=0.02, wave=0.028, freq=3.0, legs=True))

    # --- şort
    pocket_r = chaikin([(0.18, -0.085), (0.22, -0.16), (0.33, -0.2)], 2, closed=False)
    specs["garment_shorts"] = dict(
        outline=SHORTS,
        ridges=[(hline(-0.33, 0.33, -0.045), 0.02, 0.04),
                (line((0.065, -0.56), (0.405, -0.56)), 0.012, 0.02), (mirrored(line((0.065, -0.56), (0.405, -0.56))), 0.012, 0.02)],
        grooves=[hline(-0.33, 0.33, -0.088), pocket_r, mirrored(pocket_r),
                 line((0.06, -0.53), (0.395, -0.53)), mirrored(line((0.06, -0.53), (0.395, -0.53)))],
        stitches=[hline(-0.325, 0.325, -0.015), hline(-0.325, 0.325, -0.075),
                  offset_line(pocket_r, 0.012, -0.012), mirrored(offset_line(pocket_r, 0.012, -0.012)),
                  line((0.065, -0.545), (0.4, -0.545)), mirrored(line((0.065, -0.545), (0.4, -0.545)))],
        loops=[-0.21, 0.0, 0.21],
        texture="cotton", folds=dict(fan=0.026, sag=0.018, wave=0.022, freq=2.6, legs=True))

    # --- çorap
    heel = chaikin([(0.16, -0.5), (0.08, -0.62), (-0.08, -0.7)], 2, closed=False)
    toe = chaikin([(0.29, -0.66), (0.24, -0.8), (0.27, -0.96)], 2, closed=False)
    specs["garment_sock"] = dict(
        outline=SOCK,
        ribs=[(rect(-0.16, 0.16, -0.14, 0.01), (1.0, 0.0), 0.028, 0.008)],
        ridges=[(hline(-0.15, 0.15, -0.15), 0.012, 0.02)],
        grooves=[hline(-0.15, 0.15, -0.165), heel, toe],
        stitches=[offset_line(heel, 0.0, 0.015), offset_line(toe, 0.015, 0.0)],
        texture="knit", folds=dict(fan=0.0, sag=0.0, wave=0.02, freq=1.2))
    return specs


def membrane(outline, left, bottom, span, res=384):
    """Şişirilmiş zar yüksekliği: ∇²h = −1, kenarda h = 0 (Poisson). Sonuç pürüzsüzdür;
    uzaklık alanının orta-eksen sırtları (köşegen "kırık" çizgiler) oluşmaz."""
    centers = (np.arange(res) + 0.5) / res * span
    gx, gz = np.meshgrid(left + centers, bottom + centers)
    mask = inside_polygon(gx.ravel(), gz.ravel(), outline).reshape(res, res)
    h = None
    for level in (8, 4, 2, 1):
        n = res // level
        m = mask.reshape(n, level, n, level).mean(axis=(1, 3)) > 0.5
        cell = span / n
        if h is None:
            h = np.zeros((n, n))
        else:
            h = np.kron(h, np.ones((2, 2)))[:n, :n]
        for _ in range({8: 2500, 4: 1200, 2: 600, 1: 300}[level]):
            nb = (np.roll(h, 1, 0) + np.roll(h, -1, 0) + np.roll(h, 1, 1) + np.roll(h, -1, 1))
            h_new = (nb + cell * cell) * 0.25
            h = np.where(m, h_new, 0.0)
    return h, (left, bottom, span, res)


def sample_grid(grid, frame, x, z):
    left, bottom, span, res = frame
    fx = np.clip((x - left) / span * res - 0.5, 0.0, res - 1.001)
    fz = np.clip((z - bottom) / span * res - 0.5, 0.0, res - 1.001)
    x0, z0 = fx.astype(int), fz.astype(int)
    tx, tz = fx - x0, fz - z0
    g = grid
    return ((g[z0, x0] * (1 - tx) + g[z0, x0 + 1] * tx) * (1 - tz)
            + (g[z0 + 1, x0] * (1 - tx) + g[z0 + 1, x0 + 1] * tx) * tz)


def inflate(co, outline, gain=0.42, power=0.42, edge=0.004, back=0.75):
    """Yastık hacmi: zar yüksekliğine göre ön (−y) ve arka (+y) yüz dışarı itilir.
    Kenarda h ~ uzaklık; kök alınınca kenar yuvarlak (dikey teğet) olur."""
    grid, frame = membrane(outline, G_LEFT, G_BOTTOM, G_ORTHO)
    h = np.clip(sample_grid(grid, frame, co[:, 0], co[:, 2]), 0.0, None)
    profile = gain * h ** power
    dist = seg_distance(co[:, 0], co[:, 2], outline, closed=True)
    dist = np.where(inside_polygon(co[:, 0], co[:, 2], outline), dist, 0.0)
    half = max(np.abs(co[:, 1]).max(), 1e-6)
    side = np.clip(co[:, 1] / half, -1.0, 1.0)
    scale = np.where(side < 0.0, 1.0, back)
    co[:, 1] = side * (edge + profile * scale)
    return dist, side


def feature_height(x, z, spec):
    h = np.zeros_like(x)
    for polyline, height, width in spec.get("ridges", []):
        d = seg_distance(x, z, polyline)
        h += height * np.exp(-(d / width) ** 2)
    for polygon, direction, period, height in spec.get("ribs", []):
        mask = inside_polygon(x, z, polygon).astype(np.float64)
        coord = x * direction[0] + z * direction[1]
        h += mask * height * (0.5 + 0.5 * np.cos(coord / period * math.tau))
    gathers = spec.get("gathers")
    if gathers is not None:
        # Bel altında sık, küçük büzgüler (aşağı doğru sönümlenir).
        z_top, half_width, freq, amp = gathers
        below = np.clip((z_top - z) / 0.03, 0.0, 1.0) * np.exp(-np.clip(z_top - z, 0.0, None) / 0.22)
        h += amp * below * np.sin(x * freq * math.tau) * (np.abs(x) < half_width * 2.2)
    for loop_x in spec.get("loops", []):
        # Kemer köprüleri: bel bandında küçük dikey kabarıklar.
        d = seg_distance(x, z, [(loop_x, -0.005), (loop_x, -0.085)])
        h += 0.012 * np.exp(-(d / 0.012) ** 2)
    return h


def fold_field(x, z, folds, seed, bottom):
    """Asılı kumaş kıvrımları: mandallardan yelpaze + mandallar arası sarkma + alt dalgalar."""
    rng = random.Random(seed)
    f = np.zeros_like(x)
    height = max(-bottom, 1e-6)
    t = np.clip(-z / height, 0.0, 1.0)
    ease = t * t * (3.0 - 2.0 * t)
    fan = folds.get("fan", 0.03) * FOLD_GAIN
    if fan > 0.0:
        for pin in (-PIN_X, PIN_X):
            side = 1.0 if pin > 0 else -1.0
            for k, angle in enumerate((-34.0, -14.0, 4.0, 24.0, 46.0)):
                a = math.radians(angle + rng.uniform(-5.0, 5.0))
                dx, dz = side * math.sin(a), -math.cos(a)
                rx, rz = x - pin, z + 0.012
                s = rx * dx + rz * dz
                perp = rx * dz - rz * dx
                sp = np.clip(s, 0.0, None)
                width = 0.012 + 0.11 * sp
                amp = fan * rng.uniform(0.75, 1.2) * (1.0 if k % 2 == 0 else -0.8)
                env = (1.0 - np.exp(-sp / 0.045)) * np.exp(-sp / 0.42) * (s > 0)
                f += amp * env * np.exp(-(perp / width) ** 2)
    sag = folds.get("sag", 0.02) * FOLD_GAIN
    if sag > 0.0:
        rel = np.clip(1.0 - (x / PIN_X) ** 2, 0.0, 1.0)
        for depth, amp, width in ((0.07, 1.0, 0.03), (0.16, -0.7, 0.045), (0.26, 0.5, 0.06)):
            zc = -0.03 - depth * rel
            f += sag * amp * rel * np.exp(-((z - zc) / width) ** 2)
    wave = folds.get("wave", 0.03) * FOLD_GAIN
    freq = folds.get("freq", 2.5)
    phase = seed * 1.7
    flare = folds.get("flare")
    if flare is not None:
        # Etek: belden aşağı açılan, derinleşen dikey kıvrımlar.
        below = np.clip((flare - z) / 0.5, 0.0, 1.0)
        local = below * below * (3.0 - 2.0 * below)
        spread = x / (0.35 + 0.6 * below)
        f += wave * local * (np.sin(spread * freq * math.tau + phase)
                             + 0.35 * np.sin(spread * freq * 2.1 * math.tau + phase * 1.3))
    elif folds.get("legs"):
        # Her paçada boyuna yumuşak kıvrımlar + birkaç çapraz, geniş kırışık.
        legx = np.abs(x) - 0.2
        f += wave * ease * (0.8 * np.sin(legx * freq * math.tau + phase)
                            + 0.3 * np.sin(legx * freq * 2.2 * math.tau + phase * 1.4))
        for zc, tilt, amp in ((-0.55, 0.35, 0.35), (-0.72, -0.3, -0.3)):
            d = (z - zc) - tilt * legx
            f += wave * amp * ease * np.exp(-(d / 0.035) ** 2) * np.exp(-(legx / 0.14) ** 2)
    else:
        f += wave * ease * (np.sin(x * freq * math.tau + phase + t * 1.2)
                            + 0.4 * np.sin(x * freq * 2.3 * math.tau + phase * 1.7 + t * 2.0))
    return f, ease


def make_garment(name, spec, index):
    reset()
    add_lights()
    outline = chaikin(densify(spec["outline"], 0.03), 3)
    parts = [flat_shape(name, outline, 0.024)]
    body = parts[0]
    remesh_smooth(body, voxel=0.0052, smooth_repeat=3, factor=0.5)
    co = get_co(body)
    original = co[:, [0, 2]].copy()
    dist, side = inflate(co, outline)
    front = side < 0.0
    extra = feature_height(co[:, 0], co[:, 2], spec)
    # Detaylar yalnız ön yüze (kenara yaklaştıkça sönerek) eklenir.
    edge_fade = np.clip(dist / 0.02, 0.0, 1.0)
    co[:, 1] -= np.where(front, -side, 0.0) * extra * edge_fade
    bottom = min(z for _, z in spec["outline"])
    folds, ease = fold_field(co[:, 0], co[:, 2], spec.get("folds", {}), index * 3 + 1, bottom)
    co[:, 1] += folds
    # Kıvrım diplerinde (kameradan uzaklaşan bölgeler) yumuşak temas gölgesi.
    peak = max(float(np.abs(folds).max()), 1e-6)
    cavity = 1.0 - 0.22 * np.clip(folds / peak, 0.0, 1.0) ** 1.5
    # Etek kenarı hafif dalgalı (kumaşın ağırlığı).
    co[:, 2] += 0.01 * ease ** 3 * np.sin(co[:, 0] * 2.0 * math.tau + index)
    set_co(body, co)
    add_canvas_uv(body, original, G_LEFT, G_BOTTOM, G_ORTHO)
    set_cavity(body, cavity)
    add_subsurf(body)

    detail = DetailMap()
    for polyline in spec.get("grooves", []):
        detail.groove(polyline)
    for polyline in spec.get("stitches", []):
        detail.stitches(polyline)
    mat = fabric_material("Cloth", detail.images(name), spec.get("texture", "cotton"), cavity=True)
    body.data.materials.append(mat)

    if "back" in spec:
        # Yaka açıklığından görünen arka panelin içi: önün biraz arkasında, gölgede kalır.
        back_outline = chaikin(densify(spec["back"], 0.02), 2)
        back = flat_shape(name + "_back", back_outline, 0.02)
        remesh_smooth(back, voxel=0.0052, smooth_repeat=3, factor=0.5)
        bco = get_co(back)
        borig = bco[:, [0, 2]].copy()
        bco[:, 1] += 0.065
        bfold, _ = fold_field(bco[:, 0], bco[:, 2], spec.get("folds", {}), index * 3 + 1, bottom)
        bco[:, 1] += bfold
        set_co(back, bco)
        add_canvas_uv(back, borig, G_LEFT, G_BOTTOM, G_ORTHO)
        set_cavity(back, np.full(len(bco), 0.82))
        back.data.materials.append(mat)
        add_subsurf(back)

    add_camera(center_z=G_CENTER_Z, ortho_scale=G_ORTHO, res_x=768, res_y=768)
    render(name, 768, 768)


# ----------------------------------------------------------------------------- katlanmış parça

def make_folded():
    reset()
    add_lights()
    # Yan kesit (y-z): önde tam yuvarlak kat kenarı, arkada daha düz köşeler.
    hh = 0.15
    front = 0.12
    # Önde tek, dolgun, yuvarlak kat kenarı; arkada daha düz köşeler. Üç parça üst üste
    # yığıldığında her parça kendi kat kenarıyla ayrı okunur.
    profile = [(-0.26, hh), (0.0, hh + 0.006), (front, hh)]
    profile += [(front + hh * 1.05 * math.cos(math.radians(a)), hh * math.sin(math.radians(a)))
                for a in range(80, -81, -8)]
    profile += [(front, -hh), (0.0, -hh), (-0.26, -hh), (-0.29, -hh + 0.03), (-0.3, 0.0), (-0.29, hh - 0.03)]
    # Kesit XY düzleminde çizilip x boyunca kalınlaştırılır: önce y-z düzlemine çevrilir.
    curve = bpy.data.curves.new("fold", "CURVE")
    curve.dimensions = "2D"
    curve.fill_mode = "BOTH"
    spline = curve.splines.new("POLY")
    pts = chaikin(densify(profile, 0.012), 2)
    spline.points.add(len(pts) - 1)
    for point, (y, z) in zip(spline.points, pts):
        point.co = (y, z, 0.0, 1.0)
    spline.use_cyclic_u = True
    obj = bpy.data.objects.new("folded", curve)
    bpy.context.scene.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    obj = bpy.context.view_layer.objects.active
    solid = obj.modifiers.new("Solid", "SOLIDIFY")
    solid.thickness = 0.86
    solid.offset = 0.0
    bpy.ops.object.modifier_apply(modifier="Solid")
    # Yerel (y, z, x) -> dünya: eğri X'i = derinlik (−y öne), eğri Y'si = z, kalınlık = x.
    mesh_co = get_co(obj)
    world = np.stack([mesh_co[:, 2], -mesh_co[:, 0], mesh_co[:, 1]], axis=1)
    set_co(obj, world)
    obj.data.flip_normals()
    remesh_smooth(obj, voxel=0.005, smooth_repeat=8, factor=0.6)
    co = get_co(obj)
    x, y, z = co[:, 0], co[:, 1], co[:, 2]
    # Yanlar dolgun: x uçları yuvarlanır (yastık gibi).
    end = np.clip((np.abs(x) - 0.33) / 0.1, 0.0, 1.0)
    co[:, 2] = z * (1.0 - 0.45 * end ** 2)
    co[:, 1] = y * (1.0 - 0.08 * end ** 2)
    top = np.clip((z - 0.5 * hh) / (0.5 * hh), 0.0, 1.0)
    # Üst yüz hafif kubbe.
    co[:, 2] += 0.026 * top * (1.0 - (x / 0.45) ** 2).clip(0) * (1.0 - ((y + 0.03) / 0.33) ** 2).clip(0)
    # Ön kat kenarında yumuşak kırışıklar.
    frontness = np.clip((-y - 0.15) / 0.1, 0.0, 1.0)
    co[:, 1] -= 0.007 * frontness * np.sin(x * 20.0 + 0.4)
    # Yan yüzlerde katman çizgisi.
    sideness = np.clip((np.abs(x) - 0.36) / 0.06, 0.0, 1.0)
    co[:, 0] -= np.sign(x) * 0.01 * sideness * np.exp(-(z / 0.01) ** 2)
    set_co(obj, co)
    add_subsurf(obj)
    detail = DetailMap(512, -0.5, -0.5, 1.0)
    # Üst katın kenarında dikiş (üstten bakış: UV = x, y).
    detail.stitches(hline(-0.38, 0.38, -0.16), dash=0.018, gap=0.011, width=0.0045, darken=0.2)
    add_canvas_uv(obj, np.stack([co[:, 0], co[:, 1]], axis=1), -0.5, -0.5, 1.0)
    # Katlar arasındaki oluk ve alt kenar: temas gölgesi.
    fin = get_co(obj)
    fr = np.clip((-fin[:, 1] - 0.05) / 0.12, 0.0, 1.0)
    # Kat kenarının alt yarısı ve taban: yığında parçaları ayıran yumuşak temas gölgesi.
    under = np.clip((-fin[:, 2] - 0.35 * hh) / (0.65 * hh), 0.0, 1.0) * (0.4 + 0.6 * fr)
    set_cavity(obj, 1.0 - 0.3 * under ** 1.5)
    obj.data.materials.append(fabric_material("Cloth", detail.images("folded"), "cotton", uv_scale=1.4, cavity=True))
    tilt = math.radians(24.0)
    screen_v = fin[:, 1] * math.sin(tilt) + fin[:, 2] * math.cos(tilt)
    center_z = 0.5 * (screen_v.max() + screen_v.min()) / math.cos(tilt)
    add_camera(center_z=center_z, ortho_scale=0.98, res_x=256, res_y=256, tilt_deg=24.0)
    render("folded", 256, 256)


# ----------------------------------------------------------------------------- mandal

def inflate_object(obj, outline, puff, radius, half_depth_min=0.004):
    co = get_co(obj)
    dist = seg_distance(co[:, 0], co[:, 2], outline, closed=True)
    dist = np.where(inside_polygon(co[:, 0], co[:, 2], outline), dist, 0.0)
    u = np.clip(dist / radius, 0.0, 1.0)
    profile = puff * np.sqrt(np.clip(1.0 - (1.0 - u) ** 2, 0.0, 1.0))
    half = max(np.abs(co[:, 1]).max(), 1e-6)
    side = np.clip(co[:, 1] / half, -1.0, 1.0)
    co[:, 1] = side * (half_depth_min + profile)
    set_co(obj, co)


def make_pin():
    reset()
    add_lights(key=2.6, fill=0.6, rim=1.8)
    wood = wood_material("Wood")
    metal = metal_material("Metal")
    fulcrum = -0.42
    halves = []
    for side in (1.0, -1.0):
        right = [(0.03, 0.0), (0.075, 0.004), (0.108, -0.025), (0.118, -0.12), (0.114, -0.25),
                 (0.1, -0.33), (0.085, -0.37), (0.082, -0.47), (0.098, -0.51), (0.11, -0.58),
                 (0.098, -0.72), (0.066, -0.85), (0.034, -0.935), (0.012, -0.94), (0.007, -0.84),
                 (0.007, -0.745), (0.024, -0.73), (0.034, -0.705), (0.024, -0.68), (0.007, -0.665),
                 (0.007, -0.47), (0.016, -0.455), (0.024, -0.42), (0.016, -0.385), (0.01, -0.37),
                 (0.022, -0.2), (0.03, -0.06)]
        outline = chaikin([(side * x, z) for x, z in right] if side > 0 else
                          [(side * x, z) for x, z in reversed(right)], 2)
        half = flat_shape("half", outline, 0.02)
        remesh_smooth(half, voxel=0.004, smooth_repeat=3, factor=0.5)
        inflate_object(half, outline, puff=0.046, radius=0.03)
        add_subsurf(half)
        half.data.materials.append(wood)
        halves.append(half)
    # Yay: y ekseninde sarmal + iki kol (biri önde sola, biri arkada sağa).
    turns, coil_r, wire = 4.5, 0.036, 0.0085
    pts = []
    steps = 200
    for i in range(steps + 1):
        t = i / steps
        a = t * turns * math.tau + math.pi * 0.5
        pts.append((coil_r * math.cos(a), -0.05 + 0.1 * t, fulcrum + coil_r * math.sin(a)))
    start, end = pts[0], pts[-1]
    arm_front = [(-0.112 + 0.004, -0.05, -0.2), (-0.118, -0.05, -0.3), (-0.07, -0.05, -0.39), (start[0], start[1], start[2])]
    arm_back = [(end[0], end[1], end[2]), (0.07, 0.05, -0.39), (0.118, 0.05, -0.3), (0.112 - 0.004, 0.05, -0.2)]
    wire_pts = chaikin(arm_front, 2, closed=False) + pts + chaikin(arm_back, 2, closed=False)
    curve = bpy.data.curves.new("spring", "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = wire
    curve.bevel_resolution = 6
    curve.use_fill_caps = True
    spline = curve.splines.new("POLY")
    spline.points.add(len(wire_pts) - 1)
    for point, p in zip(spline.points, wire_pts):
        point.co = (*p, 1.0)
    spring = bpy.data.objects.new("spring", curve)
    bpy.context.scene.collection.objects.link(spring)
    spring.data.materials.append(metal)
    bpy.context.view_layer.objects.active = spring
    spring.select_set(True)
    bpy.ops.object.shade_smooth()
    add_camera(center_z=-0.47, ortho_scale=1.0, res_x=128, res_y=256, yaw_deg=-22.0)
    render("pin", 128, 256)


# ----------------------------------------------------------------------------- sepet

def tube(name, points, radius, mat, cyclic=False, resolution=6, tone=None):
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = radius
    curve.bevel_resolution = resolution
    curve.use_fill_caps = not cyclic
    spline = curve.splines.new("POLY")
    spline.points.add(len(points) - 1)
    for point, p in zip(spline.points, points):
        point.co = (*p, 1.0)
    spline.use_cyclic_u = cyclic
    obj = bpy.data.objects.new(name, curve)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(mat)
    if tone is not None:
        obj["tone"] = tone
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    obj = bpy.context.view_layer.objects.active
    bpy.ops.object.shade_smooth()
    obj.select_set(False)
    return obj


BASKET_TOP, BASKET_BOTTOM = 0.27, -0.3
STAKES = 28
BASKET_LINER = False
ROWS = 11


def basket_radius(z):
    t = (z - BASKET_BOTTOM) / (BASKET_TOP - BASKET_BOTTOM)
    return 0.345 + 0.085 * t + 0.02 * math.sin(math.pi * t)


def basket_parts():
    """Örgü sepet: dikey çubuklar + aralarından alt-üst geçen yatay hasır sıralar."""
    wicker = wicker_material("Wicker")
    rng = random.Random(7)
    parts = []
    # Dikey çubuklar (çoğu örgünün arkasında; aralardan görünür).
    for k in range(STAKES):
        a = k / STAKES * math.tau
        pts = []
        for i in range(13):
            z = BASKET_BOTTOM + (BASKET_TOP - 0.02 - BASKET_BOTTOM) * i / 12
            r = basket_radius(z)
            pts.append((r * math.cos(a), r * math.sin(a), z))
        parts.append(tube("stake", pts, 0.013, wicker, tone=rng.uniform(0.0, 0.2)))
    # Yatay örgü: her sıra çubuklar arasında içe/dışa dalgalanır, komşu sıra ters fazda.
    pitch = (BASKET_TOP - 0.035 - BASKET_BOTTOM - 0.02) / (ROWS - 1)
    for row in range(ROWS):
        z0 = BASKET_BOTTOM + 0.02 + row * pitch
        pts = []
        samples = STAKES * 10
        for i in range(samples):
            a = i / samples * math.tau
            weave = math.cos(a * STAKES / 2.0 + row * math.pi)
            r = basket_radius(z0) + 0.014 * weave
            z = z0 + 0.003 * math.sin(a * 3 + row)
            pts.append((r * math.cos(a), r * math.sin(a), z))
        flat = tube("row", pts, pitch * 0.55, wicker, cyclic=True, resolution=8, tone=rng.uniform(0.0, 0.45))
        # Hasır şerit yassıdır: kesit radyal yönde ezilir (yuvarlak ip gibi değil).
        co = get_co(flat)
        ang = np.arctan2(co[:, 1], co[:, 0])
        rv = np.hypot(co[:, 0], co[:, 1])
        rp = basket_radius(z0) + 0.014 * np.cos(ang * STAKES / 2.0 + row * math.pi)
        rn = rp + (rv - rp) * 0.42
        co[:, 0], co[:, 1] = np.cos(ang) * rn, np.sin(ang) * rn
        set_co(flat, co)
        parts.append(flat)
    # Taban halkası (kalın, yuvarlak) ve taban.
    base_pts = [(basket_radius(BASKET_BOTTOM) * math.cos(i / 160 * math.tau),
                 basket_radius(BASKET_BOTTOM) * math.sin(i / 160 * math.tau), BASKET_BOTTOM) for i in range(160)]
    parts.append(tube("foot", base_pts, 0.026, wicker, cyclic=True, resolution=8, tone=0.15))
    # İç astar: aralardan arka plan görünmesin; içi yumuşak, sıcak gölgede.
    inner = principled("Inner", (0.45, 0.33, 0.2), 0.85)[0]
    bpy.ops.mesh.primitive_cylinder_add(vertices=128, radius=1.0, depth=1.0, location=(0, 0, 0), end_fill_type="NOTHING")
    liner = bpy.context.view_layer.objects.active
    for v in liner.data.vertices:
        z = BASKET_BOTTOM + (v.co.z + 0.5) * (BASKET_TOP - 0.01 - BASKET_BOTTOM)
        r = basket_radius(z) - 0.03
        length = math.hypot(v.co.x, v.co.y)
        v.co.x, v.co.y, v.co.z = v.co.x / length * r, v.co.y / length * r, z
    bpy.ops.object.shade_smooth()
    liner.data.materials.append(inner)
    parts.append(liner)
    liner.hide_render = not BASKET_LINER
    bpy.ops.mesh.primitive_circle_add(vertices=128, radius=basket_radius(BASKET_BOTTOM) - 0.02, fill_type="NGON",
                                      location=(0, 0, BASKET_BOTTOM + 0.015))
    floor = bpy.context.view_layer.objects.active
    floor.data.materials.append(inner)
    parts.append(floor)
    # Arka duvarın dışında koyu perde: içeriden bakınca örgü aralıkları boşluk değil gölge görünür.
    shade = principled("Backing", (0.3, 0.2, 0.11), 0.9)[0]
    mesh = bpy.data.meshes.new("backing")
    verts, faces = [], []
    cols, rows = 64, 8
    for j in range(rows + 1):
        z = BASKET_BOTTOM + (BASKET_TOP - 0.03 - BASKET_BOTTOM) * j / rows
        for i in range(cols + 1):
            a = math.radians(35 + 110 * i / cols)
            r = basket_radius(z) + 0.03
            verts.append((r * math.cos(a), r * math.sin(a), z))
    for j in range(rows):
        for i in range(cols):
            k = j * (cols + 1) + i
            faces.append((k, k + 1, k + cols + 2, k + cols + 1))
    mesh.from_pydata(verts, [], faces)
    backing = bpy.data.objects.new("backing", mesh)
    bpy.context.scene.collection.objects.link(backing)
    backing.data.materials.append(shade)
    parts.append(backing)

    # Yan tutamaklar: ağzın altında, dışa taşan "D" biçimli hasır kulplar.
    for side in (-1.0, 1.0):
        pts = []
        for i in range(41):
            t = i / 40
            z = 0.2 - 0.15 * t
            pts.append((side * (basket_radius(z) - 0.005 + 0.07 * math.sin(math.pi * t) ** 0.8), 0.0, z))
        parts.append(tube("handle", pts, 0.021, wicker, resolution=8, tone=0.2))

    # Ağız bandı (oyunda renklenir): dolgun, kumaş kaplı yuvarlak kenar + iki sıra dikiş.
    band_mat = fabric_material("Band", None, "cotton", uv_scale=1.0)
    bpy.ops.mesh.primitive_torus_add(major_radius=basket_radius(BASKET_TOP) + 0.005, minor_radius=0.058,
                                     location=(0, 0, BASKET_TOP), major_segments=256, minor_segments=48)
    band = bpy.context.view_layer.objects.active
    band.scale = (1.0, 1.0, 1.12)
    co = get_co(band)
    angle = np.arctan2(co[:, 1], co[:, 0])
    radial = np.hypot(co[:, 0], co[:, 1])
    tube_r = basket_radius(BASKET_TOP) + 0.005
    rel = radial - tube_r
    # Hafif büzgü: kumaş, kenarın etrafında dalgalanır.
    wobble = 1.0 + 0.045 * np.sin(angle * 30.0) + 0.025 * np.sin(angle * 11.0 + 1.0)
    co[:, 0] = np.cos(angle) * (tube_r + rel * wobble)
    co[:, 1] = np.sin(angle) * (tube_r + rel * wobble)
    co[:, 2] = co[:, 2] * wobble
    set_co(band, co)
    bpy.ops.object.shade_smooth()
    add_subsurf(band)
    band.data.materials.append(band_mat)
    _add_band_stitches(band_mat, tube_r)
    return parts, band


def _add_band_stitches(mat, tube_r):
    """Bandın üst ve alt kenarına yakın, çevre boyunca kesik dikiş (gölgelendiricide)."""
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes["Principled BSDF"]
    coords = nodes.new("ShaderNodeTexCoord")
    sep = nodes.new("ShaderNodeSeparateXYZ")
    links.new(coords.outputs["Object"], sep.inputs[0])
    atan = nodes.new("ShaderNodeMath")
    atan.operation = "ARCTAN2"
    links.new(sep.outputs["Y"], atan.inputs[0])
    links.new(sep.outputs["X"], atan.inputs[1])
    dash = nodes.new("ShaderNodeMath")
    dash.operation = "MULTIPLY"
    dash.inputs[1].default_value = 140.0 / math.tau
    links.new(atan.outputs[0], dash.inputs[0])
    frac = nodes.new("ShaderNodeMath")
    frac.operation = "FRACT"
    links.new(dash.outputs[0], frac.inputs[0])
    on = nodes.new("ShaderNodeMath")
    on.operation = "LESS_THAN"
    on.inputs[1].default_value = 0.6
    links.new(frac.outputs[0], on.inputs[0])
    total = None
    for offset in (0.034, -0.034):
        dz = nodes.new("ShaderNodeMath")
        dz.operation = "SUBTRACT"
        dz.inputs[1].default_value = offset
        links.new(sep.outputs["Z"], dz.inputs[0])
        absz = nodes.new("ShaderNodeMath")
        absz.operation = "ABSOLUTE"
        links.new(dz.outputs[0], absz.inputs[0])
        line_mask = nodes.new("ShaderNodeMath")
        line_mask.operation = "LESS_THAN"
        line_mask.inputs[1].default_value = 0.0035
        links.new(absz.outputs[0], line_mask.inputs[0])
        total = line_mask if total is None else _add(nodes, links, total, line_mask)
    mask = nodes.new("ShaderNodeMath")
    mask.operation = "MULTIPLY"
    links.new(total.outputs[0], mask.inputs[0])
    links.new(on.outputs[0], mask.inputs[1])
    bump = nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.5
    bump.inputs["Distance"].default_value = 0.003
    links.new(mask.outputs[0], bump.inputs["Height"])
    old = bsdf.inputs["Normal"].links[0].from_socket if bsdf.inputs["Normal"].links else None
    if old is not None:
        links.new(old, bump.inputs["Normal"])
    links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    shade = nodes.new("ShaderNodeMath")
    shade.operation = "MULTIPLY_ADD"
    shade.inputs[1].default_value = -0.1
    shade.inputs[2].default_value = 0.93
    links.new(mask.outputs[0], shade.inputs[0])
    links.new(shade.outputs[0], bsdf.inputs["Base Color"])


def _add(nodes, links, a, b):
    node = nodes.new("ShaderNodeMath")
    node.operation = "ADD"
    links.new(a.outputs[0], node.inputs[0])
    links.new(b.outputs[0], node.inputs[1])
    return node


def make_basket():
    for target in ("basket_body", "basket_band"):
        reset()
        add_lights(key=2.4, fill=0.6, rim=1.6)
        body_parts, band = basket_parts()
        if target == "basket_body":
            # Bant "holdout": gövdede bandın yeri boş kalır (bant tam o boşluğa oturur),
            # ama bant gölgesini hasıra yine düşürür.
            band.is_holdout = True
        else:
            for part in body_parts:
                part.is_holdout = True
        add_camera(center_z=0.03, ortho_scale=1.12, res_x=512, res_y=512, tilt_deg=24.0)
        render(target, 512, 512)


# ----------------------------------------------------------------------------- giriş

def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    wanted = set(argv)
    for index, (name, spec) in enumerate(garment_specs().items()):
        if not wanted or name in wanted:
            make_garment(name, spec, index)
    if not wanted or "folded" in wanted:
        make_folded()
    if not wanted or "pin" in wanted:
        make_pin()
    if not wanted or wanted & {"basket_body", "basket_band"}:
        make_basket()


main()
