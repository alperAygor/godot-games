extends TestCase

## i18n sözleşmesi: TR/EN anahtar paritesi, zorunlu anahtarlar, Loc API davranışı.

const EN_PATH: String = "res://data/i18n/en.json"
const TR_PATH: String = "res://data/i18n/tr.json"
const LEVEL_COUNT: int = 12
const REQUIRED_KEYS: Array[String] = [
	"game.title", "game.subtitle", "menu.play", "menu.levels", "menu.settings",
	"levels.title", "levels.locked", "hud.overload", "hud.connected",
	"fail.title", "fail.revive", "fail.retry", "pause.title", "pause.resume",
	"result.title", "result.stars", "result.next", "result.retry", "result.menu",
	"toast.wrong_socket", "toast.short_circuit", "toast.ad_unavailable", "toast.live_wires",
]


func _load_table(path: String) -> Dictionary:
	assert_true(FileAccess.file_exists(path), "dil dosyası var: %s" % path)
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_true(parsed is Dictionary, "dil dosyası JSON nesnesi: %s" % path)
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


func test_tables_parse() -> void:
	var en: Dictionary = _load_table(EN_PATH)
	var tr: Dictionary = _load_table(TR_PATH)
	assert_greater(float(en.size()), 40.0, "en anahtar sayısı")
	assert_greater(float(tr.size()), 40.0, "tr anahtar sayısı")


func test_key_parity() -> void:
	var en: Dictionary = _load_table(EN_PATH)
	var tr: Dictionary = _load_table(TR_PATH)
	var missing_tr: Array[String] = []
	var missing_en: Array[String] = []
	for key: Variant in en.keys():
		if not tr.has(key):
			missing_tr.append(String(key))
	for key: Variant in tr.keys():
		if not en.has(key):
			missing_en.append(String(key))
	assert_eq(missing_tr.size(), 0, "tr'de eksik anahtarlar: %s" % str(missing_tr))
	assert_eq(missing_en.size(), 0, "en'de eksik anahtarlar: %s" % str(missing_en))


func test_required_keys_and_levels() -> void:
	var tables: Array[Dictionary] = [_load_table(EN_PATH), _load_table(TR_PATH)]
	for table: Dictionary in tables:
		for key: String in REQUIRED_KEYS:
			assert_true(table.has(key), "zorunlu anahtar var: %s" % key)
			assert_false(String(table.get(key, "")).is_empty(), "anahtar boş değil: %s" % key)
		for level: int in range(1, LEVEL_COUNT + 1):
			var name_key: String = "level.%d.name" % level
			var hint_key: String = "level.%d.hint" % level
			assert_true(table.has(name_key), "bölüm adı anahtarı: %s" % name_key)
			assert_true(table.has(hint_key), "bölüm ipucu anahtarı: %s" % hint_key)


func test_loc_autoload_and_format() -> void:
	var loc: Node = autoload_node("Loc")
	assert_not_null(loc, "Loc autoload")
	if loc == null:
		return
	var original: String = String(loc.get("locale"))
	loc.call("set_locale", "en")
	assert_eq(String(loc.get("locale")), "en", "en diline geçildi")
	var title: String = String(loc.call("t", "game.title"))
	assert_false(title.is_empty(), "game.title boş değil")
	assert_eq(title, String(loc.call("t", "game.title")), "t() deterministik")
	var overload: String = String(loc.call("t", "hud.overload", {"pct": 42}))
	assert_true(overload.contains("42"), "format yer tutucusu: %s" % overload)
	loc.call("set_locale", "tr")
	assert_eq(String(loc.get("locale")), "tr", "tr diline geçildi")
	assert_true(String(loc.call("t", "game.title")).length() > 2, "tr başlık dolu")
	loc.call("set_locale", original)