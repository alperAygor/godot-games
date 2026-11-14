extends "res://tests/engine_case.gd"
## Slip: uyarı fişi satırları.


func _lines_for(mistakes: Array[Dictionary], verdict: Verdict) -> Array[Dictionary]:
	return Slip.lines(mistakes, verdict)


func test_no_mistakes_no_lines() -> void:
	assert_eq(_lines_for([] as Array[Dictionary], Verdict.new()), [] as Array[Dictionary])


func test_decision_and_note_mistakes_name_the_expected_answer() -> void:
	var mistakes: Array[Dictionary] = [
		{"type": Verdict.MISTAKE_DECISION, "expected": Verdict.DECISION_POLICE, "got": Verdict.DECISION_COMPLETE},
	]
	var lines := _lines_for(mistakes, Verdict.new())
	assert_eq(lines[0], {"key": "SLIP_WRONG_DECISION", "args": ["@DECISION_POLICE"]})
	var note_mistakes: Array[Dictionary] = [
		{"type": Verdict.MISTAKE_NOTE, "note": 1, "expected": Verdict.FATE_CONFISCATE, "got": Verdict.FATE_ACCEPT},
	]
	assert_eq(_lines_for(note_mistakes, Verdict.new())[0], {"key": "SLIP_WRONG_NOTE", "args": [2, "@FATE_CONFISCATE"]})


func test_payment_mistakes_carry_money_arguments() -> void:
	var mistakes: Array[Dictionary] = [
		{"type": Verdict.MISTAKE_OVERPAID, "code": "PL", "delta": 1500},
		{"type": Verdict.MISTAKE_UNDERPAID, "code": "FED", "delta": -300},
		{"type": Shift.MISTAKE_TILL_SHORT},
		{"type": Verdict.MISTAKE_REASON, "expected": ["R_UV"], "got": ""},
	]
	var lines := _lines_for(mistakes, Verdict.new())
	assert_eq(lines[0], {"key": "SLIP_OVERPAID", "args": [{"money": [1500, "PL"]}]})
	assert_eq(lines[1], {"key": "SLIP_UNDERPAID", "args": [{"money": [300, "FED"]}]})
	assert_eq(lines[2]["key"], "SLIP_TILL_SHORT")
	assert_eq(lines[3]["key"], "SLIP_WRONG_REASON")


func test_rule_hints_come_from_verdict_details_and_are_unique() -> void:
	var ctx := make_ctx(3)
	var customer := new_customer()
	customer.notes.append(fake_note("FED", 20, 3, [Banknote.FAKE_UV_MISSING, Banknote.FAKE_UV_COLOR]))
	customer.notes.append(fake_note("FED", 10, 3, [Banknote.FAKE_UV_MISSING]))
	var verdict := evaluate(customer, ctx)
	var mistakes: Array[Dictionary] = [{"type": Verdict.MISTAKE_DECISION, "expected": verdict.decision, "got": "complete"}]
	var lines := _lines_for(mistakes, verdict)
	var rule_lines := lines.filter(func(l: Dictionary) -> bool: return l["key"] == "SLIP_RULE")
	assert_eq(rule_lines.size(), 1, "aynı kural bir kez")
	assert_eq(rule_lines[0]["args"], ["@RULE_R_UV"])


func test_rule_hints_limited_to_three() -> void:
	var verdict := Verdict.new()
	for rule_id in ["R_CATALOG", "R_UV", "R_STOLEN", "R_TORN", "R_WANTED"]:
		verdict.details.append({"rule": rule_id, "kind": "x", "note": 0})
	var mistakes: Array[Dictionary] = [{"type": Verdict.MISTAKE_REASON, "expected": [], "got": ""}]
	var rule_lines := _lines_for(mistakes, verdict).filter(func(l: Dictionary) -> bool: return l["key"] == "SLIP_RULE")
	assert_eq(rule_lines.size(), 3)
