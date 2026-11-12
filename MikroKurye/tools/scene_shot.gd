extends SceneTree

## Bir sahneyi gerçek pencerede çalıştırıp ekran görüntüsü alır (headless ÇALIŞMAZ).
##
##   godot --path . -s res://tools/scene_shot.gd -- --scene=res://scenes/Proto.tscn --out=/tmp/shot.png --frames=240 --throttle=1.0
##
## `--throttle` verilirse `robot` grubundaki düğümün `set_move_input(Vector2(0, throttle))` metodu çağrılır.
## Lider görsel denetiminde (orchestra/shots.sh benzeri) kullanır; birim test değildir.

var _scene_path: String = "res://scenes/Proto.tscn"
var _out: String = "/tmp/scene_shot.png"
var _frames: int = 240
var _throttle: float = 0.0
var _level_id: String = ""
var _result_file: String = ""
var _zone: int = -1
var _count: int = 0
var _scene: Node = null
var _done: bool = false


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			_scene_path = arg.split("=")[1]
		elif arg.begins_with("--out="):
			_out = arg.split("=")[1]
		elif arg.begins_with("--frames="):
			_frames = int(arg.split("=")[1])
		elif arg.begins_with("--result="):
			_result_file = arg.split("=")[1]
		elif arg.begins_with("--zone="):
			_zone = int(arg.split("=")[1])
		elif arg.begins_with("--level="):
			_level_id = arg.split("=")[1]
		elif arg.begins_with("--throttle="):
			_throttle = float(arg.split("=")[1])
	if not _level_id.is_empty():
		var manager: Node = root.get_node_or_null("GameManager")
		if manager != null:
			manager.set("selected_level_id", _level_id)
	if not _result_file.is_empty():
		# Sonuç ekranı denetimi: GameManager.last_result bir JSON dosyasından kurulur.
		var manager_for_result: Node = root.get_node_or_null("GameManager")
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_result_file))
		if manager_for_result != null and parsed is Dictionary:
			manager_for_result.set("last_result", parsed)
	var packed: PackedScene = load(_scene_path) as PackedScene
	if packed == null:
		push_error("scene_shot: sahne yüklenemedi: %s" % _scene_path)
		quit(1)
		return
	_scene = packed.instantiate()
	root.add_child(_scene)


func _process(_delta: float) -> bool:
	if _done:
		return true
	_count += 1
	if _zone >= 0 and _count == 3:
		# `_ready` zinciri ilk karede tamamlanır; seviye düğümü bundan sonra vardır.
		var zone_level: Node = _scene.get_node_or_null("Level")
		if zone_level != null and zone_level.has_method("preview_zone"):
			zone_level.call("preview_zone", _zone)
	var robot: Node = get_first_node_in_group("robot")
	if robot != null and robot.has_method("set_move_input"):
		robot.call("set_move_input", Vector2(0.0, _throttle))
	if _count >= _frames:
		_done = true
		var img: Image = root.get_texture().get_image()
		var err: int = img.save_png(_out)
		quit(0 if err == OK else 1)
	return _done
