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
		{"at": 9.30, "press": "MenuButton"},
		{"at": 9.90, "shot": "05_menu_after"},
		{"at": 10.10, "press": "UpgradesButton"},
		{"at": 10.70, "shot": "06_upgrades"},
	]
	var packed: PackedScene = load("res://scenes/Boot.tscn")
	if packed == null:
		push_error("flow: Boot.tscn yuklenemedi")
		quit(1)
		return
	var scene: Node = packed.instantiate()
	root.add_child(scene)
	current_scene = scene


## Sabit zamanlama yerine kosul bekleme: sahne gecisi gecikirse adim ertelenir.
## Boylece arac makine hizina gore kararsizlasmaz.
func _process(delta: float) -> bool:
	_elapsed += delta
	while _index < _plan.size():
		var step: Dictionary = _plan[_index]
		var due: float = float(step["at"])
		if _elapsed < due:
			break
		if step.has("shot"):
			_capture(String(step["shot"]))
			_index += 1
			continue
		var ready_ok: bool = true
		if step.has("press"):
			ready_ok = _press(String(step["press"]))
		elif step.has("place"):
			var args: Array = step["place"]
			ready_ok = _place(String(args[0]), Vector2i(int(args[1]), int(args[2])))
		if ready_ok:
			_index += 1
			continue
		# Henuz hazir degil: son tarihe kadar sonraki karede tekrar dene.
		if _elapsed > due + 4.0:
			push_error("flow: adim zaman asimi (%s)" % str(step))
			_index += 1
			continue
		break
	if not _done and _index >= _plan.size():
		_done = true
		quit(0)
	return false


func _capture(name: String) -> void:
	var image: Image = root.get_texture().get_image()
	var path: String = _out_dir.path_join(name + ".png")
	image.save_png(path)
	print("SHOT %s" % path)


func _press(node_name: String) -> bool:
	if current_scene == null:
		return false
	var node: Node = current_scene.find_child(node_name, true, false)
	if node == null:
		return false
	if not (node is Button):
		push_error("flow: dugum buton degil: " + node_name)
		return true
	(node as Button).pressed.emit()
	return true


func _place(node_name: String, cell: Vector2i) -> bool:
	if current_scene == null:
		return false
	var pkg: Node3D = current_scene.get_node_or_null("ShakeRoot/Packages/" + node_name) as Node3D
	var camera: Camera3D = current_scene.get_node_or_null("Camera3D") as Camera3D
	var grid: Node3D = current_scene.get_node_or_null("ShakeRoot/BackpackGrid") as Node3D
	if pkg == null or camera == null or grid == null:
		return false
	var start: Vector2 = camera.unproject_position(pkg.global_position)
	var target_world: Vector3 = grid.to_global(
		Vector3(-0.15 + (float(cell.x) + 0.5) * 0.075, (float(cell.y) + 0.5) * 0.075, 0.048))
	var target: Vector2 = camera.unproject_position(target_world)
	grid.call("_begin_drag", start)
	grid.call("_update_drag", start.lerp(target, 0.5))
	grid.call("_update_drag", target)
	grid.call("_end_drag", target)
	return true
