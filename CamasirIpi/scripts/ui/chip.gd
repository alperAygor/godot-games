class_name UiChip
extends PanelContainer

## Küçük, yarı saydam, çizgisiz sayaç hapı: ikon + sayı (jeton / yıldız).
## Sayı değişince kısa, yumuşak bir sayma animasyonu oynar.

const ICON_PIXELS: float = 40.0
const FONT_SIZE: int = UiTokens.TYPE_NUMERIC_SM
const HEIGHT: float = float(UiTokens.H_CHIP)
const COUNT_SECONDS: float = UiTokens.MOTION_COUNT_SECONDS
const ICON_GAP: int = UiTokens.SPACE_SM

var _value: int = 0
var _shown: float = 0.0
var _label: Label = null
var _tween: Tween = null
## İlk değer animasyonsuz yazılır: ekran açılırken 0'dan saymasın.
var _primed: bool = false


func setup(icon_name: String, icon_color: Color) -> void:
	theme_type_variation = &"ChipPanel"
	custom_minimum_size = Vector2(0.0, HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", ICON_GAP)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	var icon: TextureRect = UiKit.tinted_icon(icon_name, ICON_PIXELS, icon_color)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	# Sabit genişlikli rakamlar: sayı artarken hap titremesin.
	_label = UiKit.numeric_label("0", FONT_SIZE)
	row.add_child(_label)


func set_value(value: int, animated: bool = true) -> void:
	if not _primed:
		_primed = true
		animated = false
	elif value == _value:
		return
	var from: float = _shown
	_value = value
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if not animated:
		_set_shown(float(value))
		return
	_tween = create_tween()
	_tween.tween_method(_set_shown, from, float(value), COUNT_SECONDS)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _set_shown(value: float) -> void:
	_shown = value
	_label.text = UiKit.fmt_int(roundi(value))
