class_name CameraRig
extends Node3D

const DEFAULT_CAMERA_DISTANCE: float = 6.0
const DEFAULT_CAMERA_HEIGHT: float = 3.5
const DEFAULT_CAMERA_LOOK_HEIGHT: float = 0.7
const DEFAULT_CAMERA_FOLLOW_SPEED: float = 8.0
const DEFAULT_CAMERA_LOOK_SPEED: float = 10.0
const DEFAULT_CAMERA_FOV: float = 65.0

@export var target_path: NodePath

var _target: Node3D = null
var _camera: Camera3D = null
var _distance: float = DEFAULT_CAMERA_DISTANCE
var _height: float = DEFAULT_CAMERA_HEIGHT
var _look_height: float = DEFAULT_CAMERA_LOOK_HEIGHT
var _follow_speed: float = DEFAULT_CAMERA_FOLLOW_SPEED
var _look_speed: float = DEFAULT_CAMERA_LOOK_SPEED
var _look_position: Vector3 = Vector3.ZERO
var _behind_direction: Vector3 = Vector3.BACK


func _ready() -> void:
	_target = get_node_or_null(target_path) as Node3D
	_camera = get_node_or_null("Camera3D") as Camera3D
	_distance = maxf(0.1, _balance_value("camera_distance", DEFAULT_CAMERA_DISTANCE))
	_height = maxf(0.1, _balance_value("camera_height", DEFAULT_CAMERA_HEIGHT))
	_look_height = _balance_value("camera_look_height", DEFAULT_CAMERA_LOOK_HEIGHT)
	_follow_speed = maxf(0.0, _balance_value("camera_follow_speed", DEFAULT_CAMERA_FOLLOW_SPEED))
	_look_speed = maxf(0.0, _balance_value("camera_look_speed", DEFAULT_CAMERA_LOOK_SPEED))
	if _target == null or _camera == null:
		push_warning("CameraRig: target_path and a Camera3D child are required.")
		return
	_camera.position = Vector3.ZERO
	_camera.fov = clampf(_balance_value("camera_fov", DEFAULT_CAMERA_FOV), 1.0, 179.0)
	_camera.current = true
	_update_behind_direction()
	global_position = _target.global_position + _behind_direction * _distance + Vector3.UP * _height
	_look_position = _target.global_position + Vector3.UP * _look_height
	_look_at_target()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_target) or not is_instance_valid(_camera):
		return
	_update_behind_direction()
	var desired_position: Vector3 = _target.global_position + _behind_direction * _distance + Vector3.UP * _height
	var desired_look: Vector3 = _target.global_position + Vector3.UP * _look_height
	# Exponential weights keep smoothing consistent if the fixed timestep changes.
	global_position = global_position.lerp(desired_position, 1.0 - exp(-_follow_speed * delta))
	_look_position = _look_position.lerp(desired_look, 1.0 - exp(-_look_speed * delta))
	_look_at_target()


func _update_behind_direction() -> void:
	var target_back: Vector3 = _target.global_basis.z
	target_back.y = 0.0
	# Preserve heading if the robot tumbles until its forward axis is vertical.
	if not target_back.is_zero_approx():
		_behind_direction = target_back.normalized()


func _look_at_target() -> void:
	var direction: Vector3 = _look_position - _camera.global_position
	if direction.is_zero_approx():
		return
	if direction.normalized().cross(Vector3.UP).is_zero_approx():
		return
	_camera.look_at(_look_position, Vector3.UP)


func _balance_value(key: String, fallback: float) -> float:
	var game_data: Node = get_node_or_null("/root/GameData")
	if game_data == null:
		return fallback
	var physics: Variant = game_data.call("value", "balance", "physics", null)
	if physics is Dictionary:
		var result: Variant = physics.get(key, fallback)
		if result is float or result is int:
			return float(result)
	return fallback
