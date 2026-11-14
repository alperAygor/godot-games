class_name PrizElementRegistry
extends RefCounted
## İçerik öğesi kayıt defteri. Öğeler klasördeki JSON dosyalarından okunur; yeni öğe eklemek
## için dosya bırakmak yeter. Örnek ana iş parçacığında kurulur, sonra salt okunur olarak
## iş parçacıkları arasında paylaşılabilir (global durum yok).

const DEFAULT_DIR: String = "res://data/elements"

## Açılış seviyesi, sonra kimlik sırasıyla.
var elements: Array[PrizElement] = []
var errors: PackedStringArray = PackedStringArray()


static func create_default() -> PrizElementRegistry:
	var registry: PrizElementRegistry = PrizElementRegistry.new()
	registry.add_dir(DEFAULT_DIR)
	return registry


## Klasördeki tüm .json öğelerini ekler; eklenen sayıyı döner.
func add_dir(path: String) -> int:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		errors.append("öğe klasörü açılamadı: %s" % path)
		return 0
	var names: PackedStringArray = dir.get_files()
	names.sort()
	var added: int = 0
	for file_name: String in names:
		if file_name.ends_with(".json") and add_file(path.path_join(file_name)):
			added += 1
	return added


func add_file(path: String) -> bool:
	var data: Variant = PrizJson.read_file(path)
	if typeof(data) != TYPE_DICTIONARY:
		errors.append("öğe dosyası okunamadı: %s" % path)
		return false
	return add_dict(data, path)


func add_dict(d: Dictionary, source: String = "<sözlük>") -> bool:
	var element: PrizElement = PrizElement.from_dict(d, source, errors)
	if element == null:
		return false
	if get_element(element.id) != null:
		errors.append("yinelenen öğe: %s" % element.id)
		return false
	elements.append(element)
	elements.sort_custom(_element_less)
	return true


static func _element_less(a: PrizElement, b: PrizElement) -> bool:
	if a.unlock_level != b.unlock_level:
		return a.unlock_level < b.unlock_level
	return a.id < b.id


func get_element(element_id: String) -> PrizElement:
	for element: PrizElement in elements:
		if element.id == element_id:
			return element
	return null


## Bu seviyede (dahil) açılmış öğeler.
func unlocked_at(level_number: int) -> Array[PrizElement]:
	var result: Array[PrizElement] = []
	for element: PrizElement in elements:
		if element.unlock_level <= level_number:
			result.append(element)
	return result


## Tam bu seviyede ilk kez açılan öğeler (tanıtım kartı gösterilecek olanlar).
func introduced_at(level_number: int) -> Array[PrizElement]:
	var result: Array[PrizElement] = []
	for element: PrizElement in elements:
		if element.unlock_level == level_number:
			result.append(element)
	return result


## Verilen öğelerin kuralları, uygulama sırasına göre (order, sonra öğe sırası).
## Bilinmeyen kimlikler atlanır (seviye doğrulaması bunları ayrıca raporlar).
func rules_for(element_ids: Array[String]) -> Array[PrizRule]:
	var result: Array[PrizRule] = []
	for element: PrizElement in elements:
		if element_ids.has(element.id):
			for rule: PrizRule in element.rules:
				result.append(rule)
	# Kararlı sıralama: order eşitse kayıt sırası korunur.
	var indexed: Array = []
	for i: int in result.size():
		indexed.append([result[i].order, i])
	indexed.sort()
	var sorted: Array[PrizRule] = []
	for pair: Variant in indexed:
		var p: Array = pair
		sorted.append(result[int(p[1])])
	return sorted
