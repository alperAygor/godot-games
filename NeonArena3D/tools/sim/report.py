#!/usr/bin/env python3
"""Denge simülasyonu raporunu (balance_sim.gd çıktısı JSON) okunur özet tablolara çevirir.

  python3 tools/sim/report.py build/sim/balance_report.json            # ekrana yazar
  python3 tools/sim/report.py build/sim/balance_report.json -o x.md    # dosyaya da yazar
  python3 tools/sim/report.py yeni.json --compare eski.json            # iki rapor arası medyan dalga farkı (F2 kabulü: <= %5)

Yalnız standart kütüphane. Rapordaki sayılar soyut modelin çıktısıdır (bkz. tests/sim/run_sim.gd başlığı).
"""
from __future__ import annotations

import argparse
import json
import sys


def table(headers, rows):
    out = ["| " + " | ".join(headers) + " |", "|" + "|".join("---" for _ in headers) + "|"]
    for r in rows:
        out.append("| " + " | ".join(str(c) for c in r) + " |")
    return "\n".join(out)


def f(x, nd=1):
    return f"{x:.{nd}f}"


def share_text(d, top=4):
    items = sorted(d.items(), key=lambda kv: -kv[1])[:top]
    return ", ".join(f"{k} {v}" for k, v in items) if items else "-"


def pct_text(d, top=4):
    total = sum(d.values()) or 1
    items = sorted(d.items(), key=lambda kv: -kv[1])[:top]
    return ", ".join(f"{k} %{100 * v / total:.0f}" for k, v in items) if items else "-"


def render(rep):
    L = []
    o = rep["overall"]
    g = rep["meta"]["grid"]
    L.append("# Denge simülasyonu raporu")
    L.append("")
    L.append(f"{o['runs']} koşu · {g['seeds']} tohum × gemiler {g['ships']} × atölye {g['tiers']} × yapı {g['builds']} × politika {g['policies']} · "
             f"{g['careers']} kariyer. Soyut model (sim v{rep['meta']['sim_version']}): oranlar ve sürümler arası farklar anlamlıdır, mutlak sayılar değil.")
    L.append("")
    L.append(f"Genel: medyan dalga **{f(o['wave']['median'])}** (p10 {f(o['wave']['p10'])}, p90 {f(o['wave']['p90'])}), medyan süre {f(o['time_s']['median'], 0)} sn, "
             f"medyan öldürme {f(o['kills']['median'], 0)}, medyan koşu çekirdeği {f(o['cores']['median'])}, zaman sınırına takılan: {o['capped']}.")
    L.append("")
    L.append("## Gemi")
    L.append(table(["gemi", "medyan dalga", "p10", "p90", "süre sn", "çekirdek/koşu", "ana ölüm nedeni"],
                   [[k, f(v["wave"]["median"]), f(v["wave"]["p10"]), f(v["wave"]["p90"]), f(v["time_s"]["median"], 0), f(v["cores"]["mean"]), pct_text(v["death_causes"], 2)]
                    for k, v in rep["by_ship"].items()]))
    L.append("")
    L.append("## Atölye düzeyi")
    L.append(table(["düzey", "medyan dalga", "p10", "p90", "çekirdek/koşu", "boss öldürme/koşu"],
                   [[k, f(v["wave"]["median"]), f(v["wave"]["p10"]), f(v["wave"]["p90"]), f(v["cores"]["mean"]), f(sum(v["boss_kills"].values()) / max(1, v["runs"]), 2)]
                    for k, v in rep["by_tier"].items()]))
    if len(rep["by_build"]) > 1:
        L.append("")
        L.append("## Yapı")
        L.append(table(["yapı", "medyan dalga", "p90", "süre sn"],
                       [[k, f(v["wave"]["median"]), f(v["wave"]["p90"]), f(v["time_s"]["median"], 0)] for k, v in rep["by_build"].items()]))
    if len(rep["by_policy"]) > 1:
        L.append("")
        L.append("## Kart politikası")
        L.append(table(["politika", "medyan dalga", "p90"], [[k, f(v["wave"]["median"]), f(v["wave"]["p90"])] for k, v in rep["by_policy"].items()]))
    if rep.get("sectors"):
        L.append("")
        L.append("## Sektörler (C1: temizleme oranı S1..Sn, zafer, kapı seçimleri)")
        rows = []
        for mode, tiers in rep["sectors"].items():
            for tier, st in tiers.items():
                rows.append([mode, tier, st["runs"], " / ".join(f"%{100 * v:.0f}" for v in st["clear_rate"]), f"%{100 * st['victory_rate']:.0f}",
                             f(st["wave"]["median"]), f(st["cores"]["median"], 0), st["gate_errors"], pct_text(st.get("gate_picks", {}), 4)])
        L.append(table(["mod", "atölye", "koşu", "temizleme S1/S2/S3", "zafer", "medyan dalga", "medyan çekirdek", "kapı hatası", "kapı seçimi"], rows))
    if rep.get("by_mode"):
        L.append("")
        L.append("## Mod başına: ölüm yeri (boss dalgası / normal dalga) ve çekirdek")
        L.append(table(["mod", "koşu", "medyan dalga", "ölüm: boss dalgası", "ölüm: normal dalga", "boss payı", "çekirdek medyan", "çekirdek ort."],
                       [[k, v["runs"], f(v["wave"]["median"]), v.get("deaths", {}).get("boss_wave", "-"), v.get("deaths", {}).get("normal_wave", "-"),
                         f"%{100 * v.get('deaths', {}).get('boss_share', 0):.0f}", f(v["cores"]["median"]), f(v["cores"]["mean"])] for k, v in rep["by_mode"].items()]))
    L.append("")
    L.append("## Ölüm nedenleri (genel, canı bitiren son vuruş)")
    L.append(pct_text(o["death_causes"], 12))
    L.append("")
    L.append("Alınan hasar payı: " + pct_text({k: v for k, v in o["damage_share"].items()}, 10))
    if o.get("damage_share_normal"):
        L.append("")
        L.append("Normal dalgada (boss yokken) alınan hasar payı (C2): " + pct_text(o["damage_share_normal"], 12))
    L.append("")
    L.append("Medyan dalga zaman çizelgesi (sn → dalga): " + ", ".join(f"{k} sn → {f(v)}" for k, v in sorted(o["median_wave_at_seconds"].items(), key=lambda kv: int(kv[0]))))
    L.append("")
    L.append("Düşman türü öldürme payı: " + pct_text(o["kills_by_kind"], 8))
    L.append("")
    L.append("Boss öldürme (tür): " + share_text(o["boss_kills"], 5))
    L.append("")
    cards = rep["cards"]
    L.append("## Kartlar (rastgele politika: seçim oranı = seçilen/sunulan; kazanç = seçilince kalan dalga - sunulup geçilen)")
    rows = sorted(cards.items(), key=lambda kv: -kv[1]["lift_waves"])
    L.append(table(["kart", "kademe", "sunulan", "seçilen", "seçim oranı", "kazanç (dalga) ± s.h.", "örnek"],
                   [[k, v["tier"], v["offered"], v["picked"], f"%{100 * v['pick_rate']:.0f}", f"{v['lift_waves']:+.2f} ± {v['lift_se']:.2f}", v["lift_samples"]] for k, v in rows]))
    L.append("")
    L.append("Not: rastgele politikada seçim oranı ~%33 beklenir (bilgi taşımaz); anlamlı olan kazançtır. |kazanç| < 2 × s.h. ise gürültüdür (daha çok tohum: --seeds=60).")
    for pol, c in rep.get("careers", {}).items():
        L.append("")
        L.append(f"## Kariyer (atölye + gemi tüketimi, '{pol}' kart politikası)")
        L.append(f"{c['exhausted']}/{c['careers']} kariyerde atölye+gemiler tükendi. Koşu sayısı: medyan {f(c['runs_to_exhaust']['median'], 0)} "
                 f"(min {f(c['runs_to_exhaust']['min'], 0)}, max {f(c['runs_to_exhaust']['max'], 0)}); oyun süresi medyan {f(c['play_minutes']['median'], 0)} dk; "
                 f"toplam çekirdek medyan {f(c['cores_earned']['median'], 0)}. İlk 5 koşu ort. dalga {f(c['mean_wave_first5_runs'])}, son 5: {f(c['mean_wave_last5_runs'])}.")
        L.append("Gemi kullanım payı (kariyer boyunca): " + ", ".join(f"{k} %{100 * v:.0f}" for k, v in c["ship_usage_share"].items()) +
                 " · gemi alınma koşusu: " + ", ".join(f"{k} #{f(v, 0)}" for k, v in c["ship_bought_at_run"].items()))
        if c.get("endgame_ship_share"):
            L.append("Her şey alındıktan sonra (12 koşu): kullanım " + ", ".join(f"{k} %{100 * v:.0f}" for k, v in c["endgame_ship_share"].items()) +
                     " · ort. dalga " + ", ".join(f"{k} {f(v)}" for k, v in c["endgame_ship_mean_wave"].items()))
    sc = rep.get("scan")
    if sc:
        L.append("")
        L.append(f"## Kırık kombinasyon taraması ({sc['ship']}, atölye {sc['tier']}, {sc['seeds']} tohum; yapısız medyan {f(sc['baseline_median'])})")
        L.append(table(["grup", "giriş", "en iyi", "en iyi IQM", "ort. IQM", "oran (kapı)", "düz medyan oranı", "sınır"],
                       [[g, len(v["entries"]), v["best"], f(v["best_median"]), f(v["mean_median"]), f(v["ratio"], 2), f(v.get("median_ratio", 0), 2), f(v["max_ratio"], 2)] for g, v in sc["groups"].items()]))
        for g, v in sc["groups"].items():
            items = sorted(v["entries"].items(), key=lambda kv: -kv[1])
            L.append("")
            L.append(f"{g}: " + ", ".join(f"{k} {f(x)}" for k, x in items))
    a = rep["assertions"]
    L.append("")
    L.append("## Doğrulamalar")
    L.append("geçti" if a["passed"] else "BAŞARISIZ: " + "; ".join(a["failed"]))
    return "\n".join(L) + "\n"


def compare(new, old):
    L = ["# Karşılaştırma (yeni - eski), medyan dalga", ""]
    rows = []
    worst = 0.0
    for key, n in new["groups"].items():
        o = old["groups"].get(key)
        if not o:
            continue
        a, b = n["wave"]["median"], o["wave"]["median"]
        d = (a - b) / max(1e-9, b)
        worst = max(worst, abs(d))
        rows.append([key, f(b), f(a), f"{100 * d:+.1f}%"])
    L.append(table(["grup", "eski", "yeni", "fark"], rows))
    ov_n, ov_o = new["overall"]["wave"]["median"], old["overall"]["wave"]["median"]
    L.append("")
    L.append(f"Genel medyan dalga: {f(ov_o)} -> {f(ov_n)} ({100 * (ov_n - ov_o) / max(1e-9, ov_o):+.1f}%); en büyük grup farkı %{100 * worst:.1f}")
    return "\n".join(L) + "\n", abs(ov_n - ov_o) / max(1e-9, ov_o)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("report")
    ap.add_argument("-o", "--out")
    ap.add_argument("--compare")
    args = ap.parse_args()
    rep = json.load(open(args.report, encoding="utf-8"))
    if args.compare:
        text, overall = compare(rep, json.load(open(args.compare, encoding="utf-8")))
        print(text)
        return 0 if overall <= 0.05 else 1
    text = render(rep)
    print(text)
    if args.out:
        open(args.out, "w", encoding="utf-8").write(text)
    return 0 if rep["assertions"]["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
