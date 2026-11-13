extends TestCase

## Zorluk eğrisi, engellerin/mekaniklerin üretimi ve seviye hedefi kipleri; 1..120 seviyenin
## üretilip çözücüyle çözülmesi (süreler yazdırılır).

const NEW_KEYS: Array[String] = ["sheet", "sock", "dye"]
const OLD_KEYS: Array[String] = ["wet", "mystery", "lock"]
const RULE_ITEM_KEYS: Array[String] = ["stain", "chain"]
const RULE_LEVEL_KEYS: Array[String] = ["jokers", "big", "wind"]
const LATE_LEVEL: int = 100
const CURVE_LEVELS: int = 120
## 1..15 öğretici seviyeleri: içerik değişmesin (öğretici akışı bunlara bağlı).
const EARLY_LEVELS: int = 15
const EARLY_HASH: String = "298f419f2f3dec287e9e8b04011abfa4"


func _count(level: Dictionary, key: String) -> int:
	var total: int = 0
	for entry: Variant in level["items"] as Array:
		if (entry as Dictionary).has(key):
			total += 1
	return total


func _level_count(level: Dictionary, key: String) -> int:
	if key == "wind":
		return ((level.get("wind", {}) as Dictionary).get("steps", []) as Array).size()
	return (level.get(key, []) as Array).size()


func _find(level: Dictionary, id: int) -> Dictionary:
	for entry: Variant in level["items"] as Array:
		if int((entry as Dictionary)["id"]) == id:
			return entry as Dictionary
	return {}


func test_early_levels_are_byte_identical() -> void:
	var text: String = ""
	for number: int in range(1, EARLY_LEVELS + 1):
		text += JSON.stringify(LevelCache.level(number), "", true)
	assert_eq(text.md5_text(), EARLY_HASH, "1..15 seviyeleri değişmemeli")


func test_obstacle_unlock_levels_are_kept() -> void:
	assert_eq(LevelGenerator.WET_FROM_LEVEL, 8)
	assert_eq(LevelGenerator.MYSTERY_FROM_LEVEL, 14)
	assert_eq(LevelGenerator.LOCK_FROM_LEVEL, 20)
	assert_eq(LevelGenerator.SHEET_FROM_LEVEL, 26)
	assert_eq(LevelGenerator.SOCK_FROM_LEVEL, 32)
	assert_eq(LevelGenerator.DYE_FROM_LEVEL, 40)


func test_each_new_obstacle_is_introduced_alone() -> void:
	var intros: Dictionary = {
		"sheet": LevelGenerator.SHEET_FROM_LEVEL,
		"sock": LevelGenerator.SOCK_FROM_LEVEL,
		"dye": LevelGenerator.DYE_FROM_LEVEL,
	}
	for key: String in intros.keys():
		var number: int = int(intros[key])
		assert_eq(_count(LevelCache.level(number - 1), key), 0, "%s %d'den önce yok" % [key, number])
		var intro: Dictionary = LevelCache.level(number)
		var expected: int = 2 if key == "sock" else 1
		assert_eq(_count(intro, key), expected, "%s tanıtımında tek adet" % key)
		for other: String in NEW_KEYS + OLD_KEYS + RULE_ITEM_KEYS:
			if other != key:
				assert_eq(_count(intro, other), 0, "seviye %d yalnız %s öğretir (%s var)" % [number, key, other])
		for other: String in RULE_LEVEL_KEYS:
			assert_eq(_level_count(intro, other), 0, "seviye %d'de %s yok" % [number, other])
		assert_false(bool(intro["hard"]), "tanıtım seviyesi zor olmaz")


func test_rule_mechanics_are_introduced_alone() -> void:
	var intros: Dictionary = {
		"jokers": LevelGenerator.JOKER_FROM_LEVEL, "big": LevelGenerator.BIG_FROM_LEVEL,
		"stain": LevelGenerator.STAIN_FROM_LEVEL, "chain": LevelGenerator.CHAIN_FROM_LEVEL,
		"wind": LevelGenerator.WIND_FROM_LEVEL,
	}
	for key: String in intros.keys():
		var number: int = int(intros[key])
		var item_key: bool = RULE_ITEM_KEYS.has(key)
		for before: int in range(1, number):
			var earlier: Dictionary = LevelCache.level(before)
			var found: int = _count(earlier, key) if item_key else _level_count(earlier, key)
			assert_eq(found, 0, "%s seviye %d'de (tanıtım %d) olmamalı" % [key, before, number])
		var intro: Dictionary = LevelCache.level(number)
		var count: int = _count(intro, key) if item_key else _level_count(intro, key)
		assert_eq(count, 2 if key == "chain" else 1, "%s tanıtımında tek adet (seviye %d)" % [key, number])
		for other: String in NEW_KEYS + OLD_KEYS + RULE_ITEM_KEYS:
			if other != key:
				assert_eq(_count(intro, other), 0, "seviye %d yalnız %s öğretir (%s var)" % [number, key, other])
		for other: String in RULE_LEVEL_KEYS:
			if other != key:
				assert_eq(_level_count(intro, other), 0, "seviye %d yalnız %s öğretir (%s var)" % [number, key, other])
		assert_false(intro.has("mode"), "tanıtım seviyesinde kip yok")
		assert_false(bool(intro["hard"]), "tanıtım seviyesi zor olmaz")


func test_rule_mechanics_mix_in_later() -> void:
	var seen: Dictionary = {}
	for number: int in range(61, CURVE_LEVELS + 1):
		var level: Dictionary = LevelCache.level(number)
		for key: String in RULE_ITEM_KEYS:
			if _count(level, key) > 0:
				seen[key] = int(seen.get(key, 0)) + 1
		for key: String in RULE_LEVEL_KEYS:
			if _level_count(level, key) > 0:
				seen[key] = int(seen.get(key, 0)) + 1
	for key: String in RULE_ITEM_KEYS + RULE_LEVEL_KEYS:
		assert_greater(int(seen.get(key, 0)), 10, "%s geç seviyelerde karışır (%d)" % [key, int(seen.get(key, 0))])
		assert_true(int(seen.get(key, 0)) < 60, "%s her seviyede değil" % key)


func test_mode_schedule_one_mode_per_level() -> void:
	assert_eq(LevelGenerator.mode_for(LevelGenerator.MOVES_FROM_LEVEL), LaundryBoard.MODE_MOVES)
	assert_eq(LevelGenerator.mode_for(LevelGenerator.SHORT_RACK_FROM_LEVEL), LaundryBoard.MODE_SHORT_RACK)
	assert_eq(LevelGenerator.mode_for(LevelGenerator.ORDERS_FROM_LEVEL), LaundryBoard.MODE_ORDERS)
	for number: int in [30, 45, 60, 75, 90, 105, 120]:
		assert_eq(LevelGenerator.mode_for(number), LaundryBoard.MODE_BOSS, "seviye %d patron" % number)
	var counts: Dictionary = {}
	for number: int in range(1, CURVE_LEVELS + 1):
		var mode: String = LevelGenerator.mode_for(number)
		if number <= EARLY_LEVELS or number in LevelGenerator.INTRO_LEVELS:
			assert_true(mode == LaundryBoard.MODE_NONE, "seviye %d kipsiz olmalı" % number)
		counts[mode] = int(counts.get(mode, 0)) + 1
	for mode: String in [LaundryBoard.MODE_MOVES, LaundryBoard.MODE_SHORT_RACK, LaundryBoard.MODE_ORDERS]:
		assert_greater(int(counts.get(mode, 0)), 4, "%s düzenli gelir" % mode)


func test_mode_levels_carry_their_fields() -> void:
	var moves: Dictionary = LevelCache.level(LevelGenerator.MOVES_FROM_LEVEL)
	var path: Array[int] = LevelCache.path(LevelGenerator.MOVES_FROM_LEVEL)
	assert_eq(String(moves["mode"]), LaundryBoard.MODE_MOVES)
	assert_true(int(moves["move_limit"]) >= path.size(), "sınır çözüm yoluna yeter")
	assert_true(int(moves["move_limit"]) <= path.size() + LevelGenerator.MOVES_SLACK_START)
	var short: Dictionary = LevelCache.level(LevelGenerator.SHORT_RACK_FROM_LEVEL)
	assert_true(int(short["rack_slots"]) == 2 or int(short["rack_slots"]) == 3, "kısa askı 2-3 slot")
	var orders: Dictionary = LevelCache.level(LevelGenerator.ORDERS_FROM_LEVEL)
	assert_eq((orders["orders"] as Array).size(), LevelGenerator.ORDER_COUNT)
	var strict: Dictionary = orders.duplicate()
	strict["orders_strict"] = true
	assert_true(LevelSolver.is_solvable(strict, LevelCache.SOLVE_LIMIT), "sipariş en iyi oyunla yapılabilir")


func test_boss_is_two_screens_and_bigger() -> void:
	for number: int in [30, 60, 90, 120]:
		var boss: Dictionary = LevelCache.level(number)
		assert_eq(String(boss["mode"]), LaundryBoard.MODE_BOSS)
		var second: int = 0
		for entry: Variant in boss["items"] as Array:
			if int((entry as Dictionary).get("screen", 0)) == 1:
				second += 1
		var total: int = (boss["items"] as Array).size()
		assert_greater(second, total / 4, "seviye %d ikinci ekran dolu" % number)
		var normal: int = (LevelCache.level(number + 1)["items"] as Array).size()
		assert_greater(float(total), float(normal) * 1.3, "seviye %d patron daha büyük (%d / %d)" % [number, total, normal])
		var board: LaundryBoard = LaundryBoard.new(boss)
		assert_eq(board.screen_count(), 2)


func test_sheet_covers_many_and_is_on_top() -> void:
	var level: Dictionary = LevelCache.level(LevelGenerator.SHEET_FROM_LEVEL)
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
		var level: Dictionary = LevelCache.level(number)
		for entry: Variant in level["items"] as Array:
			var sock: Dictionary = entry as Dictionary
			if not sock.has("sock"):
				continue
			var partner: Dictionary = _find(level, int(sock["sock"]))
			assert_eq(int(partner.get("sock", -1)), int(sock["id"]), "çift karşılıklı")
			assert_eq(int(partner["color"]), int(sock["color"]), "çift aynı renk")
			assert_eq(int(sock["kind"]), LevelGenerator.SOCK_KIND)


func test_chains_are_mutual_neighbours() -> void:
	for number: int in range(LevelGenerator.CHAIN_FROM_LEVEL, CURVE_LEVELS + 1):
		var level: Dictionary = LevelCache.level(number)
		for entry: Variant in level["items"] as Array:
			var chained: Dictionary = entry as Dictionary
			if not chained.has("chain"):
				continue
			var partner: Dictionary = _find(level, int(chained["chain"]))
			assert_eq(int(partner.get("chain", -1)), int(chained["id"]), "zincir karşılıklı")
			assert_eq(int(partner["line"]), int(chained["line"]), "aynı ip")
			assert_almost_eq(absf(float(partner["slot"]) - float(chained["slot"])), 1.0)


func test_dye_target_is_directly_beneath_and_differs() -> void:
	var level: Dictionary = LevelCache.level(LevelGenerator.DYE_FROM_LEVEL)
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
	var early: Dictionary = LevelGenerator.params_for(31)
	var late: Dictionary = LevelGenerator.params_for(LATE_LEVEL - 1)
	assert_greater(int(late["twist"]), int(early["twist"]))
	assert_greater(int(late["colors"]), int(early["colors"]))
	assert_eq(int(late["colors"]), LevelGenerator.MAX_COLORS)
	assert_greater(int(late["columns"]), int(early["columns"]))
	for number: int in range(1, CURVE_LEVELS + 1):
		var params: Dictionary = LevelGenerator.params_for(number)
		assert_true(int(params["colors"]) <= LevelGenerator.MAX_COLORS)
		assert_true(int(params["layers"]) <= LevelGenerator.MAX_LAYERS)


func test_boss_replaces_very_hard_every_fifteenth() -> void:
	for number: int in [30, 45, 60, 75, 90]:
		var params: Dictionary = LevelGenerator.params_for(number)
		assert_true(bool(params["boss"]), "seviye %d patron" % number)
		assert_false(bool(params["very_hard"]), "çok zorun yerini patron alır")
		assert_true(bool(params["hard"]))
	assert_false(bool(LevelGenerator.params_for(35).get("boss", false)))


## 1..120: hepsi üretilir, düğüm bütçesi içinde çözülür, yol oynanınca kazanır; hamle sınırlı
## seviyelerde yol sınıra sığar. Süreler yazdırılır (performans aşaması için).
func test_levels_1_to_120_are_solvable_within_budget() -> void:
	var total_gen: int = 0
	var total_solve: int = 0
	var slowest: int = 0
	var slowest_level: int = 0
	for number: int in range(1, CURVE_LEVELS + 1):
		var data: Dictionary = LevelCache.level(number)
		var path: Array[int] = LevelCache.path(number)
		assert_false(path.is_empty(), "seviye %d çözülebilir" % number)
		var board: LaundryBoard = LaundryBoard.new(data)
		for id: int in path:
			board.tap(id)
		assert_true(board.is_won(), "seviye %d: yol kazandırır" % number)
		var generated: int = int(LevelCache.gen_usec.get(number, 0))
		total_gen += generated
		total_solve += int(LevelCache.solve_usec.get(number, 0))
		if generated > slowest:
			slowest = generated
			slowest_level = number
	print("        süre 1..%d: üretim %d ms, çözüm %d ms, en yavaş üretim seviye %d (%d ms)" % [
		CURVE_LEVELS, total_gen / 1000, total_solve / 1000, slowest_level, slowest / 1000])
