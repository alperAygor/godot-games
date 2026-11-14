class_name NoteTile
extends DraggableItem
## Tezgâhtaki bir banknot: dokununca incelenir (`tapped`), sürüklenince masada taşınır ve kabul/iade/el koy tepsilerine bırakılabilir.

signal tapped(index: int)

const FATE_COLORS := {
	Verdict.FATE_ACCEPT: UiKit.GOOD_COLOR,
	Verdict.FATE_RETURN: UiKit.WARN_COLOR,
	Verdict.FATE_CONFISCATE: UiKit.BAD_COLOR,
}

var index := 0
var view: BanknoteView
var _badge: Label


func setup(note_index: int, note: Banknote, pixels_per_mm: float, lamp: bool, lens := false) -> void:
	index = note_index
	theme_type_variation = &"CardPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	view = BanknoteView.new()
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.setup(note, pixels_per_mm, lamp, false, lens)
	box.add_child(view)
	_badge = Label.new()
	_badge.theme_type_variation = &"SmallLabel"
	_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_badge)
	set_fate(Verdict.FATE_ACCEPT)


func set_fate(fate: String) -> void:
	_badge.text = tr("FATE_%s" % fate.to_upper())
	_badge.add_theme_color_override("font_color", FATE_COLORS[fate])


func set_uv_lamp(on: bool) -> void:
	view.set_tools(on, view.backlight, view.magnifier)


func set_magnifier(on: bool) -> void:
	view.set_tools(view.uv_lamp, view.backlight, on)


func _on_tap() -> void:
	tapped.emit(index)
