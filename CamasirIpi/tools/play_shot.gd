extends SceneTree

## Görsel QA: seviyeyi açar, çözücü yolundan N dokunuş oynar ve ekran görüntüsü alır.
##   godot --path . --resolution 1080x1920 -s res://tools/play_shot.gd -- --level=22 --taps=5 --out=docs/art/x.png
## Tanıtım kartları varsayılan olarak gizlenir (tahta görünsün); `--cards` ile gösterilir.
## `--until=joker|big|stain|screen|wind`: dokunuşlar o durum oluşunca durur (rengini almamış joker sepet
## aktif / patronun ikinci ekranı açıldı / rüzgâr esti) — kural görsellerini yakalamak için.
## Makineler/misafirler: `--until=washer|dryer|typed|birdhint|bird|rain|cat` (makinede çamaşır var /
## türlü sepet aktif / kuş bir hamle sonra konacak / kuş kondu / bulut yağmak üzere / kedi uyuyor).
## `--sheet=machines`: makine yükseltme sayfasını açar (bellekte jeton verilir, kayda yazılmaz).

var _game: Node = null
var _path: Array[int] = []
var _taps: int = 0
var _out: String = "docs/art/play_shot.png"
var _frame: int = 0
var _level: int = 1
var _shot_at: int = -1
var _capturing: bool = false
var _cards: bool = false
var _until: String = ""
var _settle_msec: int = 0
var _busy_msec: int = 0
var _sheet: String = ""
## Sayfa çekiminde gösterilecek jeton (bir yükseltme alınabilir, biri alınamaz görünsün).
const SHEET_COINS: int = 520
const IDLE_MSEC: int = 1600
## Yavaş makinede (pencere arka planda) animasyonlar gecikir: son dokunuştan sonra bu kadar beklenir.
const UNTIL_SETTLE_MSEC: int = 1500


func _initialize() -> void:
	# Ekran görüntüsü araçları oyuncunun gerçek kaydına ASLA yazmaz.
	var progress_guard: Node = root.get_node_or_null("Progress")
	if progress_guard != null:
		progress_guard.set("persist", false)
	Loc.apply_from_args(OS.get_cmdline_user_args())  # --lang=tr|en|es
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--level="):
			_level = int(arg.split("=")[1])
		elif arg.begins_with("--taps="):
			_taps = int(arg.split("=")[1])
		elif arg.begins_with("--out="):
			_out = arg.split("=")[1]
		elif arg.begins_with("--until="):
			_until = arg.split("=")[1]
		elif arg == "--cards":
			_cards = true
		elif arg.begins_with("--sheet="):
			_sheet = arg.split("=")[1]
	_game = (load("res://scenes/Game.tscn") as PackedScene).instantiate()
	root.add_child(_game)
	current_scene = _game


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 2 and not _cards:
		# Kart bayrakları yalnız bellekte "görüldü" işaretlenir (kayda dokunulmaz).
		var seen: Dictionary = (_game.get("_tutorial") as Node).get("_memory_seen") as Dictionary
		for feature: Variant in TutorialFeatures.table().get("card_order", []) as Array:
			seen[TutorialDirector.FLAG_CARD % String(feature)] = true
	if _frame == 5:
		_path = LevelSolver.solve(_game.get("_level") as Dictionary, 200000)
	if _frame == 8 and _sheet == "machines":
		var progress: Node = root.get_node("Progress")
		progress.call("add_coins", SHEET_COINS - int(progress.call("coins")))
		progress.call("set_module_value", "machines", "washer_capacity", 1)
		# Sayfa iki makineyi de açık göstersin (yalnız bellekte; kayda yazılmaz).
		(progress.get("data") as Object).set("level", maxi(int(progress.call("level")), _level))
		# Dinamik yükleme: araç (-s) kipinde UI sınıfları autoload adlarıyla derlenemiyor.
		(load("res://scripts/machines/machine_upgrades.gd") as GDScript).call("open", _game.get("_ui") as Node)
	if _taps > 0 and _reached_until():
		_taps = 0
		_shot_at = _frame + 1
		# Kare sayısı pencere hızına bağlı; sepet geliş animasyonu gerçek zamanlıdır.
		_settle_msec = Time.get_ticks_msec() + UNTIL_SETTLE_MSEC
	if _frame > 20 and _frame % 14 == 0 and _taps > 0 and not _path.is_empty():
		_game.call("_tap", _path.pop_front())
		_taps -= 1
		if _taps == 0:
			_shot_at = _frame + 26
	if _taps == 0 and _shot_at < 0:
		_shot_at = 60
	# Görsel olay kuyruğu dokunuşların gerisinden gelir: kuyruk boşalana dek çekim ertelenir.
	if bool(_game.get("_playing")):
		_busy_msec = Time.get_ticks_msec()
	# Olay kuyruğu bitse de son sepetin kayıp gitmesi/yenisinin gelmesi tween'le sürer: kuyruk
	# boşaldıktan sonra da IDLE_MSEC beklenir.
	if _shot_at > 0 and _frame >= _shot_at and (bool(_game.get("_playing")) or Time.get_ticks_msec() < _settle_msec
			or Time.get_ticks_msec() - _busy_msec < IDLE_MSEC):
		_shot_at = _frame + 1
	if _shot_at > 0 and _frame >= _shot_at and not _capturing:
		# Görüntü, bir sonraki kare GERÇEKTEN çizildikten sonra alınır: pencere arka plandayken
		# son çizilen kare eski kalabiliyor (çekim birkaç dokunuş geriden geliyordu).
		_capturing = true
		RenderingServer.frame_post_draw.connect(_capture, CONNECT_ONE_SHOT)
	return false


func _reached_until() -> bool:
	var board: LaundryBoard = _game.get("_board") as LaundryBoard
	if board == null or _until.is_empty():
		return false
	match _until:
		"joker":
			for basket: Dictionary in board.baskets():
				if bool(basket.get("joker", false)) and int(basket["color"]) == LaundryBoard.EMPTY:
					return true
		"big":
			for index: int in range(board.baskets().size()):
				if board.basket_capacity(index) > LaundryBoard.BASKET_CAPACITY and int(board.baskets()[index]["count"]) >= 2:
					return true
		"stain":
			return not board.drying_ids().is_empty()
		"screen":
			return board.current_screen() > 0
		"wind":
			return board.wind_done() > 0
		"washer", "dryer":
			var machine: int = LaundryBoard.MACHINE_WASHER if _until == "washer" else LaundryBoard.MACHINE_DRYER
			for slot: int in range(board.machine_capacity(machine)):
				if board.machine_slot(machine, slot).x != LaundryBoard.EMPTY:
					return true
		"typed":
			for index: int in range(board.baskets().size()):
				if board.basket_kind(index) != LaundryBoard.EMPTY:
					return true
		"birdhint":
			return board.bird_left() == 1
		"bird":
			return board.bird_on() != LaundryBoard.EMPTY
		"rain":
			return board.rain_left() == 1
		"cat":
			return board.cat_at() != LaundryBoard.EMPTY
	return false


func _capture() -> void:
	var board: LaundryBoard = _game.get("_board") as LaundryBoard
	print("SHOT playing=%s events=%d baskets=%s screen=%d" % [str(_game.get("_playing")),
		(_game.get("_events") as Array).size(), str(board.baskets()), board.current_screen()])
	root.get_texture().get_image().save_png(_out)
	quit(0)
