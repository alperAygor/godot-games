extends TestCase

## AdPacing: geçiş reklamı kararı. Varsayılan: 4. seviyeden itibaren her geçişte; üç istisna test edilir.

var _pacing: Dictionary = {}


func before_each() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/ads.json"))
	_pacing = ((parsed as Dictionary)["interstitial"] as Dictionary).duplicate()


func test_never_before_first_level() -> void:
	for level: int in range(1, 4):
		assert_false(AdPacing.should_show(level, false, false, _pacing), "seviye %d reklamsız" % level)


func test_every_transition_from_level_four() -> void:
	for level: int in range(4, 60):
		assert_true(AdPacing.should_show(level, false, false, _pacing), "seviye %d her geçişte" % level)


func test_ads_file_first_level_is_four_and_has_no_interval_rules() -> void:
	assert_eq(int(_pacing["first_level"]), 4)
	assert_false(_pacing.has("min_seconds_between"), "süre aralığı yok")
	assert_false(_pacing.has("min_levels_between"), "seviye aralığı yok")


func test_never_when_remove_ads_owned() -> void:
	for level: int in range(1, 30):
		assert_false(AdPacing.should_show(level, true, false, _pacing))


func test_never_right_after_rewarded_ad_in_same_transition() -> void:
	assert_false(AdPacing.should_show(5, false, true, _pacing))
	assert_true(AdPacing.should_show(5, false, false, _pacing), "bir sonraki geçişte yine gösterilir")


func test_owner_can_change_first_level_in_data() -> void:
	var late: Dictionary = {"first_level": 10}
	assert_false(AdPacing.should_show(9, false, false, late))
	assert_true(AdPacing.should_show(10, false, false, late))


func test_missing_pacing_falls_back_to_default_first_level() -> void:
	assert_false(AdPacing.should_show(3, false, false, {}))
	assert_true(AdPacing.should_show(4, false, false, {}))
