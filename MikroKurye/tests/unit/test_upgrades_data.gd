extends TestCase

## `data/upgrades.json` şema + değer testi. Sözleşme: ARCHITECTURE.md §3 (görev F4.3).
##
## Türetilen API: dosya `res://data/upgrades.json`; kök nesne `kategori -> {max_level, levels}`
## sözlüğüdür. Her seviye `{cost: {gold, scrap}, mods: {...}}` taşır. `levels.size()` daima
## `max_level` ile aynıdır; seviye N'in bedeli `levels[N-1].cost`tur ve maliyetler artar.
##
## Dosya doğrudan `FileAccess` ile okunur; `GameData` autoload'una bağımlı değil.
## F4.3 verisi henüz yazılmadıysa bu test KIRMIZI kalır (beklenen).

const UPGRADES_PATH: String = "res://data/upgrades.json"

## §3 tablosundaki kategoriler ve maksimum seviye.
const EXPECTED_CATEGORIES: Array[String] = ["chassis", "wheels", "battery"]

## Her kategorinin seviye başına tek mod anahtarı ve sabit katkısı.
const EXPECTED_MOD_KEYS: Dictionary = {
	"chassis": "cargo_damping_bonus",
	"wheels": "wheel_grip_bonus",
	"battery": "battery_capacity_bonus",
}

const EXPECTED_MOD_VALUES: Dictionary = {
	"chassis": 1.0,
	"wheels": 0.6,
	"battery": 15.0,
}

## ARCHITECTURE.md §3'teki NİHAİ TABLO (birebir).
const EXPECTED_UPGRADES: Dictionary = {
	"chassis": {"max_level": 5, "levels": [
		{"cost": {"gold": 100, "scrap": 5}, "mods": {"cargo_damping_bonus": 1.0}},
		{"cost": {"gold": 200, "scrap": 10}, "mods": {"cargo_damping_bonus": 1.0}},
		{"cost": {"gold": 350, "scrap": 18}, "mods": {"cargo_damping_bonus": 1.0}},
		{"cost": {"gold": 550, "scrap": 28}, "mods": {"cargo_damping_bonus": 1.0}},
		{"cost": {"gold": 800, "scrap": 40}, "mods": {"cargo_damping_bonus": 1.0}},
	]},
	"wheels": {"max_level": 5, "levels": [
		{"cost": {"gold": 80, "scrap": 4}, "mods": {"wheel_grip_bonus": 0.6}},
		{"cost": {"gold": 160, "scrap": 8}, "mods": {"wheel_grip_bonus": 0.6}},
		{"cost": {"gold": 300, "scrap": 15}, "mods": {"wheel_grip_bonus": 0.6}},
		{"cost": {"gold": 480, "scrap": 24}, "mods": {"wheel_grip_bonus": 0.6}},
		{"cost": {"gold": 700, "scrap": 35}, "mods": {"wheel_grip_bonus": 0.6}},
	]},
	"battery": {"max_level": 5, "levels": [
		{"cost": {"gold": 80, "scrap": 3}, "mods": {"battery_capacity_bonus": 15.0}},
		{"cost": {"gold": 160, "scrap": 7}, "mods": {"battery_capacity_bonus": 15.0}},
		{"cost": {"gold": 300, "scrap": 14}, "mods": {"battery_capacity_bonus": 15.0}},
		{"cost": {"gold": 480, "scrap": 22}, "mods": {"battery_capacity_bonus": 15.0}},
		{"cost": {"gold": 700, "scrap": 32}, "mods": {"battery_capacity_bonus": 15.0}},
	]},
}


func _upgrades() -> Dictionary:
	if not FileAccess.file_exists(UPGRADES_PATH):
		fail("%s bulunamadı (F4.3 henüz yazılmadı)" % UPGRADES_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(UPGRADES_PATH))
	if not parsed is Dictionary:
		fail("%s geçerli bir JSON nesnesi değil" % UPGRADES_PATH)
		return {}
	return parsed as Dictionary


func _category(upgrades: Dictionary, category: Variant) -> Dictionary:
	var raw: Variant = upgrades.get(category)
	if raw is Dictionary:
		return raw as Dictionary
	fail("kategori nesne değil: %s" % str(category))
	return {}


func _levels(entry: Dictionary, category: Variant) -> Array:
	var raw: Variant = entry.get("levels")
	if not raw is Array:
		fail("%s.levels dizi değil" % str(category))
		return []
	return raw as Array


func _level_entry(levels: Array, category: Variant, index: int) -> Dictionary:
	var raw: Variant = levels[index]
	if not raw is Dictionary:
		fail("%s.levels[%d] nesne değil" % [str(category), index])
		return {}
	return raw as Dictionary


func test_file_exists_and_is_a_json_object() -> void:
	assert_true(FileAccess.file_exists(UPGRADES_PATH), "%s bulunmalı" % UPGRADES_PATH)
	var upgrades: Dictionary = _upgrades()
	assert_true(not upgrades.is_empty(), "upgrades tablosu boş olmamalı")


func test_exactly_three_expected_categories() -> void:
	var upgrades: Dictionary = _upgrades()
	if upgrades.is_empty():
		return
	assert_eq(upgrades.size(), 3, "tam olarak üç yükseltme kategorisi olmalı")
	for category: String in EXPECTED_CATEGORIES:
		assert_true(upgrades.has(category), "kategori eksik: %s" % category)
	for key: Variant in upgrades.keys():
		assert_true(EXPECTED_CATEGORIES.has(String(key)), "beklenmeyen kategori: %s" % str(key))


func test_max_level_equals_number_of_levels() -> void:
	var upgrades: Dictionary = _upgrades()
	if upgrades.is_empty():
		return
	for category: String in EXPECTED_CATEGORIES:
		var entry: Dictionary = _category(upgrades, category)
		if entry.is_empty():
			continue
		var max_level_raw: Variant = entry.get("max_level")
		# Godot JSON her sayıyı float üretir (GOTCHAS #20): küsuratsız değer tamsayıdır.
		var is_whole: bool = (max_level_raw is int) or (max_level_raw is float and is_equal_approx(float(max_level_raw), roundf(float(max_level_raw))))
		assert_true(is_whole, "%s.max_level tamsayı olmalı (gelen: %s)" % [category, str(max_level_raw)])
		var max_level: int = int(max_level_raw)
		assert_eq(max_level, 5, "%s.max_level 5 olmalı" % category)
		var levels: Array = _levels(entry, category)
		assert_eq(levels.size(), max_level, "%s.levels boyutu max_level'a eşit olmalı" % category)


func test_each_level_has_cost_and_mods_objects() -> void:
	var upgrades: Dictionary = _upgrades()
	if upgrades.is_empty():
		return
	for category: String in EXPECTED_CATEGORIES:
		var entry: Dictionary = _category(upgrades, category)
		if entry.is_empty():
			continue
		var levels: Array = _levels(entry, category)
		for index: int in range(levels.size()):
			var level_entry: Dictionary = _level_entry(levels, category, index)
			if level_entry.is_empty():
				continue
			assert_true(level_entry.get("cost") is Dictionary,
				"%s.levels[%d].cost nesne olmalı" % [category, index])
			assert_true(level_entry.get("mods") is Dictionary,
				"%s.levels[%d].mods nesne olmalı" % [category, index])


func test_costs_are_positive_and_strictly_increase() -> void:
	var upgrades: Dictionary = _upgrades()
	if upgrades.is_empty():
		return
	for category: String in EXPECTED_CATEGORIES:
		var entry: Dictionary = _category(upgrades, category)
		if entry.is_empty():
			continue
		var levels: Array = _levels(entry, category)
		var previous_gold: int = -1
		var previous_scrap: int = -1
		for index: int in range(levels.size()):
			var level_entry: Dictionary = _level_entry(levels, category, index)
			if level_entry.is_empty():
				continue
			var cost_raw: Variant = level_entry.get("cost")
			if not cost_raw is Dictionary:
				continue
			var cost: Dictionary = cost_raw as Dictionary
			var gold: int = int(cost.get("gold", 0))
			var scrap: int = int(cost.get("scrap", 0))
			assert_true(gold > 0, "%s.levels[%d] gold pozitif olmalı (gelen: %d)" % [category, index, gold])
			assert_true(scrap > 0, "%s.levels[%d] scrap pozitif olmalı (gelen: %d)" % [category, index, scrap])
			assert_true(gold > previous_gold,
				"%s gold seviyeyle artmalı (index %d)" % [category, index])
			assert_true(scrap > previous_scrap,
				"%s scrap seviyeyle artmalı (index %d)" % [category, index])
			previous_gold = gold
			previous_scrap = scrap


func test_mods_have_expected_single_key_and_value() -> void:
	var upgrades: Dictionary = _upgrades()
	if upgrades.is_empty():
		return
	for category: String in EXPECTED_CATEGORIES:
		var entry: Dictionary = _category(upgrades, category)
		if entry.is_empty():
			continue
		var expected_key: String = String(EXPECTED_MOD_KEYS[category])
		var expected_value: float = float(EXPECTED_MOD_VALUES[category])
		var levels: Array = _levels(entry, category)
		for index: int in range(levels.size()):
			var level_entry: Dictionary = _level_entry(levels, category, index)
			if level_entry.is_empty():
				continue
			var mods_raw: Variant = level_entry.get("mods")
			if not mods_raw is Dictionary:
				continue
			var mods: Dictionary = mods_raw as Dictionary
			assert_eq(mods.size(), 1, "%s.levels[%d].mods tek anahtar taşımalı" % [category, index])
			assert_true(mods.has(expected_key),
				"%s.levels[%d].mods anahtarı %s olmalı" % [category, index, expected_key])
			assert_almost_eq(float(mods.get(expected_key, 0.0)), expected_value, 0.0001,
				"%s.levels[%d].%s değeri" % [category, index, expected_key])


func test_table_matches_architecture_values_exactly() -> void:
	var upgrades: Dictionary = _upgrades()
	if upgrades.is_empty():
		return
	# Beklenen değerleri de JSON'dan geçir: tamsayılar float'a normalleşir (GOTCHAS #20).
	var expected: Variant = JSON.parse_string(JSON.stringify(EXPECTED_UPGRADES))
	assert_eq(upgrades, expected, "upgrades.json ARCHITECTURE.md §3 ile birebir örtüşmeli")
