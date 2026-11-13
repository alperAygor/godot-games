extends SceneTree

## Arayüz cilası için ek ekran görüntüleri (gerçek pencere; headless ÇALIŞMAZ).
##   godot --path . --resolution 1080x1920 -s res://tools/q_ui_shot.gd -- --shot=machines --lang=tr --out=x.png
## --shot: machines | settings | tc_<özellik> (öğretici kartı) | booster | boosterzero
## Oyuncunun gerçek kaydına ASLA yazmaz (persist=false).

const TRIGGER_FRAME: int = 20
const BOOSTER_LEVEL: int = 30
const MACHINE_LEVEL: int = 70
## Öğretici kartı çekimlerinde ana ekranda ödül yolu sayfası otomatik açılmasın diye düşük seviye.
const CARD_LEVEL: int = 3
const MACHINE_COINS: int = 900

var _shot: String = "machines"
var _out: String = "docs/art/q_ui_shot.png"
var _wait_ms: int = 2400
var _scene: Node = null
var _frame: int = 0
var _trigger_at_ms: int = -1


func _initialize() -> void:
	var guard: Node = root.get_node_or_null("Progress")
	if guard != null:
		guard.set("persist", false)
	Loc.apply_from_args(OS.get_cmdline_user_args())
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot = arg.split("=")[1]
		elif arg.begins_with("--out="):
			_out = arg.split("=")[1]
		elif arg.begins_with("--wait="):
			_wait_ms = int(arg.split("=")[1])


func _build_scene() -> void:
	var progress: Node = root.get_node_or_null("Progress")
	var game: bool = _shot.begins_with("booster")
	if progress != null:
		progress.call("reset_state")
		progress.call("add_coins", MACHINE_COINS)
		progress.call("add_stars", 3)
		var data: ProgressData = progress.get("data") as ProgressData
		data.level = BOOSTER_LEVEL if game else (MACHINE_LEVEL if _shot == "machines" else CARD_LEVEL)
		if _shot == "booster":
			var amount: int = 1
			for id: String in Boosters.IDS:
				progress.call("add_booster", id, amount * 3 - 2)
				amount += 1
		if _shot == "boosterzero" or _shot == "boosterad":
			for id: String in Boosters.IDS:
				while int(progress.call("booster_count", id)) > 0:
					progress.call("use_booster", id)
	var path: String = "res://scenes/Game.tscn" if game else "res://scenes/Home.tscn"
	_scene = (load(path) as PackedScene).instantiate()
	if game:
		_scene.set("_persist", false)
		_scene.set("_level_number", BOOSTER_LEVEL)
	root.add_child(_scene)
	current_scene = _scene


func _process(_delta: float) -> bool:
	_frame += 1
	if _scene == null:
		_build_scene()
		return false
	if _frame == 2 and _scene.get("_tutorial") is TutorialDirector:
		var flags: Array[String] = []
		for feature: String in TutorialStrings.CARDS.keys():
			flags.append("tut_card_%s" % feature)
		(_scene.get("_tutorial") as TutorialDirector).preseed_seen(flags)
	if _frame == TRIGGER_FRAME:
		_trigger()
		_trigger_at_ms = Time.get_ticks_msec()
	if _trigger_at_ms > 0 and Time.get_ticks_msec() - _trigger_at_ms >= _wait_ms:
		var err: int = root.get_texture().get_image().save_png(_out)
		quit(0 if err == OK else 1)
		return true
	return false


func _trigger() -> void:
	if _shot == "machines":
		MachineUpgrades.open(_scene)
	elif _shot == "boosterad":
		(_scene.get("_booster_bar") as BoosterBar).ad_enabled = true
		_scene.call("_refresh_booster_bar")
	elif _shot == "settings":
		_scene.call("_open_settings")
	elif _shot.begins_with("tc_"):
		var feature: String = _shot.substr(3)
		var spec: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://data/tutorials.json")) as Dictionary)["cards"][feature]
		var card: TutorialCard = TutorialCard.new()
		var palette: Array[Color] = []
		root.add_child(card)
		card.setup(feature, spec, palette)
