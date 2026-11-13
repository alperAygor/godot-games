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
## Kural çeşitlemeleri (derinleşme 2): her biri tanıtım seviyesinde tek başına ve tek adet gelir.
const JOKER_FROM_LEVEL: int = 23
const BIG_FROM_LEVEL: int = 29
const STAIN_FROM_LEVEL: int = 36
const CHAIN_FROM_LEVEL: int = 44
const WIND_FROM_LEVEL: int = 52
const INTRO_LEVELS: Array[int] = [WET_FROM_LEVEL, MYSTERY_FROM_LEVEL, LOCK_FROM_LEVEL,
	JOKER_FROM_LEVEL, SHEET_FROM_LEVEL, BIG_FROM_LEVEL, SOCK_FROM_LEVEL, STAIN_FROM_LEVEL,
	DYE_FROM_LEVEL, CHAIN_FROM_LEVEL, WIND_FROM_LEVEL]
const MAX_JOKERS: int = 2
const MAX_BIGS: int = 2
const MAX_STAINS: int = 3
const MAX_CHAINS: int = 2
const MAX_WIND_STEPS: int = 3
## Rüzgâr kaç hamlede bir eser (seviye verisine yazılır; oyuncu sayacı görür).
const WIND_EVERY_MOVES: int = 5
const WIND_EVERY_MOVES_LATE: int = 4
const WIND_FAST_FROM_LEVEL: int = 80
## Tanıtımdan sonraki iki seviyede mekanik kesin gelir (pekişsin); sonra her seviyede bu olasılıkla
## karışır. Neden olasılık: her şey her seviyede olursa tahta okunmaz, seviyeler birbirine benzer.
const MIX_SURE_LEVELS: int = 2
const MIX_CHANCE: float = 0.55
## Mekanik başına ayrı tohum tuzu: karışım kararları birbirinden ve ana düzenden bağımsız olsun.
const FEATURE_SALT: int = 104729
const MIX_SALTS: Dictionary = {"joker": 11, "big": 23, "stain": 37, "chain": 41, "wind": 53}
const PLACE_ATTEMPTS: int = 24
## Yeni mekanik yerleşimlerinin doğrulama bütçesi: başarılı doğrulama çoğunlukla çözüm yolu
## uzunluğu kadar düğümde biter; başarısız aday bütün bütçeyi yer. Düşük bütçe yalnız "daha az
## engel" demektir (güvenli taraf), üretim süresini mobilde makul tutar.
const PLACE_NODE_LIMIT: int = 4000
## Seviye hedefi kipleri: bir seviyede en fazla bir kip. Patron her 15'te (çok zorun yerine).
const MOVES_FROM_LEVEL: int = 16
const MOVES_EVERY: int = 7
const SHORT_RACK_FROM_LEVEL: int = 21
const SHORT_RACK_EVERY: int = 9
const ORDERS_FROM_LEVEL: int = 33
const ORDERS_EVERY: int = 11
const BOSS_FROM_LEVEL: int = 30
const BOSS_EVERY: int = 15
## Kipin ilk göründüğü seviyeler: o seviyede yeni mekanik karışmaz (kip tek başına öğrenilsin).
const MODE_INTRO_LEVELS: Array[int] = [MOVES_FROM_LEVEL, SHORT_RACK_FROM_LEVEL, BOSS_FROM_LEVEL, ORDERS_FROM_LEVEL]
## Hamle sınırı = çözüm yolu + pay; pay seviye ilerledikçe daralır.
const MOVES_SLACK_START: int = 8
const MOVES_SLACK_STEP: int = 15
const MOVES_SLACK_MIN: int = 3
## Kısa askı: önce 3, sonra 2 slot.
const SHORT_RACK_SLOTS: int = 3
const SHORT_RACK_TIGHT_SLOTS: int = 2
const SHORT_RACK_TIGHT_FROM_LEVEL: int = 48
## Sipariş: ilk kaç sepet, kaç aday sıra denenir.
const ORDER_COUNT: int = 3
const ORDER_ATTEMPTS: int = 3
## Patron: iki yarım tahta (her biri bir katman eksik), toplam normal seviyenin ~1.6 katı.
const BOSS_SIZE_RATIO: float = 1.6
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


## 26+ eğrisi: renk 5->7, karıştırma 40'tan sonra da büyür, her 5'te zor, her 15'te patron
## (eski "çok zor"un yerine: iki ekranlı büyük tahta), 56'dan itibaren 5 sütun. Tanıtım
## seviyeleri zor olmaz ve karıştırma yarıya iner: yeni engel oyuncuya sakin bir tahtada öğretilir.
static func _late_params(n: int) -> Dictionary:
	var intro: bool = n in INTRO_LEVELS
	var boss: bool = not intro and n >= BOSS_FROM_LEVEL and n % BOSS_EVERY == 0
	# Patron çok zorun yerini alır: zorluğu ek karıştırmadan değil, tahtanın büyüklüğünden gelir.
	var very_hard: bool = false
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
		"hard": hard, "very_hard": very_hard, "boss": boss}


static func generate(level: int) -> Dictionary:
	var params: Dictionary = params_for(level)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = maxi(level, 1) * SEED_SALT
	var number: int = maxi(level, 1)
	var mode: String = mode_for(number)
	var items: Array[Dictionary] = _boss_layout(params, rng) if mode == LaundryBoard.MODE_BOSS \
		else _layout(params, rng)
	var sheets: int = _new_obstacle_count(number, SHEET_FROM_LEVEL, MAX_SHEETS)
	if sheets > 0:
		_add_sheets(items, params, sheets, number, rng)
	# Yeni mekaniklerin kararları ayrı bir RNG ile verilir: ana düzenin rastgele dizisi (ve
	# böylece mekaniksiz seviyeler) değişmesin.
	var features: RandomNumberGenerator = RandomNumberGenerator.new()
	features.seed = number * FEATURE_SALT
	var bigs: int = mechanic_count(number, "big")
	if bigs > 0:
		_trim_for_big(items, bigs)
	var order: Array[int] = _removal_order(items, rng)
	var active: int = int(params["active_baskets"])
	var sizes: Array[int] = _group_sizes(order.size(), bigs, active, features, number == BIG_FROM_LEVEL)
	var queue: Array[int] = _assign_colors(items, order, int(params["colors"]), active, rng, sizes)
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
	var big_indices: Array[int] = []
	for index: int in range(sizes.size()):
		if sizes[index] == LaundryBoard.BIG_BASKET_CAPACITY:
			big_indices.append(index)
	if not big_indices.is_empty():
		result["big"] = big_indices
	var jokers: int = mechanic_count(number, "joker")
	if jokers > 0:
		_add_jokers(result, jokers, features, number == JOKER_FROM_LEVEL)
	_apply_mode_setup(result, mode, number)
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
	var stains: int = mechanic_count(number, "stain")
	if stains > 0:
		_add_stains(result, stains, features)
	var chains: int = mechanic_count(number, "chain")
	if chains > 0:
		_add_chains(result, chains, features)
	var gusts: int = mechanic_count(number, "wind")
	if gusts > 0:
		_add_wind(result, gusts, order, features)
	_finish_mode(result, mode, number, features)
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
		if LevelSolver.is_solvable(level, _lock_limit(number)):
			locks -= 1
		else:
			entry.erase("lock")


## Kilit doğrulama bütçesi: erken seviyeler eskisi gibi (birebir aynı kalsınlar); geç eğride
## reddedilen her kilit adayı bütün bütçeyi tükettiğinden üretim süresi için düşük tutulur.
static func _lock_limit(level: int) -> int:
	return LevelSolver.DEFAULT_NODE_LIMIT if level < LATE_CURVE_FROM_LEVEL else LATE_NODE_LIMIT


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
		# Patron: ikinci ekran ancak ilki boşalınca açılır; sıra da önce ilk ekranı bitirir.
		var screen: int = 1 << 30
		for id: Variant in remaining.keys():
			screen = mini(screen, int((remaining[id] as Dictionary).get("screen", 0)))
		var open: Array[int] = []
		for id: Variant in remaining.keys():
			if int((remaining[id] as Dictionary).get("screen", 0)) != screen:
				continue
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


## Sıra üçerli (büyük sepette beşli) gruplanır; her grup bir sepet rengidir. Aynı anda aktif
## olacak komşu sepetler farklı renkte seçilir. `sizes` boşsa hepsi 3'tür (eski seviyelerle birebir).
static func _assign_colors(items: Array[Dictionary], order: Array[int], colors: int,
		active: int, rng: RandomNumberGenerator, sizes: Array[int] = []) -> Array[int]:
	var queue: Array[int] = []
	var palette: int = clampi(colors, MIN_COLORS, MAX_COLORS)
	var group_count: int = order.size() / BASKET_CAPACITY if sizes.is_empty() else sizes.size()
	var start: int = 0
	for group: int in range(group_count):
		var color: int = rng.randi_range(0, palette - 1)
		var guard: int = 0
		while _recent_has(queue, color, active - 1) and guard < 20:
			color = (color + 1) % palette
			guard += 1
		queue.append(color)
		var size: int = BASKET_CAPACITY if sizes.is_empty() else sizes[group]
		for offset: int in range(size):
			var id: int = order[start + offset]
			items[_index_of(items, id)]["color"] = color
		start += size
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
		# Büyük/joker sepet rengiyle birlikte yer değiştirir (renk grubunun boyu sepete bağlı).
		_swap_kind(candidate, "big", a, b)
		_swap_kind(candidate, "jokers", a, b)
		if LevelSolver.is_solvable(candidate, node_limit):
			queue = swapped
			level["queue"] = swapped
			for key: String in ["big", "jokers"]:
				if candidate.has(key):
					level[key] = candidate[key]
			applied += 1


# --- Yeni engellerin yerleşimi ----------------------------------------------------------------

## Engelsiz, sıradan parça mı (yeni engeller birbirine ve eskilere binmesin).
static func _plain(entry: Dictionary) -> bool:
	for key: String in ["wet", "mystery", "lock", "sheet", "sock", "dye", "stain", "chain"]:
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
						and int(entry.get("screen", 0)) == 0 and absf(float(entry["slot"]) - center) <= half:
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
		var victim: int = _top_victim(items, covering)
		if victim < 0:
			return
		var victim_id: int = int(items[victim]["id"])
		items.remove_at(victim)
		for entry: Dictionary in items:
			(entry["blockers"] as Array).erase(victim_id)


## Kimseyi kapatmayan, çarşaf olmayan en son parçanın sırası (yoksa -1).
static func _top_victim(items: Array[Dictionary], covering: Dictionary) -> int:
	for index: int in range(items.size() - 1, -1, -1):
		var entry: Dictionary = items[index]
		if not entry.has("sheet") and not covering.has(int(entry["id"])):
			return index
	return -1


## Toplam `target` olana dek kimseyi kapatmayan en üst parçalar çıkarılır (büyük sepet ve patron
## boyutu için). Kapatmayan parça çıkarıldığı için kalan düzenin geçerliliği bozulmaz.
static func _trim_to_count(items: Array[Dictionary], target: int) -> void:
	while items.size() > target:
		var covering: Dictionary = {}
		for entry: Dictionary in items:
			for blocker: Variant in entry["blockers"] as Array:
				covering[int(blocker)] = true
		var victim: int = _top_victim(items, covering)
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


# --- Derinleşme 2: kural çeşitlemeleri ve seviye hedefi kipleri -------------------------------
# Her yerleşim `LevelSolver` ile tüm kurallar (joker, büyük sepet, leke, zincir, rüzgâr, kısa
# askı, iki ekran) altında doğrulanır; bozan yerleşim geri alınır. Böylece her seviye en iyi
# oyunla kesin çözülebilir kalır. Tanıtım seviyelerinde ilgili mekanik garanti edilir.

## Seviyenin kipi (takvim): patron > sipariş > kısa askı > hamle sınırı. Tanıtım seviyelerinde
## (yeni engel/mekanik öğretilirken) kip yoktur; patron bunun dışındadır (hiçbiri 15'in katı değil).
static func mode_for(level: int) -> String:
	if level >= BOSS_FROM_LEVEL and level % BOSS_EVERY == 0 and not level in INTRO_LEVELS:
		return LaundryBoard.MODE_BOSS
	if level in INTRO_LEVELS:
		return LaundryBoard.MODE_NONE
	if level >= ORDERS_FROM_LEVEL and (level - ORDERS_FROM_LEVEL) % ORDERS_EVERY == 0:
		return LaundryBoard.MODE_ORDERS
	if level >= SHORT_RACK_FROM_LEVEL and (level - SHORT_RACK_FROM_LEVEL) % SHORT_RACK_EVERY == 0:
		return LaundryBoard.MODE_SHORT_RACK
	if level >= MOVES_FROM_LEVEL and (level - MOVES_FROM_LEVEL) % MOVES_EVERY == 0:
		return LaundryBoard.MODE_MOVES
	return LaundryBoard.MODE_NONE


static func _mechanic_from(mechanic: String) -> int:
	match mechanic:
		"joker":
			return JOKER_FROM_LEVEL
		"big":
			return BIG_FROM_LEVEL
		"stain":
			return STAIN_FROM_LEVEL
		"chain":
			return CHAIN_FROM_LEVEL
		"wind":
			return WIND_FROM_LEVEL
	return 1 << 30


static func _mechanic_max(mechanic: String) -> int:
	match mechanic:
		"joker":
			return MAX_JOKERS
		"big":
			return MAX_BIGS
		"stain":
			return MAX_STAINS
		"chain":
			return MAX_CHAINS
		"wind":
			return MAX_WIND_STEPS
	return 0


## Mekaniğin bu seviyedeki adedi: tanıtımda 1 (tek başına), başka bir tanıtım ya da kip tanıtım
## seviyesinde 0, sonraki iki seviyede kesin, sonra deterministik karışım (MIX_CHANCE).
static func mechanic_count(level: int, mechanic: String) -> int:
	var from: int = _mechanic_from(mechanic)
	if level < from:
		return 0
	if level == from:
		return 1
	if level in INTRO_LEVELS or level in MODE_INTRO_LEVELS:
		return 0
	if level - from > MIX_SURE_LEVELS:
		var roll: RandomNumberGenerator = RandomNumberGenerator.new()
		roll.seed = level * FEATURE_SALT + int(MIX_SALTS.get(mechanic, 0))
		if roll.randf() >= MIX_CHANCE:
			return 0
	return obstacle_count(level, from, _mechanic_max(mechanic))


## Patron tahtası: iki yarım düzen (her biri bir katman eksik), ikincisi `screen: 1`. Toplam,
## aynı seviyenin normal tahtasının ~1.6 katına kırpılır. Toplama sırası önce ilk ekranı bitirdiği
## için "sıra = kuyruk" kanıtı iki ekranda da geçerlidir (askı ve sepetler ekranlar arasında sürer).
static func _boss_layout(params: Dictionary, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var probe: RandomNumberGenerator = RandomNumberGenerator.new()
	probe.seed = rng.seed
	probe.state = rng.state
	var normal: int = _layout(params, probe).size()
	var half: Dictionary = params.duplicate()
	half["layers"] = maxi(int(params["layers"]) - 1, 2)
	var items: Array[Dictionary] = _layout(half, rng)
	var second: Array[Dictionary] = _layout(half, rng)
	var offset: int = 0
	for entry: Dictionary in items:
		offset = maxi(offset, int(entry["id"]) + 1)
	for entry: Dictionary in second:
		entry["id"] = int(entry["id"]) + offset
		var shifted: Array[int] = []
		for blocker: Variant in entry["blockers"] as Array:
			shifted.append(int(blocker) + offset)
		entry["blockers"] = shifted
		entry["screen"] = 1
		items.append(entry)
	var target: int = int(round(float(normal) * BOSS_SIZE_RATIO / float(BASKET_CAPACITY))) * BASKET_CAPACITY
	_trim_to_count(items, maxi(target, normal))
	return items


## Büyük sepet b adetse toplam 3g + 2b olmalı: en üstten 0-2 parça çıkarılır.
static func _trim_for_big(items: Array[Dictionary], bigs: int) -> void:
	var target: int = items.size()
	while (target - 2 * bigs) % BASKET_CAPACITY != 0:
		target -= 1
	_trim_to_count(items, target)


## Grup boyları: `bigs` grup 5, kalanı 3. Büyük sepet başlangıçta aktif olmaz (oyuncu önce
## kuyruktaki farklı sepeti görsün) ve iki büyük sepet yan yana gelmez. Tanıtımda (`early`) ilk
## aktif olmayan sıraya konur: oyuncu yeni sepeti beklemeden görür.
static func _group_sizes(total: int, bigs: int, active: int, features: RandomNumberGenerator,
		early: bool = false) -> Array[int]:
	var sizes: Array[int] = []
	if bigs <= 0:
		return sizes
	var groups: int = (total - 2 * bigs) / BASKET_CAPACITY
	for _i: int in range(groups):
		sizes.append(BASKET_CAPACITY)
	var candidates: Array[int] = []
	for index: int in range(mini(active, groups - 1), groups):
		candidates.append(index)
	if not early:
		_shuffle(candidates, features)
	var placed: int = 0
	for index: int in candidates:
		if placed >= bigs:
			break
		if (index > 0 and sizes[index - 1] != BASKET_CAPACITY) \
				or (index + 1 < groups and sizes[index + 1] != BASKET_CAPACITY):
			continue
		sizes[index] = LaundryBoard.BIG_BASKET_CAPACITY
		placed += 1
	# Yerleşemeyen büyük sepetin 2 fazla parçası kalmasın: grup sayısı boyu tutmalı.
	var sum: int = 0
	for size: int in sizes:
		sum += size
	while sum < total and not sizes.is_empty():
		for index: int in range(sizes.size()):
			if sizes[index] == BASKET_CAPACITY and sum < total:
				sizes[index] = LaundryBoard.BIG_BASKET_CAPACITY
				sum += 2
	return sizes


## Büyük sepetin renk grubu 5'li olduğundan kuyruk değişiminde sepet türü renkle birlikte taşınır.
static func _swap_kind(level: Dictionary, key: String, a: int, b: int) -> void:
	if not level.has(key):
		return
	var swapped: Array[int] = []
	for entry: Variant in level[key] as Array:
		var index: int = int(entry)
		swapped.append(b if index == a else (a if index == b else index))
	swapped.sort()
	level[key] = swapped


## Joker: kuyrukta normal (3'lük) bir sepet joker olur; kuyruktaki rengi = çözüm yolunda alacağı
## renk (`ref`). Başta aktif olmaz; yan yana iki joker gelmez. Tanıtımda (`early`) ilk boşalan
## sepetin yerine gelir: oyuncu jokeri ilk dakikada görür.
static func _add_jokers(level: Dictionary, count: int, features: RandomNumberGenerator,
		early: bool = false) -> void:
	var queue: Array = level["queue"] as Array
	var big: Array = level.get("big", []) as Array
	var active: int = int(level["active_baskets"])
	var candidates: Array[int] = []
	for index: int in range(active, queue.size()):
		if not big.has(index):
			candidates.append(index)
	if not early:
		_shuffle(candidates, features)
	var chosen: Array[int] = []
	for index: int in candidates:
		if chosen.size() >= count:
			break
		if chosen.has(index - 1) or chosen.has(index + 1):
			continue
		chosen.append(index)
		level["jokers"] = chosen.duplicate()
		if not LevelSolver.is_solvable(level, PLACE_NODE_LIMIT):
			chosen.pop_back()
	chosen.sort()
	if chosen.is_empty():
		level.erase("jokers")
	else:
		level["jokers"] = chosen


## Kipin kuralı karıştırmadan ÖNCE kurulur (kısa askı doğrulamalara girsin).
static func _apply_mode_setup(level: Dictionary, mode: String, number: int) -> void:
	if mode == LaundryBoard.MODE_NONE:
		return
	level["mode"] = mode
	if mode == LaundryBoard.MODE_SHORT_RACK:
		level["rack_slots"] = SHORT_RACK_TIGHT_SLOTS if number >= SHORT_RACK_TIGHT_FROM_LEVEL else SHORT_RACK_SLOTS


## Kipin sonuç alanları en son (tüm engeller yerleştikten sonra) hesaplanır.
static func _finish_mode(level: Dictionary, mode: String, number: int, features: RandomNumberGenerator) -> void:
	match mode:
		LaundryBoard.MODE_MOVES:
			var path: Array[int] = LevelSolver.solve(level, LevelSolver.DEFAULT_NODE_LIMIT)
			var slack: int = clampi(MOVES_SLACK_START - (number - MOVES_FROM_LEVEL) / MOVES_SLACK_STEP,
				MOVES_SLACK_MIN, MOVES_SLACK_START)
			# Yol bulunamazsa (bütçe) cömert sınır: her parça + her ıslak sıkma, pay iki katı.
			var base: int = path.size() if not path.is_empty() else _min_moves(level) + slack
			level["move_limit"] = base + slack
		LaundryBoard.MODE_ORDERS:
			_add_orders(level, features)


static func _min_moves(level: Dictionary) -> int:
	var total: int = 0
	for entry: Variant in level["items"] as Array:
		total += 2 if (entry as Dictionary).has("wet") else 1
	return total


## Sipariş: çözüm yolunun ilk üç tamamlanan sepeti (kuyruk sıraları) bulunur; adaylar bunların
## farklı sıralamalarıdır (doğal sıra kolaydır, bonusu anlamsızlaştırır). Her aday, sıra bozulunca
## kayıp sayan "katı" kopyayla çözücüde sınanır: siparişin en iyi oyunla yapılabildiği kanıtlanır.
## Neden yalnız bu üçünün sıralamaları: hepsi başta ya da hemen sonra aktif olan sepetlerdir, bu
## yüzden çoğu yapılabilir ve başarısız (bütçeyi tüketen) aramalar azalır. Hiçbiri olmazsa doğal sıra.
static func _add_orders(level: Dictionary, features: RandomNumberGenerator) -> void:
	var natural: Array[int] = _natural_orders(level)
	var queue: Array = level["queue"] as Array
	var candidates: Array[Array] = []
	if natural.size() == ORDER_COUNT:
		for perm: Array in [[0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]]:
			var candidate: Array[int] = []
			for at: Variant in perm:
				candidate.append(natural[int(at)])
			var colors: Dictionary = {}
			for index: int in candidate:
				colors[int(queue[index])] = true
			if colors.size() == ORDER_COUNT:
				candidates.append(candidate)
	for index: int in range(candidates.size() - 1, 0, -1):
		var other: int = features.randi_range(0, index)
		var held: Array = candidates[index]
		candidates[index] = candidates[other]
		candidates[other] = held
	for attempt: int in range(mini(ORDER_ATTEMPTS, candidates.size())):
		var strict: Dictionary = level.duplicate()
		strict["orders"] = candidates[attempt]
		strict["orders_strict"] = true
		if LevelSolver.is_solvable(strict, PLACE_NODE_LIMIT):
			level["orders"] = candidates[attempt]
			return
	level["orders"] = natural


static func _natural_orders(level: Dictionary) -> Array[int]:
	var result: Array[int] = []
	var path: Array[int] = LevelSolver.solve(level, LevelSolver.DEFAULT_NODE_LIMIT)
	var board: LaundryBoard = LaundryBoard.new(level)
	var queue: Array = level["queue"] as Array
	var used: Dictionary = {}
	for id: int in path:
		for event: Dictionary in board.tap(id):
			if String(event["type"]) != LaundryBoard.EVENT_BASKET_DONE or result.size() >= ORDER_COUNT:
				continue
			for index: int in range(queue.size()):
				if not used.has(index) and int(queue[index]) == int(event["color"]):
					used[index] = true
					result.append(index)
					break
	return result


## Yerleşim adayları: rastgele sıralı, engelsiz parçalar.
static func _plain_pool(items: Array[Dictionary], features: RandomNumberGenerator) -> Array[int]:
	var pool: Array[int] = []
	for index: int in range(items.size()):
		if _plain(items[index]):
			pool.append(index)
	_shuffle(pool, features)
	return pool


## Lekeli: sıradan bir parça; her biri çözücüyle doğrulanır.
static func _add_stains(level: Dictionary, count: int, features: RandomNumberGenerator) -> void:
	var items: Array[Dictionary] = level["items"] as Array[Dictionary]
	var left: int = count
	var tries: int = 0
	for index: int in _plain_pool(items, features):
		if left <= 0 or tries >= PLACE_ATTEMPTS:
			break
		tries += 1
		items[index]["stain"] = true
		if LevelSolver.is_solvable(level, PLACE_NODE_LIMIT):
			left -= 1
		else:
			items[index].erase("stain")


## Zincirli mandal: aynı ip, aynı katman, aynı ekranda yan yana (slot farkı 1) iki sıradan parça.
static func _add_chains(level: Dictionary, count: int, features: RandomNumberGenerator) -> void:
	var items: Array[Dictionary] = level["items"] as Array[Dictionary]
	var pairs: Array[Vector2i] = []
	for a: int in range(items.size()):
		for b: int in range(a + 1, items.size()):
			var first: Dictionary = items[a]
			var second: Dictionary = items[b]
			if int(first["line"]) != int(second["line"]) or int(first["layer"]) != int(second["layer"]) \
					or int(first.get("screen", 0)) != int(second.get("screen", 0)):
				continue
			if absf(float(first["slot"]) - float(second["slot"])) != 1.0:
				continue
			pairs.append(Vector2i(a, b))
	for index: int in range(pairs.size() - 1, 0, -1):
		var other: int = features.randi_range(0, index)
		var held: Vector2i = pairs[index]
		pairs[index] = pairs[other]
		pairs[other] = held
	# Önce ikisi de başta açık (üstte) olan çiftler: ortak mandal ekranda açıkça görünsün.
	var ordered: Array[Vector2i] = []
	for strict: bool in [true, false]:
		for pair: Vector2i in pairs:
			var open: bool = (items[pair.x]["blockers"] as Array).is_empty() \
				and (items[pair.y]["blockers"] as Array).is_empty()
			if open == strict:
				ordered.append(pair)
	var left: int = count
	var tries: int = 0
	for pair: Vector2i in ordered:
		if left <= 0 or tries >= PLACE_ATTEMPTS:
			break
		var first: Dictionary = items[pair.x]
		var second: Dictionary = items[pair.y]
		if not _plain(first) or not _plain(second):
			continue
		tries += 1
		first["chain"] = int(second["id"])
		second["chain"] = int(first["id"])
		if LevelSolver.is_solvable(level, PLACE_NODE_LIMIT):
			left -= 1
		else:
			first.erase("chain")
			second.erase("chain")


## Rüzgâr: adım k (0'dan) k+1'inci sayaç bitiminde, yani (k+1)*every hamlede eser. Savrulan ve
## örtülen aynı ip ve ekranda komşudur (slot farkı <= 1), örtülenin katmanı savrulanınkinden
## yüksek değildir ve örtülen savrulanı (dolaylı) örtmez -> döngü yok. Anlamlı olsun diye ikisi
## de çözüm sırasında rüzgâr anından sonra alınan parçalardan seçilir. Her adım doğrulanır.
static func _add_wind(level: Dictionary, steps: int, order: Array[int], features: RandomNumberGenerator) -> void:
	var items: Array[Dictionary] = level["items"] as Array[Dictionary]
	var every: int = WIND_EVERY_MOVES_LATE if int(level["level"]) >= WIND_FAST_FROM_LEVEL else WIND_EVERY_MOVES
	var rank: Dictionary = {}
	for position: int in range(order.size()):
		rank[order[position]] = position
	var by_id: Dictionary = {}
	for entry: Dictionary in items:
		by_id[int(entry["id"])] = entry
	var chosen: Array = []
	level["wind"] = {"every": every, "steps": chosen}
	var used: Dictionary = {}
	for step: int in range(steps):
		var fire_at: int = (step + 1) * every
		var placed: bool = false
		# Önce ikisi de başta açık (en üstte) olan çiftler: savrulma ekranda açıkça görünsün.
		# Bulunamazsa örtülü parçalar da denenir (kural yine doğru; yalnız daha az göze çarpar).
		for strict: bool in [true, false]:
			if placed:
				break
			var movers: Array[int] = []
			for index: int in range(items.size()):
				var entry: Dictionary = items[index]
				if _plain(entry) and not used.has(int(entry["id"])) and int(rank.get(int(entry["id"]), 0)) > fire_at \
						and (not strict or (entry["blockers"] as Array).is_empty()):
					movers.append(index)
			_shuffle(movers, features)
			var tries: int = 0
			for index: int in movers:
				if placed or tries >= PLACE_ATTEMPTS:
					break
				var mover: Dictionary = items[index]
				var mover_id: int = int(mover["id"])
				for target: Dictionary in items:
					var target_id: int = int(target["id"])
					if target_id == mover_id or used.has(target_id) or target.has("sheet") \
							or int(target["line"]) != int(mover["line"]) \
							or int(target.get("screen", 0)) != int(mover.get("screen", 0)) \
							or absf(float(target["slot"]) - float(mover["slot"])) > 1.0 \
							or int(target["layer"]) > int(mover["layer"]) \
							or (strict and not (target["blockers"] as Array).is_empty()) \
							or int(rank.get(target_id, 0)) <= fire_at \
							or (target["blockers"] as Array).has(mover_id) \
							or _reaches(by_id, chosen, target_id, mover_id):
						continue
					tries += 1
					chosen.append([mover_id, target_id])
					if LevelSolver.is_solvable(level, PLACE_NODE_LIMIT):
						used[mover_id] = true
						used[target_id] = true
						placed = true
						break
					chosen.pop_back()
					if tries >= PLACE_ATTEMPTS:
						break
		if not placed:
			break
	if chosen.is_empty():
		level.erase("wind")


## `top`, `bottom`u kapatma zinciriyle (rüzgâr adımları dahil) örtüyor mu: döngü denetimi.
static func _reaches(by_id: Dictionary, wind_steps: Array, top: int, bottom: int) -> bool:
	var stack: Array[int] = [bottom]
	var seen: Dictionary = {}
	while not stack.is_empty():
		var current: int = stack.pop_back()
		if seen.has(current):
			continue
		seen[current] = true
		var above: Array[int] = []
		for blocker: Variant in (by_id[current] as Dictionary)["blockers"] as Array:
			above.append(int(blocker))
		for step: Variant in wind_steps:
			if int((step as Array)[1]) == current:
				above.append(int((step as Array)[0]))
		for blocker: int in above:
			if blocker == top:
				return true
			stack.append(blocker)
	return false
