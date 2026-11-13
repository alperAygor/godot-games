extends TestCase

## AdPacing: geçiş reklamı sıklığı. Saat dışarıdan verildiği için süreler anında sınanır.

var _pacing: Dictionary = {}


func before_each() -> void:
	_pacing = (ProgressData.DEFAULT_BALANCE["interstitial"] as Dictionary).duplicate()


func test_never_before_first_level() -> void:
	for level: int in range(1, 4):
		assert_false(AdPacing.should_show(level, 99, 10000.0, 0.0, 0.0, _pacing), "seviye %d" % level)


func test_needs_two_or_three_levels_since_last() -> void:
	for level: int in range(4, 40):
		var needed: int = AdPacing.levels_needed(level, _pacing)
		assert_true(needed == 2 or needed == 3, "gereken 2-3 olmalı")
		assert_false(AdPacing.should_show(level, needed - 1, 10000.0, 0.0, 0.0, _pacing))
		assert_true(AdPacing.should_show(level, needed, 10000.0, 0.0, 0.0, _pacing))


func test_needs_ninety_seconds_between() -> void:
	var level: int = 4
	var needed: int = AdPacing.levels_needed(level, _pacing)
	assert_false(AdPacing.should_show(level, needed, 1089.0, 1000.0, 0.0, _pacing))
	assert_true(AdPacing.should_show(level, needed, 1090.0, 1000.0, 0.0, _pacing))


func test_never_right_after_rewarded_ad() -> void:
	var level: int = 4
	var needed: int = AdPacing.levels_needed(level, _pacing)
	assert_false(AdPacing.should_show(level, needed, 5000.0, 0.0, 4950.0, _pacing))
	assert_true(AdPacing.should_show(level, needed, 5000.0, 0.0, 4800.0, _pacing))
