class_name GardenBackdrop
extends Node2D

## Güneşli bahçe arka planı (kodla çizilir; soluk kalır ki çamaşırlar öne çıksın).
## Katmanlar: güneş halesi, kayan bulutlar, uzak tepeler, çit, çim, sallanan çiçekler,
## ip direkleri ve uçuşan yapraklar. `storm` 0..1 arttıkça sahne kararır, rüzgâr hızlanır.

const HILL_FAR: Color = Color("cfe6e6")
const HILL_NEAR: Color = Color("c3e2c4")
const GRASS_TOP: Color = Color("cdeab0")
const GRASS_BOTTOM: Color = Color("a8d78c")
const FENCE: Color = Color("fbf5e8")
const FENCE_SHADE: Color = Color("e3d9c4")
const POLE: Color = Color("b58a5c")
const POLE_LIGHT: Color = Color("d2ab7c")
const STEM: Color = Color("7fbf6a")
const PETALS: Array[Color] = [Color("ffd1dc"), Color("fff0a8"), Color("d9c8ff"), Color("ffffff")]
const STORM_TINT: Color = Color(0.6, 0.65, 0.74)
const HORIZON_Y: float = 1090.0
const GRASS_Y: float = 1215.0
const FENCE_TOP: float = 1085.0
const FENCE_HEIGHT: float = 150.0
const PICKET_WIDTH: float = 46.0
const PICKET_GAP: float = 16.0
const POLE_TOP: float = 215.0
const POLE_WIDTH: float = 26.0
const CLOUD_COUNT: int = 4
const FLOWER_COUNT: int = 14

var storm: float = 0.0

var _width: float = 1080.0
var _height: float = 1920.0
var _clouds: Array[Node2D] = []
var _cloud_speed: Array[float] = []
var _flowers: Array[Dictionary] = []
var _leaves: CPUParticles2D = null
var _box: StyleBoxFlat = StyleBoxFlat.new()


func setup(view_size: Vector2) -> void:
	_width = view_size.x
	_height = maxf(view_size.y, 1920.0)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42
	var glow: Sprite2D = Sprite2D.new()
	glow.texture = _soft_texture()
	glow.position = Vector2(_width * 0.8, 210.0)
	glow.scale = Vector2.ONE * 5.2
	glow.modulate = Color(1.0, 0.97, 0.8, 0.75)
	add_child(glow)
	for index: int in range(CLOUD_COUNT):
		var cloud: Node2D = _make_cloud(rng)
		cloud.position = Vector2(rng.randf_range(0.0, _width), 120.0 + 95.0 * float(index) + rng.randf_range(-20.0, 20.0))
		cloud.scale = Vector2.ONE * rng.randf_range(0.7, 1.25)
		add_child(cloud)
		_clouds.append(cloud)
		_cloud_speed.append(rng.randf_range(6.0, 14.0))
	for index: int in range(FLOWER_COUNT):
		_flowers.append({
			"x": rng.randf_range(40.0, _width - 40.0),
			"y": rng.randf_range(GRASS_Y + 40.0, _height - 60.0),
			"height": rng.randf_range(34.0, 62.0),
			"color": PETALS[rng.randi_range(0, PETALS.size() - 1)],
			"phase": rng.randf_range(0.0, TAU),
		})
	_leaves = CPUParticles2D.new()
	_leaves.amount = 10
	_leaves.lifetime = 9.0
	_leaves.preprocess = 6.0
	_leaves.position = Vector2(-40.0, 500.0)
	_leaves.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_leaves.emission_rect_extents = Vector2(10.0, 480.0)
	_leaves.direction = Vector2(1.0, 0.15)
	_leaves.spread = 12.0
	_leaves.gravity = Vector2(0.0, 6.0)
	_leaves.initial_velocity_min = 90.0
	_leaves.initial_velocity_max = 160.0
	_leaves.angular_velocity_min = -90.0
	_leaves.angular_velocity_max = 90.0
	_leaves.scale_amount_min = 0.05
	_leaves.scale_amount_max = 0.1
	_leaves.texture = GarmentView.circle_texture()
	_leaves.color = Color(0.72, 0.88, 0.62, 0.8)
	add_child(_leaves)
	_box.anti_aliasing = true
	_box.anti_aliasing_size = 1.2


func _process(delta: float) -> void:
	var wind: float = 1.0 + storm * 5.0
	for index: int in range(_clouds.size()):
		var cloud: Node2D = _clouds[index]
		cloud.position.x += _cloud_speed[index] * wind * delta
		if cloud.position.x > _width + 320.0:
			cloud.position.x = -320.0
		cloud.modulate = Color.WHITE.lerp(Color(0.62, 0.65, 0.72), storm)
	_leaves.speed_scale = wind
	modulate = Color.WHITE.lerp(STORM_TINT, storm * 0.8)
	queue_redraw()


func _soft_texture() -> Texture2D:
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	gradient.colors = PackedColorArray([Color.WHITE, Color(1.0, 1.0, 1.0, 0.55), Color(1.0, 1.0, 1.0, 0.0)])
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	return texture


func _make_cloud(rng: RandomNumberGenerator) -> Node2D:
	var cloud: Node2D = Node2D.new()
	var texture: Texture2D = _soft_texture()
	for blob: int in range(6):
		var puff: Sprite2D = Sprite2D.new()
		puff.texture = texture
		puff.position = Vector2(float(blob - 2) * 62.0 + rng.randf_range(-14.0, 14.0), rng.randf_range(-26.0, 14.0))
		puff.scale = Vector2(rng.randf_range(1.6, 2.5), rng.randf_range(1.1, 1.7))
		puff.modulate = Color(1.0, 1.0, 1.0, 0.9)
		cloud.add_child(puff)
	return cloud


func _hill(base_y: float, amplitude: float, frequency: float, phase: float, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	var steps: int = 48
	for step: int in range(steps + 1):
		var x: float = _width * float(step) / float(steps)
		var y: float = base_y - amplitude * (0.5 + 0.5 * sin(x * frequency + phase)) \
			- amplitude * 0.3 * sin(x * frequency * 2.3 + phase * 1.7)
		points.append(Vector2(x, y))
	points.append(Vector2(_width, _height))
	points.append(Vector2(0.0, _height))
	draw_colored_polygon(points, color)
	draw_polyline(points.slice(0, steps + 1), color.lightened(0.25), 3.0, true)


func _draw() -> void:
	var time: float = float(Time.get_ticks_msec()) * 0.001
	_hill(HORIZON_Y, 150.0, 0.0052, 0.6, HILL_FAR)
	_hill(HORIZON_Y + 70.0, 110.0, 0.0071, 2.4, HILL_NEAR)
	# Çit: yuvarlak uçlu tahtalar + iki yatay kuşak.
	_box.set_corner_radius_all(0)
	for rail: float in [0.3, 0.72]:
		_box.bg_color = FENCE_SHADE
		draw_style_box(_box, Rect2(0.0, FENCE_TOP + FENCE_HEIGHT * rail, _width, 16.0))
	var x: float = -10.0
	while x < _width:
		_box.corner_radius_top_left = int(PICKET_WIDTH * 0.5)
		_box.corner_radius_top_right = int(PICKET_WIDTH * 0.5)
		_box.bg_color = FENCE_SHADE
		draw_style_box(_box, Rect2(x + 5.0, FENCE_TOP + 4.0, PICKET_WIDTH, FENCE_HEIGHT))
		_box.bg_color = FENCE
		draw_style_box(_box, Rect2(x, FENCE_TOP, PICKET_WIDTH, FENCE_HEIGHT))
		x += PICKET_WIDTH + PICKET_GAP
	# Çim: dalgalı üst kenar, aşağı doğru koyulaşan iki ton.
	var grass: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var steps: int = 40
	for step: int in range(steps + 1):
		var gx: float = _width * float(step) / float(steps)
		grass.append(Vector2(gx, GRASS_Y + 10.0 * sin(gx * 0.021) + 5.0 * sin(gx * 0.067)))
		colors.append(GRASS_TOP)
	grass.append(Vector2(_width, _height))
	colors.append(GRASS_BOTTOM)
	grass.append(Vector2(0.0, _height))
	colors.append(GRASS_BOTTOM)
	draw_polygon(grass, colors)
	# Çiçekler: rüzgârla sallanan sap + taç.
	var sway_gain: float = 1.0 + storm * 2.5
	for flower: Dictionary in _flowers:
		var base: Vector2 = Vector2(float(flower["x"]), float(flower["y"]))
		var lean: float = sin(time * 1.6 + float(flower["phase"])) * 7.0 * sway_gain
		var top: Vector2 = base + Vector2(lean, -float(flower["height"]))
		draw_line(base, top, STEM, 4.0, true)
		draw_circle(top, 11.0, flower["color"] as Color, true, -1.0, true)
		draw_circle(top, 4.5, Color("ffd65c"), true, -1.0, true)
	# İp direkleri: iki kenarda, iplerin bağlandığı ahşap direkler.
	for pole_x: float in [16.0, _width - 16.0 - POLE_WIDTH]:
		_box.set_corner_radius_all(int(POLE_WIDTH * 0.5))
		_box.bg_color = POLE
		draw_style_box(_box, Rect2(pole_x, POLE_TOP, POLE_WIDTH, GRASS_Y - POLE_TOP + 30.0))
		_box.bg_color = POLE_LIGHT
		draw_style_box(_box, Rect2(pole_x + 5.0, POLE_TOP + 8.0, 7.0, GRASS_Y - POLE_TOP))
