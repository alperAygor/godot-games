extends SceneTree

## QA aracı: Boot -> Home -> Ayarlar -> Game -> kazanma -> kayıp -> duraklatma akışını geçer ve
## her adımda PNG alır. (Headless ÇALIŞMAZ — gerçek pencere gerekir.)
##
##   godot --path . -s res://tools/screenshot.gd -- --out-dir=build/shots --lang=tr
##
## Oyuncunun gerçek kaydına ASLA yazmaz (Progress.persist = false, ilk iş). Reklamlar anında biten
## sahte sağlayıcıyla sürülür, çevrimiçi kapısı kapalıdır.
## Gerçek pencere araçları başka bir pencere öndeyken takılabilir ve gerçek zamanda çalışır:
## yavaş ≠ asılı. Çok kare gerekiyorsa sert zaman aşımıyla (kendi PID'inizi öldürerek) çalıştırın.
## Çıktıları tek sayfada görmek için: python3 ../tools/montage.py (studio-kit).

const WATCHDOG_SECONDS: float = 90.0

var _out_dir: String = "build/shots"
var _lang: String = "tr"
var _elapsed: float = 0.0
var _finished: bool = false


class InstantProvider extends AdsProvider:
	func is_ready(_placement: int) -> bool:
		return true

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


func _run() -> void:
	# Autoload `_ready`leri bu betiğin `_initialize`inden sonra çalışır: kayıt ilk kareden sonra hazırlanır.
	await process_frame
	var progress: Node = root.get_node("Progress")
	progress.call("reset_state")
	progress.call("set_module_value", "settings", "language", _lang)
	progress.call("add_coins", 120)
	root.get_node("AdManager").call("set_provider", InstantProvider.new())
	# `-s` modunda ana sahne otomatik YÜKLENMEZ; kendimiz kurup current_scene yaparız,
	# yoksa change_scene_to_file eski sahneyi serbest bırakamaz.
	var scene: Node = (load("res://scenes/Boot.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	await _wait(0.2)
	_capture("01_boot")
	await _wait(1.4)
	_capture("02_home")
	current_scene.call("_open_settings")
	await _wait(0.9)
	_capture("03_settings")
	current_scene.call("_on_back")
	await _wait(0.5)
	_press("PlayButton")
	await _wait(1.3)
	_capture("04_game")
	_press("TapButton")
	_press("TapButton")
	await _wait(0.3)
	_capture("05_game_progress")
	for _tap: int in range(3):
		_press("TapButton")
	await _wait(2.4)
	_capture("06_win")
	current_scene.get("_overlay").emit_signal(&"continue_pressed")
	await _wait(1.0)
	# Sigorta hakları (3) bitince kayıp sayfası açılır.
	for _fuse: int in range(3):
		_press("LoseButton")
	await _wait(2.2)
	_capture("07_lose")
	current_scene.get("_overlay").emit_signal(&"retry_pressed")
	await _wait(0.6)
	current_scene.call("_on_pause_requested")
	await _wait(0.9)
	_capture("08_pause")
	_finished = true
	quit(0)


func _capture(shot_name: String) -> void:
	var image: Image = root.get_texture().get_image()
	var path: String = _out_dir.path_join(shot_name + ".png")
	image.save_png(path)
	print("SHOT %s" % path)


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
