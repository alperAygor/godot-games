extends SceneTree

## Meta ekranlarının ekran görüntüsü (gerçek pencere; headless ÇALIŞMAZ).
##   godot --path . --resolution 1080x1920 -s res://tools/meta_shot.gd -- --shot=laundry_half --out=docs/art/meta_laundry_half.png
## --shot: laundry_empty | laundry_half | laundry_full | laundry_reveal | laundry_poor | collection | collection_early
##         | laundry_tap | collection_all
## Oyuncunun GERÇEK kaydına asla yazılmaz: Progress.persist=false, durum yalnız bellekte kurulur.
## NEDEN ekran sınıfları adla değil `load()` ile: `-s` kipinde betik autoload'lardan önce
## derlenir; UiKit'in AudioService başvurusu derleme anında çözülemez (testlerle aynı sorun).

const LAUNDROMAT_SCENE: String = "res://scenes/meta/Laundromat.tscn"
const COLLECTION_SCENE: String = "res://scenes/meta/Collection.tscn"

const WAIT_MS: int = 2400
## Açılma animasyonunu ortasında yakalamak için (parıltı görünsün).
const REVEAL_WAIT_MS: int = 520
## laundry_tap: 1. çamaşır makinesinin gövdesi (1080 genişlikli görünümde).
const TAP_POINT: Vector2 = Vector2(355.0, 960.0)

var _shot: String = "laundry_half"
var _out: String = "docs/art/meta_shot.png"
var _wait_ms: int = WAIT_MS
var _frame: int = 0
var _opened_at: int = -1
var _screen: Node = null


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot = arg.split("=")[1]
		elif arg.begins_with("--out="):
			_out = arg.split("=")[1]
		elif arg.begins_with("--wait="):
			_wait_ms = int(arg.split("=")[1])


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 3:
		_prepare()
	elif _frame == 6:
		_open()
		_opened_at = Time.get_ticks_msec()
	elif _opened_at > 0 and Time.get_ticks_msec() - _opened_at >= _wait_ms:
		var err: int = root.get_texture().get_image().save_png(_out)
		quit(0 if err == OK else 1)
		return true
	return false


func _prepare() -> void:
	var progress: Node = root.get_node_or_null("Progress")
	if progress == null:
		push_error("meta_shot: Progress autoload yok")
		quit(1)
		return
	# Önce diske yazmayı kapat, sonra bellekteki durumu sıfırla: gerçek kayıt dokunulmaz kalır.
	progress.set("persist", false)
	progress.call("reset_state")
	var data: ProgressData = progress.get("data") as ProgressData
	var catalog: MetaCatalog = MetaCatalog.load_default()
	var state: MetaState = MetaState.new()
	data.coins = 480
	match _shot:
		"laundry_empty":
			data.stars = 3
			data.level = 4
		"laundry_poor":
			data.stars = 0
			data.level = 2
			state.complete_next(catalog, 0)
		"laundry_half":
			data.stars = 2
			data.level = 12
			for variant: int in [0, 1, 2, 0, 1, 1]:
				state.complete_next(catalog, variant)
		"laundry_tap":
			data.stars = 2
			data.level = 12
			for variant: int in [0, 1, 2, 0, 1, 1]:
				state.complete_next(catalog, variant)
		"laundry_reveal":
			data.stars = 4
			data.level = 12
			for variant: int in [1, 0, 1, 0, 2]:
				state.complete_next(catalog, variant)
		"laundry_full":
			data.stars = 1
			data.level = 30
			for variant: int in [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]:
				state.complete_next(catalog, variant)
			data.stars = catalog.task_cost(0, 11)
		"collection":
			data.level = 75
			state.pieces_seen = 5
		"collection_early":
			data.level = 18
		"collection_all":
			data.level = 241
			state.pieces_seen = 24
	progress.call("set_module_value", "meta", "state", state.to_dict())


func _open() -> void:
	if _shot.begins_with("laundry"):
		_screen = (load(LAUNDROMAT_SCENE) as PackedScene).instantiate()
		root.add_child(_screen)
		if _shot == "laundry_reveal":
			_wait_ms = REVEAL_WAIT_MS
			_screen.call_deferred("_on_cost_pressed")
		elif _shot == "laundry_tap":
			# Bitmiş bir eşyaya (çamaşır makinesi) dokunma: görünüm seçici açılmalı.
			_screen.call_deferred("_tap_room", TAP_POINT)
		elif _shot == "laundry_full":
			# Son görevi gerçekten satın al: mekân tamamlama kartı + jeton ödülü görünsün.
			_screen.call_deferred("_on_cost_pressed")
			_screen.call_deferred("_on_confirm")
	else:
		_screen = (load(COLLECTION_SCENE) as PackedScene).instantiate()
		root.add_child(_screen)
