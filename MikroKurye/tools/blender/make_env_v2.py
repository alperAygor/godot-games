#!/usr/bin/env python3
"""MikroKurye — F7.10b: MODEL v2 — masa eşyaları + oda/çevre kiti (Blender 5.2, headless).

Tek betikten, idempotent. Kaynak = bu betik; GLB'ler üretilmiş çıktıdır.

    /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/make_env_v2.py

İstenirse tek model yeniden üretilir (hata ayıklama):

    ... -b -P tools/blender/make_env_v2.py -- prop_mug_v2

Sözleşme (studio-kit/tools/validate_glb.py):
  * tek mesh, transformlar uygulanmış -> node'da TRS yok
  * origin ALT-MERKEZ (min Y = 0, X/Z merkez = 0), metre ölçek
  * pürüzsüz gölgeleme: bevel + shade_auto_smooth ("Smooth by Angle" uygulanır)
  * vertex-renk "Col" ile taban AO gradyanı (GLB'de COLOR_0 olarak taşınır)
  * İSİMLİ malzeme slotları: "hazard" (klavye şeridi), "screen" (monitör),
    "bulb" (lamba), "glass" (pencere) — entegrasyonda toon malzemeyle eşlenecek
  * Blender +Y = glTF -Z = robotun ÖNÜ (yüz/ön +Y tarafında)

1 birim = 1 metre. Robot ~0.8 m; masa eşyaları robota göre dev (kupa ≈ 2.4 m).
"""

import math
import os
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
# palet — PROJECT_SPEC.md §13 (sıcak, doygun, harmonik)
# ---------------------------------------------------------------------------
WOOD = "#D9A066"          # sıcak ahşap
WOOD_DARK = "#B07A45"     # ahşap kenar
RED = "#F25F5C"           # kırmızı
BLUE = "#4D9DE0"          # mavi
YELLOW = "#F7B801"        # sarı
GREEN = "#7BC86C"         # yeşil
CREAM = "#FFE8C7"         # krem
NAVY = "#20263A"          # lacivert
TURQUOISE = "#2EE6C5"     # robot ana
ROBOT_YELLOW = "#FFC83D"  # robot vurgu
TIRE_DARK = "#2B2F3A"     # koyu aksam
RIM_LIGHT = "#B8C0CC"     # metal/jant
GOLD = "#E3B64B"          # altın
SILVER = "#C9CED6"        # gümüş
DANGER = "#FF4D4D"        # tehlike kırmızısı
MUG_INNER = "#6E1F1E"     # kupa içi
BOOK_SPINE = "#5AA34E"    # kitap sırtı
TERRACOTTA = "#C96F4A"    # saksı
LEAF_GREEN = "#5FA85B"    # yaprak koyu
LEAF_LIGHT = "#8FD08A"    # yaprak açık
PINK = "#F08A9B"          # pembe (yapışkan not)
ORANGE = "#EF8B2C"        # portakal
COFFEE = "#5B3626"        # kahve yüzeyi
SCREEN_BLUE = "#9FD8FF"   # monitör ekranı
BULB_WARM = "#FFD98A"     # ampul sıcak ışığı

BG_WARM = "#FFE8C7"       # önizleme arka planı


# ---------------------------------------------------------------------------
# yardımcılar — blender_kit primitiflerini tamamlar
# ---------------------------------------------------------------------------
def _srgb_to_linear(channel: float) -> float:
    return channel / 12.92 if channel <= 0.04045 else ((channel + 0.055) / 1.055) ** 2.4


def _lin(hex_color: str):
    value = hex_color.lstrip("#")
    return tuple(_srgb_to_linear(int(value[i:i + 2], 16) / 255.0) for i in (0, 2, 4))


def mat(name, color, roughness=0.55, metallic=0.0):
    return kit.material(name, color, roughness=roughness, metallic=metallic)


def emissive(name, color, strength=2.5, roughness=0.45):
    """Parlayan yüzey (monitör ekranı, ampul). EmissiveFactor GLB'ye yazılır."""
    existing = bpy.data.materials.get(name)
    if existing is not None:
        return existing
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    linear = _lin(color)
    bsdf.inputs["Base Color"].default_value = (*linear, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Emission Color"].default_value = (*linear, 1.0)
    bsdf.inputs["Emission Strength"].default_value = strength
    m.diffuse_color = (*linear, 1.0)
    return m


def glass(name, color="#BFE3F2", alpha=0.42, roughness=0.12):
    """Yarı saydam cam (pencere). İki yüz de çizilir."""
    existing = bpy.data.materials.get(name)
    if existing is not None:
        return existing
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    linear = _lin(color)
    bsdf.inputs["Base Color"].default_value = (*linear, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Alpha"].default_value = alpha
    for attr, value in (("blend_method", "BLEND"),
                        ("surface_render_method", "BLENDED"),
                        ("shadow_method", "NONE")):
        try:
            setattr(m, attr, value)
        except (AttributeError, TypeError):
            pass
    m.use_backface_culling = False
    m.diffuse_color = (*linear, alpha)
    return m


def add_torus(name, major_r, tube_r, location, m, rotation=(0.0, 0.0, 0.0),
              major_seg=28, minor_seg=8):
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


def add_leaf(name, length, width, thickness, location, m, direction):
    """Koni tabanlı sivri yaprak; geniş uç -Z'de, uç +Z'de. `direction` ucu yönlendirir."""
    bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=width / 2.0,
                                    radius2=0.02, depth=length, location=(0.0, 0.0, 0.0))
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = (1.0, thickness / max(width, 1e-6), 1.0)
    obj.rotation_euler = Vector(direction).to_track_quat("Z", "Y").to_euler()
    obj.location = location
    kit.activate(obj)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obj.data.materials.append(m)
    return obj


def _flat_triangle(name, r, h, location, m):
    """Y'de ince üçgen kabartma (resim tepesi, yapışkan not kıvrımı)."""
    bpy.ops.mesh.primitive_cone_add(vertices=3, radius1=r, radius2=0.0,
                                    depth=h, location=(0.0, 0.0, 0.0))
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = (1.0, 0.02, 1.0)
    obj.location = location
    kit.activate(obj)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
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
    """Transformları uygular, smooth-by-angle normalleri pişirir, origin'i alt-merkeze alır."""
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
# A) yenilenmiş masa eşyaları
# ---------------------------------------------------------------------------
def build_keyboard_row():
    base = mat("keyboard_base", NAVY, roughness=0.5)
    key = mat("keyboard_key", CREAM, roughness=0.6)
    legend = mat("keyboard_legend", TIRE_DARK, roughness=0.45)
    hazard = mat("hazard", YELLOW, roughness=0.4)
    hazard_black = mat("hazard_black", TIRE_DARK, roughness=0.4)

    base_w = 2.6
    base_d = 1.0
    base_h = 0.16
    key_w = 0.72
    key_d = 0.72
    key_h = 0.46
    gap = 0.08

    parts = [kit.box_bounds("Base", -base_w / 2, base_w / 2, -base_d / 2, base_d / 2,
                            0.0, base_h, base, 0.045, 2)]
    for index in range(3):
        cx = (index - 1.0) * (key_w + gap)
        cap = kit.box("Key%d" % index, (key_w, key_d, key_h),
                      (cx, 0.0, base_h + key_h / 2.0), key, 0.0)
        kit.taper_top(cap, 0.80)
        kit.bevel(cap, 0.07, 2)
        parts.append(cap)
        # üstte kabartma legend (harf yerine stilize blok + nokta)
        top_z = base_h + key_h + 0.004
        parts.append(kit.box_bounds("Legend%d" % index, cx - 0.16, cx + 0.16,
                                    -0.06, 0.06, top_z, top_z + 0.010, legend, 0.004, 1))
        parts.append(kit.cylinder("LegendDot%d" % index, 0.03, 0.012,
                                  (cx, 0.20, top_z), legend, vertices=8))

    # ön kenarda sarı/siyah tehlike şeridi — AYRI malzeme slotu "hazard"
    band_y0 = base_d / 2 - 0.004
    band_y1 = base_d / 2 + 0.012
    band_z0 = 0.02
    band_z1 = 0.14
    parts.append(kit.box_bounds("HazardBand", -base_w / 2, base_w / 2,
                                band_y0, band_y1, band_z0, band_z1, hazard, 0.003, 1))
    block_w = base_w / 8.0
    for index in range(0, 8, 2):
        x0 = -base_w / 2 + index * block_w
        parts.append(kit.box_bounds("HazardStripe%d" % index, x0, x0 + block_w,
                                    band_y1 - 0.002, band_y1 + 0.006,
                                    band_z0, band_z1, hazard_black, 0.002, 1))
    return build("KeyboardRowV2", parts)


def build_mug():
    red = mat("mug_red", RED, roughness=0.35)
    inner = mat("mug_inner", MUG_INNER, roughness=0.7)
    coffee = mat("mug_coffee", COFFEE, roughness=0.25)
    logo = mat("mug_logo", CREAM, roughness=0.5)

    r = 0.86
    body_z0 = 0.14
    body_z1 = 2.26
    body_h = body_z1 - body_z0
    body = kit.cylinder("Body", r, body_h, (0.0, 0.0, body_z0 + body_h / 2.0),
                        red, vertices=28)
    kit.bevel(body, 0.05, 2)
    base = kit.cylinder("Base", 0.90, 0.16, (0.0, 0.0, 0.08), red, vertices=28)
    kit.bevel(base, 0.03, 2)
    rim = add_torus("Rim", 0.80, 0.085, (0.0, 0.0, body_z1 + 0.03), red,
                    major_seg=28, minor_seg=8)
    inner_c = kit.cylinder("Inside", 0.76, 0.10, (0.0, 0.0, body_z1 - 0.02),
                           inner, vertices=28)
    coffee_surf = kit.cylinder("Coffee", 0.70, 0.012, (0.0, 0.0, body_z1 - 0.16),
                               coffee, vertices=28)
    handle = add_torus("Handle", 0.42, 0.12, (0.86, 0.0, 1.28), red,
                       rotation=(math.radians(90.0), 0.0, 0.0), major_seg=22, minor_seg=8)
    # hafif logo: ön yüzde (+Y) yumuşak kabartma disk + nokta
    parts = [body, base, rim, inner_c, coffee_surf, handle]
    parts.append(kit.cylinder("LogoDisc", 0.17, 0.02, (0.0, 0.88, 1.30), logo,
                              vertices=20, rotation=(math.radians(90.0), 0.0, 0.0)))
    parts.append(kit.cylinder("LogoDot", 0.06, 0.022, (0.0, 0.885, 1.30), logo,
                              vertices=12, rotation=(math.radians(90.0), 0.0, 0.0)))
    return build("MugV2", parts)


def build_pencil():
    yellow = mat("pencil_body", YELLOW, roughness=0.45)
    wood = mat("pencil_wood", WOOD, roughness=0.7)
    dark = mat("pencil_graphite", TIRE_DARK, roughness=0.35)
    ferrule = mat("pencil_ferrule", SILVER, roughness=0.25, metallic=0.7)
    eraser = mat("pencil_eraser", PINK, roughness=0.8)

    length = 8.0
    r = 0.25
    tip_l = 0.65
    graphite_l = 0.22
    ferrule_d = 0.18
    eraser_d = 0.20

    eraser_c = -length / 2 + eraser_d / 2
    ferrule_c = eraser_c + eraser_d / 2 + ferrule_d / 2
    body_y0 = ferrule_c + ferrule_d / 2
    body_y1 = length / 2 - graphite_l - tip_l
    body_len = body_y1 - body_y0
    axis_y = (math.radians(90.0), 0.0, 0.0)

    parts = [
        kit.cylinder("Eraser", 0.24, eraser_d, (0.0, eraser_c, 0.0), eraser, vertices=12,
                     rotation=axis_y),
        kit.cylinder("Ferrule", 0.27, ferrule_d, (0.0, ferrule_c, 0.0), ferrule,
                     vertices=12, rotation=axis_y),
    ]
    hex_body = kit.cylinder("HexBody", r, body_len, (0.0, (body_y0 + body_y1) / 2.0, 0.0),
                            yellow, vertices=6, rotation=axis_y)
    kit.bevel(hex_body, 0.03, 2)
    parts.append(hex_body)
    parts.append(add_cone("WoodTip", r, 0.06, tip_l, (0.0, body_y1 + tip_l / 2.0, 0.0), wood,
                          vertices=6, rotation=axis_y))
    parts.append(add_cone("Graphite", 0.06, 0.0, graphite_l, (0.0, body_y1 + tip_l + graphite_l / 2.0, 0.0),
                          dark, vertices=6, rotation=axis_y))
    # silgi üstünde metal yaka detayı
    parts.append(kit.cylinder("Collar", 0.255, 0.03, (0.0, body_y0 - 0.012, 0.0),
                              ferrule, vertices=12, rotation=axis_y))
    return build("PencilV2", parts)


def build_ruler():
    blue = mat("ruler_body", BLUE, roughness=0.45)
    tick = mat("ruler_tick", CREAM, roughness=0.6)

    length = 12.0
    width = 1.2
    thick = 0.10
    parts = [kit.box_bounds("Ruler", -width / 2, width / 2, -length / 2, length / 2,
                            0.0, thick, blue, 0.02, 2)]
    edge_x = -width / 2 + 0.02
    z0 = thick
    z1 = thick + 0.006
    # ana çentikler (1 m) + ara çentikler (0.5 m)
    y = -length / 2 + 0.6
    while y <= length / 2 - 0.6 + 1e-6:
        parts.append(kit.box_bounds("Tick%02d" % round((y + 6.0) * 10),
                                    edge_x, edge_x + 0.075, y - 0.025, y + 0.025,
                                    z0, z1, tick, 0.0012, 1))
        if y + 0.5 <= length / 2 - 0.6 + 1e-6:
            parts.append(kit.box_bounds("TickHalf%02d" % round((y + 6.25) * 10),
                                        edge_x, edge_x + 0.05, y + 0.475, y + 0.525,
                                        z0, z1 - 0.0015, tick, 0.0012, 1))
        y += 1.0
    # rakam şeridi: kenar boyunca sürekli ince krem bant (vertex-renk/geometri detayı)
    parts.append(kit.box_bounds("NumberStrip", edge_x, edge_x + 0.4,
                                -length / 2 + 0.1, length / 2 - 0.1,
                                z0, z0 + 0.004, tick, 0.0008, 1))
    # merkez oluğu
    parts.append(kit.box_bounds("Groove", -0.02, 0.02, -length / 2 + 0.3, length / 2 - 0.3,
                                z0, z0 + 0.003, tick, 0.0008, 1))
    return build("RulerV2", parts)


def build_book():
    cover = mat("book_cover", GREEN, roughness=0.5)
    pages = mat("book_pages", CREAM, roughness=0.75)
    spine = mat("book_spine", BOOK_SPINE, roughness=0.5)
    ribbon = mat("book_ribbon", RED, roughness=0.5)

    w = 3.5
    l = 5.0
    h = 0.62
    cover_t = 0.09
    inset = 0.08
    hw, hl = w / 2, l / 2
    page_x0 = -hw + inset
    page_x1 = hw - inset
    page_y0 = -hl + inset
    page_y1 = hl - inset
    parts = [
        kit.box_bounds("CoverBottom", -hw, hw, -hl, hl, 0.0, cover_t, cover, 0.016, 2),
        kit.box_bounds("CoverTop", -hw, hw, -hl, hl, h - cover_t, h, cover, 0.016, 2),
        kit.box_bounds("Spine", -hw, page_x0, -hl, hl, 0.0, h, spine, 0.014, 2),
        kit.box_bounds("Pages", page_x0, page_x1, page_y0, page_y1, cover_t, h - cover_t,
                       pages, 0.006, 2),
    ]
    # sayfa kenarı çizgileri (ince oyuk hissi)
    line_z = h - cover_t
    n_lines = 4
    for i in range(1, n_lines + 1):
        yy0 = page_y0 + (page_y1 - page_y0) * (i - 0.5) / n_lines - 0.004
        parts.append(kit.box_bounds("PageLine%d" % i, page_x0, page_x1, yy0, yy0 + 0.008,
                                    line_z, line_z + 0.006, spine, 0.0015, 1))
    # yer imi şeridi: sırttan sarkan kırmızı kurdele
    parts.append(kit.box_bounds("Ribbon", -hw + 0.03, -hw + 0.09, 0.2, 0.4,
                                h, h + 0.05, ribbon, 0.004, 1))
    parts.append(kit.box_bounds("RibbonTail", -hw + 0.035, -hw + 0.085, 0.2, 0.9,
                                h - 0.03, h + 0.02, ribbon, 0.004, 1))
    return build("BookV2", parts)


# ---------------------------------------------------------------------------
# B) yeni masa eşyaları
# ---------------------------------------------------------------------------
def build_monitor():
    frame = mat("monitor_frame", NAVY, roughness=0.4)
    screen = emissive("screen", SCREEN_BLUE, strength=2.2)
    stand = mat("monitor_stand", TIRE_DARK, roughness=0.45)
    led = emissive("monitor_led", GREEN, strength=3.0)

    scr_w = 2.5
    scr_h = 1.7
    bezel = 0.10
    scr_z0 = 0.9
    scr_z1 = scr_z0 + scr_h
    # ekran (emissive slot "screen") önde; çerçeve arkada daha büyük -> kenar bezel görünür
    parts = [kit.box_bounds("Screen", -scr_w / 2, scr_w / 2, 0.0, 0.06,
                            scr_z0, scr_z1, screen, 0.01, 1)]
    outer_w = scr_w + bezel * 2
    outer_h = scr_h + bezel * 2
    parts.append(kit.box_bounds("Back", -outer_w / 2, outer_w / 2, 0.06, 0.22,
                                scr_z0 - bezel, scr_z1 + bezel, frame, 0.035, 2))
    # alt bezelde güç LED'i
    parts.append(kit.cylinder("PowerLed", 0.025, 0.02, (outer_w / 2 - 0.14, 0.065,
                                                        scr_z0 - bezel / 2), led,
                              vertices=10, rotation=(math.radians(90.0), 0.0, 0.0)))
    # ayak: boyun + taban
    parts.append(kit.box_bounds("Neck", -0.06, 0.06, -0.05, 0.12, 0.0, scr_z0,
                                stand, 0.012, 2))
    parts.append(kit.box_bounds("Base", -0.55, 0.55, -0.30, 0.30, 0.0, 0.06,
                                stand, 0.03, 2))
    return build("MonitorV2", parts)


def build_lamp():
    body = mat("lamp_body", YELLOW, roughness=0.4)
    metal = mat("lamp_metal", SILVER, roughness=0.25, metallic=0.7)
    bulb = emissive("bulb", BULB_WARM, strength=4.0)

    parts = [
        kit.cylinder("Base", 0.5, 0.10, (0.0, 0.0, 0.05), body, vertices=24),
        kit.cylinder("BaseDisc", 0.44, 0.04, (0.0, 0.0, 0.12), metal, vertices=24),
    ]
    # alt kol (Z) + dirsek + üst kol
    parts.append(kit.cylinder("ArmLower", 0.07, 0.7, (0.0, 0.0, 0.55), body, vertices=12))
    parts.append(add_sphere("Elbow", 0.13, (0.0, 0.0, 0.95), metal, segments=20, rings=10))
    parts.append(kit.cylinder("ArmUpper", 0.06, 0.6, (0.0, 0.42, 1.15), body, vertices=12,
                              rotation=(math.radians(-35.0), 0.0, 0.0)))
    # başlık: kubbe + ampul
    head_z = 1.32
    parts.append(add_sphere("Head", 0.28, (0.0, 0.55, head_z), body, segments=24, rings=12))
    parts.append(kit.cylinder("Bulb", 0.16, 0.10, (0.0, 0.60, head_z - 0.02), bulb, vertices=16))
    parts.append(kit.cylinder("Shade", 0.30, 0.05, (0.0, 0.55, head_z + 0.12), body, vertices=20))
    return build("LampV2", parts)


def build_plant():
    pot = mat("plant_pot", TERRACOTTA, roughness=0.55)
    pot_rim = mat("plant_rim", WOOD_DARK, roughness=0.5)
    leaf_dark = mat("plant_leaf_dark", LEAF_GREEN, roughness=0.5)
    leaf_light = mat("plant_leaf_light", LEAF_LIGHT, roughness=0.5)
    stem = mat("plant_stem", BOOK_SPINE, roughness=0.5)

    pot_r0 = 0.62
    pot_r1 = 0.78
    pot_h = 0.9
    parts = [
        add_cone("Pot", pot_r1, pot_r0, pot_h, (0.0, 0.0, pot_h / 2), pot,
                 vertices=24, bevel_width=0.02),
        add_torus("PotRim", pot_r1, 0.05, (0.0, 0.0, pot_h + 0.01), pot_rim,
                  major_seg=24, minor_seg=6),
        kit.cylinder("Soil", pot_r1 - 0.06, 0.03, (0.0, 0.0, pot_h + 0.05), pot,
                     vertices=24),
    ]
    # merkez gövde + kavisli yapraklar (dışa + yukarı yönlü)
    parts.append(kit.cylinder("Stem", 0.05, 1.1, (0.0, 0.0, pot_h + 0.6), stem, vertices=10))
    base = Vector((0.0, 0.0, pot_h + 0.6))
    n_leaves = 7
    for i in range(n_leaves):
        a = (2 * math.pi * i) / n_leaves
        tilt = 1.05  # dikeyden dışa açı (radyan)
        direction = Vector((math.cos(a) * math.sin(tilt),
                            math.sin(a) * math.sin(tilt),
                            math.cos(tilt)))
        length = 1.0 if i % 2 == 0 else 0.85
        m = leaf_light if i % 2 == 0 else leaf_dark
        loc = base + direction * (length / 2.0)
        parts.append(add_leaf("Leaf%d" % i, length, 0.42, 0.05, loc, m, direction))
    return build("PlantV2", parts, smooth_angle=45.0)


def build_book_stack():
    colors = [RED, BLUE, YELLOW, GREEN]
    mats = [mat("stack_book_%d" % i, colors[i], roughness=0.5) for i in range(4)]
    pages = mat("stack_pages", CREAM, roughness=0.75)

    parts = []
    book_w = 3.0
    book_l = 4.0
    book_h = 0.55
    y_offsets = [0.0, 0.18, -0.14, 0.28]
    for i in range(4):
        hw, hl = book_w / 2, book_l / 2
        z0 = i * book_h
        y0 = y_offsets[i]
        rot = math.radians((-2.0, 3.0, -1.5, 2.5)[i])
        cover = mats[i]
        # kapak (solda) + sayfa bloğu (sağda, krem) -> yandan kitap okunur
        parts.append(add_box_rot("Book%dCover" % i, (book_w * 0.72, book_l, book_h),
                                 (-hw * 0.14, y0, z0 + book_h / 2), cover,
                                 rotation=(0.0, 0.0, rot), bevel_width=0.03, segments=2))
        parts.append(add_box_rot("Book%dPages" % i, (book_w * 0.28, book_l - 0.08, book_h * 0.92),
                                 (hw * 0.36, y0, z0 + book_h / 2), pages,
                                 rotation=(0.0, 0.0, rot), bevel_width=0.01, segments=1))
    return build("BookStackV2", parts)


def build_headphones():
    band = mat("hp_band", NAVY, roughness=0.4)
    cup = mat("hp_cup", RED, roughness=0.35)
    cushion = mat("hp_cushion", TIRE_DARK, roughness=0.8)

    parts = [
        add_torus("Band", 0.85, 0.09, (0.0, 0.0, 0.95), band,
                  rotation=(math.radians(90.0), 0.0, 0.0), major_seg=28, minor_seg=8),
    ]
    for side in (-1.0, 1.0):
        y = side * 0.75
        parts.append(kit.cylinder("Cup%+.0f" % side, 0.42, 0.20,
                                  (0.0, y, 0.95), cup, vertices=24,
                                  rotation=(math.radians(90.0), 0.0, 0.0)))
        parts.append(kit.cylinder("Cushion%+.0f" % side, 0.36, 0.08,
                                  (0.0, side * 0.87, 0.95), cushion, vertices=24,
                                  rotation=(math.radians(90.0), 0.0, 0.0)))
    return build("HeadphonesV2", parts)


def build_notebook():
    cover = mat("nb_cover", BLUE, roughness=0.5)
    pages = mat("nb_pages", CREAM, roughness=0.75)
    spiral = mat("nb_spiral", SILVER, roughness=0.25, metallic=0.7)
    pencil_y = mat("nb_pencil", YELLOW, roughness=0.45)
    pencil_tip = mat("nb_pencil_tip", TIRE_DARK, roughness=0.4)

    w = 3.4
    l = 4.4
    t = 0.16
    parts = [
        kit.box_bounds("Cover", -w / 2, w / 2, -l / 2, l / 2, 0.0, t, cover, 0.025, 2),
        kit.box_bounds("Pages", -w / 2 + 0.12, w / 2 - 0.12, -l / 2 + 0.08, l / 2 - 0.08,
                       0.02, t, pages, 0.006, 2),
    ]
    # spiral: uzun kenarda 8 halka (helix yerine ayrı torus halkaları)
    for i in range(8):
        y = -l / 2 + 0.3 + i * ((l - 0.6) / 7)
        parts.append(add_torus("Spiral%d" % i, 0.05, 0.016, (-w / 2 - 0.015, y, 0.06),
                               spiral, rotation=(math.radians(90.0), 0.0, 0.0),
                               major_seg=12, minor_seg=5))
    # içine sıkışmış kalem
    parts.append(kit.cylinder("Pencil", 0.07, 3.6, (0.0, 0.3, t), pencil_y, vertices=6,
                              rotation=(math.radians(90.0), 0.0, 0.0)))
    parts.append(add_cone("PencilTip", 0.07, 0.0, 0.3, (0.0, 2.15, t), pencil_tip,
                          vertices=6, rotation=(math.radians(-90.0), 0.0, 0.0)))
    return build("NotebookV2", parts)


def build_pen_cup():
    cup = mat("pc_cup", ORANGE, roughness=0.4)
    cup_inner = mat("pc_inner", TIRE_DARK, roughness=0.6)
    pen_colors = [RED, BLUE, GREEN]
    pens = [mat("pc_pen_%d" % i, pen_colors[i], roughness=0.4) for i in range(3)]
    pen_tip = mat("pc_pen_tip", TIRE_DARK, roughness=0.4)

    cup_r = 0.55
    cup_h = 1.5
    parts = [
        add_cone("Cup", cup_r, cup_r * 0.85, cup_h, (0.0, 0.0, cup_h / 2), cup,
                 vertices=24, bevel_width=0.02),
        kit.cylinder("Inner", cup_r - 0.06, 0.04, (0.0, 0.0, cup_h - 0.02), cup_inner,
                     vertices=24),
    ]
    tips = [(-0.18, 1.62), (0.12, 1.55), (0.34, 1.68)]
    for i in range(3):
        x, z = tips[i]
        parts.append(kit.cylinder("Pen%d" % i, 0.055, 1.1, (x, 0.0, z + 0.35), pens[i],
                                  vertices=10))
        parts.append(add_cone("PenTip%d" % i, 0.055, 0.0, 0.22, (x, 0.0, z - 0.35), pen_tip,
                              vertices=10))
    return build("PenCupV2", parts)


def build_sticky_notes():
    yellow = mat("sn_yellow", YELLOW, roughness=0.55)
    green = mat("sn_green", GREEN, roughness=0.55)
    pink = mat("sn_pink", PINK, roughness=0.55)

    size = 0.85
    t = 0.035
    notes = [
        (yellow, 0.0, 0.0, 0.0),
        (green, 0.10, -0.10, math.radians(8.0)),
        (pink, -0.08, -0.20, math.radians(-6.0)),
    ]
    parts = []
    for i, (m, x, y, rot) in enumerate(notes):
        parts.append(add_box_rot("Note%d" % i, (size, size, t), (x, y, t / 2), m,
                                 rotation=(0.0, 0.0, rot), bevel_width=0.008, segments=1))
        # hafif kıvrık köşe hissi: üstte ince kat izi
        parts.append(kit.box_bounds("Crease%d" % i, x + 0.05, x + 0.35,
                                    y + size / 2 - 0.28, y + size / 2 - 0.22,
                                    t, t + 0.006, m, 0.002, 1))
    return build("StickyNotesV2", parts)


def build_coin():
    gold = mat("coin_gold", GOLD, roughness=0.3, metallic=0.8)
    emblem = mat("coin_emblem", "#C8912B", roughness=0.3, metallic=0.8)

    r = 0.75
    h = 0.22
    parts = [
        kit.cylinder("Coin", r, h, (0.0, 0.0, h / 2), gold, vertices=40),
    ]
    # yüzde kabartma amblem: dış halka + iç yıldız noktası
    parts.append(add_torus("EmblemRing", 0.30, 0.05, (0.0, 0.0, h), emblem,
                           major_seg=24, minor_seg=6))
    parts.append(kit.cylinder("EmblemCore", 0.16, 0.02, (0.0, 0.0, h), emblem, vertices=18))
    return build("CoinV2", parts)


# ---------------------------------------------------------------------------
# C) oda/çevre kiti (uzak/dekor)
# ---------------------------------------------------------------------------
def build_window():
    frame = mat("win_frame", WOOD, roughness=0.5)
    sill = mat("win_sill", WOOD_DARK, roughness=0.5)
    gl = glass("glass", "#BFE3F2", alpha=0.42)

    w = 5.0
    h = 4.0
    depth = 0.22
    frame_t = 0.14
    frame_z0 = 0.10
    frame_z1 = frame_z0 + h
    mid_z = (frame_z0 + frame_z1) / 2
    parts = [
        kit.box_bounds("Sill", -w / 2 - 0.3, w / 2 + 0.3, -0.18, depth + 0.10,
                       0.0, 0.10, sill, 0.03, 2),
        kit.box_bounds("FrameTop", -w / 2, w / 2, 0.0, depth, frame_z1 - frame_t, frame_z1,
                       frame, 0.03, 2),
        kit.box_bounds("FrameBottom", -w / 2, w / 2, 0.0, depth, frame_z0, frame_z0 + frame_t,
                       frame, 0.03, 2),
        kit.box_bounds("FrameL", -w / 2, -w / 2 + frame_t, 0.0, depth,
                       frame_z0 + frame_t, frame_z1 - frame_t, frame, 0.02, 2),
        kit.box_bounds("FrameR", w / 2 - frame_t, w / 2, 0.0, depth,
                       frame_z0 + frame_t, frame_z1 - frame_t, frame, 0.02, 2),
        kit.box_bounds("MullionV", -frame_t / 2, frame_t / 2, 0.0, depth,
                       frame_z0 + frame_t, frame_z1 - frame_t, frame, 0.02, 2),
        kit.box_bounds("MullionH", -w / 2, w / 2, 0.0, depth,
                       mid_z - frame_t / 2, mid_z + frame_t / 2, frame, 0.02, 2),
    ]
    # 4 cam bölme (yarı saydam slot "glass")
    pane_w = (w - frame_t * 3) / 2
    pane_h = (h - frame_t * 3) / 2
    for gx in (-1, 1):
        for gy in (-1, 1):
            cx = gx * (pane_w / 2 + frame_t)
            cz = mid_z + gy * (pane_h / 2 + frame_t)
            parts.append(kit.box_bounds("Glass%+d%+d" % (gx, gy),
                                        cx - pane_w / 2, cx + pane_w / 2,
                                        0.03, depth - 0.03,
                                        cz - pane_h / 2, cz + pane_h / 2, gl, 0.0, 1))
    return build("WindowV2", parts)


def build_curtain():
    fabric = mat("cur_fabric", RED, roughness=0.7)
    rod = mat("cur_rod", NAVY, roughness=0.4)
    fold_dark = mat("cur_fold", "#D84A48", roughness=0.7)

    w = 5.0
    h = 3.4
    depth = 0.5
    parts = [
        kit.box_bounds("Rod", -w / 2, w / 2, -0.05, 0.05, h + 0.12, h + 0.2,
                       rod, 0.02, 2),
    ]
    # kıvrımlı perde: arka düz bant + öne çıkan dikey silindir kıvrımlar
    parts.append(kit.box_bounds("Back", -w / 2, w / 2, -depth / 2, depth / 2, 0.0, h,
                                fabric, 0.03, 2))
    n_folds = 6
    fold_w = w / n_folds
    for i in range(n_folds):
        cx = -w / 2 + fold_w * (i + 0.5)
        radius = fold_w * 0.36
        parts.append(kit.cylinder("Fold%d" % i, radius, h, (cx, depth / 2, h / 2),
                                  fold_dark if i % 2 else fabric, vertices=16))
    return build("CurtainV2", parts)


def build_shelf():
    wood = mat("shelf_wood", WOOD, roughness=0.5)
    wood_dark = mat("shelf_wood_dark", WOOD_DARK, roughness=0.5)
    book_a = mat("shelf_book_a", RED, roughness=0.5)
    book_b = mat("shelf_book_b", BLUE, roughness=0.5)
    pot = mat("shelf_pot", TERRACOTTA, roughness=0.55)
    leaf = mat("shelf_leaf", LEAF_GREEN, roughness=0.5)

    w = 4.2
    d = 1.0
    t = 0.16
    parts = [
        kit.box_bounds("Plank", -w / 2, w / 2, -d / 2, d / 2, 0.0, t, wood, 0.025, 2),
        kit.box_bounds("BracketL", -w / 2 + 0.2, -w / 2 + 0.32, -d / 2 + 0.1, d / 2 - 0.1,
                       -0.35, 0.0, wood_dark, 0.02, 2),
        kit.box_bounds("BracketR", w / 2 - 0.32, w / 2 - 0.2, -d / 2 + 0.1, d / 2 - 0.1,
                       -0.35, 0.0, wood_dark, 0.02, 2),
    ]
    # iki kitap (dik duran)
    for i, (x, m, bh, bl) in enumerate([(-1.2, book_a, 0.9, 0.35), (-0.6, book_b, 1.1, 0.42)]):
        parts.append(add_box_rot("Book%d" % i, (bl, bh, 0.7), (x, -d / 2 + 0.5, t + 0.35), m,
                                 rotation=(0.0, 0.0, 0.0), bevel_width=0.02, segments=2))
    # küçük bitki
    pot_r = 0.18
    parts.append(add_cone("Pot", pot_r, pot_r * 0.8, 0.34, (1.4, 0.0, t + 0.17), pot,
                          vertices=16, bevel_width=0.01))
    leaf_base = Vector((1.4, 0.0, t + 0.45))
    for i, a in enumerate([0.0, math.radians(120.0), math.radians(240.0)]):
        direction = Vector((math.cos(a) * math.sin(1.0), math.sin(a) * math.sin(1.0),
                            math.cos(1.0)))
        parts.append(add_leaf("Leaf%d" % i, 0.42, 0.16, 0.02,
                              leaf_base + direction * 0.21, leaf, direction))
    return build("ShelfV2", parts, smooth_angle=45.0)


def build_picture_frame():
    frame = mat("pf_frame", NAVY, roughness=0.4)
    art = mat("pf_art", CREAM, roughness=0.6)
    art_sun = mat("pf_art_sun", YELLOW, roughness=0.5)
    art_hill = mat("pf_art_hill", GREEN, roughness=0.6)

    w = 2.6
    h = 1.9
    frame_t = 0.16
    depth = 0.12
    # çerçeve + sanat: XZ düzleminde, Y ince (yüze bakar)
    parts = [
        kit.box_bounds("Frame", -w / 2, w / 2, 0.0, depth, 0.0, h, frame, 0.025, 2),
        kit.box_bounds("Art", -w / 2 + frame_t, w / 2 - frame_t, 0.0, depth - 0.03,
                       frame_t, h - frame_t, art, 0.006, 1),
    ]
    # sanat: güneş (disk) + tepeler (ince üçgen kabartma)
    parts.append(kit.cylinder("Sun", 0.22, 0.02, (0.5, depth - 0.03, h - 0.5), art_sun,
                              vertices=14, rotation=(math.radians(90.0), 0.0, 0.0)))
    parts.append(_flat_triangle("HillA", 0.9, 0.5, (-0.5, depth - 0.03, frame_t + 0.25), art_hill))
    parts.append(_flat_triangle("HillB", 0.6, 0.34, (0.1, depth - 0.03, frame_t + 0.17), art_hill))
    return build("PictureFrameV2", parts)


def build_desk_edge():
    wood_top = mat("desk_wood", WOOD, roughness=0.5)
    wood_edge = mat("desk_edge", WOOD_DARK, roughness=0.5)
    seam = mat("desk_seam", "#B07A45", roughness=0.6)

    length = 6.0
    depth = 1.5
    thick = 0.4
    hw, hd = length / 2, depth / 2
    parts = [
        # üst yüzey (açık ahşap) + ön/yan kalınlık (koyu ahşap)
        kit.box_bounds("Top", -hw, hw, -hd, hd, 0.0, thick, wood_top, 0.05, 2),
        kit.box_bounds("Face", -hw, hw, hd - 0.10, hd, 0.0, thick, wood_edge, 0.05, 2),
    ]
    # ahşap kalas kenarları (üstte ince dikiş oyukları)
    n_planks = 4
    for i in range(1, n_planks):
        y = -hd + i * (depth / n_planks)
        parts.append(kit.box_bounds("Seam%d" % i, -hw + 0.1, hw - 0.1, y - 0.012, y + 0.012,
                                    thick, thick + 0.006, seam, 0.002, 1))
    return build("DeskEdgeV2", parts)


def build_wall_panel():
    wall = mat("wall", CREAM, roughness=0.8)
    skirt = mat("wall_skirt", NAVY, roughness=0.5)

    length = 6.0
    height = 3.0
    skirt_h = 0.4
    parts = [
        kit.box_bounds("Wall", -length / 2, length / 2, -0.12, 0.12, 0.0, height,
                       wall, 0.02, 2),
        kit.box_bounds("Skirt", -length / 2, length / 2, -0.16, 0.16, 0.0, skirt_h,
                       skirt, 0.02, 2),
    ]
    return build("WallPanelV2", parts)


# ---------------------------------------------------------------------------
# kayıt + ana akış
# ---------------------------------------------------------------------------
BUILDERS = [
    ("prop_keyboard_row_v2.glb", build_keyboard_row),
    ("prop_mug_v2.glb", build_mug),
    ("prop_pencil_v2.glb", build_pencil),
    ("prop_ruler_v2.glb", build_ruler),
    ("prop_book_v2.glb", build_book),
    ("prop_monitor_v2.glb", build_monitor),
    ("prop_lamp_v2.glb", build_lamp),
    ("prop_plant_v2.glb", build_plant),
    ("prop_book_stack_v2.glb", build_book_stack),
    ("prop_headphones_v2.glb", build_headphones),
    ("prop_notebook_v2.glb", build_notebook),
    ("prop_pen_cup_v2.glb", build_pen_cup),
    ("prop_sticky_notes_v2.glb", build_sticky_notes),
    ("prop_coin_v2.glb", build_coin),
    ("env_window_v2.glb", build_window),
    ("env_curtain_v2.glb", build_curtain),
    ("env_shelf_v2.glb", build_shelf),
    ("env_picture_frame_v2.glb", build_picture_frame),
    ("env_desk_edge_v2.glb", build_desk_edge),
    ("env_wall_panel_v2.glb", build_wall_panel),
]


def main() -> int:
    out_dir = PROJECT_ROOT / "assets" / "models" / "v2" / "env"
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
