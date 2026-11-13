class_name MetaBar
extends Control

## İnce, yuvarlak uçlu ilerleme çubuğu (çizgisiz, düz). Değer değişince yumuşakça dolar.
## NEDEN özel çizim: ProgressBar teması projede tanımlı değil; burada iki hap çizmek yeter.

const FILL_SECONDS: float = 0.6

var track_color: Color = Color(0.0, 0.0, 0.0, 0.08)
var fill_color: Color = UiKit.ACCENT
var _value: float = 0.0
var _tween: Tween = null


func setup(bar_size: Vector2, fill: Color, track: Color) -> void:
	custom_minimum_size = bar_size
	size = bar_size
	fill_color = fill
	track_color = track
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_value(value: float, animated: bool = true) -> void:
	var target: float = clampf(value, 0.0, 1.0)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if not animated:
		_set_shown(target)
		return
	_tween = create_tween()
	_tween.tween_method(_set_shown, _value, target, FILL_SECONDS)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _set_shown(value: float) -> void:
	_value = value
	queue_redraw()


func _draw() -> void:
	var radius: float = size.y * 0.5
	_pill(Rect2(Vector2.ZERO, size), track_color, radius)
	if _value <= 0.0:
		return
	# Dolu kısım en az bir daire genişliğinde: çok küçük değerde bile yuvarlak kalsın.
	var width: float = maxf(size.x * _value, size.y)
	_pill(Rect2(Vector2.ZERO, Vector2(width, size.y)), fill_color, radius)


func _pill(rect: Rect2, color: Color, radius: float) -> void:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(int(radius))
	box.anti_aliasing = true
	draw_style_box(box, rect)
