class_name CameraRig
extends Node3D

## Robotu arkadan izleyen oyun kamerası. Yalnız görsel: fiziğe, çarpışmaya ve
## prob ölçümlerine dokunmaz. Denge değerleri `data/balance.json` `physics.camera_*`
## anahtarlarından okunur; kodda sihirli sayı yoktur (varsayılanlar adlandırılmış sabittir).

const DEFAULT_CAMERA_DISTANCE: float = 7.2
const DEFAULT_CAMERA_HEIGHT: float = 4.6
const DEFAULT_CAMERA_LOOK_HEIGHT: float = 0.9
const DEFAULT_CAMERA_FOLLOW_SPEED: float = 8.0
const DEFAULT_CAMERA_LOOK_SPEED: float = 10.0
const DEFAULT_CAMERA_FOV: float = 60.0
const DEFAULT_CAMERA_FOV_GAIN: float = 6.0
const DEFAULT_CAMERA_SHAKE_AMPLITUDE: float = 0.05
const DEFAULT_CAMERA_SHAKE_FREQUENCY: float = 8.0

@export var target_path: NodePath

var _target: Node3D = null
var _camera: Camera3D = null
var _distance: float = DEFAULT_CAMERA_DISTANCE
var _height: float = DEFAULT_CAMERA_HEIGHT
var _look_height: float = DEFAULT_CAMERA_LOOK_HEIGHT
var _follow_speed: float = DEFAULT_CAMERA_FOLLOW_SPEED
var _look_speed: float = DEFAULT_CAMERA_LOOK_SPEED
var _base_fov: float = DEFAULT_CAMERA_FOV
var _fov_gain: float = DEFAULT_CAMERA_FOV_GAIN
var _shake_amplitude: float = DEFAULT_CAMERA_SHAKE_AMPLITUDE
var _shake_frequency: float = DEFAULT_CAMERA_SHAKE_FREQUENCY
var _look_position: Vector3 = Vector3.ZERO
var _behind_direction: Vector3 = Vector3.BACK
var _time: float = 0.0


func _ready() -> void:
	_target = get_node_or_null(target_path) as Node3D
	_camera = get_node_or_null("Camera3D") as Camera3D
	_distance = maxf(0.1, _balance_value("camera_distance", DEFAULT_CAMERA_DISTANCE))
	_height = maxf(0.1, _balance_value("camera_height", DEFAULT_CAMERA_HEIGHT))
	_look_height = _balance_value("camera_look_height", DEFAULT_CAMERA_LOOK_HEIGHT)
	_follow_speed = maxf(0.0, _balance_value("camera_follow_speed", DEFAULT_CAMERA_FOLLOW_SPEED))
	_look_speed = maxf(0.0, _balance_value("camera_look_speed", DEFAULT_CAMERA_LOOK_SPEED))
	_base_fov = clampf(_balance_value("camera_fov", DEFAULT_CAMERA_FOV), 1.0, 179.0)
	_fov_gain = maxf(0.0, _balance_value("camera_fov_gain", DEFAULT_CAMERA_FOV_GAIN))
	_shake_amplitude = maxf(0.0, _balance_value("camera_shake_amplitude", DEFAULT_CAMERA_SHAKE_AMPLITUDE))
	_shake_frequency = maxf(0.1, _balance_value("camera_shake_frequency", DEFAULT_CAMERA_SHAKE_FREQUENCY))
	if _target == null or _camera == null:
		push_warning("CameraRig: target_path and a Camera3D child are required.")
		return
	_camera.position = Vector3.ZERO
	_camera.fov = _base_fov
	_camera.current = true
	_update_behind_direction()
	global_position = _target.global_position + _behind_direction * _distance + Vector3.UP * _height
	_look_position = _target.global_position + Vector3.UP * _look_height
	_look_at_target()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_target) or not is_instance_valid(_camera):
		return
	_time += delta
	_update_behind_direction()
	var speed_ratio: float = _speed_ratio()
	var desired_position: Vector3 = _target.global_position + _behind_direction * _distance + Vector3.UP * _height
	var desired_look: Vector3 = _target.global_position + Vector3.UP * _look_height
	# Exponential weights keep smoothing consistent if the fixed timestep changes.
	global_position = global_position.lerp(desired_position + _shake_offset(speed_ratio), 1.0 - exp(-_follow_speed * delta))
	_look_position = _look_position.lerp(desired_look, 1.0 - exp(-_look_speed * delta))
	# Hız arttıkça hafif FOV genişlemesi: ileri yolu ve tehlikeleri belirginleştirir,
	# dururken taban FOV'a döner.
	_camera.fov = clampf(_base_fov + speed_ratio * _fov_gain, 1.0, 179.0)
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


## Robot hızının azami hıza oranı (0..1). `speed()`/`max_speed()` yoksa 0 döner,
## böylece izole sahnelerde/prob'larda kamera sabit kalır.
func _speed_ratio() -> float:
	if _target == null or not _target.has_method("speed"):
		return 0.0
	var speed: float = float(_target.call("speed"))
	var top_speed: float = 1.0
	if _target.has_method("max_speed"):
		top_speed = maxf(float(_target.call("max_speed")), 0.001)
	return clampf(speed / top_speed, 0.0, 1.0)


## Hıza bağlı çok hafif sarsıntı. Üç eksende farklı frekans kayması yapay periyodik
## görünümü kırar; genlik dururken sıfır, azami hızda `_shake_amplitude` kadardır.
func _shake_offset(ratio: float) -> Vector3:
	if ratio <= 0.0:
		return Vector3.ZERO
	var strength: float = _shake_amplitude * ratio
	return Vector3(
		sin(_time * _shake_frequency) * strength,
		sin(_time * _shake_frequency * 1.7 + 1.3) * strength * 0.5,
		cos(_time * _shake_frequency * 0.9 + 0.7) * strength
	)


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
