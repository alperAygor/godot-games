"""rules.py birim testleri: DESIGN §2 hamle kuralları ve YARD.md §2 belirsizlik çözümleri."""

import os
import random
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import layout  # noqa: E402
import rules  # noqa: E402
from rules import SIDE_A, SIDE_B  # noqa: E402


def line_cells(n):
    """0..n-1 düz hat; a yanı küçük kimliğe bakar."""
    cells = []
    for i in range(n):
        cells.append({"x": 0, "y": i, "a": [i - 1] if i > 0 else [], "b": [i + 1] if i < n - 1 else []})
    return cells


def lvl(cells, vehicles, links=None, targets=None, **kw):
    d = {"id": "t", "world": 1, "cells": cells, "vehicles": vehicles, "links": links or [],
         "targets": [{"cell": 0, "color": "red"}] if targets is None else targets}
    d.update(kw)
    return rules.Level(d)


def loco(cell, **kw):
    v = {"id": "L", "type": "loco", "cell": cell}
    v.update(kw)
    return v


def wagon(vid, cell, color="red", **kw):
    v = {"id": vid, "type": "wagon", "color": color, "cell": cell}
    v.update(kw)
    return v


def switch_yard():
    """Makas: 0-1-2 gövde, 2'nin b yanında dallar 3 (düz) ve 5 (sapan), 3-4 ve 5-6 devam."""
    tracks = ["3,1 3,2 3,3 3,4 3,5", "3,3 4,4 4,5"]
    return layout.build_cells(tracks)


class TestValidation(unittest.TestCase):
    def test_ok(self):
        lvl(line_cells(3), [loco(0), wagon("r1", 2)])

    def bad(self, **kw):
        with self.assertRaises(rules.LevelError):
            base = {"cells": line_cells(4), "vehicles": [loco(0), wagon("r1", 1), wagon("b1", 2, "blue")]}
            base.update(kw)
            lvl(**base)

    def test_asymmetric(self):
        c = line_cells(4)
        c[1]["b"] = [2]
        c[2]["a"] = []
        self.bad(cells=c)

    def test_three_on_side(self):
        c = line_cells(5)
        c[0]["b"] = [1, 2, 3]
        self.bad(cells=c)

    def test_two_vehicles_one_cell(self):
        self.bad(vehicles=[loco(0), wagon("r1", 0)])

    def test_link_not_adjacent(self):
        self.bad(vehicles=[loco(0), wagon("r1", 2)], links=[["L", "r1"]])

    def test_two_links_one_side(self):
        cells = switch_yard()
        # 2 (3,3) makas: b yanında 3 ve 5. İki dal aracının ikisi de 2'deki araca bağlı olamaz.
        ix = lambda x, y: layout.cell_index(cells, x, y)
        with self.assertRaises(rules.LevelError):
            lvl(cells, [loco(ix(3, 3)), wagon("r1", ix(3, 4)), wagon("b1", ix(4, 4), "blue")],
                links=[["L", "r1"], ["L", "b1"]])

    def test_ring(self):
        tracks = ["2,2 3,2 4,3 4,4 3,5 2,5 1,4 1,3 2,2"]
        cells = layout.build_cells(tracks)
        vs = [loco(0)] + [wagon("w%d" % i, i) for i in range(1, 8)]
        links = [[vs[i]["id"], vs[(i + 1) % 8]["id"]] for i in range(8)]
        # Halka hattında her araç komşusuna bağlı: zincir değil halka.
        ring = []
        for i in range(8):
            ring.append(i)
        cell_of = {}
        for v in vs:
            cell_of[v["id"]] = v["cell"]
        # Araçları hat sırasına diz.
        order = [0]
        while len(order) < 8:
            last = order[-1]
            c = cells[last]
            for q in c["a"] + c["b"]:
                if q not in order:
                    order.append(q)
                    break
        vs = [loco(order[0])] + [wagon("w%d" % i, order[i]) for i in range(1, 8)]
        links = [[vs[i]["id"], vs[(i + 1) % 8]["id"]] for i in range(8)]
        with self.assertRaises(rules.LevelError):
            lvl(cells, vs, links=links)

    def test_no_loco(self):
        self.bad(vehicles=[wagon("r1", 1)])

    def test_bad_color(self):
        self.bad(vehicles=[loco(0), wagon("r1", 1, "pink")])

    def test_self_neighbor(self):
        c = line_cells(3)
        c[1]["b"] = [1]
        self.bad(cells=c)

    def test_no_targets(self):
        self.bad(targets=[])

    def test_float_ints_accepted(self):
        c = line_cells(3)
        c[1]["a"] = [0.0]
        lvl(c, [loco(0.0), wagon("r1", 2.0)])


class TestDrive(unittest.TestCase):
    def test_loco_alone_moves_and_buffer(self):
        L = lvl(line_cells(3), [loco(1), wagon("r1", 0)], targets=[{"cell": 2, "color": "red"}])
        st = rules.initial_state(L)
        r = rules.step(L, st, SIDE_B, 0)
        self.assertTrue(r.moved)
        self.assertEqual(st.pos["L"], 2)
        self.assertEqual(r.moves, {"L": [1, 2]})
        r = rules.step(L, st, SIDE_B, 0)
        self.assertFalse(r.moved)
        self.assertEqual(r.blocked, "buffer")

    def test_push_couples_and_moves(self):
        L = lvl(line_cells(5), [loco(0), wagon("r1", 1), wagon("b1", 2, "blue")])
        st = rules.initial_state(L)
        r = rules.step(L, st, SIDE_B, 0)
        self.assertTrue(r.moved)
        self.assertEqual(r.coupled, ["r1", "b1"])
        self.assertEqual(st.pos, {"L": 1, "r1": 2, "b1": 3})
        self.assertTrue(st.is_linked("L", "r1"))
        self.assertTrue(st.is_linked("r1", "b1"))
        self.assertEqual(rules.train(L, st), ["L", "r1", "b1"])

    def test_couple_against_buffer_persists(self):
        L = lvl(line_cells(3), [loco(0), wagon("r1", 1), wagon("b1", 2, "blue")])
        st = rules.initial_state(L)
        r = rules.step(L, st, SIDE_B, 0)
        self.assertFalse(r.moved)
        self.assertEqual(r.blocked, "buffer")
        self.assertEqual(r.coupled, ["r1", "b1"])
        self.assertTrue(r.effective())
        # Şimdi çekince ikisi gelir.
        L2 = lvl(line_cells(4), [loco(1), wagon("r1", 2), wagon("b1", 3, "blue")])
        st2 = rules.initial_state(L2)
        rules.step(L2, st2, SIDE_B, 0)
        r = rules.step(L2, st2, SIDE_A, 0)
        self.assertTrue(r.moved)
        self.assertEqual(st2.pos, {"L": 0, "r1": 1, "b1": 2})

    def test_pull_only_linked(self):
        L = lvl(line_cells(5), [loco(2), wagon("r1", 3), wagon("b1", 1, "blue")], links=[["L", "r1"]])
        st = rules.initial_state(L)
        r = rules.step(L, st, SIDE_B, 0)
        # b yönünde baş r1; b1 bağsız, yerinde kalır.
        self.assertTrue(r.moved)
        self.assertEqual(st.pos, {"L": 3, "r1": 4, "b1": 1})
        st = rules.initial_state(L)
        r = rules.step(L, st, SIDE_A, 0)
        # a yönünde b1 komşu: itilir ve bağlanır; r1 bağlı olduğu için çekilir.
        self.assertEqual(r.coupled, ["b1"])
        self.assertEqual(st.pos, {"L": 1, "r1": 2, "b1": 0})
        self.assertEqual(rules.train(L, st), ["b1", "L", "r1"])

    def test_pulling_leaves_unlinked(self):
        L = lvl(line_cells(5), [loco(2), wagon("r1", 1)])
        st = rules.initial_state(L)
        r = rules.step(L, st, SIDE_B, 0)
        self.assertTrue(r.moved)
        self.assertEqual(st.pos, {"L": 3, "r1": 1})

    def test_uncouple(self):
        L = lvl(line_cells(4), [loco(1), wagon("r1", 2)], links=[["L", "r1"]])
        st = rules.initial_state(L)
        self.assertTrue(rules.uncouple(L, st, "r1", "L"))
        self.assertFalse(rules.uncouple(L, st, "r1", "L"))
        rules.step(L, st, SIDE_A, 0)
        self.assertEqual(st.pos, {"L": 0, "r1": 2})

    def test_switch_branch_choice(self):
        cells = switch_yard()
        ix = lambda x, y: layout.cell_index(cells, x, y)
        L = lvl(cells, [loco(ix(3, 2)), wagon("r1", ix(3, 1))])
        st = rules.initial_state(L)
        sw = ix(3, 3)
        self.assertEqual(cells[sw]["b"], [ix(3, 4), ix(4, 4)])
        rules.step(L, st, SIDE_B, 0)
        self.assertEqual(st.pos["L"], sw)
        p = rules.probe(L, st, SIDE_B)
        self.assertTrue(p.needs_branch)
        self.assertEqual(p.branch_cells, [ix(3, 4), ix(4, 4)])
        rules.step(L, st, SIDE_B, 1)
        self.assertEqual(st.pos["L"], ix(4, 4))
        # Daldan gövdeye dönüşte seçim yok.
        p = rules.probe(L, st, SIDE_A)
        self.assertFalse(p.needs_branch)
        self.assertTrue(p.possible)

    def test_no_sharp_turn(self):
        cells = switch_yard()
        ix = lambda x, y: layout.cell_index(cells, x, y)
        # Dal 3,4'ten makasa gelen lokomotif öbür dala (4,4) geçemez; ancak gövdeye gider.
        L = lvl(cells, [loco(ix(3, 4)), wagon("r1", ix(3, 1))])
        st = rules.initial_state(L)
        rules.step(L, st, SIDE_A, 0)
        self.assertEqual(st.pos["L"], ix(3, 3))
        rules.step(L, st, SIDE_A, 0)
        self.assertEqual(st.pos["L"], ix(3, 2))

    def test_coupling_stop_at_switch(self):
        cells = switch_yard()
        ix = lambda x, y: layout.cell_index(cells, x, y)
        # Lokomotif 3,1; vagon makasın üstünde (3,3) ama bir boşluk var: 3,2 boş.
        L = lvl(cells, [loco(ix(3, 2)), wagon("r1", ix(3, 3))])
        st = rules.initial_state(L)
        r = rules.step(L, st, SIDE_B, 0)
        # Bağlandı; yeni baş dal yanına bakıyor: adım burada biter (oyuncu dalı sonra seçer).
        self.assertEqual(r.coupled, ["r1"])
        self.assertFalse(r.moved)
        self.assertEqual(r.blocked, "")
        p = rules.probe(L, st, SIDE_B)
        self.assertTrue(p.needs_branch)
        r = rules.step(L, st, SIDE_B, 1)
        self.assertTrue(r.moved)
        self.assertEqual(st.pos["r1"], ix(4, 4))

    def test_self_bite_loop(self):
        tracks = ["2,2 3,2 4,3 4,4 3,5 2,5 1,4 1,3 2,2"]
        cells = layout.build_cells(tracks)
        order = [0]
        while len(order) < 8:
            c = cells[order[-1]]
            for q in c["a"] + c["b"]:
                if q not in order:
                    order.append(q)
                    break
        vs = [loco(order[0])] + [wagon("w%d" % i, order[i]) for i in range(1, 8)]
        links = [[vs[i]["id"], vs[i + 1]["id"]] for i in range(7)]
        L = lvl(cells, vs, links=links)
        st = rules.initial_state(L)
        # Halka dolu, katar zincir: iki yönde de baş kendi katarına dayanır.
        for side in (0, 1):
            r = rules.step(L, st, side, 0)
            self.assertEqual(r.blocked, "self")
            self.assertFalse(r.effective())
        # Bir vagon ayrılınca kuyruk ucu yine kendi katarı değil duran vagondur: itilir ama yer yok.
        rules.uncouple(L, st, "w6", "w7")
        s_tail = L.side_of(order[0], order[7])
        r = rules.step(L, st, s_tail, 0)
        self.assertEqual(r.coupled, ["w7"])
        self.assertEqual(r.blocked, "self")

    def test_foul(self):
        cells = switch_yard()
        ix = lambda x, y: layout.cell_index(cells, x, y)
        # r1 makasta (3,3), dal 4,4'teki b1'e bağlı; lokomotif öbür daldan (3,4) gelir.
        L = lvl(cells, [loco(ix(3, 5)), wagon("r1", ix(3, 3)), wagon("b1", ix(4, 4), "blue")],
                links=[["r1", "b1"]])
        st = rules.initial_state(L)
        r = rules.step(L, st, SIDE_A, 0)
        self.assertTrue(r.moved)
        r = rules.step(L, st, SIDE_A, 0)
        self.assertEqual(r.blocked, "foul")
        self.assertFalse(r.effective())

    def test_solved(self):
        L = lvl(line_cells(3), [loco(0), wagon("r1", 1)], targets=[{"cell": 2, "color": "red"}])
        st = rules.initial_state(L)
        self.assertFalse(rules.is_solved(L, st))
        rules.step(L, st, SIDE_B, 0)
        self.assertTrue(rules.is_solved(L, st))

    def test_loco_target(self):
        L = lvl(line_cells(3), [loco(0), wagon("r1", 2)], targets=[{"cell": 1, "color": "loco"}])
        st = rules.initial_state(L)
        rules.step(L, st, SIDE_B, 0)
        self.assertTrue(rules.is_solved(L, st))

    def test_apply_action_atomic_and_count(self):
        L = lvl(line_cells(6), [loco(0), wagon("r1", 2)], targets=[{"cell": 5, "color": "red"}])
        st = rules.initial_state(L)
        self.assertFalse(rules.apply_action(L, st, {"t": "drive", "side": "b", "steps": 9}))
        self.assertEqual(st.pos, {"L": 0, "r1": 2})
        acts = [{"t": "drive", "side": "b", "steps": 4, "branches": []}]
        self.assertTrue(rules.apply_action(L, st, acts[0]))
        self.assertTrue(rules.is_solved(L, st))
        self.assertEqual(rules.count_moves(L, acts), 1)
        split = [{"t": "drive", "side": "b", "steps": 2}, {"t": "drive", "side": "b", "steps": 2}]
        self.assertEqual(rules.count_moves(L, split), 1)
        cut = [{"t": "drive", "side": "b", "steps": 2}, {"t": "uncouple", "between": ["L", "r1"]},
               {"t": "drive", "side": "b", "steps": 2}]
        self.assertEqual(rules.count_moves(L, cut), 2)

    def test_direction_continuity_across_flipped_sides(self):
        # 1. hücrenin yanları ters: aynı yöne devam yan harfi değiştirir ama aynı hamledir.
        cells = line_cells(4)
        cells[2] = {"x": 0, "y": 2, "a": [3], "b": [1]}
        L = lvl(cells, [loco(0), wagon("r1", 3)], targets=[{"cell": 2, "color": "red"}])
        acts = [{"t": "drive", "side": "b", "steps": 2}, {"t": "drive", "side": "a", "steps": 1}]
        self.assertEqual(rules.count_moves(L, acts), 1)


class TestMechanics(unittest.TestCase):
    def test_traction(self):
        L = lvl(line_cells(6), [loco(0, power=1), wagon("r1", 1), wagon("b1", 2, "blue")])
        st = rules.initial_state(L)
        r = rules.step(L, st, SIDE_B, 0)
        self.assertEqual(r.blocked, "traction")
        self.assertEqual(r.coupled, ["r1", "b1"])
        rules.uncouple(L, st, "r1", "b1")
        r = rules.step(L, st, SIDE_A, 0)
        self.assertEqual(r.blocked, "buffer")
        r = rules.step(L, st, SIDE_B, 0)
        # r1 b1'e değer, b1 bağlanır, iki vagon: yine çekiş sınırı.
        self.assertEqual(r.blocked, "traction")

    def test_spring(self):
        cells = switch_yard()
        ix = lambda x, y: layout.cell_index(cells, x, y)
        sw = ix(3, 3)
        cells[sw]["kind"] = "spring"
        cells[sw]["spring"] = 1
        L = lvl(cells, [loco(ix(3, 2)), wagon("r1", ix(3, 1))])
        st = rules.initial_state(L)
        rules.step(L, st, SIDE_B, 0)
        p = rules.probe(L, st, SIDE_B)
        self.assertFalse(p.needs_branch)
        rules.step(L, st, SIDE_B, 0)
        self.assertEqual(st.pos["L"], ix(4, 4))

    def test_gate(self):
        cells = line_cells(5)
        cells[3]["kind"] = "gate"
        cells[0]["kind"] = "plate"
        L = lvl(cells, [loco(1), wagon("r1", 0)], targets=[{"cell": 4, "color": "red"}])
        st = rules.initial_state(L)
        r = rules.step(L, st, SIDE_B, 0)
        self.assertTrue(r.moved)
        r = rules.step(L, st, SIDE_B, 0)
        self.assertTrue(r.moved)  # plaka dolu: kapı açık
        L2 = lvl(cells, [loco(1), wagon("r1", 4)], targets=[{"cell": 4, "color": "red"}])
        st2 = rules.initial_state(L2)
        rules.step(L2, st2, SIDE_B, 0)
        r = rules.step(L2, st2, SIDE_B, 0)
        self.assertEqual(r.blocked, "gate")


class TestFastAgreement(unittest.TestCase):
    """Hızlı model (fast.py) rastgele durumlarda rules.py ile aynı sonucu vermeli."""

    def test_random(self):
        from fast import Yard
        rnd = random.Random(7)
        yards = [
            ["3,10 3,9 3,8 3,7 3,6 3,5 3,4 3,3 3,2 3,1", "3,6 2,5 2,4 2,3 2,2", "2,5 1,4 1,3 1,2"],
            ["3,1 3,2 3,3 3,4 3,5 3,6 3,7 3,8 3,9", "3,2 4,3 4,4 4,5 4,6 4,7 3,8", "3,5 2,6 2,7 2,8",
             "4,4 5,3 5,2 5,1"],
            ["2,2 3,2 4,3 4,4 3,5 2,5 1,4 1,3 2,2", "4,3 5,4 5,5 5,6"],
        ]
        checked = 0
        for tracks in yards:
            cells = layout.build_cells(tracks)
            n = len(cells)
            for _ in range(60):
                cells2 = [dict(c) for c in cells]
                mech = rnd.random()
                power = rnd.choice([0, 0, 1, 2])
                if mech < 0.3:
                    g = rnd.randrange(n)
                    p = rnd.randrange(n)
                    if g != p:
                        cells2[g]["kind"] = "gate"
                        cells2[p]["kind"] = "plate"
                for c in range(n):
                    br = [s for s in (0, 1) if len(cells2[c]["ab"[s]]) == 2]
                    if len(br) == 1 and rnd.random() < 0.3 and cells2[c].get("kind", "plain") == "plain":
                        cells2[c]["kind"] = "spring"
                        cells2[c]["spring"] = rnd.randrange(2)
                k = rnd.randint(1, min(6, n - 1))
                occ = rnd.sample(range(n), k + 1)
                vs = [loco(occ[0], power=power)]
                for i, c in enumerate(occ[1:]):
                    v = wagon("w%d" % i, c, rnd.choice(["red", "blue", "yellow"]))
                    vs.append(v)
                L = lvl(cells2, vs, targets=[{"cell": occ[1], "color": "red"}])
                st = rules.initial_state(L)
                yard = Yard(L)
                for _step in range(40):
                    key = yard.from_level_state(st)
                    occl, tr = yard.decode(key)
                    side = rnd.randrange(2)
                    br = rnd.randrange(2)
                    nb = yard.needs_branch(occl, tr, side)
                    pr = rules.probe(L, st, side)
                    self.assertEqual(nb, pr.needs_branch)
                    fr = yard.step(occl, tr, side, br)
                    work = st.copy()
                    r = rules.step(L, work, side, br)
                    if fr is None:
                        self.assertFalse(r.effective(), "hızlı etkisiz, kural etkili")
                    else:
                        self.assertTrue(r.effective())
                        self.assertEqual(bytes(fr[0]) + bytes(fr[1]), yard.from_level_state(work))
                        self.assertEqual(fr[2], 1 if r.moved else 0)
                    checked += 1
                    # İlerle: rastgele adım ya da ayırma; duran bağları normalleştir.
                    if rnd.random() < 0.15 and len(st.links) > 0:
                        lk = sorted(sorted(x) for x in st.links)
                        a, b = rnd.choice(lk)
                        rules.uncouple(L, st, a, b)
                    else:
                        rules.step(L, st, side, br)
                    tr_ids = set(rules.train(L, st))
                    st.links = set(x for x in st.links if set(x) <= tr_ids)
        self.assertGreater(checked, 5000)


if __name__ == "__main__":
    unittest.main()
