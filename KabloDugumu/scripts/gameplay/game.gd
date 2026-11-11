extends Node3D

## Oyun sahnesi orkestrasyonu: HUD, ses, ödüllü reklam akışı, kazanma/kaybetme
## ve QA kancaları. Dünya kuralları LevelController'da; burada oturum akışı var.

enum State { INTRO, PLAYING, WON, FAILED, PAUSED }

const HUD_SYNC_INTERVAL: float = 0.12
const TOAST_COOLDOWN: float = 1.4
const WIN_DELAY: float = 1.2
const HINT_VISIBLE_SECONDS: float = 7.0
const VOLTAGE_SCALE: float = 250.0

var _level: LevelController = null
var _board: BoardBuilder = null
var _sparks: SparkBurst = null
var _input: GameInput = null
var _state: int = State.INTRO
var _elapsed: float = 0.0
var _level_number: int = 1
var _level_name: String = ""
var _par_seconds: float = 60.0
var _hint: String = ""
var _hint_left: float = 0.0
var _pending_reward: int = -1
var _applied_rewards: Dictionary = {}
var _hud_accum: float = 0.0
var _toast_left: float = 0.0
var _shield_seconds: float = 10.0
var _revive_seconds: float = 15.0

@onready var _board_node: Node3D = $Board
@onready var _cable_root: Node3D = $CableRoot
@onready var _sparks_node: Node3D = $Sparks
@onready var _camera: CameraRig = $CameraRig as CameraRig
@onready var _hud: GameHUD = $HUD as GameHUD
@onready var _lights_node: Node3D = get_node_or_null("Lights") as Node3D
@onready var _world_env: WorldEnvironment = get_node_or_null("WorldEnvironment") as WorldEnvironment

## blackout fallback: BoardBuilder.set_blackout yoksa ışık enerjilerini kısarız.
var _light_base: Dictionary = {}
var _ambient_base: float = 1.0


func _ready() -> void:
	GameManager.set_phase(GameManager.Phase.GAME)
	AdManager.reset_run_limits()
	_connect_ads()
	_connect_hud()
	GameManager.back_requested.connect(_on_back_requested)
	_build_world()
	_cache_lights()
	_start_ambient()
	if _level == null:
		return
	_configure_hud()
	_camera.intro_finished.connect(_on_intro_finished, CONNECT_ONE_SHOT)
	_camera.play_intro()
	AudioService.play("level_start")


func _process(delta: float) -> void:
	if _state != State.PLAYING or _level == null:
		return
	_elapsed += delta
	_toast_left = maxf(0.0, _toast_left - delta)
	_hint_left = maxf(0.0, _hint_left - delta)
	if _hint_left <= 0.0 and _hint != "":
		_hint = ""
		_hud.set_hint("")
	_hud_accum += delta
	if _hud_accum >= HUD_SYNC_INTERVAL:
		_hud_accum = 0.0
		_sync_hud()


func _physics_process(delta: float) -> void:
	if _level != null:
		_level.tick(delta)


# --- kurulum -------------------------------------------------------------

func _build_world() -> void:
	var level_config: Dictionary = _find_level_config(GameManager.level_index)
	if level_config.is_empty():
		push_error("game.gd: bölüm %d verisi bulunamadı" % GameManager.level_index)
		return
	var levels_table: Dictionary = GameData.table("levels")
	var colors: Dictionary = _dict(levels_table, "colors")
	var balance: Dictionary = GameData.table("balance")
	var layout: Dictionary = _dict(balance, "board")
	var overload_cfg: Dictionary = _dict(balance, "overload")
	_shield_seconds = float(overload_cfg.get("shield_seconds", 10.0))
	_revive_seconds = float(overload_cfg.get("revive_shield_seconds", 15.0))
	_level_number = int(level_config.get("id", 1))
	_level_name = _localized_name(_level_number, level_config)
	_par_seconds = float(level_config.get("par_seconds", 60.0))
	_hint = _localized_hint(_level_number, level_config)

	_board = BoardBuilder.new()
	_board.name = "BoardBuilder"
	_board_node.add_child(_board)
	_board.build(layout)

	_sparks = SparkBurst.new()
	_sparks.name = "SparkBurst"
	_sparks_node.add_child(_sparks)

	# Tam balance tablosu verilir: board bolumu ic ice okunur, modifier ayarlari
	# (locked_socket sayisi, sway genligi) da veri odakli kalir (ARCHITECTURE §12).
	var knot: KnotLevel = KnotLevel.from_config(level_config, colors, balance)
	_level = LevelController.new()
	_level.build(knot, _board, _cable_root, _sparks, _camera)
	_level.snap_done.connect(_on_snap_done)
	_level.wrong_socket_try.connect(_on_wrong_socket_try)
	_level.short_circuit.connect(_on_short_circuit)
	_level.connections_changed.connect(_on_connections_changed)
	_level.fuse_blown.connect(_on_fuse_blown)
	_level.level_completed.connect(_on_level_completed)
	_level.locked_socket_hint.connect(_on_locked_socket_hint)
	_level.socket_unlocked.connect(_on_socket_unlocked)
	_level.blackout_changed.connect(_on_blackout_changed)

	_input = GameInput.new()
	_input.setup(_camera, _level, float(layout.get("drag_lift", 0.3)), _board.board_bounds())
	_input.grabbed.connect(_on_cable_grabbed)


func _configure_hud() -> void:
	_hud.setup(_level_number, _level_name, _level.total_cables(), _par_seconds)
	_hud.set_hint(_hint)
	_hint_left = HINT_VISIBLE_SECONDS
	_sync_hud()
	# sway: bölüm başında tek seferlik canlı hat uyarısı (telegraph, ASMR tonunda).
	if _level.has_modifier(KnotLevel.MODIFIER_SWAY):
		_toast(_loc("toast.live_wires"))


func _sync_hud() -> void:
	var load_value: float = _level.overload.value
	_hud.set_timer(_elapsed)
	_hud.set_connected(_level.connected, _level.total_cables())
	_hud.set_overload(load_value)
	_hud.set_voltage(int(roundf(load_value * VOLTAGE_SCALE)))
	_hud.set_shield(_level.overload.shield_left)
	_hud.set_ad_buttons(AdManager.can_offer(AdManager.Placement.GOLDEN_CUTTER),
		AdManager.can_offer(AdManager.Placement.INSULATION_SPRAY))
	if _board != null and _board.voltmeter != null:
		_board.voltmeter.set_load(load_value)


# --- girdi ---------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _state != State.PLAYING or _input == null:
		return
	_input.handle_event(event)


func _on_cable_grabbed(_cable_index: int) -> void:
	AudioService.play("cable_pull", 0.12)


# --- LevelController sinyalleri ------------------------------------------

func _on_snap_done(_cable_index: int, _socket_index: int) -> void:
	AudioService.play("clack", 0.06)
	_camera.shake(0.08)


func _on_wrong_socket_try(_cable_index: int, _socket_index: int) -> void:
	AudioService.play("wrong_socket")
	_toast(_loc("toast.wrong_socket"))


func _on_short_circuit(_point: Vector3, _color: Color) -> void:
	AudioService.play("spark", 0.2)
	_toast(_loc("toast.short_circuit"))


## locked_socket: kilitli prizin yanında fiş tutuluyor / kilide bırakıldı.
func _on_locked_socket_hint(_socket_index: int) -> void:
	_toast(_loc("toast.locked_socket"))


## Kapak açıldı: yumuşak mekanik "clack" (ASMR).
func _on_socket_unlocked(_socket_index: int) -> void:
	AudioService.play("clack", 0.12)


## blackout: panoya yumuşak sönme; board API'si varsa ona delege et.
func _on_blackout_changed(amount: float) -> void:
	_apply_blackout(amount)


func _on_connections_changed(done: int, total: int) -> void:
	_hud.set_connected(done, total)


func _on_level_completed() -> void:
	if _state == State.WON or _state == State.FAILED:
		return
	_state = State.WON
	_disable_input()
	_clear_toast()
	_hud.set_hint("")
	_camera.reset_parallax()
	_camera.shake(0.18)
	if _board != null and _board.voltmeter != null:
		_board.voltmeter.settle()
	_sync_hud()
	AudioService.play("win")
	var scoring: Dictionary = LevelScoring.compute(_elapsed, _par_seconds,
		_level.shorts, _level.overload.peak)
	_hud.celebrate(int(scoring.get("stars", 1)))
	var result: Dictionary = scoring.duplicate(true)
	result["level"] = _level_number
	result["name"] = _level_name
	get_tree().create_timer(WIN_DELAY).timeout.connect(_finish_level.bind(result))


func _finish_level(result: Dictionary) -> void:
	GameManager.complete_level(result)


func _on_fuse_blown() -> void:
	if _state != State.PLAYING:
		return
	_state = State.FAILED
	_disable_input()
	_clear_toast()
	_camera.reset_parallax()
	AudioService.play("fuse_pop")
	_hud.set_overload(1.0)
	_hud.set_voltage(int(VOLTAGE_SCALE))
	_hud.set_shield(0.0)
	if _board != null and _board.voltmeter != null:
		_board.voltmeter.set_load(1.0)
	_hud.set_ad_buttons(false, false)
	_hud.show_fail(_loc("fail.reason"),
		AdManager.can_offer(AdManager.Placement.FUSE_RESCUE))


# --- reklam / ödüller ----------------------------------------------------

func _connect_ads() -> void:
	AdManager.ad_started.connect(_on_ad_started)
	AdManager.rewarded_finished.connect(_on_rewarded_finished)


func _on_ad_started(placement: int) -> void:
	_pending_reward = placement
	_hud.show_ad_overlay(true)
	_hud.set_ad_buttons(false, false)
	if _input != null:
		_input.set_enabled(false)  # reklam sırasında fiş tutulamaz


func _on_rewarded_finished(placement: int, success: bool) -> void:
	_hud.show_ad_overlay(false)
	_pending_reward = -1
	if _state == State.PLAYING:
		_enable_input()
	if not success:
		_hud.toast(_loc("toast.ad_failed"))
		return
	if _applied_rewards.has(placement):
		return
	_applied_rewards[placement] = true
	match placement:
		AdManager.Placement.GOLDEN_CUTTER:
			_reward_cutter()
		AdManager.Placement.INSULATION_SPRAY:
			_reward_spray()
		AdManager.Placement.FUSE_RESCUE:
			_reward_revive()


func _reward_cutter() -> void:
	if _state != State.PLAYING:
		return
	var target: int = _level.best_cutter_target()
	if target < 0:
		_hud.toast(_loc("toast.cutter_none"))
		return
	_level.cutter_snap(target)
	if _state != State.PLAYING:
		return  # keski son fişi bağladıysa zafer akışı devralır
	_level.apply_shield(2.0)
	AudioService.play("cutter")
	_hud.toast(_loc("toast.cutter_done"))


func _reward_spray() -> void:
	if _state != State.PLAYING:
		return
	_level.apply_shield(_shield_seconds)
	AudioService.play("shield_on")
	_hud.toast(Loc.t("toast.spray_done", {"sec": int(_shield_seconds)}))


func _reward_revive() -> void:
	if _state != State.FAILED:
		return
	_level.revive(_revive_seconds)
	_state = State.PLAYING
	_enable_input()
	_hud.hide_fail()
	_clear_toast()
	AudioService.play("shield_on")
	_hud.toast(_loc("toast.revive_done"))


# --- HUD eylemleri -------------------------------------------------------

func _connect_hud() -> void:
	_hud.cutter_pressed.connect(_request_ad.bind(AdManager.Placement.GOLDEN_CUTTER))
	_hud.spray_pressed.connect(_request_ad.bind(AdManager.Placement.INSULATION_SPRAY))
	_hud.revive_pressed.connect(_on_revive_pressed)
	_hud.retry_pressed.connect(_on_retry_pressed)
	_hud.menu_pressed.connect(_on_menu_pressed)
	_hud.pause_pressed.connect(_on_pause_pressed)
	_hud.resume_pressed.connect(_on_resume_pressed)


func _request_ad(placement: int) -> void:
	if _state != State.PLAYING or _pending_reward != -1:
		return
	if not AdManager.can_offer(placement):
		_hud.toast(_loc("toast.ad_unavailable"))
		return
	AdManager.show_rewarded(placement)


func _on_revive_pressed() -> void:
	if _state != State.FAILED or _pending_reward != -1:
		return
	if not AdManager.can_offer(AdManager.Placement.FUSE_RESCUE):
		_hud.toast(_loc("toast.ad_unavailable"))
		return
	AdManager.show_rewarded(AdManager.Placement.FUSE_RESCUE)


func _on_retry_pressed() -> void:
	_clear_toast()
	get_tree().paused = false
	GameManager.replay_level()


func _on_menu_pressed() -> void:
	get_tree().paused = false
	GameManager.goto_menu()


func _on_pause_pressed() -> void:
	if _state != State.PLAYING:
		return
	_state = State.PAUSED
	_disable_input()
	get_tree().paused = true
	_hud.show_pause(true)


func _on_resume_pressed() -> void:
	if _state != State.PAUSED:
		return
	get_tree().paused = false
	_state = State.PLAYING
	_enable_input()
	_hud.show_pause(false)


func _on_back_requested() -> void:
	if _state == State.PAUSED:
		_on_resume_pressed()
	elif _state == State.PLAYING or _state == State.INTRO:
		_on_pause_pressed()
	else:
		_on_menu_pressed()


func _on_intro_finished() -> void:
	if _state == State.INTRO:
		_state = State.PLAYING
		_enable_input()


func _disable_input() -> void:
	if _input != null:
		_input.set_enabled(false)
		_input.cancel()


func _enable_input() -> void:
	if _input != null:
		_input.set_enabled(true)


# --- QA API --------------------------------------------------------------

func force_snap(cable_index: int) -> bool:
	if _level == null:
		return false
	return _level.force_snap(cable_index)


func force_contact(cable_index_a: int, cable_index_b: int) -> void:
	if _level == null:
		return
	_level.force_contact(cable_index_a, cable_index_b)


## QA: barı doğrudan doldurur (kalkan aktifken de fail karesi alınabilsin).
## Kural dışıdır; LevelController bir sonraki fizik karesinde sigortayı attırır.
func force_overload(amount: float) -> void:
	if _level == null or _level.overload == null:
		return
	var target: float = clampf(amount, 0.0, 1.0)
	_level.overload.value = target
	_level.overload.peak = maxf(_level.overload.peak, target)
	_level.overload.blown = target >= 1.0


## QA: fast_overload çarpanı (modifier yoksa 1.0).
func fill_multiplier() -> float:
	if _level == null:
		return 1.0
	return _level.monitor.fill_multiplier()


func debug_state() -> Dictionary:
	if _level == null:
		return {"level": _level_number, "connected": 0, "total": 0,
			"overload": 0.0, "shorts": 0, "elapsed": _elapsed,
			"state": _state_name(), "modifiers": []}
	return {
		"level": _level_number,
		"connected": _level.connected,
		"total": _level.total_cables(),
		"overload": _level.overload.value,
		"shorts": _level.shorts,
		"elapsed": _elapsed,
		"state": _state_name(),
		"modifiers": _modifier_names(),
		"obstacles": _level.obstacle_count(),
		"locked_sockets": _level.locked_socket_count(),
		"blackout": _level.blackout_amount(),
	}


# --- yardımcılar ---------------------------------------------------------

func _toast(text: String) -> void:
	if _toast_left > 0.0:
		return
	_hud.toast(text)
	_toast_left = TOAST_COOLDOWN


## Eski toast/hint'i temizle (retry / revive / win anında kalmasın).
func _clear_toast() -> void:
	_hud.toast("")
	_toast_left = 0.0


func _state_name() -> String:
	if _state < 0 or _state >= State.size():
		return "unknown"
	return String(State.keys()[_state]).to_lower()


func _find_level_config(level_number: int) -> Dictionary:
	var raw_levels: Variant = GameData.table("levels").get("levels", [])
	if not (raw_levels is Array):
		return {}
	for entry: Variant in raw_levels as Array:
		if entry is Dictionary:
			var config: Dictionary = entry as Dictionary
			if int(config.get("id", -1)) == level_number:
				return config
	return {}


func _dict(source: Dictionary, key: String) -> Dictionary:
	var raw: Variant = source.get(key, {})
	if raw is Dictionary:
		return raw as Dictionary
	return {}


# --- v0.2: yerelleştirme, atmosfer ve modifier görselleri ----------------

## Loc anahtarı varsa yerelleştirilmiş metin, yoksa veri dosyasındaki yedek.
func _loc(key: String, fallback: String = "") -> String:
	if Loc.has(key):
		return Loc.t(key)
	if fallback != "":
		return fallback
	return Loc.t(key)


func _localized_name(level: int, config: Dictionary) -> String:
	var key: String = "level.%d.name" % level
	if Loc.has(key):
		return Loc.t(key)
	return String(config.get("name", "Level %d" % level))


func _localized_hint(level: int, config: Dictionary) -> String:
	var key: String = "level.%d.hint" % level
	if Loc.has(key):
		return Loc.t(key)
	return String(config.get("hint", ""))


func _modifier_names() -> Array[String]:
	var names: Array[String] = []
	if _level == null or _level.knot == null:
		return names
	for modifier: StringName in _level.knot.modifiers:
		names.append(String(modifier))
	return names


## blackout: önce BoardBuilder.set_blackout (live-world API'si), sonra sahne
## ışıkları ve ortam ışığı yumuşakça kısılır (API yoksa da oyun bozulmaz).
func _apply_blackout(amount: float) -> void:
	var sealed: float = clampf(amount, 0.0, 1.0)
	if _board != null and is_instance_valid(_board) and _board.has_method("set_blackout"):
		_board.call("set_blackout", sealed)
	var factor: float = lerpf(1.0, 0.45, sealed)
	for key: Variant in _light_base.keys():
		var light: Light3D = key as Light3D
		if light != null and is_instance_valid(light):
			light.light_energy = float(_light_base[key]) * factor
	if _world_env != null and _world_env.environment != null:
		_world_env.environment.ambient_light_energy = _ambient_base * factor


func _cache_lights() -> void:
	_light_base.clear()
	if _lights_node != null:
		for child: Node in _lights_node.get_children():
			var light: Light3D = child as Light3D
			if light != null:
				_light_base[light] = light.light_energy
	if _world_env != null and _world_env.environment != null:
		_ambient_base = _world_env.environment.ambient_light_energy


## ASMR zemin: oyun içi sakin uğultu (AudioService ambient API'si; ses yoksa sessiz).
func _start_ambient() -> void:
	if AudioService.has_method("play_ambient"):
		AudioService.call("play_ambient", "ambient_hum", 1.5)
