class_name BasketView
extends Node2D

## Renk sepetinin görünümü. Konum = sepetin orta noktası. Sprite varsa
## (basket_body.png + nötr basket_band.png renk çarpımıyla) onu kullanır.
## Hareket katmanları: kök düğüm = konum (kayma/geliş), `_breath` = boşta nefes,
## `_visual` = tepki (zıplama/ezilme). Üçü ayrı olduğundan Tween'ler birbirini ezmez.

const BODY_PATH: String = "res://assets/sprites/basket_body.png"
const BAND_PATH: String = "res://assets/sprites/basket_band.png"
const BODY_COLOR: Color = Color("e9d3ad")
const EMPTY_ALPHA: float = 0.0
const DOT_RADIUS_RATIO: float = 0.045
## Ezilme/nefes sepetin tabanından yapılır (taban yerden kopmasın): tuvalde taban ~ bu oranda.
const PIVOT_RATIO: float = 0.3
const BAND_PULSE_SCALE: float = 1.06

var size: float = 240.0
var color: Color = Color.WHITE
var filled: int = 0
var active: bool = true
## Sepetin dinlenme konumu: kayma/geliş sırasında bile uçuş hedefi buraya göre hesaplanır.
var rest_position: Vector2 = Vector2.ZERO

var _body: Sprite2D = null
var _band: Sprite2D = null
var _breath: Node2D = null
var _visual: Node2D = null
var _box: StyleBoxFlat = StyleBoxFlat.new()
var _react_tween: Tween = null
var _band_tween: Tween = null
var _move_tween: Tween = null
var _leaving: bool = false
var _pending_enter: bool = false
var _pending_color: Color = Color.WHITE
var _breath_phase: float = 0.0


func setup(pixel_size: float) -> void:
	size = pixel_size
	_breath_phase = randf() * TAU
	_breath = Node2D.new()
	_breath.position = Vector2(0.0, size * PIVOT_RATIO)
	add_child(_breath)
	_visual = Node2D.new()
	_breath.add_child(_visual)
	if ResourceLoader.exists(BODY_PATH) and ResourceLoader.exists(BAND_PATH):
		_body = _make_sprite(BODY_PATH)
		_band = _make_sprite(BAND_PATH)
	_box.anti_aliasing = true
	_box.anti_aliasing_size = 1.5


func set_color(tint: Color) -> void:
	color = tint
	active = true
	visible = true
	if _band != null:
		# Önceki sepetin tamamlanma parıltısı hâlâ sürüyorsa durdurulur: yoksa o animasyon bandı
		# ESKİ renge geri boyar ve yeni sepet yanlış renkte görünür (kırmızı sepete mavi gider).
		if _band_tween != null:
			_band_tween.kill()
			_band_tween = null
		_band.scale = _band_rest_scale()
		_band.modulate = tint
	queue_redraw()


## Ekranda görünen sepet rengi (prob bununla kural rengini karşılaştırır). Rengini henüz almamış
## joker beyaz bant + gökkuşağı gösterir: JOKER_BAND döner.
func shown_color() -> Color:
	if joker and not _joker_fixed:
		return JOKER_BAND
	return _band.modulate if _band != null else color


func set_filled(count: int) -> void:
	filled = count
	queue_redraw()


## Sepetteki `index`. parçanın duracağı yer (global).
## Katlanmış parçalar üst üste yığılır: her kat ayrı seçilir (aralarında boşluk/gölge kalır).
func slot_position(index: int) -> Vector2:
	# Büyük sepette 5 kat aynı yüksekliğe sığsın diye aralık daralır.
	var step: float = size * 0.19 * float(LaundryBoard.BASKET_CAPACITY) / float(maxi(capacity, LaundryBoard.BASKET_CAPACITY))
	return rest_position + Vector2(0.0, -size * 0.17 - float(index) * step)


func folded_width() -> float:
	return size * 0.5


func _process(_delta: float) -> void:
	# Boşta çok hafif nefes: ekran hiç ölü durmasın ama sakin kalsın.
	var time: float = float(Time.get_ticks_msec()) * 0.001
	var breath: float = Motion.BASKET_BREATH * sin(time * Motion.BASKET_BREATH_SPEED + _breath_phase)
	_breath.scale = Vector2(1.0 - breath * 0.5, 1.0 + breath)


## Yeni bir parça sepete indi: ağırlıklı, yumuşak zıplama (strength 0..1).
func receive(strength: float) -> void:
	_react(Vector2.ONE + (Motion.BASKET_BOUNCE_SQUASH - Vector2.ONE) * strength)


## Kilitli/uyarı: bu sepet beklendiğini gösteren yumuşak şişme.
func hop() -> void:
	_react(Vector2.ONE * Motion.BASKET_HOP_SCALE)


func _react(peak: Vector2) -> void:
	if _react_tween != null:
		_react_tween.kill()
	_react_tween = create_tween()
	_react_tween.tween_property(_visual, "scale", peak, Motion.BASKET_BOUNCE_IN_SECONDS)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_react_tween.tween_property(_visual, "scale", Vector2.ONE, Motion.BASKET_BOUNCE_OUT_SECONDS)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Tamamlanma: yığın basarken sepet de hafifçe çöker.
func press(seconds: float) -> void:
	if _react_tween != null:
		_react_tween.kill()
	_react_tween = create_tween()
	_react_tween.tween_property(_visual, "scale", Vector2(1.06, 0.9), seconds)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_react_tween.tween_property(_visual, "scale", Vector2.ONE, Motion.BASKET_BOUNCE_OUT_SECONDS)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Bant/kapak parlayıp yavaşça sönen nabız.
func pulse_band() -> void:
	if _band == null:
		return
	if _band_tween != null:
		_band_tween.kill()
	_band.modulate = color.lightened(Motion.COMPLETE_BAND_GLOW)
	_band.scale = _band_rest_scale() * BAND_PULSE_SCALE
	_band_tween = create_tween().set_parallel(true)
	_band_tween.tween_property(_band, "modulate", color, Motion.COMPLETE_BAND_SECONDS)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_band_tween.tween_property(_band, "scale", _band_rest_scale(), Motion.COMPLETE_BAND_SECONDS)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Yavaşça aşağı kayar (ease-in) ve gizlenir. Bitince bekleyen yeni sepet varsa gelir.
func leave() -> void:
	_leaving = true
	_kill_move()
	_move_tween = create_tween()
	_move_tween.tween_property(self, "position:y", rest_position.y + Motion.BASKET_SLIDE, Motion.BASKET_SLIDE_OUT_SECONDS)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_move_tween.tween_callback(_after_leave)


## Yeni sepet: kayma bitince alttan gelir ve hafif aşarak yerine oturur. Büyük/joker sepet de
## (kapasite ve gökkuşağı) yeni sepetle birlikte gelir.
func enter(tint: Color, cap: int = LaundryBoard.BASKET_CAPACITY, is_joker: bool = false) -> void:
	_pending_color = tint
	_pending_cap = cap
	_pending_joker = is_joker
	_pending_enter = true
	if not _leaving:
		_do_enter()


func _after_leave() -> void:
	_leaving = false
	visible = false
	set_filled(0)
	if _pending_enter:
		_do_enter()


func _do_enter() -> void:
	_pending_enter = false
	_kill_move()
	set_capacity(_pending_cap)
	set_joker(_pending_joker)
	set_color(_pending_color)
	position.y = rest_position.y + Motion.BASKET_SLIDE
	_breath.modulate.a = 0.0
	_visual.scale = Vector2.ONE * Motion.BASKET_ARRIVE_FROM_SCALE
	_move_tween = create_tween().set_parallel(true)
	_move_tween.tween_property(self, "position:y", rest_position.y, Motion.BASKET_ARRIVE_SECONDS)\
		.set_delay(Motion.BASKET_ARRIVE_DELAY).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_move_tween.tween_property(_breath, "modulate:a", 1.0, Motion.BASKET_ARRIVE_SECONDS * 0.4)\
		.set_delay(Motion.BASKET_ARRIVE_DELAY)
	_move_tween.tween_property(_visual, "scale", Vector2.ONE, Motion.BASKET_ARRIVE_SECONDS)\
		.set_delay(Motion.BASKET_ARRIVE_DELAY).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _kill_move() -> void:
	if _move_tween != null:
		_move_tween.kill()


func _band_rest_scale() -> Vector2:
	return Vector2.ONE * (size / _band.texture.get_size().x)


func _make_sprite(path: String) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = load(path) as Texture2D
	sprite.scale = Vector2.ONE * (size / sprite.texture.get_size().x)
	sprite.position = Vector2(0.0, -size * PIVOT_RATIO)
	_visual.add_child(sprite)
	return sprite


func _draw() -> void:
	# Doluluk noktaları: sepetin altında 3 küçük nokta (yazısız sayaç).
	var radius: float = size * DOT_RADIUS_RATIO
	var middle: float = float(capacity - 1) * 0.5
	for index: int in range(capacity):
		var center: Vector2 = Vector2((float(index) - middle) * radius * 3.2, size * 0.52)
		var dot: Color = color if index < filled else Color(0.0, 0.0, 0.0, 0.12)
		if joker and not _joker_fixed and index >= filled:
			# Rengini almamış joker: noktalar gökkuşağı tonlarında (hangi renk gelirse).
			dot = JOKER_TINTS[index % JOKER_TINTS.size()]
			dot.a = JOKER_DOT_ALPHA
		draw_circle(center, radius, dot, true, -1.0, true)
	if _body != null:
		return
	var body: Rect2 = Rect2(Vector2(-size * 0.42, -size * 0.18), Vector2(size * 0.84, size * 0.58))
	_box.set_corner_radius_all(int(size * 0.12))
	_box.bg_color = BODY_COLOR.darkened(0.12)
	draw_style_box(_box, Rect2(body.position + Vector2(0.0, size * 0.03), body.size))
	_box.bg_color = BODY_COLOR
	draw_style_box(_box, body)
	_box.set_corner_radius_all(int(size * 0.07))
	_box.bg_color = color
	draw_style_box(_box, Rect2(Vector2(-size * 0.46, -size * 0.26), Vector2(size * 0.92, size * 0.16)))


# --- Büyük ve joker sepet ------------------------------------------------------------------

const BIG_SCALE: float = 1.1
## Joker bandı: beyaz (renksiz) + bandın üstünde gökkuşağı benekleri; renk gelince söner.
const JOKER_BAND: Color = Color(1.0, 1.0, 1.0)
const JOKER_TINTS: Array[Color] = [Color("e5484d"), Color("f58a3c"), Color("f5c02e"), Color("3dbb6e"),
	Color("3e8ef7"), Color("9b59d0")]
const JOKER_DOT_ALPHA: float = 0.55
const JOKER_SPOT_RATIO: float = 0.055
const JOKER_SPOT_SPREAD: float = 0.36
const JOKER_SPOT_Y: float = -0.53

var capacity: int = LaundryBoard.BASKET_CAPACITY
var joker: bool = false
var _joker_fixed: bool = false
var _pending_cap: int = LaundryBoard.BASKET_CAPACITY
var _pending_joker: bool = false
var _rainbow: JokerRainbow = null


## Büyük sepet: 5 doluluk noktası ve biraz daha iri gövde (yazısız "bu daha çok alır").
func set_capacity(cap: int) -> void:
	capacity = maxi(cap, 1)
	if _visual != null:
		_visual.scale = Vector2.ONE
		_breath.scale = Vector2.ONE
		scale = Vector2.ONE * (BIG_SCALE if capacity > LaundryBoard.BASKET_CAPACITY else 1.0)
	queue_redraw()


## Joker (rengini almamış): bant beyaz, üstünde gökkuşağı benekleri.
func set_joker(is_joker: bool) -> void:
	joker = is_joker
	_joker_fixed = false
	if is_joker and _rainbow == null and _visual != null:
		_rainbow = JokerRainbow.new()
		_rainbow.radius = size * JOKER_SPOT_RATIO
		_rainbow.spread = size * JOKER_SPOT_SPREAD
		_rainbow.position = Vector2(0.0, size * JOKER_SPOT_Y)
		_visual.add_child(_rainbow)
	if _rainbow != null:
		_rainbow.visible = is_joker
		_rainbow.modulate.a = 1.0
	queue_redraw()


## Rengi joker için `JOKER_BAND`, normal sepette verilen renk (set_color ile birlikte çağrılır).
func show_joker_color(tint: Color) -> void:
	set_color(JOKER_BAND if joker and not _joker_fixed else tint)
	color = tint


## Joker rengini aldı: gökkuşağı söner, bant o renge döner, küçük bir sıçrama.
func fix_joker(tint: Color) -> void:
	if _pending_enter:
		# Sepet daha kayıp gelmedi: rengini almış olarak gelsin (gelişte gökkuşağı yeniden açılmasın).
		_pending_color = tint
		_pending_joker = false
		return
	_joker_fixed = true
	set_color(tint)
	if _rainbow != null:
		var fade: Tween = _rainbow.create_tween()
		fade.tween_property(_rainbow, "modulate:a", 0.0, Motion.JOKER_FADE_SECONDS)
		fade.tween_callback(_rainbow.set.bind("visible", false))
	hop()


## Gökkuşağı benekleri: bant üzerinde yay boyunca altı yumuşak daire.
class JokerRainbow extends Node2D:
	var radius: float = 12.0
	var spread: float = 90.0

	func _draw() -> void:
		var count: int = BasketView.JOKER_TINTS.size()
		for index: int in range(count):
			var t: float = float(index) / float(count - 1)
			var at: Vector2 = Vector2(lerpf(-spread, spread, t), -sin(PI * t) * radius * 0.8)
			draw_circle(at, radius, BasketView.JOKER_TINTS[index], true, -1.0, true)
