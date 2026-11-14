extends Node
## data/ altındaki JSON tablolarını yükler. Oyun dengesi (hız, hasar, maliyet) kodda değil burada okunur.
## Örnek: GameData.get_value("balance", "player.move_speed", 0.0)
## Not: Export'ta JSON dosyalarının pakete girmesi için export preset'inde include_filter="data/*.json" olmalı.

const DATA_DIR := "res://data"

var _tables: Dictionary = {}


func _ready() -> void:
	reload()


func reload() -> void:
	_tables.clear()
	for file_name in DirAccess.get_files_at(DATA_DIR):
		if file_name.get_extension() == "json":
			_tables[file_name.get_basename()] = JsonIO.read_dict(DATA_DIR.path_join(file_name))


func has_table(table_name: String) -> bool:
	return _tables.has(table_name)


func table(table_name: String) -> Dictionary:
	if not _tables.has(table_name):
		push_error("GameData: '%s' tablosu yok (data/%s.json)." % [table_name, table_name])
		return {}
	return _tables[table_name]


func get_value(table_name: String, dotted_path: String, fallback: Variant = null) -> Variant:
	return JsonIO.get_path_value(table(table_name), dotted_path, fallback)
