class_name CatView
extends Node2D

## Çamaşırhane kedisi: sepetin üstüne kıvrılıp uyur (sepet o sürede bir şey almaz); dokununca
## (ücretsiz) uyanır, kalpler uçuşur ve atlayıp gider. Bir hamle önce gelir haberi: hedef sepetin
## önünde yumuşak nabız atan kedi silüeti. Kural `LaundryBoard`'dadır; bu sınıf yalnız gösterir.
## Tek düğüm seviye boyunca yeniden kullanılır; uyurken sepeti izler (kare başına konum kopyası).

const SLEEP_PATH: String = "res://assets/sprites/critters/cat_sleep.png"
const AWAKE_PATH: String = "res://assets/sprites/critters/cat_awake.png"
const HINT_PATH: String = "res://assets/sprites/critters/icon_cat.png"
## Uyuyan kedi sepet genişliğinin bu oranında, sepet ağzının biraz üstünde yatar.
const SLEEP_WIDTH_RATIO: float = 0.86
const SLEEP_Y_RATIO: float = -0.2
const AWAKE_HEIGHT_RATIO: float = 0.62
const Z_INDEX: int = 80
const HINT_ALPHA: float = 0.55
const HINT_RATIO: float = 0.3
const HINT_Y_RATIO: float = 0.1
const HINT_PULSE: float = 1.12
const HINT_SECONDS: float = 0.55
const HINT_DISC: Color = Color(1.0, 1.0, 1.0, 0.75)
const HINT_INK: Color = Color("c98a55")
const JUMP_FROM: Vector2 = Vector2(-220.0, 60.0)
const JUMP_HEIGHT: float = 120.0
const JUMP_SECONDS: float = 0.5
const LEAVE_SECONDS: float = 0.45
const BREATH_SPEED: float = 1.6
const BREATH_AMOUNT: float = 0.025
const HEART_COLOR: Color = Color("f7a8b8")
const HEART_COUNT: int = 6
const HIT_RATIO: float = 0.5

var basket_index: int = LaundryBoard.EMPTY
var _sleep: Sprite2D = null
var _awake: Sprite2D = null
var _hint: Node2D = null
var _hint_tween: Tween = null
var _basket: BasketView = null
var _motion: Tween = null
var _time: float = 0.0
var _hearts: CPUParticles2D = null
var _basket_size: float = 250.0


func setup(basket_size: float) -> void:
	_basket_size = basket_size
	z_index = Z_INDEX
	var sleep_texture: Texture2D = load(SLEEP_PATH) as Texture2D
	_sleep = Sprite2D.new()
	_sleep.texture = sleep_texture
	_sleep.scale = Vector2.ONE * (basket_size * SLEEP_WIDTH_RATIO / sleep_texture.get_size().x)
	add_child(_sleep)
	var awake_texture: Texture2D = load(AWAKE_PATH) as Texture2D
	_awake = Sprite2D.new()
	_awake.texture = awake_texture
	_awake.scale = Vector2.ONE * (basket_size * AWAKE_HEIGHT_RATIO / awake_texture.get_size().y)
	_awake.visible = false
	add_child(_awake)
	_hearts = CPUParticles2D.new()
	_hearts.one_shot = true
	_hearts.emitting = false
	_hearts.explosiveness = 0.85
	_hearts.amount = HEART_COUNT
	_hearts.lifetime = 0.9
	_hearts.texture = GarmentView.circle_texture()
	_hearts.scale_amount_min = 0.08
	_hearts.scale_amount_max = 0.14
	_hearts.direction = Vector2.UP
	_hearts.spread = 50.0
	_hearts.gravity = Vector2(0.0, -40.0)
	_hearts.initial_velocity_min = 80.0
	_hearts.initial_velocity_max = 160.0
	_hearts.color = HEART_COLOR
	add_child(_hearts)
	visible = false
	set_process(false)


## Hint düğümü sahne kökünde durur (kedi görünmezken de görünür): oyun ekler.
func make_hint() -> Node2D:
	_hint = Node2D.new()
	_hint.z_index = Z_INDEX
	_hint.visible = false
	var disc: Sprite2D = Sprite2D.new()
	disc.texture = GarmentView.circle_texture()
	disc.modulate = HINT_DISC
	disc.scale = Vector2.ONE * (_basket_size * HINT_RATIO / float(GarmentView.CIRCLE_TEXTURE_SIZE))
	_hint.add_child(disc)
	if ResourceLoader.exists(HINT_PATH):
		var icon: Sprite2D = Sprite2D.new()
		icon.texture = load(HINT_PATH) as Texture2D
		icon.modulate = HINT_INK
		icon.scale = Vector2.ONE * (_basket_size * HINT_RATIO * 0.7 / icon.texture.get_size().x)
		_hint.add_child(icon)
	return _hint


## Bir hamle sonra kedi bu sepete yatacak: sepetin önünde nabız atan silüet.
func show_hint(basket: BasketView) -> void:
	if _hint == null or basket == null:
		return
	_hint.position = basket.rest_position + Vector2(0.0, _basket_size * HINT_Y_RATIO)
	if _hint.visible:
		return
	_hint.visible = true
	_hint.modulate.a = HINT_ALPHA
	_hint.scale = Vector2.ONE
	if _hint_tween != null:
		_hint_tween.kill()
	_hint_tween = _hint.create_tween().set_loops()
	_hint_tween.tween_property(_hint, "scale", Vector2.ONE * HINT_PULSE, HINT_SECONDS).set_trans(Tween.TRANS_SINE)
	_hint_tween.tween_property(_hint, "scale", Vector2.ONE, HINT_SECONDS).set_trans(Tween.TRANS_SINE)


func hide_hint() -> void:
	if _hint == null:
		return
	_hint.visible = false
	if _hint_tween != null:
		_hint_tween.kill()
		_hint_tween = null


## Yandan zıplayıp sepetin üstüne kıvrılır.
func land_in(basket: BasketView, index: int) -> void:
	hide_hint()
	_basket = basket
	basket_index = index
	_kill_motion()
	visible = true
	modulate.a = 1.0
	_sleep.visible = true
	_awake.visible = false
	var home: Vector2 = _home()
	var from: Vector2 = home + JUMP_FROM
	position = from
	_motion = create_tween()
	_motion.tween_method(func(weight: float) -> void:
		position = from.lerp(_home(), weight) + Vector2(0.0, -JUMP_HEIGHT * sin(PI * weight)), 0.0, 1.0, JUMP_SECONDS)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	set_process(true)


## Sevildi: uyanır, kalpler uçuşur, sonra atlayıp gider. `petted` false: kendiliğinden kalktı.
func wake_and_leave(petted: bool) -> void:
	if not visible:
		return
	basket_index = LaundryBoard.EMPTY
	_kill_motion()
	_sleep.visible = false
	_awake.visible = true
	if petted:
		_hearts.restart()
		_hearts.emitting = true
	var from: Vector2 = position
	_motion = create_tween()
	_motion.tween_interval(LEAVE_SECONDS * 0.6 if petted else 0.1)
	_motion.tween_method(func(weight: float) -> void:
		position = from.lerp(from - JUMP_FROM, weight) + Vector2(0.0, -JUMP_HEIGHT * sin(PI * weight)), 0.0, 1.0, LEAVE_SECONDS)
	_motion.parallel().tween_property(self, "modulate:a", 0.0, LEAVE_SECONDS)
	_motion.tween_callback(_gone)


func _gone() -> void:
	visible = false
	_basket = null
	set_process(false)


func _kill_motion() -> void:
	if _motion != null:
		_motion.kill()
		_motion = null


func _home() -> Vector2:
	if _basket == null or not is_instance_valid(_basket):
		return position
	return _basket.position + Vector2(0.0, _basket_size * SLEEP_Y_RATIO)


func hit(point: Vector2, min_touch: float) -> bool:
	if not visible or basket_index == LaundryBoard.EMPTY:
		return false
	return position.distance_to(point) <= maxf(_basket_size * HIT_RATIO, min_touch * 0.5)


## Uyurken sepeti izler ve yavaşça nefes alır.
func _process(delta: float) -> void:
	_time += delta
	if basket_index != LaundryBoard.EMPTY and (_motion == null or not _motion.is_running()):
		position = _home()
	var breath: float = BREATH_AMOUNT * sin(_time * BREATH_SPEED)
	_sleep.scale.y = _sleep.scale.x * (1.0 + breath)
