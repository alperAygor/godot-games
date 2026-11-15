"""Seviye dosyalarının denetimi (verify.sh'ten çağrılır; hızlı, çözücüsüz).

Her seviye: geçerli (rules.Level), ekran kısıtları (x 0..6, y 0..10, kenar 1 ya da √2, kesişen köşegen yok,
en çok 9 araç), kayıtlı çözüm Python kurallarıyla eylem eylem oynar ve tam `par` hamlede çözer, başta çözülmüş
değil, dizin ile dosya tutarlı, bloklar içinde zorluk ölçülebilir biçimde yükselir.

  python3 tools/yard/check_levels.py           # hızlı
  python3 tools/yard/check_levels.py --deep    # ayrıca par'ı çözücüyle yeniden kanıtla (yavaş)
"""

import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import rules  # noqa: E402
import solver  # noqa: E402
import levels_def  # noqa: E402

LEVEL_DIR = levels_def.LEVEL_DIR


def geometry_errors(d):
    errs = []
    cells = d["cells"]
    pts = set()
    for i, c in enumerate(cells):
        x, y = c["x"], c["y"]
        if not (0 <= x <= 6 and 0 <= y <= 10):
            errs.append("hücre %d ekran dışı" % i)
        if (x, y) in pts:
            errs.append("iki hücre aynı noktada")
        pts.add((x, y))
    edges = set()
    for i, c in enumerate(cells):
        for q in c["a"] + c["b"]:
            p1, p2 = (c["x"], c["y"]), (cells[q]["x"], cells[q]["y"])
            d2 = (p1[0] - p2[0]) ** 2 + (p1[1] - p2[1]) ** 2
            if d2 not in (1, 2):
                errs.append("kenar uzunluğu %d-%d" % (i, q))
            edges.add((p1, p2))
    for (p1, p2) in edges:
        if abs(p1[0] - p2[0]) == 1 and abs(p1[1] - p2[1]) == 1:
            if ((p1[0], p2[1]), (p2[0], p1[1])) in edges:
                errs.append("kesişen köşegenler %r-%r" % (p1, p2))
    if len(d["vehicles"]) > 9:
        errs.append("9'dan çok araç")
    return errs


def check(deep=False):
    problems = []
    with open(os.path.join(LEVEL_DIR, "index.json")) as f:
        index = json.load(f)["levels"]
    if len(index) != 40:
        problems.append("dizinde %d seviye (40 beklenir)" % len(index))
    hard = {}
    for e in index:
        lid = e["id"]
        with open(os.path.join(LEVEL_DIR, lid + ".json")) as f:
            d = json.load(f)
        try:
            lv = rules.Level(d)
        except rules.LevelError as ex:
            problems.append("%s: geçersiz: %s" % (lid, ex))
            continue
        problems += ["%s: %s" % (lid, x) for x in geometry_errors(d)]
        if lv.id != lid or e["par"] != lv.par or e["world"] != lv.world:
            problems.append("%s: dizin/dosya tutarsız" % lid)
        m = d.get("metrics", {})
        for k in ("min_cells", "states", "detours", "solutions_at_par", "difficulty", "hardness"):
            if k not in m:
                problems.append("%s: ölçüt eksik: %s" % (lid, k))
        if e.get("difficulty") != m.get("difficulty"):
            problems.append("%s: dizin zorluğu farklı" % lid)
        st = rules.initial_state(lv)
        if rules.is_solved(lv, st):
            problems.append("%s: başta çözülmüş" % lid)
        for i, a in enumerate(lv.solution):
            if not rules.apply_action(lv, st, a):
                problems.append("%s: çözüm eylemi %d uygulanamadı" % (lid, i))
                break
        if not rules.is_solved(lv, st):
            problems.append("%s: çözüm çözmüyor" % lid)
        n_drive = len([a for a in lv.solution if a["t"] == "drive"])
        if rules.count_moves(lv, lv.solution) != lv.par or n_drive != lv.par:
            problems.append("%s: çözüm par hamle değil" % lid)
        hard[lid] = solver.hardness(m) if "par" in m else 0
        if deep:
            m2, _ = solver.analyze(lv)
            if m2["par"] != lv.par:
                problems.append("%s: par yeniden çözümde %d" % (lid, m2["par"]))
    # Eğri: blok içinde komşu seviye ölçülebilir daha zor (öğretim bloğunda par artar).
    for bi, blk in enumerate(levels_def.BLOCKS):
        for a, b in zip(blk, blk[1:]):
            if a not in hard or b not in hard:
                continue
            if bi == 0:
                pa = json.load(open(os.path.join(LEVEL_DIR, a + ".json")))["par"]
                pb = json.load(open(os.path.join(LEVEL_DIR, b + ".json")))["par"]
                if pb <= pa:
                    problems.append("%s -> %s: öğretim parı artmıyor" % (a, b))
            elif hard[b] - hard[a] < levels_def.MARGIN:
                problems.append("%s -> %s: zorluk %.2f -> %.2f (en az +%.1f)" % (a, b, hard[a], hard[b],
                                                                                levels_def.MARGIN))
    return problems


def main():
    problems = check(deep="--deep" in sys.argv)
    for p in problems:
        print("x " + p)
    if problems:
        sys.exit(1)
    print("seviyeler tamam (40)")


if __name__ == "__main__":
    main()
