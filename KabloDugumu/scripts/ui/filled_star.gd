class_name FilledStar
extends Control

## Dolu/outline altın yıldız (v0.2). Lucide yıldızı yalnızca outline olduğu için
## kutlama ve sonuç ekranında dolu yıldız gerekir. Vektörel: 5 köşeli yıldız,
## lit=false iken yalnızca ince kontur (kilit/boş yıldız).
## ASMR: dolu yıldızın arkasında çok hafif yumuşak parıltı.

const FILL_COLOR: Color = Color(0.9529, 0.7882, 0.4784, 1.0)
const FILL_GLOW: Color = Color(0.9529, 0.7882, 0.4784, 0.16)
const OUTLINE_COLOR: Color = Color(0.5294, 0.4863, 0.4431, 0.85)
const STROKE: float = 2.5
const INNER_RATIO: float = 0.44

var lit: bool = true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(64.0, 64.0)


func set_lit(value: bool) -> void:
	if lit == value:
		return
	lit = value
	queue_redraw()


func _draw() -> void:
	var radius: float = minf(size.x, size.y) * 0.5
	if radius <= 4.0:
		return
	var center: Vector2 = size * 0.5
	var points: PackedVector2Array = _star_points(center, radius)
	if lit:
		draw_circle(center, radius * 1.02, FILL_GLOW)
		draw_circle(center, radius * 0.72, Color(FILL_GLOW.r, FILL_GLOW.g, FILL_GLOW.b, 0.10))
		draw_colored_polygon(points, FILL_COLOR)
		var closed: PackedVector2Array = points.duplicate()
		closed.append(points[0])
		draw_polyline(closed, Color(1.0, 0.95, 0.82, 0.85), 2.0, true)
		return
	var outline: PackedVector2Array = points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, OUTLINE_COLOR, STROKE, true)


func _star_points(center: Vector2, radius: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in 10:
		var angle: float = -PI * 0.5 + float(index) * PI / 5.0
		var length: float = radius if index % 2 == 0 else radius * INNER_RATIO
		points.append(center + Vector2(cos(angle), sin(angle)) * length)
	return points
