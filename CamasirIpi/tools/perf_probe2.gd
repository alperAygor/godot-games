extends SceneTree

## Son başarım geçişi probu. İki kip:
##   (1) sahneler (varsayılan): açılış (Boot beklemesinin emülasyonu), ana ekran, harita (boşta + kaydırma), mağaza, koleksiyon (soğuk + ılık açılış),
##       oyun L5 / L70 (kurutucu) / L88 (yağmur + kar) / L100 (kedi + polen + ilkbahar), L65 -> 66 "Devam",
##       zen. Her sahnede: kare süresi, betik süresi (TIME_PROCESS), açılış (eşzamanlı kurulum) süresi,
##       takılma kareleri (hangi olayın ardından), işlenen düğüm/ara geçiş (tween) sayıları ve script bazında
##       "boşta çalışan _process" dökümü. Pencerede ayrıca çizim çağrısı ve doku belleği.
##   (2) --leak: 12 seviye aynı sahnede "Devam" ile + 12 tam sahne döngüsü (ana ekran + meta ekranları ->
##       oyun -> ana ekran). Her döngü sonunda OBJECT_COUNT / NODE / ORPHAN / STATIC / statik önbellekler.
## Oyuncunun kaydına ASLA yazmaz (Progress.persist = false, ilk iş).
##   godot --headless --path . -s res://tools/perf_probe2.gd -- --out=docs/perf/final_raw/after_cpu.md --label=cpu
##   godot --path . -s res://tools/perf_probe2.gd -- --out=docs/perf/final_raw/after_window.md --label=pencere
##   godot --headless --path . -s res://tools/perf_probe2.gd -- --leak --out=docs/perf/final_raw/after_leak.md
##   (`--only=<ad parçası>` yalnız eşleşen senaryoları koşar.) Pencere koşusu ~4 dk; sert zaman aşımıyla çalıştırın.
## Başsız (headless) kipte çizim yoktur: kare süresi = betik + motor CPU işi (mobil CPU payının vekili);
## çizim çağrısı / doku belleği yalnız pencere kipinde anlamlıdır.
## NOT: autoload'a değen sınıflar (ZenMode, OnlineGate, sahneler) `load()` + `call/get` ile anılır.

const BOOT_SCENE: String = "res://scenes/Boot.tscn"
const HOME_SCENE: String = "res://scenes/Home.tscn"
const GAME_SCENE: String = "res://scenes/Game.tscn"
const ZEN_SCRIPT: String = "res://scripts/zen/zen_mode.gd"
const GATE_SCRIPT: String = "res://scripts/net/online_gate.gd"
const PREFETCH_SCRIPT: String = "res://scripts/core/level_prefetch.gd"
const BACKDROP_SCRIPT: String = "res://scripts/game/garden_backdrop.gd"
const ZEN_SEED: int = 4242
const BOOT_HOLD_MSEC: int = 400
const GAME_LEVELS: Array[int] = [5, 70, 88, 100]
const NEXT_LEVEL_FROM: int = 65
const WIN_SHEET_MSEC: int = 1500
const SOLVE_LIMIT: int = 200000
const WARMUP_FRAMES: int = 10
const STATIC_SAMPLE_MSEC: int = 3000
const SCROLL_SAMPLE_MSEC: int = 3000
## Harita kaydırma hızı (px/sn): hızlı bir parmak savurması.
const SCROLL_SPEED: float = 3000.0
const TAP_EVERY_MSEC: int = 380
const AFTER_PLAY_MSEC: int = 1500
const MAX_PLAY_MSEC: int = 60000
const ZEN_BOARDS: int = 2
const SETTLE_FRAMES: int = 6
## Pencerede 30 fps'nin altına düşen kare = görünür takılma. Başsızda (yalnız CPU, Apple M4) eşik 4 ms:
## orta sınıf Android CPU'su kabaca 5-8 kat yavaştır, 4 ms orada ~20-33 ms'lik bir kareye denk gelir.
const HITCH_MSEC: float = 33.3
const HITCH_HEADLESS_MSEC: float = 4.0
const USEC_PER_MSEC: float = 1000.0
const BYTES_PER_MIB: float = 1048576.0
const P99: float = 0.99
## Sızıntı kipi.
const LEAK_DEVAM_FROM: int = 60
const LEAK_DEVAM_LEVELS: int = 12
const LEAK_SCENE_LEVELS: Array[int] = [3, 8, 14, 18, 22, 26, 31, 36, 64, 82, 94, 124]
const LEAK_FRAMES_PER_TAP: int = 3
const LEAK_TIME_SCALE: float = 3.0
const LEAK_MAX_LEVEL_MSEC: int = 90000

var _out: String = "docs/perf/final_run.md"
var _label: String = "run"
var _only: String = ""
var _leak: bool = false
var _headless: bool = false
var _progress: Node = null
var _zen_script: GDScript = null
var _prefetch_script: GDScript = null
var _backdrop_script: GDScript = null
var _queue: Array[Dictionary] = []
var _rows: Array[Dictionary] = []
var _current: Dictionary = {}
var _phase: String = "start"
var _wait: int = 0
var _home: Node = null
var _scene: Node = null
var _overlay: Node = null
var _frames: PackedFloat32Array = PackedFloat32Array()
var _script_ms: PackedFloat32Array = PackedFloat32Array()
var _draw_calls: PackedInt32Array = PackedInt32Array()
var _hitches: Array[String] = []
var _marker: String = "open"
var _last_usec: int = 0
var _open_usec: int = 0
var _sample_until: int = 0
var _warm: int = 0
var _path: Array[int] = []
var _next_tap_msec: int = 0
var _play_end_msec: int = 0
var _next_at_msec: int = 0
var _taps: int = 0
var _board_seen: Object = null
var _boards_done: int = 0
var _first_frame: bool = false
var _scroll_dir: float = -1.0
## Sızıntı kipi durumu.
var _leak_rows: Array[Dictionary] = []
var _leak_step: int = 0
var _leak_deadline: int = 0
var _boot_at_msec: int = 0
var _tail: TailProbe = null


## En son işlenen düğüm: karenin başından (MainLoop._process) tüm düğüm `_process`'leri bitene dek
## geçen süreyi ölçer (zamanlayıcı/tween geri çağrıları hariç; onlar sonraki kare süresine girer).
class TailProbe extends Node:
	var spent_usec: int = 0
	var start_usec: int = 0

	func _ready() -> void:
		process_priority = 2147483647
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _process(_delta: float) -> void:
		spent_usec = Time.get_ticks_usec() - start_usec


func _initialize() -> void:
	# Önce diske yazma kapanır, sonra bellek sıfırlanır: gerçek kayıt dokunulmaz kalır.
	_progress = root.get_node_or_null("Progress")
	if _progress != null:
		_progress.set("persist", false)
		_progress.call("reset_state")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr("--out=".length())
		elif arg.begins_with("--label="):
			_label = arg.substr("--label=".length())
		elif arg.begins_with("--only="):
			_only = arg.substr("--only=".length())
		elif arg == "--leak":
			_leak = true
	_headless = DisplayServer.get_name() == "headless"
	(load(GATE_SCRIPT) as GDScript).set("enabled", false)
	_zen_script = load(ZEN_SCRIPT) as GDScript
	_prefetch_script = load(PREFETCH_SCRIPT) as GDScript
	_backdrop_script = load(BACKDROP_SCRIPT) as GDScript
	AnalyticsLog.echo = false
	if _headless:
		# Başsız sürücü kareleri 6.9 ms'ye (low_processor_mode_sleep_usec) sabitler: iş bunun altında
		# görünmez. Uyku kapatılınca kare süresi = gerçek CPU işi.
		OS.low_processor_usage_mode_sleep_usec = 0
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
	if _leak:
		Engine.time_scale = LEAK_TIME_SCALE
		_phase = "leak_start"
		return
	# Soğuk açılış: Boot (0.4 sn bekleme dahil) -> ilk gerçek sahne (ana ekran; seviye 30 kaydı).
	_queue.append({"name": "boot -> ana ekran (0.4 sn bekleme dahil)", "kind": "boot", "level": 30})
	_queue.append({"name": "home", "kind": "home"})
	for pass_name: String in ["soğuk", "ılık"]:
		_queue.append({"name": "map açılış (%s) + boşta" % pass_name, "kind": "meta", "meta": "map"})
		_queue.append({"name": "shop açılış (%s)" % pass_name, "kind": "meta", "meta": "shop"})
		_queue.append({"name": "collection açılış (%s)" % pass_name, "kind": "meta", "meta": "collection"})
	_queue.append({"name": "map kaydırma", "kind": "meta", "meta": "map", "scroll": true})
	for level: int in GAME_LEVELS:
		_queue.append({"name": "game L%d" % level, "kind": "game", "level": level})
	_queue.append({"name": "game L%d -> %d (Devam)" % [NEXT_LEVEL_FROM, NEXT_LEVEL_FROM + 1], "kind": "game",
		"level": NEXT_LEVEL_FROM, "next": true})
	_queue.append({"name": "zen (%d tahta)" % ZEN_BOARDS, "kind": "zen", "level": 40})
	# Aynı seviye ikinci kez: ilk açılıştaki fazla iş "ilk kullanım" (yazı tipi glifleri, betik
	# derleme, doku yükleme) mi, her açılışta mı ödeniyor ayrılsın.
	_queue.append({"name": "game L100 (ikinci açılış)", "kind": "game", "level": 100})
	if not _only.is_empty():
		_queue = _queue.filter(func(entry: Dictionary) -> bool: return String(entry["name"]).contains(_only))


func _process(_delta: float) -> bool:
	var now_usec: int = Time.get_ticks_usec()
	if _tail == null:
		_tail = TailProbe.new()
		root.add_child(_tail)
	var tail_usec: int = _tail.spent_usec
	_tail.start_usec = now_usec
	if _wait > 0:
		_wait -= 1
		_last_usec = now_usec
		return false
	match _phase:
		"start", "next":
			_next_scenario()
		"sample":
			_sample(now_usec, tail_usec)
		"wait_boot":
			# Bekleme bitince ana ekran kurulur; açılış süresi beklemenin başından sayılır.
			if Time.get_ticks_msec() >= _boot_at_msec:
				var build_start: int = Time.get_ticks_usec()
				var manager: Node = root.get_node_or_null("GameManager")
				if manager != null and manager.has_method(&"scene_resource"):
					_home = (manager.call(&"scene_resource", &"home") as PackedScene).instantiate()
					root.add_child(_home)
					current_scene = _home
				else:
					_home = _instance(HOME_SCENE)
				_current["open_ms"] = float(Time.get_ticks_usec() - _open_usec) / USEC_PER_MSEC
				# İlk kare hesabından yalnız bu karedeki eşzamanlı kurulum düşülür (bekleme değil).
				_current["frame_open_ms"] = float(Time.get_ticks_usec() - build_start) / USEC_PER_MSEC
				_first_frame = true
				_phase = "sample"
				_sample_until = Time.get_ticks_msec() + STATIC_SAMPLE_MSEC
		"leak_start", "leak_next", "leak_play", "leak_settle":
			_leak_tick()
	_last_usec = now_usec
	return false


# --- Sahne senaryoları ------------------------------------------------------------------------

func _next_scenario() -> void:
	_clear_scenes()
	if _queue.is_empty():
		_phase = "done"
		_write_report()
		quit(0)
		return
	_current = _queue.pop_front()
	_frames.clear()
	_script_ms.clear()
	_draw_calls.clear()
	_hitches.clear()
	_marker = "open"
	_warm = WARMUP_FRAMES
	_taps = 0
	_path.clear()
	_board_seen = null
	_boards_done = 0
	_next_at_msec = 0
	_play_end_msec = 0
	_current["next_ms"] = -1.0
	_set_level(int(_current.get("level", 30)))
	var kind: String = String(_current["kind"])
	_open_usec = Time.get_ticks_usec()
	var frame_start: int = _open_usec
	match kind:
		"boot":
			# Boot sahnesinin kendisi açılmaz: `UiData.consume_first_launch` kullanıcı dizinine yazar.
			# Onun yerine Boot'un bekleme işi aynen yapılır (seviye ön üretimi + bahçe dokuları iş
			# parçacığında), 0.4 sn sonra ana ekran açılır.
			_prefetch_script.call("request_level", int(_current["level"]))
			_backdrop_script.call("warm_up")
			var manager: Node = root.get_node_or_null("GameManager")
			if manager != null and manager.has_method(&"preload_scene"):
				manager.call(&"preload_scene", &"home")
				manager.call(&"preload_scene", &"game")
			_boot_at_msec = Time.get_ticks_msec() + BOOT_HOLD_MSEC
			_phase = "wait_boot"
			return
		"home":
			_home = _instance(HOME_SCENE)
		"meta":
			_home = _instance(HOME_SCENE)
			# Ana ekranın kurulumu ayrı ölçülür: açılış süresi yalnız meta ekranınındır.
			_open_usec = Time.get_ticks_usec()
			match String(_current["meta"]):
				"map":
					_home.call("_open_map")
				"shop":
					_home.call("_on_tab", 0)
				"collection":
					_home.call("_on_tab", 2)
			_overlay = _home.get("_meta") as Node
		"game", "zen":
			if kind == "zen":
				_zen_script.set("pending_seed", ZEN_SEED)
				_zen_script.call("request_start")
			else:
				# Gerçek akışta seviye ana ekranda/önceki seviyede arka planda üretilir; prob da
				# önbelleği önceden doldurur ki açılış süresi yalnız sahne kurulumunu ölçsün.
				var gen_start: int = Time.get_ticks_usec()
				_prefetch_script.call("take_level", int(_current["level"]))
				_current["gen_ms"] = float(Time.get_ticks_usec() - gen_start) / USEC_PER_MSEC
				_open_usec = Time.get_ticks_usec()
			_scene = (load(GAME_SCENE) as PackedScene).instantiate()
			_scene.set("_persist", false)
			_scene.set("_level_number", int(_current["level"]))
			root.add_child(_scene)
			current_scene = _scene
			_mark_tutorials_seen()
	_current["open_ms"] = float(Time.get_ticks_usec() - _open_usec) / USEC_PER_MSEC
	# Açılış karesindeki tüm eşzamanlı iş (ön üretim dahil): ilk kare hesabından düşülür.
	_current["frame_open_ms"] = float(Time.get_ticks_usec() - frame_start) / USEC_PER_MSEC
	_first_frame = true
	_phase = "sample"
	_sample_until = Time.get_ticks_msec() + (MAX_PLAY_MSEC if kind == "game" or kind == "zen" else STATIC_SAMPLE_MSEC)
	if bool(_current.get("scroll", false)):
		_sample_until = Time.get_ticks_msec() + SCROLL_SAMPLE_MSEC
	_next_tap_msec = Time.get_ticks_msec() + TAP_EVERY_MSEC


func _instance(path: String) -> Node:
	var node: Node = (load(path) as PackedScene).instantiate()
	root.add_child(node)
	current_scene = node
	return node


func _set_level(level: int) -> void:
	if _progress != null:
		(_progress.get("data") as ProgressData).level = level


## Tanıtım kartları tahtayı örtmesin (yalnız bellekte "görüldü").
func _mark_tutorials_seen() -> void:
	var tutorial: Node = _scene.get("_tutorial") as Node
	if tutorial == null:
		return
	var seen: Dictionary = tutorial.get("_memory_seen") as Dictionary
	for feature: Variant in TutorialFeatures.table().get("card_order", []) as Array:
		seen["tut_card_%s" % String(feature)] = true


func _sample(now_usec: int, tail_usec: int) -> void:
	var frame_ms: float = float(now_usec - _last_usec) / USEC_PER_MSEC
	if _first_frame:
		# Açılıştan sonraki ilk kare: kurulumun kalan işi (ilk çizim, gölgelendirici derleme) burada.
		_first_frame = false
		_current["first_frame_ms"] = frame_ms - float(_current.get("frame_open_ms", _current["open_ms"]))
		return
	var kind: String = String(_current["kind"])
	if kind == "game" or kind == "zen":
		_drive_game()
		if _phase != "sample":
			return
	if bool(_current.get("scroll", false)):
		_drive_scroll(frame_ms)
	if _warm > 0:
		_warm -= 1
		return
	_frames.append(frame_ms)
	_script_ms.append(float(tail_usec) / USEC_PER_MSEC)
	if not _headless:
		_draw_calls.append(RenderingServer.viewport_get_render_info(root.get_viewport_rid(),
			RenderingServer.VIEWPORT_RENDER_INFO_TYPE_CANVAS, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME))
	if frame_ms > (HITCH_HEADLESS_MSEC if _headless else HITCH_MSEC):
		_hitches.append("%.0f ms @%s" % [frame_ms, _marker])
	if Time.get_ticks_msec() >= _sample_until:
		_finish_scenario()


func _drive_scroll(frame_ms: float) -> void:
	var canvas: Control = _overlay.get("_canvas") as Control if _overlay != null else null
	if canvas == null:
		return
	var before: float = float(canvas.get("scroll_top"))
	canvas.call("set_scroll", before + _scroll_dir * SCROLL_SPEED * frame_ms / USEC_PER_MSEC)
	if is_equal_approx(before, float(canvas.get("scroll_top"))):
		_scroll_dir = -_scroll_dir


func _drive_game() -> void:
	var now: int = Time.get_ticks_msec()
	var board: LaundryBoard = _scene.get("_board") as LaundryBoard
	if board == null:
		return
	var zen: bool = String(_current["kind"]) == "zen"
	if board != _board_seen:
		# Yeni tahta (ilk açılış, zen'de sıradaki tahta, Devam): çözüm yolu yeniden bulunur.
		if _board_seen != null:
			_boards_done += 1
		_board_seen = board
		_path = LevelSolver.solve(_scene.get("_level") as Dictionary, SOLVE_LIMIT)
		_marker = "tahta %d" % (_boards_done + 1)
		if zen and _boards_done >= ZEN_BOARDS:
			_finish_scenario()
			return
	if _play_end_msec == 0 and now >= _next_tap_msec and not board.is_over() and not _path.is_empty():
		_scene.call("_tap", _path.pop_front())
		_taps += 1
		_marker = "dokunuş %d" % _taps
		_next_tap_msec = now + TAP_EVERY_MSEC
	if board.is_won() and not bool(_scene.get("_playing")) and not _marker.begins_with("kazanma"):
		_marker = "kazanma sayfası"
	var wants_next: bool = bool(_current.get("next", false))
	if not zen and board.is_won() and not bool(_scene.get("_playing")):
		if wants_next and _next_at_msec == 0 and float(_current["next_ms"]) < 0.0:
			_next_at_msec = now + WIN_SHEET_MSEC
		elif not wants_next and _play_end_msec == 0:
			_play_end_msec = now + AFTER_PLAY_MSEC
	if _next_at_msec > 0 and now >= _next_at_msec and float(_current["next_ms"]) < 0.0:
		var start: int = Time.get_ticks_usec()
		_scene.call("_start_level")
		_current["next_ms"] = float(Time.get_ticks_usec() - start) / USEC_PER_MSEC
		_marker = "Devam"
		_play_end_msec = now + AFTER_PLAY_MSEC
	if board.is_over() and not board.is_won() and _play_end_msec == 0:
		_play_end_msec = now + AFTER_PLAY_MSEC
	if _play_end_msec > 0 and now >= _play_end_msec:
		_finish_scenario()


func _finish_scenario() -> void:
	var row: Dictionary = _current.duplicate()
	var sorted: PackedFloat32Array = _frames.duplicate()
	sorted.sort()
	row["frames"] = _frames.size()
	row["avg_ms"] = _mean(_frames)
	row["p99_ms"] = sorted[clampi(int(float(sorted.size()) * P99), 0, sorted.size() - 1)] if not sorted.is_empty() else 0.0
	row["max_ms"] = sorted[sorted.size() - 1] if not sorted.is_empty() else 0.0
	row["script_ms"] = _mean(_script_ms)
	row["draw_calls"] = _mean_int(_draw_calls)
	row["draw_calls_max"] = _max_int(_draw_calls)
	row["tmem_mib"] = float(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)) / BYTES_PER_MIB
	row["vmem_mib"] = float(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)) / BYTES_PER_MIB
	row["static_mib"] = float(Performance.get_monitor(Performance.MEMORY_STATIC)) / BYTES_PER_MIB
	row["nodes"] = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	row["objects"] = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	row["orphans"] = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var cover: Dictionary = _coverage_census(root)
	row["cover"] = float(cover["cover"])
	row["hidden_cover"] = float(cover["hidden"])
	row["hidden_items"] = cover["hidden_items"]
	var processing: Dictionary = _processing_census(root)
	row["proc_nodes"] = int(processing["count"])
	row["proc_by_script"] = processing["by_script"]
	row["tweens"] = get_processed_tweens().size()
	row["hitches"] = _hitches.duplicate()
	row["taps"] = _taps
	if _scene != null and _scene.get("_board") != null:
		row["won"] = (_scene.get("_board") as LaundryBoard).is_won()
	_rows.append(row)
	print("PERF2 %s: kare ort=%.2f p99=%.2f en=%.1f ms, betik=%.2f ms, açılış=%.0f+%.0f ms, çizim=%.0f, doku=%.1f MiB, düğüm=%d, işlenen=%d, tween=%d, takılma=%d" % [
		String(row["name"]), float(row["avg_ms"]), float(row["p99_ms"]), float(row["max_ms"]), float(row["script_ms"]),
		float(row["open_ms"]), float(row.get("first_frame_ms", 0.0)), float(row["draw_calls"]), float(row["tmem_mib"]),
		int(row["nodes"]), int(row["proc_nodes"]), int(row["tweens"]), _hitches.size()])
	_phase = "next"
	_wait = SETTLE_FRAMES


## Şu an gerçekten `_process` alan düğümler (işlenebilir olanlar), script dosyası başına.
func _processing_census(top: Node) -> Dictionary:
	var by_script: Dictionary[String, int] = {}
	var count: int = 0
	var stack: Array[Node] = [top]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child: Node in node.get_children():
			stack.append(child)
		if node == top or node == _tail or not (node.is_processing() or node.is_physics_processing()):
			continue
		if not node.can_process():
			continue
		count += 1
		var script: Script = node.get_script() as Script
		var key: String = script.resource_path.get_file() if script != null else node.get_class()
		by_script[key] = by_script.get(key, 0) + 1
	return {"count": count, "by_script": by_script}


## Aşırı çizim (overdraw) vekili: görünür doku/renk kutularının ekranla kesişen alanlarının toplamı /
## ekran alanı (1.0 = ekranı bir kez kaplayan). "Gizli": görünür sayılan ama etkin saydamlığı 0 olan
## (yine de çizilen) öğeler — tam ekran saydam örtüler boşa piksel doldurur.
func _coverage_census(top: Node) -> Dictionary:
	var view: Rect2 = root.get_visible_rect()
	var screen: float = maxf(view.get_area(), 1.0)
	var total: float = 0.0
	var hidden: float = 0.0
	var hidden_items: Array[String] = []
	var stack: Array[Node] = [top]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child: Node in node.get_children():
			stack.append(child)
		var rect: Rect2 = Rect2()
		if node is Sprite2D:
			var sprite: Sprite2D = node as Sprite2D
			if sprite.texture == null or not sprite.is_visible_in_tree():
				continue
			rect = sprite.get_global_transform_with_canvas() * sprite.get_rect()
		elif node is TextureRect or node is ColorRect or node is Panel or node is PanelContainer:
			var control: Control = node as Control
			if not control.is_visible_in_tree():
				continue
			if node is TextureRect and (node as TextureRect).texture == null:
				continue
			rect = control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)
		else:
			continue
		var area: float = rect.intersection(view).get_area()
		if area <= 0.0:
			continue
		if _effective_alpha(node as CanvasItem) <= 0.001:
			hidden += area
			if area > screen * 0.25:
				hidden_items.append("%s(%s) %.0f%%" % [node.name, node.get_class(), area / screen * 100.0])
			continue
		total += area
	return {"cover": total / screen, "hidden": hidden / screen, "hidden_items": hidden_items}


func _effective_alpha(item: CanvasItem) -> float:
	var alpha: float = item.self_modulate.a
	var node: Node = item
	while node != null:
		if node is CanvasItem:
			alpha *= (node as CanvasItem).modulate.a
		node = node.get_parent()
	return alpha


func _clear_scenes() -> void:
	for node: Node in [_overlay, _scene, _home]:
		if node != null and is_instance_valid(node):
			node.queue_free()
	_overlay = null
	_scene = null
	_home = null


# --- Sızıntı kipi ----------------------------------------------------------------------------

## Adımlar: önce LEAK_DEVAM_LEVELS seviye tek oyun sahnesinde "Devam" ile, sonra her seviye için
## ana ekran (+ harita, mağaza, koleksiyon aç/kapa) -> oyun sahnesi -> sahne serbest.
func _leak_tick() -> void:
	match _phase:
		"leak_start":
			_leak_snapshot("başlangıç (sahne yok)")
			_set_level(LEAK_DEVAM_FROM)
			_scene = (load(GAME_SCENE) as PackedScene).instantiate()
			_scene.set("_persist", false)
			_scene.set("_level_number", LEAK_DEVAM_FROM)
			root.add_child(_scene)
			current_scene = _scene
			_mark_tutorials_seen()
			_leak_begin_level()
			_phase = "leak_play"
		"leak_play":
			if _leak_play_step():
				_leak_step += 1
				if _leak_step < LEAK_DEVAM_LEVELS:
					_leak_snapshot("Devam %d (L%d bitti)" % [_leak_step, int(_scene.get("_level_number")) - 1])
					_scene.call("_start_level")
					_leak_begin_level()
				elif _leak_step == LEAK_DEVAM_LEVELS:
					_leak_snapshot("Devam %d (L%d bitti)" % [_leak_step, int(_scene.get("_level_number")) - 1])
					_clear_scenes()
					_phase = "leak_settle"
					_wait = SETTLE_FRAMES
				else:
					_clear_scenes()
					_phase = "leak_settle"
					_wait = SETTLE_FRAMES
		"leak_settle":
			var cycle: int = _leak_step - LEAK_DEVAM_LEVELS
			if cycle > 0:
				_leak_snapshot("sahne döngüsü %d (L%d)" % [cycle, LEAK_SCENE_LEVELS[cycle - 1]])
			if cycle >= LEAK_SCENE_LEVELS.size():
				_write_leak_report()
				quit(0)
				return
			_phase = "leak_next"
		"leak_next":
			var cycle: int = _leak_step - LEAK_DEVAM_LEVELS
			var level: int = LEAK_SCENE_LEVELS[cycle]
			_set_level(level)
			# Ana ekran + üç meta ekranı açılıp kapanır (gerçek akış: ana ekran sahnesi serbest kalır).
			_home = _instance(HOME_SCENE)
			_home.call("_open_map")
			(_home.get("_meta") as Node).queue_free()
			_home.call("_on_tab", 0)
			(_home.get("_meta") as Node).queue_free()
			_home.call("_on_tab", 2)
			(_home.get("_meta") as Node).queue_free()
			_home.queue_free()
			_home = null
			_scene = (load(GAME_SCENE) as PackedScene).instantiate()
			_scene.set("_persist", false)
			_scene.set("_level_number", level)
			root.add_child(_scene)
			current_scene = _scene
			_mark_tutorials_seen()
			_leak_begin_level()
			_phase = "leak_play"


func _leak_begin_level() -> void:
	_board_seen = _scene.get("_board")
	_path = LevelSolver.solve(_scene.get("_level") as Dictionary, SOLVE_LIMIT)
	_leak_deadline = Time.get_ticks_msec() + LEAK_MAX_LEVEL_MSEC
	_wait = 2


## Bir adım oynar; seviye kazanılıp animasyonlar bitince true.
func _leak_play_step() -> bool:
	var board: LaundryBoard = _scene.get("_board") as LaundryBoard
	if board.is_won() and not bool(_scene.get("_playing")):
		return true
	if Time.get_ticks_msec() > _leak_deadline:
		push_warning("perf_probe2: seviye süresinde bitmedi (L%d)" % int(_scene.get("_level_number")))
		return true
	if not _path.is_empty() and not board.is_over():
		_scene.call("_tap", _path.pop_front())
		_wait = LEAK_FRAMES_PER_TAP
	return false


func _leak_snapshot(name: String) -> void:
	var prefetch_results: Dictionary = _prefetch_script.get("_results") as Dictionary
	var prefetch_tasks: Dictionary = _prefetch_script.get("_tasks") as Dictionary
	var textures: Dictionary = _backdrop_script.get("_textures") as Dictionary
	var requested: Array = _backdrop_script.get("_requested") as Array
	var row: Dictionary = {
		"name": name,
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"static_mib": float(Performance.get_monitor(Performance.MEMORY_STATIC)) / BYTES_PER_MIB,
		"tmem_mib": float(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)) / BYTES_PER_MIB,
		"tweens": get_processed_tweens().size(),
		"prefetch": "%d sonuç / %d görev" % [prefetch_results.size(), prefetch_tasks.size()],
		"backdrop_tex": "%d (+%d istek)" % [textures.size(), requested.size()],
	}
	_leak_rows.append(row)
	print("LEAK %s: nesne=%d kaynak=%d düğüm=%d yetim=%d statik=%.1f MiB tween=%d prefetch=%s bahçe dokusu=%s" % [
		name, int(row["objects"]), int(row["resources"]), int(row["nodes"]), int(row["orphans"]),
		float(row["static_mib"]), int(row["tweens"]), String(row["prefetch"]), String(row["backdrop_tex"])])


# --- Rapor ------------------------------------------------------------------------------------

func _header(lines: PackedStringArray) -> void:
	lines.append("# Başarım ölçümü (son geçiş): %s" % _label)
	lines.append("")
	lines.append("- Tarih: %s" % Time.get_datetime_string_from_system())
	lines.append("- Godot: %s, sürücü: %s, işleyici: %s, ekran kartı: %s" % [Engine.get_version_info()["string"],
		DisplayServer.get_name(), RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name()])
	lines.append("- İşlemci: %s (%d çekirdek), işletim sistemi: %s" % [OS.get_processor_name(),
		OS.get_processor_count(), OS.get_name()])
	lines.append("")


func _write_report() -> void:
	var lines: PackedStringArray = PackedStringArray()
	_header(lines)
	if _headless:
		lines.append("Başsız kip: kare süresi = betik + motor CPU (çizim yok). Çizim/doku sütunları anlamsız (0).")
	else:
		lines.append("Pencere kipi, VSync kapalı: kare süresi = kare başına gerçek iş.")
	lines.append("")
	lines.append("| Sahne | açılış eşzamanlı (ms) | ilk kare (ms) | kare ort (ms) | p99 (ms) | en kötü (ms) | düğüm _process/kare (ms) | çizim çağrısı ort / en çok | doku (MiB) | statik (MiB) | düğüm | işlenen düğüm | tween | takılma (eşik üstü kare) | Devam (ms) | kaplama (ekran) | saydam ama çizilen (ekran) |")
	lines.append("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
	for row: Dictionary in _rows:
		lines.append("| %s | %.0f | %.0f | %.2f | %.2f | %.1f | %.2f | %.0f / %d | %.1f | %.1f | %d | %d | %d | %d | %s | %.1f | %.2f |" % [
			String(row["name"]), float(row["open_ms"]), float(row.get("first_frame_ms", 0.0)), float(row["avg_ms"]),
			float(row["p99_ms"]), float(row["max_ms"]), float(row["script_ms"]), float(row["draw_calls"]),
			int(row["draw_calls_max"]), float(row["tmem_mib"]), float(row["static_mib"]), int(row["nodes"]),
			int(row["proc_nodes"]), int(row["tweens"]), (row["hitches"] as Array).size(),
			"-" if float(row["next_ms"]) < 0.0 else "%.0f" % float(row["next_ms"]), float(row["cover"]),
			float(row["hidden_cover"])])
	lines.append("")
	lines.append("## Saydam (alfa 0) ama çizim listesinde kalan büyük öğeler (ekranın >%25'i)")
	lines.append("")
	for row: Dictionary in _rows:
		var hidden_items: Array = row["hidden_items"] as Array
		if not hidden_items.is_empty():
			lines.append("- %s: %s" % [String(row["name"]), ", ".join(PackedStringArray(hidden_items))])
	lines.append("")
	lines.append("## Takılma kareleri (eşik: %.1f ms; @ = karenin öncesindeki son olay)" % (HITCH_HEADLESS_MSEC if _headless else HITCH_MSEC))
	lines.append("")
	for row: Dictionary in _rows:
		var hitches: Array = row["hitches"] as Array
		if hitches.is_empty():
			continue
		lines.append("- %s: %s" % [String(row["name"]), ", ".join(PackedStringArray(hitches.slice(0, 12)))])
	lines.append("")
	lines.append("## Ölçüm sonunda `_process` alan düğümler (script başına)")
	lines.append("")
	for row: Dictionary in _rows:
		var parts: PackedStringArray = PackedStringArray()
		var by_script: Dictionary = row["proc_by_script"] as Dictionary
		for key: Variant in by_script.keys():
			parts.append("%s×%d" % [String(key), int(by_script[key])])
		lines.append("- %s (%d): %s" % [String(row["name"]), int(row["proc_nodes"]), ", ".join(parts)])
	lines.append("")
	_save(lines)


func _write_leak_report() -> void:
	var lines: PackedStringArray = PackedStringArray()
	_header(lines)
	lines.append("Sızıntı döngüsü: %d seviye tek sahnede Devam ile (L%d..), sonra %d tam sahne döngüsü (ana ekran + harita/mağaza/koleksiyon aç-kapa -> oyun -> serbest). Ölçüm her adımın sonunda; sahne döngüsü satırlarında sahne yoktur. time_scale=%.0f." % [
		LEAK_DEVAM_LEVELS, LEAK_DEVAM_FROM, LEAK_SCENE_LEVELS.size(), LEAK_TIME_SCALE])
	lines.append("")
	lines.append("| Adım | nesne | kaynak | düğüm | yetim | statik (MiB) | doku (MiB) | tween | LevelPrefetch | bahçe doku önbelleği |")
	lines.append("|---|---|---|---|---|---|---|---|---|---|")
	for row: Dictionary in _leak_rows:
		lines.append("| %s | %d | %d | %d | %d | %.1f | %.1f | %d | %s | %s |" % [String(row["name"]), int(row["objects"]),
			int(row["resources"]), int(row["nodes"]), int(row["orphans"]), float(row["static_mib"]), float(row["tmem_mib"]),
			int(row["tweens"]), String(row["prefetch"]), String(row["backdrop_tex"])])
	lines.append("")
	_save(lines)


func _save(lines: PackedStringArray) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + _out.get_base_dir()))
	var file: FileAccess = FileAccess.open("res://" + _out, FileAccess.WRITE)
	if file == null:
		push_error("perf_probe2: %s yazılamadı" % _out)
		return
	file.store_string("\n".join(lines) + "\n")
	file.close()
	print("PERF2 rapor: %s" % _out)


func _mean(values: PackedFloat32Array) -> float:
	if values.is_empty():
		return 0.0
	var total: float = 0.0
	for value: float in values:
		total += value
	return total / float(values.size())


func _mean_int(values: PackedInt32Array) -> float:
	if values.is_empty():
		return 0.0
	var total: int = 0
	for value: int in values:
		total += value
	return float(total) / float(values.size())


func _max_int(values: PackedInt32Array) -> int:
	var best: int = 0
	for value: int in values:
		best = maxi(best, value)
	return best
