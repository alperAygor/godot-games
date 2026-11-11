extends SceneTree

## Seviye ve tehlike kabul probu (Faz 3). Sözleşme: ARCHITECTURE.md §5.3.
##
##   godot --headless --path . -s res://tools/level_probe.gd
##
## Çıkış: 0 geçti, 1 ölçüt başarısız, 2 kurulum hatası.
## Seviye tek başına yüklenir (GameController yok); tehlikeler kendi başlarına çalışmalıdır.

const LEVEL_PATH: String = "res://scenes/levels/desk_01.tscn"
const DEADLINE_MS: int = 150000
const READY_FRAMES: int = 10
const OBSERVE_FRAMES: int = 900
const FAN_TEST_FRAMES: int = 240
const PENCIL_FRAMES: int = 600
const MIN_LENGTH: float = 60.0
const MIN_WIDTH: float = 8.0
const MIN_WARN_LEAD_FRAMES: int = 20
const MIN_FAN_GAIN: float = 0.3
const MIN_PENCIL_MOVE: float = 1.0
const MARKERS: Array[String] = ["RobotStart", "Checkpoint_1", "Checkpoint_2", "Checkpoint_3"]

enum Phase { LOAD, READY, OBSERVE, FAN, PENCIL, DONE }

var _phase: Phase = Phase.LOAD
var _frames: int = 0
var _phase_frames: int = 0
var _start_ms: int = 0
var _failures: Array[String] = []
var _setup_error: String = ""
var _level: Node3D = null
var _keys: Array[Node] = []
var _fans: Array[Node] = []
var _pencils: Array[Node] = []
var _key_first_warn: Dictionary = {}
var _key_first_press: Dictionary = {}
var _fan_ball: RigidBody3D = null
var _fan_dir: Vector3 = Vector3.ZERO
var _fan_blow_start_vel: float = -1.0
var _fan_best_gain: float = 0.0
var _pencil_start: Dictionary = {}
var _done: bool = false


func _initialize() -> void:
	_start_ms = Time.get_ticks_msec()


func _physics_process(_delta: float) -> bool:
	if _done:
		return true
	if Time.get_ticks_msec() - _start_ms > DEADLINE_MS:
		_setup_error = "zaman aşımı — faz %s" % Phase.keys()[_phase]
		_finish()
		return true
	_frames += 1
	_phase_frames += 1
	match _phase:
		Phase.LOAD: _step_load()
		Phase.READY: _step_ready()
		Phase.OBSERVE: _step_observe()
		Phase.FAN: _step_fan()
		Phase.PENCIL: _step_pencil()
		_: pass
	if _setup_error != "" or _phase == Phase.DONE:
		_finish()
	return _done


func _go(next: Phase) -> void:
	_phase = next
	_phase_frames = 0


func _fail(message: String) -> void:
	_failures.append(message)


func _setup_fail(message: String) -> void:
	if _setup_error == "":
		_setup_error = message


func _marker(name: String) -> Node3D:
	return _level.find_child(name, true, false) as Node3D


func _step_load() -> void:
	var packed: PackedScene = load(LEVEL_PATH) as PackedScene
	if packed == null:
		_setup_fail("%s yüklenemedi (sahne yok ya da hatalı)" % LEVEL_PATH)
		return
	_level = packed.instantiate() as Node3D
	if _level == null:
		_setup_fail("seviye kökü Node3D değil")
		return
	root.add_child(_level)
	_go(Phase.READY)


func _step_ready() -> void:
	if _phase_frames < READY_FRAMES:
		return
	for name: String in MARKERS:
		if _marker(name) == null:
			_setup_fail("seviyede '%s' Marker3D yok" % name)
	if _level.find_child("DeliveryZone", true, false) == null:
		_setup_fail("seviyede 'DeliveryZone' yok")
	if _setup_error != "":
		return
	var start: Node3D = _marker("RobotStart")
	var zone: Node3D = _level.find_child("DeliveryZone", true, false) as Node3D
	var length: float = absf(zone.global_position.z - start.global_position.z)
	print("PROBE seviye uzunluk=%.1f" % length)
	if length < MIN_LENGTH:
		_fail("seviye çok kısa: %.1f m (< %.0f)" % [length, MIN_LENGTH])
	var prev_z: float = start.global_position.z
	for name: String in ["Checkpoint_1", "Checkpoint_2", "Checkpoint_3"]:
		var z: float = _marker(name).global_position.z
		if z >= prev_z:
			_fail("%s −Z yönünde bir öncekinden ileride olmalı (z=%.1f, önceki %.1f)" % [name, z, prev_z])
		prev_z = z
	if zone.global_position.z >= prev_z:
		_fail("DeliveryZone son kontrol noktasından ileride olmalı")
	_keys = get_nodes_in_group("keyboard_key")
	_fans = get_nodes_in_group("fan_wind")
	_pencils = get_nodes_in_group("rolling_pencil")
	print("PROBE tehlikeler klavye=%d fan=%d kalem=%d" % [_keys.size(), _fans.size(), _pencils.size()])
	if _keys.is_empty():
		_fail("seviyede KeyboardKey yok")
	if _fans.is_empty():
		_fail("seviyede FanWind yok")
	if _pencils.is_empty():
		_fail("seviyede RollingPencil yok")
	for k: Node in _keys:
		for m: String in ["is_telegraphing", "is_pressed"]:
			if not k.has_method(m):
				_setup_fail("KeyboardKey.%s() yok" % m)
	for f: Node in _fans:
		for m: String in ["is_blowing", "wind_direction"]:
			if not f.has_method(m):
				_setup_fail("FanWind.%s() yok" % m)
	if _setup_error != "":
		return
	for p: Node in _pencils:
		_pencil_start[p.get_instance_id()] = (p as Node3D).global_position
	_go(Phase.OBSERVE)


func _step_observe() -> void:
	for k: Node in _keys:
		var id: int = k.get_instance_id()
		if bool(k.call("is_telegraphing")) and not _key_first_warn.has(id):
			_key_first_warn[id] = _frames
		if bool(k.call("is_pressed")) and not _key_first_press.has(id):
			_key_first_press[id] = _frames
	if _phase_frames < OBSERVE_FRAMES:
		return
	for k: Node in _keys:
		var id: int = k.get_instance_id()
		if not _key_first_warn.has(id):
			_fail("%s %d karede hiç uyarı vermedi" % [k.name, OBSERVE_FRAMES])
		elif not _key_first_press.has(id):
			_fail("%s %d karede hiç basmadı" % [k.name, OBSERVE_FRAMES])
		else:
			var lead: int = int(_key_first_press[id]) - int(_key_first_warn[id])
			print("PROBE klavye %s uyarı_önce_kare=%d" % [k.name, lead])
			if lead < MIN_WARN_LEAD_FRAMES:
				_fail("%s uyarı basmadan yalnızca %d kare önce (< %d): adil değil" % [k.name, lead, MIN_WARN_LEAD_FRAMES])
	_start_fan_test()


func _start_fan_test() -> void:
	var fan: Node3D = _fans[0] as Node3D
	_fan_ball = RigidBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = 0.25
	shape.shape = sphere
	_fan_ball.add_child(shape)
	_fan_ball.gravity_scale = 0.0
	_fan_ball.linear_damp = 0.0
	root.add_child(_fan_ball)
	_fan_ball.global_position = fan.global_position
	_fan_dir = (fan.call("wind_direction") as Vector3).normalized()
	_fan_best_gain = 0.0
	_go(Phase.FAN)


func _step_fan() -> void:
	var fan: Node = _fans[0]
	if _phase_frames > 1 and _fan_ball != null:
		var along: float = _fan_ball.linear_velocity.dot(_fan_dir)
		_fan_best_gain = maxf(_fan_best_gain, along)
	if _phase_frames < FAN_TEST_FRAMES:
		return
	print("PROBE fan en_iyi_hız_kazancı=%.2f blowing_şimdi=%s" % [_fan_best_gain, str(bool(fan.call("is_blowing")))])
	if _fan_best_gain < MIN_FAN_GAIN:
		_fail("fan alanındaki serbest küre üflerken yeterince ivmelenmedi: %.2f m/s (< %.1f)" % [_fan_best_gain, MIN_FAN_GAIN])
	_fan_ball.queue_free()
	_go(Phase.PENCIL)


func _step_pencil() -> void:
	if _phase_frames < PENCIL_FRAMES:
		return
	for p: Node in _pencils:
		var moved: float = ((p as Node3D).global_position - (_pencil_start[p.get_instance_id()] as Vector3)).length()
		print("PROBE kalem %s hareket=%.2f" % [p.name, moved])
		if moved < MIN_PENCIL_MOVE:
			_fail("%s %d karede yalnızca %.2f m hareket etti (< %.1f)" % [p.name, PENCIL_FRAMES, moved, MIN_PENCIL_MOVE])
	_go(Phase.DONE)


func _finish() -> void:
	if _done:
		return
	_done = true
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
