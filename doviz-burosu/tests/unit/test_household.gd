extends "res://tests/test_case.gd"
## Household: enflasyonlu giderler, ödeme/ödememe sonuçları, eviction, döviz birikimi.

var home: Household
var rates: RateTable


func before_each() -> void:
	home = Household.load_default()
	rates = RateTable.new(CurrencyBook.load_default(), JsonIO.read_dict("res://data/balance.json"))


func _ids(due: Array[Dictionary]) -> Array:
	return due.map(func(e: Dictionary) -> String: return e["id"])


func test_starting_state() -> void:
	assert_eq(home.cash_minor, Money.units(300))
	assert_eq(home.mood, 100)
	assert_eq(home.rent_missed, 0)
	assert_eq(home.game_over_reason(), "")


func test_inflation_index_compounds_daily() -> void:
	assert_eq(home.inflation_index(1), 10000)
	assert_eq(home.inflation_index(2), 10150)
	assert_eq(home.inflation_index(3), 10302)
	assert_true(home.inflation_index(15) > 12000 and home.inflation_index(15) < 12500)


func test_expense_amounts_grow_with_inflation_and_round_up_to_five_pl() -> void:
	assert_eq(home.amount_minor("food", 1), Money.units(110))
	assert_eq(home.amount_minor("food", 2), Money.units(115), "111,65 -> 115")
	for day in range(1, 16):
		for expense in ["food", "heating", "medicine", "rent"]:
			assert_eq(home.amount_minor(expense, day) % 500, 0, "%s gün %d 5 PL'nin katı" % [expense, day])
		assert_true(home.amount_minor("food", day + 1) >= home.amount_minor("food", day), "fiyat düşmez")
	assert_true(home.amount_minor("rent", 15) > home.amount_minor("rent", 5), "kira da enflasyonla artar")


func test_due_expenses_by_day_and_flag() -> void:
	assert_eq(_ids(home.due_expenses(1)), ["food"])
	assert_eq(_ids(home.due_expenses(2)), ["food"])
	assert_eq(_ids(home.due_expenses(3)), ["food", "heating"])
	assert_eq(_ids(home.due_expenses(5)), ["rent", "food", "heating"], "öncelik sırası: kira önce")
	assert_eq(_ids(home.due_expenses(6)), ["food", "heating"], "anne hasta değil")
	home.flags["mother_sick"] = true
	assert_eq(_ids(home.due_expenses(6)), ["medicine", "food", "heating"])
	assert_eq(_ids(home.due_expenses(10)), ["rent", "medicine", "food", "heating"])


func test_paying_spends_cash_and_keeps_family_happy() -> void:
	home.cash_minor = Money.units(1000)
	var report := home.settle_day(3, ["food", "heating"])
	assert_eq(report["paid"], ["food", "heating"])
	assert_eq(report["unpaid"], [])
	assert_eq(home.cash_minor, Money.units(1000) - home.amount_minor("food", 3) - home.amount_minor("heating", 3))
	assert_eq(home.mood, 100)
	assert_eq(report["over"], "")


func test_unpaid_expense_lowers_mood_and_recovery_needs_a_clean_day() -> void:
	home.cash_minor = Money.units(1000)
	var report := home.settle_day(3, ["food"])  # ısınma ödenmedi: -10
	assert_eq(report["unpaid"], ["heating"])
	assert_eq(home.mood, 90)
	home.settle_day(4, ["food", "heating"])
	assert_eq(home.mood, 95, "tam ödenen günde +5")
	home.cash_minor = Money.units(5000)
	for i in 5:
		home.settle_day(4, ["food", "heating"])
	assert_eq(home.mood, 100, "üst sınır 100")


func test_cash_shortage_skips_what_does_not_fit() -> void:
	home.cash_minor = Money.units(120)
	var report := home.settle_day(3, ["food", "heating"])  # yemek 115, ısınma 55 -> yalnızca yemek
	assert_eq(report["paid"], ["food"])
	assert_eq(report["unpaid"], ["heating"])
	assert_eq(home.cash_minor, Money.units(120) - home.amount_minor("food", 3))
	var ignored := home.settle_day(3, ["rent", "food"])  # o gün vadesi gelmeyen gider ödenmez
	assert_false("rent" in ignored["paid"])


func test_missing_rent_twice_means_eviction() -> void:
	home.cash_minor = Money.units(5000)
	var first := home.settle_day(5, ["food", "heating"])
	assert_eq(first["unpaid"], ["rent"])
	assert_eq(first["rent_missed"], 1)
	assert_eq(first["over"], "", "ilk ödenmeyen kira evden atmaz")
	var second := home.settle_day(10, ["food", "heating"])
	assert_eq(second["rent_missed"], 2)
	assert_eq(second["over"], "evicted")
	assert_eq(home.game_over_reason(), "evicted")


func test_family_leaves_when_mood_runs_out() -> void:
	home.cash_minor = Money.units(5000)
	var over := ""
	var days := 0
	while over.is_empty() and days < 20:
		days += 1
		over = home.settle_day(3, [])["over"]  # her gün yemek + ısınma ödenmiyor: -25
	assert_eq(over, "family_left")
	assert_eq(days, 4, "100 -> 75 -> 50 -> 25 -> 0")


func test_foreign_savings_conversion_uses_sell_then_buy_rate() -> void:
	home.cash_minor = Money.units(1000)
	var foreign := home.convert_to_foreign("FED", Money.units(600), rates, 1)
	assert_true(foreign > 0)
	assert_eq(home.cash_minor, Money.units(400))
	assert_eq(home.savings["FED"], foreign)
	var sell := int(rates.rates("FED", 1)["sell"])
	assert_eq(foreign, Money.mul_div_floor(Money.units(600), Money.RATE_SCALE, sell))
	var back := home.convert_to_local("FED", foreign, rates, 1)
	assert_true(back < Money.units(600), "aynı gün geri bozdurmak makas kadar kaybettirir")
	assert_eq(home.cash_minor, Money.units(400) + back)


func test_savings_in_foreign_currency_protect_against_inflation() -> void:
	home.cash_minor = Money.units(1000)
	var before_worth := home.net_worth_minor(rates, 1)
	home.convert_to_foreign("FED", Money.units(1000), rates, 1)
	var worth_day1 := home.net_worth_minor(rates, 1)
	var worth_day15 := home.net_worth_minor(rates, 15)
	assert_true(worth_day1 < before_worth, "makas yüzünden başta küçük kayıp")
	assert_true(worth_day15 > before_worth, "15 gün sonra enflasyon dövizi değerlendirir")


func test_conversion_guards() -> void:
	home.cash_minor = Money.units(100)
	assert_eq(home.convert_to_foreign("FED", Money.units(500), rates, 1), 0, "nakit yetmez")
	assert_eq(home.convert_to_foreign("FED", 0, rates, 1), 0)
	assert_eq(home.convert_to_local("FED", Money.units(5), rates, 1), 0, "birikim yok")
	assert_eq(home.cash_minor, Money.units(100))


func test_dict_roundtrip() -> void:
	home.cash_minor = 123500
	home.savings = {"FED": 4200}
	home.mood = 70
	home.rent_missed = 1
	home.flags = {"mother_sick": true}
	var copy := Household.load_default()
	copy.load_dict(JSON.parse_string(JSON.stringify(home.to_dict())))
	assert_eq(copy.to_dict(), home.to_dict())
