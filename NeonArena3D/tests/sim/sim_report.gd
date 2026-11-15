extends RefCounted
class_name SimReport
## Simülasyon sonuçlarını özetler ve "kabaca bozukluk" doğrulamalarını yapar. Saf veri işleme; Godot düğümü yok.

static func _round(v: float) -> float:
	return snappedf(v, 0.001)

static func quantile(values: Array, q: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted: Array = values.duplicate()
	sorted.sort()
	var pos := q * float(sorted.size() - 1)
	var lo := int(floor(pos))
	var hi := int(ceil(pos))
	return float(sorted[lo]) + (float(sorted[hi]) - float(sorted[lo])) * (pos - float(lo))

static func mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var s := 0.0
	for v in values:
		s += float(v)
	return s / float(values.size())

static func _variance(values: Array) -> float:
	if values.size() < 2:
		return 0.0
	var m := mean(values)
	var s := 0.0
	for v in values:
		s += (float(v) - m) * (float(v) - m)
	return s / float(values.size() - 1)

static func dist(values: Array) -> Dictionary:
	return {
		"n": values.size(), "mean": _round(mean(values)), "median": _round(quantile(values, 0.5)),
		"p10": _round(quantile(values, 0.1)), "p90": _round(quantile(values, 0.9)),
		"min": _round(quantile(values, 0.0)), "max": _round(quantile(values, 1.0)),
	}

static func group_key(r: Dictionary) -> String:
	return "%s|%s|%s|%s" % [r.get("ship", "?"), r.get("tier", "?"), r.get("build", "none"), r.get("policy", "random")]

static func summarize(runs: Array) -> Dictionary:
	## Bir grup koşunun dağılım özeti.
	var waves: Array = []
	var times: Array = []
	var kills: Array = []
	var scores: Array = []
	var cores: Array = []
	var levels: Array = []
	var peaks: Array = []
	var capped := 0
	var causes := {}
	var damage := {}
	var boss_kills := {}
	var kbk := {}
	var wave_at := {}
	for r in runs:
		waves.append(r["wave"])
		times.append(r["time"])
		kills.append(r["kills"])
		scores.append(r["score"])
		cores.append(r["cores"])
		levels.append(r["level"])
		peaks.append(r["peak_alive"])
		if r["capped"]:
			capped += 1
		var c: String = str(r["death_cause"]).get_slice(":", 0) + (":" + str(r["death_cause"]).get_slice(":", 1) if ":" in str(r["death_cause"]) else "")
		causes[c] = int(causes.get(c, 0)) + 1
		for k in r["damage_taken"]:
			damage[k] = float(damage.get(k, 0.0)) + float(r["damage_taken"][k])
		for k in r["boss_kills"]:
			boss_kills[k] = int(boss_kills.get(k, 0)) + int(r["boss_kills"][k])
		for k in r["kills_by_kind"]:
			kbk[k] = int(kbk.get(k, 0)) + int(r["kills_by_kind"][k])
		for k in r["wave_at"]:
			if not wave_at.has(k):
				wave_at[k] = []
			(wave_at[k] as Array).append(r["wave_at"][k])
	var wave_marks := {}
	for k in wave_at:
		wave_marks[k] = _round(quantile(wave_at[k], 0.5))
	var total_damage := 0.0
	for k in damage:
		total_damage += float(damage[k])
	var damage_share := {}
	for k in damage:
		damage_share[k] = _round(float(damage[k]) / maxf(1.0, total_damage))
	return {
		"runs": runs.size(), "capped": capped,
		"wave": dist(waves), "time_s": dist(times), "kills": dist(kills), "score": dist(scores),
		"cores": dist(cores), "level": dist(levels), "peak_alive": dist(peaks),
		"death_causes": causes, "damage_share": damage_share, "boss_kills": boss_kills,
		"kills_by_kind": kbk, "median_wave_at_seconds": wave_marks,
	}

static func card_stats(runs: Array, card_ids: Array, tiers: Dictionary) -> Dictionary:
	## Kart sunum/seçim oranları ve "seçilince kalan dalga kazancı" (aynı anda sunulup seçilmeyen kartlara göre).
	var offered := {}
	var picked := {}
	var runs_offered := {}
	var runs_taken := {}
	var rem_picked := {}
	var rem_skipped := {}
	var by_wave := {}
	for id in card_ids:
		offered[id] = 0
		picked[id] = 0
		runs_offered[id] = 0
		runs_taken[id] = 0
		rem_picked[id] = []
		rem_skipped[id] = []
		by_wave[id] = []
	for r in runs:
		var seen_o := {}
		var seen_t := {}
		for p in r["picks"]:
			var offer: Array = p[0]
			var chosen: String = p[1]
			var remaining := float(r["wave"]) - float(p[2])
			for id in offer:
				offered[id] = int(offered.get(id, 0)) + 1
				seen_o[id] = true
				if id == chosen:
					picked[id] = int(picked.get(id, 0)) + 1
					seen_t[id] = true
					(rem_picked[id] as Array).append(remaining)
					(by_wave[id] as Array).append(float(p[2]))
				else:
					(rem_skipped[id] as Array).append(remaining)
		for id in seen_o:
			runs_offered[id] = int(runs_offered.get(id, 0)) + 1
		for id in seen_t:
			runs_taken[id] = int(runs_taken.get(id, 0)) + 1
	var out := {}
	for id in card_ids:
		var o := int(offered[id])
		var p := int(picked[id])
		var lift := 0.0
		var lift_se := 0.0
		var rp: Array = rem_picked[id]
		var rs: Array = rem_skipped[id]
		if rp.size() >= 5 and rs.size() >= 5:
			lift = mean(rp) - mean(rs)
			lift_se = sqrt(_variance(rp) / float(rp.size()) + _variance(rs) / float(rs.size()))
		out[id] = {
			"tier": tiers.get(id, "?"), "offered": o, "picked": p,
			"pick_rate": _round(float(p) / float(maxi(1, o))), "runs_offered": runs_offered[id], "runs_taken": runs_taken[id],
			"lift_waves": _round(lift), "lift_se": _round(lift_se), "lift_samples": rp.size(), "mean_wave_when_taken": _round(mean(by_wave[id])),
		}
	return out

static func check(report: Dictionary, expect_full_cards := true) -> Array:
	## "Kabaca bozukluk" doğrulamaları: boş dönerse sorun yok. Her öğe okunur bir hata cümlesidir.
	var problems: Array = []
	var overall: Dictionary = report.get("overall", {})
	if int(overall.get("runs", 0)) <= 0:
		problems.append("hiç koşu üretilmedi")
		return problems
	if int(overall.get("capped", 0)) > 0:
		var share := float(overall["capped"]) / float(overall["runs"])
		if share > float(report["meta"].get("max_capped_share", 0.25)):
			problems.append("koşuların %%%.0f'i sonlanmadı (zaman sınırı) — ölümsüz yapı ya da bozuk zorluk" % (share * 100.0))
	if float(overall["wave"]["median"]) < 2.0:
		problems.append("medyan dalga < 2: oyun oynanamaz görünüyor")
	if float(overall["kills"]["median"]) < 3.0:
		problems.append("medyan öldürme < 3: bot hiç öldüremiyor")
	for key in report.get("groups", {}):
		var g: Dictionary = report["groups"][key]
		if int(g["runs"]) >= 5 and float(g["wave"]["median"]) <= 1.0:
			problems.append("grup %s: medyan dalga 1" % key)
	if expect_full_cards:
		for id in report.get("cards", {}):
			var c: Dictionary = report["cards"][id]
			if str(c.get("tier", "")) in ["evolution", "cursed"]:
				continue   # havuz dışı / yalnız tarif tamamlanınca: kırık kombinasyon taraması ölçer
			if int(c["offered"]) == 0:
				problems.append("kart %s hiç sunulmadı" % id)
			elif int(c["picked"]) == 0 and int(c["offered"]) >= 20:
				problems.append("kart %s %d kez sunuldu, hiç seçilmedi (%%0 seçim)" % [id, int(c["offered"])])
	for tier_pair in [["fresh", "maxed"]]:
		var a: Variant = report.get("by_tier", {}).get(tier_pair[0], null)
		var b: Variant = report.get("by_tier", {}).get(tier_pair[1], null)
		if a != null and b != null and float(b["wave"]["median"]) + 0.01 < float(a["wave"]["median"]):
			problems.append("tam atölye (%.1f dalga) boş atölyeden (%.1f) daha kötü: yükseltmeler ters etki ediyor" % [float(b["wave"]["median"]), float(a["wave"]["median"])])
	if report.has("scan"):
		var sc: Dictionary = report["scan"]
		if float(sc.get("ratio", 0.0)) > float(sc.get("max_ratio", 1.6)):
			problems.append("kırık kombinasyon: %s sağlam medyan (IQM) dalga %.1f, ortalama %.1f (oran %.2f > %.2f)" % [str(sc.get("best", "?")), float(sc.get("best_median", 0.0)), float(sc.get("mean_median", 0.0)), float(sc["ratio"]), float(sc.get("max_ratio", 1.6))])
	if report.has("determinism") and not bool(report["determinism"].get("same", true)):
		problems.append("aynı tohum iki kez farklı sonuç verdi (belirlenimsizlik)")
	return problems

static func iqm(values: Array) -> float:
	## Çeyrekler arası ortalama: sıralı listenin ortadaki yarısının ortalaması. Dalga sonuçları boss dalgalarında
	## kümelendiği için (5/10/25…) az tohumda medyan bir kümeden ötekine sıçrar; IQM medyanın sağlam karşılığıdır.
	if values.is_empty():
		return 0.0
	var sorted: Array = values.duplicate()
	sorted.sort()
	var cut := sorted.size() / 4
	return mean(sorted.slice(cut, sorted.size() - cut))

static func scan_summary(entries: Dictionary, max_ratio: float) -> Dictionary:
	## Kırık kombinasyon taraması: entries = {ad: [dalga...]}. Kapı oranı = en iyi IQM / ortalama IQM (sağlam medyan);
	## düz medyan oranı da raporlanır (median_ratio).
	var medians := {}
	var iqms := {}
	var best := ""
	var best_v := -1.0
	var total := 0.0
	var best_med := -1.0
	var total_med := 0.0
	for k in entries:
		var md := quantile(entries[k], 0.5)
		var q := iqm(entries[k])
		medians[k] = _round(md)
		iqms[k] = _round(q)
		total += q
		total_med += md
		best_med = maxf(best_med, md)
		if q > best_v or (q == best_v and str(k) < best):
			best_v = q
			best = k
	var n := float(maxi(1, entries.size()))
	return {"entries": iqms, "medians": medians, "best": best, "best_median": _round(best_v), "mean_median": _round(total / n),
		"ratio": _round(best_v / maxf(0.001, total / n)), "median_ratio": _round(best_med / maxf(0.001, total_med / n)), "max_ratio": max_ratio}
