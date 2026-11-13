extends TestCase

## Yerelleştirme testleri: tablo tam mı, biçim yer tutucuları dillerde uyuşuyor mu,
## koddaki anahtarların hepsi tabloda mı, kullanılmayan anahtar var mı, dil değişince çıktı değişiyor mu.

const CSV_PATH: String = "res://data/i18n/strings.csv"
const SCAN_ROOTS: Array[String] = ["res://scripts", "res://scenes"]
## `%%` düz yüzde işaretidir; yer tutucu sayılmaz.
const PLACEHOLDER_PATTERN: String = "%[ds]"
const KEY_PATTERN: String = "^[A-Z][A-Z0-9_]*$"
const MIN_KEYS: int = 50

var _table: Dictionary = {}


func _load_table() -> void:
	_table.clear()
	var file: FileAccess = FileAccess.open(CSV_PATH, FileAccess.READ)
	assert_true(file != null, "CSV açılmalı")
	if file == null:
		return
	var header: PackedStringArray = file.get_csv_line()
	assert_true(header == PackedStringArray(["keys", "tr", "en", "es"]), "başlık keys,tr,en,es olmalı")
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() < 2 or row[0].is_empty():
			continue
		_table[row[0]] = row


func _placeholders(text: String) -> Array[String]:
	var found: Array[String] = []
	var clean: String = text.replace("%%", "")
	var regex: RegEx = RegEx.new()
	regex.compile(PLACEHOLDER_PATTERN)
	for hit: RegExMatch in regex.search_all(clean):
		found.append(hit.get_string())
	return found


func _collect(dir_path: String, files: Array[String]) -> void:
	for sub: String in DirAccess.get_directories_at(dir_path):
		_collect(dir_path.path_join(sub), files)
	for file_name: String in DirAccess.get_files_at(dir_path):
		if file_name.ends_with(".gd") or file_name.ends_with(".tscn"):
			files.append(dir_path.path_join(file_name))


func _all_source() -> String:
	var files: Array[String] = []
	for root_dir: String in SCAN_ROOTS:
		_collect(root_dir, files)
	var text: String = ""
	for path: String in files:
		text += FileAccess.get_file_as_string(path) + "\n"
	return text


func test_every_key_has_all_languages() -> void:
	_load_table()
	assert_true(_table.size() > MIN_KEYS, "tablo dolu olmalı")
	var key_regex: RegEx = RegEx.new()
	key_regex.compile(KEY_PATTERN)
	for key: String in _table.keys():
		var row: PackedStringArray = _table[key]
		assert_true(key_regex.search(key) != null, "anahtar UPPER_SNAKE olmalı: %s" % key)
		assert_eq(row.size(), 4, "%s dört sütun" % key)
		for column: int in range(1, row.size()):
			assert_false(row[column].strip_edges().is_empty(), "%s sütun %d boş" % [key, column])


func test_placeholders_match_across_languages() -> void:
	_load_table()
	for key: String in _table.keys():
		var row: PackedStringArray = _table[key]
		if row.size() < 4:
			continue
		var reference: Array[String] = _placeholders(row[1])
		assert_eq(_placeholders(row[2]), reference, "%s en yer tutucuları" % key)
		assert_eq(_placeholders(row[3]), reference, "%s es yer tutucuları" % key)


func test_code_keys_exist_in_table() -> void:
	_load_table()
	var regex: RegEx = RegEx.new()
	regex.compile("Loc\\.(?:t|f|n)\\(\\s*\"([A-Z0-9_]+)\"(?:\\s*,\\s*\"([A-Z0-9_]+)\")?")
	var checked: int = 0
	for hit: RegExMatch in regex.search_all(_all_source()):
		for group: int in [1, 2]:
			var key: String = hit.get_string(group)
			if not key.is_empty():
				checked += 1
				assert_true(_table.has(key), "kodda geçen anahtar tabloda yok: %s" % key)
	assert_true(checked > 0, "kodda anahtar bulunmalı")


func test_no_unused_keys() -> void:
	_load_table()
	var source: String = _all_source()
	for key: String in _table.keys():
		assert_true(source.contains("\"%s\"" % key), "kullanılmayan anahtar: %s" % key)


func test_holder_tables_resolve() -> void:
	Loc.set_language(Loc.LANG_EN)
	for feature: String in TutorialStrings.CARDS.keys():
		var spec: Dictionary = TutorialStrings.CARDS[feature]
		assert_true(TutorialStrings.card_title(feature) != String(spec["title"]), "başlık çevrilmeli: %s" % feature)
		assert_true(TutorialStrings.card_line(feature) != String(spec["line"]), "satır çevrilmeli: %s" % feature)
	for id: String in MetaStrings.LOCATION_KEYS.keys():
		assert_true(MetaStrings.location_name(id) != MetaStrings.LOCATION_KEYS[id], "konum çevrilmeli: %s" % id)
	for id: String in MetaStrings.TASK_KEYS.keys():
		assert_true(MetaStrings.task_name(id) != MetaStrings.TASK_KEYS[id], "görev çevrilmeli: %s" % id)
	for id: String in MetaStrings.SET_KEYS.keys():
		assert_true(MetaStrings.country_name(id) != MetaStrings.SET_KEYS[id], "ülke çevrilmeli: %s" % id)
	Loc.set_language(Loc.LANG_TR)


func test_language_switch_changes_output() -> void:
	Loc.set_language(Loc.LANG_TR)
	assert_eq(Loc.t("LOSE_RETRY"), "Tekrar dene")
	Loc.set_language(Loc.LANG_EN)
	assert_eq(Loc.t("LOSE_RETRY"), "Try again")
	assert_eq(Loc.language(), "en")
	Loc.set_language(Loc.LANG_ES)
	assert_eq(Loc.t("LOSE_RETRY"), "Reintentar")
	Loc.set_language("de")
	assert_eq(Loc.language(), "en", "bilinmeyen dil İngilizce olur")
	Loc.set_language(Loc.LANG_TR)


func test_plural_and_format() -> void:
	Loc.set_language(Loc.LANG_EN)
	assert_eq(Loc.n("LOSE_LEFT_FEW_ONE", "LOSE_LEFT_FEW_OTHER", 1) % "1", "Only 1 item left")
	assert_eq(Loc.n("LOSE_LEFT_FEW_ONE", "LOSE_LEFT_FEW_OTHER", 4) % "4", "Only 4 items left")
	assert_eq(Loc.f("LEVEL", [7]), "Level 7")
	Loc.set_language(Loc.LANG_ES)
	assert_eq(Loc.n("LOSE_COINS_ONE", "LOSE_COINS_OTHER", 1) % 1, "Seguir por 1 moneda")
	assert_eq(Loc.n("LOSE_COINS_ONE", "LOSE_COINS_OTHER", 30) % 30, "Seguir por 30 monedas")
	Loc.set_language(Loc.LANG_TR)
	assert_eq(Loc.n("LOSE_COINS_ONE", "LOSE_COINS_OTHER", 1) % 1, "1 jeton ile devam")


func test_unknown_key_returns_key() -> void:
	assert_eq(Loc.t("NO_SUCH_KEY_XYZ"), "NO_SUCH_KEY_XYZ")
