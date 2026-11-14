extends Node
## Kullanıcı ayarları (ses seviyeleri, titreşim, dil). user://settings.cfg içinde ConfigFile olarak saklanır.

signal setting_changed(section: String, key: String, value: Variant)

const SETTINGS_PATH := "user://settings.cfg"
const LANGUAGES_PATH := "res://data/languages.json"
## language "" = cihaz dili (destekleniyorsa), değilse data/languages.json'daki "default".
const DEFAULTS := {
	"audio": {"master": 1.0, "music": 0.8, "sfx": 1.0},
	"game": {"vibration": true, "pixel_filter": true, "language": "", "analytics_consent": false, "consent_asked": false, "guide_seen": false},
}

var _config := ConfigFile.new()


func _ready() -> void:
	load_settings()
	apply_language()


## { "en": "English", "tr": "Türkçe" } — dil kodu → kendi dilindeki adı.
func available_languages() -> Dictionary:
	return JsonIO.read_dict(LANGUAGES_PATH).get("languages", {})


## Ayardaki dili (yoksa cihaz dilini) TranslationServer'a uygular ve uygulanan kodu döner.
func apply_language() -> String:
	var languages := available_languages()
	var chosen: String = get_value("game", "language")
	if chosen.is_empty():
		chosen = OS.get_locale_language()
	if not languages.has(chosen):
		chosen = JsonIO.read_dict(LANGUAGES_PATH).get("default", "en")
	TranslationServer.set_locale(chosen)
	return chosen


func load_settings() -> void:
	_config = ConfigFile.new()
	var err := _config.load(SETTINGS_PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		push_warning("SettingsManager: ayarlar okunamadı (hata %d), varsayılanlar kullanılıyor." % err)


func get_value(section: String, key: String) -> Variant:
	var default_value: Variant = DEFAULTS.get(section, {}).get(key)
	return _config.get_value(section, key, default_value)


func set_value(section: String, key: String, value: Variant, save_now := true) -> void:
	_config.set_value(section, key, value)
	if section == "game" and key == "language":
		apply_language()
	setting_changed.emit(section, key, value)
	if save_now:
		save_settings()


func save_settings() -> Error:
	return _config.save(SETTINGS_PATH)
