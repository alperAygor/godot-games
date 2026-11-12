extends SceneTree

## Sonsuz mod kabul probu (Faz 9). Sözleşme: PROJECT_SPEC §14.
##
##   godot --headless --path . -s res://tools/endless_probe.gd
##
## Koşu 1: level 1 teslimatı (kasa, level ilerlemesi, akış), level 2 bitişine ışınlanıp
## level 3'e geçiş, ardından kırılma (kasa yarı yarıya ödenir). Koşu 2: aynı tohumla
## aynı yol (determinizm), level 1 sonrası batarya boşalır (kasa tam ödenir).
## Çıkış: 0 geçti, 1 ölçüt başarısız, 2 kurulum hatası.
## `-s` modunda autoload kimliği derlenmez (GOTCHAS #2): `/root/...` yolu kullanılır.

const GAME_SCENE: String = "res://scenes/Game.tscn"
const LEVEL_ID: String = "endless_desk"
const CARGO_ID: String = "pencil_battery"
const DEADLINE_MS: int = 180000
const READY_FRAMES: int = 20
const LEVEL1_FRAMES: int = 1500
const SETTLE_FRAMES: int = 30
const LEVEL2_FRAMES: int = 600
const BREAK_FRAMES: int = 90
const BATTERY_FRAMES: int = 420
const IMPACT_BREAK: float = 5000.0
const TELEPORT_BEFORE_PAD: float = 8.0
const MAX_LIVE_SEGMENTS: int = 40
## Uzak mesafe: bu z'de robot durağan kalmalı (tek duyarlıklı kayan nokta sınırı, PROJECT_SPEC §14).
const FAR_Z: float = -4000.0
const FAR_BUILD_CALLS: int = 120
const FAR_SETTLE_FRAMES: int = 90
const FAR_SAMPLE_FRAMES: int = 240
const FAR_MAX_JITTER: float = 0.002

enum Phase { LOAD, READY, LEVEL1, SETTLE, LEVEL2, BREAK, RELOAD, READY2, LEVEL1B, BATTERY, FARLOAD, FAR, DONE }

var _phase: Phase = Phase.LOAD
var _frames: int = 0
var _phase_frames: int = 0
var _start_ms: int = 0
var _failures: Array[String] = []
var _setup_error: String = ""
var _scene: Node = null
var _ctl: Node = null
var _level: Node = null
var _robot: Node3D = null
var _cargo: Node = null
var _finished_count: int = 0
var _last_result: Dictionary = {}
var _pad1_z_first: float = 0.0
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
		Phase.LOAD, Phase.RELOAD, Phase.FARLOAD: _step_load()
		Phase.READY, Phase.READY2: _step_ready()
		Phase.LEVEL1, Phase.LEVEL1B: _step_level1()
		Phase.SETTLE: _step_settle()
		Phase.LEVEL2: _step_level2()
		Phase.BREAK: _step_break()
		Phase.BATTERY: _step_battery()
		Phase.FAR: _step_far()
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
	gm.set("selected_cargo_id", CARGO_ID)
	gm.set("selected_level_id", LEVEL_ID)
	if _scene != null:
		_scene.queue_free()
		_scene = null
	var packed: PackedScene = load(GAME_SCENE) as PackedScene
	if packed == null:
		_setup_fail("%s yüklenemedi" % GAME_SCENE)
		return
	_scene = packed.instantiate()
	root.add_child(_scene)
	_finished_count = 0
	_last_result = {}
	match _phase:
		Phase.LOAD: _go(Phase.READY)
		Phase.RELOAD: _go(Phase.READY2)
		_: _go(Phase.FAR)


func _step_ready() -> void:
	if _phase_frames < READY_FRAMES:
		return
	_ctl = get_first_node_in_group("game_controller")
	_robot = get_first_node_in_group("robot") as Node3D
	_cargo = get_first_node_in_group("cargo")
	_level = _scene.get_node_or_null("Level")
	if _ctl == null or _robot == null or _cargo == null or _level == null:
		_setup_fail("denetleyici/robot/kargo/Level bulunamadı")
		return
	if not _level.has_method("level_end_z") or not _level.has_method("segment_count"):
		_setup_fail("Level EndlessLevel değil (level_end_z/segment_count yok)")
		return
	_ctl.connect("finished", _on_finished)
	var st: Dictionary = _state()
	var pad1: float = float(_level.call("level_end_z"))
	print("PROBE sonsuz başlangıç endless=%s level=%d pad1_z=%.2f parça=%d" % [
		str(st.get("endless")), int(st.get("level_number", 0)), pad1, int(_level.call("segment_count"))])
	if not bool(st.get("endless", false)) or int(st.get("level_number", 0)) != 1:
		_fail("koşu level 1'de sonsuz modda başlamalı")
	if absf(pad1 + 60.0) > 12.5:
		_fail("level 1 bitişi ~60 m olmalı (parça yuvarlaması dahil): %.2f" % pad1)
	if _phase == Phase.READY:
		_pad1_z_first = pad1
		_go(Phase.LEVEL1)
	else:
		if not is_equal_approx(pad1, _pad1_z_first):
			_fail("aynı tohum aynı yolu vermeli: %.3f != %.3f" % [pad1, _pad1_z_first])
		_go(Phase.LEVEL1B)


func _step_level1() -> void:
	_robot.call("set_move_input", Vector2(0.0, 1.0))
	var st: Dictionary = _state()
	if int(st.get("levels_delivered", 0)) >= 1 or _phase_frames >= LEVEL1_FRAMES:
		_robot.call("set_move_input", Vector2.ZERO)
		var gold: int = int(st.get("banked_gold", 0))
		print("PROBE level1 kare=%d teslim=%d level=%d kasa_altın=%d hasar=%.3f parça=%d" % [
			_phase_frames, int(st.get("levels_delivered", 0)), int(st.get("level_number", 0)), gold,
			float(st.get("damage", 0.0)), int(_level.call("segment_count"))])
		if int(st.get("levels_delivered", 0)) != 1 or int(st.get("level_number", 0)) != 2:
			_fail("level 1 teslimatı level 2'yi başlatmalı: %s" % str(st))
		if gold <= 0:
			_fail("level 1 ödülü kasaya yazılmalı")
		if _finished_count != 0:
			_fail("sonsuz modda teslimat koşuyu bitirmemeli")
		if int(_level.call("segment_count")) > MAX_LIVE_SEGMENTS:
			_fail("canlı parça sayısı sınırsız büyüyor: %d" % int(_level.call("segment_count")))
		var pad2: float = float(_level.call("level_end_z"))
		if pad2 >= float(_pad1_z_first) - 60.0:
			_fail("level 2 bitişi level 1'den en az ~72 m ileride olmalı: %.2f" % pad2)
		_go(Phase.SETTLE if _phase == Phase.LEVEL1 else Phase.BATTERY)


func _step_settle() -> void:
	if _phase_frames < SETTLE_FRAMES:
		return
	# Level 2'yi sürmeden sonuna ışınla: engellere takılmadan geçiş zinciri sınanır.
	var end_z: float = float(_level.call("level_end_z"))
	_teleport_to(end_z + TELEPORT_BEFORE_PAD)
	_go(Phase.LEVEL2)


func _step_level2() -> void:
	_robot.call("set_move_input", Vector2(0.0, 1.0))
	var st: Dictionary = _state()
	if int(st.get("levels_delivered", 0)) >= 2 or _phase_frames >= LEVEL2_FRAMES:
		_robot.call("set_move_input", Vector2.ZERO)
		print("PROBE level2 kare=%d teslim=%d level=%d kasa_altın=%d" % [
			_phase_frames, int(st.get("levels_delivered", 0)), int(st.get("level_number", 0)),
			int(st.get("banked_gold", 0))])
		if int(st.get("levels_delivered", 0)) != 2 or int(st.get("level_number", 0)) != 3:
			_fail("level 2 teslimatı level 3'ü başlatmalı: %s" % str(st))
		_go(Phase.BREAK)


func _step_break() -> void:
	if _phase_frames == 5:
		_cargo.emit_signal("impact_reported", IMPACT_BREAK)
		return
	if _phase_frames < BREAK_FRAMES:
		return
	# Reklamla kurtarma teklif edildiyse reddet: koşu kırık bitsin.
	if _ctl.has_method("decline_revive") and bool(_state().get("revive_offered", false)):
		_ctl.call("decline_revive")
		return
	if _finished_count == 0:
		return
	var banked: int = int(_last_result.get("banked_gold", -1))
	var paid: int = int(_last_result.get("gold", -2))
	print("PROBE kırılma sonuç=%s" % str(_last_result))
	if not bool(_last_result.get("endless", false)) or String(_last_result.get("reason", "")) != "broken":
		_fail("kırılma sonucu endless + reason=broken olmalı")
	if bool(_last_result.get("success", true)):
		_fail("kırılan koşu success=false olmalı")
	if paid != banked / 2:
		_fail("kırılmada kasanın yarısı ödenmeli: kasa=%d ödenen=%d" % [banked, paid])
	if int(_last_result.get("levels_delivered", 0)) != 2 or int(_last_result.get("level", 0)) != 3:
		_fail("sonuç level/teslim sayısı yanlış")
	if float(_last_result.get("distance", 0.0)) < 100.0:
		_fail("mesafe en az ~130 m olmalı: %s" % str(_last_result.get("distance")))
	if int(_last_result.get("score", 0)) <= 0:
		_fail("puan > 0 olmalı")
	_go(Phase.RELOAD)


func _step_battery() -> void:
	if _phase_frames == 1:
		_ctl.call("set_battery_level", 0.0)
	_robot.call("set_move_input", Vector2(0.0, 0.2))
	if _finished_count == 0 and _phase_frames < BATTERY_FRAMES:
		return
	_robot.call("set_move_input", Vector2.ZERO)
	print("PROBE batarya sonuç=%s" % str(_last_result))
	if _finished_count != 1:
		_fail("batarya bitince koşu bir kez bitmeli (%d)" % _finished_count)
		_go(Phase.DONE)
		return
	if String(_last_result.get("reason", "")) != "battery":
		_fail("reason=battery olmalı: %s" % String(_last_result.get("reason", "")))
	if int(_last_result.get("gold", -1)) != int(_last_result.get("banked_gold", -2)):
		_fail("batarya bitişinde kasa tam ödenmeli")
	if not bool(_last_result.get("success", false)):
		_fail("batarya bitişi success=true sayılmalı (kırılma değil)")
	_go(Phase.FARLOAD)


## Uzak mesafe: yol robotun önüne kadar üretilir, robot 4 km'ye ışınlanır; durağan
## y titremesi ve kaymasızlık ölçülür (dünya geri çekme gerekip gerekmediğini söyler).
var _far_ys: Array[float] = []


func _step_far() -> void:
	if _phase_frames == 1:
		_ctl = get_first_node_in_group("game_controller")
		_robot = get_first_node_in_group("robot") as Node3D
		_level = _scene.get_node_or_null("Level")
		if _ctl == null or _robot == null or _level == null:
			_setup_fail("uzak mesafe: denetleyici/robot/Level bulunamadı")
			return
		for i: int in FAR_BUILD_CALLS:
			_level.call("update_world", FAR_Z)
		_teleport_to(FAR_Z)
		return
	if _phase_frames > FAR_SETTLE_FRAMES:
		_far_ys.append(_robot.global_position.y)
	if _phase_frames < FAR_SAMPLE_FRAMES:
		return
	var lowest: float = 1e9
	var highest: float = -1e9
	for y: float in _far_ys:
		lowest = minf(lowest, y)
		highest = maxf(highest, y)
	var jitter: float = highest - lowest
	var st: Dictionary = _state()
	print("PROBE uzak z=%.0f titreme=%.6f y=%.3f respawns=%d canlı_parça=%d" % [
		_robot.global_position.z, jitter, _robot.global_position.y, int(st.get("respawns", 0)),
		int(_level.call("segment_count"))])
	if jitter > FAR_MAX_JITTER:
		_fail("uzak mesafede durağan titreme çok büyük: %.6f" % jitter)
	if int(st.get("respawns", 0)) != 0:
		_fail("uzak mesafede robot zeminden düştü (zemin üretilmedi?)")
	if absf(_robot.global_position.z - FAR_Z) > 2.0:
		_fail("uzak mesafede robot kaydı: %.2f" % _robot.global_position.z)
	if int(_level.call("segment_count")) > MAX_LIVE_SEGMENTS:
		_fail("uzak mesafede canlı parça sayısı büyüdü: %d" % int(_level.call("segment_count")))
	_go(Phase.DONE)


func _teleport_to(z: float) -> void:
	_robot.global_position = Vector3(0.0, 0.7, z)
	var body: RigidBody3D = _robot as RigidBody3D
	if body != null:
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO


func _finish() -> void:
	if _done:
		return
	_done = true
	var code: int = 0
	if _setup_error != "":
		print("PROBE KURULUM HATASI: %s" % _setup_error)
		code = 2
	elif not _failures.is_empty():
		for message: String in _failures:
			print("PROBE BAŞARISIZ: %s" % message)
		code = 1
	else:
		print("PROBE SONUC: gecti (kare %d)" % _frames)
	quit(code)
