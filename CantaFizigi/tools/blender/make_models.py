#!/usr/bin/env python3
"""CantaFizigi — stylized low-poly asset generator (Blender headless).

Usage:
    /Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup \
        --python tools/blender/make_models.py -- --out assets/models

Every model is exported as ONE mesh object that satisfies:
  * all transforms applied (location = 0, rotation = 0, scale = 1)
  * origin exactly at the bottom-center of the bounding box
  * glTF +Y up / +Z forward  (Blender -Y front -> Godot +Z forward)
  * flat shading, no textures, <= 3-4 material slots (mobile draw-call budget)

Convention: 1 unit = 1 metre. One bag cell = 0.075 m.
"""

import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix

# --------------------------------------------------------------------------
# palette (sRGB hex -> linear for Principled BSDF)
# --------------------------------------------------------------------------
BODY_MINT = "#8FD9B6"
TRIM_CREAM = "#FFF0D2"
DIVIDER_BLUE = "#A9CFEA"
ACCENT_LAVENDER = "#B9A3EC"

GLASS_BLUE = "#7FB8F0"
GLASS_DARK = "#4C7FB5"

ICE_CYAN = "#9FE8EF"
ICE_DEEP = "#5FC7D6"

IRON_DARK = "#4A5060"
STEEL = "#9AA3B2"

SPRING_YELLOW = "#FFD75E"
SPRING_DEEP = "#C9861C"
SPRING_CREAM = "#FFE9A8"

# bag geometry (metres)
CELL = 0.075
COLS, ROWS = 4, 5
WALL = 0.014
DIV_T = 0.005
DEPTH = 0.095
INNER_W = COLS * CELL          # 0.300
INNER_H = ROWS * CELL          # 0.375
OUTER_W = INNER_W + 2 * WALL   # 0.328
OUTER_H = INNER_H + 2 * WALL   # 0.403
XM = -OUTER_W / 2.0
XP = OUTER_W / 2.0
XIM = -INNER_W / 2.0
XIP = INNER_W / 2.0
Z0 = -WALL                     # outer bottom
Z1 = OUTER_H                   # outer top
YF = -DEPTH                    # front opening plane
YB = WALL                      # outer back plane


# --------------------------------------------------------------------------
# helpers
# --------------------------------------------------------------------------
def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def reset_scene():
    bpy.ops.object.mode_set(mode="OBJECT") if bpy.context.mode != "OBJECT" else None
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for coll in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.lights,
                 bpy.data.cameras, bpy.data.images):
        for block in list(coll):
            if block.users == 0:
                coll.remove(block)


def make_material(name, hexcol, roughness=0.62, metallic=0.0, alpha=1.0):
    existing = bpy.data.materials.get(name)
    if existing:
        return existing
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    lin = tuple(srgb_to_linear(c) for c in hex_rgb(hexcol))
    bsdf.inputs["Base Color"].default_value = (*lin, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = 0.35
    if alpha < 1.0:
        bsdf.inputs["Alpha"].default_value = alpha
        for attr, val in (("blend_method", "BLEND"),
                          ("surface_render_method", "BLENDED"),
                          ("shadow_method", "NONE")):
            try:
                setattr(mat, attr, val)
            except (AttributeError, TypeError):
                pass
    mat.use_backface_culling = True
    mat.diffuse_color = (*lin, alpha)  # solid-view / workbench colour
    return mat


def _activate(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def apply_bevel(obj, width, segments):
    if width <= 0.0:
        return
    m = obj.modifiers.new("Bevel", "BEVEL")
    m.width = min(width, min(obj.dimensions) * 0.45)
    m.segments = segments
    m.limit_method = "ANGLE"
    m.angle_limit = math.radians(40.0)
    _activate(obj)
    bpy.ops.object.modifier_apply(modifier=m.name)


def add_box(name, x0, x1, y0, y1, z0, z1, mat, bevel=0.0, segments=2):
    cx, cy, cz = (x0 + x1) / 2.0, (y0 + y1) / 2.0, (z0 + z1) / 2.0
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(cx, cy, cz))
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = (abs(x1 - x0), abs(y1 - y0), abs(z1 - z0))
    _activate(obj)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    apply_bevel(obj, bevel, segments)
    obj.data.materials.append(mat)
    return obj


def add_box_size(name, size, center, mat, bevel=0.0, segments=2):
    sx, sy, sz = size
    cx, cy, cz = center
    return add_box(name, cx - sx / 2, cx + sx / 2, cy - sy / 2, cy + sy / 2,
                   cz - sz / 2, cz + sz / 2, mat, bevel, segments)


def add_taper(obj, factor):
    """Scale the topmost ring of vertices inwards (crystalline silhouette)."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    zmax = max(v.co.z for v in bm.verts)
    for v in bm.verts:
        if abs(v.co.z - zmax) < 1e-6:
            v.co.x *= factor
            v.co.y *= factor
    bm.to_mesh(obj.data)
    bm.free()


def add_stud(name, radius, depth, location, mat, vertices=6, axis="Y-"):
    """Pointed stud / rivet / crystal.

    axis "Y-" -> points at -Y (front face), "Y+" -> +Y, "Z+" -> up.
    """
    rot = {"Y+": math.radians(-90.0), "Y-": math.radians(90.0), "Z+": 0.0}[axis]
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius, radius2=0.0,
                                    depth=depth, location=location,
                                    rotation=(rot, 0.0, 0.0))
    obj = bpy.context.active_object
    obj.name = name
    _activate(obj)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    obj.data.materials.append(mat)
    return obj


def add_helix(name, center, radius, height, turns, tube_r, mat, steps_per_turn=6):
    """Low-poly helical spring as a swept poly-curve -> mesh."""
    n = int(round(turns * steps_per_turn))
    curve = bpy.data.curves.new(name + "_curve", "CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = 1
    curve.bevel_depth = tube_r
    curve.bevel_resolution = 0
    curve.use_fill_caps = True
    spline = curve.splines.new("POLY")
    spline.points.add(n)
    for i in range(n + 1):
        a = 2.0 * math.pi * turns * (i / float(n))
        spline.points[i].co = (center[0] + radius * math.cos(a),
                               center[1] + radius * math.sin(a),
                               center[2] + height * (i / float(n)), 1.0)
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    _activate(obj)
    bpy.ops.object.convert(target="MESH")
    obj = bpy.context.active_object
    obj.data.materials.append(mat)
    return obj


def add_torus(name, major_r, tube_r, location, rotation, mat, major_seg=10, minor_seg=4):
    bpy.ops.mesh.primitive_torus_add(major_radius=major_r, minor_radius=tube_r,
                                     major_segments=major_seg, minor_segments=minor_seg,
                                     location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    _activate(obj)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    obj.data.materials.append(mat)
    return obj


def join_objects(parts, name):
    _activate(parts[0])
    for p in parts:
        p.select_set(True)
    bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = name
    obj.data.name = name
    return obj


def bbox(obj):
    xs = [v.co.x for v in obj.data.vertices]
    ys = [v.co.y for v in obj.data.vertices]
    zs = [v.co.z for v in obj.data.vertices]
    return (min(xs), min(ys), min(zs)), (max(xs), max(ys), max(zs))


def finalize(obj, name):
    """Apply ALL transforms, then pin the origin to the bottom-center."""
    _activate(obj)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")

    (mn_x, mn_y, mn_z), (mx_x, mx_y, mx_z) = bbox(obj)
    obj.data.transform(Matrix.Translation((-(mn_x + mx_x) / 2.0,
                                           -(mn_y + mx_y) / 2.0,
                                           -mn_z)))
    obj.data.update()
    obj.location = (0.0, 0.0, 0.0)
    obj.rotation_euler = (0.0, 0.0, 0.0)
    obj.scale = (1.0, 1.0, 1.0)
    obj.name = name
    obj.data.name = name
    for poly in obj.data.polygons:
        poly.use_smooth = False
    return obj


def tri_count(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def export_glb(obj, path):
    _activate(obj)
    wanted = dict(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_materials="EXPORT",
        export_normals=True,
        export_texcoords=False,
        export_tangents=False,
        export_cameras=False,
        export_lights=False,
        export_extras=False,
        export_animations=False,
        export_skins=False,
        export_morph=False,
    )
    known = {p.identifier for p in bpy.ops.export_scene.gltf.get_rna_type().properties}
    kwargs = {k: v for k, v in wanted.items() if k in known}
    bpy.ops.export_scene.gltf(**kwargs)


# --------------------------------------------------------------------------
# 1. backpack_base.glb  — open front, 4x5 interior grid, pastel
# --------------------------------------------------------------------------
def build_backpack():
    body = make_material("BAG_Body", BODY_MINT, roughness=0.78)
    trim = make_material("BAG_Trim", TRIM_CREAM, roughness=0.72)
    grid = make_material("BAG_Grid", DIVIDER_BLUE, roughness=0.85)
    strap = make_material("BAG_Strap", ACCENT_LAVENDER, roughness=0.8)

    parts = []
    bev = 0.006

    # shell: back, floor, roof, two sides  (front stays open)
    parts.append(add_box("BackPanel", XM, XP, 0.0, YB, Z0, Z1, body, bev, 2))
    parts.append(add_box("Floor", XM, XP, YF, 0.0, Z0, 0.0, body, bev, 2))
    parts.append(add_box("Roof", XM, XP, YF, 0.0, INNER_H, Z1, body, bev, 2))
    parts.append(add_box("SideL", XM, XIM, YF, 0.0, 0.0, INNER_H, body, bev, 2))
    parts.append(add_box("SideR", XIP, XP, YF, 0.0, 0.0, INNER_H, body, bev, 2))

    # front collar (4 rails) -> reads as the bag opening / package lip
    rim = 0.026
    ox0, ox1 = XM - 0.006, XP + 0.006
    oz0, oz1 = Z0 - 0.006, Z1 + 0.006
    ry0, ry1 = YF - 0.010, YF + 0.016
    parts.append(add_box("RimL", ox0, ox0 + rim, ry0, ry1, oz0, oz1, trim, 0.004, 2))
    parts.append(add_box("RimR", ox1 - rim, ox1, ry0, ry1, oz0, oz1, trim, 0.004, 2))
    parts.append(add_box("RimT", ox0 + rim, ox1 - rim, ry0, ry1, oz1 - rim, oz1, trim, 0.004, 2))
    parts.append(add_box("RimB", ox0 + rim, ox1 - rim, ry0, ry1, oz0, oz0 + rim, trim, 0.004, 2))

    # cream liner on the inner back face -> makes each pocket read
    parts.append(add_box("Liner", XIM, XIP, -0.003, 0.001, 0.0, INNER_H, trim))

    # interior 4x5 grid (3 vertical dividers + 4 shelves = 20 cells)
    gy0, gy1 = YF + 0.008, -0.002
    for i in range(1, COLS):
        gx = XIM + i * CELL
        parts.append(add_box("DivV%d" % i, gx - DIV_T / 2, gx + DIV_T / 2,
                             gy0, gy1, 0.0, INNER_H, grid))
    for j in range(1, ROWS):
        gz = j * CELL
        parts.append(add_box("DivH%d" % j, XIM, XIP, gy0, gy1,
                             gz - 0.002, gz + 0.002, grid))

    # shoulder straps + buckles on the back
    for side, sx0, sx1 in (("L", -0.120, -0.068), ("R", 0.068, 0.120)):
        parts.append(add_box("Strap" + side, sx0, sx1, YB, YB + 0.013,
                             0.052, OUTER_H - 0.020, strap, 0.005, 1))
        parts.append(add_box("Buckle" + side, sx0 + 0.008, sx1 - 0.008,
                             YB + 0.013, YB + 0.019,
                             0.108, 0.128, trim, 0.002, 1))

    # side utility pockets
    for side, sx0, sx1 in (("L", XM - 0.009, XM + 0.001), ("R", XP - 0.001, XP + 0.009)):
        parts.append(add_box("Pocket" + side, sx0, sx1, -0.070, -0.018,
                             0.100, 0.176, trim, 0.004, 1))

    # top carry handle
    parts.append(add_torus("Handle", 0.026, 0.0075, (0.0, -0.040, Z1 + 0.013),
                           (0.0, math.radians(90.0), 0.0), trim, 10, 4))

    obj = join_objects(parts, "BackpackBase")
    return finalize(obj, "BackpackBase")


# --------------------------------------------------------------------------
# 2. pkg_glass_1x2.glb — 1x1 cell footprint, 2 cells tall, translucent blue
# --------------------------------------------------------------------------
def build_glass():
    glass = make_material("Glass_Blue", GLASS_BLUE, roughness=0.10, alpha=0.42)
    frame = make_material("Glass_Frame", GLASS_DARK, roughness=0.35)

    w, d, h = CELL, CELL, CELL * 2.0
    x0, x1 = -w / 2.0, w / 2.0
    y0, y1 = -d / 2.0, d / 2.0

    parts = [add_box("Body", x0 + 0.004, x1 - 0.004, y0 + 0.004, y1 - 0.004,
                     0.008, h - 0.012, glass, 0.006, 2)]
    parts.append(add_box("Foot", x0, x1, y0, y1, 0.0, 0.010, frame, 0.003, 1))
    parts.append(add_box("Lid", x0, x1, y0, y1, h - 0.012, h, frame, 0.004, 2))
    # corner posts make the silhouette read as a crate
    for ix, px in ((0, x0), (1, x1)):
        for iy, py in ((0, y0), (1, y1)):
            sx0, sx1 = (px, px + 0.008) if ix == 0 else (px - 0.008, px)
            sy0, sy1 = (py, py + 0.008) if iy == 0 else (py - 0.008, py)
            parts.append(add_box("Post%d%d" % (ix, iy), sx0, sx1, sy0, sy1,
                                 0.010, h - 0.012, frame))

    obj = join_objects(parts, "PkgGlass1x2")
    return finalize(obj, "PkgGlass1x2")


# --------------------------------------------------------------------------
# 3. pkg_ice_1x1.glb — light cyan ice pack, crystalline silhouette
# --------------------------------------------------------------------------
def build_ice():
    ice = make_material("Ice_Cyan", ICE_CYAN, roughness=0.28)
    deep = make_material("Ice_Deep", ICE_DEEP, roughness=0.42)

    s = CELL
    block_h = s * 0.80
    parts = [add_box_size("Block", (s, s, block_h), (0.0, 0.0, block_h / 2.0), ice, 0.0, 2)]

    # crystalline taper before bevelling
    add_taper(parts[0], 0.87)
    apply_bevel(parts[0], 0.010, 2)

    parts.append(add_box_size("Base", (s * 0.94, s * 0.94, 0.008),
                              (0.0, 0.0, 0.004), deep, 0.003, 1))

    # three frozen shards rising out of the top facet (tips stay <= s)
    for i, (px, py, r, top) in enumerate(((-0.017, -0.007, 0.013, s),
                                          (0.016, 0.013, 0.011, s * 0.94),
                                          (-0.001, 0.023, 0.0095, s * 0.90))):
        depth = top - (block_h - 0.014)
        parts.append(add_stud("Shard%d" % i, r, depth,
                              (px, py, (block_h - 0.014 + top) / 2.0), deep,
                              vertices=5, axis="Z+"))

    obj = join_objects(parts, "PkgIce1x1")
    return finalize(obj, "PkgIce1x1")


# --------------------------------------------------------------------------
# 4. pkg_iron_2x2.glb — 2x2 heavy iron crate with rivets
# --------------------------------------------------------------------------
def build_iron():
    iron = make_material("Iron_Dark", IRON_DARK, roughness=0.42, metallic=0.85)
    steel = make_material("Iron_Steel", STEEL, roughness=0.32, metallic=0.95)

    w = CELL * 2.0
    h = CELL * 2.0
    d = CELL
    parts = [add_box_size("Core", (w - 0.012, d - 0.006, h - 0.012),
                          (0.0, 0.0, h / 2.0), iron, 0.005, 2)]

    # corner posts define the exact 2x2 footprint
    for ix, px in ((0, -w / 2.0 + 0.008), (1, w / 2.0 - 0.008)):
        for iy, py in ((0, -d / 2.0 + 0.008), (1, d / 2.0 - 0.008)):
            parts.append(add_box("Post%d%d" % (ix, iy), px - 0.008, px + 0.008,
                                 py - 0.008, py + 0.008, 0.0, h, steel, 0.002, 1))

    # horizontal band top and bottom
    parts.append(add_box("BandB", -w / 2.0, w / 2.0, -d / 2.0, d / 2.0,
                         0.010, 0.022, steel, 0.002, 1))
    parts.append(add_box("BandT", -w / 2.0, w / 2.0, -d / 2.0, d / 2.0,
                         h - 0.022, h - 0.010, steel, 0.002, 1))

    # rivets on the front and back faces
    for i, (px, pz) in enumerate(((-0.052, 0.040), (0.052, 0.040),
                                  (-0.052, 0.110), (0.052, 0.110))):
        parts.append(add_stud("RivF%d" % i, 0.0070, 0.008,
                              (px, -d / 2.0 + 0.0025, pz), steel, axis="Y-"))
        parts.append(add_stud("RivB%d" % i, 0.0070, 0.008,
                              (px, d / 2.0 - 0.0025, pz), steel, axis="Y+"))

    obj = join_objects(parts, "PkgIron2x2")
    return finalize(obj, "PkgIron2x2")


# --------------------------------------------------------------------------
# 5. pkg_spring_1x1.glb — yellow shock-absorber box with helix spring
# --------------------------------------------------------------------------
def build_spring():
    shell = make_material("Spring_Shell", SPRING_YELLOW, roughness=0.55)
    coil = make_material("Spring_Coil", SPRING_DEEP, roughness=0.35, metallic=0.3)
    inner = make_material("Spring_Inner", SPRING_CREAM, roughness=0.75)

    s = CELL
    body_h = 0.030
    lip = 0.008
    x0, x1 = -s / 2.0, s / 2.0

    parts = [add_box("Tray", x0, x1, x0, x1, 0.0, body_h, shell, 0.006, 2)]
    parts.append(add_box("Pedestal", x0 + 0.014, x1 - 0.014, x0 + 0.014, x1 - 0.014,
                         0.0, 0.022, inner))

    # rim frame around the open top
    t = 0.0085
    z0, z1 = body_h, body_h + lip
    parts.append(add_box("LipL", x0, x0 + t, x0, x1, z0, z1, shell))
    parts.append(add_box("LipR", x1 - t, x1, x0, x1, z0, z1, shell))
    parts.append(add_box("LipF", x0 + t, x1 - t, x0, x0 + t, z0, z1, shell))
    parts.append(add_box("LipB", x0 + t, x1 - t, x1 - t, x1, z0, z1, shell))

    # the spring itself: starts inside the tray, protrudes above the rim
    parts.append(add_helix("Coil", (0.0, 0.0, 0.024), 0.0235, 0.044, 3.0, 0.0048,
                           coil, steps_per_turn=6))

    obj = join_objects(parts, "PkgSpring1x1")
    return finalize(obj, "PkgSpring1x1")


# --------------------------------------------------------------------------
# main
# --------------------------------------------------------------------------
BUILDERS = [
    ("backpack_base.glb", build_backpack),
    ("pkg_glass_1x2.glb", build_glass),
    ("pkg_ice_1x1.glb", build_ice),
    ("pkg_iron_2x2.glb", build_iron),
    ("pkg_spring_1x1.glb", build_spring),
]


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out_dir = "assets/models"
    if "--out" in argv:
        out_dir = argv[argv.index("--out") + 1]
    out_dir = os.path.abspath(out_dir)
    os.makedirs(out_dir, exist_ok=True)

    total = 0
    rows = []
    for filename, builder in BUILDERS:
        reset_scene()
        obj = builder()
        path = os.path.join(out_dir, filename)
        export_glb(obj, path)

        tris = tri_count(obj)
        total += tris
        (mnx, mny, mnz), (mxx, mxy, mxz) = bbox(obj)
        rows.append((filename, tris, len(obj.data.materials),
                     (mxx - mnx, mxy - mny, mxz - mnz),
                     (mnz, (mnx + mxx) / 2.0, (mny + mxy) / 2.0),
                     os.path.getsize(path)))
        print("BUILT %-22s tris=%-5d mats=%d dims=%.3f/%.3f/%.3f size=%.1fKB"
              % (filename, tris, len(obj.data.materials),
                 mxx - mnx, mxy - mny, mxz - mnz, os.path.getsize(path) / 1024.0))

    print("TOTAL_TRIS %d" % total)
    print("OUT_DIR %s" % out_dir)


main()
