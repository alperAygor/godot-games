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
