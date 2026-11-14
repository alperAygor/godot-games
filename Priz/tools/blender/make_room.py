"""Priz — tek oda dioraması (stüdyo daire: mutfak köşesi + oturma köşesi).

Çıktı: assets/models/room/room_studio.glb
    Decor                  : tüm durağan geometri (kabuk + mobilya + dekor + priz plakaları + kablo kroşeleri),
                             malzeme başına bir yüzey; renk-yalnız malzemeler "vc_*" ortak malzemelerine toplanır
    ShadowBox_shadowonly   : görünmez tavan + ön/sağ duvar (yalnız gölge; güneş yalnız pencereden girer)
    WindowGlass_noshadow   : pencere camları
    WindowView_noshadow    : pencere dışı manzara düzlemi (window_sky gölgelendiricisi)
    KitchenStrip_noshadow  : raf altı ışık şeridi (gece yanar)
    Cables_noshadow        : üç hattın kabloları tek ağ (cable_lines; hat kimliği köşe renginde)
    SocketMarkers          : prizlerin hat şekil işaretleri tek ağ (socket_marker; priz/hat kimliği köşe renginde)
    Socket_01..07          : priz yerleri (boş düğüm; yerel +Z Godot'da duvardan dışarı = fişin geldiği yön)
    Anchor_*               : cihaz ve sigorta kutusu yerleri (yerel +Z Godot = cihazın ön yüzü)
    LightAnchor_*          : ışık yerleri

Blender: x sağa (arka duvar boyunca), -y kameraya doğru, z yukarı. Oda iç köşesi (0,0,0).
    blender -b -P tools/blender/make_room.py [-- --no-bake]
"""

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.dont_write_bytecode = True  # depoya __pycache__ düşmesin
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import priz_bl as P  # noqa: E402
import priz_decor as D  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
BAKE = "--no-bake" not in ARGS

# ---------------------------------------------------------------- ölçüler
W = 5.4      # arka duvar boyu (x)
DEP = 4.15   # sol duvar boyu (-y)
H = 2.7      # duvar yüksekliği
T = 0.16     # duvar kalınlığı
SLAB = 0.24  # döşeme kesit kalınlığı

WIN = (3.75, 4.85, 0.95, 2.25)      # pencere: x0, x1, z0, z1 (arka duvar)
DOOR = (-3.97, -3.12, 0.0, 2.1)      # kapı: y0, y1, z0, z1 (sol duvar)
COUNTER_Z = 0.92
SOCKET_SCALE = 1.3

# Hatlar: şekil işareti (renk körlüğü), duvardan uzaklık (s), tavan rayı yüksekliği (h).
# Renkler gölgelendiricide: 1 kırmızı/daire, 2 mavi/üçgen, 3 sarı/kare (4 mor/elmas yalnız sigorta kutusunda).
LINES = {
    1: dict(shape="circle", s=0.030, h=2.48),
    2: dict(shape="triangle", s=0.020, h=2.43),
    3: dict(shape="square", s=0.010, h=2.38),
}

# Prizler: ad, duvar ('B' arka, 'L' sol), duvar boyu konum (B: x, L: y), z, hat
SOCKETS = [
    ("Socket_01", "B", 1.62, 1.15, 1),
    ("Socket_02", "B", 2.88, 1.15, 1),
    ("Socket_03", "B", 0.37, 2.00, 2),
    ("Socket_04", "B", 3.30, 0.80, 3),
    ("Socket_05", "L", -1.30, 0.32, 3),
    ("Socket_06", "L", -2.9, 0.32, 2),
    ("Socket_07", "B", 5.28, 0.32, 2),
]

FUSE_Y = -2.62
FUSE_Z = 1.50
FUSE_H = 0.70

# Cihaz yerleri (taban merkezi, yön açısı: yerel -Y'nin dünyadaki yönü için z dönüşü)
ANCHORS = {
    "Anchor_Fridge": ((0.37, -0.33, 0.0), 0.0),
    "Anchor_Oven": ((1.04, -0.30, 0.0), 0.0),
    "Anchor_Washer": ((1.66, -0.30, 0.0), 0.0),
    "Anchor_Kettle": ((1.62, -0.30, COUNTER_Z), 0.35),
    "Anchor_Toaster": ((2.80, -0.30, COUNTER_Z), 0.0),
    "Anchor_Lamp": ((3.30, -0.24, 0.565), 0.4),
    "Anchor_TV": ((0.21, -1.85, 0.50), math.radians(90)),
    "Anchor_Fan": ((5.0, -2.75, 0.0), math.radians(-35)),
    "Anchor_FuseBox": ((0.0, FUSE_Y, FUSE_Z), math.radians(90)),
}

# AO pişirmede cihazların yerine geçici kutular (dışa aktarılmaz)
PROXIES = [
    ((0.37, -0.33, 0.91), (0.66, 0.64, 1.82)),
    ((1.04, -0.30, 0.44), (0.6, 0.58, 0.86)),
    ((1.66, -0.30, 0.43), (0.6, 0.58, 0.85)),
    ((0.21, -1.85, 0.78), (0.12, 0.9, 0.55)),
    ((3.30, -0.24, 0.8), (0.28, 0.28, 0.5)),
]

STATIC = []


def keep(objs):
    if isinstance(objs, (list, tuple)):
        STATIC.extend([o for o in objs if o is not None])
    elif objs is not None:
        STATIC.append(objs)
    return objs


# ---------------------------------------------------------------- kabuk

def classify_wall_faces(ob, interior_axis, interior_value, interior_sign, end_axis, end_value, mats):
    """Kutu parçalarından oluşan duvarın yüzlerine malzeme atar; iç yüzeydekileri siler.
    mats: dict(cut, ext, reveal)."""
    D.multi_mat(ob, [mats["cut"], mats["ext"], mats["reveal"]])
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    kill = []
    for f in bm.faces:
        c = f.calc_center_median()
        n = f.normal
        ia = "xyz".index(interior_axis)
        ea = "xyz".index(end_axis)
        if abs(c[ia] - interior_value) < 1e-4 and n[ia] * interior_sign > 0.9:
            kill.append(f)  # iç yüz: yoğun ızgara ayrıca kurulur
            continue
        if n.z < -0.9 and c.z < -SLAB + 1e-3:
            kill.append(f)
            continue
        if n.z > 0.9 and abs(c.z - H) < 1e-4:
            f.material_index = 0
        elif abs(c[ea] - end_value) < 1e-4 and abs(n[ea]) > 0.9:
            f.material_index = 0
        elif abs(n[ia]) > 0.9 and abs(c[ia] - interior_value) > T * 0.9:
            f.material_index = 1
        else:
            f.material_index = 2
    bmesh.ops.delete(bm, geom=kill, context="FACES")
    bm.to_mesh(ob.data)
    bm.free()


def raw_box(bm, x0, x1, y0, y1, z0, z1):
    ret = bmesh.ops.create_cube(bm, size=1.0)
    vs = ret["verts"]
    for v in vs:
        v.co.x = x0 if v.co.x < 0 else x1
        v.co.y = y0 if v.co.y < 0 else y1
        v.co.z = z0 if v.co.z < 0 else z1


def build_shell():
    mats = dict(cut="wall_cut", ext="wall_exterior", reveal="wall_cream")
    # Arka duvar parçaları (pencere boşluğu)
    bm = bmesh.new()
    wx0, wx1, wz0, wz1 = WIN
    raw_box(bm, -T, wx0, 0, T, -SLAB, H)
    raw_box(bm, wx1, W, 0, T, -SLAB, H)
    raw_box(bm, wx0, wx1, 0, T, -SLAB, wz0)
    raw_box(bm, wx0, wx1, 0, T, wz1, H)
    back = P.obj_from_bm("BackWall", bm)
    classify_wall_faces(back, "y", 0.0, -1, "x", W, mats)
    # Sol duvar parçaları (kapı boşluğu)
    bm = bmesh.new()
    dy0, dy1, dz0, dz1 = DOOR
    raw_box(bm, -T, 0, dy1, 0, -SLAB, H)
    raw_box(bm, -T, 0, -DEP, dy0, -SLAB, H)
    raw_box(bm, -T, 0, dy0, dy1, dz1, H)
    raw_box(bm, -T, 0, dy0, dy1, -SLAB, 0.0)
    left = P.obj_from_bm("LeftWall", bm)
    classify_wall_faces(left, "x", 0.0, 1, "y", -DEP, mats)
    for o in (back, left):
        for p in o.data.polygons:
            p.use_smooth = False
        P.box_uv(o, 1.0, grain="Z")
    keep([back, left])

    # İç yüzler: yoğun ızgara (köşe AO'su için)
    keep(P.wall_grid("BackInK", (0, 0, 0), (1, 0, 0), 3.05, H, 0.1, "wall_cream"))
    keep(P.wall_grid("BackInL", (3.05, 0, 0), (1, 0, 0), W - 3.05, H, 0.1, "wallpaper",
                     holes=[(wx0 - 3.05, wx1 - 3.05, wz0, wz1)]))
    keep(P.wall_grid("LeftIn", (0, -DEP, 0), (0, 1, 0), DEP, H, 0.1, "wall_sage",
                     holes=[(dy0 + DEP, dy1 + DEP, dz0, dz1)]))

    # Döşeme: tahta yüzü (ızgara) + tahta kesit kenarı + beton döşeme
    keep(P.grid_plane("FloorTop", 0, W, -DEP, 0, 0.0, 0.1, "floor_planks"))
    P.box_uv(STATIC[-1], 1.0, grain="Y")
    bm = bmesh.new()
    raw_box(bm, -T, W, -DEP, T, -0.025, 0.0)
    boards = P.obj_from_bm("FloorBoards", bm, "floor_planks")
    bm = bmesh.new()
    bm.from_mesh(boards.data)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.normal.z > 0.5 or f.normal.z < -0.5], context="FACES")
    bm.to_mesh(boards.data)
    bm.free()
    P.box_uv(boards, 1.0, grain="Y")
    keep(boards)
    keep(P.box("Slab", (W + T, DEP + T, SLAB - 0.025), ((W - T) / 2, (-DEP + T) / 2, -0.025 - (SLAB - 0.025) / 2),
               "wall_cut", bev=0.0, uv_scale=1.0))
    # Kesit çizgisi: tahta ile döşeme arasında ince koyu bant
    keep(P.box("SlabLine", (W + T + 0.002, DEP + T + 0.002, 0.006), ((W - T) / 2, (-DEP + T) / 2, -0.028),
               "black_metal", bev=0.0))

    # Süpürgelik (arka ve sol duvar), kapı boşluğunda kesik
    sk_h, sk_t = 0.09, 0.016
    keep(P.box("SkirtB", (W, sk_t, sk_h), (W / 2, -sk_t / 2, sk_h / 2), "paint_white", bev=0.004, grain="X"))
    keep(P.box("SkirtL1", (sk_t, -DOOR[1] - 0.08, sk_h), (sk_t / 2, (DOOR[1] + 0.08) / 2, sk_h / 2), "paint_white",
               bev=0.004, grain="Y"))
    keep(P.box("SkirtL2", (sk_t, DOOR[0] - 0.08 + DEP, sk_h), (sk_t / 2, (-DEP + DOOR[0] - 0.08) / 2, sk_h / 2),
               "paint_white", bev=0.004, grain="Y"))

    # Görünmez gölge kutusu: tavan + sağ duvar + ön duvar
    bm = bmesh.new()
    raw_box(bm, -T - 0.2, W + T + 0.2, -DEP - T - 0.2, T + 0.2, H + 0.002, H + 0.2)
    raw_box(bm, W + 0.002, W + T + 0.2, -DEP - 0.2, T, -SLAB, H)
    raw_box(bm, -T, W + T, -DEP - T - 0.2, -DEP - 0.002, -SLAB, H)
    sb = P.obj_from_bm("ShadowBox_shadowonly", bm, "wall_exterior")
    return sb


# ---------------------------------------------------------------- pencere ve kapı

def build_window():
    x0, x1, z0, z1 = WIN
    fy = T * 0.45  # çerçeve düzlemi
    fw = 0.055
    fd = 0.06
    parts = []
    # Kasa
    parts.append(P.box("WinF_b", (x1 - x0, fd, fw), ((x0 + x1) / 2, fy, z0 + fw / 2), "paint_white", bev=0.006))
    parts.append(P.box("WinF_t", (x1 - x0, fd, fw), ((x0 + x1) / 2, fy, z1 - fw / 2), "paint_white", bev=0.006))
    parts.append(P.box("WinF_l", (fw, fd, z1 - z0), (x0 + fw / 2, fy, (z0 + z1) / 2), "paint_white", bev=0.006))
    parts.append(P.box("WinF_r", (fw, fd, z1 - z0), (x1 - fw / 2, fy, (z0 + z1) / 2), "paint_white", bev=0.006))
    # Kanatlar: orta dikme + üst vasistas kayıtı + kanat çerçeveleri
    xm = (x0 + x1) / 2
    zt = z1 - 0.36
    parts.append(P.box("WinMull", (0.05, fd + 0.01, z1 - z0 - 2 * fw), (xm, fy - 0.004, (z0 + z1) / 2), "paint_white",
                       bev=0.006))
    parts.append(P.box("WinTran", (x1 - x0 - 2 * fw, fd + 0.01, 0.045), ((x0 + x1) / 2, fy - 0.004, zt), "paint_white",
                       bev=0.006))
    # Kanat profilleri (camı tutan çıtalar)
    for (a, b) in ((x0 + fw, xm - 0.025), (xm + 0.025, x1 - fw)):
        for (c, d) in ((z0 + fw, zt - 0.0225), (zt + 0.0225, z1 - fw)):
            w_, h_ = b - a, d - c
            cx, cz = (a + b) / 2, (c + d) / 2
            s = 0.03
            parts.append(P.box("Sash", (w_, 0.04, s), (cx, fy - 0.012, c + s / 2), "paint_white", bev=0.005, seg=2))
            parts.append(P.box("Sash", (w_, 0.04, s), (cx, fy - 0.012, d - s / 2), "paint_white", bev=0.005, seg=2))
            parts.append(P.box("Sash", (s, 0.04, h_ - 2 * s), (a + s / 2, fy - 0.012, cz), "paint_white", bev=0.005, seg=2))
            parts.append(P.box("Sash", (s, 0.04, h_ - 2 * s), (b - s / 2, fy - 0.012, cz), "paint_white", bev=0.005, seg=2))
    # Kol (pirinç)
    parts.append(P.box("WinHandle", (0.012, 0.03, 0.1), (xm - 0.045, fy - 0.045, z0 + 0.6), "brass", bev=0.004))
    keep(parts)
    # İç denizlik + pervaz
    keep(P.box("Sill", (x1 - x0 + 0.16, T * 0.55 + 0.07, 0.035), ((x0 + x1) / 2, -0.07 + (T * 0.55 + 0.07) / 2 - 0.0,
                                                                   z0 - 0.0175), "paint_white", bev=0.008, grain="X"))
    keep(P.box("SillApron", (x1 - x0 + 0.08, 0.018, 0.07), ((x0 + x1) / 2, -0.009, z0 - 0.07), "paint_white",
               bev=0.004, grain="X"))
    ar = 0.07
    keep(P.box("WinArch_t", (x1 - x0 + 2 * ar, 0.016, ar), ((x0 + x1) / 2, -0.008, z1 + ar / 2), "paint_white",
               bev=0.004, grain="X"))
    keep(P.box("WinArch_l", (ar, 0.016, z1 - z0), (x0 - ar / 2, -0.008, (z0 + z1) / 2), "paint_white", bev=0.004))
    keep(P.box("WinArch_r", (ar, 0.016, z1 - z0), (x1 + ar / 2, -0.008, (z0 + z1) / 2), "paint_white", bev=0.004))
    # Cam (ayrı nesne; gölge atmaz)
    bm = bmesh.new()
    for (a, b) in ((x0 + fw, xm - 0.025), (xm + 0.025, x1 - fw)):
        for (c, d) in ((z0 + fw, zt - 0.0225), (zt + 0.0225, z1 - fw)):
            raw_box(bm, a, b, fy - 0.004, fy + 0.0, c, d)
    glass = P.obj_from_bm("WindowGlass_noshadow", bm, "glass_clear")
    P.box_uv(glass, 1.0)
    # Manzara düzlemi
    vx0, vx1, vz0, vz1 = x0 - 0.45, x1 + 0.4, z0 - 0.6, H - 0.3
    vy = T + 0.32
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    vs = [bm.verts.new((vx0, vy, vz0)), bm.verts.new((vx1, vy, vz0)), bm.verts.new((vx1, vy, vz1)),
          bm.verts.new((vx0, vy, vz1))]
    f = bm.faces.new(vs)
    for loop, uv in zip(f.loops, [(0, 1), (1, 1), (1, 0), (0, 0)]):
        loop[uvl].uv = (uv[0], P.gv(uv[1]))  # Godot'da UV.y = 0 üst
    if f.normal.y > 0:
        f.normal_flip()
    view = P.obj_from_bm("WindowView_noshadow", bm, "fx_window_sky")
    # Perde rayı + perdeler
    rod_z = z1 + 0.11
    rod_y = -0.1
    rx0, rx1 = x0 - 0.28, x1 + 0.26
    keep(P.sweep("CurtRod", [Vector((rx0, rod_y, rod_z)), Vector((rx1, rod_y, rod_z))], 0.011, "brass", sides=12))
    for xx in (rx0, rx1):
        keep(D.fruit("RodEnd", (xx, rod_y, rod_z), r=0.022, material="brass", squash=1.0))
    for xx in (rx0 + 0.07, rx1 - 0.07):
        keep(P.box("RodBracket", (0.016, abs(rod_y), 0.016), (xx, rod_y / 2, rod_z), "brass", bev=0.004))
    keep(curtain("CurtL", rx0 + 0.04, x0 + 0.2, rod_y - 0.02, rod_z - 0.02, z0 - 0.05, seed=1))
    keep(curtain("CurtR", x1 - 0.2, rx1 - 0.04, rod_y - 0.02, rod_z - 0.02, z0 - 0.05, seed=2))
    # Halkalar
    for cx in [rx0 + 0.05 + i * 0.06 for i in range(7)] + [rx1 - 0.05 - i * 0.06 for i in range(7)]:
        keep(P.sweep("Ring", [Vector((cx, rod_y + 0.018 * math.cos(a), rod_z + 0.018 * math.sin(a))) for a in
                              [i * math.pi / 6 for i in range(13)]], 0.0025, "brass", sides=5, caps=False))
    return glass, view


def curtain(name, x0, x1, y, ztop, zbot, seed=1, pleats=7):
    """Toplanmış keten perde: kıvrımlar (y yönünde dalga), alta doğru açılan etek."""
    rnd = random.Random(seed)
    nu, nv = 36, 22
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    rows = []
    phase = rnd.uniform(0, 6.28)
    for j in range(nv + 1):
        t = j / nv  # 0 üst, 1 alt
        z = ztop + (zbot - ztop) * t
        row = []
        for i in range(nu + 1):
            s = i / nu
            spread = 1.0 + 0.25 * t * t
            cx = (x0 + x1) / 2
            x = cx + (s - 0.5) * (x1 - x0) * spread
            amp = 0.028 + 0.012 * t
            yy = y + amp * math.sin(s * pleats * 2 * math.pi + phase + t * 0.6) + 0.01 * math.sin(t * 5 + s * 3)
            row.append(bm.verts.new((x, yy, z)))
        rows.append(row)
    for j in range(nv):
        for i in range(nu):
            f = bm.faces.new([rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i]])
            for loop in f.loops:
                co = loop.vert.co
                loop[uvl].uv = (co.x / 0.35, co.z / 0.35)
    ob = P.obj_from_bm(name, bm, "linen_curtain")
    P.smooth(ob, 80, weighted=False)
    # Ön yüz odaya baksın
    if ob.data.polygons[0].normal.y > 0:
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
        bm.to_mesh(ob.data)
        bm.free()
    # Üst büzgü bandı
    band = P.box(name + "_hd", (x1 - x0, 0.03, 0.06), ((x0 + x1) / 2, y, ztop - 0.03), "linen_curtain", bev=0.01)
    return [ob, band]


def build_door():
    y0, y1, z0, z1 = DOOR
    objs = []
    lx = -T * 0.5
    # Kanat (dört tablalı) — yerel ölçülerle
    dw = y1 - y0 - 0.02
    dh = z1 - 0.01
    cy = (y0 + y1) / 2
    objs.append(P.box("DoorLeaf", (0.04, dw, dh), (lx + 0.02, cy, dh / 2 + 0.005), "paint_white", bev=0.006,
                      grain="Z"))
    # Tablalar (iç yüzde hafif kabarık)
    for (pz, ph) in ((0.25, 0.75), (1.1, 0.85)):
        for py in (cy - dw * 0.22, cy + dw * 0.22):
            objs.append(P.box("DoorPanel", (0.012, dw * 0.36, ph), (lx + 0.045, py, pz + ph / 2), "paint_white",
                              bev=0.008, seg=3, grain="Z"))
    # Kol + rozet (pirinç)
    hy = y1 - 0.09
    objs.append(P.cyl("DoorRose", 0.026, 0.01, (lx + 0.04, hy, 1.02), "brass", axis="X", verts=32, bev=0.003))
    objs.append(P.sweep("DoorLever", [Vector((lx + 0.05, hy, 1.02)), Vector((lx + 0.1, hy, 1.02)),
                                      Vector((lx + 0.11, hy - 0.03, 1.02)), Vector((lx + 0.11, hy - 0.12, 1.025))],
                        0.008, "brass", sides=10))
    # Pervaz (iç yüzde)
    ar = 0.075
    objs.append(P.box("DoorArch_t", (0.018, (y1 - y0) + 2 * ar, ar), (0.009, cy, z1 + ar / 2), "paint_white",
                      bev=0.004, grain="Y"))
    objs.append(P.box("DoorArch_a", (0.018, ar, z1), (0.009, y0 - ar / 2, z1 / 2), "paint_white", bev=0.004))
    objs.append(P.box("DoorArch_b", (0.018, ar, z1), (0.009, y1 + ar / 2, z1 / 2), "paint_white", bev=0.004))
    # Paspas
    objs.append(P.box("DoorMat", (0.55, 0.8, 0.012), (0.42, cy, 0.006), "fabric_charcoal", bev=0.004, uv_scale=1.0))
    keep(objs)


# ---------------------------------------------------------------- mutfak

def build_kitchen():
    objs = []
    cz = COUNTER_Z
    depth = 0.58
    # Dolap gövdeleri (yalnız dolap birimleri; fırın/çamaşır yuvası boş)
    units = [(1.98, 2.58), (2.6, 3.0)]
    for i, (a, b) in enumerate(units):
        objs.append(P.box(f"Carcass{i}", (b - a, depth - 0.02, cz - 0.04 - 0.1), ((a + b) / 2, -depth / 2 + 0.01,
                                                                                  0.1 + (cz - 0.14) / 2),
                          "paint_sage", bev=0.002))
    # Yan panel (sona) ve ara dikmeler
    objs.append(P.box("EndPanel", (0.02, depth + 0.02, cz - 0.04), (3.01, -depth / 2 - 0.01, (cz - 0.04) / 2),
                      "paint_sage", bev=0.004, grain="Z"))
    objs.append(P.box("FillerL", (0.02, depth, cz - 0.04), (0.73, -depth / 2, (cz - 0.04) / 2), "paint_sage",
                      bev=0.003, grain="Z"))
    # Kapaklar: çekmece + kapak (birim A), kapak (birim B)
    fy = -depth - 0.01
    doors = [((1.985, 2.575), (0.70, cz - 0.045)), ((1.985, 2.575), (0.105, 0.69)), ((2.605, 2.995), (0.105, cz - 0.045))]
    for i, ((a, b), (z0, z1)) in enumerate(doors):
        objs.append(P.box(f"Front{i}", (b - a, 0.02, z1 - z0), ((a + b) / 2, fy, (z0 + z1) / 2), "paint_sage",
                          bev=0.004, grain="Z"))
        # Çerçeveli (shaker) kapak: iç tabla hafif çukur → dört çıta
        if z1 - z0 > 0.3:
            inset = 0.055
            for (px, pz, sx, sz) in (((a + b) / 2, z0 + inset / 2, b - a - 0.006, inset),
                                     ((a + b) / 2, z1 - inset / 2, b - a - 0.006, inset),
                                     (a + inset / 2, (z0 + z1) / 2, inset, z1 - z0 - 2 * inset),
                                     (b - inset / 2, (z0 + z1) / 2, inset, z1 - z0 - 2 * inset)):
                objs.append(P.box("Rail", (sx, 0.008, sz), (px, fy - 0.013, pz), "paint_sage", bev=0.003))
        # Pirinç çubuk kulp
        hz = z1 - 0.05 if z1 - z0 < 0.3 else (z1 - 0.12)
        hx0, hx1 = (a + b) / 2 - 0.07, (a + b) / 2 + 0.07
        if z1 - z0 > 0.3:
            hx0, hx1 = (a + 0.05, a + 0.05)
            pts = [Vector((hx0, fy - 0.012, hz - 0.11)), Vector((hx0, fy - 0.035, hz - 0.11)),
                   Vector((hx0, fy - 0.035, hz)), Vector((hx0, fy - 0.012, hz))]
            if i == 2:
                pts = [Vector((b - 0.05, p.y, p.z)) for p in pts]
        else:
            pts = [Vector((hx0, fy - 0.012, hz)), Vector((hx0, fy - 0.035, hz)), Vector((hx1, fy - 0.035, hz)),
                   Vector((hx1, fy - 0.012, hz))]
        objs.append(P.sweep(f"Handle{i}", P.fillet_path(pts, 0.012, 4), 0.006, "brass", sides=10))
    # Baza (geri çekik)
    objs.append(P.box("Plinth", (3.0 - 0.72, 0.02, 0.1), ((0.72 + 3.0) / 2, -depth + 0.05, 0.05), "black_metal",
                      bev=0.002, grain="X"))
    # Tezgah (meşe, lavabo boşluklu)
    top = P.box("Counter", (3.03 - 0.71, 0.63, 0.04), ((0.71 + 3.03) / 2, -0.315, cz - 0.02), "wood_oak", bev=0.006,
                grain="X")
    cut = P.box("SinkCut", (0.42, 0.38, 0.2), (2.28, -0.31, cz), "wood_oak", bev=0.0)
    bo = top.modifiers.new("cut", "BOOLEAN")
    bo.operation = "DIFFERENCE"
    bo.object = cut
    P.apply_mods(top)
    bpy.data.objects.remove(cut)
    P.box_uv(top, 1.0, grain="X")
    objs.append(top)
    # Lavabo (paslanmaz): içi görünen hazne
    bm = bmesh.new()
    raw_box(bm, 2.07, 2.49, -0.5, -0.12, cz - 0.17, cz - 0.004)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.normal.z > 0.5], context="FACES")
    bmesh.ops.reverse_faces(bm, faces=bm.faces)
    sink = P.obj_from_bm("Sink", bm, "steel_brushed")
    P.bevel(sink, 0.025, 4, angle=30)
    P.smooth(sink, 40, weighted=False)
    P.box_uv(sink, 1.0)
    objs.append(sink)
    for (px, py, sx, sy) in ((2.28, -0.505, 0.44, 0.02), (2.28, -0.115, 0.44, 0.02), (2.06, -0.31, 0.02, 0.4),
                             (2.5, -0.31, 0.02, 0.4)):
        objs.append(P.box("SinkRim", (sx, sy, 0.006), (px, py, cz + 0.002), "steel_brushed", bev=0.002))
    objs.append(P.cyl("Drain", 0.022, 0.004, (2.28, -0.31, cz - 0.174), "chrome", verts=24, bev=0.001))
    # Batarya (krom kuğu boyun)
    objs.append(P.cyl("TapBase", 0.024, 0.04, (2.28, -0.07, cz), "chrome", verts=24, bev=0.004))
    neck = [Vector((2.28, -0.07, cz + 0.03)), Vector((2.28, -0.07, cz + 0.27)), Vector((2.28, -0.11, cz + 0.33)),
            Vector((2.28, -0.2, cz + 0.32)), Vector((2.28, -0.24, cz + 0.27)), Vector((2.28, -0.245, cz + 0.22))]
    objs.append(P.sweep("TapNeck", P.resample(P.fillet_path(neck, 0.06, 6), 0.02), 0.011, "chrome", sides=10))
    objs.append(P.sweep("TapLever", [Vector((2.3, -0.07, cz + 0.06)), Vector((2.36, -0.07, cz + 0.1))], 0.006,
                        "chrome", sides=8))
    # Ocak (siyah cam) + ocak gözü halkaları
    objs.append(P.box("Hob", (0.56, 0.5, 0.008), (1.04, -0.3, cz + 0.004), "hob_glass", bev=0.003))
    for (hx, hy, r) in ((0.9, -0.18, 0.08), (1.18, -0.18, 0.06), (0.9, -0.43, 0.06), (1.18, -0.43, 0.085)):
        ring = [Vector((hx + r * math.cos(a), hy + r * math.sin(a), cz + 0.0085)) for a in
                [i * math.pi / 20 for i in range(41)]]
        objs.append(P.sweep("HobRing", ring[:-1], 0.0016, "hob_mark", sides=4, closed=True))
    # Davlumbaz
    hood = P.box("HoodCanopy", (0.6, 0.5, 0.12), (1.04, -0.25, 1.62), "steel_brushed", bev=0.004, grain="Z")
    for v in hood.data.vertices:
        if v.co.z > 0:
            v.co.y = v.co.y * 0.45 + 0.13
            v.co.x *= 0.6
    P.box_uv(hood, 1.0)
    objs.append(hood)
    objs.append(P.box("HoodChimney", (0.3, 0.24, H - 1.68), (1.04, -0.12, 1.68 + (H - 1.68) / 2), "steel_brushed",
                      bev=0.004, grain="Z"))
    # Fayans (arka duvar, tezgah üstü)
    objs.append(P.box("Backsplash", (3.02 - 0.72, 0.012, 1.52 - cz), ((0.72 + 3.02) / 2, -0.006, (cz + 1.52) / 2),
                      "tiles_cream", bev=0.002, grain="Z"))
    # Açık raflar (meşe) + pirinç konsollar
    for i, sz in enumerate((1.55, 1.95)):
        objs.append(P.box(f"Shelf{i}", (1.6, 0.26, 0.035), (2.2, -0.13, sz), "wood_oak", bev=0.006, grain="X"))
        for bx in (1.55, 2.85):
            pts = [Vector((bx, -0.005, sz - 0.12)), Vector((bx, -0.005, sz - 0.02)), Vector((bx, -0.2, sz - 0.02))]
            objs.append(P.sweep("Bracket", P.fillet_path(pts, 0.03), 0.006, "brass", sides=8))
    keep(objs)
    # Raf üstleri
    s1 = 1.55 + 0.0175
    s2 = 1.95 + 0.0175
    deco = []
    deco += D.jar("Jar1", (1.5, -0.13, s1), content="food_pasta", fill=0.7)
    deco += D.jar("Jar2", (1.61, -0.13, s1), r=0.04, h=0.12, content="food_lentil", fill=0.55)
    deco += D.jar("Jar3", (1.71, -0.13, s1), r=0.035, h=0.16, content="food_rice", fill=0.8)
    deco += D.plate_stack("Plates", (1.97, -0.13, s1), n=5)
    deco += D.mug("Mug1", (2.25, -0.12, s1), "ceramic_blue", rot=0.4)
    deco += D.mug("Mug2", (2.38, -0.14, s1), "ceramic_mustard", rot=-0.3)
    deco += D.mug("Mug3", (2.5, -0.11, s1), "ceramic_white", rot=1.1)
    deco += D.herb_pot("Herb1", (2.72, -0.13, s1), seed=4)
    deco += D.bottle("Oil", (2.9, -0.12, s1))
    deco += D.bowl("Bowl1", (1.55, -0.13, s2), r=0.09, h=0.05, material="ceramic_green")
    deco += D.bowl("Bowl2", (1.55, -0.13, s2 + 0.03), r=0.075, h=0.045, material="ceramic_white")
    deco += D.pot("PothosPot", (1.85, -0.13, s2), r=0.06, h=0.1, material="ceramic_white")
    deco += D.pothos("Pothos1", (1.85, -0.13, s2 + 0.09), n_leaves=20, spread=0.2, trail=0.45, seed=11)
    deco += D.book_row("CookBooks", (2.18, -0.05, s2), (1, 0, 0), 0.4, 0.18, 0.24, seed=21)
    deco += D.vase("Vase1", (2.78, -0.12, s2), "terracotta", scale=0.9)
    deco += D.vase("Vase2", (2.92, -0.1, s2), "ceramic_blue", scale=0.7, style=1)
    # Tezgah üstü
    deco += [P.box("Board", (0.3, 0.02, 0.4), (2.6, -0.035, cz + 0.2), "wood_walnut", bev=0.008, grain="Z",
                   rot=(math.radians(-8), 0, 0))]
    deco += D.vase("Crock", (1.4, -0.12, cz), "ceramic_white", scale=0.8, style=1)
    for k in range(4):
        a = k * 1.6
        top_p = Vector((1.4 + 0.02 * math.cos(a), -0.12 + 0.02 * math.sin(a), cz + 0.27))
        deco.append(P.sweep(f"Spoon{k}", [Vector((1.4, -0.12, cz + 0.03)), top_p], 0.005, "wood_oak", sides=6))
        deco += D.fruit(f"SpoonHead{k}", top_p + Vector((0, 0, 0.025)), r=0.018, material="wood_oak", squash=1.7,
                        seg=(10, 6))
    deco += D.bowl("FruitBowl", (0.86, -0.12, cz), r=0.1, h=0.06, material="ceramic_blue")
    for k, (dx, dy, m) in enumerate(((0.0, 0.0, "fruit_orange"), (0.05, 0.03, "fruit_lemon"), (-0.04, 0.035, "fruit_orange"),
                                      (0.02, -0.045, "fruit_apple"))):
        deco += D.fruit(f"Fruit{k}", (0.86 + dx, -0.12 + dy, cz + 0.06 + (0.02 if k == 3 else 0)), r=0.032,
                        material=m)
    # Buzdolabı üstü sepet + sarkan sarmaşık
    deco += [P.lathe("Basket", [(0, 0), (0.13, 0), (0.15, 0.13), (0.14, 0.13), (0.12, 0.012), (0, 0.012)],
                     (0.25, -0.3, 1.83), "wicker", verts=40)]
    deco += D.pot("FridgePot", (0.55, -0.25, 1.83), r=0.07, h=0.11, material="ceramic_green")
    deco += D.pothos("Pothos2", (0.55, -0.25, 1.93), n_leaves=24, spread=0.24, trail=0.7, seed=17)
    keep(deco)
    # Raf altı ışık şeridi
    strip = P.box("KitchenStrip_noshadow", (1.5, 0.02, 0.008), (2.2, -0.2, 1.528), "fx_glow_strip", bev=0.002)
    P.empty("LightAnchor_Kitchen", (2.2, -0.18, 1.5))
    hood_light = P.empty("LightAnchor_Hood", (1.04, -0.3, 1.55))
    return strip


# ---------------------------------------------------------------- oturma köşesi

def build_living():
    objs = []
    # Yan sehpa (ceviz, üç ayak)
    st = (3.3, -0.24)
    objs.append(P.cyl("SideTop", 0.2, 0.025, (st[0], st[1], 0.54), "wood_walnut", verts=48, bev=0.008))
    objs.append(P.cyl("SideShelf", 0.15, 0.02, (st[0], st[1], 0.2), "wood_walnut", verts=40, bev=0.006))
    for k in range(3):
        a = k * 2 * math.pi / 3 + 0.4
        p0 = Vector((st[0] + 0.15 * math.cos(a), st[1] + 0.15 * math.sin(a), 0.0))
        p1 = Vector((st[0] + 0.1 * math.cos(a), st[1] + 0.1 * math.sin(a), 0.545))
        objs.append(P.sweep(f"SideLeg{k}", [p0, p1], 0.014, "wood_walnut", sides=10, radius_fn=lambda t: 0.6 + 0.4 * t))
    objs += D.book_stack("SideBooks", (st[0] - 0.02, st[1] - 0.02, 0.22), n=2, seed=31)

    # Kanepe (yüzyıl ortası; ceviz kasa, petrol mavisi döşeme)
    sx0, sx1 = 3.6, 5.05
    sy0, sy1 = -0.04, -0.88
    sw = sx1 - sx0
    sd = sy0 - sy1
    cxs = (sx0 + sx1) / 2
    cys = (sy0 + sy1) / 2
    objs.append(P.box("SofaRail", (sw, sd - 0.02, 0.06), (cxs, cys, 0.2), "wood_walnut", bev=0.01, grain="X"))
    for (lx, ly) in ((sx0 + 0.07, sy1 + 0.07), (sx1 - 0.07, sy1 + 0.07), (sx0 + 0.07, sy0 - 0.07),
                     (sx1 - 0.07, sy0 - 0.07)):
        objs.append(P.cyl("SofaLeg", 0.022, 0.18, (lx, ly, 0.0), "wood_walnut", verts=16, r2=0.016, bev=0.003))
    objs.append(P.box("SofaBase", (sw - 0.04, sd - 0.04, 0.14), (cxs, cys, 0.3), "fabric_teal", bev=0.03, seg=4,
                      uv_scale=1.0))
    # Kolçaklar
    for side, ax in ((-1, sx0 + 0.075), (1, sx1 - 0.075)):
        objs += D.seat_cushion(f"SofaArm{side}", (ax, cys, 0.47), (0.15, sd, 0.3), "fabric_teal", bulge=0.01)
    # Sırt
    objs += D.seat_cushion("SofaBack", (cxs, sy0 - 0.09, 0.52), (sw - 0.02, 0.16, 0.42), "fabric_teal", bulge=0.0)
    # Oturma ve sırt minderleri
    inner = sw - 0.3
    for k in range(2):
        cx = sx0 + 0.15 + inner * (k + 0.5) / 2
        objs += D.seat_cushion(f"Seat{k}", (cx, cys - 0.07, 0.43), (inner / 2 - 0.01, sd - 0.22, 0.13), "fabric_teal",
                               bulge=0.018)
        objs += D.cushion(f"BackCush{k}", (cx, sy0 - 0.23, 0.66), (inner / 2 - 0.02, 0.14, 0.38), "fabric_teal",
                          rot=(math.radians(-12), 0, 0), puff=0.25)
    # Kırlentler + battaniye
    objs += D.cushion("Pillow1", (sx0 + 0.3, sy0 - 0.33, 0.66), (0.4, 0.13, 0.38), "fabric_mustard",
                      rot=(math.radians(-18), 0, math.radians(14)), puff=0.5)
    objs += D.cushion("Pillow2", (sx1 - 0.3, sy0 - 0.33, 0.64), (0.38, 0.12, 0.36), "fabric_terracotta",
                      rot=(math.radians(-16), 0, math.radians(-10)), puff=0.5)
    objs += D.cushion("Pillow3", (sx1 - 0.52, sy0 - 0.36, 0.6), (0.32, 0.11, 0.3), "fabric_oat",
                      rot=(math.radians(-20), 0, math.radians(8)), puff=0.5)
    throw = throw_blanket("Throw", sx1 - 0.08, cys, 0.62)
    objs += throw

    # Halı + orta sehpa
    rx, ry, rw, rd = 4.2, -1.85, 2.3, 1.55
    objs.append(rug("Rug", rx, ry, rw, rd))
    ct = (4.3, -1.75)
    top = P.cyl("CoffeeTop", 0.5, 0.032, (ct[0], ct[1], 0.4), "wood_oak", verts=64, bev=0.01)
    top.scale = (1.0, 0.58, 1.0)
    bpy.context.view_layer.update()
    P.apply_transform(top)
    P.box_uv(top, 1.0, grain="X")
    objs.append(top)
    objs.append(P.cyl("CoffeeApron", 0.44, 0.06, (ct[0], ct[1], 0.34), "wood_oak", verts=64, bev=0.006))
    objs[-1].scale = (1.0, 0.52, 1.0)
    bpy.context.view_layer.update()
    P.apply_transform(objs[-1])
    P.box_uv(objs[-1], 1.0, grain="X")
    for (dx, dy) in ((-0.34, -0.16), (0.34, -0.16), (-0.34, 0.16), (0.34, 0.16)):
        p0 = Vector((ct[0] + dx * 1.12, ct[1] + dy * 1.25, 0.0))
        p1 = Vector((ct[0] + dx, ct[1] + dy, 0.36))
        objs.append(P.sweep("CoffeeLeg", [p0, p1], 0.02, "wood_walnut", sides=10, radius_fn=lambda t: 0.6 + 0.4 * t))
    tz = 0.432
    objs += D.book_stack("CoffeeBooks", (ct[0] - 0.22, ct[1] + 0.05, tz), n=3, seed=41, rot=0.3)
    objs += D.vase("CoffeeVase", (ct[0] + 0.2, ct[1] + 0.06, tz), "ceramic_white", scale=1.0)
    objs += D.dried_stems("Stems", (ct[0] + 0.2, ct[1] + 0.06, tz + 0.2), seed=8)
    objs += D.candle("Candle", (ct[0] + 0.02, ct[1] - 0.12, tz + 0.012))
    objs += D.mug("CoffeeMug", (ct[0] - 0.1, ct[1] - 0.14, tz), "ceramic_mustard", rot=2.3)

    # Puf (deri)
    objs.append(P.lathe("Pouf", [(0, 0), (0.24, 0), (0.27, 0.05), (0.275, 0.2), (0.25, 0.36), (0.2, 0.385), (0, 0.39)],
                        (3.45, -2.35, 0.0), "leather_tan", verts=28, sub=1))
    P.box_uv(objs[-1], 1.0)
    # Puf biyesi (dikiş şeridi) ve düğmeli üst
    for (rz, rr) in ((0.335, 0.262), (0.06, 0.272)):
        objs.append(P.sweep("PoufPiping", [Vector((3.45 + rr * math.cos(a), -2.35 + rr * math.sin(a), rz)) for a in
                                           [i * math.pi / 20 for i in range(40)]], 0.009, "leather_tan", sides=6,
                            closed=True))
    objs += D.fruit("PoufButton", (3.45, -2.35, 0.385), r=0.018, material="leather_tan", squash=0.5, seg=(10, 6))

    # TV ünitesi (sol duvar; ceviz, çıtalı kapaklar)
    y0, y1 = -2.4, -1.32
    cx = 0.21
    cyc = (y0 + y1) / 2
    objs.append(P.box("ConsoleBody", (0.42, y1 - y0, 0.36), (cx, cyc, 0.12 + 0.18), "wood_walnut", bev=0.01,
                      grain="Y"))
    objs.append(P.box("ConsoleTop", (0.44, y1 - y0 + 0.02, 0.025), (cx, cyc, 0.4875), "wood_walnut", bev=0.008,
                      grain="Y"))
    for (ly) in (y0 + 0.08, y1 - 0.08):
        for lx in (0.06, 0.36):
            objs.append(P.cyl("ConsoleLeg", 0.018, 0.13, (lx, ly, 0.0), "wood_walnut", verts=12, r2=0.013, bev=0.002))
    # Çıtalı kapaklar (iki yanda), ortada açık bölme
    fx = 0.42 + 0.004
    for (a, b) in ((y0 + 0.02, y0 + 0.44), (y1 - 0.44, y1 - 0.02)):
        n = 15
        for k in range(n):
            yy = a + (b - a) * (k + 0.5) / n
            objs.append(P.box("Slat", (0.014, (b - a) / n * 0.62, 0.3), (fx + 0.007, yy, 0.3), "wood_walnut", bev=0.003,
                              seg=1, grain="Z"))
        objs.append(P.cyl("ConsoleKnob", 0.012, 0.02, (fx + 0.014, (a + b) / 2 + (0.15 if a < cyc else -0.15), 0.3),
                          "brass", axis="X", verts=16, bev=0.003))
    objs.append(P.box("ConsoleNiche", (0.006, 0.4, 0.28), (0.425, cyc, 0.3), "wood_walnut", bev=0.0))
    objs += D.book_stack("NicheBooks", (0.22, cyc - 0.05, 0.16), n=3, seed=51, rot=1.57)
    objs += D.pot("ConsolePot", (0.21, y1 - 0.13, 0.5), r=0.075, h=0.13, material="ceramic_mustard")
    objs += D.pothos("Pothos3", (0.21, y1 - 0.13, 0.62), n_leaves=18, spread=0.22, trail=0.35, seed=23)
    objs += D.vase("ConsoleVase", (0.2, y0 + 0.12, 0.5), "ceramic_green", scale=1.15)
    objs += D.candle("ConsoleCandle", (0.24, y0 + 0.24, 0.512), r=0.025, h=0.11)
    # Tablolar (TV üstü)
    objs += D.frame("Art1", (0.0, -1.86, 1.5), 0.52, 0.4, 0, (1, 0, 0), frame_mat="wood_oak")
    objs += D.frame("Art2", (0.0, -1.47, 1.62), 0.22, 0.3, 2, (1, 0, 0), frame_mat="black_metal", border=0.015)
    objs += D.frame("Art3", (0.0, -2.26, 1.48), 0.24, 0.32, 1, (1, 0, 0), frame_mat="wood_walnut")

    # Yüzer raflar (sol duvar, buzdolabının yanında)
    for i, sz in enumerate((1.28, 1.68)):
        objs.append(P.box(f"FShelf{i}", (0.24, 0.52, 0.035), (0.12, -0.97, sz), "wood_oak", bev=0.006, grain="Y"))
    objs += D.book_row("ShelfBooks", (0.11, -0.74, 1.6975), (0, -1, 0), 0.36, 0.17, 0.25, seed=61,
                       spine_dir=(1, 0, 0))
    objs += D.vase("ShelfVase", (0.12, -1.15, 1.6975), "terracotta", scale=0.7, style=1)
    objs += D.frame("Art4", (0.0, -0.85, 1.42), 0.16, 0.2, 3, (1, 0, 0), frame_mat="brass", border=0.012,
                    mat_border=0.02)
    objs += D.pot("ShelfPot", (0.12, -1.08, 1.2975), r=0.055, h=0.09, material="ceramic_white")
    objs += D.pothos("Pothos4", (0.12, -1.08, 1.38), n_leaves=14, spread=0.16, trail=0.5, seed=29)
    objs += D.candle("ShelfCandle", (0.12, -0.78, 1.31), r=0.022, h=0.07)

    # Lambri (sol duvar alt kısmı): boyalı dikey tahtalar + üst pervaz; kapı ve konsol arkası dahil
    objs += wainscot()
    # Çamaşır sepeti (hasır, içinde katlı havlular)
    objs.append(P.lathe("LaundryBasket", [(0, 0), (0.19, 0), (0.21, 0.02), (0.23, 0.36), (0.235, 0.38), (0.225, 0.385),
                                          (0.215, 0.36), (0.195, 0.025), (0.0, 0.025)], (2.6, -1.05, 0.0), "wicker",
                        verts=40))
    for k, (m, h) in enumerate((("fabric_oat", 0.3), ("fabric_terracotta", 0.34), ("fabric_teal", 0.37))):
        objs += D.cushion(f"Towel{k}", (2.6 + 0.03 * (k - 1), -1.05 + 0.02 * k, h), (0.3, 0.2, 0.06), m,
                          rot=(0.1 * k, 0.15 - 0.1 * k, 0.4 * k), puff=0.3)
    # Büyük bitki (ön orta)
    objs += D.pot("FigPot", (2.95, -3.6, 0.0), r=0.17, h=0.32, material="terracotta")
    objs += D.fiddle_leaf("Fig", (2.95, -3.6, 0.27), height=1.05)
    objs += dining_set()
    # Paşa kılıcı (kanepe yanı)
    objs += D.pot("SnakePot", (5.12, -1.12, 0.0), r=0.12, h=0.24, material="ceramic_white")
    objs += D.snake_plant("Snake", (5.12, -1.12, 0.2), height=0.7)
    keep(objs)


def wainscot():
    """Sol duvara boyalı lambri: 9 cm'lik dikey tahtalar, aralarında oluk; üstte profilli pervaz."""
    objs = []
    top = 0.95
    y_ranges = [(-0.68, DOOR[1] - 0.08)]
    for (ya, yb) in y_ranges:
        n = int((ya - yb) / 0.09)
        for k in range(n):
            y0 = ya - k * (ya - yb) / n
            y1 = ya - (k + 1) * (ya - yb) / n
            objs.append(P.box("Bead", (0.012, abs(y1 - y0) - 0.004, top - 0.09), (0.006, (y0 + y1) / 2, 0.09 + (top - 0.09) / 2),
                              "paint_white", bev=0.003, seg=2, grain="Z"))
        objs.append(P.box("ChairRail", (0.03, abs(ya - yb), 0.04), (0.015, (ya + yb) / 2, top + 0.01), "paint_white",
                          bev=0.008, seg=3, grain="Y"))
        objs.append(P.box("ChairRail2", (0.018, abs(ya - yb), 0.012), (0.012, (ya + yb) / 2, top - 0.016), "paint_white",
                          bev=0.004, seg=2, grain="Y"))
    return objs


def chair(name, x, y, rot):
    """Yüzyıl ortası sandalye: ceviz iskelet, hasır oturak, kavisli sırt."""
    objs = []
    loc = Vector((x, y, 0))
    R = Matrix.Rotation(rot, 3, "Z")

    def w(p):
        return loc + R @ Vector(p)

    for (lx, ly) in ((-0.19, -0.19), (0.19, -0.19), (-0.17, 0.19), (0.17, 0.19)):
        objs.append(P.sweep(f"{name}_leg", [w((lx * 1.1, ly * 1.1, 0.0)), w((lx, ly, 0.44))], 0.014, "wood_walnut",
                            sides=8, radius_fn=lambda t: 0.7 + 0.3 * t))
    seat = P.box(f"{name}_seat", (0.42, 0.42, 0.045), (0, 0, 0), "wicker", bev=0.012, seg=3)
    seat.location = w((0, 0, 0.46))
    seat.rotation_euler = (0, 0, rot)
    objs.append(seat)
    frame_ = P.box(f"{name}_sframe", (0.44, 0.44, 0.03), (0, 0, 0), "wood_walnut", bev=0.008, seg=2)
    frame_.location = w((0, 0, 0.43))
    frame_.rotation_euler = (0, 0, rot)
    objs.append(frame_)
    for sx in (-0.17, 0.17):
        objs.append(P.sweep(f"{name}_post", [w((sx, 0.19, 0.44)), w((sx * 1.05, 0.23, 0.82))], 0.012, "wood_walnut",
                            sides=8))
    arc = [w((0.2 * math.sin(a), 0.23 + 0.05 * (1 - math.cos(a)), 0.79)) for a in [(-1 + i / 6) * 0.95 for i in range(13)]]
    back = P.sweep(f"{name}_back", arc, 0.035, "wood_walnut", sides=10)
    back.scale = (1.0, 1.0, 1.0)
    objs.append(back)
    return objs


def dining_set():
    objs = []
    tx, ty = 1.75, -3.05
    objs.append(P.cyl("DineTop", 0.43, 0.03, (tx, ty, 0.72), "wood_oak", verts=64, bev=0.01))
    objs.append(P.cyl("DinePed", 0.05, 0.66, (tx, ty, 0.06), "wood_walnut", verts=24, bev=0.006, r2=0.035))
    objs.append(P.lathe("DineFoot", [(0, 0), (0.26, 0), (0.27, 0.015), (0.18, 0.05), (0.06, 0.07), (0, 0.07)],
                        (tx, ty, 0.0), "wood_walnut", verts=48))
    objs += chair("ChairA", tx - 0.58, ty + 0.05, math.radians(-90))
    objs += chair("ChairB", tx + 0.5, ty - 0.35, math.radians(125))
    tz = 0.75
    objs += D.bowl("DineBowl", (tx + 0.05, ty + 0.08, tz), r=0.12, h=0.07, material="ceramic_white")
    for k, (dx, dy, m) in enumerate(((0.0, 0.0, "fruit_apple"), (0.05, 0.03, "fruit_lemon"), (-0.04, 0.03, "fruit_apple"),
                                      (0.03, -0.045, "fruit_orange"))):
        objs += D.fruit(f"DFruit{k}", (tx + 0.05 + dx, ty + 0.08 + dy, tz + 0.06), r=0.034, material=m)
    objs += D.mug("DineMug", (tx - 0.2, ty - 0.15, tz), "ceramic_blue", rot=0.8)
    objs += D.candle("DineCandle", (tx + 0.18, ty - 0.18, tz + 0.012), r=0.025, h=0.13)
    objs.append(P.box("Napkin", (0.22, 0.22, 0.004), (tx - 0.17, ty + 0.17, tz + 0.002), "linen_curtain", bev=0.001,
                      rot=(0, 0, 0.5)))
    return objs


def throw_blanket(name, x, y, z):
    """Kolçak üstüne atılmış örgü battaniye: kıvrımlı dikdörtgen."""
    nu, nv = 12, 18
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    rows = []
    for j in range(nv + 1):
        t = j / nv
        row = []
        for i in range(nu + 1):
            s = i / nu
            # Kolçağın üstünden dışa ve aşağı sarkar
            ang = t * math.pi * 0.95
            r = 0.09
            px = x + r * math.sin(ang) * 1.2 - 0.03
            pz = z + r * math.cos(ang) - (max(0, t - 0.6) * 0.5)
            py = y + (s - 0.5) * 0.5 + 0.015 * math.sin(s * 12 + t * 4)
            px += 0.012 * math.sin(s * 9 + t * 7)
            row.append(bm.verts.new((px, py, pz)))
        rows.append(row)
    for j in range(nv):
        for i in range(nu):
            f = bm.faces.new([rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i]])
            for loop in f.loops:
                co = loop.vert.co
                loop[uvl].uv = (co.y * 3, co.z * 3 + co.x * 3)
    ob = P.obj_from_bm(name, bm, "fabric_oat")
    sol = ob.modifiers.new("s", "SOLIDIFY")
    sol.thickness = 0.012
    P.apply_mods(ob)
    P.smooth(ob, 80, weighted=False)
    return [ob]


def rug(name, cx, cy, w, d):
    bm = bmesh.new()
    raw_box(bm, cx - w / 2, cx + w / 2, cy - d / 2, cy + d / 2, 0.0, 0.009)
    ob = P.obj_from_bm(name, bm, "rug_kilim")
    P.bevel(ob, 0.004, 2)
    P.smooth(ob, 40, weighted=False)
    me = ob.data
    uvl = me.uv_layers.new(name="UVMap")
    for p in me.polygons:
        for li in p.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            # Desenin uzun ekseni (v) halının x eksenine
            uvl.data[li].uv = ((co.y - (cy - d / 2)) / d, (co.x - (cx - w / 2)) / w)
    return ob


# ---------------------------------------------------------------- prizler ve hatlar

def wall_point(wall, along, z, out=0.0):
    if wall == "B":
        return Vector((along, -out, z)), Vector((0, -1, 0))
    return Vector((out, along, z)), Vector((1, 0, 0))


def shape_marker(name, shape, size, material):
    if shape == "circle":
        return P.cyl(name, size * 0.5, 0.004, (0, 0, 0), material, verts=24, axis="Y", bev=0.001)
    if shape == "triangle":
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, segments=3, radius1=size * 0.62, radius2=size * 0.62, depth=0.004)
        bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(180), 3, "Z"), verts=bm.verts)
        bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(-90), 3, "X"), verts=bm.verts)
        ob = P.obj_from_bm(name, bm, material)
        P.bevel(ob, 0.0008, 1)
        P.smooth(ob, 30)
        return ob
    return P.box(name, (size * 0.86, 0.004, size * 0.86), (0, 0, 0), material, bev=0.001, seg=1)


def build_socket(name, wall, along, z, line):
    """Schuko priz (beyaz plastik, çukur yuvalı) + hat şekil işareti.
    Döndürür: (plaka nesnesi → Decor'a katılır, işaret nesnesi → SocketMarkers'a katılır).
    Priz yeri ayrıca boş düğüm `Socket_0N` olarak yazılır (yerel -Y Blender = Godot +Z duvardan dışarı)."""
    parts = []
    plate = P.box(name + "_plate", (0.084, 0.016, 0.084), (0, -0.008, 0), "plastic_white", bev=0.0, uv_scale=0)
    cutter = P.cyl(name + "_cut", 0.0245, 0.03, (0, -0.035, 0), "plastic_white", verts=24, axis="Y", bev=0.0)
    bo = plate.modifiers.new("cut", "BOOLEAN")
    bo.operation = "DIFFERENCE"
    bo.object = cutter
    P.apply_mods(plate)
    bpy.data.objects.remove(cutter)
    P.bevel(plate, 0.006, 2, angle=40)
    P.smooth(plate, 35)
    P.box_uv(plate, 0.15)
    parts.append(plate)
    parts.append(P.cyl(name + "_floor", 0.0246, 0.003, (0, -0.0065, 0), "plastic_white", verts=24, axis="Y", bev=0.0))
    for dx in (-0.0095, 0.0095):
        parts.append(P.cyl(name + "_hole", 0.0028, 0.0012, (dx, -0.0072, 0), "rubber_black", verts=12, axis="Y",
                           bev=0.0))
    for dz in (-0.0215, 0.0215):
        parts.append(P.box(name + "_earth", (0.009, 0.007, 0.004), (0, -0.011, dz), "chrome", bev=0.001, seg=1))
    mk = shape_marker(name + "_mk", LINES[line]["shape"], 0.014, "fx_socket_marker")
    mk.location = (0, -0.0165, 0.0335)
    body = P.join(parts, name + "_body")
    pos, n = wall_point(wall, along, z)
    rot = 0.0 if wall == "B" else math.radians(90)
    for ob in (body, mk):
        # Okunurluk için minyatür abartısı: priz %30 büyük
        ob.location = Vector(ob.location) * SOCKET_SCALE
        ob.scale = (SOCKET_SCALE, SOCKET_SCALE, SOCKET_SCALE)
        bpy.context.view_layer.update()
        P.apply_transform(ob)
        ob.location = (0, 0, 0)
        P.set_origin(ob, (0, 0, 0))
        ob.rotation_euler = (0, 0, rot)
        ob.location = pos
        bpy.context.view_layer.update()
        P.apply_transform(ob)
    P.empty(name, pos, (0, 0, rot))
    idx = int(name[-2:]) - 1
    P.id_colors(mk, lambda p_: ((idx + 0.5) / 8.0, (line - 1 + 0.5) / 4.0, 0.0))
    return body, mk


def build_lines():
    """Hat kabloları: sigorta kutusundan tavan rayına, oradan prizlere iner."""
    fz_top = FUSE_Z + FUSE_H / 2
    fz_bot = FUSE_Z - FUSE_H / 2
    sock = {s[0]: s for s in SOCKETS}
    riser_y = {1: FUSE_Y - 0.1, 2: FUSE_Y, 3: FUSE_Y + 0.1}
    paths = {1: [], 2: [], 3: []}
    junctions = []

    def socket_top(sname, s):
        _, wall, along, z, _ = sock[sname]
        top = 0.042 * SOCKET_SCALE
        p, _ = wall_point(wall, along, z + top, s)
        p2, _ = wall_point(wall, along, z + top, 0.008)
        return p, p2

    for ln, spec in LINES.items():
        s, h = spec["s"], spec["h"]
        ry = riser_y[ln]
        rail = [Vector((s, ry, fz_top - 0.01)), Vector((s, ry, h)), Vector((s, -s, h))]
        paths[ln].append(("main", rail))
    # L1: arka duvarda S01 (dal), S02 (son)
    s, h = LINES[1]["s"], LINES[1]["h"]
    a, b = socket_top("Socket_02", s)
    paths[1][0] = ("main", paths[1][0][1] + [Vector((2.88, -s, h)), a + Vector((0, 0, 0.05)), a, b])
    a, b = socket_top("Socket_01", s)
    paths[1].append(("br", [Vector((1.62, -s, h)), a + Vector((0, 0, 0.05)), a, b]))
    junctions.append((Vector((1.62, -s, h)), "B"))
    # L2: arka duvar S07 (son), S03 (dal), alt çıkış S06
    s, h = LINES[2]["s"], LINES[2]["h"]
    a, b = socket_top("Socket_07", s)
    paths[2][0] = ("main", paths[2][0][1] + [Vector((5.28, -s, h)), a + Vector((0, 0, 0.05)), a, b])
    a, b = socket_top("Socket_03", s)
    paths[2].append(("br", [Vector((0.37, -s, h)), a + Vector((0, 0, 0.05)), a, b]))
    junctions.append((Vector((0.37, -s, h)), "B"))
    a, b = socket_top("Socket_06", s)
    paths[2].append(("down", [Vector((s, FUSE_Y, fz_bot + 0.01)), Vector((s, FUSE_Y, 0.62)), Vector((s, -3.15, 0.55)),
                              a + Vector((0, 0, 0.05)), a, b]))
    # L3: arka duvar S04 (son), sol duvar S05 (dal)
    s, h = LINES[3]["s"], LINES[3]["h"]
    a, b = socket_top("Socket_04", s)
    paths[3][0] = ("main", paths[3][0][1] + [Vector((3.3, -s, h)), a + Vector((0, 0, 0.05)), a, b])
    a, b = socket_top("Socket_05", s)
    paths[3].append(("br", [Vector((s, -1.3, h)), a + Vector((0, 0, 0.05)), a, b]))
    junctions.append((Vector((s, -1.3, h)), "L"))

    cables = []
    clips = []
    for ln, plist in paths.items():
        for kind, pts in plist:
            path = P.resample(P.fillet_path(pts, 0.05, 8), 0.12)
            ob = P.sweep(f"Cable_L{ln}_{kind}", path, 0.0068, "fx_cables", sides=8, uv_len=1.0)
            P.id_colors(ob, lambda p_, ln=ln: (0.0, (ln - 1 + 0.5) / 4.0, 0.0))
            cables.append(ob)
            clips += cable_clips(path, LINES[ln]["s"])
    cables = [P.join(cables, "Cables_noshadow")]
    for p, wall in junctions:
        n = Vector((0, -1, 0)) if wall == "B" else Vector((1, 0, 0))
        jb = P.box("JBox", (0.05, 0.045, 0.05), (0, 0, 0), "plastic_white", bev=0.008, seg=3)
        jb.location = Vector((p.x if wall == "B" else 0.0225, p.y if wall == "L" else -0.0225, p.z))
        if wall == "L":
            jb.rotation_euler = (0, 0, math.radians(90))
        clips.append(jb)
    keep(clips)
    return cables


def cable_clips(path, standoff, every=0.55):
    clips = []
    acc = 0.0
    for i in range(1, len(path) - 1):
        seg = (path[i] - path[i - 1]).length
        acc += seg
        if acc < every:
            continue
        acc = 0.0
        p = path[i]
        t = (path[i + 1] - path[i - 1]).normalized()
        if abs(p.x - standoff) < 0.004 and p.y < -0.05:
            n = Vector((1, 0, 0))
        elif abs(p.y + standoff) < 0.004:
            n = Vector((0, -1, 0))
        else:
            continue
        side = t.cross(n).normalized()
        depth = standoff + 0.006
        c = p - n * (standoff - depth / 2)
        m = Matrix((t, n, side)).transposed()
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        bmesh.ops.scale(bm, vec=(0.014, depth + 0.004, 0.022), verts=bm.verts)
        bmesh.ops.transform(bm, matrix=m.to_4x4(), verts=bm.verts)
        bmesh.ops.translate(bm, vec=c, verts=bm.verts)
        ob = P.obj_from_bm("Clip", bm, "plastic_white")
        P.bevel(ob, 0.0025, 1)
        P.smooth(ob, 40, weighted=False)
        clips.append(ob)
    return clips


# ---------------------------------------------------------------- ana akış

def main():
    P.reset()
    shadow_box = build_shell()
    build_door()
    glass, view = build_window()
    strip = build_kitchen()
    build_living()
    cables = build_lines()
    built = [build_socket(n, w, a, z, ln) for (n, w, a, z, ln) in SOCKETS]
    keep([b for b, _ in built])
    markers = P.join([m for _, m in built], "SocketMarkers")
    sockets = [markers]
    for name, (loc, rz) in ANCHORS.items():
        P.empty(name, loc, (0, 0, rz))
    print("statik nesne:", len(STATIC))
    if BAKE:
        proxies = [P.box("Proxy", s, c, "wall_exterior", bev=0.0, uv_scale=0) for c, s in PROXIES]
        P.bake_vertex_ao(STATIC, samples=128, distance=0.5, strength=0.9, gamma=1.2)
        for o in proxies:
            bpy.data.objects.remove(o)
    P.ensure_white_vcol(STATIC + [glass, view, strip, shadow_box])
    P.collapse_materials(STATIC + [shadow_box])
    if "--report" in ARGS:
        import re
        groups = {}
        for o in STATIC:
            key = re.sub(r"[_.\d]+.*$", "", o.name)
            groups[key] = groups.get(key, 0) + P.tri_count([o])
        for k, v in sorted(groups.items(), key=lambda kv: -kv[1])[:30]:
            print(f"  {k:24s} {v}")
    decor = P.join(STATIC, "Decor")
    tris = P.tri_count([decor])
    print(f"Decor üçgen: {tris}")
    print(f"Toplam üçgen (oda dosyası): {P.tri_count()}")
    out = os.path.join(P.MODELS, "room", "room_studio.glb")
    P.export_glb(out)


main()
