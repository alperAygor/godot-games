class_name GardenBackdrop
extends Node2D

## Bahçe arka planı: Blender'da 3B modellenip render edilen katmanlar (assets/sprites/bg).
## Katmanlar derinliğe göre çok hafif kayar (parallaks), bulutlar süzülür, ağaç tacı ve
## çiçekler sallanır. `storm` 0..1 arttıkça sahne kararır ve rüzgâr hızlanır.
## Bekleme askısı da buradadır; `danger` 0..1 ile kırmızıya döner.

const BG_DIR: String = "res://assets/sprites/bg/"
const DESIGN_WIDTH: float = 1080.0
const STORM_TINT: Color = Color(0.6, 0.65, 0.74)
const DANGER_TINT: Color = Color(1.0, 0.55, 0.5)
## Katman: [dosya, sol-üst konum, parallaks genliği (px)] — uzak katman az, yakın çok kayar.
const LAYERS: Array[Array] = [
	["bg_far", Vector2(0.0, 620.0), 3.0],
	["bg_mid", Vector2(0.0, 760.0), 5.0],
]
const FRONT_LAYERS: Array[Array] = [
	["bg_fence", Vector2(0.0, 990.0), 8.0],
	["bg_grass", Vector2(0.0, 1100.0), 11.0],
]
const CLOUDS: Array[Array] = [
	["cloud_1", Vector2(-120.0, 90.0), 0.9, 7.0],
	["cloud_2", Vector2(520.0, 200.0), 0.8, 10.0],
	["cloud_3", Vector2(180.0, 430.0), 0.6, 5.0],
]
const TREE_BASE: Vector2 = Vector2(150.0, 1230.0)
const TRUNK_BASE_PIXEL: Vector2 = Vector2(180.0, 900.0)
const CROWN_PIVOT_PIXEL: Vector2 = Vector2(320.0, 500.0)
const CROWN_RISE: float = 740.0
const CROWN_SWAY_DEGREES: float = 1.4
const POLE_TOP: float = 200.0
const POLE_AXIS_PIXEL: float = 80.0
const POLE_AXIS_INSET: float = 40.0
const RACK_RAIL_PIXEL_Y: float = 66.0
const RACK_HOOK_TIP_PIXEL_Y: float = 150.0
const FLOWERS: Array[Array] = [
	["flower_1", Vector2(95.0, 1640.0), 0.9], ["flower_2", Vector2(1005.0, 1770.0), 1.0],
	["flower_1", Vector2(905.0, 1250.0), 0.55], ["flower_2", Vector2(60.0, 1300.0), 0.5],
]
const FLOWER_PIVOT_PIXEL: Vector2 = Vector2(80.0, 240.0)
const FLOWER_SWAY_DEGREES: float = 4.0
const PARALLAX_SPEED: float = 0.22
const CLOUD_WRAP_MARGIN: float = 700.0

var storm: float = 0.0
var danger: float = 0.0

var _width: float = DESIGN_WIDTH
var _parallax: Array[Array] = []
var _clouds: Array[Array] = []
var _crown: Sprite2D = null
var _flowers: Array[Sprite2D] = []
var _rack: Sprite2D = null
## Manzara katmanları (ekran 1080'den genişse büyütülür); direk ve askı oyunla hizalı kalır.
var _scenery: Node2D = null
var _props: Node2D = null
var _parent: Node2D = null


func setup(view_size: Vector2, rack_hook_y: float) -> void:
	_width = view_size.x
	# Geniş ekranlarda (tablet) manzara kenarlarda boşluk bırakmasın diye büyütülür.
	var cover: float = maxf(view_size.x / DESIGN_WIDTH, 1.0)
	_scenery = Node2D.new()
	_scenery.scale = Vector2.ONE * cover
	add_child(_scenery)
	_props = Node2D.new()
	_props.position.x = (view_size.x - DESIGN_WIDTH) * 0.5
	add_child(_props)
	_width = view_size.x / cover
	_parent = _scenery
	for spec: Array in CLOUDS:
		var cloud: Sprite2D = _sprite(String(spec[0]), spec[1] as Vector2)
		cloud.scale = Vector2.ONE * float(spec[2])
		_clouds.append([cloud, float(spec[3])])
	for spec: Array in LAYERS:
		_parallax.append([_sprite(String(spec[0]), spec[1] as Vector2), (spec[1] as Vector2).x, float(spec[2])])
	# Ağaç çitin arkasında durur; taç ayrı sprite olduğu için rüzgârda sallanır.
	_sprite("tree_trunk", TREE_BASE - TRUNK_BASE_PIXEL)
	_crown = _sprite("tree_crown", Vector2.ZERO)
	_crown.centered = false
	_crown.offset = -CROWN_PIVOT_PIXEL
	_crown.position = TREE_BASE - Vector2(0.0, CROWN_RISE) \
		+ (CROWN_PIVOT_PIXEL - Vector2(320.0, 320.0))
	for spec: Array in FRONT_LAYERS:
		_parallax.append([_sprite(String(spec[0]), spec[1] as Vector2), (spec[1] as Vector2).x, float(spec[2])])
	# Uzun ekranlarda (dar-uzun telefon) çim ekranın altına kadar uzatılır.
	var grass: Sprite2D = (_parallax[_parallax.size() - 1] as Array)[0] as Sprite2D
	var grass_top: float = grass.position.y
	var needed: float = view_size.y / cover - grass_top
	if grass.texture != null and needed > grass.texture.get_size().y:
		grass.scale.y = needed / grass.texture.get_size().y
	# Direkler iki kenarda; sağdaki aynalanır. Oyun koordinatlarıyla hizalıdır (büyütülmez).
	_parent = _props
	_sprite("pole", Vector2(POLE_AXIS_INSET - POLE_AXIS_PIXEL, POLE_TOP))
	var right_pole: Sprite2D = _sprite("pole", Vector2(DESIGN_WIDTH - POLE_AXIS_INSET - POLE_AXIS_PIXEL, POLE_TOP))
	right_pole.flip_h = true
	_parent = _scenery
	for spec: Array in FLOWERS:
		var flower: Sprite2D = _sprite(String(spec[0]), Vector2.ZERO)
		flower.offset = -FLOWER_PIVOT_PIXEL
		flower.position = (spec[1] as Vector2)
		flower.scale = Vector2.ONE * float(spec[2])
		_flowers.append(flower)
	_parent = _props
	# Askı: kanca uçları oyunun askı hizasına (çamaşırın asıldığı nokta) oturur.
	_rack = _sprite("rack", Vector2((DESIGN_WIDTH - 1024.0) * 0.5, rack_hook_y - RACK_HOOK_TIP_PIXEL_Y))


func _sprite(file_name: String, top_left: Vector2) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	var path: String = BG_DIR + file_name + ".png"
	if ResourceLoader.exists(path):
		sprite.texture = load(path) as Texture2D
	sprite.centered = false
	sprite.position = top_left
	_parent.add_child(sprite)
	return sprite


func _process(delta: float) -> void:
	var time: float = float(Time.get_ticks_msec()) * 0.001
	var wind: float = 1.0 + storm * 4.0
	# Çok yavaş, küçük yatay salınım: katmanlar farklı genlikte kaydığı için derinlik hissi verir.
	var drift: float = sin(time * PARALLAX_SPEED)
	for entry: Array in _parallax:
		(entry[0] as Sprite2D).position.x = float(entry[1]) + drift * float(entry[2])
	for entry: Array in _clouds:
		var cloud: Sprite2D = entry[0] as Sprite2D
		cloud.position.x += float(entry[1]) * wind * delta
		if cloud.position.x > _width + 40.0:
			cloud.position.x = -CLOUD_WRAP_MARGIN
		cloud.modulate = Color.WHITE.lerp(Color(0.62, 0.65, 0.72), storm)
	if _crown != null:
		_crown.rotation_degrees = CROWN_SWAY_DEGREES * wind * 0.6 * sin(time * 0.7 * (1.0 + storm))
	for index: int in range(_flowers.size()):
		_flowers[index].rotation_degrees = FLOWER_SWAY_DEGREES * (1.0 + storm * 2.0) \
			* sin(time * 1.5 + float(index) * 1.9)
	modulate = Color.WHITE.lerp(STORM_TINT, storm * 0.8)
	if _rack != null:
		_rack.modulate = Color.WHITE.lerp(DANGER_TINT, danger)
