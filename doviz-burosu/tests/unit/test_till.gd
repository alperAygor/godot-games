extends "res://tests/test_case.gd"
## Till: kupür bazlı kasa, tam tutar ödeme planı, kayıt.


func _till() -> Till:
	var till := Till.new()
	till.add("FED", 1, 3)
	till.add("FED", 5, 2)
	till.add("FED", 10, 1)
	return till


func test_totals_and_counts() -> void:
	var till := _till()
	assert_eq(till.count("FED", 5), 2)
	assert_eq(till.count("FED", 100), 0)
	assert_eq(till.count("AVR", 5), 0)
	assert_eq(till.total_minor("FED"), Money.units(3 + 10 + 10))
	assert_eq(till.total_minor("AVR"), 0)


func test_exact_payment_uses_available_notes() -> void:
	var till := _till()
	var plan := till.pay_plan("FED", Money.units(23))
	assert_true(plan["ok"])
	assert_eq(plan["notes"], {10: 1, 5: 2, 1: 3})
	assert_true(till.can_pay("FED", Money.units(8)), "5 + 3x1")
	assert_true(till.can_pay("FED", 0))


func test_payment_fails_when_denominations_do_not_fit() -> void:
	var till := _till()
	assert_false(till.can_pay("FED", Money.units(24)), "toplamdan fazla")
	assert_false(till.can_pay("FED", Money.units(4) + 50), "kuruşlu tutar")
	var small := Till.new()
	small.add("FED", 5, 4)
	assert_false(small.can_pay("FED", Money.units(3)), "1'lik yok")
	assert_false(small.can_pay("FED", Money.units(12)), "5'in katı değil")
	assert_true(small.can_pay("FED", Money.units(15)))
	assert_false(small.can_pay("STR", Money.units(5)), "olmayan para birimi")


func test_search_finds_non_greedy_solution() -> void:
	# 10'luk tek, 5'lik iki, 6'lık iki: 12 = 6+6 (açgözlü 10+? ile bulunamaz).
	var till := Till.new()
	till.add("DNR", 10, 1)
	till.add("DNR", 6, 2)
	till.add("DNR", 5, 1)
	var plan := till.pay_plan("DNR", Money.units(12))
	assert_true(plan["ok"])
	assert_eq(plan["notes"], {6: 2})


func test_take_removes_notes_and_is_atomic() -> void:
	var till := _till()
	var plan := till.pay_plan("FED", Money.units(11))
	assert_true(till.take("FED", plan["notes"]))
	assert_eq(till.total_minor("FED"), Money.units(12))
	assert_false(till.take("FED", {100: 1}))
	assert_eq(till.total_minor("FED"), Money.units(12), "başarısız take hiçbir şeyi değiştirmez")


func test_deposit_and_duplicate_are_independent() -> void:
	var till := _till()
	var copy := till.duplicate_till()
	var factory := NoteFactory.new(CurrencyBook.load_default(), Seed.rng("till"))
	copy.deposit(factory.make_genuine("FED", 20))
	assert_eq(copy.count("FED", 20), 1)
	assert_eq(till.count("FED", 20), 0)


func test_from_balance_only_includes_available_currencies() -> void:
	var book := CurrencyBook.load_default()
	var balance := JsonIO.read_dict("res://data/balance.json")
	var day1 := Till.from_balance(book, balance, 1)
	assert_true(day1.total_minor("PL") > Money.units(20000), "PL stoğu bol")
	assert_true(day1.total_minor("FED") > 0)
	assert_eq(day1.total_minor("AVR"), 0, "AVR 2. günde açılır")
	var day13 := Till.from_balance(book, balance, 13)
	assert_true(day13.total_minor("KRN") > 0)


func test_dict_roundtrip() -> void:
	var till := _till()
	var copy := Till.from_dict(JSON.parse_string(JSON.stringify(till.to_dict())))
	assert_eq(copy.to_dict(), till.to_dict())
	assert_eq(copy.total_minor("FED"), till.total_minor("FED"))
