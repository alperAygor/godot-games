extends Node

## `res://data/*.json` tablolarını yükler. Denge sayıları kodda değil burada durur
## (CLAUDE.md §4). Dosya adı tablo adıdır: `packages.json` -> "packages".

const DATA_DIR: String = "res://data"

var _tables: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_all()


func has_table(table_name: String) -> bool:
	return _tables.has(table_name)


func table(table_name: String) -> Dictionary:
	var found: Variant = _tables.get(table_name)
	if found is Dictionary:
		return found as Dictionary
	return {}


func value(table_name: String, key: String, fallback: Variant) -> Variant:
	var row: Dictionary = table(table_name)
	return row.get(key, fallback)


## Tabloyu yeniden okur (test ve editör araçları için).
func reload() -> void:
	_tables.clear()
	_load_all()


func _load_all() -> void:
	var dir: DirAccess = DirAccess.open(DATA_DIR)
	if dir == null:
		push_warning("GameData: %s açılamadı" % DATA_DIR)
		return
	for file: String in dir.get_files():
		if not file.ends_with(".json"):
			continue
		var path: String = DATA_DIR.path_join(file)
		var text: String = FileAccess.get_file_as_string(path)
		var parsed: Variant = JSON.parse_string(text)
		if parsed is Dictionary:
			_tables[file.get_basename()] = parsed
		else:
			push_warning("GameData: %s geçerli bir JSON nesnesi değil" % path)
