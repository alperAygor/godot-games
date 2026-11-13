extends TestCase

## Yerelleştirme testleri: tablo tam mı, biçim yer tutucuları dillerde uyuşuyor mu,
## koddaki anahtarların hepsi tabloda mı, kullanılmayan anahtar var mı, dil değişince çıktı değişiyor mu.

const CSV_PATH: String = "res://data/i18n/strings.csv"
const SCAN_ROOTS: Array[String] = ["res://scripts", "res://scenes"]
## `%%` düz yüzde işaretidir; yer tutucu sayılmaz.
const PLACEHOLDER_PATTERN: String = "%[ds]"
const KEY_PATTERN: String = "^[A-Z][A-Z0-9_]*$"
const MIN_KEYS: int = 50
## Kodda anahtar gibi görünen (aile önekli) her sabit metin tabloda olmalı: sözlükte tutulan
## (`Loc.t(DEĞİŞKEN)` ile çözülen) anahtarlar da yakalansın.
const KEY_FAMILY_PATTERN: String = "\"((?:TUT|RET|META|MAP|ZEN|NET|SHOP|DAILY|PLACE|SEASON|UI|MACHINES?|LOSE|WIN|RESULT|SETTINGS|PATTERN)_[A-Z0-9_]+)\""
## Uzunluk bütçeleri (karakter): [anahtar deseni, en çok karakter]. İlk eşleşen geçerlidir;
## en uzun dil (tr/en/es) ölçülür. Düğmeler en katı: 1080 genişlikte tek satıra sığmalı.
const LENGTH_BUDGETS: Array = [
	["^(OK|MENU_PLAY|RESULT_RETRY|RESULT_MENU|WIN_CONTINUE|RESUME|LOSE_RETRY|LOSE_REVIVE|LOSE_REVIVE_MOVES|DAILY_PLAY|DAILY_CLAIM|DAILY_CLAIMED_TODAY|DAILY_CLOSE|RET_CLAIM|ZEN_START|NET_RETRY|MAP_REPLAY|SHOP_FREE_ONE)$", 20],
	["^(SHOP_RESTORE|SHOP_REMOVE_ADS|UI_PRIVACY_OPTIONS)$", 26],
	["^(SHOP_TITLE|SHOP_BOOSTERS|SHOP_SKINS|SHOP_PINS|SHOP_ROPES|SETTINGS_[A-Z]+|UI_SETTING_[A-Z]+)$", 16],
	["^TUT_.*_TITLE$", 24],
	["^TUT_.*_LINE$", 100],
	["^META_(LOC|TASK|SET)_", 26],
	["^RET_[WG]_", 32],
	["^RET_M_", 48],
	["^RET_N_.*_T$", 40],
	["^RET_N_.*_B$", 48],
	["^(PLACE_|SEASON_ARRIVE_|MAP_SEASON_)", 26],
	["^MACHINE_LOCKED$", 30],
	["^MACHINE_", 22],
	["^SHOP_", 60],
	["^(DAILY|ZEN|NET|WIN|LOSE|RESULT)_", 50],
	["^RET_", 60],
]

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
	assert_eq(Loc.n("LOSE_LEFT_FEW_ONE", "LOSE_LEFT_FEW_OTHER", 1) % "1", "Solo queda 1 prenda")
	assert_eq(Loc.n("LOSE_LEFT_FEW_ONE", "LOSE_LEFT_FEW_OTHER", 30) % "30", "Solo quedan 30 prendas")
	Loc.set_language(Loc.LANG_TR)
	assert_eq(Loc.n("LOSE_LEFT_FEW_ONE", "LOSE_LEFT_FEW_OTHER", 1) % "1", "Sadece 1 çamaşır kaldı")


func test_unknown_key_returns_key() -> void:
	assert_eq(Loc.t("NO_SUCH_KEY_XYZ"), "NO_SUCH_KEY_XYZ")


func test_no_duplicate_keys() -> void:
	_load_table()
	assert_eq(_duplicates, [] as Array[String], "yinelenen anahtarlar: %s" % str(_duplicates))


func test_family_keys_in_source_exist_in_table() -> void:
	_load_table()
	var regex: RegEx = RegEx.new()
	regex.compile(KEY_FAMILY_PATTERN)
	var checked: int = 0
	for hit: RegExMatch in regex.search_all(_all_source()):
		var key: String = hit.get_string(1)
		checked += 1
		assert_true(_table.has(key), "kodda geçen aile anahtarı tabloda yok: %s" % key)
	assert_true(checked > 20, "aile anahtarları bulunmalı")


func test_length_budgets() -> void:
	_load_table()
	var compiled: Array = []
	for budget: Array in LENGTH_BUDGETS:
		var regex: RegEx = RegEx.new()
		regex.compile(String(budget[0]))
		compiled.append([regex, int(budget[1])])
	for key: String in _table.keys():
		for entry: Array in compiled:
			if (entry[0] as RegEx).search(key) != null:
				var longest: int = _longest(_table[key])
				assert_true(longest <= int(entry[1]), "%s çok uzun: %d > %d" % [key, longest, int(entry[1])])
				break


func test_spanish_punctuation_and_register() -> void:
	_load_table()
	for key: String in _table.keys():
		var row: PackedStringArray = _table[key]
		var es: String = row[3]
		if es.contains("?"):
			assert_true(es.contains("¿"), "%s: es soru işareti ¿ ister" % key)
		if es.ends_with("!"):
			assert_true(es.contains("¡"), "%s: es ünlem ¡ ister" % key)
		# Samimi "tú": resmi "usted" kalıpları yok.
		for formal: String in ["Usted", " usted", "Ingrese", "Seleccione", "Presione"]:
			assert_false(es.contains(formal), "%s: es resmi hitap: %s" % [key, formal])
		# Türkçede sayıdan sonra ek ('de/'lü) sayıya göre değişir: yer tutucudan sonra kesme yok.
		assert_false(row[1].contains("%d'") or row[1].contains("%s'"), "%s: tr yer tutucudan sonra ek yok" % key)


func test_spelling_is_consistent() -> void:
	_load_table()
	for key: String in _table.keys():
		var row: PackedStringArray = _table[key]
		# İngilizce tek yazım: ABD ("color"); Latin Amerika İspanyolcası: "videos", "rompecabezas".
		for british: String in ["colour", "Colour"]:
			assert_false(row[2].contains(british), "%s: en 'color' yazımı" % key)
		assert_false(row[3].contains("vídeo"), "%s: es 'video' (LatAm)" % key)
		assert_false(row[3].contains("puzzle"), "%s: es 'rompecabezas'" % key)
		assert_false(row[3].contains("colgador"), "%s: es raf terimi 'percha'" % key)
		assert_false(row[3].contains("tendedero"), "%s: es raf terimi 'percha'" % key)
		assert_false(row[2].contains("slot"), "%s: en raf terimi 'rack spot'" % key)
		assert_false(row[2].contains("..") and not row[2].contains("..."), "%s: nokta" % key)


func test_plural_pairs_present() -> void:
	_load_table()
	for key: String in _table.keys():
		if key.ends_with("_ONE"):
			var other: String = key.trim_suffix("_ONE") + "_OTHER"
			if _table.has(other):
				assert_eq(_placeholders(_table[key][2]), _placeholders(_table[other][2]), "%s/%s en yer tutucu" % [key, other])
	Loc.set_language(Loc.LANG_EN)
	assert_eq(Loc.n("ZEN_TOTAL_ONE", "ZEN_TOTAL_OTHER", 1) % 1, "1 board cleared in total")
	assert_eq(Loc.n("ZEN_TOTAL_ONE", "ZEN_TOTAL_OTHER", 5) % 5, "5 boards cleared in total")
	Loc.set_language(Loc.LANG_TR)


func test_language_persists_across_restart() -> void:
	var progress: Node = autoload_node("Progress")
	var was_persist: Variant = progress.get("persist")
	progress.set("persist", false)
	Loc.choose(Loc.LANG_ES)
	Loc.set_language(Loc.LANG_TR)
	Loc.apply_saved()
	assert_eq(Loc.language(), "es", "kayıtlı dil yeniden açılışta uygulanır")
	Loc.choose(Loc.LANG_TR)
	progress.set("persist", was_persist)
