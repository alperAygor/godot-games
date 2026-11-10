extends SceneTree

## Faz 2 kabul testi: Boot -> Menu -> Game -> Result akisini surer, her adimda PNG alir.
## (Headless CALISMAZ — gercek pencere gerekir.)

var _plan: Array = []
var _index: int = 0
var _elapsed: float = 0.0
var _out_dir: String = "/tmp/flows"
var _done: bool = false


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out-dir="):
			_out_dir = arg.split("=")[1]
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_plan = [
		{"at": 0.20, "shot": "01_boot"},
		{"at": 0.90, "shot": "02_menu"},
		{"at": 1.10, "press": "PlayButton"},
		{"at": 1.80, "place": ["PkgIce", 0, 0]},
		{"at": 2.10, "place": ["PkgIron", 2, 2]},
		{"at": 2.40, "press": "StartButton"},
		{"at": 4.00, "shot": "03_game"},
		{"at": 9.00, "shot": "04_result"},
	]
	var packed: PackedScene = load("res://scenes/Boot.tscn")
	if packed == null:
		push_error("flow: Boot.tscn yuklenemedi")
		quit(1)
		return
	var scene: Node = packed.instantiate()
	root.add_child(scene)
	current_scene = scene


func _process(delta: float) -> bool:
	_elapsed += delta
	while _index < _plan.size() and _elapsed >= float(_plan[_index]["at"]):
		var step: Dictionary = _plan[_index]
		_index += 1
		if step.has("shot"):
			_capture(String(step["shot"]))
		elif step.has("press"):
			_press(String(step["press"]))
		elif step.has("place"):
			var args: Array = step["place"]
			_place(String(args[0]), Vector2i(int(args[1]), int(args[2])))
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
		push_error("flow: aktif sahne yok")
		return
	var node: Node = current_scene.find_child(node_name, true, false)
	if node == null:
		push_error("flow: dugum yok: " + node_name)
		return
	if node is Button:
		(node as Button).pressed.emit()


func _place(node_name: String, cell: Vector2i) -> void:
	if current_scene == null:
		return
	var pkg: Node3D = current_scene.get_node_or_null("ShakeRoot/Packages/" + node_name) as Node3D
	var camera: Camera3D = current_scene.get_node_or_null("Camera3D") as Camera3D
	var grid: Node3D = current_scene.get_node_or_null("ShakeRoot/BackpackGrid") as Node3D
	if pkg == null or camera == null or grid == null:
		push_error("flow: yerlesim icin dugum eksik (" + node_name + ")")
		return
	var start: Vector2 = camera.unproject_position(pkg.global_position)
	var target_world: Vector3 = grid.to_global(
		Vector3(-0.15 + (float(cell.x) + 0.5) * 0.075, (float(cell.y) + 0.5) * 0.075, 0.048))
	var target: Vector2 = camera.unproject_position(target_world)
	grid.call("_begin_drag", start)
	grid.call("_update_drag", start.lerp(target, 0.5))
	grid.call("_update_drag", target)
	grid.call("_end_drag", target)
