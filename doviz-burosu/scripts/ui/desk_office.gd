class_name DeskOffice
extends RefCounted
## Ofis: Merkez talimatı + tüple gelen notlar. Gişe sahnesinin köşesinde küçük bir düğme ("OfficeButton"; rozeti
## okunmamış not sayısı); yeni not düşünce tüp/telefon sesi ve kısa dürtme. Sayfası vardiya saatini durdurur.

var desk: DeskScreen
var button: IconButton
var _memos_announced := 0


func _init(owner_desk: DeskScreen) -> void:
	desk = owner_desk


func build(overlay: Control) -> void:
	button = UiKit.icon_button("document", tr("OFFICE_TITLE"), "OfficeButton", true, true, 72.0)
	button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	button.offset_left = 8.0
	button.offset_right = 198.0
	button.offset_top = -86.0
	button.offset_bottom = -14.0
	button.z_index = 26
	button.visible = false
	button.pressed.connect(open_sheet)
	overlay.add_child(button)


## Ofis düğmesi: talimat ilerlemesi + okunmamış not rozeti; yeni not düşünce tüp sesi ve kısa dürtme.
func sync() -> void:
	if button == null:
		return
	var shift := desk.shift
	var has_directive := not shift.directive.is_empty()
	button.visible = has_directive or not shift.memos_delivered.is_empty()
	if has_directive:
		var status := Directives.status(shift.directive, shift.stats)
		button.text = tr("DIR_CHIP") % [int(status["progress"]), int(status["target"])]
		var warn := bool(status["failed"]) or (not bool(status["at_least"]) and int(status["progress"]) == int(status["target"]))
		button.ink = Color("E2554A") if warn else Color("F5EEDC")
	else:
		button.text = tr("OFFICE_TITLE")
	button.badge = shift.unread_memos()
	if shift.memos_delivered.size() > _memos_announced:
		_memos_announced = shift.memos_delivered.size()
		_announce_memo()


func _announce_memo() -> void:
	var latest: Dictionary = desk.shift.memos_delivered[-1]
	Feel.sfx("phone" if str(latest["kind"]) in ["directive_change", "call"] else "tube")
	Feel.haptic(30)
	if Feel.instant or button == null:
		return
	Fx.capsule_drop(desk, button.global_position + Vector2(button.size.x / 2.0, 20.0))
	button.pivot_offset = button.size / 2.0
	var tween := desk.create_tween()
	for i in 3:
		tween.tween_property(button, "scale", Vector2(1.12, 1.12), 0.12)
		tween.tween_property(button, "scale", Vector2.ONE, 0.12)


func open_sheet() -> void:
	var shift := desk.shift
	var content := desk.sheets.open("OFFICE_TITLE")
	desk.sheets.pauses = true
	var list := DeskSheets.scroll(620)
	content.add_child(list.get_meta("scroll"))
	if not shift.directive.is_empty():
		var def := shift.directive
		var status := Directives.status(def, shift.stats)
		var card := PanelContainer.new()
		card.name = "DirectiveCard"
		card.theme_type_variation = &"SlipPanel"
		list.add_child(card)
		var box := VBoxContainer.new()
		card.add_child(box)
		box.add_child(UiKit.label(tr("DIR_TITLE"), &"SlipTitle"))
		var text := UiKit.label(UiKit.directive_text(def), &"SlipLine", "DirectiveText")
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(text)
		var bar := ProgressBar.new()
		bar.name = "DirectiveBar"
		bar.max_value = maxi(1, int(status["target"]))
		bar.value = mini(int(status["progress"]), int(bar.max_value))
		bar.show_percentage = false
		bar.custom_minimum_size.y = 18.0
		box.add_child(bar)
		box.add_child(UiKit.label(tr("DIR_PROGRESS") % [int(status["progress"]), int(status["target"])], &"SlipLine", "DirectiveProgress"))
		for line in UiKit.directive_terms(def):
			box.add_child(UiKit.label(line, &"SlipLine"))
	list.add_child(UiKit.label(tr("OFFICE_INBOX"), &"CardTitle"))
	if shift.memos_delivered.is_empty():
		list.add_child(UiKit.label(tr("OFFICE_NO_MEMOS"), &"CardDetail", "NoMemos"))
	var index := shift.memos_delivered.size()
	while index > 0:  # en yeni üstte
		index -= 1
		list.add_child(_memo_card(shift.memos_delivered[index]))


## Telefon notunun seçenekleri: cevaplanmadıysa düğmeler, cevaplandıysa seçilen cevap soluk yazılır.
func _add_call_options(box: VBoxContainer, memo: Dictionary) -> void:
	if not str(memo["answered"]).is_empty():
		for option: Dictionary in memo["options"]:
			if str(option["id"]) == str(memo["answered"]):
				box.add_child(UiKit.label("✓ " + tr(str(option["text_key"])), &"CardDetail", "CallAnswered"))
		return
	for option: Dictionary in memo["options"]:
		var option_button := UiKit.icon_button("phone", tr(str(option["text_key"])), "CallOption_%s_%s" % [memo["id"], option["id"]], true, false, 88.0)
		option_button.pressed.connect(func() -> void:
			if desk.shift.answer_call(str(memo["id"]), str(option["id"])):
				Feel.sfx("note_drop")
				open_sheet()
				sync())
		box.add_child(option_button)


func _memo_card(memo: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.name = "Memo_%s" % memo["id"]
	card.theme_type_variation = &"CardPanel"
	var box := VBoxContainer.new()
	card.add_child(box)
	box.add_child(UiKit.label(tr("OFFICE_FROM") % tr(str(memo["sender_key"])), &"CardDetail"))
	var body := ""
	match str(memo["kind"]):
		"call":
			body = tr(str(memo["text_key"]))
		"stolen_add":
			body = tr(str(memo["text_key"])) % [memo.get("from_serial", "?"), memo.get("to_serial", "?")]
		"directive_change":
			body = tr(str(memo["text_key"])) % UiKit.directive_text(Directives.by_id(str(memo.get("directive_id", ""))))
		_:
			body = tr(str(memo["text_key"]))
	var text := UiKit.label(body, &"CardTitle", "MemoText")
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(text)
	if str(memo["kind"]) == "call":
		_add_call_options(box, memo)
		return card
	if not bool(memo["read"]):
		var stamp := UiKit.icon_button("stamp", tr("OFFICE_READ"), "MemoStamp_%s" % memo["id"], true, false, 88.0)
		stamp.pressed.connect(func() -> void:
			desk.shift.mark_memo_read(str(memo["id"]))
			Feel.sfx("stamp")
			open_sheet()
			sync())
		box.add_child(stamp)
	return card
