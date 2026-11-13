extends TestCase

## Haftalık etkinlik: hafta matematiği (Pazartesi başlangıcı), tema döngüsü, kademeler, devir.

const MONDAY: String = "2026-11-09"
const FRIDAY: String = "2026-11-13"
const SUNDAY: String = "2026-11-15"


func _cfg() -> Dictionary:
	return RetentionData.weekly()


func test_week_math_is_monday_based() -> void:
	assert_eq(WeeklyEvent.weekday(MONDAY), 0, "Pazartesi")
	assert_eq(WeeklyEvent.weekday(FRIDAY), 4, "Cuma")
	assert_eq(WeeklyEvent.weekday(SUNDAY), 6, "Pazar")
	assert_eq(WeeklyEvent.week_start(SUNDAY), MONDAY, "Pazar aynı haftanın başına döner")
	assert_eq(WeeklyEvent.week_start("2026-11-16"), "2026-11-16", "sonraki Pazartesi yeni hafta")
	assert_eq(WeeklyEvent.days_left(MONDAY), 7, "Pazartesi 7 gün")
	assert_eq(WeeklyEvent.days_left(SUNDAY), 1, "Pazar son gün")


func test_theme_is_stable_within_week_and_cycles() -> void:
	var a: Dictionary = WeeklyEvent.theme_for(MONDAY, _cfg())
	assert_eq(String(WeeklyEvent.theme_for(WeeklyEvent.week_start(SUNDAY), _cfg())["id"]), String(a["id"]), "hafta içinde aynı")
	var seen: Dictionary = {}
	for week: int in range(WeeklyEvent.themes(_cfg()).size()):
		seen[String(WeeklyEvent.theme_for(DailyDate.add_days(MONDAY, week * 7), _cfg())["id"])] = true
	assert_eq(seen.size(), WeeklyEvent.themes(_cfg()).size(), "tüm temalar sırayla gelir")


func _blue_state() -> Dictionary:
	var state: Dictionary = WeeklyEvent.new_state(MONDAY, _cfg())
	state["theme"] = "blue"
	return state


func test_colour_theme_counts_garments_of_that_colour() -> void:
	var state: Dictionary = _blue_state()
	var hit: Dictionary = WeeklyEvent.apply_event(state, "basket_completed", 1, {"color": 1, "count": 3}, _cfg())
	assert_eq(WeeklyEvent.progress(hit["state"] as Dictionary), 3, "mavi sepet 3 çamaşır")
	var miss: Dictionary = WeeklyEvent.apply_event(state, "basket_completed", 1, {"color": 0, "count": 3}, _cfg())
	assert_false(bool(miss["changed"]), "kırmızı mavi haftaya sayılmaz")
	var other: Dictionary = WeeklyEvent.apply_event(state, "level_won", 1, {"stars": 3}, _cfg())
	assert_false(bool(other["changed"]), "başka olay sayılmaz")


func test_chain_theme_counts_links_only() -> void:
	var state: Dictionary = WeeklyEvent.new_state(MONDAY, _cfg())
	state["theme"] = "chain"
	assert_false(bool(WeeklyEvent.apply_event(state, "basket_completed", 1, {"chain": 1}, _cfg())["changed"]), "tek sepet zincir değil")
	assert_true(bool(WeeklyEvent.apply_event(state, "basket_completed", 1, {"chain": 3}, _cfg())["changed"]), "zincir halkası sayılır")


func test_tiers_claim_and_double_claim() -> void:
	var state: Dictionary = _blue_state()
	state["progress"] = 31
	var theme: Dictionary = WeeklyEvent.theme_by_id(_cfg(), "blue")
	assert_eq(WeeklyEvent.claimable_tiers(state, theme), [0, 1] as Array[int], "iki kademe hazır")
	var first: Dictionary = WeeklyEvent.claim(state, 0, _cfg())
	assert_true(bool(first["ok"]), "alındı")
	assert_false(bool(WeeklyEvent.claim(first["state"] as Dictionary, 0, _cfg())["ok"]), "çift alma yok")
	assert_false(bool(WeeklyEvent.claim(state, 2, _cfg())["ok"]), "ulaşılmamış kademe alınamaz")


func test_rollover_resets_and_carries_unclaimed() -> void:
	var state: Dictionary = _blue_state()
	state["progress"] = 60
	state["claimed"] = [1, 0, 0, 0, 0]
	var same: Dictionary = WeeklyEvent.sync(state, SUNDAY, _cfg())
	assert_false(bool(same["rolled"]), "hafta içinde sıfırlanmaz")
	var next: Dictionary = WeeklyEvent.sync(state, "2026-11-16", _cfg())
	assert_true(bool(next["rolled"]), "hafta döndü")
	assert_eq((next["carry"] as Array).size(), 2, "2. ve 3. kademe otomatik verilir")
	assert_eq(WeeklyEvent.progress(next["state"] as Dictionary), 0, "ilerleme sıfırlandı")
	assert_eq(String((next["state"] as Dictionary)["week"]), "2026-11-16", "yeni hafta anahtarı")
