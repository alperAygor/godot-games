#!/usr/bin/env python3
"""MikroKurye — FAZ 10 (F10.2): BÖLGE EŞYALARI — 3D modeller (Blender 5.2, headless).

Tek betikten, idempotent. Kaynak = bu betik; GLB'ler üretilmiş çıktıdır.

    /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/make_zone_props_v3.py

İstenirse tek model yeniden üretilir (hata ayıklama):

    ... -b -P tools/blender/make_zone_props_v3.py -- zone_kitchen_teapot

Sözleşme (studio-kit/tools/validate_glb.py + görev):
  * tek mesh, transformlar uygulanmış -> node'da TRS yok
  * origin ALT-MERKEZ (min Y = 0, X/Z merkez = 0), 1 birim = 1 metre
  * Blender +Y = robotun ÖNÜ (yüz/ön detay +Y tarafında)
  * pürüzsüz gölgeleme: bevel + shade_auto_smooth + vertex-renk "Col" taban AO gradyanı
  * İSİMLİ malzeme slotları (entegrasyonda toon malzemeyle eşlenecek):
      "base"   — ana gövde
      "accent" — ikincil renk / detay
      "glow"   — parlak/özel parça (lamba, alev, ekran) — emissive
    BAŞKA İSİM KULLANILMAZ.
  * Tris ≤ 2500/model.

Ölçek hissi: robot ~0.8 m; bölge eşyaları robota göre dev (v2 masa eşyalarıyla aynı).
"""

import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

# ---------------------------------------------------------------------------
# studio-kit'i worktree konumundan bağımsız bul
# ---------------------------------------------------------------------------
PROJECT_ROOT = Path(__file__).resolve().parents[2]


def _find_kit() -> Path:
    for parent in (PROJECT_ROOT, *PROJECT_ROOT.parents):
        candidate = parent / "studio-kit" / "tools"
        if (candidate / "blender_kit.py").is_file():
            return candidate
    raise RuntimeError("studio-kit/tools/blender_kit.py bulunamadı")


sys.path.insert(0, str(_find_kit()))
import blender_kit as kit  # noqa: E402


# ---------------------------------------------------------------------------
# bölge paletleri (data/zones.json + görevdeki renk tarifi)
# ---------------------------------------------------------------------------
# kitchen: açık gri-mavi / beyaz / nane
K_BLUE = "#A8C4DC"
K_WHITE = "#F4FAFF"
K_MINT = "#7FD8BE"
K_MINT_DARK = "#5FBFA6"
K_WOOD = "#E8D5B0"      # kesme tahtası (açık nötr ahşap)

# library: sıcak kahve / koyu yeşil / altın
L_BROWN = "#8A5A38"
L_BROWN_DARK = "#5E3A20"
L_GREEN = "#3E5C43"
L_GOLD = "#E3B64B"
L_CREAM = "#F2D8AE"

# night: lacivert / mor / sarı-glow
N_NAVY = "#2B345C"
N_NAVY_DARK = "#1B2347"
N_PURPLE = "#7A5C9E"
N_GLOW = "#FFE27A"
N_MOON = "#EFE9C8"

# pastel: pembe / mint / sarı
P_PINK = "#F2A9BE"
P_MINT = "#A8E0C8"
P_YELLOW = "#FFE08A"
P_CREAM = "#FFF0F5"


# ---------------------------------------------------------------------------
# yardımcılar — blender_kit primitiflerini tamamlar
# ---------------------------------------------------------------------------
def _srgb_to_linear(channel: float) -> float:
    return channel / 12.92 if channel <= 0.04045 else ((channel + 0.055) / 1.055) ** 2.4


def _lin(hex_color: str):
    value = hex_color.lstrip("#")
    return tuple(_srgb_to_linear(int(value[i:i + 2], 16) / 255.0) for i in (0, 2, 4))


def base(color, roughness=0.5, metallic=0.0):
    return kit.material("base", color, roughness=roughness, metallic=metallic)


def accent(color, roughness=0.5, metallic=0.0):
    return kit.material("accent", color, roughness=roughness, metallic=metallic)


def glow(color, strength=3.2, roughness=0.4):
    """Parlayan yüzey (alev/ekran/lamba). EmissiveFactor GLB'ye yazılır."""
    existing = bpy.data.materials.get("glow")
    if existing is not None:
        return existing
    m = bpy.data.materials.new("glow")
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    linear = _lin(color)
    bsdf.inputs["Base Color"].default_value = (*linear, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Emission Color"].default_value = (*linear, 1.0)
    bsdf.inputs["Emission Strength"].default_value = strength
    m.diffuse_color = (*linear, 1.0)
    return m


def add_torus(name, major_r, tube_r, location, m, rotation=(0.0, 0.0, 0.0),
              major_seg=26, minor_seg=7):
    bpy.ops.mesh.primitive_torus_add(major_radius=major_r, minor_radius=tube_r,
                                     major_segments=major_seg, minor_segments=minor_seg,
                                     location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    kit.activate(obj)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    obj.data.materials.append(m)
    return obj


def add_cone(name, r1, r2, depth, location, m, vertices=20,
             rotation=(0.0, 0.0, 0.0), bevel_width=0.0):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=r1, radius2=r2,
                                    depth=depth, location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    kit.activate(obj)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    kit.bevel(obj, bevel_width, 1)
    obj.data.materials.append(m)
    return obj


def add_ico(name, radius, location, m, subdivisions=1):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=radius,
                                          location=location)
    obj = bpy.context.active_object
    obj.name = name
    kit.activate(obj)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    obj.data.materials.append(m)
    return obj


def add_sphere(name, radius, location, m, segments=24, rings=12):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings,
                                         radius=radius, location=location)
    obj = bpy.context.active_object
    obj.name = name
    kit.activate(obj)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    obj.data.materials.append(m)
    return obj


def add_sphere_s(name, radius, scale, location, m, segments=24, rings=12):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings,
                                         radius=radius, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    kit.activate(obj)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    obj.data.materials.append(m)
    return obj


def add_box_rot(name, size, location, m, rotation=(0.0, 0.0, 0.0),
                bevel_width=0.0, segments=2):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    kit.activate(obj)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    kit.bevel(obj, bevel_width, segments)
    obj.data.materials.append(m)
    return obj


def add_star(name, radius, thickness, location, m, points=5):
    """Yassı 5 köşeli yıldız (fan-üçgenleme; içbükeylik güvenli). XY düzlemi, Z kalınlık."""
    import bmesh
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    outer_r = radius
    inner_r = radius * 0.44
    n = points
    c_top = bm.verts.new((0.0, 0.0, thickness / 2.0))
    c_bot = bm.verts.new((0.0, 0.0, -thickness / 2.0))
    rim_top = []
    rim_bot = []
    for i in range(2 * n):
        ang = math.pi / 2.0 + i * math.pi / n
        r = outer_r if i % 2 == 0 else inner_r
        x = math.cos(ang) * r
        y = math.sin(ang) * r
        rim_top.append(bm.verts.new((x, y, thickness / 2.0)))
        rim_bot.append(bm.verts.new((x, y, -thickness / 2.0)))
    bm.verts.ensure_lookup_table()
    for i in range(2 * n):
        j = (i + 1) % (2 * n)
        bm.faces.new((c_top, rim_top[i], rim_top[j]))
        bm.faces.new((c_bot, rim_bot[j], rim_bot[i]))
        bm.faces.new((rim_top[i], rim_top[j], rim_bot[j], rim_bot[i]))
    bm.normal_update()
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.location = location
    kit.activate(obj)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(m)
    return obj


def add_letter(name, char, height, thickness, location, m):
    """Blender metin nesnesi -> mesh; +Y yüzüne bakan, dik kabartma harf."""
    curve = bpy.data.curves.new(name + "_c", "FONT")
    curve.body = char
    curve.size = 1.0
    curve.extrude = thickness
    curve.align_x = "CENTER"
    curve.align_y = "CENTER"
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    kit.activate(obj)
    bpy.ops.object.convert(target="MESH")
    obj = bpy.context.active_object
    # metnin +Z (yüz) -> dünya +Y (ön), +Y (yukarı) -> dünya +Z
    obj.rotation_euler = Vector((0.0, 1.0, 0.0)).to_track_quat("Z", "Y").to_euler()
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    (min_x, min_y, min_z), (max_x, max_y, max_z) = kit.bounds(obj)
    h = max_z - min_z
    if h > 1e-6:
        s = height / h
        obj.scale = (s, s, s)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.location = location
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
    obj.data.materials.append(m)
    return obj


def add_ao(obj, strength=0.24, floor_power=1.5):
    """Taban temas AO'su: alt kenara doğru yumuşak kararma (COLOR_0)."""
    mesh = obj.data
    attr = mesh.color_attributes.new(name="Col", type="FLOAT_COLOR", domain="POINT")
    zs = [v.co.z for v in mesh.vertices]
    zmin, zmax = min(zs), max(zs)
    span = (zmax - zmin) if (zmax - zmin) > 1e-6 else 1.0
    for v in mesh.vertices:
        t = max(0.0, min(1.0, (v.co.z - zmin) / span))
        shade = 1.0 - strength * (1.0 - t) ** floor_power
        attr.data[v.index].color = (shade, shade, shade, 1.0)
    mesh.update()


def finalize(obj, name, smooth_angle=58.0, ao=True):
    kit.activate(obj)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.shade_auto_smooth(angle=math.radians(smooth_angle))
    for modifier in list(obj.modifiers):
        if modifier.type == "NODES":  # "Smooth by Angle"
            bpy.ops.object.modifier_apply(modifier=modifier.name)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True

    (min_x, min_y, min_z), (max_x, max_y, _max_z) = kit.bounds(obj)
    obj.data.transform(Matrix.Translation((-(min_x + max_x) / 2.0,
                                           -(min_y + max_y) / 2.0,
                                           -min_z)))
    obj.data.update()
    obj.location = (0.0, 0.0, 0.0)
    obj.rotation_euler = (0.0, 0.0, 0.0)
    obj.scale = (1.0, 1.0, 1.0)
    obj.name = name
    obj.data.name = name
    if ao:
        add_ao(obj)
    return obj


def build(name, parts, ao=True, smooth_angle=58.0):
    obj = kit.join(parts, name)
    return finalize(obj, name, smooth_angle=smooth_angle, ao=ao)


def export(obj, path):
    kit.export_glb(obj, str(path), extra={"export_vertex_color": "ACTIVE"})


# ---------------------------------------------------------------------------
# A) KITCHEN — açık gri-mavi / beyaz / nane
# ---------------------------------------------------------------------------
def build_teapot():
    b = base(K_MINT)
    a = accent(K_WHITE)
    parts = [
        # gövde: hafif basık küre + geniş taban bileziği
        add_sphere_s("Body", 1.05, (1.0, 1.0, 0.78), (0.0, 0.0, 1.0), b, 30, 16),
        kit.cylinder("Foot", 0.62, 0.2, (0.0, 0.0, 0.1), a, vertices=24),
        # kapak + topuz
        kit.cylinder("Lid", 0.6, 0.16, (0.0, 0.0, 1.9), a, vertices=24),
        add_sphere("Knob", 0.15, (0.0, 0.0, 2.04), a, segments=18, rings=10),
    ]
    # ağız (ön, +Y)
    parts.append(add_cone("Spout", 0.17, 0.05, 0.75, (0.0, 1.1, 1.15), b,
                          vertices=16, rotation=(math.radians(76.0), 0.0, 0.0)))
    # kulp (arkada, -Y)
    parts.append(add_torus("Handle", 0.52, 0.095, (0.0, -0.9, 1.2), b,
                           rotation=(math.radians(90.0), 0.0, 0.0), major_seg=22, minor_seg=7))
    return build("zone_kitchen_teapot", parts)


def build_jar():
    b = base(K_BLUE)
    a = accent(K_MINT)
    body = kit.cylinder("Body", 0.8, 2.0, (0.0, 0.0, 1.0), b, vertices=28)
    kit.bevel(body, 0.05, 2)
    parts = [
        body,
        add_torus("Neck", 0.68, 0.08, (0.0, 0.0, 2.02), a, major_seg=24, minor_seg=7),
        kit.cylinder("Lid", 0.82, 0.14, (0.0, 0.0, 2.16), a, vertices=28),
        kit.cylinder("Knob", 0.2, 0.16, (0.0, 0.0, 2.3), a, vertices=18),
    ]
    # ön yüz (+Y) etiket
    parts.append(kit.cylinder("Label", 0.62, 0.28, (0.0, 0.82, 1.15), a,
                              vertices=24, rotation=(math.radians(90.0), 0.0, 0.0)))
    return build("zone_kitchen_jar", parts)


def build_plate_stack():
    b = base(K_WHITE)
    a = accent(K_MINT)
    parts = []
    radii = [1.3, 1.3, 1.3]
    zs = [0.06, 0.2, 0.34]
    for i, (r, z) in enumerate(zip(radii, zs)):
        plate = kit.cylinder("Plate%d" % i, r, 0.1, (0.0, 0.0, z), b, vertices=32)
        kit.bevel(plate, 0.03, 2)
        parts.append(plate)
        parts.append(kit.cylinder("PlateRim%d" % i, r - 0.06, 0.02, (0.0, 0.0, z + 0.055), b,
                                  vertices=32))
    # en üst tabağın ortasına nane süsleme
    parts.append(kit.cylinder("Deco", 0.5, 0.014, (0.0, 0.0, 0.40), a, vertices=24))
    return build("zone_kitchen_plate_stack", parts)


def build_cutting_board():
    b = base(K_WOOD, roughness=0.6)
    a = accent(K_MINT)
    parts = [
        kit.box_bounds("Board", -2.0, 2.0, -1.3, 1.3, 0.0, 0.25, b, 0.06, 2),
    ]
    # asma deliği (ön kenarda, +Y)
    parts.append(kit.cylinder("Hole", 0.16, 0.1, (1.55, 0.9, 0.125), a, vertices=16))
    # meyve suyu oluğu (kenar boyunca ince şerit)
    parts.append(kit.box_bounds("Groove", -1.7, 1.7, 0.95, 1.05, 0.25, 0.256, a, 0.004, 1))
    return build("zone_kitchen_cutting_board", parts)


# ---------------------------------------------------------------------------
# B) LIBRARY — sıcak kahve / koyu yeşil / altın
# ---------------------------------------------------------------------------
def build_globe():
    b = base(L_GREEN)
    a = accent(L_GOLD, metallic=0.35)
    parts = [
        add_sphere("Globe", 0.95, (0.0, 0.0, 1.45), b, segments=30, rings=16),
        add_torus("Ring", 1.0, 0.055, (0.0, 0.0, 1.45), a,
                  rotation=(math.radians(90.0), 0.0, math.radians(23.4)),
                  major_seg=30, minor_seg=7),
    ]
    # eksen (küre içinden geçen ince mil)
    parts.append(kit.cylinder("Axis", 0.05, 2.3, (0.0, 0.0, 1.45), a, vertices=12,
                              rotation=(math.radians(90.0), 0.0, math.radians(23.4))))
    # ayak: sütun + genişleyen taban
    parts.append(kit.cylinder("Column", 0.18, 0.55, (0.0, 0.0, 0.27), a, vertices=20))
    parts.append(add_cone("Base", 0.42, 0.26, 0.16, (0.0, 0.0, 0.08), a,
                          vertices=24, bevel_width=0.02))
    parts.append(kit.cylinder("BaseDisc", 0.44, 0.06, (0.0, 0.0, 0.03), a, vertices=24))
    return build("zone_library_globe", parts)


def build_candle():
    b = base(L_CREAM)
    a = accent(L_GOLD, metallic=0.3)
    g = glow(N_GLOW, strength=4.0)
    wax = kit.cylinder("Wax", 0.34, 1.0, (0.0, 0.0, 0.8), b, vertices=24)
    kit.bevel(wax, 0.03, 2)
    parts = [
        # mum gövdesi + üstte eriyik halka
        wax,
        add_torus("Melt", 0.3, 0.06, (0.0, 0.0, 1.3), b, major_seg=22, minor_seg=6),
        # şamdan: taban + sütun + mumluk
        kit.cylinder("HolderBase", 0.5, 0.1, (0.0, 0.0, 0.05), a, vertices=24),
        kit.cylinder("Stem", 0.14, 0.28, (0.0, 0.0, 0.24), a, vertices=16),
        kit.cylinder("Cup", 0.42, 0.2, (0.0, 0.0, 0.48), a, vertices=24),
        # fitil + alev (glow)
        kit.cylinder("Wick", 0.03, 0.16, (0.0, 0.0, 1.44), a, vertices=8),
        add_sphere_s("Flame", 0.15, (0.85, 0.85, 1.5), (0.0, 0.0, 1.66), g, 20, 10),
    ]
    return build("zone_library_candle", parts)


def build_book_tower():
    b = base(L_BROWN)
    a = accent(L_CREAM)
    parts = []
    book_w = 2.3
    book_l = 3.0
    book_h = 0.5
    y_offsets = [0.0, -0.1, 0.08, -0.06, 0.12, 0.0]
    rots = [-2.0, 3.0, -1.5, 2.5, -2.5, 1.0]
    for i in range(6):
        hw, hl = book_w / 2.0, book_l / 2.0
        z0 = i * book_h
        y0 = y_offsets[i]
        rot = math.radians(rots[i])
        # kapak (ön kısım, +Y) + sayfa bloğu (arka kısım)
        parts.append(add_box_rot("Book%dCover" % i, (book_w * 0.6, book_l, book_h),
                                 (0.0, y0 - hl * 0.2, z0 + book_h / 2.0), b,
                                 rotation=(0.0, 0.0, rot), bevel_width=0.03, segments=2))
        parts.append(add_box_rot("Book%dPages" % i, (book_w * 0.4, book_l - 0.08, book_h * 0.92),
                                 (0.0, y0 + hl * 0.3, z0 + book_h / 2.0), a,
                                 rotation=(0.0, 0.0, rot), bevel_width=0.01, segments=1))
    return build("zone_library_book_tower", parts)


def build_hourglass():
    b = base(L_GOLD, metallic=0.3)
    a = accent(L_CREAM)
    parts = [
        # üst + alt disk
        kit.cylinder("TopDisc", 0.5, 0.1, (0.0, 0.0, 2.1), b, vertices=28),
        kit.cylinder("BottomDisc", 0.5, 0.1, (0.0, 0.0, 0.05), b, vertices=28),
        # sütunlar (3 adet)
    ]
    for i in range(3):
        ang = 2.0 * math.pi * i / 3.0
        x = math.cos(ang) * 0.42
        y = math.sin(ang) * 0.42
        parts.append(kit.cylinder("Pillar%d" % i, 0.06, 2.1, (x, y, 1.1), b, vertices=12))
    # cam ampuller (üst + alt) — üstte dar boğaz
    parts.append(add_sphere_s("GlassTop", 0.52, (1.0, 1.0, 0.85), (0.0, 0.0, 1.85), a, 24, 12))
    parts.append(add_sphere_s("GlassBot", 0.52, (1.0, 1.0, 0.85), (0.0, 0.0, 0.3), a, 24, 12))
    # kum: alt ampulde tepe + düşen ince akış
    parts.append(add_cone("SandPile", 0.4, 0.0, 0.34, (0.0, 0.0, 0.22), b, vertices=20))
    parts.append(kit.cylinder("SandFlow", 0.06, 0.7, (0.0, 0.0, 1.45), b, vertices=12))
    return build("zone_library_hourglass", parts)


# ---------------------------------------------------------------------------
# C) NIGHT — lacivert / mor / sarı-glow
# ---------------------------------------------------------------------------
def build_alarm_clock():
    b = base(N_NAVY)
    a = accent(N_PURPLE)
    g = glow(N_GLOW, strength=2.6)
    leg_h = 0.18
    body_r = 0.72
    body_z = leg_h + body_r  # 0.90
    body = kit.cylinder("Body", body_r, 0.5, (0.0, 0.0, body_z), b, vertices=30,
                        rotation=(math.radians(90.0), 0.0, 0.0))
    kit.bevel(body, 0.04, 2)
    parts = [
        # gövde (ön +Y)
        body,
        # ayaklar (gövdenin altında, yere basar)
        kit.box_bounds("LegL", -0.55, -0.25, -0.22, 0.22, 0.0, leg_h, a, 0.02, 2),
        kit.box_bounds("LegR", 0.25, 0.55, -0.22, 0.22, 0.0, leg_h, a, 0.02, 2),
    ]
    # çanlar (üstte iki kubbe)
    bell_z = body_z + body_r - 0.1  # 1.52
    for sx in (-0.34, 0.34):
        parts.append(add_sphere("Bell%+.0f" % sx, 0.22, (sx, 0.0, bell_z), b, 20, 12))
        parts.append(kit.cylinder("BellCap%+.0f" % sx, 0.1, 0.08, (sx, 0.0, bell_z + 0.2), a, 14))
    # kadran (glow, ön +Y)
    parts.append(kit.cylinder("Dial", 0.58, 0.02, (0.0, 0.27, body_z), g, vertices=30,
                              rotation=(math.radians(90.0), 0.0, 0.0)))
    # akrep + yelkovan
    parts.append(kit.box_bounds("Hour", -0.02, 0.02, 0.26, 0.55, body_z - 0.02, body_z + 0.02,
                                a, 0.004, 1))
    parts.append(kit.box_bounds("Minute", -0.015, 0.015, 0.26, 0.72, body_z + 0.0, body_z + 0.04,
                                a, 0.003, 1))
    return build("zone_night_alarm_clock", parts)


def build_moon_lamp():
    b = base(N_NAVY)
    a = accent(N_PURPLE)
    g = glow(N_GLOW, strength=3.0)
    parts = [
        kit.cylinder("Base", 0.5, 0.12, (0.0, 0.0, 0.06), b, vertices=24),
        kit.cylinder("Stem", 0.12, 0.5, (0.0, 0.0, 0.36), b, vertices=16),
        kit.cylinder("Neck", 0.1, 0.2, (0.0, 0.0, 0.7), b, vertices=16),
    ]
    # ay küresi (glow) + kraterler (accent)
    parts.append(add_sphere("Moon", 0.62, (0.0, 0.0, 1.45), g, segments=28, rings=14))
    for (cx, cz, r) in ((0.2, 1.55, 0.12), (-0.18, 1.35, 0.09), (0.05, 1.15, 0.07)):
        parts.append(add_sphere_s("Crater", r, (0.8, 0.8, 0.5), (cx, 0.55, cz), a, 14, 8))
    return build("zone_night_moon_lamp", parts)


def build_plush():
    b = base(N_PURPLE)
    a = accent(N_MOON)
    parts = [
        # gövde + kafa
        add_sphere_s("Body", 0.75, (1.0, 0.9, 1.1), (0.0, 0.0, 0.85), b, 20, 10),
        add_sphere("Head", 0.55, (0.0, 0.0, 1.95), b, 20, 10),
        # kulaklar
        add_sphere("EarL", 0.24, (-0.42, 0.0, 2.45), b, 14, 8),
        add_sphere("EarR", 0.24, (0.42, 0.0, 2.45), b, 14, 8),
        add_sphere_s("EarLIn", 0.12, (1.0, 1.0, 0.6), (-0.42, 0.12, 2.48), a, 10, 6),
        add_sphere_s("EarRIn", 0.12, (1.0, 1.0, 0.6), (0.42, 0.12, 2.48), a, 10, 6),
        # kollar + bacaklar
        add_sphere_s("ArmL", 0.22, (1.0, 1.0, 1.3), (-0.62, 0.0, 1.1), b, 12, 7),
        add_sphere_s("ArmR", 0.22, (1.0, 1.0, 1.3), (0.62, 0.0, 1.1), b, 12, 7),
        add_sphere_s("LegL", 0.26, (1.0, 1.0, 0.9), (-0.32, 0.0, 0.28), b, 12, 7),
        add_sphere_s("LegR", 0.26, (1.0, 1.0, 0.9), (0.32, 0.0, 0.28), b, 12, 7),
    ]
    # ağız (ön +Y) + burun + karın
    parts.append(add_sphere_s("Muzzle", 0.24, (1.0, 1.0, 0.7), (0.0, 0.42, 1.9), a, 12, 7))
    parts.append(add_sphere("Nose", 0.09, (0.0, 0.62, 1.95), a, 10, 6))
    parts.append(add_sphere_s("Belly", 0.34, (1.0, 0.6, 1.0), (0.0, 0.5, 0.9), a, 12, 7))
    return build("zone_night_plush", parts)


def build_stars_mobile():
    b = base(N_NAVY)
    a = accent(N_PURPLE)
    g = glow(N_GLOW, strength=3.4)
    parts = [
        # taban + direk + yatay kol
        kit.cylinder("Base", 0.55, 0.12, (0.0, 0.0, 0.06), b, vertices=24),
        kit.cylinder("Pole", 0.08, 2.4, (0.0, 0.0, 1.3), b, vertices=16),
        kit.cylinder("Arm", 0.06, 2.0, (0.0, 0.0, 2.5), b, vertices=14,
                     rotation=(math.radians(90.0), 0.0, 0.0)),
        add_sphere("Finial", 0.12, (0.0, 0.0, 2.62), a, 14, 8),
    ]
    # asılı yıldızlar + ipler
    hangs = [(-0.75, 0.42, 0.85), (0.0, 0.55, 1.15), (0.7, 0.3, 0.6)]
    for i, (hx, z0, zlen) in enumerate(hangs):
        # ip (ince silindir, accent)
        parts.append(kit.cylinder("String%d" % i, 0.02, zlen, (hx, 0.0, 2.48 - zlen / 2.0), a,
                                  vertices=8))
        parts.append(add_star("Star%d" % i, 0.2, 0.06, (hx, 0.0, 2.48 - zlen - 0.1), g))
    return build("zone_night_stars_mobile", parts)


# ---------------------------------------------------------------------------
# D) PASTEL — pembe / mint / sarı
# ---------------------------------------------------------------------------
def build_blocks():
    b = base(P_PINK)
    a = accent(P_MINT)
    size = 0.95
    half = size / 2.0
    # alt iki blok (pembe) + üst blok (mint, hafif öne kaydırılmış)
    blocks = [
        ("BlockL", (-half - 0.05, 0.0, half), b),
        ("BlockR", (half + 0.05, 0.0, half), b),
        ("BlockTop", (0.0, 0.14, size * 1.5), a),
    ]
    parts = []
    for name, loc, m in blocks:
        parts.append(add_box_rot(name, (size, size, size), loc, m,
                                 bevel_width=0.05, segments=2))
    # harfler: her bloğun +Y (ön) yüzüne zıt renkte kabartma
    letters = [
        ("A", blocks[0][1], a),
        ("M", blocks[1][1], a),
        ("O", blocks[2][1], b),
    ]
    for i, (ch, (bx, by, bz), m) in enumerate(letters):
        letter = add_letter("Letter%d" % i, ch, 0.5, 0.05, (0.0, 0.0, 0.0), m)
        letter.location = (bx, by + half, bz)
        bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
        parts.append(letter)
    return build("zone_pastel_blocks", parts)


def build_duck():
    b = base(P_YELLOW)
    a = accent("#F2A65A")  # turuncu gaga (pastel uyumlu)
    parts = [
        # gövde (yassı küre) + kafa
        add_sphere_s("Body", 0.7, (1.0, 0.85, 0.8), (0.0, 0.0, 0.55), b, 26, 14),
        add_sphere("Head", 0.45, (0.0, 0.1, 1.35), b, 24, 12),
        # kuyruk (arkada, -Y)
        add_cone("Tail", 0.22, 0.0, 0.4, (0.0, -0.72, 0.75), b,
                 vertices=14, rotation=(math.radians(105.0), 0.0, 0.0)),
        # kanat
        add_sphere_s("Wing", 0.3, (0.9, 0.5, 1.0), (0.0, 0.42, 0.55), a, 16, 9),
        # gaga (ön +Y)
        add_cone("Beak", 0.16, 0.0, 0.3, (0.0, 0.55, 1.3), a,
                 vertices=12, rotation=(math.radians(-90.0), 0.0, 0.0)),
        # göz (küçük)
        add_sphere("Eye", 0.07, (0.0, 0.5, 1.5), a, 12, 7),
    ]
    return build("zone_pastel_duck", parts)


def build_balloon():
    b = base(P_PINK)
    a = accent(P_MINT)
    parts = [
        # balon + düğüm
        add_sphere_s("Balloon", 0.82, (1.0, 1.0, 1.15), (0.0, 0.0, 2.25), b, 28, 14),
        add_cone("Knot", 0.14, 0.0, 0.24, (0.0, 0.0, 1.4), b, vertices=14,
                 rotation=(math.radians(180.0), 0.0, 0.0)),
        # ip (eğimli) + taban ağırlığı
        kit.cylinder("String", 0.025, 1.55, (0.0, 0.0, 0.78), a, vertices=8),
        kit.cylinder("Base", 0.28, 0.1, (0.0, 0.0, 0.05), a, vertices=20),
    ]
    return build("zone_pastel_balloon", parts)


def build_toy_train():
    b = base(P_PINK)
    a = accent(P_MINT)
    g = glow(P_YELLOW, strength=2.6)
    car_w = 1.3   # X genişlik
    car_l = 1.0   # Y uzunluk (yol yönü)
    car_h = 0.7
    wheel_r = 0.2
    parts = []

    def wheels(cx, cy, cz):
        for sx in (-0.38, 0.38):
            parts.append(kit.cylinder("Wheel", wheel_r, 0.14, (cx + sx, cy, cz), a,
                                      vertices=16, rotation=(math.radians(90.0), 0.0, 0.0)))

    # lokomotif (en ön, +Y)
    loc_y = 1.05
    parts.append(add_box_rot("LocoBody", (car_w, car_l, car_h), (0.0, loc_y, 0.45), b,
                             bevel_width=0.05, segments=2))
    parts.append(add_box_rot("LocoCab", (0.7, 0.5, 0.55), (0.0, loc_y - 0.1, 1.0), a,
                             bevel_width=0.04, segments=2))
    parts.append(kit.cylinder("Chimney", 0.14, 0.3, (0.0, loc_y + 0.1, 1.3), a, vertices=16))
    # ön far (glow, +Y)
    parts.append(kit.cylinder("Headlight", 0.12, 0.04, (0.0, loc_y + car_l / 2 + 0.02, 0.55), g,
                              vertices=16, rotation=(math.radians(90.0), 0.0, 0.0)))
    wheels(0.0, loc_y, 0.2)

    # vagon 1
    wag_y = 0.0
    parts.append(add_box_rot("Wagon1", (car_w, car_l, car_h * 0.8), (0.0, wag_y, 0.4), b,
                             bevel_width=0.05, segments=2))
    wheels(0.0, wag_y, 0.2)

    # vagon 2
    wag_y = -1.05
    parts.append(add_box_rot("Wagon2", (car_w, car_l, car_h * 0.8), (0.0, wag_y, 0.4), b,
                             bevel_width=0.05, segments=2))
    wheels(0.0, wag_y, 0.2)

    # bağlantı çubukları
    parts.append(kit.box_bounds("Coupling1", -0.1, 0.1, 0.55, 0.75, 0.3, 0.4, a, 0.02, 1))
    parts.append(kit.box_bounds("Coupling2", -0.1, 0.1, -0.75, -0.55, 0.3, 0.4, a, 0.02, 1))
    return build("zone_pastel_toy_train", parts)


# ---------------------------------------------------------------------------
# kayıt + ana akış
# ---------------------------------------------------------------------------
BUILDERS = [
    ("zone_kitchen_teapot.glb", build_teapot),
    ("zone_kitchen_jar.glb", build_jar),
    ("zone_kitchen_plate_stack.glb", build_plate_stack),
    ("zone_kitchen_cutting_board.glb", build_cutting_board),
    ("zone_library_globe.glb", build_globe),
    ("zone_library_candle.glb", build_candle),
    ("zone_library_book_tower.glb", build_book_tower),
    ("zone_library_hourglass.glb", build_hourglass),
    ("zone_night_alarm_clock.glb", build_alarm_clock),
    ("zone_night_moon_lamp.glb", build_moon_lamp),
    ("zone_night_plush.glb", build_plush),
    ("zone_night_stars_mobile.glb", build_stars_mobile),
    ("zone_pastel_blocks.glb", build_blocks),
    ("zone_pastel_duck.glb", build_duck),
    ("zone_pastel_balloon.glb", build_balloon),
    ("zone_pastel_toy_train.glb", build_toy_train),
]


def main() -> int:
    out_dir = PROJECT_ROOT / "assets" / "models" / "v3" / "zone"
    out_dir.mkdir(parents=True, exist_ok=True)

    only = set(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])

    total = 0
    for filename, builder in BUILDERS:
        if only and filename not in only:
            continue
        kit.reset()
        obj = builder()
        path = out_dir / filename
        export(obj, path)
        kit.report(obj, str(path))
        total += kit.triangle_count(obj)

    print("TOTAL_MODELS %d" % len(BUILDERS))
    print("TOTAL_TRIS %d" % total)
    print("OUT_DIR %s" % out_dir)
    return 0


if __name__ == "__main__":
    sys.exit(main())
