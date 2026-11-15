#!/usr/bin/env python3
"""C2: tür başına ortalama ömür (doğmadan ölüme sn ≈ öldürme süresi) ve öldürme sayısı; iki rapor karşılaştırması (--runs ile üretilmiş).
Kullanım: python3 tools/sim/c2_ttk.py once.json sonra.json"""
import json, sys, collections
def agg(path):
    tot = collections.defaultdict(lambda: [0.0, 0])
    for r in json.load(open(path))["run_list"]:
        for k, v in r.get("ttk", {}).items():
            tot[k][0] += v[0]; tot[k][1] += v[1]
    return tot
a, b = agg(sys.argv[1]), agg(sys.argv[2])
print("| tür | ömür önce (sn) | ömür sonra (sn) | öldürme önce | öldürme sonra |\n|---|---|---|---|---|")
for k in sorted(set(a) | set(b), key=lambda k: -(b.get(k, [0, 0])[1] + a.get(k, [0, 0])[1])):
    fa, fb = a.get(k, [0.0, 0]), b.get(k, [0.0, 0])
    sa = f"{fa[0]/fa[1]:.1f}" if fa[1] else "—"
    sb = f"{fb[0]/fb[1]:.1f}" if fb[1] else "—"
    print(f"| {k} | {sa} | {sb} | {fa[1]} | {fb[1]} |")
