extends "res://tests/session_case.gd"
## Gişe masası arayüzü: gerçek dokunma olaylarıyla Gün 1-3 akışı (headless).

var desk: Control


func _open(day := 1, salt := "desk-test") -> void:
	var career := Career.load_default(salt)
	career.day = day
	await scenes.goto(Scenes.DESK)
	desk = tree.current_scene
	desk.set_process(false)
	desk.play(career)
	await tree.process_frame


func _tap(node_name: String) -> void:
	await tap(node_name)


func _node(node_name: String) -> Control:
	return node(node_name)


func _type_units(units: int) -> void:
	for digit in str(units):
		await _tap("Key_%s" % digit)


func _pay(code: String, units: int) -> void:
	await _tap("PayButton_%s" % code)
	await _type_units(units)
	await _tap("NumpadOk")
	await tree.process_frame


## Masaya hazırladığımız bir müşteriyi koyar (rastgele müşteri yerine).
func _inject(customer: Customer) -> void:
	desk.shift.current = customer
	desk.shift.current_verdict = RuleEngine.new(desk.shift.ctx).evaluate(customer)
	desk.tick(0.0)
	await tree.process_frame


func _slip_text() -> String:
	var slip: Control = _node("Slip")
	var lines: PackedStringArray = []
	for child in slip.get_child(0).get_children():
		lines.append((child as Label).text)
	return "\n".join(lines)


func test_desk_opens_with_the_first_customer() -> void:
	await _open()
	assert_true(desk.shift.current != null)
	assert_ne((_node("CustomerName") as Label).text, "")
	assert_true((_node("CustomerSpeech") as Label).text.contains("FED"), "müşteri isteğini söyler")
	assert_eq((_node("DayLabel") as Label).text, "Gün 1")
	assert_eq((_node("ClockLabel") as Label).text, "09:00")
	assert_false((_node("CompleteButton") as Button).disabled)
	assert_false(_node("ToolUvButton").visible, "UV lamba 3. günde gelir")
	assert_true(_node("NoteTile0") != null)


func test_correct_exchange_earns_the_bonus() -> void:
	await _open()
	var expected_units: int = int(desk.shift.current_verdict.pay_out["PL"]) / Money.UNIT
	await _pay("PL", expected_units)
	assert_true((_node("PayButton_PL") as Button).text.contains(Money.format(expected_units * Money.UNIT, "PL", "tr")), "ödeme butonu tutarı gösterir")
	await _tap("CompleteButton")
	assert_eq(desk.shift.stats["correct"], 1)
	assert_eq(desk.shift.stats["mistake_transactions"], 0)
	assert_true(_node("Slip").visible)
	assert_true(_slip_text().contains("Doğru"), _slip_text())
	assert_eq(desk.shift.current, null, "müşteri gitti")
	assert_true((_node("CompleteButton") as Button).disabled, "müşteri yokken karar butonları kapalı")


func test_wrong_payment_prints_a_warning_slip() -> void:
	await _open()
	var expected_units: int = int(desk.shift.current_verdict.pay_out["PL"]) / Money.UNIT
	await _pay("PL", maxi(0, expected_units - 5))
	await _tap("CompleteButton")
	assert_eq(desk.shift.stats["mistake_transactions"], 1)
	assert_eq(desk.shift.stats["fined"], 0, "ilk iki hata cezasız")
	var text := _slip_text()
	assert_true(text.contains("UYARI") and text.contains("eksik ödedin"), text)
	assert_true(text.contains("kalan cezasız uyarı: 1"), text)


func test_third_mistake_is_fined_on_the_slip() -> void:
	await _open()
	for i in 3:
		while desk.shift.current == null:
			desk.tick(1.0)
		await tree.process_frame
		await _tap("CompleteButton")  # ödeme yazılmadan tamamla: eksik ödeme ya da yanlış karar
	assert_eq(desk.shift.stats["mistake_transactions"], 3)
	assert_eq(desk.shift.stats["fined"], 1)
	assert_true(_slip_text().contains("CEZA"), _slip_text())
	assert_true((_node("MistakeLabel") as Label).text.contains("3/2"))


func test_reject_with_a_reason_from_the_rule_list() -> void:
	await _open()
	await _tap("RejectButton")
	assert_true(_node("Reason_R_EXCHANGE") != null, "açık kuralların nedenleri listelenir")
	assert_true(_node("Reason_R_CATALOG") == null, "2. gün kuralı henüz yok")
	await _tap("Reason_R_EXCHANGE")
	assert_eq(desk.shift.stats["served"], 1)
	assert_eq(desk.shift.stats["mistake_transactions"], 1, "temiz müşteriyi reddetmek hata")
	assert_true(_slip_text().contains("Yanlış karar. Doğrusu: Tamamla."), _slip_text())
	assert_true(_node("Sheet") == null, "neden seçilince sayfa kapanır")


func test_police_with_a_confiscated_counterfeit_is_correct() -> void:
	await _open(3)
	var customer := new_customer()
	customer.notes.append(fake_note("FED", 20, 3, [Banknote.FAKE_UV_MISSING]))
	customer.notes.append(factory.make_genuine("FED", 10, 3))
	await _inject(customer)
	assert_true(_node("ToolUvButton").visible, "UV lamba 3. günde verilir")
	var zone: FateZone = _node("Zone_confiscate")
	zone._drop_data(Vector2.ZERO, {"note_index": 0})
	assert_eq(desk.model.fate(0), Verdict.FATE_CONFISCATE)
	assert_eq((_node("NoteTile0") as NoteTile)._badge.text, "El koy")
	await _tap("PoliceButton")
	assert_eq(desk.shift.stats["correct"], 1)
	assert_true(_slip_text().contains("Doğru"), _slip_text())


func test_police_without_confiscating_the_fake_is_a_note_mistake() -> void:
	await _open(3)
	var customer := new_customer()
	customer.notes.append(fake_note("FED", 20, 3, [Banknote.FAKE_UV_MISSING]))
	await _inject(customer)
	await _tap("PoliceButton")
	assert_eq(desk.shift.stats["mistake_transactions"], 1)
	assert_true(_slip_text().contains("1. banknot: doğrusu 'El koy'"), _slip_text())
	assert_true(_slip_text().contains("Kural: UV şerit"), _slip_text())


func test_dropping_a_note_on_a_zone_changes_its_fate() -> void:
	await _open()
	var zone: FateZone = _node("Zone_return")
	assert_true(zone._can_drop_data(Vector2.ZERO, {"note_index": 0}))
	assert_false(zone._can_drop_data(Vector2.ZERO, "x"))
	zone._drop_data(Vector2.ZERO, {"note_index": 0})
	assert_eq(desk.model.fate(0), Verdict.FATE_RETURN)
	assert_eq((_node("NoteTile0") as NoteTile)._badge.text, "İade")


func test_inspect_sheet_sets_the_note_fate_and_closes() -> void:
	await _open()
	await _tap("NoteTile0")
	assert_true(_node("InspectView") != null)
	assert_true(_node("Inspect_accept").button_pressed)
	await _tap("Inspect_confiscate")
	assert_eq(desk.model.fate(0), Verdict.FATE_CONFISCATE)
	assert_false(_node("Inspect_accept").button_pressed, "yalnızca seçilen basılı görünür")
	await _tap("CloseSheetButton")
	assert_true(_node("Sheet") == null)
	assert_eq((_node("NoteTile0") as NoteTile)._badge.text, "El koy")


func test_uv_lamp_toggle_reaches_the_notes() -> void:
	await _open(3)
	var tile: NoteTile = _node("NoteTile0")
	assert_false(tile.view.uv_lamp)
	await _tap("ToolUvButton")
	assert_true(tile.view.uv_lamp)
	assert_true(desk.uv_lamp)
	await _tap("NoteTile0")
	assert_true((_node("InspectView") as BanknoteView).uv_lamp, "inceleme de lambayı yansıtır")
	await _tap("InspectUvButton")
	assert_false((_node("InspectView") as BanknoteView).uv_lamp)
	assert_false(tile.view.uv_lamp)


func test_numpad_edits_and_limits() -> void:
	await _open()
	await _tap("PayButton_PL")
	await _tap("Key_0")
	assert_eq((_node("NumpadDisplay") as Label).text, "0 PL", "baştaki sıfır girilmez")
	await _type_units(123)
	assert_eq((_node("NumpadDisplay") as Label).text, "123 PL")
	await _tap("Key_back")
	assert_eq((_node("NumpadDisplay") as Label).text, "12 PL")
	await _tap("Key_C")
	assert_eq((_node("NumpadDisplay") as Label).text, "0 PL")
	await _type_units(12345678)
	assert_eq((_node("NumpadDisplay") as Label).text, "1234567 PL", "en fazla 7 hane")
	await _tap("NumpadOk")
	assert_eq(desk.model.paid_minor("PL"), 1234567 * Money.UNIT)


func test_calculator_sheet_works() -> void:
	await _open()
	await _tap("ToolCalcButton")
	for key in ["Calc_9", "Calc_mul", "Calc_8", "Calc_equals"]:
		await _tap(key)
	assert_eq((_node("CalcDisplay") as Label).text, "72")
	await _tap("Calc_back")
	assert_eq((_node("CalcDisplay") as Label).text, "72", "sonuç sonrası geri silme etkisiz")


func test_rates_and_rules_sheet() -> void:
	await _open()
	await _tap("ToolBookButton")
	assert_true(_node("RateRow_FED") != null)
	assert_true(_node("RateRow_AVR") == null, "AVR 2. günde açılır")
	var buy := int(desk.shift.ctx.rates.rates("FED", 1)["buy"]) / 100
	var row_text := ""
	for label in _node("RateRow_FED").get_children():
		row_text += (label as Label).text + " "
	assert_true(row_text.contains(Money.format(buy, "", "tr")), row_text)
	await _tap("InfoRulesTab")
	assert_true(_node("RateRow_FED") == null)


func test_catalog_sheet_lists_the_denominations() -> void:
	await _open(2)
	await _tap("ToolCatalogButton")
	assert_true(_node("CatalogTab_AVR") != null)
	assert_true(_node("CatalogTab_STR") == null)
	await _tap("CatalogTab_FED")
	assert_true(_node("CatalogRow_100") != null)
	assert_true(_node("CatalogRow_1") != null)
	assert_true(_node("CatalogRow_200") == null, "FED'de 200'lük yok")
	await _tap("CatalogTab_AVR")
	assert_true(_node("CatalogRow_200") != null)


func test_slip_hides_after_a_few_seconds_and_on_tap() -> void:
	await _open()
	await _tap("CompleteButton")
	assert_true(_node("Slip").visible)
	desk.tick(5.0)
	assert_false(_node("Slip").visible, "4 sn sonra kapanır")


func test_back_button_pauses_the_shift_and_closes_sheets() -> void:
	await _open()
	await _tap("ToolCalcButton")
	assert_true(desk.handle_back(), "açık sayfa kapanır")
	assert_true(_node("Sheet") == null)
	assert_true(desk.handle_back(), "sayfa yoksa vardiya duraklar")
	assert_true(_node("ResumeButton") != null)
	var frozen: float = desk.shift.elapsed
	desk.tick(5.0)
	assert_eq(desk.shift.elapsed, frozen, "duraklatmada saat akmaz")
	assert_true(desk.handle_back(), "ikinci geri tuşu duraklatmayı kapatır")
	assert_true(_node("Sheet") == null)
	desk.tick(5.0)
	assert_true(desk.shift.elapsed > frozen, "devam edince saat akar")


func test_resume_button_continues_and_pause_menu_leaves_to_the_main_menu() -> void:
	await _open()
	desk.handle_back()
	await tree.process_frame
	await _tap("ResumeButton")
	assert_true(_node("Sheet") == null)
	desk.handle_back()
	await tree.process_frame
	await _tap("PauseMenuButton")
	await wait_for_scene(Scenes.MAIN)


func test_the_end_of_shift_sheet_cannot_be_dismissed() -> void:
	await _open()
	desk.tick(400.0)
	await _tap("CompleteButton")
	assert_true(_node("ToEveningButton") != null, "mesai bitti sayfası")
	assert_true(desk.handle_back(), "geri tuşu yutulur")
	assert_true(_node("ToEveningButton") != null, "kapanmaz")


func test_a_finished_shift_goes_to_the_evening_with_its_shift() -> void:
	await _open()
	desk.tick(400.0)  # süre doldu, ekrandaki müşteri kalır
	assert_eq(desk.shift.phase, Shift.PHASE_CLOSING)
	await _tap("CompleteButton")
	assert_true(desk.shift.is_closed())
	var finished: Shift = desk.shift
	await _tap("ToEveningButton")
	await wait_for_scene(Scenes.EVENING)
	assert_eq(session.shift, finished)
	assert_eq(session.career.day, 1, "gün akşam bitene kadar ilerlemez")


## Bir müşteriyi beklenen hükme göre ARAYÜZDEN oynar: banknot bölgeleri, ödeme tuş takımı, karar butonları.
func _play_customer_perfectly() -> void:
	var verdict: Verdict = desk.shift.current_verdict
	for i in verdict.fates.size():
		if verdict.fates[i] != Verdict.FATE_ACCEPT:
			var zone: FateZone = _node("Zone_%s" % verdict.fates[i])
			zone._drop_data(Vector2.ZERO, {"note_index": i})
	match verdict.decision:
		Verdict.DECISION_COMPLETE:
			for code: String in verdict.pay_out:
				await _pay(code, int(verdict.pay_out[code]) / Money.UNIT)
			await _tap("CompleteButton")
		Verdict.DECISION_REJECT:
			await _tap("RejectButton")
			await _tap("Reason_%s" % verdict.reasons[0])
		Verdict.DECISION_POLICE:
			await _tap("PoliceButton")


func test_every_correct_move_for_days_one_to_three_can_be_played_on_screen() -> void:
	var played := 0
	var scenarios := {}
	for day in [1, 2, 3]:
		await _open(day, "ui-perfect-%d" % day)
		var guard := 0
		while played < 60 and guard < 400:
			guard += 1
			if desk.shift.current == null:
				desk.tick(1.0)
				await tree.process_frame
				continue
			if int(desk.shift.stats["served"]) >= 7:
				break
			scenarios[desk.shift.current.scenario] = true
			await _play_customer_perfectly()
			played += 1
			var last: Dictionary = desk.shift.entries.back()
			assert_eq(last["mistakes"], [], "gün %d müşteri %d (%s) arayüzden kusursuz oynanabilmeli" % [day, last["customer"], last["scenario"]])
		assert_eq(desk.shift.stats["mistake_transactions"], 0, "gün %d" % day)
	assert_true(played >= 18, "en az 18 müşteri oynandı (%d)" % played)
	assert_true(scenarios.has("counterfeit"), "sahte para senaryosu da oynandı: %s" % [scenarios.keys()])
