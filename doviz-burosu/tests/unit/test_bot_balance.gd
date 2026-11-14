extends "res://tests/test_case.gd"
## Denge testleri: ClerkBot 15 gün oynar. Sayılar data/balance.json ve data/household.json ile ayarlanır;
## bu testler "mükemmel oyuncu reklamsız bitirir, dikkatsiz zorlanır, hilekar zengin ama yakalanabilir" kuralını korur.
## Elle sınamak için: godot --headless --path . -s res://tools/balance_sim.gd -- --bot=perfect --seed=1

const SEEDS := ["1", "2", "3", "4", "5", "6"]


func _play(bot_name: String, seed_key: String, days := 15) -> Dictionary:
	var career := Career.load_default("sim-%s" % seed_key)
	var reports := ClerkBot.new(bot_name, seed_key).play_career(career, days)
	var mistakes := 0
	var unpaid := 0
	var fines := 0
	for report in reports:
		mistakes += int(report["shift"]["mistake_transactions"])
		unpaid += (report["household"]["unpaid"] as Array).size()
		fines += int(report["shift"]["fines_minor"])
	return {"career": career, "reports": reports, "mistakes": mistakes, "unpaid": unpaid, "fines": fines,
		"cash": career.household.cash_minor, "over": career.game_over}


func test_perfect_bot_never_makes_a_mistake_and_finishes_without_ads() -> void:
	for seed_key in SEEDS:
		var run := _play("perfect", seed_key)
		assert_eq(run["reports"].size(), 15, "tohum %s: 15 gün" % seed_key)
		assert_eq(run["over"], "", "tohum %s: oyun bitmedi" % seed_key)
		assert_eq(run["mistakes"], 0, "tohum %s: mükemmel botun hatası olmamalı" % seed_key)
		assert_eq(run["unpaid"], 0, "tohum %s: hiçbir gider ödenmemiş kalmamalı" % seed_key)
		assert_eq(run["career"].household.mood, 100)


func test_perfect_bot_ends_with_positive_but_small_cash() -> void:
	for seed_key in SEEDS:
		var cash_pl: int = _play("perfect", seed_key)["cash"] / Money.UNIT
		assert_true(cash_pl > 20, "tohum %s: kalan para pozitif olmalı (%d PL)" % [seed_key, cash_pl])
		assert_true(cash_pl < 1000, "tohum %s: kalan para küçük kalmalı (%d PL)" % [seed_key, cash_pl])


func test_perfect_bot_buys_every_tool_and_still_pays_every_expense() -> void:
	# Araçlar (60 + 120 + 200 PL) akşam dükkanından alınır; gider ve ruh hali etkilenmemeli.
	for seed_key in SEEDS:
		var run := _play("perfect", seed_key)
		var career: Career = run["career"]
		for tool_id in ["uv", "magnifier", "counter", "rate_calc"]:
			assert_true(career.has_tool(tool_id), "tohum %s: %s alınmış olmalı" % [seed_key, tool_id])
		assert_eq(run["unpaid"], 0)
		assert_eq(career.household.mood, 100)


func test_careless_bot_does_not_buy_tools() -> void:
	var career: Career = _play("careless", "1")["career"]
	assert_false(career.has_tool("magnifier"))


func test_perfect_bot_is_squeezed_by_inflation_in_the_second_half() -> void:
	# Maaş sabit, giderler enflasyonla artar: günlük kazanç farkı (maaş - gider) ikinci yarıda küçülür.
	var run := _play("perfect", "1")
	var reports: Array = run["reports"]
	# (4. ve 7. günlerde araç alındığı için araçsız günler karşılaştırılır: 3. ve 13. gün.)
	var early := int(reports[2]["household"]["cash_after"]) - int(reports[1]["household"]["cash_after"])
	var late := int(reports[12]["household"]["cash_after"]) - int(reports[11]["household"]["cash_after"])
	assert_true(late < early, "13. gün birikimi 3. günden düşük olmalı (%d < %d)" % [late, early])


func test_careless_bot_struggles_and_ends_poorer_than_the_perfect_one() -> void:
	var careless_total := 0
	var perfect_total := 0
	for seed_key in SEEDS:
		var careless := _play("careless", seed_key)
		assert_true(careless["mistakes"] >= 15, "tohum %s: %%15 hata ~30 hatalı işlem verir (%d)" % [seed_key, careless["mistakes"]])
		assert_true(careless["fines"] > 0 or careless["unpaid"] > 0, "tohum %s: en az bir kez ceza yer ya da gider ödeyemez" % seed_key)
		careless_total += int(careless["cash"])
		perfect_total += int(_play("perfect", seed_key)["cash"])
	# Mükemmel bot araçlara 380 PL harcadı; adil kıyas için onu geri ekle.
	var perfect_equivalent: int = perfect_total + SEEDS.size() * Money.units(380)
	assert_true(careless_total < perfect_equivalent / 2, "dikkatsiz bot belirgin biçimde daha yoksul olmalı")


func test_cheater_gets_richer_until_the_inspector_arrives() -> void:
	var caught := 0
	for seed_key in SEEDS:
		var cheater := _play("cheater", seed_key)
		var perfect := _play("perfect", seed_key)
		var skimmed := 0
		for report in cheater["reports"]:
			skimmed += int(report["shift"]["skim_minor"])
		assert_true(skimmed > Money.units(100), "tohum %s: gizli kâr birikmeli (%d)" % [seed_key, skimmed / 100])
		assert_eq(cheater["mistakes"], 0, "kesinti hata sayılmaz")
		var day13_cheater := int(cheater["reports"][12]["household"]["cash_after"])
		var day13_perfect := int(perfect["reports"][12]["household"]["cash_after"])
		assert_true(day13_cheater > day13_perfect, "tohum %s: 13. günde hilekar daha zengin" % seed_key)
		if cheater["over"] == "arrested":
			caught += 1
			assert_eq(cheater["reports"].size(), 14, "müfettiş 14. günde gelir")
	assert_true(caught >= 1 and caught < SEEDS.size(), "hilekar bazen yakalanır, bazen kurtulur (%d/%d)" % [caught, SEEDS.size()])


func test_the_boss_offer_starts_on_day_eight() -> void:
	var run := _play("cheater", "1", 7)
	for report in run["reports"]:
		assert_eq(report["shift"]["skim_minor"], 0, "8. günden önce kesinti yok")


func test_bots_are_deterministic() -> void:
	for bot_name in ["perfect", "careless", "cheater"]:
		var first := _play(bot_name, "7", 8)
		var second := _play(bot_name, "7", 8)
		assert_eq(first["cash"], second["cash"], bot_name)
		assert_eq(first["mistakes"], second["mistakes"], bot_name)


func test_every_shift_serves_a_reasonable_number_of_customers() -> void:
	var run := _play("perfect", "2")
	for report in run["reports"]:
		var served := int(report["shift"]["served"])
		assert_true(served >= 8 and served <= 18, "gün %d: %d müşteri" % [report["day"], served])
