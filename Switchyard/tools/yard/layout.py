"""Saha şablonu -> hücre listesi.

Şablon ızgara noktalarından geçen hat çizgileridir ("x,y x,y ..."). Ortak noktalar hatları birleştirir;
üç komşulu nokta makastır. Yanlar (a/b) açılardan kendiliğinden bulunur: bir hücreden geçiş en çok 45°
kırılır, aynı yandaki iki komşu (makas dalları) arası 45°dir. Telefon ekranı kısıtları burada denetlenir:
x 0..6, y 0..10, kenar uzunluğu 1 ya da √2, kesişen kenar yok.
"""

import math

GRID_W = 7
GRID_H = 11
COS45 = math.cos(math.pi / 4)
EPS = 1e-6


class LayoutError(ValueError):
    pass


def parse_tracks(tracks):
    """tracks: ["x,y x,y ...", ...] -> (points list, edges set of (i,j) i<j)."""
    pts = []
    index = {}
    edges = set()

    def pid(p):
        if p not in index:
            index[p] = len(pts)
            pts.append(p)
        return index[p]

    for line in tracks:
        seq = []
        for tok in line.split():
            xs, ys = tok.split(",")
            seq.append((int(xs), int(ys)))
        for i in range(len(seq) - 1):
            p, q = pid(seq[i]), pid(seq[i + 1])
            if p == q:
                raise LayoutError("yinelenen nokta: %r" % (seq[i],))
            edges.add((min(p, q), max(p, q)))
        if len(seq) == 1:
            pid(seq[0])
    return pts, edges


def _unit(p, q):
    dx, dy = q[0] - p[0], q[1] - p[1]
    d = math.hypot(dx, dy)
    return (dx / d, dy / d)


def _dot(u, v):
    return u[0] * v[0] + u[1] * v[1]


def check_geometry(pts, edges):
    for (x, y) in pts:
        if not (0 <= x < GRID_W and 0 <= y < GRID_H):
            raise LayoutError("nokta ekran dışı: %d,%d" % (x, y))
    eset = set()
    for (i, j) in edges:
        p, q = pts[i], pts[j]
        d2 = (p[0] - q[0]) ** 2 + (p[1] - q[1]) ** 2
        if d2 not in (1, 2):
            raise LayoutError("kenar uzunluğu 1 ya da √2 olmalı: %r-%r" % (p, q))
        eset.add((p, q))
        eset.add((q, p))
    # Tek kesişme biçimi: aynı birim karede iki köşegen.
    for (i, j) in edges:
        p, q = pts[i], pts[j]
        if abs(p[0] - q[0]) == 1 and abs(p[1] - q[1]) == 1:
            o1 = (p[0], q[1])
            o2 = (q[0], p[1])
            if (o1, o2) in eset:
                raise LayoutError("kesişen köşegenler: %r-%r" % (p, q))


def assign_sides(pts, edges):
    """Her nokta için (a listesi, b listesi). Dal sırası: 0 = gövdeyle en düz giden."""
    nbrs = [[] for _ in pts]
    for (i, j) in edges:
        nbrs[i].append(j)
        nbrs[j].append(i)
    result = []
    for p, nb in enumerate(nbrs):
        if not nb:
            raise LayoutError("bağlantısız nokta %r" % (pts[p],))
        if len(nb) > 4:
            raise LayoutError("4'ten çok komşu: %r" % (pts[p],))
        dirs = {q: _unit(pts[p], pts[q]) for q in nb}
        best = None
        k = len(nb)
        for mask in range(1 << k):
            g1 = [nb[i] for i in range(k) if mask & (1 << i)]
            g2 = [nb[i] for i in range(k) if not mask & (1 << i)]
            if len(g1) > 2 or len(g2) > 2 or not g1:
                continue
            ok = True
            for g in (g1, g2):
                if len(g) == 2 and _dot(dirs[g[0]], dirs[g[1]]) < COS45 - EPS:
                    ok = False
            for u in g1:
                for v in g2:
                    # u'dan gelip v'ye gitmek: kırılma <= 45°.
                    if _dot(dirs[u], dirs[v]) > -COS45 + EPS:
                        ok = False
            if ok:
                best = (g1, g2)
                break
        if best is None:
            raise LayoutError("geçersiz kavşak/keskin dönüş: %r" % (pts[p],))
        g1, g2 = best

        def mean(g):
            sx = sum(dirs[q][0] for q in g)
            sy = sum(dirs[q][1] for q in g)
            return (sx, sy)

        # Yön: a yanı kuzey (y küçük) ya da batı tarafı; çizim ve metin arayüzü için kararlı.
        m1 = mean(g1)
        flip = False
        if not g2:
            if m1[1] > EPS or (abs(m1[1]) <= EPS and m1[0] > 0):
                flip = True
        else:
            m2 = mean(g2)
            if m1[1] > m2[1] + EPS or (abs(m1[1] - m2[1]) <= EPS and m1[0] > m2[0]):
                flip = True
        a, b = (g2, g1) if flip else (g1, g2)

        def order(side, other):
            if len(side) < 2:
                return list(side)
            if other:
                body = mean(other)
                body = (-body[0], -body[1])
            else:
                body = mean(side)
            return sorted(side, key=lambda q: -_dot(dirs[q], body))

        result.append((order(a, b), order(b, a)))
    return result


def build_cells(tracks, kinds=None):
    """Şablondan CORE_API §1 hücre listesi. kinds: {(x,y): {"kind":..., ...}}."""
    pts, edges = parse_tracks(tracks)
    check_geometry(pts, edges)
    sides = assign_sides(pts, edges)
    # Hücre sırası: önce y sonra x (okunur kimlikler).
    order = sorted(range(len(pts)), key=lambda i: (pts[i][1], pts[i][0]))
    remap = {old: new for new, old in enumerate(order)}
    cells = []
    for old in order:
        a, b = sides[old]
        c = {"x": pts[old][0], "y": pts[old][1], "a": [remap[q] for q in a], "b": [remap[q] for q in b]}
        extra = (kinds or {}).get(pts[old])
        if extra:
            c.update(extra)
        cells.append(c)
    return cells


def cell_index(cells, x, y):
    for i, c in enumerate(cells):
        if c["x"] == x and c["y"] == y:
            return i
    raise KeyError((x, y))


def cell_name(cells, i):
    return "%s%d" % ("ABCDEFG"[int(cells[i]["x"])], int(cells[i]["y"]))
