class_name LampFx
extends Appliance

## Abajur: sıcak ışık, keten abajur içten parlar, ampul ısınırken kısa bir titreme.

const MODEL: PackedScene = preload("res://assets/models/appliances/lamp.glb")

var _light: OmniLight3D
var _shade: StandardMaterial3D
var _bulb: StandardMaterial3D
var _warm: float = 0.0


func _init() -> void:
	appliance_id = "lamp"
	default_ramp = 0.3
	if model == null:
		model = MODEL


func _setup() -> void:
	_light = make_light("LightAnchor", Color(1.0, 0.7, 0.42), 3.2)
	_light.omni_attenuation = 0.9
	_shade = own_material(mesh_part("Shade"))
	_bulb = own_material(mesh_part("Bulb"))


func _on_switch(on: bool) -> void:
	_warm = 0.25 if on else 0.0


func _on_level(level: float) -> void:
	_apply(level)


func _animate(delta: float, level: float) -> void:
	if _warm > 0.0:
		_warm = maxf(0.0, _warm - delta)
		_apply(level)


func _apply(level: float) -> void:
	var flick: float = 1.0
	if _warm > 0.0:
		flick = 0.75 + 0.25 * sin(_warm * 90.0)
	var e: float = level * flick
	set_light(_light, 0.9 * e)
	if _shade != null:
		_shade.emission_energy_multiplier = 0.18 * e
	if _bulb != null:
		_bulb.emission_energy_multiplier = 7.0 * e
