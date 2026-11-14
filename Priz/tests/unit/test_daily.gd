extends TestCase
## Günün dairesi: aynı tarih → aynı seviye; saf fonksiyon.

var content: PrizContent


func before_each() -> void:
	if content == null:
		content = PrizContent.load_default()


func test_day_index_reference_values() -> void:
	assert_eq(PrizDaily.day_index(1970, 1, 1), 0)
	assert_eq(PrizDaily.day_index(1969, 12, 31), -1)
	assert_eq(PrizDaily.day_index(2000, 3, 1), 11017)
	assert_eq(PrizDaily.day_index(2024, 2, 29), 19782)
	assert_eq(PrizDaily.day_index(2026, 11, 14), 20771)


func test_same_date_same_level() -> void:
	var a: PrizLevel = PrizDaily.generate(2026, 11, 14, content)
	var b: PrizLevel = PrizDaily.generate(2026, 11, 14, PrizContent.load_default())
	assert_not_null(a)
	assert_true(a.to_json() == b.to_json())
	assert_eq(a.id, "daily_2026-11-14")
	var c: PrizLevel = PrizDaily.generate(2026, 11, 15, content)
	assert_false(a.to_json() == c.to_json())


func test_two_months_of_dailies_are_valid() -> void:
	var solver: PrizSolver = PrizSolver.new()
	var start: int = PrizDaily.day_index(2026, 11, 1)
	var seen: Dictionary = {}
	for i: int in 60:
		var index: int = start + i
		var v: int = PrizDaily.virtual_level(index)
		assert_true(v >= PrizDaily.MIN_VIRTUAL and v <= PrizDaily.MAX_VIRTUAL)
		assert_false(PrizCurve.is_hard_level(v), "günlük seviye zor değil")
		seen[v] = true
	assert_true(seen.size() > 10, "zorluk çeşitlenir")
	# Bir haftayı tam üretip doğrula.
	for day: int in range(1, 8):
		var level: PrizLevel = PrizDaily.generate(2026, 12, day, content)
		assert_not_null(level)
		if level == null:
			continue
		assert_eq(level.mode, PrizLevel.MODE_DAY)
		var res: PrizSolveResult = solver.count_solutions(level, content.registry, level.band_max + 1)
		assert_true(res.count >= level.band_min and res.count <= level.band_max)
