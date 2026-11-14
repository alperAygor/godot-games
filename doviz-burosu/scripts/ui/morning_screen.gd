extends Control
## Sabah gazetesi: manşet, kurlar, yeni kural, bülten, aile. İçeriği Newspaper üretir; burası sadece çizer.
## Ekran açılınca oyun kaydedilir (her sabah otomatik kayıt).

var _leave_sheet: Control = null


func _ready() -> void:
	if GameSession.career == null and not GameSession.continue_game():
		GameSession.new_game()
	var career := GameSession.career
	career.begin_day()
	GameSession.modes().note_day_reached(career.day)
	Analytics.log_event("day_start", {"day": career.day})
	GameSession.save()
	var paper := Newspaper.build(career)

	var column := UiKit.screen_column(self, 10)
	var list := UiKit.scroll_box()
	column.add_child(list.get_meta("scroll"))
	_build_paper(list, paper, career)
	var start := UiKit.button(tr("MORNING_START"), "StartShiftButton", &"InkButton", 96.0)
	start.pressed.connect(func() -> void: SceneManager.goto(Scenes.DESK))
	column.add_child(start)
	print("[Morning] gün %d" % career.day)


## Geri tuşu: onay sorar (ilerleme zaten kayıtlı); onay açıkken geri tuşu onu kapatır.
func handle_back() -> bool:
	if _leave_sheet != null:
		_close_leave()
		return true
	_open_leave()
	return true


func _build_paper(list: VBoxContainer, paper: Dictionary, career: Career) -> void:
	var masthead := UiKit.card("", &"FloatCard", "Masthead")
	var title := UiKit.label(tr("MORNING_MASTHEAD"), &"SheetTitle", "Masthead")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	masthead.add_child(title)
	var day_label := UiKit.label(tr("MORNING_DAY") % int(paper["day"]), &"SubtitleLabel", "DayLabel")
	day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	masthead.add_child(day_label)
	masthead.add_child(UiKit.wrapped(tr(str(paper["head_key"])), &"GoalTitle", "Headline"))
	masthead.add_child(UiKit.wrapped(tr(str(paper["body_key"])), &"GoalLabel", "HeadlineBody"))
	var masthead_panel: PanelContainer = masthead.get_meta("panel")
	var texture := PaperTexture.new()
	texture.seed_text = "morning%d" % int(paper["day"])
	masthead_panel.add_child(texture)
	masthead_panel.move_child(texture, 0)  # gazete künyesine kâğıt dokusu (yazının altında)
	list.add_child(masthead_panel)

	list.add_child(_rates_card(paper))
	list.add_child(_rule_card(paper))
	var directive := _directive_card(paper)
	if directive != null:
		list.add_child(directive)
	var bulletin := _bulletin_card(paper)
	if bulletin != null:
		list.add_child(bulletin)
	list.add_child(_family_card(paper, career))


func _rates_card(paper: Dictionary) -> Control:
	var box := UiKit.card(tr("MORNING_RATES"), &"CardPanel", "RatesCard", "rate")
	var header := HBoxContainer.new()
	box.add_child(header)
	for text in ["", tr("DESK_BUY_RATE"), tr("DESK_SELL_RATE"), ""]:
		var cell := UiKit.label(text, &"SheetInfo")
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.add_child(cell)
	for entry: Dictionary in paper["rates"]:
		var row := HBoxContainer.new()
		row.name = "Rate_%s" % entry["code"]
		box.add_child(row)
		var change := int(entry["change_bp"])
		var cells := [
			UiKit.label(str(entry["code"]), &"BigNumber"),
			UiKit.label(UiKit.rate_text(int(entry["buy"])), &"CardTitle"),
			UiKit.label(UiKit.rate_text(int(entry["sell"])), &"CardTitle"),
			UiKit.label(UiKit.change_text(change) if change != 0 else "", &"CardDetail"),
		]
		(cells[3] as Label).add_theme_color_override("font_color", UiKit.BAD_COLOR if change > 0 else UiKit.GOOD_COLOR)
		for cell: Label in cells:
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			row.add_child(cell)
	return box.get_meta("panel")


func _rule_card(paper: Dictionary) -> Control:
	var box := UiKit.card(tr("MORNING_NEW_RULE"), &"SlipPanel", "RuleCard", "book")
	var rules: Array = paper["new_rules"]
	if rules.is_empty():
		box.add_child(UiKit.wrapped(tr("MORNING_NO_NEW_RULE"), &"GoalLabel", "NoNewRule"))
	for rule_id: Variant in rules:
		box.add_child(UiKit.wrapped(tr("RULE_%s" % rule_id), &"SlipTitle", "NewRule_%s" % rule_id))
		box.add_child(UiKit.wrapped(tr("RULE_%s_DESC" % rule_id), &"SlipLine"))
	for tool_id: Variant in paper["new_tools"]:
		box.add_child(UiKit.wrapped(tr("MORNING_NEW_TOOL") % tr("TOOL_%s" % str(tool_id).to_upper()), &"SlipTitle", "NewTool_%s" % tool_id))
	return box.get_meta("panel")


## Merkez talimatı: günün hedefi ve şartları (yönetimden gelen not).
func _directive_card(paper: Dictionary) -> Control:
	var def: Dictionary = paper["directive"]
	if def.is_empty():
		return null
	var box := UiKit.card(tr("DIR_TITLE"), &"SlipPanel", "DirectiveCard", "document")
	box.add_child(UiKit.wrapped(UiKit.directive_text(def), &"SlipTitle", "DirectiveText"))
	for line in UiKit.directive_terms(def):
		box.add_child(UiKit.label(line, &"SlipLine", "DirectiveTerm"))
	return box.get_meta("panel")


func _bulletin_card(paper: Dictionary) -> Control:
	var stolen: Array = paper["stolen"]
	var wanted: Array = paper["wanted_faces"]
	if stolen.is_empty() and wanted.is_empty():
		return null
	var box := UiKit.card(tr("MORNING_BULLETIN"), &"CardBrokenPanel", "BulletinCard", "siren")
	if not stolen.is_empty():
		box.add_child(UiKit.label(tr("MORNING_STOLEN"), &"SlipTitle"))
		for entry: Dictionary in stolen:
			box.add_child(UiKit.label("%s  %s – %s" % [entry["currency"], entry["from_serial"], entry["to_serial"]], &"GoalLabel"))
	if not wanted.is_empty():
		box.add_child(UiKit.label(tr("MORNING_WANTED"), &"SlipTitle"))
		var faces := HBoxContainer.new()
		faces.name = "WantedFaces"
		faces.add_theme_constant_override("separation", 12)
		for face_id: Variant in wanted:
			var face := FaceView.new()
			face.setup(int(face_id), "?")
			face.custom_minimum_size = Vector2(110, 110)
			faces.add_child(face)
		box.add_child(faces)
	return box.get_meta("panel")


func _family_card(paper: Dictionary, career: Career) -> Control:
	var box := UiKit.card("", &"CardPanel", "FamilyCard")
	box.add_child(UiKit.wrapped(tr(str(paper["family_key"])), &"GoalTitle", "FamilyLine"))
	box.add_child(UiKit.label(tr("NEWS_CASH") % UiKit.money(int(paper["cash_minor"]), "PL"), &"GoalLabel", "CashLine"))
	if int(paper["rent_today_minor"]) > 0:
		box.add_child(UiKit.label(tr("NEWS_RENT_TODAY") % UiKit.money(int(paper["rent_today_minor"]), "PL"), &"GoalLabel", "RentLine"))
	var unpaid: Array = paper["last_unpaid"]
	if not unpaid.is_empty():
		var names: PackedStringArray = []
		for expense_id: Variant in unpaid:
			names.append(tr("EXPENSE_%s" % str(expense_id).to_upper()))
		box.add_child(UiKit.wrapped(tr("NEWS_LAST_UNPAID") % ", ".join(names), &"CardDetail", "UnpaidLine"))
	return box.get_meta("panel")


func _open_leave() -> void:
	_leave_sheet = Control.new()
	_leave_sheet.name = "LeaveSheet"
	_leave_sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_leave_sheet)
	var dim := ColorRect.new()
	dim.color = UiKit.DIM_COLOR
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_leave_sheet.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_leave_sheet.add_child(center)
	var box := UiKit.card("", &"FloatCard")
	center.add_child(box.get_meta("panel"))
	box.add_child(UiKit.label(tr("MORNING_LEAVE_TITLE"), &"SheetTitle", "LeaveTitle"))
	box.add_child(UiKit.wrapped(tr("MORNING_LEAVE_TEXT"), &"GoalLabel"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var yes := UiKit.button(tr("COMMON_YES"), "LeaveYesButton", &"", 84.0)
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yes.pressed.connect(func() -> void: SceneManager.goto(Scenes.MAIN))
	var no := UiKit.button(tr("COMMON_NO"), "LeaveNoButton", &"GhostButton", 84.0)
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	no.pressed.connect(_close_leave)
	row.add_child(yes)
	row.add_child(no)


func _close_leave() -> void:
	if _leave_sheet != null:
		remove_child(_leave_sheet)
		_leave_sheet.queue_free()
		_leave_sheet = null
