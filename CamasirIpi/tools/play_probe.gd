extends SceneTree

## Oynanış probu (headless): seviyeleri çözücünün yoluyla GERÇEK oyun sahnesinde oynar;
## her seviyede kazanma katmanının çıktığını ve olay kuyruğunun boşaldığını doğrular.
## Ayrıca bir seviyede bilerek kaybedip "+1 askı" ve "tekrar dene" yollarını dener.
## Yeni engeller: 26 çarşaf, 32 çorap, 40 boya, 47 karışık. Son aşamada güçlendiriciler
## (geri al, +1 askı, mandal sökücü) gerçek sahnede denenir.
##   godot --headless --path . -s res://tools/play_probe.gd      çıkış 0 = geçti

const LEVELS: Array[int] = [1, 2, 3, 7, 16, 25, 26, 32, 40, 47]
const BOOST_LEVEL: int = 40
const BOOST_TAPS: int = 3
const FRAMES_PER_TAP: int = 4
const SETTLE_FRAMES: int = 2
const MID_CHECK_EVERY: int = 6
## Sepet bandı parıltısı ve yeni sepetin gelişi bitsin diye beklenen süre.
const MID_SETTLE_MSEC: int = 1800
const MAX_DRAIN_FRAMES: int = 2000000

var _game: Node = null
var _queue: Array[int] = []
var _path: Array[int] = []
var _wait: int = 0
var _phase: String = "load"
var _failed: bool = false
var _drain_frames: int = 0
var _lose_taps: Array[int] = []
var _mid_deadline: int = 0


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
			# Seviye ortalarında birkaç kez dur: animasyonlar bitince görünen sepet renkleri sınanır.
			if _path.size() > 0 and _path.size() % MID_CHECK_EVERY == 0:
				_mid_deadline = 0
				_phase = "mid_check"
		"mid_check":
			if bool(_game.get("_playing")):
				return false
			if _mid_deadline == 0:
				_mid_deadline = Time.get_ticks_msec() + MID_SETTLE_MSEC
			if Time.get_ticks_msec() < _mid_deadline:
				return false
			_check_basket_colors()
			_phase = "play"
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
			_check_basket_colors()
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
			_phase = "boost_load"
		"boost_load":
			_load_level(BOOST_LEVEL)
			_path = LevelSolver.solve(_game.get("_level") as Dictionary, 200000)
			_path.resize(BOOST_TAPS)
			_phase = "boost_play"
			_wait = 2
		"boost_play":
			if _path.is_empty():
				_phase = "boost_check"
				_wait = SETTLE_FRAMES
				return false
			_game.call("_tap", _path.pop_front())
			_wait = FRAMES_PER_TAP
		"boost_check":
			_drain_frames += 1
			if _drain_frames < MAX_DRAIN_FRAMES and bool(_game.get("_playing")):
				return false
			_drain_frames = 0
			_check_boosters()
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


## Görünen sepet rengi kuraldaki renkle aynı olmalı (animasyon yarışı rengi bozmasın).
func _check_basket_colors() -> void:
	var board: LaundryBoard = _game.get("_board") as LaundryBoard
	var views: Array = _game.get("_baskets") as Array
	var palette: Array = _game.get("COLORS") as Array
	var states: Array[Dictionary] = board.baskets()
	for index: int in range(states.size()):
		if states[index].is_empty():
			continue
		var expected: Color = palette[int(states[index]["color"]) % palette.size()] as Color
		var shown: Color = (views[index] as BasketView).shown_color()
		if not shown.is_equal_approx(expected):
			_fail("sepet %d rengi yanlış: görünen %s, kural %s" % [index, shown.to_html(), expected.to_html()])


func _fail(message: String) -> void:
	_failed = true
	printerr("PROBE HATA: %s" % message)


func _check_boosters() -> void:
	# Prob kaydı sıfırdan başlar (güçlendirici yok); sınamak için bellekte birkaç tane verilir.
	var progress: Node = root.get_node_or_null("Progress")
	if progress != null:
		for id: String in [Boosters.UNDO, Boosters.EXTRA_SLOT, Boosters.PIN_REMOVER]:
			progress.call("add_booster", id, 2)
	var board: LaundryBoard = _game.get("_board") as LaundryBoard
	var moves: int = board.moves()
	var on_line: int = board.remaining_on_line()
	_game.call("_on_booster_pressed", Boosters.UNDO)
	var views: Dictionary = _game.get("_views") as Dictionary
	print("PROBE geri_al hamle=%d->%d ip=%d->%d görünüm=%d" % [moves, board.moves(), on_line,
		board.remaining_on_line(), views.size()])
	if board.moves() != moves - 1 or board.remaining_on_line() != on_line + 1:
		_fail("geri al tahtayı geri almadı")
	for id: Variant in views.keys():
		if board.is_on_line(int(id)) and not is_instance_valid(views[id] as Object):
			_fail("geri al sonrası görünüm eksik")
	_game.call("_on_booster_pressed", Boosters.EXTRA_SLOT)
	print("PROBE +1_askı askı=%d" % board.rack_slots())
	if board.rack_slots() != LaundryBoard.DEFAULT_RACK_SLOTS + 1:
		_fail("+1 askı güçlendiricisi çalışmadı")
	var targets: Array[int] = Boosters.pin_targets(board)
	if targets.is_empty():
		_fail("sökücü hedefi yok")
		return
	var target: GarmentView = views[targets[0]] as GarmentView
	var rect: Rect2 = target.hit_rect()
	var before: int = board.remaining_on_line()
	_game.call("_on_booster_pressed", Boosters.PIN_REMOVER)
	_game.call("_booster_intercepts", target.position + rect.get_center())
	print("PROBE sökücü ip=%d->%d" % [before, board.remaining_on_line()])
	if board.remaining_on_line() != before - 1:
		_fail("mandal sökücü parça almadı")
