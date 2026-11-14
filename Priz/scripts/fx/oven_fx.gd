class_name OvenFx
extends Appliance

## Fırın: içi yavaşça kızarır (≈3 sn), camdan turuncu ışık taşar, düğmeler döner, gösterge yanar.

const MODEL: PackedScene = preload("res://assets/models/appliances/oven.glb")

var _interior: MeshInstance3D
var _light: OmniLight3D
var _led: StandardMaterial3D
var _t: float = 0.0


func _init() -> void:
	appliance_id = "oven"
	default_ramp = 3.0
	if model == null:
		model = MODEL


func _setup() -> void:
	_interior = mesh_part("Interior")
	_light = make_light("LightAnchor", Color(1.0, 0.52, 0.22), 1.6)
	_led = make_indicator(Color(1.0, 0.55, 0.15))


func _on_switch(on: bool) -> void:
	for knob_name: String in ["Knob_L", "Knob_R"]:
		var k: Node3D = part(knob_name)
		if k != null:
			var t: Tween = create_tween()
			var target: float = deg_to_rad(-130.0 if knob_name == "Knob_L" else -90.0) if on else 0.0
			t.tween_property(k, "rotation:z", target, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_level(level: float) -> void:
	if _interior != null:
		_interior.set_instance_shader_parameter("heat", level)
	if _led != null:
		_led.emission_energy_multiplier = 5.0 * (1.0 if running else 0.0) * _mains
	_apply_light(level)


func _animate(delta: float, level: float) -> void:
	if level <= 0.0:
		return
	_t += delta
	_apply_light(level)


func _apply_light(level: float) -> void:
	var flick: float = 0.94 + 0.06 * sin(_t * 7.0) * sin(_t * 3.1)
	set_light(_light, 1.5 * pow(level, 1.4) * flick)
