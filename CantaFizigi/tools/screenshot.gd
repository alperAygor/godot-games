extends SceneTree

## QA aracı: sahneyi açar, bir senaryo koşar ve PNG kaydeder.
## (Headless ÇALIŞMAZ — gerçek pencere gerekir; ses de bu modda gerçekten çalar.)
##
##   godot --path . -s res://tools/screenshot.gd -- --mode=fail --out=/tmp/fail.png

var _mode: String = "idle"
var _out_path: String = "/tmp/shot.png"
var _elapsed: float = 0.0
var _started: bool = false
var _finished: bool = false
var _capture_at: float = 2.4
var _wait_for: Callable = Callable()
var _wait_action: Callable = Callable()
var _wait_delay: float = 0.5
var _scene: Node = null
var _controller: Node = null
var _camera: Camera3D = null
var _actions: Array = []
## GameManager.Phase.FAILED — autoload kimliği `-s` modunda derleme anında çözülemediği
## için enum değeri burada sabit tutulur (GameManager.Phase: PACKING 0, DELIVERING 1, FAILED 2).
const PHASE_FAILED: int = 2


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out_path = a.split("=")[1]
		elif a.begins_with("--mode="):
			_mode = a.split("=")[1]
	var packed: PackedScene = load("res://scenes/Main.tscn")
	if packed == null:
		push_error("Main.tscn yüklenemedi")
		quit(1)
		return
	_scene = packed.instantiate()
	root.add_child(_scene)
	_controller = _scene.get_node("ShakeRoot/BackpackGrid")
	_camera = _scene.get_node("Camera3D")


func _process(delta: float) -> bool:
	_elapsed += delta
	if not _started and _elapsed > 0.3:
		_started = true
		_plan()

	for action: Dictionary in _actions:
		if not action["done"] and _elapsed >= float(action["at"]):
			action["done"] = true
			(action["fn"] as Callable).call()

	if _wait_for.is_valid() and _wait_for.call():
		_wait_for = Callable()
		if _wait_action.is_valid():
			var action: Callable = _wait_action
			_wait_action = Callable()
			action.call()
		_capture_at = _elapsed + _wait_delay

	if not _finished and _elapsed >= _capture_at:
		_finished = true
		var img: Image = root.get_texture().get_image()
		img.save_png(_out_path)
		print("SHOT %s %s mode=%s" % [_out_path, str(img.get_size()), _mode])
		quit(0)
	return false


func _plan() -> void:
	match _mode:
		"idle":
			pass
		"placed":
			_add(0.45, _place.bind("PkgIce", Vector2i(0, 0)))
			_add(0.75, _place.bind("PkgIron", Vector2i(2, 2)))
			_capture_at = 2.6
		"shake":
			_add(0.40, _place.bind("PkgIce", Vector2i(0, 0)))
			_add(0.65, _place.bind("PkgGlass", Vector2i(1, 2)))
			_add(0.95, _start_delivery)
			_capture_at = 2.6
		"fail":
			_add(0.40, _place.bind("PkgGlass", Vector2i(1, 1)))
			_add(0.65, _place.bind("PkgIce", Vector2i(0, 0)))
			_add(0.95, _start_delivery)
			_wait_for = func() -> bool: return _elapsed > 1.2 and _phase() == PHASE_FAILED
			_capture_at = 99.0
		"revive":
			_add(0.40, _place.bind("PkgGlass", Vector2i(1, 1)))
			_add(0.95, _start_delivery)
			_wait_for = func() -> bool: return _phase() == PHASE_FAILED
			_wait_action = _revive
			_wait_delay = 2.2
			_capture_at = 99.0
		"success":
			_add(0.40, _place.bind("PkgIce", Vector2i(0, 0)))
			_add(0.65, _place.bind("PkgIron", Vector2i(2, 2)))
			_add(0.95, _start_delivery)
			_capture_at = 7.6
		"pocket":
			_add(0.60, _extra_pocket)
			_wait_for = func() -> bool: return int(_controller.get("cols")) >= 5
			_capture_at = 99.0
		"pocket_place":
			_add(0.45, _extra_pocket)
			_add(2.20, _place.bind("PkgIce", Vector2i(4, 0)))
			_add(2.45, _place.bind("PkgSpring", Vector2i(4, 3)))
			_capture_at = 3.9
		_:
			push_warning("Bilinmeyen mod: " + _mode)


func _phase() -> int:
	var gm: Node = root.get_node_or_null("GameManager")
	if gm == null:
		return -1
	return int(gm.get("phase"))


func _add(at: float, fn: Callable) -> void:
	_actions.append({"at": at, "fn": fn, "done": false})


func _start_delivery() -> void:
	_scene.call("_on_start_pressed")


func _revive() -> void:
	_scene.call("_on_revive_pressed")


func _extra_pocket() -> void:
	_scene.call("_on_extra_pocket_pressed")


func _place(node_name: String, cell: Vector2i) -> void:
	var pkg: Node3D = _scene.get_node_or_null("ShakeRoot/Packages/" + node_name) as Node3D
	if pkg == null:
		push_error("Paket yok: " + node_name)
		return
	var start: Vector2 = _camera.unproject_position(pkg.global_position)
	var target_world: Vector3 = _controller.to_global(
		Vector3(-0.15 + (float(cell.x) + 0.5) * 0.075, (float(cell.y) + 0.5) * 0.075, 0.048))
	var target: Vector2 = _camera.unproject_position(target_world)
	_controller.call("_begin_drag", start)
	_controller.call("_update_drag", start.lerp(target, 0.5))
	_controller.call("_update_drag", target)
	_controller.call("_end_drag", target)
