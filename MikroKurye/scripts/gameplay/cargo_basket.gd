class_name CargoBasket
extends RigidBody3D

signal impact_reported(impulse: float)
signal slosh_reported(angular_accel: float, dt: float)

const DEFAULT_MASS: float = 4.5
const DEFAULT_SPRING: float = 24.0
const DEFAULT_DAMPING: float = 5.0
const DEFAULT_LIMIT_DEG: float = 28.0
const DEFAULT_ACCEL_RESPONSE: float = 0.6
const DEFAULT_ANGULAR_RESPONSE: float = 0.35
const DEFAULT_ATTACH_DISTANCE: float = 1.2
const DEFAULT_ATTACH_ANGLE_MARGIN: float = 8.0
const DEFAULT_TELEPORT_DISTANCE: float = 2.0
const DEFAULT_TELEPORT_ANGLE_DEG: float = 45.0
const DEFAULT_VELOCITY_RESET: float = 6.0
const DEFAULT_IMPACT_REARM_SECONDS: float = 0.2
const DEFAULT_IMPACT_MIN: float = 0.1
const CONTACT_COUNT: int = 8

var _robot: RigidBody3D
var _mount: Transform3D
var _previous_robot_position: Vector3 = Vector3.ZERO
var _previous_robot_velocity: Vector3 = Vector3.ZERO
var _previous_robot_spin: Vector3 = Vector3.ZERO
var _previous_world_spin: Vector3 = Vector3.ZERO
var _angles: Vector3 = Vector3.ZERO
var _sway_velocity: Vector3 = Vector3.ZERO
var _spring: float = DEFAULT_SPRING
var _damping: float = DEFAULT_DAMPING
var _limit_deg: float = DEFAULT_LIMIT_DEG
var _limit_rad: float = 0.0
var _accel_response: float = DEFAULT_ACCEL_RESPONSE
var _angular_response: float = DEFAULT_ANGULAR_RESPONSE
var _attach_distance: float = DEFAULT_ATTACH_DISTANCE
var _attach_margin: float = DEFAULT_ATTACH_ANGLE_MARGIN
var _teleport_distance: float = DEFAULT_TELEPORT_DISTANCE
var _parameters: Dictionary[String, Variant] = {}
var _previous_robot_basis: Basis = Basis.IDENTITY
var _reset_pending: bool = true
var _teleport_angle: float = deg_to_rad(DEFAULT_TELEPORT_ANGLE_DEG)
var _velocity_reset: float = DEFAULT_VELOCITY_RESET
var _impact_rearm: float = DEFAULT_IMPACT_REARM_SECONDS
var _impact_min: float = DEFAULT_IMPACT_MIN
var _contact_ids: Array[int] = []
var _contact_ages: Array[float] = []
var _contact_reported: Array[bool] = []
var _contact_impulses: Array[float] = []


func _ready() -> void:
	add_to_group("cargo")
	_robot = get_parent() as RigidBody3D
	if _robot == null:
		push_error("CargoBasket requires a RigidBody3D parent mount")
		freeze = true
		process_mode = Node.PROCESS_MODE_DISABLED
		return
	_mount = transform
	# Preserve the authored mount, but never inherit a moving physics body's transform.
	var world_mount: Transform3D = global_transform
	top_level = true
	global_transform = world_mount
	if _robot.has_signal("physics_reset"):
		_robot.connect("physics_reset", reset_sway)
	_contact_ids.resize(CONTACT_COUNT)
	_contact_ages.resize(CONTACT_COUNT)
	_contact_reported.resize(CONTACT_COUNT)
	_contact_impulses.resize(CONTACT_COUNT)
	_contact_ages.fill(INF)
	var data: Node = get_node_or_null("/root/GameData")
	if data != null:
		var found: Variant = data.call("value", "balance", "physics", null)
		if found is Dictionary:
			_parameters.assign(found)
	mass = _parameter("cargo_mass", DEFAULT_MASS)
	_spring = _parameter("cargo_spring", DEFAULT_SPRING)
	_damping = _parameter("cargo_damping", DEFAULT_DAMPING)
	_limit_deg = _parameter("cargo_joint_limit_deg", DEFAULT_LIMIT_DEG)
	_limit_rad = deg_to_rad(_limit_deg)
	_accel_response = _parameter("cargo_accel_response", DEFAULT_ACCEL_RESPONSE)
	_angular_response = _parameter("cargo_angular_response", DEFAULT_ANGULAR_RESPONSE)
	_attach_distance = _parameter("cargo_attach_distance", DEFAULT_ATTACH_DISTANCE)
	_attach_margin = _parameter("cargo_attach_angle_margin_deg", DEFAULT_ATTACH_ANGLE_MARGIN)
	_teleport_distance = _parameter("cargo_teleport_distance", DEFAULT_TELEPORT_DISTANCE)
	_teleport_angle = deg_to_rad(_parameter("cargo_teleport_angle_deg", DEFAULT_TELEPORT_ANGLE_DEG))
	_velocity_reset = _parameter("cargo_velocity_reset_threshold", DEFAULT_VELOCITY_RESET)
	_impact_rearm = _parameter("cargo_impact_rearm_seconds", DEFAULT_IMPACT_REARM_SECONDS)
	_impact_min = _parameter("cargo_impact_min_impulse", DEFAULT_IMPACT_MIN)
	# The mount is solved explicitly, so gravity/engine damping must not integrate it twice.
	custom_integrator = true
	gravity_scale = 0.0
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp = 0.0
	can_sleep = false
	contact_monitor = true
	max_contacts_reported = CONTACT_COUNT
	add_collision_exception_with(_robot)


func _parameter(key: String, fallback: float) -> float:
	return float(_parameters.get(key, fallback))


## Şasi yükseltmesi: sönüm artar, sallanma daha çabuk söner. GameController
## `SaveService.mods()` toplamını bir kez uygular.
func add_damping_bonus(bonus: float) -> void:
	_damping += maxf(bonus, 0.0)


func reset_sway() -> void:
	# Checkpoint/recovery callers must not turn a pose reset into physical slosh.
	_reset_pending = true


func sway_angle_deg() -> float:
	if not is_instance_valid(_robot):
		return 0.0
	return rad_to_deg(global_basis.y.angle_to(_robot.global_basis.y))


func is_attached() -> bool:
	return (is_instance_valid(_robot)
		and global_position.distance_to(_robot.global_position) <= _attach_distance
		and sway_angle_deg() <= _limit_deg + _attach_margin)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if not is_instance_valid(_robot):
		return
	var dt: float = state.step
	var moved: bool = (_reset_pending
		or _robot.global_position.distance_to(_previous_robot_position) > _teleport_distance
		or _robot.global_basis.get_rotation_quaternion().angle_to(
			_previous_robot_basis.get_rotation_quaternion()) > _teleport_angle
		or _robot.linear_velocity.distance_to(_previous_robot_velocity) > _velocity_reset)
	var local_accel: Vector3 = _robot.global_basis.inverse() * ((_robot.linear_velocity - _previous_robot_velocity) / dt)
	var local_angular_accel: Vector3 = _robot.global_basis.inverse() * ((_robot.angular_velocity - _previous_robot_spin) / dt)
	if moved:
		# A checkpoint jump is not physical acceleration and must not inject spring energy.
		_angles = Vector3.ZERO
		_sway_velocity = Vector3.ZERO
		local_accel = Vector3.ZERO
		local_angular_accel = Vector3.ZERO
	# Up tilts opposite translation; angular inertia likewise opposes the mount's rotation.
	var forcing: Vector3 = Vector3(-local_accel.z, 0.0, local_accel.x) * _accel_response
	forcing -= Vector3(local_angular_accel.x, 0.0, local_angular_accel.z) * _angular_response
	# Inertia-normalized coefficients keep the feel independent of the collision body's mass.
	var acceleration: Vector3 = forcing - _angles * _spring - _sway_velocity * _damping
	_sway_velocity += acceleration * dt
	_angles += _sway_velocity * dt
	if _angles.length() > _limit_rad:
		_angles = _angles.limit_length(_limit_rad)
		var outward_speed: float = _sway_velocity.dot(_angles.normalized())
		if outward_speed > 0.0:
			_sway_velocity -= _angles.normalized() * outward_speed
	var target: Transform3D = _robot.global_transform * _mount
	target.basis *= Basis.from_euler(_angles)
	# Keeping the body dynamic preserves real solver contact impulses for damage measurement.
	state.transform = target
	state.linear_velocity = _robot.linear_velocity + _robot.angular_velocity.cross(target.origin - _robot.global_position)
	state.angular_velocity = _robot.angular_velocity + _robot.global_basis * _sway_velocity
	var angular_accel: float = (state.angular_velocity - _previous_world_spin).length() / dt
	if moved:
		angular_accel = 0.0
	slosh_reported.emit(angular_accel, dt)
	_previous_world_spin = state.angular_velocity
	_previous_robot_position = _robot.global_position
	_previous_robot_velocity = _robot.linear_velocity
	_previous_robot_spin = _robot.angular_velocity
	_previous_robot_basis = _robot.global_basis
	_reset_pending = false
	_report_contacts(state)


func _report_contacts(state: PhysicsDirectBodyState3D) -> void:
	for slot: int in range(CONTACT_COUNT):
		_contact_ages[slot] += state.step
		_contact_impulses[slot] = 0.0
	for contact: int in range(state.get_contact_count()):
		var collider_id: int = state.get_contact_collider_id(contact)
		var slot: int = _contact_ids.find(collider_id)
		if slot < 0:
			# Fixed slots avoid per-frame containers; only stale contacts may be replaced.
			for candidate: int in range(CONTACT_COUNT):
				if _contact_ages[candidate] > _impact_rearm:
					slot = candidate
					_contact_ids[slot] = collider_id
					break
		if slot < 0:
			continue
		if _contact_ages[slot] > _impact_rearm:
			_contact_reported[slot] = false
		_contact_ages[slot] = 0.0
		_contact_impulses[slot] += state.get_contact_impulse(contact).length()
	for slot: int in range(CONTACT_COUNT):
		if not _contact_reported[slot] and _contact_impulses[slot] >= _impact_min:
			_contact_reported[slot] = true
			impact_reported.emit(_contact_impulses[slot])
