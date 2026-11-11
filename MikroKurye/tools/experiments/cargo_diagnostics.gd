class_name CargoPhysicsDiagnostics
extends SceneTree

## Run: godot --headless --path . -s res://tools/experiments/cargo_diagnostics.gd
## Scope exception: this standalone physics diagnostic lives beside gameplay because
## tools/tests are protected. Output is diagnostic-only, never production logging.

const DEADLINE_MS: int = 45000
const STEP: float = 1.0 / 60.0
const SIGNAL_EPSILON: float = 0.001
const SIGN_EPSILON: float = 0.01
const SETTLE_FRAMES: int = 180
const FIXTURE_FRAMES: int = 45
const FIXTURE_ACCEL: float = 6.0
const FIXTURE_ANGULAR_ACCEL: float = 3.0
const SPEED_MARGIN: float = 1.35
const SLOSH_SAFETY_BOUND: float = 200.0
# A 10 kg plate falling at ~5 m/s cannot justify an unbounded contact report.
const IMPULSE_SAFETY_BOUND: float = 200.0
const REST_TOTAL_BOUND: float = 200.0
const REST_EVENT_BOUND: int = 4

var _started_ms: int = 0
var _failures: Array[String] = []
var _robot: RobotController
var _cargo: RigidBody3D
var _scene: Node3D
var _slosh_count: int = 0
var _impact_count: int = 0
var _peak_slosh: float = 0.0
var _window_slosh: float = 0.0
var _peak_impulse: float = 0.0
var _total_impulse: float = 0.0
var _peak_cargo_speed: float = 0.0
var _bad_signal: bool = false
var _normal_air_balance: float = 0.0
var _normal_upright_damping: float = 0.0


func _initialize() -> void:
	_started_ms = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - _started_ms > DEADLINE_MS:
		push_error("CARGO_CHECK timeout after %d ms" % DEADLINE_MS)
		quit(2)
	return false


func _on_slosh(accel: float, dt: float) -> void:
	_slosh_count += 1
	_peak_slosh = maxf(_peak_slosh, accel)
	_window_slosh = maxf(_window_slosh, accel)
	_bad_signal = _bad_signal or not is_finite(accel) or accel < 0.0 or not is_equal_approx(dt, STEP)


func _on_impact(impulse: float) -> void:
	_impact_count += 1
	_peak_impulse = maxf(_peak_impulse, impulse)
	_total_impulse += impulse
	_bad_signal = _bad_signal or not is_finite(impulse) or impulse < 0.0


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
		push_error("CARGO_CHECK failed: " + label)


func _setup_error(message: String) -> void:
	push_error("CARGO_CHECK setup: " + message)
	quit(2)


func _frames(count: int) -> void:
	for frame: int in range(count):
		await physics_frame
		_peak_cargo_speed = maxf(_peak_cargo_speed, _cargo.linear_velocity.length())


func _local_up() -> Vector3:
	return _robot.global_basis.inverse() * _cargo.global_basis.y.normalized()


func _reset_fixture(yaw: float = 0.0) -> void:
	_robot.global_transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(10.0, 10.0, 0.0))
	_robot.linear_velocity = Vector3.ZERO
	_robot.angular_velocity = Vector3.ZERO
	_cargo.call("reset_sway")
	await _frames(3)


func _velocity_ramp(direction: Vector3) -> Vector3:
	for frame: int in range(FIXTURE_FRAMES):
		_robot.linear_velocity = _robot.global_basis * direction * FIXTURE_ACCEL * STEP * float(frame + 1)
		await _frames(1)
	return _local_up()


func _run() -> void:
	if Engine.physics_ticks_per_second != 60:
		_setup_error("requires 60 Hz physics")
		return
	var packed: PackedScene = load("res://scenes/Proto.tscn") as PackedScene
	if packed == null:
		_setup_error("Proto.tscn did not load")
		return
	_scene = packed.instantiate() as Node3D
	if _scene == null:
		_setup_error("Proto root must be Node3D")
		return
	root.add_child(_scene)
	_robot = _scene.get_node_or_null("Robot") as RobotController
	_cargo = _scene.get_node_or_null("Robot/CargoBasket") as RigidBody3D
	if _robot == null or _cargo == null:
		_setup_error("requires Robot and Robot/CargoBasket rigid bodies")
		return
	if not _cargo.has_method("reset_sway") or not _cargo.has_method("is_attached") or not _cargo.has_method("sway_angle_deg"):
		_setup_error("cargo requires reset_sway(), is_attached(), sway_angle_deg()")
		return
	if not _cargo.has_signal("slosh_reported") or not _cargo.has_signal("impact_reported"):
		_setup_error("cargo measurement signals missing")
		return
	_cargo.connect("slosh_reported", _on_slosh)
	_cargo.connect("impact_reported", _on_impact)
	_check(_cargo.top_level and _cargo.get_parent() == _robot, "cargo top_level preserves Robot parent path")
	await _frames(SETTLE_FRAMES)
	_check(bool(_cargo.call("is_attached")), "settled cargo attached")
	_robot.set_move_input(Vector2(0.0, 1.0))
	await _frames(90)
	_robot.set_move_input(Vector2(0.7, 1.0))
	var turn_accel_x: float = 0.0
	var turn_up_x: float = 0.0
	var turn_samples: int = 0
	var previous_velocity: Vector3 = _robot.linear_velocity
	for frame: int in range(75):
		await _frames(1)
		var local_accel: Vector3 = _robot.global_basis.inverse() * ((_robot.linear_velocity - previous_velocity) / STEP)
		previous_velocity = _robot.linear_velocity
		# Late samples avoid demanding zero-lag spring response at steering onset.
		if frame >= 40:
			turn_accel_x += local_accel.x
			turn_up_x += _local_up().x
			turn_samples += 1
	turn_accel_x /= float(turn_samples)
	turn_up_x /= float(turn_samples)
	_check(absf(turn_accel_x) > 0.5 and turn_up_x * turn_accel_x < -SIGN_EPSILON, "real turn sway points outward against centripetal acceleration")
	print("TURN_CHECK local_accel_x=%.5f cargo_up_x=%.5f" % [turn_accel_x, turn_up_x])
	_robot.set_move_input(Vector2.ZERO)
	await _frames(SETTLE_FRAMES)
	var driven_slosh: float = _peak_slosh
	_window_slosh = 0.0
	await _frames(120)
	var decayed_slosh: float = _window_slosh
	_check(driven_slosh > SIGN_EPSILON and driven_slosh <= SLOSH_SAFETY_BOUND, "nonzero bounded driving slosh")
	_check(decayed_slosh < maxf(SIGNAL_EPSILON, driven_slosh * 0.05), "slosh decays after stop")
	_check(_peak_cargo_speed <= _robot.max_speed() * SPEED_MARGIN, "cargo speed bounded relative to robot max_speed")
	print("DRIVE_CHECK slosh_peak=%.4f decay=%.6f cargo_speed=%.4f max_speed=%.4f" % [driven_slosh, decayed_slosh, _peak_cargo_speed, _robot.max_speed()])

	# Frozen robot gives controlled kinematics without suspension/ground noise.
	_normal_air_balance = float(_robot.get("_air_balance"))
	_normal_upright_damping = float(_robot.get("_upright_damping"))
	_robot.set_physics_process(false)
	_robot.freeze = true
	await _reset_fixture()
	var acceleration_up: Vector3 = await _velocity_ramp(Vector3.FORWARD)
	_check(acceleration_up.z > SIGN_EPSILON, "acceleration tilts robot-local up rearward (+z)")
	await _reset_fixture()
	var braking_up: Vector3 = await _velocity_ramp(Vector3.BACK)
	_check(braking_up.z < -SIGN_EPSILON, "braking tilts robot-local up forward (-z)")
	await _reset_fixture(PI / 2.0)
	var lateral_up: Vector3 = await _velocity_ramp(Vector3.RIGHT)
	_check(lateral_up.x < -SIGN_EPSILON, "turn acceleration tilts outward opposite local +x at rotated heading")
	_check(float(_cargo.call("sway_angle_deg")) <= float(_cargo.get("_limit_deg")) + SIGNAL_EPSILON, "sway remains within configured angular limit")
	await _reset_fixture()
	for frame: int in range(FIXTURE_FRAMES):
		_robot.angular_velocity = Vector3.RIGHT * FIXTURE_ANGULAR_ACCEL * STEP * float(frame + 1)
		await _frames(1)
	var angular_up: Vector3 = _local_up()
	_check(angular_up.z < -SIGN_EPSILON, "positive robot pitch acceleration produces opposing relative cargo pitch")
	print("SIGNED_SWAY accel_z=%.5f brake_z=%.5f lateral_x=%.5f angular_z=%.5f" % [acceleration_up.z, braking_up.z, lateral_up.x, angular_up.z])

	# Query before the next solver step: attachment must measure the actual body,
	# not merely a cached spring angle that silently hides external displacement.
	_cargo.global_position += Vector3(5.0, 0.0, 0.0)
	_check(not bool(_cargo.call("is_attached")), "externally displaced cargo is not attached")
	await _reset_fixture()
	_robot.global_basis = Basis(Vector3.UP, PI / 2.0)
	_robot.angular_velocity = Vector3(0.0, 2.0, 0.0)
	_cargo.call("reset_sway")
	_window_slosh = 0.0
	await _frames(3)
	_check(_window_slosh <= SIGNAL_EPSILON, "reset_sway after rotation suppresses artificial slosh")
	_check(bool(_cargo.call("is_attached")), "reset restores attachment")
	print("RESET_CHECK slosh=%.6f attached=%s" % [_window_slosh, str(_cargo.call("is_attached"))])

	await _contact_fixture()
	await _flip_fixture(99.0, false)
	await _flip_fixture(101.0, true)
	await _ground_flip_fixture()
	_check(_slosh_count > 0 and not _bad_signal, "signals finite, nonnegative, fixed dt")
	_check(_peak_slosh <= SLOSH_SAFETY_BOUND, "all slosh bounded including resets")
	print("CARGO_CHECK slosh=%d impacts=%d impulse_peak=%.4f total=%.4f invalid=%s failures=%s" % [_slosh_count, _impact_count, _peak_impulse, _total_impulse, str(_bad_signal), str(_failures)])
	print("CARGO_CHECK result=%s" % str(_failures.is_empty()))
	quit(0 if _failures.is_empty() else 1)


func _contact_fixture() -> void:
	await _reset_fixture()
	var plate: RigidBody3D = RigidBody3D.new()
	plate.mass = 10.0
	plate.can_sleep = false
	var collision: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(1.0, 0.08, 1.0)
	collision.shape = box
	plate.add_child(collision)
	_scene.add_child(plate)
	plate.global_position = _cargo.global_position + Vector3(0.0, 0.8, 0.0)
	plate.linear_velocity = Vector3(0.0, -3.0, 0.0)
	var before_impacts: int = _impact_count
	await _frames(45)
	var resting_start: float = _total_impulse
	var resting_count: int = _impact_count
	await _frames(180)
	var resting_total: float = _total_impulse - resting_start
	_check(_impact_count > before_impacts and _peak_impulse > 0.0, "real falling plate produces contact impulse")
	_check(_peak_impulse <= IMPULSE_SAFETY_BOUND, "contact impulse bounded")
	# One persistent collider must not charge damage anew on every resting step.
	_check(resting_total <= REST_TOTAL_BOUND and _impact_count - resting_count <= REST_EVENT_BOUND, "repeated resting contact cumulative impulse and events capped")
	print("CONTACT_CHECK peak=%.4f resting_total=%.4f count=%d" % [_peak_impulse, resting_total, _impact_count - before_impacts])
	plate.queue_free()
	await _frames(2)


func _flip_fixture(angle: float, should_recover: bool) -> void:
	_robot.freeze = false
	_robot.gravity_scale = 0.0
	_robot.set("_air_balance", 0.0)
	_robot.set("_upright_damping", 0.0)
	_robot.set("_flipped_seconds", 0.0)
	_robot.global_transform = Transform3D(Basis(Vector3.FORWARD, deg_to_rad(angle)), Vector3(10.0, 10.0, 0.0))
	_robot.linear_velocity = Vector3.ZERO
	_robot.angular_velocity = Vector3.ZERO
	_cargo.call("reset_sway")
	await _frames(60)
	var before: float = rad_to_deg(_robot.global_basis.y.angle_to(Vector3.UP))
	await _frames(45)
	var after: float = rad_to_deg(_robot.global_basis.y.angle_to(Vector3.UP))
	_check(absf(before - angle) < 0.1, "%.0f degree flip does not recover before timeout" % angle)
	_check(after < 0.1 if should_recover else absf(after - angle) < 0.1, "%.0f degree flip recovery threshold" % angle)
	_check(_robot.global_position.distance_to(Vector3(10.0, 10.0, 0.0)) < SIGNAL_EPSILON, "flip recovery preserves position")
	_check(_robot.linear_velocity.length() < SIGNAL_EPSILON and _robot.angular_velocity.length() < SIGNAL_EPSILON, "flip recovery clears velocities")
	print("FLIP_CHECK angle=%.0f before=%.3f after=%.3f" % [angle, before, after])


func _ground_flip_fixture() -> void:
	_robot.set("_air_balance", _normal_air_balance)
	_robot.set("_upright_damping", _normal_upright_damping)
	_robot.set_physics_process(true)
	_robot.gravity_scale = 1.0
	_robot.set("_flipped_seconds", 0.0)
	_robot.global_transform = Transform3D(Basis(Vector3.FORWARD, PI), Vector3(10.0, 1.5, 0.0))
	_robot.linear_velocity = Vector3.ZERO
	_robot.angular_velocity = Vector3.ZERO
	_cargo.call("reset_sway")
	await _frames(240)
	var tilt: float = rad_to_deg(_robot.global_basis.y.angle_to(Vector3.UP))
	_check(tilt < 5.0 and _robot.global_position.y > 0.0 and _robot.global_position.y < 2.0 and _robot.is_grounded(), "real gravity/ground inverted robot recovers on working suspension")
	print("GROUND_FLIP_CHECK tilt=%.3f height=%.4f speed=%.4f grounded=%s" % [tilt, _robot.global_position.y, _robot.linear_velocity.length(), str(_robot.is_grounded())])
