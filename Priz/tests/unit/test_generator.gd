extends TestCase
## Üretici: belirlenimcilik, zorluk eğrisi, öğe açılışları, 61-100 örneklemi, yozlaşma denetimi.

var content: PrizContent


func before_each() -> void:
	if content == null:
		content = PrizContent.load_default()


func test_same_seed_byte_identical() -> void:
	for level_seed: int in [1, 42, 777, 99991, 2147480000]:
		for n: int in [2, 9, 17, 36, 52, 88]:
			var a: PrizLevel = PrizGenerator.new(content).generate(n, level_seed)
			var b: PrizLevel = PrizGenerator.new(PrizContent.load_default()).generate(n, level_seed)
			assert_not_null(a)
			if a != null and b != null:
				assert_true(a.to_json() == b.to_json(), "tohum %d seviye %d" % [level_seed, n])


func test_different_seeds_differ() -> void:
	var gen: PrizGenerator = PrizGenerator.new(content)
	assert_false(gen.generate(30, 1).to_json() == gen.generate(30, 2).to_json())


func test_shipped_levels_regenerate_identically() -> void:
	var gen: PrizGenerator = PrizGenerator.new(content)
	for path: String in PrizLevel.shipped_files():
		var shipped: String = FileAccess.get_file_as_string(path)
		var level: PrizLevel = PrizLevel.from_json(shipped)
		var regen: PrizLevel = gen.generate(level.number)
		assert_not_null(regen, path)
		if regen != null:
			assert_true(regen.to_json() == shipped, "yeniden üretim farklı: %s" % path)


func test_levels_61_to_100_generate_and_solve() -> void:
	var gen: PrizGenerator = PrizGenerator.new(content)
	var solver: PrizSolver = PrizSolver.new()
	for n: int in range(61, 101):
		var level: PrizLevel = gen.generate(n)
		assert_not_null(level, "seviye %d" % n)
		if level == null:
			continue
		assert_true(level.validate(content.registry).is_empty(), "seviye %d doğrulama" % n)
		var res: PrizSolveResult = solver.count_solutions(level, content.registry, level.band_max + 1)
		assert_false(res.node_limit_hit, "seviye %d düğüm sınırı" % n)
		assert_true(res.count >= level.band_min and res.count <= level.band_max,
				"seviye %d çözüm %d" % [n, res.count])
		assert_eq(level.difficulty == PrizLevel.DIFF_HARD, n % 5 == 0, "seviye %d etiket" % n)


func test_late_element_intros_have_their_element() -> void:
	var gen: PrizGenerator = PrizGenerator.new(content)
	for pair: Array in [[65, "neighbour_line"], [80, "timer_socket"], [95, "line_off"]]:
		var level: PrizLevel = gen.generate(int(pair[0]))
		assert_true(level.elements.has(str(pair[1])), str(pair))
		var count: int = 0
		for e: String in level.elements:
			if content.registry.get_element(e).unlock_level == int(pair[0]):
				count += 1
		assert_eq(count, 1, "tanıtım seviyesinde tek yeni öğe")


func test_no_element_before_unlock_and_flat_day_split() -> void:
	var gen: PrizGenerator = PrizGenerator.new(content)
	for n: int in range(1, 101, 3):
		var ids: Array[String] = gen.choose_elements(n, PrizGenerator.default_seed(n))
		for e: String in ids:
			assert_true(content.registry.get_element(e).unlock_level <= n, "%d: %s" % [n, e])
		assert_eq(ids.has("day_cycle"), n >= 15)
		assert_eq(ids.has("room_restriction"), n >= 6)


func test_curve_sizes_and_hard_every_fifth() -> void:
	for n: int in range(1, 101):
		var c: PrizCurve = PrizCurve.for_level(n, false)
		assert_true(c.lines >= 2 and c.lines <= 4, "hat %d" % n)
		assert_eq(c.difficulty == PrizLevel.DIFF_HARD, n % 5 == 0)
		if n > 7 and n % 5 != 0 and (n - 7) % 5 != 0:
			assert_true(c.devices >= PrizCurve.for_level(n - 7, false).devices,
					"cihaz sayısı büyür %d" % n)
	assert_true(PrizCurve.for_level(60, false).devices > PrizCurve.for_level(4, false).devices)


## İlk üç seviye: yazı okumayan biri de geçer. Her cihazı (tepsideki sırayla) kabul eden
## ilk ya da son prize takan "düşünmeyen" oyuncu da kazanır.
func test_first_three_levels_near_trivial() -> void:
	for n: int in [1, 2, 3]:
		var level: PrizLevel = PrizLevel.load_shipped(n)
		for from_end: bool in [false, true]:
			var board: PrizBoard = PrizBoard.new(level, content.registry)
			for device: PrizDevice in level.devices:
				var accepting: Array[String] = board.sockets_accepting(device.id)
				if accepting.is_empty():
					break
				board.plug(device.id, accepting.back() if from_end else accepting.front())
			assert_true(board.is_won(), "seviye %d (%s)" % [n, "sondan" if from_end else "baştan"])


## Yozlaşma: seviye 4'ten itibaren kapasite gerçekten kısıtlar (her şey her yere sığmaz).
func test_capacity_matters_from_level_4() -> void:
	var solver: PrizSolver = PrizSolver.new()
	for n: int in range(4, 61):
		var level: PrizLevel = PrizLevel.load_shipped(n)
		var c: PrizCompiled = PrizCompiled.build(level, content.registry)
		var constrained: int = solver.count_compiled(c, 5000).count
		var free: int = solver.count_compiled(c, constrained + 1, true).count
		assert_true(free > constrained, "seviye %d: kapasite hiçbir şeyi elemiyor" % n)
