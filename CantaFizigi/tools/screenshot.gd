extends SceneTree

## QA aracı: sahneyi açar, istenirse sürükleme senaryosu uygular ve PNG kaydeder.
## Kullanım (headless DEĞİL, gerçek pencere gerekir):
##   godot --path . -s res://tools/screenshot.gd -- --out=/tmp/shot.png --mode=idle --frames=30

var _frames: int = 30
var _out_path: String = "/tmp/shot.png"
var _mode: String = "idle"
var _tweaks: PackedStringArray = PackedStringArray()
var _elapsed: float = 0.0
var _script_done: bool = false
var _controller: Node = null
var _camera: Camera3D = null


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--frames="):
			_frames = int(a.split("=")[1])
		elif a.begins_with("--out="):
			_out_path = a.split("=")[1]
		elif a.begins_with("--mode="):
			_mode = a.split("=")[1]
		elif a.begins_with("--tweak="):
			_tweaks = a.split("=")[1].split(",")
	var packed: PackedScene = load("res://scenes/Main.tscn")
	if packed == null:
		push_error("Main.tscn yüklenemedi")
		quit(1)
		return
	var scene: Node = packed.instantiate()
	root.add_child(scene)
	_controller = scene.get_node("BackpackGrid")
	_camera = scene.get_node("Camera3D")


func _process(delta: float) -> bool:
	_elapsed += delta
	if _frames <= 0:
		return false
	if not _script_done and _elapsed > 0.2:
		_script_done = true
		_apply_tweaks()
		_run_scenario()
	if _elapsed > 2.4:
		var img: Image = root.get_texture().get_image()
		img.save_png(_out_path)
		print("SHOT %s %s mode=%s" % [_out_path, str(img.get_size()), _mode])
		quit(0)
	return false


func _apply_tweaks() -> void:
	var scene: Node = root.get_child(root.get_child_count() - 1)
	var world: WorldEnvironment = scene.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world == null or world.environment == null:
		return
	var env: Environment = world.environment
	for t: String in _tweaks:
		match t:
			"nolut":
				env.adjustment_color_correction = null
			"noadjust":
				env.adjustment_enabled = false
			"noglow":
				env.glow_enabled = false
			"nossao":
				env.ssao_enabled = false
			"sat0":
				env.adjustment_saturation = 0.0
			"gray":
				env.adjustment_saturation = 0.0
			_:
				push_warning("Bilinmeyen tweak: " + t)


func _run_scenario() -> void:
	if _mode == "idle" or _controller == null or _camera == null:
		return
	var scene: Node = root.get_child(root.get_child_count() - 1)
	if _mode == "placed":
		_drag_package(scene, "PkgIce", Vector2i(0, 0))
		_drag_package(scene, "PkgIron", Vector2i(2, 2))
	elif _mode == "drag":
		_drag_package(scene, "PkgGlass", Vector2i(1, 2), true)
	elif _mode == "full":
		_drag_package(scene, "PkgIron", Vector2i(0, 0))
		_drag_package(scene, "PkgIce", Vector2i(0, 0), true)


func _screen_of(world: Vector3) -> Vector2:
	return _camera.unproject_position(world)


func _drag_package(scene: Node, node_name: String, cell: Vector2i, hold: bool = false) -> void:
	var pkg: Node3D = scene.get_node_or_null("Packages/" + node_name) as Node3D
	if pkg == null:
		push_error("Paket yok: " + node_name)
		return
	var start: Vector2 = _screen_of(pkg.global_position)
	# hücrenin MERKEZİ hedeflenir; kenar hedeflemek float32 yuvarlamasında
	# komşu hücreye düşebilir (test aracı tuzağı).
	var target_world: Vector3 = _controller.to_global(
		Vector3(-0.15 + (float(cell.x) + 0.5) * 0.075, (float(cell.y) + 0.5) * 0.075, 0.048))
	var target: Vector2 = _screen_of(target_world)
	_controller.call("_begin_drag", start)
	_controller.call("_update_drag", start.lerp(target, 0.5))
	_controller.call("_update_drag", target)
	if not hold:
		_controller.call("_end_drag", target)
