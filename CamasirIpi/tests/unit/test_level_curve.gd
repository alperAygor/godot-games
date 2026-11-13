extends TestCase

## Zorluk eğrisi ve yeni engellerin üretimi (çarşaf, çorap, boya).

const NEW_KEYS: Array[String] = ["sheet", "sock", "dye"]
const OLD_KEYS: Array[String] = ["wet", "mystery", "lock"]
const LATE_LEVEL: int = 100


func _count(level: Dictionary, key: String) -> int:
	var total: int = 0
	for entry: Variant in level["items"] as Array:
		if (entry as Dictionary).has(key):
			total += 1
	return total


func _find(level: Dictionary, id: int) -> Dictionary:
	for entry: Variant in level["items"] as Array:
		if int((entry as Dictionary)["id"]) == id:
			return entry as Dictionary
	return {}


func test_each_new_obstacle_is_introduced_alone() -> void:
	var intros: Dictionary = {
		"sheet": LevelGenerator.SHEET_FROM_LEVEL,
		"sock": LevelGenerator.SOCK_FROM_LEVEL,
		"dye": LevelGenerator.DYE_FROM_LEVEL,
	}
	for key: String in intros.keys():
		var number: int = int(intros[key])
		assert_eq(_count(LevelGenerator.generate(number - 1), key), 0, "%s %d'den önce yok" % [key, number])
		var intro: Dictionary = LevelGenerator.generate(number)
		var expected: int = 2 if key == "sock" else 1
		assert_eq(_count(intro, key), expected, "%s tanıtımında tek adet" % key)
		for other: String in NEW_KEYS + OLD_KEYS:
			if other != key:
				assert_eq(_count(intro, other), 0, "seviye %d yalnız %s öğretir (%s var)" % [number, key, other])
		assert_false(bool(intro["hard"]), "tanıtım seviyesi zor olmaz")


func test_new_obstacles_mix_in_later() -> void:
	var late: Dictionary = LevelGenerator.generate(LATE_LEVEL - 1)
	assert_greater(_count(late, "sheet"), 0)
	assert_greater(_count(late, "sock"), 2)
	assert_greater(_count(late, "wet"), 0)


func test_sheet_covers_many_and_is_on_top() -> void:
	var level: Dictionary = LevelGenerator.generate(LevelGenerator.SHEET_FROM_LEVEL)
	for entry: Variant in level["items"] as Array:
		var sheet: Dictionary = entry as Dictionary
		if not sheet.has("sheet"):
			continue
		assert_true((sheet["blockers"] as Array).is_empty(), "çarşafın üstü boş")
		var covered: int = 0
		for other: Variant in level["items"] as Array:
			if ((other as Dictionary)["blockers"] as Array).has(int(sheet["id"])):
				covered += 1
		assert_true(covered >= LevelGenerator.SHEET_MIN_COVER, "çarşaf çok parçayı kapatır (%d)" % covered)


func test_socks_are_mutual_same_colour_pairs() -> void:
	for number: int in [LevelGenerator.SOCK_FROM_LEVEL, 60]:
		var level: Dictionary = LevelGenerator.generate(number)
		for entry: Variant in level["items"] as Array:
			var sock: Dictionary = entry as Dictionary
			if not sock.has("sock"):
				continue
			var partner: Dictionary = _find(level, int(sock["sock"]))
			assert_eq(int(partner.get("sock", -1)), int(sock["id"]), "çift karşılıklı")
			assert_eq(int(partner["color"]), int(sock["color"]), "çift aynı renk")
			assert_eq(int(sock["kind"]), LevelGenerator.SOCK_KIND)


func test_dye_target_is_directly_beneath_and_differs() -> void:
	var level: Dictionary = LevelGenerator.generate(LevelGenerator.DYE_FROM_LEVEL)
	for entry: Variant in level["items"] as Array:
		var dye: Dictionary = entry as Dictionary
		if not dye.has("dye"):
			continue
		assert_eq(int(dye["dye"]), LaundryBoard.DEFAULT_DYE_MOVES)
		assert_true((dye["blockers"] as Array).is_empty(), "boyalı başta açıktır")
		var target: Dictionary = _find(level, int(dye["dye_target"]))
		assert_true((target["blockers"] as Array).has(int(dye["id"])), "hedef boyalının altında")
		assert_true(int(target["color"]) != int(dye["color"]))


func test_curve_keeps_growing() -> void:
	var early: Dictionary = LevelGenerator.params_for(30)
	var late: Dictionary = LevelGenerator.params_for(LATE_LEVEL - 1)
	assert_greater(int(late["twist"]), int(early["twist"]))
	assert_greater(int(late["colors"]), int(early["colors"]))
	assert_eq(int(late["colors"]), LevelGenerator.MAX_COLORS)
	assert_greater(int(late["columns"]), int(early["columns"]))
	for number: int in range(1, LATE_LEVEL + 1):
		var params: Dictionary = LevelGenerator.params_for(number)
		assert_true(int(params["colors"]) <= LevelGenerator.MAX_COLORS)
		assert_true(int(params["layers"]) <= LevelGenerator.MAX_LAYERS)


func test_very_hard_every_fifteenth() -> void:
	for number: int in [30, 45, 60, 75, 90]:
		var params: Dictionary = LevelGenerator.params_for(number)
		assert_true(bool(params["very_hard"]), "seviye %d çok zor" % number)
		assert_true(bool(params["hard"]))
		var normal: Dictionary = LevelGenerator.params_for(number - 5)
		assert_greater(int(params["twist"]), int(normal["twist"]))
	assert_false(bool(LevelGenerator.params_for(35).get("very_hard", false)))


func test_late_levels_are_solvable() -> void:
	# 1..80 genel testte; burada eğrinin uzak ucundan örnekler (5 sütun, en yoğun engel).
	for number: int in [85, 90, 95, LATE_LEVEL]:
		var data: Dictionary = LevelGenerator.generate(number)
		var path: Array[int] = LevelSolver.solve(data, 200000)
		assert_false(path.is_empty(), "seviye %d çözülebilir" % number)
