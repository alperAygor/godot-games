extends TestCase

## LevelProgression: level boyu, zorluk eğrisi, engel kilitleri ve tohumlu parça planı.

const LIBRARY: Array = [
	{"id": "calm_a", "length": 12.0, "min_level": 1, "weight": 1.0, "tags": ["keys"], "calm": true},
	{"id": "keys_a", "length": 12.0, "min_level": 1, "weight": 2.0, "tags": ["keys"]},
	{"id": "keys_b", "length": 12.0, "min_level": 1, "weight": 2.0, "tags": ["keys"]},
	{"id": "mug_a", "length": 12.0, "min_level": 2, "weight": 1.0, "tags": ["obstacles"]},
	{"id": "pencil_a", "length": 12.0, "min_level": 3, "weight": 1.0, "tags": ["pencils"]},
	{"id": "fan_a", "length": 12.0, "min_level": 4, "weight": 1.0, "tags": ["fans"]},
	{"id": "mix_a", "length": 24.0, "min_level": 6, "weight": 1.0, "tags": ["keys", "fans", "mixed"]},
]


func _ids(plan_list: Array[Dictionary]) -> Array[String]:
	var ids: Array[String] = []
	for entry: Dictionary in plan_list:
		ids.append(String(entry["id"]))
	return ids


func test_length_grows_then_caps() -> void:
	assert_almost_eq(LevelProgression.length_for(1), 60.0, 0.0001)
	assert_almost_eq(LevelProgression.length_for(2), 72.0, 0.0001)
	assert_almost_eq(LevelProgression.length_for(5), 108.0, 0.0001)
	assert_almost_eq(LevelProgression.length_for(16), 240.0, 0.0001)
	assert_almost_eq(LevelProgression.length_for(500), 240.0, 0.0001)
	assert_almost_eq(LevelProgression.length_for(0), 60.0, 0.0001)


func test_intensity_ramps_and_saturates() -> void:
	assert_almost_eq(LevelProgression.intensity(1), 0.0, 0.0001)
	assert_almost_eq(LevelProgression.intensity(15), 1.0, 0.0001)
	assert_almost_eq(LevelProgression.intensity(99), 1.0, 0.0001)
	assert_greater(LevelProgression.intensity(8), LevelProgression.intensity(4))


func test_scales_move_toward_harder_values() -> void:
	assert_almost_eq(LevelProgression.telegraph_scale(1), 1.0, 0.0001)
	assert_almost_eq(LevelProgression.telegraph_scale(50), LevelProgression.MIN_TELEGRAPH_SCALE, 0.0001)
	assert_almost_eq(LevelProgression.cycle_scale(50), LevelProgression.MIN_CYCLE_SCALE, 0.0001)
	assert_almost_eq(LevelProgression.fan_strength_scale(50), LevelProgression.MAX_FAN_SCALE, 0.0001)
	assert_almost_eq(LevelProgression.heal_fraction(1), LevelProgression.HEAL_FRACTION_EASY, 0.0001)
	# Yenileme level boyuyla orantılı: L1 (60 m) -> %6, tavan (240 m) -> %24.
	assert_almost_eq(LevelProgression.battery_refill(1), 0.06, 0.0001)
	assert_almost_eq(LevelProgression.battery_refill(50), 0.24, 0.0001)
	assert_greater(LevelProgression.battery_refill(10), LevelProgression.battery_refill(2))


func test_hazard_budget_is_clamped() -> void:
	assert_eq(LevelProgression.hazard_budget(1), 1)
	assert_eq(LevelProgression.hazard_budget(3), 2)
	assert_eq(LevelProgression.hazard_budget(100), 4)


func test_unlocks_open_in_order() -> void:
	assert_eq(LevelProgression.unlocked_tags(1), ["keys"] as Array[String])
	assert_true(LevelProgression.unlocked_tags(2).has("obstacles"))
	assert_false(LevelProgression.unlocked_tags(2).has("pencils"))
	assert_true(LevelProgression.unlocked_tags(4).has("fans"))
	assert_true(LevelProgression.unlocked_tags(6).has("mixed"))


func test_plan_is_deterministic_per_seed_and_level() -> void:
	var a: Array[Dictionary] = LevelProgression.plan(3, 1234, LIBRARY)
	var b: Array[Dictionary] = LevelProgression.plan(3, 1234, LIBRARY)
	assert_eq(_ids(a), _ids(b))
	var c: Array[Dictionary] = LevelProgression.plan(3, 999, LIBRARY)
	assert_false(_ids(a) == _ids(c) and a.size() > 4, "farklı tohum çoğunlukla farklı yol vermeli")


func test_plan_covers_target_length_and_offsets_are_contiguous() -> void:
	var plan_list: Array[Dictionary] = LevelProgression.plan(2, 7, LIBRARY)
	assert_greater(LevelProgression.plan_length(plan_list), LevelProgression.length_for(2) - 0.01)
	var expected_offset: float = 0.0
	for entry: Dictionary in plan_list:
		assert_almost_eq(float(entry["offset"]), expected_offset, 0.0001)
		expected_offset += float(entry["length"])


func test_plan_respects_unlocks() -> void:
	for level: int in [1, 2, 3]:
		for entry: Dictionary in LevelProgression.plan(level, 5, LIBRARY):
			var id: String = String(entry["id"])
			assert_false(id == "fan_a", "level %d'de fan parçası olmamalı" % level)
			if level < 3:
				assert_false(id == "pencil_a", "level %d'de kalem parçası olmamalı" % level)
			if level < 2:
				assert_false(id == "mug_a", "level 1'de kupa parçası olmamalı")


func test_plan_starts_calm_and_avoids_immediate_repeats() -> void:
	for level: int in range(1, 9):
		var ids: Array[String] = _ids(LevelProgression.plan(level, 42, LIBRARY))
		assert_eq(ids[0], "calm_a", "level %d sakin parçayla başlamalı" % level)
		for i: int in range(1, ids.size()):
			assert_false(ids[i] == ids[i - 1], "art arda aynı parça: level %d, sıra %d" % [level, i])


func test_plan_with_empty_or_invalid_library_is_empty() -> void:
	assert_eq(LevelProgression.plan(1, 1, []).size(), 0)
	assert_eq(LevelProgression.plan(1, 1, [{"id": "", "length": 12.0}, {"id": "x", "length": 0.0}]).size(), 0)
	assert_eq(LevelProgression.plan(1, 1, [42, "x"]).size(), 0)
