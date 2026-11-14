extends "res://tests/session_case.gd"
## Ofis arayüzü: sabah gazetesinde Merkez talimatı, masada ofis düğmesi (talimat ilerlemesi + not rozeti), tüp notu, "OKUNDU" damgası.

var desk: Control


func _open_desk(day: int) -> Career:
	var career := Career.load_default("office-ui")
	career.day = day
	career.office_enabled = true
	await scenes.goto(Scenes.DESK)
	desk = tree.current_scene
	desk.set_process(false)
	desk.play(career)
	await tree.process_frame
	return career


func test_the_morning_paper_shows_the_directive_card_with_its_terms() -> void:
	session.office_enabled = true
	session.new_game()
	session.career.day = 6
	await scenes.goto(Scenes.MORNING)
	await tree.process_frame
	assert_true(node("DirectiveCard") != null)
	assert_false((node("DirectiveText") as Label).text.is_empty())
	assert_true(node("DirectiveTerm") != null)


func test_no_directive_card_on_the_training_days() -> void:
	session.office_enabled = true
	session.new_game()
	await scenes.goto(Scenes.MORNING)
	await tree.process_frame
	assert_true(node("DirectiveCard") == null)


func test_the_desk_shows_the_directive_progress_on_the_office_button() -> void:
	await _open_desk(6)
	var button := node("OfficeButton") as Button
	assert_true(button.visible)
	assert_true(button.text.begins_with("Talimat 0/"), button.text)
	await tap("OfficeButton")
	assert_true(node("DirectiveCard") != null)
	assert_true(node("DirectiveBar") != null)
	assert_true(desk.handle_back(), "geri tuşu ofis sayfasını kapatır")
	assert_true(node("DirectiveCard") == null)


func test_a_tube_memo_raises_the_badge_and_the_stamp_clears_it() -> void:
	await _open_desk(9)
	var plan: Array[Dictionary] = [{"id": "t1", "kind": "flavor", "at_served": 0, "text_key": "MEMO_F2", "sender_key": "MEMO_SENDER_RIZA"}]
	desk.shift.memo_plan = plan
	desk.shift._deliver_due_memos()
	desk._sync()
	var button := node("OfficeButton") as IconButton
	assert_eq(button.badge, 1)
	await tap("OfficeButton")
	assert_true(node("Memo_t1") != null)
	assert_true((node("MemoText") as Label).text.contains("Kalorifer"))
	await tap("MemoStamp_t1")
	assert_eq(button.badge, 0)
	assert_true(node("MemoStamp_t1") == null, "okunan notta damga düğmesi kalmaz")


func test_the_evening_summary_reports_the_directive_and_pocket_money() -> void:
	session.office_enabled = true
	session.new_game()
	var career: Career = session.career
	career.day = 6
	career.begin_day()
	var shift := career.new_shift()
	shift.start()
	shift.stats["story_minor"] = -Money.units(120)
	shift.end_now()
	session.shift = shift
	await scenes.goto(Scenes.EVENING)
	await tree.process_frame
	var texts := ""
	for label in (node("SummaryCard") as Control).find_children("*", "Label", true, false):
		texts += (label as Label).text + "\n"
	assert_true(texts.contains("Talimat"), texts)
	assert_true(texts.contains("Cebinden verdiğin"), texts)


func test_a_phone_call_shows_options_and_remembers_the_answer() -> void:
	await _open_desk(9)
	var plan: Array[Dictionary] = [{"id": "c1", "kind": "call", "call_id": "C1", "at_served": 0, "text_key": "CALL_C1", "sender_key": "CALL_SENDER_SELMA"}]
	desk.shift.memo_plan = plan
	desk.shift._deliver_due_memos()
	desk._sync()
	await tap("OfficeButton")
	assert_true(node("CallOption_c1_pay") != null and node("CallOption_c1_later") != null)
	await tap("CallOption_c1_pay")
	assert_true(node("CallOption_c1_pay") == null, "cevaplanan aramanın düğmeleri kalmaz")
	assert_true(node("CallAnswered") != null)
	assert_eq(int(desk.shift.stats["call_mood"]), 4)
