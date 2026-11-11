extends TestCase

## DamageModel: darbe / çalkalanma / düşme -> 0..1 hasar. Sözleşme: ARCHITECTURE.md §4.1.
## Eşikler oyun hissini belirler; sınır değerleri burada sabitlenir.

const PROFILE: Dictionary = {
	"impact_threshold": 5.0, "impact_scale": 0.05,
	"slosh_threshold": 6.0, "slosh_scale": 0.012,
	"fall_threshold": 0.25, "fall_scale": 1.0,
}


func test_impact_below_and_at_threshold_is_zero() -> void:
	assert_almost_eq(DamageModel.impact_damage(0.0, PROFILE), 0.0, 0.0001)
	assert_almost_eq(DamageModel.impact_damage(4.99, PROFILE), 0.0, 0.0001)
	assert_almost_eq(DamageModel.impact_damage(5.0, PROFILE), 0.0, 0.0001)


func test_impact_above_threshold_scales_linearly() -> void:
	# (7 - 5) * 0.05 = 0.10 ; (15 - 5) * 0.05 = 0.50
	assert_almost_eq(DamageModel.impact_damage(7.0, PROFILE), 0.10, 0.0001)
	assert_almost_eq(DamageModel.impact_damage(15.0, PROFILE), 0.50, 0.0001)


func test_impact_is_clamped_to_one() -> void:
	assert_almost_eq(DamageModel.impact_damage(1000.0, PROFILE), 1.0, 0.0001)


func test_negative_impulse_is_zero() -> void:
	assert_almost_eq(DamageModel.impact_damage(-20.0, PROFILE), 0.0, 0.0001)


func test_slosh_below_threshold_is_zero() -> void:
	assert_almost_eq(DamageModel.slosh_damage(6.0, 1.0, PROFILE), 0.0, 0.0001)
	assert_almost_eq(DamageModel.slosh_damage(2.0, 1.0, PROFILE), 0.0, 0.0001)


func test_slosh_scales_with_excess_and_time() -> void:
	# (10 - 6) * 0.012 * 0.5 = 0.024
	assert_almost_eq(DamageModel.slosh_damage(10.0, 0.5, PROFILE), 0.024, 0.0001)
	# süre iki katına çıkınca hasar iki katına çıkar
	assert_almost_eq(DamageModel.slosh_damage(10.0, 1.0, PROFILE), 0.048, 0.0001)


func test_slosh_uses_absolute_value_of_acceleration() -> void:
	assert_almost_eq(DamageModel.slosh_damage(-10.0, 0.5, PROFILE), 0.024, 0.0001)


func test_slosh_zero_or_negative_dt_is_zero() -> void:
	assert_almost_eq(DamageModel.slosh_damage(50.0, 0.0, PROFILE), 0.0, 0.0001)
	assert_almost_eq(DamageModel.slosh_damage(50.0, -0.1, PROFILE), 0.0, 0.0001)


func test_fall_below_threshold_is_zero() -> void:
	assert_almost_eq(DamageModel.fall_damage(0.0, PROFILE), 0.0, 0.0001)
	assert_almost_eq(DamageModel.fall_damage(0.25, PROFILE), 0.0, 0.0001)


func test_fall_above_threshold_scales_and_clamps() -> void:
	# (0.75 - 0.25) * 1.0 = 0.5
	assert_almost_eq(DamageModel.fall_damage(0.75, PROFILE), 0.5, 0.0001)
	assert_almost_eq(DamageModel.fall_damage(5.0, PROFILE), 1.0, 0.0001)
	assert_almost_eq(DamageModel.fall_damage(-1.0, PROFILE), 0.0, 0.0001)


func test_empty_profile_means_no_damage() -> void:
	var empty: Dictionary = {}
	assert_almost_eq(DamageModel.impact_damage(500.0, empty), 0.0, 0.0001)
	assert_almost_eq(DamageModel.slosh_damage(500.0, 1.0, empty), 0.0, 0.0001)
	assert_almost_eq(DamageModel.fall_damage(500.0, empty), 0.0, 0.0001)


func test_results_never_negative_and_never_above_one() -> void:
	for value: float in [-1000.0, -1.0, 0.0, 0.5, 5.0, 6.0, 50.0, 1e9]:
		var i: float = DamageModel.impact_damage(value, PROFILE)
		var s: float = DamageModel.slosh_damage(value, 0.1, PROFILE)
		var f: float = DamageModel.fall_damage(value, PROFILE)
		for d: float in [i, s, f]:
			assert_true(d >= 0.0 and d <= 1.0, "hasar 0..1 dışında: %f (girdi %f)" % [d, value])
