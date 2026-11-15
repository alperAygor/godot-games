"""Uygunluk vektörleri: Python kurallarından tests/data/yard_vectors.json üretir.

GDScript testi (tests/unit/test_yard_vectors.gd) her vektörü oyunun kurallarıyla yeniden hesaplar; tek bir
ayrışma testi kırar. Kapsam: düz hat, makas merdiveni, halka (kuyruk ısırma), dolaşma hattı, iterek zincir,
tampona dayalı bağlanma, makasta bağlanma-durması, foul, mekanikler (çekiş, yaylı makas, kapı/plaka),
çok adımlı sürüş eylemleri, ayırma, çözüm denetimi ve bozuk seviye doğrulaması.

  python3 tools/yard/vectors.py            # yazar
  python3 tools/yard/vectors.py --check    # dosya güncel mi (verify.sh)
"""

import json
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import layout  # noqa: E402
import rules  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(ROOT, "tests", "data", "yard_vectors.json")

YARDS = [
    ("line", ["3,1 3,2 3,3 3,4 3,5 3,6 3,7"]),
    ("inglenook", ["3,10 3,9 3,8 3,7 3,6 3,5 3,4 3,3 3,2 3,1", "3,6 2,5 2,4 2,3 2,2", "2,5 1,4 1,3 1,2"]),
    ("timesaver", ["3,1 3,2 3,3 3,4 3,5 3,6 3,7 3,8 3,9", "3,2 4,3 4,4 4,5 4,6 4,7 3,8", "3,5 2,6 2,7 2,8",
                   "4,4 5,3 5,2 5,1"]),
    ("loop", ["2,2 3,2 4,3 4,4 3,5 2,5 1,4 1,3 2,2", "4,3 5,4 5,5 5,6"]),
    ("balloon", ["3,10 3,9 3,8 3,7 3,6 3,5 3,4 3,3 3,2 2,1 1,1 0,2 0,3 0,4 1,5 2,6 3,7"]),
    ("ladder", ["1,9 1,8 1,7 2,6 3,5 4,4 5,3 5,2 5,1", "2,6 2,5 2,4 2,3", "3,5 3,4 3,3 3,2", "4,4 4,3 4,2 4,1"]),
    ("scissors", ["2,1 2,2 2,3 2,4 2,5 2,6 2,7", "4,1 4,2 4,3 4,4 4,5 4,6 4,7", "2,3 3,4 4,5"]),
]

COLS = ["red", "blue", "yellow", "green"]


def make_cells(rnd, tracks, mech):
    cells = layout.build_cells(tracks)
    n = len(cells)
    if mech:
        # Mekanik süsleri rastgele: kapı/plaka, yaylı makas.
        if rnd.random() < 0.5:
            g, p = rnd.sample(range(n), 2)
            cells[g]["kind"] = "gate"
            cells[p]["kind"] = "plate"
            if rnd.random() < 0.5:
                g2 = rnd.randrange(n)
                if cells[g2].get("kind", "plain") == "plain":
                    cells[g2]["kind"] = "gate"
        for c in range(n):
            br = [s for s in (0, 1) if len(cells[c]["ab"[s]]) == 2]
            if len(br) == 1 and rnd.random() < 0.35 and cells[c].get("kind", "plain") == "plain":
                cells[c]["kind"] = "spring"
                cells[c]["spring"] = rnd.randrange(2)
    return cells


def random_level(rnd, cells, mech, dense=False):
    n = len(cells)
    k = rnd.randint(1, min(7, n - 1))
    if dense:
        # Halka hatlarında kuyruk ısırma ancak katar halkayı doldurunca olur.
        k = min(n - 1, rnd.randint(6, 9))
    occ = rnd.sample(range(n), k + 1)
    vs = [{"id": "L", "type": "loco", "cell": occ[0]}]
    if mech and rnd.random() < 0.4:
        vs[0]["power"] = rnd.randint(1, 3)
    for i, c in enumerate(occ[1:]):
        col = rnd.choice(COLS)
        v = {"id": "%s%d" % (col[0], i), "type": "wagon", "color": col, "cell": c}
        vs.append(v)
    free = [c for c in range(n)]
    rnd.shuffle(free)
    targets = []
    for c in free[:rnd.randint(1, 3)]:
        targets.append({"cell": c, "color": rnd.choice(COLS + ["loco"])})
    return {"id": "v", "world": 1, "cells": cells, "vehicles": vs, "links": [], "targets": targets}


def state_to_level(base, st):
    d = dict(base)
    vs = []
    for v in base["vehicles"]:
        v2 = dict(v)
        v2["cell"] = st.pos[v["id"]]
        vs.append(v2)
    d["vehicles"] = vs
    d["links"] = sorted(sorted(k) for k in st.links)
    return d


def expect_state(L, st):
    return {"pos": dict(st.pos), "links": sorted(sorted(k) for k in st.links),
            "train": rules.train(L, st), "solved": rules.is_solved(L, st), "key": st.key()}


def gen_cases(rnd, count):
    yards = []
    cases = []
    for (_name, tracks) in YARDS:
        yards.append(layout.build_cells(tracks))
    blocked_seen = {}
    while len(cases) < count:
        yi = rnd.randrange(len(YARDS))
        mech = rnd.random() < 0.45
        cells = make_cells(rnd, YARDS[yi][1], mech)
        base = random_level(rnd, cells, mech, dense=YARDS[yi][0] in ("loop", "balloon") and rnd.random() < 0.5)
        L = rules.Level(base)
        st = rules.initial_state(L)
        for _ in range(rnd.randint(15, 40)):
            if len(cases) >= count:
                break
            snap = state_to_level(base, st)
            r = rnd.random()
            if r < 0.62:
                side = rnd.randrange(2)
                br = rnd.randrange(2)
                work = st.copy()
                res = rules.step(L, work, side, br)
                case = {"level": snap, "op": "step", "side": side, "branch": br, "result": res.to_dict(),
                        "after": expect_state(L, work)}
                cases.append(case)
                blocked_seen[res.blocked] = blocked_seen.get(res.blocked, 0) + 1
                st = work
            elif r < 0.74:
                side = rnd.randrange(2)
                pr = rules.probe(L, st, side)
                cases.append({"level": snap, "op": "probe", "side": side, "result": pr.to_dict()})
            elif r < 0.86:
                ids = list(L.vehicle_ids)
                if st.links and rnd.random() < 0.8:
                    a, b = rnd.choice(sorted(sorted(k) for k in st.links))
                else:
                    a, b = rnd.sample(ids, 2) if len(ids) > 1 else (ids[0], ids[0])
                work = st.copy()
                ok = rules.uncouple(L, work, a, b)
                cases.append({"level": snap, "op": "uncouple", "between": [a, b], "result": ok,
                              "after": expect_state(L, work)})
                st = work
            else:
                act = {"t": "drive", "side": rnd.choice("ab"), "steps": rnd.randint(1, 5),
                       "branches": [rnd.randrange(2) for _ in range(rnd.randint(0, 3))]}
                work = st.copy()
                ok = rules.apply_action(L, work, act)
                cases.append({"level": snap, "op": "action", "action": act, "result": ok,
                              "after": expect_state(L, work)})
                st = work
    return cases, blocked_seen


def foul_cases():
    """Foul, makasta bağlanma-durması ve kuyruk ısırma elle kurulmuş vektörler (rastgele az düşer)."""
    out = []
    cells = layout.build_cells(["3,1 3,2 3,3 3,4 3,5", "3,3 4,4 4,5"])
    ix = lambda x, y: layout.cell_index(cells, x, y)
    lv = {"id": "v", "world": 1, "cells": cells, "targets": [{"cell": ix(3, 1), "color": "red"}],
          "vehicles": [{"id": "L", "type": "loco", "cell": ix(3, 5)},
                       {"id": "r1", "type": "wagon", "color": "red", "cell": ix(3, 3)},
                       {"id": "b1", "type": "wagon", "color": "blue", "cell": ix(4, 4)}],
          "links": [["b1", "r1"]]}
    L = rules.Level(lv)
    st = rules.initial_state(L)
    rules.step(L, st, 0, 0)
    snap = state_to_level(lv, st)
    work = st.copy()
    res = rules.step(L, work, 0, 0)
    assert res.blocked == "foul"
    out.append({"level": snap, "op": "step", "side": 0, "branch": 0, "result": res.to_dict(),
                "after": expect_state(L, work)})
    lv2 = dict(lv)
    lv2["vehicles"] = [{"id": "L", "type": "loco", "cell": ix(3, 1)},
                       {"id": "r1", "type": "wagon", "color": "red", "cell": ix(3, 3)}]
    lv2["links"] = []
    L2 = rules.Level(lv2)
    st2 = rules.initial_state(L2)
    for br in (0, 1):
        work = st2.copy()
        res = rules.step(L2, work, 1, br)
        out.append({"level": lv2, "op": "step", "side": 1, "branch": br, "result": res.to_dict(),
                    "after": expect_state(L2, work)})
    # Kuyruk ısırma: dolu halka, katar zincir; bir ucu ayrılmış hali (bağlanır, sonra kendine dayanır).
    ring = layout.build_cells(["2,2 3,2 4,3 4,4 3,5 2,5 1,4 1,3 2,2"])
    order = [0]
    while len(order) < 8:
        cc = ring[order[-1]]
        for q in cc["a"] + cc["b"]:
            if q not in order:
                order.append(q)
                break
    for nveh in (8, 7):
        vs = [{"id": "L", "type": "loco", "cell": order[0]}] + [
            {"id": "w%d" % i, "type": "wagon", "color": "red", "cell": order[i]} for i in range(1, nveh)]
        for cut in (False, True):
            links = [[vs[i]["id"], vs[i + 1]["id"]] for i in range(nveh - 1 - (1 if cut else 0))]
            lvr = {"id": "v", "world": 1, "cells": ring, "vehicles": vs, "links": links,
                   "targets": [{"cell": order[0], "color": "red"}]}
            Lr = rules.Level(lvr)
            for side in (0, 1):
                st = rules.initial_state(Lr)
                res = rules.step(Lr, st, side, 0)
                out.append({"level": lvr, "op": "step", "side": side, "branch": 0, "result": res.to_dict(),
                            "after": expect_state(Lr, st)})
    return out


def invalid_levels(rnd):
    out = []
    base_cells = layout.build_cells(YARDS[1][1])
    ix = lambda x, y: layout.cell_index(base_cells, x, y)

    def lv(**kw):
        d = {"id": "bad", "world": 1, "cells": [dict(c, a=list(c["a"]), b=list(c["b"])) for c in base_cells],
             "vehicles": [{"id": "L", "type": "loco", "cell": ix(3, 9)},
                          {"id": "r1", "type": "wagon", "color": "red", "cell": ix(3, 8)},
                          {"id": "b1", "type": "wagon", "color": "blue", "cell": ix(3, 7)}],
             "links": [["L", "r1"]], "targets": [{"cell": ix(3, 1), "color": "red"}]}
        d.update(kw)
        return d

    good = lv()
    out.append(("ok", good, True))
    d = lv()
    d["cells"][ix(3, 4)]["a"] = []
    out.append(("asymmetric", d, False))
    d = lv()
    c = d["cells"][ix(3, 4)]
    c["a"] = c["a"] + [ix(1, 2), ix(1, 3)]
    out.append(("three_neighbours", d, False))
    d = lv()
    d["vehicles"][2]["cell"] = ix(3, 8)
    out.append(("two_in_cell", d, False))
    d = lv(links=[["L", "b1"]])
    out.append(("link_not_adjacent", d, False))
    # Bir yanda iki bağ: makas hücresindeki araç iki dala bağlı.
    sw = ix(3, 6)
    d = lv(vehicles=[{"id": "L", "type": "loco", "cell": sw},
                     {"id": "r1", "type": "wagon", "color": "red", "cell": ix(3, 5)},
                     {"id": "b1", "type": "wagon", "color": "blue", "cell": ix(2, 5)}],
           links=[["L", "r1"], ["L", "b1"]])
    out.append(("two_links_one_side", d, False))
    d = lv(links=[["L", "r1"], ["r1", "L"]])
    out.append(("duplicate_link", d, False))
    d = lv()
    d["vehicles"].append({"id": "L2", "type": "loco", "cell": ix(3, 1)})
    out.append(("two_locos", d, False))
    d = lv()
    d["vehicles"][1]["color"] = "pink"
    out.append(("bad_color", d, False))
    d = lv(targets=[])
    out.append(("no_targets", d, False))
    d = lv(targets=[{"cell": 99, "color": "red"}])
    out.append(("target_out_of_range", d, False))
    d = lv()
    d["cells"][0]["b"] = d["cells"][0]["b"] + [0]
    out.append(("self_neighbour", d, False))
    d = lv()
    d["cells"][0]["kind"] = "lava"
    out.append(("bad_kind", d, False))
    d = lv()
    d["cells"][ix(3, 5)]["kind"] = "spring"
    out.append(("spring_without_branch", d, False))
    d = lv()
    d["vehicles"][1]["kind"] = "glass"
    out.append(("bad_vehicle_kind", d, False))
    d = lv()
    d["vehicles"][0]["cell"] = 1.5
    out.append(("fractional_cell", d, False))
    d = lv()
    del d["vehicles"][0]
    d["links"] = []
    out.append(("no_loco", d, False))
    # Halka: dolu halka hattında zincir yerine halka bağları.
    ring = layout.build_cells(["2,2 3,2 4,3 4,4 3,5 2,5 1,4 1,3 2,2"])
    order = [0]
    while len(order) < 8:
        cc = ring[order[-1]]
        for q in cc["a"] + cc["b"]:
            if q not in order:
                order.append(q)
                break
    vs = [{"id": "L", "type": "loco", "cell": order[0]}] + [
        {"id": "w%d" % i, "type": "wagon", "color": "red", "cell": order[i]} for i in range(1, 8)]
    links = [[vs[i]["id"], vs[(i + 1) % 8]["id"]] for i in range(8)]
    out.append(("ring", {"id": "bad", "cells": ring, "vehicles": vs, "links": links,
                         "targets": [{"cell": 0, "color": "red"}]}, False))
    # Python ile uyum: her biri Python'da da aynı sonucu vermeli.
    for name, d, valid in out:
        try:
            rules.Level(d)
            ok = True
        except rules.LevelError:
            ok = False
        assert ok == valid, name
    return [{"name": n, "level": d, "valid": v} for (n, d, v) in out]


def build(seed=20261115, count=3000):
    rnd = random.Random(seed)
    cases, seen = gen_cases(rnd, count)
    cases += foul_cases()
    # Hücre listeleri tekrar eder: bir kez yazılır, vektör "cells_ref" ile başvurur (dosya boyutu).
    pool = {}
    cell_lists = []
    for c in cases:
        lvd = dict(c["level"])
        key = json.dumps(lvd["cells"], sort_keys=True)
        if key not in pool:
            pool[key] = len(cell_lists)
            cell_lists.append(lvd["cells"])
        del lvd["cells"]
        lvd["cells_ref"] = pool[key]
        c["level"] = lvd
    return {"_note": "tools/yard/vectors.py üretir; elle düzenlenmez", "seed": seed,
            "cell_lists": cell_lists, "cases": cases, "invalid": invalid_levels(rnd)}, seen


def main():
    data, seen = build()
    text = json.dumps(data, sort_keys=True, separators=(",", ":"))
    if "--check" in sys.argv:
        if not os.path.exists(OUT) or open(OUT).read() != text:
            print("yard_vectors.json eski: python3 tools/yard/vectors.py", file=sys.stderr)
            sys.exit(1)
        print("vektörler güncel (%d durum, %d geçersiz seviye)" % (len(data["cases"]), len(data["invalid"])))
        return
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w") as f:
        f.write(text)
    print("yazıldı: %s (%d vektör, %d geçersiz seviye) engeller: %s" % (
        OUT, len(data["cases"]), len(data["invalid"]), seen), file=sys.stderr)


if __name__ == "__main__":
    main()
