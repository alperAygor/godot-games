"""Priz — sekiz cihaz + fiş (her biri ayrı GLB).

Sözleşme (her cihaz):
  - Orijin: taban merkezi; ön yüz Blender -Y (Godot +Z).
  - "Body": durağan gövde (malzeme başına bir yüzey).
  - Hareketli/efektli parçalar ayrı düğüm, orijinleri dönme/kayma ekseninde (pivot):
      Fridge : Indicator
      Oven   : Interior (fx_oven_glow), Glass, Knob_L, Knob_R, Indicator, LightAnchor
      Washer : Drum (yerel Y ekseninde döner; çamaşırlar içinde), Glass, Dial, Indicator
      Kettle : Indicator, SteamAnchor
      Toaster: Coils (fx_coil), Toast (aşağı kayar), Lever (aşağı kayar), Knob
      TV     : Screen (fx_tv_screen), Indicator, LightAnchor
      Fan    : Head (Z/Godot-Y ekseninde salınır) > Blades (yerel Y/Godot-Z ekseninde döner), BladeBlur
      Lamp   : Shade (fx_lamp_shade), Bulb (fx_bulb), LightAnchor
      Plug   : Body, CableAnchor (kablonun çıktığı nokta); pimler +Y (Godot -Z) yönünde
  - "PlugAnchor": cihazın kablosunun gövdeden çıktığı nokta.

    blender -b -P tools/blender/make_appliances.py [-- --only=fan,lamp] [-- --no-bake]
"""

import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.dont_write_bytecode = True  # depoya __pycache__ düşmesin
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import priz_bl as P  # noqa: E402
import priz_decor as D  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ONLY = []
for a in ARGS:
    if a.startswith("--only="):
        ONLY = a[7:].split(",")
BAKE = "--no-bake" not in ARGS
OUT = os.path.join(P.MODELS, "appliances")
PLUG_SCALE = 1.3


def parent(child, par):
    child.parent = par
    child.matrix_parent_inverse = par.matrix_world.inverted()


def node_from(objs, name, pivot=None):
    """Nesneleri birleştirip adlı düğüm yapar; pivot verilirse orijin oraya taşınır."""
    ob = P.join(list(objs), name)
    if pivot is not None:
        P.set_origin(ob, pivot)
    return ob


def raw_box(bm, x0, x1, y0, y1, z0, z1):
    ret = bmesh.ops.create_cube(bm, size=1.0)
    for v in ret["verts"]:
        v.co.x = x0 if v.co.x < 0 else x1
        v.co.y = y0 if v.co.y < 0 else y1
        v.co.z = z0 if v.co.z < 0 else z1


def inner_box(name, x0, x1, y0, y1, z0, z1, material, open_side="-y", bev=0.02):
    """İçi görünen açık kutu (normaller içe). UV (Godot): u = x, UV.y = 0 altta → 1 üstte."""
    bm = bmesh.new()
    raw_box(bm, x0, x1, y0, y1, z0, z1)
    ax = {"-y": (1, -1), "+z": (2, 1)}[open_side]
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.normal[ax[0]] * ax[1] > 0.5], context="FACES")
    bmesh.ops.reverse_faces(bm, faces=bm.faces)
    ob = P.obj_from_bm(name, bm, material)
    if bev:
        P.bevel(ob, bev, 3, angle=30)
    P.smooth(ob, 40, weighted=False)
    me = ob.data
    uvl = me.uv_layers.new(name="UVMap")
    for p in me.polygons:
        for li in p.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            uvl.data[li].uv = ((co.x - x0) / (x1 - x0), P.gv((co.z - z0) / (z1 - z0)))
    return ob


def disc_y(name, r, y, z, material, verts=32, x=0.0, depth=0.004):
    return P.cyl(name, r, depth, (x, y, z), material, verts=verts, axis="Y", bev=0.0)


def finish_export(name, objs_all):
    if BAKE:
        meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
        P.bake_vertex_ao(meshes, samples=64, distance=0.08, strength=0.6)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    P.ensure_white_vcol(meshes)
    P.collapse_materials(meshes)
    print(f"  {name}: {P.tri_count()} üçgen")
    P.export_glb(os.path.join(OUT, f"{name}.glb"))


# ================================================================ BUZDOLABI

def build_fridge():
    w, d, h = 0.64, 0.6, 1.82
    body = []
    body.append(P.box("Cab", (w, d - 0.05, h - 0.07), (0, 0.025, 0.07 + (h - 0.07) / 2), "enamel_cream", bev=0.04, seg=5,
                      uv_scale=0.25))
    body.append(P.box("Plinth", (w - 0.06, d - 0.12, 0.08), (0, 0.02, 0.04), "black_metal", bev=0.01))
    body.append(P.box("Grille", (w - 0.12, 0.01, 0.05), (0, -d / 2 + 0.06, 0.045), "chrome", bev=0.004, cuts=0))
    for k in range(5):
        body.append(P.box("GrSlat", (w - 0.14, 0.006, 0.004), (0, -d / 2 + 0.054, 0.028 + k * 0.009), "black_metal",
                          bev=0.0))
    fy = -d / 2 + 0.005
    doors = [(0.1, 1.24), (1.27, h - 0.02)]
    for i, (z0, z1) in enumerate(doors):
        body.append(P.box(f"Door{i}", (w - 0.008, 0.06, z1 - z0), (0, fy, (z0 + z1) / 2), "enamel_cream", bev=0.03,
                          seg=5, uv_scale=0.25))
        body.append(P.box(f"Gasket{i}", (w - 0.03, 0.01, z1 - z0 - 0.02), (0, fy + 0.032, (z0 + z1) / 2), "rubber_black",
                          bev=0.003))
    # Krom kulplar (sağ kenar, ayaklı)
    hx = w / 2 - 0.065
    for (z0, z1) in ((0.82, 1.18), (1.34, 1.56)):
        pts = [Vector((hx, fy - 0.03, z0)), Vector((hx, fy - 0.065, z0 + 0.03)), Vector((hx, fy - 0.065, z1 - 0.03)),
               Vector((hx, fy - 0.03, z1))]
        body.append(P.sweep("Handle", P.resample(P.fillet_path(pts, 0.025, 6), 0.02), 0.011, "chrome", sides=12))
        for zz in (z0, z1):
            body.append(P.cyl("HFoot", 0.016, 0.03, (hx, fy - 0.03, zz), "chrome", axis="Y", verts=16, bev=0.003))
    # Rozet (yazısız) ve kapı çıtası
    body.append(P.box("Badge", (0.11, 0.008, 0.026), (0, fy - 0.032, h - 0.12), "chrome", bev=0.006, seg=3))
    body.append(P.box("Trim", (w - 0.02, 0.012, 0.012), (0, fy - 0.026, 1.255), "chrome", bev=0.004))
    # Ayaklar
    for (fx, fyy) in ((-w / 2 + 0.06, -d / 2 + 0.08), (w / 2 - 0.06, -d / 2 + 0.08)):
        body.append(P.cyl("Foot", 0.02, 0.02, (fx, fyy, 0.0), "black_metal", verts=16, bev=0.004))
    node_from(body, "Body")
    ind = P.cyl("Indicator", 0.007, 0.006, (-0.18, fy - 0.033, h - 0.12), "fx_indicator", axis="Y", verts=16, bev=0.002)
    P.set_origin(ind, (-0.18, fy - 0.033, h - 0.12))
    P.empty("PlugAnchor", (0.2, d / 2 - 0.02, 0.15))
    finish_export("fridge", None)


# ================================================================ FIRIN

def build_oven():
    w, d, h = 0.6, 0.58, 0.86
    fy = -d / 2
    body = []
    body.append(P.box("Shell", (w - 0.01, d - 0.03, h - 0.1), (0, 0.015, 0.1 + (h - 0.1) / 2), "enamel_graphite", bev=0.01))
    # Kontrol şeridi (paslanmaz) + kapak (siyah cam, pencereli)
    body.append(P.box("Panel", (w - 0.004, 0.022, 0.12), (0, fy, 0.78), "steel_brushed", bev=0.005, grain="X"))
    door = P.box("Door", (w - 0.004, 0.04, 0.6), (0, fy, 0.1 + 0.3 + 0.01), "hob_glass", bev=0.008, uv_scale=0.25)
    cut = P.box("Cut", (0.44, 0.1, 0.27), (0, fy, 0.39), "hob_glass", bev=0.0)
    bo = door.modifiers.new("cut", "BOOLEAN")
    bo.operation = "DIFFERENCE"
    bo.object = cut
    P.apply_mods(door)
    bpy.data.objects.remove(cut)
    P.smooth(door, 35)
    body.append(door)
    # Pencere çerçevesi (paslanmaz ince kenar)
    for (px, pz, sx, sz) in ((0, 0.39 + 0.135, 0.45, 0.008), (0, 0.39 - 0.135, 0.45, 0.008), (-0.222, 0.39, 0.008, 0.28),
                             (0.222, 0.39, 0.008, 0.28)):
        body.append(P.box("WinTrim", (sx, 0.012, sz), (px, fy - 0.02, pz), "steel_brushed", bev=0.002))
    # Kapak kulpu (çubuk + ayaklar)
    hz = 0.655
    pts = [Vector((-0.22, fy - 0.02, hz)), Vector((-0.2, fy - 0.06, hz)), Vector((0.2, fy - 0.06, hz)),
           Vector((0.22, fy - 0.02, hz))]
    body.append(P.sweep("OvenHandle", P.resample(P.fillet_path(pts, 0.02, 6), 0.03), 0.01, "steel_brushed", sides=12))
    body.append(P.box("Kick", (w - 0.004, 0.02, 0.1), (0, fy + 0.04, 0.05), "black_metal", bev=0.003))
    # İç hazne: tel raf, tepsi, kek
    body.append(P.box("Back", (0.5, 0.01, 0.34), (0, 0.24, 0.39), "enamel_graphite", bev=0.0))
    for k in range(9):
        x = -0.2 + k * 0.05
        body.append(P.sweep("RackW", [Vector((x, fy + 0.06, 0.33)), Vector((x, 0.2, 0.33))], 0.0022, "chrome", sides=5))
    for yy in (fy + 0.06, 0.2):
        body.append(P.sweep("RackF", [Vector((-0.22, yy, 0.33)), Vector((0.22, yy, 0.33))], 0.003, "chrome", sides=5))
    body.append(P.box("Tray", (0.3, 0.24, 0.02), (0, -0.02, 0.345), "black_metal", bev=0.004))
    body.append(P.lathe("Cake", [(0, 0), (0.085, 0), (0.09, 0.01), (0.088, 0.045), (0.07, 0.06), (0, 0.065)],
                        (0, -0.02, 0.355), "food_bread", verts=32, sub=1))
    node_from(body, "Body")
    interior = inner_box("Interior", -0.24, 0.24, fy + 0.03, 0.245, 0.24, 0.535, "fx_oven_glow", bev=0.025)
    P.set_origin(interior, (0, 0, 0.39))
    glass = P.box("Glass", (0.44, 0.006, 0.27), (0, fy + 0.006, 0.39), "glass_dark", bev=0.0)
    for side, kx in (("L", -0.2), ("R", 0.2)):
        parts = [P.cyl(f"Knob{side}", 0.026, 0.026, (kx, fy - 0.011, 0.78), "chrome", axis="Y", verts=32, bev=0.004)]
        parts[0].location.y -= 0.026
        parts.append(P.box(f"KnobGrip{side}", (0.008, 0.02, 0.04), (kx, fy - 0.045, 0.78), "chrome", bev=0.003))
        parts.append(P.box(f"KnobMark{side}", (0.004, 0.004, 0.012), (kx, fy - 0.05, 0.796), "black_metal", bev=0.0))
        node_from(parts, f"Knob_{side}", pivot=(kx, fy - 0.02, 0.78))
    ind = P.cyl("Indicator", 0.006, 0.006, (0.0, fy - 0.014, 0.8), "fx_indicator", axis="Y", verts=16, bev=0.002)
    P.set_origin(ind, (0.0, fy - 0.014, 0.8))
    P.empty("LightAnchor", (0, fy - 0.12, 0.42))
    P.empty("PlugAnchor", (0.22, d / 2 - 0.02, 0.1))
    finish_export("oven", None)


# ================================================================ ÇAMAŞIR MAKİNESİ

def build_washer():
    w, d, h = 0.6, 0.58, 0.85
    fy = -d / 2
    cz = 0.4
    body = []
    shell = P.box("Shell", (w - 0.004, d - 0.01, h - 0.02), (0, 0.005, 0.02 + (h - 0.02) / 2), "enamel_white", bev=0.025,
                  seg=4, uv_scale=0.25)
    cut = P.cyl("Cut", 0.17, 0.2, (0, fy - 0.1, cz), "enamel_white", axis="Y", verts=48, bev=0.0)
    bo = shell.modifiers.new("cut", "BOOLEAN")
    bo.operation = "DIFFERENCE"
    bo.object = cut
    P.apply_mods(shell)
    bpy.data.objects.remove(cut)
    P.smooth(shell, 35)
    body.append(shell)
    # Ön panel ayrımı + çekmece + kick
    body.append(P.box("PanelLine", (w - 0.01, 0.004, 0.004), (0, fy - 0.001, 0.73), "plastic_grey", bev=0.0))
    body.append(P.box("Drawer", (0.2, 0.012, 0.08), (-0.17, fy - 0.004, 0.785), "plastic_white", bev=0.006))
    body.append(P.box("DrawerGrip", (0.08, 0.006, 0.012), (-0.17, fy - 0.01, 0.765), "plastic_grey", bev=0.003))
    body.append(P.box("KickLine", (w - 0.04, 0.004, 0.004), (0, fy - 0.001, 0.09), "plastic_grey", bev=0.0))
    body.append(P.box("Feet", (w - 0.06, d - 0.08, 0.02), (0, 0.0, 0.01), "rubber_black", bev=0.004))
    # Kapak halkası (krom) + iç conta
    ring = P.lathe("DoorRing", [(0.155, 0.0), (0.2, 0.0), (0.21, 0.012), (0.2, 0.03), (0.17, 0.034), (0.15, 0.02)],
                   (0, fy - 0.0, cz), "chrome", verts=64, axis="Y", rot=(0, 0, math.pi), close_top=False,
                   close_bottom=False)
    body.append(ring)
    body.append(P.lathe("Boot", [(0.17, 0.0), (0.165, 0.03), (0.155, 0.05)], (0, fy + 0.0, cz), "rubber_black",
                        verts=48, axis="Y", close_top=False, close_bottom=False))
    body.append(P.box("Hinge", (0.03, 0.02, 0.08), (-0.2, fy - 0.02, cz), "chrome", bev=0.006))
    node_from(body, "Body")
    glass = P.lathe("Glass", [(0.0, 0.03), (0.08, 0.028), (0.15, 0.015), (0.16, 0.0)], (0, fy - 0.0, cz), "glass_clear",
                    verts=48, axis="Y", rot=(0, 0, math.pi), close_bottom=False)
    # Tambur: içi görünen silindir (normaller içe) + kanatçıklar + çamaşırlar
    drum_parts = []
    dr = 0.155
    prof = [(dr, -0.02), (dr, 0.36), (0.0, 0.36)]
    drum = P.lathe("DrumShell", prof, (0, fy + 0.04, cz), "fx_drum", verts=48, axis="Y", close_bottom=False,
                   close_top=False)
    bm = bmesh.new()
    bm.from_mesh(drum.data)
    bmesh.ops.reverse_faces(bm, faces=bm.faces)
    bm.to_mesh(drum.data)
    bm.free()
    drum_parts.append(drum)
    # Delik deseni yerine kabartma halkalar (yakın planda tambur dokusu)
    for k in range(3):
        yy = fy + 0.09 + k * 0.09
        drum_parts.append(P.sweep("DrumRib", [Vector((dr * math.cos(a) * 0.99, yy, cz + dr * math.sin(a) * 0.99)) for a in
                                              [i * math.pi / 16 for i in range(32)]], 0.0025, "fx_drum", sides=4,
                                  closed=True))
    for k in range(3):
        a = k * 2 * math.pi / 3
        c = Vector((math.cos(a) * (dr - 0.02), fy + 0.2, cz + math.sin(a) * (dr - 0.02)))
        pad = P.box("Paddle", (0.03, 0.3, 0.03), (0, 0, 0), "fx_drum", bev=0.01, seg=3)
        pad.location = c
        pad.rotation_euler = (0, -a, 0)
        drum_parts.append(pad)
    cols = ["fabric_terracotta", "fabric_mustard", "fabric_teal", "fabric_oat", "fabric_charcoal"]
    for k in range(4):
        a = math.radians(232 + k * 22)
        rr = dr - 0.05
        c = (rr * math.cos(a), fy + 0.08 + (k % 3) * 0.07, cz + rr * math.sin(a))
        drum_parts += D.cushion(f"Cloth{k}", c, (0.11, 0.07, 0.06), cols[k % len(cols)], rot=(k * 0.7, k * 1.3, k * 0.4),
                                puff=0.6)
    node_from(drum_parts, "Drum", pivot=(0, fy + 0.2, cz))
    dial = [P.cyl("DialB", 0.032, 0.022, (0.17, fy - 0.022, 0.785), "chrome", axis="Y", verts=32, bev=0.005)]
    dial.append(P.box("DialMark", (0.004, 0.004, 0.018), (0.17, fy - 0.024, 0.804), "plastic_grey", bev=0.0))
    node_from(dial, "Dial", pivot=(0.17, fy, 0.785))
    ind = P.cyl("Indicator", 0.006, 0.006, (0.07, fy - 0.008, 0.785), "fx_indicator", axis="Y", verts=16, bev=0.002)
    P.set_origin(ind, (0.07, fy - 0.008, 0.785))
    P.empty("PlugAnchor", (0.22, d / 2 - 0.02, 0.12))
    finish_export("washer", None)


# ================================================================ SU ISITICI

def build_kettle():
    body = []
    body.append(P.lathe("Base", [(0, 0), (0.088, 0), (0.092, 0.006), (0.09, 0.022), (0.08, 0.026), (0, 0.026)],
                        (0, 0, 0), "plastic_black", verts=48))
    prof = [(0, 0.026), (0.07, 0.026), (0.078, 0.032), (0.088, 0.07), (0.09, 0.11), (0.084, 0.16), (0.07, 0.2),
            (0.058, 0.215), (0.0, 0.215)]
    body.append(P.lathe("Pot", prof, (0, 0, 0), "enamel_mint", verts=56, sub=0))
    body.append(P.lathe("Band", [(0.089, 0.028), (0.0915, 0.034), (0.0915, 0.042), (0.089, 0.046)], (0, 0, 0), "chrome",
                        verts=56, close_top=False, close_bottom=False))
    body.append(P.lathe("Lid", [(0.0, 0.214), (0.06, 0.214), (0.058, 0.222), (0.04, 0.232), (0.0, 0.236)], (0, 0, 0),
                        "chrome", verts=48))
    body.append(P.lathe("LidKnob", [(0, 0.234), (0.014, 0.234), (0.017, 0.245), (0.012, 0.256), (0, 0.258)], (0, 0, 0),
                        "plastic_black", verts=24))
    # Emzik
    sp = [Vector((0, -0.06, 0.12)), Vector((0, -0.095, 0.15)), Vector((0, -0.118, 0.185)), Vector((0, -0.126, 0.198))]
    body.append(P.sweep("Spout", P.resample(P.fillet_path(sp, 0.02, 6), 0.008), 0.02, "enamel_mint", sides=14,
                        radius_fn=lambda t: 1.0 - 0.55 * t))
    # Kulp
    hp = [Vector((0, 0.05, 0.2)), Vector((0, 0.115, 0.185)), Vector((0, 0.13, 0.12)), Vector((0, 0.115, 0.06)),
          Vector((0, 0.08, 0.045))]
    body.append(P.sweep("Handle", P.resample(P.fillet_path(hp, 0.03, 8), 0.008), 0.013, "plastic_black", sides=12))
    body.append(P.box("Switch", (0.022, 0.03, 0.014), (0, 0.105, 0.05), "plastic_black", bev=0.005))
    node_from(body, "Body")
    ind = P.box("Indicator", (0.012, 0.004, 0.006), (0, 0.118, 0.045), "fx_indicator", bev=0.0015)
    P.empty("SteamAnchor", (0, -0.128, 0.205))
    P.empty("PlugAnchor", (0, 0.07, 0.012))
    finish_export("kettle", None)


# ================================================================ EKMEK KIZARTMA MAKİNESİ

def build_toaster():
    w, d, h = 0.27, 0.16, 0.19
    body = []
    shell = P.box("Shell", (w, d, h), (0, 0, 0.018 + h / 2), "enamel_red", bev=0.045, seg=6, uv_scale=0.25)
    slots = []
    for sy in (-0.032, 0.032):
        c = P.box("SlotCut", (0.2, 0.026, 0.2), (0, sy, 0.018 + h), "enamel_red", bev=0.0)
        slots.append(c)
    for c in slots:
        bo = shell.modifiers.new("cut", "BOOLEAN")
        bo.operation = "DIFFERENCE"
        bo.object = c
        P.apply_mods(shell)
        bpy.data.objects.remove(c)
    P.bevel(shell, 0.003, 2, angle=60)
    P.smooth(shell, 35)
    body.append(shell)
    # Yuva içleri (koyu) ve krom taban/şerit
    for sy in (-0.032, 0.032):
        body.append(inner_box(f"Slot{sy}", -0.1, 0.1, sy - 0.013, sy + 0.013, 0.07, 0.018 + h + 0.001, "black_metal",
                              open_side="+z", bev=0.0))
    body.append(P.box("Base", (w + 0.006, d + 0.006, 0.02), (0, 0, 0.012), "chrome", bev=0.008, seg=3))
    body.append(P.box("Band", (w + 0.002, 0.004, 0.014), (0, -d / 2 - 0.0, 0.07), "chrome", bev=0.002))
    body.append(P.box("SideSlot", (0.004, 0.012, 0.1), (w / 2 + 0.0, 0.0, 0.12), "black_metal", bev=0.002))
    for (fx, fy) in ((-0.1, -0.05), (0.1, -0.05), (-0.1, 0.05), (0.1, 0.05)):
        body.append(P.cyl("Foot", 0.01, 0.006, (fx, fy, 0.0), "rubber_black", verts=12, bev=0.002))
    node_from(body, "Body")
    # Isıtıcı teller (yuva duvarlarında zikzak)
    coils = []
    for sy in (-0.032, 0.032):
        for side in (-1, 1):
            yy = sy + side * 0.0115
            pts = []
            for k in range(17):
                x = -0.09 + k * 0.18 / 16
                z = 0.085 if k % 2 == 0 else 0.185
                pts.append(Vector((x, yy, z)))
            coils.append(P.sweep("Coil", pts, 0.0016, "fx_coil", sides=4))
    node_from(coils, "Coils")
    # Ekmek dilimleri
    toast = []
    for sy in (-0.032, 0.032):
        bm = bmesh.new()
        prof = []
        for k in range(13):
            a = math.pi * k / 12
            prof.append((0.075 * math.cos(a) * 1.02, 0.16 + 0.03 * math.sin(a)))
        verts_f = [bm.verts.new((-0.075, sy - 0.006, 0.08))] + [bm.verts.new((px, sy - 0.006, pz)) for px, pz in
                                                                reversed(prof)] + [bm.verts.new((0.075, sy - 0.006, 0.08))]
        f = bm.faces.new(verts_f)
        ext = bmesh.ops.extrude_face_region(bm, geom=[f])
        bmesh.ops.translate(bm, vec=(0, 0.012, 0), verts=[v for v in ext["geom"] if isinstance(v, bmesh.types.BMVert)])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        ob = P.obj_from_bm("Slice", bm, "food_toast")
        P.bevel(ob, 0.003, 2, angle=30)
        P.smooth(ob, 40, weighted=False)
        P.box_uv(ob, 0.2)
        toast.append(ob)
    node_from(toast, "Toast", pivot=(0, 0, 0.1))
    lever = [P.box("LeverK", (0.03, 0.028, 0.016), (w / 2 + 0.014, 0.0, 0.17), "plastic_black", bev=0.006)]
    lever.append(P.box("LeverS", (0.012, 0.006, 0.008), (w / 2 + 0.004, 0.0, 0.17), "chrome", bev=0.002))
    node_from(lever, "Lever", pivot=(w / 2 + 0.01, 0.0, 0.17))
    knob = [P.cyl("KnobB", 0.016, 0.014, (0.08, -d / 2 - 0.0, 0.06), "chrome", axis="Y", verts=24, bev=0.003)]
    knob[0].location.y -= 0.014
    node_from(knob, "Knob", pivot=(0.08, -d / 2, 0.06))
    P.empty("PlugAnchor", (0.1, d / 2, 0.03))
    finish_export("toaster", None)


# ================================================================ TELEVİZYON

def build_tv():
    sw, sh = 0.62, 0.35
    bz = 0.13  # ekran alt kenarı
    body = []
    frame = P.box("Frame", (sw + 0.03, 0.04, sh + 0.03), (0, 0, bz + sh / 2), "plastic_black", bev=0.008, seg=3)
    body.append(frame)
    body.append(P.box("Back", (sw - 0.12, 0.05, sh - 0.08), (0, 0.04, bz + sh / 2), "plastic_black", bev=0.02, seg=4))
    body.append(P.box("Chin", (sw + 0.03, 0.044, 0.018), (0, -0.001, bz - 0.006), "black_metal", bev=0.004))
    # Ayak: boyun + oval taban
    body.append(P.box("Neck", (0.05, 0.03, 0.13), (0, 0.03, 0.065), "black_metal", bev=0.008))
    base = P.cyl("Foot", 0.14, 0.014, (0, 0.0, 0.0), "black_metal", verts=48, bev=0.005)
    base.scale = (1.0, 0.55, 1.0)
    bpy.context.view_layer.update()
    P.apply_transform(base)
    body.append(base)
    node_from(body, "Body")
    # Ekran (UV 0..1, v=0 üst)
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    y = -0.0205
    vs = [bm.verts.new((-sw / 2, y, bz)), bm.verts.new((sw / 2, y, bz)), bm.verts.new((sw / 2, y, bz + sh)),
          bm.verts.new((-sw / 2, y, bz + sh))]
    f = bm.faces.new(vs)
    # Godot'da UV.y = 0 üst kenar (atlas satırları yukarıdan aşağı)
    for loop, uv in zip(f.loops, [(0, 1), (1, 1), (1, 0), (0, 0)]):
        loop[uvl].uv = (uv[0], P.gv(uv[1]))
    if f.normal.y > 0:
        f.normal_flip()
    scr = P.obj_from_bm("Screen", bm, "fx_tv_screen")
    ind = P.cyl("Indicator", 0.004, 0.004, (sw / 2 - 0.03, -0.024, bz - 0.006), "fx_indicator", axis="Y", verts=12,
                bev=0.001)
    P.empty("LightAnchor", (0, -0.3, bz + sh * 0.5))
    P.empty("PlugAnchor", (0.05, 0.06, 0.12))
    finish_export("tv", None)


# ================================================================ VANTİLATÖR

def build_fan():
    body = []
    body.append(P.lathe("Base", [(0, 0), (0.17, 0), (0.175, 0.008), (0.16, 0.03), (0.09, 0.05), (0.03, 0.06),
                                 (0, 0.062)], (0, 0, 0), "enamel_cream", verts=56))
    body.append(P.lathe("BaseRing", [(0.172, 0.0), (0.176, 0.004), (0.172, 0.008)], (0, 0, 0), "chrome", verts=56,
                        close_top=False, close_bottom=False))
    body.append(P.cyl("Pole", 0.013, 0.86, (0, 0, 0.05), "chrome", verts=20, bev=0.0))
    body.append(P.cyl("Collar", 0.022, 0.05, (0, 0, 0.5), "enamel_cream", verts=24, bev=0.008))
    body.append(P.cyl("Top", 0.02, 0.05, (0, 0, 0.9), "enamel_cream", verts=24, bev=0.006))
    node_from(body, "Body")
    hz = 1.0       # fan merkezi yüksekliği
    pivot = Vector((0, 0.06, 0.95))
    head = []
    # Motor gövdesi (arkada, Y ekseni boyunca)
    head.append(P.lathe("Motor", [(0.0, 0.0), (0.05, 0.0), (0.068, 0.03), (0.07, 0.09), (0.055, 0.135), (0.0, 0.15)],
                        (0, 0.02, hz), "enamel_cream", verts=40, axis="Y", rot=(0, 0, 0)))
    head.append(P.box("Yoke", (0.04, 0.05, 0.08), (0, 0.06, 0.955), "enamel_cream", bev=0.012, seg=3))
    head.append(P.cyl("Knob", 0.012, 0.03, (0, 0.17, hz), "chrome", axis="Y", verts=16, bev=0.003))
    # Koruma kafesi: ön ve arka halka + teller
    R = 0.2
    yf, yb = -0.06, 0.025
    for yy, rr in ((yf, R), (yb, R * 0.98)):
        head.append(P.sweep("GuardRing", [Vector((rr * math.cos(a), yy, hz + rr * math.sin(a))) for a in
                                          [i * math.pi / 32 for i in range(64)]], 0.0035, "chrome", sides=6, closed=True))
    for rr in (0.08, 0.14):
        head.append(P.sweep("GuardInner", [Vector((rr * math.cos(a), yf - 0.02 * (1 - rr / R), hz + rr * math.sin(a)))
                                           for a in [i * math.pi / 24 for i in range(48)]], 0.0018, "chrome", sides=4,
                            closed=True))
    n_sp = 20
    for k in range(n_sp):
        a = 2 * math.pi * k / n_sp
        pts_f = [Vector((r * math.cos(a), yf - 0.03 * (1 - (r / R) ** 2), hz + r * math.sin(a))) for r in
                 [0.03 + i * (R - 0.03) / 8 for i in range(9)]]
        head.append(P.sweep("SpokeF", pts_f, 0.0015, "chrome", sides=4, caps=False))
        if k % 2 == 0:
            pts_b = [Vector((r * math.cos(a), yb + 0.025 * (1 - (r / R) ** 2), hz + r * math.sin(a))) for r in
                     [0.06 + i * (R - 0.06) / 6 for i in range(7)]]
            head.append(P.sweep("SpokeB", pts_b, 0.0015, "chrome", sides=4, caps=False))
    head.append(P.cyl("Badge", 0.032, 0.008, (0, yf - 0.033, hz), "enamel_cream", axis="Y", verts=32, bev=0.003))
    headob = node_from(head, "Head", pivot=pivot)
    # Kanatlar
    blades = []
    blades.append(P.lathe("Hub", [(0.0, 0.0), (0.035, 0.0), (0.04, 0.02), (0.03, 0.035), (0.0, 0.04)], (0, -0.005, hz),
                          "enamel_cream", verts=32, axis="Y", rot=(0, 0, math.pi)))
    for k in range(3):
        lf = D.leaf_mesh(f"Blade{k}", length=0.16, width=0.11, heart=-0.4, fold=0.05, droop=0.0, nu=8, nv=3,
                         material="fan_blade")
        # Yaprak +X boyunca; Y ekseninde bükülme (hatve açısı)
        lf.rotation_euler = (math.radians(90) + math.radians(22), 0, 0)
        bpy.context.view_layer.update()
        P.apply_transform(lf)
        lf.location = (0.0, 0.0, 0.0)
        a = 2 * math.pi * k / 3
        lf.rotation_euler = (0, a, 0)
        lf.location = (0.03 * math.cos(-a), -0.012, hz + 0.03 * math.sin(-a))
        bpy.context.view_layer.update()
        P.apply_transform(lf)
        blades.append(lf)
    bladeob = node_from(blades, "Blades", pivot=(0, -0.012, hz))
    blur = bmesh.new()
    uvl = blur.loops.layers.uv.new("UVMap")
    ret = bmesh.ops.create_circle(blur, cap_ends=True, segments=48, radius=0.19)
    bmesh.ops.rotate(blur, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(90), 3, "X"), verts=blur.verts)
    for f in blur.faces:
        for loop in f.loops:
            co = loop.vert.co
            loop[uvl].uv = (co.x / 0.38 + 0.5, co.z / 0.38 + 0.5)
        if f.normal.y > 0:
            f.normal_flip()
    bmesh.ops.translate(blur, vec=(0, -0.014, hz), verts=blur.verts)
    blurob = P.obj_from_bm("BladeBlur_noshadow", blur, "fx_fan_blur")
    parent(bladeob, headob)
    parent(blurob, headob)
    P.empty("PlugAnchor", (0.0, 0.17, 0.01))
    finish_export("fan", None)


# ================================================================ ABAJUR

def build_lamp():
    body = []
    body.append(P.cyl("Foot", 0.07, 0.012, (0, 0, 0), "wood_walnut", verts=40, bev=0.004))
    body.append(P.lathe("Vase", [(0, 0.012), (0.05, 0.012), (0.075, 0.05), (0.08, 0.1), (0.06, 0.16), (0.025, 0.2),
                                 (0.02, 0.215), (0, 0.215)], (0, 0, 0), "ceramic_mustard", verts=48))
    body.append(P.cyl("Neck", 0.008, 0.11, (0, 0, 0.215), "brass", verts=16, bev=0.0))
    body.append(P.lathe("Socket", [(0, 0.3), (0.018, 0.3), (0.02, 0.33), (0.016, 0.335), (0, 0.335)], (0, 0, 0), "brass",
                        verts=24))
    # Abajur iskeleti (pirinç teller)
    for zz, rr in ((0.27, 0.152), (0.445, 0.112)):
        body.append(P.sweep("ShadeRing", [Vector((rr * math.cos(a), rr * math.sin(a), zz)) for a in
                                          [i * math.pi / 24 for i in range(48)]], 0.0022, "brass", sides=5, closed=True))
    for k in range(3):
        a = k * 2 * math.pi / 3
        body.append(P.sweep("Spider", [Vector((0, 0, 0.42)), Vector((0.11 * math.cos(a), 0.11 * math.sin(a), 0.443))],
                            0.0015, "brass", sides=4))
    node_from(body, "Body")
    shade = P.lathe("Shade", [(0.152, 0.27), (0.13, 0.36), (0.112, 0.445)], (0, 0, 0), "fx_lamp_shade", verts=56,
                    close_top=False, close_bottom=False)
    P.box_uv(shade, 1.0, grain="Z")
    # Lathe UV'si kumaş dokusu için daha iyi: çevre boyunca metre ölçekli
    me = shade.data
    uvl = me.uv_layers.active
    for p in me.polygons:
        for li in p.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            a = math.atan2(co.y, co.x)
            uvl.data[li].uv = (a * 0.14, co.z)
    bulb = P.lathe("Bulb", [(0, 0.335), (0.012, 0.335), (0.026, 0.36), (0.03, 0.38), (0.022, 0.4), (0, 0.405)],
                   (0, 0, 0), "fx_bulb", verts=24)
    P.empty("LightAnchor", (0, 0, 0.37))
    P.empty("PlugAnchor", (0, 0.06, 0.006))
    finish_export("lamp", None)


# ================================================================ FİŞ

def build_plug():
    s = PLUG_SCALE
    parts = []
    # Pimler +Y (duvara doğru); gövde -Y yönünde
    for dx in (-0.0095, 0.0095):
        parts.append(P.cyl("Pin", 0.0024, 0.019, (dx, 0.0, 0.0), "chrome", axis="Y", verts=12, bev=0.0008))
    prof = [(0.0, 0.0), (0.0185, 0.0), (0.0195, 0.002), (0.0195, 0.016), (0.0185, 0.022), (0.016, 0.03), (0.0165, 0.036),
            (0.016, 0.042), (0.0165, 0.048), (0.0125, 0.058), (0.0085, 0.064), (0.0075, 0.085), (0.0, 0.085)]
    body = P.lathe("PlugBody", prof, (0, 0, 0), "plastic_white", verts=40, axis="Y", rot=(0, 0, math.pi))
    parts.append(body)
    for dz in (-0.0195, 0.0195):
        parts.append(P.box("EarthClip", (0.008, 0.016, 0.0016), (0, -0.008, dz), "chrome", bev=0.0005, seg=1))
    ob = node_from(parts, "Body")
    for o in (ob,):
        o.scale = (s, s, s)
        bpy.context.view_layer.update()
        P.apply_transform(o)
    P.empty("CableAnchor", (0, -0.085 * s, 0))
    P.empty("PinTip", (0, 0.019 * s, 0))
    finish_export("plug", None)


BUILDERS = {
    "fridge": build_fridge, "oven": build_oven, "washer": build_washer, "kettle": build_kettle,
    "toaster": build_toaster, "tv": build_tv, "fan": build_fan, "lamp": build_lamp, "plug": build_plug,
}


def main():
    for name, fn in BUILDERS.items():
        if ONLY and name not in ONLY:
            continue
        P.reset()
        fn()


main()
