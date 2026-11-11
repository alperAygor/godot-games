extends SceneTree

## QA aracı: Boot -> Menu -> Game -> Result akışını geçer ve her adımda PNG alır.
## (Headless ÇALIŞMAZ — gerçek pencere gerekir.)
##
##   godot --path . -s res://tools/screenshot.gd -- --out-dir=/tmp/shots

var _plan: Array = []
var _index: int = 0
var _elapsed: float = 0.0
var _out_dir: String = "/tmp/shots"
var _done: bool = false


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out-dir="):
			_out_dir = arg.split("=")[1]
	DirAccess.make_dir_recursive_absolute(_out_dir)
	# `-s` modunda ana sahne otomatik YÜKLENMEZ; kendimiz kurup current_scene yaparız,
	# yoksa change_scene_to_file eski sahneyi serbest bırakamaz.
	var packed: PackedScene = load("res://scenes/Boot.tscn")
	if packed == null:
		push_error("screenshot: Boot.tscn yüklenemedi")
		quit(1)
		return
	var scene: Node = packed.instantiate()
	root.add_child(scene)
	current_scene = scene
	_plan = [
		{"at": 0.20, "shot": "01_boot"},
		{"at": 0.80, "shot": "02_menu"},
		{"at": 1.00, "press": "PlayButton"},
		{"at": 1.70, "shot": "03_game"},
		{"at": 1.90, "press": "SuccessButton"},
		{"at": 2.60, "shot": "04_result"},
		{"at": 2.90, "shot": "05_result"},
	]


func _process(delta: float) -> bool:
	_elapsed += delta
	while _index < _plan.size() and _elapsed >= float(_plan[_index]["at"]):
		var step: Dictionary = _plan[_index]
		_index += 1
		if step.has("press"):
			_press(String(step["press"]))
		elif step.has("shot"):
			_capture(String(step["shot"]))
	if not _done and _index >= _plan.size():
		_done = true
		quit(0)
	return false


func _capture(name: String) -> void:
	var image: Image = root.get_texture().get_image()
	var path: String = _out_dir.path_join(name + ".png")
	image.save_png(path)
	print("SHOT %s" % path)


func _press(node_name: String) -> void:
	if current_scene == null:
		push_error("screenshot: aktif sahne yok")
		return
	var node: Node = current_scene.find_child(node_name, true, false)
	if node == null:
		push_error("screenshot: düğüm bulunamadı: " + node_name)
		return
	if node is Button:
		(node as Button).pressed.emit()
