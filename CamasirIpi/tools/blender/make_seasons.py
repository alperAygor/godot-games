#!/usr/bin/env python3
"""Çamaşır İpi — mevsim varlıkları (sonbahar / kış / ilkbahar). Yaz = mevcut katmanlar.

    /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/make_seasons.py
    ... -- crowns                   # yalnız mevsimlik ağaç/palmiye taçları
    ... -- fences decals fx icons   # gruplar seçilebilir
    ... -- --preview                # yarım çözünürlük, az örnek

Neden bu yaklaşım (bellek/paket bütçesi): büyük katmanlar (uzak/orta/zemin) her mevsim için yeniden
render EDİLMEZ; oyunda renk derecelendirme gölgelendiricisiyle (season_grade.gdshader) boyanır.
Burada yalnız derecelendirmenin inandırıcı yapamadığı küçük parçalar üretilir:
  * kahraman taç (640x640) her mekân x mevsim: sonbaharda kehribar/mercan/altın kütleler, kışın
    üstü karlı kütleler, ilkbaharda taze yeşil + çiçek kümeleri (aynı geometri, aynı tohum: salınım
    pivotu ve silüet yazdaki taçla birebir aynı, oyunda yalnız doku değişir),
  * kışın çit eşdeğeri (1080x420): aynı çit, üst yüzeylerinde yumuşak kar,
  * küçük zemin süsleri (kar yığını, kardan adam, yaprak yığını, balkabağı, lale, çiçekli çalı),
  * ortam efekti sprite'ları (yaprak, taç yaprağı) ve mevsim afişi simgeleri.
Hepsi bahçe betiğinin yardımcılarıyla (mat, blob, tube, slab ...) üretilir: aynı ışık, aynı malzeme dili.
Mevsim rengi iki genel kancayla verilir — taç/çit kurucularına dokunmadan:
  * `lin` sarmalayıcısı: yeşillik tonundaki her malzeme rengi mevsim paletine çevrilir,
  * `render` sarmalayıcısı: render'dan hemen önce (kış) tüm malzemelere normal yönlü kar, (sonbahar)
    nesne başına rastgele ton oynaması, (ilkbahar) taç yüzeyine çiçek kümeleri eklenir.
Kural 1: low-poly yok — her şey metaball/yuvarlak bevel/pürüzsüz tüp.
"""

import colorsys
import math
import os
import random
import sys

import bpy
from mathutils import Vector

_HERE = os.path.dirname(os.path.abspath(__file__))
_LOC = os.path.join(_HERE, "make_locations.py")
with open(_LOC, encoding="utf-8") as _fh:
    _SRC = _fh.read()
# Mekân betiğinin sonundaki koşulsuz main() atılır; o da bahçe betiğini kendi içinde yükler.
_SRC = _SRC[:_SRC.rindex("\nmain()")]
_SRC = _SRC.replace("_HERE = os.path.dirname(os.path.abspath(__file__))", "_HERE = %r" % _HERE)
exec(compile(_SRC, _LOC, "exec"), globals())

ROOT = os.path.dirname(os.path.dirname(_HERE))
SEASON_DIR = os.path.join(ROOT, "assets", "sprites", "season")
ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
GROUPS = {a for a in ARGV if not a.startswith("--")}

_lin0 = lin
_render0 = render
# Etkin iş: mevsim, isim -> çıktı yolu eşlemesi.
JOB = {"season": None, "names": {}}

# Yeşillik tonu aralığı (HSV tonu) ve mevsim paletleri: ton hedefi, doygunluk ve parlaklık çarpanı.
FOLIAGE_HUE = (0.18, 0.47)
FOLIAGE_SAT_MIN = 0.08
RECOLOR = {
    # Sonbahar: kehribar-şeftali; pastel kalır (doygun turuncu çamaşırla yarışmasın).
    "autumn": {"hue": 0.075, "sat": 1.35, "val": 1.02},
    # Kış: karın altında soluk adaçayı-mavi yeşil.
    "winter": {"hue": 0.40, "sat": 0.75, "val": 0.95},
    # İlkbahar: taze, biraz daha sarımsı ve doygun yeşil.
    "spring": {"hue": -0.03, "sat": 1.15, "val": 1.03, "relative": True},
}
SNOW = "#F7FAFF"
SNOW_SHADE = "#E3EBF7"


def lin(hex_color):
    """Mevsim kancası: yeşillik rengi mevsim paletine çevrilir, diğer renkler aynen geçer."""
    season = JOB["season"]
    if season in RECOLOR:
        h = hex_color.lstrip("#")
        r, g, b = (int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
        hue, sat, val = colorsys.rgb_to_hsv(r, g, b)
        if FOLIAGE_HUE[0] <= hue <= FOLIAGE_HUE[1] and sat >= FOLIAGE_SAT_MIN:
            spec = RECOLOR[season]
            # Açık uç tonlar (taç tepesi) hedef tona biraz daha sarı kayar: güneş alan yaprak.
            lift = 0.025 * (1.0 - sat) if season == "autumn" else 0.0
            hue = (hue + spec["hue"]) % 1.0 if spec.get("relative") else spec["hue"] + lift
            sat = min(sat * spec["sat"], 1.0)
            val = min(val * spec["val"], 1.0)
            r, g, b = colorsys.hsv_to_rgb(hue, sat, val)
            hex_color = "#%02X%02X%02X" % (round(r * 255), round(g * 255), round(b * 255))
    return _lin0(hex_color)


def render(name):
    """Mevsim kancası: istenmeyen ara render'lar atlanır (ör. taç işinde gövde), istenene mevsim
    son işlemi uygulanıp mevsim klasörüne yazılır."""
    target = JOB["names"].get(name)
    if target is None:
        print("atlandı:", name)
        return
    season = JOB["season"]
    if season == "winter" and JOB.get("mat_snow", True):
        low, high = JOB.get("snow_range", (0.32, 0.62))
        for m in list(bpy.data.materials):
            add_snow(m, low, high)
    elif season == "autumn" and JOB.get("vary", 0.0) > 0.0:
        for m in list(bpy.data.materials):
            add_variety(m, JOB["vary"])
    if season == "winter" and JOB.get("caps"):
        add_snow_caps(**JOB["caps"])
    if season == "spring" and JOB.get("pink"):
        tint_masses(**JOB["pink"])
    if season == "spring" and JOB.get("blossoms"):
        add_blossoms(**JOB["blossoms"])
    path = os.path.join(SEASON_DIR, target + ".png")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("yazıldı:", os.path.relpath(path, ROOT))


def _base_socket(m):
    if m.node_tree is None:
        return None, None
    bsdf = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        return None, None
    base = bsdf.inputs["Base Color"]
    src = base.links[0].from_socket if base.links else tuple(base.default_value)[:3]
    return bsdf, src


def add_snow(m, low=0.32, high=0.62, amount=1.0):
    """Normal yönlü yumuşak kar: yukarı bakan yüzeyler beyazlar. Düşük frekanslı gürültü sınırı
    dalgalandırır (cetvel çizgisi değil, yığılmış kar). Bir kez eklenir."""
    if m.get("snowed"):
        return
    bsdf, src = _base_socket(m)
    if bsdf is None:
        return
    m["snowed"] = True
    nodes, links = m.node_tree.nodes, m.node_tree.links
    geo = nodes.new("ShaderNodeNewGeometry")
    sep = nodes.new("ShaderNodeSeparateXYZ")
    links.new(geo.outputs["Normal"], sep.inputs[0])
    texco = nodes.new("ShaderNodeTexCoord")
    noise = nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 3.5
    noise.inputs["Detail"].default_value = 2.0
    links.new(texco.outputs["Object"], noise.inputs["Vector"])
    wob = nodes.new("ShaderNodeMath")
    wob.operation = "MULTIPLY_ADD"
    wob.inputs[1].default_value = 0.35
    wob.inputs[2].default_value = -0.175
    links.new(noise.outputs["Fac"], wob.inputs[0])
    add = nodes.new("ShaderNodeMath")
    add.operation = "ADD"
    links.new(sep.outputs["Z"], add.inputs[0])
    links.new(wob.outputs[0], add.inputs[1])
    ramp = nodes.new("ShaderNodeMapRange")
    ramp.interpolation_type = "SMOOTHSTEP"
    ramp.inputs["From Min"].default_value = low
    ramp.inputs["From Max"].default_value = high
    ramp.inputs["To Max"].default_value = amount
    links.new(add.outputs[0], ramp.inputs["Value"])
    # Kar kendi içinde de hafif gölgeli: yanlara doğru mavimsi, tepede beyaz.
    snow_col = _mix(nodes, links, sep.outputs["Z"], _lin0(SNOW_SHADE), _lin0(SNOW))
    if isinstance(src, tuple):
        mixed = _mix(nodes, links, ramp.outputs["Result"], src, snow_col)
    else:
        mixed = _mix(nodes, links, ramp.outputs["Result"], src, snow_col)
    links.new(mixed, bsdf.inputs["Base Color"])
    if "Sheen Weight" in bsdf.inputs and not bsdf.inputs["Sheen Weight"].links:
        bsdf.inputs["Sheen Weight"].default_value = max(bsdf.inputs["Sheen Weight"].default_value, 0.25)


def add_snow_caps(step, radius, depths, min_nz=0.45, seed=1, squash=0.55, lift=0.35):
    """Kış: yukarıdan aşağı ışın atılır, ilk çarpılan YUKARI bakan yüzeye yumuşak kar topları dizilir;
    hepsi tek bir metaball'da birleşir -> çit ucunda, halatta, taç kütlesinde krema gibi kalın,
    pürüzsüz kar örtüsü (yalnız renk değil, gerçek hacim: silüet de değişir)."""
    rng = random.Random(seed)
    scene = bpy.context.scene
    depsgraph = bpy.context.evaluated_depsgraph_get()
    meshes = [o for o in scene.objects if o.type == "MESH"]
    if not meshes:
        return
    xs = [(o.matrix_world @ Vector(c)).x for o in meshes for c in o.bound_box]
    x0, x1 = min(xs), max(xs)
    balls = []
    x = x0
    while x <= x1:
        for y in depths:
            hit, loc, normal, _i, _o, _m = scene.ray_cast(depsgraph, Vector((x + rng.uniform(-0.3, 0.3) * step, y, 40.0)),
                                                         Vector((0.0, 0.0, -1.0)))
            if hit and normal.z >= min_nz:
                r = rng.uniform(radius[0], radius[1]) * (0.6 + 0.4 * normal.z)
                balls.append((loc.x, loc.y, loc.z + r * lift, r, 1.0, 1.0, squash))
        x += step
    if balls:
        blob(balls, snow_cap_mat(), res=min(radius) * 0.3, smooth=6, name="SnowCap", stiffness=2.0)
    print("kar topu:", len(balls))


def snow_cap_mat():
    return mat("SnowCap", SNOW_SHADE, SNOW, rough=0.5, ao=0.35, ao_dist=0.12, grad=(0.0, 1.0), sheen=0.35,
               spec=0.3)


def tint_masses(material, share, colors, seed=2):
    """İlkbahar: taç kütlelerinin bir kısmı çiçek açmış (pembe) kütleye döner: uzaktan bakınca
    "çiçekli ağaç" okunur, benek değil."""
    rng = random.Random(seed)
    pinks = [mat("Bloom%d" % k, c, top, rough=0.7, ao=0.7, ao_dist=0.5, grad=(0.12, 0.95), noise=0.03,
                 noise_scale=1.4, sheen=0.35, spec=0.3, haze=0.08, haze_color="#FFF0F5")
             for k, (c, top) in enumerate(colors)]
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH" or not obj.material_slots:
            continue
        slot = obj.material_slots[0]
        if slot.material is not None and slot.material.name.startswith(material) and rng.random() < share:
            slot.material = pinks[rng.randrange(len(pinks))]


def add_variety(m, spread):
    """Sonbahar: nesne başına rastgele ton (Object Info > Random): her yaprak kütlesi ayrı bir
    kehribar / mercan / altın tonunda okunur. Yalnız turuncu ailesindeki malzemelere."""
    if m.get("varied"):
        return
    bsdf, src = _base_socket(m)
    if bsdf is None or isinstance(src, tuple):
        return
    m["varied"] = True
    nodes, links = m.node_tree.nodes, m.node_tree.links
    info = nodes.new("ShaderNodeObjectInfo")
    hue = nodes.new("ShaderNodeMapRange")
    hue.inputs["To Min"].default_value = 0.5 - spread
    hue.inputs["To Max"].default_value = 0.5 + spread * 0.6
    links.new(info.outputs["Random"], hue.inputs["Value"])
    hs = nodes.new("ShaderNodeHueSaturation")
    links.new(hue.outputs["Result"], hs.inputs["Hue"])
    links.new(src, hs.inputs["Color"])
    links.new(hs.outputs["Color"], bsdf.inputs["Base Color"])


def add_blossoms(count, radius, colors, seed, front_bias=0.0, centre="#FFE7A0"):
    """İlkbahar: taç yüzeyine kameradan ışın atılarak çiçek kümeleri yerleştirilir (görünen yüzde,
    yukarı/öne bakan yerlerde). Her çiçek 5 tombul taç yaprağı + sarı göbek."""
    rng = random.Random(seed)
    scene = bpy.context.scene
    cam = scene.camera
    depsgraph = bpy.context.evaluated_depsgraph_get()
    view = (cam.matrix_world.to_quaternion() @ Vector((0.0, 0.0, -1.0))).normalized()
    right = (cam.matrix_world.to_quaternion() @ Vector((1.0, 0.0, 0.0))).normalized()
    up = (cam.matrix_world.to_quaternion() @ Vector((0.0, 1.0, 0.0))).normalized()
    half = cam.data.ortho_scale / 2.0
    pmats = [mat("Blossom%d" % k, c, top, rough=0.5, ao=0.25, ao_dist=0.05, sheen=0.4, grad=(0.0, 1.0))
             for k, (c, top) in enumerate(colors)]
    cmat = mat("BlossomEye", centre, rough=0.5, ao=0.2, ao_dist=0.03)
    placed = []
    tries = 0
    while len(placed) < count and tries < count * 60:
        tries += 1
        u, v = rng.uniform(-half, half), rng.uniform(-half, half)
        origin = cam.location + right * u + up * v
        hit, loc, normal, _i, _obj, _m = scene.ray_cast(depsgraph, origin, view)
        if not hit:
            continue
        # Yalnız öne/yukarı bakan yüzeyler: gölgedeki alt yüzlerde çiçek "benek" gibi okunuyordu.
        if normal.z < -0.15 - front_bias or normal.dot(-view) < 0.25:
            continue
        if any((loc - q).length < radius * 2.3 for q in placed):
            continue
        placed.append(loc.copy())
    for loc in placed:
        n_r = radius * rng.uniform(0.8, 1.15)
        pm = pmats[rng.randrange(len(pmats))]
        centre_pt = loc + (-view) * n_r * 0.35
        spin = rng.uniform(0, math.tau)
        for k in range(5):
            a = spin + math.tau * k / 5
            off = right * math.cos(a) * n_r * 0.55 + up * math.sin(a) * n_r * 0.55
            petal = ellipsoid(tuple(centre_pt + off), (n_r * 0.5, n_r * 0.5, n_r * 0.22), pm,
                              segments=24, rings=12)
            petal.rotation_euler = (-view).to_track_quat("Z", "Y").to_euler()
        ellipsoid(tuple(centre_pt + (-view) * n_r * 0.15), (n_r * 0.22, n_r * 0.22, n_r * 0.14), cmat,
                  segments=20, rings=10)
    print("çiçek:", len(placed))


def job(season, names, **extra):
    JOB.clear()
    JOB.update({"season": season, "names": names})
    JOB.update(extra)


def want_group(name):
    return not GROUPS or name in GROUPS or any(g.startswith(name + ":") for g in GROUPS)


# ---------------------------------------------------------------------------- taçlar

CROWN_BLOSSOM = [("#FBD3E0", "#FFF0F5"), ("#F7BCD0", "#FFE4EE"), ("#FFFFFF", "#FFF6FA")]


def crowns():
    plans = [
        ("garden", make_tree, "tree_crown", "Crown"),
        ("beach", beach_palm, "hero_crown", "Frond"),
        ("rooftop", rooftop_tree, "hero_crown", "OliveCrown"),
    ]
    only = {g.split(":")[1] for g in GROUPS if ":" in g}
    for place, builder, crown_name, crown_mat in plans:
        for season in ("autumn", "winter", "spring"):
            if only and place not in only and "%s/%s" % (place, season) not in only:
                continue
            extra = {}
            palm = place == "beach"
            if season == "autumn":
                extra["vary"] = 0.035 if palm else 0.06
            if season == "winter":
                # Taç kütlelerinin her birinin tepesine kalın kar: ışınlar derinlik ızgarasında atılır
                # (yalnız en üst silüete değil, öndeki kütlelerin tepesine de düşsün).
                # Palmiyede tek tek kar topları yaprak uçlarında "mantar" gibi duruyordu: yalnız
                # malzeme karı (yaprakçıkların üst yüzü kırağılı); ağaçlarda hacimli kar örtüsü.
                if not palm:
                    extra["caps"] = {"step": 0.1, "radius": (0.2, 0.28), "min_nz": 0.45, "squash": 0.5,
                                     "depths": tuple(-1.8 + 0.25 * k for k in range(10))}
                extra["snow_range"] = (-0.05, 0.3) if palm else (0.22, 0.52)
            if season == "spring":
                if place == "garden":
                    # Bahçe: kiraz ağacı — kütlelerin çoğu pembe çiçek, arada taze yeşil.
                    extra["pink"] = {"material": crown_mat, "share": 0.62, "seed": 4,
                                     "colors": [("#F4BCCD", "#FFE6EE"), ("#F8CCD9", "#FFF0F5")]}
                    extra["blossoms"] = {"count": 22, "radius": 0.2, "colors": [("#FFFFFF", "#FFF6FA")], "seed": 11}
                elif place == "rooftop":
                    # Çatı: zeytin dalında beyaz-pembe iri çiçek kümeleri (bahçeden ayrışsın).
                    extra["blossoms"] = {"count": 30, "radius": 0.22, "colors": CROWN_BLOSSOM, "seed": 17}
                else:
                    extra["blossoms"] = {"count": 14, "radius": 0.26, "colors": [("#F9A8C0", "#FFD6E2")],
                                         "seed": 11, "front_bias": 0.6}
            job(season, {crown_name: "%s/%s_crown" % (season, place)}, **extra)
            builder()


# ---------------------------------------------------------------------------- kış çitleri

def fences():
    for place, builder in (("garden", make_fence), ("beach", beach_fence), ("rooftop", rooftop_fence)):
        job("winter", {"bg_fence": "winter/%s_fence" % place},
            caps={"step": 0.03, "radius": (0.085, 0.115), "depths": (-0.13, 0.0, 0.14), "min_nz": 0.3, "lift": 0.25},
            # Tuğla/tahta yüzlerine malzeme karı "kırağı çizgisi" gibi kalabalık görünüyordu: yalnız hacimli kar.
            mat_snow=False)
        builder()


# ---------------------------------------------------------------------------- zemin süsleri

def decal_scene(w, h, cz=0.0, tilt=24.0):
    reset()
    light_rig(sun=1.05, sky=0.55, direction=(0.55, 0.6, -0.6))
    camera(w, h, 0.0, cz, tilt)


def snow_mat(name="Snow"):
    return mat(name, SNOW_SHADE, SNOW, rough=0.55, ao=0.55, ao_dist=0.3, grad=(0.1, 0.9), sheen=0.35,
               spec=0.25, noise=0.02, noise_scale=2.0)


def snow_drift(name, w, h, lumps, seed):
    decal_scene(w, h, cz=0.05)
    rng = random.Random(seed)
    span = w / PPU * 0.38
    balls = []
    for k in range(lumps):
        t = (k + 0.5) / lumps
        x = -span + 2 * span * t + rng.uniform(-0.08, 0.08)
        r = (0.32 + 0.18 * math.sin(math.pi * t)) * rng.uniform(0.85, 1.1) * (h / 140.0)
        balls.append((x, rng.uniform(-0.1, 0.1), -r * 0.35, r, 1.25, 1.0, 0.75))
    blob(balls, snow_mat(), res=0.025, smooth=6, name="Drift", stiffness=2.0)
    render(name)


def snowman(name):
    decal_scene(200, 280, cz=0.95, tilt=10.0)
    snow = snow_mat()
    coal = mat("Coal", "#6E6A78", rough=0.4, ao=0.2, ao_dist=0.05, spec=0.4)
    carrot = mat("Carrot", "#F4A15E", "#FFC48A", rough=0.5, ao=0.3, ao_dist=0.05, grad=(0.0, 1.0))
    scarf = mat("Scarf", "#E9858F", "#F7AEB5", rough=0.8, ao=0.4, ao_dist=0.08, sheen=0.5, grad=(0.0, 1.0))
    blob([(0.0, 0.0, 0.32, 0.42, 1.0, 1.0, 0.92)], snow, res=0.02, name="Body")
    blob([(0.0, 0.0, 0.98, 0.31)], snow, res=0.02, name="Belly")
    blob([(0.0, 0.0, 1.5, 0.24)], snow, res=0.02, name="Head")
    for dx in (-0.08, 0.08):
        ellipsoid((dx, -0.21, 1.56), (0.03, 0.02, 0.035), coal, segments=24, rings=12)
    tube([(0.0, -0.22, 1.49, 0.04), (0.03, -0.32, 1.47, 0.025), (0.06, -0.4, 1.45, 0.008)], carrot, res=8)
    for dz in (0.9, 1.08):
        ellipsoid((0.0, -0.2, dz), (0.028, 0.02, 0.028), coal, segments=24, rings=12)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.21, minor_radius=0.065, location=(0.0, 0.0, 1.27),
                                     major_segments=48, minor_segments=16)
    bpy.ops.object.shade_smooth()
    assign(bpy.context.view_layer.objects.active, scarf)
    tube([(0.15, -0.14, 1.25, 0.06), (0.2, -0.2, 1.1, 0.055), (0.22, -0.22, 0.95, 0.05)], scarf, res=8)
    render(name)


def leaf_pile(name, w, h, count, seed):
    decal_scene(w, h, cz=0.08)
    rng = random.Random(seed)
    count *= 2
    tones = [mat("PileLeaf%d" % i, c, t, rough=0.65, ao=0.5, ao_dist=0.12, grad=(0.0, 1.0), sheen=0.2)
             for i, (c, t) in enumerate((("#EE9A58", "#FFC98E"), ("#E8846C", "#FFB8A0"),
                                         ("#EAB255", "#FFDC94"), ("#E39A72", "#FFCDAE")))]
    span = w / PPU * 0.4
    # Altta yumuşak tümsek (yaprak yığınının gövdesi), üstüne yassı yaprak elipsoidleri.
    # Gövde yok: altta düz bir tümsek "turta/tabak" gibi okunuyordu; yığın yalnız üst üste binmiş
    # yapraklardan oluşur (ortada yüksek, kenarda tek tük).
    for k in range(count):
        a = rng.uniform(0, math.tau)
        rr = math.sqrt(rng.uniform(0, 1))
        x = math.cos(a) * rr * span * 0.95
        y = math.sin(a) * rr * 0.32
        z = (1.0 - rr * rr) * span * 0.2 - 0.08 + k * 0.0008
        size = rng.uniform(0.14, 0.2)
        leaf = ellipsoid((x, y, z), (size, size * 0.62, 0.02), tones[rng.randrange(len(tones))],
                         rot=(rng.uniform(-0.7, 0.7), rng.uniform(-0.8, 0.8), rng.uniform(0, math.tau)),
                         segments=24, rings=12)
        for v in leaf.data.vertices:
            v.co.z += 0.4 * v.co.x * v.co.x
    render(name)


def pumpkins(name):
    decal_scene(240, 172, cz=0.25, tilt=16.0)
    rng = random.Random(4)
    body = mat("Pumpkin", "#F2A35E", "#FFC98E", rough=0.5, ao=0.6, ao_dist=0.15, grad=(0.0, 1.0), spec=0.35,
               coat=0.15)
    pale = mat("PumpkinPale", "#F5DDB0", "#FFF1D6", rough=0.5, ao=0.6, ao_dist=0.15, grad=(0.0, 1.0),
               spec=0.35, coat=0.15)
    stem = mat("PumpkinStem", "#A7B57A", "#C9D59A", rough=0.6, ao=0.4, ao_dist=0.05, grad=(0.0, 1.0))
    for cx, r, m in ((-0.36, 0.52, body), (0.5, 0.38, pale)):
        balls = []
        # Dilimler: merkezden uzak, küçük elipsoidler -> aralarında yumuşak oluk (kabak dilimi).
        for k in range(10):
            a = math.tau * k / 10
            balls.append((cx + math.cos(a) * r * 0.62, math.sin(a) * r * 0.62, r * 0.6, r * 0.5,
                          0.8, 0.8, 1.15))
        blob(balls, m, res=0.012, smooth=3, name="Pumpkin", stiffness=2.6)
        tube([(cx, 0.0, r * 1.15, 0.05), (cx + 0.04, 0.0, r * 1.35, 0.04), (cx + 0.1, 0.0, r * 1.42, 0.035)],
             stem, res=8)
    leaf_m = mat("PumpLeaf", "#B8C98A", "#D8E4AE", rough=0.6, ao=0.4, ao_dist=0.05, grad=(0.0, 1.0))
    leaf = ellipsoid((0.05, -0.25, 0.04), (0.2, 0.12, 0.02), leaf_m, rot=(0.0, 0.0, 0.4), segments=32, rings=16)
    for v in leaf.data.vertices:
        v.co.z += 0.3 * v.co.x * v.co.x
    _ = rng
    render(name)


def tulips(name):
    decal_scene(220, 220, cz=0.65, tilt=12.0)
    rng = random.Random(8)
    stem_m = mat("TulipStem", "#8CCB7E", "#B0DE98", rough=0.6, ao=0.3, ao_dist=0.08, grad=(0.0, 1.0))
    leaf_m = mat("TulipLeaf", "#93CF86", "#C1E6A8", rough=0.6, ao=0.35, ao_dist=0.08, grad=(0.0, 1.0))
    petals = [mat("Tulip%d" % i, c, t, rough=0.45, ao=0.35, ao_dist=0.06, sheen=0.4, grad=(0.0, 1.0))
              for i, (c, t) in enumerate((("#F6A3B8", "#FFD3DE"), ("#FFD98A", "#FFF0C2"),
                                          ("#FFFFFF", "#FFF4F7"), ("#F4B6D6", "#FFE0EE")))]
    for k, (x, y, hgt) in enumerate(((-0.55, 0.05, 0.95), (-0.2, -0.1, 1.2), (0.15, 0.08, 1.05),
                                     (0.48, -0.06, 1.15), (0.0, 0.2, 0.85))):
        lean = rng.uniform(-0.08, 0.08)
        tube([(x, y, 0.0, 0.035), (x + lean * 0.5, y, hgt * 0.5, 0.032), (x + lean, y, hgt, 0.03)], stem_m, res=6)
        pm = petals[k % len(petals)]
        for j, a in enumerate((-50, 0, 50, -25, 25)):
            back = j >= 3
            ellipsoid((x + lean + math.sin(math.radians(a)) * 0.11, y + (0.07 if back else -0.04),
                       hgt + 0.2 + (0.03 if back else 0.0)), (0.12, 0.09, 0.24), pm,
                      rot=(0, math.radians(a * 0.45), 0), segments=32, rings=16)
    for side in (-1, 1):
        for x in (-0.4, 0.3):
            leaf = ellipsoid((x + side * 0.12, -0.05, 0.25), (0.08, 0.03, 0.32), leaf_m,
                             rot=(0, math.radians(side * 22), 0), segments=32, rings=16)
            for v in leaf.data.vertices:
                v.co.y += 0.5 * v.co.z * v.co.z
    render(name)


def blossom_bush(name):
    decal_scene(260, 192, cz=0.3, tilt=16.0)
    rng = random.Random(15)
    green = mat("BushGreen", "#9ED793", "#DDF4C0", rough=0.8, ao=0.7, ao_dist=0.3, grad=(0.1, 0.95), sheen=0.2)
    balls = foliage(rng, (0.0, 0.0, 0.32), 0.95, 0.5, 0.5, big=4, small=26, big_r=0.42, small_r=0.2)
    blob(balls, green, res=0.015, smooth=4, name="Bush", stiffness=3.0)
    JOB["season"] = "spring"
    add_blossoms(count=26, radius=0.07, colors=CROWN_BLOSSOM, seed=3)
    JOB["season"] = None
    render(name)


def decals():
    plans = [
        ("winter", "snow_drift_1", lambda n: snow_drift(n, 360, 140, 5, 2)),
        ("winter", "snow_drift_2", lambda n: snow_drift(n, 240, 120, 3, 9)),
        ("winter", "snowman", snowman),
        ("autumn", "leaf_pile_1", lambda n: leaf_pile(n, 320, 140, 70, 5)),
        ("autumn", "leaf_pile_2", lambda n: leaf_pile(n, 220, 112, 36, 13)),
        ("autumn", "pumpkins", pumpkins),
        ("spring", "tulips", tulips),
        ("spring", "blossom_bush", blossom_bush),
    ]
    for season, name, builder in plans:
        # Süsler zaten mevsim renginde modellenir: `lin`/`render` kancaları uygulanmaz.
        job(None, {name: "%s/%s" % (season, name)})
        builder(name)


# ---------------------------------------------------------------------------- efekt + simgeler

def flat_scene(size):
    reset()
    light_rig(sun=0.95, sky=0.8)
    camera(size, size, 0.0, 0.0, 0.0)


def leaf_shape(name, lobed, color, top):
    flat_scene(96)
    m = mat("FxLeaf" + name, color, top, rough=0.6, ao=0.3, ao_dist=0.06, grad=(0.0, 1.0), sheen=0.25)
    vein = mat("FxVein" + name, top, rough=0.6, ao=0.0)
    pts = []
    steps = 60
    # Uç yukarıda, en geniş yer ortanın biraz altında: tombul, yuvarlak hatlı yaprak.
    # "lobed" iken iki yanda yumuşak omuz (akçaağaç esintisi), köşe yok.
    half = []
    for i in range(steps + 1):
        u = i / steps
        w = 0.27 * math.sin(math.pi * (0.06 + 0.9 * u)) ** 0.75 * (1.0 - 0.3 * u)
        if lobed:
            w *= 1.0 + 0.22 * math.exp(-((u - 0.5) / 0.11) ** 2) - 0.1 * math.exp(-((u - 0.68) / 0.06) ** 2)
        half.append((w, -0.36 + 0.74 * u))
    pts = [(x, z) for x, z in half] + [(-x, z) for x, z in reversed(half[1:-1])]
    leaf = slab(pts, 0.05, 0.022, m, name="Leaf")
    for v in leaf.data.vertices:
        v.co.y += 0.35 * v.co.x * v.co.x
    tube([(0.0, -0.06, -0.33, 0.012), (0.0, -0.05, 0.0, 0.009), (0.0, -0.045, 0.3, 0.004)], vein, res=6)
    render(name)


def petal_shape(name):
    flat_scene(64)
    m = mat("FxPetal", "#FFFFFF", "#FFF7FA", rough=0.5, ao=0.25, ao_dist=0.05, grad=(0.0, 1.0), sheen=0.45)
    pts = []
    for i in range(100):
        th = math.tau * i / 100
        # Kiraz yaprağı: yuvarlak gövde, uçta hafif çentik.
        r = 0.27 * (1.0 + 0.25 * math.sin(th)) * (1.0 - 0.1 * max(math.cos(th * 2.0 - math.pi), 0.0) ** 8)
        pts.append((r * math.cos(th) * 0.8, r * math.sin(th)))
    p = slab(pts, 0.04, 0.018, m, name="Petal")
    for v in p.data.vertices:
        v.co.y += 0.6 * v.co.x * v.co.x
    render(name)


def icon_sun(name):
    flat_scene(128)
    disc = mat("IcSun", "#FFC861", "#FFE7A0", rough=0.4, ao=0.2, ao_dist=0.05, grad=(0.0, 1.0), sheen=0.3)
    blob([(0.0, 0.0, 0.0, 0.26, 1.0, 0.5, 1.0)], disc, res=0.01, name="Sun")
    for k in range(8):
        a = math.tau * k / 8
        # Yuvarlak uçlu kapsül ışınlar (düz kesik uç yok).
        ellipsoid((math.cos(a) * 0.42, 0.0, math.sin(a) * 0.42), (0.11, 0.04, 0.045), disc,
                  rot=(0.0, -a, 0.0), segments=32, rings=16)
    render(name)


def icon_snowflake(name):
    flat_scene(128)
    ice = mat("IcIce", "#9CC8EE", "#D4EAFB", rough=0.35, ao=0.2, ao_dist=0.05, grad=(0.0, 1.0), sheen=0.3, coat=0.3)
    for k in range(6):
        a = math.tau * k / 6 + math.pi / 2
        d = Vector((math.cos(a), 0.0, math.sin(a)))
        # Tombul kollar: kalın tüp + her uçta yuvarlak top (keskin uç yok).
        tube([(0.0, 0.0, 0.0, 0.06), tuple(d * 0.24) + (0.055,), tuple(d * 0.44) + (0.05,)], ice, res=10)
        ellipsoid(tuple(d * 0.45), (0.065, 0.06, 0.065), ice, segments=24, rings=12)
        for s_ in (-1, 1):
            b = a + s_ * math.radians(48)
            base = d * 0.27
            tip = base + Vector((math.cos(b), 0.0, math.sin(b))) * 0.13
            tube([tuple(base) + (0.04,), tuple(tip) + (0.038,)], ice, res=10)
            ellipsoid(tuple(tip), (0.045, 0.04, 0.045), ice, segments=24, rings=12)
    ellipsoid((0.0, 0.0, 0.0), (0.09, 0.05, 0.09), ice, segments=32, rings=16)
    render(name)


def icon_blossom(name):
    flat_scene(128)
    pm = mat("IcPetal", "#F7A9C2", "#FFDCE7", rough=0.45, ao=0.25, ao_dist=0.05, grad=(0.0, 1.0), sheen=0.4)
    cm = mat("IcEye", "#FFD36E", "#FFEBA8", rough=0.5, ao=0.2, ao_dist=0.03)
    for k in range(5):
        a = math.tau * k / 5 + math.pi / 2
        petal = ellipsoid((math.cos(a) * 0.24, 0.0, math.sin(a) * 0.24), (0.21, 0.06, 0.17), pm,
                          rot=(0.0, -a, 0.0), segments=32, rings=16)
        _ = petal
    ellipsoid((0.0, -0.05, 0.0), (0.11, 0.06, 0.11), cm, segments=32, rings=16)
    render(name)


def fx():
    job(None, {"leaf_round": "fx/leaf_round", "leaf_lobed": "fx/leaf_lobed", "petal": "fx/petal",
               "icon_summer": "fx/icon_summer", "icon_autumn": "fx/icon_autumn",
               "icon_winter": "fx/icon_winter", "icon_spring": "fx/icon_spring"})
    # Efekt yaprakları açık nötr tonda: oyunda modulate ile turuncu/mercan/altın boyanır.
    leaf_shape("leaf_round", False, "#F3ECE4", "#FFFFFF")
    leaf_shape("leaf_lobed", True, "#F3ECE4", "#FFFFFF")
    petal_shape("petal")
    icon_sun("icon_summer")
    leaf_shape("icon_autumn", True, "#F0A060", "#FFD39A")
    icon_snowflake("icon_winter")
    icon_blossom("icon_spring")


def main_seasons():
    if want_group("crowns"):
        crowns()
    if want_group("fences"):
        fences()
    if want_group("decals"):
        decals()
    if want_group("fx") or want_group("icons"):
        fx()


main_seasons()
