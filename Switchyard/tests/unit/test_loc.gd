extends TestCase

## Yerelleştirme testleri: tablo tam mı, biçim yer tutucuları dillerde uyuşuyor mu,
## koddaki anahtarların hepsi tabloda mı, kullanılmayan anahtar var mı, dil değişince çıktı değişiyor mu.

const CSV_PATH: String = "res://data/i18n/strings.csv"
const SCAN_ROOTS: Array[String] = ["res://scripts", "res://scenes"]
## `%%` düz yüzde işaretidir; yer tutucu sayılmaz.
const PLACEHOLDER_PATTERN: String = "%[ds]"
const KEY_PATTERN: String = "^[A-Z][A-Z0-9_]*$"
const MIN_KEYS: int = 15
## Kodda anahtar gibi görünen (aile önekli) her sabit metin tabloda olmalı: sözlükte tutulan
## (`Loc.t(DEĞİŞKEN)` ile çözülen) anahtarlar da yakalansın. Yeni aile eklenince buraya da eklenir.
const KEY_FAMILY_PATTERN: String = "\"((?:NET|UI|LOSE|WIN|SETTINGS|PH|BOOT|GAME|HOME|MAP|HUD|RESULT|AD|SKIP|SHOP)_[A-Z0-9_]+)\""
## Uzunluk bütçeleri (karakter): [anahtar deseni, en çok karakter]. İlk eşleşen geçerlidir;
## en uzun dil (tr/en/es) ölçülür. Düğmeler en katı: 1080 genişlikte tek satıra sığmalı.
const LENGTH_BUDGETS: Array = [
	["^(OK|WIN_CONTINUE|RESUME|LOSE_RETRY|LOSE_REVIVE|NET_RETRY|PH_TAP|PH_LOSE)$", 20],
	["^(HOME_LEVELS|RESULT_NEXT|RESULT_RETRY|SKIP_WATCH|SKIP_CANCEL|SHOP_REMOVE_ADS)$", 20],
	["^(UI_PRIVACY_OPTIONS|SHOP_RESTORE)$", 26],
	["^SETTINGS_[A-Z]+$", 16],
	["^(HUD|MAP_TITLE|MAP_WORLD|RESULT_[0-9]|RESULT_BEST)", 14],
	["^SKIP_BODY$", 70],
	["^(NET|WIN|LOSE|PH|AD|SHOP|MAP|RESULT|SKIP)_", 50],
]
## Şablondan kalan, artık kullanılmayan anahtarlar. strings.csv yalnız sona eklenir (merge=union), bu yüzden
## satırlar silinmez; kullanılmayan-anahtar denetiminden bilerek muaftır.
const RETIRED_KEYS: Array[String] = ["WIN_TITLE", "WIN_CONTINUE", "LOSE_TITLE", "LOSE_REVIVE", "LOSE_RETRY",
	"PH_TAP", "PH_LOSE", "PH_LEFT_ONE", "PH_LEFT_OTHER"]

var _table: Dictionary = {}
var _duplicates: Array[String] = []


func _load_table() -> void:
	_table.clear()
	_duplicates.clear()
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
		if _table.has(row[0]):
			_duplicates.append(row[0])
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


## Anahtar -> en uzun dildeki karakter sayısı.
func _longest(row: PackedStringArray) -> int:
	var longest: int = 0
	for column: int in range(1, row.size()):
		longest = maxi(longest, row[column].length())
	return longest


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


func test_spanish_inverted_marks_are_paired() -> void:
	_load_table()
	for key: String in _table.keys():
		var es: String = (_table[key] as PackedStringArray)[3]
		assert_eq(es.count("¡"), es.count("!"), "%s: ¡ ve ! eşleşmeli" % key)
		assert_eq(es.count("¿"), es.count("?"), "%s: ¿ ve ? eşleşmeli" % key)


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
		if RETIRED_KEYS.has(key):
			continue
		assert_true(source.contains("\"%s\"" % key), "kullanılmayan anahtar: %s" % key)


func test_family_keys_in_source_exist_in_table() -> void:
	_load_table()
	var regex: RegEx = RegEx.new()
	regex.compile(KEY_FAMILY_PATTERN)
	var checked: int = 0
	for hit: RegExMatch in regex.search_all(_all_source()):
		var key: String = hit.get_string(1)
		checked += 1
		assert_true(_table.has(key), "kodda geçen aile anahtarı tabloda yok: %s" % key)
	assert_true(checked > 10, "aile anahtarları bulunmalı")


func test_no_duplicate_keys() -> void:
	_load_table()
	assert_eq(_duplicates, [] as Array[String], "yinelenen anahtarlar: %s" % str(_duplicates))


func test_length_budgets() -> void:
	_load_table()
	for key: String in _table.keys():
		for budget: Array in LENGTH_BUDGETS:
			var regex: RegEx = RegEx.new()
			regex.compile(String(budget[0]))
			if regex.search(key) != null:
				var length: int = _longest(_table[key])
				assert_true(length <= int(budget[1]), "%s çok uzun: %d > %d" % [key, length, int(budget[1])])
				break


func test_language_switch_changes_output() -> void:
	Loc.set_language(Loc.LANG_TR)
	assert_eq(Loc.t("NET_RETRY"), "Tekrar dene")
	Loc.set_language(Loc.LANG_EN)
	assert_eq(Loc.t("NET_RETRY"), "Try again")
	assert_eq(Loc.language(), "en")
	Loc.set_language(Loc.LANG_ES)
	assert_eq(Loc.t("NET_RETRY"), "Reintentar")
	Loc.set_language("de")
	assert_eq(Loc.language(), "en", "bilinmeyen dil İngilizce olur")
	Loc.set_language(Loc.LANG_TR)


func test_plural_helper_picks_one_or_other() -> void:
	Loc.set_language(Loc.LANG_EN)
	assert_eq(Loc.n("NET_TITLE", "NET_RETRY", 1), "Connection required")
	assert_eq(Loc.n("NET_TITLE", "NET_RETRY", 4), "Try again")
	assert_eq(Loc.f("LEVEL", [7]), "Level 7")
	assert_eq(Loc.f("MAP_WORLD", [2]), "World 2")
	Loc.set_language(Loc.LANG_ES)
	assert_eq(Loc.f("RESULT_MOVES", [5, 4]), "Movimientos 5 · Par 4")
	Loc.set_language(Loc.LANG_TR)
	assert_eq(Loc.f("RESULT_MOVES", [5, 4]), "Hamle 5 · Par 4")


func test_unknown_key_returns_key() -> void:
	assert_eq(Loc.t("NO_SUCH_KEY_XYZ"), "NO_SUCH_KEY_XYZ")


func test_detect_device_language_is_supported() -> void:
	assert_true(Loc.detect_device_language() in Loc.LANGUAGES)


func test_apply_from_args_defaults_to_source_language() -> void:
	Loc.apply_from_args(PackedStringArray(["--lang=es"]))
	assert_eq(Loc.language(), "es")
	Loc.apply_from_args(PackedStringArray())
	assert_eq(Loc.language(), "tr")
