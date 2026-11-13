class_name BasketView
extends Node2D

## Renk sepetinin görünümü. Konum = sepet karesinin orta noktası.
## Sepet aynı Blender kamerasından render edilmiş KATMANLARDAN kurulur (tools/blender/make_sprites.py):
##   gölge (çimde) -> arka gövde (iç arka duvar + taban) -> arka astar (renklenir) -> YIĞIN
##   -> ön gövde (ön duvar + kulplar) -> ön astar (renklenir).
## Katlanmış çamaşırlar `adopt` ile YIĞIN düğümüne taşınır: ön duvar altlarını keser, yani ağızdan
## içeri girmiş görünürler; sepet ezilince/kayıp gidince yığın da onunla birlikte hareket eder.
## Hareket katmanları: kök düğüm = konum (kayma/geliş), `_breath` = boşta nefes,
## `_visual` = tepki (zıplama/ezilme), `_rim` = astar sallantısı. Ayrı olduklarından Tween'ler
## birbirini ezmez.

const BACK_PATH: String = "res://assets/sprites/basket/basket_back.png"
const FRONT_PATH: String = "res://assets/sprites/basket/basket_front.png"
const BAND_BACK_PATH: String = "res://assets/sprites/basket/band_back.png"
const BAND_FRONT_PATH: String = "res://assets/sprites/basket/band_front.png"
const SHADOW_PATH: String = "res://assets/sprites/basket/basket_shadow.png"
const BODY_COLOR: Color = Color("e9d3ad")
const DOT_RADIUS_RATIO: float = 0.045
const DOT_Y_RATIO: float = 0.52

## Render karesindeki önemli noktalar (tuval oranı, v aşağı). make_sprites.py `BASKET_POINT`
## satırlarından alınır; kamera/biçim değişirse burası da güncellenir.
const RIM_FRONT_V: float = 0.545
const RIM_BACK_V: float = 0.151
const RIM_HALF_U: float = 0.377
const FOOT_V: float = 0.897
## Ezilme/nefes sepetin tabanından yapılır (taban yerden kopmasın).
const PIVOT_RATIO: float = FOOT_V - 0.5
## Ağız elipsinin merkezi ve yarı yüksekliği (kök düğüme göre, boy oranı).
const RIM_CENTER_RATIO: float = (RIM_FRONT_V + RIM_BACK_V) * 0.5 - 0.5
const RIM_HALF_H_RATIO: float = (RIM_FRONT_V - RIM_BACK_V) * 0.5

## Ön katmanlar yığının üstünde çizilir. Yığındaki parçalar `game.gd`de 60 + sıra z'sini alır
## (en çok 60 + 4); ön duvar bunların hepsinin üstünde kalmalı, parçacıklar (90) ise üstünde.
const FRONT_Z: int = 70

## Yığın yerleşimi (boy oranı, köke göre). İlk kat ağızda, ön rulonun hemen arkasında oturur:
## alt kenarı ön duvarın arkasına girer -> "sepetin içinde" okunur. Sonraki katlar yukarı yığılır ve
## dolunca ağzın üstüne taşar.
const PILE_BASE_RATIO: float = -0.085
const PILE_STEP_RATIO: float = 0.1
## Büyük sepette 5 kat sığsın diye adım daralır; yine de her katın kat kenarı görünür kalır ve
## dolu büyük sepette yığın ağzın üstüne kabarır.
const PILE_BIG_STEP_FACTOR: float = 0.75
## Katlar birbirinden ayrı okunsun: sırayla hafif sağa/sola kayar.
const PILE_SHIFT_RATIO: float = 0.05
const FOLDED_WIDTH_RATIO: float = 0.5

## Ağırlık tepkisi: yığın düğümü inişte biraz basılır, astar rulosu hafifçe sallanır.
const PILE_LAND_SQUASH: Vector2 = Vector2(1.03, 0.9)
const RIM_JIGGLE: Vector2 = Vector2(1.025, 0.93)
const RIM_JIGGLE_IN_SECONDS: float = 0.08
const RIM_JIGGLE_OUT_SECONDS: float = 0.45
## Tamamlanma: yığın sıkışır, sonra sepetin içine çöker (kayıp giderken parçalar içeride kalır).
const PILE_PRESS: Vector2 = Vector2(1.05, 0.62)
const PILE_SINK_RATIO: float = 0.1
const PILE_SINK_SCALE: Vector2 = Vector2(0.96, 0.5)
const BAND_PULSE_SCALE: float = 1.05
const SHADOW_ALPHA: float = 1.0

var size: float = 240.0
var color: Color = Color.WHITE
var filled: int = 0
var active: bool = true
## Sepetin dinlenme konumu: kayma/geliş sırasında bile uçuş hedefi buraya göre hesaplanır.
var rest_position: Vector2 = Vector2.ZERO

var _back: Sprite2D = null
var _front: Sprite2D = null
var _band_back: Sprite2D = null
var _band_front: Sprite2D = null
var _shadow: Sprite2D = null
var _rim: Node2D = null
var _pile: Node2D = null
## Yığının taşıyıcısı: kök ölçeğini (büyük sepet) geri alır -> yığındaki parçanın yerel ölçeği =
## ekrandaki ölçeği. Böylece iniş ezilmesi (GarmentView mutlak ölçekle çalışır) sıçrama yapmaz.
var _pile_holder: Node2D = null
var _breath: Node2D = null
var _visual: Node2D = null
var _box: StyleBoxFlat = StyleBoxFlat.new()
var _react_tween: Tween = null
var _band_tween: Tween = null
var _rim_tween: Tween = null
var _pile_tween: Tween = null
var _move_tween: Tween = null
var _leaving: bool = false
var _pending_enter: bool = false
var _pending_color: Color = Color.WHITE
var _breath_phase: float = 0.0
var _shadow_scale: float = 1.0
## Kayıp giderken taşınan (tamamlanmış) yığın: gidiş bitince serbest bırakılır.
var _carried: Array[Node2D] = []
## Sepet giderken/gelirken inen parça: sepet yerine oturunca yığına alınır.
var _deferred: Array[Node2D] = []
var _deferred_slots: Array[int] = []


func setup(pixel_size: float) -> void:
	size = pixel_size
	_breath_phase = randf() * TAU
	_breath = Node2D.new()
	_breath.position = Vector2(0.0, size * PIVOT_RATIO)
	add_child(_breath)
	if ResourceLoader.exists(SHADOW_PATH):
		# Gölge nefes/zıplama ölçeğine katılmaz (yere yapışık); yalnız genişliği ezilmeyi izler.
		_shadow = Sprite2D.new()
		_shadow.texture = load(SHADOW_PATH) as Texture2D
		_shadow_scale = size / _shadow.texture.get_size().x
		_shadow.scale = Vector2.ONE * _shadow_scale
		_shadow.position = Vector2(0.0, -size * PIVOT_RATIO)
		_shadow.modulate.a = SHADOW_ALPHA
		_breath.add_child(_shadow)
	_visual = Node2D.new()
	_breath.add_child(_visual)
	if ResourceLoader.exists(BACK_PATH) and ResourceLoader.exists(FRONT_PATH) \
			and ResourceLoader.exists(BAND_BACK_PATH) and ResourceLoader.exists(BAND_FRONT_PATH):
		_back = _make_sprite(BACK_PATH, _visual, Vector2(0.0, -size * PIVOT_RATIO))
		# Astar ağız elipsinin merkezinden ölçeklenir: sallanınca rulo yerinden kaymaz, yalnız esner.
		_rim = Node2D.new()
		_rim.position = Vector2(0.0, size * (RIM_CENTER_RATIO - PIVOT_RATIO))
		_visual.add_child(_rim)
		_band_back = _make_sprite(BAND_BACK_PATH, _rim, Vector2(0.0, -size * RIM_CENTER_RATIO))
		_pile_holder = Node2D.new()
		_pile_holder.position = Vector2(0.0, size * (PILE_BASE_RATIO - PIVOT_RATIO))
		_visual.add_child(_pile_holder)
		_pile = Node2D.new()
		_pile_holder.add_child(_pile)
		_front = _make_sprite(FRONT_PATH, _visual, Vector2(0.0, -size * PIVOT_RATIO))
		_front.z_index = FRONT_Z
		# Ön astar ön gövdeden SONRA çizilmeli (aynı z'de ağaç sırası ters düşerdi): bir üst z.
		_band_front = _make_sprite(BAND_FRONT_PATH, _rim, Vector2(0.0, -size * RIM_CENTER_RATIO))
		_band_front.z_index = FRONT_Z + 1
	_box.anti_aliasing = true
	_box.anti_aliasing_size = 1.5


func set_color(tint: Color) -> void:
	color = tint
	active = true
	visible = true
	if _band_front != null:
		# Önceki sepetin tamamlanma parıltısı hâlâ sürüyorsa durdurulur: yoksa o animasyon bandı
		# ESKİ renge geri boyar ve yeni sepet yanlış renkte görünür (kırmızı sepete mavi gider).
		if _band_tween != null:
			_band_tween.kill()
			_band_tween = null
		_rim.scale = Vector2.ONE
		_set_band_modulate(tint)
	queue_redraw()


## Ekranda görünen sepet rengi (prob bununla kural rengini karşılaştırır). Rengini henüz almamış
## joker beyaz bant + gökkuşağı gösterir: JOKER_BAND döner.
func shown_color() -> Color:
	if joker and not _joker_fixed:
		return JOKER_BAND
	return _band_front.modulate if _band_front != null else color


func set_filled(count: int) -> void:
	filled = count
	queue_redraw()


## Sepetteki `index`. parçanın duracağı yer (global). Katlar ağızdan yukarı yığılır; sırayla hafif
## sağa/sola kayar (game.gd ayrıca eğim ve ton farkı verir) -> her kat ayrı okunur.
func slot_position(index: int) -> Vector2:
	return rest_position + _slot_local(index) * scale


## Yığın düğümüne göre yerel konum (ölçeksiz kök birimi).
func _slot_local(index: int) -> Vector2:
	var step: float = size * PILE_STEP_RATIO
	if capacity > LaundryBoard.BASKET_CAPACITY:
		step *= PILE_BIG_STEP_FACTOR
	var shift: float = size * PILE_SHIFT_RATIO * (0.0 if index == 0 else (1.0 if index % 2 == 1 else -1.0))
	return Vector2(shift, size * PILE_BASE_RATIO - float(index) * step)


func folded_width() -> float:
	return size * FOLDED_WIDTH_RATIO * scale.x


## İnen katlanmış parçayı yığına alır: artık sepetin parçasıdır (ön duvarın ARKASINDA çizilir,
## sepetle birlikte ezilir ve kayıp gider). `game.gd` iniş anında çağırır.
func adopt(piece: Node2D, index: int) -> void:
	if _pile == null or not is_instance_valid(piece):
		return
	if _leaving or _pending_enter:
		# Sepet yerinde değil: parça oturduğu yerde bekler, sepet gelince yığına katılır.
		_deferred.append(piece)
		_deferred_slots.append(index)
		return
	_place_in_pile(piece, index)


func _place_in_pile(piece: Node2D, index: int) -> void:
	piece.reparent(_pile, false)
	# Taşıyıcı kök ölçeğini geri aldığı için konum kök ölçeğiyle çarpılır (ekranda slot_position'a düşer).
	piece.position = (_slot_local(index) - Vector2(0.0, size * PILE_BASE_RATIO)) * scale


func _process(_delta: float) -> void:
	# Boşta çok hafif nefes: ekran hiç ölü durmasın ama sakin kalsın.
	var time: float = float(Time.get_ticks_msec()) * 0.001
	var breath: float = Motion.BASKET_BREATH * sin(time * Motion.BASKET_BREATH_SPEED + _breath_phase)
	_breath.scale = Vector2(1.0 - breath * 0.5, 1.0 + breath)
	if _shadow != null:
		# Gölge yalnız genişlikte ezilmeyi izler (yükseklik değişmez: yere basılı kalır).
		_shadow.scale.x = _shadow_scale * _visual.scale.x
		_shadow.scale.y = _shadow_scale / _breath.scale.y


## Yeni bir parça sepete indi: ağırlıklı, yumuşak zıplama (strength 0..1) + yığın basılır +
## astar rulosu kısa bir an esner.
func receive(strength: float) -> void:
	_react(Vector2.ONE + (Motion.BASKET_BOUNCE_SQUASH - Vector2.ONE) * strength)
	_jiggle_rim(strength)
	if _pile != null and _pile.get_child_count() > 0:
		if _pile_tween != null:
			_pile_tween.kill()
		_pile_tween = create_tween()
		_pile_tween.tween_property(_pile, "scale", Vector2.ONE + (PILE_LAND_SQUASH - Vector2.ONE) * strength,
			Motion.BASKET_BOUNCE_IN_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_pile_tween.tween_property(_pile, "scale", Vector2.ONE, Motion.BASKET_BOUNCE_OUT_SECONDS)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


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


func _jiggle_rim(strength: float) -> void:
	if _rim == null:
		return
	if _rim_tween != null:
		_rim_tween.kill()
	_rim_tween = create_tween()
	_rim_tween.tween_property(_rim, "scale", Vector2.ONE + (RIM_JIGGLE - Vector2.ONE) * strength,
		RIM_JIGGLE_IN_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_rim_tween.tween_property(_rim, "scale", Vector2.ONE, RIM_JIGGLE_OUT_SECONDS)\
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
	_tween_pile(PILE_PRESS, 0.0, seconds, Tween.TRANS_SINE, Tween.EASE_IN_OUT)


## Tamamlanma sonu: sıkışmış yığın sepetin içine çöker (ön duvarın arkasına iner) ve sepet onu
## içinde taşıyarak gider. Parçalar silinmez/solmaz; sepet gidince serbest bırakılır.
func sink_pile(seconds: float) -> void:
	_tween_pile(PILE_SINK_SCALE, size * PILE_SINK_RATIO, seconds, Tween.TRANS_CUBIC, Tween.EASE_IN)


func _tween_pile(target_scale: Vector2, drop: float, seconds: float, trans: Tween.TransitionType,
		ease_type: Tween.EaseType) -> void:
	if _pile == null:
		return
	if _pile_tween != null:
		_pile_tween.kill()
	_pile_tween = create_tween().set_parallel(true)
	_pile_tween.tween_property(_pile, "scale", target_scale, seconds).set_trans(trans).set_ease(ease_type)
	_pile_tween.tween_property(_pile, "position:y", drop, seconds).set_trans(trans).set_ease(ease_type)


## Bant/kapak parlayıp yavaşça sönen nabız.
func pulse_band() -> void:
	if _band_front == null:
		return
	if _band_tween != null:
		_band_tween.kill()
	_set_band_modulate(color.lightened(Motion.COMPLETE_BAND_GLOW))
	_rim.scale = Vector2.ONE * BAND_PULSE_SCALE
	_band_tween = create_tween().set_parallel(true)
	_band_tween.tween_method(_set_band_modulate, _band_front.modulate, color, Motion.COMPLETE_BAND_SECONDS)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_band_tween.tween_property(_rim, "scale", Vector2.ONE, Motion.COMPLETE_BAND_SECONDS)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Astarın iki yarısı her zaman aynı renkte (yan birleşme yerinde ton sıçraması olmasın).
func _set_band_modulate(tint: Color) -> void:
	_band_back.modulate = tint
	_band_front.modulate = tint


## Yavaşça aşağı kayar (ease-in) ve gizlenir; içindeki yığını da taşır. Bitince bekleyen yeni
## sepet varsa gelir.
func leave() -> void:
	_leaving = true
	_kill_move()
	if _pile != null:
		for child: Node in _pile.get_children():
			_carried.append(child as Node2D)
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
	_release_carried()
	if _pending_enter:
		_do_enter()


## Taşınan yığın artık görünmez: serbest bırakılır, yığın düğümü dinlenme hâline döner.
func _release_carried() -> void:
	for piece: Node2D in _carried:
		if is_instance_valid(piece):
			piece.queue_free()
	_carried.clear()
	if _pile != null:
		if _pile_tween != null:
			_pile_tween.kill()
		_pile.scale = Vector2.ONE
		_pile.position = Vector2.ZERO


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
	_move_tween.chain().tween_callback(_adopt_deferred)


## Sepet gelmeden inen parçalar şimdi yığına katılır.
func _adopt_deferred() -> void:
	for at: int in range(_deferred.size()):
		if is_instance_valid(_deferred[at]):
			_place_in_pile(_deferred[at], _deferred_slots[at])
	_deferred.clear()
	_deferred_slots.clear()


func _kill_move() -> void:
	if _move_tween != null:
		_move_tween.kill()


func _make_sprite(path: String, parent: Node2D, at: Vector2) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = load(path) as Texture2D
	sprite.scale = Vector2.ONE * (size / sprite.texture.get_size().x)
	sprite.position = at
	parent.add_child(sprite)
	return sprite


func _draw() -> void:
	# Doluluk noktaları: sepetin altında küçük noktalar (yazısız sayaç).
	var radius: float = size * DOT_RADIUS_RATIO
	var middle: float = float(capacity - 1) * 0.5
	for index: int in range(capacity):
		var center: Vector2 = Vector2((float(index) - middle) * radius * 3.2, size * DOT_Y_RATIO)
		var dot: Color = color if index < filled else Color(0.0, 0.0, 0.0, 0.12)
		if joker and not _joker_fixed and index >= filled:
			# Rengini almamış joker: noktalar gökkuşağı tonlarında (hangi renk gelirse).
			dot = JOKER_TINTS[index % JOKER_TINTS.size()]
			dot.a = JOKER_DOT_ALPHA
		draw_circle(center, radius, dot, true, -1.0, true)
	if _back != null:
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
## Joker bandı: beyaz (renksiz) + ön rulonun üstünde gökkuşağı benekleri; renk gelince söner.
const JOKER_BAND: Color = Color(1.0, 1.0, 1.0)
const JOKER_TINTS: Array[Color] = [Color("e5484d"), Color("f58a3c"), Color("f5c02e"), Color("3dbb6e"),
	Color("3e8ef7"), Color("9b59d0")]
const JOKER_DOT_ALPHA: float = 0.55
const JOKER_SPOT_RATIO: float = 0.05
## Benekler ön rulo yayı boyunca dizilir (ağız elipsinin alt yarısı, uçlarda biraz içeride).
const JOKER_ARC_FROM_DEGREES: float = 155.0
const JOKER_ARC_TO_DEGREES: float = 25.0
## Benekler rulonun sırtında dursun: ağız çizgisinden biraz yukarı.
const JOKER_LIFT_RATIO: float = 0.03

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
		if _pile_holder != null:
			_pile_holder.scale = Vector2.ONE / scale
	queue_redraw()


## Joker (rengini almamış): bant beyaz, ön rulonun üstünde gökkuşağı benekleri.
func set_joker(is_joker: bool) -> void:
	joker = is_joker
	_joker_fixed = false
	if is_joker and _rainbow == null and _rim != null:
		_rainbow = JokerRainbow.new()
		_rainbow.radius = size * JOKER_SPOT_RATIO
		_rainbow.half_width = size * RIM_HALF_U
		_rainbow.half_height = size * RIM_HALF_H_RATIO
		_rainbow.from_angle = deg_to_rad(JOKER_ARC_FROM_DEGREES)
		_rainbow.to_angle = deg_to_rad(JOKER_ARC_TO_DEGREES)
		_rainbow.position = Vector2(0.0, -size * JOKER_LIFT_RATIO)
		_rainbow.z_index = FRONT_Z + 2
		_rim.add_child(_rainbow)
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


## Gökkuşağı benekleri: ön rulo yayı (ağız elipsinin ön yarısı) boyunca altı yumuşak daire.
## Düğüm `_rim` içinde, elipsin merkezinde durur: astar sallanınca benekler de onunla esner.
class JokerRainbow extends Node2D:
	var radius: float = 12.0
	var half_width: float = 90.0
	var half_height: float = 50.0
	var from_angle: float = PI
	var to_angle: float = 0.0

	func _draw() -> void:
		var count: int = BasketView.JOKER_TINTS.size()
		for index: int in range(count):
			var angle: float = lerpf(from_angle, to_angle, float(index) / float(count - 1))
			var at: Vector2 = Vector2(cos(angle) * half_width, sin(angle) * half_height)
			# Önde (ekrana yakın) benek biraz daha iri: perspektif derinlik ipucu.
			var near: float = 0.85 + 0.15 * sin(angle)
			draw_circle(at, radius * near, Color(0.0, 0.0, 0.0, 0.12), true, -1.0, true)
			draw_circle(at - Vector2(0.0, radius * 0.12), radius * near, BasketView.JOKER_TINTS[index], true, -1.0, true)
