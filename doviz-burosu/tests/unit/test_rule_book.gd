extends "res://tests/session_case.gd"
## Kılavuzun Kurallar bölümü: sayfa sayfa kural, nasıl denetlenir, araç, "YENİ" damgası, masaya iğneleme.

var desk: Control


func _open_desk(day: int) -> Career:
	var career := Career.load_default("rulebook-ui")
	career.day = day
	await scenes.goto(Scenes.DESK)
	desk = tree.current_scene
	desk.set_process(false)
	desk.play(career)
	await tree.process_frame
	session.pinned_rules.clear()
	return career


func _text(node_name: String) -> String:
	return (node(node_name) as Label).text


func test_the_rules_tab_opens_on_the_newest_rule_with_its_how_to_and_tool() -> void:
	await _open_desk(5)
	await tap("ToolBookButton")
	await tap("InfoRulesTab")
	assert_true(node("RuleBook") != null)
	assert_eq(_text("RulePageNumber"), "Kural 5 / 5")
	assert_eq(_text("RuleTitle"), "1.000 PL üzeri kimlik")
	assert_true(_text("RuleHow").contains("1."), "adım adım anlatım")
	assert_true(node("RuleNewStamp") != null, "5. günde açılan kural YENİ")


func test_turning_pages_walks_through_the_rules_and_stops_at_the_ends() -> void:
	await _open_desk(5)
	await tap("ToolBookButton")
	await tap("InfoRulesTab")
	await tap("RuleNext")
	assert_eq(_text("RulePageNumber"), "Kural 5 / 5", "son sayfadan öteye geçmez")
	for i in 4:
		await tap("RulePrev")
	assert_eq(_text("RulePageNumber"), "Kural 1 / 5")
	assert_true(node("RuleNewStamp") == null, "eski kuralda YENİ yok")
	await tap("RulePrev")
	assert_eq(_text("RulePageNumber"), "Kural 1 / 5")
	var book := node("RuleBook") as RuleBook
	book.turn(2)
	assert_eq(book.current_rule(), "R_UV")


func test_a_locked_tool_is_marked_as_not_owned() -> void:
	await _open_desk(3)
	await tap("ToolBookButton")
	await tap("InfoRulesTab")
	assert_eq((node("RuleBook") as RuleBook).current_rule(), "R_UV")
	var career: Career = desk.career
	var tool_text := ""
	for label in node("RuleTool").find_children("*", "Label", true, false):
		tool_text += (label as Label).text
	assert_eq(career.has_tool("uv"), not tool_text.contains("henüz yok"))


func test_pinning_a_rule_puts_a_note_on_the_desk_that_reopens_that_page() -> void:
	await _open_desk(6)
	await tap("ToolBookButton")
	await tap("InfoRulesTab")
	var rule := (node("RuleBook") as RuleBook).current_rule()
	await tap("RulePin_%s" % rule)
	assert_true(rule in session.pinned_rules)
	desk._close_sheet()
	await tree.process_frame
	assert_true(node("Pinned_%s" % rule) != null)
	await tap("Pinned_%s" % rule)
	assert_eq((node("RuleBook") as RuleBook).current_rule(), rule)
	await tap("RulePin_%s" % rule)
	assert_false(rule in session.pinned_rules, "ikinci dokunuş iğneyi çıkarır")


func test_at_most_three_notes_stay_pinned_and_the_oldest_drops() -> void:
	await _open_desk(8)
	await tap("ToolBookButton")
	await tap("InfoRulesTab")
	var book := node("RuleBook") as RuleBook
	var pinned: Array[String] = []
	for i in 4:
		pinned.append(book.current_rule())
		await tap("RulePin_%s" % book.current_rule())
		await tap("RulePrev")
	assert_eq(session.pinned_rules.size(), GameSession.MAX_PINS)
	assert_false(pinned[0] in session.pinned_rules, "en eski not düştü")
	assert_true(pinned[3] in session.pinned_rules)
