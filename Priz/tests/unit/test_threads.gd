extends TestCase
## İş parçacığı dumanı: üretim + çözüm WorkerThreadPool üzerinde ana iş parçacığıyla aynı sonucu verir.

const LEVELS: Array[int] = [8, 23, 52, 60, 77, 95]

var content: PrizContent
var _results: Array = []


func before_each() -> void:
	if content == null:
		content = PrizContent.load_default()


func _job(index: int) -> void:
	var n: int = LEVELS[index]
	var level: PrizLevel = PrizGenerator.new(content).generate(n)
	if level == null:
		_results[index] = "null"
		return
	var res: PrizSolveResult = PrizSolver.new().count_solutions(level, content.registry, 1000)
	var board: PrizBoard = PrizBoard.new(level, content.registry)
	var hint: PrizHint = PrizSolver.new().hint(board)
	_results[index] = "%s|%d|%s|%s" % [level.to_json(), res.count, hint.device_id, hint.socket_id]


func test_worker_pool_matches_main_thread() -> void:
	_results.clear()
	_results.resize(LEVELS.size())
	var group: int = WorkerThreadPool.add_group_task(_job, LEVELS.size(), -1, true)
	WorkerThreadPool.wait_for_group_task_completion(group)
	var threaded: Array = _results.duplicate()
	_results.clear()
	_results.resize(LEVELS.size())
	for i: int in LEVELS.size():
		_job(i)
	for i: int in LEVELS.size():
		assert_true(str(threaded[i]) != "null", "seviye %d iş parçacığında üretilemedi" % LEVELS[i])
		assert_true(str(threaded[i]) == str(_results[i]), "seviye %d farklı" % LEVELS[i])
