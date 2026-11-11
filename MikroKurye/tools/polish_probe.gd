extends SceneTree

## Cila kabul probu (Faz 6). Sözleşme: ARCHITECTURE.md §5.6.
##
##   godot --headless --path . -s res://tools/polish_probe.gd
##
## Kapsam: Şok Jeli, ses sayaçları (olay → ses), sessize alma, ayarlar kalıcılığı, ilk açılış rehberi.
## Çıkış: 0 geçti, 1 ölçüt başarısız, 2 kurulum hatası.
## Adımlar kuyruktadır (her biri N fizik karesi sonra): headless ve deterministik.
## `-s` modunda autoload kimliği derlenmez (GOTCHAS.md #2): autoload'lara `/root/...` yoluyla erişilir.

const SAVE_PATH: String = "user://polish_probe_save.json"
const GAME_SCENE: String = "res://scenes/Game.tscn"
const MENU_SCENE: String = "res://scenes/Menu.tscn"
const SETTINGS_SCENE: String = "res://scenes/Settings.tscn"
const GARAGE_SCENE: String = "res://scenes/Garage.tscn"
const DEADLINE_MS: int = 150000
const READY_FRAMES: int = 20
const SETTLE: int = 12
const SOUND_FILES: Array[String] = ["ui_tap", "success", "impact_light", "impact_heavy", "key_press", "delivery", "break_sound", "purchase", "revive", "boost"]

var _queue: Array[Dictionary] = []
var _wait: int = 0
var _frames: int = 0
var _start_ms: int = 0
var _failures: Array[String] = []
var _setup_error: String = ""
var _gm: Node = null
var _save: Node = null
var _audio: Node = null
var _ad: Node = null
var _scene: Node = null
var _ctl: Node = null
var _cargo: Node = null
var _count_before: int = 0
var _done: bool = false


func _initialize() -> void:
	_start_ms = Time.get_ticks_msec()
	_queue.append({"wait": 0, "fn": _setup})


func _enqueue(wait_frames: int, fn: Callable) -> void:
	_queue.append({"wait": wait_frames, "fn": fn})


func _physics_process(_delta: float) -> bool:
	if _done:
		return true
	if Time.get_ticks_msec() - _start_ms > DEADLINE_MS:
		_setup_error = "zaman aşımı"
	_frames += 1
	if _setup_error == "":
		# `wait` = bu adım çalıştıktan SONRA beklenecek kare sayısı. Kuyruk boşken de sayaç azalır,
		# böylece son adımın beklemesi bitince prob kendiliğinden sonlanır (aksi halde zaman aşımına kadar asılır).
		if _wait > 0:
			_wait -= 1
		elif not _queue.is_empty():
			var item: Dictionary = _queue.pop_front()
			_wait = int(item["wait"])
			(item["fn"] as Callable).call()
	if _setup_error != "" or (_queue.is_empty() and _wait <= 0):
		_finish()
	return _done


func _fail(message: String) -> void:
	_failures.append(message)


func _setup_fail(message: String) -> void:
	if _setup_error == "":
		_setup_error = message


func _state() -> Dictionary:
	return _ctl.call("state") as Dictionary


func _plays(sound: String) -> int:
	return int(_audio.call("play_count", sound))


func _wallet_dict() -> Dictionary:
	var p: Object = _save.call("profile") as Object
	return (p.call("wallet") as Object).call("to_dict") as Dictionary


func _setup() -> void:
	_gm = root.get_node_or_null("/root/GameManager")
	_save = root.get_node_or_null("/root/SaveService")
	_audio = root.get_node_or_null("/root/AudioService")
	_ad = root.get_node_or_null("/root/AdManager")
	if _gm == null or _save == null or _audio == null or _ad == null:
		_setup_fail("GameManager/SaveService/AudioService/AdManager autoload eksik")
		return
	for method: String in ["play_count", "set_muted", "is_muted", "play"]:
		if not _audio.has_method(method):
			_setup_fail("AudioService.%s() yok" % method)
	for method: String in ["setting", "set_setting"]:
		if not _save.has_method(method):
			_setup_fail("SaveService.%s() yok" % method)
	if _setup_error != "":
		return
	_gm.set("navigation_enabled", false)
	var prov: Object = _ad.get("provider") as Object
	if prov != null and "instant" in prov:
		prov.set("instant", true)
		prov.set("force_result", 1)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	_save.call("set_save_path", SAVE_PATH)
	_save.call("load_profile")
	_audio.call("set_muted", false)
	# ses tablosu ve dosyaları
	for sound: String in SOUND_FILES:
		if not bool(_audio.call("has_sound", sound)):
			_fail("data/sounds.json'da '%s' tanımlı değil" % sound)
		else:
			var table: Dictionary = (root.get_node_or_null("/root/GameData").call("table", "sounds")) as Dictionary
			var path: String = str(table.get(sound, ""))
			if not ResourceLoader.exists(path):
				_fail("ses dosyası yok: %s (%s)" % [sound, path])
	_enqueue(0, _shock_start)


# ---------------------------------------------------------------- Şok Jeli
func _shock_start() -> void:
	_save.call("grant", 1000, 60)
	var ok: bool = bool(_save.call("purchase", "shock_gel"))
	var mods: Dictionary = _save.call("mods") as Dictionary
	print("PROBE jel satın_alma ok=%s mods=%s" % [str(ok), str(mods)])
	if not ok:
		_fail("shock_gel satın alınamadı (upgrades.json'da kategori var mı?)")
	_gm.set("selected_cargo_id", "pencil_battery")
	_scene = (load(GAME_SCENE) as PackedScene).instantiate()
	root.add_child(_scene)
	_enqueue(READY_FRAMES, _shock_bind)


func _shock_bind() -> void:
	_ctl = get_first_node_in_group("game_controller")
	_cargo = get_first_node_in_group("cargo")
	if _ctl == null or _cargo == null:
		_setup_fail("game_controller/cargo bulunamadı")
		return
	var st: Dictionary = _state()
	print("PROBE jel jelly_left=%s" % str(st.get("jelly_left")))
	if int(st.get("jelly_left", -1)) != 1:
		_fail("shock_gel sahipken state.jelly_left == 1 olmalı: %s" % str(st.get("jelly_left")))
	_cargo.emit_signal("impact_reported", 5000.0)
	_enqueue(SETTLE, _shock_after_first)


func _shock_after_first() -> void:
	var st: Dictionary = _state()
	print("PROBE jel ilk_vuruş damage=%.2f broken=%s jelly_left=%s" % [float(st.get("damage", -1.0)), str(st.get("broken")), str(st.get("jelly_left"))])
	if bool(st.get("broken", true)):
		_fail("jel ilk kırıcı vuruşu emmeliydi (kargo kırılmamalı)")
	if absf(float(st.get("damage", 0.0)) - 0.95) > 0.001:
		_fail("jel emişi sonrası hasar 0.95 olmalı: %s" % str(st.get("damage")))
	if int(st.get("jelly_left", -1)) != 0:
		_fail("jel tüketilmeli: jelly_left=%s" % str(st.get("jelly_left")))
	_cargo.emit_signal("impact_reported", 5000.0)
	_enqueue(SETTLE, _shock_after_second)


func _shock_after_second() -> void:
	var st: Dictionary = _state()
	if not bool(st.get("broken", false)):
		_fail("ikinci kırıcı vuruş kargoyu kırmalı")
	_scene.queue_free()
	_enqueue(2, _audio_start)


# ---------------------------------------------------------------- Ses
func _audio_start() -> void:
	_gm.set("selected_cargo_id", "pencil_battery")
	_scene = (load(GAME_SCENE) as PackedScene).instantiate()
	root.add_child(_scene)
	_enqueue(READY_FRAMES, _audio_events)


func _audio_events() -> void:
	_ctl = get_first_node_in_group("game_controller")
	_cargo = get_first_node_in_group("cargo")
	_ctl.call("restart")
	var heavy0: int = _plays("impact_heavy")
	var light0: int = _plays("impact_light")
	_cargo.emit_signal("impact_reported", 12.0)
	_enqueue(8, _audio_check_heavy.bind(heavy0, light0))


func _audio_check_heavy(heavy0: int, light0: int) -> void:
	var heavy1: int = _plays("impact_heavy")
	print("PROBE ses ağır_çarpma %d -> %d" % [heavy0, heavy1])
	if heavy1 != heavy0 + 1:
		_fail("impulse 12 'impact_heavy' çalmalı (%d -> %d)" % [heavy0, heavy1])
	_enqueue(10, _audio_light.bind(light0))


func _audio_light(light0: int) -> void:
	_cargo.emit_signal("impact_reported", 4.0)
	_enqueue(8, _audio_check_light.bind(light0))


func _audio_check_light(light0: int) -> void:
	var light1: int = _plays("impact_light")
	print("PROBE ses hafif_çarpma %d -> %d" % [light0, light1])
	if light1 != light0 + 1:
		_fail("impulse 4 'impact_light' çalmalı (%d -> %d)" % [light0, light1])
	# sıklık sınırı: aynı karede iki darbe tek ses
	var h0: int = _plays("impact_heavy")
	_cargo.emit_signal("impact_reported", 12.0)
	_cargo.emit_signal("impact_reported", 12.0)
	_enqueue(8, _audio_check_gap.bind(h0))


func _audio_check_gap(h0: int) -> void:
	var h1: int = _plays("impact_heavy")
	print("PROBE ses sıklık_sınırı %d -> %d" % [h0, h1])
	if h1 - h0 > 1:
		_fail("80 ms içinde iki darbe tek ses çalmalı (%d -> %d)" % [h0, h1])
	_ctl.call("restart")
	var d0: int = _plays("delivery")
	var zone: Node3D = _scene.find_child("DeliveryZone", true, false) as Node3D
	var robot: Node3D = get_first_node_in_group("robot") as Node3D
	robot.global_position = zone.global_position + Vector3(0.0, 0.6, 0.0)
	_enqueue(30, _audio_check_delivery.bind(d0))


func _audio_check_delivery(d0: int) -> void:
	var d1: int = _plays("delivery")
	print("PROBE ses teslimat %d -> %d" % [d0, d1])
	if d1 < d0 + 1:
		_fail("teslimat 'delivery' çalmalı (%d -> %d)" % [d0, d1])
	_scene.queue_free()
	# sessize alma
	_audio.call("set_muted", true)
	var t0: int = _plays("ui_tap")
	_audio.call("play", "ui_tap")
	var muted_ok: bool = bool(_audio.call("is_muted")) and _plays("ui_tap") == t0
	print("PROBE ses sessiz is_muted=%s sayaç_değişmedi=%s" % [str(_audio.call("is_muted")), str(_plays("ui_tap") == t0)])
	if not muted_ok:
		_fail("sessizken play sayaç artırmamalı ve is_muted true olmalı")
	_audio.call("set_muted", false)
	var t1: int = _plays("ui_tap")
	_audio.call("play", "ui_tap")
	if _plays("ui_tap") != t1 + 1:
		_fail("sessiz kapatılınca play sayaç artırmalı")
	_enqueue(2, _settings_start)


# ---------------------------------------------------------------- Ayarlar + rehber
func _settings_start() -> void:
	_save.call("load_profile")
	var packed: PackedScene = load(SETTINGS_SCENE) as PackedScene
	if packed == null:
		_setup_fail("%s yüklenemedi" % SETTINGS_SCENE)
		return
	_scene = packed.instantiate()
	root.add_child(_scene)
	_enqueue(5, _settings_toggle)


func _settings_toggle() -> void:
	var toggle: BaseButton = _scene.find_child("SoundToggle", true, false) as BaseButton
	if toggle == null:
		_fail("Settings'te SoundToggle yok")
		_scene.queue_free()
		_enqueue(2, _tutorial_start)
		return
	print("PROBE ayar başlangıç sound_on=%s toggle=%s" % [str(_save.call("setting", "sound_on")), str(toggle.get("button_pressed"))])
	if not bool(toggle.get("button_pressed")):
		_fail("varsayılan: SoundToggle açık olmalı")
	toggle.set("button_pressed", false)   # toggled sinyali yayılır
	toggle.toggled.emit(false)
	_enqueue(SETTLE, _settings_check)


func _settings_check() -> void:
	var on: bool = bool(_save.call("setting", "sound_on"))
	print("PROBE ayar sonra sound_on=%s muted=%s" % [str(on), str(_audio.call("is_muted"))])
	if on:
		_fail("SoundToggle kapatınca sound_on false olmalı")
	if not bool(_audio.call("is_muted")):
		_fail("sound_on=false iken AudioService sessiz olmalı")
	_save.call("load_profile")   # kalıcılık
	if bool(_save.call("setting", "sound_on")):
		_fail("sound_on ayarı kalıcı değil")
	_save.call("set_setting", "sound_on", true)
	_audio.call("set_muted", false)
	_scene.queue_free()
	_enqueue(2, _tutorial_start)


func _tutorial_start() -> void:
	_save.call("set_setting", "tutorial_done", false)
	_scene = (load(MENU_SCENE) as PackedScene).instantiate()
	root.add_child(_scene)
	_enqueue(5, _tutorial_check)


func _tutorial_check() -> void:
	var panel: Control = _scene.find_child("TutorialPanel", true, false) as Control
	if panel == null:
		_fail("Menu'de TutorialPanel yok")
		_enqueue(1, _noop)
		return
	print("PROBE rehber başlangıç görünür=%s" % str(panel.visible))
	if not panel.visible:
		_fail("tutorial_done=false iken TutorialPanel görünür olmalı")
	var presses: int = 0
	while panel.visible and presses < 6:
		var next_btn: BaseButton = _scene.find_child("TutorialNextButton", true, false) as BaseButton
		if next_btn == null:
			_fail("TutorialNextButton yok")
			break
		next_btn.pressed.emit()
		presses += 1
	print("PROBE rehber basış=%d görünür=%s" % [presses, str(panel.visible)])
	if panel.visible:
		_fail("rehber en fazla 6 basışta kapanmalı")
	if not bool(_save.call("setting", "tutorial_done")):
		_fail("rehber bitince tutorial_done true kaydedilmeli")
	_scene.queue_free()
	_enqueue(2, _tutorial_again)


func _tutorial_again() -> void:
	_scene = (load(MENU_SCENE) as PackedScene).instantiate()
	root.add_child(_scene)
	_enqueue(5, _tutorial_hidden)


func _tutorial_hidden() -> void:
	var panel: Control = _scene.find_child("TutorialPanel", true, false) as Control
	if panel != null and panel.visible:
		_fail("rehber bir kez gösterilmeli: tutorial_done iken TutorialPanel gizli olmalı")
	if _scene.find_child("SettingsButton", true, false) == null:
		_fail("Menu'de SettingsButton yok")


func _noop() -> void:
	pass


func _finish() -> void:
	if _done:
		return
	_done = true
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
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
