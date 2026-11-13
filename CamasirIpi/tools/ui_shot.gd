extends SceneTree

## Arayüz ekran görüntüsü (gerçek pencere; headless ÇALIŞMAZ).
##   godot --path . --resolution 1080x1920 -s res://tools/ui_shot.gd -- --shot=win --out=docs/art/ui_win.png
## --shot: home | soon | settings | hud | pause | win | lose | lose_few | lose_many | lose_moves
##         | shop | shop_skins | shop_ropes | shop_ads | shop_owned | game_skins | home_skins
## Mağaza/kaplama çekimleri için durum bellekte hazırlanır (kayda yazılmaz); `--scroll=` mağaza listesini kaydırır.
## Giriş animasyonları bitsin diye tetikten sonra `--wait=` ms beklenir (varsayılan 2600).

const HOME_SHOTS: Array[String] = ["home", "soon", "settings", "shop", "shop_skins", "shop_ropes",
	"shop_ads", "shop_owned", "home_skins"]

var _shot: String = "home"
var _out: String = "docs/art/ui_shot.png"
var _wait_ms: int = 2600
var _level: int = 22
var _scene: Node = null
var _frame: int = 0
var _trigger_at_ms: int = -1
var _scroll: int = 0


func _initialize() -> void:
	# Ekran görüntüsü araçları oyuncunun gerçek kaydına ASLA yazmaz.
	var progress_guard: Node = root.get_node_or_null("Progress")
	if progress_guard != null:
		progress_guard.set("persist", false)
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
		elif arg.begins_with("--scroll="):
			_scroll = int(arg.split("=")[1])


## Sahne ilk karede kurulur: autoload'ların `_ready`si (kayıt yükleme) `_initialize`dan SONRA çalışır;
## durum daha önce hazırlansaydı oyuncunun gerçek kaydı onu ezerdi.
func _build_scene() -> void:
	_seed_state()
	var path: String = "res://scenes/Home.tscn" if _shot in HOME_SHOTS else "res://scenes/Game.tscn"
	_scene = (load(path) as PackedScene).instantiate()
	if path.ends_with("Game.tscn"):
		_scene.set("_persist", false)
		_scene.set("_level_number", _level)
	root.add_child(_scene)
	current_scene = _scene


## Mağaza/kaplama çekimleri için bellekte örnek oyuncu durumu (diske yazılmaz: persist=false).
func _seed_state() -> void:
	var progress: Node = root.get_node_or_null("Progress")
	if progress == null or not _shot.begins_with("shop") and not _shot.ends_with("_skins"):
		return
	progress.call("reset_state")
	progress.call("add_coins", 420)
	progress.call("add_stars", 3)
	var data: ProgressData = progress.get("data") as ProgressData
	data.level = _level
	progress.call("set_module_value", "meta", "cosmetics", ["pin_tulip", "rope_sakura"])
	progress.call("set_module_value", "skins", "owned", ["pin_mint", "rope_twine"])
	match _shot:
		"shop_owned":
			progress.call("set_remove_ads_owned", true)
			progress.call("add_coins", 2000)
			progress.call("add_booster", "undo", 4)
		"game_skins":
			progress.call("set_module_value", "skins", "pin", "pin_mint")
			progress.call("set_module_value", "skins", "rope", "rope_twine")
		"home_skins":
			progress.call("set_module_value", "skins", "pin", "pin_tulip")
			progress.call("set_module_value", "skins", "rope", "rope_sakura")
		_:
			progress.call("set_module_value", "skins", "pin", "pin_mint")


func _process(_delta: float) -> bool:
	_frame += 1
	if _scene == null:
		_build_scene()
		return false
	# Tanıtım kartları ekran görüntüsünü örtmesin: tüm kartlar "görüldü" sayılır (yalnız bellekte).
	if _frame == 2 and _scene.get("_tutorial") is TutorialDirector:
		var flags: Array[String] = []
		for feature: String in TutorialStrings.CARDS.keys():
			flags.append("tut_card_%s" % feature)
		(_scene.get("_tutorial") as TutorialDirector).preseed_seen(flags)
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
		"shop", "shop_skins", "shop_ropes", "shop_ads", "shop_owned":
			_scene.call("_on_tab", 0)
			_scroll_shop()
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
		"lose_moves":
			(_scene.get("_board") as LaundryBoard).set("_lose_reason", LaundryBoard.LOSE_MOVES)
			_scene.call("_show_lose", 4)


## Mağaza listesini belirli bir bölüme kaydırır (kart sırası: güçlendirici, mandal, ip, reklam).
func _scroll_shop() -> void:
	var offsets: Dictionary = {"shop": 0, "shop_skins": 1000, "shop_ropes": 1750, "shop_ads": 99999, "shop_owned": 99999}
	var target: int = _scroll if _scroll > 0 else int(offsets.get(_shot, 0))
	for child: Node in _scene.get_children():
		# NOT: ShopScreen tipi anılmaz; `-s` kipinde autoload kimlikleri derleme anında yoktur.
		if child.get("_scroll") is ScrollContainer:
			var scroll: ScrollContainer = child.get("_scroll") as ScrollContainer
			await create_timer(0.8).timeout
			scroll.scroll_vertical = target
