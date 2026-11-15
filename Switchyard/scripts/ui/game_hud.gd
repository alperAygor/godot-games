class_name GameHud
extends VBoxContainer

## Oyun içi üst bölge: duraklat (sol), seviye başlığı (orta), seviye haritası (sağ); altında hamle ve par sayaçları.
## Güvenli alan Game sahnesinin kenar boşluğuyla verilir; bu sınıf yalnız satırları kurar.
## Sayılar sabit genişlikli rakamlarla (UiKit.numeric_label) yazılır: sayaç değişirken zıplamaz.

signal pause_requested
signal levels_requested

const TITLE_SIZE: int = UiTokens.TYPE_NUMERIC_SM
const STAT_GAP: float = 120.0
const CAPTION_SIZE: int = UiKit.TYPE_CAPTION
const VALUE_SIZE: int = UiKit.TYPE_NUMERIC

var _title: Label = null
var _moves_value: Label = null
var _par_value: Label = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 0)


func _ready() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, UiKit.MIN_TOUCH)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	var pause_button: UiIconButton = UiIconButton.new()
	pause_button.name = "PauseButton"
	pause_button.setup("lucide/pause")
	pause_button.pressed.connect(pause_requested.emit)
	row.add_child(pause_button)
	_title = UiKit.label("", TITLE_SIZE)
	_title.name = "Title"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Uzun başlık (EN/ES) yan düğmelere binmesin: taşan "…" olur.
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(_title)
	var levels_button: UiIconButton = UiIconButton.new()
	levels_button.name = "MapButton"
	levels_button.setup("lucide/grid-2x2")
	levels_button.pressed.connect(levels_requested.emit)
	row.add_child(levels_button)
	var stats: HBoxContainer = HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", int(STAT_GAP))
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stats)
	_moves_value = _stat(stats, UiStrings.moves(), "MovesValue")
	_par_value = _stat(stats, UiStrings.par(), "ParValue")


func _stat(parent: Control, caption: String, value_name: String) -> Label:
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(column)
	column.add_child(UiKit.label(caption, CAPTION_SIZE, UiKit.TEXT_MUTED))
	var value: Label = UiKit.numeric_label("0", VALUE_SIZE)
	value.name = value_name
	column.add_child(value)
	return value


func set_level(number: int) -> void:
	_title.text = UiStrings.level(number)


func set_moves(moves: int, par: int) -> void:
	_moves_value.text = str(moves)
	_par_value.text = str(par)


func title_text() -> String:
	return _title.text


func moves_text() -> String:
	return _moves_value.text


func par_text() -> String:
	return _par_value.text
