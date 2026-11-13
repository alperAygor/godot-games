class_name LevelSolver
extends RefCounted

## Saf mantık: bir seviyenin çözülebilir olup olmadığını arar (derinlik öncelikli,
## düğüm sınırlı). Üretici zorluk karıştırmasını bununla doğrular; testler de kullanır.

const DEFAULT_NODE_LIMIT: int = 20000


## `help_critters`: kuş konar konmaz kovalanır, kedi yatar yatmaz sevilir (ücretsiz eylemler yola
## TAP_BIRD/TAP_CAT olarak yazılır). false: oyuncu hiç kovalamaz/sevmez (üretici "yardımsız da
## kazanılır" güvencesini bununla sınar).
static func is_solvable(level: Dictionary, node_limit: int = DEFAULT_NODE_LIMIT, help_critters: bool = true) -> bool:
	return not solve(level, node_limit, help_critters).is_empty() or (level.get("items", []) as Array).is_empty()


## Kazandıran dokunuş sırası; bulunamazsa (ya da sınır aşılırsa) boş dizi.
static func solve(level: Dictionary, node_limit: int = DEFAULT_NODE_LIMIT, help_critters: bool = true) -> Array[int]:
	if not counts_fit(level):
		return []
	var budget: Array[int] = [node_limit]
	var path: Array[int] = []
	var seen: Dictionary = {}
	# Tek tahta + geri al: her düğümde yolu baştan oynatmak (O(derinlik)) yerine dokunup geri
	# alınır. Arama sırası ve bütçe sayımı eskisiyle birebir aynıdır -> aynı seviyeler üretilir.
	var board: LaundryBoard = LaundryBoard.new(level)
	board.enable_history()
	if _search(board, path, seen, budget, help_critters):
		return path
	return []


## Verilen dokunuşlar oynandıktan SONRAKİ durumdan kazandıran tam yol (baştaki dokunuşlar dahil);
## bulunamazsa boş dizi. Öğretici/ipucu, oyuncunun geldiği yerden devam yolunu bununla bulur.
static func solve_from(level: Dictionary, taps: Array[int], node_limit: int = DEFAULT_NODE_LIMIT) -> Array[int]:
	var board: LaundryBoard = LaundryBoard.new(level)
	for id: int in taps:
		board.tap(id)
	board.enable_history()
	var path: Array[int] = taps.duplicate()
	var budget: Array[int] = [node_limit]
	# Oyuncu kuşu henüz kovalamadıysa öneri yolu da oradan (kovalayarak) devam eder.
	_help_critters(board, path)
	if _search(board, path, {}, budget):
		return path
	return []


static func _search(board: LaundryBoard, path: Array[int], seen: Dictionary, budget: Array[int],
		help_critters: bool = true) -> bool:
	if board.is_won():
		return true
	if board.is_lost():
		return false
	budget[0] -= 1
	if budget[0] <= 0:
		return false
	var key: PackedInt32Array = board.state_key()
	if seen.has(key):
		return false
	seen[key] = true
	# Önce sepete giden hamleler denenir: çözüm çok daha hızlı bulunur.
	var direct: Array[int] = []
	var parked: Array[int] = []
	for id: int in board.open_ids():
		if board.accepts_item(id):
			direct.append(id)
		else:
			parked.append(id)
	for id: int in direct + parked:
		var before: int = board.history_size()
		board.tap(id)
		if board.history_size() == before:
			# Durum değişmedi (askı dolu reddi): eski sürüm bu çocuğu ziyaret edip bütçeden
			# bir düşerdi; aynı sayım korunur ki üretilen seviyeler değişmesin.
			budget[0] -= 1
			continue
		path.append(id)
		var helped: int = _help_critters(board, path) if help_critters else 0
		if _search(board, path, seen, budget, help_critters):
			return true
		path.resize(path.size() - 1 - helped)
		board.undo()
	return false


## Konan kuşu kovalar, yatan kediyi sever (ikisi de ücretsiz; hep yapmak en iyisidir: kuş yalnız
## zarar verir, kedi yalnız sepet kapatır). Yola eklenen ücretsiz eylem sayısını döndürür. Geri al
## son HAMLEYİ bunlarla birlikte geri sardığından ayrıca geri alınmaz.
static func _help_critters(board: LaundryBoard, path: Array[int]) -> int:
	var helped: int = 0
	if board.is_over():
		return helped
	if board.bird_on() != LaundryBoard.EMPTY:
		board.tap(LaundryBoard.TAP_BIRD)
		path.append(LaundryBoard.TAP_BIRD)
		helped += 1
	if board.cat_at() != LaundryBoard.EMPTY and not board.is_over():
		board.tap(LaundryBoard.TAP_CAT)
		path.append(LaundryBoard.TAP_CAT)
		helped += 1
	return helped


## Durum anahtarı tahtadadır (iç alanlara kopyasız erişir); burada geriye uyum için durur.
static func _state_key(board: LaundryBoard) -> PackedInt32Array:
	return board.state_key()


## Hızlı ön denetim: her rengin parça sayısı o rengin sepet kapasitesini (kuyruk; büyük sepet 5,
## joker asıl rengiyle sayılır) aşmamalı. Aşan renk hiçbir zaman askıdan boşalamaz -> kesin
## çözümsüz. Neden: renkleri sepet türünü gözetmeden takas eden çağıranlar (ör. günlük bulmacanın
## ek karıştırması) aksi hâlde her adayda bütün düğüm bütçesini boşa yakıyordu. Geçerli seviyede
## sonuç değişmez (yalnız kesin çözümsüzleri erken eler).
static func counts_fit(level: Dictionary) -> bool:
	var items: Dictionary = {}
	for entry: Variant in level.get("items", []) as Array:
		var color: int = int((entry as Dictionary).get("color", LaundryBoard.EMPTY))
		items[color] = int(items.get(color, 0)) + 1
	var big: Array = level.get("big", []) as Array
	var capacity: Dictionary = {}
	var queue: Array = level.get("queue", []) as Array
	for index: int in range(queue.size()):
		var size: int = LaundryBoard.BIG_BASKET_CAPACITY if big.has(index) else LaundryBoard.BASKET_CAPACITY
		capacity[int(queue[index])] = int(capacity.get(int(queue[index]), 0)) + size
	for color: Variant in items.keys():
		if int(items[color]) > int(capacity.get(color, 0)):
			return false
	return true
