extends TestCase

## Yerelleştirme testleri: tablo tam mı, biçim yer tutucuları dillerde uyuşuyor mu,
## koddaki anahtarların hepsi tabloda mı, kullanılmayan anahtar var mı, dil değişince çıktı değişiyor mu.
## Yedi dil: tr (kaynak), en, es, pt, de, ja, ko. CSV biçimi, Türkçe kalıntısı, yazım/noktalama, yerel ayar eşlemesi,
## yedek zinciri ve yazı tipi kapsamı da burada denetlenir.

const CSV_PATH: String = "res://data/i18n/strings.csv"
const SCAN_ROOTS: Array[String] = ["res://scripts", "res://scenes"]
## `%%` düz yüzde işaretidir; yer tutucu sayılmaz.
const PLACEHOLDER_PATTERN: String = "%[ds]"
const KEY_PATTERN: String = "^[A-Z][A-Z0-9_]*$"
const COLUMNS: PackedStringArray = ["keys", "tr", "en", "es", "pt", "de", "ja", "ko"]
## Türkçe'ye özgü harfler (ş ğ ı İ); başka dillerde geçmemeli. ç ö ü pt/de/es'te meşrudur, bu yüzden aranmaz.
const TURKISH_ONLY_PATTERN: String = "[şŞğĞıİ]"
## Kaynakla aynı kalabilen (çevrilmeyen) hücreler: [anahtar, dil kodları ("*" = hepsi)].
const SAME_AS_SOURCE_OK: Dictionary = {
	"MAP_DIVIDER_JOIN": "*", "ZEN_TITLE": "en pt de es", "META_SET_TURKIYE": "en", "TUT_POLLEN_TITLE": "es",
}
const CJK_PATTERN: String = "[\u3040-\u30ff\u4e00-\u9fff\uac00-\ud7a3]"
## ja/ko'da CJK harf taşımayabilen hücreler (marka adı, "OK", ayraç).
const NO_CJK_OK: Array[String] = ["GAME_TITLE", "MAP_DIVIDER_JOIN", "OK"]
const DEVICE_LOCALES: Dictionary = {
	"pt_BR": "pt", "pt-BR": "pt", "pt_PT": "pt", "pt-PT": "pt", "pt": "pt", "de_DE": "de", "de-AT": "de", "de_CH": "de",
	"ja_JP": "ja", "ja": "ja", "ko_KR": "ko", "ko-KR": "ko", "tr_TR": "tr", "es_MX": "es", "es-419": "es", "en_GB": "en",
	"zh_Hans_CN": "en", "fr_FR": "en", "": "en", "PT_br": "pt",
}
const MIN_KEYS: int = 50
## Kodda anahtar gibi görünen (aile önekli) her sabit metin tabloda olmalı: sözlükte tutulan
## (`Loc.t(DEĞİŞKEN)` ile çözülen) anahtarlar da yakalansın.
const KEY_FAMILY_PATTERN: String = "\"((?:TUT|RET|META|MAP|ZEN|NET|SHOP|DAILY|PLACE|SEASON|UI|MACHINES?|LOSE|WIN|RESULT|SETTINGS|PATTERN)_[A-Z0-9_]+)\""
## Uzunluk bütçeleri (karakter): [anahtar deseni, en çok karakter]. İlk eşleşen geçerlidir;
## en uzun dil (tr/en/es) ölçülür. Düğmeler en katı: 1080 genişlikte tek satıra sığmalı.
const LENGTH_BUDGETS: Array = [
	["^(OK|MENU_PLAY|RESULT_RETRY|RESULT_MENU|WIN_CONTINUE|RESUME|LOSE_RETRY|LOSE_REVIVE|LOSE_REVIVE_MOVES|DAILY_PLAY|DAILY_CLAIM|DAILY_CLAIMED_TODAY|DAILY_CLOSE|RET_CLAIM|ZEN_START|NET_RETRY|MAP_REPLAY|SHOP_FREE_ONE)$", 20],
	["^(SHOP_RESTORE|SHOP_REMOVE_ADS|UI_PRIVACY_OPTIONS|UI_PRIVACY_POLICY)$", 26],
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
	assert_true(header == COLUMNS, "başlık keys,tr,en,es,pt,de,ja,ko olmalı")
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
		assert_eq(row.size(), COLUMNS.size(), "%s sütun sayısı" % key)
		for column: int in range(1, row.size()):
			assert_false(row[column].strip_edges().is_empty(), "%s sütun %d boş" % [key, column])


func test_placeholders_match_across_languages() -> void:
	_load_table()
	for key: String in _table.keys():
		var row: PackedStringArray = _table[key]
		if row.size() < COLUMNS.size():
			continue
		var reference: Array[String] = _placeholders(row[1])
		for column: int in range(2, COLUMNS.size()):
			assert_eq(_placeholders(row[column]), reference, "%s %s yer tutucuları" % [key, COLUMNS[column]])


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
	Loc.set_language("fr")
	assert_eq(Loc.language(), "en", "bilinmeyen dil İngilizce olur")
	Loc.set_language(Loc.LANG_PT)
	assert_eq(Loc.t("LOSE_RETRY"), "Tentar de novo")
	Loc.set_language(Loc.LANG_DE)
	assert_eq(Loc.t("LOSE_RETRY"), "Nochmal versuchen")
	Loc.set_language(Loc.LANG_JA)
	assert_eq(Loc.t("LOSE_RETRY"), "再挑戦")
	Loc.set_language(Loc.LANG_KO)
	assert_eq(Loc.language(), "ko")
	assert_eq(Loc.t("LOSE_RETRY").replace("\u2060", ""), "다시 도전")
	Loc.set_language(Loc.LANG_TR)


func test_plural_and_format() -> void:
	Loc.set_language(Loc.LANG_EN)
	assert_eq(Loc.n("LOSE_LEFT_FEW_ONE", "LOSE_LEFT_FEW_OTHER", 1) % "1", "Only 1 item left")
	assert_eq(Loc.n("LOSE_LEFT_FEW_ONE", "LOSE_LEFT_FEW_OTHER", 4) % "4", "Only 4 items left")
	assert_eq(Loc.f("LEVEL", [7]), "Level 7")
	Loc.set_language(Loc.LANG_ES)
	assert_eq(Loc.n("LOSE_LEFT_FEW_ONE", "LOSE_LEFT_FEW_OTHER", 1) % "1", "Solo queda 1 prenda")
	assert_eq(Loc.n("LOSE_LEFT_FEW_ONE", "LOSE_LEFT_FEW_OTHER", 30) % "30", "Solo quedan 30 prendas")
	Loc.set_language(Loc.LANG_PT)
	assert_eq(Loc.n("LOSE_LEFT_FEW_ONE", "LOSE_LEFT_FEW_OTHER", 1) % "1", "Só falta 1 peça")
	assert_eq(Loc.n("LOSE_LEFT_FEW_ONE", "LOSE_LEFT_FEW_OTHER", 3) % "3", "Só faltam 3 peças")
	Loc.set_language(Loc.LANG_DE)
	assert_eq(Loc.n("LOSE_LEFT_FEW_ONE", "LOSE_LEFT_FEW_OTHER", 1) % "1", "Nur noch 1 Teil")
	assert_eq(Loc.n("LOSE_LEFT_FEW_ONE", "LOSE_LEFT_FEW_OTHER", 5) % "5", "Nur noch 5 Teile")
	# ja/ko'da çoğul biçimi yok: iki satır aynı metni taşır.
	for code: String in [Loc.LANG_JA, Loc.LANG_KO]:
		Loc.set_language(code)
		assert_eq(Loc.n("LOSE_LEFT_FEW_ONE", "LOSE_LEFT_FEW_OTHER", 1), Loc.n("LOSE_LEFT_FEW_ONE", "LOSE_LEFT_FEW_OTHER", 4), "%s: çoğul yok" % code)
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
				for column: int in range(1, COLUMNS.size()):
					assert_eq(_placeholders(_table[key][column]), _placeholders(_table[other][column]), "%s/%s %s yer tutucu" % [key, other, COLUMNS[column]])
				# Çoğul biçimi olmayan diller iki anahtarda aynı metni taşır.
				for column: int in [1, 6, 7]:
					assert_eq(_table[key][column], _table[other][column], "%s/%s %s çoğulsuz dil aynı olmalı" % [key, other, COLUMNS[column]])
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


## Çeviri hücrelerinde Türkçe'ye özgü harf (ş ğ ı İ) ve kaynakla birebir aynı metin kalıntısı olmamalı.
func test_no_leftover_turkish() -> void:
	_load_table()
	var turkish: RegEx = RegEx.new()
	turkish.compile(TURKISH_ONLY_PATTERN)
	for key: String in _table.keys():
		var row: PackedStringArray = _table[key]
		for column: int in range(2, COLUMNS.size()):
			var code: String = COLUMNS[column]
			assert_true(turkish.search(row[column]) == null, "%s: %s hücresinde Türkçe harf kalmış: %s" % [key, code, row[column]])
			if row[column] == row[1]:
				var allowed: String = String(SAME_AS_SOURCE_OK.get(key, ""))
				assert_true(allowed == "*" or allowed.split(" ").has(code), "%s: %s hücresi Türkçe ile birebir aynı" % [key, code])


## ja/ko hücreleri gerçekten CJK harf taşır (Latin/İngilizce metin kalmamış).
func test_cjk_columns_contain_cjk() -> void:
	_load_table()
	var cjk: RegEx = RegEx.new()
	cjk.compile(CJK_PATTERN)
	for key: String in _table.keys():
		if NO_CJK_OK.has(key):
			continue
		var row: PackedStringArray = _table[key]
		for column: int in [6, 7]:
			assert_true(cjk.search(row[column]) != null, "%s: %s hücresinde CJK harf yok: %s" % [key, COLUMNS[column], row[column]])


## Japonca: tam genişlikli noktalama (、。！？：（）), CJK harfler arasında boşluk yok, ASCII ! ? yok.
func test_japanese_typography() -> void:
	_load_table()
	var gap: RegEx = RegEx.new()
	gap.compile(CJK_PATTERN + " " + CJK_PATTERN)
	for key: String in _table.keys():
		var ja: String = _table[key][6]
		assert_true(gap.search(ja) == null, "%s: ja CJK harfler arasında boşluk: %s" % [key, ja])
		assert_false(ja.contains("!") or ja.contains("?") or ja.contains(", ") or ja.ends_with("."), "%s: ja noktalama tam genişlikli olmalı: %s" % [key, ja])


## Korece: ! ve ? kalır (Korece'de ASCII kullanılır); virgül/nokta sonrası boşluk var; Japon noktalaması yok.
func test_korean_typography() -> void:
	_load_table()
	for key: String in _table.keys():
		var ko: String = _table[key][7]
		for japanese: String in ["。", "、", "！", "？"]:
			assert_false(ko.contains(japanese), "%s: ko'da Japon noktalaması: %s" % [key, ko])


## Almanca: samimi "du" (resmi "Sie"/"Ihre" yok); Portekizce: Brezilya yazımı ve "você".
func test_german_and_portuguese_register() -> void:
	_load_table()
	var formal_de: RegEx = RegEx.new()
	formal_de.compile("(^|[ .:;!?])(Sie|Ihr|Ihre|Ihnen|Ihren)( |$)")
	for key: String in _table.keys():
		var row: PackedStringArray = _table[key]
		assert_true(formal_de.search(row[5]) == null, "%s: de resmi hitap: %s" % [key, row[5]])
		for european: String in ["ecrã", "equipa", "telemóvel", "utilizador", "ficheiro", "estás", "tens ", "ligação"]:
			assert_false(row[4].contains(european), "%s: pt Brezilya yazımı bekleniyor (%s)" % [key, european])
		assert_false(row[4].contains(" tu ") or row[4].begins_with("Tu "), "%s: pt 'você' beklenir" % key)


## CSV biçimi: BOM yok, CR yok, hücrede satır sonu/başta-sonda boşluk yok, alıntı yalnız gerektiğinde, kayıt sayısı = satır sayısı.
func test_csv_is_well_formed() -> void:
	var raw: String = FileAccess.get_file_as_string(CSV_PATH)
	assert_false(raw.begins_with("\ufeff"), "BOM olmamalı")
	assert_false(raw.contains("\r"), "CR (Windows satır sonu) olmamalı")
	assert_true(raw.ends_with("\n") and not raw.ends_with("\n\n"), "dosya tek satır sonuyla bitmeli")
	var lines: PackedStringArray = raw.trim_suffix("\n").split("\n")
	var file: FileAccess = FileAccess.open(CSV_PATH, FileAccess.READ)
	var index: int = 0
	while not file.eof_reached() and index < lines.size():
		var row: PackedStringArray = file.get_csv_line()
		assert_eq(row.size(), COLUMNS.size(), "satır %d sütun sayısı" % (index + 1))
		var rebuilt: PackedStringArray = []
		for cell: String in row:
			assert_eq(cell, cell.strip_edges(), "satır %d: hücre başında/sonunda boşluk: '%s'" % [index + 1, cell])
			assert_false(cell.contains("\n") or cell.contains("\t"), "satır %d: hücrede satır sonu/sekme" % (index + 1))
			if cell.contains(",") or cell.contains("\""):
				rebuilt.append("\"" + cell.replace("\"", "\"\"") + "\"")
			else:
				rebuilt.append(cell)
		assert_eq(",".join(rebuilt), lines[index], "satır %d: alıntı biçimi" % (index + 1))
		index += 1
	assert_eq(index, lines.size(), "kayıt sayısı satır sayısına eşit olmalı (çok satırlı hücre yok)")


func test_language_for_locale_mapping() -> void:
	for locale: String in DEVICE_LOCALES.keys():
		assert_eq(Loc.language_for_locale(locale), String(DEVICE_LOCALES[locale]), "yerel ayar eşlemesi: '%s'" % locale)
	for code: String in Loc.LANGUAGES:
		assert_true(Loc.NATIVE_NAMES.has(code), "yerel ad tanımlı olmalı: %s" % code)
		assert_eq(Loc.language_for_locale(code), code)


## İlk açılış kuralı: kayıt yoksa cihaz dili (yedi dilden biriyse), değilse İngilizce; oyuncunun seçimi her zaman kazanır.
func test_first_run_language_rule() -> void:
	var progress: Node = autoload_node("Progress")
	var was_persist: Variant = progress.get("persist")
	progress.set("persist", false)
	var cases: Dictionary = {"fr_FR": "en", "tr_TR": "tr", "pt_BR": "pt", "": "en", "xx_YY": "en", "zh_Hans_CN": "en", "ko_KR": "ko"}
	for locale: String in cases.keys():
		progress.call("set_module_value", Loc.SETTINGS_SECTION, Loc.SETTINGS_KEY, "")
		Loc.set_language(Loc.LANG_TR)
		Loc.apply_saved_for(locale)
		assert_eq(Loc.language(), String(cases[locale]), "ilk açılış, cihaz '%s'" % locale)
		assert_eq(String(progress.call("module_value", Loc.SETTINGS_SECTION, Loc.SETTINGS_KEY, "")), String(cases[locale]), "ilk açılış dili kaydedilir: '%s'" % locale)
	# Oyuncunun seçimi cihaz dilini ezer.
	Loc.choose(Loc.LANG_DE)
	Loc.set_language(Loc.LANG_TR)
	Loc.apply_saved_for("tr_TR")
	assert_eq(Loc.language(), "de", "kayıtlı seçim cihaz dilinden önce gelir")
	# Geçersiz kayıt yok sayılır: cihaz diline, o da bilinmiyorsa İngilizceye düşer.
	progress.call("set_module_value", Loc.SETTINGS_SECTION, Loc.SETTINGS_KEY, "xx")
	Loc.apply_saved_for("fr_FR")
	assert_eq(Loc.language(), "en", "geçersiz kayıt -> cihaz -> en")
	assert_eq(String(ProjectSettings.get_setting("internationalization/locale/fallback", "")), "en", "motor yedek dili en")
	progress.call("set_module_value", Loc.SETTINGS_SECTION, Loc.SETTINGS_KEY, "")
	Loc.set_language(Loc.LANG_TR)
	progress.set("persist", was_persist)


## Eksik anahtar önce İngilizceye, sonra Türkçeye düşer; hiçbirinde yoksa anahtarın kendisi döner.
func test_missing_key_falls_back_to_english() -> void:
	var extra: Translation = Translation.new()
	extra.locale = "en"
	extra.add_message("ZZ_ONLY_IN_ENGLISH", "english text")
	TranslationServer.add_translation(extra)
	for code: String in [Loc.LANG_JA, Loc.LANG_KO, Loc.LANG_PT, Loc.LANG_DE]:
		Loc.set_language(code)
		assert_eq(Loc.t("ZZ_ONLY_IN_ENGLISH").replace("\u2060", ""), "english text", "%s: eksik anahtar en'e düşer" % code)
		assert_eq(Loc.t("ZZ_NOWHERE"), "ZZ_NOWHERE", "%s: hiçbirinde yoksa anahtar" % code)
	TranslationServer.remove_translation(extra)
	Loc.set_language(Loc.LANG_TR)
	assert_eq(Loc.KEY_FALLBACK, [Loc.LANG_EN, Loc.LANG_TR] as Array[String], "yedek sırası en -> tr")


## Korece satırlarda Hangul heceleri arasına WORD JOINER konur; diğer dillerde metin değişmez.
func test_korean_keeps_words_together() -> void:
	Loc.set_language(Loc.LANG_KO)
	var text: String = Loc.t("TUT_UNDO_LINE")
	assert_true(text.contains("\u2060"), "ko: kelime bağlayıcı bulunmalı")
	assert_eq(text.replace("\u2060", ""), _table_cell("TUT_UNDO_LINE", 7), "ko: bağlayıcı çıkarılınca CSV metni")
	Loc.set_language(Loc.LANG_JA)
	assert_false(Loc.t("TUT_UNDO_LINE").contains("\u2060"), "ja: bağlayıcı yok")
	Loc.set_language(Loc.LANG_TR)


func _table_cell(key: String, column: int) -> String:
	_load_table()
	return String((_table[key] as PackedStringArray)[column])


## Yazı tipi: Latin dillerin (tr/en/es/pt/de) her karakteri paketli Baloo alt kümesinde var; CJK yedek zinciri
## yalnız ja/ko'da kurulur ve Latin dillerde boştur.
func test_latin_columns_covered_by_bundled_font() -> void:
	_load_table()
	Loc.set_language(Loc.LANG_TR)
	var font: Font = LocFonts.base_font()
	assert_eq(font.fallbacks.size(), 0, "tr: yedek zinciri boş")
	var missing: String = ""
	for key: String in _table.keys():
		for column: int in range(1, 6):
			for index: int in (_table[key] as PackedStringArray)[column].length():
				var code: int = (_table[key] as PackedStringArray)[column].unicode_at(index)
				if code > 0x20 and not font.has_char(code) and not missing.contains(char(code)):
					missing += char(code)
	assert_eq(missing, "", "Baloo alt kümesinde olmayan Latin karakterler: %s" % missing)
	Loc.set_language(Loc.LANG_JA)
	assert_eq(font.fallbacks.size(), 2, "ja: CJK yedek zinciri kurulu")
	Loc.set_language(Loc.LANG_KO)
	assert_eq(font.fallbacks.size(), 2, "ko: CJK yedek zinciri kurulu")
	Loc.set_language(Loc.LANG_DE)
	assert_eq(font.fallbacks.size(), 0, "de: yedek zinciri boş")
	assert_true(LocFonts.selector_font(Loc.LANG_JA) != font and LocFonts.selector_font(Loc.LANG_KO) != font, "seçici ja/ko adları sistem yazı tipiyle çizilir")
	Loc.set_language(Loc.LANG_TR)
