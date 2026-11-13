class_name RetBar
extends Control

## Düz, yuvarlak uçlu ilerleme çubuğu (çizgisiz). Dolgu değişince yumuşakça uzar.

const FILL_SECONDS: float = 0.45

var fill_color: Color = UiKit.ACCENT
var track_color: Color = Color("e6e2d5")
var _fraction: float = 0.0
var _shown: float = 0.0
var _tween: Tween = null


func setup(height: float) -> void:
	custom_minimum_size = Vector2(0.0, height)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## `animated` kapalıysa doğrudan atlar (ilk açılışta 0'dan dolmasın diye çağıran seçer).
func set_fraction(value: float, animated: bool = true) -> void:
	_fraction = clampf(value, 0.0, 1.0)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if not animated or not is_inside_tree():
		_shown = _fraction
		queue_redraw()
		return
	_tween = create_tween()
	_tween.tween_method(_set_shown, _shown, _fraction, FILL_SECONDS)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _set_shown(value: float) -> void:
	_shown = value
	queue_redraw()


func _draw() -> void:
	var radius: int = int(size.y * 0.5)
	var track: StyleBoxFlat = StyleBoxFlat.new()
	track.bg_color = track_color
	track.set_corner_radius_all(radius)
	track.anti_aliasing = true
	draw_style_box(track, Rect2(Vector2.ZERO, size))
	var width: float = size.x * _shown
	if width <= 0.5:
		return
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(radius)
	fill.anti_aliasing = true
	draw_style_box(fill, Rect2(Vector2.ZERO, Vector2(maxf(width, size.y), size.y)))
