extends TestCase

## Yeni engellerin saf kuralları: çarşaf, çorap çifti, boya akıtan.


func _level(colors: Array, queue: Array, blockers: Dictionary = {}, extra: Dictionary = {}) -> Dictionary:
	var items: Array = []
	for index: int in range(colors.size()):
		var entry: Dictionary = {"id": index, "color": colors[index], "blockers": blockers.get(index, [])}
		entry.merge(extra.get(index, {}) as Dictionary)
		items.append(entry)
	return {"items": items, "queue": queue, "active_baskets": 2, "rack_slots": 4}


func _types(events: Array[Dictionary]) -> Array[String]:
	var types: Array[String] = []
	for event: Dictionary in events:
		types.append(String(event["type"]))
	return types


# --- Çarşaf ---

func test_sheet_opens_many_at_once_and_counts_as_one() -> void:
	# 0 çarşaf (renk 0) 1..4'ü kapatır; 0 + 5 + 6 renk 0 sepetini doldurur.
	var blockers: Dictionary = {1: [0], 2: [0], 3: [0], 4: [0]}
	var colors: Array = [0, 1, 1, 1, 2, 0, 0, 2, 2]
	var board: LaundryBoard = LaundryBoard.new(_level(colors, [0, 1, 2], blockers, {0: {"sheet": true}}))
	assert_true(board.is_sheet(0))
	for id: int in [1, 2, 3, 4]:
		assert_false(board.is_open(id), "çarşafın altı kapalı")
	var events: Array[Dictionary] = board.tap(0)
	assert_eq(String(events[0]["type"]), LaundryBoard.EVENT_TO_BASKET)
	for id: int in [1, 2, 3, 4]:
		assert_true(board.is_open(id), "çarşaf alınınca hepsi birden açılır")
	board.tap(5)
	var done: Array[Dictionary] = board.tap(6)
	assert_true(_types(done).has(LaundryBoard.EVENT_BASKET_DONE), "çarşaf sepette tek parça sayılır")


# --- Çorap çifti ---

## 0,1: çorap çifti (renk 2, sepeti henüz yok); 2: renk 2; 3-5 renk 0; 6-8 renk 1.
func _sock_level() -> Dictionary:
	var colors: Array = [2, 2, 2, 0, 0, 0, 1, 1, 1]
	return _level(colors, [0, 1, 2], {}, {0: {"sock": 1}, 1: {"sock": 0}})


func test_sock_partner_taken_next_is_fine() -> void:
	var board: LaundryBoard = LaundryBoard.new(_sock_level())
	var first: Array[Dictionary] = board.tap(0)
	assert_true(_types(first).has(LaundryBoard.EVENT_SOCK_WAIT))
	assert_eq(board.sock_waiting(), 0)
	var second: Array[Dictionary] = board.tap(1)
	assert_false(_types(second).has(LaundryBoard.EVENT_SOCK_STUCK))
	assert_eq(board.sock_waiting(), LaundryBoard.EMPTY)
	assert_false(board.is_sock_stuck(0))
	for id: int in [3, 4, 5]:
		board.tap(id)
	assert_eq(board.rack_count(), 0, "renk 2 sepeti gelince iki çorap da geçer")


func test_sock_gets_stuck_until_partner_is_taken() -> void:
	var board: LaundryBoard = LaundryBoard.new(_sock_level())
	board.tap(0)
	var other: Array[Dictionary] = board.tap(3)
	assert_true(_types(other).has(LaundryBoard.EVENT_SOCK_STUCK), "eşi sırayla alınmadı")
	assert_true(board.is_sock_stuck(0))
	board.tap(4)
	board.tap(5)
	# Renk 2 sepeti geldi ama takılı çorap askıda kalır.
	assert_true(board.rack().has(0), "takılı çorap sepete kendiliğinden geçmez")
	var partner: Array[Dictionary] = board.tap(1)
	assert_true(_types(partner).has(LaundryBoard.EVENT_SOCK_FREE))
	assert_false(board.is_sock_stuck(0))
	assert_false(board.rack().has(0), "eşi alınınca serbest kalıp sepete geçer")


func test_sock_in_basket_is_never_stuck() -> void:
	# Çorap rengi (0) aktif: ilk çorap doğrudan sepete gider; ceza yoktur.
	var colors: Array = [0, 0, 0, 1, 1, 1]
	var board: LaundryBoard = LaundryBoard.new(_level(colors, [0, 1], {}, {0: {"sock": 1}, 1: {"sock": 0}}))
	board.tap(0)
	var other: Array[Dictionary] = board.tap(3)
	assert_false(_types(other).has(LaundryBoard.EVENT_SOCK_STUCK))
	assert_true(board.stuck_ids().is_empty())


func test_wring_does_not_count_as_taking() -> void:
	var level: Dictionary = _sock_level()
	((level["items"] as Array)[3] as Dictionary)["wet"] = true
	var board: LaundryBoard = LaundryBoard.new(level)
	board.tap(0)
	board.tap(3)
	assert_eq(board.sock_waiting(), 0, "sıkma bir alma değildir: çorap beklemeye devam eder")
	board.tap(1)
	assert_true(board.stuck_ids().is_empty())


# --- Boya akıtan ---

## 0: boyalı (renk 1, 2 hamle), 1'in üstünde (1 renk 0). 2-4 açık dolgu.
func _dye_level(moves: int) -> Dictionary:
	var colors: Array = [1, 0, 0, 0, 1, 1, 2, 2, 2]
	return _level(colors, [0, 1, 2], {1: [0]}, {0: {"dye": moves, "dye_target": 1}})


func test_dye_counts_down_and_swaps_colours() -> void:
	var board: LaundryBoard = LaundryBoard.new(_dye_level(2))
	var first: Array[Dictionary] = board.tap(2)
	assert_eq(board.dye_left(0), 1)
	assert_true(_types(first).has(LaundryBoard.EVENT_DYE_TICK))
	var second: Array[Dictionary] = board.tap(3)
	assert_true(_types(second).has(LaundryBoard.EVENT_DYE_BLEED))
	assert_eq(board.color_of(1), 1, "alttaki boyanın rengini aldı")
	assert_eq(board.color_of(0), 0, "renk takası: sayılar korunur")
	board.tap(6)
	assert_eq(board.dye_left(0), 0, "boya bir kez akar")
	assert_eq(board.color_of(1), 1)


func test_dye_taken_in_time_does_not_bleed() -> void:
	var board: LaundryBoard = LaundryBoard.new(_dye_level(2))
	board.tap(2)
	var taken: Array[Dictionary] = board.tap(0)
	assert_false(_types(taken).has(LaundryBoard.EVENT_DYE_BLEED))
	assert_false(_types(taken).has(LaundryBoard.EVENT_DYE_TICK), "alınan boyalı sayılmaz")
	assert_eq(board.color_of(1), 0)


func test_dye_waits_while_covered() -> void:
	var level: Dictionary = _dye_level(2)
	((level["items"] as Array)[0] as Dictionary)["blockers"] = [5]
	var board: LaundryBoard = LaundryBoard.new(level)
	board.tap(2)
	assert_eq(board.dye_left(0), 2, "kapalıyken sayaç işlemez")
	board.tap(5)
	assert_eq(board.dye_left(0), 2, "açan hamle sayılmaz")
	board.tap(3)
	assert_eq(board.dye_left(0), 1)


func test_wring_ticks_dye() -> void:
	var level: Dictionary = _dye_level(2)
	((level["items"] as Array)[2] as Dictionary)["wet"] = true
	var board: LaundryBoard = LaundryBoard.new(level)
	board.tap(2)
	assert_eq(board.dye_left(0), 1, "sıkma da bir hamledir")


func test_solver_handles_new_rules() -> void:
	var sock: Array[int] = LevelSolver.solve(_sock_level())
	assert_false(sock.is_empty())
	var dye: Array[int] = LevelSolver.solve(_dye_level(1))
	assert_false(dye.is_empty())
	var board: LaundryBoard = LaundryBoard.new(_dye_level(1))
	for id: int in dye:
		board.tap(id)
	assert_true(board.is_won())
