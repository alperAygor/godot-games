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
	if _search(level, path, seen, budget):
		return path
	return []


static func _search(level: Dictionary, path: Array[int], seen: Dictionary, budget: Array[int]) -> bool:
	var board: LaundryBoard = _replay(level, path)
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
		path.append(id)
		if _search(level, path, seen, budget):
			return true
		path.pop_back()
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
	return "%s|%s|%s|%d" % [str(line), str(rack_colors), str(board.baskets()), board.queue().size()]
