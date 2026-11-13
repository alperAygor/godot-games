class_name LevelGenerator
extends RefCounted

## Saf mantık: seviye numarasından deterministik, ÇÖZÜLEBİLİR seviye üretir.
##
## Yöntem (PROJECT_SPEC teknik not): önce düzen (hangi çamaşır hangisini kapatıyor)
## kurulur, sonra geçerli bir toplama sırası seçilir ve sıra üçerli gruplara bölünür;
## her grup bir sepettir. Sepet kuyruğu bu sırayla dizildiğinden o sırayla oynayan
## oyuncu hiç askı kullanmadan bitirir -> her seviye çözülebilir. Zorluk, sepet
## kuyruğunu "ters" karıştırıp `LevelSolver` ile yeniden doğrulayarak artırılır.

const BASKET_CAPACITY: int = 3
const MIN_COLORS: int = 2
const MAX_COLORS: int = 7
const MAX_LINES: int = 5
const MAX_LAYERS: int = 4
const HARD_EVERY: int = 5
const THREE_BASKETS_FROM_LEVEL: int = 15
const SHUFFLE_ATTEMPTS: int = 12
const SEED_SALT: int = 7919
## Engellerin açıldığı seviyeler: her biri ilk göründüğü seviyede tek başına ve azdır.
const WET_FROM_LEVEL: int = 8
const MYSTERY_FROM_LEVEL: int = 14
const LOCK_FROM_LEVEL: int = 20
const OBSTACLE_RAMP_LEVELS: int = 6
const MAX_WET: int = 5
const MAX_MYSTERY: int = 6
const MAX_LOCKS: int = 3
## Yeni engeller (derinleşme): her biri tanıtım seviyesinde TEK BAŞINA ve tek adet gelir.
const SHEET_FROM_LEVEL: int = 26
const SOCK_FROM_LEVEL: int = 32
const DYE_FROM_LEVEL: int = 40
const INTRO_LEVELS: Array[int] = [WET_FROM_LEVEL, MYSTERY_FROM_LEVEL, LOCK_FROM_LEVEL,
	SHEET_FROM_LEVEL, SOCK_FROM_LEVEL, DYE_FROM_LEVEL]
const MAX_SHEETS: int = 2
const MAX_SOCK_PAIRS: int = 3
const MAX_DYES: int = 3
## Çarşaf kaç sütun genişliğinde (iki ipe yayılır); geç seviyelerde bir sütun daha geniş.
const SHEET_SPAN: int = 2
const SHEET_LINES: int = 2
const SHEET_WIDE_FROM_LEVEL: int = 50
## Çarşafın altında en az bu kadar parça olmalı (yoksa "çok parçayı açan" hissi doğmaz).
const SHEET_MIN_COVER: int = 4
const SHEET_ATTEMPTS: int = 16
## Görünüm türleri (GarmentView.KINDS ile aynı sıra): havlu = çarşaf dokusu, 6 = çorap.
const SHEET_KIND: int = 3
const SOCK_KIND: int = 6
## Yeni zorluk eğrisi bu seviyeden başlar; öncesi birebir eskisi gibi kalır (oyuncu ve
## öğretici akışı tanıdık seviyeleri görmeye devam etsin).
const LATE_CURVE_FROM_LEVEL: int = 26
const LATE_COLORS_BASE: int = 5
const LATE_COLORS_STEP: int = 9
const LATE_TWIST_FROM_LEVEL: int = 40
const LATE_TWIST_STEP: int = 10
const LATE_TWIST_MAX_EXTRA: int = 6
const BASE_TWIST_MAX: int = 8
const HARD_TWIST_BONUS: int = 3
## Çok zor seviye: her 15'te bir (30'dan itibaren); zorun üstüne ek kuyruk karışıklığı.
const VERY_HARD_EVERY: int = 15
const VERY_HARD_FROM_LEVEL: int = 30
const VERY_HARD_TWIST_BONUS: int = 3
## Geniş tahta (5 sütun): ipteki parça sayısı büyür.
const WIDE_BOARD_FROM_LEVEL: int = 56
const WIDE_COLUMNS: int = 5
const BASE_COLUMNS: int = 4
## Geç seviyelerde çözücü doğrulama sınırı: başarısız aramalar bütçeyi tüketir; mobilde
## üretim süresi sınırlı kalsın diye düşük tutulur (reddedilen karıştırma güvenli taraftır).
const LATE_NODE_LIMIT: int = 6000


## Zorluk parametreleri: {lines, columns, layers, colors, twist, active_baskets, hard}.
static func params_for(level: int) -> Dictionary:
	var n: int = maxi(level, 1)
	var hard: bool = n > HARD_EVERY and n % HARD_EVERY == 0
	if n >= LATE_CURVE_FROM_LEVEL:
		return _late_params(n)
	if n == 1:
		return {"lines": 2, "columns": 3, "layers": 1, "colors": 2, "twist": 0,
			"active_baskets": 2, "hard": false}
	if n == 2:
		return {"lines": 2, "columns": 3, "layers": 2, "colors": 2, "twist": 0,
			"active_baskets": 2, "hard": false}
	if n == 3:
		return {"lines": 2, "columns": 3, "layers": 2, "colors": 3, "twist": 1,
			"active_baskets": 2, "hard": false}
	var lines: int = clampi(2 + (n - 1) / 6, 2, MAX_LINES)
	var layers: int = clampi(2 + (n - 4) / 12, 2, MAX_LAYERS)
	var colors: int = clampi(3 + (n - 4) / 8, 3, MAX_COLORS)
	var twist: int = clampi(1 + (n - 4) / 5, 1, 8)
	if hard:
		layers = mini(layers + 1, MAX_LAYERS)
		twist += 3
	return {"lines": lines, "columns": 4, "layers": layers, "colors": colors, "twist": twist,
		"active_baskets": 3 if n >= THREE_BASKETS_FROM_LEVEL else 2, "hard": hard}


## 26+ eğrisi: renk 5->7, karıştırma 40'tan sonra da büyür, her 5'te zor, her 15'te çok zor,
## 56'dan itibaren 5 sütun. Tanıtım seviyeleri zor olmaz ve karıştırma yarıya iner: yeni
## engel oyuncuya sakin bir tahtada öğretilir.
static func _late_params(n: int) -> Dictionary:
	var intro: bool = n in INTRO_LEVELS
	var very_hard: bool = not intro and n >= VERY_HARD_FROM_LEVEL and n % VERY_HARD_EVERY == 0
	var hard: bool = not intro and n % HARD_EVERY == 0
	var layers: int = clampi(2 + (n - 4) / 12, 2, MAX_LAYERS)
	var colors: int = clampi(LATE_COLORS_BASE + (n - LATE_CURVE_FROM_LEVEL) / LATE_COLORS_STEP,
		LATE_COLORS_BASE, MAX_COLORS)
	var twist: int = clampi(1 + (n - 4) / 5, 1, BASE_TWIST_MAX) \
		+ clampi((n - LATE_TWIST_FROM_LEVEL) / LATE_TWIST_STEP, 0, LATE_TWIST_MAX_EXTRA)
	if intro:
		twist = twist / 2
		layers = mini(layers, MAX_LAYERS - 1)
	if hard:
		layers = mini(layers + 1, MAX_LAYERS)
		twist += HARD_TWIST_BONUS
	if very_hard:
		twist += VERY_HARD_TWIST_BONUS
	return {"lines": MAX_LINES, "columns": WIDE_COLUMNS if n >= WIDE_BOARD_FROM_LEVEL else BASE_COLUMNS,
		"layers": layers, "colors": colors, "twist": twist, "active_baskets": 3,
		"hard": hard, "very_hard": very_hard}


static func generate(level: int) -> Dictionary:
	var params: Dictionary = params_for(level)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = maxi(level, 1) * SEED_SALT
	var items: Array[Dictionary] = _layout(params, rng)
	var number: int = maxi(level, 1)
	var sheets: int = _new_obstacle_count(number, SHEET_FROM_LEVEL, MAX_SHEETS)
	if sheets > 0:
		_add_sheets(items, params, sheets, number, rng)
	var order: Array[int] = _removal_order(items, rng)
	var active: int = int(params["active_baskets"])
	var queue: Array[int] = _assign_colors(items, order, int(params["colors"]), active, rng)
	var result: Dictionary = {
		"level": maxi(level, 1),
		"items": items,
		"queue": queue,
		"active_baskets": active,
		"rack_slots": LaundryBoard.DEFAULT_RACK_SLOTS,
		"hard": bool(params["hard"]),
	}
	if bool(params.get("very_hard", false)):
		result["very_hard"] = true
	var limit: int = LevelSolver.DEFAULT_NODE_LIMIT if number < LATE_CURVE_FROM_LEVEL else LATE_NODE_LIMIT
	_twist_queue(result, int(params["twist"]), rng, limit)
	_add_obstacles(result, rng)
	# Boya önce yerleşir: uygun yeri azdır (başta açık + altında başka renk sıradan parça);
	# çoraplar her renk grubuna sığabildiği için sonra gelir.
	var dyes: int = _new_obstacle_count(number, DYE_FROM_LEVEL, MAX_DYES)
	if dyes > 0:
		_add_dyes(result, dyes, rng)
	var socks: int = _new_obstacle_count(number, SOCK_FROM_LEVEL, MAX_SOCK_PAIRS)
	if socks > 0:
		_add_socks(result, order, socks, rng)
	return result


## Yeni engel sayısı: açıldığı seviyede 1; başka bir engelin tanıtım seviyesinde 0 (o seviye
## yalnız yeni engeli öğretir); sonra `obstacle_count` rampası.
static func _new_obstacle_count(level: int, from_level: int, maximum: int) -> int:
	if level < from_level:
		return 0
	if level == from_level:
		return 1
	if level in INTRO_LEVELS:
		return 0
	return obstacle_count(level, from_level, maximum)


## Seviyeye göre engel sayısı: açıldığı seviyede 1, sonra her OBSTACLE_RAMP_LEVELS'ta +1.
static func obstacle_count(level: int, from_level: int, maximum: int) -> int:
	if level < from_level:
		return 0
	return clampi(1 + (level - from_level) / OBSTACLE_RAMP_LEVELS, 1, maximum)


## Yeni engelin tanıtıldığı seviyede eskiler karışmaz (yalnız yeni engel gelir).
static func _add_obstacles(level: Dictionary, rng: RandomNumberGenerator) -> void:
	var number: int = int(level["level"])
	var items: Array[Dictionary] = level["items"] as Array[Dictionary]
	var intro: bool = number in INTRO_LEVELS
	var wet: int = obstacle_count(number, WET_FROM_LEVEL, MAX_WET)
	var mystery: int = obstacle_count(number, MYSTERY_FROM_LEVEL, MAX_MYSTERY)
	var locks: int = obstacle_count(number, LOCK_FROM_LEVEL, MAX_LOCKS)
	if intro:
		wet = 1 if number == WET_FROM_LEVEL else 0
		mystery = 2 if number == MYSTERY_FROM_LEVEL else 0
		locks = 1 if number == LOCK_FROM_LEVEL else 0
	var pool: Array[int] = []
	for index: int in range(items.size()):
		pool.append(index)
	_shuffle(pool, rng)
	# Gizemli: başta üstü kapalı olanlardan seçilir (yoksa anlamı kalmaz).
	for index: int in pool:
		if mystery <= 0:
			break
		if not (items[index]["blockers"] as Array).is_empty():
			items[index]["mystery"] = true
			mystery -= 1
	for index: int in pool:
		if wet <= 0:
			break
		if not bool(items[index].get("mystery", false)):
			items[index]["wet"] = true
			wet -= 1
	# Kilit: çözülebilirlik bozulursa geri alınır.
	var queue: Array = level["queue"] as Array
	for index: int in pool:
		if locks <= 0 or queue.size() < 3:
			break
		var entry: Dictionary = items[index]
		if entry.has("wet") or entry.has("mystery"):
			continue
		var key_color: int = int(queue[rng.randi_range(0, mini(2, queue.size() - 1))])
		if key_color == int(entry["color"]):
			continue
		entry["lock"] = key_color
		if LevelSolver.is_solvable(level):
			locks -= 1
		else:
			entry.erase("lock")


static func _shuffle(values: Array[int], rng: RandomNumberGenerator) -> void:
	for index: int in range(values.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var held: int = values[index]
		values[index] = values[other]
		values[other] = held


## Piramit düzeni: her ipte katman 0'da `columns` parça; üst katman yarım kaydırılır ve
## altındaki iki komşuyu kapatır. Toplam, 3'ün katına indirilir (en üstten kırpılır).
static func _layout(params: Dictionary, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	var next_id: int = 0
	var lines: int = int(params["lines"])
	var columns: int = int(params["columns"])
	var layers: int = int(params["layers"])
	for line: int in range(lines):
		var below: Array[int] = []
		for layer: int in range(layers):
			var count: int = columns - layer
			if count <= 0:
				break
			var current: Array[int] = []
			for column: int in range(count):
				# Üst katmanlar seyrek olabilir: düzen her seviyede farklı görünür.
				if layer > 0 and rng.randf() < 0.25:
					current.append(LaundryBoard.EMPTY)
					continue
				var entry: Dictionary = {
					"id": next_id, "color": 0, "blockers": [] as Array[int],
					"line": line, "layer": layer, "slot": float(column) + 0.5 * float(layer),
					"kind": rng.randi_range(0, 5),
				}
				items.append(entry)
				current.append(next_id)
				if layer > 0:
					for under_column: int in [column, column + 1]:
						var under: int = below[under_column]
						if under != LaundryBoard.EMPTY:
							((items[_index_of(items, under)]["blockers"]) as Array).append(next_id)
				next_id += 1
			below = current
	_trim_to_multiple(items)
	return items


static func _trim_to_multiple(items: Array[Dictionary]) -> void:
	var extra: int = items.size() % BASKET_CAPACITY
	while extra > 0:
		# Son eklenen parça en üst katmandadır: kimse onu kapatmaz, güvenle çıkarılır.
		var victim: int = items.size() - 1
		var victim_id: int = int(items[victim]["id"])
		items.remove_at(victim)
		for entry: Dictionary in items:
			(entry["blockers"] as Array).erase(victim_id)
		extra -= 1


static func _index_of(items: Array[Dictionary], id: int) -> int:
	for index: int in range(items.size()):
		if int(items[index]["id"]) == id:
			return index
	return -1


## Rastgele ama geçerli (her adımda açık olan) bir toplama sırası.
static func _removal_order(items: Array[Dictionary], rng: RandomNumberGenerator) -> Array[int]:
	var remaining: Dictionary = {}
	for entry: Dictionary in items:
		remaining[int(entry["id"])] = entry
	var order: Array[int] = []
	while not remaining.is_empty():
		var open: Array[int] = []
		for id: Variant in remaining.keys():
			var blocked: bool = false
			for blocker: Variant in (remaining[id] as Dictionary)["blockers"] as Array:
				if remaining.has(int(blocker)):
					blocked = true
					break
			if not blocked:
				open.append(int(id))
		open.sort()
		var pick: int = open[rng.randi_range(0, open.size() - 1)]
		order.append(pick)
		remaining.erase(pick)
	return order


## Sıra üçerli gruplanır; her grup bir sepet rengidir. Aynı anda aktif olacak komşu
## sepetler farklı renkte seçilir.
static func _assign_colors(items: Array[Dictionary], order: Array[int], colors: int,
		active: int, rng: RandomNumberGenerator) -> Array[int]:
	var queue: Array[int] = []
	var palette: int = clampi(colors, MIN_COLORS, MAX_COLORS)
	var group_count: int = order.size() / BASKET_CAPACITY
	for group: int in range(group_count):
		var color: int = rng.randi_range(0, palette - 1)
		var guard: int = 0
		while _recent_has(queue, color, active - 1) and guard < 20:
			color = (color + 1) % palette
			guard += 1
		queue.append(color)
		for offset: int in range(BASKET_CAPACITY):
			var id: int = order[group * BASKET_CAPACITY + offset]
			items[_index_of(items, id)]["color"] = color
	return queue


static func _recent_has(queue: Array[int], color: int, window: int) -> bool:
	for back: int in range(1, window + 1):
		var index: int = queue.size() - back
		if index >= 0 and queue[index] == color:
			return true
	return false


## Kuyrukta komşu sepetleri yer değiştirir; çözülebilirlik bozulursa geri alınır.
static func _twist_queue(level: Dictionary, twist: int, rng: RandomNumberGenerator,
		node_limit: int = LevelSolver.DEFAULT_NODE_LIMIT) -> void:
	var queue: Array[int] = level["queue"] as Array[int]
	if queue.size() < 3 or twist <= 0:
		return
	var applied: int = 0
	var attempts: int = 0
	while applied < twist and attempts < SHUFFLE_ATTEMPTS + twist * 2:
		attempts += 1
		var a: int = rng.randi_range(0, queue.size() - 2)
		var b: int = mini(a + rng.randi_range(1, 2), queue.size() - 1)
		if queue[a] == queue[b]:
			continue
		var swapped: Array[int] = queue.duplicate()
		swapped[a] = queue[b]
		swapped[b] = queue[a]
		var candidate: Dictionary = level.duplicate()
		candidate["queue"] = swapped
		if LevelSolver.is_solvable(candidate, node_limit):
			queue = swapped
			level["queue"] = swapped
			applied += 1


# --- Yeni engellerin yerleşimi ----------------------------------------------------------------

## Engelsiz, sıradan parça mı (yeni engeller birbirine ve eskilere binmesin).
static func _plain(entry: Dictionary) -> bool:
	for key: String in ["wet", "mystery", "lock", "sheet", "sock", "dye"]:
		if entry.has(key):
			return false
	return true


## Çarşaf: iki komşu ipe yayılan, en üst katmandaki tek parça. Altında kalan (iki ipteki,
## sütun aralığındaki tüm katmanlar) parçaların `blockers` listesine eklenir. Renk ataması
## toplama sırasından ÖNCE yapıldığı için çarşaf da normal bir parça gibi gruplara girer ve
## çözülebilirlik kanıtı (sıra = kuyruk) aynen geçerli kalır.
static func _add_sheets(items: Array[Dictionary], params: Dictionary, count: int, level: int,
		rng: RandomNumberGenerator) -> void:
	var lines: int = int(params["lines"])
	var columns: int = int(params["columns"])
	if lines < SHEET_LINES:
		return
	var span: int = mini(SHEET_SPAN + (1 if level >= SHEET_WIDE_FROM_LEVEL else 0), columns)
	var next_id: int = 0
	for entry: Dictionary in items:
		next_id = maxi(next_id, int(entry["id"]) + 1)
	var placed: Array[Vector2i] = []
	for _sheet: int in range(count):
		for _attempt: int in range(SHEET_ATTEMPTS):
			var top: int = rng.randi_range(0, lines - SHEET_LINES)
			var start: int = rng.randi_range(0, columns - span)
			if _sheet_overlaps(placed, top, start, span):
				continue
			var center: float = float(start) + float(span - 1) * 0.5
			var half: float = float(span) * 0.5
			var covered: Array[Dictionary] = []
			for entry: Dictionary in items:
				var line: int = int(entry["line"])
				if line >= top and line < top + SHEET_LINES and not entry.has("sheet") \
						and absf(float(entry["slot"]) - center) <= half:
					covered.append(entry)
			if covered.size() < SHEET_MIN_COVER:
				continue
			for entry: Dictionary in covered:
				(entry["blockers"] as Array).append(next_id)
			items.append({
				"id": next_id, "color": 0, "blockers": [] as Array[int], "line": top,
				"layer": int(params["layers"]), "slot": center, "kind": SHEET_KIND,
				"sheet": true, "span": span, "span_lines": SHEET_LINES,
			})
			placed.append(Vector2i(top, start))
			next_id += 1
			break
	_trim_keeping_sheets(items)


static func _sheet_overlaps(placed: Array[Vector2i], top: int, start: int, span: int) -> bool:
	for other: Vector2i in placed:
		if absi(other.x - top) < SHEET_LINES and absi(other.y - start) < span:
			return true
	return false


## Çarşaf eklenince toplam yeniden 3'ün katına indirilir: kimseyi kapatmayan (en üstteki)
## sıradan parçalar çıkarılır; çarşaf asla çıkarılmaz.
static func _trim_keeping_sheets(items: Array[Dictionary]) -> void:
	while items.size() % BASKET_CAPACITY != 0:
		var covering: Dictionary = {}
		for entry: Dictionary in items:
			for blocker: Variant in entry["blockers"] as Array:
				covering[int(blocker)] = true
		var victim: int = -1
		for index: int in range(items.size() - 1, -1, -1):
			var entry: Dictionary = items[index]
			if not entry.has("sheet") and not covering.has(int(entry["id"])):
				victim = index
				break
		if victim < 0:
			return
		var victim_id: int = int(items[victim]["id"])
		items.remove_at(victim)
		for entry: Dictionary in items:
			(entry["blockers"] as Array).erase(victim_id)


## Çorap çifti: toplama sırasında ARDIŞIK ve aynı sepet grubundaki iki parça seçilir (aynı
## renk; ilki alınınca ikincisi kesin açıktır). Her çift `LevelSolver` ile doğrulanır.
static func _add_socks(level: Dictionary, order: Array[int], count: int, rng: RandomNumberGenerator) -> void:
	var items: Array[Dictionary] = level["items"] as Array[Dictionary]
	var starts: Array[int] = []
	for k: int in range(order.size() - 1):
		if k / BASKET_CAPACITY == (k + 1) / BASKET_CAPACITY:
			starts.append(k)
	_shuffle(starts, rng)
	var left: int = count
	for k: int in starts:
		if left <= 0:
			break
		var first: Dictionary = items[_index_of(items, order[k])]
		var second: Dictionary = items[_index_of(items, order[k + 1])]
		if not _plain(first) or not _plain(second):
			continue
		var kinds: Array[int] = [int(first["kind"]), int(second["kind"])]
		first["sock"] = order[k + 1]
		second["sock"] = order[k]
		first["kind"] = SOCK_KIND
		second["kind"] = SOCK_KIND
		if LevelSolver.is_solvable(level, LATE_NODE_LIMIT):
			left -= 1
		else:
			first.erase("sock")
			second.erase("sock")
			first["kind"] = kinds[0]
			second["kind"] = kinds[1]


## Boya akıtan: başta açık (üstü boş) ve altında başka renkte sıradan bir parça kapatan
## parçaya konur. İki doğrulama: (1) seviye en iyi oyunla çözülebilir; (2) boya baştan akmış
## gibi renkler takas edilse de çözülebilir. İkincisi, boyayı kaçıran oyuncunun önüne
## "kesin kayıp" bir tahta çıkmamasının makul güvencesidir (takas zaten renk sayılarını korur).
static func _add_dyes(level: Dictionary, count: int, rng: RandomNumberGenerator) -> void:
	var items: Array[Dictionary] = level["items"] as Array[Dictionary]
	var below: Dictionary = {}
	for entry: Dictionary in items:
		for blocker: Variant in entry["blockers"] as Array:
			if not below.has(int(blocker)):
				below[int(blocker)] = [] as Array[int]
			(below[int(blocker)] as Array[int]).append(int(entry["id"]))
	var pool: Array[int] = []
	for index: int in range(items.size()):
		pool.append(index)
	_shuffle(pool, rng)
	var left: int = count
	for index: int in pool:
		if left <= 0:
			break
		var entry: Dictionary = items[index]
		var id: int = int(entry["id"])
		if not _plain(entry) or not (entry["blockers"] as Array).is_empty() or not below.has(id):
			continue
		var targets: Array[int] = []
		for under: int in below[id] as Array[int]:
			var candidate: Dictionary = items[_index_of(items, under)]
			if _plain(candidate) and int(candidate["color"]) != int(entry["color"]):
				targets.append(under)
		if targets.is_empty():
			continue
		var target: int = targets[rng.randi_range(0, targets.size() - 1)]
		entry["dye"] = LaundryBoard.DEFAULT_DYE_MOVES
		entry["dye_target"] = target
		if LevelSolver.is_solvable(level, LATE_NODE_LIMIT) \
				and LevelSolver.is_solvable(_bled_variant(level, id, target), LATE_NODE_LIMIT):
			left -= 1
		else:
			entry.erase("dye")
			entry.erase("dye_target")


static func _bled_variant(level: Dictionary, id: int, target: int) -> Dictionary:
	var copy: Dictionary = level.duplicate(true)
	var a: Dictionary = {}
	var b: Dictionary = {}
	for entry: Variant in copy["items"] as Array:
		var item: Dictionary = entry as Dictionary
		if int(item["id"]) == id:
			a = item
		elif int(item["id"]) == target:
			b = item
	var held: int = int(a["color"])
	a["color"] = int(b["color"])
	b["color"] = held
	a.erase("dye")
	a.erase("dye_target")
	return copy
