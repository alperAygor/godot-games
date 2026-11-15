class_name UiData
extends RefCounted

## Arayüzün veri kaynağı. `Progress` autoload'una yalnız `get_node_or_null` ile ve savunmacı
## biçimde bağlanılır; yoksa (ör. autoload'suz araç/test) makul varsayılanlara düşülür.
## Böylece arayüz sınıfları tek başına örneklenebilir.

const PROGRESS_PATH: NodePath = ^"/root/Progress"
const SETTING_SOUND: String = "sound"
const SETTING_MUSIC: String = "music"
const SETTING_VIBRATION: String = "vibration"
## Ayar modülü (Progress.module_value): bayrak olmayan tercihler burada durur.
const SETTINGS_MODULE: String = "settings"
const ADS_PRIVACY_METHOD: String = "show_privacy_options"
const ADS_PATH: NodePath = ^"/root/AdManager"
## Progress yokken ayarların bellekteki yedeği (oturum boyunca korunur).
static var _fallback_settings: Dictionary = {}


static func progress() -> Node:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop == null:
		return null
	return loop.root.get_node_or_null(PROGRESS_PATH)


static func _call_int(method: String, fallback: int) -> int:
	var node: Node = progress()
	if node != null and node.has_method(method):
		return int(node.call(method))
	return fallback


static func level() -> int:
	return maxi(_call_int("level", 1), 1)


static func coins() -> int:
	return maxi(_call_int("coins", 0), 0)


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


## Ayar modülündeki mantıksal tercih (Progress yoksa yedek bellek). Yeni tercihler için tek kapı.
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
