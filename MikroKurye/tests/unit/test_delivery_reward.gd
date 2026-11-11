extends TestCase

## DeliveryReward: hasar + kargo profili -> {damage, stars, multiplier, gold, scrap, success}.
## Sözleşme: ARCHITECTURE.md §4.4 (görev F1.5).
##
## Türetilen API (sınıf henüz yok; kırmızı aşama):
##   `class_name DeliveryReward` (statik, `scripts/core/delivery_reward.gd`)
##   `static func compute(damage: float, profile: Dictionary, bonus: Dictionary = {}) -> Dictionary`
##   gold  = int(round(profile.reward_gold * RunScoring.multiplier_for_damage(clamped) * (1 + bonus.gold_pct)))
##   scrap = int(round(profile.reward_scrap * (1 - clamped)))   (kırık = 0)
##   success = clamped < 1.0   ;   clamped = clampf(damage, 0, 1)
##
## `RunScoring` zaten var (scripts/core/run_scoring.gd); bozulmadan kullanılır.

## Kargo profilinin yalnızca ödül kısmı yeterli; değerler pencil_battery ile aynı.
const PROFILE: Dictionary = {
	"reward_gold": 40, "reward_scrap": 2,
}

const RESULT_KEYS: Array[String] = [
	"damage", "stars", "multiplier", "gold", "scrap", "success",
]


func test_result_contains_all_contract_keys() -> void:
	var result: Dictionary = DeliveryReward.compute(0.1, PROFILE)
	for key: String in RESULT_KEYS:
		assert_true(result.has(key), "sonuçta anahtar eksik: %s" % key)


func test_perfect_run_rewards_full_gold_and_scrap() -> void:
	# 40 * 1.2 = 48 altın; 2 * 1.0 = 2 hurda
	var result: Dictionary = DeliveryReward.compute(0.0, PROFILE)
	assert_eq(int(result["gold"]), 48)
	assert_eq(int(result["scrap"]), 2)
	assert_eq(int(result["stars"]), 3)
	assert_almost_eq(float(result["multiplier"]), 1.2, 0.0001)
	assert_almost_eq(float(result["damage"]), 0.0, 0.0001)
	assert_true(bool(result["success"]))


func test_two_star_band_keeps_full_gold() -> void:
	# çarpan 1.0; hurda round(2 * 0.75) = 2
	var result: Dictionary = DeliveryReward.compute(0.25, PROFILE)
	assert_eq(int(result["gold"]), 40)
	assert_eq(int(result["stars"]), 2)
	assert_eq(int(result["scrap"]), 2)


func test_one_star_band_scales_gold_and_scrap() -> void:
	# çarpan 0.6 -> 24 altın; hurda round(2 * 0.4) = 1
	var result: Dictionary = DeliveryReward.compute(0.60, PROFILE)
	assert_eq(int(result["gold"]), 24)
	assert_eq(int(result["stars"]), 1)
	assert_eq(int(result["scrap"]), 1)


func test_zero_star_band_pays_twenty_percent() -> void:
	# çarpan 0.2 -> 8 altın; hurda round(2 * 0.39) = 1
	var result: Dictionary = DeliveryReward.compute(0.61, PROFILE)
	assert_eq(int(result["gold"]), 8)
	assert_eq(int(result["stars"]), 0)
	assert_eq(int(result["scrap"]), 1)


func test_broken_run_returns_nothing_and_fails() -> void:
	var result: Dictionary = DeliveryReward.compute(1.0, PROFILE)
	assert_eq(int(result["gold"]), 0)
	assert_eq(int(result["scrap"]), 0)
	assert_eq(int(result["stars"]), 0)
	assert_almost_eq(float(result["multiplier"]), 0.0, 0.0001)
	assert_false(bool(result["success"]))


func test_gold_bonus_multiplies_reward() -> void:
	# 40 * 1.2 * (1 + 0.5) = 72
	var result: Dictionary = DeliveryReward.compute(0.0, PROFILE, {"gold_pct": 0.5})
	assert_eq(int(result["gold"]), 72)


func test_missing_bonus_means_no_extra_gold() -> void:
	var result: Dictionary = DeliveryReward.compute(0.0, PROFILE, {})
	assert_eq(int(result["gold"]), 48)


func test_success_is_false_only_when_broken() -> void:
	assert_true(bool(DeliveryReward.compute(0.99, PROFILE)["success"]))
	assert_false(bool(DeliveryReward.compute(1.0, PROFILE)["success"]))
	assert_false(bool(DeliveryReward.compute(1.01, PROFILE)["success"]))


func test_damage_is_clamped() -> void:
	var low: Dictionary = DeliveryReward.compute(-0.5, PROFILE)
	assert_almost_eq(float(low["damage"]), 0.0, 0.0001)
	assert_true(bool(low["success"]))
	assert_eq(int(low["gold"]), 48)
	var high: Dictionary = DeliveryReward.compute(2.0, PROFILE)
	assert_almost_eq(float(high["damage"]), 1.0, 0.0001)
	assert_false(bool(high["success"]))
	assert_eq(int(high["gold"]), 0)


func test_reuses_run_scoring_multiplier_and_stars() -> void:
	for damage: float in [0.0, 0.1, 0.25, 0.5, 0.6, 0.61, 0.9]:
		var result: Dictionary = DeliveryReward.compute(damage, PROFILE)
		assert_almost_eq(float(result["multiplier"]), RunScoring.multiplier_for_damage(damage), 0.0001)
		assert_eq(int(result["stars"]), RunScoring.stars_for_damage(damage))
