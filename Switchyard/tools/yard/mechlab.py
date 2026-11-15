"""Mekanik deneyi: aynı sahalarda, aynı vagonlarla, her aday mekaniğin farklı yerleşimleri için kesin en büyük par.

  python3 tools/yard/mechlab.py > build/mechlab.json      (sonuç özeti docs/YARD.md §6)
"""

import json
import multiprocessing
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import layout  # noqa: E402
import gen  # noqa: E402

BASES = {
    "inglenook": {
        "tracks": ["3,8 3,7 3,6 3,5 3,4 3,3 3,2 3,1", "3,6 2,5 2,4 2,3 2,2", "2,5 1,4 1,3 1,2"],
        "targets": [(3, 1, "red"), (3, 2, "yellow"), (3, 3, "blue"), (3, 4, "green")],
        "switches": [(3, 6), (2, 5)],
        "siding_heads": [(3, 5), (2, 4), (1, 4)],
        "siding_ends": [(3, 1), (2, 2), (1, 2), (3, 8)],
    },
    "runaround": {
        "tracks": ["3,10 3,9 3,8 3,7 3,6 3,5 3,4 3,3 3,2", "3,8 4,7 4,6 4,5 4,4 3,3", "3,4 2,3 2,2 2,1"],
        "targets": [(2, 1, "red"), (2, 2, "blue"), (3, 2, "yellow")],
        "switches": [(3, 8), (3, 3), (3, 4)],
        "siding_heads": [(2, 3), (4, 6), (3, 5)],
        "siding_ends": [(2, 1), (3, 2), (3, 10), (4, 5)],
    },
    "timesaver": {
        "tracks": ["3,1 3,2 3,3 3,4 3,5 3,6 3,7 3,8 3,9", "3,2 4,3 4,4 4,5 4,6 4,7 3,8", "3,5 2,6 2,7 2,8",
                   "4,4 5,3 5,2 5,1"],
        "targets": [(2, 8, "red"), (2, 7, "blue"), (5, 1, "yellow")],
        "switches": [(3, 2), (3, 8), (3, 5), (4, 4)],
        "siding_heads": [(2, 6), (5, 3), (4, 6)],
        "siding_ends": [(2, 8), (5, 1), (3, 1), (3, 9)],
    },
}


def variants(name, base):
    out = [("none", {}, 0, ())]
    for p in (1, 2):
        out.append(("traction", {}, p, ()))
    # "fragile" (kırılgan vagon) da denendi ve elendi; kural kaldırıldığı için artık koşturulamaz
    # (sonuçlar docs/YARD.md §6).
    for sw in base["switches"]:
        for br in (0, 1):
            out.append(("spring", {sw: {"kind": "spring", "spring": br}}, 0, ()))
    for g in base["siding_heads"]:
        for pl in base["siding_ends"]:
            out.append(("gate", {g: {"kind": "gate"}, pl: {"kind": "plate"}}, 0, ()))
    return out


def run_one(args):
    name, mech, kinds, power, fragile = args
    base = BASES[name]
    try:
        cells = layout.build_cells(base["tracks"], kinds)
    except Exception as e:  # noqa
        return {"base": name, "mech": mech, "error": str(e)}
    ix = lambda x, y: layout.cell_index(cells, x, y)
    tg = [(ix(x, y), col, i in fragile) for i, (x, y, col) in enumerate(base["targets"])]
    # Plaka hedef hücresinde olmasın (yoksa kapı çözülmüş durumda hep açık olur; deney yine geçerli).
    spec = {"cells": cells, "targets": tg, "loco_target": None, "power": power}
    t = time.time()
    try:
        out, yard, lv, G, D = gen.farthest(spec, max_states=2500000)
    except Exception as e:  # noqa
        return {"base": name, "mech": mech, "error": repr(e)}
    best = out[0][0] if out else 0
    nbest = sum(1 for o in out if o[0] == best)
    # Hedefe ulaşabilen durum oranı (mekanik ölü uç yaratıyor mu)
    return {"base": name, "mech": mech, "power": power, "fragile": list(fragile),
            "kinds": {"%d,%d" % k: v for k, v in kinds.items()}, "max_par": best, "states": G.N,
            "overflow": G.overflow, "sec": round(time.time() - t, 1)}


def main():
    jobs = []
    for name, base in BASES.items():
        for (mech, kinds, power, fragile) in variants(name, base):
            jobs.append((name, mech, kinds, power, fragile))
    with multiprocessing.Pool(5) as pool:
        res = []
        for r in pool.imap_unordered(run_one, jobs):
            print(json.dumps(r), file=sys.stderr, flush=True)
            res.append(r)
    print(json.dumps(res, indent=1))


if __name__ == "__main__":
    main()
