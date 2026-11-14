extends "res://tests/engine_case.gd"
## Shift: saat akışı, kapanış, hata sayımı/ceza, maaş, kesinti, kasa.

var career: Career


func before_each() -> void:
	super.before_each()
	career = Career.load_default("shift-test")


func _shift(day := 1) -> Shift:
	career.day = day
	return career.new_shift()


func _perfect(shift: Shift) -> PlayerMove:
	var move := PlayerMove.new()
	move.decision = shift.current_verdict.decision
	move.fates = shift.current_verdict.fates.duplicate()
	move.paid = shift.current_verdict.pay_out.duplicate()
	move.reason = "" if shift.current_verdict.reasons.is_empty() else shift.current_verdict.reasons[0]
	return move


func _wrong(shift: Shift) -> PlayerMove:
	var move := _perfect(shift)
	move.decision = Verdict.DECISION_POLICE if move.decision != Verdict.DECISION_POLICE else Verdict.DECISION_COMPLETE
	return move


func _next(shift: Shift) -> void:
	for i in 10:
		if shift.current != null or shift.is_closed():
			return
		shift.advance(1.0)


func test_clock_runs_from_nine_to_five() -> void:
	var shift := _shift()
	assert_eq(shift.phase, Shift.PHASE_NOT_STARTED)
	shift.start()
	assert_eq(shift.clock_text(), "09:00")
	shift.advance(135.0)
	assert_eq(shift.clock_text(), "13:00")
	shift.advance(67.5)
	assert_eq(shift.clock_text(), "15:00")
	shift.advance(500.0)
	assert_eq(shift.clock_text(), "17:00", "saat 17:00'yi aşmaz")
	assert_almost_eq(shift.seconds_left(), 0.0)


func test_first_customer_is_waiting_when_the_shift_opens() -> void:
	var shift := _shift()
	shift.start()
	assert_eq(shift.phase, Shift.PHASE_OPEN)
	assert_true(shift.current != null and shift.current_verdict != null)


func test_next_customer_arrives_after_the_gap() -> void:
	var shift := _shift()
	shift.start()
	shift.advance(10.0)
	shift.submit(_perfect(shift))
	assert_eq(shift.current, null)
	shift.advance(1.0)
	assert_eq(shift.current, null, "2 sn bekleme dolmadı")
	shift.advance(1.5)
	assert_true(shift.current != null)


func test_closing_finishes_the_customer_in_front_but_admits_nobody_new() -> void:
	var shift := _shift()
	shift.start()
	shift.advance(300.0)
	assert_eq(shift.phase, Shift.PHASE_CLOSING)
	assert_true(shift.current != null, "ekrandaki müşteri kalır")
	shift.submit(_perfect(shift))
	assert_eq(shift.phase, Shift.PHASE_CLOSED)
	assert_eq(shift.current, null)
	shift.advance(30.0)
	assert_eq(shift.current, null, "kapandıktan sonra müşteri gelmez")
	assert_true(shift.is_closed())


func test_shift_closes_when_time_runs_out_with_nobody_waiting() -> void:
	var shift := _shift()
	shift.start()
	shift.advance(268.0)
	shift.submit(_perfect(shift))
	shift.advance(10.0)
	assert_true(shift.is_closed())
	assert_eq(shift.stats["served"], 1)


func test_midday_rates_switch_on_at_thirteen() -> void:
	var shift := _shift(11)
	shift.start()
	assert_false(shift.ctx.midday)
	shift.advance(134.0)
	assert_false(shift.ctx.midday)
	shift.advance(2.0)
	assert_true(shift.ctx.midday, "13:00'ten sonra")
	assert_true(shift.ctx.use_midday_rates(), "11. günde kural açık")
	var early := _shift(10)
	early.start()
	early.advance(200.0)
	assert_true(early.ctx.midday)
	assert_false(early.ctx.use_midday_rates(), "10. günde kural kapalı")


func test_correct_move_earns_bonus_and_counts() -> void:
	var shift := _shift()
	shift.start()
	var result := shift.submit(_perfect(shift))
	assert_true(result["correct"])
	assert_eq(result["bonus_minor"], Money.units(15))
	assert_eq(shift.stats["served"], 1)
	assert_eq(shift.stats["correct"], 1)
	assert_eq(shift.stats["bonus_minor"], Money.units(15))


func test_first_two_mistaken_transactions_are_free_then_fined() -> void:
	var shift := _shift()
	shift.start()
	var fined: Array[bool] = []
	for i in 4:
		_next(shift)
		var result := shift.submit(_wrong(shift))
		assert_false(result["correct"])
		fined.append(result["fined"])
		assert_eq(result["bonus_minor"], 0)
	assert_eq(fined, [false, false, true, true] as Array[bool])
	assert_eq(shift.stats["free_used"], 2)
	assert_eq(shift.stats["fined"], 2)
	assert_eq(shift.stats["fines_minor"], 2 * Money.units(30))
	assert_eq(shift.stats["mistake_transactions"], 4)


func test_several_mistakes_in_one_transaction_count_once() -> void:
	var shift := _shift()
	shift.start()
	var move := _perfect(shift)
	move.decision = Verdict.DECISION_POLICE if move.decision != Verdict.DECISION_POLICE else Verdict.DECISION_REJECT
	move.reason = "R_UV"
	var result := shift.submit(move)
	assert_eq(shift.stats["mistake_transactions"], 1)
	assert_false(result["fined"])


func test_report_pays_salary_plus_bonus_minus_fines() -> void:
	var shift := _shift()
	shift.start()
	for i in 3:
		_next(shift)
		shift.submit(_perfect(shift))
	for i in 3:
		_next(shift)
		shift.submit(_wrong(shift))
	var report := shift.report()
	assert_eq(report["base_minor"], Money.units(305))
	assert_eq(report["bonus_minor"], 3 * Money.units(15))
	assert_eq(report["fines_minor"], Money.units(30))
	assert_eq(report["net_minor"], Money.units(305) + 3 * Money.units(15) - Money.units(30))


func test_net_pay_never_goes_negative() -> void:
	var shift := _shift()
	shift.ctx.balance["shift"]["fine_pl"] = 100000
	shift.start()
	for i in 5:
		_next(shift)
		shift.submit(_wrong(shift))
	assert_eq(shift.report()["net_minor"], 0)


func test_submit_without_customer_is_refused() -> void:
	var shift := _shift()
	shift.start()
	shift.submit(_perfect(shift))
	assert_false(shift.submit(PlayerMove.new())["ok"])


func test_overtime_reopens_a_closing_shift() -> void:
	var shift := _shift()
	shift.start()
	shift.advance(280.0)
	assert_eq(shift.phase, Shift.PHASE_CLOSING)
	shift.extend_time(45.0)
	assert_eq(shift.phase, Shift.PHASE_OPEN)
	assert_almost_eq(shift.seconds_left(), 35.0)
	assert_eq(shift.stats["overtime_seconds"], 45)


func _complete_sell(shift: Shift) -> bool:
	for i in 60:
		_next(shift)
		if shift.current_verdict.decision == Verdict.DECISION_COMPLETE and shift.current.intent == Customer.INTENT_SELL and int(shift.current_verdict.pay_out.get("PL", 0)) > 1000:
			return true
		shift.submit(_perfect(shift))
		shift.advance(1.0)
	return false


func test_skimming_exact_amount_is_hidden_profit_not_a_mistake() -> void:
	var shift := _shift(8)
	shift.skim_minor = 500
	shift.start()
	assert_true(_complete_sell(shift))
	var move := _perfect(shift)
	move.paid["PL"] = int(move.paid["PL"]) - 500
	var result := shift.submit(move)
	assert_true(result["correct"])
	assert_eq(result["skimmed_minor"], 500)
	assert_eq(shift.stats["skim_minor"], 500)
	assert_eq(shift.stats["skim_count"], 1)


func test_underpaying_more_than_the_skim_is_still_a_mistake() -> void:
	var shift := _shift(8)
	shift.skim_minor = 500
	shift.start()
	assert_true(_complete_sell(shift))
	var move := _perfect(shift)
	move.paid["PL"] = int(move.paid["PL"]) - 1000
	var result := shift.submit(move)
	assert_false(result["correct"])
	assert_eq(shift.stats["skim_count"], 0)


func test_skim_is_a_mistake_when_the_boss_offer_was_not_taken() -> void:
	var shift := _shift(8)
	shift.start()
	assert_true(_complete_sell(shift))
	var move := _perfect(shift)
	move.paid["PL"] = int(move.paid["PL"]) - 500
	assert_false(shift.submit(move)["correct"])


func test_completed_move_changes_the_till() -> void:
	var shift := _shift()
	shift.start()
	assert_true(_complete_sell(shift))
	var customer := shift.current
	var pl_before := shift.ctx.till.total_minor("PL")
	var foreign_before := shift.ctx.till.total_minor(customer.currency)
	var move := _perfect(shift)
	var paid := int(move.paid["PL"])
	assert_true(shift.submit(move)["correct"])
	assert_eq(shift.ctx.till.total_minor("PL"), pl_before - paid)
	assert_eq(shift.ctx.till.total_minor(customer.currency), foreign_before + customer.nominal_minor(customer.currency))


func test_unpayable_move_is_a_till_short_mistake_and_changes_nothing() -> void:
	var shift := _shift()
	shift.start()
	assert_true(_complete_sell(shift))
	shift.ctx.till = Till.new()
	var result := shift.submit(_perfect(shift))
	assert_false(result["correct"])
	assert_eq(result["mistakes"][0]["type"], Shift.MISTAKE_TILL_SHORT)
	assert_eq(shift.ctx.till.to_dict(), {})
