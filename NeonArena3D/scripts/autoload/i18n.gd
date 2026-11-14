extends Node
## Dil desteği. Türkçe metinler anahtar olarak kalır; İngilizce karşılıklar data/lang_en.json'da.
## Kart, harita ve boss adları kendi JSON kayıtlarındaki *_en alanlarından eklenir.

signal language_changed

const LANGS := ["tr", "en"]
const NAMES := {"tr": "TÜRKÇE", "en": "ENGLISH"}
const EN_PATH := "res://data/lang_en.json"

var _en: Translation
var keys: Dictionary = {}

func _ready() -> void:
	_en = Translation.new()
	_en.locale = "en"
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(EN_PATH))
	if parsed is Dictionary:
		for key in parsed:
			_add(str(key), str(parsed[key]))
	else:
		push_error("Çeviri dosyası okunamadı: " + EN_PATH)
	for card in GameData.cards:
		_add(str(card.get("name", "")), str(card.get("name_en", "")))
		_add(str(card.get("desc", "")), str(card.get("desc_en", "")))
	for theme in GameData.maps:
		_add(str(theme.get("name", "")), str(theme.get("name_en", "")))
		_add(str(theme.get("boss_name", "")), str(theme.get("boss_name_en", "")))
	for list in [GameData.ships, GameData.upgrades]:
		for entry in list:
			_add(str(entry.get("name", "")), str(entry.get("name_en", "")))
			_add(str(entry.get("desc", "")), str(entry.get("desc_en", "")))
			_add(str(entry.get("weapon_name", "")), str(entry.get("weapon_name_en", "")))
	TranslationServer.add_translation(_en)
	TranslationServer.set_locale(Settings.language)

func _add(key: String, value: String) -> void:
	if key == "" or value == "":
		return
	keys[key] = value
	_en.add_message(key, value)

func set_language(code: String) -> void:
	if not code in LANGS:
		code = "en"
	Settings.set_value("language", code)
	TranslationServer.set_locale(code)
	language_changed.emit()

func next_language() -> String:
	return LANGS[(LANGS.find(Settings.language) + 1) % LANGS.size()]

func has_key(text: String) -> bool:
	return keys.has(text)
