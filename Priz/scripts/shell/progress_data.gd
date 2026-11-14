class_name ProgressData
extends RefCounted

## Oyuncu ilerlemesinin SAF mantığı (sahne/dosya yok): seviye, jeton, ayarlar, görülen bayraklar,
## modül verisi ve reklam sıklığı sayaçları.
## Disk işi `Progress` autoload'unda; bu sınıf yalnız kural ve (de)serileştirme bilir,
## böylece birim testi dosya sistemine dokunmadan kuralları sınar.
## Oyuna özgü kayıt (yıldız, envanter, koleksiyon...) bu sınıfa alan eklenerek DEĞİL,
## `modules` altında kendi bölümüyle tutulur (bkz. `Progress.set_module_value`).

const SAVE_VERSION: int = 1
const BALANCE_PATH: String = "res://data/balance.json"
## Bozuk/devasa kayıt değerleri int taşmasına yol açmasın diye üst sınır.
const MAX_VALUE: int = 1000000000

const SETTING_KEYS: Array[String] = ["sound", "music", "vibration"]
## Açılışta tüm ayarlar açıktır.
const SETTING_DEFAULT: bool = true
## Görsel kalite kademesi (yüksek/orta/düşük); varsayılan yüksek. Dil ayarı `Loc` tarafından
## "settings" modülünde tutulur (bkz. Loc.SETTINGS_KEY).
const QUALITY_TIERS: Array[String] = ["high", "medium", "low"]
const QUALITY_DEFAULT: String = "high"
const MAX_STARS: int = 3

## balance.json okunamazsa kullanılan yedek; asıl değerler dosyadadır.
const DEFAULT_BALANCE: Dictionary = {
	"win_coins": 20,
	"double_coins_multiplier": 2,
	"require_online": true,
	"fuses_per_level": 3,
	"win_stars": 3,
	"coin_display": {"per_icon": 10, "max_icons": 5, "pile_from": 100},
	"level_pips": {"block": 5},
	"haptics": {"tick_ms": 12, "thud_ms": 35, "success_ms": 60},
}

var level: int = 1
var coins: int = 0
var settings: Dictionary = {}
var seen_flags: Dictionary = {}
var levels_since_interstitial: int = 0
## Şimdiye dek gösterilen geçiş reklamı sayısı (AdPacing aralık döngüsünün indeksi).
var interstitials_shown: int = 0
## Seviye -> yıldız (0-3). Yalnız en iyi sonuç tutulur; kaydedilmeyen seviye 0 yıldızdır.
var level_stars: Dictionary = {}
## Üst üste kazanılan seviye sayısı; kayıpta sıfırlanır.
var win_streak: int = 0
var quality_tier: String = QUALITY_DEFAULT
## SEVİYE BAŞINA, KAYDEDİLMEZ: kalan sigorta hakkı. `begin_level_fuses` ile kurulur.
var fuses_left: int = 0
var last_interstitial_time: float = 0.0
var last_rewarded_time: float = 0.0
## Özellik modüllerinin kendi verisi: bölüm -> sözlük. Her modül yalnız KENDİ bölümünü yazar;
## böylece modüller bu dosyayı değiştirmeden kayıt tutar ve birbirinin alanına dokunmaz.
## Hazır bölümler: "settings" (dil), "shop" (remove_ads sahipliği).
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
	data.level = maxi(to_count(raw.get("level"), 1), 1)
	data.coins = to_count(raw.get("coins"))
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
	data.levels_since_interstitial = to_count(raw.get("levels_since_interstitial"))
	data.interstitials_shown = to_count(raw.get("interstitials_shown"))
	data.win_streak = to_count(raw.get("win_streak"))
	var raw_quality: Variant = raw.get("quality_tier")
	data.quality_tier = String(raw_quality) if raw_quality is String and QUALITY_TIERS.has(raw_quality) else QUALITY_DEFAULT
	var raw_stars: Variant = raw.get("stars")
	if raw_stars is Dictionary:
		for key: Variant in (raw_stars as Dictionary).keys():
			var number: int = int(String(key)) if String(key).is_valid_int() else 0
			if number >= 1:
				data.set_stars(number, to_count((raw_stars as Dictionary)[key]))
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
	var stars_out: Dictionary = {}
	for key: Variant in level_stars.keys():
		stars_out[str(key)] = level_stars[key]
	return {
		"version": SAVE_VERSION,
		"level": level, "coins": coins,
		"settings": settings.duplicate(),
		"seen": flags,
		"levels_since_interstitial": levels_since_interstitial,
		"interstitials_shown": interstitials_shown,
		"stars": stars_out,
		"win_streak": win_streak,
		"quality_tier": quality_tier,
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


# --- Jeton -------------------------------------------------------------------

func add_coins(amount: int) -> void:
	coins = clampi(coins + amount, 0, MAX_VALUE)


func spend_coins(amount: int) -> bool:
	if amount < 0 or amount > coins:
		return false
	coins -= amount
	return true


# --- Seviye ------------------------------------------------------------------

## Kazanç: seviye ilerler, ödül eklenir, yıldız işlenir, seri artar. Dönen değerler BU seviyenin kazancıdır.
func complete_level(balance: Dictionary, stars: int = 1) -> Dictionary:
	var reward: int = to_count(balance.get("win_coins"))
	add_coins(reward)
	set_stars(level, stars)
	win_streak = clampi(win_streak + 1, 0, MAX_VALUE)
	var finished: int = level
	level = clampi(level + 1, 1, MAX_VALUE)
	levels_since_interstitial = clampi(levels_since_interstitial + 1, 0, MAX_VALUE)
	return {"coins": reward, "level": level, "finished_level": finished, "stars": stars_for(finished),
		"streak": win_streak}


## Kayıp: galibiyet serisi biter. Seviye ve jeton değişmez.
func record_loss() -> void:
	win_streak = 0


## Geçiş reklamı gösterildi: bekleme sayacı sıfırlanır, aralık döngüsü bir adım ilerler.
func note_interstitial(now: float) -> void:
	last_interstitial_time = now
	levels_since_interstitial = 0
	interstitials_shown = clampi(interstitials_shown + 1, 0, MAX_VALUE)


# --- Yıldız ------------------------------------------------------------------

func stars_for(for_level: int) -> int:
	return int(level_stars.get(for_level, 0))


## En iyi sonuç korunur (daha düşük yıldız eskisini ezmez).
func set_stars(for_level: int, count: int) -> void:
	if for_level < 1:
		return
	level_stars[for_level] = maxi(stars_for(for_level), clampi(count, 0, MAX_STARS))


func total_stars() -> int:
	var total: int = 0
	for key: Variant in level_stars.keys():
		total += int(level_stars[key])
	return total


# --- Sigorta hakkı (seviye başına, kaydedilmez) -------------------------------

func begin_level_fuses(count: int) -> void:
	fuses_left = clampi(count, 0, MAX_VALUE)


## Bir hak gider; kalan hak döner (0 = seviye kaybedilir ya da ödüllü ek hak sunulur).
func lose_fuse() -> int:
	fuses_left = maxi(fuses_left - 1, 0)
	return fuses_left


## Ödüllü reklamla +1 hak (`extra_fuse`).
func grant_extra_fuse() -> void:
	fuses_left = clampi(fuses_left + 1, 0, MAX_VALUE)


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


func set_quality_tier(tier: String) -> void:
	if QUALITY_TIERS.has(tier):
		quality_tier = tier
