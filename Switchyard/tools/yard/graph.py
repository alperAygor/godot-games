"""Açık durum çizgesi ve KESİN hedefe-uzaklık.

Neden: hamleler tam tersinir değil (bağlanmak için itmek gerekir, ayırma bedava). Hedeften ileri tarayıp
bulunan uzaklık gerçek par'dan 0-4 hamle sapıyordu (ölçüm: docs/YARD.md §4). Bu yüzden erişilebilir bütün
durumlar tek adım kenarlarıyla diziye yazılır, kenarlar ters çevrilir ve hedeften geriye 0-1 BFS yapılır.

Düğüm = (durum, devam yanı c): c=0/1 son sürüşün devam ettiği lokomotif yanı, c=2 "yeni hamle".
Kenar etiketleri: adım = side*2 + cont (0..3), ayırma = 4.
"""

from array import array
from collections import deque

INF = 1 << 30
UNCOUPLE = 4


class Graph(object):
    def __init__(self, yard, seeds, max_states=None):
        self.yard = yard
        n = yard.n
        index = {}
        keys = []
        for s in seeds:
            if s not in index:
                index[s] = len(keys)
                keys.append(s)
        fstart = array("i")
        fdst = array("i")
        flab = array("b")
        i = 0
        self.overflow = False
        while i < len(keys):
            k = keys[i]
            occ = list(k[:n])
            tr = list(k[n:])
            fstart.append(len(fdst))
            for side in (0, 1):
                for _br, r in yard.drive_options(occ, tr, side):
                    nk = bytes(r[0]) + bytes(r[1])
                    j = index.get(nk)
                    if j is None:
                        j = len(keys)
                        index[nk] = j
                        keys.append(nk)
                    fdst.append(j)
                    flab.append(side * 2 + r[3])
            for (_a, _b, t2) in yard.uncouple_options(occ, tr):
                nk = k[:n] + bytes(t2)
                j = index.get(nk)
                if j is None:
                    j = len(keys)
                    index[nk] = j
                    keys.append(nk)
                fdst.append(j)
                flab.append(UNCOUPLE)
            i += 1
            if max_states is not None and len(keys) > max_states:
                self.overflow = True
                break
        while len(fstart) < len(keys) + 1:
            fstart.append(len(fdst))
        self.keys = keys
        self.index = index
        self.fstart = fstart
        self.fdst = fdst
        self.flab = flab
        self.N = len(keys)
        self._rev = None

    def _build_reverse(self):
        N = self.N
        cnt = array("i", [0]) * (N + 1)
        fdst = self.fdst
        for j in fdst:
            cnt[j + 1] += 1
        for x in range(N):
            cnt[x + 1] += cnt[x]
        rstart = array("i", cnt)
        pos = array("i", cnt)
        rsrc = array("i", [0]) * len(fdst)
        rlab = array("b", [0]) * len(fdst)
        fstart = self.fstart
        flab = self.flab
        for x in range(N):
            for e in range(fstart[x], fstart[x + 1]):
                j = fdst[e]
                p = pos[j]
                rsrc[p] = x
                rlab[p] = flab[e]
                pos[j] = p + 1
        self._rev = (rstart, rsrc, rlab)

    def goal_indices(self):
        n = self.yard.n
        out = []
        for i, k in enumerate(self.keys):
            if self.yard.solved(list(k[:n])):
                out.append(i)
        return out

    def dist_to_goal(self, goals=None):
        """D[3x+c]: (x, c) düğümünden hedefe en az hamle. Kesin (0-1 BFS ters kenarlarda)."""
        if self._rev is None:
            self._build_reverse()
        rstart, rsrc, rlab = self._rev
        if goals is None:
            goals = self.goal_indices()
        N = self.N
        D = array("i", [INF]) * (3 * N)
        done = bytearray(3 * N)
        dq = deque()
        for g in goals:
            for c in (0, 1, 2):
                D[3 * g + c] = 0
                dq.append(3 * g + c)
        while dq:
            node = dq.popleft()
            if done[node]:
                continue
            done[node] = 1
            d = D[node]
            y = node // 3
            c = node - 3 * y
            for e in range(rstart[y], rstart[y + 1]):
                x = rsrc[e]
                lab = rlab[e]
                b = 3 * x
                if lab == UNCOUPLE:
                    if c != 2:
                        continue
                    for cx in (0, 1, 2):
                        if D[b + cx] > d:
                            D[b + cx] = d
                            dq.appendleft(b + cx)
                else:
                    if (lab & 1) != c:
                        continue
                    s = lab >> 1
                    if D[b + s] > d:
                        D[b + s] = d
                        dq.appendleft(b + s)
                    d1 = d + 1
                    o = b + (1 - s)
                    if D[o] > d1:
                        D[o] = d1
                        dq.append(o)
                    if D[b + 2] > d1:
                        D[b + 2] = d1
                        dq.append(b + 2)
        return D

    def optimal_plans(self, D, start, cap=100000):
        """Par uzunluğundaki farklı planlar: hamle sonlarındaki araç dizilişleri dizisi (sayım cap'li).

        Ayrıca her hamle seviyesinde optimal koridorun genişliği (farklı dizilişler) döner."""
        n = self.yard.n
        par = D[3 * start + 2]
        if par >= INF:
            return 0, []
        fstart, fdst, flab = self.fstart, self.fdst, self.flab
        keys = self.keys
        # Sınır durumu: D(x, yeni)=k. Hamle: ayırmalar (0) sonra bir yönde adımlar; her ara durum y'de durmak
        # optimalse (D(y,yeni) == k-1) hamle orada bitebilir.
        def proj(k):
            # Yalnız vagon dizilişi: lokomotifin nerede durduğu ayrı plan sayılmaz.
            return bytes(0 if b == 1 else b for b in k[:n])

        level = {start}
        ways = {proj(keys[start]): 1}
        widths = []
        for k in range(par, 0, -1):
            # ayırma kapanışı (optimal kalanlar)
            closure = set(level)
            stack = list(level)
            while stack:
                x = stack.pop()
                for e in range(fstart[x], fstart[x + 1]):
                    if flab[e] == UNCOUPLE:
                        y = fdst[e]
                        if D[3 * y + 2] == k and y not in closure:
                            closure.add(y)
                            stack.append(y)
            nxt = set()
            edges = {}
            for x in closure:
                px = proj(keys[x])
                for side in (0, 1):
                    # adım zinciri, devam düğümleri D(y,c) == k-1 olmalı
                    seen = set()
                    stack = []
                    for e in range(fstart[x], fstart[x + 1]):
                        lab = flab[e]
                        if lab != UNCOUPLE and (lab >> 1) == side:
                            y = fdst[e]
                            c = lab & 1
                            if D[3 * y + c] == k - 1 and (y, c) not in seen:
                                seen.add((y, c))
                                stack.append((y, c))
                    while stack:
                        y, c = stack.pop()
                        if D[3 * y + 2] == k - 1:
                            nxt.add(y)
                            edges.setdefault(px, set()).add(proj(keys[y]))
                        for e in range(fstart[y], fstart[y + 1]):
                            lab = flab[e]
                            if lab != UNCOUPLE and (lab >> 1) == c:
                                z = fdst[e]
                                cz = lab & 1
                                if D[3 * z + cz] == k - 1 and (z, cz) not in seen:
                                    seen.add((z, cz))
                                    stack.append((z, cz))
            new_ways = {}
            for p, w in ways.items():
                for q in edges.get(p, ()):
                    new_ways[q] = min(cap, new_ways.get(q, 0) + w)
            widths.append(len(ways))
            ways = new_ways
            level = nxt
        total = 0
        for p, w in ways.items():
            total = min(cap, total + w)
        return total, widths
