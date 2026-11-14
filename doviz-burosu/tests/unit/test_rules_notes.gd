extends "res://tests/engine_case.gd"
## Banknot kuralları: R_EXCHANGE, R_CATALOG, R_UV, R_WATERMARK, R_MICROTEXT, R_SERIES, R_STOLEN, R_TORN.

const FED := "FED"


# --- R_EXCHANGE --------------------------------------------------------------

func test_exchange_pays_buy_rate_rounded_down() -> void:
	var ctx := make_ctx(1)
	var verdict := evaluate(seller(FED, [100], 1), ctx)
	assert_eq(verdict.decision, Verdict.DECISION_COMPLETE)
	assert_eq(verdict.pay_out, {"PL": Money.units(2970)})
	assert_eq(verdict.fates, [Verdict.FATE_ACCEPT] as Array[String])
	assert_eq(verdict.reasons, [] as Array[String])


func test_exchange_rounds_the_total_not_each_note() -> void:
	var ctx := make_ctx(1)
	var customer := seller(FED, [1, 1, 5, 5, 10], 1)
	var verdict := evaluate(customer, ctx)
	assert_eq(verdict.pay_out["PL"], Money.units(650), "22 FED x 29.70 = 653.40 -> 650")
	var per_note := 0
	for denom in [1, 1, 5, 5, 10]:
		per_note += ctx.rates.buy_payout(FED, Money.units(denom), 1)
	assert_ne(verdict.pay_out["PL"], per_note, "tek tek yuvarlamak farklı sonuç verirdi")


func test_exchange_uses_the_rate_of_the_day() -> void:
	var day1 := evaluate(seller(FED, [20], 1), make_ctx(1))
	var day5 := evaluate(seller(FED, [20], 5), make_ctx(5))
	assert_true(day5.pay_out["PL"] > day1.pay_out["PL"], "enflasyon: kur her gün yükselir")


# --- R_CATALOG / R_UV / R_WATERMARK / R_MICROTEXT ------------------------------

func _check_counterfeit_rule(rule_id: String, first_day: int, fakes: Array) -> void:
	for fake: String in fakes:
		var active := make_ctx(first_day)
		var verdict := evaluate(_single(fake_note(FED, 20, first_day, [fake])), active)
		assert_eq(verdict.decision, Verdict.DECISION_POLICE, "%s: %s polis" % [rule_id, fake])
		assert_eq(verdict.reasons, [rule_id] as Array[String], "%s: %s neden" % [rule_id, fake])
		assert_eq(verdict.fates, [Verdict.FATE_CONFISCATE] as Array[String])
		assert_eq(verdict.pay_out, {}, "polis kararında ödeme yok")
		# Kural açılmadan önceki gün aynı banknot görmezden gelinir.
		var inactive := make_ctx(first_day - 1)
		var calm := evaluate(_single(fake_note(FED, 20, first_day - 1, [fake])), inactive)
		assert_eq(calm.decision, Verdict.DECISION_COMPLETE, "%s kapalıyken %s yakalanmaz" % [rule_id, fake])
		assert_eq(calm.fates, [Verdict.FATE_ACCEPT] as Array[String])
	var genuine := evaluate(_single(factory.make_genuine(FED, 20, first_day)), make_ctx(first_day))
	assert_eq(genuine.decision, Verdict.DECISION_COMPLETE, "%s: gerçek banknot geçer" % rule_id)


func _single(note: Banknote) -> Customer:
	var customer := new_customer()
	customer.notes.append(note)
	return customer


func test_catalog_rule() -> void:
	_check_counterfeit_rule("R_CATALOG", 2, [Banknote.FAKE_COLOR, Banknote.FAKE_SIZE, Banknote.FAKE_PORTRAIT])


func test_uv_rule() -> void:
	_check_counterfeit_rule("R_UV", 3, [Banknote.FAKE_UV_MISSING, Banknote.FAKE_UV_COLOR])


func test_watermark_rule() -> void:
	_check_counterfeit_rule("R_WATERMARK", 9, [Banknote.FAKE_WM_MISSING, Banknote.FAKE_WM_SHAPE])


func test_microtext_rule() -> void:
	_check_counterfeit_rule("R_MICROTEXT", 13, [Banknote.FAKE_MICROTEXT])


func test_one_fake_among_genuine_notes_returns_the_rest() -> void:
	var ctx := make_ctx(3)
	var customer := new_customer()
	customer.notes.append(factory.make_genuine(FED, 10, 3))
	customer.notes.append(fake_note(FED, 20, 3, [Banknote.FAKE_UV_MISSING]))
	customer.notes.append(factory.make_genuine(FED, 5, 3))
	var verdict := evaluate(customer, ctx)
	assert_eq(verdict.decision, Verdict.DECISION_POLICE)
	assert_eq(verdict.fates, [Verdict.FATE_RETURN, Verdict.FATE_CONFISCATE, Verdict.FATE_RETURN] as Array[String])


func test_note_with_several_fakes_lists_every_active_rule() -> void:
	var ctx := make_ctx(9)
	var note := fake_note(FED, 20, 9, [Banknote.FAKE_WM_MISSING, Banknote.FAKE_COLOR, Banknote.FAKE_UV_COLOR])
	var verdict := evaluate(_single(note), ctx)
	assert_eq(verdict.reasons, ["R_CATALOG", "R_UV", "R_WATERMARK"] as Array[String], "dosya sırasıyla")
	# Mikro yazı kuralı henüz kapalı: bu sahtelik tek başına yakalanmaz.
	var only_micro := evaluate(_single(fake_note(FED, 20, 9, [Banknote.FAKE_MICROTEXT])), ctx)
	assert_eq(only_micro.decision, Verdict.DECISION_COMPLETE)


# --- R_SERIES ----------------------------------------------------------------

func test_old_series_is_returned_from_day_six() -> void:
	var old := factory.make_genuine("AVR", 20, 5, {"series_id": "AV1"})
	var customer := new_customer(Customer.INTENT_SELL, "AVR")
	customer.notes.append(old)
	assert_eq(evaluate(customer, make_ctx(5)).decision, Verdict.DECISION_COMPLETE, "5. günde eski seri hâlâ geçerli")
	var verdict := evaluate(customer, make_ctx(6))
	assert_eq(verdict.decision, Verdict.DECISION_REJECT, "tek banknot iade -> reddet")
	assert_eq(verdict.reasons, ["R_SERIES"] as Array[String])
	assert_eq(verdict.fates, [Verdict.FATE_RETURN] as Array[String])


func test_old_series_with_valid_note_completes_and_returns_the_old_one() -> void:
	var ctx := make_ctx(6)
	var customer := new_customer(Customer.INTENT_SELL, "AVR")
	customer.notes.append(factory.make_genuine("AVR", 10, 6, {"series_id": "AV1"}))
	customer.notes.append(factory.make_genuine("AVR", 5, 6))
	var verdict := evaluate(customer, ctx)
	assert_eq(verdict.decision, Verdict.DECISION_COMPLETE)
	assert_eq(verdict.fates, [Verdict.FATE_RETURN, Verdict.FATE_ACCEPT] as Array[String])
	assert_eq(verdict.pay_out["PL"], ctx.rates.buy_payout("AVR", Money.units(5), 6), "yalnızca geçerli banknot ödenir")


func test_new_series_is_fine() -> void:
	var customer := new_customer(Customer.INTENT_SELL, "AVR")
	customer.notes.append(factory.make_genuine("AVR", 20, 6, {"series_id": "AV2"}))
	assert_eq(evaluate(customer, make_ctx(6)).decision, Verdict.DECISION_COMPLETE)


# --- R_STOLEN ----------------------------------------------------------------

func _bulletin_with_range(from_number: int, to_number: int) -> Bulletin:
	var bulletin := Bulletin.new()
	bulletin.add_stolen(FED, "FD1", from_number, to_number)
	return bulletin


func _serial_customer(number: int, day: int) -> Customer:
	return _single(factory.make_genuine(FED, 20, day, {"series_id": "FD1", "serial_number": number}))


func test_stolen_range_edges_are_inclusive() -> void:
	var ctx := make_ctx(7, {"bulletin": _bulletin_with_range(1000, 1999)})
	for number in [1000, 1500, 1999]:
		var verdict := evaluate(_serial_customer(number, 7), ctx)
		assert_eq(verdict.decision, Verdict.DECISION_POLICE, "seri %d" % number)
		assert_eq(verdict.reasons, ["R_STOLEN"] as Array[String])
		assert_eq(verdict.fates, [Verdict.FATE_CONFISCATE] as Array[String])
	for number in [999, 2000, 0, 9999999]:
		assert_eq(evaluate(_serial_customer(number, 7), ctx).decision, Verdict.DECISION_COMPLETE, "seri %d" % number)


func test_stolen_rule_inactive_before_day_seven() -> void:
	var ctx := make_ctx(6, {"bulletin": _bulletin_with_range(0, 9999999)})
	assert_eq(evaluate(_serial_customer(1500, 6), ctx).decision, Verdict.DECISION_COMPLETE)


func test_stolen_only_matches_same_currency_and_series() -> void:
	var ctx := make_ctx(7, {"bulletin": _bulletin_with_range(1000, 1999)})
	var other_currency := _single(factory.make_genuine("AVR", 20, 7, {"serial_number": 1500}))
	assert_eq(evaluate(other_currency, ctx).decision, Verdict.DECISION_COMPLETE)


func test_stolen_and_torn_note_is_confiscated_not_returned() -> void:
	var ctx := make_ctx(8, {"bulletin": _bulletin_with_range(1000, 1999)})
	var note := factory.make_genuine(FED, 20, 8, {"series_id": "FD1", "serial_number": 1200, "torn": true})
	var verdict := evaluate(_single(note), ctx)
	assert_eq(verdict.decision, Verdict.DECISION_POLICE)
	assert_eq(verdict.fates, [Verdict.FATE_CONFISCATE] as Array[String], "el koy, iade değil")
	assert_eq(verdict.reasons, ["R_STOLEN"] as Array[String])


# --- R_TORN ------------------------------------------------------------------

func test_torn_boundary_is_half() -> void:
	var ctx := make_ctx(8)
	var below := _single(factory.make_genuine(FED, 20, 8, {"remaining_percent": 49}))
	var verdict := evaluate(below, ctx)
	assert_eq(verdict.decision, Verdict.DECISION_REJECT)
	assert_eq(verdict.reasons, ["R_TORN"] as Array[String])
	var half := _single(factory.make_genuine(FED, 20, 8, {"remaining_percent": 50}))
	assert_eq(evaluate(half, ctx).decision, Verdict.DECISION_COMPLETE, "tam yarısı kalan geçerli")


func test_taped_but_complete_note_is_valid() -> void:
	var taped := _single(factory.make_genuine(FED, 20, 8, {"taped": true}))
	var verdict := evaluate(taped, make_ctx(8))
	assert_eq(verdict.decision, Verdict.DECISION_COMPLETE)
	assert_eq(verdict.fates, [Verdict.FATE_ACCEPT] as Array[String])


func test_torn_note_ignored_before_rule_opens() -> void:
	var torn := _single(factory.make_genuine(FED, 20, 7, {"torn": true}))
	assert_eq(evaluate(torn, make_ctx(7)).decision, Verdict.DECISION_COMPLETE)


func test_torn_note_among_good_ones_is_returned_and_rest_paid() -> void:
	var ctx := make_ctx(8)
	var customer := new_customer()
	customer.notes.append(factory.make_genuine(FED, 20, 8, {"torn": true}))
	customer.notes.append(factory.make_genuine(FED, 10, 8))
	var verdict := evaluate(customer, ctx)
	assert_eq(verdict.decision, Verdict.DECISION_COMPLETE)
	assert_eq(verdict.fates, [Verdict.FATE_RETURN, Verdict.FATE_ACCEPT] as Array[String])
	assert_eq(verdict.pay_out["PL"], ctx.rates.buy_payout(FED, Money.units(10), 8))
