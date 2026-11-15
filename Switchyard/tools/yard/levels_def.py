"""Kilometre taşı 1 seviye kümesi: 3 elle çizilmiş öğretim seviyesi + üretilen 37 seviye.

Her üretilen seviye: saha şablonu + hedef dizilişi + mekanik; başlangıç geriye aramadan, istenen par aralığında,
en dar (en az plan) ve en çok sezgiye aykırı (detour) aday seçilir. Sonra tam ölçüm (solver.analyze) yazılır.

  python3 tools/yard/gen.py build [--only w2-003,w2-004] [--jobs 5]
"""

import json
import multiprocessing
import os
import random
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import layout  # noqa: E402
import rules  # noqa: E402
import solver  # noqa: E402
import gen  # noqa: E402
import graph  # noqa: E402
from fast import Yard, wagon_code  # noqa: E402

LEVEL_DIR = gen.LEVEL_DIR

# ---------------------------------------------------------------- saha şablonları (7x11 dikey ızgara)

T = {
    # Düz hat + tek yan hat (öğretim)
    "spur": ["3,9 3,8 3,7 3,6 3,5 3,4 3,3 3,2", "3,6 2,5 2,4 2,3"],
    # Çatal: kısa çekme hattı, iki kör hat
    "fork": ["3,9 3,8 3,7 3,6 3,5 3,4 3,3 3,2 3,1", "3,6 2,5 2,4 2,3 2,2 2,1"],
    "fork_short": ["3,8 3,7 3,6 3,5 3,4 3,3 3,2", "3,6 2,5 2,4 2,3 2,2"],
    # Inglenook: üç kör hat, çekme hattı uzunluğu değişir
    "ingle_h4": ["3,10 3,9 3,8 3,7 3,6 3,5 3,4 3,3 3,2 3,1", "3,6 2,5 2,4 2,3 2,2", "2,5 1,4 1,3 1,2"],
    "ingle_h3": ["3,9 3,8 3,7 3,6 3,5 3,4 3,3 3,2 3,1", "3,6 2,5 2,4 2,3 2,2", "2,5 1,4 1,3 1,2"],
    "ingle_h2": ["3,8 3,7 3,6 3,5 3,4 3,3 3,2 3,1", "3,6 2,5 2,4 2,3 2,2", "2,5 1,4 1,3 1,2"],
    # Merdiven: dört paralel kör hat
    "ladder": ["1,9 1,8 1,7 2,6 3,5 4,4 5,3 5,2 5,1", "2,6 2,5 2,4 2,3", "3,5 3,4 3,3 3,2", "4,4 4,3 4,2 4,1"],
    "ladder_short": ["1,8 1,7 2,6 3,5 4,4 5,3 5,2 5,1", "2,6 2,5 2,4 2,3", "3,5 3,4 3,3 3,2", "4,4 4,3 4,2"],
    # Dolaşma hattı + kör hat
    "runaround": ["3,10 3,9 3,8 3,7 3,6 3,5 3,4 3,3 3,2", "3,8 4,7 4,6 4,5 4,4 3,3", "3,4 2,3 2,2 2,1"],
    # Timesaver: halka + zıt yönlü iki kör hat
    "timesaver": ["3,1 3,2 3,3 3,4 3,5 3,6 3,7 3,8 3,9", "3,2 4,3 4,4 4,5 4,6 4,7 3,8", "3,5 2,6 2,7 2,8",
                  "4,4 5,3 5,2 5,1"],
    # İki uçlu: dolaşma halkası ortada, iki yanda kör hatlar
    "twin": ["3,10 3,9 3,8 3,7 3,6 3,5 3,4 3,3 3,2 3,1 3,0", "3,8 4,7 4,6 4,5 4,4 4,3 3,2",
             "3,7 2,6 2,5 2,4", "4,4 5,3 5,2 5,1"],
}


def H(lid, world, tracks, vehicles, targets, links=(), kinds=None):
    """Elle seviye: araçlar ve hedefler ızgara koordinatıyla."""
    return {"hand": True, "id": lid, "world": world, "tracks": tracks, "kinds": kinds or {},
            "vehicles": vehicles, "targets": targets, "links": list(links)}


def G(lid, world, tpl, targets, par, loco_target=None, power=0, kinds=None, note="", h=None):
    """par: başlangıç aralığı (lo, hi). h: hedef hardness; verilirse aralıktaki adaylardan ona en yakını seçilir."""
    return {"hand": False, "id": lid, "world": world, "tracks": T[tpl], "tpl": tpl, "kinds": kinds or {},
            "targets": targets, "par": par, "loco_target": loco_target, "power": power, "note": note, "h": h}


SPRING = lambda br: {"kind": "spring", "spring": br}  # noqa: E731
GATE = {"kind": "gate"}
PLATE = {"kind": "plate"}

LEVELS = [
    # --- Dünya 1: yalnız temel kurallar
    H("w1-001", 1, ["3,9 3,8 3,7 3,6 3,5 3,4 3,3"],
      [("L", "loco", None, (3, 9)), ("r1", "wagon", "red", (3, 7))], [((3, 4), "red")]),
    H("w1-002", 1, ["3,9 3,8 3,7 3,6 3,5 3,4 3,3"],
      [("L", "loco", None, (3, 5)), ("r1", "wagon", "red", (3, 4))], [((3, 7), "red"), ((3, 9), "loco")],
      links=[("L", "r1")]),
    # Öğretim 3: dal seçimi. Vagon düz hattın ucunda; al (bağlan), makasın altına çek, sapan dala it.
    H("w1-003", 1, ["3,9 3,8 3,7 3,6 3,5 3,4 3,3 3,2", "3,6 2,5 2,4 2,3 2,2"],
      [("L", "loco", None, (3, 5)), ("r1", "wagon", "red", (3, 2))], [((2, 3), "red")]),
    G("w1-004", 1, "spur", [(2, 3, "red"), (3, 2, "blue")], (2, 4), h=3.7),
    G("w1-005", 1, "fork", [(2, 1, "red"), (3, 1, "blue")], (3, 6), h=4.7),
    G("w1-006", 1, "spur", [(2, 3, "red"), (2, 4, "blue")], (3, 5), h=5.2),
    G("w1-007", 1, "fork", [(2, 1, "red"), (2, 2, "blue"), (3, 1, "yellow")], (6, 9), h=6.8),
    G("w1-008", 1, "runaround", [(2, 1, "red"), (3, 2, "blue")], (4, 8), h=4.2),
    G("w1-009", 1, "ladder", [(2, 3, "red"), (3, 2, "blue"), (4, 1, "yellow")], (8, 12), h=8.3),
    G("w1-010", 1, "fork_short", [(2, 2, "red"), (2, 3, "blue"), (3, 2, "yellow")], (7, 10), h=7.8),
    G("w1-011", 1, "timesaver", [(2, 8, "red"), (5, 1, "blue")], (6, 10), h=5.8),
    G("w1-012", 1, "ingle_h4", [(3, 1, "red"), (3, 2, "blue"), (3, 3, "yellow")], (7, 11), h=6.3),
    G("w1-013", 1, "runaround", [(2, 1, "red"), (2, 2, "blue"), (3, 2, "yellow")], (7, 11), h=7.3),
    G("w1-014", 1, "ladder_short", [(2, 3, "red"), (3, 2, "blue"), (4, 2, "yellow"), (5, 1, "green")], (10, 14), h=9.9),
    G("w1-015", 1, "ingle_h3", [(3, 1, "red"), (3, 2, "blue"), (3, 3, "red"), (3, 4, "blue")], (9, 12), h=9.4),
    G("w1-016", 1, "timesaver", [(2, 8, "red"), (2, 7, "blue"), (5, 1, "yellow")], (10, 14), h=8.9),
    G("w1-017", 1, "ingle_h3", [(3, 1, "red"), (3, 2, "yellow"), (3, 3, "blue"), (3, 4, "green")], (11, 14), h=10.4),
    G("w1-018", 1, "ingle_h3", [(3, 1, "red"), (3, 2, "blue"), (3, 3, "red"), (3, 4, "blue"), (3, 5, "yellow")],
      (12, 15), h=11.4),
    G("w1-019", 1, "ingle_h2", [(3, 1, "red"), (3, 2, "yellow"), (3, 3, "blue"), (3, 4, "green")], (12, 17), h=10.9),
    G("w1-020", 1, "ingle_h2", [(3, 1, "red"), (3, 2, "blue"), (3, 3, "red"), (3, 4, "blue"), (3, 5, "yellow")],
      (14, 17), h=12.0),
    # --- Dünya 2: mekanikler tek tek; bloklar tepe zorluğu yükselecek sırada: çekiş (001-006), yaylı makas
    # (007-011), kapı + plaka (012-017), karışık (018-020). LEVELS sırası önemsiz: dizin kimliğe göre sıralanır.
    # Kapı + plaka
    G("w2-012", 2, "fork", [(2, 1, "red"), (3, 2, "blue")], (7, 10),
      kinds={(2, 3): GATE, (3, 1): PLATE}),
    G("w2-013", 2, "runaround", [(2, 1, "red"), (3, 2, "blue")], (8, 9),
      kinds={(2, 3): GATE, (3, 10): PLATE}),
    G("w2-014", 2, "runaround", [(2, 1, "red"), (2, 2, "blue"), (3, 2, "yellow")], (13, 15),
      kinds={(4, 6): GATE, (3, 10): PLATE}),
    G("w2-015", 2, "ingle_h3", [(3, 1, "red"), (3, 2, "blue"), (3, 3, "yellow")], (12, 13),
      kinds={(2, 4): GATE, (1, 2): PLATE}),
    G("w2-016", 2, "timesaver", [(2, 8, "red"), (2, 7, "blue"), (5, 1, "yellow")], (18, 21),
      kinds={(4, 6): GATE, (5, 1): PLATE}),
    G("w2-017", 2, "timesaver", [(2, 8, "red"), (2, 7, "blue"), (5, 2, "yellow")], (20, 24),
      kinds={(4, 6): GATE, (3, 9): PLATE}),
    # Çekiş gücü
    G("w2-001", 2, "fork", [(2, 1, "red"), (2, 2, "blue"), (3, 1, "yellow")], (10, 12), power=2),
    G("w2-002", 2, "runaround", [(2, 1, "red"), (3, 2, "blue")], (9, 10), power=1),
    G("w2-003", 2, "ingle_h4", [(3, 1, "red"), (3, 2, "blue"), (3, 3, "yellow"), (3, 4, "green")], (16, 18),
      power=2),
    G("w2-004", 2, "runaround", [(2, 1, "red"), (2, 2, "blue"), (3, 2, "yellow")], (17, 20), power=1),
    G("w2-005", 2, "timesaver", [(2, 8, "red"), (2, 7, "blue"), (5, 1, "yellow")], (20, 22), power=1),
    G("w2-006", 2, "ingle_h3", [(3, 1, "red"), (3, 2, "blue"), (3, 3, "yellow"), (3, 4, "green")], (22, 26),
      power=1),
    # Yaylı makas
    G("w2-007", 2, "runaround", [(2, 1, "red"), (3, 2, "blue")], (10, 12), kinds={(3, 8): SPRING(1)}),
    G("w2-008", 2, "runaround", [(2, 1, "red"), (2, 2, "blue"), (3, 2, "yellow")], (14, 22),
      kinds={(3, 8): SPRING(1)}, h=13.0),
    G("w2-009", 2, "timesaver", [(2, 8, "red"), (2, 7, "blue"), (5, 1, "yellow")], (18, 21),
      kinds={(4, 4): SPRING(1)}),
    G("w2-010", 2, "ingle_h3", [(3, 1, "red"), (3, 2, "blue"), (3, 3, "yellow"), (3, 4, "green")], (14, 15),
      kinds={(2, 5): SPRING(0)}),
    G("w2-011", 2, "timesaver", [(2, 8, "red"), (5, 2, "blue"), (5, 1, "yellow")], (15, 15),
      kinds={(3, 2): SPRING(1)}),
    # Karışık finaller
    G("w2-018", 2, "timesaver", [(2, 8, "red"), (2, 7, "blue"), (5, 1, "yellow")], (24, 28), power=2,
      kinds={(4, 6): GATE, (3, 9): PLATE}),
    G("w2-019", 2, "timesaver", [(2, 8, "red"), (2, 7, "blue"), (5, 1, "yellow")], (24, 32), power=1,
      kinds={(4, 6): GATE, (3, 9): PLATE}),
    G("w2-020", 2, "runaround", [(2, 1, "red"), (2, 2, "blue"), (3, 2, "yellow")], (28, 34), power=1,
      kinds={(3, 8): SPRING(1), (2, 3): GATE, (3, 10): PLATE}),
]


# ---------------------------------------------------------------- kurulum

def _cells(spec):
    return layout.build_cells(spec["tracks"], spec["kinds"])


def build_hand(spec):
    cells = _cells(spec)
    ix = lambda p: layout.cell_index(cells, p[0], p[1])  # noqa: E731
    vehicles = []
    for (vid, vt, col, p) in spec["vehicles"]:
        v = {"id": vid, "type": vt, "cell": ix(p)}
        if col:
            v["color"] = col
        vehicles.append(v)
    targets = [{"cell": ix(p), "color": col} for (p, col) in spec["targets"]]
    d = gen.make_level(spec["id"], spec["world"], cells, vehicles, targets, [list(x) for x in spec["links"]])
    return finalize(d, spec)


def build_generated(spec):
    cells = _cells(spec)
    ix = lambda x, y: layout.cell_index(cells, x, y)  # noqa: E731
    tg = [(ix(x, y), col, False) for (x, y, col) in spec["targets"]]
    lt = ix(*spec["loco_target"]) if spec["loco_target"] else None
    gspec = {"cells": cells, "targets": tg, "loco_target": lt, "power": spec["power"]}
    lv = gen.probe_level(gspec)
    yard = Yard(lv)
    seeds = gen.goal_keys(yard, [(c, wagon_code(col, False)) for (c, col, _f) in tg], lt)
    Gr = graph.Graph(yard, seeds, max_states=4000000)
    D = Gr.dist_to_goal()
    n = yard.n
    lo, hi = spec["par"]
    by_d = {}
    for i, k in enumerate(Gr.keys):
        d = D[3 * i + 2]
        if len(k) - n == 1 and lo <= d <= hi and not _wagons_home(yard, k):
            by_d.setdefault(d, []).append(i)
    maxd = max((D[3 * i + 2] for i in range(Gr.N) if D[3 * i + 2] < graph.INF), default=0)
    if not by_d:
        raise RuntimeError("%s: aralıkta başlangıç yok (en uzak %d)" % (spec["id"], maxd))
    rnd = random.Random(spec["id"])
    base = {"id": spec["id"], "world": spec["world"], "cells": cells, "power": spec["power"],
            "targets": [{"cell": c, "color": col} for (c, col, _f) in tg] +
                       ([{"cell": lt, "color": "loco"}] if lt is not None else [])}
    if spec.get("h") is None:
        d = max(by_d)
        pool = by_d[d]
        sample = pool if len(pool) <= 60 else rnd.sample(pool, 60)
        scored = []
        for i in sample:
            sols, _w = Gr.optimal_plans(D, i, cap=100000)
            scored.append((sols, i))
        scored.sort()
        best = None
        for sols, i in scored[:4]:
            d0 = gen.key_to_level(base, yard, Gr.keys[i])
            m, acts = solver.analyze(rules.Level(d0))
            score = (m["detours"] * 2 - min(6, len(str(m["solutions_at_par"]))), -m["solutions_at_par"])
            if best is None or score > best[0]:
                best = (score, d0)
    else:
        target = spec["h"]
        approx = []
        for d, pool in by_d.items():
            sample = pool if len(pool) <= 25 else rnd.sample(pool, 25)
            for i in sample:
                sols, _w = Gr.optimal_plans(D, i, cap=100000)
                reach = _reach_count(Gr, i)
                est = solver.hardness({"par": d, "detours": round(0.35 * d), "solutions_at_par": sols,
                                       "states": reach})
                approx.append((abs(est - target), i))
        approx.sort()
        best = None
        for _e, i in approx[:3]:
            d0 = gen.key_to_level(base, yard, Gr.keys[i])
            m, acts = solver.analyze(rules.Level(d0))
            err = abs(solver.hardness(m) - target)
            if best is None or err < best[0]:
                best = (err, d0)
    pool = by_d[max(by_d)]
    out = finalize(best[1], spec)
    out["_gen"] = {"template": spec["tpl"], "template_max_par": maxd, "candidates_at_par": len(pool)}
    return out


def _reach_count(Gr, start):
    seen = bytearray(Gr.N)
    seen[start] = 1
    stack = [start]
    fs, fd = Gr.fstart, Gr.fdst
    cnt = 1
    while stack:
        x = stack.pop()
        for e in range(fs[x], fs[x + 1]):
            y = fd[e]
            if not seen[y]:
                seen[y] = 1
                cnt += 1
                stack.append(y)
    return cnt


def _wagons_home(yard, key):
    # Bütün vagonlar hedefteyse başlangıç anlamsız (yalnız lokomotif gezer).
    occ = key[:yard.n]
    for c, col in yard.target_color.items():
        if col == "loco":
            continue
        code = occ[c]
        if code < 2:
            return False
        from fast import code_color
        if code_color(code) != col:
            return False
    return True


def finalize(d, spec):
    lvl = rules.Level(d)
    m, acts = solver.analyze(lvl)
    d = dict(d)
    d["par"] = m["par"]
    d["solution"] = acts
    d["metrics"] = m
    if spec.get("note"):
        d["note"] = spec["note"]
    # Lokomotifin çekiş gücü vehicles içinde
    for v in d["vehicles"]:
        if v["type"] == "loco" and spec.get("power"):
            v["power"] = spec["power"]
    d.pop("power", None)
    return d


def build_one(spec):
    t = time.time()
    try:
        d = build_hand(spec) if spec["hand"] else build_generated(spec)
    except Exception as e:  # noqa
        import traceback
        return spec["id"], None, "%s\n%s" % (e, traceback.format_exc())
    path = os.path.join(LEVEL_DIR, spec["id"] + ".json")
    write_level(path, d)
    return spec["id"], d["metrics"], "%.0fs" % (time.time() - t)


def write_level(path, d):
    order = ["id", "world", "note", "par", "cells", "vehicles", "links", "targets", "solution", "metrics", "_gen"]
    out = {k: d[k] for k in order if k in d}
    with open(path, "w") as f:
        json.dump(out, f, indent=1, ensure_ascii=False)
        f.write("\n")


def write_index():
    entries = []
    for spec in sorted(LEVELS, key=lambda x: x["id"]):
        path = os.path.join(LEVEL_DIR, spec["id"] + ".json")
        if not os.path.exists(path):
            continue
        with open(path) as f:
            d = json.load(f)
        entries.append({"id": d["id"], "world": d["world"], "par": d["par"],
                        "difficulty": d["metrics"]["difficulty"]})
    with open(os.path.join(LEVEL_DIR, "index.json"), "w") as f:
        json.dump({"levels": entries}, f, indent=1)
        f.write("\n")
    return entries


def build_all(only=None, jobs=5):
    specs = [s for s in LEVELS if not only or s["id"] in only]
    # Büyük durum uzaylı olanlar önce (paralellikte kuyruk sonu kısalsın).
    with multiprocessing.Pool(jobs) as pool:
        for lid, m, info in pool.imap_unordered(build_one, specs):
            if m is None:
                print("HATA %s: %s" % (lid, info), file=sys.stderr, flush=True)
            else:
                print("%s par %2d states %8d det %2d plans %6d diff %2d (%s)" % (
                    lid, m["par"], m["states"], m["detours"], m["solutions_at_par"], m["difficulty"], info),
                    file=sys.stderr, flush=True)
    write_index()


# ---------------------------------------------------------------- eğri: bloklar içinde ölçüme göre sırala

# Bloklar: blok başı (yeni mekanik) bilinçli bir düşüştür; blok içinde her seviye bir öncekinden ölçülebilir
# daha zor olmalı (hardness farkı >= MARGIN). Öğretim seviyeleri (w1-001..003) elle sıralı kalır.
BLOCKS = [
    ["w1-001", "w1-002", "w1-003"],
    ["w1-%03d" % i for i in range(4, 21)],
    ["w2-%03d" % i for i in range(1, 7)],     # çekiş gücü
    ["w2-%03d" % i for i in range(7, 12)],    # yaylı makas
    ["w2-%03d" % i for i in range(12, 18)],   # kapı + plaka
    ["w2-%03d" % i for i in range(18, 21)],   # karışık
]
MARGIN = 0.3


def curve(apply=False):
    """Blok içi sıralama önerisi (ve apply=True ise dosyaları/kimlikleri yeniden adlandırma). Döner ihlaller."""
    import re
    datas = {}
    for blk in BLOCKS:
        for lid in blk:
            path = os.path.join(LEVEL_DIR, lid + ".json")
            if os.path.exists(path):
                with open(path) as f:
                    datas[lid] = json.load(f)
                m = datas[lid]["metrics"]
                m["hardness"] = round(solver.hardness(m), 2)
                m["difficulty"] = solver.difficulty_score(m)
    mapping = {}
    for bi, blk in enumerate(BLOCKS):
        present = [lid for lid in blk if lid in datas]
        order = present if bi == 0 else sorted(present, key=lambda x: datas[x]["metrics"]["hardness"])
        for new, old in zip(present, order):
            mapping[old] = new
    problems = []
    for bi, blk in enumerate(BLOCKS):
        seq = [old for new in blk for old, nn in mapping.items() if nn == new]
        for a, b in zip(seq, seq[1:]):
            ha, hb = datas[a]["metrics"]["hardness"], datas[b]["metrics"]["hardness"]
            if hb - ha < MARGIN:
                problems.append("%s -> %s: hardness %.2f -> %.2f (< +%.1f)" % (mapping[a], mapping[b], ha, hb, MARGIN))
    if apply:
        for old, new in mapping.items():
            d = datas[old]
            d["id"] = new
            write_level(os.path.join(LEVEL_DIR, new + ".json"), d)
        # Tanım dosyasındaki kimlikleri de aynı eşlemeyle değiştir (bir sonraki üretim aynı dosyaya yazsın).
        src = open(__file__).read()
        for old, new in mapping.items():
            if old != new:
                src = src.replace('("%s",' % old, '("@@%s",' % new)
        src = src.replace('("@@', '("')
        with open(__file__, "w") as f:
            f.write(src)
        write_index()
    return mapping, problems


def mechanics_of(d):
    out = []
    for v in d["vehicles"]:
        if v["type"] == "loco" and v.get("power"):
            out.append("traction %d" % v["power"])
    kinds = set(c.get("kind", "plain") for c in d["cells"])
    if "gate" in kinds:
        out.append("gate")
    if "spring" in kinds:
        out.append("spring")
    return ", ".join(out) or "-"


def levels_table(notes=None):
    notes = notes or {}
    with open(os.path.join(LEVEL_DIR, "index.json")) as f:
        idx = json.load(f)["levels"]
    rows = ["| level | mechanics | yard | wagons | par | min_cells | states | dead | detours | plans@par | "
            "width | hardness | diff | note |", "|" + "---|" * 14]
    for e in idx:
        with open(os.path.join(LEVEL_DIR, e["id"] + ".json")) as f:
            d = json.load(f)
        m = d["metrics"]
        tpl = d.get("_gen", {}).get("template", "hand")
        wag = len([v for v in d["vehicles"] if v["type"] == "wagon"])
        rows.append("| %s | %s | %s | %d | %d | %d | %d | %d | %d | %d | %d | %.2f | %d | %s |" % (
            d["id"], mechanics_of(d), tpl, wag, m["par"], m["min_cells"], m["states"], m.get("dead_states", 0),
            m["detours"], m["solutions_at_par"], m.get("path_width", 0), m["hardness"], m["difficulty"],
            notes.get(d["id"], "")))
    return "\n".join(rows)
