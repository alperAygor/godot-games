extends Node
## Kullanıcı ayarları (ses seviyeleri, titreşim, dil). user://settings.cfg içinde ConfigFile olarak saklanır.
## Sağlamlık: yazma atomik (geçici dosya + doğrulama + rename), önceki geçerli dosya `.bak` olarak saklanır; ana dosya okunamazsa
## kenara (`settings.corrupt.<ts>.cfg`) alınır ve yedekten devam edilir; yanlış tipli değerler varsayılana döner.
## Betikle (`-s`: testler, araçlar) çalışırken yol gerçek `settings.cfg` DEĞİL, `JsonIO.SANDBOX_DIR` altıdır.

signal setting_changed(section: String, key: String, value: Variant)

## Ayar dosyasının şema sürümü ([meta] version). Anahtar adı/anlamı değişirse artır ve `_migrate` içine adım ekle.
const SETTINGS_VERSION := 1
const LANGUAGES_PATH := "res://data/languages.json"
## language "" = cihaz dili (destekleniyorsa), değilse data/languages.json'daki "default".
const DEFAULTS := {
	"audio": {"master": 1.0, "music": 0.8, "sfx": 1.0},
	"game": {"vibration": true, "pixel_filter": true, "language": "", "ads_personalized": false, "consent_asked": false, "guide_seen": false},
	# Erişilebilirlik (T-A2): text_size "normal"/"large" (Accessibility.TEXT_SIZES), renk körü paleti + işaretler, hareketi azalt.
	"access": {"text_size": "normal", "color_blind": false, "reduced_motion": false},
}

## Testler/araçlar değiştirebilir. Varsayılan: gerçek kullanıcı dosyası (betikli çalışmada sandbox).
var settings_path := JsonIO.user_file("settings.cfg")
## false ise `save_settings` diske hiç yazmaz (bellekte kalır).
var persist := true
var _config := ConfigFile.new()


func _ready() -> void:
	load_settings()
	apply_language()
	apply_accessibility()


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


## Yazı boyutu ve renk körü paletini kök temaya uygular (ayarlar değişince `set_value` de çağırır). Ağaçta değilse (testteki
## serbest örnekler) bir şey yapmaz.
func apply_accessibility() -> void:
	if is_inside_tree():
		A11y.apply(get_tree())


func load_settings() -> void:
	_config = ConfigFile.new()
	if not FileAccess.file_exists(settings_path) and not FileAccess.file_exists(JsonIO.backup_path(settings_path)):
		return
	if not _try_load(settings_path):
		if FileAccess.file_exists(settings_path):
			JsonIO.quarantine(settings_path)
		_config = ConfigFile.new()
		if _try_load(JsonIO.backup_path(settings_path)):
			save_settings()  # ana dosyayı yedekten yeniden yaz
		else:
			_config = ConfigFile.new()
			push_warning("SettingsManager: ayarlar okunamadı, varsayılanlar kullanılıyor.")
	_sanitize()
	_migrate()


## Dosyayı `_config` içine yükler; okunamıyorsa false.
func _try_load(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	if not _looks_like_config(FileAccess.get_file_as_string(path)):
		return false  # ConfigFile bozuk metinde motor hatası basar; bariz bozukları önceden ele
	var loaded := ConfigFile.new()
	if loaded.load(path) != OK:
		return false
	_config = loaded
	return true


## Her satır boş / yorum / `[bölüm]` / `anahtar=değer` mi? (yarım kalmış yazma genelde bunu bozar)
static func _looks_like_config(text: String) -> bool:
	if text.strip_edges().is_empty():
		return false
	for line in text.split("\n"):
		var trimmed := line.strip_edges()
		if trimmed.is_empty() or trimmed.begins_with(";") or trimmed.begins_with("#"):
			continue
		if trimmed.begins_with("["):
			if not trimmed.ends_with("]"):
				return false
		elif trimmed.find("=") < 1:
			return false
	return true


## Tipi varsayılanıyla uyuşmayan değerleri (elle/yarım bozulmuş dosya) atar: sayı<->sayı, bool, metin serbestçe karşılaştırılır.
func _sanitize() -> void:
	for section: String in DEFAULTS:
		for key: String in DEFAULTS[section]:
			if not _config.has_section_key(section, key):
				continue
			if not _same_kind(_config.get_value(section, key), DEFAULTS[section][key]):
				_config.erase_section_key(section, key)
	if _config.has_section_key("access", "text_size") and not Accessibility.TEXT_SIZES.has(str(_config.get_value("access", "text_size"))):
		_config.erase_section_key("access", "text_size")
	# Ses seviyeleri 0..1 dışına taşmasın.
	for key: String in DEFAULTS["audio"]:
		if _config.has_section_key("audio", key):
			_config.set_value("audio", key, clampf(float(_config.get_value("audio", key)), 0.0, 1.0))


static func _same_kind(value: Variant, reference: Variant) -> bool:
	var numeric := [TYPE_INT, TYPE_FLOAT]
	if typeof(reference) in numeric:
		return typeof(value) in numeric
	return typeof(value) == typeof(reference)


## Eski dosya sürümünü yükseltir (şimdilik tek sürüm var; ileride adımlar buraya).
func _migrate() -> void:
	var version := int(_config.get_value("meta", "version", 0))
	if version < 1:
		version = 1  # sürüm damgasından önceki dosyalar v1 şemasındadır
	# Gelecekte: if version == 1: ...; version = 2
	if version <= SETTINGS_VERSION:
		_config.set_value("meta", "version", version)


func get_value(section: String, key: String) -> Variant:
	var default_value: Variant = DEFAULTS.get(section, {}).get(key)
	return _config.get_value(section, key, default_value)


func set_value(section: String, key: String, value: Variant, save_now := true) -> void:
	_config.set_value(section, key, value)
	if section == "game" and key == "language":
		apply_language()
	elif section == "access" and key in ["text_size", "color_blind"]:
		apply_accessibility()
	setting_changed.emit(section, key, value)
	if save_now:
		save_settings()


func save_settings() -> Error:
	if not persist:
		return OK
	_config.set_value("meta", "version", maxi(SETTINGS_VERSION, int(_config.get_value("meta", "version", SETTINGS_VERSION))))
	var tmp_path := settings_path + ".tmp"
	var err := _config.save(tmp_path)
	if err != OK:
		return err
	var check := ConfigFile.new()
	if not _looks_like_config(FileAccess.get_file_as_string(tmp_path)) or check.load(tmp_path) != OK:  # yarım yazılmış: ana dosyaya dokunma
		DirAccess.remove_absolute(tmp_path)
		return ERR_FILE_CORRUPT
	var backup := ConfigFile.new()
	if FileAccess.file_exists(settings_path) and _looks_like_config(FileAccess.get_file_as_string(settings_path)) and backup.load(settings_path) == OK:  # yalnız GEÇERLİ eski dosya yedeğe geçer
		DirAccess.copy_absolute(settings_path, JsonIO.backup_path(settings_path))
	return DirAccess.rename_absolute(tmp_path, settings_path)
