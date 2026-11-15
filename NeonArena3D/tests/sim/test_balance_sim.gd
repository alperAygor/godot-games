extends TestCase
## Denge simülasyonu: belirlenimlilik, sonlanma, veri kapsamı, toplama (aggregate) mantığı. Hızlı: < ~3 sn.

const RunSimScript = preload("res://tests/sim/run_sim.gd")
const SimReportScript = preload("res://tests/sim/sim_report.gd")

func _sim() -> RunSim:
	var data := RunSimScript.load_data()
	check(not data.is_empty(), "sim veri dosyaları okunmalı")
	return RunSimScript.new(data)

func test_same_seed_same_result() -> void:
	var sim := _sim()
	var a := sim.play({"seed": 7, "ship": "vektor"})
	var b := sim.play({"seed": 7, "ship": "vektor"})
	eq(JSON.stringify(a, "", true), JSON.stringify(b, "", true), "aynı tohum aynı sonucu vermeli")
	# Aynı nesnede art arda ve yeni nesnede de aynı olmalı (durum sızıntısı yok).
	var c := _sim().play({"seed": 7, "ship": "vektor"})
	eq(JSON.stringify(a, "", true), JSON.stringify(c, "", true), "yeni simülatör de aynı sonucu vermeli")

func test_different_seeds_diverge() -> void:
	var sim := _sim()
	var kills := {}
	for s in [1, 2, 3, 4, 5]:
		kills[sim.play({"seed": s, "ship": "vektor"})["score"]] = true
	gt(float(kills.size()), 1.0, "farklı tohumlar farklı koşular üretmeli")

func test_every_ship_run_ends() -> void:
	var sim := _sim()
	for ship in sim.ships:
		var r := sim.play({"seed": 3, "ship": str(ship["id"])})
		check(not bool(r["capped"]), "koşu zaman sınırından önce bitmeli: " + str(ship["id"]))
		gt(float(r["wave"]), 1.0, "ikinci dalgaya ulaşılmalı: " + str(ship["id"]))
		gt(float(r["kills"]), 2.0, "bot öldürebilmeli: " + str(ship["id"]))
		check(str(r["death_cause"]) != "", "ölüm nedeni kaydedilmeli: " + str(ship["id"]))

func test_workshop_power_does_not_hurt() -> void:
	var sim := _sim()
	var fresh: Array = []
	var maxed: Array = []
	var meta_max := sim.meta_for_fraction(1.0)
	for s in 8:
		fresh.append(sim.play({"seed": 100 + s, "ship": "vektor"})["wave"])
		maxed.append(sim.play({"seed": 100 + s, "ship": "vektor", "meta": meta_max})["wave"])
	gt(SimReportScript.mean(maxed) + 0.5, SimReportScript.mean(fresh), "tam atölye boş atölyeden kötü olmamalı")

func test_meta_fraction_spends_budget() -> void:
	var sim := _sim()
	var total := 0
	for def in sim.upgrades:
		for c in def["costs"]:
			total += int(c)
	var full := sim.meta_for_fraction(1.0)
	var none := sim.meta_for_fraction(0.0)
	var half := sim.meta_for_fraction(0.5)
	eq(full.cores, 0, "tam harcamada bakiye kalmamalı")
	eq(none.cores, total, "sıfır harcamada tüm bütçe kalmalı")
	check(half.cores > 0 and half.cores < total, "yarı harcama arada kalmalı")

func test_model_covers_game_data() -> void:
	var sim := _sim()
	var known := ["blaster", "scatter", "rail", "rocket"]
	for ship in sim.ships:
		check(str(ship["weapon"]["type"]) in known, "model bu silah tipini bilmeli: " + str(ship["weapon"]["type"]))
		check((sim.model["accuracy"] as Dictionary).has(str(ship["weapon"]["type"])), "isabet sabiti olmalı: " + str(ship["weapon"]["type"]))
	for kind in sim.bal["boss_kinds"]:
		check(sim.model["boss_patterns"].has(kind), "boss kalıp tablosu olmalı: " + kind)
		check(sim.model["boss_summons"].has(kind), "boss çağırma tablosu olmalı: " + kind)
	for theme in sim.maps:
		check(sim.bal["boss_kinds"].has(str(theme["boss"])), "harita boss türü balance.json'da olmalı: " + str(theme["boss"]))
	var greedy: Dictionary = sim.model["policies"]["greedy"]["weights"]
	for card in sim.cards:
		for key in card["effect"]:
			check(greedy.has(key), "greedy ağırlığı eksik: %s (%s)" % [key, card["id"]])
	for kind in sim.bal["enemies"]:
		check(sim.bal["enemies"][kind].has("hp"), "düşman hp'si olmalı: " + kind)
	for build in sim.model["builds"]:
		for id in sim.model["builds"][build]:
			check(not sim.cards.filter(func(c): return c["id"] == id).is_empty(), "yapı kartı veride olmalı: " + str(id))

func test_boss_waves_spawn_a_boss() -> void:
	var sim := _sim()
	var r := sim.play({"seed": 5, "ship": "vektor", "meta": sim.meta_for_fraction(1.0)})
	gt(float(r["wave"]), 5.0, "tam atölyeyle ilk boss dalgasına varılmalı")
	check(int(r["bosses"]) >= 1 or r["death_cause"].begins_with("boss") or r["wave"] == 5, "5. dalgada boss çıkmalı")

func test_summarize_and_quantiles() -> void:
	near(SimReportScript.quantile([1, 2, 3, 4, 5], 0.5), 3.0, 0.0001, "medyan")
	near(SimReportScript.quantile([1, 2, 3, 4], 0.5), 2.5, 0.0001, "çift medyan")
	near(SimReportScript.quantile([], 0.5), 0.0, 0.0001, "boş liste 0 dönmeli")
	near(SimReportScript.mean([2, 4]), 3.0, 0.0001, "ortalama")

func test_card_stats_pick_rate_and_zero_pick_detection() -> void:
	var runs: Array = []
	for i in 30:
		runs.append({"wave": 10 + i % 3, "picks": [[["a", "b", "c"], "a", 3], [["a", "b", "d"], "b", 6]]})
	var stats := SimReportScript.card_stats(runs, ["a", "b", "c", "d", "z"], {"a": "common"})
	near(float(stats["a"]["pick_rate"]), 0.5, 0.0001, "a: 2 sunumdan 1 seçim")
	eq(int(stats["c"]["picked"]), 0, "c hiç seçilmedi")
	eq(int(stats["z"]["offered"]), 0, "z hiç sunulmadı")
	var report := {"overall": {"runs": 30, "capped": 0, "wave": {"median": 5.0}, "kills": {"median": 50.0}}, "meta": {}, "cards": stats}
	var problems := SimReportScript.check(report, true)
	check(problems.any(func(p): return "kart c" in str(p) and "%0" in str(p)), "sıfır seçimli kart yakalanmalı")
	check(problems.any(func(p): return "kart z" in str(p)), "hiç sunulmayan kart yakalanmalı")

func test_check_catches_unending_and_dead_games() -> void:
	var broken := {"overall": {"runs": 10, "capped": 9, "wave": {"median": 1.0}, "kills": {"median": 0.0}}, "meta": {"max_capped_share": 0.25}}
	var problems := SimReportScript.check(broken, false)
	gt(float(problems.size()), 2.0, "sonlanmayan + oynanamaz oyun birden çok sorun bildirmeli")
	var healthy := {"overall": {"runs": 10, "capped": 0, "wave": {"median": 8.0}, "kills": {"median": 90.0}}, "meta": {}}
	eq(SimReportScript.check(healthy, false).size(), 0, "sağlıklı rapor sorunsuz olmalı")

func test_career_terminates_and_spends() -> void:
	var sim := _sim()
	var c := sim.play_career({"seed": 2, "max_runs": 12, "run_cap": 300.0})
	check(int(c["runs"]) >= 1 and int(c["runs"]) <= 12, "kariyer koşu sınırına uymalı")
	gt(float(c["cores_earned"]), 0.0, "kariyer çekirdek kazanmalı")
	check(not (c["purchases"] as Array).is_empty(), "kariyer bir şey satın almalı")

# --- C1: koşu yapısı (sektörler, kapılar, zafer, ödül eğrisi) ---------------------------------------
func test_finite_modes_always_end() -> void:
	var sim := _sim()
	for mode in ["standard", "quick"]:
		for ship in sim.ships:
			var r := sim.play({"seed": 3, "ship": str(ship["id"]), "mode": mode, "meta": sim.meta_for_fraction(1.0)})
			check(not bool(r["capped"]), "%s koşusu bitmeli: %s" % [mode, ship["id"]])
			check(str(r["death_cause"]) != "", "%s bitiş nedeni kaydedilmeli: %s" % [mode, ship["id"]])
			check(int(r["wave"]) <= int(sim.bal["run"]["modes"][mode]["sectors"]) * int(sim.bal["run"]["modes"][mode]["waves_per_sector"]), "devamsız sonlu mod son dalgayı aşmaz: " + mode)

func test_victory_reachable_with_developed_workshop() -> void:
	var sim := _sim()
	var meta := sim.meta_for_fraction(1.0)
	var wins := 0
	for s in 6:
		var r := sim.play({"seed": 40 + s, "ship": "mizrak", "mode": "standard", "meta": meta})
		if bool(r["won"]):
			wins += 1
			eq(str(r["death_cause"]), "victory", "zafer bitiş nedeni")
			eq(int(r["sectors_cleared"]), 3, "zaferde 3 sektör")
	gt(float(wins), 0.0, "tam atölyeyle zafer erişilebilir olmalı")

func test_gates_never_produce_impossible_state() -> void:
	var sim := _sim()
	for policy in ["auto", "safe", "risky", "random"]:
		for s in 4:
			var r := sim.play({"seed": 60 + s, "ship": "vektor", "mode": "standard", "meta": sim.meta_for_fraction(0.6), "gate_policy": policy})
			eq((r["gate_errors"] as Array).size(), 0, "kapı hatası olmamalı (%s, tohum %d): %s" % [policy, 60 + s, str(r["gate_errors"])])
			check((r["gates"] as Array).size() <= 2, "standartta en fazla 2 kapı")

func test_continue_after_victory_and_rewards_capped() -> void:
	var sim := _sim()
	var meta := sim.meta_for_fraction(1.0)
	var cont: Dictionary = {}
	for s in 8:
		var r := sim.play({"seed": 80 + s, "ship": "mizrak", "mode": "standard", "meta": meta, "continue": true, "max_time": 900.0})
		if bool(r["won"]):
			cont = r
			break
	check(not cont.is_empty(), "zafer + devam eden koşu bulunmalı")
	if not cont.is_empty():
		check(bool(cont["continued"]) and int(cont["wave"]) > 15, "devamda 15. dalga aşılır")
	var std: Dictionary = sim.bal["run"]["modes"]["standard"]["reward"]
	var gates: Dictionary = sim.bal["run"]["gates"]["options"]
	var max_mult := 1.0 + 2.0 * float(gates["overload"]["reward_mult"])
	var core_mult := 1.0
	for def in sim.upgrades:
		if def["effect"].has("core_mult"):
			core_mult *= pow(1.0 + float(def["effect"]["core_mult"]), float((def["costs"] as Array).size()))
	var ceiling := (float(std["cap"]) + float(std["extra_cap"])) * max_mult * core_mult + 2.0 * float(gates["salvage"]["bank_cores"]) + 1.0
	if not cont.is_empty():
		check(float(cont["cores"]) <= ceiling, "standart ödülü üst sınırlı (%d ≤ %.0f)" % [int(cont["cores"]), ceiling])
	var endless := sim.play({"seed": 5, "ship": "mizrak", "mode": "endless", "meta": meta, "max_time": 900.0})
	check(float(endless["cores"]) <= float(sim.bal["run"]["modes"]["endless"]["reward"]["cap"]) * core_mult + 1.0, "sonsuz ödülü de sınırlı")

func test_endless_mode_matches_legacy_sim() -> void:
	## Sonsuz mod = eski oyun: aynı tohumla dalga/puan/öldürme eski (mod belirtilmeyen) koşuyla aynı.
	var sim := _sim()
	var a := sim.play({"seed": 9, "ship": "vektor"})
	var b := sim.play({"seed": 9, "ship": "vektor", "mode": "endless"})
	eq([a["wave"], a["score"], a["kills"], a["time"]], [b["wave"], b["score"], b["kills"], b["time"]], "sonsuz = eski akış")

func test_sector_table_and_checks() -> void:
	var runs: Array = []
	for i in 10:
		runs.append({"wave": 15 if i < 3 else 8, "cores": 100, "sectors_cleared": 3 if i < 3 else 1, "won": i < 3, "victory_time": 400.0, "gate_errors": [], "gates": ["repair"]})
	var t := SimReportScript.sector_table(runs, 3)
	near(float(t["victory_rate"]), 0.3, 0.0001, "zafer oranı")
	near(float(t["clear_rate"][0]), 1.0, 0.0001, "S1 oranı")
	near(float(t["clear_rate"][1]), 0.3, 0.0001, "S2 oranı")
	var bad := {"overall": {"runs": 10, "capped": 0, "wave": {"median": 8.0}, "kills": {"median": 50.0}}, "meta": {},
		"by_mode": {"standard": {"capped": 2}},
		"sectors": {"standard": {"maxed": {"runs": 8, "victory_rate": 0.0, "gate_errors": 1}}}}
	var problems := SimReportScript.check(bad, false)
	check(problems.any(func(p): return "zaman sınırına" in str(p)), "sonlanmayan sonlu mod yakalanmalı")
	check(problems.any(func(p): return "zafer erişilemez" in str(p)), "erişilemeyen zafer yakalanmalı")
	check(problems.any(func(p): return "kapı hatası" in str(p)), "kapı hatası yakalanmalı")
