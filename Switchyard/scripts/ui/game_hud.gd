class_name GameHud
extends VBoxContainer

## Oyun içi üst bölge: duraklat (sol), seviye başlığı + zorluk noktaları (orta), seviye haritası (sağ); altında tek kart:
## HAMLE (büyük sayı) · yıldız temposu (üç küçük yıldız: şu an hangi yıldızı alırsın) · PAR.
## Sayılar sabit genişlikli rakamlarla yazılır (zıplamaz); par'ı aşınca hamle sayısı sakin bir amber olur, alarm yok.
## Güvenli alan Game sahnesinin kenar boşluğuyla verilir; bu sınıf yalnız satırları kurar.

signal pause_requested
signal levels_requested

const TITLE_SIZE: int = UiTokens.TYPE_NUMERIC_SM
const CAPTION_SIZE: int = UiKit.TYPE_CAPTION
const VALUE_SIZE: int = UiTokens.TYPE_NUMERIC_LG
const PACE_ICON: float = 44.0
const PACE_GAP: int = UiTokens.SPACE_XS
const CARD_RADIUS: int = UiTokens.RADIUS_CARD
const CARD_PAD_X: int = UiTokens.SPACE_XL
const CARD_PAD_Y: int = UiTokens.SPACE_SM
const OVER_PAR: Color = UiTokens.C_WARNING
const PACE_OFF: Color = Color(0.0, 0.0, 0.0, 0.1)
const CUE_BOX: float = float(UiTokens.SIZE_CUE_DOT)

var _title: Label = null
var _cue: Control = null
var _moves_value: Label = null
var _par_value: Label = null
var _pace: Array[TextureRect] = []
var _difficulty: int = 1
var _slack: int = 0
var _last_moves: int = -1


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", UiTokens.SPACE_SM)


func _ready() -> void:
	_slack = ProgressData.to_count(GameData.value("balance", "three_star_slack", 0))
	var row: HBoxContainer = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, UiIconButton.BIG_TOUCH)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	var pause_button: UiIconButton = UiIconButton.new()
	pause_button.name = "PauseButton"
	pause_button.setup("lucide/pause", false, true)
	pause_button.pressed.connect(pause_requested.emit)
	row.add_child(pause_button)
	var middle: VBoxContainer = VBoxContainer.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.alignment = BoxContainer.ALIGNMENT_CENTER
	middle.add_theme_constant_override("separation", UiTokens.SPACE_XS)
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(middle)
	_title = UiKit.label("", TITLE_SIZE)
	_title.name = "Title"
	# Uzun başlık (EN/ES) yan düğmelere binmesin: taşan "…" olur.
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	middle.add_child(_title)
	_cue = DifficultyCue.new()
	_cue.name = "DifficultyCue"
	_cue.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	middle.add_child(_cue)
	var levels_button: UiIconButton = UiIconButton.new()
	levels_button.name = "MapButton"
	levels_button.setup("lucide/grid-2x2", false, true)
	levels_button.pressed.connect(levels_requested.emit)
	row.add_child(levels_button)
	var card: PanelContainer = UiKit.card(UiKit.SURFACE_SOFT, CARD_RADIUS, CARD_PAD_X, CARD_PAD_Y)
	card.name = "StatCard"
	add_child(card)
	var stats: HBoxContainer = HBoxContainer.new()
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(stats)
	_moves_value = _stat(stats, UiStrings.moves(), "MovesValue")
	stats.add_child(_pace_row())
	_par_value = _stat(stats, UiStrings.par(), "ParValue")


func _stat(parent: Control, caption: String, value_name: String) -> Label:
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(column)
	column.add_child(UiKit.label(caption, CAPTION_SIZE, UiKit.TEXT_MUTED))
	var value: Label = UiKit.numeric_label("0", VALUE_SIZE)
	value.name = value_name
	column.add_child(value)
	return value


func _pace_row() -> Control:
	var holder: CenterContainer = CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Pace"
	row.add_theme_constant_override("separation", PACE_GAP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(row)
	for _index: int in LevelProgress.MAX_STARS:
		var star: TextureRect = UiKit.tinted_icon("shell/star-fill", PACE_ICON, UiKit.STAR)
		row.add_child(star)
		_pace.append(star)
	return holder


func set_level(number: int, difficulty: int = 1) -> void:
	_title.text = UiStrings.level(number)
	_difficulty = difficulty
	(_cue as DifficultyCue).set_dots(LevelTile.cue_dots(difficulty))
	_last_moves = -1


func set_moves(moves: int, par: int) -> void:
	_moves_value.text = str(moves)
	_par_value.text = str(par)
	var earned: int = LevelProgress.stars_for(moves, par, _slack) if par > 0 else LevelProgress.MAX_STARS
	for index: int in _pace.size():
		_pace[index].modulate = UiKit.STAR if index < earned else PACE_OFF
	var over: bool = par > 0 and moves > par + _slack
	_moves_value.add_theme_color_override("font_color", OVER_PAR if over else UiKit.TEXT)
	if _last_moves >= 0 and moves != _last_moves and not UiData.reduced_motion():
		UiKit.pop(_moves_value)
	_last_moves = moves


func title_text() -> String:
	return _title.text


func moves_text() -> String:
	return _moves_value.text


func par_text() -> String:
	return _par_value.text


## Pace yıldızlarından şu an yanan sayısı (test).
func pace_stars() -> int:
	var lit: int = 0
	for star: TextureRect in _pace:
		if star.modulate == UiKit.STAR:
			lit += 1
	return lit


## Seviye başlığının altındaki küçük zorluk noktaları (5 nokta).
class DifficultyCue extends Control:
	var _dots: int = 1

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var gap: float = float(UiTokens.SIZE_CUE_GAP)
		custom_minimum_size = Vector2(float(LevelTile.CUE_DOTS) * CUE_BOX + float(LevelTile.CUE_DOTS - 1) * gap, CUE_BOX)

	func set_dots(count: int) -> void:
		_dots = count
		queue_redraw()

	func _draw() -> void:
		var gap: float = float(UiTokens.SIZE_CUE_GAP)
		for index: int in LevelTile.CUE_DOTS:
			var at: Vector2 = Vector2(CUE_BOX * 0.5 + float(index) * (CUE_BOX + gap), CUE_BOX * 0.5)
			draw_circle(at, CUE_BOX * 0.5, UiKit.ACCENT if index < _dots else Color(0.0, 0.0, 0.0, 0.12), true, -1.0, true)
