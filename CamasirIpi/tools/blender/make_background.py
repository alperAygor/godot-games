#!/usr/bin/env python3
"""Çamaşır İpi — bahçe arka planı katmanları (Blender, headless, EEVEE).

    /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/make_background.py
    ... -- bg_far cloud_1          # yalnız adı verilenler
    ... -- --preview               # yarım çözünürlük, az örnek (hızlı deneme)

Çıktılar: assets/sprites/bg/*.png (RGBA, şeffaf zemin). Betik idempotenttir: her katman
fabrika ayarlarından sıfırdan kurulur, aynı tohumla aynı PNG çıkar.

Kural 1 (kullanıcı): low-poly YOK. Teknikler:
  * Yapraklar / bulutlar / çalılar: metaball kümeleri -> mesh -> yumuşatma + smooth shading
    (iri, tombul, oyuncak gibi yuvarlak kümeler; kıvrımlarda AO düğümüyle yumuşak gölge).
  * Tahta parçalar (çit, direk, raf): yoğun 2B dış hat -> eğri extrude + yuvarlak bevel.
  * Gövde / dallar / kancalar: yarıçaplı eğri tüpler -> voxel remesh + smooth (dikişsiz).
  * Tepeler: yüksek çözünürlüklü elipsoidler; derinliğe göre pus (emission karışımı).
Işık: sol-üst-önden yumuşak güneş (geniş açı) + mavimsi gökyüzü dolgu ışığı; Standard görünüm.
Ölçek: 1 Blender birimi = 100 piksel (orto kamera).
"""

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_DIR = os.path.join(ROOT, "assets", "sprites", "bg")
PPU = 100.0  # piksel / birim
MBALL_K = 0.575
SUN_GAIN = math.pi  # güneş gücü W/m²; beyaz difüz yüzeyde ~1.0 parlaklık için pi ile çarpılır  # tek metaball elemanında yüzey yarıçapı = radius * MBALL_K (eşik 0.6)

ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
PREVIEW = "--preview" in ARGV
WANTED = {a for a in ARGV if not a.startswith("--")}


# ---------------------------------------------------------------------------- renk / sahne

def lin(hex_color):
    """'#RRGGBB' (sRGB) -> lineer RGB demeti."""
    h = hex_color.lstrip("#")
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return tuple(out)


def reset(samples=64):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _MATS.clear()
    scene = bpy.context.scene
    for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            scene.render.engine = engine
            break
        except TypeError:
            continue
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.render.filter_size = 1.2
    eevee = scene.eevee
    eevee.taa_render_samples = 12 if PREVIEW else samples
    for attr, value in (("use_raytracing", True), ("use_fast_gi", True), ("fast_gi_distance", 1.2),
                        ("shadow_ray_count", 3), ("shadow_step_count", 12),
                        ("shadow_resolution_scale", 1.0)):
        try:
            setattr(eevee, attr, value)
        except (AttributeError, TypeError):
            pass
    try:
        eevee.ray_tracing_method = "SCREEN"
    except (AttributeError, TypeError):
        pass
    return scene


def light_rig(sun=1.1, sky=0.48, sky_color="#DCEBFF", sun_color="#FFF6E6",
              direction=(0.62, 0.42, -0.66), angle=18.0, rim=0.0):
    """Yumuşak güneş (sol-üst-ön) + gökyüzü dolgu. rim>0: arkadan ince parlak kenar."""
    scene = bpy.context.scene
    world = bpy.data.worlds.new("World")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (*lin(sky_color), 1.0)
    bg.inputs[1].default_value = sky

    def sun_light(name, energy, dirv, color, ang):
        data = bpy.data.lights.new(name, "SUN")
        data.energy = energy
        data.color = lin(color)
        data.angle = math.radians(ang)
        try:
            data.use_shadow_jitter = True
            data.shadow_jitter_overblur = 10.0
        except AttributeError:
            pass
        obj = bpy.data.objects.new(name, data)
        obj.rotation_euler = Vector(dirv).normalized().to_track_quat("-Z", "Y").to_euler()
        scene.collection.objects.link(obj)
        return obj

    sun_light("Sun", sun * SUN_GAIN, direction, sun_color, angle)
    if rim > 0.0:
        sun_light("Rim", rim * SUN_GAIN, (-0.35, -0.75, -0.55), "#FFFFFF", 30.0)


def camera(res_x, res_y, cx=0.0, cz=0.0, tilt=0.0):
    """Orto kamera; hedef (cx, 0, cz) çerçeve merkezinde; tilt = aşağı bakış açısı (derece)."""
    scene = bpy.context.scene
    data = bpy.data.cameras.new("Cam")
    data.type = "ORTHO"
    data.ortho_scale = max(res_x, res_y) / PPU
    data.clip_start = 0.1
    data.clip_end = 400.0
    obj = bpy.data.objects.new("Cam", data)
    t = math.radians(tilt)
    view = Vector((0.0, math.cos(t), -math.sin(t)))
    obj.location = Vector((cx, 0.0, cz)) - view * 120.0
    obj.rotation_euler = (math.radians(90.0) - t, 0.0, 0.0)
    scene.collection.objects.link(obj)
    scene.camera = obj
    scene.render.resolution_x = res_x
    scene.render.resolution_y = res_y
    scene.render.resolution_percentage = 50 if PREVIEW else 100


def render(name):
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, name + ".png")
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("yazıldı:", os.path.relpath(path, ROOT))


def wanted(name):
    return not WANTED or name in WANTED


# ---------------------------------------------------------------------------- malzeme

_MATS = {}


def _mix(nodes, links, fac, a, b, blend="MIX"):
    node = nodes.new("ShaderNodeMix")
    node.data_type = "RGBA"
    node.blend_type = blend
    sock = {s.identifier: s for s in node.inputs}
    if isinstance(fac, float):
        sock["Factor_Float"].default_value = fac
    else:
        links.new(fac, sock["Factor_Float"])
    for key, value in (("A_Color", a), ("B_Color", b)):
        if isinstance(value, tuple):
            sock[key].default_value = (*value[:3], 1.0)
        else:
            links.new(value, sock[key])
    return [s for s in node.outputs if s.identifier == "Result_Color"][0]


def mat(name, base, top=None, rough=0.75, haze=0.0, haze_color="#D6EAF0", ao=0.55, ao_dist=0.5,
        noise=0.0, noise_scale=2.5, grain=0.0, grain_scale=14.0, grain_dir="X", bump=0.0,
        bump_scale=9.0, grad=(0.0, 1.0), grad_axis="Z", coords="Generated", metallic=0.0,
        sheen=0.0, spec=0.35, coat=0.0, stripes=0.0, stripe_scale=0.5):
    """Principled tabanlı yumuşak malzeme.

    base/top: alt->üst renk geçişi (Generated koordinatta grad aralığı).
    noise: düşük frekanslı ton oynaması; grain: tahta lifi; ao: kıvrım gölgesi; haze: pus.
    """
    key = name
    if key in _MATS:
        return _MATS[key]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nodes, links = m.node_tree.nodes, m.node_tree.links
    bsdf = nodes["Principled BSDF"]
    out = nodes["Material Output"]
    texco = nodes.new("ShaderNodeTexCoord")
    co = texco.outputs[coords]

    color = lin(base)
    col_socket = None
    if top is not None:
        sep = nodes.new("ShaderNodeSeparateXYZ")
        links.new(co, sep.inputs[0])
        rng = nodes.new("ShaderNodeMapRange")
        rng.inputs["From Min"].default_value = grad[0]
        rng.inputs["From Max"].default_value = grad[1]
        rng.clamp = True
        links.new(sep.outputs[grad_axis], rng.inputs["Value"])
        smooth = nodes.new("ShaderNodeMapRange")
        smooth.interpolation_type = "SMOOTHSTEP"
        links.new(rng.outputs["Result"], smooth.inputs["Value"])
        col_socket = _mix(nodes, links, smooth.outputs["Result"], color, lin(top))
    else:
        col_socket = _mix(nodes, links, 0.0, color, color)

    obj_co = texco.outputs["Object"]
    if noise > 0.0:
        tex = nodes.new("ShaderNodeTexNoise")
        tex.inputs["Scale"].default_value = noise_scale
        tex.inputs["Detail"].default_value = 3.0
        links.new(obj_co, tex.inputs["Vector"])
        rr = nodes.new("ShaderNodeMapRange")
        rr.inputs["From Min"].default_value = 0.3
        rr.inputs["From Max"].default_value = 0.7
        rr.inputs["To Min"].default_value = 1.0 - noise
        rr.inputs["To Max"].default_value = 1.0 + noise
        links.new(tex.outputs["Fac"], rr.inputs["Value"])
        gray = nodes.new("ShaderNodeCombineXYZ")
        for i in range(3):
            links.new(rr.outputs["Result"], gray.inputs[i])
        col_socket = _mix(nodes, links, 1.0, col_socket, gray.outputs[0], "MULTIPLY")
    if grain > 0.0:
        wave = nodes.new("ShaderNodeTexWave")
        wave.wave_type = "BANDS"
        wave.bands_direction = grain_dir
        wave.inputs["Scale"].default_value = grain_scale
        wave.inputs["Distortion"].default_value = 7.0
        wave.inputs["Detail"].default_value = 3.0
        wave.inputs["Detail Scale"].default_value = 1.5
        links.new(obj_co, wave.inputs["Vector"])
        rr = nodes.new("ShaderNodeMapRange")
        rr.inputs["To Min"].default_value = 1.0 - grain
        rr.inputs["To Max"].default_value = 1.0
        links.new(wave.outputs["Fac"], rr.inputs["Value"])
        gray = nodes.new("ShaderNodeCombineXYZ")
        for i in range(3):
            links.new(rr.outputs["Result"], gray.inputs[i])
        col_socket = _mix(nodes, links, 1.0, col_socket, gray.outputs[0], "MULTIPLY")
    if stripes > 0.0:
        # Biçilmiş çim şeritleri: yumuşak sinüs bantları (X yönünde).
        wave = nodes.new("ShaderNodeTexWave")
        wave.wave_type = "BANDS"
        wave.bands_direction = "X"
        wave.wave_profile = "SIN"
        wave.inputs["Scale"].default_value = stripe_scale
        wave.inputs["Distortion"].default_value = 0.0
        links.new(obj_co, wave.inputs["Vector"])
        rr = nodes.new("ShaderNodeMapRange")
        rr.inputs["To Min"].default_value = 1.0 - stripes
        rr.inputs["To Max"].default_value = 1.0 + stripes
        links.new(wave.outputs["Fac"], rr.inputs["Value"])
        gray = nodes.new("ShaderNodeCombineXYZ")
        for i in range(3):
            links.new(rr.outputs["Result"], gray.inputs[i])
        col_socket = _mix(nodes, links, 1.0, col_socket, gray.outputs[0], "MULTIPLY")
    if ao > 0.0:
        aon = nodes.new("ShaderNodeAmbientOcclusion")
        aon.inputs["Distance"].default_value = ao_dist
        aon.samples = 16
        links.new(col_socket, aon.inputs["Color"])
        col_socket = _mix(nodes, links, ao, col_socket, aon.outputs["Color"])
    links.new(col_socket, bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metallic
    for sock_name, value in (("Specular IOR Level", spec), ("Sheen Weight", sheen),
                             ("Coat Weight", coat)):
        if sock_name in bsdf.inputs:
            bsdf.inputs[sock_name].default_value = value
    if sheen > 0.0 and "Sheen Tint" in bsdf.inputs:
        bsdf.inputs["Sheen Tint"].default_value = (1.0, 1.0, 1.0, 1.0)
    if bump > 0.0:
        tex = nodes.new("ShaderNodeTexNoise")
        tex.inputs["Scale"].default_value = bump_scale
        tex.inputs["Detail"].default_value = 4.0
        links.new(obj_co, tex.inputs["Vector"])
        bn = nodes.new("ShaderNodeBump")
        bn.inputs["Strength"].default_value = bump
        bn.inputs["Distance"].default_value = 0.02
        links.new(tex.outputs["Fac"], bn.inputs["Height"])
        links.new(bn.outputs["Normal"], bsdf.inputs["Normal"])
    if haze > 0.0:
        emis = nodes.new("ShaderNodeEmission")
        emis.inputs["Color"].default_value = (*lin(haze_color), 1.0)
        emis.inputs["Strength"].default_value = 1.0
        mix = nodes.new("ShaderNodeMixShader")
        mix.inputs[0].default_value = haze
        links.new(bsdf.outputs[0], mix.inputs[1])
        links.new(emis.outputs[0], mix.inputs[2])
        links.new(mix.outputs[0], out.inputs["Surface"])
    _MATS[key] = m
    return m


# ---------------------------------------------------------------------------- geometri

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


def smooth_mesh(obj, factor=0.5, repeat=6):
    activate(obj)
    if repeat > 0:
        mod = obj.modifiers.new("Smooth", "SMOOTH")
        mod.factor = factor
        mod.iterations = repeat
        bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.ops.object.shade_smooth()
    return obj


def remesh(obj, voxel, repeat=8):
    activate(obj)
    mod = obj.modifiers.new("Remesh", "REMESH")
    mod.mode = "VOXEL"
    mod.voxel_size = voxel
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return smooth_mesh(obj, 0.6, repeat)


_BLOB_ID = [0]


def blob(balls, material, res=0.05, smooth=6, name="Blob", stiffness=2.0, threshold=0.6):
    """Metaball kümesi -> pürüzsüz mesh. balls: (x, y, z, r[, sx, sy, sz]) — r yüzey yarıçapı."""
    _BLOB_ID[0] += 1
    uname = "%s%d" % (name, _BLOB_ID[0])
    mb = bpy.data.metaballs.new(uname)
    mb.resolution = res
    mb.render_resolution = res
    mb.threshold = threshold
    obj = link(bpy.data.objects.new(uname, mb))
    for ball in balls:
        x, y, z, r = ball[:4]
        el = mb.elements.new()
        el.co = (x, y, z)
        el.radius = r / MBALL_K
        el.stiffness = stiffness
        if len(ball) > 4:
            el.type = "ELLIPSOID"
            el.size_x, el.size_y, el.size_z = ball[4], ball[5], ball[6]
    activate(obj)
    bpy.ops.object.convert(target="MESH")
    obj = bpy.context.view_layer.objects.active
    smooth_mesh(obj, 0.5, smooth)
    return assign(obj, material)


def ellipsoid(loc, scale, material, rot=(0.0, 0.0, 0.0), segments=96, rings=48):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=1.0,
                                         location=loc, rotation=rot)
    obj = bpy.context.view_layer.objects.active
    obj.scale = scale
    bpy.ops.object.shade_smooth()
    return assign(obj, material)


def slab(outline, depth, bevel, material, y=0.0, name="Slab", rot_z=0.0, loc=(0.0, 0.0)):
    """XZ düzleminde dolu 2B dış hat; Y yönünde kalınlık; tüm kenarlar yuvarlak bevel."""
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "2D"
    curve.fill_mode = "BOTH"
    curve.extrude = max(depth * 0.5 - bevel, 0.0)
    curve.bevel_depth = bevel
    curve.bevel_resolution = 6
    try:
        curve.bevel_mode = "ROUND"
    except AttributeError:
        pass
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
    if rot_z:
        obj.rotation_euler.y = math.radians(rot_z)
    return assign(obj, material)


def tube(points, material, name="Tube", res=8, caps=True):
    """Yarıçaplı çoklu nokta borusu: points = [(x, y, z, r), ...]."""
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = 1.0
    curve.bevel_resolution = res
    curve.use_fill_caps = caps
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


def rounded_box(loc, size, bevel, material, segments=6, rot=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    obj = bpy.context.view_layer.objects.active
    obj.scale = size
    bpy.ops.object.transform_apply(scale=True)
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = bevel
    mod.segments = segments
    mod.limit_method = "NONE"
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.ops.object.shade_smooth()
    wn = obj.modifiers.new("WN", "WEIGHTED_NORMAL")
    wn.keep_sharp = False
    wn.weight = 100
    return assign(obj, material)


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


def arc(cx, cz, rx, rz, a0, a1, steps):
    return [(cx + rx * math.cos(math.radians(a0 + (a1 - a0) * i / steps)),
             cz + rz * math.sin(math.radians(a0 + (a1 - a0) * i / steps))) for i in range(steps + 1)]


def foliage(rng, center, rx, ry, rz, big=7, small=26, big_r=0.55, small_r=0.32, flat_bottom=0.0):
    """Tombul yaprak kümesi: iç çekirdek + yüzeye dağılmış küçük top kümeler (öne/üste ağırlıklı)."""
    cx, cy, cz = center
    balls = []
    for _ in range(big):
        while True:
            u, v, w = rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1)
            if u * u + v * v + w * w <= 1.0:
                break
        balls.append((cx + u * rx * 0.5, cy + v * ry * 0.4, cz + w * rz * 0.45,
                      big_r * rng.uniform(0.85, 1.1)))
    for i in range(small):
        # Fibonacci küresi ile düzgün dağılım; arka yarı (kameradan uzak) seyrek.
        k = (i + 0.5) / small
        phi = math.acos(1 - 2 * k)
        theta = math.pi * (1 + 5 ** 0.5) * i + rng.uniform(-0.3, 0.3)
        dx = math.sin(phi) * math.cos(theta)
        dy = math.sin(phi) * math.sin(theta)
        dz = math.cos(phi)
        if dy > 0.55:
            continue
        if dz < -0.55 and flat_bottom > 0:
            continue
        s = rng.uniform(0.72, 0.86)
        balls.append((cx + dx * rx * s, cy + dy * ry * s, cz + dz * rz * s,
                      small_r * rng.uniform(0.8, 1.15)))
    return balls


def puff(rng, center, r, material, res=None, lumps=3, squash=0.9, name="Puff"):
    """Tek tombul yaprak kümesi: ana top + birkaç küçük yan şişkinlik (ayrı nesne -> net kıvrım)."""
    cx, cy, cz = center
    balls = [(cx, cy, cz, r, 1.0, 0.9, squash)]
    for k in range(lumps):
        a = rng.uniform(0, math.tau)
        balls.append((cx + math.cos(a) * r * 0.5, cy - r * 0.15, cz + math.sin(a) * r * 0.42 * squash,
                      r * rng.uniform(0.55, 0.7)))
    return blob(balls, material, res=res or max(r * 0.07, 0.008), smooth=4, name=name)


def puff_crown(rng, center, rx, rz, puff_r, material, count=14, depth=0.6, name="Crown"):
    """Royal Match tarzı taç: arkada gizli dolgu çekirdeği, elips sınırında dış halka, önde kubbe
    gibi öne doğru çıkan iç kümeler. Her küme ayrı nesne (net, yumuşak AO'lu kıvrımlar) ve
    kendi alt->üst ton geçişine sahip (Generated Z), böylece kümeler tek tek okunur."""
    cx, cy, cz = center
    objs = [blob([(cx, cy + depth * 0.9, cz, 1.0, rx * 0.82, depth * 0.6, rz * 0.82)], material,
                 res=0.06, smooth=2, name=name + "Core")]
    ring = max(int(count * 0.55), 5)
    for i in range(ring):
        a = math.tau * i / ring + rng.uniform(-0.12, 0.12)
        rr = puff_r * rng.uniform(0.88, 1.08) * (1.0 - 0.12 * max(-math.sin(a), 0.0))
        objs.append(puff(rng, (cx + math.cos(a) * (rx - rr * 0.85), cy + depth * rng.uniform(0.2, 0.45),
                               cz + math.sin(a) * (rz - rr * 0.85)), rr, material, name=name))
    placed = []
    tries = 0
    while len(placed) < count - ring and tries < 2000:
        tries += 1
        u, v = rng.uniform(-1, 1), rng.uniform(-1, 1)
        d = u * u + v * v
        if d > 1.0:
            continue
        px, pz = cx + u * (rx - puff_r * 1.1), cz + v * (rz - puff_r * 1.1)
        if any((px - qx) ** 2 + (pz - qz) ** 2 < (puff_r * 1.05) ** 2 for qx, qz in placed):
            continue
        placed.append((px, pz))
        rr = puff_r * rng.uniform(0.9, 1.1)
        objs.append(puff(rng, (px, cy - depth * (0.15 + 0.6 * (1.0 - d)), pz), rr, material, name=name))
    return objs


def crown_masses(rng, center, rx, rz, material, mass=1.0, name="Mass"):
    """Doğal stilize taç: 7-9 iri yaprak kütlesi (her biri yüzeyi küçük şişkinliklerle kaplı tek bir
    metaball). Kütleler ayrı nesne: aralarında yumuşak AO kıvrımı, her biri kendi ton geçişiyle."""
    cx, cy, cz = center
    layout = [(0.0, -0.35, 0.12, 1.25), (-0.52, 0.0, -0.18, 0.98), (0.52, 0.0, -0.15, 1.02),
              (-0.28, 0.12, 0.52, 0.95), (0.33, 0.15, 0.5, 0.95), (0.0, -0.2, -0.42, 0.95),
              (-0.68, 0.3, 0.3, 0.78), (0.7, 0.3, 0.28, 0.78), (0.02, 0.35, 0.72, 0.72)]
    objs = []
    for ux, uy, uz, k in layout:
        sz = mass * k * rng.uniform(0.92, 1.08)
        pos = (cx + ux * rx + rng.uniform(-0.04, 0.04) * rx, cy + uy * sz,
               cz + uz * rz + rng.uniform(-0.04, 0.04) * rz)
        objs.append(blob(foliage(rng, pos, sz, sz * 0.8, sz * 0.9, big=3, small=22, big_r=sz * 0.62,
                                 small_r=sz * 0.34), material, res=sz * 0.03, smooth=4, name=name,
                         stiffness=3.0))
    return objs


# ---------------------------------------------------------------------------- katmanlar

FOLIAGE = "#9FD39A"
WOOD = "#C89B6A"


class Frame:
    """Eğik orto kamera çerçevesi: piksel satırı (p, üstten) <-> dünya yüksekliği dönüşümleri."""

    def __init__(self, res_x, res_y, tilt, origin_p):
        self.h = res_y
        self.t = math.radians(tilt)
        self.s, self.c = math.sin(self.t), math.cos(self.t)
        # (0,0,0) noktası üstten origin_p pikselde görünsün.
        self.cz = (origin_p - res_y / 2.0) / PPU / self.c
        camera(res_x, res_y, 0.0, self.cz, tilt)

    def v(self, p):
        return (self.h / 2.0 - p) / PPU

    def z_at(self, p, y):
        """y derinliğinde, üstten p pikselde görünen yükseklik."""
        return self.cz + (self.v(p) - y * self.s) / self.c

    def hill_sz(self, p, y, sy):
        """y derinliğindeki (sx, sy, sz) elipsoidin silüet tepesi p'de olsun diye gereken sz."""
        q = self.v(p) + self.cz * self.c - y * self.s
        return math.sqrt(max(q * q - (sy * self.s) ** 2, 0.01)) / self.c


def house(base, w, h, wall_m, roof_m, trim_m):
    """Minik oyuncak ev: yuvarlak köşeli gövde, yuvarlatılmış üçgen çatı, kapı ve pencere."""
    rounded_box(base + Vector((0, 0, h / 2)), (w, w * 0.8, h), w * 0.1, wall_m)
    roof = [(-w * 0.64, 0.0), (w * 0.64, 0.0), (0.0, h * 0.95)]
    dense = []
    for pa, pb in zip(roof, roof[1:] + roof[:1]):
        for k in range(16):
            t = k / 16
            dense.append((pa[0] + (pb[0] - pa[0]) * t, pa[1] + (pb[1] - pa[1]) * t))
    slab(dense, w * 0.95, w * 0.07, roof_m, y=base.y, loc=(base.x, base.z + h - w * 0.04), name="Roof")
    front = base.y - w * 0.4
    rounded_box(Vector((base.x - w * 0.2, front, base.z + h * 0.3)), (w * 0.22, w * 0.06, h * 0.56),
                w * 0.05, trim_m)
    rounded_box(Vector((base.x + w * 0.2, front, base.z + h * 0.58)), (w * 0.22, w * 0.06, h * 0.26),
                w * 0.05, trim_m)
    rounded_box(Vector((base.x + w * 0.3, base.y + w * 0.1, base.z + h * 1.55)),
                (w * 0.13, w * 0.13, h * 0.5), w * 0.04, roof_m)


def make_far():
    """Uzak tepeler: 4 sıra yumuşak elipsoid tepe, sırtlarda top ve servi ağaçları, 3 minik pastel ev.
    Derinlik arttıkça pus (emission karışımı) artar, renk maviye kayar."""
    reset()
    light_rig(sun=1.05, sky=0.5, direction=(0.55, 0.55, -0.62))
    rng = random.Random(7)
    fr = Frame(1080, 900, 10.0, 720)
    sy = 3.2
    rows = [
        # (derinlik y, renk alt, renk üst, pus, ağaç pus, [(x, sx, tepe_p)])
        (17.0, "#B4D6DA", "#D3ECEE", 0.58, "#CFE6E9",
         [(-6.8, 4.0, 190), (-2.6, 4.4, 150), (1.9, 3.6, 175), (6.2, 4.6, 140)]),
        (12.0, "#ADD8B8", "#D3EED4", 0.44, "#D3E9E6",
         [(-5.4, 3.6, 215), (-1.0, 3.4, 245), (3.3, 4.2, 205), (8.0, 3.4, 235)]),
        (7.0, "#B4DFA8", "#DCF2CF", 0.3, "#DDEFD6",
         [(-7.8, 3.6, 290), (-3.6, 4.0, 270), (1.2, 3.8, 300), (5.4, 3.8, 275)]),
        (2.0, "#B9E3A6", "#D8F0C6", 0.2, "#DDEFD6",
         [(-5.6, 4.6, 345), (-0.6, 4.2, 365), (4.2, 4.6, 340), (8.6, 3.6, 360)]),
    ]
    surface = {}
    for ri, (depth, col, top, haze, hcol, hills) in enumerate(rows):
        hm = mat("Hill%d" % ri, col, top, rough=0.95, haze=haze, haze_color=hcol, ao=0.35, ao_dist=1.5,
                 noise=0.04, noise_scale=0.3, grad=(0.5, 0.98), spec=0.2)
        tm = mat("FarTree%d" % ri, "#76B97E", "#B4E2A4", rough=0.85, haze=haze + 0.04, haze_color=hcol,
                 ao=0.55, ao_dist=0.25, grad=(0.1, 0.95), spec=0.2)
        for hx, sx, crest in hills:
            sz = fr.hill_sz(crest, depth, sy)
            ellipsoid((hx, depth, 0.0), (sx, sy, sz), hm)
            surface.setdefault(ri, []).append((hx, sx, sz))
            if ri == 0:
                continue
            # Sırt boyunca ağaç kümeleri: yuvarlak toplar ve ince servi (poplar) ağaçları.
            for _ in range(rng.randint(2, 4)):
                ux = rng.uniform(-0.7, 0.7)
                uy = -rng.uniform(0.25, 0.5)
                uz = math.sqrt(max(1 - ux * ux - uy * uy, 0.0))
                tx, ty, tz = hx + ux * sx, depth + uy * sy, uz * sz
                size = rng.uniform(0.16, 0.26) * (0.8 + 0.2 * ri)
                if rng.random() < 0.3:
                    puff(rng, (tx, ty, tz + size * 1.4), size, tm, lumps=2, squash=2.4, name="Poplar")
                else:
                    for k in range(rng.randint(1, 3)):
                        r = size * rng.uniform(0.75, 1.0)
                        puff(rng, (tx + k * size * 1.2, ty - k * 0.05, tz + r * 0.7), r, tm, lumps=3,
                             name="FarTree")
    ground = mat("FarGround", "#B9E3A6", rough=0.95, haze=0.2, haze_color="#DDEFD6", ao=0.0, spec=0.2)
    bpy.ops.mesh.primitive_plane_add(size=1.0, location=(0.0, 8.0, -0.01))
    plane = bpy.context.view_layer.objects.active
    plane.scale = (40.0, 40.0, 1.0)
    assign(plane, ground)
    # Minik pastel evler.
    walls = ["#FFE4DC", "#FFF3D9", "#E4F0FB"]
    roofs = ["#F0A99B", "#EDBB8A", "#9FBDE3"]
    for i, (hx, ri, w) in enumerate(((-2.9, 2, 0.46), (0.25, 1, 0.38), (3.25, 1, 0.42))):
        depth, haze, hcol = rows[ri][0], rows[ri][3] - 0.08, rows[ri][4]
        hill_x, sx, sz = min(surface[ri], key=lambda hh: abs(hh[0] - hx))
        ux, uy = (hx - hill_x) / sx, -0.32
        uz = math.sqrt(max(1 - ux * ux - uy * uy, 0.0))
        base = Vector((hx, depth + uy * sy, uz * sz - 0.03))
        house(base, w, w * 0.62, mat("Wall%d" % i, walls[i], rough=0.75, haze=haze, haze_color=hcol,
                                     ao=0.45, ao_dist=0.1, spec=0.2),
              mat("Roof%d" % i, roofs[i], rough=0.6, haze=haze, haze_color=hcol, ao=0.35, ao_dist=0.1),
              mat("Trim%d" % i, "#C9A58F", rough=0.7, haze=haze, haze_color=hcol, ao=0.0))
    render("bg_far")


def hedge(rng, x0, x1, depth, height, puff_r, material, name="Hedge"):
    """Uzun çalı sırası: gizli dolgu + üst kenarda düzensiz boy/aralıkta kümeler + ön yüzde kümeler."""
    objs = [blob([((x0 + x1) / 2, depth + puff_r * 0.6, height * 0.45, 1.0, (x1 - x0) / 2 + 0.3,
                   puff_r * 1.0, height * 0.5)], material, res=0.06, smooth=2, name=name + "Core")]
    x = x0
    while x <= x1 + 0.01:
        r = puff_r * rng.uniform(0.7, 1.3)
        lift = 0.12 * math.sin(x * 0.9 + 1.0) + 0.06 * math.sin(x * 2.3) + rng.uniform(-0.05, 0.05)
        objs.append(puff(rng, (x, depth + rng.uniform(-0.1, 0.15), height - r * 0.8 + lift), r,
                         material, lumps=4, name=name))
        x += r * rng.uniform(0.95, 1.25)
    for row, zf in enumerate((0.72, 0.46, 0.2)):
        x = x0 + puff_r * (0.6 + 0.7 * (row % 2))
        while x <= x1:
            r = puff_r * rng.uniform(0.75, 1.1)
            objs.append(puff(rng, (x + rng.uniform(-0.12, 0.12), depth - puff_r * (0.4 + 0.2 * row),
                                   height * zf + rng.uniform(-0.08, 0.08)), r, material, lumps=4,
                             name=name))
            x += r * rng.uniform(1.15, 1.45)
    return objs


def make_mid():
    """Orta plan: arkada top taçlı bahçe ağaçları, önde tombul budanmış çalı duvarı."""
    reset()
    light_rig(sun=1.08, sky=0.48, direction=(0.58, 0.48, -0.66))
    rng = random.Random(11)
    fr = Frame(1080, 700, 8.0, 640)
    trunk_m = mat("MidTrunk", "#B08A6C", "#C7A383", rough=0.8, haze=0.18, haze_color="#DDEEE2", ao=0.5,
                  ao_dist=0.3, grad=(0.0, 1.0))
    # Ağaç sırası (arkada): (x, taç merkezi p, yarıçap x, yarıçap z, derinlik, renk)
    trees = [(-4.4, 195, 0.85, 0.8, 6.0, 0), (-1.45, 170, 0.8, 0.85, 7.5, 1), (1.85, 200, 0.75, 0.72, 6.5, 0),
             (4.6, 175, 0.9, 0.85, 7.2, 1)]
    for tx, cp, rx, rz, depth, tone in trees:
        fm = mat("MidTree%d" % tone, ("#7FC184", "#88C683")[tone], ("#C4EBB0", "#CBEBAE")[tone],
                 rough=0.85, haze=(0.26, 0.3)[tone], haze_color="#DCEDE4", ao=0.65, ao_dist=0.3,
                 grad=(0.12, 0.95), spec=0.25, sheen=0.15)
        cz = fr.z_at(cp, depth)
        tube([(tx, depth + 0.1, 0.0, 0.16), (tx + 0.03, depth + 0.1, cz * 0.5, 0.13),
              (tx, depth + 0.1, cz, 0.1)], trunk_m)
        crown_masses(rng, (tx, depth, cz), rx, rz, fm, mass=0.32 * (rx + rz), name="MidCrown")
    hm = mat("Hedge", "#86C88A", "#C9EBB4", rough=0.85, haze=0.16, haze_color="#DCEEE4", ao=0.7,
             ao_dist=0.35, grad=(0.1, 0.95), spec=0.25, sheen=0.15)
    hedge_top = fr.z_at(225, 2.2)
    hedge(rng, -5.9, 5.9, 2.2, hedge_top, 0.32, hm)
    ground = mat("MidGround", "#BFE3A6", rough=0.9, haze=0.12, haze_color="#DCEEE4", ao=0.4,
                 ao_dist=0.8, spec=0.2)
    bpy.ops.mesh.primitive_plane_add(size=1.0, location=(0.0, 5.0, 0.0))
    plane = bpy.context.view_layer.objects.active
    plane.scale = (30.0, 30.0, 1.0)
    assign(plane, ground)
    render("bg_mid")


def make_fence():
    """Krem ahşap çit: yuvarlak başlı, kalın, bevel'li tahtalar + arkada iki kuşak."""
    reset()
    light_rig(sun=1.1, sky=0.5, direction=(0.6, 0.5, -0.62))
    rng = random.Random(3)
    fr = Frame(1080, 420, 10.0, 360)
    pm = mat("Picket", "#F8F0E0", "#FFFAF0", rough=0.55, ao=0.6, ao_dist=0.3, grain=0.045,
             grain_scale=9.0, grain_dir="X", noise=0.02, noise_scale=1.0, grad=(0.0, 1.0), spec=0.3)
    rm = mat("Rail", "#F2E8D4", rough=0.6, ao=0.3, ao_dist=0.3, grain=0.06, grain_scale=6.0,
             grain_dir="Z", spec=0.3)
    width, pitch = 0.44, 0.6
    height = fr.z_at(48, 0.0)
    x = -5.4 + 0.1
    while x < 5.8:
        h = height + rng.uniform(-0.03, 0.02)
        r = width / 2
        outline = [(-r, -1.5), (r, -1.5)] + arc(0.0, h - r, r, r * 1.0, 0, 180, 48)
        slab(outline, 0.13, 0.05, pm, y=0.0, loc=(x, 0.0), name="Picket", rot_z=rng.uniform(-0.7, 0.7))
        x += pitch
    for zz in (fr.z_at(300, 0.13), fr.z_at(140, 0.13)):
        outline = [(-6.0, zz - 0.11), (6.0, zz - 0.11), (6.0, zz + 0.11), (-6.0, zz + 0.11)]
        slab(outline, 0.1, 0.035, rm, y=0.14, name="Rail")
    render("bg_fence")


def grass_blade(x, y, z, h, lean, rot, material, width=0.035):
    pts = []
    for i in range(5):
        t = i / 4
        pts.append((x + math.cos(rot) * lean * t * t, y + math.sin(rot) * lean * t * t, z + h * t,
                    width * (1 - t * 0.92)))
    return tube(pts, material, "Blade", res=4)


STONE_PATH = [(0.9, -7.0), (1.7, -5.75), (2.75, -4.7), (3.65, -3.55), (4.35, -2.35), (5.0, -1.25)]


def make_grass():
    """Ön çim: yumuşak tümsekler, taş basamaklar, çiçek kümeleri; üst kenar tutam silüeti."""
    reset()
    light_rig(sun=1.0, sky=0.55, direction=(0.55, 0.62, -0.6))
    rng = random.Random(21)
    tilt = 38.0
    st, ct = math.sin(math.radians(tilt)), math.cos(math.radians(tilt))
    camera(1080, 820, 0.0, 0.0, tilt)
    back_y = (4.1 - 0.55) / st  # arka kenar, üstten ~55 px aşağıda
    # Zemin: yoğun ızgara + yumuşak gauss tümsekler + dalgalı arka kenar.
    gm = mat("Lawn", "#B4E09A", "#D2EEB8", rough=0.85, ao=0.45, ao_dist=0.6, noise=0.05,
             noise_scale=0.45, grad=(0.0, 1.0), grad_axis="Y", bump=0.06, bump_scale=30.0,
             stripes=0.035, stripe_scale=0.42, sheen=0.25, spec=0.25)
    mounds = [(-3.6, -2.0, 1.6, 0.22), (3.3, 0.6, 1.8, 0.2), (-0.6, 2.2, 2.0, 0.14),
              (1.4, -4.6, 1.9, 0.18), (-4.6, 3.8, 1.4, 0.16), (4.8, -3.0, 1.5, 0.2)]
    bm_ = bmesh.new()
    nx, ny = 160, 150
    y0, y1 = -7.2, back_y + 0.2
    verts = []
    for j in range(ny + 1):
        row = []
        yy = y0 + (y1 - y0) * j / ny
        for i in range(nx + 1):
            xx = -6.2 + 12.4 * i / nx
            edge = back_y + 0.06 * math.sin(xx * 2.1) + 0.04 * math.sin(xx * 5.3 + 1.0)
            yy2 = min(yy, edge) if j == ny else yy
            zz = sum(a * math.exp(-((xx - mx) ** 2 + (yy2 - my) ** 2) / (r * r))
                     for mx, my, r, a in mounds)
            row.append(bm_.verts.new((xx, yy2, zz)))
        verts.append(row)
    for j in range(ny):
        for i in range(nx):
            bm_.faces.new((verts[j][i], verts[j][i + 1], verts[j + 1][i + 1], verts[j + 1][i]))
    mesh = bpy.data.meshes.new("Lawn")
    bm_.to_mesh(mesh)
    bm_.free()
    lawn = link(bpy.data.objects.new("Lawn", mesh))
    activate(lawn)
    bpy.ops.object.shade_smooth()
    assign(lawn, gm)

    def ground_z(xx, yy):
        return sum(a * math.exp(-((xx - mx) ** 2 + (yy - my) ** 2) / (r * r)) for mx, my, r, a in mounds)

    # Arka kenar: yuvarlak uçlu çim tutamları (yumuşak silüet).
    bl = mat("Blade", "#A6DA8A", "#DAF3C2", rough=0.7, ao=0.3, ao_dist=0.15, grad=(0.0, 1.0), spec=0.3)
    blades = []
    xx = -5.6
    while xx < 5.7:
        cy = back_y - rng.uniform(0.0, 0.25)
        for _ in range(rng.randint(3, 5)):
            bx = xx + rng.uniform(-0.12, 0.12)
            by = cy + rng.uniform(-0.1, 0.1)
            blades.append(grass_blade(bx, by, ground_z(bx, by) - 0.02, rng.uniform(0.16, 0.3),
                                      rng.uniform(0.04, 0.12), rng.uniform(0, math.tau), bl,
                                      width=rng.uniform(0.03, 0.042)))
        xx += rng.uniform(0.16, 0.26)
    # Seyrek ön çim tutamları (doku hissi; ortası temiz kalır).
    for _ in range(22):
        bx = rng.uniform(-5.3, 5.3)
        by = rng.uniform(-6.8, back_y - 0.6)
        if abs(bx) < 2.6 and -4.5 < by < 2.5:
            continue
        if any((bx - sx) ** 2 + (by - sy) ** 2 < 0.8 for sx, sy in STONE_PATH):
            continue
        for _ in range(5):
            px, py = bx + rng.uniform(-0.07, 0.07), by + rng.uniform(-0.05, 0.05)
            blades.append(grass_blade(px, py, ground_z(px, py) - 0.02, rng.uniform(0.14, 0.22),
                                      rng.uniform(0.03, 0.08), rng.uniform(0, math.tau), bl,
                                      width=0.04))
    join(blades, "Blades")
    # Taş basamaklar: yassı, yuvarlak, hafif gömülü.
    sm = mat("Stone", "#D3CBBB", "#ECE5D6", rough=0.7, ao=0.55, ao_dist=0.3, noise=0.06,
             noise_scale=3.0, bump=0.15, bump_scale=5.0, spec=0.3)
    for k, (px, py) in enumerate(STONE_PATH):
        s = 1.0 - k * 0.04
        stone = blob([(px, py, ground_z(px, py) + 0.02, 1.0, 0.5 * s, 0.38 * s, 0.13),
                      (px + 0.15 * s, py + 0.05, ground_z(px, py) + 0.02, 1.0, 0.36 * s, 0.32 * s, 0.12)],
                     sm, res=0.02, smooth=4, name="Stone")
        stone.rotation_euler.z = rng.uniform(-0.5, 0.5)
    # Çiçek kümeleri: tombul yaprak öbeği + birkaç çiçek.
    leaf_m = mat("ClumpLeaf", "#86C987", "#C9ECB2", rough=0.8, ao=0.6, ao_dist=0.25, grad=(0.1, 0.95),
                 spec=0.25, sheen=0.15)
    petal_cols = ["#F8C9D6", "#FFF0B0", "#E0D2FA", "#FFFFFF"]
    centre_m = mat("Centre", "#FFD36E", rough=0.5, ao=0.2, ao_dist=0.05)
    clumps = [(-4.4, -2.8, 0.55), (-3.1, -5.9, 0.5), (4.5, 2.2, 0.48), (-4.9, 2.6, 0.45),
              (2.6, 3.4, 0.36), (4.9, -5.6, 0.52)]
    for ci, (cx, cy, size) in enumerate(clumps):
        cz = ground_z(cx, cy)
        for k in range(7):
            a = math.tau * k / 7 + rng.uniform(-0.2, 0.2)
            rr = size * rng.uniform(0.38, 0.5)
            puff(rng, (cx + math.cos(a) * size * 0.65, cy + math.sin(a) * size * 0.45,
                       cz + rr * 0.55), rr, leaf_m, lumps=3, name="Clump")
        puff(rng, (cx, cy - size * 0.1, cz + size * 0.45), size * 0.55, leaf_m, lumps=3, name="Clump")
        pmat = mat("Petal%d" % (ci % 4), petal_cols[ci % 4], rough=0.55, ao=0.2, ao_dist=0.08,
                   sheen=0.3)
        for _ in range(rng.randint(3, 5)):
            a = rng.uniform(0, math.tau)
            fx = cx + math.cos(a) * size * 0.75
            fy = cy + math.sin(a) * size * 0.5 - 0.15
            fz = cz + size * 0.75 + rng.uniform(0.0, 0.2)
            flower_head(Vector((fx, fy, fz)), 0.15, pmat, centre_m, petals=6, face_tilt=35.0)
    render("bg_grass")


def flower_head(center, radius, petal_m, centre_m, petals=8, face_tilt=20.0):
    """Kameraya dönük tombul papatya başı: elipsoid taç yapraklar + kubbe göbek.
    Çiçek yüzü XZ düzleminde; face_tilt kadar yukarı bakar (üst taç yaprakları geride)."""
    tilt = Matrix.Rotation(math.radians(-face_tilt), 3, "X")
    for p in range(petals):
        a = math.tau * p / petals + 0.2
        radial = tilt @ Vector((math.cos(a) * radius * 0.6, 0.0, math.sin(a) * radius * 0.6))
        rot = tilt @ Matrix.Rotation(-a, 3, "Y")
        ellipsoid(center + radial, (radius * 0.5, radius * 0.16, radius * 0.27), petal_m,
                  rot=tuple(rot.to_euler()), segments=32, rings=16)
    ellipsoid(center + tilt @ Vector((0, -radius * 0.1, 0)), (radius * 0.33, radius * 0.22, radius * 0.33),
              centre_m, rot=tuple(tilt.to_euler()), segments=32, rings=16)


def make_tree():
    """Bahçe ağacı: gövde (kök genişlemesi + dallar, voxel ile dikişsiz) ve ayrı taç."""
    # Gövde 360x900
    reset()
    light_rig()
    camera(360, 900, 0.0, 4.5, 3.0)
    bark = mat("Bark", "#B48A66", "#C9A07A", rough=0.8, ao=0.55, ao_dist=0.35, grain=0.12,
               grain_scale=5.0, grain_dir="X", bump=0.25, bump_scale=6.0, grad=(0.0, 1.0))
    parts = [
        tube([(0.0, 0, -0.1, 0.62), (0.03, 0, 0.9, 0.45), (-0.08, 0, 3.0, 0.38), (0.06, 0, 5.2, 0.34),
              (0.0, 0, 6.6, 0.28), (-0.03, 0, 7.6, 0.19), (0.1, 0, 8.3, 0.13), (0.2, 0, 8.95, 0.08)], bark),
        tube([(0.0, 0, 6.0, 0.24), (0.55, 0, 6.9, 0.17), (1.1, 0, 7.8, 0.12), (1.35, 0, 8.6, 0.08)], bark),
        tube([(-0.02, 0, 5.4, 0.23), (-0.6, 0, 6.4, 0.16), (-1.15, 0, 7.3, 0.11), (-1.3, 0, 8.1, 0.08)],
             bark),
    ]
    for sign, length in ((-1, 0.95), (1, 1.05), (-0.25, 0.6)):
        parts.append(tube([(0.0, 0.05, 0.5, 0.3), (sign * length * 0.55, -0.1, 0.14, 0.18),
                           (sign * length * 1.1, -0.2, 0.02, 0.09)], bark))
    trunk = join(parts, "Trunk")
    remesh(trunk, 0.025, 10)
    render("tree_trunk")

    # Taç 640x640
    reset()
    light_rig(rim=0.3)
    camera(640, 640, 0.0, 0.0, 4.0)
    rng = random.Random(5)
    crown_m = mat("Crown", "#84C686", "#D6F0BA", rough=0.8, ao=0.75, ao_dist=0.5, grad=(0.12, 0.95),
                  noise=0.03, noise_scale=1.4, sheen=0.2, spec=0.3, haze=0.1, haze_color="#E6F4E0")
    crown_masses(rng, (0.0, 0.0, 0.0), 2.85, 2.55, crown_m, mass=1.08)
    render("tree_crown")


def make_pole():
    """Çamaşır direği: yuvarlak ahşap direk, tepede T kolu, payandalar, uçlarda metal halkalar."""
    reset()
    light_rig()
    camera(160, 1400, 0.0, 7.0, 0.0)
    wood = mat("PoleWood", WOOD, "#D8B184", rough=0.6, ao=0.5, ao_dist=0.2, grain=0.12,
               grain_scale=7.0, grain_dir="X", grad=(0.0, 1.0), coat=0.1)
    arm_wood = mat("ArmWood", WOOD, rough=0.6, ao=0.5, ao_dist=0.2, grain=0.12, grain_scale=7.0,
                   grain_dir="Z", coat=0.1)
    metal = mat("Ring", "#C9CED6", rough=0.3, metallic=0.85, ao=0.2, ao_dist=0.05)
    top = 13.25
    tube([(0, 0, -0.2, 0.19), (0, 0, 6.0, 0.18), (0, 0, top, 0.165)], wood, res=10)
    ellipsoid((0, 0, top + 0.02), (0.185, 0.185, 0.12), wood)
    arm_z = top - 0.32
    tube([(-0.68, 0, arm_z, 0.085), (0.0, 0, arm_z, 0.09), (0.68, 0, arm_z, 0.085)], arm_wood, res=8)
    for side in (-1, 1):
        ellipsoid((side * 0.68, 0, arm_z), (0.07, 0.095, 0.095), arm_wood)
        tube([(side * 0.12, 0, arm_z - 0.75, 0.05), (side * 0.32, 0, arm_z - 0.42, 0.048),
              (side * 0.5, 0, arm_z - 0.08, 0.045)], arm_wood, res=6)
        bpy.ops.mesh.primitive_torus_add(major_radius=0.075, minor_radius=0.017,
                                         location=(side * 0.6, -0.02, arm_z - 0.16),
                                         rotation=(math.radians(90), 0, 0), major_segments=48,
                                         minor_segments=16)
        ring = bpy.context.view_layer.objects.active
        bpy.ops.object.shade_smooth()
        assign(ring, metal)
    # Metal kuşak (direk tepesinin altında).
    bpy.ops.mesh.primitive_torus_add(major_radius=0.17, minor_radius=0.022, location=(0, 0, arm_z - 0.95),
                                     major_segments=64, minor_segments=16)
    bpy.ops.object.shade_smooth()
    assign(bpy.context.view_layer.objects.active, metal)
    # Dibinde küçük çim tutamı: direk çime "oturur", kesik alt uç görünmez.
    grass = mat("PoleGrass", "#A6DA8A", "#DAF3C2", rough=0.7, ao=0.3, ao_dist=0.15, grad=(0.0, 1.0),
                spec=0.3)
    rng = random.Random(9)
    blades = []
    for _ in range(34):
        bx = rng.uniform(-0.66, 0.66)
        blades.append(grass_blade(bx, rng.uniform(-0.35, 0.1), -0.05, rng.uniform(0.3, 0.62) *
                                  (1.0 - 0.55 * abs(bx)), rng.uniform(0.06, 0.18), rng.uniform(0, math.tau),
                                  grass, width=rng.uniform(0.045, 0.065)))
    join(blades, "PoleGrass")
    render("pole")


def make_clouds():
    specs = {
        "cloud_1": (101, [(-1.6, 0.0, 0.62), (-0.5, 0.35, 0.95), (0.8, 0.2, 0.85), (1.85, -0.1, 0.6),
                          (0.2, -0.2, 0.7)]),
        "cloud_2": (202, [(-2.0, -0.15, 0.5), (-1.0, 0.25, 0.8), (0.3, 0.45, 1.0), (1.5, 0.15, 0.78),
                          (2.4, -0.2, 0.5)]),
        "cloud_3": (303, [(-1.2, 0.0, 0.75), (0.2, 0.3, 1.05), (1.45, -0.05, 0.72)]),
    }
    for name, (seed, puffs) in specs.items():
        if not wanted(name):
            continue
        reset()
        light_rig(sun=0.7, sky=0.62, sky_color="#D6E8FF", direction=(0.35, 0.45, -0.82))
        camera(640, 320, 0.0, 0.25, 0.0)
        rng = random.Random(seed)
        cm = mat("Cloud", "#C8D6EA", "#FFFFFF", rough=1.0, haze=0.32, haze_color="#F4F8FF", ao=0.45,
                 ao_dist=0.6, grad=(0.0, 0.62), spec=0.0)
        balls = []
        for px, pz, r in puffs:
            balls.append((px, 0.0, pz, r))
            for _ in range(3):
                a = rng.uniform(0.35, math.pi - 0.35)
                balls.append((px + math.cos(a) * r * 0.75, rng.uniform(-0.35, -0.15),
                              pz + math.sin(a) * r * 0.55, r * rng.uniform(0.42, 0.58)))
        # Yassı, yumuşak taban: yan yana basık elipsoidler.
        left = min(p[0] - p[2] for p in puffs) + 0.35
        right = max(p[0] + p[2] for p in puffs) - 0.35
        steps = max(int((right - left) / 0.55), 2)
        for k in range(steps + 1):
            bx = left + (right - left) * k / steps
            balls.append((bx, 0.0, -0.42, 0.42, 1.0, 1.1, 0.55))
        blob(balls, cm, res=0.03, smooth=6, name="Cloud", stiffness=3.2)
        render(name)


def make_rack():
    """Bekleme rafı: iki direkli ahşap askı, kalın yuvarlak çubuk, 5 altın sarısı J kanca.
    Kanca halkalarının merkezi x = 512 + (i-2)*175 px (i=0..4), çubuk ekseni üstten ~68 px."""
    reset()
    light_rig()
    camera(1024, 300, 0.0, 0.0, 6.0)
    wood = mat("RackWood", WOOD, "#D9B283", rough=0.5, ao=0.5, ao_dist=0.2, grain=0.12,
               grain_scale=7.0, grain_dir="Z", grad=(0.0, 1.0), coat=0.2)
    post_wood = mat("RackPost", WOOD, "#D6AE80", rough=0.5, ao=0.5, ao_dist=0.2, grain=0.12,
                    grain_scale=7.0, grain_dir="X", grad=(0.0, 1.0), coat=0.2)
    gold = mat("Hook", "#F0CB7A", "#FFE3A6", rough=0.3, metallic=0.35, ao=0.3, ao_dist=0.06,
               grad=(0.0, 1.0), coat=0.4)
    rail_z = 0.85
    tube([(-4.8, 0, rail_z, 0.13), (0.0, 0, rail_z, 0.13), (4.8, 0, rail_z, 0.13)], wood, res=12)
    for side in (-1, 1):
        px = side * 4.8
        tube([(px, 0.06, -1.3, 0.14), (px, 0.06, 0.0, 0.13), (px, 0.06, 1.08, 0.13)], post_wood, res=12)
        ellipsoid((px, 0.06, 1.14), (0.2, 0.2, 0.18), post_wood)
        ellipsoid((px, 0.0, -1.33), (0.29, 0.24, 0.12), post_wood)
    for i in range(5):
        hx = (i - 2) * 1.75
        bpy.ops.mesh.primitive_torus_add(major_radius=0.17, minor_radius=0.045, location=(hx, 0, rail_z),
                                         rotation=(0, math.radians(90), 0), major_segments=64,
                                         minor_segments=20)
        bpy.ops.object.shade_smooth()
        assign(bpy.context.view_layer.objects.active, gold)
        pts = [(hx, -0.03, rail_z - 0.16, 0.05), (hx, -0.04, rail_z - 0.5, 0.05), (hx, -0.04, 0.06, 0.05),
               (hx + 0.06, -0.04, -0.1, 0.05), (hx + 0.2, -0.04, -0.13, 0.048), (hx + 0.3, -0.04, -0.02, 0.046),
               (hx + 0.31, -0.04, 0.1, 0.045)]
        tube(pts, gold, res=8)
        ellipsoid((hx + 0.31, -0.04, 0.13), (0.07, 0.07, 0.07), gold, segments=32, rings=16)
    render("rack")


def make_flowers():
    specs = {
        "flower_1": ("#F7BFD0", "daisy"),
        "flower_2": ("#FFE7A3", "tulip"),
    }
    for name, (petal, kind) in specs.items():
        if not wanted(name):
            continue
        reset()
        light_rig()
        camera(160, 240, 0.0, 1.2, 8.0)
        stem_m = mat("Stem", "#86C47A", "#A8D893", rough=0.6, ao=0.3, ao_dist=0.1, grad=(0.0, 1.0))
        leaf_m = mat("Leaf", "#8FCB82", "#B8E19F", rough=0.6, ao=0.3, ao_dist=0.1, grad=(0.0, 1.0),
                     grad_axis="X")
        pm = mat("Petal", petal, rough=0.5, ao=0.35, ao_dist=0.1, sheen=0.35)
        cm = mat("Centre", "#FFCF6A", "#FFE39A", rough=0.5, ao=0.3, ao_dist=0.05)
        head_z = 1.72 if kind == "daisy" else 1.68
        tube([(0.0, 0, 0.0, 0.045), (0.04, 0, 0.6, 0.04), (-0.03, 0, 1.2, 0.036), (0.0, 0, head_z, 0.033)],
             stem_m, res=6)
        for side, z, ang in ((-1, 0.38, 40), (1, 0.7, 36)):
            leaf = ellipsoid((side * 0.24, 0.02, z + 0.12), (0.3, 0.05, 0.1), leaf_m,
                             rot=(0, math.radians(-side * ang), 0), segments=48, rings=24)
            # Yaprağı kaşık gibi kıvır.
            for v in leaf.data.vertices:
                v.co.y += 0.35 * v.co.x * v.co.x
        if kind == "daisy":
            flower_head(Vector((0.0, -0.05, head_z + 0.02)), 0.5, pm, cm, petals=9, face_tilt=18.0)
        else:
            for k, a in enumerate((-50, 0, 50, -25, 25)):
                back = k >= 3
                ellipsoid((math.sin(math.radians(a)) * 0.13, 0.08 if back else -0.04,
                           head_z + 0.25 + (0.04 if back else 0.0)),
                          (0.15, 0.11, 0.3), pm, rot=(0, math.radians(a * 0.45), 0), segments=48,
                          rings=24)
        render(name)


def make_butterfly_wing():
    reset()
    light_rig(sun=0.95, sky=0.8)
    camera(128, 128, 0.0, 0.0, 0.0)
    wm = mat("Wing", "#FFFFFF", "#F2F2F2", rough=0.55, ao=0.3, ao_dist=0.08, grad=(0.0, 1.0),
             grad_axis="X", sheen=0.4)
    root = (-0.58, 0.0)
    pts = []
    steps = 90
    for i in range(steps + 1):
        th = math.radians(-78 + 160 * i / steps)
        deg = math.degrees(th)
        r = max(1.08 * math.exp(-((deg - 30) / 40) ** 2), 0.8 * math.exp(-((deg + 42) / 30) ** 2),
                0.12)
        pts.append((root[0] + r * math.cos(th), root[1] + r * math.sin(th)))
    pts.append(root)
    # Kanadı 128x128 kareye sığdır: kök sol-ortada (~x 6 px, y 64 px) sabit kalır.
    reach = max(max(px - root[0] for px, _ in pts) / 1.14, max(abs(pz - root[1]) for _, pz in pts) / 0.54)
    pts = [(root[0] + (px - root[0]) / reach, root[1] + (pz - root[1]) / reach) for px, pz in pts]
    wing = slab(pts, 0.035, 0.016, wm, name="Wing")
    for v in wing.data.vertices:
        v.co.y += 0.12 * (v.co.x - root[0]) ** 2  # hafif kavis
    render("butterfly_wing")


def main():
    jobs = [
        ("bg_far", make_far), ("bg_mid", make_mid), ("bg_fence", make_fence), ("bg_grass", make_grass),
        ("tree", make_tree), ("pole", make_pole), ("rack", make_rack),
        ("butterfly_wing", make_butterfly_wing),
    ]
    for name, func in jobs:
        if name == "tree":
            if wanted("tree") or wanted("tree_trunk") or wanted("tree_crown"):
                func()
        elif wanted(name):
            func()
    if not WANTED or WANTED & {"cloud_1", "cloud_2", "cloud_3", "clouds"}:
        if "clouds" in WANTED:
            WANTED.update({"cloud_1", "cloud_2", "cloud_3"})
        make_clouds()
    if not WANTED or WANTED & {"flower_1", "flower_2", "flowers"}:
        if "flowers" in WANTED:
            WANTED.update({"flower_1", "flower_2"})
        make_flowers()


main()
