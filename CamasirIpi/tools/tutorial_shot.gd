extends SceneTree

## Öğretici görsel QA (gerçek pencere): seviyeyi açar, isteğe bağlı bazı özellikleri "görüldü"
## sayar, N saniye bekler ve ekran görüntüsü alır. `--level=` oyunun kendi bayrağıdır; kaydı
## yazmaz (`_persist` kapanır) ve öğretici "görüldü" bilgisini yalnız bellekte tutar, yani
## oyuncunun gerçek kaydına dokunulmaz.
##   godot --path . --resolution 1080x1920 -s res://tools/tutorial_shot.gd -- \
##       --level=14 --seen=tut_card_wet --wait=2.2 --out=docs/art/tut_mystery.png

var _game: Node = null
var _out: String = "docs/art/tut_shot.png"
var _wait: float = 2.5
var _taps: int = 0
var _path: Array[int] = []
var _time: float = 0.0
var _frame: int = 0
var _seen: Array[String] = []


func _initialize() -> void:
	# Ekran görüntüsü araçları oyuncunun gerçek kaydına ASLA yazmaz.
	var progress_guard: Node = root.get_node_or_null("Progress")
	if progress_guard != null:
		progress_guard.set("persist", false)
	Loc.apply_from_args(OS.get_cmdline_user_args())  # --lang=tr|en|es
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.split("=")[1]
		elif arg.begins_with("--wait="):
			_wait = float(arg.split("=")[1])
		elif arg.begins_with("--taps="):
			_taps = int(arg.split("=")[1])
		elif arg.begins_with("--seen="):
			for flag: String in arg.split("=")[1].split(","):
				_seen.append(flag)
	_game = (load("res://scenes/Game.tscn") as PackedScene).instantiate()
	root.add_child(_game)
	current_scene = _game


func _process(delta: float) -> bool:
	_frame += 1
	# Düğümler ağaca girip _ready çalıştıktan sonra (ilk kare) kayıt hazırlanır; kartlar zaten gecikmeli açılır.
	if _frame == 1:
		(_game.get("_tutorial") as TutorialDirector).preseed_seen(_seen)
	_time += delta
	if _frame == 3 and _taps > 0:
		_path = LevelSolver.solve(_game.get("_level") as Dictionary, 200000)
	# Dokunuşlar kartı/rehberi beklemeden, ilk saniye içinde oynanır.
	if _taps > 0 and not _path.is_empty() and _frame > 10 and _frame % 8 == 0:
		_game.call("_tap", _path.pop_front())
		_taps -= 1
	if _time >= _wait:
		root.get_texture().get_image().save_png(_out)
		quit(0)
		return true
	return false
