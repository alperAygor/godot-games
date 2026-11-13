class_name GardenBackdrop
extends Node2D

## Bahçe arka planı: Blender'da 3B modellenip render edilen katmanlar (assets/sprites/bg).
## Katmanlar derinliğe göre çok hafif kayar (parallaks), bulutlar süzülür, ağaç tacı ve
## çiçekler sallanır. `storm` 0..1 arttıkça sahne kararır ve rüzgâr hızlanır.
## Bekleme askısı da buradadır; `danger` 0..1 ile kırmızıya döner.
## Gün döngüsü: `set_level(n)` günün saatini seçer (DayCycle); önceki aşamadan yeni aşamaya
## ~1.5 sn'de yumuşakça geçilir. Önce aşama paleti uygulanır, `storm` onun üstüne biner.

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
## Fırtınada bulutlar bu renge çekilir (aşama bulut tonuyla çarpılır).
const STORM_CLOUD_TINT: Color = Color(0.62, 0.65, 0.72)
## Direk/askı manzara tonunu bu oranda alır: gece de görünür kalsın, ama sahneden kopmasın.
const PROPS_TINT_SHARE: float = 0.4
## Çiçekler doygun renkli; sahne tonunu bu oranda alır.
const FLOWER_TINT_SHARE: float = 0.6
## HUD yazısı: gökyüzü parlaklığı bu değerin altına inince açık renge geçmeye başlar.
const HUD_DARK_LUMA_START: float = 0.5
const HUD_DARK_LUMA_RANGE: float = 0.25
const HUD_LIGHT_TEXT: Color = Color(0.94, 0.96, 1.0)
## Hata ayıklama: `-- --phase=N` o gün aşamasını zorlar (ekran görüntüsü için).
const PHASE_ARG: String = "--phase="

var storm: float = 0.0
var danger: float = 0.0
## Çamaşır/sepet katmanına uygulanacak çok hafif ortam tonu (game.gd okur).
var garment_tint: Color = Color.WHITE

var _current: DayLook = DayLook.new()
var _fade_from: DayLook = DayLook.new()
var _fade_to: DayLook = DayCycle.look_for_phase(0)
var _fade: float = 1.0
var _level_seen: int = -1
var _forced_phase: int = -1
var _sky_node: Node2D = null
var _sky_view: SkyView = null
var _window_lights: WindowLights = null
var _fireflies: Fireflies = null
var _far_sprite: Sprite2D = null
## Sahne tonu uygulanan sprite'lar (parallaks katmanları + ağaç); çiçekler ayrı, daha hafif.
var _tinted: Array[Sprite2D] = []

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
	# Gök cisimleri/bulutlar manzaranın arkasında, ama sahne tonundan etkilenmeyen ayrı katmanda.
	_sky_node = Node2D.new()
	_sky_node.scale = Vector2.ONE * cover
	add_child(_sky_node)
	_sky_view = SkyView.new()
	_sky_node.add_child(_sky_view)
	_sky_view.setup()
	_scenery = Node2D.new()
	_scenery.scale = Vector2.ONE * cover
	add_child(_scenery)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(PHASE_ARG):
			_forced_phase = posmod(int(arg.substr(PHASE_ARG.length())), DayCycle.PHASE_COUNT)
	_props = Node2D.new()
	_props.position.x = (view_size.x - DESIGN_WIDTH) * 0.5
	add_child(_props)
	_width = view_size.x / cover
	_parent = _sky_node
	for spec: Array in CLOUDS:
		var cloud: Sprite2D = _sprite(String(spec[0]), spec[1] as Vector2)
		cloud.scale = Vector2.ONE * float(spec[2])
		_clouds.append([cloud, float(spec[3])])
	_sky_view.lift_moon(_sky_node)
	_parent = _scenery
	for spec: Array in LAYERS:
		var layer_sprite: Sprite2D = _sprite(String(spec[0]), spec[1] as Vector2)
		_parallax.append([layer_sprite, (spec[1] as Vector2).x, float(spec[2])])
		_tinted.append(layer_sprite)
		if _far_sprite == null:
			# Pencere ışıkları uzak katmanın hemen üstüne, orta katmanın arkasına gelir.
			_far_sprite = layer_sprite
			_window_lights = WindowLights.new()
			_scenery.add_child(_window_lights)
			_window_lights.setup()
	# Ağaç çitin arkasında durur; taç ayrı sprite olduğu için rüzgârda sallanır.
	_tinted.append(_sprite("tree_trunk", TREE_BASE - TRUNK_BASE_PIXEL))
	_crown = _sprite("tree_crown", Vector2.ZERO)
	_tinted.append(_crown)
	_crown.centered = false
	_crown.offset = -CROWN_PIVOT_PIXEL
	_crown.position = TREE_BASE - Vector2(0.0, CROWN_RISE) \
		+ (CROWN_PIVOT_PIXEL - Vector2(320.0, 320.0))
	for spec: Array in FRONT_LAYERS:
		var front_sprite: Sprite2D = _sprite(String(spec[0]), spec[1] as Vector2)
		_parallax.append([front_sprite, (spec[1] as Vector2).x, float(spec[2])])
		_tinted.append(front_sprite)
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
	# Ateş böcekleri çimin önünde, direklerin arkasında uçar; ışıklı olduğu için tonlanmaz.
	_fireflies = Fireflies.new()
	_scenery.add_child(_fireflies)
	_fireflies.setup()
	_parent = _props
	# Askı: kanca uçları oyunun askı hizasına (çamaşırın asıldığı nokta) oturur.
	_rack = _sprite("rack", Vector2((DESIGN_WIDTH - 1024.0) * 0.5, rack_hook_y - RACK_HOOK_TIP_PIXEL_Y))
	# İlk set_level() çağrısı gelene kadar geçerli bir görünüm olsun (şafak ya da zorlanan aşama).
	_current.copy_from(DayCycle.look_for_phase(maxi(_forced_phase, 0)))
	_apply_look(0.0)


## Seviye numarasına göre günün saatini ayarlar. İlk çağrı anında oturur; sonrakiler
## önceki görünümden DayCycle.FADE_SECONDS sürede yumuşakça geçer. Aynı seviye tekrarı geçiş başlatmaz.
func set_level(level: int) -> void:
	if level == _level_seen:
		return
	var first: bool = _level_seen < 0
	_level_seen = level
	_fade_from.copy_from(_current)
	_fade_to = DayCycle.look_for_phase(_forced_phase) if _forced_phase >= 0 else DayCycle.look_for_level(level)
	_fade = 1.0 if first else 0.0
	if first:
		_current.copy_from(_fade_to)
		_apply_look(0.0)


## Gökyüzü koyulaşınca (alacakaranlık/gece) koyu HUD yazısı okunmaz olur; bu yüzden
## varsayılan yazı rengi hedef aşamaya göre açık tona çekilir (seviye başında çağrılır).
func hud_text_color(default_color: Color) -> Color:
	var darkness: float = clampf((HUD_DARK_LUMA_START - _fade_to.sky_top.get_luminance()) / HUD_DARK_LUMA_RANGE, 0.0, 1.0)
	return default_color.lerp(HUD_LIGHT_TEXT, darkness)


## Aşama paleti + fırtına birleşik gökyüzü üst rengi (game.gd gradyanı için).
func sky_top(storm_color: Color, weight: float) -> Color:
	return _current.sky_top.lerp(_dimmed(storm_color), weight)


func sky_bottom(storm_color: Color, weight: float) -> Color:
	return _current.sky_bottom.lerp(_dimmed(storm_color), weight)


## Fırtına rengi geceleyin de parlak gri kalmasın: aşamanın storm_dim değeriyle koyulur.
func _dimmed(color: Color) -> Color:
	return Color(color.r * _current.storm_dim, color.g * _current.storm_dim, color.b * _current.storm_dim, color.a)


## Geçiş ilerler, paleti sahneye uygular. Kare başına yalnızca ~20 özellik ataması.
func _apply_look(time: float) -> void:
	var scenery: Color = _current.scenery_tint
	for sprite: Sprite2D in _tinted:
		sprite.modulate = scenery
	var flower_tint: Color = Color.WHITE.lerp(scenery, FLOWER_TINT_SHARE)
	for flower: Sprite2D in _flowers:
		flower.modulate = flower_tint
	_props.modulate = Color.WHITE.lerp(scenery, PROPS_TINT_SHARE)
	garment_tint = _current.garment_tint
	_sky_view.apply(_current, time)
	_fireflies.apply(_current.firefly_amount, time)
	_window_lights.apply(_current.window_glow, time)
	if _far_sprite != null:
		_window_lights.position = _far_sprite.position


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
	if _fade < 1.0:
		_fade = minf(_fade + delta / DayCycle.FADE_SECONDS, 1.0)
		_current.blend(_fade_from, _fade_to, smoothstep(0.0, 1.0, _fade))
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
		cloud.modulate = _current.cloud_tint * Color.WHITE.lerp(STORM_CLOUD_TINT, storm)
	if _crown != null:
		_crown.rotation_degrees = CROWN_SWAY_DEGREES * wind * 0.6 * sin(time * 0.7 * (1.0 + storm))
	for index: int in range(_flowers.size()):
		_flowers[index].rotation_degrees = FLOWER_SWAY_DEGREES * (1.0 + storm * 2.0) \
			* sin(time * 1.5 + float(index) * 1.9)
	_apply_look(time)
	modulate = Color.WHITE.lerp(STORM_TINT, storm * 0.8)
	if _rack != null:
		_rack.modulate = Color.WHITE.lerp(DANGER_TINT, danger)
