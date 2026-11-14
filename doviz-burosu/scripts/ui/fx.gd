class_name Fx
extends RefCounted
## Piksel parçacık ve ekran efektleri (madeni para saçılması, ekran parlaması, konfeti, daktilo ile yazma, tüp kapsülü).
## Hepsi geçici düğüm üretir ve kendini temizler. Ekransız çalıştırmada (Feel.instant) hiçbir şey çizmez; testleri etkilemez.
## Piksel görünümüyle uyumlu: yuvarlak değil kare parçacıklar, sert kenar.

const PIXEL := 8.0
const INK := Color("14120E")


## Kare piksel: koyu çerçeveli renkli blok.
static func _pixel(color: Color, size := PIXEL) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = INK
	rect.size = Vector2(size, size)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inner := ColorRect.new()
	inner.color = color
	inner.position = Vector2(2, 2)
	inner.size = Vector2(size - 4.0, size - 4.0)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.add_child(inner)
	return rect


## `at` (genel konum) çevresinde madeni paralar yukarı fırlar, düşüp solar.
static func coin_burst(root: Control, at: Vector2, count := 9) -> void:
	if Feel.instant or not root.is_inside_tree():
		return
	var layer := _layer(root)
	for i in count:
		var coin := _pixel(Color("F0C24E"), PIXEL + float(i % 2) * 4.0)
		coin.position = at - layer.global_position
		layer.add_child(coin)
		var drift := Vector2(randf_range(-110.0, 110.0), randf_range(-170.0, -80.0))
		var tween := coin.create_tween()
		tween.tween_property(coin, "position", coin.position + drift, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(coin, "position", coin.position + drift + Vector2(drift.x * 0.4, 150.0), 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(coin, "modulate:a", 0.0, 0.3).set_delay(0.45)
		tween.tween_callback(coin.queue_free)


## Mürekkep sıçraması (damga vurulduğu yerde): küçük karelerin yanlara fırlaması.
static func splat(root: Control, at: Vector2, color: Color, count := 8) -> void:
	if Feel.instant or not root.is_inside_tree():
		return
	var layer := _layer(root)
	for i in count:
		var speck := _pixel(color, 6.0 + float(i % 3) * 2.0)
		speck.position = at - layer.global_position
		layer.add_child(speck)
		var angle := TAU * float(i) / float(count) + randf() * 0.5
		var target := speck.position + Vector2(cos(angle), sin(angle)) * randf_range(40.0, 90.0)
		var tween := speck.create_tween()
		tween.tween_property(speck, "position", target, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(speck, "modulate:a", 0.0, 0.25)
		tween.tween_callback(speck.queue_free)


## Tüm ekranı kısa süre boyar (hata: kırmızı, ödül: amber).
static func flash(root: Control, color: Color, strength := 0.28, seconds := 0.3) -> void:
	if Feel.instant or not root.is_inside_tree():
		return
	var layer := _layer(root)
	var rect := ColorRect.new()
	rect.color = Color(color, strength)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(rect)
	var tween := rect.create_tween()
	tween.tween_property(rect, "modulate:a", 0.0, seconds)
	tween.tween_callback(rect.queue_free)


## Üstten kâğıt/konfeti yağmuru (iyi sonlar, gün sonu başarısı).
static func confetti(root: Control, count := 36) -> void:
	if Feel.instant or not root.is_inside_tree():
		return
	var layer := _layer(root)
	var palette := [Color("F0C24E"), Color("9CCB7E"), Color("D9A845"), Color("E2D9B8"), Color("A83A2C")]
	var width := root.get_viewport_rect().size.x
	for i in count:
		var piece := _pixel(palette[i % palette.size()], 6.0 + float(i % 3) * 2.0)
		piece.position = Vector2(randf() * width, -20.0 - randf() * 200.0)
		layer.add_child(piece)
		var fall := randf_range(1.6, 3.0)
		var tween := piece.create_tween()
		tween.tween_property(piece, "position", piece.position + Vector2(randf_range(-80.0, 80.0), root.get_viewport_rect().size.y + 260.0), fall)
		tween.parallel().tween_property(piece, "modulate:a", 0.0, 0.5).set_delay(fall - 0.5)
		tween.tween_callback(piece.queue_free)


## Pnömatik tüp kapsülü: yukarıdan inip hedefin üstünde sekerek durur, sonra kaybolur.
static func capsule_drop(root: Control, target: Vector2) -> void:
	if Feel.instant or not root.is_inside_tree():
		return
	var layer := _layer(root)
	var capsule := _pixel(Color("B8B2A0"), 22.0)
	capsule.size = Vector2(16.0, 30.0)
	capsule.get_child(0).size = Vector2(12.0, 26.0)
	var local := target - layer.global_position
	capsule.position = Vector2(local.x, -40.0)
	layer.add_child(capsule)
	var tween := capsule.create_tween()
	tween.tween_property(capsule, "position:y", local.y, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(capsule, "position:y", local.y - 16.0, 0.1).set_ease(Tween.EASE_OUT)
	tween.tween_property(capsule, "position:y", local.y, 0.1).set_ease(Tween.EASE_IN)
	tween.tween_interval(0.5)
	tween.tween_property(capsule, "modulate:a", 0.0, 0.25)
	tween.tween_callback(capsule.queue_free)


## Daktilo: etiketin metni harf harf yazılır, her birkaç harfte tuş sesi. Ekransızda metin hemen tamamdır.
static func typewriter(label: Label, characters_per_second := 38.0, with_sound := true) -> void:
	if Feel.instant or not label.is_inside_tree():
		return
	label.visible_characters = 0
	var total := label.text.length()
	var tween := label.create_tween()
	tween.tween_method(func(value: float) -> void:
		var shown := int(value)
		if shown != label.visible_characters:
			if with_sound and shown % 4 == 0:
				Feel.sfx("calc_key", 1.2 + randf() * 0.2)
			label.visible_characters = shown, 0.0, float(total), float(total) / characters_per_second)
	tween.tween_callback(func() -> void: label.visible_characters = -1)


## Kutudaki çocukları sırayla (satır satır) belirtir: günün özeti defter yazar gibi açılır.
static func reveal_children(box: Control, first_delay := 0.15, step := 0.09) -> void:
	if Feel.instant or not box.is_inside_tree():
		return
	var delay := first_delay
	for child in box.get_children():
		if not (child is Label):
			continue
		var label := child as Label
		label.modulate.a = 0.0
		var tween := label.create_tween()
		tween.tween_interval(delay)
		tween.tween_callback(func() -> void:
			label.modulate.a = 1.0
			Feel.sfx("calc_key", 1.0 + randf() * 0.15))
		delay += step


static func _layer(root: Control) -> Control:
	var existing := root.get_node_or_null("FxLayer") as Control
	if existing != null:
		return existing
	var layer := Control.new()
	layer.name = "FxLayer"
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.z_index = 90
	root.add_child(layer)
	return layer
