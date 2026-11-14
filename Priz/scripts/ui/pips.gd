class_name UiPips
extends Control

## İlerleme noktaları (sayı yerine): dolu = bitti, halkalı büyük = şimdiki, sönük = kalan.
## `hard_last` açıksa son nokta yıldız şeklinde çizilir (zor seviye). Kodla çizilir, doku yok.
## Seviye ilerlemesi ve yer tutucu oyunun ilerleme göstergesi bunu kullanır.

const DOT_RADIUS: float = 15.0
const CURRENT_RADIUS: float = 20.0
const GAP: float = 26.0
const STAR_POINTS: int = 5
const STAR_INNER_RATIO: float = 0.45
const SOFT_ALPHA: float = 0.28
const HEIGHT: float = 56.0

var total: int = 0
var done: int = 0
var current: int = -1
var hard_last: bool = false
var color: Color = UiKit.ACCENT
var hard_color: Color = UiKit.STAR


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## `current` -1 ise şimdiki nokta vurgusu yoktur (yalnız dolu/boş).
func set_state(total_count: int, done_count: int, current_index: int = -1, hard: bool = false) -> void:
	total = maxi(total_count, 0)
	done = clampi(done_count, 0, total)
	current = current_index
	hard_last = hard
	custom_minimum_size = Vector2(width_for(total), HEIGHT)
	queue_redraw()


static func width_for(count: int) -> float:
	return float(count) * CURRENT_RADIUS * 2.0 + float(maxi(count - 1, 0)) * GAP


func _draw() -> void:
	var step: float = CURRENT_RADIUS * 2.0 + GAP
	var left: float = (size.x - width_for(total)) * 0.5
	for index: int in range(total):
		var center: Vector2 = Vector2(left + CURRENT_RADIUS + float(index) * step, size.y * 0.5)
		var is_done: bool = index < done
		var is_current: bool = index == current
		var is_hard: bool = hard_last and index == total - 1
		var tint: Color = hard_color if is_hard else color
		var paint: Color = tint if (is_done or is_current) else Color(tint.r, tint.g, tint.b, SOFT_ALPHA)
		if is_hard:
			_draw_star(center, CURRENT_RADIUS if is_current else DOT_RADIUS + 3.0, paint)
		elif is_current:
			draw_circle(center, CURRENT_RADIUS, Color(tint.r, tint.g, tint.b, SOFT_ALPHA))
			draw_circle(center, DOT_RADIUS, paint)
		else:
			draw_circle(center, DOT_RADIUS, paint)


func _draw_star(center: Vector2, radius: float, paint: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in range(STAR_POINTS * 2):
		var angle: float = -PI * 0.5 + float(index) * PI / float(STAR_POINTS)
		var length: float = radius if index % 2 == 0 else radius * STAR_INNER_RATIO
		points.append(center + Vector2(cos(angle), sin(angle)) * length)
	draw_colored_polygon(points, paint)
