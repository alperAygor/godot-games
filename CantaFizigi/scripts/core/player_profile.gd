class_name PlayerProfile
extends RefCounted

## Kalici oyuncu verisi. Saf sinif: dosya/IO yok, sahne yok — bu yuzden test edilebilir.
## Sema degisirse SAVE_VERSION artirilir ve _migrate() icin yeni bir adim yazilir.

const SAVE_VERSION: int = 1

const DEFAULT_SETTINGS: Dictionary = {
	"music": 0.7,
	"sfx": 1.0,
	"haptics": true,
	"camera_shake": true,
}

var version: int = SAVE_VERSION
var currency: int = 0
var reputation: int = 3
var upgrades: Dictionary[String, int] = {}
var stats: Dictionary[String, int] = {}
var settings: Dictionary[String, Variant] = {}


static func create_default() -> PlayerProfile:
	var profile: PlayerProfile = PlayerProfile.new()
	for key: String in DEFAULT_SETTINGS:
		profile.settings[key] = DEFAULT_SETTINGS[key]
	return profile


## Kaydedilmis sozlukten profil kurar; eski semayi sessizce yukseltir.
static func from_dictionary(data: Dictionary) -> PlayerProfile:
	var profile: PlayerProfile = create_default()
	var found_version: int = int(data.get("version", 0))
	profile.currency = int(data.get("currency", 0))
	profile.reputation = int(data.get("reputation", 3))
	profile.upgrades = _int_map(data.get("upgrades", {}))
	profile.stats = _int_map(data.get("stats", {}))
	profile.settings = _variant_map(data.get("settings", {}))

	if found_version < SAVE_VERSION:
		profile._migrate(found_version, data)
	profile.version = SAVE_VERSION
	return profile


func to_dictionary() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"currency": currency,
		"reputation": reputation,
		"upgrades": _plain(upgrades),
		"stats": _plain(stats),
		"settings": _plain(settings),
	}


func upgrade_level(upgrade_id: String) -> int:
	return int(upgrades.get(upgrade_id, 0))


func set_upgrade_level(upgrade_id: String, level: int) -> void:
	upgrades[upgrade_id] = maxi(0, level)


func bump_stat(stat_name: String, amount: int = 1) -> void:
	stats[stat_name] = int(stats.get(stat_name, 0)) + amount


func setting(setting_name: String, fallback: Variant) -> Variant:
	return settings.get(setting_name, fallback)


## v0 -> v1: eski kayitlarda para birimi "coins" adiyla tutuluyordu.
func _migrate(from_version: int, data: Dictionary) -> void:
	if from_version < 1:
		if data.has("coins") and not data.has("currency"):
			currency = int(data["coins"])
		if not data.has("settings"):
			for key: String in DEFAULT_SETTINGS:
				settings[key] = DEFAULT_SETTINGS[key]


static func _int_map(source: Variant) -> Dictionary[String, int]:
	var result: Dictionary[String, int] = {}
	if not (source is Dictionary):
		return result
	for key: Variant in (source as Dictionary).keys():
		result[String(key)] = int((source as Dictionary)[key])
	return result


static func _variant_map(source: Variant) -> Dictionary[String, Variant]:
	var result: Dictionary[String, Variant] = {}
	for key: String in DEFAULT_SETTINGS:
		result[key] = DEFAULT_SETTINGS[key]
	if not (source is Dictionary):
		return result
	for key: Variant in (source as Dictionary).keys():
		result[String(key)] = (source as Dictionary)[key]
	return result


static func _plain(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in source.keys():
		result[String(key)] = source[key]
	return result
