extends SceneTree

## Ustalık eşiklerini ayarlamak için ölçüm: her seviyede rastgele "sepet-öncelikli" oyuncular
## ve çözücü yolu oynatılıp askı kullanımı dağılımı yazılır (geliştirme aracı, test değildir).
##   godot --headless --path . -s res://tools/mastery_calib.gd -- --levels=1-60 --trials=300

var _window: int = RunStats.DEFAULT_WINDOW_TAPS


func _initialize() -> void:
	var first: int = 1
	var last: int = 60
	var trials: int = 300
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--levels="):
			var parts: PackedStringArray = arg.split("=")[1].split("-")
			first = int(parts[0])
			last = int(parts[1])
		elif arg.begins_with("--window="):
			_window = int(arg.split("=")[1])
		elif arg.begins_with("--trials="):
			trials = int(arg.split("=")[1])
	seed(7)
	for number: int in range(first, last + 1):
		var level: Dictionary = LevelGenerator.generate(number)
		var items: int = (level["items"] as Array).size()
		var totals: Array[int] = []
		var chains: Array[int] = []
		var solver: RunStats = _play_path(level, LevelSolver.solve(level, 200000))
		for _t: int in range(trials):
			var stats: RunStats = _play_greedy(level)
			if stats != null:
				totals.append(stats.rack_total * 100 + stats.rack_max)
				chains.append(stats.best_chain)
		totals.sort()
		chains.sort()
		var count: int = totals.size()
		if count == 0:
			print("L%d items=%d no win" % [number, items])
			continue
		print("L%02d items=%2d slots=%d | solver rack=%d max=%d chain=%d | greedy rackTotal min=%d p25=%d med=%d p75=%d | maxfill min=%d med=%d | chain med=%d max=%d" % [
			number, items, int(level.get("rack_slots", 4)),
			solver.rack_total, solver.rack_max, solver.best_chain,
			totals[0] / 100, totals[count / 4] / 100, totals[count / 2] / 100, totals[count * 3 / 4] / 100,
			totals[0] % 100, totals[count / 2] % 100, chains[count / 2], chains[count - 1]])
	quit(0)


func _play_path(level: Dictionary, path: Array[int]) -> RunStats:
	var board: LaundryBoard = LaundryBoard.new(level)
	var stats: RunStats = RunStats.new(_window)
	for id: int in path:
		stats.record_tap(board.tap(id))
	return stats


func _play_greedy(level: Dictionary) -> RunStats:
	var board: LaundryBoard = LaundryBoard.new(level)
	var stats: RunStats = RunStats.new(_window)
	var guard: int = 0
	while not board.is_over() and guard < 400:
		guard += 1
		var open: Array[int] = board.open_ids()
		# Islak çamaşır sıkılır (açık ve kilitsiz).
		var basket_moves: Array[int] = []
		for id: int in open:
			if board.is_wet(id):
				basket_moves.append(id)
		if basket_moves.is_empty():
			for id: int in open:
				if _goes_to_basket(board, id):
					basket_moves.append(id)
		var pick: int = -1
		if not basket_moves.is_empty():
			pick = basket_moves[randi() % basket_moves.size()]
		elif not open.is_empty():
			pick = open[randi() % open.size()]
		else:
			return null
		stats.record_tap(board.tap(pick))
	return stats if board.is_won() else null


func _goes_to_basket(board: LaundryBoard, id: int) -> bool:
	for basket: Dictionary in board.baskets():
		if not basket.is_empty() and int(basket["color"]) == board.color_of(id) and int(basket["count"]) < LaundryBoard.BASKET_CAPACITY:
			return true
	return false
