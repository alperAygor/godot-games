#!/usr/bin/env python3
"""C2: normal dalgalarda (boss yokken) alınan hasarın kaynağa göre payı + normal dalga başına can kaybı + normal dalgada ölüm payı.
Kullanım: python3 tools/sim/c2_normal.py rapor1.json [rapor2.json ...]   (raporlar --runs ile üretilmiş olmalı)"""
import json, sys, collections, statistics as st
for path in sys.argv[1:]:
    runs = json.load(open(path))["run_list"]
    tot = collections.Counter()
    per = []
    for r in runs:
        for k, v in r.get("damage_normal", {}).items():
            tot[k] += v
        nw = max(1, r["wave"] - r["wave"] // 5)
        per.append((r["hp_lost"] - r["hp_lost_boss"]) / r["max_hp"] / nw)
    s = sum(tot.values()) or 1.0
    dead = [r for r in runs if not r["capped"]]
    normal_deaths = [r for r in dead if r["wave"] % 5 != 0]
    print(f"{path}: koşu {len(runs)}  normal-dalga hasarı toplam {s:.0f}  normal dalga başına can kaybı (maks canın oranı) ort {st.mean(per):.3f} medyan {st.median(per):.3f}")
    print("  normal dalga hasar payı: " + ", ".join(f"{k} %{100*v/s:.0f}" for k, v in tot.most_common(12)))
    print(f"  normal dalgada ölüm: {len(normal_deaths)}/{len(dead)} = %{100*len(normal_deaths)/max(1,len(dead)):.1f}")
