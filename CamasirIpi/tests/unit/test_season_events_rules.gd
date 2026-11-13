extends TestCase

## Mevsim olaylarının saf kuralları: güneşte solma (iki dokunuş cezası), düşen yaprak (ücretsiz
## süpürme), don (askıda bir hamle / kurutucu), polen (yalnız bilgi). Geri al ve çözücü dahil.


func _level(colors: Array, queue: Array, blockers: Dictionary = {}, extra: Dictionary = {}) -> Dictionary:
	var items: Array = []
	for index: int in range(colors.size()):
		var entry: Dictionary = {"id": index, "color": colors[index], "blockers": blockers.get(index, []),
			"line": index / 3}
		entry.merge(extra.get(index, {}) as Dictionary)
		items.append(entry)
	return {"items": items, "queue": queue, "active_baskets": 2, "rack_slots": 4}


func _types(events: Array[Dictionary]) -> Array[String]:
	var types: Array[String] = []
	for event: Dictionary in events:
		types.append(String(event["type"]))
	return types


# --- Güneşte solma ---

func test_sun_counts_only_while_open_and_fades() -> void:
	# 0 güneşli (2 hamle), 1 onu kapatır mı? Hayır: 0 açık. 3 kapalı ve güneşli (sayaç işlemez).
	var colors: Array = [0, 0, 0, 1, 1, 1]
	var board: LaundryBoard = LaundryBoard.new(_level(colors, [0, 1], {3: [4]},
		{0: {"sun": 2}, 3: {"sun": 2}}))
	assert_true(board.has_season())
	var first: Array[Dictionary] = board.tap(1)
	assert_true(_types(first).has(LaundryBoard.EVENT_SUN_TICK))
	assert_eq(board.sun_left(0), 1)
	assert_eq(board.sun_left(3), 2, "kapalı parçanın sayacı işlemez")
	var second: Array[Dictionary] = board.tap(5)
	assert_true(_types(second).has(LaundryBoard.EVENT_SUN_FADE))
	assert_true(board.is_faded(0))


func test_faded_needs_one_shake_then_take() -> void:
	var board: LaundryBoard = LaundryBoard.new(_level([0, 0, 0, 1, 1, 1], [0, 1], {}, {0: {"sun": 1}}))
	board.tap(1)
	assert_true(board.is_faded(0))
	var moves: int = board.moves()
	var shake: Array[Dictionary] = board.tap(0)
	assert_eq(_types(shake)[0], LaundryBoard.EVENT_SHAKE)
	assert_eq(board.moves(), moves + 1, "silkelemek bir hamle")
	assert_true(board.is_on_line(0), "silkelenen parça hâlâ ipte")
	var take: Array[Dictionary] = board.tap(0)
	assert_true(_types(take).has(LaundryBoard.EVENT_TO_BASKET), "ikinci dokunuşta alınır")


func test_taken_before_countdown_has_no_penalty() -> void:
	var board: LaundryBoard = LaundryBoard.new(_level([0, 0, 0, 1, 1, 1], [0, 1], {}, {0: {"sun": 3}}))
	var events: Array[Dictionary] = board.tap(0)
	assert_true(_types(events).has(LaundryBoard.EVENT_TO_BASKET))
	assert_false(_types(events).has(LaundryBoard.EVENT_SUN_TICK), "alınan parçanın sayacı işlemez")


func test_sun_undo_restores_counter_and_fade() -> void:
	var board: LaundryBoard = LaundryBoard.new(_level([0, 0, 0, 1, 1, 1], [0, 1], {}, {0: {"sun": 1}}))
	board.enable_history()
	var key: PackedInt32Array = board.state_key()
	board.tap(1)
	assert_true(board.is_faded(0))
	board.undo()
	assert_false(board.is_faded(0))
	assert_eq(board.sun_left(0), 1)
	assert_eq(board.state_key(), key)


# --- Düşen yapraklar ---

func _leaf_level() -> Dictionary:
	var level: Dictionary = _level([0, 0, 0, 1, 1, 1], [0, 1])
	level["leaves"] = {"every": 2, "targets": [3, 0]}
	return level


func test_leaf_lands_shown_ahead_and_brush_is_free() -> void:
	var board: LaundryBoard = LaundryBoard.new(_leaf_level())
	assert_eq(board.leaf_left(), 2)
	assert_eq(board.leaf_next(), 3)
	var tick: Array[Dictionary] = board.tap(1)
	assert_true(_types(tick).has(LaundryBoard.EVENT_LEAF_TICK))
	assert_eq(board.leaf_left(), 1, "bir hamle önceden bilinir")
	var land: Array[Dictionary] = board.tap(2)
	assert_true(_types(land).has(LaundryBoard.EVENT_LEAF_LAND))
	assert_true(board.is_leafy(3))
	var moves: int = board.moves()
	var brush: Array[Dictionary] = board.tap(3)
	assert_eq(_types(brush), [LaundryBoard.EVENT_LEAF_BRUSH] as Array[String])
	assert_eq(board.moves(), moves, "süpürmek hamle değil")
	assert_true(board.is_on_line(3))
	assert_false(board.is_leafy(3))
	var take: Array[Dictionary] = board.tap(3)
	assert_true(_types(take).has(LaundryBoard.EVENT_TO_BASKET) or _types(take).has(LaundryBoard.EVENT_TO_RACK))


func test_leaf_passes_when_target_gone() -> void:
	var board: LaundryBoard = LaundryBoard.new(_leaf_level())
	board.tap(3)
	var events: Array[Dictionary] = board.tap(1)
	assert_true(_types(events).has(LaundryBoard.EVENT_LEAF_PASS), "hedef ipte değil: geçer")


func test_undo_restores_leaf_state() -> void:
	var board: LaundryBoard = LaundryBoard.new(_leaf_level())
	board.enable_history()
	board.tap(1)
	var key: PackedInt32Array = board.state_key()
	board.tap(2)
	assert_true(board.is_leafy(3))
	board.tap(3)
	assert_false(board.is_leafy(3))
	board.undo()
	assert_eq(board.state_key(), key, "geri al son hamleyi ve ardındaki süpürmeyi geri sarar")
	assert_false(board.is_leafy(3))
	assert_eq(board.leaf_left(), 1)


func test_solver_brushes_leaves_and_path_replays() -> void:
	var level: Dictionary = _leaf_level()
	var path: Array[int] = LevelSolver.solve(level)
	assert_false(path.is_empty())
	var board: LaundryBoard = LaundryBoard.new(level)
	for id: int in path:
		board.tap(id)
	assert_true(board.is_won(), "süpürmeler yola yazılır, oyunda aynen oynanır")


# --- Don ---

func test_frost_rests_one_move_on_rack_then_settles() -> void:
	var board: LaundryBoard = LaundryBoard.new(_level([0, 0, 0, 1, 1, 1], [0, 1], {}, {0: {"frost": true}}))
	var events: Array[Dictionary] = board.tap(0)
	assert_true(_types(events).has(LaundryBoard.EVENT_TO_RACK), "renk eşleşse de askıya")
	assert_true(_types(events).has(LaundryBoard.EVENT_FROST_WAIT))
	assert_true(board.is_drying(0))
	var next: Array[Dictionary] = board.tap(1)
	assert_true(_types(next).has(LaundryBoard.EVENT_FROST_THAW))
	assert_true(_types(next).has(LaundryBoard.EVENT_RACK_TO_BASKET), "çözülünce sepete geçer")
	assert_false(board.is_frozen(0))


func test_frost_goes_through_dryer_when_present() -> void:
	var level: Dictionary = _level([0, 0, 0, 1, 1, 1], [0, 1], {}, {0: {"frost": true}})
	level["dryer"] = {"capacity": 2, "moves": 2}
	var board: LaundryBoard = LaundryBoard.new(level)
	var events: Array[Dictionary] = board.tap(0)
	assert_eq(String(events[0]["type"]), LaundryBoard.EVENT_TO_MACHINE)
	board.tap(3)
	var out: Array[Dictionary] = board.tap(4)
	assert_true(_types(out).has(LaundryBoard.EVENT_MACHINE_OUT))
	assert_false(board.is_frozen(0), "kurutucudan çözülmüş çıkar")
	assert_eq(board.rack_count(), 0, "doğrudan sepete")


func test_frost_with_full_rack_is_refused_not_lost() -> void:
	var level: Dictionary = _level([0, 1, 2, 3, 0, 0], [0, 4], {}, {4: {"frost": true}})
	level["rack_slots"] = 1
	var board: LaundryBoard = LaundryBoard.new(level)
	board.tap(1)
	var refuse: Array[Dictionary] = board.tap(4)
	assert_eq(_types(refuse), [LaundryBoard.EVENT_RACK_FULL] as Array[String])


# --- Polen ---

func test_pollen_hides_a_line_for_k_moves_without_rule_effect() -> void:
	var level: Dictionary = _level([0, 0, 0, 1, 1, 1, 0, 1, 2, 2, 2, 2], [0, 1, 2, 0, 1, 2])
	level["pollen"] = {"every": 1, "lines": [1], "hide": 2}
	var plain: Dictionary = level.duplicate(true)
	plain.erase("pollen")
	var board: LaundryBoard = LaundryBoard.new(level)
	var reference: LaundryBoard = LaundryBoard.new(plain)
	assert_eq(board.pollen_left(), 1)
	var puff: Array[Dictionary] = board.tap(0)
	reference.tap(0)
	assert_true(_types(puff).has(LaundryBoard.EVENT_POLLEN))
	assert_eq(board.dust_line(), 1)
	assert_true(board.is_dusty(3) and board.is_dusty(5))
	assert_false(board.is_dusty(0))
	var take: Array[Dictionary] = board.tap(4)
	reference.tap(4)
	assert_true(_types(take).has(LaundryBoard.EVENT_TO_BASKET), "tozlu parça alınabilir")
	var clear: Array[Dictionary] = board.tap(1)
	reference.tap(1)
	assert_true(_types(clear).has(LaundryBoard.EVENT_POLLEN_CLEAR))
	assert_eq(board.dust_line(), LaundryBoard.EMPTY)
	assert_eq(board.state_key(), reference.state_key(), "polen kural durumunu değiştirmez")
	assert_eq(board.rack(), reference.rack())
