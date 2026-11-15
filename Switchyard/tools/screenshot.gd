extends SceneTree

## QA aracı: Ana ekran, seviye haritası, oyun (ilk 3 seviyede ve ipucu/atla görünen), sonuç sayfası, atlama onayı,
## ayarlar, duraklatma ve "reklam yok" bildirimini gezer, her adımda PNG alır. (Headless ÇALIŞMAZ — gerçek pencere gerekir.)
##
##   godot --path . -s res://tools/screenshot.gd -- --out-dir=build/shots/shell --lang=en --size=540x1200 --tag=tall
##
## Oyuncunun gerçek kaydına ASLA yazmaz (Progress.persist = false, ilk iş). Reklamlar anında biten sahte sağlayıcıyla
## sürülür, çevrimiçi kapısı kapalıdır. Seviye dizini yerine sentetik bir katalog (24 seviye, 4 dünya) kullanılır:
## harita kaydırma ve çok dünyalı görünüm denenir. `--size=GENxYUK` pencere boyudur (tarama oranı telefonu taklit eder):
## 540x1200 uzun (20:9), 540x960 kısa (16:9).
## Gerçek pencere araçları başka bir pencere öndeyken takılabilir ve gerçek zamanda çalışır: yavaş ≠ asılı.

const WATCHDOG_SECONDS: float = 120.0
const LEVEL_COUNT: int = 24
const WORLD_SIZE: int = 6
const PAR_BASE: int = 3
const PAR_SPREAD: int = 5
## Haritada görünecek ilerleme: yıldız sayıları (0 = atlandı), ardından şimdiki seviye.
const PROGRESS_STARS: Array[int] = [3, 3, 2, 3, 1, 0, 3, 2]
const PLAY_LEVEL: int = 9
const EARLY_LEVEL: int = 2

var _out_dir: String = "build/shots/shell"
var _lang: String = "en"
var _tag: String = ""
var _window_size: Vector2i = Vector2i(540, 1200)
var _elapsed: float = 0.0
var _finished: bool = false
var _provider: ShotProvider = null


class ShotProvider extends AdsProvider:
	var ready: bool = true

	func is_ready(_placement: int) -> bool:
		return ready

	func show(placement: int) -> void:
		shown.emit()
		if placement == INTERSTITIAL_PLACEMENT:
			dismissed.emit()
		else:
			rewarded.emit()


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out-dir="):
			_out_dir = arg.split("=")[1]
		elif arg.begins_with("--lang="):
			_lang = arg.split("=")[1]
		elif arg.begins_with("--tag="):
			_tag = arg.split("=")[1]
		elif arg.begins_with("--size="):
			var parts: PackedStringArray = arg.split("=")[1].split("x")
			if parts.size() == 2:
				_window_size = Vector2i(int(parts[0]), int(parts[1]))
	DirAccess.make_dir_recursive_absolute(_out_dir)
	root.get_node("Progress").set("persist", false)
	AnalyticsLog.echo = false
	OnlineGate.enabled = false
	_run()


func _process(delta: float) -> bool:
	_elapsed += delta
	if not _finished and _elapsed > WATCHDOG_SECONDS:
		printerr("screenshot: zaman aşımı")
		_finished = true
		quit(1)
	return false


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _install_catalog() -> void:
	var entries: Array[Dictionary] = []
	for index: int in LEVEL_COUNT:
		entries.append({"id": "shot-%02d" % (index + 1), "world": 1 + index / WORLD_SIZE,
			"par": PAR_BASE + (index + 1) % PAR_SPREAD, "difficulty": 1})
	LevelCatalog._entries = entries
	LevelCatalog._loaded = true


func _run() -> void:
	# Autoload `_ready`leri bu betiğin `_initialize`inden sonra çalışır: kayıt ilk kareden sonra hazırlanır.
	await process_frame
	root.size = _window_size
	await _wait(0.3)
	var progress: Node = root.get_node("Progress")
	progress.call("reset_state")
	Loc.set_language(_lang)
	_install_catalog()
	var done: LevelProgress = LevelProgress.new()
	for index: int in PROGRESS_STARS.size():
		var level_id: String = "shot-%02d" % (index + 1)
		var par: int = PAR_BASE + (index + 1) % PAR_SPREAD
		if PROGRESS_STARS[index] == 0:
			done.record_skip(level_id)
		else:
			done.record_solve(level_id, _moves_for(par, PROGRESS_STARS[index]), par, 0)
		done.save(level_id)
	_provider = ShotProvider.new()
	root.get_node("AdManager").call("set_provider", _provider)
	IapService.ensure(self)
	await process_frame

	await _show_scene("res://scenes/Home.tscn", 0.9)
	_capture("01_home")
	current_scene.call("_open_settings")
	await _wait(0.9)
	_capture("02_settings")
	current_scene.call("_on_back")
	await _wait(0.4)
	await _show_scene("res://scenes/Map.tscn", 1.0)
	_capture("03_map")
	_scroll_map_to_top()
	await _wait(0.3)
	_capture("04_map_top")

	await _open_game(PLAY_LEVEL)
	_capture("05_game_empty")
	_tap_session(2)
	await _wait(0.4)
	_capture("06_game_moves")
	_press("SkipButton")
	await _wait(0.9)
	_capture("07_skip_sheet")
	current_scene.get("_skip_sheet").call("close")
	await _wait(0.5)
	_provider.ready = false
	_press("HintButton")
	await _wait(0.5)
	_capture("08_toast")
	_provider.ready = true
	await _wait(2.8)
	current_scene.call("_on_pause_requested")
	await _wait(0.9)
	_capture("09_pause")
	current_scene.get("_pause").call("close")
	await _wait(0.6)
	# Sonuç: par'ın bir üstünde çözülür (2 yıldız).
	var par_now: int = PAR_BASE + PLAY_LEVEL % PAR_SPREAD
	_tap_session(maxi(par_now + 1 - 2, 1), par_now + 1)
	await _wait(2.4)
	_capture("10_result")

	await _open_game(EARLY_LEVEL)
	_tap_session(1, 99)
	await _wait(0.4)
	_capture("11_game_early")
	_finished = true
	quit(0)


## Hedef yıldız için hamle sayısı (3 = par, 2 = ceil(par x 1,5), 1 = bir fazlası).
func _moves_for(par: int, stars: int) -> int:
	if stars >= 3:
		return par
	var two_star: int = (par * 3 + 1) / 2
	return two_star if stars == 2 else two_star + 1


func _show_scene(path: String, wait_seconds: float) -> void:
	if current_scene != null:
		current_scene.free()
	var scene: Node = (load(path) as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	await _wait(wait_seconds)


func _open_game(number: int) -> void:
	root.get_node("GameManager").set("selected_level_id", "shot-%02d" % number)
	await _show_scene("res://scenes/Game.tscn", 1.0)


## Sahte sahada `count` dokunuş yapar; `solve_at` verilirse çözüm eşiği o olur.
func _tap_session(count: int, solve_at: int = 0) -> void:
	var session: Control = current_scene.get("_session") as Control
	if solve_at > 0:
		session.set("solve_at", solve_at)
	for _tap: int in range(count):
		session.call("tap")


func _scroll_map_to_top() -> void:
	var scroll: ScrollContainer = current_scene.find_child("Scroll", true, false) as ScrollContainer
	if scroll != null:
		scroll.scroll_vertical = 0


func _capture(shot_name: String) -> void:
	# Pencere başka bir pencerenin arkasında kalırsa macOS çizimi durdurur: kareyi elle zorla.
	RenderingServer.force_draw(false)
	var image: Image = root.get_texture().get_image()
	var file_name: String = "%s_%s_%s.png" % [shot_name, _lang, _tag] if not _tag.is_empty() else "%s_%s.png" % [shot_name, _lang]
	var path: String = _out_dir.path_join(file_name)
	image.save_png(path)
	print("SHOT %s (%dx%d) scene=%s frame=%d" % [path, image.get_width(), image.get_height(),
		current_scene.name if current_scene != null else "-", Engine.get_frames_drawn()])


func _press(node_name: String) -> void:
	if current_scene == null:
		printerr("screenshot: aktif sahne yok")
		return
	var node: Node = current_scene.find_child(node_name, true, false)
	if node == null:
		printerr("screenshot: düğüm bulunamadı: " + node_name)
		return
	if node is Button:
		(node as Button).pressed.emit()
