"""Metin arayüzü: hamle yazımı, sayım, hata iletileri."""

import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import cli  # noqa: E402
import layout  # noqa: E402
import rules  # noqa: E402


def lv():
    cells = layout.build_cells(["3,8 3,7 3,6 3,5 3,4 3,3 3,2", "3,6 2,5 2,4 2,3"])
    ix = lambda x, y: layout.cell_index(cells, x, y)  # noqa: E731
    return rules.Level({"id": "c", "par": 2, "cells": cells, "links": [],
                        "vehicles": [{"id": "L", "type": "loco", "cell": ix(3, 8)},
                                     {"id": "r1", "type": "wagon", "color": "red", "cell": ix(3, 7)}],
                        "targets": [{"cell": ix(2, 3), "color": "red"}, {"cell": ix(3, 8), "color": "loco"}]})


class TestCli(unittest.TestCase):
    def test_solve_and_count(self):
        L = lv()
        st, moves, log, err = cli.run_moves(L, "N3[NW] N1 L/r1 S4")
        self.assertIsNone(err, log)
        self.assertEqual(moves, 2, "N3 N1 tek hamle")
        self.assertTrue(rules.is_solved(L, st))

    def test_missing_branch_lists_options(self):
        st, moves, log, err = cli.run_moves(lv(), "N3")
        self.assertIn("NW", err)
        self.assertIn("N", err)

    def test_star_and_errors(self):
        L = lv()
        st, moves, log, err = cli.run_moves(L, "N*[N]")
        self.assertIsNone(err, log)
        self.assertEqual(st.pos["r1"], layout.cell_index(L_cells(), 3, 2))
        st, moves, log, err = cli.run_moves(L, "E2")
        self.assertIn("no rail", err)
        st, moves, log, err = cli.run_moves(L, "L/b9")
        self.assertIsNotNone(err)

    def test_render_has_grid(self):
        L = lv()
        out = cli.render(L, rules.initial_state(L))
        self.assertIn("r1", out)
        self.assertIn(".R", out)
        self.assertIn("L L", out)


def L_cells():
    return layout.build_cells(["3,8 3,7 3,6 3,5 3,4 3,3 3,2", "3,6 2,5 2,4 2,3"])


if __name__ == "__main__":
    unittest.main()
