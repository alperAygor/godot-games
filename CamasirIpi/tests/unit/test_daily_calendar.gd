extends TestCase

## 7 günlük takvim kuralları: alma, çift alma reddi, ertesi gün, kaçırma, 7. gün sonrası sarma.

const DAY_ONE: String = "2026-11-13"


func _claim_days(offsets: Array[int]) -> Dictionary:
	var state: Dictionary = {}
	for offset: int in offsets:
		var result: Dictionary = DailyCalendarLogic.claim(state, DailyDate.add_days(DAY_ONE, offset))
		state = result["state"] as Dictionary
	return state


func test_first_claim_is_day_one() -> void:
	var result: Dictionary = DailyCalendarLogic.claim({}, DAY_ONE)
	assert_true(bool(result["ok"]), "ilk alma")
	assert_eq(int(result["day"]), 1, "1. gün")
	assert_greater(float((result["reward"] as Dictionary)["coins"]), 0.0, "ödül jeton")


func test_double_claim_refused() -> void:
	var state: Dictionary = _claim_days([0])
	assert_false(DailyCalendarLogic.can_claim_today(state, DAY_ONE), "aynı gün alınamaz")
	var again: Dictionary = DailyCalendarLogic.claim(state, DAY_ONE)
	assert_false(bool(again["ok"]), "ikinci alma reddedilir")
	assert_eq(int((again["state"] as Dictionary)["day"]), 1, "durum değişmez")


func test_next_day_advances() -> void:
	var state: Dictionary = _claim_days([0, 1, 2])
	assert_eq(int(state["day"]), 3, "ardışık günler")
	assert_true(DailyCalendarLogic.can_claim_today(state, DailyDate.add_days(DAY_ONE, 3)), "ertesi gün hazır")
	assert_eq(DailyCalendarLogic.claimable_day(state, DailyDate.add_days(DAY_ONE, 3)), 4, "sıradaki 4. gün")


func test_missed_day_resets_to_one() -> void:
	var state: Dictionary = _claim_days([0, 1, 2])
	assert_eq(DailyCalendarLogic.claimable_day(state, DailyDate.add_days(DAY_ONE, 4)), 1, "gün kaçtı -> 1")


func test_wrap_after_day_seven() -> void:
	var state: Dictionary = _claim_days([0, 1, 2, 3, 4, 5, 6])
	assert_eq(int(state["day"]), 7, "7. gün alındı")
	var seven: Dictionary = DailyCalendarLogic.reward_for_day(7)
	assert_greater(float(seven["coins"]), float(DailyCalendarLogic.reward_for_day(6)["coins"]), "7. gün en büyük")
	assert_eq(DailyCalendarLogic.claimable_day(state, DailyDate.add_days(DAY_ONE, 7)), 1, "8. gün başa sarar")


func test_rewards_grow() -> void:
	var previous: int = 0
	for day: int in range(1, DailyCalendarLogic.day_count() + 1):
		var coins: int = int(DailyCalendarLogic.reward_for_day(day)["coins"])
		assert_greater(float(coins), float(previous) - 1.0, "ödül azalmaz: gün %d" % day)
		previous = coins


func test_clock_set_back_is_safe() -> void:
	var state: Dictionary = _claim_days([0, 1, 2])
	assert_eq(DailyCalendarLogic.claimable_day(state, DAY_ONE), 1, "saat geri alındıysa başa döner")


func test_tile_states() -> void:
	var fresh: Array[int] = DailyCalendarLogic.tile_states({}, DAY_ONE)
	assert_eq(fresh.size(), 7, "7 karo")
	assert_eq(fresh[0], DailyCalendarLogic.TILE_TODAY, "taze: 1. gün bugün")
	assert_eq(fresh[1], DailyCalendarLogic.TILE_UPCOMING, "geri kalan yaklaşan")
	var third: Array[int] = DailyCalendarLogic.tile_states(_claim_days([0, 1, 2]), DailyDate.add_days(DAY_ONE, 2))
	assert_eq(third[2], DailyCalendarLogic.TILE_CLAIMED, "3. gün alındı")
	assert_eq(third[3], DailyCalendarLogic.TILE_UPCOMING, "4. yaklaşan")
	var next: Array[int] = DailyCalendarLogic.tile_states(_claim_days([0, 1]), DailyDate.add_days(DAY_ONE, 2))
	assert_eq(next[1], DailyCalendarLogic.TILE_CLAIMED, "önceki alındı")
	assert_eq(next[2], DailyCalendarLogic.TILE_TODAY, "3. bugün")
