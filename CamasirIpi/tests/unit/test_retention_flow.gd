extends TestCase

## Yapıştırıcı katman: olay -> kayıt -> ödül, gün/hafta devri otomatik ödülü, rozet sayısı.
## Gerçek kayıt dosyasına dokunmamak için ayrı bir Progress örneği (persist=false) enjekte edilir.

const MONDAY: String = "2026-11-09"

var _progress: Node = null


func before_each() -> void:
	_progress = (load("res://scripts/autoload/Progress.gd") as GDScript).new()
	_progress.set("persist", false)
	_progress.set("balance", ProgressData.load_balance())
	_progress.data.level = 12
	RetentionStore.progress_override = _progress
	RetentionStore.today_override = MONDAY
	AnalyticsLog.echo = false
	AnalyticsLog.clear()


func after_each() -> void:
	RetentionStore.progress_override = null
	RetentionStore.today_override = ""
	RetentionEvents.clear_listeners()
	_progress.free()


func _seed_missions() -> void:
	RetentionStore.put(RetentionFlow.KEY_MISSIONS, {"day": MONDAY, "chest": false, "items": [
		{"id": "baskets", "target": 2, "progress": 0, "claimed": false, "reward": {"coins": 20}},
		{"id": "levels", "target": 1, "progress": 0, "claimed": false, "reward": {"coins": 20}},
		{"id": "daily", "target": 1, "progress": 0, "claimed": false, "reward": {"coins": 30}},
	]})


func test_emit_feeds_missions_and_claim_grants_coins() -> void:
	_seed_missions()
	RetentionEvents.emit("basket_completed", 1, {"color": 1, "count": 3, "chain": 1})
	RetentionEvents.emit("basket_completed", 1, {"color": 2, "count": 3, "chain": 2})
	var state: Dictionary = RetentionFlow.sync_missions(MONDAY)
	assert_true(Missions.is_done(Missions.items(state)[0]), "iki sepet -> görev tamam")
	var coins_before: int = int(_progress.call("coins"))
	var reward: Dictionary = RetentionFlow.claim_mission(0, MONDAY)
	assert_eq(int(reward["coins"]), 20, "ödül")
	assert_eq(int(_progress.call("coins")), coins_before + 20, "jeton eklendi")
	assert_true(RetentionFlow.claim_mission(0, MONDAY).is_empty(), "çift alma yok")
	assert_eq(AnalyticsLog.count("ret_mission_claim"), 1, "analitik")


func test_events_ignored_below_unlock_level() -> void:
	_progress.data.level = 3
	_seed_missions()
	RetentionEvents.emit("level_won", 1, {"stars": 3})
	var state: Dictionary = RetentionStore.get_dict(RetentionFlow.KEY_MISSIONS)
	assert_eq(int(Missions.items(state)[1]["progress"]), 0, "5. seviyeden önce görev işlemez")
	assert_false(RetentionFlow.missions_unlocked(), "kilitli")


func test_day_rollover_auto_grants_completed_missions() -> void:
	_seed_missions()
	RetentionEvents.emit("level_won", 1, {"stars": 1})
	var coins_before: int = int(_progress.call("coins"))
	var next_day: String = DailyDate.add_days(MONDAY, 1)
	RetentionStore.today_override = next_day
	var state: Dictionary = RetentionFlow.sync_missions(next_day)
	assert_eq(String(state["day"]), next_day, "yeni gün")
	assert_eq(int(_progress.call("coins")), coins_before + 20, "tamamlanan görev otomatik verildi")
	RetentionFlow.sync_missions(next_day)
	assert_eq(int(_progress.call("coins")), coins_before + 20, "ikinci senkron çift vermez")


func test_weekly_progress_and_auto_grant_on_rollover() -> void:
	var week: Dictionary = {"week": MONDAY, "theme": "blue", "progress": 0, "claimed": [0, 0, 0, 0, 0]}
	RetentionStore.put(RetentionFlow.KEY_WEEKLY, week)
	RetentionEvents.emit("basket_completed", 1, {"color": 1, "count": 3, "chain": 1})
	RetentionEvents.emit("basket_completed", 1, {"color": 0, "count": 3, "chain": 1})
	assert_eq(WeeklyEvent.progress(RetentionFlow.sync_weekly(MONDAY)), 3, "yalnız mavi sayıldı")
	RetentionStore.put(RetentionFlow.KEY_WEEKLY, {"week": MONDAY, "theme": "blue", "progress": 31, "claimed": [0, 0, 0, 0, 0]})
	var coins_before: int = int(_progress.call("coins"))
	var next: Dictionary = RetentionFlow.sync_weekly("2026-11-16")
	assert_eq(int(next["progress"]), 0, "hafta sıfırlandı")
	assert_eq(int(_progress.call("coins")), coins_before + 25 + 40, "iki kademe otomatik verildi")


func test_milestone_claim_grants_and_marks() -> void:
	_progress.data.level = 11
	var coins_before: int = int(_progress.call("coins"))
	var reward: Dictionary = RetentionFlow.claim_milestone(10)
	assert_eq(int(reward["coins"]), 50, "10. kilometre taşı jetonu")
	assert_eq(int(_progress.call("coins")), coins_before + 50, "jeton eklendi")
	assert_eq(int(_progress.call("stars")), 5, "yıldız paketi")
	assert_true(RetentionFlow.claim_milestone(10).is_empty(), "bir kez")


func test_comeback_claim_flow() -> void:
	RetentionFlow.touch_session(MONDAY)
	var later: String = DailyDate.add_days(MONDAY, 4)
	RetentionStore.today_override = later
	RetentionFlow.touch_session(later)
	assert_true(Comeback.has_pending(RetentionFlow.comeback_state()), "4 gün sonra bekleyen hediye")
	var coins_before: int = int(_progress.call("coins"))
	var reward: Dictionary = RetentionFlow.claim_comeback()
	assert_eq(int(reward["coins"]), 30 + 15 * 4, "hediye jetonu")
	assert_eq(int(_progress.call("coins")), coins_before + int(reward["coins"]), "jeton eklendi")
	assert_eq(int(_progress.call("booster_count", "undo")) + int(_progress.call("booster_count", "pin_remover")), 1, "1 güçlendirici")
	assert_true(RetentionFlow.claim_comeback().is_empty(), "çift alma yok")


func test_badge_counts_follow_state() -> void:
	_progress.data.level = 11
	_seed_missions()
	assert_eq(RetentionHub.badge_for(RetentionHub.KIND_MILESTONES), 2, "5 ve 10 hazır")
	assert_eq(RetentionHub.badge_for(RetentionHub.KIND_MISSIONS), 0, "görev bitmedi")
	RetentionEvents.emit("level_won", 1, {"stars": 1})
	assert_eq(RetentionHub.badge_for(RetentionHub.KIND_MISSIONS), 1, "bir görev alınabilir")
	assert_greater(float(RetentionHub.badge_count()), 2.0, "toplam rozet")


func test_declare_live_enables_optional_missions() -> void:
	assert_false(bool(RetentionStore.live_events().get("bird_shooed", false)), "başta kuş olayı yok")
	RetentionEvents.declare_live("bird_shooed")
	assert_true(bool(RetentionStore.live_events().get("bird_shooed", false)), "bildirildi")
