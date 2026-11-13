extends SceneTree

## Görsel QA: seviyeyi açar, çözücü yolundan N dokunuş oynar ve ekran görüntüsü alır.
##   godot --path . --resolution 1080x1920 -s res://tools/play_shot.gd -- --level=22 --taps=5 --out=docs/art/x.png

var _game: Node = null
var _path: Array[int] = []
var _taps: int = 0
var _out: String = "docs/art/play_shot.png"
var _frame: int = 0
var _level: int = 1
var _shot_at: int = -1
var _capturing: bool = false


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--level="):
			_level = int(arg.split("=")[1])
		elif arg.begins_with("--taps="):
			_taps = int(arg.split("=")[1])
		elif arg.begins_with("--out="):
			_out = arg.split("=")[1]
	_game = (load("res://scenes/Game.tscn") as PackedScene).instantiate()
	root.add_child(_game)
	current_scene = _game


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 5:
		_path = LevelSolver.solve(_game.get("_level") as Dictionary, 200000)
	if _frame > 20 and _frame % 14 == 0 and _taps > 0 and not _path.is_empty():
		_game.call("_tap", _path.pop_front())
		_taps -= 1
		if _taps == 0:
			_shot_at = _frame + 26
	if _taps == 0 and _shot_at < 0:
		_shot_at = 60
	# Görsel olay kuyruğu dokunuşların gerisinden gelir: kuyruk boşalana dek çekim ertelenir.
	if _shot_at > 0 and _frame >= _shot_at and bool(_game.get("_playing")):
		_shot_at = _frame + 1
	if _shot_at > 0 and _frame >= _shot_at and not _capturing:
		# Görüntü, bir sonraki kare GERÇEKTEN çizildikten sonra alınır: pencere arka plandayken
		# son çizilen kare eski kalabiliyor (çekim birkaç dokunuş geriden geliyordu).
		_capturing = true
		RenderingServer.frame_post_draw.connect(_capture, CONNECT_ONE_SHOT)
	return false


func _capture() -> void:
	root.get_texture().get_image().save_png(_out)
	quit(0)
