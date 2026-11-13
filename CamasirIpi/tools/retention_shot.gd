extends SceneTree

## Tutundurma sayfaları ekran görüntüsü (gerçek pencere; headless ÇALIŞMAZ).
##   godot --path . --resolution 1080x1920 -s res://tools/retention_shot.gd -- --shot=missions_progress --lang=en --out=docs/art/retention_missions_progress_en.png
## --shot: missions_fresh | missions_progress | missions_claim | missions_fx
##         milestones_fresh | milestones_progress | milestones_claim | milestones_fx
##         weekly_fresh | weekly_progress | weekly_claim | weekly_chain
##         comeback | streak | entry | locked
## Oyuncunun gerçek kaydı ASLA yazılmaz (persist=false); "bugün" enjekte edilir.

const TODAY: String = "2026-11-13"
const WEEK: String = "2026-11-09"
const PLAYER_LEVEL: int = 22
const TRIGGER_FRAME: int = 20
const FX_DELAY_SECONDS: float = 1.0
const FX_PEEK_MS: int = 380

var _shot: String = "missions_fresh"
var _out: String = "docs/art/retention_shot.png"
var _wait_ms: int = 2200
var _scene: Node = null
var _frame: int = 0
var _trigger_at_ms: int = -1
var _sheet: Node = null
var _progress: Node = null


func _initialize() -> void:
	Loc.apply_from_args(OS.get_cmdline_user_args())
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot = arg.split("=")[1]
		elif arg.begins_with("--out="):
			_out = arg.split("=")[1]
		elif arg.begins_with("--wait="):
			_wait_ms = int(arg.split("=")[1])
	_progress = root.get_node("Progress")
	_progress.set("persist", false)
	# Sınıflara çalışma anında bağlanılır: -s kipinde autoload kimlikleri derleme anında çözülemez.
	_cls("res://scripts/retention/retention_store.gd").set("today_override", TODAY)
	AnalyticsLog.echo = false


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 2:
		_prepare()
		_scene = (load("res://scenes/Home.tscn") as PackedScene).instantiate()
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


func _cls(path: String) -> GDScript:
	return load(path) as GDScript


func _put(key: String, value: Variant) -> void:
	_progress.call("set_module_value", "retention", key, value)


func _mission(id: String, target: int, progress: int, claimed: bool, coins: int) -> Dictionary:
	return {"id": id, "target": target, "progress": progress, "claimed": claimed, "reward": {"coins": coins}}


func _missions_state(kind: String) -> Dictionary:
	match kind:
		"progress":
			return {"day": TODAY, "chest": false, "items": [_mission("levels", 3, 2, false, 20),
				_mission("baskets", 8, 3, false, 20), _mission("chain", 3, 0, false, 30)]}
		"claim", "fx":
			return {"day": TODAY, "chest": false, "items": [_mission("levels", 3, 3, true, 20),
				_mission("baskets", 8, 8, false, 20), _mission("stars3", 1, 1, true, 30)]}
	return {}


func _weekly_state(progress: int, claimed: Array, theme: String) -> Dictionary:
	return {"week": WEEK, "theme": theme, "progress": progress, "claimed": claimed}


func _prepare() -> void:
	_progress.call("reset_state")
	_progress.data.level = PLAYER_LEVEL
	_progress.data.coins = 380
	var kind: String = _shot.split("_")[1] if _shot.contains("_") else ""
	if _shot.begins_with("missions"):
		var seeded: Dictionary = _missions_state(kind)
		if not seeded.is_empty():
			_put("missions", seeded)
		_put("comeback", {"last_day": TODAY, "run": 4})
	match _shot:
		"milestones_fresh":
			_progress.data.level = 1
		"milestones_progress":
			_progress.data.level = 8
			_put("milestones", {"claimed": [5]})
		"milestones_claim", "milestones_fx":
			_progress.data.level = 12
			_put("milestones", {"claimed": [5]})
		"weekly_fresh":
			_put("weekly", _weekly_state(0, [0, 0, 0, 0, 0], "blue"))
		"weekly_progress":
			_put("weekly", _weekly_state(18, [1, 0, 0, 0, 0], "blue"))
		"weekly_claim":
			_put("weekly", _weekly_state(62, [1, 0, 0, 0, 0], "blue"))
		"weekly_chain":
			_put("weekly", _weekly_state(14, [1, 0, 0, 0, 0], "chain"))
		"comeback":
			_put("comeback", {"last_day": TODAY, "run": 1, "pending": {
				"reward": {"coins": 90, "stars": 0, "boosters": {"undo": 1}}, "away": 4, "streak": 0}})
		"streak":
			_put("comeback", {"last_day": TODAY, "run": 3, "pending": {
				"reward": {"coins": 15, "stars": 0, "boosters": {}}, "away": 0, "streak": 3}})
		"locked":
			_progress.data.level = 3


func _trigger() -> void:
	match _shot:
		"entry":
			_cls("res://scripts/retention/retention_hub.gd").call("build_entry_row", _scene)
		"missions_fx":
			_sheet = _open("missions")
			_wait_ms = FX_PEEK_MS + 1300
			root.get_tree().create_timer(FX_DELAY_SECONDS).timeout.connect(_press_first_claim)
		"milestones_fx":
			_sheet = _open("milestones")
			_wait_ms = FX_PEEK_MS + 1300
			root.get_tree().create_timer(FX_DELAY_SECONDS).timeout.connect(_press_first_claim)
		_:
			var kind: String = _shot.split("_")[0]
			if _shot == "locked":
				kind = "weekly"
			elif _shot == "comeback" or _shot == "streak":
				_sheet = _cls("res://scripts/retention/comeback_sheet.gd").call("open", _scene) as Node
				return
			_sheet = _open(kind)


func _open(kind: String) -> Node:
	return _cls("res://scripts/retention/retention_hub.gd").call("open_sheet", kind, _scene) as Node


func _press_first_claim() -> void:
	for node: Node in _sheet.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if button.visible and not button.disabled and button.get_child_count() > 0 \
				and button.theme_type_variation != &"SecondaryButton":
			button.pressed.emit()
			return
