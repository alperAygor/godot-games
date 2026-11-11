class_name CircuitBackground
extends Control

## Menü / bölüm seçimi / sonuç arka planı v0.2: sıcak-koyu atölye hissi.
## Animasyonlu "devre" katmanı: yavaş akan enerji darbeleri, nefes alan ışık,
## sürüklenen toz zerreleri. AmbientBackdrop (3D) yoksa fallback'tir.
## Mobil bütçe: 15 FPS yeniden çizim, ~40 çizim çağrısı, tahsis yok.

const BG_COLOR: Color = Color(0.0784, 0.0667, 0.0627, 1.0)
const WARM_TOP: Color = Color(0.1647, 0.1176, 0.0902, 1.0)
const GRID_COLOR: Color = Color(0.5608, 0.8275, 0.9412, 0.035)
const TRACE_COLOR: Color = Color(0.4980, 0.9098, 0.7961, 0.10)
const TRACE_WARM: Color = Color(0.9529, 0.7882, 0.4784, 0.09)
const PULSE_MINT: Color = Color(0.4980, 0.9098, 0.7961, 0.85)
const PULSE_AMBER: Color = Color(0.9529, 0.7882, 0.4784, 0.75)
const NODE_COLOR: Color = Color(0.4980, 0.9098, 0.7961, 0.55)
const GLOW_COLOR: Color = Color(0.9529, 0.7882, 0.4784, 0.06)
const MOTE_COLOR: Color = Color(0.9529, 0.7882, 0.4784, 0.16)
const GRID_STEP: float = 120.0
const REDRAW_INTERVAL: float = 0.066
const MOTE_COUNT: int = 26

var _traces: Array[PackedVector2Array] = []
var _pulse_speeds: PackedFloat32Array = PackedFloat32Array()
var _pulse_phases: PackedFloat32Array = PackedFloat32Array()
var _nodes: PackedVector2Array = PackedVector2Array()
var _motes: Array[Vector4] = []
var _time: float = 0.0
var _accum: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.seed = 7
	_build_shapes()
	_build_motes()
	set_process(true)


func _process(delta: float) -> void:
	_time += delta
	_accum += delta
	if _accum >= REDRAW_INTERVAL:
		_accum = 0.0
		queue_redraw()


func _build_shapes() -> void:
	_add_trace([Vector2(0.03, 0.16), Vector2(0.28, 0.16), Vector2(0.28, 0.27), Vector2(0.52, 0.27)], 0.13, 0.0)
	_add_trace([Vector2(0.74, 0.10), Vector2(0.74, 0.23), Vector2(0.95, 0.23), Vector2(0.95, 0.36)], 0.10, 0.4)
	_add_trace([Vector2(0.05, 0.44), Vector2(0.36, 0.44), Vector2(0.36, 0.55), Vector2(0.10, 0.55)], 0.09, 0.7)
	_add_trace([Vector2(0.61, 0.41), Vector2(0.88, 0.41), Vector2(0.88, 0.51), Vector2(0.66, 0.51)], 0.12, 0.2)
	_add_trace([Vector2(0.12, 0.70), Vector2(0.12, 0.80), Vector2(0.42, 0.80), Vector2(0.42, 0.90)], 0.08, 0.9)
	_add_trace([Vector2(0.70, 0.64), Vector2(0.70, 0.76), Vector2(0.94, 0.76)], 0.11, 0.55)
	_nodes.append(Vector2(0.28, 0.27))
	_nodes.append(Vector2(0.52, 0.27))
	_nodes.append(Vector2(0.74, 0.23))
	_nodes.append(Vector2(0.36, 0.44))
	_nodes.append(Vector2(0.88, 0.51))
	_nodes.append(Vector2(0.42, 0.80))
	_nodes.append(Vector2(0.70, 0.76))
	_nodes.append(Vector2(0.95, 0.36))


func _add_trace(points: Array[Vector2], speed: float, phase: float) -> void:
	var packed: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in points:
		packed.append(point)
	_traces.append(packed)
	_pulse_speeds.append(speed)
	_pulse_phases.append(phase)


func _build_motes() -> void:
	for index: int in MOTE_COUNT:
		_motes.append(Vector4(
			_rng.randf_range(0.04, 0.96),
			_rng.randf_range(0.08, 0.94),
			_rng.randf_range(0.006, 0.020),
			_rng.randf_range(0.0, TAU)))


func _draw() -> void:
	if size.x <= 8.0 or size.y <= 8.0:
		return
	_draw_ground()
	_draw_grid()
	for index: int in _traces.size():
		_draw_trace(index)
	_draw_motes()
	_draw_breathing_light()


func _draw_ground() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG_COLOR, true)
	var bands: int = 8
	for band: int in bands:
		var t: float = float(band) / float(bands)
		var alpha: float = WARM_TOP.a * (1.0 - t) * 0.35
		draw_rect(Rect2(0.0, size.y * t * 0.6, size.x, size.y * 0.6 / float(bands)),
			Color(WARM_TOP.r, WARM_TOP.g, WARM_TOP.b, alpha), true)


func _draw_grid() -> void:
	var x: float = 0.0
	while x <= size.x:
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), GRID_COLOR, 1.0)
		x += GRID_STEP
	var y: float = 0.0
	while y <= size.y:
		draw_line(Vector2(0.0, y), Vector2(size.x, y), GRID_COLOR, 1.0)
		y += GRID_STEP


func _draw_trace(index: int) -> void:
	var points: PackedVector2Array = _screen_points(_traces[index])
	var warm: bool = index % 3 == 1
	draw_polyline(points, TRACE_WARM if warm else TRACE_COLOR, 2.0, true)
	var pulse_color: Color = PULSE_AMBER if warm else PULSE_MINT
	var speed: float = _pulse_speeds[index]
	var base_phase: float = _pulse_phases[index]
	for pulse: int in 2:
		var t: float = fmod(_time * speed + base_phase + float(pulse) * 0.5, 1.0)
		var position: Vector2 = _point_along(points, t)
		var breath: float = 0.55 + 0.45 * sin(_time * 1.4 + base_phase * TAU)
		draw_circle(position, 7.0, Color(pulse_color.r, pulse_color.g, pulse_color.b, 0.10 * breath))
		draw_circle(position, 3.0, Color(pulse_color.r, pulse_color.g, pulse_color.b, 0.55 * breath))
	var node_alpha: float = 0.35 + 0.25 * sin(_time * 0.8 + base_phase * TAU)
	# Durak noktaları (yalnızca trace sonları): sabit ve sakin.
	draw_circle(points[points.size() - 1], 3.5, Color(NODE_COLOR.r, NODE_COLOR.g,
		NODE_COLOR.b, node_alpha))


func _draw_motes() -> void:
	for mote: Vector4 in _motes:
		var x: float = mote.x * size.x + sin(_time * 0.25 + mote.w) * 14.0
		var y: float = (mote.y - fmod(_time * mote.z, 1.0)) * size.y
		if y < 0.0:
			y += size.y
		var alpha: float = MOTE_COLOR.a * (0.5 + 0.5 * sin(_time * 0.9 + mote.w))
		draw_circle(Vector2(x, y), 1.6, Color(MOTE_COLOR.r, MOTE_COLOR.g, MOTE_COLOR.b, alpha))


func _draw_breathing_light() -> void:
	var pulse: float = 0.5 + 0.5 * sin(_time * 0.45)
	var center: Vector2 = Vector2(size.x * 0.5, size.y * 0.30)
	draw_circle(center, 360.0 + 30.0 * pulse, Color(GLOW_COLOR.r, GLOW_COLOR.g,
		GLOW_COLOR.b, GLOW_COLOR.a * (0.7 + 0.3 * pulse)))
	draw_circle(center, 200.0 + 16.0 * pulse, Color(GLOW_COLOR.r, GLOW_COLOR.g,
		GLOW_COLOR.b, GLOW_COLOR.a * 1.2))


func _screen_points(normalized: PackedVector2Array) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in normalized:
		result.append(Vector2(point.x * size.x, point.y * size.y))
	return result


## Polyline üzerinde 0..1 normalize konumdaki nokta (eşit segment varsayımı).
func _point_along(points: PackedVector2Array, t: float) -> Vector2:
	var segments: int = points.size() - 1
	if segments <= 0:
		return points[0]
	var scaled: float = clampf(t, 0.0, 1.0) * float(segments)
	var index: int = mini(int(scaled), segments - 1)
	var local: float = scaled - float(index)
	return points[index].lerp(points[index + 1], local)
