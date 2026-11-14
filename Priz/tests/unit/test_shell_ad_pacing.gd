extends TestCase

## AdPacing: Priz reklam politikası (saf karar). Kurallar data/ads.json'dan okunur.
##  * ilk 3 seviye sessiz, geçiş reklamı 5. seviyeden sonra, 2-3 seviyede bir (belirlenimci 2,3,2,3),
##    en az 90 sn arayla, ödüllü izlenen geçişte yok, reklamlar kaldırıldıysa yok,
##  * banner yalnız mahalle ve koleksiyonda.

var _pacing: Dictionary = {}
var _quiet: Dictionary = {}
var _banner: Dictionary = {}
const NOW: float = 100000.0


func before_each() -> void:
	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ads.json")) as Dictionary
	_pacing = (table["interstitial"] as Dictionary).duplicate()
	_quiet = (table["quiet"] as Dictionary).duplicate()
	_banner = (table["banner"] as Dictionary).duplicate()


## Basit yardımcı: `levels_since` ve `shown` verilir, son reklam çok eskidir.
func _show(level: int, levels_since: int, shown: int = 0, rewarded: bool = false, removed: bool = false,
		last_time: float = 0.0) -> bool:
	return AdPacing.should_show(level, removed, rewarded, levels_since, shown, last_time, NOW, _pacing, _quiet)


func test_ads_file_matches_design() -> void:
	assert_eq(int(_quiet["levels"]), 3)
	assert_eq(int(_pacing["first_after_level"]), 5)
	assert_eq(_pacing["gap_cycle"], [2.0, 3.0] as Array)
	assert_eq(float(_pacing["min_seconds_between"]), 90.0)
	assert_false(_pacing.has("first_level"), "şablonun 4. seviyeden her geçişte kuralı kaldırıldı")


func test_quiet_period_is_first_three_levels() -> void:
	for level: int in range(1, 4):
		assert_true(AdPacing.is_quiet(level, _quiet), "seviye %d sessiz" % level)
	assert_false(AdPacing.is_quiet(4, _quiet))


func test_never_in_quiet_period_or_before_level_five() -> void:
	for level: int in range(1, 5):
		assert_false(_show(level, 99), "seviye %d tamamlanınca geçiş reklamı yok" % level)
	assert_true(_show(5, 5), "seviye 5 bitince ilk geçiş reklamı")


func test_gap_cycle_alternates_two_three_deterministically() -> void:
	assert_eq(AdPacing.gap_after(1, _pacing), 2)
	assert_eq(AdPacing.gap_after(2, _pacing), 3)
	assert_eq(AdPacing.gap_after(3, _pacing), 2)
	assert_eq(AdPacing.gap_after(4, _pacing), 3)


func test_every_two_or_three_levels_after_the_first() -> void:
	# Seviyeleri sırayla bitir; reklam gösterilince sayaç sıfırlanır (Progress.mark_interstitial_shown gibi).
	var since: int = 0
	var shown: int = 0
	var ad_levels: Array[int] = []
	for level: int in range(1, 31):
		since += 1
		if _show(level, since, shown):
			ad_levels.append(level)
			since = 0
			shown += 1
	assert_eq(ad_levels, [5, 7, 10, 12, 15, 17, 20, 22, 25, 27, 30] as Array[int])
	for index: int in range(1, ad_levels.size()):
		var gap: int = ad_levels[index] - ad_levels[index - 1]
		assert_true(gap == 2 or gap == 3, "aralık 2 ya da 3 olmalı")


func test_needs_ninety_seconds_between_ads() -> void:
	assert_false(_show(8, 2, 1, false, false, NOW - 30.0), "30 sn önce reklam vardı")
	assert_false(_show(8, 3, 1, false, false, NOW - 89.0))
	assert_true(_show(8, 3, 1, false, false, NOW - 90.0))
	assert_true(_show(8, 3, 1, false, false, 0.0), "hiç reklam gösterilmediyse süre koşulu yok")


func test_not_before_gap_is_reached() -> void:
	assert_false(_show(6, 1, 1), "ilk reklamdan sonra en az 2 seviye")
	assert_true(_show(7, 2, 1))
	assert_false(_show(9, 2, 2), "ikinci reklamdan sonra 3 seviye")
	assert_true(_show(10, 3, 2))


func test_never_right_after_rewarded_ad_in_same_transition() -> void:
	assert_false(_show(7, 9, 0, true), "ödüllü izlenen geçişte yok")
	assert_true(_show(7, 9, 0, false), "bir sonraki geçişte yine gösterilir")


func test_never_when_remove_ads_owned() -> void:
	for level: int in range(1, 30):
		assert_false(_show(level, 9, 0, false, true))


func test_missing_pacing_falls_back_to_design_defaults() -> void:
	assert_false(AdPacing.should_show(4, false, false, 9, 0, 0.0, NOW, {}, {}))
	assert_true(AdPacing.should_show(5, false, false, 9, 0, 0.0, NOW, {}, {}))
	assert_eq(AdPacing.gap_after(0, {}), 2)


func test_owner_can_change_rules_in_data() -> void:
	var late: Dictionary = {"first_after_level": 10, "gap_cycle": [4], "min_seconds_between": 0}
	assert_false(AdPacing.should_show(9, false, false, 9, 0, 0.0, NOW, late, _quiet))
	assert_true(AdPacing.should_show(10, false, false, 9, 0, 0.0, NOW, late, _quiet))
	assert_false(AdPacing.should_show(14, false, false, 3, 1, NOW, NOW, late, _quiet), "bekleme 4 seviye")
	assert_true(AdPacing.should_show(14, false, false, 4, 1, NOW, NOW, late, _quiet))


func test_banner_only_on_neighbourhood_and_collection() -> void:
	assert_true(AdPacing.banner_allowed(&"neighbourhood", false, false, _banner))
	assert_true(AdPacing.banner_allowed(&"collection", false, false, _banner))
	assert_false(AdPacing.banner_allowed(&"game", false, false, _banner), "oyun ekranında asla")
	assert_false(AdPacing.banner_allowed(&"settings", false, false, _banner))
	assert_false(AdPacing.banner_allowed(&"game", false, false, {}), "veri yokken de oyun ekranı kapalı")


func test_banner_hidden_in_quiet_period_and_when_ads_removed() -> void:
	assert_false(AdPacing.banner_allowed(&"neighbourhood", false, true, _banner))
	assert_false(AdPacing.banner_allowed(&"neighbourhood", true, false, _banner))
