extends TestCase

## EndlessReward: level ödülü, zor kargo çarpanı, kırılma kasası (yarısı), puan.

const EASY: Dictionary = {"reward_gold": 40, "reward_scrap": 2, "difficulty": 1}
const HARD: Dictionary = {"reward_gold": 160, "reward_scrap": 9, "difficulty": 3}


func test_cargo_multiplier_by_difficulty() -> void:
	assert_almost_eq(EndlessReward.cargo_multiplier(1), 1.0, 0.0001)
	assert_almost_eq(EndlessReward.cargo_multiplier(2), 1.5, 0.0001)
	assert_almost_eq(EndlessReward.cargo_multiplier(3), 2.0, 0.0001)
	assert_almost_eq(EndlessReward.cargo_multiplier(0), 1.0, 0.0001)


func test_level_one_matches_plain_delivery_reward_for_easy_cargo() -> void:
	var base: Dictionary = DeliveryReward.compute(0.0, EASY)
	var result: Dictionary = EndlessReward.level_reward(1, 0.0, EASY)
	assert_eq(int(result["gold"]), int(base["gold"]))
	assert_eq(int(result["scrap"]), int(base["scrap"]))
	assert_eq(int(result["level"]), 1)


func test_reward_grows_with_level() -> void:
	var l1: Dictionary = EndlessReward.level_reward(1, 0.0, EASY)
	var l5: Dictionary = EndlessReward.level_reward(5, 0.0, EASY)
	assert_greater(float(l5["gold"]), float(l1["gold"]))
	# 40 * 1.2 (hasarsız çarpan) * (1 + 0.25*4) = 96
	assert_eq(int(l5["gold"]), 96)


func test_hard_cargo_multiplies_gold_not_scrap() -> void:
	# 160 * 1.2 * 2.0 = 384 ; hurda 9
	var result: Dictionary = EndlessReward.level_reward(1, 0.0, HARD)
	assert_eq(int(result["gold"]), 384)
	assert_eq(int(result["scrap"]), 9)


func test_damage_reduces_reward() -> void:
	var clean: Dictionary = EndlessReward.level_reward(3, 0.0, EASY)
	var dirty: Dictionary = EndlessReward.level_reward(3, 0.6, EASY)
	assert_greater(float(clean["gold"]), float(dirty["gold"]))


func test_payout_is_full_unless_broken() -> void:
	for reason: String in ["battery", "quit", "", "anything"]:
		var paid: Dictionary = EndlessReward.payout(101, 7, reason)
		assert_eq(int(paid["gold"]), 101)
		assert_eq(int(paid["scrap"]), 7)
		assert_almost_eq(float(paid["fraction"]), 1.0, 0.0001)


func test_payout_on_break_is_half_rounded_down() -> void:
	var paid: Dictionary = EndlessReward.payout(101, 7, EndlessReward.REASON_BROKEN)
	assert_eq(int(paid["gold"]), 50)
	assert_eq(int(paid["scrap"]), 3)
	assert_almost_eq(float(paid["fraction"]), 0.5, 0.0001)
	var zero: Dictionary = EndlessReward.payout(0, 0, EndlessReward.REASON_BROKEN)
	assert_eq(int(zero["gold"]), 0)


func test_payout_never_negative() -> void:
	var paid: Dictionary = EndlessReward.payout(-5, -1, EndlessReward.REASON_BROKEN)
	assert_eq(int(paid["gold"]), 0)
	assert_eq(int(paid["scrap"]), 0)


func test_score_scales_with_cargo_difficulty_and_rejects_bad_input() -> void:
	assert_eq(EndlessReward.score(100.0, 1), 100)
	assert_eq(EndlessReward.score(100.0, 2), 150)
	assert_eq(EndlessReward.score(100.0, 3), 200)
	assert_eq(EndlessReward.score(-5.0, 3), 0)
	assert_eq(EndlessReward.score(NAN, 3), 0)


func test_insurance_raises_break_payout_but_is_capped() -> void:
	var paid: Dictionary = EndlessReward.payout(100, 10, EndlessReward.REASON_BROKEN, 0.3)
	assert_eq(int(paid["gold"]), 80)
	assert_almost_eq(float(paid["fraction"]), 0.8, 0.0001)
	var capped: Dictionary = EndlessReward.payout(100, 10, EndlessReward.REASON_BROKEN, 5.0)
	assert_almost_eq(float(capped["fraction"]), EndlessReward.MAX_BREAK_PAYOUT_FRACTION, 0.0001)
	var negative: Dictionary = EndlessReward.payout(100, 10, EndlessReward.REASON_BROKEN, -1.0)
	assert_almost_eq(float(negative["fraction"]), 0.5, 0.0001)


func test_insurance_does_not_change_non_break_payout() -> void:
	var paid: Dictionary = EndlessReward.payout(100, 10, "quit", 0.3)
	assert_eq(int(paid["gold"]), 100)


func test_contract_bonus_raises_level_gold() -> void:
	var profile: Dictionary = {"reward_gold": 40, "reward_scrap": 2, "difficulty": 1}
	var plain: Dictionary = EndlessReward.level_reward(1, 0.0, profile)
	var boosted: Dictionary = EndlessReward.level_reward(1, 0.0, profile, {"gold_pct": 0.25})
	assert_true(int(boosted["gold"]) > int(plain["gold"]), "sözleşme altını artırmalı")
