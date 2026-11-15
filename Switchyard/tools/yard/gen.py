"""Switchyard seviye üreteci: elle çizilmiş saha şablonları + geriye arama.

Yöntem (DESIGN §4): hedef dizilişinden (çözülmüş durumlar) başlayıp bütün durum çizgesi taranır; hamleler
büyük ölçüde tersinir olduğundan bu uzaklık "başlangıçtan hedefe" uzaklığına çok yakındır. Hedefe EN UZAK
başlangıçlar aday olur, her aday ileri çözücüyle KESİN ölçülür, ölçütlere göre seçilir.

Kullanım:
  python3 tools/yard/gen.py explore <şablon> [--colors r,r,b,b] ...   (deney)
  python3 tools/yard/gen.py build                                     (data/levels yeniden üretimi)
"""

import argparse
import json
import os
import random
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import layout  # noqa: E402
import rules  # noqa: E402
import solver  # noqa: E402
from fast import Yard, LOCO, wagon_code  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
LEVEL_DIR = os.path.join(ROOT, "data", "levels")


# ---------------------------------------------------------------- yardımcılar

def make_level(lid, world, cells, vehicles, targets, links=None, par=0, solution=None, metrics=None):
    d = {"id": lid, "world": world, "cells": cells, "vehicles": vehicles, "links": links or [],
         "targets": targets, "par": par, "solution": solution or [], "metrics": metrics or {}}
    return d


def goal_level(cells, target_specs, loco_kind=None, power=0, fragile=None):
    """target_specs: [(cell, color)] — her vagonun bir hedefi var. Dönen seviye sözlüğünde araçlar hedeflerde,
    lokomotif ilk boş hücrede (yalnız yapı için; başlangıç üreteçte seçilir)."""
    raise NotImplementedError


def key_to_level(base, yard, key, fragile_ids=()):
    """Hızlı anahtardan seviye sözlüğü (araç kimlikleri renge göre r1, r2...)."""
    n = yard.n
    occ = list(key[:n])
    tr = list(key[n:])
    vehicles = []
    count = {}
    cell_vid = {}
    for c in range(n):
        code = occ[c]
        if code == 0:
            continue
        if code == LOCO:
            v = {"id": "L", "type": "loco", "cell": c}
            if base.get("power"):
                v["power"] = base["power"]
            vehicles.append(v)
            cell_vid[c] = "L"
            continue
        from fast import code_color, code_fragile
        col = code_color(code)
        count[col] = count.get(col, 0) + 1
        vid = "%s%d" % (col[0], count[col])
        v = {"id": vid, "type": "wagon", "color": col, "cell": c}
        if code_fragile(code):
            v["kind"] = "fragile"
        vehicles.append(v)
        cell_vid[c] = vid
    links = []
    for i in range(len(tr) - 1):
        links.append([cell_vid[tr[i]], cell_vid[tr[i + 1]]])
    # Kararlı sıra: lokomotif önce.
    vehicles.sort(key=lambda v: (v["type"] != "loco", v["id"]))
    return make_level(base["id"], base["world"], base["cells"], vehicles, base["targets"], links)


def goal_keys(yard, target_codes, loco_target=None):
    """Bütün vagonlar hedefte; lokomotif her boş hücrede (hedefi varsa yalnız orada), katar yalnız lokomotif."""
    n = yard.n
    base = [0] * n
    for c, code in target_codes:
        base[c] = code
    keys = []
    cells = [loco_target] if loco_target is not None else [c for c in range(n) if base[c] == 0]
    for c in cells:
        occ = list(base)
        occ[c] = LOCO
        keys.append(bytes(occ) + bytes([c]))
    return keys


def explore(spec, top=6, verbose=True, max_states=None, pick="far"):
    """spec: {"cells", "targets": [(cell,color,fragile)], "loco_target": cell|None, "power", ...}
    Döner: aday listesi [(approx_dist, key)] ve yard."""
    cells = spec["cells"]
    targets = [{"cell": c, "color": col} for (c, col, _f) in spec["targets"]]
    if spec.get("loco_target") is not None:
        targets.append({"cell": spec["loco_target"], "color": "loco"})
    vehicles = [{"id": "L", "type": "loco", "cell": _free_cell(cells, spec)}]
    if spec.get("power"):
        vehicles[0]["power"] = spec["power"]
    for i, (c, col, fr) in enumerate(spec["targets"]):
        v = {"id": "w%d" % i, "type": "wagon", "color": col, "cell": c}
        if fr:
            v["kind"] = "fragile"
        vehicles.append(v)
    lv = rules.Level(make_level("probe", 1, cells, vehicles, targets))
    yard = Yard(lv)
    tcodes = [(c, wagon_code(col, fr)) for (c, col, fr) in spec["targets"]]
    seeds = goal_keys(yard, tcodes, spec.get("loco_target"))
    t0 = time.time()
    dist, _g, over = solver.layered(yard, seeds, max_states=max_states)
    if verbose:
        mx = max(dist.values())
        print("  durumlar %d, en uzak %d, %.1fs%s" % (len(dist), mx, time.time() - t0, " (TAŞTI)" if over else ""),
              file=sys.stderr)
    n = yard.n
    cand = []
    for k, d in dist.items():
        if len(k) - n != 1:
            continue  # başlangıçta lokomotif tek başına
        cand.append((d, k))
    cand.sort(key=lambda x: -x[0])
    return cand, yard, lv, dist


def _free_cell(cells, spec):
    used = set(c for (c, _col, _f) in spec["targets"])
    for i in range(len(cells)):
        if i not in used and i != spec.get("loco_target"):
            return i
    raise ValueError("boş hücre yok")


def farthest(spec, max_states=None, keep=50):
    """Kesin geriye arama: hedefe en uzak, lokomotifin tek başına olduğu başlangıçlar.
    Döner (adaylar [(par, key)], yard, level, graph, D)."""
    import graph
    lv = probe_level(spec)
    yard = Yard(lv)
    tcodes = [(c, wagon_code(col, fr)) for (c, col, fr) in spec["targets"]]
    seeds = goal_keys(yard, tcodes, spec.get("loco_target"))
    G = graph.Graph(yard, seeds, max_states=max_states)
    D = G.dist_to_goal()
    n = yard.n
    out = []
    for i, k in enumerate(G.keys):
        d = D[3 * i + 2]
        if len(k) - n == 1 and d < graph.INF:
            out.append((d, i))
    out.sort(key=lambda x: -x[0])
    return out[:keep], yard, lv, G, D


def probe_level(spec):
    cells = spec["cells"]
    targets = [{"cell": c, "color": col} for (c, col, _f) in spec["targets"]]
    if spec.get("loco_target") is not None:
        targets.append({"cell": spec["loco_target"], "color": "loco"})
    vehicles = [{"id": "L", "type": "loco", "cell": _free_cell(cells, spec)}]
    if spec.get("power"):
        vehicles[0]["power"] = spec["power"]
    for i, (c, col, fr) in enumerate(spec["targets"]):
        v = {"id": "w%d" % i, "type": "wagon", "color": col, "cell": c}
        if fr:
            v["kind"] = "fragile"
        vehicles.append(v)
    return rules.Level(make_level("probe", 1, cells, vehicles, targets))


def exact_par(yard, key, max_states=None):
    dist, g, over = solver.layered(yard, [key], stop_at_goal=True, max_states=max_states)
    return g


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd")
    b = sub.add_parser("build")
    b.add_argument("--only", default="")
    b.add_argument("--jobs", type=int, default=5)
    sub.add_parser("index")
    sub.add_parser("table")
    c = sub.add_parser("curve")
    c.add_argument("--apply", action="store_true")
    args = ap.parse_args()
    if args.cmd == "build":
        import levels_def
        levels_def.build_all(only=set(x for x in args.only.split(",") if x), jobs=args.jobs)
    elif args.cmd == "curve":
        import levels_def
        mapping, problems = levels_def.curve(apply=args.apply)
        for old, new in sorted(mapping.items(), key=lambda x: x[1]):
            if old != new:
                print("%s -> %s" % (old, new))
        for p in problems:
            print("ZAYIF:", p)
    elif args.cmd == "table":
        import levels_def
        print(levels_def.levels_table())
    elif args.cmd == "index":
        import levels_def
        levels_def.write_index()
    else:
        ap.print_help()


if __name__ == "__main__":
    main()
