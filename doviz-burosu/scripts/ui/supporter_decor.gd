class_name SupporterDecor
extends Control
## "Destekçi" masa süsü (Reklamları Kaldır sahiplerine): küçük bir saksı ve isim plakası. Veriden çizilir.


func _init() -> void:
	name = "SupporterDecor"
	custom_minimum_size = Vector2(96, 120)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var font := get_theme_default_font()
	var base := Vector2(size.x / 2.0, size.y - 34.0)
	for leaf in [[-0.7, 34.0], [0.0, 44.0], [0.7, 34.0]]:
		var tip: Vector2 = base + Vector2(sin(float(leaf[0])) * float(leaf[1]), -cos(float(leaf[0])) * float(leaf[1]))
		draw_line(base + Vector2(0, -6), tip, Color("3F7D4E"), 5.0)
		draw_circle(tip, 9.0, Color("5A9A66"))
	draw_colored_polygon(PackedVector2Array([base + Vector2(-20, -4), base + Vector2(20, -4), base + Vector2(15, 22), base + Vector2(-15, 22)]), Color("A0643A"))
	draw_rect(Rect2(base.x - 22.0, base.y - 8.0, 44.0, 8.0), Color("8A5530"))
	draw_rect(Rect2(2.0, size.y - 12.0, size.x - 4.0, 14.0), Color("D9C28F"))
	draw_string(font, Vector2(0, size.y - 1.0), tr("SUPPORTER"), HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, Color("2B2A33"))
