extends SceneTree

## Meta akışı kabul probu (Faz 4b). Sözleşme: ARCHITECTURE.md §5.4.
##
##   godot --headless --path . -s res://tools/meta_probe.gd
##
## Çıkış: 0 geçti, 1 ölçüt başarısız, 2 kurulum hatası.
## `-s` modunda autoload kimliği derlenmez (GOTCHAS.md #2): autoload'lara `/root/...` yoluyla erişilir.
## Gerçek kayıt dosyasına dokunmaz: `set_save_path("user://meta_probe_save.json")`.

const SAVE_PATH: String = "user://meta_probe_save.json"
const GAME_SCENE: String = "res://scenes/Game.tscn"
const ORDER_SCENE: String = "res://scenes/OrderSelect.tscn"
const GARAGE_SCENE: String = "res://scenes/Garage.tscn"
const DEADLINE_MS: int = 120000
const READY_FRAMES: int = 20
const BATTERY_FIRST_GOLD: int = 80
const BATTERY_FIRST_SCRAP: int = 3
const BATTERY_BONUS: float = 15.0

enum Phase { SYNC, GAME_WAIT, DONE }

var _phase: Phase = Phase.SYNC
var _frames: int = 0
var _phase_frames: int = 0
var _start_ms: int = 0
var _failures: Array[String] = []
var _setup_error: String = ""
var _save: Node = null
var _gm: Node = null
var _scene: Node = null
var _done: bool = false


func _initialize() -> void:
	_start_ms = Time.get_ticks_msec()


func _physics_process(_delta: float) -> bool:
	if _done:
		return true
	if Time.get_ticks_msec() - _start_ms > DEADLINE_MS:
		_setup_error = "zaman aşımı — faz %s" % Phase.keys()[_phase]
		_finish()
		return true
	_frames += 1
	_phase_frames += 1
	match _phase:
		Phase.SYNC: _step_sync()
		Phase.GAME_WAIT: _step_game_wait()
		_: pass
	if _setup_error != "" or _phase == Phase.DONE:
		_finish()
	return _done


func _fail(message: String) -> void:
	_failures.append(message)


func _setup_fail(message: String) -> void:
	if _setup_error == "":
		_setup_error = message


func _wallet() -> Dictionary:
	var p: Object = _save.call("profile") as Object
	return (p.call("wallet") as Object).call("to_dict") as Dictionary


func _level(category: String) -> int:
	var p: Object = _save.call("profile") as Object
	return int(p.call("level", category))


func _find_button(root_node: Node, node_name: String) -> BaseButton:
	return root_node.find_child(node_name, true, false) as BaseButton


func _label_text(root_node: Node, node_name: String) -> String:
	var n: Node = root_node.find_child(node_name, true, false)
	if n == null or not ("text" in n):
		return ""
	return str(n.get("text"))


func _step_sync() -> void:
	_save = root.get_node_or_null("/root/SaveService")
	_gm = root.get_node_or_null("/root/GameManager")
	if _save == null:
		_setup_fail("/root/SaveService autoload yok")
		return
	if _gm == null:
		_setup_fail("/root/GameManager autoload yok")
		return
	for method: String in ["profile", "set_save_path", "load_profile", "save_profile", "apply_result", "upgrade_cost", "purchase", "mods"]:
		if not _save.has_method(method):
			_setup_fail("SaveService.%s() yok" % method)
	if not ("navigation_enabled" in _gm):
		_setup_fail("GameManager.navigation_enabled yok")
	if _setup_error != "":
		return
	_gm.set("navigation_enabled", false)

	# 1) temiz başlangıç
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH + ".corrupt"))
	_save.call("set_save_path", SAVE_PATH)
	_save.call("load_profile")
	var w0: Dictionary = _wallet()
	if int(w0.get("gold", -1)) != 0 or int(w0.get("scrap", -1)) != 0:
		_fail("yeni profilin cüzdanı 0/0 olmalı: %s" % str(w0))

	# 2) sonuç uygula + kalıcılık + çift uygulama engeli
	var result: Dictionary = {"success": true, "gold": 100, "scrap": 6, "stars": 3, "cargo_id": "pencil_battery"}
	_save.call("apply_result", result)
	var w1: Dictionary = _wallet()
	print("PROBE kayıt apply_result cüzdan=%s" % str(w1))
	if int(w1.get("gold", -1)) != 100 or int(w1.get("scrap", -1)) != 6:
		_fail("apply_result cüzdanı 100/6 yapmalıydı: %s" % str(w1))
	if not FileAccess.file_exists(SAVE_PATH):
		_fail("apply_result kayıt dosyasını yazmadı")
	_save.call("apply_result", result)   # aynı sonuç ikinci kez
	var w1b: Dictionary = _wallet()
	if int(w1b.get("gold", -1)) != 100:
		_fail("aynı sonuç iki kez uygulandı: %s" % str(w1b))
	_save.call("load_profile")   # yeniden yükle = oyunu kapatıp açmak
	var w2: Dictionary = _wallet()
	if int(w2.get("gold", -1)) != 100 or int(w2.get("scrap", -1)) != 6:
		_fail("yeniden yüklemede cüzdan korunmadı: %s" % str(w2))

	# 3) satın alma
	var cost: Dictionary = _save.call("upgrade_cost", "battery") as Dictionary
	print("PROBE kayıt battery_maliyet=%s" % str(cost))
	if int(cost.get("gold", -1)) != BATTERY_FIRST_GOLD or int(cost.get("scrap", -1)) != BATTERY_FIRST_SCRAP:
		_fail("battery 1. seviye maliyeti %d/%d olmalı: %s" % [BATTERY_FIRST_GOLD, BATTERY_FIRST_SCRAP, str(cost)])
	var ok1: bool = bool(_save.call("purchase", "battery"))
	var w3: Dictionary = _wallet()
	if not ok1 or int(w3.get("gold", -1)) != 100 - BATTERY_FIRST_GOLD or int(w3.get("scrap", -1)) != 6 - BATTERY_FIRST_SCRAP or _level("battery") != 1:
		_fail("battery satın alma yanlış: ok=%s cüzdan=%s seviye=%d" % [str(ok1), str(w3), _level("battery")])
	var ok2: bool = bool(_save.call("purchase", "battery"))   # 160 altın gerekir, 20 var
	var w4: Dictionary = _wallet()
	if ok2 or _level("battery") != 1 or int(w4.get("gold", -1)) != int(w3.get("gold", -2)):
		_fail("yetersiz bakiyede satın alma değişiklik yapmamalı: ok=%s cüzdan=%s seviye=%d" % [str(ok2), str(w4), _level("battery")])
	if bool(_save.call("purchase", "yok_boyle_kategori")):
		_fail("bilinmeyen kategori satın alınamamalı")
	_save.call("load_profile")
	if _level("battery") != 1:
		_fail("satın alma kalıcı değil: battery seviye %d" % _level("battery"))

	# 4) mods
	var mods: Dictionary = _save.call("mods") as Dictionary
	print("PROBE kayıt mods=%s" % str(mods))
	if absf(float(mods.get("battery_capacity_bonus", -1.0)) - BATTERY_BONUS) > 0.001:
		_fail("mods.battery_capacity_bonus %.1f olmalı: %s" % [BATTERY_BONUS, str(mods)])

	# 5) bozuk dosya toleransı
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string("{bu json degil")
	f.close()
	_save.call("load_profile")
	var w5: Dictionary = _wallet()
	print("PROBE kayıt bozuk_dosya cüzdan=%s yedek=%s" % [str(w5), str(FileAccess.file_exists(SAVE_PATH + ".corrupt"))])
	if int(w5.get("gold", -1)) != 0:
		_fail("bozuk dosyada varsayılan profil beklenir: %s" % str(w5))
	if not FileAccess.file_exists(SAVE_PATH + ".corrupt"):
		_fail("bozuk dosya '.corrupt' olarak yedeklenmedi")

	# 6) UI: OrderSelect kartları
	var order_packed: PackedScene = load(ORDER_SCENE) as PackedScene
	if order_packed == null:
		_setup_fail("%s yüklenemedi" % ORDER_SCENE)
		return
	_scene = order_packed.instantiate()
	root.add_child(_scene)
	for cargo_id: String in ["pencil_battery", "sd_card", "espresso_capsule"]:
		var card: BaseButton = _find_button(_scene, "CargoCard_%s" % cargo_id)
		if card == null:
			_fail("OrderSelect'te CargoCard_%s yok" % cargo_id)
			continue
		card.pressed.emit()
		if str(_gm.get("selected_cargo_id")) != cargo_id:
			_fail("CargoCard_%s selected_cargo_id'yi ayarlamadı: %s" % [cargo_id, str(_gm.get("selected_cargo_id"))])
	if _find_button(_scene, "BackButton") == null:
		_fail("OrderSelect'te BackButton yok")
	_scene.queue_free()

	# 7) UI: Garage
	_save.call("load_profile")   # bozuk dosyadan temiz profil
	_save.call("apply_result", {"success": true, "gold": 500, "scrap": 30, "stars": 3, "cargo_id": "sd_card"})
	var garage_packed: PackedScene = load(GARAGE_SCENE) as PackedScene
	if garage_packed == null:
		_setup_fail("%s yüklenemedi" % GARAGE_SCENE)
		return
	_scene = garage_packed.instantiate()
	root.add_child(_scene)
	var gold_text: String = _label_text(_scene, "GoldLabel")
	var scrap_text: String = _label_text(_scene, "ScrapLabel")
	print("PROBE garaj etiketler gold='%s' scrap='%s'" % [gold_text, scrap_text])
	if not gold_text.contains("500"):
		_fail("GoldLabel 500 içermeli: '%s'" % gold_text)
	if not scrap_text.contains("30"):
		_fail("ScrapLabel 30 içermeli: '%s'" % scrap_text)
	for category: String in ["chassis", "wheels", "battery"]:
		if _find_button(_scene, "UpgradeButton_%s" % category) == null:
			_fail("Garage'da UpgradeButton_%s yok" % category)
	var buy: BaseButton = _find_button(_scene, "UpgradeButton_chassis")
	if buy != null:
		buy.pressed.emit()   # chassis 1: 100 altın + 5 hurda
		var w6: Dictionary = _wallet()
		print("PROBE garaj chassis_sonrası cüzdan=%s seviye=%d" % [str(w6), _level("chassis")])
		if _level("chassis") != 1 or int(w6.get("gold", -1)) != 400 or int(w6.get("scrap", -1)) != 25:
			_fail("Garage chassis satın alma yanlış: cüzdan=%s seviye=%d (beklenen 400/25, seviye 1)" % [str(w6), _level("chassis")])
		var gold_after: String = _label_text(_scene, "GoldLabel")
		if not gold_after.contains("400"):
			_fail("satın almadan sonra GoldLabel güncellenmedi: '%s'" % gold_after)
	if _find_button(_scene, "BackButton") == null:
		_fail("Garage'da BackButton yok")
	_scene.queue_free()

	# 8) Game efektleri: chassis 1 -> cargo_damping_bonus
	_gm.set("selected_cargo_id", "pencil_battery")
	var game_packed: PackedScene = load(GAME_SCENE) as PackedScene
	if game_packed == null:
		_setup_fail("%s yüklenemedi" % GAME_SCENE)
		return
	_scene = game_packed.instantiate()
	root.add_child(_scene)
	_phase_frames = 0
	_phase = Phase.GAME_WAIT


func _step_game_wait() -> void:
	if _phase_frames < READY_FRAMES:
		return
	var ctl: Node = get_first_node_in_group("game_controller")
	if ctl == null or not ctl.has_method("state"):
		_setup_fail("Game.tscn'de game_controller yok")
		return
	var mods: Variant = (ctl.call("state") as Dictionary).get("mods")
	print("PROBE game state.mods=%s" % str(mods))
	if not (mods is Dictionary):
		_fail("GameController.state()['mods'] sözlüğü yok")
	else:
		var md: Dictionary = mods as Dictionary
		if absf(float(md.get("cargo_damping_bonus", -1.0)) - 1.0) > 0.001:
			_fail("state.mods.cargo_damping_bonus 1.0 olmalı (chassis seviye 1): %s" % str(md))
	_phase = Phase.DONE


func _finish() -> void:
	if _done:
		return
	_done = true
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH + ".corrupt"))
	if _setup_error != "":
		print("PROBE KURULUM HATASI: %s" % _setup_error)
		quit(2)
		return
	if _failures.is_empty():
		print("PROBE SONUC: gecti (kare %d)" % _frames)
		quit(0)
	else:
		for f: String in _failures:
			print("PROBE HATA: %s" % f)
		print("PROBE SONUC: basarisiz (%d hata)" % _failures.size())
		quit(1)
