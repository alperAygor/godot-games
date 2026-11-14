class_name ScreenBackdrop
extends Control
## Gişe dışındaki ekranların (menü, gazete, akşam, son, market, ayarlar) ortak koyu arka planı: loş duvar, üstten sarkan lambanın
## sıcak ışığı ve (ekranlıyken) süzülen toz. Kâğıtlar/kartlar bunun üstünde "masadaki belgeler" gibi durur.


var _glow: Texture2D = Glow.texture(Color(1.0, 0.8, 0.45), 0.17)


func _init() -> void:
	name = "ScreenBackdrop"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dust := Atmosphere.new()
	dust.calm = true
	add_child(dust)
	Feel.start_ambience()


func _draw() -> void:
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]),
		PackedColorArray([Color("222B28"), Color("222B28"), Color("0E1110"), Color("0E1110")]))
	var rng := Seed.rng("backdrop-wall")
	for i in 18:
		draw_circle(Vector2(rng.randf() * size.x, rng.randf() * size.y), rng.randf_range(20.0, 70.0), Color(0, 0, 0, 0.05))
	for i in 7:
		var x := rng.randf() * size.x
		draw_line(Vector2(x, 0), Vector2(x + rng.randf_range(-8, 8), rng.randf_range(60, 220)), Color(0, 0, 0, 0.14), 1.0)
	# Üstten sarkan lamba: ince kablo, abajur ve aşağı doğru sıcak ışık
	var lamp := Vector2(size.x * 0.5, 0.0)
	draw_line(lamp, Vector2(lamp.x, 36.0), Color("0A0B0A"), 3.0)
	draw_colored_polygon(PackedVector2Array([Vector2(lamp.x - 38, 62), Vector2(lamp.x + 38, 62), Vector2(lamp.x + 16, 36), Vector2(lamp.x - 16, 36)]), Color("171A19"))
	draw_circle(Vector2(lamp.x, 64.0), 8.0, Color("FFE9B0"))
	draw_texture_rect(_glow, Rect2(Vector2(lamp.x, 64.0) - Vector2(580, 580), Vector2(1160, 1160)), false)
