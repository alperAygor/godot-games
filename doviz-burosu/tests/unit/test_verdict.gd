extends "res://tests/engine_case.gd"
## Verdict.compare (oyuncu hamlesi - beklenen) ve Till.settle (tamamlanan işlemi kasaya işleme).


func _move(verdict: Verdict) -> PlayerMove:
	var move := PlayerMove.new()
	move.decision = verdict.decision
	move.fates = verdict.fates.duplicate()
	move.paid = verdict.pay_out.duplicate()
	if not verdict.reasons.is_empty():
		move.reason = verdict.reasons[0]
	return move


func _complete_verdict() -> Verdict:
	var ctx := make_ctx(8)
	var customer := new_customer()
	customer.notes.append(factory.make_genuine("FED", 20, 8, {"torn": true}))
	customer.notes.append(factory.make_genuine("FED", 10, 8))
	return evaluate(customer, ctx)


func _types(mistakes: Array[Dictionary]) -> Array:
	return mistakes.map(func(m: Dictionary) -> String: return m["type"])


func test_perfect_move_has_no_mistakes() -> void:
	var verdict := _complete_verdict()
	assert_eq(verdict.decision, Verdict.DECISION_COMPLETE)
	assert_eq(Verdict.compare(verdict, _move(verdict)), [] as Array[Dictionary])


func test_wrong_decision_reports_only_the_decision() -> void:
	var verdict := _complete_verdict()
	var move := _move(verdict)
	move.decision = Verdict.DECISION_REJECT
	move.fates = ["return", "return"] as Array[String]
	var mistakes := Verdict.compare(verdict, move)
	assert_eq(_types(mistakes), [Verdict.MISTAKE_DECISION])
	assert_eq(mistakes[0]["expected"], Verdict.DECISION_COMPLETE)
	assert_eq(mistakes[0]["got"], Verdict.DECISION_REJECT)


func test_note_fate_mistake_names_the_note() -> void:
	var verdict := _complete_verdict()
	var move := _move(verdict)
	move.fates[0] = Verdict.FATE_ACCEPT  # yırtık banknotu kabul etmiş
	var mistakes := Verdict.compare(verdict, move)
	assert_eq(_types(mistakes), [Verdict.MISTAKE_NOTE])
	assert_eq(mistakes[0]["note"], 0)
	assert_eq(mistakes[0]["expected"], Verdict.FATE_RETURN)
	assert_eq(mistakes[0]["got"], Verdict.FATE_ACCEPT)


func test_overpaid_and_underpaid_report_the_difference() -> void:
	var verdict := _complete_verdict()
	var over := _move(verdict)
	over.paid["PL"] = int(verdict.pay_out["PL"]) + 500
	var over_mistakes := Verdict.compare(verdict, over)
	assert_eq(_types(over_mistakes), [Verdict.MISTAKE_OVERPAID])
	assert_eq(over_mistakes[0]["delta"], 500)
	assert_eq(over_mistakes[0]["code"], "PL")
	var under := _move(verdict)
	under.paid["PL"] = int(verdict.pay_out["PL"]) - 100
	assert_eq(_types(Verdict.compare(verdict, under)), [Verdict.MISTAKE_UNDERPAID])
	var nothing := _move(verdict)
	nothing.paid = {}
	var nothing_mistakes := Verdict.compare(verdict, nothing)
	assert_eq(_types(nothing_mistakes), [Verdict.MISTAKE_UNDERPAID])
	assert_eq(nothing_mistakes[0]["delta"], -int(verdict.pay_out["PL"]))


func test_paying_a_wrong_currency_is_flagged_twice() -> void:
	var verdict := _complete_verdict()
	var move := _move(verdict)
	move.paid = {"FED": 100}
	var types := _types(Verdict.compare(verdict, move))
	assert_true(Verdict.MISTAKE_UNDERPAID in types and Verdict.MISTAKE_OVERPAID in types)


func test_reject_requires_a_valid_reason() -> void:
	var ctx := make_ctx(5)
	var customer := seller("FED", [20, 20], 5)  # 1.000 PL üstü, kimlik yok
	var verdict := evaluate(customer, ctx)
	assert_eq(verdict.decision, Verdict.DECISION_REJECT)
	var good := _move(verdict)
	assert_eq(Verdict.compare(verdict, good), [] as Array[Dictionary])
	var wrong := _move(verdict)
	wrong.reason = "R_UV"
	assert_eq(_types(Verdict.compare(verdict, wrong)), [Verdict.MISTAKE_REASON])
	var none := _move(verdict)
	none.reason = ""
	assert_eq(_types(Verdict.compare(verdict, none)), [Verdict.MISTAKE_REASON], "reddetmede neden seçmek zorunlu")


func test_police_reason_is_optional_but_must_be_right_if_given() -> void:
	var ctx := make_ctx(2)
	var customer := new_customer()
	customer.notes.append(fake_note("FED", 20, 2, [Banknote.FAKE_COLOR]))
	var verdict := evaluate(customer, ctx)
	assert_eq(verdict.decision, Verdict.DECISION_POLICE)
	var blank := _move(verdict)
	blank.reason = ""
	assert_eq(Verdict.compare(verdict, blank), [] as Array[Dictionary])
	var wrong := _move(verdict)
	wrong.reason = "R_STOLEN"
	assert_eq(_types(Verdict.compare(verdict, wrong)), [Verdict.MISTAKE_REASON])
	var missed := _move(verdict)
	missed.fates[0] = Verdict.FATE_RETURN
	assert_eq(_types(Verdict.compare(verdict, missed)), [Verdict.MISTAKE_NOTE], "sahteyi iade etmek hata")


func test_verdict_details_explain_each_finding() -> void:
	var ctx := make_ctx(8)
	var customer := new_customer()
	customer.notes.append(factory.make_genuine("FED", 20, 8, {"torn": true}))
	var details := evaluate(customer, ctx).details
	assert_eq(details.size(), 1)
	assert_eq(details[0], {"rule": "R_TORN", "kind": "torn", "note": 0})


func test_settle_moves_notes_and_payouts_through_the_till() -> void:
	var ctx := make_ctx(4)
	var customer := buyer("FED", 10, ctx, 95)
	var verdict := evaluate(customer, ctx)
	var pl_before := ctx.till.total_minor("PL")
	var fed_before := ctx.till.total_minor("FED")
	assert_true(ctx.till.settle(customer, verdict))
	assert_eq(ctx.till.total_minor("FED"), fed_before - Money.units(10))
	var received := customer.nominal_minor("PL")
	assert_eq(ctx.till.total_minor("PL"), pl_before + received - Money.units(95))


func test_settle_ignores_police_and_reject_and_never_goes_negative() -> void:
	var ctx := make_ctx(2)
	var before := ctx.till.to_dict()
	var customer := new_customer()
	customer.notes.append(fake_note("FED", 20, 2, [Banknote.FAKE_SIZE]))
	var verdict := evaluate(customer, ctx)
	assert_true(ctx.till.settle(customer, verdict))
	assert_eq(ctx.till.to_dict(), before, "polis kararında kasa değişmez")
	# Ödenemeyecek bir hüküm: kasa değişmeden false döner.
	var empty_ctx := make_ctx(4, {"till": Till.new()})
	var sale := seller("FED", [20], 4)
	var fake_verdict := Verdict.new()
	fake_verdict.decision = Verdict.DECISION_COMPLETE
	fake_verdict.fates = [Verdict.FATE_ACCEPT] as Array[String]
	fake_verdict.pay_out = {"PL": Money.units(500)}
	assert_false(empty_ctx.till.settle(sale, fake_verdict))
	assert_eq(empty_ctx.till.to_dict(), {})
