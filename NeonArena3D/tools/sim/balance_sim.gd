extends SceneTree
## Başsız denge simülasyonu: gemi × atölye düzeyi × yapı × tohum ızgarasında bot koşuları + kariyer (atölye tüketimi).
## Saf mantık katmanını kullanır (tests/sim/run_sim.gd); sahne, çizim ve kayıt dosyası YOK.
##
##   godot --headless --path . -s res://tools/sim/balance_sim.gd -- --seeds=20 --out=build/sim/balance_report.json
##
## Bayraklar: --seeds=N (20) --seed-base=K (1) --ships=a,b|all --tiers=fresh,mid,maxed --builds=none,tank|all
##            --policies=random,greedy --careers=N (3) --career-policies=random,greedy --out=yol --quick (4 tohum, 1 kariyer) --runs (çıktıya koşu listesini ekle)
## Çıkış kodu: doğrulama başarısızsa 1. Aynı bayrak + aynı veri = aynı JSON (süre bilgisi JSON'a girmez).

const RunSimScript = preload("res://tests/sim/run_sim.gd")
const SimReportScript = preload("res://tests/sim/sim_report.gd")

func _arg(name: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + name + "="):
			return a.get_slice("=", 1)
	return fallback

func _flag(name: String) -> bool:
	return ("--" + name) in OS.get_cmdline_user_args()

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var started := Time.get_ticks_msec()
	var data := RunSimScript.load_data()
	if data.is_empty():
		printerr("SIM HATA: veri dosyaları okunamadı")
		quit(1)
		return
	var quick := _flag("quick")
	var seeds := int(_arg("seeds", "4" if quick else "20"))
	var seed_base := int(_arg("seed-base", "1"))
	var careers := int(_arg("careers", "1" if quick else "3"))
	var all_ships: Array = []
	for s in data["ships"]:
		all_ships.append(str(s["id"]))
	var ships: Array = all_ships if _arg("ships", "all") == "all" else Array(_arg("ships", "all").split(","))
	var tier_names: Array = Array(_arg("tiers", "fresh,mid,maxed").split(","))
	var build_names: Array = (data["model"]["builds"] as Dictionary).keys() if _arg("builds", "none") == "all" else Array(_arg("builds", "none").split(","))
	var policies: Array = Array(_arg("policies", "random").split(","))
	var out_path := _arg("out", "build/sim/balance_report.json")
	# Bayrak doğrulaması: yanlış ad sessizce başka bir şeye düşmesin.
	var bad: Array = []
	for ship in ships:
		if not (ship in all_ships):
			bad.append("gemi:" + str(ship))
	for tier in tier_names:
		if not (data["model"]["tiers"] as Dictionary).has(tier):
			bad.append("atölye düzeyi:" + str(tier))
	for build in build_names:
		if not (data["model"]["builds"] as Dictionary).has(build):
			bad.append("yapı:" + str(build))
	for pol in policies:
		if not (data["model"]["policies"] as Dictionary).has(pol):
			bad.append("politika:" + str(pol))
	if seeds <= 0 or not bad.is_empty():
		printerr("SIM HATA: geçersiz bayrak (%s)%s" % [", ".join(PackedStringArray(bad)), " seeds>=1 olmalı" if seeds <= 0 else ""])
		quit(2)
		return
	var sim := RunSimScript.new(data)
	var runs: Array = []
	for ship in ships:
		for tier in tier_names:
			var frac := float((data["model"]["tiers"] as Dictionary).get(tier, {}).get("fraction", 0.0))
			var meta := sim.meta_for_fraction(frac)
			for build in build_names:
				for policy in policies:
					for k in seeds:
						var seed_value := seed_base + k
						var r := sim.play({"seed": seed_value, "ship": ship, "meta": meta, "give": data["model"]["builds"].get(build, []), "policy": policy})
						r["tier"] = tier
						r["build"] = build
						runs.append(r.duplicate(true))
	var sim_ms := Time.get_ticks_msec() - started
	var career_results := {}
	var career_started := Time.get_ticks_msec()
	for cp in Array(_arg("career-policies", "random,greedy").split(",")):
		var list: Array = []
		for c in careers:
			list.append(sim.play_career({"seed": seed_base + c, "policy": cp}))
		career_results[cp] = list
	var career_ms := Time.get_ticks_msec() - career_started
	# Belirlenimlik öz-denetimi: aynı tohumla ilk koşuyu yeniden oyna.
	var first: Dictionary = runs[0]
	var again := sim.play({"seed": int(first["seed"]), "ship": first["ship"], "meta": sim.meta_for_fraction(float(data["model"]["tiers"][first["tier"]]["fraction"])), "give": data["model"]["builds"].get(first["build"], []), "policy": first["policy"]})
	var same := JSON.stringify(_strip(again), "", true) == JSON.stringify(_strip(first), "", true)
	var report := _build_report(data, runs, career_results, {
		"seeds": seeds, "seed_base": seed_base, "ships": ships, "tiers": tier_names, "builds": build_names, "policies": policies, "careers": careers,
	}, same)
	var problems := SimReportScript.check(report, runs.size() >= 40)
	report["assertions"] = {"failed": problems, "passed": problems.is_empty()}
	var text := JSON.stringify(report, "  ", true)
	var abs_path := out_path if out_path.is_absolute_path() else ProjectSettings.globalize_path("res://").path_join(out_path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	_protect_build_dir(abs_path)
	var f := FileAccess.open(abs_path, FileAccess.WRITE)
	if f == null:
		printerr("SIM HATA: rapor yazılamadı: " + abs_path)
		quit(1)
		return
	f.store_string(text + "\n")
	f.close()
	_print_headline(report)
	print("SÜRE: ızgara %.1f sn (%d koşu), kariyer %.1f sn (%d kariyer), toplam %.1f sn" % [float(sim_ms) / 1000.0, runs.size(), float(career_ms) / 1000.0, careers, float(Time.get_ticks_msec() - started) / 1000.0])
	print("RAPOR: " + abs_path)
	if problems.is_empty():
		print("SİM SONUÇ: geçti")
		quit(0)
	else:
		for p in problems:
			printerr("SIM HATA: " + str(p))
		print("SİM SONUÇ: başarısız")
		quit(1)

func _strip(r: Dictionary) -> Dictionary:
	var c := r.duplicate(true)
	c.erase("tier")
	c.erase("build")
	return c

func _build_report(data: Dictionary, runs: Array, career_results: Dictionary, meta: Dictionary, same: bool) -> Dictionary:
	var groups := {}
	var by_ship := {}
	var by_tier := {}
	var by_build := {}
	var by_policy := {}
	var bucket := {}
	for r in runs:
		var key := SimReportScript.group_key(r)
		if not bucket.has(key):
			bucket[key] = []
		(bucket[key] as Array).append(r)
		for pair in [[by_ship, r["ship"]], [by_tier, r["tier"]], [by_build, r["build"]], [by_policy, r["policy"]]]:
			var m: Dictionary = pair[0]
			if not m.has(pair[1]):
				m[pair[1]] = []
			(m[pair[1]] as Array).append(r)
	for key in bucket:
		groups[key] = SimReportScript.summarize(bucket[key])
	var card_ids: Array = []
	var tiers := {}
	for c in data["cards"]:
		card_ids.append(str(c["id"]))
		tiers[str(c["id"])] = str(c.get("tier", "?"))
	var random_runs: Array = []
	for r in runs:
		if r["policy"] == "random":
			random_runs.append(r)
	var report := {
		"meta": {"sim_version": RunSimScript.VERSION, "grid": meta, "runs": runs.size(), "max_capped_share": 0.25,
			"note": "Soyut dövüş modeli (tests/sim/sim_model.json); mutlak değerler değil, sürümler arası fark ve gemi/kart oranları anlamlıdır."},
		"overall": SimReportScript.summarize(runs),
		"groups": groups,
		"by_ship": _sum_map(by_ship), "by_tier": _sum_map(by_tier), "by_build": _sum_map(by_build), "by_policy": _sum_map(by_policy),
		"cards": SimReportScript.card_stats(random_runs, card_ids, tiers),
		"careers": _careers_by_policy(career_results),
		"determinism": {"same": same},
	}
	if _flag("runs"):
		report["run_list"] = runs
	return report

func _sum_map(m: Dictionary) -> Dictionary:
	var out := {}
	for k in m:
		out[k] = SimReportScript.summarize(m[k])
	return out

func _careers_by_policy(by_policy: Dictionary) -> Dictionary:
	var out := {}
	for p in by_policy:
		var summary := _career_summary(by_policy[p])
		if not summary.is_empty():
			out[p] = summary
	return out

func _career_summary(results: Array) -> Dictionary:
	if results.is_empty():
		return {}
	var runs_needed: Array = []
	var minutes: Array = []
	var cores: Array = []
	var exhausted := 0
	var plays := {}
	var first_wave: Array = []
	var last_wave: Array = []
	var first_buy := {}
	var end_plays := {}
	var end_waves := {}
	for cr in results:
		for k in cr["endgame_plays"]:
			end_plays[k] = int(end_plays.get(k, 0)) + int(cr["endgame_plays"][k])
			end_waves[k] = (end_waves.get(k, []) as Array) + (cr["endgame_waves"][k] as Array)
		runs_needed.append(cr["runs"])
		minutes.append(cr["minutes"])
		cores.append(cr["cores_earned"])
		if cr["exhausted"]:
			exhausted += 1
		for k in cr["ship_plays"]:
			plays[k] = int(plays.get(k, 0)) + int(cr["ship_plays"][k])
		var w: Array = cr["waves"]
		first_wave.append(SimReportScript.mean(w.slice(0, mini(5, w.size()))))
		last_wave.append(SimReportScript.mean(w.slice(maxi(0, w.size() - 5))))
		for p in cr["purchases"]:
			var item: String = p["item"]
			if not first_buy.has(item):
				first_buy[item] = []
			(first_buy[item] as Array).append(p["run"])
	var ship_runs := {}
	var total_plays := 0
	for k in plays:
		total_plays += int(plays[k])
	for k in plays:
		ship_runs[k] = SimReportScript._round(float(plays[k]) / float(maxi(1, total_plays)))
	var ship_buy_run := {}
	for item in first_buy:
		if (item as String).begins_with("s:"):
			ship_buy_run[item] = SimReportScript._round(SimReportScript.mean(first_buy[item]))
	var end_total := 0
	for k in end_plays:
		end_total += int(end_plays[k])
	var end_share := {}
	var end_wave_mean := {}
	for k in end_plays:
		end_share[k] = SimReportScript._round(float(end_plays[k]) / float(maxi(1, end_total)))
		end_wave_mean[k] = SimReportScript._round(SimReportScript.mean(end_waves[k]))
	return {
		"endgame_ship_share": end_share, "endgame_ship_mean_wave": end_wave_mean,
		"careers": results.size(), "exhausted": exhausted, "runs_to_exhaust": SimReportScript.dist(runs_needed),
		"play_minutes": SimReportScript.dist(minutes), "cores_earned": SimReportScript.dist(cores),
		"ship_usage_share": ship_runs, "ship_bought_at_run": ship_buy_run,
		"mean_wave_first5_runs": SimReportScript._round(SimReportScript.mean(first_wave)),
		"mean_wave_last5_runs": SimReportScript._round(SimReportScript.mean(last_wave)),
	}

func _print_headline(report: Dictionary) -> void:
	var o: Dictionary = report["overall"]
	print("== DENGE SİMÜLASYONU: %d koşu ==" % int(o["runs"]))
	print("medyan dalga %.1f (p10 %.1f, p90 %.1f) · medyan süre %.0f sn · medyan öldürme %.0f · zaman sınırına takılan %d" % [
		float(o["wave"]["median"]), float(o["wave"]["p10"]), float(o["wave"]["p90"]), float(o["time_s"]["median"]), float(o["kills"]["median"]), int(o["capped"])])
	for s in report["by_ship"]:
		var g: Dictionary = report["by_ship"][s]
		print("  gemi %-8s medyan dalga %5.1f · süre %5.0f sn · çekirdek/koşu %5.1f" % [s, float(g["wave"]["median"]), float(g["time_s"]["median"]), float(g["cores"]["mean"])])
	for t in report["by_tier"]:
		var g: Dictionary = report["by_tier"][t]
		print("  atölye %-6s medyan dalga %5.1f" % [t, float(g["wave"]["median"])])
	for p in report["careers"]:
		var cr: Dictionary = report["careers"][p]
		print("kariyer (%s kart politikası): %d/%d atölye+gemi tükendi · koşu sayısı medyan %.0f · oyun süresi medyan %.0f dk" % [p, int(cr["exhausted"]), int(cr["careers"]), float(cr["runs_to_exhaust"]["median"]), float(cr["play_minutes"]["median"])])

func _protect_build_dir(abs_path: String) -> void:
	## build/ altına yazılan çıktılar Godot tarafından kaynak sayılıp PCK'ya sızmasın: .gdignore koy.
	var marker := ProjectSettings.globalize_path("res://").path_join("build")
	if abs_path.begins_with(marker + "/") and not FileAccess.file_exists(marker + "/.gdignore"):
		var g := FileAccess.open(marker + "/.gdignore", FileAccess.WRITE)
		if g != null:
			g.close()
