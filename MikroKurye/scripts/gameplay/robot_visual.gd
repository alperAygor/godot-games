class_name RobotVisual
extends Node3D
## Robot görsel yardımcısı — yalnızca görünüm; fizik gövdesine, çarpışmaya ve
## probe ölçümlerine dokunmaz.
##
## Sahne düzeni (Robot.tscn) şöyle beklenir:
##   Robot (RigidBody3D)
##   ├─ VisualRoot (bu düğüm) -> BodyPivot -> Body (robot_body.glb)
##   └─ FrontLeft/FrontRight/RearLeft/RearRight (SuspensionWheel)
##        └─ Visual -> Spin -> Mesh (robot_wheel.glb, aks Y=0'da, -0.18 ötelenmiş)
##
## Tekerlek dönüşü ileri hız / yarıçap; direksiyon yaw'ı gövdenin açısal hızından
## (görsel ipucu) okunur. Nefes ve iniş squash&stretch yalnız BodyPivot ölçeğine
## uygulanır; Robot'un RigidBody3D transform'una asla yazılmaz.

const WHEEL_RADIUS_FALLBACK: float = 0.18
const IDLE_BOB_FREQUENCY: float = 2.2
const IDLE_BOB_AMPLITUDE: float = 0.012
const SQUASH_STRENGTH: float = 0.16
const SQUASH_XZ_FACTOR: float = 0.6
const SQUASH_DURATION: float = 0.24
## Görsel büyütme: fizik gövdesi aynı kalır; model gözle okunur olsun diye yalnız görünüm ölçeklenir.
const VISUAL_SCALE: float = 1.3
const MAX_STEER_RAD: float = 0.22
const STEER_RESPONSE: float = 10.0
const STEER_GAIN: float = 0.12

var _robot: RigidBody3D = null
var _body_pivot: Node3D = null
var _body_base_y: float = 0.0
var _spin_nodes: Array[Node3D] = []
var _steer_nodes: Array[Node3D] = []
var _wheel_radius: float = WHEEL_RADIUS_FALLBACK
var _spin_angle: float = 0.0
var _steer_angle: float = 0.0
var _idle_phase: float = 0.0
var _squash_timer: float = 0.0
var _was_grounded: bool = false


func _ready() -> void:
	_robot = get_parent() as RigidBody3D
	_body_pivot = get_node("BodyPivot") as Node3D
	_body_base_y = _body_pivot.position.y
	_wheel_radius = _read_wheel_radius()
	if _robot == null or _body_pivot == null:
		push_warning("RobotVisual: RigidBody3D üst ve BodyPivot çocuğu gerekir.")
		return
	for child: Node in _robot.get_children():
		if child is SuspensionWheel:
			var steer: Node3D = child.get_node_or_null("Visual") as Node3D
			var spin: Node3D = child.get_node_or_null("Visual/Spin") as Node3D
			if steer != null and spin != null:
				_steer_nodes.append(steer)
				_spin_nodes.append(spin)


func _process(delta: float) -> void:
	if _robot == null or _body_pivot == null:
		return
	_idle_phase += delta * IDLE_BOB_FREQUENCY
	_update_wheels(delta)
	_update_body(delta)


## İleri hız negatif Z eksenine göre; tekerlek çevresi dönüşü bu hızla orantılıdır.
func _update_wheels(delta: float) -> void:
	var forward: Vector3 = -_robot.global_basis.z
	var forward_speed: float = _robot.linear_velocity.dot(forward)
	_spin_angle += (forward_speed / _wheel_radius) * delta
	for spin: Node3D in _spin_nodes:
		spin.rotation.x = _spin_angle
	# Direksiyon görseli: gerçek fizik dönüş hızını (angular_velocity.y) küçük yaw'a
	# çevirir; giriş okunmadığı için fiziğe bağımlı kalmayan salt görsel bir ipucudur.
	var target_steer: float = clampf(_robot.angular_velocity.y * STEER_GAIN,
		-MAX_STEER_RAD, MAX_STEER_RAD)
	_steer_angle = lerpf(_steer_angle, target_steer, 1.0 - exp(-STEER_RESPONSE * delta))
	for steer: Node3D in _steer_nodes:
		steer.rotation.y = _steer_angle


## Nefes: gövde pivotu dikeyde küçük sinüs; iniş squash&stretch: havadan yere geçişte
## bir kerelik basılma. İkisi aynı pivot ölçeğinde toplanır (X/Z korunur, Y sıkışır).
func _update_body(delta: float) -> void:
	var grounded: bool = bool(_robot.call("is_grounded")) if _robot.has_method("is_grounded") else true
	if grounded and not _was_grounded:
		_squash_timer = SQUASH_DURATION
	_was_grounded = grounded
	var bob: float = sin(_idle_phase) * IDLE_BOB_AMPLITUDE
	var squash: float = 0.0
	if _squash_timer > 0.0:
		_squash_timer = maxf(_squash_timer - delta, 0.0)
		var envelope: float = sin((1.0 - _squash_timer / SQUASH_DURATION) * PI)
		squash = SQUASH_STRENGTH * envelope
	_body_pivot.position.y = _body_base_y + bob
	_body_pivot.scale = Vector3(1.0 + squash * SQUASH_XZ_FACTOR, 1.0 - squash, 1.0 + squash * SQUASH_XZ_FACTOR) * VISUAL_SCALE


func _read_wheel_radius() -> float:
	var data: Node = get_node_or_null("/root/GameData")
	if data != null:
		var physics: Variant = data.call("value", "balance", "physics", null)
		if physics is Dictionary:
			var radius: Variant = (physics as Dictionary).get("wheel_radius", WHEEL_RADIUS_FALLBACK)
			if radius is float or radius is int:
				return maxf(float(radius), 0.001)
	return WHEEL_RADIUS_FALLBACK
