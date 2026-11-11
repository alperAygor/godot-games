extends SceneTree

## Performans ölçüm aracı (ARCHITECTURE §14).
##
## Menü + oyun (bölüm 12) + 5 sn sürekli drag sırasında kare süresini örnekler;
## avg/p50/p95/p99/max, FPS, draw call (RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
## nesne/primitive sayısı raporlar ve JSON yazar.
##
##   godot --path . -s res://tools/perf_probe.gd -- --out=/tmp/perf.json
##
## Headless ÇALIŞMAZ: kare süresi gerçek pencerede ölçülür. V-Sync kapatılır ve
## max_fps sıfırlanır; böylece kare süresi iş yükünü ölçer, ekran tazeleme hızını değil.
## Hedef: p95 < 16.7 ms (60 fps bütçesi).
##
## Çıkış kodu: 0 = ölçüm tamamlandı (rapor PASS/FAIL der), 1 = kurulum hatası.

const MENU_SCENE: String = "res://scenes/Menu.tscn"
const GAME_SCENE: String = "res://scenes/Game.tscn"
## Kabul ölçümü bölüm 12'de (7 kablo, en ağır sahne) yapılır.
const LEVEL: int = 12
const TARGET_MS: float = 16.7
const WARMUP_SECONDS: float = 0.9
const SAMPLE_SECONDS: float = 2.0
const INTRO_SETTLE_SECONDS: float = 1.6
const DRAG_SECONDS: float = 5.0
const DRAG_SETTLE_SECONDS: float = 0.6
## Drag sırasında sigorta atarsa ölçüm kesilmesin diye kalkan verilir (QA enjeksiyonu).
const DRAG_SHIELD_SECONDS: float = 90.0
const DRAG_WORLD_RADIUS: Vector2 = Vector2(0.42, 0.34)
const DEADLINE_SECONDS: float = 90.0
## Bu esikten uzun kareler "hitch" sayilir ve en kotu 5 kare raporlanir.
const HITCH_MS: float = 25.0
## A/B: backdrop kapaliyken ayni oyun sahnesini de ornekle (backdrop maliyeti).
const ENABLE_BACKDROP_AB: bool = true

enum Phase { LOAD_MENU, MENU_WARM, MENU_SAMPLE, LOAD_GAME, GAME_WARM, GAME_SAMPLE,
	GAME_NO_BACKDROP, DRAG, SETTLE, REPORT, DONE }

var _phase: int = Phase.LOAD_MENU
var _phase_elapsed: float = 0.0
var _elapsed: float = 0.0
var _done: bool = false
var _out_path: String = "/tmp/perf.json"

var _menu: Node = null
var _game: Node = null
var _result: Dictionary = {}
var _skips: Array[String] = []
var _warnings: Array[String] = []

var _collect_name: String = ""
var _phase_frame: int = 0
var _worst_frames: Array[Dictionary] = []
var _preload_audio: bool = false
var _collect_ms: PackedFloat64Array = PackedFloat64Array()
var _collect_draw: PackedInt32Array = PackedInt32Array()
var _collect_prim: PackedInt32Array = PackedInt32Array()
var _collect_obj: PackedInt32Array = PackedInt32Array()

var _drag_active: bool = false
var _drag_angle: float = 0.0
var _drag_center: Vector2 = Vector2.ZERO
var _drag_camera: Camera3D = null
var _drag_lift: float = 0.3
var _drag_last: Vector2 = Vector2.ZERO
var _drag_cable: int = -1
var _window_size: Vector2i = Vector2i.ZERO


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_path = arg.trim_prefix("--out=")
		elif arg == "--preload-audio":
			_preload_audio = true
	if DisplayServer.get_name() == "headless":
		printerr("PERF FAIL: headless modda kare süresi ölçülemez; gerçek pencere gerekir")
		quit(1)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	DisplayServer.window_move_to_foreground()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_window_size = DisplayServer.window_get_size()
	print("PERF probe: window=%dx%d renderer=%s vsync=off"
		% [_window_size.x, _window_size.y, RenderingServer.get_current_rendering_method()])


func _process(delta: float) -> bool:
	if _done:
		return true
	_elapsed += delta
	_phase_elapsed += delta
	if _elapsed > DEADLINE_SECONDS:
		_warn("genel zaman aşımı (%.1f sn), faz=%d" % [DEADLINE_SECONDS, _phase])
		_finish(1)
		return true
	match _phase:
		Phase.LOAD_MENU:
			_step_load_menu()
		Phase.MENU_WARM:
			if _phase_elapsed >= WARMUP_SECONDS:
				_begin_collect("menu")
				_go(Phase.MENU_SAMPLE)
		Phase.MENU_SAMPLE:
			_record_frame(delta)
			if _phase_elapsed >= SAMPLE_SECONDS:
				_end_collect()
				_go(Phase.LOAD_GAME)
		Phase.LOAD_GAME:
			_step_load_game()
		Phase.GAME_WARM:
			if _phase_elapsed >= INTRO_SETTLE_SECONDS:
				if _preload_audio:
					_preload_sounds()
				_begin_collect("game")
				_go(Phase.GAME_SAMPLE)
		Phase.GAME_SAMPLE:
			_record_frame(delta)
			if _phase_elapsed >= SAMPLE_SECONDS:
				_end_collect()
				if ENABLE_BACKDROP_AB:
					_set_backdrop_visible(false)
					_begin_collect("game_nobackdrop")
					_go(Phase.GAME_NO_BACKDROP)
				else:
					_go(Phase.DRAG)
		Phase.GAME_NO_BACKDROP:
			_record_frame(delta)
			if _phase_elapsed >= SAMPLE_SECONDS:
				_end_collect()
				_set_backdrop_visible(true)
				_go(Phase.DRAG)
		Phase.DRAG:
			_record_frame(delta)
			_step_drag(delta)
		Phase.SETTLE:
			if _phase_elapsed >= DRAG_SETTLE_SECONDS:
				_go(Phase.REPORT)
		Phase.REPORT:
			_finish(0)
			return true
		_:
			return true
	return false


# --- fazlar ---------------------------------------------------------------

func _step_load_menu() -> void:
	if _phase_elapsed < 0.1:
		return
	var packed: PackedScene = load(MENU_SCENE) as PackedScene
	if packed == null:
		_skip("menu: %s yüklenemedi" % MENU_SCENE)
		_go(Phase.LOAD_GAME)
		return
	_menu = packed.instantiate()
	if _menu == null:
		_skip("menu: sahne örneklenemedi")
		_go(Phase.LOAD_GAME)
		return
	root.add_child(_menu)
	current_scene = _menu
	print("PERF menu yüklendi")
	_go(Phase.MENU_WARM)


func _step_load_game() -> void:
	if _phase_elapsed < 0.1:
		return
	if _menu != null and is_instance_valid(_menu):
		current_scene = null
		root.remove_child(_menu)
		_menu.free()
		_menu = null
	var manager: Node = root.get_node_or_null("GameManager")
	if manager == null:
		_skip("game: GameManager autoload yok")
		_go(Phase.REPORT)
		return
	manager.set("level_index", LEVEL)
	var packed: PackedScene = load(GAME_SCENE) as PackedScene
	if packed == null:
		_skip("game: %s yüklenemedi" % GAME_SCENE)
		_go(Phase.REPORT)
		return
	_game = packed.instantiate()
	if _game == null:
		_skip("game: sahne örneklenemedi")
		_go(Phase.REPORT)
		return
	root.add_child(_game)
	current_scene = _game
	print("PERF game yüklendi (bölüm %d)" % LEVEL)
	_go(Phase.GAME_WARM)


func _step_drag(delta: float) -> void:
	if not _drag_active:
		_drag_begin()
		if not _drag_active:
			_skip("drag: sürüklenecek kablo bulunamadı")
			_end_collect()
			_go(Phase.REPORT)
			return
	_drag_angle += delta * 1.9
	var world: Vector3 = Vector3(
		_drag_center.x + sin(_drag_angle) * DRAG_WORLD_RADIUS.x,
		_drag_center.y + cos(_drag_angle * 0.77) * DRAG_WORLD_RADIUS.y,
		_drag_lift)
	var target: Vector2 = _input_position(_drag_camera.unproject_position(world))
	_send_drag(target, target - _drag_last)
	_drag_last = target
	if _phase_elapsed >= DRAG_SECONDS:
		_send_touch(false, target)
		_drag_active = false
		_end_collect()
		_go(Phase.SETTLE)


# --- drag ----------------------------------------------------------------

func _drag_begin() -> void:
	if _game == null or not is_instance_valid(_game):
		return
	_drag_camera = _game.get_node_or_null("CameraRig/Camera3D") as Camera3D
	if _drag_camera == null:
		return
	var level: Variant = _game.get("_level")
	if not (level is Object):
		return
	# Ölçüm sürsün diye kalkan: sigorta atarsa giriş kapanır ve iş yükü düşer.
	if (level as Object).has_method("apply_shield"):
		(level as Object).call("apply_shield", DRAG_SHIELD_SECONDS)
	var input_node: Variant = _game.get("_input")
	if input_node is Object:
		var plane_value: Variant = (input_node as Object).get("_drag_plane")
		if plane_value is Plane:
			_drag_lift = (plane_value as Plane).d
	var cables_variant: Variant = (level as Object).get("cables")
	if not (cables_variant is Array):
		return
	var cables: Array = cables_variant as Array
	var chosen: Object = null
	for i: int in cables.size():
		var cable_variant: Variant = cables[i]
		if not (cable_variant is Object):
			continue
		var cable: Object = cable_variant as Object
		if bool(cable.call("is_linked")) or not bool(cable.call("is_grabbable")):
			continue
		chosen = cable
		_drag_cable = i
		break
	if chosen == null:
		return
	var plug: Vector3 = chosen.call("plug_position")
	_drag_center = Vector2(plug.x, plug.y)
	var start: Vector2 = _input_position(
		_drag_camera.unproject_position(Vector3(plug.x, plug.y, _drag_lift)))
	_send_touch(true, start)
	_drag_last = start
	_drag_active = true
	_begin_collect("drag")
	print("PERF drag başladı cable=%d start=%s" % [_drag_cable, str(start)])


func _input_position(viewport_position: Vector2) -> Vector2:
	var viewport_size: Vector2 = root.get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return viewport_position
	var window_size: Vector2 = Vector2(DisplayServer.window_get_size())
	return viewport_position * (window_size / viewport_size)


func _send_touch(pressed: bool, position: Vector2) -> void:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = 0
	event.pressed = pressed
	event.position = position
	Input.parse_input_event(event)


func _send_drag(position: Vector2, relative: Vector2) -> void:
	var event: InputEventScreenDrag = InputEventScreenDrag.new()
	event.index = 0
	event.position = position
	event.relative = relative
	Input.parse_input_event(event)


# --- ölçüm ----------------------------------------------------------------

func _begin_collect(name: String) -> void:
	_collect_name = name
	_phase_frame = 0
	_worst_frames.clear()
	_collect_ms = PackedFloat64Array()
	_collect_draw = PackedInt32Array()
	_collect_prim = PackedInt32Array()
	_collect_obj = PackedInt32Array()


## Sahne eklendikten sonra backdrop'u gorunur/gorunmez yapar (A/B olcumu).
func _set_backdrop_visible(on: bool) -> void:
	if _game == null or not is_instance_valid(_game):
		return
	var backdrop: Node = _game.get_node_or_null("Backdrop")
	if backdrop == null:
		return
	(backdrop as Node3D).visible = on
	backdrop.set_process(on)


func _record_frame(delta: float) -> void:
	var milliseconds: float = delta * 1000.0
	_phase_frame += 1
	# macOS pencereyi arka planda tutarsa çizim duraklıyor ve monitörler bayat
	# kalıyor; ölçüm boyunca pencereyi önde tut (20 karede bir, maliyetsiz).
	if (_phase_frame % 20) == 0:
		DisplayServer.window_move_to_foreground()
	_collect_ms.append(milliseconds)
	_collect_draw.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	_collect_prim.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
	_collect_obj.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)))
	if milliseconds >= HITCH_MS:
		_worst_frames.append({
			"ms": _round3(milliseconds),
			"at_s": _round3(_phase_elapsed),
			"frame": _phase_frame,
			"draws": _collect_draw[_collect_draw.size() - 1],
		})


func _end_collect() -> void:
	if _collect_name == "" or _collect_ms.is_empty():
		_collect_name = ""
		return
	var sorted_ms: PackedFloat64Array = _collect_ms.duplicate()
	sorted_ms.sort()
	var count: int = sorted_ms.size()
	var total: float = 0.0
	var jank: int = 0
	for value: float in sorted_ms:
		total += value
		if value > TARGET_MS:
			jank += 1
	var average: float = total / float(count)
	_worst_frames.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["ms"]) > float(b["ms"]))
	var worst_top: Array[Dictionary] = []
	for i: int in mini(5, _worst_frames.size()):
		worst_top.append(_worst_frames[i])
	var stats: Dictionary = {
		"frames": count,
		"avg_ms": _round3(average),
		"min_fps": _round3(1000.0 / maxf(sorted_ms[count - 1], 0.0001)),
		"hitches": _worst_frames.size(),
		"worst_frames": worst_top,
		"p50_ms": _round3(_percentile(sorted_ms, 0.50)),
		"p95_ms": _round3(_percentile(sorted_ms, 0.95)),
		"p99_ms": _round3(_percentile(sorted_ms, 0.99)),
		"max_ms": _round3(sorted_ms[count - 1]),
		"fps": _round3(1000.0 / maxf(average, 0.0001)),
		"jank_frames": jank,
		"jank_pct": _round3(100.0 * float(jank) / float(count)),
		"draw_calls_avg": _int_mean(_collect_draw),
		"draw_calls_max": _int_max(_collect_draw),
		"primitives_avg": _int_mean(_collect_prim),
		"objects_avg": _int_mean(_collect_obj),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"objects_total": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
	}
	_result[_collect_name] = stats
	print("PERF %-14s frames=%d avg=%.2fms p95=%.2fms p99=%.2fms max=%.2fms fps=%.1f min_fps=%.1f draw=%d/%d prim=%d nodes=%d hitches=%d"
		% [_collect_name, count, average, float(stats["p95_ms"]), float(stats["p99_ms"]),
			float(stats["max_ms"]), float(stats["fps"]), float(stats["min_fps"]),
			int(stats["draw_calls_avg"]), int(stats["draw_calls_max"]),
			int(stats["primitives_avg"]), int(stats["nodes"]), _worst_frames.size()])
	for entry: Dictionary in worst_top:
		print("PERF   hitch %.1fms at %.2fs frame=%d draws=%d"
			% [float(entry["ms"]), float(entry["at_s"]), int(entry["frame"]), int(entry["draws"])])
	_collect_name = ""


func _percentile(sorted_values: PackedFloat64Array, fraction: float) -> float:
	var count: int = sorted_values.size()
	if count <= 0:
		return 0.0
	var index: int = int(ceil(fraction * float(count))) - 1
	return sorted_values[clampi(index, 0, count - 1)]


func _int_mean(values: PackedInt32Array) -> int:
	if values.is_empty():
		return 0
	var total: int = 0
	for value: int in values:
		total += value
	return int(round(float(total) / float(values.size())))


func _int_max(values: PackedInt32Array) -> int:
	var best: int = 0
	for value: int in values:
		best = maxi(best, value)
	return best


func _round3(value: float) -> float:
	return snappedf(value, 0.001)


# --- rapor ----------------------------------------------------------------

func _finish(code: int) -> void:
	if _done:
		return
	_done = true
	_check_stale_render()
	_result["meta"] = {
		"tool": "perf_probe",
		"level": LEVEL,
		"window": [_window_size.x, _window_size.y],
		"renderer": RenderingServer.get_current_rendering_method(),
		"vsync": "disabled",
		"target_p95_ms": TARGET_MS,
		"gpu": RenderingServer.get_video_adapter_name(),
		"vendor": RenderingServer.get_video_adapter_vendor(),
		"engine": String(Engine.get_version_info().get("string", "")),
		"timestamp": Time.get_datetime_string_from_system(),
		"skips": _skips,
		"warnings": _warnings,
	}
	var summary: Dictionary = _summarize()
	_result["summary"] = summary
	var json_text: String = JSON.stringify(_result, "  ")
	_write_text(_out_path, json_text)
	var build_dir: String = ProjectSettings.globalize_path("res://build")
	DirAccess.make_dir_recursive_absolute(build_dir)
	_write_text(build_dir.path_join("perf.json"), json_text)
	print("PERF summary: worst_p95=%.2fms target=%.2fms -> %s"
		% [float(summary.get("worst_p95_ms", 0.0)), TARGET_MS, String(summary.get("verdict", "?"))])
	for skip: String in _skips:
		print("PERF SKIP: %s" % skip)
	for warning: String in _warnings:
		print("PERF WARN: %s" % warning)
	print("PERF json: %s" % _out_path)
	quit(code)


## Ses ilk çalınışta disken yüklenmesin (hitch kaynağı) diye tüm efektleri
## ResourceLoader önbelleğine alır. --preload-audio ile açılır (A/B kanıtı).
func _preload_sounds() -> void:
	var table: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/sounds.json"))
	if not (table is Dictionary):
		return
	for sound_name: Variant in (table as Dictionary).keys():
		var path: String = String((table as Dictionary)[sound_name])
		if ResourceLoader.exists(path):
			load(path)


## macOS pencere önde değilken çizim durabiliyor: monitörler önceki sahnenin
## değerlerinde donar (draw call'lar menüyle birebir aynı görünür). Bunu yakala.
func _check_stale_render() -> void:
	if not _result.has("menu") or not _result.has("game"):
		return
	var menu_draw: int = int((_result["menu"] as Dictionary).get("draw_calls_avg", -1))
	var game_draw: int = int((_result["game"] as Dictionary).get("draw_calls_avg", -2))
	if menu_draw != game_draw:
		return
	_warn("RENDER BAYAT: menü ve oyun draw call ortalaması aynı (%d) — pencere önde değil ya da çizim durdu; ölçümü tekrarla." % menu_draw)


func _summarize() -> Dictionary:
	var measured: Array[String] = []
	var worst: float = 0.0
	var worst_name: String = ""
	for phase_name: String in ["menu", "game", "drag"]:
		if not _result.has(phase_name):
			continue
		var stats: Dictionary = _result[phase_name] as Dictionary
		measured.append(phase_name)
		var p95: float = float(stats.get("p95_ms", 0.0))
		if p95 > worst:
			worst = p95
			worst_name = phase_name
	var verdict: String = "SKIP"
	if not measured.is_empty():
		verdict = "PASS" if worst < TARGET_MS else "FAIL"
	return {
		"measured": measured,
		"worst_p95_ms": _round3(worst),
		"worst_phase": worst_name,
		"verdict": verdict,
	}


func _write_text(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_warn("yazılamadı: %s (%d)" % [path, FileAccess.get_open_error()])
		return
	file.store_string(text)
	file.close()


func _go(next: int) -> void:
	_phase = next
	_phase_elapsed = 0.0


func _skip(message: String) -> void:
	_skips.append(message)


func _warn(message: String) -> void:
	_warnings.append(message)
