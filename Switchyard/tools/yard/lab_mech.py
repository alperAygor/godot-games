"""Dünya 3-6 yol haritası için mekanik laboratuvarı (yalnız Python, yalnız deney).

Gönderilen kurallar (rules.py / yard_rules.gd) DEĞİŞMEZ: burada hızlı model alt sınıflanır, aday mekanikler
kesin geriye aramayla ölçülür. Seçilen bir mekanik yayına girecekse iki dilde `kind` ile eklenir + vektör.

Adaylar:
  magnets  Ayırma yalnız "ayırıcı" hücrelerde: iki bağlı araçtan biri ayırıcı hücredeyse kanca kalkar
           (gerçek Inglenook'taki mıknatıslar).
  rival    İki renk (ör. kırmızı-mor) komşu hücrelerde duramaz: bunu doğuracak adım engellenir.
  crane    Belli renkteki vagonlar hedefe gitmeden önce vinç hücresinden geçmeli (yüklenir); hedef yalnız
           yüklü vagonla sayılır.
  fragile  (DÜNYA 2'de elendi) itilemez vagon; burada birleşimlerde yeniden ölçülür.

  python3 tools/yard/lab_mech.py > build/lab_mech.json
"""

import json
import multiprocessing
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import layout  # noqa: E402
import rules  # noqa: E402
import graph  # noqa: E402
from fast import Yard, LOCO, wagon_code, code_color, SIDE_A, SIDE_B  # noqa: E402,F401
from mechlab import BASES  # noqa: E402


class LabYard(Yard):
    def __init__(self, level, opts):
        Yard.__init__(self, level)
        self.magnets = set(opts.get("magnets", ()))
        rv = opts.get("rival")
        self.rival = None
        if rv:
            self.rival = (rules.COLORS.index(rv[0]), rules.COLORS.index(rv[1]))
        self.crane = opts.get("crane")
        self.crane_colors = set(rules.COLORS.index(c) for c in opts.get("crane_colors", ()))
        self.fragile_on = bool(opts.get("fragile"))
        self.edges = [(p, q) for p in range(self.n) for s in (0, 1) for q in self.sides[p][s] if p < q]

    def _ci(self, code):
        return (code - 2) // 2

    def step(self, occ, train, side, branch):
        r = Yard.step(self, occ, train, side, branch)
        if r is None:
            return None
        new_occ, tr, moved, cont = r
        if moved and self.rival is not None:
            a, b = self.rival
            for (p, q) in self.edges:
                cp, cq = new_occ[p], new_occ[q]
                if cp >= 2 and cq >= 2:
                    x, y = self._ci(cp), self._ci(cq)
                    if (x, y) == (a, b) or (x, y) == (b, a):
                        # Yaklaşım: bu adımdaki bağlanmalar da yok sayılır (deney için yeterli).
                        return None
        if moved and self.crane is not None:
            c = self.crane
            code = new_occ[c]
            if code >= 2 and self._ci(code) in self.crane_colors and not (code - 2) & 1:
                new_occ = list(new_occ)
                new_occ[c] = code + 1
        return (new_occ, tr, moved, cont)

    def uncouple_options(self, occ, train):
        opts = Yard.uncouple_options(self, occ, train)
        if not self.magnets:
            return opts
        out = []
        for (i, j, t2) in opts:
            ok = True
            # kesilen her sınır bağında iki uçtan biri ayırıcıda olmalı
            if i > 0 and not (train[i - 1] in self.magnets or train[i] in self.magnets):
                ok = False
            if j < len(train) - 1 and not (train[j] in self.magnets or train[j + 1] in self.magnets):
                ok = False
            if ok:
                out.append((i, j, t2))
        return out

    def solved(self, occ):
        if not Yard.solved(self, occ):
            return False
        if self.crane is not None:
            for c, col in self.target_color.items():
                if col == "loco":
                    continue
                code = occ[c]
                if self._ci(code) in self.crane_colors and not (code - 2) & 1:
                    return False
        return True


class FragileYard(LabYard):
    """Kırılgan = kodun 1. biti (vinçle aynı anda kullanılmaz)."""

    def step(self, occ, train, side, branch):
        r = Yard.step(self, occ, train, side, branch)
        if r is None or not r[2]:
            return r
        hc, free, seq, lpos = self.head_info(occ, train, side)
        # adım sonrası lokomotifin önündekiler: yeni katar, sürüş yönü korunur; eski seq + yeni baş hücreleri
        new_occ, tr, moved, cont = r
        lc = new_occ.index(LOCO)
        li = tr.index(lc)
        ahead = tr[li + 1:] if cont == SIDE_B else tr[:li][::-1]
        for c in ahead:
            code = new_occ[c]
            if code >= 2 and (code - 2) & 1:
                return None
        return r


def run(job):
    name, label, opts, power, kinds = job
    base = BASES[name]
    cells = layout.build_cells(base["tracks"], kinds)
    ix = lambda x, y: layout.cell_index(cells, x, y)  # noqa: E731
    tg = [(ix(x, y), col) for (x, y, col) in base["targets"]]
    cell_opts = dict(opts)
    if "magnets" in opts:
        cell_opts["magnets"] = [ix(*p) for p in opts["magnets"]]
    if "crane" in opts:
        cell_opts["crane"] = ix(*opts["crane"])
    vehicles = [{"id": "L", "type": "loco", "cell": [c for c in range(len(cells)) if c not in [t[0] for t in tg]][0]}]
    if power:
        vehicles[0]["power"] = power
    for i, (c, col) in enumerate(tg):
        vehicles.append({"id": "w%d" % i, "type": "wagon", "color": col, "cell": c})
    lv = rules.Level({"id": "lab", "cells": cells, "vehicles": vehicles, "links": [],
                      "targets": [{"cell": c, "color": col} for (c, col) in tg]})
    cls = FragileYard if opts.get("fragile") else LabYard
    yard = cls(lv, cell_opts)
    base_occ = [0] * yard.n
    bit_cols = set()
    # Vinç: yükleme geri alınamaz; hedeften ileri taranan çizge yüksüz başlangıçları içermez. Bu yüzden tohum
    # "vagonlar hedefte ama yüksüz" durumlarıdır; çözülmüş (yüklü) durumlar oradan erişilir.
    if opts.get("fragile"):
        bit_cols = set([opts["fragile"]])
    for (c, col) in tg:
        base_occ[c] = wagon_code(col, col in bit_cols)
    seeds = []
    for c in range(yard.n):
        if base_occ[c] == 0:
            occ = list(base_occ)
            occ[c] = LOCO
            seeds.append(bytes(occ) + bytes([c]))
    t = time.time()
    G = graph.Graph(yard, seeds, max_states=3000000)
    D = G.dist_to_goal()
    n = yard.n
    best = 0
    for i, k in enumerate(G.keys):
        d = D[3 * i + 2]
        if d >= graph.INF or len(k) - n != 1:
            continue
        if opts.get("crane") and any(b >= 2 and (b - 2) & 1 for b in k[:n]):
            continue  # başta hiçbir vagon yüklü değil
        if d > best:
            best = d
    return {"base": name, "mech": label, "max_par": best, "states": G.N, "overflow": G.overflow,
            "sec": round(time.time() - t, 1)}


def jobs():
    out = []
    for name, base in BASES.items():
        cols = [c for (_x, _y, c) in base["targets"]]
        heads = base["siding_heads"]
        ends = base["siding_ends"]
        sw = base["switches"]
        out.append((name, "none", {}, 0, {}))
        # ayırıcı mıknatıs: tek hücre (çekme hattı / kör hat ağzı)
        for m in heads[:2] + [ends[-1]]:
            out.append((name, "magnets@%d,%d" % m, {"magnets": [m]}, 0, {}))
        out.append((name, "magnets@heads", {"magnets": heads}, 0, {}))
        # rakip renkler: ilk iki hedef rengi
        tg = base["targets"]
        for a in range(len(tg)):
            for b in range(a + 1, len(tg)):
                if (tg[a][0] - tg[b][0]) ** 2 + (tg[a][1] - tg[b][1]) ** 2 > 2:
                    out.append((name, "rival %s-%s" % (tg[a][2], tg[b][2]), {"rival": (tg[a][2], tg[b][2])}, 0, {}))
        # vinç: kör hat sonu / çekme hattı
        for cr in ends[:2]:
            if cr in [(x, y) for (x, y, _c) in base["targets"]]:
                continue
            out.append((name, "crane@%d,%d %s" % (cr + (cols[0],)), {"crane": cr, "crane_colors": [cols[0]]}, 0, {}))
        out.append((name, "crane@%d,%d all" % ends[-1], {"crane": ends[-1], "crane_colors": cols}, 0, {}))
        # birleşimler
        out.append((name, "traction1+gate", {}, 1, {heads[0]: {"kind": "gate"}, ends[-1]: {"kind": "plate"}}))
        out.append((name, "traction2+gate", {}, 2, {heads[0]: {"kind": "gate"}, ends[-1]: {"kind": "plate"}}))
        out.append((name, "traction2+spring", {}, 2, {sw[0]: {"kind": "spring", "spring": 1}}))
        out.append((name, "gate+spring", {}, 0, {heads[0]: {"kind": "gate"}, ends[-1]: {"kind": "plate"},
                                                  sw[-1]: {"kind": "spring", "spring": 1}}))
        out.append((name, "traction2+magnets", {"magnets": [heads[0]]}, 2, {}))
        out.append((name, "gate+magnets", {"magnets": [heads[0]]}, 0, {heads[1]: {"kind": "gate"},
                                                                       ends[-1]: {"kind": "plate"}}))
        out.append((name, "fragile+traction2", {"fragile": cols[0]}, 2, {}))
        out.append((name, "fragile+gate", {"fragile": cols[0]}, 0, {heads[0]: {"kind": "gate"},
                                                                    ends[-1]: {"kind": "plate"}}))
        out.append((name, "crane+traction2", {"crane": ends[-1], "crane_colors": cols}, 2, {}))
    return out


def main():
    res = []
    only = os.environ.get("LAB_ONLY", "")
    js = [j for j in jobs() if not only or only in j[1]]
    with multiprocessing.Pool(int(os.environ.get("LAB_JOBS", "4"))) as pool:
        for r in pool.imap_unordered(run, js):
            print(json.dumps(r), file=sys.stderr, flush=True)
            res.append(r)
    print(json.dumps(res, indent=1))


if __name__ == "__main__":
    main()
