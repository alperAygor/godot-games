extends "res://tests/engine_case.gd"
## Career: gün döngüsü, maaş ve giderler, oyun bitişleri, müfettiş, araçlar, kayıt.

var career: Career


func before_each() -> void:
	super.before_each()
	career = Career.load_default("career-test")


func _close_day(paid: Array = []) -> Dictionary:
	var shift := career.new_shift()
	shift.start()
	shift.advance(400.0)  # müşteri varsa beklesin; vardiya kapanmış sayılır
	return career.finish_day(shift, paid)


func test_new_career_starts_with_basic_tools_and_cash() -> void:
	assert_eq(career.day, 1)
	assert_eq(career.tools, ["calculator", "catalog"] as Array[String])
	assert_eq(career.household.cash_minor, Money.units(300))
	assert_false(career.is_over())


func test_begin_day_unlocks_story_flags_and_free_tools() -> void:
	career.day = 2
	career.begin_day()
	assert_false(career.has_tool("uv"))
	assert_false(career.household.flags.has("mother_sick"))
	career.day = 3
	career.begin_day()
	assert_true(career.has_tool("uv"), "patron 3. günde UV lambası verir")
	career.day = 6
	career.begin_day()
	assert_true(career.household.flags["mother_sick"], "anne 6. günde hastalanır")
	assert_true("medicine" in career.household.due_expenses(6).map(func(e: Dictionary) -> String: return e["id"]))


func test_finish_day_adds_pay_pays_expenses_and_advances() -> void:
	var cash_before := career.household.cash_minor
	var report := _close_day(["food"])
	assert_eq(report["day"], 1)
	assert_eq(career.day, 2)
	assert_eq(career.history.size(), 1)
	var net := int(report["shift"]["net_minor"])
	assert_eq(career.household.cash_minor, cash_before + net - career.household.amount_minor("food", 1))
	assert_eq(report["over"], "")


func test_skim_profit_goes_to_cash_and_counts_for_the_inspector() -> void:
	var shift := career.new_shift()
	shift.start()
	shift.advance(400.0)
	shift.stats["skim_minor"] = 1500
	shift.stats["skim_count"] = 3
	var cash_before := career.household.cash_minor
	var net := int(shift.report()["net_minor"])
	career.finish_day(shift, [])
	assert_eq(career.household.cash_minor, cash_before + net + 1500)
	assert_eq(career.story.counter("skim_count"), 3)


func test_unpaid_rent_twice_ends_the_game_by_eviction() -> void:
	career.household.cash_minor = Money.units(99999)
	var over := ""
	while over.is_empty() and career.day < 30:
		var due := career.household.due_expenses(career.day).map(func(e: Dictionary) -> String: return e["id"])
		due.erase("rent")
		over = str(_close_day(due)["over"])
	assert_eq(over, "evicted")
	assert_eq(career.day, 10, "ikinci kira günü")
	assert_true(career.is_over())
	assert_eq(career.game_over, "evicted")


func test_family_leaves_if_nothing_is_paid() -> void:
	var over := ""
	while over.is_empty() and career.day < 30:
		over = str(_close_day([])["over"])
	assert_eq(over, "family_left")
	assert_true(career.day <= 6)


func test_too_many_mistaken_transactions_gets_you_fired() -> void:
	var shift := career.new_shift()
	shift.start()
	shift.advance(400.0)
	shift.stats["mistake_transactions"] = 8
	assert_eq(career.finish_day(shift, ["food"])["over"], "fired")
	assert_eq(career.game_over, "fired")
	var calm := Career.load_default("calm")
	var calm_shift := calm.new_shift()
	calm_shift.start()
	calm_shift.advance(400.0)
	calm_shift.stats["mistake_transactions"] = 7
	assert_eq(calm.finish_day(calm_shift, ["food"])["over"], "", "7 hatalı işlem henüz kovdurmaz")


func test_inspector_rolls_a_fixed_seeded_chance_that_grows_with_skims() -> void:
	var roll := Seed.rng("inspector|career-test").randi_range(1, 100)
	career.story.counters["skim_count"] = 0
	assert_false(career.inspector_catches(), "kesinti yoksa yakalanmaz")
	career.story.counters["skim_count"] = 1000
	assert_eq(career.inspector_catches(), roll <= 90, "olasılık üst sınırı %90")
	for skims in [1, 10, 25, 45, 60]:
		career.story.counters["skim_count"] = skims
		assert_eq(career.inspector_catches(), roll <= mini(90, skims * 2), "kesinti %d" % skims)


func test_inspector_only_acts_on_day_fourteen() -> void:
	career.story.counters["skim_count"] = 1000
	var sure := Career.load_default("career-test")
	sure.story.counters["skim_count"] = 1000
	var salts_caught := 0
	for salt in ["a", "b", "c", "d", "e", "f"]:
		var test_career := Career.load_default(salt)
		test_career.story.counters["skim_count"] = 1000
		test_career.day = 14
		var shift := test_career.new_shift()
		shift.start()
		shift.advance(400.0)
		var over := str(test_career.finish_day(shift, ["food", "heating", "medicine"])["over"])
		if over == "arrested":
			salts_caught += 1
		var early := Career.load_default(salt)
		early.story.counters["skim_count"] = 1000
		early.day = 13
		var early_shift := early.new_shift()
		early_shift.start()
		early_shift.advance(400.0)
		assert_ne(str(early.finish_day(early_shift, ["food", "heating", "medicine"])["over"]), "arrested", "13. günde müfettiş yok")
	assert_true(salts_caught >= 4 and salts_caught <= 6, "%%90 olasılıkla çoğu yakalanır: %d" % salts_caught)


func test_skim_offer_only_works_after_day_eight_and_when_accepted() -> void:
	career.day = 8
	assert_false(career.skim_active())
	career.accept_skim()
	assert_true(career.skim_active())
	career.day = 7
	assert_false(career.skim_active(), "öneri 8. günde gelir")
	career.day = 8
	assert_eq(career.new_shift().skim_minor, Money.units(5))


func test_buying_tools() -> void:
	career.household.cash_minor = Money.units(1000)
	career.day = 6
	assert_false(career.buy_tool("magnifier"), "büyüteç 7. günde açılır")
	career.day = 7
	assert_true(career.buy_tool("magnifier"))
	assert_eq(career.household.cash_minor, Money.units(940))
	assert_false(career.buy_tool("magnifier"), "ikinci kez alınmaz")
	assert_false(career.buy_tool("calculator"), "başlangıç aracı zaten var")
	career.household.cash_minor = Money.units(10)
	career.day = 9
	assert_false(career.buy_tool("rate_calc"), "nakit yetmiyor")
	assert_eq(career.tool_price_minor("rate_calc"), Money.units(200))
	assert_eq(career.tool_price_minor("yok"), -1)


func test_save_roundtrip_through_json() -> void:
	_close_day(["food"])
	career.accept_skim()
	career.household.savings = {"FED": 12000}
	var copy := Career.load_default("career-test")
	copy.load_dict(JSON.parse_string(JSON.stringify(career.to_dict())))
	assert_eq(copy.day, career.day)
	assert_eq(copy.household.cash_minor, career.household.cash_minor)
	assert_eq(copy.household.savings, career.household.savings)
	assert_eq(copy.household.mood, career.household.mood)
	assert_eq(copy.tools, career.tools)
	assert_true(copy.story.flag("skim_accepted"))
	assert_eq(copy.history.size(), 1)
	assert_eq(copy.game_over, "")


func test_replaying_the_day_returns_to_the_morning() -> void:
	career.day = 4
	career.begin_day()
	var morning_cash := career.household.cash_minor
	var shift := career.new_shift()
	shift.start()
	shift.advance(400.0)
	career.finish_day(shift, [])
	assert_eq(career.day, 5)
	assert_true(career.restore_morning())
	assert_eq(career.day, 4)
	assert_eq(career.household.cash_minor, morning_cash)
	assert_eq(career.history.size(), 0)
	assert_false(Career.load_default().restore_morning(), "anlık görüntü yoksa false")


func test_shop_only_offers_paid_unlocked_unowned_tools() -> void:
	career.day = 3
	assert_eq(career.buyable_tool_ids(), [] as Array[String], "3. günde satın alınacak bir şey yok (UV ücretsiz)")
	career.day = 4
	assert_eq(career.buyable_tool_ids(), ["counter", "rate_calc"] as Array[String])
	career.day = 7
	assert_eq(career.buyable_tool_ids(), ["magnifier", "counter", "rate_calc"] as Array[String])
	career.household.cash_minor = Money.units(5000)
	assert_true(career.buy_tool("counter"))
	assert_eq(career.buyable_tool_ids(), ["magnifier", "rate_calc"] as Array[String], "alınan araç listeden düşer")
