class_name SuspensionWheel
extends Node3D

const WHEEL_COUNT: float = 4.0
const MIN_LENGTH: float = 0.001

var grounded: bool = false
var ground_normal: Vector3 = Vector3.UP
var _body: RigidBody3D
var _ray: RayCast3D
var _rest: float = 0.0
var _radius: float = 0.0
var _stiffness: float = 0.0
var _damping: float = 0.0
var _grip: float = 0.0
var _base_grip: float = 0.0
var _force_limit: float = 0.0
@onready var _visual: MeshInstance3D = get_node("Visual") as MeshInstance3D


func configure(body: RigidBody3D, rest: float, radius: float, stiffness: float,
		damping: float, grip: float, force_limit: float) -> void:
	_body = body
	_rest = rest
	_radius = radius
	_stiffness = stiffness
	_damping = damping
	_grip = grip
	_base_grip = grip
	_force_limit = force_limit
	_ray = get_node("RayCast3D") as RayCast3D
	_ray.target_position = Vector3.DOWN * (_rest + _radius)
	_ray.add_exception(body)


## Tekerlek yükseltmesi: yanal tutuş artar (RobotController dört tekerleğe uygular).
func add_grip_bonus(bonus: float) -> void:
	_grip += maxf(bonus, 0.0)


func set_grip_bonus(bonus: float) -> void:
	_grip = _base_grip + maxf(bonus, 0.0)


func simulate() -> void:
	_ray.force_raycast_update()
	grounded = _ray.is_colliding()
	if not grounded:
		_visual.position.y = -_rest
		return
	ground_normal = _ray.get_collision_normal()
	var hit: Vector3 = _ray.get_collision_point()
	var offset: Vector3 = hit - _body.global_position
	var point_velocity: Vector3 = _body.linear_velocity + _body.angular_velocity.cross(
		hit - _body.to_global(_body.center_of_mass))
	var distance: float = global_position.distance_to(hit)
	var compression: float = maxf(_rest + _radius - distance, 0.0)
	var force: float = clampf(compression * _stiffness
		- point_velocity.dot(ground_normal) * _damping, 0.0, _force_limit)
	_body.apply_force(ground_normal * force, offset)
	var sideways: Vector3 = _body.global_basis.x.slide(ground_normal).normalized()
	# Merkezi yanal kuvvet, tutuşun gövdeyi yapay biçimde devirmesini önler.
	_body.apply_central_force(-sideways * _body.linear_velocity.dot(sideways)
		* _grip * _body.mass / WHEEL_COUNT)
	_visual.position.y = -maxf(distance - _radius, MIN_LENGTH)
