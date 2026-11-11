class_name KeyboardKey
extends AnimatableBody3D

@export var phase_offset_seconds: float = 0.0

var _parameters: Dictionary[String, Variant] = {}
var _period: float = 0.0
var _warning_seconds: float = 0.0
var _press_seconds: float = 0.0
var _hold_seconds: float = 0.0
var _release_seconds: float = 0.0
var _press_depth: float = 0.0
var _warning_start: float = 0.0
var _press_start: float = 0.0
var _phase: float = 0.0
var _rest_position: Vector3 = Vector3.ZERO
var _telegraphing: bool = false
var _pressed: bool = false
var _normal_color: Color = Color.WHITE
var _warning_color: Color = Color.WHITE
var _pressed_color: Color = Color.WHITE
var _visual_material: StandardMaterial3D = null


func _ready() -> void:
	add_to_group("hazard")
	add_to_group("keyboard_key")
	var data: Node = get_node_or_null("/root/GameData")
	if data != null:
		var found: Variant = data.call("value", "balance", "hazards", null)
		if found is Dictionary:
			_parameters.assign(found)
	_warning_seconds = maxf(_parameter("key_warn_seconds", 0.65), 0.5)
	_press_seconds = maxf(_parameter("key_press_seconds", 0.12), 0.001)
	_hold_seconds = maxf(_parameter("key_hold_seconds", 0.4), 0.0)
	_release_seconds = maxf(_parameter("key_release_seconds", 0.25), 0.001)
	_period = maxf(_parameter("key_period_seconds", 4.0),
		_warning_seconds + _press_seconds + _hold_seconds + _release_seconds)
	_press_depth = maxf(_parameter("key_press_depth", 0.28), 0.0)
	_normal_color = Color.from_string(String(_parameters.get("key_idle_color", "4d9de0")), Color.WHITE)
	_warning_color = Color.from_string(String(_parameters.get("key_warn_color", "f7b801")), Color.YELLOW)
	_pressed_color = Color.from_string(String(_parameters.get("key_pressed_color", "ff4d4d")), Color.RED)
	_rest_position = position
	_press_start = _period - _press_seconds - _hold_seconds - _release_seconds
	_warning_start = _press_start - _warning_seconds
	_phase = fposmod(phase_offset_seconds, _period)
	sync_to_physics = true
	_visual_material = StandardMaterial3D.new()
	_visual_material.albedo_color = _normal_color
	var visual: Node = get_node_or_null("Visual")
	if visual != null:
		_override_visual_material(visual)
	_update_phase()


func is_telegraphing() -> bool:
	return _telegraphing


func is_pressed() -> bool:
	return _pressed


func _physics_process(delta: float) -> void:
	_phase = fposmod(_phase + delta, _period)
	_update_phase()


func _update_phase() -> void:
	_telegraphing = _phase >= _warning_start and _phase < _press_start
	_pressed = _phase >= _press_start and _phase < _press_start + _press_seconds + _hold_seconds
	var depth_fraction: float = 0.0
	if _pressed:
		depth_fraction = clampf((_phase - _press_start) / _press_seconds, 0.0, 1.0)
	elif _phase >= _press_start + _press_seconds + _hold_seconds:
		depth_fraction = 1.0 - clampf(
			(_phase - _press_start - _press_seconds - _hold_seconds) / _release_seconds, 0.0, 1.0)
	position = _rest_position + Vector3.DOWN * (_press_depth * depth_fraction)
	if _telegraphing:
		_visual_material.albedo_color = _warning_color
	elif _pressed:
		_visual_material.albedo_color = _pressed_color
	else:
		_visual_material.albedo_color = _normal_color


func _override_visual_material(node: Node) -> void:
	# Imported GLBs can nest their mesh below multiple transform nodes.
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		mesh_instance.material_override = _visual_material
	for child: Node in node.get_children():
		_override_visual_material(child)


func _parameter(key: String, fallback: float) -> float:
	return float(_parameters.get(key, fallback))
