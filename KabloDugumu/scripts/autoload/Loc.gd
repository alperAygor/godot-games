extends Node

## Metin yerelleştirme: res://data/i18n/<dil>.json + user://settings.cfg kalıcılığı.
## Kural: kullanıcıya görünen HİÇBİR metin koda gömülmez; hepsi Loc.t("anahtar") ile gelir.
## Yer tutucular süslü parantezledir: Loc.t("hud.level", {"n": 12, "name": "..."}) -> "BÖLÜM 12 · ..."

signal language_changed(locale: String)

const LOCALES: Array[String] = ["en", "tr"]
const LOCALE_LABELS: Dictionary = {"en": "English", "tr": "Türkçe"}
const DEFAULT_LOCALE: String = "en"
const SETTINGS_PATH: String = "user://settings.cfg"

var locale: String = DEFAULT_LOCALE

var _table: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var saved: String = _load_saved_locale()
	set_locale(saved if saved != "" else _detect_locale())


## Anahtar yoksa anahtarın kendisi döner (UI asla boş kalmaz) ve uyarı basılır.
func t(key: String, values: Dictionary = {}) -> String:
	var raw: Variant = _table.get(key)
	if raw == null:
		push_warning("Loc: eksik anahtar '%s' (%s)" % [key, locale])
		return key
	var text: String = String(raw)
	if values.is_empty():
		return text
	return text.format(values)


func has(key: String) -> bool:
	return _table.has(key)


func set_locale(code: String) -> void:
	var next: String = code if LOCALES.has(code) else DEFAULT_LOCALE
	var path: String = "res://data/i18n/%s.json" % next
	if not FileAccess.file_exists(path):
		push_error("Loc: dil dosyası yok: %s" % path)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		push_error("Loc: dil dosyası geçersiz: %s" % path)
		return
	_table = parsed as Dictionary
	locale = next
	_save_locale(next)
	language_changed.emit(next)


func toggle_locale() -> void:
	set_locale("tr" if locale == "en" else "en")


func locale_label() -> String:
	return String(LOCALE_LABELS.get(locale, locale))


func _detect_locale() -> String:
	if OS.get_locale().to_lower().begins_with("tr"):
		return "tr"
	return DEFAULT_LOCALE


func _load_saved_locale() -> String:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return ""
	var config: ConfigFile = ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return ""
	return String(config.get_value("ui", "locale", ""))


func _save_locale(code: String) -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("ui", "locale", code)
	config.save(SETTINGS_PATH)
