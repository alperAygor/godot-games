extends TestCase

## AdPacing: geçiş reklamı sırası (ilk 3 seviyede yok, sonra her 3 seviyede bir), istisnalar ve düğme eşiği.
## Sayılar data/ads.json'dan okunur; sahibin kararı değişirse test veriyle birlikte değişir.

var _pacing: Dictionary = {}
var _rewarded: Dictionary = {}


func before_each() -> void:
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ads.json")) as Dictionary
	_pacing = (parsed["interstitial"] as Dictionary).duplicate()
	_rewarded = (parsed["rewarded"] as Dictionary).duplicate()


## 1..count seviyesini ardışık, ilk kez bitiren oyuncu için geçiş reklamı gelen seviyeler.
func _ad_levels(count: int) -> Array[int]:
	var found: Array[int] = []
	for level: int in range(1, count + 1):
		if AdPacing.should_show(level, true, false, false, AdPacing.NEVER_SECONDS, _pacing):
			found.append(level)
	return found


func test_ads_file_numbers() -> void:
	assert_eq(int(_pacing["first_level"]), 4)
	assert_eq(int(_pacing["every_n"]), 3)
	assert_eq(int(_pacing["min_gap_seconds"]), 60)
	assert_true(bool(_pacing["suppress_after_rewarded"]))
	assert_eq(int(_rewarded["buttons_from_level"]), 4)


func test_exact_sequence_over_twelve_levels() -> void:
	# 3. seviye bitince ilk reklam (4'e geçiş), sonra 6, 9, 12 bitişlerinde.
	assert_eq(_ad_levels(12), [3, 6, 9, 12] as Array[int])


func test_nothing_while_playing_levels_one_to_three() -> void:
	# 1. ve 2. seviyenin bitişinde (3'e geçiş) reklam yok; reklam yalnız 3 bitince başlar.
	assert_false(AdPacing.is_due(1, true, _pacing))
	assert_false(AdPacing.is_due(2, true, _pacing))
	assert_true(AdPacing.is_due(3, true, _pacing))


func test_cadence_keeps_going_every_third_level() -> void:
	var found: Array[int] = _ad_levels(60)
	assert_eq(found.size(), 20)
	for index: int in found.size():
		assert_eq(found[index], 3 * (index + 1))


func test_replaying_a_completed_level_never_counts() -> void:
	for level: int in range(1, 30):
		assert_false(AdPacing.should_show(level, false, false, false, AdPacing.NEVER_SECONDS, _pacing))


func test_never_when_remove_ads_owned() -> void:
	for level: int in range(1, 30):
		assert_false(AdPacing.should_show(level, true, true, false, AdPacing.NEVER_SECONDS, _pacing))


func test_not_on_a_transition_with_a_rewarded_ad() -> void:
	assert_false(AdPacing.should_show(6, true, false, true, AdPacing.NEVER_SECONDS, _pacing))
	assert_true(AdPacing.should_show(6, true, false, false, AdPacing.NEVER_SECONDS, _pacing), "rewarded yoksa gelir")
	var lenient: Dictionary = _pacing.duplicate()
	lenient["suppress_after_rewarded"] = false
	assert_true(AdPacing.should_show(6, true, false, true, AdPacing.NEVER_SECONDS, lenient), "veriyle kapatılabilir")


func test_minimum_gap_between_interstitials() -> void:
	assert_false(AdPacing.should_show(6, true, false, false, 59.9, _pacing))
	assert_true(AdPacing.should_show(6, true, false, false, 60.0, _pacing))
	assert_true(AdPacing.should_show(6, true, false, false, 600.0, _pacing))


func test_seconds_since_handles_missing_and_backwards_clock() -> void:
	assert_eq(AdPacing.seconds_since(1000.0, 0.0), AdPacing.NEVER_SECONDS, "hiç gösterilmedi")
	assert_eq(AdPacing.seconds_since(1000.0, 940.0), 60.0)
	assert_eq(AdPacing.seconds_since(900.0, 1000.0), AdPacing.NEVER_SECONDS, "saat geri alındı: engel yok")


func test_owner_can_change_numbers_in_data() -> void:
	var custom: Dictionary = {"first_level": 6, "every_n": 2, "min_gap_seconds": 0}
	var found: Array[int] = []
	for level: int in range(1, 13):
		if AdPacing.should_show(level, true, false, false, 0.0, custom):
			found.append(level)
	assert_eq(found, [5, 7, 9, 11] as Array[int])


func test_missing_pacing_falls_back_to_defaults() -> void:
	assert_true(AdPacing.is_due(3, true, {}))
	assert_false(AdPacing.is_due(4, true, {}))
	assert_eq(AdPacing.min_gap_seconds({}), 60.0)
	assert_eq(AdPacing.min_gap_seconds({"min_gap_seconds": -5}), 60.0, "bozuk değer yedeğe düşer")
	assert_eq(AdPacing.min_gap_seconds({"min_gap_seconds": "x"}), 60.0)


func test_every_n_zero_does_not_divide_by_zero() -> void:
	assert_true(AdPacing.is_due(3, true, {"first_level": 4, "every_n": 0}))


func test_rewarded_buttons_hidden_on_first_three_levels() -> void:
	for level: int in range(1, 4):
		assert_false(AdPacing.rewarded_buttons_visible(level, _rewarded), "seviye %d" % level)
	for level: int in range(4, 20):
		assert_true(AdPacing.rewarded_buttons_visible(level, _rewarded), "seviye %d" % level)
	assert_false(AdPacing.rewarded_buttons_visible(3, {}))
	assert_true(AdPacing.rewarded_buttons_visible(4, {}))
