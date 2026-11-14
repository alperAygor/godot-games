class_name BoothFrame
extends Control
## Gişe penceresinin ön katmanı: çelik çerçeve, cam parlaması ve çizikler. Müşterinin ÜSTÜNDE durur, dokunmayı geçirir.

var window := Rect2()
var flicker := 1.0:
	set(value):
		flicker = value
		queue_redraw()


func _init() -> void:
	name = "BoothFrame"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if window.size.x <= 0.0:
		return
	var steel := Color("1C2120")
	var edge := Color("56625D")
	# Çerçeve (dört bar) ve köşe cıvataları
	var thick := 16.0
	draw_rect(Rect2(window.position.x - thick, window.position.y - thick, window.size.x + thick * 2.0, thick), steel)
	draw_rect(Rect2(window.position.x - thick, window.end.y, window.size.x + thick * 2.0, thick + 6.0), steel)
	draw_rect(Rect2(window.position.x - thick, window.position.y, thick, window.size.y), steel)
	draw_rect(Rect2(window.end.x, window.position.y, thick, window.size.y), steel)
	draw_rect(window.grow(2.0), edge, false, 2.0)
	for corner in [window.position + Vector2(-8, -8), Vector2(window.end.x + 8, window.position.y - 8), Vector2(window.position.x - 8, window.end.y + 10), Vector2(window.end.x + 8, window.end.y + 10)]:
		draw_circle(corner, 4.0, edge)
	# Cam: hafif ton, çapraz parlama şeritleri, çizikler
	draw_rect(window, Color(0.75, 0.9, 0.85, 0.05 * flicker))
	var streak := PackedVector2Array([window.position + Vector2(window.size.x * 0.52, 0), window.position + Vector2(window.size.x * 0.64, 0), window.position + Vector2(window.size.x * 0.40, window.size.y), window.position + Vector2(window.size.x * 0.28, window.size.y)])
	draw_colored_polygon(streak, Color(1, 1, 1, 0.045))
	var streak_two := PackedVector2Array([window.position + Vector2(window.size.x * 0.70, 0), window.position + Vector2(window.size.x * 0.73, 0), window.position + Vector2(window.size.x * 0.49, window.size.y), window.position + Vector2(window.size.x * 0.46, window.size.y)])
	draw_colored_polygon(streak_two, Color(1, 1, 1, 0.05))
	var rng := Seed.rng("glass-scratches")
	for i in 7:
		var from := window.position + Vector2(rng.randf() * window.size.x, rng.randf() * window.size.y)
		draw_line(from, from + Vector2(rng.randf_range(-40, 40), rng.randf_range(10, 36)), Color(1, 1, 1, 0.08), 1.0)
	# Para geçirme yuvası (ön kenarda)
	var slot := Rect2(window.position.x + window.size.x * 0.5 - 150.0, window.end.y - 4.0, 300.0, 12.0)
	draw_rect(slot, Color("0A0C0B"))
	draw_rect(slot, edge, false, 1.5)
