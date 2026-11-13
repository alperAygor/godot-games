extends TestCase

## LaundryBoard kuralları (PROJECT_SPEC §1).


func _level(colors: Array, queue: Array, blockers: Dictionary = {}) -> Dictionary:
	var items: Array = []
	for index: int in range(colors.size()):
		items.append({"id": index, "color": colors[index], "blockers": blockers.get(index, [])})
	return {"items": items, "queue": queue, "active_baskets": 2, "rack_slots": 4}


func test_matching_color_goes_to_basket() -> void:
	var board: LaundryBoard = LaundryBoard.new(_level([0, 0, 0, 1, 1, 1], [0, 1]))
	var events: Array[Dictionary] = board.tap(0)
	assert_eq(String(events[0]["type"]), LaundryBoard.EVENT_TO_BASKET)
	assert_eq(board.rack_count(), 0)


func test_non_matching_color_goes_to_rack() -> void:
	var board: LaundryBoard = LaundryBoard.new(_level([2, 2, 2, 0, 0, 0, 1, 1, 1], [0, 1, 2]))
	var events: Array[Dictionary] = board.tap(0)
	assert_eq(String(events[0]["type"]), LaundryBoard.EVENT_TO_RACK)
	assert_eq(board.rack_count(), 1)


func test_blocked_item_cannot_be_taken() -> void:
	var board: LaundryBoard = LaundryBoard.new(_level([0, 0, 0], [0], {0: [1]}))
	var events: Array[Dictionary] = board.tap(0)
	assert_eq(String(events[0]["type"]), LaundryBoard.EVENT_BLOCKED)
	assert_true(board.is_on_line(0))
	assert_false(board.is_open(0))
	board.tap(1)
	assert_true(board.is_open(0), "üstündeki alınınca açılmalı")


func test_full_basket_is_replaced_and_rack_auto_moves() -> void:
	var board: LaundryBoard = LaundryBoard.new(_level([2, 0, 0, 0, 1, 1, 1, 2, 2], [0, 1, 2]))
	board.tap(0)
	assert_eq(board.rack_count(), 1)
	board.tap(1)
	board.tap(2)
	var events: Array[Dictionary] = board.tap(3)
	var types: Array[String] = []
	for event: Dictionary in events:
		types.append(String(event["type"]))
	assert_true(types.has(LaundryBoard.EVENT_BASKET_DONE))
	assert_true(types.has(LaundryBoard.EVENT_BASKET_NEW))
	assert_true(types.has(LaundryBoard.EVENT_RACK_TO_BASKET), "askıdaki renk yeni sepete geçmeli")
	assert_eq(board.rack_count(), 0)


func test_win_when_everything_is_folded() -> void:
	var board: LaundryBoard = LaundryBoard.new(_level([0, 0, 0, 1, 1, 1], [0, 1]))
	for id: int in range(6):
		board.tap(id)
	assert_true(board.is_won())
	assert_false(board.is_lost())


func test_full_rack_is_not_a_loss_while_a_basket_move_exists() -> void:
	var colors: Array = [2, 2, 3, 3, 0, 0, 0, 1, 1, 1, 2, 3]
	var board: LaundryBoard = LaundryBoard.new(_level(colors, [0, 1, 2, 3]))
	for id: int in [0, 1, 2, 3]:
		board.tap(id)
	assert_eq(board.rack_count(), 4, "dört slot da kullanılabilir")
	assert_false(board.is_lost(), "sepete gidebilecek çamaşır varken kayıp olmaz")
	var refused: Array[Dictionary] = board.tap(10)
	assert_eq(String(refused[0]["type"]), LaundryBoard.EVENT_RACK_FULL)
	assert_true(board.is_on_line(10), "askı doluyken eşleşmeyen parça alınamaz")
	assert_false(board.tap(4).is_empty(), "eşleşen parça hâlâ alınabilir")


func test_lose_when_rack_full_and_no_move_left() -> void:
	# 0-3 açık (sepetlerle eşleşmez); 4-5 açık ama eşleşmez; eşleşenler (6-11) 4 ve 5'in altında.
	var colors: Array = [2, 2, 3, 3, 2, 3, 0, 0, 0, 1, 1, 1]
	var blockers: Dictionary = {6: [4], 7: [4], 8: [4], 9: [5], 10: [5], 11: [5]}
	var board: LaundryBoard = LaundryBoard.new(_level(colors, [0, 1, 2, 3], blockers))
	for id: int in [0, 1, 2]:
		board.tap(id)
	assert_false(board.is_lost())
	var events: Array[Dictionary] = board.tap(3)
	assert_true(board.is_lost(), "askı dolu ve sepete gidecek açık parça yok")
	assert_eq(String(events[events.size() - 1]["type"]), LaundryBoard.EVENT_LOSE)
	assert_true(board.tap(5).is_empty(), "kayıptan sonra hamle yok")


func test_extra_rack_slot_revives() -> void:
	# 0-3 açık (sepetlerle eşleşmez); 4-5 açık ama eşleşmez; eşleşenler (6-11) 4 ve 5'in altında.
	var colors: Array = [2, 2, 3, 3, 2, 3, 0, 0, 0, 1, 1, 1]
	var blockers: Dictionary = {6: [4], 7: [4], 8: [4], 9: [5], 10: [5], 11: [5]}
	var board: LaundryBoard = LaundryBoard.new(_level(colors, [0, 1, 2, 3], blockers))
	for id: int in [0, 1, 2, 3]:
		board.tap(id)
	assert_true(board.is_lost())
	board.add_rack_slot()
	assert_false(board.is_lost())
	assert_eq(board.rack_slots(), 5)
	assert_false(board.tap(4).is_empty())


func test_wet_item_needs_two_taps() -> void:
	var level: Dictionary = _level([0, 0, 0], [0])
	((level["items"] as Array)[0] as Dictionary)["wet"] = true
	var board: LaundryBoard = LaundryBoard.new(level)
	var first: Array[Dictionary] = board.tap(0)
	assert_eq(String(first[0]["type"]), LaundryBoard.EVENT_WRING)
	assert_true(board.is_on_line(0), "ilk dokunuş yalnız sıkar")
	board.tap(0)
	assert_false(board.is_on_line(0))


func test_locked_item_opens_when_its_basket_completes() -> void:
	var level: Dictionary = _level([0, 0, 0, 1, 1, 1], [0, 1])
	((level["items"] as Array)[3] as Dictionary)["lock"] = 0
	var board: LaundryBoard = LaundryBoard.new(level)
	var events: Array[Dictionary] = board.tap(3)
	assert_eq(String(events[0]["type"]), LaundryBoard.EVENT_LOCKED)
	assert_true(board.is_locked(3))
	assert_false(board.open_ids().has(3))
	board.tap(0)
	board.tap(1)
	var done: Array[Dictionary] = board.tap(2)
	var types: Array[String] = []
	for event: Dictionary in done:
		types.append(String(event["type"]))
	assert_true(types.has(LaundryBoard.EVENT_UNLOCK))
	assert_false(board.is_locked(3))
	board.tap(3)
	assert_false(board.is_on_line(3))

