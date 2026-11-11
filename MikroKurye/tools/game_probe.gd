extends SceneTree

## Fizik kabul probu (Faz 2). Sözleşme: ARCHITECTURE.md §5.1.
##
##   godot --headless --path . -s res://tools/game_probe.gd
##
## Çıkış: 0 tüm aşamalar geçti, 1 bir ölçüt başarısız, 2 kurulum hatası (sahne/API eksik).
## Aşama `res://tools/probe_stage.txt` ("robot" | "full") dosyasından okunur; lider belirler.
## Çıktıdaki `PROBE ...` satırları raporlara girer (ayar için sayısal veri).
##
## Neden `_physics_process` ve kare sayımı: sonuç makine hızından bağımsız, deterministik olsun
## (headless kare hızı değişir; fizik 60 Hz sabit adım). `-s` modunda autoload kimliği derlenmez
## (GOTCHAS.md #2): bu dosya autoload'lara kimlikle erişmez.

const SCENE_PATH: String = "res://scenes/Proto.tscn"
const STAGE_PATH: String = "res://tools/probe_stage.txt"
const DEADLINE_MS: int = 120000

const SETTLE_FRAMES: int = 180
const ACCEL_FRAMES: int = 180
const BRAKE_FRAMES: int = 240
const TURN_FRAMES: int = 120
const RAMP_FRAMES: int = 420
const READY_FRAMES: int = 10

const SETTLED_SPEED: float = 0.1
const MAX_START_HEIGHT: float = 1.0
const ACCEL_MIN_RATIO: float = 0.8
const ACCEL_MAX_RATIO: float = 1.3
const BRAKE_END_RATIO: float = 0.15
const TURN_MIN_DEG: float = 30.0
const AIR_MIN_FRAMES: int = 3
const MAX_SANE_SPEED: float = 40.0
const MIN_SANE_Y: float = -2.0
const SWAY_REST_MAX: float = 1.5
const SWAY_ACCEL_MIN: float = 2.0
const SWAY_ACCEL_MAX: float = 60.0
const SWAY_DAMPED_MAX: float = 3.0
const SWAY_DAMPED_AFTER_FRAMES: int = 240

enum Phase { LOAD, READY, SETTLE, ACCEL, BRAKE, TURN, RAMP, DONE }

var _phase: Phase = Phase.LOAD
var _frames: int = 0
var _phase_frames: int = 0
var _start_ms: int = 0
var _failures: Array[String] = []
var _setup_error: String = ""
var _full: bool = false
var _scene: Node = null
var _robot: Node3D = null
var _cargo: Node3D = null
var _max_speed: float = 1.0
var _peak_speed: float = 0.0
var _peak_sway: float = 0.0
var _sway_after_brake: float = -1.0
var _start_yaw: float = 0.0
var _air_run: int = 0
var _best_air_run: int = 0
var _was_air: bool = false
var _landed_after_air: bool = false
var _detached: bool = false
var _done: bool = false


func _initialize() -> void:
	_start_ms = Time.get_ticks_msec()
	_full = _read_stage() == "full"


func _physics_process(_delta: float) -> bool:
	if _done:
		return true
	if Time.get_ticks_msec() - _start_ms > DEADLINE_MS:
		_setup_error = "zaman aşımı (%d ms) — faz %s" % [DEADLINE_MS, Phase.keys()[_phase]]
		_finish()
		return true
	_frames += 1
	_phase_frames += 1
	match _phase:
		Phase.LOAD: _step_load()
		Phase.READY: _step_ready()
		Phase.SETTLE: _step_settle()
		Phase.ACCEL: _step_accel()
		Phase.BRAKE: _step_brake()
		Phase.TURN: _step_turn()
		Phase.RAMP: _step_ramp()
		_: pass
	if _setup_error != "" or _phase == Phase.DONE:
		_finish()
	return _done


func _read_stage() -> String:
	if not FileAccess.file_exists(STAGE_PATH):
		return "robot"
	return FileAccess.get_file_as_string(STAGE_PATH).strip_edges()


func _go(next: Phase) -> void:
	_phase = next
	_phase_frames = 0


func _fail(message: String) -> void:
	_failures.append(message)


func _setup_fail(message: String) -> void:
	if _setup_error == "":
		_setup_error = message


func _finite(v: Vector3) -> bool:
	return is_finite(v.x) and is_finite(v.y) and is_finite(v.z)


func _speed() -> float:
	return float(_robot.call("speed"))


func _sway() -> float:
	return float(_cargo.call("sway_angle_deg"))


func _yaw_deg() -> float:
	return rad_to_deg(_robot.global_transform.basis.get_euler().y)


func _sanity() -> void:
	var rb: RigidBody3D = _robot as RigidBody3D
	if not _finite(_robot.global_position) or (rb != null and not _finite(rb.linear_velocity)):
		_fail("robot konumu/hızı sonlu değil (NaN/INF) — kare %d" % _frames)
	if _robot.global_position.y < MIN_SANE_Y:
		_fail("robot zeminden düştü (y=%.2f) — kare %d" % [_robot.global_position.y, _frames])
	if rb != null and rb.linear_velocity.length() > MAX_SANE_SPEED:
		_fail("robot hızı makul değil (%.1f m/s) — kare %d" % [rb.linear_velocity.length(), _frames])
	if _full and _cargo != null:
		if not bool(_cargo.call("is_attached")):
			_detached = true


func _step_load() -> void:
	var packed: PackedScene = load(SCENE_PATH) as PackedScene
	if packed == null:
		_setup_fail("%s yüklenemedi (sahne yok ya da hatalı)" % SCENE_PATH)
		return
	_scene = packed.instantiate()
	root.add_child(_scene)
	_go(Phase.READY)


func _step_ready() -> void:
	if _phase_frames < READY_FRAMES:
		return
	_robot = get_first_node_in_group("robot") as Node3D
	if _robot == null:
		_setup_fail("'robot' grubunda düğüm yok")
		return
	for method: String in ["set_move_input", "speed", "max_speed", "is_grounded"]:
		if not _robot.has_method(method):
			_setup_fail("RobotController.%s() yok" % method)
	if _scene.get_node_or_null("RobotStart") == null:
		_setup_fail("sahnede 'RobotStart' Marker3D yok")
	if _scene.get_node_or_null("RampStart") == null:
		_setup_fail("sahnede 'RampStart' Marker3D yok")
	if _full:
		_cargo = get_first_node_in_group("cargo") as Node3D
		if _cargo == null:
			_setup_fail("aşama 'full' ama 'cargo' grubunda düğüm yok")
		else:
			for method: String in ["sway_angle_deg", "is_attached"]:
				if not _cargo.has_method(method):
					_setup_fail("CargoBasket.%s() yok" % method)
	if _setup_error != "":
		return
	_max_speed = maxf(float(_robot.call("max_speed")), 0.001)
	print("PROBE aşama=%s max_speed=%.2f" % [("full" if _full else "robot"), _max_speed])
	_go(Phase.SETTLE)


func _step_settle() -> void:
	_sanity()
	if _phase_frames < SETTLE_FRAMES:
		return
	var s: float = _speed()
	var y: float = _robot.global_position.y
	print("PROBE dinlenme speed=%.3f y=%.3f" % [s, y])
	if s >= SETTLED_SPEED:
		_fail("dinlenmede robot kıpırdıyor: speed=%.3f (>= %.2f)" % [s, SETTLED_SPEED])
	if y <= 0.0 or y >= MAX_START_HEIGHT:
		_fail("dinlenme yüksekliği aralık dışı: y=%.3f (0..%.1f)" % [y, MAX_START_HEIGHT])
	if _full:
		var sw: float = _sway()
		print("PROBE dinlenme sway=%.2f" % sw)
		if sw >= SWAY_REST_MAX:
			_fail("dinlenmede kargo sallanıyor: sway=%.2f° (>= %.1f°)" % [sw, SWAY_REST_MAX])
	_start_yaw = _yaw_deg()
	_go(Phase.ACCEL)


func _step_accel() -> void:
	_robot.call("set_move_input", Vector2(0.0, 1.0))
	_sanity()
	_peak_speed = maxf(_peak_speed, _speed())
	if _full:
		_peak_sway = maxf(_peak_sway, _sway())
	if _phase_frames < ACCEL_FRAMES:
		return
	print("PROBE ivmelenme peak_speed=%.2f (hedef %.2f..%.2f)" % [_peak_speed, ACCEL_MIN_RATIO * _max_speed, ACCEL_MAX_RATIO * _max_speed])
	if _peak_speed < ACCEL_MIN_RATIO * _max_speed:
		_fail("yeterince hızlanmadı: %.2f < %.2f" % [_peak_speed, ACCEL_MIN_RATIO * _max_speed])
	if _peak_speed > ACCEL_MAX_RATIO * _max_speed:
		_fail("azami hız aşıldı: %.2f > %.2f" % [_peak_speed, ACCEL_MAX_RATIO * _max_speed])
	if _full:
		print("PROBE ivmelenme peak_sway=%.2f" % _peak_sway)
		if _peak_sway < SWAY_ACCEL_MIN:
			_fail("kargo ivmelenmede tepki vermedi: tepe sway=%.2f° (< %.1f°)" % [_peak_sway, SWAY_ACCEL_MIN])
		if _peak_sway > SWAY_ACCEL_MAX:
			_fail("kargo aşırı savruluyor: tepe sway=%.2f° (> %.1f°)" % [_peak_sway, SWAY_ACCEL_MAX])
	_go(Phase.BRAKE)


func _step_brake() -> void:
	_robot.call("set_move_input", Vector2.ZERO)
	_sanity()
	if _full:
		_peak_sway = maxf(_peak_sway, _sway())
		if _phase_frames == SWAY_DAMPED_AFTER_FRAMES:
			_sway_after_brake = _sway()
	if _phase_frames < BRAKE_FRAMES:
		return
	var s: float = _speed()
	print("PROBE frenleme speed_end=%.3f (hedef < %.2f)" % [s, BRAKE_END_RATIO * _max_speed])
	if s >= BRAKE_END_RATIO * _max_speed:
		_fail("frenlemeden sonra hâlâ hızlı: %.3f >= %.3f" % [s, BRAKE_END_RATIO * _max_speed])
	if _full:
		print("PROBE frenleme sway_after=%.2f tepe=%.2f" % [_sway_after_brake, _peak_sway])
		if _sway_after_brake < 0.0 or _sway_after_brake >= SWAY_DAMPED_MAX:
			_fail("kargo sönümlenmedi: sway=%.2f° (>= %.1f°) frenlemeden %d kare sonra" % [_sway_after_brake, SWAY_DAMPED_MAX, SWAY_DAMPED_AFTER_FRAMES])
	_start_yaw = _yaw_deg()
	_go(Phase.TURN)


func _step_turn() -> void:
	_robot.call("set_move_input", Vector2(1.0, 1.0))
	_sanity()
	if _phase_frames < TURN_FRAMES:
		return
	var dyaw: float = absf(angle_difference(deg_to_rad(_start_yaw), deg_to_rad(_yaw_deg())))
	dyaw = rad_to_deg(dyaw)
	print("PROBE dönüş yaw_degisim=%.1f (hedef >= %.0f)" % [dyaw, TURN_MIN_DEG])
	if dyaw < TURN_MIN_DEG:
		_fail("dönüş yetersiz: %.1f° < %.0f°" % [dyaw, TURN_MIN_DEG])
	# Rampa aşaması: robotu RampStart'a taşı
	var marker: Marker3D = _scene.get_node("RampStart") as Marker3D
	var rb: RigidBody3D = _robot as RigidBody3D
	_robot.global_transform = marker.global_transform
	if rb != null:
		rb.linear_velocity = Vector3.ZERO
		rb.angular_velocity = Vector3.ZERO
	if _full and _cargo != null:
		# Kargoyu robotla birlikte taşı: bağlı olmayı bozmadan yalnız mesafeyi korur
		var cb: RigidBody3D = _cargo as RigidBody3D
		if cb != null:
			cb.linear_velocity = Vector3.ZERO
			cb.angular_velocity = Vector3.ZERO
	_air_run = 0
	_go(Phase.RAMP)


func _step_ramp() -> void:
	_robot.call("set_move_input", Vector2(0.0, 1.0))
	if _phase_frames < 30:
		return   # taşıma sonrası oturma payı; bu karelerde saplık denetimi yapılmaz
	_sanity()
	var grounded: bool = bool(_robot.call("is_grounded"))
	if not grounded:
		_air_run += 1
		_best_air_run = maxi(_best_air_run, _air_run)
		if _air_run >= AIR_MIN_FRAMES:
			_was_air = true
	else:
		if _was_air:
			_landed_after_air = true
		_air_run = 0
	if _phase_frames < RAMP_FRAMES:
		return
	print("PROBE rampa en_uzun_havada_kare=%d indi=%s" % [_best_air_run, str(_landed_after_air)])
	if not _was_air:
		_fail("rampada havalanma yok (en uzun havada seri %d kare < %d)" % [_best_air_run, AIR_MIN_FRAMES])
	elif not _landed_after_air:
		_fail("robot havalandıktan sonra bir daha yere inmedi")
	_go(Phase.DONE)


func _finish() -> void:
	if _done:
		return
	_done = true
	_robot_cleanup()
	if _detached:
		_fail("kargo robottan koptu (is_attached() yanlış oldu)")
	if _setup_error != "":
		print("PROBE KURULUM HATASI: %s" % _setup_error)
		quit(2)
		return
	if _failures.is_empty():
		print("PROBE SONUC: gecti (kare %d)" % _frames)
		quit(0)
	else:
		for f: String in _failures:
			print("PROBE HATA: %s" % f)
		print("PROBE SONUC: basarisiz (%d hata)" % _failures.size())
		quit(1)


func _robot_cleanup() -> void:
	if _robot != null and _robot.has_method("set_move_input"):
		_robot.call("set_move_input", Vector2.ZERO)
