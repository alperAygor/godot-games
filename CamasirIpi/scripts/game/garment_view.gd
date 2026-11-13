class_name GarmentView
extends Node2D

## Tek çamaşırın görünümü. Konum = ipe tutunduğu üst-orta nokta. Hazır sprite varsa
## (assets/sprites/garment_*.png, nötr beyaz -> renk çarpımı) onu kullanır; yoksa
## yumuşak köşeli basit bir şekil çizer (prototip yedeği).

const KINDS: Array[String] = ["tshirt", "pants", "dress", "towel", "shorts", "sweater"]
const SPRITE_PATH: String = "res://assets/sprites/garment_%s.png"
const PIN_PATH: String = "res://assets/sprites/pin.png"
const CLOSED_GRAY: Color = Color(0.55, 0.57, 0.62)
const CLOSED_MIX: float = 0.55
const CLOSED_DARKEN: float = 0.18
const WOBBLE_DEGREES: float = 7.0
const WOBBLE_SECONDS: float = 0.09
const FLASH_SECONDS: float = 0.16
const PIN_COLOR: Color = Color("c99a5b")

var item_id: int = -1
var color: Color = Color.WHITE
var size: float = 200.0
var layer: int = 0

var _open: bool = true
var _sprite: Sprite2D = null
var _pins: Array[Sprite2D] = []
var _box: StyleBoxFlat = StyleBoxFlat.new()
var _tween: Tween = null
var _show_pins: bool = true


func setup(id: int, tint: Color, pixel_size: float, kind: int, item_layer: int) -> void:
	item_id = id
	color = tint
	size = pixel_size
	layer = item_layer
	z_index = item_layer
	var path: String = SPRITE_PATH % KINDS[posmod(kind, KINDS.size())]
	if ResourceLoader.exists(path):
		_sprite = Sprite2D.new()
		_sprite.texture = load(path) as Texture2D
		_sprite.centered = false
		var texture_size: Vector2 = _sprite.texture.get_size()
		var factor: float = size / maxf(texture_size.x, texture_size.y)
		_sprite.scale = Vector2.ONE * factor
		_sprite.position = Vector2(-texture_size.x * factor * 0.5, -size * 0.06)
		add_child(_sprite)
		if ResourceLoader.exists(PIN_PATH):
			for side: float in [-0.22, 0.22]:
				var pin: Sprite2D = Sprite2D.new()
				pin.texture = load(PIN_PATH) as Texture2D
				var pin_factor: float = size * 0.22 / pin.texture.get_size().y
				pin.scale = Vector2.ONE * pin_factor
				pin.position = Vector2(size * side, 0.0)
				add_child(pin)
				_pins.append(pin)
	_box.set_corner_radius_all(int(size * 0.16))
	_box.anti_aliasing = true
	_box.anti_aliasing_size = 1.5
	_apply_color()


func set_open(open: bool) -> void:
	if open == _open:
		return
	_open = open
	_apply_color()


func is_open() -> bool:
	return _open


## İpten ayrılınca mandallar görünmez olur.
func detach_pins() -> void:
	_show_pins = false
	for pin: Sprite2D in _pins:
		pin.visible = false
	queue_redraw()


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
	_tween = create_tween()


func _shown_color() -> Color:
	if _open:
		return color
	return color.lerp(CLOSED_GRAY, CLOSED_MIX).darkened(CLOSED_DARKEN)


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
	_box.bg_color = shown.lightened(0.22)
	draw_style_box(_box, Rect2(body.position + Vector2(size * 0.08, size * 0.08),
		Vector2(size * 0.3, size * 0.12)))
	if _show_pins:
		_box.bg_color = PIN_COLOR
		for side: float in [-0.24, 0.24]:
			draw_style_box(_box, Rect2(Vector2(size * side - size * 0.035, -size * 0.07),
				Vector2(size * 0.07, size * 0.2)))
