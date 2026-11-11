class_name RobotController
extends RigidBody3D

signal physics_reset()

const DEFAULT_MAX_SPEED: float = 8.0
const DEFAULT_ACCEL: float = 12.0
const DEFAULT_BRAKE: float = 4.0
const DEFAULT_TURN_RATE: float = 1.8
const DEFAULT_MASS: float = 45.0
const DEFAULT_REST: float = 0.38
const DEFAULT_STIFFNESS: float = 2400.0
const DEFAULT_DAMPING: float = 200.0
const DEFAULT_GRIP: float = 7.0
const DEFAULT_RADIUS: float = 0.18
const DEFAULT_FORCE_LIMIT: float = 1000.0
const DEFAULT_GRAVITY_SCALE: float = 1.0
const DEFAULT_COM_Y: float = -0.14
const DEFAULT_LINEAR_DAMP: float = 0.05
const DEFAULT_ANGULAR_DAMP: float = 0.3
const DEFAULT_UPRIGHT: float = 14.0
const DEFAULT_UPRIGHT_DAMPING: float = 4.0
const DEFAULT_AIR_BALANCE: float = 5.0
const DEFAULT_STEERING_RESPONSE: float = 6.0
const DEFAULT_SPEED_RESPONSE: float = 3.0
const DEFAULT_INPUT_RESPONSE: float = 8.0
const DEFAULT_STEER_SPEED_FACTOR: float = 0.65
const DEFAULT_FLIP_RECOVERY_ANGLE_DEG: float = 100.0
const DEFAULT_FLIP_RECOVERY_SECONDS: float = 1.5
const MIN_SPEED: float = 0.001

var _wheels: Array[SuspensionWheel] = []
var _move_input: Vector2 = Vector2.ZERO
var _smoothed_input: Vector2 = Vector2.ZERO
var _grounded: bool = false
var _top_speed: float = DEFAULT_MAX_SPEED
## Batarya/modül etkisi: hedef hızı ölçekler, `max_speed()` tavanını değiştirmez.
var _speed_factor: float = 1.0
var _accel: float = DEFAULT_ACCEL
var _brake: float = DEFAULT_BRAKE
var _turn_rate: float = DEFAULT_TURN_RATE
var _upright: float = DEFAULT_UPRIGHT
var _upright_damping: float = DEFAULT_UPRIGHT_DAMPING
var _air_balance: float = DEFAULT_AIR_BALANCE
var _steering_response: float = DEFAULT_STEERING_RESPONSE
var _speed_response: float = DEFAULT_SPEED_RESPONSE
var _input_response: float = DEFAULT_INPUT_RESPONSE
var _steer_speed_factor: float = DEFAULT_STEER_SPEED_FACTOR
var _flip_recovery_up_dot: float = cos(deg_to_rad(DEFAULT_FLIP_RECOVERY_ANGLE_DEG))
var _flip_recovery_seconds: float = DEFAULT_FLIP_RECOVERY_SECONDS
var _flipped_seconds: float = 0.0
var _parameters: Dictionary[String, Variant] = {}


func _ready() -> void:
	add_to_group("robot")
	var data: Node = get_node_or_null("/root/GameData")
	if data != null:
		var found: Variant = data.call("value", "balance", "physics", null)
		if found is Dictionary:
			_parameters.assign(found)
	_top_speed = _parameter("max_speed", DEFAULT_MAX_SPEED)
	_accel = _parameter("accel", DEFAULT_ACCEL)
	_brake = _parameter("brake", DEFAULT_BRAKE)
	_turn_rate = _parameter("turn_rate", DEFAULT_TURN_RATE)
	_upright = _parameter("upright_torque", DEFAULT_UPRIGHT)
	_upright_damping = _parameter("upright_damping", DEFAULT_UPRIGHT_DAMPING)
	_air_balance = _parameter("air_balance_torque", DEFAULT_AIR_BALANCE)
	_steering_response = _parameter("steering_response", DEFAULT_STEERING_RESPONSE)
	_speed_response = _parameter("speed_response", DEFAULT_SPEED_RESPONSE)
	_input_response = _parameter("input_response", DEFAULT_INPUT_RESPONSE)
	_steer_speed_factor = _parameter("steer_speed_factor", DEFAULT_STEER_SPEED_FACTOR)
	_flip_recovery_up_dot = cos(deg_to_rad(
		_parameter("flip_recovery_angle_deg", DEFAULT_FLIP_RECOVERY_ANGLE_DEG)))
	_flip_recovery_seconds = _parameter("flip_recovery_seconds", DEFAULT_FLIP_RECOVERY_SECONDS)
	mass = _parameter("robot_mass", DEFAULT_MASS)
	gravity_scale = _parameter("gravity_scale", DEFAULT_GRAVITY_SCALE)
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0.0, _parameter("center_of_mass_y", DEFAULT_COM_Y), 0.0)
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = _parameter("linear_damp", DEFAULT_LINEAR_DAMP)
	angular_damp = _parameter("angular_damp", DEFAULT_ANGULAR_DAMP)
	can_sleep = false
	for child: Node in get_children():
		if child is SuspensionWheel:
			var wheel: SuspensionWheel = child as SuspensionWheel
			_wheels.append(wheel)
			wheel.configure(self, _parameter("suspension_rest", DEFAULT_REST),
				_parameter("wheel_radius", DEFAULT_RADIUS),
				_parameter("suspension_stiffness", DEFAULT_STIFFNESS),
				_parameter("suspension_damping", DEFAULT_DAMPING),
				_parameter("wheel_grip", DEFAULT_GRIP),
				_parameter("suspension_force_limit", DEFAULT_FORCE_LIMIT))


func _parameter(key: String, fallback: float) -> float:
	return float(_parameters.get(key, fallback))


func set_move_input(v: Vector2) -> void:
	_move_input = v.limit_length(1.0)


## Hedef hızı çarpar (batarya boşaldıkça yavaşlar). Negatif değer 0 sayılır;
## `max_speed()` raporlanan tavan olarak değişmez (§5.2).
func set_speed_factor(f: float) -> void:
	_speed_factor = maxf(f, 0.0)


func speed() -> float:
	return Vector2(linear_velocity.x, linear_velocity.z).length()


func max_speed() -> float:
	return _top_speed


func is_grounded() -> bool:
	return _grounded


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var body_transform: Transform3D = state.transform
	var up_dot: float = body_transform.basis.y.normalized().dot(Vector3.UP)
	if up_dot >= _flip_recovery_up_dot:
		_flipped_seconds = 0.0
		return
	_flipped_seconds += state.step
	if _flipped_seconds < _flip_recovery_seconds:
		return
	var heading: Vector3 = -body_transform.basis.z
	heading.y = 0.0
	if heading.is_zero_approx():
		# A vertical forward axis has no yaw; the right axis still defines one.
		heading = Vector3.UP.cross(body_transform.basis.x)
	var yaw: float = atan2(-heading.x, -heading.z)
	body_transform.basis = Basis(Vector3.UP, yaw)
	# Direct state keeps the reset synchronized with physics and retains the origin.
	state.transform = body_transform
	state.linear_velocity = Vector3.ZERO
	state.angular_velocity = Vector3.ZERO
	_flipped_seconds = 0.0
	physics_reset.emit()


func _physics_process(delta: float) -> void:
	_smoothed_input = _smoothed_input.lerp(_move_input, 1.0 - exp(-_input_response * delta))
	_grounded = false
	var normal: Vector3 = Vector3.ZERO
	for wheel: SuspensionWheel in _wheels:
		wheel.simulate()
		if wheel.grounded:
			_grounded = true
			normal += wheel.ground_normal
	var desired_up: Vector3 = normal.normalized() if _grounded else Vector3.UP
	var tilt_velocity: Vector3 = angular_velocity - Vector3.UP * angular_velocity.y
	var balance: float = _upright if _grounded else _air_balance
	# Yaylar eğime tepki verir; sınırlı PD torku kilitlemeden devrilmeyi bastırır.
	apply_torque((global_basis.y.cross(desired_up) * balance
		- tilt_velocity * _upright_damping) * mass)
	if not _grounded:
		return
	var forward: Vector3 = -global_basis.z.slide(desired_up).normalized()
	var longitudinal_speed: float = linear_velocity.dot(forward)
	var target_speed: float = _smoothed_input.y * _top_speed * _speed_factor
	var acceleration: float = clampf((target_speed - longitudinal_speed) * _speed_response,
		-_accel, _accel)
	if is_zero_approx(_move_input.y):
		acceleration = -longitudinal_speed * _brake
	apply_central_force(forward * acceleration * mass)
	var speed_ratio: float = clampf(speed() / maxf(_top_speed, MIN_SPEED), 0.0, 1.0)
	var desired_yaw: float = (-_smoothed_input.x * _turn_rate * speed_ratio
		/ (1.0 + speed_ratio * _steer_speed_factor))
	apply_torque(Vector3.UP * (desired_yaw - angular_velocity.y) * mass * _steering_response)
