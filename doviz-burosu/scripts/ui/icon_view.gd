class_name IconView
extends Control
## Tek bir minimal ikon (dokunmayı geçirir). Başlık/etiketlerin yanında küçük süs ve anlam ipucu olarak kullanılır.

@export var icon := "":
	set(value):
		icon = value
		queue_redraw()
@export var tint := Color("2B2A33"):
	set(value):
		tint = value
		queue_redraw()
@export var stroke := 2.4:
	set(value):
		stroke = value
		queue_redraw()


func _init(icon_name := "", color := Color("2B2A33"), pixels := 28.0) -> void:
	icon = icon_name
	tint = color
	custom_minimum_size = Vector2(pixels, pixels)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _draw() -> void:
	Icons.draw_on(self, icon, Rect2(Vector2.ZERO, size).grow(-size.x * 0.06), tint, stroke)
