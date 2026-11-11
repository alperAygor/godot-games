#!/usr/bin/env python3
"""MikroKurye — V1 low-poly model seti (Blender 5.x, headless).

Kaynak = bu betik; GLB'ler üretilmiş çıktıdır. Tek komut:

    /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/make_models.py

Sözleşme (studio-kit/tools/validate_glb.py):
  * tek mesh, transformlar uygulanmış -> node'da TRS yok
  * origin ALT-MERKEZ (min Y = 0, X/Z merkez = 0), metre ölçek
  * düz gölgeleme, dokusuz, doygun palet, hafif bevel
  * Blender +Y = glTF -Z = robotun ÖNÜ; lamba/yüz +Y tarafında

Tekerlek de ALT-MERKEZ'de üretilir: validate_glb istisna kabul etmediği için
(minY=0 zorunlu) dönme ekseni tekerleğin merkezinden değil, zemine değen alt
noktasından geçer; sahneye yerleştirirken merkez = origin + (0, 0.18, 0).

1 birim = 1 metre. Robot ~0.8 m; masa eşyaları robota göre dev ölçekli.
"""

import math
import os
import sys
from pathlib import Path

import bpy
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
# palet — PROJECT_SPEC.md §13 (hex sRGB)
# ---------------------------------------------------------------------------
ROBOT_TURQUOISE = "#2EE6C5"   # robot ana
ROBOT_YELLOW = "#FFC83D"      # robot vurgu: lamba, şerit, anten
TIRE_DARK = "#2B2F3A"         # lastik / koyu aksam
RIM_LIGHT = "#B8C0CC"         # jant / metal
WOOD = "#D9A066"              # masa ahşabı, kalem traşı
WOOD_DARK = "#B07A45"         # ahşap kenar
PROP_RED = "#F25F5C"          # kupa, kapsül, silgi
PROP_BLUE = "#4D9DE0"         # SD kart, cetvel
PROP_YELLOW = "#F7B801"       # kalem, tehlike şeridi
PROP_GREEN = "#7BC86C"        # pil, kitap
BG_WARM = "#FFE8C7"           # önizleme arka planı
BG_SKY = "#BFE3F2"            # önizleme gökyüzü (yedek)
DANGER_RED = "#FF4D4D"        # tehlike vurgusu
CREAM = "#FFF0D2"             # sayfa kenarı, tuş, çentik
BASKET_ORANGE = "#EF8B2C"     # sepet kenarı
GOLD = "#E3B64B"              # SD temas
SILVER = "#C9CED6"            # pil kapağı, kapsül detayı
MUG_INNER = "#6E1F1E"         # kupa içi
BOOK_SPINE = "#5AA34E"        # kitap sırtı / başlık

# ---------------------------------------------------------------------------
# ölçüler — robot (metre)
# ---------------------------------------------------------------------------
ROBOT_LENGTH = 0.80
ROBOT_REAR_Y = -ROBOT_LENGTH / 2.0       # -0.40
ROBOT_FRONT_Y = ROBOT_LENGTH / 2.0       # +0.40
ROBOT_BODY_W = 0.44
ROBOT_BODY_Y0 = -0.36
ROBOT_BODY_Y1 = 0.24
ROBOT_BODY_Z0 = 0.16
ROBOT_BODY_Z1 = 0.50
ROBOT_BODY_BEVEL = 0.09
ROBOT_NOSE_W = 0.36
ROBOT_NOSE_Y0 = 0.19
ROBOT_NOSE_Y1 = 0.385
ROBOT_NOSE_Z0 = 0.18
ROBOT_NOSE_Z1 = 0.44
ROBOT_NOSE_BEVEL = 0.07
ROBOT_REAR_BUMPER_Y0 = ROBOT_REAR_Y
ROBOT_REAR_BUMPER_Y1 = -0.34
ROBOT_REAR_BUMPER_W = 0.40
ROBOT_REAR_BUMPER_Z0 = 0.17
ROBOT_REAR_BUMPER_Z1 = 0.42
ROBOT_PLATFORM_W = 0.52
ROBOT_PLATFORM_Y0 = ROBOT_REAR_Y
ROBOT_PLATFORM_Y1 = -0.05
ROBOT_PLATFORM_Z0 = 0.49
ROBOT_PLATFORM_Z1 = 0.52
ROBOT_PLATFORM_PAD_W = 0.48
ROBOT_PLATFORM_PAD_Y0 = ROBOT_PLATFORM_Y0 + 0.010
ROBOT_PLATFORM_PAD_Y1 = ROBOT_PLATFORM_Y1 - 0.010
ROBOT_FACE_W = 0.26
ROBOT_FACE_Z0 = 0.26
ROBOT_FACE_Z1 = 0.40
ROBOT_FACE_Y0 = 0.380
ROBOT_FACE_Y1 = 0.400
ROBOT_EYE_X = 0.065
ROBOT_EYE_Z = 0.345
ROBOT_EYE_R = 0.030
ROBOT_EYE_DEPTH = 0.012
ROBOT_EYE_Y = 0.402
ROBOT_ANTENNA_X = 0.13
ROBOT_ANTENNA_Y = 0.10
ROBOT_ANTENNA_Z0 = 0.49
ROBOT_ANTENNA_Z1 = 0.68
ROBOT_ANTENNA_R = 0.008
ROBOT_ANTENNA_TIP_R = 0.018
ROBOT_SIDE_STRIPE_Z0 = 0.21
ROBOT_SIDE_STRIPE_Z1 = 0.255
ROBOT_SIDE_STRIPE_Y0 = -0.30
ROBOT_SIDE_STRIPE_Y1 = 0.18
ROBOT_SIDE_STRIPE_X = 0.222
ROBOT_SIDE_STRIPE_T = 0.008
ROBOT_FRONT_STRIPE_W = 0.30
ROBOT_FORK_X0 = 0.14
ROBOT_FORK_X1 = 0.20
ROBOT_FORK_Y0 = -0.10
ROBOT_FORK_Y1 = 0.10
ROBOT_FORK_Z1 = 0.18
ROBOT_FORK_BEVEL = 0.015
ROBOT_AXLE_CAP_R = 0.035
ROBOT_AXLE_CAP_D = 0.012

# ---------------------------------------------------------------------------
# ölçüler — tekerlek (metre)
# ---------------------------------------------------------------------------
WHEEL_RADIUS = 0.18
WHEEL_TIRE_TUBE = 0.045
WHEEL_TIRE_MAJOR = WHEEL_RADIUS - WHEEL_TIRE_TUBE   # 0.135
WHEEL_TIRE_MAJOR_SEG = 18
WHEEL_TIRE_MINOR_SEG = 8
WHEEL_RIM_MAJOR = 0.096
WHEEL_RIM_TUBE = 0.018
WHEEL_HUB_R = 0.034
WHEEL_HUB_D = 0.100
WHEEL_CAP_R = 0.026
WHEEL_CAP_D = 0.012
WHEEL_SPOKE_COUNT = 5
WHEEL_SPOKE_AXIAL = 0.055
WHEEL_SPOKE_RADIAL = 0.140
WHEEL_SPOKE_TANGENT = 0.028
WHEEL_SPOKE_RADIUS = 0.068
WHEEL_TREAD_COUNT = 10
WHEEL_TREAD_AXIAL = 0.100
WHEEL_TREAD_RADIAL = 0.028
WHEEL_TREAD_TANGENT = 0.024
WHEEL_TREAD_RADIUS = 0.166

# ---------------------------------------------------------------------------
# ölçüler — sepet (metre)
# ---------------------------------------------------------------------------
BASKET_W = 0.50
BASKET_D = 0.35
BASKET_H = 0.30
BASKET_WALL = 0.022
BASKET_FLOOR = 0.024
BASKET_RIM_H = 0.035
BASKET_RIM_T = 0.020
BASKET_POST = 0.030
BASKET_BEVEL = 0.008

# ---------------------------------------------------------------------------
# ölçüler — kargo (metre; her biri <= 0.12 m)
# ---------------------------------------------------------------------------
BATTERY_BODY_D = 0.090
BATTERY_R = 0.030
BATTERY_CAP_D = 0.008
BATTERY_CAP_R = 0.031
BATTERY_NUB_R = 0.012
BATTERY_NUB_D = 0.008
BATTERY_BAND_D = 0.004
BATTERY_BAND_R = 0.0305

SD_CARD_L = 0.120
SD_CARD_W = 0.080
SD_CARD_T = 0.008
SD_CHAMFER = 0.015
SD_CONTACT_COUNT = 4
SD_CONTACT_W = 0.012
SD_CONTACT_L = 0.035
SD_CONTACT_T = 0.0015
SD_LABEL_W = 0.055
SD_LABEL_L = 0.040

CAPSULE_R_BOTTOM = 0.032
CAPSULE_R_TOP = 0.045
CAPSULE_BODY_H = 0.045
CAPSULE_LID_R = 0.047
CAPSULE_LID_H = 0.012

# ---------------------------------------------------------------------------
# ölçüler — masa eşyaları (robota göre dev ölçek)
# ---------------------------------------------------------------------------
KEY_W = 0.70
KEY_D = 0.70
KEY_H = 0.42
KEY_GAP = 0.06
KEY_COUNT = 3
KEY_BASE_H = 0.12
KEY_BASE_D = 0.90
KEY_BASE_BEVEL = 0.030
KEY_TOP_SCALE = 0.86
KEY_BEVEL = 0.055
KEY_BASE_W = KEY_COUNT * KEY_W + (KEY_COUNT + 1) * KEY_GAP   # 2.40
HAZARD_H = 0.060
HAZARD_T = 0.006
HAZARD_BLACK_T = 0.003
HAZARD_Z0 = 0.030

MUG_H = 2.40
MUG_R = 0.86
MUG_BASE_R = 0.90
MUG_BASE_H = 0.12
MUG_BODY_Z0 = 0.10
MUG_BODY_Z1 = 2.28
MUG_RIM_MAJOR = 0.800
MUG_RIM_TUBE = 0.085
MUG_INNER_R = 0.780
MUG_INNER_H = 0.060
MUG_HANDLE_MAJOR = 0.420
MUG_HANDLE_TUBE = 0.130
MUG_HANDLE_X = 0.860
MUG_HANDLE_Z = 1.250
MUG_BAND_R = 0.862
MUG_BAND_H = 0.120
MUG_BAND_Z = 1.550

PENCIL_LENGTH = 8.0
PENCIL_R = 0.25
PENCIL_TIP_L = 0.65
PENCIL_GRAPHITE_L = 0.20
PENCIL_FERRULE_D = 0.18
PENCIL_ERASER_D = 0.15
PENCIL_ERASER_R = 0.24
PENCIL_FERRULE_R = 0.265
PENCIL_TIP_R = 0.055

RULER_L = 12.0
RULER_W = 1.2
RULER_T = 0.10
RULER_BEVEL = 0.018
RULER_TICK_T = 0.007
RULER_MAJOR_W = 0.055
RULER_MINOR_W = 0.040
RULER_MAJOR_X = 0.410
RULER_MINOR_X = 0.260
RULER_STEP = 1.0

BOOK_W = 3.5
BOOK_L = 5.0
BOOK_H = 0.6
BOOK_COVER_T = 0.07
BOOK_PAGE_INSET = 0.07
BOOK_BEVEL = 0.012
BOOK_TITLE_H = 0.008


# ---------------------------------------------------------------------------
# yardımcılar (blender_kit primitiflerini tamamlar)
# ---------------------------------------------------------------------------
def add_torus(name, major_r, tube_r, location, mat, rotation=(0.0, 0.0, 0.0),
              major_seg=16, minor_seg=6):
    bpy.ops.mesh.primitive_torus_add(major_radius=major_r, minor_radius=tube_r,
                                     major_segments=major_seg,
                                     minor_segments=minor_seg,
                                     location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    kit.activate(obj)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    obj.data.materials.append(mat)
    return obj


def add_cone(name, r1, r2, depth, location, mat, vertices=12,
             rotation=(0.0, 0.0, 0.0), bevel_width=0.0):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=r1, radius2=r2,
                                    depth=depth, location=location,
                                    rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    kit.activate(obj)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    kit.bevel(obj, bevel_width, 1)
    obj.data.materials.append(mat)
    return obj


def add_ico(name, radius, location, mat, subdivisions=1):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=radius,
                                          location=location)
    obj = bpy.context.active_object
    obj.name = name
    kit.activate(obj)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    obj.data.materials.append(mat)
    return obj


def add_box_rot(name, size, location, mat, rotation=(0.0, 0.0, 0.0),
                bevel_width=0.0, segments=2):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    kit.activate(obj)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    kit.bevel(obj, bevel_width, segments)
    obj.data.materials.append(mat)
    return obj


def add_prism(name, points, z0, z1, mat, bevel_width=0.0, segments=1):
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
    kit.bevel(obj, bevel_width, segments)
    obj.data.materials.append(mat)
    return obj


def mat(name, color, roughness=0.6, metallic=0.0):
    return kit.material("MK_" + name, color, roughness=roughness, metallic=metallic)


# ---------------------------------------------------------------------------
# 1. robot_body.glb — tekerleksiz kurye gövdesi, ön = +Y (glTF -Z)
# ---------------------------------------------------------------------------
def build_robot_body():
    turquoise = mat("Robot_Turquoise", ROBOT_TURQUOISE, roughness=0.55)
    yellow = mat("Robot_Yellow", ROBOT_YELLOW, roughness=0.45)
    dark = mat("Robot_Dark", TIRE_DARK, roughness=0.55)

    parts = []

    # ana gövde: geniş bevel -> yuvarlatılmış siluet
    parts.append(kit.box_bounds("BodyMain", -ROBOT_BODY_W / 2.0, ROBOT_BODY_W / 2.0,
                                ROBOT_BODY_Y0, ROBOT_BODY_Y1,
                                ROBOT_BODY_Z0, ROBOT_BODY_Z1,
                                turquoise, ROBOT_BODY_BEVEL, 3))
    # ön burun: gövdeyle aynı malzeme, yüz plakasını taşır
    parts.append(kit.box_bounds("Nose", -ROBOT_NOSE_W / 2.0, ROBOT_NOSE_W / 2.0,
                                ROBOT_NOSE_Y0, ROBOT_NOSE_Y1,
                                ROBOT_NOSE_Z0, ROBOT_NOSE_Z1,
                                turquoise, ROBOT_NOSE_BEVEL, 3))
    # arka tampon: koyu, sepet platformunu dengeler
    parts.append(kit.box_bounds("RearBumper", -ROBOT_REAR_BUMPER_W / 2.0,
                                ROBOT_REAR_BUMPER_W / 2.0,
                                ROBOT_REAR_BUMPER_Y0, ROBOT_REAR_BUMPER_Y1,
                                ROBOT_REAR_BUMPER_Z0, ROBOT_REAR_BUMPER_Z1,
                                dark, 0.025, 2))
    # sepet oturma platosu (düz) + sarı ped
    parts.append(kit.box_bounds("BasketPlatform", -ROBOT_PLATFORM_W / 2.0,
                                ROBOT_PLATFORM_W / 2.0,
                                ROBOT_PLATFORM_Y0, ROBOT_PLATFORM_Y1,
                                ROBOT_PLATFORM_Z0, ROBOT_PLATFORM_Z1,
                                dark, 0.010, 2))
    parts.append(kit.box_bounds("PlatformPad", -ROBOT_PLATFORM_PAD_W / 2.0,
                                ROBOT_PLATFORM_PAD_W / 2.0,
                                ROBOT_PLATFORM_PAD_Y0, ROBOT_PLATFORM_PAD_Y1,
                                ROBOT_PLATFORM_Z1, ROBOT_PLATFORM_Z1 + 0.008,
                                yellow, 0.004, 1))

    # yüz plakası: sarı kafa lambası + iki koyu lens (ön +Y)
    parts.append(kit.box_bounds("FacePlate", -ROBOT_FACE_W / 2.0, ROBOT_FACE_W / 2.0,
                                ROBOT_FACE_Y0, ROBOT_FACE_Y1,
                                ROBOT_FACE_Z0, ROBOT_FACE_Z1, yellow, 0.015, 2))
    for side in (-1.0, 1.0):
        parts.append(kit.cylinder("Eye%+.0f" % side, ROBOT_EYE_R, ROBOT_EYE_DEPTH,
                                  (side * ROBOT_EYE_X, ROBOT_EYE_Y, ROBOT_EYE_Z),
                                  dark, vertices=10, rotation=(math.radians(90.0), 0.0, 0.0)))

    # yan şeritler + ön şerit (sarı vurgu)
    for side in (-1.0, 1.0):
        parts.append(kit.box_bounds("SideStripe%+.0f" % side,
                                    side * ROBOT_SIDE_STRIPE_X - ROBOT_SIDE_STRIPE_T / 2.0,
                                    side * ROBOT_SIDE_STRIPE_X + ROBOT_SIDE_STRIPE_T / 2.0,
                                    ROBOT_SIDE_STRIPE_Y0, ROBOT_SIDE_STRIPE_Y1,
                                    ROBOT_SIDE_STRIPE_Z0, ROBOT_SIDE_STRIPE_Z1,
                                    yellow, 0.003, 1))
    parts.append(kit.box_bounds("FrontStripe", -ROBOT_FRONT_STRIPE_W / 2.0,
                                ROBOT_FRONT_STRIPE_W / 2.0,
                                ROBOT_NOSE_Y1 - 0.002, ROBOT_NOSE_Y1 + 0.006,
                                ROBOT_SIDE_STRIPE_Z0, ROBOT_SIDE_STRIPE_Z1,
                                yellow, 0.003, 1))

    # tekerlek yuvası: iki koyu çatal + üst köprü; arada 0.28 m boşluk
    for side in (-1.0, 1.0):
        x0 = side * ROBOT_FORK_X0
        x1 = side * ROBOT_FORK_X1
        parts.append(kit.box_bounds("Fork%+.0f" % side, min(x0, x1), max(x0, x1),
                                    ROBOT_FORK_Y0, ROBOT_FORK_Y1, 0.0, ROBOT_FORK_Z1,
                                    dark, ROBOT_FORK_BEVEL, 2))
        parts.append(kit.cylinder("AxleCap%+.0f" % side, ROBOT_AXLE_CAP_R,
                                  ROBOT_AXLE_CAP_D,
                                  (side * (ROBOT_FORK_X1 + 0.002), 0.0,
                                   ROBOT_FORK_Z1),
                                  yellow, vertices=10,
                                  rotation=(0.0, math.radians(90.0), 0.0)))
    parts.append(kit.box_bounds("ForkBridge", -ROBOT_FORK_X0, ROBOT_FORK_X0,
                                ROBOT_FORK_Y0, ROBOT_FORK_Y1,
                                ROBOT_FORK_Z1 - 0.04, ROBOT_FORK_Z1,
                                dark, 0.010, 2))

    # antenler: gövde tepesinde, sepete çarpmayan ön konum
    for side in (-1.0, 1.0):
        parts.append(kit.cylinder("Antenna%+.0f" % side, ROBOT_ANTENNA_R,
                                  ROBOT_ANTENNA_Z1 - ROBOT_ANTENNA_Z0,
                                  (side * ROBOT_ANTENNA_X, ROBOT_ANTENNA_Y,
                                   (ROBOT_ANTENNA_Z0 + ROBOT_ANTENNA_Z1) / 2.0),
                                  yellow, vertices=6))
        parts.append(add_ico("AntennaTip%+.0f" % side, ROBOT_ANTENNA_TIP_R,
                             (side * ROBOT_ANTENNA_X, ROBOT_ANTENNA_Y,
                              ROBOT_ANTENNA_Z1 + ROBOT_ANTENNA_TIP_R * 0.4),
                             yellow, subdivisions=1))

    obj = kit.join(parts, "RobotBody")
    return kit.finalize(obj, "RobotBody")


# ---------------------------------------------------------------------------
# 2. robot_wheel.glb — eksen X, alt-merkez origin, yarıçap 0.18
# ---------------------------------------------------------------------------
def build_robot_wheel():
    dark = mat("Wheel_Tire", TIRE_DARK, roughness=0.85)
    silver = mat("Wheel_Rim", RIM_LIGHT, roughness=0.30, metallic=0.75)
    yellow = mat("Wheel_Hub", ROBOT_YELLOW, roughness=0.45)

    parts = [
        add_torus("Tire", WHEEL_TIRE_MAJOR, WHEEL_TIRE_TUBE, (0.0, 0.0, 0.0), dark,
                  rotation=(0.0, math.radians(90.0), 0.0),
                  major_seg=WHEEL_TIRE_MAJOR_SEG, minor_seg=WHEEL_TIRE_MINOR_SEG),
        add_torus("RimRing", WHEEL_RIM_MAJOR, WHEEL_RIM_TUBE, (0.0, 0.0, 0.0), silver,
                  rotation=(0.0, math.radians(90.0), 0.0), major_seg=18, minor_seg=6),
        kit.cylinder("Hub", WHEEL_HUB_R, WHEEL_HUB_D, (0.0, 0.0, 0.0), silver,
                     vertices=12, rotation=(0.0, math.radians(90.0), 0.0)),
    ]
    for index in range(WHEEL_SPOKE_COUNT):
        angle = 2.0 * math.pi * index / WHEEL_SPOKE_COUNT
        parts.append(add_box_rot("Spoke%d" % index,
                                 (WHEEL_SPOKE_AXIAL, WHEEL_SPOKE_RADIAL,
                                  WHEEL_SPOKE_TANGENT),
                                 (0.0, WHEEL_SPOKE_RADIUS * math.cos(angle),
                                  WHEEL_SPOKE_RADIUS * math.sin(angle)),
                                 silver, rotation=(angle, 0.0, 0.0), bevel_width=0.006,
                                 segments=1))
    for index in range(WHEEL_TREAD_COUNT):
        angle = 2.0 * math.pi * index / WHEEL_TREAD_COUNT
        parts.append(add_box_rot("Tread%d" % index,
                                 (WHEEL_TREAD_AXIAL, WHEEL_TREAD_RADIAL,
                                  WHEEL_TREAD_TANGENT),
                                 (0.0, WHEEL_TREAD_RADIUS * math.cos(angle),
                                  WHEEL_TREAD_RADIUS * math.sin(angle)),
                                 dark, rotation=(angle, 0.0, 0.0), bevel_width=0.004,
                                 segments=1))
    for side in (-1.0, 1.0):
        parts.append(kit.cylinder("HubCap%+.0f" % side, WHEEL_CAP_R, WHEEL_CAP_D,
                                  (side * (WHEEL_HUB_D / 2.0 + WHEEL_CAP_D / 2.0 - 0.002),
                                   0.0, 0.0),
                                  yellow, vertices=10,
                                  rotation=(0.0, math.radians(90.0), 0.0)))

    obj = kit.join(parts, "RobotWheel")
    return kit.finalize(obj, "RobotWheel")


# ---------------------------------------------------------------------------
# 3. cargo_basket.glb — açık üstlü sepet, 0.5 x 0.35 x 0.30
# ---------------------------------------------------------------------------
def build_cargo_basket():
    yellow = mat("Basket_Yellow", ROBOT_YELLOW, roughness=0.65)
    orange = mat("Basket_Orange", BASKET_ORANGE, roughness=0.55)

    hw, hd = BASKET_W / 2.0, BASKET_D / 2.0
    wall_top = BASKET_H - BASKET_RIM_H
    parts = [
        kit.box_bounds("Floor", -hw, hw, -hd, hd, 0.0, BASKET_FLOOR,
                       yellow, BASKET_BEVEL, 2),
    ]
    # dört duvar; üstte rim için 0.035 m pay
    parts.append(kit.box_bounds("WallL", -hw, -hw + BASKET_WALL, -hd, hd,
                                BASKET_FLOOR, wall_top, yellow, BASKET_BEVEL, 2))
    parts.append(kit.box_bounds("WallR", hw - BASKET_WALL, hw, -hd, hd,
                                BASKET_FLOOR, wall_top, yellow, BASKET_BEVEL, 2))
    parts.append(kit.box_bounds("WallF", -hw + BASKET_WALL, hw - BASKET_WALL,
                                -hd, -hd + BASKET_WALL, BASKET_FLOOR, wall_top,
                                yellow, BASKET_BEVEL, 2))
    parts.append(kit.box_bounds("WallB", -hw + BASKET_WALL, hw - BASKET_WALL,
                                hd - BASKET_WALL, hd, BASKET_FLOOR, wall_top,
                                yellow, BASKET_BEVEL, 2))
    # turuncu rim: dış yüzeyle aynı hizada, içe doğru kalın
    parts.append(kit.box_bounds("RimL", -hw, -hw + BASKET_RIM_T, -hd, hd,
                                wall_top, BASKET_H, orange, BASKET_BEVEL, 2))
    parts.append(kit.box_bounds("RimR", hw - BASKET_RIM_T, hw, -hd, hd,
                                wall_top, BASKET_H, orange, BASKET_BEVEL, 2))
    parts.append(kit.box_bounds("RimF", -hw + BASKET_RIM_T, hw - BASKET_RIM_T,
                                -hd, -hd + BASKET_RIM_T, wall_top, BASKET_H,
                                orange, BASKET_BEVEL, 2))
    parts.append(kit.box_bounds("RimB", -hw + BASKET_RIM_T, hw - BASKET_RIM_T,
                                hd - BASKET_RIM_T, hd, wall_top, BASKET_H,
                                orange, BASKET_BEVEL, 2))
    # köşe dikmeleri: silueti sepet gibi okutur
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            cx = sx * (hw - BASKET_POST / 2.0)
            cy = sy * (hd - BASKET_POST / 2.0)
            parts.append(kit.box_bounds("Post%+.0f%+.0f" % (sx, sy),
                                        cx - BASKET_POST / 2.0, cx + BASKET_POST / 2.0,
                                        cy - BASKET_POST / 2.0, cy + BASKET_POST / 2.0,
                                        BASKET_FLOOR, wall_top + 0.001,
                                        orange, 0.006, 2))
    # yan tutamaklar: kısa kenarlarda dışa taşan ince barlar
    handle_z = wall_top - 0.035
    for side in (-1.0, 1.0):
        parts.append(kit.box_bounds("Handle%+.0f" % side,
                                    side * (hw + 0.004) - 0.008,
                                    side * (hw + 0.004) + 0.008,
                                    -0.06, 0.06, handle_z, handle_z + 0.028,
                                    orange, 0.005, 2))

    obj = kit.join(parts, "CargoBasket")
    return kit.finalize(obj, "CargoBasket")


# ---------------------------------------------------------------------------
# 4. cargo_pencil_battery.glb — yeşil/gümüş silindir, <= 0.12 m
# ---------------------------------------------------------------------------
def build_battery():
    green = mat("Battery_Green", PROP_GREEN, roughness=0.45)
    silver = mat("Battery_Silver", SILVER, roughness=0.30, metallic=0.65)

    axis_y = (math.radians(90.0), 0.0, 0.0)
    half_body = BATTERY_BODY_D / 2.0
    cap_center = half_body + BATTERY_CAP_D / 2.0
    nub_center = half_body + BATTERY_CAP_D + BATTERY_NUB_D / 2.0
    parts = [
        kit.cylinder("BatteryBody", BATTERY_R, BATTERY_BODY_D, (0.0, 0.0, 0.0),
                     green, vertices=16, rotation=axis_y),
        kit.cylinder("CapPlus", BATTERY_CAP_R, BATTERY_CAP_D,
                     (0.0, cap_center, 0.0), silver, vertices=16, rotation=axis_y),
        kit.cylinder("CapMinus", BATTERY_CAP_R, BATTERY_CAP_D,
                     (0.0, -cap_center, 0.0), silver, vertices=16, rotation=axis_y),
        kit.cylinder("Nub", BATTERY_NUB_R, BATTERY_NUB_D,
                     (0.0, nub_center, 0.0), silver, vertices=10, rotation=axis_y),
    ]
    for side in (-1.0, 1.0):
        parts.append(kit.cylinder("Band%+.0f" % side, BATTERY_BAND_R, BATTERY_BAND_D,
                                  (0.0, side * 0.015, 0.0), silver, vertices=16,
                                  rotation=axis_y))
    obj = kit.join(parts, "CargoBattery")
    return kit.finalize(obj, "CargoBattery")


# ---------------------------------------------------------------------------
# 5. cargo_sd_card.glb — mavi ince kart, altın temaslar, <= 0.12 m
# ---------------------------------------------------------------------------
def build_sd_card():
    blue = mat("SD_Blue", PROP_BLUE, roughness=0.42)
    gold = mat("SD_Gold", GOLD, roughness=0.28, metallic=0.85)
    cream = mat("SD_Label", CREAM, roughness=0.75)

    hw, hl = SD_CARD_W / 2.0, SD_CARD_L / 2.0
    # sağ üst köşe pahlı SD silueti
    points = [(-hw, -hl), (hw, -hl), (hw, hl - SD_CHAMFER),
              (hw - SD_CHAMFER, hl), (-hw, hl)]
    parts = [add_prism("Card", points, 0.0, SD_CARD_T, blue,
                       bevel_width=0.0012, segments=1)]

    contact_gap = 0.004
    contact_total = SD_CONTACT_COUNT * SD_CONTACT_W + (SD_CONTACT_COUNT - 1) * contact_gap
    contact_x0 = -contact_total / 2.0
    for index in range(SD_CONTACT_COUNT):
        cx = contact_x0 + index * (SD_CONTACT_W + contact_gap) + SD_CONTACT_W / 2.0
        parts.append(kit.box_bounds("Contact%d" % index,
                                    cx - SD_CONTACT_W / 2.0, cx + SD_CONTACT_W / 2.0,
                                    -hl + 0.010, -hl + 0.010 + SD_CONTACT_L,
                                    SD_CARD_T, SD_CARD_T + SD_CONTACT_T,
                                    gold, 0.0006, 1))
    parts.append(kit.box_bounds("Label",
                                -SD_LABEL_W / 2.0, SD_LABEL_W / 2.0,
                                0.008, 0.008 + SD_LABEL_L,
                                SD_CARD_T, SD_CARD_T + SD_CONTACT_T,
                                cream, 0.0006, 1))

    obj = kit.join(parts, "CargoSdCard")
    return kit.finalize(obj, "CargoSdCard")


# ---------------------------------------------------------------------------
# 6. cargo_espresso_capsule.glb — kırmızı/siyah kapsül, <= 0.12 m
# ---------------------------------------------------------------------------
def build_capsule():
    red = mat("Capsule_Red", PROP_RED, roughness=0.42)
    black = mat("Capsule_Black", TIRE_DARK, roughness=0.35)

    parts = [
        add_cone("Cup", CAPSULE_R_BOTTOM, CAPSULE_R_TOP, CAPSULE_BODY_H,
                 (0.0, 0.0, CAPSULE_BODY_H / 2.0), red, vertices=14,
                 bevel_width=0.003),
        kit.cylinder("Lid", CAPSULE_LID_R, CAPSULE_LID_H,
                     (0.0, 0.0, CAPSULE_BODY_H + CAPSULE_LID_H / 2.0),
                     black, vertices=14),
    ]
    parts.append(kit.cylinder("LidRing", CAPSULE_LID_R * 0.72, 0.004,
                              (0.0, 0.0, CAPSULE_BODY_H + CAPSULE_LID_H),
                              red, vertices=12))
    parts.append(kit.cylinder("Dimple", CAPSULE_LID_R * 0.25, 0.003,
                              (0.0, 0.0, CAPSULE_BODY_H + CAPSULE_LID_H + 0.003),
                              black, vertices=10))
    obj = kit.join(parts, "CargoCapsule")
    return kit.finalize(obj, "CargoCapsule")


# ---------------------------------------------------------------------------
# 7. prop_keyboard_row.glb — 3 dev tuş + tehlike şeridi (ayrı malzemeler)
# ---------------------------------------------------------------------------
def build_keyboard_row():
    base_dark = mat("Keyboard_Base", TIRE_DARK, roughness=0.60)
    cream = mat("Keyboard_Key", CREAM, roughness=0.70)
    hazard_yellow = mat("Hazard_Yellow", PROP_YELLOW, roughness=0.50)
    hazard_black = mat("Hazard_Black", TIRE_DARK, roughness=0.55)

    parts = [kit.box_bounds("Base", -KEY_BASE_W / 2.0, KEY_BASE_W / 2.0,
                            -KEY_BASE_D / 2.0, KEY_BASE_D / 2.0,
                            0.0, KEY_BASE_H, base_dark, KEY_BASE_BEVEL, 2)]
    key_z0 = KEY_BASE_H
    for index in range(KEY_COUNT):
        cx = (index - (KEY_COUNT - 1) / 2.0) * (KEY_W + KEY_GAP)
        key = kit.box("Key%d" % index, (KEY_W, KEY_D, KEY_H),
                      (cx, 0.0, key_z0 + KEY_H / 2.0), cream, 0.0)
        kit.taper_top(key, KEY_TOP_SCALE)
        kit.bevel(key, KEY_BEVEL, 2)
        parts.append(key)
        # tuş üstünde koyu legend çubuğu
        parts.append(kit.box_bounds("Legend%d" % index, cx - 0.15, cx + 0.15,
                                    -0.05, 0.05, key_z0 + KEY_H,
                                    key_z0 + KEY_H + 0.006, base_dark, 0.003, 1))

    # ön kenarda sarı/siyah tehlike şeridi (ayrı malzeme -> istenirse kapatılır)
    y0 = KEY_BASE_D / 2.0 - 0.002
    y1 = KEY_BASE_D / 2.0 + HAZARD_T
    parts.append(kit.box_bounds("HazardBand", -KEY_BASE_W / 2.0, KEY_BASE_W / 2.0,
                                y0, y1, HAZARD_Z0, HAZARD_Z0 + HAZARD_H,
                                hazard_yellow, 0.0015, 1))
    block_w = KEY_BASE_W / 8.0
    for index in range(0, 8, 2):
        x0 = -KEY_BASE_W / 2.0 + index * block_w
        parts.append(kit.box_bounds("HazardBlack%d" % index, x0, x0 + block_w,
                                    y1, y1 + HAZARD_BLACK_T,
                                    HAZARD_Z0, HAZARD_Z0 + HAZARD_H,
                                    hazard_black, 0.0010, 1))
    obj = kit.join(parts, "PropKeyboardRow")
    return kit.finalize(obj, "PropKeyboardRow")


# ---------------------------------------------------------------------------
# 8. prop_mug.glb — kırmızı kupa, yükseklik ~2.4 m
# ---------------------------------------------------------------------------
def build_mug():
    red = mat("Mug_Red", PROP_RED, roughness=0.40)
    inner = mat("Mug_Inner", MUG_INNER, roughness=0.70)
    cream = mat("Mug_Band", CREAM, roughness=0.60)

    body_h = MUG_BODY_Z1 - MUG_BODY_Z0
    body = kit.cylinder("Body", MUG_R, body_h,
                        (0.0, 0.0, MUG_BODY_Z0 + body_h / 2.0), red, vertices=18)
    kit.bevel(body, 0.045, 2)
    base = kit.cylinder("Base", MUG_BASE_R, MUG_BASE_H,
                        (0.0, 0.0, MUG_BASE_H / 2.0), red, vertices=18)
    kit.bevel(base, 0.025, 2)
    parts = [
        body, base,
        add_torus("Rim", MUG_RIM_MAJOR, MUG_RIM_TUBE,
                  (0.0, 0.0, MUG_BODY_Z1 + MUG_RIM_TUBE / 2.0), red,
                  major_seg=18, minor_seg=6),
        kit.cylinder("Inside", MUG_INNER_R, MUG_INNER_H,
                     (0.0, 0.0, MUG_BODY_Z1 - MUG_INNER_H / 2.0 - 0.01),
                     inner, vertices=18),
        add_torus("Handle", MUG_HANDLE_MAJOR, MUG_HANDLE_TUBE,
                  (MUG_HANDLE_X, 0.0, MUG_HANDLE_Z), red,
                  rotation=(math.radians(90.0), 0.0, 0.0),
                  major_seg=12, minor_seg=6),
        kit.cylinder("Band", MUG_BAND_R, MUG_BAND_H,
                     (0.0, 0.0, MUG_BAND_Z), cream, vertices=18),
    ]
    obj = kit.join(parts, "PropMug")
    return kit.finalize(obj, "PropMug")


# ---------------------------------------------------------------------------
# 9. prop_pencil.glb — sarı altıgen kalem, 8 m boy, 0.5 m çap
# ---------------------------------------------------------------------------
def build_pencil():
    yellow = mat("Pencil_Yellow", PROP_YELLOW, roughness=0.50)
    wood = mat("Pencil_Wood", WOOD, roughness=0.75)
    dark = mat("Pencil_Graphite", TIRE_DARK, roughness=0.40)
    red = mat("Pencil_Eraser", PROP_RED, roughness=0.85)

    # uçlar: silgi -Y, kalem ucu +Y; toplam 8.0 m
    body_y0 = -PENCIL_LENGTH / 2.0 + PENCIL_ERASER_D + PENCIL_FERRULE_D
    body_y1 = PENCIL_LENGTH / 2.0 - PENCIL_GRAPHITE_L - PENCIL_TIP_L
    body_len = body_y1 - body_y0
    axis_y = (math.radians(90.0), 0.0, 0.0)
    axis_y_neg = (math.radians(-90.0), 0.0, 0.0)
    eraser_center = -PENCIL_LENGTH / 2.0 + PENCIL_ERASER_D / 2.0
    ferrule_center = eraser_center + PENCIL_ERASER_D / 2.0 + PENCIL_FERRULE_D / 2.0
    wood_center = body_y1 + PENCIL_TIP_L / 2.0
    graphite_center = body_y1 + PENCIL_TIP_L + PENCIL_GRAPHITE_L / 2.0

    parts = [
        kit.cylinder("Eraser", PENCIL_ERASER_R, PENCIL_ERASER_D,
                     (0.0, eraser_center, 0.0), red, vertices=8, rotation=axis_y),
        kit.cylinder("Ferrule", PENCIL_FERRULE_R, PENCIL_FERRULE_D,
                     (0.0, ferrule_center, 0.0), dark, vertices=8, rotation=axis_y),
        kit.cylinder("HexBody", PENCIL_R, body_len,
                     (0.0, (body_y0 + body_y1) / 2.0, 0.0), yellow,
                     vertices=6, rotation=axis_y),
        add_cone("WoodTip", PENCIL_R, PENCIL_TIP_R, PENCIL_TIP_L,
                 (0.0, wood_center, 0.0), wood, vertices=6, rotation=axis_y_neg),
        add_cone("GraphiteTip", PENCIL_TIP_R, 0.0, PENCIL_GRAPHITE_L,
                 (0.0, graphite_center, 0.0), dark, vertices=6,
                 rotation=axis_y_neg),
    ]
    obj = kit.join(parts, "PropPencil")
    return kit.finalize(obj, "PropPencil")


# ---------------------------------------------------------------------------
# 10. prop_ruler.glb — 12 x 1.2 x 0.1 m düz mavi cetvel, çentikli
# ---------------------------------------------------------------------------
def build_ruler():
    blue = mat("Ruler_Blue", PROP_BLUE, roughness=0.55)
    cream = mat("Ruler_Tick", CREAM, roughness=0.70)

    parts = [kit.box_bounds("RulerBody", -RULER_W / 2.0, RULER_W / 2.0,
                            -RULER_L / 2.0, RULER_L / 2.0,
                            0.0, RULER_T, blue, RULER_BEVEL, 2)]
    tick_edge = -RULER_W / 2.0 + 0.01
    tick_z0 = RULER_T
    tick_z1 = RULER_T + RULER_TICK_T
    # 1 m ana çentikler
    y = -RULER_L / 2.0 + 0.5
    while y <= RULER_L / 2.0 - 0.5 + 1e-6:
        parts.append(kit.box_bounds("TickMajor%d" % round((y + 6.0) * 10),
                                    tick_edge, tick_edge + RULER_MAJOR_X,
                                    y - 0.03, y + 0.03,
                                    tick_z0, tick_z1, cream, 0.0015, 1))
        # 0.5 m ara çentikler
        if y + 0.5 <= RULER_L / 2.0 - 0.5 + 1e-6:
            parts.append(kit.box_bounds("TickMinor%d" % round((y + 6.5) * 10),
                                        tick_edge, tick_edge + RULER_MINOR_X,
                                        y + 0.47, y + 0.53,
                                        tick_z0, tick_z1 - 0.001, cream, 0.0015, 1))
        y += RULER_STEP
    obj = kit.join(parts, "PropRuler")
    return kit.finalize(obj, "PropRuler")


# ---------------------------------------------------------------------------
# 11. prop_book.glb — 5 x 3.5 x 0.6 m yeşil kapak, krem sayfa kenarı
# ---------------------------------------------------------------------------
def build_book():
    green = mat("Book_Cover", PROP_GREEN, roughness=0.55)
    pages = mat("Book_Pages", CREAM, roughness=0.80)
    spine = mat("Book_Spine", BOOK_SPINE, roughness=0.55)

    hw, hl = BOOK_W / 2.0, BOOK_L / 2.0
    page_x0 = -hw + BOOK_PAGE_INSET
    page_x1 = hw - BOOK_PAGE_INSET
    page_y0 = -hl + BOOK_PAGE_INSET
    page_y1 = hl - BOOK_PAGE_INSET
    parts = [
        kit.box_bounds("CoverBottom", -hw, hw, -hl, hl, 0.0, BOOK_COVER_T,
                       green, BOOK_BEVEL, 2),
        kit.box_bounds("CoverTop", -hw, hw, -hl, hl,
                       BOOK_H - BOOK_COVER_T, BOOK_H, green, BOOK_BEVEL, 2),
        kit.box_bounds("Spine", -hw, page_x0, -hl, hl, 0.0, BOOK_H,
                       spine, 0.008, 2),
        kit.box_bounds("Pages", page_x0, page_x1, page_y0, page_y1,
                       BOOK_COVER_T, BOOK_H - BOOK_COVER_T, pages, 0.004, 2),
        kit.box_bounds("Title", 0.25, 0.45, -1.40, 1.40,
                       BOOK_H, BOOK_H + BOOK_TITLE_H, spine, 0.0025, 1),
    ]
    obj = kit.join(parts, "PropBook")
    return kit.finalize(obj, "PropBook")


# ---------------------------------------------------------------------------
# ana akış
# ---------------------------------------------------------------------------
BUILDERS = [
    ("robot_body.glb", build_robot_body, ""),
    ("robot_wheel.glb", build_robot_wheel, ""),
    ("cargo_basket.glb", build_cargo_basket, ""),
    ("cargo_pencil_battery.glb", build_battery, ""),
    ("cargo_sd_card.glb", build_sd_card, ""),
    ("cargo_espresso_capsule.glb", build_capsule, ""),
    ("prop_keyboard_row.glb", build_keyboard_row, ""),
    ("prop_mug.glb", build_mug, ""),
    ("prop_pencil.glb", build_pencil, ""),
    ("prop_ruler.glb", build_ruler, ""),
    ("prop_book.glb", build_book, ""),
]


def main() -> int:
    models_dir = PROJECT_ROOT / "assets" / "models"
    models_dir.mkdir(parents=True, exist_ok=True)

    total = 0
    for filename, builder, subdir in BUILDERS:
        kit.reset()
        obj = builder()
        path = models_dir / subdir / filename
        kit.export_glb(obj, str(path))
        kit.report(obj, str(path))
        total += kit.triangle_count(obj)

    print("TOTAL_MODELS %d" % len(BUILDERS))
    print("TOTAL_TRIS %d" % total)
    print("OUT_DIR %s" % models_dir)
    return 0


if __name__ == "__main__":
    sys.exit(main())
