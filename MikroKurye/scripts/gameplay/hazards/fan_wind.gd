class_name FanWind
extends Area3D

@export var direction: Vector3 = Vector3.LEFT

var _parameters: Dictionary[String, Variant] = {}
var _bodies: Array[RigidBody3D] = []
var _direction: Vector3 = Vector3.LEFT
var _acceleration: float = 0.0
var _base_acceleration: float = 0.0
var _base_cycle: float = 0.0
var _blow_fraction: float = 0.55
var _cycle_seconds: float = 0.0
var _blow_seconds: float = 0.0
var _phase: float = 0.0
var _blowing: bool = false


func _ready() -> void:
	add_to_group("hazard")
	add_to_group("fan_wind")
	var data: Node = get_node_or_null("/root/GameData")
	if data != null:
		var found: Variant = data.call("value", "balance", "hazards", null)
		if found is Dictionary:
			_parameters.assign(found)
	_acceleration = maxf(_parameter("fan_accel", 4.0), 0.0)
	_cycle_seconds = maxf(_parameter("fan_cycle_seconds", 4.0), 0.001)
	_blow_fraction = clampf(_parameter("fan_blow_fraction", 0.55), 0.0, 1.0)
	_blow_seconds = _cycle_seconds * _blow_fraction
	_base_acceleration = _acceleration
	_base_cycle = _cycle_seconds
	_direction = direction.normalized() if not direction.is_zero_approx() else Vector3.LEFT
	_blowing = _phase < _blow_seconds
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


## Sonsuz mod: level zorluğu döngüyü kısaltır, rüzgârı güçlendirir.
func apply_difficulty(params: Dictionary) -> void:
	_cycle_seconds = maxf(_base_cycle * float(params.get("cycle_scale", 1.0)), 0.5)
	_blow_seconds = _cycle_seconds * _blow_fraction
	_acceleration = _base_acceleration * float(params.get("fan_scale", 1.0))
	_phase = fposmod(_phase, _cycle_seconds)


func is_blowing() -> bool:
	return _blowing


func wind_direction() -> Vector3:
	return _direction


func _physics_process(delta: float) -> void:
	_phase = fposmod(_phase + delta, _cycle_seconds)
	_blowing = _phase < _blow_seconds
	if not _blowing:
		return
	# Signals maintain this cache: no overlapping-body arrays are built per tick.
	for body: RigidBody3D in _bodies:
		if is_instance_valid(body):
			# F = m*a keeps the acceleration equal for robot, basket and loose cargo.
			body.apply_central_force(_direction * (body.mass * _acceleration))


func _on_body_entered(body: Node3D) -> void:
	if body is RigidBody3D:
		var rigid_body: RigidBody3D = body as RigidBody3D
		if not _bodies.has(rigid_body):
			_bodies.append(rigid_body)


func _on_body_exited(body: Node3D) -> void:
	if body is RigidBody3D:
		_bodies.erase(body as RigidBody3D)


func _parameter(key: String, fallback: float) -> float:
	return float(_parameters.get(key, fallback))
