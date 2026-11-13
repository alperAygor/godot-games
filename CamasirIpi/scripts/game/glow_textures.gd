class_name GlowTextures
extends RefCounted

## Yumuşak radyal doku fabrikası (güneş, ay, yıldız, ateş böceği, pencere ışığı).
## Neden kod ile üretim: dokular gradyan olduğu için kenarları pürüzsüz (anti-aliased) olur,
## dosya boyutu ve içe aktarma yükü eklemez. Her doku bir kez üretilip paylaşılır.

const SIZE: int = 256
## Doku yarıçapı (piksel): sprite ölçeği = istenen_yarıçap / RADIUS.
const RADIUS: float = 128.0
const CENTER: Vector2 = Vector2(0.5, 0.5)
const EDGE: Vector2 = Vector2(1.0, 0.5)

static var _disc: Texture2D = null
static var _halo: Texture2D = null
static var _dot: Texture2D = null
static var _add: CanvasItemMaterial = null


## Yumuşak kenarlı dolu disk (güneş/ay gövdesi).
static func disc() -> Texture2D:
	if _disc == null:
		_disc = _radial([0.0, 0.7, 0.88, 1.0], [1.0, 1.0, 0.4, 0.0])
	return _disc


## Geniş, çok yumuşak ışık halesi (toplamalı karışımla kullanılır).
static func halo() -> Texture2D:
	if _halo == null:
		_halo = _radial([0.0, 0.15, 0.4, 0.7, 1.0], [0.85, 0.5, 0.2, 0.05, 0.0])
	return _halo


## Küçük parlak nokta (yıldız, ateş böceği).
static func dot() -> Texture2D:
	if _dot == null:
		_dot = _radial([0.0, 0.25, 0.6, 1.0], [1.0, 0.7, 0.15, 0.0])
	return _dot


## Işık efektleri için toplamalı (additive) malzeme; tüm sprite'lar paylaşır.
static func additive() -> CanvasItemMaterial:
	if _add == null:
		_add = CanvasItemMaterial.new()
		_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _add


static func _radial(offsets: Array[float], alphas: Array[float]) -> GradientTexture2D:
	var gradient: Gradient = Gradient.new()
	var color_array: PackedColorArray = PackedColorArray()
	for alpha: float in alphas:
		color_array.append(Color(1.0, 1.0, 1.0, alpha))
	gradient.offsets = PackedFloat32Array(offsets)
	gradient.colors = color_array
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = CENTER
	texture.fill_to = EDGE
	texture.width = SIZE
	texture.height = SIZE
	return texture


## Yarıçapı (px) verilen sprite oluşturur; konum ve renk çağıranda ayarlanır.
static func make_sprite(texture: Texture2D, radius: float, additive_blend: bool) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = texture
	sprite.scale = Vector2.ONE * (radius / RADIUS)
	if additive_blend:
		sprite.material = additive()
	return sprite
