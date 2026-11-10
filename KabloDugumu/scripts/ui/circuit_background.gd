class_name CircuitBackground
extends Control

## Ana menü / bölüm seçimi arka planı: koyu neon devre tahtası.
## Shader yerine kodla çizilir (derleme riski yok); çizimler normalize (0..1)
## tutulduğu için kontrol boyutu değişse de bozulmaz. Mobil için 20 FPS'e seyreltildi.

const BG_COLOR: Color = Color(0.043, 0.059, 0.078, 1.0)
const GRID_COLOR: Color = Color(0.110, 0.470, 0.430, 0.160)
const GRID_STEP: float = 72.0
const TRACE_COLOR: Color = Color(0.204, 0.906, 0.769, 0.300)
const TRACE_ALT_COLOR: Color = Color(1.000, 0.788, 0.290, 0.220)
const NODE_COLOR: Color = Color(0.204, 0.906, 0.769, 0.850)
const STRIPE_BG: Color = Color(0.050, 0.060, 0.080, 0.900)
const STRIPE_COLOR: Color = Color(1.000, 0.788, 0.290, 0.320)
const REDRAW_INTERVAL: float = 0.05

var _traces: Array[PackedVector2Array] = []
var _nodes: Array[Vector2] = []
var _time: float = 0.0
var _redraw_accum: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_shapes()
	set_process(true)


func _process(delta: float) -> void:
	_time += delta
	_redraw_accum += delta
	if _redraw_accum >= REDRAW_INTERVAL:
		_redraw_accum = 0.0
		queue_redraw()


func _build_shapes() -> void:
	_traces.append(PackedVector2Array([
		Vector2(0.08, 0.18), Vector2(0.30, 0.18), Vector2(0.30, 0.30), Vector2(0.58, 0.30),
	]))
	_traces.append(PackedVector2Array([
		Vector2(0.72, 0.12), Vector2(0.72, 0.26), Vector2(0.90, 0.26), Vector2(0.90, 0.42),
	]))
	_traces.append(PackedVector2Array([
		Vector2(0.12, 0.52), Vector2(0.44, 0.52), Vector2(0.44, 0.66), Vector2(0.12, 0.66),
	]))
	_traces.append(PackedVector2Array([
		Vector2(0.62, 0.48), Vector2(0.88, 0.48), Vector2(0.88, 0.60), Vector2(0.66, 0.60),
	]))
	_traces.append(PackedVector2Array([
		Vector2(0.20, 0.82), Vector2(0.20, 0.90), Vector2(0.52, 0.90),
	]))
	_traces.append(PackedVector2Array([
		Vector2(0.78, 0.74), Vector2(0.78, 0.86), Vector2(0.94, 0.86),
	]))
	_nodes.append(Vector2(0.30, 0.30))
	_nodes.append(Vector2(0.58, 0.30))
	_nodes.append(Vector2(0.72, 0.26))
	_nodes.append(Vector2(0.90, 0.42))
	_nodes.append(Vector2(0.44, 0.52))
	_nodes.append(Vector2(0.44, 0.66))
	_nodes.append(Vector2(0.88, 0.60))
	_nodes.append(Vector2(0.20, 0.90))
	_nodes.append(Vector2(0.78, 0.86))


func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), BG_COLOR, true)
	_draw_grid()
	for index: int in _traces.size():
		var color: Color = TRACE_ALT_COLOR if index % 3 == 2 else TRACE_COLOR
		draw_polyline(_screen_points(_traces[index]), color, 3.0, true)
	for index: int in _nodes.size():
		_draw_node(_nodes[index], index)
	_draw_warning_stripes()


func _draw_grid() -> void:
	var x: float = 0.0
	while x <= size.x:
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), GRID_COLOR, 1.0)
		x += GRID_STEP
	var y: float = 0.0
	while y <= size.y:
		draw_line(Vector2(0.0, y), Vector2(size.x, y), GRID_COLOR, 1.0)
		y += GRID_STEP


func _draw_warning_stripes() -> void:
	var stripe_height: float = 26.0
	var top: float = size.y - stripe_height - 18.0
	draw_rect(Rect2(0.0, top, size.x, stripe_height), STRIPE_BG, true)
	var step: float = 58.0
	var offset: float = fmod(_time * 22.0, step)
	var x: float = -stripe_height - step + offset
	while x < size.x + stripe_height:
		draw_line(Vector2(x, top), Vector2(x + stripe_height, top + stripe_height),
			STRIPE_COLOR, 6.0)
		x += step


func _draw_node(point: Vector2, index: int) -> void:
	var center: Vector2 = Vector2(point.x * size.x, point.y * size.y)
	var pulse: float = 0.5 + 0.5 * sin(_time * 2.2 + float(index) * 1.7)
	draw_circle(center, 5.0 + 2.0 * pulse, NODE_COLOR)
	draw_circle(center, 15.0 + 7.0 * pulse,
		Color(NODE_COLOR.r, NODE_COLOR.g, NODE_COLOR.b, 0.08 + 0.10 * pulse))


func _screen_points(normalized: PackedVector2Array) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in normalized:
		result.append(Vector2(point.x * size.x, point.y * size.y))
	return result
