extends SceneTree

## Ustalık ekran görüntüleri (gerçek pencere; headless ÇALIŞMAZ). Oyuncunun kaydına ASLA yazmaz.
##   godot --path . --resolution 1080x1920 -s res://tools/mastery_shot.gd -- --shot=win3 --out=docs/art/mastery_win3.png
## --shot: win1 | win2 | win3 | chain
##   win1/2/3: kazanma sayfası 1/2/3 yıldızla (istatistik elle kurulur)
##   chain:    seviye çözücü yoluyla oynanır, zincir hapı ×2 görününce görüntü alınır
## --wait=ms: tetikten sonra beklenecek süre (yıldız animasyonları bitsin diye varsayılan 3600).

const SOLVE_NODE_LIMIT: int = 200000
const TAP_EVERY_FRAMES: int = 30
const CHAIN_TARGET_TEXT: String = "×2"
const CHAIN_SETTLE_MSEC: int = 500
const MAX_FRAMES: int = 4000

var _shot: String = "win3"
var _out: String = "docs/art/mastery_shot.png"
var _wait_ms: int = 3600
var _level: int = 14
var _scene: Node = null
var _frame: int = 0
var _trigger_at_ms: int = -1
var _path: Array[int] = []
var _chain_seen_at_ms: int = -1


func _initialize() -> void:
	root.get_node("Progress").set("persist", false)
	Loc.apply_from_args(OS.get_cmdline_user_args())  # --lang=tr|en|es
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot = arg.split("=")[1]
		elif arg.begins_with("--out="):
			_out = arg.split("=")[1]
		elif arg.begins_with("--wait="):
			_wait_ms = int(arg.split("=")[1])
		elif arg.begins_with("--level="):
			_level = int(arg.split("=")[1])
	_scene = (load("res://scenes/Game.tscn") as PackedScene).instantiate()
	_scene.set("_persist", false)
	_scene.set("_level_number", _level)
	root.add_child(_scene)
	current_scene = _scene


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 2:
		_silence_tutorial()
	if _shot == "chain":
		return _process_chain()
	if _frame == 20:
		_trigger_win()
		_trigger_at_ms = Time.get_ticks_msec()
	if _trigger_at_ms > 0 and Time.get_ticks_msec() - _trigger_at_ms >= _wait_ms:
		return _save()
	return false


## Öğretici kartları görüntüyü örtmesin: kart/ipucu bayrakları (yalnız bellekte) görüldü sayılır.
## Sahne `_ready`si ilk karede çalıştığı için ikinci karede çağrılır (öğretici 0.9 sn sonra bakar).
func _silence_tutorial() -> void:
	var seen: Array[String] = ["tut_queue"]
	for feature: String in TutorialFeatures.table().get("card_order", []) as Array:
		seen.append(TutorialDirector.FLAG_CARD % feature)
	(_scene.get("_tutorial") as TutorialDirector).preseed_seen(seen)


func _trigger_win() -> void:
	var stats: RunStats = _scene.get("_run_stats") as RunStats
	match _shot:
		"win1":
			stats.rack_total = 20
			stats.best_chain = 1
		"win2":
			stats.rack_total = 3
			stats.best_chain = 3
		_:
			stats.rack_total = 0
			stats.best_chain = 4
	_scene.call("_show_win")


func _process_chain() -> bool:
	if _frame == 20:
		_path = LevelSolver.solve(_scene.get("_level") as Dictionary, SOLVE_NODE_LIMIT)
	if _frame > 20 and _frame % TAP_EVERY_FRAMES == 0 and not _path.is_empty() \
			and _chain_seen_at_ms < 0:
		_scene.call("_tap", _path.pop_front())
	var hud: Node = _scene.get("_hud") as Node
	var label: Label = hud.get("_chain_label") as Label
	if _chain_seen_at_ms < 0 and label != null and label.text == CHAIN_TARGET_TEXT:
		_chain_seen_at_ms = Time.get_ticks_msec()
	if _chain_seen_at_ms > 0 and Time.get_ticks_msec() - _chain_seen_at_ms >= CHAIN_SETTLE_MSEC:
		return _save()
	if _frame > MAX_FRAMES:
		printerr("MASTERY SHOT: zincir ×2 görünmedi")
		quit(1)
		return true
	return false


func _save() -> bool:
	var err: int = root.get_texture().get_image().save_png(_out)
	quit(0 if err == OK else 1)
	return true
