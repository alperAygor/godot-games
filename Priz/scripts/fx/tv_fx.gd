class_name TvFx
extends Appliance

## Televizyon: açılınca ekran parlar, tablo atlasından yavaşça kayan "sahneler" birbirine karışır
## ve odaya o anki sahnenin renginde ışık vurur. Kapalıyken kırmızı bekleme ışığı yanar.

const MODEL: PackedScene = preload("res://assets/models/appliances/tv.glb")
## Atlas çeyreklerinin ortalama renkleri (sahne → oda ışığı rengi).
const SCENE_COLORS: Array[Color] = [
	Color(0.95, 0.62, 0.42), Color(0.92, 0.72, 0.52), Color(0.62, 0.78, 0.55), Color(0.5, 0.72, 0.9),
]
const SCENE_TIME: float = 3.6
const FADE_TIME: float = 0.9

var _screen: MeshInstance3D
var _light: OmniLight3D
var _led: StandardMaterial3D
var _scene_a: int = 0
var _scene_b: int = 1
var _clock: float = 0.0
var _pan: float = 0.0


func _init() -> void:
	appliance_id = "tv"
	default_ramp = 0.35
	if model == null:
		model = MODEL


func _setup() -> void:
	_screen = mesh_part("Screen")
	_light = make_light("LightAnchor", Color.WHITE, 2.6)
	_led = make_indicator(Color(1.0, 0.15, 0.1))


func _on_level(level: float) -> void:
	if _screen != null:
		_screen.set_instance_shader_parameter("power", level)
	if _led != null:
		_led.emission = Color(0.3, 1.0, 0.4) if running else Color(1.0, 0.15, 0.1)
		_led.emission_energy_multiplier = (2.5 if running else 1.5) * _mains


func _animate(delta: float, level: float) -> void:
	if level <= 0.0:
		set_light(_light, 0.0)
		return
	_clock += delta
	_pan += delta
	var mix_t: float = clampf((_clock - (SCENE_TIME - FADE_TIME)) / FADE_TIME, 0.0, 1.0)
	if _clock >= SCENE_TIME:
		_clock = 0.0
		_scene_a = _scene_b
		_scene_b = (_scene_b + 1 + (1 if _scene_b == 2 else 0)) % SCENE_COLORS.size()
		mix_t = 0.0
	if _screen != null:
		_screen.set_instance_shader_parameter("scene_a", float(_scene_a))
		_screen.set_instance_shader_parameter("scene_b", float(_scene_b))
		_screen.set_instance_shader_parameter("scene_mix", mix_t)
		_screen.set_instance_shader_parameter("pan", _pan)
	if _light != null:
		_light.light_color = SCENE_COLORS[_scene_a].lerp(SCENE_COLORS[_scene_b], mix_t)
		var flick: float = 0.92 + 0.08 * sin(_pan * 2.3) * sin(_pan * 5.7)
		set_light(_light, 1.6 * level * flick)
