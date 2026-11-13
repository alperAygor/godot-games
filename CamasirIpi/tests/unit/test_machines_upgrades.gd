extends TestCase

## Makine yükseltme tablosu (MachineRules / data/machines.json): seviye 0 tahtanın yükseltmesiz
## değerleriyle aynı, yükseltmeler yalnız kolaylaştırır, bedeller artar.


func test_level_zero_matches_board_defaults() -> void:
	assert_eq(MachineRules.value(MachineRules.WASHER, MachineRules.CAPACITY, 0), LaundryBoard.WASHER_CAPACITY)
	assert_eq(MachineRules.value(MachineRules.WASHER, MachineRules.MOVES, 0), LaundryBoard.WASHER_MOVES)
	assert_eq(MachineRules.value(MachineRules.DRYER, MachineRules.CAPACITY, 0), LaundryBoard.DRYER_CAPACITY)
	assert_eq(MachineRules.value(MachineRules.DRYER, MachineRules.MOVES, 0), LaundryBoard.DRYER_MOVES)


func test_tracks_only_get_easier_and_costs_escalate() -> void:
	for machine: String in MachineRules.MACHINES:
		for track: String in MachineRules.TRACKS:
			var top: int = MachineRules.max_level(machine, track)
			assert_greater(top, 0, "%s %s yükseltilebilir" % [machine, track])
			var last_cost: int = 0
			for level: int in range(top):
				var now: int = MachineRules.value(machine, track, level)
				var next: int = MachineRules.value(machine, track, level + 1)
				if track == MachineRules.CAPACITY:
					assert_greater(next, now, "kapasite artar")
				else:
					assert_true(next < now and next >= LaundryBoard.MACHINE_MIN_MOVES, "süre kısalır")
				var price: int = MachineRules.cost(machine, track, level)
				assert_greater(price, last_cost, "bedel artar")
				last_cost = price
			assert_eq(MachineRules.cost(machine, track, top), MachineRules.MAXED)
			assert_true(MachineRules.value(machine, MachineRules.CAPACITY, top) <= LaundryBoard.MACHINE_MAX_CAPACITY)


func test_board_params_feed_the_board() -> void:
	var params: Dictionary = MachineRules.board_params({"washer_capacity": 1, "dryer_moves": 1})
	assert_eq(int(params["washer_capacity"]), 3)
	assert_eq(int(params["washer_moves"]), LaundryBoard.WASHER_MOVES)
	assert_eq(int(params["dryer_moves"]), 1)
	var level: Dictionary = {"items": [{"id": 0, "color": 0, "blockers": [], "wet": true}], "queue": [0],
		"active_baskets": 1, "dryer": {"capacity": 2, "moves": 2}}
	var board: LaundryBoard = LaundryBoard.new(level, params)
	assert_eq(board.machine_moves(LaundryBoard.MACHINE_DRYER), 1)
	assert_eq(MachineRules.unlock_level(MachineRules.DRYER), LevelGenerator.DRYER_FROM_LEVEL)
