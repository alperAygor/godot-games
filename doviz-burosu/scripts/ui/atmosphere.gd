class_name Atmosphere
extends Control
## Gişenin havası: vinyet (kenar kararması), loş floresan titremesi ve havada süzülen toz. Tüm ekranı kaplar, dokunmayı geçirir.
## Ekransız ve animasyonsuz modda (testler) sakin kalır: yalnızca vinyet çizilir.

## Sakin mod (gişe dışındaki ekranlar): hafif vinyet ve toz; titreme ve alt/üst kararma yok.
var calm := false
var _dust: Array[Dictionary] = []
var _flicker := 0.0
var _next_flicker := 3.0
var _time := 0.0


func _init() -> void:
	name = "Atmosphere"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 30
	var rng := Seed.rng("dust")
	for i in 22:
		_dust.append({"p": Vector2(rng.randf(), rng.randf()), "v": Vector2(rng.randf_range(-0.012, 0.012), rng.randf_range(0.004, 0.02)), "r": rng.randf_range(1.0, 2.6), "a": rng.randf_range(0.06, 0.2)})
	set_process(not Feel.instant)


## Toz ve titreme 30 Hz güncellenir (gözle fark edilmez, her kare komut listesini yeniden kurmaktan ucuz).
const STEP := 1.0 / 30.0
var _accumulated := 0.0


func _process(delta: float) -> void:
	_accumulated += delta
	if _accumulated < STEP:
		return
	delta = _accumulated
	_accumulated = 0.0
	_time += delta
	_next_flicker -= delta
	if _next_flicker <= 0.0:
		_flicker = 1.0
		if randi() % 5 == 0:
			Feel.sfx("flicker")
		_next_flicker = randf_range(2.5, 7.0)
	_flicker = maxf(0.0, _flicker - delta * 6.0)
	for particle in _dust:
		var p: Vector2 = particle["p"] + (particle["v"] as Vector2) * delta
		if p.y > 1.0:
			p.y = 0.0
		if p.x < 0.0 or p.x > 1.0:
			p.x = fposmod(p.x, 1.0)
		particle["p"] = p
	queue_redraw()


func _draw() -> void:
	# Vinyet: dört kenardan içeri doğru kararan şeritler
	var edge := 120.0
	var dark := Color(0, 0, 0, 0.2 if calm else 0.42)
	var clear := Color(0, 0, 0, 0.0)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x, edge), Vector2(0, edge)]), PackedColorArray([dark, dark, clear, clear]))
	draw_polygon(PackedVector2Array([Vector2(0, size.y - edge), Vector2(size.x, size.y - edge), Vector2(size.x, size.y), Vector2(0, size.y)]), PackedColorArray([clear, clear, dark, dark]))
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(edge * 0.6, 0), Vector2(edge * 0.6, size.y), Vector2(0, size.y)]), PackedColorArray([dark, clear, clear, dark]))
	draw_polygon(PackedVector2Array([Vector2(size.x - edge * 0.6, 0), Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(size.x - edge * 0.6, size.y)]), PackedColorArray([clear, dark, dark, clear]))
	if Feel.instant:
		return
	if calm:
		for particle in _dust:
			var q: Vector2 = particle["p"]
			draw_circle(Vector2(q.x * size.x, q.y * size.y), float(particle["r"]), Color(1, 0.95, 0.8, float(particle["a"]) * 0.8))
		return
	# Floresan titremesi: ara sıra kısa bir kararma, sürekli çok hafif dalgalanma
	var wobble := 0.03 + 0.015 * sin(_time * 23.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, wobble + _flicker * 0.16))
	for particle in _dust:
		var p: Vector2 = particle["p"]
		draw_circle(Vector2(p.x * size.x, p.y * size.y), float(particle["r"]), Color(1, 0.95, 0.8, float(particle["a"])))
