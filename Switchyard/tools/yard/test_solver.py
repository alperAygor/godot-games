"""Çözücü testleri: par kesinliği (üç bağımsız yol aynı sonucu verir), çözümün gerçek kurallarla oynaması."""

import os
import random
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import graph  # noqa: E402
import layout  # noqa: E402
import rules  # noqa: E402
import solver  # noqa: E402
from fast import Yard  # noqa: E402

TRACKS = ["3,8 3,7 3,6 3,5 3,4 3,3 3,2", "3,6 2,5 2,4 2,3"]


def level(vehicles, targets, links=()):
    cells = layout.build_cells(TRACKS)
    ix = lambda p: layout.cell_index(cells, p[0], p[1])  # noqa: E731
    vs = []
    for (vid, col, p) in vehicles:
        v = {"id": vid, "type": "loco" if vid == "L" else "wagon", "cell": ix(p)}
        if col:
            v["color"] = col
        vs.append(v)
    return rules.Level({"id": "s", "cells": cells, "vehicles": vs, "links": [list(x) for x in links],
                        "targets": [{"cell": ix(p), "color": c} for (p, c) in targets]})


class TestSolver(unittest.TestCase):
    def test_single_push(self):
        lv = level([("L", None, (3, 8)), ("r1", "red", (3, 6))], [((3, 3), "red")])
        m, acts = solver.analyze(lv)
        self.assertEqual(m["par"], 1)
        self.assertEqual(m["min_cells"], 4)  # 1 yaklaşma + 3 itme
        self.assertEqual(acts, [{"t": "drive", "side": "a", "steps": 5, "branches": [0]}])
        # 5 etkili adım: makastaki vagona bağlanma adımı biter (YARD.md §2 kural 4), dal sonraki adımda

    def test_swap_needs_siding(self):
        # Kırmızı ve mavi yer değiştirmeli: yan hat olmadan imkânsız, onunla birkaç hamle.
        lv = level([("L", None, (3, 8)), ("r1", "red", (3, 3)), ("b1", "blue", (3, 2))],
                   [((3, 2), "red"), ((3, 3), "blue")])
        m, acts = solver.analyze(lv)
        self.assertGreaterEqual(m["par"], 4)
        st = rules.initial_state(lv)
        for a in acts:
            self.assertTrue(rules.apply_action(lv, st, a))
        self.assertTrue(rules.is_solved(lv, st))
        self.assertEqual(rules.count_moves(lv, acts), m["par"])

    def test_three_methods_agree(self):
        """Geriye 0-1 BFS (graph), ileri katmanlı BFS ve Dijkstra rastgele başlangıçlarda aynı par'ı verir."""
        rnd = random.Random(3)
        lv0 = level([("L", None, (3, 8)), ("r1", "red", (3, 3)), ("b1", "blue", (3, 2)),
                     ("y1", "yellow", (2, 3))], [((3, 2), "red"), ((3, 3), "blue"), ((2, 3), "yellow")])
        yard = Yard(lv0)
        start = yard.from_level_state(rules.initial_state(lv0))
        G = graph.Graph(yard, [start])
        D = G.dist_to_goal()
        idx = [i for i in range(G.N) if D[3 * i + 2] < graph.INF]
        for i in rnd.sample(idx, 25):
            k = G.keys[i]
            _d, g, _o = solver.layered(yard, [k], stop_at_goal=True)
            r = solver.solve_path(yard, k)
            self.assertEqual(D[3 * i + 2], g)
            self.assertEqual(r[0], g)

    def test_unsolvable_reported(self):
        # Hedef yan hattın ucunda ama vagon yok -> çözümsüz.
        lv = level([("L", None, (3, 8)), ("r1", "red", (3, 2))], [((2, 3), "blue")])
        with self.assertRaises(RuntimeError):
            solver.analyze(lv)

    def test_difficulty_range(self):
        self.assertEqual(solver.difficulty_score({"par": 1, "detours": 0, "solutions_at_par": 1, "states": 20}), 1)
        self.assertEqual(solver.difficulty_score({"par": 34, "detours": 9, "solutions_at_par": 5,
                                                  "states": 10 ** 6}), 10)


if __name__ == "__main__":
    unittest.main()
