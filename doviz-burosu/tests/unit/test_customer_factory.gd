extends "res://tests/engine_case.gd"
## CustomerFactory kendi kendini doğrulama testi: üretici her müşterinin doğru cevabını (truth) bağımsız bilir;
## RuleEngine'in kararı bununla birebir uyuşmak zorunda.

const SCENARIO_UNLOCK_DAY := {
	"clean": 1, "counterfeit": 2, "no_stock": 4, "id_missing": 5, "id_expired": 5, "id_other": 5, "id_forged": 5,
	"old_series": 6, "stolen": 7, "taped": 8, "torn": 8, "stolen_torn": 8, "decl_missing": 10, "decl_amount": 10,
	"decl_signature": 10, "wanted": 12,
}


func _setup(day: int, key: String, midday := false) -> Array:
	var ctx := make_ctx(day, {"salt": key, "midday": midday})
	var generator := Seed.rng("factory|%s|%d" % [key, day])
	ctx.bulletin = CustomerFactory.make_bulletin(ctx, generator)
	return [ctx, CustomerFactory.new(ctx, generator)]


func _perfect_move(verdict: Verdict) -> PlayerMove:
	var move := PlayerMove.new()
	move.decision = verdict.decision
	move.fates = verdict.fates.duplicate()
	move.paid = verdict.pay_out.duplicate()
	move.reason = "" if verdict.reasons.is_empty() else verdict.reasons[0]
	return move


func _run_day(day: int, key: String, count: int, midday: bool, seen: Dictionary) -> Array[String]:
	var pair := _setup(day, key, midday)
	var ctx: DayContext = pair[0]
	var customers: CustomerFactory = pair[1]
	var engine := RuleEngine.new(ctx)
	var problems: Array[String] = []
	for i in count:
		var customer := customers.make_random()
		seen[customer.scenario] = int(seen.get(customer.scenario, 0)) + 1
		var verdict := engine.evaluate(customer)
		var label := "gün %d/%s #%d %s" % [day, key, i, customer.scenario]
		if verdict.decision != customer.truth["decision"]:
			problems.append("%s: karar %s, beklenen %s" % [label, verdict.decision, customer.truth["decision"]])
		elif verdict.reasons != customer.truth["reasons"]:
			problems.append("%s: nedenler %s, beklenen %s" % [label, verdict.reasons, customer.truth["reasons"]])
		elif not Verdict.compare(verdict, _perfect_move(verdict)).is_empty():
			problems.append("%s: kusursuz hamle hata sayıldı" % label)
		elif verdict.fates.size() != customer.notes.size():
			problems.append("%s: kader sayısı banknot sayısıyla uyuşmuyor" % label)
		elif verdict.decision == Verdict.DECISION_COMPLETE:
			if ctx.till.duplicate_till().settle(customer, verdict) == false:
				problems.append("%s: tamamlanan işlem kasadan ödenemiyor" % label)
		elif verdict.decision == Verdict.DECISION_REJECT:
			if verdict.fates.any(func(f: String) -> bool: return f != Verdict.FATE_RETURN) or not verdict.pay_out.is_empty():
				problems.append("%s: reddette her şey iade, ödeme yok olmalı" % label)
		elif verdict.decision == Verdict.DECISION_POLICE and not verdict.pay_out.is_empty():
			problems.append("%s: polis kararında ödeme olmamalı" % label)
	return problems


func test_engine_matches_factory_truth_every_day() -> void:
	var problems: Array[String] = []
	for day in range(1, 16):
		for key in ["alfa", "beta"]:
			problems.append_array(_run_day(day, key, 150, day % 2 == 0, {}))
	assert_eq(problems.size(), 0, "\n".join(problems.slice(0, 8)))


func test_thousand_customers_on_the_final_day_cover_every_scenario() -> void:
	var seen := {}
	var problems := _run_day(15, "final", 1000, true, seen)
	assert_eq(problems.size(), 0, "\n".join(problems.slice(0, 8)))
	for scenario in CustomerFactory.SCENARIOS:
		assert_true(int(seen.get(scenario, 0)) >= 5, "%s en az 5 kez üretilmeli: %d" % [scenario, int(seen.get(scenario, 0))])


func test_scenarios_unlock_with_their_rules() -> void:
	for day in range(1, 16):
		var pair := _setup(day, "unlock")
		var factory: CustomerFactory = pair[1]
		var available := factory.available_scenarios()
		for scenario in CustomerFactory.SCENARIOS:
			var should_exist: bool = day >= int(SCENARIO_UNLOCK_DAY[scenario])
			assert_eq(scenario in available, should_exist, "gün %d: %s" % [day, scenario])
	assert_eq(_setup(1, "x")[1].available_scenarios(), ["clean"] as Array[String])


func test_same_seed_produces_identical_customers() -> void:
	var first := _setup(12, "same")[1] as CustomerFactory
	var second := _setup(12, "same")[1] as CustomerFactory
	for i in 60:
		var a := first.make_random()
		var b := second.make_random()
		assert_eq(a.scenario, b.scenario)
		assert_eq(a.holder_name, b.holder_name)
		assert_eq(a.face_id, b.face_id)
		assert_eq(a.truth, b.truth)
		assert_eq(a.notes.map(func(n: Banknote) -> Dictionary: return n.to_dict()), b.notes.map(func(n: Banknote) -> Dictionary: return n.to_dict()))


func test_different_seeds_produce_different_customers() -> void:
	var a := _setup(12, "one")[1] as CustomerFactory
	var b := _setup(12, "two")[1] as CustomerFactory
	var differs := false
	for i in 20:
		if a.make_random().holder_name != b.make_random().holder_name:
			differs = true
	assert_true(differs)


func test_bulletin_follows_open_rules() -> void:
	var early := _setup(6, "bulletin")[0] as DayContext
	assert_true(early.bulletin.stolen_ranges.is_empty(), "R_STOLEN 7. günde açılır")
	var day7 := _setup(7, "bulletin")[0] as DayContext
	assert_eq(day7.bulletin.stolen_ranges.size(), 3)
	assert_true(day7.bulletin.wanted_faces.is_empty(), "R_WANTED 12. günde açılır")
	for range_def in day7.bulletin.stolen_ranges:
		assert_true(day7.book.series_valid_on(range_def["currency"], range_def["series_id"], 7))
		assert_eq(int(range_def["to"]) - int(range_def["from"]) + 1, 2000)
	var day12 := _setup(12, "bulletin")[0] as DayContext
	assert_eq(day12.bulletin.wanted_faces.size(), 2)
	assert_ne(day12.bulletin.wanted_faces[0], day12.bulletin.wanted_faces[1])


func test_clean_customers_never_carry_stolen_serials_or_wanted_faces() -> void:
	var pair := _setup(14, "clean-check")
	var ctx: DayContext = pair[0]
	var factory: CustomerFactory = pair[1]
	for i in 300:
		var customer := factory.make_scenario("clean")
		assert_false(ctx.bulletin.is_wanted(customer.face_id))
		for note in customer.notes:
			assert_false(ctx.bulletin.is_stolen(note, ctx.book), note.serial)


func test_threshold_scenarios_really_cross_their_limits() -> void:
	var pair := _setup(15, "limits")
	var ctx: DayContext = pair[0]
	var factory: CustomerFactory = pair[1]
	var id_limit := ctx.rules.limit_minor("R_ID_LIMIT")
	var source_limit := ctx.rules.limit_minor("R_SOURCE")
	for scenario in ["id_missing", "id_expired", "id_other", "id_forged"]:
		for i in 25:
			var customer := factory.make_scenario(scenario)
			var value := customer.transaction_value_pl(ctx.rates, 15, ctx.use_midday_rates())
			assert_true(value > id_limit and value <= source_limit, "%s değer %d" % [scenario, value])
	for scenario in ["decl_missing", "decl_amount", "decl_signature"]:
		for i in 25:
			var customer := factory.make_scenario(scenario)
			assert_true(customer.transaction_value_pl(ctx.rates, 15, ctx.use_midday_rates()) > source_limit, scenario)
			assert_true(customer.notes.size() <= 12)


func test_no_stock_customers_ask_more_than_the_till_holds() -> void:
	var pair := _setup(4, "stock")
	var ctx: DayContext = pair[0]
	var factory: CustomerFactory = pair[1]
	for i in 40:
		var customer := factory.make_scenario("no_stock")
		assert_eq(customer.intent, Customer.INTENT_BUY)
		assert_true(customer.requested_foreign_minor > ctx.till.total_minor(customer.currency))
		assert_false(ctx.till.can_pay(customer.currency, customer.requested_foreign_minor))
		assert_eq(customer.nominal_minor("PL"), ctx.rates.sell_cost(customer.currency, customer.requested_foreign_minor, 4), "tam bedeli PL banknotlarıyla getirir")


func test_unavailable_scenarios_return_null() -> void:
	var factory := _setup(1, "null")[1] as CustomerFactory
	for scenario in CustomerFactory.SCENARIOS:
		if scenario != "clean":
			assert_eq(factory.make_scenario(scenario), null, scenario)
