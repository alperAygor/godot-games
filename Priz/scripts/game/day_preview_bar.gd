class_name DayPreviewBar
extends Control
## Ödüllü "gün önizleme" çubuğu (yazısız): dört dilim diski (doğan güneş, tepe güneş, batan güneş, ay) ve
## kapatma diski. Diske dokununca o dilime geçilir; dioramada yatay sürükleme de gezdirir (SliceGame).
## Çizim tamamen kod; rakam ve metin yok. Dokunma alanları ≥ 48 dp (126 px).

signal slice_chosen(slice: int)
signal closed

const DISC: float = 104.0
const GAP: float = 22.0
## Tasarım ekranında (1080 genişlik, alttan ölçülür) çubuğun merkezi: soluk tepsinin yerinde, sigorta
## kutusunun sağında — önizlemede dilim göstergeleri açıkta kalır.
const CENTER: Vector2 = Vector2(756.0, 1600.0)
const DESIGN: Vector2 = Vector2(1080.0, 1920.0)
const SLICE_COLORS: Array[Color] = [Color(0.55, 0.74, 0.95), Color(1.0, 0.84, 0.28), Color(1.0, 0.52, 0.22),
	Color(0.36, 0.4, 0.86)]

var current: int = 0
var _alpha: float = 0.0
var _open: bool = false
var _press: int = -2
var _pulse: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func open_bar() -> void:
	_open = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func close_bar() -> void:
	_open = false


func is_open() -> bool:
	return _open


func set_current(slice: int) -> void:
	current = slice
	_pulse = 1.0
	queue_redraw()


## Disk merkezleri: 0..3 dilimler, 4 kapat.
func disc_center(i: int) -> Vector2:
	var c: Vector2 = _center()
	var total: float = 5.0 * DISC + 4.0 * GAP
	return Vector2(c.x - total * 0.5 + DISC * 0.5 + float(i) * (DISC + GAP), c.y)


func _center() -> Vector2:
	var view: Vector2 = get_viewport_rect().size
	var k: float = view.x / DESIGN.x
	return Vector2(CENTER.x * k, view.y - (DESIGN.y - CENTER.y) * k)


func disc_at(p: Vector2) -> int:
	for i: int in 5:
		if p.distance_to(disc_center(i)) < (DISC + GAP) * 0.56:
			return i
	return -1


func _input(event: InputEvent) -> void:
	if not _open:
		return
	# Yalnız dokunma olayları (masaüstünde fare dokunmaya çevrilir: project.godot emulate_touch_from_mouse).
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch == null or touch.index != 0:
		return
	var pos: Vector2 = touch.position
	var pressed: bool = touch.pressed
	var i: int = disc_at(pos)
	if pressed:
		_press = i
		if i >= 0:
			_pulse = 1.0
			get_viewport().set_input_as_handled()
			if i < 4:
				slice_chosen.emit(i)
	else:
		if _press == 4 and i == 4:
			get_viewport().set_input_as_handled()
			closed.emit()
		elif _press >= 0:
			get_viewport().set_input_as_handled()
		_press = -2


## Prob/çekim: diske dokunmuş gibi.
func tap_disc(i: int) -> void:
	if i == 4:
		closed.emit()
	elif i >= 0 and i < 4:
		slice_chosen.emit(i)


func _process(delta: float) -> void:
	_alpha = move_toward(_alpha, 1.0 if _open else 0.0, delta * 5.0)
	_pulse = maxf(0.0, _pulse - delta * 3.0)
	visible = _alpha > 0.0
	if visible:
		queue_redraw()


func _draw() -> void:
	var a: float = _alpha
	# Alt şerit: yumuşak koyu zemin
	var c0: Vector2 = disc_center(0)
	var c4: Vector2 = disc_center(4)
	var band: Rect2 = Rect2(Vector2(c0.x - DISC * 0.75, c0.y - DISC * 0.78), Vector2(c4.x - c0.x + DISC * 1.5, DISC * 1.56))
	draw_style_box(_band_style(a), band)
	for i: int in 5:
		var c: Vector2 = disc_center(i)
		var r: float = DISC * 0.5
		var on: bool = i == current
		if i < 4:
			var col: Color = SLICE_COLORS[i]
			if on:
				r *= 1.0 + 0.08 * _pulse + 0.06
				draw_circle(c, r + 10.0, Color(col, 0.35 * a))
			draw_circle(c, r, Color(col.darkened(0.15 if on else 0.55), a))
			draw_arc(c, r, 0.0, TAU, 48, Color(1, 1, 1, (0.9 if on else 0.35) * a), 4.0, true)
			_draw_icon(i, c, r * 0.62, Color(1.0, 0.98, 0.92, (1.0 if on else 0.6) * a))
		else:
			draw_circle(c, r * 0.8, Color(0.92, 0.9, 0.86, 0.95 * a))
			var k: float = r * 0.28
			draw_line(c + Vector2(-k, -k), c + Vector2(k, k), Color(0.2, 0.2, 0.22, a), 7.0, true)
			draw_line(c + Vector2(-k, k), c + Vector2(k, -k), Color(0.2, 0.2, 0.22, a), 7.0, true)


func _band_style(a: float) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.08, 0.6 * a)
	sb.set_corner_radius_all(int(DISC * 0.78))
	sb.anti_aliasing = true
	return sb


## Dilim simgesi (gösterge gölgelendiricisindeki biçimlerin 2B eşi).
func _draw_icon(s: int, c: Vector2, r: float, col: Color) -> void:
	var horizon: float = c.y + r * 0.3
	match s:
		0, 2:
			var rr: float = r * (0.5 if s == 0 else 0.68)
			draw_arc(Vector2(c.x, horizon), rr, PI, TAU, 32, col, rr, true)
			draw_line(Vector2(c.x - r * 0.95, horizon + 3.0), Vector2(c.x + r * 0.95, horizon + 3.0), col, 5.0, true)
			if s == 0:
				for k: int in 5:
					var ang: float = PI + PI * (float(k) + 0.5) / 5.0
					var d: Vector2 = Vector2(cos(ang), sin(ang))
					draw_line(Vector2(c.x, horizon) + d * rr * 1.35, Vector2(c.x, horizon) + d * rr * 1.85, col, 4.0, true)
		1:
			draw_circle(c, r * 0.42, col)
			for k: int in 8:
				var ang2: float = TAU * float(k) / 8.0
				var d2: Vector2 = Vector2(cos(ang2), sin(ang2))
				draw_line(c + d2 * r * 0.62, c + d2 * r * 0.95, col, 4.5, true)
		3:
			draw_circle(c, r * 0.62, col)
			var bg: Color = SLICE_COLORS[3].darkened(0.15 if s == current else 0.55)
			bg.a = col.a
			draw_circle(c + Vector2(r * 0.3, -r * 0.24), r * 0.54, bg)
			draw_circle(c + Vector2(r * 0.6, r * 0.45), r * 0.1, col)
