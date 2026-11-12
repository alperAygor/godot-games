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
## Hızlanma/frenleme eğimi (burun kalkar/çöker) ve virajda dışa yatış: yalnız BodyPivot dönüşü.
const LEAN_PITCH_GAIN: float = 0.012
const LEAN_PITCH_MAX: float = 0.09
const LEAN_ROLL_GAIN: float = 0.011
const LEAN_ROLL_MAX: float = 0.12
const LEAN_RESPONSE: float = 8.0
const ACCEL_SMOOTHING: float = 12.0
## Darbe sarsıntısı: sönümlü yatış salınımı; genlik darbe şiddetinden gelir (üst sınırlı).
const WOBBLE_GAIN: float = 0.00004
const WOBBLE_MAX: float = 0.16
const WOBBLE_FREQUENCY: float = 22.0
const WOBBLE_DECAY: float = 6.0
## Göz ifadesi: emisyon rengi/enerjisiyle (geometri değişmez, ucuz). Göz kırpma
## aralıklı; hasarda kısa kırmızı flaş; teslimatta kısa parlama.
const BLINK_GAP_MIN: float = 2.4
const BLINK_GAP_MAX: float = 5.0
const BLINK_DURATION: float = 0.12
const HURT_DURATION: float = 0.7
const HAPPY_DURATION: float = 1.4
const EYE_ENERGY_HAPPY_FACTOR: float = 2.2
const EYE_COLOR_HURT: Color = Color("ff4d4d")
const EYE_COLOR_HAPPY: Color = Color("ffe27a")
## Tekerlek tozu: yalnız hızlı ve yerdeyken yayılır; düşük parçacık sayısı (mobil).
const DUST_MIN_SPEED: float = 2.5

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
var _prev_forward_speed: float = 0.0
var _accel_smooth: float = 0.0
var _lean_pitch: float = 0.0
var _lean_roll: float = 0.0
var _wobble_amp: float = 0.0
var _wobble_phase: float = 0.0
var _eye_materials: Array[ShaderMaterial] = []
var _eye_indices: Array[Vector2i] = []   # (mesh sırası, yüzey)
var _eyes_ready: bool = false
var _eye_base_color: Color = Color.WHITE
var _eye_base_energy: float = 1.0
var _blink_timer: float = 3.0
var _blink_left: float = 0.0
var _hurt_left: float = 0.0
var _happy_left: float = 0.0
var _dust: CPUParticles3D = null


func _ready() -> void:
	_robot = get_parent() as RigidBody3D
	_body_pivot = get_node("BodyPivot") as Node3D
	_body_base_y = _body_pivot.position.y
	_wheel_radius = _read_wheel_radius()
	if _robot == null or _body_pivot == null:
		push_warning("RobotVisual: RigidBody3D üst ve BodyPivot çocuğu gerekir.")
		return
	_dust = get_node_or_null("WheelDust") as CPUParticles3D
	_connect_reactions()
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
	_update_lean(delta)
	_update_eyes(delta)
	_update_dust()


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


## Hızlanma ivmesi gövdeyi öne/arkaya yatırır; viraj dışa yatırır. Değerler yumuşatılır
## ve sınırlıdır; fizik gövdesi okunur ama asla yazılmaz.
func _update_lean(delta: float) -> void:
	var forward: Vector3 = -_robot.global_basis.z
	var forward_speed: float = _robot.linear_velocity.dot(forward)
	var accel: float = (forward_speed - _prev_forward_speed) / maxf(delta, 0.0001)
	_prev_forward_speed = forward_speed
	_accel_smooth = lerpf(_accel_smooth, accel, 1.0 - exp(-ACCEL_SMOOTHING * delta))
	var target_pitch: float = clampf(_accel_smooth * LEAN_PITCH_GAIN, -LEAN_PITCH_MAX, LEAN_PITCH_MAX)
	var target_roll: float = clampf(-_robot.angular_velocity.y * forward_speed * LEAN_ROLL_GAIN,
		-LEAN_ROLL_MAX, LEAN_ROLL_MAX)
	var blend: float = 1.0 - exp(-LEAN_RESPONSE * delta)
	_lean_pitch = lerpf(_lean_pitch, target_pitch, blend)
	_lean_roll = lerpf(_lean_roll, target_roll, blend)
	_wobble_phase += delta * WOBBLE_FREQUENCY
	_wobble_amp = maxf(_wobble_amp - _wobble_amp * WOBBLE_DECAY * delta, 0.0)
	_body_pivot.rotation = Vector3(_lean_pitch, 0.0, _lean_roll + sin(_wobble_phase) * _wobble_amp)


func _connect_reactions() -> void:
	var cargo: Node = get_tree().get_first_node_in_group("cargo")
	if cargo != null and cargo.has_signal("impact_reported"):
		cargo.connect("impact_reported", _on_impact)
	var controller: Node = get_tree().get_first_node_in_group("game_controller")
	if controller != null and controller.has_signal("finished"):
		controller.connect("finished", _on_finished)


func _on_impact(impulse: float) -> void:
	_wobble_amp = minf(absf(impulse) * WOBBLE_GAIN * 1000.0, WOBBLE_MAX)
	_hurt_left = HURT_DURATION


func _on_finished(result: Dictionary) -> void:
	if bool(result.get("success", false)):
		_happy_left = HAPPY_DURATION
	else:
		_hurt_left = HURT_DURATION


## Gözler: StyleA `_ready`'sinde yüzeyleri paylaşılan toon malzemesine çevirir; ilk karede
## göz yüzeylerini tekilleştirip (duplicate) emisyonu parametreyle sürüyoruz, böylece
## başka nesnelerle paylaşılan malzeme boyanmaz.
func _setup_eyes() -> void:
	_eyes_ready = true
	for mesh: MeshInstance3D in _find_meshes(_body_pivot):
		if mesh.mesh == null:
			continue
		for surface: int in mesh.mesh.get_surface_count():
			var source: Material = mesh.mesh.surface_get_material(surface)
			if source == null or not source.resource_name.to_lower().contains("eye"):
				continue
			var active: ShaderMaterial = mesh.get_active_material(surface) as ShaderMaterial
			if active == null:
				continue
			var unique: ShaderMaterial = active.duplicate() as ShaderMaterial
			mesh.set_surface_override_material(surface, unique)
			if _eye_materials.is_empty():
				var base_color: Variant = unique.get_shader_parameter("emissive_color")
				var base_energy: Variant = unique.get_shader_parameter("emissive_energy")
				if base_color is Color:
					_eye_base_color = base_color
				if base_energy is float and float(base_energy) > 0.0:
					_eye_base_energy = float(base_energy)
			_eye_materials.append(unique)


func _find_meshes(root: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		found.append(root as MeshInstance3D)
	for child: Node in root.get_children():
		found.append_array(_find_meshes(child))
	return found


func _update_eyes(delta: float) -> void:
	if not _eyes_ready:
		_setup_eyes()
	if _eye_materials.is_empty():
		return
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_blink_left = BLINK_DURATION
		_blink_timer = randf_range(BLINK_GAP_MIN, BLINK_GAP_MAX)
	_blink_left = maxf(_blink_left - delta, 0.0)
	_hurt_left = maxf(_hurt_left - delta, 0.0)
	_happy_left = maxf(_happy_left - delta, 0.0)
	var color: Color = _eye_base_color
	var energy: float = _eye_base_energy
	if _hurt_left > 0.0:
		color = _eye_base_color.lerp(EYE_COLOR_HURT, _hurt_left / HURT_DURATION)
	elif _happy_left > 0.0:
		color = _eye_base_color.lerp(EYE_COLOR_HAPPY, _happy_left / HAPPY_DURATION)
		energy = lerpf(_eye_base_energy, _eye_base_energy * EYE_ENERGY_HAPPY_FACTOR, _happy_left / HAPPY_DURATION)
	if _blink_left > 0.0:
		energy = 0.0
	for material: ShaderMaterial in _eye_materials:
		material.set_shader_parameter("emissive_color", color)
		material.set_shader_parameter("emissive_energy", energy)


func _update_dust() -> void:
	if _dust == null:
		return
	var grounded: bool = bool(_robot.call("is_grounded")) if _robot.has_method("is_grounded") else true
	_dust.emitting = grounded and _robot.linear_velocity.length() > DUST_MIN_SPEED


func _read_wheel_radius() -> float:
	var data: Node = get_node_or_null("/root/GameData")
	if data != null:
		var physics: Variant = data.call("value", "balance", "physics", null)
		if physics is Dictionary:
			var radius: Variant = (physics as Dictionary).get("wheel_radius", WHEEL_RADIUS_FALLBACK)
			if radius is float or radius is int:
				return maxf(float(radius), 0.001)
	return WHEEL_RADIUS_FALLBACK
