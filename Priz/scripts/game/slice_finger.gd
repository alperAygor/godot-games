class_name SliceFinger
extends Control
## Yazısız öğretim: yarı saydam "hayalet parmak" cihazdan prize sürükleme hareketini döngüyle gösterir
## (bas → sürükle → bırak dalgası). Ekran koordinatları SliceGame tarafından her karede verilir
## (kamera paralaksla oynasa da hedefe yapışık kalır). Rakam ve metin yok; yalnız çizim.

const LOOP_SECONDS: float = 2.6
const RADIUS: float = 46.0

var from_point: Vector2 = Vector2.ZERO
var to_point: Vector2 = Vector2.ZERO
var _t: float = 0.0
var _active: bool = false
var _alpha: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func play(from: Vector2, to: Vector2) -> void:
	from_point = from
	to_point = to
	if not _active:
		_t = 0.0
	_active = true


func stop() -> void:
	_active = false


func is_playing() -> bool:
	return _active


func _process(delta: float) -> void:
	_alpha = move_toward(_alpha, 1.0 if _active else 0.0, delta * 4.0)
	if _alpha <= 0.0 and not _active:
		visible = false
		return
	visible = true
	_t = fmod(_t + delta, LOOP_SECONDS)
	queue_redraw()


## Döngü evreleri: 0-0.18 iniş/basış, 0.18-0.72 sürükleme, 0.72-0.86 bırakma dalgası, sonra sönme.
func _draw() -> void:
	var u: float = _t / LOOP_SECONDS
	var pos: Vector2 = from_point
	var press: float = 0.0
	var fade: float = 1.0
	if u < 0.18:
		var k: float = u / 0.18
		press = smoothstep(0.4, 1.0, k)
		fade = smoothstep(0.0, 0.5, k)
		pos = from_point + Vector2(0.0, 40.0 * (1.0 - k))
	elif u < 0.72:
		var k: float = smoothstep(0.0, 1.0, (u - 0.18) / 0.54)
		press = 1.0
		var mid: Vector2 = (from_point + to_point) * 0.5 + Vector2(0.0, -120.0)
		pos = _bezier(from_point, mid, to_point, k)
	elif u < 0.86:
		press = 1.0 - (u - 0.72) / 0.14
		pos = to_point
	else:
		pos = to_point
		fade = 1.0 - (u - 0.86) / 0.14
	var a: float = _alpha * fade
	# İz: kesikli yay
	if u > 0.18:
		var mid2: Vector2 = (from_point + to_point) * 0.5 + Vector2(0.0, -120.0)
		var upto: float = clampf((u - 0.18) / 0.54, 0.0, 1.0)
		var steps: int = 14
		for i: int in range(steps):
			var k2: float = float(i) / float(steps - 1)
			if k2 > upto:
				break
			var p: Vector2 = _bezier(from_point, mid2, to_point, smoothstep(0.0, 1.0, k2))
			draw_circle(p, 6.0, Color(1, 1, 1, 0.35 * a))
	# Bırakma dalgası
	if u >= 0.72:
		var w: float = clampf((u - 0.72) / 0.28, 0.0, 1.0)
		draw_arc(to_point, 30.0 + 70.0 * w, 0.0, TAU, 48, Color(1, 1, 1, (1.0 - w) * 0.8 * _alpha), 6.0, true)
	# Parmak ucu: yumuşak gölge + disk + basınç halkası
	var r: float = RADIUS * (1.0 - 0.18 * press)
	draw_circle(pos + Vector2(6.0, 10.0), r * 1.05, Color(0, 0, 0, 0.18 * a))
	draw_circle(pos, r, Color(1, 1, 1, 0.55 * a))
	draw_arc(pos, r, 0.0, TAU, 48, Color(1, 1, 1, 0.9 * a), 4.0, true)
	if press > 0.0:
		draw_arc(pos, r + 14.0 * press, 0.0, TAU, 48, Color(1, 1, 1, 0.35 * a * press), 3.0, true)


static func _bezier(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	var ab: Vector2 = a.lerp(b, t)
	var bc: Vector2 = b.lerp(c, t)
	return ab.lerp(bc, t)
