extends SceneTree

## Oyun akışı kabul probu (Faz 2C). Sözleşme: ARCHITECTURE.md §5.2.
##
##   godot --headless --path . -s res://tools/flow_probe.gd
##
## Çıkış: 0 geçti, 1 ölçüt başarısız, 2 kurulum hatası.
## Kargo olaylarını (impact/slosh) probe kendisi sinyalle yayar: hasar bağlantısı deterministik sınanır.
## `-s` modunda autoload kimliği derlenmez (GOTCHAS.md #2): autoload'lara `/root/...` yoluyla erişilir.

const GAME_SCENE: String = "res://scenes/Game.tscn"
const CARGO_ID: String = "pencil_battery"
const DEADLINE_MS: int = 150000
const READY_FRAMES: int = 20
const DRIVE_FRAMES: int = 90
const FALL_WAIT_FRAMES: int = 120
const DELIVERY_FRAMES: int = 1500
const IMPACT_IMPULSE: float = 30.0
## pencil_battery: (30 - 9) * 0.02 = 0.42
const IMPACT_EXPECTED: float = 0.42
const DAMAGE_TOLERANCE: float = 0.03
const FALL_MIN_PENALTY: float = 0.2

enum Phase { LOAD, READY, IMPACT, SLOSH, DRIVE, FALL, DELIVER, BREAK, DONE }

var _phase: Phase = Phase.LOAD
var _frames: int = 0
var _phase_frames: int = 0
var _start_ms: int = 0
var _failures: Array[String] = []
var _setup_error: String = ""
var _scene: Node = null
var _ctl: Node = null
var _robot: Node3D = null
var _cargo: Node = null
var _damage_before_fall: float = 0.0
var _finished_count: int = 0
var _last_result: Dictionary = {}
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
		Phase.IMPACT: _step_impact()
		Phase.SLOSH: _step_slosh()
		Phase.DRIVE: _step_drive()
		Phase.FALL: _step_fall()
		Phase.DELIVER: _step_deliver()
		Phase.BREAK: _step_break()
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


func _state() -> Dictionary:
	return _ctl.call("state") as Dictionary


func _on_finished(result: Dictionary) -> void:
	_finished_count += 1
	_last_result = result


func _step_load() -> void:
	var gm: Node = root.get_node_or_null("/root/GameManager")
	if gm == null:
		_setup_fail("/root/GameManager autoload yok")
		return
	if not ("selected_cargo_id" in gm):
		_setup_fail("GameManager.selected_cargo_id yok (ARCHITECTURE §5.2)")
		return
	gm.set("selected_cargo_id", CARGO_ID)
	var packed: PackedScene = load(GAME_SCENE) as PackedScene
	if packed == null:
		_setup_fail("%s yüklenemedi" % GAME_SCENE)
		return
	_scene = packed.instantiate()
	root.add_child(_scene)
	_go(Phase.READY)


func _step_ready() -> void:
	if _phase_frames < READY_FRAMES:
		return
	_ctl = get_first_node_in_group("game_controller")
	if _ctl == null:
		_setup_fail("'game_controller' grubunda düğüm yok")
		return
	for method: String in ["state", "restart"]:
		if not _ctl.has_method(method):
			_setup_fail("GameController.%s() yok" % method)
	if not _ctl.has_signal("finished"):
		_setup_fail("GameController.finished sinyali yok")
	_robot = get_first_node_in_group("robot") as Node3D
	_cargo = get_first_node_in_group("cargo")
	if _robot == null or not _robot.has_method("set_speed_factor"):
		_setup_fail("robot yok ya da RobotController.set_speed_factor() yok")
	if _cargo == null or not _cargo.has_signal("impact_reported") or not _cargo.has_signal("slosh_reported"):
		_setup_fail("kargo yok ya da impact_reported/slosh_reported sinyalleri yok")
	for node_path: String in ["HUD/CargoHealthBar", "HUD/BatteryBar"]:
		if _scene.find_child(node_path.get_file(), true, false) == null:
			_setup_fail("sahnede '%s' yok" % node_path.get_file())
	for marker: String in ["RobotStart", "Checkpoint_1", "DeliveryZone"]:
		if _scene.find_child(marker, true, false) == null:
			_setup_fail("sahnede '%s' yok" % marker)
	if _setup_error != "":
		return
	_ctl.connect("finished", _on_finished)
	var st: Dictionary = _state()
	print("PROBE akış başlangıç cargo=%s damage=%.3f battery=%.3f" % [str(st.get("cargo_id")), float(st.get("damage", -1.0)), float(st.get("battery", -1.0))])
	if str(st.get("cargo_id")) != CARGO_ID:
		_fail("cargo_id yanlış: %s" % str(st.get("cargo_id")))
	if absf(float(st.get("damage", 1.0))) > 0.0001:
		_fail("başlangıç hasarı sıfır değil")
	_go(Phase.IMPACT)


func _step_impact() -> void:
	if _phase_frames == 1:
		_cargo.emit_signal("impact_reported", IMPACT_IMPULSE)
		return
	if _phase_frames < 3:
		return
	var d: float = float(_state().get("damage", -1.0))
	print("PROBE hasar impact_sonrası=%.3f (beklenen %.2f)" % [d, IMPACT_EXPECTED])
	if absf(d - IMPACT_EXPECTED) > DAMAGE_TOLERANCE:
		_fail("impact hasarı beklenenden farklı: %.3f (beklenen %.2f ± %.2f)" % [d, IMPACT_EXPECTED, DAMAGE_TOLERANCE])
	_go(Phase.SLOSH)


func _step_slosh() -> void:
	if _phase_frames == 1:
		_cargo.emit_signal("slosh_reported", 10.0, 0.5)   # pencil_battery slosh_threshold = 999 → hasar yok
		return
	if _phase_frames < 3:
		return
	var d: float = float(_state().get("damage", -1.0))
	if absf(d - IMPACT_EXPECTED) > DAMAGE_TOLERANCE:
		_fail("eşik altı çalkalanma hasar üretmemeliydi: %.3f" % d)
	_go(Phase.DRIVE)


func _step_drive() -> void:
	_robot.call("set_move_input", Vector2(0.0, 1.0))
	if _phase_frames < DRIVE_FRAMES:
		return
	_robot.call("set_move_input", Vector2.ZERO)
	var b: float = float(_state().get("battery", -1.0))
	print("PROBE batarya sürüş_sonrası=%.4f" % b)
	if b >= 1.0 or b <= 0.0:
		_fail("batarya sürüşle azalmalı (0<b<1): %.4f" % b)
	_damage_before_fall = float(_state().get("damage", 0.0))
	_robot.global_position = Vector3(_robot.global_position.x, -20.0, _robot.global_position.z)
	var rb: RigidBody3D = _robot as RigidBody3D
	if rb != null:
		rb.linear_velocity = Vector3.ZERO
		rb.angular_velocity = Vector3.ZERO
	_go(Phase.FALL)


func _step_fall() -> void:
	if _phase_frames < FALL_WAIT_FRAMES:
		return
	var st: Dictionary = _state()
	var d: float = float(st.get("damage", -1.0))
	print("PROBE düşme respawns=%d y=%.2f hasar %.3f -> %.3f" % [int(st.get("respawns", 0)), _robot.global_position.y, _damage_before_fall, d])
	if int(st.get("respawns", 0)) < 1:
		_fail("düşen robot kontrol noktasına dönmedi (respawns=0)")
	if _robot.global_position.y < -1.0:
		_fail("robot hâlâ zeminin altında: y=%.2f" % _robot.global_position.y)
	if d - _damage_before_fall < FALL_MIN_PENALTY:
		_fail("düşme cezası yetersiz: +%.3f (< %.2f)" % [d - _damage_before_fall, FALL_MIN_PENALTY])
	if bool(st.get("broken", false)):
		_fail("kargo bu aşamada kırılmamalıydı")
	_ctl.call("restart")
	_finished_count = 0
	_go(Phase.DELIVER)


func _step_deliver() -> void:
	if _phase_frames < 10:
		return   # restart sonrası oturma
	_robot.call("set_move_input", Vector2(0.0, 1.0))
	if _finished_count > 0 or _phase_frames >= DELIVERY_FRAMES:
		_robot.call("set_move_input", Vector2.ZERO)
		print("PROBE teslimat kare=%d finished=%d sonuç=%s" % [_phase_frames, _finished_count, str(_last_result)])
		if _finished_count != 1:
			_fail("teslimat bitişi bir kez yayılmalıydı (%d kez, %d karede)" % [_finished_count, _phase_frames])
		else:
			if not bool(_last_result.get("success", false)):
				_fail("teslimat başarılı olmalıydı: %s" % str(_last_result))
			if int(_last_result.get("gold", 0)) <= 0:
				_fail("altın > 0 olmalı")
			if int(_last_result.get("fee", -1)) != int(_last_result.get("gold", -2)):
				_fail("fee == gold olmalı (Result ekranı uyumu)")
			if int(_last_result.get("stars", -1)) < 1:
				_fail("yıldız >= 1 olmalı")
			var gm: Node = root.get_node_or_null("/root/GameManager")
			var lr: Dictionary = gm.get("last_result") as Dictionary
			if int(lr.get("gold", -1)) != int(_last_result.get("gold", -2)):
				_fail("GameManager.last_result güncellenmedi")
		_ctl.call("restart")
		_finished_count = 0
		_go(Phase.BREAK)


func _step_break() -> void:
	if _phase_frames == 10:
		_cargo.emit_signal("impact_reported", 5000.0)
		return
	if _phase_frames < 30:
		return
	var st: Dictionary = _state()
	print("PROBE kırılma broken=%s finished=%d sonuç=%s" % [str(st.get("broken")), _finished_count, str(_last_result)])
	if not bool(st.get("broken", false)):
		_fail("devasa darbe kargoyu kırmalıydı")
	if _finished_count != 1:
		_fail("kırılmada bitiş bir kez yayılmalıydı (%d)" % _finished_count)
	elif bool(_last_result.get("success", true)):
		_fail("kırılma başarısız sonuç vermeli (success=false)")
	elif int(_last_result.get("gold", -1)) != 0 or int(_last_result.get("scrap", -1)) != 0:
		_fail("kırılmada altın ve hurda 0 olmalı")
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
