class_name SeasonButterflies
extends Node2D

## Yaz kelebekleri: iki kanat sprite'ı (bg/butterfly_wing.png, kök sol-ortada) kanat çırpar
## (yatay ölçek), kelebek yumuşak Lissajous yolunda süzülür ve gidiş yönüne hafifçe yatar.
## Yalnız gündüz ve fırtınasızken görünür (çağıran `amount` ile söyler).

const WING_PATH: String = "res://assets/sprites/bg/butterfly_wing.png"
## Kanat dokusunda kök pikseli (make_background.py: kök sol-ortada ~x 6, y 64).
const WING_ROOT: Vector2 = Vector2(6.0, 64.0)
const FLAP_SPEED: float = 9.0
## Kanat en kapalı hâlinde bu orana iner (tamamen kapanırsa kelebek "kaybolur").
const FLAP_MIN: float = 0.18
const BODY_COLOR: Color = Color(0.52, 0.45, 0.55, 0.9)
const BODY_SIZE: Vector2 = Vector2(5.0, 15.0)
const PATH_SPEED_MIN: float = 0.12
const PATH_SPEED_MAX: float = 0.22
const BOB_PIXELS: float = 10.0
const BOB_SPEED: float = 2.3
const TILT: float = 0.25
const SEED: int = 3307

var _flyers: Array[Node2D] = []
var _wings: Array[Sprite2D] = []
var _center: PackedVector2Array = PackedVector2Array()
var _reach: PackedVector2Array = PackedVector2Array()
var _speed: PackedVector2Array = PackedVector2Array()
var _phase: PackedFloat32Array = PackedFloat32Array()
var _wing_scale: float = 0.3


func setup(spec: Dictionary) -> void:
	var texture: Texture2D = load(WING_PATH) as Texture2D
	if texture == null:
		return
	var raw_area: Array = spec.get("area", [0, 0, 1080, 1080]) as Array
	var area: Rect2 = Rect2(float(raw_area[0]), float(raw_area[1]), float(raw_area[2]), float(raw_area[3]))
	_wing_scale = float(spec.get("span", 40.0)) * 0.5 / texture.get_size().x
	var colors: Array = spec.get("colors", ["#ffffff"]) as Array
	var alpha: float = float(spec.get("alpha", 1.0))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED
	for index: int in range(int(spec.get("count", 0))):
		var flyer: Node2D = Node2D.new()
		var color: Color = Color.html(String(colors[index % colors.size()]))
		flyer.modulate = Color(color.r, color.g, color.b, alpha)
		add_child(flyer)
		for side: int in range(2):
			var wing: Sprite2D = Sprite2D.new()
			wing.texture = texture
			wing.centered = false
			wing.flip_h = side == 1
			wing.offset = Vector2(-(texture.get_size().x - WING_ROOT.x) if side == 1 else -WING_ROOT.x, -WING_ROOT.y)
			wing.scale = Vector2.ONE * _wing_scale
			flyer.add_child(wing)
			_wings.append(wing)
		var body: Sprite2D = GlowTextures.make_sprite(GlowTextures.disc(), 1.0, false)
		body.scale = BODY_SIZE / GlowTextures.RADIUS
		body.modulate = BODY_COLOR
		flyer.add_child(body)
		_flyers.append(flyer)
		_center.append(area.position + Vector2(rng.randf() * area.size.x, rng.randf() * area.size.y))
		_reach.append(Vector2(rng.randf_range(0.25, 0.45) * area.size.x, rng.randf_range(0.12, 0.25) * area.size.y))
		_speed.append(Vector2(rng.randf_range(PATH_SPEED_MIN, PATH_SPEED_MAX), rng.randf_range(PATH_SPEED_MIN, PATH_SPEED_MAX) * 1.6))
		_phase.append(rng.randf() * TAU)


func step(time: float, amount: float) -> void:
	var on: bool = amount > 0.01
	if visible != on:
		visible = on
	if not on:
		return
	modulate.a = minf(amount, 1.0)
	for index: int in range(_flyers.size()):
		var phase: float = _phase[index]
		var speed: Vector2 = _speed[index]
		var center: Vector2 = _center[index]
		var reach: Vector2 = _reach[index]
		var flyer: Node2D = _flyers[index]
		flyer.position = Vector2(center.x + sin(time * speed.x + phase) * reach.x,
			center.y + sin(time * speed.y + phase * 1.7) * reach.y + sin(time * BOB_SPEED + phase) * BOB_PIXELS)
		# Gidiş yönüne hafif yatış (x hızının işareti ve büyüklüğü).
		flyer.rotation = cos(time * speed.x + phase) * TILT
		var flap: float = FLAP_MIN + (1.0 - FLAP_MIN) * absf(sin(time * FLAP_SPEED + phase * 3.0))
		for side: int in range(2):
			_wings[index * 2 + side].scale.x = _wing_scale * flap
