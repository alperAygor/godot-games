extends TestCase

## AnalyticsLog: halka tampon, sayaç, olay yardımcıları.

func before_each() -> void:
	AnalyticsLog.echo = false
	AnalyticsLog.clear()


func test_records_and_counts_events() -> void:
	AnalyticsLog.level_start(1)
	AnalyticsLog.level_win(1, 2.5)
	AnalyticsLog.level_lose(2, 1.0)
	assert_eq(AnalyticsLog.count("level_start"), 1)
	assert_eq(AnalyticsLog.count("level_win"), 1)
	assert_eq(AnalyticsLog.count("level_lose"), 1)
	assert_eq(AnalyticsLog.events().size(), 3)
	assert_eq(AnalyticsLog.events()[1]["level"], 1)


func test_ring_buffer_drops_oldest() -> void:
	for index: int in range(AnalyticsLog.MAX_EVENTS + 25):
		AnalyticsLog.record("e", {"i": index})
	assert_eq(AnalyticsLog.events().size(), AnalyticsLog.MAX_EVENTS)
	assert_eq(int(AnalyticsLog.events()[0]["i"]), 25)


func test_ad_event_helpers() -> void:
	AnalyticsLog.rewarded_offered("CONTINUE")
	AnalyticsLog.rewarded_watched("CONTINUE")
	AnalyticsLog.rewarded_skipped("DOUBLE_COINS")
	AnalyticsLog.interstitial_shown(5)
	assert_eq(AnalyticsLog.count("rewarded_offered"), 1)
	assert_eq(AnalyticsLog.count("rewarded_watched"), 1)
	assert_eq(AnalyticsLog.count("rewarded_skipped"), 1)
	assert_eq(AnalyticsLog.count("interstitial_shown"), 1)
