class_name BasketView
extends Node2D

## Renk sepetinin görünümü. Konum = sepetin orta noktası. Sprite varsa
## (basket_body.png + nötr basket_band.png renk çarpımıyla) onu kullanır.

const BODY_PATH: String = "res://assets/sprites/basket_body.png"
const BAND_PATH: String = "res://assets/sprites/basket_band.png"
const BODY_COLOR: Color = Color("e9d3ad")
const EMPTY_ALPHA: float = 0.0
const DOT_RADIUS_RATIO: float = 0.045

var size: float = 240.0
var color: Color = Color.WHITE
var filled: int = 0
var active: bool = true

var _body: Sprite2D = null
var _band: Sprite2D = null
var _box: StyleBoxFlat = StyleBoxFlat.new()


func setup(pixel_size: float) -> void:
	size = pixel_size
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
		_band.modulate = tint
	queue_redraw()


func set_filled(count: int) -> void:
	filled = count
	queue_redraw()


## Sepetteki `index`. parçanın duracağı yer (global).
## Katlanmış parçalar üst üste yığılır: her kat ayrı seçilir (aralarında boşluk/gölge kalır).
func slot_position(index: int) -> Vector2:
	return global_position + Vector2(0.0, -size * 0.17 - float(index) * size * 0.19)


func folded_width() -> float:
	return size * 0.5


func _make_sprite(path: String) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = load(path) as Texture2D
	sprite.scale = Vector2.ONE * (size / sprite.texture.get_size().x)
	add_child(sprite)
	return sprite


func _draw() -> void:
	# Doluluk noktaları: sepetin altında 3 küçük nokta (yazısız sayaç).
	var radius: float = size * DOT_RADIUS_RATIO
	for index: int in range(LaundryBoard.BASKET_CAPACITY):
		var center: Vector2 = Vector2((float(index) - 1.0) * radius * 3.2, size * 0.52)
		var dot: Color = color if index < filled else Color(0.0, 0.0, 0.0, 0.12)
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
