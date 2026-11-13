extends SceneTree

## Oynanış probu (headless): seviyeleri çözücünün yoluyla GERÇEK oyun sahnesinde oynar;
## her seviyede kazanma katmanının çıktığını ve olay kuyruğunun boşaldığını doğrular.
## Ayrıca bir seviyede bilerek kaybedip "+1 askı" ve "tekrar dene" yollarını dener.
##   godot --headless --path . -s res://tools/play_probe.gd      çıkış 0 = geçti

const LEVELS: Array[int] = [1, 2, 3, 7, 16, 25]
const FRAMES_PER_TAP: int = 4
const SETTLE_FRAMES: int = 2
const MAX_DRAIN_FRAMES: int = 2000000

var _game: Node = null
var _queue: Array[int] = []
var _path: Array[int] = []
var _wait: int = 0
var _phase: String = "load"
var _failed: bool = false
var _drain_frames: int = 0
var _lose_taps: Array[int] = []


func _initialize() -> void:
	# Prob oyuncunun gerçek kaydını ASLA ezmemeli.
	var progress: Node = root.get_node("Progress")
	progress.set("persist", false)
	_queue = LEVELS.duplicate()


func _process(_delta: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	match _phase:
		"load":
			if _queue.is_empty():
				_phase = "lose_load"
				return false
			_load_level(_queue.pop_front())
			_path = LevelSolver.solve(_game.get("_level") as Dictionary, 200000)
			if _path.is_empty():
				_fail("çözüm yok")
			_phase = "play"
			_wait = 2
		"play":
			if _path.is_empty():
				_phase = "check"
				_wait = SETTLE_FRAMES
				return false
			_game.call("_tap", _path.pop_front())
			_wait = FRAMES_PER_TAP
		"check":
			# Animasyonlar gerçek zamanlıdır; kuyruk boşalana ve katman çıkana dek beklenir.
			_drain_frames += 1
			if _drain_frames < MAX_DRAIN_FRAMES and (bool(_game.get("_playing")) or _game.get("_overlay") == null):
				return false
			_drain_frames = 0
			var board: LaundryBoard = _game.get("_board") as LaundryBoard
			var number: int = int(_game.get("_level_number"))
			var overlay: Variant = _game.get("_overlay")
			print("PROBE seviye_sonu sonraki=%d kazandı=%s katman=%s kuyruk=%d" % [
				number, str(board.is_won()), str(overlay != null), (_game.get("_events") as Array).size()])
			if not board.is_won() or overlay == null or not (_game.get("_events") as Array).is_empty():
				_fail("seviye kazanılmadı ya da katman yok")
			_phase = "load"
		"lose_load":
			# Seri bonusu (+1 askı) kayıp senaryosunu bozmasın diye ilerleme sıfırlanır.
			root.get_node("Progress").call("reset_state")
			# Kesin kayıp: askı dolunca sepete gidebilecek açık parça kalmayan elle kurulmuş seviye.
			_load_level(1, _losing_level())
			_lose_taps = [0, 1, 2, 3]
			_phase = "lose_play"
			_wait = 2
		"lose_play":
			if _lose_taps.is_empty():
				_phase = "lose_check"
				_wait = SETTLE_FRAMES
				return false
			_game.call("_tap", _lose_taps.pop_front())
			_wait = FRAMES_PER_TAP
		"lose_check":
			_drain_frames += 1
			if _drain_frames < MAX_DRAIN_FRAMES and (bool(_game.get("_playing")) or _game.get("_overlay") == null):
				return false
			_drain_frames = 0
			var board: LaundryBoard = _game.get("_board") as LaundryBoard
			print("PROBE kayıp lost=%s katman=%s askı=%d" % [str(board.is_lost()),
				str(_game.get("_overlay") != null), board.rack_slots()])
			if not board.is_lost() or _game.get("_overlay") == null:
				_fail("kayıp katmanı yok")
			_game.call("_revive")
			if board.is_lost() or board.rack_slots() != 5 or _game.get("_overlay") != null:
				_fail("+1 askı çalışmadı")
			_game.set("debug_level", {})
			_game.call("_start_level")
			var fresh: LaundryBoard = _game.get("_board") as LaundryBoard
			if fresh.is_over() or fresh.rack_count() != 0:
				_fail("tekrar dene temiz başlamadı")
			print("PROBE devam_ve_tekrar tamam")
			_phase = "done"
		"done":
			print("PROBE SONUC: %s" % ("kaldi" if _failed else "gecti"))
			quit(1 if _failed else 0)
			return true
	return false


func _load_level(level: int, custom: Dictionary = {}) -> void:
	if _game != null:
		_game.queue_free()
	var packed: PackedScene = load("res://scenes/Game.tscn") as PackedScene
	_game = packed.instantiate()
	root.add_child(_game)
	current_scene = _game
	_game.set("_persist", false)
	_game.set("_level_number", level)
	_game.set("debug_level", custom)
	_game.call("_start_level")


func _losing_level() -> Dictionary:
	var colors: Array[int] = [2, 2, 3, 3, 2, 3, 0, 0, 0, 1, 1, 1]
	var blockers: Dictionary = {6: [4], 7: [4], 8: [4], 9: [5], 10: [5], 11: [5]}
	var items: Array[Dictionary] = []
	for index: int in range(colors.size()):
		items.append({"id": index, "color": colors[index], "blockers": blockers.get(index, []),
			"line": index / 6, "layer": 0 if index < 6 else 1, "slot": float(index % 6) * 0.6, "kind": index % 6})
	return {"level": 1, "items": items, "queue": [0, 1, 2, 3], "active_baskets": 2, "rack_slots": 4, "hard": false}


func _fail(message: String) -> void:
	_failed = true
	printerr("PROBE HATA: %s" % message)
