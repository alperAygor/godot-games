#!/usr/bin/env python3
"""Çamaşır İpi — yeni mekân katmanları: Sahil (bg_beach) ve Çatı Katı (bg_rooftop).

    /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/make_locations.py
    ... -- beach                    # yalnız sahil
    ... -- rooftop far mid          # çatı katının yalnız uzak + orta katmanı
    ... -- --preview                # yarım çözünürlük, az örnek

Neden ayrı betik: bahçe betiği (make_background.py) çalışan, ayarlı bir boru hattı; ona dokunmadan
onun malzeme/geometri yardımcılarını (mat, blob, puff, tube, slab, Frame, light_rig ...) aynen
kullanıyoruz. O dosya modül olarak içe aktarılamıyor (sonunda koşulsuz main() var), bu yüzden
kaynağı son satırı çıkarılarak bu modülün ad alanına yüklenir.

Katman sözleşmesi bahçeyle AYNI (data/locations.json bu piksel çapalarını kullanır):
  bg_far   1080x900  ekranda y=620      bg_mid    1080x700  y=760
  bg_fence 1080x420  y=990 (çit eşdeğeri) bg_ground 1080x820  y=1100
  hero_trunk 360x900 (taban pikseli 180,900)  hero_crown 640x640 (salınım pivotu çıktıda yazılır)
  pole 160x1400 (eksen x=80, halkalar bahçe direğiyle aynı yükseklikte)  decor_* 160x240 (pivot 80,240)
Işık/parıltı çapaları (pencere, fener, ampul) "ANCHOR" satırlarıyla yazdırılır; locations.json'a girer.
Kural 1: low-poly yok — her şey metaball/yuvarlak bevel/pürüzsüz tüp; düz yüzeyler bile yumuşak.
"""

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

_HERE = os.path.dirname(os.path.abspath(__file__))
_BASE = os.path.join(_HERE, "make_background.py")
with open(_BASE, encoding="utf-8") as _fh:
    _SRC = _fh.read()
# Bahçe betiğinin sonundaki koşulsuz main() çağrısı atılır: yalnız yardımcılar yüklenir.
_SRC = _SRC[:_SRC.rindex("\nmain()")]
exec(compile(_SRC, _BASE, "exec"), globals())

ROOT = os.path.dirname(os.path.dirname(_HERE))
ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ONLY = {a for a in ARGV if not a.startswith("--")}
ANCHORS = {}


def want(place, layer):
    places = ONLY & {"beach", "rooftop"}
    layers = ONLY - {"beach", "rooftop"}
    return (not places or place in places) and (not layers or layer in layers)


def out_dir(place):
    global OUT_DIR
    OUT_DIR = os.path.join(ROOT, "assets", "sprites", "bg_" + place)


def proj(res_x, res_y, cz, tilt, x, y, z):
    """Dünya noktası -> piksel (üstten). Eğik orto kamera, Frame/camera ile aynı formül."""
    t = math.radians(tilt)
    v = (z - cz) * math.cos(t) + y * math.sin(t)
    return (res_x / 2.0 + x * PPU, res_y / 2.0 - v * PPU)


def fproj(fr, x, y, z):
    return proj(1080, fr.h, fr.cz, math.degrees(fr.t), x, y, z)


def anchor(key, xy):
    ANCHORS.setdefault(key, []).append([round(xy[0]), round(xy[1])])


def depth_for(fr, p, z=0.0):
    """z yüksekliğindeki düzlem noktasının p pikselinde görünmesi için gereken derinlik y."""
    return (fr.v(p) - (z - fr.cz) * fr.c) / fr.s


def grid_plane(x0, x1, y0, y1, nx, ny, material, height=None, name="Plane"):
    bm_ = bmesh.new()
    rows = []
    for j in range(ny + 1):
        yy = y0 + (y1 - y0) * j / ny
        row = []
        for i in range(nx + 1):
            xx = x0 + (x1 - x0) * i / nx
            row.append(bm_.verts.new((xx, yy, height(xx, yy) if height else 0.0)))
        rows.append(row)
    for j in range(ny):
        for i in range(nx):
            bm_.faces.new((rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i]))
    mesh = bpy.data.meshes.new(name)
    bm_.to_mesh(mesh)
    bm_.free()
    obj = link(bpy.data.objects.new(name, mesh))
    activate(obj)
    bpy.ops.object.shade_smooth()
    return assign(obj, material)


def wave_bump(material, scale, strength, direction="Y", distortion=2.0):
    """Malzemeye yumuşak dalga kabartısı ekler (kum dalgacıkları, deniz kıpırtısı)."""
    nodes, links = material.node_tree.nodes, material.node_tree.links
    bsdf = nodes["Principled BSDF"]
    texco = [n for n in nodes if n.type == "TEX_COORD"][0]
    wave = nodes.new("ShaderNodeTexWave")
    wave.wave_type = "BANDS"
    wave.bands_direction = direction
    wave.wave_profile = "SIN"
    wave.inputs["Scale"].default_value = scale
    wave.inputs["Distortion"].default_value = distortion
    wave.inputs["Detail"].default_value = 2.0
    links.new(texco.outputs["Object"], wave.inputs["Vector"])
    bump = nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = strength
    bump.inputs["Distance"].default_value = 0.02
    links.new(wave.outputs["Fac"], bump.inputs["Height"])
    links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    return material


def stripe_mat(name, col_a, col_b, scale, rough=0.6, haze=0.0, haze_color="#FFFFFF", ao=0.4,
               direction="X"):
    """İki renkli yumuşak kenarlı şerit (kabin tahtaları, şemsiye): kenar keskin değil, pürüzsüz."""
    m = mat(name, col_a, rough=rough, haze=haze, haze_color=haze_color, ao=ao, ao_dist=0.1)
    nodes, links = m.node_tree.nodes, m.node_tree.links
    bsdf = nodes["Principled BSDF"]
    texco = [n for n in nodes if n.type == "TEX_COORD"][0]
    wave = nodes.new("ShaderNodeTexWave")
    wave.wave_type = "BANDS"
    wave.bands_direction = direction
    wave.wave_profile = "SIN"
    wave.inputs["Scale"].default_value = scale
    wave.inputs["Distortion"].default_value = 0.0
    links.new(texco.outputs["Object"], wave.inputs["Vector"])
    sharp = nodes.new("ShaderNodeMapRange")
    sharp.inputs["From Min"].default_value = 0.4
    sharp.inputs["From Max"].default_value = 0.6
    sharp.interpolation_type = "SMOOTHSTEP"
    links.new(wave.outputs["Fac"], sharp.inputs["Value"])
    old = bsdf.inputs["Base Color"].links[0].from_socket
    mixed = _mix(nodes, links, sharp.outputs["Result"], old, lin(col_b))
    links.new(mixed, bsdf.inputs["Base Color"])
    return m


def attr_mat(name, base, tip, rough=0.7, ao=0.5, ao_dist=0.25, haze=0.0, haze_color="#FFFFFF",
             sheen=0.2):
    """Köşe niteliği 'Grad' (0 kök -> 1 uç) ile renk geçişi: palmiye yaprağı boyunca açık ton."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nodes, links = m.node_tree.nodes, m.node_tree.links
    bsdf = nodes["Principled BSDF"]
    out = nodes["Material Output"]
    attr = nodes.new("ShaderNodeAttribute")
    attr.attribute_name = "Grad"
    sep = nodes.new("ShaderNodeSeparateColor")
    links.new(attr.outputs["Color"], sep.inputs[0])
    smooth = nodes.new("ShaderNodeMapRange")
    smooth.interpolation_type = "SMOOTHSTEP"
    links.new(sep.outputs[0], smooth.inputs["Value"])
    col = _mix(nodes, links, smooth.outputs["Result"], lin(base), lin(tip))
    if ao > 0.0:
        aon = nodes.new("ShaderNodeAmbientOcclusion")
        aon.inputs["Distance"].default_value = ao_dist
        aon.samples = 16
        links.new(col, aon.inputs["Color"])
        col = _mix(nodes, links, ao, col, aon.outputs["Color"])
    links.new(col, bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = rough
    for sock_name, value in (("Specular IOR Level", 0.3), ("Sheen Weight", sheen)):
        if sock_name in bsdf.inputs:
            bsdf.inputs[sock_name].default_value = value
    if haze > 0.0:
        emis = nodes.new("ShaderNodeEmission")
        emis.inputs["Color"].default_value = (*lin(haze_color), 1.0)
        mix = nodes.new("ShaderNodeMixShader")
        mix.inputs[0].default_value = haze
        links.new(bsdf.outputs[0], mix.inputs[1])
        links.new(emis.outputs[0], mix.inputs[2])
        links.new(mix.outputs[0], out.inputs["Surface"])
    return m


def glow_mat(name, color, strength=1.0):
    """Ampul/fener camı: gündüz de açık krem görünür (ışığı oyun gece ekler)."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nodes, links = m.node_tree.nodes, m.node_tree.links
    out = nodes["Material Output"]
    emis = nodes.new("ShaderNodeEmission")
    emis.inputs["Color"].default_value = (*lin(color), 1.0)
    emis.inputs["Strength"].default_value = strength
    links.new(emis.outputs[0], out.inputs["Surface"])
    return m


def subdivide(obj, levels=2):
    activate(obj)
    mod = obj.modifiers.new("Sub", "SUBSURF")
    mod.levels = levels
    mod.render_levels = levels
    return obj


def solidify(obj, thickness):
    activate(obj)
    mod = obj.modifiers.new("Solid", "SOLIDIFY")
    mod.thickness = thickness
    mod.offset = 0.0
    return obj


def cap_cut(obj, keep_above=0.0):
    """Elipsoidin alt yarısını siler (şemsiye kubbesi, kubbe çatı)."""
    bm_ = bmesh.new()
    bm_.from_mesh(obj.data)
    doomed = [v for v in bm_.verts if v.co.z < keep_above - 1e-4]
    bmesh.ops.delete(bm_, geom=doomed, context="VERTS")
    bm_.to_mesh(obj.data)
    bm_.free()
    return obj


def tapered_pot(base, r0, r1, h, body_m, rim_m, soil_m=None):
    """Toprak saksı: yumuşak konik gövde + kalın yuvarlak ağız (torus) + toprak yüzeyi."""
    bx, by, bz = base
    tube([(bx, by, bz, r0), (bx, by, bz + h * 0.5, (r0 + r1) / 2), (bx, by, bz + h, r1)], body_m,
         res=12)
    bpy.ops.mesh.primitive_torus_add(major_radius=r1 * 1.02, minor_radius=r1 * 0.14,
                                     location=(bx, by, bz + h), major_segments=64, minor_segments=20)
    bpy.ops.object.shade_smooth()
    assign(bpy.context.view_layer.objects.active, rim_m)
    if soil_m is not None:
        ellipsoid((bx, by, bz + h - r1 * 0.05), (r1 * 0.95, r1 * 0.95, r1 * 0.12), soil_m,
                  segments=48, rings=24)


def blade_tuft(rng, cx, cy, cz, count, h, material, spread=0.12, lean=(0.04, 0.14), width=0.04):
    out = []
    for _ in range(count):
        bx, by = cx + rng.uniform(-spread, spread), cy + rng.uniform(-spread * 0.6, spread * 0.6)
        out.append(grass_blade(bx, by, cz - 0.02, h * rng.uniform(0.7, 1.15), rng.uniform(*lean),
                               rng.uniform(0, math.tau), material, width=width * rng.uniform(0.85, 1.1)))
    return out


def sea_oat_heads(rng, x, y, z, h, material, seed_m):
    """Deniz yulafı sapı: hafif eğik sap + ucunda sarkan yumuşak tohum taneleri."""
    lean = rng.uniform(-0.18, 0.18)
    pts = [(x, y, z, 0.022), (x + lean * 0.3, y, z + h * 0.5, 0.019), (x + lean, y, z + h, 0.016)]
    tube(pts, material, "OatStalk", res=6)
    tip = Vector((x + lean, y, z + h))
    for k in range(5):
        side = -1 if k % 2 else 1
        p = tip + Vector((side * 0.05 + lean * 0.15 * k, -0.01, -0.06 * k))
        ellipsoid(tuple(p), (0.045, 0.03, 0.075), seed_m, rot=(0, math.radians(side * 25), 0),
                  segments=24, rings=12)


# ============================================================================ SAHİL

SAND = "#F1DCBA"
SAND_TOP = "#F8EBD3"
DRIFT = "#DCC8AE"
DRIFT_TOP = "#EDE0CC"
DUNE_GRASS = "#A8C79B"
DUNE_GRASS_TOP = "#DCEAC6"


def beach_far():
    """Uzak plan: sakin deniz bandı (yumuşak ufuk), sağda deniz feneri olan burun, solda pus
    içinde ada, ufukta minik yelkenli. Derinlik arttıkça pus ve maviye kayma artar."""
    reset()
    light_rig(sun=1.05, sky=0.52, direction=(0.55, 0.55, -0.62))
    rng = random.Random(41)
    fr = Frame(1080, 900, 10.0, 720)
    horizon = 178
    y_h = depth_for(fr, horizon)
    sea = mat("Sea", "#8FD0CF", "#CBE9E8", rough=0.9, haze=0.18, haze_color="#DDF0F0", ao=0.0,
              grad=(0.0, 1.0), grad_axis="Y", spec=0.15)
    wave_bump(sea, 0.9, 0.05, "Y", distortion=3.0)
    grid_plane(-8.0, 8.0, -2.0, y_h, 8, 40, sea, name="Sea")
    # Sağ burun: iki yumuşak tepe, üstte deniz feneri.
    hm = mat("Cape", "#B7D3C8", "#D9EBE2", rough=0.95, haze=0.48, haze_color="#DCEDEA", ao=0.3,
             ao_dist=1.0, grad=(0.4, 1.0), spec=0.15)
    sy = 1.8
    cape = []
    for hx, sx, crest, dy in ((4.2, 2.4, 124, 3.4), (6.5, 1.9, 146, 2.6), (2.3, 1.3, 164, 2.0)):
        depth = y_h - dy
        sz = fr.hill_sz(crest, depth, sy)
        ellipsoid((hx, depth, 0.0), (sx, sy, sz), hm)
        cape.append((hx, depth, sx, sz))
    tm = mat("CapeTree", "#93C3A0", "#C6E4C6", rough=0.85, haze=0.52, haze_color="#DCEDEA", ao=0.5,
             ao_dist=0.2, grad=(0.1, 0.95), spec=0.2)
    for hx, depth, sx, sz in cape[:2]:
        for _ in range(3):
            ux = rng.uniform(-0.75, 0.75)
            if abs(hx + ux * sx - 4.1) < 0.35:
                continue
            uz = math.sqrt(max(1 - ux * ux - 0.16, 0.0))
            r = rng.uniform(0.12, 0.2)
            puff(rng, (hx + ux * sx, depth - 0.4 * sy, uz * sz + r * 0.5), r, tm, lumps=3, name="FarTree")
    # Deniz feneri: beyaz gövde, iki yumuşak mercan bant, galeri, krem fener camı, kubbe.
    lx, ldepth, lsx, lsz = 4.1, cape[0][1], cape[0][2], cape[0][3]
    ux = (lx - cape[0][0]) / lsx
    lz = math.sqrt(max(1 - ux * ux - 0.09, 0.0)) * lsz - 0.04
    ly = ldepth - 0.3 * sy
    white = mat("Tower", "#F4F1EA", rough=0.6, haze=0.3, haze_color="#E6F1EF", ao=0.3, ao_dist=0.08)
    coral = mat("Band", "#EDB3A6", rough=0.6, haze=0.3, haze_color="#E6F1EF", ao=0.2, ao_dist=0.05)
    th = 0.62
    tube([(lx, ly, lz, 0.115), (lx, ly, lz + th * 0.5, 0.098), (lx, ly, lz + th, 0.082)], white, res=10)
    for b0 in (0.18, 0.42):
        r_b = 0.115 - 0.033 * (b0 + 0.06) / th + 0.006
        tube([(lx, ly, lz + b0, r_b), (lx, ly, lz + b0 + 0.06, r_b - 0.002), (lx, ly, lz + b0 + 0.12, r_b - 0.004)],
             coral, res=10)
    ellipsoid((lx, ly, lz + th + 0.01), (0.12, 0.12, 0.025), white)
    lamp = glow_mat("Lamp", "#FFF2CF", 1.0)
    tube([(lx, ly, lz + th, 0.06), (lx, ly, lz + th + 0.1, 0.06)], lamp, res=8)
    dome = ellipsoid((lx, ly, lz + th + 0.1), (0.075, 0.075, 0.07), coral)
    cap_cut(dome)
    anchor("beach_lighthouse", fproj(fr, lx, ly, lz + th + 0.05))
    # Sol: pus içinde alçak ada.
    im = mat("Isle", "#BCD7D3", "#D8EAE8", rough=0.95, haze=0.6, haze_color="#DFEFEE", ao=0.2,
             ao_dist=1.0, grad=(0.4, 1.0), spec=0.1)
    for hx, sx, crest, dy in ((-5.6, 2.3, 150, 1.4), (-3.7, 1.4, 166, 1.2)):
        depth = y_h - dy
        ellipsoid((hx, depth, 0.0), (sx, 1.0, fr.hill_sz(crest, depth, 1.0)), im)
    # Ufukta minik yelkenli.
    bx, bdepth = -1.4, y_h - 6.0
    hull = mat("Hull", "#F6F3EE", rough=0.5, haze=0.3, haze_color="#E3F3F1", ao=0.3, ao_dist=0.05)
    sail = mat("Sail", "#FFFDF7", rough=0.6, haze=0.26, haze_color="#E3F3F1", ao=0.2, ao_dist=0.05)
    ellipsoid((bx, bdepth, 0.02), (0.3, 0.1, 0.07), hull)
    tube([(bx, bdepth, 0.0, 0.012), (bx, bdepth, 0.55, 0.01)], hull, res=6)
    outline = [(0.0, 0.08), (0.0, 0.55), (0.26, 0.1)]
    dense = []
    for pa, pb in zip(outline, outline[1:] + outline[:1]):
        for k in range(12):
            t = k / 12
            dense.append((pa[0] + (pb[0] - pa[0]) * t, pa[1] + (pb[1] - pa[1]) * t))
    slab(dense, 0.02, 0.008, sail, y=bdepth, loc=(bx + 0.02, 0.0), name="Sail")
    flag = mat("Flag", "#F4B7A6", rough=0.6, haze=0.3, haze_color="#E3F3F1", ao=0.0)
    slab([(0.0, 0.0), (-0.16, 0.0), (-0.16, 0.06), (0.0, 0.06)], 0.02, 0.008, flag, y=bdepth - 0.02,
         loc=(bx - 0.01, 0.0), name="Jib", rot_z=0.0)
    render("bg_far")


def beach_hut(base, w, h, stripe_m, roof_m, trim_m, window_m, key):
    """Pastel plaj kabini: şeritli gövde, beyaz üçgen çatı, kapı, yuvarlak pencere."""
    rounded_box(base + Vector((0, 0, h / 2)), (w, w * 0.85, h), w * 0.08, stripe_m)
    roof = [(-w * 0.62, 0.0), (w * 0.62, 0.0), (0.0, h * 0.42)]
    dense = []
    for pa, pb in zip(roof, roof[1:] + roof[:1]):
        for k in range(16):
            t = k / 16
            dense.append((pa[0] + (pb[0] - pa[0]) * t, pa[1] + (pb[1] - pa[1]) * t))
    slab(dense, w * 1.0, w * 0.06, roof_m, y=base.y, loc=(base.x, base.z + h - w * 0.03), name="HutRoof")
    front = base.y - w * 0.43
    rounded_box(Vector((base.x - w * 0.12, front, base.z + h * 0.33)), (w * 0.34, w * 0.05, h * 0.6),
                w * 0.04, trim_m)
    win = Vector((base.x + w * 0.24, front - 0.005, base.z + h * 0.68))
    bpy.ops.mesh.primitive_torus_add(major_radius=w * 0.1, minor_radius=w * 0.025, location=win,
                                     rotation=(math.radians(90), 0, 0), major_segments=40, minor_segments=12)
    bpy.ops.object.shade_smooth()
    assign(bpy.context.view_layer.objects.active, trim_m)
    ellipsoid(tuple(win + Vector((0, 0.01, 0))), (w * 0.1, w * 0.02, w * 0.1), window_m, segments=32, rings=16)
    return win


def beach_mid():
    """Orta plan: ıslak kumda yumuşak köpük çizgisi, iki yanda deniz yulaflı tombul kum tepeleri,
    ortada uzakta üç pastel kabin ve çizgili şemsiye. Orta bölge alçak: deniz görünür kalsın."""
    reset()
    light_rig(sun=1.08, sky=0.5, direction=(0.58, 0.48, -0.66))
    rng = random.Random(43)
    fr = Frame(1080, 700, 14.0, 640)
    shore_p = 168
    y_s = depth_for(fr, shore_p)
    sand = mat("MidSand", "#F2DFC0", "#E2CCAC", rough=0.95, haze=0.12, haze_color="#F5EEE2", ao=0.3,
               ao_dist=1.0, grad=(0.86, 1.0), grad_axis="Y", noise=0.03, noise_scale=0.5, spec=0.15)
    grid_plane(-8.0, 8.0, -3.0, y_s, 16, 60, sand, name="Sand")
    foam = mat("Foam", "#FFFFFF", rough=0.7, haze=0.35, haze_color="#F8FCFB", ao=0.0, spec=0.2)
    for off, r, alpha_gap in ((0.0, 0.06, 0.0), (0.45, 0.035, 0.35)):
        x = -7.5
        while x < 7.5:
            seg = rng.uniform(1.2, 2.6)
            pts = []
            for k in range(7):
                xx = x + seg * k / 6
                pts.append((xx, y_s - off - 0.06 * math.sin(xx * 1.7 + off * 5.0), 0.0,
                            r * (0.35 + 0.65 * math.sin(math.pi * k / 6))))
            t_obj = tube(pts, foam, "Foam", res=6)
            t_obj.scale.z = 0.35
            x += seg + (rng.uniform(0.1, 0.5) if alpha_gap else rng.uniform(0.02, 0.08))
    # Kum tepeleri (yanlarda yüksek, ortada alçak).
    dune = mat("Dune", "#E9D1AC", "#F7E9D1", rough=0.95, haze=0.1, haze_color="#F6EFE3", ao=0.45,
               ao_dist=0.8, grad=(0.3, 1.0), noise=0.03, noise_scale=0.6, spec=0.15)
    wave_bump(dune, 2.2, 0.06, "Z", distortion=4.0)
    grass = mat("DuneGrass", "#A2C298", "#D8E7C5", rough=0.7, haze=0.12, haze_color="#EEF3E6", ao=0.3,
                ao_dist=0.15, grad=(0.0, 1.0), spec=0.3)
    seed = mat("Oat", "#E7D3A8", "#F4E7C6", rough=0.6, haze=0.1, haze_color="#F6EFE3", ao=0.2, ao_dist=0.05)
    blades = []
    # Kum tepeleri metaball ile kurulur: bitişik tümsekler tek, kesintisiz, yumuşak bir sırta
    # kaynaşır (ayrı elipsoidler "iglo" gibi tek tek okunuyordu). Yanlarda geniş-alçak tepeler,
    # önde boydan boya alçak sırt (bahçedeki çalı bandının karşılığı; denizi kapatmaz).
    groups = [
        [(-6.2, 3.4, 112, 8.0, 2.6), (-4.0, 2.2, 182, 5.0, 1.8), (-2.7, 1.5, 228, 3.4, 1.4)],
        [(6.3, 3.2, 122, 8.5, 2.6), (4.2, 2.0, 190, 4.6, 1.8), (3.0, 1.4, 232, 3.2, 1.4)],
    ]
    ridge = []
    x = -7.0
    while x < 7.2:
        ridge.append((x, rng.uniform(1.4, 1.8), rng.uniform(258, 276), rng.uniform(1.2, 1.6), 1.1))
        x += rng.uniform(1.1, 1.5)
    groups.append(ridge)
    surface = []
    for group in groups:
        balls = []
        for hx, sx, crest, depth, sy in group:
            sz = fr.hill_sz(crest, depth, sy)
            balls.append((hx, depth, -0.05, 1.0, sx * 0.95, sy * 0.95, sz))
            surface.append((hx, sx, depth, sy, sz))
        blob(balls, dune, res=0.07, smooth=8, name="Dune", stiffness=2.0)
    for hx, sx, depth, sy, sz in surface:
        for k in range(2 if sx < 1.9 else 4):
            ux = rng.uniform(-0.6, 0.6)
            uy = -rng.uniform(0.35, 0.7)
            uz = math.sqrt(max(1 - ux * ux - uy * uy, 0.0))
            cx, cy, cz = hx + ux * sx, depth + uy * sy, uz * sz
            blades += blade_tuft(rng, cx, cy, cz, rng.randint(5, 8), 0.34, grass, spread=0.14,
                                 width=0.032)
            if k % 2 == 0:
                sea_oat_heads(rng, cx, cy - 0.05, cz, rng.uniform(0.45, 0.6), grass, seed)
    if blades:
        join(blades, "DuneBlades")
    # Kabinler: kıyıya yakın, yan yana; pencereleri gece yanar.
    huts = (("#BFE3D8", -2.0), ("#F6CDBE", -1.05), ("#D4CBEE", 1.75))
    roof_m = mat("HutRoof", "#FBF8F2", rough=0.55, haze=0.2, haze_color="#F3F4F2", ao=0.35, ao_dist=0.08)
    trim_m = mat("HutTrim", "#FFFCF6", rough=0.55, haze=0.2, haze_color="#F3F4F2", ao=0.35, ao_dist=0.06)
    win_m = mat("HutWin", "#CFE3EA", rough=0.3, haze=0.2, haze_color="#F3F4F2", ao=0.0)
    for i, (col, hx) in enumerate(huts):
        sm = stripe_mat("Hut%d" % i, col, "#FFFDF8", 11.0, haze=0.2, haze_color="#F3F4F2")
        depth = y_s - 3.2 - 0.25 * i
        win = beach_hut(Vector((hx, depth, 0.0)), 0.68, 0.74, sm, roof_m, trim_m, win_m, i)
        anchor("beach_huts", fproj(fr, win.x, win.y, win.z))
    # Çizgili şemsiye.
    ux_, depth_u = 2.75, y_s - 3.6
    pole_m = mat("UmbPole", "#F7F2EA", rough=0.5, ao=0.2, ao_dist=0.05)
    tube([(ux_, depth_u, 0.0, 0.025), (ux_ + 0.05, depth_u, 0.62, 0.022)], pole_m, res=6)
    canopy = ellipsoid((ux_ + 0.05, depth_u, 0.6), (0.48, 0.48, 0.2), stripe_mat(
        "Umb", "#F5C2B4", "#FFFBF4", 9.0, haze=0.18, haze_color="#F3F4F2"), rot=(0, math.radians(-8), 0))
    cap_cut(canopy, 0.0)
    ellipsoid((ux_ + 0.07, depth_u, 0.8), (0.04, 0.04, 0.035), pole_m, segments=16, rings=8)
    render("bg_mid")


def beach_fence():
    """Alçak ip-direk çit: yuvarlak başlı yıpranmış ahşap kazıklar, aralarında sarkan kalın halat,
    kazıklara düğümlü halka sargılar."""
    reset()
    light_rig(sun=1.1, sky=0.5, direction=(0.6, 0.5, -0.62))
    rng = random.Random(47)
    fr = Frame(1080, 420, 10.0, 360)
    wood = mat("Drift", DRIFT, DRIFT_TOP, rough=0.7, ao=0.55, ao_dist=0.25, grain=0.08, grain_scale=8.0,
               grain_dir="X", noise=0.03, noise_scale=1.2, grad=(0.0, 1.0), spec=0.25)
    rope = mat("Rope", "#E9D7B4", "#F4E8CF", rough=0.75, ao=0.35, ao_dist=0.1, grain=0.16,
               grain_scale=26.0, grain_dir="DIAGONAL", grad=(0.0, 1.0), spec=0.2)
    top = fr.z_at(64, 0.0)
    posts = []
    x = -5.55
    while x < 5.9:
        h = top + rng.uniform(-0.05, 0.03)
        posts.append((x + rng.uniform(-0.05, 0.05), h))
        x += 1.38
    for px, h in posts:
        tube([(px, 0.0, -1.6, 0.13), (px, 0.0, h * 0.4, 0.125), (px, 0.0, h - 0.06, 0.118)], wood, res=12)
        ellipsoid((px, 0.0, h - 0.06), (0.118, 0.118, 0.07), wood)
    for level_z, sag, r in ((top - 0.22, 0.16, 0.05), (top - 0.95, 0.12, 0.045)):
        for (xa, ha), (xb, hb) in zip(posts, posts[1:]):
            pts = []
            for k in range(9):
                t = k / 8
                pts.append((xa + (xb - xa) * t, -0.13, level_z - sag * 4 * t * (1 - t), r))
            tube(pts, rope, "Rope", res=8)
        for px, _h in posts:
            bpy.ops.mesh.primitive_torus_add(major_radius=0.135, minor_radius=0.04,
                                             location=(px, 0.0, level_z), major_segments=48,
                                             minor_segments=14)
            bpy.ops.object.shade_smooth()
            assign(bpy.context.view_layer.objects.active, rope)
    render("bg_fence")


def starfish(center, size, material, rot):
    arms = []
    cx, cy, cz = center
    balls = [(cx, cy, cz + size * 0.12, size * 0.32, 1.0, 1.0, 0.45)]
    for k in range(5):
        a = rot + math.tau * k / 5
        for s in (0.35, 0.62, 0.85):
            r = size * (0.24 - 0.15 * s)
            balls.append((cx + math.cos(a) * size * s, cy + math.sin(a) * size * s, cz + size * 0.08 * (1 - s),
                          r, 1.0, 1.0, 0.55))
    return blob(balls, material, res=size * 0.03, smooth=6, name="Star", stiffness=2.5)


def scallop(center, size, material, rot):
    """Tarak kabuğu: yassı yelpaze, yumuşak ışınsal kaburgalar (vertex kaydırma, pürüzsüz)."""
    obj = ellipsoid(center, (size, size * 0.8, size * 0.28), material, rot=(0, 0, rot), segments=96,
                    rings=48)
    for v in obj.data.vertices:
        ang = math.atan2(v.co.y, v.co.x)
        if v.co.y > 0.15:
            v.co.y = 0.15 + (v.co.y - 0.15) * 0.4
        if v.co.z > 0:
            v.co.z *= 1.0 + 0.18 * math.cos(ang * 14.0)
    return obj


def beach_ground():
    """Ön kum: hafif tümsekler, rüzgâr dalgacıkları, kenarlarda deniz kabukları, deniz yıldızı,
    çakıllar ve deniz yulafı tutamları; ortası (sepet alanı) temiz kalır."""
    reset()
    light_rig(sun=1.0, sky=0.55, direction=(0.55, 0.62, -0.6))
    rng = random.Random(49)
    tilt = 38.0
    st = math.sin(math.radians(tilt))
    camera(1080, 820, 0.0, 0.0, tilt)
    back_y = (4.1 - 0.55) / st
    sm = mat("Sand", SAND, SAND_TOP, rough=0.95, ao=0.4, ao_dist=0.6, noise=0.04, noise_scale=0.5,
             grad=(0.0, 1.0), grad_axis="Y", spec=0.15, sheen=0.15)
    wave_bump(sm, 1.1, 0.09, "Y", distortion=5.0)
    mounds = [(-3.8, -2.2, 1.7, 0.22), (3.4, 0.4, 1.9, 0.2), (-0.4, 2.4, 2.2, 0.12),
              (1.6, -4.8, 1.9, 0.16), (-4.7, 3.6, 1.5, 0.2), (4.9, -3.2, 1.5, 0.18), (0.0, back_y, 1.2, 0.08)]

    def gz(xx, yy):
        return sum(a * math.exp(-((xx - mx) ** 2 + (yy - my) ** 2) / (r * r)) for mx, my, r, a in mounds)

    def h(xx, yy):
        return gz(xx, yy)

    grid_plane(-6.2, 6.2, -7.2, back_y + 0.05, 160, 150, sm, height=h, name="Beach")
    # Arka kenar: yuvarlak kum dudağı (yumuşak silüet) + seyrek yulaf tutamları.
    lip = []
    for k in range(41):
        xx = -6.2 + 12.4 * k / 40
        lip.append((xx, back_y - 0.02 + 0.05 * math.sin(xx * 1.9), gz(xx, back_y) + 0.02,
                    0.11 + 0.03 * math.sin(xx * 2.7 + 1.0)))
    lip_obj = tube(lip, sm, "Lip", res=10)
    lip_obj.scale.z = 0.6
    grass = mat("Tuft", DUNE_GRASS, DUNE_GRASS_TOP, rough=0.7, ao=0.3, ao_dist=0.15, grad=(0.0, 1.0), spec=0.3)
    seed = mat("Oat", "#E5D0A3", "#F3E6C4", rough=0.6, ao=0.2, ao_dist=0.05)
    blades = []
    xx = -5.7
    while xx < 5.8:
        by = back_y - rng.uniform(0.0, 0.2)
        blades += blade_tuft(rng, xx, by, gz(xx, by), rng.randint(4, 7), 0.3, grass, spread=0.12, width=0.036)
        if rng.random() < 0.4:
            sea_oat_heads(rng, xx, by - 0.04, gz(xx, by), rng.uniform(0.38, 0.5), grass, seed)
        xx += rng.uniform(0.7, 1.4)
    for bx, by in ((-5.1, -1.0), (5.2, 1.6), (-4.6, 3.2), (4.7, -5.6), (-5.3, -6.1)):
        blades += blade_tuft(rng, bx, by, gz(bx, by), 9, 0.36, grass, spread=0.2, width=0.04)
        sea_oat_heads(rng, bx + 0.1, by, gz(bx, by), 0.5, grass, seed)
    join(blades, "Tufts")
    # Kabuklar ve deniz yıldızları (pastel, mat).
    shell_cols = ["#F9DCD2", "#FFF1DF", "#F2D9EA"]
    for k, (sx, sy, size) in enumerate(((-3.9, -3.6, 0.2), (4.2, -1.6, 0.17), (-4.6, 1.4, 0.15),
                                        (3.6, 3.0, 0.14), (-2.9, -6.0, 0.18), (2.7, -6.4, 0.16))):
        m = mat("Shell%d" % (k % 3), shell_cols[k % 3], rough=0.45, ao=0.5, ao_dist=0.08, sheen=0.3,
                spec=0.4, coat=0.2)
        scallop((sx, sy, gz(sx, sy) + size * 0.12), size, m, rng.uniform(-0.7, 0.7))
    star_m = mat("Starfish", "#F6B9A3", "#FBD3C0", rough=0.6, ao=0.5, ao_dist=0.1, bump=0.35,
                 bump_scale=40.0, grad=(0.0, 1.0), spec=0.25)
    for sx, sy, size in ((-4.3, -4.8, 0.42), (4.6, 0.3, 0.34), (3.4, -5.2, 0.3)):
        starfish((sx, sy, gz(sx, sy)), size, star_m, rng.uniform(0, math.tau))
    peb = mat("Pebble", "#E3DCD2", "#F2EDE6", rough=0.6, ao=0.5, ao_dist=0.1, noise=0.05, noise_scale=4.0,
              spec=0.3)
    for px, py in ((-5.0, -2.6), (-4.75, -2.85), (5.0, 2.4), (4.1, -3.9), (-3.4, 2.6), (5.2, -6.6)):
        s = rng.uniform(0.1, 0.16)
        blob([(px, py, gz(px, py) + s * 0.25, 1.0, s, s * 0.8, s * 0.45)], peb, res=0.012, smooth=4,
             name="Pebble")
    render("bg_ground")


def beach_palm():
    """Palmiye: halka kabartılı kavisli gövde (taban 180,900) + ayrı, rüzgârda sallanan taç."""
    reset()
    light_rig()
    camera(360, 900, 0.0, 4.5, 3.0)
    bark = mat("PalmBark", "#CDAE8C", "#E2CBAA", rough=0.75, ao=0.6, ao_dist=0.2, grain=0.05,
               grain_scale=4.0, grain_dir="Z", grad=(0.0, 1.0), spec=0.25)
    n = 80
    lean = 1.05
    top_z = 8.35
    pts = []
    for i in range(n + 1):
        t = i / n
        r = 0.27 * (1 - t) + 0.15 * t + 0.12 * math.exp(-t * 18.0)
        ring = (0.5 + 0.5 * math.cos(math.tau * 15.0 * t)) ** 3
        pts.append((lean * t ** 1.7, 0.0, -0.15 + (top_z + 0.15) * t, r * (1.0 + 0.07 * ring)))
    tube(pts, bark, "PalmTrunk", res=12)
    top = (lean, 0.0, top_z)
    ANCHORS["beach_trunk_top_px"] = [list(map(round, proj(360, 900, 4.5, 3.0, *top)))]
    render("hero_trunk")

    reset()
    light_rig(rim=0.3)
    camera(640, 640, 0.0, 0.0, 4.0)
    rng = random.Random(53)
    hub = Vector((0.0, 0.0, 0.62))
    frond_ms = [mat("Frond%d" % k, c, t2, rough=0.7, ao=0.45, ao_dist=0.2, haze=0.06, haze_color="#E8F4E2",
                    grad=(0.0, 1.0), sheen=0.2, spec=0.3)
                for k, (c, t2) in enumerate((("#7FB98A", "#9ACB9C"), ("#93C898", "#B5DBAE"), ("#A9D5A6", "#CDE9BE")))]
    specs = [(-8, 2.75, 0.7, 0.2), (22, 2.8, 0.62, -0.25), (52, 2.55, 0.5, 0.3), (88, 2.2, 0.42, -0.2),
             (124, 2.55, 0.5, 0.25), (156, 2.8, 0.66, -0.2), (186, 2.7, 0.75, 0.15), (-36, 2.35, 0.85, -0.35),
             (214, 2.3, 0.85, 0.35), (70, 2.0, 0.3, -0.55), (140, 2.1, 0.45, -0.6)]
    for ang, length, droop, dy in specs:
        frond(hub, math.radians(ang), length, droop, dy, frond_ms, rng)
    nut = mat("Nut", "#C7A27B", "#DDBE98", rough=0.5, ao=0.5, ao_dist=0.1, spec=0.35, coat=0.2)
    ellipsoid(tuple(hub + Vector((0, 0.05, -0.05))), (0.24, 0.22, 0.2), mat("Hub", "#B9946F", rough=0.7, ao=0.5,
                                                                           ao_dist=0.1))
    for dx, dz in ((-0.14, -0.2), (0.12, -0.22), (0.0, -0.33)):
        ellipsoid(tuple(hub + Vector((dx, -0.16, dz))), (0.14, 0.13, 0.15), nut, segments=48, rings=24)
    ANCHORS["beach_crown_pivot_px"] = [list(map(round, proj(640, 640, 0.0, 4.0, *hub)))]
    render("hero_crown")


def frond(hub, ang, length, droop, dy, mats, rng):
    """Tek palmiye yaprağı: kavisli ince orta damar + iki yanda uca doğru yatık, sarkık, yassı
    elipsoid yaprakçıklar (her biri pürüzsüz). Tonu kökten uca açılır (3 malzeme kademesi)."""
    u = Vector((math.cos(ang), 0.0, math.sin(ang)))

    def centre(t):
        c = hub + u * (length * t) + Vector((0.0, dy * length * t, -droop * length * t * t))
        return c + Vector((0.0, 0.0, 0.22 * length * t * (1 - t)))

    rib = []
    for k in range(9):
        t = k / 8
        c = centre(t)
        rib.append((c.x, c.y, c.z, 0.04 * (1 - t) + 0.012))
    tube(rib, mats[0], "Rib", res=6)
    count = 15
    view = Vector((0.0, -1.0, 0.0))
    for i in range(count):
        t = 0.1 + 0.88 * i / (count - 1)
        c = centre(t)
        tangent = (centre(min(t + 0.01, 1.0)) - centre(max(t - 0.01, 0.0))).normalized()
        side = tangent.cross(view).normalized()
        leaf_len = length * (0.34 * math.sin(math.pi * (0.12 + 0.8 * t)) + 0.05)
        m = mats[min(int(t * 3.0), 2)]
        for sgn in (-1.0, 1.0):
            d = (side * sgn * math.cos(math.radians(48)) + tangent * math.sin(math.radians(48))).normalized()
            d = (d + Vector((0.0, 0.0, -0.35 - 0.4 * t))).normalized()
            yb = (view - d * view.dot(d)).normalized()
            zb = d.cross(yb).normalized()
            basis = Matrix((d, yb, zb)).transposed()
            mid = c + d * (leaf_len * 0.5) + Vector((0.0, rng.uniform(-0.03, 0.03), 0.0))
            bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, radius=1.0, location=mid)
            leaf = bpy.context.view_layer.objects.active
            leaf.rotation_euler = basis.to_euler()
            leaf.scale = (leaf_len * 0.5, 0.02, length * 0.034)
            # Yaprakçığı hafifçe kaşıkla: uçları kameradan geriye kıvrılır.
            for v in leaf.data.vertices:
                v.co.y += 0.6 * v.co.x * v.co.x
            bpy.ops.object.shade_smooth()
            assign(leaf, m)


def make_pole_variant(base_kind, wood_cols, grass_cols=None):
    """Bahçe direğiyle AYNI geometri (halka/kol yükseklikleri oyunla hizalı), farklı taban ve renk."""
    reset()
    light_rig()
    camera(160, 1400, 0.0, 7.0, 0.0)
    wood = mat("PoleWood", wood_cols[0], wood_cols[1], rough=0.6, ao=0.5, ao_dist=0.2, grain=0.1,
               grain_scale=7.0, grain_dir="X", grad=(0.0, 1.0), coat=0.1)
    arm_wood = mat("ArmWood", wood_cols[0], rough=0.6, ao=0.5, ao_dist=0.2, grain=0.1, grain_scale=7.0,
                   grain_dir="Z", coat=0.1)
    metal = mat("Ring", "#C9CED6", rough=0.3, metallic=0.85, ao=0.2, ao_dist=0.05)
    top = 13.25
    tube([(0, 0, -0.2, 0.19), (0, 0, 6.0, 0.18), (0, 0, top, 0.165)], wood, res=10)
    ellipsoid((0, 0, top + 0.02), (0.185, 0.185, 0.12), wood)
    arm_z = top - 0.32
    tube([(-0.68, 0, arm_z, 0.085), (0.0, 0, arm_z, 0.09), (0.68, 0, arm_z, 0.085)], arm_wood, res=8)
    for side in (-1, 1):
        ellipsoid((side * 0.68, 0, arm_z), (0.07, 0.095, 0.095), arm_wood)
        tube([(side * 0.12, 0, arm_z - 0.75, 0.05), (side * 0.32, 0, arm_z - 0.42, 0.048),
              (side * 0.5, 0, arm_z - 0.08, 0.045)], arm_wood, res=6)
        bpy.ops.mesh.primitive_torus_add(major_radius=0.075, minor_radius=0.017,
                                         location=(side * 0.6, -0.02, arm_z - 0.16),
                                         rotation=(math.radians(90), 0, 0), major_segments=48,
                                         minor_segments=16)
        bpy.ops.object.shade_smooth()
        assign(bpy.context.view_layer.objects.active, metal)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.17, minor_radius=0.022, location=(0, 0, arm_z - 0.95),
                                     major_segments=64, minor_segments=16)
    bpy.ops.object.shade_smooth()
    assign(bpy.context.view_layer.objects.active, metal)
    rng = random.Random(59)
    if base_kind == "sand":
        sand = mat("PoleSand", SAND, SAND_TOP, rough=0.95, ao=0.45, ao_dist=0.3, noise=0.04, noise_scale=3.0,
                   grad=(0.0, 1.0), spec=0.15)
        blob([(0.0, -0.05, -0.12, 1.0, 0.7, 0.45, 0.3), (0.25, -0.1, -0.08, 1.0, 0.4, 0.3, 0.22)], sand,
             res=0.02, smooth=6, name="Mound")
        grass = mat("PoleGrass", grass_cols[0], grass_cols[1], rough=0.7, ao=0.3, ao_dist=0.15,
                    grad=(0.0, 1.0), spec=0.3)
        blades = blade_tuft(rng, -0.42, -0.2, 0.05, 8, 0.45, grass, spread=0.14, width=0.05)
        blades += blade_tuft(rng, 0.45, -0.15, 0.05, 6, 0.36, grass, spread=0.12, width=0.05)
        join(blades, "PoleTuft")
    else:
        conc = mat("PoleBase", "#E6E1DA", "#F2EEE8", rough=0.75, ao=0.5, ao_dist=0.15, noise=0.04,
                   noise_scale=6.0, grad=(0.0, 1.0), spec=0.25)
        rounded_box((0.0, 0.0, 0.17), (1.0, 0.7, 0.42), 0.12, conc, segments=8)
        rounded_box((0.0, 0.0, 0.43), (0.56, 0.5, 0.14), 0.06, conc, segments=6)
        bolt = mat("Bolt", "#C3C8CF", rough=0.35, metallic=0.7, ao=0.2, ao_dist=0.03)
        for bx in (-0.36, 0.36):
            ellipsoid((bx, -0.36, 0.22), (0.045, 0.03, 0.045), bolt, segments=24, rings=12)
    render("pole")


def beach_decor():
    for name, seed in (("decor_1", 61), ("decor_2", 67)):
        reset()
        light_rig()
        camera(160, 240, 0.0, 1.2, 8.0)
        rng = random.Random(seed)
        grass = mat("Oats", DUNE_GRASS, DUNE_GRASS_TOP, rough=0.7, ao=0.3, ao_dist=0.12, grad=(0.0, 1.0),
                    spec=0.3)
        seed_m = mat("Seed", "#E5CFA0", "#F5E8C8", rough=0.55, ao=0.25, ao_dist=0.05, sheen=0.3)
        sand = mat("DecorSand", SAND, SAND_TOP, rough=0.95, ao=0.4, ao_dist=0.2, spec=0.15)
        blob([(0.0, 0.0, 0.0, 1.0, 0.55, 0.3, 0.1)], sand, res=0.015, smooth=6, name="Mound")
        blades = []
        for _ in range(11 if seed == 61 else 9):
            bx = rng.uniform(-0.3, 0.3)
            blades.append(grass_blade(bx, rng.uniform(-0.1, 0.1), 0.02, rng.uniform(0.7, 1.25),
                                      rng.uniform(0.12, 0.35) * (1 if bx > 0 else -1) * 0.8,
                                      rng.uniform(-0.5, 0.5) + (0.0 if bx > 0 else math.pi), grass,
                                      width=rng.uniform(0.05, 0.065)))
        join(blades, "OatBlades")
        for k in range(3 if seed == 61 else 2):
            sea_oat_heads(rng, -0.15 + 0.15 * k, -0.05, 0.02, rng.uniform(1.45, 1.75), grass, seed_m)
        render(name)


# ============================================================================ ÇATI KATI

def rooftop_far():
    """Şehir silüeti: üç sıra yuvarlak köşeli bina; derinlikle artan pastel lila pus. Orta sırada
    kubbe ve kuleli yuvarlak bir kule. Yakın sıraların pencereleri gece yanar (çapalar yazdırılır)."""
    reset()
    light_rig(sun=1.0, sky=0.55, direction=(0.55, 0.55, -0.62))
    rng = random.Random(71)
    fr = Frame(1080, 900, 10.0, 720)
    rows = [
        # (derinlik, renk alt, üst, pus, pus rengi, tepe aralığı p, pencere mi)
        (26.0, "#C6C6E0", "#DADAEE", 0.55, "#E2E0F0", (120, 205), False),
        (18.0, "#D8CCDF", "#E8DEEC", 0.4, "#ECE3EE", (175, 255), True),
        (10.0, "#EAD9D3", "#F5EAE3", 0.26, "#F3EBE8", (240, 315), True),
    ]
    win_m = {}
    for ri, (depth, col, top, haze, hcol, (p0, p1), windows) in enumerate(rows):
        wall = mat("Bld%d" % ri, col, top, rough=0.85, haze=haze, haze_color=hcol, ao=0.4, ao_dist=0.3,
                   grad=(0.0, 1.0), spec=0.2)
        alt = mat("BldB%d" % ri, ("#CFCBE6", "#E3D3DA", "#F0DFCF")[ri], rough=0.85, haze=haze,
                  haze_color=hcol, ao=0.4, ao_dist=0.3, spec=0.2)
        roof = mat("BldRoof%d" % ri, ("#BCBCD8", "#D9B9BD", "#E7BBA8")[ri], rough=0.7, haze=haze,
                   haze_color=hcol, ao=0.3, ao_dist=0.1, spec=0.2)
        win = mat("Win%d" % ri, ("#D4D6EA", "#CBC7DE", "#D9CFD6")[ri], rough=0.4, haze=haze * 0.9,
                  haze_color=hcol, ao=0.0)
        win_m[ri] = win
        x = -6.0 + rng.uniform(0.0, 0.4)
        while x < 6.0:
            w = rng.uniform(0.7, 1.35) * (1.0 - 0.15 * (2 - ri))
            p_top = rng.uniform(p0, p1)
            d = 0.9
            front = depth - d / 2
            hz = fr.z_at(p_top, front)
            m = wall if rng.random() < 0.6 else alt
            rounded_box((x + w / 2, depth, hz / 2 - 0.5), (w, d, hz + 1.0), 0.07, m, segments=5)
            kind = rng.random()
            if kind < 0.28:
                # Yumuşak beşik çatı.
                pts = [(-w * 0.55, 0.0), (w * 0.55, 0.0), (0.0, w * 0.32)]
                dense = []
                for pa, pb in zip(pts, pts[1:] + pts[:1]):
                    for k in range(14):
                        t = k / 14
                        dense.append((pa[0] + (pb[0] - pa[0]) * t, pa[1] + (pb[1] - pa[1]) * t))
                slab(dense, d * 1.02, 0.05, roof, y=depth, loc=(x + w / 2, hz - 0.02), name="Roof")
            elif kind < 0.45:
                rounded_box((x + w * 0.3, depth + 0.1, hz + 0.18), (0.16, 0.16, 0.36), 0.04, roof)
            if windows:
                cols = max(int(w / 0.3), 2)
                rws = 3 if ri == 2 else 2
                for cx_i in range(cols):
                    for rz_i in range(rws):
                        wx = x + w * (cx_i + 0.5) / cols
                        wz = hz - 0.28 - rz_i * 0.42
                        rounded_box((wx, front - 0.01, wz), (0.13, 0.04, 0.2), 0.03, win, segments=3)
                        if rng.random() < (0.22 if ri == 2 else 0.12):
                            anchor("roof_city_r%d" % ri, fproj(fr, wx, front - 0.03, wz))
            x += w + rng.uniform(0.02, 0.12)
        if ri == 1:
            # Kubbe: kasnak + yumuşak kubbe + minik alem.
            dx, dd = -2.3, depth - 1.0
            dz = fr.z_at(205, dd)
            tube([(dx, dd, 0.0, 0.62), (dx, dd, dz, 0.62)], alt, res=12)
            dome = ellipsoid((dx, dd, dz), (0.66, 0.66, 0.52), roof)
            cap_cut(dome)
            tube([(dx, dd, dz + 0.5, 0.03), (dx, dd, dz + 0.72, 0.02)], roof, res=6)
            # Yuvarlak kule (konik külahlı).
            tx, td = 2.6, depth - 1.2
            tz = fr.z_at(150, td)
            tube([(tx, td, 0.0, 0.34), (tx, td, tz * 0.6, 0.3), (tx, td, tz, 0.28)], wall, res=12)
            bpy.ops.mesh.primitive_torus_add(major_radius=0.3, minor_radius=0.045, location=(tx, td, tz - 0.25),
                                             major_segments=48, minor_segments=12)
            bpy.ops.object.shade_smooth()
            assign(bpy.context.view_layer.objects.active, roof)
            tube([(tx, td, tz, 0.32), (tx, td, tz + 0.3, 0.17), (tx, td, tz + 0.62, 0.02)], roof, res=12)
    ground = mat("CityGround", "#EAD9D3", rough=0.95, haze=0.3, haze_color="#F3EBE8", ao=0.0, spec=0.2)
    bpy.ops.mesh.primitive_plane_add(size=1.0, location=(0.0, 12.0, -0.6))
    plane = bpy.context.view_layer.objects.active
    plane.scale = (40.0, 40.0, 1.0)
    assign(plane, ground)
    render("bg_far")


def barrel_roof(x0, x1, depth, eave_z, ridge_z, run, tile_m, under_m):
    """Kiremit çatı (karşıya bakan eğim): yumuşak oluklu kiremit sıraları yukarı doğru uzanır."""
    pts = [(x0, eave_z), (x1, eave_z), (x1, ridge_z), (x0, ridge_z)]
    # Eğimli alt yüzey: X ekseni etrafında döndürülmüş ince levha.
    ang = math.atan2(ridge_z - eave_z, run)
    length = math.hypot(ridge_z - eave_z, run)
    rounded_box(((x0 + x1) / 2, depth + run / 2, (eave_z + ridge_z) / 2), (x1 - x0, length, 0.08), 0.03,
                under_m, rot=(ang, 0.0, 0.0))
    # Her oluk sütunu 4 kursa bölünür; her kiremit üst ucunda incelir ve bir üsttekinin altına
    # girer: kesintisiz "boru" yerine kiremit kademesi okunur.
    courses = 4
    x = x0 + 0.1
    while x < x1 - 0.05:
        for c_i in range(courses):
            t0, t1 = c_i / courses, min((c_i + 1.15) / courses, 1.0)
            pa = (x, depth - 0.04 + run * t0, eave_z + 0.05 + (ridge_z - eave_z) * t0, 0.105)
            pb = (x, depth - 0.04 + run * t1, eave_z + 0.05 + (ridge_z - eave_z) * t1 - 0.03, 0.085)
            tube([pa, pb], tile_m, "Tile", res=8)
            ellipsoid(pa[:3], (0.105, 0.05, 0.105), tile_m, segments=24, rings=12)
        x += 0.23
    tube([(x0 - 0.05, depth + run, ridge_z + 0.1, 0.12), (x1 + 0.05, depth + run, ridge_z + 0.1, 0.12)], tile_m,
         "Ridge", res=10)
    return pts


def rooftop_mid():
    """Komşu çatılar: solda kiremit çatı + baca, sağda düz çatıda su deposu, anten ve çanak;
    ortada alçak çatı çizgisi (şehir görünür kalsın). Bacadan depoya sarkan iki sıra ampul."""
    reset()
    light_rig(sun=1.08, sky=0.5, direction=(0.58, 0.48, -0.66))
    rng = random.Random(73)
    fr = Frame(1080, 700, 8.0, 640)
    wall_a = mat("WallA", "#F1E2D6", "#F7EDE4", rough=0.85, haze=0.16, haze_color="#F4EEEA", ao=0.45,
                 ao_dist=0.4, grad=(0.0, 1.0), noise=0.03, noise_scale=1.0, spec=0.2)
    wall_b = mat("WallB", "#E4E0EE", "#EFECF5", rough=0.85, haze=0.16, haze_color="#F1EFF4", ao=0.45,
                 ao_dist=0.4, grad=(0.0, 1.0), noise=0.03, noise_scale=1.0, spec=0.2)
    wall_c = mat("WallC", "#EFE6D2", rough=0.85, haze=0.2, haze_color="#F4EFE6", ao=0.45, ao_dist=0.4,
                 spec=0.2)
    tile = mat("RoofTile", "#E7B5A0", "#F1CDBB", rough=0.6, haze=0.14, haze_color="#F4E9E4", ao=0.6,
               ao_dist=0.12, grad=(0.0, 1.0), spec=0.3)
    under = mat("RoofUnder", "#D9A894", rough=0.7, haze=0.14, haze_color="#F4E9E4", ao=0.5, ao_dist=0.1)
    cap = mat("Coping", "#F6F1EA", rough=0.7, haze=0.15, haze_color="#F4F1EC", ao=0.4, ao_dist=0.1, spec=0.25)
    brick = mat("Chimney", "#E3B4A2", "#EDC7B6", rough=0.8, haze=0.14, haze_color="#F4E9E4", ao=0.5,
                ao_dist=0.1, noise=0.05, noise_scale=6.0, grad=(0.0, 1.0), spec=0.2)
    metal = mat("Metal", "#D7DCE3", "#EEF1F4", rough=0.35, metallic=0.5, haze=0.14, haze_color="#F1F3F6",
                ao=0.4, ao_dist=0.1, grad=(0.0, 1.0), spec=0.4)
    # Sol bina + kiremit çatı.
    ld = 3.5
    eave = fr.z_at(262, ld)
    rounded_box((-4.0, ld + 1.0, eave / 2 - 2.0), (4.4, 2.0, eave + 4.0), 0.1, wall_a, segments=6)
    ridge = fr.z_at(196, ld + 1.6)
    barrel_roof(-6.2, -1.85, ld, eave, ridge, 1.6, tile, under)
    cx_ch = -3.1
    ch_top = fr.z_at(92, ld + 1.0)
    rounded_box((cx_ch, ld + 1.0, (ridge + ch_top) / 2 - 0.2), (0.46, 0.46, ch_top - ridge + 0.6), 0.07, brick)
    rounded_box((cx_ch, ld + 1.0, ch_top + 0.04), (0.58, 0.58, 0.1), 0.04, cap)
    tube([(cx_ch - 0.1, ld + 1.0, ch_top, 0.07), (cx_ch - 0.1, ld + 1.0, ch_top + 0.22, 0.065)], metal, res=8)
    # Orta: daha geride alçak bina (şehre pencere).
    md = 7.0
    mid_top = fr.z_at(232, md)
    rounded_box((0.0, md, mid_top / 2 - 2.0), (4.4, 1.6, mid_top + 4.0), 0.08, wall_c, segments=6)
    rounded_box((0.0, md - 0.1, mid_top + 0.05), (4.5, 1.7, 0.12), 0.05, cap)
    # Küçük çatı kulübesi.
    rounded_box((0.9, md + 0.2, mid_top + 0.3), (0.9, 0.7, 0.6), 0.07, wall_b)
    rounded_box((0.9, md + 0.2, mid_top + 0.64), (1.05, 0.85, 0.08), 0.04, tile)
    # Sağ bina: düz çatı, korkuluk, su deposu, anten, çanak.
    rd = 3.2
    r_top = fr.z_at(248, rd)
    rounded_box((4.1, rd + 1.0, r_top / 2 - 2.0), (4.0, 2.0, r_top + 4.0), 0.1, wall_b, segments=6)
    rounded_box((4.1, rd - 0.02, r_top + 0.06), (4.1, 0.2, 0.16), 0.05, cap)
    tx, tdp = 3.55, rd + 1.1
    leg_top = r_top + 0.55
    for lx, ly in ((-0.32, -0.25), (0.32, -0.25), (-0.32, 0.25), (0.32, 0.25)):
        tube([(tx + lx, tdp + ly, r_top, 0.04), (tx + lx, tdp + ly, leg_top, 0.04)], metal, res=6)
    tank = mat("Tank", "#CFE0E6", "#E6F0F2", rough=0.5, metallic=0.2, haze=0.14, haze_color="#F1F3F6", ao=0.5,
               ao_dist=0.15, grad=(0.0, 1.0), spec=0.35)
    tank_h = fr.z_at(118, tdp) - leg_top
    tube([(tx, tdp, leg_top, 0.5), (tx, tdp, leg_top + tank_h * 0.5, 0.52), (tx, tdp, leg_top + tank_h, 0.5)],
         tank, res=14)
    for bz in (0.3, 0.7):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.52, minor_radius=0.025,
                                         location=(tx, tdp, leg_top + tank_h * bz), major_segments=64,
                                         minor_segments=12)
        bpy.ops.object.shade_smooth()
        assign(bpy.context.view_layer.objects.active, metal)
    lid = ellipsoid((tx, tdp, leg_top + tank_h), (0.53, 0.53, 0.22), tank)
    cap_cut(lid)
    # Anten: kalın yuvarlak direk + iki yumuşak kol.
    ax = 4.75
    a_top = fr.z_at(48, rd + 1.4)
    tube([(ax, rd + 1.4, r_top, 0.045), (ax, rd + 1.4, a_top, 0.035)], metal, res=8)
    for k, (zz, half) in enumerate(((a_top - 0.25, 0.42), (a_top - 0.6, 0.32))):
        tube([(ax - half, rd + 1.4, zz, 0.028), (ax + half, rd + 1.4, zz, 0.028)], metal, res=6)
        for e in (-half, half):
            ellipsoid((ax + e, rd + 1.4, zz), (0.04, 0.04, 0.04), metal, segments=16, rings=8)
    ellipsoid((ax, rd + 1.4, a_top), (0.05, 0.05, 0.05), metal, segments=16, rings=8)
    # Bacadan antene sarkan iki sıra ampul (kablo + krem cam küre).
    cable = mat("Cable", "#9C8E86", rough=0.6, haze=0.1, haze_color="#F1EEEC", ao=0.0)
    bulb = glow_mat("Bulb", "#FFF3D2", 1.0)
    for (xa, za), (xb, zb), sag, depth in (((cx_ch + 0.25, ch_top - 0.2), (tx - 0.5, leg_top + tank_h * 0.75), 0.75, 2.4),
                                           ((tx + 0.5, leg_top + tank_h * 0.6), (ax, a_top - 0.62), 0.35, 2.4)):
        steps = 40
        pts = []
        for k in range(steps + 1):
            t = k / steps
            pts.append((xa + (xb - xa) * t, depth, za + (zb - za) * t - sag * 4 * t * (1 - t), 0.02))
        tube(pts, cable, "Cable", res=6)
        n_bulbs = max(int(abs(xb - xa) / 0.42), 2)
        for k in range(1, n_bulbs):
            t = k / n_bulbs
            x = xa + (xb - xa) * t
            z = za + (zb - za) * t - sag * 4 * t * (1 - t)
            tube([(x, depth, z, 0.012), (x, depth, z - 0.07, 0.012)], cable, res=4)
            ellipsoid((x, depth, z - 0.13), (0.055, 0.055, 0.07), bulb, segments=24, rings=12)
            anchor("roof_bulbs", fproj(fr, x, depth, z - 0.13))
    render("bg_mid")


def rooftop_fence():
    """Alçak tuğla korkuluk: yumuşak yuvarlak köşeli pastel kiremit rengi tuğlalar (şaşırtmalı),
    arkada açık harç, üstte krem beton harpuşta."""
    reset()
    light_rig(sun=1.1, sky=0.5, direction=(0.6, 0.5, -0.62))
    rng = random.Random(79)
    fr = Frame(1080, 420, 10.0, 360)
    top = fr.z_at(58, 0.0)
    coping = mat("Coping", "#F3ECE2", "#FAF6F0", rough=0.7, ao=0.45, ao_dist=0.15, noise=0.03,
                 noise_scale=4.0, grad=(0.0, 1.0), spec=0.3)
    mortar = mat("Mortar", "#F5E9DE", rough=0.9, ao=0.45, ao_dist=0.1, spec=0.15)
    tones = [mat("Brick%d" % i, c, t, rough=0.8, ao=0.45, ao_dist=0.08, noise=0.04, noise_scale=7.0,
                 grad=(0.0, 1.0), spec=0.2)
             for i, (c, t) in enumerate((("#EDC6B2", "#F3D5C5"), ("#F0CDBB", "#F6DCCE"), ("#E9BFAB", "#F0CFBF")))]
    rounded_box((0.0, 0.08, top - 1.0), (12.2, 0.2, 2.2), 0.04, mortar)
    rounded_box((0.0, -0.04, top - 0.09), (12.2, 0.62, 0.2), 0.07, coping, segments=8)
    bh, bw, gap = 0.24, 0.56, 0.035
    z = top - 0.2 - bh / 2 - gap
    row = 0
    while z > -1.7:
        x = -6.2 + (bw / 2 if row % 2 else 0.0)
        while x < 6.3:
            rounded_box((x, -0.06, z), (bw - gap, 0.3, bh - gap), 0.05, tones[rng.randrange(3)], segments=4)
            x += bw
        z -= bh
        row += 1
    render("bg_fence")


def rooftop_ground():
    """Teras zemini: yastık gibi yumuşak pastel kiremit karolar, açık derz, arkada beton süpürgelik;
    köşelerde tombul saksı bitkileri ve bir sulama kabı. Ortası temiz."""
    reset()
    light_rig(sun=1.0, sky=0.55, direction=(0.55, 0.62, -0.6))
    rng = random.Random(83)
    tilt = 38.0
    st = math.sin(math.radians(tilt))
    camera(1080, 820, 0.0, 0.0, tilt)
    back_y = (4.1 - 0.55) / st
    grout = mat("Grout", "#F6EADF", rough=0.9, ao=0.15, ao_dist=0.1, spec=0.15)
    bpy.ops.mesh.primitive_plane_add(size=1.0, location=(0.0, (back_y - 7.4) / 2, -0.02))
    plane = bpy.context.view_layer.objects.active
    plane.scale = (12.6, back_y + 7.6, 1.0)
    assign(plane, grout)
    tones = [mat("Floor%d" % i, c, t, rough=0.75, ao=0.2, ao_dist=0.08, noise=0.035, noise_scale=2.5,
                 grad=(0.0, 1.0), grad_axis="Y", spec=0.25, sheen=0.1)
             for i, (c, t) in enumerate((("#F2D3BF", "#F7E0D1"), ("#F4D8C6", "#F8E3D6"), ("#F0CFBA", "#F5DCCB")))]
    size, gap = 1.36, 0.045
    yy = back_y - size / 2 - 0.12
    while yy > -7.8:
        xx = -6.24 + size / 2
        while xx < 6.4:
            rounded_box((xx, yy, 0.0), (size - gap, size - gap, 0.07), 0.034, tones[rng.randrange(3)], segments=4)
            xx += size
        yy -= size
    skirting = mat("Skirt", "#F2ECE4", "#F8F4EF", rough=0.75, ao=0.4, ao_dist=0.12, grad=(0.0, 1.0), spec=0.25)
    rounded_box((0.0, back_y + 0.02, 0.06), (12.6, 0.22, 0.22), 0.06, skirting, segments=6)
    # Sepet alanının altında yumuşak, çizgili dış mekân kilimi: karo ızgarasını böler, sahneye
    # "yaşanan teras" sıcaklığı verir; renkleri soluk (sepetler önde okunur).
    rug_m = stripe_mat("Rug", "#F8F1E7", "#DEEBDD", 0.42, rough=0.95, ao=0.3, direction="Y")
    rug_y0, rug_y1 = -2.6, 3.7
    rounded_box((0.0, (rug_y0 + rug_y1) / 2, 0.07), (7.6, rug_y1 - rug_y0, 0.05), 0.025, rug_m, segments=4)
    fringe = mat("Fringe", "#F4ECE0", rough=0.9, ao=0.2, ao_dist=0.05)
    for fy in (rug_y0, rug_y1):
        xx = -3.7
        while xx <= 3.71:
            sgn = -1 if fy == rug_y0 else 1
            tube([(xx, fy, 0.08, 0.022), (xx + 0.01, fy + sgn * 0.14, 0.075, 0.018)], fringe, "Fringe", res=4)
            xx += 0.13
    # Saksılar.
    clay = mat("Clay", "#E2AE94", "#EDC2AD", rough=0.7, ao=0.45, ao_dist=0.15, noise=0.03, noise_scale=3.0,
               grad=(0.0, 1.0), spec=0.25)
    rim = mat("ClayRim", "#E9B9A2", rough=0.65, ao=0.4, ao_dist=0.1, spec=0.25)
    soil = mat("Soil", "#B79A86", rough=0.95, ao=0.5, ao_dist=0.1)
    leaf = mat("PotLeaf", "#8FC690", "#CDEBB6", rough=0.8, ao=0.65, ao_dist=0.25, grad=(0.1, 0.95), spec=0.25,
               sheen=0.15)
    blossom = mat("Blossom", "#F7C5CF", rough=0.55, ao=0.3, ao_dist=0.05, sheen=0.3)
    for px, py, r, h, bush, flowers in ((4.75, -5.6, 0.62, 0.95, leaf, True),):
        tapered_pot((px, py, 0.0), r * 0.75, r, h, clay, rim, soil)
        objs = []
        for k in range(7):
            a = math.tau * k / 7 + rng.uniform(-0.2, 0.2)
            rr = r * rng.uniform(0.42, 0.55)
            objs.append(puff(rng, (px + math.cos(a) * r * 0.6, py + math.sin(a) * r * 0.5,
                                   h + rr * 0.6), rr, bush, lumps=3, name="PotBush"))
        puff(rng, (px, py - r * 0.1, h + r * 0.7), r * 0.62, bush, lumps=4, name="PotBush")
        if flowers:
            for _ in range(9):
                a = rng.uniform(0, math.tau)
                ellipsoid((px + math.cos(a) * r * 0.75, py - r * 0.4 + math.sin(a) * r * 0.25,
                           h + r * rng.uniform(0.6, 1.2)), (0.08, 0.06, 0.08), blossom, segments=24, rings=12)
    # Sulama kabı (yumuşak, pastel nane).
    can = mat("Can", "#BFDCCF", "#DCEEE5", rough=0.4, metallic=0.2, ao=0.45, ao_dist=0.1, grad=(0.0, 1.0),
              spec=0.4, coat=0.3)
    cx, cy = -4.4, -5.2
    tube([(cx, cy, 0.0, 0.3), (cx, cy, 0.25, 0.31), (cx, cy, 0.48, 0.28)], can, res=12)
    ellipsoid((cx, cy, 0.48), (0.28, 0.28, 0.06), can)
    tube([(cx + 0.22, cy, 0.12, 0.06), (cx + 0.5, cy, 0.38, 0.045), (cx + 0.7, cy, 0.62, 0.04)], can, res=8)
    ellipsoid((cx + 0.72, cy, 0.64), (0.08, 0.06, 0.06), can)
    tube([(cx - 0.18, cy, 0.5, 0.035), (cx, cy, 0.78, 0.035), (cx + 0.18, cy, 0.5, 0.035)], can, res=6)
    render("bg_ground")


def rooftop_tree():
    """Komşu terastaki zeytin ağacı: iki gövdeli burgu gövde (dikişsiz) + adaçayı yeşili taç.
    (Önde limon denendi; taçta "delik/benek" gibi okunduğu için kaldırıldı.)"""
    reset()
    light_rig()
    camera(360, 900, 0.0, 4.5, 3.0)
    bark = mat("Olive", "#B9A08A", "#CDB8A2", rough=0.8, ao=0.55, ao_dist=0.35, grain=0.12, grain_scale=5.0,
               grain_dir="X", bump=0.25, bump_scale=6.0, grad=(0.0, 1.0))
    parts = []
    for phase in (0.0, math.pi):
        pts = []
        for k in range(9):
            t = k / 8
            pts.append((0.16 * math.sin(t * 5.0 + phase), 0.1 * math.cos(t * 5.0 + phase), -0.1 + 6.0 * t,
                        0.3 - 0.14 * t))
        parts.append(tube(pts, bark))
    parts.append(tube([(0.0, 0, 5.4, 0.18), (0.6, 0, 6.5, 0.13), (1.1, 0, 7.6, 0.09), (1.2, 0, 8.4, 0.06)], bark))
    parts.append(tube([(0.0, 0, 5.0, 0.18), (-0.65, 0, 6.2, 0.12), (-1.1, 0, 7.2, 0.08), (-1.2, 0, 8.0, 0.06)],
                      bark))
    parts.append(tube([(0.0, 0, 5.8, 0.16), (0.05, 0, 7.4, 0.11), (-0.05, 0, 8.8, 0.06)], bark))
    trunk = join(parts, "Trunk")
    remesh(trunk, 0.025, 10)
    render("hero_trunk")

    reset()
    light_rig(rim=0.3)
    camera(640, 640, 0.0, 0.0, 4.0)
    rng = random.Random(89)
    crown_m = mat("OliveCrown", "#9CC49A", "#DDEFCF", rough=0.8, ao=0.75, ao_dist=0.5, grad=(0.12, 0.95),
                  noise=0.03, noise_scale=1.4, sheen=0.2, spec=0.3, haze=0.1, haze_color="#ECF4E6")
    crown_masses(rng, (0.0, 0.0, 0.0), 2.75, 2.45, crown_m, mass=1.02)
    render("hero_crown")


def rooftop_decor():
    for name, kind in (("decor_1", "geranium"), ("decor_2", "lavender")):
        reset()
        light_rig()
        camera(160, 240, 0.0, 1.2, 8.0)
        rng = random.Random(97 if kind == "geranium" else 101)
        clay = mat("Clay", "#E3B09A", "#EEC6B3", rough=0.7, ao=0.45, ao_dist=0.1, grad=(0.0, 1.0), spec=0.25)
        rim = mat("ClayRim", "#EABCA7", rough=0.65, ao=0.4, ao_dist=0.08, spec=0.25)
        soil = mat("Soil", "#B79A86", rough=0.95, ao=0.5, ao_dist=0.1)
        tapered_pot((0.0, 0.0, 0.07), 0.3, 0.4, 0.55, clay, rim, soil)
        if kind == "geranium":
            leaf = mat("GerLeaf", "#8FC690", "#C9EAB2", rough=0.8, ao=0.6, ao_dist=0.15, grad=(0.1, 0.95),
                       spec=0.25, sheen=0.15)
            for k in range(6):
                a = math.tau * k / 6 + rng.uniform(-0.2, 0.2)
                puff(rng, (math.cos(a) * 0.28, math.sin(a) * 0.12 - 0.05, 0.7 + rng.uniform(0.0, 0.12)), 0.2, leaf,
                     lumps=3, name="GerLeaf")
            stem = mat("GerStem", "#93C285", rough=0.6, ao=0.2, ao_dist=0.05)
            pet = mat("GerPetal", "#F6B5C2", "#FBD3DB", rough=0.55, ao=0.35, ao_dist=0.05, sheen=0.3,
                      grad=(0.0, 1.0))
            for fx, fz in ((-0.22, 1.42), (0.18, 1.55), (0.02, 1.25)):
                tube([(fx * 0.4, -0.05, 0.7, 0.025), (fx * 0.8, -0.06, fz - 0.25, 0.022), (fx, -0.08, fz - 0.08, 0.02)],
                     stem, res=6)
                for _ in range(9):
                    a, b = rng.uniform(0, math.tau), rng.uniform(0.3, 1.0)
                    ellipsoid((fx + math.cos(a) * 0.13 * b, -0.1 - 0.05 * b, fz + math.sin(a) * 0.1 * b),
                              (0.075, 0.05, 0.07), pet, segments=24, rings=12)
        else:
            sage = mat("LavLeaf", "#A9C6A4", "#D5E6CC", rough=0.8, ao=0.55, ao_dist=0.15, grad=(0.1, 0.95),
                       spec=0.25)
            puff(rng, (0.0, -0.02, 0.68), 0.28, sage, lumps=4, name="LavBush")
            stem = mat("LavStem", "#A3BF98", rough=0.6, ao=0.2, ao_dist=0.05)
            spike = mat("LavSpike", "#C7B6E6", "#E2D8F4", rough=0.6, ao=0.35, ao_dist=0.04, sheen=0.3,
                        grad=(0.0, 1.0))
            for k in range(9):
                ang = math.radians(-34 + 68 * k / 8 + rng.uniform(-4, 4))
                hgt = rng.uniform(0.75, 1.0)
                x1, z1 = math.sin(ang) * hgt * 0.7, 0.62 + math.cos(ang) * hgt
                yk = rng.uniform(-0.12, 0.08)
                tube([(0.0, yk, 0.62, 0.025), (x1 * 0.5, yk, (0.62 + z1) / 2, 0.022), (x1, yk, z1, 0.02)], stem,
                     res=6)
                for s in range(5):
                    t = s / 4
                    ellipsoid((x1 + math.sin(ang) * 0.07 * s, yk - 0.01, z1 + 0.06 + 0.075 * s),
                              (0.05 * (1 - 0.3 * t), 0.045, 0.055), spike, segments=20, rings=10)
        render(name)


def main():
    jobs = [
        ("beach", "far", beach_far), ("beach", "mid", beach_mid), ("beach", "fence", beach_fence),
        ("beach", "ground", beach_ground), ("beach", "hero", beach_palm),
        ("beach", "pole", lambda: make_pole_variant("sand", ("#D2B48F", "#E3CBA8"), (DUNE_GRASS, DUNE_GRASS_TOP))),
        ("beach", "decor", beach_decor),
        ("rooftop", "far", rooftop_far), ("rooftop", "mid", rooftop_mid), ("rooftop", "fence", rooftop_fence),
        ("rooftop", "ground", rooftop_ground), ("rooftop", "hero", rooftop_tree),
        ("rooftop", "pole", lambda: make_pole_variant("block", ("#C9A684", "#DDBE9A"))),
        ("rooftop", "decor", rooftop_decor),
    ]
    for place, layer, func in jobs:
        if want(place, layer):
            out_dir(place)
            func()
    for key, pts in sorted(ANCHORS.items()):
        print("ANCHOR %s %s" % (key, pts))


main()
