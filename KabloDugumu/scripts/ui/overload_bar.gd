class_name OverloadBar
extends Control

## Yatay aşırı yük barı (Control._draw): sarı -> turuncu -> kırmızı dolum,
## segmentli endüstriyel görünüm, dolarken nabız. set_overload(0..1) dışarıdan çağrılır.
## Gösterge yalnızca gösterir; bar değerini OverloadModel hesaplar.

const SEGMENTS: int = 20
const LOW_COLOR: Color = Color(1.000, 0.788, 0.290, 1.0)
const MID_COLOR: Color = Color(1.000, 0.550, 0.250, 1.0)
const HIGH_COLOR: Color = Color(1.000, 0.333, 0.400, 1.0)
const TRACK_COLOR: Color = Color(0.050, 0.080, 0.100, 0.850)
const BORDER_COLOR: Color = Color(0.130, 0.200, 0.250, 1.0)
const SEGMENT_GAP_COLOR: Color = Color(0.020, 0.030, 0.040, 0.550)
const THRESHOLD_COLOR: Color = Color(1.000, 0.333, 0.400, 0.800)
const THRESHOLD: float = 0.75
const FILL_LERP_SPEED: float = 9.0
const PULSE_DECAY: float = 1.6

var _value: float = 0.0
var _display: float = 0.0
var _pulse: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


## 0..1 arası dolum. Değer artarken nabız başlar (görsel geri bildirim).
func set_overload(value: float) -> void:
	var clamped: float = clampf(value, 0.0, 1.0)
	if clamped > _value + 0.0005:
		_pulse = 1.0
	_value = clamped


func current_value() -> float:
	return _value


func _process(delta: float) -> void:
	var next: float = lerpf(_display, _value, clampf(delta * FILL_LERP_SPEED, 0.0, 1.0))
	if absf(next - _value) < 0.0008:
		next = _value
	var pulse_next: float = maxf(0.0, _pulse - delta * PULSE_DECAY)
	var changed: bool = not is_equal_approx(next, _display) or _pulse > 0.0
	_display = next
	_pulse = pulse_next
	if changed:
		queue_redraw()


func _draw() -> void:
	if size.x <= 4.0 or size.y <= 4.0:
		return
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(rect, TRACK_COLOR, true)
	_draw_fill()
	var segment_width: float = size.x / float(SEGMENTS)
	for index: int in SEGMENTS + 1:
		var x: float = segment_width * float(index)
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), SEGMENT_GAP_COLOR, 2.0)
	var threshold_x: float = size.x * THRESHOLD
	draw_line(Vector2(threshold_x, -5.0), Vector2(threshold_x, size.y + 5.0),
		THRESHOLD_COLOR, 3.0)
	draw_rect(rect, BORDER_COLOR, false, 3.0)
	if _pulse > 0.0:
		var glow: Color = Color(HIGH_COLOR.r, HIGH_COLOR.g, HIGH_COLOR.b, _pulse * 0.35)
		draw_rect(Rect2(Vector2(-7.0, -7.0), size + Vector2(14.0, 14.0)), glow, false, 5.0)


func _draw_fill() -> void:
	var ratio: float = clampf(_display, 0.0, 1.0)
	if ratio <= 0.0:
		return
	var fill_width: float = size.x * ratio
	var color: Color = fill_color(ratio)
	if _pulse > 0.0:
		color = color.lerp(Color(1.0, 1.0, 1.0, 1.0), _pulse * 0.30)
	var shrink: float = _pulse * size.y * 0.12
	draw_rect(Rect2(Vector2(0.0, shrink * 0.5), Vector2(fill_width, size.y - shrink)), color, true)


## 0..1 -> sarı/turuncu/kırmızı renk geçişi.
func fill_color(ratio: float) -> Color:
	if ratio < 0.5:
		return LOW_COLOR.lerp(MID_COLOR, ratio * 2.0)
	return MID_COLOR.lerp(HIGH_COLOR, (ratio - 0.5) * 2.0)
