extends TestCase

## Zen kipi: veri, deterministik ve çözülebilir tahtalar, sakin kurtarma (sonsuz döngü yok),
## oturum sayacı. Oyun sahnesi bağlantısı tools/map_probe.gd'de sınanır.

const SEEDS: int = 14
const LOSS_SEARCH_TRIES: int = 400
const SOLVE_BUDGET: int = 60000

var _progress: Node = null
var _persist_before: bool = true


func before_each() -> void:
	_progress = autoload_node("Progress")
	_persist_before = bool(_progress.get("persist"))
	_progress.set("persist", false)
	AnalyticsLog.echo = false
	AnalyticsLog.clear()
	LevelPrefetch.enabled = false


func after_each() -> void:
	_progress.set("persist", _persist_before)
	LevelPrefetch.enabled = true
	ZenMode.pending = false


func test_config_and_unlock() -> void:
	assert_eq(ZenMode.unlock_level(), 10)
	assert_false(ZenMode.is_unlocked(9))
	assert_true(ZenMode.is_unlocked(10))


func test_ramp_widens_with_progress() -> void:
	var cfg: Dictionary = ZenMode.config()
	assert_eq(ZenMode.bases_for(0, cfg), [4, 5] as Array[int])
	assert_true(ZenMode.bases_for(3, cfg).has(6))
	assert_true(ZenMode.bases_for(50, cfg).has(7))
	assert_eq(ZenMode.bases_for(0, {}), ZenMode.FALLBACK_BASES, "bozuk veri yedeğe düşer")


func test_boards_are_deterministic_gentle_and_solvable() -> void:
	var cfg: Dictionary = ZenMode.config()
	var seen: Dictionary = {}
	for variant: int in range(1, SEEDS + 1):
		var step: int = variant
		var level: Dictionary = ZenMode.build_level(variant, step, cfg)
		var again: Dictionary = ZenMode.build_level(variant, step, cfg)
		assert_eq(var_to_str(level), var_to_str(again), "aynı tohum aynı tahta")
		seen[var_to_str(level)] = true
		assert_true(LevelSolver.is_solvable(level, SOLVE_BUDGET), "çözülebilir: %d" % variant)
		assert_true(bool(level.get(ZenMode.ZEN_FLAG, false)))
		assert_false(bool(level.get("hard", true)))
		assert_false(level.has("mode"), "hamle sınırı/patron/kısa askı yok")
		assert_eq(int(level["rack_slots"]), 5)
		for item: Dictionary in level["items"] as Array[Dictionary]:
			assert_true(int(item["layer"]) <= 1, "sığ katman")
			for key: String in ["sheet", "lock", "sock", "dye", "wet", "mystery"]:
				assert_false(item.has(key), "zen'de engel yok: %s" % key)
	assert_true(seen.size() >= SEEDS - 2, "tahtalar birbirinden farklı olmalı")


func test_prefetch_job_matches_direct_build() -> void:
	var cfg: Dictionary = ZenMode.config()
	LevelPrefetch.enabled = true
	var key: String = ZenMode.level_key(777)
	LevelPrefetch.request(key, ZenMode.build_level.bind(777, 2, cfg))
	var fetched: Dictionary = LevelPrefetch.take(key, ZenMode.build_level.bind(777, 2, cfg))
	assert_eq(var_to_str(fetched), var_to_str(ZenMode.build_level(777, 2, cfg)), "arka plan sonucu birebir aynı")
	LevelPrefetch.drain()


## Rastgele oynayarak KAYBEDEN bir tahta durumu bulur (askı 1 → kolay): kurtarmayı sınamak için.
func _lost_board(level: Dictionary, taps: Array[int], rng: RandomNumberGenerator) -> LaundryBoard:
	for _try: int in range(LOSS_SEARCH_TRIES):
		taps.clear()
		var board: LaundryBoard = LaundryBoard.new(level)
		board.enable_history()
		while not board.is_over():
			var open: Array[int] = []
			for id: int in board.item_ids():
				if board.is_on_line(id) and board.blockers_of(id).is_empty():
					open.append(id)
			if open.is_empty():
				break
			var pick: int = open[rng.randi_range(0, open.size() - 1)]
			var before: int = board.history_size()
			board.tap(pick)
			if board.history_size() == before + 1:
				taps.append(pick)
		if board.is_lost():
			return board
	return null


func test_rescue_never_leaves_the_board_lost() -> void:
	var cfg: Dictionary = ZenMode.config().duplicate(true)
	cfg[ZenMode.KEY_RACK] = 1
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 424242
	var rescued: int = 0
	for variant: int in range(1, 13):
		var level: Dictionary = ZenMode.build_level(variant, 9, cfg)
		var taps: Array[int] = []
		var board: LaundryBoard = _lost_board(level, taps, rng)
		if board == null:
			continue
		var info: Dictionary = ZenMode.rescue(level, taps, board, 0, cfg)
		rescued += 1
		assert_false(board.is_lost(), "kurtarma sonrası kayıp kalmamalı")
		assert_true(int(info["undone"]) >= 1 or bool(info["slot"]), "geri alındı ya da askı eklendi")
		assert_eq(board.history_size(), taps.size(), "dokunuş listesi geçmişle eş kalmalı")
		if int(info["hint"]) >= 0:
			assert_true(board.is_on_line(int(info["hint"])), "ipucu ipte bir çamaşır")
	assert_true(rescued >= 3, "en az birkaç kayıp durumu kurtarılmalı (%d)" % rescued)


func test_rescue_cap_adds_a_slot_instead_of_undo() -> void:
	var cfg: Dictionary = ZenMode.config().duplicate(true)
	cfg[ZenMode.KEY_RACK] = 1
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 99
	var level: Dictionary = {}
	var taps: Array[int] = []
	var board: LaundryBoard = null
	for variant: int in range(1, 13):
		level = ZenMode.build_level(variant, 9, cfg)
		board = _lost_board(level, taps, rng)
		if board != null:
			break
	assert_not_null(board, "kayıp durumu bulunmalı")
	if board == null:
		return
	var slots: int = board.rack_slots()
	var max_rescues: int = int((cfg[ZenMode.KEY_RESCUE] as Dictionary)["max_per_board"])
	var info: Dictionary = ZenMode.rescue(level, taps, board, max_rescues, cfg)
	assert_true(bool(info["slot"]), "limit aşılınca geri alma yerine askı eklenir")
	assert_eq(int(info["undone"]), 0)
	assert_eq(board.rack_slots(), slots + 1)
	assert_false(board.is_lost())


func test_session_counts_and_is_deterministic() -> void:
	var cfg: Dictionary = ZenMode.config()
	var first: ZenSession = ZenSession.new(cfg, 12345)
	var second: ZenSession = ZenSession.new(cfg, 12345)
	for _index: int in range(3):
		assert_eq(var_to_str(first.next_level()), var_to_str(second.next_level()), "aynı tohum aynı dizi")
	assert_eq(first.step, 3)
	var before: int = ZenMode.total_cleared()
	assert_eq(first.on_cleared(), 1)
	assert_eq(first.on_cleared(), 2)
	assert_eq(ZenMode.total_cleared(), before + 2, "kalıcı sayaç artar")
	assert_eq(AnalyticsLog.count(ZenMode.EVENT_CLEAR), 2)
	_progress.call("set_module_value", ZenMode.MODULE, ZenMode.KEY_CLEARED, before)


func test_pending_handoff_is_single_use() -> void:
	assert_true(ZenMode.take_pending() == null, "devir yokken oturum açılmaz")
	ZenMode.request_start()
	assert_eq(AnalyticsLog.count(ZenMode.EVENT_START), 1)
	var session: ZenSession = ZenMode.take_pending()
	assert_not_null(session)
	assert_true(ZenMode.take_pending() == null, "tek seferlik")
