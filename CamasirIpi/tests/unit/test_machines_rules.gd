extends TestCase

## Makineler ve misafirler (LaundryBoard son bölümü): çamaşır/kurutma makinesi, zaman atlama,
## türlü sepet, kuş, yağmur, kedi; geri al ve çözücü (ücretsiz eylemler) desteği.

const WASHER: Dictionary = {"capacity": 2, "moves": 3}
const DRYER: Dictionary = {"capacity": 2, "moves": 2}


## Tek ipte yan yana parçalar (hepsi açık). `extra`: parça başına ek alanlar (kimlik -> sözlük).
func _flat(colors: Array[int], queue: Array[int], extra: Dictionary = {}, active: int = 2) -> Dictionary:
	var items: Array[Dictionary] = []
	for index: int in range(colors.size()):
		var item: Dictionary = {"id": index, "color": colors[index], "blockers": [], "line": 0, "layer": 0,
			"slot": float(index), "kind": 0}
		item.merge(extra.get(index, {}) as Dictionary, true)
		items.append(item)
	return {"items": items, "queue": queue, "active_baskets": active, "rack_slots": 4}


func _types(events: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for event: Dictionary in events:
		result.append(String(event["type"]))
	return result


func test_dirty_goes_to_washer_and_exits_clean_after_moves() -> void:
	var level: Dictionary = _flat([0, 0, 0, 1, 1, 1], [0, 1], {0: {"dirty": true}})
	level["washer"] = WASHER
	var board: LaundryBoard = LaundryBoard.new(level)
	var events: Array[Dictionary] = board.tap(0)
	assert_eq(String(events[0]["type"]), LaundryBoard.EVENT_TO_MACHINE)
	assert_eq(board.moves(), 1, "makineye koymak bir hamledir")
	assert_eq(board.machine_slot(LaundryBoard.MACHINE_WASHER, 0), Vector2i(0, 3))
	board.tap(1)
	board.tap(2)
	assert_eq(board.machine_slot(LaundryBoard.MACHINE_WASHER, 0).y, 1, "her sonraki hamlede bir azalır")
	var exit: Array[Dictionary] = board.tap(3)
	var types: Array[String] = _types(exit)
	assert_true(types.has(LaundryBoard.EVENT_MACHINE_READY))
	var out: int = types.find(LaundryBoard.EVENT_MACHINE_OUT)
	assert_true(out >= 0, "üçüncü hamlede çıkar")
	assert_eq(types[out + 1], LaundryBoard.EVENT_TO_BASKET, "temiz parça uygun sepete gider")
	assert_false(board.is_dirty(0))
	board.tap(4)
	board.tap(5)
	assert_true(board.is_won())


func test_dirty_never_goes_to_rack_or_basket_directly_and_full_machine_refuses() -> void:
	var level: Dictionary = _flat([0, 0, 0, 1, 1, 1], [0, 1], {0: {"dirty": true}, 1: {"dirty": true},
		2: {"dirty": true}})
	level["washer"] = WASHER
	var board: LaundryBoard = LaundryBoard.new(level)
	board.tap(0)
	board.tap(1)
	assert_eq(board.rack_count(), 0)
	var refused: Array[Dictionary] = board.tap(2)
	assert_eq(String(refused[0]["type"]), LaundryBoard.EVENT_MACHINE_FULL, "dolu makine reddeder")
	assert_eq(board.moves(), 2, "red hamle sayılmaz")
	assert_true(board.is_on_line(2))


func test_time_skip_finishes_machines_when_no_tap_is_left() -> void:
	# İp boşaldı ama makinede çamaşır var: dokunacak bir şey kalmadığından makine hemen bitirir.
	var level: Dictionary = _flat([0, 0, 0], [0], {0: {"dirty": true}}, 1)
	level["washer"] = WASHER
	var board: LaundryBoard = LaundryBoard.new(level)
	board.tap(0)
	board.tap(1)
	var events: Array[Dictionary] = board.tap(2)
	var types: Array[String] = _types(events)
	assert_true(types.has(LaundryBoard.EVENT_MACHINE_RUSH), "zaman atlandı")
	assert_true(types.has(LaundryBoard.EVENT_MACHINE_OUT))
	assert_true(board.is_won(), "kilitlenmeden kazanılır")
	assert_eq(board.moves(), 3)


func test_rack_full_with_waiting_machine_garment_loses_fairly() -> void:
	# Makinedeki parça bitti ama ne sepet ne askı var ve dokunacak parça yok: kayıp (sessiz kilit yok).
	var level: Dictionary = _flat([0, 1, 1], [2, 1, 0], {0: {"dirty": true}}, 1)
	level["washer"] = {"capacity": 2, "moves": 1}
	level["rack_slots"] = 1
	var board: LaundryBoard = LaundryBoard.new(level)
	board.tap(0)
	assert_false(board.is_over())
	board.tap(1)
	assert_true(board.is_lost(), "ilerleme yoksa kayıp ilan edilir")
	assert_eq(board.lose_reason(), LaundryBoard.LOSE_RACK)


func test_dryer_replaces_wring_only_where_present() -> void:
	var plain: Dictionary = _flat([0, 0, 0], [0], {0: {"wet": true}}, 1)
	var old_rule: LaundryBoard = LaundryBoard.new(plain)
	assert_eq(String(old_rule.tap(0)[0]["type"]), LaundryBoard.EVENT_WRING, "kurutucusuz: iki dokunuş")
	var dried: Dictionary = plain.duplicate(true)
	dried["dryer"] = DRYER
	var board: LaundryBoard = LaundryBoard.new(dried)
	var events: Array[Dictionary] = board.tap(0)
	assert_eq(String(events[0]["type"]), LaundryBoard.EVENT_TO_MACHINE)
	assert_eq(int(events[0]["machine"]), LaundryBoard.MACHINE_DRYER)
	board.tap(1)
	board.tap(2)
	assert_true(board.is_won(), "kurutucu iki hamlede (ya da ip boşalınca) bitirir")
	assert_false(board.is_wet(0))


func test_upgrades_only_change_player_board() -> void:
	var level: Dictionary = _flat([0, 0, 0], [0], {0: {"dirty": true}, 1: {"dirty": true}, 2: {"dirty": true}}, 1)
	level["washer"] = WASHER
	var base: LaundryBoard = LaundryBoard.new(level)
	assert_eq(base.machine_capacity(LaundryBoard.MACHINE_WASHER), 2)
	assert_eq(base.machine_moves(LaundryBoard.MACHINE_WASHER), 3)
	var boosted: LaundryBoard = LaundryBoard.new(level, {"washer_capacity": 3, "washer_moves": 1})
	assert_eq(boosted.machine_capacity(LaundryBoard.MACHINE_WASHER), 3)
	assert_eq(boosted.machine_moves(LaundryBoard.MACHINE_WASHER), 1)
	boosted.tap(0)
	boosted.tap(1)
	boosted.tap(2)
	assert_true(boosted.is_won())
	var from_level: Dictionary = level.duplicate(true)
	from_level["upgrades"] = {"washer_capacity": 4}
	assert_eq(LaundryBoard.new(from_level).machine_capacity(LaundryBoard.MACHINE_WASHER), 4)


func test_typed_basket_takes_only_its_kind() -> void:
	var level: Dictionary = _flat([0, 0, 0, 0, 0, 0], [0, 0], {0: {"kind": 1}, 1: {"kind": 1}, 2: {"kind": 1}}, 1)
	level["typed"] = [[0, 1]]
	var board: LaundryBoard = LaundryBoard.new(level)
	assert_eq(board.basket_kind(0), 1)
	var events: Array[Dictionary] = board.tap(3)
	assert_eq(String(events[0]["type"]), LaundryBoard.EVENT_TO_RACK, "başka tür askıya")
	board.tap(0)
	board.tap(1)
	events = board.tap(2)
	assert_true(_types(events).has(LaundryBoard.EVENT_BASKET_DONE))
	assert_true(_types(events).has(LaundryBoard.EVENT_RACK_TO_BASKET), "sıradaki türsüz sepet askıdakini alır")
	board.tap(4)
	board.tap(5)
	assert_true(board.is_won())


func test_bird_lands_stains_unless_shooed_and_shoo_is_free() -> void:
	var level: Dictionary = _flat([0, 0, 0, 1, 1, 1], [0, 1])
	level["washer"] = WASHER
	level["birds"] = {"every": 3, "targets": [5]}
	var board: LaundryBoard = LaundryBoard.new(level)
	board.enable_history()
	board.tap(0)
	assert_eq(board.bird_left(), 2)
	board.tap(1)
	var landed: Array[Dictionary] = board.tap(2)
	assert_true(_types(landed).has(LaundryBoard.EVENT_BIRD_LAND))
	assert_eq(board.bird_on(), 5)
	var moves: int = board.moves()
	var history: int = board.history_size()
	var shoo: Array[Dictionary] = board.tap(LaundryBoard.TAP_BIRD)
	assert_eq(String(shoo[0]["type"]), LaundryBoard.EVENT_BIRD_SHOO)
	assert_eq(board.moves(), moves, "kovalamak hamle değildir")
	assert_eq(board.history_size(), history, "geçmişe yazılmaz")
	assert_eq(board.bird_on(), LaundryBoard.EMPTY)
	# Kovalanmasa: iki hamle sonra leke -> çamurlu.
	var lazy: LaundryBoard = LaundryBoard.new(level)
	for id: int in [0, 1, 2, 3]:
		lazy.tap(id)
	var stained: Array[Dictionary] = lazy.tap(4)
	assert_true(_types(stained).has(LaundryBoard.EVENT_BIRD_STAIN))
	assert_true(lazy.is_dirty(5))
	assert_true(lazy.is_bird_mess(5))
	assert_eq(lazy.machine_for(5), LaundryBoard.MACHINE_WASHER)


func test_bird_flies_away_when_its_garment_is_taken() -> void:
	var level: Dictionary = _flat([0, 0, 0, 1, 1, 1], [0, 1])
	level["washer"] = WASHER
	level["birds"] = {"every": 3, "targets": [3]}
	var board: LaundryBoard = LaundryBoard.new(level)
	board.tap(0)
	board.tap(1)
	board.tap(2)
	assert_eq(board.bird_on(), 3)
	var events: Array[Dictionary] = board.tap(3)
	assert_true(_types(events).has(LaundryBoard.EVENT_BIRD_AWAY))
	assert_false(board.is_dirty(3))


func test_rain_soaks_open_garments_on_its_line_only() -> void:
	var level: Dictionary = _flat([0, 0, 0, 1, 1, 1], [0, 1])
	(level["items"] as Array[Dictionary])[5]["blockers"] = [4]
	level["rain"] = {"every": 2, "steps": [[3, 4, 5]]}
	var board: LaundryBoard = LaundryBoard.new(level)
	board.enable_history()
	assert_eq(board.rain_left(), 2)
	assert_eq(board.rain_next_line(), 0)
	board.tap(0)
	var events: Array[Dictionary] = board.tap(3)
	var rain: Dictionary = events[_types(events).find(LaundryBoard.EVENT_RAIN)]
	var soaked: Array = rain["ids"] as Array
	assert_true(soaked.size() == 1 and int(soaked[0]) == 4, "alınan ve örtülü parça ıslanmaz")
	assert_true(board.is_wet(4))
	assert_false(board.is_wet(5))
	assert_true(board.undo())
	assert_false(board.is_wet(4), "geri al yağmuru da geri alır")
	assert_eq(board.rain_left(), 1)


func test_cat_blocks_basket_until_petted_or_moves_pass() -> void:
	var level: Dictionary = _flat([0, 0, 0, 1, 1, 1], [0, 1])
	level["cat"] = {"every": 4, "baskets": [0]}
	var board: LaundryBoard = LaundryBoard.new(level)
	board.tap(3)
	board.tap(4)
	board.tap(5)
	var landed: Array[Dictionary] = board.tap(0)
	assert_true(_types(landed).has(LaundryBoard.EVENT_CAT_LAND))
	assert_eq(board.cat_at(), 0)
	var blocked: Array[Dictionary] = board.tap(1)
	assert_eq(String(blocked[0]["type"]), LaundryBoard.EVENT_TO_RACK, "kedili sepet almaz")
	var pet: Array[Dictionary] = board.tap(LaundryBoard.TAP_CAT)
	assert_eq(String(pet[0]["type"]), LaundryBoard.EVENT_CAT_PET)
	assert_true(_types(pet).has(LaundryBoard.EVENT_RACK_TO_BASKET), "sevince askıdaki sepete geçer")
	assert_eq(board.moves(), 5, "sevmek hamle değildir")
	board.tap(2)
	assert_true(board.is_won())
	# Sevilmezse CAT_STAY_MOVES hamle sonra kendiliğinden kalkar.
	var napping: Dictionary = _flat([0, 0, 0, 1, 1, 1, 2, 2, 2], [0, 1, 2])
	napping["cat"] = {"every": 4, "baskets": [1]}
	var lazy: LaundryBoard = LaundryBoard.new(napping)
	for id: int in [0, 1, 2, 6]:
		lazy.tap(id)
	assert_eq(lazy.cat_at(), 1)
	for id: int in [7, 8]:
		lazy.tap(id)
	var gone: Array[Dictionary] = lazy.tap(3)
	assert_true(_types(gone).has(LaundryBoard.EVENT_CAT_LEAVE))


func test_state_key_and_undo_cover_machine_state() -> void:
	var level: Dictionary = _flat([0, 0, 0, 1, 1, 1], [0, 1], {0: {"dirty": true}})
	level["washer"] = WASHER
	var board: LaundryBoard = LaundryBoard.new(level)
	board.enable_history()
	var start: PackedInt32Array = board.state_key()
	board.tap(0)
	assert_true(board.state_key() != start)
	assert_true(board.undo())
	assert_eq(board.state_key(), start, "geri al makineyi boşaltır")
	assert_eq(board.machine_slot(LaundryBoard.MACHINE_WASHER, 0).x, LaundryBoard.EMPTY)
	assert_true(board.is_dirty(0))


func test_solver_shoos_and_pets_for_free_and_paths_replay() -> void:
	var level: Dictionary = _flat([0, 0, 0, 1, 1, 1, 2, 2, 2], [0, 1, 2])
	level["washer"] = WASHER
	level["birds"] = {"every": 3, "targets": [8]}
	level["cat"] = {"every": 4, "baskets": [1]}
	var path: Array[int] = LevelSolver.solve(level)
	assert_false(path.is_empty())
	assert_true(path.has(LaundryBoard.TAP_BIRD), "çözücü kuşu kovalar")
	var board: LaundryBoard = LaundryBoard.new(level)
	for id: int in path:
		board.tap(id)
	assert_true(board.is_won(), "yol (ücretsiz dokunuşlarla) kazandırır")
	assert_true(LevelSolver.is_solvable(level, LevelSolver.DEFAULT_NODE_LIMIT, false), "yardımsız da çözülür")
