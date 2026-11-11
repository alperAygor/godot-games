extends TestCase

## `data/cargo.json` şema + değer testi. Sözleşme: ARCHITECTURE.md §3 (görev F1.1).
##
## Türetilen API: dosya `res://data/cargo.json`; kök nesne `cargo_id -> profil` sözlüğü.
## Profil zorunlu anahtarları: name_key, difficulty, mass, impact_threshold, impact_scale,
## slosh_threshold, slosh_scale, fall_threshold, fall_scale, reward_gold, reward_scrap.
## Aralıklar: difficulty 1..3 tamsayı; eşikler > 0; ölçekler >= 0; ödüller >= 0; mass > 0.
##
## Dosya doğrudan `FileAccess` ile okunur; `GameData` autoload'una bağımlı değil.
## F1.1 henüz yazılmadıysa bu test KIRMIZI kalır (beklenen).

const CARGO_PATH: String = "res://data/cargo.json"

## Zorunlu anahtarlar (ARCHITECTURE.md §3).
const REQUIRED_KEYS: Array[String] = [
	"name_key", "difficulty", "mass",
	"impact_threshold", "impact_scale",
	"slosh_threshold", "slosh_scale",
	"fall_threshold", "fall_scale",
	"reward_gold", "reward_scrap",
]

## Beklenen profil kimlikleri; zorluk sırasıyla (1 -> 3).
const EXPECTED_IDS: Array[String] = [
	"pencil_battery", "sd_card", "espresso_capsule",
]

## ARCHITECTURE.md §3'teki değerler (birebir).
const EXPECTED_CARGO: Dictionary = {
	"pencil_battery": {
		"name_key": "cargo.battery", "difficulty": 1, "mass": 0.05,
		"impact_threshold": 9.0, "impact_scale": 0.02,
		"slosh_threshold": 999.0, "slosh_scale": 0.0,
		"fall_threshold": 0.45, "fall_scale": 0.6,
		"reward_gold": 40, "reward_scrap": 2,
	},
	"sd_card": {
		"name_key": "cargo.sd_card", "difficulty": 2, "mass": 0.02,
		"impact_threshold": 3.5, "impact_scale": 0.07,
		"slosh_threshold": 14.0, "slosh_scale": 0.004,
		"fall_threshold": 0.18, "fall_scale": 1.4,
		"reward_gold": 90, "reward_scrap": 5,
	},
	"espresso_capsule": {
		"name_key": "cargo.espresso", "difficulty": 3, "mass": 0.04,
		"impact_threshold": 5.0, "impact_scale": 0.05,
		"slosh_threshold": 6.0, "slosh_scale": 0.012,
		"fall_threshold": 0.25, "fall_scale": 1.0,
		"reward_gold": 160, "reward_scrap": 9,
	},
}


func _cargo() -> Dictionary:
	if not FileAccess.file_exists(CARGO_PATH):
		fail("%s bulunamadı (F1.1 henüz yazılmadı)" % CARGO_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CARGO_PATH))
	if not parsed is Dictionary:
		fail("%s geçerli bir JSON nesnesi değil" % CARGO_PATH)
		return {}
	return parsed as Dictionary


func _profile(cargo: Dictionary, id: Variant) -> Dictionary:
	var raw: Variant = cargo.get(id)
	if raw is Dictionary:
		return raw as Dictionary
	fail("profil nesne değil: %s" % str(id))
	return {}


func test_file_exists_and_is_a_json_object() -> void:
	assert_true(FileAccess.file_exists(CARGO_PATH), "%s bulunmalı" % CARGO_PATH)
	var cargo: Dictionary = _cargo()
	assert_true(not cargo.is_empty(), "cargo tablosu boş olmamalı")


func test_exactly_three_profiles_with_expected_ids() -> void:
	var cargo: Dictionary = _cargo()
	if cargo.is_empty():
		return
	assert_eq(cargo.size(), 3, "tam olarak üç kargo profili olmalı")
	for id: String in EXPECTED_IDS:
		assert_true(cargo.has(id), "profil eksik: %s" % id)
	for key: Variant in cargo.keys():
		assert_true(EXPECTED_IDS.has(String(key)), "beklenmeyen profil: %s" % str(key))


func test_each_profile_has_all_required_keys() -> void:
	var cargo: Dictionary = _cargo()
	if cargo.is_empty():
		return
	for id: Variant in cargo.keys():
		var profile: Dictionary = _profile(cargo, id)
		if profile.is_empty():
			continue
		for key: String in REQUIRED_KEYS:
			assert_true(profile.has(key), "%s.profilinde zorunlu anahtar eksik: %s" % [id, key])


func test_difficulty_is_integer_between_1_and_3() -> void:
	var cargo: Dictionary = _cargo()
	if cargo.is_empty():
		return
	for id: Variant in cargo.keys():
		var profile: Dictionary = _profile(cargo, id)
		if profile.is_empty():
			continue
		var difficulty: Variant = profile.get("difficulty")
		assert_true(difficulty is int, "%s.difficulty tamsayı olmalı (gelen: %s)" % [id, str(difficulty)])
		var value: int = int(difficulty)
		assert_true(value >= 1 and value <= 3, "%s.difficulty 1..3 dışında: %d" % [id, value])


func test_thresholds_are_positive() -> void:
	var cargo: Dictionary = _cargo()
	if cargo.is_empty():
		return
	for id: Variant in cargo.keys():
		var profile: Dictionary = _profile(cargo, id)
		if profile.is_empty():
			continue
		for key: String in ["impact_threshold", "slosh_threshold", "fall_threshold"]:
			var value: float = float(profile.get(key))
			assert_true(value > 0.0, "%s.%s pozitif olmalı (gelen: %f)" % [id, key, value])


func test_scales_are_non_negative() -> void:
	var cargo: Dictionary = _cargo()
	if cargo.is_empty():
		return
	for id: Variant in cargo.keys():
		var profile: Dictionary = _profile(cargo, id)
		if profile.is_empty():
			continue
		for key: String in ["impact_scale", "slosh_scale", "fall_scale"]:
			var value: float = float(profile.get(key))
			assert_true(value >= 0.0, "%s.%s negatif olamaz (gelen: %f)" % [id, key, value])


func test_rewards_are_non_negative() -> void:
	var cargo: Dictionary = _cargo()
	if cargo.is_empty():
		return
	for id: Variant in cargo.keys():
		var profile: Dictionary = _profile(cargo, id)
		if profile.is_empty():
			continue
		for key: String in ["reward_gold", "reward_scrap"]:
			var value: int = int(profile.get(key))
			assert_true(value >= 0, "%s.%s negatif olamaz (gelen: %d)" % [id, key, value])


func test_mass_is_positive() -> void:
	var cargo: Dictionary = _cargo()
	if cargo.is_empty():
		return
	for id: Variant in cargo.keys():
		var profile: Dictionary = _profile(cargo, id)
		if profile.is_empty():
			continue
		var mass: float = float(profile.get("mass"))
		assert_true(mass > 0.0, "%s.mass pozitif olmalı (gelen: %f)" % [id, mass])


func test_reward_gold_increases_with_difficulty() -> void:
	var cargo: Dictionary = _cargo()
	if cargo.is_empty():
		return
	var previous_difficulty: int = 0
	var previous_gold: int = -1
	for id: String in EXPECTED_IDS:
		var profile: Dictionary = _profile(cargo, id)
		if profile.is_empty():
			continue
		var difficulty: int = int(profile.get("difficulty"))
		var gold: int = int(profile.get("reward_gold"))
		assert_true(difficulty > previous_difficulty, "zorluk sırası artmalı (%s)" % id)
		assert_true(gold > previous_gold, "reward_gold zorlukla artmalı (%s)" % id)
		previous_difficulty = difficulty
		previous_gold = gold


func test_profiles_match_architecture_values_exactly() -> void:
	var cargo: Dictionary = _cargo()
	if cargo.is_empty():
		return
	assert_eq(cargo, EXPECTED_CARGO, "cargo.json ARCHITECTURE.md §3 ile birebir örtüşmeli")


func test_damage_model_returns_in_range_for_each_profile() -> void:
	var cargo: Dictionary = _cargo()
	if cargo.is_empty():
		return
	var samples: Array[float] = [0.0, 1.0, 5.0, 20.0, 1000.0]
	for id: Variant in cargo.keys():
		var profile: Dictionary = _profile(cargo, id)
		if profile.is_empty():
			continue
		for impulse: float in samples:
			var damage: float = DamageModel.impact_damage(impulse, profile)
			assert_true(damage >= 0.0 and damage <= 1.0, "impact_damage 0..1 dışında: %f (%s)" % [damage, id])
		for accel: float in samples:
			var damage: float = DamageModel.slosh_damage(accel, 1.0, profile)
			assert_true(damage >= 0.0 and damage <= 1.0, "slosh_damage 0..1 dışında: %f (%s)" % [damage, id])
		for height: float in samples:
			var damage: float = DamageModel.fall_damage(height, profile)
			assert_true(damage >= 0.0 and damage <= 1.0, "fall_damage 0..1 dışında: %f (%s)" % [damage, id])
