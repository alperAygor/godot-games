extends SceneTree

## QA akış aracı (v0.2 ASMR redesign): Boot → Menu(EN) → LevelSelect → Menu(TR) →
## Game(TR) → Game(EN) → kıvılcım → kalkan → fail → win → Result.
## Gerçek pencere gerekir (headless'ta hemen çıkar); her adımda PNG alınır.
##
##   godot --path . -s res://tools/flow_shot.gd -- --out-dir=/tmp/kablo_v02_shots
##
## Deterministik: bölüm ilerlemesi (profil) ve dil geçici olarak sıfırlanır,
## akış sonunda diskteki değerlerine geri yüklenir.
## Çıkış: 0 = en az MIN_SHOTS kare alındı, 1 = kritik hata.

const MIN_SHOTS: int = 8
## Bir adımın koşulunun gerçekleşmesi için tanınan süre (sn).
const STEP_TIMEOUT: float = 6.0
## Tüm akış için sert sınır.
const DEADLINE: float = 100.0
const BOOT_SCENE: String = "res://scenes/Boot.tscn"
## Basılınca sahne değiştiren butonlar: yeni sahne örneği beklenir.
const SCENE_BUTTONS: Array[String] = [
	"PlayButton", "RetryButton", "NextButton", "MenuButton", "BackButton", "LevelsButton",
]

var _plan: Array[Dictionary] = []
var _index: int = 0
var _elapsed: float = 0.0
var _out_dir: String = "/tmp/kablo_v02_shots"
var _done: bool = false
var _shots: Array[String] = []
var _warnings: Array[String] = []
var _last_state: Dictionary = {}
## Sahne değiştiren aksiyondan sonra eski örnek: yeni örnek beklenir.
var _expect_new_instance: int = 0
## Adım başına kare sayacı (settle_frames koşulu için).
var _step_frame: int = 0
var _step_seen: int = -1
## Profil/dil yedeği: akış deterministik başlasın, sonunda geri yüklensin.
var _profile_backup: Dictionary = {}
var _profile_frozen: bool = false
var _locale_backup: String = ""
var _locale_saved: bool = false


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out-dir="):
			_out_dir = arg.trim_prefix("--out-dir=")
	if DisplayServer.get_name() == "headless":
		printerr("FLOW FAIL: headless modda ekran görüntüsü alınamaz; gerçek pencere gerekir")
		_finish(1)
		return
	# Pencere başka uygulamanın arkasında kalırsa macOS çizimi durdurabilir:
	# kareler donuk (aynı sha) gelirdi. Bu yüzden akış boyunca önde tutulur.
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	DisplayServer.window_move_to_foreground()
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_clear_old_pngs()
	_plan = _build_plan()
	var packed: PackedScene = load(BOOT_SCENE) as PackedScene
	if packed == null:
		printerr("FLOW FAIL: %s yüklenemedi" % BOOT_SCENE)
		_finish(1)
		return
	var scene: Node = packed.instantiate()
	if scene == null:
		printerr("FLOW FAIL: %s örneklenemedi" % BOOT_SCENE)
		_finish(1)
		return
	root.add_child(scene)
	current_scene = scene
	print("FLOW out_dir: %s (%d adım)" % [_out_dir, _plan.size()])


func _process(delta: float) -> bool:
	if _done:
		return true
	if not _profile_frozen:
		_profile_frozen = true
		_freeze_profile()
		_save_locale()
	_elapsed += delta
	if _elapsed > DEADLINE:
		_warn("genel zaman aşımı (%.1f sn), %d/%d adım" % [DEADLINE, _index, _plan.size()])
		_finish(1)
		return true
	while _index < _plan.size():
		if _index != _step_seen:
			_step_seen = _index
			_step_frame = 0
		_step_frame += 1
		var step: Dictionary = _plan[_index]
		var due: float = float(step.get("at", 0.0))
		if _elapsed < due:
			break
		var result: int = _try_step(step)
		if result == 1:
			_index += 1
			continue
		if result == 0:
			break
		# result == 2: zaman aşımı; uyarı yazıldı, sonraki adıma geç.
		_index += 1
	if _index >= _plan.size():
		_finish(0)
		return true
	return false


func _try_step(step: Dictionary) -> int:
	if step.has("only_if_state"):
		if String(_game_state().get("state", "")) != String(step["only_if_state"]):
			return 1
	var conditions_ok: bool = _conditions_met(step)
	var timed_out: bool = _elapsed > float(step.get("at", 0.0)) + STEP_TIMEOUT
	if step.has("shot"):
		if conditions_ok:
			_capture(String(step["shot"]))
			return 1
		if timed_out:
			_warn("adım zaman aşımı, kare atlandı: %s (%s)"
				% [String(step["shot"]), _conditions_text(step)])
			if not bool(step.get("skip_on_timeout", false)):
				_capture(String(step["shot"]) + "_timeout")
			return 2
		return 0
	if not conditions_ok:
		if timed_out:
			_warn("adım zaman aşımı, atlandı: %s (%s)" % [_step_text(step), _conditions_text(step)])
			return 2
		return 0
	if _perform(step):
		return 1
	if timed_out:
		_warn("adım gerçekleşmedi, atlandı: %s" % _step_text(step))
		return 2
	return 0


## Adımın koşulları sağlandı mı? (sahne, oyun hazır, durum, bar, kalkan, temas)
func _conditions_met(step: Dictionary) -> bool:
	if step.has("settle_frames"):
		if _step_frame < int(step["settle_frames"]):
			return false
	if step.has("wait_scene"):
		if not _scene_matches(String(step["wait_scene"])):
			return false
		if _expect_new_instance != 0:
			if current_scene != null and current_scene.get_instance_id() == _expect_new_instance:
				return false
			_expect_new_instance = 0
	if step.has("wait_game"):
		if not _game_ready():
			return false
	if step.has("wait_state"):
		if String(_game_state().get("state", "")) != String(step["wait_state"]):
			return false
	if step.has("wait_connected"):
		var state: Dictionary = _game_state()
		var total: int = int(state.get("total", 0))
		if total <= 0 or int(state.get("connected", 0)) != total:
			return false
	if step.has("wait_shorts_gt"):
		if int(_game_state().get("shorts", 0)) <= int(step["wait_shorts_gt"]):
			return false
	if step.has("wait_shield"):
		if _shield_left() < float(step["wait_shield"]):
			return false
	if step.has("wait_overload"):
		if float(_game_state().get("overload", 0.0)) < float(step["wait_overload"]):
			return false
	return true


func _perform(step: Dictionary) -> bool:
	if step.has("contact"):
		var pair: Array = step["contact"] as Array
		if pair.size() < 2:
			return false
		return _contact(int(pair[0]), int(pair[1]))
	if step.has("snap"):
		for value: Variant in step["snap"] as Array:
			if not _snap(int(value)):
				return false
		return true
	if step.has("snap_rest"):
		if not _game_ready():
			return false
		var state: Dictionary = _game_state()
		for i: int in int(state.get("total", 0)):
			_snap(i)  # zaten bağlıysa false döner; hata değil
		return true
	if step.has("force_overload"):
		return _force_overload(float(step["force_overload"]))
	if step.has("press"):
		return _press(String(step["press"]))
	if step.has("call"):
		var args: Array = step.get("args", []) as Array
		return _invoke(String(step["call"]), args, bool(step.get("new_scene", false)))
	return true


# --- ekran görüntüsü -------------------------------------------------------

func _capture(shot_name: String) -> void:
	# Pencere önde olsa da son çizilen kareyi garanti et.
	RenderingServer.force_draw(true, 0.0)
	var image: Image = root.get_texture().get_image()
	if image == null:
		_warn("ekran görüntüsü alınamadı: %s" % shot_name)
		return
	var path: String = _out_dir.path_join(shot_name + ".png")
	var error: Error = image.save_png(path)
	if error != OK:
		_warn("PNG yazılamadı (%d): %s" % [error, path])
		return
	_shots.append(shot_name)
	print("SHOT %s t=%.2f drawn=%d" % [path, _elapsed, Engine.get_frames_drawn()])


# --- aksiyonlar ------------------------------------------------------------

func _press(node_name: String) -> bool:
	if current_scene == null:
		return false
	var node: Node = current_scene.find_child(node_name, true, false)
	if node == null:
		return false
	if not (node is Button):
		_warn("düğüm buton değil: %s" % node_name)
		return true
	if SCENE_BUTTONS.has(node_name) and current_scene != null:
		_expect_new_instance = current_scene.get_instance_id()
	(node as Button).pressed.emit()
	print("PRESS %s" % node_name)
	return true


func _contact(index_a: int, index_b: int) -> bool:
	if not _game_ready():
		return false
	var state: Dictionary = _game_state()
	var total: int = int(state.get("total", 0))
	if index_a >= total or index_b >= total or index_a == index_b:
		return false
	var game: Node = current_scene
	if not game.has_method("force_contact"):
		return false
	game.call("force_contact", index_a, index_b)
	print("CONTACT %d-%d" % [index_a, index_b])
	return true


func _snap(cable_index: int) -> bool:
	if not _game_ready():
		return false
	var game: Node = current_scene
	var snapped: bool = bool(game.call("force_snap", cable_index))
	if snapped:
		print("SNAP %d" % cable_index)
	return snapped


func _force_overload(amount: float) -> bool:
	if current_scene == null:
		return false
	if current_scene.has_method("force_overload"):
		current_scene.call("force_overload", amount)
		print("OVERLOAD %.2f" % amount)
		return true
	_warn("game.force_overload API'si yok")
	return true


func _invoke(target_method: String, args: Array, new_scene: bool) -> bool:
	var parts: PackedStringArray = target_method.split(".", false, 1)
	if parts.size() != 2:
		_warn("geçersiz call adımı: %s" % target_method)
		return true
	var target: Node = root.get_node_or_null(parts[0])
	if target == null or not target.has_method(parts[1]):
		return false
	if new_scene and current_scene != null:
		_expect_new_instance = current_scene.get_instance_id()
	target.callv(StringName(parts[1]), args)
	print("CALL %s%s" % [target_method, str(args) if not args.is_empty() else ""])
	return true


## OverloadModel.shield_left (HUD kalkan göstergesi); debug_state'te yok.
func _shield_left() -> float:
	if current_scene == null:
		return 0.0
	var level: Variant = current_scene.get("_level")
	if not (level is Object):
		return 0.0
	var model: Variant = (level as Object).get("overload")
	if not (model is Object):
		return 0.0
	return float((model as Object).get("shield_left"))


# --- oyun/sahne durumu -----------------------------------------------------

func _game_ready() -> bool:
	if current_scene == null:
		return false
	if not (current_scene.has_method("debug_state") and current_scene.has_method("force_snap")):
		return false
	return int(_game_state().get("total", 0)) > 0


func _game_state() -> Dictionary:
	if current_scene == null or not current_scene.has_method("debug_state"):
		return {}
	_last_state = current_scene.call("debug_state") as Dictionary
	return _last_state


func _scene_matches(expected: String) -> bool:
	if current_scene == null:
		return false
	if String(current_scene.name) == expected:
		return true
	var path: String = current_scene.scene_file_path
	return path != "" and path.get_file().get_basename() == expected


# --- profil / dil yedeği ---------------------------------------------------

func _freeze_profile() -> void:
	var manager: Node = root.get_node_or_null("GameManager")
	if manager == null:
		return
	var profile_variant: Variant = manager.get("profile")
	if not (profile_variant is Object):
		return
	var profile: Object = profile_variant as Object
	var stars: Variant = profile.get("best_stars")
	var times: Variant = profile.get("best_times")
	_profile_backup = {
		"stars": (stars as Dictionary).duplicate(true) if stars is Dictionary else {},
		"times": (times as Dictionary).duplicate(true) if times is Dictionary else {},
	}
	profile.set("best_stars", {})
	profile.set("best_times", {})
	print("FLOW profile: geçici sıfırlandı (%d yıldız yedeklendi)"
		% int((_profile_backup["stars"] as Dictionary).size()))


func _restore_profile() -> void:
	if _profile_backup.is_empty():
		return
	var manager: Node = root.get_node_or_null("GameManager")
	if manager == null:
		return
	var profile_variant: Variant = manager.get("profile")
	if not (profile_variant is Object):
		return
	var profile: Object = profile_variant as Object
	profile.set("best_stars", (_profile_backup["stars"] as Dictionary).duplicate(true))
	profile.set("best_times", (_profile_backup["times"] as Dictionary).duplicate(true))
	profile.call("save")
	print("FLOW profile: geri yüklendi")


func _save_locale() -> void:
	var loc: Node = root.get_node_or_null("Loc")
	if loc == null:
		return
	_locale_backup = String(loc.get("locale"))
	_locale_saved = true
	print("FLOW locale: yedek '%s'" % _locale_backup)


func _restore_locale() -> void:
	if not _locale_saved or _locale_backup == "":
		return
	var loc: Node = root.get_node_or_null("Loc")
	if loc == null or not loc.has_method("set_locale"):
		return
	loc.call("set_locale", _locale_backup)
	print("FLOW locale: geri yüklendi ('%s')" % _locale_backup)


# --- yardımcılar -----------------------------------------------------------

func _conditions_text(step: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for key: String in ["wait_scene", "wait_game", "wait_state", "wait_connected",
			"wait_shorts_gt", "wait_shield", "wait_overload", "settle_frames", "only_if_state"]:
		if step.has(key):
			parts.append("%s=%s" % [key, str(step[key])])
	if parts.is_empty():
		return "koşul yok"
	return ", ".join(parts)


func _step_text(step: Dictionary) -> String:
	for key: String in ["contact", "snap", "snap_rest", "force_overload", "press", "call"]:
		if step.has(key):
			return "%s=%s" % [key, str(step[key])]
	return "adım"


func _warn(message: String) -> void:
	_warnings.append(message)
	printerr("FLOW WARN: %s" % message)


func _clear_old_pngs() -> void:
	var dir: DirAccess = DirAccess.open(_out_dir)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		if file_name.ends_with(".png"):
			dir.remove(file_name)


func _finish(code: int) -> void:
	if _done:
		return
	_done = true
	_restore_profile()
	_restore_locale()
	for warning: String in _warnings:
		print("FLOW WARN: %s" % warning)
	print("FLOW shots: %d/%d (min %d): %s"
		% [_shots.size(), _plan.size(), MIN_SHOTS, ", ".join(_shots)])
	print("FLOW last_state: %s" % JSON.stringify(_last_state))
	if code == 0 and _shots.size() < MIN_SHOTS:
		_warn("yetersiz kare: %d < %d" % [_shots.size(), MIN_SHOTS])
		code = 1
	print("FLOW %s" % ("PASS" if code == 0 else "FAIL"))
	quit(code)


## Akış planı: zamanlar alt sınırdır; koşullar sağlanana kadar adım bekler.
func _build_plan() -> Array[Dictionary]:
	var plan: Array[Dictionary] = []
	plan.append({"at": 0.35, "shot": "01_boot"})
	plan.append({"at": 0.62, "call": "Loc.set_locale", "args": ["en"]})
	plan.append({"at": 0.78, "wait_scene": "Menu", "settle_frames": 6, "shot": "02_menu_en"})
	plan.append({"at": 1.00, "wait_scene": "Menu", "press": "LevelsButton"})
	plan.append({"at": 1.20, "wait_scene": "LevelSelect"})
	plan.append({"at": 1.35, "wait_scene": "LevelSelect", "settle_frames": 6,
		"shot": "03_levelselect"})
	plan.append({"at": 1.60, "wait_scene": "LevelSelect", "press": "BackButton"})
	plan.append({"at": 1.80, "wait_scene": "Menu"})
	plan.append({"at": 1.95, "call": "Loc.set_locale", "args": ["tr"]})
	plan.append({"at": 2.12, "wait_scene": "Menu", "settle_frames": 6, "shot": "04_menu_tr"})
	plan.append({"at": 2.35, "wait_scene": "Menu", "press": "PlayButton"})
	plan.append({"at": 2.55, "wait_scene": "Game"})
	plan.append({"at": 2.75, "wait_scene": "Game", "wait_game": true, "wait_state": "playing",
		"settle_frames": 8, "shot": "05_game_tr"})
	plan.append({"at": 3.10, "call": "GameManager.goto_menu", "new_scene": true})
	plan.append({"at": 3.30, "wait_scene": "Menu"})
	plan.append({"at": 3.45, "call": "Loc.set_locale", "args": ["en"]})
	plan.append({"at": 3.62, "wait_scene": "Menu", "settle_frames": 4, "press": "PlayButton"})
	plan.append({"at": 3.82, "wait_scene": "Game"})
	plan.append({"at": 4.02, "wait_scene": "Game", "wait_game": true, "wait_state": "playing",
		"settle_frames": 8, "shot": "06_game_en"})
	# Kısa devre: kıvılcım karesi (2 kare: SparkBurst ömrü 0.45 sn).
	plan.append({"at": 4.30, "wait_scene": "Game", "wait_state": "playing", "contact": [0, 1]})
	plan.append({"at": 4.50, "wait_scene": "Game", "wait_shorts_gt": 0, "settle_frames": 3,
		"shot": "07_game_kivilcim"})
	# INSULATION_SPRAY: HUD butonu → ödüllü reklam (mock) → 10 sn kalkan.
	plan.append({"at": 4.75, "wait_scene": "Game", "wait_state": "playing", "press": "SprayButton"})
	plan.append({"at": 4.95, "wait_scene": "Game", "wait_shield": 1.0, "settle_frames": 4,
		"shot": "08_game_kalkan", "skip_on_timeout": true})
	plan.append({"at": 5.95, "wait_scene": "Game", "wait_state": "playing", "press": "SprayButton"})
	plan.append({"at": 6.15, "wait_scene": "Game", "wait_shield": 1.0, "settle_frames": 4,
		"shot": "08_game_kalkan", "skip_on_timeout": false})
	# Fail: bar doldur → fail overlay karesi; sonra HUD RetryButton ile yeni tur.
	plan.append({"at": 6.50, "wait_scene": "Game", "force_overload": 1.0})
	plan.append({"at": 6.80, "wait_scene": "Game", "wait_state": "failed", "shot": "09_fail"})
	plan.append({"at": 7.20, "press": "RetryButton"})
	plan.append({"at": 7.40, "wait_scene": "Game", "wait_game": true})
	plan.append({"at": 7.60, "wait_scene": "Game", "wait_state": "playing"})
	plan.append({"at": 7.90, "wait_scene": "Game", "wait_state": "playing", "snap_rest": true})
	plan.append({"at": 8.20, "wait_scene": "Game", "wait_connected": true})
	plan.append({"at": 8.40, "wait_scene": "Game", "wait_state": "won", "settle_frames": 6,
		"shot": "10_win", "skip_on_timeout": true})
	# Win'den ~1.4 sn sonra Result sahnesi; yıldız animasyonu otursun diye bekle.
	plan.append({"at": 9.00, "wait_scene": "Result"})
	plan.append({"at": 10.40, "wait_scene": "Result", "settle_frames": 12, "shot": "11_result"})
	return plan
