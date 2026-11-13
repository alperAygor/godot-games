class_name BirdView
extends Node2D

## Tombul kuş: gökten süzülüp hedef çamaşırın omzuna konar, orada hafifçe zıplar; dokununca
## kanat çırpıp uçar (ücretsiz). Kural `LaundryBoard`'dadır (kuş sayaçları); bu sınıf yalnız
## gösterir. Tek kuş düğümü seviye boyunca yeniden kullanılır. Konmuşken çamaşırı izler
## (sallanma/kayma); kare başına yalnız konum kopyalanır.

const IDLE_PATH: String = "res://assets/sprites/critters/bird_idle.png"
const FLAP_PATH: String = "res://assets/sprites/critters/bird_flap.png"
## Kuş boyu (çamaşır boyuna oran) ve çamaşırın üst kenarına göre oturma noktası.
const SIZE_RATIO: float = 0.85
const PERCH_Y_RATIO: float = -0.02
const Z_INDEX: int = 75
const ARRIVE_FROM: Vector2 = Vector2(260.0, -420.0)
const LEAVE_TO: Vector2 = Vector2(-320.0, -520.0)
const ARRIVE_SECONDS: float = 0.55
const LEAVE_SECONDS: float = 0.5
const FLAP_FRAME_SECONDS: float = 0.08
const HOP_HEIGHT: float = 10.0
const HOP_SECONDS: float = 0.12
const WORRY_TILT: float = 8.0
const HIT_RATIO: float = 0.75
const FEATHER_COLOR: Color = Color(1.0, 1.0, 1.0, 0.8)
const FEATHER_COUNT: int = 8
## Bir hamle önceki haber: konacağı yerde yumuşak gölge + soluk kuş silüeti (her şeyin üstünde).
const HINT_PATH: String = "res://assets/sprites/critters/icon_bird.png"
const HINT_INK: Color = Color(0.16, 0.22, 0.36, 0.42)
const HINT_SHADOW: Color = Color(0.1, 0.14, 0.24, 0.3)
const HINT_PULSE: float = 1.12
const HINT_SECONDS: float = 0.55

var perched: int = LaundryBoard.EMPTY
var _sprite: Sprite2D = null
var _idle: Texture2D = null
var _flap: Texture2D = null
var _target: GarmentView = null
var _offset: Vector2 = Vector2.ZERO
var _flight: Tween = null
var _flap_time: float = 0.0
var _flapping: bool = false
var _size: float = 100.0
var _feathers: CPUParticles2D = null
var _hint: Node2D = null
var _hint_tween: Tween = null
var _hint_target: GarmentView = null


func setup(garment_size: float) -> void:
	_idle = load(IDLE_PATH) as Texture2D
	_flap = load(FLAP_PATH) as Texture2D
	_size = garment_size * SIZE_RATIO
	_sprite = Sprite2D.new()
	_sprite.texture = _idle
	_sprite.scale = Vector2.ONE * (_size / _idle.get_size().x)
	# Ayaklar tuvalin altına yakın: oturma noktası ayak hizası olsun.
	_sprite.offset = Vector2(0.0, -_idle.get_size().y * 0.36)
	add_child(_sprite)
	z_index = Z_INDEX
	visible = false
	_feathers = CPUParticles2D.new()
	_feathers.one_shot = true
	_feathers.emitting = false
	_feathers.explosiveness = 0.9
	_feathers.amount = FEATHER_COUNT
	_feathers.lifetime = 0.7
	_feathers.texture = GarmentView.circle_texture()
	_feathers.scale_amount_min = 0.05
	_feathers.scale_amount_max = 0.09
	_feathers.spread = 180.0
	_feathers.gravity = Vector2(0.0, 160.0)
	_feathers.initial_velocity_min = 60.0
	_feathers.initial_velocity_max = 140.0
	_feathers.color = FEATHER_COLOR
	add_child(_feathers)
	set_process(false)


## Ayrı düğüm (kuş görünmezken de görünür): oyun dünyaya ekler.
func make_hint() -> Node2D:
	_hint = Node2D.new()
	_hint.z_index = Z_INDEX
	_hint.visible = false
	var shadow: Sprite2D = Sprite2D.new()
	shadow.texture = GarmentView.circle_texture()
	shadow.modulate = HINT_SHADOW
	shadow.scale = Vector2(_size * 0.8, _size * 0.22) / float(GarmentView.CIRCLE_TEXTURE_SIZE)
	_hint.add_child(shadow)
	if ResourceLoader.exists(HINT_PATH):
		var ghost: Sprite2D = Sprite2D.new()
		ghost.texture = load(HINT_PATH) as Texture2D
		ghost.modulate = HINT_INK
		ghost.scale = Vector2.ONE * (_size * 0.62 / ghost.texture.get_size().x)
		ghost.position = Vector2(0.0, -_size * 0.3)
		_hint.add_child(ghost)
	return _hint


func show_hint(view: GarmentView) -> void:
	if _hint == null or view == null:
		return
	_hint_target = view
	_hint.position = view.position + Vector2(0.0, view.size * PERCH_Y_RATIO)
	if _hint.visible:
		return
	_hint.visible = true
	_hint.scale = Vector2.ONE
	if _hint_tween != null:
		_hint_tween.kill()
	_hint_tween = _hint.create_tween().set_loops()
	_hint_tween.tween_property(_hint, "scale", Vector2.ONE * HINT_PULSE, HINT_SECONDS).set_trans(Tween.TRANS_SINE)
	_hint_tween.tween_property(_hint, "scale", Vector2.ONE, HINT_SECONDS).set_trans(Tween.TRANS_SINE)


func hide_hint() -> void:
	_hint_target = null
	if _hint == null:
		return
	_hint.visible = false
	if _hint_tween != null:
		_hint_tween.kill()
		_hint_tween = null


## Hedef çamaşıra iner (gökten yay çizerek).
func land_on(view: GarmentView, id: int) -> void:
	hide_hint()
	perched = id
	_target = view
	_offset = Vector2(0.0, view.size * PERCH_Y_RATIO)
	var home: Vector2 = view.position + _offset
	_kill_flight()
	visible = true
	modulate.a = 1.0
	rotation_degrees = 0.0
	position = home + ARRIVE_FROM
	_flapping = true
	set_process(true)
	_flight = create_tween()
	_flight.tween_method(_arrive_step.bind(position), 0.0, 1.0, ARRIVE_SECONDS)
	_flight.tween_callback(_settle)


func _arrive_step(weight: float, from: Vector2) -> void:
	if not is_instance_valid(_target):
		return
	var home: Vector2 = _target.position + _offset
	var eased: float = Motion.ease_out(weight)
	position = from.lerp(home, eased) + Vector2(0.0, -40.0 * sin(PI * weight))


func _settle() -> void:
	_flapping = false
	_sprite.texture = _idle
	hop()


## Kalan hamle azaldı: küçük zıplama; son hamlede başını eğer (uyarı).
func hop(worried: bool = false) -> void:
	var tween: Tween = _sprite.create_tween()
	var base: Vector2 = _sprite.position
	tween.tween_property(_sprite, "position:y", base.y - HOP_HEIGHT, HOP_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_sprite, "position:y", base.y, HOP_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_sprite.rotation_degrees = WORRY_TILT if worried else 0.0


## Kovalandı / çamaşır alındı / leke bıraktı: kanat çırpıp uçar, birkaç tüy uçuşur.
func fly_off(startled: bool = true) -> void:
	if not visible:
		return
	perched = LaundryBoard.EMPTY
	_target = null
	_kill_flight()
	_flapping = true
	set_process(true)
	if startled:
		_feathers.restart()
		_feathers.emitting = true
	_flight = create_tween().set_parallel(true)
	_flight.tween_property(self, "position", position + LEAVE_TO, LEAVE_SECONDS)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_flight.tween_property(self, "modulate:a", 0.0, LEAVE_SECONDS).set_delay(LEAVE_SECONDS * 0.4)
	_flight.chain().tween_callback(_hide)


## Hedef yoktu: ekrandan geçip gider (konmaz).
func pass_by(over: Vector2) -> void:
	_kill_flight()
	perched = LaundryBoard.EMPTY
	_target = null
	visible = true
	modulate.a = 1.0
	position = over + ARRIVE_FROM
	_flapping = true
	set_process(true)
	_flight = create_tween()
	_flight.tween_property(self, "position", over + LEAVE_TO, ARRIVE_SECONDS + LEAVE_SECONDS)
	_flight.tween_callback(_hide)


func _hide() -> void:
	visible = false
	_flapping = false
	set_process(false)


func _kill_flight() -> void:
	if _flight != null:
		_flight.kill()
		_flight = null


## Dokunma: konmuş kuşun gövdesi (en az MIN_TOUCH çaplı alan).
func hit(point: Vector2, min_touch: float) -> bool:
	if not visible or perched == LaundryBoard.EMPTY:
		return false
	var center: Vector2 = position + Vector2(0.0, -_size * 0.3)
	return center.distance_to(point) <= maxf(_size * HIT_RATIO, min_touch * 0.5)


func _process(delta: float) -> void:
	if _flapping:
		_flap_time += delta
		_sprite.texture = _flap if int(_flap_time / FLAP_FRAME_SECONDS) % 2 == 0 else _idle
	elif perched != LaundryBoard.EMPTY and is_instance_valid(_target) and (_flight == null or not _flight.is_running()):
		position = _target.position + _offset
