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
## Sürgülü ip: bir ipin üst sırası birkaç hamlede bir yana kayıp geri gelir.
const SLIDE_FROM_LEVEL: int = 58
const MAX_SLIDES: int = 1
const SLIDE_EVERY_MOVES: int = 4
const SLIDE_EVERY_MOVES_LATE: int = 3
const SLIDE_FAST_FROM_LEVEL: int = 90
## Derinleşme 3: makineler ve misafirler (her biri kendi tanıtım seviyesinde TEK BAŞINA gelir).
const WASHER_FROM_LEVEL: int = 64
const DRYER_FROM_LEVEL: int = 70
const TYPED_FROM_LEVEL: int = 76
const BIRDS_FROM_LEVEL: int = 82
const RAIN_FROM_LEVEL: int = 88
const CAT_FROM_LEVEL: int = 94
## Derinleşme 4: çift renkli çamaşır ve mevsim olayları (her biri kendi tanıtımında TEK BAŞINA).
## Mevsim tanıtımları kendi mevsim bandının (SeasonCycle) başka tanıtım olmayan ilk uygun seviyesidir.
const DUAL_FROM_LEVEL: int = 18
const SUN_FROM_LEVEL: int = 22
const LEAVES_FROM_LEVEL: int = 31
const FROST_FROM_LEVEL: int = 61
const POLLEN_FROM_LEVEL: int = 91
const INTRO_LEVELS: Array[int] = [WET_FROM_LEVEL, MYSTERY_FROM_LEVEL, LOCK_FROM_LEVEL,
	JOKER_FROM_LEVEL, SHEET_FROM_LEVEL, BIG_FROM_LEVEL, SOCK_FROM_LEVEL, STAIN_FROM_LEVEL,
	DYE_FROM_LEVEL, CHAIN_FROM_LEVEL, WIND_FROM_LEVEL, SLIDE_FROM_LEVEL,
	WASHER_FROM_LEVEL, DRYER_FROM_LEVEL, TYPED_FROM_LEVEL, BIRDS_FROM_LEVEL, RAIN_FROM_LEVEL, CAT_FROM_LEVEL,
	DUAL_FROM_LEVEL, SUN_FROM_LEVEL, LEAVES_FROM_LEVEL, FROST_FROM_LEVEL, POLLEN_FROM_LEVEL]
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
const MIX_SALTS: Dictionary = {"joker": 11, "big": 23, "stain": 37, "chain": 41, "wind": 53, "slide": 67,
	"washer": 71, "dryer": 79, "typed": 83, "birds": 89, "rain": 97, "cat": 101, "dual": 103}
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
## Bu seviyeden sonra (yeni mekaniklerin geldiği yer) eski engellerin yerleşim denemeleri de
## sınırlanır: en ağır seviyelerin üretimi mobilde birkaç saniyeyi aşıyordu. Öncesi birebir aynı.
const LEAN_FROM_LEVEL: int = 64
const LEAN_TRIES: int = 3
const LEAN_ORDER_ATTEMPTS: int = 1
const LEAN_NODE_LIMIT: int = 1500
## 64+ yerleşim doğrulama bütçesi (tanık yolu geçmezse): başarılı aramalar çoğunlukla bunun altında
## biter, başarısız aday bütçenin tamamını yer. Düşük bütçe yalnız "daha az engel" demektir (güvenli).
const LEAN_PLACE_LIMIT: int = 2000
## 64+ mevsim işareti için ek deneme (adet + bu kadar).
const LEAN_EXTRA_TRIES: int = 1


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
	if gusts > 0 and _timed_ok(number, "wind"):
		_add_wind(result, gusts, order, features)
	if mechanic_count(number, "slide") > 0 and mode != LaundryBoard.MODE_BOSS and _timed_ok(number, "slide"):
		_add_slide(result, number)
	var pairs: int = mini(mechanic_count(number, "dual"), 1 + (number - DUAL_FROM_LEVEL) / DUAL_RAMP_LEVELS)
	if pairs > 0:
		_add_duals(result, pairs, number)
	_add_extras(result, number)
	_finish_mode(result, mode, number, features)
	# Mevsim olayı EN SON eklenir (ayrı RNG): mevsimsiz kararlar ve 64 öncesi seviyelerin geri kalanı
	# birebir aynı kalır; yalnız mevsim anahtarları eklenir (tanıtım seviyeleri hariç).
	_add_season(result, number)
	result.erase(WITNESS_KEY)
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
	var tries: int = 0
	for index: int in pool:
		if locks <= 0 or queue.size() < 3:
			break
		var entry: Dictionary = items[index]
		if entry.has("wet") or entry.has("mystery"):
			continue
		var key_color: int = int(queue[rng.randi_range(0, mini(2, queue.size() - 1))])
		if key_color == int(entry["color"]):
			continue
		# Geç seviyelerde reddedilen her aday bütçenin tamamını yer: deneme sayısı sınırlanır.
		tries += 1
		if number >= LEAN_FROM_LEVEL and tries > LEAN_TRIES:
			break
		entry["lock"] = key_color
		if _verify(level, _lock_limit(number) if number < LEAN_FROM_LEVEL else PLACE_NODE_LIMIT):
			locks -= 1
		else:
			entry.erase("lock")


## Hamle sınırı/sipariş için çözüm yolu bütçesi: 64 öncesi eskisi gibi (seviyeler birebir kalsın);
## sonrasında başarısız arama bütçenin tamamını yediğinden düşük (bulunamazsa cömert sınır).
static func _path_limit(level: int) -> int:
	return LevelSolver.DEFAULT_NODE_LIMIT if level < LEAN_FROM_LEVEL else LATE_NODE_LIMIT


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
		if _verify(candidate, node_limit):
			queue = swapped
			level["queue"] = swapped
			if candidate.has(WITNESS_KEY):
				level[WITNESS_KEY] = candidate[WITNESS_KEY]
			for key: String in ["big", "jokers"]:
				if candidate.has(key):
					level[key] = candidate[key]
			applied += 1


# --- Yeni engellerin yerleşimi ----------------------------------------------------------------

## Engelsiz, sıradan parça mı (yeni engeller birbirine ve eskilere binmesin).
static func _plain(entry: Dictionary) -> bool:
	for key: String in PLAIN_BLOCKING_KEYS:
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
	var lean: bool = int(level["level"]) >= LEAN_FROM_LEVEL
	var tries: int = 0
	for k: int in starts:
		if left <= 0 or (lean and tries >= LEAN_TRIES):
			break
		var first: Dictionary = items[_index_of(items, order[k])]
		var second: Dictionary = items[_index_of(items, order[k + 1])]
		if not _plain(first) or not _plain(second):
			continue
		var kinds: Array[int] = [int(first["kind"]), int(second["kind"])]
		tries += 1
		first["sock"] = order[k + 1]
		second["sock"] = order[k]
		first["kind"] = SOCK_KIND
		second["kind"] = SOCK_KIND
		if _verify(level, LATE_NODE_LIMIT if not lean else PLACE_NODE_LIMIT):
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
	var lean: bool = int(level["level"]) >= LEAN_FROM_LEVEL
	var tries: int = 0
	for index: int in pool:
		if left <= 0 or (lean and tries >= LEAN_TRIES):
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
		tries += 1
		entry["dye"] = LaundryBoard.DEFAULT_DYE_MOVES
		entry["dye_target"] = target
		var budget: int = LATE_NODE_LIMIT if not lean else PLACE_NODE_LIMIT
		if _verify(level, budget) \
				and _verify(_bled_variant(level, id, target), budget):
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
		"slide":
			return SLIDE_FROM_LEVEL
		"washer":
			return WASHER_FROM_LEVEL
		"dryer":
			return DRYER_FROM_LEVEL
		"typed":
			return TYPED_FROM_LEVEL
		"birds":
			return BIRDS_FROM_LEVEL
		"rain":
			return RAIN_FROM_LEVEL
		"cat":
			return CAT_FROM_LEVEL
		"dual":
			return DUAL_FROM_LEVEL
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
		"slide":
			return MAX_SLIDES
		"washer":
			return MAX_DIRTY
		"dryer":
			return 1
		"typed":
			return MAX_TYPED
		"birds":
			return MAX_BIRDS
		"rain":
			return MAX_RAIN_STEPS
		"cat":
			return MAX_CAT_NAPS
		"dual":
			return MAX_DUAL_PAIRS
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
		if not _verify(level, PLACE_NODE_LIMIT):
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
			var path: Array[int] = _path(level, _path_limit(number))
			var slack: int = clampi(MOVES_SLACK_START - (number - MOVES_FROM_LEVEL) / MOVES_SLACK_STEP,
				MOVES_SLACK_MIN, MOVES_SLACK_START)
			# Yol bulunamazsa (bütçe) cömert sınır: her parça + her ıslak sıkma, pay iki katı.
			# Kuşu kovalamak/kediyi sevmek (negatif kimlik) hamle sayılmaz.
			var base: int = _real_moves(path) if not path.is_empty() else _min_moves(level) + slack
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
	var lean: bool = int(level["level"]) >= LEAN_FROM_LEVEL
	for attempt: int in range(mini(ORDER_ATTEMPTS if not lean else LEAN_ORDER_ATTEMPTS, candidates.size())):
		var strict: Dictionary = level.duplicate()
		strict["orders"] = candidates[attempt]
		strict["orders_strict"] = true
		if _verify(strict, PLACE_NODE_LIMIT if not lean else LEAN_NODE_LIMIT):
			level["orders"] = candidates[attempt]
			return
	level["orders"] = natural


static func _natural_orders(level: Dictionary) -> Array[int]:
	var result: Array[int] = []
	var path: Array[int] = _path(level, _path_limit(int(level["level"])))
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
		if _verify(level, PLACE_NODE_LIMIT):
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
		if _verify(level, PLACE_NODE_LIMIT):
			left -= 1
		else:
			first.erase("chain")
			second.erase("chain")


## Rüzgâr: adım k (0'dan) k+1'inci sayaç bitiminde, yani (k+1)*every hamlede eser. Savrulan ve
## örtülen aynı ip ve ekranda komşudur (slot farkı <= 1), örtülenin katmanı savrulanınkinden
## yüksek değildir ve örtülen savrulanı (dolaylı) örtmez -> döngü yok. Anlamlı olsun diye ikisi
## de çözüm sırasında rüzgâr anından sonra alınan parçalardan seçilir. Her adım doğrulanır.
## Sürgülü ip: en üst sırası katman 1 olan bir ipte, o sıranın TÜM parçaları birlikte bir sütun
## kayar ve geri gelir. Kayanların örtmesi sabit `blockers`tan çıkarılıp faz tablolarına taşınır:
##   faz 0 = başlangıç (yarım kaymış parça c ve c+1 sütunlarını örter),
##   faz 1 = bir sütun kaymış hali (c+yön ve c+1+yön).
## Çözülebilirlik çözücüyle doğrulanır (çözücü kaymayı kural olarak oynar); doğrulanamazsa geri alınır.
static func _add_slide(level: Dictionary, number: int) -> void:
	var items: Array[Dictionary] = level["items"] as Array[Dictionary]
	var every: int = SLIDE_EVERY_MOVES_LATE if number >= SLIDE_FAST_FROM_LEVEL else SLIDE_EVERY_MOVES
	var top_layer: Dictionary = {}
	var columns: int = 0
	for entry: Dictionary in items:
		if int(entry.get("screen", 0)) != 0 or entry.has("sheet"):
			continue
		var line: int = int(entry["line"])
		top_layer[line] = maxi(int(top_layer.get(line, 0)), int(entry["layer"]))
		if int(entry["layer"]) == 0:
			columns = maxi(columns, int(float(entry["slot"])) + 1)
	var lines: Array = top_layer.keys()
	lines.sort()
	for line: Variant in lines:
		var top: int = int(top_layer[line])
		if top < 1:
			continue
		# Kayan sıra = ipin en üst katmanı; örttüğü sıra = bir alt katman (yarım sütun kaymış dizilir).
		# Konumlar yarım sütun adımlı olduğundan anahtar olarak 2 x slot (tamsayı) kullanılır.
		var base: Dictionary = {}
		var sliders: Array[Dictionary] = []
		var usable: bool = true
		for entry: Dictionary in items:
			if int(entry["line"]) != int(line) or int(entry.get("screen", 0)) != 0:
				continue
			if entry.has("sheet") or entry.has("chain") or entry.has("sock"):
				usable = false
			elif number >= LEAN_FROM_LEVEL and int(entry["layer"]) == top and not _plain(entry):
				# 64+: kayan parçada başka rozet olmasın (sürgü rozeti üst üste binmesin; yoğun tahta).
				usable = false
			elif int(entry["layer"]) == top - 1:
				base[int(round(float(entry["slot"]) * 2.0))] = int(entry["id"])
			elif int(entry["layer"]) == top:
				sliders.append(entry)
		if not usable or sliders.is_empty():
			continue
		var low: float = float(columns)
		var high: float = -1.0
		for slider: Dictionary in sliders:
			low = minf(low, float(slider["slot"]))
			high = maxf(high, float(slider["slot"]))
		# Katman k'nin geçerli konum aralığı [k/2, sütun-1-k/2]; kayınca bunun dışına taşmamalı.
		var edge: float = float(top) * 0.5
		var shift: int = 0
		if high + 1.0 <= float(columns - 1) - edge + 0.001:
			shift = 1
		elif low - 1.0 >= edge - 0.001:
			shift = -1
		if shift == 0:
			continue
		var phases: Array = [{}, {}]
		var slider_ids: Array[int] = []
		for slider: Dictionary in sliders:
			var id: int = int(slider["id"])
			slider_ids.append(id)
			var doubled: int = int(round(float(slider["slot"]) * 2.0))
			for phase: int in range(2):
				for covered: int in [doubled - 1 + 2 * shift * phase, doubled + 1 + 2 * shift * phase]:
					if base.has(covered):
						var table: Dictionary = phases[phase] as Dictionary
						if not table.has(base[covered]):
							table[base[covered]] = [] as Array[int]
						(table[base[covered]] as Array[int]).append(id)
		var removed: Array = []
		for entry: Dictionary in items:
			var blockers: Array = entry["blockers"] as Array
			for id: int in slider_ids:
				if blockers.has(id):
					blockers.erase(id)
					removed.append([entry, id])
		for slider: Dictionary in sliders:
			slider["slide"] = shift
		level["slide"] = {"every": every, "line": int(line), "shift": shift, "sliders": slider_ids,
			"phases": phases}
		if _verify(level, PLACE_NODE_LIMIT):
			return
		for pair: Variant in removed:
			(((pair as Array)[0] as Dictionary)["blockers"] as Array).append(int((pair as Array)[1]))
		for slider: Dictionary in sliders:
			slider.erase("slide")
		level.erase("slide")


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
					if _verify(level, PLACE_NODE_LIMIT):
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


# --- Derinleşme 3: makineler ve misafirler ------------------------------------------------------
# Kurallar `LaundryBoard` son bölümündedir. Her yerleşim çözücüyle YÜKSELTMESİZ makinelerle
# (kapasite 2; yıkama 3, kurutma 2 hamle) doğrulanır: yükseltmeler yalnız kolaylaştırır. Kuş ve
# kedi için ayrıca "oyuncu hiç kovalamaz/sevmez" varyantı doğrulanır (yardımsız da kazanılır);
# yardımlı oyun kuşsuz/kedisiz tahtayla aynıdır, o zaten doğrulanmıştır. Doğrulanamayan yerleşim
# geri alınır (daha az engel = güvenli taraf).

const MAX_DIRTY: int = 3
const MAX_TYPED: int = 1
const MAX_BIRDS: int = 3
const MAX_RAIN_STEPS: int = 2
const MAX_CAT_NAPS: int = 2
## Tanıtım seviyelerinde kaç parça: makinenin kapasitesini (2) bir kerede gösterir.
const WASHER_INTRO_DIRTY: int = 2
const DRYER_INTRO_WET: int = 2
## Misafir aralıkları (hamle); geç seviyelerde kuş daha sık gelir.
const BIRD_EVERY_MOVES: int = 5
const BIRD_EVERY_MOVES_LATE: int = 4
const BIRD_FAST_FROM_LEVEL: int = 110
const RAIN_EVERY_MOVES: int = 6
const CAT_EVERY_MOVES: int = 7
## Bir yağmur adımı en az bu kadar açık parçayı ıslatmalı (yoksa bulut anlamsız kalır).
const RAIN_MIN_SOAK: int = 2
## Aday deneme sınırları (başarısız doğrulama bütün bütçeyi yer: üretim süresi için düşük).
const EXTRA_TRIES: int = 3
## Türlü sepetin seçebileceği türler (havlu çarşafla, çorap çiftle karışmasın diye yok).
const TYPED_KINDS: Array[int] = [0, 1, 2, 4, 5]
## Aynı anda en fazla bu kadar sayaçlı mekanik (rüzgâr, sürgü, kuş, yağmur, kedi): sağdaki
## sayaç hapları ve oyuncunun dikkati sınırlı. Yeni gelen önceliklidir.
const MAX_TIMED_MECHANICS: int = 2
const TIMED_CAP_FROM_LEVEL: int = BIRDS_FROM_LEVEL
## Mevsim sayaçları (polen, yaprak) önceliklidir: mevsimin imzası o bantta görünsün.
const TIMED_PRIORITY: Array[String] = ["pollen", "leaves", "cat", "rain", "birds", "slide", "wind"]
## Bir seviyede en fazla bu kadar yeni mekanik (makine/misafir) karışır; en yenisi önce.
const MAX_NEW_MECHANICS: int = 2
const NEW_PRIORITY: Array[String] = ["cat", "rain", "birds", "typed", "dryer", "washer"]
## Yeni mekaniklerin kendi rastgele dizisi: eski mekaniklerin kararları değişmesin.
const EXTRA_SALT: int = 7907


## Sayaçlı mekanik bu seviyede yer alabilir mi (en fazla MAX_TIMED_MECHANICS; 82 öncesi sınırsız,
## böylece eski seviyeler değişmez).
static func _timed_ok(number: int, mechanic: String) -> bool:
	if number < TIMED_CAP_FROM_LEVEL:
		return true
	var allowed: Array[String] = []
	for name: String in TIMED_PRIORITY:
		if _any_count(number, name) <= 0:
			continue
		if name == "slide" and mode_for(number) == LaundryBoard.MODE_BOSS:
			continue
		allowed.append(name)
	var at: int = allowed.find(mechanic)
	return at >= 0 and at < MAX_TIMED_MECHANICS


## Bu seviyede yer alan yeni mekanikler (en yenisi önce, en fazla MAX_NEW_MECHANICS): her şey
## her seviyede olursa tahta okunmaz ("abartma" kuralı). Sayaçlı olanlar ayrıca `_timed_ok`'a uyar.
static func extras_for(number: int) -> Array[String]:
	var chosen: Array[String] = []
	if number < WASHER_FROM_LEVEL:
		return chosen
	# Mevsim olayı da "yeni mekanik" sayılır (abartma kuralının genişletilmesi): varsa bir yer ayrılır.
	var limit: int = MAX_NEW_MECHANICS - (1 if season_count(number, season_mechanic(number)) > 0 else 0)
	# Tanıtımdan hemen sonraki "pekiştirme" seviyesindeki mekanik önce gelir; kalanlar seviyeye
	# bağlı tohumla karışır (hep en yenisi seçilse eski makineler geç seviyelerde hiç görünmezdi).
	var fresh: Array[String] = []
	var others: Array[String] = []
	for name: String in NEW_PRIORITY:
		if mechanic_count(number, name) <= 0:
			continue
		if TIMED_PRIORITY.has(name) and not _timed_ok(number, name):
			continue
		if number - _mechanic_from(name) <= MIX_SURE_LEVELS:
			fresh.append(name)
		else:
			others.append(name)
	var roll: RandomNumberGenerator = RandomNumberGenerator.new()
	roll.seed = number * FEATURE_SALT + EXTRA_SALT * 2
	for index: int in range(others.size() - 1, 0, -1):
		var other: int = roll.randi_range(0, index)
		var held: String = others[index]
		others[index] = others[other]
		others[other] = held
	for name: String in fresh + others:
		if chosen.size() < limit:
			chosen.append(name)
	return chosen


static func _add_extras(level: Dictionary, number: int) -> void:
	var allowed: Array[String] = extras_for(number)
	if allowed.is_empty():
		return
	var extra: RandomNumberGenerator = RandomNumberGenerator.new()
	extra.seed = number * FEATURE_SALT + EXTRA_SALT
	var rain: int = mechanic_count(number, "rain") if allowed.has("rain") else 0
	var birds: int = mechanic_count(number, "birds") if allowed.has("birds") else 0
	var cats: int = mechanic_count(number, "cat") if allowed.has("cat") else 0
	if allowed.has("dryer"):
		_add_dryer(level, number == DRYER_FROM_LEVEL, rain > 0, extra)
	var dirty: int = mechanic_count(number, "washer") if allowed.has("washer") else 0
	if dirty > 0 or birds > 0:
		_add_washer(level, dirty, number == WASHER_FROM_LEVEL, birds > 0, extra)
	var typed: int = mechanic_count(number, "typed") if allowed.has("typed") else 0
	if typed > 0:
		_add_typed(level, typed, extra)
	if rain > 0:
		_add_rain(level, rain, extra)
	if birds > 0:
		_add_birds(level, birds, number, extra)
	if cats > 0:
		_add_cats(level, cats, extra)


## Engelsiz parçalar; tanıtımda (`open_first`) önce başta açık olanlar: oyuncu yeni şeyi hemen görür.
static func _extra_pool(items: Array[Dictionary], rng: RandomNumberGenerator, open_first: bool) -> Array[int]:
	var pool: Array[int] = _plain_pool(items, rng)
	if not open_first:
		return pool
	var ordered: Array[int] = []
	for strict: bool in [true, false]:
		for index: int in pool:
			if (items[index]["blockers"] as Array).is_empty() == strict:
				ordered.append(index)
	return ordered


## Kurutucu: ıslak parçalar sıkılmaz, kurutucuya girer. Islak parça (ya da yağmur) yoksa anlamsızdır.
## Tanıtımda eski engeller olmadığından iki ıslak parça yerleştirilir.
static func _add_dryer(level: Dictionary, intro: bool, rainy: bool, rng: RandomNumberGenerator) -> void:
	var items: Array[Dictionary] = level["items"] as Array[Dictionary]
	level["dryer"] = {"capacity": LaundryBoard.DRYER_CAPACITY, "moves": LaundryBoard.DRYER_MOVES}
	if intro:
		_mark_some(level, "wet", DRYER_INTRO_WET, true, rng)
	var wet: int = 0
	for entry: Dictionary in items:
		if bool(entry.get("wet", false)):
			wet += 1
	if (wet == 0 and not rainy) or not _verify(level, PLACE_NODE_LIMIT):
		level.erase("dryer")


## Çamaşır makinesi + `count` çamurlu parça. Kuşlu seviyede (`keep`) çamurlu parça olmasa da makine kalır.
static func _add_washer(level: Dictionary, count: int, intro: bool, keep: bool, rng: RandomNumberGenerator) -> void:
	level["washer"] = {"capacity": LaundryBoard.WASHER_CAPACITY, "moves": LaundryBoard.WASHER_MOVES}
	var wanted: int = WASHER_INTRO_DIRTY if intro else count
	var placed: int = _mark_some(level, "dirty", wanted, intro, rng) if wanted > 0 else 0
	if placed == 0 and not keep:
		level.erase("washer")


## `count` engelsiz parçaya `key` işaretini koyar; her biri doğrulanır. Konan sayıyı döndürür.
static func _mark_some(level: Dictionary, key: String, count: int, open_first: bool, rng: RandomNumberGenerator) -> int:
	var items: Array[Dictionary] = level["items"] as Array[Dictionary]
	var placed: int = 0
	var tries: int = 0
	for index: int in _extra_pool(items, rng, open_first):
		if placed >= count or tries >= count + EXTRA_TRIES:
			break
		tries += 1
		items[index][key] = true
		if _verify(level, PLACE_NODE_LIMIT):
			placed += 1
		else:
			items[index].erase(key)
	return placed


## Türlü sepet: başta aktif olmayan normal bir sepet (joker/büyük değil) tek türü ister. O renkten
## üç parça bu türe çevrilir (görünüm türü kuralın parçası olur); aynı renkte bu türde başka parça
## bırakılmaz ki rozet "tam bu üçü" desin. Renk sayıları değişmez -> kuyruk tutarlı kalır.
static func _add_typed(level: Dictionary, count: int, rng: RandomNumberGenerator) -> void:
	var items: Array[Dictionary] = level["items"] as Array[Dictionary]
	var queue: Array = level["queue"] as Array
	var big: Array = level.get("big", []) as Array
	var jokers: Array = level.get("jokers", []) as Array
	var candidates: Array[int] = []
	for index: int in range(int(level["active_baskets"]), queue.size()):
		if not big.has(index) and not jokers.has(index):
			candidates.append(index)
	_shuffle(candidates, rng)
	# Boya akarsa renk takası ayrılmış üçlüyü bozar: boyaya karışan renkler türlü sepet olmaz.
	var dyed: Dictionary = {}
	for entry: Dictionary in items:
		# Çift renkli parçanın iki rengi de türlü sepet olmaz (ev takası ayrılmış üçlüyü bozabilir).
		if entry.has("twin"):
			dyed[int(entry["color"])] = true
			for other: Dictionary in items:
				if int(other["id"]) == int(entry["twin"]):
					dyed[int(other["color"])] = true
		if entry.has("dye"):
			dyed[int(entry["color"])] = true
			for other: Dictionary in items:
				if int(other["id"]) == int(entry["dye_target"]):
					dyed[int(other["color"])] = true
	var typed: Array = []
	var tries: int = 0
	for index: int in candidates:
		if typed.size() >= count or tries >= EXTRA_TRIES:
			break
		var color: int = int(queue[index])
		if dyed.has(color):
			continue
		var members: Array[int] = []
		for at: int in range(items.size()):
			var entry: Dictionary = items[at]
			if int(entry["color"]) == color and not entry.has("sheet") and not entry.has("sock"):
				members.append(at)
		if members.size() < BASKET_CAPACITY:
			continue
		tries += 1
		_shuffle(members, rng)
		var kind: int = TYPED_KINDS[rng.randi_range(0, TYPED_KINDS.size() - 1)]
		var saved: Dictionary = {}
		for k: int in range(members.size()):
			var entry: Dictionary = items[members[k]]
			saved[members[k]] = int(entry["kind"])
			if k < BASKET_CAPACITY:
				entry["kind"] = kind
			elif int(entry["kind"]) == kind:
				entry["kind"] = TYPED_KINDS[(TYPED_KINDS.find(kind) + 1) % TYPED_KINDS.size()]
		typed.append([index, kind])
		level["typed"] = typed
		if _verify(level, PLACE_NODE_LIMIT):
			continue
		typed.pop_back()
		for at: Variant in saved.keys():
			items[int(at)]["kind"] = int(saved[at])
	if typed.is_empty():
		level.erase("typed")


## Çözüm yolu oynanır: verilen hamle sayılarında açık parçalar ve dolu sepet yuvaları, ayrıca her
## parçanın ipten ayrıldığı hamle kaydedilir (misafirin anlamlı bir hedef seçmesi için).
static func _simulate(level: Dictionary, path: Array[int], marks: Array[int]) -> Dictionary:
	var board: LaundryBoard = LaundryBoard.new(level)
	var open: Dictionary = {}
	var slots: Dictionary = {}
	var left_at: Dictionary = {}
	var remaining: Array[int] = board.item_ids()
	for id: int in path:
		board.tap(id)
		var moves: int = board.moves()
		for at: int in range(remaining.size() - 1, -1, -1):
			if not board.is_on_line(remaining[at]):
				left_at[remaining[at]] = moves
				remaining.remove_at(at)
		if marks.has(moves) and not open.has(moves):
			open[moves] = board.open_ids()
			var filled: Array[int] = []
			var states: Array[Dictionary] = board.baskets()
			for index: int in range(states.size()):
				if not states[index].is_empty():
					filled.append(index)
			slots[moves] = filled
	return {"open": open, "slots": slots, "left_at": left_at}


static func _by_id(items: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = {}
	for entry: Dictionary in items:
		result[int(entry["id"])] = entry
	return result


## Hedef olabilir mi: ıslak/çamurlu/zincirli/çarşaf değil (kuş ve yağmur yalnız sıradan parçayı etkiler).
static func _guest_target(entry: Dictionary) -> bool:
	return not bool(entry.get("wet", false)) and not bool(entry.get("dirty", false)) \
		and not entry.has("chain") and not entry.has("sheet")


## Yağmur: her adım, o anda (çözüm yolunda) en çok açık parçanın beklediği ipe yağar. Adım o ipin
## TÜM parçalarını listeler; tahta yağış anında yalnız açık olanları ıslatır.
static func _add_rain(level: Dictionary, steps: int, rng: RandomNumberGenerator) -> void:
	var path: Array[int] = _path(level, LATE_NODE_LIMIT)
	if path.is_empty():
		return
	var marks: Array[int] = []
	for step: int in range(steps):
		marks.append((step + 1) * RAIN_EVERY_MOVES)
	var sim: Dictionary = _simulate(level, path, marks)
	var items: Array[Dictionary] = level["items"] as Array[Dictionary]
	var by_id: Dictionary = _by_id(items)
	var left_at: Dictionary = sim["left_at"] as Dictionary
	var chosen: Array = []
	level["rain"] = {"every": RAIN_EVERY_MOVES, "steps": chosen}
	for fire: int in marks:
		if not (sim["open"] as Dictionary).has(fire):
			break
		var score: Dictionary = {}
		for id: int in (sim["open"] as Dictionary)[fire] as Array[int]:
			var entry: Dictionary = by_id[id] as Dictionary
			if _guest_target(entry) and int(left_at.get(id, 0)) > fire:
				score[int(entry["line"])] = int(score.get(int(entry["line"]), 0)) + 1
		var lines: Array[int] = []
		for line: Variant in score.keys():
			if int(score[line]) >= RAIN_MIN_SOAK:
				lines.append(int(line))
		_shuffle(lines, rng)
		lines.sort_custom(func(a: int, b: int) -> bool: return int(score[a]) > int(score[b]))
		# Aynı ipe iki kez yağmasın (varsa başka ip): bulut tahtada gezinsin.
		var used: Array[int] = []
		for step: Variant in chosen:
			used.append(int(by_id[int((step as Array)[0])]["line"]))
		lines.sort_custom(func(a: int, b: int) -> bool: return not used.has(a) and used.has(b))
		var placed: bool = false
		for line: int in lines.slice(0, EXTRA_TRIES):
			var ids: Array[int] = []
			for entry: Dictionary in items:
				if int(entry["line"]) == line:
					ids.append(int(entry["id"]))
			chosen.append(ids)
			if _verify(level, PLACE_NODE_LIMIT):
				placed = true
				break
			chosen.pop_back()
		if not placed:
			break
	if chosen.is_empty():
		level.erase("rain")


## Kuş: her konuşta, o an açık ve en az BIRD_STAIN_MOVES hamle daha ipte kalacak sıradan bir parça.
## Yardımsız (hiç kovalanmayan) varyant doğrulanır; yardımlı oyun kuşsuz tahtayla aynıdır.
static func _add_birds(level: Dictionary, count: int, number: int, rng: RandomNumberGenerator) -> void:
	var path: Array[int] = _path(level, LATE_NODE_LIMIT)
	if path.is_empty():
		return
	var every: int = BIRD_EVERY_MOVES_LATE if number >= BIRD_FAST_FROM_LEVEL else BIRD_EVERY_MOVES
	var marks: Array[int] = []
	for step: int in range(count):
		marks.append((step + 1) * every)
	var sim: Dictionary = _simulate(level, path, marks)
	var by_id: Dictionary = _by_id(level["items"] as Array[Dictionary])
	var left_at: Dictionary = sim["left_at"] as Dictionary
	var targets: Array[int] = []
	level["birds"] = {"every": every, "targets": targets}
	for fire: int in marks:
		if not (sim["open"] as Dictionary).has(fire):
			break
		var candidates: Array[int] = []
		for id: int in (sim["open"] as Dictionary)[fire] as Array[int]:
			# Kuş rozetli (kilit, boya...) parçaya konmaz: aynı parçada iki işaret üst üste binmesin.
			if _guest_target(by_id[id] as Dictionary) and _plain(by_id[id] as Dictionary) and not targets.has(id) \
					and int(left_at.get(id, 0)) > fire + LaundryBoard.BIRD_STAIN_MOVES:
				candidates.append(id)
		_shuffle(candidates, rng)
		var placed: bool = false
		for id: int in candidates.slice(0, EXTRA_TRIES):
			targets.append(id)
			if _verify(level, PLACE_NODE_LIMIT, false):
				placed = true
				break
			targets.pop_back()
		if not placed:
			break
	if targets.is_empty():
		level.erase("birds")


## Kedi: her uykuda o an dolu bir sepet yuvası. Yardımsız (hiç sevilmeyen) varyant doğrulanır.
static func _add_cats(level: Dictionary, count: int, rng: RandomNumberGenerator) -> void:
	var path: Array[int] = _path(level, LATE_NODE_LIMIT)
	if path.is_empty():
		return
	var marks: Array[int] = []
	for step: int in range(count):
		marks.append((step + 1) * CAT_EVERY_MOVES)
	var sim: Dictionary = _simulate(level, path, marks)
	var slots: Array[int] = []
	level["cat"] = {"every": CAT_EVERY_MOVES, "baskets": slots}
	for fire: int in marks:
		if not (sim["slots"] as Dictionary).has(fire):
			break
		var candidates: Array[int] = ((sim["slots"] as Dictionary)[fire] as Array[int]).duplicate()
		_shuffle(candidates, rng)
		var placed: bool = false
		for slot: int in candidates.slice(0, EXTRA_TRIES):
			slots.append(slot)
			if _verify(level, PLACE_NODE_LIMIT, false):
				placed = true
				break
			slots.pop_back()
		if not placed:
			break
	if slots.is_empty():
		level.erase("cat")


## Çözüm yolundaki gerçek hamle sayısı (ücretsiz eylemler negatif kimliklidir, sayılmaz).
static func _real_moves(path: Array[int]) -> int:
	var total: int = 0
	for id: int in path:
		if id >= 0:
			total += 1
	return total


# --- Derinleşme 4: çift renk, mevsim olayları, doğrulama yardımcıları ------------------------------
# Kurallar `LaundryBoard` son bölümündedir. Çift renk 18'den, tamamlayıcı ÇİFTLER hâlinde (A|B evi A,
# B|A evi B) gelir; iki yön de doğrulanır (ilk parça ev rengine / diğer renge gitmiş gibi). Mevsim
# olayı en son, ayrı RNG ile eklenir: o mevsimin bandında (SeasonCycle) yalnız o mevsimin imzası.

const MAX_DUAL_PAIRS: int = 2
## Çift sayısı yumuşak artar: bu kadar seviyede bir +1 çift (ilk 15 seviye tek çift).
const DUAL_RAMP_LEVELS: int = 15
## Çift aday denemesi (her deneme iki doğrulama).
const DUAL_TRIES: int = 4
const DUAL_SALT: int = 7951
## Engelsiz sayılmayan parça anahtarları (yeni engeller birbirine ve eskilere binmesin; rozet yığılmasın).
const PLAIN_BLOCKING_KEYS: Array[String] = ["wet", "mystery", "lock", "sheet", "sock", "dye", "stain", "chain",
	"dirty", "twin", "sun", "frost"]
## Üretim içi tanık yolu (son bulunan çözüm): 64+ doğrulamalarında önce bu yol oynanır. Sonuçtan silinir.
const WITNESS_KEY: String = "_witness"
## Mevsim -> imza mekaniği.
const SEASON_MECHANICS: Dictionary = {
	SeasonCycle.SUMMER: "sun", SeasonCycle.AUTUMN: "leaves", SeasonCycle.WINTER: "frost", SeasonCycle.SPRING: "pollen",
}
## Tanıtımda adet (güneş/don: parça; yaprak/polen: olay sayısı), en çok adet, rampa adımı (seviye).
const SEASON_INTRO_COUNT: Dictionary = {"sun": 1, "leaves": 2, "frost": 1, "pollen": 2}
const SEASON_MAX: Dictionary = {"sun": 3, "leaves": 4, "frost": 3, "pollen": 3}
const SEASON_RAMP_LEVELS: int = 8
## Tanıtım sonrası pekiştirmeden sonra mevsim olayının seviyede bulunma olasılığı (deterministik zar).
const SEASON_MIX_CHANCE: float = 0.6
const SEASON_SALTS: Dictionary = {"sun": 107, "leaves": 109, "frost": 113, "pollen": 127}
const SEASON_SALT: int = 7963
## İlk mevsim döngüsü (4 bant x 30): sonrasında tanıtım gerekmez, bant başından itibaren karışır.
const FIRST_CYCLE_LAST_LEVEL: int = SeasonCycle.LEVELS_PER_SEASON * 4
const SUN_MOVES: int = 4
const SUN_MOVES_LATE: int = 3
const LEAF_EVERY_MOVES: int = 4
const LEAF_EVERY_INTRO: int = 3
const POLLEN_EVERY_MOVES: int = 5
const POLLEN_HIDE_MOVES: int = 3
## Sayaçlı (sağ sütunda hap gösteren) mekanikler: bir seviyede en fazla MAX_TIMED_MECHANICS.
const TIMED_LEVEL_KEYS: Array[String] = ["wind", "slide", "birds", "rain", "cat", "leaves", "pollen"]


## Doğrulama: 64 öncesi `LevelSolver.is_solvable` ile BİREBİR aynı (seviyeler değişmesin). 64+:
## önce üretim içi tanık yolu oynanır (geçerliyse kanıttır, arama gerekmez); geçmezse arama, bulunan
## yol yeni tanık olur. Sağlam: kabul edilen her yerleşim için kazandıran bir yol vardır.
static func _verify(level: Dictionary, node_limit: int = LevelSolver.DEFAULT_NODE_LIMIT,
		help_critters: bool = true) -> bool:
	if int(level.get("level", 1)) < LEAN_FROM_LEVEL:
		return LevelSolver.is_solvable(level, node_limit, help_critters)
	var witness: Variant = level.get(WITNESS_KEY)
	if witness is Array and LevelSolver.replays(level, witness as Array[int], help_critters):
		return true
	# Yerleşim doğrulaması (karıştırma değil) daha düşük bütçeyle: üretim süresi sınırı.
	var budget: int = mini(node_limit, LEAN_PLACE_LIMIT) if node_limit <= PLACE_NODE_LIMIT else node_limit
	var path: Array[int] = LevelSolver.solve(level, budget, help_critters)
	if path.is_empty():
		return (level.get("items", []) as Array).is_empty()
	level[WITNESS_KEY] = path
	return true


## Çözüm yolu: 64 öncesi eskisi gibi arama; 64+ geçerli tanık yolu varsa o.
static func _path(level: Dictionary, node_limit: int) -> Array[int]:
	if int(level.get("level", 1)) >= LEAN_FROM_LEVEL:
		var witness: Variant = level.get(WITNESS_KEY)
		if witness is Array and LevelSolver.replays(level, witness as Array[int]):
			return (witness as Array[int]).duplicate()
	var path: Array[int] = LevelSolver.solve(level, node_limit)
	if not path.is_empty() and int(level.get("level", 1)) >= LEAN_FROM_LEVEL:
		level[WITNESS_KEY] = path
	return path


## Mekanik ya da mevsim olayı adedi (sayaç sınırı her ikisini de aynı sırayla sayar).
static func _any_count(number: int, name: String) -> int:
	if SEASON_SALTS.has(name):
		return season_count(number, name)
	return mechanic_count(number, name)


static func season_mechanic(level: int) -> String:
	return String(SEASON_MECHANICS[SeasonCycle.season_for(level)])


static func _season_from(name: String) -> int:
	match name:
		"sun":
			return SUN_FROM_LEVEL
		"leaves":
			return LEAVES_FROM_LEVEL
		"frost":
			return FROST_FROM_LEVEL
		"pollen":
			return POLLEN_FROM_LEVEL
	return 1 << 30


## Mevsim olayının bu seviyedeki adedi. Yalnız seviyenin kendi mevsiminde. İlk döngüde: tanıtım
## seviyesinde tanıtım adedi (tek başına), başka tanıtım/kip tanıtımında 0, sonraki iki seviyede kesin,
## sonra deterministik zar. 121+: tanıtım gerekmez, bant başından zarla karışır. Adet yumuşak rampayla artar.
static func season_count(level: int, name: String) -> int:
	if not SEASON_SALTS.has(name) or season_mechanic(level) != name:
		return 0
	var base: int = 0
	var sure: bool = false
	if level <= FIRST_CYCLE_LAST_LEVEL:
		base = _season_from(name)
		if level < base:
			return 0
		if level == base:
			return int(SEASON_INTRO_COUNT[name])
		if level in INTRO_LEVELS or level in MODE_INTRO_LEVELS:
			return 0
		sure = level - base <= MIX_SURE_LEVELS
	else:
		base = level - SeasonCycle.step_in_season(level)
	if not sure:
		var roll: RandomNumberGenerator = RandomNumberGenerator.new()
		roll.seed = level * FEATURE_SALT + int(SEASON_SALTS[name])
		if roll.randf() >= SEASON_MIX_CHANCE:
			return 0
	return clampi(int(SEASON_INTRO_COUNT[name]) + (level - base) / SEASON_RAMP_LEVELS, 1, int(SEASON_MAX[name]))


# --- Çift renkli çamaşır --------------------------------------------------------------------------

## Tamamlayıcı çift: farklı renkte iki engelsiz parça (boya hedefi değil), karşılıklı `twin`. İkinci
## renk tahtada eşin renginden türetilir (veride renk yok: günlük bulmacanın renk eşlemesi bozamaz).
## İki doğrulama: (1) seviye çift renk kurallarıyla çözülür; (2) ilk
## parça diğer renge gitmiş (evler takas edilmiş) sıradan seviye de çözülür -> oyuncu hangi yönü
## seçerse seçsin renk sayıları tutar ve makul bir çözüm yolu kalır.
static func _add_duals(level: Dictionary, pairs: int, number: int) -> void:
	var items: Array[Dictionary] = level["items"] as Array[Dictionary]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = number * FEATURE_SALT + DUAL_SALT
	var dye_targets: Dictionary = {}
	for entry: Dictionary in items:
		if entry.has("dye_target"):
			dye_targets[int(entry["dye_target"])] = true
	var pool: Array[int] = []
	for index: int in _extra_pool(items, rng, number == DUAL_FROM_LEVEL):
		if not dye_targets.has(int(items[index]["id"])) and int(items[index].get("screen", 0)) == 0:
			pool.append(index)
	var placed: int = 0
	var tries: int = 0
	for first_at: int in range(pool.size()):
		if placed >= pairs or tries >= DUAL_TRIES:
			break
		var first: Dictionary = items[pool[first_at]]
		if not _plain(first):
			continue
		for second_at: int in range(first_at + 1, pool.size()):
			var second: Dictionary = items[pool[second_at]]
			if not _plain(second) or int(second["color"]) == int(first["color"]):
				continue
			tries += 1
			_mark_dual(first, second)
			if _verify(level, PLACE_NODE_LIMIT) and _verify(_dual_swapped(level, first, second), PLACE_NODE_LIMIT):
				placed += 1
			else:
				_unmark_dual(first)
				_unmark_dual(second)
			break


static func _mark_dual(first: Dictionary, second: Dictionary) -> void:
	first["twin"] = int(second["id"])
	second["twin"] = int(first["id"])


static func _unmark_dual(entry: Dictionary) -> void:
	entry.erase("twin")


## İlk parça diğer renge gitmiş hâl: evler takas edilmiş, artık çift renk olmayan sıradan seviye.
static func _dual_swapped(level: Dictionary, first: Dictionary, second: Dictionary) -> Dictionary:
	var copy: Dictionary = level.duplicate(true)
	for entry: Variant in copy["items"] as Array:
		var item: Dictionary = entry as Dictionary
		if int(item["id"]) == int(first["id"]):
			item["color"] = int(second["color"])
			_unmark_dual(item)
		elif int(item["id"]) == int(second["id"]):
			item["color"] = int(first["color"])
			_unmark_dual(item)
	return copy


# --- Mevsim olayları ------------------------------------------------------------------------------

static func _add_season(level: Dictionary, number: int) -> void:
	var name: String = season_mechanic(number)
	var count: int = season_count(number, name)
	if count <= 0:
		return
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = number * FEATURE_SALT + SEASON_SALT + int(SEASON_SALTS[name])
	match name:
		"sun":
			_add_sun(level, count, number, rng)
		"frost":
			_add_frost(level, count, number, rng)
		"leaves":
			if _timed_room(level):
				_add_leaves(level, count, number, rng)
		"pollen":
			if _timed_room(level):
				_add_pollen(level, count, rng)


## Sağ sütunda yer var mı (en fazla MAX_TIMED_MECHANICS sayaç hapı).
static func _timed_room(level: Dictionary) -> bool:
	var used: int = 0
	for key: String in TIMED_LEVEL_KEYS:
		if level.has(key):
			used += 1
	return used < MAX_TIMED_MECHANICS


## Rozet/misafir taşıyan parçalar (rüzgâr, sürgü, kuş hedefi): mevsim işareti bunlara konmaz ki aynı
## parçada iki rozet üst üste binmesin.
static func _badged_ids(level: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for step: Variant in (level.get("wind", {}) as Dictionary).get("steps", []) as Array:
		for id: Variant in step as Array:
			result[int(id)] = true
	for id: Variant in (level.get("slide", {}) as Dictionary).get("sliders", []) as Array:
		result[int(id)] = true
	for id: Variant in (level.get("birds", {}) as Dictionary).get("targets", []) as Array:
		result[int(id)] = true
	return result


## Güneşte solma: başta açık, engelsiz parçalar (tanıtımda kesin açık). Her biri doğrulanır (hamle
## sınırlı seviyede ceza hamlesi sınırı aşmamalı).
static func _add_sun(level: Dictionary, count: int, number: int, rng: RandomNumberGenerator) -> void:
	var items: Array[Dictionary] = level["items"] as Array[Dictionary]
	var badged: Dictionary = _badged_ids(level)
	var moves: int = SUN_MOVES if number <= FIRST_CYCLE_LAST_LEVEL else SUN_MOVES_LATE
	var placed: int = 0
	var tries: int = 0
	var extra: int = EXTRA_TRIES if number < LEAN_FROM_LEVEL else LEAN_EXTRA_TRIES
	for index: int in _extra_pool(items, rng, true):
		if placed >= count or tries >= count + extra:
			break
		var entry: Dictionary = items[index]
		if badged.has(int(entry["id"])) or int(entry.get("screen", 0)) != 0:
			continue
		tries += 1
		entry["sun"] = moves
		if _verify(level, PLACE_NODE_LIMIT):
			placed += 1
		else:
			entry.erase("sun")


## Don: engelsiz parçalar (tanıtımda önce açık olanlar). Her biri doğrulanır.
static func _add_frost(level: Dictionary, count: int, number: int, rng: RandomNumberGenerator) -> void:
	var items: Array[Dictionary] = level["items"] as Array[Dictionary]
	var badged: Dictionary = _badged_ids(level)
	var placed: int = 0
	var tries: int = 0
	var extra: int = EXTRA_TRIES if number < LEAN_FROM_LEVEL else LEAN_EXTRA_TRIES
	for index: int in _extra_pool(items, rng, number == FROST_FROM_LEVEL):
		if placed >= count or tries >= count + extra:
			break
		var entry: Dictionary = items[index]
		if badged.has(int(entry["id"])):
			continue
		tries += 1
		entry["frost"] = true
		if _verify(level, PLACE_NODE_LIMIT):
			placed += 1
		else:
			entry.erase("frost")


## Yaprak: her düşüşte (çözüm yolunda) o an açık, engelsiz ve en az bir hamle daha ipte kalacak parça.
## Doğrulama gerekmez: yaprağı süpürmek ücretsizdir ve yalnız alınabilir (açık) parçada olur, yani
## yapraksız tahtanın her çözümü süpürmeler eklenerek aynen geçerlidir (çözülebilirlik değişmez).
static func _add_leaves(level: Dictionary, count: int, number: int, rng: RandomNumberGenerator) -> void:
	var path: Array[int] = _path(level, LATE_NODE_LIMIT)
	if path.is_empty():
		return
	var every: int = LEAF_EVERY_INTRO if number == LEAVES_FROM_LEVEL else LEAF_EVERY_MOVES
	var marks: Array[int] = []
	for step: int in range(count):
		marks.append((step + 1) * every)
	var sim: Dictionary = _simulate(level, path, marks)
	var by_id: Dictionary = _by_id(level["items"] as Array[Dictionary])
	var left_at: Dictionary = sim["left_at"] as Dictionary
	var badged: Dictionary = _badged_ids(level)
	var targets: Array[int] = []
	for fire: int in marks:
		if not (sim["open"] as Dictionary).has(fire):
			break
		var candidates: Array[int] = []
		for id: int in (sim["open"] as Dictionary)[fire] as Array[int]:
			if _plain(by_id[id] as Dictionary) and not badged.has(id) and not targets.has(id) \
					and int(left_at.get(id, 0)) > fire + 1:
				candidates.append(id)
		if candidates.is_empty():
			break
		_shuffle(candidates, rng)
		targets.append(candidates[0])
	if not targets.is_empty():
		level["leaves"] = {"every": every, "targets": targets}


## Polen: her bulut (çözüm yolunda) o an en çok açık parçanın beklediği ipe; aynı ipe üst üste gelmez.
## Doğrulama gerekmez: yalnız bilgiyi gizler, kuralı değiştirmez.
static func _add_pollen(level: Dictionary, count: int, rng: RandomNumberGenerator) -> void:
	var path: Array[int] = _path(level, LATE_NODE_LIMIT)
	if path.is_empty():
		return
	var marks: Array[int] = []
	for step: int in range(count):
		marks.append((step + 1) * POLLEN_EVERY_MOVES)
	var sim: Dictionary = _simulate(level, path, marks)
	var by_id: Dictionary = _by_id(level["items"] as Array[Dictionary])
	var lines: Array[int] = []
	for fire: int in marks:
		if not (sim["open"] as Dictionary).has(fire):
			break
		var score: Dictionary = {}
		for id: int in (sim["open"] as Dictionary)[fire] as Array[int]:
			var line: int = int((by_id[id] as Dictionary)["line"])
			score[line] = int(score.get(line, 0)) + 1
		var options: Array[int] = []
		for line: Variant in score.keys():
			if lines.is_empty() or int(line) != lines[lines.size() - 1]:
				options.append(int(line))
		if options.is_empty():
			break
		_shuffle(options, rng)
		options.sort_custom(func(a: int, b: int) -> bool: return int(score[a]) > int(score[b]))
		lines.append(options[0])
	if not lines.is_empty():
		level["pollen"] = {"every": POLLEN_EVERY_MOVES, "lines": lines, "hide": POLLEN_HIDE_MOVES}
