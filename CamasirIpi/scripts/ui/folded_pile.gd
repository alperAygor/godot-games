class_name UiFoldedPile
extends Control

## Kazanma sayfasındaki katlanmış çamaşır yığını. Oyundaki `folded.png` (beyaz, gölgeli)
## seviyenin renkleriyle boyanıp üst üste dizilir; her kat yukarıdan yumuşakça iner.

const TEXTURE_PATH: String = "res://assets/sprites/folded.png"
## folded.png içinde görünen gövdenin sınırları (px): yığını gövdeye göre ölçeklemek için.
const BODY_RECT: Rect2 = Rect2(15.0, 69.0, 226.0, 118.0)
const BASE_WIDTH: float = 330.0
const WIDTH_STEP: float = 0.07
const LAYER_STEP: float = 62.0
const TILT_DEGREES: float = 2.6
const DROP_DISTANCE: float = 150.0
const LAYER_STAGGER: float = 0.2
const LAYER_SECONDS: float = 0.5
const SHADOW_COLOR: Color = Color(0.1, 0.16, 0.13, 0.12)
const SHADOW_SQUASH: float = 0.22
const MAX_LAYERS: int = 5
const SHADE_STEP: float = 0.05

var _tints: Array[Color] = []
var _texture: Texture2D = null
var _progress: float = 0.0
var _tween: Tween = null


func setup(tints: Array[Color]) -> void:
	_texture = load(TEXTURE_PATH) as Texture2D
	for tint: Color in tints:
		if _tints.size() < MAX_LAYERS:
			_tints.append(tint)
	if _tints.is_empty():
		_tints.append(UiKit.ACCENT)
	custom_minimum_size = Vector2(BASE_WIDTH * 1.2, BASE_WIDTH * 0.62 + LAYER_STEP * float(_tints.size() - 1))
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Katlar sırayla iner. `delay`: sayfanın girişi bittikten sonra başlasın diye.
func play(delay: float) -> void:
	_progress = 0.0
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(delay)
	var total: float = LAYER_STAGGER * float(_tints.size()) + LAYER_SECONDS
	_tween.tween_method(_set_progress, 0.0, total, total)


func _set_progress(value: float) -> void:
	_progress = value
	queue_redraw()


func _draw() -> void:
	if _texture == null:
		return
	var count: int = _tints.size()
	var scale_px: float = BASE_WIDTH / BODY_RECT.size.x
	var body_center: Vector2 = BODY_RECT.position + BODY_RECT.size * 0.5
	var base_center: Vector2 = Vector2(size.x * 0.5, size.y - BODY_RECT.size.y * scale_px * 0.5 - 6.0)
	# Zemin gölgesi: yassı, çok yumuşak elips (ağır gölge yok).
	var shadow_alpha: float = clampf(_progress / LAYER_SECONDS, 0.0, 1.0)
	draw_set_transform(base_center + Vector2(0.0, BODY_RECT.size.y * scale_px * 0.42),
		0.0, Vector2(1.0, SHADOW_SQUASH))
	draw_circle(Vector2.ZERO, BASE_WIDTH * 0.52, Color(SHADOW_COLOR, SHADOW_COLOR.a * shadow_alpha), true, -1.0, true)
	for index: int in range(count):
		var local: float = clampf((_progress - LAYER_STAGGER * float(index)) / LAYER_SECONDS, 0.0, 1.0)
		if local <= 0.0:
			continue
		var eased: float = 1.0 - pow(1.0 - local, 3.0)
		var width_factor: float = 1.0 - WIDTH_STEP * float(index)
		var tilt: float = deg_to_rad(TILT_DEGREES * (1.0 if index % 2 == 0 else -1.0)) * (0.0 if index == 0 else 1.0)
		var center: Vector2 = base_center + Vector2(0.0, -LAYER_STEP * float(index)) \
			+ Vector2(0.0, -DROP_DISTANCE * (1.0 - eased))
		draw_set_transform(center, tilt, Vector2.ONE * scale_px * width_factor)
		# Üst katlar bir tık daha açık: yığında derinlik, çizgi/gölge olmadan.
		var tint: Color = _tints[index].lightened(SHADE_STEP * float(index))
		tint.a = eased
		draw_texture(_texture, -body_center, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
