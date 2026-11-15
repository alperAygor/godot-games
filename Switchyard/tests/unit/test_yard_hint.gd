extends TestCase

## YardHint: çözüm yolunda kalan eylem; yoldan sapınca arama; arama yetmezse geri sarma noktası.


func _level(lid: String) -> YardLevel:
	return YardLevel.from_dict(LevelCatalog.load_level(lid))


func test_on_path_returns_stored_solution() -> void:
	var lv: YardLevel = _level("w1-010")
	var st: YardState = YardRules.initial_state(lv)
	var sol: Array[Dictionary] = lv.solution()
	var history: Array[Dictionary] = []
	for i: int in sol.size():
		var h: Dictionary = YardHint.next_action(lv, st, history)
		assert_eq(JSON.stringify(h), JSON.stringify(sol[i]), "adım %d kayıtlı çözüm" % i)
		YardRules.apply_action(lv, st, sol[i])
		history.append(sol[i])
	assert_true(YardRules.is_solved(lv, st))
	assert_eq(YardHint.next_action(lv, st, history).size(), 0, "çözülünce boş")


func test_mid_drive_gives_remainder() -> void:
	var lv: YardLevel = _level("w1-010")
	var sol: Array[Dictionary] = lv.solution()
	var first: Dictionary = sol[0]
	if int(first["steps"]) < 2:
		return
	var st: YardState = YardRules.initial_state(lv)
	var one: Dictionary = {"t": "drive", "side": first["side"], "steps": 1,
		"branches": (first["branches"] as Array).slice(0, 1) if YardRules.probe(lv, st, YardRules.side_from_name(str(first["side"]))).needs_branch else []}
	assert_true(YardRules.apply_action(lv, st, one))
	var h: Dictionary = YardHint.next_action(lv, st, [one] as Array[Dictionary])
	assert_eq(str(h["t"]), "drive")
	assert_eq(int(h["steps"]), int(first["steps"]) - 1, "sürüşün kalanı")


func test_off_path_hints_lead_to_solution() -> void:
	for lid: String in ["w1-008", "w1-012"]:
		var lv: YardLevel = _level(lid)
		var st: YardState = YardRules.initial_state(lv)
		var history: Array[Dictionary] = []
		# Bilerek sap: ilk çözüm eyleminin tersi yönde bir adım (mümkünse).
		var first_side: int = YardRules.side_from_name(str(lv.solution()[0]["side"]))
		var wrong: Dictionary = {"t": "drive", "side": "a" if first_side == YardRules.SIDE_B else "b", "steps": 1, "branches": []}
		if YardRules.apply_action(lv, st, wrong):
			history.append(wrong)
		var guard: int = 0
		while not YardRules.is_solved(lv, st) and guard < 80:
			guard += 1
			var h: Dictionary = YardHint.next_action(lv, st, history)
			assert_true(h.has("t"), "ipucu eylem döndürmeli")
			if str(h.get("t", "")) == "rewind":
				fail("%s: arama bulmalıydı" % lid)
				break
			assert_true(YardRules.apply_action(lv, st, h), "%s: ipucu uygulanabilir olmalı" % lid)
			history.append(h)
		assert_true(YardRules.is_solved(lv, st), "%s: ipuçlarını izleyen çözer" % lid)


func test_rewind_point_is_last_on_path_moment() -> void:
	var lv: YardLevel = _level("w1-012")
	var sol: Array[Dictionary] = lv.solution()
	var path: Dictionary = YardHint._solution_path(lv)
	var st: YardState = YardRules.initial_state(lv)
	var history: Array[Dictionary] = [sol[0], sol[1]]
	# Çözüm yolunda iki eylem, sonra yoldan çıkan bir eylem.
	YardRules.apply_action(lv, st, sol[0])
	YardRules.apply_action(lv, st, sol[1])
	var side: int = YardRules.side_from_name(str(sol[2]["side"])) if str(sol[2]["t"]) == "drive" else 0
	var wrong: Dictionary = {"t": "drive", "side": "a" if side == YardRules.SIDE_B else "b", "steps": 1, "branches": []}
	if YardRules.apply_action(lv, st, wrong):
		history.append(wrong)
		assert_eq(YardHint._last_on_path(lv, history, path), 2, "yoldaki son an")
	assert_eq(YardHint._last_on_path(lv, [] as Array[Dictionary], path), 0)
