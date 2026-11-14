extends "res://tests/session_case.gd"
## Faz 6: araçlar (kilitler, büyüteç, arka ışık, kasa, kur hesaplayıcı), belgeler, bülten, gün ortası bildirimi, döviz alan müşteri.

var desk: Control


func _open(day := 1, extra_tools: Array = [], salt := "tools-test") -> void:
	var career := Career.load_default(salt)
	career.day = day
	career.household.flags["mother_sick"] = day >= 6
	for tool_id in extra_tools:
		career.tools.append(str(tool_id))
	await scenes.goto(Scenes.DESK)
	desk = tree.current_scene
	desk.set_process(false)
	desk.play(career)
	await tree.process_frame


func _inject(customer: Customer) -> void:
	desk.shift.current = customer
	desk.shift.current_verdict = RuleEngine.new(desk.shift.ctx).evaluate(customer)
	desk.tick(0.0)
	await tree.process_frame


func _label_text(node_name: String) -> String:
	return (node(node_name) as Label).text


# --- Araç kilitleri --------------------------------------------------------------

func test_locked_tools_are_hidden_until_they_exist() -> void:
	await _open(1)
	for tool_name in ["ToolUvButton", "ToolMagnifierButton", "ToolRateButton", "ToolTillButton"]:
		assert_false(node(tool_name).visible, "%s 1. günde görünmemeli" % tool_name)
	for tool_name in ["ToolBookButton", "ToolCalcButton", "ToolCatalogButton"]:
		assert_true(node(tool_name).visible, tool_name)


func test_tools_appear_when_the_day_and_ownership_allow() -> void:
	await _open(3)
	assert_true(node("ToolUvButton").visible, "UV lamba 3. günde verilir")
	assert_false(node("ToolTillButton").visible, "kasa görünümü 4. günde")
	await _open(4)
	assert_true(node("ToolTillButton").visible, "R_SELL_FOREIGN açıldı")
	assert_false(node("ToolRateButton").visible, "kur hesaplayıcı satın alınmadan görünmez")
	assert_false(node("ToolMagnifierButton").visible)
	await _open(8, ["magnifier", "rate_calc"])
	assert_true(node("ToolMagnifierButton").visible)
	assert_true(node("ToolRateButton").visible)


func test_counting_machine_shows_totals_only_when_owned() -> void:
	await _open(4)
	var customer := new_customer()
	customer.notes.append(factory.make_genuine("FED", 20, 4))
	customer.notes.append(factory.make_genuine("FED", 5, 4))
	await _inject(customer)
	assert_false(node("CountLabel").visible)
	await _open(4, ["counter"])
	await _inject(customer)
	assert_true(node("CountLabel").visible)
	assert_true(_label_text("CountLabel").contains("25"), _label_text("CountLabel"))
	assert_true(_label_text("CountLabel").contains("FED"))


# --- Kur hesaplayıcı ve kasa ------------------------------------------------------

func test_rate_calculator_shows_buy_and_sell_amounts() -> void:
	await _open(4, ["rate_calc"])
	await tap("ToolRateButton")
	for digit in "100":
		await tap("Key_%s" % digit)
	var rates: RateTable = desk.shift.ctx.rates
	var buy := Money.format(rates.buy_payout("FED", Money.units(100), 4), "PL", "tr")
	var sell := Money.format(rates.sell_cost("FED", Money.units(100), 4), "PL", "tr")
	assert_eq(_label_text("RateDisplay"), "100 FED")
	assert_true(_label_text("RateBuy").contains(buy), _label_text("RateBuy"))
	assert_true(_label_text("RateSell").contains(sell), _label_text("RateSell"))
	assert_true(node("RateTab_AVR") != null, "AVR 2. günden beri dolaşımda")
	assert_true(node("RateTab_STR") == null, "STR 6. günde açılır")


func test_rate_calculator_switches_currency() -> void:
	await _open(5, ["rate_calc"])
	await tap("ToolRateButton")
	await tap("RateTab_AVR")
	await tap("Key_5")
	var expected := Money.format(desk.shift.ctx.rates.buy_payout("AVR", Money.units(5), 5), "PL", "tr")
	assert_eq(_label_text("RateDisplay"), "5 AVR")
	assert_true(_label_text("RateBuy").contains(expected))


func test_till_sheet_lists_the_denominations() -> void:
	await _open(4)
	await tap("ToolTillButton")
	assert_true(node("TillRow_PL") != null)
	assert_true(node("TillRow_FED") != null)
	assert_true(node("TillRow_AVR") != null, "AVR 2. günden beri dolaşımda")
	assert_true(node("TillRow_STR") == null, "STR 6. günde açılır")
	var fed_texts := ""
	for child in node("TillRow_FED").get_child(0).get_children():
		fed_texts += (child as Label).text + " "
	assert_true(fed_texts.contains("3 × 1"), fed_texts)
	assert_true(fed_texts.contains("1 × 10"), fed_texts)


# --- Bülten ------------------------------------------------------------------------

func test_bulletin_tab_appears_with_the_bulletin() -> void:
	await _open(6)
	await tap("ToolBookButton")
	assert_true(node("InfoBulletinTab") == null, "çalıntı listesi 7. günde başlar")
	await _open(7)
	await tap("ToolBookButton")
	assert_true(node("InfoBulletinTab") != null)
	await tap("InfoBulletinTab")
	var expected: int = desk.shift.ctx.bulletin.stolen_ranges.size()
	assert_eq(expected, 3)
	var rows := 0
	for child in node("StolenRow").get_parent().get_children():
		if child is Label and (child as Label).text.contains(" – "):
			rows += 1
	assert_eq(rows, expected)
	assert_true(_label_text("StolenRow").contains(" – "))


func test_wanted_faces_are_listed_from_day_twelve() -> void:
	await _open(12)
	await tap("ToolBookButton")
	await tap("InfoBulletinTab")
	var faces := node("WantedFaces")
	assert_true(faces != null)
	assert_eq(faces.get_child_count(), 2)


# --- Belgeler -----------------------------------------------------------------------

func test_documents_appear_on_the_counter_and_open_their_sheets() -> void:
	await _open(10)
	var customer := seller("DNR", [50, 50], 10, 31)
	give_id(customer, desk.shift.ctx, 7)
	give_declaration(customer, desk.shift.ctx)
	await _inject(customer)
	assert_true(node("DocTile_id") != null)
	assert_true(node("DocTile_declaration") != null)
	await tap("DocTile_id")
	assert_true(node("IdView") != null)
	assert_eq(_label_text("IdName"), customer.holder_name)
	assert_true(_label_text("IdNumber").contains(customer.id_card.number))
	assert_true(_label_text("IdPhotoNo").contains("31"), "fotoğraf yüz numarasını gösterir")
	assert_true(_label_text("IdExpiry").contains(str(10 + 7)))
	assert_true(_label_text("IdSignature").contains(customer.id_card.signature))
	await tap("CloseSheetButton")
	await tap("DocTile_declaration")
	assert_true(node("DeclarationView") != null)
	assert_true(_label_text("DeclAmount").contains(Money.format(customer.declaration.amount_minor, "PL", "tr")))
	assert_true(_label_text("DeclSignature").contains(customer.declaration.signature))


func test_no_documents_no_tiles() -> void:
	await _open(10)
	await _inject(seller("FED", [5], 10))
	assert_true(node("DocTile_id") == null)
	assert_true(node("DocTile_declaration") == null)
	assert_eq(node("DocsRow").get_child_count(), 0)


# --- Büyüteç, filigran, görünürlük ----------------------------------------------------

func test_magnifier_reveals_the_microtext_in_the_inspect_sheet() -> void:
	await _open(13, ["magnifier"])
	var customer := new_customer()
	customer.notes.append(fake_note("FED", 20, 13, [Banknote.FAKE_MICROTEXT]))
	await _inject(customer)
	await tap("NoteTile0")
	assert_false(node("InspectMicrotext").visible, "büyüteç kapalıyken metin yok")
	assert_eq((node("InspectView") as BanknoteView).magnifier, false)
	await tap("InspectMagnifierButton")
	assert_true(node("InspectMicrotext").visible)
	assert_eq(_label_text("InspectMicrotext"), tr("DESK_INFO_MICROTEXT") % customer.notes[0].microtext)
	assert_true((node("InspectView") as BanknoteView).magnifier)
	assert_true(node("ToolMagnifierButton").button_pressed, "araç çubuğu da senkron")


func test_magnifier_button_is_not_offered_without_the_tool() -> void:
	await _open(13)
	await _inject(seller("FED", [20], 13))
	await tap("NoteTile0")
	assert_true(node("InspectMagnifierButton") == null)


func test_backlight_is_a_hold_button_available_from_the_watermark_rule() -> void:
	await _open(8)
	await _inject(seller("FED", [20], 8))
	await tap("NoteTile0")
	assert_true(node("InspectBacklightButton") == null, "filigran kuralı 9. günde")
	await _open(9)
	await _inject(seller("FED", [20], 9))
	await tap("NoteTile0")
	var button := node("InspectBacklightButton") as Button
	var view := node("InspectView") as BanknoteView
	assert_false(view.backlight)
	button.button_down.emit()
	assert_true(view.backlight, "basılı tutunca ışık yanar")
	button.button_up.emit()
	assert_false(view.backlight, "bırakınca söner")


func test_every_counterfeit_type_is_visible_with_the_right_tool() -> void:
	# Oyuncu her sahteliği bir araçla GÖREBİLMELİ: gözlem parmak izi (renk, boyut, portre + araç gözlemleri) gerçekten farklı olmalı.
	var genuine := factory.make_genuine("FED", 20, 13)
	var fingerprint := func(note: Banknote) -> Array:
		var seen := BanknoteView.observe(note, true, true, true)
		return [note.color, note.size_mm, note.portrait, seen["uv_color"], seen["watermark"], seen["microtext"]]
	var base: Array = fingerprint.call(genuine)
	for fake in Banknote.FAKE_TYPES:
		var forged := factory.make("FED", 20, 13, [fake])
		assert_ne(fingerprint.call(forged), base, "%s gözle fark edilebilmeli" % fake)
	# Araç yokken araca bağlı sahtelikler görünmez, bağlı olmayanlar görünür.
	var plain := func(note: Banknote) -> Array:
		var seen := BanknoteView.observe(note, false, false, false)
		return [note.color, note.size_mm, note.portrait, seen["uv_color"], seen["watermark"], seen["microtext"]]
	for fake in [Banknote.FAKE_UV_MISSING, Banknote.FAKE_UV_COLOR, Banknote.FAKE_WM_MISSING, Banknote.FAKE_WM_SHAPE, Banknote.FAKE_MICROTEXT]:
		assert_eq(plain.call(factory.make("FED", 20, 13, [fake])), plain.call(genuine), "%s araçsız görünmez" % fake)
	for fake in [Banknote.FAKE_COLOR, Banknote.FAKE_SIZE, Banknote.FAKE_PORTRAIT]:
		assert_ne(plain.call(factory.make("FED", 20, 13, [fake])), plain.call(genuine), "%s araçsız da görünür" % fake)


func test_damaged_notes_draw_without_errors() -> void:
	await _open(8)
	var customer := new_customer()
	customer.notes.append(factory.make_genuine("FED", 20, 8, {"torn": true}))
	customer.notes.append(factory.make_genuine("FED", 10, 8, {"taped": true}))
	await _inject(customer)
	await tree.process_frame
	await tree.process_frame
	assert_true((node("NoteTile0") as NoteTile).view.note.remaining_percent < 50)
	assert_true((node("NoteTile1") as NoteTile).view.note.taped)
	await tap("NoteTile0")
	await tree.process_frame
	assert_true(node("InspectView") != null)


# --- Gün ortası kur bildirimi -----------------------------------------------------------

func test_midday_banner_announces_the_rate_update_once() -> void:
	await _open(11)
	assert_false(node("MiddayBanner").visible)
	desk.tick(130.0)
	assert_false(node("MiddayBanner").visible, "13:00'ten önce yok")
	desk.tick(10.0)
	assert_true(node("MiddayBanner").visible)
	assert_true(_label_text("MiddayText").contains("13:00"))
	desk.tick(5.0)
	assert_false(node("MiddayBanner").visible, "birkaç sn sonra kapanır")
	desk.tick(20.0)
	assert_false(node("MiddayBanner").visible, "bir kez gösterilir")


func test_no_midday_banner_before_the_rule_opens() -> void:
	await _open(10)
	desk.tick(200.0)
	assert_false(node("MiddayBanner").visible)


func test_rates_sheet_changes_after_midday_on_day_eleven() -> void:
	await _open(11)
	await tap("ToolBookButton")
	var morning := ""
	for label in node("RateRow_FED").get_children():
		morning += (label as Label).text + " "
	await tap("CloseSheetButton")
	desk.tick(140.0)
	await tap("ToolBookButton")
	var afternoon := ""
	for label in node("RateRow_FED").get_children():
		afternoon += (label as Label).text + " "
	assert_ne(morning, afternoon, "öğleden sonra tabelada yeni kurlar")


# --- Döviz alan müşteri ----------------------------------------------------------------

func test_a_customer_buying_foreign_currency_is_playable_from_the_screen() -> void:
	await _open(4)
	var ctx: DayContext = desk.shift.ctx
	var customer := buyer("FED", 10, ctx, 95)
	await _inject(customer)
	assert_true(_label_text("CustomerSpeech").contains("satın al"), _label_text("CustomerSpeech"))
	assert_true(node("PayButton_PL") != null)
	assert_true(node("PayButton_FED") != null, "döviz satırı da var")
	var verdict: Verdict = desk.shift.current_verdict
	assert_eq(verdict.pay_out, {"FED": Money.units(10), "PL": Money.units(95)})
	for code: String in verdict.pay_out:
		await tap("PayButton_%s" % code)
		for digit in str(int(verdict.pay_out[code]) / Money.UNIT):
			await tap("Key_%s" % digit)
		await tap("NumpadOk")
	await tap("CompleteButton")
	assert_eq(desk.shift.stats["correct"], 1, _slip_text())


func _slip_text() -> String:
	var lines: PackedStringArray = []
	for child in node("Slip").get_child(0).get_children():
		lines.append((child as Label).text)
	return "\n".join(lines)


# --- Her senaryo ekrandan doğru oynanabilir ---------------------------------------------------

func _play_perfectly() -> void:
	var verdict: Verdict = desk.shift.current_verdict
	for i in verdict.fates.size():
		if verdict.fates[i] != Verdict.FATE_ACCEPT:
			(node("Zone_%s" % verdict.fates[i]) as FateZone)._drop_data(Vector2.ZERO, {"note_index": i})
	match verdict.decision:
		Verdict.DECISION_COMPLETE:
			for code: String in verdict.pay_out:
				await tap("PayButton_%s" % code)
				for digit in str(int(verdict.pay_out[code]) / Money.UNIT):
					await tap("Key_%s" % digit)
				await tap("NumpadOk")
			await tap("CompleteButton")
		Verdict.DECISION_REJECT:
			await tap("RejectButton")
			await tap_scrolled("Reason_%s" % verdict.reasons[0])
		Verdict.DECISION_POLICE:
			await tap("PoliceButton")


func test_every_scenario_at_day_thirteen_can_be_played_correctly_on_screen() -> void:
	await _open(13, ["uv", "magnifier", "counter", "rate_calc"], "all-scenarios")
	var ctx: DayContext = desk.shift.ctx
	var generator := CustomerFactory.new(ctx, Seed.rng("ui-all-scenarios"))
	var played := {}
	for scenario in CustomerFactory.SCENARIOS:
		var customer := generator.make_scenario(scenario)
		assert_true(customer != null, "13. günde %s üretilebilmeli" % scenario)
		if customer == null:
			continue
		await _inject(customer)
		assert_true(node("CompleteButton") != null)
		await _play_perfectly()
		var last: Dictionary = desk.shift.entries.back()
		assert_eq(last["mistakes"], [], "%s ekrandan kusursuz oynanabilmeli" % scenario)
		played[scenario] = true
		desk.shift.advance(3.0)  # sonraki müşteri için bekleme süresi
	assert_eq(played.size(), CustomerFactory.SCENARIOS.size())
