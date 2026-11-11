class_name UpgradeModel
extends RefCounted

## Saf mantık: yükseltme tablosu üzerinden bedel, satın alma ve toplam modlar.
## Sözleşme: ARCHITECTURE.md §4.5.
##
## Tablo `data/upgrades.json`'dan okunur; JSON bütün sayıları float ürettiği için
## (GOTCHAS #20) seviye ve bedel değerleri küsuratsızsa tamsayıya çevrilir.
## Küsuratlı/geçersiz tablo değeri satın alınamaz sayılır; tahmin edilmez.
##
## Girdi sözlükleri ASLA değiştirilmez: her dönüş yolu taze kopya taşır.

const GOLD_KEY: String = "gold"
const SCRAP_KEY: String = "scrap"
const LEVELS_KEY: String = "levels"
const MAX_LEVEL_KEY: String = "max_level"
const COST_KEY: String = "cost"
const MODS_KEY: String = "mods"

## Satın alma başarısızlık nedenleri; arayüz bunları yerelleştirebilir.
const REASON_UNKNOWN_CATEGORY: String = "unknown_category"
const REASON_INVALID_TABLE: String = "invalid_table"
const REASON_MAX_LEVEL: String = "max_level"
const REASON_INSUFFICIENT_FUNDS: String = "insufficient_funds"


## Satın alınacak `level` seviyesinin bedeli. Seviye 1..max dışındaysa ya da
## kategori/tablo bozuksa boş sözlük döner (satın alma reddedilir).
static func cost(table: Dictionary, category: String, level: int) -> Dictionary:
	var entry: Variant = table.get(category)
	if not entry is Dictionary:
		return {}
	var category_entry: Dictionary = entry as Dictionary
	var levels_raw: Variant = category_entry.get(LEVELS_KEY)
	if not levels_raw is Array:
		return {}
	var level_entries: Array = levels_raw as Array
	if level < 1 or level > level_entries.size():
		return {}
	if level > _max_level(category_entry, level_entries.size()):
		return {}

	var level_raw: Variant = level_entries[level - 1]
	if not level_raw is Dictionary:
		return {}
	var cost_raw: Variant = (level_raw as Dictionary).get(COST_KEY)
	if not cost_raw is Dictionary:
		return {}
	return _cost_from_dict(cost_raw as Dictionary)


## Cüzdan bedeli karşılıyor mu? Eksik anahtar 0 sayılır; bozuk değer 0'a çekilir.
static func can_afford(wallet: Dictionary, cost: Dictionary) -> bool:
	var wallet_gold: int = _whole_or_zero(wallet.get(GOLD_KEY, 0))
	var wallet_scrap: int = _whole_or_zero(wallet.get(SCRAP_KEY, 0))
	var cost_gold: int = _whole_or_zero(cost.get(GOLD_KEY, 0))
	var cost_scrap: int = _whole_or_zero(cost.get(SCRAP_KEY, 0))
	return wallet_gold >= cost_gold and wallet_scrap >= cost_scrap


## Sıradaki seviyeyi satın alır. Başarısızlıkta da cüzdan/seviye kopyaları döner;
## böylece çağıran aynı sonuç şeklini kullanır ama girdiler değişmez.
static func purchase(table: Dictionary, wallet: Dictionary,
		levels: Dictionary, category: String) -> Dictionary:
	var next_wallet: Dictionary = _normalized_wallet(wallet)
	var next_levels: Dictionary = _normalized_levels(levels)

	var entry: Variant = table.get(category)
	if not entry is Dictionary:
		return _failure(next_wallet, next_levels, REASON_UNKNOWN_CATEGORY)
	var category_entry: Dictionary = entry as Dictionary
	var levels_raw: Variant = category_entry.get(LEVELS_KEY)
	if not levels_raw is Array:
		return _failure(next_wallet, next_levels, REASON_INVALID_TABLE)
	var level_entries: Array = levels_raw as Array
	var max_level: int = _max_level(category_entry, level_entries.size())
	var current_level: int = _whole_or_zero(levels.get(category, 0))
	if current_level >= max_level:
		return _failure(next_wallet, next_levels, REASON_MAX_LEVEL)

	var next_level: int = current_level + 1
	var price: Dictionary = cost(table, category, next_level)
	if price.is_empty():
		return _failure(next_wallet, next_levels, REASON_INVALID_TABLE)
	if not can_afford(next_wallet, price):
		return _failure(next_wallet, next_levels, REASON_INSUFFICIENT_FUNDS)

	next_wallet[GOLD_KEY] = int(next_wallet[GOLD_KEY]) - int(price[GOLD_KEY])
	next_wallet[SCRAP_KEY] = int(next_wallet[SCRAP_KEY]) - int(price[SCRAP_KEY])
	next_levels[category] = next_level
	return {
		"ok": true,
		"wallet": next_wallet,
		"levels": next_levels,
		"reason": "",
	}


## Sahip olunan 1..N seviyelerin `mods` değerlerini anahtar bazında toplar.
## Bilinmeyen kategori, seviye 0 ve bozuk mod girdisi katkı vermez.
static func stats(table: Dictionary, levels: Dictionary) -> Dictionary:
	var sums: Dictionary = {}
	for key: Variant in levels.keys():
		var category: String = String(key)
		var entry: Variant = table.get(category)
		if not entry is Dictionary:
			continue
		var category_entry: Dictionary = entry as Dictionary
		var levels_raw: Variant = category_entry.get(LEVELS_KEY)
		if not levels_raw is Array:
			continue
		var level_entries: Array = levels_raw as Array
		# Sahip olunan seviye tablo sınırını aşarsa fazlası yok sayılır.
		var owned_levels: int = mini(_whole_or_zero(levels[key]), level_entries.size())
		owned_levels = mini(owned_levels, _max_level(category_entry, level_entries.size()))
		for index: int in range(owned_levels):
			var level_raw: Variant = level_entries[index]
			if not level_raw is Dictionary:
				continue
			var mods_raw: Variant = (level_raw as Dictionary).get(MODS_KEY)
			if not mods_raw is Dictionary:
				continue
			var mods: Dictionary = mods_raw as Dictionary
			for mod_key: Variant in mods.keys():
				var value_raw: Variant = mods[mod_key]
				if typeof(value_raw) != TYPE_INT and typeof(value_raw) != TYPE_FLOAT:
					continue
				var value: float = float(value_raw)
				if not is_finite(value):
					continue
				var mod_name: String = String(mod_key)
				sums[mod_name] = float(sums.get(mod_name, 0.0)) + value
	return sums


## Bedel sözlüğünü doğrular ve tamsayıya çevirir. Eksik para birimi 0'dır;
## küsuratlı/negatif/yanlış tip bedel geçersizdir (boş sözlük).
static func _cost_from_dict(raw: Dictionary) -> Dictionary:
	var gold: int = 0
	var scrap: int = 0
	if raw.has(GOLD_KEY):
		if not _is_whole_number(raw[GOLD_KEY]):
			return {}
		gold = _to_whole_int(raw[GOLD_KEY])
	if raw.has(SCRAP_KEY):
		if not _is_whole_number(raw[SCRAP_KEY]):
			return {}
		scrap = _to_whole_int(raw[SCRAP_KEY])
	if gold < 0 or scrap < 0:
		return {}
	var result: Dictionary = {}
	result[GOLD_KEY] = gold
	result[SCRAP_KEY] = scrap
	return result


static func _normalized_wallet(wallet: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	result[GOLD_KEY] = _whole_or_zero(wallet.get(GOLD_KEY, 0))
	result[SCRAP_KEY] = _whole_or_zero(wallet.get(SCRAP_KEY, 0))
	return result


static func _normalized_levels(levels: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in levels.keys():
		result[String(key)] = _whole_or_zero(levels[key])
	return result


static func _failure(wallet: Dictionary, levels: Dictionary, reason: String) -> Dictionary:
	return {
		"ok": false,
		"wallet": wallet,
		"levels": levels,
		"reason": reason,
	}


## max_level eksik/bozuksa tablodaki seviye sayısına düşülür; böylece bozuk bir
## alan yüzünden sınırsız seviye satın alınamaz.
static func _max_level(entry: Dictionary, fallback: int) -> int:
	var raw: Variant = entry.get(MAX_LEVEL_KEY)
	if not _is_whole_number(raw):
		return fallback
	var result: int = _to_whole_int(raw)
	return result if result >= 0 else fallback


## JSON küsuratsız float (5.0) tamsayıdır; 5.5, NaN ve metin değildir.
static func _is_whole_number(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) == TYPE_FLOAT:
		var number: float = float(value)
		return is_finite(number) and is_equal_approx(number, roundf(number))
	return false


static func _to_whole_int(value: Variant) -> int:
	if typeof(value) == TYPE_FLOAT:
		return int(roundf(float(value)))
	return int(value)


## Eksik/yanlış tip/küsuratlı/negatif sayı 0 sayılır; para ve seviye için güvenli.
static func _whole_or_zero(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		return maxi(int(value), 0)
	if typeof(value) == TYPE_FLOAT:
		var number: float = float(value)
		if is_finite(number) and is_equal_approx(number, roundf(number)):
			return maxi(int(roundf(number)), 0)
	return 0
