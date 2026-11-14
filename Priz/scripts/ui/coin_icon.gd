class_name UiCoinIcon
extends Control

## Tek jeton simgesi (kodla çizilir, doku yok): düz altın disk + ince iç halka + küçük parıltı.
## `filled=false` boş (sönük) jeton halkasıdır. Sayısız miktar gösteriminin yapı taşı (bkz. `Quantity`).

const DIAMETER: float = 40.0
const RING_RATIO: float = 0.62
const RING_WIDTH: float = 3.0
const SHINE_RATIO: float = 0.34
const EMPTY_ALPHA: float = 0.4
const ARC_POINTS: int = 32

var color: Color = UiKit.GOLD
var filled: bool = true


func _init() -> void:
	custom_minimum_size = Vector2(DIAMETER, DIAMETER)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


func setup(coin_color: Color, is_filled: bool = true) -> void:
	color = coin_color
	filled = is_filled
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.5
	if filled:
		draw_circle(center, radius, color)
		draw_arc(center, radius * RING_RATIO, 0.0, TAU, ARC_POINTS, color.darkened(0.18), RING_WIDTH, true)
		draw_arc(center, radius * RING_RATIO, PI * 1.1, PI * 1.6, ARC_POINTS, color.lightened(0.45), RING_WIDTH, true)
	else:
		var faded: Color = Color(color.r, color.g, color.b, EMPTY_ALPHA)
		draw_arc(center, radius - RING_WIDTH, 0.0, TAU, ARC_POINTS, faded, RING_WIDTH, true)
