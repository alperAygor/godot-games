class_name DeskSurface
extends Control
## Masanın üstü: yıpranmış koyu ahşap, tezgâh lambasının sıcak ışık havuzu, çizikler. Nesneler bunun üstünde serbestçe durur.


var _glow: Texture2D = Glow.texture(Color(1.0, 0.82, 0.5), 0.2)


func _init() -> void:
	name = "DeskSurface"
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("3A2B20"))
	var rng := Seed.rng("desk-wood")
	var y := 0.0
	while y < size.y:
		var tone := rng.randf_range(-0.03, 0.03)
		draw_rect(Rect2(0, y, size.x, 2.0), Color(0.05, 0.03, 0.02, 0.45))
		draw_rect(Rect2(0, y + 2.0, size.x, 46.0), Color(0.23 + tone, 0.17 + tone, 0.12 + tone, 0.35))
		y += 52.0
	for i in 40:
		var from := Vector2(rng.randf() * size.x, rng.randf() * size.y)
		draw_line(from, from + Vector2(rng.randf_range(10, 60), rng.randf_range(-3, 3)), Color(0.02, 0.01, 0.0, 0.25), 1.0)
	# Lamba ışığı: üstte geniş sıcak havuz (tek degrade dokusu)
	var lamp := Vector2(size.x * 0.52, size.y * 0.30)
	draw_texture_rect(_glow, Rect2(lamp - Vector2(420, 420), Vector2(840, 840)), false)
	# Kenarlarda karartı
	draw_rect(Rect2(0, 0, size.x, 6.0), Color(0, 0, 0, 0.5))
