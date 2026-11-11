extends SceneTree

## Reklam yerleşimleri kabul probu (Faz 5). Sözleşme: ARCHITECTURE.md §5.5.
##
##   godot --headless --path . -s res://tools/ads_probe.gd
##
## Aşama `res://tools/ads_stage.txt` ("a" | "b") dosyasından okunur; lider belirler.
##   a: revive (CARGO_INSURANCE), reklam başarısızlığı, hızlı şarj (BATTERY_RECHARGE)
##   b: a + DOUBLE_REWARD, GOLDEN_BOX, TRY_BEFORE_BUY
## Çıkış: 0 geçti, 1 ölçüt başarısız, 2 kurulum hatası.
## Adımlar bir kuyrukta çalışır (her adım N fizik karesi sonra): headless ve deterministik.
## `-s` modunda autoload kimliği derlenmez (GOTCHAS.md #2): autoload'lara `/root/...` yoluyla erişilir.

const GAME_SCENE: String = "res://scenes/Game.tscn"
const RESULT_SCENE: String = "res://scenes/Result.tscn"
const GARAGE_SCENE: String = "res://scenes/Garage.tscn"
const SAVE_PATH: String = "user://ads_probe_save.json"
const STAGE_PATH: String = "res://tools/ads_stage.txt"
const DEADLINE_MS: int = 180000
const READY_FRAMES: int = 20
const SETTLE: int = 12
const DELIVERY_FRAMES: int = 1500
const GOLD_REWARD: int = 100
const SCRAP_REWARD: int = 6
const GOLDEN_GOLD: int = 150

var _queue: Array[Dictionary] = []
var _wait: int = 0
var _frames: int = 0
var _start_ms: int = 0
var _failures: Array[String] = []
var _setup_error: String = ""
var _stage_b: bool = false
var _ad: Node = null
var _gm: Node = null
var _save: Node = null
var _scene: Node = null
var _ctl: Node = null
var _robot: Node3D = null
var _cargo: Node = null
var _finished_count: int = 0
var _last_result: Dictionary = {}
var _deliver_frames: int = 0
var _done: bool = false


func _initialize() -> void:
	_start_ms = Time.get_ticks_msec()
	_stage_b = FileAccess.file_exists(STAGE_PATH) and FileAccess.get_file_as_string(STAGE_PATH).strip_edges() == "b"
	# Autoload düğümleri `_initialize` anında henüz yok olabilir (-s modu): kurulum ilk fizik karesinde.
	_enqueue(0, _setup)


func _setup() -> void:
	_ad = root.get_node_or_null("/root/AdManager")
	_gm = root.get_node_or_null("/root/GameManager")
	_save = root.get_node_or_null("/root/SaveService")
	if _ad == null or _gm == null:
		_setup_fail("AdManager/GameManager autoload yok")
		return
	if _stage_b and _save == null:
		_setup_fail("aşama b: /root/SaveService autoload yok (Faz 4b birleşmeli)")
		return
	var prov: Object = _ad.get("provider") as Object
	if prov == null or not ("instant" in prov) or not ("force_result" in prov):
		_setup_fail("AdManager.provider MockAdsProvider değil ya da instant/force_result alanları yok (§5.5)")
		return
	_gm.set("navigation_enabled", false)
	_enqueue(0, _load_game)


func _enqueue(wait_frames: int, fn: Callable) -> void:
	_queue.append({"wait": wait_frames, "fn": fn})


func _physics_process(_delta: float) -> bool:
	if _done:
		return true
	if Time.get_ticks_msec() - _start_ms > DEADLINE_MS:
		_setup_error = "zaman aşımı"
	_frames += 1
	if _setup_error == "":
		# `wait` = bu adım çalıştıktan SONRA beklenecek kare sayısı. Kuyruk boşken de sayaç azalır,
		# böylece son adımın beklemesi bitince prob kendiliğinden sonlanır (aksi halde zaman aşımına kadar asılır).
		if _wait > 0:
			_wait -= 1
		elif not _queue.is_empty():
			var item: Dictionary = _queue.pop_front()
			_wait = int(item["wait"])
			(item["fn"] as Callable).call()
	if _setup_error != "" or (_queue.is_empty() and _wait <= 0 and not _failures.has("__pending__")):
		if _setup_error != "" or _queue.is_empty():
			_finish()
	return _done


func _fail(message: String) -> void:
	_failures.append(message)


func _setup_fail(message: String) -> void:
	if _setup_error == "":
		_setup_error = message


func _state() -> Dictionary:
	return _ctl.call("state") as Dictionary


func _provider(result: int) -> void:
	var prov: Object = _ad.get("provider") as Object
	prov.set("instant", true)
	prov.set("force_result", result)


func _on_finished(result: Dictionary) -> void:
	_finished_count += 1
	_last_result = result


func _reset_run() -> void:
	_ctl.call("restart")
	_finished_count = 0
	_last_result = {}


func _hit(impulse: float) -> void:
	_cargo.emit_signal("impact_reported", impulse)


# ---------------------------------------------------------------- aşama a
func _load_game() -> void:
	_provider(1)
	if _stage_b:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
		_save.call("set_save_path", SAVE_PATH)
		_save.call("load_profile")
	_gm.set("selected_cargo_id", "pencil_battery")
	var packed: PackedScene = load(GAME_SCENE) as PackedScene
	if packed == null:
		_setup_fail("%s yüklenemedi" % GAME_SCENE)
		return
	_scene = packed.instantiate()
	root.add_child(_scene)
	_enqueue(READY_FRAMES, _bind_game)


func _bind_game() -> void:
	_ctl = get_first_node_in_group("game_controller")
	_robot = get_first_node_in_group("robot") as Node3D
	_cargo = get_first_node_in_group("cargo")
	if _ctl == null or _robot == null or _cargo == null:
		_setup_fail("game_controller/robot/cargo bulunamadı")
		return
	for method: String in ["accept_revive", "decline_revive", "request_recharge", "state", "restart", "set_battery_level"]:
		if not _ctl.has_method(method):
			_setup_fail("GameController.%s() yok" % method)
	if not _ctl.has_signal("revive_offered"):
		_setup_fail("GameController.revive_offered sinyali yok")
	if _setup_error != "":
		return
	_ctl.connect("finished", _on_finished)
	_provider(1)
	_reset_run()
	_enqueue(5, _revive_break1)


func _revive_break1() -> void:
	_hit(5000.0)
	_enqueue(SETTLE, _revive_check_offer)


func _revive_check_offer() -> void:
	var st: Dictionary = _state()
	print("PROBE revive teklif offered=%s finished=%d" % [str(st.get("revive_offered")), _finished_count])
	if not bool(st.get("revive_offered", false)):
		_fail("kargo kırılınca revive teklif edilmedi (revive_offered=false)")
	if _finished_count != 0:
		_fail("revive teklif edilirken tur bitmemeliydi (finished=%d)" % _finished_count)
	if bool(st.get("revive_offered", false)):
		_ctl.call("accept_revive")
	_enqueue(SETTLE, _revive_check_applied)


func _revive_check_applied() -> void:
	var st: Dictionary = _state()
	print("PROBE revive uygulandı damage=%.3f broken=%s used=%s y=%.2f" % [float(st.get("damage", -1.0)), str(st.get("broken")), str(st.get("revive_used")), _robot.global_position.y])
	if absf(float(st.get("damage", 1.0))) > 0.001 or bool(st.get("broken", true)):
		_fail("revive sonrası kargo sağlam olmalı: %s" % str(st))
	if not bool(st.get("revive_used", false)):
		_fail("revive_used true olmalı")
	if _finished_count != 0:
		_fail("revive sonrası tur bitmemeli")
	if _robot.global_position.y < -1.0:
		_fail("revive sonrası robot zeminin altında")
	_hit(5000.0)   # ikinci kırılma: teklif YOK, tur biter
	_enqueue(SETTLE, _revive_second)


func _revive_second() -> void:
	var st: Dictionary = _state()
	print("PROBE revive ikinci_kırılma offered=%s finished=%d" % [str(st.get("revive_offered")), _finished_count])
	if bool(st.get("revive_offered", false)):
		_fail("tur başına yalnız bir revive: ikinci teklif yapılmamalı")
	if _finished_count != 1 or bool(_last_result.get("success", true)):
		_fail("ikinci kırılma turu başarısız bitirmeli (finished=%d, sonuç=%s)" % [_finished_count, str(_last_result)])
	_reset_run()
	_provider(0)   # reklam başarısız
	_enqueue(5, _revive_fail_break)


func _revive_fail_break() -> void:
	_hit(5000.0)
	_enqueue(SETTLE, _revive_fail_accept)


func _revive_fail_accept() -> void:
	if bool(_state().get("revive_offered", false)):
		_ctl.call("accept_revive")
	else:
		_fail("reklam başarısızlık testi: teklif beklenirdi")
	_enqueue(SETTLE, _revive_fail_check)


func _revive_fail_check() -> void:
	var st: Dictionary = _state()
	print("PROBE revive reklam_başarısız finished=%d used=%s" % [_finished_count, str(st.get("revive_used"))])
	if _finished_count != 1 or bool(_last_result.get("success", true)):
		_fail("reklam başarısızsa tur kırık bitmeli (finished=%d)" % _finished_count)
	if bool(st.get("revive_used", false)):
		_fail("başarısız reklamda revive_used true olmamalı")
	_reset_run()
	_provider(1)
	_ctl.call("set_battery_level", 0.05)
	_enqueue(SETTLE, _recharge_check_available)


func _recharge_check_available() -> void:
	var st: Dictionary = _state()
	var btn: Node = _scene.find_child("RechargeButton", true, false)
	print("PROBE şarj available=%s düğme_var=%s" % [str(st.get("recharge_available")), str(btn != null)])
	if not bool(st.get("recharge_available", false)):
		_fail("düşük bataryada recharge_available true olmalı")
	if btn == null:
		_fail("HUD'da RechargeButton yok")
	elif not bool(btn.get("visible")):
		_fail("RechargeButton düşük bataryada görünür olmalı")
	_ctl.call("request_recharge")
	_enqueue(SETTLE, _recharge_check_done)


func _recharge_check_done() -> void:
	var st: Dictionary = _state()
	print("PROBE şarj sonrası battery=%.2f boost=%s" % [float(st.get("battery", 0.0)), str(st.get("boost_active"))])
	if float(st.get("battery", 0.0)) < 0.99:
		_fail("hızlı şarj bataryayı %100 yapmalı: %.2f" % float(st.get("battery", 0.0)))
	if not bool(st.get("boost_active", false)):
		_fail("hızlı şarj boost vermeli")
	_ctl.call("set_battery_level", 0.05)
	_enqueue(SETTLE, _recharge_limit)


func _recharge_limit() -> void:
	if bool(_state().get("recharge_available", true)):
		_fail("tur başına bir hızlı şarj: ikinci teklif yapılmamalı")
	if _stage_b:
		_reset_run()
		_enqueue(5, _b_double_setup)
	else:
		_enqueue(1, _noop)


func _noop() -> void:
	pass


# ---------------------------------------------------------------- aşama b
func _result_scene_with(result: Dictionary) -> Node:
	_gm.set("last_result", result)
	var packed: PackedScene = load(RESULT_SCENE) as PackedScene
	if packed == null:
		_setup_fail("%s yüklenemedi" % RESULT_SCENE)
		return null
	var n: Node = packed.instantiate()
	root.add_child(n)
	return n


func _wallet_gold() -> int:
	var p: Object = _save.call("profile") as Object
	return int(((p.call("wallet") as Object).call("to_dict") as Dictionary).get("gold", -1))


func _b_double_setup() -> void:
	_save.call("load_profile")
	_provider(1)
	var res: Dictionary = {"success": true, "gold": GOLD_REWARD, "scrap": SCRAP_REWARD, "stars": 3, "cargo_id": "pencil_battery", "fee": GOLD_REWARD}
	var rs: Node = _result_scene_with(res)
	if rs == null:
		return
	_scene.queue_free()
	_scene = rs
	_enqueue(5, _b_double_press)


func _b_double_press() -> void:
	var btn: BaseButton = _scene.find_child("DoubleRewardButton", true, false) as BaseButton
	var before: int = _wallet_gold()
	print("PROBE 2x önce cüzdan_altın=%d" % before)
	if btn == null:
		_fail("Result'ta DoubleRewardButton yok")
		_enqueue(1, _b_golden_setup)
		return
	btn.pressed.emit()
	_enqueue(SETTLE, _b_double_check.bind(before))


func _b_double_check(before: int) -> void:
	var after: int = _wallet_gold()
	var btn: BaseButton = _scene.find_child("DoubleRewardButton", true, false) as BaseButton
	print("PROBE 2x sonra cüzdan_altın=%d (önce %d)" % [after, before])
	if after - before != GOLD_REWARD:
		_fail("2× ödül ikinci kez %d altın eklemeli: %d -> %d" % [GOLD_REWARD, before, after])
	if btn != null and bool(btn.get("visible")) and not bool(btn.get("disabled")):
		btn.pressed.emit()   # ikinci basış etkisiz olmalı
	_enqueue(SETTLE, _b_double_once.bind(after))


func _b_double_once(after: int) -> void:
	if _wallet_gold() != after:
		_fail("2× ödül tek seferlik olmalı")
	_scene.queue_free()
	_enqueue(2, _b_golden_setup)


func _b_golden_setup() -> void:
	_gm.set("selected_cargo_id", "pencil_battery")
	_scene = (load(GAME_SCENE) as PackedScene).instantiate()
	root.add_child(_scene)
	_enqueue(READY_FRAMES, _b_golden_bind)


func _b_golden_bind() -> void:
	_ctl = get_first_node_in_group("game_controller")
	_robot = get_first_node_in_group("robot") as Node3D
	_cargo = get_first_node_in_group("cargo")
	_ctl.connect("finished", _on_finished)
	_provider(1)
	_reset_run()
	var boxes: Array[Node] = get_nodes_in_group("golden_box")
	print("PROBE altın_kutu sayı=%d" % boxes.size())
	if boxes.is_empty():
		_fail("seviyede 'golden_box' grubunda kutu yok")
		_enqueue(1, _b_trial_setup)
		return
	var box: Node3D = boxes[0] as Node3D
	var rb: RigidBody3D = _robot as RigidBody3D
	_robot.global_position = box.global_position + Vector3(0.0, 0.6, 0.0)
	if rb != null:
		rb.linear_velocity = Vector3.ZERO
		rb.angular_velocity = Vector3.ZERO
	_enqueue(SETTLE * 2, _b_golden_collected)


func _b_golden_collected() -> void:
	var st: Dictionary = _state()
	print("PROBE altın_kutu toplandı=%s" % str(st.get("golden_box_collected")))
	if not bool(st.get("golden_box_collected", false)):
		_fail("robot kutuya değince golden_box_collected true olmalı")
	var zone: Node3D = _scene.find_child("DeliveryZone", true, false) as Node3D
	var rb: RigidBody3D = _robot as RigidBody3D
	_robot.global_position = zone.global_position + Vector3(0.0, 0.6, 6.0)
	_robot.global_rotation = Vector3.ZERO
	if rb != null:
		rb.linear_velocity = Vector3.ZERO
		rb.angular_velocity = Vector3.ZERO
	_deliver_frames = 0
	_enqueue(15, _b_golden_drive)


func _b_golden_drive() -> void:
	_robot.call("set_move_input", Vector2(0.0, 1.0))
	_deliver_frames += 1
	if _finished_count == 0 and _deliver_frames < DELIVERY_FRAMES:
		_enqueue(0, _b_golden_drive)
		return
	_robot.call("set_move_input", Vector2.ZERO)
	print("PROBE altın_kutu teslimat sonuç=%s" % str(_last_result))
	if _finished_count != 1 or not bool(_last_result.get("success", false)):
		_fail("altın kutuyla teslimat başarılı olmalı: %s" % str(_last_result))
	if not bool(_last_result.get("golden_box", false)):
		_fail("sonuçta golden_box=true olmalı")
	var rs: Node = _result_scene_with(_last_result)
	if rs == null:
		return
	_scene.queue_free()
	_scene = rs
	_enqueue(5, _b_golden_press)


func _b_golden_press() -> void:
	var btn: BaseButton = _scene.find_child("GoldenBoxButton", true, false) as BaseButton
	var before: int = _wallet_gold()
	if btn == null:
		_fail("Result'ta GoldenBoxButton yok")
		_enqueue(1, _b_trial_setup)
		return
	btn.pressed.emit()
	_enqueue(SETTLE, _b_golden_check.bind(before))


func _b_golden_check(before: int) -> void:
	var after: int = _wallet_gold()
	print("PROBE altın_kutu bonus cüzdan %d -> %d" % [before, after])
	if after - before != GOLDEN_GOLD:
		_fail("Altın Kutu bonusu %d altın olmalı: %d -> %d" % [GOLDEN_GOLD, before, after])
	_scene.queue_free()
	_enqueue(2, _b_trial_setup)


func _b_trial_setup() -> void:
	_save.call("load_profile")
	_save.call("grant", 500, 30)
	var packed: PackedScene = load(GARAGE_SCENE) as PackedScene
	_scene = packed.instantiate()
	root.add_child(_scene)
	_enqueue(5, _b_trial_press)


func _b_trial_press() -> void:
	var btn: BaseButton = _scene.find_child("TryButton_chassis", true, false) as BaseButton
	if btn == null:
		_fail("Garage'da TryButton_chassis yok")
		_enqueue(1, _noop)
		return
	_provider(1)
	btn.pressed.emit()
	_enqueue(SETTLE, _b_trial_check)


func _b_trial_check() -> void:
	var trial: String = str(_save.call("trial"))
	var mods: Dictionary = _save.call("mods") as Dictionary
	print("PROBE deneme trial='%s' mods=%s" % [trial, str(mods)])
	if trial != "chassis":
		_fail("TRY_BEFORE_BUY sonrası trial() == 'chassis' olmalı: '%s'" % trial)
	if absf(float(mods.get("cargo_damping_bonus", -1.0)) - 1.0) > 0.001:
		_fail("deneme modları mods()'a yansımalı (cargo_damping_bonus 1.0): %s" % str(mods))
	_scene.queue_free()
	_gm.set("selected_cargo_id", "pencil_battery")
	_scene = (load(GAME_SCENE) as PackedScene).instantiate()
	root.add_child(_scene)
	_enqueue(READY_FRAMES, _b_trial_game)


func _b_trial_game() -> void:
	_ctl = get_first_node_in_group("game_controller")
	var mods: Variant = (_state().get("mods"))
	print("PROBE deneme game_mods=%s trial_sonra='%s'" % [str(mods), str(_save.call("trial"))])
	if not (mods is Dictionary) or absf(float((mods as Dictionary).get("cargo_damping_bonus", -1.0)) - 1.0) > 0.001:
		_fail("deneme etkisi Game koşusunda state.mods'ta görünmeli: %s" % str(mods))
	if str(_save.call("trial")) != "":
		_fail("deneme tek koşuluk: Game başlayınca trial() boş olmalı")


func _finish() -> void:
	if _done:
		return
	_done = true
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	if _setup_error != "":
		print("PROBE KURULUM HATASI: %s" % _setup_error)
		quit(2)
		return
	if _failures.is_empty():
		print("PROBE SONUC: gecti (kare %d, aşama %s)" % [_frames, ("b" if _stage_b else "a")])
		quit(0)
	else:
		for f: String in _failures:
			print("PROBE HATA: %s" % f)
		print("PROBE SONUC: basarisiz (%d hata)" % _failures.size())
		quit(1)
