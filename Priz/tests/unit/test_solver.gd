extends TestCase
## Çözücü: bilinen sayımlar, kaba kuvvetle karşılaştırma, düğüm sınırı, ipucu doğruluğu.

const F: GDScript = preload("res://tests/data/priz_fixtures.gd")

var content: PrizContent


func before_each() -> void:
	if content == null:
		content = PrizContent.load_default()


func test_known_counts() -> void:
	var solver: PrizSolver = PrizSolver.new()
	var a: PrizSolveResult = solver.count_solutions(F.flat_a(), content.registry)
	assert_eq(a.count, 1)
	assert_true(a.is_exact())
	assert_eq(a.solution, {"d0": "s0", "d1": "s1", "d2": "s2"})
	var b: PrizSolveResult = solver.count_solutions(F.day_b(), content.registry)
	assert_eq(b.count, 2, "d0 L0'da ya da L1'de; s1/s2 eş prizler tek sayılır")
	assert_true(solver.is_solvable(F.day_b(), content.registry))


func test_cap_and_node_limit_reported() -> void:
	var level: PrizLevel = PrizLevel.load_shipped(14)
	var capped: PrizSolveResult = PrizSolver.new().count_solutions(level, content.registry, 2)
	assert_eq(capped.count, 2)
	assert_true(capped.capped)
	var tiny: PrizSolver = PrizSolver.new(3)
	var limited: PrizSolveResult = tiny.count_solutions(PrizLevel.load_shipped(60), content.registry)
	assert_true(limited.node_limit_hit, "düğüm sınırı raporlanır")
	assert_false(limited.is_exact())


func test_first_solution_is_valid_on_board() -> void:
	for n: int in [1, 7, 16, 33, 48, 60]:
		var level: PrizLevel = PrizLevel.load_shipped(n)
		var plan: Dictionary = PrizSolver.new().first_solution(level, content.registry)
		assert_eq(plan.size(), level.devices.size(), "seviye %d" % n)
		var board: PrizBoard = PrizBoard.new(level, content.registry)
		assert_true(board.apply_placement(plan).is_empty(), "seviye %d plan reddedildi" % n)
		if level.is_day_mode():
			assert_eq(board.start_day().back().type, PrizEvent.WIN, "seviye %d" % n)
		else:
			assert_true(board.is_won(), "seviye %d" % n)


## Kaba kuvvet: tüm priz atamalarını dener; çözücü "çözülebilir" dediğinde aynı fikirde olmalı.
func test_agrees_with_brute_force() -> void:
	var gen: PrizGenerator = PrizGenerator.new(content)
	var checked: int = 0
	for n: int in range(1, 30):
		var level: PrizLevel = gen.generate(n, 5000 + n)
		if level == null or level.devices.size() > 5:
			continue
		var c: PrizCompiled = PrizCompiled.build(level, content.registry)
		# Bir kapasiteyi bir blok kısıp hem çözülebilir hem çözülemez örnekler üret.
		for squeeze: int in 2:
			if squeeze == 1:
				level.lines[0].capacity = maxi(level.lines[0].capacity - 2, 0)
				c = PrizCompiled.build(level, content.registry)
			var brute: bool = _brute_any(c)
			var solved: bool = PrizSolver.new().count_compiled(c, 1).count > 0
			assert_eq(solved, brute, "seviye %d sıkma %d" % [n, squeeze])
			checked += 1
	assert_greater(float(checked), 10.0)


func _brute_any(c: PrizCompiled) -> bool:
	var placement: PackedInt32Array = PackedInt32Array()
	placement.resize(c.n_devices)
	return _brute_rec(c, placement, 0)


func _brute_rec(c: PrizCompiled, placement: PackedInt32Array, d: int) -> bool:
	if d == c.n_devices:
		return c.is_valid_solution(placement)
	for s: int in c.n_sockets:
		# Yalnız uyumsuz prizler elenir; kapasite en sonda, tam atamada denetlenir.
		if c.compat_of(d, s) != PrizReason.OK:
			continue
		placement[d] = s
		if _brute_rec(c, placement, d + 1):
			return true
	return false


## Ödüllü ipucu: boş tahtadan yalnız ipuçlarını izleyen oyuncu her seviyeyi kazanır.
func test_hint_chain_solves_every_shipped_level() -> void:
	var solver: PrizSolver = PrizSolver.new()
	for path: String in PrizLevel.shipped_files():
		var level: PrizLevel = PrizLevel.load_file(path)
		var board: PrizBoard = PrizBoard.new(level, content.registry)
		var guard: int = 0
		while not board.is_all_plugged() and guard < 64:
			guard += 1
			var h: PrizHint = solver.hint(board)
			assert_eq(h.kind, PrizHint.PLACE, path)
			if h.kind != PrizHint.PLACE:
				break
			assert_eq(board.socket_of(h.device_id), "", "ipucu takılı olmayan cihaz verir")
			assert_eq(board.plug(h.device_id, h.socket_id), PrizReason.OK, path)
		if level.is_day_mode():
			assert_eq(solver.hint(board).kind, PrizHint.NONE, path)
			assert_eq(board.start_day().back().type, PrizEvent.WIN, path)
		else:
			assert_true(board.is_won(), path)


func test_hint_partial_plan_consistent() -> void:
	# Doğru başlangıçtan sonra gelen ipucu da çözüme uzanmalı.
	var board: PrizBoard = PrizBoard.new(F.day_b(), content.registry)
	board.plug("d0", "s1")
	var h: PrizHint = PrizSolver.new().hint(board)
	assert_eq(h.kind, PrizHint.PLACE)
	board.plug(h.device_id, h.socket_id)
	var h2: PrizHint = PrizSolver.new().hint(board)
	board.plug(h2.device_id, h2.socket_id)
	assert_eq(board.start_day().back().type, PrizEvent.WIN)


func test_hint_move_when_plan_not_extendable() -> void:
	var board: PrizBoard = PrizBoard.new(F.day_b(), content.registry)
	F.plug_all(board, {"d0": "s1", "d1": "s2", "d2": "s0"})
	var solver: PrizSolver = PrizSolver.new()
	var h: PrizHint = solver.hint(board)
	assert_eq(h.kind, PrizHint.MOVE)
	assert_true(h.device_id != "")
	# İpucunu uygula, sonra ipuçlarıyla bitir.
	board.unplug(h.device_id)
	if h.socket_id != "" and board.free_seats(h.socket_id) > 0:
		assert_eq(board.plug(h.device_id, h.socket_id), PrizReason.OK)
	var guard: int = 0
	while guard < 10:
		guard += 1
		var next: PrizHint = solver.hint(board)
		if next.kind == PrizHint.NONE:
			break
		if next.kind == PrizHint.MOVE:
			board.unplug(next.device_id)
			continue
		assert_eq(board.plug(next.device_id, next.socket_id), PrizReason.OK)
	assert_eq(board.start_day().back().type, PrizEvent.WIN)


func test_hint_none_and_unsolvable() -> void:
	var board: PrizBoard = PrizBoard.new(F.day_b(), content.registry)
	F.plug_all(board, {"d0": "s0", "d1": "s1", "d2": "s2"})
	assert_eq(PrizSolver.new().hint(board).kind, PrizHint.NONE)
	var level: PrizLevel = F.day_b()
	level.lines[1].capacity = 0
	level.lines[0].capacity = 0
	var dead: PrizBoard = PrizBoard.new(level, content.registry)
	assert_eq(PrizSolver.new().hint(dead).kind, PrizHint.UNSOLVABLE)
