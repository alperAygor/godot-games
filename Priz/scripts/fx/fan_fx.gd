class_name FanFx
extends Appliance

## Ayaklı vantilatör: kanatlar hızlanarak döner (≈1.5 sn), yüksek hızda hareket bulanıklığı
## diski belirir; kafa yavaşça sağa sola salınır.

const MODEL: PackedScene = preload("res://assets/models/appliances/fan.glb")
const MAX_SPIN: float = 22.0  # rad/sn
const OSC_AMPLITUDE: float = 0.55  # radyan (≈ ±32°)
const OSC_SPEED: float = 0.55

var _blades: Node3D
var _head: Node3D
var _blur: MeshInstance3D
var _spin: float = 0.0
var _osc: float = 0.0
var _head_base: float = 0.0


func _init() -> void:
	appliance_id = "fan"
	default_ramp = 1.5
	if model == null:
		model = MODEL


func _setup() -> void:
	_blades = part("Blades")
	_head = part("Head")
	_blur = mesh_part("BladeBlur_noshadow")
	if _head != null:
		_head_base = _head.rotation.y
	if _blur != null:
		_blur.set_instance_shader_parameter("speed", 0.0)


func _animate(delta: float, level: float) -> void:
	var speed: float = level * level
	_spin += delta * MAX_SPIN * speed
	if _blades != null:
		_blades.rotation.z = fmod(_spin, TAU)
	if _blur != null:
		_blur.set_instance_shader_parameter("speed", smoothstep(0.35, 1.0, speed))
	_osc += delta * OSC_SPEED * level
	if _head != null:
		_head.rotation.y = _head_base + OSC_AMPLITUDE * sin(_osc)
