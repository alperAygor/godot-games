extends TestCase

## AdPacing: geçiş reklamı kararı. 4. seviyeden itibaren her geçişte; üç istisna test edilir.

var _pacing: Dictionary = {}


func before_each() -> void:
	_pacing = (ProgressData.DEFAULT_BALANCE["interstitial"] as Dictionary).duplicate()


func test_never_before_first_level() -> void:
	for level: int in range(1, 4):
		assert_false(AdPacing.should_show(level, false, false, _pacing), "seviye %d reklamsız" % level)


func test_every_transition_from_level_four() -> void:
	for level: int in range(4, 60):
		assert_true(AdPacing.should_show(level, false, false, _pacing), "seviye %d her geçişte" % level)


func test_balance_file_first_level_is_four() -> void:
	var balance: Dictionary = ProgressData.load_balance()
	var pacing: Dictionary = balance["interstitial"] as Dictionary
	assert_eq(int(pacing["first_level"]), 4)
	assert_false(pacing.has("min_seconds_between"), "süre aralığı kaldırıldı")
	assert_false(pacing.has("min_levels_between"), "seviye aralığı kaldırıldı")


func test_never_when_remove_ads_owned() -> void:
	for level: int in range(1, 30):
		assert_false(AdPacing.should_show(level, true, false, _pacing))


func test_never_right_after_rewarded_ad_in_same_transition() -> void:
	assert_false(AdPacing.should_show(5, false, true, _pacing))
	assert_true(AdPacing.should_show(5, false, false, _pacing), "bir sonraki geçişte yine gösterilir")


func test_missing_pacing_falls_back_to_default_first_level() -> void:
	assert_false(AdPacing.should_show(3, false, false, {}))
	assert_true(AdPacing.should_show(4, false, false, {}))
