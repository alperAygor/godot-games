class_name ProgressData
extends RefCounted

## Oyuncu ilerlemesinin SAF mantığı (sahne/dosya yok): seviye, jeton, yıldız, galibiyet serisi,
## güçlendirici sayıları, ayarlar, görülen bayraklar ve reklam sıklığı sayaçları.
## Disk işi `Progress` autoload'unda; bu sınıf yalnız kural ve (de)serileştirme bilir,
## böylece birim testi dosya sistemine dokunmadan kuralları sınar.

const SAVE_VERSION: int = 1
const BALANCE_PATH: String = "res://data/balance.json"
## Bozuk/devasa kayıt değerleri int taşmasına yol açmasın diye üst sınır.
const MAX_VALUE: int = 1000000000

const BOOSTER_UNDO: String = "undo"
const BOOSTER_PIN_REMOVER: String = "pin_remover"
const BOOSTER_EXTRA_SLOT: String = "extra_slot"
const BOOSTER_IDS: Array[String] = [BOOSTER_UNDO, BOOSTER_PIN_REMOVER, BOOSTER_EXTRA_SLOT]
const SETTING_KEYS: Array[String] = ["sound", "music", "vibration"]
## Açılışta tüm ayarlar açıktır.
const SETTING_DEFAULT: bool = true
## Ücretsiz güçlendirici hediyesinin bir kez verildiğini işaretleyen bayrak öneki.
const GRANT_FLAG_PREFIX: String = "booster_grant_"

## balance.json okunamazsa kullanılan yedek; asıl değerler dosyadadır.
const DEFAULT_BALANCE: Dictionary = {
	"win_coins": 20,
	"hard_win_coins": 40,
	"stars_per_level": 1,
	"continue_cost": 100,
	"double_coins_multiplier": 2,
	"refill_booster_grant": 1,
	"streak_wins_for_extra_slot": 3,
	"booster_unlock_grant": 2,
	"booster_cost": {"undo": 60, "pin_remover": 80, "extra_slot": 100},
	"booster_unlock_level": {"undo": 6, "pin_remover": 12, "extra_slot": 18},
	"interstitial": {
		"first_level": 4, "min_levels_between": 2, "max_levels_between": 3,
		"min_seconds_between": 90, "rewarded_cooldown_seconds": 120,
	},
}

var level: int = 1
var coins: int = 0
var stars: int = 0
var streak: int = 0
var best_streak: int = 0
var boosters: Dictionary = {}
var settings: Dictionary = {}
var seen_flags: Dictionary = {}
var levels_since_interstitial: int = 0
var last_interstitial_time: float = 0.0
var last_rewarded_time: float = 0.0
## Özellik modüllerinin (günlük bulmaca, koleksiyon, onarım, yıldız dereceleri...) kendi
## verisi: bölüm -> sözlük. Her modül yalnız KENDİ bölümünü yazar; böylece modüller bu
## dosyayı değiştirmeden kayıt tutar ve birbirinin alanına dokunmaz.
var modules: Dictionary = {}


func _init() -> void:
	for id: String in BOOSTER_IDS:
		boosters[id] = 0
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
	data.stars = to_count(raw.get("stars"))
	data.streak = to_count(raw.get("streak"))
	data.best_streak = maxi(to_count(raw.get("best_streak")), data.streak)
	var raw_boosters: Variant = raw.get("boosters")
	if raw_boosters is Dictionary:
		for id: String in BOOSTER_IDS:
			data.boosters[id] = to_count((raw_boosters as Dictionary).get(id))
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
		"level": level, "coins": coins, "stars": stars,
		"streak": streak, "best_streak": best_streak,
		"boosters": boosters.duplicate(), "settings": settings.duplicate(),
		"seen": flags,
		"levels_since_interstitial": levels_since_interstitial,
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


# --- Seviye / seri -----------------------------------------------------------

## Kazanç: seviye ilerler, ödül eklenir, seri artar. Dönen değerler BU seviyenin kazancıdır.
func complete_level(hard: bool, balance: Dictionary) -> Dictionary:
	var reward: int = to_count(balance.get("hard_win_coins" if hard else "win_coins"))
	var star_gain: int = to_count(balance.get("stars_per_level"))
	add_coins(reward)
	stars = clampi(stars + star_gain, 0, MAX_VALUE)
	streak = clampi(streak + 1, 0, MAX_VALUE)
	best_streak = maxi(best_streak, streak)
	level = clampi(level + 1, 1, MAX_VALUE)
	levels_since_interstitial = clampi(levels_since_interstitial + 1, 0, MAX_VALUE)
	grant_unlocked_boosters(balance)
	return {"coins": reward, "stars": star_gain, "streak": streak,
		"streak_bonus": streak_extra_slot(balance)}


## Kayıp seriyi sıfırlar (ve bonus askıyı da götürür).
func fail_level() -> void:
	streak = 0


## Seri eşiğine ulaşıldıysa sonraki seviye +1 askıyla başlar; kayba dek sürer.
func streak_extra_slot(balance: Dictionary) -> bool:
	var needed: int = to_count(balance.get("streak_wins_for_extra_slot"), 3)
	return needed > 0 and streak >= needed


# --- Güçlendiriciler ---------------------------------------------------------

func booster_count(id: String) -> int:
	return to_count(boosters.get(id))


func add_booster(id: String, amount: int) -> void:
	if not BOOSTER_IDS.has(id):
		return
	boosters[id] = clampi(booster_count(id) + amount, 0, MAX_VALUE)


func use_booster(id: String) -> bool:
	if booster_count(id) <= 0:
		return false
	boosters[id] = booster_count(id) - 1
	return true


## Seviyesi açılmış her güçlendiriciye hediyeyi BİR kez verir. Bayrakla idempotent:
## eski kaydı olan oyuncu da ilk yüklemede eksik hediyesini alır, tekrar tekrar almaz.
func grant_unlocked_boosters(balance: Dictionary) -> bool:
	var unlock_levels: Variant = balance.get("booster_unlock_level")
	if not (unlock_levels is Dictionary):
		return false
	var grant: int = to_count(balance.get("booster_unlock_grant"))
	var changed: bool = false
	for id: String in BOOSTER_IDS:
		var flag: String = GRANT_FLAG_PREFIX + id
		var unlock_at: int = to_count((unlock_levels as Dictionary).get(id), MAX_VALUE)
		if level >= unlock_at and not seen_flags.has(flag):
			seen_flags[flag] = true
			add_booster(id, grant)
			changed = true
	return changed


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
