extends "res://tests/engine_case.gd"
## EveningPlan: akşam giderleri, seçim kuralları ve döviz birikimi.

var career: Career


func before_each() -> void:
	super.before_each()
	career = Career.load_default("evening-test")


func _plan(day := 5, cash_pl := -1) -> EveningPlan:
	career.day = day
	career.household.flags["mother_sick"] = day >= 6
	var shift := career.new_shift()
	shift.start()
	shift.advance(400.0)  # müşteri varsa beklesin; vardiya kapanmış sayılır
	if cash_pl >= 0:
		career.household.cash_minor = Money.units(cash_pl)
	return EveningPlan.new(career, shift)


func test_evening_adds_the_days_pay_exactly_once() -> void:
	career.day = 1
	var before := career.household.cash_minor
	var shift := career.new_shift()
	shift.start()
	shift.advance(400.0)
	var plan := EveningPlan.new(career, shift)
	assert_eq(plan.cash_minor(), before + Money.units(305))
	var again := EveningPlan.new(career, shift)
	assert_eq(again.cash_minor(), before + Money.units(305), "ikinci plan maaşı tekrar eklemez")


func test_default_selection_pays_everything_affordable_in_priority_order() -> void:
	var plan := _plan(10, 5000)
	assert_eq(plan.selected, ["rent", "medicine", "food", "heating"] as Array[String])
	assert_eq(plan.remaining_cash(), plan.cash_minor() - plan.selected_total())
	var poor := _plan(10, 200)  # kira + ilaç + yemek + ısınma karşılanamaz
	assert_true(poor.selected_total() <= poor.cash_minor())
	assert_false("rent" in poor.selected, "kira yetmiyor")


func test_cannot_select_what_the_cash_does_not_cover() -> void:
	var plan := _plan(5, 0)
	plan.selected.clear()
	career.household.cash_minor = plan.amount_of("food") + 100
	assert_true(plan.can_toggle("food"))
	assert_false(plan.can_toggle("rent"), "kira bu nakitle seçilemez")
	assert_true(plan.toggle("food"))
	assert_eq(plan.selected, ["food"] as Array[String])
	assert_false(plan.toggle("rent"), "yetmeyen gider seçilmez")
	assert_false(plan.toggle("food"), "ikinci dokunuş kaldırır")
	assert_eq(plan.selected, [] as Array[String])
	assert_true(plan.can_toggle("food"))


func test_selection_keeps_priority_order() -> void:
	var plan := _plan(5, 9000)
	plan.selected.clear()
	plan.toggle("heating")
	plan.toggle("rent")
	plan.toggle("food")
	assert_eq(plan.selected, ["rent", "food", "heating"] as Array[String])


func test_buying_savings_moves_cash_to_foreign_and_trims_the_selection() -> void:
	var plan := _plan(5, 1700)
	var all_selected := plan.selected.size()
	assert_eq(all_selected, 3)
	var cash_before := plan.cash_minor()
	var got := plan.buy_savings(Money.units(1000))
	assert_true(got > 0)
	assert_eq(plan.savings_minor(), got)
	assert_eq(plan.cash_minor(), cash_before - Money.units(1000))
	assert_true(plan.selected_total() <= plan.cash_minor(), "seçili giderler artık yeni nakde sığmalı")
	assert_true(plan.selected.size() < all_selected, "en düşük öncelikliler bırakıldı")
	assert_false("rent" in plan.selected, "kira 1.000 PL'den fazla; kalan nakde sığmaz")


func test_buy_and_sell_use_spread_and_value_follows_rates() -> void:
	var plan := _plan(5, 2000)
	var rates := plan.rates()
	var got := plan.buy_savings(Money.units(1000))
	assert_eq(got, Money.mul_div_floor(Money.units(1000), Money.RATE_SCALE, int(rates["sell"])))
	assert_true(plan.savings_value_minor() < Money.units(1000), "makas yüzünden değeri biraz düşük")
	var cash_before := plan.cash_minor()
	var back := plan.sell_savings(plan.savings_minor())
	assert_eq(plan.cash_minor(), cash_before + back)
	assert_eq(plan.savings_minor(), 0)
	assert_eq(plan.sell_savings(100), 0, "bozdurulacak birikim kalmadı")
	assert_eq(plan.buy_savings(Money.units(999999)), 0, "nakit yetmez")


func test_finish_pays_the_selected_expenses_and_moves_to_the_next_day() -> void:
	var plan := _plan(5, 5000)
	var cash_before := plan.cash_minor()
	var total := plan.selected_total()
	var report := plan.finish()
	assert_eq(report["day"], 5)
	assert_eq(report["household"]["unpaid"], [])
	assert_eq(career.household.cash_minor, cash_before - total)
	assert_eq(career.day, 6)
	assert_true(career.pending_report.is_empty())


func test_finishing_with_nothing_selected_hurts_the_family() -> void:
	var plan := _plan(3, 5000)
	plan.selected.clear()
	var report := plan.finish()
	assert_eq(report["household"]["unpaid"], ["food", "heating"])
	assert_eq(career.household.mood, 75)


func test_shop_lists_tools_with_prices_and_buying_trims_the_selection() -> void:
	var plan := _plan(7, 400)
	var ids := plan.shop().map(func(item: Dictionary) -> String: return item["id"])
	assert_eq(ids, ["magnifier", "counter", "rate_calc"])
	assert_eq(plan.shop()[0]["price_minor"], Money.units(60))
	var selected_before := plan.selected.size()
	var cash_before := plan.cash_minor()
	assert_true(plan.buy_tool("rate_calc"))
	assert_eq(plan.cash_minor(), cash_before - Money.units(200))
	assert_true(plan.selected_total() <= plan.cash_minor(), "seçili giderler yeni nakde sığmalı")
	assert_true(plan.selected.size() <= selected_before)
	assert_false(plan.buy_tool("rate_calc"), "aynı araç ikinci kez alınmaz")
	assert_true(career.has_tool("rate_calc"))
	assert_eq(plan.shop().size(), 2)


func test_buying_a_tool_without_enough_cash_changes_nothing() -> void:
	var plan := _plan(7, 0)
	career.household.cash_minor = Money.units(10)
	assert_false(plan.buy_tool("magnifier"))
	assert_eq(plan.cash_minor(), Money.units(10))
	assert_false(career.has_tool("magnifier"))
