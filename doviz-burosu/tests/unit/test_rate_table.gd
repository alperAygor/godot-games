extends "res://tests/test_case.gd"
## RateTable: alış/satış tutarlılığı, deterministik enflasyon, gün ortası güncellemesi, tam sayı yuvarlama.

var book: CurrencyBook
var balance: Dictionary


func before_each() -> void:
	book = CurrencyBook.load_default()
	balance = JsonIO.read_dict("res://data/balance.json")


func _table(salt := "story") -> RateTable:
	return RateTable.new(book, balance, salt)


func test_day_one_mid_is_base_rate() -> void:
	var table := _table()
	for code in book.codes():
		assert_eq(table.mid_rate(code, 1), book.base_rate(code), code)
		assert_eq(table.mid_rate(code, 0), book.base_rate(code), "0. gün 1. gün gibi")


func test_buy_below_mid_below_sell_for_foreign() -> void:
	var table := _table()
	for code in book.foreign_codes():
		for day in range(1, 61):
			for midday in [false, true]:
				var r := table.rates(code, day, midday)
				assert_true(r["buy"] < r["mid"] and r["mid"] < r["sell"], "%s gün %d: %s" % [code, day, r])


func test_local_currency_is_identity() -> void:
	var table := _table()
	for day in [1, 5, 40]:
		var r := table.rates("PL", day)
		assert_eq(r["mid"], Money.RATE_SCALE)
		assert_eq(r["buy"], Money.RATE_SCALE)
		assert_eq(r["sell"], Money.RATE_SCALE)
		assert_eq(table.midday_mid_rate("PL", day), Money.RATE_SCALE)


func test_inflation_raises_rates_every_day() -> void:
	var table := _table()
	for code in book.foreign_codes():
		for day in range(2, 31):
			assert_true(table.mid_rate(code, day) > table.mid_rate(code, day - 1), "%s gün %d yükselmeli" % [code, day])
			assert_true(table.change_bp(code, day) > 0)
	assert_eq(table.change_bp("FED", 1), 0)


func test_fifteen_day_growth_is_in_expected_range() -> void:
	var table := _table()
	for code in book.foreign_codes():
		var growth := float(table.mid_rate(code, 15)) / float(book.base_rate(code))
		# günlük en az %0.4, en çok %2.0 artış x 14 gün
		assert_true(growth > 1.05 and growth < 1.33, "%s: %.3f" % [code, growth])


func test_same_salt_same_rates_regardless_of_query_order() -> void:
	var a := _table("daily-2026-10-26")
	var b := _table("daily-2026-10-26")
	var forward := []
	for day in range(1, 11):
		forward.append(a.mid_rate("AVR", day))
	var backward := []
	for day in range(10, 0, -1):
		backward.append(b.mid_rate("AVR", day))
	backward.reverse()
	assert_eq(forward, backward)


func test_different_salt_changes_rates() -> void:
	var a := _table("daily-2026-10-26")
	var b := _table("daily-2026-10-27")
	var differs := false
	for day in range(2, 11):
		if a.mid_rate("FED", day) != b.mid_rate("FED", day):
			differs = true
	assert_true(differs)


func test_midday_update_moves_rate_within_bounds() -> void:
	var table := _table()
	for code in book.foreign_codes():
		for day in range(1, 21):
			var morning := table.mid_rate(code, day)
			var afternoon := table.midday_mid_rate(code, day)
			var change := absi((afternoon - morning) * 10000 / morning)
			assert_true(afternoon != morning, "%s gün %d: gün ortası kur değişmeli" % [code, day])
			assert_true(change >= 70 and change <= 155, "%s gün %d: %d bp" % [code, day, change])
	assert_eq(table.rates("FED", 3, true)["mid"], table.midday_mid_rate("FED", 3))


func test_buy_payout_rounds_down_to_five_pl() -> void:
	var table := _table()
	# 1. gün FED: alış 297000 (= 29.70 PL). 100 FED -> 2970 PL tam.
	assert_eq(table.rates("FED", 1)["buy"], 297000)
	assert_eq(table.buy_payout("FED", Money.units(100), 1), Money.units(2970))
	# 1 FED -> 29.70 PL, 5 PL'nin katına aşağı: 25 PL.
	assert_eq(table.buy_payout("FED", Money.units(1), 1), Money.units(25))
	assert_eq(table.buy_payout("FED", 0, 1), 0)
	for code in book.foreign_codes():
		for denom in book.denominations(code):
			var minor := Money.units(denom)
			var payout := table.buy_payout(code, minor, 4)
			var exact := Money.mul_div_floor(minor, int(table.rates(code, 4)["buy"]), Money.RATE_SCALE)
			assert_eq(payout % 500, 0)
			assert_true(payout <= exact and exact - payout < 500, "%s %d: %d vs %d" % [code, denom, payout, exact])


func test_sell_cost_rounds_up_and_always_exceeds_payout() -> void:
	var table := _table()
	assert_eq(table.rates("FED", 1)["sell"], 303000)
	assert_eq(table.sell_cost("FED", Money.units(1), 1), Money.units(35), "30.30 PL -> 35 PL")
	assert_eq(table.sell_cost("FED", Money.units(100), 1), Money.units(3030))
	for code in book.foreign_codes():
		for denom in book.denominations(code):
			var minor := Money.units(denom)
			var cost := table.sell_cost(code, minor, 7)
			assert_eq(cost % 500, 0)
			assert_true(cost > table.buy_payout(code, minor, 7), "%s %d: satış alıştan pahalı olmalı" % [code, denom])


func test_payout_round_to_is_configurable() -> void:
	var custom := balance.duplicate(true)
	custom["money"]["payout_round_to"] = 100
	var table := RateTable.new(book, custom)
	assert_eq(table.buy_payout("FED", Money.units(1), 1), Money.units(29))
	assert_eq(table.sell_cost("FED", Money.units(1), 1), Money.units(31))


func test_midday_rate_changes_payout() -> void:
	var table := _table()
	var morning := table.buy_payout("DNR", Money.units(50), 9)
	var afternoon := table.buy_payout("DNR", Money.units(50), 9, true)
	assert_ne(morning, afternoon)
