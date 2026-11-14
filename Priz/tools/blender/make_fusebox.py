"""Priz — sigorta kutusu (dünya içi arayüz).

Çıktı: assets/models/fusebox/fusebox.glb
  Orijin: duvara değen arka yüzün merkezi; ön yüz Blender -Y (Godot +Z).
  Body          : kasa, kapak çerçevesi, iç panel, kablo rakorları
  Dial          : gün dilimi kadranı (fx_dial; dört piktogram, rakamsız) + cam kubbe
  DialNeedle    : ibre (pivot kadran merkezinde, yerel Y/Godot-Z ekseninde döner)
  Module_1..4   : hat modülü ağı (şekil levhası + gösterge çerçevesi + şalter gövdesi); betik konumlar/gizler.
                  Çocukları:
      Gauge_N   : blok gösterge yüzeyi (fx_gauge; Godot'da UV.y 0 alt → 1 üst)
      Breaker_N : şalter kolu (pivot menteşede, yerel X ekseninde döner: yukarı = açık), hat renginde
  MainLever     : "günü başlat" bıçaklı şalter kolu (pivot alt menteşede, yerel X ekseni)

    blender -b -P tools/blender/make_fusebox.py [-- --no-bake]
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

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
BAKE = "--no-bake" not in ARGS

W, H, D = 0.44, 0.70, 0.12
FRONT = -D          # ön yüz düzlemi (y)
PANEL = -D + 0.018  # iç panel düzlemi (çerçevenin gerisinde)
MODULE_X = [-0.135, -0.045, 0.045, 0.135]
SHAPES = ["circle", "triangle", "square", "diamond"]


def parent(child, par):
    child.parent = par
    child.matrix_parent_inverse = par.matrix_world.inverted()


def shape_plate(name, shape, x, z, material):
    parts = [P.box(name + "_bg", (0.07, 0.008, 0.05), (x, PANEL - 0.004, z), "enamel_white", bev=0.006, seg=3)]
    s = 0.03
    y = PANEL - 0.010
    if shape == "circle":
        m = P.cyl(name + "_mk", s * 0.5, 0.006, (x, y + 0.003, z), material, verts=32, axis="Y", bev=0.0015)
        m.location.y = y - 0.003
    elif shape == "square":
        m = P.box(name + "_mk", (s * 0.85, 0.006, s * 0.85), (x, y, z), material, bev=0.0015, seg=1)
    else:
        segs = 3 if shape == "triangle" else 4
        bm = bmesh.new()
        r = s * (0.62 if segs == 3 else 0.6)
        bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r, radius2=r, depth=0.006)
        bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(180 if segs == 3 else 45), 3, "Z"),
                         verts=bm.verts)
        bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(-90), 3, "X"), verts=bm.verts)
        m = P.obj_from_bm(name + "_mk", bm, material)
        P.bevel(m, 0.0012, 1)
        P.smooth(m, 30)
        if segs == 4:
            m.rotation_euler = (0, math.radians(45), 0)
        m.location = (x, y, z + (-0.002 if segs == 3 else 0.0))
    parts.append(m)
    return P.join(parts, name)


def build():
    P.reset()
    body = []
    # Kasa: krem emaye, yuvarlatılmış
    # Kasa gövdesi panelin gerisinde biter; çerçeve öne taşar ve içe gömük panel oluşur.
    cd = -PANEL - 0.004
    body.append(P.box("Case", (W, cd, H), (0, -cd / 2, 0), "enamel_cream", bev=0.025, seg=5, uv_scale=0.25))
    # Ön çerçeve (kapak kenarı) ve içe gömük panel
    fw = 0.03
    for (px, pz, sx, sz) in ((0, H / 2 - fw / 2, W, fw), (0, -H / 2 + fw / 2, W, fw), (-W / 2 + fw / 2, 0, fw, H - 2 * fw),
                             (W / 2 - fw / 2, 0, fw, H - 2 * fw)):
        body.append(P.box("Bezel", (sx, 0.03, sz), (px, FRONT + 0.012, pz), "enamel_cream", bev=0.006, seg=2))
    body.append(P.box("Panel", (W - 2 * fw + 0.004, 0.006, H - 2 * fw + 0.004), (0, PANEL, 0), "enamel_graphite",
                      bev=0.002))
    # Menteşeler (sol) ve kilit dili (sağ)
    for hz in (0.22, -0.22):
        body.append(P.cyl("Hinge", 0.008, 0.05, (-W / 2 - 0.002, FRONT + 0.004, hz - 0.025), "chrome", verts=16, bev=0.002))
    body.append(P.box("Latch", (0.016, 0.012, 0.05), (W / 2 - 0.012, FRONT - 0.004, 0.0), "chrome", bev=0.004))
    # DIN rayı (şalterlerin oturduğu metal ray)
    body.append(P.box("Rail", (W - 0.08, 0.008, 0.028), (0, PANEL - 0.004, -0.18), "steel_brushed", bev=0.002, grain="X"))
    # Kablo rakorları (üst üç, alt bir)
    for gx in (-0.1, 0.0, 0.1):
        body.append(P.cyl("Gland", 0.012, 0.014, (gx, -0.03, H / 2 - 0.002), "chrome", verts=20, bev=0.003))
    body.append(P.cyl("GlandB", 0.012, 0.014, (0.0, -0.03, -H / 2 - 0.012), "chrome", verts=20, bev=0.003))
    # Ana şalter yuvası (alt): pirinç mafsal blokları + kanal
    body.append(P.box("LeverSlot", (0.26, 0.01, 0.12), (0, PANEL - 0.004, -0.275), "black_metal", bev=0.006))
    for bx in (-0.1, 0.1):
        body.append(P.box("PivotBlock", (0.03, 0.04, 0.04), (bx, PANEL - 0.02, -0.29), "brass", bev=0.006))
    # Kadran yuvası (pirinç çerçeve)
    dz = 0.235
    body.append(P.lathe("DialBezel", [(0.07, 0.0), (0.082, 0.0), (0.085, 0.01), (0.08, 0.018), (0.07, 0.016)],
                        (0, PANEL, dz), "brass", verts=64, axis="Y", rot=(0, 0, math.pi), close_top=False,
                        close_bottom=False))
    bodyob = P.join(body, "Body")

    # Kadran yüzü (UV: merkez 0.5,0.5; v=0 üst)
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    ret = bmesh.ops.create_circle(bm, cap_ends=True, segments=64, radius=0.07)
    bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(90), 3, "X"), verts=bm.verts)
    for f in bm.faces:
        if f.normal.y > 0:
            f.normal_flip()
        for loop in f.loops:
            co = loop.vert.co
            loop[uvl].uv = (co.x / 0.14 + 0.5, P.gv(0.5 - co.z / 0.14))
    bmesh.ops.translate(bm, vec=(0, PANEL - 0.006, dz), verts=bm.verts)
    dial = P.obj_from_bm("Dial", bm, "fx_dial")
    dome = P.lathe("DialGlass_noshadow", [(0.0, 0.026), (0.03, 0.024), (0.06, 0.014), (0.072, 0.0)], (0, PANEL - 0.004, dz),
                   "glass_clear", verts=48, axis="Y", rot=(0, 0, math.pi), close_bottom=False)
    needle = [P.box("NeedleArm", (0.006, 0.003, 0.062), (0, PANEL - 0.012, dz + 0.026), "black_metal", bev=0.001, seg=1)]
    needle.append(P.cyl("NeedleHub", 0.009, 0.006, (0, PANEL - 0.016, dz), "brass", axis="Y", verts=24, bev=0.002))
    tip = P.box("NeedleTip", (0.012, 0.003, 0.012), (0, PANEL - 0.012, dz + 0.058), "plastic_red", bev=0.0)
    tip.rotation_euler = (0, math.radians(45), 0)
    needle.append(tip)
    needleob = P.join(needle, "DialNeedle")
    P.set_origin(needleob, (0, PANEL - 0.012, dz))

    # Hat modülleri
    gauge_h = 0.2
    gz = -0.015
    for i, mx in enumerate(MODULE_X):
        n = i + 1
        mod = P.empty(f"_tmp_{n}", (mx, 0, 0))
        plate = shape_plate(f"Shape_{n}", SHAPES[i], mx, 0.125, f"paint_line{n}")
        # Gösterge yüzeyi (UV.y 0 alt)
        bm = bmesh.new()
        uvl = bm.loops.layers.uv.new("UVMap")
        gw = 0.046
        y = PANEL - 0.004
        vs = [bm.verts.new((mx - gw / 2, y, gz - gauge_h / 2)), bm.verts.new((mx + gw / 2, y, gz - gauge_h / 2)),
              bm.verts.new((mx + gw / 2, y, gz + gauge_h / 2)), bm.verts.new((mx - gw / 2, y, gz + gauge_h / 2))]
        f = bm.faces.new(vs)
        # Godot'da UV.y = 0 alt (gölgelendirici alttan doldurur)
        for loop, uv in zip(f.loops, [(0, 0), (1, 0), (1, 1), (0, 1)]):
            loop[uvl].uv = (uv[0], P.gv(uv[1]))
        if f.normal.y > 0:
            f.normal_flip()
        gauge = P.obj_from_bm(f"Gauge_{n}", bm, "fx_gauge")
        frame = []
        for (px, pz, sx, sz) in ((mx, gz + gauge_h / 2 + 0.006, gw + 0.024, 0.012),
                                 (mx, gz - gauge_h / 2 - 0.006, gw + 0.024, 0.012),
                                 (mx - gw / 2 - 0.006, gz, 0.012, gauge_h), (mx + gw / 2 + 0.006, gz, 0.012, gauge_h)):
            frame.append(P.box("GFrame", (sx, 0.014, sz), (px, PANEL - 0.008, pz), "chrome", bev=0.004, seg=1))
        frameob = P.join(frame, f"GaugeFrame_{n}")
        # Şalter gövdesi (DIN) + kol
        brk = P.box(f"BreakerBody_{n}", (0.058, 0.05, 0.085), (mx, PANEL - 0.03, -0.18), "plastic_white", bev=0.006,
                    seg=2)
        lever = [P.box("LvArm", (0.024, 0.042, 0.018), (mx, PANEL - 0.074, -0.18), f"paint_line{n}", bev=0.006, seg=2)]
        lever.append(P.box("LvBase", (0.03, 0.016, 0.026), (mx, PANEL - 0.054, -0.18), "plastic_black", bev=0.005))
        lv = P.join(lever, f"Breaker_{n}")
        P.set_origin(lv, (mx, PANEL - 0.05, -0.18))
        # Durağan modül parçaları tek düğüm (çizim çağrısı azaltma); gösterge ve kol onun çocukları.
        bpy.data.objects.remove(mod)
        modob = P.join([plate, frameob, brk], f"Module_{n}")
        P.set_origin(modob, (mx, 0, 0))
        for ob in (gauge, lv):
            parent(ob, modob)
    # Ana şalter kolu (bıçaklı şalter): iki kol + kırmızı tutamak
    lever = []
    for bx in (-0.1, 0.1):
        lever.append(P.box("MArm", (0.014, 0.13, 0.016), (bx * 0.9, PANEL - 0.085, -0.29), "chrome", bev=0.004, seg=2))
    lever.append(P.cyl("MBar", 0.011, 0.2, (-0.1, PANEL - 0.15, -0.29), "chrome", axis="X", verts=16, bev=0.002))
    grip = P.lathe("MGrip", [(0.0, 0.0), (0.017, 0.0), (0.02, 0.02), (0.019, 0.12), (0.016, 0.14), (0.0, 0.14)],
                   (-0.07, PANEL - 0.15, -0.29), "plastic_red", verts=24, axis="X")
    lever.append(grip)
    mlever = P.join(lever, "MainLever")
    P.set_origin(mlever, (0, PANEL - 0.02, -0.29))
    if BAKE:
        meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
        P.bake_vertex_ao(meshes, samples=64, distance=0.05, strength=0.55)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    P.ensure_white_vcol(meshes)
    P.collapse_materials(meshes)
    print(f"  fusebox: {P.tri_count()} üçgen")
    P.export_glb(os.path.join(P.MODELS, "fusebox", "fusebox.glb"))


build()
