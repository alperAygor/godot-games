extends TestCase

## Günlük görevler: deterministik çekim, hedef ölçekleme, olay işleme, ödül alma, gün geçişi.

const DAY: String = "2026-11-13"


func _cfg() -> Dictionary:
	return RetentionData.missions()


func _live() -> Dictionary:
	var live: Dictionary = {}
	for id: Variant in _cfg()["core_events"] as Array:
		live[String(id)] = true
	return live


func test_draw_is_deterministic_and_has_three_distinct_groups() -> void:
	var first: Array[Dictionary] = Missions.draw(DAY, 12, _cfg(), _live())
	var second: Array[Dictionary] = Missions.draw(DAY, 12, _cfg(), _live())
	assert_eq(first, second, "aynı gün aynı görevler")
	assert_eq(first.size(), 3, "üç görev")
	var groups: Array[String] = []
	for item: Dictionary in first:
		var group: String = String(Missions.definition(_cfg(), String(item["id"])).get("group", ""))
		assert_false(groups.has(group), "aynı gruptan iki görev yok")
		groups.append(group)


func test_days_differ_over_a_week() -> void:
	var seen: Dictionary = {}
	for offset: int in range(7):
		var items: Array[Dictionary] = Missions.draw(DailyDate.add_days(DAY, offset), 12, _cfg(), _live())
		var ids: Array[String] = []
		for item: Dictionary in items:
			ids.append(String(item["id"]))
		seen[",".join(ids)] = true
	assert_greater(float(seen.size()), 2.0, "günler birbirine benzemez")


func test_optional_missions_need_a_live_event() -> void:
	for offset: int in range(40):
		for item: Dictionary in Missions.draw(DailyDate.add_days(DAY, offset), 12, _cfg(), _live()):
			assert_false(String(item["id"]) == "bird" or String(item["id"]) == "cat", "ölü olay görevi çekilmez")
	var live: Dictionary = _live()
	live["bird_shooed"] = true
	var found: bool = false
	for offset: int in range(60):
		for item: Dictionary in Missions.draw(DailyDate.add_days(DAY, offset), 12, _cfg(), live):
			found = found or String(item["id"]) == "bird"
	assert_true(found, "olay canlıysa kuş görevi çekilebilir")


func test_target_scales_mildly_with_level_and_respects_cap() -> void:
	var def: Dictionary = Missions.definition(_cfg(), "levels")
	assert_eq(Missions.target_for(def, 5, _cfg()), 2, "5. seviyede taban")
	assert_eq(Missions.target_for(def, 25, _cfg()), 4, "25. seviyede +2")
	assert_eq(Missions.target_for(def, 900, _cfg()), 5, "tavan")


func test_event_progress_modes_and_where() -> void:
	var state: Dictionary = {"day": DAY, "items": [
		{"id": "baskets", "target": 3, "progress": 0, "claimed": false, "reward": {"coins": 20}},
		{"id": "chain", "target": 3, "progress": 0, "claimed": false, "reward": {"coins": 30}},
		{"id": "stars3", "target": 1, "progress": 0, "claimed": false, "reward": {"coins": 30}},
	], "chest": false}
	var result: Dictionary = Missions.apply_event(state, "basket_completed", 1, {"chain": 2, "count": 3}, _cfg())
	assert_true(bool(result["changed"]), "değişti")
	var items: Array[Dictionary] = Missions.items(result["state"] as Dictionary)
	assert_eq(int(items[0]["progress"]), 1, "sum")
	assert_eq(int(items[1]["progress"]), 2, "max zincir")
	result = Missions.apply_event(result["state"] as Dictionary, "basket_completed", 1, {"chain": 1}, _cfg())
	assert_eq(int(Missions.items(result["state"] as Dictionary)[1]["progress"]), 2, "max geri gitmez")
	result = Missions.apply_event(result["state"] as Dictionary, "level_won", 1, {"stars": 2}, _cfg())
	assert_eq(int(Missions.items(result["state"] as Dictionary)[2]["progress"]), 0, "2 yıldız 3 yıldız görevine sayılmaz")
	result = Missions.apply_event(result["state"] as Dictionary, "level_won", 1, {"stars": 3}, _cfg())
	assert_true(Missions.is_done(Missions.items(result["state"] as Dictionary)[2]), "3 yıldız sayılır")


func test_unknown_event_never_completes_anything() -> void:
	var state: Dictionary = Missions.new_state(DAY, 12, _cfg(), _live())
	var result: Dictionary = Missions.apply_event(state, "alien_landed", 5, {}, _cfg())
	assert_false(bool(result["changed"]), "tanınmayan olay hiçbir şeyi değiştirmez")


func test_claim_and_chest_flow() -> void:
	var state: Dictionary = {"day": DAY, "items": [
		{"id": "levels", "target": 1, "progress": 1, "claimed": false, "reward": {"coins": 20}},
		{"id": "daily", "target": 1, "progress": 1, "claimed": false, "reward": {"coins": 30}},
		{"id": "booster", "target": 1, "progress": 0, "claimed": false, "reward": {"coins": 20}},
	], "chest": false}
	assert_eq(Missions.claimable_count(state), 2, "iki görev alınabilir")
	var claimed: Dictionary = Missions.claim(state, 0)
	assert_true(bool(claimed["ok"]), "alındı")
	assert_false(bool(Missions.claim(claimed["state"] as Dictionary, 0)["ok"]), "çift alma reddedilir")
	assert_false(bool(Missions.claim(state, 2)["ok"]), "bitmemiş görev alınamaz")
	assert_false(Missions.chest_ready(state), "sandık hazır değil")
	var finished: Dictionary = Missions.apply_event(state, "booster_used", 1, {}, _cfg())
	assert_true(Missions.chest_ready(finished["state"] as Dictionary), "üçü bitince sandık hazır")
	var chest: Dictionary = Missions.claim_chest(finished["state"] as Dictionary, _cfg())
	assert_true(bool(chest["ok"]), "sandık alındı")
	assert_false(bool(Missions.claim_chest(chest["state"] as Dictionary, _cfg())["ok"]), "sandık bir kez")


func test_rollover_carries_completed_unclaimed_rewards() -> void:
	var state: Dictionary = {"day": DAY, "items": [
		{"id": "levels", "target": 1, "progress": 1, "claimed": false, "reward": {"coins": 20}},
		{"id": "daily", "target": 1, "progress": 0, "claimed": false, "reward": {"coins": 30}},
	], "chest": false}
	var same: Dictionary = Missions.sync(state, DAY, 12, _cfg(), _live())
	assert_false(bool(same["rolled"]), "aynı gün yeniden kurulmaz")
	var next: Dictionary = Missions.sync(state, DailyDate.add_days(DAY, 1), 12, _cfg(), _live())
	assert_true(bool(next["rolled"]), "gün geçti")
	assert_eq((next["carry"] as Array).size(), 1, "yalnız tamamlanmış ödül taşınır")
	assert_eq(Missions.items(next["state"] as Dictionary).size(), 3, "yeni üç görev")
	assert_eq(String((next["state"] as Dictionary)["day"]), DailyDate.add_days(DAY, 1), "yeni gün")


func test_progress_survives_json_roundtrip() -> void:
	var state: Dictionary = Missions.new_state(DAY, 12, _cfg(), _live())
	var again: Variant = JSON.parse_string(JSON.stringify(state))
	assert_true(again is Dictionary, "JSON geçti")
	var result: Dictionary = Missions.apply_event(again as Dictionary, "level_won", 1, {"stars": 3, "rack_total": 0}, _cfg())
	assert_true(Missions.items(result["state"] as Dictionary).size() == 3, "float'a dönen sayılar bozmaz")
