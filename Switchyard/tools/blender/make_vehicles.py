"""Switchyard — araçlar: manevra lokomotifi + altı vagon gövdesi (her biri her renge boyanabilir).

    Blender -b --factory-startup -P tools/blender/make_vehicles.py [-- --only=loco,box --no-bake]

Çıktı: assets/models/vehicles/<ad>.glb
Sözleşme (Godot): orijin ray üstünde, iki aksın ortasında; ön yüz +Z (Blender -Y). Tampon başları ±OVER_BUFFERS/2.
Düğümler: `Body` (tek ağ, çok yüzey: paint + vc_* + cam + lamba), vagonlarda `Symbols/Sym_<şekil>` (beyaz simge
plakaları, çatı + iki yan; ArtKit rengin şeklini bırakır, ötekileri siler), `CouplerFront`, `CouplerRear`, `RoofTop`.
"""

import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import sy_bl as B  # noqa: E402
import sy_spec as S  # noqa: E402

OUT = os.path.join(S.ROOT, "assets", "models", "vehicles")
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
NO_BAKE = "--no-bake" in ARGS
ONLY = next((a.split("=", 1)[1].split(",") for a in ARGS if a.startswith("--only=")), None)

HL = S.HEADSTOCK_LEN / 2.0
OB = S.OVER_BUFFERS / 2.0
W = S.VEHICLE_W
DECK = 0.158          # şasi üstü (döşeme)
SHAPES = ["circle", "triangle", "square", "diamond", "star", "cross"]


# ---------------------------------------------------------------- küçük yardımcılar

def along_y(obj):
    """XY'de çizilip Z'de kalınlaştırılmış şekli, kalınlık Y boyunca olacak biçimde çevirir (profil XZ'de)."""
    obj.data.transform(Matrix.Rotation(math.radians(90), 4, "X"))
    obj.data.update()
    return obj


def prism_y(name, outline_xz, length, material, bev=0.004, y=0.0, seg=3):
    """XZ düzleminde verilen profili Y boyunca `length` uzatır (merkez y)."""
    ob = B.extrude_shape(name, outline_xz, length, material, bev=bev, bev_seg=seg, z0=-length / 2.0)
    along_y(ob)
    ob.location = (0, y, 0)
    B.apply_transform(ob)
    return ob


def roof_profile(w, z0, rise, flat, thick, steps=10):
    """Düz tepeli, yuvarlak omuzlu çatı kesiti (x, z). w: tam genişlik, z0: saçak altı."""
    hw = w / 2.0
    top = []
    for i in range(steps + 1):
        t = i / steps
        x = -hw + t * (hw - flat / 2.0)
        u = (x + hw) / (hw - flat / 2.0)          # 0 saçak .. 1 düz kısmın başı
        z = z0 + thick + rise * math.sin(u * math.pi / 2.0)
        top.append((x, z))
    right = [(-x, z) for x, z in reversed(top)]
    return [(-hw, z0)] + top + right + [(hw, z0)]


def symbol_plate(name, kind, size, depth=0.006, dense=False):
    """Yatay simge plakası (tepe yüzü z=depth), yoğun üçgenli (eğriye sarılabilsin)."""
    outline = B.symbol_outline(kind, size)
    bm = bmesh.new()
    vs = [bm.verts.new((x, y, 0.0)) for x, y in outline]
    f = bm.faces.new(vs)
    res = bmesh.ops.triangulate(bm, faces=[f], quad_method="BEAUTY", ngon_method="BEAUTY")
    if dense:
        bmesh.ops.subdivide_edges(bm, edges=list({e for fc in res["faces"] for e in fc.edges}), cuts=2,
                                  use_grid_fill=True)
    ext = bmesh.ops.extrude_face_region(bm, geom=list(bm.faces))
    top_verts = [v for v in ext["geom"] if isinstance(v, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, vec=Vector((0, 0, depth)), verts=top_verts)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = B.obj_from_bm(name, bm, "symbol")
    b = ob.modifiers.new("bevel", "BEVEL")
    b.width = depth * 0.45
    b.segments = 2
    b.limit_method = "ANGLE"
    b.angle_limit = math.radians(50)
    B.apply_mods(ob)
    B.smooth(ob, 45.0, weighted=False)
    return ob


def place_plate(ob, loc, face):
    """Plakayı yüzeye yerleştirir. face: 'top' | '+x' | '-x' (yan duvar)."""
    if face == "+x":
        ob.data.transform(Matrix.Rotation(math.radians(90), 4, "Y"))
    elif face == "-x":
        ob.data.transform(Matrix.Rotation(math.radians(-90), 4, "Y"))
    elif face == "-x_upright":
        pass
    ob.data.update()
    ob.location = loc
    B.apply_transform(ob)
    return ob


def wrap_cylinder(ob, radius):
    """Tepe yüzü yatay (yerel z = 0..d) plakayı Y eksenli silindire sarar (orijin = silindir ekseni)."""
    me = ob.data
    for v in me.vertices:
        x, y, z = v.co
        r = radius + z
        th = x / radius
        v.co = Vector((r * math.sin(th), y, r * math.cos(th)))
    me.update()
    return ob


# ---------------------------------------------------------------- yürüyen aksam

def wheelset(y, r=S.WHEEL_R, gauge=S.GAUGE):
    parts = []
    tw = 0.024
    prof = [(0.0, -tw / 2), (r * 0.55, -tw / 2), (r * 0.62, -tw / 2 - 0.004), (r * 0.94, -tw / 2 - 0.002),
            (r, -tw / 2 + 0.004), (r + 0.010, -tw / 2 + 0.004), (r + 0.011, -tw / 2 + 0.009), (r, tw / 2 - 0.004),
            (r * 0.96, tw / 2), (r * 0.6, tw / 2 + 0.003), (r * 0.25, tw / 2 + 0.006), (0.0, tw / 2 + 0.006)]
    for sx in (-1, 1):
        # Flanş içeride (ray içine bakar): profil +z dışa doğru; sol tekerde çevir.
        p = [(rr, z * -sx) for rr, z in prof]
        if sx < 0:
            p = list(reversed(p))
        wh = B.lathe("wheel", p, (sx * gauge / 2.0, y, r), "steel_dark", verts=28, axis="X", angle=50)
        parts.append(wh)
    parts.append(B.cyl("axle", 0.012, gauge + 0.03, (-(gauge + 0.03) / 2, y, r), "steel_dark", verts=12, axis="X"))
    return parts


def axlebox_spring(y, x, r=S.WHEEL_R):
    parts = [B.box("axlebox", (0.034, 0.05, 0.046), (x, y, r + 0.004), "frame_dark", bev=0.006)]
    # Yaprak yay: kavisli ince plaka (dört kat)
    for k in range(3):
        L = 0.17 - k * 0.035
        pts = []
        for i in range(9):
            t = i / 8.0
            yy = y - L / 2 + L * t
            zz = r + 0.034 + 0.012 * (1 - (2 * t - 1) ** 2) - k * 0.006
            pts.append((x, yy, zz))
        parts.append(B.profile_sweep("spring", pts, [(-0.012, 0), (0.012, 0), (0.012, 0.005), (-0.012, 0.005)],
                                     "steel_dark", smooth_angle=30))
    return parts


def buffer(x, y_face, front):
    """Tampon: gövde + mil + kavisli baş. y_face: başın dış yüzü; front: -Y yönü mü."""
    sgn = -1.0 if front else 1.0
    base_y = sgn * HL
    parts = []
    # Gövde (kovan)
    parts.append(B.cyl("buf_body", 0.022, 0.05, (0, 0, 0), "frame_dark", verts=20, axis="Y", bev=0.004))
    parts[-1].location = (x, base_y + (0 if not front else -0.05), S.BUFFER_Y)
    B.apply_transform(parts[-1])
    # Mil
    stem_len = abs(y_face - base_y) - 0.05 - 0.008
    st = B.cyl("buf_stem", 0.014, stem_len, (0, 0, 0), "steel", verts=16, axis="Y")
    st.location = (x, base_y + sgn * 0.05 + (0 if not front else -stem_len), S.BUFFER_Y)
    B.apply_transform(st)
    parts.append(st)
    # Baş (yuvarlak disk, hafif kubbe)
    prof = [(0.0, 0.0), (0.030, 0.0), (0.034, 0.003), (0.034, 0.008), (0.026, 0.012), (0.0, 0.0135)]
    hd = B.lathe("buf_head", prof, (0, 0, 0), "steel", verts=28, axis="Y", angle=60)
    if front:
        hd.data.transform(Matrix.Rotation(math.pi, 4, "Z"))
    hd.location = (x, y_face - sgn * 0.0135, S.BUFFER_Y)
    B.apply_transform(hd)
    parts.append(hd)
    return parts


def coupler_hook(front):
    sgn = -1.0 if front else 1.0
    parts = []
    hk = B.box("hook", (0.026, 0.06, 0.03), (0, sgn * (HL + 0.03), S.BUFFER_Y), "frame_dark", bev=0.007)
    parts.append(hk)
    # Kanca ucu (yukarı kıvrık)
    parts.append(B.box("hook_tip", (0.022, 0.016, 0.042), (0, sgn * (HL + 0.058), S.BUFFER_Y + 0.008), "frame_dark",
                       bev=0.006))
    return parts


def underframe(length_hs=S.HEADSTOCK_LEN, axles=(-0.2, 0.2), beam_mat=("frame_dark", "frame_dark"), wheel_r=S.WHEEL_R,
               springs=True, deck_mat=None):
    """Şasi: yan kirişler, tampon kirişleri, tamponlar, kancalar, tekerlek takımları, yaylar."""
    parts = []
    hl = length_hs / 2.0
    sole_w = 0.03
    sx = W / 2.0 - sole_w / 2.0 - 0.012
    for s in (-1, 1):
        parts.append(B.box("sole", (sole_w, length_hs - 0.02, 0.05), (s * sx, 0, S.FRAME_Y + 0.025), "frame_dark",
                           bev=0.006, cuts=2))
    for front, mat in ((True, beam_mat[0]), (False, beam_mat[1])):
        y = -hl if front else hl
        parts.append(B.box("beam", (W - 0.01, 0.04, 0.072), (0, y + (0.0 if front else 0.0), S.BUFFER_Y), mat,
                           bev=0.008, cuts=2))
        for bx in (-S.BUFFER_SPACING / 2, S.BUFFER_SPACING / 2):
            parts += buffer(bx, -OB if front else OB, front)
        parts += coupler_hook(front)
    if deck_mat:
        parts.append(B.box("deck", (W, length_hs - 0.04, 0.02), (0, 0, DECK - 0.01), deck_mat, bev=0.005, cuts=3))
    for y in axles:
        parts += wheelset(y, wheel_r)
        if springs:
            for s in (-1, 1):
                parts += axlebox_spring(y, s * (S.GAUGE / 2 + 0.045), wheel_r)
    return parts


def bogie(y, wheel_r=0.052, spread=0.15):
    parts = []
    for dy in (-spread / 2, spread / 2):
        parts += wheelset(y + dy, wheel_r)
    for s in (-1, 1):
        x = s * (S.GAUGE / 2 + 0.04)
        parts.append(B.box("bogie_side", (0.026, spread + 0.11, 0.05), (x, y, wheel_r + 0.01), "frame_dark",
                           bev=0.008, cuts=2))
        for dy in (-spread / 2, spread / 2):
            parts.append(B.box("bogie_box", (0.03, 0.04, 0.036), (x + s * 0.008, y + dy, wheel_r), "steel_dark",
                               bev=0.006))
        parts.append(B.cyl("bogie_spring", 0.014, 0.04, (x, y, wheel_r + 0.035), "steel", verts=12))
    parts.append(B.box("bolster", (S.GAUGE + 0.1, 0.05, 0.03), (0, y, wheel_r + 0.04), "frame_dark", bev=0.006))
    return parts


# ---------------------------------------------------------------- simgeler

def add_symbols(top_z, side_x, side_z, side_y=0.0, top_size=0.30, side_size=0.17, cyl_r=None, side_top=False):
    """Altı şeklin hepsini üretir: her biri (çatı + iki yan) tek ağ. Dönüş: [nesne]."""
    out = []
    for kind in SHAPES:
        pieces = []
        top = symbol_plate("t", kind, top_size, dense=cyl_r is not None)
        if cyl_r is not None:
            top.location = (0, 0, 0)
            B.apply_transform(top)
            wrap_cylinder(top, cyl_r)
            top.location = (0, 0, top_z - cyl_r)
            B.apply_transform(top)
        else:
            # Önü -Y olan araçta şeklin "yukarısı" yolculuk yönüne (ön) baksın
            top.data.transform(Matrix.Rotation(math.pi, 4, "Z"))
            top.location = (0, 0, top_z)
            B.apply_transform(top)
        pieces.append(top)
        for s in (-1, 1):
            sd = symbol_plate("s", kind, side_size, depth=0.005, dense=cyl_r is not None)
            if cyl_r is not None:
                wrap_cylinder(sd, cyl_r)
                sd.data.transform(Matrix.Rotation(math.radians(90) * s, 4, "Y"))
                sd.location = (0, side_y, side_z)
            else:
                # Yan duvar: plaka yüzü +x/-x'e bakar; şeklin yukarısı +Z.
                sd.data.transform(Matrix.Rotation(math.radians(90) * s, 4, "Z"))
                sd.data.transform(Matrix.Rotation(math.radians(90) * s, 4, "Y"))
                sd.location = (s * side_x, side_y, side_z)
            B.apply_transform(sd)
            pieces.append(sd)
        ob = B.join(pieces, f"Sym_{kind}")
        B.ensure_white_vcol([ob])
        out.append(ob)
    return out


# ---------------------------------------------------------------- gövdeler

def body_box_van():
    parts = underframe(axles=(-0.2, 0.2))
    L = 0.70
    z0, z1 = DECK, 0.385
    parts.append(B.box("floor", (W - 0.02, L, 0.02), (0, 0, DECK - 0.005), "frame_dark", bev=0.004))
    walls = B.box("walls", (W - 0.02, L, z1 - z0), (0, 0, (z0 + z1) / 2), "paint", bev=0.014, seg=3, cuts=3)
    parts.append(walls)
    hw = (W - 0.02) / 2
    # Dikey dikmeler (çelik çerçeve) + çapraz destek — boyalı, hafif çıkıntılı
    for s in (-1, 1):
        for y in (-0.33, -0.2, 0.2, 0.33):
            parts.append(B.box("stanchion", (0.012, 0.018, z1 - z0 - 0.01), (s * (hw + 0.004), y, (z0 + z1) / 2),
                               "paint", bev=0.004))
        # Kapı (ortada, hafif çıkıntılı) + ray
        parts.append(B.box("door", (0.012, 0.26, z1 - z0 - 0.03), (s * (hw + 0.006), 0, (z0 + z1) / 2 - 0.004),
                           "paint", bev=0.005, cuts=2))
        parts.append(B.box("door_rail", (0.012, 0.42, 0.012), (s * (hw + 0.012), 0, z1 - 0.012), "frame_dark",
                           bev=0.004))
        parts.append(B.box("door_rail_lo", (0.012, 0.42, 0.01), (s * (hw + 0.012), 0, z0 + 0.012), "frame_dark",
                           bev=0.004))
        for y in (-0.12, 0.12):
            parts.append(B.box("door_edge", (0.006, 0.012, z1 - z0 - 0.05), (s * (hw + 0.013), y, (z0 + z1) / 2),
                               "frame_dark", bev=0.003))
    # Uç duvar dikmeleri
    for e in (-1, 1):
        for x in (-0.12, 0.12):
            parts.append(B.box("end_post", (0.016, 0.012, z1 - z0 - 0.01), (x, e * (L / 2 + 0.004), (z0 + z1) / 2),
                               "paint", bev=0.004))
    # Çatı: düz tepeli yuvarlak omuz, saçak taşmalı (boyalı: üstten rengi taşır)
    roof = prism_y("roof", roof_profile(W + 0.02, z1 - 0.004, 0.03, 0.30, 0.012), L + 0.03, "paint", bev=0.006)
    parts.append(roof)
    top_z = z1 - 0.004 + 0.012 + 0.03
    syms = add_symbols(top_z, hw + 0.012, (z0 + z1) / 2 - 0.004, side_y=0.0, top_size=0.30, side_size=0.17)
    return parts, syms, top_z


def body_tank():
    parts = underframe(axles=(-0.2, 0.2), deck_mat=None)
    R = 0.178
    cz = 0.33
    L = 0.60
    # Tank: silindir + çanak uçlar (döndürme gövdesi, eksen Y)
    prof = [(0.0, -L / 2 - 0.045)]
    for i in range(1, 9):
        a = i / 8 * math.pi / 2
        prof.append((R * math.sin(a), -L / 2 - 0.045 * math.cos(a)))
    prof += [(R, 0.0)]
    for i in range(8, 0, -1):
        a = i / 8 * math.pi / 2
        prof.append((R * math.sin(a), L / 2 + 0.045 * math.cos(a)))
    prof.append((0.0, L / 2 + 0.045))
    tank = B.lathe("tank", prof, (0, 0, cz), "paint", verts=48, axis="Y", angle=60)
    tank.data.transform(Matrix.Rotation(math.pi, 4, "Z"))
    B.apply_transform(tank)
    parts.append(tank)
    # Kuşaklar
    for y in (-0.2, 0.2):
        band = B.lathe("band", [(R + 0.006, -0.012), (R + 0.006, 0.012)], (0, y, cz), "frame_dark", verts=48,
                       axis="Y", close_top=False, close_bottom=False)
        parts.append(band)
    # Beşikler
    for y in (-0.2, 0.2):
        parts.append(B.box("saddle", (W - 0.04, 0.05, 0.07), (0, y, DECK + 0.01), "frame_dark", bev=0.008))
    parts.append(B.box("tank_floor", (0.2, 0.66, 0.02), (0, 0, DECK - 0.01), "frame_dark", bev=0.004))
    # Kapaklar (iki uçta) + yürüme platformu
    for y in (-0.26, 0.26):
        parts.append(B.cyl("hatch", 0.035, 0.03, (0, y, cz + R - 0.008), "frame_dark", verts=24, bev=0.006))
        parts.append(B.cyl("hatch_lid", 0.04, 0.008, (0, y, cz + R + 0.02), "steel_dark", verts=24, bev=0.003))
    # Uç merdivenler
    for e in (-1, 1):
        for x in (-0.05, 0.05):
            parts.append(B.box("ladder_rail", (0.008, 0.008, 0.2), (x, e * (L / 2 + 0.06), DECK + 0.1), "steel_dark",
                               bev=0.003))
        for k in range(4):
            parts.append(B.box("ladder_rung", (0.1, 0.006, 0.006), (0, e * (L / 2 + 0.06), DECK + 0.03 + k * 0.05),
                               "steel_dark", bev=0.002))
    top_z = cz + R
    syms = add_symbols(top_z, 0, cz, side_y=0.0, top_size=0.28, side_size=0.17, cyl_r=R)
    return parts, syms, top_z + 0.03


def body_hopper():
    parts = underframe(axles=(-0.22, 0.22))
    L = 0.70
    z0, z1 = 0.24, 0.40
    hw = (W - 0.02) / 2
    # Üst gövde (dik duvarlar)
    parts.append(B.box("upper", (W - 0.02, L, z1 - z0), (0, 0, (z0 + z1) / 2), "paint", bev=0.014, cuts=3))
    # Alt hunilar (iki V), yandan görünür
    for y in (-0.17, 0.17):
        out = [(-hw + 0.02, z0 + 0.002), (hw - 0.02, z0 + 0.002), (0.05, DECK - 0.04), (-0.05, DECK - 0.04)]
        hop = prism_y("hopper", B.arc_fillet(out, 0.02, 4), 0.3, "paint", bev=0.008, y=y)
        parts.append(hop)
        parts.append(B.box("gate", (0.1, 0.12, 0.02), (0, y, DECK - 0.045), "frame_dark", bev=0.005))
    # Dış dikmeler
    for s in (-1, 1):
        for y in (-0.3, -0.15, 0.0, 0.15, 0.3):
            parts.append(B.box("rib", (0.012, 0.016, z1 - z0 - 0.01), (s * (hw + 0.004), y, (z0 + z1) / 2), "paint",
                               bev=0.004))
        parts.append(B.box("sill", (0.016, L + 0.01, 0.02), (s * (hw + 0.004), 0, z0 + 0.008), "paint", bev=0.005))
    # Uç platformlar
    for e in (-1, 1):
        parts.append(B.box("end_plat", (W - 0.06, 0.04, 0.01), (0, e * (L / 2 + 0.005), DECK + 0.01), "frame_dark",
                           bev=0.003))
        parts.append(B.box("end_slope", (W - 0.04, 0.02, 0.17), (0, e * (L / 2 - 0.01), DECK + 0.085), "paint",
                           bev=0.006))
    roof = prism_y("roof", roof_profile(W, z1 - 0.004, 0.022, 0.30, 0.01), L + 0.01, "paint", bev=0.005)
    parts.append(roof)
    top_z = z1 - 0.004 + 0.01 + 0.022
    # Yükleme kapakları (çatı uçlarında, küçük)
    for y in (-0.28, 0.28):
        parts.append(B.cyl("hatch", 0.04, 0.012, (0, y, top_z - 0.002), "roof_grey", verts=28, bev=0.004))
    syms = add_symbols(top_z, hw + 0.01, (z0 + z1) / 2, top_size=0.28, side_size=0.13)
    return parts, syms, top_z


def body_container():
    parts = underframe(axles=(-0.22, 0.22), deck_mat="frame_grey")
    L = 0.68
    cw = W - 0.03
    z0 = DECK + 0.012
    z1 = 0.41
    # Konteyner: oluklu yan duvarlar (sinüs kesitli yüzey) — pürüzsüz oluk, köşeli değil
    parts.append(B.box("cont_core", (cw - 0.012, L - 0.012, z1 - z0), (0, 0, (z0 + z1) / 2), "paint", bev=0.008,
                       cuts=2))
    for s in (-1, 1):
        n_ribs = 14
        for i in range(n_ribs):
            y = -L / 2 + 0.05 + (L - 0.1) * (i + 0.5) / n_ribs
            prof = [(0.0, -0.012), (0.006, -0.008), (0.008, 0.0), (0.006, 0.008), (0.0, 0.012)]
            rib = B.box("cont_rib", (0.008, 0.026, z1 - z0 - 0.04), (s * (cw / 2 - 0.004), y, (z0 + z1) / 2),
                        "paint", bev=0.0035, seg=3)
            parts.append(rib)
            del prof
    # Köşe direkleri ve üst/alt kirişler (koyu boya değil: konteyner renginde, ama biraz koyu = AO)
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(B.box("corner", (0.03, 0.03, z1 - z0), (sx * (cw / 2 - 0.012), sy * (L / 2 - 0.012),
                                                                (z0 + z1) / 2), "paint", bev=0.006))
    for s in (-1, 1):
        parts.append(B.box("top_rail", (0.02, L, 0.022), (s * (cw / 2 - 0.006), 0, z1 - 0.008), "paint", bev=0.006))
        parts.append(B.box("bot_rail", (0.02, L, 0.022), (s * (cw / 2 - 0.006), 0, z0 + 0.01), "paint", bev=0.006))
    # Arka kapılar + kilit çubukları
    for x in (-0.11, -0.04, 0.04, 0.11):
        parts.append(B.cyl("lockbar", 0.0045, z1 - z0 - 0.04, (x, L / 2 + 0.002, z0 + 0.02), "steel", verts=10))
    # Çatı: hafif içbükey paneller
    parts.append(B.box("cont_roof", (cw - 0.01, L - 0.01, 0.012), (0, 0, z1 + 0.002), "paint", bev=0.005, cuts=3))
    top_z = z1 + 0.008
    # Taşıyıcı kilitleri
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(B.box("twist", (0.03, 0.03, 0.012), (sx * (cw / 2 - 0.012), sy * (L / 2 - 0.012), DECK + 0.004),
                               "frame_dark", bev=0.003))
    syms = add_symbols(top_z, cw / 2 + 0.004, (z0 + z1) / 2, top_size=0.30, side_size=0.17)
    return parts, syms, top_z


def body_glass():
    """Kırılgan yük: cam levhalar (yarı saydam), boyalı sandık çerçevesi, kauçuk köşe tamponları."""
    parts = underframe(axles=(-0.2, 0.2), deck_mat="paint")
    L = 0.66
    cw = W - 0.05
    z0 = DECK + 0.004
    z1 = 0.37
    # Çerçeve: köşe direkleri, üst kirişler, çaprazlar (boyalı)
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(B.box("post", (0.026, 0.026, z1 - z0), (sx * cw / 2, sy * L / 2, (z0 + z1) / 2), "paint",
                               bev=0.006))
            parts.append(B.box("pad", (0.036, 0.036, 0.04), (sx * cw / 2, sy * L / 2, z1 - 0.02), "rubber", bev=0.01))
    for s in (-1, 1):
        parts.append(B.box("rail_top", (0.022, L, 0.024), (s * cw / 2, 0, z1 - 0.012), "paint", bev=0.006))
        parts.append(B.box("rail_mid", (0.016, L, 0.016), (s * cw / 2, 0, (z0 + z1) / 2 - 0.02), "paint", bev=0.005))
        parts.append(B.box("post_mid", (0.02, 0.02, z1 - z0), (s * cw / 2, 0, (z0 + z1) / 2), "paint", bev=0.005))
    for e in (-1, 1):
        parts.append(B.box("end_top", (cw, 0.022, 0.024), (0, e * L / 2, z1 - 0.012), "paint", bev=0.006))
    # Cam levhalar: A çerçeveye yaslı, iki yanda 3'er levha (yan yana kenarları görünür)
    for s in (-1, 1):
        for k in range(3):
            g = B.box("pane", (0.008, L - 0.08, z1 - z0 - 0.05), (0, 0, 0), "glass_load", bev=0.002)
            g.rotation_euler = (0, math.radians(-s * 12), 0)
            g.location = (s * (0.05 + k * 0.022), 0, (z0 + z1) / 2 - 0.01)
            B.apply_transform(g)
            parts.append(g)
    # A çerçeve (koyu çelik) + üst yastık
    for y in (-0.22, 0.0, 0.22):
        for s in (-1, 1):
            st = B.box("aframe", (0.014, 0.016, z1 - z0 - 0.02), (0, 0, 0), "frame_dark", bev=0.004)
            st.rotation_euler = (0, math.radians(-s * 12), 0)
            st.location = (s * 0.03, y, (z0 + z1) / 2 - 0.01)
            B.apply_transform(st)
            parts.append(st)
    # Kapak (boyalı) — üstten simgeyi taşır; camın üstü örtülü değil, kenarlar açık kalır.
    lid = B.box("lid", (cw - 0.12, L - 0.1, 0.016), (0, 0, z1 + 0.004), "paint", bev=0.006, cuts=3)
    parts.append(lid)
    top_z = z1 + 0.012
    syms = add_symbols(top_z, cw / 2 + 0.013, (z0 + z1) / 2 + 0.06, side_y=0.0, top_size=0.24, side_size=0.1)
    return parts, syms, top_z


def body_heavy():
    """Ağır yük: dört akslı (iki boji), alçak şasi, kanatçıklı trafo bloğu (boyalı), zincir bağlar."""
    parts = []
    hl = HL
    for front in (True, False):
        y = -hl if front else hl
        parts.append(B.box("beam", (W - 0.01, 0.04, 0.072), (0, y, S.BUFFER_Y), "frame_dark", bev=0.008, cuts=2))
        for bx in (-S.BUFFER_SPACING / 2, S.BUFFER_SPACING / 2):
            parts += buffer(bx, -OB if front else OB, front)
        parts += coupler_hook(front)
    for s in (-1, 1):
        # Derin yan kiriş (balık karnı)
        out = [(-hl + 0.02, 0.17), (hl - 0.02, 0.17), (hl - 0.02, 0.11), (0.16, 0.075), (-0.16, 0.075),
               (-hl + 0.02, 0.11)]
        sb = B.extrude_shape("sole", B.arc_fillet(out, 0.02, 4), 0.03, "frame_dark", bev=0.006, z0=-0.015)
        sb.data.transform(Matrix.Rotation(math.radians(90), 4, "Z"))
        sb.data.transform(Matrix.Rotation(math.radians(90), 4, "Y"))
        sb.location = (s * (W / 2 - 0.03), 0, 0)
        B.apply_transform(sb)
        parts.append(sb)
    parts.append(B.box("deck", (W - 0.02, 2 * hl - 0.02, 0.022), (0, 0, 0.17), "frame_grey", bev=0.005, cuts=3))
    parts += bogie(-0.22)
    parts += bogie(0.22)
    # Trafo bloğu
    bw, bl, bz0, bz1 = 0.34, 0.46, 0.181, 0.40
    parts.append(B.box("block", (bw, bl, bz1 - bz0), (0, 0, (bz0 + bz1) / 2), "paint", bev=0.016, cuts=3))
    for s in (-1, 1):
        for i in range(7):
            y = -bl / 2 + 0.06 + (bl - 0.12) * i / 6
            parts.append(B.box("fin", (0.04, 0.012, bz1 - bz0 - 0.06), (s * (bw / 2 + 0.018), y, (bz0 + bz1) / 2 - 0.01),
                               "paint", bev=0.004))
    # Üst bağlantılar ve kancalar
    for x, y in ((-0.11, -0.16), (0.11, -0.16), (-0.11, 0.16), (0.11, 0.16)):
        parts.append(B.cyl("bushing", 0.016, 0.03, (x, y, bz1 - 0.002), "cream", verts=16, bev=0.004))
    parts.append(B.box("cap", (bw - 0.04, bl - 0.04, 0.012), (0, 0, bz1 + 0.002), "paint", bev=0.005, cuts=3))
    # Zincir bağlar (köşelerden şasiye) — boru zincir
    for sx in (-1, 1):
        for sy in (-1, 1):
            a = (sx * (bw / 2 - 0.01), sy * (bl / 2 - 0.01), bz1 - 0.05)
            b = (sx * (W / 2 - 0.035), sy * (hl - 0.06), 0.185)
            parts.append(B.sweep("chain", [a, ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, (a[2] + b[2]) / 2 - 0.01), b],
                                 0.006, "steel_dark", sides=8))
    top_z = bz1 + 0.008
    syms = add_symbols(top_z, bw / 2 + 0.04, (bz0 + bz1) / 2 + 0.04, top_size=0.26, side_size=0.1)
    # Yan simgeler kanatçıkların önüne gelsin: yandan biraz dışarı taşı
    return parts, syms, top_z


# ---------------------------------------------------------------- lokomotif

def loco():
    parts = []
    hl = HL
    axles = (-0.22, 0.0, 0.22)
    wr = 0.072
    # Şasi + yürüme yolu (gövde rengi)
    for s in (-1, 1):
        parts.append(B.box("sole", (0.03, 2 * hl - 0.02, 0.06), (s * (W / 2 - 0.04), 0, S.FRAME_Y + 0.03), "frame_dark",
                           bev=0.006, cuts=2))
    parts.append(B.box("footplate", (W + 0.01, 2 * hl, 0.022), (0, 0, 0.162), "loco_body", bev=0.006, cuts=3))
    # Ön tampon kirişi: sarı + koyu çapraz şeritler (yön ipucu); arka: kırmızı
    parts.append(B.box("beam_f", (W + 0.01, 0.042, 0.08), (0, -hl, S.BUFFER_Y), "stripe_yellow", bev=0.008, cuts=2))
    for i in range(-2, 3):
        st = B.box("chevron", (0.03, 0.006, 0.078), (0, 0, 0), "stripe_dark", bev=0.002)
        st.rotation_euler = (0, math.radians(40), 0)
        st.location = (i * 0.09, -hl - 0.0215, S.BUFFER_Y)
        B.apply_transform(st)
        # Kirişin dışına taşan uçları kırp: ölçekle
        parts.append(st)
    parts.append(B.box("beam_r", (W + 0.01, 0.042, 0.08), (0, hl, S.BUFFER_Y), "buffer_red", bev=0.008, cuts=2))
    for front in (True, False):
        for bx in (-S.BUFFER_SPACING / 2, S.BUFFER_SPACING / 2):
            parts += buffer(bx, -OB if front else OB, front)
        parts += coupler_hook(front)
    # Tekerlekler + biyel kolları (karakter): dış tarafta kol ve krank
    for y in axles:
        parts += wheelset(y, wr)
        for s in (-1, 1):
            parts.append(B.cyl("crank", 0.016, 0.012, (s * (S.GAUGE / 2 + 0.016), y, wr), "steel", verts=16, axis="X"))
            parts.append(B.box("axlebox", (0.03, 0.05, 0.05), (s * (S.GAUGE / 2 + 0.06), y, wr + 0.01), "frame_dark",
                               bev=0.007))
    for s in (-1, 1):
        x = s * (S.GAUGE / 2 + 0.03)
        rod = B.box("rod", (0.01, 0.5, 0.018), (x, 0, wr - 0.03), "steel", bev=0.004)
        parts.append(rod)
        for y in axles:
            parts.append(B.cyl("pin", 0.01, 0.016, (x - s * 0.002, y, wr - 0.03), "steel", verts=12, axis="X"))
    # Burun (uzun kaput) önde (-Y)
    hood_y0, hood_y1 = -hl + 0.03, 0.06
    hood_w = 0.34
    hz0, hz1 = 0.172, 0.345
    hood_len = hood_y1 - hood_y0
    hood = prism_y("hood", B.rounded_rect(hood_w, hz1 - hz0, 0.045, 8), hood_len, "loco_body", bev=0.02,
                   y=(hood_y0 + hood_y1) / 2)
    hood.location = (0, 0, (hz0 + hz1) / 2)
    B.apply_transform(hood)
    parts.append(hood)
    # Panjurlar (kaput yanlarında ince koyu yuvalar)
    for s in (-1, 1):
        for i in range(6):
            y = hood_y0 + 0.07 + i * 0.035
            parts.append(B.box("louvre", (0.006, 0.02, 0.09), (s * (hood_w / 2 + 0.0005), y, (hz0 + hz1) / 2 + 0.01),
                               "stripe_dark", bev=0.003))
        # Kapı tutamakları
        parts.append(B.box("hood_door", (0.004, 0.16, 0.12), (s * (hood_w / 2 + 0.001), hood_y0 + 0.2,
                                                              (hz0 + hz1) / 2 - 0.005), "loco_body", bev=0.003))
    # Radyatör ızgarası (ön yüz)
    parts.append(B.box("grille_frame", (0.22, 0.008, 0.12), (0, hood_y0 - 0.002, (hz0 + hz1) / 2 + 0.005),
                       "stripe_dark", bev=0.004))
    for k in range(6):
        parts.append(B.box("grille_slat", (0.2, 0.008, 0.008), (0, hood_y0 - 0.006, hz0 + 0.04 + k * 0.018), "steel_dark",
                           bev=0.003))
    # Kaput tepesindeki sarı uyarı bandı (yukarıdan "ön"ü gösterir)
    parts.append(B.box("nose_band", (hood_w - 0.06, 0.05, 0.006), (0, hood_y0 + 0.04, hz1 + 0.002), "stripe_yellow",
                       bev=0.0025))
    # Egzoz, kum kutuları, tepe farı
    parts.append(B.lathe("stack", [(0.0, 0.0), (0.022, 0.0), (0.022, 0.05), (0.026, 0.056), (0.018, 0.06),
                                   (0.0, 0.058)], (0, hood_y0 + 0.17, hz1 - 0.004), "stripe_dark", verts=24))
    parts.append(B.box("vent", (0.14, 0.09, 0.016), (0, hood_y0 + 0.29, hz1 + 0.004), "loco_body", bev=0.006))
    for s in (-1, 1):
        parts.append(B.box("sandbox", (0.05, 0.06, 0.05), (s * (W / 2 - 0.04), hood_y0 + 0.03, 0.198), "loco_body",
                           bev=0.012))
    lamp_f = []
    # Farlar: ön yüzde iki alt + bir üst
    for x, z in ((-0.12, 0.215), (0.12, 0.215), (0.0, hz1 - 0.02)):
        parts.append(B.cyl("lamp_ring", 0.026, 0.02, (0, 0, 0), "stripe_dark", verts=24, axis="Y", bev=0.004))
        parts[-1].location = (x, hood_y0 - 0.016, z)
        B.apply_transform(parts[-1])
        lf = B.lathe("lamp", [(0.0, 0.0), (0.019, 0.0), (0.019, 0.004), (0.0, 0.010)], (0, 0, 0), "lamp_front",
                     verts=24, axis="Y")
        lf.data.transform(Matrix.Rotation(math.pi, 4, "Z"))
        lf.location = (x, hood_y0 - 0.016, z)
        B.apply_transform(lf)
        lamp_f.append(lf)
    # Kabin (arka)
    cab_y0, cab_y1 = 0.065, hl - 0.03
    cw = W - 0.02
    cz0, cz1 = 0.172, 0.43
    cab_len = cab_y1 - cab_y0
    cab = prism_y("cab", B.rounded_rect(cw, cz1 - cz0, 0.03, 8), cab_len, "loco_cab", bev=0.012, y=(cab_y0 + cab_y1) / 2)
    cab.location = (0, 0, (cz0 + cz1) / 2)
    B.apply_transform(cab)
    parts.append(cab)
    # Alt kuşak (gövde rengi)
    parts.append(B.box("cab_skirt", (cw + 0.006, cab_len + 0.006, 0.05), (0, (cab_y0 + cab_y1) / 2, cz0 + 0.024),
                       "loco_body", bev=0.01))
    glass = []
    wz0, wz1 = 0.29, 0.395
    # Ön camlar (kaputa bakan): iki adet
    for x in (-0.11, 0.11):
        g = B.box("win", (0.15, 0.008, wz1 - wz0), (x, cab_y0 - 0.002, (wz0 + wz1) / 2), "glass", bev=0.008)
        glass.append(g)
    for x in (-0.11, 0.11):
        g = B.box("win_r", (0.15, 0.008, wz1 - wz0), (x, cab_y1 + 0.002, (wz0 + wz1) / 2), "glass", bev=0.008)
        glass.append(g)
    for s in (-1, 1):
        g = B.box("win_s", (0.008, cab_len - 0.08, wz1 - wz0), (s * (cw / 2 + 0.002), (cab_y0 + cab_y1) / 2,
                                                               (wz0 + wz1) / 2), "glass", bev=0.008)
        glass.append(g)
        # Kabin kapısı çizgisi ve tutamak
        parts.append(B.sweep("grab", [(s * (cw / 2 + 0.012), cab_y0 + 0.02, 0.2), (s * (cw / 2 + 0.014), cab_y0 + 0.02,
                                                                                   0.36)], 0.005, "stripe_yellow",
                             sides=8))
        parts.append(B.sweep("grab", [(s * (cw / 2 + 0.012), cab_y1 - 0.02, 0.2), (s * (cw / 2 + 0.014), cab_y1 - 0.02,
                                                                                   0.36)], 0.005, "stripe_yellow",
                             sides=8))
    # Çatı (krem, taşmalı, yuvarlak omuz)
    roof = prism_y("cab_roof", roof_profile(cw + 0.04, cz1 - 0.004, 0.026, 0.24, 0.012), cab_len + 0.04, "cream",
                   bev=0.006, y=(cab_y0 + cab_y1) / 2)
    parts.append(roof)
    top_z = cz1 - 0.004 + 0.012 + 0.026
    # Çatı üstü: korna + ışıklı tepe lambası (yön değil, karakter)
    parts.append(B.cyl("horn", 0.012, 0.05, (0, 0, 0), "steel", verts=16, axis="Y", bev=0.003))
    parts[-1].location = (0.08, cab_y0 + 0.03, top_z + 0.01)
    B.apply_transform(parts[-1])
    parts.append(B.lathe("beacon", [(0.0, 0.0), (0.02, 0.0), (0.02, 0.008), (0.016, 0.026), (0.0, 0.03)],
                         (-0.05, (cab_y0 + cab_y1) / 2 + 0.02, top_z - 0.004), "stripe_yellow", verts=24))
    # Korkuluklar: kaput boyunca sarı tüp + direkler
    for s in (-1, 1):
        x = s * (W / 2 - 0.012)
        pts = [(x, hood_y0 + 0.01, 0.30), (x, cab_y0 - 0.03, 0.30)]
        parts.append(B.sweep("handrail", pts, 0.0065, "stripe_yellow", sides=10))
        for y in (hood_y0 + 0.01, (hood_y0 + cab_y0) / 2 - 0.015, cab_y0 - 0.03):
            parts.append(B.cyl("stanchion", 0.0055, 0.135, (x, y, 0.168), "stripe_yellow", verts=10))
        # Ön basamak korkuluğu (uçta kıvrık)
        parts.append(B.sweep("front_rail", [(x, hood_y0 + 0.01, 0.30), (x * 0.9, -hl + 0.005, 0.30),
                                            (x * 0.9, -hl + 0.005, 0.18)], 0.0065, "stripe_yellow", sides=10))
        # Basamaklar
        for e in (-1, 1):
            parts.append(B.box("step", (0.04, 0.05, 0.008), (x + s * 0.008, e * (hl - 0.05), 0.12), "frame_dark",
                               bev=0.003))
    # Arka lambalar (kırmızı, sönük): yön ipucu
    lamp_r = []
    for x in (-0.15, 0.15):
        parts.append(B.cyl("rlamp_ring", 0.02, 0.016, (0, 0, 0), "stripe_dark", verts=20, axis="Y", bev=0.003))
        parts[-1].location = (x, cab_y1 - 0.006, 0.25)
        B.apply_transform(parts[-1])
        lr = B.lathe("rlamp", [(0.0, 0.0), (0.014, 0.0), (0.014, 0.003), (0.0, 0.008)], (x, cab_y1 + 0.01, 0.25),
                     "lamp_rear", verts=20, axis="Y")
        lamp_r.append(lr)
    return parts + glass + lamp_f + lamp_r, top_z


# ---------------------------------------------------------------- derleme

def finish_vehicle(name, parts, syms, top_z):
    meshes = [p for p in parts if p is not None and p.type == "MESH"]
    body = B.join(meshes, "Body")
    tris = B.tri_count([body])
    if not NO_BAKE:
        # Simgeler pişirmede gölge versin diye geçici olarak sahnede kalır.
        B.bake_vertex_ao([body], samples=64, distance=0.12, strength=0.8)
    else:
        B.ensure_white_vcol([body])
    B.collapse_materials([body])
    root = B.empty(name, size=0.2)
    body.parent = root
    for sy in syms:
        sy.parent = root
    # Bağlantı noktaları (Godot: ön +Z = Blender -Y)
    B.empty("CouplerFront", (0, -S.COUPLER_Z, S.BUFFER_Y), parent=root)
    B.empty("CouplerRear", (0, S.COUPLER_Z, S.BUFFER_Y), parent=root)
    B.empty("RoofTop", (0, 0, top_z), parent=root)
    objs = [root, body] + syms + [c for c in root.children if c.type == "EMPTY"]
    path = os.path.join(OUT, f"{name}.glb")
    B.export_glb(path, objs)
    sym_tris = sum(B.tri_count([s]) for s in syms) // max(1, len(syms))
    print(f"  üçgen {name}: gövde {tris} + simge {sym_tris}")


BUILDERS = {
    "wagon_box": body_box_van,
    "wagon_tank": body_tank,
    "wagon_hopper": body_hopper,
    "wagon_container": body_container,
    "wagon_glass": body_glass,
    "wagon_heavy": body_heavy,
}


def main():
    os.makedirs(OUT, exist_ok=True)
    if ONLY is None or "loco" in ONLY:
        B.reset()
        parts, top_z = loco()
        finish_vehicle("loco", parts, [], top_z)
    for name, fn in BUILDERS.items():
        if ONLY is not None and name not in ONLY and name.replace("wagon_", "") not in ONLY:
            continue
        B.reset()
        parts, syms, top_z = fn()
        finish_vehicle(name, parts, syms, top_z)


main()
