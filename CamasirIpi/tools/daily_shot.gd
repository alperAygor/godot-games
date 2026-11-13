extends SceneTree

## Günlük bulmaca/takvim ekran görüntüsü (gerçek pencere; headless ÇALIŞMAZ).
##   godot --path . --resolution 1080x1920 -s res://tools/daily_shot.gd -- --shot=card --out=docs/art/daily_card.png
## --shot: card | card_done | cal_fresh | cal_day3 | cal_day7 | cal_claim | win
## Oyuncunun gerçek kaydı ASLA yazılmaz (persist=false); durum her çekimde sıfırdan kurulur.

const PLAYER_LEVEL: int = 22
const SECTION: String = "daily"
const TRIGGER_FRAME: int = 20
const CLAIM_PEEK_MS: int = 420

var _shot: String = "card"
var _out: String = "docs/art/daily_shot.png"
var _wait_ms: int = 2600
var _scene: Node = null
var _frame: int = 0
var _trigger_at_ms: int = -1
var _today: String = ""
var _sheet: Node = null
var _progress: Node = null


func _initialize() -> void:
	Loc.apply_from_args(OS.get_cmdline_user_args())  # --lang=tr|en|es
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot = arg.split("=")[1]
		elif arg.begins_with("--out="):
			_out = arg.split("=")[1]
		elif arg.begins_with("--wait="):
			_wait_ms = int(arg.split("=")[1])
	_progress = root.get_node("Progress")
	_progress.set("persist", false)
	_today = (load("res://scripts/daily/daily_date.gd") as GDScript).call("today_key") as String


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 2:
		# Autoload'un diskten yüklemesi bittikten sonra durum kurulur, sonra sahne açılır.
		_prepare()
		var path: String = "res://scenes/Game.tscn" if _shot == "win" else "res://scenes/Home.tscn"
		_scene = (load(path) as PackedScene).instantiate()
		root.add_child(_scene)
		current_scene = _scene
	if _frame == TRIGGER_FRAME:
		_trigger()
		_trigger_at_ms = Time.get_ticks_msec()
	if _trigger_at_ms > 0 and Time.get_ticks_msec() - _trigger_at_ms >= _wait_ms:
		var err: int = root.get_texture().get_image().save_png(_out)
		quit(0 if err == OK else 1)
		return true
	return false


func _date(offset: int) -> String:
	return (load("res://scripts/daily/daily_date.gd") as GDScript).call("add_days", _today, offset) as String


func _prepare() -> void:
	_progress.call("reset_state")
	_progress.data.level = PLAYER_LEVEL
	_progress.data.coins = 380
	match _shot:
		"card":
			_progress.call("set_module_value", SECTION, "last_won", _date(-1))
			_progress.call("set_module_value", SECTION, "streak", 2)
			_progress.call("set_module_value", SECTION, "best", 5)
		"card_done":
			_progress.call("set_module_value", SECTION, "last_won", _today)
			_progress.call("set_module_value", SECTION, "streak", 3)
			_progress.call("set_module_value", SECTION, "best", 5)
		"cal_day3":
			_progress.call("set_module_value", SECTION, "last_claim", _today)
			_progress.call("set_module_value", SECTION, "day", 3)
		"cal_day7", "cal_claim":
			_progress.call("set_module_value", SECTION, "last_claim", _date(-1))
			_progress.call("set_module_value", SECTION, "day", 6)
		"win":
			# Öğretici kartları görüldü sayılır: görüntüde günlük sonuç sayfasının önüne geçmesinler.
			var tutorials: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/tutorials.json"))
			for card: Variant in ((tutorials as Dictionary).get("cards", {}) as Dictionary).keys():
				_progress.call("mark_seen", "tut_card_%s" % String(card))
			_progress.call("set_module_value", SECTION, "last_won", _date(-1))
			_progress.call("set_module_value", SECTION, "streak", 2)
			_progress.call("set_module_value", SECTION, "best", 2)
			var puzzle: GDScript = load("res://scripts/daily/daily_puzzle.gd") as GDScript
			puzzle.set("pending_level", puzzle.call("build_level", _today, PLAYER_LEVEL))


func _trigger() -> void:
	match _shot:
		"card", "card_done":
			_sheet = (load("res://scripts/daily/daily_puzzle.gd") as GDScript).call("open_card", _scene) as Node
		"cal_fresh", "cal_day3", "cal_day7":
			_sheet = (load("res://scripts/daily/daily_calendar.gd") as GDScript).call("open", _scene) as Node
		"cal_claim":
			_sheet = (load("res://scripts/daily/daily_calendar.gd") as GDScript).call("open", _scene) as Node
			# Giriş animasyonu bitsin, sonra al: karo zıplarken/kıvılcım saçılırken görüntü alınır.
			_wait_ms = int(CLAIM_PEEK_MS) + 900
			get_root().get_tree().create_timer(0.9).timeout.connect(func() -> void: _sheet.call("_on_claim"))
		"win":
			_scene.call("_show_win")
