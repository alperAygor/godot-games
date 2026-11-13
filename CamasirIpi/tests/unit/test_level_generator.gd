extends TestCase

## Üretilen seviyeler: deterministik, 3'ün katı, kuyrukla birebir ve ÇÖZÜLEBİLİR.

const CHECKED_LEVELS: int = 80


func test_same_level_is_deterministic() -> void:
	assert_eq(LevelGenerator.generate(12), LevelGenerator.generate(12))


func test_counts_match_queue() -> void:
	for level: int in range(1, CHECKED_LEVELS + 1):
		var data: Dictionary = LevelGenerator.generate(level)
		var items: Array = data["items"] as Array
		var queue: Array = data["queue"] as Array
		assert_eq(items.size() % 3, 0, "seviye %d: parça sayısı 3'ün katı" % level)
		var per_color: Dictionary = {}
		for entry: Variant in items:
			var color: int = int((entry as Dictionary)["color"])
			per_color[color] = int(per_color.get(color, 0)) + 1
		var from_queue: Dictionary = {}
		for color: Variant in queue:
			from_queue[int(color)] = int(from_queue.get(int(color), 0)) + 3
		assert_eq(per_color, from_queue, "seviye %d: renk sayıları kuyrukla eşleşmeli" % level)


func test_every_level_is_solvable() -> void:
	for level: int in range(1, CHECKED_LEVELS + 1):
		var data: Dictionary = LevelGenerator.generate(level)
		var path: Array[int] = LevelSolver.solve(data, 200000)
		assert_false(path.is_empty(), "seviye %d çözülebilir olmalı" % level)
		var board: LaundryBoard = LaundryBoard.new(data)
		for id: int in path:
			board.tap(id)
		assert_true(board.is_won(), "seviye %d: çözüm yolu kazandırmalı" % level)


func test_first_level_is_tiny() -> void:
	var data: Dictionary = LevelGenerator.generate(1)
	assert_eq((data["items"] as Array).size(), 6)
	assert_eq(int(data["active_baskets"]), 2)


func test_difficulty_grows() -> void:
	var early: int = (LevelGenerator.generate(4)["items"] as Array).size()
	var late: int = (LevelGenerator.generate(40)["items"] as Array).size()
	assert_greater(late, early)


func test_obstacles_unlock_by_level() -> void:
	assert_eq(_count(LevelGenerator.generate(7), "wet"), 0)
	assert_eq(_count(LevelGenerator.generate(LevelGenerator.WET_FROM_LEVEL), "wet"), 1)
	assert_eq(_count(LevelGenerator.generate(LevelGenerator.WET_FROM_LEVEL), "mystery"), 0)
	assert_greater(_count(LevelGenerator.generate(LevelGenerator.MYSTERY_FROM_LEVEL), "mystery"), 0)
	assert_eq(_count(LevelGenerator.generate(LevelGenerator.MYSTERY_FROM_LEVEL), "wet"), 0,
		"tanıtım seviyesinde yalnız yeni engel olmalı")
	assert_greater(_count(LevelGenerator.generate(30), "wet"), 1)


func _count(level: Dictionary, key: String) -> int:
	var total: int = 0
	for entry: Variant in level["items"] as Array:
		if (entry as Dictionary).has(key):
			total += 1
	return total

