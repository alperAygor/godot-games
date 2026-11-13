class_name MetaCatalog
extends RefCounted

## Meta katmanının statik verisi: çamaşırhane mekânları/görevleri (`data/meta_laundromat.json`)
## ve kıyafet koleksiyonu setleri (`data/meta_collection.json`).
## NEDEN ayrı sınıf: JSON'dan gelen ham sözlükler gevşek tiplidir (sayılar float, alanlar
## eksik olabilir); tüm savunmacı okuma burada toplanır, MetaState ve sahneler yalnız tipli
## erişimcileri kullanır. Testler kendi küçük kataloglarını `from_dicts` ile kurar.

const LAUNDROMAT_PATH: String = "res://data/meta_laundromat.json"
const COLLECTION_PATH: String = "res://data/meta_collection.json"
const DEFAULT_VARIANTS: int = 3
const DEFAULT_LEVELS_PER_PIECE: int = 10
const MIN_COST: int = 1

var variants_per_task: int = DEFAULT_VARIANTS
var draw_order: Array[String] = []
var levels_per_piece: int = DEFAULT_LEVELS_PER_PIECE
var _locations: Array[Dictionary] = []
var _sets: Array[Dictionary] = []


static func load_default() -> MetaCatalog:
	return from_dicts(_read_json(LAUNDROMAT_PATH), _read_json(COLLECTION_PATH))


static func from_dicts(laundromat: Dictionary, collection: Dictionary) -> MetaCatalog:
	var catalog: MetaCatalog = MetaCatalog.new()
	catalog.variants_per_task = maxi(int(laundromat.get("variants_per_task", DEFAULT_VARIANTS)), 1)
	var order: Variant = laundromat.get("draw_order", [])
	if order is Array:
		for entry: Variant in order as Array:
			catalog.draw_order.append(str(entry))
	var locations: Variant = laundromat.get("locations", [])
	if locations is Array:
		for entry: Variant in locations as Array:
			if entry is Dictionary:
				catalog._locations.append(entry as Dictionary)
	catalog.levels_per_piece = maxi(int(collection.get("levels_per_piece", DEFAULT_LEVELS_PER_PIECE)), 1)
	var sets: Variant = collection.get("sets", [])
	if sets is Array:
		for entry: Variant in sets as Array:
			if entry is Dictionary:
				catalog._sets.append(entry as Dictionary)
	return catalog


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("MetaCatalog: %s yok" % path)
		return {}
	var parser: JSON = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not (parser.data is Dictionary):
		push_warning("MetaCatalog: %s okunamadı" % path)
		return {}
	return parser.data as Dictionary


# --- Çamaşırhane ---------------------------------------------------------------

func location_count() -> int:
	return _locations.size()


func location_id(index: int) -> String:
	if index < 0 or index >= _locations.size():
		return ""
	return str(_locations[index].get("id", "loc%d" % index))


func location_has_art(index: int) -> bool:
	if index < 0 or index >= _locations.size():
		return false
	return bool(_locations[index].get("art", false))


func completion_coins(index: int) -> int:
	if index < 0 or index >= _locations.size():
		return 0
	return maxi(int(_locations[index].get("completion_coins", 0)), 0)


func task_count(index: int) -> int:
	return _tasks(index).size()


func task_id(index: int, task: int) -> String:
	var tasks: Array[Dictionary] = _tasks(index)
	if task < 0 or task >= tasks.size():
		return ""
	return str(tasks[task].get("id", "task%d" % task))


## Görev bedeli (yıldız). Bozuk/eksik veride en az 1: bedava görev ekonomiyi delmesin.
func task_cost(index: int, task: int) -> int:
	var tasks: Array[Dictionary] = _tasks(index)
	if task < 0 or task >= tasks.size():
		return 0
	return maxi(int(tasks[task].get("cost", MIN_COST)), MIN_COST)


func task_swatches(index: int, task: int) -> Array[Color]:
	var result: Array[Color] = []
	var tasks: Array[Dictionary] = _tasks(index)
	if task < 0 or task >= tasks.size():
		return result
	var raw: Variant = tasks[task].get("swatches", [])
	if raw is Array:
		for entry: Variant in raw as Array:
			result.append(Color.from_string(str(entry), Color.WHITE))
	return result


func task_index(index: int, id: String) -> int:
	var tasks: Array[Dictionary] = _tasks(index)
	for task: int in range(tasks.size()):
		if str(tasks[task].get("id", "")) == id:
			return task
	return -1


func _tasks(index: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if index < 0 or index >= _locations.size():
		return result
	var raw: Variant = _locations[index].get("tasks", [])
	if raw is Array:
		for entry: Variant in raw as Array:
			if entry is Dictionary:
				result.append(entry as Dictionary)
	return result


# --- Koleksiyon -----------------------------------------------------------------

func set_count() -> int:
	return _sets.size()


func set_id(index: int) -> String:
	if index < 0 or index >= _sets.size():
		return ""
	return str(_sets[index].get("id", "set%d" % index))


func set_reward(index: int) -> String:
	if index < 0 or index >= _sets.size():
		return ""
	return str(_sets[index].get("reward", ""))


func set_pieces(index: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if index < 0 or index >= _sets.size():
		return result
	var raw: Variant = _sets[index].get("pieces", [])
	if raw is Array:
		for entry: Variant in raw as Array:
			if entry is Dictionary:
				result.append(entry as Dictionary)
	return result


func set_sizes() -> Array[int]:
	var result: Array[int] = []
	for index: int in range(_sets.size()):
		result.append(set_pieces(index).size())
	return result


func total_pieces() -> int:
	var total: int = 0
	for size: int in set_sizes():
		total += size
	return total
