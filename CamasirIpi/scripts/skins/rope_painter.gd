class_name RopePainter
extends RefCounted

## İpi bir `CanvasItem` üzerine ÇİZER (düğüm yok, doku yok). Oyun ekranı ve ana ekran aynı
## çizimi kullanır; kaplama değişince çağıran `queue_redraw()` yapar (performans geçişinde ipler
## yalnız değişimde yeniden çizilir; bu sınıf kare başına çalışmaz).
## Stil sözlüğü: {"pattern": solid|alternate|dots, "width", "colors": [hex], "run", "steps",
## "highlight", "dot_every", "dot_radius", "dot_colors", "dot_glow"}.

const DEFAULT_STYLE: Dictionary = {"pattern": "solid", "width": 5.0, "colors": ["#8a6a4a"]}
const DEFAULT_COLOR: Color = Color("8a6a4a")
const DEFAULT_WIDTH: float = 5.0
const DEFAULT_STEPS: int = 24
const HIGHLIGHT_WIDTH_RATIO: float = 0.3
const HIGHLIGHT_LIFT: float = 1.4
const GLOW_ALPHA: float = 0.24
const GLOW_RADIUS_RATIO: float = 2.1
const DOT_SHINE: Color = Color(1.0, 1.0, 1.0, 0.55)
const DOT_SHINE_RATIO: float = 0.38
const PATTERN_SOLID: String = "solid"
const PATTERN_ALTERNATE: String = "alternate"
const PATTERN_DOTS: String = "dots"


## Hafifçe sarkan ip noktaları: x0..x1 arası, taban `y`, orta noktada `sag` kadar aşağı.
static func build_points(x0: float, x1: float, y: float, sag: float, steps: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for step: int in range(steps + 1):
		var t: float = float(step) / float(steps)
		points.append(Vector2(lerpf(x0, x1, t), y + sag * sin(PI * t)))
	return points


## `size_scale`: küçük önizlemelerde kalınlık ve nokta yarıçapını orantılı küçültür (oyunda 1).
static func draw_rope(canvas: CanvasItem, x0: float, x1: float, y: float, sag: float, style: Dictionary,
		size_scale: float = 1.0) -> void:
	var pattern: String = String(style.get("pattern", PATTERN_SOLID))
	var width: float = float(style.get("width", DEFAULT_WIDTH)) * size_scale
	var colors: Array[Color] = parse_colors(style.get("colors", []), DEFAULT_COLOR)
	var steps: int = maxi(int(style.get("steps", DEFAULT_STEPS)), 4)
	var points: PackedVector2Array = build_points(x0, x1, y, sag, steps)
	if pattern == PATTERN_ALTERNATE and colors.size() > 1:
		_draw_alternate(canvas, points, colors, width, maxi(int(style.get("run", 1)), 1))
	else:
		canvas.draw_polyline(points, colors[0], width, true)
	var highlight: String = String(style.get("highlight", ""))
	if not highlight.is_empty():
		var shine: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in points:
			shine.append(point + Vector2(0.0, -HIGHLIGHT_LIFT))
		canvas.draw_polyline(shine, Color(highlight), maxf(width * HIGHLIGHT_WIDTH_RATIO, 1.0), true)
	if pattern == PATTERN_DOTS:
		_draw_dots(canvas, points, style, size_scale)


## Renkler `run` parçalık gruplar hâlinde döner; ardışık gruplar uç noktayı paylaşır (boşluk kalmaz).
static func _draw_alternate(canvas: CanvasItem, points: PackedVector2Array, colors: Array[Color],
		width: float, run: int) -> void:
	var segments: int = points.size() - 1
	var group: int = 0
	var start: int = 0
	while start < segments:
		var stop: int = mini(start + run, segments)
		canvas.draw_polyline(points.slice(start, stop + 1), colors[group % colors.size()], width, true)
		start = stop
		group += 1


## Işık/çiçek noktaları: her `dot_every` noktada bir daire (+ yumuşak hale). Uçlara konmaz.
static func _draw_dots(canvas: CanvasItem, points: PackedVector2Array, style: Dictionary,
		size_scale: float) -> void:
	var every: int = maxi(int(style.get("dot_every", 3)), 1)
	var radius: float = float(style.get("dot_radius", 8.0)) * size_scale
	var dot_colors: Array[Color] = parse_colors(style.get("dot_colors", []), Color.WHITE)
	var glow: bool = bool(style.get("dot_glow", true))
	var index: int = 0
	for at: int in range(every, points.size() - 1, every):
		var color: Color = dot_colors[index % dot_colors.size()]
		var center: Vector2 = points[at] + Vector2(0.0, radius * 0.55)
		if glow:
			canvas.draw_circle(center, radius * GLOW_RADIUS_RATIO, Color(color, GLOW_ALPHA), true, -1.0, true)
		canvas.draw_circle(center, radius, color, true, -1.0, true)
		if glow:
			canvas.draw_circle(center + Vector2(-radius * 0.22, -radius * 0.25), radius * DOT_SHINE_RATIO,
				DOT_SHINE, true, -1.0, true)
		index += 1


## Hex metin listesi -> Color; boş/bozuksa `fallback` tek elemanlı döner (çizim asla patlamasın).
static func parse_colors(raw: Variant, fallback: Color) -> Array[Color]:
	var result: Array[Color] = []
	if raw is Array:
		for entry: Variant in raw as Array:
			result.append(Color(String(entry)))
	if result.is_empty():
		result.append(fallback)
	return result
