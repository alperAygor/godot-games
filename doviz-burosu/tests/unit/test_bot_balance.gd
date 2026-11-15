extends "res://tests/test_case.gd"
## Denge testleri (T-B1): ClerkBot'lar gerçek oyun koşulunda (hikaye + ofis açık) 15 gün oynar; kovulunca reklamsız tekrar
## (DayRetry: önce ücretsiz hak, sonra bedelli). Hedefler data/balance.json `targets`, denetim tools/balance_targets.gd:
## mükemmel oyuncu reklamsız bitirir ama bir kez kenara gelir; dikkatsiz daha yoksul ve ağır ceza görür; hilekar kısa vadede
## kazançlı ama müfettiş riski gerçek; rüşvet dürüst oyuncunun o akşamki nakdine göre cazip; dürüst hikaye yolları yaşanabilir.
## Elle: godot --headless --path . -s res://tools/balance_sim.gd -- --table --seeds=5 [--assert]

const Targets := preload("res://tools/balance_targets.gd")
const SEEDS := ["1", "2", "3", "4", "5"]

static var _cache: Dictionary = {}


func _results() -> Dictionary:
	if _cache.is_empty():
		_cache = Targets.run_all(SEEDS)
	return _cache


func test_all_balance_targets_hold_for_every_bot_and_five_seeds() -> void:
	var results := _results()
	for bot_name: String in Targets.BOTS:
		assert_eq((results[bot_name] as Array).size(), SEEDS.size(), bot_name)
	var problems := Targets.check(results)
	assert_eq(problems, [] as Array[String], "\n" + Targets.table(results))


func test_the_check_fails_when_a_target_is_broken() -> void:
	var results := _results()
	var strict := Targets.targets().duplicate(true)
	strict["perfect_edge_rent_fraction"] = 0.0  # hiçbir nakit kiranın %0'ından az olamaz
	assert_false(Targets.check(results, strict).is_empty(), "kenar hedefi bozulunca denetim yakalamalı")
	var greedy := Targets.targets().duplicate(true)
	greedy["bribe_cushion_ratio"] = 100.0
	assert_false(Targets.check(results, greedy).is_empty(), "rüşvet hedefi bozulunca denetim yakalamalı")
	var lenient := Targets.targets().duplicate(true)
	lenient["careless_min_heavy_days"] = 99
	assert_false(Targets.check(results, lenient).is_empty())


func test_perfect_bot_never_makes_a_mistake_and_finishes_without_ads_or_retries() -> void:
	for run: Dictionary in _results()["perfect"]:
		assert_true(run["finished"], "tohum %s: 15 gün" % run["seed"])
		assert_eq(run["mistakes"], 0)
		assert_eq(run["unpaid"], 0, "tohum %s: her gider ödendi" % run["seed"])
		assert_eq(run["retries"], 0)
		assert_eq(run["ending"], "honest")


func test_perfect_bot_ends_with_positive_but_small_cash() -> void:
	for run: Dictionary in _results()["perfect"]:
		var cash_pl: int = int(run["cash"]) / Money.UNIT
		assert_true(cash_pl >= 0 and cash_pl < 1000, "tohum %s: kalan para küçük (%d PL)" % [run["seed"], cash_pl])


func test_careless_bot_ends_poorer_on_average_and_pays_fines() -> void:
	var careless := 0
	var perfect := 0
	for run: Dictionary in _results()["careless"]:
		assert_true(int(run["mistakes"]) >= 15, "tohum %s: %%15 hata ~30 hatalı işlem verir (%d)" % [run["seed"], run["mistakes"]])
		assert_true(int(run["fines"]) > 0)
		careless += int(run["standing"])
	for run: Dictionary in _results()["perfect"]:
		perfect += int(run["standing"])
	assert_true(careless < perfect, "dikkatsiz bot ortalamada daha yoksul (%d < %d)" % [careless, perfect])


func test_cheater_is_ahead_on_day_thirteen_but_sometimes_caught() -> void:
	var caught := 0
	for run: Dictionary in _results()["cheater"]:
		assert_eq(run["mistakes"], 0, "kesinti hata sayılmaz")
		assert_true(int(run["inspector"]) > 0)
		if run["over"] == "arrested":
			caught += 1
			assert_eq(run["days"], 14, "müfettiş 14. günde gelir")
	assert_true(caught >= 1 and caught < SEEDS.size(), "hilekar bazen yakalanır (%d/%d)" % [caught, SEEDS.size()])


func test_bribes_are_read_from_the_story_and_fall_on_rent_days() -> void:
	var bribes := Targets.bribe_days()
	assert_true(bribes.size() >= 2)
	var home := Household.load_default()
	for day: Variant in bribes:
		var rent_due := home.due_expenses(int(day)).any(func(e: Dictionary) -> bool: return e["id"] == "rent")
		assert_true(rent_due, "%d. gün rüşveti kira gününe denk gelir (cazibe)" % day)


func test_a_very_careless_player_is_fired_and_recovers_with_retries_without_ads() -> void:
	var career := Career.load_default("sim-fire")
	career.story_enabled = true
	career.office_enabled = true
	var bot := ClerkBot.new("careless", "fire")
	bot.profile = bot.profile.duplicate()
	bot.profile["error_percent"] = 55  # bir günde kovulma sınırına varır
	var played := DayRetry.play_career(bot, career, 4, 3)
	var failed := (played["attempts"] as Array).filter(func(r: Dictionary) -> bool: return r["over"] == "fired")
	assert_true(failed.size() >= 1, "kovulma gerçekten olur")
	assert_true(int(played["retries"]) >= 1, "kovulunca reklamsız tekrar var")
	assert_true(int(played["retry_cost_minor"]) >= 0)


func test_the_boss_offer_starts_on_day_eight() -> void:
	var career := Career.load_default("sim-1")
	for report in ClerkBot.new("cheater", "1").play_career(career, 7):
		assert_eq(report["shift"]["skim_minor"], 0, "8. günden önce kesinti yok")


func test_careless_bot_does_not_buy_tools() -> void:
	var career := Career.load_default("sim-1")
	ClerkBot.new("careless", "1").play_career(career, 15)
	assert_false(career.has_tool("magnifier"))


func test_bots_are_deterministic() -> void:
	for bot_name in ["perfect", "careless", "cheater"]:
		var first := Targets.measure(bot_name, "7", 8)
		var second := Targets.measure(bot_name, "7", 8)
		assert_eq(first["cash"], second["cash"], bot_name)
		assert_eq(first["mistakes"], second["mistakes"], bot_name)


func test_every_shift_serves_a_reasonable_number_of_customers() -> void:
	var career := Career.load_default("sim-2")
	for report in ClerkBot.new("perfect", "2").play_career(career, 15):
		var served := int(report["shift"]["served"])
		assert_true(served >= 8 and served <= 18, "gün %d: %d müşteri" % [report["day"], served])
