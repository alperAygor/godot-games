extends SceneTree
## Ekran görüntüsü + tuş / fare / dokunuş simülasyonu (headless DEĞİL).
## godot --path . --resolution 1280x720 -s res://tools/screenshot.gd -- --demo --times=2,6 --press=ESC@4
##   --click=X,Y@T      fare sol tık
##   --touch=X,Y@T      parmak bas (basılı kalır)   --move=X,Y@T  sürükle   --lift=0@T  bırak

const KEYS := {
	"ESC": KEY_ESCAPE, "R": KEY_R, "ENTER": KEY_ENTER, "SPACE": KEY_SPACE, "M": KEY_M,
	"LEFT": KEY_LEFT, "RIGHT": KEY_RIGHT, "UP": KEY_UP, "DOWN": KEY_DOWN,
	"1": KEY_1, "2": KEY_2, "3": KEY_3, "Q": KEY_Q, "P": KEY_P,
	"W": KEY_W, "A": KEY_A, "S": KEY_S, "D": KEY_D,
}

var _out_dir := "tools/screenshots"
var _prefix := "shot"
var _actions: Array[Dictionary] = []
var _failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _parse() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--times="):
			for part in arg.get_slice("=", 1).split(","):
				_actions.append({"t": float(part), "kind": "shot"})
		elif arg.begins_with("--press="):
			var value := arg.get_slice("=", 1)
			var key := value.get_slice("@", 0).to_upper()
			var when := float(value.get_slice("@", 1)) if value.contains("@") else 0.5
			_actions.append({"t": when, "kind": "press", "key": key})
		elif arg.begins_with("--click=") or arg.begins_with("--touch=") or arg.begins_with("--move=") or arg.begins_with("--lift="):
			var kind := arg.get_slice("=", 0).trim_prefix("--")
			var body := arg.get_slice("=", 1)
			var xy := body.get_slice("@", 0).split(",")
			var at := Vector2(float(xy[0]), float(xy[1]) if xy.size() > 1 else 0.0)
			_actions.append({"t": float(body.get_slice("@", 1)) if body.contains("@") else 0.5, "kind": kind, "pos": at})
		elif arg.begins_with("--out="):
			_out_dir = arg.get_slice("=", 1)
		elif arg.begins_with("--prefix="):
			_prefix = arg.get_slice("=", 1)
	if _actions.is_empty():
		_actions = [{"t": 1.0, "kind": "shot"}]
	_actions.sort_custom(func(a, b): return float(a["t"]) < float(b["t"]))

func _run() -> void:
	_parse()
	if DisplayServer.get_name() == "headless":
		printerr("screenshot.gd: --headless ile görüntü alınamaz (dummy renderer).")
		quit(2)
		return
	var scene_path: String = ProjectSettings.get_setting("application/run/main_scene", "")
	var packed: PackedScene = load(scene_path)
	if packed == null:
		printerr("screenshot.gd: sahne yüklenemedi: " + scene_path)
		quit(2)
		return
	var out_abs := ProjectSettings.globalize_path("res://").path_join(_out_dir)
	DirAccess.make_dir_recursive_absolute(out_abs)
	if not FileAccess.file_exists(out_abs.path_join(".gdignore")):
		FileAccess.open(out_abs.path_join(".gdignore"), FileAccess.WRITE)
	await process_frame
	change_scene_to_packed(packed)
	await process_frame
	await process_frame
	var started := Time.get_ticks_msec() / 1000.0
	for action in _actions:
		var wait: float = float(action["t"]) - (Time.get_ticks_msec() / 1000.0 - started)
		if wait > 0.0:
			await create_timer(wait, true, false, true).timeout
		if action["kind"] == "shot":
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			var file_path := out_abs.path_join("%s_%05.1fs.png" % [_prefix, float(action["t"])])
			if image.save_png(file_path) == OK:
				print("ekran görüntüsü: %s (%dx%d)" % [file_path, image.get_width(), image.get_height()])
			else:
				printerr("kaydedilemedi: " + file_path)
				_failures += 1
		elif action["kind"] == "press":
			await _press(str(action["key"]))
		else:
			await _pointer(str(action["kind"]), action["pos"])
	quit(0 if _failures == 0 else 1)

func _pointer(kind: String, at: Vector2) -> void:
	## Fare tıklaması veya tek parmak dokunuşu (index 0) gönderir.
	if kind == "click":
		var motion := InputEventMouseMotion.new()
		motion.position = at
		motion.global_position = at
		Input.parse_input_event(motion)
		await process_frame
		for pressed in [true, false]:
			var button := InputEventMouseButton.new()
			button.button_index = MOUSE_BUTTON_LEFT
			button.pressed = pressed
			button.position = at
			button.global_position = at
			Input.parse_input_event(button)
			await process_frame
			await process_frame
	elif kind == "touch" or kind == "lift":
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.pressed = kind == "touch"
		touch.position = at
		Input.parse_input_event(touch)
		await process_frame
	elif kind == "move":
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = at
		Input.parse_input_event(drag)
		await process_frame
	print("%s: %s" % [kind, str(at)])

func _press(key_name: String) -> void:
	var code: int = KEYS.get(key_name, KEY_NONE)
	if code == KEY_NONE:
		printerr("bilinmeyen tuş: " + key_name)
		_failures += 1
		return
	var down := InputEventKey.new()
	down.keycode = code
	down.physical_keycode = code
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	var up := InputEventKey.new()
	up.keycode = code
	up.physical_keycode = code
	up.pressed = false
	Input.parse_input_event(up)
	await process_frame
	print("tuş: " + key_name)
