extends "res://tests/engine_case.gd"
## DeskModel: banknot kaderleri, ödeme girdisi ve hamle kurma.


func _customer(count := 3) -> Customer:
	var customer := new_customer()
	for i in count:
		customer.notes.append(factory.make_genuine("FED", 10, 1))
	return customer


func test_notes_default_to_accept() -> void:
	var model := DeskModel.new(_customer())
	assert_eq(model.fates, [Verdict.FATE_ACCEPT, Verdict.FATE_ACCEPT, Verdict.FATE_ACCEPT] as Array[String])
	assert_eq(model.fate(1), Verdict.FATE_ACCEPT)


func test_set_fate_ignores_bad_index() -> void:
	var model := DeskModel.new(_customer())
	model.set_fate(1, Verdict.FATE_CONFISCATE)
	model.set_fate(9, Verdict.FATE_RETURN)
	model.set_fate(-1, Verdict.FATE_RETURN)
	assert_eq(model.fates, [Verdict.FATE_ACCEPT, Verdict.FATE_CONFISCATE, Verdict.FATE_ACCEPT] as Array[String])


func test_complete_keeps_fates_and_payment() -> void:
	var model := DeskModel.new(_customer())
	model.set_fate(0, Verdict.FATE_RETURN)
	model.set_paid("PL", 12000)
	model.set_paid("FED", 0)
	var move := model.build_move(Verdict.DECISION_COMPLETE)
	assert_eq(move.decision, Verdict.DECISION_COMPLETE)
	assert_eq(move.fates, [Verdict.FATE_RETURN, Verdict.FATE_ACCEPT, Verdict.FATE_ACCEPT] as Array[String])
	assert_eq(move.paid, {"PL": 12000}, "sıfır tutarlar yazılmaz")


func test_reject_returns_everything_and_drops_payment() -> void:
	var model := DeskModel.new(_customer())
	model.set_fate(1, Verdict.FATE_CONFISCATE)
	model.set_paid("PL", 5000)
	var move := model.build_move(Verdict.DECISION_REJECT, "R_UV")
	assert_eq(move.fates, [Verdict.FATE_RETURN, Verdict.FATE_RETURN, Verdict.FATE_RETURN] as Array[String])
	assert_eq(move.paid, {})
	assert_eq(move.reason, "R_UV")


func test_police_returns_accepted_notes_but_keeps_confiscations() -> void:
	var model := DeskModel.new(_customer())
	model.set_fate(1, Verdict.FATE_CONFISCATE)
	model.set_fate(2, Verdict.FATE_RETURN)
	var move := model.build_move(Verdict.DECISION_POLICE)
	assert_eq(move.fates, [Verdict.FATE_RETURN, Verdict.FATE_CONFISCATE, Verdict.FATE_RETURN] as Array[String])
	assert_eq(move.paid, {})


func test_negative_payment_is_clamped() -> void:
	var model := DeskModel.new(_customer())
	model.set_paid("PL", -500)
	assert_eq(model.paid_minor("PL"), 0)
	assert_eq(model.paid_minor("FED"), 0)


func test_payment_lines_depend_on_intent() -> void:
	var seller_model := DeskModel.new(_customer())
	assert_eq(seller_model.payment_codes("PL"), ["PL"] as Array[String])
	var ctx := make_ctx(4)
	var buyer_model := DeskModel.new(buyer("FED", 10, ctx))
	assert_eq(buyer_model.payment_codes("PL"), ["PL", "FED"] as Array[String])


func test_built_move_satisfies_the_engine_when_played_right() -> void:
	var ctx := make_ctx(1)
	var customer := seller("FED", [20, 10], 1)
	var verdict := evaluate(customer, ctx)
	var model := DeskModel.new(customer)
	model.set_paid("PL", int(verdict.pay_out["PL"]))
	assert_eq(Verdict.compare(verdict, model.build_move(Verdict.DECISION_COMPLETE)), [] as Array[Dictionary])
