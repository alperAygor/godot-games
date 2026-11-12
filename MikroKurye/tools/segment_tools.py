#!/usr/bin/env python3
"""Sonsuz mod parça (segment) sahnelerini desk_01.tscn'den türetir.

Neden: tuzak düğümleri/alt kaynakları (şekil, mesh, betik) desk_01'de kanıtlanmış hâlde var;
elle kopyalamak yerine bu araç ilgili düğümleri bağımlılıklarıyla çıkarıp yeni sahneye koyar.
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
    block.lines.insert(0, "position = Vector3(%s, %s, %s)" % (fmt(x or 0.0), fmt(y or 0.0), fmt(z or 0.0)))


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


def build_segment(src, seg_id, items, length=SEGMENT_LENGTH):
    """items: [(kaynak_düğüm, yeni_ad, {x,y,z, phase})]"""
    subs, nodes = floor_nodes(src, length)
    extra_ext = [mk_ext("Material", p, k) for k, p in FLOOR_EXT.items()]
    extra_ext.append(mk_ext("Script", "res://scripts/gameplay/segment.gd", "segment_script"))
    placed = []
    for source_name, new_name, over in items:
        tree = [clone(b) for b in src.node_tree(source_name)]
        assert tree, source_name
        set_position(tree[0], over.get("x"), over.get("y"), over.get("z"))
        if "phase" in over:
            tree[0].lines = [re.sub(r'phase_offset_seconds = .*', 'phase_offset_seconds = %s' % fmt(over["phase"]), l) for l in tree[0].lines]
        if new_name != source_name:
            old = source_name
            rename(tree[0], new_name)
            for b in tree[1:]:
                b.attrs_text = b.attrs_text.replace('parent="%s"' % old, 'parent="%s"' % new_name).replace('parent="%s/' % old, 'parent="%s/' % new_name)
        placed += tree
    # kullanılan ext kaynaklarından zemin için tanımlıları çıkar (çift id olmasın)
    root_attrs = '[node name="Segment" type="Node3D"]'
    root_lines = ['script = ExtResource("segment_script")', 'segment_id = "%s"' % seg_id, "length = %g" % length]
    text = assemble(src, root_attrs, root_lines, extra_ext, subs, nodes + placed)
    return text


def main():
    src = Source(SRC)
    out_dir = ROOT / "scenes/segments"
    out_dir.mkdir(parents=True, exist_ok=True)
    defs = {
        "seg_calm_a": dict(tags=[], calm=True, weight=1.0, min_level=1, items=[]),
        "seg_keys_a": dict(tags=["keys"], weight=2.0, min_level=1, items=[
            ("KeyRow1Left", "KeyL", dict(z=-6.0)), ("KeyRow1Right", "KeyR", dict(z=-6.0))]),
        "seg_keys_b": dict(tags=["keys"], weight=2.0, min_level=1, items=[
            ("KeyRow2Left", "KeyL1", dict(z=-3.0, phase=0.8)), ("KeyRow2Right", "KeyR1", dict(z=-3.0, phase=0.8)),
            ("KeyRow3Left", "KeyL2", dict(z=-9.0, phase=1.6)), ("KeyRow3Right", "KeyR2", dict(z=-9.0, phase=1.6))]),
        "seg_obst_a": dict(tags=["obstacles"], weight=2.0, min_level=2, items=[
            ("Mug", "Mug", dict(x=0.9, z=-4.0)), ("Book", "Book", dict(x=-1.2, z=-9.0))]),
        "seg_pencil_a": dict(tags=["pencils"], weight=2.0, min_level=3, items=[
            ("RollingPencil1", "PencilA", dict(z=-4.0)), ("RollingPencil2", "PencilB", dict(z=-8.0))]),
        "seg_fan_a": dict(tags=["fans"], weight=2.0, min_level=4, items=[
            ("FanLeft", "FanL", dict(z=-6.0)), ("FanRight", "FanR", dict(z=-6.0))]),
    }
    library = []
    for seg_id, d in defs.items():
        (out_dir / (seg_id + ".tscn")).write_text(build_segment(src, seg_id, d["items"]))
        library.append({"id": seg_id, "scene": "res://scenes/segments/%s.tscn" % seg_id, "length": SEGMENT_LENGTH,
                        "min_level": d["min_level"], "weight": d["weight"], "tags": d["tags"], "calm": d.get("calm", False)})
    (ROOT / "data/segments.json").write_text(json.dumps({"segments": library}, indent=2, ensure_ascii=False) + "\n")
    print("parça:", len(library))


if __name__ == "__main__":
    main()
