class_name DeskToolSheets
extends RefCounted
## Araç çubuğunun açtığı sayfalar: kılavuz (kurlar / kurallar / bülten sekmeleri), katalog, kasa görünümü,
## hesap makinesi ve kur hesaplayıcı; ayrıca masaya iğnelenen kural notları ("PinnedNotes").

var desk: DeskScreen
var pins_box: VBoxContainer
var _calculator := Calculator.new()


func _init(owner_desk: DeskScreen) -> void:
	desk = owner_desk


## İğnelenen kural notları (gişe sahnesinin sağ alt köşesi): dokununca kılavuz o kuralın sayfasında açılır.
func build_pins(overlay: Control) -> void:
	pins_box = VBoxContainer.new()
	pins_box.name = "PinnedNotes"
	pins_box.z_index = 26
	pins_box.add_theme_constant_override("separation", 4)
	pins_box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	pins_box.alignment = BoxContainer.ALIGNMENT_END
	pins_box.offset_left = -260.0
	pins_box.offset_top = -220.0
	pins_box.offset_right = -8.0
	pins_box.offset_bottom = -14.0
	pins_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	pins_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	overlay.add_child(pins_box)
	refresh_pins()


func refresh_pins() -> void:
	if pins_box == null:
		return
	UiKit.clear(pins_box)
	for rule_id: Variant in GameSession.pinned_rules:
		var note := UiKit.icon_button("pin", tr("RULE_%s" % rule_id), "Pinned_%s" % rule_id, true, true, 64.0)
		note.custom_minimum_size.x = 250.0
		note.pressed.connect(open_info.bind(str(rule_id)))
		pins_box.add_child(note)


## Kur hesaplayıcı (satın alınmış araç): döviz tutarını yaz, PL karşılığını ALIŞ ve SATIŞ kuruyla gör (5 PL yuvarlaması dahil).
func open_rate() -> void:
	var shift := desk.shift
	var content := desk.sheets.open("TOOL_RATE_CALC")
	var codes := shift.ctx.book.foreign_codes(shift.ctx.day)
	var state := {"code": codes[0] if not codes.is_empty() else ""}
	var holder := [""]
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	content.add_child(tabs)
	var display := UiKit.label("", &"BigNumber", "RateDisplay")
	display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(display)
	var buy_label := UiKit.label("", &"GoalLabel", "RateBuy")
	var sell_label := UiKit.label("", &"GoalLabel", "RateSell")
	content.add_child(buy_label)
	content.add_child(sell_label)
	var refresh := func() -> void:
		var units := int(holder[0]) if not str(holder[0]).is_empty() else 0
		var minor := units * Money.UNIT
		var midday := shift.ctx.use_midday_rates()
		display.text = "%d %s" % [units, state["code"]]
		buy_label.text = tr("DESK_RATE_BUY_RESULT") % UiKit.money(shift.ctx.rates.buy_payout(state["code"], minor, shift.ctx.day, midday), "PL")
		sell_label.text = tr("DESK_RATE_SELL_RESULT") % UiKit.money(shift.ctx.rates.sell_cost(state["code"], minor, shift.ctx.day, midday), "PL")
	var group := ButtonGroup.new()
	for code in codes:
		var tab := UiKit.button(code, "RateTab_%s" % code, &"SegmentButton", 88.0)
		tab.toggle_mode = true
		tab.button_group = group
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.pressed.connect(func() -> void:
			state["code"] = code
			refresh.call())
		tabs.add_child(tab)
		if code == state["code"]:
			tab.button_pressed = true
	content.add_child(DeskSheets.keypad(holder, refresh))
	refresh.call()


## Kasa görünümü: para birimi başına kupür sayıları ve toplam.
func open_till() -> void:
	var shift := desk.shift
	var content := desk.sheets.open("TOOL_TILL")
	var list := DeskSheets.scroll(560)
	content.add_child(list.get_meta("scroll"))
	var codes: Array[String] = [shift.ctx.book.local_code]
	codes.append_array(shift.ctx.book.foreign_codes(shift.ctx.day))
	for code in codes:
		var parts: PackedStringArray = []
		var denoms := shift.ctx.book.denominations(code)
		denoms.reverse()
		for denom in denoms:
			var count := shift.ctx.till.count(code, denom)
			if count > 0:
				parts.append("%d × %d" % [count, denom])
		var card := PanelContainer.new()
		card.name = "TillRow_%s" % code
		card.theme_type_variation = &"CardPanel"
		list.add_child(card)
		var box := VBoxContainer.new()
		card.add_child(box)
		box.add_child(UiKit.label("%s — %s" % [code, UiKit.money(shift.ctx.till.total_minor(code), code)], &"CardTitle"))
		var detail := UiKit.label("  ".join(parts) if not parts.is_empty() else tr("DESK_TILL_EMPTY"), &"CardDetail")
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(detail)


func open_calculator() -> void:
	var content := desk.sheets.open("TOOL_CALC")
	var display := UiKit.label(_calculator.display, &"BigNumber", "CalcDisplay")
	display.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	content.add_child(display)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	content.add_child(grid)
	var layout := [["7", "7"], ["8", "8"], ["9", "9"], ["÷", "/"], ["4", "4"], ["5", "5"], ["6", "6"], ["×", "*"],
		["1", "1"], ["2", "2"], ["3", "3"], ["−", "-"], ["C", "C"], ["0", "0"], [".", "."], ["+", "+"]]
	for entry in layout:
		var key: String = entry[1]
		var names := {"/": "div", "*": "mul", "-": "sub", "+": "add", ".": "dot"}
		var button := UiKit.button(str(entry[0]), "Calc_%s" % names.get(key, key), &"KeyButton", 88.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void:
			_calculator.press(key)
			display.text = _calculator.display)
		grid.add_child(button)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	content.add_child(bottom)
	for entry in [["⌫", "<", "Calc_back"], ["=", "=", "Calc_equals"]]:
		var button := UiKit.button(str(entry[0]), str(entry[2]), &"KeyButton", 88.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void:
			_calculator.press(str(entry[1]))
			display.text = _calculator.display)
		bottom.add_child(button)


## Kılavuz: kurlar (varsayılan), kurallar (`start_rule` verilirse o kuralda) ve bülten (çalıntı seri/aranan varsa).
func open_info(start_rule := "") -> void:
	var shift := desk.shift
	var content := desk.sheets.open("TOOL_BOOK")
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	content.add_child(tabs)
	var body := VBoxContainer.new()
	content.add_child(body)
	var group := ButtonGroup.new()
	var rates_tab := UiKit.button(tr("DESK_RATES"), "InfoRatesTab", &"SegmentButton", 88.0)
	var rules_tab := UiKit.button(tr("DESK_RULES"), "InfoRulesTab", &"SegmentButton", 88.0)
	var buttons: Array[Button] = [rates_tab, rules_tab]
	var has_bulletin := not shift.ctx.bulletin.stolen_ranges.is_empty() or not shift.ctx.bulletin.wanted_faces.is_empty()
	if has_bulletin:
		var bulletin_tab := UiKit.button(tr("MORNING_BULLETIN"), "InfoBulletinTab", &"SegmentButton", 88.0)
		bulletin_tab.pressed.connect(_fill_bulletin.bind(body))
		buttons.append(bulletin_tab)
	for button in buttons:
		button.toggle_mode = true
		button.button_group = group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(button)
	rates_tab.pressed.connect(_fill_rates.bind(body))
	rules_tab.pressed.connect(func() -> void: _fill_rules(body))
	if start_rule.is_empty():
		rates_tab.button_pressed = true
		_fill_rates(body)
	else:
		rules_tab.button_pressed = true
		_fill_rules(body, start_rule)


## Kur tablosu: para birimi, ALIŞ (müşteri döviz satarken ödenen) ve SATIŞ kuru; telefonda okunsun diye büyük yazı.
func _fill_rates(body: VBoxContainer) -> void:
	UiKit.clear(body)
	var shift := desk.shift
	var midday := shift.ctx.use_midday_rates()
	var header := HBoxContainer.new()
	body.add_child(header)
	for text in ["", tr("DESK_BUY_RATE"), tr("DESK_SELL_RATE")]:
		var label := UiKit.label(text, &"CardTitle")
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.add_child(label)
	for code in shift.ctx.book.foreign_codes(shift.ctx.day):
		var rates := shift.ctx.rates.rates(code, shift.ctx.day, midday)
		var row := HBoxContainer.new()
		row.name = "RateRow_%s" % code
		body.add_child(row)
		for text in [code, UiKit.rate_text(int(rates["buy"])), UiKit.rate_text(int(rates["sell"]))]:
			var label := UiKit.label(text, &"BigNumber")
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			row.add_child(label)
	desk.tutorial_event(TutorialFlow.EVENT_RATES, {})


func _fill_bulletin(body: VBoxContainer) -> void:
	UiKit.clear(body)
	var shift := desk.shift
	var list := DeskSheets.scroll(560)
	body.add_child(list.get_meta("scroll"))
	var bulletin := shift.ctx.bulletin
	if not bulletin.stolen_ranges.is_empty():
		list.add_child(UiKit.label(tr("MORNING_STOLEN"), &"SlipTitle"))
		var row_index := 0
		for range_def in bulletin.stolen_ranges:
			var from_serial := shift.ctx.book.make_serial(range_def["currency"], range_def["series_id"], int(range_def["from"]))
			var to_serial := shift.ctx.book.make_serial(range_def["currency"], range_def["series_id"], int(range_def["to"]))
			var fresh := "  [%s]" % tr("RULEBOOK_NEW") if row_index >= shift.initial_stolen_count else ""
			list.add_child(UiKit.label("%s  %s – %s%s" % [range_def["currency"], from_serial, to_serial, fresh], &"GoalLabel", "StolenRow"))
			row_index += 1
	if not bulletin.wanted_faces.is_empty():
		list.add_child(UiKit.label(tr("MORNING_WANTED"), &"SlipTitle"))
		var faces := HBoxContainer.new()
		faces.name = "WantedFaces"
		faces.add_theme_constant_override("separation", 12)
		for face_id in bulletin.wanted_faces:
			var face := FaceView.new()
			face.setup(face_id, "?")
			face.custom_minimum_size = Vector2(110, 110)
			faces.add_child(face)
		list.add_child(faces)


func _fill_rules(body: VBoxContainer, start_rule := "") -> void:
	UiKit.clear(body)
	var book := RuleBook.new(desk.shift.ctx, desk.career, GameSession.pinned_rules, start_rule)
	book.pins_changed.connect(refresh_pins)
	body.add_child(book)


func open_catalog() -> void:
	var shift := desk.shift
	var content := desk.sheets.open("TOOL_CATALOG")
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	content.add_child(tabs)
	var body := VBoxContainer.new()
	content.add_child(body)
	var group := ButtonGroup.new()
	var codes: Array[String] = [shift.ctx.book.local_code]
	codes.append_array(shift.ctx.book.foreign_codes(shift.ctx.day))
	for code in codes:
		var button := UiKit.button(code, "CatalogTab_%s" % code, &"SegmentButton", 88.0)
		button.toggle_mode = true
		button.button_group = group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_fill_catalog.bind(body, code))
		tabs.add_child(button)
		if code == codes[0]:
			button.button_pressed = true
	_fill_catalog(body, codes[0])


func _fill_catalog(body: VBoxContainer, code: String) -> void:
	UiKit.clear(body)
	var book := desk.shift.ctx.book
	var list := DeskSheets.scroll(560)
	body.add_child(list.get_meta("scroll"))
	var general := book.spec(code, book.denominations(code)[0])
	var features := UiKit.label("%s · %s" % [tr("DESK_CATALOG_WATERMARK") % tr("WM_SHAPE_%s" % str(general["watermark_shape"]).to_upper()),
		tr("DESK_CATALOG_MICROTEXT") % general["microtext"]], &"CardDetail", "CatalogFeatures")
	features.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(features)
	for series_id in book.series_ids(code):
		var until := book.series_valid_until(code, series_id)
		var span := tr("DESK_CATALOG_SERIES_SPAN") % [book.series_valid_from(code, series_id), until] if until >= 0 else tr("DESK_CATALOG_SERIES_OPEN") % book.series_valid_from(code, series_id)
		list.add_child(UiKit.label("%s · %s" % [tr("DESK_CATALOG_SERIES") % [series_id, book.series_prefix(code, series_id)], span], &"CardDetail", "SeriesRow_%s" % series_id))
	for denom in book.denominations(code):
		var spec := book.spec(code, denom)
		var row := HBoxContainer.new()
		row.name = "CatalogRow_%d" % denom
		row.add_theme_constant_override("separation", 10)
		list.add_child(row)
		row.add_child(_swatch(Color(str(spec["color"]))))
		row.add_child(UiKit.label("%d" % denom, &"BigNumber"))
		var size: Vector2i = spec["size_mm"]
		var info := UiKit.label(tr("DESK_CATALOG_ROW") % [size.x, size.y, str(spec["portrait"]).get_slice("_", 1), tr("DESK_UV_AT_" + str(spec["uv_position"]).to_upper())], &"CardDetail")
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		row.add_child(_swatch(Color(str(spec["uv_color"]))))


static func _swatch(color: Color) -> ColorRect:
	var swatch := ColorRect.new()
	swatch.color = color
	swatch.custom_minimum_size = Vector2(44, 44)
	return swatch
