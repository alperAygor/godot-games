extends TestCase

## Kilometre taşı yolu: liste, sonsuz uzama, ulaşma, alma, pencere ve ilerleme oranı.


func _cfg() -> Dictionary:
	return RetentionData.milestones()


func test_list_and_repeat_rule() -> void:
	var entries: Array[Dictionary] = Milestones.entries_through(_cfg(), 100)
	var levels: Array[int] = []
	for entry: Dictionary in entries:
		levels.append(int(entry["level"]))
	assert_eq(levels.slice(0, 7), [5, 10, 15, 20, 30, 40, 50] as Array[int], "veri listesi")
	assert_eq(levels.slice(7), [60, 70, 80, 90, 100] as Array[int], "her 10 seviyede tekrar")
	assert_greater(float(int(Milestones.reward_for(_cfg(), 100)["coins"])), float(int(Milestones.reward_for(_cfg(), 60)["coins"])), "100. büyük sandık")


func test_reached_and_claimable() -> void:
	assert_eq(Milestones.claimable({}, 5, _cfg()).size(), 0, "5. seviyedeyken (4 bitti) yok")
	assert_eq(Milestones.claimable({}, 6, _cfg()), [5] as Array[int], "5 seviye bitti")
	assert_eq(Milestones.claimable({}, 11, _cfg()), [5, 10] as Array[int], "iki sandık bekliyor")
	assert_eq(Milestones.claimable({"claimed": [5.0]}, 11, _cfg()), [10] as Array[int], "float kayıt okunur")


func test_claim_rules() -> void:
	assert_false(bool(Milestones.claim({}, 5, 5, _cfg())["ok"]), "ulaşılmadan alınamaz")
	var first: Dictionary = Milestones.claim({}, 5, 6, _cfg())
	assert_true(bool(first["ok"]), "ulaşınca alınır")
	assert_false(bool(Milestones.claim(first["state"] as Dictionary, 5, 6, _cfg())["ok"]), "çift alma yok")
	assert_false(bool(Milestones.claim({}, 7, 20, _cfg())["ok"]), "olmayan kilometre taşı")


func test_levels_to_go_and_fraction() -> void:
	assert_eq(Milestones.levels_to_go(1, _cfg()), 5, "baştan 5")
	assert_eq(Milestones.levels_to_go(4, _cfg()), 2, "3 bitti, 5'e 2")
	assert_eq(Milestones.levels_to_go(6, _cfg()), 5, "5 bitti, 10'a 5")
	assert_almost_eq(Milestones.progress_fraction(1, _cfg()), 0.0, 0.001, "başta 0")
	assert_almost_eq(Milestones.progress_fraction(8, _cfg()), 0.4, 0.001, "7 bitti: 5->10 arası 2/5")


func test_window_marks_status() -> void:
	var window: Array[Dictionary] = Milestones.window({"claimed": [5]}, 11, _cfg(), 5)
	assert_eq(window.size(), 5, "5 düğüm")
	assert_eq(int(window[0]["level"]), 5, "bağlam: alınmış bir önceki")
	assert_eq(int(window[0]["status"]), Milestones.STATUS_CLAIMED, "alınmış")
	assert_eq(int(window[1]["status"]), Milestones.STATUS_CLAIMABLE, "10 alınabilir")
	assert_eq(int(window[2]["status"]), Milestones.STATUS_NEXT, "15 sıradaki")
	assert_eq(int(window[3]["status"]), Milestones.STATUS_LOCKED, "20 kilitli")
