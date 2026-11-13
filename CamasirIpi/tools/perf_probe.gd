extends SceneTree

## Başarım probu: temsilî sahneleri GERÇEK pencerede açar, kare süresi / çizim çağrısı / bellek
## ölçer ve Markdown tablosu yazar. Oyuncunun kaydına ASLA yazmaz (Progress.persist = false).
##   godot --path . --resolution 1080x1920 -s res://tools/perf_probe.gd -- --out=docs/perf/after.md --label=after
##   godot --headless --path . -s res://tools/perf_probe.gd -- --gen-only      # yalnız üretim kıyası
## Neden VSync kapalı: VSync açıkken kare süresi 16.7 ms'ye kilitlenir ve iyileşme görünmez;
## kapalıyken ölçülen süre "kare başına gerçek iş"tir (mobildeki boş payın vekili).
## Neden masaüstü: mobil cihaz yok; mutlak değerler değil, önce/sonra ORANI anlamlıdır.
## NOT: Oyun sınıfları (GarmentView, EcoFlow...) adla anılmaz: `-s` kipinde autoload kimlikleri
## derleme anında yoktur; sahneler `load()` ile açılır, alanlar `get/set` ile okunur.

const BOOT_SCENE: String = "res://scenes/Boot.tscn"
const HOME_SCENE: String = "res://scenes/Home.tscn"
const GAME_SCENE: String = "res://scenes/Game.tscn"
const LAUNDROMAT_SCENE: String = "res://scenes/meta/Laundromat.tscn"
const COLLECTION_SCENE: String = "res://scenes/meta/Collection.tscn"
## Oyun sahneleri: erken, patron (30), geç geniş tahta (60), büyük patron (75).
const GAME_LEVELS: Array[int] = [5, 30, 60, 75]
## Kazanınca "Devam" ile sonraki seviyeye geçiş ölçülür: 65 -> 66 (66 üretimi ~1 sn, en ağırlardan).
const NEXT_LEVEL_FROM: int = 65
## Kazanma sayfasında oyuncunun kalma süresi (bu arada arka plan üretimi bitebilir).
const WIN_SHEET_MSEC: int = 1500
const GEN_BENCH_LAST: int = 120
const GEN_SLOW_MSEC: float = 100.0
const SOLVE_LIMIT: int = 200000
## Isınma: ilk kareler doku yükleme/gölgelendirici derleme içerir; ortalamayı bozmasın.
const WARMUP_FRAMES: int = 20
const STATIC_SAMPLE_MSEC: int = 4000
## Hızlı bir oyuncu temposu (ms): olay kuyruğu dolu kalır, uçuşlar üst üste biner (en kötü durum).
const TAP_EVERY_MSEC: int = 380
const AFTER_PLAY_MSEC: int = 1500
const MAX_PLAY_MSEC: int = 60000
const SETTLE_FRAMES: int = 6
const USEC_PER_MSEC: float = 1000.0
const BYTES_PER_MIB: float = 1048576.0
const P99: float = 0.99

var _out: String = "docs/perf/run.md"
var _label: String = "run"
var _gen_only: bool = false
var _skip_gen: bool = false
## Yalnız adı bu metni içeren sahneler (hızlı yineleme için).
var _only: String = ""
var _queue: Array[Dictionary] = []
var _rows: Array[Dictionary] = []
var _gen_rows: Dictionary = {}
var _current: Dictionary = {}
var _phase: String = "start"
var _wait: int = 0
var _home: Node = null
var _scene: Node = null
var _overlay: Node = null
var _frames: PackedFloat32Array = PackedFloat32Array()
var _render_cpu_ms: PackedFloat32Array = PackedFloat32Array()
var _draw_calls: PackedInt32Array = PackedInt32Array()
var _items: PackedInt32Array = PackedInt32Array()
var _last_usec: int = 0
var _open_usec: int = 0
var _first_frame_usec: int = 0
var _sample_until: int = 0
var _warm: int = 0
var _path: Array[int] = []
var _next_tap_msec: int = 0
var _play_end_msec: int = 0
var _taps: int = 0
var _progress: Node = null
var _next_at_msec: int = 0


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr("--out=".length())
		elif arg.begins_with("--label="):
			_label = arg.substr("--label=".length())
		elif arg == "--gen-only":
			_gen_only = true
		elif arg == "--skip-gen":
			_skip_gen = true
		elif arg.begins_with("--only="):
			_only = arg.substr("--only=".length())
	_progress = root.get_node_or_null("Progress")
	if _progress != null:
		# Önce diske yazma kapanır, sonra bellek sıfırlanır: gerçek kayıt dokunulmaz kalır.
		_progress.set("persist", false)
		_progress.call("reset_state")
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
		RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	if not _gen_only:
		# Açılış: Boot (0.4 sn bekleme dahil) -> ilk gerçek sahnenin ilk karesi (sıfır kayıt = oyun L1).
		_queue.append({"name": "boot -> ilk sahne", "kind": "boot"})
		_queue.append({"name": "home", "kind": "home"})
		for level: int in GAME_LEVELS:
			_queue.append({"name": "game L%d" % level, "kind": "game", "level": level})
		_queue.append({"name": "game L%d -> %d (Devam)" % [NEXT_LEVEL_FROM, NEXT_LEVEL_FROM + 1], "kind": "game",
			"level": NEXT_LEVEL_FROM, "next": true})
		_queue.append({"name": "laundromat (full)", "kind": "laundromat"})
		_queue.append({"name": "collection", "kind": "collection"})
		if not _only.is_empty():
			_queue = _queue.filter(func(entry: Dictionary) -> bool: return String(entry["name"]).contains(_only))


func _process(_delta: float) -> bool:
	var now_usec: int = Time.get_ticks_usec()
	if _wait > 0:
		_wait -= 1
		_last_usec = now_usec
		return false
	match _phase:
		"start":
			if not _skip_gen:
				_gen_bench()
			if _gen_only or DisplayServer.get_name() == "headless":
				_write_report()
				quit(0)
				return true
			_phase = "next"
		"next":
			_next_scenario()
		"wait_first":
			pass
		"wait_boot":
			# Boot, beklemeden sonra sahneyi değiştirir; yeni sahnenin ilk çizilen karesi beklenir.
			if current_scene != null and current_scene != _scene and is_instance_valid(current_scene):
				_scene = current_scene
				_phase = "wait_first"
				RenderingServer.frame_post_draw.connect(_on_first_frame, CONNECT_ONE_SHOT)
		"sample":
			_sample(now_usec)
	_last_usec = now_usec
	return false


# --- Üretim kıyası (başsız da çalışır) --------------------------------------------------------

func _gen_bench() -> void:
	var total_ms: float = 0.0
	var worst_ms: float = 0.0
	var worst_level: int = 0
	var slow: Array[String] = []
	for level: int in range(1, GEN_BENCH_LAST + 1):
		var start: int = Time.get_ticks_usec()
		LevelGenerator.generate(level)
		var spent: float = float(Time.get_ticks_usec() - start) / USEC_PER_MSEC
		total_ms += spent
		if spent > worst_ms:
			worst_ms = spent
			worst_level = level
		if spent > GEN_SLOW_MSEC:
			slow.append("%d (%.0f)" % [level, spent])
	_gen_rows = {"total": total_ms, "max": worst_ms, "max_level": worst_level, "slow": slow}
	print("PERF gen 1..%d toplam=%.0f ms en_kotu=%.0f ms (L%d) >%.0fms: %s" % [GEN_BENCH_LAST, total_ms,
		worst_ms, worst_level, GEN_SLOW_MSEC, ", ".join(slow)])


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
	_render_cpu_ms.clear()
	_draw_calls.clear()
	_items.clear()
	_warm = WARMUP_FRAMES
	_taps = 0
	_path.clear()
	_current["gen_ms"] = -1.0
	_current["next_ms"] = -1.0
	_next_at_msec = 0
	var kind: String = String(_current["kind"])
	if kind == "laundromat":
		_prepare_full_laundromat()
	_open_usec = Time.get_ticks_usec()
	match kind:
		"boot":
			_scene = (load(BOOT_SCENE) as PackedScene).instantiate()
			root.add_child(_scene)
			current_scene = _scene
			_phase = "wait_boot"
			return
		"home":
			_home = (load(HOME_SCENE) as PackedScene).instantiate()
			root.add_child(_home)
			current_scene = _home
		"game":
			var level: int = int(_current["level"])
			# Üretim süresi ayrı ölçülür (sahne açılışı içindeki payı da TTI'ya girer).
			var gen_start: int = Time.get_ticks_usec()
			LevelGenerator.generate(level)
			_current["gen_ms"] = float(Time.get_ticks_usec() - gen_start) / USEC_PER_MSEC
			# Oyun sahnesi seviyeyi Progress'ten okur (yalnız bellekte; kayıt kapalı).
			if _progress != null:
				(_progress.get("data") as ProgressData).level = level
			_open_usec = Time.get_ticks_usec()
			_scene = (load(GAME_SCENE) as PackedScene).instantiate()
			_scene.set("_persist", false)
			_scene.set("_level_number", level)
			root.add_child(_scene)
			current_scene = _scene
			# Tanıtım kartları tahtayı örtmesin (yalnız bellekte "görüldü").
			var tutorial: Node = _scene.get("_tutorial") as Node
			if tutorial != null:
				var seen: Dictionary = tutorial.get("_memory_seen") as Dictionary
				for feature: Variant in TutorialFeatures.table().get("card_order", []) as Array:
					seen["tut_card_%s" % String(feature)] = true
		"laundromat", "collection":
			_home = (load(HOME_SCENE) as PackedScene).instantiate()
			root.add_child(_home)
			current_scene = _home
			var path: String = LAUNDROMAT_SCENE if kind == "laundromat" else COLLECTION_SCENE
			_overlay = (load(path) as PackedScene).instantiate()
			_home.add_child(_overlay)
			# Ana ekranın gerçek açılış yolu (varsa): arkadaki katmanların gizlenmesi de ölçülsün.
			if _home.has_method(&"_open_meta"):
				_home.call(&"_open_meta", _overlay)
	_phase = "wait_first"
	RenderingServer.frame_post_draw.connect(_on_first_frame, CONNECT_ONE_SHOT)


func _on_first_frame() -> void:
	_first_frame_usec = Time.get_ticks_usec()
	_current["tti_ms"] = float(_first_frame_usec - _open_usec) / USEC_PER_MSEC
	_phase = "sample"
	_last_usec = Time.get_ticks_usec()
	_sample_until = Time.get_ticks_msec() + STATIC_SAMPLE_MSEC
	if String(_current["kind"]) == "game":
		_path = LevelSolver.solve(_scene.get("_level") as Dictionary, SOLVE_LIMIT)
		_next_tap_msec = Time.get_ticks_msec() + TAP_EVERY_MSEC
		_play_end_msec = 0
		_sample_until = Time.get_ticks_msec() + MAX_PLAY_MSEC


func _sample(now_usec: int) -> void:
	if _warm > 0:
		_warm -= 1
		return
	var frame_ms: float = float(now_usec - _last_usec) / USEC_PER_MSEC
	_frames.append(frame_ms)
	_render_cpu_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())
		+ RenderingServer.get_frame_setup_time_cpu())
	_draw_calls.append(RenderingServer.viewport_get_render_info(root.get_viewport_rid(),
		RenderingServer.VIEWPORT_RENDER_INFO_TYPE_CANVAS, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME))
	_items.append(RenderingServer.viewport_get_render_info(root.get_viewport_rid(),
		RenderingServer.VIEWPORT_RENDER_INFO_TYPE_CANVAS, RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME))
	var now: int = Time.get_ticks_msec()
	if String(_current["kind"]) == "game":
		var board: LaundryBoard = _scene.get("_board") as LaundryBoard
		if _play_end_msec == 0 and now >= _next_tap_msec:
			if not _path.is_empty() and board != null and not board.is_over():
				_scene.call("_tap", _path.pop_front())
				_taps += 1
				_next_tap_msec = now + TAP_EVERY_MSEC
			elif not bool(_current.get("next", false)) or (board != null and not board.is_won()):
				_play_end_msec = now + AFTER_PLAY_MSEC
		if bool(_current.get("next", false)) and board != null and board.is_won() and _next_at_msec == 0 \
				and not bool(_scene.get("_playing")):
			_next_at_msec = now + WIN_SHEET_MSEC
		if _next_at_msec > 0 and now >= _next_at_msec and float(_current["next_ms"]) < 0.0:
			# "Devam": sonraki seviyenin kurulduğu karedeki takılma (eşzamanlı üretim dahil).
			var start: int = Time.get_ticks_usec()
			_scene.call("_start_level")
			_current["next_ms"] = float(Time.get_ticks_usec() - start) / USEC_PER_MSEC
			_play_end_msec = now + AFTER_PLAY_MSEC
		if _play_end_msec > 0 and now >= _play_end_msec:
			_finish_scenario()
			return
	if now >= _sample_until:
		_finish_scenario()


func _finish_scenario() -> void:
	var row: Dictionary = _current.duplicate()
	var sorted: PackedFloat32Array = _frames.duplicate()
	sorted.sort()
	row["frames"] = _frames.size()
	row["avg_ms"] = _mean(_frames)
	row["p99_ms"] = sorted[clampi(int(float(sorted.size()) * P99), 0, sorted.size() - 1)] if not sorted.is_empty() else 0.0
	row["max_ms"] = sorted[sorted.size() - 1] if not sorted.is_empty() else 0.0
	row["render_cpu_ms"] = _mean(_render_cpu_ms)
	row["draw_calls"] = _mean_int(_draw_calls)
	row["draw_calls_max"] = _max_int(_draw_calls)
	row["items"] = _mean_int(_items)
	row["vmem_mib"] = float(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)) / BYTES_PER_MIB
	row["tmem_mib"] = float(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)) / BYTES_PER_MIB
	row["static_mib"] = float(Performance.get_monitor(Performance.MEMORY_STATIC)) / BYTES_PER_MIB
	row["nodes"] = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	row["orphans"] = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	row["objects"] = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	row["taps"] = _taps
	if _scene != null and String(_current["kind"]) == "game":
		var board: LaundryBoard = _scene.get("_board") as LaundryBoard
		row["won"] = board != null and board.is_won()
	_rows.append(row)
	print("PERF %s: kare ort=%.2f p99=%.2f ms, çizim=%.1f (en çok %d), öğe=%.0f, VRAM=%.1f MiB, doku=%.1f MiB, statik=%.1f MiB, düğüm=%d, yetim=%d, TTI=%.0f ms, Devam=%.0f ms" % [
		String(row["name"]), float(row["avg_ms"]), float(row["p99_ms"]),
		float(row["draw_calls"]), int(row["draw_calls_max"]), float(row["items"]), float(row["vmem_mib"]),
		float(row["tmem_mib"]), float(row["static_mib"]), int(row["nodes"]), int(row["orphans"]), float(row["tti_ms"]), float(row["next_ms"])])
	_phase = "next"
	_wait = SETTLE_FRAMES


func _clear_scenes() -> void:
	for node: Node in [_overlay, _scene, _home]:
		if node != null and is_instance_valid(node):
			node.queue_free()
	_overlay = null
	_scene = null
	_home = null


## meta_shot "laundry_full" ile aynı durum: ilk mekânın tüm görevleri yapılmış (en çok katman).
func _prepare_full_laundromat() -> void:
	if _progress == null:
		return
	_progress.call("reset_state")
	var data: ProgressData = _progress.get("data") as ProgressData
	var catalog: MetaCatalog = MetaCatalog.load_default()
	var state: MetaState = MetaState.new()
	data.coins = 480
	data.stars = 1
	data.level = 30
	for _index: int in range(11):
		state.complete_next(catalog, 0)
	_progress.call("set_module_value", "meta", "state", state.to_dict())


# --- Rapor ------------------------------------------------------------------------------------

func _write_report() -> void:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("# Başarım ölçümü: %s" % _label)
	lines.append("")
	lines.append("- Tarih: %s" % Time.get_datetime_string_from_system())
	lines.append("- Godot: %s, işleyici: %s, ekran kartı: %s" % [Engine.get_version_info()["string"],
		RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name()])
	lines.append("- İşlemci: %s (%d çekirdek), işletim sistemi: %s" % [OS.get_processor_name(),
		OS.get_processor_count(), OS.get_name()])
	lines.append("- Pencere: %s, VSync kapalı (kare süresi = gerçek iş)." % str(root.get_visible_rect().size))
	lines.append("- NOT: masaüstü sayıları orta sınıf Android'in VEKİLİDİR; mutlak değer değil önce/sonra oranı anlamlıdır.")
	lines.append("")
	if not _rows.is_empty():
		lines.append("## Sahneler")
		lines.append("")
		lines.append("| Sahne | kare ort (ms) | kare p99 (ms) | kare en kötü (ms) | çizim CPU (ms) | 2B çizim çağrısı ort / en çok | 2B öğe | VRAM (MiB) | doku (MiB) | statik (MiB) | düğüm | yetim | ilk etkileşimli kare (ms) | üretim (ms) | Devam karesi (ms) | dokunuş |")
		lines.append("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
		for row: Dictionary in _rows:
			lines.append("| %s | %.2f | %.2f | %.1f | %.2f | %.1f / %d | %.0f | %.1f | %.1f | %.1f | %d | %d | %.0f | %s | %s | %d%s |" % [
				String(row["name"]), float(row["avg_ms"]), float(row["p99_ms"]), float(row["max_ms"]),
				float(row["render_cpu_ms"]), float(row["draw_calls"]),
				int(row["draw_calls_max"]), float(row["items"]), float(row["vmem_mib"]), float(row["tmem_mib"]),
				float(row["static_mib"]), int(row["nodes"]), int(row["orphans"]), float(row["tti_ms"]),
				"-" if float(row["gen_ms"]) < 0.0 else "%.0f" % float(row["gen_ms"]),
				"-" if float(row["next_ms"]) < 0.0 else "%.0f" % float(row["next_ms"]), int(row["taps"]),
				"" if not row.has("won") else (" (kazandı)" if bool(row["won"]) else " (bitmedi)")])
		lines.append("")
	if not _gen_rows.is_empty():
		lines.append("## LevelGenerator.generate 1..%d (ana iş parçacığında, eşzamanlı)" % GEN_BENCH_LAST)
		lines.append("")
		lines.append("- Toplam: %.0f ms" % float(_gen_rows["total"]))
		lines.append("- En kötü: %.0f ms (seviye %d)" % [float(_gen_rows["max"]), int(_gen_rows["max_level"])])
		lines.append("- %.0f ms üstü seviyeler (ms): %s" % [GEN_SLOW_MSEC, ", ".join(_gen_rows["slow"] as Array[String])])
		lines.append("")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + _out.get_base_dir()))
	var file: FileAccess = FileAccess.open("res://" + _out, FileAccess.WRITE)
	if file == null:
		push_error("perf_probe: %s yazılamadı" % _out)
		return
	file.store_string("\n".join(lines) + "\n")
	file.close()
	print("PERF rapor: %s" % _out)


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
