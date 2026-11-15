# CORE worker report (sy-core)

Status per deliverable (updated as work proceeds).

| # | Deliverable | Status |
|---|---|---|
| 1 | Python rules `tools/yard/rules.py` + tests | done (test_rules.py, 32 tests incl. randomized fast-model agreement) |
| 2 | GDScript rules `scripts/core/yard/` + tests | done (test_yard_rules.gd, 8 tests) |
| 3 | Conformance vectors | done: 3003 vectors + 18 invalid levels, GDScript matches 100% (test_yard_vectors.gd) |
| 4 | Solver | core done (solver.py, graph.py); metrics being finalised |
| 5 | Generator | pending |
| 6 | Mechanics (3) | pending |
| 7 | 40 levels | pending |
| 8 | Blind CLI | pending |
| 9 | Hint | pending |

## Early findings (kept here so they survive interruptions)

- Goal-side forward BFS is NOT a good proxy for par (it overestimated by 0-4 moves; moves are not exactly
  reversible because coupling needs a push while uncoupling is free). The generator therefore builds the explicit
  state graph and runs an exact backward 0-1 BFS (`tools/yard/graph.py`).
- Depth probe (exact max par, loco starting alone): Inglenook 3-siding with 2-cell headshunt and 5 wagons
  (r,r,b,b,y): par 20 in a 15-cell yard (341k states); Timesaver-style loop yard, 4 distinct wagons: par 18-19
  (2.9M states, ~50 s). Shorter headshunts produce deeper puzzles.
