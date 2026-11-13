class_name UiData
extends RefCounted

## Arayüzün veri kaynağı. `Progress` autoload'u başka bir işçi tarafından yazılıyor;
## burada ona yalnız `get_node_or_null` ile ve savunmacı biçimde bağlanılır, yoksa
## (ör. prob/testler) makul varsayılanlara düşülür. Böylece arayüz tek başına çalışır.

const PROGRESS_PATH: NodePath = ^"/root/Progress"
const LEGACY_SAVE_PATH: String = "user://progress.cfg"
const STATE_PATH: String = "user://ui_state.cfg"
const STATE_SECTION: String = "ui"
const KEY_HOME_SEEN: String = "home_seen"
const SETTING_SOUND: String = "sound"
const SETTING_MUSIC: String = "music"
const SETTING_VIBRATION: String = "vibration"
const MAX_STREAK: int = 3
## Ayar modülü (Progress.module_value): bildirim ve desen tercihleri burada durur.
## `notifications` anahtarını Notifier ileride okur (varsayılan açık); `patterns` renk desenleridir.
const SETTINGS_MODULE: String = "settings"
const SETTING_NOTIFICATIONS: String = "notifications"
const SETTING_PATTERNS: String = "patterns"
const COLOR_PATTERNS_PATH: String = "res://scripts/game/color_patterns.gd"
const ADS_PRIVACY_METHOD: String = "show_privacy_options"
const ADS_PATH: NodePath = ^"/root/AdManager"
## Progress yokken ayarların bellekteki yedeği (oturum boyunca korunur).
static var _fallback_settings: Dictionary = {}


static func progress() -> Node:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop == null:
		return null
	return loop.root.get_node_or_null(PROGRESS_PATH)


static func _legacy_value(key: String, default_value: int) -> int:
	var config: ConfigFile = ConfigFile.new()
	if config.load(LEGACY_SAVE_PATH) != OK:
		return default_value
	return int(config.get_value("progress", key, default_value))


static func _call_int(method: String, fallback: int) -> int:
	var node: Node = progress()
	if node != null and node.has_method(method):
		return int(node.call(method))
	return fallback


static func level() -> int:
	return maxi(_call_int("level", _legacy_value("level", 1)), 1)


static func coins() -> int:
	return maxi(_call_int("coins", _legacy_value("coins", 0)), 0)


static func stars() -> int:
	return maxi(_call_int("stars", 0), 0)


static func streak() -> int:
	return clampi(_call_int("streak", 0), 0, MAX_STREAK)


## Veri değişince haber veren sinyal (varsa). Yoksa bağlanmaz.
static func connect_changed(callable: Callable) -> void:
	var node: Node = progress()
	if node != null and node.has_signal("changed") and not node.is_connected("changed", callable):
		node.connect("changed", callable)


static func setting(key: String) -> bool:
	var node: Node = progress()
	if node != null and node.has_method("setting"):
		return bool(node.call("setting", key))
	return bool(_fallback_settings.get(key, true))


static func set_setting(key: String, value: bool) -> void:
	_fallback_settings[key] = value
	var node: Node = progress()
	if node != null and node.has_method("set_setting"):
		node.call("set_setting", key, value)
	apply_audio_settings()


## Ayar modülündeki mantıksal tercih (Progress yoksa yedek bellek). Gelecekteki işçiler için tek kapı.
static func module_flag(key: String, default_value: bool) -> bool:
	var node: Node = progress()
	if node != null and node.has_method("module_value"):
		return bool(node.call("module_value", SETTINGS_MODULE, key, default_value))
	return bool(_fallback_settings.get("module_" + key, default_value))


static func set_module_flag(key: String, value: bool) -> void:
	_fallback_settings["module_" + key] = value
	var node: Node = progress()
	if node != null and node.has_method("set_module_value"):
		node.call("set_module_value", SETTINGS_MODULE, key, value)


## Renk desenleri sınıfı (başka işçi ekliyor) çalışma anında var mı? Yoksa satır hiç çizilmez.
static func patterns_available() -> bool:
	return ResourceLoader.exists(COLOR_PATTERNS_PATH)


## Deseni açar/kapar: sınıf yoksa yalnız tercih kaydedilir; varsa statik `set_enabled` çağrılır.
static func apply_patterns(on: bool) -> void:
	set_module_flag(SETTING_PATTERNS, on)
	if patterns_available():
		var script: Script = load(COLOR_PATTERNS_PATH) as Script
		if script != null and script.has_method("set_enabled"):
			script.call("set_enabled", on)


## Desen durumu: sınıf `is_enabled` sunuyorsa onu, yoksa kayıtlı tercihi okur (varsayılan kapalı).
static func patterns_on() -> bool:
	if patterns_available():
		var script: Script = load(COLOR_PATTERNS_PATH) as Script
		if script != null and script.has_method("is_enabled"):
			return bool(script.call("is_enabled"))
	return module_flag(SETTING_PATTERNS, false)


## Reklam katmanında gizlilik seçenekleri formu varsa true (SDK işi başka yerde; burada yalnız kanca).
static func privacy_options_available() -> bool:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop == null:
		return false
	var ads: Node = loop.root.get_node_or_null(ADS_PATH)
	return ads != null and ads.has_method(ADS_PRIVACY_METHOD)


static func show_privacy_options() -> void:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop == null:
		return
	var ads: Node = loop.root.get_node_or_null(ADS_PATH)
	if ads != null and ads.has_method(ADS_PRIVACY_METHOD):
		ads.call(ADS_PRIVACY_METHOD)


## Kayıtlı ses/müzik ayarını AudioService'e uygular (açılışta ve her değişimde).
static func apply_audio_settings() -> void:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop == null:
		return
	var audio: Node = loop.root.get_node_or_null("AudioService")
	if audio == null:
		return
	audio.call("set_sound_enabled", setting(SETTING_SOUND))
	audio.call("set_music_enabled", setting(SETTING_MUSIC))


## Titreşim ayarına saygılı sarmalayıcı; oyun `Input.vibrate_handheld` yerine bunu çağırır.
static func vibrate(milliseconds: int) -> void:
	if setting(SETTING_VIBRATION):
		Input.vibrate_handheld(milliseconds)


## Ana ekran hiç görülmediyse ve oyuncu sıfırdaysa true döner ve bayrağı kaydeder:
## ilk açılış menüsüz doğrudan 1. seviyeye girer, sonrakiler Home'a gider.
static func consume_first_launch() -> bool:
	var config: ConfigFile = ConfigFile.new()
	var _loaded: Error = config.load(STATE_PATH)
	if bool(config.get_value(STATE_SECTION, KEY_HOME_SEEN, false)):
		return false
	config.set_value(STATE_SECTION, KEY_HOME_SEEN, true)
	var _saved: Error = config.save(STATE_PATH)
	return level() <= 1 and coins() == 0
