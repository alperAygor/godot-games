class_name OverloadBar
extends Control

## İnce aşırı yük şeridi (v0.2): ASMR paleti, yumuşak amber → mercan geçişi.
## Sadece gösterir; değeri OverloadModel hesaplar (set_overload(0..1)).
## Yükseklik 14–20 tasarım px: panoyu örtmez; kapsül çizim tahsissizdir.

const TRACK_COLOR: Color = Color(0.2157, 0.1882, 0.1647, 0.95)
const TRACK_EDGE: Color = Color(0.4235, 0.3765, 0.3294, 0.95)
const HOT_THRESHOLD: float = 0.75
const HOT_PULSE_SPEED: float = 4.0
const LOW_COLOR: Color = Color(0.9529, 0.7882, 0.4784, 1.0)
const HIGH_COLOR: Color = Color(0.9373, 0.5608, 0.4941, 1.0)
const FILL_LERP_SPEED: float = 6.0
const PULSE_DECAY: float = 1.2
const SEGMENTS: int = 14
const PULSE_LIMIT: float = 0.7

var _value: float = 0.0
var _display: float = 0.0
var _pulse: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


## 0..1 dolum. Değer artarken yumuşak nabız başlar (panik yok, sadece his).
func set_overload(value: float) -> void:
	var clamped: float = clampf(value, 0.0, 1.0)
	if clamped > _value + 0.0005:
		_pulse = minf(1.0, _pulse + 0.55)
	_value = clamped


func current_value() -> float:
	return _value


func _process(delta: float) -> void:
	_time += delta
	var next: float = lerpf(_display, _value, clampf(delta * FILL_LERP_SPEED, 0.0, 1.0))
	if absf(next - _value) < 0.0008:
		next = _value
	var pulse_next: float = maxf(0.0, _pulse - delta * PULSE_DECAY)
	var changed: bool = not is_equal_approx(next, _display) or not is_equal_approx(pulse_next, _pulse)
	_display = next
	_pulse = pulse_next
	if changed:
		queue_redraw()


func _draw() -> void:
	if size.x <= 8.0 or size.y <= 4.0:
		return
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	_draw_capsule(rect, TRACK_COLOR)
	_draw_fill(rect)
	_draw_segments(rect)
	if _display >= HOT_THRESHOLD:
		_draw_threshold_glow(rect)
	draw_line(Vector2(rect.position.x + rect.size.y * 0.5, rect.position.y + 2.0),
		Vector2(rect.end.x - rect.size.y * 0.5, rect.position.y + 2.0),
		Color(TRACK_EDGE.r, TRACK_EDGE.g, TRACK_EDGE.b, 0.45), 1.0)


func _draw_fill(rect: Rect2) -> void:
	var ratio: float = clampf(_display, 0.0, 1.0)
	if ratio <= 0.001:
		return
	var color: Color = fill_color(ratio)
	var pulse_boost: float = _pulse * (0.12 if ratio < PULSE_LIMIT else 0.22)
	if pulse_boost > 0.0:
		color = color.lerp(Color(1.0, 0.92, 0.80, 1.0), pulse_boost)
	var fill_rect: Rect2 = Rect2(rect.position, Vector2(maxf(rect.size.x * ratio, rect.size.y),
		rect.size.y))
	# Yumuşak dış parıltı: kapsülün 3 px genişlemiş hâli düşük alfa ile.
	var glow_rect: Rect2 = fill_rect.grow(2.0)
	_draw_capsule(glow_rect, Color(color.r, color.g, color.b, 0.16))
	_draw_capsule(fill_rect, color)


func _draw_segments(rect: Rect2) -> void:
	var inner: Rect2 = rect.grow(-rect.size.y * 0.25)
	var step: float = inner.size.x / float(SEGMENTS)
	for index: int in range(1, SEGMENTS):
		var x: float = inner.position.x + step * float(index)
		draw_line(Vector2(x, inner.position.y + 1.0), Vector2(x, inner.end.y - 1.0),
			Color(TRACK_COLOR.r, TRACK_COLOR.g, TRACK_COLOR.b, 0.55), 1.0)


## %75+ : yumuşak nefes alan mercan parıltı (panik değil, dikkat çeker).
func _draw_threshold_glow(rect: Rect2) -> void:
	var pulse: float = 0.5 + 0.5 * sin(_time * HOT_PULSE_SPEED)
	var glow: Color = Color(HIGH_COLOR.r, HIGH_COLOR.g, HIGH_COLOR.b, 0.10 + 0.12 * pulse)
	_draw_capsule(rect.grow(2.0 + pulse * 2.0), glow)


## Kapsül: gövde dikdörtgeni + iki yuvarlak uç (StyleBox tahsisi yapmadan).
func _draw_capsule(rect: Rect2, color: Color, filled: bool = true) -> void:
	var radius: float = rect.size.y * 0.5
	if rect.size.x <= radius * 2.0 or radius <= 0.5:
		if filled:
			draw_rect(rect, color, true)
		return
	if filled:
		draw_rect(Rect2(rect.position.x + radius, rect.position.y,
			rect.size.x - radius * 2.0, rect.size.y), color, true)
		draw_circle(Vector2(rect.position.x + radius, rect.position.y + radius), radius, color)
		draw_circle(Vector2(rect.end.x - radius, rect.position.y + radius), radius, color)
	else:
		draw_rect(Rect2(rect.position.x + radius, rect.position.y,
			rect.size.x - radius * 2.0, rect.size.y), color, false, 1.0)
		draw_arc(Vector2(rect.position.x + radius, rect.position.y + radius), radius,
			PI * 0.5, PI * 1.5, 12, color, 1.0, true)
		draw_arc(Vector2(rect.end.x - radius, rect.position.y + radius), radius,
			-PI * 0.5, PI * 0.5, 12, color, 1.0, true)


## 0..1 → amber/mercan yumuşak geçiş (agresif kırmızı yok; ARCHITECTURE §16).
func fill_color(ratio: float) -> Color:
	if ratio < 0.55:
		return LOW_COLOR
	return LOW_COLOR.lerp(HIGH_COLOR, clampf((ratio - 0.55) / 0.45, 0.0, 1.0))
