class_name RollingPencil
extends RigidBody3D

@export var travel_direction: Vector3 = Vector3.LEFT

var _parameters: Dictionary[String, Variant] = {}
var _start_transform: Transform3D = Transform3D.IDENTITY
var _direction: Vector3 = Vector3.LEFT
var _rolling_velocity: Vector3 = Vector3.ZERO
var _rolling_angular_velocity: Vector3 = Vector3.ZERO
var _speed: float = 0.0
var _travel_distance: float = 0.0
var _period: float = 0.0
var _base_period: float = 0.0
var _elapsed: float = 0.0
var _lane_min: float = 0.0
var _lane_max: float = 0.0
var _side: float = 1.0
var _moving: bool = true


func _ready() -> void:
	add_to_group("hazard")
	add_to_group("rolling_pencil")
	var data: Node = get_node_or_null("/root/GameData")
	if data != null:
		var found: Variant = data.call("value", "balance", "hazards", null)
		if found is Dictionary:
			_parameters.assign(found)
	_speed = maxf(_parameter("pencil_speed", 1.3), 0.0)
	_period = maxf(_parameter("pencil_period_seconds", 5.0), 0.001)
	_base_period = _period
	_lane_min = maxf(_parameter("pencil_lane_min_x", 2.1),
		_parameter("pencil_center_clearance", 1.5))
	_lane_max = maxf(_parameter("pencil_lane_max_x", 4.4), _lane_min)
	_start_transform = global_transform
	_side = -1.0 if _start_transform.origin.x < 0.0 else 1.0
	_start_transform.origin.x = _side * clampf(absf(_start_transform.origin.x), _lane_min, _lane_max)
	# The mesh's long axis is Z; only X travel is allowed in the side lane.
	_direction = Vector3.LEFT if travel_direction.x <= 0.0 else Vector3.RIGHT
	var available_distance: float = _lane_max - absf(_start_transform.origin.x)
	if _direction.x * _side < 0.0:
		available_distance = absf(_start_transform.origin.x) - _lane_min
	_travel_distance = clampf(_parameter("pencil_travel_distance", 2.0), 0.0, available_distance)
	_rolling_velocity = _direction * _speed
	var radius: float = maxf(_parameter("pencil_radius", 0.265), 0.001)
	_rolling_angular_velocity = Vector3.UP.cross(_direction) * (_speed / radius)
	mass = maxf(_parameter("pencil_mass", 2.0), 0.001)
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp = 0.0
	can_sleep = false
	continuous_cd = true
	axis_lock_angular_x = true
	axis_lock_angular_y = true
	axis_lock_linear_z = true


## Sonsuz mod: level zorluğu geçiş döngüsünü sıklaştırır (en az 1 sn).
func apply_difficulty(params: Dictionary) -> void:
	_period = maxf(_base_period * float(params.get("cycle_scale", 1.0)), 1.0)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	_elapsed += state.step
	if _elapsed >= _period:
		_elapsed = fposmod(_elapsed, _period)
		_moving = true
		_reset_state(state)
	var body_transform: Transform3D = state.transform
	var side_x: float = body_transform.origin.x * _side
	var distance: float = (body_transform.origin - _start_transform.origin).dot(_direction)
	var next_side_x: float = (body_transform.origin.x + _rolling_velocity.x * state.step) * _side
	if side_x < _lane_min or side_x > _lane_max:
		# Emergency lane recovery is synchronized with physics, never a freeze.
		_reset_state(state)
		_moving = false
	elif _moving and (distance >= _travel_distance or next_side_x < _lane_min or next_side_x > _lane_max):
		# Keep the full traverse visible until the next scheduled launch.
		body_transform.origin.x = _start_transform.origin.x + _direction.x * _travel_distance
		state.transform = body_transform
		_moving = false
	if _moving:
		var velocity: Vector3 = state.linear_velocity
		velocity.x = _rolling_velocity.x
		velocity.z = 0.0
		state.linear_velocity = velocity
		state.angular_velocity = _rolling_angular_velocity
	else:
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO


func _reset_state(state: PhysicsDirectBodyState3D) -> void:
	state.transform = _start_transform
	state.linear_velocity = Vector3.ZERO
	state.angular_velocity = Vector3.ZERO
	state.sleeping = false


func _parameter(key: String, fallback: float) -> float:
	return float(_parameters.get(key, fallback))
