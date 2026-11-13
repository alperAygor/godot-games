class_name MapDraw
extends RefCounted

## Haritanın küçük çizim yardımcıları (yıldız çokgeni). Çokgen bir kez kurulur, her çizimde yeniden
## üretilmez (kare başına bellek ayırma yok); ölçek/konum `draw_set_transform` ile verilir.

const STAR_POINTS: int = 5
const STAR_INNER_RATIO: float = 0.5
const STAR_COLOR: Color = Color("f2b63d")
const STAR_OFF: Color = Color("e3dfd2")

static var _unit_star: PackedVector2Array = PackedVector2Array()


static func unit_star() -> PackedVector2Array:
	if _unit_star.is_empty():
		for index: int in range(STAR_POINTS * 2):
			var radius: float = 1.0 if index % 2 == 0 else STAR_INNER_RATIO
			var angle: float = -PI * 0.5 + PI * float(index) / float(STAR_POINTS)
			_unit_star.append(Vector2(cos(angle), sin(angle)) * radius)
	return _unit_star


## `canvas` üzerinde `center` merkezli, `radius` yarıçaplı tek yıldız.
static func star(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	canvas.draw_set_transform(center, 0.0, Vector2(radius, radius))
	canvas.draw_colored_polygon(unit_star(), color)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
