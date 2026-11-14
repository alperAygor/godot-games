extends "res://tests/session_case.gd"
## Mod ekranları: menü kilidi, masa HUD'u, sonuç ekranı, paylaş, alıştırma, Sonsuz'da can ve yeni kural.

const DATE := "2026-10-26"

var desk: Control


func _label(node_name: String) -> String:
	return str(node(node_name).get("text"))


func _open_main(max_day := 0) -> void:
	session.modes().note_day_reached(max_day)
	await scenes.goto(Scenes.MAIN)
	await tree.process_frame


func _start_on_desk(start: Callable) -> void:
	start.call()
	await scenes.goto(Scenes.DESK)
	desk = tree.current_scene
	desk.set_process(false)
	await tree.process_frame


## Masadaki müşteriyi (bot) hamlesiyle işler; moda sonucu bildirir.
func _serve(correct := true) -> Dictionary:
	var bot := ClerkBot.new("perfect", "ui")
	desk.tick(3.0)
	var move := bot.move_for(desk.shift.current, desk.shift.current_verdict)
	if not correct:
		move.decision = Verdict.DECISION_POLICE if desk.shift.current_verdict.decision != Verdict.DECISION_POLICE else Verdict.DECISION_COMPLETE
	var result: Dictionary = desk.shift.submit(move)
	var outcome: Dictionary = session.mode.on_submit(result)
	desk._on_mode_submit(outcome)
	desk._shown = null
	desk._clear_customer()
	desk._sync()
	return outcome


func test_menu_modes_are_open_from_the_start() -> void:
	await _open_main(0)
	assert_false((node("DailyButton") as Button).disabled)
	assert_false((node("EndlessButton") as Button).disabled)
	assert_true(node("StoryCard") != null or node("NewGameButton") != null)


func test_daily_from_the_menu_runs_on_the_desk_with_its_own_hud() -> void:
	await _open_main(6)
	await tap("DailyButton")
	await wait_for_scene(Scenes.DESK)
	desk = tree.current_scene
	desk.set_process(false)
	await tree.process_frame
	assert_true(session.mode is DailyChallenge)
	assert_eq(_label("DayLabel"), "Günün Kuru")
	assert_eq(_label("MistakeLabel"), "Kalan: 12")
	assert_eq(_label("PayLabel"), "Puan: 0")
	assert_eq(session.modes().official_attempts_left(DailyChallenge.date_key()), 0, "resmi deneme başlarken harcanır")


func test_finishing_the_daily_shows_the_result_and_saves_the_best() -> void:
	await _start_on_desk(func() -> void: session.start_daily(DATE))
	for i in 12:
		await _serve()
	assert_true(node("ToResultButton") != null, "12 müşteri bitince sonuç düğmesi")
	assert_eq(_label("PayLabel"), "Puan: 1200")
	await tree.process_frame
	await tap("ToResultButton")
	await wait_for_scene(Scenes.MODE_RESULT)
	var score := int(_label("ModeScore"))
	assert_true(score >= 1200)
	assert_true(_label("ModeTitle").contains("26.10"))
	assert_true(node("ModeNewBest") != null)
	assert_true(_label("ModeBest").contains(str(score)))
	assert_eq(session.modes().best_daily(DATE), score)
	assert_true(node("ShareButton") != null)
	await tap("ShareButton")
	assert_eq(_label("ShareDone"), "Panoya kopyalandı")
	assert_eq(_label("ReplayButton"), "Alıştırma (puansız)", "resmi deneme bitti")


func test_practice_run_does_not_change_the_recorded_score() -> void:
	session.modes().start_daily_attempt(DATE)
	session.modes().record_daily(DATE, 5000)
	await _start_on_desk(func() -> void: session.start_daily(DATE))
	assert_false((session.mode as DailyChallenge).official)
	for i in 12:
		await _serve()
	await tree.process_frame
	await tap("ToResultButton")
	await wait_for_scene(Scenes.MODE_RESULT)
	assert_true(node("PracticeNote") != null)
	assert_true(node("ShareButton") == null, "alıştırma paylaşılmaz")
	assert_true(node("ModeNewBest") == null)
	assert_eq(session.modes().best_daily(DATE), 5000)


func test_bonus_attempt_makes_the_replay_official_again() -> void:
	await _start_on_desk(func() -> void: session.start_daily(DATE))
	for i in 12:
		await _serve()
	await tree.process_frame
	await tap("ToResultButton")
	await wait_for_scene(Scenes.MODE_RESULT)
	session.modes().grant_bonus_attempt(DATE)
	await scenes.goto(Scenes.MAIN)
	await tree.process_frame
	session.start_daily(DATE)
	assert_true((session.mode as DailyChallenge).official, "reklamla kazanılan deneme resmi")


func test_endless_adds_rules_and_announces_them() -> void:
	await _start_on_desk(func() -> void: session.start_endless("ui-1"))
	assert_eq(_label("DayLabel"), "Sonsuz")
	assert_eq(_label("MistakeLabel"), "Can: 3")
	for i in 5:
		await _serve()
	assert_eq(_label("PayLabel"), "Puan: 5")
	assert_true(((node("MiddayBanner") as Control).visible), "yeni kural duyurulur")
	assert_true(_label("MiddayText").begins_with("Yeni kural:"))
	assert_eq((session.mode as EndlessRun).active_rules.size(), 4)


func test_endless_ends_when_lives_run_out_and_shows_the_result() -> void:
	await _start_on_desk(func() -> void: session.start_endless("ui-2"))
	for i in 3:
		await _serve(false)
	assert_eq(_label("MistakeLabel"), "Can: 0")
	await tree.process_frame
	await tap("ToResultButton")
	await wait_for_scene(Scenes.MODE_RESULT)
	assert_eq(_label("ModeScore"), "3")
	assert_eq(session.modes().endless_best(), 3)
	assert_eq(_label("ReplayButton"), "Yeni koşu")
	await tap("ReplayButton")
	await wait_for_scene(Scenes.DESK)
	assert_eq((session.mode as EndlessRun).lives, 3, "yeni koşu tam canla başlar")


func test_pausing_and_leaving_abandons_the_run_without_a_score() -> void:
	await _start_on_desk(func() -> void: session.start_daily(DATE))
	desk.handle_back()
	await tree.process_frame
	await tap("PauseMenuButton")
	await wait_for_scene(Scenes.MAIN)
	assert_true(session.mode == null)
	assert_eq(session.modes().best_daily(DATE), -1)
	assert_eq(session.modes().official_attempts_left(DATE), 0, "çıkmak resmi denemeyi harcar")


func test_story_progress_unlocks_modes_from_the_morning() -> void:
	session.new_game()
	session.career.day = 6
	await scenes.goto(Scenes.MORNING)
	await tree.process_frame
	assert_true(session.modes().is_unlocked("daily"))
	await scenes.goto(Scenes.MAIN)
	session.new_game()  # yeni oyun kilidi geri almaz
	await tree.process_frame
	assert_true(session.modes().is_unlocked("daily"))
