class_name LevelCatalog
extends RefCounted
## SÖZLEŞME (yalnız lider değiştirir): oyundaki seviye sırası ve seviye dosyalarına erişim.
## Kabuk ve görünüm seviyeleri yalnız buradan okur; dosya düzeni (`data/levels/`) çekirdek işçisinindir.

const INDEX_PATH: String = "res://data/levels/index.json"
const LEVEL_DIR: String = "res://data/levels"

static var _entries: Array[Dictionary] = []
static var _loaded: bool = false

## Oyundaki sırayla seviye özetleri: { "id": String, "world": int, "par": int, "difficulty": int }.
static func entries() -> Array[Dictionary]:
	if not _loaded:
		_load_index()
	return _entries

static func count() -> int:
	return entries().size()

## Sıra numarası (0'dan); yoksa -1.
static func index_of(level_id: String) -> int:
	var list: Array[Dictionary] = entries()
	for i: int in list.size():
		if str(list[i].get("id", "")) == level_id:
			return i
	return -1

## Seviye sözlüğü (docs/CORE_API.md §1); okunamazsa boş sözlük.
static func load_level(level_id: String) -> Dictionary:
	var path: String = "%s/%s.json" % [LEVEL_DIR, level_id]
	if not FileAccess.file_exists(path):
		push_error("seviye dosyası yok: " + path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed as Dictionary
	push_error("seviye dosyası okunamadı: " + path)
	return {}

## Testler için: dizini yeniden okut.
static func reload() -> void:
	_loaded = false
	_entries = []

static func _load_index() -> void:
	_loaded = true
	_entries = []
	if not FileAccess.file_exists(INDEX_PATH):
		push_error("seviye dizini yok: " + INDEX_PATH)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(INDEX_PATH))
	if not (parsed is Dictionary):
		push_error("seviye dizini okunamadı: " + INDEX_PATH)
		return
	var raw: Variant = (parsed as Dictionary).get("levels", [])
	if not (raw is Array):
		return
	for item: Variant in raw as Array:
		if item is Dictionary:
			var d: Dictionary = item as Dictionary
			_entries.append({
				"id": str(d.get("id", "")),
				"world": int(d.get("world", 1)),
				"par": int(d.get("par", 0)),
				"difficulty": int(d.get("difficulty", 1)),
			})
