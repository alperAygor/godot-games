"""Priz — dekor üreticileri (bitki, kitap, çerçeve, seramik, minder ...).

Her fonksiyon Blender nesneleri döndürür (liste). Konumlar Blender dünya koordinatıdır.
"""

import math
import random

import bmesh
import bpy
from mathutils import Matrix, Vector

import priz_bl as P


# ---------------------------------------------------------------- çoklu malzeme

def multi_mat(obj, names):
    obj.data.materials.clear()
    for n in names:
        obj.data.materials.append(P.mat(n))


# ---------------------------------------------------------------- seramik / kap

def pot(name, loc, r=0.09, h=0.16, material="terracotta", soil=True, rim=True):
    prof = [(0.0, 0.0), (r * 0.72, 0.0), (r * 0.76, 0.006), (r * 0.98, h * 0.9)]
    if rim:
        prof += [(r * 1.06, h * 0.9), (r * 1.08, h), (r * 0.93, h), (r * 0.9, h * 0.94)]
    else:
        prof += [(r, h), (r * 0.9, h)]
    prof += [(r * 0.86, h * 0.85)]
    objs = [P.lathe(name, prof, loc, material, verts=40, close_top=False, angle=50)]
    if soil:
        s = P.cyl(name + "_soil", r * 0.88, 0.01, (loc[0], loc[1], loc[2] + h * 0.83), "soil", verts=32, bev=0.0)
        objs.append(s)
    return objs


def mug(name, loc, material="ceramic_white", rot=0.0, r=0.04, h=0.09):
    prof = [(0.0, 0.0), (r * 0.85, 0.0), (r * 0.95, 0.004), (r, h * 0.3), (r, h), (r * 0.9, h), (r * 0.88, h * 0.4),
            (r * 0.0, h * 0.12)]
    body = P.lathe(name, prof, loc, material, verts=24)
    pts = []
    for i in range(13):
        a = -math.pi / 2 + math.pi * i / 12
        pts.append(Vector((r + 0.022 * math.cos(a) + 0.002, 0, h * 0.55 + 0.026 * math.sin(a))))
    handle = P.sweep(name + "_h", [Vector(loc) + p for p in pts], 0.0055, material, sides=8)
    for o in (body, handle):
        o.rotation_euler = (0, 0, rot)
        P.set_origin(o, loc)
        o.location = loc
    return [body, handle]


def vase(name, loc, material="ceramic_blue", scale=1.0, style=0):
    s = scale
    if style == 0:
        prof = [(0, 0), (0.035 * s, 0), (0.06 * s, 0.05 * s), (0.065 * s, 0.1 * s), (0.04 * s, 0.17 * s),
                (0.022 * s, 0.21 * s), (0.026 * s, 0.24 * s), (0.02 * s, 0.24 * s), (0.016 * s, 0.2 * s)]
    else:
        prof = [(0, 0), (0.04 * s, 0), (0.05 * s, 0.03 * s), (0.05 * s, 0.13 * s), (0.045 * s, 0.14 * s),
                (0.04 * s, 0.14 * s), (0.038 * s, 0.08 * s)]
    return [P.lathe(name, prof, loc, material, verts=40, close_top=False)]


def bowl(name, loc, r=0.1, h=0.06, material="ceramic_white"):
    prof = [(0, 0), (r * 0.45, 0), (r * 0.5, 0.004), (r * 0.85, h * 0.5), (r, h), (r * 0.94, h), (r * 0.8, h * 0.5),
            (r * 0.4, h * 0.1), (0, h * 0.08)]
    return [P.lathe(name, prof, loc, material, verts=40)]


def plate_stack(name, loc, n=4, r=0.11, material="ceramic_white"):
    objs = []
    for i in range(n):
        z = loc[2] + i * 0.012
        prof = [(0, 0), (r * 0.6, 0.0), (r * 0.95, 0.01), (r, 0.014), (r * 0.96, 0.014), (r * 0.55, 0.007), (0, 0.007)]
        objs.append(P.lathe(f"{name}_{i}", prof, (loc[0], loc[1], z), material, verts=24))
    return objs


def jar(name, loc, r=0.045, h=0.14, content="paper", lid="wood_oak", fill=0.6):
    objs = []
    prof = [(0, 0), (r, 0), (r, h), (r * 0.92, h), (r * 0.92, 0.004), (0, 0.004)]
    objs.append(P.lathe(name, prof, loc, "glass_clear", verts=20))
    objs.append(P.cyl(name + "_in", r * 0.9, h * fill, (loc[0], loc[1], loc[2] + 0.005), content, verts=16, bev=0.0))
    objs.append(P.cyl(name + "_lid", r * 1.02, 0.025, (loc[0], loc[1], loc[2] + h), lid, verts=20, bev=0.004, seg=1))
    return objs


def bottle(name, loc, material="glass_amber", h=0.26, r=0.035):
    prof = [(0, 0), (r, 0), (r, h * 0.62), (r * 0.4, h * 0.82), (r * 0.32, h * 0.96), (r * 0.36, h), (0, h)]
    objs = [P.lathe(name, prof, loc, material, verts=28)]
    objs.append(P.cyl(name + "_cork", r * 0.33, 0.025, (loc[0], loc[1], loc[2] + h - 0.004), "wood_oak", verts=16,
                      bev=0.002))
    return objs


def candle(name, loc, r=0.03, h=0.08):
    return [P.cyl(name, r, h, loc, "candle", verts=28, bev=0.004),
            P.cyl(name + "_holder", r * 1.25, 0.012, (loc[0], loc[1], loc[2] - 0.004), "brass", verts=28, bev=0.003)]


def fruit(name, loc, r=0.035, material="fruit_orange", squash=0.95, seg=(14, 9)):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg[0], v_segments=seg[1], radius=r)
    bmesh.ops.scale(bm, vec=(1, 1, squash), verts=bm.verts)
    ob = P.obj_from_bm(name, bm, material)
    ob.location = loc
    P.smooth(ob, 80, weighted=False)
    P.box_uv(ob, 0.2)
    return [ob]


# ---------------------------------------------------------------- bitkiler

def leaf_mesh(name, length=0.12, width=0.07, heart=0.25, fold=0.35, droop=0.25, nu=6, nv=2, material="leaf"):
    """Kalp/elips biçimli yaprak; yerel +X boyunca uzanır (sap 0'da). Orta damar boyunca katlanır."""
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    rows = []
    for i in range(nu + 1):
        t = i / nu
        w = math.sin(math.pi * min(t * 1.05, 1.0)) ** 0.75 * (1.0 + heart * (1.0 - t) ** 2) * width * 0.5
        if t >= 1.0:
            w = 0.0
        x = t * length
        z_droop = -droop * length * t * t
        row = []
        for j in range(nv + 1):
            s = j / nv * 2 - 1  # -1..1
            y = s * w
            z = z_droop + abs(s) * w * fold
            row.append(bm.verts.new((x, y, z)))
        rows.append(row)
    for i in range(nu):
        for j in range(nv):
            q = [rows[i][j], rows[i][j + 1], rows[i + 1][j + 1], rows[i + 1][j]]
            uniq = []
            for v in q:
                if v not in uniq:
                    uniq.append(v)
            if len(uniq) < 3:
                continue
            f = bm.faces.new(uniq)
            for loop in f.loops:
                co = loop.vert.co
                loop[uvl].uv = (0.5 + co.y / (width * 1.3), co.x / length)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    ob = P.obj_from_bm(name, bm, material)
    P.smooth(ob, 80, weighted=False)
    return ob


def place(ob, loc, rot):
    ob.rotation_euler = rot
    ob.location = loc
    return ob


def pothos(name, loc, n_leaves=18, spread=0.25, trail=0.0, seed=1, material="leaf"):
    n_leaves = int(n_leaves * 0.8)
    """Sarmaşık (pothos): saksıdan çıkan kavisli saplar, kalp yapraklar; trail>0 ise aşağı sarkar."""
    rnd = random.Random(seed)
    objs = []
    base = Vector(loc)
    n_vines = 5 if trail <= 0 else 4
    for v in range(n_vines):
        ang = 2 * math.pi * v / n_vines + rnd.uniform(-0.3, 0.3)
        d = Vector((math.cos(ang), math.sin(ang), 0))
        pts = []
        L = spread * rnd.uniform(0.7, 1.2)
        for i in range(10):
            t = i / 9
            if trail > 0:
                p = base + d * (L * min(t * 2.2, 1.0)) + Vector((0, 0, 0.05 * math.sin(t * 3) - trail * max(0, t - 0.35) * 1.5))
            else:
                p = base + d * L * t + Vector((0, 0, 0.18 * math.sin(t * math.pi * 0.8) * rnd.uniform(0.7, 1.3)))
            pts.append(p)
        objs.append(P.sweep(f"{name}_vine{v}", P.resample(pts, 0.03), 0.0025, "stem", sides=5))
        n = n_leaves // n_vines
        for k in range(n):
            t = (k + 1) / (n + 0.5)
            idx = min(int(t * (len(pts) - 1)), len(pts) - 2)
            p = pts[idx].lerp(pts[idx + 1], t * (len(pts) - 1) - idx)
            sz = rnd.uniform(0.75, 1.15) * (0.07 if trail <= 0 else 0.06)
            lf = leaf_mesh(f"{name}_leaf{v}_{k}", length=sz * 1.4, width=sz, heart=0.35, fold=0.25,
                           droop=rnd.uniform(0.1, 0.4), material=material)
            yaw = ang + rnd.uniform(-1.2, 1.2) + (math.pi / 2 if k % 2 else -math.pi / 2) * 0.6
            pitch = rnd.uniform(-0.6, 0.2) if trail <= 0 else rnd.uniform(0.2, 0.9)
            place(lf, p, (rnd.uniform(-0.3, 0.3), pitch, yaw))
            objs.append(lf)
    return objs


def snake_plant(name, loc, n=11, height=0.75, seed=3):
    """Paşa kılıcı: dik, uca doğru incelen, hafif kıvrık kılıç yapraklar."""
    rnd = random.Random(seed)
    objs = []
    for i in range(n):
        h = height * rnd.uniform(0.55, 1.0)
        w = rnd.uniform(0.045, 0.065)
        bm = bmesh.new()
        uvl = bm.loops.layers.uv.new("UVMap")
        nu, nv = 10, 2
        twist = rnd.uniform(-0.6, 0.6)
        lean = rnd.uniform(-0.18, 0.18)
        rows = []
        for a in range(nu + 1):
            t = a / nu
            ww = w * (math.sin(math.pi * min(0.15 + t * 0.85, 1.0)) ** 0.5) * (1 - t ** 3)
            row = []
            for b in range(nv + 1):
                s = b / nv * 2 - 1
                ang = twist * t
                x = s * ww * math.cos(ang)
                y = s * ww * math.sin(ang) + abs(s) * ww * 0.35
                row.append(bm.verts.new((x + lean * h * t * t, y, t * h)))
            rows.append(row)
        for a in range(nu):
            for b in range(nv):
                q = [rows[a][b], rows[a][b + 1], rows[a + 1][b + 1], rows[a + 1][b]]
                uq = []
                for vv in q:
                    if vv not in uq:
                        uq.append(vv)
                if len(uq) >= 3:
                    f = bm.faces.new(uq)
                    for loop in f.loops:
                        loop[uvl].uv = (0.5 + loop.vert.co.x / (w * 2.5), loop.vert.co.z / h)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
        ob = P.obj_from_bm(f"{name}_b{i}", bm, "leaf_dark")
        P.smooth(ob, 80, weighted=False)
        r = rnd.uniform(0, 0.05)
        a0 = rnd.uniform(0, 2 * math.pi)
        place(ob, (loc[0] + r * math.cos(a0), loc[1] + r * math.sin(a0), loc[2]), (0, 0, rnd.uniform(0, 2 * math.pi)))
        objs.append(ob)
    return objs


def fiddle_leaf(name, loc, height=1.15, seed=5):
    """Keman yapraklı incir: tek gövde, iri dalgalı yapraklar."""
    rnd = random.Random(seed)
    objs = []
    base = Vector(loc)
    trunk = [base + Vector((0.02 * math.sin(t * 4), 0.015 * math.cos(t * 3), t * height)) for t in
             [i / 12 for i in range(13)]]
    objs.append(P.sweep(name + "_trunk", trunk, 0.012, "wood_walnut", sides=8,
                        radius_fn=lambda t: 1.0 - 0.5 * t))
    n = 16
    for k in range(n):
        t = 0.3 + 0.7 * k / (n - 1)
        p = base + Vector((0.02 * math.sin(t * 4), 0.015 * math.cos(t * 3), t * height))
        sz = 0.13 * rnd.uniform(0.85, 1.15) * (1.15 - 0.3 * t)
        lf = leaf_mesh(f"{name}_l{k}", length=sz * 1.5, width=sz, heart=-0.25, fold=0.18, droop=rnd.uniform(0.15, 0.45),
                       nu=8, nv=4, material="leaf")
        yaw = k * 2.4 + rnd.uniform(-0.3, 0.3)
        place(lf, p, (rnd.uniform(-0.2, 0.2), rnd.uniform(-0.7, -0.1), yaw))
        objs.append(lf)
    return objs


def herb_pot(name, loc, seed=7):
    objs = pot(name + "_pot", loc, r=0.05, h=0.08, material="terracotta")
    rnd = random.Random(seed)
    for k in range(14):
        sz = rnd.uniform(0.025, 0.04)
        lf = leaf_mesh(f"{name}_l{k}", length=sz * 1.4, width=sz, heart=0.0, fold=0.3, droop=0.3, nu=4, nv=2)
        ang = rnd.uniform(0, 2 * math.pi)
        r = rnd.uniform(0.0, 0.03)
        place(lf, (loc[0] + r * math.cos(ang), loc[1] + r * math.sin(ang), loc[2] + 0.07 + rnd.uniform(0.0, 0.07)),
              (0, rnd.uniform(-0.9, -0.2), ang))
        objs.append(lf)
    return objs


def dried_stems(name, loc, n=7, h=0.32, seed=9):
    rnd = random.Random(seed)
    objs = []
    for i in range(n):
        a = rnd.uniform(0, 2 * math.pi)
        lean = rnd.uniform(0.05, 0.2)
        top = Vector(loc) + Vector((math.cos(a) * lean * h, math.sin(a) * lean * h, h * rnd.uniform(0.8, 1.1)))
        pts = [Vector(loc).lerp(top, t) + Vector((0, 0, 0.02 * math.sin(t * 3))) for t in [i / 6 for i in range(7)]]
        objs.append(P.sweep(f"{name}_s{i}", pts, 0.0018, "paper", sides=4, caps=False))
        # Kurutulmuş çiçek başı (küçük elipsoid)
        objs += fruit(f"{name}_h{i}", top, r=0.012, material="fabric_oat", squash=1.6, seg=(8, 5))
    return objs


# ---------------------------------------------------------------- kitap, çerçeve

BOOK_COLUMNS = 12


def book(name, loc, size, col_idx, rot_z=0.0, tilt=0.0):
    """Kitap: size = (kalınlık x, derinlik y, yükseklik z). Sırt -Y yüzünde (yerel)."""
    t, d, h = size
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(t, d, h), verts=bm.verts)
    bmesh.ops.translate(bm, vec=(0, 0, h / 2), verts=bm.verts)
    ob = P.obj_from_bm(name, bm, "books")
    P.bevel(ob, min(0.003, t * 0.2), 2)
    P.smooth(ob, 40, weighted=False)
    me = ob.data
    uvl = me.uv_layers.new(name="UVMap")
    cw = 32.0 / 512.0
    u0 = (col_idx % BOOK_COLUMNS) * cw
    for p in me.polygons:
        n = p.normal
        for li in p.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            if n.y < -0.5:  # sırt
                uv = (u0 + cw * (co.x / t + 0.5) * 0.9 + cw * 0.05, co.z / h)
            elif abs(n.x) > 0.5:  # kapaklar: sırt renginin orta bandı
                uv = (u0 + cw * 0.5, 0.45 + 0.1 * co.z / h)
            else:  # sayfa kenarları
                uv = (384 / 512 + (64 / 512) * (co.x / t + 0.5) * 0.8 + 0.01, co.z / h if abs(n.z) < 0.5 else co.y / d + 0.5)
            uvl.data[li].uv = uv
    ob.rotation_euler = (0, tilt, rot_z)
    ob.location = loc
    return ob


def book_row(prefix, start, direction, length, depth, max_h, seed=11, spine_dir=None, lean_end=True):
    """Raf boyunca dizili kitaplar. direction: sıra yönü (birim, yatay). Sırtlar odaya bakar."""
    rnd = random.Random(seed)
    objs = []
    d = Vector(direction).normalized()
    pos = 0.0
    k = 0
    # Sırt yönü: kitabın yerel -Y'si odaya bakmalı
    face = Vector(spine_dir) if spine_dir else Vector((-d.y, d.x, 0)) * -1
    rot_z = math.atan2(face.x, -face.y)
    while pos < length - 0.03:
        t = rnd.uniform(0.018, 0.04)
        h = max_h * rnd.uniform(0.72, 1.0)
        if pos + t > length:
            break
        c = Vector(start) + d * (pos + t / 2)
        objs.append(book(f"{prefix}_{k}", c, (t, depth * rnd.uniform(0.8, 1.0), h), rnd.randrange(BOOK_COLUMNS), rot_z))
        pos += t + rnd.uniform(0.0, 0.004)
        k += 1
        if rnd.random() < 0.08 and pos < length - 0.2:
            pos += rnd.uniform(0.05, 0.1)
    if lean_end and pos < length - 0.06:
        t = 0.03
        h = max_h * 0.9
        c = Vector(start) + d * (pos + 0.04)
        ob = book(f"{prefix}_lean", c, (t, depth * 0.9, h), rnd.randrange(BOOK_COLUMNS), rot_z)
        ob.rotation_euler = (0, 0, rot_z)
        ob.rotation_mode = "XYZ"
        # Sıranın yönünde yaslanma: yerel x ekseni sıra yönüyle hizalı → Y ekseni etrafında eğ
        ob.rotation_euler = (0, -0.35, rot_z)
        objs.append(ob)
    return objs


def book_stack(prefix, loc, n=3, seed=13, rot=0.0):
    rnd = random.Random(seed)
    objs = []
    z = loc[2]
    for i in range(n):
        th = rnd.uniform(0.02, 0.035)
        w = rnd.uniform(0.15, 0.2)
        dd = rnd.uniform(0.11, 0.14)
        ob = book(f"{prefix}_{i}", (loc[0], loc[1], z + w / 2), (th, dd, w), rnd.randrange(BOOK_COLUMNS))
        # Yatırılmış kitap: Y ekseni etrafında 90°
        ob.rotation_euler = (0, math.pi / 2, rot + rnd.uniform(-0.15, 0.15))
        ob.location = (loc[0], loc[1], z + th / 2 - w / 2 + w / 2)
        bpy.context.view_layer.update()
        # Kitabın alt yüzü z'ye otursun
        bb = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
        mz = min(v.z for v in bb)
        ob.location.z += z - mz
        z += th
        objs.append(ob)
    return objs


def frame(name, loc, w, h, art_idx, normal_dir, frame_mat="wood_walnut", depth=0.025, border=0.025, mat_border=0.04):
    """Duvar tablosu: çerçeve + paspartu + resim (atlas çeyreği). normal_dir: duvardan dışarı."""
    objs = []
    n = Vector(normal_dir).normalized()
    rot_z = math.atan2(n.x, -n.y)  # yerel -Y = n
    # Çerçeve: dört çıta
    parts = [((0, 0, h / 2 - border / 2), (w, depth, border)), ((0, 0, -h / 2 + border / 2), (w, depth, border)),
             ((-w / 2 + border / 2, 0, 0), (border, depth, h - 2 * border)),
             ((w / 2 - border / 2, 0, 0), (border, depth, h - 2 * border))]
    for i, (o, s) in enumerate(parts):
        objs.append(P.box(f"{name}_f{i}", s, (o[0], -depth / 2, o[2]), frame_mat, bev=0.004, seg=2))
    iw, ih = w - 2 * border, h - 2 * border
    objs.append(P.box(f"{name}_mat", (iw, 0.006, ih), (0, -0.006, 0), "paper", bev=0.0, uv_scale=1.0))
    # Resim düzlemi (atlas UV)
    aw, ah = iw - 2 * mat_border, ih - 2 * mat_border
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    ay = -0.0095
    vs = [bm.verts.new((-aw / 2, ay, -ah / 2)), bm.verts.new((aw / 2, ay, -ah / 2)),
          bm.verts.new((aw / 2, ay, ah / 2)), bm.verts.new((-aw / 2, ay, ah / 2))]
    f = bm.faces.new(vs)
    cu, cv = (art_idx % 2) * 0.5, (art_idx // 2) * 0.5
    # Görüntü satırları yukarıdan aşağı: v=0 üst
    asp = aw / ah
    su, sv = (0.5, 0.5 / asp) if asp > 1 else (0.5 * asp, 0.5)
    for loop in f.loops:
        co = loop.vert.co
        loop[uvl].uv = (cu + 0.25 + (co.x / aw) * su * 0.95, P.gv(cv + 0.25 - (co.z / ah) * sv * 0.95))
    if f.normal.y > 0:
        f.normal_flip()
    art = P.obj_from_bm(f"{name}_art", bm, "art")
    objs.append(art)
    for o in objs:
        o.location = Matrix.Rotation(rot_z, 3, "Z") @ Vector(o.location) + Vector(loc)
        o.rotation_euler = (0, 0, rot_z)
    return objs


# ---------------------------------------------------------------- yumuşak eşyalar

def cushion(name, loc, size, material, rot=(0, 0, 0), puff=0.35, seg=1):
    """Kırlent/minder: alt bölünmeli kutu, köşeler sivri, ortası kabarık."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=2, use_grid_fill=True)
    for v in bm.verts:
        x, y, z = v.co
        # Kalınlık ortada fazla, kenarda az
        k = (1 - (2 * x) ** 2) * (1 - (2 * z) ** 2)
        v.co.y = y * (1 - puff + puff * max(k, 0) * 1.6)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    ob = P.obj_from_bm(name, bm, material)
    P.subsurf(ob, seg)
    P.smooth(ob, 80, weighted=False)
    ob.rotation_euler = rot
    ob.location = loc
    bpy.context.view_layer.update()
    P.box_uv(ob, 1.0)
    return [ob]


def seat_cushion(name, loc, size, material, bulge=0.012):
    """Oturma minderi: pahlı kutu + hafif üst kabarıklık + alt bölünme ile yumuşak kenar."""
    sx, sy, sz = size
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=2, use_grid_fill=True)
    for v in bm.verts:
        x, y, z = v.co
        if z > 0.49:
            v.co.z += bulge / sz * (1 - (2 * x) ** 2) * (1 - (2 * y) ** 2)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    ob = P.obj_from_bm(name, bm, material)
    b = ob.modifiers.new("b", "BEVEL")
    b.width = min(sz * 0.3, 0.03)
    b.segments = 2
    b.limit_method = "ANGLE"
    P.apply_mods(ob)
    P.subsurf(ob, 1)
    P.smooth(ob, 80, weighted=False)
    ob.location = loc
    bpy.context.view_layer.update()
    P.box_uv(ob, 1.0)
    return [ob]
