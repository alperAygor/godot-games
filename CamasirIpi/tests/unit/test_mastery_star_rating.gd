extends TestCase

## StarRating: 1-3 yıldız eşikleri, kusursuz/zincir bonusu ve denge dosyası uyumu.

var _balance: Dictionary = {}


func before_each() -> void:
	_balance = ProgressData.DEFAULT_BALANCE.duplicate(true)


func test_budgets_scale_with_level_size() -> void:
	assert_eq(StarRating.two_star_budget(6, _balance), 2, "küçük seviyede alt sınır")
	assert_eq(StarRating.two_star_budget(21, _balance), 6)
	assert_eq(StarRating.two_star_budget(45, _balance), 12)
	assert_eq(StarRating.perfect_budget(6, _balance), 1)
	assert_eq(StarRating.perfect_budget(21, _balance), 2)
	assert_eq(StarRating.perfect_budget(45, _balance), 3)


func test_finished_with_heavy_rack_is_one_star() -> void:
	assert_eq(StarRating.rate(7, 21, false, _balance), 1)
	assert_eq(StarRating.rate(40, 45, false, _balance), 1)


func test_moderate_rack_is_two_stars() -> void:
	assert_eq(StarRating.rate(6, 21, false, _balance), 2)
	assert_eq(StarRating.rate(3, 21, false, _balance), 2)


func test_light_rack_without_revive_is_three_stars() -> void:
	assert_eq(StarRating.rate(0, 21, false, _balance), 3)
	assert_eq(StarRating.rate(2, 21, false, _balance), 3)
	assert_eq(StarRating.rate(1, 6, false, _balance), 3)
	assert_eq(StarRating.rate(2, 6, false, _balance), 2)


func test_revive_blocks_three_stars_but_not_two() -> void:
	assert_eq(StarRating.rate(0, 21, true, _balance), 2)
	assert_eq(StarRating.rate(7, 21, true, _balance), 1)


func test_perfect_bonus_only_at_three_stars() -> void:
	assert_eq(StarRating.perfect_bonus(1, _balance), 0)
	assert_eq(StarRating.perfect_bonus(2, _balance), 0)
	assert_eq(StarRating.perfect_bonus(3, _balance), 15)


func test_chain_bonus_steps_and_cap() -> void:
	assert_eq(StarRating.chain_bonus(0, _balance), 0)
	assert_eq(StarRating.chain_bonus(1, _balance), 0)
	assert_eq(StarRating.chain_bonus(2, _balance), 2)
	assert_eq(StarRating.chain_bonus(4, _balance), 6)
	assert_eq(StarRating.chain_bonus(7, _balance), 12)
	assert_eq(StarRating.chain_bonus(50, _balance), 12, "tavan")


func test_breakdown_adds_up() -> void:
	var result: Dictionary = StarRating.breakdown(20, 3, 4, _balance)
	assert_eq(int(result["perfect"]), 15)
	assert_eq(int(result["chain"]), 6)
	assert_eq(int(result["total"]), 41)
	var plain: Dictionary = StarRating.breakdown(40, 1, 1, _balance)
	assert_eq(int(plain["total"]), 40)


func test_rate_stats_uses_run_stats() -> void:
	var stats: RunStats = RunStats.new()
	assert_eq(StarRating.rate_stats(stats, 21, _balance), 3)
	stats.note_revive()
	assert_eq(StarRating.rate_stats(stats, 21, _balance), 2)


func test_missing_or_broken_balance_falls_back() -> void:
	assert_eq(StarRating.perfect_bonus(3, {}), StarRating.FALLBACK_PERFECT_BONUS)
	assert_eq(StarRating.rate(0, 21, false, {"mastery": "bozuk"}), 3)
	assert_eq(StarRating.two_star_budget(20, {"mastery": {"two_star_rack_ratio": "x"}}), 5)


func test_balance_file_drives_thresholds() -> void:
	var loaded: Dictionary = ProgressData.load_balance()
	assert_eq(StarRating.perfect_budget(21, loaded), 2)
	assert_eq(StarRating.two_star_budget(21, loaded), 6)
	assert_eq(StarRating.chain_bonus(3, loaded), 4)
