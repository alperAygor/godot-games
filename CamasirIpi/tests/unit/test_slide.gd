extends TestCase

## Sürgülü ip: üst sıra her N hamlede iki konum arasında gidip gelir; örtme ilişkisi faza bağlıdır.


func _level() -> Dictionary:
	# 0,1,2 alt sıra (0 ve 1 kırmızı sepete, 2 mavi); 3 üst sırada kayan parça (mavi).
	# Faz 0: 3, 0 ve 1'i örter. Faz 1: 3, 1 ve 2'yi örter.
	var items: Array = []
	var colors: Array[int] = [0, 0, 1, 1, 0, 1]
	for index: int in range(colors.size()):
		items.append({"id": index, "color": colors[index], "blockers": []})
	return {"items": items, "queue": [0, 1], "active_baskets": 2, "rack_slots": 4,
		"slide": {"every": 2, "sliders": [3], "phases": [{0: [3], 1: [3]}, {1: [3], 2: [3]}]}}


func test_phase_zero_covers_first_pair() -> void:
	var board: LaundryBoard = LaundryBoard.new(_level())
	assert_false(board.is_open(0))
	assert_false(board.is_open(1))
	assert_true(board.is_open(2))
	assert_eq(board.blockers_of(0), [3] as Array[int])
	assert_eq(board.slide_left(), 2)


func test_slides_after_n_moves_and_back() -> void:
	var board: LaundryBoard = LaundryBoard.new(_level())
	var first: Array[Dictionary] = board.tap(4)
	assert_eq(String(first[first.size() - 1]["type"]), LaundryBoard.EVENT_SLIDE_TICK)
	var second: Array[Dictionary] = board.tap(5)
	var types: Array[String] = []
	for event: Dictionary in second:
		types.append(String(event["type"]))
	assert_true(types.has(LaundryBoard.EVENT_SLIDE), "ikinci hamlede kaymalı")
	assert_eq(board.slide_phase(), 1)
	assert_true(board.is_open(0), "kayınca 0 açılır")
	assert_false(board.is_open(2), "kayınca 2 örtülür")


func test_slides_back_on_the_next_cycle() -> void:
	# Kayan parça ipte kaldıkça faz gidip gelir: serbest dört parça ile dört hamle yapılır.
	var level: Dictionary = _level()
	for extra: int in range(6, 10):
		(level["items"] as Array).append({"id": extra, "color": 2, "blockers": []})
	level["queue"] = [2, 2, 0, 1]
	var board: LaundryBoard = LaundryBoard.new(level)
	board.tap(6)
	board.tap(7)
	assert_eq(board.slide_phase(), 1)
	board.tap(8)
	board.tap(9)
	assert_eq(board.slide_phase(), 0, "iki hamle sonra geri döner")
	assert_false(board.is_open(0))


func test_no_slide_once_slider_is_taken() -> void:
	var board: LaundryBoard = LaundryBoard.new(_level())
	board.tap(3)
	assert_eq(board.slide_left(), -1)
	assert_true(board.is_open(0))
	var events: Array[Dictionary] = board.tap(2)
	for event: Dictionary in events:
		assert_true(String(event["type"]) != LaundryBoard.EVENT_SLIDE_TICK, "kayan kalmayınca sayaç durur")


func test_undo_restores_slide_state() -> void:
	var board: LaundryBoard = LaundryBoard.new(_level())
	board.enable_history()
	board.tap(4)
	board.tap(5)
	assert_eq(board.slide_phase(), 1)
	assert_true(board.undo())
	assert_eq(board.slide_phase(), 0)
	assert_eq(board.slide_left(), 1)
	assert_false(board.is_open(0))


func test_solver_handles_slide() -> void:
	assert_true(LevelSolver.is_solvable(_level()))
