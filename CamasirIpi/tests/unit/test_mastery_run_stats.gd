extends TestCase

## RunStats: dokunuş/askı/sepet sayımı ve zincir tanımı (olay listelerinden, tahtasız).

func _to_rack(slot: int = 0) -> Dictionary:
	return {"type": LaundryBoard.EVENT_TO_RACK, "id": 1, "slot": slot}


func _to_basket() -> Dictionary:
	return {"type": LaundryBoard.EVENT_TO_BASKET, "id": 1, "basket": 0, "index": 0}


func _rack_to_basket() -> Dictionary:
	return {"type": LaundryBoard.EVENT_RACK_TO_BASKET, "id": 1, "basket": 0, "index": 1, "slot": 0}


func _done() -> Dictionary:
	return {"type": LaundryBoard.EVENT_BASKET_DONE, "basket": 0, "color": 0}


func _tap(stats: RunStats, list: Array[Dictionary]) -> int:
	return stats.record_tap(list)


func _plain() -> Array[Dictionary]:
	return [_to_basket()]


func _finish() -> Array[Dictionary]:
	return [_to_basket(), _done()]


func test_rejected_taps_are_not_counted() -> void:
	var stats: RunStats = RunStats.new()
	_tap(stats, [{"type": LaundryBoard.EVENT_BLOCKED, "id": 1, "by": [2]}])
	_tap(stats, [{"type": LaundryBoard.EVENT_LOCKED, "id": 1, "color": 0}])
	_tap(stats, [{"type": LaundryBoard.EVENT_RACK_FULL, "id": 1}])
	_tap(stats, [])
	assert_eq(stats.taps, 0)
	_tap(stats, _plain())
	_tap(stats, [{"type": LaundryBoard.EVENT_WRING, "id": 2}])
	assert_eq(stats.taps, 2, "sıkma da hamledir")


func test_rack_total_and_max_fill() -> void:
	var stats: RunStats = RunStats.new()
	_tap(stats, [_to_rack(0)])
	_tap(stats, [_to_rack(1)])
	assert_eq(stats.rack_total, 2)
	assert_eq(stats.rack_max, 2)
	# Bir sepet gelir, askıdan biri sepete geçer: doluluk düşer, ama en yüksek değer korunur.
	_tap(stats, [_to_basket(), _rack_to_basket()])
	_tap(stats, [_to_rack(0)])
	assert_eq(stats.rack_total, 3)
	assert_eq(stats.rack_max, 2)
	_tap(stats, [_to_rack(2)])
	assert_eq(stats.rack_max, 3)


func test_chain_continues_within_window() -> void:
	var stats: RunStats = RunStats.new(4)
	_tap(stats, _finish())
	assert_eq(stats.chain(), 1)
	for _i: int in range(3):
		_tap(stats, _plain())
	var next: Array[Dictionary] = _finish()
	_tap(stats, next)
	# 4. etkin dokunuş (aralık = 4 = pencere): zincir sürer.
	assert_eq(stats.chain(), 2)
	assert_eq(int(next[1][RunStats.EVENT_CHAIN_KEY]), 2, "olaya zincir adımı yazılır")
	assert_eq(stats.best_chain, 2)


func test_chain_breaks_after_window() -> void:
	var stats: RunStats = RunStats.new(4)
	_tap(stats, _finish())
	var broke: int = 0
	for _i: int in range(4):
		broke = _tap(stats, _plain())
	assert_eq(broke, 0, "pencerenin son dokunuşunda kopmaz")
	assert_eq(stats.chain(), 1)
	assert_eq(_tap(stats, _plain()), 1, "pencereyi aşan ilk dokunuşta zincir kopar, uzunluk döner")
	assert_eq(stats.chain(), 0)
	var late: Array[Dictionary] = _finish()
	_tap(stats, late)
	assert_eq(int(late[1][RunStats.EVENT_CHAIN_KEY]), 1, "yeniden 1'den başlar")
	assert_eq(stats.best_chain, 1)


func test_break_reports_long_chain_once() -> void:
	var stats: RunStats = RunStats.new(2)
	for _i: int in range(3):
		_tap(stats, _finish())
	assert_eq(stats.best_chain, 3)
	_tap(stats, _plain())
	_tap(stats, _plain())
	assert_eq(_tap(stats, _plain()), 3)
	assert_eq(_tap(stats, _plain()), 0, "kopan zincir bir kez bildirilir")
	assert_eq(stats.best_chain, 3, "en iyi zincir korunur")


func test_two_baskets_in_one_tap_chain_together() -> void:
	var stats: RunStats = RunStats.new(4)
	var burst: Array[Dictionary] = [_to_basket(), _done(), _rack_to_basket(), _done()]
	_tap(stats, burst)
	assert_eq(int(burst[1][RunStats.EVENT_CHAIN_KEY]), 1)
	assert_eq(int(burst[3][RunStats.EVENT_CHAIN_KEY]), 2)
	assert_eq(stats.baskets_done, 2)


func test_rejected_taps_do_not_eat_the_window() -> void:
	var stats: RunStats = RunStats.new(2)
	_tap(stats, _finish())
	for _i: int in range(5):
		_tap(stats, [{"type": LaundryBoard.EVENT_BLOCKED, "id": 1, "by": [2]}])
	_tap(stats, _plain())
	var next: Array[Dictionary] = _finish()
	_tap(stats, next)
	assert_eq(int(next[1][RunStats.EVENT_CHAIN_KEY]), 2)


func test_revive_booster_and_reset() -> void:
	var stats: RunStats = RunStats.new()
	stats.note_revive()
	stats.note_booster()
	stats.note_booster()
	_tap(stats, [_to_rack(0), _done()])
	assert_true(stats.revived)
	assert_eq(stats.boosters_used, 2)
	stats.reset()
	assert_false(stats.revived)
	assert_eq(stats.boosters_used, 0)
	assert_eq(stats.taps, 0)
	assert_eq(stats.rack_total, 0)
	assert_eq(stats.best_chain, 0)
	assert_eq(stats.chain(), 0)


func test_from_balance_reads_window() -> void:
	var stats: RunStats = RunStats.from_balance({"mastery": {"chain_window_taps": 1}})
	_tap(stats, _finish())
	_tap(stats, _plain())
	_tap(stats, _plain())
	assert_eq(stats.chain(), 0)
	var fallback: RunStats = RunStats.from_balance({})
	_tap(fallback, _finish())
	for _i: int in range(RunStats.DEFAULT_WINDOW_TAPS):
		_tap(fallback, _plain())
	assert_eq(fallback.chain(), 1)


func test_real_board_events_drive_the_stats() -> void:
	# Gerçek tahta: aynı renkten 3 çamaşır = 1 sepet; sepet tamamlanma olayına zincir yazılır.
	var items: Array[Dictionary] = []
	for index: int in range(3):
		items.append({"id": index, "color": 0, "blockers": [], "line": 0, "layer": 0, "slot": float(index)})
	var board: LaundryBoard = LaundryBoard.new({"items": items, "queue": [0], "active_baskets": 1, "rack_slots": 4})
	var stats: RunStats = RunStats.new()
	var last: Array[Dictionary] = []
	for index: int in range(3):
		last = board.tap(index)
		stats.record_tap(last)
	assert_eq(stats.taps, 3)
	assert_eq(stats.baskets_done, 1)
	assert_eq(stats.rack_total, 0)
	assert_eq(stats.best_chain, 1)
	assert_true(board.is_won())
