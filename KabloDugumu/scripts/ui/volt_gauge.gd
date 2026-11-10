class_name VoltGauge
extends Control

## Analog voltmetre (Control._draw): yarım daire skala + yumuşak hareketli iğne.
## Ölçek 0..250 V; dışarıdan gelen yüksek değerler ölçeğe kırpılır.
## İğne hedefe lerp ile yaklaşır; 180 V üstü kırmızı (tehlike) bölgesi.

const MIN_VOLTS: float = 0.0
const MAX_VOLTS: float = 250.0
const DANGER_VOLTS: float = 180.0
const START_DEGREES: float = 160.0
const SWEEP_DEGREES: float = 220.0
const TICK_STEP_VOLTS: float = 50.0
const NEEDLE_SPEED: float = 9.0

const FACE_COLOR: Color = Color(0.035, 0.055, 0.070, 0.920)
const RIM_COLOR: Color = Color(0.204, 0.906, 0.769, 0.900)
const DANGER_COLOR: Color = Color(1.000, 0.333, 0.400, 0.900)
const TICK_COLOR: Color = Color(0.561, 0.639, 0.690, 0.900)
const TEXT_COLOR: Color = Color(0.561, 0.639, 0.690, 1.0)
const NEEDLE_COLOR: Color = Color(1.000, 0.788, 0.290, 1.0)
const HUB_COLOR: Color = Color(0.130, 0.200, 0.250, 1.0)

var _target_volts: float = 0.0
var _display_volts: float = 0.0
var _font: Font = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = get_theme_font(&"font")
	set_process(true)


## 0..250 V aralığına kırpılır (data/levels.json voltajları 380 V'a çıkabilir).
func set_voltage(volts: int) -> void:
	_target_volts = clampf(float(volts), MIN_VOLTS, MAX_VOLTS)


func current_voltage() -> float:
	return _target_volts


func _process(delta: float) -> void:
	var next: float = lerpf(_display_volts, _target_volts,
		clampf(delta * NEEDLE_SPEED, 0.0, 1.0))
	if absf(next - _target_volts) < 0.4:
		next = _target_volts
	if not is_equal_approx(next, _display_volts):
		_display_volts = next
		queue_redraw()


func _draw() -> void:
	var radius: float = minf(size.x, size.y) * 0.42
	if radius <= 8.0:
		return
	var center: Vector2 = Vector2(size.x * 0.5, size.y * 0.60)
	var rim: Color = DANGER_COLOR if _display_volts >= DANGER_VOLTS else RIM_COLOR
	draw_circle(center, radius + 9.0, FACE_COLOR)
	draw_arc(center, radius + 9.0, deg_to_rad(START_DEGREES),
		deg_to_rad(START_DEGREES + SWEEP_DEGREES), 40,
		Color(rim.r, rim.g, rim.b, 0.30), 2.0, true)
	draw_arc(center, radius, deg_to_rad(START_DEGREES),
		deg_to_rad(START_DEGREES + SWEEP_DEGREES), 40, rim, 4.0, true)
	_draw_ticks(center, radius)
	_draw_needle(center, radius, clampf(_display_volts / MAX_VOLTS, 0.0, 1.0))


func _draw_ticks(center: Vector2, radius: float) -> void:
	var value: float = MIN_VOLTS
	while value <= MAX_VOLTS + 0.1:
		var ratio: float = (value - MIN_VOLTS) / (MAX_VOLTS - MIN_VOLTS)
		var angle: float = deg_to_rad(START_DEGREES + SWEEP_DEGREES * ratio)
		var direction: Vector2 = Vector2(cos(angle), sin(angle))
		var color: Color = DANGER_COLOR if value > DANGER_VOLTS else TICK_COLOR
		draw_line(center + direction * (radius * 0.86),
			center + direction * (radius * 0.98), color, 4.0, true)
		if _font != null:
			var label_center: Vector2 = center + direction * (radius * 0.66)
			draw_string(_font, label_center + Vector2(-30.0, 8.0), "%d" % int(value),
				HORIZONTAL_ALIGNMENT_CENTER, 60.0, 20, TEXT_COLOR)
		value += TICK_STEP_VOLTS
	if _font != null:
		draw_string(_font, center + Vector2(-8.0, radius * 0.42), "V",
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24, TEXT_COLOR)


func _draw_needle(center: Vector2, radius: float, ratio: float) -> void:
	var angle: float = deg_to_rad(START_DEGREES + SWEEP_DEGREES * ratio)
	var direction: Vector2 = Vector2(cos(angle), sin(angle))
	if ratio >= 0.72:
		draw_circle(center + direction * (radius * 0.78), 13.0,
			Color(NEEDLE_COLOR.r, NEEDLE_COLOR.g, NEEDLE_COLOR.b, 0.25))
	draw_line(center - direction * (radius * 0.14),
		center + direction * (radius * 0.78), NEEDLE_COLOR, 6.0, true)
	draw_circle(center, 13.0, HUB_COLOR)
	draw_circle(center, 6.0, NEEDLE_COLOR)
