class_name DemoYard
extends Control

## Üstten bakan, vektörle çizilen küçük manevra sahası (yer tutucu görünüm): bir makas, iki yan hat, bir lokomotif ve
## simgeli renkli vagonlar. Ana ekran arka planı (`StubSession.start_demo`) ve kabuğun sahte sahası bunu çizer;
## gerçek 3B görünüm (YardSession) gelince bu sınıf yalnız probe/geliştirme içindir.
##
## Zamanlama TEK bir saatten türer (`time`): durum her karede `time`dan hesaplanır, birikim yok. Bu yüzden
## döngü (demo) ve sürükleme (oyun kipi: hamle sayısı -> zaman) aynı kodla çalışır.
## Maliyet: statik katman (zemin, ray, ağaç) yalnız boyut değişince çizilir; dinamik katman karede ~60 çizim çağrısı,
## karede yeni nesne üretmez (stil kutuları, çokgenler, çizgi dizileri önceden hazır).

## Yayla birimi (sahne birimi): saha 920 yüksek, ~460 geniş; ekrana sığdırılırken ölçeklenir.
const LEAD_LENGTH: float = 400.0
const CURVE_DX: float = 190.0
const CURVE_DY: float = 190.0
const CURVE_PULL: float = 120.0
const SIDING_LENGTH: float = 330.0
const CURVE_STEPS: int = 40
const SLEEPER_STEP: float = 24.0
const SLEEPER_HALF: float = 25.0
const RAIL_HALF: float = 14.0
const RAIL_WIDTH: float = 4.5
const BALLAST_WIDTH: float = 54.0
const SLEEPER_WIDTH: float = 6.0
const APRON_MARGIN: float = 120.0
const APRON_RADIUS: int = 110

# --- Araçlar ---
const WAGON_LENGTH: float = 84.0
const WAGON_WIDTH: float = 52.0
const LOCO_LENGTH: float = 98.0
const LOCO_WIDTH: float = 56.0
const COUPLE_GAP: float = 10.0
const SPLIT_GAP: float = 22.0
const END_MARGIN: float = 60.0
const SYMBOL_PIXELS: float = 28.0
const AXLE_SPAN: float = 0.35

# --- Zaman çizelgesi (saniye) ---
const T_START: float = 0.8
const T_PUSH_A_END: float = 4.9
const T_UNCOUPLE_A_END: float = 5.6
const T_BACK_END: float = 8.3
const T_SWITCH_END: float = 9.0
const T_PUSH_B_END: float = 11.5
const T_UNCOUPLE_B_END: float = 12.2
const T_LEAVE_END: float = 14.5
const T_FADE_OUT: float = 16.4
const T_RESET: float = 17.2
const T_LOOP: float = 18.0
const T_SOLVED: float = 14.5
const START_HEAD: float = 250.0
const FADE_SECONDS: float = 0.8
const DELTA_CAP: float = 0.1

# --- Çizim ---
const SHADOW_OFFSET: Vector2 = Vector2(4.0, 7.0)
const SHADOW_COLOR: Color = Color(0.16, 0.2, 0.14, 0.16)
const TARGET_BORDER: int = 5
const TARGET_ALPHA: float = 0.62
const SMOKE_PUFFS: int = 3
const SMOKE_SPEED: float = 0.55
const SMOKE_RISE: Vector2 = Vector2(38.0, -46.0)
const SPARK_SECONDS: float = 0.7
const PULSE_SECONDS: float = 1.3
const TREE_SPOTS: Array[Vector3] = [
	Vector3(-330.0, 380.0, 44.0), Vector3(-282.0, 468.0, 30.0), Vector3(318.0, 520.0, 40.0),
	Vector3(-336.0, -430.0, 38.0), Vector3(350.0, 150.0, 34.0), Vector3(372.0, 244.0, 26.0),
]
const DEPOT_RECT: Rect2 = Rect2(Vector2(96.0, 250.0), Vector2(120.0, 84.0))

## Oyun kipinde (saha ekranda) hamle sayısı zamana çevrilirken kullanılan aralık.
static func play_time(fraction: float) -> float:
	return lerpf(T_START, T_SOLVED, clampf(fraction, 0.0, 1.0))

## Saha, kontrolün hangi bölümüne sığdırılacak (oran: x, y, genişlik, yükseklik).
var stage: Rect2 = Rect2(0.04, 0.04, 0.92, 0.92):
	set(value):
		stage = value
		if is_inside_tree():
			_on_resized()
## Zaman (saniye). Demoda döngü, oyun kipinde dışarıdan sürülür.
var time: float = T_START:
	set(value):
		time = value
		queue_redraw()
## Çözüm halkası (ipucu): 0..1 aralığında yayılan halka, -1 = yok.
var hint_phase: float = -1.0:
	set(value):
		hint_phase = value
		queue_redraw()
## Oyun kipinde dokunuş geri bildirimi: 1 -> 0.
var press: float = 0.0:
	set(value):
		press = value
		queue_redraw()

var _looping: bool = false
var _wanted: bool = false
var _ground: Control = null
var _routes: Array[PackedVector2Array] = []
var _lengths: Array[PackedFloat32Array] = []
var _rail_lines: Array[PackedVector2Array] = []
var _ballast_lines: Array[PackedVector2Array] = []
var _sleepers: PackedVector2Array = PackedVector2Array()
var _origin: Vector2 = Vector2.ZERO
var _scale: float = 1.0
var _sample_pos: Vector2 = Vector2.ZERO
var _sample_dir: Vector2 = Vector2.UP
var _wagon_boxes: Array[StyleBoxFlat] = []
var _lid_boxes: Array[StyleBoxFlat] = []
var _shadow_box: StyleBoxFlat = null
var _loco_box: StyleBoxFlat = null
var _cab_box: StyleBoxFlat = null
var _stripe_box: StyleBoxFlat = null
var _target_box: StyleBoxFlat = null
var _coupler_box: StyleBoxFlat = null
var _wagon_colors: Array[Color] = [UiTokens.C_WAGON_RED, UiTokens.C_WAGON_BLUE, UiTokens.C_WAGON_YELLOW]
var _wagon_symbols: Array[String] = ["ux/sym-circle", "ux/sym-triangle", "ux/sym-diamond"]
var _wagon_ribs: PackedVector2Array = PackedVector2Array()
var _end_a: float = 0.0
var _end_b: float = 0.0
var _total_height: float = 0.0
var _glow: GradientTexture2D = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	set_process(false)
	_build_routes()
	_build_boxes()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ground = Backdrop.new()
	_ground.name = "Ground"
	# Çocuk normalde ebeveynin ÜSTÜNE çizilir; zemin araçların arkasında kalmalı.
	_ground.show_behind_parent = true
	_ground.set("yard", self)
	add_child(_ground)
	_ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_on_resized)
	visibility_changed.connect(_refresh_running)
	_on_resized()


## Döngüyü başlatır (demo). Görünmezken ve uygulama arka plandayken işlemez.
func start_loop() -> void:
	_wanted = true
	_looping = true
	_refresh_running()


func stop_loop() -> void:
	_wanted = false
	_looping = false
	_refresh_running()


func is_looping() -> bool:
	return _looping and is_processing()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			set_process(false)
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_WM_WINDOW_FOCUS_IN:
			_refresh_running()


func _refresh_running() -> void:
	set_process(_wanted and _looping and is_visible_in_tree())


func _process(delta: float) -> void:
	time = fposmod(time + minf(delta, DELTA_CAP), T_LOOP)


func _on_resized() -> void:
	var box: Rect2 = Rect2(size * stage.position, size * stage.size)
	var yard_width: float = CURVE_DX * 2.0 + WAGON_WIDTH + APRON_MARGIN
	var yard_height: float = _total_height + APRON_MARGIN
	_scale = maxf(minf(box.size.x / yard_width, box.size.y / yard_height), 0.01)
	# Saha orijini (makas) sahnenin yatay ortasında; dikeyde yükseklik kutunun ortasına oturur.
	var top_extent: float = CURVE_DY + SIDING_LENGTH + END_MARGIN * 0.5
	var bottom_extent: float = LEAD_LENGTH
	var middle: float = (bottom_extent - top_extent) * 0.5
	_origin = Vector2(box.position.x + box.size.x * 0.5, box.position.y + box.size.y * 0.5 + middle * _scale)
	if _ground != null:
		_ground.queue_redraw()
	queue_redraw()


# --- Geometri -----------------------------------------------------------------------------------

func _build_routes() -> void:
	_routes.clear()
	_lengths.clear()
	for side: int in 2:
		var sign_x: float = -1.0 if side == 0 else 1.0
		var points: PackedVector2Array = PackedVector2Array()
		points.append(Vector2(0.0, LEAD_LENGTH))
		points.append(Vector2.ZERO)
		var start: Vector2 = Vector2.ZERO
		var control_a: Vector2 = Vector2(0.0, -CURVE_PULL)
		var control_b: Vector2 = Vector2(sign_x * CURVE_DX, -CURVE_DY + CURVE_PULL)
		var finish: Vector2 = Vector2(sign_x * CURVE_DX, -CURVE_DY)
		for step: int in range(1, CURVE_STEPS + 1):
			var t: float = float(step) / float(CURVE_STEPS)
			points.append(start.bezier_interpolate(control_a, control_b, finish, t))
		points.append(finish + Vector2(0.0, -SIDING_LENGTH))
		var lengths: PackedFloat32Array = PackedFloat32Array()
		var run: float = 0.0
		lengths.append(0.0)
		for index: int in range(1, points.size()):
			run += points[index].distance_to(points[index - 1])
			lengths.append(run)
		_routes.append(points)
		_lengths.append(lengths)
	_end_a = _lengths[0][_lengths[0].size() - 1]
	_end_b = _lengths[1][_lengths[1].size() - 1]
	_total_height = LEAD_LENGTH + CURVE_DY + SIDING_LENGTH
	# Ray ve balast çizgileri: lead bir kez, iki yan hat makastan sonra.
	_rail_lines.clear()
	_ballast_lines.clear()
	_sleepers = PackedVector2Array()
	_add_track_lines(0, 0.0, LEAD_LENGTH, true)
	_add_track_lines(0, LEAD_LENGTH, _end_a, false)
	_add_track_lines(1, LEAD_LENGTH, _end_b, false)
	_wagon_ribs = PackedVector2Array()
	for index: int in 4:
		var x: float = lerpf(-WAGON_LENGTH * 0.28, WAGON_LENGTH * 0.28, float(index) / 3.0)
		_wagon_ribs.append(Vector2(x, -WAGON_WIDTH * 0.5 + 9.0))
		_wagon_ribs.append(Vector2(x, WAGON_WIDTH * 0.5 - 9.0))


func _add_track_lines(route: int, from_p: float, to_p: float, include_start: bool) -> void:
	var center: PackedVector2Array = PackedVector2Array()
	var left: PackedVector2Array = PackedVector2Array()
	var right: PackedVector2Array = PackedVector2Array()
	var step: float = 6.0
	var p: float = from_p
	while p <= to_p + 0.01:
		_sample(route, p)
		var normal: Vector2 = Vector2(-_sample_dir.y, _sample_dir.x)
		center.append(_sample_pos)
		left.append(_sample_pos + normal * RAIL_HALF)
		right.append(_sample_pos - normal * RAIL_HALF)
		p += step
	_ballast_lines.append(center)
	_rail_lines.append(left)
	_rail_lines.append(right)
	var q: float = from_p if include_start else from_p + SLEEPER_STEP
	while q <= to_p:
		_sample(route, q)
		var side: Vector2 = Vector2(-_sample_dir.y, _sample_dir.x) * SLEEPER_HALF
		_sleepers.append(_sample_pos + side)
		_sleepers.append(_sample_pos - side)
		q += SLEEPER_STEP


## `p` yol uzunluğundaki konum ve yön (üye değişkenlere; karede yeni nesne üretmez).
func _sample(route: int, p: float) -> void:
	var points: PackedVector2Array = _routes[route]
	var lengths: PackedFloat32Array = _lengths[route]
	var clamped: float = clampf(p, 0.0, lengths[lengths.size() - 1])
	var low: int = 0
	var high: int = lengths.size() - 1
	while high - low > 1:
		var middle: int = (low + high) >> 1
		if lengths[middle] <= clamped:
			low = middle
		else:
			high = middle
	var span: float = lengths[high] - lengths[low]
	var amount: float = (clamped - lengths[low]) / span if span > 0.0 else 0.0
	_sample_pos = points[low].lerp(points[high], amount)
	_sample_dir = (points[high] - points[low]).normalized()


## Aracın merkezi ve yönü: iki aks noktasının ortası (virajda gövde doğal döner).
func _pose(route: int, p: float, length: float) -> Transform2D:
	_sample(route, p + length * AXLE_SPAN)
	var front: Vector2 = _sample_pos
	_sample(route, p - length * AXLE_SPAN)
	var back: Vector2 = _sample_pos
	var heading: Vector2 = front - back
	return Transform2D((heading.angle()), (front + back) * 0.5)


# --- Stil kutuları -------------------------------------------------------------------------------

func _build_boxes() -> void:
	_wagon_boxes.clear()
	_lid_boxes.clear()
	for color: Color in _wagon_colors:
		_wagon_boxes.append(_box(color, 9))
		_lid_boxes.append(_box(color.lightened(0.16), 6))
	_shadow_box = _box(SHADOW_COLOR, 10)
	_loco_box = _box(UiTokens.C_LOCO_BODY, 14)
	_cab_box = _box(UiTokens.C_LOCO_CAB, 8)
	_stripe_box = _box(UiTokens.C_WARNING, 3)
	_coupler_box = _box(UiTokens.C_INK.lerp(UiTokens.C_RAIL, 0.4), 3)
	_target_box = _box(Color.WHITE, 12)
	_target_box.draw_center = false
	_target_box.set_border_width_all(TARGET_BORDER)


static func _box(color: Color, radius: int) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.anti_aliasing = true
	return box


# --- Durum (zamandan) ----------------------------------------------------------------------------

## Karede kullanılan geçici durum: araç merkezleri (yol uzunluğu) ve yol seçimi.
var _loco_p: float = 0.0
var _blue_p: float = 0.0
var _red_p: float = 0.0
var _yellow_p: float = 0.0
var _blue_route: int = 0
var _tongue: float = 0.0
var _fade: float = 1.0
var _link_red: bool = true
var _link_loco: bool = true
var _state_time: float = 0.0


func _compute_state() -> void:
	var t: float = time
	_fade = 1.0
	if t >= T_FADE_OUT and t < T_RESET:
		_fade = 1.0 - Motion.smooth((t - T_FADE_OUT) / FADE_SECONDS)
	elif t >= T_RESET:
		_fade = Motion.smooth((t - T_RESET) / FADE_SECONDS)
		t = 0.0
	_state_time = t
	var pitch_loco: float = LOCO_LENGTH * 0.5 + COUPLE_GAP + WAGON_LENGTH * 0.5
	var pitch_wagon: float = WAGON_LENGTH + COUPLE_GAP
	var red_end: float = _end_a - END_MARGIN
	var yellow_end: float = _end_b - END_MARGIN
	var blue_end: float = yellow_end - pitch_wagon - 6.0
	var blue_clear: float = LEAD_LENGTH - 90.0
	_yellow_p = yellow_end
	_blue_route = 0 if t < T_SWITCH_END else 1
	_tongue = 0.0
	# Başlangıç: katar makas önünde, lokomotif arkada (aşağıda).
	var head: float = START_HEAD
	var blue_free: float = START_HEAD - pitch_wagon
	_link_red = true
	_link_loco = true
	var loco: float = blue_free - pitch_loco
	if t < T_START:
		pass
	elif t < T_PUSH_A_END:
		var f: float = Motion.ease_in_out((t - T_START) / (T_PUSH_A_END - T_START))
		head = lerpf(START_HEAD, red_end, f)
		blue_free = head - pitch_wagon
		loco = blue_free - pitch_loco
	elif t < T_UNCOUPLE_A_END:
		head = red_end
		blue_free = head - pitch_wagon
		loco = blue_free - pitch_loco
		_link_red = false
		var open: float = Motion.smooth((t - T_PUSH_A_END) / (T_UNCOUPLE_A_END - T_PUSH_A_END))
		blue_free -= (SPLIT_GAP - COUPLE_GAP) * open
		loco = blue_free - pitch_loco
	elif t < T_BACK_END:
		_link_red = false
		head = red_end
		var f2: float = Motion.ease_in_out((t - T_UNCOUPLE_A_END) / (T_BACK_END - T_UNCOUPLE_A_END))
		blue_free = lerpf(red_end - pitch_wagon - (SPLIT_GAP - COUPLE_GAP), blue_clear, f2)
		loco = blue_free - pitch_loco
	elif t < T_SWITCH_END:
		_link_red = false
		head = red_end
		blue_free = blue_clear
		loco = blue_free - pitch_loco
		_tongue = Motion.ease_in_out((t - T_BACK_END) / (T_SWITCH_END - T_BACK_END))
	elif t < T_PUSH_B_END:
		_link_red = false
		head = red_end
		_tongue = 1.0
		var f3: float = Motion.ease_in_out((t - T_SWITCH_END) / (T_PUSH_B_END - T_SWITCH_END))
		blue_free = lerpf(blue_clear, blue_end, f3)
		loco = blue_free - pitch_loco
	elif t < T_UNCOUPLE_B_END:
		_link_red = false
		_link_loco = t < (T_PUSH_B_END + 0.05)
		head = red_end
		_tongue = 1.0
		blue_free = blue_end
		var open2: float = Motion.smooth((t - T_PUSH_B_END) / (T_UNCOUPLE_B_END - T_PUSH_B_END))
		loco = blue_free - pitch_loco - (SPLIT_GAP - COUPLE_GAP) * open2
	else:
		_link_red = false
		_link_loco = false
		head = red_end
		_tongue = 1.0
		blue_free = blue_end
		var f4: float = Motion.ease_in_out((t - T_UNCOUPLE_B_END) / (T_LEAVE_END - T_UNCOUPLE_B_END))
		var loco_from: float = blue_end - pitch_loco - (SPLIT_GAP - COUPLE_GAP)
		loco = lerpf(loco_from, START_HEAD - pitch_wagon - pitch_loco, f4)
	_red_p = head
	_blue_p = blue_free
	_loco_p = loco


# --- Çizim ---------------------------------------------------------------------------------------

func _draw() -> void:
	if size.x <= 0.0:
		return
	_compute_state()
	var t: float = time
	_draw_targets(t)
	_draw_tongue()
	var alpha: float = _fade
	_draw_couplings(alpha)
	_draw_wagon(0, 0, _red_p, alpha)
	_draw_wagon(1, _blue_route, _blue_p, alpha)
	_draw_wagon(2, 1, _yellow_p, alpha)
	_draw_loco(0 if _blue_route == 0 else 1, _loco_p)
	_draw_smoke(t)
	_draw_effects(t)
	_draw_hint()


func _to_screen(local: Vector2) -> Vector2:
	return _origin + local * _scale


func _transform(local_pos: Vector2, angle: float) -> void:
	draw_set_transform(_to_screen(local_pos), angle, Vector2(_scale, _scale))


func _reset_transform() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_targets(t: float) -> void:
	# A sonu: kırmızı; B sonu: sarı (hazır) ve mavi (ikinci yer).
	var done_a: bool = t >= T_PUSH_A_END
	var done_b: bool = t >= T_PUSH_B_END
	_draw_target(0, _end_a - END_MARGIN, 0, done_a)
	_draw_target(1, _end_b - END_MARGIN, 2, true)
	var second: float = _end_b - END_MARGIN - (WAGON_LENGTH + COUPLE_GAP) - 6.0
	_draw_target(1, second, 1, done_b)


func _draw_target(route: int, p: float, wagon: int, done: bool) -> void:
	var pose: Transform2D = _pose(route, p, WAGON_LENGTH)
	_transform(pose.origin, pose.get_rotation())
	var color: Color = _wagon_colors[wagon]
	var rect: Rect2 = Rect2(Vector2(-WAGON_LENGTH * 0.5 - 7.0, -WAGON_WIDTH * 0.5 - 7.0),
		Vector2(WAGON_LENGTH + 14.0, WAGON_WIDTH + 14.0))
	_target_box.border_color = Color(color, TARGET_ALPHA if not done else TARGET_ALPHA * 1.3)
	draw_style_box(_target_box, rect)
	var texture: Texture2D = Icons.texture(_wagon_symbols[wagon])
	if texture != null and not done:
		var half: float = SYMBOL_PIXELS * 0.5
		draw_texture_rect(texture, Rect2(Vector2(-half, -half), Vector2(SYMBOL_PIXELS, SYMBOL_PIXELS)), false,
			Color(color, TARGET_ALPHA))
	_reset_transform()


func _draw_tongue() -> void:
	# Makas dili: açık yola doğru kısa, belirgin bir çizgi (A: sol, B: sağ).
	var toward_a: Vector2 = _to_screen(Vector2(-RAIL_HALF * 0.0, 0.0))
	var length: float = 74.0
	var route: int = 0 if _tongue < 0.5 else 1
	_sample(route, LEAD_LENGTH + length)
	var tip: Vector2 = _to_screen(_sample_pos)
	draw_line(toward_a, tip, Color(UiTokens.C_PRIMARY, 0.85), 7.0 * _scale, true)
	draw_circle(toward_a, 10.0 * _scale, UiTokens.C_PRIMARY, true, -1.0, true)


func _draw_wagon(index: int, route: int, p: float, alpha: float) -> void:
	if alpha <= 0.01:
		return
	var pose: Transform2D = _pose(route, p, WAGON_LENGTH)
	var angle: float = pose.get_rotation()
	_transform(pose.origin, angle)
	var half_l: float = WAGON_LENGTH * 0.5
	var half_w: float = WAGON_WIDTH * 0.5
	var body: Rect2 = Rect2(Vector2(-half_l, -half_w), Vector2(WAGON_LENGTH, WAGON_WIDTH))
	_shadow_box.bg_color = Color(SHADOW_COLOR, SHADOW_COLOR.a * alpha)
	draw_style_box(_shadow_box, Rect2(body.position + SHADOW_OFFSET, body.size))
	var color: Color = _wagon_colors[index]
	_wagon_boxes[index].bg_color = Color(color, alpha)
	draw_style_box(_wagon_boxes[index], body)
	_lid_boxes[index].bg_color = Color(color.lightened(0.16), alpha)
	draw_style_box(_lid_boxes[index], body.grow(-6.0))
	draw_multiline(_wagon_ribs, Color(color.darkened(0.18), alpha * 0.5), 2.5, true)
	var texture: Texture2D = Icons.texture(_wagon_symbols[index])
	if texture != null:
		var half: float = SYMBOL_PIXELS * 0.5
		draw_texture_rect(texture, Rect2(Vector2(-half, -half), Vector2(SYMBOL_PIXELS, SYMBOL_PIXELS)), false,
			Color(1.0, 1.0, 1.0, alpha * 0.95))
	_reset_transform()


func _draw_couplings(alpha: float) -> void:
	_draw_link(_blue_p, _blue_route, _red_p, 0, _link_red, alpha)
	_draw_link(_loco_p, 0 if _blue_route == 0 else 1, _blue_p, _blue_route, _link_loco, alpha)


func _draw_link(p_back: float, route_back: int, p_front: float, route_front: int, linked: bool, alpha: float) -> void:
	if not linked or alpha <= 0.01:
		return
	var a: Transform2D = _pose(route_back, p_back, WAGON_LENGTH)
	var b: Transform2D = _pose(route_front, p_front, WAGON_LENGTH)
	var from_point: Vector2 = _to_screen(a.origin)
	var to_point: Vector2 = _to_screen(b.origin)
	draw_line(from_point, to_point, Color(UiTokens.C_INK, 0.4 * alpha), 7.0 * _scale, true)


func _draw_loco(route: int, p: float) -> void:
	var pose: Transform2D = _pose(route, p, LOCO_LENGTH)
	var angle: float = pose.get_rotation()
	_transform(pose.origin, angle)
	var half_l: float = LOCO_LENGTH * 0.5
	var half_w: float = LOCO_WIDTH * 0.5
	var body: Rect2 = Rect2(Vector2(-half_l, -half_w), Vector2(LOCO_LENGTH, LOCO_WIDTH))
	draw_style_box(_shadow_box, Rect2(body.position + SHADOW_OFFSET, body.size))
	draw_style_box(_loco_box, body)
	# Kabin (arka), kazan şeridi (ortada), baca (ön) ve far.
	draw_style_box(_cab_box, Rect2(Vector2(-half_l + 6.0, -half_w + 6.0), Vector2(34.0, LOCO_WIDTH - 12.0)))
	draw_style_box(_stripe_box, Rect2(Vector2(-half_l + 46.0, -3.0), Vector2(LOCO_LENGTH - 60.0, 6.0)))
	draw_circle(Vector2(half_l - 22.0, 0.0), 10.0, UiTokens.C_INK, true, -1.0, true)
	draw_circle(Vector2(half_l - 22.0, 0.0), 5.0, UiTokens.C_LOCO_CAB, true, -1.0, true)
	draw_circle(Vector2(half_l - 4.0, 0.0), 6.5, Color(1.0, 0.93, 0.62), true, -1.0, true)
	_reset_transform()


func _draw_smoke(t: float) -> void:
	var pose: Transform2D = _pose(0 if _blue_route == 0 else 1, _loco_p, LOCO_LENGTH)
	var heading: Vector2 = Vector2.from_angle(pose.get_rotation())
	var chimney: Vector2 = pose.origin + heading * (LOCO_LENGTH * 0.5 - 22.0)
	for puff: int in SMOKE_PUFFS:
		var phase: float = fposmod(t * SMOKE_SPEED + float(puff) / float(SMOKE_PUFFS), 1.0)
		var at: Vector2 = chimney + SMOKE_RISE * phase
		var radius: float = lerpf(8.0, 24.0, phase) * _scale
		var fade: float = (1.0 - phase) * 0.22
		draw_circle(_to_screen(at), radius, Color(1.0, 1.0, 1.0, fade), true, -1.0, true)


func _draw_effects(t: float) -> void:
	# Ayırma kıvılcımı: iki aracın arasında genişleyen halka.
	_spark(t, T_PUSH_A_END, _red_p, 0, _blue_p, 0)
	_spark(t, T_PUSH_B_END, _blue_p, 1, _loco_p, 1)
	# Çözüm: bütün hedeflerde sakin halkalar.
	if t >= T_LEAVE_END - 0.4 and t < T_FADE_OUT:
		var phase: float = clampf((t - (T_LEAVE_END - 0.4)) / PULSE_SECONDS, 0.0, 1.0)
		for spot: int in 3:
			var route: int = 0 if spot == 0 else 1
			var p: float = _end_a - END_MARGIN if spot == 0 else _end_b - END_MARGIN
			if spot == 2:
				p -= WAGON_LENGTH + COUPLE_GAP + 6.0
			var pose: Transform2D = _pose(route, p, WAGON_LENGTH)
			var radius: float = lerpf(WAGON_WIDTH * 0.7, WAGON_LENGTH * 1.05, phase) * _scale
			draw_arc(_to_screen(pose.origin), radius, 0.0, TAU, 48,
				Color(_wagon_colors[spot], (1.0 - phase) * 0.55), 5.0, true)
	# Oyun kipinde dokunuş: lokomotifte kısa halka.
	if press > 0.0:
		var loco_pose: Transform2D = _pose(0 if _blue_route == 0 else 1, _loco_p, LOCO_LENGTH)
		draw_arc(_to_screen(loco_pose.origin), lerpf(70.0, 36.0, press) * _scale, 0.0, TAU, 40,
			Color(UiTokens.C_PRIMARY, press * 0.6), 6.0, true)


func _spark(t: float, start: float, p_a: float, route_a: int, p_b: float, route_b: int) -> void:
	if t < start or t > start + SPARK_SECONDS:
		return
	var phase: float = (t - start) / SPARK_SECONDS
	var a: Transform2D = _pose(route_a, p_a, WAGON_LENGTH)
	var b: Transform2D = _pose(route_b, p_b, WAGON_LENGTH)
	var middle: Vector2 = _to_screen((a.origin + b.origin) * 0.5)
	var radius: float = lerpf(10.0, 52.0, Motion.ease_out(phase)) * _scale
	draw_arc(middle, radius, 0.0, TAU, 32, Color(UiTokens.C_STAR, (1.0 - phase) * 0.9), 5.0, true)
	draw_circle(middle, 7.0 * _scale * (1.0 - phase), Color(UiTokens.C_STAR, 0.95), true, -1.0, true)


func _draw_hint() -> void:
	if hint_phase < 0.0:
		return
	var pose: Transform2D = _pose(0 if _blue_route == 0 else 1, _loco_p, LOCO_LENGTH)
	var radius: float = lerpf(LOCO_LENGTH * 0.5, LOCO_LENGTH * 1.6, hint_phase) * _scale
	draw_arc(_to_screen(pose.origin), radius, 0.0, TAU, 56, Color(UiTokens.C_WARNING, 1.0 - hint_phase),
		float(UiTokens.SIZE_HINT_RING), true)


## Odak noktası (denetim/koç): lokomotifin ekran konumu (kontrol uzayı).
func loco_screen_position() -> Vector2:
	_compute_state()
	var pose: Transform2D = _pose(0 if _blue_route == 0 else 1, _loco_p, LOCO_LENGTH)
	return _to_screen(pose.origin)


## Makasın ekran konumu (koç: 3. seviye).
func switch_screen_position() -> Vector2:
	return _to_screen(Vector2.ZERO)


func yard_scale() -> float:
	return _scale


func ground_origin() -> Vector2:
	return _origin


func glow_texture() -> GradientTexture2D:
	if _glow == null:
		var gradient: Gradient = Gradient.new()
		gradient.set_color(0, Color(1.0, 1.0, 1.0, 0.75))
		gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
		_glow = GradientTexture2D.new()
		_glow.gradient = gradient
		_glow.fill = GradientTexture2D.FILL_RADIAL
		_glow.fill_from = Vector2(0.5, 0.5)
		_glow.fill_to = Vector2(1.0, 0.5)
		_glow.width = 256
		_glow.height = 256
	return _glow


## Statik katman: zemin, çakıl, ray, ağaç, bina. Yalnız boyut değişince yeniden çizilir.
class Backdrop extends Control:
	var yard: DemoYard = null

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if yard == null or size.x <= 0.0:
			return
		_draw_ground()
		var origin: Vector2 = yard.ground_origin()
		var scale_factor: float = yard.yard_scale()
		_draw_apron(origin, scale_factor)
		_draw_trees(origin, scale_factor)
		_draw_depot(origin, scale_factor)
		_draw_tracks(origin, scale_factor)

	func _draw_ground() -> void:
		var colors: PackedColorArray = PackedColorArray([UiTokens.C_GROUND_TOP, UiTokens.C_GROUND_TOP,
			UiTokens.C_GROUND_BOTTOM, UiTokens.C_GROUND_BOTTOM])
		var corners: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0.0), size,
			Vector2(0.0, size.y)])
		draw_polygon(corners, colors)
		# Yumuşak ışık lekeleri: sıcak gün ışığı hissi (ucuz radyal doku).
		var glow: Texture2D = yard.glow_texture()
		var big: float = maxf(size.x, size.y) * 0.9
		draw_texture_rect(glow, Rect2(Vector2(size.x * 0.15 - big * 0.5, size.y * 0.25 - big * 0.5), Vector2(big, big)),
			false, Color(1.0, 0.97, 0.82, 0.55))
		draw_texture_rect(glow, Rect2(Vector2(size.x * 0.9 - big * 0.4, size.y * 0.8 - big * 0.4), Vector2(big * 0.8, big * 0.8)),
			false, Color(UiTokens.C_FOLIAGE, 0.22))

	func _apron_rect(origin: Vector2, scale_factor: float) -> Rect2:
		var width: float = (CURVE_DX * 2.0 + WAGON_WIDTH) + APRON_MARGIN * 0.6
		var top: float = -(CURVE_DY + SIDING_LENGTH + END_MARGIN * 0.4)
		var bottom: float = LEAD_LENGTH + 50.0
		return Rect2(origin + Vector2(-width * 0.5, top) * scale_factor, Vector2(width, bottom - top) * scale_factor)

	func _draw_apron(origin: Vector2, scale_factor: float) -> void:
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = Color(UiTokens.C_GRAVEL, 0.55)
		box.set_corner_radius_all(int(float(APRON_RADIUS) * scale_factor))
		box.anti_aliasing = true
		box.shadow_color = Color(0.2, 0.22, 0.14, 0.14)
		box.shadow_size = int(38.0 * scale_factor)
		box.shadow_offset = Vector2(0.0, 10.0 * scale_factor)
		draw_style_box(box, _apron_rect(origin, scale_factor))

	func _draw_trees(origin: Vector2, scale_factor: float) -> void:
		for spot: Vector3 in TREE_SPOTS:
			var center: Vector2 = origin + Vector2(spot.x, spot.y) * scale_factor
			var radius: float = spot.z * scale_factor
			draw_circle(center + Vector2(7.0, 11.0) * scale_factor, radius, Color(0.16, 0.22, 0.12, 0.16), true, -1.0, true)
			draw_circle(center, radius, UiTokens.C_FOLIAGE_DEEP, true, -1.0, true)
			draw_circle(center + Vector2(-radius * 0.18, -radius * 0.2), radius * 0.74, UiTokens.C_FOLIAGE, true, -1.0, true)

	func _draw_depot(origin: Vector2, scale_factor: float) -> void:
		var rect: Rect2 = Rect2(origin + DEPOT_RECT.position * scale_factor, DEPOT_RECT.size * scale_factor)
		var shadow: StyleBoxFlat = StyleBoxFlat.new()
		shadow.bg_color = Color(0.16, 0.2, 0.14, 0.14)
		shadow.set_corner_radius_all(int(12.0 * scale_factor))
		shadow.anti_aliasing = true
		draw_style_box(shadow, Rect2(rect.position + Vector2(8.0, 12.0) * scale_factor, rect.size))
		var roof: StyleBoxFlat = StyleBoxFlat.new()
		roof.bg_color = UiTokens.C_ROOF
		roof.set_corner_radius_all(int(12.0 * scale_factor))
		roof.anti_aliasing = true
		draw_style_box(roof, rect)
		var ridge: float = rect.position.y + rect.size.y * 0.5
		draw_line(Vector2(rect.position.x + 10.0 * scale_factor, ridge), Vector2(rect.end.x - 10.0 * scale_factor, ridge),
			UiTokens.C_ROOF.darkened(0.14), 5.0 * scale_factor, true)
		draw_line(Vector2(rect.position.x + 10.0 * scale_factor, ridge - 18.0 * scale_factor),
			Vector2(rect.end.x - 10.0 * scale_factor, ridge - 18.0 * scale_factor), UiTokens.C_ROOF.lightened(0.18),
			3.0 * scale_factor, true)

	func _draw_tracks(origin: Vector2, scale_factor: float) -> void:
		var count: int = yard._ballast_lines.size()
		for index: int in count:
			draw_polyline(_scaled(yard._ballast_lines[index], origin, scale_factor), Color(UiTokens.C_GRAVEL_DEEP, 0.6),
				BALLAST_WIDTH * scale_factor, true)
		var sleepers: PackedVector2Array = _scaled(yard._sleepers, origin, scale_factor)
		draw_multiline(sleepers, UiTokens.C_SLEEPER, SLEEPER_WIDTH * scale_factor, true)
		for line: PackedVector2Array in yard._rail_lines:
			draw_polyline(_scaled(line, origin, scale_factor), UiTokens.C_RAIL, RAIL_WIDTH * scale_factor, true)
		# Tampon: her yan hattın ucunda.
		for side: int in 2:
			var route: PackedVector2Array = yard._routes[side]
			var tip: Vector2 = origin + route[route.size() - 1] * scale_factor
			var stop: StyleBoxFlat = StyleBoxFlat.new()
			stop.bg_color = UiTokens.C_INK.lerp(UiTokens.C_RAIL, 0.35)
			stop.set_corner_radius_all(int(5.0 * scale_factor))
			stop.anti_aliasing = true
			draw_style_box(stop, Rect2(tip + Vector2(-26.0, -14.0) * scale_factor, Vector2(52.0, 14.0) * scale_factor))

	static func _scaled(points: PackedVector2Array, origin: Vector2, scale_factor: float) -> PackedVector2Array:
		var result: PackedVector2Array = PackedVector2Array()
		result.resize(points.size())
		for index: int in points.size():
			result[index] = origin + points[index] * scale_factor
		return result
