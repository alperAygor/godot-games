class_name GarmentView
extends Node2D

## Tek çamaşırın görünümü. Konum = ipe tutunduğu üst-orta nokta. Blender'da üretilen
## nötr beyaz sprite (assets/sprites/garment_*.png) oyun rengiyle çarpılır; sprite yoksa
## yumuşak köşeli basit bir şekil çizilir (yedek).
## Durumlar: kapalı (soluk), ıslak (koyu + damla), gizemli (renk gizli, "?"),
## kilitli (anahtar renginde rozet). İpteyken hafifçe sallanır.

const KINDS: Array[String] = ["tshirt", "pants", "dress", "towel", "shorts", "sweater"]
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
const SWAY_DEGREES: float = 1.7
const SWAY_SPEED: float = 1.25
const WOBBLE_DEGREES: float = 7.0
const WOBBLE_SECONDS: float = 0.09
const FLASH_SECONDS: float = 0.16
const PIN_COLOR: Color = Color("c99a5b")
const CIRCLE_TEXTURE_SIZE: int = 128

var item_id: int = -1
var color: Color = Color.WHITE
var size: float = 200.0
var layer: int = 0

var _open: bool = true
var _wet: bool = false
var _mystery: bool = false
var _lock_color: Color = Color.TRANSPARENT
var _locked: bool = false
var _swaying: bool = true
var _phase: float = 0.0
var _sprite: Sprite2D = null
var _shadow: Sprite2D = null
var _pins: Array[Sprite2D] = []
var _question: Label = null
var _drops: CPUParticles2D = null
var _box: StyleBoxFlat = StyleBoxFlat.new()
var _tween: Tween = null
var _show_pins: bool = true
var _folded: bool = false
var _badge: Node2D = null
static var _circle: Texture2D = null


func setup(id: int, tint: Color, pixel_size: float, kind: int, item_layer: int) -> void:
	item_id = id
	color = tint
	size = pixel_size
	layer = item_layer
	z_index = item_layer
	_phase = float(id) * 1.37
	var path: String = SPRITE_PATH % KINDS[posmod(kind, KINDS.size())]
	if ResourceLoader.exists(path):
		var texture: Texture2D = load(path) as Texture2D
		_shadow = _make_sprite(texture)
		_shadow.modulate = SHADOW_COLOR
		_shadow.position += SHADOW_OFFSET
		_shadow.material = _silhouette_material()
		_sprite = _make_sprite(texture)
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


## Gölge için sprite'ın yalnız alfa silueti kullanılır (renk çarpımı düz renge döner).
func _silhouette_material() -> ShaderMaterial:
	var shader: Shader = Shader.new()
	shader.code = "shader_type canvas_item;\nvoid fragment() {\n\tCOLOR = vec4(COLOR.rgb, texture(TEXTURE, UV).a * COLOR.a);\n}\n"
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	return material


func _process(_delta: float) -> void:
	if not _swaying or (_tween != null and _tween.is_running()):
		return
	var time: float = float(Time.get_ticks_msec()) * 0.001
	rotation_degrees = SWAY_DEGREES * sin(time * SWAY_SPEED + _phase)


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


## İpten ayrılınca mandallar ve gölge kaybolur, sallanma durur.
func detach_pins() -> void:
	_show_pins = false
	_swaying = false
	rotation_degrees = 0.0
	for pin: Sprite2D in _pins:
		pin.visible = false
	if _drops != null:
		_drops.emitting = false
	queue_redraw()


## Uçuşun ortasında katlanır: dikeyde ezilir, katlanmış görünüme geçer, yeniden açılır.
func fold(seconds: float, target_width: float) -> void:
	if _sprite == null or _folded or not ResourceLoader.exists(FOLDED_PATH):
		return
	_folded = true
	var tween: Tween = create_tween()
	tween.tween_property(_sprite, "scale:y", _sprite.scale.y * 0.08, seconds * 0.45)
	tween.tween_callback(func() -> void:
		var texture: Texture2D = load(FOLDED_PATH) as Texture2D
		var factor: float = target_width / texture.get_size().x
		for sprite: Sprite2D in [_sprite, _shadow]:
			sprite.texture = texture
			sprite.centered = true
			sprite.position = Vector2.ZERO
			sprite.scale = Vector2(factor, factor * 0.08)
		_shadow.position = SHADOW_OFFSET * 0.6
		var open_tween: Tween = create_tween().set_parallel(true)
		for sprite: Sprite2D in [_sprite, _shadow]:
			open_tween.tween_property(sprite, "scale:y", factor, seconds * 0.5)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))


## Dokunma alanı (yerel koordinat): görünenden biraz geniş.
func hit_rect() -> Rect2:
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
	var shown: Color = MYSTERY_COLOR if _mystery else color
	if _wet:
		shown = shown.darkened(WET_DARKEN)
	if _open:
		return shown
	return shown.lerp(CLOSED_GRAY, CLOSED_MIX).darkened(CLOSED_DARKEN)


func _apply_color() -> void:
	if _sprite != null:
		_sprite.modulate = _shown_color()
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
