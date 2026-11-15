class_name DeskNoteSheets
extends RefCounted
## Müşterinin kâğıtlarıyla ilgili sayfalar: banknot inceleme (büyük çizim + kader + araçlar), kimlik/beyan,
## ret nedeni listesi ve ödeme tuş takımı.

const INSPECT_SCALE := 3.4
## Neden listesi 13 kurala kadar uzar; ekranın büyük kısmını kullanır, sığmayan kısım kaydırılır.
const REASON_LIST_HEIGHT := 760.0

var desk: DeskScreen


func _init(owner_desk: DeskScreen) -> void:
	desk = owner_desk


func open_inspect(index: int) -> void:
	var shown := desk._shown
	if desk.model == null or index >= shown.notes.size():
		return
	var note := shown.notes[index]
	var sheets := desk.sheets
	var content := sheets.open("DESK_INSPECT_TITLE")
	sheets.set_title(content, "%s %d" % [note.currency, note.denom])
	var center := CenterContainer.new()
	var big := BanknoteView.new()
	big.name = "InspectView"
	big.setup(note, INSPECT_SCALE, desk.uv_lamp, false, desk.magnifier)
	center.add_child(big)
	content.add_child(center)
	for text in [tr("DESK_INFO_SERIAL") % note.serial, tr("DESK_INFO_SIZE") % [note.size_mm.x, note.size_mm.y],
			tr("DESK_INFO_PORTRAIT") % note.portrait.get_slice("_", 1), tr("DESK_INFO_SERIES") % note.series_id]:
		content.add_child(UiKit.label(text, &"SheetInfo"))
	var microtext := UiKit.label("", &"SheetInfo", "InspectMicrotext")
	microtext.visible = desk.magnifier
	microtext.text = tr("DESK_INFO_MICROTEXT") % note.microtext
	content.add_child(microtext)
	var fates := HBoxContainer.new()
	fates.add_theme_constant_override("separation", 8)
	content.add_child(fates)
	for fate in [Verdict.FATE_ACCEPT, Verdict.FATE_RETURN, Verdict.FATE_CONFISCATE]:
		var button := UiKit.button(tr("FATE_%s" % fate.to_upper()), "Inspect_%s" % fate, &"SegmentButton", 88.0)
		button.toggle_mode = true
		button.button_pressed = desk.model.fate(index) == fate
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void:
			desk.counter.set_fate(index, fate)
			for other in fates.get_children():
				(other as Button).set_pressed_no_signal(other.name == "Inspect_%s" % fate))
		fates.add_child(button)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	content.add_child(tools)
	var toolbar := desk.toolbar
	if desk.career.has_tool("uv"):
		var lamp := UiKit.button(tr("TOOL_UV"), "InspectUvButton", &"WarnButton", 88.0)
		lamp.toggle_mode = true
		lamp.button_pressed = desk.uv_lamp
		lamp.toggled.connect(func(on: bool) -> void:
			toolbar.uv_button.button_pressed = on
			big.set_tools(on, big.backlight, big.magnifier))
		tools.add_child(lamp)
	if desk.career.has_tool("magnifier"):
		var lens := UiKit.button(tr("TOOL_MAGNIFIER"), "InspectMagnifierButton", &"WarnButton", 88.0)
		lens.toggle_mode = true
		lens.button_pressed = desk.magnifier
		lens.toggled.connect(func(on: bool) -> void:
			toolbar.magnifier_button.button_pressed = on
			microtext.visible = on
			big.set_tools(big.uv_lamp, big.backlight, on))
		tools.add_child(lens)
	if desk.shift.ctx.rule_active("R_WATERMARK"):
		# Basılı tutunca arka ışık: bırakınca söner.
		var light := UiKit.button(tr("TOOL_BACKLIGHT"), "InspectBacklightButton", &"WarnButton", 88.0)
		light.button_down.connect(func() -> void: big.set_tools(big.uv_lamp, true, big.magnifier))
		light.button_up.connect(func() -> void: big.set_tools(big.uv_lamp, false, big.magnifier))
		tools.add_child(light)
	for button in tools.get_children():
		(button as Button).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desk.tutorial_event(TutorialFlow.EVENT_INSPECT, {"index": index})


## Kimlik / kaynak beyanı ayrıntı sayfası.
func open_document(kind: String) -> void:
	var shown := desk._shown
	if shown == null:
		return
	var content := desk.sheets.open("DOC_ID" if kind == DocTile.KIND_ID else "DOC_DECLARATION")
	if kind == DocTile.KIND_ID and shown.id_card != null:
		content.add_child(DocumentViews.build_id(shown.id_card))
	elif kind == DocTile.KIND_DECLARATION and shown.declaration != null:
		content.add_child(DocumentViews.build_declaration(shown.declaration))


func open_reason() -> void:
	if desk.model == null:
		return
	var content := desk.sheets.open("DESK_REASON_TITLE")
	var list := DeskSheets.scroll(REASON_LIST_HEIGHT)
	content.add_child(list.get_meta("scroll"))
	var shift := desk.shift
	for rule_id in shift.ctx.rules.active_ids(shift.ctx.day):
		var button := UiKit.button(tr("RULE_%s" % rule_id), "Reason_%s" % rule_id, &"GhostButton", 88.0)
		button.pressed.connect(desk._decide.bind(Verdict.DECISION_REJECT, rule_id))
		list.add_child(button)


func open_numpad(code: String) -> void:
	var model := desk.model
	if model == null:
		return
	var sheets := desk.sheets
	var content := sheets.open("DESK_NUMPAD_TITLE")
	sheets.set_title(content, tr("DESK_NUMPAD_TITLE") % code)
	var holder := ["" if model.paid_minor(code) == 0 else str(model.paid_minor(code) / Money.UNIT)]
	var display := UiKit.label("", &"BigNumber", "NumpadDisplay")
	display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(display)
	var refresh := func() -> void:
		display.text = "%s %s" % [holder[0] if not str(holder[0]).is_empty() else "0", code]
	refresh.call()
	content.add_child(DeskSheets.keypad(holder, refresh))
	var ok := UiKit.button(tr("DESK_OK"), "NumpadOk", &"", 96.0)
	ok.pressed.connect(func() -> void:
		Feel.sfx("pen_scratch")
		var minor := (int(holder[0]) if not str(holder[0]).is_empty() else 0) * Money.UNIT
		model.set_paid(code, minor)
		desk.counter.refresh_payment()
		desk.sheets.close()
		desk.tutorial_event(TutorialFlow.EVENT_PAID, {"code": code, "minor": minor}))
	content.add_child(ok)
	desk.tutorial_event(TutorialFlow.EVENT_NUMPAD, {"code": code})
