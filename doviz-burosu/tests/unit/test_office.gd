extends "res://tests/engine_case.gd"
## Merkez talimatları ve tüple gelen notlar (core): seçim, durum, maaşa etkisi, not planı ve teslimi.


func _career(day: int, salt := "office-test") -> Career:
	var career := Career.load_default(salt)
	career.day = day
	career.office_enabled = true
	return career


func test_no_directive_during_the_first_two_training_days() -> void:
	assert_true(Directives.pick(1, "s").is_empty())
	assert_true(Directives.pick(2, "s").is_empty())
	assert_false(Directives.pick(3, "s").is_empty())


func test_directive_choice_is_deterministic_and_respects_the_opening_day() -> void:
	for day in range(3, 16):
		assert_eq(Directives.pick(day, "a"), Directives.pick(day, "a"))
		var def := Directives.pick(day, "a")
		assert_true(int(def["from_day"]) <= day, "%d. gün: %s" % [day, def["id"]])
	var seen := {}
	for salt in ["a", "b", "c", "d", "e", "f", "g", "h"]:
		seen[str(Directives.pick(12, salt)["id"])] = true
	assert_true(seen.size() >= 3, "farklı oyunlar farklı talimat görür")


func test_the_inspector_day_always_demands_zero_mistakes() -> void:
	for salt in ["a", "b", "c"]:
		assert_eq(str(Directives.pick(14, salt)["id"]), "clean")


func test_status_of_at_least_and_at_most_directives() -> void:
	var quota := Directives.by_id("quota")
	assert_true(Directives.is_at_least(quota))
	assert_false(bool(Directives.status(quota, {"served": 12})["met"]))
	assert_true(bool(Directives.status(quota, {"served": 13})["met"]))
	var calm := Directives.by_id("calm")
	assert_false(Directives.is_at_least(calm))
	assert_true(bool(Directives.status(calm, {"rejects": 2})["met"]))
	var over := Directives.status(calm, {"rejects": 3})
	assert_false(bool(over["met"]))
	assert_true(bool(over["failed"]), "aşılan üst sınır geri alınamaz")


func test_result_is_a_bonus_when_met_and_a_deduction_when_not() -> void:
	var quota := Directives.by_id("quota")
	assert_eq(Directives.result_minor(quota, {"served": 20}), Money.units(60))
	assert_eq(Directives.result_minor(quota, {"served": 1}), -Money.units(30))
	assert_eq(Directives.result_minor({}, {}), 0)


func test_the_shift_counts_decisions_and_applies_the_directive_to_the_wage() -> void:
	var career := _career(6)
	career.office_enabled = false
	var shift := career.new_shift()
	shift.directive = Directives.by_id("quota")
	shift.start()
	var bot := ClerkBot.new("perfect", "office")
	var guard := 0
	while not shift.is_closed() and guard < 5000:
		guard += 1
		if shift.current == null:
			shift.advance(1.0)
			continue
		shift.advance(bot.think_seconds())
		shift.submit(bot.move_for(shift.current, shift.current_verdict))
	var report := shift.report()
	assert_eq(int(report["rejects"]) + int(report["polices"]) + int(report["completes"]), int(report["served"]))
	var met := int(report["served"]) >= 13
	assert_eq(bool(report["directive_met"]), met)
	assert_eq(int(report["directive_minor"]), Money.units(60) if met else -Money.units(30))
	var plain := int(report["base_minor"]) + int(report["bonus_minor"]) - int(report["fines_minor"])
	assert_eq(int(report["net_minor"]), plain + int(report["directive_minor"]))


func test_a_career_with_the_office_gives_the_shift_the_days_directive_and_memos() -> void:
	var career := _career(9, "office-a")
	var shift := career.new_shift()
	assert_eq(shift.directive, career.todays_directive())
	assert_false(shift.directive.is_empty())
	assert_false(shift.memo_plan.is_empty())
	var plain := _career(9, "office-a")
	plain.office_enabled = false
	var plain_shift := plain.new_shift()
	assert_true(plain_shift.directive.is_empty() and plain_shift.memo_plan.is_empty(), "ofis kapalıyken hiçbir şey eklenmez")


func test_memo_plan_starts_on_day_four_is_deterministic_and_sorted() -> void:
	var career := _career(3)
	var ctx := career.make_context()
	assert_true(OfficeMemos.plan(3, "s", ctx).is_empty())
	for day in range(4, 16):
		career.day = day
		var plan := OfficeMemos.plan(day, "s", career.make_context())
		assert_false(plan.is_empty(), "%d. gün" % day)
		assert_eq(plan, OfficeMemos.plan(day, "s", career.make_context()))
		for i in range(1, plan.size()):
			assert_true(int(plan[i - 1]["at_served"]) <= int(plan[i]["at_served"]))
		for memo in plan:
			if memo["kind"] == "stolen_add":
				assert_true(day >= 7, "çalıntı bülteni kural açılınca")


func test_a_stolen_memo_adds_a_range_to_the_bulletin_even_if_nobody_reads_it() -> void:
	var career := _career(9)
	var shift := career.new_shift()
	var before := shift.ctx.bulletin.stolen_ranges.size()
	shift.memo_plan = [{"id": "t1", "kind": "stolen_add", "at_served": 0, "text_key": "MEMO_STOLEN", "sender_key": "MEMO_SENDER_CENTER"}]
	shift.start()
	assert_eq(shift.memos_delivered.size(), 1)
	assert_eq(shift.ctx.bulletin.stolen_ranges.size(), before + 1)
	var memo: Dictionary = shift.memos_delivered[0]
	assert_false(str(memo["from_serial"]).is_empty())
	assert_eq(shift.unread_memos(), 1)
	shift.mark_memo_read("t1")
	assert_eq(shift.unread_memos(), 0)


func test_a_directive_change_memo_swaps_the_directive() -> void:
	var career := _career(9)
	var shift := career.new_shift()
	var old_id := str(shift.directive["id"])
	shift.memo_plan = [{"id": "t2", "kind": "directive_change", "at_served": 0, "text_key": "MEMO_CHANGE", "sender_key": "MEMO_SENDER_REGION"}]
	shift.start()
	assert_ne(str(shift.directive["id"]), old_id)
	assert_eq(str(shift.memos_delivered[0]["directive_id"]), str(shift.directive["id"]))


func test_memos_arrive_only_after_enough_customers_were_served() -> void:
	var career := _career(5)
	var shift := career.new_shift()
	shift.memo_plan = [{"id": "t3", "kind": "flavor", "at_served": 2, "text_key": "MEMO_F1", "sender_key": "MEMO_SENDER_RIZA"}]
	shift.start()
	assert_eq(shift.memos_delivered.size(), 0)
	var bot := ClerkBot.new("perfect", "memo")
	for i in 3:
		if shift.current != null:
			shift.submit(bot.move_for(shift.current, shift.current_verdict))
		shift.advance(5.0)
	assert_eq(shift.memos_delivered.size(), 1)


func test_ranges_added_by_the_tube_are_counted_after_the_initial_ones() -> void:
	var career := _career(9)
	var shift := career.new_shift()
	var initial := shift.initial_stolen_count
	assert_eq(initial, shift.ctx.bulletin.stolen_ranges.size())
	var plan: Array[Dictionary] = [{"id": "t4", "kind": "stolen_add", "at_served": 0, "text_key": "MEMO_STOLEN", "sender_key": "MEMO_SENDER_CENTER"}]
	shift.memo_plan = plan
	shift.start()
	assert_eq(shift.initial_stolen_count, initial)
	assert_eq(shift.ctx.bulletin.stolen_ranges.size(), initial + 1)


func _call_shift(day := 9) -> Shift:
	var career := _career(day)
	var shift := career.new_shift()
	var plan: Array[Dictionary] = [{"id": "c1", "kind": "call", "call_id": "C1", "at_served": 0, "text_key": "CALL_C1", "sender_key": "CALL_SENDER_SELMA"}]
	shift.memo_plan = plan
	shift.start()
	return shift


func test_a_call_memo_carries_its_options_and_is_unanswered() -> void:
	var shift := _call_shift()
	var memo: Dictionary = shift.memos_delivered[0]
	assert_eq((memo["options"] as Array).size(), 2)
	assert_eq(str(memo["answered"]), "")
	assert_eq(shift.missed_calls(), 1)


func test_answering_a_call_applies_cash_mood_and_kindness_once() -> void:
	var shift := _call_shift()
	assert_true(shift.answer_call("c1", "pay"))
	assert_eq(int(shift.stats["story_minor"]), -Money.units(40))
	assert_eq(int(shift.stats["call_mood"]), 4)
	assert_eq(int(shift.stats["call_kind"]), 1)
	assert_eq(shift.missed_calls(), 0)
	assert_false(shift.answer_call("c1", "later"), "bir arama yalnızca bir kez cevaplanır")
	assert_eq(int(shift.stats["call_mood"]), 4)
	assert_false(shift.answer_call("c1", "nope"))
	assert_false(shift.answer_call("zzz", "pay"))


func test_the_evening_applies_call_effects_and_missed_calls_to_the_household() -> void:
	var career := _career(9)
	var shift := career.new_shift()
	var plan: Array[Dictionary] = [
		{"id": "c1", "kind": "call", "call_id": "C1", "at_served": 0, "text_key": "CALL_C1", "sender_key": "CALL_SENDER_SELMA"},
		{"id": "c2", "kind": "call", "call_id": "C2", "at_served": 0, "text_key": "CALL_C2", "sender_key": "CALL_SENDER_ANNE"}]
	shift.memo_plan = plan
	shift.start()
	career.household.mood = 50
	shift.answer_call("c1", "pay")  # +4 ruh hali, +1 iyilik; c2 cevapsız: -2
	shift.end_now()
	career.begin_evening(shift)
	assert_eq(career.household.mood, 52)
	assert_eq(career.story.counter("kind"), 1)
