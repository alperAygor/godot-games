extends SceneTree

## Arayüz ekran görüntüsü (gerçek pencere; headless ÇALIŞMAZ).
##   godot --path . --resolution 1080x1920 -s res://tools/ui_shot.gd -- --shot=win --out=docs/art/ui_win.png
## --shot: home | soon | settings | hud | pause | win | lose | lose_few | lose_many
## Giriş animasyonları bitsin diye tetikten sonra `--wait=` ms beklenir (varsayılan 2600).

var _shot: String = "home"
var _out: String = "docs/art/ui_shot.png"
var _wait_ms: int = 2600
var _level: int = 22
var _scene: Node = null
var _frame: int = 0
var _trigger_at_ms: int = -1


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot = arg.split("=")[1]
		elif arg.begins_with("--out="):
			_out = arg.split("=")[1]
		elif arg.begins_with("--wait="):
			_wait_ms = int(arg.split("=")[1])
		elif arg.begins_with("--level="):
			_level = int(arg.split("=")[1])
	var path: String = "res://scenes/Home.tscn" if _shot in ["home", "soon", "settings"] \
		else "res://scenes/Game.tscn"
	_scene = (load(path) as PackedScene).instantiate()
	if path.ends_with("Game.tscn"):
		_scene.set("_persist", false)
		_scene.set("_level_number", _level)
	root.add_child(_scene)
	current_scene = _scene


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 20:
		_trigger()
		_trigger_at_ms = Time.get_ticks_msec()
	if _trigger_at_ms > 0 and Time.get_ticks_msec() - _trigger_at_ms >= _wait_ms:
		var err: int = root.get_texture().get_image().save_png(_out)
		quit(0 if err == OK else 1)
		return true
	return false


func _trigger() -> void:
	match _shot:
		"soon":
			_scene.call("_on_tab", 0)
		"settings":
			_scene.call("_open_settings")
		"pause":
			_scene.call("_on_pause_requested")
		"win":
			_scene.call("_show_win")
		"lose", "lose_few":
			_scene.call("_show_lose", 4)
		"lose_many":
			_scene.call("_show_lose", 11)
