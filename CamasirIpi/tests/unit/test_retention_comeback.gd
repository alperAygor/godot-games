extends TestCase

## Geri dönüş hediyesi + oturum serisi + yerel bildirim planı + sağlayıcı.

const DAY: String = "2026-11-13"


func _cfg() -> Dictionary:
	return RetentionData.comeback()


func _ctx(level: int = 12) -> Dictionary:
	return {"level": level, "unlock_levels": {"undo": 6, "pin_remover": 12, "extra_slot": 18}, "fallback_coins": 40}


func _day(offset: int) -> String:
	return DailyDate.add_days(DAY, offset)


func _play(state: Dictionary, offset: int, level: int = 12) -> Dictionary:
	return Comeback.touch(state, _day(offset), _cfg(), _ctx(level))


func test_first_session_has_no_gift() -> void:
	var state: Dictionary = _play({}, 0)
	assert_eq(Comeback.streak_position(state, _cfg()), 1, "seri 1")
	assert_false(Comeback.has_pending(state), "ilk gün hediye yok")


func test_same_day_is_idempotent() -> void:
	var state: Dictionary = _play({}, 0)
	assert_eq(_play(state, 0), state, "aynı gün değişmez")


func test_one_day_away_is_not_a_comeback() -> void:
	var state: Dictionary = _play(_play({}, 0), 1)
	assert_false(Comeback.has_pending(state), "ertesi gün dönüş değil")
	assert_eq(Comeback.streak_position(state, _cfg()), 2, "seri 2")


func test_comeback_gift_scales_with_absence() -> void:
	var two: Dictionary = Comeback.pending(_play(_play({}, 0), 2))
	assert_eq(int(two["away"]), 2, "2 gün")
	var six: Dictionary = Comeback.pending(_play(_play({}, 0), 6))
	var seven: Dictionary = Comeback.pending(_play(_play({}, 0), 7))
	var coins_two: int = int((two["reward"] as Dictionary)["coins"])
	var coins_six: int = int((six["reward"] as Dictionary)["coins"])
	var coins_seven: int = int((seven["reward"] as Dictionary)["coins"])
	assert_greater(float(coins_six), float(coins_two), "6 gün 2 günden büyük")
	assert_greater(float(coins_seven), float(coins_six), "7+ gün daha büyük")
	assert_eq(((two["reward"] as Dictionary)["boosters"] as Dictionary).size(), 1, "2-6 gün: 1 güçlendirici")
	assert_eq(int(((seven["reward"] as Dictionary)["boosters"] as Dictionary).values()[0]), 2, "7+ gün: 2 güçlendirici")
	assert_eq(int((seven["reward"] as Dictionary)["stars"]), 3, "7+ gün yıldız")


func test_comeback_resets_streak_and_blocks_low_level_gift() -> void:
	var state: Dictionary = _play(_play(_play({}, 0), 1), 5)
	assert_eq(Comeback.streak_position(state, _cfg()), 1, "ara verince seri 1")
	var low: Dictionary = _play(_play({}, 0, 2), 5, 2)
	assert_false(Comeback.has_pending(low), "çok düşük seviyede hediye yok")


func test_booster_falls_back_to_coins_when_none_unlocked() -> void:
	var state: Dictionary = _play(_play({}, 0, 4), 3, 4)
	var reward: Dictionary = (Comeback.pending(state)["reward"] as Dictionary)
	assert_true((reward["boosters"] as Dictionary).is_empty(), "açık güçlendirici yok")
	assert_eq(int(reward["coins"]), 30 + 15 * 3 + 40, "jeton olarak ödenir")


func test_streak_bonus_only_on_day_three_and_seven() -> void:
	var state: Dictionary = {}
	var bonus_days: Array[int] = []
	for offset: int in range(9):
		state = _play(state, offset)
		if Comeback.has_pending(state):
			bonus_days.append(Comeback.streak_position(state, _cfg()))
			state = (Comeback.claim_pending(state)["state"] as Dictionary)
	assert_eq(bonus_days, [3, 7] as Array[int], "yalnız 3 ve 7. gün")
	assert_eq(Comeback.streak_position(state, _cfg()), 2, "9. gün döngüde 2")


func test_claim_pending_once() -> void:
	var state: Dictionary = _play(_play({}, 0), 3)
	var claimed: Dictionary = Comeback.claim_pending(state)
	assert_true(bool(claimed["ok"]), "alındı")
	assert_false(Comeback.has_pending(claimed["state"] as Dictionary), "bekleyen temizlendi")
	assert_false(bool(Comeback.claim_pending(claimed["state"] as Dictionary)["ok"]), "çift alma yok")


func test_clock_going_backwards_does_not_break_state() -> void:
	var state: Dictionary = _play(_play({}, 5), 6)
	assert_eq(_play(state, 2), state, "saat geri alındı: durum aynı")


func _notify_cfg() -> Dictionary:
	return RetentionData.core()["notify"] as Dictionary


func test_notify_plan_times() -> void:
	var now: Dictionary = {"day": "2026-11-13", "hour": 20, "minute": 0, "second": 0}
	var plan: Array[Dictionary] = RetentionNotifyPlan.plan(now, {"missions": true, "weekly": true}, _notify_cfg())
	var by_id: Dictionary = {}
	for entry: Dictionary in plan:
		by_id[String(entry["id"])] = int(entry["seconds"])
	assert_eq(int(by_id["ret_daily_gift"]), 13 * 3600, "akşam 20:00 -> ertesi 09:00 = 13 sa")
	# 24 sa sonrası 20:00 sessiz saat değil.
	assert_eq(int(by_id["ret_missions"]), 24 * 3600, "24 sa boşta")
	# Cuma 20:00 -> Cumartesi 18:00 = 22 sa.
	assert_eq(int(by_id["ret_weekly_end"]), 22 * 3600, "Cumartesi 18:00")


func test_notify_quiet_hours_shift_and_locks() -> void:
	var late: Dictionary = {"day": "2026-11-13", "hour": 2, "minute": 30, "second": 0}
	var plan: Array[Dictionary] = RetentionNotifyPlan.plan(late, {"missions": true, "weekly": false}, _notify_cfg())
	var missions: int = 0
	for entry: Dictionary in plan:
		assert_false(String(entry["id"]) == "ret_weekly_end", "haftalık kilitliyken yok")
		if String(entry["id"]) == "ret_missions":
			missions = int(entry["seconds"])
	# 02:30 + 24 sa = ertesi 02:30 (sessiz) -> 09:00'a kayar.
	assert_eq(missions, 24 * 3600 + 6 * 3600 + 30 * 60, "sessiz saatte sabaha kayar")
	var locked: Array[Dictionary] = RetentionNotifyPlan.plan(late, {"missions": false, "weekly": false}, _notify_cfg())
	assert_eq(locked.size(), 1, "yalnız günlük hediye")
	var sunday: Dictionary = {"day": "2026-11-15", "hour": 10, "minute": 0, "second": 0}
	for entry: Dictionary in RetentionNotifyPlan.plan(sunday, {"missions": true, "weekly": true}, _notify_cfg()):
		assert_false(String(entry["id"]) == "ret_weekly_end", "Pazar günü 'yarın biter' yok")


func test_notifier_noop_provider_records_and_cancels() -> void:
	var saved: Notifier.Provider = Notifier.provider
	var noop: Notifier.NoopProvider = Notifier.NoopProvider.new()
	Notifier.provider = noop
	Notifier.schedule("a", 60, "RET_N_GIFT_T", "RET_N_GIFT_B")
	assert_true(noop.scheduled.has("a"), "kaydedildi")
	assert_eq(int((noop.scheduled["a"] as Dictionary)["seconds"]), 60, "saniye")
	Notifier.cancel("a")
	assert_false(noop.scheduled.has("a"), "iptal")
	Notifier.provider = saved
