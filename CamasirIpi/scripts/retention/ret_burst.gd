class_name RetBurst
extends Control

## Yumuşak kıvılcım patlaması: tek düğüm, birkaç küçük yuvarlak; yavaşça dağılıp solar,
## sonra kendini siler. Neden tek _draw: ödül anında düğüm seli yaratmamak.

const COUNT: int = 16
const SECONDS: float = 0.9
const SPEED_MIN: float = 90.0
const SPEED_MAX: float = 300.0
const GRAVITY: float = 260.0
const RADIUS_MIN: float = 5.0
const RADIUS_MAX: float = 12.0
const WARM_WHITE: Color = Color(1.0, 0.97, 0.86)

var _dirs: Array[Vector2] = []
var _speeds: Array[float] = []
var _radii: Array[float] = []
var _tint: Color = UiKit.GOLD
var _t: float = 0.0


## `center`: kapsayıcıya göre merkez. Kapsayıcının üstüne eklenir, dokunuşu engellemez.
static func play(host: Control, center: Vector2, tint: Color = UiKit.GOLD) -> void:
	var burst: RetBurst = RetBurst.new()
	burst._tint = tint
	burst.position = center
	burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for index: int in range(COUNT):
		var angle: float = TAU * float(index) / float(COUNT) + randf_range(-0.2, 0.2)
		burst._dirs.append(Vector2.from_angle(angle))
		burst._speeds.append(randf_range(SPEED_MIN, SPEED_MAX))
		burst._radii.append(randf_range(RADIUS_MIN, RADIUS_MAX))
	host.add_child(burst)
	var tween: Tween = burst.create_tween()
	tween.tween_method(burst._advance, 0.0, 1.0, SECONDS)
	tween.tween_callback(burst.queue_free)


func _advance(progress: float) -> void:
	_t = progress
	queue_redraw()


func _draw() -> void:
	var fade: float = 1.0 - _t
	for index: int in range(_dirs.size()):
		var at: Vector2 = _dirs[index] * _speeds[index] * _t * SECONDS * 0.5 + Vector2(0.0, GRAVITY * _t * _t * 0.5)
		var tint: Color = _tint.lerp(WARM_WHITE, 0.5 if index % 2 == 0 else 0.0)
		tint.a = fade
		draw_circle(at, _radii[index] * (0.4 + 0.6 * fade), tint, true, -1.0, true)
