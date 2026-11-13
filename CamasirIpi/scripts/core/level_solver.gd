class_name LevelSolver
extends RefCounted

## Saf mantık: bir seviyenin çözülebilir olup olmadığını arar (derinlik öncelikli,
## düğüm sınırlı). Üretici zorluk karıştırmasını bununla doğrular; testler de kullanır.

const DEFAULT_NODE_LIMIT: int = 20000


static func is_solvable(level: Dictionary, node_limit: int = DEFAULT_NODE_LIMIT) -> bool:
	return not solve(level, node_limit).is_empty() or (level.get("items", []) as Array).is_empty()


## Kazandıran dokunuş sırası; bulunamazsa (ya da sınır aşılırsa) boş dizi.
static func solve(level: Dictionary, node_limit: int = DEFAULT_NODE_LIMIT) -> Array[int]:
	var budget: Array[int] = [node_limit]
	var path: Array[int] = []
	var seen: Dictionary = {}
	# Tek tahta + geri al: her düğümde yolu baştan oynatmak (O(derinlik)) yerine dokunup geri
	# alınır. Arama sırası ve bütçe sayımı eskisiyle birebir aynıdır -> aynı seviyeler üretilir.
	var board: LaundryBoard = LaundryBoard.new(level)
	board.enable_history()
	if _search(board, path, seen, budget):
		return path
	return []


static func _search(board: LaundryBoard, path: Array[int], seen: Dictionary, budget: Array[int]) -> bool:
	if board.is_won():
		return true
	if board.is_lost():
		return false
	budget[0] -= 1
	if budget[0] <= 0:
		return false
	var key: String = _state_key(board)
	if seen.has(key):
		return false
	seen[key] = true
	# Önce sepete giden hamleler denenir: çözüm çok daha hızlı bulunur.
	var direct: Array[int] = []
	var parked: Array[int] = []
	for id: int in board.open_ids():
		if _matches_basket(board, board.color_of(id)):
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
		if _search(board, path, seen, budget):
			return true
		path.pop_back()
		board.undo()
	return false


static func _replay(level: Dictionary, path: Array[int]) -> LaundryBoard:
	var board: LaundryBoard = LaundryBoard.new(level)
	for id: int in path:
		board.tap(id)
	return board


static func _matches_basket(board: LaundryBoard, color: int) -> bool:
	for basket: Dictionary in board.baskets():
		if basket.is_empty():
			continue
		if int(basket["color"]) == color and int(basket["count"]) < LaundryBoard.BASKET_CAPACITY:
			return true
	return false


static func _state_key(board: LaundryBoard) -> String:
	var line: Array[int] = []
	for id: int in board.item_ids():
		if board.is_on_line(id):
			line.append(id)
	var rack_colors: Array[int] = []
	for id: int in board.rack():
		if id != LaundryBoard.EMPTY:
			rack_colors.append(board.color_of(id))
	rack_colors.sort()
	# Çorap (bekleyen/takılı) ve boya (sayaç + takas sonrası renkler) durumu da anahtara girer:
	# aynı ip/askı görünümü bu kurallar yüzünden farklı gelecekler taşıyabilir.
	return "%s|%s|%s|%d|%s|%s|%d|%s|%s" % [str(line), str(rack_colors), str(board.baskets()),
		board.queue().size(), str(board.wet_ids()), str(board.completed_colors()),
		board.sock_waiting(), str(board.stuck_ids()), str(board.dye_state())]
