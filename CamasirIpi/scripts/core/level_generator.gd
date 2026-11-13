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


## Zorluk parametreleri: {lines, columns, layers, colors, twist, active_baskets, hard}.
static func params_for(level: int) -> Dictionary:
	var n: int = maxi(level, 1)
	var hard: bool = n > HARD_EVERY and n % HARD_EVERY == 0
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


static func generate(level: int) -> Dictionary:
	var params: Dictionary = params_for(level)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = maxi(level, 1) * SEED_SALT
	var items: Array[Dictionary] = _layout(params, rng)
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
	_twist_queue(result, int(params["twist"]), rng)
	return result


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
static func _twist_queue(level: Dictionary, twist: int, rng: RandomNumberGenerator) -> void:
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
		if LevelSolver.is_solvable(candidate):
			queue = swapped
			level["queue"] = swapped
			applied += 1
