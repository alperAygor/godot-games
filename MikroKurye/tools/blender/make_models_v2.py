#!/usr/bin/env python3
"""MikroKurye — V2 mid-poly model seti (Blender 5.x, headless).

Kaynak = bu betik; GLB'ler üretilmiş çıktıdır. Tek komut:

    /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/make_models_v2.py

V1'den farkı (kullanıcı geri bildirimi: "low-poly'nin üstüne çıkmalı"):
  * kırık/köşeli kutumsu formlar yerine kavisli, bevel'li, Subdivision Surface'li formlar
  * pürüzsüz gölgeleme (shade smooth) — V1 flat shading'di
  * vertex-renk "Color" gradyanı (alt koyu, üst açık) GLB'ye yazılır
  * İSİMLİ malzeme slotları: body / accent / tire / hub / visor / eye_emissive / metal /
    plastic_basket / label / strap (entegrasyonda toon malzemeyle eşlenecek)

Sözleşme (studio-kit/tools/validate_glb.py):
  * tek mesh, transformlar uygulanmış -> node'da TRS yok
  * origin ALT-MERKEZ (min Y = 0, X/Z merkez = 0), metre ölçek — TEKERLEK İSTİSNA:
    tekerlek origin MERKEZ + eksen X (dönme için doğru pivot; validate minY istisnası)
  * Blender +Y = glTF -Z = robotun ÖNÜ

1 birim = 1 metre.
"""

import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix

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
# palet — PROJECT_SPEC.md §13 + gerekli ek slot renkleri (sRGB hex)
# ---------------------------------------------------------------------------
ROBOT_TURQUOISE = "#2EE6C5"   # robot ana gövde
ROBOT_YELLOW = "#FFC83D"      # robot vurgu: lamba, anten, rozet
TIRE_DARK = "#2B2F3A"         # lastik / koyu aksam / süspansiyon
RIM_LIGHT = "#B8C0CC"         # jant / metal
WOOD_DARK = "#B07A45"         # çanta kayışı (sıcak kahve tonu)
PROP_BLUE = "#4D9DE0"         # SD kart
PROP_GREEN = "#7BC86C"        # pil gövdesi
PROP_RED = "#F25F5C"          # kapsül gövdesi
CREAM = "#FFF0D2"             # etiket / sayfa kenarı
BASKET_ORANGE = "#EF8B2C"     # sepet kenarı / kaburga
GOLD = "#E3B64B"              # SD temas
SILVER = "#C9CED6"            # pil kapağı
ALUMINUM = "#CFD4DA"          # kapsül alüminyum kapağı
VISOR_DARK = "#20283A"        # yüz visor ekranı
EYE_GLOW = "#EAF9FF"          # göz taban rengi
EYE_EMISSIVE = "#B7F3FF"      # göz emisyon rengi

# ---------------------------------------------------------------------------
# ölçüler — robot (metre; front = +Y)
# ---------------------------------------------------------------------------
ROBOT_BODY_RX = 0.25          # gövde yarım genişlik
ROBOT_BODY_RY = 0.38          # gövde yarım uzunluk
ROBOT_BODY_RZ = 0.28          # gövde yarım yükseklik
ROBOT_BODY_CENTER = (0.0, 0.02, 0.34)

VISOR_RX = 0.165
VISOR_RY = 0.045
VISOR_RZ = 0.13
VISOR_CENTER = (0.0, 0.382, 0.38)

EYE_R = 0.05
EYE_X = 0.068
EYE_Z = 0.40
EYE_Y = 0.418

SMILE_R = 0.058
SMILE_TUBE = 0.0075
SMILE_CENTER = (0.0, 0.426, 0.318)

LAMP_R = 0.028
LAMP_H = 0.045
LAMP_POS = (0.17, -0.07, 0.54)

ANTENNA_R = 0.009
ANTENNA_BASE = (-0.0, -0.05, 0.57)   # taban yüksekliği (her iki tarafta)
ANTENNA_X = 0.11
ANTENNA_TOP_Z = 0.73
ANTENNA_TIP_R = 0.022

BAG_SIZE = (0.085, 0.04, 0.15)
BAG_CENTER = (-0.235, 0.0, 0.28)
BAG_FLAP_H = 0.035

PLATFORM_SIZE = (0.44, 0.30, 0.035)
PLATFORM_CENTER = (0.0, -0.16, 0.60)

AXLE_X = 0.20
AXLE_Z = 0.18
AXLE_Y = 0.0
SUSP_ARM_X = 0.17

BOLT_R = 0.014
BOLT_D = 0.006

# ---------------------------------------------------------------------------
# ölçüler — tekerlek (metre; origin MERKEZ, eksen X)
# ---------------------------------------------------------------------------
WHEEL_RADIUS = 0.18
WHEEL_TIRE_TUBE = 0.045
WHEEL_TIRE_MAJOR = WHEEL_RADIUS - WHEEL_TIRE_TUBE       # 0.135
WHEEL_TIRE_WIDTH = 0.075
WHEEL_RIM_MAJOR = 0.098
WHEEL_RIM_TUBE = 0.016
WHEEL_HUB_R = 0.042
WHEEL_HUB_D = 0.08
WHEEL_CAP_R = 0.024
WHEEL_CAP_D = 0.014
WHEEL_SPOKE_COUNT = 5
WHEEL_TREAD_COUNT = 14
WHEEL_TREAD_RADIAL = 0.020

# ---------------------------------------------------------------------------
# ölçüler — sepet (metre)
# ---------------------------------------------------------------------------
BASKET_W = 0.52
BASKET_D = 0.35
BASKET_H = 0.30
BASKET_WALL = 0.02
BASKET_FLOOR = 0.022
BASKET_RIM_H = 0.035
BASKET_RIM_T = 0.018
BASKET_BEVEL = 0.010
BASKET_RIB_W = 0.02
BASKET_RIB_COUNT = 3

# ---------------------------------------------------------------------------
# ölçüler — kargo (metre; her biri <= 0.12 m)
# ---------------------------------------------------------------------------
BATTERY_R = 0.030
BATTERY_BODY_D = 0.085
BATTERY_CAP_D = 0.008
BATTERY_NUB_R = 0.012
BATTERY_NUB_D = 0.008
BATTERY_BAND_D = 0.004
BATTERY_LABEL_W = 0.012

SD_CARD_L = 0.120
SD_CARD_W = 0.080
SD_CARD_T = 0.008
SD_CHAMFER = 0.016
SD_CONTACT_COUNT = 5
SD_CONTACT_W = 0.013
SD_CONTACT_L = 0.034
SD_CONTACT_T = 0.0016
SD_LABEL_W = 0.058
SD_LABEL_L = 0.038
SD_LOCK_W = 0.008
SD_LOCK_L = 0.014

CAPSULE_R_BOTTOM = 0.030
CAPSULE_R_TOP = 0.043
CAPSULE_BODY_H = 0.044
CAPSULE_LID_R = 0.046
CAPSULE_LID_H = 0.010
CAPSULE_RIDGE_COUNT = 14


# ---------------------------------------------------------------------------
# yardımcılar — malzeme + primitifler (pürüzsüz gölgelemeye uygun)
# ---------------------------------------------------------------------------
def mat(name: str, color: str, roughness: float = 0.5, metallic: float = 0.0,
        emission: str = None, emission_strength: float = 1.0):
    """İsimli malzeme slotu. emission verilirse Principled emisyon yazılır."""
    m = kit.material(name, color, roughness=roughness, metallic=metallic)
    if emission:
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        if bsdf is not None and "Emission Color" in bsdf.inputs:
            linear = tuple(kit._srgb_to_linear(c) for c in kit._hex_rgb(emission))
            bsdf.inputs["Emission Color"].default_value = (*linear, 1.0)
            bsdf.inputs["Emission Strength"].default_value = emission_strength
    return m


def uv_sphere(name: str, radius: float, location, mat, segments: int = 32,
              rings: int = 16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings,
                                         radius=radius, location=location)
    obj = bpy.context.active_object
    obj.name = name
    kit.activate(obj)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    if mat is not None:
        obj.data.materials.append(mat)
    return obj


def ellipsoid(name: str, size, location, mat, segments: int = 40, rings: int = 24):
    """Yarım eksenleri `size=(sx, sy, sz)` olan elipsoid; merkezi `location`."""
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings,
                                         radius=1.0, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    kit.activate(obj)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    if mat is not None:
        obj.data.materials.append(mat)
    return obj


def cylinder(name: str, radius: float, depth: float, location, mat,
             vertices: int = 16, rotation=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius,
                                        depth=depth, location=location,
                                        rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    kit.activate(obj)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    if mat is not None:
        obj.data.materials.append(mat)
    return obj


def cone(name: str, r1: float, r2: float, depth: float, location, mat,
         vertices: int = 16, rotation=(0.0, 0.0, 0.0), bevel_width: float = 0.0):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=r1, radius2=r2,
                                    depth=depth, location=location,
                                    rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    kit.activate(obj)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    if bevel_width > 0.0:
        kit.bevel(obj, bevel_width, 1)
    if mat is not None:
        obj.data.materials.append(mat)
    return obj


def torus(name: str, major_r: float, tube_r: float, location, mat,
          rotation=(0.0, 0.0, 0.0), major_seg: int = 24, minor_seg: int = 10):
    bpy.ops.mesh.primitive_torus_add(major_radius=major_r, minor_radius=tube_r,
                                     major_segments=major_seg,
                                     minor_segments=minor_seg,
                                     location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    kit.activate(obj)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    if mat is not None:
        obj.data.materials.append(mat)
    return obj


def box(name: str, size, location, mat, bevel_width: float = 0.0,
        segments: int = 2, rotation=(0.0, 0.0, 0.0)):
    """Bevel'li kutu (düzgün köşeler)."""
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    kit.activate(obj)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    if bevel_width > 0.0:
        kit.bevel(obj, bevel_width, segments)
    if mat is not None:
        obj.data.materials.append(mat)
    return obj


def arc_xz(name: str, center, radius: float, tube_radius: float, a0: float, a1: float,
           mat, steps: int = 16, downward: bool = True):
    """XZ düzleminde dairesel yay borusu (gülümseme / panel çizgisi)."""
    curve = bpy.data.curves.new(name + "_curve", "CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = 1
    curve.bevel_depth = tube_radius
    curve.bevel_resolution = 1
    curve.use_fill_caps = True
    spline = curve.splines.new("POLY")
    spline.points.add(steps)
    sign = -1.0 if downward else 1.0
    for i in range(steps + 1):
        a = a0 + (a1 - a0) * i / float(steps)
        x = center[0] + radius * math.cos(a)
        z = center[2] + sign * radius * math.sin(a)
        spline.points[i].co = (x, center[1], z, 1.0)
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    kit.activate(obj)
    bpy.ops.object.convert(target="MESH")
    obj = bpy.context.active_object
    if mat is not None:
        obj.data.materials.append(mat)
    return obj


def apply_vertex_gradient(obj, bottom: float = 0.80, top: float = 1.0) -> None:
    """Dikey gradyanı 'Color' vertex-renk katmanına yazar (alt koyu, üst açık)."""
    mesh = obj.data
    if "Color" in [attr.name for attr in mesh.color_attributes]:
        return
    attr = mesh.color_attributes.new(name="Color", type="FLOAT_COLOR", domain="CORNER")
    zs = [v.co.z for v in mesh.vertices]
    zmin, zmax = min(zs), max(zs)
    span = max(zmax - zmin, 1e-6)
    for poly in mesh.polygons:
        for li in poly.loop_indices:
            v = mesh.vertices[mesh.loops[li].vertex_index]
            t = (v.co.z - zmin) / span
            g = bottom + (top - bottom) * t
            attr.data[li].color = (g, g, g, 1.0)


def finalize_v2(obj, name: str, center_origin: bool = False):
    """Transformları uygula, origin sabitle, pürüzsüz gölgele + vertex gradyan."""
    kit.activate(obj)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")

    (min_x, min_y, min_z), (max_x, max_y, max_z) = kit.bounds(obj)
    if center_origin:
        offset = (-(min_x + max_x) / 2.0, -(min_y + max_y) / 2.0,
                  -(min_z + max_z) / 2.0)
    else:
        offset = (-(min_x + max_x) / 2.0, -(min_y + max_y) / 2.0, -min_z)
    obj.data.transform(Matrix.Translation(offset))
    obj.data.update()
    obj.location = (0.0, 0.0, 0.0)
    obj.rotation_euler = (0.0, 0.0, 0.0)
    obj.scale = (1.0, 1.0, 1.0)
    obj.name = name
    obj.data.name = name
    bpy.ops.object.shade_smooth()
    apply_vertex_gradient(obj)
    return obj


def export(obj, path: Path) -> None:
    kit.export_glb(obj, str(path),
                   extra={"export_vertex_color": "NAME",
                          "export_vertex_color_name": "Color"})


# ---------------------------------------------------------------------------
# 1. robot_body_v2.glb — tekerleksiz kurye gövdesi, ön = +Y (glTF -Z)
# ---------------------------------------------------------------------------
def build_robot_body():
    body = mat("body", ROBOT_TURQUOISE, roughness=0.42)
    accent = mat("accent", ROBOT_YELLOW, roughness=0.40)
    tire = mat("tire", TIRE_DARK, roughness=0.55)
    visor = mat("visor", VISOR_DARK, roughness=0.30, metallic=0.15)
    eye = mat("eye_emissive", EYE_GLOW, roughness=0.25,
              emission=EYE_EMISSIVE, emission_strength=4.5)
    metal = mat("metal", RIM_LIGHT, roughness=0.30, metallic=0.75)
    strap = mat("strap", WOOD_DARK, roughness=0.65)

    parts = []

    # ana gövde: elipsoid yumurta (smooth)
    parts.append(ellipsoid("Body", (ROBOT_BODY_RX, ROBOT_BODY_RY, ROBOT_BODY_RZ),
                           ROBOT_BODY_CENTER, body, segments=48, rings=28))

    # yüz visoru: öne hafif bombeli koyu ekran
    parts.append(ellipsoid("Visor", (VISOR_RX, VISOR_RY, VISOR_RZ), VISOR_CENTER,
                           visor, segments=28, rings=16))

    # gözler: iki parlak emisyon küre
    for side in (-1.0, 1.0):
        parts.append(uv_sphere("Eye%+.0f" % side, EYE_R,
                               (side * EYE_X, EYE_Y, EYE_Z), eye,
                               segments=20, rings=14))
    # gülümseme çizgisi (aşağı bombeli yay; parlak emisyon -> koyu visorda okunur)
    parts.append(arc_xz("Smile", SMILE_CENTER, SMILE_R, SMILE_TUBE,
                        0.0, math.pi, eye, steps=16, downward=True))

    # omuz sinyal lambası: silindir + kubbe
    parts.append(cylinder("LampBase", LAMP_R, LAMP_H, LAMP_POS, accent, vertices=14))
    parts.append(uv_sphere("LampDome", LAMP_R * 1.05,
                           (LAMP_POS[0], LAMP_POS[1], LAMP_POS[2] + LAMP_H / 2.0),
                           accent, segments=14, rings=10))

    # antenler: iki esnek direk + top uç
    for side in (-1.0, 1.0):
        x = side * ANTENNA_X
        z0 = ANTENNA_BASE[2]
        length = ANTENNA_TOP_Z - z0
        parts.append(cylinder("Antenna%+.0f" % side, ANTENNA_R, length,
                              (x, ANTENNA_BASE[1], z0 + length / 2.0),
                              accent, vertices=8))
        parts.append(uv_sphere("AntennaTip%+.0f" % side, ANTENNA_TIP_R,
                               (x, ANTENNA_BASE[1], ANTENNA_TOP_Z), accent,
                               segments=14, rings=10))

    # yan teslimat çantası: gövde + kapak + kayış bandı + toka
    parts.append(box("Bag", BAG_SIZE, BAG_CENTER, strap, bevel_width=0.012, segments=2))
    flap_c = (BAG_CENTER[0], BAG_CENTER[1], BAG_CENTER[2] + BAG_SIZE[2] / 2.0 - 0.006)
    parts.append(box("BagFlap", (BAG_SIZE[0] + 0.008, BAG_SIZE[1] + 0.002, BAG_FLAP_H),
                     flap_c, strap, bevel_width=0.008, segments=2))
    parts.append(box("BagStrap", (BAG_SIZE[0] + 0.006, BAG_SIZE[1] + 0.004, 0.012),
                     (BAG_CENTER[0], BAG_CENTER[1], BAG_CENTER[2] - BAG_SIZE[2] / 2.0 + 0.005),
                     strap, bevel_width=0.004, segments=1))
    parts.append(box("BagBuckle", (0.012, 0.006, 0.02),
                     (BAG_CENTER[0], BAG_CENTER[1] - BAG_SIZE[1] / 2.0 - 0.004,
                      BAG_CENTER[2] + BAG_SIZE[2] / 2.0 - 0.004),
                     metal, bevel_width=0.003, segments=1))

    # sırtta sepet oturma platosu
    parts.append(box("BasketPlatform", PLATFORM_SIZE, PLATFORM_CENTER,
                     tire, bevel_width=0.008, segments=2))
    parts.append(box("PlatformPad", (PLATFORM_SIZE[0] - 0.02, PLATFORM_SIZE[1] - 0.02, 0.006),
                     (PLATFORM_CENTER[0], PLATFORM_CENTER[1],
                      PLATFORM_CENTER[2] + PLATFORM_SIZE[2] / 2.0 + 0.002),
                     accent, bevel_width=0.003, segments=1))

    # alt süspansiyon: iki amortisör kolu + aks yuvası (tekerlek bağlantısı)
    for side in (-1.0, 1.0):
        x = side * SUSP_ARM_X
        parts.append(box("Arm%+.0f" % side, (0.05, 0.10, AXLE_Z - 0.04),
                         (x, AXLE_Y, (0.04 + AXLE_Z) / 2.0),
                         tire, bevel_width=0.012, segments=2))
        # aks yuvası: eksen X boyunca kısa silindir (tekerlek buraya oturur)
        parts.append(cylinder("AxleSocket%+.0f" % side, 0.030, 0.045,
                              (side * AXLE_X, AXLE_Y, AXLE_Z), tire,
                              vertices=12, rotation=(0.0, math.radians(90.0), 0.0)))
        # amortisör dikmesi (gövdeden kola)
        parts.append(cylinder("Shock%+.0f" % side, 0.012, 0.07,
                              (x, AXLE_Y - 0.035, 0.22), metal,
                              vertices=8))

    # küçük detaylar: cıvatalar, panel çizgisi, kurye logo rozeti
    for side in (-1.0, 1.0):
        for i, (by, bz) in enumerate(((-0.05, 0.26), (0.14, 0.22))):
            parts.append(cylinder("Bolt%d%+.0f" % (i, side), BOLT_R, BOLT_D,
                                  (side * (ROBOT_BODY_RX - 0.005), by, bz),
                                  metal, vertices=10,
                                  rotation=(0.0, math.radians(90.0), 0.0)))
    parts.append(arc_xz("PanelLine", (0.0, ROBOT_BODY_RY - 0.006, 0.30), 0.13, 0.0045,
                        0.0, math.pi, accent, steps=16, downward=False))
    # logo rozeti: ön göğüste küçük yuvarlak amblem
    parts.append(cylinder("Badge", 0.026, 0.006, (0.0, ROBOT_BODY_RY - 0.002, 0.50),
                          accent, vertices=16, rotation=(0.0, math.radians(90.0), 0.0)))
    parts.append(cylinder("BadgeDot", 0.009, 0.007, (0.0, ROBOT_BODY_RY - 0.001, 0.50),
                          metal, vertices=10, rotation=(0.0, math.radians(90.0), 0.0)))

    obj = kit.join(parts, "RobotBody")
    return finalize_v2(obj, "RobotBody")


# ---------------------------------------------------------------------------
# 2. robot_wheel_v2.glb — eksen X, origin MERKEZ, yarıçap 0.18
# ---------------------------------------------------------------------------
def build_robot_wheel():
    tire = mat("tire", TIRE_DARK, roughness=0.85)
    hub = mat("hub", RIM_LIGHT, roughness=0.28, metallic=0.8)
    accent = mat("accent", ROBOT_YELLOW, roughness=0.42)

    axis_x = (0.0, math.radians(90.0), 0.0)
    parts = [
        # kauçuk lastik: tek torus (torus kesiti zaten kavisli yan duvardır)
        torus("Tire", WHEEL_TIRE_MAJOR, WHEEL_TIRE_TUBE, (0.0, 0.0, 0.0), tire,
              rotation=axis_x, major_seg=24, minor_seg=10),
        # açık jant: dış halka + iç göbek
        torus("RimRing", WHEEL_RIM_MAJOR, WHEEL_RIM_TUBE, (0.0, 0.0, 0.0), hub,
              rotation=axis_x, major_seg=20, minor_seg=8),
        cylinder("Hub", WHEEL_HUB_R, WHEEL_HUB_D, (0.0, 0.0, 0.0), hub,
                 vertices=14, rotation=axis_x),
    ]

    # sığ diş deseni: lastik yüzeyinde küçük bloklar
    for index in range(WHEEL_TREAD_COUNT):
        angle = 2.0 * math.pi * index / WHEEL_TREAD_COUNT
        parts.append(box("Tread%d" % index, (WHEEL_TIRE_WIDTH * 0.5, 0.016, WHEEL_TREAD_RADIAL),
                         (0.0, (WHEEL_RADIUS - WHEEL_TREAD_RADIAL / 2.0) * math.cos(angle),
                          (WHEEL_RADIUS - WHEEL_TREAD_RADIAL / 2.0) * math.sin(angle)),
                         tire, bevel_width=0.004, segments=1,
                         rotation=(angle, 0.0, 0.0)))

    # jant telleri (açık jant)
    for index in range(WHEEL_SPOKE_COUNT):
        angle = 2.0 * math.pi * index / WHEEL_SPOKE_COUNT
        parts.append(box("Spoke%d" % index, (WHEEL_HUB_D * 0.55, 0.040, 0.022),
                         (0.0, (WHEEL_RIM_MAJOR * 0.62) * math.cos(angle),
                          (WHEEL_RIM_MAJOR * 0.62) * math.sin(angle)),
                         hub, bevel_width=0.005, segments=1,
                         rotation=(angle, 0.0, 0.0)))

    # merkez kapağı: iki tarafta küçük sarı kapak
    for side in (-1.0, 1.0):
        parts.append(cylinder("HubCap%+.0f" % side, WHEEL_CAP_R, WHEEL_CAP_D,
                              (side * (WHEEL_HUB_D / 2.0 + WHEEL_CAP_D / 2.0 - 0.002),
                               0.0, 0.0),
                              accent, vertices=12, rotation=axis_x))

    obj = kit.join(parts, "RobotWheel")
    return finalize_v2(obj, "RobotWheel", center_origin=True)


# ---------------------------------------------------------------------------
# 3. cargo_basket_v2.glb — yuvarlatılmış açık kasa, ~0.52 x 0.35 x 0.30
# ---------------------------------------------------------------------------
def build_cargo_basket():
    crate = mat("plastic_basket", ROBOT_YELLOW, roughness=0.62)
    accent = mat("accent", BASKET_ORANGE, roughness=0.50)
    label = mat("label", CREAM, roughness=0.72)

    hw, hd = BASKET_W / 2.0, BASKET_D / 2.0
    wall_top = BASKET_H - BASKET_RIM_H
    parts = [
        box("Floor", (BASKET_W, BASKET_D, BASKET_FLOOR),
            (0.0, 0.0, BASKET_FLOOR / 2.0), crate, bevel_width=BASKET_BEVEL, segments=2),
    ]

    # dört yuvarlatılmış duvar
    parts.append(box("WallL", (BASKET_WALL, BASKET_D, wall_top - BASKET_FLOOR),
                     (-hw + BASKET_WALL / 2.0, 0.0, BASKET_FLOOR + (wall_top - BASKET_FLOOR) / 2.0),
                     crate, bevel_width=BASKET_BEVEL * 0.7, segments=2))
    parts.append(box("WallR", (BASKET_WALL, BASKET_D, wall_top - BASKET_FLOOR),
                     (hw - BASKET_WALL / 2.0, 0.0, BASKET_FLOOR + (wall_top - BASKET_FLOOR) / 2.0),
                     crate, bevel_width=BASKET_BEVEL * 0.7, segments=2))
    parts.append(box("WallF", (BASKET_W - 2 * BASKET_WALL, BASKET_WALL, wall_top - BASKET_FLOOR),
                     (0.0, -hd + BASKET_WALL / 2.0, BASKET_FLOOR + (wall_top - BASKET_FLOOR) / 2.0),
                     crate, bevel_width=BASKET_BEVEL * 0.7, segments=2))
    parts.append(box("WallB", (BASKET_W - 2 * BASKET_WALL, BASKET_WALL, wall_top - BASKET_FLOOR),
                     (0.0, hd - BASKET_WALL / 2.0, BASKET_FLOOR + (wall_top - BASKET_FLOOR) / 2.0),
                     crate, bevel_width=BASKET_BEVEL * 0.7, segments=2))

    # turuncu üst çerçeve (rim)
    rim_th = BASKET_RIM_T
    parts.append(box("RimL", (rim_th, BASKET_D, BASKET_RIM_H),
                     (-hw + rim_th / 2.0, 0.0, wall_top + BASKET_RIM_H / 2.0),
                     accent, bevel_width=BASKET_BEVEL * 0.7, segments=2))
    parts.append(box("RimR", (rim_th, BASKET_D, BASKET_RIM_H),
                     (hw - rim_th / 2.0, 0.0, wall_top + BASKET_RIM_H / 2.0),
                     accent, bevel_width=BASKET_BEVEL * 0.7, segments=2))
    parts.append(box("RimF", (BASKET_W - 2 * rim_th, rim_th, BASKET_RIM_H),
                     (0.0, -hd + rim_th / 2.0, wall_top + BASKET_RIM_H / 2.0),
                     accent, bevel_width=BASKET_BEVEL * 0.7, segments=2))
    parts.append(box("RimB", (BASKET_W - 2 * rim_th, rim_th, BASKET_RIM_H),
                     (0.0, hd - rim_th / 2.0, wall_top + BASKET_RIM_H / 2.0),
                     accent, bevel_width=BASKET_BEVEL * 0.7, segments=2))

    # köşe dikmeleri (silueti güçlendirir)
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            cx = sx * (hw - BASKET_RIM_T / 2.0)
            cy = sy * (hd - BASKET_RIM_T / 2.0)
            parts.append(box("Post%+.0f%+.0f" % (sx, sy),
                             (BASKET_RIM_T * 1.1, BASKET_RIM_T * 1.1, BASKET_H),
                             (cx, cy, BASKET_H / 2.0),
                             accent, bevel_width=0.006, segments=2))

    # güçlendirme kaburgaları: uzun duvarlarda dikey şeritler
    for i in range(BASKET_RIB_COUNT):
        fy = -hd + (i + 1) * BASKET_D / (BASKET_RIB_COUNT + 1)
        parts.append(box("RibF%d" % i, (BASKET_RIB_W, 0.006, wall_top - BASKET_FLOOR - 0.01),
                         (0.0, fy, BASKET_FLOOR + (wall_top - BASKET_FLOOR) / 2.0),
                         accent, bevel_width=0.003, segments=1))
        parts.append(box("RibB%d" % i, (BASKET_RIB_W, 0.006, wall_top - BASKET_FLOOR - 0.01),
                         (0.0, -fy, BASKET_FLOOR + (wall_top - BASKET_FLOOR) / 2.0),
                         accent, bevel_width=0.003, segments=1))

    # kulplar: kısa kenarlarda dışa taşan barlar (genişliği değil derinliği aşar)
    handle_z = wall_top - 0.03
    for side in (-1.0, 1.0):
        parts.append(box("Handle%+.0f" % side, (BASKET_W * 0.55, 0.026, 0.022),
                         (0.0, side * (hd - 0.003), handle_z),
                         accent, bevel_width=0.006, segments=2))

    # etiket plakası: ön duvarda küçük krem plaka
    parts.append(box("LabelPlate", (0.10, 0.006, 0.055),
                     (0.0, -hd + BASKET_WALL + 0.004, 0.13),
                     label, bevel_width=0.003, segments=1))

    obj = kit.join(parts, "CargoBasket")
    return finalize_v2(obj, "CargoBasket")


# ---------------------------------------------------------------------------
# 4. cargo_pencil_battery_v2.glb — AA pil, yatay, <= 0.12 m
# ---------------------------------------------------------------------------
def build_battery():
    body = mat("body", PROP_GREEN, roughness=0.42)
    metal = mat("metal", SILVER, roughness=0.26, metallic=0.7)
    label = mat("label", CREAM, roughness=0.7)

    axis_y = (math.radians(90.0), 0.0, 0.0)
    half_body = BATTERY_BODY_D / 2.0
    cap_center = half_body + BATTERY_CAP_D / 2.0
    nub_center = half_body + BATTERY_CAP_D + BATTERY_NUB_D / 2.0

    parts = [
        cylinder("Body", BATTERY_R, BATTERY_BODY_D, (0.0, 0.0, 0.0), body,
                 vertices=20, rotation=axis_y),
        cylinder("CapPlus", BATTERY_R * 1.005, BATTERY_CAP_D, (0.0, cap_center, 0.0),
                 metal, vertices=20, rotation=axis_y),
        cylinder("CapMinus", BATTERY_R * 1.005, BATTERY_CAP_D, (0.0, -cap_center, 0.0),
                 metal, vertices=20, rotation=axis_y),
        cylinder("Nub", BATTERY_NUB_R, BATTERY_NUB_D, (0.0, nub_center, 0.0),
                 metal, vertices=12, rotation=axis_y),
    ]
    # metal bant (pozitif uca yakın)
    parts.append(cylinder("Band", BATTERY_R * 1.006, BATTERY_BAND_D,
                          (0.0, half_body - 0.02, 0.0), metal, vertices=20,
                          rotation=axis_y))
    # ince etiket şeritleri
    for i, y in enumerate((-0.02, 0.0, 0.02)):
        parts.append(cylinder("Label%d" % i, BATTERY_R * 1.004, BATTERY_LABEL_W,
                              (0.0, y, 0.0), label, vertices=20, rotation=axis_y))

    obj = kit.join(parts, "CargoBattery")
    return finalize_v2(obj, "CargoBattery")


# ---------------------------------------------------------------------------
# 5. cargo_sd_card_v2.glb — mavi ince kart, kesik köşe, altın temaslar
# ---------------------------------------------------------------------------
def build_sd_card():
    body = mat("body", PROP_BLUE, roughness=0.40)
    metal = mat("metal", GOLD, roughness=0.24, metallic=0.9)
    label = mat("label", CREAM, roughness=0.7)

    hw, hl = SD_CARD_W / 2.0, SD_CARD_L / 2.0
    points = [(-hw, -hl), (hw, -hl), (hw, hl - SD_CHAMFER),
              (hw - SD_CHAMFER, hl), (-hw, hl)]

    parts = [_prism("Card", points, 0.0, SD_CARD_T, body, bevel_width=0.002, segments=1)]

    # altın temaslar (alt kenarda)
    contact_gap = 0.003
    total = SD_CONTACT_COUNT * SD_CONTACT_W + (SD_CONTACT_COUNT - 1) * contact_gap
    x0 = -total / 2.0
    for index in range(SD_CONTACT_COUNT):
        cx = x0 + index * (SD_CONTACT_W + contact_gap) + SD_CONTACT_W / 2.0
        parts.append(box("Contact%d" % index,
                         (SD_CONTACT_W, SD_CONTACT_L, SD_CONTACT_T),
                         (cx, -hl + 0.006 + SD_CONTACT_L / 2.0,
                          SD_CARD_T / 2.0),
                         metal, bevel_width=0.0004, segments=1))

    # etiket alanı
    parts.append(box("Label", (SD_LABEL_W, SD_LABEL_L, 0.002),
                     (0.0, 0.010 + SD_LABEL_L / 2.0, SD_CARD_T + 0.001),
                     label, bevel_width=0.0006, segments=1))

    # kilit anahtarı (yan kenarda küçük sürgü)
    parts.append(box("LockSwitch", (0.006, SD_LOCK_L, SD_CARD_T * 0.9),
                     (-hw + 0.004, hl - SD_CHAMFER - 0.028, SD_CARD_T / 2.0),
                     metal, bevel_width=0.001, segments=1))

    obj = kit.join(parts, "CargoSdCard")
    return finalize_v2(obj, "CargoSdCard")


def _prism(name, points, z0, z1, mat, bevel_width=0.0, segments=1):
    """XY düzlemindeki çokgeni Z boyunca extruder (SD kart kesik köşesi)."""
    count = len(points)
    verts = [(x, y, z0) for x, y in points] + [(x, y, z1) for x, y in points]
    faces = [tuple(range(count - 1, -1, -1)), tuple(range(count, 2 * count))]
    for index in range(count):
        nxt = (index + 1) % count
        faces.append((index, nxt, count + nxt, count + index))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    kit.activate(obj)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if bevel_width > 0.0:
        kit.bevel(obj, bevel_width, segments)
    if mat is not None:
        obj.data.materials.append(mat)
    return obj


# ---------------------------------------------------------------------------
# 6. cargo_espresso_capsule_v2.glb — tırtıklı gövde, alüminyum kapak
# ---------------------------------------------------------------------------
def build_capsule():
    body = mat("body", PROP_RED, roughness=0.40)
    metal = mat("metal", ALUMINUM, roughness=0.28, metallic=0.85)

    parts = [
        cone("Cup", CAPSULE_R_BOTTOM, CAPSULE_R_TOP, CAPSULE_BODY_H,
             (0.0, 0.0, CAPSULE_BODY_H / 2.0), body, vertices=20,
             bevel_width=0.003),
    ]
    # tırtıklı gövde: çevre boyunca ince dikey kaburgalar
    for index in range(CAPSULE_RIDGE_COUNT):
        angle = 2.0 * math.pi * index / CAPSULE_RIDGE_COUNT
        rr = (CAPSULE_R_BOTTOM + CAPSULE_R_TOP) / 2.0 + 0.002
        parts.append(box("Ridge%d" % index,
                         (0.004, 0.003, CAPSULE_BODY_H * 0.86),
                         (rr * math.cos(angle), rr * math.sin(angle),
                          CAPSULE_BODY_H / 2.0),
                         body, bevel_width=0.001, segments=1))

    # alüminyum kapak + kenar halkası
    lid_top = CAPSULE_BODY_H
    parts.append(cylinder("Lid", CAPSULE_LID_R, CAPSULE_LID_H,
                          (0.0, 0.0, lid_top + CAPSULE_LID_H / 2.0), metal,
                          vertices=20))
    parts.append(torus("LidRing", CAPSULE_LID_R * 0.9, 0.005,
                       (0.0, 0.0, lid_top + CAPSULE_LID_H), metal,
                       major_seg=20, minor_seg=8))
    parts.append(cylinder("LidDimple", CAPSULE_LID_R * 0.22, 0.003,
                          (0.0, 0.0, lid_top + CAPSULE_LID_H + 0.002), metal,
                          vertices=10))

    obj = kit.join(parts, "CargoCapsule")
    return finalize_v2(obj, "CargoCapsule")


# ---------------------------------------------------------------------------
# ana akış
# ---------------------------------------------------------------------------
BUILDERS = [
    ("robot_body_v2.glb", build_robot_body),
    ("robot_wheel_v2.glb", build_robot_wheel),
    ("cargo_basket_v2.glb", build_cargo_basket),
    ("cargo_pencil_battery_v2.glb", build_battery),
    ("cargo_sd_card_v2.glb", build_sd_card),
    ("cargo_espresso_capsule_v2.glb", build_capsule),
]


def main() -> int:
    models_dir = PROJECT_ROOT / "assets" / "models" / "v2"
    models_dir.mkdir(parents=True, exist_ok=True)

    total = 0
    for filename, builder in BUILDERS:
        kit.reset()
        obj = builder()
        path = models_dir / filename
        export(obj, path)
        kit.report(obj, str(path))
        total += kit.triangle_count(obj)

    print("TOTAL_MODELS %d" % len(BUILDERS))
    print("TOTAL_TRIS %d" % total)
    print("OUT_DIR %s" % models_dir)
    return 0


if __name__ == "__main__":
    sys.exit(main())
