class_name ZenMode
extends RefCounted

## Zen kipi: kaybetme yok, süre yok, ödül yok; sakin, bitmeyen tahtalar. Saf mantık burada:
## veri okuma, tahta üretimi (iş parçacığı güvenli), kurtarma kararı. Oyun sahnesi bağlantısı
## game.gd'deki [ZEN] kancalarında; görünüm ZenView/ZenCard'da.
## Ana ilerlemeye (seviye, seri, jeton, yıldız, günlük) HİÇ dokunulmaz; yalnız `zen` modülünde
## "temizlenen tahta" sayacı tutulur.

const DATA_PATH: String = "res://data/zen.json"
const MODULE: String = "zen"
const KEY_CLEARED: String = "cleared"
const KEY_UNLOCK: String = "unlock_level"
const KEY_RACK: String = "rack_slots"
const KEY_PALETTE: String = "palette"
const KEY_SALT: String = "seed_salt"
const KEY_SEED_MOD: String = "session_seed_mod"
const KEY_RAMP: String = "ramp"
const KEY_RESCUE: String = "rescue"
const KEY_FROM: String = "from"
const KEY_BASES: String = "bases"
const FALLBACK_UNLOCK: int = 10
const FALLBACK_RACK: int = 5
const FALLBACK_PALETTE: int = 7
const FALLBACK_SALT: int = 104717
const FALLBACK_SEED_MOD: int = 100000
const FALLBACK_BASES: Array[int] = [4, 5]
const FALLBACK_MAX_UNDO: int = 8
const FALLBACK_NODE_LIMIT: int = 6000
const FALLBACK_MAX_RESCUES: int = 3
const LEVEL_KEY: String = "zen:%d"
## Çözücü bütçesi: tahtalar küçük, bu bol yeter.
const ZEN_FLAG: String = "zen"
const EVENT_START: String = "zen_start"
const EVENT_CLEAR: String = "zen_level_clear"
const EVENT_EXIT: String = "zen_exit"

## Menüden oyuna tek seferlik devir (DailyPuzzle.pending_level ile aynı desen).
static var pending: bool = false
## Testler/prob: oturum tohumunu sabitler (-1 = zamandan türet). Tek seferlik.
static var pending_seed: int = -1
static var _config: Dictionary = {}


static func config() -> Dictionary:
	if not _config.is_empty():
		return _config
	var parsed: Variant = null
	if FileAccess.file_exists(DATA_PATH):
		parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	_config = parsed as Dictionary if parsed is Dictionary else {"_fallback": true}
	return _config


static func unlock_level() -> int:
	return ProgressData.to_count(config().get(KEY_UNLOCK), FALLBACK_UNLOCK)


static func is_unlocked(player_level: int) -> bool:
	return player_level >= unlock_level()


## Menü/harita: bir sonraki oyun sahnesi zen oturumu açsın.
static func request_start() -> void:
	pending = true
	AnalyticsLog.record(EVENT_START, {})


## Oyun sahnesi açılırken çağırır: bekleyen devir varsa yeni oturum, yoksa null (tek seferlik).
static func take_pending() -> ZenSession:
	if not pending:
		return null
	pending = false
	var seed_value: int = pending_seed
	pending_seed = -1
	return ZenSession.new(config(), seed_value)


## Kalıcı sayaç: şimdiye dek temizlenen zen tahtası.
static func total_cleared() -> int:
	return int(_progress_value(KEY_CLEARED))


static func add_cleared() -> int:
	var total: int = total_cleared() + 1
	var progress: Node = _progress()
	if progress != null:
		progress.call("set_module_value", MODULE, KEY_CLEARED, total)
	return total


static func level_key(variant_seed: int) -> String:
	return LEVEL_KEY % variant_seed


## Oturumdaki `step`. tahta için taban seviye havuzu (rampa).
static func bases_for(step: int, cfg: Dictionary) -> Array[int]:
	var pool: Array[int] = FALLBACK_BASES.duplicate()
	var ramp: Variant = cfg.get(KEY_RAMP)
	if not (ramp is Array):
		return pool
	for entry: Variant in ramp as Array:
		if not (entry is Dictionary) or step < int((entry as Dictionary).get(KEY_FROM, 0)):
			continue
		var raw: Variant = (entry as Dictionary).get(KEY_BASES)
		if raw is Array and not (raw as Array).is_empty():
			pool.clear()
			for value: Variant in raw as Array:
				pool.append(int(value))
	return pool


## Tahta üretimi: SAF ve iş parçacığı güvenli (yalnız yerel RNG + LevelGenerator; düğüm/autoload
## yok). Aynı (variant_seed, step, cfg) her zaman aynı tahtayı verir.
static func build_level(variant_seed: int, step: int, cfg: Dictionary) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = maxi(variant_seed, 1) * int(cfg.get(KEY_SALT, FALLBACK_SALT))
	var pool: Array[int] = bases_for(step, cfg)
	var base: int = pool[rng.randi_range(0, pool.size() - 1)]
	var level: Dictionary = LevelGenerator.generate(base)
	_relabel_colors(level, rng, ProgressData.to_count(cfg.get(KEY_PALETTE), FALLBACK_PALETTE))
	_mirror_and_reorder(level, rng)
	level["rack_slots"] = maxi(ProgressData.to_count(cfg.get(KEY_RACK), FALLBACK_RACK), 1)
	level["hard"] = false
	level[ZEN_FLAG] = true
	return level


## Renkler bire bir eşlemeyle (bijection) paletin rastgele bir alt kümesine taşınır: kural aynı,
## görünüm her tahtada farklı.
static func _relabel_colors(level: Dictionary, rng: RandomNumberGenerator, palette: int) -> void:
	var used: int = 0
	for color: Variant in level["queue"] as Array:
		used = maxi(used, int(color) + 1)
	for entry: Dictionary in level["items"] as Array[Dictionary]:
		used = maxi(used, int(entry["color"]) + 1)
	var targets: Array[int] = []
	for index: int in range(maxi(palette, used)):
		targets.append(index)
	for index: int in range(targets.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var held: int = targets[index]
		targets[index] = targets[other]
		targets[other] = held
	var queue: Array[int] = []
	for color: Variant in level["queue"] as Array:
		queue.append(targets[int(color)])
	level["queue"] = queue
	for entry: Dictionary in level["items"] as Array[Dictionary]:
		entry["color"] = targets[int(entry["color"])]


## İp sırası karışır, istenirse sağ-sol ayna: kapatma ilişkileri değişmez, çözülebilirlik aynı.
static func _mirror_and_reorder(level: Dictionary, rng: RandomNumberGenerator) -> void:
	var items: Array[Dictionary] = level["items"] as Array[Dictionary]
	var widest: float = 0.0
	var lines: int = 0
	for entry: Dictionary in items:
		if entry.has("sheet") or int(entry.get("screen", 0)) > 0:
			return
		widest = maxf(widest, float(entry["slot"]))
		lines = maxi(lines, int(entry["line"]) + 1)
	var mirror: bool = rng.randi_range(0, 1) == 1
	var order: Array[int] = []
	for index: int in range(lines):
		order.append(index)
	for index: int in range(lines - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var held: int = order[index]
		order[index] = order[other]
		order[other] = held
	for entry: Dictionary in items:
		entry["line"] = order[int(entry["line"])]
		if mirror:
			entry["slot"] = widest - float(entry["slot"])


## Askı doldu / hamle kalmadı: oyuncuyu cezalandırmadan kurtarır. Önce son hamleleri geri alır
## (en çok `max_undo`) ve çözücünün bulduğu ilk iyi hamleyi önerir; tahta başına `max_per_board`
## kurtarmadan sonra ya da geri alma yetmezse bir askı ekler. Her çağrı sınırlıdır: kendiliğinden
## döngüye girmez; askı sayısı çamaşır sayısını aşınca kayıp fiziksel olarak imkânsızdır.
## `taps`: bu tahtada yapılan durum değiştiren dokunuşlar (geri alınanlar listeden düşer).
## Dönen: {"undone": int, "hint": çamaşır kimliği ya da -1, "slot": askı eklendi mi}.
static func rescue(level: Dictionary, taps: Array[int], board: LaundryBoard, rescues_so_far: int,
		cfg: Dictionary) -> Dictionary:
	var rule: Dictionary = cfg.get(KEY_RESCUE, {}) as Dictionary
	var max_undo: int = ProgressData.to_count(rule.get("max_undo"), FALLBACK_MAX_UNDO)
	var node_limit: int = ProgressData.to_count(rule.get("node_limit"), FALLBACK_NODE_LIMIT)
	var max_rescues: int = ProgressData.to_count(rule.get("max_per_board"), FALLBACK_MAX_RESCUES)
	var result: Dictionary = {"undone": 0, "hint": -1, "slot": false}
	# Geçmiş ile dokunuş listesi uyuşmuyorsa (beklenmedik durum) güvenli yedek: askı ekle.
	if rescues_so_far < max_rescues and board.history_size() == taps.size():
		for _step: int in range(mini(max_undo, taps.size())):
			if not board.undo():
				break
			taps.pop_back()
			result["undone"] = int(result["undone"]) + 1
			var path: Array[int] = LevelSolver.solve_from(level, taps, node_limit)
			if path.size() > taps.size():
				result["hint"] = path[taps.size()]
				break
	if board.is_over():
		board.add_rack_slot()
		result["slot"] = true
	return result


static func _progress() -> Node:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	return loop.root.get_node_or_null("Progress") if loop != null else null


static func _progress_value(key: String) -> Variant:
	var progress: Node = _progress()
	if progress == null:
		return 0
	return progress.call("module_value", MODULE, key, 0)
