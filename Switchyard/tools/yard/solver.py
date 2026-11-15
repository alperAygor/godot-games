"""Switchyard çözücüsü: hamle sayısında en iyi (DESIGN §2 sayım kuralı), eşitlikte en az hücre.

Hamle = aynı yönde kesintisiz sürüş; ayırma bedava ama sonraki sürüşü yeni hamle yapar. Bu yüzden arama
düğümü (durum, devam yanı) çiftidir: aynı yönde sürmeyi sürdürmek 0, yeni yön 1 hamle tutar.

Ölçütler (`analyze`): par, min_cells, states, detours, solutions_at_par, depth/branch istatistikleri ve
türetilmiş difficulty (formül ve gerekçe: docs/YARD.md §5).
"""

import heapq
import math
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import rules  # noqa: E402
from fast import Yard, LOCO, code_color  # noqa: E402

NO_DIR = 2


# ---------------------------------------------------------------- katmanlı BFS (par, durum sayısı)

def layered(yard, sources, stop_at_goal=False, max_layer=None, max_states=None):
    """Kaynaklardan hamle katmanları. Döner: (dist sözlüğü, hedefe ilk ulaşılan katman ya da None, taşma)."""
    dist = {}
    frontier = []
    for k in sources:
        if k not in dist:
            dist[k] = 0
            frontier.append(k)
    frontier = _closure(yard, frontier, 0, dist)
    goal_layer = None
    if stop_at_goal:
        for k in frontier:
            if yard.solved(list(k[:yard.n])):
                return dist, 0, False
    d = 0
    seen_drive = set()
    n = yard.n
    while frontier:
        if max_layer is not None and d >= max_layer:
            break
        nxt = []
        for k in frontier:
            occ = list(k[:n])
            tr = list(k[n:])
            for side in (0, 1):
                stack = [(occ, tr, side)]
                while stack:
                    o, t, s = stack.pop()
                    for _br, r in yard.drive_options(o, t, s):
                        nk = bytes(r[0]) + bytes(r[1])
                        dk = dist.get(nk)
                        if dk is not None and dk <= d:
                            continue
                        if dk is None:
                            dist[nk] = d + 1
                            nxt.append(nk)
                            if stop_at_goal and yard.solved(r[0]):
                                return dist, d + 1, False
                        dv = (nk, r[3])
                        if dv in seen_drive:
                            continue
                        seen_drive.add(dv)
                        stack.append((r[0], r[1], r[3]))
            if max_states is not None and len(dist) > max_states:
                return dist, goal_layer, True
        seen_drive.clear()
        nxt = _closure(yard, nxt, d + 1, dist)
        if stop_at_goal:
            for k in nxt:
                if yard.solved(list(k[:n])):
                    return dist, d + 1, False
        frontier = nxt
        d += 1
    return dist, goal_layer, False


def _closure(yard, keys, d, dist):
    out = list(keys)
    n = yard.n
    for k in keys:
        occ = list(k[:n])
        tr = list(k[n:])
        for (_i, _j, t2) in yard.uncouple_options(occ, tr):
            nk = k[:n] + bytes(t2)
            if nk not in dist:
                dist[nk] = d
                out.append(nk)
    return out


# ---------------------------------------------------------------- Dijkstra (hamle, hücre)

def solve_path(yard, start_key, max_nodes=None):
    """En az hamle, eşitlikte en az hücre. Döner (moves, cells, geçişler) ya da None.

    geçiş: ("s", side, branch, needs_branch, önceki anahtar) | ("u", i, j, önceki anahtar)
    """
    n = yard.n
    start = (start_key, NO_DIR)
    best = {start: (0, 0)}
    parent = {start: None}
    heap = [(0, 0, 0, start_key, NO_DIR)]
    counter = 1
    done = set()
    while heap:
        m, c, _, k, dr = heapq.heappop(heap)
        node = (k, dr)
        if node in done:
            continue
        done.add(node)
        occ = list(k[:n])
        tr = list(k[n:])
        if yard.solved(occ):
            path = []
            cur = node
            while parent[cur] is not None:
                prev, act = parent[cur]
                path.append(act)
                cur = prev
            path.reverse()
            return m, c, path
        if max_nodes is not None and len(done) > max_nodes:
            return None
        for side in (0, 1):
            nb = yard.needs_branch(occ, tr, side)
            for br, r in yard.drive_options(occ, tr, side):
                nm = m + (0 if side == dr else 1)
                nc = c + r[2]
                nk = bytes(r[0]) + bytes(r[1])
                nn = (nk, r[3])
                old = best.get(nn)
                if old is None or (nm, nc) < old:
                    best[nn] = (nm, nc)
                    parent[nn] = (node, ("s", side, br, nb))
                    heapq.heappush(heap, (nm, nc, counter, nk, r[3]))
                    counter += 1
        for (i, j, t2) in yard.uncouple_options(occ, tr):
            nk = k[:n] + bytes(t2)
            nn = (nk, NO_DIR)
            old = best.get(nn)
            if old is None or (m, c) < old:
                best[nn] = (m, c)
                parent[nn] = (node, ("u", i, j, tr))
                heapq.heappush(heap, (m, c, counter, nk, NO_DIR))
                counter += 1
    return None


# ---------------------------------------------------------------- gerçek eylemlere çevirme

class RealizeError(RuntimeError):
    pass


def realize(level, path):
    """Hızlı modeldeki geçişleri CORE_API §1 eylemlerine çevirir ve rules.py ile yeniden oynatarak denetler.

    Ayırmada önce yalnız sınır bağları kesilir; gerçek durum hızlı modelden ayrışırsa (duran dizideki bağ bir
    makasta ya da 'foul' engelinde fark yaratırsa) kopan parçanın iç bağları da kesilir.
    """
    yard = Yard(level)
    st = rules.initial_state(level)
    actions = []
    cur_drive = None  # {"t":"drive", ...} birikmekte olan sürüş
    cont = None
    fast_key = yard.from_level_state(st)
    for act in path:
        if act[0] == "s":
            _, side, br, nb = act
            if cur_drive is not None and side == cont:
                cur_drive["steps"] += 1
                if nb:
                    cur_drive["branches"].append(br)
            else:
                cur_drive = {"t": "drive", "side": "ab"[side], "steps": 1, "branches": [br] if nb else []}
                actions.append(cur_drive)
            pr = rules.probe(level, st, side)
            if pr.needs_branch != bool(nb):
                raise RealizeError("dal ihtiyacı ayrıştı")
            old = st.pos[level.loco]
            r = rules.step(level, st, side, br)
            if not r.effective():
                raise RealizeError("adım gerçek kurallarda etkisiz")
            cont = rules.continue_side(level, old, st.pos[level.loco], side)
        else:
            _, i, j, tr_before = act
            cur_drive = None
            cont = None
            cuts = []
            if i > 0:
                cuts.append((tr_before[i - 1], tr_before[i]))
            if j < len(tr_before) - 1:
                cuts.append((tr_before[j], tr_before[j + 1]))
            for (c1, c2) in cuts:
                a, b = st.at[c1], st.at[c2]
                if not rules.uncouple(level, st, a, b):
                    raise RealizeError("ayrılacak bağ yok")
                actions.append({"t": "uncouple", "between": [a, b]})
            # Kopan parçaların iç bağlarını da kes (normalleştirmeyle birebir aynı durum için).
            keep = set(tr_before[i:j + 1])
            for c in tr_before:
                if c in keep:
                    continue
            detached = [c for c in tr_before if c not in keep]
            for x in range(len(tr_before) - 1):
                c1, c2 = tr_before[x], tr_before[x + 1]
                if c1 in keep or c2 in keep:
                    continue
                a, b = st.at[c1], st.at[c2]
                if st.is_linked(a, b):
                    rules.uncouple(level, st, a, b)
                    actions.append({"t": "uncouple", "between": [a, b]})
            del detached
        fast_key = yard.from_level_state(st)
        _ = fast_key
    if not rules.is_solved(level, st):
        raise RealizeError("çözüm gerçek kurallarda çözmedi")
    return actions


def simplify_uncouples(level, actions, par):
    """Gereksiz iç-bağ kesimlerini at: her birini çıkarıp yeniden oynat; hamle sayısı ve çözüm korunuyorsa sil."""
    acts = list(actions)
    i = 0
    while i < len(acts):
        if acts[i]["t"] != "uncouple":
            i += 1
            continue
        trial = acts[:i] + acts[i + 1:]
        if _replay_ok(level, trial, par):
            acts = trial
        else:
            i += 1
    return acts


def _replay_ok(level, actions, par):
    # Bitişik aynı yönlü sürüşler birleşmeli (ayırma silinince ikisi tek hamle olur).
    acts = merge_drives(level, actions)
    st = rules.initial_state(level)
    for a in acts:
        if not rules.apply_action(level, st, a):
            return False
    if not rules.is_solved(level, st):
        return False
    return rules.count_moves(level, acts) == par and len([a for a in acts if a["t"] == "drive"]) == par


def merge_drives(level, actions):
    out = []
    st = rules.initial_state(level)
    cont = None
    for a in actions:
        a = {k: (list(v) if isinstance(v, list) else v) for k, v in a.items()}
        if a["t"] == "drive":
            side = 0 if a["side"] == "a" else 1
            end = rules.drive_end_side(level, st, a)
            if out and out[-1]["t"] == "drive" and cont == side:
                out[-1]["steps"] += a["steps"]
                out[-1]["branches"] += a["branches"]
            else:
                out.append(a)
            cont = end
        else:
            out.append(a)
            cont = None
        rules.apply_action(level, st, a)
    return out


# ---------------------------------------------------------------- ölçütler

def pass_distances(level):
    """Geçiş kuralına uyan hücre uzaklığı: d[p][q] (her iki yöne başlanabilir)."""
    n = level.n
    INF = 10 ** 6
    out = []
    for src in range(n):
        dist = [INF] * n
        dist[src] = 0
        # durum: (hücre, çıkış yanı)
        from collections import deque
        dq = deque()
        seen = set()
        for s in (0, 1):
            dq.append((src, s, 0))
            seen.add((src, s))
        while dq:
            c, s, d = dq.popleft()
            for q in level.sides[c][s]:
                if dist[q] > d + 1:
                    dist[q] = d + 1
                ns = 1 - level.side_of(q, c)
                if (q, ns) not in seen:
                    seen.add((q, ns))
                    dq.append((q, ns, d + 1))
        out.append(dist)
    return out


def count_detours(level, actions):
    pd = pass_distances(level)
    tcol = {}
    for (c, col) in level.targets:
        tcol.setdefault(col, []).append(c)

    def wdist(st, vid):
        col = level.vcolor[vid]
        cells = tcol.get(col)
        if not cells:
            return None
        return min(pd[st.pos[vid]][c] for c in cells)

    st = rules.initial_state(level)
    detours = 0
    # Hamle sınırları: sürüş eylemleri (birleşmiş). Ayırma araç taşımaz.
    for a in actions:
        if a["t"] != "drive":
            rules.apply_action(level, st, a)
            continue
        before = {v: wdist(st, v) for v in level.vehicle_ids if level.vtype[v] == "wagon"}
        rules.apply_action(level, st, a)
        worse = False
        for v, d0 in before.items():
            if d0 is None:
                continue
            if wdist(st, v) > d0:
                worse = True
        if worse:
            detours += 1
    return detours


def optimal_dag(yard, start_key, dist, par, cap=10 ** 6):
    """Par uzunluğundaki farklı çözümler (araç dizilişleri dizisi olarak) ve katman genişlikleri.

    Döner (solutions_at_par (cap'li), on_path katman genişlikleri [projeksiyon sayısı])."""
    n = yard.n
    layers = [[] for _ in range(par + 1)]
    for k, d in dist.items():
        if d <= par:
            layers[d].append(k)
    on = [set() for _ in range(par + 1)]
    for k in layers[par]:
        if yard.solved(list(k[:n])):
            on[par].add(k)
    edges = [dict() for _ in range(par)]  # edges[i][proj_i] = set(proj_{i+1})
    for i in range(par - 1, -1, -1):
        # Kısa katarlı durumlar önce: ayırma çeşitleri onlara iner.
        lay = sorted(layers[i], key=lambda k: len(k) - n)
        target = on[i + 1]
        for k in lay:
            occ = list(k[:n])
            tr = list(k[n:])
            hit = False
            for side in (0, 1):
                stack = [(occ, tr, side)]
                seen = set()
                while stack:
                    o, t, s = stack.pop()
                    for _br, r in yard.drive_options(o, t, s):
                        nk = bytes(r[0]) + bytes(r[1])
                        dv = (nk, r[3])
                        if dv in seen:
                            continue
                        seen.add(dv)
                        if nk in target:
                            hit = True
                            edges[i].setdefault(k[:n], set()).add(nk[:n])
                        stack.append((r[0], r[1], r[3]))
            if not hit:
                for (_a, _b, t2) in yard.uncouple_options(occ, tr):
                    if k[:n] + bytes(t2) in on[i]:
                        hit = True
                        break
            if hit:
                on[i].add(k)
    if start_key not in on[0] and not any(start_key[:n] + bytes(t2) in on[0] for (_a, _b, t2) in yard.uncouple_options(list(start_key[:n]), list(start_key[n:]))):
        return 0, []
    ways = {start_key[:n]: 1}
    widths = []
    for i in range(par):
        nxt = {}
        for p, w in ways.items():
            for q in edges[i].get(p, ()):
                nxt[q] = min(cap, nxt.get(q, 0) + w)
        widths.append(len(ways))
        ways = nxt
    total = 0
    for p, w in ways.items():
        total = min(cap, total + w)
    return total, widths


def hardness(m):
    """Sürekli zorluk puanı (seviye sıralaması ve "komşu seviye ölçülebilir daha zor mu" denetimi için).

    Bileşenler ve gerekçe (docs/YARD.md §8):
      0.30 * par                       plan uzunluğu: ana eksen
      0.60 * detours                   sezgiye aykırı hamle: insanın "yanlış görünen doğru hamle"yi bulması zor
      0.80 * max(0, 3 - log10(plans))  dar kapı: az sayıda optimal plan = deneme-yanılmayla rastlanmaz
      0.50 * max(0, log10(states) - 2) arama uzayı: küçük uzayda her şeyi denemek kolay
    """
    par = m["par"]
    det = m["detours"]
    sol = max(1, m["solutions_at_par"])
    states = max(1, m["states"])
    return (0.30 * par + 0.60 * det + 0.80 * max(0.0, 3.0 - math.log10(sol)) +
            0.50 * max(0.0, math.log10(states) - 2.0))


# Sabit eşleme (veri kümesine bağlı değil: yeni seviyeler aynı ölçekte kalır).
# h=3.0 ~ par 1 öğretim seviyesi -> 1;  h=17 ~ par 30, 8 detour, 10 plan, 1e6 durum -> 10.
H_LO = 3.0
H_HI = 17.0


def difficulty_score(m):
    """1-10 zorluk: hardness'ın sabit doğrusal eşlemesi."""
    h = hardness(m)
    return int(max(1, min(10, round(1 + 9 * (h - H_LO) / (H_HI - H_LO)))))


def analyze(level, max_states=4000000):
    """Tam ölçüm (kesin, açık çizge üzerinde). Döner (metrics, çözüm eylemleri)."""
    import graph
    yard = Yard(level)
    st = rules.initial_state(level)
    start = yard.from_level_state(st)
    G = graph.Graph(yard, [start], max_states=max_states)
    if G.overflow:
        raise RuntimeError("durum uzayı sınırı aşıldı: %s" % level.id)
    D = G.dist_to_goal()
    par = D[2]
    if par >= graph.INF:
        raise RuntimeError("çözüm yok: %s" % level.id)
    res = solve_path(yard, start)
    moves, cells, path = res
    if moves != par:
        raise RuntimeError("Dijkstra %d != geriye arama %d" % (moves, par))
    actions = realize(level, path)
    actions = merge_drives(level, actions)
    actions = simplify_uncouples(level, actions, par)
    actions = merge_drives(level, actions)
    if rules.count_moves(level, actions) != par:
        raise RuntimeError("sayım tutmadı")
    hist = {}
    dead = 0
    for x in range(G.N):
        d = D[3 * x + 2]
        if d >= graph.INF:
            dead += 1
        else:
            hist[d] = hist.get(d, 0) + 1
    sols, widths = G.optimal_plans(D, 0)
    # İlk hamle seçenekleri: farklı ilk sürüş yönleri/uçları içinde optimal olanların oranı ölçüsü
    m = {
        "par": par,
        "min_cells": cells,
        "states": G.N,
        "dead_states": dead,
        "depth_max": max(hist) if hist else 0,
        "depth_hist": {str(k): hist[k] for k in sorted(hist)},
        "detours": count_detours(level, actions),
        "solutions_at_par": sols,
        "path_width": max(widths) if widths else 1,
        "uncouples": len([a for a in actions if a["t"] == "uncouple"]),
    }
    m["hardness"] = round(hardness(m), 2)
    m["difficulty"] = difficulty_score(m)
    return m, actions
