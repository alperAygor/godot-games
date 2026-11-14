class_name BanknoteView
extends Control
## Bir banknotu VERİDEN çizer (resim dosyası yok): sahte = farklı parametre. Prototip aşamasında düz renkli kutu + yazı;
## gerçek desen/portre Faz 8'de. Boyut milimetreden piksele `px_per_mm` ile çevrilir, böylece "yanlış boyut" gözle görülür.
## Araçlar çizimi değiştirir:
## - UV lambası: yalnızca (varsa) UV şerit, kendi renginde parlar.
## - Arka ışık (basılı tut): (varsa) filigran şekli görünür.
## - Büyüteç: mikro yazı okunur (kapalıyken sadece noktalı bir çizgi görünür).
## Yırtık banknotun kopuk kısmı eksik çizilir; bantlı banknotun üstünde bant şeridi vardır.

const UV_POSITIONS := {"left": 0.14, "center": 0.46, "right": 0.78}
const HOLE_COLOR := Color(0.88, 0.9, 0.95)

var note: Banknote
var px_per_mm := 1.25
var uv_lamp := false
var backlight := false
var magnifier := false


## Aletlerin gösterdiği şeyler: UV şerit rengi, filigran şekli, mikro yazı metni. Boş metin = görünmüyor.
## Çizim bunu kullanır; testler de "sahtelik bu aletle gözle görülebilir mi" diye bunu sorar.
static func observe(banknote: Banknote, lamp: bool, light: bool, lens: bool) -> Dictionary:
	return {
		"uv_color": banknote.uv_color if (lamp and banknote.uv_present) else "",
		"watermark": banknote.watermark_shape if (light and banknote.watermark_present) else "",
		"microtext": banknote.microtext if lens else "",
	}


func setup(banknote: Banknote, pixels_per_mm: float, lamp := false, light := false, lens := false) -> void:
	note = banknote
	px_per_mm = pixels_per_mm
	uv_lamp = lamp
	backlight = light
	magnifier = lens
	custom_minimum_size = Vector2(banknote.size_mm) * pixels_per_mm
	queue_redraw()


func set_tools(lamp: bool, light: bool, lens: bool) -> void:
	uv_lamp = lamp
	backlight = light
	magnifier = lens
	queue_redraw()


func _draw() -> void:
	if note == null:
		return
	var font := get_theme_default_font()
	var area := Rect2(Vector2.ZERO, size)
	var height := size.y
	var dark := Color(0.1, 0.12, 0.2, 0.9)
	var seen := BanknoteView.observe(note, uv_lamp, backlight, magnifier)
	draw_rect(area, Color(note.color))
	draw_rect(area.grow(-3.0), Color(1, 1, 1, 0.22), false, 2.0)
	draw_rect(area, Color(0, 0, 0, 0.45), false, 2.0)
	draw_rect(area.grow(-height * 0.07), Color(dark, 0.35), false, maxf(1.0, height * 0.015))
	_draw_pattern(area, dark)

	var center := Vector2(height * 0.45, height * 0.52)
	var radius := height * 0.28
	for ring in 3:  # kılcal desen: portrenin çevresinde ince halkalar
		draw_arc(center, radius * (1.18 + ring * 0.16), 0.0, TAU, 40, Color(dark, 0.13), maxf(1.0, height * 0.012))
	draw_circle(center, radius, Color(0, 0, 0, 0.22))
	draw_circle(center, radius * 0.88, Color(1, 1, 1, 0.38))
	draw_string(font, Vector2(center.x - radius, center.y + height * 0.06), note.portrait.get_slice("_", 1),
		HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, maxi(8, int(height * 0.26)), dark)
	draw_string(font, Vector2(size.x * 0.58, height * 0.62), str(note.denom), HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(10, int(height * 0.56)), dark)
	draw_string(font, Vector2(8, height * 0.2), note.currency, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(8, int(height * 0.22)), dark)
	draw_string(font, Vector2(8, height - 6), note.serial, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(8, int(height * 0.19)), Color(dark, 0.8))
	_draw_microtext(font, str(seen["microtext"]), dark)

	if backlight:
		draw_rect(area, Color(1.0, 0.98, 0.8, 0.6))
		if not str(seen["watermark"]).is_empty():
			draw_colored_polygon(WatermarkShapes.points(str(seen["watermark"]), Vector2(size.x * 0.78, height * 0.4), height * 0.22), Color(0.3, 0.35, 0.55, 0.55))
	if uv_lamp:
		draw_rect(area, Color(0.04, 0.0, 0.22, 0.68))
		if not str(seen["uv_color"]).is_empty():
			var x: float = size.x * float(UV_POSITIONS.get(note.uv_position, 0.46))
			var strip := Rect2(x, 3.0, size.x * 0.07, height - 6.0)
			draw_rect(strip.grow(2.0), Color(Color(str(seen["uv_color"])), 0.35))
			draw_rect(strip, Color(str(seen["uv_color"])))
	_draw_damage()


## Her para biriminin kendine özgü zemin deseni (ince, banknotu okunur bırakır).
func _draw_pattern(area: Rect2, dark: Color) -> void:
	var tint := Color(dark, 0.07)
	var step := maxf(6.0, size.y * 0.1)
	match note.currency:
		"FED":  # çapraz çizgiler
			var x := -size.y
			while x < size.x:
				draw_line(Vector2(x, size.y), Vector2(x + size.y, 0), tint, 1.0)
				x += step
		"AVR":  # nokta ızgarası
			var y := step
			while y < size.y:
				var x := step
				while x < size.x:
					draw_circle(Vector2(x, y), 1.2, tint)
					x += step
				y += step
		"STR":  # dalgalar
			var y := step
			while y < size.y:
				var points := PackedVector2Array()
				for i in range(0, 21):
					points.append(Vector2(size.x * i / 20.0, y + sin(i * 0.9) * step * 0.25))
				draw_polyline(points, tint, 1.0)
				y += step
		"DNR":  # baklavalar
			var x := 0.0
			while x < size.x:
				draw_line(Vector2(x, 0), Vector2(x + size.y * 0.5, size.y * 0.5), tint, 1.0)
				draw_line(Vector2(x + size.y * 0.5, size.y * 0.5), Vector2(x, size.y), tint, 1.0)
				x += step * 1.6
		"KRN":  # çapraz kafes
			var x := -size.y
			while x < size.x:
				draw_line(Vector2(x, 0), Vector2(x + size.y, size.y), tint, 1.0)
				draw_line(Vector2(x, size.y), Vector2(x + size.y, 0), tint, 1.0)
				x += step * 1.4
		_:  # PL: yatay ince çizgiler
			var y := step * 0.6
			while y < size.y:
				draw_line(Vector2(0, y), Vector2(size.x, y), tint, 1.0)
				y += step * 0.6


func _draw_microtext(font: Font, text: String, dark: Color) -> void:
	# Seri numarasından sonra başlar; sığmıyorsa yazı küçülür.
	var serial_size := maxi(8, int(size.y * 0.19))
	var start_x := 8.0 + font.get_string_size(note.serial, HORIZONTAL_ALIGNMENT_LEFT, -1, serial_size).x + 10.0
	var available := size.x - start_x - 8.0
	var baseline := size.y - 6.0
	if not text.is_empty():
		var text_size := maxi(8, int(size.y * 0.15))
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
		if width > available and available > 20.0:
			text_size = maxi(6, int(text_size * available / width))
		draw_string(font, Vector2(start_x, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, available, text_size, Color(dark, 0.9))
	else:
		# Büyüteç yokken mikro yazı sadece ince noktalı bir çizgi gibi görünür.
		var x := start_x
		while x < size.x - 8.0:
			draw_rect(Rect2(x, baseline - 3.0, 3.0, 1.5), Color(dark, 0.45))
			x += 5.0


func _draw_damage() -> void:
	if note.remaining_percent < 100:
		var missing := (100 - note.remaining_percent) / 100.0
		var edge_x := size.x * (1.0 - missing)
		var hole := PackedVector2Array([Vector2(edge_x, 0)])
		var steps := 8
		for i in range(1, steps + 1):
			hole.append(Vector2(edge_x + (7.0 if i % 2 == 1 else -7.0), size.y * i / steps))
		hole.append(Vector2(size.x, size.y))
		hole.append(Vector2(size.x, 0))
		draw_colored_polygon(hole, HOLE_COLOR)
		draw_polyline(hole.slice(0, steps + 1), Color(0.3, 0.3, 0.35, 0.8), 2.0)
	if note.taped:
		var x := size.x * 0.5
		var crack := PackedVector2Array()
		for i in 9:
			crack.append(Vector2(x + (4.0 if i % 2 == 0 else -4.0), size.y * i / 8.0))
		draw_polyline(crack, Color(0.2, 0.2, 0.25, 0.7), 1.5)
		draw_rect(Rect2(x - 12.0, 0, 24.0, size.y), Color(0.93, 0.86, 0.55, 0.55))
