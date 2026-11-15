"""Switchyard — Blender yardımcıları (geometri, UV, malzeme adı, AO pişirme, GLB ihracı).

Koordinat sözleşmesi (Blender): Z yukarı, metre. glTF ihracı Y-yukarıya çevirir:
    Godot (x, y, z) = Blender (x, z, -y)
Yani Blender'da -Y yönü Godot'da +Z (kameraya doğru) olur.

Malzemeler yalnız ADLA taşınır: GLB içindeki malzeme adı `assets/materials/<ad>.tres`
dosyasıyla eşleşir; Godot içe aktarma betiği (`assets/models/sy_post_import.gd`)
yüzeyleri bu .tres dosyalarıyla değiştirir. Böylece doku tek kopya, malzeme ortaktır.
"""

import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import sy_mats  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
MODELS = os.path.join(ROOT, "assets", "models")


# ---------------------------------------------------------------- sahne

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _MAT_CACHE.clear()


def collection(name):
    col = bpy.data.collections.get(name)
    if col is None:
        col = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(col)
    return col


def link(obj, col=None):
    (col or bpy.context.scene.collection).objects.link(obj)
    return obj


def empty(name, loc=(0, 0, 0), rot=(0, 0, 0), parent=None, size=0.05):
    e = bpy.data.objects.new(name, None)
    e.empty_display_type = "ARROWS"
    e.empty_display_size = size
    e.location = loc
    e.rotation_euler = rot
    link(e)
    if parent is not None:
        e.parent = parent
    return e


# ---------------------------------------------------------------- malzeme

_MAT_CACHE = {}


def mat(name):
    """Adlı malzeme (önizleme rengiyle). Ad sy_mats.MATERIALS ya da VC_GROUPS içinde olmalı."""
    if name in _MAT_CACHE:
        return _MAT_CACHE[name]
    spec = sy_mats.MATERIALS.get(name) or sy_mats.VC_GROUPS.get(name)
    if spec is None:
        raise KeyError(f"tanımsız malzeme: {name}")
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    if bsdf is not None:
        c = sy_mats.preview_color(spec)
        bsdf.inputs["Base Color"].default_value = (c[0], c[1], c[2], 1.0)
        bsdf.inputs["Roughness"].default_value = spec.get("rough", 0.5)
        bsdf.inputs["Metallic"].default_value = spec.get("metal", 0.0)
    _MAT_CACHE[name] = m
    return m


def set_mat(obj, name):
    obj.data.materials.clear()
    obj.data.materials.append(mat(name))
    return obj


# ---------------------------------------------------------------- mesh yardımcıları

def obj_from_bm(name, bm, material=None, col=None):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    link(ob, col)
    if material:
        set_mat(ob, material)
    return ob


def activate(obj):
    bpy.context.view_layer.update()
    for o in list(bpy.context.view_layer.objects):
        if o is not None:
            o.select_set(False)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)


def apply_mods(obj):
    activate(obj)
    for m in list(obj.modifiers):
        with bpy.context.temp_override(object=obj, active_object=obj):
            bpy.ops.object.modifier_apply(modifier=m.name)


def smooth(obj, angle=35.0, weighted=True):
    """Pürüzsüz gölgeleme + açıya göre keskin kenar + ağırlıklı normaller."""
    me = obj.data
    for p in me.polygons:
        p.use_smooth = True
    try:
        me.set_sharp_from_angle(angle=math.radians(angle))
    except AttributeError:
        pass
    if weighted:
        wn = obj.modifiers.new("wn", "WEIGHTED_NORMAL")
        wn.keep_sharp = True
        wn.weight = 50
        wn.mode = "FACE_AREA"
        apply_mods(obj)
    return obj


def bevel(obj, width, segments=3, angle=40.0, profile=0.5, harden=False):
    if width <= 0:
        return obj
    b = obj.modifiers.new("bevel", "BEVEL")
    b.width = width
    b.segments = segments
    b.limit_method = "ANGLE"
    b.angle_limit = math.radians(angle)
    b.profile = profile
    b.harden_normals = harden
    b.use_clamp_overlap = True
    apply_mods(obj)
    return obj


def subsurf(obj, levels=1):
    s = obj.modifiers.new("sub", "SUBSURF")
    s.levels = levels
    s.render_levels = levels
    apply_mods(obj)
    return obj


def box_uv(obj, scale=1.0, grain=None):
    """Dünya ölçekli kutu izdüşümü UV (1 UV birimi = `scale` metre).
    grain: 'X'|'Y'|'Z' — ahşap lifi (dokunun v ekseni) bu dünya eksenine hizalanır."""
    me = obj.data
    mw = obj.matrix_world
    if not me.uv_layers:
        me.uv_layers.new(name="UVMap")
    uv = me.uv_layers.active.data
    if grain is None:
        dims = obj.dimensions
        grain = "XYZ"[max(range(3), key=lambda i: dims[i])]
    gi = "XYZ".index(grain)
    rot = mw.to_3x3()
    for p in me.polygons:
        n = rot @ p.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        others = [i for i in range(3) if i != ax]
        if gi in others:
            vi = gi
            ui = others[0] if others[1] == gi else others[1]
        else:
            ui, vi = others
        for li in p.loop_indices:
            co = mw @ me.vertices[me.loops[li].vertex_index].co
            uv[li].uv = (co[ui] / scale, co[vi] / scale)
    return obj


def finish(obj, material, bev=0.0, seg=3, angle=35.0, sub=0, uv_scale=1.0, grain=None, weighted=True,
           bev_angle=40.0):
    if material:
        set_mat(obj, material)
    if bev > 0:
        bevel(obj, bev, seg, angle=bev_angle)
    if sub:
        subsurf(obj, sub)
    smooth(obj, angle, weighted=weighted and sub == 0)
    if uv_scale:
        box_uv(obj, uv_scale, grain)
    return obj


def box(name, size, loc, material, bev=0.006, seg=3, sub=0, uv_scale=1.0, grain=None, rot=(0, 0, 0), col=None,
        angle=35.0, bev_angle=40.0, cuts=0):
    """Pahlı kutu. size=(x,y,z) tam boyut, loc = merkez."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    if cuts:
        bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=cuts, use_grid_fill=True)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    ob = obj_from_bm(name, bm, col=col)
    ob.location = loc
    ob.rotation_euler = rot
    bpy.context.view_layer.update()
    return finish(ob, material, bev, seg, angle, sub, uv_scale, grain, bev_angle=bev_angle)


def cyl(name, r, h, loc, material, verts=32, bev=0.003, seg=2, axis="Z", uv_scale=1.0, col=None, r2=None,
        caps=True, angle=35.0):
    """Silindir/koni (taban merkezi loc, eksen boyunca h)."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=caps, segments=verts, radius1=r, radius2=r if r2 is None else r2, depth=h)
    bmesh.ops.translate(bm, vec=Vector((0, 0, h / 2)), verts=bm.verts)
    if axis == "X":
        bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(90), 3, "Y"), verts=bm.verts)
    elif axis == "Y":
        bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(-90), 3, "X"), verts=bm.verts)
    ob = obj_from_bm(name, bm, col=col)
    ob.location = loc
    bpy.context.view_layer.update()
    return finish(ob, material, bev, seg, angle, 0, uv_scale)


def lathe(name, profile, loc, material, verts=48, axis="Z", uv_scale=None, col=None, angle=40.0, sub=0,
          rot=(0, 0, 0), close_top=True, close_bottom=True):
    """Döndürme gövdesi. profile: [(r, z), ...] alttan üste. r=0 uçlar kapatılır.
    UV: u = açı (0..1), v = profil yay uzunluğu (metre / uv_scale)."""
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    rings = []
    for r, z in profile:
        ring = []
        if r <= 1e-6:
            ring = [bm.verts.new((0, 0, z))] * verts
        else:
            for i in range(verts):
                a = 2 * math.pi * i / verts
                ring.append(bm.verts.new((r * math.cos(a), r * math.sin(a), z)))
        rings.append(ring)
    arc = [0.0]
    for i in range(1, len(profile)):
        (r0, z0), (r1, z1) = profile[i - 1], profile[i]
        arc.append(arc[-1] + math.hypot(r1 - r0, z1 - z0))
    sc = uv_scale or max(arc[-1], 1e-6)
    for k in range(len(rings) - 1):
        a, b = rings[k], rings[k + 1]
        for i in range(verts):
            j = (i + 1) % verts
            vs = [a[i], a[j], b[j], b[i]]
            uvs = [(i / verts, arc[k] / sc), ((i + 1) / verts, arc[k] / sc), ((i + 1) / verts, arc[k + 1] / sc),
                   (i / verts, arc[k + 1] / sc)]
            uniq = []
            uu = []
            for v, t in zip(vs, uvs):
                if v not in uniq:
                    uniq.append(v)
                    uu.append(t)
            if len(uniq) < 3:
                continue
            try:
                f = bm.faces.new(uniq)
            except ValueError:
                continue
            for loop, t in zip(f.loops, uu):
                loop[uvl].uv = t
    if close_bottom and profile[0][0] > 1e-6:
        f = bm.faces.new(list(reversed(rings[0])))
        for loop in f.loops:
            loop[uvl].uv = (loop.vert.co.x / 0.2 + 0.5, loop.vert.co.y / 0.2 + 0.5)
    if close_top and profile[-1][0] > 1e-6:
        f = bm.faces.new(rings[-1])
        for loop in f.loops:
            loop[uvl].uv = (loop.vert.co.x / 0.2 + 0.5, loop.vert.co.y / 0.2 + 0.5)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if axis == "X":
        bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(90), 3, "Y"), verts=bm.verts)
    elif axis == "Y":
        bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(-90), 3, "X"), verts=bm.verts)
    ob = obj_from_bm(name, bm, material, col)
    ob.location = loc
    ob.rotation_euler = rot
    if sub:
        subsurf(ob, sub)
    smooth(ob, angle, weighted=False)
    return ob


def fillet_path(points, radius, steps=6):
    """Köşeleri yay ile yuvarlatılmış çoklu çizgi."""
    pts = [Vector(p) for p in points]
    if len(pts) < 3 or radius <= 0:
        return pts
    out = [pts[0]]
    for i in range(1, len(pts) - 1):
        p0, p1, p2 = pts[i - 1], pts[i], pts[i + 1]
        d0 = (p0 - p1)
        d2 = (p2 - p1)
        l0, l2 = d0.length, d2.length
        if l0 < 1e-6 or l2 < 1e-6:
            continue
        d0.normalize()
        d2.normalize()
        r = min(radius, l0 * 0.45, l2 * 0.45)
        a = p1 + d0 * r
        b = p1 + d2 * r
        for s in range(steps + 1):
            t = s / steps
            # Kuadratik Bezier (a -> p1 -> b) — yumuşak köşe.
            q = a * (1 - t) * (1 - t) + p1 * 2 * t * (1 - t) + b * t * t
            out.append(q)
    out.append(pts[-1])
    return out


def resample(points, step):
    pts = [Vector(p) for p in points]
    out = [pts[0]]
    acc = 0.0
    for i in range(1, len(pts)):
        a, b = pts[i - 1], pts[i]
        seg = (b - a).length
        if seg < 1e-9:
            continue
        n = max(1, int(math.ceil(seg / step)))
        for k in range(1, n + 1):
            out.append(a.lerp(b, k / n))
    return out


def sweep(name, points, radius, material, sides=12, closed=False, caps=True, col=None, uv_len=1.0,
          radius_fn=None):
    """Yol boyunca tüp (paralel taşıma çerçeveleri). points: Vector listesi.
    radius_fn(t) varsa yarıçap çarpanı (t: 0..1 yol boyunca)."""
    pts = [Vector(p) for p in points]
    n = len(pts)
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    tangents = []
    for i in range(n):
        if closed:
            t = pts[(i + 1) % n] - pts[i - 1]
        else:
            t = pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]
        tangents.append(t.normalized())
    up = Vector((0, 0, 1)) if abs(tangents[0].z) < 0.9 else Vector((1, 0, 0))
    normal = tangents[0].cross(up).normalized()
    frames = []
    for i in range(n):
        if i > 0:
            axis = tangents[i - 1].cross(tangents[i])
            if axis.length > 1e-8:
                ang = tangents[i - 1].angle(tangents[i])
                normal = Matrix.Rotation(ang, 3, axis.normalized()) @ normal
        binormal = tangents[i].cross(normal).normalized()
        frames.append((normal.copy(), binormal))
    lengths = [0.0]
    for i in range(1, n):
        lengths.append(lengths[-1] + (pts[i] - pts[i - 1]).length)
    total = max(lengths[-1], 1e-6)
    rings = []
    for i in range(n):
        nr, bn = frames[i]
        rr = radius * (radius_fn(lengths[i] / total) if radius_fn else 1.0)
        ring = []
        for s in range(sides):
            a = 2 * math.pi * s / sides
            ring.append(bm.verts.new(pts[i] + (nr * math.cos(a) + bn * math.sin(a)) * rr))
        rings.append(ring)
    segs = n if closed else n - 1
    for i in range(segs):
        a, b = rings[i], rings[(i + 1) % n]
        for s in range(sides):
            s2 = (s + 1) % sides
            f = bm.faces.new([a[s], a[s2], b[s2], b[s]])
            v0 = lengths[i] / uv_len
            v1 = (lengths[i + 1] if i + 1 < n else total) / uv_len
            for loop, t in zip(f.loops, [(s / sides, v0), ((s + 1) / sides, v0), ((s + 1) / sides, v1), (s / sides, v1)]):
                loop[uvl].uv = t
    if caps and not closed:
        for ring, rev in ((rings[0], True), (rings[-1], False)):
            c = sum((v.co for v in ring), Vector()) / len(ring)
            cv = bm.verts.new(c)
            for s in range(sides):
                s2 = (s + 1) % sides
                vs = [ring[s], ring[s2], cv]
                if rev:
                    vs.reverse()
                f = bm.faces.new(vs)
                for loop in f.loops:
                    loop[uvl].uv = (0.5, 0.0)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = obj_from_bm(name, bm, material, col)
    smooth(ob, 60.0, weighted=False)
    return ob


def grid_plane(name, x0, x1, y0, y1, z, step, material, holes=(), col=None, uv_scale=1.0, flip=False):
    """Yatay ızgara düzlem (AO köşe pişirmesi için yoğun). holes: [(x0,x1,y0,y1)]."""
    bm = bmesh.new()
    nx = max(1, int(round((x1 - x0) / step)))
    ny = max(1, int(round((y1 - y0) / step)))
    verts = {}

    def v(i, j):
        key = (i, j)
        if key not in verts:
            verts[key] = bm.verts.new((x0 + (x1 - x0) * i / nx, y0 + (y1 - y0) * j / ny, z))
        return verts[key]

    for i in range(nx):
        for j in range(ny):
            cx = x0 + (x1 - x0) * (i + 0.5) / nx
            cy = y0 + (y1 - y0) * (j + 0.5) / ny
            if any(h[0] < cx < h[1] and h[2] < cy < h[3] for h in holes):
                continue
            q = [v(i, j), v(i + 1, j), v(i + 1, j + 1), v(i, j + 1)]
            if flip:
                q.reverse()
            bm.faces.new(q)
    ob = obj_from_bm(name, bm, material, col)
    for p in ob.data.polygons:
        p.use_smooth = True
    box_uv(ob, uv_scale)
    return ob


def wall_grid(name, origin, u_dir, length, height, step, material, holes=(), normal_sign=1, col=None,
              uv_scale=1.0):
    """Dikey duvar yüzü ızgarası. origin: alt köşe, u_dir: duvar boyunca birim vektör.
    holes: [(u0,u1,z0,z1)] açıklıklar. normal_sign: yüzün baktığı yön (u x Z yönüne göre)."""
    bm = bmesh.new()
    o = Vector(origin)
    u = Vector(u_dir).normalized()
    nu = max(1, int(round(length / step)))
    nz = max(1, int(round(height / step)))
    # Açıklık kenarlarını ızgaraya ekle (tam hizalı kesim için)
    us = sorted(set([length * i / nu for i in range(nu + 1)] + [h[0] for h in holes] + [h[1] for h in holes]))
    zs = sorted(set([height * i / nz for i in range(nz + 1)] + [h[2] for h in holes] + [h[3] for h in holes]))
    us = [x for x in us if 0 <= x <= length]
    zs = [x for x in zs if 0 <= x <= height]
    verts = {}

    def v(i, j):
        key = (i, j)
        if key not in verts:
            verts[key] = bm.verts.new(o + u * us[i] + Vector((0, 0, zs[j])))
        return verts[key]

    for i in range(len(us) - 1):
        for j in range(len(zs) - 1):
            cu = (us[i] + us[i + 1]) / 2
            cz = (zs[j] + zs[j + 1]) / 2
            if any(h[0] < cu < h[1] and h[2] < cz < h[3] for h in holes):
                continue
            q = [v(i, j), v(i + 1, j), v(i + 1, j + 1), v(i, j + 1)]
            if normal_sign < 0:
                q.reverse()
            bm.faces.new(q)
    ob = obj_from_bm(name, bm, material, col)
    for p in ob.data.polygons:
        p.use_smooth = True
    box_uv(ob, uv_scale, grain="Z")
    return ob


def join(objs, name):
    objs = [o for o in objs if o is not None]
    if not objs:
        return None
    activate(objs[0])
    for o in objs[1:]:
        o.select_set(True)
    with bpy.context.temp_override(active_object=objs[0], selected_editable_objects=objs, object=objs[0]):
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = name
    ob.data.name = name
    return ob


def apply_transform(obj):
    activate(obj)
    with bpy.context.temp_override(active_object=obj, selected_editable_objects=[obj], object=obj):
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def set_origin(obj, point):
    """Nesnenin orijinini dünya noktasına taşır (geometri yerinde kalır)."""
    p = Vector(point)
    mw = obj.matrix_world.copy()
    local = mw.inverted() @ p
    obj.data.transform(Matrix.Translation(-local))
    obj.matrix_world = mw @ Matrix.Translation(local)


def gv(v):
    """Godot/glTF V'sini Blender V'sine çevirir (glTF ihracı V'yi ters çevirir: v_godot = 1 - v_blender).
    El ile UV yazılırken "Godot'da UV.y=0 üst" düşünülür ve bu fonksiyondan geçirilir."""
    return 1.0 - v


def tri_count(objs=None):
    total = 0
    for o in objs or bpy.context.scene.objects:
        if o.type == "MESH":
            for p in o.data.polygons:
                total += len(p.vertices) - 2
    return total


# ---------------------------------------------------------------- AO pişirme

def bake_vertex_ao(objs, samples=96, distance=0.35, strength=0.75, gamma=1.0):
    """Cycles ile köşe rengine ortam örtmesi pişirir; renk = karışım(1, ao, strength).
    Malzemeler Godot'da köşe rengini albedo çarpanı olarak kullanır."""
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    if scene.world is None:
        scene.world = bpy.data.worlds.new("World")
    scene.world.light_settings.distance = distance
    meshes = [o for o in objs if o.type == "MESH"]
    for o in meshes:
        me = o.data
        for a in list(me.color_attributes):
            me.color_attributes.remove(a)
        attr = me.color_attributes.new("Color", "BYTE_COLOR", "CORNER")
        me.color_attributes.active_color = attr
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    with bpy.context.temp_override(active_object=meshes[0], selected_objects=meshes):
        bpy.ops.object.bake(type="AO", target="VERTEX_COLORS", use_clear=True)
    for o in meshes:
        attr = o.data.color_attributes.active_color
        vals = [0.0] * (len(attr.data) * 4)
        attr.data.foreach_get("color", vals)
        for i in range(0, len(vals), 4):
            ao = vals[i]
            ao = ao ** gamma
            k = 1.0 - strength * (1.0 - ao)
            vals[i] = vals[i + 1] = vals[i + 2] = k
            vals[i + 3] = 1.0
        attr.data.foreach_set("color", vals)


def _srgb_to_lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def collapse_materials(objs):
    """Yalnız rengi farklı malzemeleri ortak "vc_*" malzemelerine toplar: yüzün rengi (doğrusal)
    köşe rengine (AO ile çarpılarak) yazılır, yuva ortak malzemeye bağlanır, yinelenen yuvalar birleşir."""
    for o in objs:
        if o.type != "MESH" or not o.data.materials:
            continue
        me = o.data
        names = [m.name if m else "" for m in me.materials]
        if not any(n in sy_mats.GROUP_OF for n in names):
            continue
        if not me.color_attributes:
            ensure_white_vcol([o])
        attr = me.color_attributes.active_color or me.color_attributes[0]
        vals = [0.0] * (len(attr.data) * 4)
        attr.data.foreach_get("color", vals)
        tints = []
        for n in names:
            if n in sy_mats.GROUP_OF:
                spec = sy_mats.MATERIALS[n]
                h = spec.get("albedo", "#ffffff").lstrip("#")
                tints.append(tuple(_srgb_to_lin(int(h[i:i + 2], 16) / 255.0) for i in (0, 2, 4)))
            else:
                tints.append(None)
        if attr.domain == "CORNER":
            for p in me.polygons:
                t = tints[p.material_index] if p.material_index < len(tints) else None
                if t is None:
                    continue
                for li in p.loop_indices:
                    k = li * 4
                    vals[k] *= t[0]
                    vals[k + 1] *= t[1]
                    vals[k + 2] *= t[2]
        attr.data.foreach_set("color", vals)
        # Yuvaları ortak malzemeye bağla, aynı malzemeli yuvaları birleştir
        new_names = [sy_mats.GROUP_OF.get(n, n) for n in names]
        uniq = []
        for n in new_names:
            if n not in uniq:
                uniq.append(n)
        remap = [uniq.index(n) for n in new_names]
        idx = [0] * len(me.polygons)
        me.polygons.foreach_get("material_index", idx)
        idx = [remap[i] if i < len(remap) else 0 for i in idx]
        # Not: materials.clear() yüz indekslerini sıfırlar; indeksler yuvalar yazıldıktan SONRA atanır.
        me.materials.clear()
        for n in uniq:
            me.materials.append(mat(n))
        me.polygons.foreach_set("material_index", idx)
        me.update()


def id_colors(obj, fn):
    """Kimlik kodlaması için kayıpsız (FLOAT) köşe rengi: fn(polygon) -> (r, g, b)."""
    me = obj.data
    for a in list(me.color_attributes):
        me.color_attributes.remove(a)
    attr = me.color_attributes.new("Color", "FLOAT_COLOR", "CORNER")
    me.color_attributes.active_color = attr
    vals = [1.0] * (len(attr.data) * 4)
    for p in me.polygons:
        c = fn(p)
        for li in p.loop_indices:
            vals[li * 4:li * 4 + 3] = c
    attr.data.foreach_set("color", vals)


def ensure_white_vcol(objs):
    for o in objs:
        if o.type != "MESH":
            continue
        me = o.data
        if me.color_attributes:
            continue
        attr = me.color_attributes.new("Color", "BYTE_COLOR", "CORNER")
        vals = [1.0] * (len(attr.data) * 4)
        attr.data.foreach_set("color", vals)
        me.color_attributes.active_color = attr


# ---------------------------------------------------------------- ihracat

def export_glb(path, objects=None):
    """Seçili (ya da tüm) nesneleri GLB olarak yazar. Malzemeler yalnız ad + önizleme rengi."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    use_sel = objects is not None
    if use_sel:
        for o in objects:
            o.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=use_sel,
        export_yup=True,
        export_apply=True,
        export_normals=True,
        export_texcoords=True,
        export_tangents=False,
        export_materials="EXPORT",
        export_image_format="NONE",
        export_vertex_color="ACTIVE",
        export_all_vertex_colors=False,
        export_extras=True,
        export_animations=False,
    )
    size = os.path.getsize(path)
    print(f"  GLB: {os.path.relpath(path, ROOT)}  {size / 1024:.0f} KB")


# ================================================================ Switchyard ekleri

def arc_fillet(points, radius, steps=8, closed=True):
    """Çokgen köşelerini gerçek daire yaylarıyla yuvarlar (2B, [(x, y)]). Kapalı çokgen varsayılır."""
    pts = [Vector((p[0], p[1], 0.0)) for p in points]
    n = len(pts)
    out = []
    rng = range(n) if closed else range(1, n - 1)
    if not closed:
        out.append(pts[0])
    for i in rng:
        p0, p1, p2 = pts[i - 1], pts[i], pts[(i + 1) % n]
        d0 = (p0 - p1)
        d2 = (p2 - p1)
        l0, l2 = d0.length, d2.length
        d0.normalize()
        d2.normalize()
        cosang = max(-1.0, min(1.0, d0.dot(d2)))
        ang = math.acos(cosang)
        if ang < 1e-3 or ang > math.pi - 1e-3:
            out.append(p1)
            continue
        r = radius
        t = r / math.tan(ang / 2.0)
        t = min(t, l0 * 0.49, l2 * 0.49)
        r = t * math.tan(ang / 2.0)
        a = p1 + d0 * t
        b = p1 + d2 * t
        bis = (d0 + d2).normalized()
        c = p1 + bis * (r / math.sin(ang / 2.0))
        va = a - c
        vb = b - c
        cross = va.x * vb.y - va.y * vb.x
        total = math.atan2(cross, va.dot(vb))
        for s in range(steps + 1):
            q = Matrix.Rotation(total * s / steps, 3, "Z") @ va
            out.append(c + q)
    if not closed:
        out.append(pts[-1])
    return [(p.x, p.y) for p in out]


def symbol_outline(kind, size=1.0, steps=6):
    """Simge dış hatları (birim boy ~ size), saat yönünün tersine, köşeler yumuşatılmış.
    Şekiller küçükken de ayrışacak biçimde seçildi: daire, üçgen, kare, elmas, yıldız, artı; lokomotif."""
    s = size * 0.5
    if kind == "circle":
        n = 64
        return [(s * 0.92 * math.cos(2 * math.pi * i / n), s * 0.92 * math.sin(2 * math.pi * i / n)) for i in range(n)]
    if kind == "triangle":
        r = s * 1.08
        pts = [(r * math.cos(math.radians(90 + 120 * i)), r * math.sin(math.radians(90 + 120 * i)) - s * 0.14)
               for i in range(3)]
        return arc_fillet(pts, s * 0.16, steps * 2)
    if kind == "square":
        q = s * 0.80
        return arc_fillet([(-q, -q), (q, -q), (q, q), (-q, q)], s * 0.18, steps * 2)
    if kind == "diamond":
        q = s * 1.02
        return arc_fillet([(0, -q), (q * 0.86, 0), (0, q), (-q * 0.86, 0)], s * 0.14, steps * 2)
    if kind == "star":
        pts = []
        for i in range(10):
            r = s * (1.04 if i % 2 == 0 else 0.46)
            a = math.radians(90 + 36 * i)
            pts.append((r * math.cos(a), r * math.sin(a) - s * 0.04))
        return arc_fillet(pts, s * 0.07, steps)
    if kind == "cross":
        a = s * 0.92
        b = s * 0.31
        pts = [(-b, -a), (b, -a), (b, -b), (a, -b), (a, b), (b, b), (b, a), (-b, a), (-b, b), (-a, b), (-a, -b),
               (-b, -b)]
        return arc_fillet(pts, s * 0.12, steps)
    if kind == "loco":
        # Önü +y'ye bakan sade lokomotif silueti: uzun burun + kabin, sivri burun yok (yön okunur).
        w = s * 0.62
        pts = [(-w, -s), (w, -s), (w, s * 0.10), (w * 0.62, s * 0.10), (w * 0.62, s * 0.95), (-w * 0.62, s * 0.95),
               (-w * 0.62, s * 0.10), (-w, s * 0.10)]
        return arc_fillet(pts, s * 0.12, steps)
    raise KeyError(kind)


def extrude_shape(name, outline, depth, material, bev=0.0, bev_seg=3, z0=0.0, col=None, smooth_angle=40.0):
    """2B dış hattı (Blender XY) Z boyunca `depth` kadar kalınlaştırır; tabanı z0'da. Pahlı, pürüzsüz."""
    bm = bmesh.new()
    bot = [bm.verts.new((x, y, z0)) for x, y in outline]
    top = [bm.verts.new((x, y, z0 + depth)) for x, y in outline]
    bm.faces.new(list(reversed(bot)))
    bm.faces.new(top)
    n = len(outline)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new([bot[i], bot[j], top[j], top[i]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = obj_from_bm(name, bm, material, col)
    if bev > 0:
        b = ob.modifiers.new("bevel", "BEVEL")
        b.width = bev
        b.segments = bev_seg
        b.limit_method = "ANGLE"
        b.angle_limit = math.radians(50)
        b.use_clamp_overlap = True
        apply_mods(ob)
    # Kapaklar n-gen: üçgenlemeyi burada yap ki pişirme/ihracat aynı topolojiyi görsün.
    tri = ob.modifiers.new("tri", "TRIANGULATE")
    tri.quad_method = "BEAUTY"
    tri.ngon_method = "BEAUTY"
    apply_mods(ob)
    smooth(ob, smooth_angle, weighted=True)
    return ob


def profile_sweep(name, path, profile, material, closed_profile=True, up=(0, 0, 1), col=None, caps=True,
                  smooth_angle=50.0):
    """Keyfi 2B profili (yan x, yukarı y) 3B yol boyunca süpürür. Yol yatay düzlemde olmalı (rayların, korkulukların).
    profile: [(x, y)] saat yönünün tersine. Dönüş: nesne."""
    pts = [Vector(p) for p in path]
    n = len(pts)
    upv = Vector(up)
    bm = bmesh.new()
    rings = []
    for i in range(n):
        t = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        side = t.cross(upv).normalized()
        u2 = side.cross(t).normalized()
        rings.append([bm.verts.new(pts[i] + side * px + u2 * py) for px, py in profile])
    m = len(profile)
    segs = m if closed_profile else m - 1
    for i in range(n - 1):
        a, b = rings[i], rings[i + 1]
        for k in range(segs):
            k2 = (k + 1) % m
            bm.faces.new([a[k], a[k2], b[k2], b[k]])
    if caps and closed_profile:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = obj_from_bm(name, bm, material, col)
    tri = ob.modifiers.new("tri", "TRIANGULATE")
    apply_mods(ob)
    smooth(ob, smooth_angle, weighted=False)
    return ob


def rounded_rect(w, h, r, steps=6):
    """Merkezli yuvarlak köşeli dikdörtgen dış hattı."""
    x, y = w / 2.0, h / 2.0
    return arc_fillet([(-x, -y), (x, -y), (x, y), (-x, y)], r, steps)


def tube(name, points, radius, material, sides=10, col=None):
    """Kısa yol: köşeleri yuvarlatılmış tutamak/korkuluk tüpü."""
    return sweep(name, points, radius, material, sides=sides, col=col)


def mark_shadow(obj, mode):
    """İçe aktarmada gölge davranışı: ad son eki '_noshadow' / '_shadowonly'."""
    obj.name = obj.name + "_" + mode
    return obj


def vertex_count_tris(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)
