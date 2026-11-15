extends TestCase

## Veri dosyaları sağlığı: tabloların JSON'u geçerli, ses/ikon yolları gerçekten var, sahne kaydı tutarlı.

func _read(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_true(parsed is Dictionary, "%s geçerli JSON nesnesi olmalı" % path)
	return parsed as Dictionary if parsed is Dictionary else {}


func test_all_data_tables_are_valid_json_objects() -> void:
	var count: int = 0
	for file_name: String in DirAccess.get_files_at("res://data"):
		if file_name.ends_with(".json"):
			_read("res://data".path_join(file_name))
			count += 1
	assert_true(count >= 5, "data/ altında tablolar bulunmalı")


func test_sound_table_points_to_existing_files() -> void:
	for sound_name: String in _read("res://data/sounds.json").keys():
		var path: String = String(_read("res://data/sounds.json")[sound_name])
		assert_true(ResourceLoader.exists(path), "ses dosyası yok: %s -> %s" % [sound_name, path])


func test_icon_table_points_to_existing_files() -> void:
	for icon_name: String in _read("res://data/icons.json").keys():
		var path: String = String(_read("res://data/icons.json")[icon_name])
		assert_true(ResourceLoader.exists(path), "ikon dosyası yok: %s -> %s" % [icon_name, path])


func test_icons_used_in_code_exist() -> void:
	var regex: RegEx = RegEx.new()
	regex.compile("\"(lucide/[a-z0-9-]+)\"")
	var table: Dictionary = _read("res://data/icons.json")
	var checked: int = 0
	for dir_path: String in ["res://scripts/ui", "res://scripts/net", "res://scripts/core"]:
		for file_name: String in DirAccess.get_files_at(dir_path):
			if not file_name.ends_with(".gd"):
				continue
			for hit: RegExMatch in regex.search_all(FileAccess.get_file_as_string(dir_path.path_join(file_name))):
				checked += 1
				assert_true(table.has(hit.get_string(1)), "ikon tabloda yok: %s (%s)" % [hit.get_string(1), file_name])
	assert_true(checked > 5)


func test_game_data_autoload_reads_tables() -> void:
	var data: Node = autoload_node("GameData")
	assert_true(bool(data.call("has_table", "balance")))
	assert_eq(int(data.call("value", "balance", "win_coins", -1)), 20)
	assert_eq(data.call("value", "balance", "yok_boyle_anahtar", "yedek"), "yedek")
	assert_eq((data.call("table", "yok") as Dictionary).size(), 0)
