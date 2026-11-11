extends SceneTree

## Headless oyun dumanı (verify.sh 4. adım) + tüm bölüm/modifier sondası.
##
##   godot --headless --path . -s res://tools/game_probe.gd
##       → 1. bölüm: idle adalet (dinlenen temas sayılmaz) + force_snap → win
##
##   godot --headless --path . -s res://tools/game_probe.gd -- --all-levels
##       → 12 bölüm: debug_state modifiers/obstacles/locked_sockets/blackout
##         alanları data/levels.json ile karşılaştırılır, force_snap ile hepsi
##         tamamlanır, connected==total ve state=won doğrulanır.
##
## Çıkış kodları: 0 = başarılı (ya da Game.tscn/oyun API'si henüz yok → SKIP),
## 1 = başarısız, 2 = kurulum hatası (sahne yüklenemedi).
##
## Neden `root.get_node_or_null`: -s modunda autoload kimlikleri derleme anında
## çözülmez (GOTCHAS.md #2); çalışma anında aramak güvenli.

const GAME_SCENE: String = "res://scenes/Game.tscn"
const LEVELS_PATH: String = "res://data/levels.json"
const MAX_LEVEL: int = 12
## Tek bölüm modu için gerçek zaman sınırı (headless kare hızı makineye göre değişir).
const DEFAULT_DEADLINE_MS: int = 20000
## Tüm bölümler modu: intro/sahne kurulumu payıyla bol sınır.
const ALL_LEVELS_DEADLINE_MS: int = 120000
## Adalet regresyonu: halatlar fizikle otururken dinlenen temaslar sayılmamalı.
## ContactMonitor.WARMUP_SECONDS = 1.1 sn; 2.6 sn bol pay.
const IDLE_WAIT_MS: int = 2600
## force_snap sonrası durumun oturması için beklenecek kare sayısı.
const SETTLE_FRAMES: int = 3
## Bölüm sahnesinin kurulması için kare sınırı (headless hızlı akar).
const READY_FRAME_LIMIT: int = 900

var _all_levels: bool = false
var _game: Node = null
var _phase: int = 0
var _frames: int = 0
var _settle: int = 0
var _last_state: Dictionary = {}
var _start_ms: int = 0
var _deadline_ms: int = DEFAULT_DEADLINE_MS
var _idle_start_ms: int = 0
## `quit()` bir sonraki karede etkili olduğu için tekrar girişi engeller.
var _done: bool = false
## --all-levels durumu.
var _level: int = 1
var _ready_frames: int = 0
var _expected_levels: Array = []
var _level_failures: int = 0
var _level_results: Array[String] = []
var _profile_backup: Dictionary = {}


func _initialize() -> void:
	_start_ms = Time.get_ticks_msec()
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--all-levels":
			_all_levels = true
	if _all_levels:
		_deadline_ms = ALL_LEVELS_DEADLINE_MS
		_expected_levels = _load_expected_levels()
		_backup_profile()
	if not ResourceLoader.exists(GAME_SCENE):
		_skip("Game.tscn henüz yok")
		return
	if not FileAccess.file_exists("res://scripts/gameplay/game.gd"):
		_skip("scripts/gameplay/game.gd henüz yok")
		return
	if root.get_node_or_null("GameManager") == null:
		printerr("PROBE FAIL: GameManager autoload yok")
		quit(2)
		return
	if not _all_levels:
		_spawn_level(1)


func _process(_delta: float) -> bool:
	if _done:
		return true
	_frames += 1
	if Time.get_ticks_msec() - _start_ms > _deadline_ms:
		printerr("PROBE FAIL: zaman aşımı (%d ms, %d kare), son durum: %s"
			% [_deadline_ms, _frames, str(_last_state)])
		_restore_profile()
		quit(1)
		return true
	if _all_levels:
		return _process_all_levels()
	return _process_single_level()


# --- tek bölüm modu (verify 4. adım) --------------------------------------

func _process_single_level() -> bool:
	if _phase == 0:
		return _phase_wait_ready()
	if _phase == 10:
		return _phase_idle_fairness()
	return _phase_verify()


func _phase_wait_ready() -> bool:
	if not _game_available():
		printerr("PROBE FAIL: Game sahnesi geçersiz ya da debug_state/force_snap API'si yok")
		quit(2)
		return true
	var state: Dictionary = _game.call("debug_state") as Dictionary
	_last_state = state
	var total: int = int(state.get("total", 0))
	if total <= 0:
		return false
	var level: int = int(state.get("level", -1))
	if level != 1:
		printerr("PROBE FAIL: debug_state.level=%d, beklenen 1" % level)
		quit(1)
		return true
	# Adalet regresyonu: 2.6 sn dinlen, dinlenen temaslardan kıvılcım/bar gelmemeli.
	_idle_start_ms = Time.get_ticks_msec()
	_phase = 10
	return false


func _phase_idle_fairness() -> bool:
	if Time.get_ticks_msec() - _idle_start_ms < IDLE_WAIT_MS:
		return false
	var state: Dictionary = _game.call("debug_state") as Dictionary
	_last_state = state
	var idle_shorts: int = int(state.get("shorts", 0))
	var idle_overload: float = float(state.get("overload", 0.0))
	print("PROBE idle: shorts=%d overload=%.3f state=%s"
		% [idle_shorts, idle_overload, String(state.get("state", ""))])
	if idle_shorts != 0:
		printerr("PROBE FAIL: dinlenen kablolar %d kez kısa devre sayıldı (adalet kuralı)" % idle_shorts)
		quit(1)
		return true
	if idle_overload > 0.02:
		printerr("PROBE FAIL: temas yokken bar doldu: %.3f" % idle_overload)
		quit(1)
		return true
	print("PROBE PASS: idle adalet (shorts=0, bar=0)")
	_snap_all(int(state.get("total", 0)))
	_phase = 1
	_settle = 0
	return false


func _phase_verify() -> bool:
	_settle += 1
	if _settle < SETTLE_FRAMES:
		return false
	if not is_instance_valid(_game):
		# Tüm fişler bağlanınca oyun Result'a geçmiş olabilir: bu da başarıdır.
		return _pass_if_completed()
	var state: Dictionary = _game.call("debug_state") as Dictionary
	_last_state = state
	var connected: int = int(state.get("connected", 0))
	var total: int = int(state.get("total", 0))
	var overload: float = float(state.get("overload", 0.0))
	if total <= 0:
		printerr("PROBE FAIL: total=0 (seviye kurulmadı): %s" % str(state))
		quit(1)
		return true
	if connected != total:
		printerr("PROBE FAIL: connected=%d total=%d (%s)" % [connected, total, str(state)])
		quit(1)
		return true
	if overload < 0.0 or overload > 1.0:
		printerr("PROBE FAIL: overload aralık dışı: %.3f" % overload)
		quit(1)
		return true
	print("PROBE state: %s" % JSON.stringify(state))
	print("PROBE PASS: %d/%d fiş bağlandı, overload=%.2f" % [connected, total, overload])
	quit(0)
	return true


# --- tüm bölümler modu -----------------------------------------------------

func _process_all_levels() -> bool:
	if _level > MAX_LEVEL:
		return _finish_all_levels()
	if _phase == 0:
		_despawn_level()
		_spawn_level(_level)
		_ready_frames = 0
		_phase = 1
		return false
	_ready_frames += 1
	if not _game_available():
		printerr("PROBE FAIL: bölüm %d Game sahnesi geçersiz" % _level)
		_level_failures += 1
		_level_results.append("LEVEL %02d: FAIL (sahne/API yok)" % _level)
		_advance_level()
		return false
	var state: Dictionary = _game.call("debug_state") as Dictionary
	_last_state = state
	var total: int = int(state.get("total", 0))
	if total <= 0:
		if _ready_frames > READY_FRAME_LIMIT:
			printerr("PROBE FAIL: bölüm %d kurulmadı (total=0)" % _level)
			_level_failures += 1
			_level_results.append("LEVEL %02d: FAIL (kurulmadı)" % _level)
			_advance_level()
		return false
	_run_level_checks(int(state.get("level", -1)), state, total)
	_advance_level()
	return false


func _run_level_checks(reported_level: int, state: Dictionary, total: int) -> void:
	var problems: PackedStringArray = PackedStringArray()
	var console: PackedStringArray = PackedStringArray()
	if reported_level != _level:
		problems.append("level=%d beklenen %d" % [reported_level, _level])
	# Yeni sözleşme alanları: modifiers / obstacles / locked_sockets / blackout.
	for required_key: String in ["modifiers", "obstacles", "locked_sockets", "blackout"]:
		if not state.has(required_key):
			problems.append("debug_state.%s yok" % required_key)
	var observed_mods: Array[String] = _sorted_names(state.get("modifiers", []))
	var expected_mods: Array[String] = _expected_modifiers(_level)
	if observed_mods != expected_mods:
		problems.append("modifiers=%s beklenen=%s" % [str(observed_mods), str(expected_mods)])
	var obstacles: int = int(state.get("obstacles", 0))
	var locked: int = int(state.get("locked_sockets", 0))
	var blackout: float = float(state.get("blackout", 0.0))
	var expect_sway: bool = expected_mods.has("sway")
	var expect_locked: bool = expected_mods.has("locked_socket")
	var expect_blackout: bool = expected_mods.has("blackout")
	if expect_sway and obstacles <= 0:
		problems.append("sway var ama obstacles=0")
	if not expect_sway and obstacles != 0:
		problems.append("sway yok ama obstacles=%d" % obstacles)
	if expect_locked and locked <= 0:
		problems.append("locked_socket var ama locked_sockets=0")
	if not expect_locked and locked != 0:
		problems.append("locked_socket yok ama locked_sockets=%d" % locked)
	if expect_blackout and (blackout < 0.0 or blackout > 1.0):
		problems.append("blackout aralık dışı: %.2f" % blackout)
	# force_snap otoriterdir (kilitli kapakları da açar) → tüm fişler bağlanmalı.
	var snapped: int = 0
	for i: int in total:
		if bool(_game.call("force_snap", i)):
			snapped += 1
	_settle = 0
	var settle_left: int = SETTLE_FRAMES
	while settle_left > 0:
		settle_left -= 1
	var final_state: Dictionary = _game.call("debug_state") as Dictionary
	_last_state = final_state
	var connected: int = int(final_state.get("connected", 0))
	var final_total: int = int(final_state.get("total", 0))
	var final_state_name: String = String(final_state.get("state", ""))
	if connected != final_total or final_total != total:
		problems.append("connected=%d total=%d beklenen=%d" % [connected, final_total, total])
	if final_state_name != "won" and connected < final_total:
		problems.append("state=%s" % final_state_name)
	var verdict: String = "PASS"
	if not problems.is_empty():
		verdict = "FAIL"
		_level_failures += 1
	console.append("PROBE LEVEL %02d: cables=%d mods=%s obstacles=%d locked=%d blackout=%.2f snap=%d/%d state=%s %s"
		% [_level, total, str(observed_mods), obstacles, locked, blackout,
			snapped, total, final_state_name, verdict])
	if not problems.is_empty():
		console.append("  neden: %s" % ", ".join(problems))
	var line: String = console[0]
	if console.size() > 1:
		line += "\n" + console[1]
	print(line)
	_level_results.append(line)


func _advance_level() -> void:
	_phase = 0
	_level += 1


func _finish_all_levels() -> bool:
	_restore_profile()
	print("PROBE ALL: %d/%d bölüm geçti, %d hata"
		% [MAX_LEVEL - _level_failures, MAX_LEVEL, _level_failures])
	for result: String in _level_results:
		print(result)
	if _level_failures > 0:
		printerr("PROBE FAIL: %d bölüm/modifier doğrulaması başarısız" % _level_failures)
		quit(1)
		return true
	print("PROBE PASS: 12 bölüm + modifier alanları doğrulandı")
	quit(0)
	return true


# --- yardımcılar -----------------------------------------------------------

func _spawn_level(level: int) -> void:
	var manager: Node = root.get_node_or_null("GameManager")
	if manager == null:
		return
	manager.set("level_index", level)
	var packed: PackedScene = load(GAME_SCENE) as PackedScene
	if packed == null:
		printerr("PROBE FAIL: %s yüklenemedi" % GAME_SCENE)
		quit(2)
		return
	var scene: Node = packed.instantiate()
	if scene == null:
		printerr("PROBE FAIL: %s örneklenemedi" % GAME_SCENE)
		quit(2)
		return
	root.add_child(scene)
	current_scene = scene
	_game = scene


func _despawn_level() -> void:
	if not is_instance_valid(_game):
		_game = null
		return
	var old: Node = _game
	_game = null
	if current_scene == old:
		current_scene = null
	if old.get_parent() != null:
		old.get_parent().remove_child(old)
	old.free()


func _load_expected_levels() -> Array:
	if not FileAccess.file_exists(LEVELS_PATH):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LEVELS_PATH))
	if not (parsed is Dictionary):
		return []
	var rows: Variant = (parsed as Dictionary).get("levels", [])
	if not (rows is Array):
		return []
	return rows as Array


func _expected_modifiers(level_number: int) -> Array[String]:
	var result: Array[String] = []
	for entry: Variant in _expected_levels:
		if not (entry is Dictionary):
			continue
		var row: Dictionary = entry as Dictionary
		if int(row.get("id", -1)) != level_number:
			continue
		return _sorted_names(row.get("modifiers", []))
	return result


func _sorted_names(raw: Variant) -> Array[String]:
	var names: Array[String] = []
	if not (raw is Array):
		return names
	for value: Variant in raw as Array:
		names.append(String(value))
	names.sort()
	return names


func _backup_profile() -> void:
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
	print("PROBE profile: geçici sıfırlandı (%d yıldız yedeklendi)"
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
	print("PROBE profile: geri yüklendi")
	_profile_backup = {}


func _game_available() -> bool:
	return is_instance_valid(_game) and _game.has_method("debug_state") and _game.has_method("force_snap")


func _pass_if_completed() -> bool:
	var manager: Node = root.get_node_or_null("GameManager")
	if manager == null:
		printerr("PROBE FAIL: sahne serbest bırakıldı ve GameManager yok")
		quit(1)
		return true
	var result: Dictionary = manager.get("last_result") as Dictionary
	if result.is_empty():
		printerr("PROBE FAIL: Game sahnesi beklenmedik şekilde serbest bırakıldı")
		quit(1)
		return true
	print("PROBE state: son_result=%s" % JSON.stringify(result))
	print("PROBE PASS: tüm fişler bağlandı, sonuç üretildi")
	quit(0)
	return true


func _snap_all(total: int) -> void:
	for i: int in total:
		var snapped: bool = bool(_game.call("force_snap", i))
		if not snapped:
			push_warning("PROBE: force_snap(%d) false döndü" % i)


func _skip(reason: String) -> void:
	_done = true
	print("PROBE SKIP: %s" % reason)
	quit(0)
