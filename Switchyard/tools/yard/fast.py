"""Çözücü ve üreteç için hızlı, renk-kanonik durum modeli.

Durum anahtarı (bytes): n bayt doluluk (0 boş, 1 lokomotif, vagon = 2 + 2*renk + kırılgan) ve ardından katarın
hücreleri (lokomotif hücresinin a-ucundan b-ucuna). Aynı renkli vagonlar böylece kendiliğinden birleşir.

NORMALLEŞTİRME (neden doğru, YARD.md §3): katara bağlı olmayan araçlar bağsız sayılır. Ayırma bedavadır ve
duran dizilerdeki bağlar hiçbir hamleyi ucuzlatmaz (itince zaten bağlanırlar), bu yüzden en az hamle değişmez.
Gerçek kurallarla (`rules.py`) yeniden oynatma `solver.realize()` içinde denetlenir.
"""

from rules import COLORS, SIDE_A, SIDE_B

LOCO = 1


def wagon_code(color, fragile):
    return 2 + 2 * COLORS.index(color) + (1 if fragile else 0)


def code_color(code):
    if code == LOCO:
        return "loco"
    return COLORS[(code - 2) // 2]


def code_fragile(code):
    return code >= 2 and (code - 2) % 2 == 1


class Yard(object):
    """Seviyenin değişmez kısmı, hızlı erişim için düz listeler."""

    def __init__(self, level):
        self.level = level
        self.n = level.n
        self.sides = [(tuple(a), tuple(b)) for (a, b) in level.sides]
        self.side_of = [dict() for _ in range(self.n)]
        for p in range(self.n):
            for s in (0, 1):
                for q in self.sides[p][s]:
                    self.side_of[p][q] = s
        self.spring = list(level.spring)
        self.is_spring = [k == "spring" for k in level.kind]
        self.gate = [k == "gate" for k in level.kind]
        self.plates = [c for c in range(self.n) if level.kind[c] == "plate"]
        self.has_gate = any(self.gate)
        self.power = level.power
        tg = []
        for (c, col) in level.targets:
            tg.append((c, LOCO if col == "loco" else None, col))
        self.targets = tg
        # Hedef denetimi: hücre -> kabul edilen renk adı
        self.target_color = {c: col for (c, col) in level.targets}

    # --- durum kodlama ---
    def encode(self, occ, train):
        return bytes(occ) + bytes(train)

    def decode(self, key):
        n = self.n
        return list(key[:n]), list(key[n:])

    def from_level_state(self, state):
        """rules.State -> anahtar. Duran bağlar normalleştirilir (atılır)."""
        import rules
        lv = self.level
        occ = [0] * self.n
        for vid, c in state.pos.items():
            if lv.vtype[vid] == "loco":
                occ[c] = LOCO
            else:
                occ[c] = wagon_code(lv.vcolor[vid], lv.vkind[vid] == "fragile")
        tr = [state.pos[v] for v in rules.train(lv, state)]
        return self.encode(occ, tr)

    def loco_cell(self, occ):
        return occ.index(LOCO)

    def solved(self, occ):
        for (c, col) in self.target_color.items():
            code = occ[c]
            if code == 0:
                return False
            if col == "loco":
                if code != LOCO:
                    return False
            elif code == LOCO or code_color(code) != col:
                return False
        return True

    def gates_open(self, occ):
        if not self.has_gate:
            return True
        for c in self.plates:
            if occ[c]:
                return True
        return False

    def orient(self, cells, li):
        """Katar listesini lokomotif hücresinin a-ucundan başlayacak biçimde çevirir."""
        if len(cells) == 1:
            return cells
        lc = cells[li]
        if li > 0:
            if self.side_of[lc][cells[li - 1]] == SIDE_A:
                return cells
            return cells[::-1]
        if self.side_of[lc][cells[1]] == SIDE_B:
            return cells
        return cells[::-1]

    def head_info(self, occ, train, side):
        """(baş hücresi, serbest yan, sürüş yönündeki dizi kuyruk..baş, lokomotifin dizideki yeri)."""
        lc = occ.index(LOCO)
        li = train.index(lc)
        if side == SIDE_B:
            seq = list(train)
            lpos = li
        else:
            seq = train[::-1]
            lpos = len(train) - 1 - li
        hc = seq[-1]
        if lpos == len(seq) - 1:
            free = side
        else:
            free = 1 - self.side_of[hc][seq[-2]]
        return hc, free, seq, lpos

    def needs_branch(self, occ, train, side):
        hc, free, _seq, _l = self.head_info(occ, train, side)
        return len(self.sides[hc][free]) == 2 and not self.is_spring[hc]

    def step(self, occ, train, side, branch):
        """Kural aynası (rules.step, normalleştirilmiş). Döner: (etkili, yeni occ, yeni katar, hücre adımı,
        lokomotifin yeni devam yanı) ya da etkisizse None."""
        hc, free, seq, lpos = self.head_info(occ, train, side)
        tset = set(seq)
        first = True
        coupled = False
        sides = self.sides
        while True:
            nb = sides[hc][free]
            if not nb:
                return self._couple_only(occ, seq, lpos, side) if coupled else None
            if len(nb) == 2:
                if self.is_spring[hc]:
                    t = nb[self.spring[hc]]
                elif not first:
                    return self._couple_only(occ, seq, lpos, side)
                else:
                    t = nb[branch] if branch in (0, 1) else nb[0]
            else:
                t = nb[0]
            first = False
            if occ[t] == 0:
                break
            if t in tset:
                return self._couple_only(occ, seq, lpos, side) if coupled else None
            # Duran araç (normalleştirilmiş: bağsız) bağlanır.
            seq.append(t)
            tset.add(t)
            coupled = True
            free = 1 - self.side_of[t][hc]
            hc = t
        if self.gate[t] and not self.gates_open(occ):
            return self._couple_only(occ, seq, lpos, side) if coupled else None
        if self.power > 0 and len(seq) - 1 > self.power:
            return self._couple_only(occ, seq, lpos, side) if coupled else None
        codes = [occ[c] for c in seq]
        new_occ = list(occ)
        for c in seq:
            new_occ[c] = 0
        new_cells = seq[1:]
        new_cells.append(t)
        for code, c in zip(codes, new_cells):
            new_occ[c] = code
        old_l = seq[lpos]
        new_l = new_cells[lpos]
        cont = 1 - self.side_of[new_l][old_l]
        # Yeni katar sırası: lokomotif yeni hücresinin a-ucundan.
        tr = self.orient(new_cells, lpos)
        return (new_occ, tr, 1, cont)

    def _couple_only(self, occ, seq, lpos, side):
        tr = self.orient(list(seq), lpos)
        return (list(occ), tr, 0, side)

    def drive_options(self, occ, train, side):
        """Bir adımın dal seçenekleri: [(branch, sonuç)]."""
        if self.needs_branch(occ, train, side):
            out = []
            for br in (0, 1):
                r = self.step(occ, train, side, br)
                if r is not None:
                    out.append((br, r))
            return out
        r = self.step(occ, train, side, 0)
        return [(0, r)] if r is not None else []

    def uncouple_options(self, occ, train):
        """Katarın lokomotifi içeren her alt aralığı (tam katar hariç): [(i, j, yeni katar)]."""
        lc = occ.index(LOCO)
        li = train.index(lc)
        m = len(train)
        out = []
        for i in range(0, li + 1):
            for j in range(li, m):
                if i == 0 and j == m - 1:
                    continue
                out.append((i, j, train[i:j + 1]))
        return out

    def successors_single(self, key):
        """Tek adım ve ayırma komşuları (durum sayımı için)."""
        occ, train = self.decode(key)
        out = []
        for side in (0, 1):
            for _br, r in self.drive_options(occ, train, side):
                out.append(self.encode(r[0], r[1]))
        for (_i, _j, tr) in self.uncouple_options(occ, train):
            out.append(self.encode(occ, tr))
        return out
