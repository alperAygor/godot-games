extends SceneTree

## Headless hızlı oyun dumanı: Game.tscn'i doğrudan kurar, force_snap ile tüm
## fişleri bağlar ve `debug_state()` sözleşmesini doğrular. flow_shot'tan (gerçek
## pencere) önce hızlı regresyon sağlar; verify.sh'ın 4. adımıdır.
##
##   godot --headless --path . -s res://tools/game_probe.gd
##
## Çıkış kodları: 0 = başarılı (ya da Game.tscn/oyun API'si henüz yok → SKIP),
## 1 = başarısız, 2 = kurulum hatası (sahne yüklenemedi).
##
## Neden `root.get_node_or_null`: -s modunda autoload kimlikleri derleme anında
## çözülmez (GOTCHAS.md #2); çalışma anında aramak güvenli.

const GAME_SCENE: String = "res://scenes/Game.tscn"
## Tüm probe için gerçek zaman sınırı (headless kare hızı makineye göre değişir).
const DEADLINE_MS: int = 20000
## Adalet regresyonu: halatlar fizikle otururken dinlenen temaslar sayılmamalı.
## ContactMonitor.WARMUP_SECONDS = 1.1 sn; 2.6 sn bol pay.
const IDLE_WAIT_MS: int = 2600
## force_snap sonrası durumun oturması için beklenecek kare sayısı.
const SETTLE_FRAMES: int = 3

var _game: Node = null
var _frames: int = 0
var _phase: int = 0
var _settle: int = 0
var _last_state: Dictionary = {}
var _start_ms: int = 0
var _idle_start_ms: int = 0
## `quit()` bir sonraki karede etkili olduğu için tekrar girişi engeller.
var _done: bool = false


func _initialize() -> void:
	_start_ms = Time.get_ticks_msec()
	if not ResourceLoader.exists(GAME_SCENE):
		_skip("Game.tscn henüz yok")
		return
	if not FileAccess.file_exists("res://scripts/gameplay/game.gd"):
		_skip("scripts/gameplay/game.gd henüz yok")
		return
	var manager: Node = root.get_node_or_null("GameManager")
	if manager == null:
		printerr("PROBE FAIL: GameManager autoload yok")
		quit(2)
		return
	manager.set("level_index", 1)
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


func _process(_delta: float) -> bool:
	if _done:
		return true
	_frames += 1
	if Time.get_ticks_msec() - _start_ms > DEADLINE_MS:
		printerr("PROBE FAIL: zaman aşımı (%d ms, %d kare), son durum: %s"
			% [DEADLINE_MS, _frames, str(_last_state)])
		quit(1)
		return true
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
