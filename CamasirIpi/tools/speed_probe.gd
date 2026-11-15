extends SceneTree

## Hızlı oyun stres probu (headless, gerçek zamanlı). Üç bölüm:
##  1) Ölçüm: tek dokunuş, 10 dokunuşluk patlama (100 ms ve aynı kare), sakin tempo (1500 ms):
##     dokunuştan ilk görsel tepkiye kare/ms ve son dokunuştan tamamen durulmuş ekrana ms;
##     seviye sonu (son dokunuştan sonuç sayfasına) ve "Devam"dan oynanabilir ilk kareye.
##  2) Stres: her mekaniğin açıldığı seviyeler çözücü yoluyla OLABİLDİĞİNCE HIZLI oynanır (kare başına
##     birkaç dokunuş, rastgele küçük aralıklar), araya engelli dokunuşlar, geri al yağmuru, +1 askı,
##     mandal sökücü (sonrası rastgele yasal hamleler) ve seviye sonu atlatma dokunuşu girer.
##     Ara ara ve sonda ekran durulunca GÖRÜNÜM == TAHTA denetlenir (her çamaşırın ip/askı/sepet/makine
##     yeri ve görünürlüğü, sepetlerin rengi/doluluğu/kapasitesi, askı, HUD sayaçları), süren kayıtlı
##     Tween kalmamalı, sahipsiz düğüm sayısı büyümemeli. Sonuç, aynı işlemlerin saf tahtada (görünümsüz)
##     tekrarıyla karşılaştırılır; üç seviye ayrıca gerçek sahnede YAVAŞ (her dokunuşta durularak) oynanıp
##     karşılaştırılır.
##  3) Geçiş sızıntısı: 30 "Devam" geçişinde düğüm/nesne sayısı.
##   godot --headless --path . -s res://tools/speed_probe.gd            -> PROBE SONUC: gecti
##   godot --headless --path . -s res://tools/speed_probe.gd -- --bench  (yalnız ölçüm)
##   godot --headless --path . -s res://tools/speed_probe.gd -- --quick  (verify.sh: ölçümsüz, 6 seviye stres)
## Oyuncunun kaydına ASLA yazmaz (Progress.persist = false, ilk iş).

const GAME_SCENE: String = "res://scenes/Game.tscn"
const BENCH_LEVEL: int = 12
const BURST_TAPS: int = 10
const SOLVE_LIMIT: int = 200000
const MAX_SETTLE_MSEC: int = 20000
## Her mekaniğin açılış aralığı (play_probe ile aynı liste + birkaç ek).
const STRESS_LEVELS: Array[int] = [2, 7, 9, 16, 18, 21, 22, 23, 25, 26, 29, 30, 31, 32, 33, 36, 40, 44, 47, 52,
	58, 61, 64, 66, 70, 76, 82, 88, 91, 94, 100, 108, 124]
## Mandal sökücü + ardından rastgele yasal oyun (kayıp yolunu da dener).
const PIN_LEVELS: Array[int] = [40, 58, 100]
## Gerçek sahnede yavaş (durularak) tekrar.
const SLOW_LEVELS: Array[int] = [9, 23]
## Hızlı kip (verify.sh): her mekanik ailesinden bir seviye, yavaş tekrar/sızıntı yok.
const QUICK_LEVELS: Array[int] = [7, 23, 30, 40, 64, 88]
const UNDO_CHANCE: float = 0.1
const BLOCKED_CHANCE: float = 0.12
const EXTRA_CHANCE: float = 0.03
const MID_AUDIT_EVERY: int = 9
const POS_TOLERANCE: float = 2.0
const TWEEN_WAIT_MSEC: int = 4000
const TRANSITIONS: int = 30
const TRANSITION_FROM: int = 40
const SEED: int = 7741

var _game: Node = null
var _progress: Node = null
var _phase: String = "bench_start"
var _bench_only: bool = false
var _quick: bool = false
var _failed: bool = false
var _frame: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

# --- ölçüm ---
var _scenarios: Array[Array] = [["tek dokunuş", 1, 0], ["10 dokunuş / 100 ms", BURST_TAPS, 100],
	["10 dokunuş / aynı kare", BURST_TAPS, 0], ["10 dokunuş / 1500 ms (sakin)", BURST_TAPS, 1500]]
var _path: Array[int] = []
var _taps_left: int = 0
var _gap: int = 0
var _label: String = ""
var _next_tap_msec: int = 0
var _last_tap_msec: int = 0
var _watch: Array[Dictionary] = []
var _tr_levels: Array[int] = [2, 3, 9, 65]
var _tr_level: int = 0
var _tr_wait: int = 0
var _tr_board: Object = null
var _tr_press_usec: int = 0
var _tr_last_usec: int = 0
var _tr_frames: PackedFloat32Array = PackedFloat32Array()
var _tr_sync_ms: float = 0.0
var _tr_ready_ms: float = -1.0

# --- stres ---
var _queue: Array[int] = []
var _level: int = 0
var _ops: Array[Array] = []
var _applied: Array[Array] = []
var _actions: int = 0
var _random_mode: bool = false
var _pinned: bool = false
var _extra_done: bool = false
var _wait_frames: int = 0
var _settle_deadline: int = 0
var _resume: String = ""
var _audits: int = 0
var _fallback_taps: int = 0
var _input_taps: int = 0
var _skip_sent_msec: int = 0
var _orphans_start: int = -1
var _orphans_max: int = 0
var _slow_queue: Array[int] = []
var _slow_ops: Array[Array] = []
var _slow_expect: Dictionary = {}
var _recorded_ops: Dictionary = {}
var _recorded_results: Dictionary = {}
var _tr_count: int = 0
var _tr_nodes: Array[int] = []
var _tr_objects: Array[int] = []
var _mechanics_seen: Dictionary = {}


func _initialize() -> void:
	_progress = root.get_node("Progress")
	_progress.set("persist", false)
	Engine.max_fps = 60
	_rng.seed = SEED
	_bench_only = OS.get_cmdline_user_args().has("--bench")
	_queue = STRESS_LEVELS.duplicate()
	_slow_queue = SLOW_LEVELS.duplicate()
	if OS.get_cmdline_user_args().has("--quick"):
		_quick = true
		_queue = QUICK_LEVELS.duplicate()
		_slow_queue.clear()
		_phase = "stress_load"


func _process(_delta: float) -> bool:
	_frame += 1
	if _wait_frames > 0:
		_wait_frames -= 1
		return false
	match _phase:
		"bench_start", "bench_warm", "bench_taps", "bench_settle":
			_bench_step()
		"tr_start", "tr_play", "tr_wait":
			_transition_bench_step()
		"stress_load":
			_stress_load()
		"stress_play":
			_stress_play()
		"settle":
			_settle_step()
		"end_wait":
			_end_wait_step()
		"slow_load":
			_slow_load()
		"slow_play":
			_slow_play()
		"leak":
			_leak_step()
		"done":
			print("PROBE stres: %d seviye, %d denetim, girdi yoluyla %d dokunuş (doğrudan %d), sahipsiz düğüm artışı en çok %d" % [
				STRESS_LEVELS.size() if not _quick else QUICK_LEVELS.size(), _audits, _input_taps, _fallback_taps, _orphans_max])
			print("PROBE mekanikler: %s" % ", ".join(PackedStringArray(_mechanics_seen.keys())))
			print("PROBE SONUC: %s" % ("kaldi" if _failed else "gecti"))
			quit(1 if _failed else 0)
			return true
	return false


# ================================================================ ölçüm

func _bench_step() -> void:
	match _phase:
		"bench_start":
			if _scenarios.is_empty():
				_phase = "tr_start"
				return
			var scenario: Array = _scenarios.pop_front()
			_label = String(scenario[0])
			_taps_left = int(scenario[1])
			_gap = int(scenario[2])
			_load(BENCH_LEVEL)
			_path = LevelSolver.solve(_game.get("_level") as Dictionary, SOLVE_LIMIT)
			_watch.clear()
			_phase = "bench_warm"
			_next_tap_msec = Time.get_ticks_msec() + 600
		"bench_warm":
			if Time.get_ticks_msec() >= _next_tap_msec:
				_phase = "bench_taps"
		"bench_taps":
			_track()
			while _taps_left > 0 and Time.get_ticks_msec() >= _next_tap_msec:
				var id: int = _path.pop_front()
				var view: Node2D = (_game.get("_views") as Dictionary)[id] as Node2D
				_watch.append({"view": view, "pos": view.global_position, "scale": view.scale,
					"rot": view.rotation, "frame": _frame, "msec": Time.get_ticks_msec(), "moved": -1, "moved_msec": -1})
				_game.call("_tap", id)
				_last_tap_msec = Time.get_ticks_msec()
				_taps_left -= 1
				_next_tap_msec = Time.get_ticks_msec() + _gap
				if _gap > 0:
					break
			if _taps_left == 0:
				_phase = "bench_settle"
		"bench_settle":
			_track()
			if _screen_still() or Time.get_ticks_msec() - _last_tap_msec > MAX_SETTLE_MSEC:
				var worst_frames: int = 0
				var worst_ms: int = 0
				for entry: Dictionary in _watch:
					worst_frames = maxi(worst_frames, int(entry["moved"]) - int(entry["frame"]))
					worst_ms = maxi(worst_ms, int(entry["moved_msec"]) - int(entry["msec"]))
				print("BENCH %s: son dokunuştan durulmaya %d ms; geri bildirim en kötü %d kare / %d ms" % [
					_label, Time.get_ticks_msec() - _last_tap_msec, worst_frames, worst_ms])
				_phase = "bench_start"


func _track() -> void:
	for entry: Dictionary in _watch:
		if int(entry["moved"]) >= 0:
			continue
		var view: Node2D = entry["view"] as Node2D
		if not is_instance_valid(view) or view.global_position.distance_to(entry["pos"] as Vector2) > 0.5 \
				or view.scale.distance_to(entry["scale"] as Vector2) > 0.001 or absf(view.rotation - float(entry["rot"])) > 0.001:
			entry["moved"] = _frame
			entry["moved_msec"] = Time.get_ticks_msec()


func _transition_bench_step() -> void:
	match _phase:
		"tr_start":
			if _tr_levels.is_empty():
				_phase = "done" if _bench_only else "stress_load"
				return
			_tr_level = _tr_levels.pop_front()
			_load(_tr_level)
			_path = LevelSolver.solve(_game.get("_level") as Dictionary, SOLVE_LIMIT)
			_tr_wait = 0
			_phase = "tr_play"
		"tr_play":
			if not _path.is_empty():
				_game.call("_tap", _path.pop_front())
				_last_tap_msec = Time.get_ticks_msec()
				return
			var sheet: Variant = _game.get("_overlay")
			if sheet == null:
				return
			if _tr_wait == 0:
				print("BENCH seviye sonu %d: son dokunuştan sonuç sayfasına %d ms" % [_tr_level,
					Time.get_ticks_msec() - _last_tap_msec])
			_tr_wait += 1
			if _tr_wait < 90:
				return
			_tr_board = _game.get("_board") as Object
			_tr_press_usec = Time.get_ticks_usec()
			_tr_frames = PackedFloat32Array()
			_tr_last_usec = _tr_press_usec
			(sheet as Object).emit_signal("continue_pressed")
			_tr_sync_ms = float(Time.get_ticks_usec() - _tr_press_usec) / 1000.0
			_tr_ready_ms = -1.0
			_phase = "tr_wait"
		"tr_wait":
			var now: int = Time.get_ticks_usec()
			_tr_frames.append(float(now - _tr_last_usec) / 1000.0)
			_tr_last_usec = now
			if _tr_ready_ms < 0.0 and _interactive() and _game.get("_board") != _tr_board:
				_tr_ready_ms = float(now - _tr_press_usec) / 1000.0
			if now - _tr_press_usec > 1000000 + int(maxf(_tr_ready_ms, 0.0) * 1000.0):
				var worst: float = 0.0
				for ms: float in _tr_frames:
					worst = maxf(worst, ms)
				print("BENCH geçiş %d->%d: eşzamanlı %.1f ms, oynanabilir %.1f ms, sonraki 1 sn en kötü kare %.1f ms" % [
					_tr_level, _tr_level + 1, _tr_sync_ms, _tr_ready_ms, worst])
				_phase = "tr_start"


func _interactive() -> bool:
	var tutorial: Object = _game.get("_tutorial") as Object
	var board: LaundryBoard = _game.get("_board") as LaundryBoard
	return board != null and not board.is_over() and _game.get("_overlay") == null \
		and not bool(tutorial.get("input_blocked"))


## Ekran tamamen durdu mu: kuyruk/uçuş/sepet kanalı yok, kayıtlı Tween'lerin hiçbiri sürmüyor.
func _screen_still() -> bool:
	return not bool(_game.get("_playing")) and Motion.running_tracked() == 0


# ================================================================ stres

func _stress_load() -> void:
	if _queue.is_empty():
		_phase = "done" if _quick else "slow_load"
		return
	_progress.call("reset_state")
	for id: String in Boosters.IDS:
		_progress.call("add_booster", id, 40)
	_level = _queue.pop_front()
	_load(_level)
	_path = LevelSolver.solve(_game.get("_level") as Dictionary, SOLVE_LIMIT)
	if _path.is_empty():
		_fail("L%d çözüm yok" % _level)
	_note_mechanics(_game.get("_level") as Dictionary)
	_ops.clear()
	_applied.clear()
	_actions = 0
	_random_mode = false
	_pinned = false
	_extra_done = false
	_skip_sent_msec = 0
	if _orphans_start < 0:
		_orphans_start = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	_phase = "stress_play"
	_wait_frames = 2


func _stress_play() -> void:
	var board: LaundryBoard = _game.get("_board") as LaundryBoard
	if board.is_over():
		_begin_end()
		return
	# Kare başına 0-3 işlem; bazen 1-4 karelik küçük aralık.
	var count: int = _rng.randi_range(1, 3)
	for _index: int in range(count):
		if board.is_over():
			break
		if not _stress_action(board):
			_begin_end()
			return
	if _rng.randf() < 0.3:
		_wait_frames = _rng.randi_range(1, 4)
	if _actions > 0 and _actions % MID_AUDIT_EVERY == 0 and not board.is_over():
		_actions += 1
		_begin_settle("stress_play")


## Bir işlem uygular; yapacak işlem kalmadıysa false.
func _stress_action(board: LaundryBoard) -> bool:
	_actions += 1
	var roll: float = _rng.randf()
	if roll < BLOCKED_CHANCE:
		var blocked: int = _random_blocked(board)
		if blocked != LaundryBoard.EMPTY:
			_do_tap(blocked)
			return true
	if _level >= Boosters.unlock_level(Boosters.UNDO) and roll < BLOCKED_CHANCE + UNDO_CHANCE and board.can_undo():
		_do_undo(board)
		return true
	if not _extra_done and _level >= Boosters.unlock_level(Boosters.EXTRA_SLOT) and _rng.randf() < EXTRA_CHANCE:
		_extra_done = true
		var slots: int = board.rack_slots()
		_game.call("_on_booster_pressed", Boosters.EXTRA_SLOT)
		if board.rack_slots() > slots:
			_ops.append(["extra"])
	if PIN_LEVELS.has(_level) and not _pinned and _path.size() * 2 < _applied.size():
		_pinned = true
		if _do_pin(board):
			_random_mode = true
			return true
	if _random_mode:
		var pick: int = _random_legal(board)
		if pick == LaundryBoard.EMPTY:
			return false
		_do_tap(pick)
		return true
	if _path.is_empty():
		return false
	_do_tap(_path.pop_front())
	return true


func _do_tap(id: int) -> void:
	var board: LaundryBoard = _game.get("_board") as LaundryBoard
	var before: int = board.history_size()
	var views: Dictionary = _game.get("_views") as Dictionary
	var sent: bool = false
	if id >= 0 and views.has(id) and is_instance_valid(views[id]):
		var view: GarmentView = views[id] as GarmentView
		var point: Vector2 = view.line_home + view.hit_rect().get_center()
		if int(_game.call("_pick", point)) == id:
			var click: InputEventMouseButton = InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			click.position = (_game as Node2D).get_canvas_transform() * point
			_game.call("_unhandled_input", click)
			_input_taps += 1
			sent = true
	if not sent:
		_game.call("_tap", id)
		_fallback_taps += 1
	_ops.append(["tap", id])
	_applied.append([id, board.history_size() > before])


func _do_undo(board: LaundryBoard) -> void:
	var before: int = board.history_size()
	_game.call("_on_booster_pressed", Boosters.UNDO)
	if board.history_size() >= before:
		return
	_ops.append(["undo"])
	# Geri al son KAYITLI hamleden bu yana her şeyi (ücretsiz eylemler dahil) geri sarar: yeniden yapılır.
	var redo: Array[int] = []
	while not _applied.is_empty():
		var entry: Array = _applied.pop_back()
		redo.push_front(int(entry[0]))
		if bool(entry[1]):
			break
	if not _random_mode:
		for at: int in range(redo.size() - 1, -1, -1):
			_path.push_front(redo[at])


func _do_pin(board: LaundryBoard) -> bool:
	var targets: Array[int] = Boosters.pin_targets(board)
	var views: Dictionary = _game.get("_views") as Dictionary
	for target: int in targets:
		if not views.has(target) or not is_instance_valid(views[target]):
			continue
		var view: GarmentView = views[target] as GarmentView
		var point: Vector2 = view.line_home + view.hit_rect().get_center()
		if int(_game.call("_pick_pin_target", point)) != target:
			continue
		var before: int = board.history_size()
		_game.call("_on_booster_pressed", Boosters.PIN_REMOVER)
		_game.call("_booster_intercepts", point)
		if board.history_size() > before:
			_ops.append(["pin", target])
			_applied.append([target, true])
			return true
		return false
	return false


func _random_blocked(board: LaundryBoard) -> int:
	var options: Array[int] = []
	for id: int in board.item_ids():
		if board.is_on_line(id) and not board.is_hidden(id) and not board.is_open(id):
			options.append(id)
	return LaundryBoard.EMPTY if options.is_empty() else options[_rng.randi_range(0, options.size() - 1)]


## Rastgele yasal hamle: önce sepete gidebilen açık parça, yoksa herhangi bir açık parça.
func _random_legal(board: LaundryBoard) -> int:
	var open: Array[int] = board.open_ids()
	if open.is_empty():
		return LaundryBoard.EMPTY
	var to_basket: Array[int] = []
	for id: int in open:
		if board.accepts_item(id) and not board.is_locked(id):
			to_basket.append(id)
	var pool: Array[int] = to_basket if not to_basket.is_empty() and _rng.randf() < 0.8 else open
	return pool[_rng.randi_range(0, pool.size() - 1)]


func _begin_end() -> void:
	var board: LaundryBoard = _game.get("_board") as LaundryBoard
	# Seviye sonu dizisi dokunuşla atlanır (yalnız tahta bittiyse; bitmediyse çıkmaz — sonra kaybettirmeyiz).
	if board.is_over() and _game.get("_overlay") == null:
		var click: InputEventMouseButton = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = Vector2(540.0, 900.0)
		_game.call("_unhandled_input", click)
		_skip_sent_msec = Time.get_ticks_msec()
	_settle_deadline = Time.get_ticks_msec() + MAX_SETTLE_MSEC
	_phase = "end_wait"


func _end_wait_step() -> void:
	var board: LaundryBoard = _game.get("_board") as LaundryBoard
	if board.is_over() and _game.get("_overlay") == null and Time.get_ticks_msec() < _settle_deadline:
		return
	if not board.is_over():
		# Yol bitti ama tahta bitmedi (olmamalı): kayıt + denetim.
		_fail("L%d işlemler bitti, tahta bitmedi" % _level)
	elif _game.get("_overlay") == null:
		_fail("L%d sonuç sayfası gelmedi" % _level)
	elif _skip_sent_msec > 0:
		print("PROBE L%d sonu atlandı: dokunuştan sonuç sayfasına %d ms" % [_level, Time.get_ticks_msec() - _skip_sent_msec])
	_begin_settle("stress_finish")


func _begin_settle(resume: String) -> void:
	_resume = resume
	_settle_deadline = Time.get_ticks_msec() + MAX_SETTLE_MSEC
	_phase = "settle"


func _settle_step() -> void:
	var still: bool = _screen_still()
	if not still and Time.get_ticks_msec() < _settle_deadline:
		return
	if not still:
		_fail("L%d ekran %d sn içinde durulmadı (oynuyor=%s, kayıtlı tween=%d)" % [_level,
			MAX_SETTLE_MSEC / 1000, str(_game.get("_playing")), Motion.running_tracked()])
	_audit("L%d %s" % [_level, "son" if _resume == "stress_finish" else "ara"])
	match _resume:
		"stress_play":
			_phase = "stress_play"
		"stress_finish":
			_finish_level()
		"slow_finish":
			_finish_slow()
		"slow_play":
			_phase = "slow_play"


func _finish_level() -> void:
	var board: LaundryBoard = _game.get("_board") as LaundryBoard
	var replay: Dictionary = _pure_replay(_game.get("_level") as Dictionary, _ops, board.rack_slots() - _extra_count(_ops))
	var actual: Dictionary = _result_of(board, _game.get("_run_stats") as RunStats)
	if replay != actual:
		_fail("L%d sonuç saf tekrarla aynı değil:\n  oyun %s\n  saf  %s" % [_level, str(actual), str(replay)])
	print("PROBE L%d tamam: işlem=%d kazandı=%s hamle=%d" % [_level, _ops.size(), str(board.is_won()), board.moves()])
	_recorded_ops[_level] = _ops.duplicate(true)
	_recorded_results[_level] = actual
	var orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) - _orphans_start
	_orphans_max = maxi(_orphans_max, orphans)
	_phase = "stress_load"


func _extra_count(ops: Array[Array]) -> int:
	var count: int = 0
	for op: Array in ops:
		if String(op[0]) == "extra":
			count += 1
	return count


## Aynı işlemler görünümsüz, saf tahtada: oyun katmanı mantığı değiştirmediyse sonuç birebir aynıdır.
func _pure_replay(level: Dictionary, ops: Array[Array], start_slots: int) -> Dictionary:
	var board: LaundryBoard = LaundryBoard.new(level)
	while board.rack_slots() < start_slots:
		board.add_rack_slot()
	board.enable_history()
	var boosters: Boosters = Boosters.new()
	var stats: RunStats = RunStats.from_balance(_progress.call("balance_table") as Dictionary)
	for op: Array in ops:
		match String(op[0]):
			"tap":
				var id: int = int(op[1])
				var events: Array[Dictionary] = board.tap(id)
				if id >= 0 and not events.is_empty():
					stats.record_tap(events)
			"undo":
				if boosters.undo(board):
					stats.note_booster()
			"extra":
				if boosters.extra_slot(board):
					stats.note_booster()
			"pin":
				boosters.pin(board, int(op[1]))
	return _result_of(board, stats)


func _result_of(board: LaundryBoard, stats: RunStats) -> Dictionary:
	return {"won": board.is_won(), "lost": board.is_lost(), "moves": board.moves(), "key": board.state_key(),
		"summary": board.result_summary(), "taps": stats.taps, "best_chain": stats.best_chain,
		"baskets": stats.baskets_done}


# ================================================================ yavaş tekrar

func _slow_load() -> void:
	if _slow_queue.is_empty():
		_phase = "leak"
		return
	_level = _slow_queue.pop_front()
	if not _recorded_ops.has(_level):
		_fail("L%d yavaş tekrar için kayıt yok" % _level)
		return
	_progress.call("reset_state")
	for id: String in Boosters.IDS:
		_progress.call("add_booster", id, 40)
	_load(_level)
	_slow_ops = (_recorded_ops[_level] as Array).duplicate(true)
	_slow_expect = _recorded_results[_level] as Dictionary
	_phase = "slow_play"
	_wait_frames = 2


func _slow_play() -> void:
	if _slow_ops.is_empty():
		_begin_settle("slow_finish")
		return
	var op: Array = _slow_ops.pop_front()
	match String(op[0]):
		"tap":
			_game.call("_tap", int(op[1]))
		"undo":
			_game.call("_on_booster_pressed", Boosters.UNDO)
		"extra":
			_game.call("_on_booster_pressed", Boosters.EXTRA_SLOT)
		"pin":
			var views: Dictionary = _game.get("_views") as Dictionary
			var view: GarmentView = views[int(op[1])] as GarmentView
			_game.call("_on_booster_pressed", Boosters.PIN_REMOVER)
			_game.call("_booster_intercepts", view.line_home + view.hit_rect().get_center())
	# Her işlemden sonra ekran tamamen durulur (sakin oyuncu).
	_settle_deadline = Time.get_ticks_msec() + MAX_SETTLE_MSEC
	_resume = "slow_play"
	_phase = "settle"


func _finish_slow() -> void:
	var board: LaundryBoard = _game.get("_board") as LaundryBoard
	if board.is_over() and _game.get("_overlay") == null:
		# Sonuç sayfası bekleme süresinden sonra gelir.
		_wait_frames = 30
		_resume = "slow_finish"
		_phase = "settle"
		return
	var actual: Dictionary = _result_of(board, _game.get("_run_stats") as RunStats)
	if actual != _slow_expect:
		_fail("L%d yavaş oyun sonucu hızlı oyunla aynı değil:\n  yavaş %s\n  hızlı %s" % [_level, str(actual), str(_slow_expect)])
	else:
		print("PROBE L%d yavaş tekrar aynı sonuç" % _level)
	_phase = "slow_load"


# ================================================================ geçiş sızıntısı

func _leak_step() -> void:
	if _tr_count == 0:
		_progress.call("reset_state")
		_load(TRANSITION_FROM)
	var board: LaundryBoard = _game.get("_board") as LaundryBoard
	if not board.is_over():
		var path: Array[int] = LevelSolver.solve(_game.get("_level") as Dictionary, SOLVE_LIMIT)
		for id: int in path:
			_game.call("_tap", id)
		_tr_count = maxi(_tr_count, 1)
		return
	var sheet: Variant = _game.get("_overlay")
	if sheet == null:
		var click: InputEventMouseButton = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		_game.call("_unhandled_input", click)
		return
	_tr_nodes.append(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	_tr_objects.append(int(Performance.get_monitor(Performance.OBJECT_COUNT)))
	if _tr_count >= TRANSITIONS:
		var nodes_growth: int = _tr_nodes[_tr_nodes.size() - 1] - _tr_nodes[4]
		var objects_growth: int = _tr_objects[_tr_objects.size() - 1] - _tr_objects[4]
		print("PROBE %d geçiş: düğüm %d -> %d -> %d, nesne %d -> %d -> %d" % [TRANSITIONS, _tr_nodes[0], _tr_nodes[4],
			_tr_nodes[_tr_nodes.size() - 1], _tr_objects[0], _tr_objects[4], _tr_objects[_tr_objects.size() - 1]])
		# Seviyeler farklı boyda: küçük oynama olağan; sürekli büyüme sızıntıdır.
		if nodes_growth > 400 or objects_growth > 4000:
			_fail("geçişlerde düğüm/nesne sürekli büyüyor (düğüm +%d, nesne +%d)" % [nodes_growth, objects_growth])
		_phase = "done"
		return
	_tr_count += 1
	(sheet as Object).emit_signal("continue_pressed")
	_wait_frames = 3


# ================================================================ denetim: görünüm == tahta

func _audit(where: String) -> void:
	_audits += 1
	var board: LaundryBoard = _game.get("_board") as LaundryBoard
	var views: Dictionary = _game.get("_views") as Dictionary
	var baskets: Array = _game.get("_baskets") as Array
	var rack_points: Array = _game.get("_rack_points") as Array
	var held: Dictionary = _game.get("_machine_held") as Dictionary
	var palette: Array = _game.get("COLORS") as Array
	var errors: Array[String] = []
	var in_basket: Dictionary = {}
	for index: int in range(baskets.size()):
		var contents: Array[int] = board.basket_contents(index)
		for stack: int in range(contents.size()):
			in_basket[contents[stack]] = Vector2i(index, stack)
	var rack: Array[int] = board.rack()
	for id: int in board.item_ids():
		var raw: Variant = views.get(id)
		var valid: bool = is_instance_valid(raw)
		var view: GarmentView = raw as GarmentView if valid else null
		var slot: int = rack.find(id)
		if board.is_on_line(id):
			if view == null:
				errors.append("%d ipte ama görünüm yok" % id)
				continue
			if not view.visible or view.in_flight:
				errors.append("%d ipte: görünür=%s uçuyor=%s" % [id, str(view.visible), str(view.in_flight)])
			if view.position.distance_to(view.line_home) > POS_TOLERANCE:
				errors.append("%d ipte ama yerinde değil (%s, beklenen %s)" % [id, str(view.position), str(view.line_home)])
			if not board.is_hidden(id) and view.is_open() != board.is_open(id):
				errors.append("%d açıklık görünümü %s, kural %s" % [id, str(view.is_open()), str(board.is_open(id))])
			if bool(view.get("_wet")) != board.is_wet(id):
				errors.append("%d ıslaklık görünümü %s, kural %s" % [id, str(view.get("_wet")), str(board.is_wet(id))])
			if bool(view.get("_locked")) != board.is_locked(id):
				errors.append("%d kilit görünümü yanlış" % id)
			if not board.is_dual(id) and not view.color.is_equal_approx(palette[board.color_of(id) % palette.size()] as Color):
				errors.append("%d rengi yanlış" % id)
		elif slot >= 0:
			if view == null or not view.visible or view.in_flight:
				errors.append("%d askıda ama görünüm yok/gizli/uçuyor" % id)
				continue
			if view.global_position.distance_to(rack_points[slot] as Vector2) > POS_TOLERANCE:
				errors.append("%d askı %d yerinde değil (%s, beklenen %s)" % [id, slot, str(view.global_position), str(rack_points[slot])])
			if absf(view.scale.x - float(_game.get("RACK_GARMENT_SCALE"))) > 0.01:
				errors.append("%d askıda ölçek %.2f" % [id, view.scale.x])
		elif in_basket.has(id):
			var at: Vector2i = in_basket[id] as Vector2i
			var basket: BasketView = baskets[at.x] as BasketView
			if view == null or not view.visible or view.in_flight:
				errors.append("%d sepette ama görünüm yok/gizli/uçuyor" % id)
				continue
			if not basket.holds(view):
				errors.append("%d sepet %d yığınında değil" % [id, at.x])
			elif view.global_position.distance_to(basket.slot_position(at.y)) > POS_TOLERANCE * 2.0:
				errors.append("%d sepet %d/%d yerinde değil" % [id, at.x, at.y])
		elif board.has_extras() and board.machine_of(id) != LaundryBoard.EMPTY:
			if view == null or view.visible or not held.has(id):
				errors.append("%d makinede ama görünür ya da tutulmuyor" % id)
		else:
			if view != null and view.visible and not view.is_queued_for_deletion():
				errors.append("%d bitti ama hâlâ görünür" % id)
	var states: Array[Dictionary] = board.baskets()
	for index: int in range(states.size()):
		var basket: BasketView = baskets[index] as BasketView
		if not basket.is_settled():
			errors.append("sepet %d durulmamış" % index)
		if states[index].is_empty():
			if basket.visible:
				errors.append("sepet %d kuralda yok ama görünür" % index)
			continue
		if not basket.visible:
			errors.append("sepet %d görünmüyor" % index)
		var expected: Color = palette[int(states[index]["color"]) % palette.size()] as Color
		if bool(states[index].get("joker", false)) and int(states[index]["color"]) == LaundryBoard.EMPTY:
			expected = BasketView.JOKER_BAND
		if not basket.shown_color().is_equal_approx(expected):
			errors.append("sepet %d rengi %s, kural %s" % [index, basket.shown_color().to_html(), expected.to_html()])
		if basket.filled != board.basket_contents(index).size():
			errors.append("sepet %d doluluk %d, kural %d" % [index, basket.filled, board.basket_contents(index).size()])
		if basket.capacity != board.basket_capacity(index):
			errors.append("sepet %d kapasite yanlış" % index)
		if basket.position.distance_to(basket.rest_position) > POS_TOLERANCE:
			errors.append("sepet %d yerinde değil" % index)
	if rack_points.size() != board.rack_slots():
		errors.append("askı noktası %d, kural %d" % [rack_points.size(), board.rack_slots()])
	# HUD: zincir hapı ve hamle sayacı tahtayla aynı.
	var stats: RunStats = _game.get("_run_stats") as RunStats
	var hud: Object = _game.get("_hud") as Object
	var chain: int = stats.chain() if stats.chain() >= RunStats.MIN_VISIBLE_CHAIN else 0
	if not board.is_over() and int(hud.call("shown_chain")) != chain:
		errors.append("zincir hapı %d, kural %d" % [int(hud.call("shown_chain")), chain])
	var rules: Object = _game.get("_rules_hud") as Object
	if board.mode() == LaundryBoard.MODE_MOVES and int(rules.get("_shown_moves")) != board.moves_left():
		errors.append("hamle sayacı %d, kural %d" % [int(rules.get("_shown_moves")), board.moves_left()])
	if Motion.running_tracked() != 0:
		errors.append("durulmuş ekranda %d kayıtlı tween sürüyor" % Motion.running_tracked())
	if not (_game.get("_events") as Array).is_empty():
		errors.append("olay kuyruğu boş değil")
	for error: String in errors:
		_fail("%s: %s" % [where, error])


func _note_mechanics(level: Dictionary) -> void:
	for item: Variant in level.get("items", []) as Array:
		for key: String in ["wet", "mystery", "lock", "sheet", "sock", "dye", "stain", "chain", "twin", "slide",
				"sun", "frost", "screen", "dirty", "leaf"]:
			if (item as Dictionary).has(key):
				_mechanics_seen[key] = true
	if level.has("mode"):
		_mechanics_seen["mode:" + String(level["mode"])] = true
	for key: String in ["wind", "mode", "washer", "dryer", "birds", "rain", "cat", "typed", "season", "screens",
			"jokers", "big", "leaves", "pollen", "sun", "frost"]:
		if level.has(key):
			_mechanics_seen[key] = true


func _load(level: int) -> void:
	if _game != null:
		_game.queue_free()
	_game = (load(GAME_SCENE) as PackedScene).instantiate()
	root.add_child(_game)
	current_scene = _game
	_game.set("_persist", false)
	_game.set("_level_number", level)
	_game.call("_start_level")


func _fail(message: String) -> void:
	_failed = true
	printerr("PROBE HATA: %s" % message)
