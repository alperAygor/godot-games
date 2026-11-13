extends TestCase

## Kural çeşitlemelerinin saf kuralları: joker sepet, büyük sepet, lekeli, zincirli mandal,
## rüzgâr ve seviye hedefi kipleri (hamle sınırı, sipariş, iki ekranlı patron).


func _level(colors: Array, queue: Array, blockers: Dictionary = {}, extra: Dictionary = {},
		fields: Dictionary = {}) -> Dictionary:
	var items: Array = []
	for index: int in range(colors.size()):
		var entry: Dictionary = {"id": index, "color": colors[index], "blockers": blockers.get(index, [])}
		entry.merge(extra.get(index, {}) as Dictionary)
		items.append(entry)
	var level: Dictionary = {"items": items, "queue": queue, "active_baskets": 2, "rack_slots": 4}
	level.merge(fields, true)
	return level


func _types(events: Array[Dictionary]) -> Array[String]:
	var types: Array[String] = []
	for event: Dictionary in events:
		types.append(String(event["type"]))
	return types


# --- Joker sepet ---

## Kuyruk: 0 (renk 0), 1 (renk 1), 2 = joker (ref 2), 3 (renk 1). Parçalar: 3x0, 6x1, 3x2.
func _joker_level() -> Dictionary:
	var colors: Array = [0, 0, 0, 1, 1, 1, 1, 1, 1, 2, 2, 2]
	return _level(colors, [0, 1, 2, 1], {}, {}, {"jokers": [2]})


func test_joker_takes_ref_colour_without_swap() -> void:
	var board: LaundryBoard = LaundryBoard.new(_joker_level())
	for id: int in [0, 1, 2]:
		board.tap(id)
	assert_true(board.is_joker_basket(0), "renk 0 sepeti dolunca joker gelir")
	assert_eq(int(board.baskets()[0]["color"]), LaundryBoard.EMPTY, "joker henüz renksiz")
	var events: Array[Dictionary] = board.tap(9)
	assert_eq(String(events[0]["type"]), LaundryBoard.EVENT_JOKER_FIX)
	assert_eq(int(events[0]["swap"]), LaundryBoard.EMPTY, "asıl renk: kuyruk değişmez")
	assert_eq(int(board.baskets()[0]["color"]), 2)
	assert_eq(board.queue(), [1] as Array[int])


func test_joker_waits_while_coloured_basket_matches() -> void:
	var board: LaundryBoard = LaundryBoard.new(_joker_level())
	for id: int in [0, 1, 2, 3, 4, 5]:
		board.tap(id)
	# Renk 1 sepeti doldu -> kuyruktan renk 1 (sıra 3) gelir; joker sıra 0'da renksiz.
	assert_true(board.is_joker_basket(0))
	assert_eq(int(board.baskets()[1]["color"]), 1)
	board.tap(6)
	board.tap(7)
	board.tap(8)
	# Renk 1 sepeti yine doldu; kuyruk boş. Joker renk 2 dışında bir renk alamaz artık.
	assert_eq(int(board.baskets()[0]["color"]), LaundryBoard.EMPTY)
	for id: int in [9, 10, 11]:
		board.tap(id)
	assert_true(board.is_won(), "joker ref rengiyle tamamlanır")


func test_joker_relabels_first_queued_normal_basket() -> void:
	# Kuyruk: 0, joker(ref 2), 1, 1. Parça 3 (renk 1) jokere gider: kuyruktaki ilk 1 -> 2 olur.
	var colors: Array = [0, 0, 0, 1, 1, 1, 1, 1, 1, 2, 2, 2]
	var board: LaundryBoard = LaundryBoard.new(_level(colors, [0, 2, 1, 1], {}, {}, {"jokers": [1]}))
	assert_true(board.is_joker_basket(1), "ikinci aktif sepet joker")
	var events: Array[Dictionary] = board.tap(3)
	assert_eq(String(events[0]["type"]), LaundryBoard.EVENT_JOKER_FIX)
	assert_eq(int(events[0]["color"]), 1)
	assert_eq(int(events[0]["swap"]), 0, "kuyruktaki ilk renk 1 sepeti")
	assert_eq(board.queue(), [2, 1] as Array[int], "renk sayıları dengede kalır")
	for id: int in [4, 5, 0, 1, 2, 9, 10, 11, 6, 7, 8]:
		board.tap(id)
	assert_true(board.is_won(), "takastan sonra da seviye bitirilebilir")


func test_joker_refuses_colour_without_queued_basket() -> void:
	# Joker (ref 1) ikinci aktif sepet; kuyrukta renk 2 için normal sepet yok -> renk 2 giremez.
	var board: LaundryBoard = LaundryBoard.new(_level([0, 0, 0, 1, 1, 1], [0, 1], {}, {}, {"jokers": [1]}))
	assert_true(board.is_joker_basket(1))
	assert_false(board.joker_accepts(board.baskets()[1], 2), "kuyrukta sepeti olmayan renk jokere giremez")
	assert_true(board.joker_accepts(board.baskets()[1], 1), "asıl renk her zaman girer")
	var events: Array[Dictionary] = board.tap(3)
	assert_eq(String(events[0]["type"]), LaundryBoard.EVENT_JOKER_FIX)
	assert_eq(int(events[0]["swap"]), LaundryBoard.EMPTY)


# --- Büyük sepet ---

func test_big_basket_needs_five() -> void:
	var colors: Array = [0, 0, 0, 0, 0, 1, 1, 1]
	var board: LaundryBoard = LaundryBoard.new(_level(colors, [0, 1], {}, {}, {"big": [0]}))
	assert_eq(board.basket_capacity(0), LaundryBoard.BIG_BASKET_CAPACITY)
	for id: int in [0, 1, 2]:
		var events: Array[Dictionary] = board.tap(id)
		assert_false(_types(events).has(LaundryBoard.EVENT_BASKET_DONE), "3 parça yetmez")
	board.tap(3)
	var done: Array[Dictionary] = board.tap(4)
	assert_true(_types(done).has(LaundryBoard.EVENT_BASKET_DONE), "5. parça sepeti kapatır")


# --- Lekeli ---

func test_stained_rests_one_move_then_moves_to_basket() -> void:
	var colors: Array = [0, 0, 0, 1, 1, 1]
	var board: LaundryBoard = LaundryBoard.new(_level(colors, [0, 1], {}, {0: {"stain": true}}))
	var events: Array[Dictionary] = board.tap(0)
	assert_eq(String(events[0]["type"]), LaundryBoard.EVENT_TO_RACK, "eşleşse bile askıya")
	assert_true(_types(events).has(LaundryBoard.EVENT_STAIN_WAIT))
	assert_true(board.is_drying(0))
	var next: Array[Dictionary] = board.tap(3)
	var types: Array[String] = _types(next)
	assert_true(types.has(LaundryBoard.EVENT_STAIN_DRY), "sonraki hamlede kurur")
	assert_true(types.has(LaundryBoard.EVENT_RACK_TO_BASKET), "kuruyunca sepete geçer")
	assert_eq(board.rack_count(), 0)
	assert_false(board.is_stained(0))


func test_stained_refused_when_rack_full_and_last_item_dries() -> void:
	var colors: Array = [2, 0, 0, 0, 1, 1, 1, 2, 2]
	var full: Dictionary = _level(colors, [0, 1, 2], {}, {0: {"stain": true}}, {"rack_slots": 1})
	var board: LaundryBoard = LaundryBoard.new(full)
	board.tap(7)
	var refused: Array[Dictionary] = board.tap(0)
	assert_eq(String(refused[0]["type"]), LaundryBoard.EVENT_RACK_FULL, "askıda yer yoksa alınamaz")
	assert_true(board.is_on_line(0))
	# Tek parçalık seviye: son parça lekeliyse ip boşalınca hemen kurur, seviye biter.
	var single: LaundryBoard = LaundryBoard.new(_level([0, 0, 0], [0], {}, {2: {"stain": true}}))
	single.tap(0)
	single.tap(1)
	var last: Array[Dictionary] = single.tap(2)
	assert_true(_types(last).has(LaundryBoard.EVENT_STAIN_DRY))
	assert_true(single.is_won(), "son lekeli parça seviyeyi kilitlemez")


# --- Zincirli mandal ---

func test_chain_partner_drops_to_rack_even_if_covered() -> void:
	var colors: Array = [0, 1, 0, 0, 1, 1, 2]
	# 1, 6 tarafından örtülü; 0 ile 1 zincirli.
	var level: Dictionary = _level(colors, [0, 1, 2], {1: [6]}, {0: {"chain": 1}, 1: {"chain": 0}})
	var board: LaundryBoard = LaundryBoard.new(level)
	var events: Array[Dictionary] = board.tap(0)
	var types: Array[String] = _types(events)
	assert_true(types.has(LaundryBoard.EVENT_CHAIN_DROP))
	assert_false(board.is_on_line(1), "eşi ipten düştü")
	assert_true(board.rack().has(1) or board.basket_contents(1).has(1), "eşi askıya (sonra sepete) gitti")


func test_chain_refused_without_enough_slots() -> void:
	var colors: Array = [2, 2, 0, 0, 0, 1, 1, 1, 2]
	var level: Dictionary = _level(colors, [0, 1, 2], {}, {0: {"chain": 1}, 1: {"chain": 0}},
		{"rack_slots": 1})
	var board: LaundryBoard = LaundryBoard.new(level)
	var events: Array[Dictionary] = board.tap(0)
	assert_eq(String(events[0]["type"]), LaundryBoard.EVENT_RACK_FULL, "iki slot gerekirdi")
	assert_true(board.is_on_line(0) and board.is_on_line(1), "durum değişmedi")
	assert_eq(board.moves(), 0)


# --- Rüzgâr ---

func test_wind_counts_down_and_covers_neighbour() -> void:
	var colors: Array = [0, 0, 0, 1, 1, 1, 2, 2, 2]
	var level: Dictionary = _level(colors, [0, 1, 2], {}, {}, {"wind": {"every": 2, "steps": [[8, 7]]}})
	var board: LaundryBoard = LaundryBoard.new(level)
	assert_eq(board.wind_left(), 2)
	assert_eq(board.wind_next(), Vector2i(8, 7))
	var first: Array[Dictionary] = board.tap(0)
	assert_true(_types(first).has(LaundryBoard.EVENT_WIND_TICK))
	assert_eq(board.wind_left(), 1)
	assert_true(board.is_open(7))
	var second: Array[Dictionary] = board.tap(1)
	assert_true(_types(second).has(LaundryBoard.EVENT_WIND), "sayaç bitince eser")
	assert_false(board.is_open(7), "komşusu artık örtülü")
	assert_eq(board.blockers_of(7), [8] as Array[int])
	assert_eq(board.wind_left(), -1, "adım kalmadı")
	board.tap(8)
	assert_true(board.is_open(7), "savrulan alınınca açılır")


func test_wind_is_void_when_mover_gone_and_undo_restores() -> void:
	var colors: Array = [0, 0, 0, 1, 1, 1, 2, 2, 2]
	var level: Dictionary = _level(colors, [0, 1, 2], {}, {}, {"wind": {"every": 2, "steps": [[0, 7]]}})
	var board: LaundryBoard = LaundryBoard.new(level)
	board.enable_history()
	board.tap(0)
	var events: Array[Dictionary] = board.tap(1)
	var gust: Dictionary = {}
	for event: Dictionary in events:
		if String(event["type"]) == LaundryBoard.EVENT_WIND:
			gust = event
	assert_false(bool(gust.get("effective", true)), "savrulan ipte değil: boşa eser")
	assert_true(board.is_open(7))
	assert_true(board.undo())
	assert_eq(board.wind_left(), 1, "geri al sayacı geri alır")


func test_wind_never_creates_cycle() -> void:
	# 7, 8'i örtüyor; rüzgâr 8'i 7'nin üstüne kapatmak isterse döngü olurdu -> boşa eser.
	var colors: Array = [0, 0, 0, 1, 1, 1, 2, 2, 2]
	var level: Dictionary = _level(colors, [0, 1, 2], {8: [7]}, {}, {"wind": {"every": 1, "steps": [[8, 7]]}})
	var board: LaundryBoard = LaundryBoard.new(level)
	var events: Array[Dictionary] = board.tap(0)
	for event: Dictionary in events:
		if String(event["type"]) == LaundryBoard.EVENT_WIND:
			assert_false(bool(event["effective"]))
	assert_true(board.is_open(7))


# --- Kipler ---

func test_move_limit_loses_with_reason_and_revive_adds_moves() -> void:
	var colors: Array = [0, 0, 0, 1, 1, 1]
	var board: LaundryBoard = LaundryBoard.new(_level(colors, [0, 1], {}, {}, {"mode": "moves", "move_limit": 2}))
	assert_eq(board.mode(), LaundryBoard.MODE_MOVES)
	assert_eq(board.moves_left(), 2)
	board.tap(0)
	var events: Array[Dictionary] = board.tap(1)
	assert_true(board.is_lost())
	assert_eq(board.lose_reason(), LaundryBoard.LOSE_MOVES)
	assert_eq(String(events[events.size() - 1]["reason"]), LaundryBoard.LOSE_MOVES)
	board.add_rack_slot()
	assert_false(board.is_lost())
	assert_eq(board.moves_left(), LaundryBoard.MOVE_REVIVE_BONUS)
	assert_eq(LaundryBoard.new(_level(colors, [0, 1])).moves_left(), -1, "sınırsız")


func test_move_limit_win_on_last_move() -> void:
	var board: LaundryBoard = LaundryBoard.new(_level([0, 0, 0], [0], {}, {}, {"move_limit": 3}))
	for id: int in [0, 1, 2]:
		board.tap(id)
	assert_true(board.is_won(), "son hamle kazandırırsa kayıp değil")


func test_orders_bonus_and_broken_order_is_not_a_loss() -> void:
	var colors: Array = [0, 0, 0, 1, 1, 1]
	var ordered: Dictionary = _level(colors, [0, 1], {}, {}, {"mode": "orders", "orders": [1, 0]})
	var good: LaundryBoard = LaundryBoard.new(ordered)
	assert_eq(good.orders(), [1, 0] as Array[int], "sıralar kuyruktan renge çevrilir")
	for id: int in [3, 4, 5, 0, 1, 2]:
		good.tap(id)
	assert_true(good.is_won())
	assert_true(good.order_bonus_earned())
	assert_true(bool(good.result_summary()["order_bonus_earned"]))
	var bad: LaundryBoard = LaundryBoard.new(ordered)
	var events: Array[Dictionary] = []
	for id: int in [0, 1, 2]:
		events = bad.tap(id)
	assert_true(_types(events).has(LaundryBoard.EVENT_ORDER_BROKEN))
	assert_false(bad.is_lost(), "yanlış sıra kayıp değildir")
	for id: int in [3, 4, 5]:
		bad.tap(id)
	assert_true(bad.is_won())
	assert_false(bad.order_bonus_earned())
	var strict: Dictionary = ordered.duplicate()
	strict["orders_strict"] = true
	var checked: LaundryBoard = LaundryBoard.new(strict)
	for id: int in [0, 1, 2]:
		checked.tap(id)
	assert_true(checked.is_lost(), "üretici doğrulamasında katı kip kaybettirir")


func test_boss_second_screen_opens_after_first_and_keeps_rack() -> void:
	var colors: Array = [0, 0, 1, 1, 1, 0]
	var level: Dictionary = _level(colors, [0, 1], {}, {3: {"screen": 1}, 4: {"screen": 1}, 5: {"screen": 1}},
		{"mode": "boss", "active_baskets": 1})
	var board: LaundryBoard = LaundryBoard.new(level)
	assert_eq(board.screen_count(), 2)
	assert_true(board.is_hidden(3))
	assert_false(board.is_open(3))
	assert_true(board.tap(3).is_empty(), "gizli ekrandaki parça dokunulamaz")
	board.tap(0)
	board.tap(1)
	board.tap(2)
	var events: Array[Dictionary] = board.tap(2)
	assert_true(events.is_empty())
	assert_eq(board.current_screen(), 1, "ilk ekran boşalınca ikinci gelir")
	assert_eq(board.rack_count(), 1, "askıdaki renk 1 parçası ikinci ekrana taşınır")
	for id: int in [5, 3, 4]:
		board.tap(id)
	assert_true(board.is_won())


func test_undo_restores_new_state() -> void:
	var colors: Array = [0, 0, 0, 1, 1, 1]
	var level: Dictionary = _level(colors, [0, 1], {}, {0: {"stain": true}}, {"move_limit": 9})
	var board: LaundryBoard = LaundryBoard.new(level)
	board.enable_history()
	board.tap(0)
	assert_true(board.is_drying(0))
	board.tap(3)
	assert_false(board.is_drying(0))
	board.undo()
	assert_true(board.is_drying(0), "geri al kurumayı geri alır")
	assert_true(board.is_stained(0))
	assert_eq(board.moves_left(), 8)
	board.undo()
	assert_true(board.is_on_line(0))


func test_state_key_distinguishes_new_state() -> void:
	var colors: Array = [0, 0, 0, 1, 1, 1]
	var a: LaundryBoard = LaundryBoard.new(_level(colors, [0, 1], {}, {0: {"stain": true}}))
	var b: LaundryBoard = LaundryBoard.new(_level(colors, [0, 1], {}, {0: {"stain": true}}))
	a.tap(0)
	assert_true(a.state_key() != b.state_key())
	var plain: LaundryBoard = LaundryBoard.new(_level(colors, [0, 1]))
	var plain_copy: LaundryBoard = LaundryBoard.new(_level(colors, [0, 1]))
	assert_eq(plain.state_key(), plain_copy.state_key())
