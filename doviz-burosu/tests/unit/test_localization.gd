extends "res://tests/test_case.gd"
## Çeviri tablosu tutarlılığı: eksik çeviri ve sahnelerde tanımsız anahtar yakalanır.

const CSV_PATH := "res://assets/translations/strings.csv"
const STORY_CSV_PATH := "res://assets/translations/story.csv"
const SCENES_DIR := "res://scenes"


func _read_csv(path := CSV_PATH) -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = []
	var file := FileAccess.open(path, FileAccess.READ)
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() > 1 or (row.size() == 1 and not row[0].is_empty()):
			rows.append(row)
	return rows


## strings.csv + story.csv anahtarları (ikisi de kodda tr() ile okunur).
func _keys() -> PackedStringArray:
	var keys := PackedStringArray()
	for path in [CSV_PATH, STORY_CSV_PATH]:
		for row in _read_csv(path).slice(1):
			keys.append(row[0])
	return keys


func test_csv_columns_match_supported_languages() -> void:
	var languages: Dictionary = tree.root.get_node("SettingsManager").available_languages()
	for path in [CSV_PATH, STORY_CSV_PATH]:
		var header := _read_csv(path)[0]
		for code: String in languages:
			assert_true(code in header, "%s içinde '%s' sütunu olmalı" % [path, code])


func test_every_key_translated_in_every_language() -> void:
	for path in [CSV_PATH, STORY_CSV_PATH]:
		var rows := _read_csv(path)
		var header := rows[0]
		for row in rows.slice(1):
			assert_eq(row.size(), header.size(), "'%s' satırının sütun sayısı" % row[0])
			for i in range(1, mini(row.size(), header.size())):
				assert_false(row[i].strip_edges().is_empty(), "'%s' anahtarının '%s' çevirisi boş" % [row[0], header[i]])


func test_no_key_is_defined_in_both_tables() -> void:
	var seen := {}
	for path in [CSV_PATH, STORY_CSV_PATH]:
		for row in _read_csv(path).slice(1):
			assert_false(seen.has(row[0]), "'%s' iki tabloda da tanımlı" % row[0])
			seen[row[0]] = true


func test_scene_text_keys_exist_in_csv() -> void:
	# Sahnelerde BÜYÜK_HARF_ANAHTAR biçimindeki her metin CSV'de tanımlı olmalı.
	var keys := _keys()
	var key_pattern := RegEx.create_from_string("\\btext = \"([A-Z][A-Z0-9_]+)\"")
	for file_name in DirAccess.get_files_at(SCENES_DIR):
		if file_name.get_extension() != "tscn":
			continue
		var content := FileAccess.get_file_as_string(SCENES_DIR.path_join(file_name))
		for found in key_pattern.search_all(content):
			assert_true(found.get_string(1) in keys, "%s: '%s' anahtarı strings.csv'de yok" % [file_name, found.get_string(1)])


func test_ui_script_text_keys_exist_in_csv() -> void:
	# scripts/ui içindeki tr("ANAHTAR") çağrılarının hepsi CSV'de tanımlı olmalı (sahne taraması bunları görmez).
	var keys := _keys()
	var pattern := RegEx.create_from_string("\\btr\\(\"([A-Z][A-Z0-9_]+)\"\\)")
	var checked := 0
	for file_name in DirAccess.get_files_at("res://scripts/ui"):
		if file_name.get_extension() != "gd":
			continue
		var content := FileAccess.get_file_as_string("res://scripts/ui".path_join(file_name))
		for found in pattern.search_all(content):
			checked += 1
			assert_true(found.get_string(1) in keys, "%s: '%s' anahtarı strings.csv'de yok" % [file_name, found.get_string(1)])
	assert_true(checked > 20, "tarama gerçekten anahtar bulmalı (%d)" % checked)


func test_dynamic_key_families_are_complete() -> void:
	# Kodda tr("ÖNEK_%s" % değer) ile üretilen anahtar aileleri.
	var keys := _keys()
	var rules: Array = JsonIO.read_dict("res://data/rules.json")["rules"]
	for rule: Dictionary in rules:
		for suffix in ["", "_DESC"]:
			assert_true(("RULE_%s%s" % [rule["id"], suffix]) in keys, "RULE_%s%s" % [rule["id"], suffix])
	for fate in ["ACCEPT", "RETURN", "CONFISCATE"]:
		assert_true(("FATE_" + fate) in keys, "FATE_" + fate)
	for decision in ["COMPLETE", "REJECT", "POLICE"]:
		assert_true(("DECISION_" + decision) in keys, "DECISION_" + decision)
	for over in ["FIRED", "EVICTED", "FAMILY_LEFT", "ARRESTED"]:
		assert_true(("END_OVER_" + over) in keys, "END_OVER_" + over)
	for position in ["LEFT", "CENTER", "RIGHT"]:
		assert_true(("DESK_UV_AT_" + position) in keys, "DESK_UV_AT_" + position)
	var book := CurrencyBook.load_default()
	for code in book.codes():
		assert_true(book.name_key(code) in keys)


func test_switching_locale_changes_text() -> void:
	TranslationServer.set_locale("tr")
	assert_eq(tree.root.tr("MENU_SETTINGS"), "Ayarlar")
	TranslationServer.set_locale("en")
	assert_eq(tree.root.tr("MENU_SETTINGS"), "Settings")
	tree.root.get_node("SettingsManager").apply_language()


func test_unsupported_language_falls_back_to_default() -> void:
	var settings := tree.root.get_node("SettingsManager")
	var original: String = settings.get_value("game", "language")
	settings.set_value("game", "language", "xx", false)
	assert_eq(settings.apply_language(), "en")
	settings.set_value("game", "language", original, false)
