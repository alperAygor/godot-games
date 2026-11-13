class_name SkyView
extends Node2D

## Gökyüzü süsleri: güneş (disk + hale + ufuk puslu ışığı), ay, yıldızlar.
## Hepsi yumuşak radyal dokular; konum/renk DayLook'tan gelir. Gradyan gökyüzü zeminini
## oyun sahnesi çizer, burası onun üstündeki "gök cisimleri" katmanıdır.

const SUN_DISC_RADIUS: float = 58.0
const SUN_HALO_RADIUS: float = 330.0
const SUN_HAZE_RADIUS: float = 420.0
## Ufuk puslu ışığı yatay uzanır; gün batımı hissini yaratır.
const SUN_HAZE_STRETCH: Vector2 = Vector2(1.9, 0.75)
const SUN_HALO_ALPHA: float = 0.55
const SUN_HAZE_ALPHA: float = 0.45
const MOON_RADIUS: float = 46.0
const MOON_HALO_RADIUS: float = 230.0
const MOON_HALO_ALPHA: float = 0.4
const MOON_HALO_COLOR: Color = Color(0.62, 0.72, 1.0)
const MOON_CRATER_COLOR: Color = Color(0.72, 0.74, 0.72, 0.38)
## Krater: [ay merkezine göre konum, yarıçap]
const MOON_CRATERS: Array[Array] = [
	[Vector2(-14.0, -10.0), 11.0], [Vector2(12.0, 8.0), 8.0], [Vector2(-6.0, 20.0), 6.0],
]
const STAR_COUNT: int = 34
const STAR_AREA: Rect2 = Rect2(24.0, 30.0, 1032.0, 700.0)
const STAR_MIN_RADIUS: float = 5.0
const STAR_MAX_RADIUS: float = 14.0
const STAR_TWINKLE_MIN_SPEED: float = 0.7
const STAR_TWINKLE_MAX_SPEED: float = 2.2
const STAR_SEED: int = 4242
const VISIBLE_EPSILON: float = 0.01

var _sun_haze: Sprite2D = null
var _sun_halo: Sprite2D = null
var _sun_disc: Sprite2D = null
var _moon: Node2D = null
var _moon_disc: Sprite2D = null
var _moon_halo: Sprite2D = null
var _stars: Array[Sprite2D] = []
var _star_base: PackedFloat32Array = PackedFloat32Array()
var _star_speed: PackedFloat32Array = PackedFloat32Array()
var _star_phase: PackedFloat32Array = PackedFloat32Array()


func setup() -> void:
	_sun_haze = GlowTextures.make_sprite(GlowTextures.halo(), SUN_HAZE_RADIUS, true)
	_sun_haze.scale *= SUN_HAZE_STRETCH
	add_child(_sun_haze)
	_sun_halo = GlowTextures.make_sprite(GlowTextures.halo(), SUN_HALO_RADIUS, true)
	add_child(_sun_halo)
	_sun_disc = GlowTextures.make_sprite(GlowTextures.disc(), SUN_DISC_RADIUS, false)
	add_child(_sun_disc)
	_moon = Node2D.new()
	add_child(_moon)
	_moon_halo = GlowTextures.make_sprite(GlowTextures.halo(), MOON_HALO_RADIUS, true)
	_moon.add_child(_moon_halo)
	_moon_disc = GlowTextures.make_sprite(GlowTextures.disc(), MOON_RADIUS, false)
	_moon.add_child(_moon_disc)
	for spec: Array in MOON_CRATERS:
		var crater: Sprite2D = GlowTextures.make_sprite(GlowTextures.disc(), float(spec[1]), false)
		crater.position = spec[0] as Vector2
		crater.modulate = MOON_CRATER_COLOR
		_moon.add_child(crater)
	# Yıldızlar sabit tohumla dağıtılır: her açılışta aynı gökyüzü (tutarlı, test edilebilir).
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = STAR_SEED
	for index: int in range(STAR_COUNT):
		var radius: float = rng.randf_range(STAR_MIN_RADIUS, STAR_MAX_RADIUS)
		var star: Sprite2D = GlowTextures.make_sprite(GlowTextures.dot(), radius, true)
		star.position = STAR_AREA.position + Vector2(rng.randf() * STAR_AREA.size.x, rng.randf() * STAR_AREA.size.y)
		add_child(star)
		_stars.append(star)
		_star_base.append(rng.randf_range(0.45, 1.0))
		_star_speed.append(rng.randf_range(STAR_TWINKLE_MIN_SPEED, STAR_TWINKLE_MAX_SPEED))
		_star_phase.append(rng.randf() * TAU)


## Ay, bulutların önüne taşınır: bulut ayı örtünce gece gökyüzü boş görünürdü.
func lift_moon(new_parent: Node) -> void:
	_moon.reparent(new_parent, false)


func apply(look: DayLook, time: float) -> void:
	var sun_on: bool = look.sun_alpha > VISIBLE_EPSILON
	_sun_disc.visible = sun_on
	_sun_halo.visible = sun_on
	_sun_haze.visible = sun_on and look.sun_haze > VISIBLE_EPSILON
	if sun_on:
		_sun_disc.position = look.sun_pos
		_sun_halo.position = look.sun_pos
		_sun_haze.position = look.sun_pos
		_sun_disc.scale = Vector2.ONE * (SUN_DISC_RADIUS * look.sun_size / GlowTextures.RADIUS)
		_sun_halo.scale = Vector2.ONE * (SUN_HALO_RADIUS * look.sun_size / GlowTextures.RADIUS)
		_sun_disc.modulate = Color(look.sun_color.r, look.sun_color.g, look.sun_color.b, look.sun_alpha)
		_sun_halo.modulate = Color(look.sun_color.r, look.sun_color.g, look.sun_color.b, look.sun_alpha * SUN_HALO_ALPHA)
		_sun_haze.modulate = Color(look.sun_color.r, look.sun_color.g, look.sun_color.b, look.sun_alpha * look.sun_haze * SUN_HAZE_ALPHA)
	var moon_on: bool = look.moon_alpha > VISIBLE_EPSILON
	_moon.visible = moon_on
	if moon_on:
		_moon.position = look.moon_pos
		_moon.modulate.a = look.moon_alpha
		_moon_disc.modulate = Color(look.moon_color.r, look.moon_color.g, look.moon_color.b, 1.0)
		_moon_halo.modulate = Color(MOON_HALO_COLOR.r, MOON_HALO_COLOR.g, MOON_HALO_COLOR.b, MOON_HALO_ALPHA)
	var stars_on: bool = look.star_amount > VISIBLE_EPSILON
	for index: int in range(_stars.size()):
		_stars[index].visible = stars_on
		if stars_on:
			# Her yıldız kendi hızında ve fazında hafifçe parlayıp söner.
			var twinkle: float = 0.6 + 0.4 * sin(time * _star_speed[index] + _star_phase[index])
			_stars[index].modulate = Color(0.95, 0.97, 1.0, _star_base[index] * twinkle * look.star_amount)
