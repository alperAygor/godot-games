class_name TutorialHand
extends Node2D

## Yumuşak el imleci + nabız halkası. Parmak ucu düğümün orijinindedir. Hepsi kodla çizilir
## (yassı, çizgisiz, yumuşak köşeli); hareket zamana bağlı bir döngüdür: yaklaş, bas, halka yayıl.
## Hiçbir girdiyi tutmaz (Node2D'dir, Control değil), oyunun dokunuşlarını engelleyemez.

enum Mode { HAND, RING, DEMO }

const CYCLE_SECONDS: float = 1.7
const RING_CYCLE_SECONDS: float = 1.05
const APPROACH_END: float = 0.3
const PRESS_AT: float = 0.34
const RELEASE_AT: float = 0.52
const FADE_IN_END: float = 0.2
const FADE_OUT_START: float = 0.86
const APPROACH_DISTANCE: float = 54.0
const PRESS_DEPTH: float = 12.0
const PRESS_SCALE: float = 0.92
const TILT_DEGREES: float = -14.0
const RING_MIN_RADIUS: float = 34.0
const RING_MAX_RADIUS: float = 112.0
const RING_WIDTH: float = 7.0
const RING_ALPHA: float = 0.85
const RING_FILL_ALPHA: float = 0.16
const RING_ARC_POINTS: int = 56
const FADE_SECONDS: float = 0.22
const HAND_Z: int = 200
const HAND_COLOR: Color = Color("fffdf8")
const SHADOW_COLOR: Color = Color(0.1, 0.15, 0.25, 0.22)
const SHADOW_OFFSET: Vector2 = Vector2(9.0, 13.0)
const RING_COLOR: Color = UiKit.ACCENT
const ANTI_ALIAS: float = 1.5
## Elin parçaları (parmak ucu orijin): işaret parmağı, avuç, iki kıvrık parmak, başparmak.
const FINGER: Rect2 = Rect2(-19.0, 0.0, 38.0, 118.0)
const PALM: Rect2 = Rect2(-52.0, 84.0, 124.0, 116.0)
const KNUCKLES: Array[Rect2] = [Rect2(19.0, 66.0, 32.0, 80.0), Rect2(46.0, 78.0, 30.0, 74.0)]
const THUMB: Rect2 = Rect2(-14.0, -70.0, 28.0, 100.0)
const THUMB_PIVOT: Vector2 = Vector2(-42.0, 134.0)
const THUMB_DEGREES: float = -38.0

var _mode: Mode = Mode.HAND
var _time: float = 0.0
var _ring_pulses: int = 1
var _fade_tween: Tween = null
var _box: StyleBoxFlat = StyleBoxFlat.new()
var _tilt: Transform2D = Transform2D.IDENTITY
var _thumb_local: Transform2D = Transform2D.IDENTITY


func _init() -> void:
	z_index = HAND_Z
	visible = false
	modulate.a = 0.0
	_box.anti_aliasing = true
	_box.anti_aliasing_size = ANTI_ALIAS
	_tilt = Transform2D(deg_to_rad(TILT_DEGREES), Vector2.ZERO)
	_thumb_local = Transform2D(deg_to_rad(THUMB_DEGREES), THUMB_PIVOT)
	set_process(false)


func _process(delta: float) -> void:
	_time += delta
	if _mode == Mode.RING and _time >= RING_CYCLE_SECONDS * float(_ring_pulses):
		dismiss()
		return
	queue_redraw()


## Elin hedefte döngüyle durduğu mod (kılavuz).
func show_hint(point: Vector2) -> void:
	_begin(Mode.HAND, point)


## Yalnız halka nabzı (boşta ipucu): `pulses` kez atar, kendiliğinden kaybolur.
func show_ring(point: Vector2, pulses: int) -> void:
	_ring_pulses = maxi(pulses, 1)
	_begin(Mode.RING, point)


## Kart içi mini gösteri: el yaklaşır, basar, halka yayılır. Basış anında döner; çağıran
## o an etkiyi (sıkma vb.) oynatır. El kendi bitişini kendisi halleder.
func tap_once(point: Vector2) -> void:
	_begin(Mode.DEMO, point)
	await get_tree().create_timer(CYCLE_SECONDS * PRESS_AT).timeout
	if is_inside_tree():
		get_tree().create_timer(CYCLE_SECONDS * (1.0 - PRESS_AT)).timeout.connect(dismiss)


func dismiss() -> void:
	if not visible:
		return
	_kill_fade()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 0.0, FADE_SECONDS)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_fade_tween.tween_callback(_hide_now)


func _begin(mode: Mode, point: Vector2) -> void:
	_mode = mode
	_time = 0.0
	position = point
	_kill_fade()
	visible = true
	set_process(true)
	# Giriş/çıkış solması çizimin içindedir (döngü alfası); düğüm tam görünür açılır.
	modulate.a = 1.0


func _hide_now() -> void:
	visible = false
	set_process(false)


func _kill_fade() -> void:
	if _fade_tween != null:
		_fade_tween.kill()


func _draw() -> void:
	var phase: float = fposmod(_time, CYCLE_SECONDS) / CYCLE_SECONDS
	if _mode == Mode.RING:
		var ring_phase: float = fposmod(_time, RING_CYCLE_SECONDS) / RING_CYCLE_SECONDS
		_draw_ring(Motion.ease_out(ring_phase), 1.0 - Motion.smooth(ring_phase))
		return
	# Halka, basış anından sonra yayılır ve solar.
	if phase >= PRESS_AT:
		var k: float = (phase - PRESS_AT) / (1.0 - PRESS_AT)
		_draw_ring(Motion.ease_out(k), 1.0 - Motion.smooth(k))
	var approach: float = 1.0 - Motion.smooth(phase / APPROACH_END)
	var press: float = 0.0
	if phase >= PRESS_AT and phase < RELEASE_AT:
		press = Motion.smooth((phase - PRESS_AT) / (RELEASE_AT - PRESS_AT) * 2.0) if phase < (PRESS_AT + RELEASE_AT) * 0.5 \
			else 1.0 - Motion.smooth((phase - (PRESS_AT + RELEASE_AT) * 0.5) / (RELEASE_AT - PRESS_AT) * 2.0)
	var alpha: float = Motion.smooth(phase / FADE_IN_END)
	if phase > FADE_OUT_START:
		alpha *= 1.0 - Motion.smooth((phase - FADE_OUT_START) / (1.0 - FADE_OUT_START))
	var offset: Vector2 = Vector2(APPROACH_DISTANCE * 0.5, APPROACH_DISTANCE) * approach \
		+ Vector2(0.0, PRESS_DEPTH) * press
	var scale_now: float = lerpf(1.0, PRESS_SCALE, press)
	var base: Transform2D = Transform2D(_tilt.get_rotation(), Vector2.ONE * scale_now, 0.0, offset)
	_draw_hand(base, SHADOW_OFFSET, Color(SHADOW_COLOR, SHADOW_COLOR.a * alpha))
	_draw_hand(base, Vector2.ZERO, Color(HAND_COLOR, alpha))


func _draw_ring(radius_t: float, strength: float) -> void:
	var radius: float = lerpf(RING_MIN_RADIUS, RING_MAX_RADIUS, radius_t)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	draw_circle(Vector2.ZERO, radius, Color(RING_COLOR, RING_FILL_ALPHA * strength), true, -1.0, true)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, RING_ARC_POINTS, Color(RING_COLOR, RING_ALPHA * strength), RING_WIDTH, true)


func _draw_hand(base: Transform2D, shift: Vector2, tint: Color) -> void:
	var moved: Transform2D = Transform2D(base.get_rotation(), base.get_scale(), 0.0, base.origin + shift)
	_box.bg_color = tint
	draw_set_transform_matrix(moved)
	_part(FINGER)
	_part(PALM)
	for knuckle: Rect2 in KNUCKLES:
		_part(knuckle)
	draw_set_transform_matrix(moved * _thumb_local)
	_part(THUMB)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _part(rect: Rect2) -> void:
	_box.set_corner_radius_all(int(minf(rect.size.x, rect.size.y) * 0.5))
	draw_style_box(_box, rect)
