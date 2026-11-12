#!/usr/bin/env python3
"""Sonsuz mod parça (segment) sahnelerini desk_01.tscn'den türetir.

Neden: tuzak düğümleri/alt kaynakları (şekil, mesh, betik) desk_01'de kanıtlanmış hâlde var;
elle kopyalamak yerine bu araç ilgili düğümleri bağımlılıklarıyla çıkarıp yeni sahneye koyar.
desk_01'de olmayan masa eşyaları (kalemlik, kulaklık, defter, yapışkan not, kitap yığını) için
YENİ düğüm blokları üretir (StaticBody3D + çarpışma + GLB görsel); boyutlar gerçek model
AABB'lerinden gelir (docs/art/models_v2/env/manifest.json dims alanının Godot izdüşümü).
Kullanım:  python3 tools/segment_tools.py   (scenes/segments/*.tscn, endless_desk.tscn, data/segments.json)
Parça sözleşmesi: kök `Segment` (scripts/gameplay/segment.gd), yerel -Z yönünde 0..length; zemin dahil.
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "scenes/levels/desk_01.tscn"
SEGMENT_LENGTH = 12.0
FLOOR_OVERLAP = 0.04   # komşu zemin kutuları arasında çatlak kalmasın

HEADER = re.compile(r'^\[(\w+)\s*(.*)\]\s*$')

# Yeni masa eşyası sözleşmesi (desk_01'de yok). Boyutlar gerçek GLB AABB'sinden ölçüldü
# (Blender dims [x=genişlik, z=yükseklik, y=derinlik] -> Godot (x, y, z) = (genişlik, yükseklik, derinlik)).
# Çarpışma şekli modelin tabanında oturur (origin alt-merkez: min y = 0).
PROP_SPECS = {
    "pen_cup":      dict(glb="res://assets/models/v2/env/prop_pen_cup_v2.glb",
                         shape="cylinder", radius=0.55, height=2.58),
    "headphones":   dict(glb="res://assets/models/v2/env/prop_headphones_v2.glb",
                         shape="box", size=(1.88, 1.88, 1.82)),
    "notebook":     dict(glb="res://assets/models/v2/env/prop_notebook_v2.glb",
                         shape="box", size=(3.48, 0.24, 4.5)),
    "sticky_notes": dict(glb="res://assets/models/v2/env/prop_sticky_notes_v2.glb",
                         shape="box", size=(1.13, 0.05, 1.1)),
    "book_stack":   dict(glb="res://assets/models/v2/env/prop_book_stack_v2.glb",
                         shape="box", size=(2.45, 2.2, 4.49)),
}


class Block:
    def __init__(self, kind, attrs_text, lines):
        self.kind, self.attrs_text, self.lines = kind, attrs_text, lines
        m = re.search(r'\bid="([^"]+)"', attrs_text)
        self.id = m.group(1) if m else None
        m = re.search(r'\bname="([^"]+)"', attrs_text)
        self.name = m.group(1) if m else None
        m = re.search(r'\bparent="([^"]*)"', attrs_text)
        self.parent = m.group(1) if m else None

    def text(self):
        return "[%s %s]\n%s" % (self.kind, self.attrs_text, "\n".join(self.lines)) if self.lines else "[%s %s]" % (self.kind, self.attrs_text)

    def refs(self):
        body = self.attrs_text + "\n" + "\n".join(self.lines)
        return (set(re.findall(r'ExtResource\("([^"]+)"\)', body)),
                set(re.findall(r'SubResource\("([^"]+)"\)', body)))


def parse(path):
    blocks, cur = [], None
    for line in path.read_text().split("\n"):
        m = HEADER.match(line.strip()) if line.startswith("[") else None
        if m:
            cur = Block(m.group(1), m.group(2).strip(), [])
            blocks.append(cur)
        elif cur is not None:
            cur.lines.append(line)
    for b in blocks:
        while b.lines and b.lines[-1] == "":
            b.lines.pop()
    return blocks


class Source:
    def __init__(self, path):
        self.blocks = parse(path)
        self.ext = {b.id: b for b in self.blocks if b.kind == "ext_resource"}
        self.sub = {b.id: b for b in self.blocks if b.kind == "sub_resource"}
        self.nodes = [b for b in self.blocks if b.kind == "node"]

    def node_tree(self, name):
        """Üst düzey düğüm + tüm torunları (kaynak sırasıyla)."""
        out = []
        for b in self.nodes:
            if b.name == name and b.parent == ".":
                out.append(b)
            elif b.parent and (b.parent == name or b.parent.startswith(name + "/")):
                out.append(b)
        return out


def set_position(block, x=None, y=None, z=None):
    for i, l in enumerate(block.lines):
        m = re.match(r'position = Vector3\(([^,]+), ([^,]+), ([^)]+)\)', l)
        if m:
            cx, cy, cz = (float(m.group(k)) for k in (1, 2, 3))
            block.lines[i] = "position = Vector3(%s, %s, %s)" % (
                fmt(cx if x is None else x), fmt(cy if y is None else y), fmt(cz if z is None else z))
            return
    block.lines.insert(0, "position = Vector3(%s, %s, %s)" % (fmt(x if x is not None else 0.0), fmt(y if y is not None else 0.0), fmt(z if z is not None else 0.0)))


def override_line(block, pattern, replacement):
    for i, l in enumerate(block.lines):
        if re.search(pattern, l):
            block.lines[i] = replacement
            return True
    return False


def fmt(v):
    return ("%g" % v)


def clone(block):
    return Block(block.kind, block.attrs_text, list(block.lines))


def rename(block, new_name):
    block.attrs_text = block.attrs_text.replace('name="%s"' % block.name, 'name="%s"' % new_name, 1)
    block.name = new_name


def assemble(src, root_attrs, root_lines, extra_ext, extra_sub, node_blocks):
    ext_ids, sub_ids = set(), set()
    for b in node_blocks:
        e, s = b.refs()
        ext_ids |= e
        sub_ids |= s
    for b in extra_sub:
        e, s = b.refs()
        ext_ids |= e
        sub_ids |= s
    for b in [Block("x", "", root_lines)]:
        e, s = b.refs()
        ext_ids |= e
    local_sub = {b.id for b in extra_sub}
    local_ext = {b.id for b in extra_ext}
    sub_ids = {i for i in sub_ids if i not in local_sub}
    queue = list(sub_ids)
    while queue:
        sid = queue.pop()
        e, s = src.sub[sid].refs()
        ext_ids |= e
        for t in s:
            if t not in sub_ids and t not in local_sub:
                sub_ids.add(t)
                queue.append(t)
    ext_lines = [src.ext[i].text() for i in src.ext if i in ext_ids and i not in local_ext] + [b.text() for b in extra_ext]
    sub_blocks = [src.sub[i].text() for i in src.sub if i in sub_ids] + [b.text() for b in extra_sub]
    steps = len(ext_lines) + len(sub_blocks) + 1
    parts = ["[gd_scene load_steps=%d format=3]" % steps, ""]
    parts += ext_lines + [""]
    for t in sub_blocks:
        parts += [t, ""]
    parts.append(root_attrs)
    parts += root_lines
    parts.append("")
    for b in node_blocks:
        parts += [b.text(), ""]
    return "\n".join(parts).rstrip() + "\n"


def mk_ext(kind, path, rid):
    return Block("ext_resource", 'type="%s" path="%s" id="%s"' % (kind, path, rid), [])


def floor_nodes(src, length):
    """Zemin: koşulan masa tahtası + kenar şeritleri + rota çizgileri (yerel z: 0..-length)."""
    L = length + FLOOR_OVERLAP
    cz = -length / 2.0
    subs = [
        Block("sub_resource", 'type="BoxShape3D" id="TileShape"', ["size = Vector3(10, 0.5, %g)" % L]),
        Block("sub_resource", 'type="BoxMesh" id="TileMesh"', ['material = ExtResource("wood")', "size = Vector3(10, 0.5, %g)" % L]),
        Block("sub_resource", 'type="BoxMesh" id="ApronTileMesh"', ['material = ExtResource("wood_edge")', "size = Vector3(10, 0.35, %g)" % L]),
        Block("sub_resource", 'type="BoxMesh" id="EdgeTileMesh"', ['material = ExtResource("stripe")', "size = Vector3(0.1, 0.012, %g)" % length]),
        Block("sub_resource", 'type="BoxMesh" id="RouteTileMesh"', ['material = ExtResource("route")', "size = Vector3(0.08, 0.01, %g)" % length]),
    ]
    nodes = [
        Block("node", 'name="Floor" type="StaticBody3D" parent="."', ["position = Vector3(0, -0.25, %g)" % cz]),
        Block("node", 'name="CollisionShape3D" type="CollisionShape3D" parent="Floor"', ['shape = SubResource("TileShape")']),
        Block("node", 'name="Surface" type="MeshInstance3D" parent="Floor"', ['mesh = SubResource("TileMesh")']),
        Block("node", 'name="Apron" type="MeshInstance3D" parent="."', ["position = Vector3(0, -0.65, %g)" % cz, 'mesh = SubResource("ApronTileMesh")']),
        Block("node", 'name="EdgeLeft" type="MeshInstance3D" parent="."', ["position = Vector3(-4.85, 0.008, %g)" % cz, 'mesh = SubResource("EdgeTileMesh")']),
        Block("node", 'name="EdgeRight" type="MeshInstance3D" parent="."', ["position = Vector3(4.85, 0.008, %g)" % cz, 'mesh = SubResource("EdgeTileMesh")']),
        Block("node", 'name="RouteLeft" type="MeshInstance3D" parent="."', ["position = Vector3(-1.5, 0.006, %g)" % cz, 'mesh = SubResource("RouteTileMesh")']),
        Block("node", 'name="RouteRight" type="MeshInstance3D" parent="."', ["position = Vector3(1.5, 0.006, %g)" % cz, 'mesh = SubResource("RouteTileMesh")']),
    ]
    exts = []
    return subs, nodes


FLOOR_EXT = {
    "wood": "res://assets/materials/wood.tres",
    "wood_edge": "res://assets/materials/wood_edge.tres",
    "stripe": "res://assets/materials/stripe_yellow.tres",
    "route": "res://assets/materials/route_blue.tres",
}


def prop_blocks(prop_key, name, x, z, suffix):
    """desk_01'de olmayan bir masa eşyası için düğüm bloğu üretir (StatikBody + çarpışma + görsel).

    Dönüş: (ext_kaynakları, alt_kaynaklar, düğümler). Çarpışma şekli modelin tabanında
    (origin alt-merkez) olduğundan şekil merkezi y = yükseklik/2'ye konur.
    """
    spec = PROP_SPECS[prop_key]
    glb_id = "prop_glb_%s" % suffix
    shape_id = "PropShape_%s" % suffix
    ext = mk_ext("PackedScene", spec["glb"], glb_id)
    if spec["shape"] == "cylinder":
        sub = Block("sub_resource", 'type="CylinderShape3D" id="%s"' % shape_id,
                    ["radius = %s" % fmt(spec["radius"]), "height = %s" % fmt(spec["height"])])
        half = spec["height"] / 2.0
    else:
        sx, sy, sz = spec["size"]
        sub = Block("sub_resource", 'type="BoxShape3D" id="%s"' % shape_id,
                    ["size = Vector3(%s, %s, %s)" % (fmt(sx), fmt(sy), fmt(sz))])
        half = sy / 2.0
    node = Block("node", 'name="%s" type="StaticBody3D" parent="."' % name,
                 ["position = Vector3(%s, 0, %s)" % (fmt(x), fmt(z))])
    coll = Block("node", 'name="CollisionShape3D" type="CollisionShape3D" parent="%s"' % name,
                 ["position = Vector3(0, %s, 0)" % fmt(half), 'shape = SubResource("%s")' % shape_id])
    visual = Block("node", 'name="Visual" parent="%s" instance=ExtResource("%s")' % (name, glb_id), [])
    return [ext], [sub], [node, coll, visual]


def build_segment(src, seg_id, items, length=SEGMENT_LENGTH, props=()):
    """items: [(kaynak_düğüm, yeni_ad, {x,y,z,phase,direction,travel_direction})];
    props: [{key, name, x, z}] yeni masa eşyaları."""
    subs, nodes = floor_nodes(src, length)
    extra_ext = [mk_ext("Material", p, k) for k, p in FLOOR_EXT.items()]
    extra_ext.append(mk_ext("Script", "res://scripts/gameplay/segment.gd", "segment_script"))
    extra_sub = []
    placed = []
    for source_name, new_name, over in items:
        tree = [clone(b) for b in src.node_tree(source_name)]
        assert tree, source_name
        set_position(tree[0], over.get("x"), over.get("y"), over.get("z"))
        if "phase" in over:
            override_line(tree[0], r'phase_offset_seconds = ', 'phase_offset_seconds = %s' % fmt(over["phase"]))
        if "direction" in over:
            d = over["direction"]
            override_line(tree[0], r'direction = Vector3\(', 'direction = Vector3(%s, %s, %s)' % (fmt(d[0]), fmt(d[1]), fmt(d[2])))
        if "travel_direction" in over:
            d = over["travel_direction"]
            override_line(tree[0], r'travel_direction = Vector3\(', 'travel_direction = Vector3(%s, %s, %s)' % (fmt(d[0]), fmt(d[1]), fmt(d[2])))
        if new_name != source_name:
            old = source_name
            rename(tree[0], new_name)
            for b in tree[1:]:
                b.attrs_text = b.attrs_text.replace('parent="%s"' % old, 'parent="%s"' % new_name).replace('parent="%s/' % old, 'parent="%s/' % new_name)
        placed += tree
    for i, prop in enumerate(props):
        e, s, n = prop_blocks(prop["key"], prop["name"], prop["x"], prop["z"], prop.get("suffix", str(i)))
        extra_ext += e
        extra_sub += s
        placed += n
    root_attrs = '[node name="Segment" type="Node3D"]'
    root_lines = ['script = ExtResource("segment_script")', 'segment_id = "%s"' % seg_id, "length = %g" % length]
    text = assemble(src, root_attrs, root_lines, extra_ext, subs + extra_sub, nodes + placed)
    return text


# --- Parça tanımları ---------------------------------------------------------
# Kaynak düğümler (desk_01.tscn): tuş sıraları KeyRow1..4 (faz 0.0/0.8/1.6/2.4),
# FanLeft (yön -X), FanRight (yön +X), Mug, Book, RollingPencil1 (-X), RollingPencil2 (+X).
# Şeritler: yan |x| ~ 3.3, orta |x| < 1.5. Tuzaklar dinamiktir (probe onları geçilebilir sayar);
# sabit eşyalar (Mug/Book/props) gerçek engeldir ve en az 1.2 m'lik açık koridor bırakmalı.

def segment_defs():
    return [
        # --- calm (tags [], level başında kullanılır) ---
        dict(id="seg_calm_a", tags=[], calm=True, weight=1.0, min_level=1, items=[], props=[]),
        dict(id="seg_calm_b", tags=[], calm=True, weight=1.0, min_level=1, items=[], props=[
            dict(key="sticky_notes", name="Notes", x=-3.2, z=-4.0),
            dict(key="pen_cup", name="Cup", x=3.5, z=-8.0),
        ]),
        dict(id="seg_calm_c", tags=[], calm=True, weight=1.0, min_level=1, items=[], props=[
            dict(key="headphones", name="Phones", x=-3.6, z=-6.0),
            dict(key="sticky_notes", name="Notes", x=3.8, z=-3.0),
            dict(key="pen_cup", name="Cup", x=-3.8, z=-9.0),
        ]),
        # --- keys (orta şeride tuş; tek şerit daima boş) ---
        dict(id="seg_keys_a", tags=["keys"], weight=2.0, min_level=1, items=[
            ("KeyRow1Left", "KeyL", dict(z=-6.0)), ("KeyRow1Right", "KeyR", dict(z=-6.0))], props=[]),
        dict(id="seg_keys_b", tags=["keys"], weight=2.0, min_level=1, items=[
            ("KeyRow2Left", "KeyL1", dict(z=-3.0, phase=0.8)), ("KeyRow2Right", "KeyR1", dict(z=-3.0, phase=0.8)),
            ("KeyRow3Left", "KeyL2", dict(z=-9.0, phase=1.6)), ("KeyRow3Right", "KeyR2", dict(z=-9.0, phase=1.6))], props=[]),
        dict(id="seg_keys_c", tags=["keys"], weight=2.0, min_level=1, items=[
            ("KeyRow1Left", "KeyC", dict(x=0.0, z=-5.0, phase=0.0)),  # orta (eşzamanlı)
            ("KeyRow1Right", "KeyL", dict(x=-3.3, z=-5.0, phase=0.0))], props=[]),
        dict(id="seg_keys_d", tags=["keys"], weight=2.0, min_level=1, items=[
            ("KeyRow1Left", "KeyC", dict(x=0.0, z=-6.0, phase=0.0)),
            ("KeyRow1Right", "KeyR", dict(x=3.3, z=-6.0, phase=1.2))], props=[]),
        dict(id="seg_keys_e", tags=["keys"], weight=2.0, min_level=1, items=[
            ("KeyRow1Left", "KeyC", dict(x=0.0, z=-4.0, phase=0.0)),
            ("KeyRow2Left", "KeyL", dict(x=-3.3, z=-9.0, phase=0.8)),
            ("KeyRow2Right", "KeyR", dict(x=3.3, z=-9.0, phase=0.8))], props=[]),
        # --- obstacles (sabit engeller; orta şerit zikzak + dar geçit) ---
        dict(id="seg_obst_a", tags=["obstacles"], weight=2.0, min_level=2, items=[
            ("Mug", "Mug", dict(x=0.9, z=-4.0)), ("Book", "Book", dict(x=-1.2, z=-9.0))], props=[]),
        dict(id="seg_obst_b", tags=["obstacles"], weight=2.0, min_level=2, items=[
            ("Mug", "MugL", dict(x=-2.0, z=-3.0)), ("Mug", "MugR", dict(x=-2.0, z=-9.0))],
            props=[dict(key="book_stack", name="Stack", x=2.0, z=-6.0)]),
        dict(id="seg_obst_c", tags=["obstacles"], weight=2.0, min_level=2, items=[], props=[
            dict(key="book_stack", name="StackL", x=-3.4, z=-6.0),
            dict(key="book_stack", name="StackR", x=3.4, z=-6.0),
            dict(key="book_stack", name="StackC", x=-0.9, z=-6.0)]),
        dict(id="seg_obst_d", tags=["obstacles"], weight=2.0, min_level=2, items=[
            ("Mug", "MugL", dict(x=-3.3, z=-2.5)), ("Book", "BookL", dict(x=-3.3, z=-7.5)),
            ("Mug", "MugR", dict(x=3.3, z=-10.0))],
            props=[dict(key="pen_cup", name="Cup", x=3.3, z=-5.0)]),
        dict(id="seg_obst_e", tags=["obstacles"], weight=2.0, min_level=2, items=[
            ("Mug", "MugL", dict(x=-3.5, z=-8.0)), ("Book", "BookR", dict(x=3.5, z=-10.0))],
            props=[
                dict(key="headphones", name="Phones", x=-3.5, z=-4.0),
                dict(key="notebook", name="Pad", x=3.0, z=-6.0)]),
        # --- pencils (yan şeritlerde; orta şeride yaklaşan faz/yön) ---
        dict(id="seg_pencil_a", tags=["pencils"], weight=2.0, min_level=3, items=[
            ("RollingPencil1", "PencilA", dict(z=-4.0)), ("RollingPencil2", "PencilB", dict(z=-8.0))], props=[]),
        dict(id="seg_pencil_b", tags=["pencils"], weight=2.0, min_level=3, items=[
            ("RollingPencil1", "PencilR", dict(x=4.3, z=-5.0)),  # sağdan merkeze (-X)
            ("RollingPencil2", "PencilL", dict(x=-4.3, z=-5.0))], props=[]),
        dict(id="seg_pencil_c", tags=["pencils"], weight=2.0, min_level=3, items=[
            ("RollingPencil1", "PencilA", dict(x=2.6, z=-5.0)),
            ("RollingPencil2", "PencilB", dict(x=-2.6, z=-8.0))], props=[]),
        dict(id="seg_pencil_d", tags=["pencils"], weight=2.0, min_level=3, items=[
            ("RollingPencil1", "PencilA", dict(x=4.3, z=-4.0)),
            ("RollingPencil2", "PencilB", dict(x=-4.3, z=-6.0)),
            ("RollingPencil2", "PencilC", dict(x=-2.6, z=-8.0))], props=[]),
        # --- fans (rüzgar yönü/konumu çeşitli; karşı yönde >= 1.2 m boşluk) ---
        dict(id="seg_fan_a", tags=["fans"], weight=2.0, min_level=4, items=[
            ("FanLeft", "FanL", dict(z=-6.0)), ("FanRight", "FanR", dict(z=-6.0))], props=[]),
        dict(id="seg_fan_b", tags=["fans"], weight=2.0, min_level=4, items=[
            ("FanLeft", "FanL", dict(z=-6.0))], props=[]),
        dict(id="seg_fan_c", tags=["fans"], weight=2.0, min_level=4, items=[
            ("FanRight", "FanR", dict(z=-6.0))], props=[]),
        dict(id="seg_fan_d", tags=["fans"], weight=2.0, min_level=4, items=[
            ("FanLeft", "FanL", dict(z=-5.0)), ("FanRight", "FanR", dict(z=-7.0))], props=[]),
        # --- mixed (>= min_level 6; iki-üç tuzak türü) ---
        dict(id="seg_mixed_a", tags=["mixed"], weight=1.5, min_level=6, length=24.0, items=[
            ("KeyRow1Left", "KeyC", dict(x=0.0, z=-4.0, phase=0.0)),
            ("KeyRow1Right", "KeyL", dict(x=-3.3, z=-4.0, phase=0.4)),
            ("Mug", "Mug", dict(x=3.0, z=-9.0)),
            ("FanLeft", "FanL", dict(z=-15.0)),
            ("RollingPencil1", "Pencil", dict(x=4.3, z=-20.0))], props=[]),
        dict(id="seg_mixed_b", tags=["mixed"], weight=1.5, min_level=6, items=[
            ("Mug", "Mug", dict(x=-2.0, z=-4.0)),
            ("RollingPencil1", "Pencil", dict(x=4.3, z=-8.0))], props=[]),
        dict(id="seg_mixed_c", tags=["mixed"], weight=1.5, min_level=6, items=[
            ("KeyRow1Left", "KeyC", dict(x=0.0, z=-4.0, phase=0.0)),
            ("FanLeft", "FanL", dict(z=-6.0))],
            props=[dict(key="book_stack", name="Stack", x=2.0, z=-6.0)]),
    ]


def main():
    src = Source(SRC)
    out_dir = ROOT / "scenes/segments"
    out_dir.mkdir(parents=True, exist_ok=True)
    library = []
    for d in segment_defs():
        seg_id = d["id"]
        length = d.get("length", SEGMENT_LENGTH)
        (out_dir / (seg_id + ".tscn")).write_text(build_segment(src, seg_id, d["items"], length, d.get("props", [])))
        library.append({"id": seg_id, "scene": "res://scenes/segments/%s.tscn" % seg_id, "length": length,
                        "min_level": d["min_level"], "weight": d["weight"], "tags": d["tags"],
                        "calm": d.get("calm", False)})
    (ROOT / "data/segments.json").write_text(json.dumps({"segments": library}, indent=2, ensure_ascii=False) + "\n")
    print("parça:", len(library))


if __name__ == "__main__":
    main()
