extends RefCounted
## Denge hedefleri (T-B1): tüm botlar x tohumlar 15 gün oynar (gerçek oyun koşulu: hikaye + ofis açık), tekrar edilebilen
## bitişte DayRetry en kötü durumu varsayar (reklam yok: önce ücretsiz hak, sonra bedelli). Ölçüler `measure`, hedefler
## data/balance.json `targets`, denetim `check` (boş liste = hepsi tuttu). balance_sim.gd --table ve test_bot_balance.gd kullanır.

const BOTS := ["perfect", "careless", "cheater", "ally", "escaper", "merciful", "helper"]


static func targets() -> Dictionary:
	return JsonIO.read_dict("res://data/balance.json").get("targets", {}) as Dictionary


## Rüşvet teklifleri: gün -> en büyük "bribe" etiketli seçeneğin nakdi (kuruş). Hikaye verisinden okunur.
static func bribe_days() -> Dictionary:
	var db := StoryDb.load_default()
	var result := {}
	for day in range(1, 16):
		for beat: Dictionary in db.day_def(day).get("beats", []):
			for option: Dictionary in beat.get("choice", {}).get("options", []):
				var cash := int(option.get("effects", {}).get("cash_pl", 0))
				if str(option.get("tag", "")) == "bribe" and cash > 0:
					result[day] = maxi(int(result.get(day, 0)), Money.units(cash))
	return result


## Bir botun bir tohumdaki koşusu ve ölçüleri.
static func measure(bot_name: String, seed_key: String, days := 15, story := true, office := true) -> Dictionary:
	var t := targets()
	var career := Career.load_default("sim-%s" % seed_key)
	career.story_enabled = story
	career.office_enabled = office
	var bot := ClerkBot.new(bot_name, seed_key)
	var played := DayRetry.play_career(bot, career, days, int(t.get("sim_max_retries_per_day", 3)))
	var reports: Array = played["reports"]
	var attempts: Array = played["attempts"]
	var rent_minor := career.household.amount_minor("rent", int(career.household.expense_def("rent").get("first_day", 5)))
	var fire := int(JsonIO.get_path_value(JsonIO.read_dict("res://data/balance.json"), "shift.fire_mistakes", 8))
	var heavy_fine := Money.units(int(t.get("heavy_day_loss_pl", 100)))
	var lowest := 1 << 60
	var highest := -(1 << 60)
	var lowest_day := 0
	var mistakes := 0
	var fines := 0
	var unpaid := 0
	var max_day_mistakes := 0
	var heavy_days := 0
	var failures := 0
	var cash_by_day := {}
	for report: Dictionary in attempts:
		var s: Dictionary = report["shift"]
		var cash := int(report["household"]["cash_after"])
		if cash < lowest:
			lowest = cash
			lowest_day = int(report["day"])
		highest = maxi(highest, cash)
		var loss := int(s["fines_minor"]) + maxi(0, -int(s.get("directive_minor", 0)))
		var day_mistakes := int(s["mistake_transactions"])
		max_day_mistakes = maxi(max_day_mistakes, day_mistakes)
		if loss >= heavy_fine or day_mistakes >= fire - 1 or not str(report["over"]).is_empty():
			heavy_days += 1
		if not str(report["over"]).is_empty():
			failures += 1
	var arrears := 0
	for report: Dictionary in reports:
		for expense_id: Variant in report["household"]["unpaid"]:
			if bool(career.household.expense_def(str(expense_id)).get("counts_as_rent", false)):
				arrears += career.household.amount_minor(str(expense_id), int(report["day"]))
		mistakes += int(report["shift"]["mistake_transactions"])
		fines += int(report["shift"]["fines_minor"])
		unpaid += (report["household"]["unpaid"] as Array).size()
		cash_by_day[int(report["day"])] = int(report["household"]["cash_after"])
	var finished := not career.is_over() and career.day > days
	var ending := Endings.resolve(career)
	return {
		"bot": bot_name, "seed": seed_key, "finished": finished, "over": career.game_over, "days": reports.size(),
		"cash": career.household.cash_minor, "arrears": arrears, "standing": career.household.cash_minor - arrears, "lowest": lowest, "lowest_day": lowest_day, "highest": highest,
		"rent": rent_minor, "mistakes": mistakes, "fines": fines, "unpaid": unpaid, "max_day_mistakes": max_day_mistakes,
		"heavy_days": heavy_days, "failures": failures, "retries": int(played["retries"]), "retry_cost": int(played["retry_cost_minor"]),
		"inspector": career.inspector_chance_percent(), "cash_by_day": cash_by_day,
		"ending": str(ending.get("id", "-")) if finished or career.is_over() else "(%d)" % career.day,
	}


## Tüm botlar x tohumlar: {bot: [ölçü, ...]}.
static func run_all(seeds: Array, days := 15, story := true, office := true) -> Dictionary:
	var results := {}
	for bot_name: String in BOTS:
		var runs: Array = []
		for seed_key: Variant in seeds:
			runs.append(measure(bot_name, str(seed_key), days, story, office))
		results[bot_name] = runs
	return results


static func _pl(minor: int) -> String:
	return str(minor / Money.UNIT)


## Satır tablosu + bot ortalamaları (düz metin).
static func table(results: Dictionary) -> String:
	var lines: PackedStringArray = []
	lines.append("bot       tohum | bitti  son        | nakit borç  en_düşük(gün) dip/kira | hata ceza  ağır_gün başarısız tekrar(bedel) | müfettiş%")
	for bot_name: String in BOTS:
		if not results.has(bot_name):
			continue
		for run: Dictionary in results[bot_name]:
			lines.append("%-9s %5s | %-5s %-10s | %5s %4s %6s (%2d)   %5.2f   | %4d %5s %5d %9d %4d (%4s) | %3d" % [
				bot_name, run["seed"], "evet" if run["finished"] else str(run["over"]), run["ending"], _pl(run["cash"]), _pl(run["arrears"]),
				_pl(run["lowest"]), run["lowest_day"], float(run["lowest"]) / float(run["rent"]), run["mistakes"], _pl(run["fines"]),
				run["heavy_days"], run["failures"], run["retries"], _pl(run["retry_cost"]), run["inspector"]])
	lines.append("")
	lines.append("bot       | bitiren | ort.nakit-borç ort.en_düşük | ort.hata ort.ceza | ağır_gün>=1 | tekrar")
	for bot_name: String in BOTS:
		if not results.has(bot_name):
			continue
		var runs: Array = results[bot_name]
		var done := 0
		var cash := 0
		var low := 0
		var mistakes := 0
		var fines := 0
		var heavy := 0
		var retries := 0
		for run: Dictionary in runs:
			done += 1 if run["finished"] else 0
			cash += int(run["standing"])
			low += int(run["lowest"])
			mistakes += int(run["mistakes"])
			fines += int(run["fines"])
			heavy += 1 if int(run["heavy_days"]) > 0 else 0
			retries += int(run["retries"])
		var n := runs.size()
		lines.append("%-9s | %d/%d     | %6s %8s        | %5.1f %6s   | %d/%d        | %d" % [bot_name, done, n, _pl(cash / n), _pl(low / n),
			float(mistakes) / n, _pl(fines / n), heavy, n, retries])
	return "\n".join(lines)


## Hedefleri denetler; tutmayan her hedef için bir satır döner.
static func check(results: Dictionary, t: Dictionary = {}) -> Array[String]:
	var tg: Dictionary = t if not t.is_empty() else targets()
	var problems: Array[String] = []
	var perfect: Array = results.get("perfect", [])
	var bribes := bribe_days()
	var edge := float(tg.get("perfect_edge_rent_fraction", 0.3))
	var swing := float(tg.get("perfect_swing_rents", 1.0))
	var temptation := float(tg.get("bribe_cushion_ratio", 1.0))
	var perfect_by_seed := {}
	for run: Dictionary in perfect:
		perfect_by_seed[run["seed"]] = run
		if not run["finished"] or int(run["retries"]) > 0 or int(run["unpaid"]) > 0:
			problems.append("perfect %s: reklamsız, tekrarsız, her gideri ödeyerek bitirmeli (bitti=%s tekrar=%d ödenmeyen=%d)" % [run["seed"], run["finished"], run["retries"], run["unpaid"]])
		if float(run["lowest"]) >= edge * float(run["rent"]):
			problems.append("perfect %s: en düşük nakit %s PL, kiranın %.0f%%'inden (%s PL) az olmalı (kenarda)" % [run["seed"], _pl(run["lowest"]), edge * 100, _pl(int(edge * run["rent"]))])
		if float(int(run["highest"]) - int(run["lowest"])) < swing * float(run["rent"]):
			problems.append("perfect %s: nakit dalgalanması en az %.1f kira olmalı (%s PL)" % [run["seed"], swing, _pl(int(run["highest"]) - int(run["lowest"]))])
	for day: Variant in bribes:
		var cushion_total := 0
		for run: Dictionary in perfect:
			cushion_total += int(run["cash_by_day"].get(day, 0))
		var cushion := cushion_total / maxi(1, perfect.size())
		if float(bribes[day]) < temptation * float(cushion):
			problems.append("%d. gün rüşveti (%s PL) dürüst oyuncunun o akşamki ortalama nakdinin %%%.0f'inden (%s PL) küçük: cazip değil" % [day, _pl(bribes[day]), temptation * 100, _pl(int(temptation * cushion))])
	var careless_total := 0
	var perfect_total := 0
	var careless_above := 0
	var above_lines: Array[String] = []
	for run: Dictionary in results.get("careless", []):
		var ref: Dictionary = perfect_by_seed.get(run["seed"], {})
		if not ref.is_empty():
			careless_total += int(run["standing"])
			perfect_total += int(ref["standing"])
			if int(run["standing"]) >= int(ref["standing"]):
				careless_above += 1
				above_lines.append("careless %s: nakit-kira borcu (%s) mükemmelden (%s) az olmalı" % [run["seed"], _pl(run["standing"]), _pl(ref["standing"])])
		if int(run["heavy_days"]) < int(tg.get("careless_min_heavy_days", 1)):
			problems.append("careless %s: en az bir ağır ceza / kovulma riski günü olmalı" % run["seed"])
	var careless_runs: Array = results.get("careless", [])
	if float(careless_above) > float(tg.get("careless_max_share_above_perfect", 0.0)) * careless_runs.size():
		problems.append_array(above_lines)
	if careless_total >= perfect_total and not perfect.is_empty():
		problems.append("careless ortalaması mükemmelden düşük olmalı")
	var caught := 0
	var cheaters: Array = results.get("cheater", [])
	for run: Dictionary in cheaters:
		var ref: Dictionary = perfect_by_seed.get(run["seed"], {})
		var day13 := int(tg.get("cheater_ahead_on_day", 13))
		if not ref.is_empty() and int(run["cash_by_day"].get(day13, 0)) <= int(ref["cash_by_day"].get(day13, 0)):
			problems.append("cheater %s: %d. günde mükemmelden zengin olmalı" % [run["seed"], day13])
		if int(run["inspector"]) < int(tg.get("cheater_min_inspector_percent", 20)):
			problems.append("cheater %s: müfettiş riski en az %%%d olmalı (%d)" % [run["seed"], int(tg.get("cheater_min_inspector_percent", 20)), run["inspector"]])
		if run["over"] == "arrested":
			caught += 1
	if not cheaters.is_empty() and (caught < 1 or caught >= cheaters.size()):
		problems.append("cheater: bazı tohumlarda yakalanmalı, bazılarında kurtulmalı (%d/%d)" % [caught, cheaters.size()])
	for bot_name: String in tg.get("must_finish", ["ally", "merciful"]):
		for run: Dictionary in results.get(bot_name, []):
			if not run["finished"]:
				problems.append("%s %s: dürüst yol yaşanabilir kalmalı (bitiş: %s)" % [bot_name, run["seed"], run["over"]])
	return problems
