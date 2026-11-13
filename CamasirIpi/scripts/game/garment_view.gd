class_name GarmentView
extends Node2D

## Tek çamaşırın görünümü. Konum = ipe tutunduğu üst-orta nokta. Blender'da üretilen
## nötr beyaz sprite (assets/sprites/garment_*.png) oyun rengiyle çarpılır; sprite yoksa
## yumuşak köşeli basit bir şekil çizilir (yedek).
## Durumlar: kapalı (soluk), ıslak (koyu + damla), gizemli (renk gizli, "?"),
## kilitli (anahtar renginde rozet). Derinleşme 4 (dosya sonu): çift renk (çapraz bölünmüş iki renk),
## güneş rozeti/solma, yaprak, don, polen tozu. İpteyken kumaş gibi sallanır (cloth_sway shader'ı);
## tüm uçuş/katlama/iniş hareketi `fly_to` içinde tek bir Tween ile sürülür.

const KINDS: Array[String] = ["tshirt", "pants", "dress", "towel", "shorts", "sweater", "sock"]
const SPRITE_PATH: String = "res://assets/sprites/garment_%s.png"
const FOLDED_PATH: String = "res://assets/sprites/folded.png"
const PIN_PATH: String = "res://assets/sprites/pin.png"
const CLOSED_GRAY: Color = Color(0.55, 0.57, 0.62)
const CLOSED_MIX: float = 0.62
const CLOSED_DARKEN: float = 0.1
const MYSTERY_COLOR: Color = Color(0.72, 0.7, 0.8)
const WET_DARKEN: float = 0.3
const DROP_COLOR: Color = Color(0.55, 0.78, 1.0, 0.9)
const SHADOW_COLOR: Color = Color(0.1, 0.15, 0.25, 0.16)
const SHADOW_OFFSET: Vector2 = Vector2(7.0, 11.0)
## Sprite tuvalinin tamamı dolu değildir; görünen çamaşır hedef boyuta yaklaşsın diye büyütülür.
const SPRITE_FILL: float = 1.14
const SWAY_SHADER_PATH: String = "res://assets/shaders/cloth_sway.gdshader"
const SWAY_SPEED_BASE: float = 1.1
const SWAY_SPEED_SPREAD: float = 0.3
const PHASE_PER_ID: float = 1.37
const SPEED_HASH: float = 0.37
const PIN_Z: int = 55
const P_PHASE: StringName = &"phase"
const P_SPEED: StringName = &"speed"
const P_STRENGTH: StringName = &"strength"
const P_KICK: StringName = &"kick"
const P_SILHOUETTE: StringName = &"silhouette"
const KICK_LIMIT: float = 1.2
const FOLDED_SHADOW_RATIO: float = 0.6
const WOBBLE_DEGREES: float = 7.0
const WOBBLE_SECONDS: float = 0.09
const FLASH_SECONDS: float = 0.16
const PIN_COLOR: Color = Color("c99a5b")
const CIRCLE_TEXTURE_SIZE: int = 128

## Çamaşır bir sepete/askıya oturduğu an (iniş başlangıcı) yayılır.
signal landed

var item_id: int = -1
## Ait olduğu ip (komşu itmesi için aynı ipteki çamaşırlar aranır).
var line: int = 0
var color: Color = Color.WHITE
var size: float = 200.0
var layer: int = 0

var _open: bool = true
var _wet: bool = false
var _mystery: bool = false
var _lock_color: Color = Color.TRANSPARENT
var _locked: bool = false
var _phase: float = 0.0
var _sprite: Sprite2D = null
var _shadow: Sprite2D = null
var _folded_sprite: Sprite2D = null
var _folded_shadow: Sprite2D = null
var _material: ShaderMaterial = null
var _shadow_material: ShaderMaterial = null
var _sway_strength: float = Motion.SWAY_CALM
var _kick_amp: float = 0.0
var _kick_age: float = 0.0
var _base_scale: Vector2 = Vector2.ONE
var _base_pos: Vector2 = Vector2.ZERO
var _shadow_base_pos: Vector2 = Vector2.ZERO
var _folded_factor: float = 1.0
var _flight_tween: Tween = null
var _fly_start: Vector2 = Vector2.ZERO
var _fly_target: Vector2 = Vector2.ZERO
var _fly_from_scale: Vector2 = Vector2.ONE
var _fly_scale: float = 1.0
var _fly_rotation: float = 0.0
var _fly_arc: float = 0.0
var _fly_anticipate: float = 0.0
var _fly_total: float = 1.0
var _fly_fold: bool = false
var _last_pos: Vector2 = Vector2.ZERO
var _lag: float = 0.0
var _pins: Array[Sprite2D] = []
var _question: Label = null
var _drops: CPUParticles2D = null
var _box: StyleBoxFlat = StyleBoxFlat.new()
var _tween: Tween = null
var _show_pins: bool = true
var _folded: bool = false
var _badge: Node2D = null
static var _circle: Texture2D = null
static var _shader: Shader = null


func setup(id: int, tint: Color, pixel_size: float, kind: int, item_layer: int) -> void:
	item_id = id
	color = tint
	size = pixel_size
	layer = item_layer
	z_index = item_layer
	_phase = float(id) * PHASE_PER_ID
	_kind = posmod(kind, KINDS.size())
	# Sallanma yalnız komşu itmesi/uçuş kick'i sürerken işlenir; boşta CPU harcanmaz.
	set_process(false)
	var path: String = SPRITE_PATH % KINDS[posmod(kind, KINDS.size())]
	if ResourceLoader.exists(path):
		var texture: Texture2D = load(path) as Texture2D
		_shadow = _make_sprite(texture)
		_shadow.modulate = SHADOW_COLOR
		_shadow.position += SHADOW_OFFSET
		_shadow_material = _cloth_material(true)
		_shadow.material = _shadow_material
		_sprite = _make_sprite(texture)
		_material = _cloth_material(false)
		_sprite.material = _material
		_base_scale = _sprite.scale
		_base_pos = _sprite.position
		_shadow_base_pos = _shadow.position
		if ResourceLoader.exists(PIN_PATH):
			for side: float in [-0.2, 0.2]:
				var pin: Sprite2D = Sprite2D.new()
				pin.texture = load(PIN_PATH) as Texture2D
				var pin_factor: float = size * 0.24 / pin.texture.get_size().y
				pin.scale = Vector2.ONE * pin_factor
				pin.position = Vector2(size * side, size * 0.01)
				add_child(pin)
				_pins.append(pin)
	_box.set_corner_radius_all(int(size * 0.16))
	_box.anti_aliasing = true
	_box.anti_aliasing_size = 1.5
	_apply_color()


func _make_sprite(texture: Texture2D) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	var texture_size: Vector2 = texture.get_size()
	var factor: float = size * SPRITE_FILL / maxf(texture_size.x, texture_size.y)
	sprite.scale = Vector2.ONE * factor
	# Sprite'ta ipe değen üst kenar tuvalin ~%10 altındadır; o çizgi yerel y=0'a oturur.
	sprite.position = Vector2(-texture_size.x * factor * 0.5, -texture_size.y * factor * 0.1)
	add_child(sprite)
	return sprite


## Kumaş sallanma materyali. Neden çamaşır başına ayrı materyal: faz/hız her çamaşırda
## farklı olmalı (hepsi aynı anda sallanırsa ölü ve mekanik görünür). Gölge aynı shader'ı
## `silhouette` ile kullanır; böylece gölge de çamaşırla birlikte aynı şekilde bükülür.
func _cloth_material(silhouette: bool) -> ShaderMaterial:
	if _shader == null:
		_shader = load(SWAY_SHADER_PATH) as Shader
	if _shader == null:
		return null
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = _shader
	material.set_shader_parameter(P_PHASE, _phase)
	material.set_shader_parameter(P_SPEED, SWAY_SPEED_BASE + fposmod(float(item_id) * SPEED_HASH, 1.0) * SWAY_SPEED_SPREAD)
	material.set_shader_parameter(P_SILHOUETTE, silhouette)
	return material


func _set_param(param: StringName, value: float) -> void:
	if _material != null:
		_material.set_shader_parameter(param, value)
	if _shadow_material != null:
		_shadow_material.set_shader_parameter(param, value)


## Oyun fırtına arttıkça sallanma çarpanını yükseltir.
func set_sway_strength(value: float) -> void:
	_sway_strength = value
	_set_param(P_STRENGTH, value)


## Aynı ipteki komşu alınınca kumaşa yumuşak, sönümlenen bir itme (işaretli).
func nudge(amount: float) -> void:
	_kick_amp = clampf(_kick_amp + amount, -KICK_LIMIT, KICK_LIMIT)
	_kick_age = 0.0
	set_process(true)


func _process(delta: float) -> void:
	_kick_age += delta
	_kick_amp *= exp(-Motion.NEIGHBOUR_DECAY * delta)
	if absf(_kick_amp) < Motion.NEIGHBOUR_EPSILON:
		_kick_amp = 0.0
		_set_param(P_KICK, 0.0)
		set_process(false)
		return
	_set_param(P_KICK, _kick_amp * cos(Motion.NEIGHBOUR_FREQUENCY * _kick_age))


func set_open(open: bool) -> void:
	if open == _open:
		return
	_open = open
	_apply_color()
	if open and _mystery:
		_reveal()


func is_open() -> bool:
	return _open


func set_wet(wet: bool) -> void:
	_wet = wet
	if wet and _drops == null:
		_drops = CPUParticles2D.new()
		_drops.amount = 5
		_drops.lifetime = 0.9
		_drops.position = Vector2(0.0, size * 0.9)
		_drops.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		_drops.emission_rect_extents = Vector2(size * 0.3, 2.0)
		_drops.direction = Vector2.DOWN
		_drops.spread = 4.0
		_drops.gravity = Vector2(0.0, 520.0)
		_drops.initial_velocity_min = 10.0
		_drops.initial_velocity_max = 30.0
		_drops.scale_amount_min = 4.0
		_drops.scale_amount_max = 7.0
		_drops.color = DROP_COLOR
		add_child(_drops)
	elif not wet and _drops != null:
		_drops.emitting = false
	_apply_color()


## Islak çamaşır sıkılır: yandan ezilir, damlalar saçılır, rengi açılır.
func wring() -> void:
	set_wet(false)
	_restart_tween()
	_tween.tween_property(self, "scale", Vector2(0.72, 1.08), 0.11)
	_tween.tween_property(self, "scale", Vector2(1.06, 0.97), 0.1)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.1)
	var splash: CPUParticles2D = CPUParticles2D.new()
	splash.one_shot = true
	splash.explosiveness = 0.9
	splash.amount = 14
	splash.lifetime = 0.5
	splash.position = Vector2(0.0, size * 0.75)
	splash.direction = Vector2.DOWN
	splash.spread = 70.0
	splash.gravity = Vector2(0.0, 900.0)
	splash.initial_velocity_min = 120.0
	splash.initial_velocity_max = 260.0
	splash.scale_amount_min = 4.0
	splash.scale_amount_max = 8.0
	splash.color = DROP_COLOR
	add_child(splash)
	splash.emitting = true
	# Tek atımlık sıçrama bitince silinir: eskiden her sıkmada bir yayıcı düğüm çamaşırda kalıyordu.
	splash.finished.connect(splash.queue_free)


func set_mystery(mystery: bool) -> void:
	_mystery = mystery
	if mystery and _question == null:
		_question = Label.new()
		_question.text = "?"
		_question.add_theme_font_size_override("font_size", int(size * 0.42))
		_question.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95))
		_question.position = Vector2(-size * 0.11, size * 0.18)
		add_child(_question)
	_apply_color()


func _reveal() -> void:
	_mystery = false
	if _question != null:
		_question.queue_free()
		_question = null
	_apply_color()
	_restart_tween()
	_tween.tween_property(self, "scale", Vector2.ONE * 1.14, 0.1)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.14)


## Kilit rozeti: beyaz halka içinde anahtar sepetin rengi (o sepet tamamlanınca açılır).
## Çocuk düğüm olarak eklenir ki sprite'ın ÜSTÜNDE çizilsin.
func set_lock(key_color: Color) -> void:
	_lock_color = key_color
	_locked = true
	_badge = Node2D.new()
	_badge.position = Vector2(0.0, size * 0.45)
	add_child(_badge)
	for spec: Array in [[0.36, Color(1.0, 1.0, 1.0, 0.96)], [0.26, key_color]]:
		var dot: Sprite2D = Sprite2D.new()
		dot.texture = circle_texture()
		dot.scale = Vector2.ONE * (size * float(spec[0]) / float(CIRCLE_TEXTURE_SIZE))
		dot.modulate = spec[1] as Color
		_badge.add_child(dot)


func unlock() -> void:
	_locked = false
	if _badge != null:
		var gone: Tween = _badge.create_tween()
		gone.tween_property(_badge, "scale", Vector2.ONE * 1.5, 0.12)
		gone.parallel().tween_property(_badge, "modulate:a", 0.0, 0.18)
		gone.tween_callback(_badge.queue_free)
		_badge = null
	_restart_tween()
	_tween.tween_property(self, "scale", Vector2.ONE * 1.12, 0.1)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.14)


## Kenarı yumuşatılmış dolu daire dokusu (rozet/parıltı için ortak, bir kez üretilir).
static func circle_texture() -> Texture2D:
	if _circle == null:
		var gradient: Gradient = Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.93, 1.0])
		gradient.colors = PackedColorArray([Color.WHITE, Color.WHITE, Color(1.0, 1.0, 1.0, 0.0)])
		var texture: GradientTexture2D = GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
		texture.width = CIRCLE_TEXTURE_SIZE
		texture.height = CIRCLE_TEXTURE_SIZE
		_circle = texture
	return _circle


## Mandal kaplaması: tüm mandalların dokusunu değiştirir (boyut/çapa aynı kalır, kaplamalar
## `assets/sprites/pin.png` ile aynı ölçüdedir). Düşen mandal animasyonu da bu dokuyu kullanır.
func set_pin_texture(texture: Texture2D) -> void:
	for pin: Sprite2D in _pins:
		pin.texture = texture


## Mandallar küçük ayrı sprite olarak fırlar, düşer ve solar (asıl mandallar gizlenir).
func release_pins() -> void:
	if not _show_pins:
		return
	_show_pins = false
	if _drops != null:
		_drops.emitting = false
	var host: Node = get_parent()
	for pin: Sprite2D in _pins:
		if host != null and pin.visible and pin.texture != null:
			_spawn_falling_pin(host, pin)
		pin.visible = false
	queue_redraw()


func _spawn_falling_pin(host: Node, pin: Sprite2D) -> void:
	var fall: Sprite2D = Sprite2D.new()
	fall.texture = pin.texture
	fall.scale = pin.scale * scale
	fall.z_index = PIN_Z
	host.add_child(fall)
	fall.global_position = pin.global_position
	fall.rotation = pin.global_rotation
	var origin: Vector2 = fall.position
	var dir: float = -1.0 if pin.position.x < 0.0 else 1.0
	var spin: float = deg_to_rad(Motion.PIN_SPIN_DEGREES) * dir
	var total: float = Motion.PIN_POP_SECONDS + Motion.PIN_FALL_SECONDS
	var tween: Tween = fall.create_tween().set_parallel(true)
	tween.tween_property(fall, "position", origin + Vector2(dir * 8.0, -Motion.PIN_POP_HEIGHT), Motion.PIN_POP_SECONDS)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(fall, "position", origin + Vector2(dir * 46.0, Motion.PIN_FALL_DISTANCE), Motion.PIN_FALL_SECONDS)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).set_delay(Motion.PIN_POP_SECONDS)
	tween.tween_property(fall, "rotation", fall.rotation + spin, total)
	tween.tween_property(fall, "modulate:a", 0.0, Motion.PIN_FALL_SECONDS * 0.8)\
		.set_delay(Motion.PIN_POP_SECONDS + Motion.PIN_FALL_SECONDS * 0.2)
	tween.chain().tween_callback(fall.queue_free)


## Hedefe zarif yay çizerek uçar: hazırlık (kalkış/çekiliş) -> yay -> iniş. `folded_width` > 0
## ise uçuşun ortasında iki adımda katlanır (yanlar içeri, sonra alt yukarı) ve yığın parçası olur.
## Tek Tween tek `tween_method` sürer: kare başına yeni nesne yok, çamaşır silinince Tween de ölür.
func fly_to(target: Vector2, target_scale: float, folded_width: float, final_rotation_deg: float) -> void:
	release_pins()
	_leave_season_state()
	if _tween != null:
		_tween.kill()
	if _flight_tween != null:
		_flight_tween.kill()
	_kick_amp = 0.0
	set_process(false)
	_set_param(P_KICK, 0.0)
	rotation_degrees = 0.0
	_fly_start = global_position
	_fly_target = target
	_fly_from_scale = scale
	_fly_scale = target_scale
	_fly_rotation = final_rotation_deg
	_fly_arc = Motion.arc_height(_fly_start.distance_to(target))
	# Askıdan sepete giden parça zaten mandalsızdır; kısa bir hazırlık yeter.
	_fly_anticipate = Motion.ANTICIPATE_SECONDS
	_fly_fold = folded_width > 0.0 and _sprite != null and ResourceLoader.exists(FOLDED_PATH)
	if _fly_fold:
		_prepare_fold(folded_width)
	_fly_total = _fly_anticipate + Motion.FLIGHT_SECONDS
	_begin_sheet_shrink()
	_last_pos = _fly_start
	_lag = 0.0
	_flight_tween = create_tween()
	_flight_tween.tween_method(_fly_step, 0.0, 1.0, _fly_total)
	_flight_tween.tween_callback(_land)


func _fly_step(progress: float) -> void:
	var elapsed: float = progress * _fly_total
	if elapsed < _fly_anticipate:
		# Hazırlık: çamaşır yukarı çekilir, hafif uzar; sallanma sönümlenir.
		var a: float = Motion.ease_out(elapsed / _fly_anticipate)
		global_position = _fly_start + Vector2(0.0, -Motion.ANTICIPATE_LIFT * a)
		scale = Vector2(_fly_from_scale.x * (1.0 - Motion.ANTICIPATE_STRETCH * 0.4),
			_fly_from_scale.y * (1.0 + Motion.ANTICIPATE_STRETCH)).lerp(_fly_from_scale, 1.0 - a)
		_set_param(P_STRENGTH, _sway_strength * (1.0 - a))
		return
	_set_param(P_STRENGTH, 0.0)
	var weight: float = (elapsed - _fly_anticipate) / Motion.FLIGHT_SECONDS
	_sheet_shrink_step(weight)
	var eased: float = Motion.ease_in_out(weight)
	var lifted: Vector2 = _fly_start + Vector2(0.0, -Motion.ANTICIPATE_LIFT)
	var pos: Vector2 = lifted.lerp(_fly_target, eased) + Vector2(0.0, -_fly_arc * sin(PI * eased))
	global_position = pos
	var bump: float = 1.0 + Motion.FLIGHT_SCALE_BUMP * sin(PI * eased)
	var start_x: float = _fly_from_scale.x * (1.0 - Motion.ANTICIPATE_STRETCH * 0.4)
	var start_y: float = _fly_from_scale.y * (1.0 + Motion.ANTICIPATE_STRETCH)
	scale = Vector2(lerpf(start_x, _fly_scale, eased), lerpf(start_y, _fly_scale, eased)) * bump
	# Yöne doğru yatma + geride kalan kumaş: yatay hızın yumuşatılmış hali sürer.
	var dt: float = get_process_delta_time()
	if dt > 0.0:
		var speed_x: float = (pos.x - _last_pos.x) / dt
		_lag = lerpf(_lag, speed_x, 1.0 - exp(-Motion.FLIGHT_LAG_RATE * dt))
	_last_pos = pos
	var lean: float = clampf(_lag * Motion.FLIGHT_LEAN_DEGREES_PER_SPEED,
		-Motion.FLIGHT_LEAN_MAX_DEGREES, Motion.FLIGHT_LEAN_MAX_DEGREES)
	rotation_degrees = lean + _fly_rotation * eased
	_set_param(P_KICK, clampf(-_lag * Motion.FLIGHT_KICK_PER_SPEED, -Motion.FLIGHT_KICK_MAX, Motion.FLIGHT_KICK_MAX))
	if _fly_fold:
		_fold_step(clampf((weight - Motion.FOLD_START) / (Motion.FOLD_END - Motion.FOLD_START), 0.0, 1.0))


## Katlanmış görünüm için ikinci sprite çifti (çapraz solma ile geçilir; doku "pop" etmez).
func _prepare_fold(width: float) -> void:
	if _folded_sprite != null:
		return
	var texture: Texture2D = load(FOLDED_PATH) as Texture2D
	_folded_factor = width / texture.get_size().x
	_folded_shadow = Sprite2D.new()
	_folded_shadow.texture = texture
	_folded_shadow.modulate = Color(SHADOW_COLOR.r, SHADOW_COLOR.g, SHADOW_COLOR.b, 0.0)
	_folded_shadow.position = SHADOW_OFFSET * FOLDED_SHADOW_RATIO
	var silhouette: ShaderMaterial = _cloth_material(true)
	silhouette.set_shader_parameter(P_STRENGTH, 0.0)
	_folded_shadow.material = silhouette
	add_child(_folded_shadow)
	move_child(_folded_shadow, 0)
	_folded_sprite = Sprite2D.new()
	_folded_sprite.texture = texture
	_folded_sprite.modulate = Color(_sprite.modulate.r, _sprite.modulate.g, _sprite.modulate.b, 0.0)
	add_child(_folded_sprite)
	_pin_children_on_top()


## Katlanmış sprite çamaşırın üstünde, rozet/soru işareti ise onun da üstünde kalsın.
func _pin_children_on_top() -> void:
	for extra: Node in [_dual_mask, _question, _badge]:
		if extra != null:
			move_child(extra, get_child_count() - 1)


## f: 0..1. Önce yanlar içeri (dar + hafif uzun), sonra alt yukarı (kısa); eksen ağırlık
## merkezinden kat merkezine kayar. Son kısımda katlı sprite'a çapraz solma.
func _fold_step(f: float) -> void:
	var sides: float = Motion.ease_in_out(f / Motion.FOLD_SIDES_SHARE)
	var bottom: float = Motion.ease_in_out((f - Motion.FOLD_SIDES_SHARE) / (1.0 - Motion.FOLD_SIDES_SHARE))
	var mx: float = lerpf(1.0, Motion.FOLD_SIDES_SCALE_X, sides)
	var my: float = lerpf(lerpf(1.0, Motion.FOLD_SIDES_SCALE_Y, sides), Motion.FOLD_BOTTOM_SCALE_Y, bottom)
	var center: float = size * Motion.FOLD_CENTER_RATIO
	var pivot: float = lerpf(center, 0.0, bottom)
	_fold_pose(_sprite, _base_pos, mx, my, center, pivot)
	_fold_pose(_shadow, _shadow_base_pos, mx, my, center, pivot)
	var fade: float = Motion.smooth((bottom - Motion.FOLD_CROSSFADE_FROM) / (1.0 - Motion.FOLD_CROSSFADE_FROM))
	_sprite.modulate.a = 1.0 - fade
	_shadow.modulate.a = SHADOW_COLOR.a * (1.0 - fade)
	_folded_sprite.modulate.a = fade
	_folded_shadow.modulate.a = SHADOW_COLOR.a * fade
	var pop: float = lerpf(Motion.FOLDED_POP_FROM, 1.0, fade)
	_folded_sprite.scale = Vector2(_folded_factor, _folded_factor * pop)
	_folded_shadow.scale = _folded_sprite.scale


## Sprite'ı (mx,my) ile `center` ekseni çevresinde ölçekler ve ekseni `pivot`a taşır.
func _fold_pose(sprite: Sprite2D, base_pos: Vector2, mx: float, my: float, center: float, pivot: float) -> void:
	sprite.scale = _base_scale * Vector2(mx, my)
	sprite.position = Vector2(base_pos.x * mx, pivot + (base_pos.y - center) * my)


## İniş: kısa ezilme + yumuşak oturma. Sepet/askı bu anda tepki verir (`landed`).
func _land() -> void:
	global_position = _fly_target
	rotation_degrees = _fly_rotation
	scale = Vector2.ONE * _fly_scale
	_set_param(P_KICK, 0.0)
	if _fly_fold:
		_fold_step(1.0)
	landed.emit()
	_flight_tween = create_tween()
	_flight_tween.tween_property(self, "scale", Vector2.ONE * _fly_scale * Motion.LAND_SQUASH, Motion.LAND_SQUASH_SECONDS)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_flight_tween.tween_property(self, "scale", Vector2.ONE * _fly_scale, Motion.LAND_SETTLE_SECONDS)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Dokunma alanı (yerel koordinat): görünenden biraz geniş.
func hit_rect() -> Rect2:
	if _sheet_size != Vector2.ZERO:
		return Rect2(Vector2(-_sheet_size.x * 0.5, -size * 0.08), _sheet_size)
	return Rect2(Vector2(-size * 0.5, -size * 0.08), Vector2(size, size * 1.05))


## Kapalı çamaşıra dokununca: hafif sallanır.
func wobble() -> void:
	_restart_tween()
	_tween.tween_property(self, "rotation_degrees", WOBBLE_DEGREES, WOBBLE_SECONDS)
	_tween.tween_property(self, "rotation_degrees", -WOBBLE_DEGREES, WOBBLE_SECONDS)
	_tween.tween_property(self, "rotation_degrees", 0.0, WOBBLE_SECONDS)


## Kapatan çamaşır bir an parlar: oyuncu nedenini yazısız anlar.
func flash() -> void:
	_restart_tween()
	_tween.tween_property(self, "modulate", Color(1.7, 1.7, 1.7), FLASH_SECONDS)
	_tween.tween_property(self, "modulate", Color.WHITE, FLASH_SECONDS)


func _restart_tween() -> void:
	if _tween != null:
		_tween.kill()
	rotation_degrees = 0.0
	modulate = Color.WHITE
	scale = Vector2.ONE
	_tween = create_tween()


func _shown_color() -> Color:
	return _shade(color)


## Taban renge durum gölgesi (gizem/toz, ıslaklık, solma, don, kapalılık). Çift rengin ikinci yarısı da
## aynı gölgeyle boyanır: iki yarı her durumda birlikte okunur.
func _shade(base: Color) -> Color:
	var shown: Color = MYSTERY_COLOR if _mystery else base
	if _dusty:
		shown = DUST_COLOR
	if _faded:
		shown = shown.lerp(FADED_TINT, FADED_MIX)
	if _frozen:
		shown = shown.lerp(FROST_TINT, FROST_MIX)
	if _wet:
		shown = shown.darkened(WET_DARKEN)
	if _open:
		return shown
	return shown.lerp(CLOSED_GRAY, CLOSED_MIX).darkened(CLOSED_DARKEN)


func _apply_color() -> void:
	if _sprite != null:
		_sprite.modulate = _shown_color()
	if _dual_sprite != null:
		_dual_sprite.modulate = _shade(_dual_color)
	queue_redraw()


func _draw() -> void:
	if _sprite != null:
		return
	var shown: Color = _shown_color()
	var body: Rect2 = Rect2(Vector2(-size * 0.42, size * 0.02), Vector2(size * 0.84, size * 0.86))
	_box.bg_color = shown.darkened(0.14)
	draw_style_box(_box, Rect2(body.position + Vector2(0.0, size * 0.035), body.size))
	_box.bg_color = shown
	draw_style_box(_box, body)
	if _show_pins:
		_box.bg_color = PIN_COLOR
		for side: float in [-0.24, 0.24]:
			draw_style_box(_box, Rect2(Vector2(size * side - size * 0.035, -size * 0.07),
				Vector2(size * 0.07, size * 0.2)))


# --- Yeni engeller: çarşaf, çorap çifti, boya akıtan ----------------------------------------

const SHEET_SHRINK_SHARE: float = 0.55
const SHEET_PIN_SPREAD: float = 0.38
const SOCK_BADGE_RATIO: float = 0.16
const SOCK_BADGE_COLOR: Color = Color(1.0, 1.0, 1.0, 0.95)
const SOCK_LINK_COLOR: Color = Color("6b7280")
const SOCK_STUCK_COLOR: Color = Color("e5484d")
const SOCK_STUCK_DARKEN: float = 0.25
const DYE_BADGE_RATIO: float = 0.17
const DYE_URGENT_LEFT: int = 2
const DYE_TEXT_COLOR: Color = Color.WHITE
const DYE_PULSE_SCALE: float = 1.25
const DYE_PULSE_SECONDS: float = 0.12
const RECOLOR_SECONDS: float = 0.45
const BADGE_POP_SECONDS: float = 0.14
const BADGE_GONE_SECONDS: float = 0.3
const DRIP_FALL: float = 60.0

var _sheet_size: Vector2 = Vector2.ZERO
var _normal_scale: Vector2 = Vector2.ONE
var _normal_pos: Vector2 = Vector2.ZERO
var _sheet_scale: Vector2 = Vector2.ONE
var _sheet_pos: Vector2 = Vector2.ZERO
var _shrinking: bool = false
var _sock_badge: SockBadge = null
var _dye_badge: DyeBadge = null


## Çarşaf: havlu dokusu kendi boyutuna gerilir (iki ipe yayılır). Uçarken normal çamaşır
## boyutuna küçülür; böylece askı/sepet/katlama kodu çarşafı sıradan parça gibi işler.
func make_sheet(width: float, height: float) -> void:
	if _sprite == null:
		_sheet_size = Vector2(width, height)
		return
	_normal_scale = _base_scale
	_normal_pos = _base_pos
	var texture_size: Vector2 = _sprite.texture.get_size()
	_sheet_scale = Vector2(width / texture_size.x, height / texture_size.y)
	_sheet_pos = Vector2(-texture_size.x * _sheet_scale.x * 0.5, -texture_size.y * _sheet_scale.y * 0.1)
	_sheet_size = Vector2(width, height)
	_apply_base(_sheet_scale, _sheet_pos)
	for index: int in range(_pins.size()):
		_pins[index].position.x = width * SHEET_PIN_SPREAD * (-1.0 if index == 0 else 1.0)


func is_sheet() -> bool:
	return _sheet_size != Vector2.ZERO


func _apply_base(base_scale: Vector2, base_pos: Vector2) -> void:
	_base_scale = base_scale
	_base_pos = base_pos
	_shadow_base_pos = base_pos + SHADOW_OFFSET
	_sprite.scale = base_scale
	_sprite.position = base_pos
	if _shadow != null:
		_shadow.scale = base_scale
		_shadow.position = _shadow_base_pos


func _begin_sheet_shrink() -> void:
	_shrinking = is_sheet() and _sprite != null


func _sheet_shrink_step(weight: float) -> void:
	if not _shrinking:
		return
	var t: float = Motion.ease_in_out(weight / SHEET_SHRINK_SHARE)
	_apply_base(_sheet_scale.lerp(_normal_scale, t), _sheet_pos.lerp(_normal_pos, t))
	if t >= 1.0:
		# Artık sıradan bir çamaşır: dokunma alanı da normale döner.
		_shrinking = false
		_sheet_size = Vector2.ZERO


## Çorap: eşini gösteren küçük halka rozeti (iki halka iç içe).
func set_sock() -> void:
	if _sock_badge != null:
		return
	_sock_badge = SockBadge.new()
	_sock_badge.radius = size * SOCK_BADGE_RATIO
	_sock_badge.position = Vector2(size * 0.24, size * 0.18)
	add_child(_sock_badge)


## Eşi beklenen çorap: kısa bir parlama ("şimdi beni al").
func hint() -> void:
	flash()
	if _sock_badge != null:
		_pop(_sock_badge)


## Takılı çorap: rozet kırmızıya döner, çorap koyulaşır; serbest kalınca eski haline döner.
func set_stuck(stuck: bool) -> void:
	if _sock_badge == null:
		set_sock()
	_sock_badge.stuck = stuck
	_sock_badge.queue_redraw()
	if _sprite != null:
		_sprite.modulate = _shown_color().darkened(SOCK_STUCK_DARKEN) if stuck else _shown_color()
	if stuck:
		# Askıdaki parçanın ölçeği küçüktür: `wobble` ölçeği sıfırladığından yalnız dönme oynatılır.
		var shake: Tween = create_tween()
		for angle: float in [WOBBLE_DEGREES, -WOBBLE_DEGREES, 0.0]:
			shake.tween_property(self, "rotation_degrees", angle, WOBBLE_SECONDS)
	_pop(_sock_badge)


## Boya akıtan: damla rozeti ve kalan hamle sayısı.
func set_dye(left: int, dye_color: Color) -> void:
	if _dye_badge == null:
		_dye_badge = DyeBadge.new()
		_dye_badge.radius = size * DYE_BADGE_RATIO
		_dye_badge.position = Vector2(size * 0.3, size * 0.3)
		add_child(_dye_badge)
		_dye_badge.build()
	_dye_badge.tint = dye_color
	set_dye_left(left)


func set_dye_left(left: int) -> void:
	if _dye_badge == null:
		return
	if left <= 0:
		_drop_dye_badge()
		return
	var changed: bool = _dye_badge.left != left
	_dye_badge.left = left
	_dye_badge.urgent = left <= DYE_URGENT_LEFT
	_dye_badge.refresh()
	if changed:
		_pop(_dye_badge)


## Boya aktı / etkisizleşti: rozet damla gibi aşağı süzülüp söner.
func _drop_dye_badge() -> void:
	if _dye_badge == null:
		return
	var badge: DyeBadge = _dye_badge
	_dye_badge = null
	var gone: Tween = badge.create_tween().set_parallel(true)
	gone.tween_property(badge, "position:y", badge.position.y + DRIP_FALL, BADGE_GONE_SECONDS)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	gone.tween_property(badge, "modulate:a", 0.0, BADGE_GONE_SECONDS)
	gone.chain().tween_callback(badge.queue_free)


## Renk değişimi (boya akması / geri al): yumuşak geçiş, sonra yeni renk kalıcı olur.
func recolor(tint: Color, animate: bool = true) -> void:
	color = tint
	if _sprite == null or not animate:
		_apply_color()
		return
	var shift: Tween = _sprite.create_tween()
	shift.tween_property(_sprite, "modulate", _shown_color(), RECOLOR_SECONDS)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_restart_tween()
	_tween.tween_property(self, "scale", Vector2(1.08, 0.94), RECOLOR_SECONDS * 0.4)
	_tween.tween_property(self, "scale", Vector2.ONE, RECOLOR_SECONDS * 0.6)


## Uçuşsuz yerleştirme (geri al sonrası yeniden kurulum): uçuş anında tamamlanır, mandal düşmez.
func snap_to(target: Vector2, target_scale: float, folded_width: float, final_rotation_deg: float) -> void:
	_show_pins = false
	for pin: Sprite2D in _pins:
		pin.visible = false
	if _drops != null:
		_drops.emitting = false
	fly_to(target, target_scale, folded_width, final_rotation_deg)
	_flight_tween.custom_step(_fly_total + Motion.LAND_TOTAL_SECONDS)


func _pop(node: Node2D) -> void:
	var pop: Tween = node.create_tween()
	pop.tween_property(node, "scale", Vector2.ONE * DYE_PULSE_SCALE, DYE_PULSE_SECONDS)
	pop.tween_property(node, "scale", Vector2.ONE, BADGE_POP_SECONDS)


## Çorap rozeti: beyaz daire içinde iç içe iki halka (takılıyken kırmızı).
class SockBadge extends Node2D:
	var radius: float = 20.0
	var stuck: bool = false

	func _draw() -> void:
		draw_circle(Vector2.ZERO, radius, GarmentView.SOCK_BADGE_COLOR, true, -1.0, true)
		var ink: Color = GarmentView.SOCK_STUCK_COLOR if stuck else GarmentView.SOCK_LINK_COLOR
		var ring: float = radius * 0.38
		var width: float = maxf(2.0, radius * 0.16)
		draw_arc(Vector2(-ring * 0.55, 0.0), ring, 0.0, TAU, 24, ink, width, true)
		draw_arc(Vector2(ring * 0.55, 0.0), ring, 0.0, TAU, 24, ink, width, true)


## Boya rozeti: boya renginde damla + beyaz geri sayım rakamı.
class DyeBadge extends Node2D:
	var radius: float = 24.0
	var tint: Color = Color.WHITE
	var left: int = 0
	var urgent: bool = false
	var _label: Label = null

	func build() -> void:
		_label = Label.new()
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.size = Vector2(radius * 2.0, radius * 2.0)
		_label.position = Vector2(-radius, -radius * 0.82)
		_label.add_theme_font_size_override("font_size", int(radius * 1.2))
		_label.add_theme_color_override("font_color", GarmentView.DYE_TEXT_COLOR)
		_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.35))
		_label.add_theme_constant_override("outline_size", 4)
		add_child(_label)

	func refresh() -> void:
		if _label != null:
			_label.text = str(left)
		queue_redraw()

	func _draw() -> void:
		# Damla: alt daire + üstte sivri uç. Son hamlelerde beyaz halka belirir (aciliyet).
		var body: Color = tint.darkened(0.08)
		var tip: PackedVector2Array = PackedVector2Array([
			Vector2(-radius * 0.72, -radius * 0.25), Vector2(0.0, -radius * 1.55), Vector2(radius * 0.72, -radius * 0.25)])
		if urgent:
			draw_circle(Vector2.ZERO, radius * 1.18, Color(1.0, 1.0, 1.0, 0.9), true, -1.0, true)
		draw_colored_polygon(tip, body)
		draw_circle(Vector2.ZERO, radius, body, true, -1.0, true)


# --- Kural çeşitlemeleri: lekeli, zincirli mandal, rüzgâr ------------------------------------

const STAIN_COLOR: Color = Color("5e4127")
const STAIN_ALPHA: float = 0.85
const STAIN_DRYING_ALPHA: float = 0.5
const STAIN_RATIO: float = 0.17
## Kururken lekenin yanında küçük güneş: "bir hamle bekle, kuruyor".
const STAIN_SUN_COLOR: Color = Color("f5c02e")
const STAIN_SUN_HALO: Color = Color(1.0, 1.0, 1.0, 0.95)
const CHAIN_PILL_COLOR: Color = Color(1.0, 1.0, 1.0, 0.95)
const CHAIN_LINK_COLOR: Color = Color("8a6a4a")
const CHAIN_HEIGHT_RATIO: float = 0.17
const CHAIN_PIN_OFFSET: float = 0.2
const WIND_BADGE_COLOR: Color = Color("6cb6e8")
const WIND_STROKE_COLOR: Color = Color(1.0, 1.0, 1.0, 0.95)
const WIND_BADGE_RATIO: float = 0.15
const WIND_IDLE_ALPHA: float = 0.7

var _stain_badge: StainBadge = null
var _chain_badge: ChainBadge = null
var _wind_badge: WindBadge = null


## Lekeli: gövdede kahverengi, yumuşak bir leke (üç örtüşen daire).
func set_stain(stained: bool) -> void:
	if stained and _stain_badge == null:
		_stain_badge = StainBadge.new()
		_stain_badge.radius = size * STAIN_RATIO
		_stain_badge.position = Vector2(-size * 0.1, size * 0.42)
		add_child(_stain_badge)
	if _stain_badge != null:
		_stain_badge.visible = stained
		_stain_badge.modulate.a = 1.0


## Askıda kuruyor: leke solgunlaşır ve nabız atar (bir hamle sonra kurur).
func set_drying(drying: bool) -> void:
	if _stain_badge == null:
		return
	_stain_badge.drying = drying
	_stain_badge.queue_redraw()
	if drying:
		_pop(_stain_badge)


## Kurudu: leke solarak kaybolur.
func dry_stain() -> void:
	if _stain_badge == null:
		return
	var badge: StainBadge = _stain_badge
	_stain_badge = null
	var gone: Tween = badge.create_tween()
	gone.tween_property(badge, "modulate:a", 0.0, Motion.STAIN_DRY_SECONDS)
	gone.tween_callback(badge.queue_free)


## Zincirli mandal: sağdaki komşuya uzanan tek bir beyaz hap (ortak mandal) + iki mandal noktası.
func set_chain(to_partner: Vector2) -> void:
	if _chain_badge == null:
		_chain_badge = ChainBadge.new()
		_chain_badge.height = size * CHAIN_HEIGHT_RATIO
		add_child(_chain_badge)
	# Hap bu çamaşırın sağ mandalından komşunun sol mandalına uzanır (mandallar ±0.2 boyda).
	_chain_badge.position = Vector2(size * CHAIN_PIN_OFFSET, size * 0.02)
	_chain_badge.span = to_partner - Vector2(size * CHAIN_PIN_OFFSET * 2.0, 0.0)
	_chain_badge.z_index = PIN_Z - z_index
	_chain_badge.queue_redraw()


## Zincir çözüldü (eşlerden biri alındı): hap yukarı süzülüp söner.
func release_chain() -> void:
	if _chain_badge == null:
		return
	var badge: ChainBadge = _chain_badge
	_chain_badge = null
	var gone: Tween = badge.create_tween().set_parallel(true)
	gone.tween_property(badge, "position:y", badge.position.y - Motion.PIN_POP_HEIGHT, BADGE_GONE_SECONDS)
	gone.tween_property(badge, "modulate:a", 0.0, BADGE_GONE_SECONDS)
	gone.chain().tween_callback(badge.queue_free)


## Rüzgâr rozeti: mavi disk + üç beyaz rüzgâr çizgisi; ok, örtülecek komşu yönünü gösterir.
## `next`: sıradaki savrulan (tam opak, nabız atar); sonrakiler soluk.
func set_wind(direction: float, next: bool) -> void:
	if _wind_badge == null:
		_wind_badge = WindBadge.new()
		_wind_badge.radius = size * WIND_BADGE_RATIO
		_wind_badge.position = Vector2(0.0, size * 0.3)
		add_child(_wind_badge)
	_wind_badge.direction = direction
	_wind_badge.modulate.a = 1.0 if next else WIND_IDLE_ALPHA
	_wind_badge.queue_redraw()


func clear_wind() -> void:
	if _wind_badge == null:
		return
	var badge: WindBadge = _wind_badge
	_wind_badge = null
	var gone: Tween = badge.create_tween()
	gone.tween_property(badge, "modulate:a", 0.0, BADGE_GONE_SECONDS)
	gone.tween_callback(badge.queue_free)


func wind_pulse() -> void:
	if _wind_badge != null:
		_pop(_wind_badge)


## Rüzgâr esti: çamaşır komşusunun üstüne kayar (yolun bir kısmı), üst katmana geçer.
func blow_over(target: Vector2, target_z: int, animate: bool = true) -> void:
	var landing: Vector2 = position.lerp(target, Motion.WIND_FLIP_SHARE) + Vector2(0.0, Motion.WIND_FLIP_DROP)
	# Örttüğü komşunun üstünde çizilsin (dokunma önceliği de katmanla gelir).
	z_index = maxi(z_index, target_z + 1)
	layer = maxi(layer, target_z + 1)
	if not animate:
		position = landing
		return
	var blow: Tween = create_tween().set_parallel(true)
	blow.tween_property(self, "position", landing, Motion.WIND_FLIP_SECONDS)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	blow.tween_property(self, "rotation_degrees", WOBBLE_DEGREES * signf(target.x - position.x), Motion.WIND_FLIP_SECONDS * 0.4)
	blow.chain().tween_property(self, "rotation_degrees", 0.0, Motion.WIND_FLIP_SECONDS * 0.6)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	nudge(1.0 if target.x > position.x else -1.0)


## Leke: üç örtüşen yumuşak daire (kurumaktayken soluk).
class StainBadge extends Node2D:
	var radius: float = 20.0
	var drying: bool = false

	func _draw() -> void:
		var ink: Color = GarmentView.STAIN_COLOR
		ink.a = GarmentView.STAIN_DRYING_ALPHA if drying else GarmentView.STAIN_ALPHA
		draw_circle(Vector2.ZERO, radius, ink, true, -1.0, true)
		draw_circle(Vector2(radius * 0.9, radius * 0.35), radius * 0.62, ink, true, -1.0, true)
		draw_circle(Vector2(radius * 0.25, -radius * 0.85), radius * 0.45, ink, true, -1.0, true)
		if drying:
			var sun: Vector2 = Vector2(radius * 2.1, -radius * 1.2)
			draw_circle(sun, radius * 0.95, GarmentView.STAIN_SUN_HALO, true, -1.0, true)
			draw_circle(sun, radius * 0.62, GarmentView.STAIN_SUN_COLOR, true, -1.0, true)


## Ortak mandal: iki çamaşır arasında beyaz hap, uçlarda mandal renginde iki nokta, ortada bağ.
class ChainBadge extends Node2D:
	var span: Vector2 = Vector2(200.0, 0.0)
	var height: float = 24.0

	func _draw() -> void:
		var half: float = height * 0.5
		var from: Vector2 = Vector2(0.0, 0.0)
		var to: Vector2 = span
		draw_line(from, to, GarmentView.CHAIN_PILL_COLOR, height, true)
		draw_circle(from, half, GarmentView.CHAIN_PILL_COLOR, true, -1.0, true)
		draw_circle(to, half, GarmentView.CHAIN_PILL_COLOR, true, -1.0, true)
		draw_circle(from, half * 0.62, GarmentView.CHAIN_LINK_COLOR, true, -1.0, true)
		draw_circle(to, half * 0.62, GarmentView.CHAIN_LINK_COLOR, true, -1.0, true)
		var middle: Vector2 = (from + to) * 0.5
		draw_line(middle - Vector2(half * 0.9, 0.0), middle + Vector2(half * 0.9, 0.0),
			GarmentView.CHAIN_LINK_COLOR, half * 0.55, true)


## Rüzgâr rozeti: disk + üç kısa yuvarlak uçlu beyaz çizgi + yön oku.
class WindBadge extends Node2D:
	var radius: float = 22.0
	var direction: float = 1.0

	func _draw() -> void:
		draw_circle(Vector2.ZERO, radius, GarmentView.WIND_BADGE_COLOR, true, -1.0, true)
		var width: float = maxf(2.0, radius * 0.18)
		var ink: Color = GarmentView.WIND_STROKE_COLOR
		for row: int in range(3):
			var y: float = (float(row) - 1.0) * radius * 0.42
			var length: float = radius * (0.9 if row == 1 else 0.6)
			var start: Vector2 = Vector2(-length * 0.6, y)
			var finish: Vector2 = Vector2(length * 0.6, y)
			draw_line(start, finish, ink, width, true)
			draw_circle(start, width * 0.5, ink, true, -1.0, true)
			draw_circle(finish, width * 0.5, ink, true, -1.0, true)
		# Yön oku: diskin kenarında küçük üçgen (örtülecek komşuya bakar).
		var side: float = signf(direction) if direction != 0.0 else 1.0
		var tip: Vector2 = Vector2(side * radius * 1.45, 0.0)
		var base: Vector2 = Vector2(side * radius * 0.95, 0.0)
		draw_colored_polygon(PackedVector2Array([tip, base + Vector2(0.0, -radius * 0.38),
			base + Vector2(0.0, radius * 0.38)]), GarmentView.WIND_BADGE_COLOR)


# --- Makineler ve misafirler: çamur/kuş lekesi ---------------------------------

const MUD_PATH: String = "res://assets/sprites/machines/overlay_mud.png"
const BIRD_MESS_PATH: String = "res://assets/sprites/machines/overlay_birdmess.png"
## Leke genişliği (çamaşır boyuna oran) ve tür başına konum: lekenin her sprite'ta kumaşın
## üstünde kalması için (pantolon bacak arası boştur, çorap dardır).
const MESS_WIDTH_RATIO: float = 0.46
const MESS_ANCHORS: Array[Vector2] = [
	Vector2(0.0, 0.5), Vector2(0.0, 0.2), Vector2(0.0, 0.4), Vector2(0.04, 0.48),
	Vector2(0.0, 0.24), Vector2(0.0, 0.5), Vector2(-0.06, 0.3),
]
const MESS_POP_SECONDS: float = 0.22
const MESS_POP_FROM: float = 0.3
var _kind: int = 0
var _mess: Sprite2D = null


func kind_index() -> int:
	return _kind


## Çamurlu (ya da kuş lekeli) görünüm. `animate`: leke küçükten "şap" diye belirir.
func set_dirty(dirty: bool, bird: bool = false, animate: bool = false) -> void:
	if not dirty:
		if _mess != null:
			_mess.visible = false
		return
	var path: String = BIRD_MESS_PATH if bird else MUD_PATH
	if not ResourceLoader.exists(path):
		return
	if _mess == null:
		_mess = Sprite2D.new()
		_mess.z_index = 1
		add_child(_mess)
	_mess.texture = load(path) as Texture2D
	var anchor: Vector2 = MESS_ANCHORS[_kind % MESS_ANCHORS.size()]
	_mess.position = Vector2(anchor.x * size, anchor.y * size)
	var base: float = size * MESS_WIDTH_RATIO / maxf(_mess.texture.get_size().x, 1.0)
	_mess.visible = true
	_mess.modulate = Color.WHITE
	_pin_children_on_top()
	if not animate:
		_mess.scale = Vector2.ONE * base
		return
	_mess.scale = Vector2.ONE * base * MESS_POP_FROM
	var pop: Tween = _mess.create_tween()
	pop.tween_property(_mess, "scale", Vector2.ONE * base, MESS_POP_SECONDS)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Makineden temiz çıktı: leke yumuşakça söner (çağıran ayrıca ıslaklığı kapatır).
func wash_clean() -> void:
	if _mess != null:
		_mess.visible = false
	set_wet(false)


# --- Derinleşme 4: çift renk ve mevsim olayları ---------------------------------------------------
# Kurallar `LaundryBoard` son bölümündedir; burada yalnız görünüm. Hepsi yumuşak geçişlidir (Motion)
# ve kurulumda bir kez üretilen düğümlerle çalışır (kare başına üretim yok). Rozetler çakışmasın diye
# farklı köşelerdedir: güneş sağ üstte, yaprak gövde ortasında, don tüm gövdede (kaplama).

const SEASON_FX_PATH: String = "res://assets/sprites/seasons_fx/%s.png"
## Çift renk: çapraz ayrım (sağ alt yarı ikinci renk); kenar yumuşaklığı (gradyan payı).
const DUAL_EDGE_SOFTNESS: float = 0.012
const DUAL_MASK_TEXTURE_SIZE: int = 128
const DUAL_SETTLE_SECONDS: float = 0.42
## Güneş rozeti: sağ üst köşe; aciliyette (son hamle) nabız.
const SUN_BADGE_RATIO: float = 0.42
const SUN_BADGE_POS: Vector2 = Vector2(0.3, 0.16)
const SUN_TEXT_COLOR: Color = Color("6b4a10")
const SUN_URGENT_LEFT: int = 1
const FADED_TINT: Color = Color(0.97, 0.95, 0.9)
const FADED_MIX: float = 0.55
const SHAKE_SECONDS: float = 0.08
const SHAKE_DEGREES: float = 9.0
## Yaprak: gövdenin üst-ortasına konar; düşüş ve süpürme süreleri.
const LEAF_RATIO: float = 0.62
const LEAF_POS: Vector2 = Vector2(0.06, 0.4)
const LEAF_FALL_HEIGHT: float = 220.0
const LEAF_FALL_SECONDS: float = 0.75
const LEAF_BRUSH_SECONDS: float = 0.4
const LEAF_BRUSH_DISTANCE: float = 140.0
const LEAF_HINT_ALPHA: float = 0.45
const LEAF_HINT_LIFT: float = 70.0
const LEAF_HINT_BOB_SECONDS: float = 0.9
## Don: buzlu kaplama + soğuk renk; askıda ısınırken nabız.
const FROST_TINT: Color = Color(0.82, 0.91, 1.0)
const FROST_MIX: float = 0.12
## Don tülü (beyaz, yarı saydam) ve kar taneleri; polen tülü ve benekleri.
const FROST_VEIL: Color = Color(0.92, 0.97, 1.0, 0.3)
const FROST_MARK: Color = Color(1.0, 1.0, 1.0, 0.95)
const DUST_VEIL: Color = Color(1.0, 0.95, 0.8, 0.35)
const DUST_MARK: Color = Color(1.0, 0.86, 0.38, 0.95)
## İşaretlerin gövde çapasına göre yerleri (boy oranı) ve büyüklüğü.
const OVERLAY_MARKS: Array[Vector2] = [Vector2(-0.16, -0.12), Vector2(0.15, 0.02), Vector2(-0.05, 0.16)]
const OVERLAY_MARK_RATIO: float = 0.2
const FROST_WARM_TINT: Color = Color(1.0, 0.86, 0.7, 0.85)
const FROST_THAW_SECONDS: float = 0.6
## Polen tozu: renk gizlenir (sıcak bej), üstünde benekli toz.
const DUST_COLOR: Color = Color(0.86, 0.8, 0.66)
const DUST_ALPHA: float = 0.85
const DUST_FADE_SECONDS: float = 0.35

var _dual_color: Color = Color.WHITE
var _dual_mask: Sprite2D = null
var _dual_sprite: Sprite2D = null
var _sun_badge: SunBadge = null
var _faded: bool = false
var _leaf: Sprite2D = null
var _leaf_hint: Sprite2D = null
var _frozen: bool = false
var _frost: Node2D = null
var _frost_pulse: Tween = null
var _dusty: bool = false
var _dust: Node2D = null
static var _fx_cache: Dictionary = {}
static var _dual_masks: Array[Texture2D] = []


static func season_texture(name: String) -> Texture2D:
	if not _fx_cache.has(name):
		var path: String = SEASON_FX_PATH % name
		_fx_cache[name] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _fx_cache[name] as Texture2D


## Çapraz maske dokusu (ikinci rengin yarısı: köşegenin sağ altı); bir kez üretilir.
static func _dual_mask_texture() -> Texture2D:
	if _dual_masks.is_empty():
		var gradient: Gradient = Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.5 - DUAL_EDGE_SOFTNESS, 0.5 + DUAL_EDGE_SOFTNESS, 1.0])
		gradient.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color.WHITE, Color.WHITE])
		var texture: GradientTexture2D = GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_LINEAR
		texture.fill_from = Vector2(0.0, 0.0)
		texture.fill_to = Vector2(1.0, 1.0)
		texture.width = DUAL_MASK_TEXTURE_SIZE
		texture.height = DUAL_MASK_TEXTURE_SIZE
		_dual_masks.append(texture)
	return _dual_masks[0]


## Çift renk: aynı sprite'ın ikinci kopyası, çapraz bir maskenin (clip_children) içinde ikinci renkle
## boyanır. Aynı materyali paylaştığı için kumaşla birlikte birebir sallanır.
func set_dual(second: Color) -> void:
	_dual_color = second
	if _sprite == null or _dual_mask != null:
		_apply_color()
		return
	var area: Vector2 = _sprite.texture.get_size() * _sprite.scale
	_dual_mask = _make_dual_layer(area)
	_dual_sprite = _dual_mask.get_child(0) as Sprite2D
	_pin_children_on_top()
	_apply_color()


## Maske (gradyan, sprite alanını kaplar) + içinde sprite kopyası (aynı doku, ölçek, materyal).
func _make_dual_layer(area: Vector2) -> Sprite2D:
	var mask: Sprite2D = Sprite2D.new()
	mask.texture = _dual_mask_texture()
	mask.centered = false
	mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	mask.position = _sprite.position
	mask.scale = area / float(DUAL_MASK_TEXTURE_SIZE)
	add_child(mask)
	var copy: Sprite2D = Sprite2D.new()
	copy.texture = _sprite.texture
	copy.centered = false
	copy.material = _material
	# Maskenin ölçeği geri alınır: kopya ana sprite ile aynı piksellerde durur.
	copy.scale = _sprite.scale / mask.scale
	mask.add_child(copy)
	return mask


func is_dual() -> bool:
	return _dual_mask != null


## Çift yerleşti: parça tek renge döner (ikinci yarı yumuşakça erir). `tint`: kalan/seçilen renk.
func settle_dual(tint: Color, animate: bool = true) -> void:
	if _dual_mask == null:
		recolor(tint, animate)
		return
	var mask: Sprite2D = _dual_mask
	_dual_mask = null
	_dual_sprite = null
	color = tint
	_apply_color()
	if not animate:
		mask.queue_free()
		return
	var melt: Tween = mask.create_tween()
	melt.tween_property(mask, "modulate:a", 0.0, DUAL_SETTLE_SECONDS).set_trans(Tween.TRANS_SINE)
	melt.tween_callback(mask.queue_free)
	_restart_tween()
	_tween.tween_property(self, "scale", Vector2(1.06, 0.95), DUAL_SETTLE_SECONDS * 0.4)
	_tween.tween_property(self, "scale", Vector2.ONE, DUAL_SETTLE_SECONDS * 0.6)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# --- Güneşte solma ---

func set_sun(left: int) -> void:
	if _sun_badge == null:
		_sun_badge = SunBadge.new()
		_sun_badge.radius = size * SUN_BADGE_RATIO * 0.5
		_sun_badge.position = Vector2(size * SUN_BADGE_POS.x, size * SUN_BADGE_POS.y)
		_sun_badge.z_index = 2
		add_child(_sun_badge)
		_sun_badge.build()
	set_sun_left(left)


func set_sun_left(left: int) -> void:
	if _sun_badge == null:
		return
	if left <= 0:
		_drop_sun_badge()
		return
	var changed: bool = _sun_badge.left != left
	_sun_badge.left = left
	_sun_badge.urgent = left <= SUN_URGENT_LEFT
	_sun_badge.refresh()
	if changed:
		_pop(_sun_badge)


func _drop_sun_badge() -> void:
	if _sun_badge == null:
		return
	var badge: SunBadge = _sun_badge
	_sun_badge = null
	var gone: Tween = badge.create_tween().set_parallel(true)
	gone.tween_property(badge, "scale", Vector2.ONE * 1.4, BADGE_GONE_SECONDS)
	gone.tween_property(badge, "modulate:a", 0.0, BADGE_GONE_SECONDS)
	gone.chain().tween_callback(badge.queue_free)


## Soldu: renk açılır (ağarmış kumaş), güneş rozeti parlayıp söner.
func set_faded(faded: bool, animate: bool = true) -> void:
	_faded = faded
	if faded:
		_drop_sun_badge()
	if _sprite == null or not animate:
		_apply_color()
		return
	var shift: Tween = _sprite.create_tween()
	shift.tween_property(_sprite, "modulate", _shown_color(), RECOLOR_SECONDS).set_trans(Tween.TRANS_SINE)
	if _dual_sprite != null:
		_apply_color()


## Solmuş parça silkelendi: iki yana çırpılır, rengi geri gelir.
func shake_out() -> void:
	_faded = false
	_restart_tween()
	for angle: float in [SHAKE_DEGREES, -SHAKE_DEGREES, SHAKE_DEGREES * 0.6, -SHAKE_DEGREES * 0.4, 0.0]:
		_tween.tween_property(self, "rotation_degrees", angle, SHAKE_SECONDS).set_trans(Tween.TRANS_SINE)
	nudge(1.0)
	if _sprite != null:
		var shift: Tween = _sprite.create_tween()
		shift.tween_property(_sprite, "modulate", _shown_color(), RECOLOR_SECONDS)
	if _dual_sprite != null:
		_dual_sprite.modulate = _shade(_dual_color)


# --- Düşen yaprak ---

## Yaprak konar: yukarıdan salınarak süzülür (animate) ya da doğrudan yerinde (yeniden kurulum).
func land_leaf(animate: bool = true) -> void:
	hide_leaf_hint()
	if _leaf != null:
		return
	var texture: Texture2D = season_texture("leaf")
	if texture == null:
		return
	_leaf = Sprite2D.new()
	_leaf.texture = texture
	_leaf.z_index = 3
	var factor: float = size * LEAF_RATIO / texture.get_size().x
	_leaf.scale = Vector2.ONE * factor
	var rest: Vector2 = Vector2(size * LEAF_POS.x, size * LEAF_POS.y)
	add_child(_leaf)
	if not animate:
		_leaf.position = rest
		return
	_leaf.position = rest + Vector2(-size * 0.25, -LEAF_FALL_HEIGHT)
	_leaf.modulate.a = 0.0
	_leaf.rotation_degrees = -40.0
	var fall: Tween = _leaf.create_tween().set_parallel(true)
	fall.tween_property(_leaf, "modulate:a", 1.0, LEAF_FALL_SECONDS * 0.3)
	fall.tween_property(_leaf, "position:y", rest.y, LEAF_FALL_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	fall.tween_property(_leaf, "position:x", rest.x, LEAF_FALL_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	fall.tween_property(_leaf, "rotation_degrees", 12.0, LEAF_FALL_SECONDS).set_trans(Tween.TRANS_SINE)
	fall.chain().tween_callback(nudge.bind(0.5))


## Süpürüldü: yaprak yana savrulup döner ve söner.
func brush_leaf() -> void:
	if _leaf == null:
		return
	var leaf: Sprite2D = _leaf
	_leaf = null
	var away: Tween = leaf.create_tween().set_parallel(true)
	away.tween_property(leaf, "position", leaf.position + Vector2(LEAF_BRUSH_DISTANCE, -LEAF_BRUSH_DISTANCE * 0.35),
		LEAF_BRUSH_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	away.tween_property(leaf, "rotation_degrees", leaf.rotation_degrees + 160.0, LEAF_BRUSH_SECONDS)
	away.tween_property(leaf, "modulate:a", 0.0, LEAF_BRUSH_SECONDS)
	away.chain().tween_callback(leaf.queue_free)
	nudge(-0.6)


func has_leaf() -> bool:
	return _leaf != null


## Bir hamle önceden: hedefin üstünde soluk, hafifçe salınan yaprak (yazısız uyarı).
func show_leaf_hint() -> void:
	if _leaf_hint != null or _leaf != null:
		return
	var texture: Texture2D = season_texture("leaf")
	if texture == null:
		return
	_leaf_hint = Sprite2D.new()
	_leaf_hint.texture = texture
	_leaf_hint.z_index = 3
	_leaf_hint.scale = Vector2.ONE * (size * LEAF_RATIO * 0.8 / texture.get_size().x)
	_leaf_hint.position = Vector2(size * LEAF_POS.x, size * LEAF_POS.y - LEAF_HINT_LIFT)
	_leaf_hint.modulate.a = LEAF_HINT_ALPHA
	add_child(_leaf_hint)
	var bob: Tween = _leaf_hint.create_tween().set_loops()
	bob.tween_property(_leaf_hint, "rotation_degrees", 14.0, LEAF_HINT_BOB_SECONDS).set_trans(Tween.TRANS_SINE)
	bob.tween_property(_leaf_hint, "rotation_degrees", -14.0, LEAF_HINT_BOB_SECONDS).set_trans(Tween.TRANS_SINE)


func hide_leaf_hint() -> void:
	if _leaf_hint == null:
		return
	_leaf_hint.queue_free()
	_leaf_hint = null


# --- Don ---

func set_frost(frozen: bool) -> void:
	_frozen = frozen
	if frozen and _frost == null:
		_frost = _season_overlay(FROST_VEIL, "icon_frost", FROST_MARK)
	elif not frozen and _frost != null:
		_frost.queue_free()
		_frost = null
	_apply_color()


## Askıda ısınıyor: kırağı sıcak tona döner ve yumuşakça nabız atar (bir hamle sonra çözülür).
func set_warming(warming: bool) -> void:
	if _frost == null:
		return
	if _frost_pulse != null:
		_frost_pulse.kill()
		_frost_pulse = null
	if not warming:
		_frost.modulate = Color.WHITE
		return
	_frost.modulate = FROST_WARM_TINT
	_frost_pulse = _frost.create_tween().set_loops()
	_frost_pulse.tween_property(_frost, "modulate:a", 0.45, 0.6).set_trans(Tween.TRANS_SINE)
	_frost_pulse.tween_property(_frost, "modulate:a", FROST_WARM_TINT.a, 0.6).set_trans(Tween.TRANS_SINE)


## Çözüldü: kırağı söner, renk ısınır.
func thaw() -> void:
	_frozen = false
	if _frost_pulse != null:
		_frost_pulse.kill()
		_frost_pulse = null
	if _frost != null:
		var frost: Node2D = _frost
		_frost = null
		var gone: Tween = frost.create_tween()
		gone.tween_property(frost, "modulate:a", 0.0, FROST_THAW_SECONDS).set_trans(Tween.TRANS_SINE)
		gone.tween_callback(frost.queue_free)
	if _sprite != null:
		var shift: Tween = _sprite.create_tween()
		shift.tween_property(_sprite, "modulate", _shown_color(), FROST_THAW_SECONDS)
	if _dual_sprite != null:
		_dual_sprite.modulate = _shade(_dual_color)


# --- Polen tozu ---

func set_dusty(dusty: bool, animate: bool = true) -> void:
	if dusty == _dusty:
		return
	_dusty = dusty
	if dusty and _dust == null:
		_dust = _season_overlay(DUST_VEIL, "icon_pollen", DUST_MARK)
		if _dust != null:
			_dust.modulate.a = 0.0
	if _dust != null:
		var target: float = DUST_ALPHA if dusty else 0.0
		if animate:
			var fade: Tween = _dust.create_tween()
			fade.tween_property(_dust, "modulate:a", target, DUST_FADE_SECONDS)
		else:
			_dust.modulate.a = target
	if _sprite != null and animate:
		var shift: Tween = _sprite.create_tween()
		shift.tween_property(_sprite, "modulate", _shown_color(), DUST_FADE_SECONDS)
		if _dual_sprite != null:
			_dual_sprite.modulate = _shade(_dual_color)
	else:
		_apply_color()


## Mevsim kaplaması: gövdenin silüetini izleyen beyaz bir "tül" (aynı doku ve materyal: kumaşla
## birlikte sallanır, rengin üstüne yarı saydam biner) + gövdeye serpilmiş birkaç küçük işaret
## (kar tanesi / polen beneği). Neden kırpma değil: clip_children bu materyalle kaplamayı düz bir
## beyaza çeviriyordu; tül + seçik işaretler rengi okunur bırakır.
func _season_overlay(veil_tint: Color, mark: String, mark_tint: Color) -> Node2D:
	if _sprite == null:
		return null
	var holder: Node2D = Node2D.new()
	holder.z_index = 1
	var veil: Sprite2D = Sprite2D.new()
	veil.texture = _sprite.texture
	veil.centered = false
	veil.position = _sprite.position
	veil.scale = _sprite.scale
	veil.material = _material
	veil.modulate = veil_tint
	holder.add_child(veil)
	var texture: Texture2D = season_texture(mark)
	if texture != null:
		var anchor: Vector2 = MESS_ANCHORS[_kind % MESS_ANCHORS.size()]
		for offset: Vector2 in OVERLAY_MARKS:
			var dot: Sprite2D = Sprite2D.new()
			dot.texture = texture
			dot.modulate = mark_tint
			dot.scale = Vector2.ONE * (size * OVERLAY_MARK_RATIO * (1.0 - absf(offset.x)) / texture.get_size().x)
			dot.position = Vector2((anchor.x + offset.x) * size, (anchor.y + offset.y) * size)
			dot.rotation = offset.x * 3.0
			holder.add_child(dot)
	add_child(holder)
	_pin_children_on_top()
	return holder


## Uçuş başlarken mevsim durumu çözülür: toz kalkar (renk alınınca belli olur), ipucu yaprağı silinir.
func _leave_season_state() -> void:
	hide_leaf_hint()
	if _dusty:
		set_dusty(false)
	if _sun_badge != null:
		_drop_sun_badge()


## Güneş rozeti: sıcak güneş dokusu + koyu kahve sayı; son hamlede beyaz halka nabız.
class SunBadge extends Node2D:
	var radius: float = 24.0
	var left: int = 0
	var urgent: bool = false
	var _label: Label = null
	var _disc: Sprite2D = null

	func build() -> void:
		var texture: Texture2D = GarmentView.season_texture("sun_badge")
		if texture != null:
			_disc = Sprite2D.new()
			_disc.texture = texture
			_disc.scale = Vector2.ONE * (radius * 2.0 / texture.get_size().x) * 1.3
			add_child(_disc)
		_label = Label.new()
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.size = Vector2(radius * 2.0, radius * 2.0)
		_label.position = Vector2(-radius, -radius * 1.02)
		_label.add_theme_font_size_override("font_size", int(radius * 1.15))
		_label.add_theme_color_override("font_color", GarmentView.SUN_TEXT_COLOR)
		add_child(_label)

	func refresh() -> void:
		if _label != null:
			_label.text = str(left)
		queue_redraw()

	func _draw() -> void:
		if urgent:
			draw_circle(Vector2.ZERO, radius * 1.32, Color(1.0, 1.0, 1.0, 0.9), true, -1.0, true)
			draw_circle(Vector2.ZERO, radius * 1.32, Color("e5484d"), false, maxf(2.0, radius * 0.12), true)
