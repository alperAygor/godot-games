class_name LockBadge
extends Control

## Kilit simgesi (v0.2). Lucide setinde "lock" yok (assets/icons başka sahibin
## alanı) → ikonu burada çizeriz: yay + gövde + anahtar deliği. Vektörel çizim
## ölçeklenebilir ve tema paletiyle uyumludur.

const COLOR_BODY: Color = Color(0.6275, 0.5843, 0.5412, 0.75)
const COLOR_SHACKLE: Color = Color(0.6275, 0.5843, 0.5412, 0.55)
const STROKE: float = 4.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(40.0, 40.0)


func _draw() -> void:
	var side: float = minf(size.x, size.y)
	if side <= 8.0:
		return
	var body_width: float = side * 0.52
	var body_height: float = side * 0.38
	var center: Vector2 = size * 0.5
	var body_rect: Rect2 = Rect2(center.x - body_width * 0.5,
		center.y - body_height * 0.15, body_width, body_height)
	var radius: float = side * 0.18
	var shackle_center: Vector2 = Vector2(center.x, body_rect.position.y - 1.0)
	_draw_rounded_rect(body_rect, radius, COLOR_BODY)
	draw_arc(shackle_center, radius, PI, TAU, 20, COLOR_SHACKLE, STROKE, true)
	draw_circle(Vector2(center.x, body_rect.position.y + body_height * 0.42),
		side * 0.045, Color(0.0784, 0.0667, 0.0627, 0.9))


func _draw_rounded_rect(rect: Rect2, radius: float, color: Color) -> void:
	draw_rect(Rect2(rect.position.x + radius, rect.position.y,
		rect.size.x - radius * 2.0, rect.size.y), color, true)
	draw_rect(Rect2(rect.position.x, rect.position.y + radius,
		rect.size.x, rect.size.y - radius * 2.0), color, true)
	draw_circle(Vector2(rect.position.x + radius, rect.position.y + radius), radius, color)
	draw_circle(Vector2(rect.end.x - radius, rect.position.y + radius), radius, color)
	draw_circle(Vector2(rect.position.x + radius, rect.end.y - radius), radius, color)
	draw_circle(Vector2(rect.end.x - radius, rect.end.y - radius), radius, color)
