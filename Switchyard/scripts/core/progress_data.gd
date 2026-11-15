class_name ProgressData
extends RefCounted

## Oyuncu ilerlemesinin SAF mantığı (sahne/dosya yok): ayarlar, görülen bayraklar, modül verisi ve
## reklam zaman damgaları. Jeton ekonomisi YOKTUR (sahibinin kararı); seviye ilerlemesi `LevelProgress`
## tarafından "levels" modülünde tutulur.
## Disk işi `Progress` autoload'unda; bu sınıf yalnız kural ve (de)serileştirme bilir,
## böylece birim testi dosya sistemine dokunmadan kuralları sınar.
## Oyuna özgü kayıt (yıldız, envanter, koleksiyon...) bu sınıfa alan eklenerek DEĞİL,
## `modules` altında kendi bölümüyle tutulur (bkz. `Progress.set_module_value`).

const SAVE_VERSION: int = 2
const BALANCE_PATH: String = "res://data/balance.json"
## Bozuk/devasa kayıt değerleri int taşmasına yol açmasın diye üst sınır.
const MAX_VALUE: int = 1000000000

const SETTING_KEYS: Array[String] = ["sound", "music", "vibration"]
## Açılışta tüm ayarlar açıktır.
const SETTING_DEFAULT: bool = true

## balance.json okunamazsa kullanılan yedek; asıl değerler dosyadadır.
const DEFAULT_BALANCE: Dictionary = {
	"require_online": true,
	"three_star_slack": 0,
}

var settings: Dictionary = {}
var seen_flags: Dictionary = {}
var last_interstitial_time: float = 0.0
var last_rewarded_time: float = 0.0
## Özellik modüllerinin kendi verisi: bölüm -> sözlük. Her modül yalnız KENDİ bölümünü yazar;
## böylece modüller bu dosyayı değiştirmeden kayıt tutar ve birbirinin alanına dokunmaz.
## Hazır bölümler: "settings" (dil), "shop" (remove_ads sahipliği), "levels" (seviye kayıtları).
var modules: Dictionary = {}


func _init() -> void:
	for key: String in SETTING_KEYS:
		settings[key] = SETTING_DEFAULT


## balance.json + yedek değerler (eksik anahtarlar yedekten tamamlanır).
static func load_balance() -> Dictionary:
	var merged: Dictionary = DEFAULT_BALANCE.duplicate(true)
	if not FileAccess.file_exists(BALANCE_PATH):
		return merged
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BALANCE_PATH))
	if parsed is Dictionary:
		for key: Variant in (parsed as Dictionary).keys():
			var value: Variant = (parsed as Dictionary)[key]
			if value is Dictionary and merged.get(key) is Dictionary:
				(merged[key] as Dictionary).merge(value as Dictionary, true)
			else:
				merged[key] = value
	return merged


## JSON'dan gelen sayılar float'tır ("3.0"); metin/NaN/negatif gibi bozuk değer varsayılana düşer.
static func to_count(value: Variant, fallback: int = 0) -> int:
	if value is int:
		return clampi(value as int, 0, MAX_VALUE)
	if value is float:
		var number: float = value as float
		if is_nan(number) or is_inf(number):
			return fallback
		return clampi(int(number), 0, MAX_VALUE)
	return fallback


static func from_dict(source: Variant) -> ProgressData:
	var data: ProgressData = ProgressData.new()
	if not (source is Dictionary):
		return data
	var raw: Dictionary = source as Dictionary
	var raw_settings: Variant = raw.get("settings")
	if raw_settings is Dictionary:
		for key: String in SETTING_KEYS:
			var flag: Variant = (raw_settings as Dictionary).get(key)
			data.settings[key] = flag if flag is bool else SETTING_DEFAULT
	var raw_seen: Variant = raw.get("seen")
	if raw_seen is Array:
		for flag: Variant in raw_seen as Array:
			if flag is String and not (flag as String).is_empty():
				data.seen_flags[flag] = true
	data.last_interstitial_time = _to_time(raw.get("last_interstitial_time"))
	data.last_rewarded_time = _to_time(raw.get("last_rewarded_time"))
	var raw_modules: Variant = raw.get("modules")
	if raw_modules is Dictionary:
		for section: Variant in (raw_modules as Dictionary).keys():
			var entry: Variant = (raw_modules as Dictionary)[section]
			if section is String and entry is Dictionary:
				data.modules[section] = (entry as Dictionary).duplicate(true)
	return data


func to_dict() -> Dictionary:
	var flags: Array[String] = []
	for flag: Variant in seen_flags.keys():
		flags.append(String(flag))
	flags.sort()
	return {
		"version": SAVE_VERSION,
		"settings": settings.duplicate(),
		"seen": flags,
		"last_interstitial_time": last_interstitial_time,
		"last_rewarded_time": last_rewarded_time,
		"modules": modules.duplicate(true),
	}


static func _to_time(value: Variant) -> float:
	if value is int or value is float:
		var number: float = float(value)
		if not is_nan(number) and not is_inf(number) and number > 0.0:
			return number
	return 0.0


# --- Ayar / bayrak -----------------------------------------------------------

func setting(key: String) -> bool:
	return bool(settings.get(key, SETTING_DEFAULT))


func set_setting(key: String, value: bool) -> void:
	if SETTING_KEYS.has(key):
		settings[key] = value


func seen(flag: String) -> bool:
	return seen_flags.has(flag)


func mark_seen(flag: String) -> void:
	if not flag.is_empty():
		seen_flags[flag] = true
