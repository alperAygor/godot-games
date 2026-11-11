class_name CargoJointTrial
extends RigidBody3D

## Isolated solver alternative; never installed in the production scene.
signal impact_reported(impulse: float)
signal slosh_reported(angular_accel: float, dt: float)

const DEFAULT_MASS: float = 4.5
const DEFAULT_SPRING: float = 24.0
const DEFAULT_DAMPING: float = 5.0
const DEFAULT_LIMIT_DEG: float = 28.0
const DEFAULT_ATTACH_DISTANCE: float = 1.2
const DEFAULT_ANGLE_MARGIN: float = 8.0
const DEFAULT_TELEPORT_DISTANCE: float = 2.0
const CONTACT_COUNT: int = 8

var _robot: RigidBody3D
var _mount: Transform3D
var _previous_position: Vector3 = Vector3.ZERO
var _previous_spin: Vector3 = Vector3.ZERO
var _parameters: Dictionary[String, Variant] = {}
var _joint: Generic6DOFJoint3D
var _attach_distance: float = DEFAULT_ATTACH_DISTANCE
var _limit_deg: float = DEFAULT_LIMIT_DEG
var _margin: float = DEFAULT_ANGLE_MARGIN
var _teleport_distance: float = DEFAULT_TELEPORT_DISTANCE


func _ready() -> void:
	_robot = get_parent() as RigidBody3D
	_mount = transform
	var mount_world: Transform3D = _robot.global_transform * _mount
	top_level = true
	global_transform = mount_world
	add_to_group("cargo")
	var data: Node = get_node_or_null("/root/GameData")
	if data != null:
		var found: Variant = data.call("value", "balance", "physics", null)
		if found is Dictionary:
			_parameters.assign(found)
	mass = _parameter("cargo_mass", DEFAULT_MASS)
	_limit_deg = _parameter("cargo_joint_limit_deg", DEFAULT_LIMIT_DEG)
	_attach_distance = _parameter("cargo_attach_distance", DEFAULT_ATTACH_DISTANCE)
	_margin = _parameter("cargo_attach_angle_margin_deg", DEFAULT_ANGLE_MARGIN)
	_teleport_distance = _parameter("cargo_teleport_distance", DEFAULT_TELEPORT_DISTANCE)
	can_sleep = false
	contact_monitor = true
	max_contacts_reported = CONTACT_COUNT
	add_collision_exception_with(_robot)
	_previous_position = _robot.global_position
	_build_joint.call_deferred()


func _build_joint() -> void:
	_joint = Generic6DOFJoint3D.new()
	_joint.name = "CargoJointTrialConstraint"
	_robot.add_child(_joint)
	var collision: CollisionShape3D = get_node("CollisionShape3D") as CollisionShape3D
	var box: BoxShape3D = collision.shape as BoxShape3D
	# Mount the basket at its lower face so acceleration generates physical torque.
	_joint.global_position = global_position - global_basis.y * box.size.y * 0.5
	_joint.node_a = _joint.get_path_to(_robot)
	_joint.node_b = _joint.get_path_to(self)
	var stiffness: float = _parameter("cargo_spring", DEFAULT_SPRING)
	var damping: float = _parameter("cargo_damping", DEFAULT_DAMPING)
	var limit: float = deg_to_rad(_limit_deg)
	_joint.set_param_x(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, -limit)
	_joint.set_param_x(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, limit)
	_joint.set_param_z(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, -limit)
	_joint.set_param_z(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, limit)
	_joint.set_flag_x(Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_SPRING, true)
	_joint.set_flag_z(Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_SPRING, true)
	_joint.set_param_x(Generic6DOFJoint3D.PARAM_ANGULAR_SPRING_STIFFNESS, stiffness)
	_joint.set_param_z(Generic6DOFJoint3D.PARAM_ANGULAR_SPRING_STIFFNESS, stiffness)
	_joint.set_param_x(Generic6DOFJoint3D.PARAM_ANGULAR_SPRING_DAMPING, damping)
	_joint.set_param_z(Generic6DOFJoint3D.PARAM_ANGULAR_SPRING_DAMPING, damping)


func _parameter(key: String, fallback: float) -> float:
	return float(_parameters.get(key, fallback))


func sway_angle_deg() -> float:
	return rad_to_deg(global_basis.y.angle_to(_robot.global_basis.y))


func is_attached() -> bool:
	return global_position.distance_to(_robot.global_position) <= _attach_distance and sway_angle_deg() <= _limit_deg + _margin


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	# The protected probe teleports only the robot; reset cargo once, not every step.
	var reset: bool = _robot.global_position.distance_to(_previous_position) > _teleport_distance
	if reset:
		state.transform = _robot.global_transform * _mount
		state.linear_velocity = _robot.linear_velocity
		state.angular_velocity = _robot.angular_velocity
	var angular_accel: float = (state.angular_velocity - _previous_spin).length() / state.step
	if not reset:
		slosh_reported.emit(angular_accel, state.step)
	# Impact damage is deliberately uninstrumented: this fixture compares sway only.
	_previous_spin = state.angular_velocity
	_previous_position = _robot.global_position
