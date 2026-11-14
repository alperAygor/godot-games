extends "res://tests/engine_case.gd"
## İşlem kuralları: R_SELL_FOREIGN, R_ID_LIMIT, R_SOURCE, R_MIDDAY_RATE, R_WANTED ve öncelik sırası.

const FED := "FED"


# --- R_SELL_FOREIGN ----------------------------------------------------------

func test_buy_foreign_pays_from_till_at_sell_rate() -> void:
	var ctx := make_ctx(4)
	var customer := buyer(FED, 10, ctx)
	var verdict := evaluate(customer, ctx)
	assert_eq(verdict.decision, Verdict.DECISION_COMPLETE)
	assert_eq(verdict.pay_out, {FED: Money.units(10)}, "fazla PL yok, değişiklik yok")
	assert_eq(customer.nominal_minor("PL"), ctx.rates.sell_cost(FED, Money.units(10), 4), "müşteri tam tutarı getirdi")
	for fate in verdict.fates:
		assert_eq(fate, Verdict.FATE_ACCEPT)


func test_buy_foreign_gives_pl_change_when_customer_overpays() -> void:
	var ctx := make_ctx(4)
	var customer := buyer(FED, 10, ctx, 95)
	var verdict := evaluate(customer, ctx)
	assert_eq(verdict.decision, Verdict.DECISION_COMPLETE)
	assert_eq(verdict.pay_out, {FED: Money.units(10), "PL": Money.units(95)})


func test_till_stock_boundary() -> void:
	var ctx := make_ctx(4)  # kasada 23 FED: 3x1 + 2x5 + 1x10
	assert_eq(evaluate(buyer(FED, 23, ctx), ctx).decision, Verdict.DECISION_COMPLETE, "tam stok kadarı verilebilir")
	var over := evaluate(buyer(FED, 24, ctx), ctx)
	assert_eq(over.decision, Verdict.DECISION_REJECT, "bir fazlası yok")
	assert_eq(over.reasons, ["R_SELL_FOREIGN"] as Array[String])
	for fate in over.fates:
		assert_eq(fate, Verdict.FATE_RETURN, "reddetmede her şey iade")
	assert_eq(over.pay_out, {})


func test_till_cannot_make_exact_amount_with_its_denominations() -> void:
	var till := Till.new()
	till.add(FED, 5, 4)
	till.add("PL", 5, 100)
	var ctx := make_ctx(4, {"till": till})
	var verdict := evaluate(buyer(FED, 3, ctx), ctx)
	assert_eq(verdict.decision, Verdict.DECISION_REJECT, "1'lik banknot yok")
	assert_eq(verdict.reasons, ["R_SELL_FOREIGN"] as Array[String])
	assert_eq(evaluate(buyer(FED, 15, ctx), ctx).decision, Verdict.DECISION_COMPLETE)


func test_till_cannot_pay_pl_change() -> void:
	var till := Till.new()
	till.add(FED, 10, 5)
	var ctx := make_ctx(4, {"till": till})  # PL kasası boş
	assert_eq(evaluate(buyer(FED, 10, ctx), ctx).decision, Verdict.DECISION_COMPLETE, "değişiklik yoksa PL gerekmez; müşterinin PL'si girer")
	var change := evaluate(buyer(FED, 10, ctx, 95), ctx)
	assert_eq(change.decision, Verdict.DECISION_REJECT, "95 PL bozuk para üstü verilemez")


func test_customers_notes_can_fund_the_change() -> void:
	var till := Till.new()
	till.add(FED, 10, 5)  # PL yok, ama müşterinin getirdiği banknotlar kasaya girer
	var ctx := make_ctx(4, {"till": till})
	var customer := buyer(FED, 10, ctx, 0)
	assert_eq(evaluate(customer, ctx).decision, Verdict.DECISION_COMPLETE)


func test_stock_rule_is_inactive_before_day_four() -> void:
	var ctx := make_ctx(3, {"till": Till.new()})
	var customer := new_customer(Customer.INTENT_SELL)
	customer.notes.append(factory.make_genuine(FED, 10, 3))
	assert_eq(evaluate(customer, ctx).decision, Verdict.DECISION_COMPLETE, "kasa boş olsa da 4. günden önce kontrol yok")


func test_buy_foreign_with_too_little_pl_is_rejected() -> void:
	var ctx := make_ctx(4)
	var customer := new_customer(Customer.INTENT_BUY)
	customer.requested_foreign_minor = Money.units(10)
	customer.notes.append(factory.make_genuine("PL", 200, 4))  # 305 PL gerekir
	var verdict := evaluate(customer, ctx)
	assert_eq(verdict.decision, Verdict.DECISION_REJECT)
	assert_eq(verdict.reasons, ["R_EXCHANGE"] as Array[String])


# --- R_ID_LIMIT --------------------------------------------------------------

func _big_seller(day: int) -> Customer:
	return seller(FED, [20, 20], day)  # 40 FED ~ 1.185 PL: 1.000 PL sınırının üstünde


func test_id_not_needed_below_limit_and_before_day_five() -> void:
	var small := seller(FED, [20], 5)
	assert_eq(evaluate(small, make_ctx(5)).decision, Verdict.DECISION_COMPLETE)
	assert_eq(evaluate(_big_seller(4), make_ctx(4)).decision, Verdict.DECISION_COMPLETE, "4. günde kural kapalı")


func test_id_required_above_limit() -> void:
	var ctx := make_ctx(5)
	var no_id := evaluate(_big_seller(5), ctx)
	assert_eq(no_id.decision, Verdict.DECISION_REJECT)
	assert_eq(no_id.reasons, ["R_ID_LIMIT"] as Array[String])
	var with_id := _big_seller(5)
	give_id(with_id, ctx)
	assert_eq(evaluate(with_id, ctx).decision, Verdict.DECISION_COMPLETE)


func test_id_limit_boundary_is_strictly_greater() -> void:
	var probe_ctx := make_ctx(5)
	var customer := _big_seller(5)
	var value := customer.transaction_value_pl(probe_ctx.rates, 5, false)
	var at_limit := make_ctx(5, {"rules": custom_rules([{"id": "R_ID_LIMIT", "from_day": 1, "check": "id", "limit_pl_minor": value}])})
	assert_eq(evaluate(customer, at_limit).decision, Verdict.DECISION_COMPLETE, "tam sınırda kimlik gerekmez")
	var just_over := make_ctx(5, {"rules": custom_rules([{"id": "R_ID_LIMIT", "from_day": 1, "check": "id", "limit_pl_minor": value - 1}])})
	assert_eq(evaluate(customer, just_over).decision, Verdict.DECISION_REJECT, "bir kuruş fazlası kimlik ister")


func test_expired_id_is_rejected_and_last_valid_day_is_accepted() -> void:
	var ctx := make_ctx(5)
	var expired := _big_seller(5)
	give_id(expired, ctx, -1)
	var verdict := evaluate(expired, ctx)
	assert_eq(verdict.decision, Verdict.DECISION_REJECT)
	assert_eq(verdict.reasons, ["R_ID_LIMIT"] as Array[String])
	var last_day := _big_seller(5)
	give_id(last_day, ctx, 0)
	assert_eq(evaluate(last_day, ctx).decision, Verdict.DECISION_COMPLETE, "bugün son geçerli gün")


func test_someone_elses_id_is_rejected() -> void:
	var ctx := make_ctx(5)
	var customer := _big_seller(5)
	give_id(customer, ctx).face_id = customer.face_id + 1
	var verdict := evaluate(customer, ctx)
	assert_eq(verdict.decision, Verdict.DECISION_REJECT)
	assert_eq(verdict.reasons, ["R_ID_LIMIT"] as Array[String])


func test_forged_id_calls_the_police() -> void:
	var ctx := make_ctx(5)
	var customer := _big_seller(5)
	var card := give_id(customer, ctx)
	card.number = card.number.substr(0, 10) + str((card.number[10].to_int() + 1) % 10)
	assert_false(Documents.id_number_ok(card.number))
	var verdict := evaluate(customer, ctx)
	assert_eq(verdict.decision, Verdict.DECISION_POLICE)
	assert_eq(verdict.reasons, ["R_ID_LIMIT"] as Array[String])
	for fate in verdict.fates:
		assert_eq(fate, Verdict.FATE_RETURN, "banknotlarda sorun yok, iade edilir")


func test_id_number_checksum() -> void:
	for i in 50:
		assert_true(Documents.id_number_ok(Documents.make_id_number(rng)))
	assert_false(Documents.id_number_ok("123"))
	assert_false(Documents.id_number_ok("1234567890X"))


# --- R_SOURCE ----------------------------------------------------------------

func _huge_seller(day: int) -> Customer:
	return seller("DNR", [50, 50], day)  # ~9.000 PL: 5.000 PL sınırının üstünde


func _huge_customer_with_papers(ctx: DayContext) -> Customer:
	var customer := _huge_seller(ctx.day)
	give_id(customer, ctx)
	give_declaration(customer, ctx)
	return customer


func test_source_declaration_not_needed_below_limit_or_before_day_ten() -> void:
	var ctx := make_ctx(10)
	var customer := seller(FED, [100], 10)
	give_id(customer, ctx)
	assert_true(customer.transaction_value_pl(ctx.rates, 10, false) <= 500000)
	assert_eq(evaluate(customer, ctx).decision, Verdict.DECISION_COMPLETE, "5.000 PL altında beyan gerekmez")
	var early := make_ctx(9)
	var big := _huge_seller(9)
	give_id(big, early)
	assert_eq(evaluate(big, early).decision, Verdict.DECISION_COMPLETE, "9. günde kural kapalı")


func test_source_declaration_required_above_limit() -> void:
	var ctx := make_ctx(10)
	var missing := _huge_seller(10)
	give_id(missing, ctx)
	var verdict := evaluate(missing, ctx)
	assert_eq(verdict.decision, Verdict.DECISION_REJECT)
	assert_eq(verdict.reasons, ["R_SOURCE"] as Array[String])
	assert_eq(evaluate(_huge_customer_with_papers(ctx), ctx).decision, Verdict.DECISION_COMPLETE)


func test_source_declaration_mismatches_call_the_police() -> void:
	var ctx := make_ctx(10)
	var wrong_amount := _huge_customer_with_papers(ctx)
	wrong_amount.declaration.amount_minor += 500
	var wrong_signature := _huge_customer_with_papers(ctx)
	wrong_signature.declaration.signature = "sig-başka"
	var wrong_name := _huge_customer_with_papers(ctx)
	wrong_name.declaration.holder_name = "Başka Biri"
	for customer in [wrong_amount, wrong_signature, wrong_name]:
		var verdict := evaluate(customer, ctx)
		assert_eq(verdict.decision, Verdict.DECISION_POLICE)
		assert_eq(verdict.reasons, ["R_SOURCE"] as Array[String])


func test_source_limit_boundary_is_strictly_greater() -> void:
	var probe := make_ctx(10)
	var customer := _huge_customer_with_papers(probe)
	var value := customer.transaction_value_pl(probe.rates, 10, false)
	customer.declaration = null
	var at_limit := make_ctx(10, {"rules": custom_rules([{"id": "R_SOURCE", "from_day": 1, "check": "source", "limit_pl_minor": value}])})
	assert_eq(evaluate(customer, at_limit).decision, Verdict.DECISION_COMPLETE)
	var just_over := make_ctx(10, {"rules": custom_rules([{"id": "R_SOURCE", "from_day": 1, "check": "source", "limit_pl_minor": value - 1}])})
	assert_eq(evaluate(customer, just_over).decision, Verdict.DECISION_REJECT)


# --- R_MIDDAY_RATE -----------------------------------------------------------

func test_midday_rate_applies_only_after_update_and_only_when_rule_is_open() -> void:
	var morning_ctx := make_ctx(11)
	var afternoon_ctx := make_ctx(11, {"midday": true})
	var morning := evaluate(seller(FED, [20], 11), morning_ctx)
	var afternoon := evaluate(seller(FED, [20], 11), afternoon_ctx)
	assert_eq(morning.pay_out["PL"], morning_ctx.rates.buy_payout(FED, Money.units(20), 11, false))
	assert_eq(afternoon.pay_out["PL"], afternoon_ctx.rates.buy_payout(FED, Money.units(20), 11, true))
	assert_ne(morning.pay_out["PL"], afternoon.pay_out["PL"], "öğleden sonra kur farklı")
	# 10. günde kural kapalı: öğleden sonra bile sabah kuru geçerli.
	var early_afternoon := make_ctx(10, {"midday": true})
	var early_morning := make_ctx(10)
	assert_eq(evaluate(seller(FED, [20], 10), early_afternoon).pay_out, evaluate(seller(FED, [20], 10), early_morning).pay_out)


func test_midday_rate_applies_to_buyers_too() -> void:
	var ctx := make_ctx(11, {"midday": true})
	var customer := buyer(FED, 10, ctx)
	var verdict := evaluate(customer, ctx)
	assert_eq(verdict.decision, Verdict.DECISION_COMPLETE)
	assert_eq(customer.nominal_minor("PL"), ctx.rates.sell_cost(FED, Money.units(10), 11, true))


# --- R_WANTED ----------------------------------------------------------------

func test_wanted_face_calls_the_police() -> void:
	var bulletin := Bulletin.new()
	bulletin.wanted_faces.append(77)
	var ctx := make_ctx(12, {"bulletin": bulletin})
	var wanted := evaluate(seller(FED, [20], 12, 77), ctx)
	assert_eq(wanted.decision, Verdict.DECISION_POLICE)
	assert_eq(wanted.reasons, ["R_WANTED"] as Array[String])
	assert_eq(wanted.fates, [Verdict.FATE_RETURN] as Array[String], "banknotu temiz, iade")
	assert_eq(evaluate(seller(FED, [20], 12, 78), ctx).decision, Verdict.DECISION_COMPLETE)


func test_wanted_rule_inactive_before_day_twelve() -> void:
	var bulletin := Bulletin.new()
	bulletin.wanted_faces.append(77)
	assert_eq(evaluate(seller(FED, [20], 11, 77), make_ctx(11, {"bulletin": bulletin})).decision, Verdict.DECISION_COMPLETE)


# --- Öncelik -----------------------------------------------------------------

func test_police_beats_reject_and_lists_only_police_reasons() -> void:
	var ctx := make_ctx(5)
	var customer := new_customer()
	customer.notes.append(fake_note(FED, 20, 5, [Banknote.FAKE_UV_COLOR, Banknote.FAKE_COLOR]))
	customer.notes.append(factory.make_genuine(FED, 20, 5))
	customer.notes.append(factory.make_genuine(FED, 20, 5))
	# 60 FED > 1.000 PL ve kimlik yok (reddet nedeni), ama sahte para polis gerektirir.
	var verdict := evaluate(customer, ctx)
	assert_eq(verdict.decision, Verdict.DECISION_POLICE)
	assert_eq(verdict.reasons, ["R_CATALOG", "R_UV"] as Array[String], "R_ID_LIMIT reddet nedeni polis kararında listelenmez")


func test_forged_id_and_wanted_face_list_both_reasons_in_rule_order() -> void:
	var bulletin := Bulletin.new()
	bulletin.wanted_faces.append(5)
	var ctx := make_ctx(12, {"bulletin": bulletin})
	var customer := _big_seller(12)
	customer.face_id = 5
	var card := give_id(customer, ctx)
	card.number = card.number.substr(0, 10) + str((card.number[10].to_int() + 1) % 10)
	give_declaration(customer, ctx)
	var verdict := evaluate(customer, ctx)
	assert_eq(verdict.decision, Verdict.DECISION_POLICE)
	assert_eq(verdict.reasons, ["R_ID_LIMIT", "R_WANTED"] as Array[String])


func test_reject_reasons_are_collected_together() -> void:
	var ctx := make_ctx(10)
	var customer := _huge_seller(10)  # kimlik ve beyan yok
	var verdict := evaluate(customer, ctx)
	assert_eq(verdict.decision, Verdict.DECISION_REJECT)
	assert_eq(verdict.reasons, ["R_ID_LIMIT", "R_SOURCE"] as Array[String])
