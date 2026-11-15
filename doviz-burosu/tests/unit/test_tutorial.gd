extends "res://tests/session_case.gd"
## Gün 1 etkileşimli öğreticisi gerçek masada, gerçek dokunuşlarla (TouchInput): yeni oyun → ilk müşteri doğru işlenir;
## atla, geri tuşu, uygulama duraklatma, dil değişimi, sıra dışı hamle, yalnızca ilk yeni oyunda, Rehber'den yeniden oynat.

var desk: DeskScreen


func _open_desk(day := 1, state := [false, false]) -> void:
	session.abort_mode()  # önceki testten kalan mod koşusu öğreticiyi kapatır
	DeskTutorial.write_state(state[0], state[1])
	assert_eq(DeskTutorial.read_state(), {"done": state[0], "replay": state[1]}, "durum dosyası yazıldı")
	var career := Career.load_default("tutorial-test")
	career.day = day
	session.career = career
	await scenes.goto(Scenes.DESK)
	desk = tree.current_scene as DeskScreen
	desk.set_process(false)
	await tree.process_frame


func _step() -> String:
	return desk.tutorial.flow.current() if desk.tutorial != null else ""


func _callout_text() -> String:
	return (node("TutorialText") as Label).text


func _type_units(units: int) -> void:
	for digit in str(units):
		await tap("Key_%s" % digit)


## Öğreticinin istediği her şeyi sırasıyla yapar: istek, incele, kapat, kur, kapat, öde, damga, sonuç, kapanış.
func _play_lesson_by_the_book() -> void:
	assert_eq(_step(), TutorialFlow.STEP_REQUEST)
	await tap("TutorialNext")
	assert_eq(_step(), TutorialFlow.STEP_INSPECT)
	await tap("NoteTile0")
	assert_true(node("InspectView") != null, "banknot inceleme sayfası açıldı")
	assert_eq(_step(), TutorialFlow.STEP_INSPECT_CLOSE)
	await tap("CloseSheetButton")
	assert_eq(_step(), TutorialFlow.STEP_RATES)
	await tap("ToolBookButton")
	assert_eq(_step(), TutorialFlow.STEP_RATES_CLOSE)
	assert_true(desk.tutorial.target_node() != null and desk.tutorial.target_node().name.begins_with("RateRow_"), "kur satırı parlatılır")
	await tap("CloseSheetButton")
	assert_eq(_step(), TutorialFlow.STEP_PAY)
	var payout: int = int(desk.shift.current_verdict.pay_out["PL"]) / Money.UNIT
	assert_true(_callout_text().contains(Money.format(payout * Money.UNIT, "PL", UiKit.locale())), "doğru tutar cümlede: " + _callout_text())
	await tap("PayButton_PL")
	assert_eq(_step(), TutorialFlow.STEP_PAY_TYPE)
	await _type_units(payout)
	await tap("NumpadOk")
	assert_eq(_step(), TutorialFlow.STEP_STAMP)
	await tap("CompleteButton")
	assert_eq(_step(), TutorialFlow.STEP_RESULT)
	assert_eq(_callout_text(), tr("TUT_RESULT_OK"))
	assert_true(node("Slip").visible, "sonuç fişi okunurken açık kalır")
	await tap("TutorialNext")
	assert_eq(_step(), TutorialFlow.STEP_OUTRO)
	await tap("TutorialNext")


func test_a_new_player_goes_from_the_menu_to_a_correct_first_customer() -> void:
	session.abort_mode()
	tree.root.get_node("SettingsManager").set_value("game", "guide_seen", false, false)
	if FileAccess.file_exists(JsonIO.user_file(DeskTutorial.STATE_FILE)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(JsonIO.user_file(DeskTutorial.STATE_FILE)))
	await scenes.goto(Scenes.MAIN)
	await tap("NewGameButton")
	await tree.process_frame
	await tap("GuideNext")  # tek karşılama sayfası
	await wait_for_scene(Scenes.MORNING)
	await tap("StartShiftButton")
	await wait_for_scene(Scenes.DESK)
	desk = tree.current_scene as DeskScreen
	await tree.process_frame
	assert_true(desk.tutorial != null, "ilk yeni oyunda öğretici kurulur")
	assert_true(node("TutorialCallout").visible)
	await _play_lesson_by_the_book()
	assert_eq(int(desk.shift.stats["correct"]), 1, "ilk müşteri doğru işlendi")
	assert_eq(int(desk.shift.stats["mistake_transactions"]), 0)
	assert_eq(_step(), TutorialFlow.STEP_DONE)
	assert_false(node("TutorialCallout").visible)
	assert_true(bool(DeskTutorial.read_state()["done"]), "bir kez görüldü")
	assert_false(DeskTutorial.wanted(1), "bir sonraki yeni oyunda çıkmaz")


func test_the_clock_waits_while_the_tutorial_talks() -> void:
	await _open_desk()
	assert_true(desk.tutorial.holds_clock())
	desk.tick(30.0)
	assert_eq(desk.shift.clock_text(), "09:00", "ders sürerken vardiya saati işlemez")
	await tap("TutorialSkip")
	assert_false(desk.tutorial.holds_clock())
	desk.tick(30.0)
	assert_ne(desk.shift.clock_text(), "09:00", "atlanınca saat işler")


func test_skip_ends_it_for_good() -> void:
	await _open_desk()
	await tap("TutorialNext")
	await tap("TutorialSkip")
	assert_eq(_step(), TutorialFlow.STEP_DONE)
	assert_true(desk.tutorial.flow.skipped)
	assert_false(node("TutorialCallout").visible)
	assert_true(bool(DeskTutorial.read_state()["done"]))
	await tap("CompleteButton")  # masa normal çalışmaya devam eder
	assert_eq(int(desk.shift.stats["served"]), 1)


func test_back_key_pauses_and_resume_returns_to_the_same_step() -> void:
	await _open_desk()
	await tap("TutorialNext")
	await tap("NoteTile0")
	await TouchInput.back(tree)  # açık sayfayı kapatır (normal masa davranışı)
	assert_true(desk.sheets.sheet == null)
	assert_eq(_step(), TutorialFlow.STEP_RATES)
	await TouchInput.back(tree)  # sayfa yokken: duraklat
	assert_true(node("ResumeButton") != null)
	assert_false(node("TutorialCallout").visible, "duraklatmada öğretici susar")
	assert_eq(_step(), TutorialFlow.STEP_HIDDEN)
	await tap("ResumeButton")
	assert_eq(_step(), TutorialFlow.STEP_RATES, "kalınan adımdan devam")
	assert_true(node("TutorialCallout").visible)


func test_app_pause_mid_tutorial_keeps_the_step() -> void:
	await _open_desk()
	await tap("TutorialNext")
	desk.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	await tree.process_frame
	assert_false(node("TutorialCallout").visible)
	desk.tick(60.0)
	assert_eq(desk.shift.clock_text(), "09:00")
	await tap("ResumeButton")
	assert_eq(_step(), TutorialFlow.STEP_INSPECT)
	assert_true(node("TutorialCallout").visible)


func test_switching_language_mid_tutorial_rewrites_the_sentence() -> void:
	await _open_desk()
	await tap("TutorialNext")
	TranslationServer.set_locale("tr")
	await tree.process_frame
	await tree.process_frame
	var turkish := _callout_text()
	assert_eq(turkish, tr("TUT_INSPECT"))
	TranslationServer.set_locale("en")
	await tree.process_frame
	await tree.process_frame
	assert_eq(_callout_text(), str(TranslationServer.translate("TUT_INSPECT")))
	assert_ne(_callout_text(), turkish)
	assert_eq(_step(), TutorialFlow.STEP_INSPECT, "dil adımı değiştirmez")
	TranslationServer.set_locale("tr")
	await tree.process_frame


func test_stamping_early_explains_the_mistake() -> void:
	await _open_desk()
	await tap("CompleteButton")  # ödeme yazmadan tamamla: eksik ödeme
	assert_eq(_step(), TutorialFlow.STEP_RESULT)
	assert_true(_callout_text().contains("2"), "cezasız uyarı sayısı söylenir: " + _callout_text())
	assert_eq(int(desk.shift.stats["mistake_transactions"]), 1)
	await tap("TutorialNext")
	await tap("TutorialNext")
	assert_eq(_step(), TutorialFlow.STEP_DONE)


func test_another_tool_page_asks_to_close_it() -> void:
	await _open_desk()
	await tap("ToolCalcButton")
	assert_eq(_step(), TutorialFlow.STEP_CLOSE_OTHER)
	assert_true(node("TutorialCallout").visible)
	await tap("TutorialSkip")  # balon sayfanın karartmasının üstünde: dokunulabilir
	assert_eq(_step(), TutorialFlow.STEP_DONE)
	assert_true(desk.sheets.sheet != null, "atlamak açık sayfayı kapatmaz")


func test_a_wrong_amount_is_caught_before_stamping() -> void:
	await _open_desk()
	await tap("TutorialNext")
	await tap("PayButton_PL")
	await _type_units(7)
	await tap("NumpadOk")
	assert_true(desk.tutorial.flow.paid_wrong())
	assert_eq(_step(), TutorialFlow.STEP_INSPECT, "erken ödeme hatırlanır, sıradaki eksik adım istenir")
	assert_eq(desk.tutorial.flow.text_key(TutorialFlow.STEP_PAY), "TUT_PAY_FIX", "ödeme adımına gelince düzelt denir")


func test_returning_players_do_not_see_it_again() -> void:
	await _open_desk(1, [true, false])
	assert_true(desk.tutorial == null, "bitmiş öğretici kurulmaz")
	assert_true(node("TutorialCallout") == null)


func test_it_only_starts_by_itself_on_day_one() -> void:
	await _open_desk(4, [false, false])
	assert_true(desk.tutorial == null)


func test_a_requested_replay_runs_on_a_later_day_once() -> void:
	await _open_desk(6, [true, true])
	assert_true(desk.tutorial != null)
	await tree.process_frame
	if desk.tutorial.flow.has_lesson():  # ilk müşteri ders için uygun değilse uygun olanı bekler
		assert_true(node("TutorialCallout").visible)
		await tap("TutorialSkip")
	else:
		desk.tutorial.skip()
	var state := DeskTutorial.read_state()
	assert_true(bool(state["done"]))
	assert_false(bool(state["replay"]), "yeniden oynatma bir kez")


func test_modes_never_show_it() -> void:
	DeskTutorial.write_state(false, false)
	session.start_daily()
	await scenes.goto(Scenes.DESK)
	desk = tree.current_scene as DeskScreen
	desk.set_process(false)
	assert_true(desk.tutorial == null)
	session.abort_mode()


func test_probe_plays_the_whole_story_day_one_through_the_tutorial() -> void:
	var probe := preload("res://tools/tutorial_probe_flow.gd")
	var report: Dictionary = await probe.play_first_day(tree)
	assert_true(bool(report["ok"]), "sonda: %s" % JSON.stringify(report))
	assert_eq(report["steps"], TutorialFlow.ORDER)
	assert_true(int(report["served"]) >= 5, "gün sonuna kadar oynandı")
