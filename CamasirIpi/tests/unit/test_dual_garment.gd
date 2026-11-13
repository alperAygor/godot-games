extends TestCase

## Çift renkli çamaşır: yönlendirme kuralı (A, yoksa B, ikisi de varsa tamamlanmaya yakın olan,
## eşitlikte A), tamamlayıcı çiftin yerleşmesi (ev takası), geri al, durum anahtarı ve özellik testi:
## üretilen seviyelerde çift hangi yöne giderse gitsin renk sayıları tutar ve seviye çözülebilir kalır.

const PROPERTY_LEVELS: Array[int] = [18, 19, 24, 35, 38, 41, 43, 45, 49]
const RANDOM_PLAYOUTS: int = 6
const PLAYOUT_SEED: int = 4242
const PROPERTY_NODE_LIMIT: int = 60000


## 0: çift A|B (evi 0), 1: çift A|B (evi 1); 2-3 renk 0, 4-5 renk 1. Kuyruk: 0, 1.
func _pair_level(blockers: Dictionary = {}) -> Dictionary:
	var items: Array = [
		{"id": 0, "color": 0, "blockers": blockers.get(0, []), "twin": 1, "line": 0},
		{"id": 1, "color": 1, "blockers": blockers.get(1, []), "twin": 0, "line": 0},
		{"id": 2, "color": 0, "blockers": blockers.get(2, []), "line": 1},
		{"id": 3, "color": 0, "blockers": blockers.get(3, []), "line": 1},
		{"id": 4, "color": 1, "blockers": blockers.get(4, []), "line": 1},
		{"id": 5, "color": 1, "blockers": blockers.get(5, []), "line": 1},
	]
	return {"items": items, "queue": [0, 1], "active_baskets": 2, "rack_slots": 4}


func _types(events: Array[Dictionary]) -> Array[String]:
	var types: Array[String] = []
	for event: Dictionary in events:
		types.append(String(event["type"]))
	return types


func _basket_of(events: Array[Dictionary]) -> int:
	for event: Dictionary in events:
		if String(event["type"]) == LaundryBoard.EVENT_TO_BASKET:
			return int(event["basket"])
	return LaundryBoard.EMPTY


func test_tie_goes_to_colour_a() -> void:
	var board: LaundryBoard = LaundryBoard.new(_pair_level())
	assert_true(board.is_dual(0))
	var events: Array[Dictionary] = board.tap(0)
	assert_eq(_basket_of(events), 0, "iki sepet de boş: eşitlikte A (renk 0)")
	assert_true(_types(events).has(LaundryBoard.EVENT_DUAL_SETTLE))
	assert_false(board.is_dual(0), "yerleşti")
	assert_false(board.is_dual(1), "eşi de artık tek renk")
	assert_eq(board.color_of(1), 1, "eşi kalan renge (B) gider")


func test_closer_to_completion_wins() -> void:
	var board: LaundryBoard = LaundryBoard.new(_pair_level())
	board.tap(4)
	board.tap(5)
	# Renk 1 sepeti 2/3 dolu, renk 0 sepeti boş: çift renkli parça renk 1'e gider (ev takası).
	var events: Array[Dictionary] = board.tap(0)
	assert_eq(_basket_of(events), 1, "tamamlanmaya yakın sepet (renk 1)")
	assert_eq(board.color_of(0), 1, "parça renk 1 olarak yerleşti")
	assert_eq(board.color_of(1), 0, "eşi evi devraldı: artık renk 0")
	assert_false(board.is_dual(1))
	assert_true(_types(events).has(LaundryBoard.EVENT_BASKET_DONE), "renk 1 sepeti tamamlandı")
	for id: int in [1, 2, 3]:
		board.tap(id)
	assert_true(board.is_won(), "takastan sonra renk sayıları tutar, seviye biter")


func test_only_colour_b_available() -> void:
	# Kuyruk 1, 2: renk 0 sepeti yok -> B (renk 1) sepetine.
	var level: Dictionary = _pair_level()
	level["queue"] = [1, 0]
	level["active_baskets"] = 1
	var board: LaundryBoard = LaundryBoard.new(level)
	var events: Array[Dictionary] = board.tap(0)
	assert_eq(_basket_of(events), 0, "tek aktif sepet renk 1")
	assert_eq(board.color_of(0), 1)
	assert_eq(board.color_of(1), 0, "eşi renk 0'a döndü")


func test_neither_available_goes_to_rack_and_settles_later() -> void:
	var level: Dictionary = _pair_level()
	level["items"].append({"id": 6, "color": 2, "blockers": []})
	level["items"].append({"id": 7, "color": 2, "blockers": []})
	level["items"].append({"id": 8, "color": 2, "blockers": []})
	level["queue"] = [2, 0, 1]
	level["active_baskets"] = 1
	var board: LaundryBoard = LaundryBoard.new(level)
	var events: Array[Dictionary] = board.tap(0)
	assert_true(_types(events).has(LaundryBoard.EVENT_TO_RACK), "uygun sepet yok: askıya")
	assert_true(board.is_dual(0), "askıda hâlâ iki renkli")
	for id: int in [6, 7, 8]:
		board.tap(id)
	# Renk 0 sepeti geldi: askıdaki çift renkli parça kendiliğinden geçer.
	assert_eq(board.rack_count(), 0, "askıdan sepete geçti")
	assert_false(board.is_dual(0))


func test_undo_restores_dual_state() -> void:
	var board: LaundryBoard = LaundryBoard.new(_pair_level())
	board.enable_history()
	var before: PackedInt32Array = board.state_key()
	board.tap(4)
	board.tap(5)
	var mid: PackedInt32Array = board.state_key()
	board.tap(0)
	assert_eq(board.color_of(1), 0)
	assert_true(board.undo())
	assert_eq(board.state_key(), mid, "geri al: anahtar birebir")
	assert_true(board.is_dual(0) and board.is_dual(1), "çift yeniden esnek")
	assert_eq(board.color_of(0), 0)
	assert_eq(board.color_of(1), 1)
	board.undo()
	board.undo()
	assert_eq(board.state_key(), before)


func test_state_key_distinguishes_settled_pair() -> void:
	var a: LaundryBoard = LaundryBoard.new(_pair_level())
	var b: LaundryBoard = LaundryBoard.new(_pair_level())
	a.tap(2)
	b.tap(2)
	assert_eq(a.state_key(), b.state_key())
	a.tap(0)
	b.tap(4)
	assert_true(a.state_key() != b.state_key())


func test_solver_handles_dual_level() -> void:
	var path: Array[int] = LevelSolver.solve(_pair_level())
	assert_false(path.is_empty())


## Değişmez: her an, yerleşmemiş parçaların ev sayısı = o rengin kalan sepet kapasitesi.
func _counts_balanced(board: LaundryBoard, level: Dictionary) -> bool:
	var homes: Dictionary = {}
	for id: int in board.item_ids():
		var placed: bool = false
		for index: int in range(board.baskets().size()):
			if board.basket_contents(index).has(id):
				placed = true
		if placed or _completed_id(board, id):
			continue
		homes[board.color_of(id)] = int(homes.get(board.color_of(id), 0)) + 1
	var room: Dictionary = {}
	var states: Array[Dictionary] = board.baskets()
	for basket: Dictionary in states:
		if basket.is_empty():
			continue
		var color: int = int(basket["color"]) if int(basket["color"]) != LaundryBoard.EMPTY else int(basket.get("ref", -1))
		room[color] = int(room.get(color, 0)) + int(basket.get("cap", LaundryBoard.BASKET_CAPACITY)) - int(basket["count"])
	var queue: Array[int] = board.queue()
	for index: int in range(queue.size()):
		var size: int = LaundryBoard.BIG_BASKET_CAPACITY if board.queue_kind(index) == LaundryBoard.KIND_BIG \
			else LaundryBoard.BASKET_CAPACITY
		room[queue[index]] = int(room.get(queue[index], 0)) + size
	for color: Variant in homes.keys():
		if int(homes[color]) != int(room.get(color, 0)):
			return false
	return true


## Tamamlanıp çıkan sepetlerin parçaları: ipte, askıda, makinede ya da aktif sepette değil.
func _completed_id(board: LaundryBoard, id: int) -> bool:
	return not board.is_on_line(id) and not board.rack().has(id) and board.machine_of(id) == LaundryBoard.EMPTY


func test_property_counts_never_drift_in_random_play() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = PLAYOUT_SEED
	var checked: int = 0
	for number: int in PROPERTY_LEVELS:
		var level: Dictionary = LevelCache.level(number)
		if level["items"].filter(func(e: Variant) -> bool: return (e as Dictionary).has("twin")).is_empty():
			continue
		for _run: int in range(RANDOM_PLAYOUTS):
			var board: LaundryBoard = LaundryBoard.new(level)
			while not board.is_over():
				var open: Array[int] = board.open_ids()
				if open.is_empty():
					break
				board.tap(open[rng.randi_range(0, open.size() - 1)])
				assert_true(_counts_balanced(board, level), "seviye %d: renk sayıları tutar" % number)
				checked += 1
	assert_greater(float(checked), 50.0, "yeterli rastgele hamle denetlendi")


## Özellik testi: üretilen her çift renkli seviyede, çiftin ilk parçası İKİ YÖNE de gidebilecek bir
## duruma gelinir (çözüm yolunun önekiyle), o yön zorlanır ve kalan seviye çözülebilir olmalıdır.
func test_property_either_way_stays_solvable() -> void:
	var tested: int = 0
	for number: int in PROPERTY_LEVELS:
		var level: Dictionary = LevelCache.level(number)
		var path: Array[int] = LevelCache.path(number)
		var board: LaundryBoard = LaundryBoard.new(level)
		for step: int in range(path.size()):
			var id: int = path[step]
			if id >= 0 and board.is_dual(id) and board.is_open(id):
				# İki yön: (1) asıl tahtada aynı önek + bu dokunuş; (2) evleri takas edilmiş (parça diğer
				# renge yerleşmiş gibi) tahtada aynı önek + bu dokunuş. İkisinden de kazanılabilmeli.
				var taps: Array[int] = []
				taps.assign(path.slice(0, step))
				taps.append(id)
				assert_false(LevelSolver.solve_from(level, taps, PROPERTY_NODE_LIMIT).is_empty(),
					"seviye %d: yolun yönü çözülür" % number)
				var swapped: Dictionary = _swap_pair(level, id, board.dual_partner(id))
				assert_false(LevelSolver.solve_from(swapped, taps, PROPERTY_NODE_LIMIT).is_empty(),
					"seviye %d: diğer yön de çözülür" % number)
				tested += 1
				break
			board.tap(id)
	assert_greater(float(tested), 3.0, "çift renkli seviyeler denendi (%d)" % tested)


## Çiftin evleri takas edilmiş kopya: aynı dokunuşta parça diğer renge yerleşmiş gibi oynanır.
func _swap_pair(level: Dictionary, first: int, second: int) -> Dictionary:
	var copy: Dictionary = level.duplicate(true)
	var a: Dictionary = {}
	var b: Dictionary = {}
	for entry: Variant in copy["items"] as Array:
		if int((entry as Dictionary)["id"]) == first:
			a = entry as Dictionary
		elif int((entry as Dictionary)["id"]) == second:
			b = entry as Dictionary
	var held: int = int(a["color"])
	a["color"] = int(b["color"])
	b["color"] = held
	a.erase("twin")
	b.erase("twin")
	return copy


func test_generator_places_complementary_pairs() -> void:
	var intro: Dictionary = LevelCache.level(LevelGenerator.DUAL_FROM_LEVEL)
	var duals: Array[Dictionary] = []
	for entry: Variant in intro["items"] as Array:
		if (entry as Dictionary).has("twin"):
			duals.append(entry as Dictionary)
	assert_eq(duals.size(), 2, "tanıtımda tek çift")
	assert_eq(int(duals[0]["twin"]), int(duals[1]["id"]))
	assert_eq(int(duals[1]["twin"]), int(duals[0]["id"]))
	assert_true(int(duals[0]["color"]) != int(duals[1]["color"]), "evler farklı renk (tamamlayıcı)")
	for number: int in range(1, LevelGenerator.DUAL_FROM_LEVEL):
		for entry: Variant in LevelCache.level(number)["items"] as Array:
			assert_false((entry as Dictionary).has("twin"), "seviye %d'de çift renk yok" % number)
	assert_true(TutorialFeatures.detect(intro).has("dual"), "tanıtım kartı")
