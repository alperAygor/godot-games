extends SceneTree

## Harita / tekrar kartı / ana ekran / zen / çevrimdışı sayfası ekran görüntüsü (gerçek pencere; headless ÇALIŞMAZ).
##   godot --path . --resolution 1080x1920 -s res://tools/map_shot.gd -- --shot=map_early --lang=tr --out=docs/art/q_map_early_tr.png
## --shot: map_early | map_35 | map_85 | map_600 | card | home | zen | zen_card | offline
## Oyuncunun gerçek kaydı ASLA yazılmaz (persist=false); çevrimiçi kapısı araçta kapalıdır.
## NOT: autoload kimlikleri `-s` kipinde derleme anında yoktur; autoload'a değen sınıflara `load` + `call/get` ile erişilir.

const TRIGGER_FRAME: int = 20
const SETTLE_MS: int = 1800

var _shot: String = "map_early"
var _out: String = "docs/art/q_map_shot.png"
var _wait_ms: int = SETTLE_MS
var _scene: Node = null
var _frame: int = 0
var _trigger_at_ms: int = -1
var _progress: Node = null
var _map: Node = null


func _initialize() -> void:
	Loc.apply_from_args(OS.get_cmdline_user_args())
	(load("res://scripts/net/online_gate.gd") as GDScript).set("enabled", false)
	AnalyticsLog.echo = false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot = arg.split("=")[1]
		elif arg.begins_with("--out="):
			_out = arg.split("=")[1]
		elif arg.begins_with("--wait="):
			_wait_ms = int(arg.split("=")[1])
	_progress = root.get_node("Progress")
	_progress.set("persist", false)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 2:
		_prepare()
		var path: String = "res://scenes/Game.tscn" if _shot == "zen" else "res://scenes/Home.tscn"
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


## Oynanmış bir geçmiş: 1..current-1 seviyelerine değişen yıldızlar (gerçekçi dağılım).
func _history(current: int) -> void:
	_progress.call("reset_state")
	_progress.data.level = current
	_progress.data.coins = 380
	for level: int in range(1, current):
		var stars: int = 3 if (level * 7 + level / 3) % 5 < 2 else (2 if (level * 3) % 4 != 0 else 1)
		_progress.data.record_best_stars(level, stars)
	_progress.data.stars = 40
	# Öğretici kartları görüldü sayılır: görüntüde önüne geçmesinler.
	var tutorials: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/tutorials.json"))
	for card: Variant in ((tutorials as Dictionary).get("cards", {}) as Dictionary).keys():
		_progress.call("mark_seen", "tut_card_%s" % String(card))


## Sandık açılışı penceresi ana ekranda çıkmasın: geçmiş kilometre taşları alınmış sayılır
## (harita çekimlerinde en yeni sandık alınmamış bırakılır: altın görünür).
func _claim_milestones(through: int) -> void:
	var claimed: Array[int] = []
	for level: int in [5, 10, 15, 20, 30, 40, 50, 60, 70, 80]:
		if level <= through:
			claimed.append(level)
	_progress.call("set_module_value", "retention", "milestones", {"claimed": claimed})


func _prepare() -> void:
	match _shot:
		"map_early":
			_history(4)
		"map_35", "card":
			_history(35)
			_claim_milestones(20)
		"map_85":
			_history(85)
			_claim_milestones(70)
		"map_600":
			_history(600)
		"zen", "zen_card", "home":
			_history(22)
			_claim_milestones(20)
			if _shot == "zen":
				(load("res://scripts/zen/zen_mode.gd") as GDScript).set("pending", true)
		"offline":
			_history(22)
			_claim_milestones(20)


func _trigger() -> void:
	match _shot:
		"map_early", "map_85", "map_600":
			_map = _open_map()
		"map_35":
			_map = _open_map()
			# Mevsim ayracı (31) ve mevcut seviye birlikte görünsün.
			(_map.get("_canvas") as Node).call("focus_level", 33, false, 0.5)
		"card":
			_map = _open_map()
			(_map.get("_canvas") as Node).call("focus_level", 33, false, 0.5)
			_map.call("_on_level_tapped", 31)
		"zen_card":
			_map = _open_map()
			(load("res://scripts/zen/zen_card.gd") as GDScript).call("open", _map.get("_root") as Node)
		"offline":
			var checker: RefCounted = (load("res://scripts/net/online_checker.gd") as GDScript).new() as RefCounted
			(load("res://scripts/net/online_sheet.gd") as GDScript).call("open", _scene, checker)


func _open_map() -> Node:
	return (load("res://scripts/map/level_map.gd") as GDScript).call("open", _scene) as Node
