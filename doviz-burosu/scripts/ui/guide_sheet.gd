class_name GuideSheet
extends Control
## "Nasıl oynanır" rehberi: ilk yeni oyunda otomatik, sonra ana menüdeki (?) düğmesinden açılır. Sayfalı, ikonlu, kısa metinli.
## Atla / Geri / İleri / Başla; kapanınca `finished` yayılır. Metinler strings.csv (GUIDE_*).

signal finished

## Sayfalar: ikon, başlık anahtarı sonu, ve sayfanın altındaki küçük ikon+etiket çipleri.
const PAGES := [
	{"icon": "person", "chips": []},
	{"icon": "magnifier", "chips": [["uv", "TOOL_UV"], ["magnifier", "TOOL_MAGNIFIER"], ["book", "TOOL_BOOK"]]},
	{"icon": "stamp", "chips": [["check", "DECISION_COMPLETE"], ["close", "DECISION_REJECT"], ["siren", "DECISION_POLICE"]]},
	{"icon": "coin", "chips": [["rate", "TOOL_RATE_CALC"], ["calc", "TOOL_CALC"], ["till", "TOOL_TILL"]]},
	{"icon": "document", "n": 8, "chips": [["document", "GUIDE_CHIP_OFFICE"], ["phone", "GUIDE_CHIP_PHONE"], ["pin", "GUIDE_CHIP_PIN"]]},
	{"icon": "warning", "n": 5, "chips": []},
	{"icon": "house", "n": 6, "chips": [["wallet", "GUIDE_CHIP_PAY"], ["coin", "GUIDE_CHIP_SAVE"], ["heart", "GUIDE_CHIP_FAMILY"]]},
	{"icon": "heart", "n": 7, "chips": []},
]

var page := 0

var _title: Label
var _body: Label
var _chips: HBoxContainer
var _icon: IconView
var _dots: HBoxContainer
var _back_button: Button
var _next_button: Button


func _init() -> void:
	name = "GuideSheet"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 50
	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.055, 0.045, 1.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var safe := MarginContainer.new()
	safe.set_script(load("res://scripts/ui/safe_area_container.gd"))
	safe.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(safe)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 22)
	safe.add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	var progress := UiKit.label("", &"BoothMuted", "GuideProgress")
	progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(progress)
	var skip := UiKit.icon_button("close", tr("GUIDE_SKIP"), "GuideSkip", true, true, 64.0)
	skip.custom_minimum_size.x = 170.0
	skip.pressed.connect(_finish)
	top.add_child(skip)
	column.add_child(_spacer())
	var emblem := CenterContainer.new()
	column.add_child(emblem)
	_icon = IconView.new("person", Color("FFC857"), 120.0)
	_icon.stroke = 3.4
	emblem.add_child(_icon)
	_title = UiKit.label("", &"BoothTitle", "GuideTitle")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 44)
	column.add_child(_title)
	_body = UiKit.wrapped("", &"BoothBody", "GuideText")
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_body)
	_chips = HBoxContainer.new()
	_chips.alignment = BoxContainer.ALIGNMENT_CENTER
	_chips.add_theme_constant_override("separation", 26)
	column.add_child(_chips)
	column.add_child(_spacer())
	_dots = HBoxContainer.new()
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	_dots.add_theme_constant_override("separation", 10)
	column.add_child(_dots)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 14)
	column.add_child(buttons)
	_back_button = UiKit.icon_button("back", tr("GUIDE_BACK"), "GuideBack", true, true, 84.0)
	_back_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_back_button.pressed.connect(func() -> void: _show(page - 1))
	buttons.add_child(_back_button)
	_next_button = UiKit.button(tr("GUIDE_NEXT"), "GuideNext", &"", 84.0)
	_next_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_next_button.size_flags_stretch_ratio = 1.6
	_next_button.pressed.connect(_advance)
	buttons.add_child(_next_button)
	_show(0)


func _ready() -> void:
	_show(page)


func handle_back() -> bool:
	if page > 0:
		_show(page - 1)
	else:
		_finish()
	return true


func _spacer() -> Control:
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return spacer


func _advance() -> void:
	if page >= PAGES.size() - 1:
		_finish()
	else:
		_show(page + 1)


func _show(index: int) -> void:
	page = clampi(index, 0, PAGES.size() - 1)
	var data: Dictionary = PAGES[page]
	_icon.icon = str(data["icon"])
	var text_id := int(data.get("n", page + 1))
	_title.text = tr("GUIDE_T%d" % text_id)
	_body.text = tr("GUIDE_B%d" % text_id)
	(find_child("GuideProgress", true, false) as Label).text = tr("GUIDE_PAGE") % [page + 1, PAGES.size()]
	_back_button.visible = page > 0
	_next_button.text = tr("GUIDE_START") if page == PAGES.size() - 1 else tr("GUIDE_NEXT")
	UiKit.clear(_chips)
	for chip: Array in data["chips"]:
		var holder := VBoxContainer.new()
		holder.alignment = BoxContainer.ALIGNMENT_CENTER
		var chip_icon := IconView.new(str(chip[0]), Color("F5EEDC"), 44.0)
		chip_icon.stroke = 2.8
		holder.add_child(CenterContainer.new())
		holder.get_child(0).add_child(chip_icon)
		var caption := UiKit.label(tr(str(chip[1])), &"BoothMuted")
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		holder.add_child(caption)
		_chips.add_child(holder)
	UiKit.clear(_dots)
	for i in PAGES.size():
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(28 if i == page else 10, 10)
		dot.color = Color("FFC857") if i == page else Color(1, 1, 1, 0.25)
		_dots.add_child(dot)


func _finish() -> void:
	SettingsManager.set_value("game", "guide_seen", true)
	finished.emit()
	queue_free()
