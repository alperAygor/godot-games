#!/usr/bin/env python3
"""NEON ARENA 3B varlıklarını Blender CLI ile üretir ve .glb olarak dışa aktarır.

    blender -b --python tools/blender/make_models.py

Modeller +Y yönüne bakar (Blender); glTF dönüşümünden sonra Godot'ta -Z (ileri) olur.
"""
import math
import os

import bpy

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_DIR = os.path.join(ROOT, "assets", "models")
os.makedirs(OUT_DIR, exist_ok=True)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name, color, emission=0.0, metallic=0.85, roughness=0.35):
    # Refleksiyon probu/skybox yok: yüksek metallic yüzeyler Godot'ta siyah görünür.
    metallic = min(metallic, 0.22)
    mat = bpy.data.materials.get(name)
    if mat:
        return mat
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Emission Color"].default_value = (*color, 1.0)
    bsdf.inputs["Emission Strength"].default_value = emission
    return mat


def _finish(obj, mat, bevel=0.0, shade_flat=True):
    if mat:
        obj.data.materials.append(mat)
    if bevel > 0:
        mod = obj.modifiers.new("bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        mod.limit_method = "ANGLE"
    if not shade_flat:
        bpy.ops.object.shade_smooth()
    return obj


def box(size, loc=(0, 0, 0), rot=(0, 0, 0), mat=None, bevel=0.0, name="box"):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    obj = bpy.context.object
    obj.scale = (size[0], size[1], size[2])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.name = name
    return _finish(obj, mat, bevel)


def cyl(radius, depth, loc=(0, 0, 0), rot=(0, 0, 0), verts=12, mat=None, bevel=0.0, name="cyl"):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=loc, rotation=rot)
    obj = bpy.context.object
    obj.name = name
    return _finish(obj, mat, bevel, shade_flat=False)


def cone(radius, depth, loc=(0, 0, 0), rot=(0, 0, 0), verts=8, mat=None, name="cone"):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=radius, radius2=0.0, depth=depth, location=loc, rotation=rot)
    obj = bpy.context.object
    obj.name = name
    return _finish(obj, mat, 0.0)


def sphere(radius, loc=(0, 0, 0), subdiv=2, mat=None, scale=(1, 1, 1), name="sphere"):
    bpy.ops.mesh.primitive_ico_sphere_add(radius=radius, subdivisions=subdiv, location=loc)
    obj = bpy.context.object
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.name = name
    return _finish(obj, mat, 0.0, shade_flat=False)


def torus(major, minor, loc=(0, 0, 0), rot=(0, 0, 0), mat=None, name="torus"):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=32, minor_segments=8,
                                     location=loc, rotation=rot)
    obj = bpy.context.object
    obj.name = name
    return _finish(obj, mat, 0.0, shade_flat=False)


def export(name):
    bpy.ops.object.select_all(action="SELECT")
    path = os.path.join(OUT_DIR, name)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_materials="EXPORT",
    )
    size = os.path.getsize(path)
    print("MODEL %-16s %7.1f KB" % (name, size / 1024.0))


# --- Oyuncu gemisi (mavi) ---------------------------------------------------
def make_ship():
    reset()
    hull = material("ship_hull", (0.18, 0.26, 0.34), 0.0, 0.22, 0.4)
    accent = material("ship_accent", (0.10, 0.85, 1.0), 1.6, 0.4, 0.2)
    glass = material("ship_glass", (0.75, 0.95, 1.0), 0.7, 0.2, 0.1)
    box((0.46, 2.0, 0.3), (0, 0, 0), mat=hull, bevel=0.06, name="hull")
    cone(0.24, 0.7, (0, 1.25, 0), (math.radians(-90), 0, 0), verts=6, mat=hull, name="nose")
    box((1.5, 0.62, 0.1), (0, -0.15, 0.02), (0, 0, math.radians(0)), mat=hull, bevel=0.04, name="wing")
    for side in (-1, 1):
        box((0.5, 0.9, 0.08), (side * 0.62, -0.42, 0.0), (0, 0, math.radians(side * -16)), mat=hull, bevel=0.03, name="winglet")
        box((0.06, 0.55, 0.04), (side * 0.78, -0.35, 0.05), mat=accent, name="wing_glow")
    box((0.05, 1.35, 0.05), (0, 0.1, 0.16), mat=accent, name="spine_glow")
    sphere(0.11, (0, 0.55, 0.15), 2, glass, scale=(1.0, 1.7, 0.8), name="cockpit")
    cyl(0.16, 0.3, (0, -1.1, 0), (math.radians(90), 0, 0), 12, accent, name="engine")
    for side in (-1, 1):
        cyl(0.09, 0.2, (side * 0.3, -1.0, 0), (math.radians(90), 0, 0), 10, accent, name="engine_small")
    box((0.06, 0.5, 0.32), (0, -0.85, 0.16), mat=hull, bevel=0.02, name="fin")
    export("ship.glb")


# --- Avcı düşman (pembe) ----------------------------------------------------
def make_chaser():
    reset()
    dark = material("chaser_body", (0.30, 0.10, 0.16), 0.0, 0.22, 0.45)
    glow = material("chaser_glow", (1.0, 0.10, 0.35), 1.9, 0.2, 0.2)
    sphere(0.42, (0, 0, 0), 1, dark, scale=(1.0, 1.2, 0.8), name="core")
    for i in range(4):
        ang = math.radians(45 + i * 90)
        cone(0.13, 0.85, (math.cos(ang) * 0.45, math.sin(ang) * 0.45, 0),
             (math.radians(90), 0, ang - math.pi / 2), 6, dark, name="spike")
        box((0.1, 0.1, 0.16), (math.cos(ang) * 0.62, math.sin(ang) * 0.62, 0), mat=glow, name="tip")
    sphere(0.2, (0, 0, 0.05), 2, glow, scale=(1, 1, 0.7), name="eye")
    torus(0.5, 0.025, (0, 0, 0), (math.radians(90), 0, 0), glow, name="ring")
    export("chaser.glb")


# --- Atıcı düşman (amber) ---------------------------------------------------
def make_shooter():
    reset()
    dark = material("shooter_body", (0.32, 0.22, 0.08), 0.0, 0.22, 0.45)
    glow = material("shooter_glow", (1.0, 0.62, 0.10), 1.8, 0.2, 0.2)
    cyl(0.52, 0.26, (0, 0, -0.1), (0, 0, 0), 10, dark, 0.03, name="base")
    sphere(0.34, (0, 0, 0.16), 2, dark, scale=(1, 1, 0.85), name="dome")
    cyl(0.1, 0.95, (0, 0.55, 0.16), (math.radians(90), 0, 0), 8, dark, name="barrel")
    cyl(0.13, 0.12, (0, 1.02, 0.16), (math.radians(90), 0, 0), 8, glow, name="muzzle")
    torus(0.4, 0.03, (0, 0, 0.05), (math.radians(90), 0, 0), glow, name="ring")
    for i in range(3):
        ang = math.radians(i * 120)
        box((0.1, 0.32, 0.1), (math.cos(ang) * 0.4, math.sin(ang) * 0.4, -0.05),
            (0, 0, ang - math.pi / 2), glow, name="vent")
    export("shooter.glb")


# --- Tank düşman (mor) ------------------------------------------------------
def make_tank():
    reset()
    dark = material("tank_body", (0.26, 0.16, 0.38), 0.0, 0.22, 0.5)
    glow = material("tank_glow", (0.62, 0.30, 1.0), 1.7, 0.3, 0.25)
    box((1.5, 1.5, 0.7), (0, 0, 0), mat=dark, bevel=0.12, name="body")
    box((0.95, 0.95, 0.22), (0, 0, 0.44), mat=dark, bevel=0.06, name="roof")
    for sx in (-1, 1):
        for sy in (-1, 1):
            box((0.34, 0.34, 0.5), (sx * 0.62, sy * 0.62, -0.1), (0, 0, math.radians(45)), mat=dark, bevel=0.05, name="corner")
            box((0.12, 0.12, 0.24), (sx * 0.62, sy * 0.62, 0.32), mat=glow, name="corner_glow")
    sphere(0.3, (0, 0, 0.5), 2, glow, scale=(1, 1, 0.6), name="core")
    for i in range(4):
        ang = math.radians(i * 90 + 45)
        box((0.07, 1.45, 0.07), (0, 0, -0.38), (0, 0, ang), mat=glow, name="strip")
    export("tank.glb")


# --- Çevre: pillar ----------------------------------------------------------
def make_pillar():
    reset()
    dark = material("pillar_body", (0.08, 0.11, 0.16), 0.0, 0.22, 0.5)
    glow = material("pillar_glow", (0.12, 0.85, 1.0), 3.2, 0.2, 0.2)
    box((1.1, 1.1, 0.22), (0, 0, 0.11), mat=dark, bevel=0.04, name="base")
    box((0.62, 0.62, 3.6), (0, 0, 2.0), mat=dark, bevel=0.05, name="column")
    box((0.9, 0.9, 0.16), (0, 0, 3.85), mat=dark, bevel=0.03, name="cap")
    box((0.94, 0.94, 0.1), (0, 0, 3.7), mat=glow, name="cap_glow")
    for side in (-1, 1):
        box((0.12, 0.12, 3.2), (side * 0.34, 0.34, 2.0), mat=glow, name="strip")
        box((0.12, 0.12, 3.2), (side * 0.34, -0.34, 2.0), mat=glow, name="strip")
    export("pillar.glb")


# --- Çevre: kasa ------------------------------------------------------------
def make_crate():
    reset()
    dark = material("crate_body", (0.09, 0.12, 0.16), 0.0, 0.22, 0.55)
    glow = material("crate_glow", (0.18, 0.90, 1.0), 2.2, 0.3, 0.3)
    box((1.0, 1.0, 1.0), (0, 0, 0.5), mat=dark, bevel=0.05, name="body")
    for z in (0.08, 0.92):
        box((1.04, 1.04, 0.07), (0, 0, z), mat=glow, name="edge")
    box((0.12, 1.05, 0.72), (0.5, 0, 0.5), mat=glow, name="side_glow")
    box((1.05, 0.12, 0.72), (0, 0.5, 0.5), mat=glow, name="side_glow")
    export("crate.glb")


# --- Çevre: arena göbeği ----------------------------------------------------
def make_dais():
    reset()
    dark = material("dais_body", (0.11, 0.155, 0.21), 0.0, 0.22, 0.4)
    glow = material("dais_glow", (0.12, 0.78, 1.0), 1.5, 0.2, 0.2)
    cyl(2.3, 0.12, (0, 0, 0.06), (0, 0, 0), 48, dark, 0.02, name="disc")
    torus(2.2, 0.03, (0, 0, 0.13), (0, 0, 0), glow, name="ring_outer")
    torus(1.6, 0.02, (0, 0, 0.13), (0, 0, 0), glow, name="ring_inner")
    for i in range(6):
        ang = math.radians(i * 60)
        box((0.5, 0.08, 0.03), (math.cos(ang) * 1.9, math.sin(ang) * 1.9, 0.13), (0, 0, ang), mat=glow, name="tick")
    export("dais.glb")



# --- Yeni düşman: sürü üyesi (turuncu) --------------------------------------
def make_swarmer():
    reset()
    dark = material("swarmer_body", (0.30, 0.16, 0.08), 0.0, 0.22, 0.45)
    glow = material("swarmer_glow", (1.0, 0.55, 0.12), 2.4, 0.2, 0.2)
    sphere(0.3, (0, 0, 0), 1, dark, scale=(1.0, 1.1, 0.9), name="core")
    for i in range(6):
        ang = math.radians(i * 60)
        cone(0.07, 0.42, (math.cos(ang) * 0.26, math.sin(ang) * 0.26, 0),
             (math.radians(90), 0, ang - math.pi / 2), 5, dark, name="spike")
        sphere(0.05, (math.cos(ang) * 0.42, math.sin(ang) * 0.42, 0.02), 1, glow, name="tip")
    sphere(0.11, (0, 0.1, 0.16), 1, glow, name="eye")
    export("swarmer.glb")


# --- Yeni düşman: bombacı (kırmızı) -----------------------------------------
def make_bomber():
    reset()
    dark = material("bomber_body", (0.26, 0.10, 0.10), 0.0, 0.22, 0.5)
    glow = material("bomber_glow", (1.0, 0.20, 0.10), 2.6, 0.2, 0.2)
    sphere(0.48, (0, 0, 0), 2, dark, scale=(1.0, 1.0, 0.95), name="shell")
    for i in range(3):
        torus(0.52, 0.035, (0, 0, 0), (math.radians(70 + i * 20), 0, math.radians(i * 60)), glow, name="ring")
    sphere(0.26, (0, 0, 0.05), 2, glow, name="core")
    for i in range(4):
        ang = math.radians(i * 90 + 45)
        box((0.12, 0.24, 0.12), (math.cos(ang) * 0.44, math.sin(ang) * 0.44, -0.3), mat=dark, name="leg")
    export("bomber.glb")


# --- Yeni düşman: nişancı (yeşil) -------------------------------------------
def make_sniper():
    reset()
    dark = material("sniper_body", (0.10, 0.22, 0.20), 0.0, 0.22, 0.4)
    glow = material("sniper_glow", (0.25, 1.0, 0.75), 2.2, 0.2, 0.2)
    box((0.46, 1.5, 0.34), (0, 0, 0), mat=dark, bevel=0.05, name="hull")
    cone(0.22, 0.5, (0, 0.9, 0), (math.radians(-90), 0, 0), 5, dark, name="nose")
    cyl(0.075, 1.7, (0, 0.95, 0.02), (math.radians(90), 0, 0), 8, dark, name="barrel")
    cyl(0.11, 0.16, (0, 1.78, 0.02), (math.radians(90), 0, 0), 8, glow, name="muzzle")
    box((0.06, 0.9, 0.04), (0, -0.1, 0.18), mat=glow, name="rail")
    sphere(0.1, (0, 0.15, 0.22), 2, glow, scale=(1, 1.6, 0.8), name="scope")
    for side in (-1, 1):
        box((0.5, 0.3, 0.06), (side * 0.34, -0.5, 0), mat=dark, bevel=0.02, name="fin")
    export("sniper.glb")


# --- Yeni düşman: yörüngeci (mor-beyaz) -------------------------------------
def make_orbiter():
    reset()
    dark = material("orbiter_body", (0.16, 0.12, 0.30), 0.0, 0.22, 0.4)
    glow = material("orbiter_glow", (0.75, 0.55, 1.0), 2.4, 0.2, 0.2)
    sphere(0.26, (0, 0, 0), 2, dark, name="core")
    torus(0.55, 0.05, (0, 0, 0), (math.radians(90), 0, 0), dark, name="ring")
    for i in range(3):
        ang = math.radians(i * 120)
        sphere(0.12, (math.cos(ang) * 0.55, math.sin(ang) * 0.55, 0), 2, glow, name="orb")
        box((0.05, 0.2, 0.05), (math.cos(ang) * 0.4, math.sin(ang) * 0.4, 0), (0, 0, ang), mat=glow, name="link")
    sphere(0.14, (0, 0, 0.12), 2, glow, scale=(1, 1, 1.4), name="eye")
    export("orbiter.glb")


# --- Boss -------------------------------------------------------------------
def make_boss():
    reset()
    dark = material("boss_body", (0.11, 0.06, 0.20), 0.0, 0.22, 0.45)
    glow = material("boss_glow", (1.0, 0.18, 0.45), 2.2, 0.25, 0.2)
    cyan = material("boss_cyan", (0.20, 0.85, 1.0), 2.0, 0.25, 0.2)
    sphere(1.55, (0, 0, 0), 2, dark, scale=(1.0, 1.0, 0.8), name="hull")
    sphere(0.75, (0, 0, 0.25), 2, glow, scale=(1.0, 1.0, 0.7), name="core")
    for i, (r, tilt, mat) in enumerate([(2.3, 12, glow), (2.9, -18, cyan)]):
        torus(r, 0.07, (0, 0, 0.1), (math.radians(78), math.radians(tilt), 0), mat, name="ring")
    for i in range(6):
        ang = math.radians(i * 60)
        cone(0.26, 1.5, (math.cos(ang) * 1.6, math.sin(ang) * 1.6, 0),
             (math.radians(90), 0, ang - math.pi / 2), 5, dark, name="spike")
        sphere(0.16, (math.cos(ang) * 2.3, math.sin(ang) * 2.3, 0.02), 2, glow, name="tip")
    for i in range(4):
        ang = math.radians(i * 90 + 45)
        sphere(0.16, (math.cos(ang) * 1.05, math.sin(ang) * 1.05, 0.55), 2, cyan, name="eye")
    export("boss.glb")


# --- Çevre: kristal ---------------------------------------------------------
def make_crystal():
    reset()
    body = material("crystal_body", (0.16, 0.10, 0.34), 0.0, 0.22, 0.25)
    glow = material("crystal_glow", (0.55, 0.30, 1.0), 1.8, 0.2, 0.2)
    for i, (h, r, dx, dy, tilt) in enumerate([(3.0, 0.42, 0.0, 0.0, 0), (2.1, 0.3, 0.55, 0.2, 12),
                                             (1.6, 0.24, -0.5, 0.15, -14), (1.1, 0.18, 0.1, -0.5, 8)]):
        cone(r, h, (dx, dy, h * 0.5), (math.radians(tilt), 0, math.radians(i * 40)), 5, body, name="shard")
        cone(r * 0.55, h * 0.45, (dx, dy, h * 0.78), (math.radians(tilt), 0, math.radians(i * 40)), 5, glow, name="tip")
    torus(0.75, 0.05, (0, 0, 0.08), (math.radians(90), 0, 0), glow, name="base_ring")
    export("crystal.glb")


# --- Çevre: obelisk ---------------------------------------------------------
def make_obelisk():
    reset()
    body = material("obelisk_body", (0.08, 0.10, 0.14), 0.0, 0.22, 0.5)
    glow = material("obelisk_glow", (0.20, 0.85, 1.0), 2.0, 0.2, 0.2)
    box((1.3, 1.3, 0.3), (0, 0, 0.15), mat=body, bevel=0.04, name="base")
    cone(0.62, 4.2, (0, 0, 2.3), (0, 0, math.radians(45)), 4, body, name="spire")
    for z in (1.1, 2.0, 2.9):
        box((0.9, 0.9, 0.06), (0, 0, z), (0, 0, math.radians(45)), mat=glow, name="rune")
    sphere(0.16, (0, 0, 4.5), 2, glow, name="tip")
    export("obelisk.glb")


# --- Çevre: bariyer ---------------------------------------------------------
def make_barrier():
    reset()
    body = material("barrier_body", (0.07, 0.09, 0.13), 0.0, 0.22, 0.55)
    glow = material("barrier_glow", (1.0, 0.62, 0.15), 0.9, 0.2, 0.2)
    box((3.2, 0.5, 0.9), (0, 0, 0.45), mat=body, bevel=0.04, name="wall")
    box((3.25, 0.56, 0.05), (0, 0, 0.94), mat=glow, name="strip")
    for side in (-1, 1):
        box((0.22, 0.6, 1.05), (side * 1.5, 0, 0.52), mat=body, bevel=0.02, name="post")
        box((0.26, 0.62, 0.1), (side * 1.5, 0, 1.0), mat=glow, name="post_glow")
    export("barrier.glb")


# --- Gemi 2: KASIRGA (turuncu, geniş yaylım gemisi) ---------------------------
def make_ship_storm():
    reset()
    hull = material("storm_hull", (0.26, 0.20, 0.16), 0.0, 0.22, 0.45)
    accent = material("storm_accent", (1.0, 0.55, 0.12), 1.15, 0.3, 0.2)
    glass = material("storm_glass", (1.0, 0.85, 0.6), 0.6, 0.2, 0.1)
    box((0.7, 1.7, 0.36), (0, -0.05, 0), mat=hull, bevel=0.08, name="hull")
    cone(0.36, 0.55, (0, 1.05, 0), (math.radians(-90), 0, math.radians(45)), 4, hull, name="nose")
    box((1.9, 0.75, 0.14), (0, -0.25, 0.0), mat=hull, bevel=0.05, name="wing")
    for side in (-1, 1):
        box((0.36, 1.25, 0.32), (side * 0.86, 0.05, -0.02), mat=hull, bevel=0.06, name="pod")
        for k in (-1, 0, 1):
            cyl(0.055, 0.42, (side * 0.86 + k * 0.1, 0.78, 0.04), (math.radians(90), 0, 0), 8, hull, name="barrel")
            cyl(0.07, 0.06, (side * 0.86 + k * 0.1, 1.0, 0.04), (math.radians(90), 0, 0), 8, accent, name="muzzle")
        box((0.06, 0.95, 0.04), (side * 0.86, 0.05, 0.19), mat=accent, name="pod_glow")
        box((0.42, 0.3, 0.06), (side * 0.86, -0.62, 0.14), mat=accent, name="pod_vent")
    box((0.08, 1.2, 0.05), (0, 0.0, 0.2), mat=accent, name="spine_glow")
    sphere(0.16, (0, 0.38, 0.2), 2, glass, scale=(1.2, 1.5, 0.7), name="cockpit")
    cyl(0.22, 0.3, (0, -0.98, 0), (math.radians(90), 0, 0), 12, accent, name="engine")
    for side in (-1, 1):
        cyl(0.13, 0.26, (side * 0.86, -0.72, 0), (math.radians(90), 0, 0), 10, accent, name="engine_pod")
    export("ship_storm.glb")


# --- Gemi 3: MIZRAK (mor, uzun raylı top) ------------------------------------
def make_ship_lance():
    reset()
    hull = material("lance_hull", (0.20, 0.16, 0.30), 0.0, 0.22, 0.4)
    accent = material("lance_accent", (0.82, 0.32, 1.0), 1.9, 0.3, 0.2)
    glass = material("lance_glass", (0.95, 0.8, 1.0), 0.6, 0.2, 0.1)
    box((0.3, 1.6, 0.24), (0, -0.2, 0), mat=hull, bevel=0.05, name="hull")
    for side in (-1, 1):
        box((0.08, 1.55, 0.1), (side * 0.16, 0.95, 0.02), mat=hull, bevel=0.02, name="rail")
        box((0.03, 1.35, 0.03), (side * 0.12, 0.95, 0.08), mat=accent, name="rail_glow")
        box((0.75, 0.42, 0.06), (side * 0.48, -0.75, 0.0), (0, 0, math.radians(side * -28)), mat=hull, bevel=0.02, name="wing")
        box((0.05, 0.36, 0.04), (side * 0.72, -0.86, 0.04), (0, 0, math.radians(side * -28)), mat=accent, name="wing_glow")
        box((0.04, 0.34, 0.3), (side * 0.2, -0.95, 0.18), (0, math.radians(side * 14), 0), mat=hull, name="fin")
    for y in (0.45, 0.85, 1.25, 1.6):
        box((0.36, 0.05, 0.05), (0, y, 0.02), mat=accent, name="coil")
    sphere(0.09, (0, 1.72, 0.02), 2, accent, name="tip")
    sphere(0.1, (0, -0.05, 0.15), 2, glass, scale=(1.0, 2.0, 0.8), name="cockpit")
    cyl(0.14, 0.32, (0, -1.08, 0), (math.radians(90), 0, 0), 12, accent, name="engine")
    export("ship_lance.glb")


# --- Gemi 4: ŞAHİN (yeşil, roket gemisi) --------------------------------------
def make_ship_hawk():
    reset()
    hull = material("hawk_hull", (0.14, 0.24, 0.20), 0.0, 0.22, 0.4)
    accent = material("hawk_accent", (0.25, 1.0, 0.5), 1.7, 0.3, 0.2)
    glass = material("hawk_glass", (0.8, 1.0, 0.9), 0.6, 0.2, 0.1)
    warhead = material("hawk_warhead", (1.0, 0.4, 0.2), 1.4, 0.2, 0.3)
    box((0.42, 1.8, 0.28), (0, 0, 0), mat=hull, bevel=0.06, name="hull")
    cone(0.22, 0.6, (0, 1.2, 0), (math.radians(-90), 0, 0), 6, hull, name="nose")
    for side in (-1, 1):
        # İleri süpürülmüş kanat
        box((0.95, 0.38, 0.08), (side * 0.6, 0.0, 0.0), (0, 0, math.radians(side * 22)), mat=hull, bevel=0.03, name="wing")
        box((0.7, 0.05, 0.04), (side * 0.62, 0.17, 0.05), (0, 0, math.radians(side * 22)), mat=accent, name="wing_glow")
        for k, off in enumerate((0.42, 0.78)):
            cyl(0.07, 0.6, (side * off, 0.12 + k * 0.12, -0.13), (math.radians(90), 0, 0), 8, hull, name="rocket")
            cone(0.07, 0.16, (side * off, 0.5 + k * 0.12, -0.13), (math.radians(-90), 0, 0), 8, warhead, name="rocket_tip")
        box((0.05, 0.42, 0.42), (side * 0.22, -0.82, 0.22), (0, math.radians(side * 18), 0), mat=hull, bevel=0.02, name="tail")
        box((0.03, 0.3, 0.04), (side * 0.26, -0.82, 0.42), (0, math.radians(side * 18), 0), mat=accent, name="tail_glow")
    box((0.05, 1.1, 0.05), (0, 0.15, 0.16), mat=accent, name="spine_glow")
    sphere(0.12, (0, 0.5, 0.15), 2, glass, scale=(1.0, 1.7, 0.8), name="cockpit")
    for side in (-1, 1):
        cyl(0.12, 0.3, (side * 0.12, -1.02, 0), (math.radians(90), 0, 0), 10, accent, name="engine")
    export("ship_hawk.glb")


# --- Boss 2: KIZIL DEV (kızgın lav, iri ve boynuzlu) ---------------------------
def make_boss_titan():
    reset()
    rock = material("titan_rock", (0.24, 0.09, 0.06), 0.0, 0.22, 0.55)
    lava = material("titan_lava", (1.0, 0.32, 0.06), 2.4, 0.2, 0.3)
    ember = material("titan_ember", (1.0, 0.75, 0.2), 2.0, 0.2, 0.3)
    box((2.6, 2.2, 1.3), (0, 0, 0), mat=rock, bevel=0.28, name="torso")
    box((1.7, 1.2, 0.8), (0, 0.55, 0.75), mat=rock, bevel=0.2, name="head")
    for side in (-1, 1):
        # Omuz zırhı + boynuz
        box((1.1, 1.3, 0.9), (side * 1.55, -0.1, 0.35), (0, math.radians(side * 12), 0), mat=rock, bevel=0.18, name="shoulder")
        cone(0.32, 1.3, (side * 0.75, 0.85, 1.3), (math.radians(-35), math.radians(side * 30), 0), 6, rock, name="horn")
        sphere(0.13, (side * 1.05, 1.35, 1.75), 1, ember, name="horn_tip")
        # Yumruk
        box((0.8, 0.9, 0.75), (side * 1.85, 0.95, -0.15), mat=rock, bevel=0.15, name="fist")
        box((0.84, 0.12, 0.6), (side * 1.85, 1.42, -0.15), mat=lava, name="knuckle")
        for k in range(3):
            box((0.08, 1.0, 0.06), (side * (1.3 + k * 0.25), -0.1, 0.82), mat=lava, name="crack")
    # Göğüs çekirdeği ve lav damarları
    sphere(0.55, (0, 1.08, 0.1), 2, lava, scale=(1.0, 0.5, 1.0), name="core")
    for k in range(4):
        box((0.07, 0.07, 1.1), (-0.6 + k * 0.4, 1.12, -0.05), (0, math.radians(15 - k * 10), 0), mat=lava, name="vein")
    for side in (-1, 1):
        box((0.36, 0.12, 0.16), (side * 0.38, 1.17, 0.88), mat=ember, name="eye")
    # Üstten görünen lav çatlakları (oyun kamerası yukarıdan bakar)
    for k, (x, y, r) in enumerate([(-0.7, -0.5, 20), (0.1, -0.2, -35), (0.75, -0.6, 50), (-0.2, -0.85, 80), (0.5, 0.1, -10)]):
        box((0.9, 0.09, 0.05), (x, y, 0.66), (0, 0, math.radians(r)), mat=lava, name="top_crack")
    box((1.2, 0.1, 0.05), (0, 0.55, 1.16), mat=lava, name="head_crack")
    for side in (-1, 1):
        sphere(0.22, (side * 1.55, -0.1, 0.82), 1, ember, scale=(1.0, 1.0, 0.5), name="vent")
    torus(2.4, 0.06, (0, 0, -0.55), (0, 0, 0), lava, name="ring")
    export("boss_titan.glb")


# --- Boss 3: BUZ HÜKÜMDARI (kristal çekirdek, yörüngede buz kanatları) ----------
def make_boss_frost():
    reset()
    ice = material("frost_ice", (0.36, 0.56, 0.72), 0.0, 0.22, 0.15)
    glow = material("frost_glow", (0.35, 0.85, 1.0), 2.2, 0.2, 0.15)
    white = material("frost_white", (0.85, 0.97, 1.0), 2.0, 0.2, 0.1)
    # Çift sivri kristal gövde
    cone(1.05, 2.0, (0, 0, 0.9), (0, 0, math.radians(45)), 4, ice, name="crown")
    cone(1.05, 1.7, (0, 0, -0.75), (math.radians(180), 0, math.radians(45)), 4, ice, name="keel")
    sphere(0.55, (0, 0, 0.1), 2, white, scale=(1.0, 1.0, 1.0), name="core")
    torus(1.35, 0.05, (0, 0, 0.1), (0, 0, 0), glow, name="halo")
    torus(1.75, 0.04, (0, 0, 0.1), (math.radians(70), 0, 0), glow, name="orbit")
    # Yörüngedeki 6 buz kanadı
    for i in range(6):
        ang = math.radians(i * 60 + 30)
        x, y = math.cos(ang) * 2.15, math.sin(ang) * 2.15
        cone(0.32, 1.5, (x, y, 0.1), (math.radians(90), 0, ang - math.pi / 2), 4, ice, name="shard")
        box((0.06, 0.06, 0.9), (x * 0.8, y * 0.8, 0.1), (math.radians(90), 0, ang - math.pi / 2), mat=glow, name="shard_glow")
        sphere(0.12, (math.cos(ang) * 2.95, math.sin(ang) * 2.95, 0.1), 1, white, name="shard_tip")
    for i in range(3):
        ang = math.radians(i * 120)
        sphere(0.14, (math.cos(ang) * 0.75, math.sin(ang) * 0.75, 0.95), 1, glow, name="eye")
    export("boss_frost.glb")


ALL = [
    make_ship, make_chaser, make_shooter, make_tank, make_pillar, make_crate, make_dais, make_swarmer,
    make_bomber, make_sniper, make_orbiter, make_boss, make_crystal, make_obelisk, make_barrier,
    make_ship_storm, make_ship_lance, make_ship_hawk, make_boss_titan, make_boss_frost,
]


if __name__ == "__main__":
    import sys
    # blender -b --python tools/blender/make_models.py -- ship_storm,ship_lance   → yalnız bunlar
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    wanted = set(args[0].split(",")) if args else None
    for fn in ALL:
        if wanted is None or fn.__name__.replace("make_", "") in wanted:
            fn()
