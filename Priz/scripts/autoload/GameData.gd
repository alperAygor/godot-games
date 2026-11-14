extends Node

## `res://data/*.json` tabloları. Denge sayıları kodda değil burada durur.
## Dosya adı tablo adıdır: `balance.json` -> "balance".

const DATA_DIR: String = "res://data"

var _tables: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	reload()


func reload() -> void:
	_tables.clear()
	var dir: DirAccess = DirAccess.open(DATA_DIR)
	if dir == null:
		push_warning("GameData: %s açılamadı" % DATA_DIR)
		return
	for file: String in dir.get_files():
		if not file.ends_with(".json"):
			continue
		var path: String = DATA_DIR.path_join(file)
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			_tables[file.get_basename()] = parsed
		else:
			push_warning("GameData: %s geçerli JSON nesnesi değil" % path)


func has_table(table_name: String) -> bool:
	return _tables.has(table_name)


func table(table_name: String) -> Dictionary:
	var found: Variant = _tables.get(table_name)
	if found is Dictionary:
		return found as Dictionary
	return {}


func value(table_name: String, key: String, fallback: Variant) -> Variant:
	return table(table_name).get(key, fallback)
