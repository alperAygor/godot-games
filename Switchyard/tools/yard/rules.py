"""Switchyard kural aynası (Python 3.9, yalnız standart kitaplık).

Bu dosya oyunun GDScript kurallarının (scripts/core/yard/) birebir aynasıdır. İkisi ayrışmasın diye
`vectors.py` buradan uygunluk vektörleri üretir; GDScript testi hepsini doğrular. Kural metni
docs/DESIGN.md §1-2, belirsizliklerin çözümü docs/YARD.md.

Neden tam (bağları tutan) model: oyuncunun gerçek durumu duran dizilerde bağ taşıyabilir; çözücünün
hızlı modeli (`fast.py`) bunları normalleştirir, bu dosya ise hakemdir.
"""

SIDE_A = 0
SIDE_B = 1

COLORS = ("red", "blue", "yellow", "green", "purple", "orange")
CELL_KINDS = ("plain", "spring", "gate", "plate")
# Araç türleri: mekanik eklenince buraya (deneyde "fragile" elendi, docs/YARD.md §6).
VEHICLE_KINDS = ("plain",)
VEHICLE_TYPES = ("loco", "wagon")

BLOCK_NONE = ""
BLOCK_BUFFER = "buffer"
BLOCK_SELF = "self"
BLOCK_FOUL = "foul"
BLOCK_GATE = "gate"
BLOCK_TRACTION = "traction"


class LevelError(ValueError):
    pass


def _as_int(value, what):
    # JSON (özellikle Godot'dan gelen) tamsayıları float verebilir; küsuratlıysa reddet.
    if isinstance(value, bool):
        raise LevelError("%s: sayı bekleniyordu" % what)
    if isinstance(value, int):
        return value
    if isinstance(value, float) and value == int(value):
        return int(value)
    raise LevelError("%s: tamsayı bekleniyordu (%r)" % (what, value))


class Level(object):
    """Doğrulanmış, değişmez seviye."""

    def __init__(self, data):
        if not isinstance(data, dict):
            raise LevelError("seviye sözlük olmalı")
        self.id = str(data.get("id", ""))
        self.world = _as_int(data.get("world", 1), "world")
        self.par = _as_int(data.get("par", 0), "par")
        raw_cells = data.get("cells")
        if not isinstance(raw_cells, list) or not raw_cells:
            raise LevelError("cells boş olamaz")
        n = len(raw_cells)
        self.n = n
        self.sides = []  # sides[c] = (tuple a, tuple b)
        self.pos = []
        self.kind = []
        self.spring = []
        for i, c in enumerate(raw_cells):
            if not isinstance(c, dict):
                raise LevelError("hücre %d sözlük değil" % i)
            sides = []
            for key in ("a", "b"):
                lst = c.get(key, [])
                if not isinstance(lst, list) or len(lst) > 2:
                    raise LevelError("hücre %d yan %s: 0-2 komşu olmalı" % (i, key))
                vals = tuple(_as_int(v, "hücre %d komşu" % i) for v in lst)
                for v in vals:
                    if v < 0 or v >= n:
                        raise LevelError("hücre %d: komşu kimliği aralık dışı (%d)" % (i, v))
                    if v == i:
                        raise LevelError("hücre %d kendine komşu" % i)
                sides.append(vals)
            allnb = sides[0] + sides[1]
            if len(set(allnb)) != len(allnb):
                raise LevelError("hücre %d: aynı komşu iki kez" % i)
            self.sides.append((sides[0], sides[1]))
            x = c.get("x", 0)
            y = c.get("y", 0)
            if not isinstance(x, (int, float)) or not isinstance(y, (int, float)) or isinstance(x, bool):
                raise LevelError("hücre %d: x/y sayı olmalı" % i)
            self.pos.append((float(x), float(y)))
            kind = str(c.get("kind", "plain"))
            if kind not in CELL_KINDS:
                raise LevelError("hücre %d: bilinmeyen tür %s" % (i, kind))
            self.kind.append(kind)
            spring = -1
            if kind == "spring":
                spring = _as_int(c.get("spring", 0), "spring")
                branching = [s for s in (0, 1) if len(self.sides[i][s]) == 2]
                if len(branching) != 1 or spring not in (0, 1):
                    raise LevelError("hücre %d: yaylı makas tam bir dallanan yan ister" % i)
            self.spring.append(spring)
        # Simetri: p, q'yu sayıyorsa q da p'yi sayar.
        self._side_of = {}
        for p in range(n):
            for s in (0, 1):
                for q in self.sides[p][s]:
                    self._side_of[(p, q)] = s
        for (p, q) in list(self._side_of.keys()):
            if (q, p) not in self._side_of:
                raise LevelError("komşuluk simetrik değil: %d -> %d" % (p, q))
        # Araçlar
        raw_v = data.get("vehicles")
        if not isinstance(raw_v, list) or not raw_v:
            raise LevelError("vehicles boş olamaz")
        self.vehicle_ids = []
        self.vtype = {}
        self.vcolor = {}
        self.vkind = {}
        self.start_pos = {}
        self.power = 0
        used = set()
        loco = None
        for v in raw_v:
            if not isinstance(v, dict):
                raise LevelError("araç sözlük değil")
            vid = str(v.get("id", ""))
            if vid == "" or vid in self.vtype:
                raise LevelError("araç kimliği boş ya da yinelenmiş: %r" % vid)
            vt = str(v.get("type", ""))
            if vt not in VEHICLE_TYPES:
                raise LevelError("araç %s: tür %s" % (vid, vt))
            color = str(v.get("color", "loco" if vt == "loco" else ""))
            if vt == "wagon" and color not in COLORS:
                raise LevelError("vagon %s: renk %s" % (vid, color))
            if vt == "loco":
                if loco is not None:
                    raise LevelError("birden çok lokomotif")
                loco = vid
                color = "loco"
                self.power = _as_int(v.get("power", 0), "power")
                if self.power < 0:
                    raise LevelError("power negatif")
            vk = str(v.get("kind", "plain"))
            if vk not in VEHICLE_KINDS or (vt == "loco" and vk != "plain"):
                raise LevelError("araç %s: tür %s" % (vid, vk))
            cell = _as_int(v.get("cell", -1), "araç hücresi")
            if cell < 0 or cell >= n:
                raise LevelError("araç %s: hücre aralık dışı" % vid)
            if cell in used:
                raise LevelError("iki araç aynı hücrede (%d)" % cell)
            used.add(cell)
            self.vehicle_ids.append(vid)
            self.vtype[vid] = vt
            self.vcolor[vid] = color
            self.vkind[vid] = vk
            self.start_pos[vid] = cell
        if loco is None:
            raise LevelError("lokomotif yok")
        self.loco = loco
        # Bağlar
        raw_l = data.get("links", [])
        if not isinstance(raw_l, list):
            raise LevelError("links liste olmalı")
        links = set()
        for pair in raw_l:
            if not isinstance(pair, list) or len(pair) != 2:
                raise LevelError("bağ iki kimlik olmalı")
            a, b = str(pair[0]), str(pair[1])
            if a not in self.vtype or b not in self.vtype or a == b:
                raise LevelError("bağ geçersiz: %s-%s" % (a, b))
            if (self.start_pos[a], self.start_pos[b]) not in self._side_of:
                raise LevelError("bağlı araçlar komşu değil: %s-%s" % (a, b))
            key = frozenset((a, b))
            if key in links:
                raise LevelError("bağ yinelenmiş: %s-%s" % (a, b))
            links.add(key)
        per_side = {}
        for key in links:
            a, b = tuple(key)
            for x, y in ((a, b), (b, a)):
                s = self._side_of[(self.start_pos[x], self.start_pos[y])]
                if (x, s) in per_side:
                    raise LevelError("araç %s: bir yanda iki bağ" % x)
                per_side[(x, s)] = y
        # Zincir şartı halkayı da dışlar.
        parent = {}

        def find(x):
            while parent.get(x, x) != x:
                x = parent.get(x, x)
            return x

        for key in links:
            a, b = tuple(key)
            ra, rb = find(a), find(b)
            if ra == rb:
                raise LevelError("bağlar halka oluşturuyor")
            parent[ra] = rb
        self.start_links = links
        # Hedefler
        raw_t = data.get("targets")
        if not isinstance(raw_t, list) or not raw_t:
            raise LevelError("targets boş olamaz")
        self.targets = []
        tcells = set()
        for t in raw_t:
            if not isinstance(t, dict):
                raise LevelError("hedef sözlük değil")
            c = _as_int(t.get("cell", -1), "hedef hücresi")
            col = str(t.get("color", ""))
            if c < 0 or c >= n or c in tcells:
                raise LevelError("hedef hücresi geçersiz/yinelenmiş: %d" % c)
            if col not in COLORS and col != "loco":
                raise LevelError("hedef rengi: %s" % col)
            tcells.add(c)
            self.targets.append((c, col))
        self.solution = data.get("solution", [])
        self.metrics = data.get("metrics", {})

    def neighbors(self, cell, side):
        return self.sides[cell][side]

    def side_of(self, p, q):
        """p hücresinin q'ya bakan yanı (komşu değilse KeyError)."""
        return self._side_of[(p, q)]

    def adjacent(self, p, q):
        return (p, q) in self._side_of


class State(object):
    """Değişken durum: araç konumları + bağlar."""

    __slots__ = ("pos", "at", "links")

    def __init__(self, pos, links):
        self.pos = dict(pos)
        self.at = {}
        for vid, c in self.pos.items():
            self.at[c] = vid
        self.links = set(links)

    def copy(self):
        return State(self.pos, self.links)

    def is_linked(self, a, b):
        return frozenset((a, b)) in self.links

    def key(self):
        parts = ["%s@%d" % (v, self.pos[v]) for v in sorted(self.pos)]
        lk = sorted("-".join(sorted(k)) for k in self.links)
        return ";".join(parts) + "|" + ",".join(lk)

    def to_dict(self):
        return {
            "pos": dict(self.pos),
            "links": sorted(sorted(k) for k in self.links),
        }


def initial_state(level):
    return State(level.start_pos, level.start_links)


def linked_neighbor(level, state, vid, side):
    """vid'in kendi hücresinin `side` yanında bağlı olduğu araç ya da None."""
    c = state.pos[vid]
    for q in level.sides[c][side]:
        u = state.at.get(q)
        if u is not None and frozenset((vid, u)) in state.links:
            return u
    return None


def walk(level, state, vid, side):
    """vid'den `side` yönünde bağlar boyunca giden araçlar (vid hariç, uzaklaşan sırayla)."""
    out = []
    cur = vid
    s = side
    while True:
        nxt = linked_neighbor(level, state, cur, s)
        if nxt is None:
            break
        out.append(nxt)
        s = 1 - level.side_of(state.pos[nxt], state.pos[cur])
        cur = nxt
    return out


def train(level, state):
    """Katar: a-ucundan b-ucuna (lokomotif hücresinin yanlarına göre)."""
    L = level.loco
    left = walk(level, state, L, SIDE_A)
    right = walk(level, state, L, SIDE_B)
    return list(reversed(left)) + [L] + right


def gates_open(level, state):
    has_gate = False
    for c in range(level.n):
        if level.kind[c] == "plate" and c in state.at:
            return True
        if level.kind[c] == "gate":
            has_gate = True
    return not has_gate


class StepResult(object):
    __slots__ = ("moved", "coupled", "blocked", "moves")

    def __init__(self):
        self.moved = False
        self.coupled = []
        self.blocked = BLOCK_NONE
        self.moves = {}

    def effective(self):
        return self.moved or bool(self.coupled)

    def to_dict(self):
        return {
            "moved": self.moved,
            "coupled": list(self.coupled),
            "blocked": self.blocked,
            "moves": {k: list(v) for k, v in self.moves.items()},
        }


def _head(level, state, side):
    """(baş araç, başın serbest yanı, katarın sürüş yönündeki kısmı [L..baş])."""
    L = level.loco
    ahead = walk(level, state, L, side)
    if not ahead:
        return L, side, [L]
    head = ahead[-1]
    prev = ahead[-2] if len(ahead) > 1 else L
    free = 1 - level.side_of(state.pos[head], state.pos[prev])
    return head, free, [L] + ahead


def step(level, state, side, branch):
    """Bir hücre sürüş; durumu yerinde değiştirir. Kurallar: DESIGN §2, belirsizlikler YARD.md §2.

    Engellenen adımda o ana kadarki bağlanmalar kalır (tampona dayalı vagona bağlanabilmek için).
    Bir adımda en çok bir dal kararı verilir: yalnız ilk baş dal seçebilir; bağlanmadan sonra yeni baş
    (yaysız) bir makasın dal yanına bakıyorsa adım bağlanmayla biter (oyuncu sonraki adımda seçer).
    """
    res = StepResult()
    if side not in (0, 1):
        res.blocked = BLOCK_BUFFER
        return res
    open_gates = gates_open(level, state)
    head, free, _part = _head(level, state, side)
    in_train = set(train(level, state))
    first = True
    while True:
        hc = state.pos[head]
        nb = level.sides[hc][free]
        if len(nb) == 0:
            res.blocked = BLOCK_BUFFER
            return res
        if len(nb) == 2:
            if level.kind[hc] == "spring":
                t = nb[level.spring[hc]]
            elif not first:
                return res  # bağlanma sonrası dal kararı: adım burada biter
            else:
                t = nb[branch] if branch in (0, 1) else nb[0]
        else:
            t = nb[0]
        first = False
        v = state.at.get(t)
        if v is None:
            break
        if v in in_train:
            res.blocked = BLOCK_SELF
            return res
        s_v = level.side_of(t, hc)
        if linked_neighbor(level, state, v, s_v) is not None:
            res.blocked = BLOCK_FOUL
            return res
        chain = [v] + walk(level, state, v, 1 - s_v)
        state.links.add(frozenset((head, v)))
        for u in chain:
            in_train.add(u)
            res.coupled.append(u)
        prev = chain[-2] if len(chain) > 1 else head
        head = chain[-1]
        free = 1 - level.side_of(state.pos[head], state.pos[prev])
    # t boş: mekanik denetimleri, sonra yılan hareketi.
    if level.kind[t] == "gate" and not open_gates:
        res.blocked = BLOCK_GATE
        return res
    order = list(reversed(train(level, state))) if side == SIDE_A else train(level, state)
    # order: kuyruk ... baş (sürüş yönünde)
    if level.power > 0 and len(order) - 1 > level.power:
        res.blocked = BLOCK_TRACTION
        return res
    old = [state.pos[u] for u in order]
    new = old[1:] + [t]
    for u in order:
        del state.at[state.pos[u]]
    for u, c_old, c_new in zip(order, old, new):
        state.pos[u] = c_new
        state.at[c_new] = u
        res.moves[u] = [c_old, c_new]
    res.moved = True
    return res


class Probe(object):
    __slots__ = ("possible", "needs_branch", "branch_cells")

    def __init__(self):
        self.possible = False
        self.needs_branch = False
        self.branch_cells = []

    def to_dict(self):
        return {"possible": self.possible, "needs_branch": self.needs_branch,
                "branch_cells": list(self.branch_cells)}


def probe(level, state, side):
    p = Probe()
    if side not in (0, 1):
        return p
    head, free, _ = _head(level, state, side)
    hc = state.pos[head]
    nb = level.sides[hc][free]
    if len(nb) == 2 and level.kind[hc] != "spring":
        p.needs_branch = True
        p.branch_cells = list(nb)
        for br in (0, 1):
            if step(level, state.copy(), side, br).effective():
                p.possible = True
    else:
        p.possible = step(level, state.copy(), side, 0).effective()
    return p


def uncouple(level, state, a, b):
    key = frozenset((a, b))
    if key in state.links:
        state.links.discard(key)
        return True
    return False


def is_solved(level, state):
    for (c, col) in level.targets:
        v = state.at.get(c)
        if v is None:
            return False
        if col == "loco":
            if level.vtype[v] != "loco":
                return False
        elif level.vtype[v] != "wagon" or level.vcolor[v] != col:
            return False
    return True


def continue_side(level, old_cell, new_cell, side):
    """Lokomotif old_cell'den new_cell'e geçtiyse aynı yönü sürdüren yan; geçmediyse `side`."""
    if old_cell == new_cell:
        return side
    return 1 - level.side_of(new_cell, old_cell)


def apply_action(level, state, action):
    """Çözüm eylemini atomik uygular: başarısızsa durum değişmez. Başarı bool döner."""
    work = state.copy()
    t = action.get("t")
    if t == "uncouple":
        between = action.get("between", [])
        if len(between) != 2:
            return False
        if not uncouple(level, work, str(between[0]), str(between[1])):
            return False
    elif t == "drive":
        side = 0 if action.get("side") == "a" else 1 if action.get("side") == "b" else -1
        if side < 0:
            return False
        steps = _as_int(action.get("steps", 0), "steps")
        branches = [_as_int(b, "branch") for b in action.get("branches", [])]
        bi = 0
        if steps < 1:
            return False
        for _ in range(steps):
            pr = probe(level, work, side)
            br = 0
            if pr.needs_branch:
                br = branches[bi] if bi < len(branches) else 0
                bi += 1
            old = work.pos[level.loco]
            r = step(level, work, side, br)
            if not r.effective():
                return False
            side = continue_side(level, old, work.pos[level.loco], side)
    else:
        return False
    state.pos = work.pos
    state.at = work.at
    state.links = work.links
    return True


def drive_end_side(level, state_before, action):
    """Bir sürüşün bitişinde aynı yönü sürdüren lokomotif yanı (hamle sayımı için)."""
    work = state_before.copy()
    side = 0 if action.get("side") == "a" else 1
    branches = list(action.get("branches", []))
    bi = 0
    for _ in range(int(action.get("steps", 0))):
        pr = probe(level, work, side)
        br = 0
        if pr.needs_branch:
            br = int(branches[bi]) if bi < len(branches) else 0
            bi += 1
        old = work.pos[level.loco]
        step(level, work, side, br)
        side = continue_side(level, old, work.pos[level.loco], side)
    return side


def count_moves(level, actions):
    """Sayım kuralı: aynı yönde kesintisiz sürüş = 1 hamle; yön değişimi ya da ayırma yeni hamle başlatır."""
    st = initial_state(level)
    moves = 0
    cont = None  # son sürüşün devam yanı; ayırmada None
    for a in actions:
        if a.get("t") == "drive":
            side = 0 if a.get("side") == "a" else 1
            if cont is None or side != cont:
                moves += 1
            cont = drive_end_side(level, st, a)
            if not apply_action(level, st, a):
                return -1
        else:
            if not apply_action(level, st, a):
                return -1
            cont = None
    return moves
