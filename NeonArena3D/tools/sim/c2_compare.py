#!/usr/bin/env python3
"""C2: iki denge simülasyonu raporunu (--runs ile üretilmiş) karşılaştırır: hasar payı tablosu + ölüm dalgası tablosu.
Kullanım: python3 tools/sim/c2_compare.py once.json sonra.json [--tier=fresh]"""
import json, sys, collections

def load(path, tier):
    d = json.load(open(path))
    runs = [r for r in d["run_list"] if (tier is None or r.get("tier") == tier)]
    return runs

def damage_share(runs):
    tot = collections.Counter()
    for r in runs:
        for k, v in r.get("damage_taken", {}).items():
            tot[k] += v
    s = sum(tot.values()) or 1.0
    return {k: v / s for k, v in tot.items()}

def death_table(runs):
    normal = boss = 0
    by_wave = collections.Counter()
    causes_normal = collections.Counter()
    for r in runs:
        if r.get("capped"):
            continue
        w = int(r["wave"])
        by_wave[w] += 1
        if w % 5 == 0:
            boss += 1
        else:
            normal += 1
            causes_normal[r["death_cause"]] += 1
    return normal, boss, by_wave, causes_normal

def main():
    a, b = sys.argv[1], sys.argv[2]
    tier = None
    for x in sys.argv[3:]:
        if x.startswith("--tier="):
            tier = x.split("=")[1]
    ra, rb = load(a, tier), load(b, tier)
    print(f"koşu: önce {len(ra)} · sonra {len(rb)} (tier={tier or 'hepsi'})")
    sa, sb = damage_share(ra), damage_share(rb)
    keys = sorted(set(sa) | set(sb), key=lambda k: -(sb.get(k, 0) + sa.get(k, 0)))
    print("\nHasar payı (alınan hasar):\n| kaynak | önce | sonra |\n|---|---|---|")
    for k in keys[:22]:
        print(f"| {k} | %{sa.get(k,0)*100:.1f} | %{sb.get(k,0)*100:.1f} |")
    for name, runs in (("önce", ra), ("sonra", rb)):
        n, bo, bw, cn = death_table(runs)
        tot = n + bo or 1
        print(f"\nÖlüm dalgası ({name}): normal dalgada %{100*n/tot:.1f} ({n}), boss dalgasında %{100*bo/tot:.1f} ({bo})")
        print("  dalga: " + ", ".join(f"{w}:{c}" for w, c in sorted(bw.items())[:14]))
        print("  normal dalga ölüm nedenleri: " + ", ".join(f"{k} {c}" for k, c in cn.most_common(8)))
    # erken dalgalar (1-3)
    for name, runs in (("önce", ra), ("sonra", rb)):
        early = sum(1 for r in runs if not r.get("capped") and int(r["wave"]) <= 3)
        print(f"waves<=3 ölümü ({name}): {early}")
    for name, runs in (("önce", ra), ("sonra", rb)):
        ws = sorted(int(r["wave"]) for r in runs)
        print(f"medyan dalga ({name}): {ws[len(ws)//2]}")

main()
