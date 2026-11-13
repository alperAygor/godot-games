extends TestCase

## Güçlendiriciler: geri al, mandal sökücü, +1 askı (saf mantık).


func _level(colors: Array, queue: Array, blockers: Dictionary = {}) -> Dictionary:
	var items: Array = []
	for index: int in range(colors.size()):
		items.append({"id": index, "color": colors[index], "blockers": blockers.get(index, [])})
	return {"items": items, "queue": queue, "active_baskets": 2, "rack_slots": 4}


func _state(board: LaundryBoard) -> String:
	var line: Array[int] = []
	for id: int in board.item_ids():
		if board.is_on_line(id):
			line.append(id)
	return "%s|%s|%s|%s|%d|%s|%s|%s" % [str(line), str(board.rack()), str(board.baskets()),
		str(board.queue()), board.moves(), str(board.completed_colors()), str(board.dye_state()),
		str([board.basket_contents(0), board.basket_contents(1)])]


func test_unlock_levels() -> void:
	assert_false(Boosters.is_unlocked(Boosters.UNDO, 5))
	assert_true(Boosters.is_unlocked(Boosters.UNDO, 6))
	assert_false(Boosters.is_unlocked(Boosters.PIN_REMOVER, 11))
	assert_true(Boosters.is_unlocked(Boosters.PIN_REMOVER, 12))
	assert_false(Boosters.is_unlocked(Boosters.EXTRA_SLOT, 17))
	assert_true(Boosters.is_unlocked(Boosters.EXTRA_SLOT, 18))


func test_undo_reverts_basket_chain_fully() -> void:
	# 0 askıya; 1-3 renk 0 sepetini doldurur, renk 2 sepeti gelir, 0 askıdan geçer.
	var board: LaundryBoard = LaundryBoard.new(_level([2, 0, 0, 0, 1, 1, 1, 2, 2], [0, 1, 2]))
	board.enable_history()
	var boosters: Boosters = Boosters.new()
	assert_false(boosters.can_use(Boosters.UNDO, board), "hamle yokken geri al yok")
	board.tap(0)
	board.tap(1)
	board.tap(2)
	var before: String = _state(board)
	var events: Array[Dictionary] = board.tap(3)
	assert_true(events.size() > 3, "zincir: sepet doldu, yenisi geldi, askı boşaldı")
	assert_true(boosters.undo(board))
	assert_eq(_state(board), before, "son dokunuş tümüyle geri alındı")
	board.tap(3)
	assert_eq(board.rack_count(), 0, "geri alınan hamle yeniden oynanabilir")


func test_undo_keeps_extra_rack_slot_and_skips_refused_taps() -> void:
	var board: LaundryBoard = LaundryBoard.new(_level([2, 0, 0, 0, 1, 1, 1, 2, 2], [0, 1, 2], {1: [8]}))
	board.enable_history()
	board.tap(1)
	assert_false(board.can_undo(), "engelli dokunuş geçmişe yazılmaz")
	board.tap(0)
	board.add_rack_slot()
	assert_true(board.undo())
	assert_eq(board.rack_slots(), 5, "+1 askı geri alınmaz")
	assert_eq(board.rack_count(), 0)
	assert_true(board.is_on_line(0))


func test_undo_restores_dye_and_sock_state() -> void:
	var colors: Array = [1, 0, 0, 0, 1, 1, 2, 2, 2]
	var level: Dictionary = _level(colors, [0, 1, 2], {1: [0]})
	((level["items"] as Array)[0] as Dictionary)["dye"] = 1
	((level["items"] as Array)[0] as Dictionary)["dye_target"] = 1
	var board: LaundryBoard = LaundryBoard.new(level)
	board.enable_history()
	var before: String = _state(board)
	board.tap(2)
	assert_eq(board.color_of(1), 1, "boya aktı")
	board.undo()
	assert_eq(_state(board), before)
	assert_eq(board.color_of(1), 0, "geri al rengi de geri verir")
	assert_eq(board.dye_left(0), 1)


func test_no_undo_after_win() -> void:
	var board: LaundryBoard = LaundryBoard.new(_level([0, 0, 0, 1, 1, 1], [0, 1]))
	board.enable_history()
	for id: int in range(6):
		board.tap(id)
	assert_true(board.is_won())
	assert_false(board.can_undo())


func test_pin_remover_takes_covered_item() -> void:
	# 3 renk 0, 4'ün altında; 4 renk 1.
	var board: LaundryBoard = LaundryBoard.new(_level([0, 0, 1, 0, 1, 1], [0, 1], {3: [4]}))
	var boosters: Boosters = Boosters.new()
	assert_true(boosters.can_use(Boosters.PIN_REMOVER, board))
	assert_true(boosters.pin(board, 0).is_empty(), "açık parça hedef değildir")
	var events: Array[Dictionary] = boosters.pin(board, 3)
	assert_true(Boosters.pin_succeeded(events))
	assert_eq(String(events[1]["type"]), LaundryBoard.EVENT_TO_BASKET)
	assert_false(board.is_on_line(3))
	assert_true(board.is_on_line(4), "üstündeki yerinde kalır")


func test_pin_remover_opens_locked_item() -> void:
	var colors: Array = [0, 0, 0, 1, 1, 1]
	var level: Dictionary = _level(colors, [0, 1])
	((level["items"] as Array)[3] as Dictionary)["lock"] = 0
	var board: LaundryBoard = LaundryBoard.new(level)
	var boosters: Boosters = Boosters.new()
	assert_true(Boosters.pin_succeeded(boosters.pin(board, 3)))
	assert_false(board.is_on_line(3))


func test_pin_remover_respects_full_rack() -> void:
	var colors: Array = [2, 2, 3, 3, 0, 0, 0, 1, 1, 1, 2, 3]
	var board: LaundryBoard = LaundryBoard.new(_level(colors, [0, 1, 2, 3], {10: [4]}))
	for id: int in [0, 1, 2, 3]:
		board.tap(id)
	var boosters: Boosters = Boosters.new()
	var events: Array[Dictionary] = boosters.pin(board, 10)
	assert_false(Boosters.pin_succeeded(events), "askı dolu: sökülen parçanın gideceği yer yok")
	assert_true(board.is_on_line(10))


func test_extra_slot_once_per_level_up_to_five() -> void:
	var board: LaundryBoard = LaundryBoard.new(_level([0, 0, 0, 1, 1, 1], [0, 1]))
	var boosters: Boosters = Boosters.new()
	assert_true(boosters.extra_slot(board))
	assert_eq(board.rack_slots(), 5)
	assert_false(boosters.extra_slot(board), "seviye başına bir kez")
	boosters.reset()
	assert_false(boosters.extra_slot(board), "askı en fazla 5 kanca")
